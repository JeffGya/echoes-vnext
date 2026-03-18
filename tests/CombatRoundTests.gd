# res://tests/CombatRoundTests.gd
# COMBAT-005: Tests for CombatState.check_end_condition() — updated and extended.
#
#   1. combat/end_condition_not_met_when_enemies_alive
#      1 living enemy + living echo → over=false, victory=false, reason="".
#   2. combat/end_condition_victory_all_enemies_dead
#      all enemies is_dead=true → over=true, victory=true, reason="all_enemies_defeated".
#   3. combat/end_condition_defeat_all_echoes_dead
#      dead echo + living enemy → over=true, victory=false, reason="all_echoes_dead".
#   4. combat/end_condition_reason_strings
#      reason="all_enemies_defeated" on victory; reason="" when not over.
#   5. combat/end_condition_victory_priority_when_all_dead
#      all actors dead → victory check runs first → victory=true, reason="all_enemies_defeated".
#   6. combat/end_condition_defeat_reason_string
#      reason="all_echoes_dead" and victory=false for defeat case.
#
# All tests are pure unit tests — no FlowRuntime, no save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatRoundTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat/end_condition_not_met_when_enemies_alive",      Callable(CombatRoundTests, "_t_not_met_when_enemies_alive"))
	runner.register_test("combat/end_condition_victory_all_enemies_dead",        Callable(CombatRoundTests, "_t_victory_all_enemies_dead"))
	runner.register_test("combat/end_condition_defeat_all_echoes_dead",          Callable(CombatRoundTests, "_t_defeat_all_echoes_dead"))
	runner.register_test("combat/end_condition_reason_strings",                  Callable(CombatRoundTests, "_t_reason_strings"))
	runner.register_test("combat/end_condition_victory_priority_when_all_dead",  Callable(CombatRoundTests, "_t_victory_priority_when_all_dead"))
	runner.register_test("combat/end_condition_defeat_reason_string",            Callable(CombatRoundTests, "_t_defeat_reason_string"))


# -------------------------
# Tests
# -------------------------

# Test 1: not_met_when_enemies_alive
# Living echo + living enemy → not over, not a victory or defeat.
static func _t_not_met_when_enemies_alive() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", true)) != false:
		return { "ok": false, "error": "Expected over=false with living enemy, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", true)) != false:
		return { "ok": false, "error": "Expected victory=false when not over, got: %s" % str(result.get("victory")) }

	return { "ok": true }


# Test 2: victory_all_enemies_dead
# All enemies have is_dead=true → over=true, victory=true.
static func _t_victory_all_enemies_dead() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": true  },
		{ "id": "enemy_02", "faction": "enemy", "is_dead": true  },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true when all enemies dead, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", false)) != true:
		return { "ok": false, "error": "Expected victory=true when all enemies dead, got: %s" % str(result.get("victory")) }

	return { "ok": true }


# Test 3: defeat_all_echoes_dead
# All echoes are dead but an enemy is still alive → defeat.
static func _t_defeat_all_echoes_dead() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": true  },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true when all echoes dead, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", true)) != false:
		return { "ok": false, "error": "Expected victory=false on defeat, got: %s" % str(result.get("victory")) }

	return { "ok": true }


# Test 4: reason_strings
# reason="all_enemies_defeated" on victory; reason="" when not over.
static func _t_reason_strings() -> Dictionary:
	# All enemies dead → reason should be "all_enemies_defeated".
	var actors_over: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": true  },
	]
	var r_over: Dictionary = CombatState.check_end_condition(actors_over, "defeat_enemies")
	if str(r_over.get("reason", "")) != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got: %s" % str(r_over.get("reason")) }

	# Living enemy → reason should be "".
	var actors_not_over: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var r_not: Dictionary = CombatState.check_end_condition(actors_not_over, "defeat_enemies")
	if str(r_not.get("reason", "X")) != "":
		return { "ok": false, "error": "Expected reason='' when not over, got: %s" % str(r_not.get("reason")) }

	return { "ok": true }


# Test 5: victory_priority_when_all_dead
# All actors dead (echoes and enemies) → victory check runs first → victory=true.
static func _t_victory_priority_when_all_dead() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": true },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": true },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true when all actors dead, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", false)) != true:
		return { "ok": false, "error": "Expected victory=true (victory check first), got: %s" % str(result.get("victory")) }
	if str(result.get("reason", "")) != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated' (victory first), got: %s" % str(result.get("reason")) }

	return { "ok": true }


# Test 6: defeat_reason_string
# All echoes dead + living enemy → reason="all_echoes_dead", victory=false.
static func _t_defeat_reason_string() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "is_dead": true  },
		{ "id": "echo_02",  "faction": "echo",  "is_dead": true  },
		{ "id": "enemy_01", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if str(result.get("reason", "")) != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got: %s" % str(result.get("reason")) }
	if bool(result.get("victory", true)) != false:
		return { "ok": false, "error": "Expected victory=false on defeat, got: %s" % str(result.get("victory")) }

	return { "ok": true }
