class_name MovementArbitrationTests
extends RefCounted

const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const ActorFact = preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const OptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement_arbiter/production_golden", _t_production_golden)
	runner.register_test("movement_arbiter/perceived_boundary", _t_perceived_boundary)
	runner.register_test("movement_arbiter/perceived_mismatch_permutations", _t_perceived_mismatch_permutations)
	runner.register_test("movement_arbiter/recursive_insertion_reversal", _t_recursive_insertion_reversal)
	runner.register_test("movement_arbiter/unknown_targets", _t_unknown_targets)
	runner.register_test("movement_arbiter/invalid_before_caps", _t_invalid_before_caps)
	runner.register_test("movement_arbiter/canonical_and_reversed", _t_canonical_and_reversed)
	runner.register_test("movement_arbiter/full_tie_and_stationary", _t_full_tie_and_stationary)
	runner.register_test("movement_arbiter/route_without_legacy_move", _t_route_without_legacy_move)
	runner.register_test("movement_arbiter/spatial_base_terms", _t_spatial_base_terms)
	runner.register_test("movement_arbiter/spatial_directive_terms", _t_spatial_directive_terms)
	runner.register_test("movement_arbiter/spatial_clamp_indicators", _t_spatial_clamp_indicators)
	runner.register_test("movement_arbiter/config_failures", _t_config_failures)
	runner.register_test("movement_arbiter/metric_capacity_failures", _t_metric_capacity_failures)
	runner.register_test("movement_arbiter/identity_one_factor", _t_identity_one_factor)
	runner.register_test("movement_arbiter/ten_virtues", _t_ten_virtues)
	runner.register_test("movement_arbiter/maturity_skill_passive", _t_maturity_skill_passive)
	runner.register_test("movement_arbiter/vow_bond_order", _t_vow_bond_order)
	runner.register_test("movement_arbiter/final_score_finite", _t_final_score_finite)
	runner.register_test("movement_arbiter/purifier_authority", _t_purifier_authority)
	runner.register_test("movement_arbiter/unmatched_payload_policy", _t_unmatched_payload_policy)
	runner.register_test("movement_arbiter/mirrored_intent", _t_mirrored_intent)
	runner.register_test("movement_arbiter/truncated_option_keeps_planned_primary", _t_truncated_option_keeps_planned_primary)


