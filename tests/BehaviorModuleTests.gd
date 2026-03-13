# res://tests/BehaviorModuleTests.gd
# Tests for the ACTOR-003 behavior module interface:
#   1. IdleBehaviorModule returns a valid idle intent for any context.
#   2. ActorStateMachine.advance_turn() logs actor.intent with correct fields.
#   3. ActorStateMachine.get_snapshot() includes behavior_module: "idle".
#   4. Base BehaviorModule methods return safe defaults without crashing.
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name BehaviorModuleTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("behavior/idle_returns_idle_action",          Callable(BehaviorModuleTests, "_t_idle_returns_idle_action"))
	runner.register_test("behavior/actorsm_advance_turn_logs_intent",  Callable(BehaviorModuleTests, "_t_actorsm_advance_turn_logs_intent"))
	runner.register_test("behavior/actorsm_snapshot_includes_module",  Callable(BehaviorModuleTests, "_t_actorsm_snapshot_includes_module"))
	runner.register_test("behavior/base_module_safe_fallback",         Callable(BehaviorModuleTests, "_t_base_module_safe_fallback"))


# -------------------------
# Tests
# -------------------------

# Test 1: idle_returns_idle_action
# IdleBehaviorModule.select_intent() must return a valid idle intent regardless of context.
static func _t_idle_returns_idle_action() -> Dictionary:
	var idle := IdleBehaviorModule.new()

	var intent: Dictionary = idle.select_intent({})
	if intent.get("action_type") != "actor.idle":
		return { "ok": false, "error": "Expected action_type='actor.idle', got: %s" % str(intent.get("action_type")) }
	if intent.get("target_id") != "":
		return { "ok": false, "error": "Expected target_id='', got: %s" % str(intent.get("target_id")) }
	if intent.get("priority") != 0.0:
		return { "ok": false, "error": "Expected priority=0.0, got: %s" % str(intent.get("priority")) }

	# Also verify with a populated context — module must not care about content
	var ctx := { "actor": { "id": "echo_001" }, "all_actors": [], "t": 1 }
	var intent2: Dictionary = idle.select_intent(ctx)
	if intent2.get("action_type") != "actor.idle":
		return { "ok": false, "error": "Idle intent changed with non-empty context: %s" % str(intent2.get("action_type")) }

	return { "ok": true }


# Test 2: actorsm_advance_turn_logs_intent
# advance_turn() must log an actor.intent event with module_id, action_type, target_id, actor_id.
static func _t_actorsm_advance_turn_logs_intent() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_0001", "Ama Bonsu")
	var actor: Dictionary = EchoActor.from_echo(echo)
	var sm := ActorStateMachine.new(actor) # defaults to IdleBehaviorModule

	var logger := StructuredLogger.new()
	logger.set_level("info") # capture events for assertion

	var context := { "actor": actor, "all_actors": [], "t": 5 }
	var intent: Dictionary = sm.advance_turn(context, logger, 5)

	# Verify returned intent
	if intent.get("action_type") != "actor.idle":
		return { "ok": false, "error": "advance_turn() returned wrong action_type: %s" % str(intent.get("action_type")) }

	# Find actor.intent log event
	var logs: Array = logger.get_logs()
	var found_event: Dictionary = {}
	for entry in logs:
		if str(entry.get("type", "")) == "actor.intent":
			found_event = entry
			break

	if found_event.is_empty():
		return { "ok": false, "error": "No actor.intent log event found after advance_turn()" }

	var data: Dictionary = found_event.get("data", {})
	# ACTOR-005: echo actors now default to BehaviorArbiter
	if str(data.get("module_id", "")) != "arbiter":
		return { "ok": false, "error": "actor.intent log has wrong module_id: %s" % str(data.get("module_id")) }
	if str(data.get("action_type", "")) != "actor.idle":
		return { "ok": false, "error": "actor.intent log has wrong action_type: %s" % str(data.get("action_type")) }
	if str(data.get("actor_id", "")) != "echo_0001":
		return { "ok": false, "error": "actor.intent log has wrong actor_id: %s" % str(data.get("actor_id")) }

	return { "ok": true }


# Test 3: actorsm_snapshot_includes_module
# get_snapshot() must include behavior_module: "idle" for a default-constructed ActorSM.
# After advance_turn(), last_intent must reflect the intent that was selected.
static func _t_actorsm_snapshot_includes_module() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_0002", "Kwame Asante")
	var actor: Dictionary = EchoActor.from_echo(echo)
	var sm := ActorStateMachine.new(actor)

	var snap: Dictionary = sm.get_snapshot()

	# behavior_module field — ACTOR-005: echo actors default to BehaviorArbiter
	if str(snap.get("behavior_module", "")) != "arbiter":
		return { "ok": false, "error": "Expected behavior_module='arbiter', got: %s" % str(snap.get("behavior_module")) }
	# actor_id and name round-trip
	if str(snap.get("actor_id", "")) != "echo_0002":
		return { "ok": false, "error": "Expected actor_id='echo_0002', got: %s" % str(snap.get("actor_id")) }
	# last_intent starts empty
	if not snap.get("last_intent", {}).is_empty():
		return { "ok": false, "error": "Expected empty last_intent before first advance_turn(), got: %s" % str(snap.get("last_intent")) }

	# After advance_turn(), last_intent must be populated
	var logger := StructuredLogger.new()
	logger.set_level("off")
	sm.advance_turn({ "actor": actor, "all_actors": [], "t": 1 }, logger, 1)
	var snap2: Dictionary = sm.get_snapshot()
	if str(snap2.get("last_intent", {}).get("action_type", "")) != "actor.idle":
		return { "ok": false, "error": "Expected last_intent.action_type='actor.idle' after advance_turn(), got: %s" % str(snap2.get("last_intent")) }

	return { "ok": true }


# Test 4: base_module_safe_fallback
# Calling BehaviorModule (base) methods directly must return safe defaults without crashing.
# (push_error is called internally but does not throw — we just assert safe return values.)
static func _t_base_module_safe_fallback() -> Dictionary:
	var base := BehaviorModule.new()

	var id: String = base.get_module_id()
	if id != "":
		return { "ok": false, "error": "Expected base.get_module_id() == '', got: '%s'" % id }

	var intent: Dictionary = base.select_intent({})
	if intent != {}:
		return { "ok": false, "error": "Expected base.select_intent({}) == {}, got: %s" % str(intent) }

	return { "ok": true }
