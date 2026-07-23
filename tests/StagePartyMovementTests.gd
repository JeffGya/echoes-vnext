# res://tests/StagePartyMovementTests.gd
# V2-COMBAT-002 slice 5 (Unit A): the PURE + DORMANT stage-party movement adapter.
#
# The adapter is not wired into live exploration, so every board, directive and
# situation set below is built by hand. Nothing here touches FlowRuntime,
# FlowContext, SaveService or any UI node.
#
# Two tests are load-bearing:
#
#   * `frontier_mirrored_boards_have_no_directional_bias` mirrors each fixture
#     horizontally, vertically and both ways and asserts the selection mirrors
#     with it.
#   * `frontier_tie_break_has_no_systematic_compass_bias` covers criterion 4.
#     It REPLACED `frontier_headingless_tie_pins_known_bias`, which was a
#     characterisation test pinning the old lexicographic-key bias as its expected
#     values. That test was DELETED rather than repaired at slice 6 phase 6A unit
#     4: repairing its expectations would have made the fix invisible, which is the
#     opposite of what a pinned bias is for. Slice 6 phase 6A also removed a
#     SECOND, separate bias (the manhattan sub-criterion, which demoted diagonal
#     frontiers); that one is covered by
#     `frontier_diagonal_not_deprioritised_by_manhattan`, because the mirror test
#     is structurally blind to it.
#
# Situation fixtures carry `type` ONLY. They must never fabricate a `category`
# key: no situation dict in the codebase carries one, and fixtures that invented
# it made the suite green over a code path production cannot reach.

class_name StagePartyMovementTests
extends RefCounted

const Adapter = preload("res://core/movement/StagePartyMovementAdapter.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")

const SCOUT_ID: String = "directive.scout_carefully"
const SEEK_ID: String = "directive.seek_signs"

## The prefix set CombatPressureService._valid_source admits.
const VALID_SOURCE_PREFIXES: Array = ["mode.", "role.", "actor.", "objective.", "state."]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/stage_party/profile_matches_directive_step_budget", Callable(StagePartyMovementTests, "_t_profile_matches_directive_step_budget"))
	runner.register_test("movement/stage_party/profile_is_non_controlling_party_token", Callable(StagePartyMovementTests, "_t_profile_is_non_controlling_party_token"))
	runner.register_test("movement/stage_party/profile_low_budget_emits_authored_override", Callable(StagePartyMovementTests, "_t_profile_low_budget_emits_authored_override"))
	runner.register_test("movement/stage_party/goal_validates_for_every_tier", Callable(StagePartyMovementTests, "_t_goal_validates_for_every_tier"))
	runner.register_test("movement/stage_party/goal_tier_urgency_ordering", Callable(StagePartyMovementTests, "_t_goal_tier_urgency_ordering"))
	runner.register_test("movement/stage_party/goal_holds_on_same_cell_or_unwalkable", Callable(StagePartyMovementTests, "_t_goal_holds_on_same_cell_or_unwalkable"))
	runner.register_test("movement/stage_party/goal_pressure_sources_are_admissible", Callable(StagePartyMovementTests, "_t_goal_pressure_sources_are_admissible"))
	runner.register_test("movement/stage_party/intent_validates_supplied_path", Callable(StagePartyMovementTests, "_t_intent_validates_supplied_path"))
	runner.register_test("movement/stage_party/intent_truncates_path_to_capacity", Callable(StagePartyMovementTests, "_t_intent_truncates_path_to_capacity"))
	runner.register_test("movement/stage_party/result_zero_step_yields_empty_path", Callable(StagePartyMovementTests, "_t_result_zero_step_yields_empty_path"))
	runner.register_test("movement/stage_party/result_multi_step_validates_and_excludes_origin", Callable(StagePartyMovementTests, "_t_result_multi_step_validates_and_excludes_origin"))
	runner.register_test("movement/stage_party/frontier_bfs_distance_outranks_heading", Callable(StagePartyMovementTests, "_t_frontier_bfs_distance_outranks_heading"))
	runner.register_test("movement/stage_party/frontier_heading_continuation_keeps_direction", Callable(StagePartyMovementTests, "_t_frontier_heading_continuation_keeps_direction"))
	runner.register_test("movement/stage_party/frontier_mirrored_boards_have_no_directional_bias", Callable(StagePartyMovementTests, "_t_frontier_mirrored_boards_have_no_directional_bias"))
	runner.register_test("movement/stage_party/frontier_tie_break_has_no_systematic_compass_bias", Callable(StagePartyMovementTests, "_t_frontier_tie_break_has_no_systematic_compass_bias"))
	runner.register_test("movement/stage_party/frontier_diagonal_two_solid_corners_refused", Callable(StagePartyMovementTests, "_t_frontier_diagonal_two_solid_corners_refused"))
	runner.register_test("movement/stage_party/frontier_diagonal_one_solid_corner_allowed", Callable(StagePartyMovementTests, "_t_frontier_diagonal_one_solid_corner_allowed"))
	runner.register_test("movement/stage_party/objective_weight_leads_within_slack", Callable(StagePartyMovementTests, "_t_objective_weight_leads_within_slack"))
	runner.register_test("movement/stage_party/objective_slack_envelope_bounds_detour", Callable(StagePartyMovementTests, "_t_objective_slack_envelope_bounds_detour"))
	runner.register_test("movement/stage_party/objective_weight_then_distance_then_id", Callable(StagePartyMovementTests, "_t_objective_weight_then_distance_then_id"))
	runner.register_test("movement/stage_party/objective_category_derived_from_type", Callable(StagePartyMovementTests, "_t_objective_category_derived_from_type"))
	runner.register_test("movement/stage_party/objective_independent_of_array_order", Callable(StagePartyMovementTests, "_t_objective_independent_of_array_order"))
	runner.register_test("movement/stage_party/deterministic_replay_and_purity", Callable(StagePartyMovementTests, "_t_deterministic_replay_and_purity"))
	# V2-COMBAT-002 slice 6 phase 6A, unit 3.
	runner.register_test("movement/stage_party/goal_advance_only_when_objective_truthfully_named", Callable(StagePartyMovementTests, "_t_goal_advance_only_when_objective_truthfully_named"))
	runner.register_test("movement/stage_party/intent_rejects_path_containing_origin", Callable(StagePartyMovementTests, "_t_intent_rejects_path_containing_origin"))
	runner.register_test("movement/stage_party/result_resolved_action_can_diverge_from_planned", Callable(StagePartyMovementTests, "_t_result_resolved_action_can_diverge_from_planned"))
	runner.register_test("movement/stage_party/objective_slack_config_narrows_but_never_widens", Callable(StagePartyMovementTests, "_t_objective_slack_config_narrows_but_never_widens"))
	runner.register_test("movement/stage_party/objective_total_order_survives_missing_ids", Callable(StagePartyMovementTests, "_t_objective_total_order_survives_missing_ids"))
	runner.register_test("movement/stage_party/frontier_diagonal_not_deprioritised_by_manhattan", Callable(StagePartyMovementTests, "_t_frontier_diagonal_not_deprioritised_by_manhattan"))


# ---------------------------------------------------------------------------
# Profile — capacity is the DIRECTIVE step_budget
# ---------------------------------------------------------------------------

## Capacity is read out of `data.directives.<id>.step_budget` in balance.json,
## never hardcoded here: the assertion compares the adapter against config. The
## shipped values are Scout Carefully 3 and Seek Signs 6, and the test also
## proves the two directives actually differ (so a config regression collapsing
## them to one value fails loudly).
static func _t_profile_matches_directive_step_budget() -> Dictionary:
	var directives: Dictionary = _load_directives()
	if directives.is_empty():
		return _fail("could not load data.directives from balance.json")
	for directive_id: String in [SCOUT_ID, SEEK_ID]:
		if not directives.has(directive_id):
			return _fail("balance.json is missing directive %s" % directive_id)
		var directive: Dictionary = directives[directive_id] as Dictionary
		if not directive.has("step_budget"):
			return _fail("%s has no step_budget in config" % directive_id)
		var configured: int = int(directive["step_budget"])
		var profile: Dictionary = Adapter.build_profile(directive)
		var validation: Dictionary = ProfileContract.validate(profile)
		if not bool(validation["valid"]):
			return _fail("%s profile invalid: %s @ %s" % [directive_id, validation["reason"], validation["field"]])
		if int(profile["capacity"]) != configured:
			return _fail("%s capacity %d != configured step_budget %d" % [directive_id, int(profile["capacity"]), configured])

	var scout_budget: int = int((directives[SCOUT_ID] as Dictionary)["step_budget"])
	var seek_budget: int = int((directives[SEEK_ID] as Dictionary)["step_budget"])
	if scout_budget >= seek_budget:
		return _fail("Scout Carefully (%d) should travel fewer steps than Seek Signs (%d)" % [scout_budget, seek_budget])

	# The combat clamp(2,6) capacity formula must NOT be what produced these.
	# A directive budget passes through untouched inside the contract's window.
	var synthetic: Dictionary = Adapter.build_profile({"id": "directive.test", "step_budget": 5})
	if int(synthetic["capacity"]) != 5:
		return _fail("directive budget 5 did not pass through: got %d" % int(synthetic["capacity"]))

	# The contract ceiling still applies above the window.
	var over_cap: Dictionary = Adapter.build_profile({"id": "directive.test", "step_budget": 9})
	if int(over_cap["capacity"]) != Adapter.MAX_EXPRESSIBLE_CAPACITY:
		return _fail("budget 9 should cap at %d, got %d" % [Adapter.MAX_EXPRESSIBLE_CAPACITY, int(over_cap["capacity"])])
	return _pass()


## A party token projects no hostile control, and an IN-WINDOW budget carries no
## authored override (the pace is config-driven, not authored).
static func _t_profile_is_non_controlling_party_token() -> Dictionary:
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})
	var validation: Dictionary = ProfileContract.validate(profile)
	if not bool(validation["valid"]):
		return _fail("profile invalid: %s @ %s" % [validation["reason"], validation["field"]])
	if bool(profile["controlling_state"]):
		return _fail("party token must not project hostile control")
	if str(profile["actor_kind"]) != Adapter.ACTOR_KIND:
		return _fail("actor_kind should be %s, got %s" % [Adapter.ACTOR_KIND, str(profile["actor_kind"])])
	if not (profile["authored_override"] as Dictionary).is_empty():
		return _fail("an in-window budget must not carry an authored_override")
	return _pass()


