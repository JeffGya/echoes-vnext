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
#   * `frontier_headingless_tie_pins_known_bias` is a CHARACTERISATION test. Its
#     expected values are the CURRENT BIASED answers, deliberately pinned rather
#     than fixed — see the retraction block in StagePartyMovementAdapter.gd.
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
	runner.register_test("movement/stage_party/frontier_headingless_tie_pins_known_bias", Callable(StagePartyMovementTests, "_t_frontier_headingless_tie_pins_known_bias"))
	runner.register_test("movement/stage_party/frontier_diagonal_two_solid_corners_refused", Callable(StagePartyMovementTests, "_t_frontier_diagonal_two_solid_corners_refused"))
	runner.register_test("movement/stage_party/frontier_diagonal_one_solid_corner_allowed", Callable(StagePartyMovementTests, "_t_frontier_diagonal_one_solid_corner_allowed"))
	runner.register_test("movement/stage_party/objective_weight_leads_within_slack", Callable(StagePartyMovementTests, "_t_objective_weight_leads_within_slack"))
	runner.register_test("movement/stage_party/objective_slack_envelope_bounds_detour", Callable(StagePartyMovementTests, "_t_objective_slack_envelope_bounds_detour"))
	runner.register_test("movement/stage_party/objective_weight_then_distance_then_id", Callable(StagePartyMovementTests, "_t_objective_weight_then_distance_then_id"))
	runner.register_test("movement/stage_party/objective_category_derived_from_type", Callable(StagePartyMovementTests, "_t_objective_category_derived_from_type"))
	runner.register_test("movement/stage_party/objective_independent_of_array_order", Callable(StagePartyMovementTests, "_t_objective_independent_of_array_order"))
	runner.register_test("movement/stage_party/deterministic_replay_and_purity", Callable(StagePartyMovementTests, "_t_deterministic_replay_and_purity"))


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

