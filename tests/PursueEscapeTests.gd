# res://tests/PursueEscapeTests.gd
# V2-COMBAT-002 slice 4 (Unit A): shared PURSUE long-axis escape authority.
# Pure/dormant helper — these tests build every board and bounds by hand.

class_name PursueEscapeTests
extends RefCounted

const EscapeService = preload("res://core/movement/PursueEscapeService.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/pursue_escape/far_end_wide_board", Callable(PursueEscapeTests, "_t_far_end_wide_board"))
	runner.register_test("movement/pursue_escape/far_end_tall_board", Callable(PursueEscapeTests, "_t_far_end_tall_board"))
	runner.register_test("movement/pursue_escape/far_end_square_board", Callable(PursueEscapeTests, "_t_far_end_square_board"))
	runner.register_test("movement/pursue_escape/is_escaped_boundary_matches_runtime", Callable(PursueEscapeTests, "_t_is_escaped_boundary_matches_runtime"))
	runner.register_test("movement/pursue_escape/escape_cells_exclude_unwalkable", Callable(PursueEscapeTests, "_t_escape_cells_exclude_unwalkable"))
	runner.register_test("movement/pursue_escape/unwalkable_far_line_still_has_corridor", Callable(PursueEscapeTests, "_t_unwalkable_far_line_still_has_corridor"))
	runner.register_test("movement/pursue_escape/targeted_set_agrees_with_is_escaped", Callable(PursueEscapeTests, "_t_targeted_set_agrees_with_is_escaped"))
	runner.register_test("movement/pursue_escape/graph_respects_blockers", Callable(PursueEscapeTests, "_t_graph_respects_blockers"))
	runner.register_test("movement/pursue_escape/graph_respects_diagonal_legality", Callable(PursueEscapeTests, "_t_graph_respects_diagonal_legality"))
	runner.register_test("movement/pursue_escape/cutoff_exact_order_open_board", Callable(PursueEscapeTests, "_t_cutoff_exact_order_open_board"))
	runner.register_test("movement/pursue_escape/cutoff_projected_not_nearest_edge", Callable(PursueEscapeTests, "_t_cutoff_projected_not_nearest_edge"))
	runner.register_test("movement/pursue_escape/cutoff_pursuer_reach_filter", Callable(PursueEscapeTests, "_t_cutoff_pursuer_reach_filter"))
	runner.register_test("movement/pursue_escape/cutoff_unreachable_escape_empty", Callable(PursueEscapeTests, "_t_cutoff_unreachable_escape_empty"))
	runner.register_test("movement/pursue_escape/mirrored_board_no_row_col_bias", Callable(PursueEscapeTests, "_t_mirrored_board_no_row_col_bias"))
	runner.register_test("movement/pursue_escape/deterministic_replay_and_purity", Callable(PursueEscapeTests, "_t_deterministic_replay_and_purity"))


# ---------------------------------------------------------------------------
# Long-axis far-end line
# ---------------------------------------------------------------------------

## WIDE board (w > h): the escape BAND is the last TWO columns (w-2 and w-1),
## because `is_escaped` wins on `col >= max_col - 1`. Targeting the max-col column
## ALONE (the pre-fix behavior) anchored routes one step deeper than the quarry
## ever has to travel.
static func _t_far_end_wide_board() -> Dictionary:
	var bounds := {"w": 6, "h": 3}
	var cells: Array = EscapeService.escape_cells(bounds, {})
	var expected: Array = [
		{"col": 4, "row": 0}, {"col": 4, "row": 1}, {"col": 4, "row": 2},
		{"col": 5, "row": 0}, {"col": 5, "row": 1}, {"col": 5, "row": 2},
	]
	if cells != expected:
		return _fail("wide escape band wrong: %s" % str(cells))
	var graph: Dictionary = EscapeService.escape_graph({"col": 0, "row": 1}, bounds, {}, [])
	if str(graph.get("axis", "")) != "col":
		return _fail("wide board did not report the col long axis: %s" % str(graph.get("axis", "")))
	if int(graph.get("far_end", -1)) != 5:
		return _fail("wide board far_end should be w-1 = 5, got %s" % str(graph.get("far_end", -1)))
	return _pass()