## Slice 5 amendment A4: a step_budget below the threshold is SURFACED, not
## silently clamped up to 2. It yields capacity 1 plus an authored_override
## naming `directive.step_budget` — the seam MovementProfile.validate demands at
## capacity 1, and the same one the GUIDE spirit's authored pace uses.
static func _t_profile_low_budget_emits_authored_override() -> Dictionary:
	for budget: int in [1, 0, -3]:
		var profile: Dictionary = Adapter.build_profile({"id": "directive.broken", "step_budget": budget})
		var validation: Dictionary = ProfileContract.validate(profile)
		if not bool(validation["valid"]):
			return _fail("budget %d profile invalid: %s @ %s" % [budget, validation["reason"], validation["field"]])

		# NOT clamped up to 2 — that inflated the party's pace and hid the config.
		if int(profile["capacity"]) != Adapter.MIN_EXPRESSIBLE_CAPACITY:
			return _fail("budget %d should yield capacity %d, got %d" % [
				budget, Adapter.MIN_EXPRESSIBLE_CAPACITY, int(profile["capacity"])
			])

		var override: Dictionary = profile["authored_override"] as Dictionary
		if override.is_empty():
			return _fail("budget %d must emit an authored_override" % budget)
		if str(override.get("source", "")) != Adapter.CAPACITY_SOURCE:
			return _fail("budget %d override source should be %s, got %s" % [
				budget, Adapter.CAPACITY_SOURCE, str(override.get("source", ""))
			])
		if int(override.get("capacity", -1)) != int(profile["capacity"]):
			return _fail("budget %d override capacity must match the profile capacity" % budget)

	# The threshold itself is in-window and must stay override-free.
	var at_threshold: Dictionary = Adapter.build_profile({
		"id": "directive.min", "step_budget": Adapter.AUTHORED_OVERRIDE_THRESHOLD
	})
	var threshold_validation: Dictionary = ProfileContract.validate(at_threshold)
	if not bool(threshold_validation["valid"]):
		return _fail("threshold profile invalid: %s @ %s" % [
			threshold_validation["reason"], threshold_validation["field"]
		])
	if not (at_threshold["authored_override"] as Dictionary).is_empty():
		return _fail("a budget at the threshold is in-window and needs no override")
	return _pass()


# ---------------------------------------------------------------------------
# Goal
# ---------------------------------------------------------------------------

## SLICE 6 PHASE 6A: the OBJECTIVE tiers now emit `advance`; weighted and frontier
## tiers stay `reposition`. Slice 5 had to under-claim `reposition` everywhere
## because the contract required an `advance` to name its target in
## `relevant_actors`; Unit 2 added the place-directed shape (empty `target_id` +
## an `objective.` pressure source), which is exactly what these goals publish.
## Tier ordering still lives in `urgency`, asserted next.
static func _t_goal_validates_for_every_tier() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var explore_map: Dictionary = _explore_map({"col": 0, "row": 0})
	var party: Dictionary = {"col": 0, "row": 0}

	var tiers: Array = [
		[Adapter.TIER_OBJECTIVE, {"id": "sit.obj", "pos": {"col": 3, "row": 2}}, "advance"],
		[Adapter.TIER_PASSED_OBJECTIVE, {"id": "sit.obj", "pos": {"col": 3, "row": 2}}, "advance"],
		[Adapter.TIER_WEIGHTED, {"id": "sit.intel", "pos": {"col": 2, "row": 4}}, "reposition"],
		[Adapter.TIER_FRONTIER, {"pos": {"col": 5, "row": 5}, "is_frontier": true}, "reposition"],
	]
	for entry_value: Variant in tiers:
		var entry: Array = entry_value as Array
		var tier: int = int(entry[0])
		var goal: Dictionary = Adapter.build_goal(explore_map, entry[1] as Dictionary, tier, walkable)
		var validation: Dictionary = GoalContract.validate(goal, party)
		if not bool(validation["valid"]):
			return _fail("tier %d goal invalid: %s @ %s" % [tier, validation["reason"], validation["field"]])
		if str(goal["purpose"]) != str(entry[2]):
			return _fail("tier %d purpose should be %s, got %s" % [tier, str(entry[2]), str(goal["purpose"])])
		if (goal["destination_region"] as Array).has(party):
			return _fail("tier %d destination_region must not contain the party origin" % tier)

		# The goal_id must carry the `explore` MODE segment (amendment A3). The
		# previous `recover` segment was simply false: thread recovery is the run's
		# reward, not the movement mode.
		if not str(goal["goal_id"]).begins_with("goal.%s." % Adapter.GOAL_MODE):
			return _fail("tier %d goal_id should carry mode.%s, got %s" % [
				tier, Adapter.GOAL_MODE, str(goal["goal_id"])
			])
	return _pass()


## Hard-objective tiers (1 and 4) outrank weighted non-objective (2), which
## outranks frontier (3). Purpose no longer differentiates the tiers, so this is
## the assertion that carries the freeze's ranking requirement.
static func _t_goal_tier_urgency_ordering() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var explore_map: Dictionary = _explore_map({"col": 0, "row": 0})
	var target: Dictionary = {"id": "sit.x", "pos": {"col": 3, "row": 3}}

	var objective: float = float(Adapter.build_goal(explore_map, target, Adapter.TIER_OBJECTIVE, walkable)["urgency"])
	var passed: float = float(Adapter.build_goal(explore_map, target, Adapter.TIER_PASSED_OBJECTIVE, walkable)["urgency"])
	var weighted: float = float(Adapter.build_goal(explore_map, target, Adapter.TIER_WEIGHTED, walkable)["urgency"])
	var frontier: float = float(Adapter.build_goal(explore_map, target, Adapter.TIER_FRONTIER, walkable)["urgency"])
	if not (objective > passed and passed > weighted and weighted > frontier):
		return _fail("tier urgency not strictly ordered: %f %f %f %f" % [objective, passed, weighted, frontier])
	return _pass()


## Nowhere to go -> `hold`, the only purpose the contract lets contain the
## mover origin.
static func _t_goal_holds_on_same_cell_or_unwalkable() -> Dictionary:
	var walkable: Dictionary = _full_walkable(4, 4)
	var party: Dictionary = {"col": 1, "row": 1}
	var explore_map: Dictionary = _explore_map(party)

	var same_cell: Dictionary = Adapter.build_goal(
		explore_map, {"pos": {"col": 1, "row": 1}}, Adapter.TIER_FRONTIER, walkable
	)
	var same_validation: Dictionary = GoalContract.validate(same_cell, party)
	if not bool(same_validation["valid"]):
		return _fail("same-cell goal invalid: %s @ %s" % [same_validation["reason"], same_validation["field"]])
	if str(same_cell["purpose"]) != "hold":
		return _fail("same-cell target should hold, got %s" % str(same_cell["purpose"]))

	# (3,3) removed from the walkable set -> not a legal destination.
	var holed: Dictionary = _full_walkable(4, 4)
	holed.erase("3,3")
	var unwalkable: Dictionary = Adapter.build_goal(
		explore_map, {"pos": {"col": 3, "row": 3}}, Adapter.TIER_OBJECTIVE, holed
	)
	var unwalkable_validation: Dictionary = GoalContract.validate(unwalkable, party)
	if not bool(unwalkable_validation["valid"]):
		return _fail("unwalkable goal invalid: %s @ %s" % [unwalkable_validation["reason"], unwalkable_validation["field"]])
	if str(unwalkable["purpose"]) != "hold":
		return _fail("unwalkable target should hold, got %s" % str(unwalkable["purpose"]))
	return _pass()


## Slice 5 amendment A6. `CombatPressureService._valid_source` gates pressure
## sources on the prefix set mode./role./actor./objective./state., so the earlier
## `tier.%d` source would have had every stage goal REJECTED at cutover. And a
## situation id must never land in `relevant_actors`, because `_goal_sources`
## expands that field as `"actor.%s"` — publishing the false source `actor.sit.obj`.
static func _t_goal_pressure_sources_are_admissible() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var explore_map: Dictionary = _explore_map({"col": 0, "row": 0})
	var tiers: Array = [
		Adapter.TIER_OBJECTIVE, Adapter.TIER_PASSED_OBJECTIVE,
		Adapter.TIER_WEIGHTED, Adapter.TIER_FRONTIER,
	]
	for tier_value: Variant in tiers:
		var tier: int = int(tier_value)
		var goal: Dictionary = Adapter.build_goal(
			explore_map, {"id": "sit.obj", "pos": {"col": 3, "row": 2}}, tier, walkable
		)
		var sources: Array = goal["pressure_sources"] as Array
		if sources.is_empty():
			return _fail("tier %d published no pressure sources" % tier)
		for source_value: Variant in sources:
			var source: String = str(source_value)
			if source.begins_with("tier."):
				return _fail("tier %d still publishes the rejected source %s" % [tier, source])
			var admitted: bool = false
			for prefix: String in VALID_SOURCE_PREFIXES:
				if source.begins_with(prefix) and source.length() > prefix.length():
					admitted = true
					break
			if not admitted:
				return _fail("tier %d source %s is outside the admissible prefix set" % [tier, source])

		# The situation id may appear as an `objective.` source, never as an actor.
		if (goal["relevant_actors"] as Array).has("sit.obj"):
			return _fail("tier %d put a situation id in relevant_actors" % tier)
		if not sources.has("objective.sit.obj"):
			return _fail("tier %d should publish the situation as objective.sit.obj" % tier)
		if sources.has("actor.sit.obj"):
			return _fail("tier %d published the false source actor.sit.obj" % tier)
	return _pass()


# ---------------------------------------------------------------------------
# Intent
# ---------------------------------------------------------------------------

