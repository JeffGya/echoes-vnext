# res://tests/GuideSpiritActivationTests.gd
# V2-COMBAT-002 Slice 4 (Unit B): non-joining GUIDE spirit activation tests.
#
# Deterministic, hand-built boards / guide states / hazard configs. Proves the
# authored one-cell pace, escort + skittish step selection (including a mirrored
# board with no row/col bias), shared-executor terrain/occupancy/diagonal/hazard
# obedience, MovementResult validity, the absence of any objective authority,
# deterministic replay, and no input mutation.

class_name GuideSpiritActivationTests
extends RefCounted

const GuideActivation = preload("res://core/movement/GuideSpiritActivationService.gd")
const ProfileService = preload("res://core/movement/MovementProfileService.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")
const HazardFixtures = preload("res://core/movement/MovementHazardFixtures.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/guide_spirit/escort_steps_exactly_one_cell", Callable(GuideSpiritActivationTests, "_t_escort_one_cell"))
	runner.register_test("movement/guide_spirit/escort_waits_when_next_cell_occupied", Callable(GuideSpiritActivationTests, "_t_escort_waits_occupied"))
	runner.register_test("movement/guide_spirit/escort_unreachable_destination_no_route", Callable(GuideSpiritActivationTests, "_t_escort_unreachable"))
	runner.register_test("movement/guide_spirit/skittish_steps_away_from_nearest_threat", Callable(GuideSpiritActivationTests, "_t_skittish_away"))
	runner.register_test("movement/guide_spirit/skittish_mirrored_board_no_row_col_bias", Callable(GuideSpiritActivationTests, "_t_skittish_mirror_no_bias"))
	runner.register_test("movement/guide_spirit/skittish_skips_occupied_neighbours", Callable(GuideSpiritActivationTests, "_t_skittish_skips_occupied"))
	runner.register_test("movement/guide_spirit/skittish_single_threat_transpose_covariant", Callable(GuideSpiritActivationTests, "_t_skittish_single_threat_transpose"))
	runner.register_test("movement/guide_spirit/refuses_joined_spirit", Callable(GuideSpiritActivationTests, "_t_refuses_joined_spirit"))
	runner.register_test("movement/guide_spirit/golden_escort_result", Callable(GuideSpiritActivationTests, "_t_golden_escort_result"))
	runner.register_test("movement/guide_spirit/profile_is_authored_capacity_one", Callable(GuideSpiritActivationTests, "_t_authored_capacity_one"))
	runner.register_test("movement/guide_spirit/two_solid_corners_diagonal_legality", Callable(GuideSpiritActivationTests, "_t_diagonal_legality"))
	runner.register_test("movement/guide_spirit/hazards_apply_as_to_any_actor", Callable(GuideSpiritActivationTests, "_t_hazards_apply"))
	runner.register_test("movement/guide_spirit/result_passes_validate", Callable(GuideSpiritActivationTests, "_t_result_validate"))
	runner.register_test("movement/guide_spirit/makes_no_objective_progress_decision", Callable(GuideSpiritActivationTests, "_t_no_objective_authority"))
	runner.register_test("movement/guide_spirit/caller_gate_false_holds_position", Callable(GuideSpiritActivationTests, "_t_gate_false_holds"))
	runner.register_test("movement/guide_spirit/protect_moves_with_adjacent_active_hostile", Callable(GuideSpiritActivationTests, "_t_protect_moves_with_adjacent_hostile"))
	runner.register_test("movement/guide_spirit/escort_moves_when_step_adjacent_to_active_hostile", Callable(GuideSpiritActivationTests, "_t_escort_moves_adjacent_hostile"))
	runner.register_test("movement/guide_spirit/escort_moves_onto_cost_two_terrain", Callable(GuideSpiritActivationTests, "_t_escort_moves_onto_cost_two_terrain"))
	runner.register_test("movement/guide_spirit/deterministic_replay", Callable(GuideSpiritActivationTests, "_t_deterministic_replay"))
	runner.register_test("movement/guide_spirit/no_input_mutation", Callable(GuideSpiritActivationTests, "_t_no_mutation"))


# ---------------------------------------------------------------------------
# FIXTURES
# ---------------------------------------------------------------------------

static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


