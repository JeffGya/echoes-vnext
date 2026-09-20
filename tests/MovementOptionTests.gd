class_name MovementOptionTests
extends RefCounted

const PathService = preload("res://core/movement/MovementPathService.gd")
const OptionService = preload("res://core/movement/MovementOptionService.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const ActorFact = preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const MovementGoal = preload("res://core/movement/contracts/MovementGoal.gd")
const MovementProfile = preload("res://core/movement/contracts/MovementProfile.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement_option/edge_costs_all_public_apis", Callable(MovementOptionTests, "_t_edge_costs_all_public_apis"))
	runner.register_test("movement_option/edge_cost_direction_and_order", Callable(MovementOptionTests, "_t_edge_cost_direction_and_order"))
	runner.register_test("movement_option/edge_cost_invalid_envelopes", Callable(MovementOptionTests, "_t_edge_cost_invalid_envelopes"))
	runner.register_test("movement_option/primary_control_metrics", Callable(MovementOptionTests, "_t_primary_control_metrics"))
	runner.register_test("movement_option/safe_strictly_improves", Callable(MovementOptionTests, "_t_safe_strictly_improves"))
	runner.register_test("movement_option/cohesive_strictly_improves", Callable(MovementOptionTests, "_t_cohesive_strictly_improves"))
	runner.register_test("movement_option/conservative_prefix", Callable(MovementOptionTests, "_t_conservative_prefix"))
	runner.register_test("movement_option/purpose_primary_styles", Callable(MovementOptionTests, "_t_purpose_primary_styles"))
	runner.register_test("movement_option/truthful_hold", Callable(MovementOptionTests, "_t_truthful_hold"))
	runner.register_test("movement_option/truncated_attack_keeps_primary", Callable(MovementOptionTests, "_t_truncated_attack_keeps_primary"))
	runner.register_test("movement_option/hold_in_place_no_endpoints", Callable(MovementOptionTests, "_t_hold_in_place_no_endpoints"))
	runner.register_test("movement_option/perceived_intersection_and_occupancy", Callable(MovementOptionTests, "_t_perceived_intersection_and_occupancy"))
	runner.register_test("movement_option/reversed_inputs_stable", Callable(MovementOptionTests, "_t_reversed_inputs_stable"))
	runner.register_test("movement_option/mirrored_metrics_covary", Callable(MovementOptionTests, "_t_mirrored_metrics_covary"))
	runner.register_test("movement_option/invalid_inputs_before_generation", Callable(MovementOptionTests, "_t_invalid_inputs_before_generation"))
	runner.register_test("movement_option/withdraw_uses_retreating_style", Callable(MovementOptionTests, "_t_withdraw_uses_retreating_style"))
	runner.register_test("movement_option/lateral_flanks_around_threat", Callable(MovementOptionTests, "_t_lateral_flanks_around_threat"))
	runner.register_test("movement_option/lateral_distance_one_falls_back_to_baseline", Callable(MovementOptionTests, "_t_lateral_distance_one_falls_back_to_baseline"))
	runner.register_test("movement_option/forceful_pays_control_cost_for_fewer_steps", Callable(MovementOptionTests, "_t_forceful_pays_control_cost_for_fewer_steps"))
	runner.register_test("movement_option/overcommitted_spends_toward_capacity", Callable(MovementOptionTests, "_t_overcommitted_spends_toward_capacity"))
	runner.register_test("movement_option/low_exposure_diverges_from_safe", Callable(MovementOptionTests, "_t_low_exposure_diverges_from_safe"))
	runner.register_test("movement_option/forceful_overcommitted_low_exposure_reachable_end_to_end", Callable(MovementOptionTests, "_t_forceful_overcommitted_low_exposure_reachable_end_to_end"))


static func _t_edge_costs_all_public_apis() -> Dictionary:
	var origin: Dictionary = _cell(0, 0)
	var destination: Dictionary = _cell(2, 0)
	var walkable: Dictionary = _walkable([origin, _cell(1, 0), destination])
	var edges: Dictionary = {"0,0>1,0": 2, "1,0>2,0": 1}
	var shortest: Dictionary = PathService.shortest_path(origin, destination, walkable, {}, {"w": 3, "h": 1}, edges)
	if not bool(shortest["reachable"]) or int(shortest["cost"]) != 5:
		return _fail("Directed surcharges must be included in shortest cost: %s" % str(shortest))
	var region: Dictionary = PathService.reachable_cost_region(origin, 4, walkable, {}, {"w": 3, "h": 1}, edges)
	if int((region["costs"] as Dictionary).get("1,0", -1)) != 3 or (region["costs"] as Dictionary).has("2,0"):
		return _fail("Reachable region did not use complete edge-cost model: %s" % str(region))
	var route: Dictionary = PathService.validate_route(origin, [_cell(1, 0), destination], walkable, {}, {"w": 3, "h": 1}, edges)
	if not bool(route["valid"]) or int(route["cost"]) != 5:
		return _fail("Route validation did not use complete edge-cost model: %s" % str(route))
	return _pass()


static func _t_edge_cost_direction_and_order() -> Dictionary:
	var origin: Dictionary = _cell(0, 0)
	var destination: Dictionary = _cell(1, 0)
	var walkable: Dictionary = _walkable([origin, destination])
	var forward: Dictionary = PathService.shortest_path(origin, destination, walkable, {}, {}, {"0,0>1,0": 2})
	var reverse: Dictionary = PathService.shortest_path(destination, origin, walkable, {}, {}, {"0,0>1,0": 2})
	if int(forward["cost"]) != 3 or int(reverse["cost"]) != 1:
		return _fail("Edge costs must remain directed: %s / %s" % [forward, reverse])
	var ordered_a: Dictionary = {"0,0>1,0": 2, "1,0>0,0": 4}
	var ordered_b: Dictionary = {"1,0>0,0": 4, "0,0>1,0": 2}
	if PathService.shortest_path(origin, destination, walkable, {}, {}, ordered_a) != PathService.shortest_path(origin, destination, walkable, {}, {}, ordered_b):
		return _fail("Edge-cost insertion order changed path output")
	return _pass()


static func _t_edge_cost_invalid_envelopes() -> Dictionary:
	var origin: Dictionary = _cell(0, 0)
	var destination: Dictionary = _cell(1, 0)
	var walkable: Dictionary = _walkable([origin, destination])
	var cases: Array = [
		[{"00,0>1,0": 1}, "invalid_edge_cost_key"],
		[{"0,0>1,0": 1, 7: 2}, "invalid_edge_cost_key"],
		[{"0,0>2,0": 1}, "invalid_edge_cost_edge"],
		[{"0,0>1,0": -1}, "invalid_edge_cost"],
		[{"0,0>1,0": 1.0}, "invalid_edge_cost"],
	]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var edge_costs: Dictionary = case[0] as Dictionary
		var expected: String = str(case[1])
		var shortest: Dictionary = PathService.shortest_path(origin, destination, walkable, {}, {}, edge_costs)
		var region: Dictionary = PathService.reachable_cost_region(origin, 2, walkable, {}, {}, edge_costs)
		var route: Dictionary = PathService.validate_route(origin, [destination], walkable, {}, {}, edge_costs)
		if bool(shortest["reachable"]) or str(shortest["reason"]) != expected:
			return _fail("Shortest path accepted invalid edge map: %s" % str(shortest))
		if bool(region["reachable"]) or str(region["reason"]) != expected:
			return _fail("Reachable region accepted invalid edge map: %s" % str(region))
		if bool(route["valid"]) or str(route["reason"]) != expected:
			return _fail("Route validation accepted invalid edge map: %s" % str(route))
	var upfront: Dictionary = PathService.shortest_path({}, destination, walkable, {}, {}, {"bad": 1})
	if str(upfront["reason"]) != "invalid_edge_cost_key":
		return _fail("Whole edge map must validate before origin: %s" % str(upfront))
	return _pass()


static func _t_primary_control_metrics() -> Dictionary:
	var cells: Array = [_cell(0, 0), _cell(1, 0), _cell(2, 0), _cell(0, 1), _cell(1, 1), _cell(2, 1)]
	var active_a: Dictionary = _actor("enemy.a", _cell(0, 1), "enemy", false, false, false, false, false, true)
	var active_z: Dictionary = _actor("enemy.z", _cell(1, 1), "enemy", false, false, false, false, false, true)
	var context: Dictionary = _context(cells, [active_z, active_a], {"enemy.z": "hostile", "enemy.a": "hostile"})
	var result: Dictionary = OptionService.generate_options(context, _profile(2), _goal("advance", [_cell(1, 0)]))
	if not bool(result["valid"]):
		return _fail("Expected valid controlled route: %s" % str(result))
	var primary: Dictionary = _find_style(result["options"] as Array, "direct")
	if primary.is_empty() or int(primary["route_cost"]) != 2:
		return _fail("Overlapping controllers must charge +1 once, not per source: %s" % str(primary))
	if float(primary["exposure"]) != 1.0:
		return _fail("Expected the single traversed edge to be controlled: %s" % str(primary))
	if primary["hostile_control_sources"] != ["enemy.a", "enemy.z"]:
		return _fail("Expected every overlapping controller sorted exactly: %s" % str(primary))

	var excluded: Array = [
		_actor("enemy.dead", _cell(0, 1), "enemy", true),
		_actor("enemy.ko", _cell(0, 1), "enemy", false, true),
		_actor("enemy.structure", _cell(0, 1), "structure", false, false, true),
		_actor("enemy.passive", _cell(0, 1)),
	]
	for actor_value: Variant in excluded:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor["id"])
		var excluded_context: Dictionary = _context(cells, [actor], {actor_id: "hostile"})
		var excluded_result: Dictionary = OptionService.generate_options(
			excluded_context, _profile(2), _goal("advance", [_cell(1, 0)])
		)
		var excluded_primary: Dictionary = _find_style(excluded_result["options"] as Array, "direct")
		if int(excluded_primary.get("route_cost", -1)) != 1 \
			or excluded_primary.get("hostile_control_sources", [actor_id]) != []:
			return _fail("Ineligible controller projected control: %s / %s" % [actor_id, excluded_primary])
	return _pass()


