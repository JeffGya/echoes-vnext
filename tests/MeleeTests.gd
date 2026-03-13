# res://tests/MeleeTests.gd
# Tests for the ACTOR-004 melee behavior system:
#   1. get_nearest_enemy() returns the closest enemy when multiple are present.
#   2. get_nearest_enemy() tiebreak: lexicographically smallest actor_id wins.
#   3. select_intent() returns idle when the nearest enemy is at distance 2.
#   4. advance_turn() fires both actor.intent and actor.action log events
#      with correct fields when a melee attack resolves.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name MeleeTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("melee/get_nearest_enemy_returns_closest",         Callable(MeleeTests, "_t_get_nearest_enemy_returns_closest"))
	runner.register_test("melee/get_nearest_enemy_tiebreak_by_id",          Callable(MeleeTests, "_t_get_nearest_enemy_tiebreak_by_id"))
	runner.register_test("melee/select_intent_idle_when_enemy_at_dist_2",   Callable(MeleeTests, "_t_select_intent_idle_when_enemy_at_dist_2"))
	runner.register_test("melee/advance_turn_logs_actor_action_events",      Callable(MeleeTests, "_t_advance_turn_logs_actor_action_events"))


# -------------------------
# Tests
# -------------------------

# Test 1: get_nearest_enemy_returns_closest
# Actor at (0,0); enemy A at (1,0) dist=1; enemy B at (2,0) dist=2.
# Expected: enemy A returned.
static func _t_get_nearest_enemy_returns_closest() -> Dictionary:
	var actor   := { "id": "echo_001", "faction": "echo",  "grid_pos": { "col": 0, "row": 0 } }
	var enemy_a := { "id": "enemy_A",  "faction": "enemy", "grid_pos": { "col": 1, "row": 0 } }
	var enemy_b := { "id": "enemy_B",  "faction": "enemy", "grid_pos": { "col": 2, "row": 0 } }

	var result: Dictionary = ActorService.get_nearest_enemy(actor, [enemy_a, enemy_b])

	if result.is_empty():
		return { "ok": false, "error": "Expected a target, got {}" }
	if str(result.get("id", "")) != "enemy_A":
		return { "ok": false, "error": "Expected enemy_A (dist=1), got: %s" % str(result.get("id")) }

	return { "ok": true }


# Test 2: get_nearest_enemy_tiebreak_by_id
# Actor at (0,0); enemy_Z at (1,0) dist=1; enemy_A at (0,1) dist=1.
# Both equidistant — expected: enemy_A wins ("enemy_A" < "enemy_Z").
static func _t_get_nearest_enemy_tiebreak_by_id() -> Dictionary:
	var actor   := { "id": "echo_001", "faction": "echo",  "grid_pos": { "col": 0, "row": 0 } }
	var enemy_z := { "id": "enemy_Z",  "faction": "enemy", "grid_pos": { "col": 1, "row": 0 } }
	var enemy_a := { "id": "enemy_A",  "faction": "enemy", "grid_pos": { "col": 0, "row": 1 } }

	var result: Dictionary = ActorService.get_nearest_enemy(actor, [enemy_z, enemy_a])

	if result.is_empty():
		return { "ok": false, "error": "Expected a target, got {}" }
	if str(result.get("id", "")) != "enemy_A":
		return { "ok": false, "error": "Expected enemy_A (tiebreak by id), got: %s" % str(result.get("id")) }

	return { "ok": true }


# Test 3: select_intent_idle_when_enemy_at_dist_2
# Actor at (0,0); enemy at (2,0) dist=2 — outside melee range.
# Expected: idle intent returned.
static func _t_select_intent_idle_when_enemy_at_dist_2() -> Dictionary:
	var actor := { "id": "echo_001", "faction": "echo",  "grid_pos": { "col": 0, "row": 0 } }
	var enemy := { "id": "enemy_001", "faction": "enemy", "grid_pos": { "col": 2, "row": 0 } }

	var module := MeleeBehaviorModule.new()
	var context := { "actor": actor, "all_actors": [enemy], "t": 1 }
	var intent: Dictionary = module.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.idle":
		return { "ok": false, "error": "Expected actor.idle at dist=2, got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 4: advance_turn_logs_actor_action_events
# Echo at (0,0), enemy at (1,0) dist=1.
# Expected: actor.intent log event with module_id="melee" and action_type="melee_attack".
# Expected: actor.action log event with action_type="melee_attack", source_id=echo id, target_id=enemy id, damage=0.
static func _t_advance_turn_logs_actor_action_events() -> Dictionary:
	# Build a full echo actor via EchoActor (passes ActorSchema.validate)
	var echo := ActorTests._make_test_echo("echo_0010", "Ama Boateng")
	var actor: Dictionary = EchoActor.from_echo(echo)
	# Override grid_pos to trigger adjacency with enemy
	actor["grid_pos"] = { "col": 0, "row": 0 }

	var enemy := {
		"id":       "enemy_001",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var sm := ActorStateMachine.new(actor, MeleeBehaviorModule.new())
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var context := { "actor": actor, "all_actors": [enemy], "t": 10 }
	var intent: Dictionary = sm.advance_turn(context, logger, 10)

	# Verify returned intent is a melee_attack
	if str(intent.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "Expected melee_attack intent, got: %s" % str(intent.get("action_type")) }
	if str(intent.get("target_id", "")) != "enemy_001":
		return { "ok": false, "error": "Expected target_id='enemy_001', got: %s" % str(intent.get("target_id")) }

	var logs: Array = logger.get_logs()

	# Find actor.intent log event
	var intent_event: Dictionary = {}
	var action_event: Dictionary = {}
	for entry in logs:
		var etype := str(entry.get("type", ""))
		if etype == "actor.intent" and intent_event.is_empty():
			intent_event = entry
		elif etype == "actor.action" and action_event.is_empty():
			action_event = entry

	if intent_event.is_empty():
		return { "ok": false, "error": "No actor.intent log event found" }
	var idata: Dictionary = intent_event.get("data", {})
	if str(idata.get("module_id", "")) != "melee":
		return { "ok": false, "error": "actor.intent: expected module_id='melee', got: %s" % str(idata.get("module_id")) }
	if str(idata.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "actor.intent: expected action_type='melee_attack', got: %s" % str(idata.get("action_type")) }

	if action_event.is_empty():
		return { "ok": false, "error": "No actor.action log event found" }
	var adata: Dictionary = action_event.get("data", {})
	if str(adata.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "actor.action: expected action_type='melee_attack', got: %s" % str(adata.get("action_type")) }
	if str(adata.get("source_id", "")) != "echo_0010":
		return { "ok": false, "error": "actor.action: expected source_id='echo_0010', got: %s" % str(adata.get("source_id")) }
	if str(adata.get("target_id", "")) != "enemy_001":
		return { "ok": false, "error": "actor.action: expected target_id='enemy_001', got: %s" % str(adata.get("target_id")) }
	if int(adata.get("damage", -1)) != 0:
		return { "ok": false, "error": "actor.action: expected damage=0 (placeholder), got: %s" % str(adata.get("damage")) }

	return { "ok": true }
