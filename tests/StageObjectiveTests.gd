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
#  7. objective/calling_kra_soro_adds_action — kra_soro calling → cta.calling_reveal_adjacent in actions
#  8. objective/no_kra_soro_no_action        — party without kra_soro → cta.calling_reveal_adjacent absent
#  9. objective/ignore_sits_clears_pending   — cta.ignore_situation present when pending; situation NOT resolved after
# 10. objective/repair_defaults              — SaveService repair applies completed/required/objective_index defaults
# 11. objective/party_requesting_return_high_fear  — party_requesting_return true when avg fear > threshold
# 12. objective/party_requesting_return_low_fear   — party_requesting_return false when avg fear ≤ threshold
# 13. objective/zero_required_blocked_until_reached — D94: a stage with no REQUIRED objective is
#     not completable until a non-boss objective is overcome, then it is
# 14. objective/required_stage_gate_unchanged       — D94 regression guard: a normal stage with a
#     required objective gates exactly as before
# 16-22. D-82/D-83: optional objectives are skippable; guide_spirit is required in config.
# 15. objective/calling_action_bonuses_v2_only — guard: calling_action_bonuses config carries no V1 calling id

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


class MockStageConfig extends ConfigService:
	func get_balance() -> Dictionary:
		return {
			"data": {
				"stages": {
					"calling_action_bonuses": {
						"kra_soro": ["reveal_adjacent"],
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


# Set explore_map.objectives_found on the injected stage.
#
# Production NEVER marks an objective `completed` without also bumping `objectives_found` —
# the two move together at every site (VentureController.gd:597+605,
# ActiveStageService.gd:586+594, ContactController.gd:587+714). A fixture that completes an
# objective must therefore bump this too, or it describes a state the game cannot reach.
static func _set_objectives_found(ctx: FlowContext, found: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	explore_map["objectives_found"] = found
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(ctx, stage)


# Mark objective `idx` completed on the injected stage. Production also bumps objectives_found
# in the same write; the gate no longer reads it, so the helper does not.
static func _complete_objective(ctx: FlowContext, idx: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(ctx)
	var objs: Array = stage.get("objectives", [])
	(objs[idx] as Dictionary)["completed"] = true
	stage["objectives"] = objs
	FlowStageExploreStateScript._write_stage_back(ctx, stage)


static func _gate_open(ctx: FlowContext) -> bool:
	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	return actions.has("cta.proceed_to_stage_map")


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
	runner.register_test("objective/calling_kra_soro_adds_action",       Callable(StageObjectiveTests, "_t_calling_kra_soro_adds_action"))
	runner.register_test("objective/no_kra_soro_no_action",              Callable(StageObjectiveTests, "_t_no_kra_soro_no_action"))
	runner.register_test("objective/ignore_sits_clears_pending",         Callable(StageObjectiveTests, "_t_ignore_clears_pending"))
	runner.register_test("objective/repair_defaults",                    Callable(StageObjectiveTests, "_t_repair_defaults"))
	runner.register_test("objective/party_requesting_return_high_fear",  Callable(StageObjectiveTests, "_t_party_requesting_return_high_fear"))
	runner.register_test("objective/party_requesting_return_low_fear",   Callable(StageObjectiveTests, "_t_party_requesting_return_low_fear"))
	runner.register_test("objective/zero_required_blocked_until_reached", Callable(StageObjectiveTests, "_t_zero_required_blocked_until_reached"))
	runner.register_test("objective/required_stage_gate_unchanged",       Callable(StageObjectiveTests, "_t_required_stage_gate_unchanged"))
	runner.register_test("objective/optional_skipped_completable",        Callable(StageObjectiveTests, "_t_optional_skipped_completable"))
	runner.register_test("objective/required_open_blocks_despite_optional_done", Callable(StageObjectiveTests, "_t_required_open_blocks"))
	runner.register_test("objective/zero_required_optional_overcome_completable", Callable(StageObjectiveTests, "_t_zero_required_overcome"))
	runner.register_test("objective/boss_never_counts",                   Callable(StageObjectiveTests, "_t_boss_never_counts"))
	runner.register_test("objective/skipped_pays_completed_only_once",    Callable(StageObjectiveTests, "_t_skipped_pays_completed_only"))
	runner.register_test("objective/resolve_gate_agrees",                 Callable(StageObjectiveTests, "_t_resolve_gate_agrees"))
	runner.register_test("objective/guide_spirit_required_in_config",     Callable(StageObjectiveTests, "_t_guide_spirit_required_config"))
	runner.register_test("objective/generated_required_flags_unchanged",  Callable(StageObjectiveTests, "_t_generated_flags_match_config"))
	runner.register_test("objective/calling_action_bonuses_v2_only",      Callable(StageObjectiveTests, "_t_calling_action_bonuses_v2_only"))


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
	# D94: the objective is completed, so production has also counted it found. Without this
	# the fixture describes an unreachable state and the gate's reached-term rejects it.
	_set_objectives_found(ctx, 1)

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


# 7. Kra-Soro-calling echo in party adds reveal_adjacent action to explore snapshot.
static func _t_calling_kra_soro_adds_action() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo_kra_soro := _make_echo("echo_01", "kra_soro", 10)
	_inject_stage(ctx, [obj1], [sit1], [echo_kra_soro])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if not actions.has("cta.calling_reveal_adjacent"):
		return { "ok": false, "error": "cta.calling_reveal_adjacent missing for kra_soro party" }
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
	return { "ok": true, "error": "Kra-Soro calling adds reveal_adjacent action" }


# 8. Party without kra_soro does NOT get reveal_adjacent.
static func _t_no_kra_soro_no_action() -> Dictionary:
	var ctx := _make_ctx()
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo_aduro := _make_echo("echo_01", "aduro", 10)
	_inject_stage(ctx, [obj1], [sit1], [echo_aduro])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if actions.has("cta.calling_reveal_adjacent"):
		return { "ok": false, "error": "cta.calling_reveal_adjacent should be absent for non-kra_soro party" }
	return { "ok": true, "error": "No kra_soro — no reveal_adjacent action" }


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
	var echo2 := _make_echo("echo_02", "kra_soro", 70)
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
	var echo2 := _make_echo("echo_02", "kra_soro", 15)
	_inject_stage(ctx, [obj1], [sit1], [echo1, echo2])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	if bool(data.get("party_requesting_return", false)):
		return { "ok": false, "error": "Expected party_requesting_return=false with avg fear ~17" }
	return { "ok": true, "error": "party_requesting_return stays false at low avg fear" }


# 13. D94 — a stage with NO required objective is not completable until its objective
#     situations are actually reached.
#
# RealmGenerator writes the boss objective `required = false` unconditionally
# (RealmGenerator.gd:152) and a `pursue` pre-boss is optional too (:146). realm.01 generates
# exactly two objectives, so ~14% of its stages (measured: 115 of 800 generated stages) carry
# no required objective at all. `objectives_remaining` was therefore 0 from stage entry, and
# the completion gate offered `flow.complete_stage` as soon as nothing was pending — which is
# what an "Ignore" on the first engagement popup produces. Since Phase 8A (091bcfd) moved the
# stage settlement onto that action, this paid a full stage reward for one step.
#
# Both halves are pinned here: blocked while unreached, offered once reached.
static func _t_zero_required_blocked_until_reached() -> Dictionary:
	var ctx := _make_ctx()
	# The exact shipped shape: optional pursue pre-boss + always-optional boss.
	var obj_pursue := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_PURSUE, 100, {}, false, false)
	var obj_boss   := ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_BOSS,   101, {}, false, false)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj_pursue, obj_boss], [sit1])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	# The pre-fix gate's every term is satisfied — this is what made the defect reachable.
	if int(data.get("objectives_remaining", -1)) != 0:
		return { "ok": false, "error": "Fixture wrong: expected objectives_remaining=0, got %d" % int(data.get("objectives_remaining", -1)) }
	if int(data.get("objectives_total", -1)) != 1:
		return { "ok": false, "error": "Fixture wrong: expected objectives_total=1, got %d" % int(data.get("objectives_total", -1)) }
	if int(data.get("objectives_found", -1)) != 0:
		return { "ok": false, "error": "Fixture wrong: expected objectives_found=0, got %d" % int(data.get("objectives_found", -1)) }

	if actions.has("cta.proceed_to_stage_map"):
		return { "ok": false, "error": "D94: stage with no required objective must NOT be completable before its objective is reached" }

	# Reaching the situation alone (objectives_found) is not enough: nothing was overcome.
	_set_objectives_found(ctx, 1)
	if _gate_open(ctx):
		return { "ok": false, "error": "D94: reaching an objective without overcoming it must not open the gate" }

	# Overcoming the pursue objective opens the gate.
	_complete_objective(ctx, 0)
	if not _gate_open(ctx):
		return { "ok": false, "error": "D94: stage must become completable once pursue is overcome" }

	return { "ok": true, "error": "Zero-required stage blocked until pursue is overcome, then completable" }


# 14. D94 regression guard — a NORMAL stage (one required objective) gates exactly as before.
#     Blocked while the objective is incomplete; offered once it is completed and counted.
static func _t_required_stage_gate_unchanged() -> Dictionary:
	var ctx := _make_ctx()
	var obj_open := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, false, true)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [obj_open], [sit1])

	var snap_open := StageExploreSnapshotBuilder.build(ctx, 1)
	var a_open_v: Variant = snap_open.get("actions", {})
	var a_open: Dictionary = a_open_v if a_open_v is Dictionary else {}
	if a_open.has("cta.proceed_to_stage_map"):
		return { "ok": false, "error": "Required objective incomplete — gate must stay closed" }

	# Completed via the combat-victory path: objective completed AND counted found.
	var ctx2 := _make_ctx()
	var obj_done := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, true, true)
	var sit2 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx2, [obj_done], [sit2])
	_set_objectives_found(ctx2, 1)

	var snap_done := StageExploreSnapshotBuilder.build(ctx2, 1)
	var a_done_v: Variant = snap_done.get("actions", {})
	var a_done: Dictionary = a_done_v if a_done_v is Dictionary else {}
	if not a_done.has("cta.proceed_to_stage_map"):
		return { "ok": false, "error": "Required objective completed — gate must open exactly as before" }
	var act_v: Variant = a_done.get("cta.proceed_to_stage_map", {})
	var act: Dictionary = act_v if act_v is Dictionary else {}
	if str(act.get("type", "")) != "flow.complete_stage":
		return { "ok": false, "error": "Completion action type changed: got '%s'" % str(act.get("type", "")) }

	return { "ok": true, "error": "Normal required-objective stage gates unchanged" }