static func _t_safe_strictly_improves() -> Dictionary:
	var cells: Array = []
	for col in range(4):
		for row in range(2):
			cells.append(_cell(col, row))
	var hazards: Array = [
		HazardFact.build("hazard.z", _cell(1, 0), "binding"),
		HazardFact.build("hazard.a", _cell(1, 0), "unstable"),
	]
	var context: Dictionary = _context(cells, [], {}, {}, hazards)
	var result: Dictionary = OptionService.generate_options(context, _profile(4), _goal("advance", [_cell(3, 0)]))
	var primary: Dictionary = _find_style(result["options"] as Array, "direct")
	var safe: Dictionary = _find_style(result["options"] as Array, "safe")
	if safe.is_empty():
		return _fail("Expected truthful hazard-improving safe endpoint: %s" % str(result))
	if int((safe["hazard_summary"] as Dictionary)["known_count"]) >= int((primary["hazard_summary"] as Dictionary)["known_count"]):
		return _fail("Safe option did not strictly improve hazard count")
	if (primary["hazard_summary"] as Dictionary)["known_ids"] != ["hazard.a", "hazard.z"]:
		return _fail("Known hazard IDs must be sorted and unique: %s" % str(primary["hazard_summary"]))
	var no_hazard_context: Dictionary = _context(cells)
	var no_hazard_result: Dictionary = OptionService.generate_options(
		no_hazard_context, _profile(4), _goal("advance", [_cell(3, 0)])
	)
	var no_hazard_primary: Dictionary = _find_style(no_hazard_result["options"] as Array, "direct")
	if int(primary["route_cost"]) != int(no_hazard_primary["route_cost"]):
		return _fail("Known hazards must not consume movement capacity")
	return _pass()


