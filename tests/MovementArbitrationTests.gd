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
	FeltStateTests.register(runner)
	runner.register_test("movement_arbiter/fear_lean_reaches_acceptance_through_actor_state_machine", _t_fear_lean_reaches_acceptance_through_actor_state_machine)
	runner.register_test("movement_arbiter/ten_virtues", _t_ten_virtues)
	runner.register_test("movement_arbiter/maturity_skill_passive", _t_maturity_skill_passive)
	runner.register_test("movement_arbiter/vow_bond_order", _t_vow_bond_order)
	runner.register_test("movement_arbiter/final_score_finite", _t_final_score_finite)
	runner.register_test("movement_arbiter/purifier_authority", _t_purifier_authority)
	runner.register_test("movement_arbiter/unmatched_payload_policy", _t_unmatched_payload_policy)
	runner.register_test("movement_arbiter/mirrored_intent", _t_mirrored_intent)
	runner.register_test("movement_arbiter/truncated_option_keeps_planned_primary", _t_truncated_option_keeps_planned_primary)
	runner.register_test("movement_arbiter/commitment_tracks_distance_and_capacity", _t_commitment_tracks_distance_and_capacity)
	runner.register_test("movement_arbiter/capacity_meaningful_at_range", _t_capacity_meaningful_at_range)
	runner.register_test("movement_arbiter/hostile_control_still_restrains", _t_hostile_control_still_restrains)
	runner.register_test("movement_arbiter/avoid_overcommit_stays_proportionate", _t_avoid_overcommit_stays_proportionate)
	runner.register_test("movement_arbiter/commitment_ratio_ignores_hostile_surcharge", _t_commitment_ratio_ignores_hostile_surcharge)
	runner.register_test("movement_arbiter/acceptance_scout_vs_seek_exposed_option", _t_acceptance_scout_vs_seek_exposed_option)
	runner.register_test("movement_arbiter/acceptance_missing_tolerance_is_neutral", _t_acceptance_missing_tolerance_is_neutral)
	runner.register_test("movement_arbiter/acceptance_rejects_non_finite_inputs", _t_acceptance_rejects_non_finite_inputs)
	runner.register_test("movement_arbiter/fear_lean_lowers_acceptance", _t_fear_lean_lowers_acceptance)
	runner.register_test("movement_arbiter/fear_lean_follows_status_band", _t_fear_lean_follows_status_band)
	runner.register_test("movement_arbiter/fear_lean_reads_max_of_fear_and_base", _t_fear_lean_reads_max_of_fear_and_base)
	runner.register_test("movement_arbiter/more_fear_never_more_accepting", _t_more_fear_never_more_accepting)
	runner.register_test("movement_arbiter/afraid_seek_still_treats_exposure_as_cost_not_ban", _t_afraid_seek_still_cost_not_ban)
	runner.register_test("movement_arbiter/fear_lean_missing_key_is_zero", _t_fear_lean_missing_key_is_zero)
	runner.register_test("movement_arbiter/fear_lean_needs_a_directive", _t_fear_lean_needs_a_directive)
	runner.register_test("movement_arbiter/fear_lean_bound_validated", _t_fear_lean_bound_validated)
	runner.register_test("movement_arbiter/fear_bound_is_combat_owned", _t_fear_bound_is_combat_owned)
	runner.register_test("movement_arbiter/fear_lean_reaches_arbiter_through_turn_context", _t_fear_lean_reaches_arbiter_through_turn_context)
	runner.register_test("movement_arbiter/stage_bound_not_read_in_combat", _t_stage_bound_not_read_in_combat)
	runner.register_test("movement_arbiter/acceptance_falls_with_judgment", _t_acceptance_falls_with_judgment)
	runner.register_test("movement_arbiter/acceptance_judgment_scale_keeps_sign", _t_acceptance_judgment_scale_keeps_sign)
	runner.register_test("movement_arbiter/seasoned_echo_reads_directive_exposure_less_literally", _t_seasoned_echo_reads_directive_exposure_less_literally)
	runner.register_test("movement_arbiter/directive_contrast_narrows_but_never_closes", _t_directive_contrast_narrows_but_never_closes)
	runner.register_test("movement_arbiter/acceptance_growth_anchor_and_edge", _t_acceptance_growth_anchor_and_edge)
	runner.register_test("movement_arbiter/acceptance_order_of_operations", _t_acceptance_order_of_operations)
	runner.register_test("movement_arbiter/acceptance_missing_tolerance_is_neutral_plus_fear", _t_acceptance_missing_tolerance_is_neutral_plus_fear)
	runner.register_test("movement_arbiter/acceptance_swing_within_declared_budget", _t_acceptance_swing_within_declared_budget)
	runner.register_test("movement_arbiter/swing_layer_ceilings_consistent", _t_swing_layer_ceilings_consistent)
	runner.register_test("movement_arbiter/felt_state_swing_within_declared_budget", _t_felt_state_swing_within_declared_budget)
	runner.register_test("movement_arbiter/cross_layer_pair_within_declared_budget", _t_cross_layer_pair_within_declared_budget)
	runner.register_test("movement_arbiter/judgment_floor_validated_and_neutral_when_missing", _t_judgment_floor_validated_and_neutral_when_missing)
	runner.register_test("movement_arbiter/acceptance_rejects_non_finite_judgment", _t_acceptance_rejects_non_finite_judgment)
	runner.register_test("movement_arbiter/fear_lean_not_scaled_by_judgment", _t_fear_lean_not_scaled_by_judgment)
	runner.register_test("movement_arbiter/more_fear_never_more_accepting_across_judgment", _t_more_fear_never_more_accepting_across_judgment)
	runner.register_test("movement_arbiter/judgment_reaches_arbiter_through_turn_context", _t_judgment_reaches_arbiter_through_turn_context)
	runner.register_test("movement_arbiter/acceptance_own_side_equals_identity_scale", _t_acceptance_own_side_equals_identity_scale)
	runner.register_test("movement_arbiter/judgment_reaches_acceptance_through_actor_state_machine", _t_judgment_reaches_acceptance_through_actor_state_machine)
	runner.register_test("movement_arbiter/directive_stop_is_not_own_judgment", _t_directive_stop_is_not_own_judgment)
	runner.register_test("movement_arbiter/fear_lean_stays_in_own_score", _t_fear_lean_stays_in_own_score)
	runner.register_test("movement_arbiter/all_directive_terms_leave_own_score", _t_all_directive_terms_leave_own_score)
	runner.register_test("movement_arbiter/style_growth_reaches_movement_style_through_actor_state_machine", _t_style_growth_reaches_movement_style_through_actor_state_machine)


## The winner also carries the score decomposition DecisionTrace reads
## (`_score_components`, `_decision_inputs`). Pure reporting, pinned by
## tests/DecisionTraceTests.gd — this golden stays about the DECISION rather than
## growing a second copy of the arbiter's arithmetic.
static func _strip_trace_reporting(winner: Dictionary) -> void:
	winner.erase("_score_components")
	winner.erase("_decision_inputs")


static func _t_production_golden() -> Dictionary:
	var actor: Dictionary = _actor()
	var enemy: Dictionary = _enemy("enemy.a", {"col": 3, "row": 0})
	var arbiter := BehaviorArbiter.new({}, MoraleInfluenceTests._data()["combat"]["movement"] as Dictionary)
	var actual: Dictionary = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 1})
	_strip_trace_reporting(actual)
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
		"emotional_status": "grounded", "state_points": 0.0, "archetype_birth": "", "archetype_modifier": 0,
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
	_strip_trace_reporting(actual)
	# melee_attack's ranked-candidate score (36.83) is a genuine arithmetic result
	# (not a clean decimal literal), so it lands on a double a few ULPs off whatever
	# GDScript's own "36.83" literal parses to — is_equal_approx it separately, then
	# normalize it in `actual` so the single exact-equality dict compare below still
	# works for every other (exact) field.
	var stationary_candidates: Array = ((actual.get("_divergence_probe", {}) as Dictionary).get("directive_candidates", []) as Array)
	for candidate_v: Variant in stationary_candidates:
		var candidate: Dictionary = candidate_v as Dictionary
		if str(candidate.get("action_type", "")) == "melee_attack":
			if not is_equal_approx(float(candidate.get("score", 0.0)), 36.83):
				return _fail("melee_attack ranked-candidate score drifted: %s" % str(candidate.get("score", 0.0)))
			candidate["score"] = 36.83
	var expected_stationary: Dictionary = {
		"action_type": "actor.guard", "target_id": "", "priority": 0.0,
		"emotional_status": "hollow", "state_points": 0.0, "archetype_birth": "", "archetype_modifier": 0,
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
					"action_type": "melee_attack", "target_id": "enemy.a", "score": 36.83,
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
	# A zero-step option a GOAL published keeps that goal's identity. Only a candidate
	# that never had a goal is normalized to a legacy stationary one.
	if str(intent["goal_id"]) != "goal.combat.hold.baseline.c0r0" \
			or intent["path"] != [] \
			or intent["pressure_sources"] != ["mode.combat", "role.baseline"]:
		return _fail("Goal-derived stay option lost its identity: %s" % str(result))
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
			option["path"] = [{"col": 1, "row": 0}, {"col": 2, "row": 0}, {"col": 3, "row": 0}, {"col": 4, "row": 0}]
		else:
			option[str(case[0])] = 1.0
		var actual: float = arbiter._spatial_utility(goal, option, {}, cfg)
		if not is_equal_approx(actual, float(case[1])):
			return _fail("Base spatial coefficient %s differed: %s != %s" % [str(case[0]), actual, float(case[1])])
	return _pass()


static func _t_spatial_directive_terms() -> Dictionary:
	var movement_cfg: Dictionary = _spatial_cfg()
	movement_cfg["exposure_acceptance"] = {"offset": 0.0}
	var arbiter := BehaviorArbiter.new({}, movement_cfg)
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
		var with_weight: float = arbiter._spatial_utility(goal, option, _weighted(str(case[0]), 1.0), cfg)
		if not is_equal_approx(with_weight - base, float(case[2])):
			return _fail("Directive term %s was not exact: %s" % [str(case[0]), with_weight - base])
		var positive_clamp: float = arbiter._spatial_utility(goal, option, _weighted(str(case[0]), 999.0), cfg)
		var negative: float = arbiter._spatial_utility(goal, option, _weighted(str(case[0]), -1.0), cfg)
		var negative_clamp: float = arbiter._spatial_utility(goal, option, _weighted(str(case[0]), -999.0), cfg)
		if not is_equal_approx(positive_clamp, with_weight) or not is_equal_approx(negative_clamp, negative):
			return _fail("Directive term %s did not clamp at +/-1 before the utility cap" % str(case[0]))
	return _pass()


## Acceptance reads `exposure_tolerance` (offset 0 here); the other four terms read intent_weights.
static func _weighted(key: String, value: float) -> Dictionary:
	if key == "exposure_acceptance":
		return {"exposure_tolerance": value}
	return {"intent_weights": {key: value}}


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
	# The status factors need the lean table and the state points; a calm actor scores as `base`.
	var data: Dictionary = MoraleInfluenceTests._data()
	var leaning := BehaviorArbiter.new({"state_action_points": data["actor"]["state_action_points"]}, data["combat"]["movement"] as Dictionary)
	actor = _actor(); actor["fear"] = 100
	if leaning._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) >= base:
		return _fail("Fear factor missing")
	actor = _actor(); actor["morale"] = 80
	if leaning._score("actor.move", actor, {}, {}, "nascent", {}, candidate, 0.1, 0.0) <= base:
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
	var leaning := BehaviorArbiter.new({}, MoraleInfluenceTests._data()["combat"]["movement"] as Dictionary)
	var no_passive: float = leaning._score("actor.move", actor, {}, {}, "nascent", {}, {}, 0.1, 0.0)
	var passive: float = leaning._score("actor.move", actor, {}, {}, "nascent", {"afraid_signature": {"actor.move": 20.0}}, {}, 0.1, 0.0)
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