# 16. D-82 — required done, optional pursue skipped: completable.
static func _t_optional_skipped_completable() -> Dictionary:
	var ctx := _make_ctx()
	var combat := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, true, true)
	var pursue := ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_PURSUE, 101, {}, false, false)
	var boss   := ObjectiveModelScript.make(2, ObjectiveModelScript.TYPE_BOSS,   102, {}, false, false)
	var sit0 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var sit1 := SituationModelScript.make("sit.1", SituationModelScript.TYPE_COMBAT, 9, 9, 101, true, 1)
	_inject_stage(ctx, [combat, pursue, boss], [sit0, sit1])
	_set_objectives_found(ctx, 1)
	if not _gate_open(ctx):
		return { "ok": false, "error": "D-82: required done + optional skipped must be completable" }
	return { "ok": true, "error": "Skipped optional objective does not block completion" }


# 17. A required objective still open blocks the gate even when an optional one is done.
static func _t_required_open_blocks() -> Dictionary:
	var ctx := _make_ctx()
	var combat := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100, {}, false, true)
	var pursue := ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_PURSUE, 101, {}, true, false)
	var boss   := ObjectiveModelScript.make(2, ObjectiveModelScript.TYPE_BOSS,   102, {}, false, false)
	var sit0 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [combat, pursue, boss], [sit0])
	_set_objectives_found(ctx, 1)
	if _gate_open(ctx):
		return { "ok": false, "error": "Required objective open: gate must stay closed" }
	return { "ok": true, "error": "Open required objective blocks completion" }