static func _t_production_golden() -> Dictionary:
	var actor: Dictionary = _actor()
	var enemy: Dictionary = _enemy("enemy.a", {"col": 3, "row": 0})
	var arbiter := BehaviorArbiter.new({})
	var actual: Dictionary = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 1})
	# V2-PROG-012 Phase 4: select_intent() now also attaches `_divergence_probe`
	# (score components for DivergenceDetector) to the winner — see BehaviorArbiter's
	# select_intent(). Context here carries no directive, so directive_bonus is 0.0
	# everywhere and the probe carries no live directive tension; it is still
	# attached (only a hard 9999.0 score override skips it) so the golden pins it too.
	# V2-PROG-012 Phase 4 fix: `directive_preferred` (a single dict) was replaced by
	# `directive_candidates` (the FULL directive_bonus-descending ranking — see
	# BehaviorArbiter's _rank_directive_candidates()) plus `decision_scale`. With no
	# directive, every candidate's directive_bonus ties at 0.0, so the ranking's
	# tie-break (action_type, ascending) decides order — not "first encountered by
	# score" — which is why actor.idle sorts before actor.move below despite
	# actor.move being the higher-scoring winner.
	var expected: Dictionary = {
		"action_type": "actor.move", "target_id": "enemy.a", "target_pos": {"col": 3, "row": 0},
		"target_distance": 3, "target_hp_ratio": 1.0, "priority": 1.0,
		"morale_tier": "steady", "morale_modifier": 0, "archetype_birth": "", "archetype_modifier": 0,
		"_divergence_probe": {
			"chosen": {
				"action_type": "actor.move", "target_id": "enemy.a", "score": 44.0,
				"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				"components": {
					"base": 44.0, "trait_bonus": 0.0, "vector_bonus": 0.0, "archetype_bonus": 0.0,
					"morale_bonus": 0.0, "fear_factor": 1.0, "calling_mul": 1.0,
					"directive_bonus": 0.0, "situational_bonus": 0.0,
				},
			},
			"directive_candidates": [
				{
					"action_type": "actor.idle", "target_id": "", "score": 8.0,
					"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				},
				{
					"action_type": "actor.move", "target_id": "enemy.a", "score": 44.0,
					"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				},
			],
			"decision_scale": 36.0,
		},
	}
	if actual != expected:
		return _fail("Production golden changed: %s" % str(actual))
	actor["calling_origin"] = "onyamesu"
	actor["fear"] = 100
	enemy["grid_pos"] = {"col": 1, "row": 0}
	actual = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 2})
	# melee_attack's ranked-candidate score (39.77) is a genuine arithmetic result
	# (not a clean decimal literal), so it lands on a double a few ULPs off whatever
	# GDScript's own "39.77" literal parses to — is_equal_approx it separately, then
	# normalize it in `actual` so the single exact-equality dict compare below still
	# works for every other (exact) field.
	var stationary_candidates: Array = ((actual.get("_divergence_probe", {}) as Dictionary).get("directive_candidates", []) as Array)
	for candidate_v: Variant in stationary_candidates:
		var candidate: Dictionary = candidate_v as Dictionary
		if str(candidate.get("action_type", "")) == "melee_attack":
			if not is_equal_approx(float(candidate.get("score", 0.0)), 39.77):
				return _fail("melee_attack ranked-candidate score drifted: %s" % str(candidate.get("score", 0.0)))
			candidate["score"] = 39.77
	var expected_stationary: Dictionary = {
		"action_type": "actor.guard", "target_id": "", "priority": 0.0,
		"morale_tier": "steady", "morale_modifier": 0, "archetype_birth": "", "archetype_modifier": 0,
		"_divergence_probe": {
			"chosen": {
				"action_type": "actor.guard", "target_id": "", "score": 50.0,
				"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				"components": {
					"base": 55.0, "trait_bonus": 0.0, "vector_bonus": 0.0, "archetype_bonus": 0.0,
					"morale_bonus": 0.0, "fear_factor": 1.0, "calling_mul": 1.0,
					"directive_bonus": 0.0, "situational_bonus": -5.0,
				},
			},
			"directive_candidates": [
				{
					"action_type": "actor.guard", "target_id": "", "score": 50.0,
					"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				},
				{
					"action_type": "actor.idle", "target_id": "", "score": -4.0,
					"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				},
				{
					"action_type": "melee_attack", "target_id": "enemy.a", "score": 39.77,
					"directive_bonus": 0.0, "directive_bonus_nascent": 0.0,
				},
			],
			"decision_scale": 54.0,
		},
	}
	if actual != expected_stationary:
		return _fail("Stationary production golden changed: %s" % str(actual))
	return _pass()


static func _t_perceived_boundary() -> Dictionary:
	var fixture: Dictionary = _fixture()
	var base: Dictionary = _select(fixture)
	var hidden: Dictionary = _enemy("hidden.z", {"col": 1, "row": 2})
	hidden["current_hp"] = 1
	(fixture["context"] as Dictionary)["all_actors"].append(hidden)
	var filtered: Dictionary = _select(fixture)
	if base != filtered:
		return _fail("Hidden actor changed arbitration: %s / %s" % [base, filtered])
	var duplicate: Dictionary = fixture.duplicate(true)
	(duplicate["context"] as Dictionary)["all_actors"].append((duplicate["context"] as Dictionary)["all_actors"][0])
	if str(_select(duplicate)["reason"]) != "duplicate_all_actor_id":
		return _fail("Duplicate all_actors ID accepted")
	var empty_id: Dictionary = fixture.duplicate(true)
	(empty_id["context"] as Dictionary)["all_actors"][0]["id"] = ""
	if str(_select(empty_id)["reason"]) != "empty_all_actor_id":
		return _fail("Empty all_actors ID accepted")
	var mismatch: Dictionary = fixture.duplicate(true)
	(mismatch["context"] as Dictionary)["all_actors"][0]["grid_pos"] = {"col": 4, "row": 0}
	if str(_select(mismatch)["reason"]) != "perceived_actor_position_mismatch":
		return _fail("Perceived position mismatch accepted")
	return _pass()


static func _t_perceived_mismatch_permutations() -> Dictionary:
	var base: Dictionary = _fixture()
	_add_visible_actor(base, _ally(), "friendly")
	var enemy: Dictionary = (base["context"] as Dictionary)["all_actors"][0]
	var ally: Dictionary = (base["context"] as Dictionary)["all_actors"][1]
	var malformed_cases: Array = [
		[["not-an-actor", enemy, ally], "invalid_all_actor_type", "context.all_actors"],
		[[{"id": ""}, enemy, ally], "empty_all_actor_id", "context.all_actors.id"],
		[[enemy, enemy.duplicate(true), ally], "duplicate_all_actor_id", "context.all_actors.enemy.a.id"],
		[[{"id": ""}, 7, enemy, ally], "invalid_all_actor_type", "context.all_actors"],
	]
	for case_value: Variant in malformed_cases:
		var case: Array = case_value as Array
		var fixture: Dictionary = base.duplicate(true)
		fixture["context"]["all_actors"] = (case[0] as Array).duplicate(true)
		var reversed: Dictionary = fixture.duplicate(true)
		(reversed["context"]["all_actors"] as Array).reverse()
		var result: Dictionary = _select(fixture)
		var reversed_result: Dictionary = _select(reversed)
		if result != reversed_result or str(result["reason"]) != str(case[1]) or str(result["field"]) != str(case[2]):
			return _fail("Malformed all_actors permutation differed: %s / %s" % [result, reversed_result])
	var mismatch_cases: Array = [
		["grid_pos", {"col": 4, "row": 0}, "perceived_actor_position_mismatch", "grid_pos"],
		["is_dead", true, "perceived_actor_state_mismatch", "is_dead"],
		["is_ko", true, "perceived_actor_state_mismatch", "is_ko"],
		["is_structure", true, "perceived_actor_state_mismatch", "is_structure"],
		["is_spirit", true, "perceived_actor_state_mismatch", "is_spirit"],
		["is_quarry", true, "perceived_actor_state_mismatch", "is_quarry"],
		["controlling_state", false, "perceived_actor_state_mismatch", "controlling_state"],
		["actor_type", "spirit", "perceived_actor_kind_mismatch", "kind"],
		["current_hp", 50, "perceived_actor_health_mismatch", "health_ratio"],
	]
	for case_value: Variant in mismatch_cases:
		var case: Array = case_value as Array
		var fixture: Dictionary = base.duplicate(true)
		var changed_enemy: Dictionary = fixture["context"]["all_actors"][0]
		changed_enemy[str(case[0])] = case[1]
		var reversed: Dictionary = fixture.duplicate(true)
		(reversed["context"]["all_actors"] as Array).reverse()
		(reversed["movement_context"]["perceived_actors"] as Array).reverse()
		var result: Dictionary = _select(fixture)
		var reversed_result: Dictionary = _select(reversed)
		var expected_field: String = "context.all_actors.enemy.a.%s" % str(case[3])
		if result != reversed_result or str(result["reason"]) != str(case[2]) or str(result["field"]) != expected_field:
			return _fail("Perceived mismatch permutation differed for %s: %s / %s" % [str(case[0]), result, reversed_result])
	return _pass()


static func _t_recursive_insertion_reversal() -> Dictionary:
	var fixture: Dictionary = _fixture()
	_add_visible_actor(fixture, _ally(), "friendly")
	var payload: Dictionary = {
		"candidate": {
			"skill_id": "skill.route_identity",
			"layers": [{"calling": "uncalled", "virtue": "strategist"}],
		},
	}
	fixture["goals"][0]["planned_primary"] = ActionPlan.build("actor.move", "enemy.a", payload)
	fixture["options"] = [_option(
		fixture["goals"][0],
		"direct",
		{"col": 2, "row": 0},
		[{"col": 1, "row": 0}, {"col": 2, "row": 0}],
		2,
		1.0
	)]
	fixture["movement_context"]["objective_pressure"] = {
		"regions": [{"cells": [{"row": 0, "col": 2}], "source": "objective.a"}],
	}
	var canonical: Dictionary = _select(fixture)
	var reversed: Dictionary = _reverse_recursive(fixture) as Dictionary
	(reversed["context"]["all_actors"] as Array).reverse()
	(reversed["movement_context"]["perceived_actors"] as Array).reverse()
	var reversed_result: Dictionary = _select(reversed)
	if canonical != reversed_result:
		return _fail("Recursive insertion reversal changed selected intent: %s / %s" % [canonical, reversed_result])
	if not bool(canonical["valid"]) or (canonical["intent"]["planned_action"]["payload"] as Dictionary) != payload:
		return _fail("Nested action payload was not preserved through recursive reversal")
	return _pass()


static func _t_unknown_targets() -> Dictionary:
	var fixture: Dictionary = _fixture()
	var goal: Dictionary = (fixture["goals"][0] as Dictionary).duplicate(true)
	goal["relevant_actors"] = ["hidden.z"]
	goal["planned_primary"] = ActionPlan.build("actor.move", "hidden.z")
	fixture["goals"] = [goal]
	fixture["options"] = [_option(goal, "direct", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], 2, 1.0)]
	var result: Dictionary = _select(fixture)
	if str(result["reason"]) != "unknown_relevant_actor":
		return _fail("Unknown relevant actor was not rejected first: %s" % str(result))
	goal["relevant_actors"] = ["enemy.a"]
	result = _select(fixture)
	if str(result["reason"]) != "invalid_goal.invalid_primary_target":
		return _fail("Unknown plan target accepted: %s" % str(result))
	return _pass()


