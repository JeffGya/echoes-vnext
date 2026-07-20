# res://tests/SpatialModeGoalTests.gd
# V2-COMBAT-002 Slice 4, Unit D — spatial modes + escape-graph cutoff wiring.
#
# Covers the DORMANT spatial realisation added to CombatPressureService:
#   - board fall-back (`withdraw`) carries a real, threat-aware destination region;
#   - PURSUE / PROTECT cutoff targets come from PursueEscapeService's escape-graph
#     corridor rather than geometric nearest-edge;
#   - screening and interception target real interposition cells.
#
# Nothing here touches live combat: the service is pure and only tests consume it.

class_name SpatialModeGoalTests
extends RefCounted

const Service = preload("res://core/movement/CombatPressureService.gd")
const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const PressureContract = preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const EscapeAuthority = preload("res://core/movement/PursueEscapeService.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/spatial/withdraw_real_fallback_region", Callable(SpatialModeGoalTests, "_t_withdraw_real_fallback_region"))
	runner.register_test("movement/spatial/withdraw_distinct_from_advance", Callable(SpatialModeGoalTests, "_t_withdraw_distinct_from_advance"))
	runner.register_test("movement/spatial/withdraw_ignores_authored_fallback_region", Callable(SpatialModeGoalTests, "_t_withdraw_ignores_authored_fallback_region"))
	runner.register_test("movement/spatial/objective_alignment_never_withdraws", Callable(SpatialModeGoalTests, "_t_objective_alignment_never_withdraws"))
	runner.register_test("movement/spatial/cutoff_uses_escape_corridor", Callable(SpatialModeGoalTests, "_t_cutoff_uses_escape_corridor"))
	runner.register_test("movement/spatial/cutoff_carrier_escape_graph", Callable(SpatialModeGoalTests, "_t_cutoff_carrier_escape_graph"))
	runner.register_test("movement/spatial/cutoff_overrides_authored_fallback", Callable(SpatialModeGoalTests, "_t_cutoff_overrides_authored_fallback"))
	runner.register_test("movement/spatial/authored_regions_hold_outside_cutoff", Callable(SpatialModeGoalTests, "_t_authored_regions_hold_outside_cutoff"))
	runner.register_test("movement/spatial/screen_cells_interpose", Callable(SpatialModeGoalTests, "_t_screen_cells_interpose"))
	runner.register_test("movement/spatial/intercept_cells_stand_off_lane", Callable(SpatialModeGoalTests, "_t_intercept_cells_stand_off_lane"))
	runner.register_test("movement/spatial/mirrored_board_no_axis_bias", Callable(SpatialModeGoalTests, "_t_mirrored_board_no_axis_bias"))
	runner.register_test("movement/spatial/deterministic_replay", Callable(SpatialModeGoalTests, "_t_deterministic_replay"))
	runner.register_test("movement/spatial/seven_mode_invariants_hold", Callable(SpatialModeGoalTests, "_t_seven_mode_invariants_hold"))
	runner.register_test("movement/spatial/publishes_no_objective_authority", Callable(SpatialModeGoalTests, "_t_publishes_no_objective_authority"))
	runner.register_test("movement/spatial/interposition_stays_on_board", Callable(SpatialModeGoalTests, "_t_interposition_stays_on_board"))
	runner.register_test("movement/spatial/goal_cap_holds_under_collapse", Callable(SpatialModeGoalTests, "_t_goal_cap_holds_under_collapse"))
	runner.register_test("movement/spatial/stolen_carrier_cutoff_region", Callable(SpatialModeGoalTests, "_t_stolen_carrier_cutoff_region"))
	runner.register_test("movement/spatial/corridor_identical_with_authored_terrain", Callable(SpatialModeGoalTests, "_t_corridor_identical_with_authored_terrain"))
	runner.register_test("movement/spatial/no_tactical_goal_when_all_regions_empty", Callable(SpatialModeGoalTests, "_t_no_tactical_goal_when_all_regions_empty"))
	runner.register_test("movement/spatial/golden_derived_screen_region", Callable(SpatialModeGoalTests, "_t_golden_derived_screen_region"))


# ---------------------------------------------------------------------------
# BOARD FALL-BACK (`withdraw`)
# ---------------------------------------------------------------------------

## A collapsing mover receives a withdraw goal whose every cell is strictly
## farther from the nearest hostile than the mover's current cell, is walkable,
## unoccupied, and reachable — i.e. a real destination, not an approximation.
##
## Note on the occupancy claim: `_board_fallback_region` itself applies NO
## occupancy filter (its 4th `reachable_cost_region` argument is `terrain_costs`).
## Occupancy is enforced one seam later, in `_truthful_region`, which `_add_goal`
## runs over EVERY published region regardless of which producer built it. So the
## claim is about the goal this service publishes, not about the raw producer —
## and the ally planted below makes it a real assertion rather than a coincidence
## of the threat-distance filter.
static func _t_withdraw_real_fallback_region() -> Dictionary:
	var context: Dictionary = _open_context("combat", "party")
	_set_mover_health(context, 0.4)
	# Mover (1,3), hostile (6,3) -> origin threat distance 5, so the derived region
	# is exactly column 0 (threat distance 6). Park a living ally ON that column at
	# (0,3): the threat filter would KEEP this cell, so only the occupancy gate can
	# remove it. Without this the "unoccupied" assertion below is vacuous — the
	# fixture's other occupied cells are already excluded on threat distance alone.
	var ally: Dictionary = _actor("echo.ally", {"col": 0, "row": 3}, "echo")
	(context["perceived_actors"] as Array).append(ally)
	(context["relationships"] as Dictionary)["echo.ally"] = "friendly"
	(context["occupancy"] as Dictionary)["0,3"] = "echo.ally"

	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("collapsing mover rejected: %s" % str(result))
	var withdraw: Dictionary = _goal(result, "withdraw")
	if withdraw.is_empty():
		return _fail("collapsing mover produced no board fall-back: %s" % str(result["goals"]))
	var region: Array = withdraw["destination_region"] as Array
	if region.is_empty():
		return _fail("withdraw carried an empty destination region")
	if str((withdraw["planned_primary"] as Dictionary)["type"]) != "actor.move":
		return _fail("withdraw did not plan a move")
	var origin: Dictionary = context["origin"] as Dictionary
	var hostiles: Array = _hostile_positions(context)
	var origin_threat: int = _threat_distance(origin, hostiles)
	var walkable: Dictionary = context["authoritative_walkable"] as Dictionary
	var occupancy: Dictionary = context["occupancy"] as Dictionary
	for cell_value: Variant in region:
		var cell: Dictionary = cell_value as Dictionary
		if _threat_distance(cell, hostiles) <= origin_threat:
			return _fail("withdraw cell %s was not safer than origin" % str(cell))
		if not bool(walkable.get(V.canonical_cell_key(cell), false)):
			return _fail("withdraw cell %s was not walkable" % str(cell))
		if occupancy.has(V.canonical_cell_key(cell)):
			return _fail("withdraw cell %s was occupied" % str(cell))
		if _chebyshev(cell, origin) > Service.FALLBACK_RADIUS:
			return _fail("withdraw cell %s was beyond the reachable radius" % str(cell))
	# The planted ally's cell passes every OTHER filter (walkable, in radius, and
	# strictly safer than the origin), so its absence proves the occupancy gate ran.
	var ally_cell := {"col": 0, "row": 3}
	if _threat_distance(ally_cell, hostiles) <= origin_threat:
		return _fail("fixture drift: the ally cell is no longer safer than the origin, so the occupancy assertion is vacuous again")
	if region.has(ally_cell):
		return _fail("withdraw region included the ally-occupied cell %s" % str(ally_cell))
	# A healthy mover on the identical board must NOT fall back — the goal is
	# gated on collapse, so a healthy board is completely unaffected.
	var healthy: Dictionary = _open_context("combat", "party")
	if not _goal(Service.build_goals(healthy), "withdraw").is_empty():
		return _fail("healthy mover produced a board fall-back")
	return _pass()