static func _t_cohesive_strictly_improves() -> Dictionary:
	var cells: Array = []
	for col in range(5):
		for row in range(4):
			cells.append(_cell(col, row))
	var friends: Array = [
		_actor("ally.close", _cell(3, 1)),
		_actor("ally.ko", _cell(4, 1), "echo", false, true),
		_actor("ally.far", _cell(0, 3)),
		_actor("ally.dead", _cell(4, 2), "echo", true),
		_actor("ally.structure", _cell(3, 2), "structure", false, false, true),
	]
	var relationships: Dictionary = {
		"ally.close": "friendly", "ally.ko": "friendly", "ally.far": "friendly",
		"ally.dead": "friendly", "ally.structure": "friendly",
	}
	var context: Dictionary = _context(cells, friends, relationships)
	var result: Dictionary = OptionService.generate_options(context, _profile(4), _goal("advance", [_cell(4, 0)]))
	var primary: Dictionary = _find_style(result["options"] as Array, "direct")
	var cohesive: Dictionary = _find_style(result["options"] as Array, "cohesive")
	if not is_equal_approx(float(primary["congestion"]), 0.25):
		return _fail("Congestion must use occupied neighboring cells divided by exact 8: %s" % str(primary))
	if not is_equal_approx(float(primary["cohesion"]), 2.0 / 3.0):
		return _fail("Cohesion denominator must include every living nonstructure friend, including KO: %s" % str(primary))
	if cohesive.is_empty() or float(cohesive["cohesion"]) <= float(primary["cohesion"]):
		return _fail("Cohesive option must strictly improve friend proximity: %s" % str(result))
	return _pass()


static func _t_conservative_prefix() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 5, 0))
	context["terrain_costs"] = {"1,0": 2}
	var result: Dictionary = OptionService.generate_options(context, _profile(4), _goal("advance", [_cell(5, 0)]))
	var primary: Dictionary = _find_style(result["options"] as Array, "direct")
	var conservative: Dictionary = _find_style(result["options"] as Array, "conservative")
	if primary["path"] != [_cell(1, 0), _cell(2, 0), _cell(3, 0)] \
		or int(primary["route_cost"]) != 4 \
		or int(primary["shortest_cost"]) != 4 \
		or int(primary["slack"]) != 0:
		return _fail("Primary must use longest weighted-terrain capacity prefix with exact costs: %s" % str(primary))
	if conservative.is_empty() or int(conservative["route_cost"]) != 2:
		return _fail("Conservative must be longest primary prefix at half capacity: %s" % str(result))
	if (conservative["path"] as Array) != (primary["path"] as Array).slice(0, 1):
		return _fail("Conservative option must preserve the primary route prefix")

	var diagonal_cells: Array = []
	for col in range(5):
		for row in range(3):
			diagonal_cells.append(_cell(col, row))
	var diagonal_result: Dictionary = OptionService.generate_options(
		_context(diagonal_cells), _profile(2), _goal("advance", [_cell(4, 2)])
	)
	var diagonal_primary: Dictionary = _find_style(diagonal_result["options"] as Array, "direct")
	if diagonal_primary["destination"] != _cell(2, 1) \
		or not is_equal_approx(float(diagonal_primary["objective_progress"]), 0.5):
		return _fail("Objective progress must use minimum Chebyshev distance to region: %s" % str(diagonal_primary))
	return _pass()


static func _t_purpose_primary_styles() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 2, 0))
	var cases: Dictionary = {
		"advance": "direct",
		"reposition": "lateral",
		"regroup": "lateral",
		"protect": "screen",
		"escort": "screen",
		"intercept": "intercept",
		"cut_off": "intercept",
	}
	var purposes: Array = cases.keys()
	purposes.sort()
	for purpose_value: Variant in purposes:
		var purpose: String = str(purpose_value)
		var result: Dictionary = OptionService.generate_options(context, _profile(2), _goal(purpose, [_cell(2, 0)]))
		if _find_style(result["options"] as Array, str(cases[purpose])).is_empty():
			return _fail("Purpose %s did not emit primary style %s: %s" % [purpose, cases[purpose], result])

	var cap_cells: Array = []
	for col in range(7):
		for row in range(4):
			cap_cells.append(_cell(col, row))
	var cap_friend: Dictionary = _actor("ally.cap", _cell(4, 3))
	var cap_hazards: Array = [HazardFact.build("hazard.cap", _cell(1, 0), "unstable")]
	var cap_context: Dictionary = _context(
		cap_cells, [cap_friend], {"ally.cap": "friendly"}, {}, cap_hazards
	)
	var cap_result: Dictionary = OptionService.generate_options(
		cap_context, _profile(6), _goal("advance", [_cell(6, 0)])
	)
	# The cap now tracks STYLE_ORDER.size() (11), not a frozen 4 — this board simply has no
	# reachable forceful/overcommitted/low_exposure candidate (verified empirically), so it
	# still naturally produces exactly these 4. Global style order is still exact.
	var cap_options: Array = cap_result["options"] as Array
	if cap_options.size() != 4 \
		or _styles(cap_options) != ["direct", "safe", "cohesive", "conservative"]:
		return _fail("Option cap and global style order must be exact: %s" % str(cap_result))

	var direct: Dictionary = (cap_options[0] as Dictionary).duplicate(true)
	var same_safe: Dictionary = direct.duplicate(true)
	same_safe["option_id"] = str(same_safe["option_id"]).replace(".direct.d", ".safe.d")
	var earliest: Dictionary = OptionService._deduplicate_candidates([direct, same_safe])
	if not bool(earliest["valid"]) \
		or (earliest["options"] as Array).size() != 1 \
		or str(((earliest["options"] as Array)[0] as Dictionary)["option_id"]) != str(direct["option_id"]):
		return _fail("Duplicate mechanics must retain the earliest frozen style: %s" % str(earliest))
	var conflicting: Dictionary = same_safe.duplicate(true)
	conflicting["exposure"] = 1.0 if float(direct["exposure"]) < 1.0 else 0.0
	var conflict_result: Dictionary = OptionService._deduplicate_candidates([direct, conflicting])
	if bool(conflict_result["valid"]) \
		or str(conflict_result["reason"]) != "conflicting_duplicate_mechanics":
		return _fail("Conflicting duplicate mechanics must reject deterministically: %s" % str(conflict_result))
	return _pass()


static func _t_truthful_hold() -> Dictionary:
	var origin: Dictionary = _cell(0, 0)
	var context: Dictionary = _context([origin])
	var result: Dictionary = OptionService.generate_options(context, _profile(2), _goal("hold", [origin]))
	if not bool(result["valid"]) or (result["options"] as Array).size() != 1:
		return _fail("Truthful hold should produce one stay option: %s" % str(result))
	var option: Dictionary = (result["options"] as Array)[0] as Dictionary
	if option["path"] != [] or int(option["route_cost"]) != 0 or float(option["objective_progress"]) != 1.0:
		return _fail("Stay mechanics were not truthful: %s" % str(option))
	if not str(option["option_id"]).ends_with(".pstay"):
		return _fail("Stationary option must use pstay ID")
	return _pass()


