# res://tests/ActorTests.gd
# Tests for the ACTOR-001 unified Actor model:
#   - ActorSchema (validate, get_defaults)
#   - EchoActor.from_echo() mapping
#   - SanctumService.get_party_actors() / get_roster_actors()
#
# Tests 1–3 are pure unit tests (no runtime needed).
# Tests 4–5 use SanctumService directly with a synthetic save dict.
#
# Run via Debug Panel: tests

extends RefCounted
class_name ActorTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("actor/from_echo_all_fields_present",  Callable(ActorTests, "_t_from_echo_all_fields_present"))
	runner.register_test("actor/validate_false_missing_id",     Callable(ActorTests, "_t_validate_false_missing_id"))
	runner.register_test("actor/validate_false_null_name",      Callable(ActorTests, "_t_validate_false_null_name"))
	runner.register_test("actor/party_actors_empty_party",      Callable(ActorTests, "_t_party_actors_empty_party"))
	runner.register_test("actor/party_actors_two_echoes_valid", Callable(ActorTests, "_t_party_actors_two_echoes_valid"))


# -------------------------
# Tests
# -------------------------

# Test 1: from_echo_all_fields_present
# Steps:
#   1. Build a synthetic Echo dict matching current EchoFactory output.
#   2. Call EchoActor.from_echo().
#   3. Assert all REQUIRED_FIELDS are present, no nulls, actor_type == "echo".
static func _t_from_echo_all_fields_present() -> Dictionary:
	var echo := _make_test_echo("echo_0001", "Kofi Mensah")

	var actor: Dictionary = EchoActor.from_echo(echo)

	for field in ActorSchema.REQUIRED_FIELDS:
		if not actor.has(field):
			return { "ok": false, "error": "Actor dict missing required field: %s" % field }
		if actor[field] == null:
			return { "ok": false, "error": "Actor dict has null value for field: %s" % field }

	if str(actor.get("actor_type", "")) != "echo":
		return { "ok": false, "error": "Expected actor_type='echo', got: %s" % str(actor.get("actor_type", "")) }

	if str(actor.get("id", "")) != "echo_0001":
		return { "ok": false, "error": "Expected id='echo_0001', got: %s" % str(actor.get("id", "")) }

	if str(actor.get("name", "")) != "Kofi Mensah":
		return { "ok": false, "error": "Expected name='Kofi Mensah', got: %s" % str(actor.get("name", "")) }

	if int(actor.get("level", 0)) != 1:
		return { "ok": false, "error": "Expected level=1 (PROG-001 default), got: %d" % int(actor.get("level", 0)) }

	if not ActorSchema.validate(actor):
		return { "ok": false, "error": "ActorSchema.validate() returned false on from_echo() output" }

	return { "ok": true }


# Test 2: validate_false_missing_id
# Steps:
#   1. Build a dict that is missing the "id" field.
#   2. Assert ActorSchema.validate() returns false.
static func _t_validate_false_missing_id() -> Dictionary:
	var bad: Dictionary = ActorSchema.get_defaults()
	bad.erase("id")

	if ActorSchema.validate(bad):
		return { "ok": false, "error": "validate() returned true for a dict missing 'id'" }

	return { "ok": true }


# Test 3: validate_false_null_name
# Steps:
#   1. Build a defaults dict and set name = null.
#   2. Assert ActorSchema.validate() returns false.
static func _t_validate_false_null_name() -> Dictionary:
	var bad: Dictionary = ActorSchema.get_defaults()
	bad["name"] = null

	if ActorSchema.validate(bad):
		return { "ok": false, "error": "validate() returned true for a dict with null 'name'" }

	return { "ok": true }


# Test 4: party_actors_empty_party
# Steps:
#   1. Create SanctumService with an empty save (no roster, no active_party_ids).
#   2. Call get_party_actors().
#   3. Assert result is an empty Array.
static func _t_party_actors_empty_party() -> Dictionary:
	var save := {
		"sanctum": {
			"roster": [],
			"active_party_ids": []
		}
	}
	var svc := SanctumService.new(save)
	var actors: Array = svc.get_party_actors()

	if actors.size() != 0:
		return { "ok": false, "error": "Expected [] from get_party_actors() on empty party, got size=%d" % actors.size() }

	return { "ok": true }


# Test 5: party_actors_two_echoes_valid
# Steps:
#   1. Build a save with 2 synthetic echoes in roster and both IDs in active_party_ids.
#   2. Create SanctumService.
#   3. Call get_party_actors().
#   4. Assert 2 actors returned, both pass ActorSchema.validate(), no null fields.
static func _t_party_actors_two_echoes_valid() -> Dictionary:
	var echo1 := _make_test_echo("echo_0001", "Abena Asante")
	var echo2 := _make_test_echo("echo_0002", "Kwame Boateng")

	var save := {
		"sanctum": {
			"roster":           [echo1, echo2],
			"active_party_ids": ["echo_0001", "echo_0002"]
		}
	}
	var svc := SanctumService.new(save)
	var actors: Array = svc.get_party_actors()

	if actors.size() != 2:
		return { "ok": false, "error": "Expected 2 actors from get_party_actors(), got %d" % actors.size() }

	for i in range(actors.size()):
		var a_v: Variant = actors[i]
		if not (a_v is Dictionary):
			return { "ok": false, "error": "actors[%d] is not a Dictionary" % i }
		var a: Dictionary = a_v
		if not ActorSchema.validate(a):
			return { "ok": false, "error": "actors[%d] failed ActorSchema.validate()" % i }
		for field in ActorSchema.REQUIRED_FIELDS:
			if a[field] == null:
				return { "ok": false, "error": "actors[%d].%s is null" % [i, field] }

	return { "ok": true }


# -------------------------
# Helper
# -------------------------

## Returns a minimal but fully valid Echo save dict for use in tests.
## Matches the shape produced by EchoFactory (fields only; no RNG).
static func _make_test_echo(id: String, name: String) -> Dictionary:
	return {
		"id":             id,
		"name":           name,
		"gender":         "male",
		"rarity":         "uncalled",
		"calling_origin": "uncalled",
		"archetype_birth": "brave",
		"seed_path":      "campaign.summon.0",
		"summon_index":   0,
		"origin":         "summon",
		"traits":         { "courage": 55, "wisdom": 42, "faith": 38 },
		"stats":          { "max_hp": 120, "atk": 9, "def": 7, "agi": 6, "int": 5, "cha": 4 },
		"class_origin": "vanguard",  # birth Vector bias (PROG-001)
		"level":        1,            # static at generation (PROG-001)
		"xp_total":       0,
		"rank":           1,
		"vector_scores":  {},
		"generation_context": { "version": 1, "rng_draw_order_version": "v2", "rarity_raw": "uncalled" },
	}
