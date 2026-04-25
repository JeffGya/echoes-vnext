# res://tests/BondTriggerTests.gd
# BOND-002: Tests for bond trigger logic, BehaviorArbiter bond bias, and aftermath modifiers.
#
# Tests are pure unit tests — no FlowRuntime, no file I/O, no live save data.
# Trigger delta values use the same defaults as balance.json bond_triggers (hardcoded
# in the test helpers to avoid config loading — consistent with SocialGraphTests pattern).

extends RefCounted
class_name BondTriggerTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("bond_trigger/stage_win_applies_delta",           Callable(BondTriggerTests, "_t_stage_win_applies_delta"))
	runner.register_test("bond_trigger/stage_defeat_applies_delta",        Callable(BondTriggerTests, "_t_stage_defeat_applies_delta"))
	runner.register_test("bond_trigger/archetype_incompat_applies_delta",  Callable(BondTriggerTests, "_t_archetype_incompat_applies_delta"))
	runner.register_test("bond_trigger/near_wipe_both_survive",            Callable(BondTriggerTests, "_t_near_wipe_both_survive"))
	runner.register_test("bond_trigger/near_wipe_one_ko_no_bonus",         Callable(BondTriggerTests, "_t_near_wipe_one_ko_no_bonus"))
	runner.register_test("bond_trigger/grief_modifier_on_bonded_ko",       Callable(BondTriggerTests, "_t_grief_modifier_on_bonded_ko"))
	runner.register_test("bond_trigger/rival_penalty_on_protect_candidate",Callable(BondTriggerTests, "_t_rival_penalty_on_protect_candidate"))
	runner.register_test("bond_trigger/friend_bonus_on_protect_candidate", Callable(BondTriggerTests, "_t_friend_bonus_on_protect_candidate"))


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

static func _thresholds() -> Dictionary:
	return { "rival_max": -30, "friend_min": 30 }

static func _rival_archetypes() -> Array:
	return [
		["proud", "empathic"],
		["valiant", "stoic"],
		["ambitious", "devout"],
		["canny", "loyal"],
	]


