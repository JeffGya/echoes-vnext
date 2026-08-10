# res://tests/ConversationRepairTests.gd
# V2-PROG-012 Phase 8 — conversation repair regression tests.
#
# Tests:
#   1. conversation_repair/npc_line_survives_contact_start — a populated npc_line set by
#      RealmGenerator (present on sit.contact before FlowRuntime processes it) is not blanked
#      by the unauthored burden_variants lookup in _start_contact_conversation(). Fails if the
#      unconditional overwrite in FlowRuntime.gd is restored.
#   2. conversation_repair/winning_turn_awards_storyweight — a speak_response turn whose
#      resonance_score clears storyweight_speak_threshold increases the speaking echo's
#      storyweight. Fails against the int() truncation bug (storyweight_speak_partial_step ==
#      0.2 → int() == 0 → no gain, which is how this shipped originally).
#   3. conversation_repair/xp_total_not_clobbered — storyweight and xp_total seeded to
#      different values both move independently by the gain amount; xp_total must never be
#      set to a storyweight-derived value that ignores its own prior value.
#   4. conversation_repair/fractional_config_rounds_to_zero_emits_warn — a configured non-zero
#      storyweight_speak_partial_step that rounds to 0 storyweight must emit a logger.warn.
#      Fails if the warn is silently dropped (the historical failure mode this story fixes).
#   5. conversation_repair/storyweight_gain_log_fires_with_correct_values — a winning turn emits
#      conversation.storyweight_gain.awarded with the correct echo_id/gain/storyweight/xp_total.
#      Fails if the success path stays silent (the original playtest bug — the award worked but
#      was indistinguishable from a skipped one in the log).
#   6. conversation_repair/storyweight_gain_reaches_snapshot — the gain and speaker name from a
#      winning turn land in the PROJECTED snapshot's contact_pending, not just the internal
#      contact dict. Fails if the FlowStageExploreState.build_snapshot() hop is missing — this is
#      the hop that has failed repeatedly in this story (correct value, never reached the UI).
#   7. conversation_repair/losing_turn_no_gain_no_confirmation — a turn scoring below threshold
#      produces no storyweight change, no last_turn_storyweight_gain in the snapshot, and no
#      conversation.storyweight_gain.awarded log. Fails if a stale gain from an earlier winning
#      turn leaks into a later losing turn's snapshot/confirmation.

extends RefCounted
class_name ConversationRepairTests

