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
	runner.register_test("situational/own_hp_low_prefers_guard",               Callable(BehaviorArbiterTests, "_t_own_hp_low_prefers_guard"))
	runner.register_test("situational/last_echo_standing_guards",              Callable(BehaviorArbiterTests, "_t_last_echo_standing_guards"))
	runner.register_test("situational/enemy_type_is_aggressive",               Callable(BehaviorArbiterTests, "_t_enemy_type_is_aggressive"))
	runner.register_test("situational/overwhelming_advantage_pushes_move",     Callable(BehaviorArbiterTests, "_t_overwhelming_advantage_pushes_move"))
	# V2-PROG-002: confirmed calling drives behavior, not birth origin
	runner.register_test("arbiter/confirmed_calling_overrides_birth_origin",  Callable(BehaviorArbiterTests, "_t_confirmed_calling_overrides_birth_origin"))


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
		"calling_origin": "okofor",   # V2 name for warder (protect_ally base=65)
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
		return { "ok": false, "error": "Expected protect_ally (okofor base=65), got: %s" % str(intent.get("action_type")) }
	if str(intent.get("target_id", "")) != "echo_002":
		return { "ok": false, "error": "Expected target_id='echo_002', got: %s" % str(intent.get("target_id")) }
	if str(intent.get("protected_actor_id", "")) != "echo_002":
		return { "ok": false, "error": "Expected protected_actor_id='echo_002', got: %s" % str(intent.get("protected_actor_id")) }

	return { "ok": true }


