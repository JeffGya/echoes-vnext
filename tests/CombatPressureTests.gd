# res://tests/CombatPressureTests.gd
# V2-COMBAT-002 Slice 2: dormant seven-mode perceived-pressure goals.

class_name CombatPressureTests
extends RefCounted

const Service = preload("res://core/movement/CombatPressureService.gd")
const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const PressureContract = preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const V = preload("res://core/movement/contracts/MovementContractValidation.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/pressure/all_modes_party_hostile", Callable(CombatPressureTests, "_t_all_modes_party_hostile"))
	runner.register_test("movement/pressure/objective_actor_modes", Callable(CombatPressureTests, "_t_objective_actor_modes"))
	runner.register_test("movement/pressure/unknown_objective_search_only", Callable(CombatPressureTests, "_t_unknown_objective_search_only"))
	runner.register_test("movement/pressure/purify_threshold_and_plans", Callable(CombatPressureTests, "_t_purify_threshold_and_plans"))
	runner.register_test("movement/pressure/recover_roles_and_relic_safety", Callable(CombatPressureTests, "_t_recover_roles_and_relic_safety"))
	runner.register_test("movement/pressure/protect_stolen_carrier", Callable(CombatPressureTests, "_t_protect_stolen_carrier"))
	runner.register_test("movement/pressure/pursue_far_end", Callable(CombatPressureTests, "_t_pursue_far_end"))
	runner.register_test("movement/pressure/guide_join_boundary", Callable(CombatPressureTests, "_t_guide_join_boundary"))
	runner.register_test("movement/pressure/canonical_reversal", Callable(CombatPressureTests, "_t_canonical_reversal"))
	runner.register_test("movement/pressure/numeric_region_order", Callable(CombatPressureTests, "_t_numeric_region_order"))
	runner.register_test("movement/pressure/perceived_truth_and_sources", Callable(CombatPressureTests, "_t_perceived_truth_and_sources"))
	runner.register_test("movement/pressure/factual_role_crosschecks", Callable(CombatPressureTests, "_t_factual_role_crosschecks"))
	runner.register_test("movement/pressure/cap_complete_and_progress", Callable(CombatPressureTests, "_t_cap_complete_and_progress"))
	runner.register_test("movement/pressure/objective_alignment_gate", Callable(CombatPressureTests, "_t_objective_alignment_gate"))
	runner.register_test("movement/pressure/all_hostiles_blocked_first", Callable(CombatPressureTests, "_t_all_hostiles_blocked_first"))
	runner.register_test("movement/pressure/guide_authoritative_spirit_id", Callable(CombatPressureTests, "_t_guide_authoritative_spirit_id"))
	runner.register_test("movement/pressure/unknown_and_pursue_engage", Callable(CombatPressureTests, "_t_unknown_and_pursue_engage"))
	runner.register_test("movement/pressure/hostile_carrier_ordinary_only", Callable(CombatPressureTests, "_t_hostile_carrier_ordinary_only"))
	runner.register_test("movement/pressure/exact_goal_semantics", Callable(CombatPressureTests, "_t_exact_goal_semantics"))
	runner.register_test("movement/pressure/exact_mode_alignment_matrix", Callable(CombatPressureTests, "_t_exact_mode_alignment_matrix"))
	runner.register_test("movement/pressure/pursue_fallback_intercept_and_reverse", Callable(CombatPressureTests, "_t_pursue_fallback_intercept_and_reverse"))
	runner.register_test("movement/pressure/guide_dead_ko", Callable(CombatPressureTests, "_t_guide_dead_ko"))
	runner.register_test("movement/pressure/pressure_covariance", Callable(CombatPressureTests, "_t_pressure_covariance"))
	# V2-COMBAT-002 Slice 6 Phase 6A — data.combat.movement.pressure config seam.
	runner.register_test("movement/pressure/config_defaults_match_constants", Callable(CombatPressureTests, "_t_config_defaults_match_constants"))
	runner.register_test("movement/pressure/config_collapse_health_seam", Callable(CombatPressureTests, "_t_config_collapse_health_seam"))
	runner.register_test("movement/pressure/config_fallback_radius_seam", Callable(CombatPressureTests, "_t_config_fallback_radius_seam"))
	runner.register_test("movement/pressure/config_intercept_lane_seam", Callable(CombatPressureTests, "_t_config_intercept_lane_seam"))
	runner.register_test("movement/pressure/config_degenerate_values_safe", Callable(CombatPressureTests, "_t_config_degenerate_values_safe"))
	runner.register_test("movement/pressure/config_balance_wired", Callable(CombatPressureTests, "_t_config_balance_wired"))


static func _t_all_modes_party_hostile() -> Dictionary:
	for mode_value: Variant in PressureContract.MODES:
		var mode: String = str(mode_value)
		for alignment: String in ["party", "hostile"]:
			var context: Dictionary = _context(mode, alignment)
			var result: Dictionary = Service.build_goals(context)
			if not bool(result["valid"]):
				return _fail("%s/%s rejected: %s" % [mode, alignment, str(result)])
			if (result["goals"] as Array).size() > 3:
				return _fail("%s/%s exceeded goal cap" % [mode, alignment])
			for goal_value: Variant in result["goals"] as Array:
				var goal: Dictionary = goal_value as Dictionary
				if not bool(GoalContract.validate(goal, context["origin"] as Dictionary)["valid"]):
					return _fail("%s/%s emitted invalid goal" % [mode, alignment])
	return _pass()


static func _t_objective_actor_modes() -> Dictionary:
	var quarry_context: Dictionary = _context("pursue", "objective", "quarry")
	var quarry_result: Dictionary = Service.build_goals(quarry_context)
	if not bool(quarry_result["valid"]):
		return _fail("objective quarry rejected: %s" % str(quarry_result))
	if not _has_goal(quarry_result, "withdraw", "quarry"):
		return _fail("objective quarry did not receive factual withdraw")
	var spirit_context: Dictionary = _context("guide_spirit", "objective", "spirit")
	var spirit_result: Dictionary = Service.build_goals(spirit_context)
	if not bool(spirit_result["valid"]):
		return _fail("nonjoining objective spirit rejected: %s" % str(spirit_result))
	if not _has_goal(spirit_result, "advance", "spirit"):
		return _fail("nonjoining spirit did not receive dormant advance")
	return _pass()


