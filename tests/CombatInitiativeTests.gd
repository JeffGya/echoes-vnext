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
	runner.register_test("combat_initiative/dominant_vector_recognizes_all_ten_vectors",
		Callable(CombatInitiativeTests, "_t_dominant_vector_recognizes_all_ten_vectors"))
	runner.register_test("combat_initiative/v2_calling_receives_initiative_modifier",
		Callable(CombatInitiativeTests, "_t_v2_calling_receives_initiative_modifier"))


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
	# Give echo_a a speed edge so it reliably leads regardless of seed nudge.
	# The test verifies that adding active_directive to echo_b does NOT change
	# the order relative to the same pair without directive.
	var actor_a_with_dir := {
		"id":               "echo_a",
		"name":             "Echo A",
		"speed":            7,
		"stats":            { "agi": 5 },
		"morale":           60,
		"active_directive": "push",
	}
	var actor_b_no_dir := {
		"id":    "echo_b",
		"name":  "Echo B",
		"speed": 5,
		"stats": { "agi": 5 },
		"morale": 60,
	}
	# Baseline: same actors, neither has directive.
	var actor_a_no_dir := actor_a_with_dir.duplicate()
	actor_a_no_dir.erase("active_directive")

	var state_with_dir: Dictionary = CombatState.create(
		[actor_a_with_dir, actor_b_no_dir], "defeat_enemies", 0, _morale_cfg())
	var state_no_dir: Dictionary = CombatState.create(
		[actor_a_no_dir, actor_b_no_dir], "defeat_enemies", 0, _morale_cfg())

	var order_with: Array = state_with_dir.get("initiative_order", [])
	var order_without: Array = state_no_dir.get("initiative_order", [])
	if order_with.size() < 2 or order_without.size() < 2:
		return { "ok": false, "error": "initiative_order too short" }
	# echo_a has higher speed — must lead in both states.
	if str(order_with[0].get("id", "")) != "echo_a":
		return { "ok": false, "error": "Directive field must not affect order; expected echo_a first (with directive), got: %s" % str(order_with[0].get("id", "")) }
	if str(order_without[0].get("id", "")) != "echo_a":
		return { "ok": false, "error": "Directive field must not affect order; expected echo_a first (no directive), got: %s" % str(order_without[0].get("id", "")) }
	# Order must be identical whether or not echo_a carries a directive.
	var ids_with:    Array = order_with.map(func(a): return a.get("id", ""))
	var ids_without: Array = order_without.map(func(a): return a.get("id", ""))
	if ids_with != ids_without:
		return { "ok": false, "error": "Directive changed initiative order: %s vs %s" % [str(ids_with), str(ids_without)] }
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


# Test 5: dominant_vector_recognizes_all_ten_vectors
# V2-COMBAT-003: CombatState._dominant_key()'s vec_tiebreak = ["vanguard","seeker","protector",
# "pillar"] is a TIEBREAK list only — every key in vector_scores must be a scoring candidate.
# Before the fix, _dominant_key() iterated the tiebreak list itself, so a key absent from it
# (six of the ten V2 vectors) was invisible: never out-ranked, never examined.
#
#   echo_a: devoted=100 (true dominant, far above every other key), vanguard/seeker/protector/
#           pillar all =1. The pre-fix bug only ever looks at those four legacy keys, so it
#           never sees "devoted" and reports "pillar" (last checked, tied at 1) as dominant.
#   echo_b: vanguard=50 (true dominant AND the only key in the legacy four that stands out).
#           Both old and new code agree echo_b's dominant is "vanguard".
#
# by_dominant_vector weights "devoted" (30) far above "vanguard" (5) — a margin of 25, larger
# than the 0-9 deterministic seed nudge could ever close — so:
#   FIXED rule: echo_a dominant=devoted -> vec_mod 30. echo_b dominant=vanguard -> vec_mod 5.
#               echo_a leads (30 > 5, unreachable by nudge alone).
#   BUGGY rule: echo_a dominant=pillar (six vectors invisible) -> vec_mod 0. echo_b unchanged
#               at vec_mod 5. echo_b would lead instead — the wrong echo, because echo_a's true
#               100-point dominant vector was never examined.
static func _t_dominant_vector_recognizes_all_ten_vectors() -> Dictionary:
	var vec_cfg: Dictionary = {
		"by_dominant_vector": {
			"devoted": 30, "vanguard": 5, "seeker": 0, "protector": 0, "pillar": 0,
		},
	}
	var actor_a := {
		"id":            "echo_a",
		"name":          "Echo A",
		"speed":         5,
		"stats":         { "agi": 5 },
		"morale":        60,
		"vector_scores": {
			"devoted": 100, "vanguard": 1, "seeker": 1, "protector": 1, "pillar": 1,
		},
	}
	var actor_b := {
		"id":            "echo_b",
		"name":          "Echo B",
		"speed":         5,
		"stats":         { "agi": 5 },
		"morale":        60,
		"vector_scores": {
			"devoted": 0, "vanguard": 50, "seeker": 1, "protector": 1, "pillar": 1,
		},
	}
	var state: Dictionary = CombatState.create([actor_a, actor_b], "defeat_enemies", 0, vec_cfg)
	var order: Array = state.get("initiative_order", [])
	if order.size() < 2:
		return { "ok": false, "error": "initiative_order too short (got %d)" % order.size() }
	if str(order[0].get("id", "")) != "echo_a":
		return {
			"ok": false,
			"error": "Expected echo_a first (devoted=100 dominant, vec_mod=30 > echo_b vec_mod=5); "
				+ "got: %s -- a key absent from vec_tiebreak is being shadowed again" % str(order[0].get("id", ""))
		}
	return { "ok": true }


# Test 6: v2_calling_receives_initiative_modifier
# Reads the SHIPPED balance.json (not a hand-authored fixture) so a regression of
# by_calling_origin back to V1 ids fails here -- "aduro" would silently score 0.
static func _t_v2_calling_receives_initiative_modifier() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var combat_cfg: Dictionary = (bal.get("data", {}) as Dictionary).get("combat", {})
	var init_cfg: Dictionary = combat_cfg.get("initiative_modifiers", {})
	var by_calling: Dictionary = init_cfg.get("by_calling_origin", {})

	if not by_calling.has("aduro"):
		return { "ok": false, "error": "fixture broken: data.combat.initiative_modifiers.by_calling_origin has no 'aduro' key -- table is not on V2 calling ids" }

	var actor_aduro := {
		"id":             "echo_aduro",
		"name":           "Aduro",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "aduro",
		"calling":        "",
	}
	var actor_uncalled := {
		"id":             "echo_uncalled",
		"name":           "Uncalled",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "uncalled",
		"calling":        "",
	}
	var state: Dictionary = CombatState.create([actor_aduro, actor_uncalled], "defeat_enemies", 0, init_cfg)
	var order: Array = state.get("initiative_order", [])
	if order.size() < 2:
		return { "ok": false, "error": "initiative_order too short (got %d)" % order.size() }
	if str(order[0].get("id", "")) != "echo_aduro":
		return {
			"ok": false,
			"error": "Expected 'aduro' (V2 calling, shipped modifier %s) to outrank 'uncalled' (0.0); got '%s' first -- by_calling_origin has regressed to unmigrated V1 ids" % [str(by_calling.get("aduro")), str(order[0].get("id", ""))],
		}
	return { "ok": true }
