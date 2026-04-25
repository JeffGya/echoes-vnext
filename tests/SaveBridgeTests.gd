# res://tests/SaveBridgeTests.gd
# V2-MIG-002: Save schema bridge tests.
# Covers: new save V2 stub keys, repair mirroring of V1 progression values,
#   unlocked_vows Array → vows Dict migration, economy/sanctum V2 stubs, idempotency.
# No OS time, no RNG, no file I/O.

class_name SaveBridgeTests
extends RefCounted

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("bridge/new_save_has_v2_economy_roots",    Callable(SaveBridgeTests, "_test_new_save_economy_stubs"))
	runner.register_test("bridge/new_save_has_v2_sanctum_roots",    Callable(SaveBridgeTests, "_test_new_save_sanctum_stubs"))
	runner.register_test("bridge/new_save_has_stage_intel_stub",    Callable(SaveBridgeTests, "_test_new_save_intel_stub"))
	runner.register_test("bridge/repair_progression_mirrors",       Callable(SaveBridgeTests, "_test_repair_progression_mirrors"))
	runner.register_test("bridge/repair_economy_v2_stubs",         Callable(SaveBridgeTests, "_test_repair_economy_stubs"))
	runner.register_test("bridge/repair_sanctum_v2_stubs",         Callable(SaveBridgeTests, "_test_repair_sanctum_stubs"))
	runner.register_test("bridge/repair_migrates_vow_array",       Callable(SaveBridgeTests, "_test_repair_migrates_vow_array"))
	runner.register_test("bridge/repair_is_idempotent",            Callable(SaveBridgeTests, "_test_repair_idempotent"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


## Minimal old-style save that lacks all V2 fields.
static func _make_old_save() -> Dictionary:
	return {
		"schema_version": 1,
		"first_boot": false,
		"meta": {
			"created_at_unix": 1000000,
			"last_saved_at_unix": 1000000,
			"app_version": "vNext-dev"
		},
		"campaign": {
			"root_seed": 42,
			"tick": 5,
			"seed_root": "legacy:42",
			"seed_source": "imported"
		},
		"flow": { "state": "flow.sanctum", "context": {} },
		"economy": {
			"ase": 120,
			"ekwan": 0,
			"last_settle_unix": 1000000,
			"last_offline_unix": 1000000,
		},
		"sanctum": {
			"ase": 0,
			"roster": [
				{
					"id": "echo_001",
					"name": "Yaw",
					"gender": "male",
					"origin": "abosom",
					"summon_index": 0,
					"seed_path": "sanctum.summon.0",
					"class_origin": "seeker",
					"archetype_birth": "reflective",
					"traits": { "courage": 40, "wisdom": 60, "faith": 50 },
					"stats": { "max_hp": 20, "atk": 5, "def": 4, "agi": 6, "int": 7, "cha": 5 },
					"xp_total": 500,
					"rank": 3,
					"level": 4,
					"vector_scores": { "seeker": 200, "pillar": 50 },
					"rarity": "called",
					"generation_context": { "modifiers": {} },
					"emotion": { "faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 10 },
					"skill_slots": [""],
				}
			],
			"active_party_ids": ["echo_001"],
			"name": "House of Embers",
			"name_roll_index": 2,
			"starter_granted": true,
			"summon_count": 1,
			"bonds": [],
			"party_encounters": [],
			"active_vow": {},
			"unlocked_vows": [
				{ "vow_id": "tikoro_nko_agyina", "max_tier_unlocked": 1, "discovered_realm": "realm.01" }
			],
		},
		"stage_context": { "active_directive_id": "directive.none" },
		"realms": {},
	}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## make_new_save() includes all V2 economy stubs.
static func _test_new_save_economy_stubs() -> Dictionary:
	var save := SaveSchema.make_new_save(999)
	var econ: Dictionary = save.get("economy", {})

	for key in ["relics", "faith", "harmony", "favor"]:
		if not econ.has(key):
			return { "ok": false, "error": "economy missing V2 stub key: %s" % key }
		if int(econ[key]) != 0:
			return { "ok": false, "error": "economy.%s expected 0, got %d" % [key, int(econ[key])] }

	return { "ok": true }


## make_new_save() includes all V2 sanctum stubs (vows Dict, continuity, threads).
static func _test_new_save_sanctum_stubs() -> Dictionary:
	var save := SaveSchema.make_new_save(999)
	var sanctum: Dictionary = save.get("sanctum", {})

	if not sanctum.has("vows") or not (sanctum["vows"] is Dictionary):
		return { "ok": false, "error": "sanctum missing 'vows' Dict" }
	if sanctum.has("unlocked_vows"):
		return { "ok": false, "error": "sanctum should NOT have 'unlocked_vows' in new saves" }
	if not sanctum.has("continuity"):
		return { "ok": false, "error": "sanctum missing 'continuity'" }
	if int(sanctum.get("continuity", -1)) != 0:
		return { "ok": false, "error": "sanctum.continuity expected 0" }
	if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
		return { "ok": false, "error": "sanctum missing 'threads' Dict" }

	return { "ok": true }


## make_new_save() includes stage_context.intel stub.
static func _test_new_save_intel_stub() -> Dictionary:
	var save := SaveSchema.make_new_save(999)
	var sc: Dictionary = save.get("stage_context", {})

	if not sc.has("intel") or not (sc["intel"] is Dictionary):
		return { "ok": false, "error": "stage_context missing 'intel' Dict" }

	return { "ok": true }


## Old echo with xp_total/rank/level gets storyweight/standing/step mirrored correctly.
static func _test_repair_progression_mirrors() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save()

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var echo: Dictionary = (save["sanctum"]["roster"] as Array)[0]

	if not echo.has("storyweight"):
		return { "ok": false, "error": "echo missing storyweight after repair" }
	if int(echo["storyweight"]) != 500:
		return { "ok": false, "error": "storyweight expected 500 (mirrored xp_total), got %d" % int(echo["storyweight"]) }
	if int(echo.get("standing", -1)) != 3:
		return { "ok": false, "error": "standing expected 3 (mirrored rank), got %d" % int(echo.get("standing", -1)) }
	if int(echo.get("step", -1)) != 4:
		return { "ok": false, "error": "step expected 4 (mirrored level), got %d" % int(echo.get("step", -1)) }

	return { "ok": true }


## Old save missing economy V2 stubs gets them added at 0.
static func _test_repair_economy_stubs() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save()

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var econ: Dictionary = save.get("economy", {})
	for key in ["relics", "faith", "harmony", "favor"]:
		if not econ.has(key):
			return { "ok": false, "error": "economy missing V2 stub after repair: %s" % key }
		if int(econ[key]) != 0:
			return { "ok": false, "error": "economy.%s expected 0 after repair, got %d" % [key, int(econ[key])] }

	return { "ok": true }


## Old save missing sanctum V2 stubs (continuity, threads, intel) gets them added.
static func _test_repair_sanctum_stubs() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save()

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var sanctum: Dictionary = save.get("sanctum", {})
	if not sanctum.has("continuity") or int(sanctum.get("continuity", -1)) != 0:
		return { "ok": false, "error": "sanctum.continuity missing or not 0 after repair" }
	if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
		return { "ok": false, "error": "sanctum.threads missing or wrong type after repair" }

	var sc: Dictionary = save.get("stage_context", {})
	if not sc.has("intel") or not (sc["intel"] is Dictionary):
		return { "ok": false, "error": "stage_context.intel missing after repair" }

	return { "ok": true }


## Old save with unlocked_vows Array is migrated to canonical vows Dict.
static func _test_repair_migrates_vow_array() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save()

	# Verify old shape is present before repair
	var sanctum_before: Dictionary = save.get("sanctum", {})
	if not sanctum_before.has("unlocked_vows"):
		return { "ok": false, "error": "test setup error: old_save missing unlocked_vows" }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var sanctum: Dictionary = save.get("sanctum", {})

	# unlocked_vows must be gone
	if sanctum.has("unlocked_vows"):
		return { "ok": false, "error": "unlocked_vows should have been erased after migration" }

	# vows must be a Dict
	if not sanctum.has("vows") or not (sanctum["vows"] is Dictionary):
		return { "ok": false, "error": "sanctum.vows missing or wrong type after migration" }

	var vows: Dictionary = sanctum["vows"]
	if not vows.has("tikoro_nko_agyina"):
		return { "ok": false, "error": "migrated vows missing expected vow_id" }

	var entry: Dictionary = vows["tikoro_nko_agyina"]
	if int(entry.get("tier", 0)) != 1:
		return { "ok": false, "error": "migrated vow tier expected 1, got %d" % int(entry.get("tier", 0)) }
	if str(entry.get("discovered_realm", "")) != "realm.01":
		return { "ok": false, "error": "migrated vow discovered_realm expected 'realm.01'" }

	return { "ok": true }


## Running repair twice on the same save produces identical results (no doubles, no drift).
static func _test_repair_idempotent() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save()

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)
	var first_vows: Dictionary = (save["sanctum"]["vows"] as Dictionary).duplicate(true)
	var first_storyweight: int = int((save["sanctum"]["roster"] as Array)[0].get("storyweight", -99))

	# Second repair pass
	SaveService._apply_additive_defaults_and_repairs(save, logger, 1)

	var second_vows: Dictionary = save["sanctum"]["vows"]
	if second_vows.size() != first_vows.size():
		return { "ok": false, "error": "Idempotency fail: vows.size changed on second repair" }

	var second_storyweight: int = int((save["sanctum"]["roster"] as Array)[0].get("storyweight", -99))
	if second_storyweight != first_storyweight:
		return { "ok": false, "error": "Idempotency fail: storyweight changed on second repair" }

	if save.get("sanctum", {}).has("unlocked_vows"):
		return { "ok": false, "error": "Idempotency fail: unlocked_vows re-appeared after second repair" }

	return { "ok": true }