# 18. Zero required objective: blocked while the optional one is undone, open once overcome.
static func _t_zero_required_overcome() -> Dictionary:
	var ctx := _make_ctx()
	var pursue := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_PURSUE, 100, {}, false, false)
	var boss   := ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_BOSS,   101, {}, false, false)
	var sit0 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [pursue, boss], [sit0])
	if _gate_open(ctx):
		return { "ok": false, "error": "Zero required, optional undone: gate must be closed" }
	_complete_objective(ctx, 0)
	if not _gate_open(ctx):
		return { "ok": false, "error": "Zero required, optional overcome: gate must be open" }
	return { "ok": true, "error": "Zero-required stage opens only after the optional is overcome" }


# 19. The boss stub never counts as overcome, even if a fixture marks it completed... it must
# not be the one objective that opens a stage with no other overcome objective.
static func _t_boss_never_counts() -> Dictionary:
	var boss_only := [ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_BOSS, 1, {}, true, false)]
	if ObjectiveModelScript.stage_completable(boss_only):
		return { "ok": false, "error": "A completed boss stub must not satisfy the overcome term" }
	var open_boss := [ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_BOSS, 1, {}, false, false)]
	if ObjectiveModelScript.stage_completable(open_boss):
		return { "ok": false, "error": "A stage of only the boss stub must not be completable" }
	if ObjectiveModelScript.stage_completable([]):
		return { "ok": false, "error": "A stage with no objectives must not be completable" }
	return { "ok": true, "error": "Boss stub never counts" }


