# res://tests/MovementContractTests.gd
# V2-COMBAT-002 slice 1: shared movement contract validation and copy isolation.

class_name MovementContractTests
extends RefCounted

const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const OptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/contracts/context_valid_copy", Callable(MovementContractTests, "_t_context_valid_copy"))
	runner.register_test("movement/contracts/profile_zero_and_authored_one", Callable(MovementContractTests, "_t_profile_zero_and_authored_one"))
	runner.register_test("movement/contracts/goal_valid_copy", Callable(MovementContractTests, "_t_goal_valid_copy"))
	runner.register_test("movement/contracts/option_valid_copy", Callable(MovementContractTests, "_t_option_valid_copy"))
	runner.register_test("movement/contracts/intent_valid_copy", Callable(MovementContractTests, "_t_intent_valid_copy"))
	runner.register_test("movement/contracts/event_valid_copy", Callable(MovementContractTests, "_t_event_valid_copy"))
	runner.register_test("movement/contracts/result_valid_copy", Callable(MovementContractTests, "_t_result_valid_copy"))
	runner.register_test("movement/contracts/missing_fields_reasoned", Callable(MovementContractTests, "_t_missing_fields_reasoned"))
	runner.register_test("movement/contracts/wrong_types_reasoned", Callable(MovementContractTests, "_t_wrong_types_reasoned"))
	runner.register_test("movement/contracts/unexpected_field_rejected", Callable(MovementContractTests, "_t_unexpected_field_rejected"))
	runner.register_test("movement/contracts/option_path_excludes_start", Callable(MovementContractTests, "_t_option_path_excludes_start"))
	runner.register_test("movement/contracts/result_paths_exclude_start", Callable(MovementContractTests, "_t_result_paths_exclude_start"))
	runner.register_test("movement/contracts/event_seq_strict", Callable(MovementContractTests, "_t_event_seq_strict"))
	runner.register_test("movement/contracts/stop_reason_vocabulary", Callable(MovementContractTests, "_t_stop_reason_vocabulary"))
	runner.register_test("movement/contracts/final_destination_matches_actual", Callable(MovementContractTests, "_t_final_destination_matches_actual"))
	runner.register_test("movement/contracts/option_destination_and_commitment", Callable(MovementContractTests, "_t_option_destination_and_commitment"))
	runner.register_test("movement/contracts/bounds_exact_positive", Callable(MovementContractTests, "_t_bounds_exact_positive"))
	runner.register_test("movement/contracts/origin_required_and_empty_path", Callable(MovementContractTests, "_t_origin_required_and_empty_path"))
	runner.register_test("movement/contracts/capacity_bands_and_cap", Callable(MovementContractTests, "_t_capacity_bands_and_cap"))
	runner.register_test("movement/contracts/authored_override_exact_consistent", Callable(MovementContractTests, "_t_authored_override_exact_consistent"))
	runner.register_test("movement/contracts/slack_exact_and_bounded", Callable(MovementContractTests, "_t_slack_exact_and_bounded"))
	runner.register_test("movement/contracts/source_arrays_canonical", Callable(MovementContractTests, "_t_source_arrays_canonical"))
	runner.register_test("movement/contracts/result_event_projection", Callable(MovementContractTests, "_t_result_event_projection"))
	runner.register_test("movement/contracts/result_rejects_contradictory_history", Callable(MovementContractTests, "_t_result_rejects_contradictory_history"))
	runner.register_test("movement/contracts/voluntary_event_cost_positive", Callable(MovementContractTests, "_t_voluntary_event_cost_positive"))
	runner.register_test("movement/contracts/positions_exact_no_origin_bypass", Callable(MovementContractTests, "_t_positions_exact_no_origin_bypass"))
	runner.register_test("movement/contracts/movement_event_edges_adjacent", Callable(MovementContractTests, "_t_movement_event_edges_adjacent"))
	runner.register_test("movement/contracts/result_stop_facts_terminal", Callable(MovementContractTests, "_t_result_stop_facts_terminal"))
	runner.register_test("movement/contracts/required_fields_exact_tables", Callable(MovementContractTests, "_t_required_fields_exact_tables"))
	runner.register_test("movement/contracts/all_mutable_inputs_deep_copied", Callable(MovementContractTests, "_t_all_mutable_inputs_deep_copied"))
	runner.register_test("movement/contracts/result_remaining_capacity_capped", Callable(MovementContractTests, "_t_result_remaining_capacity_capped"))
	runner.register_test("movement/contracts/result_nonempty_events_require_stop", Callable(MovementContractTests, "_t_result_nonempty_events_require_stop"))
	runner.register_test("movement/contracts/result_hazards_exact_projection", Callable(MovementContractTests, "_t_result_hazards_exact_projection"))


static func _t_context_valid_copy() -> Dictionary:
	var origin := {"col": 1, "row": 2}
	var actors: Array = [{
		"id": "enemy.1", "position": {"col": 4, "row": 2}, "kind": "enemy",
		"is_dead": false, "is_ko": false, "is_structure": false,
		"is_spirit": false, "is_quarry": false, "controlling_state": false,
		"health_ratio": 1.0,
	}]
	var context: Dictionary = ContextContract.build(
		"echo.1", "activation.1", origin, {"w": 10, "h": 10},
		{"1,2": true, "2,2": true}, {"1,2": true, "2,2": true}, {}, actors,
		{}, {"2,2": 1}, [], {"mode": "recover"}, []
	)
	var valid_result: Dictionary = ContextContract.validate(context)
	if not bool(valid_result["valid"]):
		return _fail("valid context rejected: %s" % str(valid_result))
	origin["col"] = 9
	(actors[0] as Dictionary)["id"] = "mutated"
	if int((context["origin"] as Dictionary)["col"]) != 1:
		return _fail("context retained origin input alias")
	if str(((context["perceived_actors"] as Array)[0] as Dictionary).get("id", "")) != "enemy.1":
		return _fail("context retained perceived actor input alias")
	return _pass()


static func _t_profile_zero_and_authored_one() -> Dictionary:
	var structure: Dictionary = ProfileContract.build(0, [{"source": "structure"}], false, "structure", {})
	var structure_result: Dictionary = ProfileContract.validate(structure)
	if not bool(structure_result["valid"]):
		return _fail("zero-capacity structure rejected: %s" % str(structure_result))
	var guide: Dictionary = ProfileContract.build(
		1,
		[{"source": "guide_objective_phase", "amount": 1}],
		false,
		"npc",
		{"source": "guide_nonjoining", "capacity": 1}
	)
	var guide_result: Dictionary = ProfileContract.validate(guide)
	if not bool(guide_result["valid"]):
		return _fail("authored one-cell GUIDE profile rejected: %s" % str(guide_result))
	structure["capacity"] = 1
	var invalid_structure: Dictionary = ProfileContract.validate(structure)
	if bool(invalid_structure["valid"]) or str(invalid_structure["reason"]) != "structure_capacity_nonzero":
		return _fail("nonzero structure capacity was not rejected deterministically")
	return _pass()


static func _t_goal_valid_copy() -> Dictionary:
	var region: Array = [{"col": 4, "row": 3}, {"col": 4, "row": 4}]
	var action := {"type": "actor.guard", "target_id": "", "payload": {}}
	var goal: Dictionary = GoalContract.build(
		"goal.recover.hold.holder.c4r3", "hold", region, 0.8, 1.0,
		["echo.1", "enemy.1"], ["objective.relic"], action,
		{"type": "actor.idle", "target_id": "", "payload": {}}
	)
	var result: Dictionary = GoalContract.validate(goal, {"col": 1, "row": 1})
	if not bool(result["valid"]):
		return _fail("valid goal rejected: %s" % str(result))
	(region[0] as Dictionary)["col"] = 0
	action["type"] = "mutated"
	if int((goal["destination_region"] as Array)[0].get("col", -1)) != 4:
		return _fail("goal retained destination region input alias")
	if str((goal["planned_primary"] as Dictionary).get("type", "")) != "actor.guard":
		return _fail("goal retained primary action input alias")
	return _pass()


