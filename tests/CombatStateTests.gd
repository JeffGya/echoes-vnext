# res://tests/CombatStateTests.gd
# COMBAT-001: Tests for the CombatState container and EncounterRoundsState integration.
#   1. combat/state_shape                  — CombatState.create() returns correct shape.
#   2. combat/state_actors_deep_copy       — Mutating source array does not mutate combat_state.
#   3. combat/rounds_enter_creates_state   — EncounterRoundsState.enter() stores valid CombatState.
#   4. combat/rounds_combat_state_fields   — round_counter == 0 and objective matches resolution_mode.
#
# COMBAT-002: Tests for initiative order calculation.
#   5. combat/initiative_shape             — initiative_order is Array with correct size; active_initiative_index == 0.
#   6. combat/initiative_sort_by_score     — higher speed+agi actor appears first.
#   7. combat/initiative_determinism       — same inputs always produce identical initiative_order.
#   8. combat/initiative_tiebreak_order    — equal-score actors preserve input list order.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatStateTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat/state_shape",                Callable(CombatStateTests, "_t_state_shape"))
	runner.register_test("combat/state_actors_deep_copy",     Callable(CombatStateTests, "_t_state_actors_deep_copy"))
	runner.register_test("combat/rounds_enter_creates_state", Callable(CombatStateTests, "_t_rounds_enter_creates_state"))
	runner.register_test("combat/rounds_combat_state_fields", Callable(CombatStateTests, "_t_rounds_combat_state_fields"))
	# COMBAT-002
	runner.register_test("combat/initiative_shape",           Callable(CombatStateTests, "_t_initiative_shape"))
	runner.register_test("combat/initiative_sort_by_score",   Callable(CombatStateTests, "_t_initiative_sort_by_score"))
	runner.register_test("combat/initiative_determinism",     Callable(CombatStateTests, "_t_initiative_determinism"))
	runner.register_test("combat/initiative_tiebreak_order",  Callable(CombatStateTests, "_t_initiative_tiebreak_order"))
	# V2-PROG-002: initiative uses confirmed calling modifier over birth origin
	runner.register_test("combat/initiative_uses_confirmed_calling", Callable(CombatStateTests, "_t_initiative_uses_confirmed_calling"))
	# V2-STAGE-004 Phase 4 (S16b): all_echoes_dead exclusion — is_ally must not keep a wiped party "alive"
	runner.register_test("combat/all_echoes_dead_excludes_ally", Callable(CombatStateTests, "_t_all_echoes_dead_excludes_ally"))
	runner.register_test("combat/all_echoes_dead_living_normal_echo_prevents", Callable(CombatStateTests, "_t_all_echoes_dead_living_normal_echo_prevents"))


# -------------------------
# COMBAT-001 Tests
# -------------------------

static func _t_state_shape() -> Dictionary:
	var actors: Array = [{ "id": "a1" }, { "id": "a2" }]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies")

	if not state.has("actors"):
		return { "ok": false, "error": "missing 'actors' key" }
	if not state.has("objective"):
		return { "ok": false, "error": "missing 'objective' key" }
	if not state.has("round_counter"):
		return { "ok": false, "error": "missing 'round_counter' key" }
	if str(state["objective"]) != "defeat_enemies":
		return { "ok": false, "error": "objective mismatch (got %s)" % str(state["objective"]) }
	if int(state["round_counter"]) != 0:
		return { "ok": false, "error": "round_counter should be 0 (got %d)" % int(state["round_counter"]) }
	var stored: Array = state["actors"] as Array
	if stored.size() != 2:
		return { "ok": false, "error": "actors array wrong size (got %d)" % stored.size() }
	return { "ok": true }


static func _t_state_actors_deep_copy() -> Dictionary:
	var source: Array = [{ "id": "x1" }]
	var state: Dictionary = CombatState.create(source, "survive")

	# Mutate source after creation.
	source.append({ "id": "x2" })
	(source[0] as Dictionary)["id"] = "mutated"

	var stored: Array = state["actors"] as Array
	if stored.size() != 1:
		return { "ok": false, "error": "deep copy should have 1 actor, got %d" % stored.size() }
	var first_id: String = str((stored[0] as Dictionary).get("id", ""))
	if first_id == "mutated":
		return { "ok": false, "error": "source mutation propagated into combat_state actors" }
	return { "ok": true }