## The fall-back must be a genuinely different piece of ground from the advance
## goal — retreat and approach cannot be the same region.
static func _t_withdraw_distinct_from_advance() -> Dictionary:
	var context: Dictionary = _open_context("combat", "party")
	_set_mover_health(context, 0.3)
	var result: Dictionary = Service.build_goals(context)
	var withdraw: Dictionary = _goal(result, "withdraw")
	var advance: Dictionary = _goal(result, "advance")
	if withdraw.is_empty() or advance.is_empty():
		return _fail("expected both withdraw and advance: %s" % str(result["goals"]))
	if str(withdraw["purpose"]) == str(advance["purpose"]):
		return _fail("withdraw and advance collapsed to one purpose")
	for cell_value: Variant in withdraw["destination_region"] as Array:
		if (advance["destination_region"] as Array).has(cell_value):
			return _fail("withdraw shared cell %s with advance" % str(cell_value))
	return _pass()


## FIX 6 — `withdraw` must NOT borrow `pressure["fallback_region"]`.
##
## That key is MODE-SPECIFIC authored terrain sharing only a NAME with the board
## fall-back. In PURSUE it is the CONTAINMENT region: the net the hunters drive the
## QUARRY into. A wounded pursuer retreating into its own trap ground is exactly
## backwards, so the withdraw goal always uses its own derived, threat-distance
## region instead.
##
## (This replaces an earlier test that asserted the opposite — see the PURSUE case
## below for why "prefer the authored region" was the wrong rule here.)
static func _t_withdraw_ignores_authored_fallback_region() -> Dictionary:
	# --- 1. A generic authored fallback_region does not capture the withdraw goal.
	var context: Dictionary = _open_context("combat", "party")
	_set_mover_health(context, 0.4)
	var authored: Array = [{"col": 0, "row": 0}]
	(context["objective_pressure"] as Dictionary)["fallback_region"] = authored
	var result: Dictionary = Service.build_goals(context)
	var withdraw: Dictionary = _goal(result, "withdraw")
	if withdraw.is_empty():
		return _fail("collapsing mover produced no withdraw")
	var region: Array = withdraw["destination_region"] as Array
	if region == authored:
		return _fail("withdraw borrowed the mode-specific fallback_region: %s" % str(region))

	# The derived region must be identical to the no-authored-terrain case: the
	# authored key is IGNORED for this goal, not merely outranked.
	var clean: Dictionary = _open_context("combat", "party")
	_set_mover_health(clean, 0.4)
	var clean_withdraw: Dictionary = _goal(Service.build_goals(clean), "withdraw")
	if clean_withdraw.is_empty():
		return _fail("clean context produced no withdraw")
	if region != (clean_withdraw["destination_region"] as Array):
		return _fail("authored fallback_region perturbed the derived withdraw region: %s vs %s" % [
			str(region), str(clean_withdraw["destination_region"])])

	# --- 2. THE MOTIVATING CASE: in PURSUE, fallback_region IS the containment net.
	var pursue: Dictionary = _open_context("pursue", "party")
	_set_mover_health(pursue, 0.4)
	# Containment ground sits AROUND THE QUARRY at (6,3) — the ground the hunters
	# want the quarry pushed onto, and the last place a broken hunter should flee.
	var containment: Array = [
		{"col": 5, "row": 2}, {"col": 5, "row": 3}, {"col": 5, "row": 4},
	]
	(pursue["objective_pressure"] as Dictionary)["fallback_region"] = containment
	var pursue_result: Dictionary = Service.build_goals(pursue)
	if not bool(pursue_result["valid"]):
		return _fail("collapsing pursuer rejected: %s" % str(pursue_result))
	var pursue_withdraw: Dictionary = _goal(pursue_result, "withdraw")
	if pursue_withdraw.is_empty():
		return _fail("collapsing pursuer produced no withdraw")
	var pursue_region: Array = pursue_withdraw["destination_region"] as Array
	if pursue_region.is_empty():
		return _fail("pursue withdraw carried an empty region")
	for cell_value: Variant in pursue_region:
		if containment.has(cell_value):
			return _fail("wounded pursuer would retreat INTO its own containment net at %s" % str(cell_value))
	# And it is genuinely a retreat: every cell is farther from the quarry than the
	# mover's own cell.
	var hostiles: Array = _hostile_positions(pursue)
	var origin_threat: int = _threat_distance(pursue["origin"] as Dictionary, hostiles)
	for cell_value2: Variant in pursue_region:
		if _threat_distance(cell_value2 as Dictionary, hostiles) <= origin_threat:
			return _fail("pursue withdraw cell %s was not safer than origin" % str(cell_value2))
	return _pass()