# A far engage target whose route exceeds capacity keeps `planned_primary` VERBATIM on
# every option, in range or not.
#
# INVERTED by V2-COMBAT-003.5 Phase 3c, which made this generator the live per-turn
# producer. The recorded pre-change fact was the opposite: an option ending outside the
# goal region rewrote a range-bound primary into a bare `actor.move`. Live, that rewrite
# is destructive — `BehaviorArbiter._validate_movement_inputs` demands planned_action ==
# planned_primary and answers a mismatch by discarding the WHOLE board, and the rewrite
# also drops `target_id`, so a truncated approach stops naming who it is closing on.
# It protected nothing: `CombatActivationService` revalidates the primary at the final
# cell and takes the declared fallback when it is out of range.
static func _t_truncated_attack_keeps_primary() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 5, 0))
	var goal: Dictionary = MovementGoal.build(
		"goal.combat.engage.hunter.c5r0",
		"engage",
		[_cell(5, 0)],
		0.5,
		0.0,
		["enemy.a"],
		["mode.combat"],
		ActionPlan.build("melee_attack", "enemy.a"),
		ActionPlan.build("actor.idle")
	)
	var result: Dictionary = OptionService.generate_options(context, _profile(2), goal)
	if not bool(result["valid"]):
		return _fail("Truncated engage generation must succeed: %s" % str(result))
	var options: Array = result["options"] as Array
	if options.is_empty():
		return _fail("Truncated engage must still emit a movement option: %s" % str(result))
	var out_of_range_seen: bool = false
	for option_value: Variant in options:
		var option: Dictionary = option_value as Dictionary
		if not (goal["destination_region"] as Array).has(option["destination"] as Dictionary):
			out_of_range_seen = true
		if (option["planned_action"] as Dictionary) != (goal["planned_primary"] as Dictionary):
			return _fail("Every endpoint must carry planned_primary verbatim: %s" % str(option))
	if not out_of_range_seen:
		return _fail("Fixture produced no out-of-range endpoint — the assertion is vacuous")
	var primary: Dictionary = _find_style(options, "direct")
	if primary.is_empty() or primary["destination"] != _cell(2, 0):
		return _fail("Primary must truncate to capacity endpoint (2,0): %s" % str(primary))
	if str((primary["planned_action"] as Dictionary)["type"]) != "melee_attack":
		return _fail("Truncated primary must keep the melee plan: %s" % str(primary))
	if str((primary["planned_action"] as Dictionary)["target_id"]) != "enemy.a":
		return _fail("Truncated primary must keep naming its target: %s" % str(primary))
	return _pass()


# A holder already on the objective must stay put even when a nearby cell would improve
# cohesion: endpoint alternatives are suppressed so it cannot walk off the objective.
static func _t_hold_in_place_no_endpoints() -> Dictionary:
	var origin: Dictionary = _cell(0, 0)
	var friend: Dictionary = _actor("ally.f", _cell(3, 0))
	var context: Dictionary = _context(_line_cells(0, 3, 0), [friend], {"ally.f": "friendly"})
	var result: Dictionary = OptionService.generate_options(context, _profile(2), _goal("hold", [origin]))
	if not bool(result["valid"]) or (result["options"] as Array).size() != 1:
		return _fail("Holder on objective must emit exactly the stay option: %s" % str(result))
	var option: Dictionary = (result["options"] as Array)[0] as Dictionary
	if option["path"] != [] or int(option["route_cost"]) != 0 or float(option["objective_progress"]) != 1.0:
		return _fail("Stay mechanics were not truthful: %s" % str(option))
	if not str(option["option_id"]).ends_with(".pstay"):
		return _fail("Stationary hold must use pstay ID")
	return _pass()


static func _t_perceived_intersection_and_occupancy() -> Dictionary:
	var cells: Array = _line_cells(0, 3, 0)
	var perceived: Dictionary = _walkable(cells)
	perceived["1,0"] = false
	var hidden_context: Dictionary = _context(cells, [], {}, perceived)
	var hidden: Dictionary = OptionService.generate_options(hidden_context, _profile(3), _goal("advance", [_cell(3, 0)]))
	if not bool(hidden["valid"]) or not (hidden["options"] as Array).is_empty():
		return _fail("Unperceived authoritative cell must not enter planning: %s" % str(hidden))

	var blocker: Dictionary = _actor("ally.blocker", _cell(1, 0))
	var occupied_context: Dictionary = _context(cells, [blocker], {"ally.blocker": "friendly"})
	var occupied: Dictionary = OptionService.generate_options(occupied_context, _profile(3), _goal("advance", [_cell(3, 0)]))
	if not bool(occupied["valid"]) or not (occupied["options"] as Array).is_empty():
		return _fail("Occupied cells must be removed from option planning: %s" % str(occupied))
	var dead_blocker: Dictionary = _actor("ally.dead_blocker", _cell(1, 0), "echo", true)
	var dead_context: Dictionary = _context(cells, [dead_blocker], {"ally.dead_blocker": "friendly"})
	var dead_occupied: Dictionary = OptionService.generate_options(
		dead_context, _profile(3), _goal("advance", [_cell(3, 0)])
	)
	if not bool(dead_occupied["valid"]) or not (dead_occupied["options"] as Array).is_empty():
		return _fail("A dead actor retained in canonical occupancy must still block traversal: %s" % str(dead_occupied))
	return _pass()