static func _t_invalid_before_caps() -> Dictionary:
	var fixture: Dictionary = _fixture()
	var invalid: Dictionary = (fixture["goals"][0] as Dictionary).duplicate(true)
	invalid["goal_id"] = "goal.combat.advance.not_a_role.c2r0"
	var goals: Array = [invalid]
	for index: int in range(3):
		var goal: Dictionary = (fixture["goals"][0] as Dictionary).duplicate(true)
		goal["goal_id"] = "goal.combat.advance.%s.c2r0" % ["baseline", "vanguard", "watcher"][index]
		goals.append(goal)
	var result: Dictionary = _select(fixture, {}, [], goals)
	if not str(result["reason"]).begins_with("invalid_goal.invalid_goal_role"):
		return _fail("Goal cap hid an invalid goal: %s" % str(result))
	var option: Dictionary = (fixture["options"][0] as Dictionary).duplicate(true)
	option["capacity"] = 3
	var options: Array = [option]
	for style: String in ["safe", "cohesive", "lateral", "screen"]:
		var extra: Dictionary = (fixture["options"][0] as Dictionary).duplicate(true)
		extra["option_id"] = str(extra["option_id"]).replace(".direct.", ".%s." % style)
		options.append(extra)
	result = _select(fixture, {}, options)
	if str(result["reason"]) != "option_capacity_mismatch":
		return _fail("Option cap hid an invalid candidate: %s" % str(result))
	return _pass()


static func _t_canonical_and_reversed() -> Dictionary:
	var fixture: Dictionary = _fixture_two_goals()
	var canonical: Dictionary = _select(fixture)
	var reversed: Dictionary = fixture.duplicate(true)
	(reversed["context"] as Dictionary)["all_actors"].reverse()
	(reversed["movement_context"] as Dictionary)["perceived_actors"].reverse()
	reversed["movement_context"] = _reverse_nested(reversed["movement_context"] as Dictionary)
	var reversed_result: Dictionary = _select(reversed)
	if canonical != reversed_result:
		return _fail("Actor/nested insertion reversal changed output: %s / %s" % [canonical, reversed_result])
	var bad_options: Array = (fixture["options"] as Array).duplicate(true)
	bad_options.reverse()
	var failure_a: Dictionary = _select(fixture, {}, bad_options)
	var insertion_fixture: Dictionary = fixture.duplicate(true)
	var reversed_bad: Array = []
	for value: Variant in bad_options:
		reversed_bad.append(_reverse_dictionary(value as Dictionary))
	var failure_b: Dictionary = _select(insertion_fixture, {}, reversed_bad)
	if failure_a != failure_b or str(failure_a["reason"]) != "non_canonical_option_order":
		return _fail("Candidate reversal failure was not exact: %s / %s" % [failure_a, failure_b])
	return _pass()


static func _t_full_tie_and_stationary() -> Dictionary:
	var fixture: Dictionary = _fixture_two_goals()
	var result: Dictionary = _select(fixture)
	if not bool(result["valid"]) or str((result["intent"] as Dictionary)["goal_id"]) != "goal.combat.advance.baseline.c2r0":
		return _fail("Full tie order failed: %s" % str(result))
	var origin: Dictionary = fixture["movement_context"]["origin"]
	var hold: Dictionary = _goal("hold", "baseline", origin, "", "actor.guard")
	fixture["goals"] = [hold]
	fixture["options"] = [_option(hold, "direct", origin, [], 0, 1.0)]
	(fixture["context"] as Dictionary)["actor"]["calling_origin"] = "onyamesu"
	result = _select(fixture)
	var intent: Dictionary = result["intent"] as Dictionary
	if str(intent["goal_id"]) != "goal.legacy.stationary.actor_guard.c0r0" or intent["path"] != [] or intent["pressure_sources"] != []:
		return _fail("Stationary normalization failed: %s" % str(result))
	return _pass()


static func _t_route_without_legacy_move() -> Dictionary:
	var fixture: Dictionary = _fixture()
	(fixture["context"] as Dictionary)["all_actors"] = []
	var result: Dictionary = _select(fixture)
	if not bool(result["valid"]) or (result["intent"] as Dictionary)["path"] == []:
		return _fail("Perceived objective route did not compete without legacy move: %s" % str(result))
	return _pass()


