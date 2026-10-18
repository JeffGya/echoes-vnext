# res://tests/LegacyLedgerFile.gd
# Moves the legacy-selector ledger between Godot processes, so a SHARDED test run can apply the
# movement_fallback guard to the ledger of the WHOLE run, with the same verdict as a serial run.
#
# WHY. `ActorStateMachine.legacy_selector_uses` is a process-wide ledger. MovementFallbackGuardTests
# fails when it is not empty at the end of a run, so it only sees fallbacks that suites in its OWN
# process caused. A sharded run splits the suites across processes, so a fallback in another shard
# was invisible to the guard (AGENTS.md "Sharded full-suite runs").
#
# HOW.
#   1. Every test process that has ECHOES_TEST_SAVE_DIR set writes its ledger to
#      `<ECHOES_TEST_SAVE_DIR>/legacy_selector_ledger.json` after its last test (`dump_if_isolated`).
#      The dump READS the ledger and does not clear it. A serial run without the variable writes nothing.
#   2. scripts/run-tests-sharded.sh runs MovementFallbackGuardTests in one extra "merge" process.
#      That process has ECHOES_LEGACY_LEDGER_IN set to the shard ledger files. `merge_from_env`
#      loads them into `ActorStateMachine.legacy_selector_uses` BEFORE the first test, so the
#      unchanged guard test judges the combined ledger.
#
# THE SERIAL VERDICT (Jeff, 2026-10-18: "match the serial verdict"). In a serial run,
# `behavior_char/legacy_selector_fallback_is_loud` calls `take_legacy_selector_uses()` at its start.
# That call clears every entry that suites registered BEFORE it recorded. So the serial guard judges
# only the entries recorded at or after that test. `install_serial_wipe` copies this rule into each
# shard process: before the first test whose registration index is at or after the index of
# SERIAL_WIPE_TEST, it sets the ledger aside as "ignored". The ignored entries are written to the
# file and printed by the merge step as a warning. They are real fallbacks that the serial guard
# does not see. They are not judged.
#
# A ledger file that cannot be read becomes a ledger entry that names the file. The guard then
# fails the merge run, and the failure names the file. A silent empty ledger would pass instead.
# The same holds when SERIAL_WIPE_TEST is not registered (renamed or deleted): the shard says so
# in its file, and the merge step fails.
#
# This file does not change what any test asserts. It only chooses where the ledger comes from.

class_name LegacyLedgerFile
extends RefCounted

const FILE_NAME := "legacy_selector_ledger.json"
const ENV_IN := "ECHOES_LEGACY_LEDGER_IN"
const FORMAT := 2
## The test that clears the ledger in a serial run. Rename it only together with this constant.
const SERIAL_WIPE_TEST := "behavior_char/legacy_selector_fallback_is_loud"

static var _order: Dictionary = {}   # test name -> registration index (before any filter)
static var _wipe_index: int = -1
static var _wiped: bool = false
static var _ignored: Array = []


## Copy the serial run's clear-at-behavior_char rule into this process. Call it after every suite
## is registered and BEFORE the suite filter trims the runner. Does nothing in a serial run
## (ECHOES_TEST_SAVE_DIR unset), where the real test does the clearing, and does nothing in the
## merge process, where the loaded entries must stay.
static func install_serial_wipe(runner: CoreTestRunner) -> void:
	if OS.get_environment("ECHOES_TEST_SAVE_DIR") == "" or OS.get_environment(ENV_IN) != "":
		return
	_order = {}
	for i in range(runner._tests.size()):
		var test_name := str((runner._tests[i] as Dictionary).get("name", ""))
		if not _order.has(test_name):
			_order[test_name] = i
	_wipe_index = int(_order.get(SERIAL_WIPE_TEST, -1))
	_wiped = false
	_ignored = []
	runner.before_test_hook = Callable(LegacyLedgerFile, "_before_test")


static func _before_test(test_name: String) -> void:
	if _wiped or _wipe_index < 0:
		return
	if int(_order.get(test_name, -1)) < _wipe_index:
		return
	_wiped = true
	_ignored = ActorStateMachine.take_legacy_selector_uses()


