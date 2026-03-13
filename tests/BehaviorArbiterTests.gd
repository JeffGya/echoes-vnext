# res://tests/BehaviorArbiterTests.gd
# Tests for the ACTOR-005 behavior arbitration engine:
#   1. Guardian calling_origin prefers protect_ally over melee_attack
#      (base 65 > 20 even with same traits).
#   2. A warrior with high faith can guard — trait override of role
#      (protect_ally 10 + faith_bonus 35 = 45 > idle 13.5 with no adjacent enemy).
#   3. High fear idles despite an adjacent enemy
#      (fear=100 dampens melee × 0.40 → melee score < idle score).
#   4. advance_turn() fires both actor.intent (module_id="arbiter") and actor.action
#      log events with correct fields.
#
# Tests 1-3 use raw actor/enemy dicts — no full schema needed for BehaviorArbiter.
# Test 4 uses EchoActor.from_echo() for a valid full-flow test.
# All tests inject BehaviorArbiter.new({}) explicitly — no file I/O, hardcoded defaults.
# Run via Debug Panel: tests

extends RefCounted
class_name BehaviorArbiterTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("arbiter/guardian_origin_prefers_protect_ally",       Callable(BehaviorArbiterTests, "_t_guardian_origin_prefers_protect_ally"))
	runner.register_test("arbiter/high_faith_warrior_can_guard",               Callable(BehaviorArbiterTests, "_t_high_faith_warrior_can_guard"))
	runner.register_test("arbiter/high_fear_idles_despite_adjacent_enemy",     Callable(BehaviorArbiterTests, "_t_high_fear_idles_despite_adjacent_enemy"))
	runner.register_test("arbiter/advance_turn_logs_arbiter_intent_and_action", Callable(BehaviorArbiterTests, "_t_advance_turn_logs_arbiter_intent_and_action"))


# -------------------------
# Tests
# -------------------------

