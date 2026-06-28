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
	# COMBAT-BUG-001: purifier shrine pathing fixes
	runner.register_test("arbiter/purifier_moves_toward_shrine_not_enemy",    Callable(BehaviorArbiterTests, "_t_purifier_moves_toward_shrine_not_enemy"))
	runner.register_test("arbiter/purifier_purifies_when_adjacent_to_shrine", Callable(BehaviorArbiterTests, "_t_purifier_purifies_when_adjacent_to_shrine"))
	runner.register_test("arbiter/purifier_no_purify_when_on_cooldown",       Callable(BehaviorArbiterTests, "_t_purifier_no_purify_when_on_cooldown"))
	runner.register_test("arbiter/purifier_attacks_enemy_when_adjacent",      Callable(BehaviorArbiterTests, "_t_purifier_attacks_enemy_when_adjacent"))
	# COMBAT-BUG-002: guard deadlock fix
	runner.register_test("arbiter/repeated_guard_breaks_to_melee",            Callable(BehaviorArbiterTests, "_t_repeated_guard_breaks_to_melee"))
	# §5-A: RECOVER holder adjacent to relic gets objective_in_range (move down-weighted)
	runner.register_test("arbiter/recover_holder_adjacent_relic_digs_in",     Callable(BehaviorArbiterTests, "_t_recover_holder_adjacent_relic_digs_in"))
	# §5-B/C: PROTECT echo intercepts totem's nearest attacker
	runner.register_test("arbiter/protect_echo_intercepts_totem_attacker",    Callable(BehaviorArbiterTests, "_t_protect_echo_intercepts_totem_attacker"))
	# §5-C: PROTECT stolen → echo focus-fires carrier id
	runner.register_test("arbiter/protect_echo_focus_fires_carrier",          Callable(BehaviorArbiterTests, "_t_protect_echo_focus_fires_carrier"))
	runner.register_test("arbiter/pursue_flee_module_moves_toward_edge",
		Callable(BehaviorArbiterTests, "_t_pursue_flee_module_moves_toward_edge"))
	runner.register_test("behavior_arbiter/pursue_flee_module_targets_inset_border",
		Callable(BehaviorArbiterTests, "_t_pursue_flee_module_targets_inset_border"))
	runner.register_test("arbiter/pursue_echo_quarry_near_exit_fires",
		Callable(BehaviorArbiterTests, "_t_pursue_echo_quarry_near_exit_fires"))


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


# -------------------------
# COMBAT-BUG-001: Purifier shrine pathing tests
# -------------------------