## GUARD on the planned_action a CAPACITY-TRUNCATED option must carry.
##
## When a route is truncated to what the mover can afford, its destination is
## `path.back()`, by construction NOT in goal.destination_region. A producer that
## reacted by REWRITING the option's planned_action to a bare `actor.move` whenever
## the goal's planned_primary was range-bound is what this arbiter rejects
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


# ---------------------------------------------------------------------------
# V2-COMBAT-003.5 Phase 3c acceptance set (A-D). These drive the REAL option
# generator, not a hand-written option, because the defect they guard lived in the
# relationship between `objective_progress` and `commitment` — two fields only the
# generator sets together.
# ---------------------------------------------------------------------------

const _ACCEPTANCE_DISTANCES: Array = [4, 8, 12, 20, 40]
const _ACCEPTANCE_CAPACITIES: Array = [2, 3, 4, 6]


## Test A — no capacity-blind cliff. The chosen route spends min(capacity, distance)
## on open ground at every distance, instead of collapsing to one cell past a
## break-even range.
static func _t_commitment_tracks_distance_and_capacity() -> Dictionary:
	for distance_value: Variant in _ACCEPTANCE_DISTANCES:
		var distance: int = int(distance_value)
		for capacity_value: Variant in _ACCEPTANCE_CAPACITIES:
			var capacity: int = int(capacity_value)
			var measured: Dictionary = _measure_commitment(distance, capacity, {}, {})
			if not bool(measured["ok"]):
				return _fail("D=%d cap=%d: %s" % [distance, capacity, str(measured["error"])])
			var expected: int = mini(capacity, distance)
			if int(measured["commitment"]) != expected:
				return _fail("D=%d cap=%d: committed %d cells, expected %d" \
					% [distance, capacity, int(measured["commitment"]), expected])
	return _pass()


## Test B — capacity stays legible at long range: at D=20 each capacity closes its
## own number of cells per turn, all above the one-cell floor the defect produced.
static func _t_capacity_meaningful_at_range() -> Dictionary:
	var previous: int = 0
	for capacity_value: Variant in _ACCEPTANCE_CAPACITIES:
		var capacity: int = int(capacity_value)
		var measured: Dictionary = _measure_commitment(20, capacity, {}, {})
		if not bool(measured["ok"]):
			return _fail("cap=%d: %s" % [capacity, str(measured["error"])])
		var commitment: int = int(measured["commitment"])
		if commitment != capacity:
			return _fail("cap=%d at D=20 closed %d cells, expected %d" % [capacity, commitment, capacity])
		if commitment <= 1:
			return _fail("cap=%d at D=20 fell back to the one-cell floor" % capacity)
		if commitment <= previous:
			return _fail("cap=%d closed %d cells, not more than the previous capacity's %d" \
				% [capacity, commitment, previous])
		previous = commitment
	return _pass()


## Test C — restraint survives. A hostile controller beside the corridor must still
## push some full-capacity routes down, and the penalty must come from the exposure /
## hostile-control terms, not from distance.
static func _t_hostile_control_still_restrains() -> Dictionary:
	# The controller sits beside the first cells of the corridor, inside the 4 cells this
	# mover can actually reach — a controller at mid-corridor is 16 cells past its horizon
	# and cannot influence any option.
	var fixture: Dictionary = _open_fixture(20, 4, {"col": 2, "row": 1}, {})
	if not bool((fixture["generated"] as Dictionary).get("valid", false)):
		return _fail("Controlled-corridor fixture produced no options: %s" % str(fixture["generated"]))
	var open_fixture: Dictionary = _open_fixture(20, 4, {}, {})
	if not bool((open_fixture["generated"] as Dictionary).get("valid", false)):
		return _fail("Open fixture produced no options: %s" % str(open_fixture["generated"]))

	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var goal: Dictionary = (fixture["goals"] as Array)[0] as Dictionary

	var exposed_found: bool = false
	for option_value: Variant in fixture["options"] as Array:
		var option: Dictionary = option_value as Dictionary
		if (option["hostile_control_sources"] as Array).is_empty():
			continue
		exposed_found = true
		var parts: Dictionary = {}
		arbiter._spatial_utility(goal, option, {}, cfg, parts)
		var terms: Dictionary = parts["parts"] as Dictionary
		if float(terms["exposure"]) >= 0.0:
			return _fail("Option %s crossed hostile control with no exposure penalty: %s" \
				% [str(option["option_id"]), str(terms)])
		# The same option scored with exposure erased isolates the penalty: if the drop
		# came from distance or commitment instead, these two would be equal.
		var unexposed: Dictionary = option.duplicate(true)
		unexposed["exposure"] = 0.0
		var clean_parts: Dictionary = {}
		var clean_value: float = arbiter._spatial_utility(goal, unexposed, {}, cfg, clean_parts)
		if clean_value <= float(parts["value"]):
			return _fail("Exposure did not lower option %s" % str(option["option_id"]))
		if not is_equal_approx(
			float((clean_parts["parts"] as Dictionary)["commitment"]), float(terms["commitment"])
		):
			return _fail("Exposure isolation changed the commitment term for %s" % str(option["option_id"]))

	if not exposed_found:
		return _fail("No generated option crossed the hostile controller's zone of control")

	for option_value: Variant in open_fixture["options"] as Array:
		if not ((option_value as Dictionary)["hostile_control_sources"] as Array).is_empty():
			return _fail("Open board reported hostile control: %s" % str(option_value))
	return _pass()


## Test D — `avoid_overcommit` biases, it does not veto. Scout Carefully must keep the
## Test A/B shape and stay inside its own weight ceiling.
## Stays red on purpose: production urgency_progress_gain (1.0) masks this gap during urgent
## goals, but this fixture's isolated 0.0 config keeps it visible — decisions #29/#38.
static func _t_avoid_overcommit_stays_proportionate() -> Dictionary:
	var directives := DirectiveService.new({})
	var scout: Dictionary = directives.get_directive("directive.scout_carefully")
	var seek: Dictionary = directives.get_directive("directive.seek_signs")
	if float((scout["intent_weights"] as Dictionary).get("avoid_overcommit", 0.0)) <= 0.0:
		return _fail("Scout Carefully no longer carries avoid_overcommit — retune this test")
	if float((seek["intent_weights"] as Dictionary).get("avoid_overcommit", 0.0)) != 0.0:
		return _fail("Seek Signs acquired avoid_overcommit — retune this test")

	# weight x clamped directive value x (1 - commitment_ratio) can never exceed this.
	var ceiling: float = abs(float(_spatial_cfg()["spatial_utility"]["directive_avoid_overcommit_weight"])) \
		* float((scout["intent_weights"] as Dictionary)["avoid_overcommit"])
	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]

	# Every combination is reported, not just the first — the residual gap is a
	# distance/capacity SURFACE, and one sample cannot show its shape.
	var shortfalls: Array[String] = []
	for distance_value: Variant in _ACCEPTANCE_DISTANCES:
		var distance: int = int(distance_value)
		for capacity_value: Variant in _ACCEPTANCE_CAPACITIES:
			var capacity: int = int(capacity_value)
			var expected: int = mini(capacity, distance)
			var careful: Dictionary = _measure_commitment(distance, capacity, {}, scout)
			if not bool(careful["ok"]):
				return _fail("scout D=%d cap=%d: %s" % [distance, capacity, str(careful["error"])])
			var bold: Dictionary = _measure_commitment(distance, capacity, {}, seek)
			if not bool(bold["ok"]):
				return _fail("seek D=%d cap=%d: %s" % [distance, capacity, str(bold["error"])])
			if int(bold["commitment"]) != expected:
				return _fail("seek_signs D=%d cap=%d committed %d, expected %d" \
					% [distance, capacity, int(bold["commitment"]), expected])
			if int(careful["commitment"]) != expected:
				shortfalls.append("D=%d cap=%d committed %d expected %d%s" \
					% [distance, capacity, int(careful["commitment"]), expected,
						_overcommit_diagnostic(distance, capacity, scout)])

			var fixture: Dictionary = _open_fixture(distance, capacity, {}, scout)
			var goal: Dictionary = (fixture["goals"] as Array)[0] as Dictionary
			for option_value: Variant in fixture["options"] as Array:
				var parts: Dictionary = {}
				arbiter._spatial_utility(goal, option_value as Dictionary, scout, cfg, parts)
				var term: float = float((parts["parts"] as Dictionary)["directive_avoid_overcommit"])
				if abs(term) > ceiling + 0.0001:
					return _fail("avoid_overcommit term %s exceeded its %s ceiling at D=%d cap=%d" \
						% [term, ceiling, distance, capacity])
	if not shortfalls.is_empty():
		return _fail("scout_carefully still collapses to a shorter route: %s" % "\n  ".join(shortfalls))
	return _pass()


## Follow-up #7 / decision #30: two routes of the SAME length must score the SAME
## commitment term, whether or not one runs beside a hostile controller. Before the
## fix, `commitment` (a cost the surcharge inflates) was divided by a pure cell count
## that never carries the surcharge, so the exposed route scored a harsher penalty
## from mixed units alone.
static func _t_commitment_ratio_ignores_hostile_surcharge() -> Dictionary:
	var hostile_fixture: Dictionary = _open_fixture(20, 4, {"col": 2, "row": 1}, {})
	if not bool((hostile_fixture["generated"] as Dictionary).get("valid", false)):
		return _fail("Hostile fixture produced no options: %s" % str(hostile_fixture["generated"]))
	var clean_fixture: Dictionary = _open_fixture(20, 4, {}, {})
	if not bool((clean_fixture["generated"] as Dictionary).get("valid", false)):
		return _fail("Clean fixture produced no options: %s" % str(clean_fixture["generated"]))

	var exposed_option: Dictionary = {}
	for option_value: Variant in hostile_fixture["options"] as Array:
		var option: Dictionary = option_value as Dictionary
		if not (option["hostile_control_sources"] as Array).is_empty():
			exposed_option = option
			break
	if exposed_option.is_empty():
		return _fail("No generated option crossed the hostile controller's zone of control")

	var exposed_path_size: int = (exposed_option["path"] as Array).size()
	var exposed_destination: Dictionary = exposed_option["destination"] as Dictionary
	var matched_clean: Dictionary = {}
	for option_value: Variant in clean_fixture["options"] as Array:
		var option: Dictionary = option_value as Dictionary
		var destination: Dictionary = option["destination"] as Dictionary
		if int(destination["col"]) != int(exposed_destination["col"]) or int(destination["row"]) != int(exposed_destination["row"]):
			continue
		if (option["path"] as Array).size() != exposed_path_size:
			continue
		matched_clean = option
		break
	if matched_clean.is_empty():
		return _fail("No clean-fixture option matched the exposed option's destination and path length")

	if int(matched_clean["progress_origin_distance"]) != int(exposed_option["progress_origin_distance"]):
		return _fail("Fixture pair covers different ground: progress_origin_distance %d != %d" \
			% [int(matched_clean["progress_origin_distance"]), int(exposed_option["progress_origin_distance"])])
	if int(exposed_option["commitment"]) <= int(matched_clean["commitment"]):
		return _fail("Fixture does not exercise the surcharge: exposed commitment %d, clean commitment %d" \
			% [int(exposed_option["commitment"]), int(matched_clean["commitment"])])

	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var goal: Dictionary = (hostile_fixture["goals"] as Array)[0] as Dictionary
	var exposed_parts: Dictionary = {}
	arbiter._spatial_utility(goal, exposed_option, {}, cfg, exposed_parts)
	var clean_parts: Dictionary = {}
	arbiter._spatial_utility(goal, matched_clean, {}, cfg, clean_parts)
	var exposed_term: float = float((exposed_parts["parts"] as Dictionary)["commitment"])
	var clean_term: float = float((clean_parts["parts"] as Dictionary)["commitment"])
	var commitment_weight: float = float(cfg["commitment_weight"])
	if is_equal_approx(abs(exposed_term), abs(commitment_weight)) and is_equal_approx(abs(clean_term), abs(commitment_weight)):
		return _fail("Both commitment terms sit at the clamp ceiling — pick a fixture that leaves headroom")
	if not is_equal_approx(exposed_term, clean_term):
		return _fail("Commitment term still differs by hostile exposure alone: exposed %s, clean %s" \
			% [exposed_term, clean_term])
	return _pass()


