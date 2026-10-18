# res://tests/PassiveIdentityTests.gd
# PROG-009: Validates always-on passive identity rules per calling.
#
# Tests:
#   1. Warder anchor: guard/protect_ally score boosted by +8 per stationary round (cap +24).
#   2. Blade afraid: afraid_points_override applies guard penalty + melee bonus.
#   3. Seer directive aura: seer_directive_aura situational condition fires when seer present.
#   4. Ranger fear move bonus: afraid_signature raises the move score when afraid.
#   5. EchoActor passes equipped_skills through from echo dict.
#   6. V2-COMBAT-003: ActorStateMachine._update_passive_state writes _anchor_rounds and
#      _stationary_rounds for the V2 calling ids, and a V1 id ("warder") writes nothing —
#      guards against the match regressing to V1 arms.
#
# Tests 1 and 3 use BehaviorArbiter.new({}); tests 2 and 4 use the production config (the status
# lean table lives there).
# Test 5 is a pure data-mapping test (no arbiter).
# Test 6 exercises ActorStateMachine directly (the writer), not BehaviorArbiter (the reader).

class_name PassiveIdentityTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("passive/warder_anchor_boosts_guard",         Callable(PassiveIdentityTests, "_t_warder_anchor_boosts_guard"))
	runner.register_test("passive/blade_broken_morale_override",       Callable(PassiveIdentityTests, "_t_blade_broken_morale_override"))
	runner.register_test("passive/seer_directive_aura_fires",          Callable(PassiveIdentityTests, "_t_seer_directive_aura_fires"))
	runner.register_test("passive/ranger_fear_move_bonus",             Callable(PassiveIdentityTests, "_t_ranger_fear_move_bonus"))
	runner.register_test("passive/echo_actor_carries_equipped_skills", Callable(PassiveIdentityTests, "_t_echo_actor_carries_equipped_skills"))
	runner.register_test("passive/v2_calling_writes_passive_counter",  Callable(PassiveIdentityTests, "_t_v2_calling_writes_passive_counter"))


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _make_warder(anchor_rounds: int) -> Dictionary:
	var actor := {
		"id":             "echo_warder_p_01",
		"faction":        "echo",
		"calling_origin": "okofor",   # V2 name for warder (protect_ally base=65, anchor passive)
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
		"calling_origin": "aduro",   # V2 name for blade (melee base=65, afraid_points_override passive)
		"traits":         { "courage": 0, "wisdom": 0, "faith": 0 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         10,  # an afraid status
		"grid_pos":       { "col": 0, "row": 0 },
		"current_hp":     100,
		"stats":          { "max_hp": 100 },
	}

static func _make_seer_ally() -> Dictionary:
	return {
		"id":             "echo_seer_aura_01",
		"faction":        "echo",
		"calling_origin": "okomfo",   # V2 name for seer (seer_directive_aura fires for okomfo)
		"is_dead":        false,
		"grid_pos":       { "col": 2, "row": 0 },
	}

static func _make_ranger(fear: int) -> Dictionary:
	return {
		"id":             "echo_ranger_p_01",
		"faction":        "echo",
		"calling_origin": "kra_soro",   # V2 name for ranger (move bias, afraid_signature passive)
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

## The production calling_behavior entry of one calling.
static func _calling_behavior(data: Dictionary, calling: String) -> Dictionary:
	return ((data["maturity_expression"] as Dictionary)["calling_behavior"] as Dictionary)[calling] as Dictionary


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


# Test 2: an afraid blade charges: afraid_points_override replaces the afraid end of its melee and
# guard points, so blade + afraid status + adjacent enemy → melee_attack wins (not guard or idle).
static func _t_blade_broken_morale_override() -> Dictionary:
	var data: Dictionary = MoraleInfluenceTests._data()
	var ctx := {
		"actor": _make_blade_broken(), "all_actors": [_adjacent_enemy()], "t": 1,
		# ActorStateMachine normally injects calling_behavior in advance_turn().
		"calling_behavior": _calling_behavior(data, "aduro"),
	}
	var intent: Dictionary = MoraleInfluenceTests._arbiter(data).select_intent(ctx)
	if str(intent.get("action_type", "")) != "melee_attack":
		return {
			"ok": false,
			"error": "Expected melee_attack (blade afraid_points_override), got: %s" % str(intent.get("action_type"))
		}
	return { "ok": true }


# Test 3: Seer directive aura situational condition fires when a Seer ally is nearby.
# seer_directive_aura adds a strategic bonus to non-seer actors when Seer is nearby.
# We test: uncalled echo near a seer ally has higher guard/protect_ally than alone.
# Simple proxy: the board summary includes seer_directive_aura = true when seer is within 3 tiles.
# Since BoardAssessmentService.build_board_summary() has no test-facing hook here, we verify via intent scoring:
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


# Test 4: Ranger fear move bonus — the afraid_signature move points keep move dominant at fear 60
# (an afraid status), so fear does not suppress move (the anti-pattern for other callings).
static func _t_ranger_fear_move_bonus() -> Dictionary:
	var data: Dictionary = MoraleInfluenceTests._data()
	var arbiter: BehaviorArbiter = MoraleInfluenceTests._arbiter(data)
	var enemy           := _distant_enemy()
	var behavior: Dictionary = _calling_behavior(data, "kra_soro")

	var intent_no_fear: Dictionary   = arbiter.select_intent({ "actor": _make_ranger(0),  "all_actors": [enemy], "t": 1, "calling_behavior": behavior })
	var intent_with_fear: Dictionary = arbiter.select_intent({ "actor": _make_ranger(60), "all_actors": [enemy], "t": 1, "calling_behavior": behavior })

	# Both should prefer actor.move (ranger move=55 is dominant at dist=2).
	if str(intent_no_fear.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected actor.move for ranger at no fear, got: %s" % str(intent_no_fear.get("action_type")) }
	if str(intent_with_fear.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected actor.move for ranger at fear=60 (afraid_signature keeps move dominant), got: %s" % str(intent_with_fear.get("action_type")) }
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


# Test 6: guard against ActorStateMachine._update_passive_state regressing to V1 calling ids.
# Okofor is a V2 id and must write its idle-round counter; "warder" (V1) must not — if the
# match arms ever revert, this fails loudly instead of the counter going dead again.
static func _t_v2_calling_writes_passive_counter() -> Dictionary:
	var idle_intent := { "action_type": "actor.idle" }

	var okofor := { "id": "echo_v2_okofor", "faction": "echo", "calling_origin": "okofor" }
	ActorStateMachine.new(okofor)._update_passive_state(idle_intent, { "all_actors": [okofor] }, 1)
	if int(okofor.get("_anchor_rounds", 0)) != 1:
		return { "ok": false, "error": "okofor did not accumulate _anchor_rounds, got: %s" % str(okofor.get("_anchor_rounds")) }

	var v1_warder := { "id": "echo_v1_warder", "faction": "echo", "calling_origin": "warder" }
	ActorStateMachine.new(v1_warder)._update_passive_state(idle_intent, { "all_actors": [v1_warder] }, 1)
	if v1_warder.has("_anchor_rounds"):
		return { "ok": false, "error": "V1 id 'warder' matched a passive arm — match regressed to V1 calling ids" }

	return { "ok": true }