static func _t_reversed_inputs_stable() -> Dictionary:
	var cells: Array = []
	for col in range(4):
		for row in range(3):
			cells.append(_cell(col, row))
	var actors: Array = [
		_actor("enemy.b", _cell(2, 2), "enemy", false, false, false, false, false, true),
		_actor("ally.a", _cell(0, 2)),
	]
	var relationships: Dictionary = {"enemy.b": "hostile", "ally.a": "friendly"}
	var hazards: Array = [
		HazardFact.build("hazard.z", _cell(2, 0), "binding"),
		HazardFact.build("hazard.a", _cell(1, 1), "unstable"),
	]
	var context_a: Dictionary = _context(cells, actors, relationships, {}, hazards)
	context_a["terrain_costs"] = {"1,0": 2, "2,1": 2}
	context_a["objective_pressure"] = {"outer": {"alpha": 1, "omega": 2}}
	var reversed_cells: Array = cells.duplicate(true)
	reversed_cells.reverse()
	var reversed_actors: Array = actors.duplicate(true)
	reversed_actors.reverse()
	var reversed_hazards: Array = hazards.duplicate(true)
	reversed_hazards.reverse()
	var context_b: Dictionary = _context(
		reversed_cells,
		reversed_actors,
		{"ally.a": "friendly", "enemy.b": "hostile"},
		{},
		reversed_hazards
	)
	context_b["terrain_costs"] = {"2,1": 2, "1,0": 2}
	context_b["objective_pressure"] = {"outer": {"omega": 2, "alpha": 1}}
	var goal: Dictionary = _goal("advance", [_cell(3, 1), _cell(3, 0)])
	if OptionService.generate_options(context_a, _profile(4), goal) != OptionService.generate_options(context_b, _profile(4), goal):
		return _fail("Reversing input insertion order changed exact options")
	return _pass()


static func _t_mirrored_metrics_covary() -> Dictionary:
	var cells: Array = [
		_cell(0, 1), _cell(1, 1), _cell(2, 1), _cell(3, 1), _cell(4, 1),
		_cell(4, 2), _cell(3, 2),
	]
	var friend: Dictionary = _actor("ally.mirror", _cell(3, 2))
	var hazards: Array = [HazardFact.build("hazard.mirror", _cell(2, 1), "binding")]
	var origin: Dictionary = _cell(0, 1)
	var goal_cell: Dictionary = _cell(4, 2)
	var context: Dictionary = _context(cells, [friend], {"ally.mirror": "friendly"}, {}, hazards, origin)
	var goal: Dictionary = _goal("advance", [goal_cell])
	var base_result: Dictionary = OptionService.generate_options(context, _profile(5), goal)
	var base: Dictionary = _find_style(base_result["options"] as Array, "direct")
	var transforms: Array = [
		{"name": "horizontal", "call": func(cell: Dictionary) -> Dictionary: return _cell(4 - int(cell["col"]), int(cell["row"]))},
		{"name": "vertical", "call": func(cell: Dictionary) -> Dictionary: return _cell(int(cell["col"]), 2 - int(cell["row"]))},
		{"name": "transpose", "call": func(cell: Dictionary) -> Dictionary: return _cell(int(cell["row"]), int(cell["col"]))},
	]
	for transform_value: Variant in transforms:
		var transform: Dictionary = transform_value as Dictionary
		var transform_cell: Callable = transform["call"] as Callable
		var transformed_cells: Array = []
		for cell_value: Variant in cells:
			transformed_cells.append(transform_cell.call(cell_value as Dictionary))
		var transformed_friend: Dictionary = _actor(
			"ally.mirror", transform_cell.call(friend["position"] as Dictionary)
		)
		var transformed_hazards: Array = [
			HazardFact.build(
				"hazard.mirror",
				transform_cell.call((hazards[0] as Dictionary)["position"] as Dictionary),
				"binding"
			),
		]
		var transformed_origin: Dictionary = transform_cell.call(origin)
		var transformed_goal: Dictionary = transform_cell.call(goal_cell)
		var transformed_context: Dictionary = _context(
			transformed_cells,
			[transformed_friend],
			{"ally.mirror": "friendly"},
			{},
			transformed_hazards,
			transformed_origin
		)
		var transformed_goal_contract: Dictionary = _goal("advance", [transformed_goal])
		var transformed_result: Dictionary = OptionService.generate_options(
			transformed_context, _profile(5), transformed_goal_contract
		)
		var candidate: Dictionary = _find_style(transformed_result["options"] as Array, "direct")
		var expected_path: Array = []
		for path_value: Variant in base["path"] as Array:
			expected_path.append(transform_cell.call(path_value as Dictionary))
		var expected_destination: Dictionary = transform_cell.call(base["destination"] as Dictionary)
		var expected_id: String = _expected_option_id(
			transformed_goal_contract, "direct", expected_destination, expected_path
		)
		if candidate["destination"] != expected_destination \
			or candidate["path"] != expected_path \
			or str(candidate["option_id"]) != expected_id:
			return _fail("%s transform drifted option ID/path: %s" % [transform["name"], candidate])
		for field: String in [
			"route_cost", "shortest_cost", "slack", "capacity", "commitment",
			"exposure", "congestion", "cohesion", "hostile_control_sources",
			"hazard_summary", "objective_progress", "planned_action", "fallback",
		]:
			if candidate[field] != base[field]:
				return _fail("%s transform drifted %s: %s / %s" % [transform["name"], field, base[field], candidate[field]])
	return _pass()


static func _t_invalid_inputs_before_generation() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 2, 0))
	var invalid_context: Dictionary = context.duplicate(true)
	invalid_context["unexpected"] = true
	var result: Dictionary = OptionService.generate_options(invalid_context, _profile(2), _goal("advance", [_cell(2, 0)]))
	if bool(result["valid"]) or not str(result["reason"]).begins_with("invalid_context."):
		return _fail("Invalid context must fail before generation: %s" % str(result))
	var invalid_goal: Dictionary = _goal("advance", [_cell(2, 0)])
	invalid_goal["goal_id"] = "not_goal_prefixed"
	result = OptionService.generate_options(context, _profile(2), invalid_goal)
	if bool(result["valid"]) or str(result["reason"]) != "invalid_goal.invalid_goal_id":
		return _fail("Invalid stable goal ID must fail before generation: %s" % str(result))
	var origin_goal: Dictionary = _goal("advance", [_cell(0, 0)])
	result = OptionService.generate_options(context, _profile(2), origin_goal)
	if bool(result["valid"]) \
		or str(result["reason"]) != "invalid_goal.goal_region_contains_origin":
		return _fail("Non-hold origin goal must fail before generation: %s" % str(result))
	return _pass()


