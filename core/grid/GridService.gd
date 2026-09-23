# res://core/grid/GridService.gd
# Pure static service for grid configuration and spatial helpers.
# GRID-001: Board configuration — board_cols and board_rows owned here.
#
# Rules:
# - No RNG, no OS time in config/math methods. All are pure and deterministic.
# - Board config is immutable mid-combat; read from balance.json data.grid block.
# - GridService is the single source of truth for all grid math.
# - Caller logs LOG_COMBAT_INIT with the dimensions returned here.
#
# Future stories extend this file:
#   GRID-002 — assign_grid_pos(), spawn positions
#   GRID-003 — place_actors() with seeded RNG              ← implemented here
#   GRID-004 — manhattan_distance()              ← implemented here
#
# V2-STAGE-004 walkable terrain (combat board):
#   board_cfg["walkable"] — optional Dictionary of "col,row" keys (StageTerrain.walkable_set output).
#   Empty / absent key ⇒ LEGACY all-walkable sentinel (byte-identical behaviour, no code change).
#   Non-empty ⇒ terrain-aware placement and movement via StageTerrain helpers.
#
# RNG handling for place_actors (walkable branch):
#   The placement RNG is NOT reused after place_actors returns (verified: FlowEncounterState
#   creates a local rng, calls place_actors, then discards it). Therefore, when walkable is
#   non-empty, _pack_faction is NOT called — the walkable branch performs a direct, purely
#   deterministic assignment from sorted walkable cells with NO RNG draws. This is simpler
#   and correct; no parity guarantee is needed because there is no downstream RNG consumer.

class_name GridService
extends RefCounted


# -------------------------
# Board configuration
# -------------------------

## Returns the number of columns on the combat board.
## Reads from balance.json data.grid.board_cols; falls back to 10.
static func get_board_cols(cfg: Dictionary = {}) -> int:
	return int(cfg.get("board_cols", 10))


## Returns the number of rows on the combat board.
## Reads from balance.json data.grid.board_rows; falls back to 10.
static func get_board_rows(cfg: Dictionary = {}) -> int:
	return int(cfg.get("board_rows", 10))


## Returns the full board config dict { board_cols, board_rows }.
## Convenience wrapper — callers can pass this to snapshot builders.
static func get_board_config(cfg: Dictionary = {}) -> Dictionary:
	return {
		"board_cols": get_board_cols(cfg),
		"board_rows": get_board_rows(cfg),
	}


## Returns true if the given grid_pos { col, row } is inside the board bounds.
static func is_valid_pos(pos: Dictionary, cfg: Dictionary = {}) -> bool:
	var col: int = int(pos.get("col", -1))
	var row: int = int(pos.get("row", -1))
	return col >= 0 and col < get_board_cols(cfg) \
		and row >= 0 and row < get_board_rows(cfg)


# -------------------------
# Distance helpers (GRID-004)
# -------------------------

## Returns the Manhattan distance between two grid_pos dicts { col, row }.
## Pure integer function — no floats, no RNG, no side effects.
## distance(A, A) == 0; distance(adjacent cell) == 1.
static func manhattan_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("col", 0)) - int(b.get("col", 0))) \
		 + abs(int(a.get("row", 0)) - int(b.get("row", 0)))


## Returns the Chebyshev distance between two grid_pos dicts { col, row }.
## Chebyshev = max(|Δcol|, |Δrow|) — matches the true step cost for 8-directional movement.
## A diagonal neighbour is distance 1, same as an orthogonal neighbour.
## Use for all range checks and AI distance awareness.
static func chebyshev_distance(a: Dictionary, b: Dictionary) -> int:
	return max(abs(int(a.get("col", 0)) - int(b.get("col", 0))),
			   abs(int(a.get("row", 0)) - int(b.get("row", 0))))


## Returns true if two grid_pos dicts are adjacent (Chebyshev distance == 1).
## Covers all 8 neighbours: orthogonal (N/S/E/W) and diagonal (NE/NW/SE/SW).
## Use for melee range checks — do not substitute manhattan_distance == 1.
static func is_adjacent(a: Dictionary, b: Dictionary) -> bool:
	return chebyshev_distance(a, b) == 1


