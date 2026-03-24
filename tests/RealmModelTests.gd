# res://tests/RealmModelTests.gd
# REALM-001: Tests for RealmModel factory + RealmService core logic.
#
# Tests:
#   1. realm_model_fields_present     — RealmModel.make() returns dict with all 11 required keys
#   2. realm_model_validate_passes    — RealmModel.validate() returns true for a valid model
#   3. realm_service_first_create     — New realm → status "active", run_count=0, seed non-zero, stage_count in range
#   4. realm_service_returns_cached   — get_or_create on an "active" realm → same model unchanged
#   5. realm_service_rerun_completed  — get_or_create on a "completed" realm → run_count=1, different seed
#   6. realm_service_determinism      — Same campaign seed + realm_id → identical seed + stage_count
#   7. runtime_lock_active            — realm.01 "active" → realm.02 ("not_started") is locked
#   8. runtime_lock_completed_open    — Completed realm is never locked regardless of other states

extends RefCounted
class_name RealmModelTests


# ─── Mock Config Service ────────────────────────────────────────────────────
# Minimal stand-in for ConfigService — only implements get_realms().
class MockConfigService extends RefCounted:
	func get_realms() -> Dictionary:
		return {
			"data": {
				"realm_order": ["realm.01", "realm.02"],
				"realms": {
					"realm.01": {
						"id":              "realm.01",
						"name":            "Vale of Dust",
						"virtue":          "courage",
						"description":     "A forgotten stretch of bleached earth.",
						"locked":          false,
						"seed_namespace":  "campaign.realm.01",
						"stage_count_min": 3,
						"stage_count_max": 4,
					},
					"realm.02": {
						"id":              "realm.02",
						"name":            "The Ashen Hollow",
						"virtue":          "wisdom",
						"description":     "A sunken basin choked with calcified grief.",
						"locked":          false,
						"seed_namespace":  "campaign.realm.02",
						"stage_count_min": 5,
						"stage_count_max": 7,
					},
				}
			}
		}


# ─── Helpers ────────────────────────────────────────────────────────────────
static func _make_ctx(root_seed: int = 12345) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = MockConfigService.new()
	ctx.campaign_seed  = CampaignSeed.new(root_seed)
	ctx.save_data      = { "realms": {} }
	var logger         := StructuredLogger.new()
	logger.set_level("warn")  # suppress test noise
	ctx.logger = logger
	ctx.save_request        = false
	ctx.save_request_reason = ""
	return ctx


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("realm/model_fields_present",    Callable(RealmModelTests, "_t_model_fields_present"))
	runner.register_test("realm/model_validate_passes",   Callable(RealmModelTests, "_t_model_validate_passes"))
	runner.register_test("realm/service_first_create",    Callable(RealmModelTests, "_t_service_first_create"))
	runner.register_test("realm/service_returns_cached",  Callable(RealmModelTests, "_t_service_returns_cached"))
	runner.register_test("realm/service_rerun_completed", Callable(RealmModelTests, "_t_service_rerun_completed"))
	runner.register_test("realm/service_determinism",     Callable(RealmModelTests, "_t_service_determinism"))
	runner.register_test("realm/runtime_lock_active",     Callable(RealmModelTests, "_t_runtime_lock_active"))
	runner.register_test("realm/runtime_lock_completed",  Callable(RealmModelTests, "_t_runtime_lock_completed_open"))


# ─── Test 1 — All 11 required fields present ────────────────────────────────
static func _t_model_fields_present() -> Dictionary:
	var model := RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", 999, 3, 0, 0)
	for key in RealmModel.REQUIRED_FIELDS:
		if not model.has(key):
			return { "ok": false, "error": "RealmModel.make() missing required field: %s" % key }
	return { "ok": true }


# ─── Test 2 — validate() returns true ───────────────────────────────────────
static func _t_model_validate_passes() -> Dictionary:
	var model := RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", 999, 3, 0, 0)
	if not RealmModel.validate(model):
		return { "ok": false, "error": "RealmModel.validate() returned false for a valid model" }
	return { "ok": true }


# ─── Test 3 — First creation: status, run_count, seed, stage_count ──────────
static func _t_service_first_create() -> Dictionary:
	var ctx := _make_ctx(42)
	var model: Dictionary = RealmService.get_or_create("realm.01", ctx, 1)

	if model.is_empty():
		return { "ok": false, "error": "RealmService returned empty dict on first create" }

	if str(model.get("status", "")) != RealmModel.STATUS_ACTIVE:
		return { "ok": false, "error": "Expected status='active', got: %s" % model.get("status", "") }

	if int(model.get("run_count", -1)) != 0:
		return { "ok": false, "error": "Expected run_count=0, got: %s" % model.get("run_count") }

	var seed: int = int(model.get("seed", 0))
	if seed == 0:
		return { "ok": false, "error": "Expected non-zero seed, got 0" }

	var stage_count: int = int(model.get("stage_count", 0))
	if stage_count < 3 or stage_count > 4:
		return { "ok": false, "error": "stage_count out of range [3,4]: got %d" % stage_count }

	if not ctx.save_request:
		return { "ok": false, "error": "save_request should be true after first create" }

	return { "ok": true }


