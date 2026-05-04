# res://tests/MoraleInfluenceTests.gd
# Tests for the ACTOR-007 Morale Influence layer:
#   1. broken_morale_idles_despite_adjacent_enemy
#      morale=10 → broken tier → morale_bonus: idle +15, melee −20.
#      Uncalled echo (melee base=40): idle(35) > melee(20) → idles.
#   2. morale_modifier_carried_in_intent
#      Warrior echo + broken morale + adjacent enemy → melee wins (45 > 25).
#      Intent dict carries morale_tier="broken" and morale_modifier=−20 (melee penalty at broken).
#   3. advance_turn_action_log_has_morale_fields
#      actor.action log entry includes "morale_tier" and "action_weight_modifier" with correct values.
#   4. snapshot_has_morale_tier_and_modifier
#      get_snapshot() after advance_turn() returns morale_tier and action_weight_modifier fields.
#
# All tests use BehaviorArbiter.new({}) (hardcoded defaults) — no file I/O.
# Tests use raw actor dicts — no full EchoActor schema needed for the arbiter.
# Morale defaults: actor.get("morale", 50) = 50 → "steady" → bonus = 0 for all other test suites.
# Run via Debug Panel: tests

extends RefCounted
class_name MoraleInfluenceTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("morale/broken_morale_idles_despite_adjacent_enemy",  Callable(MoraleInfluenceTests, "_t_broken_morale_idles_despite_adjacent_enemy"))
	runner.register_test("morale/morale_modifier_carried_in_intent",            Callable(MoraleInfluenceTests, "_t_morale_modifier_carried_in_intent"))
	runner.register_test("morale/advance_turn_action_log_has_morale_fields",    Callable(MoraleInfluenceTests, "_t_advance_turn_action_log_has_morale_fields"))
	runner.register_test("morale/snapshot_has_morale_tier_and_modifier",        Callable(MoraleInfluenceTests, "_t_snapshot_has_morale_tier_and_modifier"))


# -------------------------
# Tests
# -------------------------

