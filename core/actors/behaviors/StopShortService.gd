# res://core/actors/behaviors/StopShortService.gd
# Rules: docs/movement-model.md 7.5; decisions.md #108.
# Decides whether ONE stop-short route option is legal for an Echo, and which cause and
# benefit it carries. Pure and static: every weight is in `cfg`, every board fact in `ctx`.
# Legal = gates G1-G5 pass AND a cause (G6) AND a benefit (G7) exist for the same benefit.

class_name StopShortService

const ReachAuthority = preload("res://core/movement/CombatActivationService.gd")

const BENEFITS: Array = ["guard", "observe", "hold"]

## Veto reasons. These strings are logged and tested; never rename one.
const VETO_PURPOSE_EXCLUDED: String = "purpose_excluded"
const VETO_URGENCY_CRITICAL: String = "urgency_critical"
const VETO_HOSTILE_IN_REACH: String = "hostile_in_reach"
const VETO_STREAK: String = "streak"
const VETO_NO_CAUSE: String = "no_cause"
const VETO_NO_BENEFIT: String = "no_benefit"

## Registry order breaks ties between causes.
const CAUSE_ROWS: Array = [
	{ "id": "fear", "enabled": true },
	{ "id": "identity", "enabled": true },
]

const _ACTION_BY_BENEFIT: Dictionary = {
	"guard": "actor.guard",
	"observe": "actor.observe",
	"hold": "actor.guard",
}


