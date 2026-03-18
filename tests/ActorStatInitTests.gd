# res://tests/ActorStatInitTests.gd
# Tests for the ACTOR-002 stat block MVP:
#   - EchoFactory stat block is deterministic across identical seeds (incl. new fields)
#   - EchoActor.from_echo() → ActorSchema.validate() passes with all ACTOR-002 fields
#   - EnemyActor.from_definition() → ActorSchema.validate() passes; actor_type = "enemy"; hp > 0
#   - ActorStateMachine.get_stat() returns correct value for a stats sub-dict field
#
# All tests are pure unit tests (no runtime needed).
# Run via Debug Panel: tests

extends RefCounted
class_name ActorStatInitTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("statinit/echo_determinism",       Callable(ActorStatInitTests, "_t_echo_determinism"))
	runner.register_test("statinit/echo_actor_validates",   Callable(ActorStatInitTests, "_t_echo_actor_validates"))
	runner.register_test("statinit/enemy_actor_validates",  Callable(ActorStatInitTests, "_t_enemy_actor_validates"))
	runner.register_test("statinit/actorsm_get_stat",       Callable(ActorStatInitTests, "_t_actorsm_get_stat"))


# -------------------------
# Tests
# -------------------------

# Test 1: echo_determinism
# Steps:
#   1. Generate two echoes from the identical seed and config.
#   2. Map both to actor dicts via EchoActor.from_echo().
#   3. Assert all stats fields are bit-identical.
#   4. Assert current_hp, speed, morale, fear are identical on both actors.
static func _t_echo_determinism() -> Dictionary:
	var cfg := _summoning_cfg()
	var echo1 := EchoFactory.generate("test-seed-actor002", "campaign.summon.0", 0, "summon", cfg)
	var echo2 := EchoFactory.generate("test-seed-actor002", "campaign.summon.0", 0, "summon", cfg)
	echo1["id"] = "echo_0001"
	echo2["id"] = "echo_0001"

	var actor1: Dictionary = EchoActor.from_echo(echo1)
	var actor2: Dictionary = EchoActor.from_echo(echo2)

	# Base stats must be bit-identical
	var stats1: Dictionary = actor1.get("stats", {})
	var stats2: Dictionary = actor2.get("stats", {})
	for key in stats1.keys():
		if stats1.get(key) != stats2.get(key):
			return { "ok": false, "error": "Non-deterministic stats.%s: %s vs %s" % [key, str(stats1.get(key)), str(stats2.get(key))] }

	# Top-level runtime fields must also be identical
	for field in ["current_hp", "speed", "morale", "fear"]:
		if actor1.get(field) != actor2.get(field):
			return { "ok": false, "error": "Non-deterministic field '%s': %s vs %s" % [field, str(actor1.get(field)), str(actor2.get(field))] }

	return { "ok": true }


# Test 2: echo_actor_validates
# Steps:
#   1. Generate an echo, assign id, map via EchoActor.from_echo().
#   2. Assert ActorSchema.validate() passes.
#   3. Assert current_hp, speed, morale, fear are all present, non-null, correct defaults.
static func _t_echo_actor_validates() -> Dictionary:
	var echo := EchoFactory.generate("test-seed-actor002", "campaign.summon.0", 0, "summon", _summoning_cfg())
	echo["id"] = "echo_0001"

	var actor: Dictionary = EchoActor.from_echo(echo)

	if not ActorSchema.validate(actor):
		return { "ok": false, "error": "ActorSchema.validate() returned false for echo actor (ACTOR-002 fields missing?)" }

	# Verify ACTOR-002 top-level fields
	for field in ["current_hp", "speed", "morale", "fear"]:
		if not actor.has(field):
			return { "ok": false, "error": "Actor dict missing ACTOR-002 field: %s" % field }
		if actor[field] == null:
			return { "ok": false, "error": "Actor dict has null value for ACTOR-002 field: %s" % field }

	# current_hp must equal stats.max_hp at spawn
	var expected_hp: int = int(actor.get("stats", {}).get("max_hp", -1))
	var actual_hp: int   = int(actor.get("current_hp", -2))
	if actual_hp != expected_hp:
		return { "ok": false, "error": "current_hp (%d) != stats.max_hp (%d) at spawn" % [actual_hp, expected_hp] }

	# BALANCE-001: speed is now formula-derived (not flat 5). Verify it is a positive integer.
	# The test cfg passes only hp_base=100, so speed uses DerivedStatService defaults (min 1).
	if int(actor.get("speed", -1)) < 1:
		return { "ok": false, "error": "Expected speed >= 1 (formula-derived), got: %d" % int(actor.get("speed", -1)) }
	if int(actor.get("morale", -1)) != 50:
		return { "ok": false, "error": "Expected morale=50, got: %d" % int(actor.get("morale", -1)) }
	if int(actor.get("fear",   -1)) != 0:
		return { "ok": false, "error": "Expected fear=0, got: %d" % int(actor.get("fear", -1)) }

	return { "ok": true }