static func _t_unknown_objective_search_only() -> Dictionary:
	var context: Dictionary = _context("purify_shrine", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["objective_known"] = false
	pressure["objective_position"] = {}
	pressure["destination_region"] = []
	pressure["approach_region"] = []
	pressure["fallback_region"] = []
	pressure["search_region"] = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	pressure["objective_health_ratio"] = -1.0
	(context["perceived_actors"] as Array).remove_at(2)
	(context["occupancy"] as Dictionary).erase("3,3")
	(context["relationships"] as Dictionary).erase("objective.relic")
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("unknown shrine search rejected: %s" % str(result))
	var goals: Array = result["goals"] as Array
	if not _has_goal(result, "read", "baseline") or not _has_goal(result, "engage", "baseline"):
		return _fail("unknown shrine did not retain both search and truthful engage: %s" % str(goals))
	if float(_goal(result, "read")["urgency"]) != 0.25:
		return _fail("unknown search did not use low urgency")
	return _pass()


static func _t_purify_threshold_and_plans() -> Dictionary:
	var purifier: Dictionary = _context("purify_shrine", "party", "purifier")
	var pressure: Dictionary = purifier["objective_pressure"] as Dictionary
	pressure["objective_health_ratio"] = 0.49
	var result: Dictionary = Service.build_goals(purifier)
	if not bool(result["valid"]):
		return _fail("low-shrine purifier rejected: %s" % str(result))
	var advance: Dictionary = _goal(result, "advance")
	if advance.is_empty() or str((advance["planned_primary"] as Dictionary)["type"]) != "actor.purify_shrine":
		return _fail("low-shrine purifier did not carry explicit purify plan")
	var healthy: Dictionary = _context("purify_shrine", "party")
	(healthy["objective_pressure"] as Dictionary)["objective_health_ratio"] = 0.5
	var healthy_result: Dictionary = Service.build_goals(healthy)
	if not bool(healthy_result["valid"]) or _has_goal(healthy_result, "protect", "protector"):
		return _fail("healthy shrine produced low-health protection pressure")
	return _pass()


static func _t_recover_roles_and_relic_safety() -> Dictionary:
	var holder: Dictionary = _context("recover", "party", "holder")
	(holder["origin"] as Dictionary).assign({"col": 2, "row": 2})
	var mover: Dictionary = (holder["perceived_actors"] as Array)[0] as Dictionary
	mover["position"] = {"col": 2, "row": 2}
	(holder["occupancy"] as Dictionary).erase("1,2")
	(holder["occupancy"] as Dictionary)["2,2"] = "echo.mover"
	var holder_result: Dictionary = Service.build_goals(holder)
	if not bool(holder_result["valid"]) or not _has_goal(holder_result, "hold", "holder"):
		return _fail("adjacent authoritative holder did not hold")
	var hostile: Dictionary = _context("recover", "hostile")
	var hostile_result: Dictionary = Service.build_goals(hostile)
	if not bool(hostile_result["valid"]):
		return _fail("hostile recover pressure rejected")
	for goal_value: Variant in hostile_result["goals"] as Array:
		var plan: Dictionary = (goal_value as Dictionary)["planned_primary"] as Dictionary
		if str(plan["type"]) == "melee_attack" and str(plan["target_id"]) == "objective.relic":
			return _fail("RECOVER hostile planned damage against invulnerable relic")
	var holder_pressure: Dictionary = _goal(hostile_result, "advance")
	if holder_pressure.is_empty() or str((holder_pressure["planned_primary"] as Dictionary)["target_id"]) != "echo.1":
		return _fail("RECOVER hostile did not explicitly pressure perceived holder")
	return _pass()


static func _t_protect_stolen_carrier() -> Dictionary:
	var context: Dictionary = _context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["totem_stolen"] = true
	pressure["carrier_id"] = "enemy.1"
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("stolen carrier pressure rejected: %s" % str(result))
	var pursue: Dictionary = _goal(result, "pursue")
	if pursue.is_empty() or str((pursue["planned_primary"] as Dictionary)["target_id"]) != "enemy.1":
		return _fail("stolen carrier was not exact pursuit target")
	if not str(pursue["goal_id"]).contains(".hunter."):
		return _fail("carrier pursuit lacked hunter candidate semantics")
	return _pass()


static func _t_pursue_far_end() -> Dictionary:
	var context: Dictionary = _context("pursue", "objective", "quarry")
	(context["objective_pressure"] as Dictionary)["destination_region"] = [{"col": 5, "row": 2}]
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("quarry pressure rejected")
	var withdraw: Dictionary = _goal(result, "withdraw")
	if withdraw.is_empty():
		return _fail("quarry withdraw missing")
	if (withdraw["destination_region"] as Array).has(context["origin"]):
		return _fail("quarry far-end region included current cell")
	if (withdraw["destination_region"] as Array) != [{"col": 5, "row": 2}]:
		return _fail("quarry did not use caller-supplied far-end region")
	return _pass()


static func _t_guide_join_boundary() -> Dictionary:
	var nonjoining: Dictionary = _context("guide_spirit", "objective", "spirit")
	var nonjoining_result: Dictionary = Service.build_goals(nonjoining)
	if not _has_goal(nonjoining_result, "advance", "spirit"):
		return _fail("nonjoining spirit missing dormant objective-phase plan")
	var joined: Dictionary = _context("guide_spirit", "party", "spirit")
	(joined["objective_pressure"] as Dictionary)["spirit_joins_battle"] = true
	var joined_result: Dictionary = Service.build_goals(joined)
	if not bool(joined_result["valid"]):
		return _fail("joined spirit rejected: %s" % str(joined_result))
	for goal_value: Variant in joined_result["goals"] as Array:
		if str((goal_value as Dictionary)["purpose"]) == "escort":
			return _fail("joined spirit self-escorted")
	var escort_party: Dictionary = _context("guide_spirit", "party")
	var escort_result: Dictionary = Service.build_goals(escort_party)
	if not _has_goal(escort_result, "escort", "protector"):
		return _fail("escort party did not receive escort purpose")
	return _pass()


static func _t_canonical_reversal() -> Dictionary:
	var context_a: Dictionary = _context("recover", "party")
	var context_b: Dictionary = _reverse_dictionary(context_a)
	var pressure_a: Dictionary = context_a["objective_pressure"] as Dictionary
	var reversed_region: Array = (pressure_a["destination_region"] as Array).duplicate(true)
	reversed_region.reverse()
	context_b["objective_pressure"] = _rebuild_pressure(pressure_a, reversed_region)
	(context_b["perceived_actors"] as Array).reverse()
	var result_a: Dictionary = Service.build_goals(context_a)
	context_b["relationships"] = _reverse_dictionary(context_a["relationships"] as Dictionary)
	context_b["occupancy"] = _reverse_dictionary(context_a["occupancy"] as Dictionary)
	var reversed_actors: Array = []
	for actor_value: Variant in context_b["perceived_actors"] as Array:
		reversed_actors.append(_reverse_dictionary(actor_value as Dictionary))
	context_b["perceived_actors"] = reversed_actors
	var result_b: Dictionary = Service.build_goals(context_b)
	if result_a != result_b:
		return _fail("reversed insertion order changed pressure result:\n%s\n%s" % [str(result_a), str(result_b)])
	return _pass()


static func _t_numeric_region_order() -> Dictionary:
	var plan := {"type": "actor.guard", "target_id": "", "payload": {}}
	var fallback := {"type": "actor.idle", "target_id": "", "payload": {}}
	var goal_10: Dictionary = GoalContract.build(
		"goal.protect.intercept.blocker.c10r0", "intercept", [{"col": 10, "row": 0}],
		0.75, 0.0, [], ["mode.protect", "role.blocker"], plan, fallback
	)
	var goal_2: Dictionary = GoalContract.build(
		"goal.protect.intercept.blocker.c2r0", "intercept", [{"col": 2, "row": 0}],
		0.75, 0.0, [], ["mode.protect", "role.blocker"], plan, fallback
	)
	var forward: Array = [{"bucket": "tactical", "goal": goal_10}, {"bucket": "tactical", "goal": goal_2}]
	var reversed: Array = forward.duplicate(true)
	reversed.reverse()
	forward.sort_custom(Callable(Service, "_candidate_before"))
	reversed.sort_custom(Callable(Service, "_candidate_before"))
	if forward != reversed:
		return _fail("numeric region sort changed under reversed insertion")
	if str(((forward[0] as Dictionary)["goal"] as Dictionary)["goal_id"]) != "goal.protect.intercept.blocker.c2r0":
		return _fail("numeric region comparator placed c10 before c2")
	return _pass()


static func _t_perceived_truth_and_sources() -> Dictionary:
	var context: Dictionary = _context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["pressure_sources"] = ["state.authored_fixture"]
	(context["perceived_planning_cells"] as Dictionary)["2,3"] = false
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("truth filtering rejected context: %s" % str(result))
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if (goal["destination_region"] as Array).has({"col": 2, "row": 3}):
			return _fail("goal retained unperceived destination cell")
		if not (goal["pressure_sources"] as Array).has("state.authored_fixture"):
			return _fail("valid authored pressure source was dropped")
	var invalid: Dictionary = _context("combat", "party")
	(invalid["objective_pressure"] as Dictionary)["pressure_sources"] = ["hidden.omniscient"]
	var invalid_result: Dictionary = Service.build_goals(invalid)
	if bool(invalid_result["valid"]) or str(invalid_result["reason"]) != "invalid_pressure_source":
		return _fail("non-grammar pressure source was not rejected")
	return _pass()


static func _t_factual_role_crosschecks() -> Dictionary:
	var mismatch: Dictionary = _context("recover", "party", "holder")
	(mismatch["objective_pressure"] as Dictionary)["holder_id"] = "echo.someone_else"
	var mismatch_result: Dictionary = Service.build_goals(mismatch)
	if bool(mismatch_result["valid"]) or str(mismatch_result["reason"]) != "factual_role_mover_mismatch":
		return _fail("factual holder role accepted for another mover")
	var contradictory: Dictionary = _context("protect", "party", "holder")
	(contradictory["objective_pressure"] as Dictionary)["carrier_id"] = "echo.mover"
	var contradictory_result: Dictionary = Service.build_goals(contradictory)
	if bool(contradictory_result["valid"]) or str(contradictory_result["reason"]) != "contradictory_factual_roles":
		return _fail("multiple factual roles for mover were accepted")
	return _pass()


static func _t_cap_complete_and_progress() -> Dictionary:
	var context: Dictionary = _context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["progress_current"] = 3
	pressure["progress_required"] = 2
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("complete candidate fixture rejected")
	var goals: Array = result["goals"] as Array
	if goals.size() > 3:
		return _fail("goal cap exceeded")
	for goal_value: Variant in goals:
		var goal: Dictionary = goal_value as Dictionary
		if float(goal["objective_progress"]) != 1.0:
			return _fail("objective progress did not clamp")
		if (goal["planned_primary"] as Dictionary).is_empty():
			return _fail("incomplete primary plan emitted")
		if not str(goal["goal_id"]).begins_with("goal.protect."):
			return _fail("unstable goal ID emitted")
	return _pass()


static func _t_objective_alignment_gate() -> Dictionary:
	for mode: String in ["combat", "purify_shrine", "recover", "protect", "endure"]:
		var context: Dictionary = _context(mode, "objective")
		var result: Dictionary = Service.build_goals(context)
		if not bool(result["valid"]) or not (result["goals"] as Array).is_empty():
			return _fail("unauthored objective mover received %s goals: %s" % [mode, str(result)])
	var joined_objective: Dictionary = _context("guide_spirit", "objective", "spirit")
	(joined_objective["objective_pressure"] as Dictionary)["spirit_joins_battle"] = true
	var joined_objective_result: Dictionary = Service.build_goals(joined_objective)
	if not bool(joined_objective_result["valid"]) or not (joined_objective_result["goals"] as Array).is_empty():
		return _fail("joined spirit remained objective-aligned")
	return _pass()


static func _t_all_hostiles_blocked_first() -> Dictionary:
	var context: Dictionary = _context("combat", "party")
	var blocked: Dictionary = _actor("enemy.0", {"col": 0, "row": 0}, "enemy")
	(context["perceived_actors"] as Array).append(blocked)
	(context["relationships"] as Dictionary)["enemy.0"] = "hostile"
	(context["occupancy"] as Dictionary)["0,0"] = "enemy.0"
	for key: String in ["0,1", "1,0", "1,1"]:
		(context["perceived_planning_cells"] as Dictionary)[key] = false
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("blocked-first hostile fixture rejected: %s" % str(result))
	var engage: Dictionary = _goal(result, "engage")
	if engage.is_empty() or str((engage["planned_primary"] as Dictionary)["target_id"]) != "enemy.1":
		return _fail("blocked first hostile suppressed later truthful hostile")
	return _pass()


static func _t_guide_authoritative_spirit_id() -> Dictionary:
	var context: Dictionary = _context("guide_spirit", "hostile")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	if str(pressure["objective_id"]) == str(pressure["spirit_id"]):
		return _fail("fixture failed to separate objective and spirit IDs")
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("GUIDE hostile fixture rejected: %s" % str(result))
	for purpose: String in ["advance", "engage"]:
		var goal: Dictionary = _goal(result, purpose)
		if not goal.is_empty() and str((goal["planned_primary"] as Dictionary)["target_id"]) == "objective.relic":
			return _fail("GUIDE hostile targeted objective_id instead of spirit_id")
	var advance: Dictionary = _goal(result, "advance")
	if advance.is_empty() or str((advance["planned_primary"] as Dictionary)["target_id"]) != "guide.spirit":
		return _fail("GUIDE hostile advance did not target authoritative spirit")
	return _pass()


static func _t_unknown_and_pursue_engage() -> Dictionary:
	var context: Dictionary = _context("pursue", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["objective_known"] = false
	pressure["objective_position"] = {}
	pressure["destination_region"] = []
	pressure["approach_region"] = []
	pressure["fallback_region"] = []
	pressure["quarry_id"] = ""
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]) or not _has_goal(result, "engage", "baseline"):
		return _fail("unknown PURSUE did not retain truthful combat-safety engage")
	return _pass()


