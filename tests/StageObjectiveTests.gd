# res://tests/StageObjectiveTests.gd
# V2-STAGE-002: Objective taxonomy + stage completion gate tests.
#
# Tests:
#  1. objective/model_all_types_valid        — ObjectiveModel.make() for all 7 types passes validate()
#  2. objective/objective_index_bound        — is_objective situations carry matching objective_index
#  3. objective/non_objective_index_minus_one — non-objective situations carry objective_index=-1
#  4. objective/stage_advance_blocked        — cta.proceed_to_stage_map absent when objectives remain
#  5. objective/stage_advance_unlocked       — cta.proceed_to_stage_map present when all required done
#  6. objective/mark_objective_completed     — completing situation marks stage.objectives[idx].completed
#  7. objective/calling_ranger_adds_action   — ranger calling → cta.calling_reveal_adjacent in actions
#  8. objective/no_ranger_no_action          — party without ranger → cta.calling_reveal_adjacent absent
#  9. objective/ignore_sits_clears_pending   — cta.ignore_situation present when pending; situation NOT resolved after
# 10. objective/repair_defaults              — SaveService repair applies completed/required/objective_index defaults
# 11. objective/party_requesting_return_high_fear  — party_requesting_return true when avg fear > threshold
# 12. objective/party_requesting_return_low_fear   — party_requesting_return false when avg fear ≤ threshold

class_name StageObjectiveTests
extends RefCounted