## NOTE ON NAMING: an earlier version of this test was called
## `intent_validates_and_excludes_origin`, which was a lie — `build_intent` did
## NOT enforce path-excludes-origin, so the assertion only ever proved the FIXTURE
## excluded the origin. Slice 6 phase 6A CLOSED that seam; the guard itself is
## asserted by `intent_rejects_path_containing_origin`. What this test asserts is
## unchanged: a supplied path validates and commitment tracks its length.
static func _t_intent_validates_supplied_path() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var party: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(party)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.obj", "pos": {"col": 2, "row": 0}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})

	var moving: Dictionary = Adapter.build_intent(
		profile, goal, [{"col": 1, "row": 0}, {"col": 2, "row": 0}], party
	)
	var moving_validation: Dictionary = IntentContract.validate(moving, party)
	if not bool(moving_validation["valid"]):
		return _fail("intent invalid: %s @ %s" % [moving_validation["reason"], moving_validation["field"]])
	if int(moving["commitment"]) != 2:
		return _fail("commitment should equal the path length, got %d" % int(moving["commitment"]))

	# Zero-step: EMPTY array, never [origin].
	var still: Dictionary = Adapter.build_intent(profile, goal, [], party)
	var still_validation: Dictionary = IntentContract.validate(still, party)
	if not bool(still_validation["valid"]):
		return _fail("zero-step intent invalid: %s @ %s" % [still_validation["reason"], still_validation["field"]])
	if (still["path"] as Array) != []:
		return _fail("zero-step path should be [], got %s" % str(still["path"]))
	if int(still["commitment"]) != 0:
		return _fail("zero-step commitment should be 0")
	return _pass()


## A 3-step Scout Carefully party cannot commit to a 5-cell route.
static func _t_intent_truncates_path_to_capacity() -> Dictionary:
	var walkable: Dictionary = _full_walkable(8, 3)
	var party: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(party)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.far", "pos": {"col": 5, "row": 0}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})
	var long_path: Array = [
		{"col": 1, "row": 0}, {"col": 2, "row": 0}, {"col": 3, "row": 0},
		{"col": 4, "row": 0}, {"col": 5, "row": 0},
	]
	var intent: Dictionary = Adapter.build_intent(profile, goal, long_path, party)
	var validation: Dictionary = IntentContract.validate(intent, party)
	if not bool(validation["valid"]):
		return _fail("intent invalid: %s @ %s" % [validation["reason"], validation["field"]])
	if (intent["path"] as Array).size() != 3:
		return _fail("path should truncate to capacity 3, got %d" % (intent["path"] as Array).size())
	if int(intent["commitment"]) != 3:
		return _fail("commitment should be 3, got %d" % int(intent["commitment"]))
	if long_path.size() != 5:
		return _fail("build_intent mutated the caller's path array")
	return _pass()


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

## Zero-step advance: traversal is an EMPTY array, never [origin].
##
## `intent` and `goal` are REQUIRED arguments (slice 5 amendment A5): the removed
## defaults fabricated `purpose: "hold"` for whatever was passed, and
## MovementResult.validate does not cross-check purpose against traversal, so the
## lie validated clean.
static func _t_result_zero_step_yields_empty_path() -> Dictionary:
	var walkable: Dictionary = _full_walkable(5, 5)
	var origin: Dictionary = {"col": 2, "row": 2}
	var explore_map: Dictionary = _explore_map(origin)
	# Target == the party cell, so this is a genuine hold.
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"pos": origin}, Adapter.TIER_FRONTIER, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})
	var intent: Dictionary = Adapter.build_intent(profile, goal, [], origin)

	var result: Dictionary = Adapter.build_result(origin, [], "reached_destination", [], intent, goal)
	var validation: Dictionary = ResultContract.validate(result)
	if not bool(validation["valid"]):
		return _fail("zero-step result invalid: %s @ %s" % [validation["reason"], validation["field"]])
	if (result["actual_traversed_cells"] as Array) != []:
		return _fail("zero-step traversal should be [], got %s" % str(result["actual_traversed_cells"]))
	if (result["planned_path"] as Array) != []:
		return _fail("zero-step planned_path should be [], got %s" % str(result["planned_path"]))
	if (result["final_destination"] as Dictionary) != origin:
		return _fail("zero-step final_destination should be the origin")
	if int(result["voluntary_cost"]) != 0:
		return _fail("zero-step must cost nothing")
	# The purpose is the GOAL's, not a fabricated default.
	if str(result["purpose"]) != str(goal["purpose"]):
		return _fail("result purpose %s should mirror the goal purpose %s" % [
			str(result["purpose"]), str(goal["purpose"])
		])
	return _pass()


static func _t_result_multi_step_validates_and_excludes_origin() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var origin: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(origin)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.obj", "pos": {"col": 2, "row": 0}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})
	var path: Array = [{"col": 1, "row": 0}, {"col": 2, "row": 0}]
	var intent: Dictionary = Adapter.build_intent(profile, goal, path, origin)

	var result: Dictionary = Adapter.build_result(
		origin, path, "reached_destination", [], intent, goal
	)
	var validation: Dictionary = ResultContract.validate(result)
	if not bool(validation["valid"]):
		return _fail("result invalid: %s @ %s" % [validation["reason"], validation["field"]])
	for field: String in ["planned_path", "actual_traversed_cells"]:
		if (result[field] as Array).has(origin):
			return _fail("%s must exclude the origin" % field)
		if (result[field] as Array).size() != 2:
			return _fail("%s should hold 2 destinations, got %d" % [field, (result[field] as Array).size()])
	if int(result["voluntary_cost"]) != 2:
		return _fail("two steps should cost 2, got %d" % int(result["voluntary_cost"]))
	if int(result["remaining_capacity"]) != 1:
		return _fail("capacity 3 minus 2 steps should leave 1, got %d" % int(result["remaining_capacity"]))
	if (result["final_destination"] as Dictionary) != {"col": 2, "row": 0}:
		return _fail("final_destination should be the last traversed cell")
	if str(result["mover_id"]) != Adapter.MOVER_ID:
		return _fail("results belong to the single party token")

	# A5: the result must report the REAL purpose of the goal it resolves, not a
	# fabricated "hold" over a genuine multi-cell walk. Slice 6 phase 6A: an
	# objective-tier goal now reports `advance`, not the slice-5 `reposition`
	# compromise.
	if str(result["purpose"]) != "advance":
		return _fail("a multi-cell walk must not report purpose %s" % str(result["purpose"]))
	if str(result["purpose"]) != str(goal["purpose"]):
		return _fail("the result purpose must mirror the goal it resolves")
	return _pass()


# ---------------------------------------------------------------------------
# Frontier tie-breaks
# ---------------------------------------------------------------------------

## Criterion 1 (BFS distance) beats criterion 2 (heading). The wall makes the
## cell the heading points at strictly farther, so the party turns.
static func _t_frontier_bfs_distance_outranks_heading() -> Dictionary:
	var walkable: Dictionary = _full_walkable(5, 5)
	walkable.erase("3,0")
	walkable.erase("3,1")
	var chosen: Dictionary = Adapter.select_frontier(
		[{"col": 4, "row": 0}, {"col": 4, "row": 4}],
		{"col": 2, "row": 2},
		{"col": 1, "row": 0},
		walkable
	)
	if chosen != {"col": 4, "row": 4}:
		return _fail("walled-off (4,0) should lose on BFS distance; picked %s" % str(chosen))
	return _pass()


## Criterion 2 actually keeps the party travelling the way it was going: with
## every other criterion tied, flipping the heading flips the selection.
static func _t_frontier_heading_continuation_keeps_direction() -> Dictionary:
	var walkable: Dictionary = _full_walkable(5, 5)
	var party: Dictionary = {"col": 2, "row": 2}
	var candidates: Array = [{"col": 2, "row": 0}, {"col": 2, "row": 4}]

	var going_south: Dictionary = Adapter.select_frontier(candidates, party, {"col": 0, "row": 1}, walkable)
	if going_south != {"col": 2, "row": 4}:
		return _fail("heading south should keep going south; picked %s" % str(going_south))
	var going_north: Dictionary = Adapter.select_frontier(candidates, party, {"col": 0, "row": -1}, walkable)
	if going_north != {"col": 2, "row": 0}:
		return _fail("heading north should keep going north; picked %s" % str(going_north))

	# No heading -> criterion 2 is neutral and cannot invent a direction.
	var no_heading: Dictionary = Adapter.select_frontier(candidates, party, {}, walkable)
	if no_heading.is_empty():
		return _fail("a headingless party should still choose a frontier")
	return _pass()


## THE ANTI-BIAS TEST.
##
## Each fixture is run as authored and then mirrored horizontally, vertically and
## both ways. Mirroring transforms the walkable set, the party cell, the heading
## delta and the candidate list together; the selection must mirror with them.
##
## Every fixture here resolves at criterion 1 or 2. Configurations that fall
## through to criterion 4 cannot be mirror-covariant by construction (see the
## honest caveat in the adapter header) and are covered instead by
## `frontier_tie_break_has_no_systematic_compass_bias`.
static func _t_frontier_mirrored_boards_have_no_directional_bias() -> Dictionary:
	var width: int = 5
	var height: int = 5
	var open_board: Dictionary = _full_walkable(width, height)
	var walled_board: Dictionary = _full_walkable(width, height)
	walled_board.erase("3,0")
	walled_board.erase("3,1")

	var fixtures: Array = [
		# Resolved at criterion 2 (heading), on each axis and on the diagonal.
		{
			"name": "heading_east",
			"walkable": open_board,
			"party": {"col": 2, "row": 2},
			"heading": {"col": 1, "row": 0},
			"candidates": [{"col": 4, "row": 2}, {"col": 0, "row": 2}],
			"expected": {"col": 4, "row": 2},
		},
		{
			"name": "heading_south",
			"walkable": open_board,
			"party": {"col": 2, "row": 2},
			"heading": {"col": 0, "row": 1},
			"candidates": [{"col": 2, "row": 4}, {"col": 2, "row": 0}],
			"expected": {"col": 2, "row": 4},
		},
		{
			"name": "heading_southeast",
			"walkable": open_board,
			"party": {"col": 2, "row": 2},
			"heading": {"col": 1, "row": 1},
			"candidates": [{"col": 4, "row": 4}, {"col": 0, "row": 0}],
			"expected": {"col": 4, "row": 4},
		},
		# Resolved at criterion 1 (BFS distance) against an asymmetric wall.
		{
			"name": "walled_bfs",
			"walkable": walled_board,
			"party": {"col": 2, "row": 2},
			"heading": {"col": 1, "row": 0},
			"candidates": [{"col": 4, "row": 0}, {"col": 4, "row": 4}],
			"expected": {"col": 4, "row": 4},
		},
	]

	for fixture_value: Variant in fixtures:
		var fixture: Dictionary = fixture_value as Dictionary
		var fixture_name: String = str(fixture["name"])
		for mirror_value: Variant in [[false, false], [true, false], [false, true], [true, true]]:
			var mirror: Array = mirror_value as Array
			var flip_h: bool = bool(mirror[0])
			var flip_v: bool = bool(mirror[1])
			var chosen: Dictionary = Adapter.select_frontier(
				_mirror_cells(fixture["candidates"] as Array, flip_h, flip_v, width, height),
				_mirror_cell(fixture["party"] as Dictionary, flip_h, flip_v, width, height),
				_mirror_delta(fixture["heading"] as Dictionary, flip_h, flip_v),
				_mirror_walkable(fixture["walkable"] as Dictionary, flip_h, flip_v, width, height)
			)
			var expected: Dictionary = _mirror_cell(
				fixture["expected"] as Dictionary, flip_h, flip_v, width, height
			)
			if chosen != expected:
				return _fail(
					"%s mirrored(h=%s,v=%s): expected %s, picked %s — directional bias"
					% [fixture_name, str(flip_h), str(flip_v), str(expected), str(chosen)]
				)
	return _pass()