## Where this process writes its ledger.
static func dump_path() -> String:
	return TestSaveHarness.root() + FILE_NAME


## Write this process's ledger to `dump_path()` when ECHOES_TEST_SAVE_DIR is set.
## Returns a one-line report for the console, or "" when nothing was written.
static func dump_if_isolated() -> String:
	if OS.get_environment("ECHOES_TEST_SAVE_DIR") == "" or OS.get_environment(ENV_IN) != "":
		return ""
	var path := dump_path()
	# Entries from suites registered before SERIAL_WIPE_TEST are never judged. If this process
	# never reached that point, all of its entries are such entries.
	var counted: Array = ActorStateMachine.legacy_selector_uses if _wiped else []
	var ignored: Array = _ignored if _wiped else ActorStateMachine.legacy_selector_uses
	var payload := {
		"format": FORMAT,
		"wipe_point_found": _wipe_index >= 0,
		"entries": counted,
		"ignored_entries": ignored,
		"no_context_uses": ActorStateMachine.legacy_selector_no_context_uses,
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Legacy ledger: FAILED to write %s (error %d)" % [path, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(payload))
	file.close()
	return "Legacy ledger: %d judged, %d ignored (recorded before %s), written to %s" % [
		counted.size(), ignored.size(), SERIAL_WIPE_TEST, path]


## Load every file named in ECHOES_LEGACY_LEDGER_IN (separator ":") into the ledger.
## Returns the console lines for the run, or [] when the variable is unset.
static func merge_from_env() -> Array:
	var raw := OS.get_environment(ENV_IN)
	if raw == "":
		return []
	var files := 0
	var merged := 0
	var no_context := 0
	var ignored: Array = []
	for path_value in raw.split(":", false):
		var path := str(path_value)
		files += 1
		var parsed: Dictionary = _read(path)
		if parsed.is_empty():
			_add_sentinel("ledger file missing or malformed: %s" % path)
			merged += 1
			continue
		if not bool(parsed.get("wipe_point_found", false)):
			_add_sentinel("the test %s is not registered, so the serial rule cannot be copied (file %s)"
				% [SERIAL_WIPE_TEST, path])
			merged += 1
		for entry_value in parsed.get("entries", []):
			ActorStateMachine.legacy_selector_uses.append(entry_value)
			merged += 1
		for entry_value in parsed.get("ignored_entries", []):
			ignored.append(entry_value)
		no_context += int(parsed.get("no_context_uses", 0))
	ActorStateMachine.legacy_selector_no_context_uses += no_context
	var lines: Array = []
	lines.append("Legacy ledger: merged %d file(s); %d entr%s judged, %d no-context use(s)" % [
		files, merged, "y" if merged == 1 else "ies", no_context])
	if not ignored.is_empty():
		lines.append(("Legacy ledger: WARNING %d real fallback(s) were recorded before %s and are NOT judged. "
			+ "The serial run clears them at the same point.") % [ignored.size(), SERIAL_WIPE_TEST])
		var by_kind: Dictionary = {}
		for entry_value in ignored:
			var entry: Dictionary = entry_value as Dictionary
			var kind := "reason=%s field=%s" % [str(entry.get("reason", "")), str(entry.get("field", ""))]
			by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var kinds: Array = by_kind.keys()
		kinds.sort_custom(func(a, b): return by_kind[a] > by_kind[b] or (by_kind[a] == by_kind[b] and str(a) < str(b)))
		for i in range(mini(5, kinds.size())):
			lines.append("Legacy ledger:   ignored x%d  %s" % [by_kind[kinds[i]], kinds[i]])
	return lines


static func _add_sentinel(reason: String) -> void:
	ActorStateMachine.legacy_selector_uses.append({
		"actor_id": "(ledger file)",
		"module_id": "(merge step)",
		"reason": reason,
		"field": "",
		"t": 0,
	})


## {} when the file is missing, is not JSON, or has the wrong shape.
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var dict: Dictionary = parsed
	if int(dict.get("format", 0)) != FORMAT or not (dict.get("entries", null) is Array):
		return {}
	return dict
