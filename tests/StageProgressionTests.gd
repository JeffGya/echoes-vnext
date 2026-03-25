# res://tests/StageProgressionTests.gd
# REALM-004: Tests for RealmService.advance_stage() and StageMap snapshot fields.
#
# Tests:
#   1. realm_prog/advance_increments_index         — index +1, not completed, save triggered
#   2. realm_prog/advance_triggers_save            — ctx.save_request == true after advance
#   3. realm_prog/advance_to_last_stage_not_complete — advance to penultimate: not complete
#   4. realm_prog/advance_to_completion            — final advance marks realm complete
#   5. realm_prog/advance_idempotent_when_complete — already-complete model stays unchanged
#   6. realm_prog/advance_empty_model              — no active model → returns {}, no crash
#   7. realm_prog/stage_map_emits_stages_remaining — snapshot has stages_remaining + realm_complete
#   8. realm_prog/stage_map_redirects_on_empty_realm — no realm → error snapshot, no scaffold

extends RefCounted
class_name StageProgressionTests


# ─── Helpers ────────────────────────────────────────────────────────────────

static func _make_ctx(realm_id: String = "realm.01") -> FlowContext:
	var ctx            := FlowContext.new()
	var logger         := StructuredLogger.new()
	logger.set_level("warn")  # suppress test noise
	ctx.logger              = logger
	ctx.realm_id            = realm_id
	ctx.save_request        = false
	ctx.save_request_reason = ""
	ctx.save_data           = { "realms": {} }
	return ctx


# Build a minimal RealmModel dict and inject it directly into ctx.save_data.
# Never calls RealmService.get_or_create() — sets balance directly per lesson learned.
static func _inject_model(ctx: FlowContext, stage_count: int, current_index: int, is_completed: bool = false) -> void:
	var m := RealmModel.make(ctx.realm_id, "Vale of Dust", "courage", "desc", 999, stage_count, 0, 0)
	m["current_stage_index"] = current_index
	m["is_completed"]        = is_completed
	if is_completed:
		m["status"] = RealmModel.STATUS_COMPLETED
	m["stages"] = []  # empty is fine for advancement tests
	ctx.save_data["realms"][ctx.realm_id] = m


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("realm_prog/advance_increments_index",          Callable(StageProgressionTests, "_t_advance_increments_index"))
	runner.register_test("realm_prog/advance_triggers_save",             Callable(StageProgressionTests, "_t_advance_triggers_save"))
	runner.register_test("realm_prog/advance_to_last_stage_not_complete",Callable(StageProgressionTests, "_t_advance_to_last_stage_not_complete"))
	runner.register_test("realm_prog/advance_to_completion",             Callable(StageProgressionTests, "_t_advance_to_completion"))
	runner.register_test("realm_prog/advance_idempotent_when_complete",  Callable(StageProgressionTests, "_t_advance_idempotent_when_complete"))
	runner.register_test("realm_prog/advance_empty_model",               Callable(StageProgressionTests, "_t_advance_empty_model"))
	runner.register_test("realm_prog/stage_map_emits_stages_remaining",  Callable(StageProgressionTests, "_t_stage_map_emits_stages_remaining"))
	runner.register_test("realm_prog/stage_map_redirects_on_empty_realm",Callable(StageProgressionTests, "_t_stage_map_redirects_on_empty_realm"))


# ─── Test 1 — advance_stage increments current_stage_index ──────────────────
static func _t_advance_increments_index() -> Dictionary:
	var ctx := _make_ctx()
	_inject_model(ctx, 3, 0)

	var result: Dictionary = RealmService.advance_stage(ctx, 1)

	if result.is_empty():
		return { "ok": false, "error": "advance_stage returned empty dict" }

	var new_index := int(result.get("current_stage_index", -1))
	if new_index != 1:
		return { "ok": false, "error": "Expected current_stage_index=1, got: %d" % new_index }

	if bool(result.get("is_completed", true)):
		return { "ok": false, "error": "Realm should NOT be completed after advancing from index 0 on 3-stage realm" }

	return { "ok": true }


# ─── Test 2 — save_request is set to true ───────────────────────────────────
static func _t_advance_triggers_save() -> Dictionary:
	var ctx := _make_ctx()
	_inject_model(ctx, 3, 0)

	RealmService.advance_stage(ctx, 1)

	if not ctx.save_request:
		return { "ok": false, "error": "ctx.save_request should be true after advance_stage" }

	return { "ok": true }


# ─── Test 3 — advance to penultimate stage → not complete ───────────────────
static func _t_advance_to_last_stage_not_complete() -> Dictionary:
	var ctx := _make_ctx()
	_inject_model(ctx, 3, 1)  # already at index 1, advancing to 2 (still 1 left)

	var result: Dictionary = RealmService.advance_stage(ctx, 1)

	var new_index := int(result.get("current_stage_index", -1))
	if new_index != 2:
		return { "ok": false, "error": "Expected current_stage_index=2, got: %d" % new_index }

	if bool(result.get("is_completed", true)):
		return { "ok": false, "error": "Realm should NOT be complete at index 2 on 3-stage realm (indices 0-2 = 3 stages)" }

	var status := str(result.get("status", ""))
	if status != RealmModel.STATUS_ACTIVE:
		return { "ok": false, "error": "Status should remain 'active', got: %s" % status }

	return { "ok": true }


