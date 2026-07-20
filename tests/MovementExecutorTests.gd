# res://tests/MovementExecutorTests.gd
# V2-COMBAT-002 Slice 3 (DORMANT): physical, edge-by-edge movement executor.
#
# Deterministic, hand-built boards / intents / contexts. The executor is pure —
# every board, hazard fact, hostile, and budget is constructed by hand so each test
# proves exactly one rule. Events are cross-checked against the authoritative
# MovementEvent / MovementResult contracts where integration matters.

class_name MovementExecutorTests
extends RefCounted

const Executor = preload("res://core/movement/MovementExecutor.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/executor/orthogonal_and_diagonal_base_cost", Callable(MovementExecutorTests, "_t_base_cost"))
	runner.register_test("movement/executor/difficult_terrain_cost_two", Callable(MovementExecutorTests, "_t_difficult_terrain"))
	runner.register_test("movement/executor/diagonal_one_solid_side_allowed", Callable(MovementExecutorTests, "_t_diagonal_one_solid"))
	runner.register_test("movement/executor/diagonal_two_solid_sides_blocked", Callable(MovementExecutorTests, "_t_diagonal_two_solid"))
	runner.register_test("movement/executor/diagonal_mirror_no_rowcol_bias", Callable(MovementExecutorTests, "_t_diagonal_mirror"))
	runner.register_test("movement/executor/hostile_surcharge_once_per_edge", Callable(MovementExecutorTests, "_t_hostile_surcharge_once"))
	runner.register_test("movement/executor/hostile_surcharge_per_edge_same_source", Callable(MovementExecutorTests, "_t_hostile_surcharge_per_edge"))
	runner.register_test("movement/executor/inactive_actors_project_no_control", Callable(MovementExecutorTests, "_t_inactive_no_control"))
	runner.register_test("movement/executor/dynamic_occupancy_stop", Callable(MovementExecutorTests, "_t_occupancy_stop"))
	runner.register_test("movement/executor/commitment_spent_stop", Callable(MovementExecutorTests, "_t_commitment_stop"))
	runner.register_test("movement/executor/capacity_spent_stop", Callable(MovementExecutorTests, "_t_capacity_stop"))
	runner.register_test("movement/executor/budget_tie_prefers_commitment", Callable(MovementExecutorTests, "_t_budget_tie"))
	runner.register_test("movement/executor/blocked_edge_stop", Callable(MovementExecutorTests, "_t_blocked_edge_stop"))
	runner.register_test("movement/executor/no_route_empty_path", Callable(MovementExecutorTests, "_t_no_route"))
	runner.register_test("movement/executor/forced_unstable_displacement_free", Callable(MovementExecutorTests, "_t_unstable_displacement"))
	runner.register_test("movement/executor/binding_halts_remaining_edges", Callable(MovementExecutorTests, "_t_binding_halts"))
	runner.register_test("movement/executor/path_excludes_start_actual_includes_forced", Callable(MovementExecutorTests, "_t_path_vs_traversal"))
	runner.register_test("movement/executor/events_conform_and_seq_contiguous", Callable(MovementExecutorTests, "_t_events_conform"))
	runner.register_test("movement/executor/deterministic_replay", Callable(MovementExecutorTests, "_t_deterministic_replay"))
	runner.register_test("movement/executor/movement_result_integration", Callable(MovementExecutorTests, "_t_result_integration"))
	runner.register_test("movement/executor/validate_rejects_path_including_origin", Callable(MovementExecutorTests, "_t_validate_rejects_path_including_origin"))
	runner.register_test("movement/executor/no_input_mutation", Callable(MovementExecutorTests, "_t_no_input_mutation"))
	runner.register_test("movement/executor/authored_pace_pays_cost_two_terrain", Callable(MovementExecutorTests, "_t_authored_pace_cost_two_terrain"))
	runner.register_test("movement/executor/authored_pace_pays_hostile_surcharge", Callable(MovementExecutorTests, "_t_authored_pace_surcharge"))
	runner.register_test("movement/executor/authored_pace_allowance_is_step_count", Callable(MovementExecutorTests, "_t_authored_pace_step_allowance"))
	runner.register_test("movement/executor/authored_pace_binding_still_stops", Callable(MovementExecutorTests, "_t_authored_pace_binding_stops"))
	runner.register_test("movement/executor/authored_pace_result_still_validates", Callable(MovementExecutorTests, "_t_authored_pace_result_integration"))


# --- fixtures / helpers ------------------------------------------------------

static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func _cfg() -> Dictionary:
	return {
		"types": ["unstable", "binding", "burning"],
		"unstable": {"displacement_cells": 1, "fallback_damage": 3},
		"binding": {"stops_movement": true},
		"burning": {"end_activation_damage": 3},
	}


