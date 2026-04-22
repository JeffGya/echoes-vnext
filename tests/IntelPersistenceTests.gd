# res://tests/IntelPersistenceTests.gd
# V2-INTEL-001: Tests for intel persistence across stage session entries.
#
# Tests:
#   1. intel/revealed_survives_session_reset  — revealed=true carries forward after session reset
#   2. intel/resolved_survives_session_reset  — resolved=true carries forward after session reset
#   3. intel/objectives_found_recomputed      — objectives_found recomputed from resolved+objective flags
#   4. intel/intel_clues_carried_forward      — intel_clues and intel_quality carry forward after reset

extends RefCounted
class_name IntelPersistenceTests

const SituationModelScript        := preload("res://core/realms/SituationModel.gd")
const StageExploreModelScript     := preload("res://core/realms/StageExploreModel.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")


# ─── Helpers ─────────────────────────────────────────────────────────────────

static func _make_ctx() -> FlowContext:
	var ctx            := FlowContext.new()
	var logger         := StructuredLogger.new()
	logger.set_level("warn")
	ctx.logger              = logger
	ctx.realm_id            = "realm.01"
	ctx.stage_id            = "stage.0"
	ctx.save_request        = false
	ctx.save_request_reason = ""
	ctx.save_data = {
		"realms": {},
		"sanctum": { "roster": [], "active_party_ids": [] },
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
	}
	ctx.campaign_seed = CampaignSeed.new(42)
	return ctx


static func _inject_realm(ctx: FlowContext, situations: Array) -> void:
	var explore_map := StageExploreModelScript.make(30, 30, situations)
	var stage := StageModel.make(0, StageModel.TYPE_COMBAT, 999, [], explore_map)
	var model  := RealmModel.make(ctx.realm_id, "Vale of Dust", "courage", "desc", 42, 1, 0, 0)
	model["stages"] = [stage]
	ctx.save_data["realms"][ctx.realm_id] = model


# Mark a situation revealed/resolved directly in save_data.
static func _set_situation_flag(ctx: FlowContext, sit_id: String, key: String, value: Variant) -> void:
	var realms_v: Variant = ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var model_v: Variant = realms.get(ctx.realm_id, {})
	var model: Dictionary = model_v if model_v is Dictionary else {}
	var stages_v: Variant = model.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	if stages.is_empty():
		return
	var stage: Dictionary = stages[0] if stages[0] is Dictionary else {}
	var em_v: Variant = stage.get("explore_map", {})
	var em: Dictionary = em_v if em_v is Dictionary else {}
	var sits_v: Variant = em.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	for i in range(sits.size()):
		var s_v: Variant = sits[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s[key] = value
			sits[i] = s
			break
	em["situations"] = sits
	stage["explore_map"] = em
	stages[0] = stage
	model["stages"] = stages
	ctx.save_data["realms"][ctx.realm_id] = model


# Read a situation field from save_data after a session reset.
static func _get_situation_field(ctx: FlowContext, sit_id: String, key: String) -> Variant:
	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var em_v: Variant = stage.get("explore_map", {})
	var em: Dictionary = em_v if em_v is Dictionary else {}
	var sits_v: Variant = em.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	for s_v in sits:
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			return (s_v as Dictionary).get(key)
	return null


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("intel/revealed_survives_session_reset", Callable(IntelPersistenceTests, "_t_revealed_survives_session_reset"))
	runner.register_test("intel/resolved_survives_session_reset", Callable(IntelPersistenceTests, "_t_resolved_survives_session_reset"))
	runner.register_test("intel/objectives_found_recomputed",     Callable(IntelPersistenceTests, "_t_objectives_found_recomputed"))
	runner.register_test("intel/intel_clues_carried_forward",     Callable(IntelPersistenceTests, "_t_intel_clues_carried_forward"))


# ─── Test 1 — revealed=true carries forward after session reset ───────────────
static func _t_revealed_survives_session_reset() -> Dictionary:
	var sits: Array = [
		SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 1001, true),
		SituationModelScript.make("sit.1", SituationModelScript.TYPE_NPC,    15, 15, 1002, false),
	]
	var ctx := _make_ctx()
	_inject_realm(ctx, sits)
	FlowStageExploreStateScript._lock_map_if_needed(ctx, 1)

	# Mark sit.0 as revealed (simulates a prior scout roll succeeding)
	_set_situation_flag(ctx, "sit.0", "revealed", true)

	# Session reset — should preserve revealed
	FlowStageExploreStateScript._reset_session_state(ctx, 2)

	var val: Variant = _get_situation_field(ctx, "sit.0", "revealed")
	if val == null:
		return { "ok": false, "error": "sit.0 not found after reset" }
	if not bool(val):
		return { "ok": false, "error": "revealed was wiped to false — intel persistence broken" }

	# sit.1 should still be false (was never revealed)
	var val1: Variant = _get_situation_field(ctx, "sit.1", "revealed")
	if bool(val1):
		return { "ok": false, "error": "sit.1 should still be hidden" }

	return { "ok": true }


