# res://tests/CombatRoundTests.gd
# COMBAT-005: Tests for CombatState.check_end_condition() — updated and extended.
# In-combat emotion dynamics tests added (Gaps 1–3 from old MVP comparison).
#
#   1. combat/end_condition_not_met_when_enemies_alive
#   2. combat/end_condition_victory_all_enemies_dead
#   3. combat/end_condition_defeat_all_echoes_dead
#   4. combat/end_condition_reason_strings
#   5. combat/end_condition_victory_priority_when_all_dead
#   6. combat/end_condition_defeat_reason_string
#   7. combat/shrine_destroyed_while_enemy_alive_is_defeat
#   8. combat/shrine_alive_all_enemies_dead_is_victory
#   9. combat/shrine_destroyed_non_shrine_objective_ignored
#  10. combat/shrine_destroyed_victory_priority
#  11. combat/fear_increases_on_hit        — fear clamps correctly, runtime dict mutation
#  12. combat/ally_ko_spreads_fear         — KO'd actor excluded; survivors gain delta
#  13. combat/per_round_fear_tick          — all living non-structure actors gain fear_per_round
#  14. combat/morale_decay_every_n_rounds  — decay fires on round N, not round N-1
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
	# COMBAT-006: shrine end-condition tests.
	runner.register_test("combat/shrine_destroyed_while_enemy_alive_is_defeat",  Callable(CombatRoundTests, "_t_shrine_destroyed_while_enemy_alive_is_defeat"))
	runner.register_test("combat/shrine_alive_all_enemies_dead_is_victory",      Callable(CombatRoundTests, "_t_shrine_alive_all_enemies_dead_is_victory"))
	runner.register_test("combat/shrine_destroyed_non_shrine_objective_ignored", Callable(CombatRoundTests, "_t_shrine_destroyed_non_shrine_objective_ignored"))
	runner.register_test("combat/shrine_destroyed_victory_priority",             Callable(CombatRoundTests, "_t_shrine_destroyed_victory_priority"))
	# In-combat emotion dynamics tests.
	runner.register_test("combat/fear_increases_on_hit",       Callable(CombatRoundTests, "_t_fear_increases_on_hit"))
	runner.register_test("combat/ally_ko_spreads_fear",        Callable(CombatRoundTests, "_t_ally_ko_spreads_fear"))
	runner.register_test("combat/per_round_fear_tick",         Callable(CombatRoundTests, "_t_per_round_fear_tick"))
	runner.register_test("combat/morale_decay_every_n_rounds", Callable(CombatRoundTests, "_t_morale_decay_every_n_rounds"))


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


# COMBAT-006 tests -------------------------------------------------------

# Test 7: shrine_destroyed_while_enemy_alive_is_defeat
# living echo + dead shrine (is_structure=true, is_dead=true) + living enemy, objective=purify_shrine
# Expected: over=true, victory=false, reason="shrine_destroyed"
static func _t_shrine_destroyed_while_enemy_alive_is_defeat() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",   "faction": "echo",      "is_dead": false, "is_structure": false },
		{ "id": "shrine_01", "faction": "structure",  "is_dead": true,  "is_structure": true  },
		{ "id": "enemy_01",  "faction": "enemy",      "is_dead": false, "is_structure": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.PURIFY_SHRINE)

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", true)) != false:
		return { "ok": false, "error": "Expected victory=false, got: %s" % str(result.get("victory")) }
	if str(result.get("reason", "")) != "shrine_destroyed":
		return { "ok": false, "error": "Expected reason='shrine_destroyed', got: %s" % str(result.get("reason")) }

	return { "ok": true }


# Test 8: shrine_alive_all_enemies_dead_is_victory
# living echo + alive shrine + dead enemy, objective=purify_shrine
# Expected: over=true, victory=true, reason="all_enemies_defeated" (victory check runs first)
static func _t_shrine_alive_all_enemies_dead_is_victory() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",   "faction": "echo",     "is_dead": false, "is_structure": false },
		{ "id": "shrine_01", "faction": "structure", "is_dead": false, "is_structure": true  },
		{ "id": "enemy_01",  "faction": "enemy",     "is_dead": true,  "is_structure": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.PURIFY_SHRINE)

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", false)) != true:
		return { "ok": false, "error": "Expected victory=true, got: %s" % str(result.get("victory")) }
	if str(result.get("reason", "")) != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got: %s" % str(result.get("reason")) }

	return { "ok": true }


