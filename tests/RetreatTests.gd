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
	runner.register_test("retreat/price_is_10_from_config",                 Callable(RetreatTests, "_t_price_from_config"))
	runner.register_test("retreat/denied_below_price",                      Callable(RetreatTests, "_t_denied_below_price"))
	runner.register_test("retreat/allowed_at_exact_price",                  Callable(RetreatTests, "_t_allowed_at_exact_price"))
	runner.register_test("retreat/allowed_above_price",                     Callable(RetreatTests, "_t_allowed_above_price"))
	runner.register_test("retreat/failed_retreat_still_spends",             Callable(RetreatTests, "_t_failed_retreat_spends"))
	runner.register_test("retreat/snapshot_affordable_and_price",           Callable(RetreatTests, "_t_snapshot_affordable"))
	runner.register_test("retreat/return_home_free_at_zero_ase",            Callable(RetreatTests, "_t_return_home_free"))


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


# ──────────────────────────────────────────────────────────────────────────────
# V2-ECONOMY-004 step 5.4: price 10 and denial (D-46, D-79). These drive a real FlowRuntime.
# ──────────────────────────────────────────────────────────────────────────────

## Runs one retreat dispatch at a fixed balance. The action carries a fake price (999) on purpose:
## the handler must ignore it and read the config.
static func _retreat_at(tag: String, ase: int, success_pct: int) -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for %s" % tag }
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.save_data["economy"]["ase"] = ase
	var snap: Dictionary = (env["runtime"] as FlowRuntime).dispatch(
		{ "type": "encounter.retreat", "ase_cost": 999, "success_pct": success_pct })
	return { "ok": true, "flow_ctx": flow_ctx, "snap": snap, "ase_after": int(flow_ctx.save_data["economy"]["ase"]) }


static func _t_price_from_config() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var cost: int = RetreatService.get_ase_cost(config)
	if cost != 10:
		return { "ok": false, "error": "expected retreat price 10 from data.combat.retreat_ase_cost, got %d" % cost }
	return { "ok": true }


static func _t_denied_below_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_denied", 9, 100)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	if int(r["ase_after"]) != 9:
		return { "ok": false, "error": "denied retreat changed the balance: 9 -> %d" % int(r["ase_after"]) }
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "denied retreat cleared the encounter" }
	if flow_ctx.pending_scout_return_ase != 0:
		return { "ok": false, "error": "denied retreat set a partial payout" }
	var denial: Variant = (r["snap"] as Dictionary).get("data", {}).get("retreat_denied", null)
	if not (denial is Dictionary) or str(denial.get("reason", "")) != "insufficient_ase" or int(denial.get("ase_cost", 0)) != 10:
		return { "ok": false, "error": "no retreat_denied outcome in the returned snapshot: %s" % str(denial) }
	return { "ok": true }


static func _t_allowed_at_exact_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_exact", 10, 100)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 0:
		return { "ok": false, "error": "expected balance 0 after a 10 Ase retreat from 10, got %d" % int(r["ase_after"]) }
	if (r["flow_ctx"] as FlowContext).encounter_ctx != null:
		return { "ok": false, "error": "paid retreat at 100%% did not leave the encounter" }
	return { "ok": true }


static func _t_allowed_above_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_above", 25, 100)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 15:
		return { "ok": false, "error": "expected balance 15 after retreat from 25, got %d" % int(r["ase_after"]) }
	return { "ok": true }


static func _t_failed_retreat_spends() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_fail", 25, 0)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 15:
		return { "ok": false, "error": "a failed retreat must still spend 10: expected 15, got %d" % int(r["ase_after"]) }
	if (r["flow_ctx"] as FlowContext).encounter_ctx == null:
		return { "ok": false, "error": "a failed retreat at 0%% must leave combat running" }
	return { "ok": true }


static func _t_snapshot_affordable() -> Dictionary:
	for case in [[9, false], [10, true], [11, true]]:
		var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "rt_snap_%d" % case[0])
		if env.is_empty():
			return { "ok": false, "error": "setup failed" }
		var flow_ctx: FlowContext = env["flow_ctx"]
		flow_ctx.save_data["economy"]["ase"] = case[0]
		var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 1)
		var data: Dictionary = snap.get("data", {})
		if int(data.get("retreat_ase_cost", -1)) != 10 or bool(data.get("retreat_affordable", not case[1])) != case[1]:
			return { "ok": false, "error": "balance %d: cost=%s affordable=%s" % [case[0], str(data.get("retreat_ase_cost")), str(data.get("retreat_affordable"))] }
	return { "ok": true }


static func _t_return_home_free() -> Dictionary:
	var env: Dictionary = PendingResultTests._drive_withdrawal("rt_home", 0)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var awarded: int = int(PendingResultTests._data_of(env["card"]).get("ase_awarded", -1))
	var ase: int = int(runtime.get_save_data()["economy"]["ase"])
	if ase != awarded:
		return { "ok": false, "error": "return home at 0 Ase: balance %d != partial %d, so something was spent" % [ase, awarded] }
	return { "ok": true }
