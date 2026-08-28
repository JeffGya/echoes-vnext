# res://tests/SaveBridgeTests.gd
# V2-MIG-002: Save schema bridge tests.
# Covers: new save V2 stub keys, repair mirroring of V1 progression values,
#   economy/sanctum V2 stubs, idempotency.
# V2-INFRA-003 dead-path cleanup: the legacy unlocked_vows Array -> vows Dict
#   migration (and other proven-unreachable Job-2 migrations) were removed from
#   SaveService — see bridge/fresh_save_triggers_no_removed_legacy_migrations.
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
	runner.register_test("bridge/repair_is_idempotent",            Callable(SaveBridgeTests, "_test_repair_idempotent"))

	# V2-INFRA-003: proves the removed legacy-migration code paths (campaign.seed_root
	# from root_seed, onboarding from first_boot, rarity common->uncalled, stats
	# spd/hp migration, V1->V2 calling ID migration, unlocked_vows->vows migration)
	# are unreachable for any save this codebase can actually produce.
	runner.register_test("bridge/fresh_save_triggers_no_removed_legacy_migrations", Callable(SaveBridgeTests, "_test_fresh_save_triggers_no_removed_legacy_migrations"))

	# V2-INFRA-003 Phase 8 groundwork: additive-only save fields (flow.pending_result,
	# per-stage settlement_receipt, onboarding.opening_realm_id/opening_realm_status).
	# Nothing reads or writes these yet — coverage here only proves schema + repair.
	runner.register_test("bridge/phase8_new_save_has_defaults",          Callable(SaveBridgeTests, "_test_phase8_new_save_has_defaults"))
	runner.register_test("bridge/phase8_repair_adds_missing_fields",     Callable(SaveBridgeTests, "_test_phase8_repair_adds_missing_fields"))
	runner.register_test("bridge/phase8_repair_adds_settlement_receipt", Callable(SaveBridgeTests, "_test_phase8_repair_adds_settlement_receipt"))
	runner.register_test("bridge/phase8_repair_is_idempotent",           Callable(SaveBridgeTests, "_test_phase8_repair_idempotent"))
	runner.register_test("bridge/phase8_repair_preserves_existing_data", Callable(SaveBridgeTests, "_test_phase8_repair_preserves_existing_data"))
	runner.register_test("bridge/legacy_flow_state_context_still_loads", Callable(SaveBridgeTests, "_test_legacy_flow_state_context_still_loads"))


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
	if not sanctum.has("ase_flame") or not (sanctum["ase_flame"] is Dictionary):
		return { "ok": false, "error": "sanctum missing 'ase_flame' Dict" }

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
	# This old-shaped save predates ase_flame. ase_flame.awakened must backfill from
	# the player's current onboarding progress (keeper_intro_complete) — not from the
	# removed legacy first_boot-derivation, which no longer exists (V2-INFRA-003).
	save["onboarding"] = { "keeper_intro_complete": true }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var sanctum: Dictionary = save.get("sanctum", {})
	if not sanctum.has("continuity") or int(sanctum.get("continuity", -1)) != 0:
		return { "ok": false, "error": "sanctum.continuity missing or not 0 after repair" }
	if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
		return { "ok": false, "error": "sanctum.threads missing or wrong type after repair" }
	if not sanctum.has("ase_flame") or not (sanctum["ase_flame"] is Dictionary):
		return { "ok": false, "error": "sanctum.ase_flame missing or wrong type after repair" }
	if not bool((sanctum["ase_flame"] as Dictionary).get("awakened", false)):
		return { "ok": false, "error": "old completed save should backfill awakened Ase flame" }

	var sc: Dictionary = save.get("stage_context", {})
	if not sc.has("intel") or not (sc["intel"] is Dictionary):
		return { "ok": false, "error": "stage_context.intel missing after repair" }

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

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-INFRA-003 Phase 8 groundwork helpers + tests
# ---------------------------------------------------------------------------

## Old-style save (no onboarding block, no flow.pending_result, one realm with one
## stage lacking settlement_receipt) — exercises every "missing" repair branch at once.
static func _make_old_save_with_stage() -> Dictionary:
	var save := _make_old_save()
	save["realms"] = {
		"realm.01": {
			"realm_id": "realm.01",
			"realm_recovery_segments": [],
			"stages": [
				{
					"index": 0,
					"objectives": [],
				}
			],
		}
	}
	return save


static func _get_stage0(save: Dictionary) -> Dictionary:
	var realms: Dictionary = save.get("realms", {})
	var realm: Dictionary = realms.get("realm.01", {})
	var stages: Array = realm.get("stages", [])
	return stages[0] if stages.size() > 0 else {}


