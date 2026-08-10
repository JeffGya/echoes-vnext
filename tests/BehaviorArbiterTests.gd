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

# V2-COMBAT-002 Slice 6E movement cross-check fixtures.
const MvContext = preload("res://core/movement/contracts/MovementContext.gd")
const MvActorFact = preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const MvProfile = preload("res://core/movement/contracts/MovementProfile.gd")
const MvGoal = preload("res://core/movement/contracts/MovementGoal.gd")
const MvOption = preload("res://core/movement/contracts/MovementOption.gd")
const MvActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

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
	# V2-COMBAT-002 Slice 6E: _crosscheck_perceived_actor must apply the same
	# `incapable_actor_cannot_control` conjunction FlowRuntime._movement_actor_facts derives.
	runner.register_test("arbiter/crosscheck_structure_on_board_selects",
		Callable(BehaviorArbiterTests, "_t_crosscheck_structure_on_board_selects"))
	runner.register_test("arbiter/crosscheck_dead_actor_on_board_selects",
		Callable(BehaviorArbiterTests, "_t_crosscheck_dead_actor_on_board_selects"))
	runner.register_test("arbiter/crosscheck_ko_actor_on_board_selects",
		Callable(BehaviorArbiterTests, "_t_crosscheck_ko_actor_on_board_selects"))
	runner.register_test("arbiter/crosscheck_still_catches_real_state_mismatch",
		Callable(BehaviorArbiterTests, "_t_crosscheck_still_catches_real_state_mismatch"))
	# V2-PROG-012 Phase 6 Item 2: config-integrity guard on the interpretation_width
	# swing budget — DEFECT 2's actual fix mechanism.
	runner.register_test("arbiter/interpretation_swing_within_declared_budget",
		Callable(BehaviorArbiterTests, "_t_interpretation_swing_within_declared_budget"))
	# V2-PROG-012 Phase 6 Item 4: first coverage for _directive_bonus() — each test
	# isolates ONE axis (rank vs judgment), which neither pre-existing rank-based
	# test in this suite did (they moved band and rank together).
	runner.register_test("arbiter/directive_and_identity_invariant_to_rank_when_judgment_fixed",
		Callable(BehaviorArbiterTests, "_t_directive_and_identity_invariant_to_rank_when_judgment_fixed"))
	runner.register_test("arbiter/identity_bonus_rises_with_judgment_rank_fixed",
		Callable(BehaviorArbiterTests, "_t_identity_bonus_rises_with_judgment_rank_fixed"))
	runner.register_test("arbiter/directive_bonus_falls_with_judgment_rank_fixed",
		Callable(BehaviorArbiterTests, "_t_directive_bonus_falls_with_judgment_rank_fixed"))


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
	# --- Part A: shrine below 50% — legacy arbiter no longer owns exact shrine movement ---
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
		return { "ok": false, "error": "Part A: expected actor.move under legacy fallback, got: %s" % str(intent_a.get("action_type")) }
	var tpos_a: Dictionary = intent_a.get("target_pos", {})
	if int(tpos_a.get("col", -1)) != 5 or int(tpos_a.get("row", -1)) != 5:
		return { "ok": false, "error": "Part A: legacy exact shrine redirect should be retired; expected ordinary enemy target {col:5,row:5}, got: %s" % str(tpos_a) }

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


# Test §5-C (threatened path): legacy exact PROTECT redirect retired.
# Setup: echo actor in PROTECT mode, totem at (5,5), one enemy adjacent to totem at (6,5)
#        (chebyshev dist=1 from totem), another enemy closer to echo at (2,0) but far from totem.
#        totem_stolen=false. Exact totem-nearest targeting is now owned by pressure-region
#        movement, not this legacy selector.
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

	var got_action: String = str(intent.get("action_type", ""))
	if not got_action in ["actor.move", "melee_attack", "actor.guard"]:
		return {
			"ok": false,
			"error": "PROTECT legacy selector should still produce a combat action after exact redirect retirement, got action=%s intent=%s" % [got_action, str(intent)],
		}
	return { "ok": true }