## CRITERION 4 — THE COMPASS-DE-ALIGNED GUARD (slice 6 phase 6A, unit 4).
##
## This is the R5 replacement for the deleted `frontier_headingless_tie_pins_known_bias`.
## The old test PINNED the lexicographic "col,row" string bias as its expected
## answers; repairing it would have hidden the fix, so it was deleted and this
## asserts the property the fix actually establishes.
##
## HONEST CAVEAT (documented AND respected by what is asserted below). Two
## candidates related by a mirror symmetry of BOTH the board and the party are
## genuinely indistinguishable — no deterministic rule can "correctly" prefer one,
## because no fact separates them. TRUE MIRROR-COVARIANCE IS UNACHIEVABLE and is
## NOT claimed here (`_t_frontier_mirrored_boards_have_no_directional_bias` covers
## the cases that ARE mirror-covariant, which all resolve at criterion 1 or 2).
## What IS achievable — and what this test asserts — is the removal of SYSTEMATIC
## compass preference: the tie answer no longer correlates with a fixed direction,
## so the party does not drift toward one quadrant run after run.
##
## (a) drives `select_frontier` over the full ring of equidistant candidates — the
##     orthogonal-vs-diagonal ring that manhattan-removal newly exposed — across a
##     set of distinct stage-shaped salts, and asserts the chosen directions are
##     not concentrated on any one compass direction. THRESHOLDS WERE MEASURED, not
##     guessed: over the 60-salt set below the observed distribution was
##     N 8 / NE 6 / E 3 / SE 10 / S 11 / SW 8 / W 7 / NW 7 — all eight directions
##     reached, max share 11/60 (18.3%) against a 12.5% uniform, families split
##     29 orth / 31 diag. The asserted bound (30% of the salt count) sits well above
##     that measured 18.3% so the test is not brittle, yet far below the >=50% a
##     two-way axis bias or the 100% a fixed compass rule would produce.
## (b) asserts EXACT replay determinism: identical (candidates, party, heading,
##     walkable, salt) returns byte-identical results across repeated calls.
static func _t_frontier_tie_break_has_no_systematic_compass_bias() -> Dictionary:
	# (a) THE RING. Party at the centre of an open 7x7 board; the eight cells at
	#     chebyshev 1 form the full ring of equidistant frontier candidates. On an
	#     open 8-way board every one is BFS distance 1 AND chebyshev 1, and with NO
	#     heading criterion 2 scores 0 for all — so criteria 1-3 tie completely and
	#     criterion 4 (the salted FNV-1a) is the sole decider. Manhattan-removal is
	#     what let the four DIAGONAL cells reach this tie at all: under the old
	#     manhattan sub-criterion a diagonal scored 2 against an orthogonal 1 and so
	#     could never win the ring — a systematic axis preference hid right here.
	var board: Dictionary = _full_walkable(7, 7)
	var party: Dictionary = {"col": 3, "row": 3}
	var ring: Array = [
		["N", {"col": 3, "row": 2}],
		["NE", {"col": 4, "row": 2}],
		["E", {"col": 4, "row": 3}],
		["SE", {"col": 4, "row": 4}],
		["S", {"col": 3, "row": 4}],
		["SW", {"col": 2, "row": 4}],
		["W", {"col": 2, "row": 3}],
		["NW", {"col": 2, "row": 2}],
	]
	var candidates: Array = []
	for entry_value: Variant in ring:
		candidates.append(((entry_value as Array)[1] as Dictionary).duplicate(true))

	# Distinct STAGE-shaped salts — exactly the identity shape the live caller
	# sources criterion 4's salt from (realm id + stage index), which is persisted
	# and constant for the life of a stage. realm 1..6 x stage 0..9 = 60 salts.
	var salts: Array = []
	for realm: int in range(1, 7):
		for stage: int in range(0, 10):
			salts.append("realm.%02d.stage.%02d" % [realm, stage])

	var counts: Dictionary = {}
	for entry_value: Variant in ring:
		counts[str((entry_value as Array)[0])] = 0

	for salt_value: Variant in salts:
		var salt: String = str(salt_value)
		var chosen: Dictionary = Adapter.select_frontier(candidates, party, {}, board, salt)
		if chosen.is_empty():
			return _fail("salt %s produced no frontier over a full open ring" % salt)
		var label: String = _compass_label(ring, chosen)
		if label.is_empty():
			return _fail("salt %s chose %s, which is not on the ring" % [salt, str(chosen)])
		counts[label] = int(counts[label]) + 1

	# NO DIRECTION SYSTEMATICALLY EXCLUDED. The old lexicographic rule pinned 100%
	# of these ties to one quadrant; the de-aligned guard must reach every compass
	# direction at least once.
	for entry_value: Variant in ring:
		var label: String = str((entry_value as Array)[0])
		if int(counts[label]) <= 0:
			return _fail(
				"compass direction %s was never chosen across %d salts — a direction is "
				% [label, salts.size()]
				+ "being systematically excluded: %s" % str(counts)
			)

	# NO SYSTEMATIC CONCENTRATION. Bound = 30% of the salt count; see the measured
	# distribution in the docstring for why this is defensible and non-brittle.
	var bound: int = int(floor(0.30 * float(salts.size())))
	for entry_value: Variant in ring:
		var label: String = str((entry_value as Array)[0])
		if int(counts[label]) > bound:
			return _fail(
				"compass direction %s captured %d of %d salts (> bound %d) — the tie-break "
				% [label, int(counts[label]), salts.size(), bound]
				+ "is concentrating on one direction: %s" % str(counts)
			)

	# BOTH AXIS FAMILIES SURVIVE. Direct regression guard for manhattan-removal:
	# under the old rule the diagonal family's share of the ring was exactly zero.
	var orth_total: int = int(counts["N"]) + int(counts["E"]) + int(counts["S"]) + int(counts["W"])
	var diag_total: int = int(counts["NE"]) + int(counts["SE"]) + int(counts["SW"]) + int(counts["NW"])
	if orth_total <= 0 or diag_total <= 0:
		return _fail(
			"one axis family was never chosen (orth=%d diag=%d) — manhattan-style axis bias is back"
			% [orth_total, diag_total]
		)

	# The salt must actually PARTICIPATE — criterion 4 is not a constant that merely
	# happens to replay. More than one distinct direction across the set proves it.
	var distinct: Dictionary = {}
	for salt_value: Variant in salts:
		var pick: Dictionary = Adapter.select_frontier(candidates, party, {}, board, str(salt_value))
		distinct[_compass_label(ring, pick)] = true
	if distinct.size() < 2:
		return _fail("every salt produced the same pick — the salt is not participating")

	# (b) EXACT REPLAY DETERMINISM. Identical inputs -> byte-identical output across
	#     repeated calls, so a saved run replays to the same walk.
	var salt_a: String = "realm.01.stage.00"
	var baseline: Dictionary = Adapter.select_frontier(candidates, party, {}, board, salt_a)
	for _repeat: int in range(5):
		var again: Dictionary = Adapter.select_frontier(candidates, party, {}, board, salt_a)
		if again != baseline:
			return _fail("replay diverged for salt %s: %s vs %s" % [salt_a, str(again), str(baseline)])

	# The default empty salt is a legitimate, fully-deterministic single de-alignment
	# and must also replay exactly.
	var empty_first: Dictionary = Adapter.select_frontier(candidates, party, {}, board)
	var empty_second: Dictionary = Adapter.select_frontier(candidates, party, {}, board, "")
	if empty_first != empty_second:
		return _fail("the default empty salt is not stable: %s vs %s" % [str(empty_first), str(empty_second)])
	return _pass()


## The shared two-solid-corners rule: a diagonal squeezed between two solids is
## not an edge, so the cell behind it is unreachable and never selected.
static func _t_frontier_diagonal_two_solid_corners_refused() -> Dictionary:
	var walkable: Dictionary = {"0,0": true, "1,1": true}  # (1,0) and (0,1) solid
	var chosen: Dictionary = Adapter.select_frontier(
		[{"col": 1, "row": 1}], {"col": 0, "row": 0}, {}, walkable
	)
	if not chosen.is_empty():
		return _fail("diagonal between two solid corners must be refused; picked %s" % str(chosen))
	return _pass()


## One solid corner still leaves a legal diagonal.
##
## SLICE 5 AMENDMENT A7. The freeze also required an "occupied but walkable"
## diagonal case tested against the shared legality helper with a NON-EMPTY
## occupancy dict. That case is STRUCTURALLY UNREACHABLE and is not tested here:
## `StageTerrain.is_legal_edge` / `legal_neighbors` take no occupancy argument,
## and `MovementPathService.reachable_cost_region` has no occupancy parameter at
## all, so occupancy cannot reach the adapter's legality decision by any route.
## The reachable property — two WALKABLE side cells keep the diagonal legal — is
## what the second half of this test asserts.
static func _t_frontier_diagonal_one_solid_corner_allowed() -> Dictionary:
	# (1,0) solid, (0,1) walkable -> legal.
	var one_solid: Dictionary = {"0,0": true, "0,1": true, "1,1": true}
	var through_gap: Dictionary = Adapter.select_frontier(
		[{"col": 1, "row": 1}], {"col": 0, "row": 0}, {}, one_solid
	)
	if through_gap != {"col": 1, "row": 1}:
		return _fail("one solid corner must still allow the diagonal; picked %s" % str(through_gap))

	# Both sides walkable -> legal.
	var both_open: Dictionary = _full_walkable(2, 2)
	var open_diagonal: Dictionary = Adapter.select_frontier(
		[{"col": 1, "row": 1}], {"col": 0, "row": 0}, {}, both_open
	)
	if open_diagonal != {"col": 1, "row": 1}:
		return _fail("walkable side cells must allow the diagonal; picked %s" % str(open_diagonal))
	return _pass()


