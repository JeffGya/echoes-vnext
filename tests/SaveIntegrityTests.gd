class_name SaveIntegrityTests
extends RefCounted

static var TEST_PATH := TestSaveHarness.dir() + "save_integrity_slot.json"

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("save_integrity/rotates_three_generations", Callable(SaveIntegrityTests, "_test_rotates_three_generations"))
	runner.register_test("save_integrity/chooses_newest_valid_artifact", Callable(SaveIntegrityTests, "_test_chooses_newest_valid_artifact"))
	runner.register_test("save_integrity/recovered_tmp_survives_pending_write_failure", Callable(SaveIntegrityTests, "_test_recovered_tmp_survives_pending_write_failure"))
	runner.register_test("save_integrity/recovered_pending_survives_other_slot_failure", Callable(SaveIntegrityTests, "_test_recovered_pending_survives_other_slot_failure"))
	runner.register_test("save_integrity/recovers_corrupt_primary_from_backup", Callable(SaveIntegrityTests, "_test_recovers_corrupt_primary_from_backup"))
	runner.register_test("save_integrity/all_invalid_is_non_destructive", Callable(SaveIntegrityTests, "_test_all_invalid_is_non_destructive"))
	runner.register_test("save_integrity/missing_is_distinct_from_error", Callable(SaveIntegrityTests, "_test_missing_is_distinct_from_error"))
	runner.register_test("save_integrity/invalid_write_preserves_current", Callable(SaveIntegrityTests, "_test_invalid_write_preserves_current"))
	runner.register_test("save_integrity/legacy_generation_defaults_to_zero", Callable(SaveIntegrityTests, "_test_legacy_generation_defaults_to_zero"))
	runner.register_test("save_integrity/repairs_same_version_incomplete_candidate", Callable(SaveIntegrityTests, "_test_repairs_same_version_incomplete_candidate"))
	runner.register_test("save_integrity/rejects_unsupported_schema_before_repairs", Callable(SaveIntegrityTests, "_test_rejects_unsupported_schema_before_repairs"))
	runner.register_test("save_integrity/runtime_boot_surfaces_recovery", Callable(SaveIntegrityTests, "_test_runtime_boot_surfaces_recovery"))
	runner.register_test("save_integrity/failed_flush_remains_queued", Callable(SaveIntegrityTests, "_test_failed_flush_remains_queued"))
	runner.register_test("save_integrity/legacy_origin_included_path_falls_back_to_party_pos", Callable(SaveIntegrityTests, "_test_legacy_origin_included_path"))
	runner.register_test("save_integrity/presentation_only_keys_do_not_flag_repair", Callable(SaveIntegrityTests, "_test_presentation_only_keys_do_not_flag_repair"))

static func _logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger

static func _cleanup() -> void:
	for suffix_v in ["", ".pending_a", ".pending_b", ".tmp", ".bak1", ".bak2", ".bak3", ".corrupt"]:
		var artifact_path: String = TEST_PATH + str(suffix_v)
		if FileAccess.file_exists(artifact_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact_path))
		elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(artifact_path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact_path))

static func _save(name: String, generation: int = 0) -> Dictionary:
	var save := SaveSchema.make_new_save(4200 + generation, "save-integrity-test")
	save["first_boot"] = false
	save["sanctum"]["name"] = name
	save["meta"]["save_generation"] = generation
	return save

static func _write_raw(path: String, value: Variant) -> bool:
	SaveService.ensure_save_dir_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value if value is String else JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	return true

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func _generation(path: String) -> int:
	var save := _read_json(path)
	var meta_v: Variant = save.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	return int(meta.get("save_generation", -1))

static func _test_rotates_three_generations() -> Dictionary:
	_cleanup()
	var save := _save("Generation 0")
	for i in range(4):
		save["sanctum"]["name"] = "Generation %d" % (i + 1)
		if not SaveService.save_to_file(TEST_PATH, save, _logger(), i):
			_cleanup()
			return {"ok": false, "error": "save %d failed" % (i + 1)}
	var generations := [
		_generation(TEST_PATH),
		_generation(TEST_PATH + ".bak1"),
		_generation(TEST_PATH + ".bak2"),
		_generation(TEST_PATH + ".bak3"),
	]
	_cleanup()
	if generations != [4, 3, 2, 1]:
		return {"ok": false, "error": "expected generations [4, 3, 2, 1], got %s" % str(generations)}
	return {"ok": true}

