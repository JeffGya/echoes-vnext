# res://tests/DerivedStatTests.gd
# Tests for PROG-002: Derived Stat Pipeline
#   - DerivedStatService.compute_stats() is deterministic
#   - Rank bonus adds correctly (rank=2 > rank=1 for all stats; all per_rank defaults > 0)
#   - Level bonus adds correctly (max_hp higher at level=2; agi same since agi_per_level=0)
#   - EchoFactory.generate() stats match DerivedStatService.compute_stats() at rank=1, level=1
#
# All tests are pure unit tests (no runtime needed).
# Run via Debug Panel: tests

extends RefCounted
class_name DerivedStatTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("derived/determinism",             Callable(DerivedStatTests, "_t_determinism"))
	runner.register_test("derived/rank_scaling",            Callable(DerivedStatTests, "_t_rank_scaling"))
	runner.register_test("derived/level_scaling",           Callable(DerivedStatTests, "_t_level_scaling"))
	runner.register_test("derived/factory_matches_service", Callable(DerivedStatTests, "_t_factory_matches_service"))


# -------------------------
# Tests
# -------------------------

# Test 1: determinism
# Steps:
#   1. Call compute_stats() twice with identical inputs.
#   2. Assert all 6 output keys are bit-identical across both calls.
static func _t_determinism() -> Dictionary:
	var traits := { "courage": 50, "wisdom": 40, "faith": 60 }
	var cfg := _stat_cfg()

	var s1 := DerivedStatService.compute_stats(traits, 1, 1, cfg)
	var s2 := DerivedStatService.compute_stats(traits, 1, 1, cfg)

	for key in s1.keys():
		if s1.get(key) != s2.get(key):
			return {
				"ok": false,
				"error": "Non-deterministic output for key '%s': %s vs %s" % [key, str(s1.get(key)), str(s2.get(key))]
			}

	return { "ok": true }


# Test 2: rank_scaling
# Steps:
#   1. Compute stats at rank=1 and rank=2 (same traits/level=1).
#   2. Assert max_hp at rank=2 > rank=1 (hp_per_rank default = 10).
#   3. Assert all other stats at rank=2 >= rank=1 (all per_rank defaults >= 1).
static func _t_rank_scaling() -> Dictionary:
	var traits := { "courage": 50, "wisdom": 50, "faith": 50 }
	var cfg := _stat_cfg()

	var s1 := DerivedStatService.compute_stats(traits, 1, 1, cfg)
	var s2 := DerivedStatService.compute_stats(traits, 2, 1, cfg)

	if int(s2.get("max_hp", 0)) <= int(s1.get("max_hp", 0)):
		return {
			"ok": false,
			"error": "max_hp did not increase from rank=1 (%d) to rank=2 (%d)" % [s1.get("max_hp"), s2.get("max_hp")]
		}

	for key in ["atk", "def", "agi", "int", "cha"]:
		if int(s2.get(key, 0)) < int(s1.get(key, 0)):
			return {
				"ok": false,
				"error": "'%s' decreased from rank=1 (%d) to rank=2 (%d)" % [key, s1.get(key), s2.get(key)]
			}

	return { "ok": true }


# Test 3: level_scaling
# Steps:
#   1. Compute stats at level=1 and level=2 (same traits/rank=1).
#   2. Assert max_hp at level=2 > level=1 (hp_per_level default = 5).
#   3. Assert agi is identical at level=1 and level=2 (agi_per_level default = 0).
static func _t_level_scaling() -> Dictionary:
	var traits := { "courage": 50, "wisdom": 50, "faith": 50 }
	var cfg := _stat_cfg()

	var s1 := DerivedStatService.compute_stats(traits, 1, 1, cfg)
	var s2 := DerivedStatService.compute_stats(traits, 1, 2, cfg)

	if int(s2.get("max_hp", 0)) <= int(s1.get("max_hp", 0)):
		return {
			"ok": false,
			"error": "max_hp did not increase from level=1 (%d) to level=2 (%d)" % [s1.get("max_hp"), s2.get("max_hp")]
		}

	if int(s2.get("agi", -1)) != int(s1.get("agi", -2)):
		return {
			"ok": false,
			"error": "agi should be identical at level=1 and level=2 (agi_per_level=0), got %d vs %d" % [s1.get("agi"), s2.get("agi")]
		}

	return { "ok": true }


# Test 4: factory_matches_service
# Steps:
#   1. Generate an echo via EchoFactory.generate() with a known seed + config.
#   2. Extract echo.traits and the birth_stats sub-dict from the same config.
#   3. Call DerivedStatService.compute_stats(echo.traits, 1, 1, birth_cfg).
#   4. Assert all 6 keys match echo.stats exactly — confirms EchoFactory delegates correctly.
static func _t_factory_matches_service() -> Dictionary:
	var cfg := _summoning_cfg()
	var echo := EchoFactory.generate("test-seed-prog002", "campaign.summon.0", 0, "summon", cfg)
	echo["id"] = "echo_prog002"

	var birth_cfg: Dictionary = cfg.get("birth_stats", {})
	var from_service: Dictionary = DerivedStatService.compute_stats(echo.get("traits", {}), 1, 1, birth_cfg)
	var from_factory: Dictionary = echo.get("stats", {})

	for key in ["max_hp", "atk", "def", "agi", "int", "cha"]:
		var sv: int = int(from_service.get(key, -1))
		var fv: int = int(from_factory.get(key, -2))
		if sv != fv:
			return {
				"ok": false,
				"error": "Mismatch on '%s': service=%d, factory=%d" % [key, sv, fv]
			}

	return { "ok": true }


# -------------------------
# Helpers
# -------------------------

## Minimal stat config. All per_rank / per_level values use DerivedStatService safe defaults,
## so passing only hp_base is sufficient for determinism and scaling tests.
static func _stat_cfg() -> Dictionary:
	return { "hp_base": 100 }


## Full summoning config matching balance.json shape — includes birth_stats.
## Used by factory_matches_service to ensure EchoFactory and the service receive identical input.
static func _summoning_cfg() -> Dictionary:
	return {
		"trait_min": 30,
		"trait_max": 70,
		"calling_weights":      { "uncalled": 0.90, "called": 0.05, "chosen": 0.05 },
		"class_origin_weights": { "protector": 1.0, "vanguard": 1.0, "seeker": 1.0, "pillar": 1.0 },
		"birth_stats":          { "hp_base": 100 }
	}
