# res://tests/EconomyRewardTests.gd
# ECONOMY-004: Tests for RewardCalc + EconomyService.reward_stage_complete().
#
# Tests:
#   1.  reward/compute_base_only             — single combat obj → base = 30
#   2.  reward/compute_multi_objectives      — combat + shrine + boss → base = 130
#   3.  reward/compute_enemy_bonus           — 3 enemies → enemy_bonus = 15
#   4.  reward/compute_echo_bonus            — 2 echoes → echo_bonus = 20
#   5.  reward/compute_speed_bonus           — round_ended=3 (<5) → speed_bonus = round(base×0.15)
#   6.  reward/no_speed_bonus_slow           — round_ended=5 → speed_bonus = 0
#   7.  reward/redo_multiplier_floor         — run_count=8 → redo_mul = 0.50
#   8.  reward/redo_multiplier_partial       — run_count=3 → redo_mul = 0.70
#   9.  reward/defeat_payout                 — defeat: total = round(base×0.25×redo_mul)
#   10. reward/rank_S_first_run              — perfect score + run_count=0 → rank = "S"
#   11. reward/rank_F_poor_performance       — poor perf + run_count=5 → rank = "F"
#   12. reward/economy_service_adds_ase      — reward_stage_complete() adds correct amount

extends RefCounted
class_name EconomyRewardTests


# ─── Config helpers ───────────────────────────────────────────────────────────

static func _default_cfg() -> Dictionary:
	return {
		"objective_weights": {
			"combat": 30,
			"shrine": 40,
			"boss":   60,
		},
		"enemy_defeated_bonus":  5,
		"echo_survived_bonus":   10,
		"speed_bonus_pct":       0.15,
		"speed_bonus_threshold": 5,
		"redo_penalty_per_run":  0.10,
		"redo_penalty_floor":    0.50,
		"defeat_factor":         0.25,
		"rank_thresholds": {
			"S": 0.90,
			"A": 0.75,
			"B": 0.55,
			"C": 0.35,
			"D": 0.15,
		},
	}


static func _make_save() -> Dictionary:
	return { "economy": { "ase": 0, "ekwan": 0 } }


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("reward/compute_base_only",        Callable(EconomyRewardTests, "_t_compute_base_only"))
	runner.register_test("reward/compute_multi_objectives", Callable(EconomyRewardTests, "_t_compute_multi_objectives"))
	runner.register_test("reward/compute_enemy_bonus",      Callable(EconomyRewardTests, "_t_compute_enemy_bonus"))
	runner.register_test("reward/compute_echo_bonus",       Callable(EconomyRewardTests, "_t_compute_echo_bonus"))
	runner.register_test("reward/compute_speed_bonus",      Callable(EconomyRewardTests, "_t_compute_speed_bonus"))
	runner.register_test("reward/no_speed_bonus_slow",      Callable(EconomyRewardTests, "_t_no_speed_bonus_slow"))
	runner.register_test("reward/redo_multiplier_floor",    Callable(EconomyRewardTests, "_t_redo_multiplier_floor"))
	runner.register_test("reward/redo_multiplier_partial",  Callable(EconomyRewardTests, "_t_redo_multiplier_partial"))
	runner.register_test("reward/defeat_payout",            Callable(EconomyRewardTests, "_t_defeat_payout"))
	runner.register_test("reward/rank_S_first_run",         Callable(EconomyRewardTests, "_t_rank_S_first_run"))
	runner.register_test("reward/rank_F_poor_performance",  Callable(EconomyRewardTests, "_t_rank_F_poor_performance"))
	runner.register_test("reward/economy_service_adds_ase", Callable(EconomyRewardTests, "_t_economy_service_adds_ase"))


# ─── Test 1 — single combat objective → base = 30 ────────────────────────────
static func _t_compute_base_only() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 0, _default_cfg())
	if int(result.get("base_reward", -1)) != 30:
		return { "ok": false, "error": "Expected base_reward=30, got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 2 — combat + shrine + boss → base = 130 ────────────────────────────
static func _t_compute_multi_objectives() -> Dictionary:
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS,   3),
	]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 0, _default_cfg())
	if int(result.get("base_reward", -1)) != 130:
		return { "ok": false, "error": "Expected base_reward=130 (30+40+60), got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 3 — 3 enemies defeated → enemy_bonus = 15 ──────────────────────────
static func _t_compute_enemy_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 3, 3, 0, 0, 10, 0, _default_cfg())
	if int(result.get("enemy_bonus", -1)) != 15:
		return { "ok": false, "error": "Expected enemy_bonus=15 (3×5), got %d" % result.get("enemy_bonus", -1) }
	return { "ok": true }


# ─── Test 4 — 2 echoes survived → echo_bonus = 20 ────────────────────────────
static func _t_compute_echo_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 2, 2, 10, 0, _default_cfg())
	if int(result.get("echo_bonus", -1)) != 20:
		return { "ok": false, "error": "Expected echo_bonus=20 (2×10), got %d" % result.get("echo_bonus", -1) }
	return { "ok": true }