# ---------------------------------------------------------------------------
# Test 1: shared_stage_win fires +3 for a pair on victory
# ---------------------------------------------------------------------------
static func _t_stage_win_applies_delta() -> Dictionary:
	var bonds: Array = []
	var delta := 3  # matches balance.json bond_triggers.shared_stage_win
	bonds = SocialGraphService.apply_score_delta(bonds, "echo_a", "echo_b", delta, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	if edge.is_empty():
		return { "ok": false, "error": "Edge not created after win delta" }
	var strength := int(edge.get("strength", 0))
	if strength != 3:
		return { "ok": false, "error": "Expected strength=3 after shared_stage_win, got %d" % strength }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 2: stage_defeat_shared fires -3 for a pair on defeat
# ---------------------------------------------------------------------------
static func _t_stage_defeat_applies_delta() -> Dictionary:
	var bonds: Array = []
	var delta := -3  # matches balance.json bond_triggers.stage_defeat_shared
	bonds = SocialGraphService.apply_score_delta(bonds, "echo_a", "echo_b", delta, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	if edge.is_empty():
		return { "ok": false, "error": "Edge not created after defeat delta" }
	var strength := int(edge.get("strength", 0))
	if strength != -3:
		return { "ok": false, "error": "Expected strength=-3 after stage_defeat_shared, got %d" % strength }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 3: archetype_incompatible_shared_stage fires -5 for incompatible archetype pair
# ---------------------------------------------------------------------------
static func _t_archetype_incompat_applies_delta() -> Dictionary:
	# Confirm pair is recognised as incompatible
	if not SocialGraphService.is_rival_archetype_pair("proud", "empathic", _rival_archetypes()):
		return { "ok": false, "error": "proud+empathic not recognised as rival archetype pair" }

	var bonds: Array = []
	var delta := -5  # matches balance.json bond_triggers.archetype_incompatible_shared_stage
	bonds = SocialGraphService.apply_score_delta(bonds, "echo_a", "echo_b", delta, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	var strength := int(edge.get("strength", 0))
	if strength != -5:
		return { "ok": false, "error": "Expected strength=-5 after archetype_incompatible_shared_stage, got %d" % strength }

	# Confirm pair not recognised for a non-incompatible combo
	if SocialGraphService.is_rival_archetype_pair("proud", "loyal", _rival_archetypes()):
		return { "ok": false, "error": "proud+loyal incorrectly flagged as rival pair" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 4: near_wipe_survival_together fires +10 when both echoes survived a near-wipe
#
# Simulates: victory=true, another echo was KO'd (near-wipe), A and B both survived.
# ---------------------------------------------------------------------------
static func _t_near_wipe_both_survive() -> Dictionary:
	# Both echoes survived — near-wipe delta should apply
	var bonds: Array = []
	var near_wipe := true  # victory=true AND ko_ids not empty
	var a_ko := false
	var b_ko := false
	var nw_delta := 10  # matches balance.json bond_triggers.near_wipe_survival_together
	if near_wipe and not a_ko and not b_ko:
		bonds = SocialGraphService.apply_score_delta(bonds, "echo_a", "echo_b", nw_delta, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	var strength := int(edge.get("strength", 0))
	if strength != 10:
		return { "ok": false, "error": "Expected strength=10 after near_wipe_survival_together, got %d" % strength }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 5: near_wipe does NOT fire when one of the pair was KO'd
# ---------------------------------------------------------------------------
static func _t_near_wipe_one_ko_no_bonus() -> Dictionary:
	var bonds: Array = []
	var near_wipe := true
	var a_ko := true   # A was KO'd — pair is not "both survived"
	var b_ko := false
	var nw_delta := 10
	if near_wipe and not a_ko and not b_ko:
		bonds = SocialGraphService.apply_score_delta(bonds, "echo_a", "echo_b", nw_delta, _thresholds(), null, 0)
	# Bond should NOT have been mutated since A was KO'd
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	if not edge.is_empty():
		return { "ok": false, "error": "Edge was created — near_wipe delta incorrectly fired when one echo was KO'd" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 6: grief modifier applied when bonded echo was KO'd
#
# EmotionRecoveryService.set_modifier() writes morale_multiplier < 1.0 (grief).
# ---------------------------------------------------------------------------
static func _t_grief_modifier_on_bonded_ko() -> Dictionary:
	var echo: Dictionary = {
		"id": "echo_a",
		"emotion": { "morale_current": 50, "morale_base": 50, "fear_current": 10, "fear_base": 0 },
	}
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 40 }]

	# Verify the bond is classified as friend (strength=40 >= friend_min=30)
	var edge := SocialGraphService.get_edge(bonds, "echo_a", "echo_b")
	var bond_type := SocialGraphService.get_bond_type(int(edge.get("strength", 0)), _thresholds())
	if bond_type != "friend":
		return { "ok": false, "error": "Expected bond_type=friend for strength=40, got %s" % bond_type }

	# Apply grief modifier (echo_b was KO'd, echo_a survived and has a bond with echo_b)
	var grief_morale_mul := 0.5
	var grief_fear_mul   := 1.5
	var grief_ticks      := 3
	EmotionRecoveryService.set_modifier(echo, grief_morale_mul, grief_fear_mul, grief_ticks, null, 0)

	var rm_v: Variant = echo.get("recovery_modifiers", {})
	if not (rm_v is Dictionary):
		return { "ok": false, "error": "recovery_modifiers not set after set_modifier()" }
	var rm: Dictionary = rm_v
	if float(rm.get("morale_multiplier", 1.0)) != grief_morale_mul:
		return { "ok": false, "error": "morale_multiplier expected %.1f, got %.1f" % [grief_morale_mul, float(rm.get("morale_multiplier", 1.0))] }
	if float(rm.get("fear_multiplier", 1.0)) != grief_fear_mul:
		return { "ok": false, "error": "fear_multiplier expected %.1f, got %.1f" % [grief_fear_mul, float(rm.get("fear_multiplier", 1.0))] }
	if int(rm.get("ticks_remaining", 0)) != grief_ticks:
		return { "ok": false, "error": "ticks_remaining expected %d, got %d" % [grief_ticks, int(rm.get("ticks_remaining", 0))] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 7: rival_protect_penalty reduces _score on protect_ally targeting a rival
# ---------------------------------------------------------------------------
static func _t_rival_penalty_on_protect_candidate() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})

	var actor := {
		"id":      "echo_a",
		"faction": "echo",
	}
	# Rival bond: strength = -50 (well into rival range)
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": -50 }]
	var thresholds := _thresholds()

	# Build two protect_ally candidates: one targeting the rival (echo_b), one targeting neutral (echo_c)
	var candidate_rival := {
		"action_type": "protect_ally",
		"target_id":   "echo_b",
		"_score":      30.0,
	}
	var candidate_neutral := {
		"action_type": "protect_ally",
		"target_id":   "echo_c",
		"_score":      30.0,
	}
	var candidates: Array = [candidate_rival, candidate_neutral]

	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, thresholds, bond_cfg)

	var score_rival   := float(candidates[0].get("_score", 0.0))
	var score_neutral := float(candidates[1].get("_score", 0.0))

	if score_rival >= score_neutral:
		return { "ok": false, "error": "Rival protect_ally score (%s) should be lower than neutral (%s)" % [score_rival, score_neutral] }
	if abs(score_rival - (30.0 - 10.0)) > 0.001:
		return { "ok": false, "error": "Rival protect_ally score expected 20.0 (30-10), got %s" % score_rival }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Test 8: friend_protect_weight_bonus increases _score on protect_ally targeting a friend
# ---------------------------------------------------------------------------
static func _t_friend_bonus_on_protect_candidate() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})

	var actor := {
		"id":      "echo_a",
		"faction": "echo",
	}
	# Friend bond: strength = 50 (well into friend range)
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 50 }]
	var thresholds := _thresholds()

	var candidate_friend := {
		"action_type": "protect_ally",
		"target_id":   "echo_b",
		"_score":      30.0,
	}
	var candidate_neutral := {
		"action_type": "protect_ally",
		"target_id":   "echo_c",
		"_score":      30.0,
	}
	var candidates: Array = [candidate_friend, candidate_neutral]

	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, thresholds, bond_cfg)

	var score_friend  := float(candidates[0].get("_score", 0.0))
	var score_neutral := float(candidates[1].get("_score", 0.0))

	if score_friend <= score_neutral:
		return { "ok": false, "error": "Friend protect_ally score (%s) should be higher than neutral (%s)" % [score_friend, score_neutral] }
	if abs(score_friend - (30.0 + 12.0)) > 0.001:
		return { "ok": false, "error": "Friend protect_ally score expected 42.0 (30+12), got %s" % score_friend }
	return { "ok": true }
