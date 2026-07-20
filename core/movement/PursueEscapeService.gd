class_name PursueEscapeService
extends RefCounted

## V2-COMBAT-002 Slice 4, Unit A — PURSUE escape authority (PURE, DORMANT).
##
## Consolidates today's four inconsistent inline quarry-escape computations into a
## single shared, deterministic authority. This service is DORMANT: nothing live
## wires it yet. Only tests (and later slice-4 units / the slice-6 cutover) consume
## it. No RNG, no OS time, no mutation of any input, no live actor/combat_state.
##
## ---------------------------------------------------------------------------
## CANONICAL DICT SHAPES (frozen for the whole PURSUE helper family)
## ---------------------------------------------------------------------------
##   cell     : { "col": int, "row": int }
##   bounds   : { "w": int, "h": int }   — matches the movement domain
##              (MovementContext / MovementPathService / StageTerrain). NOTE the
##              live FlowRuntime authority expresses the same board as
##              board_cols/board_rows; the mapping is board_cols == w,
##              board_rows == h.
##   walkable : Dictionary set keyed by "col,row" -> true. An EMPTY dict is the
##              legacy all-walkable sentinel (every in-bounds cell is walkable),
##              exactly as StageTerrain.is_walkable defines it.
##   blockers : Array of cell dicts the quarry may NOT traverse (static obstacles).
##   pursuers : Array of cell dicts — pursuer positions evaluated as interceptors.
##
## ---------------------------------------------------------------------------
## LONG-AXIS ESCAPE BAND — ONE PREDICATE, SHARED BY EVERY ENTRY POINT
## ---------------------------------------------------------------------------
## Replicates FlowRuntime._resolve_next_actor (slices-1-3 build, ~lines 2077-2087):
##   max_col = board_cols - 1  (== w - 1)
##   max_row = board_rows - 1  (== h - 1)
##   if board_cols > board_rows (w > h):  # WIDE board
##       escaped = col >= max_col - 1      # col >= w - 2
##   else:                                 # TALL or SQUARE board
##       escaped = row >= max_row - 1      # row >= h - 2
##
## That `>= max-1` rule defines a two-line BAND at the far end of the long axis,
## NOT a single line:
##   wide        -> columns w-2 and w-1
##   tall/square -> rows    h-2 and h-1
##
## THE BAND IS THE SINGLE AUTHORITY. `_is_escape_geometry` is the one predicate;
## `is_escaped`, `escape_cells`, `escape_graph` and `cutoff_cells` all derive from
## it, so they can never disagree:
##   * `is_escaped`   — the predicate alone (pure geometry, no walkability gate,
##                      byte-for-byte FlowRuntime fidelity; that fidelity is what
##                      makes the slice-6 cutover behavior-preserving).
##   * `escape_cells` — the predicate PLUS in-bounds walkability, i.e. every cell
##                      the quarry could actually stand on to win.
## Earlier revisions targeted only the FAR-END LINE (col == w-1 / row == h-1)
## while winning on the band. That was a real defect, not a nuance: it anchored
## routes one step deeper than the quarry ever needs to travel, let a pursuer
## "arrive in time" against a line the quarry never visits, and returned an EMPTY
## corridor whenever the far-end line happened to be unwalkable even though the
## quarry could still win on the walkable band behind it. Both now agree.
##
## `is_escaped` keeps its geometry-only semantics on purpose: FlowRuntime does not
## gate escape on walkability, so neither does this helper (`walkable` is accepted
## for signature symmetry only). Every cell `escape_cells` returns therefore also
## satisfies `is_escaped` — the walkable set is a filter on the same band, never a
## different band.


## Every WALKABLE, in-bounds cell of the long-axis escape BAND, in canonical
## ascending "col,row" order.
static func escape_cells(bounds: Dictionary, walkable: Dictionary) -> Array:
	var dims: Dictionary = _dims(bounds)
	if not bool(dims["valid"]):
		return []
	var cells: Array = []
	for col in range(int(dims["w"])):
		for row in range(int(dims["h"])):
			var cell: Dictionary = {"col": col, "row": row}
			if not _is_escape_geometry(cell, dims):
				continue
			if _walkable_in_bounds(cell, walkable, bounds):
				cells.append(cell)
	return cells


