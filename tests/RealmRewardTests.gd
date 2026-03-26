# res://tests/RealmRewardTests.gd
# REALM-005: Tests for RealmService.calculate_stage_reward().
#
# Tests:
#   1. realm_reward/courage_stage0_first_realm  — stage=0, courage, run_index=0 → roundi((10+0)×1.0)=10
#   2. realm_reward/wisdom_stage2_first_realm   — stage=2, wisdom,  run_index=0 → roundi((15+10)×1.0)=25
#   3. realm_reward/wisdom_stage0_second_realm  — stage=0, wisdom,  run_index=1 → roundi((15+0)×1.5)=23
#   4. realm_reward/determinism                 — same inputs twice → identical output
#   5. realm_reward/unknown_virtue_zero         — unknown virtue, run_index=0   → 0, no crash

extends RefCounted
class_name RealmRewardTests


# ─── Helpers ────────────────────────────────────────────────────────────────

static func _default_cfg() -> Dictionary:
	return {
		"virtue_bonuses": {
			"courage": 10,
			"wisdom":  15,
			"faith":   20
		},
		"stage_index_bonus_per":       5,
		"realm_order_multiplier_base": 1.0,
		"realm_order_multiplier_step": 0.5,
	}


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("realm_reward/courage_stage0_first_realm",  Callable(RealmRewardTests, "_t_courage_stage0_first_realm"))
	runner.register_test("realm_reward/wisdom_stage2_first_realm",   Callable(RealmRewardTests, "_t_wisdom_stage2_first_realm"))
	runner.register_test("realm_reward/wisdom_stage0_second_realm",  Callable(RealmRewardTests, "_t_wisdom_stage0_second_realm"))
	runner.register_test("realm_reward/determinism",                 Callable(RealmRewardTests, "_t_determinism"))
	runner.register_test("realm_reward/unknown_virtue_zero",         Callable(RealmRewardTests, "_t_unknown_virtue_zero"))


# ─── Test 1 — courage, stage 0, first realm → virtue_bonus = roundi((10+0)×1.0) = 10 ────
static func _t_courage_stage0_first_realm() -> Dictionary:
	var result := RealmService.calculate_stage_reward(0, "courage", 0, _default_cfg())

	var vb := int(result.get("virtue_bonus", -1))
	if vb != 10:
		return { "ok": false, "error": "Expected virtue_bonus=10, got %d" % vb }

	var fi: Dictionary = result.get("formula_inputs", {})
	if int(fi.get("stage_index", -1)) != 0:
		return { "ok": false, "error": "formula_inputs.stage_index should be 0, got %s" % str(fi.get("stage_index")) }
	if int(fi.get("run_index", -1)) != 0:
		return { "ok": false, "error": "formula_inputs.run_index should be 0, got %s" % str(fi.get("run_index")) }

	return { "ok": true }


# ─── Test 2 — wisdom, stage 2, first realm → virtue_bonus = roundi((15+10)×1.0) = 25 ────
static func _t_wisdom_stage2_first_realm() -> Dictionary:
	var result := RealmService.calculate_stage_reward(2, "wisdom", 0, _default_cfg())

	var vb := int(result.get("virtue_bonus", -1))
	if vb != 25:
		return { "ok": false, "error": "Expected virtue_bonus=25, got %d" % vb }

	return { "ok": true }


# ─── Test 3 — wisdom, stage 0, second realm → virtue_bonus = roundi((15+0)×1.5) = 23 ───
static func _t_wisdom_stage0_second_realm() -> Dictionary:
	var result := RealmService.calculate_stage_reward(0, "wisdom", 1, _default_cfg())

	var vb := int(result.get("virtue_bonus", -1))
	if vb != 23:
		return { "ok": false, "error": "Expected virtue_bonus=23 (roundi(15×1.5)), got %d" % vb }

	var fi: Dictionary = result.get("formula_inputs", {})
	var mul: float = float(fi.get("order_multiplier", -1.0))
	if abs(mul - 1.5) > 0.001:
		return { "ok": false, "error": "Expected order_multiplier=1.5, got %f" % mul }

	return { "ok": true }


# ─── Test 4 — determinism: same inputs → identical output ───────────────────
static func _t_determinism() -> Dictionary:
	var cfg := _default_cfg()
	var r1 := RealmService.calculate_stage_reward(2, "faith", 2, cfg)
	var r2 := RealmService.calculate_stage_reward(2, "faith", 2, cfg)

	var vb1 := int(r1.get("virtue_bonus", -1))
	var vb2 := int(r2.get("virtue_bonus", -1))
	if vb1 != vb2:
		return { "ok": false, "error": "Non-deterministic: first call=%d, second call=%d" % [vb1, vb2] }

	if vb1 < 0:
		return { "ok": false, "error": "virtue_bonus should be non-negative, got %d" % vb1 }

	return { "ok": true }


# ─── Test 5 — unknown virtue → 0, no crash ───────────────────────────────────
static func _t_unknown_virtue_zero() -> Dictionary:
	var result := RealmService.calculate_stage_reward(0, "unknown_virtue", 0, _default_cfg())

	var vb := int(result.get("virtue_bonus", -1))
	if vb != 0:
		return { "ok": false, "error": "Expected virtue_bonus=0 for unknown virtue, got %d" % vb }

	if not result.has("formula_inputs"):
		return { "ok": false, "error": "formula_inputs key missing" }

	return { "ok": true }