# ---------------------------------------------------------------------------
# Objective tie-breaks — bounded slack (slice 5 amendment A2)
# ---------------------------------------------------------------------------

## Inside the slack envelope, WEIGHT leads. The previous distance-first rule made
## one cell of distance beat any weight, which flattened Scout Carefully and Seek
## Signs into identical behaviour — a gameplay policy change, not a determinism
## fix. Live code scores `weight * 1/(d+1)`, so weight must still matter.
static func _t_objective_weight_leads_within_slack() -> Dictionary:
	var category_map: Dictionary = {"combat": "combat", "loot": "reward"}
	var weights: Dictionary = {"combat": 0.4, "reward": 1.2}
	var situations: Array = [
		{"id": "sit.near", "pos": {"col": 1, "row": 0}, "type": "combat"},
		{"id": "sit.far", "pos": {"col": 3, "row": 0}, "type": "loot"},
	]
	# nearest = 1, envelope = 1 + max(2, ceil(1 * 0.25)) = 3, so distance 3 is IN.
	var chosen: Dictionary = Adapter.select_objective_target(
		situations, {"1,0": 1, "3,0": 3}, weights, category_map
	)
	if str(chosen.get("id", "")) != "sit.far":
		return _fail(
			"the preferred category is inside the slack envelope and should win; picked %s"
			% str(chosen.get("id", ""))
		)
	return _pass()


## ...but slack is BOUNDED: past the envelope the farther node is dropped outright,
## however much the directive prefers its category. This is what keeps the party
## from crossing the map for a marginally nicer node.
static func _t_objective_slack_envelope_bounds_detour() -> Dictionary:
	var category_map: Dictionary = {"combat": "combat", "loot": "reward"}
	var weights: Dictionary = {"combat": 0.4, "reward": 1.2}
	var situations: Array = [
		{"id": "sit.near", "pos": {"col": 1, "row": 0}, "type": "combat"},
		{"id": "sit.far", "pos": {"col": 6, "row": 0}, "type": "loot"},
	]
	# nearest = 1, envelope = 3; distance 6 is OUTSIDE and is dropped.
	var chosen: Dictionary = Adapter.select_objective_target(
		situations, {"1,0": 1, "6,0": 6}, weights, category_map
	)
	if str(chosen.get("id", "")) != "sit.near":
		return _fail(
			"a node beyond the slack envelope must be dropped; picked %s"
			% str(chosen.get("id", ""))
		)

	# The envelope widens with distance (max(2, 25% of the nearest distance)), so
	# the same 5-cell gap IS inside it when the nearest node is far away.
	var far_pair: Array = [
		{"id": "sit.near", "pos": {"col": 20, "row": 0}, "type": "combat"},
		{"id": "sit.far", "pos": {"col": 25, "row": 0}, "type": "loot"},
	]
	# nearest = 20, envelope = 20 + max(2, ceil(5.0)) = 25, so distance 25 is IN.
	var widened: Dictionary = Adapter.select_objective_target(
		far_pair, {"20,0": 20, "25,0": 25}, weights, category_map
	)
	if str(widened.get("id", "")) != "sit.far":
		return _fail(
			"the envelope should widen with distance and admit sit.far; picked %s"
			% str(widened.get("id", ""))
		)
	return _pass()


## Criterion order inside the envelope: weight, then distance, then id.
static func _t_objective_weight_then_distance_then_id() -> Dictionary:
	var category_map: Dictionary = {"combat": "combat", "npc": "intel"}
	var weights: Dictionary = {"combat": 0.4, "intel": 1.4}

	# Equal distance -> the heavier configured weight wins.
	var by_weight: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.a", "pos": {"col": 1, "row": 0}, "type": "combat"},
			{"id": "sit.b", "pos": {"col": 0, "row": 1}, "type": "npc"},
		],
		{"1,0": 1, "0,1": 1}, weights, category_map
	)
	if str(by_weight.get("id", "")) != "sit.b":
		return _fail("heavier weight should win at equal distance; picked %s" % str(by_weight.get("id", "")))

	# Equal weight -> the nearer node wins (criterion 3).
	var by_distance: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.a", "pos": {"col": 2, "row": 0}, "type": "npc"},
			{"id": "sit.b", "pos": {"col": 0, "row": 1}, "type": "npc"},
		],
		{"2,0": 2, "0,1": 1}, weights, category_map
	)
	if str(by_distance.get("id", "")) != "sit.b":
		return _fail("nearer node should win at equal weight; picked %s" % str(by_distance.get("id", "")))

	# Equal weight AND equal distance -> lexicographically smallest id.
	var by_id: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.zulu", "pos": {"col": 1, "row": 0}, "type": "npc"},
			{"id": "sit.alpha", "pos": {"col": 0, "row": 1}, "type": "npc"},
		],
		{"1,0": 1, "0,1": 1}, weights, category_map
	)
	if str(by_id.get("id", "")) != "sit.alpha":
		return _fail("id tiebreak should pick sit.alpha; picked %s" % str(by_id.get("id", "")))
	return _pass()


## THE WIRING TEST — slice 5 amendment A2, second half.
##
## The adapter previously looked up `situation["category"]`. NO situation dict in
## this codebase carries that key: live `FlowRuntime._find_explore_target` DERIVES
## the category by mapping `sit.type` through `data.stages.situation_category`
## with an `"intel"` default, and never stores the result. The old fixtures
## fabricated the key, so the suite was green over a path production cannot reach.
##
## This test therefore uses REAL type-only situation shapes and the REAL category
## map out of balance.json, and its last assertion fails if the dead
## `situation["category"]` lookup is ever reintroduced.
static func _t_objective_category_derived_from_type() -> Dictionary:
	var category_map: Dictionary = _load_situation_category()
	if category_map.is_empty():
		return _fail("could not load data.stages.situation_category from balance.json")
	var directives: Dictionary = _load_directives()
	if not directives.has(SCOUT_ID):
		return _fail("balance.json is missing directive %s" % SCOUT_ID)
	var scout: Dictionary = directives[SCOUT_ID] as Dictionary
	var weights_value: Variant = scout.get("target_preference", {})
	var weights: Dictionary = weights_value if weights_value is Dictionary else {}
	if weights.is_empty():
		return _fail("%s has no target_preference in config" % SCOUT_ID)

	# Sanity: the mapping this test depends on must actually be the shipped one.
	for required_type: String in ["combat", "npc"]:
		if not category_map.has(required_type):
			return _fail("balance.json situation_category is missing type %s" % required_type)

	# A `combat` type maps to the `combat` category, which Scout Carefully weighs
	# LOW; an `npc` type maps to `intel`, which it weighs high.
	var by_type: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.a", "pos": {"col": 1, "row": 0}, "type": "combat"},
			{"id": "sit.b", "pos": {"col": 0, "row": 1}, "type": "npc"},
		],
		{"1,0": 1, "0,1": 1}, weights, category_map
	)
	if str(by_type.get("id", "")) != "sit.b":
		return _fail(
			"Scout Carefully prefers intel over combat; picked %s" % str(by_type.get("id", ""))
		)

	# An UNMAPPED type falls back to the `intel` default, exactly as the live
	# Tier-2 loop does (`str(sit_cat_map.get(sit_type, "intel"))`).
	if category_map.has("sit.unmapped_type"):
		return _fail("fixture type collision: situation_category unexpectedly maps the probe type")
	var unmapped: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.a", "pos": {"col": 1, "row": 0}, "type": "combat"},
			{"id": "sit.b", "pos": {"col": 0, "row": 1}, "type": "sit.unmapped_type"},
		],
		{"1,0": 1, "0,1": 1}, weights, category_map
	)
	if str(unmapped.get("id", "")) != "sit.b":
		return _fail(
			"an unmapped type must default to %s and win here; picked %s"
			% [Adapter.DEFAULT_SITUATION_CATEGORY, str(unmapped.get("id", ""))]
		)

	# THE REGRESSION GUARD. `sit.a` carries a FABRICATED `category` key that
	# contradicts its `type`. If the adapter ever honours that key again, sit.a
	# scores as intel, ties sit.b on weight and distance, and wins the id
	# tiebreak. Deriving from `type` — the only thing production supplies —
	# scores it as combat and sit.b wins.
	var fabricated: Dictionary = Adapter.select_objective_target(
		[
			{"id": "sit.a", "pos": {"col": 1, "row": 0}, "type": "combat", "category": "intel"},
			{"id": "sit.b", "pos": {"col": 0, "row": 1}, "type": "npc"},
		],
		{"1,0": 1, "0,1": 1}, weights, category_map
	)
	if str(fabricated.get("id", "")) != "sit.b":
		return _fail(
			"a fabricated `category` key must be IGNORED — category comes from "
			+ "`type` through situation_category; picked %s" % str(fabricated.get("id", ""))
		)
	return _pass()


## Selection must not depend on where a situation sits in the array — the flaw
## the id-lexicographic criterion exists to remove.
static func _t_objective_independent_of_array_order() -> Dictionary:
	var category_map: Dictionary = {"npc": "intel"}
	var weights: Dictionary = {"intel": 1.4}
	var situations: Array = [
		{"id": "sit.delta", "pos": {"col": 1, "row": 0}, "type": "npc"},
		{"id": "sit.bravo", "pos": {"col": 0, "row": 1}, "type": "npc"},
		{"id": "sit.charlie", "pos": {"col": 1, "row": 1}, "type": "npc"},
		{"id": "sit.alpha", "pos": {"col": 2, "row": 0}, "type": "npc"},
	]
	var dist_field: Dictionary = {"1,0": 1, "0,1": 1, "1,1": 1, "2,0": 2}

	# All four weigh the same, so criterion 3 (distance) then criterion 4 (id)
	# decide: sit.alpha is nearer-tied out at distance 2, leaving the smallest id
	# among the distance-1 nodes.
	var baseline: String = str(
		Adapter.select_objective_target(situations, dist_field, weights, category_map).get("id", "")
	)
	if baseline != "sit.bravo":
		return _fail("expected sit.bravo (distance 1, smallest id); got %s" % baseline)

	# Every rotation, plus the reversal, must agree.
	for offset: int in range(situations.size()):
		var rotated: Array = []
		for index: int in range(situations.size()):
			rotated.append(situations[(index + offset) % situations.size()])
		var rotated_pick: String = str(
			Adapter.select_objective_target(rotated, dist_field, weights, category_map).get("id", "")
		)
		if rotated_pick != baseline:
			return _fail("rotation %d changed the pick: %s vs %s" % [offset, rotated_pick, baseline])

	var reversed_situations: Array = situations.duplicate(true)
	reversed_situations.reverse()
	var reversed_pick: String = str(
		Adapter.select_objective_target(reversed_situations, dist_field, weights, category_map).get("id", "")
	)
	if reversed_pick != baseline:
		return _fail("reversal changed the pick: %s vs %s" % [reversed_pick, baseline])
	return _pass()