## True when `cell` sits inside the escape band, matching FlowRuntime's `>= max-1`
## rule exactly. Pure geometry (walkable unused — see header).
static func is_escaped(cell: Dictionary, bounds: Dictionary, _walkable: Dictionary) -> bool:
	var dims: Dictionary = _dims(bounds)
	if not bool(dims["valid"]):
		return false
	return _is_escape_geometry(cell, dims)


## THE escape predicate. Everything public in this file routes through it.
static func _is_escape_geometry(cell: Dictionary, dims: Dictionary) -> bool:
	var w: int = int(dims["w"])
	var h: int = int(dims["h"])
	if w > h:
		return int(cell.get("col", 0)) >= (w - 1) - 1
	return int(cell.get("row", 0)) >= (h - 1) - 1


## The quarry's traversable region oriented toward escape.
##
## Reuses MovementPathService.reachable_cost_region over `walkable` minus
## `blockers`, honoring StageTerrain.is_legal_edge (two-solid-corner diagonal
## rule) via that primitive. Uniform step cost (no terrain/edge costs) keeps the
## region symmetric, which the cutoff projection relies on.
##
## Returns a deterministic dict:
##   {
##     "reachable":    bool,
##     "axis":         "col" | "row",         # long-axis escape direction
##     "far_end":      int,                    # w-1 (wide) or h-1 (tall/square)
##     "band_start":   int,                    # far_end - 1: first line that WINS
##     "costs":        { "col,row": int },     # min traversal cost from the quarry
##     "escape_cells": Array,                  # reachable walkable BAND cells (sorted)
##     "reason":       String,
##   }
## `far_end` is retained as the extreme index; `band_start` is the line the quarry
## actually has to reach. Targeting uses the whole band (see header).
static func escape_graph(
	quarry_cell: Dictionary,
	bounds: Dictionary,
	walkable: Dictionary,
	blockers: Array = []
) -> Dictionary:
	var dims: Dictionary = _dims(bounds)
	var axis: String = "row"
	var far_end: int = 0
	if bool(dims["valid"]):
		var w: int = int(dims["w"])
		var h: int = int(dims["h"])
		axis = "col" if w > h else "row"
		far_end = (w - 1) if w > h else (h - 1)
	if not bool(dims["valid"]):
		return _graph_failure(axis, far_end, "invalid_bounds")

	var eff_walkable: Dictionary = _effective_walkable(walkable, blockers, bounds)
	var capacity: int = int(dims["w"]) * int(dims["h"])
	var region: Dictionary = MovementPathService.reachable_cost_region(
		quarry_cell, capacity, eff_walkable, {}, bounds, {}
	)
	if not bool(region.get("reachable", false)):
		return _graph_failure(axis, far_end, str(region.get("reason", "unreachable")))

	var costs: Dictionary = region["costs"]
	var reachable_escape: Array = []
	for ec_value: Variant in escape_cells(bounds, eff_walkable):
		var ec: Dictionary = ec_value if ec_value is Dictionary else {}
		if costs.has(_cell_key(ec)):
			reachable_escape.append(ec)
	return {
		"reachable": true,
		"axis": axis,
		"far_end": far_end,
		"band_start": far_end - 1,
		"costs": costs,
		"escape_cells": reachable_escape,
		"reason": "escape_graph_built",
	}