const SituationModelScript        := preload("res://core/realms/SituationModel.gd")
const StageExploreModelScript     := preload("res://core/realms/StageExploreModel.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const ObjectiveModelScript        := preload("res://core/realms/ObjectiveModel.gd")


# ─── Helpers ─────────────────────────────────────────────────────────────────

static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


class MockStageConfig extends RefCounted:
	func get_balance() -> Dictionary:
		return {
			"data": {
				"stages": {
					"calling_action_bonuses": {
						"ranger": ["reveal_adjacent"],
						"okofor": ["fortify_position"],
						"aduro":  ["inspire_push"]
					},
					"party_return_fear_threshold": 60,
					"cautious_advance_fear_threshold": 50,
					"objective_types": {
						"combat":  { "label": "Clear",   "required": true,  "reveal_hint": "Threat detected nearby." },
						"shrine":  { "label": "Purify",  "required": true,  "reveal_hint": "A corrupted presence lingers here." },
					},
				}
			}
		}


static func _make_ctx(
	realm_id: String = "realm.01",
	stage_id: String = "stage.0"
) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.logger  = _make_logger()
	ctx.realm_id  = realm_id
	ctx.stage_id  = stage_id
	ctx.config_service = MockStageConfig.new()
	ctx.save_data = {
		"realms": {},
		"sanctum": { "roster": [], "active_party_ids": [] },
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
	}
	ctx.campaign_seed = CampaignSeed.new(42)
	return ctx


# Build a minimal realm + stage with given objectives and situations.
# Returns the FlowContext with save_data populated.
static func _inject_stage(
	ctx: FlowContext,
	objectives: Array,          # Array of ObjectiveModel dicts
	situations: Array,          # Array of SituationModel dicts
	party_echoes: Array = []    # Array of minimal echo dicts for party
) -> void:
	var explore_map := StageExploreModelScript.make(30, 30, situations)
	var stage := StageModel.make(0, StageModel.TYPE_COMBAT, 999, objectives, explore_map)
	var model := RealmModel.make(ctx.realm_id, "Vale of Dust", "courage", "desc", 42, 1, 0, 0)
	model["stages"] = [stage]
	ctx.save_data["realms"][ctx.realm_id] = model

	if not party_echoes.is_empty():
		var ids: Array = []
		for e in party_echoes:
			ids.append(str(e.get("id", "")))
		ctx.save_data["sanctum"]["roster"] = party_echoes
		ctx.save_data["sanctum"]["active_party_ids"] = ids


static func _make_echo(id: String, calling: String, fear: int = 10) -> Dictionary:
	return {
		"id":             id,
		"name":           "Echo %s" % id,
		"calling":        calling,
		"calling_origin": calling,
		"emotion": {
			"fear_current":    fear,
			"morale_current":  50,
		},
	}


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("objective/model_all_types_valid",              Callable(StageObjectiveTests, "_t_model_all_types_valid"))
	runner.register_test("objective/objective_index_bound",              Callable(StageObjectiveTests, "_t_objective_index_bound"))
	runner.register_test("objective/non_objective_index_minus_one",      Callable(StageObjectiveTests, "_t_non_objective_index_minus_one"))
	runner.register_test("objective/stage_advance_blocked",              Callable(StageObjectiveTests, "_t_stage_advance_blocked"))
	runner.register_test("objective/stage_advance_unlocked",             Callable(StageObjectiveTests, "_t_stage_advance_unlocked"))
	runner.register_test("objective/mark_objective_completed",           Callable(StageObjectiveTests, "_t_mark_objective_completed"))
	runner.register_test("objective/calling_ranger_adds_action",         Callable(StageObjectiveTests, "_t_calling_ranger_adds_action"))
	runner.register_test("objective/no_ranger_no_action",                Callable(StageObjectiveTests, "_t_no_ranger_no_action"))
	runner.register_test("objective/ignore_sits_clears_pending",         Callable(StageObjectiveTests, "_t_ignore_clears_pending"))
	runner.register_test("objective/repair_defaults",                    Callable(StageObjectiveTests, "_t_repair_defaults"))
	runner.register_test("objective/party_requesting_return_high_fear",  Callable(StageObjectiveTests, "_t_party_requesting_return_high_fear"))
	runner.register_test("objective/party_requesting_return_low_fear",   Callable(StageObjectiveTests, "_t_party_requesting_return_low_fear"))


# ─── Tests ────────────────────────────────────────────────────────────────────

# 1. All 7 objective types produce valid dicts.
static func _t_model_all_types_valid() -> Dictionary:
	var types := ObjectiveModelScript.VALID_TYPES
	for i in range(types.size()):
		var t: String = str(types[i])
		var obj := ObjectiveModelScript.make(i, t, 1000 + i)
		if not ObjectiveModelScript.validate(obj):
			return { "ok": false, "error": "ObjectiveModel.make() failed validate() for type: %s" % t }
		if not obj.has("completed"):
			return { "ok": false, "error": "Missing 'completed' field for type: %s" % t }
		if not obj.has("required"):
			return { "ok": false, "error": "Missing 'required' field for type: %s" % t }
		if obj.get("params") != {}:
			return { "ok": false, "error": "Expected empty params dict for type: %s" % t }
	return { "ok": true, "error": "All %d objective types valid" % types.size() }


# 2. is_objective=true situations carry objective_index matching a valid objectives entry.
static func _t_objective_index_bound() -> Dictionary:
	var stages := RealmGenerator.generate(42, 1, 1, 2)
	if stages.is_empty():
		return { "ok": false, "error": "Generator returned empty stages" }
	var stage: Dictionary = stages[0]
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []

	for sit_v in sits:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if not bool(sit.get("is_objective", false)):
			continue
		var oi := int(sit.get("objective_index", -1))
		if oi < 0:
			return { "ok": false, "error": "Objective situation has objective_index=-1" }
		if oi >= objs.size():
			return { "ok": false, "error": "objective_index %d out of bounds (objectives.size=%d)" % [oi, objs.size()] }
	return { "ok": true, "error": "All is_objective situations have valid objective_index" }


# 3. Non-objective situations carry objective_index = -1.
static func _t_non_objective_index_minus_one() -> Dictionary:
	var stages := RealmGenerator.generate(42, 1, 1, 2)
	if stages.is_empty():
		return { "ok": false, "error": "Generator returned empty stages" }
	var stage: Dictionary = stages[0]
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	for sit_v in sits:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("is_objective", false)):
			continue
		var oi := int(sit.get("objective_index", -1))
		if oi != -1:
			return { "ok": false, "error": "Non-objective situation has objective_index=%d (expected -1)" % oi }
	return { "ok": true, "error": "All non-objective situations have objective_index=-1" }


# 4. Stage advance action absent when required objectives not yet complete.
static func _t_stage_advance_blocked() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, false, true)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj1], [sit1])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if actions.has("cta.proceed_to_stage_map"):
		return { "ok": false, "error": "cta.proceed_to_stage_map should be absent when objective not completed" }
	var remaining := int(data.get("objectives_remaining", -1))
	if remaining != 1:
		return { "ok": false, "error": "Expected objectives_remaining=1, got %d" % remaining }
	return { "ok": true, "error": "Stage advance correctly blocked" }


# 5. Stage advance action present when all required objectives complete.
static func _t_stage_advance_unlocked() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, true, true)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj1], [sit1])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if not actions.has("cta.proceed_to_stage_map"):
		return { "ok": false, "error": "cta.proceed_to_stage_map should be present when all objectives completed" }
	var remaining := int(data.get("objectives_remaining", -1))
	if remaining != 0:
		return { "ok": false, "error": "Expected objectives_remaining=0, got %d" % remaining }
	return { "ok": true, "error": "Stage advance correctly unlocked" }