# Test A1: purifier_moves_shrine_hp_aware
# Shrine HP gates the purifier's movement redirect.
#
# Part A: shrine HP < 50% AND purifier not adjacent → move toward shrine.
#   The purifier must return to the shrine to purify.
#
# Part B: shrine HP ≥ 50% AND purifier not adjacent → move toward enemy.
#   Shrine is healthy; purifier should intercept the enemy instead.
#   Without this gate the purifier oscillates: one step toward enemy takes it 2 tiles
#   from shrine → redirect fires → one step back → adjacent again → redirect off → repeat.
static func _t_purifier_moves_toward_shrine_not_enemy() -> Dictionary:
	# --- Part A: shrine below 50% — redirect to shrine ---
	var purifier_a := {
		"id":             "echo_pur_001a",
		"faction":        "echo",
		"calling_origin": "okofor",
		"actor_type":     "echo",
		"traits":         { "courage": 40, "wisdom": 30, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"purify_cooldown": 2,
	}
	var shrine_a := {
		"id": "shrine_001", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 40, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 9, "row": 9 },
	}
	var enemy_a := {
		"id": "enemy_pur_001a", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 5, "row": 5 },
	}
	var intent_a: Dictionary = BehaviorArbiter.new({}).select_intent({
		"actor": purifier_a, "all_actors": [purifier_a, shrine_a, enemy_a],
		"t": 1, "is_purifier": true, "shrine_alive": true, "shrine_hp_ratio": 0.40,
	})
	if str(intent_a.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Part A: expected actor.move toward shrine (HP=40%%), got: %s" % str(intent_a.get("action_type")) }
	var tpos_a: Dictionary = intent_a.get("target_pos", {})
	if int(tpos_a.get("col", -1)) != 9 or int(tpos_a.get("row", -1)) != 9:
		return { "ok": false, "error": "Part A: expected target shrine {col:9,row:9}, got: %s" % str(tpos_a) }

	# --- Part B: shrine above 50% — pursue enemy, no oscillation ---
	var purifier_b := {
		"id":             "echo_pur_001b",
		"faction":        "echo",
		"calling_origin": "okofor",
		"actor_type":     "echo",
		"traits":         { "courage": 40, "wisdom": 30, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"purify_cooldown": 2,
	}
	var shrine_b := {
		"id": "shrine_001", "faction": "structure",
		"is_structure": true, "is_dead": false,
		"current_hp": 80, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 9, "row": 9 },
	}
	var enemy_b := {
		"id": "enemy_pur_001b", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 5, "row": 5 },
	}
	var intent_b: Dictionary = BehaviorArbiter.new({}).select_intent({
		"actor": purifier_b, "all_actors": [purifier_b, shrine_b, enemy_b],
		"t": 1, "is_purifier": true, "shrine_alive": true, "shrine_hp_ratio": 0.80,
	})
	if str(intent_b.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Part B: expected actor.move toward enemy (HP=80%%), got: %s" % str(intent_b.get("action_type")) }
	var tpos_b: Dictionary = intent_b.get("target_pos", {})
	if int(tpos_b.get("col", -1)) != 5 or int(tpos_b.get("row", -1)) != 5:
		return { "ok": false, "error": "Part B: expected target enemy {col:5,row:5} not shrine, got: %s" % str(tpos_b) }

	return { "ok": true }


# Test A2: purifier_purifies_when_adjacent_and_shrine_below_50pct
# The HP gate is intentional: purify only fires when shrine HP < 50%.
# At full/healthy HP the purifier should be intercepting the enemy, not purifying.
#
# Part A: shrine at 40% HP → purify fires (adjacent, cooldown=0, HP below threshold).
# Part B: shrine at 80% HP → purify does NOT fire (HP above threshold despite adjacency).
static func _t_purifier_purifies_when_adjacent_to_shrine() -> Dictionary:
	# --- Part A: shrine below 50% — purify fires ---
	var purifier_a := {
		"id":             "echo_pur_002a",
		"faction":        "echo",
		"calling_origin": "okofor",
		"actor_type":     "echo",
		"traits":         { "courage": 40, "wisdom": 30, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 4, "row": 4 },
		"purify_cooldown": 0,
	}
	var shrine_a := {
		"id":           "shrine_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"current_hp":   40,
		"stats":        { "max_hp": 100 },
		"grid_pos":     { "col": 5, "row": 5 },
	}
	var enemy_a := {
		"id": "enemy_pur_002a", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 0, "row": 0 },
	}
	var intent_a: Dictionary = BehaviorArbiter.new({}).select_intent({
		"actor": purifier_a, "all_actors": [purifier_a, shrine_a, enemy_a],
		"t": 1, "is_purifier": true, "shrine_alive": true, "shrine_hp_ratio": 0.40,
	})
	if str(intent_a.get("action_type", "")) != "actor.purify_shrine":
		return { "ok": false, "error": "Expected actor.purify_shrine at shrine HP=40%%, got: %s" % str(intent_a.get("action_type")) }

	# --- Part B: shrine above 50% — purify must NOT fire ---
	var purifier_b := {
		"id":             "echo_pur_002b",
		"faction":        "echo",
		"calling_origin": "okofor",
		"actor_type":     "echo",
		"traits":         { "courage": 40, "wisdom": 30, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 4, "row": 4 },
		"purify_cooldown": 0,
	}
	var shrine_b := {
		"id":           "shrine_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"current_hp":   80,
		"stats":        { "max_hp": 100 },
		"grid_pos":     { "col": 5, "row": 5 },
	}
	var enemy_b := {
		"id": "enemy_pur_002b", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 0, "row": 0 },
	}
	var intent_b: Dictionary = BehaviorArbiter.new({}).select_intent({
		"actor": purifier_b, "all_actors": [purifier_b, shrine_b, enemy_b],
		"t": 1, "is_purifier": true, "shrine_alive": true, "shrine_hp_ratio": 0.80,
	})
	if str(intent_b.get("action_type", "")) == "actor.purify_shrine":
		return { "ok": false, "error": "Expected no purify at shrine HP=80%% (HP gate must hold), got: actor.purify_shrine" }

	return { "ok": true }