static func _t_spatial_base_terms() -> Dictionary:
	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var cases: Array = [
		["urgency", 4.0],
		["objective_progress", 8.0],
		["cohesion", 4.0],
		["exposure", -6.0],
		["congestion", -2.0],
		["commitment", -2.0],
	]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var goal: Dictionary = {"urgency": 0.0, "purpose": "advance"}
		var option: Dictionary = {"objective_progress": 0.0, "cohesion": 0.0, "exposure": 0.0, "congestion": 0.0, "commitment": 0, "capacity": 4}
		if str(case[0]) == "urgency":
			goal["urgency"] = 1.0
		elif str(case[0]) == "commitment":
			option["commitment"] = 4
		else:
			option[str(case[0])] = 1.0
		var actual: float = arbiter._spatial_utility(goal, option, {}, cfg)
		if not is_equal_approx(actual, float(case[1])):
			return _fail("Base spatial coefficient %s differed: %s != %s" % [str(case[0]), actual, float(case[1])])
	return _pass()


static func _t_spatial_directive_terms() -> Dictionary:
	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var option: Dictionary = {"objective_progress": 0.5, "cohesion": 0.0, "exposure": 0.5, "congestion": 0.0, "commitment": 1, "capacity": 4}
	var cases: Array = [
		["objective_advance_priority", "advance", 2.0],
		["avoid_overcommit", "advance", 1.5],
		["exposure_acceptance", "advance", 1.0],
		["ally_protection_bias", "protect", 2.0],
		["threat_interception", "intercept", 2.0],
	]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var goal: Dictionary = {"urgency": 0.0, "purpose": str(case[1])}
		var base: float = arbiter._spatial_utility(goal, option, {}, cfg)
		var with_weight: float = arbiter._spatial_utility(goal, option, {"intent_weights": {str(case[0]): 1.0}}, cfg)
		if not is_equal_approx(with_weight - base, float(case[2])):
			return _fail("Directive term %s was not exact: %s" % [str(case[0]), with_weight - base])
		var positive_clamp: float = arbiter._spatial_utility(goal, option, {"intent_weights": {str(case[0]): 999.0}}, cfg)
		var negative: float = arbiter._spatial_utility(goal, option, {"intent_weights": {str(case[0]): -1.0}}, cfg)
		var negative_clamp: float = arbiter._spatial_utility(goal, option, {"intent_weights": {str(case[0]): -999.0}}, cfg)
		if not is_equal_approx(positive_clamp, with_weight) or not is_equal_approx(negative_clamp, negative):
			return _fail("Directive term %s did not clamp at +/-1 before the utility cap" % str(case[0]))
	return _pass()


static func _t_spatial_clamp_indicators() -> Dictionary:
	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var option: Dictionary = {"objective_progress": 1.0, "cohesion": 1.0, "exposure": 0.0, "congestion": 0.0, "commitment": 0, "capacity": 4}
	if arbiter._spatial_utility({"urgency": 1.0, "purpose": "advance"}, option, {"intent_weights": {"objective_advance_priority": 999}}, cfg) != 20.0:
		return _fail("Positive spatial cap or directive clamp failed")
	option = {"objective_progress": 0.0, "cohesion": 0.0, "exposure": 1.0, "congestion": 1.0, "commitment": 4, "capacity": 4}
	var negative_cfg: Dictionary = cfg.duplicate(true)
	negative_cfg["exposure_weight"] = -100.0
	if arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, option, {}, negative_cfg) != -20.0:
		return _fail("Negative spatial cap failed")
	var base: float = arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, option, {}, cfg)
	var protect: float = arbiter._spatial_utility({"urgency": 0.0, "purpose": "protect"}, option, {"intent_weights": {"ally_protection_bias": 1.0}}, cfg)
	var cut_off: float = arbiter._spatial_utility({"urgency": 0.0, "purpose": "cut_off"}, option, {"intent_weights": {"threat_interception": 1.0}}, cfg)
	if not is_equal_approx(protect - base, 2.0) or not is_equal_approx(cut_off - base, 2.0):
		return _fail("Ip/Ii exact-purpose indicators failed")
	var false_protect: float = arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, option, {"intent_weights": {"ally_protection_bias": 1.0}}, cfg)
	var false_intercept: float = arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, option, {"intent_weights": {"threat_interception": 1.0}}, cfg)
	if not is_equal_approx(false_protect, base) or not is_equal_approx(false_intercept, base):
		return _fail("Ip/Ii produced a false-positive outside their purpose sets")
	return _pass()


static func _t_config_failures() -> Dictionary:
	var fixture: Dictionary = _fixture()
	var cases: Array = [
		[{}, "missing_spatial_utility_config"],
		[{"spatial_utility": {}}, "missing_spatial_utility_field"],
		[_cfg_edit("cap", "bad"), "invalid_spatial_utility_field"],
		[_cfg_edit("cap", NAN), "invalid_spatial_utility_field"],
		[_cfg_edit("cap", 0.0), "non_positive_spatial_cap"],
	]
	var unexpected: Dictionary = _spatial_cfg()
	unexpected["spatial_utility"]["extra"] = 1.0
	cases.append([unexpected, "unexpected_spatial_config_field"])
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		fixture["movement_cfg"] = case[0]
		var result: Dictionary = _select(fixture)
		if str(result["reason"]) != str(case[1]):
			return _fail("Config failure mismatch: %s" % str(result))
	return _pass()


static func _t_metric_capacity_failures() -> Dictionary:
	var fixture: Dictionary = _fixture()
	for field: String in ["exposure", "congestion", "cohesion", "objective_progress"]:
		var bad: Dictionary = (fixture["options"][0] as Dictionary).duplicate(true)
		bad[field] = NAN
		var result: Dictionary = _select(fixture, {}, [bad])
		if not str(result["reason"]).begins_with("invalid_option.non_finite_number"):
			return _fail("Nonfinite metric %s accepted: %s" % [field, result])
	var wrong: Dictionary = (fixture["options"][0] as Dictionary).duplicate(true)
	wrong["exposure"] = "bad"
	if not str(_select(fixture, {}, [wrong])["reason"]).begins_with("invalid_option.wrong_type"):
		return _fail("Wrong metric type accepted")
	var zero_profile: Dictionary = ProfileContract.build(0, [], false, "structure", {})
	fixture["profile"] = zero_profile
	if str(_select(fixture)["reason"]) != "non_positive_capacity":
		return _fail("Zero arbitration capacity accepted")
	return _pass()