static func _t_rounds_enter_creates_state() -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.encounter_id = "test_enc_001"
	ectx.resolution_mode = "defeat_enemies"
	ectx.actors = [
		{ "id": "echo_0001", "faction": "echo" },
		{ "id": "enemy_01",  "faction": "enemy" },
	]

	var state := EncounterRoundsState.new()
	state.enter(ectx, 1)

	if ectx.combat_state.is_empty():
		return { "ok": false, "error": "combat_state is empty after enter()" }
	if not CombatState.validate(ectx.combat_state):
		return { "ok": false, "error": "CombatState.validate() returned false" }
	return { "ok": true }


static func _t_rounds_combat_state_fields() -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.encounter_id = "test_enc_002"
	ectx.resolution_mode = "purify_shrine"
	ectx.actors = [{ "id": "echo_0002", "faction": "echo" }]

	var state := EncounterRoundsState.new()
	state.enter(ectx, 2)

	var cs: Dictionary = ectx.combat_state
	if int(cs.get("round_counter", -1)) != 0:
		return { "ok": false, "error": "round_counter should be 0 (got %d)" % int(cs.get("round_counter", -1)) }
	if str(cs.get("objective", "")) != ectx.resolution_mode:
		return { "ok": false, "error": "objective should match resolution_mode (got '%s')" % str(cs.get("objective", "")) }
	return { "ok": true }


# -------------------------
# COMBAT-002 Tests
# -------------------------

static func _t_initiative_shape() -> Dictionary:
	var actors: Array = [
		{ "id": "a1", "name": "Alpha", "speed": 5, "stats": { "agi": 2 } },
		{ "id": "a2", "name": "Beta",  "speed": 3, "stats": { "agi": 1 } },
	]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies", 0, {})

	if not state.has("initiative_order"):
		return { "ok": false, "error": "missing 'initiative_order' key" }
	if not state.has("active_initiative_index"):
		return { "ok": false, "error": "missing 'active_initiative_index' key" }
	var order: Array = state["initiative_order"] as Array
	if order.size() != 2:
		return { "ok": false, "error": "initiative_order should have 2 entries (got %d)" % order.size() }
	if int(state["active_initiative_index"]) != 0:
		return { "ok": false, "error": "active_initiative_index should be 0 (got %d)" % int(state["active_initiative_index"]) }
	return { "ok": true }


