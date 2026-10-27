class_name StandoffService
extends RefCounted

## The standoff: a fight where nothing moved for `no_progress_round_limit` rounds ends with the party
## stepping back onto the path (D-116). This file owns three things:
##   1. the stall record: what the last quiet rounds showed (refusals, guards), kept on the
##      EncounterContext and cleared whenever the fight makes progress;
##   2. the warning level the round snapshot shows (`stall_level`);
##   3. the resolution: stage marks, the one-time fear drop, and the facts the card shows.
## Statics only. Snapshot builders call `level`, `latest_froze_name` and `stalled_before`, which never
## write. `resolve` is the only writer and runs once, from FlowRuntime._resolve_forced_retreat.

const CAUSE_FROZE := "froze"
const CAUSE_BLOCKED := "blocked"
const CAUSE_UNKNOWN := "unknown"
## The card names at most this many Echoes.
const MAX_NAMES := 2


# ---------------------------------------------------------------------------
# Stall record (transient)
# ---------------------------------------------------------------------------

## Folds the finished round into `ectx.stall_record`. `streak_reset` is true when this round made
## progress: the record then starts again, so it only ever describes the current quiet run.
## `refused` is ordered oldest to newest, one entry per party Echo (the latest refusal wins).
static func record_round(ectx: EncounterContext, streak_reset: bool) -> void:
	if streak_reset:
		ectx.stall_record = {}
		return
	var rec: Dictionary = ectx.stall_record
	var refused: Array = rec.get("refused", [])
	var guards := int(rec.get("guards", 0))
	var round_no := int(ectx.combat_state.get("round_counter", 0))
	for res_v in ectx.last_round_results:
		if not (res_v is Dictionary):
			continue
		var res: Dictionary = res_v
		var action := str(res.get("action_type", ""))
		if action == "actor.guard":
			guards += 1
		elif action == "actor.refuse":
			var id := str(res.get("source_id", ""))
			if str(EncounterContext.find_actor_by_id(ectx.actors, id).get("faction", "")) != "echo":
				continue
			for i in range(refused.size() - 1, -1, -1):
				if str((refused[i] as Dictionary).get("id", "")) == id:
					refused.remove_at(i)
			refused.append({ "id": id, "name": str(res.get("source_name", "")), "round": round_no })
	ectx.stall_record = { "refused": refused, "guards": guards }


## 0, 1 or 2. Derived from the streak and the limit, never stored. A fraction at or below 0 or a
## missing key switches that level off.
static func level(combat_state: Dictionary, stalemate_cfg: Dictionary) -> int:
	var limit := int(combat_state.get("no_progress_round_limit", 0))
	var streak := int(combat_state.get("no_progress_streak", 0))
	if limit <= 0 or streak <= 0:
		return 0
	for step in [[2, "warn_level2_fraction"], [1, "warn_level1_fraction"]]:
		var fraction := float(stalemate_cfg.get(step[1], 0.0))
		if fraction > 0.0 and streak >= ceili(fraction * float(limit) - 0.000001):
			return int(step[0])
	return 0


## Name of the party Echo that refused most recently in the current quiet run, or "".
static func latest_froze_name(ectx: EncounterContext) -> String:
	var refused: Array = ectx.stall_record.get("refused", [])
	return str((refused.back() as Dictionary).get("name", "")) if not refused.is_empty() else ""


## True when the engaged situation (the one in `explore_map.last_situation_id`) has had a standoff.
static func stalled_before(flow_ctx: FlowContext) -> bool:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	return not stage.is_empty() and int(_engaged_situation(stage).get("standoff_count", 0)) > 0


static func _engaged_situation(stage: Dictionary) -> Dictionary:
	var map_v: Variant = stage.get("explore_map", {})
	var emap: Dictionary = map_v if map_v is Dictionary else {}
	var sit_id := str(emap.get("last_situation_id", ""))
	for s_v in emap.get("situations", []):
		if s_v is Dictionary and not sit_id.is_empty() and str((s_v as Dictionary).get("id", "")) == sit_id:
			return s_v
	return {}


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

## Ends the stalled fight for the stage and the party. Call before the encounter is dropped.
## Costs one turn, marks the fight open for a later turn (normal AND objective fight), counts the
## standoff on the situation, and on the first standoff eases the fear of every party Echo that
## refused. It writes no earnings row, spends nothing and marks no pack row lost.
## Returns the card facts: { standoff_count, can_go_sanctum, cause, froze_names, calmed_names, fight_returns }.
## `fight_returns` is false when the fight cannot come back (a hostile-Claimant fight: its situation is resolved).
static func resolve(flow_ctx: FlowContext, t: int) -> Dictionary:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var refused: Array = ectx.stall_record.get("refused", [])
	var cause := CAUSE_UNKNOWN
	if not refused.is_empty():
		cause = CAUSE_FROZE
	elif int(ectx.stall_record.get("guards", 0)) > 0:
		cause = CAUSE_BLOCKED

	var back := ActiveStageService.apply_retreat_return(flow_ctx, flow_ctx.active_encounter_objective_index, t, true)
	# A fight with no situation on the stage record (a harness or debug fight) counts as the first.
	var count := maxi(1, int(back.get("standoff_count", 0)))

	var froze: Array = []
	var calmed: Array = []
	for i in range(refused.size() - 1, -1, -1):
		var entry: Dictionary = refused[i]
		froze.append(str(entry.get("name", "")))
		if count == 1 and _ease_fear(flow_ctx, ectx, str(entry.get("id", "")), t):
			calmed.append(str(entry.get("name", "")))

	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "stage.standoff", "Nobody moved; the party stepped back", {
			"stage_id": flow_ctx.stage_id, "situation_id": str(back.get("situation_id", "")),
			"standoff_count": count, "cause": cause, "froze": froze.size(), "calmed": calmed.size(),
		})
	return {
		"standoff_count": count,
		"can_go_sanctum": count >= 2,
		"cause": cause,
		"froze_names": froze.slice(0, MAX_NAMES),
		"calmed_names": calmed.slice(0, MAX_NAMES),
		"fight_returns": bool(back.get("returns", false)),
	}


## Lowers the saved fear of one party Echo (already holding the fight's final fear) by `standoff_fear_drop`. True only when the value fell,
## so a name is never shown for a drop that clamped at 0.
static func _ease_fear(flow_ctx: FlowContext, ectx: EncounterContext, echo_id: String, t: int) -> bool:
	var drop := int(ectx.stalemate_cfg.get("standoff_fear_drop", 0))
	if drop <= 0 or flow_ctx.logger == null:
		return false
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var roster: Array = (sanctum_v as Dictionary).get("roster", []) if sanctum_v is Dictionary else []
	for echo_v in roster:
		if not (echo_v is Dictionary) or str((echo_v as Dictionary).get("id", "")) != echo_id:
			continue
		var echo: Dictionary = echo_v
		var emo_v: Variant = echo.get("emotion", {})
		var before := int((emo_v as Dictionary).get("fear_current", 0)) if emo_v is Dictionary else 0
		# 999: a fall must never log a "threshold reached" line.
		EmotionService.apply_fear_delta(echo, -drop, "standoff.eased", 999, flow_ctx.logger, t)
		return int(echo["emotion"]["fear_current"]) < before
	return false