# Test §5-C (stolen path): legacy exact carrier redirect retired.
# Setup: echo actor in PROTECT mode, totem_stolen=true, totem_carrier_id="enemy_carrier_001".
#        Carrier alive at (3,3). Another enemy closer to the echo at (1,0).
#        Carrier focus is now owned by pressure-region movement, not this legacy selector.
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

	var got_action: String = str(intent.get("action_type", ""))
	if not got_action in ["actor.move", "melee_attack", "actor.guard"]:
		return {
			"ok": false,
			"error": "PROTECT stolen legacy selector should still produce a combat action after exact redirect retirement, got action=%s intent=%s" % [got_action, str(intent)],
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

# ---------------------------------------------------------------------------
# V2-COMBAT-002 Slice 6E — `_crosscheck_perceived_actor` incapacity conjunction.
#
# `select_movement_intent` re-derives the perceived-actor facts it is handed and
# asserts they match the raw actor dicts. NO actor dict in the codebase ever SETS a
# `controlling_state` key, so the arbiter's side defaulted to `true` for every actor,
# while FlowRuntime._movement_actor_facts derives
#     controlling = actor.get("controlling_state", true) and not dead and not ko and not structure
# — the conjunction MovementPerceivedActorFact.validate MANDATES via
# `incapable_actor_cannot_control`. Any board holding a structure, a corpse or a
# downed actor therefore failed the cross-check with `perceived_actor_state_mismatch`,
# and a single mismatch discards the WHOLE board's selection (select_movement_intent
# returns valid:false), so ActorStateMachine fell back to legacy nearest-enemy
# select_intent for every actor.
#
# The fixtures below build facts exactly the way FlowRuntime does — and, critically,
# never set `controlling_state` on the raw actor dict, because production never does.
# ---------------------------------------------------------------------------

static func _t_crosscheck_structure_on_board_selects() -> Dictionary:
	# Shrine: is_structure, kind "structure", and NO controlling_state key on the dict.
	return _assert_incapable_actor_selects(
		_mv_bystander("shrine.a", { "col": 0, "row": 2 }, "structure", { "is_structure": true }),
		"structure"
	)


static func _t_crosscheck_dead_actor_on_board_selects() -> Dictionary:
	return _assert_incapable_actor_selects(
		_mv_bystander("enemy.dead", { "col": 1, "row": 2 }, "enemy", { "is_dead": true, "current_hp": 0 }),
		"dead actor"
	)


static func _t_crosscheck_ko_actor_on_board_selects() -> Dictionary:
	return _assert_incapable_actor_selects(
		_mv_bystander("echo.ko", { "col": 2, "row": 2 }, "echo", { "is_ko": true, "current_hp": 0 }),
		"KO'd actor"
	)


# Negative pole: the audit must still REJECT a genuine disagreement. A live, healthy
# enemy is capable, so a fact claiming controlling_state=false for it is contract-legal
# but factually wrong — the cross-check must catch it and discard the selection.
# Without this, the three tests above could be satisfied by deleting the audit outright.
static func _t_crosscheck_still_catches_real_state_mismatch() -> Dictionary:
	var fixture: Dictionary = _mv_fixture([])
	var movement: Dictionary = fixture["movement_context"] as Dictionary
	for fact_value: Variant in movement["perceived_actors"] as Array:
		var fact: Dictionary = fact_value as Dictionary
		if str(fact["id"]) == "enemy.a":
			fact["controlling_state"] = false
	var result: Dictionary = _mv_select(fixture)
	if bool(result.get("valid", false)):
		return { "ok": false, "error": "a live hostile falsely marked non-controlling must be rejected: %s" % str(result) }
	if str(result.get("reason", "")) != "perceived_actor_state_mismatch":
		return { "ok": false, "error": "expected perceived_actor_state_mismatch, got %s" % str(result) }
	if str(result.get("field", "")) != "context.all_actors.enemy.a.controlling_state":
		return { "ok": false, "error": "unexpected mismatch field: %s" % str(result.get("field", "")) }
	if not (result.get("intent", {}) as Dictionary).is_empty():
		return { "ok": false, "error": "an invalidated selection must carry no intent: %s" % str(result) }
	return { "ok": true }


static func _assert_incapable_actor_selects(bystander: Dictionary, label: String) -> Dictionary:
	if bystander.has("controlling_state"):
		return { "ok": false, "error": "fixture must not set controlling_state — production actor dicts never do" }
	var fixture: Dictionary = _mv_fixture([bystander])
	var result: Dictionary = _mv_select(fixture)
	if not bool(result.get("valid", false)):
		return {
			"ok": false,
			"error": "a board containing a %s discarded the whole movement-aware selection: %s" % [label, str(result)],
		}
	var intent: Dictionary = result["intent"] as Dictionary
	if not intent.has("planned_action"):
		return { "ok": false, "error": "valid selection carried no planned_action: %s" % str(intent) }
	if str((intent["planned_action"] as Dictionary).get("target_id", "")) != "enemy.a":
		return { "ok": false, "error": "selection did not commit to the goal target: %s" % str(intent) }
	return { "ok": true }


static func _mv_select(fixture: Dictionary) -> Dictionary:
	var arbiter := BehaviorArbiter.new({}, fixture["movement_cfg"] as Dictionary)
	return arbiter.select_movement_intent(
		fixture["context"] as Dictionary,
		fixture["movement_context"] as Dictionary,
		fixture["profile"] as Dictionary,
		fixture["goals"] as Array,
		fixture["options"] as Array
	)


# 6x3 board. Mover echo.a at (0,0) advances toward enemy.a at (3,0) via (1,0)→(2,0).
static func _mv_fixture(bystanders: Array) -> Dictionary:
	var mover: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": { "col": 0, "row": 0 }, "stats": { "max_hp": 100 }, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": { "col": 3, "row": 0 }, "stats": { "max_hp": 100 }, "current_hp": 100,
	}
	var others: Array = [enemy]
	for value: Variant in bystanders:
		others.append(value as Dictionary)

	var facts: Array = [_mv_fact(mover)]
	var occupancy: Dictionary = { "0,0": "echo.a" }
	var relationships: Dictionary = {}
	for value: Variant in others:
		var other: Dictionary = value as Dictionary
		facts.append(_mv_fact(other))
		# Mirrors FlowRuntime._movement_occupancy — dead actors do not occupy a cell.
		if not bool(other.get("is_dead", false)):
			occupancy["%d,%d" % [int(other["grid_pos"]["col"]), int(other["grid_pos"]["row"])]] = str(other["id"])
		relationships[str(other["id"])] = "friendly" if str(other.get("faction", "")) == "echo" else "hostile"
	facts.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str((a as Dictionary)["id"]) < str((b as Dictionary)["id"])
	)

	var walkable: Dictionary = {}
	var terrain: Dictionary = {}
	for col: int in range(6):
		for row: int in range(3):
			walkable["%d,%d" % [col, row]] = true
			terrain["%d,%d" % [col, row]] = 1

	var goal: Dictionary = MvGoal.build(
		"goal.combat.advance.baseline.c2r0", "advance", [{ "col": 2, "row": 0 }], 1.0, 0.0,
		["enemy.a"], ["mode.combat", "role.baseline"],
		MvActionPlan.build("actor.move", "enemy.a"), MvActionPlan.build("actor.idle")
	)
	var option: Dictionary = MvOption.build(
		str(goal["goal_id"]),
		"option.combat.advance.baseline.c2r0.direct.d2r0.pc1r0-c2r0",
		"advance", { "col": 2, "row": 0 }, [{ "col": 1, "row": 0 }, { "col": 2, "row": 0 }],
		2, 2, 0, 4, 2, 0.0, 0.0, 0.0, [], { "known_count": 0, "known_ids": [] }, 1.0,
		goal["planned_primary"] as Dictionary, goal["declared_fallback"] as Dictionary
	)
	var all_actors: Array = [mover]
	for value: Variant in others:
		all_actors.append(value)
	return {
		"context": { "actor": mover, "all_actors": all_actors, "t": 1 },
		"movement_context": MvContext.build(
			"echo.a", "activation.a", mover["grid_pos"] as Dictionary, { "w": 6, "h": 3 },
			walkable, walkable, occupancy, facts, relationships, terrain, [], {}, []
		),
		"profile": MvProfile.build(4, [], true, "echo", {}),
		"goals": [goal],
		"options": [option],
		"movement_cfg": _mv_spatial_cfg(),
	}