# ─── Test 4 — advance on final stage → realm complete ───────────────────────
static func _t_advance_to_completion() -> Dictionary:
	var ctx := _make_ctx()
	_inject_model(ctx, 3, 2)  # at index 2; advancing to 3 == stage_count → complete

	var result: Dictionary = RealmService.advance_stage(ctx, 1)

	if not bool(result.get("is_completed", false)):
		return { "ok": false, "error": "Realm should be marked complete after advancing past final stage" }

	var status := str(result.get("status", ""))
	if status != RealmModel.STATUS_COMPLETED:
		return { "ok": false, "error": "Expected status='completed', got: %s" % status }

	var new_index := int(result.get("current_stage_index", -1))
	if new_index != 3:
		return { "ok": false, "error": "Expected current_stage_index=3 (past end), got: %d" % new_index }

	return { "ok": true }


# ─── Test 5 — already-complete model is unchanged (idempotent) ──────────────
static func _t_advance_idempotent_when_complete() -> Dictionary:
	var ctx := _make_ctx()
	_inject_model(ctx, 3, 3, true)  # already completed at index 3

	var before_index := int(ctx.save_data["realms"]["realm.01"].get("current_stage_index", -99))

	var result: Dictionary = RealmService.advance_stage(ctx, 1)

	if result.is_empty():
		return { "ok": false, "error": "advance_stage should return the model even when already complete" }

	var after_index := int(result.get("current_stage_index", -99))
	if after_index != before_index:
		return { "ok": false, "error": "current_stage_index should be unchanged on already-complete realm; was %d, got %d" % [before_index, after_index] }

	return { "ok": true }


# ─── Test 6 — no active model → returns {}, no crash ────────────────────────
static func _t_advance_empty_model() -> Dictionary:
	var ctx := _make_ctx("realm.99")  # realm.99 is not in save_data

	var result: Dictionary = RealmService.advance_stage(ctx, 1)

	if not result.is_empty():
		return { "ok": false, "error": "Expected empty dict for unknown realm, got: %s" % str(result) }

	return { "ok": true }


# ─── Test 7 — StageMapState emits stages_remaining and realm_complete ────────
static func _t_stage_map_emits_stages_remaining() -> Dictionary:
	var ctx := _make_ctx()
	# 3-stage realm at current_stage_index=1 → 1 stage completed, 1 current, 1 locked
	# stages_remaining = 3 - 1 (completed) - 1 (current) = 1
	var m := RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", 999, 3, 0, 0)
	m["current_stage_index"] = 1
	m["is_completed"]        = false
	# Provide a minimal stages array so the state can build its list
	m["stages"] = [
		{ "index": 0, "type": "combat",  "seed": 1, "objectives": [] },
		{ "index": 1, "type": "combat",  "seed": 2, "objectives": [] },
		{ "index": 2, "type": "combat",  "seed": 3, "objectives": [] },
	]
	ctx.save_data["realms"]["realm.01"] = m

	FlowStageMapState.new().enter(ctx, 1)

	var snap: Dictionary = ctx.last_snapshot
	if snap.is_empty():
		return { "ok": false, "error": "No snapshot built" }

	var data: Dictionary = snap.get("data", {})

	var stages_remaining := int(data.get("stages_remaining", -1))
	if stages_remaining != 1:
		return { "ok": false, "error": "Expected stages_remaining=1, got: %d" % stages_remaining }

	if bool(data.get("realm_complete", true)):
		return { "ok": false, "error": "realm_complete should be false for an in-progress realm" }

	var stage_count := int(data.get("stage_count", -1))
	if stage_count != 3:
		return { "ok": false, "error": "Expected stage_count=3, got: %d" % stage_count }

	return { "ok": true }


# ─── Test 8 — StageMapState with no active realm → error snapshot ────────────
static func _t_stage_map_redirects_on_empty_realm() -> Dictionary:
	var ctx := _make_ctx("realm.99")  # realm.99 not in save_data → get_active returns {}

	FlowStageMapState.new().enter(ctx, 1)

	var snap: Dictionary = ctx.last_snapshot
	if snap.is_empty():
		return { "ok": false, "error": "Expected a fallback snapshot, got nothing" }

	var data: Dictionary = snap.get("data", {})
	var error_key: String = str(data.get("error", ""))
	if error_key != "no_active_realm":
		return { "ok": false, "error": "Expected data.error='no_active_realm', got: '%s'" % error_key }

	# nav.back should point to REALM_SELECT so player can escape
	var actions: Dictionary = snap.get("actions", {})
	var back_v: Variant = actions.get("nav.back", {})
	var back: Dictionary = back_v if back_v is Dictionary else {}
	var back_to := str(back.get("to", ""))
	if back_to != FlowStateIds.REALM_SELECT:
		return { "ok": false, "error": "nav.back should route to REALM_SELECT, got: '%s'" % back_to }

	return { "ok": true }