## THE FROZEN-DECISION GUARD: `_add_board_fallback` early-returns for
## `mover_alignment == "objective"`, and that early return is the only thing
## protecting a ratified design decision — the PURSUE quarry's timing and economy
## stay untouched, and the non-joining GUIDE spirit keeps its authored pace.
## Neither may ever be handed a `withdraw` safety goal, however badly hurt.
##
## Both pre-existing loops iterate only ["party", "hostile"], so the third
## alignment was never exercised. This closes that.
##
## Scope: `build_goals` short-circuits to ZERO goals for an objective-aligned mover
## that is not an AUTHORED one (`_is_authored_objective_mover`), so the only two
## contexts that actually REACH `_add_board_fallback` on this alignment are the two
## the frozen decision names — PURSUE/quarry and GUIDE_SPIRIT/spirit with
## `spirit_joins_battle == false`. Those are exactly the cases pinned here; a
## broader mode sweep would exercise the earlier short-circuit instead and pass
## without ever touching the guard.
##
## What is asserted is the absence of the BOARD FALL-BACK specifically, not the
## absence of the `withdraw` purpose. PURSUE/quarry legitimately emits its OWN
## `withdraw` — the authored escape run toward `destination_region`, at CRITICAL in
## BUCKET_DIRECT. The two are told apart by the goal_role segment of `goal_id`
## (`_add_goal` formats "goal.<mode>.<purpose>.<role>.c#r#"): the authored escape
## carries role "quarry", the board fall-back always carries role "baseline".
## Asserting on the purpose alone would wrongly forbid the quarry's own escape.
##
## The test is SELF-GUARDING: each case first proves that the IDENTICAL board and
## the identical collapse DO produce a board fall-back when the mover is
## party-aligned and baseline-role. Without that control the test could pass
## vacuously — if the fixture stopped collapsing, or the board stopped offering
## safer ground, the claim would hold for the wrong reason.
static func _t_objective_alignment_never_withdraws() -> Dictionary:
	for case: Array in [["pursue", "quarry"], ["guide_spirit", "spirit"]]:
		var mode: String = str(case[0])
		var role: String = str(case[1])

		# --- Control: same board, same collapse, ordinary party mover MUST fall back.
		var control: Dictionary = _authored_objective_mover_context(mode, "party", "baseline")
		var control_result: Dictionary = Service.build_goals(control)
		if not bool(control_result["valid"]):
			return _fail("%s control rejected: %s" % [mode, str(control_result)])
		if not _has_board_fallback(control_result):
			return _fail(
				"%s/baseline control produced no board fall-back — the fixture no longer collapses onto safer ground, so the objective-alignment claim below would be vacuous: %s"
				% [mode, str(control_result["goals"])]
			)

		# --- The claim: the authored objective mover never gets the safety goal.
		var objective_ctx: Dictionary = _authored_objective_mover_context(mode, "objective", role)
		var result: Dictionary = Service.build_goals(objective_ctx)
		if not bool(result["valid"]):
			return _fail("%s/%s objective-aligned rejected: %s" % [mode, role, str(result)])
		# Proves we reached the alignment guard rather than the earlier
		# not-an-authored-objective-mover short circuit, which yields zero goals.
		if (result["goals"] as Array).is_empty():
			return _fail(
				"%s/%s produced no goals at all — this hit the authored-objective short circuit, not the alignment guard"
				% [mode, role]
			)
		if _has_board_fallback(result):
			return _fail(
				"%s/%s received a board fall-back — the quarry's timing/economy and the spirit's authored pace are no longer protected: %s"
				% [mode, role, str(result["goals"])]
			)
	return _pass()


## True when a result carries the BOARD FALL-BACK goal from `_add_board_fallback`,
## which `_add_goal` always stamps with the "baseline" goal_role — as distinct from
## an authored `withdraw` such as the quarry's escape run (role "quarry").
static func _has_board_fallback(result: Dictionary) -> bool:
	if not bool(result.get("valid", false)):
		return false
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if str(goal["purpose"]) != "withdraw":
			continue
		if str(goal["goal_id"]).contains(".withdraw.baseline."):
			return true
	return false


## Open 7x7 board holding a COLLAPSING mover at {1,3} with a single hostile at
## {6,3}, so column 0 is real, reachable, strictly-safer fall-back ground.
##
## `role` selects who the mover factually is: "quarry" / "spirit" wire the matching
## `*_id` to the mover and set the matching fact flag, which is what makes it an
## AUTHORED objective mover; "baseline" leaves it an ordinary combatant for use as
## the control. `spirit_joins_battle` stays false so the spirit case stays on the
## non-joining path the frozen decision protects.
static func _authored_objective_mover_context(
	mode: String, alignment: String, role: String
) -> Dictionary:
	var mover_id: String = "enemy.mover"
	var hostile_id: String = "echo.1"
	var mover: Dictionary = _actor(mover_id, {"col": 1, "row": 3}, "enemy")
	mover["is_quarry"] = role == "quarry"
	mover["is_spirit"] = role == "spirit"
	mover["health_ratio"] = 0.4
	var hostile: Dictionary = _actor(hostile_id, {"col": 6, "row": 3}, "echo")
	# The far-end goal marker the quarry runs for / the spirit is escorted toward.
	var marker: Dictionary = _actor("objective.relic", {"col": 3, "row": 6}, "structure", true)
	var cells: Dictionary = _open_cells(7, 7)
	# A real authored destination (the ground beside the goal marker) so the
	# AUTHORED goal for each role actually materialises — the quarry's own escape
	# run, the non-joining spirit's advance. Without it `_add_goal` drops the empty
	# region and the context yields zero goals, which is indistinguishable from the
	# authored-objective short circuit this test must prove it got past. `advance`
	# additionally requires a non-empty objective_id present in relevant_actors.
	var pressure: Dictionary = PressureContract.build(
		mode, "escort" if mode == "guide_spirit" else "", alignment, role,
		true, "objective.relic", {"col": 3, "row": 6},
		[{"col": 3, "row": 5}], [], [], [],
		"", "", "",
		mover_id if role == "quarry" else "",
		mover_id if role == "spirit" else "",
		0.8, 1, 4, false, false, false, []
	)
	return ContextContract.build(
		mover_id, "activation.authored_objective", {"col": 1, "row": 3}, {"w": 7, "h": 7},
		cells, cells, {"1,3": mover_id, "6,3": hostile_id, "3,6": "objective.relic"},
		[mover, hostile, marker],
		{mover_id: "friendly", hostile_id: "hostile", "objective.relic": "neutral"},
		{}, [], pressure, []
	)


# ---------------------------------------------------------------------------
# ESCAPE-GRAPH CUTOFF
# ---------------------------------------------------------------------------

## The decisive test: on a walled board whose only route to the escape line runs
## through a single gap, the cutoff region must contain that CHOKEPOINT and must
## NOT contain an off-route cell that merely sits next to the escape line.
## Geometric nearest-edge targeting would pick the off-route cell; escape-graph
## projection cannot.
static func _t_cutoff_uses_escape_corridor() -> Dictionary:
	var context: Dictionary = _chokepoint_context()
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("chokepoint pursue rejected: %s" % str(result))
	var cut_off: Dictionary = _goal(result, "cut_off")
	if cut_off.is_empty():
		return _fail("silent authority did not yield a projected cutoff: %s" % str(result["goals"]))
	var region: Array = cut_off["destination_region"] as Array
	var chokepoint := {"col": 3, "row": 3}
	if not region.has(chokepoint):
		return _fail("cutoff missed the only chokepoint %s: %s" % [str(chokepoint), str(region)])
	# {6,5} is adjacent to the escape line (row 6) but off every shortest route
	# out of the gap — the exact cell naive nearest-edge geometry would target.
	var off_route := {"col": 6, "row": 5}
	if region.has(off_route):
		return _fail("cutoff targeted off-route cell %s — projection is geometric" % str(off_route))
	if str((cut_off["planned_primary"] as Dictionary)["type"]) != "actor.guard":
		return _fail("cutoff did not plan a guard")
	return _pass()


