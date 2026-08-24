# res://tests/FlowTransactionTests.gd
# V2-INFRA-003 Phase 2 Part B
#
# Proves two invariants about FlowRuntime.dispatch():
#   1. One dispatch call causes AT MOST one real save flush — even for the weave-commitment
#      -locked path, which must still fall through to the common closure (encounter bootstrap
#      + save flush) instead of returning early and stranding an already-queued save.
#   2. Every action `dispatch()` accepts is registered exactly once in its `match` block —
#      73 case labels total (two of which carry same-line trailing comments, so a naive
#      `grep -c '":'` undercounts at 71).
#
# A "real flush" is counted via the `save.flush` StructuredLogger event that FlowRuntime emits
# only from inside the actual `SaveService.save_to_file()` call site at the end of dispatch() —
# never from the point where a save is merely requested/queued. This avoids needing to mock or
# intercept SaveService.
#
# Isolation (docs/LESSONS.md #12 — tests must never share the production save path):
#   - Every runtime in this suite boots against an isolated file under /tmp/echoes-vnext-tests/.
#   - The directory is created with DirAccess.make_dir_recursive_absolute() before any runtime
#     touches it — a missing directory silently changes SaveService behaviour.
#   - Any leftover file from a previous run is deleted first, so every test starts from a
#     genuinely missing save (deterministic root_seed 12346 per SaveService.make_new_save).
#   - Balances are set directly on the save dict where needed — never via EconomyService add/spend
#     (tests/AGENTS.md rule).

class_name FlowTransactionTests
extends RefCounted

const DISPATCH_SOURCE_PATH := "res://core/runtime/FlowRuntime.gd"
const EXPECTED_ACTION_COUNT := 73


static func register(runner) -> void:
	runner.register_test("flow_transaction/action_with_save_flushes_once", func(): return _test_action_with_save_flushes_once())
	runner.register_test("flow_transaction/action_without_save_flushes_never", func(): return _test_action_without_save_flushes_never())
	runner.register_test("flow_transaction/unknown_action_flushes_never", func(): return _test_unknown_action_flushes_never())
	runner.register_test("flow_transaction/weave_locked_blocked_action_still_flushes_queued_save", func(): return _test_weave_locked_flushes_queued_save())
	runner.register_test("flow_transaction/weave_locked_blocked_action_performs_no_work", func(): return _test_weave_locked_performs_no_work())
	runner.register_test("flow_transaction/sequential_dispatches_never_exceed_one_flush_each", func(): return _test_sequential_dispatches_never_exceed_one_flush_each())
	runner.register_test("flow_transaction/dispatch_action_count_is_73", func(): return _test_dispatch_action_count_is_73())
	runner.register_test("flow_transaction/dispatch_action_labels_have_no_duplicates", func(): return _test_dispatch_action_labels_have_no_duplicates())


# ---------------------------------------------------------------------------
# Shared harness
# ---------------------------------------------------------------------------

static func _logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	# DEBUG level: "save.flush" and "weave.commit.locked" are both logged via logger.debug().
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	return logger


## Fresh, isolated FlowRuntime, booted against a save file under /tmp that is guaranteed
## missing before this call (so boot() always creates a brand-new save deterministically).
static func _make_runtime(tag: String) -> Dictionary:
	# Shared harness clears the primary save AND SaveService's backup chain, so boot() always
	# reaches make_new_save() instead of recovering a previous run. See tests/TestSaveHarness.gd.
	var save_path: String = TestSaveHarness.fresh_save_path("flow_transaction_%s.json" % tag, "flow_transaction")

	var logger := _logger()
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, save_path)
	runtime.boot()
	return {"runtime": runtime, "logger": logger, "save_path": save_path}


static func _cleanup(save_path: String) -> void:
	TestSaveHarness.remove_save_artifacts(save_path)


## Counts real `save.flush` events logged during exactly one dispatch call.
static func _dispatch_and_count_flushes(runtime: FlowRuntime, logger: StructuredLogger, action: Dictionary) -> int:
	logger.clear()
	runtime.dispatch(action)
	var flushes := 0
	for event_v in logger.get_logs():
		if str((event_v as Dictionary).get("type", "")) == "save.flush":
			flushes += 1
	return flushes


static func _has_log(logger: StructuredLogger, type: String) -> bool:
	for event_v in logger.get_logs():
		if str((event_v as Dictionary).get("type", "")) == type:
			return true
	return false


static func _find_log(logger: StructuredLogger, type: String) -> Dictionary:
	for event_v in logger.get_logs():
		var event: Dictionary = event_v as Dictionary
		if str(event.get("type", "")) == type:
			return event
	return {}


