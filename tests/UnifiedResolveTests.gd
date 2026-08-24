# res://tests/UnifiedResolveTests.gd
# V2-STAGE-004 Phase 1 close — Unified Resolve snapshot regression tests.
#
# Tests verify that engaging in-explore situations (loot / money / omen / ritual /
# obstacle / structure) routes through FlowRuntime and produces the correct
# flow.resolve snapshot shape.
#
# Tests:
#   1. unified_resolve/loot_yields_resolve_snapshot         — type=="flow.resolve", run_type=="situation_result", surface=="loot"
#   2. unified_resolve/loot_summary_line_non_empty          — data.summary_line is a non-empty String
#   3. unified_resolve/loot_emotion_summary_shape           — Array with pre/post/direction keys
#   4. unified_resolve/loot_effects_is_array                — data.effects is Array
#   5. unified_resolve/loot_continue_action_targets_explore — cta.continue.to == "flow.stage_explore"
#   6. unified_resolve/money_ase_awarded_positive           — data.ase_awarded > 0
#   7. unified_resolve/money_reward_breakdown_entry_exists  — data.reward_breakdown has ≥1 entry
#   8. unified_resolve/obstacle_choice_stays_stage_explore  — obstacle engage keeps type==stage_explore
#   9. unified_resolve/obstacle_choice_overlay_present      — situation_overlay with panel_kind=="choice"
#   10. unified_resolve/obstacle_choice_resolve_yields_resolve — dispatch resolve_situation_choice → flow.resolve
#   11. unified_resolve/emotion_summary_entry_shape         — all entries have pre/post/direction/tag keys
#   12. unified_resolve/omen_surface_key                    — surface=="omen", verdict=="passed"
#   13. unified_resolve/ritual_surface_key                  — surface=="ritual", verdict=="passed"

extends RefCounted
class_name UnifiedResolveTests

static var TEST_SAVE_PATH := TestSaveHarness.dir() + "unified_resolve_slot.json"


# ─── Preloads ────────────────────────────────────────────────────────────────

const SituationModelScript     := preload("res://core/realms/SituationModel.gd")
const StageExploreModelScript  := preload("res://core/realms/StageExploreModel.gd")
const FlowStateIds_            := preload("res://core/state/flow/FlowStateIds.gd")


# ─── Helpers ─────────────────────────────────────────────────────────────────

# Save-file isolation helpers — capture before each test, restore after.
# This ensures tests that boot a real FlowRuntime (which flushes to disk) do
# not corrupt whatever save file exists on the developer's machine.

static func _capture_save() -> Dictionary:
	var path: String = TEST_SAVE_PATH
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		return { "existed": true, "bytes": bytes }
	return { "existed": false, "bytes": PackedByteArray() }


static func _restore_save(snapshot: Dictionary) -> void:
	var path: String = TEST_SAVE_PATH
	if snapshot.get("existed", false):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_buffer(snapshot["bytes"])
			f.close()
	else:
		# File should not exist — remove it if the test created one.
		if FileAccess.file_exists(path):
			var global_path := ProjectSettings.globalize_path(path)
			var dir := DirAccess.open(global_path.get_base_dir())
			if dir:
				dir.remove(global_path.get_file())


static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


# Build a minimal echo dict with emotion fields (avoids EmotionService dependency
# for tests that only need the emotion block, not full roster logic).
static func _make_echo(id: String) -> Dictionary:
	return {
		"id":              id,
		"name":            "Echo %s" % id,
		"standing":        1,
		"rank":            1,
		"calling":         "",
		"calling_origin":  "vanguard",
		"dominant_vector": "vanguard",
		"archetype_birth": "guardian",
		"rarity":          "common",
		"traits":          { "strength": 50 },
		"stats":           { "max_hp": 100 },
		"vector_scores":   { "vanguard": 100 },
		"generation_context": {},
		"emotion": {
			"faith":          50,
			"morale_base":    50,
			"morale_current": 60,
			"fear_current":   5,
		},
		"unlocked_skills":  [],
		"skill_slots":      [],
		"woven_threads":    [],
		"weave_memory_marks": [],
		"guard_state":     false,
	}