## V2-COMBAT-003.5 Phase 3a gap 4 — withdraw must no longer fall through to the
## "direct" route-shape label; it gets its own "retreating" token.
static func _t_withdraw_uses_retreating_style() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 2, 0))
	var result: Dictionary = OptionService.generate_options(context, _profile(2), _goal("withdraw", [_cell(2, 0)]))
	if not bool(result["valid"]):
		return _fail("Expected valid withdraw generation: %s" % str(result))
	if _find_style(result["options"] as Array, "retreating").is_empty():
		return _fail("Withdraw purpose must emit the retreating route-shape: %s" % str(result))
	if not _find_style(result["options"] as Array, "direct").is_empty():
		return _fail("Withdraw purpose must not also emit direct: %s" % str(result))
	return _pass()


## Gap 3 — lateral must genuinely flank around a perceived threat rather than
## retrace `_build_primary`'s straight line under a different label.
static func _t_lateral_flanks_around_threat() -> Dictionary:
	var cells: Array = []
	for col in range(6):
		for row in range(3):
			cells.append(_cell(col, row))
	var origin: Dictionary = _cell(0, 1)
	var hostile: Dictionary = _actor("enemy.flank", _cell(0, 0), "enemy")
	var context: Dictionary = _context(cells, [hostile], {"enemy.flank": "hostile"}, {}, [], origin)
	var goal: Dictionary = _goal("reposition", [_cell(4, 1)])
	var result: Dictionary = OptionService.generate_options(context, _profile(4), goal)
	if not bool(result["valid"]):
		return _fail("Expected valid reposition generation: %s" % str(result))
	var lateral: Dictionary = _find_style(result["options"] as Array, "lateral")
	if lateral.is_empty():
		return _fail("Reposition purpose must emit a lateral option: %s" % str(result))
	if lateral["destination"] != _cell(3, 2):
		return _fail("Lateral must offset off the straight line toward the threat: %s" % str(lateral))

	var advance_result: Dictionary = OptionService.generate_options(
		context, _profile(4), _goal("advance", [_cell(4, 1)])
	)
	var straight: Dictionary = _find_style(advance_result["options"] as Array, "direct")
	if straight["destination"] == lateral["destination"] or straight["path"] == lateral["path"]:
		return _fail("Lateral route must genuinely differ from the straight route: %s / %s" % [straight, lateral])
	return _pass()


## Blocker 1 (QA fix pass) — a flank destination is always exactly 1 Chebyshev step off
## the baseline destination, so when the origin is already 1 step from the destination
## region, the flank option always scores objective_progress 0.0. This must fall back to
## the unoffset baseline route rather than returning zero options.
static func _t_lateral_distance_one_falls_back_to_baseline() -> Dictionary:
	var cells: Array = []
	for col in range(6):
		for row in range(3):
			cells.append(_cell(col, row))
	var origin: Dictionary = _cell(3, 1)
	var hostile: Dictionary = _actor("enemy.near", _cell(3, 0), "enemy")
	var context: Dictionary = _context(cells, [hostile], {"enemy.near": "hostile"}, {}, [], origin)
	var goal: Dictionary = _goal("regroup", [_cell(4, 1)])
	var result: Dictionary = OptionService.generate_options(context, _profile(2), goal)
	if not bool(result["valid"]):
		return _fail("Expected valid regroup generation at distance 1: %s" % str(result))
	if (result["options"] as Array).is_empty():
		return _fail("Distance-1 regroup must fall back to the baseline route, not zero options: %s" % str(result))
	var lateral: Dictionary = _find_style(result["options"] as Array, "lateral")
	if lateral.is_empty():
		return _fail("Expected a lateral primary even after falling back to baseline: %s" % str(result))
	return _pass()


## Gap 1 — forceful must be willing to pay hostile-control surcharges to take a
## route `_build_primary` (cost-optimal) avoids, producing a distinct path to
## the same destination.
static func _t_forceful_pays_control_cost_for_fewer_steps() -> Dictionary:
	var cells: Array = [
		_cell(0, 0), _cell(1, 0), _cell(2, 0), _cell(3, 0), _cell(4, 0),
		_cell(0, 1), _cell(2, 1), _cell(4, 1),
	]
	var origin: Dictionary = _cell(0, 0)
	var context: Dictionary = _context(cells, [], {}, {}, [], origin)
	var planning_walkable: Dictionary = OptionService._planning_walkable(context)
	var edge_costs: Dictionary = {
		"0,0>1,0": 1, "1,0>2,0": 1, "2,0>3,0": 1, "3,0>4,0": 1,
	}
	var goal: Dictionary = _goal("advance", [_cell(4, 0)])
	var profile: Dictionary = _profile(8)
	var primary: Dictionary = OptionService._build_primary(
		context, profile, goal, planning_walkable, edge_costs, {}, "direct"
	)
	var forceful: Dictionary = OptionService._build_forceful(
		context, profile, goal, planning_walkable, edge_costs, {}
	)
	if primary.is_empty() or forceful.is_empty():
		return _fail("Expected both routes to be viable: %s / %s" % [primary, forceful])
	if primary["destination"] != _cell(4, 0) or forceful["destination"] != _cell(4, 0):
		return _fail("Both routes must reach the same destination: %s / %s" % [primary, forceful])
	if primary["path"] == forceful["path"]:
		return _fail("Forceful must diverge from the cost-optimal primary path: %s" % str(forceful))
	if int(forceful["route_cost"]) <= int(primary["route_cost"]):
		return _fail("Forceful's control-tolerant route must cost more than the avoiding one: %s / %s" % [primary, forceful])
	return _pass()


## Gap 1 — overcommitted spends toward capacity instead of taking the cheapest
## affordable destination in the region.
static func _t_overcommitted_spends_toward_capacity() -> Dictionary:
	var context: Dictionary = _context(_line_cells(0, 5, 0))
	var planning_walkable: Dictionary = OptionService._planning_walkable(context)
	var goal: Dictionary = _goal("advance", [_cell(2, 0), _cell(5, 0)])
	var profile: Dictionary = _profile(5)
	var primary: Dictionary = OptionService._build_primary(
		context, profile, goal, planning_walkable, {}, {}, "direct"
	)
	var overcommitted: Dictionary = OptionService._build_overcommitted(
		context, profile, goal, planning_walkable, {}, {}
	)
	if primary.is_empty() or overcommitted.is_empty():
		return _fail("Expected both routes to be viable: %s / %s" % [primary, overcommitted])
	if primary["destination"] != _cell(2, 0):
		return _fail("Primary must take the cheapest destination: %s" % str(primary))
	if overcommitted["destination"] != _cell(5, 0):
		return _fail("Overcommitted must spend toward capacity: %s" % str(overcommitted))
	if int(overcommitted["route_cost"]) <= int(primary["route_cost"]):
		return _fail("Overcommitted must cost more than the cheapest primary: %s / %s" % [primary, overcommitted])
	return _pass()


