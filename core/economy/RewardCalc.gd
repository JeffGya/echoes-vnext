## RewardCalc
## ECONOMY-004: Pure static helper — computes stage reward values from encounter result.
## No side effects, no service calls, no OS access.
## Same inputs → identical output every time (deterministic).

class_name RewardCalc extends RefCounted

## V2-INFRA-003 Phase 8 (defect D39): THE single definition of a stage's base reward.
##
## Before this, two functions computed "the base reward of this stage" from the same stage and
## disagreed by construction:
##   - the loop now inlined here, which SUMS every objective's weight and feeds the stage payout;
##   - `ActiveStageService.get_stage_base_reward()`, which read `objectives[0]` only AND read its
##     type under the key `"obj_type"`, which `ObjectiveModel.make()` never writes (it writes
##     `"type"` — `core/realms/ObjectiveModel.gd:63-70`). Both faults pushed the same way, so it
##     returned the flat `objective_weights.combat` default (30) for every stage, and fed the
##     partial-withdrawal payout.
## For a two-combat-objective stage that is 60 against 30, for one stage, on the same tick.
##
## D39 IS ANSWERED "SUM", FOR BOTH READERS (see the register). A stage's base reward is the sum
## of its objectives' weights; the partial-withdrawal payout is a fraction of that same number.
## `ActiveStageService.get_stage_base_reward()` now delegates here so the two cannot drift again.
##
## objectives: Array of ObjectiveModel dicts. The type key is `"type"`, never `"obj_type"`.
## reward_cfg: balance.data.rewards dict.
static func base_reward(objectives: Array, reward_cfg: Dictionary) -> int:
	var weights_v: Variant = reward_cfg.get("objective_weights", {})
	var weights: Dictionary = weights_v if weights_v is Dictionary else {}
	var base := 0
	for obj_v in objectives:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		var w_v: Variant = weights.get(str(obj.get("type", "")), 0)
		base += int(w_v) if typeof(w_v) == TYPE_INT or typeof(w_v) == TYPE_FLOAT else 0
	return base


## V2-INFRA-003 Phase 8: THE single definition of the redo multiplier, for the same reason
## base_reward() above is one. The settlement split gave the stage cadence its own payer, and
## that payer must scale the base by exactly the multiplier the combined payer used — a second
## copy of `maxf(floor, 1.0 - run_count * per_run)` would be free to drift from this one.
## Degrades per completed run of the realm, clamped at the authored floor.
static func redo_multiplier(run_count: int, reward_cfg: Dictionary) -> float:
	var penalty_per_run := float(reward_cfg.get("redo_penalty_per_run", 0.10))
	var penalty_floor   := float(reward_cfg.get("redo_penalty_floor", 0.50))
	return maxf(penalty_floor, 1.0 - float(run_count) * penalty_per_run)