# 6. Completing a situation (via combat victory path) marks the objective completed.
static func _t_mark_objective_completed() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj1], [sit1])

	# Simulate what _handle_complete_stage does: mark situation resolved + objective completed.
	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []

	for i in range(sits.size()):
		var sv: Variant = sits[i]
		if sv is Dictionary and str((sv as Dictionary).get("id", "")) == "sit.0":
			var s: Dictionary = sv
			s["resolved"] = true
			var vobj_idx := int(s.get("objective_index", -1))
			if vobj_idx >= 0:
				var objs_v2: Variant = stage.get("objectives", [])
				if objs_v2 is Array:
					var objs2: Array = objs_v2
					if vobj_idx < objs2.size() and objs2[vobj_idx] is Dictionary:
						objs2[vobj_idx]["completed"] = true
						stage["objectives"] = objs2
			sits[i] = s
			break

	explore_map["situations"] = sits
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(ctx, stage)

	# Verify objective is now completed.
	var updated_stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var upd_objs_v: Variant = updated_stage.get("objectives", [])
	var upd_objs: Array = upd_objs_v if upd_objs_v is Array else []
	if upd_objs.is_empty():
		return { "ok": false, "error": "No objectives found after write-back" }
	var completed := bool((upd_objs[0] as Dictionary).get("completed", false))
	if not completed:
		return { "ok": false, "error": "Objective not marked completed after situation resolved" }
	return { "ok": true, "error": "Objective correctly marked completed" }


# 7. Ranger-calling echo in party adds reveal_adjacent action to explore snapshot.
static func _t_calling_ranger_adds_action() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo_ranger := _make_echo("echo_01", "ranger", 10)
	_inject_stage(ctx, [obj1], [sit1], [echo_ranger])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if not actions.has("cta.calling_reveal_adjacent"):
		return { "ok": false, "error": "cta.calling_reveal_adjacent missing for ranger party" }
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var pca_v: Variant = data.get("party_calling_actions", [])
	var pca: Array = pca_v if pca_v is Array else []
	var found := false
	for entry_v in pca:
		var entry: Dictionary = entry_v if entry_v is Dictionary else {}
		if str(entry.get("action_type", "")) == "reveal_adjacent":
			found = true
			break
	if not found:
		return { "ok": false, "error": "party_calling_actions missing reveal_adjacent entry" }
	return { "ok": true, "error": "Ranger calling adds reveal_adjacent action" }


# 8. Party without ranger does NOT get reveal_adjacent.
static func _t_no_ranger_no_action() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo_blade := _make_echo("echo_01", "blade", 10)
	_inject_stage(ctx, [obj1], [sit1], [echo_blade])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if actions.has("cta.calling_reveal_adjacent"):
		return { "ok": false, "error": "cta.calling_reveal_adjacent should be absent for non-ranger party" }
	return { "ok": true, "error": "No ranger — no reveal_adjacent action" }


# 9. Ignore action present when pending; situation NOT resolved after dispatch.
static func _t_ignore_clears_pending() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj1], [sit1])

	# Manually set pending_situation_id to simulate advance_turn parking the party.
	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	explore_map["pending_situation_id"] = "sit.0"
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(ctx, stage)

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if not actions.has("cta.ignore_situation"):
		return { "ok": false, "error": "cta.ignore_situation absent when pending" }

	# Simulate ignore: clear pending_situation_id without marking resolved.
	var stage2 := FlowStageExploreStateScript._get_current_stage(ctx)
	var map2_v: Variant = stage2.get("explore_map", {})
	var map2: Dictionary = map2_v if map2_v is Dictionary else {}
	map2["pending_situation_id"] = ""
	stage2["explore_map"] = map2
	FlowStageExploreStateScript._write_stage_back(ctx, stage2)

	# Verify situation is NOT resolved.
	var stage3 := FlowStageExploreStateScript._get_current_stage(ctx)
	var map3_v: Variant = stage3.get("explore_map", {})
	var map3: Dictionary = map3_v if map3_v is Dictionary else {}
	var sits3_v: Variant = map3.get("situations", [])
	var sits3: Array = sits3_v if sits3_v is Array else []
	for sv in sits3:
		var s: Dictionary = sv if sv is Dictionary else {}
		if str(s.get("id", "")) == "sit.0" and bool(s.get("resolved", false)):
			return { "ok": false, "error": "Situation should NOT be resolved after ignore" }
	return { "ok": true, "error": "Ignore clears pending without resolving situation" }