# ─── Test 5 — round_ended=3 (<5) → speed_bonus = roundi(30×0.15) = 5 ─────────
static func _t_compute_speed_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 3, 0, _default_cfg())
	var expected := roundi(30.0 * 0.15)
	if int(result.get("speed_bonus", -1)) != expected:
		return { "ok": false, "error": "Expected speed_bonus=%d, got %d" % [expected, result.get("speed_bonus", -1)] }
	return { "ok": true }


# ─── Test 6 — round_ended=5 (at threshold) → speed_bonus = 0 ────────────────
static func _t_no_speed_bonus_slow() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 5, 0, _default_cfg())
	if int(result.get("speed_bonus", -1)) != 0:
		return { "ok": false, "error": "Expected speed_bonus=0 at round 5, got %d" % result.get("speed_bonus", -1) }
	return { "ok": true }


# ─── Test 7 — run_count=8 → redo_mul clamped to floor 0.50 ──────────────────
static func _t_redo_multiplier_floor() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 8, _default_cfg())
	var redo := float(result.get("redo_multiplier", -1.0))
	if abs(redo - 0.50) > 0.001:
		return { "ok": false, "error": "Expected redo_multiplier=0.50, got %f" % redo }
	return { "ok": true }


# ─── Test 8 — run_count=3 → redo_mul = 1.0 - 0.3 = 0.70 ────────────────────
static func _t_redo_multiplier_partial() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 3, _default_cfg())
	var redo := float(result.get("redo_multiplier", -1.0))
	if abs(redo - 0.70) > 0.001:
		return { "ok": false, "error": "Expected redo_multiplier=0.70, got %f" % redo }
	return { "ok": true }


# ─── Test 9 — defeat: total = round(base×0.25×redo_mul) ─────────────────────
static func _t_defeat_payout() -> Dictionary:
	var save := _make_save()
	var svc  := EconomyService.new(save)
	# base = 30, redo_mul = 1.0 (run_count=0), defeat total = round(30×0.25×1.0) = 8
	var result := svc.reward_stage_complete(
		false, 30, 0, 0, 0, 0, 0, 1.0, "F", null, 0
	)
	var expected := roundi(30.0 * 0.25 * 1.0)
	if int(result.get("ase_awarded", -1)) != expected:
		return { "ok": false, "error": "Expected defeat payout=%d, got %d" % [expected, result.get("ase_awarded", -1)] }
	return { "ok": true }


# ─── Test 10 — perfect score + run_count=0 → rank = "S" ──────────────────────
static func _t_rank_S_first_run() -> Dictionary:
	# Victory, all 5 enemies killed, all 5 echoes survived, fast run (round 2), first run
	# base=130 (combat+shrine+boss), max_possible = 130+(5×5)+(5×10)+round(130×0.15) = 130+25+50+20 = 225
	# pre_redo = 130 + 25 + 50 + 20 = 225, perf_ratio = 225/225 = 1.0, rank_score = 1.0 → S
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS,   3),
	]
	var result := RewardCalc.compute(true, objs, 5, 5, 5, 5, 2, 0, _default_cfg())
	if str(result.get("rank", "")) != "S":
		return { "ok": false, "error": "Expected rank=S, got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 11 — defeat + run_count=5 → rank = "F" ────────────────────────────
static func _t_rank_F_poor_performance() -> Dictionary:
	# Defeat scenario: base=30, 1 enemy on board (total), 1 echo total, slow round, run_count=5
	# defeat_numerator = round(30×0.25) = 8
	# max_possible = 30 + (1×5) + (1×10) + round(30×0.15) = 30+5+10+4 = 49
	# rank_score = (8/49) × 0.50 = 0.082 → F
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(false, objs, 0, 1, 0, 1, 10, 5, _default_cfg())
	if str(result.get("rank", "")) != "F":
		return { "ok": false, "error": "Expected rank=F (defeat+run_count=5), got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 12 — reward_stage_complete() adds correct Ase to save ──────────────
static func _t_economy_service_adds_ase() -> Dictionary:
	var save := _make_save()
	var svc  := EconomyService.new(save)
	# victory, base=30, 2 enemy bonus=10, 1 echo bonus=10, no speed, redo=1.0
	# total = (30+10+10) × 1.0 = 50
	var result := svc.reward_stage_complete(
		true, 30, 10, 2, 10, 1, 0, 1.0, "B", null, 0
	)
	var ase_after := int(save.get("economy", {}).get("ase", -1))
	if ase_after != 50:
		return { "ok": false, "error": "Expected save.economy.ase=50, got %d" % ase_after }
	if int(result.get("ase_awarded", -1)) != 50:
		return { "ok": false, "error": "Expected ase_awarded=50, got %d" % result.get("ase_awarded", -1) }
	return { "ok": true }
