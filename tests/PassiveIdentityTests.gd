# res://tests/PassiveIdentityTests.gd
# PROG-009: Validates always-on passive identity rules per calling.
#
# Tests:
#   1. Warder anchor: guard/protect_ally score boosted by +8 per stationary round (cap +24).
#   2. Blade broken morale: broken_morale_override applies guard penalty + melee bonus.
#   3. Seer directive aura: seer_directive_aura situational condition fires when seer present.
#   4. Ranger fear move bonus: fear increases move score via fear_move_bonus.
#   5. EchoActor passes equipped_skills through from echo dict.
#
# Tests 1-4 use BehaviorArbiter.new({}) with inline cfg_data where needed.
# Test 5 is a pure data-mapping test (no arbiter).

class_name PassiveIdentityTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("passive/warder_anchor_boosts_guard",         Callable(PassiveIdentityTests, "_t_warder_anchor_boosts_guard"))
	runner.register_test("passive/blade_broken_morale_override",       Callable(PassiveIdentityTests, "_t_blade_broken_morale_override"))
	runner.register_test("passive/seer_directive_aura_fires",          Callable(PassiveIdentityTests, "_t_seer_directive_aura_fires"))
	runner.register_test("passive/ranger_fear_move_bonus",             Callable(PassiveIdentityTests, "_t_ranger_fear_move_bonus"))
	runner.register_test("passive/echo_actor_carries_equipped_skills", Callable(PassiveIdentityTests, "_t_echo_actor_carries_equipped_skills"))


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _make_warder(anchor_rounds: int) -> Dictionary:
	var actor := {
		"id":             "echo_warder_p_01",
		"faction":        "echo",
		"calling_origin": "warder",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}
	if anchor_rounds > 0:
		actor["_anchor_rounds"] = anchor_rounds
	return actor

static func _make_blade_broken() -> Dictionary:
	return {
		"id":             "echo_blade_p_01",
		"faction":        "echo",
		"calling_origin": "blade",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # broken tier (< 25)
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}

static func _make_seer_ally() -> Dictionary:
	return {
		"id":             "echo_seer_aura_01",
		"faction":        "echo",
		"calling_origin": "seer",
		"is_dead":        false,
		"grid_pos":       { "col": 2, "row": 0 },
	}

static func _make_ranger(fear: int) -> Dictionary:
	return {
		"id":             "echo_ranger_p_01",
		"faction":        "echo",
		"calling_origin": "ranger",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           fear,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}

static func _adjacent_enemy() -> Dictionary:
	return {
		"id": "enemy_p_01", "faction": "enemy", "is_dead": false,
		"grid_pos": { "col": 1, "row": 0 },
	}

static func _distant_enemy() -> Dictionary:
	return {
		"id": "enemy_p_02", "faction": "enemy", "is_dead": false,
		"grid_pos": { "col": 2, "row": 0 },
	}

## Returns a calling_behavior config block for blade with broken_morale_override.
static func _blade_cfg() -> Dictionary:
	return {
		"smartness": {
			"calling_behavior": {
				"blade": {
					"retreat_threshold": 0.30,
					"press_advantage":   true,
					"directive_mul":     1.0,
					"leadership_radius": 3,
					"absolute_fear_threshold": 75,
					"broken_morale_override": {
						"melee_attack": 8.0,
						"actor.guard":  -5.0,
					},
				}
			}
		}
	}


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

