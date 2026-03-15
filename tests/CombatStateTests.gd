# res://tests/CombatStateTests.gd
# COMBAT-001: Tests for the CombatState container and EncounterRoundsState integration.
#   1. combat/state_shape                  — CombatState.create() returns correct shape.
#   2. combat/state_actors_deep_copy       — Mutating source array does not mutate combat_state.
#   3. combat/rounds_enter_creates_state   — EncounterRoundsState.enter() stores valid CombatState.
#   4. combat/rounds_combat_state_fields   — round_counter == 0 and objective matches resolution_mode.
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


# -------------------------
# Tests
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