# Test A3: purifier_no_purify_when_on_cooldown
# Setup: same as A2 (adjacent to shrine) but purify_cooldown=3.
# Expected: NOT actor.purify_shrine — override never fires when cooldown > 0.
static func _t_purifier_no_purify_when_on_cooldown() -> Dictionary:
	var purifier := {
		"id":             "echo_pur_003",
		"faction":        "echo",
		"calling_origin": "okofor",
		"actor_type":     "echo",
		"traits":         { "courage": 40, "wisdom": 30, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 4, "row": 4 },
		"purify_cooldown": 3,
	}
	var shrine := {
		"id":           "shrine_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"current_hp":   80,
		"stats":        { "max_hp": 100 },
		"grid_pos":     { "col": 5, "row": 5 },
	}
	var enemy := {
		"id":       "enemy_pur_003",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 0, "row": 0 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":           purifier,
		"all_actors":      [purifier, shrine, enemy],
		"t":               1,
		"is_purifier":     true,
		"shrine_alive":    true,
		"shrine_hp_ratio": 0.80,
	}
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) == "actor.purify_shrine":
		return { "ok": false, "error": "Expected no purify_shrine when cooldown=3, got: actor.purify_shrine" }

	return { "ok": true }


# Test A4: purifier_attacks_enemy_when_adjacent
# Setup: purifier at (0,0), enemy adjacent at (1,0), shrine far at (9,9).
# Expected: melee_attack — enemy adjacency generates melee_attack candidate which scores higher.
# Demonstrates: purifier still fights enemies in the way; shrine-move only fires when not adjacent to enemy.
static func _t_purifier_attacks_enemy_when_adjacent() -> Dictionary:
	var purifier := {
		"id":             "echo_pur_004",
		"faction":        "echo",
		"calling_origin": "aduro",
		"actor_type":     "echo",
		"traits":         { "courage": 55, "wisdom": 20, "faith": 20 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"purify_cooldown": 0,
	}
	var enemy := {
		"id":       "enemy_pur_004",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },
	}
	var shrine := {
		"id":           "shrine_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"current_hp":   80,
		"stats":        { "max_hp": 100 },
		"grid_pos":     { "col": 9, "row": 9 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":           purifier,
		"all_actors":      [purifier, shrine, enemy],
		"t":               1,
		"is_purifier":     true,
		"shrine_alive":    true,
		"shrine_hp_ratio": 0.80,
	}
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "Expected melee_attack (enemy adjacent, aduro base=65), got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# -------------------------
# COMBAT-BUG-002: Guard deadlock fix test
# -------------------------

# Test B1: repeated_guard_suppressed_for_all_callings
# Verifies that candidate suppression + score penalty work together across callings.
#
# Part 1 — Suppression: guard must be excluded from the candidate pool after one guard round
# when HP is not critical. Tested for all three calling extremes:
#   uncalled (guard base=25), onyamesu (guard base=55), aduro (guard base=15).
# Score-based approaches alone fail for onyamesu at broken morale + high fear (gap ~68 pts).
# Candidate suppression is the hard guarantee regardless of calling or morale/fear state.
#
# Part 2 — Score penalty: on the suppressed turn (guard not in pool), melee_attack should
# beat actor.idle even under last_echo_standing pressure. The +15 melee / -5 idle penalty
# ensures the echo attacks rather than idles when guard is forcibly excluded.
#
# Part 3 — Critical HP exception: guard must remain available (and win) at HP ≤ 20%
# even after a guard round, so a dying echo can still try to survive.
static func _t_repeated_guard_breaks_to_melee() -> Dictionary:
	# --- Part 1: suppression works for all callings ---
	var callings := ["uncalled", "onyamesu", "aduro"]
	for calling in callings:
		var actor := {
			"id":             "echo_gd_001",
			"faction":        "echo",
			"calling_origin": calling,
			"actor_type":     "echo",
			"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
			"vector_scores":  {},
			"fear":           80,
			"morale":         10,  # broken tier — worst-case that previously caused deadlock
			"grid_pos":       { "col": 0, "row": 0 },
			"current_hp":     100,
			"stats":          { "max_hp": 100 },
			"last_intent":    { "action_type": "actor.guard" },
		}
		var enemy := {
			"id": "enemy_gd_001", "faction": "enemy",
			"is_dead": false, "grid_pos": { "col": 1, "row": 0 },
		}
		var arbiter := BehaviorArbiter.new({})
		var intent: Dictionary = arbiter.select_intent({ "actor": actor, "all_actors": [enemy], "t": 1 })
		if str(intent.get("action_type", "")) == "actor.guard":
			return {
				"ok": false,
				"error": "calling='%s': guard must be suppressed (HP=100%%, broken morale, fear=80), got: actor.guard" % calling,
			}

	# --- Part 2: score penalty ensures melee beats idle when guard is suppressed ---
	# last_echo_standing fires (dead_allies=1, living_allies=0) → idle gets +15, melee gets -15.
	# Without the +15 melee bonus from repeated_guard_penalty, idle would win over melee.
	# uncalled: guard suppressed; pool = [melee, idle].
	#   idle (passive): base(20) + last_echo_standing(+15) = 35; repeated_guard_penalty(-5) → 30
	#   melee (fear=60, factor=0.73): base(40) + last_echo_standing(-15) = 25 × 0.73 + echo_in_melee(+18) + repeated_guard(+15) = 51.25
	var actor_p2 := {
		"id":             "echo_gd_p2",
		"faction":        "echo",
		"calling_origin": "uncalled",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           60,
		"morale":         10,  # broken
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
		"last_intent":    { "action_type": "actor.guard" },
	}
	var dead_ally_p2 := {
		"id": "echo_dead_p2", "faction": "echo",
		"is_dead": true, "grid_pos": { "col": 2, "row": 0 },
	}
	var enemy_p2 := {
		"id": "enemy_p2", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 1, "row": 0 },
	}
	var arbiter_p2 := BehaviorArbiter.new({})
	var intent_p2: Dictionary = arbiter_p2.select_intent({
		"actor": actor_p2, "all_actors": [dead_ally_p2, enemy_p2], "t": 1
	})
	if str(intent_p2.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "last_echo_standing + guard suppressed: expected melee_attack (repeated_guard_penalty+15 beats idle), got: %s" % str(intent_p2.get("action_type")),
		}

	# --- Part 3: guard allowed at critical HP ≤ 20% ---
	var actor_crit := {
		"id":             "echo_gd_crit",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           80,
		"morale":         10,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     20,
		"stats":          { "max_hp": 100 },  # 20% HP — at threshold; guard stays available
		"last_intent":    { "action_type": "actor.guard" },
	}
	var enemy_crit := {
		"id": "enemy_crit", "faction": "enemy",
		"is_dead": false, "grid_pos": { "col": 1, "row": 0 },
	}
	var arbiter_crit := BehaviorArbiter.new({})
	var intent_crit: Dictionary = arbiter_crit.select_intent({
		"actor": actor_crit, "all_actors": [enemy_crit], "t": 1
	})
	if str(intent_crit.get("action_type", "")) != "actor.guard":
		return {
			"ok": false,
			"error": "critical HP (20%%): guard must stay available after guard round (onyamesu, broken, fear=80), got: %s" % str(intent_crit.get("action_type")),
		}

	return { "ok": true }