## Interception cells PROJECTED from the quarry's escape graph.
##
## Projection method (deterministic, no nearest-edge geometry):
##   1. Build escape_graph(quarry, bounds, walkable, blockers) → costs_q and the
##      set of reachable escape-BAND cells (the same band `is_escaped` wins on —
##      never the far-end line alone). Pursuers are NOT walls for the quarry's
##      routes; only `blockers` block. If no escape cell is reachable, there is
##      nothing to cut off → return [].
##   2. min_escape_cost = min over reachable escape cells of costs_q[escape].
##   3. Build costs_e: the multi-source distance field FROM every reachable escape
##      cell (uniform cost ⇒ symmetric ⇒ costs_e[c] == dist(c → nearest escape)).
##   4. Route corridor = every cell c with
##         costs_q[c] + costs_e[c] == min_escape_cost
##      i.e. c lies on SOME shortest quarry→escape-band route (captures the whole
##      corridor, not one tie-broken path). The quarry's own cell is excluded (it
##      cannot cut itself off); reachable escape cells stay in (intercepting at the
##      line is valid).
##   5. Pursuer filter:
##        - pursuers empty → return the full corridor (candidate cells any pursuer
##          would target).
##        - pursuers non-empty → keep corridor cell c iff SOME pursuer can reach c
##          with pursuer_cost <= costs_q[c] (arrives no later than the quarry, so it
##          can actually intercept). Each pursuer's reach is computed independently
##          over `walkable` minus `blockers` (pursuers do not block one another).
##   6. Deterministic order: quarry cost ascending (progress along the escape),
##      then canonical "col,row". Membership is mirror-covariant (region/distance
##      based, no row/col directional bias), so a mirrored board yields the mirror
##      set.
static func cutoff_cells(
	quarry_cell: Dictionary,
	bounds: Dictionary,
	walkable: Dictionary,
	pursuers: Array = [],
	blockers: Array = []
) -> Array:
	var graph: Dictionary = escape_graph(quarry_cell, bounds, walkable, blockers)
	if not bool(graph.get("reachable", false)):
		return []
	var escapes: Array = graph["escape_cells"]
	if escapes.is_empty():
		return []

	var costs_q: Dictionary = graph["costs"]
	var eff_walkable: Dictionary = _effective_walkable(walkable, blockers, bounds)
	var dims: Dictionary = _dims(bounds)
	var capacity: int = int(dims["w"]) * int(dims["h"])

	# min quarry-cost to reach the escape band.
	var min_escape_cost: int = -1
	for ec_value: Variant in escapes:
		var ec: Dictionary = ec_value if ec_value is Dictionary else {}
		var ck: String = _cell_key(ec)
		if costs_q.has(ck):
			var c: int = int(costs_q[ck])
			if min_escape_cost < 0 or c < min_escape_cost:
				min_escape_cost = c
	if min_escape_cost < 0:
		return []

	# costs_e: multi-source distance field from every reachable escape cell.
	var costs_e: Dictionary = {}
	for ec_value2: Variant in escapes:
		var ec2: Dictionary = ec_value2 if ec_value2 is Dictionary else {}
		var region: Dictionary = MovementPathService.reachable_cost_region(
			ec2, capacity, eff_walkable, {}, bounds, {}
		)
		if not bool(region.get("reachable", false)):
			continue
		var r_costs: Dictionary = region["costs"]
		for key_value: Variant in r_costs:
			var key: String = str(key_value)
			var d: int = int(r_costs[key])
			if not costs_e.has(key) or d < int(costs_e[key]):
				costs_e[key] = d

	var quarry_key: String = _cell_key(quarry_cell)

	# Route corridor: cells on some shortest quarry→escape-band route.
	var corridor: Array = []
	for key_value2: Variant in costs_q:
		var key2: String = str(key_value2)
		if key2 == quarry_key:
			continue
		if not costs_e.has(key2):
			continue
		if int(costs_q[key2]) + int(costs_e[key2]) == min_escape_cost:
			corridor.append(key2)

	# Optional pursuer reachability filter.
	var kept_keys: Array = corridor
	if not pursuers.is_empty():
		var pursuer_regions: Array = []
		for p_value: Variant in pursuers:
			var p_cell: Dictionary = p_value if p_value is Dictionary else {}
			var p_region: Dictionary = MovementPathService.reachable_cost_region(
				p_cell, capacity, eff_walkable, {}, bounds, {}
			)
			if bool(p_region.get("reachable", false)):
				pursuer_regions.append(p_region["costs"])
		kept_keys = []
		for key_value3: Variant in corridor:
			var key3: String = str(key_value3)
			var quarry_cost: int = int(costs_q[key3])
			var intercepted: bool = false
			for pr_value: Variant in pursuer_regions:
				var pr: Dictionary = pr_value if pr_value is Dictionary else {}
				if pr.has(key3) and int(pr[key3]) <= quarry_cost:
					intercepted = true
					break
			if intercepted:
				kept_keys.append(key3)

	# Deterministic sort: quarry cost ascending, then canonical (col,row).
	kept_keys.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = int(costs_q[a])
		var cb: int = int(costs_q[b])
		if ca != cb:
			return ca < cb
		return _key_less(a, b)
	)

	var result: Array = []
	for key_value4: Variant in kept_keys:
		result.append(_cell_from_key(str(key_value4)))
	return result


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