static func _t_option_valid_copy() -> Dictionary:
	var path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var option: Dictionary = _valid_option(path)
	var result: Dictionary = OptionContract.validate(option, {"col": 1, "row": 1})
	if not bool(result["valid"]):
		return _fail("valid option rejected: %s" % str(result))
	(path[0] as Dictionary)["col"] = 8
	if int((option["path"] as Array)[0].get("col", -1)) != 2:
		return _fail("option retained path input alias")
	return _pass()


static func _t_intent_valid_copy() -> Dictionary:
	var path: Array = [{"col": 2, "row": 1}]
	var action := {"type": "actor.guard", "target_id": "", "payload": {}}
	var intent: Dictionary = IntentContract.build(
		"echo.1", "activation.1", "goal.hold", "option.hold.1", path,
		3, 1, action, {"type": "actor.idle", "target_id": "", "payload": {}},
		["objective.relic"]
	)
	var result: Dictionary = IntentContract.validate(intent, {"col": 1, "row": 1})
	if not bool(result["valid"]):
		return _fail("valid intent rejected: %s" % str(result))
	(path[0] as Dictionary)["col"] = 8
	action["type"] = "mutated"
	if int((intent["path"] as Array)[0].get("col", -1)) != 2:
		return _fail("intent retained path input alias")
	if str((intent["planned_action"] as Dictionary).get("type", "")) != "actor.guard":
		return _fail("intent retained action input alias")
	return _pass()


static func _t_event_valid_copy() -> Dictionary:
	var hazard := {"id": "burning.1", "type": "burning"}
	var event: Dictionary = EventContract.build(
		1, "entry", "hazard_triggered", "burning.1", {"col": 1, "row": 1},
		{"col": 2, "row": 1}, "voluntary", 1, hazard, 2, ""
	)
	var result: Dictionary = EventContract.validate(event)
	if not bool(result["valid"]):
		return _fail("valid event rejected: %s" % str(result))
	hazard["id"] = "mutated"
	if str((event["hazard"] as Dictionary).get("id", "")) != "burning.1":
		return _fail("event retained hazard input alias")
	return _pass()


static func _t_result_valid_copy() -> Dictionary:
	var actual: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var events: Array = [_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}), _event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination")]
	var movement_result: Dictionary = _valid_result(actual, events)
	var result: Dictionary = ResultContract.validate(movement_result)
	if not bool(result["valid"]):
		return _fail("valid movement result rejected: %s" % str(result))
	(actual[0] as Dictionary)["col"] = 8
	(events[0] as Dictionary)["seq"] = 99
	if int((movement_result["actual_traversed_cells"] as Array)[0].get("col", -1)) != 2:
		return _fail("result retained traversal input alias")
	if int((movement_result["events"] as Array)[0].get("seq", -1)) != 1:
		return _fail("result retained event input alias")
	return _pass()


static func _t_missing_fields_reasoned() -> Dictionary:
	var cases: Array = [
		[_valid_context(), Callable(ContextContract, "validate"), "activation_id"],
		[ProfileContract.build(2, [], true, "echo", {}), Callable(ProfileContract, "validate"), "capacity"],
		[_valid_goal(), Callable(GoalContract, "validate"), "purpose", {"col": 1, "row": 1}],
		[_valid_option(), Callable(OptionContract, "validate"), "option_id", {"col": 1, "row": 1}],
		[_valid_intent(), Callable(IntentContract, "validate"), "mover_id", {"col": 1, "row": 1}],
		[_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}), Callable(EventContract, "validate"), "seq"],
		[_valid_result(), Callable(ResultContract, "validate"), "stop_reason"],
	]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var value: Dictionary = (case[0] as Dictionary).duplicate(true)
		var validator: Callable = case[1] as Callable
		var field: String = str(case[2])
		value.erase(field)
		var result: Dictionary
		if case.size() > 3:
			result = validator.call(value, case[3] as Dictionary)
		else:
			result = validator.call(value)
		if bool(result["valid"]) or str(result["reason"]) != "missing_field" or str(result["field"]) != field:
			return _fail("missing %s did not return stable diagnostic: %s" % [field, str(result)])
	return _pass()


static func _t_wrong_types_reasoned() -> Dictionary:
	var context: Dictionary = _valid_context()
	context["occupancy"] = []
	var context_result: Dictionary = ContextContract.validate(context)
	if not _matches_failure(context_result, "wrong_type", "occupancy"):
		return _fail("context wrong type diagnostic mismatch: %s" % str(context_result))
	var option: Dictionary = _valid_option()
	option["path"] = ["2,1"]
	var option_result: Dictionary = OptionContract.validate(option, {"col": 1, "row": 1})
	if not _matches_failure(option_result, "wrong_item_type", "path"):
		return _fail("option wrong type diagnostic mismatch: %s" % str(option_result))
	var event: Dictionary = _event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1})
	event["damage"] = 1.5
	var event_result: Dictionary = EventContract.validate(event)
	if not _matches_failure(event_result, "wrong_type", "damage"):
		return _fail("event wrong type diagnostic mismatch: %s" % str(event_result))
	return _pass()


static func _t_unexpected_field_rejected() -> Dictionary:
	var goal: Dictionary = _valid_goal()
	goal["free_form_note"] = "not contract data"
	var result: Dictionary = GoalContract.validate(goal, {"col": 1, "row": 1})
	if not _matches_failure(result, "unexpected_field", "free_form_note"):
		return _fail("unexpected field was not rejected deterministically: %s" % str(result))
	return _pass()


static func _t_option_path_excludes_start() -> Dictionary:
	var origin := {"col": 1, "row": 1}
	var option: Dictionary = _valid_option([origin.duplicate(true), {"col": 3, "row": 1}])
	var result: Dictionary = OptionContract.validate(option, origin)
	if not _matches_failure(result, "path_includes_origin", "path"):
		return _fail("option accepted path containing start: %s" % str(result))
	return _pass()


static func _t_result_paths_exclude_start() -> Dictionary:
	var planned_invalid: Dictionary = _valid_result()
	(planned_invalid["planned_path"] as Array).push_front({"col": 1, "row": 1})
	var planned_result: Dictionary = ResultContract.validate(planned_invalid)
	if not _matches_failure(planned_result, "path_includes_origin", "planned_path"):
		return _fail("result accepted planned path containing start: %s" % str(planned_result))
	var actual_invalid: Dictionary = _valid_result()
	(actual_invalid["actual_traversed_cells"] as Array).push_front({"col": 1, "row": 1})
	var actual_result: Dictionary = ResultContract.validate(actual_invalid)
	if not _matches_failure(actual_result, "path_includes_origin", "actual_traversed_cells"):
		return _fail("result accepted actual traversal containing start: %s" % str(actual_result))
	return _pass()