static func _test_chooses_newest_valid_artifact() -> Dictionary:
	_cleanup()
	_write_raw(TEST_PATH, _save("Primary", 5))
	_write_raw(TEST_PATH + ".tmp", _save("Interrupted Newest", 6))
	_write_raw(TEST_PATH + ".bak1", _save("Backup", 4))
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var data_v: Variant = result.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var loaded_name: String = str(data.get("sanctum", {}).get("name", ""))
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_RECOVERED:
		return {"ok": false, "error": "expected recovered status"}
	if str(result.get("source", "")) != "tmp" or loaded_name != "Interrupted Newest":
		return {"ok": false, "error": "newest tmp was not selected"}
	return {"ok": true}

static func _test_recovers_corrupt_primary_from_backup() -> Dictionary:
	_cleanup()
	_write_raw(TEST_PATH, "{truncated")
	_write_raw(TEST_PATH + ".bak1", _save("Recovered House", 8))
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var current := _read_json(TEST_PATH)
	var current_name: String = str(current.get("sanctum", {}).get("name", ""))
	var corrupt_archived := FileAccess.file_exists(TEST_PATH + ".corrupt")
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_RECOVERED:
		return {"ok": false, "error": "corrupt primary did not recover"}
	if current_name != "Recovered House":
		return {"ok": false, "error": "recovered backup was not promoted"}
	if not corrupt_archived:
		return {"ok": false, "error": "corrupt primary was not archived for diagnosis"}
	return {"ok": true}

static func _test_recovered_tmp_survives_pending_write_failure() -> Dictionary:
	_cleanup()
	_write_raw(TEST_PATH, _save("Older Primary", 5))
	_write_raw(TEST_PATH + ".tmp", _save("Newest Interrupted Save", 6))
	var tmp_before := FileAccess.get_file_as_bytes(TEST_PATH + ".tmp")
	var pending_abs := ProjectSettings.globalize_path(TEST_PATH + ".pending_a")
	if DirAccess.make_dir_recursive_absolute(pending_abs) != OK:
		_cleanup()
		return {"ok": false, "error": "could not create blocking pending directory"}

	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var tmp_unchanged := FileAccess.file_exists(TEST_PATH + ".tmp") \
		and FileAccess.get_file_as_bytes(TEST_PATH + ".tmp") == tmp_before
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_RECOVERED:
		return {"ok": false, "error": "expected recovered status when tmp is newest"}
	if not bool(result.get("needs_save_retry", false)):
		return {"ok": false, "error": "failed recovery persistence did not request retry"}
	if not tmp_unchanged:
		return {"ok": false, "error": "selected tmp was modified by failed recovery persistence"}
	return {"ok": true}

static func _test_recovered_pending_survives_other_slot_failure() -> Dictionary:
	_cleanup()
	_write_raw(TEST_PATH, _save("Older Primary", 5))
	_write_raw(TEST_PATH + ".pending_a", _save("Newest Pending Save", 7))
	var pending_before := FileAccess.get_file_as_bytes(TEST_PATH + ".pending_a")
	var blocked_abs := ProjectSettings.globalize_path(TEST_PATH + ".pending_b")
	if DirAccess.make_dir_recursive_absolute(blocked_abs) != OK:
		_cleanup()
		return {"ok": false, "error": "could not create blocking alternate-pending directory"}

	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var pending_unchanged := FileAccess.file_exists(TEST_PATH + ".pending_a") \
		and FileAccess.get_file_as_bytes(TEST_PATH + ".pending_a") == pending_before
	_cleanup()
	if str(result.get("source", "")) != "pending_a":
		return {"ok": false, "error": "newest pending slot was not selected"}
	if not bool(result.get("needs_save_retry", false)):
		return {"ok": false, "error": "failed alternate-slot write did not request retry"}
	if not pending_unchanged:
		return {"ok": false, "error": "newest pending source was modified after alternate-slot failure"}
	return {"ok": true}