# ---------------------------------------------------------------------------
# Determinism + purity
# ---------------------------------------------------------------------------

## Identical inputs -> byte-identical outputs, and no input is mutated.
static func _t_deterministic_replay_and_purity() -> Dictionary:
	var directive: Dictionary = {"id": SCOUT_ID, "step_budget": 3}
	var walkable: Dictionary = _full_walkable(5, 5)
	var party: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(party)
	var target: Dictionary = {"id": "sit.obj", "pos": {"col": 2, "row": 0}}
	var path: Array = [{"col": 1, "row": 0}, {"col": 2, "row": 0}]
	var candidates: Array = [{"col": 4, "row": 4}, {"col": 0, "row": 4}]
	var heading: Dictionary = {"col": 1, "row": 0}
	var situations: Array = [
		{"id": "sit.b", "pos": {"col": 1, "row": 0}, "type": "npc"},
		{"id": "sit.a", "pos": {"col": 0, "row": 1}, "type": "npc"},
	]
	var dist_field: Dictionary = {"1,0": 1, "0,1": 1}
	var weights: Dictionary = {"intel": 1.4}
	var category_map: Dictionary = {"npc": "intel"}

	var before: String = JSON.stringify([
		directive, walkable, explore_map, target, path, candidates, heading,
		situations, dist_field, weights, category_map
	])

	var first: Array = []
	var second: Array = []
	for pass_index: int in range(2):
		var profile: Dictionary = Adapter.build_profile(directive)
		var goal: Dictionary = Adapter.build_goal(explore_map, target, Adapter.TIER_OBJECTIVE, walkable)
		var intent: Dictionary = Adapter.build_intent(profile, goal, path, party)
		var result: Dictionary = Adapter.build_result(party, path, "reached_destination", [], intent, goal)
		var frontier: Dictionary = Adapter.select_frontier(candidates, party, heading, walkable)
		var objective: Dictionary = Adapter.select_objective_target(
			situations, dist_field, weights, category_map
		)
		var snapshot: Array = [profile, goal, intent, result, frontier, objective]
		if pass_index == 0:
			first = snapshot
		else:
			second = snapshot

	if JSON.stringify(first) != JSON.stringify(second):
		return _fail("repeated calls produced different output")

	var after: String = JSON.stringify([
		directive, walkable, explore_map, target, path, candidates, heading,
		situations, dist_field, weights, category_map
	])
	if before != after:
		return _fail("adapter mutated one of its inputs")

	# The mutated-return guard: editing a returned situation must not reach back
	# into the caller's array.
	var returned: Dictionary = Adapter.select_objective_target(
		situations, dist_field, weights, category_map
	)
	returned["id"] = "tampered"
	if str((situations[1] as Dictionary)["id"]) != "sit.a":
		return _fail("select_objective_target returned a live reference into the input")
	return _pass()


# ---------------------------------------------------------------------------
# V2-COMBAT-002 slice 6 phase 6A, unit 3
# ---------------------------------------------------------------------------

## `advance` is emitted ONLY where it is true, and the objective source is derived
## from the situation rather than manufactured to unlock the label.
##
## Unit 2 lets a place-directed `advance` leave `planned_primary.target_id` empty
## iff `pressure_sources` carries an `objective.<id>`. The temptation this test
## guards against is inventing such a source so every moving goal can call itself
## `advance`. The dependency must run source -> purpose: an objective-tier target
## with no usable id publishes no objective source and therefore stays
## `reposition`, and a frontier — which §9 does not describe as an authored
## objective at all — stays `reposition` unconditionally.
static func _t_goal_advance_only_when_objective_truthfully_named() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var party: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(party)
	var destination: Dictionary = {"col": 3, "row": 2}

	# (1) An objective tier with a usable id advances, place-directed.
	for tier_value: Variant in [Adapter.TIER_OBJECTIVE, Adapter.TIER_PASSED_OBJECTIVE]:
		var tier: int = int(tier_value)
		var goal: Dictionary = Adapter.build_goal(
			explore_map, {"id": "sit.obj", "pos": destination}, tier, walkable
		)
		var validation: Dictionary = GoalContract.validate(goal, party)
		if not bool(validation["valid"]):
			return _fail("tier %d advance invalid: %s @ %s" % [tier, validation["reason"], validation["field"]])
		if str(goal["purpose"]) != "advance":
			return _fail("tier %d should advance, got %s" % [tier, str(goal["purpose"])])
		# Place-directed: the target is the REGION, not a named actor.
		var primary: Dictionary = goal["planned_primary"] as Dictionary
		if not str(primary["target_id"]).is_empty():
			return _fail("tier %d advance must be place-directed, got target_id %s" % [tier, str(primary["target_id"])])
		if not (goal["relevant_actors"] as Array).is_empty():
			return _fail("tier %d must not launder a situation id into relevant_actors" % tier)
		if not (goal["pressure_sources"] as Array).has("objective.sit.obj"):
			return _fail("tier %d advance must name its objective source" % tier)
		if not str(goal["goal_id"]).begins_with("goal.explore.advance."):
			return _fail("tier %d goal_id must carry the advance segment, got %s" % [tier, str(goal["goal_id"])])

	# (2) An objective tier whose target cannot be truthfully named stays
	#     `reposition`. A bare frontier-shaped target has no id at all; a
	#     non-semantic id is rejected by the same gate CombatPressureService uses.
	var untruthful: Array = [
		{"pos": destination},
		{"id": "", "pos": destination},
		{"id": "Sit Obj!", "pos": destination},
	]
	for target_value: Variant in untruthful:
		var target: Dictionary = target_value as Dictionary
		var goal: Dictionary = Adapter.build_goal(
			explore_map, target, Adapter.TIER_OBJECTIVE, walkable
		)
		var validation: Dictionary = GoalContract.validate(goal, party)
		if not bool(validation["valid"]):
			return _fail("unnameable objective invalid: %s @ %s" % [validation["reason"], validation["field"]])
		if str(goal["purpose"]) != "reposition":
			return _fail(
				"an objective tier that cannot name its objective must stay reposition; "
				+ "target %s produced %s" % [str(target), str(goal["purpose"])]
			)
		for source_value: Variant in goal["pressure_sources"] as Array:
			if str(source_value).begins_with("objective."):
				return _fail("target %s published a manufactured objective source" % str(target))

	# (3) A weighted point of interest carries an objective source, so the CONTRACT
	#     would now admit `advance` — but it is not the stage's authored objective,
	#     so the adapter still declines. This is a semantic restriction, and the
	#     assertion exists so that loosening it is a deliberate act.
	var weighted: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.intel", "pos": destination}, Adapter.TIER_WEIGHTED, walkable
	)
	if str(weighted["purpose"]) != "reposition":
		return _fail("a weighted non-objective must stay reposition, got %s" % str(weighted["purpose"]))

	# (4) A frontier has no objective source and must never advance.
	var frontier: Dictionary = Adapter.build_goal(
		explore_map, {"pos": {"col": 5, "row": 5}, "is_frontier": true}, Adapter.TIER_FRONTIER, walkable
	)
	if str(frontier["purpose"]) != "reposition":
		return _fail("a frontier must stay reposition, got %s" % str(frontier["purpose"]))
	for source_value: Variant in frontier["pressure_sources"] as Array:
		if str(source_value).begins_with("objective."):
			return _fail("a frontier published an objective source: %s" % str(source_value))
	return _pass()