static func _t_event_seq_strict() -> Dictionary:
	var duplicate_seq: Dictionary = _valid_result([], [
		_event(2, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination"),
	])
	var result: Dictionary = ResultContract.validate(duplicate_seq)
	if not _matches_failure(result, "event_seq_not_strictly_increasing", "events"):
		return _fail("duplicate event seq accepted: %s" % str(result))
	var descending: Dictionary = _valid_result([], [
		_event(3, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination"),
	])
	var descending_result: Dictionary = ResultContract.validate(descending)
	if not _matches_failure(descending_result, "event_seq_not_strictly_increasing", "events"):
		return _fail("descending event seq accepted: %s" % str(descending_result))
	return _pass()


static func _t_stop_reason_vocabulary() -> Dictionary:
	for reason_value: Variant in ResultContract.STOP_REASONS:
		var movement_result: Dictionary = _valid_result()
		movement_result["stop_reason"] = str(reason_value)
		((movement_result["events"] as Array).back() as Dictionary)["stop_reason"] = str(reason_value)
		var result: Dictionary = ResultContract.validate(movement_result)
		if not bool(result["valid"]):
			return _fail("frozen stop reason rejected (%s): %s" % [str(reason_value), str(result)])
	var invalid: Dictionary = _valid_result()
	invalid["stop_reason"] = "close_enough"
	var invalid_result: Dictionary = ResultContract.validate(invalid)
	if not _matches_failure(invalid_result, "invalid_stop_reason", "stop_reason"):
		return _fail("unknown stop reason accepted: %s" % str(invalid_result))
	return _pass()


static func _t_final_destination_matches_actual() -> Dictionary:
	var movement_result: Dictionary = _valid_result()
	movement_result["final_destination"] = {"col": 9, "row": 9}
	var result: Dictionary = ResultContract.validate(movement_result)
	if not _matches_failure(result, "final_destination_mismatch", "final_destination"):
		return _fail("mismatched final destination accepted: %s" % str(result))
	return _pass()


static func _t_option_destination_and_commitment() -> Dictionary:
	var destination_mismatch: Dictionary = _valid_option()
	destination_mismatch["destination"] = {"col": 4, "row": 1}
	var destination_result: Dictionary = OptionContract.validate(destination_mismatch, {"col": 1, "row": 1})
	if not _matches_failure(destination_result, "path_destination_mismatch", "path"):
		return _fail("option endpoint mismatch accepted: %s" % str(destination_result))
	var commitment_mismatch: Dictionary = _valid_option()
	commitment_mismatch["commitment"] = 3
	var commitment_result: Dictionary = OptionContract.validate(commitment_mismatch, {"col": 1, "row": 1})
	if not _matches_failure(commitment_result, "commitment_must_equal_route_cost", "commitment"):
		return _fail("option commitment mismatch accepted: %s" % str(commitment_result))
	var zero_route_cost: Dictionary = _valid_option()
	zero_route_cost["route_cost"] = 0
	var zero_route_result: Dictionary = OptionContract.validate(zero_route_cost, {"col": 1, "row": 1})
	if not _matches_failure(
		zero_route_result,
		"nonempty_path_requires_positive_route_cost",
		"route_cost"
	):
		return _fail("moving option accepted zero route cost: %s" % str(zero_route_result))
	var zero_shortest_cost: Dictionary = _valid_option()
	zero_shortest_cost["shortest_cost"] = 0
	var zero_shortest_result: Dictionary = OptionContract.validate(
		zero_shortest_cost,
		{"col": 1, "row": 1}
	)
	if not _matches_failure(
		zero_shortest_result,
		"nonempty_path_requires_positive_shortest_cost",
		"shortest_cost"
	):
		return _fail("moving option accepted zero shortest cost: %s" % str(zero_shortest_result))
	var zero_commitment: Dictionary = _valid_option()
	zero_commitment["commitment"] = 0
	var zero_commitment_result: Dictionary = OptionContract.validate(
		zero_commitment,
		{"col": 1, "row": 1}
	)
	if not _matches_failure(
		zero_commitment_result,
		"nonempty_path_requires_positive_commitment",
		"commitment"
	):
		return _fail("moving option accepted zero commitment: %s" % str(zero_commitment_result))
	return _pass()


static func _t_bounds_exact_positive() -> Dictionary:
	var unexpected: Dictionary = _valid_context()
	unexpected["bounds"] = {"w": 10, "h": 10, "cols": 10}
	var unexpected_result: Dictionary = ContextContract.validate(unexpected)
	if not _matches_failure(unexpected_result, "invalid_bounds.unexpected_field", "bounds.cols"):
		return _fail("bounds accepted an undocumented field: %s" % str(unexpected_result))
	var missing: Dictionary = _valid_context()
	missing["bounds"] = {"w": 10}
	var missing_result: Dictionary = ContextContract.validate(missing)
	if not _matches_failure(missing_result, "invalid_bounds.missing_field", "bounds.h"):
		return _fail("bounds accepted a missing dimension: %s" % str(missing_result))
	var zero: Dictionary = _valid_context()
	zero["bounds"] = {"w": 0, "h": 10}
	var zero_result: Dictionary = ContextContract.validate(zero)
	if not _matches_failure(zero_result, "non_positive_bounds", "bounds.w"):
		return _fail("bounds accepted a non-positive dimension: %s" % str(zero_result))
	return _pass()


static func _t_origin_required_and_empty_path() -> Dictionary:
	var option_origin_result: Dictionary = OptionContract.validate(_valid_option(), {})
	if not _matches_failure(option_origin_result, "invalid_position", "origin"):
		return _fail("option validation allowed missing origin context: %s" % str(option_origin_result))
	var intent_origin_result: Dictionary = IntentContract.validate(_valid_intent(), {})
	if not _matches_failure(intent_origin_result, "invalid_position", "origin"):
		return _fail("intent validation allowed missing origin context: %s" % str(intent_origin_result))
	var intent_with_origin: Dictionary = _valid_intent()
	(intent_with_origin["path"] as Array).append({"col": 1, "row": 1})
	var intent_path_result: Dictionary = IntentContract.validate(intent_with_origin, {"col": 1, "row": 1})
	if not _matches_failure(intent_path_result, "path_includes_origin", "path"):
		return _fail("intent accepted origin inside path: %s" % str(intent_path_result))
	var stationary: Dictionary = OptionContract.build(
		"goal.combat.hold.baseline.c1r1",
		"option.combat.hold.baseline.c1r1.direct.d1r1.pstay",
		"hold", {"col": 1, "row": 1}, [],
		0, 0, 0, 2, 0, 0.0, 0.0, 1.0, [], {"known_count": 0, "known_ids": []}, 0.0,
		{"type": "actor.guard", "target_id": "", "payload": {}}, {}
	)
	var stationary_result: Dictionary = OptionContract.validate(stationary, {"col": 1, "row": 1})
	if not bool(stationary_result["valid"]):
		return _fail("stationary option at origin rejected: %s" % str(stationary_result))
	var stationary_cost_cases: Array = [
		["route_cost", "empty_path_requires_zero_route_cost"],
		["shortest_cost", "empty_path_requires_zero_shortest_cost"],
		["slack", "empty_path_requires_zero_slack"],
		["commitment", "empty_path_requires_zero_commitment"],
	]
	for case_value: Variant in stationary_cost_cases:
		var case: Array = case_value as Array
		var field: String = str(case[0])
		var costly_stationary: Dictionary = stationary.duplicate(true)
		costly_stationary[field] = 1
		var costly_stationary_result: Dictionary = OptionContract.validate(
			costly_stationary,
			{"col": 1, "row": 1}
		)
		if not _matches_failure(costly_stationary_result, str(case[1]), field):
			return _fail(
				"stationary option accepted positive %s: %s"
				% [field, str(costly_stationary_result)]
			)
	var stationary_intent: Dictionary = IntentContract.build(
		"echo.1", "activation.1", "goal.hold", "option.hold", [], 2, 0,
		{"type": "actor.idle", "target_id": "", "payload": {}}, {}, []
	)
	var stationary_intent_result: Dictionary = IntentContract.validate(
		stationary_intent,
		{"col": 1, "row": 1}
	)
	if not bool(stationary_intent_result["valid"]):
		return _fail("stationary intent with zero commitment rejected: %s" % str(stationary_intent_result))
	stationary_intent["commitment"] = 1
	var costly_stationary_intent_result: Dictionary = IntentContract.validate(
		stationary_intent,
		{"col": 1, "row": 1}
	)
	if not _matches_failure(
		costly_stationary_intent_result,
		"empty_path_requires_zero_commitment",
		"commitment"
	):
		return _fail(
			"stationary intent accepted positive commitment: %s"
			% str(costly_stationary_intent_result)
		)
	var moving_zero_commitment: Dictionary = _valid_intent()
	moving_zero_commitment["commitment"] = 0
	var moving_zero_result: Dictionary = IntentContract.validate(
		moving_zero_commitment,
		{"col": 1, "row": 1}
	)
	if not _matches_failure(
		moving_zero_result,
		"nonempty_path_requires_positive_commitment",
		"commitment"
	):
		return _fail("moving intent accepted zero commitment: %s" % str(moving_zero_result))
	stationary["destination"] = {"col": 2, "row": 1}
	var mismatch_result: Dictionary = OptionContract.validate(stationary, {"col": 1, "row": 1})
	if not _matches_failure(mismatch_result, "empty_path_destination_must_equal_origin", "destination"):
		return _fail("empty path accepted a non-origin destination: %s" % str(mismatch_result))
	return _pass()


static func _t_capacity_bands_and_cap() -> Dictionary:
	for capacity: int in range(2, 7):
		var ordinary: Dictionary = ProfileContract.build(capacity, [], true, "echo", {})
		var ordinary_result: Dictionary = ProfileContract.validate(ordinary)
		if not bool(ordinary_result["valid"]):
			return _fail("ordinary capacity %d rejected: %s" % [capacity, str(ordinary_result)])
	var zero_echo: Dictionary = ProfileContract.build(0, [], false, "echo", {})
	var zero_echo_result: Dictionary = ProfileContract.validate(zero_echo)
	if not _matches_failure(zero_echo_result, "zero_capacity_requires_structure", "capacity"):
		return _fail("zero capacity accepted for a non-structure: %s" % str(zero_echo_result))
	var unauthored_one: Dictionary = ProfileContract.build(1, [], false, "npc", {})
	var unauthored_one_result: Dictionary = ProfileContract.validate(unauthored_one)
	if not _matches_failure(unauthored_one_result, "one_capacity_requires_authored_override", "authored_override"):
		return _fail("unauthored one-cell profile accepted: %s" % str(unauthored_one_result))
	var profile_over_cap: Dictionary = ProfileContract.build(7, [], true, "echo", {})
	var profile_cap_result: Dictionary = ProfileContract.validate(profile_over_cap)
	if not _matches_failure(profile_cap_result, "capacity_exceeds_system_cap", "capacity"):
		return _fail("profile capacity above six accepted: %s" % str(profile_cap_result))
	var option_over_cap: Dictionary = _valid_option()
	option_over_cap["capacity"] = 7
	var option_cap_result: Dictionary = OptionContract.validate(option_over_cap, {"col": 1, "row": 1})
	if not _matches_failure(option_cap_result, "capacity_exceeds_system_cap", "capacity"):
		return _fail("option capacity above six accepted: %s" % str(option_cap_result))
	var intent_over_cap: Dictionary = _valid_intent()
	intent_over_cap["capacity"] = 7
	var intent_cap_result: Dictionary = IntentContract.validate(intent_over_cap, {"col": 1, "row": 1})
	if not _matches_failure(intent_cap_result, "capacity_exceeds_system_cap", "capacity"):
		return _fail("intent capacity above six accepted: %s" % str(intent_cap_result))
	var structure_option: Dictionary = OptionContract.build(
		"goal.combat.hold.baseline.c1r1",
		"option.combat.hold.baseline.c1r1.direct.d1r1.pstay",
		"hold", {"col": 1, "row": 1}, [],
		0, 0, 0, 0, 0, 0.0, 0.0, 1.0, [], {"known_count": 0, "known_ids": []}, 0.0,
		{"type": "actor.guard", "target_id": "", "payload": {}}, {}
	)
	var structure_option_result: Dictionary = OptionContract.validate(structure_option, {"col": 1, "row": 1})
	if not bool(structure_option_result["valid"]):
		return _fail("zero-capacity option rejected: %s" % str(structure_option_result))
	var guide_option: Dictionary = OptionContract.build(
		"goal.guide_spirit.advance.spirit.c2r1",
		"option.guide_spirit.advance.spirit.c2r1.direct.d2r1.pc2r1",
		"advance", {"col": 2, "row": 1}, [{"col": 2, "row": 1}],
		1, 1, 0, 1, 1, 0.0, 0.0, 1.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		{"type": "actor.move", "target_id": "objective.guide", "payload": {}}, {}
	)
	var guide_option_result: Dictionary = OptionContract.validate(guide_option, {"col": 1, "row": 1})
	if not bool(guide_option_result["valid"]):
		return _fail("one-capacity option rejected: %s" % str(guide_option_result))
	var structure_intent: Dictionary = IntentContract.build(
		"structure.1", "activation.1", "goal.structure", "option.structure", [], 0, 0,
		{"type": "actor.idle", "target_id": "", "payload": {}}, {}, []
	)
	var structure_intent_result: Dictionary = IntentContract.validate(structure_intent, {"col": 1, "row": 1})
	if not bool(structure_intent_result["valid"]):
		return _fail("zero-capacity intent rejected: %s" % str(structure_intent_result))
	var guide_intent: Dictionary = IntentContract.build(
		"guide.1", "activation.1", "goal.guide", "option.guide", [{"col": 2, "row": 1}], 1, 1,
		{"type": "actor.move", "target_id": "objective.guide", "payload": {}}, {}, []
	)
	var guide_intent_result: Dictionary = IntentContract.validate(guide_intent, {"col": 1, "row": 1})
	if not bool(guide_intent_result["valid"]):
		return _fail("one-capacity intent rejected: %s" % str(guide_intent_result))
	return _pass()


static func _t_authored_override_exact_consistent() -> Dictionary:
	var extra: Dictionary = ProfileContract.build(
		1, [], false, "npc", {"source": "guide_nonjoining", "capacity": 1, "note": "extra"}
	)
	var extra_result: Dictionary = ProfileContract.validate(extra)
	if not _matches_failure(extra_result, "invalid_authored_override.unexpected_field", "authored_override.note"):
		return _fail("authored override accepted an extra field: %s" % str(extra_result))
	var empty_source: Dictionary = ProfileContract.build(1, [], false, "npc", {"source": "", "capacity": 1})
	var source_result: Dictionary = ProfileContract.validate(empty_source)
	if not _matches_failure(source_result, "empty_string", "authored_override.source"):
		return _fail("authored override accepted an empty source: %s" % str(source_result))
	var mismatch: Dictionary = ProfileContract.build(
		2, [], false, "npc", {"source": "guide_nonjoining", "capacity": 1}
	)
	var mismatch_result: Dictionary = ProfileContract.validate(mismatch)
	if not _matches_failure(mismatch_result, "authored_override_capacity_mismatch", "authored_override.capacity"):
		return _fail("authored override accepted mismatched capacity: %s" % str(mismatch_result))
	var override_over_cap: Dictionary = ProfileContract.build(
		6, [], false, "npc", {"source": "signature", "capacity": 7}
	)
	var override_cap_result: Dictionary = ProfileContract.validate(override_over_cap)
	if not _matches_failure(override_cap_result, "capacity_exceeds_system_cap", "authored_override.capacity"):
		return _fail("authored override capacity above six accepted: %s" % str(override_cap_result))
	return _pass()


static func _t_slack_exact_and_bounded() -> Dictionary:
	var detour: Dictionary = _valid_option()
	detour["route_cost"] = 3
	detour["commitment"] = 3
	detour["slack"] = 1
	var detour_result: Dictionary = OptionContract.validate(detour, {"col": 1, "row": 1})
	if not bool(detour_result["valid"]):
		return _fail("bounded route slack rejected: %s" % str(detour_result))
	detour["slack"] = 0
	var mismatch_result: Dictionary = OptionContract.validate(detour, {"col": 1, "row": 1})
	if not _matches_failure(mismatch_result, "slack_mismatch", "slack"):
		return _fail("incorrect actual slack accepted: %s" % str(mismatch_result))
	var upper_bound: Dictionary = _valid_option()
	upper_bound["shortest_cost"] = 3
	upper_bound["route_cost"] = 5
	upper_bound["slack"] = 2
	upper_bound["capacity"] = 5
	upper_bound["commitment"] = 5
	var upper_bound_result: Dictionary = OptionContract.validate(upper_bound, {"col": 1, "row": 1})
	if not bool(upper_bound_result["valid"]):
		return _fail("exact normal slack upper bound rejected: %s" % str(upper_bound_result))
	var excessive: Dictionary = _valid_option()
	excessive["shortest_cost"] = 3
	excessive["route_cost"] = 6
	excessive["slack"] = 3
	excessive["capacity"] = 6
	excessive["commitment"] = 6
	var excessive_result: Dictionary = OptionContract.validate(excessive, {"col": 1, "row": 1})
	if not _matches_failure(excessive_result, "route_exceeds_normal_slack_envelope", "route_cost"):
		return _fail("route outside the normal slack envelope accepted: %s" % str(excessive_result))
	return _pass()


static func _t_source_arrays_canonical() -> Dictionary:
	var goal: Dictionary = GoalContract.build(
		"goal.combat.advance.baseline.c2r1", "advance", [{"col": 2, "row": 1}], 1.0, 0.0,
		["objective.test"],
		["pressure.z", "pressure.a", "pressure.z"],
		{"type": "actor.move", "target_id": "objective.test", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}
	)
	if goal["pressure_sources"] != ["pressure.a", "pressure.z"]:
		return _fail("goal builder did not sort and dedupe pressure sources")
	var intent: Dictionary = IntentContract.build(
		"echo.1", "activation.1", "goal.test", "option.test", [], 2, 0,
		{"type": "actor.idle", "target_id": "", "payload": {}}, {},
		["pressure.z", "pressure.a", "pressure.z"]
	)
	if intent["pressure_sources"] != ["pressure.a", "pressure.z"]:
		return _fail("intent builder did not sort and dedupe pressure sources")
	var option: Dictionary = _valid_option()
	option = OptionContract.build(
		str(option["goal_id"]), str(option["option_id"]), str(option["purpose"]),
		option["destination"] as Dictionary, option["path"] as Array, 2, 2, 0, 3, 2,
		0.2, 0.0, 1.0, ["enemy.z", "enemy.a", "enemy.z"],
		{"known_count": 0, "known_ids": []}, 1.0,
		{"type": "actor.guard", "target_id": "", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}
	)
	if option["hostile_control_sources"] != ["enemy.a", "enemy.z"]:
		return _fail("option builder did not sort and dedupe hostile sources")
	goal["pressure_sources"] = ["pressure.z", "pressure.a"]
	var goal_result: Dictionary = GoalContract.validate(goal, {"col": 1, "row": 1})
	if not _matches_failure(goal_result, "not_strictly_sorted_unique", "pressure_sources"):
		return _fail("goal validator accepted unsorted pressure sources: %s" % str(goal_result))
	intent["pressure_sources"] = ["pressure.a", "pressure.a"]
	var intent_result: Dictionary = IntentContract.validate(intent, {"col": 1, "row": 1})
	if not _matches_failure(intent_result, "not_strictly_sorted_unique", "pressure_sources"):
		return _fail("intent validator accepted duplicate pressure sources: %s" % str(intent_result))
	option["hostile_control_sources"] = ["enemy.z", "enemy.a"]
	var option_result: Dictionary = OptionContract.validate(option, {"col": 1, "row": 1})
	if not _matches_failure(option_result, "not_strictly_sorted_unique", "hostile_control_sources"):
		return _fail("option validator accepted unsorted hostile sources: %s" % str(option_result))
	return _pass()


static func _t_result_event_projection() -> Dictionary:
	var events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 9, "row": 9}, {"col": 8, "row": 8}, "", "none", 0),
		_event(3, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "", "forced", 0),
		_event(4, {"col": 3, "row": 1}, {"col": 4, "row": 1}, "reached_destination", "voluntary", 2),
	]
	var actual: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}, {"col": 4, "row": 1}]
	var movement_result: Dictionary = _result_for_history(actual, events, 3, 1, {"col": 4, "row": 1})
	var result: Dictionary = ResultContract.validate(movement_result)
	if not bool(result["valid"]):
		return _fail("truthful mixed movement history rejected: %s" % str(result))
	for field: String in ["mover_id", "activation_id", "goal_id", "option_id", "purpose"]:
		if not movement_result.has(field) or str(movement_result[field]).is_empty():
			return _fail("movement result missing stable correlation field %s" % field)
	return _pass()