## Validate + extract board dimensions from a { "w", "h" } bounds dict.
static func _dims(bounds: Dictionary) -> Dictionary:
	if not bounds.has("w") or not bounds.has("h"):
		return {"valid": false, "w": 0, "h": 0}
	var w: int = int(bounds["w"])
	var h: int = int(bounds["h"])
	if w <= 0 or h <= 0:
		return {"valid": false, "w": 0, "h": 0}
	return {"valid": true, "w": w, "h": h}


## In-bounds walkability, honoring the empty-set legacy all-walkable sentinel.
static func _walkable_in_bounds(
	cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary
) -> bool:
	var dims: Dictionary = _dims(bounds)
	if bool(dims["valid"]):
		var col: int = int(cell.get("col", 0))
		var row: int = int(cell.get("row", 0))
		if col < 0 or row < 0 or col >= int(dims["w"]) or row >= int(dims["h"]):
			return false
	return StageTerrain.is_walkable(cell, walkable)


## Concrete walkable set with `blockers` removed. When `blockers` is empty the
## input is returned unchanged (preserving the empty legacy sentinel). When
## blockers exist over an empty sentinel, the full in-bounds rectangle is
## materialized first so specific cells can be removed — reachability is identical
## to the sentinel minus those cells.
static func _effective_walkable(
	walkable: Dictionary,
	blockers: Array,
	bounds: Dictionary
) -> Dictionary:
	if blockers.is_empty():
		return walkable
	var base: Dictionary = {}
	if walkable.is_empty():
		var dims: Dictionary = _dims(bounds)
		if bool(dims["valid"]):
			for col in range(int(dims["w"])):
				for row in range(int(dims["h"])):
					base["%d,%d" % [col, row]] = true
	else:
		base = walkable.duplicate(true)
	for b_value: Variant in blockers:
		var b_cell: Dictionary = b_value if b_value is Dictionary else {}
		if b_cell.has("col") and b_cell.has("row"):
			base.erase("%d,%d" % [int(b_cell["col"]), int(b_cell["row"])])
	return base


static func _cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


static func _cell_from_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	return {"col": int(parts[0]), "row": int(parts[1])}


## Canonical (col, row) ordering on "col,row" keys — numeric, never lexical.
static func _key_less(left: String, right: String) -> bool:
	var lp: PackedStringArray = left.split(",")
	var rp: PackedStringArray = right.split(",")
	var lc: int = int(lp[0])
	var rc: int = int(rp[0])
	if lc != rc:
		return lc < rc
	return int(lp[1]) < int(rp[1])


static func _graph_failure(axis: String, far_end: int, reason: String) -> Dictionary:
	return {
		"reachable": false,
		"axis": axis,
		"far_end": far_end,
		"band_start": far_end - 1,
		"costs": {},
		"escape_cells": [],
		"reason": reason,
	}