static func _hazard_ctx(config: Dictionary = {}) -> Dictionary:
	return {"triggered": {"unstable": false, "binding": false, "burning": false}, "config": config}


## Full 10x10 walkable board minus the listed blocked cells.
static func _board(blocked: Array) -> Dictionary:
	var walkable: Dictionary = {}
	for col: int in range(10):
		for row: int in range(10):
			walkable["%d,%d" % [col, row]] = true
	for cell_value: Variant in blocked:
		var cell: Dictionary = cell_value as Dictionary
		walkable.erase("%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))])
	return walkable


static func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"origin": _cell(1, 1),
		"authoritative_walkable": {},  # {} == StageTerrain all-walkable sentinel (bounds constrain)
		"bounds": {"w": 10, "h": 10},
		"occupancy": {},
		"terrain_costs": {},
		"known_hazards": [],
		"perceived_actors": [],
		"relationships": {},
		"mover_id": "mover.1",
	}
	for key: Variant in overrides.keys():
		base[key] = overrides[key]
	return base


static func _intent(path: Array, commitment: int, mover_id: String = "mover.1") -> Dictionary:
	return {"mover_id": mover_id, "path": path, "commitment": commitment}


static func _profile(capacity: int) -> Dictionary:
	return {"capacity": capacity}


static func _actor(
	id: String, col: int, row: int,
	is_dead: bool = false, is_ko: bool = false,
	is_structure: bool = false, controlling: bool = true
) -> Dictionary:
	return {
		"id": id, "position": _cell(col, row),
		"is_dead": is_dead, "is_ko": is_ko,
		"is_structure": is_structure, "controlling_state": controlling,
	}


static func _step_events(events: Array) -> Array:
	var steps: Array = []
	for event_value: Variant in events:
		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) == "move.step":
			steps.append(event)
	return steps


# --- tests -------------------------------------------------------------------