# VERBATIM mirror of FlowRuntime._movement_actor_facts — including the
# `incapable_actor_cannot_control` conjunction the contract mandates.
static func _mv_fact(actor: Dictionary) -> Dictionary:
	var max_hp: int = int((actor.get("stats", {}) as Dictionary).get("max_hp", actor.get("max_hp", 1)))
	var hp_ratio: float = 0.0 if max_hp <= 0 else clampf(float(actor.get("current_hp", 0)) / float(max_hp), 0.0, 1.0)
	var is_dead: bool = bool(actor.get("is_dead", false))
	var is_ko: bool = bool(actor.get("is_ko", false)) or (int(actor.get("current_hp", 1)) <= 0 and not is_dead)
	var is_structure: bool = bool(actor.get("is_structure", false))
	var controlling: bool = bool(actor.get("controlling_state", true)) \
		and not is_dead and not is_ko and not is_structure
	return MvActorFact.build(
		str(actor.get("id", "")), actor.get("grid_pos", {}) as Dictionary,
		"structure" if is_structure else str(actor.get("actor_type", "echo")),
		is_dead, is_ko, is_structure,
		bool(actor.get("is_spirit", false)), bool(actor.get("is_quarry", false)),
		controlling, hp_ratio
	)


static func _mv_bystander(id: String, position: Dictionary, actor_type: String, flags: Dictionary) -> Dictionary:
	var actor: Dictionary = {
		"id": id, "actor_type": actor_type,
		"faction": "structure" if actor_type == "structure" else ("echo" if actor_type == "echo" else "enemy"),
		"grid_pos": position, "stats": { "max_hp": 100 }, "current_hp": 100,
	}
	for key: Variant in flags.keys():
		actor[str(key)] = flags[key]
	return actor