## Gap 2 — low-exposure reorders the safe selector's two metrics, so it can
## pick a genuinely different candidate than `_select_safe` does.
static func _t_low_exposure_diverges_from_safe() -> Dictionary:
	var primary: Dictionary = {
		"option_id": "option.combat.advance.baseline.c9r9.d0r0.pstay",
		"destination": _cell(0, 0), "path": [], "route_cost": 3,
		"exposure": 0.5, "hazard_summary": {"known_count": 2, "known_ids": ["hazard.a", "hazard.b"]},
	}
	var fewer_hazards_worse_exposure: Dictionary = primary.duplicate(true)
	fewer_hazards_worse_exposure["destination"] = _cell(1, 0)
	fewer_hazards_worse_exposure["path"] = [_cell(1, 0)]
	fewer_hazards_worse_exposure["route_cost"] = 1
	fewer_hazards_worse_exposure["exposure"] = 0.6
	fewer_hazards_worse_exposure["hazard_summary"] = {"known_count": 1, "known_ids": ["hazard.a"]}
	var lower_exposure_same_hazards: Dictionary = primary.duplicate(true)
	lower_exposure_same_hazards["destination"] = _cell(2, 0)
	lower_exposure_same_hazards["path"] = [_cell(2, 0)]
	lower_exposure_same_hazards["route_cost"] = 2
	lower_exposure_same_hazards["exposure"] = 0.3
	lower_exposure_same_hazards["hazard_summary"] = {"known_count": 2, "known_ids": ["hazard.a", "hazard.b"]}
	var candidates: Array = [fewer_hazards_worse_exposure, lower_exposure_same_hazards]

	var safe: Dictionary = OptionService._select_safe(candidates, primary)
	var low_exposure: Dictionary = OptionService._select_low_exposure(candidates, primary)
	if safe.is_empty() or low_exposure.is_empty():
		return _fail("Expected both selectors to find an improving candidate: %s / %s" % [safe, low_exposure])
	if safe["destination"] != _cell(1, 0):
		return _fail("Safe must prioritise fewer known hazards: %s" % str(safe))
	if low_exposure["destination"] != _cell(2, 0):
		return _fail("Low-exposure must prioritise lower exposure: %s" % str(low_exposure))
	if safe["destination"] == low_exposure["destination"]:
		return _fail("Safe and low-exposure must diverge on this board: %s / %s" % [safe, low_exposure])
	return _pass()


static func _context(
	cells: Array,
	additional_actors: Array = [],
	relationships: Dictionary = {},
	perceived_override: Dictionary = {},
	hazards: Array = [],
	origin: Dictionary = {}
) -> Dictionary:
	var actual_origin: Dictionary = _cell(0, 0) if origin.is_empty() else origin
	var mover: Dictionary = _actor("mover.a", actual_origin)
	var actors: Array = [mover]
	actors.append_array(additional_actors)
	var occupancy: Dictionary = {_key(actual_origin): "mover.a"}
	for actor_value: Variant in additional_actors:
		var actor: Dictionary = actor_value as Dictionary
		occupancy[_key(actor["position"] as Dictionary)] = str(actor["id"])
	var all_relationships: Dictionary = {"mover.a": "friendly"}
	for id_value: Variant in relationships:
		all_relationships[str(id_value)] = relationships[id_value]
	var walkable: Dictionary = _walkable(cells)
	var perceived: Dictionary = walkable.duplicate(true) if perceived_override.is_empty() else perceived_override.duplicate(true)
	return {
		"mover_id": "mover.a",
		"activation_id": "activation.a",
		"origin": actual_origin.duplicate(true),
		"bounds": _bounds(cells),
		"authoritative_walkable": walkable,
		"perceived_planning_cells": perceived,
		"occupancy": occupancy,
		"perceived_actors": actors,
		"relationships": all_relationships,
		"terrain_costs": {},
		"known_hazards": hazards,
		"objective_pressure": {},
		"movement_history": [],
	}


static func _profile(capacity: int) -> Dictionary:
	return MovementProfile.build(capacity, [], false, "echo", {})


static func _goal(purpose: String, region: Array) -> Dictionary:
	var target_id: String = "objective.a"
	var action_type: String = "actor.move"
	if purpose in ["intercept", "cut_off", "hold"]:
		action_type = "actor.guard"
		target_id = ""
	elif purpose in ["protect", "escort"]:
		action_type = "protect_ally"
		target_id = "ally.a"
	var relevant: Array = [] if target_id.is_empty() else [target_id]
	var fallback: Dictionary = {} if action_type == "actor.idle" else ActionPlan.build("actor.idle")
	return MovementGoal.build(
		"goal.combat.%s.baseline.c%dr%d" % [purpose, int((region[0] as Dictionary)["col"]), int((region[0] as Dictionary)["row"])],
		purpose,
		region,
		0.5,
		0.0,
		relevant,
		["mode.combat"],
		ActionPlan.build(action_type, target_id),
		fallback
	)


static func _actor(
	id: String,
	position: Dictionary,
	kind: String = "echo",
	is_dead: bool = false,
	is_ko: bool = false,
	is_structure: bool = false,
	is_spirit: bool = false,
	is_quarry: bool = false,
	controlling: bool = false
) -> Dictionary:
	return ActorFact.build(id, position, kind, is_dead, is_ko, is_structure, is_spirit, is_quarry, controlling, 1.0)


static func _find_style(options: Array, style: String) -> Dictionary:
	for option_value: Variant in options:
		var option: Dictionary = option_value as Dictionary
		if str(option["option_id"]).contains(".%s.d" % style):
			return option
	return {}


static func _styles(options: Array) -> Array:
	var styles: Array = []
	for style: String in ["direct", "safe", "cohesive", "lateral", "screen", "intercept", "conservative"]:
		if not _find_style(options, style).is_empty():
			styles.append(style)
	return styles


