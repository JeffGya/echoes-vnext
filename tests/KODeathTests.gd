# res://tests/KODeathTests.gd
# Tests for the ACTOR-008 KO & Death State system:
#   1. Actor with current_hp=0 transitions to Dead on advance_turn().
#   2. Already-dead actor skips the behavior module on subsequent turns.
#   3. Dead actor is excluded from ActorService.get_nearest_enemy() results.
#   4. actor.died log event contains required fields (actor_id, round_number).
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name KODeathTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("ko_death/actor_ko_on_zero_hp",                    Callable(KODeathTests, "_t_actor_ko_on_zero_hp"))
	runner.register_test("ko_death/dead_actor_skips_module_on_next_turn",   Callable(KODeathTests, "_t_dead_actor_skips_module_on_next_turn"))
	runner.register_test("ko_death/dead_actor_excluded_from_targeting",     Callable(KODeathTests, "_t_dead_actor_excluded_from_targeting"))
	runner.register_test("ko_death/actor_died_log_has_required_fields",     Callable(KODeathTests, "_t_actor_died_log_has_required_fields"))


# -------------------------
# Tests
# -------------------------

# Test 1: actor_ko_on_zero_hp
# Echo actor with current_hp=0.
# Expected: advance_turn() returns action_type="actor.dead" and sets is_dead=true on the actor dict.
static func _t_actor_ko_on_zero_hp() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_ko_001", "Kofi KO")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["current_hp"] = 0
	actor["grid_pos"]   = { "col": 0, "row": 0 }

	var sm      := ActorStateMachine.new(actor, IdleBehaviorModule.new())
	var logger  := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [actor], "t": 1 }

	var intent: Dictionary = sm.advance_turn(context, logger, 1)

	if str(intent.get("action_type", "")) != "actor.dead":
		return { "ok": false, "error": "Expected action_type='actor.dead', got: %s" % str(intent.get("action_type")) }

	if not bool(actor.get("is_dead", false)):
		return { "ok": false, "error": "Expected actor['is_dead']=true after KO, still false" }

	if int(actor.get("death_round", -1)) != 1:
		return { "ok": false, "error": "Expected death_round=1 (t), got: %s" % str(actor.get("death_round")) }

	return { "ok": true }


# Test 2: dead_actor_skips_module_on_next_turn
# Actor pre-flagged as is_dead=true (already died in a previous turn).
# Expected: advance_turn() returns actor.dead intent immediately — no actor.intent log event emitted.
static func _t_dead_actor_skips_module_on_next_turn() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_ko_002", "Ama Dead")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["current_hp"]  = 0
	actor["is_dead"]     = true
	actor["death_round"] = 1
	actor["grid_pos"]    = { "col": 0, "row": 0 }

	var sm      := ActorStateMachine.new(actor, IdleBehaviorModule.new())
	var logger  := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [actor], "t": 2 }

	var intent: Dictionary = sm.advance_turn(context, logger, 2)

	if str(intent.get("action_type", "")) != "actor.dead":
		return { "ok": false, "error": "Expected actor.dead on second call, got: %s" % str(intent.get("action_type")) }

	# Confirm no actor.intent event was logged (module was not invoked)
	var logs: Array = logger.get_logs()
	for entry in logs:
		if str(entry.get("type", "")) == "actor.intent":
			return { "ok": false, "error": "actor.intent log was emitted for an already-dead actor — module should have been skipped" }

	return { "ok": true }


# Test 3: dead_actor_excluded_from_targeting
# Ally at (0,0); dead enemy at (1,0) with is_dead=true.
# Expected: get_nearest_enemy() returns {} — dead actor is not a valid target.
static func _t_dead_actor_excluded_from_targeting() -> Dictionary:
	var ally := {
		"id":       "echo_ally",
		"faction":  "echo",
		"grid_pos": { "col": 0, "row": 0 },
	}
	var dead_enemy := {
		"id":       "enemy_dead_001",
		"faction":  "enemy",
		"is_dead":  true,
		"grid_pos": { "col": 1, "row": 0 },
	}

	var result: Dictionary = ActorService.get_nearest_enemy(ally, [dead_enemy])

	if not result.is_empty():
		return { "ok": false, "error": "Expected {} when only dead enemies exist, got id=%s" % str(result.get("id")) }

	return { "ok": true }


# Test 4: actor_died_log_has_required_fields
# Actor with current_hp=0 transitions to Dead.
# Expected: actor.died log event present with data containing actor_id (non-empty) and round_number (>= 0).
static func _t_actor_died_log_has_required_fields() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_ko_003", "Kwame Fallen")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["current_hp"] = 0
	actor["grid_pos"]   = { "col": 0, "row": 0 }

	var sm      := ActorStateMachine.new(actor, IdleBehaviorModule.new())
	var logger  := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [actor], "t": 5 }

	sm.advance_turn(context, logger, 5)

	var logs: Array = logger.get_logs()
	var died_event: Dictionary = {}
	for entry in logs:
		if str(entry.get("type", "")) == "actor.died" and died_event.is_empty():
			died_event = entry

	if died_event.is_empty():
		return { "ok": false, "error": "No actor.died log event found" }

	var ddata: Dictionary = died_event.get("data", {})

	if str(ddata.get("actor_id", "")).is_empty():
		return { "ok": false, "error": "actor.died: actor_id is empty" }
	if str(ddata.get("actor_id", "")) != "echo_ko_003":
		return { "ok": false, "error": "actor.died: expected actor_id='echo_ko_003', got: %s" % str(ddata.get("actor_id")) }
	if not ddata.has("round_number"):
		return { "ok": false, "error": "actor.died: missing round_number field" }
	if int(ddata.get("round_number", -1)) < 0:
		return { "ok": false, "error": "actor.died: round_number is negative, got: %s" % str(ddata.get("round_number")) }

	return { "ok": true }
