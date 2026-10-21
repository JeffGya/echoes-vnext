## RewardCalc
## ECONOMY-004: Pure static helper — computes stage reward values from encounter result.
## No side effects, no service calls, no OS access.
## Same inputs → identical output every time (deterministic).

class_name RewardCalc extends RefCounted

## THE single definition of a stage's base reward, for every reader. It sums the weights of the
## objectives selected by `mode`; no reader keeps its own copy.
##   MODE_COMPLETED:             objectives with `completed` true (stage payer, partials).
##   MODE_COMPLETED_PLUS_FOUGHT: those, plus the objective at `fought_index` (the fight base_reward).
##   MODE_FOUGHT:                only the objective at `fought_index` (defeat consolation).
## Select first, then weigh: an objective that is not selected is never looked up, so it logs
## nothing. A selected type with no key in `objective_weights` logs
## `economy.reward.unknown_objective_type` through `logger` (when given) and counts 0.
## A key with value 0 (the boss) is a weight and logs nothing.
## The type key is `"type"`, never `"obj_type"`.
const MODE_COMPLETED := "completed"
const MODE_COMPLETED_PLUS_FOUGHT := "completed_plus_fought"
const MODE_FOUGHT := "fought"


static func base_reward(objectives: Array, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0,
		mode: String = MODE_COMPLETED, fought_index: int = -1) -> int:
	return _sum_selected(objectives, reward_cfg, "objective_weights", logger, t, mode, fought_index)