static func _test_all_invalid_is_non_destructive() -> Dictionary:
	_cleanup()
	var invalid_by_path := {
		TEST_PATH: "{bad-primary",
		TEST_PATH + ".tmp": "{bad-tmp",
		TEST_PATH + ".bak1": "[]",
		TEST_PATH + ".bak2": "null",
		TEST_PATH + ".bak3": "not-json",
	}
	for artifact_path in invalid_by_path:
		_write_raw(str(artifact_path), str(invalid_by_path[artifact_path]))
	var before: Dictionary = {}
	for artifact_path in invalid_by_path:
		before[artifact_path] = FileAccess.get_file_as_bytes(str(artifact_path))
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var unchanged := true
	for artifact_path in invalid_by_path:
		unchanged = unchanged and before[artifact_path] == FileAccess.get_file_as_bytes(str(artifact_path))
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_ERROR:
		return {"ok": false, "error": "expected error when every artifact is invalid"}
	if not unchanged:
		return {"ok": false, "error": "invalid artifacts were modified"}
	return {"ok": true}

static func _test_missing_is_distinct_from_error() -> Dictionary:
	_cleanup()
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	if str(result.get("status", "")) != SaveService.LOAD_MISSING:
		return {"ok": false, "error": "absent artifacts must return missing"}
	return {"ok": true}

static func _test_invalid_write_preserves_current() -> Dictionary:
	_cleanup()
	var valid := _save("Known Good")
	if not SaveService.save_to_file(TEST_PATH, valid, _logger(), 0):
		_cleanup()
		return {"ok": false, "error": "setup save failed"}
	var before := FileAccess.get_file_as_bytes(TEST_PATH)
	var invalid := {"meta": {}, "sanctum": {"name": "Bad Write"}}
	var write_ok := SaveService.save_to_file(TEST_PATH, invalid, _logger(), 1)
	var after := FileAccess.get_file_as_bytes(TEST_PATH)
	_cleanup()
	if write_ok:
		return {"ok": false, "error": "invalid save was accepted"}
	if before != after:
		return {"ok": false, "error": "current save changed after invalid write"}
	return {"ok": true}

static func _test_legacy_generation_defaults_to_zero() -> Dictionary:
	_cleanup()
	var legacy := _save("Legacy")
	SaveService._apply_additive_defaults_and_repairs(legacy, _logger(), 0)
	legacy["meta"].erase("save_generation")
	_write_raw(TEST_PATH, legacy)
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_LOADED:
		return {"ok": false, "error": "legacy save did not load"}
	if int(result.get("generation", -1)) != 0:
		return {"ok": false, "error": "legacy generation should default to zero"}
	return {"ok": true}

static func _test_repairs_same_version_incomplete_candidate() -> Dictionary:
	_cleanup()
	var incomplete := _save("Repairable Legacy", 3)
	incomplete.erase("economy")
	_write_raw(TEST_PATH, incomplete)
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var data_v: Variant = result.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var economy_v: Variant = data.get("economy", {})
	var economy: Dictionary = economy_v if economy_v is Dictionary else {}
	var persisted := _read_json(TEST_PATH)
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_LOADED:
		return {"ok": false, "error": "repairable same-version save did not load"}
	if str(result.get("source", "")) != "primary":
		return {"ok": false, "error": "repairable primary was not selected"}
	if int(economy.get("ase", -1)) != 0 or int(economy.get("ekwan", -1)) != 0:
		return {"ok": false, "error": "missing economy block was not repaired"}
	if not (persisted.get("economy", {}) is Dictionary):
		return {"ok": false, "error": "repaired candidate was not persisted"}
	return {"ok": true}

static func _test_rejects_unsupported_schema_before_repairs() -> Dictionary:
	_cleanup()
	var unsupported := _save("Unsupported", 4)
	unsupported["schema_version"] = SaveSchema.SCHEMA_VERSION + 1
	unsupported.erase("economy")
	_write_raw(TEST_PATH, unsupported)
	var before := FileAccess.get_file_as_bytes(TEST_PATH)
	var result := SaveService.load_from_file(TEST_PATH, _logger(), 0)
	var diagnostics_v: Variant = result.get("diagnostics", [])
	var diagnostics: Array = diagnostics_v if diagnostics_v is Array else []
	var unchanged := FileAccess.get_file_as_bytes(TEST_PATH) == before
	_cleanup()
	if str(result.get("status", "")) != SaveService.LOAD_ERROR:
		return {"ok": false, "error": "unsupported schema was accepted"}
	if diagnostics.is_empty() or str((diagnostics[0] as Dictionary).get("reason", "")) != "schema_invalid":
		return {"ok": false, "error": "unsupported schema did not report schema_invalid"}
	if not unchanged:
		return {"ok": false, "error": "unsupported save was mutated during rejection"}
	return {"ok": true}