## A deliberately STRONG spirit: the ordinary formula would give this actor the
## top capacity, so any capacity of 1 can only come from the authored override.
static func _spirit(overrides: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = {
		"id": "spirit.1",
		"kind": "npc",
		"is_spirit": true,
		"standing": 9,
		"stats": {"agi": 20},
		"current_hp": 10,
	}
	for key: Variant in overrides.keys():
		actor[key] = overrides[key]
	return actor


## capacity_cfg that yields 6 for the strong spirit under the ordinary formula.
static func _capacity_cfg() -> Dictionary:
	return {
		"floor": 1,
		"cap": 6,
		"aptitude_base": 2,
		"agi_threshold_1": 5,
		"agi_threshold_2": 10,
		"calling_bonus": {},
		"skill_bonus": {},
		"standing_bands": [
			{"min_standing": 1, "capacity": 2},
			{"min_standing": 5, "capacity": 4},
			{"min_standing": 9, "capacity": 6},
		],
	}


static func _hazard_cfg() -> Dictionary:
	return {
		"types": ["unstable", "binding", "burning"],
		"unstable": {"displacement_cells": 1, "fallback_damage": 3},
		"binding": {"stops_movement": true},
		"burning": {"end_activation_damage": 3},
	}


static func _hazard_ctx(config: Dictionary = {}) -> Dictionary:
	return {"triggered": {"unstable": false, "binding": false, "burning": false}, "config": config}


static func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"origin": _cell(1, 1),
		"authoritative_walkable": {},
		"bounds": {"w": 10, "h": 10},
		"occupancy": {},
		"terrain_costs": {},
		"known_hazards": [],
		"perceived_actors": [],
		"relationships": {},
		"objective_pressure": {},
		"mover_id": "spirit.1",
	}
	for key: Variant in overrides.keys():
		base[key] = overrides[key]
	return base


static func _escort_state(destination: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"mode": "escort",
		"should_move": true,
		"destination": destination,
	}
	for key: Variant in overrides.keys():
		state[key] = overrides[key]
	return state


static func _protect_state(threats: Array, overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"mode": "protect",
		"should_move": true,
		"threats": threats,
	}
	for key: Variant in overrides.keys():
		state[key] = overrides[key]
	return state


## Explicit full-rectangle walkable set (never the empty legacy sentinel), so
## erased cells register as real obstructions.
static func _full_walkable(width: int, height: int) -> Dictionary:
	var cells: Dictionary = {}
	for col in range(width):
		for row in range(height):
			cells["%d,%d" % [col, row]] = true
	return cells


static func _hazard_types(result: Dictionary) -> Array:
	var types: Array = []
	for hazard_value: Variant in result.get("hazards", []) as Array:
		types.append(str((hazard_value as Dictionary).get("type", "")))
	return types


# ---------------------------------------------------------------------------
# ESCORT
# ---------------------------------------------------------------------------