# Build a SituationModel dict for a given type (not using SituationModelScript.make
# to avoid relying on its VALID_TYPES guard for exotic types in these routing tests).
static func _make_sit(sit_id: String, sit_type: String, is_objective: bool = false) -> Dictionary:
	return {
		"id":              sit_id,
		"type":            sit_type,
		"pos":             { "col": 5, "row": 5 },
		"seed":            999,
		"revealed":        false,
		"is_objective":    is_objective,
		"resolved":        false,
		"intel_clues":     [],
		"objective_index": -1,
		"role":            "",
	}


# Build a minimal save_data dict with a realm containing one stage and the
# given situation at col=5,row=5.  Party is anchored nearby at party_pos col=4,row=5.
static func _make_save_with_sit(sit_type: String, sit_id: String = "sit.t1") -> Dictionary:
	var sit := _make_sit(sit_id, sit_type, false)
	var situations: Array = [sit]

	var explore_map: Dictionary = {
		"locked":           true,
		"party_pos":        { "col": 5, "row": 5 },  # on top of situation so engage is valid
		"party_state":      "exploring",
		"turn_count":       0,
		"objectives_total": 0,
		"objectives_found": 0,
		"width":            30,
		"height":           30,
		"situations":       situations,
		"pending_situation_id": sit_id,  # already adjacent — engage immediately
		"loot_results":     [],
		"pending_contact":  {},
		"contact_responses": [],
		"contact_fail_count": 0,
	}

	var stage: Dictionary = StageModel.make(0, StageModel.TYPE_COMBAT, 1234, [], explore_map)

	var realm: Dictionary = RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", 42, 1, 0, 0)
	realm["stages"]       = [stage]
	realm["status"]       = "active"
	realm["current_stage_index"] = 0

	return {
		"schema_version": 1,
		"first_boot":     false,
		"meta":           { "sanctum_name": "Test Sanctum", "keeper_name": "Keeper" },
		"campaign":       { "root_seed": 42 },
		"flow":           {
			"state":            FlowStateIds_.STAGE_EXPLORE,
			"context":          {},
			"active_directive": "directive.scout_carefully",
		},
		"economy":        { "ase": 100, "last_settled_unix": 0 },
		"sanctum": {
			"roster":           [ _make_echo("echo.a1") ],
			"active_party_ids": [ "echo.a1" ],
			"bonds":            [],
			"continuity":       0,
			"rejection_counts": {},
		},
		"realms":         { "realm.01": realm },
		"stage_context":  { "active_directive_id": "directive.scout_carefully" },
	}