static func _test_runtime_boot_surfaces_recovery() -> Dictionary:
	_cleanup()
	_write_raw(TEST_PATH, "{bad-primary")
	_write_raw(TEST_PATH + ".bak1", _save("Runtime Recovery", 3))
	var runtime := FlowRuntime.new(_logger(), ConfigService.new(), TEST_PATH)
	var snapshot := runtime.boot()
	var meta_v: Variant = snapshot.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	var recovery_v: Variant = meta.get("save_recovery", {})
	_cleanup()
	if not (recovery_v is Dictionary) or (recovery_v as Dictionary).is_empty():
		return {"ok": false, "error": "boot snapshot omitted recovery notice"}
	return {"ok": true}

static func _test_failed_flush_remains_queued() -> Dictionary:
	_cleanup()
	var logger := _logger()
	var runtime := FlowRuntime.new(logger, ConfigService.new(), TEST_PATH)
	runtime.flow_ctx = FlowContext.new()
	runtime.flow_ctx.sim_tick = 0
	runtime.flow_ctx.logger = logger
	runtime.flow_ctx.save_data = {"invalid": true}
	runtime.flow_ctx.save_request = true
	runtime.flow_ctx.save_request_reason = "test.failed_flush"
	runtime.flow_ctx.last_snapshot = {"type": "test", "meta": {}, "data": {}, "actions": {}}
	runtime.flow_machine = FlowStateMachine.new()
	runtime.flow_machine.register_default_states()
	runtime.dispatch({"type": "test.noop"})
	_cleanup()
	if not runtime.flow_ctx.save_request:
		return {"ok": false, "error": "failed save request was cleared"}
	if runtime.flow_ctx.save_request_reason != "test.failed_flush":
		return {"ok": false, "error": "failed save reason changed"}
	return {"ok": true}


# ---------------------------------------------------------------------------
# V2-COMBAT-002 Phase 6E — explore_map traveled-path repair coverage
# ---------------------------------------------------------------------------

## A capturing logger: level info so `save.schema.repair` notices are observable.
static func _capturing_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_INFO)
	return logger

static func _has_repair_note(logger: StructuredLogger) -> bool:
	for event_v in logger.get_logs():
		if str((event_v as Dictionary).get("type", "")) == "save.schema.repair":
			return true
	return false

## A save carrying one realm with one stage, fully repaired so that any FURTHER
## repair observed by a test is caused only by what that test erased.
static func _save_with_explore_map(name: String) -> Dictionary:
	var save := _save(name)
	save["realms"] = {
		"realm.01": {
			"stages": [
				{"index": 0, "explore_map": StageExploreModel.make(30, 30, [])},
			],
		},
	}
	SaveService._apply_additive_defaults_and_repairs(save, _logger(), 0)
	return save