static func _t_base_cost() -> Dictionary:
	# Two orthogonal + one diagonal edge; every base cost is 1.
	var path: Array = [_cell(2, 1), _cell(3, 1), _cell(4, 2)]
	var out: Dictionary = Executor.execute(_ctx(), _intent(path, 6), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "reached_destination":
		return _fail("expected reached_destination, got %s" % str(out["stop_reason"]))
	if int(out["voluntary_cost"]) != 3:
		return _fail("expected voluntary_cost 3, got %d" % int(out["voluntary_cost"]))
	if int(out["forced_steps"]) != 0:
		return _fail("unexpected forced steps: %d" % int(out["forced_steps"]))
	if (out["actual_traversed_cells"] as Array) != path:
		return _fail("actual traversal mismatch: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(4, 2):
		return _fail("final destination mismatch: %s" % str(out["final_destination"]))
	if int(out["remaining_capacity"]) != 3:
		return _fail("remaining capacity mismatch: %d" % int(out["remaining_capacity"]))
	for step_value: Variant in _step_events(out["events"] as Array):
		if int((step_value as Dictionary)["cost"]) != 1:
			return _fail("base edge cost not 1: %s" % str(step_value))
	return _pass()


static func _t_difficult_terrain() -> Dictionary:
	# Destination (2,1) is a difficult cell (entry cost 2).
	var ctx: Dictionary = _ctx({"terrain_costs": {"2,1": 2, "3,1": 1}})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 3), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "reached_destination":
		return _fail("difficult route did not complete: %s" % str(out["stop_reason"]))
	if int(out["voluntary_cost"]) != 3:
		return _fail("expected voluntary_cost 3 (2+1), got %d" % int(out["voluntary_cost"]))
	var steps: Array = _step_events(out["events"] as Array)
	if int((steps[0] as Dictionary)["cost"]) != 2 or int((steps[1] as Dictionary)["cost"]) != 1:
		return _fail("difficult edge cost misassigned: %s" % str(steps))
	# With commitment 2 and the difficult cost on the SECOND edge, the second edge is
	# unaffordable -> commitment_spent after the first move.
	var ctx2: Dictionary = _ctx({"terrain_costs": {"2,1": 1, "3,1": 2}})
	var stop2: Dictionary = Executor.execute(ctx2, _intent([_cell(2, 1), _cell(3, 1)], 2), _profile(6), _hazard_ctx())
	if str(stop2["stop_reason"]) != "commitment_spent":
		return _fail("difficult second edge did not exhaust commitment: %s" % str(stop2["stop_reason"]))
	if (stop2["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("commitment stop landed wrong: %s" % str(stop2["final_destination"]))
	return _pass()


static func _t_diagonal_one_solid() -> Dictionary:
	# Diagonal (1,1)->(2,2) with ONE solid orthogonal side is legal.
	var col_side: Dictionary = _ctx({"authoritative_walkable": _board([_cell(2, 1)])})
	var out_col: Dictionary = Executor.execute(col_side, _intent([_cell(2, 2)], 2), _profile(6), _hazard_ctx())
	if str(out_col["stop_reason"]) != "reached_destination":
		return _fail("diagonal past a single solid col-side blocked: %s" % str(out_col["stop_reason"]))
	if int(out_col["voluntary_cost"]) != 1:
		return _fail("diagonal base cost not 1: %d" % int(out_col["voluntary_cost"]))
	return _pass()


static func _t_diagonal_two_solid() -> Dictionary:
	# Diagonal (1,1)->(2,2) with BOTH solid orthogonal sides is illegal.
	var boxed: Dictionary = _ctx({"authoritative_walkable": _board([_cell(2, 1), _cell(1, 2)])})
	var out: Dictionary = Executor.execute(boxed, _intent([_cell(2, 2)], 2), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "blocked_edge":
		return _fail("two-solid diagonal not blocked: %s" % str(out["stop_reason"]))
	if not (out["actual_traversed_cells"] as Array).is_empty():
		return _fail("blocked diagonal still traversed: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("blocked diagonal moved the mover: %s" % str(out["final_destination"]))
	return _pass()


static func _t_diagonal_mirror() -> Dictionary:
	# Neither orthogonal side ALONE blocks (row-side or col-side) — proving no row/col
	# bias — but BOTH together do. Mirror of _t_diagonal_two_solid across the corner.
	var row_side: Dictionary = _ctx({"authoritative_walkable": _board([_cell(1, 2)])})
	var out_row: Dictionary = Executor.execute(row_side, _intent([_cell(2, 2)], 2), _profile(6), _hazard_ctx())
	if str(out_row["stop_reason"]) != "reached_destination":
		return _fail("diagonal past a single solid row-side blocked (row/col bias): %s" % str(out_row["stop_reason"]))
	var col_side: Dictionary = _ctx({"authoritative_walkable": _board([_cell(2, 1)])})
	var out_col: Dictionary = Executor.execute(col_side, _intent([_cell(2, 2)], 2), _profile(6), _hazard_ctx())
	if str(out_col["stop_reason"]) != "reached_destination":
		return _fail("diagonal past a single solid col-side blocked (row/col bias): %s" % str(out_col["stop_reason"]))
	var both: Dictionary = _ctx({"authoritative_walkable": _board([_cell(2, 1), _cell(1, 2)])})
	var out_both: Dictionary = Executor.execute(both, _intent([_cell(2, 2)], 2), _profile(6), _hazard_ctx())
	if str(out_both["stop_reason"]) != "blocked_edge":
		return _fail("two-solid diagonal legal in mirror fixture: %s" % str(out_both["stop_reason"]))
	return _pass()


static func _t_hostile_surcharge_once() -> Dictionary:
	# Edge (1,1)->(2,1) flanked by TWO active hostiles: surcharge is +1 ONCE, both ids
	# recorded sorted.
	var ctx: Dictionary = _ctx({
		"perceived_actors": [_actor("enemy.b", 1, 0), _actor("enemy.a", 2, 0)],
		"relationships": {"enemy.a": "hostile", "enemy.b": "hostile"},
	})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 2), _profile(6), _hazard_ctx())
	if int(out["voluntary_cost"]) != 2:
		return _fail("expected surcharged cost 2 (1+1 once), got %d" % int(out["voluntary_cost"]))
	if (out["hostile_constraints"] as Array) != ["enemy.a", "enemy.b"]:
		return _fail("hostile constraints not sorted/complete: %s" % str(out["hostile_constraints"]))
	var steps: Array = _step_events(out["events"] as Array)
	if int((steps[0] as Dictionary)["cost"]) != 2:
		return _fail("edge cost did not include single surcharge: %s" % str(steps))
	return _pass()


static func _t_hostile_surcharge_per_edge() -> Dictionary:
	# One hostile adjacent to both edges' endpoints: EACH edge pays +1, id recorded once.
	var ctx: Dictionary = _ctx({
		"perceived_actors": [_actor("enemy.c", 2, 0)],
		"relationships": {"enemy.c": "hostile"},
	})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 4), _profile(6), _hazard_ctx())
	if int(out["voluntary_cost"]) != 4:
		return _fail("expected 4 (each edge 1+1), got %d" % int(out["voluntary_cost"]))
	if (out["hostile_constraints"] as Array) != ["enemy.c"]:
		return _fail("source id not deduped/recorded once: %s" % str(out["hostile_constraints"]))
	return _pass()


static func _t_inactive_no_control() -> Dictionary:
	# Friendly / neutral / dead / KO / structure / non-controlling actors all adjacent
	# to the edge project ZERO control.
	var ctx: Dictionary = _ctx({
		"perceived_actors": [
			_actor("friend", 2, 0),
			_actor("neutral", 0, 1),
			_actor("dead", 3, 1, true, false, false, true),
			_actor("ko", 1, 0, false, true, false, true),
			_actor("wall", 2, 2, false, false, true, false),
			_actor("passive", 0, 2, false, false, false, false),
		],
		"relationships": {
			"friend": "friendly", "neutral": "neutral", "dead": "hostile",
			"ko": "hostile", "wall": "hostile", "passive": "hostile",
		},
	})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 2), _profile(6), _hazard_ctx())
	if int(out["voluntary_cost"]) != 1:
		return _fail("inactive actors added a surcharge: %d" % int(out["voluntary_cost"]))
	if not (out["hostile_constraints"] as Array).is_empty():
		return _fail("inactive actors recorded as controllers: %s" % str(out["hostile_constraints"]))
	return _pass()


