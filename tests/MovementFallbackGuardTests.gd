# res://tests/MovementFallbackGuardTests.gd
# V2-COMBAT-003 phase 10 — the legacy selector must not be used. See
# ActorStateMachine.gd's ledger docblock (owner decision 7) for why the fallback
# stays and is logged.
#
# THIS SUITE IS THE FAILURE MECHANISM. It is registered LAST, so `runner.run_all()`
# reaches it after every other suite has run and the ledger holds every use the whole
# run produced. It reports the actor and the reason for each one.
#
# WHY A LEDGER AND NOT AN ASSERT. `assert()` is stripped from a release build and
# aborts a debug run at the first use, which would hide how many there are and stop
# the suite before it finished. A ledger read at the end counts them all and names
# each one, and the warning log in `advance_turn` covers the release build, where a
# test suite does not run at all.
#
# A test that induces the fallback on purpose must consume its own entries with
# `ActorStateMachine.take_legacy_selector_uses()`. Exactly one does today:
# `behavior_char/legacy_selector_fallback_is_loud`.
#
# A FILTERED RUN SEES ONLY ITS OWN SUITES. `-- tests movement_fallback` alone runs
# nothing before this suite, so an empty ledger there proves nothing. Only a full run
# is evidence.

class_name MovementFallbackGuardTests
extends RefCounted


static func register(runner) -> void:
	runner.register_test("movement_fallback/legacy_selector_was_never_used",
		func(): return _t_legacy_selector_was_never_used())
	runner.register_test("movement_fallback/no_context_route_is_counted_not_failed",
		func(): return _t_no_context_route_is_counted())


## The headline. Every unconsumed ledger entry is a turn the movement path refused
## and the legacy selector decided instead.
static func _t_legacy_selector_was_never_used() -> Dictionary:
	var uses: Array = ActorStateMachine.take_legacy_selector_uses()
	if uses.is_empty():
		return { "ok": true }
	var lines: Array = []
	for use_value: Variant in uses:
		var use: Dictionary = use_value as Dictionary
		lines.append("  actor=%s module=%s reason=%s field=%s t=%d" % [
			str(use.get("actor_id", "")),
			str(use.get("module_id", "")),
			str(use.get("reason", "")),
			str(use.get("field", "")),
			int(use.get("t", 0)),
		])
	return { "ok": false, "error":
		"the legacy selector decided %d turn(s); the movement path rejected each board:\n%s"
			% [uses.size(), "\n".join(lines)] }


## The other legacy route, counted rather than failed.
##
## A context that carries no `movement_context` never reaches `select_movement_intent`
## at all. About thirty suites drive `BehaviorModule` that way on purpose, so a
## non-zero count here is a test idiom, not a contract failure. The count is reported
## so the number stays visible and a sudden change is noticed.
static func _t_no_context_route_is_counted() -> Dictionary:
	print("[movement_fallback] legacy select_intent through the no-movement-context route: %d turn(s)"
		% ActorStateMachine.legacy_selector_no_context_uses)
	if ActorStateMachine.legacy_selector_no_context_uses < 0:
		return { "ok": false, "error": "the no-context counter went negative" }
	return { "ok": true }