## PROTECT: once the totem is stolen the carrier is an escaper, so its cutoff is
## projected from the carrier's own escape graph rather than the objective
## approach lane (which points the wrong way after custody is taken).
static func _t_cutoff_carrier_escape_graph() -> Dictionary:
	var context: Dictionary = _chokepoint_context("protect")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["totem_stolen"] = true
	pressure["carrier_id"] = "enemy.1"
	pressure["approach_region"] = [{"col": 0, "row": 0}]
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("carrier cutoff rejected: %s" % str(result))
	var cut_off: Dictionary = _goal(result, "cut_off")
	if cut_off.is_empty():
		return _fail("stolen-totem carrier produced no cutoff: %s" % str(result["goals"]))
	var region: Array = cut_off["destination_region"] as Array
	if region == [{"col": 0, "row": 0}]:
		return _fail("carrier cutoff fell back to the geometric approach lane")
	if not region.has({"col": 3, "row": 3}):
		return _fail("carrier cutoff missed the chokepoint: %s" % str(region))
	return _pass()


## THE MAIN PURSUE PATH (§13.6, Jeff-ratified): the escape-graph corridor is the
## PRIMARY cutoff target. Even when the objective authority DOES author a
## containment region, cutoff targeting is projected from the quarry's real
## traversable escape graph — authored ground describes where we would like to
## stand, only the corridor describes ground that actually cuts the quarry off.
static func _t_cutoff_overrides_authored_fallback() -> Dictionary:
	var context: Dictionary = _chokepoint_context()
	var authored: Array = [{"col": 0, "row": 5}]
	(context["objective_pressure"] as Dictionary)["fallback_region"] = authored
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("authored-fallback pursue rejected: %s" % str(result))
	var cut_off: Dictionary = _goal(result, "cut_off")
	if cut_off.is_empty():
		return _fail("authored fallback suppressed the projected cutoff: %s" % str(result["goals"]))
	var region: Array = cut_off["destination_region"] as Array
	if region == authored:
		return _fail("cutoff deferred to authored terrain instead of the corridor")
	if region.has({"col": 0, "row": 5}):
		return _fail("cutoff retained authored off-corridor ground {0,5}")
	if not region.has({"col": 3, "row": 3}):
		return _fail("cutoff missed the chokepoint despite authored terrain: %s" % str(region))
	if region.has({"col": 6, "row": 5}):
		return _fail("cutoff targeted an off-route cell")
	# The corridor must be identical whether or not terrain was authored: cutoff
	# targeting depends only on the quarry's escape graph.
	var silent: Dictionary = _chokepoint_context()
	var silent_region: Array = _goal(Service.build_goals(silent), "cut_off")["destination_region"] as Array
	if region != silent_region:
		return _fail("authored terrain perturbed the projected corridor")
	return _pass()