static func _mv_spatial_cfg() -> Dictionary:
	return { "spatial_utility": {
		"cap": 20.0, "urgency_weight": 4.0, "objective_progress_weight": 8.0,
		"cohesion_weight": 4.0, "exposure_weight": -6.0, "congestion_weight": -2.0,
		"commitment_weight": -2.0, "directive_objective_advance_weight": 4.0,
		"directive_avoid_overcommit_weight": 2.0, "directive_exposure_acceptance_weight": 2.0,
		"directive_ally_protection_weight": 2.0, "directive_threat_interception_weight": 2.0,
	} }


# V2-PROG-012 Phase 6 Item 2 — config-integrity test. This is the mechanism that
# stops DEFECT 2 (identity_weight_scale and directive_band_mul silently doubling
# the identity-vs-directive swing because neither knew about the other) from
# recurring: reads the REAL production identity_weight_scale and
# directive_interpretation_mul straight off ConfigService.get_balance() (not a
# hand-set test fixture — a fixture would happily "pass" no matter what the
# shipped values are) and fails if their combined ratio at interpretation_width=1.0
# exceeds the declared interpretation_swing_max budget.
# FALSIFIABLE: a future tuning pass that raises identity_weight_scale.trait/vector
# (e.g. back toward the pre-fix 0.6/0.6) or lowers directive_interpretation_mul.low
# without also raising interpretation_swing_max to match would push the computed
# ratio above the budget and this test would fail — exactly the silent-drift
# scenario DEFECT 2 described, now caught instead of unnoticed.
static func _t_interpretation_swing_within_declared_budget() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var expr_cfg: Dictionary = (bal.get("data", {}) as Dictionary).get("maturity_expression", {})
	var identity_weight_scale: Dictionary = expr_cfg.get("identity_weight_scale", {})
	var directive_interpretation_mul: Dictionary = expr_cfg.get("directive_interpretation_mul", {})
	var swing_max: float = float(expr_cfg.get("interpretation_swing_max", {}).get("value", 0.0))

	if identity_weight_scale.is_empty() or directive_interpretation_mul.is_empty() or swing_max <= 0.0:
		return { "ok": false, "error": "fixture broken: expected non-empty identity_weight_scale/directive_interpretation_mul and a positive interpretation_swing_max, got %s / %s / %s" % [str(identity_weight_scale), str(directive_interpretation_mul), str(swing_max)] }

	var actual_swing: float = BehaviorArbiter.compute_interpretation_swing(identity_weight_scale, directive_interpretation_mul)
	if actual_swing > swing_max:
		return { "ok": false, "error": "authored identity:directive ratio (%.4f) exceeds the declared interpretation_swing_max budget (%.4f) — identity_weight_scale=%s, directive_interpretation_mul=%s" % [actual_swing, swing_max, str(identity_weight_scale), str(directive_interpretation_mul)] }
	return { "ok": true }