# ─── Test 4 — Active realm returned from cache, not recreated ───────────────
static func _t_service_returns_cached() -> Dictionary:
	var ctx := _make_ctx(42)
	var first: Dictionary = RealmService.get_or_create("realm.01", ctx, 1)

	# Reset save_request so we can detect if a new model was created
	ctx.save_request = false

	var second: Dictionary = RealmService.get_or_create("realm.01", ctx, 2)

	if second.is_empty():
		return { "ok": false, "error": "Second call returned empty dict" }

	if int(second.get("seed", -1)) != int(first.get("seed", -2)):
		return { "ok": false, "error": "Cached model seed changed on second call (model was recreated)" }

	if ctx.save_request:
		return { "ok": false, "error": "save_request should NOT be triggered for a cached active realm" }

	return { "ok": true }


# ─── Test 5 — Re-run on completed realm: run_count=1, different seed ────────
static func _t_service_rerun_completed() -> Dictionary:
	var ctx := _make_ctx(42)
	var first: Dictionary = RealmService.get_or_create("realm.01", ctx, 1)
	var first_seed: int = int(first.get("seed", 0))

	# Simulate completion: mutate the model in save_data
	ctx.save_data["realms"]["realm.01"]["status"] = RealmModel.STATUS_COMPLETED

	ctx.save_request = false
	var rerun: Dictionary = RealmService.get_or_create("realm.01", ctx, 2)

	if rerun.is_empty():
		return { "ok": false, "error": "Re-run call returned empty dict" }

	if int(rerun.get("run_count", -1)) != 1:
		return { "ok": false, "error": "Expected run_count=1 on re-run, got: %s" % rerun.get("run_count") }

	if int(rerun.get("seed", 0)) == first_seed:
		return { "ok": false, "error": "Re-run seed should differ from first run (got same: %d)" % first_seed }

	if str(rerun.get("status", "")) != RealmModel.STATUS_ACTIVE:
		return { "ok": false, "error": "Re-run model status should be 'active', got: %s" % rerun.get("status") }

	if not ctx.save_request:
		return { "ok": false, "error": "save_request should be true after re-run create" }

	return { "ok": true }


# ─── Test 6 — Determinism: same root seed → same realm seed + stage_count ───
static func _t_service_determinism() -> Dictionary:
	var ctx_a := _make_ctx(7777)
	var model_a: Dictionary = RealmService.get_or_create("realm.01", ctx_a, 1)

	var ctx_b := _make_ctx(7777)
	var model_b: Dictionary = RealmService.get_or_create("realm.01", ctx_b, 1)

	if int(model_a.get("seed", 0)) != int(model_b.get("seed", 0)):
		return { "ok": false, "error": "Seed not deterministic: %d vs %d" % [model_a.get("seed"), model_b.get("seed")] }

	if int(model_a.get("stage_count", 0)) != int(model_b.get("stage_count", 0)):
		return { "ok": false, "error": "stage_count not deterministic: %d vs %d" % [model_a.get("stage_count"), model_b.get("stage_count")] }

	return { "ok": true }


# ─── Test 7 — Lock: realm.01 active → realm.02 (not_started) locked ─────────
static func _t_runtime_lock_active() -> Dictionary:
	var save_realms := {
		"realm.01": {
			"id":     "realm.01",
			"status": RealmModel.STATUS_ACTIVE,
		}
	}

	var realm_cfg_list: Array = [
		{ "id": "realm.01", "locked": false },
		{ "id": "realm.02", "locked": false },
	]

	var locks: Dictionary = RealmService.compute_runtime_locks(realm_cfg_list, save_realms)

	if locks.get("realm.01", true) == true:
		return { "ok": false, "error": "Active realm.01 should NOT be locked" }

	if locks.get("realm.02", false) != true:
		return { "ok": false, "error": "realm.02 (not_started) should be locked when realm.01 is active" }

	return { "ok": true }


# ─── Test 8 — Lock: completed realm is never locked ─────────────────────────
static func _t_runtime_lock_completed_open() -> Dictionary:
	var save_realms := {
		"realm.01": { "id": "realm.01", "status": RealmModel.STATUS_ACTIVE },
		"realm.02": { "id": "realm.02", "status": RealmModel.STATUS_COMPLETED },
	}

	var realm_cfg_list: Array = [
		{ "id": "realm.01", "locked": false },
		{ "id": "realm.02", "locked": false },
	]

	var locks: Dictionary = RealmService.compute_runtime_locks(realm_cfg_list, save_realms)

	if locks.get("realm.02", true) == true:
		return { "ok": false, "error": "Completed realm.02 should NOT be locked even when realm.01 is active" }

	return { "ok": true }