## `build_intent` ENFORCES path-excludes-origin instead of trusting the caller.
##
## Slice 5 documented the precondition and copied `path` verbatim, so a violating
## router produced a plausible-looking intent that only failed later inside
## `MovementResult.validate`, one layer from the cause. The guard now runs at the
## point of construction, reuses `MovementContractValidation.require_path_excludes_origin`
## rather than reimplementing the rule, and REFUSES rather than repairs: dropping
## the offending cell would hide a broken router exactly the way slice 5 amendment
## A4 refused to hide a broken step budget.
static func _t_intent_rejects_path_containing_origin() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var origin: Dictionary = {"col": 1, "row": 1}
	var explore_map: Dictionary = _explore_map(origin)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.obj", "pos": {"col": 3, "row": 1}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})

	# A prepended origin is the classic legacy-path shape and must be REFUSED.
	var prepended: Dictionary = Adapter.build_intent(
		profile, goal, [origin, {"col": 2, "row": 1}, {"col": 3, "row": 1}], origin
	)
	if not prepended.is_empty():
		return _fail("a path containing the origin must be refused, got %s" % str(prepended))

	# So must the origin appearing anywhere else — a loop back through the start.
	var revisits: Dictionary = Adapter.build_intent(
		profile, goal, [{"col": 2, "row": 1}, origin], origin
	)
	if not revisits.is_empty():
		return _fail("a path revisiting the origin must be refused, got %s" % str(revisits))

	# The guard must not be silently repairing: a legal path is untouched.
	var clean_path: Array = [{"col": 2, "row": 1}, {"col": 3, "row": 1}]
	var clean: Dictionary = Adapter.build_intent(profile, goal, clean_path, origin)
	var validation: Dictionary = IntentContract.validate(clean, origin)
	if not bool(validation["valid"]):
		return _fail("clean intent invalid: %s @ %s" % [validation["reason"], validation["field"]])
	if (clean["path"] as Array).size() != 2:
		return _fail("a legal path must pass through unchanged, got %s" % str(clean["path"]))
	if int(clean["commitment"]) != 2:
		return _fail("commitment should be 2, got %d" % int(clean["commitment"]))

	# A zero-step intent is still legal — an empty path cannot contain anything.
	var still: Dictionary = Adapter.build_intent(profile, goal, [], origin)
	if still.is_empty():
		return _fail("an empty path must not trip the origin guard")

	# --- SLICE 6 PHASE 6A, UNIT 4 — THE GUARD FAILED OPEN ---------------------
	#
	# `require_path_excludes_origin` tests EXACT Dictionary equality, and unit 3
	# compared raw path cells against a `_cell_of`-normalised origin. Everything
	# above passes the identical dict literal as both the origin and the path
	# element, which is precisely the one shape that cannot expose the mismatch —
	# so none of it could see the bug.
	#
	# These cells are the SAME CELL as `origin` geometrically, in the
	# non-canonical shapes a real router produces: a cost/metadata key riding
	# along, and float coordinates out of any arithmetic that touched a float.
	# Each one was accepted before the fix.
	for violating_value: Variant in [
		[{"col": 1, "row": 1, "cost": 2}, {"col": 2, "row": 1}],
		[{"col": 1.0, "row": 1.0}, {"col": 2, "row": 1}],
		[{"col": 2, "row": 1}, {"col": 1, "row": 1, "terrain": "mud"}],
		[{"col": 2, "row": 1}, {"col": 1.0, "row": 1}],
	]:
		var violating: Array = violating_value as Array
		var leaked: Dictionary = Adapter.build_intent(profile, goal, violating, origin)
		if not leaked.is_empty():
			return _fail(
				"origin guard FAILED OPEN on a non-canonical origin cell: %s was accepted as %s"
				% [str(violating), str(leaked.get("path", []))]
			)

	# ...and the equivalent non-canonical origin on the OTHER side of the compare.
	var noisy_origin: Dictionary = Adapter.build_intent(
		profile, goal, [{"col": 1, "row": 1}, {"col": 2, "row": 1}], {"col": 1, "row": 1, "cost": 0}
	)
	if not noisy_origin.is_empty():
		return _fail("origin guard failed open on a non-canonical mover_origin")

	# --- AND IT MUST NOT COERCE A MISSING ORIGIN INTO (0,0) -------------------
	#
	# `require_path_excludes_origin` deliberately bypasses on an EMPTY origin:
	# no origin was declared, so there is nothing to exclude. Unit 3 ran
	# `mover_origin` through `_cell_of` first, and `_cell_of({})` is
	# `{"col":0,"row":0}` — a real cell — which defeated that bypass and silently
	# rejected any legitimate path crossing the board corner.
	var corner_path: Array = [{"col": 0, "row": 0}, {"col": 1, "row": 0}]
	var bypassed: Dictionary = Adapter.build_intent(profile, goal, corner_path, {})
	if bypassed.is_empty():
		return _fail(
			"an ABSENT origin was coerced to (0,0): a legal path through the corner was refused"
		)
	if (bypassed["path"] as Array).size() != 2:
		return _fail("empty-origin bypass altered the path: %s" % str(bypassed["path"]))
	# The bypass is about the ABSENT origin only — a declared (0,0) still guards.
	var declared_corner: Dictionary = Adapter.build_intent(
		profile, goal, corner_path, {"col": 0, "row": 0}
	)
	if not declared_corner.is_empty():
		return _fail("a DECLARED (0,0) origin must still be excluded from its own path")
	return _pass()


## `resolved_action` is a REAL seam, not a copy of `planned_action`.
##
## It used to be assigned `intent.planned_action` unconditionally, so the two
## fields `MovementResult` deliberately keeps apart could never disagree. Empty
## (the default) still means "resolved as planned", so no existing caller changes;
## an executor that had to fall back passes what actually resolved.
static func _t_result_resolved_action_can_diverge_from_planned() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var origin: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(origin)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.obj", "pos": {"col": 2, "row": 0}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})
	var path: Array = [{"col": 1, "row": 0}, {"col": 2, "row": 0}]
	var intent: Dictionary = Adapter.build_intent(profile, goal, path, origin)

	# Default: resolved mirrors planned, byte-for-byte with the previous behaviour.
	var mirrored: Dictionary = Adapter.build_result(
		origin, path, "reached_destination", [], intent, goal
	)
	var mirrored_validation: Dictionary = ResultContract.validate(mirrored)
	if not bool(mirrored_validation["valid"]):
		return _fail("mirrored result invalid: %s @ %s" % [
			mirrored_validation["reason"], mirrored_validation["field"]
		])
	if (mirrored["resolved_action"] as Dictionary) != (mirrored["planned_action"] as Dictionary):
		return _fail("an unsupplied resolution must mirror the plan")
	if (mirrored["planned_action"] as Dictionary).is_empty():
		return _fail("the fixture must carry a non-empty planned_action for this test to mean anything")

	# Divergent: the declared `actor.idle` fallback is what actually resolved.
	var fallback: Dictionary = goal["declared_fallback"] as Dictionary
	var diverged: Dictionary = Adapter.build_result(
		origin, [], "action_invalid_no_fallback", [], intent, goal, fallback
	)
	var diverged_validation: Dictionary = ResultContract.validate(diverged)
	if not bool(diverged_validation["valid"]):
		return _fail("diverged result invalid: %s @ %s" % [
			diverged_validation["reason"], diverged_validation["field"]
		])
	if (diverged["resolved_action"] as Dictionary) != fallback:
		return _fail("resolved_action should report what actually resolved")
	if (diverged["planned_action"] as Dictionary) != (mirrored["planned_action"] as Dictionary):
		return _fail("the plan must survive a divergent resolution unchanged")
	if (diverged["resolved_action"] as Dictionary) == (diverged["planned_action"] as Dictionary):
		return _fail("planned and resolved must be able to differ")
	return _pass()


## SLACK CONFIG MAY NARROW, NEVER WIDEN (plan decision 5).
##
## `MovementOption.validate` enforces `maxi(2, ceili(dist * 0.25))` inline and
## deliberately config-free, as the INVARIANT CONTRACT FLOOR. If
## `data.combat.movement.slack` could widen past it, a config edit would make this
## adapter select targets whose routes the option contract then rejects outright —
## goals the movement layer structurally cannot serve. So the config value is
## clamped DOWN to the contract limit and never up.
##
## The adapter stays PURE: config arrives as a parameter, never a ConfigService call.
static func _t_objective_slack_config_narrows_but_never_widens() -> Dictionary:
	var category_map: Dictionary = {"combat": "combat", "loot": "reward"}
	var weights: Dictionary = {"combat": 0.4, "reward": 1.2}

	# nearest = 1, default envelope = 1 + max(2, ceil(0.25)) = 3, so d=3 is IN and
	# the heavier `reward` category wins.
	var inside: Array = [
		{"id": "sit.near", "pos": {"col": 1, "row": 0}, "type": "combat"},
		{"id": "sit.far", "pos": {"col": 3, "row": 0}, "type": "loot"},
	]
	var inside_field: Dictionary = {"1,0": 1, "3,0": 3}
	var default_pick: String = str(
		Adapter.select_objective_target(inside, inside_field, weights, category_map).get("id", "")
	)
	if default_pick != "sit.far":
		return _fail("baseline (no config) should pick sit.far, got %s" % default_pick)

	# NARROWING works: a zero envelope collapses to "nearest wins".
	var narrowed: String = str(
		Adapter.select_objective_target(
			inside, inside_field, weights, category_map, {"floor": 0, "fraction": 0.0}
		).get("id", "")
	)
	if narrowed != "sit.near":
		return _fail("a narrowed envelope should drop sit.far, got %s" % narrowed)

	# WIDENING is CLAMPED. nearest = 1, contract limit = 2, so the envelope is 3
	# however large the config asks for — d=6 stays outside.
	var outside: Array = [
		{"id": "sit.near", "pos": {"col": 1, "row": 0}, "type": "combat"},
		{"id": "sit.far", "pos": {"col": 6, "row": 0}, "type": "loot"},
	]
	var outside_field: Dictionary = {"1,0": 1, "6,0": 6}
	if str(Adapter.select_objective_target(outside, outside_field, weights, category_map).get("id", "")) != "sit.near":
		return _fail("baseline should already drop the d=6 node")
	for widening_value: Variant in [
		{"floor": 100, "fraction": 10.0},
		{"floor": 99},
		{"fraction": 5.0},
	]:
		var widening: Dictionary = widening_value as Dictionary
		var widened: String = str(
			Adapter.select_objective_target(
				outside, outside_field, weights, category_map, widening
			).get("id", "")
		)
		if widened != "sit.near":
			return _fail(
				"config %s widened past the MovementOption contract floor and picked %s"
				% [str(widening), widened]
			)

	# Broken config can only tighten, never invert the rule.
	var negative: String = str(
		Adapter.select_objective_target(
			inside, inside_field, weights, category_map, {"floor": -50, "fraction": -3.0}
		).get("id", "")
	)
	if negative != "sit.near":
		return _fail("negative config should collapse to nearest-wins, got %s" % negative)

	# The SHIPPED config must reproduce the contract baseline exactly — if
	# balance.json ever drifts above 2 / 0.25 the clamp hides it, so assert the
	# shipped numbers agree rather than merely that the clamp holds.
	var shipped: Dictionary = _load_slack_config()
	if shipped.is_empty():
		return _fail("could not load data.combat.movement.slack from balance.json")
	if int(shipped.get("floor", -1)) != Adapter.SLACK_FLOOR:
		return _fail("shipped slack floor %s != contract floor %d" % [
			str(shipped.get("floor", null)), Adapter.SLACK_FLOOR
		])
	if not is_equal_approx(float(shipped.get("fraction", -1.0)), Adapter.SLACK_FRACTION):
		return _fail("shipped slack fraction %s != contract fraction %f" % [
			str(shipped.get("fraction", null)), Adapter.SLACK_FRACTION
		])
	var shipped_pick: String = str(
		Adapter.select_objective_target(inside, inside_field, weights, category_map, shipped).get("id", "")
	)
	if shipped_pick != default_pick:
		return _fail("the shipped config changed the baseline pick: %s vs %s" % [shipped_pick, default_pick])
	return _pass()