## Shipped movement config and Directive entries: the acceptance map is read from both.
static func _shipped_movement_and_directives() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	return {
		"movement": ((cs.get_balance().get("data", {}) as Dictionary).get("combat", {}) as Dictionary).get("movement", {}),
		"directives": ConfigService.get_directives_cfg(cs),
	}


static func _exposed_option(progress: float) -> Dictionary:
	return {"objective_progress": progress, "cohesion": 0.0, "exposure": 1.0, "congestion": 0.0, "commitment": 0, "capacity": 4}


static func _t_acceptance_scout_vs_seek_exposed_option() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var directives: Dictionary = shipped["directives"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var offset: float = float((movement["exposure_acceptance"] as Dictionary)["offset"])
	var weight: float = float(cfg["directive_exposure_acceptance_weight"])
	var arbiter := BehaviorArbiter.new({}, movement)
	var goal: Dictionary = {"urgency": 0.0, "purpose": "advance"}
	# Progress gain that exactly cancels the exposure cost, so only the Directive terms decide.
	var cancel: float = -float(cfg["exposure_weight"]) / float(cfg["objective_progress_weight"])
	var exposed: Dictionary = _exposed_option(cancel)
	var results: Dictionary = {}
	for id: String in ["directive.scout_carefully", "directive.seek_signs"]:
		var directive: Dictionary = directives[id] as Dictionary
		var parts: Dictionary = {}
		var value: float = arbiter._spatial_utility(goal, exposed, directive, cfg, parts)
		var expected: float = weight * (float(directive["exposure_tolerance"]) - offset)
		if not is_equal_approx(float((parts["parts"] as Dictionary)["directive_exposure_acceptance"]), expected):
			return _fail("%s acceptance term %s != weight x (tolerance - offset) %s" % [id, (parts["parts"] as Dictionary)["directive_exposure_acceptance"], expected])
		results[id] = value
	if float(results["directive.scout_carefully"]) >= 0.0:
		return _fail("Scout should refuse the exposed option (utility %s)" % results["directive.scout_carefully"])
	if float(results["directive.seek_signs"]) <= 0.0:
		return _fail("Seek should take the exposed option (utility %s)" % results["directive.seek_signs"])
	return _pass()


static func _t_acceptance_missing_tolerance_is_neutral() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var goal: Dictionary = {"urgency": 0.0, "purpose": "advance"}
	var exposed: Dictionary = _exposed_option(0.5)
	var arbiter := BehaviorArbiter.new({}, movement)
	var base: float = arbiter._spatial_utility(goal, exposed, {}, cfg)
	# A Directive with no exposure_tolerance, even with the old intent weight set.
	var no_tolerance: Dictionary = {"intent_weights": {"exposure_acceptance": 1.0}}
	if not is_equal_approx(arbiter._spatial_utility(goal, exposed, no_tolerance, cfg), base):
		return _fail("A Directive with no exposure_tolerance must give acceptance 0")
	# A tolerance but no exposure_acceptance block (old fixtures): neutral, not an error.
	var bare := BehaviorArbiter.new({}, {"spatial_utility": cfg})
	var tolerant: Dictionary = {"exposure_tolerance": 0.8}
	if not is_equal_approx(bare._spatial_utility(goal, exposed, tolerant, cfg), base):
		return _fail("A missing exposure_acceptance block must give acceptance 0")
	return _pass()


static func _t_acceptance_rejects_non_finite_inputs() -> Dictionary:
	var movement: Dictionary = (_shipped_movement_and_directives()["movement"] as Dictionary).duplicate(true)
	var arbiter := BehaviorArbiter.new({}, movement)
	for bad: Variant in [NAN, INF, "0.3"]:
		if bool(arbiter._validate_spatial_directive({"exposure_tolerance": bad})["valid"]):
			return _fail("exposure_tolerance %s was accepted" % str(bad))
	if not bool(arbiter._validate_spatial_directive({"exposure_tolerance": 0.3})["valid"]):
		return _fail("A finite exposure_tolerance was rejected")
	if not bool(arbiter._validate_spatial_config()["valid"]):
		return _fail("The shipped movement config was rejected")
	for bad_offset: Variant in [NAN, INF, "0.5", null]:
		(movement["exposure_acceptance"] as Dictionary)["offset"] = bad_offset
		var bad_arbiter := BehaviorArbiter.new({}, movement)
		if bool(bad_arbiter._validate_spatial_config()["valid"]):
			return _fail("offset %s was accepted" % str(bad_offset))
	return _pass()


## Acceptance as the arbiter scores it: the exposure term divided by weight x exposure (1.0).
static func _acceptance_at(arbiter: BehaviorArbiter, cfg: Dictionary, directive: Dictionary, actor: Dictionary, composure: float = 0.0) -> float:
	var parts: Dictionary = {}
	arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, _exposed_option(0.0), directive, cfg, parts, arbiter._fear_lean(actor, composure))
	return float((parts["parts"] as Dictionary)["directive_exposure_acceptance"]) / float(cfg["directive_exposure_acceptance_weight"])


static func _band_lean() -> Dictionary:
	return EmotionStatusLean.table_of(_shipped_movement_and_directives()["movement"] as Dictionary)


## Afraid part of the actor's status lean, from the shipped table and the shared status rule.
static func _afraid_part(actor: Dictionary) -> float:
	var fear: int = maxi(int(actor.get("fear", 0)), int(actor.get("fear_base", 0)))
	var status: String = EmotionService.get_emotional_status(int(actor.get("morale", 50)), fear)
	return maxf(0.0, -float(_band_lean()[status]))


## Largest drop between two neighbours on the status ladder.
static func _largest_step(table: Dictionary) -> float:
	var step := 0.0
	for i: int in range(1, EmotionService.STATUS_LADDER.size()):
		step = maxf(step, float(table[EmotionService.STATUS_LADDER[i]]) - float(table[EmotionService.STATUS_LADDER[i - 1]]))
	return step


static func _t_fear_lean_lowers_acceptance() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var calm: Dictionary = _actor()
	var afraid: Dictionary = _actor()
	afraid["fear"] = 70
	for id: String in ["directive.scout_carefully", "directive.seek_signs"]:
		var directive: Dictionary = (shipped["directives"] as Dictionary)[id] as Dictionary
		var calm_value: float = _acceptance_at(arbiter, cfg, directive, calm)
		var afraid_value: float = _acceptance_at(arbiter, cfg, directive, afraid)
		var want: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"]) * _afraid_part(afraid)
		if want <= 0.0 or not is_equal_approx(calm_value - afraid_value, want):
			return _fail("%s: fear 70 should lower acceptance by %s, got %s to %s" % [id, want, calm_value, afraid_value])
	return _pass()


## The lean is the bound times the afraid part of the table entry of the shared status, with
## steps where the status changes.
static func _t_fear_lean_follows_status_band() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	var table: Dictionary = _band_lean()
	for fear: int in [0, 40, 41, 44, 45, 54, 55, 64, 65, 74, 75, 84, 85, 100]:
		var actor: Dictionary = _actor()
		actor["fear"] = fear
		var status: String = EmotionService.get_emotional_status(50, fear)
		var want: float = bound * maxf(0.0, -float(table[status]))
		if not is_equal_approx(arbiter._fear_lean(actor, 0.0), want):
			return _fail("fear %d (%s): lean %s, expected %s" % [fear, status, arbiter._fear_lean(actor, 0.0), want])
	var calm: Dictionary = _actor()
	calm["fear"] = 40
	if arbiter._fear_lean(calm, 0.0) != 0.0:
		return _fail("a grounded Echo must have lean exactly 0")
	var burdened: Dictionary = _actor()
	burdened["fear"] = 45
	if arbiter._fear_lean(burdened, 0.0) <= 0.0:
		return _fail("a burdened Echo must lean")
	return _pass()


static func _t_fear_lean_reads_max_of_fear_and_base() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var base_only: Dictionary = _actor()
	base_only["fear"] = 0
	base_only["fear_base"] = 70
	var fear_only: Dictionary = _actor()
	fear_only["fear"] = 70
	fear_only["fear_base"] = 0
	var lean: float = arbiter._fear_lean(base_only, 0.0)
	if lean <= 0.0 or not is_equal_approx(lean, arbiter._fear_lean(fear_only, 0.0)):
		return _fail("a high fear_base with low fear must lean like the same fear: %s" % lean)
	return _pass()


## With Judgment held fixed, more fear never raises acceptance. Each fear point may lower it by at
## most the largest step of the table times the bound.
static func _t_more_fear_never_more_accepting() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var step_limit: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"]) * _largest_step(_band_lean())
	for id: String in ["directive.scout_carefully", "directive.seek_signs"]:
		var directive: Dictionary = (shipped["directives"] as Dictionary)[id] as Dictionary
		var calm_actor: Dictionary = _actor()
		var previous: float = _acceptance_at(arbiter, cfg, directive, calm_actor)
		for fear: int in range(1, 101):
			var actor: Dictionary = _actor()
			actor["fear"] = fear
			var value: float = _acceptance_at(arbiter, cfg, directive, actor)
			if value > previous + 0.0000001:
				return _fail("%s: acceptance rose from %s to %s at fear %d" % [id, previous, value, fear])
			if previous - value > step_limit + 0.0000001:
				return _fail("%s: acceptance fell by more than the largest step times the bound at fear %d" % [id, fear])
			previous = value
		var grounded: Dictionary = _actor()
		grounded["fear"] = 40
		if not is_equal_approx(_acceptance_at(arbiter, cfg, directive, grounded), _acceptance_at(arbiter, cfg, directive, calm_actor)):
			return _fail("%s: a grounded Echo must not change acceptance" % id)
	return _pass()