## TALL board (h > w): the escape BAND is the last TWO rows (h-2 and h-1),
## returned in canonical ascending "col,row" order.
static func _t_far_end_tall_board() -> Dictionary:
	var bounds := {"w": 3, "h": 6}
	var cells: Array = EscapeService.escape_cells(bounds, {})
	var expected: Array = [
		{"col": 0, "row": 4}, {"col": 0, "row": 5},
		{"col": 1, "row": 4}, {"col": 1, "row": 5},
		{"col": 2, "row": 4}, {"col": 2, "row": 5},
	]
	if cells != expected:
		return _fail("tall escape band wrong: %s" % str(cells))
	var graph: Dictionary = EscapeService.escape_graph({"col": 1, "row": 0}, bounds, {}, [])
	if str(graph.get("axis", "")) != "row":
		return _fail("tall board did not report the row long axis: %s" % str(graph.get("axis", "")))
	if int(graph.get("far_end", -1)) != 5:
		return _fail("tall board far_end should be h-1 = 5, got %s" % str(graph.get("far_end", -1)))
	return _pass()


## SQUARE board (w == h) takes the SAME branch as a tall board (row far end),
## exactly as FlowRuntime's `if board_cols > board_rows ... else ...` does.
static func _t_far_end_square_board() -> Dictionary:
	var bounds := {"w": 4, "h": 4}
	var cells: Array = EscapeService.escape_cells(bounds, {})
	var expected: Array = [
		{"col": 0, "row": 2}, {"col": 0, "row": 3},
		{"col": 1, "row": 2}, {"col": 1, "row": 3},
		{"col": 2, "row": 2}, {"col": 2, "row": 3},
		{"col": 3, "row": 2}, {"col": 3, "row": 3},
	]
	if cells != expected:
		return _fail("square escape band wrong: %s" % str(cells))
	var graph: Dictionary = EscapeService.escape_graph({"col": 0, "row": 0}, bounds, {}, [])
	if str(graph.get("axis", "")) != "row":
		return _fail("square board must fall to the row axis, got %s" % str(graph.get("axis", "")))
	return _pass()


# ---------------------------------------------------------------------------
# is_escaped — must match FlowRuntime._resolve_next_actor's `>= max-1` rule
# ---------------------------------------------------------------------------

static func _t_is_escaped_boundary_matches_runtime() -> Dictionary:
	# WIDE 6x3: max_col = 5, escape when col >= max_col - 1 == 4.
	var wide := {"w": 6, "h": 3}
	var wide_cases: Array = [[3, false], [4, true], [5, true]]
	for case_value: Variant in wide_cases:
		var case: Array = case_value as Array
		var col: int = int(case[0])
		var want: bool = bool(case[1])
		var got: bool = EscapeService.is_escaped({"col": col, "row": 1}, wide, {})
		if got != want:
			return _fail("wide is_escaped(col=%d) expected %s got %s" % [col, str(want), str(got)])
	# A high ROW on a wide board must NOT escape — the col axis is authoritative.
	if EscapeService.is_escaped({"col": 0, "row": 2}, wide, {}):
		return _fail("wide board escaped on the short (row) axis")

	# TALL 3x6: max_row = 5, escape when row >= max_row - 1 == 4.
	var tall := {"w": 3, "h": 6}
	var tall_cases: Array = [[3, false], [4, true], [5, true]]
	for case_value2: Variant in tall_cases:
		var case2: Array = case_value2 as Array
		var row: int = int(case2[0])
		var want2: bool = bool(case2[1])
		var got2: bool = EscapeService.is_escaped({"col": 1, "row": row}, tall, {})
		if got2 != want2:
			return _fail("tall is_escaped(row=%d) expected %s got %s" % [row, str(want2), str(got2)])
	if EscapeService.is_escaped({"col": 2, "row": 0}, tall, {}):
		return _fail("tall board escaped on the short (col) axis")

	# SQUARE 4x4: falls to the row branch — max_row = 3, escape when row >= 2.
	var square := {"w": 4, "h": 4}
	if EscapeService.is_escaped({"col": 3, "row": 1}, square, {}):
		return _fail("square board escaped below the row threshold")
	if not EscapeService.is_escaped({"col": 0, "row": 2}, square, {}):
		return _fail("square board did not escape at the row max-1 line")
	if EscapeService.is_escaped({"col": 3, "row": 0}, square, {}):
		return _fail("square board escaped on the col axis instead of the row axis")
	return _pass()


