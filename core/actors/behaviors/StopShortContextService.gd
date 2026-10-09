# res://core/actors/behaviors/StopShortContextService.gd
# Wiring between live combat and StopShortService; see decisions.md #108.
# With data.actor.stop_short.enabled false, `screen` returns at once and `finish` only erases the streak key.

class_name StopShortContextService

const ReachAuthority = preload("res://core/movement/CombatActivationService.gd")

const STREAK_KEY: String = "_stop_short_streak"


## Vetoes every `conservative` route candidate of an Echo that has no legal cause and benefit,
## and tags the rest with `_stop_short`. Mutates `candidates`. Returns one { goal_id, option_id, reason } per veto.
## Non-Echo actors keep every route shape.
static func screen(
	candidates: Array,
	actor: Dictionary,
	all_actors: Array,
	context: Dictionary,
	movement_context: Dictionary,
	options: Array,
	capacity: int,
	style_of: Callable,
	cfg: Dictionary
) -> Array:
	var vetoes: Array = []
	if not bool(cfg.get("enabled", false)) or str(actor.get("actor_type", "")) != "echo":
		return vetoes
	var relationships: Dictionary = movement_context.get("relationships", {}) as Dictionary
	var kept: Array = []
	for candidate_v: Variant in candidates:
		var candidate: Dictionary = candidate_v as Dictionary
		if not _is_stop_short_candidate(candidate, style_of):
			kept.append(candidate)
			continue
		var stop_cell: Dictionary = (candidate["_movement_path"] as Array).back() as Dictionary
		var ctx: Dictionary = _build_ctx(
			candidate, stop_cell, actor, all_actors, relationships, context, options, capacity)
		var result: Dictionary = StopShortService.evaluate(ctx, cfg)
		if bool(result["stop"]):
			candidate["_stop_short"] = result
			kept.append(candidate)
		else:
			vetoes.append({
				"goal_id": str(candidate.get("_movement_goal_id", "")),
				"option_id": str(candidate.get("_movement_option_id", "")),
				"reason": str(result["veto"]),
				"nearest_hostile": _nearest_dist(ctx),
				"failed_benefits": _failed_benefits(ctx, cfg) if str(result["veto"]) == StopShortService.VETO_NO_BENEFIT else [],
			})
	candidates.clear()
	candidates.append_array(kept)
	return vetoes


## `actor_cfg` with `stop_short.enabled` forced by a dev override ("on"/"off"); other values return it as is.
## Never mutates `actor_cfg`: the caller's dict is a per-run cache.
static func with_override(actor_cfg: Dictionary, override: String) -> Dictionary:
	if override != "on" and override != "off":
		return actor_cfg
	var block: Dictionary = (actor_cfg.get("stop_short", {}) as Dictionary).duplicate()
	block["enabled"] = override == "on"
	var out: Dictionary = actor_cfg.duplicate()
	out["stop_short"] = block
	return out


## One-line text for the `stopshort` debug status. `ectx` may be null (no encounter yet).
static func status_line(actor_cfg: Dictionary, dev_override: String, ectx: EncounterContext) -> String:
	var shipped: bool = bool((actor_cfg.get("stop_short", {}) as Dictionary).get("enabled", false))
	var running: String = "no encounter"
	if ectx != null:
		running = "balance.json" if ectx.stop_short_override.is_empty() else ectx.stop_short_override
	return "stopshort: override = %s | balance.json enabled = %s | this encounter = %s" % [
		"none" if dev_override.is_empty() else dev_override, str(shipped), running]


## Adds the candidate's stop-short bias to its `_score_bias` record and returns it; 0.0 for any other candidate.
static func record_bias(candidate: Dictionary) -> float:
	var stop: Dictionary = candidate.get("_stop_short", {}) as Dictionary
	if stop.is_empty():
		return 0.0
	var bias: Dictionary = candidate.get("_score_bias", {}) as Dictionary
	bias[StopShortService.bias_key(str(stop["cause_id"]))] = float(stop["bias"])
	candidate["_score_bias"] = bias
	return float(stop["bias"])


static func trace_tag(candidate: Dictionary) -> Dictionary:
	var stop: Dictionary = candidate.get("_stop_short", {}) as Dictionary
	if stop.is_empty():
		return {}
	return {
		"cause_id": str(stop["cause_id"]),
		"benefit_id": str(stop["benefit_id"]),
		"source": str(stop["cause_source"]),
		"code": str(stop["cause_code"]),
	}


static func carry(
	intent: Dictionary, selection: Dictionary, actor: Dictionary, logger: StructuredLogger, t: int
) -> void:
	var actor_id: String = str(actor.get("id", ""))
	for veto_v: Variant in selection.get("_stop_short_vetoes", []) as Array:
		var veto: Dictionary = veto_v as Dictionary
		logger.info(t, "movement.stop_short_vetoed", "Stop-short vetoed", {
			"actor_id": actor_id, "goal_id": veto["goal_id"],
			"option_id": veto["option_id"], "reason": veto["reason"],
			"nearest_hostile": veto["nearest_hostile"], "failed_benefits": veto["failed_benefits"],
		})
	var stop: Dictionary = selection.get("_stop_short", {}) as Dictionary
	if stop.is_empty():
		return
	intent["_stop_short"] = stop
	logger.info(t, "movement.stop_short_selected", "Stop-short selected", {
		"actor_id": actor_id, "cause_id": stop["cause_id"], "benefit_id": stop["benefit_id"],
		"cause_code": stop["cause_code"],
	})


