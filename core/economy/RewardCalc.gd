## RewardCalc
## ECONOMY-004: Pure static helper — computes stage reward values from encounter result.
## No side effects, no service calls, no OS access.
## Same inputs → identical output every time (deterministic).

class_name RewardCalc extends RefCounted

## Compute all reward values from encounter result + stage objectives + realm run_count.
## Returns a dict with pre-computed fields ready for EconomyService.reward_stage_complete().
##
## victory:         true = win, false = defeat
## objectives:      Array of {type: String} dicts from StageModel (includes boss)
## enemies_defeated: how many enemy actors were killed
## total_enemies:    total enemy actors on board at start (for max_possible rank calc)
## echoes_survived:  how many echo actors are alive at end
## total_echoes:     total echo actors in the encounter (for max_possible rank calc)
## run_count:        from RealmModel — how many times this realm has been completed + restarted
## reward_cfg:       balance.data.rewards dict
static func compute(
	victory: bool,
	objectives: Array,
	enemies_defeated: int,
	total_enemies: int,
	echoes_survived: int,
	total_echoes: int,
	round_ended: int,
	run_count: int,
	reward_cfg: Dictionary
) -> Dictionary:
	var weights: Dictionary = reward_cfg.get("objective_weights", {})
	if not weights is Dictionary:
		weights = {}

	# Base = sum of objective type weights
	var base := 0
	for obj_v in objectives:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		var w_v: Variant = weights.get(str(obj.get("type", "")), 0)
		base += int(w_v) if typeof(w_v) == TYPE_INT or typeof(w_v) == TYPE_FLOAT else 0

	# Per-unit bonuses (actual counts)
	var enemy_bonus_per := int(reward_cfg.get("enemy_defeated_bonus", 5))
	var echo_bonus_per  := int(reward_cfg.get("echo_survived_bonus", 10))
	var enemy_bonus     := enemies_defeated * enemy_bonus_per
	var echo_bonus      := echoes_survived  * echo_bonus_per

	# Speed bonus — only if ended before threshold rounds
	var speed_threshold := int(reward_cfg.get("speed_bonus_threshold", 5))
	var speed_pct       := float(reward_cfg.get("speed_bonus_pct", 0.15))
	var speed_bonus     := roundi(float(base) * speed_pct) if round_ended < speed_threshold else 0

	# Redo multiplier — degrades per run, floor clamped
	var penalty_per_run := float(reward_cfg.get("redo_penalty_per_run", 0.10))
	var penalty_floor   := float(reward_cfg.get("redo_penalty_floor", 0.50))
	var redo_mul        := maxf(penalty_floor, 1.0 - float(run_count) * penalty_per_run)

	# Rank — use board totals for max_possible so rank reflects missed opportunities.
	# On defeat: use defeat_payout as numerator so defeat always ranks worse than victory.
	var defeat_factor   := float(reward_cfg.get("defeat_factor", 0.25))
	var max_speed_bonus := roundi(float(base) * speed_pct)
	var max_possible    := base \
		+ (total_enemies * enemy_bonus_per) \
		+ (total_echoes  * echo_bonus_per) \
		+ max_speed_bonus

	var rank_numerator: int
	if victory:
		rank_numerator = base + enemy_bonus + echo_bonus + speed_bonus
	else:
		rank_numerator = roundi(float(base) * defeat_factor)

	var perf_ratio  := float(rank_numerator) / float(max_possible) if max_possible > 0 else 0.0
	var rank_score  := perf_ratio * redo_mul
	var thresholds_v: Variant = reward_cfg.get("rank_thresholds", {})
	var thresholds: Dictionary = thresholds_v if thresholds_v is Dictionary else {}
	var rank := _compute_rank(rank_score, run_count, thresholds)

	return {
		"base_reward":     base,
		"enemy_bonus":     enemy_bonus,
		"echo_bonus":      echo_bonus,
		"speed_bonus":     speed_bonus,
		"redo_multiplier": redo_mul,
		"rank":            rank,
	}


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
