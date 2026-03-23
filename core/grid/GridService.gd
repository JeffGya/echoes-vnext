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
#   GRID-005 — move_toward()                    ← implemented here

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
## Used internally by _greedy_step() as a direction heuristic — do not replace there.
static func manhattan_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("col", 0)) - int(b.get("col", 0))) \
		 + abs(int(a.get("row", 0)) - int(b.get("row", 0)))


## Returns the Chebyshev distance between two grid_pos dicts { col, row }.
## Chebyshev = max(|Δcol|, |Δrow|) — matches the true step cost for 8-directional movement.
## A diagonal neighbour is distance 1, same as an orthogonal neighbour.
## Use for all range checks and AI distance awareness; keep manhattan_distance() for _greedy_step.
static func chebyshev_distance(a: Dictionary, b: Dictionary) -> int:
	return max(abs(int(a.get("col", 0)) - int(b.get("col", 0))),
			   abs(int(a.get("row", 0)) - int(b.get("row", 0))))


## Returns true if two grid_pos dicts are adjacent (Chebyshev distance == 1).
## Covers all 8 neighbours: orthogonal (N/S/E/W) and diagonal (NE/NW/SE/SW).
## Use for melee range checks — do not substitute manhattan_distance == 1.
static func is_adjacent(a: Dictionary, b: Dictionary) -> bool:
	return chebyshev_distance(a, b) == 1


# -------------------------
# Movement helpers (GRID-005)
# -------------------------

## Moves actor one cell toward target_pos using greedy 8-directional movement.
## Mutates actor["grid_pos"] in-place. Returns { "from_pos": Dictionary, "to_pos": Dictionary }.
## Pure except for the actor mutation — no RNG, no logging.
## If no valid neighbour exists (degenerate board), actor is not moved.
## occupied_positions: Array of { col, row } dicts for cells already taken by living actors.
static func move_toward(actor: Dictionary, target_pos: Dictionary,
		board_cfg: Dictionary = {}, occupied_positions: Array = []) -> Dictionary:
	var from_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 }).duplicate()
	var best: Dictionary = _greedy_step(from_pos, target_pos, board_cfg, occupied_positions)
	if best != from_pos:
		assign_grid_pos(actor, int(best.get("col", 0)), int(best.get("row", 0)))
	return { "from_pos": from_pos, "to_pos": actor["grid_pos"].duplicate() }


## Returns the best neighbour cell to step toward target_pos using greedy minimisation.
## Considers all 8 neighbours; filters out-of-bounds cells via is_valid_pos().
## Filters cells in occupied_positions so two living actors cannot share a cell.
## Tiebreak: lowest (col + row) sum. Returns from_pos if no valid neighbour found.
static func _greedy_step(from_pos: Dictionary, target_pos: Dictionary,
		board_cfg: Dictionary, occupied_positions: Array = []) -> Dictionary:
	var fc: int = int(from_pos.get("col", 0))
	var fr: int = int(from_pos.get("row", 0))

	var best: Dictionary = from_pos
	var best_dist: int = manhattan_distance(from_pos, target_pos)
	var best_sum: int = fc + fr

	for dc in [-1, 0, 1]:
		for dr in [-1, 0, 1]:
			if dc == 0 and dr == 0:
				continue
			var candidate: Dictionary = { "col": fc + dc, "row": fr + dr }
			if not is_valid_pos(candidate, board_cfg):
				continue
			# Skip cells already occupied by a living actor.
			var is_occupied: bool = false
			for occ_v in occupied_positions:
				if occ_v is Dictionary \
						and int(occ_v.get("col", -1)) == candidate["col"] \
						and int(occ_v.get("row", -1)) == candidate["row"]:
					is_occupied = true
					break
			if is_occupied:
				continue
			var dist: int = manhattan_distance(candidate, target_pos)
			var sum: int = int(candidate["col"]) + int(candidate["row"])
			if dist < best_dist or (dist == best_dist and sum < best_sum):
				best = candidate
				best_dist = dist
				best_sum = sum

	return best


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

	# Echoes fill from col=1 inward (col=1 = back, col=2 = more forward, etc.)
	_pack_faction(sorted_echoes, 1, 1, rows, rng)

	# Enemies fill from col=cols-2 inward (col=cols-2 = back, col=cols-3 = forward)
	_pack_faction(sorted_enemies, cols - 2, -1, rows, rng)


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