# ─── V2-PROG-012 Phase 6 Item 4 — first coverage for _directive_bonus() ────
# Shared fixture for the three axis-isolation tests below: an "uncalled" Echo
# with positive traits/vectors that both feed melee_attack (courage 0.35,
# vanguard 0.40 per _DEFAULTS), plus a directive whose sole intent_weights key
# (objective_advance_priority) maps to a POSITIVE melee_attack directive_action_muls
# entry (1.0) — so directive_bonus is unambiguously positive and its response to
# interpretation_width is directly observable, not masked by a sign flip.
static func _axis_test_actor() -> Dictionary:
	return {
		"id": "echo_axis_test", "faction": "echo", "actor_type": "echo",
		"calling_origin": "uncalled",
		"traits": {"courage": 60, "wisdom": 40, "faith": 20},
		"vector_scores": {"vanguard": 50.0},
		"fear": 0, "fear_base": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0},
	}


static func _axis_test_directive() -> Dictionary:
	return {"id": "directive.axis_test", "intent_weights": {"objective_advance_priority": 1.0}}


# Item 4, bullet 1 — vary rank with judgment held fixed. FALSIFIABLE: if a
# regression reintroduced rank_strength as an identity-scaling input (DEFECT 2's
# pre-fix shape — two independently-authored, rank-correlated levers), or if
# directive literalism regressed back to reading a rank-derived expression_band
# instead of judgment, trait_bonus/vector_bonus/directive_bonus would differ
# between these two calls despite identical judgment=0.6. Neither pre-existing
# rank-based test in this suite isolated this — they moved band and rank
# together, so neither could attribute a delta to rank alone.
static func _t_directive_and_identity_invariant_to_rank_when_judgment_fixed() -> Dictionary:
	var actor: Dictionary = _axis_test_actor()
	var directive: Dictionary = _axis_test_directive()
	var arbiter := BehaviorArbiter.new({})
	var candidate: Dictionary = {"action_type": "melee_attack", "target_id": "e1", "target_hp_ratio": 1.0}

	var comp_low_rank: Dictionary = {}
	var comp_high_rank: Dictionary = {}
	# expression_band held fixed at "grounded" on both calls (calling_origin
	# "uncalled" doesn't hit any of _score()'s Grounded+ calling_mul branches, so
	# this is neutral) — only rank_strength (identity's OLD driver) differs;
	# judgment is fixed at 0.6.
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 0.0, 0.4, 0.6, comp_low_rank)
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 1.0, 0.4, 0.6, comp_high_rank)

	if not is_equal_approx(float(comp_low_rank.get("trait_bonus", -1.0)), float(comp_high_rank.get("trait_bonus", -2.0))):
		return { "ok": false, "error": "trait_bonus moved with rank_strength alone (judgment fixed): %s vs %s" % [str(comp_low_rank.get("trait_bonus")), str(comp_high_rank.get("trait_bonus"))] }
	if not is_equal_approx(float(comp_low_rank.get("vector_bonus", -1.0)), float(comp_high_rank.get("vector_bonus", -2.0))):
		return { "ok": false, "error": "vector_bonus moved with rank_strength alone (judgment fixed): %s vs %s" % [str(comp_low_rank.get("vector_bonus")), str(comp_high_rank.get("vector_bonus"))] }
	if not is_equal_approx(float(comp_low_rank.get("directive_bonus", -1.0)), float(comp_high_rank.get("directive_bonus", -2.0))):
		return { "ok": false, "error": "directive_bonus moved with rank_strength alone (judgment fixed): %s vs %s" % [str(comp_low_rank.get("directive_bonus")), str(comp_high_rank.get("directive_bonus"))] }
	return { "ok": true }