## `ctx` fields (all read with safe defaults):
##   actor_type String, purpose String, urgency float,
##   fear, fear_base, morale int; calling_family String; dominant_vector String;
##   judgment float 0..1; capacity int; def int; guard_state bool;
##   stop_in_hostile_reach bool; previous_stop_short bool;
##   stop_cell_hostile_control bool (hostile control edge on the last step);
##   cohesion_stop, cohesion_full float;
##   hostiles Array of { id String, dist int (Chebyshev from the stop cell), marked bool }.
## Returns { stop: false, veto: String } or
## { stop: true, veto: "", cause_id, cause_source, cause_code, benefit_id, strength, bias,
##   benefit_plan: { benefit_id, action_type, target_id } }.
static func evaluate(ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	if (cfg.get("excluded_purposes", []) as Array).has(str(ctx.get("purpose", ""))):
		return _veto(VETO_PURPOSE_EXCLUDED)
	if float(ctx.get("urgency", 0.0)) >= float(cfg.get("urgency_ceiling", 1.0)):
		return _veto(VETO_URGENCY_CRITICAL)
	if bool(ctx.get("stop_in_hostile_reach", false)):
		return _veto(VETO_HOSTILE_IN_REACH)
	if bool(ctx.get("previous_stop_short", false)):
		return _veto(VETO_STREAK)

	var causes: Dictionary = {}
	var plans: Dictionary = {}
	for benefit_id: String in BENEFITS:
		var cause: Dictionary = best_cause(benefit_id, ctx, cfg)
		if not cause.is_empty():
			causes[benefit_id] = cause
		var plan: Dictionary = benefit_plan(benefit_id, ctx, cfg)
		if not plan.is_empty():
			plans[benefit_id] = plan
	if causes.is_empty():
		return _veto(VETO_NO_CAUSE)

	# Equal strengths: Hold first when an ally is near (the Hold predicate), else the list order.
	var order: Array = BENEFITS
	if plans.has("hold"):
		order = ["hold", "guard", "observe"]
	var chosen: String = ""
	for benefit_id: String in order:
		if not (causes.has(benefit_id) and plans.has(benefit_id)):
			continue
		if chosen.is_empty() or float(causes[benefit_id]["strength"]) > float(causes[chosen]["strength"]):
			chosen = benefit_id
	if chosen.is_empty():
		return _veto(VETO_NO_BENEFIT)

	var won: Dictionary = causes[chosen]
	return {
		"stop": true,
		"veto": "",
		"cause_id": won["cause_id"],
		"cause_source": won["source"],
		"cause_code": won["code"],
		"benefit_id": chosen,
		"strength": won["strength"],
		"bias": float(cfg.get("stop_short_weight", 0.0)) * float(won["strength"]),
		"benefit_plan": plans[chosen],
	}


static func bias_key(cause_id: String) -> String:
	return "stop_short.%s" % cause_id


## Strongest enabled cause for `benefit_id` reaching `min_cause_strength`; ties keep the earlier registry row. {} if none.
static func best_cause(benefit_id: String, ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	var floor_strength: float = float(cfg.get("min_cause_strength", 0.0))
	var best: Dictionary = {}
	for row_v: Variant in CAUSE_ROWS:
		var row: Dictionary = row_v as Dictionary
		if not bool(row["enabled"]):
			continue
		var found: Dictionary = cause_strength(str(row["id"]), benefit_id, ctx, cfg)
		var strength: float = float(found.get("strength", 0.0))
		if strength <= 0.0 or strength < floor_strength:
			continue
		if best.is_empty() or strength > float(best["strength"]):
			best = found
	return best


## Effective strength (0..1) of one cause for one benefit. { cause_id, strength, source, code }.
static func cause_strength(cause_id: String, benefit_id: String, ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	match cause_id:
		"fear":
			return _fear_cause(benefit_id, ctx, cfg)
		"identity":
			return _identity_cause(benefit_id, ctx, cfg)
	return { "cause_id": cause_id, "strength": 0.0, "source": "", "code": "" }


static func fear_strength(ctx: Dictionary, cfg: Dictionary) -> float:
	var fear_cfg: Dictionary = cfg.get("fear", {}) as Dictionary
	var lo: float = float(fear_cfg.get("floor", 20))
	var hi: float = float(fear_cfg.get("full", 45))
	var level: float = maxf(float(ctx.get("fear", 0)), float(ctx.get("fear_base", 0)))
	if hi <= lo:
		return 1.0 if level >= hi else 0.0
	return clampf((level - lo) / (hi - lo), 0.0, 1.0)


static func morale_strength(ctx: Dictionary, cfg: Dictionary) -> float:
	var tier: String = EmotionService.get_morale_tier(int(ctx.get("morale", 50)))
	var row: Dictionary = cfg.get("morale_strength", {}) as Dictionary
	return clampf(float(row.get(tier, 0.0)), 0.0, 1.0)


static func benefit_plan(benefit_id: String, ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	var target_id: String = ""
	match benefit_id:
		"guard":
			if not _guard_ok(ctx, cfg):
				return {}
		"observe":
			target_id = _observe_target(ctx, cfg)
			if target_id.is_empty():
				return {}
		"hold":
			if not _hold_ok(ctx, cfg):
				return {}
		_:
			return {}
	return {
		"benefit_id": benefit_id,
		"action_type": str(_ACTION_BY_BENEFIT[benefit_id]),
		"target_id": target_id,
	}


static func _veto(reason: String) -> Dictionary:
	return { "stop": false, "veto": reason }


static func _fear_cause(benefit_id: String, ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	var fear_s: float = fear_strength(ctx, cfg)
	var morale_s: float = morale_strength(ctx, cfg)
	var affinity: Dictionary = (cfg.get("fear", {}) as Dictionary).get("affinity", {}) as Dictionary
	var combined: float = maxf(fear_s, morale_s) * clampf(float(affinity.get(benefit_id, 0.0)), 0.0, 1.0)
	return {
		"cause_id": "fear",
		"strength": combined,
		"source": "emotion",
		"code": "fear" if fear_s >= morale_s else "morale",
	}


static func _identity_cause(benefit_id: String, ctx: Dictionary, cfg: Dictionary) -> Dictionary:
	var id_cfg: Dictionary = cfg.get("identity", {}) as Dictionary
	var family_row: Dictionary = (id_cfg.get("family_affinity", {}) as Dictionary).get(
		str(ctx.get("calling_family", "")), {}) as Dictionary
	var vector_row: Dictionary = (id_cfg.get("vector_affinity", {}) as Dictionary).get(
		str(ctx.get("dominant_vector", "")), {}) as Dictionary
	var family_aff: float = float(family_row.get(benefit_id, 0.0))
	var vector_aff: float = float(vector_row.get(benefit_id, 0.0))
	var base: float = float(id_cfg.get("judgment_base", 0.5))
	var scale: float = base + (1.0 - base) * clampf(float(ctx.get("judgment", 0.0)), 0.0, 1.0)
	var from_family: bool = family_aff >= vector_aff
	return {
		"cause_id": "identity",
		"strength": clampf(maxf(family_aff, vector_aff) * scale, 0.0, 1.0),
		"source": "calling" if from_family else "vector",
		"code": "calling_weight" if from_family else "values",
	}


static func _guard_ok(ctx: Dictionary, cfg: Dictionary) -> bool:
	var guard_cfg: Dictionary = cfg.get("guard", {}) as Dictionary
	if bool(ctx.get("guard_state", false)):
		return false
	if int(ctx.get("def", 0)) < int(guard_cfg.get("min_def", 1)):
		return false
	var reach: int = int(ctx.get("capacity", 0)) + int(guard_cfg.get("hostile_reach_extra", 1))
	for h_v: Variant in ctx.get("hostiles", []) as Array:
		if int((h_v as Dictionary).get("dist", 999)) <= reach:
			return true
	return false


## Nearest unmarked hostile within the observe range. Equal distance: lowest id. "" if none.
static func _observe_target(ctx: Dictionary, cfg: Dictionary) -> String:
	if bool(ctx.get("stop_cell_hostile_control", false)):
		return ""
	var obs_range: int = ReachAuthority.reach_for("actor.observe")
	var best_id: String = ""
	var best_dist: int = 0
	for h_v: Variant in ctx.get("hostiles", []) as Array:
		var h: Dictionary = h_v as Dictionary
		var dist: int = int(h.get("dist", 999))
		if bool(h.get("marked", false)) or dist > obs_range:
			continue
		var hid: String = str(h.get("id", ""))
		if best_id.is_empty() or dist < best_dist or (dist == best_dist and hid < best_id):
			best_id = hid
			best_dist = dist
	return best_id


static func _hold_ok(ctx: Dictionary, cfg: Dictionary) -> bool:
	var at_stop: float = float(ctx.get("cohesion_stop", 0.0))
	return at_stop >= float((cfg.get("hold", {}) as Dictionary).get("min_cohesion", 0.5)) \
		and at_stop > float(ctx.get("cohesion_full", 0.0))