static func _t_occupancy_stop() -> Dictionary:
	# The second cell is physically occupied -> stop occupied after one move.
	var ctx: Dictionary = _ctx({"occupancy": {"3,1": "blocker.1"}})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 4), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "occupied":
		return _fail("occupied cell not detected: %s" % str(out["stop_reason"]))
	if (out["actual_traversed_cells"] as Array) != [_cell(2, 1)]:
		return _fail("occupied stop traversal wrong: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("occupied stop final wrong: %s" % str(out["final_destination"]))
	return _pass()


static func _t_commitment_stop() -> Dictionary:
	# Committed budget 2 exhausted before a 3-cell path completes.
	var out: Dictionary = Executor.execute(_ctx(), _intent([_cell(2, 1), _cell(3, 1), _cell(4, 1)], 2), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "commitment_spent":
		return _fail("commitment not exhausted: %s" % str(out["stop_reason"]))
	if int(out["voluntary_cost"]) != 2:
		return _fail("spent past commitment: %d" % int(out["voluntary_cost"]))
	if (out["final_destination"] as Dictionary) != _cell(3, 1):
		return _fail("commitment stop final wrong: %s" % str(out["final_destination"]))
	return _pass()


static func _t_capacity_stop() -> Dictionary:
	# Profile capacity (2) is tighter than commitment (4) -> capacity_spent.
	var out: Dictionary = Executor.execute(_ctx(), _intent([_cell(2, 1), _cell(3, 1), _cell(4, 1)], 4), _profile(2), _hazard_ctx())
	if str(out["stop_reason"]) != "capacity_spent":
		return _fail("capacity wall not applied: %s" % str(out["stop_reason"]))
	if int(out["voluntary_cost"]) != 2:
		return _fail("spent past capacity: %d" % int(out["voluntary_cost"]))
	if int(out["remaining_capacity"]) != 0:
		return _fail("remaining capacity should be 0: %d" % int(out["remaining_capacity"]))
	return _pass()


static func _t_budget_tie() -> Dictionary:
	# capacity == commitment == 2: on exhaustion the mover's OWN committed budget label wins.
	var out: Dictionary = Executor.execute(_ctx(), _intent([_cell(2, 1), _cell(3, 1), _cell(4, 1)], 2), _profile(2), _hazard_ctx())
	if str(out["stop_reason"]) != "commitment_spent":
		return _fail("tie should prefer commitment_spent: %s" % str(out["stop_reason"]))
	return _pass()


static func _t_blocked_edge_stop() -> Dictionary:
	# First edge leaps two cells (non-adjacent) -> illegal edge.
	var out: Dictionary = Executor.execute(_ctx(), _intent([_cell(3, 1)], 2), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "blocked_edge":
		return _fail("non-adjacent leap not blocked: %s" % str(out["stop_reason"]))
	if not (out["actual_traversed_cells"] as Array).is_empty():
		return _fail("blocked edge still moved: %s" % str(out["actual_traversed_cells"]))
	return _pass()


static func _t_no_route() -> Dictionary:
	# Empty path -> no_route, mover stays at origin.
	var out: Dictionary = Executor.execute(_ctx(), _intent([], 0), _profile(6), _hazard_ctx())
	if str(out["stop_reason"]) != "no_route":
		return _fail("empty path not no_route: %s" % str(out["stop_reason"]))
	if not (out["actual_traversed_cells"] as Array).is_empty():
		return _fail("no_route traversed cells: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("no_route moved the mover: %s" % str(out["final_destination"]))
	if int(out["voluntary_cost"]) != 0:
		return _fail("no_route charged cost: %d" % int(out["voluntary_cost"]))
	return _pass()


static func _t_unstable_displacement() -> Dictionary:
	# Unstable at (3,1): entering it (from the west) displaces free to (4,1). No recursive
	# retrigger; displacement consumes no voluntary capacity.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")]})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 4), _profile(6), _hazard_ctx(_cfg()))
	if str(out["stop_reason"]) != "reached_destination":
		return _fail("unstable route did not complete: %s" % str(out["stop_reason"]))
	if int(out["forced_steps"]) != 1:
		return _fail("expected 1 forced step, got %d" % int(out["forced_steps"]))
	if int(out["voluntary_cost"]) != 2:
		return _fail("displacement consumed capacity: %d" % int(out["voluntary_cost"]))
	if (out["actual_traversed_cells"] as Array) != [_cell(2, 1), _cell(3, 1), _cell(4, 1)]:
		return _fail("forced cell not chronologically appended: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(4, 1):
		return _fail("final not the displaced cell: %s" % str(out["final_destination"]))
	# Exactly one forced (displacement) movement event.
	var forced: int = 0
	for event_value: Variant in out["events"] as Array:
		if str((event_value as Dictionary).get("movement_kind", "")) == "forced":
			forced += 1
	if forced != 1:
		return _fail("recursive unstable retrigger: %d forced events" % forced)
	if (out["hazards"] as Array).size() != 1:
		return _fail("hazard descriptor not projected: %s" % str(out["hazards"]))
	return _pass()


static func _t_binding_halts() -> Dictionary:
	# Binding at (3,1) halts before the remaining edge (4,1) is walked.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.b", _cell(3, 1), "binding")]})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1), _cell(4, 1)], 6), _profile(6), _hazard_ctx(_cfg()))
	if str(out["stop_reason"]) != "binding_stop":
		return _fail("binding did not halt: %s" % str(out["stop_reason"]))
	if (out["actual_traversed_cells"] as Array) != [_cell(2, 1), _cell(3, 1)]:
		return _fail("binding did not stop remaining edges: %s" % str(out["actual_traversed_cells"]))
	if (out["final_destination"] as Dictionary) != _cell(3, 1):
		return _fail("binding final wrong: %s" % str(out["final_destination"]))
	var last: Dictionary = (out["events"] as Array).back() as Dictionary
	if str(last.get("stop_reason", "")) != "binding_stop":
		return _fail("terminal event is not the binding stop: %s" % str(last))
	if str(last.get("type", "")) != "hazard.binding.stop":
		return _fail("extra terminal event appended after binding: %s" % str(last))
	return _pass()


static func _t_path_vs_traversal() -> Dictionary:
	# planned_path excludes start; actual_traversed_cells includes the forced cell.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")]})
	var path: Array = [_cell(2, 1), _cell(3, 1)]
	var out: Dictionary = Executor.execute(ctx, _intent(path, 4), _profile(6), _hazard_ctx(_cfg()))
	if (out["planned_path"] as Array) != path:
		return _fail("planned_path not equal to intent path (start leaked?): %s" % str(out["planned_path"]))
	if (out["planned_path"] as Array).has(_cell(1, 1)):
		return _fail("planned_path included start")
	if not (out["actual_traversed_cells"] as Array).has(_cell(4, 1)):
		return _fail("actual traversal missing forced cell: %s" % str(out["actual_traversed_cells"]))
	if (out["actual_traversed_cells"] as Array).size() <= (out["planned_path"] as Array).size():
		return _fail("forced traversal not longer than planned path")
	return _pass()


static func _t_events_conform() -> Dictionary:
	# A rich run: hostile surcharge + unstable displacement. Every event validates and
	# seq is contiguous 0..n.
	var ctx: Dictionary = _ctx({
		"perceived_actors": [_actor("enemy.a", 2, 0)],
		"relationships": {"enemy.a": "hostile"},
		"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")],
	})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 6), _profile(6), _hazard_ctx(_cfg()))
	var events: Array = out["events"] as Array
	var expected_seq: int = 0
	for event_value: Variant in events:
		var event: Dictionary = event_value as Dictionary
		var result: Dictionary = EventContract.validate(event)
		if not bool(result["valid"]):
			return _fail("event failed MovementEvent.validate: %s (%s)" % [str(result), str(event)])
		if int(event["seq"]) != expected_seq:
			return _fail("seq not contiguous: expected %d got %d" % [expected_seq, int(event["seq"])])
		expected_seq += 1
	if int(out["next_seq"]) != expected_seq:
		return _fail("next_seq mismatch: %d vs %d" % [int(out["next_seq"]), expected_seq])
	return _pass()


static func _t_deterministic_replay() -> Dictionary:
	var make_ctx: Callable = func() -> Dictionary:
		return _ctx({
			"perceived_actors": [_actor("enemy.a", 2, 0)],
			"relationships": {"enemy.a": "hostile"},
			"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")],
			"terrain_costs": {"2,1": 2},
		})
	var out_a: Dictionary = Executor.execute(make_ctx.call(), _intent([_cell(2, 1), _cell(3, 1)], 6), _profile(6), _hazard_ctx(_cfg()))
	var out_b: Dictionary = Executor.execute(make_ctx.call(), _intent([_cell(2, 1), _cell(3, 1)], 6), _profile(6), _hazard_ctx(_cfg()))
	if out_a != out_b:
		return _fail("identical inputs produced different outcomes")
	return _pass()