static func _t_identity_one_factor() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor: Dictionary = _actor()
	var candidate: Dictionary = {"target_hp_ratio": 1.0}
	var base: float = arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0)
	actor["calling_origin"] = "aduro"
	if arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) <= base:
		return _fail("Calling factor missing")
	actor = _actor(); actor["traits"] = {"courage": 10}
	# V2-PROG-012 Phase 6: this pins the RAW (unscaled) trait_action_muls table
	# value (courage 0.35 * 10 = 3.5) — identity_weight_scale's amplification is
	# now driven by `judgment` (default 0.3 when omitted, not 0.0 like the
	# rank_strength=0.0 passed above), so judgment=0.0 must be passed explicitly
	# here to keep interpretation_width at its floor (no amplification) and this
	# exact-equality assertion meaningful.
	if not is_equal_approx(arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0, 0.4, 0.0) - base, 3.5):
		return _fail("Trait factor missing")
	actor = _actor(); actor["archetype_birth"] = "valiant"
	if not is_equal_approx(arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) - base, 20.0):
		return _fail("Archetype factor missing")
	actor = _actor(); actor["fear"] = 100
	if arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) >= base:
		return _fail("Fear factor missing")
	actor = _actor(); actor["morale"] = 80
	if arbiter._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) <= base:
		return _fail("Morale factor missing")
	var directive: Dictionary = {"intent_weights": {"objective_advance_priority": 1.0}}
	if arbiter._score("actor.move", _actor(), directive, {}, "nascent", {}, candidate, 0.1, 0.0) <= base:
		return _fail("Legacy Directive factor missing")
	if arbiter._score("actor.move", _actor(), {}, {"active_conditions": ["enemy_far"]}, "nascent", {}, candidate, 0.1, 0.0) <= base:
		return _fail("Situation factor missing")
	return _pass()


static func _t_ten_virtues() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var expected: Dictionary = {"vanguard": 0.4, "protector": 0.05, "seeker": 0.1, "pillar": 0.0, "strategist": 0.15, "skeptic": 0.05, "devoted": 0.0, "opportunist": 0.3, "mediator": 0.05, "nurturer": 0.0}
	var base: float = arbiter._score("actor.move", _actor(), {}, {}, "nascent", {}, {}, 0.1, 0.0)
	# V2-PROG-012 Phase 6: judgment=0.0 pins interpretation_width at its floor (no
	# identity_weight_scale amplification) so `delta` below reproduces the RAW
	# vector_action_muls table values — see the equivalent note in
	# _t_identity_one_factor above for why the default judgment (0.3) would
	# otherwise silently scale these exact-equality deltas.
	for virtue: String in expected:
		var actor: Dictionary = _actor()
		actor["vector_scores"] = {virtue: 10}
		var delta: float = arbiter._score("actor.move", actor, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.4, 0.0) - base
		if not is_equal_approx(delta, 10.0 * float(expected[virtue])):
			return _fail("Virtue %s factor mismatch: %s" % [virtue, delta])
	return _pass()


static func _t_maturity_skill_passive() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor: Dictionary = _actor()
	var wounded: Dictionary = {"target_hp_ratio": 0.1}
	var nascent: float = arbiter._score("melee_attack", actor, {}, {}, "nascent", {}, wounded, 0.1, 0.0)
	var forming: float = arbiter._score("melee_attack", actor, {}, {}, "forming", {}, wounded, 0.25, 0.25)
	if forming <= nascent:
		return _fail("Maturity wound-chase factor missing")
	actor["calling_origin"] = "kra_soro"; actor["fear"] = 50
	var no_passive: float = arbiter._score("actor.move", actor, {}, {}, "nascent", {}, {}, 0.1, 0.0)
	var passive: float = arbiter._score("actor.move", actor, {}, {}, "nascent", {"fear_move_bonus": 20.0}, {}, 0.1, 0.0)
	if passive <= no_passive:
		return _fail("Calling passive factor missing")
	var fixture: Dictionary = _fixture()
	(fixture["context"] as Dictionary)["actor"]["equipped_skills"] = {"active": "read"}
	(fixture["context"] as Dictionary)["context_dummy"] = true
	(fixture["context"] as Dictionary)["skills_cfg"] = {"definitions": {"read": {"action_type": "actor.read_field", "intent_weight_tag": "read_field_test"}}}
	fixture["actor_cfg"] = {"intent_weights_by_calling_origin": {"uncalled": {"read_field_test": 100.0}}}
	var result: Dictionary = _select(fixture)
	if str(((result["intent"] as Dictionary)["planned_action"] as Dictionary)["type"]) != "actor.read_field":
		return _fail("Skill candidate metadata/pool was not preserved: %s" % str(result))
	return _pass()


