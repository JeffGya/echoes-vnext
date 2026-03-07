# res://tests/EchoSchemaTests.gd
# Tests for the PROG-001 Echo Identity Data Layer:
#   - EchoFactory.generate() outputs class_origin, level, rng_draw_order_version "v2"
#   - EchoFactory.generate() is deterministic (same seed → identical output)
#   - EchoFactory.repair_echo_fields() patches old echo dicts correctly
#   - EchoActor.from_echo() on a generated echo passes ActorSchema.validate()
#
# All tests are pure unit tests (no runtime needed).
# Run via Debug Panel: tests

extends RefCounted
class_name EchoSchemaTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("echofactory/has_class_origin_and_level",    Callable(EchoSchemaTests, "_t_has_class_origin_and_level"))
	runner.register_test("echofactory/determinism",                   Callable(EchoSchemaTests, "_t_determinism"))
	runner.register_test("old_echo/repair_adds_defaults",             Callable(EchoSchemaTests, "_t_repair_adds_defaults"))
	runner.register_test("echofactory/actor_validates_after_mapping", Callable(EchoSchemaTests, "_t_actor_validates_after_mapping"))


# -------------------------
# Tests
# -------------------------

# Test 1: has_class_origin_and_level
# Steps:
#   1. Generate an echo with a fixed seed and a config that includes class_origin_weights.
#   2. Assert class_origin is present, non-empty, and in the valid Vector taxonomy.
#   3. Assert level == 1 (static at generation — no RNG draw).
#   4. Assert generation_context.rng_draw_order_version == "v2".
static func _t_has_class_origin_and_level() -> Dictionary:
	var echo := EchoFactory.generate(
		"test-seed-prog001",
		"campaign.summon.0",
		0,
		"summon",
		_summoning_cfg()
	)

	# class_origin must be present and in the valid Vector taxonomy
	if not echo.has("class_origin"):
		return { "ok": false, "error": "Echo dict missing 'class_origin'" }

	var co: String = str(echo.get("class_origin", ""))
	if co.is_empty():
		return { "ok": false, "error": "class_origin is an empty string" }

	var valid_origins: Array = ["protector", "vanguard", "seeker", "pillar"]
	if co not in valid_origins:
		return { "ok": false, "error": "class_origin '%s' not in valid Vector set %s" % [co, str(valid_origins)] }

	# level must be 1 (static at generation)
	if not echo.has("level"):
		return { "ok": false, "error": "Echo dict missing 'level'" }

	if int(echo.get("level", 0)) != 1:
		return { "ok": false, "error": "Expected level=1, got: %d" % int(echo.get("level", 0)) }

	# generation_context must record draw-order version v2
	var gen_ctx_v: Variant = echo.get("generation_context", {})
	if not (gen_ctx_v is Dictionary):
		return { "ok": false, "error": "generation_context is not a Dictionary" }

	var gen_ctx: Dictionary = gen_ctx_v
	var ver: String = str(gen_ctx.get("rng_draw_order_version", ""))
	if ver != "v2":
		return { "ok": false, "error": "Expected rng_draw_order_version='v2', got: '%s'" % ver }

	return { "ok": true }


# Test 2: determinism
# Steps:
#   1. Generate two echoes with identical seed_root, seed_path, summon_index, and config.
#   2. Assert that all key fields are identical across both outputs.
static func _t_determinism() -> Dictionary:
	var cfg := _summoning_cfg()
	var echo1 := EchoFactory.generate("test-seed-prog001", "campaign.summon.0", 0, "summon", cfg)
	var echo2 := EchoFactory.generate("test-seed-prog001", "campaign.summon.0", 0, "summon", cfg)

	var scalar_fields := [
		"name", "gender", "rarity", "calling_origin", "class_origin",
		"archetype_birth", "level", "xp_total", "rank"
	]
	for field in scalar_fields:
		if echo1.get(field) != echo2.get(field):
			return {
				"ok": false,
				"error": "Non-deterministic field '%s': '%s' vs '%s'" % [
					field, str(echo1.get(field, "")), str(echo2.get(field, ""))
				]
			}

	# Traits must also be deterministic
	var t1: Dictionary = echo1.get("traits", {})
	var t2: Dictionary = echo2.get("traits", {})
	for trait_key in ["courage", "wisdom", "faith"]:
		if t1.get(trait_key) != t2.get(trait_key):
			return { "ok": false, "error": "Non-deterministic trait '%s'" % trait_key }

	# generation_context rng_draw_order_version must match
	var gc1: Dictionary = echo1.get("generation_context", {})
	var gc2: Dictionary = echo2.get("generation_context", {})
	if gc1.get("rng_draw_order_version") != gc2.get("rng_draw_order_version"):
		return { "ok": false, "error": "Non-deterministic rng_draw_order_version in generation_context" }

	return { "ok": true }


# Test 3: repair_adds_defaults
# Steps:
#   1. Build a minimal old-style echo dict with calling_origin "warrior" and no level or class_origin.
#   2. Call EchoFactory.repair_echo_fields(echo).
#   3. Assert return value is true (patched = fields were missing).
#   4. Assert echo["level"] == 1.
#   5. Assert echo["class_origin"] == "vanguard" (old save-compat mapping: warrior → vanguard).
static func _t_repair_adds_defaults() -> Dictionary:
	var echo: Dictionary = {
		"id":             "echo_old_001",
		"name":           "Kofi Mensah",
		"calling_origin": "warrior"
	}

	var patched: bool = EchoFactory.repair_echo_fields(echo)

	if not patched:
		return { "ok": false, "error": "repair_echo_fields() returned false — expected true (level and class_origin were missing)" }

	if int(echo.get("level", 0)) != 1:
		return { "ok": false, "error": "Expected level=1 after repair, got: %d" % int(echo.get("level", 0)) }

	var co: String = str(echo.get("class_origin", ""))
	if co != "vanguard":
		return { "ok": false, "error": "Expected class_origin='vanguard' (from calling_origin='warrior'), got: '%s'" % co }

	return { "ok": true }


# Test 4: actor_validates_after_mapping
# Steps:
#   1. Generate a real echo with a known seed and config (includes class_origin_weights).
#   2. Assign a non-empty id (EchoFactory leaves id blank by contract; caller assigns it).
#   3. Map to an Actor via EchoActor.from_echo().
#   4. Assert ActorSchema.validate() returns true on the result.
static func _t_actor_validates_after_mapping() -> Dictionary:
	var echo := EchoFactory.generate(
		"test-seed-prog001",
		"campaign.summon.0",
		0,
		"summon",
		_summoning_cfg()
	)
	echo["id"] = "echo_0001"  # EchoFactory leaves id blank by contract

	var actor: Dictionary = EchoActor.from_echo(echo)

	if not ActorSchema.validate(actor):
		return { "ok": false, "error": "ActorSchema.validate() returned false on EchoActor.from_echo() output (generated echo)" }

	return { "ok": true }


# -------------------------
# Helper
# -------------------------

## Minimal summoning config covering all keys EchoFactory reads.
## Includes class_origin_weights (PROG-001 v2 draw) to match the balance.json shape.
## class_origin_weights is the single Vector type registry for the entire system —
## expand by adding new Vectors here post-MVP (no code change needed).
static func _summoning_cfg() -> Dictionary:
	return {
		"trait_min": 30,
		"trait_max": 70,
		"calling_weights": { "uncalled": 0.90, "called": 0.05, "chosen": 0.05 },
		"class_origin_weights": { "protector": 1.0, "vanguard": 1.0, "seeker": 1.0, "pillar": 1.0 },
		"birth_stats": { "hp_base": 100 }
	}