static func _t_escape_cells_exclude_unwalkable() -> Dictionary:
	var bounds := {"w": 6, "h": 3}
	var walkable: Dictionary = _full_walkable(6, 3)
	walkable.erase("5,1")
	var cells: Array = EscapeService.escape_cells(bounds, walkable)
	var expected: Array = [
		{"col": 4, "row": 0}, {"col": 4, "row": 1}, {"col": 4, "row": 2},
		{"col": 5, "row": 0}, {"col": 5, "row": 2},
	]
	if cells != expected:
		return _fail("non-walkable band cell was not excluded: %s" % str(cells))
	return _pass()


## REGRESSION (the escape-line/escape-band disagreement).
##
## Wide 5x3 board -> band = columns 3 and 4. Make the ENTIRE far-end LINE (col 4)
## unwalkable. The quarry can still WIN by standing on col 3, which `is_escaped`
## accepts. While `escape_cells` targeted the far-end line alone it returned [],
## so `escape_graph` reported no reachable escape and `cutoff_cells` returned []
## — the pursuers were told there was nothing to cut off while the quarry was one
## step from victory. Deriving both from the band predicate fixes it.
static func _t_unwalkable_far_line_still_has_corridor() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var walkable: Dictionary = _full_walkable(5, 3)
	for row in range(3):
		walkable.erase("4,%d" % row)

	# The band still offers winning ground on col 3 alone.
	var cells: Array = EscapeService.escape_cells(bounds, walkable)
	var expected: Array = [{"col": 3, "row": 0}, {"col": 3, "row": 1}, {"col": 3, "row": 2}]
	if cells != expected:
		return _fail("band collapsed when the far-end line went solid: %s" % str(cells))
	# Sanity: every one of those cells genuinely wins.
	for cell_value: Variant in cells:
		if not EscapeService.is_escaped(cell_value as Dictionary, bounds, walkable):
			return _fail("escape cell %s does not satisfy is_escaped" % str(cell_value))

	var graph: Dictionary = EscapeService.escape_graph({"col": 0, "row": 1}, bounds, walkable, [])
	if not bool(graph.get("reachable", false)):
		return _fail("graph unreachable despite a walkable band: %s" % str(graph))
	if (graph["escape_cells"] as Array).is_empty():
		return _fail("graph reported no reachable escape cells on a winnable band")

	# THE POINT: a corridor still exists, so pursuers still have ground to hold.
	var cutoff: Array = EscapeService.cutoff_cells({"col": 0, "row": 1}, bounds, walkable, [], [])
	if cutoff.is_empty():
		return _fail("solid far-end line produced an EMPTY corridor while the quarry can still win")
	for cell_value2: Variant in cutoff:
		var cell: Dictionary = cell_value2 as Dictionary
		if int(cell["col"]) == 4:
			return _fail("corridor targeted the solid far-end line: %s" % str(cutoff))
	return _pass()


## The targeted set and the win predicate are ONE predicate: over every cell of
## several board shapes, `escape_cells` membership must be exactly
## "is_escaped AND walkable" — never a different band, never a subset of it.
static func _t_targeted_set_agrees_with_is_escaped() -> Dictionary:
	var boards: Array = [
		{"w": 6, "h": 3}, {"w": 3, "h": 6}, {"w": 4, "h": 4}, {"w": 5, "h": 3},
	]
	for bounds_value: Variant in boards:
		var bounds: Dictionary = bounds_value as Dictionary
		var w: int = int(bounds["w"])
		var h: int = int(bounds["h"])
		var walkable: Dictionary = _full_walkable(w, h)
		# Punch a hole so the walkability filter is genuinely exercised.
		walkable.erase("%d,%d" % [w - 1, 0])
		var targeted: Array = _keys(EscapeService.escape_cells(bounds, walkable))
		var predicted: Array = []
		for col in range(w):
			for row in range(h):
				var cell := {"col": col, "row": row}
				if not EscapeService.is_escaped(cell, bounds, walkable):
					continue
				if not bool(walkable.get("%d,%d" % [col, row], false)):
					continue
				predicted.append("%d,%d" % [col, row])
		predicted.sort()
		if targeted != predicted:
			return _fail("board %s: targeted set %s != is_escaped-walkable set %s" % [
				str(bounds), str(targeted), str(predicted)])
		if targeted.is_empty():
			return _fail("board %s produced an empty targeted set" % str(bounds))
	return _pass()


# ---------------------------------------------------------------------------
# escape_graph — blockers + two-solid-corner diagonal legality
# ---------------------------------------------------------------------------