# Wire up a FlowRuntime with the given save_data and set realm/stage context.
# Returns { "ok": true, "runtime": FlowRuntime } or { "ok": false, "error": ... }.
static func _make_runtime(save_data: Dictionary) -> Dictionary:
	var runtime := FlowRuntime.new(_make_logger(), ConfigService.new(), TEST_SAVE_PATH)

	# Replace save_data before boot so configs are loaded but save is overridden.
	# We call boot() first to get configs and state machine wired, then swap save.
	runtime.boot()

	# Swap in our controlled save data.
	runtime.flow_ctx.save_data = save_data

	# Point flow context at our realm/stage.
	runtime.flow_ctx.realm_id = "realm.01"
	runtime.flow_ctx.stage_id = "stage.0"

	# Set initial snapshot to stage_explore so dispatch routes correctly.
	runtime.flow_ctx.last_snapshot = {
		"type":    FlowStateIds.STAGE_EXPLORE,
		"meta":    { "t": 0 },
		"data":    {},
		"actions": {},
	}

	return { "ok": true, "runtime": runtime }


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("unified_resolve/loot_yields_resolve_snapshot",        Callable(UnifiedResolveTests, "_t_loot_yields_resolve_snapshot"))
	runner.register_test("unified_resolve/loot_summary_line_non_empty",         Callable(UnifiedResolveTests, "_t_loot_summary_line_non_empty"))
	runner.register_test("unified_resolve/loot_emotion_summary_shape",          Callable(UnifiedResolveTests, "_t_loot_emotion_summary_shape"))
	runner.register_test("unified_resolve/loot_effects_is_array",               Callable(UnifiedResolveTests, "_t_loot_effects_is_array"))
	runner.register_test("unified_resolve/loot_continue_action_targets_explore",Callable(UnifiedResolveTests, "_t_loot_continue_action_targets_explore"))
	runner.register_test("unified_resolve/money_ase_awarded_positive",          Callable(UnifiedResolveTests, "_t_money_ase_awarded_positive"))
	runner.register_test("unified_resolve/money_reward_breakdown_entry_exists", Callable(UnifiedResolveTests, "_t_money_reward_breakdown_entry_exists"))
	runner.register_test("unified_resolve/obstacle_choice_stays_stage_explore", Callable(UnifiedResolveTests, "_t_obstacle_choice_stays_stage_explore"))
	runner.register_test("unified_resolve/obstacle_choice_overlay_present",     Callable(UnifiedResolveTests, "_t_obstacle_choice_overlay_present"))
	runner.register_test("unified_resolve/obstacle_choice_resolve_yields_resolve", Callable(UnifiedResolveTests, "_t_obstacle_choice_resolve_yields_resolve"))
	runner.register_test("unified_resolve/emotion_summary_entry_shape",         Callable(UnifiedResolveTests, "_t_emotion_summary_entry_shape"))
	runner.register_test("unified_resolve/omen_surface_key",                    Callable(UnifiedResolveTests, "_t_omen_surface_key"))
	runner.register_test("unified_resolve/ritual_surface_key",                  Callable(UnifiedResolveTests, "_t_ritual_surface_key"))


# ─── Shared engage helper ─────────────────────────────────────────────────────

# Engages the situation with id sit_id on the runtime and returns the resulting snapshot.
static func _engage(runtime: FlowRuntime, sit_id: String) -> Dictionary:
	return runtime.dispatch({
		"type":         "stage.engage_situation",
		"situation_id": sit_id,
	})


# ─── Test 1 — loot → type=="flow.resolve", run_type=="situation_result", surface=="loot" ──
static func _t_loot_yields_resolve_snapshot() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("loot")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")

	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected type '%s', got '%s'" % [FlowStateIds.RESOLVE, snap.get("type", "")] }

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if str(data.get("run_type", "")) != "situation_result":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected run_type 'situation_result', got '%s'" % data.get("run_type", "") }

	if str(data.get("surface", "")) != "loot":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected surface 'loot', got '%s'" % data.get("surface", "") }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 2 — loot summary_line is a non-empty String ──────────────────────────
static func _t_loot_summary_line_non_empty() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("loot")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var line := str(data.get("summary_line", ""))
	if line.is_empty():
		_restore_save(_save_bak)
		return { "ok": false, "error": "data.summary_line should be non-empty for loot" }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 3 — loot emotion_summary is Array with pre/post/direction ─────────
# NOTE: If the party has no emotion deltas (fear_delta==0, morale_delta==0 for loot),
# the runtime only adds entries for echoes whose pre-status was captured (i.e. those
# with non-zero deltas). Loot has fear_delta=-5, so entries are expected when a party
# echo is present.  We assert the array shape, not a specific length.
static func _t_loot_emotion_summary_shape() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("loot")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if not data.has("emotion_summary"):
		_restore_save(_save_bak)
		return { "ok": false, "error": "data missing 'emotion_summary' key" }
	var es_v: Variant = data.get("emotion_summary")
	if not (es_v is Array):
		_restore_save(_save_bak)
		return { "ok": false, "error": "emotion_summary should be Array, got %s" % typeof(es_v) }

	var es: Array = es_v
	# If there are entries, validate their shape.
	for entry_v in es:
		if not (entry_v is Dictionary):
			_restore_save(_save_bak)
			return { "ok": false, "error": "emotion_summary entry is not a Dictionary" }
		var entry: Dictionary = entry_v
		for key in ["pre_emotional_status", "post_emotional_status", "direction"]:
			if not entry.has(key):
				_restore_save(_save_bak)
				return { "ok": false, "error": "emotion_summary entry missing key '%s'" % key }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 4 — loot effects is an Array ────────────────────────────────────────