static func _t_hostile_carrier_ordinary_only() -> Dictionary:
	var context: Dictionary = _context("protect", "hostile", "carrier")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["totem_stolen"] = true
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("hostile carrier fixture rejected: %s" % str(result))
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if not str(goal["goal_id"]).contains(".baseline.") or str(goal["goal_id"]).contains("custody_threat"):
			return _fail("hostile carrier received deferred custody/carry semantics")
		if not str(goal["purpose"]) in ["advance", "engage"]:
			return _fail("hostile carrier received non-ordinary purpose")
	return _pass()


static func _t_exact_goal_semantics() -> Dictionary:
	var context: Dictionary = _context("protect", "party")
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("exact semantics fixture rejected")
	var protect: Dictionary = _goal(result, "protect")
	if protect.is_empty() or float(protect["urgency"]) != 0.75:
		return _fail("protect role/urgency missing")
	if str(protect["goal_id"]) != "goal.protect.protect.protector.c2r3":
		return _fail("protect stable ID mismatch: %s" % str(protect.get("goal_id", "")))
	var primary: Dictionary = protect["planned_primary"] as Dictionary
	var fallback: Dictionary = protect["declared_fallback"] as Dictionary
	if primary != {"type": "actor.guard", "target_id": "", "payload": {}}:
		return _fail("structure protection did not use exact guard plan")
	if fallback != {"type": "actor.idle", "target_id": "", "payload": {}}:
		return _fail("protect fallback was not explicit idle")
	for source: String in ["mode.protect", "objective.objective.relic", "role.protector"]:
		if not (protect["pressure_sources"] as Array).has(source):
			return _fail("protect source missing: %s" % source)
	return _pass()