const TEST_SAVE_PATH := "/tmp/echoes-vnext-tests/conversation_repair_slot.json"
const ContactModelScript := preload("res://core/realms/ContactModel.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("conversation_repair/npc_line_survives_contact_start", Callable(ConversationRepairTests, "_t_npc_line_survives_contact_start"))
	runner.register_test("conversation_repair/winning_turn_awards_storyweight", Callable(ConversationRepairTests, "_t_winning_turn_awards_storyweight"))
	runner.register_test("conversation_repair/xp_total_not_clobbered", Callable(ConversationRepairTests, "_t_xp_total_not_clobbered"))
	runner.register_test("conversation_repair/fractional_config_rounds_to_zero_emits_warn", Callable(ConversationRepairTests, "_t_fractional_config_rounds_to_zero_emits_warn"))
	runner.register_test("conversation_repair/storyweight_gain_log_fires_with_correct_values", Callable(ConversationRepairTests, "_t_storyweight_gain_log_fires_with_correct_values"))
	runner.register_test("conversation_repair/storyweight_gain_reaches_snapshot", Callable(ConversationRepairTests, "_t_storyweight_gain_reaches_snapshot"))
	runner.register_test("conversation_repair/losing_turn_no_gain_no_confirmation", Callable(ConversationRepairTests, "_t_losing_turn_no_gain_no_confirmation"))


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


# Puts a contact directly into "pending_contact" with one winning response, bypassing
# consult/bid generation (covered elsewhere) so speak_response can be dispatched in isolation.
static func _seed_pending_contact_with_response(runtime: FlowRuntime, contact: Dictionary) -> void:
	var stage: Dictionary = FlowStageExploreState._get_current_stage(runtime.flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["pending_contact"] = contact
	explore_map["contact_responses"] = [{
		"echo_id":          "echo.a1",
		"echo_name":        "Ama",
		"calling":          "Keeper",
		"emotional_status": "steady",
		"response_text":    "I will answer with the memory we recovered.",
		"resonance_score":  0.8,  # ≥ storyweight_speak_threshold (0.5) → winning turn
		"bid_type":         "alignment",
	}]
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(runtime.flow_ctx, stage)


# Same as _seed_pending_contact_with_response but with a resonance_score below the
# storyweight_speak_threshold (0.5 default) — for the losing-turn test.
static func _seed_pending_contact_with_losing_response(runtime: FlowRuntime, contact: Dictionary) -> void:
	var stage: Dictionary = FlowStageExploreState._get_current_stage(runtime.flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["pending_contact"] = contact
	explore_map["contact_responses"] = [{
		"echo_id":          "echo.a1",
		"echo_name":        "Ama",
		"calling":          "Keeper",
		"emotional_status": "steady",
		"response_text":    "I have nothing useful to offer.",
		"resonance_score":  0.2,  # < storyweight_speak_threshold (0.5) → losing turn
		"bid_type":         "reactive",
	}]
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(runtime.flow_ctx, stage)


static func _find_echo(roster: Array, id: String) -> Dictionary:
	for e_v in roster:
		var e: Dictionary = e_v if e_v is Dictionary else {}
		if str(e.get("id", "")) == id:
			return e
	return {}


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


# ─── Test 2 — a winning turn awards storyweight ──────────────────────────────
static func _t_winning_turn_awards_storyweight() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t2", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	var save_data := _make_save_with_contact_situation(contact, 10, 40)
	var runtime := _make_runtime(save_data, _make_logger("off"))
	_seed_pending_contact_with_response(runtime, contact)

	var before := int(_find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1").get("storyweight", -1))

	runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })

	var after := int(_find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1").get("storyweight", -1))
	_restore_save(_save_bak)

	if after <= before:
		return { "ok": false, "error": "Storyweight did not increase on winning turn (before=%d after=%d)" % [before, after] }
	return { "ok": true }


# ─── Test 3 — xp_total is not clobbered when it differs from storyweight ─────
static func _t_xp_total_not_clobbered() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t3", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	# Seed storyweight and xp_total to deliberately different values.
	var save_data := _make_save_with_contact_situation(contact, 10, 999)
	var runtime := _make_runtime(save_data, _make_logger("off"))
	_seed_pending_contact_with_response(runtime, contact)

	runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })

	var echo := _find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1")
	_restore_save(_save_bak)

	var sw := int(echo.get("storyweight", -1))
	var xp := int(echo.get("xp_total", -1))
	if sw == xp:
		return { "ok": false, "error": "storyweight (%d) and xp_total (%d) collapsed to the same value — xp_total was clobbered from storyweight's base instead of moving independently" % [sw, xp] }
	if xp < 999:
		return { "ok": false, "error": "xp_total (%d) fell below its seeded base 999 — clobbered" % xp }
	if sw < 10:
		return { "ok": false, "error": "storyweight (%d) fell below its seeded base 10" % sw }
	return { "ok": true }


# ─── Test 4 — fractional config that rounds to 0 emits a warn ───────────────
static func _t_fractional_config_rounds_to_zero_emits_warn() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t4", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	var save_data := _make_save_with_contact_situation(contact, 10, 40)
	var logger := _make_logger("info")  # must be at/above INFO for warn() to be captured
	var runtime := _make_runtime(save_data, logger)

	# Force the historical failure mode: a configured non-zero value that rounds to 0
	# (mirrors the shipped 0.2 default before this story's re-tune to 1).
	runtime.config_service._balance["data"]["contact"]["storyweight_speak_partial_step"] = 0.3

	_seed_pending_contact_with_response(runtime, contact)

	runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })

	_restore_save(_save_bak)

	var found := false
	for ev_v in logger.get_logs():
		var ev: Dictionary = ev_v
		if str(ev.get("type", "")) == "conversation.storyweight_gain.rounded_to_zero":
			found = true
			break
	if not found:
		return { "ok": false, "error": "Expected a conversation.storyweight_gain.rounded_to_zero warn log; none found" }
	return { "ok": true }


# ─── Test 5 — the successful-award log fires with correct gain/totals ───────
# Falsifiable: before this story's fix, the success path never called logger at all —
# a real award and a silently-skipped one were indistinguishable in the log. This test
# fails if conversation.storyweight_gain.awarded is missing OR if any of its payload
# fields (gain, storyweight, xp_total, echo_id) don't match what actually landed on the echo.
static func _t_storyweight_gain_log_fires_with_correct_values() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t5", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	var save_data := _make_save_with_contact_situation(contact, 10, 40)
	var logger := _make_logger("info")
	var runtime := _make_runtime(save_data, logger)
	_seed_pending_contact_with_response(runtime, contact)

	runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })

	var echo := _find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1")
	_restore_save(_save_bak)

	var found: Dictionary = {}
	for ev_v in logger.get_logs():
		var ev: Dictionary = ev_v
		if str(ev.get("type", "")) == "conversation.storyweight_gain.awarded":
			found = ev
			break
	if found.is_empty():
		return { "ok": false, "error": "Expected a conversation.storyweight_gain.awarded log on a winning turn; none found" }

	var data: Dictionary = found.get("data", found)  # StructuredLogger may nest payload under "data"
	if str(data.get("echo_id", "")) != "echo.a1":
		return { "ok": false, "error": "Log echo_id mismatch: got '%s'" % str(data.get("echo_id", "")) }
	var logged_gain := int(data.get("gain", -1))
	var expected_gain := int(echo.get("storyweight", -1)) - 10
	if logged_gain != expected_gain or logged_gain <= 0:
		return { "ok": false, "error": "Log gain=%d does not match actual storyweight delta=%d" % [logged_gain, expected_gain] }
	if int(data.get("storyweight", -1)) != int(echo.get("storyweight", -1)):
		return { "ok": false, "error": "Log storyweight=%d does not match resulting echo.storyweight=%d" % [int(data.get("storyweight", -1)), int(echo.get("storyweight", -1))] }
	if int(data.get("xp_total", -1)) != int(echo.get("xp_total", -1)):
		return { "ok": false, "error": "Log xp_total=%d does not match resulting echo.xp_total=%d" % [int(data.get("xp_total", -1)), int(echo.get("xp_total", -1))] }
	return { "ok": true }