static func _t_loot_effects_is_array() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("loot")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if not data.has("effects"):
		_restore_save(_save_bak)
		return { "ok": false, "error": "data missing 'effects' key" }
	var eff_v: Variant = data.get("effects")
	if not (eff_v is Array):
		_restore_save(_save_bak)
		return { "ok": false, "error": "effects should be Array, got %s" % typeof(eff_v) }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 5 — loot cta.continue targets flow.stage_explore ────────────────────
static func _t_loot_continue_action_targets_explore() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("loot")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	if not actions.has("cta.continue"):
		_restore_save(_save_bak)
		return { "ok": false, "error": "actions missing 'cta.continue'" }
	var cta_v: Variant = actions["cta.continue"]
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}

	var to_state := str(cta.get("to", ""))
	if to_state != FlowStateIds.STAGE_EXPLORE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "cta.continue.to expected '%s', got '%s'" % [FlowStateIds.STAGE_EXPLORE, to_state] }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 6 — money data.ase_awarded > 0 ─────────────────────────────────────
static func _t_money_ase_awarded_positive() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("money")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected flow.resolve for money, got '%s'" % snap.get("type", "") }

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var ase := int(data.get("ase_awarded", 0))
	if ase <= 0:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected ase_awarded > 0 for money, got %d" % ase }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 7 — money data.reward_breakdown has ≥1 entry ────────────────────────
static func _t_money_reward_breakdown_entry_exists() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("money")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var rb_v: Variant = data.get("reward_breakdown", [])
	var rb: Array = rb_v if rb_v is Array else []
	if rb.size() < 1:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected reward_breakdown to have ≥1 entry for money, got %d" % rb.size() }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 8 — obstacle engage keeps snapshot type==flow.stage_explore ─────────