static func _t_afraid_seek_still_cost_not_ban() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var afraid: Dictionary = _actor()
	afraid["fear"] = 100
	var seek: Dictionary = (shipped["directives"] as Dictionary)["directive.seek_signs"] as Dictionary
	var block: Dictionary = movement["exposure_acceptance"] as Dictionary
	var d: float = float(seek["exposure_tolerance"]) - float(block["offset"])
	for j: float in [0.0, 1.0]:
		var value: float = float(_accept_parts(arbiter, cfg, seek, afraid, j)["acceptance"])
		if value <= -0.05:
			return _fail("a frightened Seek Echo must hesitate, not refuse; acceptance %s at J %s" % [value, j])
		var scale: float = 1.0 if j == 0.0 else _floor_a(movement)
		var want: float = d * scale - float(block["fear_lean_bound"]) * _afraid_part(afraid)
		if value < 0.0 or not is_equal_approx(value, want):
			return _fail("frightened Seek acceptance %s at J %s, expected %s (at or above 0)" % [value, j, want])
	return _pass()


static func _t_fear_lean_missing_key_is_zero() -> Dictionary:
	var movement: Dictionary = (_shipped_movement_and_directives()["movement"] as Dictionary).duplicate(true)
	var afraid: Dictionary = _actor()
	afraid["fear"] = 100
	var no_table: Dictionary = movement.duplicate(true)
	no_table.erase("felt_state")
	if BehaviorArbiter.new({}, no_table)._fear_lean(afraid, 0.0) != 0.0:
		return _fail("a missing band_lean table must give lean 0")
	(movement["exposure_acceptance"] as Dictionary).erase("fear_lean_bound")
	if BehaviorArbiter.new({}, movement)._fear_lean(afraid, 0.0) != 0.0:
		return _fail("missing fear_lean_bound must give lean 0")
	if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
		return _fail("a block without fear_lean_bound must stay valid")
	movement.erase("exposure_acceptance")
	if BehaviorArbiter.new({}, movement)._fear_lean(afraid, 0.0) != 0.0:
		return _fail("missing exposure_acceptance block must give lean 0")
	return _pass()


## An empty Directive (enemies, keeper trial) takes no lean. A non-empty one without a
## tolerance has D = 0 and still takes the lean.
static func _t_fear_lean_needs_a_directive() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var afraid: Dictionary = _actor()
	afraid["fear"] = 100
	if arbiter._exposure_acceptance_parts({}, 0.12, 0.0)["acceptance"] != 0.0:
		return _fail("an empty Directive must give acceptance 0 whatever the fear lean")
	if _acceptance_at(arbiter, cfg, {}, afraid) != 0.0:
		return _fail("frightened actor with an empty Directive scored a non-zero acceptance term")
	var no_tolerance: Dictionary = {"intent_weights": {"exposure_acceptance": 1.0}}
	if not is_equal_approx(arbiter._exposure_acceptance_parts(no_tolerance, 0.12, 0.0)["acceptance"], -0.12):
		return _fail("a Directive without tolerance must give D = 0 minus the lean")
	if arbiter._exposure_acceptance_parts(no_tolerance, 0.0, 0.0)["acceptance"] != 0.0:
		return _fail("a Directive without tolerance and a calm actor must give 0")
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"]) * _afraid_part(afraid)
	if not is_equal_approx(_acceptance_at(arbiter, cfg, no_tolerance, afraid), -bound):
		return _fail("frightened actor without tolerance should score -fear_lean_bound")
	var bare := BehaviorArbiter.new({}, {"spatial_utility": cfg})
	if bare._exposure_acceptance_parts({"exposure_tolerance": 0.8}, 0.0, 0.0)["acceptance"] != 0.0:
		return _fail("a missing exposure_acceptance block must give D = 0")
	return _pass()


static func _t_fear_lean_bound_validated() -> Dictionary:
	var movement: Dictionary = (_shipped_movement_and_directives()["movement"] as Dictionary).duplicate(true)
	for bad: Variant in [NAN, INF, -INF, "0.12", null, -0.01, 1.01]:
		(movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"] = bad
		if bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("fear_lean_bound %s was accepted" % str(bad))
	for good: Variant in [0, 0.0, 0.12, 1]:
		(movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"] = good
		if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("fear_lean_bound %s was rejected" % str(good))
	return _pass()


static func _t_fear_bound_is_combat_owned() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var data: Dictionary = (cs.get_balance()["data"] as Dictionary).duplicate(true)
	var movement: Dictionary = (data["combat"] as Dictionary)["movement"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var afraid: Dictionary = _actor()
	afraid["fear"] = 70
	var before: float = arbiter._fear_lean(afraid, 0.0)
	var party_stance: Dictionary = (data["stages"] as Dictionary)["party_stance"] as Dictionary
	(party_stance["bounds"] as Dictionary)["exposure_tolerance"] = 0.45
	(party_stance["leans"] as Dictionary)["exposure_tolerance"] = { "fear": -5.0 }
	var after: float = arbiter._fear_lean(afraid, 0.0)
	var want: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"]) * _afraid_part(afraid)
	if before <= 0.0 or after != before or not is_equal_approx(after, want):
		return _fail("changing the stage block moved the combat fear lean: %s then %s, expected %s" % [before, after, want])
	return _pass()


## Production path: CombatTurnContextService.build_turn_context -> select_movement_intent.
## Fails if the arbiter stops reading the actor view and composure for the lean.
static func _t_fear_lean_reaches_arbiter_through_turn_context() -> Dictionary:
	var movement: Dictionary = (_shipped_movement_and_directives()["movement"] as Dictionary)
	var terms: Array = []
	for fear: int in [0, 60]:
		var run: Dictionary = _turn_context_run("directive.seek_signs", fear, 0.3)
		if run.has("error"):
			return _fail("%s (fear %d)" % [run["error"], fear])
		var spatial: Dictionary = run["spatial"] as Dictionary
		var exposure: float = float(spatial["exposure"]) / float((movement["spatial_utility"] as Dictionary)["exposure_weight"])
		terms.append({"term": float(spatial["directive_exposure_acceptance"]), "exposure": exposure})
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	var weight: float = float((movement["spatial_utility"] as Dictionary)["directive_exposure_acceptance_weight"])
	var calm: Dictionary = terms[0] as Dictionary
	var afraid: Dictionary = terms[1] as Dictionary
	if not is_equal_approx(float(calm["exposure"]), float(afraid["exposure"])) or float(calm["exposure"]) <= 0.0:
		return _fail("the two runs scored different or zero exposure: %s" % str(terms))
	var afraid_actor: Dictionary = _actor()
	afraid_actor["fear"] = 60
	var dampen: float = float(_composure_dampen_scale() * _TURN_COMPOSURE)
	var expected_drop: float = weight * bound * _afraid_part(afraid_actor) * (1.0 - dampen) * float(calm["exposure"])
	if not is_equal_approx(float(calm["term"]) - float(afraid["term"]), expected_drop) or expected_drop <= 0.0:
		return _fail("afraid Echo term should be lower by %s; calm %s afraid %s" % [expected_drop, calm["term"], afraid["term"]])
	return _pass()


const _TURN_COMPOSURE: float = 0.25


static func _composure_dampen_scale() -> float:
	var cs := ConfigService.new()
	cs.load_balance()
	return float((((cs.get_balance()["data"] as Dictionary)["maturity_expression"] as Dictionary)["composure_dampen_scale"] as Dictionary)["value"])


## One Echo through build_turn_context and select_movement_intent on the open fixture.
## `judgment` is set on the context as ActorStateMachine does. Returns the spatial
## decomposition of the first exposed route candidate, or {"error": ...}.
static func _turn_context_run(directive_id: String, fear: int, judgment: float) -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var balance: Dictionary = config.get_balance()
	var bdata: Dictionary = balance["data"] as Dictionary
	var movement: Dictionary = (bdata["combat"] as Dictionary)["movement"] as Dictionary
	var fixture: Dictionary = _open_fixture(20, 4, {"col": 2, "row": 1}, {})
	var actor: Dictionary = fixture["context"]["actor"] as Dictionary
	actor["fear"] = fear
	var flow_ctx := FlowContext.new()
	flow_ctx.save_data = {"stage_context": {"active_directive_id": directive_id}}
	var ectx := EncounterContext.new()
	ectx.encounter_id = "test.turn_context_run"
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.actors = fixture["context"]["all_actors"] as Array
	flow_ctx.encounter_ctx = ectx
	var directives := DirectiveService.new(flow_ctx.save_data)
	directives.load_from_config(balance)
	var svc := CombatTurnContextService.new(flow_ctx, config, directives, StructuredLogger.new())
	var ctx: Dictionary = svc.build_turn_context(actor, ectx, balance, bdata, 1, 1)["ctx"]
	ctx["judgment"] = judgment
	ctx["composure"] = _TURN_COMPOSURE
	var exposed: Array = []
	for option_value: Variant in fixture["options"] as Array:
		if float((option_value as Dictionary)["exposure"]) > 0.0:
			exposed.append(option_value)
	if exposed.is_empty():
		return {"error": "fixture produced no exposed option"}
	exposed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["option_id"]) < str(b["option_id"]))
	exposed = [exposed[0]]
	var arbiter := BehaviorArbiter.new({}, movement)
	var result: Dictionary = arbiter.select_movement_intent(
		ctx, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary, fixture["goals"] as Array, exposed)
	if not bool(result.get("valid", false)):
		return {"error": "selection failed: %s" % str(result)}
	var inputs: Dictionary = result["_decision_inputs"] as Dictionary
	for key: String in ["winner", "runner_up"]:
		var candidate_spatial: Dictionary = (inputs[key] as Dictionary).get("spatial", {}) as Dictionary
		if candidate_spatial.has("parts"):
			return {"spatial": candidate_spatial["parts"], "acceptance_parts": candidate_spatial.get("acceptance_parts", {})}
	return {"error": "no route candidate reached the decision trace"}


## Judgment as the combat pipeline builds it: real Standing (rank), the Standing XP row, a real
## calling, build_ctx_inputs and derive_expression. Fear and bonds are optional inputs.
static func _production_judgment(rank: int, calling: String, fear: int = 0, bonds: Array = []) -> float:
	var cs := ConfigService.new()
	cs.load_balance()
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var actor: Dictionary = _judgment_actor(bdata, rank, calling, fear)
	var inputs: Dictionary = MaturityExpressionService.build_ctx_inputs(
		actor, bonds, {}, bdata, ConfigService.get_bond_thresholds_cfg(cs), {}, 0.0)
	return float(MaturityExpressionService.derive_expression(actor, inputs, bdata["maturity_expression"] as Dictionary).get("judgment", -1.0))


static func _judgment_actor(bdata: Dictionary, rank: int, calling: String, fear: int) -> Dictionary:
	var thresholds: Array = (bdata["progression"] as Dictionary)["level_thresholds"] as Array
	var echo := ActorTests._make_test_echo("echo_j%d" % rank, "Judgment")
	echo["rank"] = rank
	echo["xp_total"] = int(thresholds[mini(rank, thresholds.size()) - 1])
	echo["calling"] = calling
	echo["vector_scores"] = {"protector": 150, "pillar": 40}
	echo["emotion"] = {"morale_current": 50, "fear_current": fear, "fear_base": 0}
	return EchoActor.from_echo(echo)


static func _accept_parts(arbiter: BehaviorArbiter, cfg: Dictionary, directive: Dictionary, actor: Dictionary, judgment: float) -> Dictionary:
	var parts: Dictionary = {}
	arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, _exposed_option(0.0), directive, cfg, parts, arbiter._fear_lean(actor, 0.0), judgment)
	return parts["acceptance_parts"] as Dictionary