# -------------------------
# §5: Combat-mode distinctiveness tests (V2-STAGE-004 Phase 3)
# -------------------------

# Test §5-A: recover_holder_adjacent_relic_digs_in
# Setup: onyamesu echo in RECOVER mode, adjacent (dist=1) to a living is_structure relic,
#        enemy adjacent (dist=1 from echo). No threatened ally.
# Expected: objective_in_range condition fires (crushing idle from ~8 to 4) and the echo
#           chooses melee_attack or actor.guard — NOT actor.idle.
# This verifies the condition fires and penalises idle/move as specified in §5-A.
static func _t_recover_holder_adjacent_relic_digs_in() -> Dictionary:
	var actor := {
		"id":             "echo_rec_001",
		"faction":        "echo",
		"calling_origin": "onyamesu",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 5, "row": 5 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}
	# Relic: is_structure, adjacent (col 6 row 5 → chebyshev dist=1 from echo at col 5 row 5).
	var relic := {
		"id":           "relic_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"grid_pos":     { "col": 6, "row": 5 },
	}
	# Enemy adjacent to echo (col 4 row 5 → dist=1). Guard candidate fires.
	# onyamesu: melee_attack base=35, echo_in_melee+18, + near_friendly_structure(-5) = 48
	# actor.guard: base=55, echo_in_melee-5, near_friendly_structure(+3) = 53 → guard wins
	# actor.idle: base=20, echo_in_melee-12, near_friendly_structure(0) + objective_in_range(-4) = 4
	# Idle must NOT win.
	var enemy := {
		"id":       "enemy_rec_001",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 4, "row": 5 },
	}

	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":           actor,
		"all_actors":      [actor, relic, enemy],
		"resolution_mode": "recover",
		"t":               1,
	}
	var intent: Dictionary = arbiter.select_intent(context)

	if str(intent.get("action_type", "")) == "actor.idle":
		return {
			"ok": false,
			"error": "RECOVER holder adjacent to relic: objective_in_range should crush idle (score→4), got actor.idle. Intent: %s" % str(intent),
		}
	# Bonus: confirm intent is melee or guard (not idle, not move — no move candidate since enemy is adjacent).
	var at: String = str(intent.get("action_type", ""))
	if at != "melee_attack" and at != "actor.guard":
		return {
			"ok": false,
			"error": "RECOVER holder: expected melee_attack or actor.guard (enemy adjacent + relic adjacent), got: %s" % at,
		}
	return { "ok": true }