## The spirit advances EXACTLY one cell toward the authored destination, even
## though the destination is four cells away.
static func _t_escort_one_cell() -> Dictionary:
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), _ctx(), _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if (result["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("escort should step to (2,1), got %s" % str(result["final_destination"]))
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("escort moved more than one cell: %s" % str(result["actual_traversed_cells"]))
	if int(result["voluntary_cost"]) != 1 or int(result["remaining_capacity"]) != 0:
		return _fail("authored pace not spent exactly once: cost=%d remaining=%d" % [
			int(result["voluntary_cost"]), int(result["remaining_capacity"])])
	if str(result["stop_reason"]) != "reached_destination":
		return _fail("expected reached_destination, got %s" % str(result["stop_reason"]))
	if str(result["purpose"]) != "escort":
		return _fail("expected escort purpose, got %s" % str(result["purpose"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("escort result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## The chosen step is occupied -> the SHARED executor's occupancy rule makes the
## spirit wait in place, exactly as it would any other actor.
static func _t_escort_waits_occupied() -> Dictionary:
	var context: Dictionary = _ctx({"occupancy": {"2,1": "echo.1"}})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if str(result["stop_reason"]) != "occupied":
		return _fail("expected occupied stop, got %s" % str(result["stop_reason"]))
	if (result["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("spirit should have waited at origin, got %s" % str(result["final_destination"]))
	if not (result["actual_traversed_cells"] as Array).is_empty():
		return _fail("waiting spirit traversed cells: %s" % str(result["actual_traversed_cells"]))
	if int(result["voluntary_cost"]) != 0:
		return _fail("waiting spirit spent capacity: %d" % int(result["voluntary_cost"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("waiting result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## No route to the authored destination -> empty path -> "no_route", no movement.
static func _t_escort_unreachable() -> Dictionary:
	var walkable: Dictionary = {"1,1": true, "2,1": true}
	var context: Dictionary = _ctx({"authoritative_walkable": walkable, "bounds": {"w": 6, "h": 6}})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 5)), _hazard_ctx(), _capacity_cfg()
	)
	if str(result["stop_reason"]) != "no_route":
		return _fail("expected no_route, got %s" % str(result["stop_reason"]))
	if (result["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("unreachable escort moved: %s" % str(result["final_destination"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("no_route result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


# ---------------------------------------------------------------------------
# PROTECT / SKITTISH
# ---------------------------------------------------------------------------

## One step AWAY from the nearest threat. Spirit (3,3), threat (4,4):
## the max-Chebyshev ring is {(2,2),(3,2),(4,2),(2,3),(2,4)} at distance 2, and
## (2,2) alone maximises Manhattan (4) -> unambiguous, no tiebreak needed.
static func _t_skittish_away() -> Dictionary:
	var context: Dictionary = _ctx({"origin": _cell(3, 3), "bounds": {"w": 7, "h": 7}})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(4, 4)]), _hazard_ctx(), _capacity_cfg()
	)
	if (result["final_destination"] as Dictionary) != _cell(2, 2):
		return _fail("skittish step should be (2,2), got %s" % str(result["final_destination"]))
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("skittish moved more than one cell: %s" % str(result["actual_traversed_cells"]))
	if str(result["purpose"]) != "protect":
		return _fail("expected protect purpose, got %s" % str(result["purpose"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("skittish result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## MIRRORED BOARD — proves the tiebreak carries no row/col bias.
##
## Board 7x7, spirit (3,3), nearest threat (3,5), second threat (0,3).
## The max-Chebyshev/max-Manhattan set is {(2,2),(4,2)} — a perfect tie under the
## nearest threat alone. The second threat resolves it by GEOMETRY: (4,2) is
## farther from (0,3), so (4,2) wins.
##
## Reflecting the board across its vertical mid-line (col -> 6-col) maps the
## second threat to (6,3), and the answer must mirror to (2,2). A raw
## lowest-col preference (the live inline rule) would answer (2,2) BOTH times.
static func _t_skittish_mirror_no_bias() -> Dictionary:
	var context: Dictionary = _ctx({"origin": _cell(3, 3), "bounds": {"w": 7, "h": 7}})

	var left: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(3, 5), _cell(0, 3)]), _hazard_ctx(), _capacity_cfg()
	)
	var mirrored: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(3, 5), _cell(6, 3)]), _hazard_ctx(), _capacity_cfg()
	)

	var left_cell: Dictionary = left["final_destination"] as Dictionary
	var mirrored_cell: Dictionary = mirrored["final_destination"] as Dictionary

	if left_cell != _cell(4, 2):
		return _fail("expected (4,2) away from the near threat, got %s" % str(left_cell))
	if mirrored_cell != _cell(2, 2):
		return _fail("expected mirrored (2,2), got %s" % str(mirrored_cell))
	# The mirror relation itself: col' = (w-1) - col, row unchanged.
	var expected_mirror: Dictionary = _cell(6 - int(left_cell["col"]), int(left_cell["row"]))
	if mirrored_cell != expected_mirror:
		return _fail("choice is not reflection-covariant: %s vs %s" % [str(mirrored_cell), str(expected_mirror)])
	if left_cell == mirrored_cell:
		return _fail("identical choice on mirrored boards — a raw row/col bias is present")
	return _pass()


## Occupied neighbours are never chosen; the next-best free cell is taken.
static func _t_skittish_skips_occupied() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": 7, "h": 7},
		"occupancy": {"2,2": "echo.1"},
	})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(4, 4)]), _hazard_ctx(), _capacity_cfg()
	)
	var chosen: Dictionary = result["final_destination"] as Dictionary
	if chosen == _cell(2, 2):
		return _fail("skittish stepped onto an occupied cell")
	# Remaining max-Chebyshev(2)/max-Manhattan(3) candidates: (3,2) and (2,3);
	# both tie on the single-threat vector, so numeric order settles it.
	if chosen != _cell(2, 3):
		return _fail("expected fallback (2,3), got %s" % str(chosen))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("occupancy-skip result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## SINGLE-THREAT TRANSPOSITION — the counterexample that disproved the old
## docstring claim that the numeric fallback fired "ONLY for irreducible perfect
## symmetry" (FIX 2).
##
## Board 8x8, spirit (3,3), ONE threat at (0,0), (4,4) solid, plus an ASYMMETRIC
## far blocker at (0,7). Candidates (4,3) and (3,4) tie on every THREAT key:
##   Chebyshev to (0,0)  = 4 both
##   Manhattan to (0,0)  = 7 both
##   threat vector       = [4] both   (a single threat pins only {|dcol|,|drow|})
## so the ranking used to fall through to numeric order and answer (3,4). The
## board is NOT self-symmetric — transposing it moves the far blocker from (0,7)
## to (7,0) — yet numeric order answered (3,4) BOTH times, i.e.
## f(transpose(board)) != transpose(f(board)).
##
## The obstruction-distance key (key 4) now separates them by the board's own
## asymmetric terrain, so the answer transposes with the board.
static func _t_skittish_single_threat_transpose() -> Dictionary:
	var size: int = 8

	var walkable: Dictionary = _full_walkable(size, size)
	walkable.erase("4,4")
	walkable.erase("0,7")
	var context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": size, "h": size},
		"authoritative_walkable": walkable,
	})
	var upright: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(0, 0)]), _hazard_ctx(), _capacity_cfg()
	)

	# Transposed board: col <-> row everywhere. (4,4) is self-transposed; the far
	# blocker moves (0,7) -> (7,0), which is what makes the board asymmetric.
	var transposed_walkable: Dictionary = _full_walkable(size, size)
	transposed_walkable.erase("4,4")
	transposed_walkable.erase("7,0")
	var transposed_context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": size, "h": size},
		"authoritative_walkable": transposed_walkable,
	})
	var transposed: Dictionary = GuideActivation.activate_spirit(
		_spirit(), transposed_context, _protect_state([_cell(0, 0)]), _hazard_ctx(), _capacity_cfg()
	)

	var upright_cell: Dictionary = upright["final_destination"] as Dictionary
	var transposed_cell: Dictionary = transposed["final_destination"] as Dictionary

	# Both must still be in the tied max-threat-distance pair.
	var tied: Array = [_cell(4, 3), _cell(3, 4)]
	if not tied.has(upright_cell):
		return _fail("upright answer %s left the tied pair" % str(upright_cell))
	if not tied.has(transposed_cell):
		return _fail("transposed answer %s left the tied pair" % str(transposed_cell))
	# THE POINT: the answer transposes with the board.
	var expected: Dictionary = _cell(int(upright_cell["row"]), int(upright_cell["col"]))
	if transposed_cell != expected:
		return _fail("choice is not transpose-covariant: %s -> %s (expected %s)" % [
			str(upright_cell), str(transposed_cell), str(expected)])
	if upright_cell == transposed_cell:
		return _fail("identical choice on a transposed asymmetric board — numeric bias is still present")
	if not bool(ResultContract.validate(upright)["valid"]):
		return _fail("upright result rejected: %s" % str(ResultContract.validate(upright)))
	return _pass()