## Authored regions still win everywhere that is NOT cutoff targeting: the
## geometric approach lane remains PURSUE's last resort when no corridor can be
## projected, and other modes' authored regions are untouched by this unit.
static func _t_authored_regions_hold_outside_cutoff() -> Dictionary:
	# No projectable corridor (quarry dead) -> authored approach lane -> intercept.
	var no_corridor: Dictionary = _chokepoint_context()
	var lane: Array = [{"col": 2, "row": 4}]
	(no_corridor["objective_pressure"] as Dictionary)["approach_region"] = lane
	for actor_value: Variant in no_corridor["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == "enemy.1":
			actor["is_dead"] = true
	var no_corridor_result: Dictionary = Service.build_goals(no_corridor)
	var intercept: Dictionary = _goal(no_corridor_result, "intercept")
	if intercept.is_empty() or (intercept["destination_region"] as Array) != lane:
		return _fail("authored approach lane was overridden: %s" % str(intercept))
	if not _goal(no_corridor_result, "cut_off").is_empty():
		return _fail("a dead quarry still produced a projected cutoff")
	# Non-PURSUE modes keep authored regions verbatim.
	var protect: Dictionary = _open_context("protect", "party")
	var authored_screen: Array = [{"col": 2, "row": 4}, {"col": 4, "row": 2}]
	var protect_goal: Dictionary = _goal(Service.build_goals(protect), "protect")
	if protect_goal.is_empty() or (protect_goal["destination_region"] as Array) != authored_screen:
		return _fail("PROTECT authored destination region was overridden: %s" % str(protect_goal))
	return _pass()


# ---------------------------------------------------------------------------
# SCREENING AND INTERPOSITION
# ---------------------------------------------------------------------------

## Screen cells must physically stand between the threat and the protected actor:
## adjacent to the protected actor and on a Chebyshev geodesic from the hostile.
static func _t_screen_cells_interpose() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["destination_region"] = []
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("silent screen authority rejected: %s" % str(result))
	var protect: Dictionary = _goal(result, "protect")
	if protect.is_empty():
		return _fail("silent authority produced no derived screen: %s" % str(result["goals"]))
	var protected_position: Dictionary = pressure["objective_position"] as Dictionary
	var hostiles: Array = _hostile_positions(context)
	var region: Array = protect["destination_region"] as Array
	if region.is_empty():
		return _fail("derived screen was empty")
	for cell_value: Variant in region:
		var cell: Dictionary = cell_value as Dictionary
		if _chebyshev(cell, protected_position) != 1:
			return _fail("screen cell %s was not adjacent to the protected actor" % str(cell))
		if not _is_between(cell, protected_position, hostiles):
			return _fail("screen cell %s did not stand between threat and protected actor" % str(cell))
	return _pass()


## Interception cells are real stand-off positions on the approach lane — farther
## out than the close screen, and still on the hostile's geodesic.
static func _t_intercept_cells_stand_off_lane() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["approach_region"] = []
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("silent lane authority rejected: %s" % str(result))
	var intercept: Dictionary = _goal(result, "intercept")
	if intercept.is_empty():
		return _fail("silent authority produced no derived lane: %s" % str(result["goals"]))
	var protected_position: Dictionary = pressure["objective_position"] as Dictionary
	var hostiles: Array = _hostile_positions(context)
	var region: Array = intercept["destination_region"] as Array
	if region.is_empty():
		return _fail("derived interception lane was empty")
	for cell_value: Variant in region:
		var cell: Dictionary = cell_value as Dictionary
		var distance: int = _chebyshev(cell, protected_position)
		if distance < 2 or distance > Service.INTERCEPT_LANE_RADIUS:
			return _fail("intercept cell %s was outside the stand-off band" % str(cell))
		if not _is_between(cell, protected_position, hostiles):
			return _fail("intercept cell %s was not on an approach lane" % str(cell))
	return _pass()


# ---------------------------------------------------------------------------
# INVARIANTS
# ---------------------------------------------------------------------------

## Mirroring the board must mirror the derived regions exactly — proving the
## derivations use distance/reachability, never a row- or column-preferring rule.
## Membership is the claim; order is normalised downstream by the goal contract.
static func _t_mirrored_board_no_axis_bias() -> Dictionary:
	for case: Array in [["protect", "destination_region"], ["protect", "approach_region"]]:
		var mode: String = str(case[0])
		var silenced: String = str(case[1])
		var original: Dictionary = _open_context(mode, "party")
		(original["objective_pressure"] as Dictionary)[silenced] = []
		var original_result: Dictionary = Service.build_goals(original)
		if not bool(original_result["valid"]):
			return _fail("mirror source rejected: %s" % str(original_result))
		for axis: String in ["horizontal", "vertical"]:
			var mirrored: Dictionary = _mirror_context(original, axis)
			var mirrored_result: Dictionary = Service.build_goals(mirrored)
			if not bool(mirrored_result["valid"]):
				return _fail("%s mirror rejected: %s" % [axis, str(mirrored_result)])
			var original_goals: Array = original_result["goals"] as Array
			var mirrored_goals: Array = mirrored_result["goals"] as Array
			if original_goals.size() != mirrored_goals.size():
				return _fail("%s mirror changed goal count for %s" % [axis, silenced])
			for index: int in range(original_goals.size()):
				var source: Dictionary = original_goals[index] as Dictionary
				var image: Dictionary = mirrored_goals[index] as Dictionary
				if str(source["purpose"]) != str(image["purpose"]):
					return _fail("%s mirror reordered purposes" % axis)
				var expected: Array = _mirror_region(
					source["destination_region"] as Array, axis, original["bounds"] as Dictionary
				)
				if not _same_cell_set(expected, image["destination_region"] as Array):
					return _fail(
						"%s mirror was not covariant for %s/%s: %s vs %s" % [
							axis, silenced, str(source["purpose"]),
							str(expected), str(image["destination_region"]),
						]
					)
	return _pass()


## Identical facts must always produce byte-identical goals — no RNG, no clock,
## no iteration-order leakage anywhere in the new spatial derivations.
static func _t_deterministic_replay() -> Dictionary:
	var builders: Array = [
		func() -> Dictionary: return _chokepoint_context(),
		func() -> Dictionary: return _collapsing_context(),
		func() -> Dictionary: return _silent_screen_context(),
	]
	for builder_value: Variant in builders:
		var builder: Callable = builder_value as Callable
		var first: Dictionary = Service.build_goals(builder.call() as Dictionary)
		for _repeat: int in range(3):
			if Service.build_goals(builder.call() as Dictionary) != first:
				return _fail("replay diverged for %s" % str(first))
		# Re-running against the SAME context object must also not mutate it.
		var shared: Dictionary = builder.call() as Dictionary
		var before: Dictionary = shared.duplicate(true)
		Service.build_goals(shared)
		Service.build_goals(shared)
		if shared != before:
			return _fail("build_goals mutated its context")
	return _pass()


## The seven-mode goal invariants from slice 2 must survive unchanged: every mode
## and alignment still validates, still respects the three-bucket cap, and still
## emits contract-valid goals — now including the collapse state.
static func _t_seven_mode_invariants_hold() -> Dictionary:
	for mode_value: Variant in PressureContract.MODES:
		var mode: String = str(mode_value)
		for alignment: String in ["party", "hostile"]:
			for health: float in [1.0, 0.4]:
				var context: Dictionary = _open_context(mode, alignment)
				_set_mover_health(context, health)
				var result: Dictionary = Service.build_goals(context)
				if not bool(result["valid"]):
					return _fail("%s/%s@%s rejected: %s" % [mode, alignment, str(health), str(result)])
				var goals: Array = result["goals"] as Array
				if goals.size() > 3:
					return _fail("%s/%s@%s exceeded the bucket cap" % [mode, alignment, str(health)])
				var seen_purposes: Dictionary = {}
				for goal_value: Variant in goals:
					var goal: Dictionary = goal_value as Dictionary
					var validation: Dictionary = GoalContract.validate(goal, context["origin"] as Dictionary)
					if not bool(validation["valid"]):
						return _fail("%s/%s@%s invalid goal: %s" % [mode, alignment, str(health), str(validation)])
					if (goal["destination_region"] as Array).is_empty():
						return _fail("%s/%s@%s emitted an empty region" % [mode, alignment, str(health)])
					seen_purposes[str(goal["purpose"])] = true
				if health <= 0.5 and goals.size() > 0 and not seen_purposes.has("withdraw"):
					return _fail("%s/%s collapse produced no fall-back" % [mode, alignment])
	return _pass()


## Boundary check: the adapter publishes goals and regions ONLY. It must never
## report a win, a loss, custody transfer, or objective completion — those stay
## with the round-end objective layer (and Unit C for custody).
static func _t_publishes_no_objective_authority() -> Dictionary:
	var forbidden: Array = [
		"won", "lost", "victory", "defeat", "outcome", "resolved", "complete",
		"custody", "captured", "escaped", "progress_current", "progress_required",
	]
	var contexts: Array = [_chokepoint_context(), _collapsing_context(), _silent_screen_context()]
	for context_value: Variant in contexts:
		var result: Dictionary = Service.build_goals(context_value as Dictionary)
		var result_keys: Array = result.keys()
		result_keys.sort()
		if result_keys != ["field", "goals", "reason", "valid"]:
			return _fail("result shape changed: %s" % str(result_keys))
		for goal_value: Variant in result["goals"] as Array:
			var goal: Dictionary = goal_value as Dictionary
			var goal_keys: Array = goal.keys()
			goal_keys.sort()
			var expected_keys: Array = GoalContract.REQUIRED_FIELDS.duplicate()
			expected_keys.sort()
			if goal_keys != expected_keys:
				return _fail("goal carried non-contract fields: %s" % str(goal_keys))
			for key_value: Variant in forbidden:
				if goal.has(str(key_value)):
					return _fail("goal asserted objective authority via %s" % str(key_value))
			# objective_progress must be a pure REPORT of supplied counters, never a
			# decision: it is derived, clamped, and carries no completion verdict.
			var progress: float = float(goal["objective_progress"])
			if progress < 0.0 or progress > 1.0:
				return _fail("objective progress escaped the unit interval")
	return _pass()


# ---------------------------------------------------------------------------
# FIXTURES
# ---------------------------------------------------------------------------

## Open 7x7 board: mover at {1,3}, one hostile at {6,3}, a structure objective
## at {3,3}. The hostile stands 3 cells off the objective so that BOTH a close
## screen (band 1) and a stand-off interception lane (band 2..3) exist. No walls,
## so derived regions are unconstrained.
static func _open_context(mode: String, alignment: String) -> Dictionary:
	var mover_id: String = "echo.mover" if alignment == "party" else "enemy.mover"
	var hostile_id: String = "enemy.1" if alignment == "party" else "echo.1"
	var mover: Dictionary = _actor(mover_id, {"col": 1, "row": 3}, "echo" if alignment == "party" else "enemy")
	var hostile: Dictionary = _actor(hostile_id, {"col": 6, "row": 3}, "enemy" if alignment == "party" else "echo")
	var objective: Dictionary = _actor("objective.relic", {"col": 3, "row": 3}, "structure", true)
	var spirit: Dictionary = _actor("guide.spirit", {"col": 3, "row": 5}, "spirit")
	spirit["is_spirit"] = true
	if mode == "pursue":
		hostile["is_quarry"] = true
	var actors: Array = [mover, hostile, objective]
	var relationships: Dictionary = {
		mover_id: "friendly",
		hostile_id: "hostile",
		"objective.relic": "hostile" if alignment == "hostile" else "neutral",
	}
	var occupancy: Dictionary = {"1,3": mover_id, "6,3": hostile_id, "3,3": "objective.relic"}
	if mode == "guide_spirit":
		actors.append(spirit)
		relationships["guide.spirit"] = "hostile" if alignment == "hostile" else "friendly"
		occupancy["3,5"] = "guide.spirit"
	var cells: Dictionary = _open_cells(7, 7)
	return ContextContract.build(
		mover_id, "activation.spatial", {"col": 1, "row": 3}, {"w": 7, "h": 7},
		cells, cells, occupancy, actors, relationships, {}, [],
		_pressure(mode, alignment, mover_id, hostile_id), []
	)


## Walled 7x7 board. Row 3 is solid except for a single gap at col 3, so every
## route from the quarry at {3,1} to the far-end escape line (row 6) must pass
## through the chokepoint {3,3}. The mover sits at {2,2}, close enough to the gap
## to actually intercept.
static func _chokepoint_context(mode: String = "pursue") -> Dictionary:
	var cells: Dictionary = {}
	for col: int in range(7):
		for row: int in range(7):
			if row == 3 and col != 3:
				continue
			cells["%d,%d" % [col, row]] = true
	var mover: Dictionary = _actor("echo.mover", {"col": 2, "row": 2}, "echo")
	var quarry: Dictionary = _actor("enemy.1", {"col": 3, "row": 1}, "enemy")
	quarry["is_quarry"] = true
	var pressure: Dictionary = PressureContract.build(
		mode, "", "party", "baseline", true, "", {"col": 3, "row": 6},
		[], [], [], [], "", "", "", "enemy.1", "", 0.8, 1, 4, false, false, false, []
	)
	return ContextContract.build(
		"echo.mover", "activation.chokepoint", {"col": 2, "row": 2}, {"w": 7, "h": 7},
		cells, cells, {"2,2": "echo.mover", "3,1": "enemy.1"},
		[mover, quarry], {"echo.mover": "friendly", "enemy.1": "hostile"},
		{}, [], pressure, []
	)


static func _collapsing_context() -> Dictionary:
	var context: Dictionary = _open_context("combat", "party")
	_set_mover_health(context, 0.4)
	return context


static func _silent_screen_context() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	(context["objective_pressure"] as Dictionary)["destination_region"] = []
	return context


static func _pressure(
	mode: String, alignment: String, mover_id: String, hostile_id: String
) -> Dictionary:
	var guide_mode: String = "escort" if mode == "guide_spirit" else ""
	var quarry_id: String = hostile_id if mode == "pursue" else ""
	var holder_id: String = hostile_id if (mode == "recover" and alignment == "hostile") else ""
	var spirit_id: String = "guide.spirit" if mode == "guide_spirit" else ""
	return PressureContract.build(
		mode, guide_mode, alignment, "baseline", true, "objective.relic", {"col": 3, "row": 3},
		[{"col": 2, "row": 4}, {"col": 4, "row": 2}],
		[{"col": 2, "row": 2}, {"col": 4, "row": 4}],
		[], [], "", holder_id, "", quarry_id, spirit_id,
		0.4, 1, 4, false, false, false, []
	)


static func _actor(id: String, position: Dictionary, kind: String, structure: bool = false) -> Dictionary:
	return {
		"id": id, "position": position, "kind": kind,
		"is_dead": false, "is_ko": false, "is_structure": structure,
		"is_spirit": false, "is_quarry": false, "controlling_state": false,
		"health_ratio": 1.0,
	}


static func _open_cells(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for col: int in range(width):
		for row: int in range(height):
			cells["%d,%d" % [col, row]] = true
	return cells


static func _set_mover_health(context: Dictionary, health: float) -> void:
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == str(context["mover_id"]):
			actor["health_ratio"] = health


# ---------------------------------------------------------------------------
# FIX 4 / 8 — REGION PRODUCER SAFETY, GOAL CAP, CARRIER CUTOFF, EMPTY BRANCH
# ---------------------------------------------------------------------------

## FIX 4 — `_interposition_region` builds cells by ARITHMETIC (protected ± delta)
## with no board guard of its own, unlike the other region producers here which
## inherit one from `reachable_cost_region` / the escape graph. A protected actor
## in a board CORNER therefore used to emit negative columns and rows.
static func _t_interposition_stays_on_board() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	# Protected actor pinned to the (0,0) corner; hostile stays at (6,3), so the
	# geodesic band around the corner reaches for cells at col/row -1.
	pressure["objective_position"] = {"col": 0, "row": 0}
	pressure["destination_region"] = []
	pressure["approach_region"] = []

	var bounds: Dictionary = context["bounds"] as Dictionary
	var walkable: Dictionary = context["authoritative_walkable"] as Dictionary

	# Directly exercise the producer at both bands (close screen and stand-off lane).
	for band_value: Variant in [[1, 1], [2, Service.INTERCEPT_LANE_RADIUS]]:
		var band: Array = band_value as Array
		var produced: Array = Service._interposition_region(
			context, pressure["objective_position"] as Dictionary, int(band[0]), int(band[1])
		)
		for cell_value: Variant in produced:
			var cell: Dictionary = cell_value as Dictionary
			var col: int = int(cell["col"])
			var row: int = int(cell["row"])
			if col < 0 or row < 0:
				return _fail("band %s emitted an OFF-BOARD cell %s" % [str(band), str(cell)])
			if col >= int(bounds["w"]) or row >= int(bounds["h"]):
				return _fail("band %s emitted an out-of-bounds cell %s" % [str(band), str(cell)])
			if not bool(walkable.get(V.canonical_cell_key(cell), false)):
				return _fail("band %s emitted an unwalkable cell %s" % [str(band), str(cell)])
		# The close screen at a corner must still find real ground toward the hostile.
		if int(band[0]) == 1 and produced.is_empty():
			return _fail("corner screen collapsed to nothing — the guard is too strict")

	# And the goals built from it stay valid end to end.
	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("corner-protected context rejected: %s" % str(result))
	return _pass()


## FIX 8(a) — the 3-goal cap must hold WITH the withdraw goal in play.
##
## `_add_board_fallback` appends a candidate AFTER the mode block, and every
## ordinary fixture has health_ratio 1.0, so the existing cap assertion never
## exercised a collapsing mover. `guide_spirit`/`party` already emits exactly 3
## goals, which is where a 4th would surface.
##
## RESULT: the cap is STRUCTURALLY safe — `build_goals` shortlists at most ONE
## goal per bucket across exactly three buckets, and the withdraw candidate lands
## in BUCKET_SAFETY where it competes with (and outranks) the engage rather than
## adding a slot. This test pins that for all 7 modes x both alignments.
static func _t_goal_cap_holds_under_collapse() -> Dictionary:
	var saw_withdraw: bool = false
	for mode_value: Variant in PressureContract.MODES:
		var mode: String = str(mode_value)
		for alignment: String in ["party", "hostile"]:
			var context: Dictionary = _open_context(mode, alignment)
			_set_mover_health(context, 0.4)
			var result: Dictionary = Service.build_goals(context)
			if not bool(result["valid"]):
				return _fail("collapsing %s/%s rejected: %s" % [mode, alignment, str(result)])
			var goals: Array = result["goals"] as Array
			if goals.size() > 3:
				return _fail("collapsing %s/%s emitted %d goals (cap is 3): %s" % [
					mode, alignment, goals.size(), str(goals)])
			# No purpose may be represented twice — one goal per bucket, and no two
			# buckets may shortlist the same purpose (which would hand the mover two
			# goals reading as the same intent).
			var purposes: Array = []
			for goal_value: Variant in goals:
				var goal: Dictionary = goal_value as Dictionary
				if not bool(GoalContract.validate(goal, context["origin"] as Dictionary)["valid"]):
					return _fail("collapsing %s/%s emitted an invalid goal" % [mode, alignment])
				purposes.append(str(goal["purpose"]))
			if purposes.count("withdraw") == 1:
				saw_withdraw = true
			for purpose_value: Variant in purposes:
				var purpose: String = str(purpose_value)
				if purposes.count(purpose) > 1:
					return _fail("collapsing %s/%s emitted duplicate %s goals: %s" % [
						mode, alignment, purpose, str(purposes)])
	if not saw_withdraw:
		return _fail("no mode/alignment produced a withdraw — the collapse path was never exercised")
	return _pass()


## FIX 8(b) — the ratified PROTECT change routes the stolen-totem carrier's
## `cut_off` through the carrier's OWN escape corridor, not the objective
## approach lane (which points the wrong way once custody is already taken).
static func _t_stolen_carrier_cutoff_region() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["totem_stolen"] = true
	pressure["carrier_id"] = "enemy.1"
	# Move the carrier far from the escape band so a real corridor exists and the
	# mover can actually reach parts of it in time. Board is 7x7 -> band = rows 5,6.
	_move_actor(context, "enemy.1", {"col": 5, "row": 0})

	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("stolen-totem context rejected: %s" % str(result))
	var cut_off: Dictionary = _goal(result, "cut_off")
	if cut_off.is_empty():
		return _fail("stolen totem produced no cut_off goal: %s" % str(result["goals"]))
	var region: Array = cut_off["destination_region"] as Array
	if region.is_empty():
		return _fail("carrier cut_off carried an empty region")

	var approach: Array = pressure["approach_region"] as Array
	if region == approach:
		return _fail("carrier cut_off fell back to the objective approach lane: %s" % str(region))
	# (2,2) is an approach_region cell that is NOT on the carrier's escape corridor.
	if region.has({"col": 2, "row": 2}):
		return _fail("carrier cut_off included off-corridor approach cell (2,2): %s" % str(region))

	# Every cell must lie on the carrier's real escape corridor.
	var corridor: Array = EscapeAuthority.cutoff_cells(
		{"col": 5, "row": 0},
		context["bounds"] as Dictionary,
		context["authoritative_walkable"] as Dictionary,
		[context["origin"] as Dictionary],
		[{"col": 3, "row": 3}]
	)
	var corridor_keys: Array = []
	for cell_value: Variant in corridor:
		corridor_keys.append(V.canonical_cell_key(cell_value as Dictionary))
	for cell_value2: Variant in region:
		if not corridor_keys.has(V.canonical_cell_key(cell_value2 as Dictionary)):
			return _fail("cut_off cell %s is off the carrier's escape corridor" % str(cell_value2))
	return _pass()


## FIX 8(c) — the corridor is computed from BOARD TRUTH, so an authored
## `fallback_region` must not perturb it at all. Previously only the two halves
## were tested in isolation; this asserts the identity directly.
static func _t_corridor_identical_with_authored_terrain() -> Dictionary:
	# Board 7x7 -> band = rows 5,6. Park the quarry far from the band so a corridor
	# exists AND the mover at (1,3) can reach part of it in time; at the fixture's
	# default (6,3) the quarry is 2 steps from winning and every corridor cell is
	# filtered out, which would make the identity vacuous.
	var clean: Dictionary = _open_context("pursue", "party")
	_move_actor(clean, "enemy.1", {"col": 5, "row": 0})
	var clean_cutoff: Dictionary = _goal(Service.build_goals(clean), "cut_off")
	if clean_cutoff.is_empty():
		return _fail("no cut_off goal without authored terrain")
	var clean_region: Array = clean_cutoff["destination_region"] as Array
	if clean_region.is_empty():
		return _fail("clean corridor was empty — the identity would be vacuous")

	var authored: Dictionary = _open_context("pursue", "party")
	_move_actor(authored, "enemy.1", {"col": 5, "row": 0})
	(authored["objective_pressure"] as Dictionary)["fallback_region"] = [
		{"col": 0, "row": 0}, {"col": 0, "row": 1},
	]
	var authored_cutoff: Dictionary = _goal(Service.build_goals(authored), "cut_off")
	if authored_cutoff.is_empty():
		return _fail("no cut_off goal with authored terrain present")
	var authored_region: Array = authored_cutoff["destination_region"] as Array

	if authored_region != clean_region:
		return _fail("authored fallback_region perturbed the corridor: %s vs %s" % [
			str(authored_region), str(clean_region)])
	return _pass()


## FIX 8(d) — the third `elif` branch: corridor, fallback_region AND
## approach_region all empty -> NO tactical goal at all (not an empty-region goal,
## and not a silent fall-through to some other purpose).
static func _t_no_tactical_goal_when_all_regions_empty() -> Dictionary:
	var context: Dictionary = _open_context("pursue", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["fallback_region"] = []
	pressure["approach_region"] = []
	# Park the LIVING quarry inside the escape band (7x7 -> rows 5,6). It has
	# already won, so min_escape_cost is 0 and the corridor is empty — while the
	# quarry itself stays alive, keeping this distinct from the dead-quarry path.
	_move_actor(context, "enemy.1", {"col": 6, "row": 6})

	var result: Dictionary = Service.build_goals(context)
	if not bool(result["valid"]):
		return _fail("all-empty-region context rejected: %s" % str(result))
	if not _goal(result, "cut_off").is_empty():
		return _fail("emitted a cut_off goal with no corridor and no authored terrain")
	if not _goal(result, "intercept").is_empty():
		return _fail("emitted an intercept goal with an empty approach region")
	# The quarry is alive, so the DIRECT pursue goal must still be there — proving
	# we exercised the empty-region branch, not a dead-quarry short circuit.
	if _goal(result, "pursue").is_empty():
		return _fail("living quarry lost its direct pursue goal: %s" % str(result["goals"]))
	for goal_value: Variant in result["goals"] as Array:
		if (((goal_value as Dictionary)["destination_region"]) as Array).is_empty():
			return _fail("emitted a goal with an empty destination region")
	return _pass()


## FIX 8(e) — GOLDEN full-array pin for the derived screen region, so any change
## to derivation OR to region ordering shows up as an exact diff.
static func _t_golden_derived_screen_region() -> Dictionary:
	var context: Dictionary = _open_context("protect", "party")
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	pressure["destination_region"] = []
	var protect: Dictionary = _goal(Service.build_goals(context), "protect")
	if protect.is_empty():
		return _fail("no derived screen goal")
	# Protected actor (3,3), hostile (6,3): the close screen is the Chebyshev-1
	# ring cells that sit on a geodesic toward the hostile, in canonical order.
	var expected: Array = [
		{"col": 4, "row": 2}, {"col": 4, "row": 3}, {"col": 4, "row": 4},
	]
	if (protect["destination_region"] as Array) != expected:
		return _fail("golden screen region mismatch: %s" % str(protect["destination_region"]))
	return _pass()


# ---------------------------------------------------------------------------
# ASSERT HELPERS
# ---------------------------------------------------------------------------

## Relocate a perceived actor and keep `occupancy` consistent with the move.
static func _move_actor(context: Dictionary, actor_id: String, position: Dictionary) -> void:
	var occupancy: Dictionary = context["occupancy"] as Dictionary
	for key_value: Variant in occupancy.keys():
		if str(occupancy[key_value]) == actor_id:
			occupancy.erase(key_value)
	occupancy[V.canonical_cell_key(position)] = actor_id
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == actor_id:
			actor["position"] = position.duplicate(true)

static func _goal(result: Dictionary, purpose: String) -> Dictionary:
	if not bool(result.get("valid", false)):
		return {}
	for goal_value: Variant in result["goals"] as Array:
		var goal: Dictionary = goal_value as Dictionary
		if str(goal["purpose"]) == purpose:
			return goal
	return {}


static func _hostile_positions(context: Dictionary) -> Array:
	var positions: Array = []
	var relationships: Dictionary = context["relationships"] as Dictionary
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(relationships.get(str(actor["id"]), "")) != "hostile":
			continue
		if bool(actor["is_dead"]) or bool(actor["is_ko"]) or bool(actor["is_structure"]):
			continue
		positions.append(actor["position"] as Dictionary)
	return positions


static func _threat_distance(cell: Dictionary, hostiles: Array) -> int:
	var nearest: int = -1
	for hostile_value: Variant in hostiles:
		var distance: int = _chebyshev(cell, hostile_value as Dictionary)
		if nearest < 0 or distance < nearest:
			nearest = distance
	return nearest


## True when `cell` sits on a Chebyshev geodesic between some hostile and the
## protected actor — the formal statement of "standing between them".
static func _is_between(cell: Dictionary, protected_position: Dictionary, hostiles: Array) -> bool:
	for hostile_value: Variant in hostiles:
		var hostile: Dictionary = hostile_value as Dictionary
		var span: int = _chebyshev(hostile, protected_position)
		if _chebyshev(hostile, cell) + _chebyshev(cell, protected_position) == span:
			return true
	return false


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a["col"]) - int(b["col"])), absi(int(a["row"]) - int(b["row"])))