# Test §5-C (threatened path): protect_echo_intercepts_totem_attacker
# Setup: echo actor in PROTECT mode, totem at (5,5), one enemy adjacent to totem at (6,5)
#        (chebyshev dist=1 from totem), another enemy closer to echo at (2,0) but far from totem.
#        totem_stolen=false. The echo should target the enemy NEAREST THE TOTEM (not nearest to echo).
# Expected: the intent target_id == "enemy_near_totem".
static func _t_protect_echo_intercepts_totem_attacker() -> Dictionary:
	var actor := {
		"id":             "echo_prot_001",
		"faction":        "echo",
		"calling_origin": "uncalled",
		"actor_type":     "echo",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}
	var totem := {
		"id":           "totem_001",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"grid_pos":     { "col": 5, "row": 5 },
	}
	# Enemy near the totem (chebyshev dist=1 from totem at (5,5)). This is the one to target.
	var enemy_near := {
		"id":       "enemy_near_totem",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 6, "row": 5 },
	}
	# Enemy far from totem but nearer to the echo — should be ignored in PROTECT mode.
	var enemy_far := {
		"id":       "enemy_far_totem",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 2, "row": 0 },  # closer to echo, far from totem
	}

	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":            actor,
		"all_actors":       [actor, totem, enemy_near, enemy_far],
		"resolution_mode":  "protect",
		"totem_stolen":     false,
		"totem_carrier_id": "",
		"t":                1,
	}
	var intent: Dictionary = arbiter.select_intent(context)

	var got_target: String = str(intent.get("target_id", ""))
	if got_target != "enemy_near_totem":
		return {
			"ok": false,
			"error": "PROTECT echo should target nearest-to-totem enemy ('enemy_near_totem'), got target_id='%s' (action=%s)" % [got_target, str(intent.get("action_type"))],
		}
	return { "ok": true }