# 20. Payout: a skipped optional objective pays nothing (same payout as a stage without it), and
# the settlement stays exactly-once.
static func _t_skipped_pays_completed_only() -> Dictionary:
	var cfg := EconomyCharacterizationTests._config()
	var boss := ObjectiveModelScript.make(2, ObjectiveModelScript.TYPE_BOSS, 2, {}, false, false)
	var with_skip: Array = [
		EconomyCharacterizationTests._req(0, "combat", true),
		ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_PURSUE, 1, {}, false, false), boss]
	var without: Array = [EconomyCharacterizationTests._req(0, "combat", true), boss]
	var ctx_a := EconomyCharacterizationTests._stage_ctx(cfg, with_skip)
	var ctx_b := EconomyCharacterizationTests._stage_ctx(cfg, without)
	var pa := StageSettlementService.new(ctx_a, cfg, null, null).preview()
	var pb := StageSettlementService.new(ctx_b, cfg, null, null).preview()
	if pa.is_empty() or int(pa["ase"]) <= 0:
		return { "ok": false, "error": "Fixture wrong: empty or zero preview %s" % str(pa) }
	# The objectives_overcome row legitimately differs in params.total (1 of 2 vs 1 of 1).
	if int(pa["ase"]) != int(pb["ase"]) or int(pa["ekwan"]) != int(pb["ekwan"]) \
			or int((pa["rows"][0] as Dictionary)["delta"]) != int((pb["rows"][0] as Dictionary)["delta"]):
		return { "ok": false, "error": "Skipped optional changed the payout: %s vs %s" % [str(pa), str(pb)] }
	ctx_a.save_data["economy"] = { "ase": 0, "ekwan": 0 }
	var econ := EconomyService.new(ctx_a.save_data)
	var svc := StageSettlementService.new(ctx_a, cfg, econ, null)
	var first := svc.settle(true, 1)
	var ase_after_first := int(ctx_a.save_data["economy"]["ase"])
	var second := svc.settle(true, 2)
	if first.is_empty() or not second.is_empty():
		return { "ok": false, "error": "settle must pay once: first %s second %s" % [str(first), str(second)] }
	if int(ctx_a.save_data["economy"]["ase"]) != ase_after_first or ase_after_first != int(pa["ase"]):
		return { "ok": false, "error": "Balance %d after first settle, preview said %d" % [ase_after_first, int(pa["ase"])] }
	return { "ok": true, "error": "Skipped optional pays nothing; settlement exactly-once" }


# 21. The resolve card's routing agrees with the explore gate: required done but nothing
# overcome (zero-required stage) is not offered as complete.
static func _t_resolve_gate_agrees() -> Dictionary:
	var ctx := _make_ctx()
	var pursue := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_PURSUE, 100, {}, false, false)
	var boss   := ObjectiveModelScript.make(1, ObjectiveModelScript.TYPE_BOSS,   101, {}, false, false)
	var sit0 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	_inject_stage(ctx, [pursue, boss], [sit0])
	if EncounterSnapshotBuilder._count_remaining_required_objectives(ctx) == 0:
		return { "ok": false, "error": "Resolve gate open on a stage with nothing overcome" }
	_complete_objective(ctx, 0)
	if EncounterSnapshotBuilder._count_remaining_required_objectives(ctx) != 0:
		return { "ok": false, "error": "Resolve gate closed after pursue overcome" }
	return { "ok": true, "error": "Resolve and explore gates agree" }