static func _t_result_rejects_contradictory_history() -> Dictionary:
	var base_events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination", "forced", 0),
	]
	var traversal_mismatch: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}], base_events, 1, 1, {"col": 3, "row": 1}
	)
	var traversal_result: Dictionary = ResultContract.validate(traversal_mismatch)
	if not _matches_failure(traversal_result, "actual_traversal_event_mismatch", "actual_traversed_cells"):
		return _fail("contradictory actual traversal accepted: %s" % str(traversal_result))
	var broken_events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 7, "row": 7}, {"col": 7, "row": 8}),
	]
	var broken: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], broken_events, 2, 0, {"col": 3, "row": 1}
	)
	var broken_result: Dictionary = ResultContract.validate(broken)
	if not _matches_failure(broken_result, "event_movement_not_contiguous", "events"):
		return _fail("non-contiguous event history accepted: %s" % str(broken_result))
	var cost_mismatch: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], base_events, 2, 1, {"col": 3, "row": 1}
	)
	var cost_result: Dictionary = ResultContract.validate(cost_mismatch)
	if not _matches_failure(cost_result, "voluntary_cost_event_mismatch", "voluntary_cost"):
		return _fail("contradictory voluntary cost accepted: %s" % str(cost_result))
	var forced_mismatch: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], base_events, 1, 0, {"col": 3, "row": 1}
	)
	var forced_result: Dictionary = ResultContract.validate(forced_mismatch)
	if not _matches_failure(forced_result, "forced_steps_event_mismatch", "forced_steps"):
		return _fail("contradictory forced-step count accepted: %s" % str(forced_result))
	var costly_forced: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}, "", "forced", 1),
	]
	var costly_result_value: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}], costly_forced, 0, 1, {"col": 2, "row": 1}
	)
	var costly_result: Dictionary = ResultContract.validate(costly_result_value)
	if not _matches_failure(costly_result, "invalid_event.forced_movement_has_cost", "events.cost"):
		return _fail("forced movement consumed voluntary cost: %s" % str(costly_result))
	return _pass()