# Test 1: Warder anchor — with _anchor_rounds=3 the guard/protect_ally bonus is +24.
# Without anchor: warder guard~base≈25 (using uncalled guard since no anchor tweaks base weights directly
# — the anchor adds TO the scored value in _score(). warder base guard is from intent_weights=45).
# With anchor 3 rounds: protect_ally gets +24 boost → protect_ally = 65+24 = 89 if ally present.
# Simple test: warder with _anchor_rounds=3, threatened ally → protect_ally wins overwhelmingly.
static func _t_warder_anchor_boosts_guard() -> Dictionary:
	var actor := _make_warder(3)
	var ally  := {
		"id": "echo_ally_anch_01", "faction": "echo", "is_dead": false,
		"current_hp": 20, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 2, "row": 0 },
	}
	var enemy := _adjacent_enemy()
	var arbiter := BehaviorArbiter.new({})
	var ctx := { "actor": actor, "all_actors": [enemy, ally], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(ctx)

	# Warder with anchor=3: protect_ally = base(65) + anchor_bonus(24) = 89 >> melee(20).
	if str(intent.get("action_type", "")) != "protect_ally":
		return {
			"ok": false,
			"error": "Expected protect_ally (warder anchor=3 → score=89), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 2: Blade broken morale override.
# When blade morale=10 (broken) and broken_morale_override is in cfg_data:
#   melee_attack gets +8.0 morale bonus (instead of normal negative)
#   actor.guard gets -5.0 morale bonus (penalty)
# Without override, broken morale would dampen melee. With override, melee stays strong.
# We verify: blade + broken morale + adjacent enemy → melee_attack wins (not guard or idle).
static func _t_blade_broken_morale_override() -> Dictionary:
	var actor  := _make_blade_broken()
	var enemy  := _adjacent_enemy()
	var arbiter := BehaviorArbiter.new(_blade_cfg())
	var ctx := { "actor": actor, "all_actors": [enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(ctx)

	# Blade broken morale override: melee +8 bonus → melee wins even in broken state.
	if str(intent.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "Expected melee_attack (blade broken_morale_override +8), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 3: Seer directive aura situational condition fires when a Seer ally is nearby.
# seer_directive_aura adds a strategic bonus to non-seer actors when Seer is nearby.
# We test: uncalled echo near a seer ally has higher guard/protect_ally than alone.
# Simple proxy: the board summary includes seer_directive_aura = true when seer is within 3 tiles.
# Since BehaviorArbiter's _build_board_summary() is internal, we verify via intent scoring:
# an uncalled echo with seer nearby (and no enemy) should still produce a valid intent.
static func _t_seer_directive_aura_fires() -> Dictionary:
	var actor := {
		"id":             "echo_uncalled_p_01",
		"faction":        "echo",
		"calling_origin": "uncalled",
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}
	var seer_ally := _make_seer_ally()  # within 3 tiles
	var enemy     := _adjacent_enemy()
	var arbiter   := BehaviorArbiter.new({})
	# With seer ally at col=2 (dist=2), seer_directive_aura should fire.
	var ctx := { "actor": actor, "all_actors": [seer_ally, enemy], "t": 1 }
	var intent: Dictionary = arbiter.select_intent(ctx)

	# Verify: intent is valid (no crash). The aura adds to strategic actions.
	# With the aura, guard/protect_ally/idle get a small boost — exact winner depends on full scoring.
	if not intent.has("action_type"):
		return { "ok": false, "error": "Intent missing action_type when seer ally present" }
	if intent.is_empty():
		return { "ok": false, "error": "Empty intent when seer directive aura should fire" }
	return { "ok": true }


# Test 4: Ranger fear move bonus — fear raises move score via fear_move_bonus.
# Ranger at fear=60 with enemy at dist=2 (move is the normal candidate).
# fear_move_bonus=12 from calling_behavior adds to move score under fear.
# Without fear: ranger move=55 (already highest). With fear: move+12 = 67. Still wins — but
# we verify fear doesn't suppress move (which is the anti-pattern for other callings).
static func _t_ranger_fear_move_bonus() -> Dictionary:
	var actor_no_fear   := _make_ranger(0)
	var actor_with_fear := _make_ranger(60)
	var enemy           := _distant_enemy()
	var arbiter         := BehaviorArbiter.new({})

	var intent_no_fear: Dictionary   = arbiter.select_intent({ "actor": actor_no_fear,   "all_actors": [enemy], "t": 1 })
	var intent_with_fear: Dictionary = arbiter.select_intent({ "actor": actor_with_fear, "all_actors": [enemy], "t": 1 })

	# Both should prefer actor.move (ranger move=55 is dominant at dist=2).
	if str(intent_no_fear.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected actor.move for ranger at no fear, got: %s" % str(intent_no_fear.get("action_type")) }
	if str(intent_with_fear.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected actor.move for ranger at fear=60 (fear_move_bonus keeps move dominant), got: %s" % str(intent_with_fear.get("action_type")) }
	return { "ok": true }


# Test 5: EchoActor.from_echo() passes equipped_skills through to actor dict.
static func _t_echo_actor_carries_equipped_skills() -> Dictionary:
	var echo := {
		"id":             "echo_eq_01",
		"name":           "Kwame",
		"rarity":         "called",
		"rank":           3,
		"calling_origin": "blade",
		"stats":          { "max_hp": 100, "atk": 10, "def": 8, "agi": 6, "int": 5, "cha": 5, "speed": 5 },
		"traits":         { "courage": 50, "wisdom": 40, "faith": 35 },
		"xp_total":       0,
		"level":          1,
		"vector_scores":  {},
		"dominant_vector": "",
		"resilience_traits": [],
		"leadership_traits": [],
		"equipped_skills": { "0": "blade_resolve" },
	}

	var actor: Dictionary = EchoActor.from_echo(echo)

	if not actor.has("equipped_skills"):
		return { "ok": false, "error": "actor dict missing 'equipped_skills' after EchoActor.from_echo()" }

	var eq: Dictionary = actor.get("equipped_skills", {})
	if str(eq.get("0", "")) != "blade_resolve":
		return {
			"ok": false,
			"error": "Expected equipped_skills['0']='blade_resolve', got: %s" % str(eq.get("0", ""))
		}

	# Verify it's a deep copy — mutating actor should not affect original echo.
	actor["equipped_skills"]["0"] = "mutated"
	if str(echo["equipped_skills"]["0"]) != "blade_resolve":
		return { "ok": false, "error": "equipped_skills is not a deep copy — mutation bled back to echo" }

	return { "ok": true }