static func _scout_seek() -> Array:
	var directives: Dictionary = _shipped_movement_and_directives()["directives"] as Dictionary
	return [directives["directive.scout_carefully"], directives["directive.seek_signs"]]


static func _floor_a(movement: Dictionary) -> float:
	return float((movement["directive_judgment"] as Dictionary)["judgment_floor"])


static func _t_acceptance_falls_with_judgment() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var offset: float = float((movement["exposure_acceptance"] as Dictionary)["offset"])
	var floor_a: float = _floor_a(movement)
	var js: Array = []
	for rank: int in [1, 6, 9]:
		js.append(_production_judgment(rank, "okofor"))
	if not (float(js[0]) < float(js[1]) and float(js[1]) < float(js[2])):
		return _fail("production Judgment must rise with Standing 1, 6, 9: %s" % str(js))
	for directive_value: Variant in _scout_seek():
		var directive: Dictionary = directive_value as Dictionary
		var d: float = absf(float(directive["exposure_tolerance"]) - offset)
		var previous: float = INF
		for j: float in js:
			var scaled: float = absf(float(_accept_parts(arbiter, cfg, directive, _actor(), j)["D_scaled"]))
			if scaled >= previous or scaled < floor_a * d - 0.0000001 or scaled > d + 0.0000001:
				return _fail("|D_scaled| %s at J %s (previous %s) must fall inside [%s, %s]" % [scaled, j, previous, floor_a * d, d])
			previous = scaled
	return _pass()


static func _t_acceptance_judgment_scale_keeps_sign() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var pair: Array = _scout_seek()
	for j: float in [0.0, 0.2, 0.5, 0.85, 1.0, 7.0, -3.0]:
		if float(_accept_parts(arbiter, cfg, pair[0] as Dictionary, _actor(), j)["D_scaled"]) >= 0.0:
			return _fail("Scout D_scaled must stay negative at J %s" % j)
		if float(_accept_parts(arbiter, cfg, pair[1] as Dictionary, _actor(), j)["D_scaled"]) <= 0.0:
			return _fail("Seek D_scaled must stay positive at J %s" % j)
	return _pass()


## Two route options with equal progress, one exposed and one not. The margin is the score
## gap the Directive part of acceptance adds to the choice.
static func _t_seasoned_echo_reads_directive_exposure_less_literally() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var goal: Dictionary = {"urgency": 0.0, "purpose": "advance"}
	var exposed: Dictionary = _exposed_option(0.3)
	var covered: Dictionary = _exposed_option(0.3)
	covered["exposure"] = 0.0
	var young: float = _production_judgment(1, "okofor")
	var seasoned: float = _production_judgment(9, "okofor")
	var pair: Array = _scout_seek()
	var margins: Array = []
	for directive_value: Variant in pair:
		var row: Array = []
		for j: float in [young, seasoned]:
			var gap: float = arbiter._spatial_utility(goal, exposed, directive_value as Dictionary, cfg, {}, 0.0, j) \
				- arbiter._spatial_utility(goal, covered, directive_value as Dictionary, cfg, {}, 0.0, j)
			row.append(gap)
		margins.append(row)
	var scout: Array = margins[0] as Array
	var seek: Array = margins[1] as Array
	if float(scout[0]) >= 0.0 or float(scout[1]) >= 0.0:
		return _fail("Scout margins (young, seasoned) should both favour the covered option: %s" % str(scout))
	if absf(float(scout[0])) <= absf(float(scout[1])):
		return _fail("young Scout must avoid the exposed option by a larger margin than a seasoned one: %s" % str(scout))
	if float(seek[0]) <= float(seek[1]):
		return _fail("young Seek must be pulled to the exposed option by a larger margin than a seasoned one: %s" % str(seek))
	return _pass()


static func _t_directive_contrast_narrows_but_never_closes() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var pair: Array = _scout_seek()
	var gaps: Array = []
	for rank: int in [1, 9]:
		var j: float = _production_judgment(rank, "okofor")
		gaps.append(float(_accept_parts(arbiter, cfg, pair[1] as Dictionary, _actor(), j)["acceptance"]) - float(_accept_parts(arbiter, cfg, pair[0] as Dictionary, _actor(), j)["acceptance"]))
	if not (float(gaps[1]) < float(gaps[0]) and float(gaps[1]) > 0.0):
		return _fail("Seek minus Scout acceptance must narrow from Standing 1 to 9 and stay above 0: %s" % str(gaps))
	return _pass()


## Growth in an anchor Echo and in an edge Echo, with the Judgment the pipeline produces.
static func _t_acceptance_growth_anchor_and_edge() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var scout: Dictionary = _scout_seek()[0] as Dictionary
	for calling: String in ["okofor", "aduro"]:
		var j1: float = _production_judgment(1, calling)
		var j6: float = _production_judgment(6, calling)
		if j6 <= j1:
			return _fail("%s: Judgment at Standing 6 (%s) must exceed Standing 1 (%s)" % [calling, j6, j1])
		var a1: float = absf(float(_accept_parts(arbiter, cfg, scout, _actor(), j1)["acceptance"]))
		var a6: float = absf(float(_accept_parts(arbiter, cfg, scout, _actor(), j6)["acceptance"]))
		if a6 >= a1:
			return _fail("%s: Scout |acceptance| must fall from Standing 1 (%s) to 6 (%s)" % [calling, a1, a6])
	return _pass()


## Step by step. Expected values come from the config keys and the formula written out here,
## not from the arbiter.
static func _t_acceptance_order_of_operations() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var block: Dictionary = movement["exposure_acceptance"] as Dictionary
	var floor_a: float = _floor_a(movement)
	var bound: float = float(block["fear_lean_bound"])
	var pair: Array = _scout_seek()
	var cases: Array = [[0.2, 0], [0.85, 0], [0.025, 70], [0.675, 70]]
	for case: Array in cases:
		var j: float = float(case[0])
		var actor: Dictionary = _actor()
		actor["fear"] = int(case[1])
		for directive_value: Variant in pair:
			var directive: Dictionary = directive_value as Dictionary
			var d: float = float(directive["exposure_tolerance"]) - float(block["offset"])
			var want_scaled: float = d * (floor_a + (1.0 - floor_a) * (1.0 - j))
			var want_f: float = bound * _afraid_part(actor)
			var got: Dictionary = _accept_parts(arbiter, cfg, directive, actor, j)
			if not is_equal_approx(float(got["D_scaled"]), want_scaled) or not is_equal_approx(float(got["F"]), want_f) \
					or not is_equal_approx(float(got["acceptance"]), want_scaled - want_f):
				return _fail("J %s fear %s T %s: got %s, wanted D_scaled %s F %s" % [j, case[1], directive["exposure_tolerance"], str(got), want_scaled, want_f])
	return _pass()


static func _t_acceptance_missing_tolerance_is_neutral_plus_fear() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var no_tolerance: Dictionary = {"intent_weights": {"exposure_acceptance": 1.0}}
	var afraid: Dictionary = _actor()
	afraid["fear"] = 100
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	for j: float in [0.0, 0.5, 1.0]:
		var got: Dictionary = _accept_parts(arbiter, cfg, no_tolerance, afraid, j)
		if float(got["D_scaled"]) != 0.0 or not is_equal_approx(float(got["acceptance"]), -bound):
			return _fail("no tolerance at J %s: expected D_scaled 0 and acceptance %s, got %s" % [j, -bound, str(got)])
	return _pass()


## Own side of the acceptance layer is the action layer's identity scale when the style grows
## with Judgment, else 1.0.
static func _swing_numbers() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var data: Dictionary = cs.get_balance()["data"] as Dictionary
	var movement: Dictionary = (data["combat"] as Dictionary)["movement"] as Dictionary
	var felt: Dictionary = movement["felt_state"] as Dictionary
	var expr: Dictionary = data["maturity_expression"] as Dictionary
	var scale: Dictionary = expr["identity_weight_scale"] as Dictionary
	var identity: float = 1.0 + maxf(float(scale["trait"]), float(scale["vector"]))
	var lean: Dictionary = felt["lean"] as Dictionary
	var mul: Dictionary = expr["directive_interpretation_mul"] as Dictionary
	return {
		"budget": float((expr["interpretation_swing_max"] as Dictionary).get("value", 0.0)),
		"block": movement["directive_judgment"] as Dictionary,
		"own_style": identity if bool((felt["style_growth"] as Dictionary)["enabled"]) else 1.0,
		"lean_side": maxf(float(lean["cohesion_max"]), float(lean["progress_max"]) if bool(lean["enabled"]) else 1.0),
		"low_over_high": float(mul["low"]) / float(mul["high"]),
		"action_own": identity,
	}


static func _t_acceptance_swing_within_declared_budget() -> Dictionary:
	var n: Dictionary = _swing_numbers()
	var block: Dictionary = n["block"] as Dictionary
	if float(n["budget"]) <= 0.0 or not block.has("judgment_floor"):
		return _fail("fixture broken: budget %s, judgment_floor present %s" % [n["budget"], block.has("judgment_floor")])
	var swing: float = DirectiveJudgmentScale.swing(block, float(n["own_style"]))
	if swing > float(n["budget"]):
		return _fail("acceptance swing %s exceeds interpretation_swing_max %s (judgment_floor_min is the key that would move)" % [swing, n["budget"]])
	if not is_equal_approx(swing, float(n["own_style"]) / float(block["judgment_floor"])):
		return _fail("the swing must be own side / judgment_floor, got %s" % swing)
	if DirectiveJudgmentScale.swing({}) != 1.0 or DirectiveJudgmentScale.swing({}, 1.35) != 1.35:
		return _fail("a missing judgment_floor scales by 1.0, so its swing is the own side")
	if DirectiveJudgmentScale.swing({"judgment_floor": 0.0}) != INF:
		return _fail("a floor of 0 must read as an unbounded swing")
	return _pass()


static func _t_felt_state_swing_within_declared_budget() -> Dictionary:
	var n: Dictionary = _swing_numbers()
	var swing: float = DirectiveJudgmentScale.swing(n["block"] as Dictionary, float(n["lean_side"]))
	if swing > float(n["budget"]):
		return _fail("state-lean swing %s exceeds interpretation_swing_max %s" % [swing, n["budget"]])
	return _pass()


## Largest own side over the smallest Directive-side factor, across layers.
static func _t_cross_layer_pair_within_declared_budget() -> Dictionary:
	var n: Dictionary = _swing_numbers()
	var own: float = maxf(maxf(float(n["own_style"]), float(n["lean_side"])), float(n["action_own"]))
	var pair: float = own / minf(float(n["low_over_high"]), float((n["block"] as Dictionary)["judgment_floor"]))
	if pair > float(n["budget"]):
		return _fail("cross-layer swing %s exceeds interpretation_swing_max %s" % [pair, n["budget"]])
	return _pass()