static func _t_voluntary_event_cost_positive() -> Dictionary:
	var zero_cost_event: Dictionary = _event(
		1, {"col": 1, "row": 1}, {"col": 2, "row": 1}, "", "voluntary", 0
	)
	var event_result: Dictionary = EventContract.validate(zero_cost_event)
	if not _matches_failure(event_result, "voluntary_movement_requires_positive_cost", "cost"):
		return _fail("zero-cost voluntary event accepted: %s" % str(event_result))
	var history: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}], [zero_cost_event], 0, 0, {"col": 2, "row": 1}
	)
	var history_result: Dictionary = ResultContract.validate(history)
	if not _matches_failure(
		history_result,
		"invalid_event.voluntary_movement_requires_positive_cost",
		"events.cost"
	):
		return _fail("zero-cost voluntary history accepted: %s" % str(history_result))
	var costly_forced: Dictionary = _event(
		1, {"col": 1, "row": 1}, {"col": 2, "row": 1}, "", "forced", 1
	)
	var forced_result: Dictionary = EventContract.validate(costly_forced)
	if not _matches_failure(forced_result, "forced_movement_has_cost", "cost"):
		return _fail("positive-cost forced event accepted: %s" % str(forced_result))
	var costly_nonmovement: Dictionary = _event(
		1, {"col": 1, "row": 1}, {"col": 1, "row": 1}, "no_route", "none", 1
	)
	var nonmovement_result: Dictionary = EventContract.validate(costly_nonmovement)
	if not _matches_failure(nonmovement_result, "nonmovement_event_has_cost", "cost"):
		return _fail("positive-cost nonmovement event accepted: %s" % str(nonmovement_result))
	var nonmovement_history: Dictionary = _result_for_history(
		[], [costly_nonmovement], 0, 0, {"col": 1, "row": 1}
	)
	nonmovement_history["stop_reason"] = "no_route"
	var nonmovement_history_result: Dictionary = ResultContract.validate(nonmovement_history)
	if not _matches_failure(
		nonmovement_history_result,
		"invalid_event.nonmovement_event_has_cost",
		"events.cost"
	):
		return _fail("positive-cost nonmovement history accepted: %s" % str(nonmovement_history_result))
	return _pass()