static func _explore_map_of(save: Dictionary) -> Dictionary:
	var stages: Array = ((save["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array
	return (stages[0] as Dictionary)["explore_map"] as Dictionary

## PIN, DO NOT FIX — legacy origin-included `last_traveled_path` × repaired origin.
##
## Pre-slice-5 saves persisted `last_traveled_path` with the ORIGIN INCLUDED as
## element [0]. The current writer (FlowRuntime._advance_explore_party) writes
## DESTINATIONS ONLY and carries the origin alongside in `last_traveled_origin`.
## SaveService._apply_additive_defaults_and_repairs repairs a MISSING
## `last_traveled_origin` to {} — it cannot infer the pre-advance cell — so
## FlowStageExploreState._project_traveled_origin falls back to `party_pos`, which
## on a legacy save is the POST-advance cell, while `last_traveled_path[0]` is the
## PRE-advance cell.
##
## CONSEQUENCE (accepted): the UI's chained tween draws its first segment from the
## post-advance cell back to the pre-advance cell, duplicating that segment once.
## This is accepted because both fields are presentation-only, the duplication is
## visual and self-limiting, and it self-heals on the very next advance (which
## rewrites both fields in the current destinations-only shape). This test asserts
## the CURRENT behaviour deliberately; do not "fix" the projection to peek at
## last_traveled_path[0] without a design decision.
static func _test_legacy_origin_included_path() -> Dictionary:
	var save := _save_with_explore_map("Legacy Traveled Path")
	var emap := _explore_map_of(save)
	var pre_advance: Dictionary = {"col": 4, "row": 7}
	var post_advance: Dictionary = {"col": 6, "row": 7}
	# Legacy shape: origin included as element [0], no last_traveled_origin at all.
	emap["last_traveled_path"] = [pre_advance, {"col": 5, "row": 7}, post_advance]
	emap["party_pos"] = post_advance
	emap.erase("last_traveled_origin")

	SaveService._apply_additive_defaults_and_repairs(save, _logger(), 0)
	var repaired_map := _explore_map_of(save)
	if not repaired_map.has("last_traveled_origin"):
		return {"ok": false, "error": "repair did not add last_traveled_origin"}
	if not (repaired_map["last_traveled_origin"] as Dictionary).is_empty():
		return {"ok": false, "error": "repair must default the origin to {} — it cannot infer it"}
	if (repaired_map["last_traveled_path"] as Array).size() != 3:
		return {"ok": false, "error": "repair must not rewrite an existing legacy path"}

	var projected := FlowStageExploreState._project_traveled_origin(repaired_map)
	if projected != post_advance:
		return {"ok": false, "error": "empty origin must fall back to party_pos, got %s" % str(projected)}
	var legacy_first: Dictionary = (repaired_map["last_traveled_path"] as Array)[0] as Dictionary
	if legacy_first != pre_advance:
		return {"ok": false, "error": "legacy path head changed: %s" % str(legacy_first)}
	# The duplicated first tween segment, stated as an assertion rather than prose.
	if projected == legacy_first:
		return {"ok": false, "error": "fixture failed to reproduce the legacy origin/path mismatch"}
	return {"ok": true}

## PIN, DO NOT FIX — `_003_repaired` deliberately skips the two presentation-only keys.
##
## Every key-defaulting branch inside the V2-STAGE-003 explore_map block sets
## `_003_repaired = true` EXCEPT `last_traveled_path` and `last_traveled_origin`.
## That is DELIBERATE, not an oversight: those two are the only presentation-only
## keys in the block, and raising a durable `save.schema.repair` notice for a
## transient UI field would be noise. Their defaults are still written — only the
## repair FLAG (and therefore the log note and the persist-repaired-candidate path)
## is suppressed. A durable key in the same block (e.g. `target_situation_id`) does
## flag, proving the suppression is scoped to those two keys alone.
static func _test_presentation_only_keys_do_not_flag_repair() -> Dictionary:
	var save := _save_with_explore_map("Presentation Only Repair")
	# Baseline: a fully-repaired save reports nothing further to repair.
	if SaveService._apply_additive_defaults_and_repairs(save, _logger(), 0):
		return {"ok": false, "error": "repair is not idempotent — baseline is unusable"}

	var emap := _explore_map_of(save)
	emap.erase("last_traveled_path")
	emap.erase("last_traveled_origin")
	var quiet_logger := _capturing_logger()
	var quiet_repaired := SaveService._apply_additive_defaults_and_repairs(save, quiet_logger, 0)
	var after := _explore_map_of(save)
	if not after.has("last_traveled_path") or not after.has("last_traveled_origin"):
		return {"ok": false, "error": "presentation-only defaults were not written"}
	if not (after["last_traveled_path"] as Array).is_empty() \
			or not (after["last_traveled_origin"] as Dictionary).is_empty():
		return {"ok": false, "error": "presentation-only defaults are [] and {}"}
	if quiet_repaired:
		return {"ok": false, "error": "presentation-only keys must not flag a durable repair"}
	if _has_repair_note(quiet_logger):
		return {"ok": false, "error": "presentation-only keys must not log save.schema.repair"}

	# A durable key in the SAME block still flags and still logs.
	emap = _explore_map_of(save)
	emap.erase("last_traveled_path")
	emap.erase("last_traveled_origin")
	emap.erase("target_situation_id")
	var loud_logger := _capturing_logger()
	var loud_repaired := SaveService._apply_additive_defaults_and_repairs(save, loud_logger, 0)
	if not loud_repaired:
		return {"ok": false, "error": "a missing durable key must flag a repair"}
	if not _has_repair_note(loud_logger):
		return {"ok": false, "error": "a durable repair must log save.schema.repair"}
	if not _explore_map_of(save).has("last_traveled_path"):
		return {"ok": false, "error": "presentation-only defaults missing after durable repair"}
	return {"ok": true}