# ---------------------------------------------------------------------------
# PRECONDITION: NON-JOINING SPIRITS ONLY (FIX 3)
# ---------------------------------------------------------------------------

## This service stamps an authored capacity-1 override unconditionally. A JOINED
## spirit is an ordinary combatant, so a mis-branched caller would silently pin a
## full participant to one cell per round. The precondition must refuse loudly.
static func _t_refuses_joined_spirit() -> Dictionary:
	var context: Dictionary = _ctx()
	var joined_state: Dictionary = _escort_state(_cell(5, 1), {"joined": true})
	var refused: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, joined_state, _hazard_ctx(), _capacity_cfg()
	)
	# It never moves the joined spirit...
	if (refused["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("joined spirit was moved by the non-joining seam: %s" % str(refused["final_destination"]))
	if int(refused["voluntary_cost"]) != 0:
		return _fail("joined spirit spent capacity: %d" % int(refused["voluntary_cost"]))
	if not (refused["actual_traversed_cells"] as Array).is_empty():
		return _fail("joined spirit traversed cells: %s" % str(refused["actual_traversed_cells"]))
	# ...and it says so unambiguously, rather than returning a plausible one-cell result.
	if str(refused["goal_id"]) != GuideActivation.REFUSED_JOINED_GOAL_ID:
		return _fail("refusal was not reported via goal_id: %s" % str(refused["goal_id"]))
	if not bool(ResultContract.validate(refused)["valid"]):
		return _fail("refusal result rejected: %s" % str(ResultContract.validate(refused)))

	# The SAME state without the joined flag is the ordinary non-joining path.
	var allowed: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if (allowed["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("non-joining spirit did not move: %s" % str(allowed["final_destination"]))
	if str(allowed["goal_id"]) == GuideActivation.REFUSED_JOINED_GOAL_ID:
		return _fail("non-joining spirit was wrongly refused")
	# Default is permissive: an absent flag must never refuse.
	if str(GuideActivation.activate_spirit(
		_spirit(), context, {"mode": "escort", "destination": _cell(5, 1)},
		_hazard_ctx(), _capacity_cfg()
	)["goal_id"]) == GuideActivation.REFUSED_JOINED_GOAL_ID:
		return _fail("absent joined flag defaulted to refusal")
	return _pass()


# ---------------------------------------------------------------------------
# GOLDEN (replay / ordering pin)
# ---------------------------------------------------------------------------

## Full-array pin of a complete escort activation. Any change to step selection,
## path construction, or the authored pace shows up here as an exact diff.
static func _t_golden_escort_result() -> Dictionary:
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), _ctx(), _escort_state(_cell(5, 4)), _hazard_ctx(), _capacity_cfg()
	)
	var expected: Dictionary = {
		"mover_id": "spirit.1",
		"activation_id": "guide.activation",
		"goal_id": "guide.escort",
		"option_id": "guide.step",
		"purpose": "escort",
		"origin": _cell(1, 1),
		"final_destination": _cell(2, 2),
		"planned_path": [_cell(2, 2)],
		"actual_traversed_cells": [_cell(2, 2)],
		"voluntary_cost": 1,
		"forced_steps": 0,
		"remaining_capacity": 0,
		"stop_reason": "reached_destination",
		"objective_progress": 0.0,
	}
	for key: Variant in expected.keys():
		var field: String = str(key)
		if result[field] != expected[field]:
			return _fail("golden mismatch on %s: got %s expected %s" % [
				field, str(result[field]), str(expected[field])])
	# Full-array event pin: one voluntary step, then the stop.
	var expected_events: Array = [
		{
			"seq": 0, "phase": "movement", "type": "move.step", "source_id": "spirit.1",
			"from_pos": _cell(1, 1), "to_pos": _cell(2, 2), "movement_kind": "voluntary",
			"cost": 1, "hazard": {}, "damage": 0, "stop_reason": "",
		},
		{
			"seq": 1, "phase": "movement", "type": "move.stop", "source_id": "spirit.1",
			"from_pos": _cell(2, 2), "to_pos": _cell(2, 2), "movement_kind": "none",
			"cost": 0, "hazard": {}, "damage": 0, "stop_reason": "reached_destination",
		},
	]
	if (result["events"] as Array) != expected_events:
		return _fail("golden event stream mismatch: %s" % str(result["events"]))
	if not (result["hazards"] as Array).is_empty():
		return _fail("golden escort emitted hazards: %s" % str(result["hazards"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("golden result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


# ---------------------------------------------------------------------------
# AUTHORED PACE
# ---------------------------------------------------------------------------

## The profile is ALWAYS the authored capacity-1 override, never the formula.
static func _t_authored_capacity_one() -> Dictionary:
	var actor: Dictionary = _spirit()
	var cfg: Dictionary = _capacity_cfg()

	var ordinary: Dictionary = ProfileService.derive_profile(actor, cfg, {})
	if int(ordinary["capacity"]) <= 1:
		return _fail("fixture is not a strong actor — the test proves nothing (capacity %d)" % int(ordinary["capacity"]))

	var authored: Dictionary = ProfileService.derive_profile(
		actor, cfg, {"authored_override": {"source": "guide_spirit_nonjoining", "capacity": 1}}
	)
	if int(authored["capacity"]) != 1:
		return _fail("authored override did not yield capacity 1: %d" % int(authored["capacity"]))
	if str(authored["actor_kind"]) == "structure":
		return _fail("authored override must never be a structure")

	# And the activation itself never spends more than one cell, even with a
	# far destination that the ordinary capacity would comfortably reach.
	var result: Dictionary = GuideActivation.activate_spirit(
		actor, _ctx(), _escort_state(_cell(8, 1)), _hazard_ctx(), cfg
	)
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("authored pace exceeded one cell: %s" % str(result["actual_traversed_cells"]))
	if int(result["voluntary_cost"]) + int(result["remaining_capacity"]) != 1:
		return _fail("activation capacity envelope was not 1")
	return _pass()


# ---------------------------------------------------------------------------
# SHARED-EXECUTOR RULES
# ---------------------------------------------------------------------------

## Two-solid-corners diagonal legality applies to the spirit like anyone else.
static func _t_diagonal_legality() -> Dictionary:
	var bounds: Dictionary = {"w": 5, "h": 5}

	# BOTH orthogonal corners solid -> the diagonal is illegal -> no route at all.
	var blocked: Dictionary = _ctx({
		"origin": _cell(2, 2),
		"bounds": bounds,
		"authoritative_walkable": {"2,2": true, "3,3": true},
	})
	var blocked_result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), blocked, _escort_state(_cell(3, 3)), _hazard_ctx(), _capacity_cfg()
	)
	if str(blocked_result["stop_reason"]) != "no_route":
		return _fail("two solid corners should forbid the diagonal, got %s" % str(blocked_result["stop_reason"]))
	if (blocked_result["final_destination"] as Dictionary) != _cell(2, 2):
		return _fail("spirit cut a two-solid-corner diagonal: %s" % str(blocked_result["final_destination"]))

	# ONE corner open -> the diagonal is legal -> the spirit takes it.
	var open_board: Dictionary = _ctx({
		"origin": _cell(2, 2),
		"bounds": bounds,
		"authoritative_walkable": {"2,2": true, "3,2": true, "3,3": true},
	})
	var open_result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), open_board, _escort_state(_cell(3, 3)), _hazard_ctx(), _capacity_cfg()
	)
	if (open_result["final_destination"] as Dictionary) != _cell(3, 3):
		return _fail("one open corner should permit the diagonal, got %s" % str(open_result["final_destination"]))
	if not bool(ResultContract.validate(open_result)["valid"]):
		return _fail("diagonal result rejected: %s" % str(ResultContract.validate(open_result)))
	return _pass()


## Hazards resolve for the spirit exactly as for any actor: Binding halts it and
## Burning bills it at end of activation. Board + facts from MovementHazardFixtures.
static func _t_hazards_apply() -> Dictionary:
	var hazards: Array = HazardFixtures.authored_set()
	var bounds: Dictionary = HazardFixtures.board_bounds()

	# Binding sits at (6,5): stepping into it stops the spirit there.
	var binding_ctx: Dictionary = _ctx({
		"origin": _cell(5, 5),
		"bounds": bounds,
		"authoritative_walkable": HazardFixtures.walkable_open(),
		"known_hazards": hazards,
	})
	var binding_result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), binding_ctx, _escort_state(_cell(9, 5)), _hazard_ctx(_hazard_cfg()), _capacity_cfg()
	)
	if str(binding_result["stop_reason"]) != "binding_stop":
		return _fail("binding did not stop the spirit: %s" % str(binding_result["stop_reason"]))
	if not _hazard_types(binding_result).has("binding"):
		return _fail("binding hazard not projected: %s" % str(_hazard_types(binding_result)))
	if not bool(ResultContract.validate(binding_result)["valid"]):
		return _fail("binding result rejected: %s" % str(ResultContract.validate(binding_result)))

	# Burning sits at (8,5): entering it bills end-of-activation damage.
	var burning_ctx: Dictionary = _ctx({
		"origin": _cell(7, 5),
		"bounds": bounds,
		"authoritative_walkable": HazardFixtures.walkable_open(),
		"known_hazards": hazards,
	})
	var burning_result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), burning_ctx, _escort_state(_cell(8, 5)), _hazard_ctx(_hazard_cfg()), _capacity_cfg()
	)
	if (burning_result["final_destination"] as Dictionary) != _cell(8, 5):
		return _fail("spirit did not enter the burning cell: %s" % str(burning_result["final_destination"]))
	if not _hazard_types(burning_result).has("burning"):
		return _fail("burning hazard not projected: %s" % str(_hazard_types(burning_result)))
	var burn_damage: int = 0
	for event_value: Variant in burning_result["events"] as Array:
		burn_damage += int((event_value as Dictionary).get("damage", 0))
	if burn_damage <= 0:
		return _fail("burning billed the spirit no damage")
	if not bool(ResultContract.validate(burning_result)["valid"]):
		return _fail("burning result rejected: %s" % str(ResultContract.validate(burning_result)))
	return _pass()