static func _t_positions_exact_no_origin_bypass() -> Dictionary:
	var context: Dictionary = _valid_context()
	context["origin"] = {"col": 1, "row": 1, "label": "extra"}
	var context_result: Dictionary = ContextContract.validate(context)
	if not _matches_failure(context_result, "invalid_position", "origin"):
		return _fail("context accepted position metadata: %s" % str(context_result))
	var option: Dictionary = _valid_option([
		{"col": 1, "row": 1, "label": "origin disguise"},
		{"col": 3, "row": 1},
	])
	var option_result: Dictionary = OptionContract.validate(option, {"col": 1, "row": 1})
	if not _matches_failure(option_result, "invalid_position", "path"):
		return _fail("path position metadata bypassed origin equality: %s" % str(option_result))
	var event: Dictionary = _event(
		1, {"col": 1, "row": 1, "source": "extra"}, {"col": 2, "row": 1}
	)
	var event_result: Dictionary = EventContract.validate(event)
	if not _matches_failure(event_result, "invalid_position", "from_pos"):
		return _fail("event accepted position metadata: %s" % str(event_result))
	return _pass()


static func _t_movement_event_edges_adjacent() -> Dictionary:
	var diagonal: Dictionary = _event(1, {"col": 1, "row": 1}, {"col": 2, "row": 2})
	var diagonal_result: Dictionary = EventContract.validate(diagonal)
	if not bool(diagonal_result["valid"]):
		return _fail("adjacent diagonal movement edge rejected: %s" % str(diagonal_result))
	var self_edge: Dictionary = _event(1, {"col": 1, "row": 1}, {"col": 1, "row": 1})
	var self_result: Dictionary = EventContract.validate(self_edge)
	if not _matches_failure(self_result, "invalid_movement_edge", "to_pos"):
		return _fail("self movement edge accepted: %s" % str(self_result))
	var leap: Dictionary = _event(1, {"col": 1, "row": 1}, {"col": 3, "row": 1})
	var leap_result: Dictionary = EventContract.validate(leap)
	if not _matches_failure(leap_result, "invalid_movement_edge", "to_pos"):
		return _fail("multi-cell voluntary leap accepted: %s" % str(leap_result))
	var forced_leap: Dictionary = _event(
		1, {"col": 1, "row": 1}, {"col": 1, "row": 3}, "", "forced", 0
	)
	var forced_result: Dictionary = EventContract.validate(forced_leap)
	if not _matches_failure(forced_result, "invalid_movement_edge", "to_pos"):
		return _fail("multi-cell forced leap accepted: %s" % str(forced_result))
	var nonmovement_fact: Dictionary = _event(
		1, {"col": 1, "row": 1}, {"col": 8, "row": 8}, "", "none", 0
	)
	var nonmovement_result: Dictionary = EventContract.validate(nonmovement_fact)
	if not bool(nonmovement_result["valid"]):
		return _fail("nonmovement positional fact was incorrectly edge-limited: %s" % str(nonmovement_result))
	return _pass()


static func _t_result_stop_facts_terminal() -> Dictionary:
	var mismatch: Dictionary = _valid_result()
	mismatch["stop_reason"] = "interrupted"
	var mismatch_result: Dictionary = ResultContract.validate(mismatch)
	if not _matches_failure(mismatch_result, "event_stop_reason_mismatch", "stop_reason"):
		return _fail("top-level/event stop mismatch accepted: %s" % str(mismatch_result))
	var post_stop_events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}, "interrupted"),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}),
	]
	var post_stop: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], post_stop_events, 2, 0, {"col": 3, "row": 1}
	)
	post_stop["stop_reason"] = "interrupted"
	var post_stop_result: Dictionary = ResultContract.validate(post_stop)
	if not _matches_failure(post_stop_result, "movement_after_stop_event", "events"):
		return _fail("movement after terminal stop event accepted: %s" % str(post_stop_result))
	var later_nonmovement_events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination"),
		_event(3, {"col": 9, "row": 9}, {"col": 8, "row": 8}, "", "none", 0),
	]
	var later_nonmovement: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}],
		later_nonmovement_events,
		2,
		0,
		{"col": 3, "row": 1}
	)
	var later_nonmovement_result: Dictionary = ResultContract.validate(later_nonmovement)
	if not bool(later_nonmovement_result["valid"]):
		return _fail("later nonmovement fact rejected after stop: %s" % str(later_nonmovement_result))
	var no_route: Dictionary = ResultContract.build(
		"echo.1", "activation.1", "goal.advance", "option.none", "advance",
		{"col": 1, "row": 1}, {"col": 1, "row": 1}, [], [],
		0, 0, 2, "no_route", [], {}, {}, {}, [], 0.0, {}
	)
	var no_route_result: Dictionary = ResultContract.validate(no_route)
	if not bool(no_route_result["valid"]):
		return _fail("legitimate no-event no-route result rejected: %s" % str(no_route_result))
	return _pass()


static func _t_required_fields_exact_tables() -> Dictionary:
	var tables: Array = [
		{
			"name": "MovementContext",
			"actual": ContextContract.REQUIRED_FIELDS,
			"expected": ["mover_id", "activation_id", "origin", "bounds", "authoritative_walkable", "perceived_planning_cells", "occupancy", "perceived_actors", "relationships", "terrain_costs", "known_hazards", "objective_pressure", "movement_history"],
			"value": _valid_context(),
			"validator": Callable(ContextContract, "validate"),
		},
		{
			"name": "MovementProfile",
			"actual": ProfileContract.REQUIRED_FIELDS,
			"expected": ["capacity", "source_terms", "controlling_state", "actor_kind", "authored_override"],
			"value": ProfileContract.build(2, [], true, "echo", {}),
			"validator": Callable(ProfileContract, "validate"),
		},
		{
			"name": "MovementGoal",
			"actual": GoalContract.REQUIRED_FIELDS,
			"expected": ["goal_id", "purpose", "destination_region", "urgency", "objective_progress", "relevant_actors", "pressure_sources", "planned_primary", "declared_fallback"],
			"value": _valid_goal(),
			"validator": Callable(GoalContract, "validate"),
			"origin": {"col": 1, "row": 1},
		},
		{
			"name": "MovementOption",
			"actual": OptionContract.REQUIRED_FIELDS,
			"expected": ["goal_id", "option_id", "purpose", "destination", "path", "route_cost", "shortest_cost", "slack", "capacity", "commitment", "exposure", "congestion", "cohesion", "hostile_control_sources", "hazard_summary", "objective_progress", "planned_action", "fallback"],
			"value": _valid_option(),
			"validator": Callable(OptionContract, "validate"),
			"origin": {"col": 1, "row": 1},
		},
		{
			"name": "MovementIntent",
			"actual": IntentContract.REQUIRED_FIELDS,
			"expected": ["mover_id", "activation_id", "goal_id", "option_id", "path", "capacity", "commitment", "planned_action", "fallback", "pressure_sources"],
			"value": _valid_intent(),
			"validator": Callable(IntentContract, "validate"),
			"origin": {"col": 1, "row": 1},
		},
		{
			"name": "MovementEvent",
			"actual": EventContract.REQUIRED_FIELDS,
			"expected": ["seq", "phase", "type", "source_id", "from_pos", "to_pos", "movement_kind", "cost", "hazard", "damage", "stop_reason"],
			"value": _event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
			"validator": Callable(EventContract, "validate"),
		},
		{
			"name": "MovementResult",
			"actual": ResultContract.REQUIRED_FIELDS,
			"expected": ["mover_id", "activation_id", "goal_id", "option_id", "purpose", "origin", "final_destination", "planned_path", "actual_traversed_cells", "voluntary_cost", "forced_steps", "remaining_capacity", "stop_reason", "events", "planned_action", "resolved_action", "fallback", "hazards", "objective_progress", "hostile_constraints"],
			"value": _valid_result(),
			"validator": Callable(ResultContract, "validate"),
		},
	]
	for table_value: Variant in tables:
		var table: Dictionary = table_value as Dictionary
		var expected: Array = table["expected"] as Array
		if (table["actual"] as Array) != expected:
			return _fail("%s REQUIRED_FIELDS literal changed" % str(table["name"]))
		for field_value: Variant in expected:
			var field: String = str(field_value)
			var invalid: Dictionary = (table["value"] as Dictionary).duplicate(true)
			invalid.erase(field)
			var validator: Callable = table["validator"] as Callable
			var result: Dictionary
			if table.has("origin"):
				result = validator.call(invalid, table["origin"] as Dictionary)
			else:
				result = validator.call(invalid)
			if not _matches_failure(result, "missing_field", field):
				return _fail("%s missing %s diagnostic changed: %s" % [str(table["name"]), field, str(result)])
	return _pass()