# ---------------------------------------------------------------------------
# Task 2 — one dispatch causes at most one save flush
# ---------------------------------------------------------------------------

## "flow.new_game" unconditionally requests a save (FlowRuntime._handle_new_game) regardless
## of current flow state, so it needs no prior setup beyond boot().
static func _test_action_with_save_flushes_once() -> Dictionary:
	var env := _make_runtime("with_save")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	var flushes := _dispatch_and_count_flushes(runtime, logger, {"type": "flow.new_game"})
	_cleanup(env["save_path"])

	if flushes != 1:
		return {"ok": false, "error": "expected exactly 1 flush for a save-requesting action, got %d" % flushes}
	if runtime.flow_ctx.save_request:
		return {"ok": false, "error": "save_request remained true after a successful flush"}
	return {"ok": true}


## "debug.seed.show" only reads and logs — it never calls _mark_save_requested.
static func _test_action_without_save_flushes_never() -> Dictionary:
	var env := _make_runtime("without_save")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	var flushes := _dispatch_and_count_flushes(runtime, logger, {"type": "debug.seed.show"})
	_cleanup(env["save_path"])

	if flushes != 0:
		return {"ok": false, "error": "expected 0 flushes for a non-save-requesting action, got %d" % flushes}
	return {"ok": true}


static func _test_unknown_action_flushes_never() -> Dictionary:
	var env := _make_runtime("unknown_action")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	var flushes := _dispatch_and_count_flushes(runtime, logger, {"type": "totally.unrecognized.action"})
	var saw_unknown := _has_log(logger, "ui.action.unknown")
	_cleanup(env["save_path"])

	if flushes != 0:
		return {"ok": false, "error": "expected 0 flushes for an unknown action, got %d" % flushes}
	if not saw_unknown:
		return {"ok": false, "error": "unknown action did not log ui.action.unknown"}
	return {"ok": true}


## The core Task 1 proof: a save queued by an EARLIER dispatch must not be stranded behind a
## weave-commitment-locked dispatch. Before the fix this early-returned before the save-flush
## closure ran at all, so the queued flag stayed true for an unbounded number of ticks.
static func _test_weave_locked_flushes_queued_save() -> Dictionary:
	var env := _make_runtime("locked_flushes_queued")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	# Simulate: an earlier dispatch queued a save, then a weaving rite locked commitment.
	runtime.flow_ctx.weave_commit_locked = true
	runtime.flow_ctx.save_request = true
	runtime.flow_ctx.save_request_reason = "test.queued_before_lock"

	var flushes := _dispatch_and_count_flushes(runtime, logger, {"type": "flow.advance", "to": FlowStateIds.MAIN_MENU})
	var blocked_event := _find_log(logger, "weave.commit.locked")
	var snapshot_event := _find_log(logger, "snapshot.emitted")
	_cleanup(env["save_path"])

	if flushes != 1:
		return {"ok": false, "error": "expected exactly 1 flush for the queued save, got %d" % flushes}
	if runtime.flow_ctx.save_request:
		return {"ok": false, "error": "queued save_request remained true after a successful flush behind a locked dispatch"}
	if blocked_event.is_empty():
		return {"ok": false, "error": "blocked dispatch did not log weave.commit.locked"}
	var blocked_data: Dictionary = blocked_event.get("data", {})
	if str(blocked_data.get("blocked_action", "")) != "flow.advance":
		return {"ok": false, "error": "weave.commit.locked did not record the blocked action_type"}
	if snapshot_event.is_empty():
		return {"ok": false, "error": "blocked dispatch did not log snapshot.emitted"}
	var snapshot_data: Dictionary = snapshot_event.get("data", {})
	if str(snapshot_data.get("reason", "")) != "dispatch.weave_locked":
		return {"ok": false, "error": "expected snapshot.emitted reason 'dispatch.weave_locked', got '%s'" % str(snapshot_data.get("reason", ""))}
	return {"ok": true}


## A blocked action must perform no work: it must never enter the match, so a state-mutating
## action type ("flow.new_game", which would otherwise replace flow_ctx.save_data outright and
## transition the flow state) must leave both save_data and the returned snapshot untouched.
static func _test_weave_locked_performs_no_work() -> Dictionary:
	var env := _make_runtime("locked_no_work")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	runtime.flow_ctx.save_data["_test_marker"] = "untouched"
	var snapshot_before: String = JSON.stringify(runtime.flow_ctx.last_snapshot)
	runtime.flow_ctx.weave_commit_locked = true

	var out := runtime.dispatch({"type": "flow.new_game"})
	var snapshot_after: String = JSON.stringify(runtime.flow_ctx.last_snapshot)
	_cleanup(env["save_path"])

	if not runtime.flow_ctx.save_data.has("_test_marker"):
		return {"ok": false, "error": "blocked flow.new_game replaced save_data — action entered the match"}
	if snapshot_before != snapshot_after:
		return {"ok": false, "error": "returned snapshot changed for a blocked dispatch"}
	if JSON.stringify(out) != snapshot_after:
		return {"ok": false, "error": "dispatch() did not return the unchanged snapshot"}
	return {"ok": true}