static func _t_result_integration() -> Dictionary:
	# The outcome must assemble into a valid authoritative MovementResult.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")]})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1), _cell(3, 1)], 4), _profile(6), _hazard_ctx(_cfg()))
	var result: Dictionary = ResultContract.build(
		"mover.1", "activation.1", "goal.advance", "option.advance", "advance",
		out["origin"] as Dictionary, out["final_destination"] as Dictionary,
		out["planned_path"] as Array, out["actual_traversed_cells"] as Array,
		int(out["voluntary_cost"]), int(out["forced_steps"]), int(out["remaining_capacity"]),
		str(out["stop_reason"]), out["events"] as Array,
		{"type": "actor.move", "target_id": "", "payload": {}},
		{"type": "actor.move", "target_id": "", "payload": {}}, {},
		out["hazards"] as Array, 0.0,
		{"hostile_control_sources": out["hostile_constraints"]}
	)
	var validated: Dictionary = ResultContract.validate(result)
	if not bool(validated["valid"]):
		return _fail("assembled MovementResult rejected: %s" % str(validated))
	return _pass()


static func _t_validate_rejects_path_including_origin() -> Dictionary:
	# NEGATIVE: a deliberately malformed MovementResult whose planned_path INCLUDES the
	# origin cell must be REJECTED by the authoritative validator with the specific field
	# reason 'path_includes_origin'. This pins slice-3 producers against a regression that
	# would make the validator permissive about the path-excludes-origin invariant.
	var origin: Dictionary = _cell(1, 1)
	var malformed: Dictionary = ResultContract.build(
		"mover.1", "activation.1", "goal.advance", "option.advance", "advance",
		origin, _cell(2, 1),
		[_cell(1, 1), _cell(2, 1)],  # planned_path ILLEGALLY re-lists the origin (1,1)
		[_cell(2, 1)],
		1, 0, 5,
		"reached_destination", [],
		{"type": "actor.move", "target_id": "", "payload": {}},
		{"type": "actor.move", "target_id": "", "payload": {}}, {},
		[], 0.0,
		{"hostile_control_sources": []}
	)
	var validated: Dictionary = ResultContract.validate(malformed)
	if bool(validated["valid"]):
		return _fail("validator accepted a planned_path that includes the origin")
	if str(validated["reason"]) != "path_includes_origin":
		return _fail("expected reason 'path_includes_origin', got '%s'" % str(validated["reason"]))
	if str(validated["field"]) != "planned_path":
		return _fail("expected field 'planned_path', got '%s'" % str(validated["field"]))
	return _pass()