# -------------------------
# Actor spawn positions (GRID-002)
# -------------------------

## Assigns a grid position to an actor dict in-place; returns the actor.
## Overwrites any existing grid_pos (including the default placeholder {col:0,row:0}).
## Pure and deterministic — no side effects beyond setting actor["grid_pos"].
static func assign_grid_pos(actor: Dictionary, col: int, row: int) -> Dictionary:
	actor["grid_pos"] = { "col": col, "row": row }
	return actor


# -------------------------
# Single-cell spawn placement on a walkable set
# -------------------------
#
# The one routine that picks ONE cell for an actor spawned after place_actors() has already
# filled the board: the shrine, the RECOVER relic, the PROTECT entity, the PURSUE quarry, the
# GUIDE_SPIRIT spirit and the temporary ally. Callers build the occupancy set, collect the
# unoccupied walkable cells, choose a target column, then call place_on_terrain().
#
# WHY ref_row IS A PARAMETER AND NOT A CONSTANT. Five callers pass the board midpoint. PURSUE
# passes the PARTY CENTROID row, on purpose: the depth fraction scales COLUMNS only, so on a
# tall board the midpoint rule parked the quarry tens of rows away from a party spawning near
# the top, and a quarry escape is an immediate defeat. That fix is deliberately local to
# PURSUE. Do NOT collapse ref_row to a constant and do NOT propagate the centroid to the other
# five — either one moves every mode's spawn cell.
#
# WHY metric IS A PARAMETER. The five objective callers rank by column distance FIRST and use
# row distance only as a tie-break, because column is what the depth scale governs. The ally
# ranks by the summed (Manhattan) distance to the party centroid, which orders cells
# differently — a cell one column off can beat a cell in the exact column. Both orderings are
# in use today and neither can adopt the other without moving a spawn cell.

## Rank by |col - target_col| first, then |row - ref_row|, then col, then row.
const PLACE_METRIC_AXIS: int = 0
## Rank by |col - target_col| + |row - ref_row|, then col, then row.
const PLACE_METRIC_MANHATTAN: int = 1