static func _t_swing_layer_ceilings_consistent() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var swing_cfg: Dictionary = (((cs.get_balance()["data"] as Dictionary)["maturity_expression"] as Dictionary)["interpretation_swing_max"]) as Dictionary
	var budget: float = float(swing_cfg.get("value", 0.0))
	var layers: Dictionary = swing_cfg.get("layer_max", {}) as Dictionary
	if budget <= 0.0 or layers.is_empty():
		return _fail("fixture broken: budget %s, layer_max %s" % [budget, str(layers)])
	for layer: String in ["action", "stop"]:
		if not layers.has(layer):
			return _fail("layer_max.%s is missing" % layer)
	for layer: String in layers:
		var ceiling: Variant = layers[layer]
		if layer.begins_with("_"):
			continue
		if not (ceiling is int or ceiling is float) or float(ceiling) <= 0.0 or float(ceiling) > budget:
			return _fail("layer_max.%s = %s must be positive and at most %s" % [layer, str(ceiling), budget])
	return _pass()


static func _t_judgment_floor_validated_and_neutral_when_missing() -> Dictionary:
	var movement: Dictionary = (_shipped_movement_and_directives()["movement"] as Dictionary).duplicate(true)
	var block: Dictionary = movement["directive_judgment"] as Dictionary
	var floor_min: float = float(block["judgment_floor_min"])
	for bad: Variant in [NAN, INF, -INF, "0.6", null, floor_min - 0.01, 1.01, 0.0, -0.6]:
		block["judgment_floor"] = bad
		if bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("judgment_floor %s was accepted" % str(bad))
	for good: Variant in [floor_min, 0.6, 1, 1.0]:
		block["judgment_floor"] = good
		if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("judgment_floor %s was rejected" % str(good))
	block.erase("judgment_floor")
	var arbiter := BehaviorArbiter.new({}, movement)
	var seek: Dictionary = _scout_seek()[1] as Dictionary
	if not bool(arbiter._validate_spatial_config()["valid"]):
		return _fail("a block without judgment_floor must stay valid")
	var offset: float = float((movement["exposure_acceptance"] as Dictionary)["offset"])
	for j: float in [0.0, 0.5, 1.0]:
		if not is_equal_approx(arbiter._exposure_acceptance_parts(seek, 0.0, j)["acceptance"], float(seek["exposure_tolerance"]) - offset):
			return _fail("a missing judgment_floor must scale by 1.0 (J %s)" % j)
	return _pass()


static func _t_acceptance_rejects_non_finite_judgment() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var fixture: Dictionary = _open_fixture(20, 4, {"col": 2, "row": 1}, {})
	var arbiter := BehaviorArbiter.new({}, shipped["movement"] as Dictionary)
	for bad: Variant in [NAN, INF, "0.3"]:
		var ctx: Dictionary = (fixture["context"] as Dictionary).duplicate(true)
		ctx["judgment"] = bad
		var result: Dictionary = arbiter.select_movement_intent(
			ctx, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary, fixture["goals"] as Array, fixture["options"] as Array)
		if bool(result.get("valid", false)):
			return _fail("judgment %s was accepted" % str(bad))
	var missing: Dictionary = (fixture["context"] as Dictionary).duplicate(true)
	missing.erase("judgment")
	var refused: Dictionary = arbiter.select_movement_intent(
		missing, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary, fixture["goals"] as Array, fixture["options"] as Array)
	if bool(refused.get("valid", false)) or str(refused.get("reason", "")) != "missing_judgment":
		return _fail("a context without judgment must fail with missing_judgment: %s" % str(refused))
	return _pass()


static func _t_fear_lean_not_scaled_by_judgment() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var afraid: Dictionary = _actor()
	afraid["fear"] = 70
	var young: float = _production_judgment(1, "okofor", 70)
	var seasoned: float = _production_judgment(9, "okofor", 70)
	if seasoned <= young:
		return _fail("fixture broken: Judgment %s then %s" % [young, seasoned])
	for directive_value: Variant in _scout_seek():
		var low: Dictionary = _accept_parts(arbiter, cfg, directive_value as Dictionary, afraid, young)
		var high: Dictionary = _accept_parts(arbiter, cfg, directive_value as Dictionary, afraid, seasoned)
		if not is_equal_approx(float(low["F"]), float(high["F"])) or float(low["F"]) <= 0.0:
			return _fail("fear lean must be equal and above 0 at J %s and %s: %s / %s" % [young, seasoned, low["F"], high["F"]])
		if is_equal_approx(float(low["D_scaled"]), float(high["D_scaled"])):
			return _fail("D_scaled must differ between J %s and %s" % [young, seasoned])
	return _pass()


## More fear never raises acceptance across Judgment, with the rule derived from config. Fear lowers
## Judgment by `fear_pressure_weight` x the afraid part, which raises the Directive scale. One ladder step
## of size s raises acceptance by at most (1 - floor) x weight x max|D| x s and lowers it by bound x s.
## Rule: bound x largest step is at least that rise at the largest step.
static func _t_more_fear_never_more_accepting_across_judgment() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var data: Dictionary = cs.get_balance()["data"] as Dictionary
	var movement: Dictionary = ((data["combat"] as Dictionary)["movement"] as Dictionary)
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var block: Dictionary = movement["exposure_acceptance"] as Dictionary
	var pressure: float = float((((data["maturity_expression"] as Dictionary)["autonomy_outputs"] as Dictionary)["judgment"] as Dictionary)["fear_pressure_weight"])
	var arbiter := BehaviorArbiter.new({}, movement)
	var max_d := 0.0
	for directive_value: Variant in _scout_seek():
		max_d = maxf(max_d, absf(float((directive_value as Dictionary)["exposure_tolerance"]) - float(block["offset"])))
	var step: float = _largest_step(_band_lean())
	var judgment_rise: float = (1.0 - _floor_a(movement)) * pressure * max_d * step
	if float(block["fear_lean_bound"]) * step < judgment_rise:
		return _fail("bound x largest step %s is below the Judgment path rise %s" % [float(block["fear_lean_bound"]) * step, judgment_rise])
	for directive_value: Variant in _scout_seek():
		var directive: Dictionary = directive_value as Dictionary
		for j0: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var previous: float = float(_accept_parts(arbiter, cfg, directive, _actor(), j0)["acceptance"])
			for fear: int in range(1, 101):
				var actor: Dictionary = _actor()
				actor["fear"] = fear
				var j: float = clampf(j0 - pressure * _afraid_part(actor), 0.0, 1.0)
				var value: float = float(_accept_parts(arbiter, cfg, directive, actor, j)["acceptance"])
				if value > previous + 0.0000001:
					return _fail("T %s J0 %s fear %d: acceptance rose from %s to %s" % [directive["exposure_tolerance"], j0, fear, previous, value])
				previous = value
	return _pass()


## Judgment reaches the style alignment only as the two identity multipliers, 1 + J x
## identity_weight_scale (the action layer's scale). The state parts stay unscaled; that is pinned by
## felt_state/style_growth_scales_only_identity_parts.
static func _t_acceptance_own_side_equals_identity_scale() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var data: Dictionary = cs.get_balance()["data"] as Dictionary
	var movement: Dictionary = ((data["combat"] as Dictionary)["movement"] as Dictionary).duplicate(true)
	var scale: Dictionary = (data["maturity_expression"] as Dictionary)["identity_weight_scale"] as Dictionary
	((movement["felt_state"] as Dictionary)["style_growth"] as Dictionary)["enabled"] = true
	var arbiter := BehaviorArbiter.new({}, movement)
	for j: float in [0.0, 0.4, 1.0]:
		var growth: Dictionary = arbiter._style_growth(j)
		if not is_equal_approx(float(growth["vector_mul"]), 1.0 + j * float(scale["vector"])) \
				or not is_equal_approx(float(growth["trait_mul"]), 1.0 + j * float(scale["trait"])):
			return _fail("J %s: growth %s is not 1 + J x identity_weight_scale %s" % [j, str(growth), str(scale)])
	return _pass()


## Through ActorStateMachine, not a hand-written ctx: Judgment is derived from the actor's own
## Standing, then read back from the decision inputs the arbiter returned.
class _InputsArbiter extends BehaviorArbiter:
	var inputs: Dictionary = {}
	var probe: Dictionary = {}

	func _init(actor_cfg: Dictionary = {}, movement_cfg: Dictionary = {}) -> void:
		super(actor_cfg, movement_cfg)

	func select_movement_intent(context: Dictionary, movement_context: Dictionary, profile: Dictionary, goals: Array, options: Array) -> Dictionary:
		var result: Dictionary = super(context, movement_context, profile, goals, options)
		inputs = result.get("_decision_inputs", {}) as Dictionary
		probe = result.get("_divergence_probe", {}) as Dictionary
		return result


static func _t_judgment_reaches_acceptance_through_actor_state_machine() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var scout: Dictionary = (shipped["directives"] as Dictionary)["directive.scout_carefully"] as Dictionary
	var block: Dictionary = movement["exposure_acceptance"] as Dictionary
	var d: float = float(scout["exposure_tolerance"]) - float(block["offset"])
	var scaled: Array = []
	for rank: int in [1, 9]:
		var fixture: Dictionary = _open_fixture(20, 4, {}, scout)
		var actor: Dictionary = _judgment_actor(bdata, rank, "okofor", 0)
		actor["id"] = "echo.a"
		actor["grid_pos"] = {"col": 0, "row": 0}
		var context: Dictionary = {
			"actor": actor, "all_actors": [], "t": 1, "cfg": {"data": bdata}, "directive": scout,
			"movement_context": fixture["movement_context"], "movement_profile": fixture["profile"],
			"movement_goals": fixture["goals"], "movement_options": fixture["options"],
		}
		var module := _InputsArbiter.new({}, movement)
		var machine := ActorStateMachine.new(actor, module)
		machine.advance_turn(context, StructuredLogger.new(), 1)
		var found: Dictionary = {}
		for key: String in ["winner", "runner_up"]:
			var spatial: Dictionary = (module.inputs.get(key, {}) as Dictionary).get("spatial", {}) as Dictionary
			if spatial.has("acceptance_parts"):
				found = spatial["acceptance_parts"] as Dictionary
				break
		if found.is_empty():
			return _fail("rank %d: ActorStateMachine produced no route candidate with acceptance_parts" % rank)
		var j: float = float(actor["_judgment"])
		var floor_a: float = _floor_a(movement)
		var want: float = d * (floor_a + (1.0 - floor_a) * (1.0 - j))
		if not is_equal_approx(float(found["D_scaled"]), want):
			return _fail("rank %d: D_scaled %s, wanted %s from the Echo's own Judgment %s" % [rank, found["D_scaled"], want, j])
		scaled.append(absf(float(found["D_scaled"])))
	if float(scaled[1]) >= float(scaled[0]):
		return _fail("the seasoned Echo's |D_scaled| %s must be smaller than the young Echo's %s" % [scaled[1], scaled[0]])
	return _pass()