static func _t_vow_bond_order() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var baseline: Array = [
		{"action_type": "protect_ally", "target_id": "ally.a", "_score": 7.0},
		{"action_type": "actor.guard", "target_id": "", "_score": 10.0},
	]
	var vow_only: Array = baseline.duplicate(true)
	arbiter._apply_vow_bias(vow_only, {"vow_id": "tikoro_nko_agyina", "tier": 1}, 3)
	var bond_only: Array = baseline.duplicate(true)
	arbiter._apply_bond_bias(bond_only, _actor(), [{"actor_a": "ally.a", "actor_b": "echo.a", "strength": -60}], {"friend_threshold": 40, "rival_threshold": -40}, {"friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0})
	var both: Array = baseline.duplicate(true)
	arbiter._apply_vow_bias(both, {"vow_id": "tikoro_nko_agyina", "tier": 1}, 3)
	arbiter._apply_bond_bias(both, _actor(), [{"actor_a": "ally.a", "actor_b": "echo.a", "strength": -60}], {"friend_threshold": 40, "rival_threshold": -40}, {"friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0})
	if float(baseline[0]["_score"]) >= float(baseline[1]["_score"]):
		return _fail("Baseline matrix fixture did not prefer guard")
	if float(vow_only[0]["_score"]) <= float(vow_only[1]["_score"]):
		return _fail("Vow-only matrix did not transition to protect")
	if float(bond_only[0]["_score"]) >= float(bond_only[1]["_score"]):
		return _fail("Bond-only rival matrix did not preserve guard")
	if float(both[0]["_score"]) >= float(both[1]["_score"]):
		return _fail("Bond applied after vow did not oppose and reverse the vow-only transition")
	return _pass()


static func _t_final_score_finite() -> Dictionary:
	var fixture: Dictionary = _protect_fixture()
	var context: Dictionary = fixture["context"] as Dictionary
	context["bonds"] = [{"actor_a": "ally.a", "actor_b": "echo.a", "strength": 60}]
	context["bond_thresholds"] = {"friend_threshold": 40, "rival_threshold": -40}
	context["bond_behavior_cfg"] = {"friend_protect_weight_bonus": NAN, "rival_protect_penalty": -10.0}
	var result: Dictionary = _select(fixture)
	if str(result["reason"]) != "non_finite_final_candidate_score":
		return _fail("Post-bond nonfinite score was not rejected: %s" % str(result))
	return _pass()


static func _t_purifier_authority() -> Dictionary:
	var fixture: Dictionary = _fixture("advance", "purifier", "shrine.a", "actor.purify_shrine")
	_add_visible_actor(fixture, _structure("shrine.a", {"col": 3, "row": 0}), "neutral")
	fixture["actor_cfg"] = {"intent_weights_by_calling_origin": {"uncalled": {"actor.purify_shrine": -100.0, "actor.idle": 8.0}}}
	var context: Dictionary = fixture["context"] as Dictionary
	context["is_purifier"] = true; context["shrine_alive"] = true; context["shrine_hp_ratio"] = 0.2
	var result: Dictionary = _select(fixture)
	if str(((result["intent"] as Dictionary)["planned_action"] as Dictionary)["type"]) != "actor.purify_shrine":
		return _fail("Purifier 9999 authority lost: %s" % str(result))
	context["is_purifier"] = false
	result = _select(fixture)
	if str(((result["intent"] as Dictionary)["planned_action"] as Dictionary)["type"]) == "actor.purify_shrine":
		return _fail("Non-purifier received 9999 authority")
	return _pass()


static func _t_unmatched_payload_policy() -> Dictionary:
	var fixture: Dictionary = _fixture("engage", "baseline", "enemy.a", "melee_attack")
	var goal: Dictionary = fixture["goals"][0]
	var explicit_payload: Dictionary = {
		"skill_base_bonus": 200.0,
		"skill_id": "skill.explicit_route",
	}
	goal["planned_primary"] = ActionPlan.build("melee_attack", "enemy.a", explicit_payload)
	fixture["options"] = [_option(goal, "direct", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], 2, 1.0)]
	var enemy: Dictionary = (fixture["context"] as Dictionary)["all_actors"][0]
	enemy["marked_by"] = "hidden.mark"
	var result: Dictionary = _select(fixture)
	if not bool(result["valid"]):
		return _fail("Explicit unmatched payload route was rejected: %s" % str(result))
	var planned_action: Dictionary = (result["intent"] as Dictionary)["planned_action"] as Dictionary
	if planned_action != ActionPlan.build("melee_attack", "enemy.a", explicit_payload):
		return _fail("Explicit unmatched payload was not preserved exactly: %s" % str(planned_action))
	if (planned_action["payload"] as Dictionary).has("marked_by"):
		return _fail("Unperceived all_actors metadata leaked into unmatched route payload")
	goal["planned_primary"] = ActionPlan.build("melee_attack", "enemy.a")
	fixture["options"] = [_option(goal, "direct", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], 2, 1.0)]
	result = _select(fixture)
	if not bool(result["valid"]):
		return _fail("Unmatched route could not use perceived health: %s" % str(result))
	return _pass()


static func _t_mirrored_intent() -> Dictionary:
	var left: Dictionary = _fixture()
	var right: Dictionary = _fixture()
	_mirror_fixture(right, 5)
	var left_result: Dictionary = _select(left)
	var right_result: Dictionary = _select(right)
	if not bool(left_result["valid"]) or not bool(right_result["valid"]):
		return _fail("Mirrored fixture invalid: %s / %s" % [left_result, right_result])
	var left_path: Array = (left_result["intent"] as Dictionary)["path"]
	var right_path: Array = (right_result["intent"] as Dictionary)["path"]
	if right_path != _mirror_path(left_path, 5):
		return _fail("Selected intent did not mirror covariantly: %s / %s" % [left_path, right_path])
	return _pass()


## GUARD for the PR #52 slice-6B fix in FlowRuntime._movement_build_direct_option.
##
## When a route is capacity-truncated (FlowRuntime._movement_affordable_prefix, taken
## whenever selected_cost > capacity) the option's destination becomes
## `selected_path.back()`, which is by construction NOT in goal.destination_region.
## The pre-fix builder reacted by REWRITING the option's planned_action to a bare
## `actor.move` whenever the goal's planned_primary was range-bound. That rewrite is
## exactly what this arbiter rejects at BehaviorArbiter.gd:656-657
## ("option_action_mismatch"), and the rejection invalidates the WHOLE
## select_movement_intent call — so ActorStateMachine (:255-267) fell through to the
## legacy nearest-enemy select_intent and the objective route was abandoned.
##
## Both poles are asserted here, so the test cannot pass in both worlds:
##   * VERBATIM planned_primary on a truncated option  -> valid selection (post-fix).
##   * REWRITTEN `actor.move` on the same option       -> option_action_mismatch, the
##     precise failure the pre-fix builder produced.
static func _t_truncated_option_keeps_planned_primary() -> Dictionary:
	var fixture: Dictionary = _fixture("engage", "baseline", "enemy.a", "melee_attack")
	var goal: Dictionary = (fixture["goals"] as Array)[0] as Dictionary
	# Truncated: the mover stops at (1,0), one cell short of the goal region (2,0).
	var truncated: Dictionary = _option(goal, "direct", {"col": 1, "row": 0}, [{"col": 1, "row": 0}], 1, 0.25)
	if (goal["destination_region"] as Array).has(truncated["destination"] as Dictionary):
		return _fail("Fixture is not truncated — destination is inside the goal region")
	if (truncated["planned_action"] as Dictionary) != (goal["planned_primary"] as Dictionary):
		return _fail("Fixture option did not carry planned_primary verbatim")

	var kept: Dictionary = _select(fixture, {}, [truncated])
	if not bool(kept["valid"]):
		return _fail("Verbatim planned_primary on a truncated option was rejected: %s" % str(kept))
	var intent: Dictionary = kept["intent"] as Dictionary
	if (intent["planned_action"] as Dictionary) != (goal["planned_primary"] as Dictionary):
		return _fail("Selected intent lost the planned primary: %s" % str(intent["planned_action"]))
	if (intent["path"] as Array) != [{"col": 1, "row": 0}]:
		return _fail("Selected intent did not take the truncated route: %s" % str(intent["path"]))

	# The PRE-FIX shape: same truncated option, planned_action rewritten to actor.move.
	var rewritten: Dictionary = truncated.duplicate(true)
	rewritten["planned_action"] = ActionPlan.build("actor.move")
	var rejected: Dictionary = _select(fixture, {}, [rewritten])
	if bool(rejected["valid"]):
		return _fail("A rewritten planned_action must not validate: %s" % str(rejected))
	if str(rejected["reason"]) != "option_action_mismatch":
		return _fail("Expected option_action_mismatch, got %s" % str(rejected["reason"]))
	if not rejected.get("intent", {}).is_empty():
		return _fail("An invalidated selection must carry no intent: %s" % str(rejected))
	return _pass()


static func _select(fixture: Dictionary, movement_context: Dictionary = {}, options: Array = [], goals: Array = []) -> Dictionary:
	var arbiter := BehaviorArbiter.new(fixture.get("actor_cfg", {}) as Dictionary, fixture.get("movement_cfg", _spatial_cfg()) as Dictionary)
	return arbiter.select_movement_intent(
		fixture["context"], fixture["movement_context"] if movement_context.is_empty() else movement_context,
		fixture["profile"], fixture["goals"] if goals.is_empty() else goals, fixture["options"] if options.is_empty() else options
	)


static func _fixture(purpose: String = "advance", role: String = "baseline", target_id: String = "enemy.a", action_type: String = "actor.move") -> Dictionary:
	var actor: Dictionary = _actor()
	var enemy: Dictionary = _enemy("enemy.a", {"col": 3, "row": 0})
	var fixture: Dictionary = {"context": {"actor": actor, "all_actors": [enemy], "t": 1}, "profile": ProfileContract.build(4, [], true, "echo", {}), "movement_cfg": _spatial_cfg(), "actor_cfg": {}}
	fixture["movement_context"] = _movement_context(actor, [enemy])
	var goal: Dictionary = _goal(purpose, role, {"col": 2, "row": 0}, target_id, action_type)
	fixture["goals"] = [goal]
	fixture["options"] = [_option(goal, "direct", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], 2, 1.0)]
	return fixture


static func _fixture_two_goals() -> Dictionary:
	var fixture: Dictionary = _fixture()
	var a: Dictionary = _goal("advance", "baseline", {"col": 2, "row": 0}, "enemy.a", "actor.move")
	var b: Dictionary = _goal("advance", "vanguard", {"col": 2, "row": 1}, "enemy.a", "actor.move")
	fixture["goals"] = [a, b]
	fixture["options"] = [_option(a, "direct", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], 2, 1.0), _option(b, "direct", {"col": 2, "row": 1}, [{"col": 1, "row": 1}, {"col": 2, "row": 1}], 2, 1.0)]
	return fixture