## make_new_save() carries the documented Phase 8 defaults.
static func _test_phase8_new_save_has_defaults() -> Dictionary:
	var save := SaveSchema.make_new_save(999)

	var flow: Dictionary = save.get("flow", {})
	if not flow.has("pending_result") or not (flow["pending_result"] is Dictionary):
		return { "ok": false, "error": "flow missing 'pending_result' Dict" }
	if not (flow["pending_result"] as Dictionary).is_empty():
		return { "ok": false, "error": "flow.pending_result expected {} default" }

	var onboarding: Dictionary = save.get("onboarding", {})
	if not onboarding.has("opening_realm_id") or typeof(onboarding["opening_realm_id"]) != TYPE_STRING:
		return { "ok": false, "error": "onboarding missing 'opening_realm_id' String" }
	if str(onboarding["opening_realm_id"]) != "":
		return { "ok": false, "error": "onboarding.opening_realm_id expected '' default" }
	if not onboarding.has("opening_realm_status") or typeof(onboarding["opening_realm_status"]) != TYPE_STRING:
		return { "ok": false, "error": "onboarding missing 'opening_realm_status' String" }
	if str(onboarding["opening_realm_status"]) != "locked":
		return { "ok": false, "error": "onboarding.opening_realm_status expected 'locked' default" }

	return { "ok": true }


## A save written without the new fields gains them on load/repair, with correct defaults.
static func _test_phase8_repair_adds_missing_fields() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save_with_stage()

	# Sanity-check test setup: fields genuinely absent before repair.
	if (save.get("flow", {}) as Dictionary).has("pending_result"):
		return { "ok": false, "error": "test setup error: flow already has pending_result" }
	if save.has("onboarding"):
		return { "ok": false, "error": "test setup error: save already has onboarding" }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var flow: Dictionary = save.get("flow", {})
	if not flow.has("pending_result") or not (flow["pending_result"] is Dictionary) or not (flow["pending_result"] as Dictionary).is_empty():
		return { "ok": false, "error": "flow.pending_result not repaired to {} default" }

	var onboarding: Dictionary = save.get("onboarding", {})
	if str(onboarding.get("opening_realm_id", "MISSING")) != "":
		return { "ok": false, "error": "onboarding.opening_realm_id not repaired to '' default" }
	if str(onboarding.get("opening_realm_status", "MISSING")) != "locked":
		return { "ok": false, "error": "onboarding.opening_realm_status not repaired to 'locked' default" }

	return { "ok": true }


## A stage lacking settlement_receipt gains it as {} on repair.
static func _test_phase8_repair_adds_settlement_receipt() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save_with_stage()

	var stage_before := _get_stage0(save)
	if stage_before.has("settlement_receipt"):
		return { "ok": false, "error": "test setup error: stage already has settlement_receipt" }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var stage_after := _get_stage0(save)
	if not stage_after.has("settlement_receipt") or not (stage_after["settlement_receipt"] is Dictionary):
		return { "ok": false, "error": "stage.settlement_receipt missing or wrong type after repair" }
	if not (stage_after["settlement_receipt"] as Dictionary).is_empty():
		return { "ok": false, "error": "stage.settlement_receipt expected {} default" }

	return { "ok": true }


## Running repair twice changes none of the three Phase 8 fields the second time.
static func _test_phase8_repair_idempotent() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save_with_stage()

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)
	var first_pending_result: Dictionary = (save["flow"]["pending_result"] as Dictionary).duplicate(true)
	var first_receipt: Dictionary = (_get_stage0(save)["settlement_receipt"] as Dictionary).duplicate(true)
	var first_realm_id: String = str(save["onboarding"]["opening_realm_id"])
	var first_realm_status: String = str(save["onboarding"]["opening_realm_status"])

	var repaired_second := SaveService._apply_additive_defaults_and_repairs(save, logger, 1)

	if repaired_second:
		return { "ok": false, "error": "second repair pass reported changes; expected no-op" }

	var second_pending_result: Dictionary = save["flow"]["pending_result"]
	if second_pending_result.size() != first_pending_result.size():
		return { "ok": false, "error": "Idempotency fail: flow.pending_result changed on second repair" }

	var second_receipt: Dictionary = _get_stage0(save)["settlement_receipt"]
	if second_receipt.size() != first_receipt.size():
		return { "ok": false, "error": "Idempotency fail: settlement_receipt changed on second repair" }

	if str(save["onboarding"]["opening_realm_id"]) != first_realm_id:
		return { "ok": false, "error": "Idempotency fail: onboarding.opening_realm_id changed on second repair" }
	if str(save["onboarding"]["opening_realm_status"]) != first_realm_status:
		return { "ok": false, "error": "Idempotency fail: onboarding.opening_realm_status changed on second repair" }

	return { "ok": true }