static func _t_exact_mode_alignment_matrix() -> Dictionary:
	var enemy_region: Array = [
		{"col": 3, "row": 1}, {"col": 3, "row": 2}, {"col": 4, "row": 1},
		{"col": 4, "row": 3}, {"col": 5, "row": 1}, {"col": 5, "row": 2},
		{"col": 5, "row": 3},
	]
	var objective_region: Array = [
		{"col": 2, "row": 2}, {"col": 2, "row": 3}, {"col": 2, "row": 4},
		{"col": 3, "row": 2}, {"col": 3, "row": 4}, {"col": 4, "row": 3},
		{"col": 4, "row": 4},
	]
	var spirit_region: Array = [
		{"col": 2, "row": 3}, {"col": 2, "row": 4}, {"col": 2, "row": 5},
		{"col": 3, "row": 5}, {"col": 4, "row": 3}, {"col": 4, "row": 4},
		{"col": 4, "row": 5},
	]
	var destination_region: Array = [{"col": 2, "row": 3}, {"col": 3, "row": 2}, {"col": 4, "row": 3}]
	var approach_region: Array = [{"col": 2, "row": 2}, {"col": 3, "row": 1}]
	# V2-COMBAT-002 Slice 4 (§13.6): PURSUE cutoff TARGETING is now projected from
	# the quarry's traversable escape graph, so the authored fallback_region
	# ([{0,2}]) no longer describes the cut_off destination. This is the corridor
	# the quarry must actually cross to reach the escape BAND, filtered to the
	# cells this mover can reach no later than the quarry.
	#
	# Board 6x6 (square -> band = rows 4 and 5). Quarry (4,2), mover (1,2),
	# structure blocker (3,3). The quarry reaches the band in 2 steps, so the
	# corridor is {(4,3),(5,3),(3,4),(4,4),(5,4)}; of those only (3,4) is reachable
	# by the mover in <= 2 steps ((1,2)->(2,3)->(3,4)), so it is the sole
	# interception cell.
	#
	# This SHRANK when escape targeting was corrected from the far-end LINE to the
	# `>= max-1` BAND that `is_escaped` actually wins on. The old expectation
	# ([{2,5},{3,4},{3,5},{4,5}]) projected routes to row 5 — one row deeper than
	# the quarry ever needs to travel — so it named cells that are irrelevant to
	# the real race.
	var pursue_cutoff_corridor: Array = [{"col": 3, "row": 4}]
	var matrix: Array = [
		["combat", "party", [["advance", "baseline", "enemy.1", 0.75, enemy_region, ["enemy.1"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["combat", "hostile", [["advance", "baseline", "echo.1", 0.75, enemy_region, ["echo.1"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]]]],
		["purify_shrine", "party", [["intercept", "blocker", "", 0.75, approach_region, ["objective.relic"]], ["protect", "protector", "", 0.75, destination_region, ["objective.relic"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["purify_shrine", "hostile", [["advance", "breaker", "objective.relic", 0.75, approach_region, ["objective.relic"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]], ["engage", "breaker", "objective.relic", 0.50, objective_region, ["objective.relic"]]]],
		["recover", "party", [["advance", "runner", "objective.relic", 1.0, destination_region, ["objective.relic"]], ["intercept", "screener", "", 0.75, approach_region, ["objective.relic"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["recover", "hostile", [["advance", "breaker", "echo.1", 1.0, enemy_region, ["echo.1"]], ["intercept", "blocker", "", 0.75, approach_region, ["objective.relic"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]]]],
		["protect", "party", [["intercept", "blocker", "", 0.75, approach_region, ["objective.relic"]], ["protect", "protector", "", 0.75, destination_region, ["objective.relic"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["protect", "hostile", [["advance", "custody_threat", "objective.relic", 1.0, destination_region, ["objective.relic"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]], ["engage", "breaker", "objective.relic", 0.50, objective_region, ["objective.relic"]]]],
		["endure", "party", [["advance", "baseline", "enemy.1", 0.75, enemy_region, ["enemy.1"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["endure", "hostile", [["advance", "baseline", "echo.1", 0.75, enemy_region, ["echo.1"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]]]],
		["pursue", "party", [["pursue", "hunter", "enemy.1", 1.0, enemy_region, ["enemy.1"]], ["cut_off", "blocker", "", 0.75, pursue_cutoff_corridor, ["enemy.1"]]]],
		["pursue", "hostile", []],
		["guide_spirit", "party", [["escort", "protector", "guide.spirit", 0.75, destination_region, ["guide.spirit"]], ["intercept", "rear_guard", "", 0.75, approach_region, ["guide.spirit"]], ["engage", "baseline", "enemy.1", 0.50, enemy_region, ["enemy.1"]]]],
		["guide_spirit", "hostile", [["advance", "escort_threat", "guide.spirit", 1.0, destination_region, ["guide.spirit"]], ["engage", "baseline", "echo.1", 0.50, enemy_region, ["echo.1"]], ["engage", "breaker", "guide.spirit", 0.50, spirit_region, ["guide.spirit"]]]],
	]
	for case_value: Variant in matrix:
		var case: Array = case_value as Array
		var context: Dictionary = _context(str(case[0]), str(case[1]))
		var result: Dictionary = Service.build_goals(context)
		if not bool(result["valid"]):
			return _fail("matrix case rejected %s/%s: %s" % [str(case[0]), str(case[1]), str(result)])
		var expected: Array = case[2] as Array
		var goals: Array = result["goals"] as Array
		if goals.size() != expected.size():
			return _fail("matrix size mismatch %s/%s: %s" % [str(case[0]), str(case[1]), str(goals)])
		for index: int in range(expected.size()):
			var goal: Dictionary = goals[index] as Dictionary
			var semantic: Array = expected[index] as Array
			var role: String = str(goal["goal_id"]).split(".")[3]
			var plan: Dictionary = goal["planned_primary"] as Dictionary
			if [str(goal["purpose"]), role, str(plan["target_id"]), float(goal["urgency"])] != semantic.slice(0, 4):
				return _fail("matrix projection mismatch %s/%s[%d]: %s" % [str(case[0]), str(case[1]), index, str(goal)])
			var exact_result: Dictionary = _assert_exact_goal(context, goal, semantic[4] as Array, semantic[5] as Array)
			if not bool(exact_result["ok"]):
				return exact_result
	var quarry_result: Dictionary = Service.build_goals(_context("pursue", "objective", "quarry"))
	if not _has_goal(quarry_result, "withdraw", "quarry") or (quarry_result["goals"] as Array).size() != 1:
		return _fail("matrix objective quarry missing")
	var quarry_context: Dictionary = _context("pursue", "objective", "quarry")
	var quarry_exact: Dictionary = _assert_exact_goal(quarry_context, (quarry_result["goals"] as Array)[0] as Dictionary, destination_region, [])
	if not bool(quarry_exact["ok"]):
		return quarry_exact
	var spirit_context: Dictionary = _context("guide_spirit", "objective", "spirit")
	var spirit_result: Dictionary = Service.build_goals(spirit_context)
	if not _has_goal(spirit_result, "advance", "spirit") or (spirit_result["goals"] as Array).size() != 1:
		return _fail("matrix objective spirit missing")
	var spirit_exact: Dictionary = _assert_exact_goal(spirit_context, (spirit_result["goals"] as Array)[0] as Dictionary, destination_region, ["objective.relic"])
	if not bool(spirit_exact["ok"]):
		return spirit_exact
	return _pass()


static func _t_pursue_fallback_intercept_and_reverse() -> Dictionary:
	var fallback_context: Dictionary = _context("pursue", "party")
	_add_second_hostile(fallback_context)
	var fallback_result: Dictionary = Service.build_goals(fallback_context)
	if not bool(fallback_result["valid"]) or not _has_goal(fallback_result, "cut_off", "blocker"):
		return _fail("PURSUE fallback region did not emit cut_off")
	if _has_goal(fallback_result, "intercept", "blocker"):
		return _fail("PURSUE fallback region also emitted intercept")
	var safety: Dictionary = _goal(fallback_result, "engage")
	if safety.is_empty() or str((safety["planned_primary"] as Dictionary)["target_id"]) != "enemy.2":
		return _fail("PURSUE did not retain separate-hostile safety engage")
	# V2-COMBAT-002 Slice 4 (§13.6): with a live quarry the escape-graph corridor is
	# the cutoff target whether or not the authority authored a fallback_region, so
	# removing that region no longer demotes cut_off to a geometric intercept.
	var no_fallback: Dictionary = _context("pursue", "party")
	_add_second_hostile(no_fallback)
	(no_fallback["objective_pressure"] as Dictionary)["fallback_region"] = []
	var no_fallback_result: Dictionary = Service.build_goals(no_fallback)
	if not bool(no_fallback_result["valid"]) or not _has_goal(no_fallback_result, "cut_off", "blocker"):
		return _fail("PURSUE without fallback did not emit projected cut_off")
	if _has_goal(no_fallback_result, "intercept", "blocker"):
		return _fail("PURSUE with a projectable corridor fell back to geometric intercept")
	# The geometric approach lane remains the last resort: with no quarry left to
	# project a corridor from, PURSUE still emits the authored intercept.
	var no_corridor: Dictionary = _context("pursue", "party")
	_add_second_hostile(no_corridor)
	(no_corridor["objective_pressure"] as Dictionary)["fallback_region"] = []
	for actor_value: Variant in no_corridor["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == "enemy.1":
			actor["is_dead"] = true
	var no_corridor_result: Dictionary = Service.build_goals(no_corridor)
	if not bool(no_corridor_result["valid"]) or not _has_goal(no_corridor_result, "intercept", "blocker"):
		return _fail("PURSUE without a projectable corridor did not emit intercept")
	if _has_goal(no_corridor_result, "cut_off", "blocker"):
		return _fail("PURSUE without a projectable corridor emitted cut_off")
	var reversed: Dictionary = no_fallback.duplicate(true)
	(reversed["perceived_actors"] as Array).reverse()
	reversed["relationships"] = _reverse_dictionary(no_fallback["relationships"] as Dictionary)
	reversed["occupancy"] = _reverse_dictionary(no_fallback["occupancy"] as Dictionary)
	if Service.build_goals(reversed) != no_fallback_result:
		return _fail("reversed PURSUE facts changed cutoff/intercept result")
	return _pass()


static func _t_guide_dead_ko() -> Dictionary:
	for alignment: String in ["party", "hostile"]:
		for state_field: String in ["is_dead", "is_ko"]:
			var context: Dictionary = _context("guide_spirit", alignment)
			_actor_ref(context, "guide.spirit")[state_field] = true
			var result: Dictionary = Service.build_goals(context)
			if not bool(result["valid"]):
				return _fail("GUIDE %s %s spirit rejected context" % [alignment, state_field])
			for goal_value: Variant in result["goals"] as Array:
				var goal: Dictionary = goal_value as Dictionary
				if (goal["relevant_actors"] as Array).has("guide.spirit"):
					return _fail("GUIDE %s %s targeted inactive spirit" % [alignment, state_field])
			if not _has_goal(result, "engage", "baseline"):
				return _fail("GUIDE %s %s lost unrelated truthful engage" % [alignment, state_field])
	for state_field: String in ["is_dead", "is_ko"]:
		var objective: Dictionary = _context("guide_spirit", "objective", "spirit")
		_actor_ref(objective, "objective.mover")[state_field] = true
		var objective_result: Dictionary = Service.build_goals(objective)
		if not bool(objective_result["valid"]) or not (objective_result["goals"] as Array).is_empty():
			return _fail("inactive objective spirit mover did not return authored empty")
	return _pass()


static func _t_pressure_covariance() -> Dictionary:
	var original: Dictionary = _context("protect", "party")
	var original_result: Dictionary = Service.build_goals(original)
	for transform_name: String in ["horizontal", "vertical", "transpose"]:
		var transformed: Dictionary = _transform_context(original, transform_name)
		var transformed_result: Dictionary = Service.build_goals(transformed)
		if not bool(transformed_result["valid"]):
			return _fail("%s pressure transform rejected: %s" % [transform_name, str(transformed_result)])
		var covariance: Dictionary = _assert_covariant(original_result, transformed_result, transform_name)
		if not bool(covariance["ok"]):
			return covariance
	return _pass()


# ---------------------------------------------------------------------------
# V2-COMBAT-002 Slice 6 Phase 6A — `data.combat.movement.pressure` config seam.
#
# The seam is an OPTIONAL trailing argument on `build_goals`. These tests pin
# three separate properties, because they can fail independently:
#   1. an ABSENT block reproduces the frozen Slice 4 constants exactly;
#   2. a PRESENT block is actually read (each key changes observable output);
#   3. a DEGENERATE block neither crashes nor silently empties a region.
# ---------------------------------------------------------------------------


## The full block, stated explicitly at the frozen constant values. Passing this
## must be indistinguishable from passing nothing.
static func _explicit_default_cfg() -> Dictionary:
	return {
		"collapse_health": Service.COLLAPSE_HEALTH,
		"fallback_radius": Service.FALLBACK_RADIUS,
		"intercept_lane_inner_band": Service.INTERCEPT_LANE_INNER_BAND,
		"intercept_lane_radius": Service.INTERCEPT_LANE_RADIUS,
	}


## Property 1 — an absent block is exactly today's behaviour, across every mode
## and alignment, and matches the block stated explicitly at the constants.
static func _t_config_defaults_match_constants() -> Dictionary:
	var explicit: Dictionary = _explicit_default_cfg()
	for mode_value: Variant in PressureContract.MODES:
		var mode: String = str(mode_value)
		for alignment: String in ["party", "hostile"]:
			var absent: Dictionary = Service.build_goals(_context(mode, alignment))
			var empty_block: Dictionary = Service.build_goals(_context(mode, alignment), {})
			var stated: Dictionary = Service.build_goals(_context(mode, alignment), explicit)
			if absent != empty_block:
				return _fail("%s/%s: empty config block diverged from omitted argument" % [mode, alignment])
			if absent != stated:
				return _fail("%s/%s: explicit constants diverged from defaults" % [mode, alignment])
	# Same claim on the collapse path, which the healthy fixture above never reaches.
	var collapsing: Dictionary = _collapsing_context(Service.COLLAPSE_HEALTH)
	if Service.build_goals(collapsing) != Service.build_goals(_collapsing_context(Service.COLLAPSE_HEALTH), explicit):
		return _fail("collapse path: explicit constants diverged from defaults")
	return _pass()


## Property 2a — `collapse_health` gates the board fall-back and is read from config.
## A mover at 0.6 health is ABOVE the frozen 0.5 band, so it must not fall back by
## default, and must fall back once config raises the band past it.
static func _t_config_collapse_health_seam() -> Dictionary:
	if not _goal(Service.build_goals(_collapsing_context(0.6)), "withdraw").is_empty():
		return _fail("0.6 health fell back under the default 0.5 collapse band")
	var raised: Dictionary = Service.build_goals(_collapsing_context(0.6), {"collapse_health": 0.75})
	if _goal(raised, "withdraw").is_empty():
		return _fail("config collapse_health 0.75 was not read: no withdraw at 0.6 health")
	# ...and lowering it below a collapsing mover suppresses the fall-back.
	var lowered: Dictionary = Service.build_goals(_collapsing_context(0.4), {"collapse_health": 0.25})
	if not _goal(lowered, "withdraw").is_empty():
		return _fail("config collapse_health 0.25 was not read: withdraw at 0.4 health")
	# A collapsing mover DOES fall back by default — otherwise the two checks
	# above would pass vacuously on a fixture that can never produce a withdraw.
	if _goal(Service.build_goals(_collapsing_context(0.4)), "withdraw").is_empty():
		return _fail("fixture cannot produce a withdraw at all; seam checks are vacuous")
	return _pass()


## Property 2b — `fallback_radius` bounds the search for safer ground. A tighter
## radius must yield a strictly smaller, non-empty region that is a subset of the
## default one.
static func _t_config_fallback_radius_seam() -> Dictionary:
	var default_region: Array = _withdraw_region(Service.build_goals(_collapsing_context(0.4)))
	if default_region.is_empty():
		return _fail("default fallback region empty; seam check would be vacuous")
	var tight_region: Array = _withdraw_region(
		Service.build_goals(_collapsing_context(0.4), {"fallback_radius": 1})
	)
	if tight_region.is_empty():
		return _fail("fallback_radius 1 silently emptied the region")
	if tight_region.size() >= default_region.size():
		return _fail("fallback_radius 1 did not narrow the region: %s" % str(tight_region))
	for cell_value: Variant in tight_region:
		if not default_region.has(cell_value):
			return _fail("tight region left the default region: %s" % str(cell_value))
	return _pass()


## Property 2c — the interception-lane band. BOTH ends are seamed: the outer
## radius (already named) and the inner band (previously an unnamed literal 2 at
## the `_lane_or_authored` call site).
static func _t_config_intercept_lane_seam() -> Dictionary:
	var default_lane: Array = _lane_region(_lane_context())
	if default_lane.is_empty():
		return _fail("default derived lane empty; seam check would be vacuous")
	# Inner band 1 turns the lane into a close screen — a different band, so a
	# different region. This is the literal the carry-forward list missed.
	var inner_lane: Array = _lane_region(_lane_context(), {"intercept_lane_inner_band": 1})
	if inner_lane.is_empty():
		return _fail("intercept_lane_inner_band 1 silently emptied the lane")
	if inner_lane == default_lane:
		return _fail("intercept_lane_inner_band was not read: lane unchanged")
	# Widening the outer radius can only add cells, never remove them.
	var wide_lane: Array = _lane_region(_lane_context(), {"intercept_lane_radius": 5})
	if wide_lane.size() < default_lane.size():
		return _fail("intercept_lane_radius 5 narrowed the lane")
	for cell_value: Variant in default_lane:
		if not wide_lane.has(cell_value):
			return _fail("widened lane lost a default cell: %s" % str(cell_value))
	return _pass()


## Property 3 — a degenerate block must degrade to a safe value, never crash and
## never silently produce an empty region. Zero and negative radii are the real
## hazard: they would make every derived region vanish while every call still
## reported `valid`.
static func _t_config_degenerate_values_safe() -> Dictionary:
	var degenerate: Array = [
		{},
		{"fallback_radius": 0},
		{"fallback_radius": -4},
		{"intercept_lane_radius": 0},
		{"intercept_lane_radius": -1},
		{"intercept_lane_inner_band": 0},
		{"intercept_lane_inner_band": -3},
		# Inner band above the outer band would make every membership test fail.
		{"intercept_lane_inner_band": 9, "intercept_lane_radius": 2},
		# Wrong-typed values are config typos, not tuning.
		{"fallback_radius": "3", "collapse_health": "0.5"},
		{"fallback_radius": null, "intercept_lane_radius": null},
		{"collapse_health": 2.5},
		{"collapse_health": -1.0},
		# Unknown keys must be ignored rather than disturbing anything.
		{"not_a_real_key": 99},
	]
	for cfg_value: Variant in degenerate:
		var cfg: Dictionary = cfg_value as Dictionary
		var fallback_result: Dictionary = Service.build_goals(_collapsing_context(0.4), cfg)
		if not bool(fallback_result["valid"]):
			return _fail("degenerate cfg %s rejected a valid context" % str(cfg))
		# `collapse_health` 0 legitimately disables the fall-back; every OTHER
		# degenerate value must still produce a region.
		if float(cfg.get("collapse_health", 1.0)) > 0.0:
			if _withdraw_region(fallback_result).is_empty():
				return _fail("degenerate cfg %s silently emptied the fallback region" % str(cfg))
		var lane: Array = _lane_region(_lane_context(), cfg)
		if lane.is_empty():
			return _fail("degenerate cfg %s silently emptied the lane region" % str(cfg))
	return _pass()


## The block must exist in the live balance.json at the documented values —
## otherwise the seam is real but unreachable. House `_t_balance_config_wired`
## idiom, matching MovementProfileTests / MovementHazardTests.
static func _t_config_balance_wired() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var movement_cfg: Dictionary = config.get_balance() \
		.get("data", {}) \
		.get("combat", {}) \
		.get("movement", {})
	var pressure_cfg: Dictionary = movement_cfg.get("pressure", {})
	if pressure_cfg.is_empty():
		return _fail("data.combat.movement.pressure missing from balance.json")
	var expected: Dictionary = _explicit_default_cfg()
	for key: String in expected:
		if not pressure_cfg.has(key):
			return _fail("pressure config missing key '%s'" % key)
		if not is_equal_approx(float(pressure_cfg[key]), float(expected[key])):
			return _fail("pressure config '%s' differs from the frozen constant" % key)
	# The authored block must be behaviourally identical to the defaults it seams.
	if Service.build_goals(_collapsing_context(0.4), pressure_cfg) != Service.build_goals(_collapsing_context(0.4)):
		return _fail("balance.json pressure block is not behaviourally identical to defaults")
	# Slack seam (decision 5): the keys must exist for the adapter to read in a
	# later unit, and must not WIDEN the MovementOption contract floor of 2 / 0.25.
	var slack_cfg: Dictionary = movement_cfg.get("slack", {})
	if slack_cfg.is_empty():
		return _fail("data.combat.movement.slack missing from balance.json")
	for key: String in ["floor", "fraction"]:
		if not slack_cfg.has(key):
			return _fail("slack config missing key '%s'" % key)
	if int(slack_cfg["floor"]) > 2 or float(slack_cfg["fraction"]) > 0.25:
		return _fail("slack config widens past the MovementOption contract floor (2 / 0.25)")
	return _pass()


## A `combat`/`party` context whose mover carries the given health ratio, so the
## board fall-back path is reachable. Everything else matches `_context`.
static func _collapsing_context(health_ratio: float) -> Dictionary:
	var context: Dictionary = _context("combat", "party")
	var mover: Dictionary = _actor_ref(context, "echo.mover")
	mover["health_ratio"] = health_ratio
	return context


## A `protect`/`party` context with the authored approach region REMOVED, which is
## the only condition under which `_lane_or_authored` derives a lane at all. The
## hostile is moved far enough from the protected actor that the default inner
## band of 2 still has a geodesic to stand on.
static func _lane_context() -> Dictionary:
	var context: Dictionary = _context("protect", "party")
	(context["objective_pressure"] as Dictionary)["approach_region"] = []
	var hostile: Dictionary = _actor_ref(context, "enemy.1")
	hostile["position"] = {"col": 0, "row": 0}
	var occupancy: Dictionary = context["occupancy"] as Dictionary
	occupancy.erase("4,2")
	occupancy["0,0"] = "enemy.1"
	return context


## The derived interception lane published for the given context/config, or [] if
## no intercept goal survived.
static func _lane_region(context: Dictionary, pressure_cfg: Dictionary = {}) -> Array:
	var intercept: Dictionary = _goal(Service.build_goals(context, pressure_cfg), "intercept")
	return [] if intercept.is_empty() else intercept["destination_region"] as Array


static func _withdraw_region(result: Dictionary) -> Array:
	var withdraw: Dictionary = _goal(result, "withdraw")
	return [] if withdraw.is_empty() else withdraw["destination_region"] as Array


static func _context(mode: String, alignment: String, role: String = "baseline") -> Dictionary:
	var mover_id: String = "echo.mover" if alignment == "party" else ("enemy.mover" if alignment == "hostile" else "objective.mover")
	var hostile_id: String = "enemy.1" if alignment == "party" else "echo.1"
	var mover_kind: String = "echo" if alignment == "party" else ("enemy" if alignment == "hostile" else "objective")
	var mover := _actor(mover_id, {"col": 1, "row": 2}, mover_kind)
	var enemy_kind: String = "enemy" if alignment == "party" else "echo"
	var enemy := _actor(hostile_id, {"col": 4, "row": 2}, enemy_kind)
	var objective_kind: String = "structure"
	var objective := _actor("objective.relic", {"col": 3, "row": 3}, objective_kind, true)
	var spirit := _actor("guide.spirit", {"col": 3, "row": 4}, "spirit")
	spirit["is_spirit"] = true
	if role == "quarry":
		mover["is_quarry"] = true
	if role == "spirit":
		mover["is_spirit"] = true
	if mode == "pursue" and role != "quarry":
		enemy["is_quarry"] = true
	var cells: Dictionary = {}
	for col: int in range(6):
		for row: int in range(6):
			cells["%d,%d" % [col, row]] = true
	var pressure: Dictionary = _pressure(mode, alignment, role, mover_id, hostile_id)
	var relationships := {
		mover_id: "friendly",
		hostile_id: "hostile",
		"objective.relic": "hostile" if alignment == "hostile" else "neutral",
	}
	var occupancy := {"1,2": mover_id, "4,2": hostile_id, "3,3": "objective.relic"}
	var actors: Array = [mover, enemy, objective]
	if mode == "guide_spirit":
		relationships["guide.spirit"] = "hostile" if alignment == "hostile" else "friendly"
		occupancy["3,4"] = "guide.spirit"
		actors.append(spirit)
	return ContextContract.build(
		mover_id, "activation.1", {"col": 1, "row": 2}, {"w": 6, "h": 6},
		cells, cells, occupancy, actors, relationships, {}, [], pressure, []
	)


static func _pressure(
	mode: String, alignment: String, role: String, mover_id: String, hostile_id: String
) -> Dictionary:
	var guide_mode: String = "escort" if mode == "guide_spirit" else ""
	var ids := {"purifier": "", "holder": "", "carrier": "", "quarry": "", "spirit": ""}
	if role != "baseline":
		ids[role] = mover_id
	if mode == "pursue" and role != "quarry":
		ids["quarry"] = hostile_id
	if mode == "guide_spirit" and role != "spirit":
		ids["spirit"] = "guide.spirit"
	if mode == "recover" and alignment == "hostile":
		ids["holder"] = hostile_id
	return PressureContract.build(
		mode, guide_mode, alignment, role, true, "objective.relic", {"col": 3, "row": 3},
		[{"col": 2, "row": 3}, {"col": 3, "row": 2}, {"col": 4, "row": 3}],
		[{"col": 2, "row": 2}, {"col": 3, "row": 1}],
		[{"col": 0, "row": 2}],
		[], str(ids["purifier"]), str(ids["holder"]), str(ids["carrier"]),
		str(ids["quarry"]), str(ids["spirit"]), 0.4, 1, 4, false, false, false, []
	)


static func _actor(id: String, position: Dictionary, kind: String, structure: bool = false) -> Dictionary:
	return {
		"id": id, "position": position, "kind": kind,
		"is_dead": false, "is_ko": false, "is_structure": structure,
		"is_spirit": false, "is_quarry": false, "controlling_state": false,
		"health_ratio": 1.0,
	}


static func _goal(result: Dictionary, purpose: String) -> Dictionary:
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if str(goal["purpose"]) == purpose:
			return goal
	return {}


static func _has_goal(result: Dictionary, purpose: String, role: String) -> bool:
	if not bool(result.get("valid", false)):
		return false
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if str(goal["purpose"]) == purpose and str(goal["goal_id"]).contains(".%s." % role):
			return true
	return false


static func _reverse_dictionary(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = value.keys()
	keys.reverse()
	for key_value: Variant in keys:
		result[key_value] = value[key_value]
	return result


static func _rebuild_pressure(value: Dictionary, destination_region: Array) -> Dictionary:
	return PressureContract.build(
		str(value["mode"]), str(value["guide_mode"]), str(value["mover_alignment"]),
		str(value["factual_role"]), bool(value["objective_known"]), str(value["objective_id"]),
		value["objective_position"] as Dictionary, destination_region,
		value["approach_region"] as Array, value["fallback_region"] as Array,
		value["search_region"] as Array, str(value["purifier_id"]), str(value["holder_id"]),
		str(value["carrier_id"]), str(value["quarry_id"]), str(value["spirit_id"]),
		float(value["objective_health_ratio"]), int(value["progress_current"]),
		int(value["progress_required"]), bool(value["escort_started"]),
		bool(value["spirit_joins_battle"]), bool(value["totem_stolen"]),
		value["pressure_sources"] as Array
	)


static func _assert_exact_goal(
	context: Dictionary, goal: Dictionary, expected_region: Array, expected_relevant_actors: Array
) -> Dictionary:
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	var parts: PackedStringArray = str(goal["goal_id"]).split(".")
	if parts.size() != 5:
		return _fail("goal ID segment count invalid: %s" % str(goal["goal_id"]))
	if goal["destination_region"] != expected_region:
		return _fail("goal destination region mismatch: %s" % str(goal))
	if goal["relevant_actors"] != expected_relevant_actors:
		return _fail("goal relevant actors mismatch: %s" % str(goal))
	var anchor: Dictionary = expected_region[0] as Dictionary
	var expected_id := "goal.%s.%s.%s.c%dr%d" % [
		str(pressure["mode"]), str(goal["purpose"]), str(parts[3]),
		int(anchor["col"]), int(anchor["row"]),
	]
	if str(goal["goal_id"]) != expected_id:
		return _fail("goal anchor ID mismatch: %s != %s" % [str(goal["goal_id"]), expected_id])
	var plan: Dictionary = goal["planned_primary"] as Dictionary
	var target_id: String = str(plan["target_id"])
	var expected_type: String = ""
	match str(goal["purpose"]):
		"advance", "reposition", "regroup", "withdraw": expected_type = "actor.move"
		"engage", "pursue": expected_type = "melee_attack"
		"intercept", "hold", "cut_off": expected_type = "actor.guard"
		"protect":
			var target: Dictionary = _actor_ref(context, str(expected_relevant_actors[0])) if not expected_relevant_actors.is_empty() else {}
			expected_type = "actor.guard" if target.is_empty() or bool(target.get("is_structure", false)) else "protect_ally"
		"read": expected_type = "actor.idle"
		"escort": expected_type = "protect_ally"
	if str(plan["type"]) != expected_type or not (plan["payload"] as Dictionary).is_empty():
		return _fail("goal exact primary plan mismatch: %s" % str(goal))
	if expected_type in ["actor.guard", "actor.idle"] and not target_id.is_empty():
		return _fail("targetless plan carried target ID")
	var fallback: Dictionary = goal["declared_fallback"] as Dictionary
	var expected_fallback: Dictionary = {} if expected_type == "actor.idle" else {"type": "actor.idle", "target_id": "", "payload": {}}
	if fallback != expected_fallback:
		return _fail("goal exact fallback mismatch: %s" % str(goal))
	var expected_sources: Array = (pressure["pressure_sources"] as Array).duplicate()
	expected_sources.append("mode.%s" % str(pressure["mode"]))
	expected_sources.append("role.%s" % str(parts[3]))
	for actor_id: Variant in expected_relevant_actors:
		expected_sources.append("actor.%s" % str(actor_id))
	if not str(pressure["objective_id"]).is_empty():
		expected_sources.append("objective.%s" % str(pressure["objective_id"]))
	if not bool(pressure["objective_known"]):
		expected_sources.append("state.objective_unknown")
	elif float(pressure["objective_health_ratio"]) >= 0.0 and float(pressure["objective_health_ratio"]) < 0.5:
		expected_sources.append("state.objective_low")
	if bool(pressure["totem_stolen"]):
		expected_sources.append("state.totem_stolen")
	if bool(pressure["escort_started"]):
		expected_sources.append("state.escort_started")
	if str(pressure["mode"]) == "guide_spirit":
		expected_sources.append("state.spirit_joined" if bool(pressure["spirit_joins_battle"]) else "state.spirit_nonjoining")
	if goal["pressure_sources"] != V.canonical_string_array(expected_sources):
		return _fail("goal exact sources mismatch: %s" % str(goal))
	return _pass()


static func _add_second_hostile(context: Dictionary) -> void:
	var actor: Dictionary = _actor("enemy.2", {"col": 5, "row": 4}, "enemy")
	(context["perceived_actors"] as Array).append(actor)
	(context["relationships"] as Dictionary)["enemy.2"] = "hostile"
	(context["occupancy"] as Dictionary)["5,4"] = "enemy.2"


static func _actor_ref(context: Dictionary, actor_id: String) -> Dictionary:
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == actor_id:
			return actor
	return {}


static func _transform_context(context: Dictionary, transform_name: String) -> Dictionary:
	var transformed: Dictionary = context.duplicate(true)
	var original_bounds: Dictionary = context["bounds"] as Dictionary
	var transformed_bounds: Dictionary = original_bounds.duplicate(true)
	if transform_name == "transpose":
		transformed_bounds = {"w": int(original_bounds["h"]), "h": int(original_bounds["w"])}
	transformed["bounds"] = transformed_bounds
	transformed["origin"] = _transform_position(context["origin"] as Dictionary, transform_name, original_bounds)
	for actor_value: Variant in transformed["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		actor["position"] = _transform_position(actor["position"] as Dictionary, transform_name, original_bounds)
	var occupancy: Dictionary = {}
	for actor_value: Variant in transformed["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		occupancy[V.canonical_cell_key(actor["position"] as Dictionary)] = str(actor["id"])
	transformed["occupancy"] = occupancy
	for field: String in ["authoritative_walkable", "perceived_planning_cells", "terrain_costs"]:
		var transformed_map: Dictionary = {}
		for key_value: Variant in (context[field] as Dictionary).keys():
			var position: Dictionary = V.parse_canonical_cell_key(str(key_value))
			var transformed_position: Dictionary = _transform_position(position, transform_name, original_bounds)
			transformed_map[V.canonical_cell_key(transformed_position)] = (context[field] as Dictionary)[key_value]
		transformed[field] = transformed_map
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	var objective_position: Dictionary = {}
	if bool(pressure["objective_known"]):
		objective_position = _transform_position(pressure["objective_position"] as Dictionary, transform_name, original_bounds)
	transformed["objective_pressure"] = PressureContract.build(
		str(pressure["mode"]), str(pressure["guide_mode"]), str(pressure["mover_alignment"]),
		str(pressure["factual_role"]), bool(pressure["objective_known"]), str(pressure["objective_id"]),
		objective_position, _transform_region(pressure["destination_region"] as Array, transform_name, original_bounds),
		_transform_region(pressure["approach_region"] as Array, transform_name, original_bounds),
		_transform_region(pressure["fallback_region"] as Array, transform_name, original_bounds),
		_transform_region(pressure["search_region"] as Array, transform_name, original_bounds),
		str(pressure["purifier_id"]), str(pressure["holder_id"]), str(pressure["carrier_id"]),
		str(pressure["quarry_id"]), str(pressure["spirit_id"]), float(pressure["objective_health_ratio"]),
		int(pressure["progress_current"]), int(pressure["progress_required"]), bool(pressure["escort_started"]),
		bool(pressure["spirit_joins_battle"]), bool(pressure["totem_stolen"]), pressure["pressure_sources"] as Array
	)
	return transformed


static func _transform_position(position: Dictionary, transform_name: String, bounds: Dictionary) -> Dictionary:
	match transform_name:
		"horizontal": return {"col": int(bounds["w"]) - 1 - int(position["col"]), "row": int(position["row"])}
		"vertical": return {"col": int(position["col"]), "row": int(bounds["h"]) - 1 - int(position["row"])}
		"transpose": return {"col": int(position["row"]), "row": int(position["col"])}
	return position.duplicate(true)


static func _transform_region(region: Array, transform_name: String, bounds: Dictionary) -> Array:
	var result: Array = []
	for position_value: Variant in region:
		result.append(_transform_position(position_value as Dictionary, transform_name, bounds))
	return V.canonical_position_array(result)


static func _assert_covariant(
	original_result: Dictionary, transformed_result: Dictionary, transform_name: String
) -> Dictionary:
	var original_goals: Array = original_result["goals"] as Array
	var transformed_goals: Array = transformed_result["goals"] as Array
	if original_goals.size() != transformed_goals.size():
		return _fail("%s transform changed goal count" % transform_name)
	var bounds := {"w": 6, "h": 6}
	for original_value: Variant in original_goals:
		var original: Dictionary = original_value as Dictionary
		var original_parts: PackedStringArray = str(original["goal_id"]).split(".")
		var match_goal: Dictionary = {}
		for transformed_value: Variant in transformed_goals:
			var candidate: Dictionary = transformed_value as Dictionary
			var candidate_parts: PackedStringArray = str(candidate["goal_id"]).split(".")
			if str(candidate["purpose"]) == str(original["purpose"]) and str(candidate_parts[3]) == str(original_parts[3]) and candidate["planned_primary"] == original["planned_primary"]:
				match_goal = candidate
				break
		if match_goal.is_empty():
			return _fail("%s transform lost semantic goal %s" % [transform_name, str(original["goal_id"])])
		var expected_region: Array = _transform_region(original["destination_region"] as Array, transform_name, bounds)
		if match_goal["destination_region"] != expected_region:
			return _fail("%s region was not covariant" % transform_name)
		var expected_anchor: Dictionary = expected_region[0] as Dictionary
		var expected_id := "goal.%s.%s.%s.c%dr%d" % [
			str(original_parts[1]), str(original["purpose"]), str(original_parts[3]),
			int(expected_anchor["col"]), int(expected_anchor["row"]),
		]
		if str(match_goal["goal_id"]) != expected_id:
			return _fail("%s anchor ID was not covariant" % transform_name)
		var original_noncoordinate: Dictionary = original.duplicate(true)
		var transformed_noncoordinate: Dictionary = match_goal.duplicate(true)
		for field: String in ["goal_id", "destination_region"]:
			original_noncoordinate.erase(field)
			transformed_noncoordinate.erase(field)
		if original_noncoordinate != transformed_noncoordinate:
			return _fail("%s changed noncoordinate goal facts" % transform_name)
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