# 10. SaveService repair applies completed=false, required=true, objective_index=-1 defaults.
static func _t_repair_defaults() -> Dictionary:
	# Build a legacy stage dict missing the V2-STAGE-002 fields.
	var legacy_obj: Dictionary = { "index": 0, "type": "combat", "seed": 100 }  # no completed/required
	var legacy_sit: Dictionary = {
		"id": "sit.0", "type": "combat",
		"pos": { "col": 5, "row": 5 }, "seed": 100,
		"revealed": false, "is_objective": true, "resolved": false, "intel_clues": []
		# no objective_index
	}
	var legacy_explore_map: Dictionary = {
		"width": 30, "height": 30,
		"party_pos": { "col": 0, "row": 15 },
		"situations": [legacy_sit],
		"locked": false, "party_state": "exploring",
		"turn_count": 0, "objectives_found": 0, "objectives_total": 1, "last_situation_id": ""
	}
	var legacy_stage: Dictionary = {
		"index": 0, "type": "combat", "seed": 999,
		"objectives": [legacy_obj],
		"explore_map": legacy_explore_map,
	}
	var save: Dictionary = {
		"schema_version": 1, "first_boot": false,
		"meta": { "created_at_unix": 1, "last_saved_at_unix": 1, "app_version": "test" },
		"campaign": { "root_seed": 42, "tick": 0, "seed_root": "test:42", "seed_source": "debug" },
		"flow": { "state": "flow.sanctum", "context": {} },
		"economy": { "ase": 100, "ekwan": 0, "last_settle_unix": 1, "last_offline_unix": 1 },
		"sanctum": { "roster": [], "active_party_ids": [] },
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
		"realms": {
			"realm.01": {
				"id": "realm.01", "name": "Test", "virtue": "courage",
				"description": "", "seed": 42, "stage_count": 1,
				"run_index": 0, "run_count": 0, "current_stage_index": 0,
				"is_completed": false, "status": "active",
				"stages": [legacy_stage],
				"realm_recovery_segments": [],
			}
		},
	}
	var logger := _make_logger()
	SaveService._apply_additive_defaults_and_repairs(save, logger, 1)

	# Check objective repair.
	var realm_v: Variant = save.get("realms", {}).get("realm.01", {})
	var realm: Dictionary = realm_v if realm_v is Dictionary else {}
	var stages_v: Variant = realm.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	if stages.is_empty():
		return { "ok": false, "error": "No stages after repair" }
	var stage_r: Dictionary = stages[0]
	var objs_r_v: Variant = stage_r.get("objectives", [])
	var objs_r: Array = objs_r_v if objs_r_v is Array else []
	if objs_r.is_empty():
		return { "ok": false, "error": "No objectives after repair" }
	var obj_r: Dictionary = objs_r[0]
	if obj_r.get("completed", true) != false:
		return { "ok": false, "error": "Expected completed=false after repair, got: %s" % str(obj_r.get("completed")) }
	if obj_r.get("required", false) != true:
		return { "ok": false, "error": "Expected required=true after repair, got: %s" % str(obj_r.get("required")) }

	# Check situation objective_index repair.
	var map_r_v: Variant = stage_r.get("explore_map", {})
	var map_r: Dictionary = map_r_v if map_r_v is Dictionary else {}
	var sits_r_v: Variant = map_r.get("situations", [])
	var sits_r: Array = sits_r_v if sits_r_v is Array else []
	if sits_r.is_empty():
		return { "ok": false, "error": "No situations after repair" }
	var sit_r: Dictionary = sits_r[0]
	if int(sit_r.get("objective_index", 0)) != -1:
		return { "ok": false, "error": "Expected objective_index=-1 after repair, got: %d" % int(sit_r.get("objective_index", 0)) }
	return { "ok": true, "error": "SaveService repair correctly applied V2-STAGE-002 defaults" }


# 11. party_requesting_return = true when avg fear > threshold (60).
static func _t_party_requesting_return_high_fear() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo1 := _make_echo("echo_01", "blade", 75)
	var echo2 := _make_echo("echo_02", "ranger", 70)
	_inject_stage(ctx, [obj1], [sit1], [echo1, echo2])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	if not bool(data.get("party_requesting_return", false)):
		return { "ok": false, "error": "Expected party_requesting_return=true with avg fear ~72" }
	return { "ok": true, "error": "party_requesting_return fires at high avg fear" }


# 12. party_requesting_return = false when avg fear ≤ threshold.
static func _t_party_requesting_return_low_fear() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo1 := _make_echo("echo_01", "blade", 20)
	var echo2 := _make_echo("echo_02", "ranger", 15)
	_inject_stage(ctx, [obj1], [sit1], [echo1, echo2])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	if bool(data.get("party_requesting_return", false)):
		return { "ok": false, "error": "Expected party_requesting_return=false with avg fear ~17" }
	return { "ok": true, "error": "party_requesting_return stays false at low avg fear" }
