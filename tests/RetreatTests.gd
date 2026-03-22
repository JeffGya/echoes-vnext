# res://tests/RetreatTests.gd
# UI-004: Tests for RetreatService — speed gate, agi chance tier, roll, and filtering.
#
#   1. retreat/can_attempt_when_echo_faster
#   2. retreat/cannot_attempt_when_equal_speed
#   3. retreat/cannot_attempt_when_echo_slower
#   4. retreat/tier_guaranteed_from_high_agi_delta
#   5. retreat/tier_risky_from_negative_agi_delta
#   6. retreat/roll_success_at_100pct
#   7. retreat/roll_failure_at_0pct
#   8. retreat/excludes_dead_and_structures
#
# All tests are pure unit tests — no FlowRuntime, no save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name RetreatTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("retreat/can_attempt_when_echo_faster",            Callable(RetreatTests, "_t_can_attempt_when_echo_faster"))
	runner.register_test("retreat/cannot_attempt_when_equal_speed",         Callable(RetreatTests, "_t_cannot_attempt_when_equal_speed"))
	runner.register_test("retreat/cannot_attempt_when_echo_slower",         Callable(RetreatTests, "_t_cannot_attempt_when_echo_slower"))
	runner.register_test("retreat/tier_guaranteed_from_high_agi_delta",     Callable(RetreatTests, "_t_tier_guaranteed"))
	runner.register_test("retreat/tier_risky_from_negative_agi_delta",      Callable(RetreatTests, "_t_tier_risky"))
	runner.register_test("retreat/roll_success_at_100pct",                  Callable(RetreatTests, "_t_roll_success_at_100"))
	runner.register_test("retreat/roll_failure_at_0pct",                    Callable(RetreatTests, "_t_roll_failure_at_0"))
	runner.register_test("retreat/excludes_dead_and_structures",            Callable(RetreatTests, "_t_excludes_dead_and_structures"))


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

## Builds a minimal live echo actor dict with given speed and agi.
static func _echo(speed: int, agi: int) -> Dictionary:
	return {
		"faction": "echo", "is_dead": false, "is_structure": false,
		"stats": { "speed": speed, "agi": agi, "max_hp": 80 },
	}

## Builds a minimal live enemy actor dict with given speed and agi.
static func _enemy(speed: int, agi: int) -> Dictionary:
	return {
		"faction": "enemy", "is_dead": false, "is_structure": false,
		"stats": { "speed": speed, "agi": agi, "max_hp": 80 },
	}

## Returns the standard 5-tier config array used in balance.json.
static func _tier_cfg() -> Array:
	return [
		{ "min_delta":   10, "label": "Guaranteed", "success_pct": 100 },
		{ "min_delta":    3, "label": "Low",         "success_pct":  80 },
		{ "min_delta":   -2, "label": "Moderate",    "success_pct":  60 },
		{ "min_delta":   -9, "label": "Risky",       "success_pct":  40 },
		{ "min_delta": -9999,"label": "Dangerous",   "success_pct":  20 },
	]


# ──────────────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────────────

# Test 1: can_attempt_when_echo_faster
# Echo avg speed 8 > enemy avg speed 6 → can_attempt true.
static func _t_can_attempt_when_echo_faster() -> Dictionary:
	var actors: Array = [_echo(8, 10), _enemy(6, 10)]
	if not RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=true when echo speed (8) > enemy speed (6)" }
	return { "ok": true }


# Test 2: cannot_attempt_when_equal_speed
# Echo avg speed == enemy avg speed → can_attempt false (strictly greater required).
static func _t_cannot_attempt_when_equal_speed() -> Dictionary:
	var actors: Array = [_echo(6, 10), _enemy(6, 10)]
	if RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=false when echo speed (6) == enemy speed (6)" }
	return { "ok": true }


# Test 3: cannot_attempt_when_echo_slower
# Echo avg speed 4 < enemy avg speed 7 → can_attempt false.
static func _t_cannot_attempt_when_echo_slower() -> Dictionary:
	var actors: Array = [_echo(4, 10), _enemy(7, 10)]
	if RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=false when echo speed (4) < enemy speed (7)" }
	return { "ok": true }


# Test 4: tier_guaranteed_from_high_agi_delta
# Echo agi 30, enemy agi 15 → delta +15 ≥ +10 → Guaranteed tier (100%).
static func _t_tier_guaranteed() -> Dictionary:
	# Speed gate passes (echo faster).
	var actors: Array = [_echo(8, 30), _enemy(6, 15)]
	var tier: Dictionary = RetreatService.get_chance_tier(actors, _tier_cfg())
	if tier.is_empty():
		return { "ok": false, "error": "Expected a tier dict, got empty" }
	if str(tier.get("label", "")) != "Guaranteed":
		return { "ok": false, "error": "Expected label='Guaranteed', got: %s" % str(tier.get("label")) }
	if int(tier.get("success_pct", -1)) != 100:
		return { "ok": false, "error": "Expected success_pct=100, got: %d" % int(tier.get("success_pct")) }
	return { "ok": true }


# Test 5: tier_risky_from_negative_agi_delta
# Echo agi 10, enemy agi 15 → delta -5 → Risky tier (40%).
static func _t_tier_risky() -> Dictionary:
	var actors: Array = [_echo(8, 10), _enemy(6, 15)]
	var tier: Dictionary = RetreatService.get_chance_tier(actors, _tier_cfg())
	if tier.is_empty():
		return { "ok": false, "error": "Expected a tier dict, got empty" }
	if str(tier.get("label", "")) != "Risky":
		return { "ok": false, "error": "Expected label='Risky', got: %s" % str(tier.get("label")) }
	if int(tier.get("success_pct", -1)) != 40:
		return { "ok": false, "error": "Expected success_pct=40, got: %d" % int(tier.get("success_pct")) }
	return { "ok": true }


# Test 6: roll_success_at_100pct
# success_pct=100 → always returns { success: true } regardless of RNG.
static func _t_roll_success_at_100() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(10):
		var result: Dictionary = RetreatService.roll_retreat(100, rng)
		if not bool(result.get("success", false)):
			return { "ok": false, "error": "Expected success=true at 100%% success_pct (roll %d)" % i }
	return { "ok": true }


# Test 7: roll_failure_at_0pct
# success_pct=0 → always returns { success: false }.
static func _t_roll_failure_at_0() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(10):
		var result: Dictionary = RetreatService.roll_retreat(0, rng)
		if bool(result.get("success", true)):
			return { "ok": false, "error": "Expected success=false at 0%% success_pct (roll %d)" % i }
	return { "ok": true }


# Test 8: excludes_dead_and_structures
# A dead echo and a structure enemy should not affect averages.
# Live echo speed 8, dead echo speed 1 (should be ignored) → avg echo speed = 8.
# Live enemy speed 6, structure speed 100 (should be ignored) → avg enemy speed = 6.
# → can_attempt should be true (8 > 6).
static func _t_excludes_dead_and_structures() -> Dictionary:
	var dead_echo: Dictionary = {
		"faction": "echo", "is_dead": true, "is_structure": false,
		"stats": { "speed": 1, "agi": 1, "max_hp": 80 },
	}
	var shrine: Dictionary = {
		"faction": "enemy", "is_dead": false, "is_structure": true,
		"stats": { "speed": 100, "agi": 100, "max_hp": 200 },
	}
	var actors: Array = [_echo(8, 10), dead_echo, _enemy(6, 10), shrine]
	if not RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=true; dead/structure actors must be excluded from speed avg" }
	return { "ok": true }