static func _t_all_mutable_inputs_deep_copied() -> Dictionary:
	var context_origin := {"col": 1, "row": 1}
	var context_bounds := {"w": 10, "h": 10}
	var walkable := {"1,1": true}
	var planning := {"1,1": true}
	var occupancy := {"2,1": "enemy.1"}
	var perceived: Array = [{
		"id": "enemy.1", "position": {"col": 2, "row": 1}, "kind": "enemy",
		"is_dead": false, "is_ko": false, "is_structure": false,
		"is_spirit": false, "is_quarry": false, "controlling_state": true,
		"health_ratio": 1.0,
	}]
	var relationships := {"enemy.1": "hostile"}
	var terrain_costs := {"1,1": 1}
	var hazards: Array = [{"id": "hazard.1", "position": {"col": 1, "row": 1}, "hazard_type": "binding"}]
	var pressure := {"mode": "recover"}
	var history: Array = [{"destination": {"col": 0, "row": 1}}]
	var context: Dictionary = ContextContract.build(
		"echo.1", "activation.1", context_origin, context_bounds, walkable, planning,
		occupancy, perceived, relationships, terrain_costs, hazards, pressure, history
	)
	var expected_context: Dictionary = context.duplicate(true)
	context_origin["col"] = 9
	context_bounds["w"] = 99
	walkable["1,1"] = false
	planning["1,1"] = false
	occupancy["2,1"] = "mutated"
	(perceived[0] as Dictionary)["id"] = "mutated"
	relationships["enemy.1"] = "neutral"
	terrain_costs["1,1"] = 9
	(hazards[0] as Dictionary)["id"] = "mutated"
	pressure["mode"] = "mutated"
	((history[0] as Dictionary)["destination"] as Dictionary)["col"] = 9
	if context != expected_context:
		return _fail("MovementContext did not deep-copy every mutable input")

	var source_terms: Array = [{"source": "base", "amount": 2}]
	var authored_override := {"source": "authored", "capacity": 2}
	var profile: Dictionary = ProfileContract.build(2, source_terms, true, "echo", authored_override)
	var expected_profile: Dictionary = profile.duplicate(true)
	(source_terms[0] as Dictionary)["amount"] = 9
	authored_override["source"] = "mutated"
	if profile != expected_profile:
		return _fail("MovementProfile did not deep-copy every mutable input")

	var destination_region: Array = [{"col": 3, "row": 1}]
	var relevant_actors: Array = ["echo.1"]
	var goal_sources: Array = ["pressure.a"]
	var primary := {"type": "actor.guard", "target_id": "", "payload": {"v": 1}}
	var declared_fallback := {"type": "actor.idle", "target_id": "", "payload": {"v": 1}}
	var goal: Dictionary = GoalContract.build(
		"goal.1", "hold", destination_region, 1.0, 0.0, relevant_actors,
		goal_sources, primary, declared_fallback
	)
	var expected_goal: Dictionary = goal.duplicate(true)
	(destination_region[0] as Dictionary)["col"] = 9
	relevant_actors[0] = "mutated"
	goal_sources[0] = "mutated"
	(primary["payload"] as Dictionary)["v"] = 9
	(declared_fallback["payload"] as Dictionary)["v"] = 9
	if goal != expected_goal:
		return _fail("MovementGoal did not deep-copy every mutable input")

	var option_destination := {"col": 3, "row": 1}
	var option_path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var hostile_sources: Array = ["enemy.1"]
	var hazard_summary := {"known_count": 1, "known_ids": ["hazard.1"]}
	var option_action := {"type": "actor.guard", "target_id": "", "payload": {"v": 1}}
	var option_fallback := {"type": "actor.idle", "target_id": "", "payload": {"v": 1}}
	var option: Dictionary = OptionContract.build(
		"goal.1", "option.1", "hold", option_destination, option_path, 2, 2, 0, 3, 2,
		0.0, 0.0, 1.0, hostile_sources, hazard_summary, 0.0, option_action, option_fallback
	)
	var expected_option: Dictionary = option.duplicate(true)
	option_destination["col"] = 9
	(option_path[0] as Dictionary)["col"] = 9
	hostile_sources[0] = "mutated"
	hazard_summary["known_count"] = 9
	(option_action["payload"] as Dictionary)["v"] = 9
	(option_fallback["payload"] as Dictionary)["v"] = 9
	if option != expected_option:
		return _fail("MovementOption did not deep-copy every mutable input")

	var intent_path: Array = [{"col": 2, "row": 1}]
	var intent_action := {"type": "actor.guard", "target_id": "", "payload": {"v": 1}}
	var intent_fallback := {"type": "actor.idle", "target_id": "", "payload": {"v": 1}}
	var intent_sources: Array = ["pressure.a"]
	var intent: Dictionary = IntentContract.build(
		"echo.1", "activation.1", "goal.1", "option.1", intent_path, 2, 1,
		intent_action, intent_fallback, intent_sources
	)
	var expected_intent: Dictionary = intent.duplicate(true)
	(intent_path[0] as Dictionary)["col"] = 9
	(intent_action["payload"] as Dictionary)["v"] = 9
	(intent_fallback["payload"] as Dictionary)["v"] = 9
	intent_sources[0] = "mutated"
	if intent != expected_intent:
		return _fail("MovementIntent did not deep-copy every mutable input")

	var event_from := {"col": 1, "row": 1}
	var event_to := {"col": 2, "row": 1}
	var event_hazard := {"details": {"id": "hazard.1"}}
	var event: Dictionary = EventContract.build(
		1, "movement", "cell_entered", "echo.1", event_from, event_to,
		"voluntary", 1, event_hazard, 0, ""
	)
	var expected_event: Dictionary = event.duplicate(true)
	event_from["col"] = 9
	event_to["col"] = 9
	(event_hazard["details"] as Dictionary)["id"] = "mutated"
	if event != expected_event:
		return _fail("MovementEvent did not deep-copy every mutable input")

	var result_origin := {"col": 1, "row": 1}
	var result_final := {"col": 3, "row": 1}
	var planned_path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var actual_path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var result_events: Array = [
		_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
		_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination"),
	]
	var result_action := {"type": "combat.guard", "payload": {"v": 1}}
	var resolved_action := {"type": "combat.guard", "payload": {"v": 1}}
	var result_fallback := {"type": "combat.wait", "payload": {"v": 1}}
	var result_hazards: Array = [{"details": {"id": "hazard.1"}}]
	var hostile_constraints := {"sources": ["enemy.1"]}
	var movement_result: Dictionary = ResultContract.build(
		"echo.1", "activation.1", "goal.1", "option.1", "hold",
		result_origin, result_final, planned_path, actual_path, 2, 0, 0,
		"reached_destination", result_events, result_action, resolved_action,
		result_fallback, result_hazards, 1.0, hostile_constraints
	)
	var expected_result: Dictionary = movement_result.duplicate(true)
	result_origin["col"] = 9
	result_final["col"] = 9
	(planned_path[0] as Dictionary)["col"] = 9
	(actual_path[0] as Dictionary)["col"] = 9
	(result_events[0] as Dictionary)["seq"] = 9
	(result_action["payload"] as Dictionary)["v"] = 9
	(resolved_action["payload"] as Dictionary)["v"] = 9
	(result_fallback["payload"] as Dictionary)["v"] = 9
	((result_hazards[0] as Dictionary)["details"] as Dictionary)["id"] = "mutated"
	(hostile_constraints["sources"] as Array)[0] = "mutated"
	if movement_result != expected_result:
		return _fail("MovementResult did not deep-copy every mutable input")
	return _pass()