# Test §5-C (stolen path): protect_echo_focus_fires_carrier
# Setup: echo actor in PROTECT mode, totem_stolen=true, totem_carrier_id="enemy_carrier_001".
#        Carrier alive at (3,3). Another enemy closer to the echo at (1,0) — should be IGNORED.
# Expected: the intent target_id == "enemy_carrier_001" (focus-fire the carrier).
static func _t_protect_echo_focus_fires_carrier() -> Dictionary:
	var actor := {
		"id":             "echo_prot_002",
		"faction":        "echo",
		"calling_origin": "aduro",
		"actor_type":     "echo",
		"traits":         { "courage": 55, "wisdom": 20, "faith": 10 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}
	var totem := {
		"id":           "totem_002",
		"faction":      "structure",
		"is_structure": true,
		"is_dead":      false,
		"grid_pos":     { "col": 5, "row": 5 },
	}
	# The carrier — must be focused.
	var carrier := {
		"id":       "enemy_carrier_001",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 3, "row": 3 },
	}
	# Another enemy closer to the echo — should be IGNORED in stolen mode.
	var other_enemy := {
		"id":       "enemy_other_001",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },  # dist=1 from echo — would normally be picked
	}

	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":            actor,
		"all_actors":       [actor, totem, carrier, other_enemy],
		"resolution_mode":  "protect",
		"totem_stolen":     true,
		"totem_carrier_id": "enemy_carrier_001",
		"t":                1,
	}
	var intent: Dictionary = arbiter.select_intent(context)

	var got_target: String = str(intent.get("target_id", ""))
	if got_target != "enemy_carrier_001":
		return {
			"ok": false,
			"error": "PROTECT stolen: echo must focus-fire carrier ('enemy_carrier_001'), got target_id='%s' (action=%s). Should ignore closer enemy." % [got_target, str(intent.get("action_type"))],
		}
	return { "ok": true }


# FleeBehaviorModule: quarry near echoes moves toward a far edge.
# Board 10x10. Quarry at (5,5). Echo at (3,3). Best edge should be far-right or far-bottom (away from echo).
static func _t_pursue_flee_module_moves_toward_edge() -> Dictionary:
	var board_cfg: Dictionary = { "board_cols": 10, "board_rows": 10 }
	var flee_mod := FleeBehaviorModule.new(board_cfg)

	var quarry_actor := {
		"id":       "quarry_001",
		"faction":  "enemy",
		"is_quarry": true,
		"is_dead":  false,
		"grid_pos": { "col": 5, "row": 5 },
	}
	var echo_actor := {
		"id":       "echo_001",
		"faction":  "echo",
		"is_dead":  false,
		"grid_pos": { "col": 3, "row": 3 },
	}
	var context := {
		"actor":      quarry_actor,
		"all_actors": [quarry_actor, echo_actor],
		"board_cfg":  board_cfg,
		"t":          0,
	}

	var intent: Dictionary = flee_mod.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "FleeBehaviorModule should return actor.move, got '%s'" % str(intent.get("action_type", "")) }
	var tp: Dictionary = intent.get("target_pos", {})
	if tp.is_empty():
		return { "ok": false, "error": "FleeBehaviorModule returned actor.move but no target_pos" }
	# Target should be a board-edge cell (col=0, col=9, row=0, or row=9).
	var col: int = int(tp.get("col", -1))
	var row: int = int(tp.get("row", -1))
	if not (col == 0 or col == 9 or row == 0 or row == 9):
		return { "ok": false, "error": "FleeBehaviorModule target_pos (%d,%d) is not a board-edge cell" % [col, row] }
	return { "ok": true }