# Item 4, bullet 2 — vary judgment with rank held fixed: identity weighting
# (trait_bonus/vector_bonus) must rise. FALSIFIABLE: if identity_weight_scale
# stopped being applied (or were applied to the wrong axis), trait_bonus/
# vector_bonus would stay flat between judgment=0.0 and judgment=1.0 instead of
# strictly increasing.
static func _t_identity_bonus_rises_with_judgment_rank_fixed() -> Dictionary:
	var actor: Dictionary = _axis_test_actor()
	var directive: Dictionary = _axis_test_directive()
	var arbiter := BehaviorArbiter.new({})
	var candidate: Dictionary = {"action_type": "melee_attack", "target_id": "e1", "target_hp_ratio": 1.0}

	var comp_low_j: Dictionary = {}
	var comp_high_j: Dictionary = {}
	# rank_strength held fixed at 0.5 (an arbitrary mid value — DEFECT 2's whole
	# point is that this must no longer matter to identity/directive) on both
	# calls; only judgment differs (0.0 -> 1.0).
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 0.5, 0.4, 0.0, comp_low_j)
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 0.5, 0.4, 1.0, comp_high_j)

	var trait_low: float = float(comp_low_j.get("trait_bonus", 0.0))
	var trait_high: float = float(comp_high_j.get("trait_bonus", 0.0))
	var vector_low: float = float(comp_low_j.get("vector_bonus", 0.0))
	var vector_high: float = float(comp_high_j.get("vector_bonus", 0.0))
	if trait_low <= 0.0 or vector_low <= 0.0:
		return { "ok": false, "error": "fixture broken: expected positive baseline trait_bonus/vector_bonus at judgment=0.0, got trait=%s vector=%s" % [str(trait_low), str(vector_low)] }
	if trait_high <= trait_low:
		return { "ok": false, "error": "trait_bonus did not rise with judgment: %s (judgment=0.0) -> %s (judgment=1.0)" % [str(trait_low), str(trait_high)] }
	if vector_high <= vector_low:
		return { "ok": false, "error": "vector_bonus did not rise with judgment: %s (judgment=0.0) -> %s (judgment=1.0)" % [str(vector_low), str(vector_high)] }
	return { "ok": true }


# Item 4, bullet 4 — pins GDD:1422/GDD §7.3 "Standing never buys obedience" as an
# executable assertion: as judgment rises, the directive multiplier must go
# DOWN, never up. FALSIFIABLE: if a sign error flipped the lerp direction
# (dir_mul rising with interpretation_width instead of falling), directive_bonus
# would rise here instead of fall, and this test would catch it immediately.
static func _t_directive_bonus_falls_with_judgment_rank_fixed() -> Dictionary:
	var actor: Dictionary = _axis_test_actor()
	var directive: Dictionary = _axis_test_directive()
	var arbiter := BehaviorArbiter.new({})
	var candidate: Dictionary = {"action_type": "melee_attack", "target_id": "e1", "target_hp_ratio": 1.0}

	var comp_low_j: Dictionary = {}
	var comp_high_j: Dictionary = {}
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 0.5, 0.4, 0.0, comp_low_j)
	arbiter._score("melee_attack", actor, directive, {}, "grounded", {}, candidate, 0.1, 0.5, 0.4, 1.0, comp_high_j)

	var directive_low: float = float(comp_low_j.get("directive_bonus", 0.0))
	var directive_high: float = float(comp_high_j.get("directive_bonus", 0.0))
	if directive_low <= 0.0:
		return { "ok": false, "error": "fixture broken: expected a positive baseline directive_bonus at judgment=0.0, got %s" % str(directive_low) }
	if directive_high >= directive_low:
		return { "ok": false, "error": "directive_bonus did not fall with rising judgment (GDD:1422 'Standing never buys obedience'): %s (judgment=0.0) -> %s (judgment=1.0)" % [str(directive_low), str(directive_high)] }
	return { "ok": true }