## An existing save with real data in these fields is never overwritten by repair.
static func _test_phase8_repair_preserves_existing_data() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save_with_stage()

	save["flow"]["pending_result"] = {
		"version": 1,
		"result_id": "res_abc123",
		"status": "pending_resolve",
	}
	_get_stage0(save)["settlement_receipt"] = {
		"version": 1,
		"result_id": "res_abc123",
		"settled": true,
		"outcome": "victory",
		"settled_t": 42,
	}
	save["onboarding"] = {
		"chapter_one_complete": true,
		"chapter_one_step": "complete",
		"fragment_options": [],
		"heard_fragments": [],
		"selected_fragment": "",
		"name_options": [],
		"keeper_intro_complete": true,
		"keeper_intro_step": "complete",
		"keeper_trial_phase": "ready",
		"keeper_trial_rewind_used": false,
		"first_thread_id": "",
		"first_trial_rewards_granted": true,
		"awakening_choice": "",
		"opening_realm_id": "realm.01",
		"opening_realm_status": "active",
	}

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var pending_result: Dictionary = save["flow"]["pending_result"]
	if str(pending_result.get("result_id", "")) != "res_abc123":
		return { "ok": false, "error": "repair overwrote flow.pending_result.result_id" }
	if str(pending_result.get("status", "")) != "pending_resolve":
		return { "ok": false, "error": "repair overwrote flow.pending_result.status" }

	var receipt: Dictionary = _get_stage0(save)["settlement_receipt"]
	if not bool(receipt.get("settled", false)):
		return { "ok": false, "error": "repair overwrote stage.settlement_receipt.settled" }
	if str(receipt.get("outcome", "")) != "victory":
		return { "ok": false, "error": "repair overwrote stage.settlement_receipt.outcome" }

	var onboarding: Dictionary = save["onboarding"]
	if str(onboarding.get("opening_realm_id", "")) != "realm.01":
		return { "ok": false, "error": "repair overwrote onboarding.opening_realm_id" }
	if str(onboarding.get("opening_realm_status", "")) != "active":
		return { "ok": false, "error": "repair overwrote onboarding.opening_realm_status" }

	return { "ok": true }


## flow.state / flow.context are deleted fields. A save written before the deletion still
## carries them. It must repair and validate without complaint, and the dead keys are simply
## left where they are.
static func _test_legacy_flow_state_context_still_loads() -> Dictionary:
	var logger := _make_logger()
	var save := _make_old_save_with_stage()
	save["flow"] = { "state": "flow.stage", "context": { "foo": "bar" } }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	var flow: Dictionary = save["flow"]
	if not flow.has("pending_result") or not (flow["pending_result"] is Dictionary) or not (flow["pending_result"] as Dictionary).is_empty():
		return { "ok": false, "error": "flow.pending_result not added to {} default" }
	if str(flow.get("state", "")) != "flow.stage" or str((flow.get("context", {}) as Dictionary).get("foo", "")) != "bar":
		return { "ok": false, "error": "repair disturbed the leftover flow.state / flow.context keys" }
	if not SaveService.validate(save, false):
		return { "ok": false, "error": "a save carrying legacy flow.state failed validation" }

	# A save with no flow.state at all must validate too — that is every save written from now on.
	var fresh := _make_old_save_with_stage()
	fresh.erase("flow")
	SaveService._apply_additive_defaults_and_repairs(fresh, logger, 0)
	if (fresh["flow"] as Dictionary).has("state"):
		return { "ok": false, "error": "repair reintroduced flow.state" }
	if not SaveService.validate(fresh, false):
		return { "ok": false, "error": "a save without flow.state failed validation" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-INFRA-003 dead-path cleanup: proof that removed legacy migrations
# (campaign.seed_root from root_seed, onboarding from first_boot, rarity
# common->uncalled, roster stats spd/hp migration, V1->V2 calling ID migration,
# unlocked_vows Array -> vows Dict migration) are unreachable for any save
# this codebase can actually produce.
# ---------------------------------------------------------------------------

## A save straight out of SaveSchema.make_new_save() already carries every field
## the removed migrations used to backfill (seed_root, onboarding dict, empty
## roster) — proving those code paths had nothing left to do. A second repair
## pass is then a true no-op, proving no migration logic is silently still
## running.
static func _test_fresh_save_triggers_no_removed_legacy_migrations() -> Dictionary:
	var logger := _make_logger()
	var save := SaveSchema.make_new_save(999)

	# Pre-conditions that make the removed migrations dead code for this save:
	var camp: Dictionary = save.get("campaign", {})
	if str(camp.get("seed_root", "")).is_empty():
		return { "ok": false, "error": "test assumption broken: fresh save has no campaign.seed_root" }
	if not save.has("onboarding") or not (save["onboarding"] is Dictionary):
		return { "ok": false, "error": "test assumption broken: fresh save has no onboarding dict" }
	var sanctum: Dictionary = save.get("sanctum", {})
	if sanctum.has("unlocked_vows"):
		return { "ok": false, "error": "test assumption broken: fresh save already has legacy unlocked_vows" }
	if not (sanctum.get("roster", []) as Array).is_empty():
		return { "ok": false, "error": "test assumption broken: fresh save roster is not empty" }

	SaveService._apply_additive_defaults_and_repairs(save, logger, 0)

	# Second pass must be a true no-op: nothing left to migrate or default.
	var second_repaired := SaveService._apply_additive_defaults_and_repairs(save, logger, 1)
	if second_repaired:
		return { "ok": false, "error": "second repair pass on a fresh save reported changes; expected no-op" }

	if save.get("sanctum", {}).has("unlocked_vows"):
		return { "ok": false, "error": "unlocked_vows should never appear on a fresh save" }
	if str(save.get("campaign", {}).get("seed_root", "")).is_empty():
		return { "ok": false, "error": "campaign.seed_root missing after repair" }

	return { "ok": true }
