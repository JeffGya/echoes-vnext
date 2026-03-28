# res://tests/ExclusiveActionTests.gd
# PROG-009: Validates that skill-gated action candidates are only generated when
# the relevant skill is equipped AND the runtime condition is met.
#
# Tests:
#   1. actor.press generated when blade_resolve equipped + last target matches adjacent enemy.
#   2. actor.press NOT generated (melee_attack wins) when blade_resolve not equipped.
#   3. actor.interpose generated when warders_vigil equipped + threatened ally present.
#   4. actor.interpose NOT generated (protect_ally wins) when vigil not equipped.
#
# All tests use BehaviorArbiter.new({}) with skills_cfg injected in context.

class_name ExclusiveActionTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("exclusive_action/press_when_equipped_and_hit_last_round",   Callable(ExclusiveActionTests, "_t_press_when_equipped"))
	runner.register_test("exclusive_action/no_press_when_not_equipped",                Callable(ExclusiveActionTests, "_t_no_press_when_not_equipped"))
	runner.register_test("exclusive_action/interpose_when_vigil_equipped",             Callable(ExclusiveActionTests, "_t_interpose_when_vigil_equipped"))
	runner.register_test("exclusive_action/no_interpose_when_vigil_not_equipped",      Callable(ExclusiveActionTests, "_t_no_interpose_when_vigil_not_equipped"))


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _skills_cfg() -> Dictionary:
	return {
		"definitions": {
			"blade_resolve": {
				"skill_id":            "blade_resolve",
				"calling_requirement": "blade",
				"display_name":        "Blade's Resolve",
				"target_type":         "enemy",
				"action_type":         "actor.press",
				"cooldown_rounds":     0,
				"scaling_source":      "atk",
				"intent_weight_tag":   "melee_attack",
				"tier_gate":           "",
			},
			"warders_vigil": {
				"skill_id":            "warders_vigil",
				"calling_requirement": "warder",
				"display_name":        "Warder's Vigil",
				"target_type":         "ally",
				"action_type":         "actor.interpose",
				"cooldown_rounds":     0,
				"scaling_source":      "def",
				"intent_weight_tag":   "protect_ally",
				"tier_gate":           "",
			},
		}
	}

static func _blade_actor(equipped_skill_id: String = "") -> Dictionary:
	var actor := {
		"id":                     "echo_blade_01",
		"faction":                "echo",
		"calling_origin":         "blade",
		"traits":                 { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":          {},
		"fear":                   0,
		"morale":                 50,
		"grid_pos":               { "col": 0, "row": 0 },
		"current_hp":             100,
		"stats":                  { "max_hp": 100 },
		"last_intent": { "action_type": "melee_attack", "target_id": "enemy_press_01" },
	}
	if not equipped_skill_id.is_empty():
		actor["equipped_skills"] = { "0": equipped_skill_id }
	return actor

static func _warder_actor(equipped_skill_id: String = "") -> Dictionary:
	var actor := {
		"id":             "echo_warder_01",
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
	if not equipped_skill_id.is_empty():
		actor["equipped_skills"] = { "0": equipped_skill_id }
	return actor

static func _adjacent_enemy() -> Dictionary:
	return {
		"id":       "enemy_press_01",
		"faction":  "enemy",
		"is_dead":  false,
		"grid_pos": { "col": 1, "row": 0 },
	}

static func _threatened_ally() -> Dictionary:
	return {
		"id":         "echo_ally_01",
		"faction":    "echo",
		"is_dead":    false,
		"current_hp": 25,
		"stats":      { "max_hp": 100 },
		"grid_pos":   { "col": 2, "row": 0 },
	}


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

# Test 1: actor.press generated when blade_resolve equipped + same target adjacent.
# blade_resolve gives skill_base_bonus = blade.melee_attack(65) + 15 = 80.
# echo_in_melee applies to both: press = 80+18 = 98 > regular melee = 65+18 = 83.
static func _t_press_when_equipped() -> Dictionary:
	var actor   := _blade_actor("blade_resolve")
	var enemy   := _adjacent_enemy()
	var arbiter := BehaviorArbiter.new({})
	var ctx := {
		"actor":        actor,
		"all_actors":   [enemy],
		"t":            1,
		"equipped_skills": actor.get("equipped_skills", {}),
		"skills_cfg":   _skills_cfg(),
	}
	var intent: Dictionary = arbiter.select_intent(ctx)

	if str(intent.get("action_type", "")) != "actor.press":
		return {
			"ok": false,
			"error": "Expected actor.press (press=98 > melee=83 via echo_in_melee), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 2: melee_attack selected when blade_resolve NOT equipped (actor.press candidate absent).
static func _t_no_press_when_not_equipped() -> Dictionary:
	var actor   := _blade_actor()  # no equipped_skills
	var enemy   := _adjacent_enemy()
	var arbiter := BehaviorArbiter.new({})
	var ctx := {
		"actor":      actor,
		"all_actors": [enemy],
		"t":          1,
		"equipped_skills": {},
		"skills_cfg":  _skills_cfg(),
	}
	var intent: Dictionary = arbiter.select_intent(ctx)

	if str(intent.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "Expected melee_attack when no skill equipped (no actor.press candidate), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 3: actor.interpose generated when warders_vigil equipped + threatened ally.
# vigil gives skill_base_bonus = warder.protect_ally(65) + 15 = 80 > protect_ally(65).
static func _t_interpose_when_vigil_equipped() -> Dictionary:
	var actor   := _warder_actor("warders_vigil")
	var enemy   := _adjacent_enemy()
	var ally    := _threatened_ally()
	var arbiter := BehaviorArbiter.new({})
	var ctx := {
		"actor":         actor,
		"all_actors":    [enemy, ally],
		"t":             1,
		"equipped_skills": actor.get("equipped_skills", {}),
		"skills_cfg":    _skills_cfg(),
	}
	var intent: Dictionary = arbiter.select_intent(ctx)

	if str(intent.get("action_type", "")) != "actor.interpose":
		return {
			"ok": false,
			"error": "Expected actor.interpose (skill_base=80 > protect_ally=65), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 4: protect_ally selected when warders_vigil NOT equipped (no interpose candidate).
static func _t_no_interpose_when_vigil_not_equipped() -> Dictionary:
	var actor   := _warder_actor()  # no equipped_skills
	var enemy   := _adjacent_enemy()
	var ally    := _threatened_ally()
	var arbiter := BehaviorArbiter.new({})
	var ctx := {
		"actor":      actor,
		"all_actors": [enemy, ally],
		"t":          1,
		"equipped_skills": {},
		"skills_cfg":  _skills_cfg(),
	}
	var intent: Dictionary = arbiter.select_intent(ctx)

	if str(intent.get("action_type", "")) != "protect_ally":
		return {
			"ok": false,
			"error": "Expected protect_ally when vigil not equipped, got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }
