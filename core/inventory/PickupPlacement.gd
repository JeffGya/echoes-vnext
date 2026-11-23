class_name PickupPlacement
extends RefCounted

## Board tiles for the pickup event (D-72). Pure statics: no engine RNG, no writes, no player text.
## `place` returns { row: { echo_id -> {col,row} }, finds: { find_id -> {col,row} } }. Every ordering is a
## lexicographic key of integers that ends in numeric (col, row), so the result never depends on dictionary order.
##
## ROW. The party anchor is the board centre (cols / 2, rows / 2) plus `entry_offset`, clamped into the board
## rectangle. The fight cells of the Echoes are not used: the lineup always forms where the Echoes "enter".
## The row is the straight line of n adjacent region tiles (col axis or row axis) whose centre is nearest the
## anchor; the hash (which includes the axis) picks between ties. Else a connected chain of n region tiles grown
## from the tile nearest the anchor; else every Echo keeps its own tile.
## Only drawn tokens occupy a tile (Jeff, 2026-11-17): during the event those are the standing Echoes on their new
## row tiles. Dead enemies, fallen Echoes and the old start tiles of the row Echoes are free, for the row and for finds.
## FINDS. Region tiles that are not row tiles, at Chebyshev distance near..far from the row centre; per find
## the lowest hash with `spacing` to earlier finds. Fallbacks, in order: spacing 1, wider far, any other
## non-row region tile, then pile on the nearest taken tile.
## SCREEN ORDER. CombatBoardScreen's tile set is DIAMOND_RIGHT with a vertical offset axis: a col step moves
## (+64, -32) px and a row step (+64, +32), so screen-x grows with (col + row), and screen-y with (row - col).

const DEFAULT_NEAR := 2
const DEFAULT_FAR := 3
const DEFAULT_SPACING := 2
const DEFAULT_ENTRY_COL := -2
const DEFAULT_ENTRY_ROW := 0