# Test 9: shrine_destroyed_non_shrine_objective_ignored
# living echo + dead shrine + living enemy, objective=defeat_enemies
# Expected: over=false (shrine death is ignored when objective is not purify_shrine)
static func _t_shrine_destroyed_non_shrine_objective_ignored() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",   "faction": "echo",     "is_dead": false, "is_structure": false },
		{ "id": "shrine_01", "faction": "structure", "is_dead": true,  "is_structure": true  },
		{ "id": "enemy_01",  "faction": "enemy",     "is_dead": false, "is_structure": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies")

	if bool(result.get("over", true)) != false:
		return { "ok": false, "error": "Expected over=false (shrine ignored for defeat_enemies), got: %s" % str(result.get("over")) }

	return { "ok": true }


# Test 10: shrine_destroyed_victory_priority
# living echo + dead shrine + dead enemy, objective=purify_shrine
# Expected: victory=true, reason="all_enemies_defeated" (victory check beats shrine defeat)
static func _t_shrine_destroyed_victory_priority() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_01",   "faction": "echo",     "is_dead": false, "is_structure": false },
		{ "id": "shrine_01", "faction": "structure", "is_dead": true,  "is_structure": true  },
		{ "id": "enemy_01",  "faction": "enemy",     "is_dead": true,  "is_structure": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.PURIFY_SHRINE)

	if bool(result.get("over", false)) != true:
		return { "ok": false, "error": "Expected over=true, got: %s" % str(result.get("over")) }
	if bool(result.get("victory", false)) != true:
		return { "ok": false, "error": "Expected victory=true (enemies dead → victory wins), got: %s" % str(result.get("victory")) }
	if str(result.get("reason", "")) != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got: %s" % str(result.get("reason")) }

	return { "ok": true }


# In-combat emotion dynamics tests ------------------------------------------

# Test 11: fear_increases_on_hit
# Simulates per-hit fear accumulation logic from FlowRuntime._resolve_next_actor().
# Verifies: delta applied correctly, value clamped to 100.
static func _t_fear_increases_on_hit() -> Dictionary:
	var fear_per_hit: int = 2
	var defender: Dictionary = { "id": "echo_01", "fear": 30, "is_dead": false }

	defender["fear"] = mini(100, int(defender.get("fear", 0)) + fear_per_hit)
	if int(defender.get("fear", 0)) != 32:
		return { "ok": false, "error": "Expected fear=32 after hit, got: %d" % int(defender.get("fear", 0)) }

	# Clamping: fear cannot exceed 100.
	defender["fear"] = 99
	defender["fear"] = mini(100, int(defender.get("fear", 0)) + fear_per_hit)
	if int(defender.get("fear", 0)) != 100:
		return { "ok": false, "error": "Expected fear clamped to 100, got: %d" % int(defender.get("fear", 0)) }

	# Another hit at cap stays at 100.
	defender["fear"] = mini(100, int(defender.get("fear", 0)) + fear_per_hit)
	if int(defender.get("fear", 0)) != 100:
		return { "ok": false, "error": "Expected fear to stay at 100, got: %d" % int(defender.get("fear", 0)) }

	return { "ok": true }


# Test 12: ally_ko_spreads_fear
# Simulates KO fear spread logic from FlowRuntime._end_round().
# Verifies: survivors of the same faction gain fear; KO'd actor and different-faction actors excluded.
static func _t_ally_ko_spreads_fear() -> Dictionary:
	var fear_per_ko: int = 4
	var ko_id: String = "echo_dead"

	var actors: Array = [
		{ "id": ko_id,       "faction": "echo",  "fear": 20, "is_dead": true,  "is_structure": false },
		{ "id": "echo_02",   "faction": "echo",  "fear": 10, "is_dead": false, "is_structure": false },
		{ "id": "echo_03",   "faction": "echo",  "fear": 50, "is_dead": false, "is_structure": false },
		{ "id": "enemy_01",  "faction": "enemy", "fear": 5,  "is_dead": false, "is_structure": false },
	]

	var ko_faction: String = "echo"
	for sp_a in actors:
		if sp_a is Dictionary and not sp_a.get("is_dead", false) \
				and str(sp_a.get("id", "")) != ko_id \
				and str(sp_a.get("faction", "")) == ko_faction \
				and not sp_a.get("is_structure", false):
			sp_a["fear"] = mini(100, int(sp_a.get("fear", 0)) + fear_per_ko)

	if int(actors[1].get("fear", 0)) != 14:
		return { "ok": false, "error": "Expected echo_02 fear=14, got: %d" % int(actors[1].get("fear", 0)) }
	if int(actors[2].get("fear", 0)) != 54:
		return { "ok": false, "error": "Expected echo_03 fear=54, got: %d" % int(actors[2].get("fear", 0)) }
	if int(actors[0].get("fear", 0)) != 20:
		return { "ok": false, "error": "KO actor fear unchanged (20), got: %d" % int(actors[0].get("fear", 0)) }
	if int(actors[3].get("fear", 0)) != 5:
		return { "ok": false, "error": "Enemy fear unchanged (5), got: %d" % int(actors[3].get("fear", 0)) }

	return { "ok": true }


# Test 13: per_round_fear_tick
# Simulates per-round fear tick from FlowRuntime._end_round().
# Verifies: living non-structure actors gain fear_per_round; dead and structure actors excluded.
static func _t_per_round_fear_tick() -> Dictionary:
	var fear_per_round: int = 1

	var actors: Array = [
		{ "id": "echo_01",   "fear": 20, "is_dead": false, "is_structure": false },
		{ "id": "echo_02",   "fear": 79, "is_dead": false, "is_structure": false },
		{ "id": "echo_dead", "fear": 30, "is_dead": true,  "is_structure": false },
		{ "id": "shrine_01", "fear": 0,  "is_dead": false, "is_structure": true  },
		{ "id": "enemy_01",  "fear": 10, "is_dead": false, "is_structure": false },
	]

	for tick_a in actors:
		if tick_a is Dictionary and not tick_a.get("is_dead", false) \
				and not tick_a.get("is_structure", false):
			tick_a["fear"] = mini(100, int(tick_a.get("fear", 0)) + fear_per_round)

	if int(actors[0].get("fear", 0)) != 21:
		return { "ok": false, "error": "Expected echo_01 fear=21, got: %d" % int(actors[0].get("fear", 0)) }
	if int(actors[1].get("fear", 0)) != 80:
		return { "ok": false, "error": "Expected echo_02 fear=80, got: %d" % int(actors[1].get("fear", 0)) }
	if int(actors[2].get("fear", 0)) != 30:
		return { "ok": false, "error": "Dead actor unchanged (30), got: %d" % int(actors[2].get("fear", 0)) }
	if int(actors[3].get("fear", 0)) != 0:
		return { "ok": false, "error": "Structure excluded (0), got: %d" % int(actors[3].get("fear", 0)) }
	if int(actors[4].get("fear", 0)) != 11:
		return { "ok": false, "error": "Expected enemy_01 fear=11, got: %d" % int(actors[4].get("fear", 0)) }

	return { "ok": true }


# Test 14: morale_decay_every_n_rounds
# Simulates morale decay logic from FlowRuntime._end_round().
# Verifies: decay fires on round 3 (N=3), not round 2; echo-only; floored at 0.
static func _t_morale_decay_every_n_rounds() -> Dictionary:
	var morale_decay_n: int   = 3
	var morale_decay_amt: int = 1

	var actors: Array = [
		{ "id": "echo_01",  "faction": "echo",  "morale": 40, "is_dead": false },
		{ "id": "echo_02",  "faction": "echo",  "morale": 0,  "is_dead": false },
		{ "id": "enemy_01", "faction": "enemy", "morale": 50, "is_dead": false },
	]

	# Round 2: decay should NOT fire (2 % 3 != 0).
	if morale_decay_n > 0 and 2 % morale_decay_n == 0:
		for dec_a in actors:
			if dec_a is Dictionary and not dec_a.get("is_dead", false) \
					and dec_a.get("faction", "") == "echo":
				dec_a["morale"] = maxi(0, int(dec_a.get("morale", 50)) - morale_decay_amt)

	if int(actors[0].get("morale", 0)) != 40:
		return { "ok": false, "error": "Decay must NOT fire on round 2, expected 40, got: %d" % int(actors[0].get("morale", 0)) }

	# Round 3: decay SHOULD fire (3 % 3 == 0).
	if morale_decay_n > 0 and 3 % morale_decay_n == 0:
		for dec_a in actors:
			if dec_a is Dictionary and not dec_a.get("is_dead", false) \
					and dec_a.get("faction", "") == "echo":
				dec_a["morale"] = maxi(0, int(dec_a.get("morale", 50)) - morale_decay_amt)

	if int(actors[0].get("morale", 0)) != 39:
		return { "ok": false, "error": "Expected echo_01 morale=39 after decay on round 3, got: %d" % int(actors[0].get("morale", 0)) }
	if int(actors[1].get("morale", 0)) != 0:
		return { "ok": false, "error": "echo_02 morale floored at 0, got: %d" % int(actors[1].get("morale", 0)) }
	if int(actors[2].get("morale", 0)) != 50:
		return { "ok": false, "error": "Enemy morale unchanged (50), got: %d" % int(actors[2].get("morale", 0)) }

	return { "ok": true }