## A rich run (hostile control + difficult terrain + hazard) still validates.
static func _t_result_validate() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(2, 5),
		"bounds": HazardFixtures.board_bounds(),
		"terrain_costs": {"3,5": 1},
		"known_hazards": HazardFixtures.authored_set(),
		"perceived_actors": [{
			"id": "enemy.1",
			"position": _cell(2, 6),
			"controlling_state": true,
			"is_dead": false,
			"is_ko": false,
			"is_structure": false,
		}],
		"relationships": {"enemy.1": "hostile"},
	})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(6, 5)), _hazard_ctx(_hazard_cfg()), _capacity_cfg()
	)
	var validation: Dictionary = ResultContract.validate(result)
	if not bool(validation["valid"]):
		return _fail("rich guide result rejected: %s" % str(validation))
	for field: String in ["mover_id", "activation_id", "goal_id", "option_id", "purpose"]:
		if str(result[field]).is_empty():
			return _fail("correlation field %s is empty" % field)
	if str(result["mover_id"]) != "spirit.1":
		return _fail("mover_id not taken from the spirit actor: %s" % str(result["mover_id"]))
	return _pass()


# ---------------------------------------------------------------------------
# BOUNDARY: NO OBJECTIVE AUTHORITY
# ---------------------------------------------------------------------------

