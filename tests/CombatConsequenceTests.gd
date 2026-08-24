# res://tests/CombatConsequenceTests.gd
# V2-COMBAT-001: Tests for combat consequence routing — guard, hesitation, bond bias, vow bias.
#   1. consequence/guard_sets_guard_state_on_self
#   2. consequence/interpose_sets_guard_state_on_ally_not_self
#   3. consequence/hesitating_status_at_fear_40
#   4. consequence/alive_status_at_fear_39
#   5. consequence/refusing_status_at_fear_80
#   6. consequence/neutral_bond_no_protect_bias
#   7. consequence/bond_friend_raises_protect_score
#   8. consequence/bond_rival_lowers_protect_score
#   9. consequence/vow_boosts_cohesion_actions
#  10. consequence/vow_penalizes_aggression_small_party
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatConsequenceTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("consequence/guard_sets_guard_state_on_self",
		Callable(CombatConsequenceTests, "_t_guard_sets_guard_state_on_self"))
	runner.register_test("consequence/interpose_sets_guard_state_on_ally_not_self",
		Callable(CombatConsequenceTests, "_t_interpose_sets_guard_state_on_ally_not_self"))
	runner.register_test("consequence/alive_status_at_fear_40",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_40"))
	runner.register_test("consequence/alive_status_at_fear_39",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_39"))
	runner.register_test("consequence/alive_status_at_fear_80",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_80"))
	runner.register_test("consequence/neutral_bond_no_protect_bias",
		Callable(CombatConsequenceTests, "_t_neutral_bond_no_protect_bias"))
	runner.register_test("consequence/bond_friend_raises_protect_score",
		Callable(CombatConsequenceTests, "_t_bond_friend_raises_protect_score"))
	runner.register_test("consequence/bond_rival_lowers_protect_score",
		Callable(CombatConsequenceTests, "_t_bond_rival_lowers_protect_score"))
	runner.register_test("consequence/vow_boosts_cohesion_actions",
		Callable(CombatConsequenceTests, "_t_vow_boosts_cohesion_actions"))
	runner.register_test("consequence/vow_penalizes_aggression_small_party",
		Callable(CombatConsequenceTests, "_t_vow_penalizes_aggression_small_party"))


# -------------------------
# Tests 1–2: Self-guard and interpose (V2-COMBAT-001 guard routing fix)
# -------------------------

# Test 1: actor.guard intent must set guard_state=true on the guarding actor itself.
static func _t_guard_sets_guard_state_on_self() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "guard_state": false }
	var sm := ActorStateMachine.new(actor)
	var intent := { "action_type": "actor.guard" }
	var context := { "all_actors": [actor], "cfg": {} }
	sm._update_passive_state(intent, context, 1)
	if not bool(actor.get("guard_state", false)):
		return { "ok": false, "error": "guard_state should be true after actor.guard, got: %s" % str(actor.get("guard_state")) }
	return { "ok": true }


# Test 2: actor.interpose sets guard_state on the protected ally, NOT on the interposer.
static func _t_interpose_sets_guard_state_on_ally_not_self() -> Dictionary:
	var actor_a := { "id": "echo_a", "faction": "echo" }
	var actor_b := { "id": "echo_b", "faction": "echo", "guard_state": false }
	var sm := ActorStateMachine.new(actor_a)
	var intent := { "action_type": "actor.interpose", "target_id": "echo_b" }
	var context := { "all_actors": [actor_a, actor_b], "cfg": {} }
	sm._update_passive_state(intent, context, 1)
	if not bool(actor_b.get("guard_state", false)):
		return { "ok": false, "error": "Ally echo_b should have guard_state=true after interpose" }
	if bool(actor_a.get("guard_state", false)):
		return { "ok": false, "error": "Interposer echo_a should NOT have guard_state=true" }
	return { "ok": true }


# -------------------------
# Tests 3–5: Hesitation band (_derive_status) — V2-COMBAT-001
# -------------------------

# Test 3: fear does not replace the operational actor status.
static func _t_alive_status_at_fear_40() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 40 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Fear must not replace operational status; got: '%s'" % status }
	return { "ok": true }


# Test 4: fear=39 → "alive" (below hesitation threshold).
static func _t_alive_status_at_fear_39() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 39 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Expected 'alive' at fear=39, got: '%s'" % status }
	return { "ok": true }


# Test 5: refusal is an action/event, not an operational actor status.
static func _t_alive_status_at_fear_80() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 80 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Refusal must not replace operational status; got: '%s'" % status }
	return { "ok": true }


# -------------------------
# Tests 6–8: Bond score bias in BehaviorArbiter (BOND-002 integration)
# -------------------------

static func _bond_thresholds() -> Dictionary:
	return { "rival_max": -30, "friend_min": 30 }


# Test 6: indifferent bond (strength=0) adds no bias to protect_ally score.
static func _t_neutral_bond_no_protect_bias() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 0 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if absf(new_score - base_score) > 0.001:
		return { "ok": false, "error": "Indifferent bond should not change score (expected %.1f, got %.1f)" % [base_score, new_score] }
	return { "ok": true }


# Test 7: friend bond (strength=50) raises protect_ally score by friend_bonus.
static func _t_bond_friend_raises_protect_score() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 50 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if new_score <= base_score:
		return { "ok": false, "error": "Friend bond should raise protect_ally score (expected > %.1f, got %.1f)" % [base_score, new_score] }
	if absf(new_score - (base_score + 12.0)) > 0.001:
		return { "ok": false, "error": "Friend bonus expected +12 (got %.1f)" % new_score }
	return { "ok": true }


# Test 8: rival bond (strength=-50) lowers protect_ally score by rival_penalty.
static func _t_bond_rival_lowers_protect_score() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": -50 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if new_score >= base_score:
		return { "ok": false, "error": "Rival bond should lower protect_ally score (expected < %.1f, got %.1f)" % [base_score, new_score] }
	if absf(new_score - (base_score - 10.0)) > 0.001:
		return { "ok": false, "error": "Rival penalty expected -10 (got %.1f)" % new_score }
	return { "ok": true }


# -------------------------
# Tests 9–10: Vow score bias in BehaviorArbiter (VOW-001 integration)
# -------------------------

# Test 9: tikoro_nko_agyina vow with full party (>=3) boosts protect_ally and actor.guard.
static func _t_vow_boosts_cohesion_actions() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var active_vow := { "vow_id": "tikoro_nko_agyina", "tier": 1 }
	var protect_base := 30.0
	var guard_base   := 20.0
	var candidates: Array = [
		{ "action_type": "protect_ally", "target_id": "echo_b", "_score": protect_base },
		{ "action_type": "actor.guard",  "target_id": "",       "_score": guard_base   },
	]
	arbiter._apply_vow_bias(candidates, active_vow, 3)  # party_size >= 3
	if float(candidates[0].get("_score", 0.0)) <= protect_base:
		return { "ok": false, "error": "protect_ally should be boosted by tikoro vow with full party (>=3)" }
	if float(candidates[1].get("_score", 0.0)) <= guard_base:
		return { "ok": false, "error": "actor.guard should be boosted by tikoro vow with full party (>=3)" }
	return { "ok": true }


# Test 10: tikoro_nko_agyina with small party (<3) penalizes melee_attack and actor.move.
static func _t_vow_penalizes_aggression_small_party() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var active_vow := { "vow_id": "tikoro_nko_agyina", "tier": 1 }
	var melee_base := 40.0
	var move_base  := 30.0
	var candidates: Array = [
		{ "action_type": "melee_attack", "target_id": "enemy_a", "_score": melee_base },
		{ "action_type": "actor.move",   "target_id": "enemy_a", "_score": move_base  },
	]
	arbiter._apply_vow_bias(candidates, active_vow, 2)  # party_size < 3
	if float(candidates[0].get("_score", 0.0)) >= melee_base:
		return { "ok": false, "error": "melee_attack should be penalized by tikoro vow with small party (<3)" }
	if float(candidates[1].get("_score", 0.0)) >= move_base:
		return { "ok": false, "error": "actor.move should be penalized by tikoro vow with small party (<3)" }
	return { "ok": true }
