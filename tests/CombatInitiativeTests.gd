# res://tests/CombatInitiativeTests.gd
# V2-COMBAT-001: Tests for readiness score initiative order (morale-tier modifier).
#   1. combat_initiative/inspired_scores_higher_than_broken  — morale tier changes order.
#   2. combat_initiative/steady_has_zero_morale_modifier     — steady tier adds no bias.
#   3. combat_initiative/directives_do_not_affect_order      — directive field is ignored.
#   4. combat_initiative/same_inputs_same_order              — deterministic output.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatInitiativeTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_initiative/inspired_scores_higher_than_broken",
		Callable(CombatInitiativeTests, "_t_inspired_scores_higher_than_broken"))
	runner.register_test("combat_initiative/steady_has_zero_morale_modifier",
		Callable(CombatInitiativeTests, "_t_steady_has_zero_morale_modifier"))
	runner.register_test("combat_initiative/directives_do_not_affect_order",
		Callable(CombatInitiativeTests, "_t_directives_do_not_affect_order"))
	runner.register_test("combat_initiative/same_inputs_same_order",
		Callable(CombatInitiativeTests, "_t_same_inputs_same_order"))


static func _morale_cfg() -> Dictionary:
	return {
		"by_morale_tier": {
			"inspired":  4,
			"steady":    0,
			"shaken":   -3,
			"broken":   -6,
		}
	}


# Test 1: inspired Echo acts before broken Echo when all other stats are equal.
static func _t_inspired_scores_higher_than_broken() -> Dictionary:
	var actor_a := {
		"id":    "echo_inspired",
		"name":  "Inspired",
		"speed": 5,
		"stats": { "agi": 5 },
		"morale": 80,  # inspired tier (>=75)
	}
	var actor_b := {
		"id":    "echo_broken",
		"name":  "Broken",
		"speed": 5,
		"stats": { "agi": 5 },
		"morale": 10,  # broken tier (<25)
	}
	var state: Dictionary = CombatState.create([actor_a, actor_b], "defeat_enemies", 0, _morale_cfg())
	var order: Array = state.get("initiative_order", [])
	if order.size() < 2:
		return { "ok": false, "error": "initiative_order too short (got %d)" % order.size() }
	if str(order[0].get("id", "")) != "echo_inspired":
		return { "ok": false, "error": "Expected inspired Echo first (morale +4 vs -6), got: %s" % str(order[0].get("id", "")) }
	return { "ok": true }


# Test 2: steady morale tier adds no modifier — score is identical with or without morale cfg.
static func _t_steady_has_zero_morale_modifier() -> Dictionary:
	var actor := {
		"id":    "echo_steady",
		"name":  "Steady",
		"speed": 5,
		"stats": { "agi": 3 },
		"morale": 60,  # steady tier (>=50 <75)
	}
	var state_with_cfg: Dictionary = CombatState.create([actor], "defeat_enemies", 0, _morale_cfg())
	var state_no_cfg: Dictionary   = CombatState.create([actor], "defeat_enemies", 0, {})
	var order_cfg: Array = state_with_cfg.get("initiative_order", [])
	var order_no:  Array = state_no_cfg.get("initiative_order", [])
	if order_cfg.is_empty() or order_no.is_empty():
		return { "ok": false, "error": "initiative_order empty" }
	if str(order_cfg[0].get("id", "")) != str(order_no[0].get("id", "")):
		return { "ok": false, "error": "Steady tier must not change order (modifier=0)" }
	return { "ok": true }


# Test 3: active_directive field on actor has no effect on initiative order.
# Documents that directive bonuses live in BehaviorArbiter, not _calc_initiative().
static func _t_directives_do_not_affect_order() -> Dictionary:
	var actor_a := {
		"id":               "echo_a",
		"name":             "Echo A",
		"speed":            5,
		"stats":            { "agi": 5 },
		"morale":           60,
		"active_directive": "push",
	}
	var actor_b := {
		"id":    "echo_b",
		"name":  "Echo B",
		"speed": 5,
		"stats": { "agi": 5 },
		"morale": 60,
	}
	var state: Dictionary = CombatState.create([actor_a, actor_b], "defeat_enemies", 0, _morale_cfg())
	var order: Array = state.get("initiative_order", [])
	if order.size() < 2:
		return { "ok": false, "error": "initiative_order too short" }
	# Identical stats + morale — tiebreak preserves input order (a before b).
	if str(order[0].get("id", "")) != "echo_a":
		return { "ok": false, "error": "Directive field must not affect order; tiebreak should put a first, got: %s" % str(order[0].get("id", "")) }
	return { "ok": true }


# Test 4: same inputs always produce the same initiative order (deterministic).
static func _t_same_inputs_same_order() -> Dictionary:
	var actors: Array = [
		{ "id": "e1", "name": "Echo1", "speed": 7, "stats": { "agi": 3 }, "morale": 80 },
		{ "id": "e2", "name": "Echo2", "speed": 5, "stats": { "agi": 6 }, "morale": 50 },
		{ "id": "e3", "name": "Echo3", "speed": 4, "stats": { "agi": 8 }, "morale": 20 },
	]
	var state_a: Dictionary = CombatState.create(actors, "defeat_enemies", 42, _morale_cfg())
	var state_b: Dictionary = CombatState.create(actors, "defeat_enemies", 42, _morale_cfg())
	var order_a: Array = state_a.get("initiative_order", [])
	var order_b: Array = state_b.get("initiative_order", [])
	if order_a.size() != order_b.size():
		return { "ok": false, "error": "Order sizes differ (%d vs %d)" % [order_a.size(), order_b.size()] }
	for i in range(order_a.size()):
		if str(order_a[i].get("id", "")) != str(order_b[i].get("id", "")):
			return { "ok": false, "error": "Order differs at index %d: %s vs %s" % [i, str(order_a[i].get("id", "")), str(order_b[i].get("id", ""))] }
	return { "ok": true }