# Test 1: guardian_origin_prefers_protect_ally
# Setup: guardian echo at (0,0), enemy at (1,0) dist=1, threatened ally present.
# Expected: protect_ally wins (guardian base=65 vs melee base=20).
# Demonstrates: calling_origin gives a strong natural tendency that other echoes must work hard to override.
static func _t_guardian_origin_prefers_protect_ally() -> Dictionary:
	var actor := {
		"id":             "echo_001",
		"faction":        "echo",
		"calling_origin": "guardian",
		"traits":         { "courage": 55, "wisdom": 42, "faith": 38 },
		"vector_scores":  {},
		"fear":           0,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_001",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}
	# Threatened ally: same faction, current_hp at 40% of max_hp (below 0.5 threshold)
	var ally := {
		"id":         "echo_002",
		"faction":    "echo",
		"current_hp": 40,
		"stats":      { "max_hp": 100 },
		"grid_pos":   { "col": 2, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy, ally], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "protect_ally":
		return { "ok": false, "error": "Expected protect_ally (guardian base=65), got: %s" % str(intent.get("action_type")) }
	if str(intent.get("target_id", "")) != "echo_002":
		return { "ok": false, "error": "Expected target_id='echo_002', got: %s" % str(intent.get("target_id")) }
	if str(intent.get("protected_actor_id", "")) != "echo_002":
		return { "ok": false, "error": "Expected protected_actor_id='echo_002', got: %s" % str(intent.get("protected_actor_id")) }

	return { "ok": true }


# Test 2: high_faith_warrior_can_guard
# Setup: warrior echo, faith=70, no adjacent enemy, threatened ally present.
# Expected: protect_ally wins (base=10 + faith_bonus=35 = 45) over idle (base=10 + 3.5 = 13.5).
# Demonstrates: traits can override calling_origin — any echo can guard given the right build.
# The warrior has low protect_ally base (10), but faith lifts the score above idle.
static func _t_high_faith_warrior_can_guard() -> Dictionary:
	var actor := {
		"id":             "echo_003",
		"faction":        "echo",
		"calling_origin": "warrior",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 70 },
		"vector_scores":  {},
		"fear":           0,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	# Enemy at dist=2 — NOT adjacent, so melee_attack is not a candidate.
	var enemy := {
		"id":       "enemy_001",
		"faction":  "enemy",
		"grid_pos": { "col": 2, "row": 0 },
	}
	# Threatened ally: below 50% HP threshold.
	var ally := {
		"id":         "echo_004",
		"faction":    "echo",
		"current_hp": 30,
		"stats":      { "max_hp": 100 },
		"grid_pos":   { "col": 1, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy, ally], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "protect_ally":
		return { "ok": false, "error": "Expected protect_ally (faith=70 bonus lifts warrior above idle), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 3: high_fear_idles_despite_adjacent_enemy
# Setup: echo at (0,0), fear=100, enemy at (1,0) dist=1. No threatened ally.
# Expected: actor.idle wins.
# Score check with uncalled defaults, zeroed traits:
#   melee: (base=40) × fear_factor(clamp(1−1.0×0.6)=0.40) = 16.0
#   idle:  (base=20) × 1.0 (passive, no fear dampen) = 20.0
# Demonstrates: fear dampens active intents — idle always remains the safe fallback.
static func _t_high_fear_idles_despite_adjacent_enemy() -> Dictionary:
	var actor := {
		"id":             "echo_005",
		"faction":        "echo",
		"calling_origin": "uncalled",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           100,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_001",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.idle":
		return { "ok": false, "error": "Expected actor.idle at fear=100 (melee dampened to 16 < idle 20), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 4: advance_turn_logs_arbiter_intent_and_action
# Setup: full echo via EchoActor.from_echo() + ActorStateMachine (no explicit module).
# Expected: actor.intent log has module_id="arbiter"; actor.action fires with correct fields.
# Demonstrates: full flow integration — arbiter is wired as default module for echo actors.
static func _t_advance_turn_logs_arbiter_intent_and_action() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_0020", "Akua Asante")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["grid_pos"] = { "col": 0, "row": 0 }  # place echo on grid

	# Enemy at dist=1 — melee_attack will be the winning intent (uncalled default, no fear).
	var enemy := {
		"id":       "enemy_020",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	# ActorStateMachine without explicit module → defaults to BehaviorArbiter for echo actors.
	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var context := { "actor": actor, "all_actors": [enemy], "t": 20 }
	var intent: Dictionary = sm.advance_turn(context, logger, 20)

	# The arbiter should select melee_attack (uncalled base=40 + traits > idle base=20).
	if str(intent.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "Expected melee_attack intent from arbiter, got: %s" % str(intent.get("action_type")) }

	var logs: Array = logger.get_logs()
	var intent_event: Dictionary = {}
	var action_event: Dictionary = {}
	for entry in logs:
		var etype := str(entry.get("type", ""))
		if etype == "actor.intent" and intent_event.is_empty():
			intent_event = entry
		elif etype == "actor.action" and action_event.is_empty():
			action_event = entry

	# Verify actor.intent log
	if intent_event.is_empty():
		return { "ok": false, "error": "No actor.intent log event found" }
	var idata: Dictionary = intent_event.get("data", {})
	if str(idata.get("module_id", "")) != "arbiter":
		return { "ok": false, "error": "actor.intent: expected module_id='arbiter', got: %s" % str(idata.get("module_id")) }
	if str(idata.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "actor.intent: expected action_type='melee_attack', got: %s" % str(idata.get("action_type")) }
	if str(idata.get("actor_id", "")) != "echo_0020":
		return { "ok": false, "error": "actor.intent: expected actor_id='echo_0020', got: %s" % str(idata.get("actor_id")) }

	# Verify actor.action log
	if action_event.is_empty():
		return { "ok": false, "error": "No actor.action log event found" }
	var adata: Dictionary = action_event.get("data", {})
	if str(adata.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "actor.action: expected action_type='melee_attack', got: %s" % str(adata.get("action_type")) }
	if str(adata.get("source_id", "")) != "echo_0020":
		return { "ok": false, "error": "actor.action: expected source_id='echo_0020', got: %s" % str(adata.get("source_id")) }
	if str(adata.get("target_id", "")) != "enemy_020":
		return { "ok": false, "error": "actor.action: expected target_id='enemy_020', got: %s" % str(adata.get("target_id")) }
	if int(adata.get("damage", -1)) != 0:
		return { "ok": false, "error": "actor.action: expected damage=0 (placeholder), got: %s" % str(adata.get("damage")) }

	return { "ok": true }