## Movement-style bias the decision recorded for a seasoned Echo, through ActorStateMachine.
## `growth_enabled` null removes the style_growth block.
static func _style_bias_of(growth_enabled: Variant) -> float:
	var cs := ConfigService.new()
	cs.load_balance()
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = (shipped["movement"] as Dictionary).duplicate(true)
	var felt: Dictionary = movement["felt_state"] as Dictionary
	if growth_enabled == null:
		felt.erase("style_growth")
	else:
		(felt["style_growth"] as Dictionary)["enabled"] = growth_enabled
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var scout: Dictionary = (shipped["directives"] as Dictionary)["directive.scout_carefully"] as Dictionary
	var fixture: Dictionary = _open_fixture(20, 4, {}, scout)
	var actor: Dictionary = _judgment_actor(bdata, 9, "okofor", 0)
	actor["vector_scores"] = {"strategist": 150}
	actor["id"] = "echo.a"
	actor["grid_pos"] = {"col": 0, "row": 0}
	var context: Dictionary = {
		"actor": actor, "all_actors": [], "t": 1, "cfg": {"data": bdata}, "directive": scout,
		"movement_context": fixture["movement_context"], "movement_profile": fixture["profile"],
		"movement_goals": fixture["goals"], "movement_options": fixture["options"],
	}
	var actor_cfg: Dictionary = ConfigService.merge_actor_cfg(
		bdata["actor"] as Dictionary, bdata["maturity_expression"] as Dictionary)
	var module := _InputsArbiter.new(actor_cfg, movement)
	ActorStateMachine.new(actor, module).advance_turn(context, StructuredLogger.new(), 1)
	for key: String in ["winner", "runner_up"]:
		var bias: Dictionary = (module.inputs.get(key, {}) as Dictionary).get("bias", {}) as Dictionary
		if bias.has("movement_style"):
			return float(bias["movement_style"])
	return NAN


static func _t_style_growth_reaches_movement_style_through_actor_state_machine() -> Dictionary:
	var on: float = _style_bias_of(true)
	var off: float = _style_bias_of(false)
	var absent: float = _style_bias_of(null)
	if is_nan(on) or is_nan(off) or is_nan(absent):
		return _fail("no movement_style bias recorded (on %s off %s absent %s)" % [on, off, absent])
	if is_equal_approx(on, off):
		return _fail("style_growth on must change the seasoned Echo's movement_style bias; both are %s" % on)
	if not is_equal_approx(off, absent):
		return _fail("style_growth off %s must equal block absent %s" % [off, absent])
	return _pass()


## One Scout turn with a hostile in reach, through ActorStateMachine. `stop_directive` false removes the
## Directive stop cause. Returns the arbiter module with its recorded inputs and divergence probe.
static func _scout_stop_turn(stop_directive: bool) -> _InputsArbiter:
	var cs := ConfigService.new()
	cs.load_balance()
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var scout: Dictionary = (shipped["directives"] as Dictionary)["directive.scout_carefully"] as Dictionary
	var fixture: Dictionary = _open_fixture(20, 4, {"col": 5, "row": 1}, scout)
	((fixture["goals"] as Array)[0] as Dictionary)["urgency"] = 0.0
	var actor: Dictionary = _judgment_actor(bdata, 1, "okofor", 0)
	(actor["stats"] as Dictionary)["def"] = 5
	actor["id"] = "echo.a"
	actor["grid_pos"] = {"col": 0, "row": 0}
	var actor_cfg: Dictionary = ConfigService.merge_actor_cfg(
		bdata["actor"] as Dictionary, bdata["maturity_expression"] as Dictionary).duplicate(true)
	var stop: Dictionary = actor_cfg["stop_short"] as Dictionary
	stop["enabled"] = true
	stop["stop_short_weight"] = 40.0
	stop["identity"] = {}
	if not stop_directive:
		stop["directive"] = {}
	var context: Dictionary = {
		"actor": actor, "all_actors": (fixture["context"] as Dictionary)["all_actors"], "t": 1, "cfg": {"data": bdata},
		"directive": scout,
		"movement_context": fixture["movement_context"], "movement_profile": fixture["profile"],
		"movement_goals": fixture["goals"], "movement_options": fixture["options"],
	}
	var module := _InputsArbiter.new(actor_cfg, movement)
	ActorStateMachine.new(actor, module).advance_turn(context, StructuredLogger.new(), 1)
	return module


## The Directive's voice in a route's score (stop bias, exposure acceptance) is removed from the
## Echo's own score: a Scout Echo that stops on the Directive cause is not reported as acting on its own.
static func _t_directive_stop_is_not_own_judgment() -> Dictionary:
	var key: String = StopShortService.bias_key("directive")
	var on := _scout_stop_turn(true)
	var winner: Dictionary = on.inputs["winner"] as Dictionary
	var bias: float = float((winner["bias"] as Dictionary).get(key, 0.0))
	if bias <= 0.0:
		return _fail("fixture: the Scout Echo did not stop on the Directive cause: %s" % str(winner["bias"]))
	var chosen: Dictionary = on.probe["chosen"] as Dictionary
	var parts: Dictionary = (winner["spatial"] as Dictionary)["parts"] as Dictionary
	var want: float = float((winner["components"] as Dictionary)["directive_bonus"]) + bias + float((winner["spatial"] as Dictionary)["directive_route_part"])
	if not is_equal_approx(float(chosen["directive_bonus"]), want):
		return _fail("directive_bonus %s, wanted type bonus + stop bias + acceptance = %s" % [chosen["directive_bonus"], want])
	var off := _scout_stop_turn(false)
	var off_winner: Dictionary = off.inputs["winner"] as Dictionary
	if (off_winner["bias"] as Dictionary).has(key):
		return _fail("fixture: the stop cause is still present with the Directive stop block removed")
	var off_parts: Dictionary = (off_winner["spatial"] as Dictionary)["parts"] as Dictionary
	var off_want: float = float((off_winner["components"] as Dictionary)["directive_bonus"]) + float((off_winner["spatial"] as Dictionary)["directive_route_part"])
	if not is_equal_approx(float((off.probe["chosen"] as Dictionary)["directive_bonus"]), off_want):
		return _fail("an Echo with no Directive stop must keep the plain directive_bonus")
	return _pass()


## Advance, over-commit, protection and interception terms are Directive voice: the route part holds all five.
static func _t_all_directive_terms_leave_own_score() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var directive: Dictionary = ((shipped["directives"] as Dictionary)["directive.seek_signs"] as Dictionary).duplicate(true)
	directive["intent_weights"] = {
		"objective_advance_priority": 0.8, "avoid_overcommit": 0.5,
		"ally_protection_bias": 0.6, "threat_interception": 0.7,
	}
	var spatial: Dictionary = {}
	BehaviorArbiter.new({}, movement)._spatial_utility({"urgency": 0.0, "purpose": "intercept"}, _exposed_option(0.5), directive, cfg, spatial, 0.0, 0.0)
	var parts: Dictionary = spatial["parts"] as Dictionary
	var want: float = float(spatial["directive_exposure_part"])
	for name: String in ["objective_advance", "avoid_overcommit", "ally_protection", "threat_interception"]:
		var term: float = float(parts["directive_" + name])
		if is_zero_approx(term):
			return _fail("fixture: directive_%s is zero, the test proves nothing" % name)
		want += term
	var route: float = BehaviorArbiter._route_directive_part({"_spatial_components": spatial})
	if not is_equal_approx(route, want):
		return _fail("route Directive part %s, wanted all five Directive terms = %s" % [route, want])
	return _pass()


## The route Directive part is weight x D_scaled x exposure. The Echo's own fear lean stays in its own score.
static func _t_fear_lean_stays_in_own_score() -> Dictionary:
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var cfg: Dictionary = movement["spatial_utility"] as Dictionary
	var seek: Dictionary = (shipped["directives"] as Dictionary)["directive.seek_signs"] as Dictionary
	var weight: float = float(cfg["directive_exposure_acceptance_weight"])
	var d: float = clampf(float(seek["exposure_tolerance"]) - float((movement["exposure_acceptance"] as Dictionary)["offset"]), -1.0, 1.0)
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	var cs := ConfigService.new()
	cs.load_balance()
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, movement)
	var fear_part: Array = []
	for fear: int in [0, 60]:
		var actor: Dictionary = _judgment_actor(bdata, 1, "okofor", fear)
		var spatial: Dictionary = {}
		arbiter._spatial_utility({"urgency": 0.0, "purpose": "advance"}, _exposed_option(0.0), seek, cfg, spatial, arbiter._fear_lean(actor, 0.0), 0.0)
		var term: float = float((spatial["parts"] as Dictionary)["directive_exposure_acceptance"])
		var route: float = BehaviorArbiter._route_directive_part({"_spatial_components": spatial})
		var want_f: float = bound * _afraid_part(actor)
		var parts: Dictionary = spatial["parts"] as Dictionary
		var others: float = float(parts["directive_objective_advance"]) + float(parts["directive_avoid_overcommit"]) \
			+ float(parts["directive_ally_protection"]) + float(parts["directive_threat_interception"])
		if not is_equal_approx(float(spatial["directive_exposure_part"]), weight * d):
			return _fail("fear %d: exposure part %s, wanted weight x D_scaled x exposure = %s" % [fear, spatial["directive_exposure_part"], weight * d])
		if not is_equal_approx(route, weight * d + others):
			return _fail("fear %d: route Directive part %s, wanted exposure part + the four other terms = %s" % [fear, route, weight * d + others])
		if not is_equal_approx(term, weight * clampf(d - want_f, -1.0, 1.0)):
			return _fail("fear %d: whole term %s does not match weight x acceptance" % [fear, term])
		fear_part.append(term - float(spatial["directive_exposure_part"]))
	if not is_zero_approx(float(fear_part[0])):
		return _fail("calm Echo: the Directive part must equal the whole term, fear part %s" % fear_part[0])
	if float(fear_part[1]) >= -0.01:
		return _fail("afraid Echo: the fear penalty %s must stay in the Echo's own score" % fear_part[1])
	return _pass()


## Through ActorStateMachine: the fear lean is the bound times the afraid part of the status, softened by
## the composure the machine derives for the Echo (not injected). A seasoned Echo leans less.
static func _t_fear_lean_reaches_acceptance_through_actor_state_machine() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var shipped: Dictionary = _shipped_movement_and_directives()
	var movement: Dictionary = shipped["movement"] as Dictionary
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var scout: Dictionary = (shipped["directives"] as Dictionary)["directive.scout_carefully"] as Dictionary
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	var dampen: float = _composure_dampen_scale()
	var leans: Array = []
	for rank: int in [1, 9]:
		var fixture: Dictionary = _open_fixture(20, 4, {}, scout)
		var actor: Dictionary = _judgment_actor(bdata, rank, "okofor", 60)
		actor["id"] = "echo.a"
		actor["grid_pos"] = {"col": 0, "row": 0}
		var context: Dictionary = {
			"actor": actor, "all_actors": [], "t": 1, "cfg": {"data": bdata}, "directive": scout,
			"movement_context": fixture["movement_context"], "movement_profile": fixture["profile"],
			"movement_goals": fixture["goals"], "movement_options": fixture["options"],
		}
		var module := _InputsArbiter.new({}, movement)
		var machine := ActorStateMachine.new(actor, module)
		machine.advance_turn(context, StructuredLogger.new(), 1)
		var found: Dictionary = {}
		for key: String in ["winner", "runner_up"]:
			var spatial: Dictionary = (module.inputs.get(key, {}) as Dictionary).get("spatial", {}) as Dictionary
			if spatial.has("acceptance_parts"):
				found = spatial["acceptance_parts"] as Dictionary
				break
		if found.is_empty():
			return _fail("rank %d: no route candidate with acceptance_parts" % rank)
		var want: float = bound * _afraid_part(actor) * (1.0 - dampen * float(actor["_composure"]))
		if want <= 0.0 or not is_equal_approx(float(found["F"]), want):
			return _fail("rank %d: lean %s, wanted %s from composure %s" % [rank, found["F"], want, actor["_composure"]])
		leans.append(float(found["F"]))
	if float(leans[1]) >= float(leans[0]):
		return _fail("the seasoned Echo's lean %s must be smaller than the young Echo's %s" % [leans[1], leans[0]])
	return _pass()