## Stable integer hash (FNV-1a, 31 bits) over `parts` joined with "|" (an Array part is joined the same way). The one
## implementation: `PickupEventPlan.hash_of` in ui/ calls this (ui/ may call core; core must not call ui/).
static func hash_of(parts: Array) -> int:
	var texts: Array = []
	for p: Variant in parts:
		texts.append("|".join((p as Array).map(func(x: Variant) -> String: return str(x))) if p is Array else str(p))
	var joined := "|".join(texts)
	var h := 2166136261
	for i in joined.length():
		h = ((h ^ joined.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h


## { near, far, spacing, entry_offset {col,row} } from `inv_cfg.pickup.placement`. A missing key reads as 2, 3, 2 and
## { -2, 0 }. near < 0 reads as 0, far < near as near, spacing < 1 as 1. The offset is not clamped here.
static func settings(inv_cfg: Dictionary) -> Dictionary:
	var pk_v: Variant = inv_cfg.get("pickup", {})
	var pk: Dictionary = pk_v if pk_v is Dictionary else {}
	var pl_v: Variant = pk.get("placement", {})
	var pl: Dictionary = pl_v if pl_v is Dictionary else {}
	var eo_v: Variant = pl.get("entry_offset", {})
	var eo: Dictionary = eo_v if eo_v is Dictionary else {}
	var near := maxi(0, int(pl.get("near", DEFAULT_NEAR)))
	return { "near": near, "far": maxi(near, int(pl.get("far", DEFAULT_FAR))),
		"spacing": maxi(1, int(pl.get("spacing", DEFAULT_SPACING))),
		"entry_offset": { "col": int(eo.get("col", DEFAULT_ENTRY_COL)), "row": int(eo.get("row", DEFAULT_ENTRY_ROW)) } }


## `actors` = every actor of the board (dead or alive); each has `id` and `grid_pos`. `row_ids` = the standing
## Echoes in snapshot `row` order. `find_ids` = the finds in snapshot order.
static func place(terrain: Dictionary, cols: int, rows: int, seed_value: int, situation_id: String, run_count: int,
		actors: Array, row_ids: Array, find_ids: Array, inv_cfg: Dictionary) -> Dictionary:
	var cfg := settings(inv_cfg)
	var key := [seed_value, situation_id, run_count]
	var region := _region(terrain, cols, rows)
	var row_set := {}
	for id in row_ids:
		row_set[str(id)] = true
	var own := {}
	for a_v: Variant in actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		var gp_v: Variant = a.get("grid_pos", null)
		if not (gp_v is Dictionary):
			continue
		var gp: Dictionary = gp_v
		var cell := Vector2i(int(gp.get("col", -1)), int(gp.get("row", -1)))
		if row_set.has(str(a.get("id", ""))):
			own[str(a.get("id", ""))] = cell

	@warning_ignore("integer_division")
	var board_centre := Vector2i(cols / 2, rows / 2)
	var eo: Dictionary = cfg["entry_offset"]
	var anchor := Vector2i(clampi(board_centre.x + int(eo["col"]), 0, maxi(cols - 1, 0)),
		clampi(board_centre.y + int(eo["row"]), 0, maxi(rows - 1, 0)))
	var tiles := _row_tiles(region, own, row_ids, anchor, key)
	var centre := _average(tiles, anchor)
	var out_row := {}
	for i in row_ids.size():
		out_row[str(row_ids[i])] = _d(tiles[i])
	var out_finds := _find_tiles(region, tiles, centre, find_ids, cfg, key)
	return { "row": out_row, "finds": out_finds }


# ---------------------------------------------------------------------------
# Row
# ---------------------------------------------------------------------------

static func _row_tiles(region: Dictionary, own: Dictionary, row_ids: Array, anchor: Vector2i, key: Array) -> Array:
	var n := row_ids.size()
	var out: Array = []
	if n == 0:
		return out
	var starts := _sorted_cells(region)
	var lines: Array = []
	for axis in 2:
		var step := Vector2i(1, 0) if axis == 0 else Vector2i(0, 1)
		for s: Vector2i in starts:
			if not region.has(_k(s + step * (n - 1))):
				continue
			var ok := true
			for i in n:
				if not region.has(_k(s + step * i)):
					ok = false
					break
			if not ok:
				continue
			var cx2 := 2 * s.x + (n - 1) * step.x
			var cy2 := 2 * s.y + (n - 1) * step.y
			lines.append([maxi(absi(cx2 - 2 * anchor.x), absi(cy2 - 2 * anchor.y)),
				hash_of(key + [axis, s.x, s.y]), axis, s.x, s.y])
	if not lines.is_empty():
		lines.sort_custom(_lex_less)
		var best: Array = lines[0]
		var st := Vector2i(1, 0) if int(best[2]) == 0 else Vector2i(0, 1)
		for i in n:
			out.append(Vector2i(int(best[3]), int(best[4])) + st * i)
		return _screen_order(out)
	var chain := _chain(region, starts, n, anchor, key)
	if not chain.is_empty():
		return _screen_order(chain)
	for id in row_ids:
		out.append(own.get(str(id), anchor))
	return out


## A connected chain of n region tiles (each touches the previous by Chebyshev distance 1; no tile twice).
## Starts are tried in order of (distance to the anchor, hash, col, row). From a start the chain always adds the
## unused neighbour of its last tile that is nearest the anchor (then hash, col, row). A start that gets stuck
## before n tiles is skipped. [] when no start works.
static func _chain(region: Dictionary, starts: Array, n: int, anchor: Vector2i, key: Array) -> Array:
	var order: Array = []
	for c: Vector2i in starts:
		order.append([_cheb(c, anchor), hash_of(key + ["row", c.x, c.y]), c.x, c.y])
	order.sort_custom(_lex_less)
	for o: Array in order:
		var chain: Array = [Vector2i(int(o[2]), int(o[3]))]
		var used := { _k(chain[0]): true }
		while chain.size() < n:
			var last: Vector2i = chain[chain.size() - 1]
			var best: Array = []
			for dc in range(-1, 2):
				for dr in range(-1, 2):
					var c := last + Vector2i(dc, dr)
					if (dc == 0 and dr == 0) or not region.has(_k(c)) or used.has(_k(c)):
						continue
					var cand := [_cheb(c, anchor), hash_of(key + ["row", c.x, c.y]), c.x, c.y]
					if best.is_empty() or _lex_less(cand, best):
						best = cand
			if best.is_empty():
				break
			var next := Vector2i(int(best[2]), int(best[3]))
			chain.append(next)
			used[_k(next)] = true
		if chain.size() == n:
			return chain
	return []


# ---------------------------------------------------------------------------
# Finds
# ---------------------------------------------------------------------------

static func _find_tiles(region: Dictionary, row_tiles: Array, centre: Vector2i, find_ids: Array,
		cfg: Dictionary, key: Array) -> Dictionary:
	var near := int(cfg["near"])
	var far := int(cfg["far"])
	var spacing := int(cfg["spacing"])
	var row_set := {}
	for t: Vector2i in row_tiles:
		row_set[_k(t)] = true
	var cells: Array = []
	var max_d := 0
	for c: Vector2i in _sorted_cells(region):
		if not row_set.has(_k(c)):
			cells.append(c)
			max_d = maxi(max_d, _cheb(c, centre))
	var taken: Array = []
	var taken_set := {}
	var out := {}
	for fid in find_ids:
		var pick: Variant = null
		var levels: Array = [spacing] if spacing == 1 else [spacing, 1]
		for s: int in levels:
			pick = _best(cells, taken, taken_set, centre, near, far, s, true, key, str(fid))
			if pick != null:
				break
		var reach := far + 1
		while pick == null and reach <= max_d:
			pick = _best(cells, taken, taken_set, centre, near, reach, 1, true, key, str(fid))
			reach += 1
		if pick == null:
			pick = _best(cells, taken, taken_set, centre, 0, max_d, 0, false, key, str(fid))
		if pick == null:
			pick = _nearest_taken(taken, centre)
		var tile: Vector2i = pick
		if not taken_set.has(_k(tile)):
			taken.append(tile)
			taken_set[_k(tile)] = true
		out[str(fid)] = _d(tile)
	return out


## The candidate with the lowest (hash, col, row). `strict` = distance near..far and at least `spacing` from every
## taken tile; not strict = every untaken cell.
static func _best(cells: Array, taken: Array, taken_set: Dictionary, centre: Vector2i,
		near: int, far: int, spacing: int, strict: bool, key: Array, fid: String) -> Variant:
	var best: Array = []
	for c: Vector2i in cells:
		if taken_set.has(_k(c)):
			continue
		if strict:
			var d := _cheb(c, centre)
			if d < near or d > far:
				continue
			var far_enough := true
			for t: Vector2i in taken:
				if _cheb(c, t) < spacing:
					far_enough = false
					break
			if not far_enough:
				continue
		var cand := [hash_of(key + [fid, c.x, c.y]), c.x, c.y]
		if best.is_empty() or _lex_less(cand, best):
			best = cand
	return null if best.is_empty() else Vector2i(int(best[1]), int(best[2]))


## The taken tile nearest the row centre (ties: lowest col, then row); the centre when nothing is taken.
static func _nearest_taken(taken: Array, centre: Vector2i) -> Vector2i:
	var best: Array = []
	for t: Vector2i in taken:
		var cand := [_cheb(t, centre), t.x, t.y]
		if best.is_empty() or _lex_less(cand, best):
			best = cand
	return centre if best.is_empty() else Vector2i(int(best[1]), int(best[2]))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## The largest walkable region as a "col,row" set. Terrain with no walkable set (the sentinel) means every cell.
static func _region(terrain: Dictionary, cols: int, rows: int) -> Dictionary:
	var walk := StageTerrain.walkable_set(terrain)
	if walk.is_empty():
		for c in range(maxi(cols, 0)):
			for r in range(maxi(rows, 0)):
				walk["%d,%d" % [c, r]] = true
	return GridService.largest_walkable_region(walk, { "w": cols, "h": rows })


## Integer average with rounding up at half: (sum + n / 2) / n. `fallback` for no cells.
static func _average(cells: Array, fallback: Vector2i) -> Vector2i:
	var n := cells.size()
	if n == 0:
		return fallback
	var sc := 0
	var sr := 0
	for c: Vector2i in cells:
		sc += c.x
		sr += c.y
	@warning_ignore("integer_division")
	var half := n / 2
	@warning_ignore("integer_division")
	return Vector2i((sc + half) / n, (sr + half) / n)


static func _sorted_cells(region: Dictionary) -> Array:
	var out: Array = []
	for k: String in region:
		var p := k.split(",")
		out.append(Vector2i(int(p[0]), int(p[1])))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


## Left to right on screen: (col + row), then (row - col), then col, then row.
static func _screen_order(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _lex_less([a.x + a.y, a.y - a.x, a.x, a.y], [b.x + b.y, b.y - b.x, b.x, b.y]))
	return out


static func _lex_less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _k(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _d(c: Vector2i) -> Dictionary:
	return { "col": c.x, "row": c.y }