static func _t_obstacle_choice_stays_stage_explore() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("obstacle")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")

	if str(snap.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Obstacle should keep type '%s', got '%s'" % [FlowStateIds.STAGE_EXPLORE, snap.get("type", "")] }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 9 — obstacle overlay has panel_kind=="choice" ────────────────────────
static func _t_obstacle_choice_overlay_present() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("obstacle")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if not data.has("situation_overlay"):
		_restore_save(_save_bak)
		return { "ok": false, "error": "data missing 'situation_overlay' for obstacle" }
	var ov_v: Variant = data.get("situation_overlay", {})
	var ov: Dictionary = ov_v if ov_v is Dictionary else {}

	if str(ov.get("panel_kind", "")) != "choice":
		_restore_save(_save_bak)
		return { "ok": false, "error": "situation_overlay.panel_kind expected 'choice', got '%s'" % ov.get("panel_kind", "") }

	var choices_v: Variant = ov.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	if choices.size() < 2:
		_restore_save(_save_bak)
		return { "ok": false, "error": "situation_overlay.choices should have ≥2 entries, got %d" % choices.size() }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 10 — obstacle resolve_situation_choice yields flow.resolve ──────────
static func _t_obstacle_choice_resolve_yields_resolve() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("obstacle")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	# Step 1: engage → choice overlay, stays in stage_explore.
	var snap1 := _engage(runtime, "sit.t1")
	if str(snap1.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Pre-condition: obstacle engage expected stage_explore, got '%s'" % snap1.get("type", "") }

	# Step 2: resolve the choice.
	var snap2 := runtime.dispatch({
		"type":         "stage.resolve_situation_choice",
		"situation_id": "sit.t1",
		"choice_id":    "push_through",
	})

	if str(snap2.get("type", "")) != FlowStateIds.RESOLVE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "resolve_situation_choice expected flow.resolve, got '%s'" % snap2.get("type", "") }

	var data_v: Variant = snap2.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if str(data.get("run_type", "")) != "situation_result":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected run_type 'situation_result', got '%s'" % data.get("run_type", "") }

	if str(data.get("surface", "")) != "obstacle":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected surface 'obstacle', got '%s'" % data.get("surface", "") }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 11 — emotion_summary entry shape has pre/post/direction/tag ──────────
# Uses omen (fear_delta=2, morale_delta=-3) so entries are guaranteed.
static func _t_emotion_summary_entry_shape() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("omen")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var es_v: Variant = data.get("emotion_summary", [])
	var es: Array = es_v if es_v is Array else []

	# Omen has non-zero deltas, so at least one echo in party should appear.
	if es.is_empty():
		# Accept: if party is empty it's an empty array — not a bug.
		# But if a party echo exists, expect an entry.
		var sanctum_v: Variant = save.get("sanctum", {})
		var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
		var party_ids_v: Variant = sanctum.get("active_party_ids", [])
		var party_ids: Array = party_ids_v if party_ids_v is Array else []
		if not party_ids.is_empty():
			_restore_save(_save_bak)
			return { "ok": false, "error": "emotion_summary is empty but party has members — expected entries for omen" }
		_restore_save(_save_bak)
		return { "ok": true }

	for entry_v in es:
		if not (entry_v is Dictionary):
			_restore_save(_save_bak)
			return { "ok": false, "error": "emotion_summary entry is not a Dictionary" }
		var entry: Dictionary = entry_v
		for key in ["pre_emotional_status", "post_emotional_status", "direction", "tag"]:
			if not entry.has(key):
				_restore_save(_save_bak)
				return { "ok": false, "error": "emotion_summary entry missing key '%s'" % key }
		# direction must be one of: lift / ease / fall / steady
		var dir := str(entry.get("direction", ""))
		if dir not in ["lift", "ease", "fall", "steady"]:
			_restore_save(_save_bak)
			return { "ok": false, "error": "emotion_summary direction must be lift/ease/fall/steady, got '%s'" % dir }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 12 — omen surface=="omen", verdict=="passed" ────────────────────────
static func _t_omen_surface_key() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("omen")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected flow.resolve for omen, got '%s'" % snap.get("type", "") }

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if str(data.get("surface", "")) != "omen":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected surface 'omen', got '%s'" % data.get("surface", "") }
	if str(data.get("verdict", "")) != "passed":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected verdict 'passed' for omen, got '%s'" % data.get("verdict", "") }

	_restore_save(_save_bak)
	return { "ok": true }


# ─── Test 13 — ritual surface=="ritual", verdict=="passed" ────────────────────
static func _t_ritual_surface_key() -> Dictionary:
	var _save_bak := _capture_save()
	var save   := _make_save_with_sit("ritual")
	var env    := _make_runtime(save)
	if not bool(env.get("ok", false)):
		_restore_save(_save_bak)
		return { "ok": false, "error": env.get("error", "runtime init failed") }
	var runtime: FlowRuntime = env["runtime"]

	var snap := _engage(runtime, "sit.t1")
	if str(snap.get("type", "")) != FlowStateIds.RESOLVE:
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected flow.resolve for ritual, got '%s'" % snap.get("type", "") }

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if str(data.get("surface", "")) != "ritual":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected surface 'ritual', got '%s'" % data.get("surface", "") }
	if str(data.get("verdict", "")) != "passed":
		_restore_save(_save_bak)
		return { "ok": false, "error": "Expected verdict 'passed' for ritual, got '%s'" % data.get("verdict", "") }

	_restore_save(_save_bak)
	return { "ok": true }