# Test 2: high_faith_warrior_can_guard
# Setup: warrior echo, faith=70, protector vector=80, enemy at dist=2, threatened ally present.
# Expected: protect_ally wins over actor.move + actor.guard.
# Score breakdown (warrior defaults, faith=70, protector=80, courage=0):
#   protect_ally: 10 + faith*0.50(=35) + protector*0.45(=36) = 81
#   actor.guard:  15 + faith*0.30(=21) + protector*0.50(=40) = 76
#   actor.move:   55 + faith*0.00(=0)  + protector*0.05(=4)  = 59
# Demonstrates: high faith + protector vector can pull a warrior away from advancing
# toward the enemy, in favour of protecting a threatened ally.
static func _t_high_faith_warrior_can_guard() -> Dictionary:
	var actor := {
		"id":             "echo_003",
		"faction":        "echo",
		"calling_origin": "aduro",   # V2 name for blade (melee base=65, move=55)
		"traits":         { "courage": 0, "wisdom": 0, "faith": 70 },
		"vector_scores":  { "protector": 80 },
		"fear":           0,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	# Enemy at dist=2 — NOT adjacent, so melee_attack is not a candidate; actor.move is.
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
		return { "ok": false, "error": "Expected protect_ally (faith=70 + protector=80 lifts warrior above actor.move), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 3: high_fear_guards_despite_adjacent_enemy
# Setup: echo at (0,0), fear=100, enemy at (1,0) dist=1. No threatened ally.
# Expected: actor.guard wins (highest passive score).
# Score check with uncalled defaults, zeroed traits:
#   melee:  (base=40) × fear_factor(clamp(1−1.0×0.6)=0.40) = 16.0
#   idle:   (base=20) × 1.0 (passive, no fear dampen) = 20.0
#   guard:  (base=25) × 1.0 (passive, in fear_passive_actions) = 25.0
# Demonstrates: fear dampens active intents — guard is the preferred passive action (COMBAT-003).
static func _t_high_fear_idles_despite_adjacent_enemy() -> Dictionary:
	# onyamesu calling: guard base=55. At fear=100 (dampen=0.45, factor=0.55) + echo_in_melee:
	# guard: 55×1.0 − 5 = 50; melee: 35×0.55 + 18 = 37.25 → guard wins.
	var actor := {
		"id":             "echo_005",
		"faction":        "echo",
		"calling_origin": "onyamesu",
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

	# onyamesu guard (50) > melee (37.25) at fear=100 + echo_in_melee.
	if str(intent.get("action_type", "")) != "actor.guard":
		return { "ok": false, "error": "Expected actor.guard at fear=100 (onyamesu guard=50 > melee=37), got: %s" % str(intent.get("action_type")) }

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
	logger.set_level("debug")

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


# -------------------------
# Situational modifier tests (ACTOR-SIT)
# -------------------------

# Test 5: own_hp_low_prefers_guard
# Setup: uncalled echo at 25% HP (own_hp_low fires), enemy at dist=2 (actor.move candidate, within guard_range),
#        no allies, no dead allies (last_echo_standing does NOT fire).
# Score breakdown (uncalled, no traits/vectors, own_hp_low active):
#   actor.guard: base(25) + own_hp_low(+12) = 37   ← winner
#   actor.move:  base(35) + own_hp_low(-5)  = 30
#   actor.idle:  base(20) + own_hp_low(+8)  = 28
# Demonstrates: situational HP condition overrides personality-based aggression.
static func _t_own_hp_low_prefers_guard() -> Dictionary:
	# onyamesu calling, enemy adjacent (dist=1) so guard is a candidate (guard_range=1).
	# own_hp_low fires (hp_ratio=0.25 < 0.35 threshold).
	# guard: 55 + own_hp_low(12) − echo_in_melee(5) = 62;
	# melee: 35 + own_hp_low(-8) + echo_in_melee(18) = 45 → guard wins.
	var actor := {
		"id":             "echo_sit_001",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     25,
		"stats":          { "max_hp": 100 },
	}
	var enemy := {
		"id":       "enemy_sit_001",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },  # adjacent — guard_range=1 satisfied
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.guard":
		return { "ok": false, "error": "Expected actor.guard at 25%% HP (onyamesu guard=62 > melee=45), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 6: last_echo_standing_guards
# Setup: uncalled echo, 1 dead ally (is_dead=true), adjacent enemy (dist=1).
#        last_echo_standing fires (living_allies=0, dead_allies=1).
# Score breakdown (uncalled, no traits/vectors, last_echo_standing active):
#   actor.guard:   base(25) + last_echo_standing(+20) = 45   ← winner
#   actor.idle:    base(20) + last_echo_standing(+15) = 35
#   melee_attack:  base(40) + last_echo_standing(-15) = 25
# Demonstrates: final-survivor condition pushes even an uncalled echo to defend.
static func _t_last_echo_standing_guards() -> Dictionary:
	# onyamesu calling: guard base=55.
	# last_echo_standing: guard+20, melee-15; echo_in_melee: melee+18, guard-5.
	# guard: 55 + 20 - 5 = 70; melee: (35-15) + 18 = 38 → guard wins.
	var actor := {
		"id":             "echo_sit_002",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var dead_ally := {
		"id":      "echo_dead_001",
		"faction": "echo",
		"is_dead": true,
		"grid_pos": { "col": 2, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_sit_002",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [dead_ally, enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.guard":
		return { "ok": false, "error": "Expected actor.guard when last echo standing (onyamesu guard=70 > melee=38), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# Test 7: enemy_type_is_aggressive
# Setup: enemy actor (actor_type="enemy", calling_origin="enemy"), adjacent echo (dist=1).
#        enemy_engaged fires (enemy type + dist=1).
# Score breakdown (enemy calling, no traits/vectors, enemy_engaged active):
#   melee_attack: base(70) + enemy_engaged(+15) = 85   ← winner
#   actor.guard:  base(10) + enemy_engaged(-8)  =  2
#   actor.idle:   base(5)  + enemy_engaged(-10) = -5
# Demonstrates: enemy calling_origin + situational pressure produce decisive aggression.
static func _t_enemy_type_is_aggressive() -> Dictionary:
	var actor := {
		"id":             "enemy_sit_003",
		"faction":        "enemy",
		"calling_origin": "enemy",
		"actor_type":     "enemy",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 1, "row": 0 },
	}
	var echo_target := {
		"id":       "echo_sit_003",
		"faction":  "echo",
		"is_dead":  false,
		"grid_pos": { "col": 0, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [echo_target], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "Expected melee_attack from enemy actor (melee=85 >> guard=2), got: %s" % str(intent.get("action_type")) }
	if str(intent.get("target_id", "")) != "echo_sit_003":
		return { "ok": false, "error": "Expected target_id='echo_sit_003', got: %s" % str(intent.get("target_id")) }

	return { "ok": true }


# Test 8: overwhelming_advantage_pushes_move
# Setup: uncalled echo, 4 living allies vs 2 enemies, nearest enemy at dist=2.
#        overwhelming_advantage fires (living_allies=4 >= living_enemies=2 × 2).
# Score breakdown (uncalled, no traits/vectors, overwhelming_advantage active):
#   actor.move:  base(35) + overwhelming_advantage(+8)  = 43   ← winner
#   actor.guard: base(25) + overwhelming_advantage(-5)  = 20
#   actor.idle:  base(20) + overwhelming_advantage(-6)  = 14
# Demonstrates: numerical superiority pushes even neutral actors to advance.
static func _t_overwhelming_advantage_pushes_move() -> Dictionary:
	var actor := {
		"id":             "echo_sit_004",
		"faction":        "echo",
		"calling_origin": "uncalled",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	# 4 living allies (living_allies=4)
	var allies: Array = []
	for i in range(4):
		allies.append({
			"id":      "echo_ally_%d" % i,
			"faction": "echo",
			"is_dead": false,
			"grid_pos": { "col": i + 1, "row": 1 },
		})
	# 2 living enemies — nearest at dist=2
	var enemies: Array = [
		{ "id": "enemy_sit_004a", "faction": "enemy", "is_dead": false, "grid_pos": { "col": 2, "row": 0 } },
		{ "id": "enemy_sit_004b", "faction": "enemy", "is_dead": false, "grid_pos": { "col": 3, "row": 0 } },
	]
	var all_actors: Array = allies + enemies

	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": all_actors, "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected actor.move when overwhelming (move=43 > guard=20 > idle=14), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# -------------------------
# V2-PROG-002: Calling seam tests
# -------------------------

# Test 9: confirmed_calling_overrides_birth_origin
# Setup: echo with calling_origin="warder" (protect_ally base=65) but calling="blade" (melee base=65).
# Enemy adjacent at (1,0). Threatened ally at (2,0) with HP=40/100.
# Without seam fix: warder birth origin → protect_ally=65 would win.
# With seam fix: confirmed blade → melee_attack=65, protect_ally=10 → melee_attack wins.
# Expected: melee_attack (confirmed calling drives behavior).
static func _t_confirmed_calling_overrides_birth_origin() -> Dictionary:
	var actor := {
		"id":             "echo_seam_001",
		"faction":        "echo",
		"calling_origin": "okofor",  # V2 birth origin (warder) — protect_ally=65 if unchecked
		"calling":        "aduro",   # V2 confirmed calling (blade) — melee=65 drives behavior
		"actor_type":     "echo",
		"traits":         { "courage": 55, "wisdom": 42, "faith": 38 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
	}
	var enemy := {
		"id":       "enemy_seam_001",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },
	}
	var ally := {
		"id":         "echo_seam_002",
		"faction":    "echo",
		"is_dead":    false,
		"current_hp": 40,
		"stats":      { "max_hp": 100 },
		"grid_pos":   { "col": 2, "row": 0 },
	}
	var arbiter := BehaviorArbiter.new({})
	var context := { "actor": actor, "all_actors": [actor, enemy, ally], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(context)
	if str(intent.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "Confirmed aduro (melee=65) should win over okofor birth origin (protect_ally=65). Got: %s" % str(intent.get("action_type")),
		}
	return { "ok": true }