# Test 3: enemy_actor_validates
# Steps:
#   1. Call EnemyActor.from_definition() with a level-2 enemy definition.
#   2. Assert ActorSchema.validate() passes.
#   3. Assert actor_type == "enemy".
#   4. Assert current_hp == stats.max_hp at spawn.
static func _t_enemy_actor_validates() -> Dictionary:
	var defn := { "id": "e_001", "name": "Dust Wanderer", "level": 2 }
	var actor: Dictionary = EnemyActor.from_definition(defn, 0)

	if not ActorSchema.validate(actor):
		return { "ok": false, "error": "ActorSchema.validate() returned false for enemy actor" }

	if str(actor.get("actor_type", "")) != "enemy":
		return { "ok": false, "error": "Expected actor_type='enemy', got: %s" % str(actor.get("actor_type", "")) }

	var max_hp: int     = int(actor.get("stats", {}).get("max_hp", -1))
	var current_hp: int = int(actor.get("current_hp", -2))
	if current_hp != max_hp:
		return { "ok": false, "error": "enemy current_hp (%d) != stats.max_hp (%d) at spawn" % [current_hp, max_hp] }

	# BALANCE-001: max_hp is now formula-derived via DerivedStatService (no cfg passed here,
	# so DerivedStatService uses its safe defaults with neutral traits 50/50/50 at level 2).
	# Old flat formula (50 + level*10 = 70) no longer applies. Just verify HP is positive.
	if max_hp < 1:
		return { "ok": false, "error": "Expected max_hp > 0 for level-2 enemy, got: %d" % max_hp }

	return { "ok": true }


# Test 4: actorsm_get_stat
# Steps:
#   1. Build a synthetic echo → EchoActor.from_echo() → ActorStateMachine.new(actor).
#   2. Assert get_stat("max_hp") == actor.stats.max_hp.
#   3. Assert get_stat("nonexistent_stat") == null.
static func _t_actorsm_get_stat() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_0001", "Kofi Mensah")
	var actor: Dictionary = EchoActor.from_echo(echo)
	var sm := ActorStateMachine.new(actor)

	var expected_hp: int = int(actor.get("stats", {}).get("max_hp", -1))
	var sm_hp: Variant   = sm.get_stat("max_hp")

	if sm_hp == null:
		return { "ok": false, "error": "get_stat('max_hp') returned null — expected %d" % expected_hp }

	if int(sm_hp) != expected_hp:
		return { "ok": false, "error": "get_stat('max_hp') returned %d, expected %d" % [int(sm_hp), expected_hp] }

	var none_val: Variant = sm.get_stat("nonexistent_stat")
	if none_val != null:
		return { "ok": false, "error": "get_stat('nonexistent_stat') should return null, got: %s" % str(none_val) }

	return { "ok": true }


# -------------------------
# Helper
# -------------------------

## Minimal summoning config matching balance.json shape (same as EchoSchemaTests).
static func _summoning_cfg() -> Dictionary:
	return {
		"trait_min": 30,
		"trait_max": 70,
		"calling_weights":      { "uncalled": 0.90, "called": 0.05, "chosen": 0.05 },
		"class_origin_weights": { "protector": 1.0, "vanguard": 1.0, "seeker": 1.0, "pillar": 1.0 },
		"birth_stats":          { "hp_base": 100 }
	}