# Test 1: broken_morale_guards_despite_adjacent_enemy
# Setup: uncalled echo, morale=10 (broken), fear=0, adjacent enemy at dist=1.
# Score check (hardcoded defaults, zeroed traits):
#   melee_attack: (base=40 + morale_bonus(−20)) × 1.0 = 20.0
#   actor.idle:   (base=20 + morale_bonus(+15)) × 1.0 = 35.0
#   actor.guard:  (base=25 + morale_bonus(+20)) × 1.0 = 45.0   ← wins (COMBAT-003)
# Expected: actor.guard wins — broken morale heavily favours a defensive stance.
# Demonstrates: morale_bonus is inside the pre-fear bracket and affects candidate ranking.
static func _t_broken_morale_idles_despite_adjacent_enemy() -> Dictionary:
	# onyamesu calling has guard base=55 — at broken morale (guard+20, melee-20) + echo_in_melee
	# guard: (55+20)×1.0 − 5 = 70; melee: (35−20)×1.0 + 18 = 33 → guard wins.
	var actor := {
		"id":             "echo_morale_001",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # broken tier (0–24)
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_morale_001",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	# onyamesu guard (70) > melee (33) > idle at broken morale + echo_in_melee.
	if str(intent.get("action_type", "")) != "actor.guard":
		return {
			"ok": false,
			"error": "Expected actor.guard (broken morale: guard=45 > idle=35 > melee=20), got: %s" % str(intent.get("action_type")),
		}

	return { "ok": true }


# Test 2: morale_modifier_carried_in_intent
# Setup: warrior echo, morale=10 (broken), fear=0, adjacent enemy at dist=1.
# Score check (warrior calling, zeroed traits):
#   melee_attack: (base=65 + 0 + 0 + morale_bonus(−20)) × 1.0 = 45.0
#   actor.idle:   (base=10 + 0 + 0 + morale_bonus(+15)) × 1.0 = 25.0
# Expected: melee_attack wins (warrior base strong enough to overcome broken penalty);
#   intent dict carries morale_tier="broken" and morale_modifier=−20.
# Demonstrates: morale metadata is attached to the winner regardless of which action wins.
static func _t_morale_modifier_carried_in_intent() -> Dictionary:
	var actor := {
		"id":             "echo_morale_002",
		"faction":        "echo",
		"calling_origin": "blade",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # broken tier (0–24)
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_morale_002",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy], "t": 2 }
	var intent: Dictionary = arbiter.select_intent(context)

	# Sanity-check: melee should win for the warrior even at broken morale.
	if str(intent.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "Expected melee_attack (warrior base=65 − 20 = 45 > idle 10+15=25), got: %s" % str(intent.get("action_type")),
		}

	# Verify morale metadata on the winner.
	if str(intent.get("morale_tier", "")) != "broken":
		return {
			"ok": false,
			"error": "Expected intent.morale_tier='broken', got: %s" % str(intent.get("morale_tier")),
		}
	if int(intent.get("morale_modifier", 999)) != -20:
		return {
			"ok": false,
			"error": "Expected intent.morale_modifier=−20 (melee penalty at broken), got: %s" % str(intent.get("morale_modifier")),
		}

	return { "ok": true }


# Test 3: advance_turn_action_log_has_morale_fields
# Setup: uncalled echo, morale=10 (broken), adjacent enemy → actor.guard wins (COMBAT-003).
# Expected: actor.action log entry has morale_tier="broken" and action_weight_modifier=20.
# Demonstrates: ActorStateMachine reads morale metadata from intent and writes it to the action log.
static func _t_advance_turn_action_log_has_morale_fields() -> Dictionary:
	# onyamesu calling: guard wins at broken morale (see test 1 score math).
	var actor := {
		"id":             "echo_morale_003",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # broken tier → guard morale_bonus = +20 → action_weight_modifier = 20
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_morale_003",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var sm := ActorStateMachine.new(actor, BehaviorArbiter.new({}))
	var logger := StructuredLogger.new()
	logger.set_level("debug")

	var context := { "actor": actor, "all_actors": [enemy], "t": 3 }
	sm.advance_turn(context, logger, 3)

	# Find the actor.action log entry.
	var logs: Array = logger.get_logs()
	var action_event: Dictionary = {}
	for entry in logs:
		if str(entry.get("type", "")) == "actor.action" and action_event.is_empty():
			action_event = entry

	if action_event.is_empty():
		return { "ok": false, "error": "No actor.action log event found" }

	var adata: Dictionary = action_event.get("data", {})

	if not adata.has("morale_tier"):
		return { "ok": false, "error": "actor.action data missing 'morale_tier' key" }
	if str(adata.get("morale_tier", "")) != "broken":
		return {
			"ok": false,
			"error": "actor.action morale_tier expected 'broken', got: %s" % str(adata.get("morale_tier")),
		}

	if not adata.has("action_weight_modifier"):
		return { "ok": false, "error": "actor.action data missing 'action_weight_modifier' key" }
	# COMBAT-003: guard wins at broken: actor.guard morale_bonus = +20, so action_weight_modifier = 20.
	if int(adata.get("action_weight_modifier", -999)) != 20:
		return {
			"ok": false,
			"error": "actor.action action_weight_modifier expected 20 (guard bonus at broken), got: %s" % str(adata.get("action_weight_modifier")),
		}

	return { "ok": true }


# Test 4: snapshot_has_morale_tier_and_modifier
# Setup: uncalled echo, morale=10 (broken), adjacent enemy → actor.guard wins (COMBAT-003).
# Expected: get_snapshot() after advance_turn() returns morale_tier="broken" and action_weight_modifier=20.
# Demonstrates: ActorStateMachine exposes morale fields in the debug snapshot.
static func _t_snapshot_has_morale_tier_and_modifier() -> Dictionary:
	# onyamesu calling: guard wins at broken morale (see test 1 score math).
	var actor := {
		"id":             "echo_morale_004",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # broken tier → guard wins → action_weight_modifier = 20
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_morale_004",
		"faction":  "enemy",
		"grid_pos": { "col": 1, "row": 0 },
	}

	var sm := ActorStateMachine.new(actor, BehaviorArbiter.new({}))
	var logger := StructuredLogger.new()
	logger.set_level("debug")

	var context := { "actor": actor, "all_actors": [enemy], "t": 4 }
	sm.advance_turn(context, logger, 4)

	var snapshot: Dictionary = sm.get_snapshot()

	if not snapshot.has("morale_tier"):
		return { "ok": false, "error": "get_snapshot() missing 'morale_tier' key" }
	if str(snapshot.get("morale_tier", "")) != "broken":
		return {
			"ok": false,
			"error": "snapshot.morale_tier expected 'broken', got: %s" % str(snapshot.get("morale_tier")),
		}

	if not snapshot.has("action_weight_modifier"):
		return { "ok": false, "error": "get_snapshot() missing 'action_weight_modifier' key" }
	# COMBAT-003: guard wins at broken: actor.guard morale_bonus = +20, so action_weight_modifier = 20.
	if int(snapshot.get("action_weight_modifier", -999)) != 20:
		return {
			"ok": false,
			"error": "snapshot.action_weight_modifier expected 20 (guard bonus at broken), got: %s" % str(snapshot.get("action_weight_modifier")),
		}

	return { "ok": true }