## A full blocker wall severs the quarry from the far-end line: the region still
## builds, but no escape cell is reachable.
static func _t_graph_respects_blockers() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var blockers: Array = [
		{"col": 2, "row": 0}, {"col": 2, "row": 1}, {"col": 2, "row": 2},
	]
	var graph: Dictionary = EscapeService.escape_graph(
		{"col": 0, "row": 1}, bounds, _full_walkable(5, 3), blockers
	)
	if not bool(graph.get("reachable", false)):
		return _fail("walled board should still build a region: %s" % str(graph))
	var costs: Dictionary = graph["costs"]
	if not costs.has("1,0"):
		return _fail("near-side cell missing from the escape graph")
	if costs.has("3,1") or costs.has("4,1"):
		return _fail("escape graph leaked through a solid blocker wall")
	if not (graph["escape_cells"] as Array).is_empty():
		return _fail("severed board reported reachable escape cells: %s" % str(graph["escape_cells"]))
	# Nothing to intercept when the quarry cannot reach the line at all.
	var cutoff: Array = EscapeService.cutoff_cells({"col": 0, "row": 1}, bounds, _full_walkable(5, 3), [], blockers)
	if not cutoff.is_empty():
		return _fail("severed board produced cutoff cells: %s" % str(cutoff))
	return _pass()


## StageTerrain.is_legal_edge: a diagonal may pass ONE solid orthogonal side but
## not TWO. The escape graph must inherit that rule through MovementPathService.
static func _t_graph_respects_diagonal_legality() -> Dictionary:
	var bounds := {"w": 3, "h": 3}
	var origin := {"col": 0, "row": 0}

	# TWO solid corners around the {0,0} -> {1,1} diagonal: the quarry is sealed in.
	var sealed: Dictionary = EscapeService.escape_graph(
		origin, bounds, _full_walkable(3, 3), [{"col": 1, "row": 0}, {"col": 0, "row": 1}]
	)
	if not bool(sealed.get("reachable", false)):
		return _fail("sealed origin should still build a region: %s" % str(sealed))
	var sealed_costs: Dictionary = sealed["costs"]
	if sealed_costs.has("1,1"):
		return _fail("diagonal crossed TWO solid corners")
	if sealed_costs.size() != 1:
		return _fail("sealed quarry region should hold only its own cell: %s" % str(sealed_costs))
	if not (sealed["escape_cells"] as Array).is_empty():
		return _fail("sealed quarry reported reachable escape cells")

	# Only ONE solid corner: the same diagonal is legal.
	var open_graph: Dictionary = EscapeService.escape_graph(
		origin, bounds, _full_walkable(3, 3), [{"col": 1, "row": 0}]
	)
	var open_costs: Dictionary = open_graph["costs"]
	if not open_costs.has("1,1"):
		return _fail("diagonal past ONE solid corner was wrongly rejected")
	if (open_graph["escape_cells"] as Array).is_empty():
		return _fail("open board should reach the far-end line")
	return _pass()


# ---------------------------------------------------------------------------
# cutoff_cells — escape-graph projection
# ---------------------------------------------------------------------------

## GOLDEN full-array assertion. Fully open 3x3 (square -> row band = rows 1 and 2).
## The quarry at (1,0) WINS the moment it reaches row 1, so the whole corridor is
## row 1 — row 2 is one step beyond anything it needs. Output is ordered by quarry
## cost then (col,row).
static func _t_cutoff_exact_order_open_board() -> Dictionary:
	var bounds := {"w": 3, "h": 3}
	var cutoff: Array = EscapeService.cutoff_cells({"col": 1, "row": 0}, bounds, {}, [], [])
	var expected: Array = [
		{"col": 0, "row": 1}, {"col": 1, "row": 1}, {"col": 2, "row": 1},
	]
	if cutoff != expected:
		return _fail("open-board cutoff projection/order wrong: %s" % str(cutoff))
	# Every corridor cell must itself already satisfy the win predicate here — the
	# band IS the first row the quarry reaches.
	for cell_value: Variant in cutoff:
		if not EscapeService.is_escaped(cell_value as Dictionary, bounds, {}):
			return _fail("corridor cell %s is outside the winning band" % str(cell_value))
	return _pass()