## Strengthens "at most one flush per dispatch" into a repeatable, per-call invariant across a
## sequence of dispatches, rather than a single sample.
static func _test_sequential_dispatches_never_exceed_one_flush_each() -> Dictionary:
	var env := _make_runtime("sequential")
	var runtime: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]

	var actions := [
		{"type": "debug.seed.show"},                          # no save
		{"type": "debug.seed.set", "seed_root": "seed.777"},  # saves
		{"type": "totally.unknown"},                          # no save
		{"type": "debug.seed.set", "seed_root": "seed.042"},  # saves
	]
	var total_flushes := 0
	for action_v in actions:
		var flushes := _dispatch_and_count_flushes(runtime, logger, action_v as Dictionary)
		if flushes > 1:
			_cleanup(env["save_path"])
			return {"ok": false, "error": "a single dispatch produced %d flushes for action %s" % [flushes, str(action_v)]}
		total_flushes += flushes
	_cleanup(env["save_path"])

	if total_flushes != 2:
		return {"ok": false, "error": "expected exactly 2 total flushes across the sequence, got %d" % total_flushes}
	return {"ok": true}


# ---------------------------------------------------------------------------
# Task 3 — every action dispatch() accepts is registered exactly once
# ---------------------------------------------------------------------------
#
# GDScript's `match` statement exposes no reflection API for its case labels, so this parses
# core/runtime/FlowRuntime.gd's source text directly: it isolates the body of dispatch() (from
# its `func` line to the next top-level `func` declaration) and regex-matches lines shaped like
# a quoted case label at nested indentation, e.g. `\t\t\t"flow.new_game":` or
# `\t\t\t"stage.ignore_situation":  # comment`. This is why 71 (naive `grep -c '":'`) undercounts:
# two labels carry a same-line trailing comment that a plain substring count still matches once,
# but only a line-anchored regex correctly isolates the label from lines that merely happen to
# contain a colon inside a comment (e.g. "V2-STAGE-004: player picked...").

static func _dispatch_source_lines() -> PackedStringArray:
	var file := FileAccess.open(DISPATCH_SOURCE_PATH, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var text := file.get_as_text()
	file.close()
	return text.split("\n")


static func _dispatch_body_lines() -> PackedStringArray:
	var lines := _dispatch_source_lines()
	var start_idx := -1
	var end_idx := lines.size()
	for i in range(lines.size()):
		if start_idx == -1 and lines[i].begins_with("func dispatch(action: Dictionary) -> Dictionary:"):
			start_idx = i
			continue
		if start_idx != -1 and i > start_idx and lines[i].begins_with("func "):
			end_idx = i
			break
	if start_idx == -1:
		return PackedStringArray()
	var body := PackedStringArray()
	for i in range(start_idx, end_idx):
		body.append(lines[i])
	return body


## Returns every quoted match-case label inside dispatch()'s match block, in source order.
## Excludes the `_:` wildcard default case (it is a fallback, not a registered action type).
static func _dispatch_action_labels() -> Array:
	var re := RegEx.new()
	var compile_err := re.compile("^\\t+\"([A-Za-z0-9_.]+)\"\\s*:(\\s*#.*)?$")
	if compile_err != OK:
		return []
	var labels: Array = []
	for line in _dispatch_body_lines():
		var m := re.search(line)
		if m:
			labels.append(m.get_string(1))
	return labels


static func _test_dispatch_action_count_is_73() -> Dictionary:
	var labels := _dispatch_action_labels()
	if labels.size() != EXPECTED_ACTION_COUNT:
		return {"ok": false, "error": "expected %d match case labels in dispatch(), found %d: %s" % [EXPECTED_ACTION_COUNT, labels.size(), str(labels)]}
	return {"ok": true}


static func _test_dispatch_action_labels_have_no_duplicates() -> Dictionary:
	var labels := _dispatch_action_labels()
	if labels.is_empty():
		return {"ok": false, "error": "source parse returned no labels — dispatch() body was not located"}
	var seen: Dictionary = {}
	var duplicates: Array = []
	for label in labels:
		if seen.has(label):
			duplicates.append(label)
		else:
			seen[label] = true
	if not duplicates.is_empty():
		return {"ok": false, "error": "duplicate action registrations found: %s" % str(duplicates)}
	return {"ok": true}