## Builds the "col,row" occupancy set from any number of actor lists. Non-Dictionary entries
## and actors with no grid_pos are keyed at "-1,-1", which no walkable set contains.
static func occupied_cells(actor_lists: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for list_v in actor_lists:
		for actor_v in list_v:
			if actor_v is Dictionary:
				var gp: Dictionary = (actor_v as Dictionary).get("grid_pos", {})
				occupied[str(int(gp.get("col", -1))) + "," + str(int(gp.get("row", -1)))] = true
	return occupied


## Returns the walkable cells that nothing occupies, as [{ col, row }, ...] in walkable-set
## iteration order. place_on_terrain() imposes a total order on them, so this order is not
## load-bearing.
##
## `region_set` is THE CONNECTIVITY GUARD for every post-placement spawn (V2-COMBAT-003
## terrain commit 5, decision 22). Pass largest_walkable_region(walkable, bounds) and no
## candidate can lie on a cut-off region — an island included. An objective spawned on an
## island cannot be reached, and an unreachable shrine is an unwinnable battle.
## Empty (the default) restores the unfiltered behaviour and is the LEGACY shape: it exists
## for callers that have no bounds to hand, not as an option a spawn path may take.
static func collect_unoccupied_cells(walkable: Dictionary, occupied: Dictionary,
		region_set: Dictionary = {}) -> Array:
	var cells: Array = []
	for key in walkable:
		if not region_set.is_empty() and not region_set.has(key):
			continue
		if not occupied.has(key):
			var parts: Array = str(key).split(",")
			if parts.size() == 2:
				cells.append({ "col": int(parts[0]), "row": int(parts[1]) })
	return cells


## Returns { min_col, max_col } over the given cells. The sentinels 999999 / -1 survive an
## empty list, exactly as the six inline copies did.
static func candidate_column_range(cells: Array) -> Dictionary:
	var min_col: int = 999999
	var max_col: int = -1
	for cell_v in cells:
		var col: int = int((cell_v as Dictionary)["col"])
		if col < min_col: min_col = col
		if col > max_col: max_col = col
	return { "min_col": min_col, "max_col": max_col }


## Sorts candidates in place into the chosen total order and returns the best cell as
## { col, row }, or {} when there are none. The sort is in place so a caller that needs the
## ranked list afterwards (GUIDE_SPIRIT's escort destination) keeps its own reference to it.
## No RNG: (col, row) is unique per cell, so the order is total and fully deterministic.
##
## CLEARANCE (V2-COMBAT-003 terrain commit 5, decision 24). Pass
## `clearance_ctx = { "walkable": <set>, "occupied": <set> }` for a STATIC OBJECTIVE and the
## ranking gains two keys: a cell with all eight neighbours walkable and free outranks one
## without, ahead of everything else, and openness over the 5x5 neighbourhood breaks the
## distance tie that the bare (col,row) tie-break used to decide arbitrarily. Eight is a
## MINIMUM and not a target, so the depth intent still chooses among the cells that clear
## it; openness only decides where the old order was indifferent. Omit the context and the
## ranking is byte-identical to the pre-commit-5 one.
static func place_on_terrain(candidates: Array, target_col: float, ref_row: float,
		metric: int = PLACE_METRIC_AXIS, clearance_ctx: Dictionary = {}) -> Dictionary:
	var use_clearance: bool = not clearance_ctx.is_empty()
	if use_clearance:
		# Precomputed once per candidate: a comparator would recompute these O(n log n) times.
		var cw: Dictionary = clearance_ctx.get("walkable", {})
		var co: Dictionary = clearance_ctx.get("occupied", {})
		for cand_v in candidates:
			var cand: Dictionary = cand_v
			cand["_clear"] = 1 if has_clearance(int(cand["col"]), int(cand["row"]), cw, co) else 0
			cand["_open"] = openness(int(cand["col"]), int(cand["row"]), cw, co)
	if metric == PLACE_METRIC_MANHATTAN:
		candidates.sort_custom(func(a, b):
			if use_clearance and int(a["_clear"]) != int(b["_clear"]): return int(a["_clear"]) > int(b["_clear"])
			var da: float = abs(float(a["col"]) - target_col) + abs(float(a["row"]) - ref_row)
			var db: float = abs(float(b["col"]) - target_col) + abs(float(b["row"]) - ref_row)
			if da != db: return da < db
			if use_clearance and int(a["_open"]) != int(b["_open"]): return int(a["_open"]) > int(b["_open"])
			if a["col"] != b["col"]: return a["col"] < b["col"]
			return a["row"] < b["row"]
		)
	else:
		candidates.sort_custom(func(a, b):
			if use_clearance and int(a["_clear"]) != int(b["_clear"]): return int(a["_clear"]) > int(b["_clear"])
			var da: float = abs(float(a["col"]) - target_col)
			var db: float = abs(float(b["col"]) - target_col)
			if da != db: return da < db
			var dra: float = abs(float(a["row"]) - ref_row)
			var drb: float = abs(float(b["row"]) - ref_row)
			if dra != drb: return dra < drb
			if use_clearance and int(a["_open"]) != int(b["_open"]): return int(a["_open"]) > int(b["_open"])
			if a["col"] != b["col"]: return a["col"] < b["col"]
			return a["row"] < b["row"]
		)
	if candidates.is_empty():
		return {}
	return { "col": int(candidates[0]["col"]), "row": int(candidates[0]["row"]) }


## Decision 24: all EIGHT neighbouring tiles walkable AND free. The minimum a static
## objective needs, and the same test that decides whether a region can host one at all.
static func has_clearance(col: int, row: int, walkable: Dictionary, occupied: Dictionary) -> bool:
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var nk: String = "%d,%d" % [col + dc, row + dr]
			if not walkable.has(nk) or occupied.has(nk):
				return false
	return true


## How open a cell is: walkable, unoccupied cells in the 5x5 neighbourhood around it,
## excluding the cell itself. 0..24. Only ever a preference — see place_on_terrain.
static func openness(col: int, row: int, walkable: Dictionary, occupied: Dictionary) -> int:
	var n: int = 0
	for dc in range(-2, 3):
		for dr in range(-2, 3):
			if dc == 0 and dr == 0:
				continue
			var nk: String = "%d,%d" % [col + dc, row + dr]
			if walkable.has(nk) and not occupied.has(nk):
				n += 1
	return n


# -------------------------
# Deterministic placement (GRID-003)
# -------------------------

## Places echo_actors (left half) and enemy_actors (right half) on the board using
## seeded RNG. Mutates grid_pos on each actor in-place.
##
## Placement score = floor((agi + speed) / 2) + archetype_mod + calling_mod
##                   + trait_mod + vector_mod
## All modifiers read from place_cfg (balance.json data.grid.placement_modifiers).
## Unknown keys default to 0 — tables are open for extension without code changes.
##
## Sort order: ascending by score, tiebreak actor_id ascending.
## Actors with lower scores (supportive roles) are placed in back columns;
## higher scores (aggressive roles) advance to front columns.
##
## Rows within each column are shuffled via the injected RNG.
## The RNG must be freshly seeded by the caller to guarantee reproducibility.
##
## Returns a Dictionary of four booleans, all false on the legacy (no-walkable) path:
##   "echo_outside_region_fallback" / "enemy_outside_region_fallback" — true when that
##     faction had an actor land outside the board's largest connected region (V2-COMBAT-003
##     phase 2c/2c-region) because the region ran out of cells for it, even though the total
##     walkable set (across all regions) still had room.
##   "echo_walkable_exhausted_fallback" / "enemy_walkable_exhausted_fallback" — true when
##     that faction has more actors than the board has walkable cells in total. This is a
##     plain shortage, not a connectivity defect, and can fire with zero cut-off cells on
##     the board.
## Both flags for a faction can never be true at once (walkable-exhausted is the more severe,
## true root cause and takes priority — see _assign_walkable_faction). This should never
## happen in practice; the caller logs it as a live alarm.
static func place_actors(echo_actors: Array, enemy_actors: Array,
		board_cfg: Dictionary, rng: RandomNumberGenerator,
		place_cfg: Dictionary = {}) -> Dictionary:
	var cols: int = get_board_cols(board_cfg)
	var rows: int = get_board_rows(board_cfg)

	# Sort both arrays by placement score ascending (slowest/support → back).
	var sorted_echoes: Array = echo_actors.duplicate()
	var sorted_enemies: Array = enemy_actors.duplicate()

	sorted_echoes.sort_custom(func(a, b):
		var sa: int = _placement_score(a, place_cfg)
		var sb: int = _placement_score(b, place_cfg)
		if sa != sb: return sa < sb
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	sorted_enemies.sort_custom(func(a, b):
		var sa: int = _placement_score(a, place_cfg)
		var sb: int = _placement_score(b, place_cfg)
		if sa != sb: return sa < sb
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	# Read the optional walkable set. Empty / absent ⇒ LEGACY path (byte-identical).
	var walkable: Dictionary = board_cfg.get("walkable", {})

	if walkable.is_empty():
		# LEGACY path — unchanged. Echoes fill from col=1 inward; enemies from col=cols-2 inward.
		_pack_faction(sorted_echoes, 1, 1, rows, rng)
		_pack_faction(sorted_enemies, cols - 2, -1, rows, rng)
		return {
			"echo_outside_region_fallback": false,
			"enemy_outside_region_fallback": false,
			"echo_walkable_exhausted_fallback": false,
			"enemy_walkable_exhausted_fallback": false,
		}
	else:
		# WALKABLE TERRAIN path — direct deterministic assignment; NO RNG draws.
		# (The placement rng is not reused after this function returns, so no parity draw is needed.)
		#
		# Collect unique integer columns and build per-column cell lists (row-ascending).
		# Using integer sorts throughout for correct numeric ordering.
		var col_set: Dictionary = {}
		for k in walkable:
			var parts := (k as String).split(",")
			col_set[int(parts[0])] = true
		var sorted_cols: Array = col_set.keys()
		sorted_cols.sort()  # ascending int sort

		# Build per-column cell lists sorted by row ascending (integer sort).
		var cells_by_col: Dictionary = {}
		for k in walkable:
			var parts := (k as String).split(",")
			var c: int = int(parts[0])
			var r: int = int(parts[1])
			if not cells_by_col.has(c):
				cells_by_col[c] = []
			cells_by_col[c].append({ "col": c, "row": r })
		# Sort each column's cell list by row ascending for determinism.
		for c in cells_by_col:
			(cells_by_col[c] as Array).sort_custom(func(a, b): return int(a["row"]) < int(b["row"]))

		# V2-COMBAT-003 phase 2c: bounds for StageTerrain.legal_neighbors. StageTerrain uses
		# "w"/"h"; board_cfg uses "board_cols"/"board_rows" (already read above as cols/rows).
		var bounds: Dictionary = { "w": cols, "h": rows }

		# V2-COMBAT-003 phase 2c-region: compute the walkable set's connected regions ONCE
		# per call (not once per actor), using StageTerrain.legal_neighbors as the adjacency
		# rule — the same authority the movement layer uses. A cut-off GROUP of two or more
		# cells is invisible to a per-cell "has any legal neighbour" test (each cell in the
		# group has a legal neighbour — the other cells in the group), so the guard must
		# operate on regions, not cells. Both factions are restricted to the SAME largest
		# region: if the party and the enemies land in different regions the battle cannot
		# happen, which is worse than a single stranded actor.
		var region_set: Dictionary = largest_walkable_region(walkable, bounds)

		# Assign echoes: iterate columns left→right, filling actors in score-ascending order.
		var echo_cells: Array = []
		for c in sorted_cols:
			for cell in cells_by_col[c]:
				echo_cells.append(cell)
		var echo_result: Dictionary = _assign_walkable_faction(sorted_echoes, echo_cells, walkable, region_set)

		# Assign enemies: iterate columns right→left, filling actors in score-ascending order.
		var enemy_cols: Array = sorted_cols.duplicate()
		enemy_cols.reverse()  # descending col order
		var enemy_cells: Array = []
		for c in enemy_cols:
			# Within each column keep rows ascending for determinism.
			for cell in cells_by_col[c]:
				enemy_cells.append(cell)
		var enemy_result: Dictionary = _assign_walkable_faction(sorted_enemies, enemy_cells, walkable, region_set)

		return {
			"echo_outside_region_fallback": echo_result["outside_region"],
			"enemy_outside_region_fallback": enemy_result["outside_region"],
			"echo_walkable_exhausted_fallback": echo_result["walkable_exhausted"],
			"enemy_walkable_exhausted_fallback": enemy_result["walkable_exhausted"],
		}


## Assigns grid positions for one faction into a pre-ordered list of walkable cells.
## actors: sorted Array of actor dicts (score-ascending, id tiebreak).
## ordered_cells: walkable cells in the desired fill order for this faction.
## walkable: the full walkable set (used as the last-resort pool in pass 3).
## region_set: Dictionary of "col,row" keys — the board's largest connected region
##   (see largest_walkable_region), shared by both factions.
## Purely deterministic; no RNG.
##
## V2-COMBAT-003 phase 2c-region: a walkable cell can belong to a cut-off REGION of two or
## more cells — each cell in the region has a legal neighbour (another cell in the same
## region), so a per-cell "has any legal neighbour" test cannot see it. Passes 1 and 2
## restrict placement to region_set (the board's single largest connected region, shared
## by both factions) so an actor is never placed on ground disconnected from the main
## fight. Pass 3 has no such filter: if region_set runs out for this faction, an actor
## still needs a cell — placing it on any remaining walkable ground is bad, dropping it
## from the encounter is worse.
##
## Returns { "outside_region": bool, "walkable_exhausted": bool }:
##   outside_region — pass 3 ran because this faction has more actors than region_set has
##     cells, but the total walkable set (all regions) still has room. The extra actor(s)
##     land outside the main region via pass 3.
##   walkable_exhausted — pass 3 ran because this faction has more actors than the board
##     has walkable cells in total — a plain shortage, unrelated to connectivity, and it
##     can happen with zero cut-off cells on the board. Takes priority over outside_region
##     when both technically hold, since it is the more severe, true root cause.
static func _assign_walkable_faction(actors: Array, ordered_cells: Array, walkable: Dictionary,
		region_set: Dictionary = {}) -> Dictionary:
	if actors.is_empty():
		return { "outside_region": false, "walkable_exhausted": false }

	# Track assigned cells to prevent two actors sharing a cell.
	var assigned: Dictionary = {}

	# Pass 1: fill actors from ordered_cells in sequence, skipping any cell outside the
	# board's largest connected region.
	var cell_idx: int = 0
	var actor_idx: int = 0
	while actor_idx < actors.size() and cell_idx < ordered_cells.size():
		var cell: Dictionary = ordered_cells[cell_idx]
		var key: String = "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]
		cell_idx += 1
		if assigned.has(key):
			continue  # already taken (shouldn't happen with well-formed input, but guard it)
		if not region_set.has(key):
			continue  # outside the main region — would strand or split the fight; pass 3 only
		assign_grid_pos(actors[actor_idx], int(cell.get("col", 0)), int(cell.get("row", 0)))
		assigned[key] = true
		actor_idx += 1

	# Pass 2: if ordered_cells were exhausted before all actors placed, drain the remaining
	# region_set cells in sorted key order (col asc, row asc) as a deterministic fallback.
	if actor_idx < actors.size():
		var fallback_keys: Array = region_set.keys()
		fallback_keys.sort()
		for fk in fallback_keys:
			if actor_idx >= actors.size():
				break
			if assigned.has(fk):
				continue
			var parts := (fk as String).split(",")
			var fc: int = int(parts[0])
			var fr: int = int(parts[1])
			assign_grid_pos(actors[actor_idx], fc, fr)
			assigned[fk] = true
			actor_idx += 1

	# Pass 3: unfiltered fallback, drawn from the FULL walkable set (all regions), not just
	# region_set. The main region ran out for this faction. Placing an actor outside the
	# main region (or, in the worst case, on unreachable ground) is bad; dropping it from
	# the encounter is worse — so place it anyway. Should never fire in practice; the call
	# site (EncounterSetupService) logs this as a live alarm.
	var outside_region: bool = false
	var walkable_exhausted: bool = false
	if actor_idx < actors.size():
		# Distinguish the two causes BEFORE draining, using the counts as they stood after
		# passes 1/2 (region_set exhausted for this faction either way):
		#   walkable_exhausted — this faction needs more cells than the WHOLE walkable set
		#     has, board-wide. A plain shortage; can happen with zero cut-off cells.
		#   outside_region     — the main region alone was too small for this faction, but
		#     the full walkable set (other, smaller regions included) still has room.
		if actors.size() > walkable.size():
			walkable_exhausted = true
		else:
			outside_region = true
		var fallback_keys2: Array = walkable.keys()
		fallback_keys2.sort()
		for fk in fallback_keys2:
			if actor_idx >= actors.size():
				break
			if assigned.has(fk):
				continue
			var parts2 := (fk as String).split(",")
			var fc2: int = int(parts2[0])
			var fr2: int = int(parts2[1])
			assign_grid_pos(actors[actor_idx], fc2, fr2)
			assigned[fk] = true
			actor_idx += 1
	# If walkable itself is exhausted (more actors than walkable cells), the remaining actors
	# keep whatever grid_pos they had from the last assign_grid_pos call — this is a
	# degenerate edge case that cannot crash and will be caught by combat validation.

	return { "outside_region": outside_region, "walkable_exhausted": walkable_exhausted }


## THE ONE HOST-REGION AUTHORITY. Computes the connected regions of `walkable` using
## StageTerrain.legal_neighbors as the sole adjacency rule (the same authority the movement
## layer uses — deliberately NOT plain 8-direction adjacency, which cannot see a region cut
## off only by the diagonal edge rule), then returns the LARGEST region as a Dictionary of
## "col,row" keys for O(1) membership tests. Ties break deterministically: the region whose
## lowest cell, in numeric (col, row) order, sorts first wins. Computed ONCE per place_actors
## call — not once per actor.
##
## PUBLIC because RealmGenerator places situations against the same set. Two host rules on
## one board is a defect waiting to happen: GridService and RealmGenerator must never
## disagree about which region is the host, so there is exactly one implementation.
static func largest_walkable_region(walkable: Dictionary, bounds: Dictionary) -> Dictionary:
	var all_keys: Array = walkable.keys()
	all_keys.sort()  # deterministic traversal seed order

	var visited: Dictionary = {}
	var best_region: Array = []
	var best_min_key: String = ""

	for start_key in all_keys:
		if visited.has(start_key):
			continue

		# Flood-fill this region via StageTerrain.legal_neighbors (BFS/DFS order does not
		# matter — only membership is used).
		var region: Array = []
		var stack: Array = [start_key]
		visited[start_key] = true
		while not stack.is_empty():
			var k: String = stack.pop_back()
			region.append(k)
			var parts := (k as String).split(",")
			var cell: Dictionary = { "col": int(parts[0]), "row": int(parts[1]) }
			var neighbors: Array = StageTerrain.legal_neighbors(cell, walkable, bounds)
			for n in neighbors:
				var nk: String = "%d,%d" % [int(n.get("col", 0)), int(n.get("row", 0))]
				if not visited.has(nk):
					visited[nk] = true
					stack.append(nk)

		var region_min_key: String = _min_cell_key(region)
		if region.size() > best_region.size():
			best_region = region
			best_min_key = region_min_key
		elif region.size() == best_region.size() and region.size() > 0 \
				and _cell_key_less(region_min_key, best_min_key):
			best_region = region
			best_min_key = region_min_key

	var region_set: Dictionary = {}
	for k in best_region:
		region_set[k] = true
	return region_set


## Returns the numerically-lowest "col,row" key in `keys` (col ascending, then row
## ascending) — NOT a lexical string minimum, which would misorder multi-digit coordinates.
static func _min_cell_key(keys: Array) -> String:
	var best: String = ""
	var best_set: bool = false
	for k in keys:
		if not best_set or _cell_key_less(k, best):
			best = k
			best_set = true
	return best


## True if cell key `a` sorts before cell key `b` in numeric (col, row) order.
static func _cell_key_less(a: String, b: String) -> bool:
	var pa := (a as String).split(",")
	var pb := (b as String).split(",")
	var ac: int = int(pa[0])
	var ar: int = int(pa[1])
	var bc: int = int(pb[0])
	var br: int = int(pb[1])
	if ac != bc:
		return ac < bc
	return ar < br


## Assigns grid positions for one faction's actors into columns starting at start_col,
## stepping by col_step (+1 for echoes moving right, -1 for enemies moving left).
## Rows within each column are RNG-shuffled.
static func _pack_faction(actors: Array, start_col: int, col_step: int,
		board_rows: int, rng: RandomNumberGenerator) -> void:
	var col: int = start_col
	var col_start_idx: int = 0

	while col_start_idx < actors.size():
		# Build a shuffled row list for this column.
		var row_list: Array = []
		for r in range(board_rows):
			row_list.append(r)
		# Fisher-Yates shuffle using the seeded RNG.
		for i in range(row_list.size() - 1, 0, -1):
			var j: int = rng.randi() % (i + 1)
			var tmp = row_list[i]; row_list[i] = row_list[j]; row_list[j] = tmp

		# Assign as many actors as fit in this column's rows.
		var slot: int = 0
		while col_start_idx < actors.size() and slot < board_rows:
			assign_grid_pos(actors[col_start_idx], col, row_list[slot])
			col_start_idx += 1
			slot += 1

		col += col_step


## Computes the composite placement score for one actor.
## Higher score = placed further forward (closer to the opposing faction).
## All modifier lookups default to 0 for unknown keys — tables are freely extensible.
static func _placement_score(actor: Dictionary, place_cfg: Dictionary) -> int:
	# Base: average of agility stat and top-level speed.
	var agi: int  = int(actor.get("stats", {}).get("agi", 0))
	var spd: int  = int(actor.get("speed", 0))
	var base: int = int(floor((agi + spd) / 2.0))

	# Archetype modifier (brave / sage / devout — and any future archetypes).
	var arch_table: Dictionary = place_cfg.get("by_archetype", {})
	var arch_mod: int = int(arch_table.get(actor.get("archetype_birth", ""), 0))

	# Calling modifier (warrior / guardian / archer / uncalled — extensible).
	var call_table: Dictionary = place_cfg.get("by_calling_origin", {})
	var call_mod: int = int(call_table.get(actor.get("calling_origin", ""), 0))

	# Dominant trait modifier (reads actor.traits fresh — current value at combat start).
	# Tiebreak: courage > faith > wisdom (order mirrors modifier magnitude).
	var trait_table: Dictionary = place_cfg.get("by_dominant_trait", {})
	var traits: Dictionary = actor.get("traits", {})
	var dom_trait: String = dominant_key(traits, ["courage", "faith", "wisdom"])
	var trait_mod: int = int(trait_table.get(dom_trait, 0))

	# Dominant vector modifier (reads actor.vector_scores fresh — can drift over a run).
	# All ten V2 vectors are candidates — dominant_key() scores every key in the dict.
	# The list below is a TIEBREAK ONLY, for equal values among these four.
	var vec_table: Dictionary = place_cfg.get("by_dominant_vector", {})
	var vectors: Dictionary = actor.get("vector_scores", {})
	var dom_vec: String = dominant_key(vectors, ["vanguard", "seeker", "protector", "pillar"])
	var vec_mod: int = int(vec_table.get(dom_vec, 0))

	return base + arch_mod + call_mod + trait_mod + vec_mod


## Returns the key with the highest integer value in a Dictionary.
##
## EVERY key present in `scores` is a candidate. The dictionary is the source of truth,
## so a key added to a taxonomy in balance.json (V2-PROG-003 grew the vectors from 4 to 10)
## is scored here without a code change. Before V2-COMBAT-003 this function iterated
## `tiebreak_order` instead of `scores`, so any key absent from that list was invisible —
## never out-ranked, simply never examined — which silently shadowed six of the ten vectors.
##
## `tiebreak_order` is consulted ONLY to break an equal-value tie, which is what its name
## and this docstring always claimed: the key appearing earliest in the list wins. A key
## absent from the list ranks after every listed key; two unlisted keys tied on value are
## broken by ascending key name, so the result never depends on Dictionary insertion order.
##
## Returns "" if the dict is empty.
##
## Shared by CombatState.gd and ShrineService.gd (V2-COMBAT-003.5 Phase 5 extraction) —
## GridService is already "the single source of truth for all grid math" per this file's
## own header, so this is the one copy. Call sites keep their own tiebreak_order argument;
## do not change any of them without a design sign-off (ShrineService's vector order is the
## reverse of GridService's/CombatState's — that is intentional, not a bug).
static func dominant_key(scores: Dictionary, tiebreak_order: Array) -> String:
	if scores.is_empty():
		return ""
	var unranked: int    = tiebreak_order.size()
	var have: bool       = false
	var best_key: String = ""
	var best_val: int    = -9999999
	var best_rank: int   = 0
	for key_v in scores.keys():
		var key: String = str(key_v)
		var val: int    = int(scores[key_v])
		var rank: int   = tiebreak_order.find(key)
		if rank < 0:
			rank = unranked
		var better: bool = false
		if not have:
			better = true
		elif val > best_val:
			better = true
		elif val == best_val:
			if rank < best_rank:
				better = true
			elif rank == best_rank:
				better = key < best_key
		if better:
			have     = true
			best_key = key
			best_val = val
			best_rank = rank
	return best_key