## Judgment reaches the arbiter's spatial term from the turn context. Fails if the J argument
## of _spatial_utility is not passed.
static func _t_judgment_reaches_arbiter_through_turn_context() -> Dictionary:
	var movement: Dictionary = _shipped_movement_and_directives()["movement"] as Dictionary
	var weight: float = float((movement["spatial_utility"] as Dictionary)["directive_exposure_acceptance_weight"])
	var offset: float = float((movement["exposure_acceptance"] as Dictionary)["offset"])
	var floor_a: float = _floor_a(movement)
	var directives: Dictionary = _shipped_movement_and_directives()["directives"] as Dictionary
	var young: float = _production_judgment(1, "okofor")
	var seasoned: float = _production_judgment(9, "okofor")
	for id: String in ["directive.scout_carefully", "directive.seek_signs"]:
		var d: float = float((directives[id] as Dictionary)["exposure_tolerance"]) - offset
		var terms: Array = []
		for j: float in [young, seasoned]:
			var run: Dictionary = _turn_context_run(id, 0, j)
			if run.has("error"):
				return _fail("%s (J %s)" % [run["error"], j])
			var spatial: Dictionary = run["spatial"] as Dictionary
			var exposure: float = float(spatial["exposure"]) / float((movement["spatial_utility"] as Dictionary)["exposure_weight"])
			if exposure <= 0.0:
				return _fail("the run scored no exposure")
			var want: float = weight * d * (floor_a + (1.0 - floor_a) * (1.0 - j)) * exposure
			if not is_equal_approx(float(spatial["directive_exposure_acceptance"]), want):
				return _fail("%s J %s: term %s, wanted %s" % [id, j, spatial["directive_exposure_acceptance"], want])
			terms.append(absf(float(spatial["directive_exposure_acceptance"])))
		if float(terms[1]) >= float(terms[0]):
			return _fail("%s: the seasoned Echo's Directive exposure term %s must be smaller than the young Echo's %s" % [id, terms[1], terms[0]])
	return _pass()


## Combat code may read only the two shared ramp keys of the stage block.
static func _t_stage_bound_not_read_in_combat() -> Dictionary:
	var hits: Array = []
	var scanned := {"files": 0}
	for dir_path: String in ["res://core/actors", "res://core/combat", "res://core/emotion", "res://core/movement"]:
		_scan_for_stage_keys(dir_path, hits, scanned)
	if scanned["files"] < 20:
		return _fail("scan read only %d files" % scanned["files"])
	if not hits.is_empty():
		return _fail("stage block key read in combat code: %s" % str(hits))
	return _pass()


static func _scan_for_stage_keys(dir_path: String, hits: Array, scanned: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan_for_stage_keys(dir_path + "/" + sub, hits, scanned)
	for fname: String in dir.get_files():
		if not fname.ends_with(".gd") or fname.begins_with("Stage"):
			continue
		scanned["files"] += 1
		var path: String = dir_path + "/" + fname
		var line_no := 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			line_no += 1
			var code: String = line.strip_edges()
			if code.begins_with("#") or code.begins_with("##"):
				continue
			for key: String in ["\"directive_profile\"", "\"lean_strength\"", "\"leans\""]:
				if code.contains(key):
					hits.append("%s:%d %s" % [path, line_no, key])
			if code.contains("\"party_stance\"") and path != "res://core/combat/CombatTurnContextService.gd":
				hits.append("%s:%d party_stance" % [path, line_no])


## Failure-path only: names every option and the terms that ranked it, so a regression
## report carries the arithmetic instead of a bare commitment number.
static func _overcommit_diagnostic(distance: int, capacity: int, directive: Dictionary) -> String:
	var fixture: Dictionary = _open_fixture(distance, capacity, {}, directive)
	var arbiter := BehaviorArbiter.new({}, _spatial_cfg())
	var cfg: Dictionary = _spatial_cfg()["spatial_utility"]
	var goal: Dictionary = (fixture["goals"] as Array)[0] as Dictionary
	var lines: Array[String] = []
	for option_value: Variant in fixture["options"] as Array:
		var option: Dictionary = option_value as Dictionary
		var parts: Dictionary = {}
		var value: float = arbiter._spatial_utility(goal, option, directive, cfg, parts)
		var terms: Dictionary = parts["parts"] as Dictionary
		lines.append("%s commitment=%d progress=%s utility=%s progress_term=%s commitment_term=%s avoid_term=%s" % [
			str(option["option_id"]), int(option["commitment"]), str(option["objective_progress"]),
			str(value), str(terms["objective_progress"]), str(terms["commitment"]),
			str(terms["directive_avoid_overcommit"]),
		])
	return " | options: %s" % " ;; ".join(lines)


static func _measure_commitment(
	distance: int, capacity: int, hostile: Dictionary, directive: Dictionary
) -> Dictionary:
	var fixture: Dictionary = _open_fixture(distance, capacity, hostile, directive)
	var generated: Dictionary = fixture["generated"] as Dictionary
	if not bool(generated.get("valid", false)):
		return {"ok": false, "error": "option generation failed: %s" % str(generated)}
	if (fixture["options"] as Array).is_empty():
		return {"ok": false, "error": "option generation produced no options"}
	var result: Dictionary = _select(fixture)
	if not bool(result["valid"]):
		return {"ok": false, "error": "selection failed: %s" % str(result)}
	var intent: Dictionary = result["intent"] as Dictionary
	return {"ok": true, "commitment": int(intent["commitment"]), "intent": intent}


## An empty corridor `distance` cells long, with the goal region on the far cell and
## no relevant actor — so nothing but geometry can influence the choice.
static func _open_fixture(
	distance: int, capacity: int, hostile: Dictionary, directive: Dictionary
) -> Dictionary:
	var actor: Dictionary = _actor()
	var others: Array = []
	if not hostile.is_empty():
		others.append(_enemy("enemy.h", hostile))
	var movement_context: Dictionary = _corridor_context(actor, others, distance + 2)
	var goal: Dictionary = GoalContract.build(
		"goal.combat.advance.baseline.c%dr0" % distance,
		"advance",
		[{"col": distance, "row": 0}],
		1.0,
		0.0,
		[],
		# A place-directed advance must name its objective, or MovementGoal rejects it.
		["mode.combat", "objective.corridor", "role.baseline"],
		ActionPlan.build("actor.move"),
		ActionPlan.build("actor.idle")
	)
	var profile: Dictionary = ProfileContract.build(capacity, [], true, "echo", {})
	var generated: Dictionary = MovementOptionService.generate_options(movement_context, profile, goal)
	var context: Dictionary = {"actor": actor, "all_actors": others.duplicate(true), "t": 1, "judgment": 0.3}
	if not directive.is_empty():
		context["directive"] = directive
	return {
		"context": context,
		"movement_context": movement_context,
		"profile": profile,
		"goals": [goal],
		"options": generated.get("options", []) as Array,
		"generated": generated,
		"movement_cfg": _spatial_cfg(),
		"actor_cfg": {},
	}


static func _corridor_context(actor: Dictionary, others: Array, width: int) -> Dictionary:
	var facts: Array = [_fact(actor)]
	var occupancy: Dictionary = {"0,0": "echo.a"}
	var relationships: Dictionary = {}
	for value: Variant in others:
		var other: Dictionary = value as Dictionary
		facts.append(_fact(other))
		occupancy[_key(other["grid_pos"])] = str(other["id"])
		relationships[str(other["id"])] = "hostile"
	facts.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str((a as Dictionary)["id"]) < str((b as Dictionary)["id"])
	)
	var walkable: Dictionary = {}
	var terrain: Dictionary = {}
	for col: int in range(width):
		for row: int in range(3):
			walkable["%d,%d" % [col, row]] = true
			terrain["%d,%d" % [col, row]] = 1
	return ContextContract.build(
		"echo.a", "activation.a", actor["grid_pos"], {"w": width, "h": 3},
		walkable, walkable, occupancy, facts, relationships, terrain, [], {}, []
	)


static func _select(fixture: Dictionary, movement_context: Dictionary = {}, options: Array = [], goals: Array = []) -> Dictionary:
	var arbiter := BehaviorArbiter.new(fixture.get("actor_cfg", {}) as Dictionary, fixture.get("movement_cfg", _spatial_cfg()) as Dictionary)
	return arbiter.select_movement_intent(
		fixture["context"], fixture["movement_context"] if movement_context.is_empty() else movement_context,
		fixture["profile"], fixture["goals"] if goals.is_empty() else goals, fixture["options"] if options.is_empty() else options
	)


static func _fixture(purpose: String = "advance", role: String = "baseline", target_id: String = "enemy.a", action_type: String = "actor.move") -> Dictionary:
	var actor: Dictionary = _actor()
	var enemy: Dictionary = _enemy("enemy.a", {"col": 3, "row": 0})
	var fixture: Dictionary = {"context": {"actor": actor, "all_actors": [enemy], "t": 1, "judgment": 0.3}, "profile": ProfileContract.build(4, [], true, "echo", {}), "movement_cfg": _spatial_cfg(), "actor_cfg": {}}
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


static func _option(goal: Dictionary, style: String, destination: Dictionary, path: Array, cost: int, progress: float, origin_distance: int = cost) -> Dictionary:
	var cells: Array[String] = []
	for value: Variant in path:
		var cell: Dictionary = value as Dictionary; cells.append("c%dr%d" % [int(cell["col"]), int(cell["row"])])
	var path_token: String = "pstay" if path.is_empty() else "p%s" % "-".join(cells)
	var id: String = "option.%s.%s.d%dr%d.%s" % [str(goal["goal_id"]).trim_prefix("goal."), style, int(destination["col"]), int(destination["row"]), path_token]
	return OptionContract.build(str(goal["goal_id"]), id, str(goal["purpose"]), destination, path, cost, cost, 0, 4, cost, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, progress, origin_distance, goal["planned_primary"], goal["declared_fallback"])


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


## urgency_progress_gain kept at 0.0 here (production: 1.0) so Test D's scout_carefully gap
## stays visible — see decisions #29/#38 in docs/stories/v2-combat-003.5/decisions.md.
static func _spatial_cfg() -> Dictionary:
	return {"spatial_utility": {"cap": 20.0, "urgency_weight": 4.0, "urgency_progress_gain": 0.0, "objective_progress_weight": 8.0, "cohesion_weight": 4.0, "exposure_weight": -6.0, "congestion_weight": -2.0, "commitment_weight": -2.0, "directive_objective_advance_weight": 4.0, "directive_avoid_overcommit_weight": 2.0, "directive_exposure_acceptance_weight": 2.0, "directive_ally_protection_weight": 2.0, "directive_threat_interception_weight": 2.0}}


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