## The id criterion was not a TOTAL order, so `select_objective_target` still fell
## through to array position for the inputs most likely to be malformed.
##
## `str(situation.get("id", ""))` collapses every id-less situation to the same
## `""`, and two situations sharing an id tie outright. In both cases criterion 4
## decided nothing and the winner was whichever came first in `situations[]` —
## precisely the flaw the criterion was added to remove. Criterion 5 (the
## situation's canonical cell key) closes it for any two situations that are not
## co-located; genuine co-located duplicates remain a documented precondition.
static func _t_objective_total_order_survives_missing_ids() -> Dictionary:
	var category_map: Dictionary = {"npc": "intel"}
	var weights: Dictionary = {"intel": 1.4}
	var dist_field: Dictionary = {"3,0": 1, "0,1": 1, "2,2": 1}

	# (1) NO ids at all — every id is "" and criterion 4 is silent.
	var idless: Array = [
		{"pos": {"col": 3, "row": 0}, "type": "npc"},
		{"pos": {"col": 0, "row": 1}, "type": "npc"},
		{"pos": {"col": 2, "row": 2}, "type": "npc"},
	]
	if not _pick_is_order_independent(idless, dist_field, weights, category_map):
		return _fail("id-less situations still resolve by array position")

	# (2) SHARED ids — criterion 4 ties outright.
	var duplicated: Array = [
		{"id": "sit.dup", "pos": {"col": 3, "row": 0}, "type": "npc"},
		{"id": "sit.dup", "pos": {"col": 0, "row": 1}, "type": "npc"},
		{"id": "sit.dup", "pos": {"col": 2, "row": 2}, "type": "npc"},
	]
	if not _pick_is_order_independent(duplicated, dist_field, weights, category_map):
		return _fail("situations sharing an id still resolve by array position")

	# The guard is the canonical cell key, so the pick is the smallest one.
	var chosen: Dictionary = Adapter.select_objective_target(idless, dist_field, weights, category_map)
	if (chosen.get("pos", {}) as Dictionary) != {"col": 0, "row": 1}:
		return _fail("expected the smallest canonical key (0,1), got %s" % str(chosen.get("pos", {})))
	return _pass()


## MANHATTAN REMOVED — diagonal frontiers are no longer systematically demoted.
##
## Criterion 3b used manhattan distance. BFS here is 8-way, so an orthogonal
## candidate d cells away and a diagonal candidate d cells away are EQUIDISTANT in
## travel cost and tie on chebyshev — but manhattan scores them d and 2d, handing
## every such tie to the orthogonal candidate, always. The existing anti-bias test
## cannot see this: manhattan is mirror-symmetric, so the anisotropy survives every
## mirror unchanged. It detects COMPASS bias, never AXIS-vs-DIAGONAL bias.
##
## With manhattan gone, chebyshev (the true 8-way travel metric) leaves the tie to
## criterion 4 — the salted FNV-1a (slice 6 phase 6A unit 4), which is
## axis-agnostic (key order is now the collision-only criterion 5, NOT this
## tie-break). So the equidistant diagonal is no longer pre-empted: it wins under
## some salts and loses under others, exactly like the orthogonal. This test proves
## the axis is no longer decisive by exhibiting BOTH outcomes across a set of stage
## salts, rather than pinning a single key-order answer the salted guard no longer
## produces.
static func _t_frontier_diagonal_not_deprioritised_by_manhattan() -> Dictionary:
	var board: Dictionary = _full_walkable(5, 5)
	var party: Dictionary = {"col": 2, "row": 2}
	# Equidistant tie: (0,0) is a diagonal at chebyshev 2, (2,4) an orthogonal at
	# chebyshev 2. Both BFS 2, so criteria 1-3 tie and the salted criterion 4 decides.
	var equidistant: Array = [{"col": 2, "row": 4}, {"col": 0, "row": 0}]
	# Real travel cost: (3,3) is a diagonal at BFS 1, (2,0) an orthogonal at BFS 2.
	var nearer_pair: Array = [{"col": 2, "row": 0}, {"col": 3, "row": 3}]

	var diagonal_seen: bool = false
	var orthogonal_seen: bool = false
	for realm: int in range(1, 7):
		for stage: int in range(0, 10):
			var salt: String = "realm.%02d.stage.%02d" % [realm, stage]

			# The salted criterion 4 breaks the equidistant tie. Under the OLD manhattan
			# rule the diagonal scored 4 against the orthogonal's 2 and could NEVER win,
			# for ANY salt; now it can, and so can the orthogonal.
			var tie_pick: Dictionary = Adapter.select_frontier(equidistant, party, {}, board, salt)
			if tie_pick == {"col": 0, "row": 0}:
				diagonal_seen = true
			elif tie_pick == {"col": 2, "row": 4}:
				orthogonal_seen = true
			else:
				return _fail("equidistant tie picked an off-list cell %s at salt %s" % [str(tie_pick), salt])

			# Real travel cost LEADS the hash: the nearer diagonal (BFS 1) beats the
			# farther orthogonal (BFS 2) under EVERY salt, because criterion 1 settles it
			# before the hash is consulted — no matter how manhattan would have scored it.
			var nearer: Dictionary = Adapter.select_frontier(nearer_pair, party, {}, board, salt)
			if nearer != {"col": 3, "row": 3}:
				return _fail(
					"the nearer diagonal (BFS 1) must beat the farther orthogonal (BFS 2) for every "
					+ "salt; salt %s picked %s" % [salt, str(nearer)]
				)

	# The diagonal winning under some salt is the direct proof manhattan is gone; the
	# orthogonal winning under some salt proves the residual rule is axis-agnostic,
	# not a diagonal preference swapped in for the old orthogonal one.
	if not diagonal_seen:
		return _fail(
			"manhattan appears to be back: the equidistant diagonal (0,0) never beat the "
			+ "orthogonal (2,4) under any salt — it is still being systematically demoted"
		)
	if not orthogonal_seen:
		return _fail(
			"the equidistant orthogonal (2,4) never won — the residual rule is a diagonal "
			+ "preference, not the axis-agnostic tie-break it should be"
		)
	return _pass()


## True when the pick is the same for every rotation and the reversal.
static func _pick_is_order_independent(
	situations: Array,
	dist_field: Dictionary,
	weights: Dictionary,
	category_map: Dictionary
) -> bool:
	var baseline: Dictionary = Adapter.select_objective_target(
		situations, dist_field, weights, category_map
	)
	if baseline.is_empty():
		return false
	for offset: int in range(situations.size()):
		var rotated: Array = []
		for index: int in range(situations.size()):
			rotated.append(situations[(index + offset) % situations.size()])
		if Adapter.select_objective_target(rotated, dist_field, weights, category_map) != baseline:
			return false
	var reversed_situations: Array = situations.duplicate(true)
	reversed_situations.reverse()
	return Adapter.select_objective_target(
		reversed_situations, dist_field, weights, category_map
	) == baseline


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

## Reads a `data.<section>` object straight out of balance.json so config-shaped
## assertions follow the shipped config instead of duplicating its numbers.
static func _load_balance_section(path: Array) -> Dictionary:
	var file: FileAccess = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var cursor: Dictionary = parsed as Dictionary
	for key_value: Variant in path:
		var next_value: Variant = cursor.get(str(key_value), {})
		if not next_value is Dictionary:
			return {}
		cursor = next_value as Dictionary
	return cursor


static func _load_directives() -> Dictionary:
	return _load_balance_section(["data", "directives"])


## `data.stages.situation_category` — the map live FlowRuntime._find_explore_target
## uses to turn a situation `type` into a target_preference category.
static func _load_situation_category() -> Dictionary:
	return _load_balance_section(["data", "stages", "situation_category"])


## `data.combat.movement.slack` — the slice-6 phase-6A seam (Unit 1). The adapter
## never loads this itself; the caller injects it, so the test does too.
static func _load_slack_config() -> Dictionary:
	return _load_balance_section(["data", "combat", "movement", "slack"])


## Explicit full-rectangle walkable set (never the empty legacy sentinel).
static func _full_walkable(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for col: int in range(width):
		for row: int in range(height):
			cells["%d,%d" % [col, row]] = true
	return cells


## Situations carry `type`, never a fabricated `category` — see the file header.
static func _explore_map(party_pos: Dictionary) -> Dictionary:
	return {
		"party_pos": party_pos.duplicate(true),
		"situations": [
			{"id": "sit.obj", "pos": {"col": 3, "row": 2}, "type": "ritual", "is_objective": true, "resolved": false},
			{"id": "sit.intel", "pos": {"col": 2, "row": 4}, "type": "npc", "is_objective": false, "resolved": false},
		],
	}


static func _mirror_cell(cell: Dictionary, flip_h: bool, flip_v: bool, width: int, height: int) -> Dictionary:
	var col: int = int(cell["col"])
	var row: int = int(cell["row"])
	if flip_h:
		col = width - 1 - col
	if flip_v:
		row = height - 1 - row
	return {"col": col, "row": row}


## A heading is a DELTA, so mirroring negates the affected axis rather than
## reflecting it through the board.
static func _mirror_delta(delta: Dictionary, flip_h: bool, flip_v: bool) -> Dictionary:
	if delta.is_empty():
		return {}
	var col: int = int(delta.get("col", 0))
	var row: int = int(delta.get("row", 0))
	if flip_h:
		col = -col
	if flip_v:
		row = -row
	return {"col": col, "row": row}


static func _mirror_cells(cells: Array, flip_h: bool, flip_v: bool, width: int, height: int) -> Array:
	var mirrored: Array = []
	for cell_value: Variant in cells:
		mirrored.append(_mirror_cell(cell_value as Dictionary, flip_h, flip_v, width, height))
	return mirrored


static func _mirror_walkable(walkable: Dictionary, flip_h: bool, flip_v: bool, width: int, height: int) -> Dictionary:
	var mirrored: Dictionary = {}
	for key_value: Variant in walkable.keys():
		var parts: PackedStringArray = str(key_value).split(",")
		var cell: Dictionary = _mirror_cell(
			{"col": int(parts[0]), "row": int(parts[1])}, flip_h, flip_v, width, height
		)
		mirrored["%d,%d" % [int(cell["col"]), int(cell["row"])]] = true
	return mirrored


## Maps a chosen ring cell back to its compass label, or "" if off the ring.
static func _compass_label(ring: Array, chosen: Dictionary) -> String:
	for entry_value: Variant in ring:
		var entry: Array = entry_value as Array
		if (entry[1] as Dictionary) == chosen:
			return str(entry[0])
	return ""


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