static func _t_initiative_sort_by_score() -> Dictionary:
	# Actor A has much higher speed+agi — must appear first.
	var actors: Array = [
		{ "id": "fast", "name": "Fast", "speed": 10, "stats": { "agi": 8 } },
		{ "id": "slow", "name": "Slow", "speed": 2,  "stats": { "agi": 1 } },
	]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies", 0, {})
	var order: Array = state["initiative_order"] as Array

	if order.size() != 2:
		return { "ok": false, "error": "expected 2 entries (got %d)" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	if first_id != "fast":
		return { "ok": false, "error": "highest speed+agi actor should be first (got '%s')" % first_id }
	return { "ok": true }


static func _t_initiative_determinism() -> Dictionary:
	var actors: Array = [
		{ "id": "e1", "name": "Echo One",   "speed": 7, "stats": { "agi": 4 } },
		{ "id": "e2", "name": "Enemy One",  "speed": 5, "stats": { "agi": 3 } },
		{ "id": "e3", "name": "Echo Three", "speed": 6, "stats": { "agi": 2 } },
	]
	var seed: int = 12345

	var state_a: Dictionary = CombatState.create(actors, "defeat_enemies", seed, {})
	var state_b: Dictionary = CombatState.create(actors, "defeat_enemies", seed, {})

	var order_a: Array = state_a["initiative_order"] as Array
	var order_b: Array = state_b["initiative_order"] as Array

	if order_a.size() != order_b.size():
		return { "ok": false, "error": "order sizes differ (%d vs %d)" % [order_a.size(), order_b.size()] }
	for i in range(order_a.size()):
		var id_a: String = str((order_a[i] as Dictionary).get("id", ""))
		var id_b: String = str((order_b[i] as Dictionary).get("id", ""))
		if id_a != id_b:
			return { "ok": false, "error": "initiative_order not deterministic at index %d ('%s' vs '%s')" % [i, id_a, id_b] }
	return { "ok": true }


static func _t_initiative_tiebreak_order() -> Dictionary:
	# Both actors have identical speed+agi and no modifiers — seed=0 gives same nudge.
	# Actor at input index 0 must appear first (party list order tiebreak).
	var actors: Array = [
		{ "id": "first",  "name": "First",  "speed": 5, "stats": { "agi": 5 } },
		{ "id": "second", "name": "Second", "speed": 5, "stats": { "agi": 5 } },
	]
	var state: Dictionary = CombatState.create(actors, "defeat_enemies", 0, {})
	var order: Array = state["initiative_order"] as Array

	if order.size() != 2:
		return { "ok": false, "error": "expected 2 entries (got %d)" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	# With seed=0: nudge for "first" = derive_from(0,"first")%10; nudge for "second" = derive_from(0,"second")%10.
	# If nudges differ, sort by score. If equal, index 0 wins. Either way "first" should be first
	# unless the nudge for "second" strictly exceeds "first" — in that case the score-sort is correct.
	# We validate the stable-sort property: if scores are equal, index 0 must win.
	# Compute expected nudge to verify.
	var nudge_first:  int = int(CampaignSeed.derive_from(0, "first")  % 10)
	var nudge_second: int = int(CampaignSeed.derive_from(0, "second") % 10)
	# Both have same base score (5*3 + 5*2 = 25). If nudges are equal, "first" must be first.
	# If nudge_second > nudge_first, "second" correctly appears first by score.
	if nudge_first == nudge_second:
		if first_id != "first":
			return { "ok": false, "error": "equal scores: input index 0 ('first') should be first, got '%s'" % first_id }
	else:
		# Scores differ — verify the higher nudge wins.
		var expected_first: String = "first" if nudge_first > nudge_second else "second"
		if first_id != expected_first:
			return { "ok": false, "error": "score-based sort failed: expected '%s' first, got '%s'" % [expected_first, first_id] }
	return { "ok": true }


# -------------------------
# V2-PROG-002: Calling seam — initiative test
# -------------------------

# COMBAT-002/V2-PROG-002: confirmed calling modifier takes priority over birth origin.
# Actor A: calling_origin="seer", calling="warder"  → resolved key "warder" → +10 modifier.
# Actor B: calling_origin="seer", calling=""         → resolved key "seer"   → +0 modifier.
# Both have identical base stats (speed=5, agi=5 → base=25).
# Actor A goes first due to confirmed calling modifier (+10 → score=35 vs 25).
static func _t_initiative_uses_confirmed_calling() -> Dictionary:
	var actor_a := {
		"id":             "echo_seam_a",
		"name":           "A",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "seer",
		"calling":        "warder",  # confirmed — warder modifier (+10) should apply
	}
	var actor_b := {
		"id":             "echo_seam_b",
		"name":           "B",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "seer",
		"calling":        "",  # unconfirmed — seer modifier (0) applies
	}
	var init_cfg := {
		"by_calling_origin": { "warder": 10, "seer": 0 },
		"by_archetype":      {},
		"by_dominant_trait": {},
		"by_dominant_vector": {},
	}
	var state: Dictionary = CombatState.create([actor_a, actor_b], "defeat_enemies", 0, init_cfg)
	var order: Array = state["initiative_order"] as Array
	if order.size() != 2:
		return { "ok": false, "error": "Expected 2 actors in initiative order, got %d" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	if first_id != "echo_seam_a":
		return {
			"ok": false,
			"error": "Confirmed warder (A, +10 modifier) should go first. Got '%s' first — birth origin 'seer' must not override confirmed calling." % first_id,
		}
	return { "ok": true }


# -------------------------
# V2-STAGE-004 Phase 4 (S16b): all_echoes_dead exclusion tests
# -------------------------

# A joined Temporary Ally (is_ally=true) must NOT keep a wiped party "alive" —
# CombatState.check_end_condition's living_echoes filter excludes is_ally actors
# (mirrors the pre-existing is_spirit exclusion for GUIDE_SPIRIT).
static func _t_all_echoes_dead_excludes_ally() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_1",  "faction": "echo",  "is_dead": true },
		{ "id": "echo_2",  "faction": "echo",  "is_dead": true },
		{ "id": "ally_1",  "faction": "echo",  "is_dead": false, "is_ally": true },
		{ "id": "enemy_1", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies", {})
	if not bool(result.get("over", false)):
		return { "ok": false, "error": "Expected combat over (party wiped except a living ally), got over=false" }
	if bool(result.get("victory", false)):
		return { "ok": false, "error": "Expected defeat (victory=false) when only a living ally remains" }
	if str(result.get("reason", "")) != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# Control: a living NORMAL echo (is_ally=false, is_spirit=false) must still prevent
# all_echoes_dead from firing — proves the exclusion is scoped to is_ally/is_spirit only.
static func _t_all_echoes_dead_living_normal_echo_prevents() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_1",  "faction": "echo",  "is_dead": true },
		{ "id": "echo_2",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_1", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, "defeat_enemies", {})
	if bool(result.get("over", false)):
		return {
			"ok": false,
			"error": "Expected combat NOT over (one normal echo still alive), got over=true reason='%s'" % str(result.get("reason", ""))
		}
	return { "ok": true }