static func _protect_fixture() -> Dictionary:
	var fixture: Dictionary = _fixture("protect", "protector", "ally.a", "protect_ally")
	_add_visible_actor(fixture, _ally(), "friendly")
	return fixture


static func _goal(purpose: String, role: String, destination: Dictionary, target_id: String, action_type: String) -> Dictionary:
	var relevant: Array = [] if target_id.is_empty() else [target_id]
	return GoalContract.build("goal.combat.%s.%s.c%dr%d" % [purpose, role, int(destination["col"]), int(destination["row"])], purpose, [destination], 1.0, 0.0, relevant, ["mode.combat", "role.%s" % role], ActionPlan.build(action_type, target_id), {} if action_type == "actor.idle" else ActionPlan.build("actor.idle"))


static func _option(goal: Dictionary, style: String, destination: Dictionary, path: Array, cost: int, progress: float) -> Dictionary:
	var cells: Array[String] = []
	for value: Variant in path:
		var cell: Dictionary = value as Dictionary; cells.append("c%dr%d" % [int(cell["col"]), int(cell["row"])])
	var path_token: String = "pstay" if path.is_empty() else "p%s" % "-".join(cells)
	var id: String = "option.%s.%s.d%dr%d.%s" % [str(goal["goal_id"]).trim_prefix("goal."), style, int(destination["col"]), int(destination["row"]), path_token]
	return OptionContract.build(str(goal["goal_id"]), id, str(goal["purpose"]), destination, path, cost, cost, 0, 4, cost, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, progress, goal["planned_primary"], goal["declared_fallback"])


static func _movement_context(actor: Dictionary, others: Array) -> Dictionary:
	var facts: Array = [_fact(actor)]
	var occupancy: Dictionary = {"0,0": "echo.a"}
	var relationships: Dictionary = {}
	for value: Variant in others:
		var other: Dictionary = value as Dictionary; facts.append(_fact(other)); occupancy[_key(other["grid_pos"])] = str(other["id"]); relationships[str(other["id"])] = "hostile"
	var walkable: Dictionary = {}; var terrain: Dictionary = {}
	for col: int in range(6):
		for row: int in range(3): walkable["%d,%d" % [col, row]] = true; terrain["%d,%d" % [col, row]] = 1
	return ContextContract.build("echo.a", "activation.a", actor["grid_pos"], {"w": 6, "h": 3}, walkable, walkable, occupancy, facts, relationships, terrain, [], {}, [])