# ─── Test 2 — resolved=true carries forward after session reset ───────────────
static func _t_resolved_survives_session_reset() -> Dictionary:
	var sits: Array = [
		SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 1001, true),
	]
	var ctx := _make_ctx()
	_inject_realm(ctx, sits)
	FlowStageExploreStateScript._lock_map_if_needed(ctx, 1)

	_set_situation_flag(ctx, "sit.0", "resolved", true)
	FlowStageExploreStateScript._reset_session_state(ctx, 2)

	var val: Variant = _get_situation_field(ctx, "sit.0", "resolved")
	if val == null:
		return { "ok": false, "error": "sit.0 not found after reset" }
	if not bool(val):
		return { "ok": false, "error": "resolved was wiped — fail-forward broken" }

	return { "ok": true }


# ─── Test 3 — objectives_found recomputed from resolved+is_objective flags ────
static func _t_objectives_found_recomputed() -> Dictionary:
	var sits: Array = [
		SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5,  5,  1001, true),
		SituationModelScript.make("sit.1", SituationModelScript.TYPE_COMBAT, 15, 15, 1002, true),
		SituationModelScript.make("sit.2", SituationModelScript.TYPE_NPC,    25, 25, 1003, false),
	]
	var ctx := _make_ctx()
	_inject_realm(ctx, sits)
	FlowStageExploreStateScript._lock_map_if_needed(ctx, 1)

	# Mark 2 of 3 as resolved; only the 2 objectives should count
	_set_situation_flag(ctx, "sit.0", "resolved", true)
	_set_situation_flag(ctx, "sit.1", "resolved", true)
	# sit.2 is resolved but NOT an objective — must not count
	_set_situation_flag(ctx, "sit.2", "resolved", true)

	FlowStageExploreStateScript._reset_session_state(ctx, 2)

	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var em_v: Variant = stage.get("explore_map", {})
	var em: Dictionary = em_v if em_v is Dictionary else {}
	var obj_found := int(em.get("objectives_found", -1))

	if obj_found != 2:
		return { "ok": false, "error": "Expected objectives_found=2 (2 resolved objectives), got: %d" % obj_found }

	return { "ok": true }


# ─── Test 4 — intel_clues and intel_quality carry forward after reset ─────────
static func _t_intel_clues_carried_forward() -> Dictionary:
	var sits: Array = [
		SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 1001, true),
	]
	var ctx := _make_ctx()
	_inject_realm(ctx, sits)
	FlowStageExploreStateScript._lock_map_if_needed(ctx, 1)

	# Write intel fields as if a prior scout reveal had succeeded
	_set_situation_flag(ctx, "sit.0", "intel_clues",   ["Tracks in the earth. Something passed through here with intent."])
	_set_situation_flag(ctx, "sit.0", "intel_quality",  "precise")

	FlowStageExploreStateScript._reset_session_state(ctx, 2)

	var clues: Variant = _get_situation_field(ctx, "sit.0", "intel_clues")
	if clues == null or not (clues is Array) or (clues as Array).is_empty():
		return { "ok": false, "error": "intel_clues lost after session reset" }
	if str((clues as Array)[0]) != "Tracks in the earth. Something passed through here with intent.":
		return { "ok": false, "error": "intel_clues content changed after reset" }

	var quality: Variant = _get_situation_field(ctx, "sit.0", "intel_quality")
	if str(quality) != "precise":
		return { "ok": false, "error": "intel_quality lost after reset, got: %s" % str(quality) }

	return { "ok": true }
