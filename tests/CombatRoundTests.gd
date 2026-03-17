# res://tests/CombatRoundTests.gd
# COMBAT-004: Tests for CombatState.check_end_condition() — pure static end condition check.
#
#   1. combat/end_condition_not_met_when_enemies_alive
#      1 living enemy → over=false, reason="".
#   2. combat/end_condition_met_when_all_enemies_dead
#      all enemies is_dead=true → over=true, reason="all_enemies_dead".
#   3. combat/end_condition_ignores_dead_echoes
#      dead echo + living enemy → over=false (echo deaths don't end combat).
#   4. combat/end_condition_reason_string
#      reason is exactly "all_enemies_dead" when over=true; reason="" when not over.
#
# All tests are pure unit tests — no FlowRuntime, no save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatRoundTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat/end_condition_not_met_when_enemies_alive",    Callable(CombatRoundTests, "_t_not_met_when_enemies_alive"))
	runner.register_test("combat/end_condition_met_when_all_enemies_dead",     Callable(CombatRoundTests, "_t_met_when_all_enemies_dead"))
	runner.register_test("combat/end_condition_ignores_dead_echoes",           Callable(CombatRoundTests, "_t_ignores_dead_echoes"))
	runner.register_test("combat/end_condition_reason_string",                 Callable(CombatRoundTests, "_t_reason_string"))


# -------------------------
# Tests
# -------------------------

# Test 1: not_met_when_enemies_alive
# 1 living enemy present → over=false.
static func _t_not_met_when_enemies_alive() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", true)) != false:
		return { "ok": false, "error": "Expected over=false with living enemy, got: %s" % str(result.get("over")) }

	return { "ok": true }


# Test 2: met_when_all_enemies_dead
# All enemies have is_dead=true → over=true.
static func _t_met_when_all_enemies_dead() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": true  },
		{ "id": "enemy_02", "faction": "enemy", "is_dead": true  },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true when all enemies dead, got: %s" % str(result.get("over")) }

	return { "ok": true }


# Test 3: ignores_dead_echoes
# Dead echo + living enemy → over=false (echo deaths don't trigger end condition).
static func _t_ignores_dead_echoes() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": true  },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", true)) != false:
		return { "ok": false, "error": "Expected over=false when echo is dead but enemy is alive, got: %s" % str(result.get("over")) }

	return { "ok": true }


# Test 4: reason_string
# reason="all_enemies_dead" when over=true; reason="" when not over.
static func _t_reason_string() -> Dictionary:
	# All enemies dead → reason should be "all_enemies_dead".
	var actors_over: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": true  },
	]
	var r_over: Dictionary = CombatState.check_end_condition(actors_over, "defeat_enemies")
	if str(r_over.get("reason", "")) != "all_enemies_dead":
		return { "ok": false, "error": "Expected reason='all_enemies_dead', got: %s" % str(r_over.get("reason")) }

	# Living enemy → reason should be "".
	var actors_not_over: Array = [
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var r_not: Dictionary = CombatState.check_end_condition(actors_not_over, "defeat_enemies")
	if str(r_not.get("reason", "X")) != "":
		return { "ok": false, "error": "Expected reason='' when not over, got: %s" % str(r_not.get("reason")) }

	return { "ok": true }