## Every moving stage goal is a `reposition` (slice 5 amendment A6 — see the
## build_goal docblock for why `advance` is unavailable without laundering a
## situation id as an actor). Tier ordering lives in `urgency`, asserted next.
static func _t_goal_validates_for_every_tier() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var explore_map: Dictionary = _explore_map({"col": 0, "row": 0})
	var party: Dictionary = {"col": 0, "row": 0}

	var tiers: Array = [
		[Adapter.TIER_OBJECTIVE, {"id": "sit.obj", "pos": {"col": 3, "row": 2}}, "reposition"],
		[Adapter.TIER_PASSED_OBJECTIVE, {"id": "sit.obj", "pos": {"col": 3, "row": 2}}, "reposition"],
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
## `intent_validates_and_excludes_origin`, which was a lie — `build_intent` does
## NOT enforce path-excludes-origin, so the assertion only ever proved the
## FIXTURE excluded the origin. The seam is unguarded and is recorded as
## slice-6 carry-forward in docs/integration-map.md. What is genuinely asserted
## here is that a supplied path validates and that commitment tracks its length.
static func _t_intent_validates_supplied_path() -> Dictionary:
	var walkable: Dictionary = _full_walkable(6, 6)
	var party: Dictionary = {"col": 0, "row": 0}
	var explore_map: Dictionary = _explore_map(party)
	var goal: Dictionary = Adapter.build_goal(
		explore_map, {"id": "sit.obj", "pos": {"col": 2, "row": 0}}, Adapter.TIER_OBJECTIVE, walkable
	)
	var profile: Dictionary = Adapter.build_profile({"id": SCOUT_ID, "step_budget": 3})

	var moving: Dictionary = Adapter.build_intent(
		profile, goal, [{"col": 1, "row": 0}, {"col": 2, "row": 0}]
	)
	var moving_validation: Dictionary = IntentContract.validate(moving, party)
	if not bool(moving_validation["valid"]):
		return _fail("intent invalid: %s @ %s" % [moving_validation["reason"], moving_validation["field"]])
	if int(moving["commitment"]) != 2:
		return _fail("commitment should equal the path length, got %d" % int(moving["commitment"]))

	# Zero-step: EMPTY array, never [origin].
	var still: Dictionary = Adapter.build_intent(profile, goal, [])
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
	var intent: Dictionary = Adapter.build_intent(profile, goal, long_path)
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
	var intent: Dictionary = Adapter.build_intent(profile, goal, [])

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
	var intent: Dictionary = Adapter.build_intent(profile, goal, path)

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
	# fabricated "hold" over a genuine multi-cell walk.
	if str(result["purpose"]) != "reposition":
		return _fail("a multi-cell walk must not report purpose %s" % str(result["purpose"]))
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
## through to criterion 4 are NOT bias-free and are pinned separately by
## `frontier_headingless_tie_pins_known_bias`.
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


## CHARACTERISATION TEST — slice 5 amendment A1.
##
## THE EXPECTED VALUES BELOW ARE THE CURRENT *BIASED* ANSWERS. This test does not
## assert correct behaviour; it PINS a known bias so that removing it at slice 6
## is a deliberate, visible change rather than a silent one. Do not "fix" this
## test — fix the algorithm, then update it.
##
## An earlier draft of the adapter called criterion 4 "unreachable in practice".
## That was false on two counts:
##
##   1. It is trivially reachable. A mirrored, headingless pair ties BFS distance,
##      heading continuation, chebyshev AND manhattan, so criterion 4 decides.
##      Worse, no `heading` value is produced anywhere in core/ today, so at
##      cutover criterion 2 scores 0 for EVERY selection and criterion 4 becomes
##      the effective tie-breaker rather than a last resort.
##   2. It is not "row/col ordering". `canonical_cell_key` yields "col,row" and
##      the comparison is a lexicographic STRING compare, so "10,3" < "9,3". The
##      order is jagged and non-monotone in either axis — neither row-major nor
##      col-major — which the second half of this test demonstrates directly.
static func _t_frontier_headingless_tie_pins_known_bias() -> Dictionary:
	# (1) The reviewers' counterexample: party (2,2), candidates (2,0) and (2,4),
	#     no heading, fully walkable 5x5. Everything ties; criterion 4 picks NORTH.
	var open_board: Dictionary = _full_walkable(5, 5)
	var north_south: Dictionary = Adapter.select_frontier(
		[{"col": 2, "row": 0}, {"col": 2, "row": 4}], {"col": 2, "row": 2}, {}, open_board
	)
	if north_south != {"col": 2, "row": 0}:
		return _fail(
			"PINNED BIAS CHANGED: headingless (2,0)/(2,4) from (2,2) returned %s, "
			% str(north_south)
			+ "expected the biased (2,0). If criterion 4 was fixed, update this test."
		)

	# (2) The same tie on the west/east axis at LOW coordinates picks WEST...
	var low_west_east: Dictionary = Adapter.select_frontier(
		[{"col": 1, "row": 2}, {"col": 3, "row": 2}], {"col": 2, "row": 2}, {}, open_board
	)
	if low_west_east != {"col": 1, "row": 2}:
		return _fail(
			"PINNED BIAS CHANGED: headingless (1,2)/(3,2) from (2,2) returned %s, expected (1,2)"
			% str(low_west_east)
		)

	# ...but the identical geometry across the 9/10 column boundary picks EAST,
	# because "11,3" < "9,3" as STRINGS. Same shape, opposite compass answer:
	# proof the guard is neither row-major nor col-major, just jagged.
	var wide_board: Dictionary = _full_walkable(13, 7)
	var high_west_east: Dictionary = Adapter.select_frontier(
		[{"col": 9, "row": 3}, {"col": 11, "row": 3}], {"col": 10, "row": 3}, {}, wide_board
	)
	if high_west_east != {"col": 11, "row": 3}:
		return _fail(
			"PINNED BIAS CHANGED: headingless (9,3)/(11,3) from (10,3) returned %s, expected (11,3)"
			% str(high_west_east)
		)
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
		var intent: Dictionary = Adapter.build_intent(profile, goal, path)
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


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