static func _add_visible_actor(fixture: Dictionary, actor: Dictionary, relationship: String) -> void:
	(fixture["context"] as Dictionary)["all_actors"].append(actor)
	var movement: Dictionary = fixture["movement_context"] as Dictionary
	(movement["perceived_actors"] as Array).append(_fact(actor)); (movement["perceived_actors"] as Array).sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary)["id"]) < str((b as Dictionary)["id"]))
	movement["occupancy"][_key(actor["grid_pos"])] = str(actor["id"]); movement["relationships"][str(actor["id"])] = relationship


static func _fact(actor: Dictionary) -> Dictionary:
	var dead: bool = bool(actor.get("is_dead", false)); var ko: bool = bool(actor.get("is_ko", false)); var structure: bool = bool(actor.get("is_structure", false))
	var kind: String = "structure" if structure else str(actor.get("actor_type", "echo"))
	return ActorFact.build(str(actor["id"]), actor["grid_pos"], kind, dead, ko, structure, bool(actor.get("is_spirit", false)), bool(actor.get("is_quarry", false)), bool(actor.get("controlling_state", true)), _hp(actor))


static func _actor() -> Dictionary:
	return {"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled", "traits": {}, "vector_scores": {}, "fear": 0, "morale": 50, "grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100}


static func _enemy(id: String, position: Dictionary) -> Dictionary:
	return {"id": id, "faction": "enemy", "actor_type": "enemy", "grid_pos": position, "stats": {"max_hp": 100}, "current_hp": 100}


static func _ally() -> Dictionary:
	return {"id": "ally.a", "faction": "echo", "actor_type": "echo", "grid_pos": {"col": 0, "row": 1}, "stats": {"max_hp": 100}, "current_hp": 10}


static func _structure(id: String, position: Dictionary) -> Dictionary:
	return {"id": id, "faction": "structure", "actor_type": "structure", "is_structure": true, "controlling_state": false, "grid_pos": position, "stats": {"max_hp": 100}, "current_hp": 100}


static func _hp(actor: Dictionary) -> float:
	return clampf(float(actor.get("current_hp", 100)) / float((actor.get("stats", {}) as Dictionary).get("max_hp", 100)), 0.0, 1.0)


static func _spatial_cfg() -> Dictionary:
	return {"spatial_utility": {"cap": 20.0, "urgency_weight": 4.0, "objective_progress_weight": 8.0, "cohesion_weight": 4.0, "exposure_weight": -6.0, "congestion_weight": -2.0, "commitment_weight": -2.0, "directive_objective_advance_weight": 4.0, "directive_avoid_overcommit_weight": 2.0, "directive_exposure_acceptance_weight": 2.0, "directive_ally_protection_weight": 2.0, "directive_threat_interception_weight": 2.0}}


static func _cfg_edit(field: String, value: Variant) -> Dictionary:
	var result: Dictionary = _spatial_cfg(); result["spatial_utility"][field] = value; return result


static func _reverse_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array = source.keys(); keys.reverse(); var result: Dictionary = {}
	for key: Variant in keys: result[key] = source[key]
	return result


static func _reverse_nested(source: Dictionary) -> Dictionary:
	var result: Dictionary = _reverse_dictionary(source)
	for key: Variant in result.keys():
		if result[key] is Dictionary: result[key] = _reverse_dictionary(result[key] as Dictionary)
	return result


static func _reverse_recursive(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value as Dictionary
		var keys: Array = source.keys()
		keys.reverse()
		var result: Dictionary = {}
		for key: Variant in keys:
			result[key] = _reverse_recursive(source[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_reverse_recursive(item))
		return result
	return value


static func _mirror_fixture(fixture: Dictionary, max_col: int) -> void:
	var context: Dictionary = fixture["context"]; context["actor"]["grid_pos"] = _mirror_cell(context["actor"]["grid_pos"], max_col)
	for value: Variant in context["all_actors"]: (value as Dictionary)["grid_pos"] = _mirror_cell((value as Dictionary)["grid_pos"], max_col)
	var movement: Dictionary = fixture["movement_context"]; movement["origin"] = _mirror_cell(movement["origin"], max_col); movement["occupancy"] = {}
	for value: Variant in movement["perceived_actors"]:
		var fact: Dictionary = value
		fact["position"] = _mirror_cell(fact["position"], max_col)
		movement["occupancy"][_key(fact["position"])] = str(fact["id"])
	var goal: Dictionary = fixture["goals"][0]; goal["destination_region"] = [_mirror_cell(goal["destination_region"][0], max_col)]; goal["goal_id"] = "goal.combat.advance.baseline.c%dr0" % int(goal["destination_region"][0]["col"])
	var option: Dictionary = fixture["options"][0]
	option["goal_id"] = goal["goal_id"]
	option["destination"] = _mirror_cell(option["destination"], max_col)
	option["path"] = _mirror_path(option["path"], max_col)
	var path_tokens: PackedStringArray = []
	for value: Variant in option["path"]:
		path_tokens.append("c%dr0" % int((value as Dictionary)["col"]))
	option["option_id"] = "option.%s.direct.d%dr0.p%s" % [str(goal["goal_id"]).trim_prefix("goal."), int(option["destination"]["col"]), "-".join(path_tokens)]


static func _mirror_cell(cell: Dictionary, max_col: int) -> Dictionary: return {"col": max_col - int(cell["col"]), "row": int(cell["row"])}
static func _mirror_path(path: Array, max_col: int) -> Array:
	var result: Array = []
	for value: Variant in path: result.append(_mirror_cell(value as Dictionary, max_col))
	return result
static func _key(position: Dictionary) -> String: return "%d,%d" % [int(position["col"]), int(position["row"])]
static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}