## Compute all reward values from encounter result + stage objectives + realm run_count.
## Returns a dict with pre-computed fields ready for EconomyService.reward_encounter_complete().
##
## victory:         true = win, false = defeat
## objectives:      Array of {type: String} dicts from StageModel (includes boss)
## enemies_defeated: how many enemy actors were killed
## total_enemies:    total enemy actors on board at start (for max_possible rank calc)
## echoes_survived:  how many echo actors are alive at end
## total_echoes:     total echo actors in the encounter (for max_possible rank calc)
## run_count:        from RealmModel — how many times this realm has been completed + restarted
## reward_cfg:       balance.data.rewards dict
## resolution_mode:  EncounterResolutionModes value; selects the pace and reached-enemy rules
## par_rounds:       combat_state["par_rounds"]; 0.0 for a no-pace mode
## reached_enemies:  PaceService.rank_reached_count(combat_state); replaces total_enemies in
##                   the rank ceiling for PaceService.REACHED_ENEMY_MODES
## pace_stage_base:  combat_state["stage_base"], captured at fight start. The pace bonus, its
##                   rank term and pace_state use it, so they match the live pace_state
##                   (decisions.md D-21). Every other term keeps `base` below.
## ally_kills:       combat_state["ally_killed_enemy_ids"].size(). These kills pay the kill Ase
##                   but leave both sides of the rank (decisions.md D-23).
## guide_mode:       combat_state["guide_mode"]; GUIDE_SPIRIT carries pace only for "escort".
static func compute(
	victory: bool,
	objectives: Array,
	enemies_defeated: int,
	total_enemies: int,
	echoes_survived: int,
	total_echoes: int,
	round_ended: int,
	run_count: int,
	reward_cfg: Dictionary,
	resolution_mode: String,
	par_rounds: float,
	reached_enemies: int,
	pace_stage_base: int,
	ally_kills: int = 0,
	guide_mode: String = ""
) -> Dictionary:
	# Base = sum of objective type weights (single definition — see base_reward() above).
	var base := base_reward(objectives, reward_cfg)

	# Per-unit bonuses (actual counts)
	var enemy_bonus_per := int(reward_cfg.get("enemy_defeated_bonus", 5))
	var echo_bonus_per  := int(reward_cfg.get("echo_survived_bonus", 10))
	var enemy_bonus     := enemies_defeated * enemy_bonus_per
	var echo_bonus      := echoes_survived  * echo_bonus_per

	# Pace bonus (design §4): a win pays pace_stage_base × pace_bonus_pct × the curve fraction.
	var is_pace       := PaceService.is_pace_mode(resolution_mode, guide_mode) and par_rounds > 0.0
	var full_ratio    := float(reward_cfg.get("pace_full_ratio", 1.1))
	var zero_ratio    := float(reward_cfg.get("pace_zero_ratio", 1.6))
	var pace_pct      := float(reward_cfg.get("pace_bonus_pct", 0.05))
	var max_pace_bonus := PaceService.max_bonus_ase(pace_stage_base, pace_pct) if is_pace else 0
	var pace_bonus    := 0
	if is_pace and victory:
		pace_bonus = PaceService.bonus_ase(round_ended, par_rounds, full_ratio, zero_ratio,
			pace_stage_base, pace_pct)

	# Redo multiplier — degrades per run, floor clamped (single definition above)
	var redo_mul := redo_multiplier(run_count, reward_cfg)

	# Rank (design §5). A no-pace mode has max_pace_bonus 0, so the bonus is out of both sides.
	# The reached-enemy modes count only enemies that reached the party in the ceiling.
	# An ally or spirit kill is out of the kill term and the ceiling, in every mode (D-23);
	# reached_enemies already excludes those ids.
	# On defeat: use defeat_payout as numerator so defeat always ranks worse than victory.
	var defeat_factor  := float(reward_cfg.get("defeat_factor", 0.25))
	var ceiling_enemies := reached_enemies if PaceService.tracks_reached_enemies(resolution_mode) \
		else maxi(0, total_enemies - ally_kills)
	var rank_enemy_bonus := maxi(0, enemies_defeated - ally_kills) * enemy_bonus_per
	var max_possible   := base \
		+ (ceiling_enemies * enemy_bonus_per) \
		+ (total_echoes  * echo_bonus_per) \
		+ max_pace_bonus

	var thresholds_v: Variant = reward_cfg.get("rank_thresholds", {})
	var thresholds: Dictionary = thresholds_v if thresholds_v is Dictionary else {}
	var rank: String
	var rank_without_pace: String
	if victory:
		var kept := base + rank_enemy_bonus + echo_bonus
		rank              = _rank_for(kept + pace_bonus, max_possible, redo_mul, run_count, thresholds)
		rank_without_pace = _rank_for(kept, max_possible, redo_mul, run_count, thresholds)
	else:
		rank = _rank_for(roundi(float(base) * defeat_factor), max_possible, redo_mul, run_count, thresholds)
		rank_without_pace = rank

	return {
		"base_reward":       base,
		"enemy_bonus":       enemy_bonus,
		"echo_bonus":        echo_bonus,
		"pace_bonus":        pace_bonus,
		"pace_mode":         is_pace,
		# A defeat carries no pace state (design §7).
		"pace_state":        PaceService.pace_state(round_ended, par_rounds, full_ratio, zero_ratio,
			pace_stage_base, pace_pct) if is_pace and victory else "",
		# The rank-cause note (design §6): true when the pace bonus moved this rank.
		"pace_changed_rank": rank != rank_without_pace,
		"redo_multiplier":   redo_mul,
		"rank":              rank,
	}


static func _rank_for(numerator: int, max_possible: int, redo_mul: float, run_count: int,
		thresholds: Dictionary) -> String:
	var perf_ratio := float(numerator) / float(max_possible) if max_possible > 0 else 0.0
	return _compute_rank(perf_ratio * redo_mul, run_count, thresholds)


static func _compute_rank(rank_score: float, run_count: int, thresholds: Dictionary) -> String:
	var s_thresh := float(thresholds.get("S", 0.90))
	var a_thresh := float(thresholds.get("A", 0.75))
	var b_thresh := float(thresholds.get("B", 0.55))
	var c_thresh := float(thresholds.get("C", 0.35))
	var d_thresh := float(thresholds.get("D", 0.15))
	if rank_score >= s_thresh and run_count == 0:
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