## The stage's Ekwan before the replay factor: the sum of `objective_ekwan` over the COMPLETED
## objectives (same selection as the Ase base). The caller rounds ONCE on this sum.
static func stage_ekwan(objectives: Array, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> int:
	return _sum_selected(objectives, reward_cfg, "objective_ekwan", logger, t, MODE_COMPLETED, -1)


## Shared selection and lookup behind `base_reward` and `stage_ekwan`, so the two tables cannot
## drift in what they select or how a missing key behaves.
static func _sum_selected(objectives: Array, reward_cfg: Dictionary, table_key: String,
		logger: StructuredLogger, t: int, mode: String, fought_index: int) -> int:
	var weights_v: Variant = reward_cfg.get(table_key, {})
	var weights: Dictionary = weights_v if weights_v is Dictionary else {}
	var base := 0
	for i in objectives.size():
		var obj: Dictionary = objectives[i] if objectives[i] is Dictionary else {}
		var done := bool(obj.get("completed", false))
		var fought := i == fought_index
		var selected := (done and mode != MODE_FOUGHT) or (fought and mode != MODE_COMPLETED)
		if not selected:
			continue
		var type := str(obj.get("type", ""))
		if not weights.has(type):
			if logger != null:
				logger.warn(t, "economy.reward.unknown_objective_type",
					"Objective type has no weight — counts 0", {
						"type": type, "objective_index": i, "table": table_key })
			continue
		var w_v: Variant = weights[type]
		base += int(w_v) if typeof(w_v) == TYPE_INT or typeof(w_v) == TYPE_FLOAT else 0
	return base


## Counts for the ledger row "overcome of total". Types in `reward_cfg.objective_count_excluded_types`
## (the boss stub) are in neither number. Display only: it never changes a payout.
static func objective_counts(objectives: Array, reward_cfg: Dictionary) -> Dictionary:
	var excluded_v: Variant = reward_cfg.get("objective_count_excluded_types", [])
	var excluded: Array = excluded_v if excluded_v is Array else []
	var overcome := 0
	var total := 0
	for obj_v in objectives:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		if excluded.has(str(obj.get("type", ""))):
			continue
		total += 1
		if bool(obj.get("completed", false)):
			overcome += 1
	return { "overcome": overcome, "total": total }


## V2-INFRA-003 Phase 8: THE single definition of the redo multiplier, for the same reason
## base_reward() above is one. The settlement split gave the stage cadence its own payer, and
## that payer must scale the base by exactly the multiplier the combined payer used — a second
## copy of `maxf(floor, 1.0 - run_count * per_run)` would be free to drift from this one.
## Degrades per completed run of the realm, clamped at the authored floor.
static func redo_multiplier(run_count: int, reward_cfg: Dictionary) -> float:
	var penalty_per_run := float(reward_cfg.get("redo_penalty_per_run", 0.10))
	var penalty_floor   := float(reward_cfg.get("redo_penalty_floor", 0.50))
	return maxf(penalty_floor, 1.0 - float(run_count) * penalty_per_run)


## Compute the fight's reward values from the encounter result.
## Returns a dict ready for EconomyService.reward_encounter_complete().
##
## echoes_survived / total_echoes: roster Echoes home / started in the fight (no allies, no spirit).
## round_ended, par_rounds, resolution_mode, guide_mode: give the pace fraction. par_rounds is
##   0.0 for a no-pace mode.
## logger, t: receive the unknown-objective-type error from base_reward(); t is injected.
## fought_index: the objective of the situation being fought, -1 for none. `base_reward` is the
##   completed objectives plus this one; `consolation_base` (the defeat pay base) is this one alone.
## Speed pays no Ase (D-49). It enters only the rank score (`rank_score`).
static func compute(
	victory: bool,
	objectives: Array,
	echoes_survived: int,
	total_echoes: int,
	round_ended: int,
	run_count: int,
	reward_cfg: Dictionary,
	resolution_mode: String,
	par_rounds: float,
	guide_mode: String = "",
	logger: StructuredLogger = null,
	t: int = 0,
	fought_index: int = -1
) -> Dictionary:
	var base := base_reward(objectives, reward_cfg, logger, t, MODE_COMPLETED_PLUS_FOUGHT, fought_index)
	# The fought objective is already inside `base`, so it logs there; no second log here.
	var consolation_base := base_reward(objectives, reward_cfg, null, t, MODE_FOUGHT, fought_index)
	var echo_bonus := echoes_survived * int(reward_cfg.get("echo_survived_bonus", 10))

	var is_pace    := PaceService.is_pace_mode(resolution_mode, guide_mode) and par_rounds > 0.0
	var full_ratio := float(reward_cfg.get("pace_full_ratio", 1.1))
	var zero_ratio := float(reward_cfg.get("pace_zero_ratio", 1.6))
	var fraction   := PaceService.bonus_fraction(round_ended, par_rounds, full_ratio, zero_ratio)

	var redo_mul := redo_multiplier(run_count, reward_cfg)

	# A no-pace mode has no speed to earn, so it takes the full pace points and is not capped.
	# `rank_without_pace` is the grade with the pace points removed, for the rank-cause note.
	var rank := "F"
	var rank_without_pace := "F"
	var any_death := echoes_survived < total_echoes
	if victory:
		var thresholds_v: Variant = reward_cfg.get("rank_thresholds", {})
		var thresholds: Dictionary = thresholds_v if thresholds_v is Dictionary else {}
		var pace_credit := fraction if is_pace else 1.0
		rank = _compute_rank(rank_score(echoes_survived, total_echoes, pace_credit, reward_cfg),
			thresholds, any_death)
		rank_without_pace = _compute_rank(rank_score(echoes_survived, total_echoes, 0.0, reward_cfg),
			thresholds, any_death) if is_pace else rank

	return {
		"base_reward":       base,
		"consolation_base":  consolation_base,
		"echo_bonus":        echo_bonus,
		"pace_mode":         is_pace,
		# A defeat carries no pace state (design §7).
		"pace_state":        PaceService.pace_state(round_ended, par_rounds, full_ratio, zero_ratio) \
			if is_pace and victory else "",
		"pace_changed_rank": rank != rank_without_pace,
		"redo_multiplier":   redo_mul,
		"rank":              rank,
	}


## The rank score of a win: win points + home points x (home / started) + pace points x pace_credit.
## Reads no Ase amount and no replay factor (D-74). pace_credit is the pace fraction (0 to 1).
static func rank_score(echoes_survived: int, total_echoes: int, pace_credit: float,
		reward_cfg: Dictionary) -> float:
	var pts_v: Variant = reward_cfg.get("rank_points", {})
	var pts: Dictionary = pts_v if pts_v is Dictionary else {}
	var home_share := float(echoes_survived) / float(total_echoes) if total_echoes > 0 else 1.0
	var score := float(pts.get("win", 0.4)) + float(pts.get("home", 0.4)) * home_share \
		+ float(pts.get("pace", 0.2)) * pace_credit
	return score


## Any death caps a win at this grade, whatever the pace credit (D-69).
const DEATH_CAP_RANK := "A"


static func _compute_rank(raw_score: float, thresholds: Dictionary, any_death: bool = false) -> String:
	# A score on a threshold must not be lost to float error (0.4 + 0.4 + 0.2 x 0.5 sums to 0.8999...).
	var rank_score := raw_score + 0.000000001
	var s_thresh := float(thresholds.get("S", 0.90))
	var a_thresh := float(thresholds.get("A", 0.75))
	var b_thresh := float(thresholds.get("B", 0.55))
	var c_thresh := float(thresholds.get("C", 0.35))
	var d_thresh := float(thresholds.get("D", 0.15))
	if rank_score >= s_thresh and not any_death:
		return "S"
	if rank_score >= a_thresh:
		return "A"
	if rank_score >= b_thresh:
		return "B"
	if rank_score >= c_thresh:
		return "C"
	if rank_score >= d_thresh:
		return "D"
	return "F"