static func _same_cell_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for cell_value: Variant in left:
		if not right.has(cell_value):
			return false
	return true


static func _mirror_position(position: Dictionary, axis: String, bounds: Dictionary) -> Dictionary:
	if axis == "horizontal":
		return {"col": int(bounds["w"]) - 1 - int(position["col"]), "row": int(position["row"])}
	return {"col": int(position["col"]), "row": int(bounds["h"]) - 1 - int(position["row"])}


static func _mirror_region(region: Array, axis: String, bounds: Dictionary) -> Array:
	var result: Array = []
	for position_value: Variant in region:
		result.append(_mirror_position(position_value as Dictionary, axis, bounds))
	return V.canonical_position_array(result)


static func _mirror_context(context: Dictionary, axis: String) -> Dictionary:
	var bounds: Dictionary = context["bounds"] as Dictionary
	var mirrored: Dictionary = context.duplicate(true)
	mirrored["origin"] = _mirror_position(context["origin"] as Dictionary, axis, bounds)
	for actor_value: Variant in mirrored["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		actor["position"] = _mirror_position(actor["position"] as Dictionary, axis, bounds)
	var occupancy: Dictionary = {}
	for actor_value: Variant in mirrored["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		occupancy[V.canonical_cell_key(actor["position"] as Dictionary)] = str(actor["id"])
	mirrored["occupancy"] = occupancy
	for field: String in ["authoritative_walkable", "perceived_planning_cells"]:
		var mirrored_map: Dictionary = {}
		for key_value: Variant in (context[field] as Dictionary):
			var position: Dictionary = V.parse_canonical_cell_key(str(key_value))
			mirrored_map[V.canonical_cell_key(_mirror_position(position, axis, bounds))] = true
		mirrored[field] = mirrored_map
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	mirrored["objective_pressure"] = PressureContract.build(
		str(pressure["mode"]), str(pressure["guide_mode"]), str(pressure["mover_alignment"]),
		str(pressure["factual_role"]), bool(pressure["objective_known"]), str(pressure["objective_id"]),
		_mirror_position(pressure["objective_position"] as Dictionary, axis, bounds),
		_mirror_region(pressure["destination_region"] as Array, axis, bounds),
		_mirror_region(pressure["approach_region"] as Array, axis, bounds),
		_mirror_region(pressure["fallback_region"] as Array, axis, bounds),
		_mirror_region(pressure["search_region"] as Array, axis, bounds),
		str(pressure["purifier_id"]), str(pressure["holder_id"]), str(pressure["carrier_id"]),
		str(pressure["quarry_id"]), str(pressure["spirit_id"]),
		float(pressure["objective_health_ratio"]), int(pressure["progress_current"]),
		int(pressure["progress_required"]), bool(pressure["escort_started"]),
		bool(pressure["spirit_joins_battle"]), bool(pressure["totem_stolen"]),
		pressure["pressure_sources"] as Array
	)
	return mirrored


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