static func _t_result_remaining_capacity_capped() -> Dictionary:
	var movement_result: Dictionary = _valid_result()
	movement_result["remaining_capacity"] = 7
	var result: Dictionary = ResultContract.validate(movement_result)
	if not _matches_failure(result, "capacity_exceeds_system_cap", "remaining_capacity"):
		return _fail("remaining capacity above six accepted: %s" % str(result))
	return _pass()


static func _t_result_nonempty_events_require_stop() -> Dictionary:
	var movement_result: Dictionary = _valid_result()
	for event_value: Variant in movement_result["events"] as Array:
		(event_value as Dictionary)["stop_reason"] = ""
	var result: Dictionary = ResultContract.validate(movement_result)
	if not _matches_failure(result, "missing_event_stop_reason", "events"):
		return _fail("nonempty event history without stop fact accepted: %s" % str(result))
	return _pass()


static func _t_result_hazards_exact_projection() -> Dictionary:
	var hazard_a := {"id": "hazard.a", "type": "unstable"}
	var hazard_b := {"id": "hazard.b", "type": "binding"}
	var events: Array = [
		EventContract.build(
			1, "entry", "hazard_triggered", "hazard.a",
			{"col": 1, "row": 1}, {"col": 2, "row": 1},
			"voluntary", 1, hazard_a, 0, ""
		),
		EventContract.build(
			2, "entry", "hazard_triggered", "hazard.b",
			{"col": 2, "row": 1}, {"col": 3, "row": 1},
			"voluntary", 1, hazard_b, 0, "reached_destination"
		),
	]
	var movement_result: Dictionary = _result_for_history(
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], events, 2, 0, {"col": 3, "row": 1}
	)
	movement_result["hazards"] = [hazard_a.duplicate(true), hazard_b.duplicate(true)]
	var result: Dictionary = ResultContract.validate(movement_result)
	if not bool(result["valid"]):
		return _fail("truthful chronological hazard projection rejected: %s" % str(result))
	var false_hazard: Dictionary = movement_result.duplicate(true)
	(false_hazard["hazards"] as Array).append({"id": "hazard.false", "type": "burning"})
	var false_result: Dictionary = ResultContract.validate(false_hazard)
	if not _matches_failure(false_result, "hazard_projection_mismatch", "hazards"):
		return _fail("hazard absent from events was accepted: %s" % str(false_result))
	var misordered: Dictionary = movement_result.duplicate(true)
	(misordered["hazards"] as Array).reverse()
	var misordered_result: Dictionary = ResultContract.validate(misordered)
	if not _matches_failure(misordered_result, "hazard_projection_mismatch", "hazards"):
		return _fail("misordered hazard projection accepted: %s" % str(misordered_result))
	return _pass()


static func _valid_context() -> Dictionary:
	return ContextContract.build(
		"echo.1", "activation.1", {"col": 1, "row": 1}, {"w": 10, "h": 10},
		{"1,1": true, "2,1": true}, {"1,1": true, "2,1": true}, {}, [], {},
		{"2,1": 1}, [], {"mode": "recover"}, []
	)


static func _valid_goal() -> Dictionary:
	return GoalContract.build(
		"goal.recover.hold.holder.c3r1", "hold", [{"col": 3, "row": 1}], 0.8, 1.0,
		["echo.1"], ["objective.relic"],
		{"type": "actor.guard", "target_id": "", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}
	)


static func _valid_option(path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]) -> Dictionary:
	return OptionContract.build(
		"goal.recover.hold.holder.c3r1",
		"option.recover.hold.holder.c3r1.direct.d3r1.pc2r1-c3r1",
		"hold", {"col": 3, "row": 1},
		path, 2, 2, 0, 3, 2, 0.2, 0.0, 1.0, ["enemy.1"],
		{"known_count": 0, "known_ids": []}, 1.0,
		{"type": "actor.guard", "target_id": "", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}
	)


static func _valid_intent() -> Dictionary:
	return IntentContract.build(
		"echo.1", "activation.1", "goal.recover.hold", "option.recover.hold.1",
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], 3, 2,
		{"type": "actor.guard", "target_id": "", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}, ["objective.relic"]
	)


static func _event(
	seq: int,
	from_pos: Dictionary,
	to_pos: Dictionary,
	stop_reason: String = "",
	movement_kind: String = "voluntary",
	cost: int = 1
) -> Dictionary:
	return EventContract.build(
		seq, "movement", "cell_entered", "echo.1", from_pos, to_pos,
		movement_kind, cost, {}, 0, stop_reason
	)


static func _valid_result(
	actual: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}],
	events: Array = []
) -> Dictionary:
	var ordered_events: Array = events
	if ordered_events.is_empty():
		ordered_events = [
			_event(1, {"col": 1, "row": 1}, {"col": 2, "row": 1}),
			_event(2, {"col": 2, "row": 1}, {"col": 3, "row": 1}, "reached_destination"),
		]
	var final_destination := {"col": 3, "row": 1}
	if actual.is_empty():
		final_destination = {"col": 1, "row": 1}
	else:
		final_destination = (actual.back() as Dictionary).duplicate(true)
	return ResultContract.build(
		"echo.1", "activation.1", "goal.recover.hold", "option.recover.hold.1", "hold_objective",
		{"col": 1, "row": 1}, final_destination,
		[{"col": 2, "row": 1}, {"col": 3, "row": 1}], actual,
		2, 0, 1, "reached_destination", ordered_events,
		{"type": "combat.guard"}, {"type": "combat.guard"}, {}, [], 1.0,
		{"hostile_control_sources": ["enemy.1"]}
	)


static func _result_for_history(
	actual: Array,
	events: Array,
	voluntary_cost: int,
	forced_steps: int,
	final_destination: Dictionary
) -> Dictionary:
	return ResultContract.build(
		"echo.1", "activation.1", "goal.recover.hold", "option.recover.hold.1", "hold_objective",
		{"col": 1, "row": 1}, final_destination, actual, actual,
		voluntary_cost, forced_steps, 0, "reached_destination", events,
		{"type": "combat.guard"}, {"type": "combat.guard"}, {}, [], 1.0,
		{"hostile_control_sources": ["enemy.1"]}
	)


static func _matches_failure(result: Dictionary, reason: String, field: String) -> bool:
	return (
		not bool(result.get("valid", true))
		and str(result.get("reason", "")) == reason
		and str(result.get("field", "")) == field
	)


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