# ─── Test 6 — the gain reaches the PROJECTED snapshot ────────────────────────
# Falsifiable: the internal contact dict can hold the right value while the UI-facing
# snapshot built by FlowStageExploreState.build_snapshot() never receives it — this is
# the exact failure mode called out in this story (7 prior "correct value, never reached
# anyone" defects). This test reads ONLY the dispatch() return value (the projected
# snapshot), never the internal save_data, so it fails if the data-path hop is broken.
static func _t_storyweight_gain_reaches_snapshot() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t6", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	var save_data := _make_save_with_contact_situation(contact, 10, 40)
	var runtime := _make_runtime(save_data, _make_logger("off"))
	_seed_pending_contact_with_response(runtime, contact)

	var snap: Dictionary = runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })
	_restore_save(_save_bak)

	var data: Dictionary = snap.get("data", {})
	var cp: Dictionary = data.get("contact_pending", {})
	var snap_gain := int(cp.get("last_turn_storyweight_gain", -1))
	var snap_name := str(cp.get("last_turn_speaker_name", ""))
	if snap_gain <= 0:
		return { "ok": false, "error": "Projected snapshot's contact_pending.last_turn_storyweight_gain=%d — the gain never reached the UI-facing snapshot" % snap_gain }
	if snap_name != "Echo echo.a1":
		return { "ok": false, "error": "Projected snapshot's contact_pending.last_turn_speaker_name='%s' — expected the speaking echo's name" % snap_name }
	return { "ok": true }


# ─── Test 7 — a losing turn produces no gain and no confirmation ────────────
# Falsifiable: fails if storyweight moves on a sub-threshold turn, if the snapshot still
# shows a gain/speaker (e.g. leaked from a prior winning turn since these fields live on
# a dict that persists turn-to-turn), or if the awarded log fires when it shouldn't.
static func _t_losing_turn_no_gain_no_confirmation() -> Dictionary:
	var _save_bak := _capture_save()
	var contact := ContactModelScript.make("contact.t7", "witness", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	contact["npc_line"] = "Speak, if you dare."

	var save_data := _make_save_with_contact_situation(contact, 10, 40)
	var logger := _make_logger("info")
	var runtime := _make_runtime(save_data, logger)
	_seed_pending_contact_with_losing_response(runtime, contact)

	var before := int(_find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1").get("storyweight", -1))

	var snap: Dictionary = runtime.dispatch({ "type": "stage.speak_response", "echo_id": "echo.a1" })

	var after := int(_find_echo(runtime.flow_ctx.save_data["sanctum"]["roster"], "echo.a1").get("storyweight", -1))
	_restore_save(_save_bak)

	if after != before:
		return { "ok": false, "error": "Storyweight changed on a losing turn (before=%d after=%d)" % [before, after] }

	var data: Dictionary = snap.get("data", {})
	var cp: Dictionary = data.get("contact_pending", {})
	var snap_gain := int(cp.get("last_turn_storyweight_gain", -1))
	var snap_name := str(cp.get("last_turn_speaker_name", "MISSING"))
	if snap_gain != 0:
		return { "ok": false, "error": "Snapshot shows last_turn_storyweight_gain=%d on a losing turn — should be 0" % snap_gain }
	if snap_name != "":
		return { "ok": false, "error": "Snapshot shows last_turn_speaker_name='%s' on a losing turn — should be empty" % snap_name }

	for ev_v in logger.get_logs():
		var ev: Dictionary = ev_v
		if str(ev.get("type", "")) == "conversation.storyweight_gain.awarded":
			return { "ok": false, "error": "conversation.storyweight_gain.awarded fired on a losing turn" }
	return { "ok": true }