## After activation: consumes `intent["_stop_short"]`, sets the streak flag, logs an interrupted
## benefit, and sets `_stop_short_report` (only for a stop-short step).
static func finish(
	actor: Dictionary,
	intent: Dictionary,
	result: Dictionary,
	asm: ActorStateMachine,
	logger: StructuredLogger,
	t: int
) -> void:
	var stop: Dictionary = intent.get("_stop_short", {}) as Dictionary
	if stop.is_empty():
		actor.erase(STREAK_KEY)
		return
	intent.erase("_stop_short")
	var plan: Dictionary = stop["benefit_plan"] as Dictionary
	var resolved: Dictionary = result.get("resolved_action", {}) as Dictionary
	var performed: bool = str(resolved.get("type", "")) == str(plan["action_type"]) \
		and str(resolved.get("target_id", "")) == str(plan["target_id"])
	actor[STREAK_KEY] = true
	if not performed:
		logger.info(t, "movement.stop_short_interrupted", "Stop-short benefit no longer valid", {
			"actor_id": str(actor.get("id", "")), "benefit_id": stop["benefit_id"],
			"resolved": str(resolved.get("type", "")),
		})
	intent["_stop_short_report"] = {
		"benefit": str(stop["benefit_id"]),
		"performed": performed,
		"stop_cell": (result.get("final_destination", {}) as Dictionary).duplicate(true),
		"subject_actor_id": str(plan["target_id"]),
		"trace": DecisionTrace.sanitize(asm.get_last_decision_trace()),
	}


static func _nearest_dist(ctx: Dictionary) -> int:
	var best: int = -1
	for h_v: Variant in ctx["hostiles"] as Array:
		var d: int = int((h_v as Dictionary)["dist"])
		if best < 0 or d < best:
			best = d
	return best


## For a `no_benefit` veto: each benefit that has a cause but whose predicate is false.
static func _failed_benefits(ctx: Dictionary, cfg: Dictionary) -> Array:
	var failed: Array = []
	for benefit_id: String in StopShortService.BENEFITS:
		if not StopShortService.best_cause(benefit_id, ctx, cfg).is_empty() \
				and StopShortService.benefit_plan(benefit_id, ctx, cfg).is_empty():
			failed.append(benefit_id)
	return failed


static func _is_stop_short_candidate(candidate: Dictionary, style_of: Callable) -> bool:
	if not bool(candidate.get("_movement_route", false)):
		return false
	if (candidate.get("_movement_path", []) as Array).is_empty():
		return false
	return str(style_of.call(
		str(candidate.get("_movement_option_id", "")), str(candidate.get("_movement_goal_id", ""))
	)) == "conservative"


static func _build_ctx(
	candidate: Dictionary,
	stop_cell: Dictionary,
	actor: Dictionary,
	all_actors: Array,
	relationships: Dictionary,
	context: Dictionary,
	options: Array,
	capacity: int
) -> Dictionary:
	var goal: Dictionary = candidate.get("_movement_goal", {}) as Dictionary
	var option: Dictionary = candidate.get("_movement_option", {}) as Dictionary
	var hostiles: Array = []
	var in_reach: bool = false
	for other_v: Variant in all_actors:
		var other: Dictionary = other_v as Dictionary
		if str(relationships.get(str(other.get("id", "")), "")) != "hostile":
			continue
		if bool(other.get("is_dead", false)) or bool(other.get("is_structure", false)):
			continue
		var pos: Dictionary = other.get("grid_pos", {}) as Dictionary
		if pos.is_empty():
			continue
		hostiles.append({
			"id": str(other.get("id", "")),
			"dist": GridService.chebyshev_distance(stop_cell, pos),
			"marked": not str(other.get("marked_by", "")).is_empty(),
		})
		if ReachAuthority.in_reach(stop_cell, pos, "melee_attack"):
			in_reach = true
	return {
		"actor_type": str(actor.get("actor_type", "")),
		"purpose": str(goal.get("purpose", "")),
		"urgency": float(goal.get("urgency", 0.0)),
		"fear": int(actor.get("fear", 0)),
		"fear_base": int(actor.get("fear_base", 0)),
		"morale": int(actor.get("morale", 50)),
		"calling_family": str(context.get("calling_family", "")),
		"dominant_vector": str(actor.get("dominant_vector", "")),
		"judgment": float(context.get("judgment", 0.3)),
		"capacity": capacity,
		"def": int((actor.get("stats", {}) as Dictionary).get("def", 0)),
		"guard_state": bool(actor.get("guard_state", false)),
		"stop_in_hostile_reach": in_reach,
		"previous_stop_short": bool(actor.get(STREAK_KEY, false)),
		"stop_cell_hostile_control": not (option.get("hostile_control_sources", []) as Array).is_empty(),
		"cohesion_stop": float(option.get("cohesion", 0.0)),
		"cohesion_full": _full_route_cohesion(str(candidate.get("_movement_goal_id", "")), options),
		"hostiles": hostiles,
	}


static func _full_route_cohesion(goal_id: String, options: Array) -> float:
	var best_len: int = -1
	var cohesion: float = 0.0
	for option_v: Variant in options:
		var option: Dictionary = option_v as Dictionary
		if str(option.get("goal_id", "")) != goal_id:
			continue
		if str(option.get("option_id", "")).contains(".conservative"):
			continue
		var length: int = (option.get("path", []) as Array).size()
		if length > best_len:
			best_len = length
			cohesion = float(option.get("cohesion", 0.0))
	return cohesion