## Chokepoint board: a wall at col 2 with a single gap at {2,0}.
## Projection from the escape GRAPH must surface the far-from-edge chokepoint and
## must NOT surface off-route cells that merely sit next to the escape line —
## which is exactly what a geometric nearest-edge rule would have returned.
static func _t_cutoff_projected_not_nearest_edge() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var blockers: Array = [{"col": 2, "row": 1}, {"col": 2, "row": 2}]
	var cutoff: Array = EscapeService.cutoff_cells(
		{"col": 0, "row": 1}, bounds, _full_walkable(5, 3), [], blockers
	)
	var keys: Array = _keys(cutoff)

	# The chokepoint is two columns away from the escape line, yet it is the single
	# most valuable interception cell — nearest-edge targeting would never yield it.
	if not keys.has("2,0"):
		return _fail("projection missed the chokepoint {2,0}: %s" % str(keys))
	# {3,2} is ADJACENT to the escape line but lies on no shortest route.
	if keys.has("3,2"):
		return _fail("projection included off-route edge-adjacent {3,2} (nearest-edge behavior): %s" % str(keys))
	# Cells behind the wall on the dead-end side are likewise off-route.
	if keys.has("1,2") or keys.has("0,2"):
		return _fail("projection included dead-end cells: %s" % str(keys))
	# The quarry never cuts itself off.
	if keys.has("0,1"):
		return _fail("projection included the quarry's own cell")
	# Every returned cell must be inside the escape graph's cost region.
	var graph: Dictionary = EscapeService.escape_graph(
		{"col": 0, "row": 1}, bounds, _full_walkable(5, 3), blockers
	)
	var costs: Dictionary = graph["costs"]
	for key_value: Variant in keys:
		if not costs.has(str(key_value)):
			return _fail("cutoff cell %s is outside the escape graph" % str(key_value))
	# Ordering contract: quarry cost never decreases across the returned array.
	var previous: int = -1
	for cell_value: Variant in cutoff:
		var cell: Dictionary = cell_value as Dictionary
		var cost: int = int(costs["%d,%d" % [int(cell["col"]), int(cell["row"])]])
		if cost < previous:
			return _fail("cutoff cells were not ordered by ascending quarry cost: %s" % str(cutoff))
		previous = cost
	return _pass()


## Pursuers restrict the corridor to cells they can actually reach in time
## (pursuer cost <= quarry cost). The result stays a subset of the open corridor.
static func _t_cutoff_pursuer_reach_filter() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var blockers: Array = [{"col": 2, "row": 1}, {"col": 2, "row": 2}]
	var quarry := {"col": 0, "row": 1}
	var unfiltered: Array = EscapeService.cutoff_cells(
		quarry, bounds, _full_walkable(5, 3), [], blockers
	)
	var filtered: Array = EscapeService.cutoff_cells(
		quarry, bounds, _full_walkable(5, 3), [{"col": 3, "row": 2}], blockers
	)
	var unfiltered_keys: Array = _keys(unfiltered)
	var filtered_keys: Array = _keys(filtered)
	if filtered.is_empty():
		return _fail("a well-placed pursuer produced no interception cells")
	for key_value: Variant in filtered_keys:
		if not unfiltered_keys.has(str(key_value)):
			return _fail("pursuer filter invented cell %s outside the corridor" % str(key_value))
	# The far side of the board is 1 step from the pursuer but 3+ from it via the
	# gap, while the quarry is adjacent — the pursuer cannot beat it there.
	if filtered_keys.has("1,0") or filtered_keys.has("1,1"):
		return _fail("pursuer filter kept cells it cannot reach in time: %s" % str(filtered_keys))
	# It CAN however reach the chokepoint and the escape line no later than the quarry.
	if not filtered_keys.has("2,0"):
		return _fail("pursuer filter dropped the reachable chokepoint: %s" % str(filtered_keys))
	# A pursuer sealed off behind the wall's dead end intercepts nothing on the route.
	var far_pursuer: Array = EscapeService.cutoff_cells(
		quarry, bounds, _full_walkable(5, 3), [{"col": 0, "row": 2}], blockers
	)
	for key_value2: Variant in _keys(far_pursuer):
		if not unfiltered_keys.has(str(key_value2)):
			return _fail("trailing pursuer produced an off-corridor cell")
	return _pass()


static func _t_cutoff_unreachable_escape_empty() -> Dictionary:
	# Invalid bounds must degrade deterministically rather than throw.
	if not EscapeService.escape_cells({}, {}).is_empty():
		return _fail("missing bounds produced escape cells")
	if EscapeService.is_escaped({"col": 0, "row": 0}, {"w": 0, "h": 0}, {}):
		return _fail("non-positive bounds reported an escape")
	var graph: Dictionary = EscapeService.escape_graph({"col": 0, "row": 0}, {}, {}, [])
	if bool(graph.get("reachable", true)):
		return _fail("missing bounds produced a reachable escape graph")
	if str(graph.get("reason", "")) != "invalid_bounds":
		return _fail("missing bounds reason was not stable: %s" % str(graph.get("reason", "")))
	if not EscapeService.cutoff_cells({"col": 0, "row": 0}, {}, {}, [], []).is_empty():
		return _fail("missing bounds produced cutoff cells")
	return _pass()