static func _t_no_input_mutation() -> Dictionary:
	var ctx: Dictionary = _ctx({
		"perceived_actors": [_actor("enemy.a", 2, 0)],
		"relationships": {"enemy.a": "hostile"},
		"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable")],
		"terrain_costs": {"2,1": 2},
		"occupancy": {"9,9": "someone"},
	})
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 6)
	var profile: Dictionary = _profile(6)
	var hazard_ctx: Dictionary = _hazard_ctx(_cfg())
	var ctx_before: Dictionary = ctx.duplicate(true)
	var intent_before: Dictionary = intent.duplicate(true)
	var profile_before: Dictionary = profile.duplicate(true)
	var hazard_before: Dictionary = hazard_ctx.duplicate(true)
	Executor.execute(ctx, intent, profile, hazard_ctx)
	if ctx != ctx_before:
		return _fail("execute mutated context")
	if intent != intent_before:
		return _fail("execute mutated intent")
	if profile != profile_before:
		return _fail("execute mutated profile")
	if hazard_ctx != hazard_before:
		return _fail("execute mutated hazard_ctx ledger input")
	return _pass()


# ---------------------------------------------------------------------------
# AUTHORED PACE (Slice 4 fix)
#
# A profile carrying a non-empty authored_override paces in STEPS, not cost: it is
# permitted min(authored_override.capacity, commitment) EDGES whatever they cost.
# Normal movers keep the cost-budget wall UNCHANGED — every test below runs the
# same board twice (authored vs normal) so the two paths are pinned as divergent.
# ---------------------------------------------------------------------------

