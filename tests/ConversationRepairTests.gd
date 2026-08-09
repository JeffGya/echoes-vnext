# res://tests/ConversationRepairTests.gd
# V2-PROG-012 Phase 8 — conversation repair regression tests.
#
# Tests:
#   1. conversation_repair/npc_line_survives_contact_start — a populated npc_line set by
#      RealmGenerator (present on sit.contact before FlowRuntime processes it) is not blanked
#      by the unauthored burden_variants lookup in _start_contact_conversation(). Fails if the
#      unconditional overwrite in FlowRuntime.gd is restored.

extends RefCounted
class_name ConversationRepairTests

const TEST_SAVE_PATH := "/tmp/echoes-vnext-tests/conversation_repair_slot.json"
const ContactModelScript := preload("res://core/realms/ContactModel.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("conversation_repair/npc_line_survives_contact_start", Callable(ConversationRepairTests, "_t_npc_line_survives_contact_start"))


# ─── Save-file isolation (mirrors UnifiedResolveTests.gd) ────────────────────
# Tests boot a real FlowRuntime, which flushes to disk on dispatch. Capture/restore
# whatever exists at TEST_SAVE_PATH so we never corrupt a developer's real save.

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
		if FileAccess.file_exists(path):
			var global_path := ProjectSettings.globalize_path(path)
			var dir := DirAccess.open(global_path.get_base_dir())
			if dir:
				dir.remove(global_path.get_file())


static func _make_logger(level: String = "off") -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level(level)
	return l


static func _make_echo(id: String, storyweight: int = 10, xp_total: int = 40) -> Dictionary:
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
		"storyweight":     storyweight,
		"xp_total":        xp_total,
		"emotion": {
			"faith":          50,
			"morale_base":    50,
			"morale_current": 60,
			"fear_current":   5,
		},
		"unlocked_skills":    [],
		"skill_slots":        [],
		"woven_threads":      [],
		"weave_memory_marks": [],
		"guard_state":        false,
	}


# Build a save_data dict with one stage, one NPC situation carrying a pre-populated
# contact (as RealmGenerator would produce), and one active-party echo.
static func _make_save_with_contact_situation(contact: Dictionary, storyweight: int = 10, xp_total: int = 40) -> Dictionary:
	var sit: Dictionary = {
		"id":              "sit.t1",
		"type":            "npc",
		"pos":             { "col": 5, "row": 5 },
		"seed":            999,
		"revealed":        false,
		"is_objective":    false,
		"resolved":        false,
		"intel_clues":     [],
		"objective_index": -1,
		"role":            str(contact.get("role", "witness")),
		"contact":         contact,
	}
	var explore_map: Dictionary = {
		"locked":               true,
		"party_pos":            { "col": 5, "row": 5 },  # on top of situation so engage is valid
		"party_state":          "exploring",
		"turn_count":           0,
		"objectives_total":     0,
		"objectives_found":     0,
		"width":                30,
		"height":               30,
		"situations":           [sit],
		"pending_situation_id": "sit.t1",
		"loot_results":         [],
		"pending_contact":      {},
		"contact_responses":    [],
		"contact_fail_count":   0,
	}
	var stage: Dictionary = StageModel.make(0, StageModel.TYPE_COMBAT, 1234, [], explore_map)
	var realm: Dictionary = RealmModel.make("realm.01", "Vale of Dust", "courage", "desc", 42, 1, 0, 0)
	realm["stages"] = [stage]
	realm["status"] = "active"
	realm["current_stage_index"] = 0

	return {
		"schema_version": 1,
		"first_boot":     false,
		"meta":           { "sanctum_name": "Test Sanctum", "keeper_name": "Keeper" },
		"campaign":       { "root_seed": 42 },
		"flow": {
			"state":            FlowStateIds.STAGE_EXPLORE,
			"context":          {},
			"active_directive": "directive.scout_carefully",
		},
		"economy": { "ase": 100, "last_settled_unix": 0 },
		"sanctum": {
			"roster":           [ _make_echo("echo.a1", storyweight, xp_total) ],
			"active_party_ids": [ "echo.a1" ],
			"bonds":            [],
			"continuity":       0,
			"rejection_counts": {},
		},
		"realms":        { "realm.01": realm },
		"stage_context": { "active_directive_id": "directive.scout_carefully" },
	}


static func _make_runtime(save_data: Dictionary, logger: StructuredLogger) -> FlowRuntime:
	var runtime := FlowRuntime.new(logger, ConfigService.new(), TEST_SAVE_PATH)
	runtime.boot()
	runtime.flow_ctx.save_data = save_data
	runtime.flow_ctx.realm_id = "realm.01"
	runtime.flow_ctx.stage_id = "stage.0"
	runtime.flow_ctx.last_snapshot = {
		"type":    FlowStateIds.STAGE_EXPLORE,
		"meta":    { "t": 0 },
		"data":    {},
		"actions": {},
	}
	return runtime


# ─── Test 1 — npc_line survives contact start ─────────────────────────────────
static func _t_npc_line_survives_contact_start() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t1", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "TEST OPENING LINE — should survive engage."
	contact["burden_variant"] = "steady_witness"

	var save_data := _make_save_with_contact_situation(contact)
	var runtime := _make_runtime(save_data, _make_logger("off"))

	var snap: Dictionary = runtime.dispatch({ "type": "stage.engage_situation", "situation_id": "sit.t1" })
	_restore_save(_save_bak)

	var data: Dictionary = snap.get("data", {})
	var cp: Dictionary = data.get("contact_pending", {})
	var got := str(cp.get("npc_line", ""))
	if got != "TEST OPENING LINE — should survive engage.":
		return { "ok": false, "error": "npc_line was overwritten/blanked by contact start; got: '%s'" % got }
	return { "ok": true }