## The service never scores GUIDE progress. Even when the context carries a
## non-zero objective_progress, the result reports 0.0 — progress is decided by
## the caller AFTER this activation resolves.
static func _t_no_objective_authority() -> Dictionary:
	var context: Dictionary = _ctx({"objective_pressure": {"objective_progress": 0.85}})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if not is_equal_approx(float(result["objective_progress"]), 0.0):
		return _fail("service asserted objective progress: %s" % str(result["objective_progress"]))
	for key: String in ["destination_reached", "escort_started", "guide_protect_counter", "guide_mode"]:
		if result.has(key):
			return _fail("result leaked objective authority field %s" % key)
	# The spirit still MOVED — movement happens, scoring does not.
	if (result["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("movement did not occur: %s" % str(result["final_destination"]))
	return _pass()


## The caller owns the movement gate; false means hold, with no capacity spent.
static func _t_gate_false_holds() -> Dictionary:
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), _ctx(), _escort_state(_cell(5, 1), {"should_move": false}), _hazard_ctx(), _capacity_cfg()
	)
	if str(result["stop_reason"]) != "no_route":
		return _fail("gated spirit should report no_route, got %s" % str(result["stop_reason"]))
	if (result["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("gated spirit moved: %s" % str(result["final_destination"]))
	if int(result["voluntary_cost"]) != 0:
		return _fail("gated spirit spent capacity: %d" % int(result["voluntary_cost"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("gated result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


# ---------------------------------------------------------------------------
# BUDGET WALL vs. SURCHARGED / EXPENSIVE FIRST EDGE
#
# The authored pace stamps capacity 1 AND commitment 1, so MovementExecutor's
# budget wall is min(capacity, commitment) == 1 (MovementExecutor.gd:135). Any
# first edge that costs 2 — the +1 hostile-control surcharge when either edge
# endpoint is Chebyshev-1 to an ACTIVE CONTROLLING hostile (:132-133, :250-257),
# or a terrain_costs entry of 2 (:131, :219-223) — exceeds that wall and the walk
# breaks before committing anything.
#
# These three tests assert ACTUAL DISPLACEMENT, not merely that the result
# validates: a pinned spirit that returns a perfectly valid zero-movement result
# is exactly the failure mode under investigation.
# ---------------------------------------------------------------------------

## Deterministic active-controlling hostile actor at `pos`.
static func _hostile(id: String, pos: Dictionary) -> Dictionary:
	return {
		"id": id,
		"position": pos,
		"controlling_state": true,
		"is_dead": false,
		"is_ko": false,
		"is_structure": false,
	}


static func _movement_report(label: String, result: Dictionary) -> String:
	return "%s: stop_reason=%s origin=%s final=%s traversed=%s voluntary_cost=%d remaining_capacity=%d" % [
		label,
		str(result.get("stop_reason", "")),
		str(result.get("origin", {})),
		str(result.get("final_destination", {})),
		str(result.get("actual_traversed_cells", [])),
		int(result.get("voluntary_cost", 0)),
		int(result.get("remaining_capacity", 0)),
	]


## CLAIM 1 (protect) — MODE_PROTECT exists to flee a threat that is ALREADY
## adjacent. Spirit (3,3), active controlling hostile at (4,4) = Chebyshev 1 from
## the origin, so EVERY candidate edge pays the hostile-control surcharge on its
## `from` endpoint. The spirit must still displace one cell.
static func _t_protect_moves_with_adjacent_hostile() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": 7, "h": 7},
		"perceived_actors": [_hostile("enemy.1", _cell(4, 4))],
		"relationships": {"enemy.1": "hostile"},
	})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _protect_state([_cell(4, 4)]), _hazard_ctx(), _capacity_cfg()
	)
	var origin: Dictionary = _cell(3, 3)
	if (result["final_destination"] as Dictionary) == origin:
		return _fail("spirit pinned by hostile-control surcharge — protect mode cannot flee an adjacent threat. " \
			+ _movement_report("protect/adjacent-hostile", result))
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("protect step was not exactly one cell. " \
			+ _movement_report("protect/adjacent-hostile", result))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("protect/adjacent-hostile result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## CLAIM 1 (escort) — the spirit's first step ENDS Chebyshev-1 from an active
## controlling hostile. Origin (1,1) is Chebyshev 2 from the hostile at (3,1), so
## only the destination endpoint triggers the surcharge. The spirit must displace.
static func _t_escort_moves_adjacent_hostile() -> Dictionary:
	var context: Dictionary = _ctx({
		"perceived_actors": [_hostile("enemy.1", _cell(3, 1))],
		"relationships": {"enemy.1": "hostile"},
	})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if (result["final_destination"] as Dictionary) == _cell(1, 1):
		return _fail("spirit pinned by hostile-control surcharge on the step destination — escort cannot advance. " \
			+ _movement_report("escort/surcharged-step", result))
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("escort step was not exactly one cell. " \
			+ _movement_report("escort/surcharged-step", result))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("escort/surcharged-step result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


## CLAIM 2 — the first step's cell carries a terrain_costs entry of 2 ("difficult"
## ground). A single-cell corridor removes any cheaper detour, so the spirit must
## either pay 2 or never move at all.
static func _t_escort_moves_onto_cost_two_terrain() -> Dictionary:
	var corridor: Dictionary = {"1,1": true, "2,1": true, "3,1": true, "4,1": true, "5,1": true}
	var context: Dictionary = _ctx({
		"authoritative_walkable": corridor,
		"terrain_costs": {"2,1": 2},
	})
	var result: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, _escort_state(_cell(5, 1)), _hazard_ctx(), _capacity_cfg()
	)
	if str(result["stop_reason"]) == "no_route":
		return _fail("fixture is wrong — the corridor route was not found, the test proves nothing. " \
			+ _movement_report("escort/cost-2-terrain", result))
	if (result["final_destination"] as Dictionary) == _cell(1, 1):
		return _fail("spirit stalled on cost-2 terrain — capacity 1 can never pay a difficult cell. " \
			+ _movement_report("escort/cost-2-terrain", result))
	if (result["actual_traversed_cells"] as Array).size() != 1:
		return _fail("cost-2 escort step was not exactly one cell. " \
			+ _movement_report("escort/cost-2-terrain", result))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("escort/cost-2-terrain result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


# ---------------------------------------------------------------------------
# DETERMINISM / PURITY
# ---------------------------------------------------------------------------

static func _t_deterministic_replay() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": 7, "h": 7},
		"known_hazards": HazardFixtures.burning_at(_cell(2, 2)),
	})
	var state: Dictionary = _protect_state([_cell(4, 4), _cell(6, 6)])
	var first: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, state, _hazard_ctx(_hazard_cfg()), _capacity_cfg()
	)
	var second: Dictionary = GuideActivation.activate_spirit(
		_spirit(), context, state, _hazard_ctx(_hazard_cfg()), _capacity_cfg()
	)
	if first != second:
		return _fail("guide activation is not deterministic across replays")

	var escort_context: Dictionary = _ctx()
	var escort_first: Dictionary = GuideActivation.activate_spirit(
		_spirit(), escort_context, _escort_state(_cell(7, 4)), _hazard_ctx(), _capacity_cfg()
	)
	var escort_second: Dictionary = GuideActivation.activate_spirit(
		_spirit(), escort_context, _escort_state(_cell(7, 4)), _hazard_ctx(), _capacity_cfg()
	)
	if escort_first != escort_second:
		return _fail("escort activation is not deterministic across replays")
	return _pass()


static func _t_no_mutation() -> Dictionary:
	var actor: Dictionary = _spirit()
	var context: Dictionary = _ctx({
		"origin": _cell(3, 3),
		"bounds": {"w": 7, "h": 7},
		"occupancy": {"2,2": "echo.1"},
		"known_hazards": HazardFixtures.authored_set(),
	})
	var state: Dictionary = _protect_state([_cell(4, 4)])
	var cfg: Dictionary = _capacity_cfg()
	var ledger: Dictionary = _hazard_ctx(_hazard_cfg())

	var actor_before: Dictionary = actor.duplicate(true)
	var context_before: Dictionary = context.duplicate(true)
	var state_before: Dictionary = state.duplicate(true)
	var cfg_before: Dictionary = cfg.duplicate(true)

	GuideActivation.activate_spirit(actor, context, state, ledger, cfg)

	if actor != actor_before:
		return _fail("spirit actor was mutated")
	if context != context_before:
		return _fail("movement context was mutated")
	if state != state_before:
		return _fail("guide_state was mutated")
	if cfg != cfg_before:
		return _fail("capacity_cfg was mutated")
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