## Authored capacity-1 profile (the non-joining guide spirit / burdened carrier shape).
static func _authored_profile(capacity: int = 1, source: String = "guide_spirit_nonjoining") -> Dictionary:
	return {
		"capacity": capacity,
		"authored_override": {"source": source, "capacity": capacity},
	}


## An authored mover crosses a cost-2 ("difficult") cell on its single edge; an
## otherwise identical NORMAL capacity-1 mover cannot afford it and never moves.
static func _t_authored_pace_cost_two_terrain() -> Dictionary:
	var ctx: Dictionary = _ctx({"terrain_costs": {"2,1": 2}})

	var authored: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 1), _authored_profile(), _hazard_ctx())
	if str(authored["stop_reason"]) != "reached_destination":
		return _fail("authored mover did not complete its cost-2 edge: %s" % str(authored["stop_reason"]))
	if (authored["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("authored mover did not displace: %s" % str(authored["final_destination"]))
	if (authored["actual_traversed_cells"] as Array) != [_cell(2, 1)]:
		return _fail("authored traversal was not exactly one cell: %s" % str(authored["actual_traversed_cells"]))
	# TRUTHFUL accounting: the real edge cost (2) is charged and carried on the event,
	# while remaining_capacity clamps at 0 so MovementResult.validate accepts it.
	if int(authored["voluntary_cost"]) != 2:
		return _fail("authored edge cost not recorded truthfully: %d" % int(authored["voluntary_cost"]))
	if int(authored["remaining_capacity"]) != 0:
		return _fail("remaining_capacity must clamp at 0: %d" % int(authored["remaining_capacity"]))
	var steps: Array = _step_events(authored["events"] as Array)
	if int((steps[0] as Dictionary)["cost"]) != 2:
		return _fail("authored step event lost the real cost: %s" % str(steps))

	# Divergence: the SAME board with a normal (non-authored) capacity-1 mover stalls.
	var normal: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 1), _profile(1), _hazard_ctx())
	if (normal["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("normal capacity-1 mover must NOT afford a cost-2 edge: %s" % str(normal["final_destination"]))
	if str(normal["stop_reason"]) != "commitment_spent":
		return _fail("normal cost-budget wall changed: %s" % str(normal["stop_reason"]))
	return _pass()


## An authored mover steps while under hostile control (the +1 surcharge makes the
## edge cost 2); a normal capacity-1 mover is pinned. This is the MODE_PROTECT case.
static func _t_authored_pace_surcharge() -> Dictionary:
	var ctx: Dictionary = _ctx({
		"perceived_actors": [_actor("enemy.a", 2, 0)],
		"relationships": {"enemy.a": "hostile"},
	})

	var authored: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 1), _authored_profile(), _hazard_ctx())
	if (authored["final_destination"] as Dictionary) == _cell(1, 1):
		return _fail("authored mover pinned by the hostile-control surcharge: %s" % str(authored["stop_reason"]))
	if int(authored["voluntary_cost"]) != 2:
		return _fail("surcharged authored edge cost not recorded: %d" % int(authored["voluntary_cost"]))
	if (authored["hostile_constraints"] as Array) != ["enemy.a"]:
		return _fail("authored mover lost its hostile constraint: %s" % str(authored["hostile_constraints"]))

	var normal: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 1), _profile(1), _hazard_ctx())
	if (normal["final_destination"] as Dictionary) != _cell(1, 1):
		return _fail("normal capacity-1 mover must NOT afford a surcharged edge: %s" % str(normal["final_destination"]))
	return _pass()


