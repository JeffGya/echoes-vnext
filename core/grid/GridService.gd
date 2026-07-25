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
# Deterministic placement (GRID-003)
# -------------------------

## Places echo_actors (left half) and enemy_actors (right half) on the board using
## seeded RNG. Mutates grid_pos on each actor in-place. Returns nothing.
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
static func place_actors(echo_actors: Array, enemy_actors: Array,
		board_cfg: Dictionary, rng: RandomNumberGenerator,
		place_cfg: Dictionary = {}) -> void:
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

		# Assign echoes: iterate columns left→right, filling actors in score-ascending order.
		var echo_cells: Array = []
		for c in sorted_cols:
			for cell in cells_by_col[c]:
				echo_cells.append(cell)
		_assign_walkable_faction(sorted_echoes, echo_cells, walkable)

		# Assign enemies: iterate columns right→left, filling actors in score-ascending order.
		var enemy_cols: Array = sorted_cols.duplicate()
		enemy_cols.reverse()  # descending col order
		var enemy_cells: Array = []
		for c in enemy_cols:
			# Within each column keep rows ascending for determinism.
			for cell in cells_by_col[c]:
				enemy_cells.append(cell)
		_assign_walkable_faction(sorted_enemies, enemy_cells, walkable)


## Assigns grid positions for one faction into a pre-ordered list of walkable cells.
## actors: sorted Array of actor dicts (score-ascending, id tiebreak).
## ordered_cells: walkable cells in the desired fill order for this faction.
## walkable: the full walkable set (used as fallback pool when ordered_cells are exhausted).
## If ordered_cells has fewer entries than actors, falls back to the nearest remaining
## walkable cells (those not yet assigned) to ensure every actor gets a cell — never void.
## Purely deterministic; no RNG.
static func _assign_walkable_faction(actors: Array, ordered_cells: Array, walkable: Dictionary) -> void:
	if actors.is_empty():
		return

	# Track assigned cells to prevent two actors sharing a cell.
	var assigned: Dictionary = {}

	# Pass 1: fill actors from ordered_cells in sequence.
	var cell_idx: int = 0
	var actor_idx: int = 0
	while actor_idx < actors.size() and cell_idx < ordered_cells.size():
		var cell: Dictionary = ordered_cells[cell_idx]
		var key: String = "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]
		cell_idx += 1
		if assigned.has(key):
			continue  # already taken (shouldn't happen with well-formed input, but guard it)
		assign_grid_pos(actors[actor_idx], int(cell.get("col", 0)), int(cell.get("row", 0)))
		assigned[key] = true
		actor_idx += 1

	# Pass 2: if ordered_cells were exhausted before all actors placed, drain remaining
	# walkable cells in sorted key order (col asc, row asc) as a deterministic fallback.
	if actor_idx < actors.size():
		var fallback_keys: Array = walkable.keys()
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
	# If walkable itself is exhausted (more actors than walkable cells), the remaining actors
	# keep whatever grid_pos they had from the last assign_grid_pos call — this is a
	# degenerate edge case that cannot crash and will be caught by combat validation.


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
	var dom_trait: String = _dominant_key(traits, ["courage", "faith", "wisdom"])
	var trait_mod: int = int(trait_table.get(dom_trait, 0))

	# Dominant vector modifier (reads actor.vector_scores fresh — can drift over a run).
	# Tiebreak: vanguard > seeker > protector > pillar.
	var vec_table: Dictionary = place_cfg.get("by_dominant_vector", {})
	var vectors: Dictionary = actor.get("vector_scores", {})
	var dom_vec: String = _dominant_key(vectors, ["vanguard", "seeker", "protector", "pillar"])
	var vec_mod: int = int(vec_table.get(dom_vec, 0))

	return base + arch_mod + call_mod + trait_mod + vec_mod


## Returns the key with the highest integer value in a Dictionary.
## tiebreak_order defines which key wins when values are equal (first in list wins).
## Returns "" if the dict is empty or all values are non-integers.
static func _dominant_key(scores: Dictionary, tiebreak_order: Array) -> String:
	if scores.is_empty():
		return ""
	var best_key: String = ""
	var best_val: int = -9999999
	# Iterate in tiebreak order so the first key wins ties.
	for key in tiebreak_order:
		if not scores.has(key):
			continue
		var val: int = int(scores[key])
		if val > best_val:
			best_val = val
			best_key = key
	return best_key
