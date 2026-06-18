class_name SaveIntegrityTests
extends RefCounted

const TEST_PATH := "/tmp/echoes-vnext-tests/save_integrity_slot.json"

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
	runner.register_test("save_integrity/runtime_boot_surfaces_recovery", Callable(SaveIntegrityTests, "_test_runtime_boot_surfaces_recovery"))
	runner.register_test("save_integrity/failed_flush_remains_queued", Callable(SaveIntegrityTests, "_test_failed_flush_remains_queued"))

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