## The allowance is a STEP COUNT: an authored capacity-1 mover takes exactly one
## edge of a longer path and then stops — it never rides free past its pace.
static func _t_authored_pace_step_allowance() -> Dictionary:
	var path: Array = [_cell(2, 1), _cell(3, 1), _cell(4, 1)]
	var out: Dictionary = Executor.execute(_ctx(), _intent(path, 1), _authored_profile(), _hazard_ctx())
	if (out["actual_traversed_cells"] as Array) != [_cell(2, 1)]:
		return _fail("authored allowance exceeded one step: %s" % str(out["actual_traversed_cells"]))
	if str(out["stop_reason"]) != "commitment_spent":
		return _fail("authored allowance stop reason: %s" % str(out["stop_reason"]))

	# Capacity is the tighter bound (commitment 3, authored capacity 1) -> capacity_spent.
	var capped: Dictionary = Executor.execute(_ctx(), _intent(path, 3), _authored_profile(), _hazard_ctx())
	if (capped["actual_traversed_cells"] as Array) != [_cell(2, 1)]:
		return _fail("authored capacity did not cap the walk: %s" % str(capped["actual_traversed_cells"]))
	if str(capped["stop_reason"]) != "capacity_spent":
		return _fail("authored capacity stop reason: %s" % str(capped["stop_reason"]))

	# An authored override ABOVE 1 generalizes: two edges permitted, cost irrelevant.
	var costly: Dictionary = _ctx({"terrain_costs": {"2,1": 2, "3,1": 2}})
	var two: Dictionary = Executor.execute(costly, _intent(path, 2), _authored_profile(2, "authored.two"), _hazard_ctx())
	if (two["actual_traversed_cells"] as Array) != [_cell(2, 1), _cell(3, 1)]:
		return _fail("authored capacity-2 pace wrong: %s" % str(two["actual_traversed_cells"]))
	if int(two["voluntary_cost"]) != 4:
		return _fail("authored capacity-2 cost not truthful: %d" % int(two["voluntary_cost"]))
	return _pass()


## Hazard semantics are NOT bypassed by the one-step allowance: Binding still stops
## the activation, and Unstable still displaces the authored mover for free.
static func _t_authored_pace_binding_stops() -> Dictionary:
	var bind_ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.b", _cell(2, 1), "binding")]})
	var bound: Dictionary = Executor.execute(
		bind_ctx, _intent([_cell(2, 1), _cell(3, 1)], 1), _authored_profile(), _hazard_ctx(_cfg())
	)
	if str(bound["stop_reason"]) != "binding_stop":
		return _fail("binding did not stop the authored mover: %s" % str(bound["stop_reason"]))
	if (bound["final_destination"] as Dictionary) != _cell(2, 1):
		return _fail("authored mover walked past binding: %s" % str(bound["final_destination"]))
	var last: Dictionary = (bound["events"] as Array).back() as Dictionary
	if str(last.get("type", "")) != "hazard.binding.stop":
		return _fail("authored binding terminal event wrong: %s" % str(last))

	var shift_ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.u", _cell(2, 1), "unstable")]})
	var shifted: Dictionary = Executor.execute(
		shift_ctx, _intent([_cell(2, 1)], 1), _authored_profile(), _hazard_ctx(_cfg())
	)
	if int(shifted["forced_steps"]) != 1:
		return _fail("unstable did not displace the authored mover: %d" % int(shifted["forced_steps"]))
	if int(shifted["voluntary_cost"]) != 1:
		return _fail("forced displacement charged the authored mover: %d" % int(shifted["voluntary_cost"]))
	return _pass()


## An authored mover that OVERSPENDS its capacity still assembles into a valid
## MovementResult — the clamped remaining_capacity is the reconciliation.
static func _t_authored_pace_result_integration() -> Dictionary:
	var ctx: Dictionary = _ctx({
		"terrain_costs": {"2,1": 2},
		"perceived_actors": [_actor("enemy.a", 2, 0)],
		"relationships": {"enemy.a": "hostile"},
	})
	var out: Dictionary = Executor.execute(ctx, _intent([_cell(2, 1)], 1), _authored_profile(), _hazard_ctx(_cfg()))
	if int(out["voluntary_cost"]) != 3:
		return _fail("expected truthful cost 3 (2 terrain + 1 surcharge), got %d" % int(out["voluntary_cost"]))
	if int(out["remaining_capacity"]) != 0:
		return _fail("overspent remaining_capacity must clamp to 0: %d" % int(out["remaining_capacity"]))
	var result: Dictionary = ResultContract.build(
		"mover.1", "activation.1", "guide.protect", "guide.step", "protect",
		out["origin"] as Dictionary, out["final_destination"] as Dictionary,
		out["planned_path"] as Array, out["actual_traversed_cells"] as Array,
		int(out["voluntary_cost"]), int(out["forced_steps"]), int(out["remaining_capacity"]),
		str(out["stop_reason"]), out["events"] as Array,
		{"type": "actor.idle", "target_id": "", "payload": {}},
		{"type": "actor.idle", "target_id": "", "payload": {}}, {},
		out["hazards"] as Array, 0.0,
		{"hostile_control_sources": out["hostile_constraints"]}
	)
	var validated: Dictionary = ResultContract.validate(result)
	if not bool(validated["valid"]):
		return _fail("overspent authored MovementResult rejected: %s" % str(validated))
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