# Irregular-terrain sub-case: walkable dict covers only interior cells (col 1..8, row 1..8).
# Literal edge ring (col 0, col 9, row 0, row 9) is void — absent from walkable.
# FleeBehaviorModule must use the walkable branch and pick a near-border walkable cell
# (col ≤ 2 OR col ≥ 7 OR row ≤ 2 OR row ≥ 7) rather than the void literal corners.
static func _t_pursue_flee_module_targets_inset_border() -> Dictionary:
	# Build walkable dict for a 10×10 board where only interior cells (col 1..8, row 1..8) exist.
	var walkable: Dictionary = {}
	for c in range(1, 9):
		for r in range(1, 9):
			walkable["%d,%d" % [c, r]] = true

	var board_cfg: Dictionary = { "board_cols": 10, "board_rows": 10, "walkable": walkable }
	var flee_mod := FleeBehaviorModule.new(board_cfg)

	var quarry_actor := {
		"id":        "quarry_irr_001",
		"faction":   "enemy",
		"is_quarry": true,
		"is_dead":   false,
		"grid_pos":  { "col": 4, "row": 4 },
	}
	var echo_actor := {
		"id":       "echo_irr_001",
		"faction":  "echo",
		"is_dead":  false,
		"grid_pos": { "col": 2, "row": 2 },
	}
	var context := {
		"actor":      quarry_actor,
		"all_actors": [quarry_actor, echo_actor],
		"board_cfg":  board_cfg,
		"t":          0,
	}

	var intent: Dictionary = flee_mod.select_intent(context)

	if str(intent.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "FleeBehaviorModule (irregular) should return actor.move, got '%s'" % str(intent.get("action_type", "")) }
	var tp: Dictionary = intent.get("target_pos", {})
	if tp.is_empty():
		return { "ok": false, "error": "FleeBehaviorModule (irregular) returned actor.move but no target_pos" }
	var col: int = int(tp.get("col", -1))
	var row: int = int(tp.get("row", -1))
	# Target must be in the near-border band of the inset walkable set.
	if not (col <= 2 or col >= 7 or row <= 2 or row >= 7):
		return {
			"ok": false,
			"error": "FleeBehaviorModule (irregular) target_pos (%d,%d) is not near the inset border band" % [col, row],
		}
	return { "ok": true }


# quarry_near_exit condition: echo in PURSUE mode with quarry near edge → prefers actor.move.
# Board 10x10. Echo at (5,5). Quarry at (1,1) — dist_to_edge = min(1,1,8,8) = 1 < threshold 3.
# With quarry_near_exit firing (actor.move +8, melee_attack -2), the echo should strongly prefer move.
static func _t_pursue_echo_quarry_near_exit_fires() -> Dictionary:
	var echo_actor := {
		"id":             "echo_chk_001",
		"faction":        "echo",
		"actor_type":     "echo",
		"calling_origin": "uncalled",
		"is_dead":        false,
		"grid_pos":       { "col": 5, "row": 5 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
		"traits":         { "courage": 50, "wisdom": 50, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
	}
	var quarry_actor := {
		"id":           "quarry_chk_001",
		"faction":      "enemy",
		"is_quarry":    true,
		"is_dead":      false,
		"is_structure": false,
		"grid_pos":     { "col": 1, "row": 1 },
		"current_hp":   60,
	}
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor":           echo_actor,
		"all_actors":      [echo_actor, quarry_actor],
		"board_cfg":       { "board_cols": 10, "board_rows": 10 },
		"resolution_mode": "pursue",
		"t":               0,
	}

	var intent: Dictionary = arbiter.select_intent(context)

	# With quarry_near_exit (+8 to actor.move, -2 to melee_attack) and uncalled echo base,
	# actor.move should win decisively. Verify the echo does NOT pick actor.idle.
	if str(intent.get("action_type", "")) == "actor.idle":
		return {
			"ok": false,
			"error": "quarry_near_exit bonus should make echo prefer actor.move, not actor.idle. Intent: %s" % str(intent),
		}
	return { "ok": true }