static func _walkable(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value: Variant in cells:
		result[_key(cell_value as Dictionary)] = true
	return result


static func _bounds(cells: Array) -> Dictionary:
	var max_col: int = 0
	var max_row: int = 0
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value as Dictionary
		max_col = maxi(max_col, int(cell["col"]))
		max_row = maxi(max_row, int(cell["row"]))
	return {"w": max_col + 1, "h": max_row + 1}


static func _line_cells(from_col: int, to_col: int, row: int) -> Array:
	var cells: Array = []
	for col in range(from_col, to_col + 1):
		cells.append(_cell(col, row))
	return cells


static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func _key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell["col"]), int(cell["row"])]


static func _mirror(cell: Dictionary, max_col: int) -> Dictionary:
	return _cell(max_col - int(cell["col"]), int(cell["row"]))


static func _expected_option_id(
	goal: Dictionary,
	style: String,
	destination: Dictionary,
	path: Array
) -> String:
	var token: String = "pstay"
	if not path.is_empty():
		var cells: Array = []
		for cell_value: Variant in path:
			var cell: Dictionary = cell_value as Dictionary
			cells.append("c%dr%d" % [int(cell["col"]), int(cell["row"])])
		token = "p%s" % "-".join(cells)
	return "option.%s.%s.d%dr%d.%s" % [
		str(goal["goal_id"]).trim_prefix("goal."), style,
		int(destination["col"]), int(destination["row"]), token,
	]


## Follow-up to the dedup-cap fix (V2-COMBAT-003.5 Phase 3a cleanup): `forceful`,
## `overcommitted` and `low_exposure` are allowlisted styles, but with the cap frozen at 4
## kept options and sorted by STYLE_ORDER, they were structurally excluded from
## `generate_options()`'s real output on almost any board. This proves each is reachable
## through the full pipeline (not just its builder function called directly, which the
## other tests in this file already cover) once the cap tracks the true style count.
static func _t_forceful_overcommitted_low_exposure_reachable_end_to_end() -> Dictionary:
	# forceful: a 2-step controlled route beats a cheaper-but-longer 3-step clean route on
	# step count, even though it costs more once repriced — see _build_forceful's doc comment.
	var forceful_cells: Array = [_cell(0, 0), _cell(1, 0), _cell(2, 0), _cell(0, 1), _cell(0, 2), _cell(0, 3)]
	var forceful_controller: Dictionary = _actor(
		"enemy.forceful", _cell(2, -1), "enemy", false, false, false, false, false, true
	)
	var forceful_context: Dictionary = _context(
		forceful_cells, [forceful_controller], {"enemy.forceful": "hostile"}
	)
	var forceful_goal: Dictionary = _goal("advance", [_cell(0, 3), _cell(2, 0)])
	var forceful_result: Dictionary = OptionService.generate_options(
		forceful_context, _profile(4), forceful_goal
	)
	if not bool(forceful_result["valid"]):
		return _fail("Expected valid forceful-reachable generation: %s" % str(forceful_result))
	var direct: Dictionary = _find_style(forceful_result["options"] as Array, "direct")
	var forceful: Dictionary = _find_style(forceful_result["options"] as Array, "forceful")
	if direct.is_empty() or forceful.is_empty():
		return _fail("Expected both direct and forceful in real output: %s" % str(forceful_result))
	if direct["destination"] == forceful["destination"] \
			or int(forceful["route_cost"]) <= int(direct["route_cost"]):
		return _fail("Forceful must diverge from and cost more than direct: %s" % str(forceful_result))

	# overcommitted: goal region spans a cheap-near and an expensive-far destination;
	# overcommitted spends toward capacity where direct takes the cheapest.
	var overcommitted_context: Dictionary = _context(_line_cells(0, 5, 0))
	var overcommitted_goal: Dictionary = _goal("advance", [_cell(2, 0), _cell(5, 0)])
	var overcommitted_result: Dictionary = OptionService.generate_options(
		overcommitted_context, _profile(5), overcommitted_goal
	)
	if not bool(overcommitted_result["valid"]):
		return _fail("Expected valid overcommitted-reachable generation: %s" % str(overcommitted_result))
	var overcommitted: Dictionary = _find_style(overcommitted_result["options"] as Array, "overcommitted")
	if overcommitted.is_empty() or overcommitted["destination"] != _cell(5, 0):
		return _fail("Expected overcommitted to spend toward capacity: %s" % str(overcommitted_result))

	# low_exposure: a controlled first two cells make hazard count monotonic in path length,
	# so safe prefers the shortest viable prefix, while a longer same-hazard route dilutes
	# the fixed controlled-edge count and wins on exposure instead — genuine divergence.
	var exposure_cells: Array = _line_cells(0, 6, 0)
	var exposure_controller: Dictionary = _actor(
		"enemy.exposure", _cell(0, -1), "enemy", false, false, false, false, false, true
	)
	var exposure_hazards: Array = [
		HazardFact.build("hazard.e1", _cell(1, 0), "unstable"),
		HazardFact.build("hazard.e2", _cell(2, 0), "unstable"),
	]
	var exposure_context: Dictionary = _context(
		exposure_cells, [exposure_controller], {"enemy.exposure": "hostile"}, {}, exposure_hazards
	)
	var exposure_goal: Dictionary = _goal("advance", [_cell(3, 0)])
	var exposure_result: Dictionary = OptionService.generate_options(exposure_context, _profile(6), exposure_goal)
	if not bool(exposure_result["valid"]):
		return _fail("Expected valid low_exposure-reachable generation: %s" % str(exposure_result))
	var safe: Dictionary = _find_style(exposure_result["options"] as Array, "safe")
	var low_exposure: Dictionary = _find_style(exposure_result["options"] as Array, "low_exposure")
	if safe.is_empty() or low_exposure.is_empty():
		return _fail("Expected both safe and low_exposure in real output: %s" % str(exposure_result))
	if safe["destination"] == low_exposure["destination"] \
			or int((safe["hazard_summary"] as Dictionary)["known_count"]) \
				>= int((low_exposure["hazard_summary"] as Dictionary)["known_count"]) \
			or float(low_exposure["exposure"]) >= float(safe["exposure"]):
		return _fail("Safe and low_exposure must genuinely diverge: %s" % str(exposure_result))
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true, "error": ""}


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