## Mirroring the board across the SHORT axis must mirror the interception set
## exactly. Any row/col-order bias in the projection would break this.
static func _t_mirrored_board_no_row_col_bias() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var walkable: Dictionary = _full_walkable(5, 3)

	# Original: wall at col 2 with the gap at row 0.
	var blockers: Array = [{"col": 2, "row": 1}, {"col": 2, "row": 2}]
	var original: Array = EscapeService.cutoff_cells(
		{"col": 0, "row": 1}, bounds, walkable, [], blockers
	)
	# Mirrored (row -> h-1-row): wall at col 2 with the gap at row 2.
	var mirrored_blockers: Array = [{"col": 2, "row": 1}, {"col": 2, "row": 0}]
	var mirrored: Array = EscapeService.cutoff_cells(
		{"col": 0, "row": 1}, bounds, walkable, [], mirrored_blockers
	)

	if original.size() != mirrored.size():
		return _fail("mirrored board changed the interception count: %d vs %d" % [original.size(), mirrored.size()])
	var expected_keys: Array = _keys(_mirror_cells(original, 3))
	var mirrored_keys: Array = _keys(mirrored)
	if expected_keys != mirrored_keys:
		return _fail("mirrored interception set is not the mirror image: %s vs %s" % [str(expected_keys), str(mirrored_keys)])
	if original.is_empty():
		return _fail("mirror case degenerated to an empty projection")
	return _pass()


## Same inputs -> byte-identical outputs, and no input is mutated.
static func _t_deterministic_replay_and_purity() -> Dictionary:
	var bounds := {"w": 5, "h": 3}
	var quarry := {"col": 0, "row": 1}
	var walkable: Dictionary = _full_walkable(5, 3)
	var blockers: Array = [{"col": 2, "row": 1}, {"col": 2, "row": 2}]
	var pursuers: Array = [{"col": 3, "row": 2}]
	var walkable_before: Dictionary = walkable.duplicate(true)
	var blockers_before: Array = blockers.duplicate(true)
	var pursuers_before: Array = pursuers.duplicate(true)
	var quarry_before: Dictionary = quarry.duplicate(true)

	for pass_index in range(3):
		if EscapeService.escape_cells(bounds, walkable) != EscapeService.escape_cells(bounds, walkable):
			return _fail("escape_cells was not reproducible on pass %d" % pass_index)
		var graph_a: Dictionary = EscapeService.escape_graph(quarry, bounds, walkable, blockers)
		var graph_b: Dictionary = EscapeService.escape_graph(quarry, bounds, walkable, blockers)
		if graph_a != graph_b:
			return _fail("escape_graph was not reproducible on pass %d" % pass_index)
		var cutoff_a: Array = EscapeService.cutoff_cells(quarry, bounds, walkable, pursuers, blockers)
		var cutoff_b: Array = EscapeService.cutoff_cells(quarry, bounds, walkable, pursuers, blockers)
		if cutoff_a != cutoff_b:
			return _fail("cutoff_cells was not reproducible on pass %d" % pass_index)

	if walkable != walkable_before:
		return _fail("walkable input was mutated")
	if blockers != blockers_before:
		return _fail("blockers input was mutated")
	if pursuers != pursuers_before:
		return _fail("pursuers input was mutated")
	if quarry != quarry_before:
		return _fail("quarry cell input was mutated")
	return _pass()


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

## Explicit full-rectangle walkable set (never the empty legacy sentinel), so
## blocker removal is observable.
static func _full_walkable(w: int, h: int) -> Dictionary:
	var cells: Dictionary = {}
	for col in range(w):
		for row in range(h):
			cells["%d,%d" % [col, row]] = true
	return cells


static func _keys(cells: Array) -> Array:
	var keys: Array = []
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value as Dictionary
		keys.append("%d,%d" % [int(cell["col"]), int(cell["row"])])
	keys.sort()
	return keys


static func _mirror_cells(cells: Array, height: int) -> Array:
	var mirrored: Array = []
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value as Dictionary
		mirrored.append({"col": int(cell["col"]), "row": height - 1 - int(cell["row"])})
	return mirrored


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