# Shipped config and generator agree on which types are required (D-83, closes D95).
static func _shipped_required_flags() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var stages_cfg: Dictionary = (cs.get_balance().get("data", {}) as Dictionary).get("stages", {})
	var types_cfg: Dictionary = stages_cfg.get("objective_types", {})
	var out := {}
	for k in types_cfg:
		out[k] = bool((types_cfg[k] as Dictionary).get("required", true))
	return out


# 22.
static func _t_guide_spirit_required_config() -> Dictionary:
	var flags := _shipped_required_flags()
	for t in ["combat", "shrine", "recover", "protect", "endure", "guide_spirit"]:
		if not bool(flags.get(t, false)):
			return { "ok": false, "error": "objective_types.%s.required must be true" % t }
	if bool(flags.get("pursue", true)):
		return { "ok": false, "error": "objective_types.pursue.required must stay false" }
	return { "ok": true, "error": "guide_spirit required; pursue optional" }


# 23. Generated stages keep their flags: every pre-boss objective is required except pursue,
# the boss is not required, and the flags equal the config flags for each type.
static func _t_generated_flags_match_config() -> Dictionary:
	var flags := _shipped_required_flags()
	var explore_cfg := {
		"objective_pool": ["combat", "shrine", "recover", "protect", "endure", "pursue", "guide_spirit"],
		"sit_count_min": 2, "sit_count_max": 2,
		"map_width_min": 30, "map_width_max": 30, "map_height_min": 30, "map_height_max": 30,
	}
	var seen := {}
	for seed in range(1, 41):
		for st_v in RealmGenerator.generate(seed, 6, 2, 4, explore_cfg):
			for o_v in (st_v as Dictionary).get("objectives", []):
				var o: Dictionary = o_v
				var ty := str(o.get("type", ""))
				var want: bool = (ty != "pursue" and ty != "boss")
				if bool(o.get("required", true)) != want:
					return { "ok": false, "error": "seed %d: %s required=%s" % [seed, ty, str(o.get("required"))] }
				if ty != "boss" and bool(flags.get(ty, true)) != want:
					return { "ok": false, "error": "config flag for %s disagrees with generator" % ty }
				seen[ty] = true
	if not seen.has("guide_spirit") and not seen.has("pursue"):
		return { "ok": false, "error": "Fixture saw neither guide_spirit nor pursue: %s" % str(seen.keys()) }
	return { "ok": true, "error": "Generated flags match config (types seen: %s)" % str(seen.keys()) }


# 15. Reads the SHIPPED balance.json (not the MockStageConfig fixture) so a regression of
# calling_action_bonuses back to the V1 "ranger" key fails here, and proves reveal_adjacent
# is reachable end-to-end for a real Kra-Soro echo against the real config.
static func _t_calling_action_bonuses_v2_only() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var stages_cfg: Dictionary = (bal.get("data", {}) as Dictionary).get("stages", {})
	var bonuses: Dictionary = stages_cfg.get("calling_action_bonuses", {})

	if bonuses.has("ranger"):
		return { "ok": false, "error": "data.stages.calling_action_bonuses has regressed to the V1 'ranger' key" }
	if not bonuses.has("kra_soro"):
		return { "ok": false, "error": "data.stages.calling_action_bonuses has no 'kra_soro' key -- table is not on V2 calling ids" }

	var ctx := _make_ctx()
	ctx.config_service = cs
	var obj1 := ObjectiveModelScript.make(0, ObjectiveModelScript.TYPE_COMBAT, 100)
	var sit1 := SituationModelScript.make("sit.0", SituationModelScript.TYPE_COMBAT, 5, 5, 100, true, 0)
	var echo_kra_soro := _make_echo("echo_01", "kra_soro", 10)
	_inject_stage(ctx, [obj1], [sit1], [echo_kra_soro])

	var snap := StageExploreSnapshotBuilder.build(ctx, 1)
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	if not actions.has("cta.calling_reveal_adjacent"):
		return { "ok": false, "error": "Kra-Soro's Scout Ahead did not fire against the real shipped config" }

	return { "ok": true, "error": "calling_action_bonuses is on V2 ids and reveal_adjacent is reachable" }
