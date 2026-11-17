# res://tests/PickupPlacementTests.gd
# V2-ITEM-001b D-72: PickupPlacement (core/inventory/PickupPlacement.gd), the board tiles of the pickup event.
# Registered from PickupSnapshotTests.register, so the suite name is `pickup_snapshot`.
# Worked cases are derived by hand in the comments; the hash-dependent ones list the candidate set by hand and take
# the lowest hash with a loop that calls PickupPlacement.hash_of.

class_name PickupPlacementTests
extends RefCounted

const _SEED := 77
const _SIT := "s0"
const _RUN := 1


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_snapshot/placement_is_deterministic", Callable(PickupPlacementTests, "_t_deterministic"))
	runner.register_test("pickup_snapshot/placement_hand_worked_row_keeps_a_straight_party", Callable(PickupPlacementTests, "_t_worked_row"))
	runner.register_test("pickup_snapshot/placement_hand_worked_find_is_the_lowest_hash_of_the_band", Callable(PickupPlacementTests, "_t_worked_find"))
	runner.register_test("pickup_snapshot/placement_finds_are_distinct_free_spaced_and_in_the_band", Callable(PickupPlacementTests, "_t_finds_rules"))
	runner.register_test("pickup_snapshot/placement_row_is_straight_and_n_long_for_n_1_to_5", Callable(PickupPlacementTests, "_t_row_straight"))
	runner.register_test("pickup_snapshot/placement_row_runs_left_to_right_on_screen_in_row_order", Callable(PickupPlacementTests, "_t_row_order"))
	runner.register_test("pickup_snapshot/placement_row_may_use_the_tile_of_a_dead_enemy", Callable(PickupPlacementTests, "_t_row_free"))
	runner.register_test("pickup_snapshot/placement_finds_may_use_dead_enemy_and_old_start_tiles", Callable(PickupPlacementTests, "_t_finds_free"))
	runner.register_test("pickup_snapshot/placement_never_uses_void_or_island_cells", Callable(PickupPlacementTests, "_t_holes"))
	runner.register_test("pickup_snapshot/placement_sentinel_terrain_uses_the_whole_board", Callable(PickupPlacementTests, "_t_sentinel"))
	runner.register_test("pickup_snapshot/placement_piles_finds_when_tiles_run_out", Callable(PickupPlacementTests, "_t_pile"))
	runner.register_test("pickup_snapshot/placement_row_fallback_is_a_chain_then_own_tiles", Callable(PickupPlacementTests, "_t_row_fallback"))
	runner.register_test("pickup_snapshot/placement_with_no_echo_cells_centres_on_the_board", Callable(PickupPlacementTests, "_t_no_echo_cells"))
	runner.register_test("pickup_snapshot/placement_hash_equals_the_ui_hash", Callable(PickupPlacementTests, "_t_hash_equal"))
	runner.register_test("pickup_snapshot/placement_constants_come_from_config", Callable(PickupPlacementTests, "_t_config"))
	runner.register_test("pickup_snapshot/placement_config_validator_accepts_shipping_and_rejects_bad", Callable(PickupPlacementTests, "_t_validator"))
	runner.register_test("pickup_snapshot/placement_tiles_in_the_snapshot_are_live_equal_to_reload", Callable(PickupPlacementTests, "_t_snapshot_tiles"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _a(id: String, col: int, row: int) -> Dictionary:
	return { "id": id, "grid_pos": { "col": col, "row": row } }


static func _cfg(near: int = 2, far: int = 3, spacing: int = 2) -> Dictionary:
	return { "pickup": { "placement": { "near": near, "far": far, "spacing": spacing } } }


static func _run(actors: Array, row_ids: Array, find_ids: Array, terrain: Dictionary = {}, cols: int = 7, rows: int = 5,
		cfg: Dictionary = {}) -> Dictionary:
	return PickupPlacement.place(terrain, cols, rows, _SEED, _SIT, _RUN, actors, row_ids, find_ids,
		_cfg() if cfg.is_empty() else cfg)


static func _t(d: Dictionary) -> Vector2i:
	return Vector2i(int(d["col"]), int(d["row"]))


static func _ids(prefix: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append("%s%d" % [prefix, i])
	return out


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _cells_of(actors: Array) -> Array:
	return actors.map(func(a: Dictionary) -> Vector2i: return _t(a["grid_pos"]))


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_deterministic() -> Dictionary:
	var m: Array = []
	var actors := [_a("e0", 1, 1), _a("e1", 2, 1), _a("x0", 5, 3)]
	var a := _run(actors, ["e0", "e1"], ["f0", "f1", "f2"])
	var b := _run(actors.duplicate(true), ["e0", "e1"], ["f0", "f1", "f2"])
	if str(a) != str(b):
		m.append("two runs differ: %s / %s" % [str(a), str(b)])
	if str(_run(actors, ["e0", "e1"], ["f0", "f1", "f2"], {}, 7, 5, _cfg(2, 3, 2))) != str(a):
		m.append("an explicit default config differs from the default")
	return _result(m)


## Hand-derived. Board 7 x 5 (sentinel), Echoes (1,1) (2,1) (3,1). Anchor = ((6 + 1) / 3, (3 + 1) / 3) = (2, 1).
## A line is scored by the Chebyshev distance of its doubled centre to (4, 2). Axis 0 start (1,1): centre (4, 2), 0.
## Axis 1 start (2,0): centre (4, 2), 0. No other line has 0. The hash of [seed, sit, run, axis, col, row] picks
## between the two (the axis is part of the hash); the test computes both hashes with `hash_of`.
static func _t_worked_row() -> Dictionary:
	var m: Array = []
	var r: Dictionary = _run([_a("e0", 1, 1), _a("e1", 2, 1), _a("e2", 3, 1)], ["e0", "e1", "e2"], [])["row"]
	var h0 := PickupPlacement.hash_of([_SEED, _SIT, _RUN, 0, 1, 1])
	var h1 := PickupPlacement.hash_of([_SEED, _SIT, _RUN, 1, 2, 0])
	var horizontal := h0 <= h1
	var want := { "e0": Vector2i(1, 1), "e1": Vector2i(2, 1), "e2": Vector2i(3, 1) } if horizontal \
		else { "e0": Vector2i(2, 0), "e1": Vector2i(2, 1), "e2": Vector2i(2, 2) }
	for id in want:
		if _t(r[id]) != want[id]:
			m.append("%s at %s, want %s" % [id, str(r[id]), str(want[id])])
	if not horizontal:
		m.append("golden changed: the hash now picks the vertical line for seed %d" % _SEED)
	# The hash, not the axis, decides: find a seed whose axis 1 hash is the lower one, and expect the vertical line.
	var vertical_seen := false
	for sd in 60:
		if PickupPlacement.hash_of([sd, _SIT, _RUN, 1, 2, 0]) < PickupPlacement.hash_of([sd, _SIT, _RUN, 0, 1, 1]):
			vertical_seen = true
			var o: Dictionary = PickupPlacement.place({}, 7, 5, sd, _SIT, _RUN, [_a("e0", 1, 1), _a("e1", 2, 1), _a("e2", 3, 1)],
				["e0", "e1", "e2"], [], _cfg())["row"]
			if _t(o["e0"]) != Vector2i(2, 0) or _t(o["e2"]) != Vector2i(2, 2):
				m.append("seed %d: axis 1 hash is lower but the row is %s" % [sd, str(o)])
	if not vertical_seen:
		m.append("test setup: no seed in 0..59 prefers axis 1")
	var one: Dictionary = _run([_a("e0", 2, 3)], ["e0"], [])["row"]
	if _t(one["e0"]) != Vector2i(2, 3):
		m.append("n = 1 at %s, want (2,3)" % str(one["e0"]))
	return _result(m)


## Hand-worked band. Echo e0 (2,3) on 7 x 5, near 2, far 3: the row tile and centre are (2,3). Free tiles with
## Chebyshev distance 2..3 from (2,3): cols 0, 4, 5 on every row (15 tiles; col 0 and col 4 are 2 away, col 5 is 3
## away) plus cols 1..3 on rows 0 and 1 (6 tiles) = 21. Cols 1..3 on rows 2..4 are within 1; col 6 is 4 away.
static func _t_worked_find() -> Dictionary:
	var m: Array = []
	var cand: Array = []
	for c in [0, 4, 5]:
		for r in 5:
			cand.append(Vector2i(c, r))
	for c in [1, 2, 3]:
		for r in [0, 1]:
			cand.append(Vector2i(c, r))
	if cand.size() != 21:
		m.append("hand list has %d tiles, want 21" % cand.size())
	var want := Vector2i(-1, -1)
	var best := -1
	for c: Vector2i in cand:
		var h := PickupPlacement.hash_of([_SEED, _SIT, _RUN, "f0", c.x, c.y])
		if best == -1 or h < best or (h == best and (c.x < want.x or (c.x == want.x and c.y < want.y))):
			best = h
			want = c
	var got := _t(_run([_a("e0", 2, 3)], ["e0"], ["f0"])["finds"]["f0"])
	if got != want:
		m.append("find at %s, want %s" % [str(got), str(want)])
	# Golden value: pins the hash and the rule together, so an edit to either shows here.
	if got != Vector2i(1, 0):
		m.append("golden find tile is %s, pinned (1,0)" % str(got))
	return _result(m)


static func _t_finds_rules() -> Dictionary:
	var m: Array = []
	var actors := [_a("e0", 1, 2), _a("e1", 2, 2), _a("n0", 5, 0), _a("n1", 6, 4)]
	var out := _run(actors, ["e0", "e1"], _ids("f", 3), {}, 9, 7)
	var row_tiles: Array = (out["row"] as Dictionary).values().map(func(d: Dictionary) -> Vector2i: return _t(d))
	var sum := Vector2i.ZERO
	for t: Vector2i in row_tiles:
		sum += t
	@warning_ignore("integer_division")
	var centre := Vector2i((sum.x + 1) / 2, (sum.y + 1) / 2)
	var seen: Array = []
	for fid in out["finds"]:
		var t := _t(out["finds"][fid])
		if seen.has(t):
			m.append("two finds on %s" % str(t))
		if row_tiles.has(t):
			m.append("find %s on a row tile %s" % [fid, str(t)])
		var d := _cheb(t, centre)
		if d < 2 or d > 3:
			m.append("find %s at distance %d, want 2..3" % [fid, d])
		for s: Vector2i in seen:
			if _cheb(t, s) < 2:
				m.append("finds closer than spacing: %s %s" % [str(t), str(s)])
		seen.append(t)
	return _result(m)


static func _t_row_straight() -> Dictionary:
	var m: Array = []
	# Scattered start tiles, so a row that keeps the own tiles is not a line (n >= 2).
	var starts := [Vector2i(7, 5), Vector2i(0, 1), Vector2i(4, 6), Vector2i(8, 0), Vector2i(2, 3)]
	for n in range(1, 6):
		var actors: Array = []
		for i in n:
			actors.append(_a("e%d" % i, starts[i].x, starts[i].y))
		var ids := _ids("e", n)
		var row: Dictionary = _run(actors, ids, [], {}, 9, 7)["row"]
		var tiles: Array = ids.map(func(id: String) -> Vector2i: return _t(row[id]))
		if tiles.size() != n or tiles.size() != (row as Dictionary).size():
			m.append("n=%d: %d tiles" % [n, tiles.size()])
		var sorted_tiles := tiles.duplicate()
		sorted_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
		var along_col := true
		var along_row := true
		for i in range(1, n):
			var step: Vector2i = sorted_tiles[i] - sorted_tiles[0]
			along_col = along_col and step == Vector2i(i, 0)
			along_row = along_row and step == Vector2i(0, i)
		if not (along_col or along_row):
			m.append("n=%d: tiles are not a straight line %s" % [n, str(tiles)])
	return _result(m)


static func _t_row_order() -> Dictionary:
	var m: Array = []
	# Start tiles in the wrong screen order: ids run right to left on the board, so the tiles must be re-assigned.
	for starts in [[Vector2i(5, 4), Vector2i(1, 1), Vector2i(3, 6)], [Vector2i(8, 5), Vector2i(0, 0), Vector2i(6, 1), Vector2i(2, 6)]]:
		var n: int = starts.size()
		var ids := _ids("e", n)
		var actors: Array = []
		for i in n:
			actors.append(_a("e%d" % i, starts[i].x, starts[i].y))
		var row: Dictionary = _run(actors, ids, [], {}, 9, 7)["row"]
		var xs: Array = ids.map(func(id: String) -> int: return _t(row[id]).x + _t(row[id]).y)
		for i in range(1, n):
			if xs[i] <= xs[i - 1]:
				m.append("n=%d: screen x not rising %s" % [n, str(xs)])
	var actors2 := [_a("a", 1, 1), _a("b", 2, 1)]
	var fwd: Dictionary = _run(actors2, ["a", "b"], [])["row"]
	var rev: Dictionary = _run(actors2, ["b", "a"], [])["row"]
	if _t(fwd["a"]) != _t(rev["b"]) or _t(fwd["b"]) != _t(rev["a"]):
		m.append("row order does not decide the left to right order: %s / %s" % [str(fwd), str(rev)])
	# Terrain that leaves one column forces an axis 1 line; the ids stand in reverse down the column.
	var column := { "bounds": { "w": 3, "h": 3 }, "plateaus": [{ "col": 1, "row": 0, "w": 1, "h": 3, "cells": [[1, 0], [1, 1], [1, 2]] }] }
	var col_actors := [_a("e0", 1, 2), _a("e1", 1, 0), _a("e2", 1, 1)]
	var col_line: Dictionary = _run(col_actors, ["e0", "e1", "e2"], [], column, 3, 3)["row"]
	var want := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	for i in 3:
		if _t(col_line["e%d" % i]) != want[i]:
			m.append("axis 1 line: e%d at %s, want %s" % [i, str(col_line["e%d" % i]), str(want[i])])
	return _result(m)


static func _t_row_free() -> Dictionary:
	var m: Array = []
	# Only drawn tokens occupy tiles, so a dead enemy tile is free for the row. 3 x 1 board, enemy x on (1,0),
	# Echoes on (0,0) and (2,0): the only lines of 2 both use (1,0).
	var row: Dictionary = _run([_a("e0", 0, 0), _a("e1", 2, 0), _a("x", 1, 0)], ["e0", "e1"], [], {}, 3, 1)["row"]
	var tiles: Array = [_t(row["e0"]), _t(row["e1"])]
	if not tiles.has(Vector2i(1, 0)) or _cheb(tiles[0], tiles[1]) != 1:
		m.append("the row did not use the dead enemy tile: %s" % str(row))
	return _result(m)


## Finds may lie on a dead enemy tile and on the old start tile of a row Echo.
static func _t_finds_free() -> Dictionary:
	var m: Array = []
	# 4 x 1 board, Echo (0,0), enemy (3,0): near 3 far 3 leaves only (3,0).
	var out := _run([_a("e0", 0, 0), _a("x", 3, 0)], ["e0"], ["f0"], {}, 4, 1, _cfg(3, 3, 2))
	if _t(out["finds"]["f0"]) != Vector2i(3, 0):
		m.append("find at %s, want the dead enemy tile (3,0)" % str(out["finds"]["f0"]))
	# 3 x 1 board, Echoes on (0,0) and (1,0). Search a seed where the row moves to (1,0) (2,0): the one tile left is
	# the old start tile (0,0), and the find must lie there.
	var found := false
	for sd in 60:
		var o := PickupPlacement.place({}, 3, 1, sd, _SIT, _RUN, [_a("e0", 0, 0), _a("e1", 1, 0)], ["e0", "e1"], ["f0"], _cfg(0, 5, 1))
		if _t(o["row"]["e0"]) == Vector2i(1, 0):
			found = true
			if _t(o["finds"]["f0"]) != Vector2i(0, 0):
				m.append("seed %d: find at %s, want the old start tile (0,0)" % [sd, str(o["finds"]["f0"])])
	if not found:
		m.append("test setup: no seed moved the row off the start tiles")
	return _result(m)


static func _holey() -> Dictionary:
	var cells: Array = []
	for c in 5:
		for r in 5:
			if c != 2 or r != 2:
				cells.append([c, r])
	return { "bounds": { "w": 8, "h": 5 }, "plateaus": [{ "col": 0, "row": 0, "w": 5, "h": 5, "cells": cells }],
		"islands": [{ "cells": [[7, 0]] }] }


static func _t_holes() -> Dictionary:
	var m: Array = []
	var terrain := _holey()
	var actors := [_a("e0", 1, 2), _a("e1", 2, 3), _a("x", 4, 4)]
	var out := _run(actors, ["e0", "e1"], _ids("f", 4), terrain, 8, 5)
	var tiles: Array = []
	tiles.append_array((out["row"] as Dictionary).values())
	tiles.append_array((out["finds"] as Dictionary).values())
	for d: Dictionary in tiles:
		var t := _t(d)
		if t == Vector2i(2, 2) or t == Vector2i(7, 0) or t.x > 4 or t.y > 4 or t.x < 0 or t.y < 0:
			m.append("a tile lies on void or on the island: %s" % str(t))
	return _result(m)


static func _t_sentinel() -> Dictionary:
	var m: Array = []
	var out := _run([_a("e0", 3, 2)], ["e0"], _ids("f", 3), {}, 7, 5)
	for d: Dictionary in (out["finds"] as Dictionary).values():
		var t := _t(d)
		if t.x < 0 or t.x > 6 or t.y < 0 or t.y > 4:
			m.append("tile off the board %s" % str(t))
	if (out["finds"] as Dictionary).size() != 3:
		m.append("finds %s" % str(out["finds"]))
	# A zero-size board has no region at all: every tile falls back to the anchor and nothing crashes.
	var none := PickupPlacement.place({}, 0, 0, _SEED, _SIT, _RUN, [], ["e0"], ["f0", "f1"], _cfg())
	if str(none["row"]) != str({ "e0": { "col": 0, "row": 0 } }) or (none["finds"] as Dictionary).size() != 2:
		m.append("empty board: %s" % str(none))
	return _result(m)


static func _t_pile() -> Dictionary:
	var m: Array = []
	# 2 x 2 board, one Echo on (0,0): 3 non-row tiles. Five finds: 3 distinct tiles, then the pile reuses a taken tile.
	var out := _run([_a("e0", 0, 0)], ["e0"], _ids("f", 5), {}, 2, 2)
	var tiles := {}
	for fid in out["finds"]:
		var t := _t(out["finds"][fid])
		tiles[str(t)] = true
		if t == Vector2i(0, 0) or t.x > 1 or t.y > 1:
			m.append("%s on %s" % [fid, str(t)])
	if (out["finds"] as Dictionary).size() != 5:
		m.append("a find has no tile: %s" % str(out["finds"]))
	if tiles.size() != 3:
		m.append("%d distinct tiles, want 3 before the pile" % tiles.size())
	# With room for every find, no find shares a tile.
	var wide := _run([_a("e0", 3, 2)], ["e0"], _ids("f", 6), {}, 9, 9)
	var distinct := {}
	for d: Dictionary in (wide["finds"] as Dictionary).values():
		distinct[str(_t(d))] = true
	if distinct.size() != 6:
		m.append("6 finds on %d tiles although room exists" % distinct.size())
	return _result(m)


static func _t_row_fallback() -> Dictionary:
	var m: Array = []
	# Fewer region tiles than Echoes: every Echo keeps its own tile (two share (2,0)).
	var actors := [_a("e0", 0, 0), _a("e1", 1, 0), _a("e2", 2, 0), _a("e3", 2, 0)]
	var row: Dictionary = _run(actors, _ids("e", 4), [], {}, 3, 1)["row"]
	for i in 4:
		var own: Vector2i = _t(actors[i]["grid_pos"])
		if _t(row["e%d" % i]) != own:
			m.append("e%d moved to %s, want its own tile %s" % [i, str(row["e%d" % i]), str(own)])
	# An L shaped corridor of 5 tiles has no straight line of 4: the row is a connected chain of 4 of its tiles.
	var corridor := { "bounds": { "w": 3, "h": 3 }, "plateaus": [{ "col": 0, "row": 0, "w": 3, "h": 3,
		"cells": [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]] }] }
	var l_cells := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	var scattered := [_a("e0", 2, 2), _a("e1", 0, 0), _a("e2", 1, 2), _a("e3", 0, 1)]
	var out: Dictionary = _run(scattered, _ids("e", 4), [], corridor, 3, 3)["row"]
	var tiles: Array = _ids("e", 4).map(func(id: String) -> Vector2i: return _t(out[id]))
	var seen := {}
	for t: Vector2i in tiles:
		if not l_cells.has(t) or seen.has(str(t)):
			m.append("chain tile %s is not a distinct corridor tile" % str(t))
		seen[str(t)] = true
	# Connected: a flood from the first tile over Chebyshev-1 steps reaches all four.
	var reach := [tiles[0]]
	var grew := true
	while grew:
		grew = false
		for t: Vector2i in tiles:
			if not reach.has(t):
				for r: Vector2i in reach:
					if _cheb(t, r) == 1:
						reach.append(t)
						grew = true
						break
	if reach.size() != 4:
		m.append("the chain is not connected: %s" % str(tiles))
	var xs: Array = tiles.map(func(t: Vector2i) -> int: return t.x + t.y)
	for i in range(1, 4):
		if xs[i] < xs[i - 1]:
			m.append("chain is not ordered left to right %s" % str(xs))
	# Greedy growth from every start can dead-end (it takes the neighbour nearest the anchor and never backs up).
	# Five Echoes on the same tile (0,0) of the 5 tile corridor: the anchor is (0,0), and every start ends short of 5
	# tiles (checked by running it). Then each Echo keeps its own tile. This pins that fallback of the rule.
	var all5: Dictionary = _run(_ids_actors(5), _ids("e", 5), [], corridor, 3, 3)["row"]
	for id in all5:
		if _t(all5[id]) != Vector2i(0, 0):
			m.append("chain too short: %s left its own tile for %s" % [id, str(all5[id])])
	return _result(m)


static func _ids_actors(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(_a("e%d" % i, 0, 0))
	return out


static func _t_no_echo_cells() -> Dictionary:
	var m: Array = []
	# No Echo has a cell: the anchor is the board centre (7/2, 5/2) = (3, 2). Two Echoes: every line near it is
	# within distance 1 (doubled) and the hash picks one; the pair must touch and stay next to the centre.
	var out := _run([], ["a", "b"], ["f0"])
	var ra := _t(out["row"]["a"])
	var rb := _t(out["row"]["b"])
	var step := rb - ra
	if _cheb(ra, Vector2i(3, 2)) > 1 or _cheb(rb, Vector2i(3, 2)) > 1 or (step != Vector2i(1, 0) and step != Vector2i(0, 1)):
		m.append("row of two without cells: %s %s" % [str(ra), str(rb)])
	if not (out["finds"] as Dictionary).has("f0"):
		m.append("no find tile")
	return _result(m)


static func _t_hash_equal() -> Dictionary:
	var m: Array = []
	var samples: Array = [[1], ["a", 2, 3], [_SEED, _SIT, _RUN, "f0", 3, 4], [123456789012, "stage.x", 0, 1, 2, 3],
		[[1, 2], "b"], [], ["", ""], [-5, 0, -1], ["a|b", "c"], [[1, [2, 3]], "x"], [-9007199254740993, "é"]]
	for s in samples:
		var a := PickupPlacement.hash_of(s)
		var b := PickupEventPlan.hash_of(s)
		if a != b:
			m.append("%s: core %d, ui %d" % [str(s), a, b])
	return _result(m)


static func _t_config() -> Dictionary:
	var m: Array = []
	var d := PickupPlacement.settings({})
	if d != { "near": 2, "far": 3, "spacing": 2 }:
		m.append("missing keys read %s, want 2, 3, 2" % str(d))
	var shipping := ConfigService.new()
	shipping.load_balance()
	var inv := ConfigService.get_inventory_cfg(shipping)
	if PickupPlacement.settings(inv) != { "near": 2, "far": 3, "spacing": 2 }:
		m.append("shipping config reads %s" % str(PickupPlacement.settings(inv)))
	if PickupPlacement.settings(_cfg(0, 0, 0)) != { "near": 0, "far": 0, "spacing": 1 }:
		m.append("bad values are not clamped: %s" % str(PickupPlacement.settings(_cfg(0, 0, 0))))
	var actors := [_a("e0", 8, 8)]
	var ids := _ids("f", 3)
	# Each constant moves the result: a hard-coded value would not.
	var base := _run(actors, ["e0"], ids, {}, 17, 17, _cfg(2, 3, 2))
	var cases := { "near": _cfg(4, 6, 2), "far": _cfg(2, 8, 2) }
	for k in cases:
		var out := _run(actors, ["e0"], ids, {}, 17, 17, cases[k])
		if str(out) == str(base):
			m.append("changing %s changes nothing" % k)
	# Spacing: a ring of 16 tiles (near 2, far 2) holds 6 finds; spacing 2 and spacing 1 must give other tiles.
	var six := _ids("g", 6)
	if str(_run(actors, ["e0"], six, {}, 17, 17, _cfg(2, 2, 2))) == str(_run(actors, ["e0"], six, {}, 17, 17, _cfg(2, 2, 1))):
		m.append("changing spacing changes nothing")
	var wide := _run(actors, ["e0"], ids, {}, 17, 17, _cfg(4, 6, 2))
	for d2: Dictionary in (wide["finds"] as Dictionary).values():
		var dist := _cheb(_t(d2), Vector2i(8, 8))
		if dist < 4 or dist > 6:
			m.append("near 4, far 6 gave a find at distance %d" % dist)
	return _result(m)


static func _t_validator() -> Dictionary:
	var m: Array = []
	var shipping := ConfigService.new()
	shipping.load_balance()
	var inv := ConfigService.get_inventory_cfg(shipping)
	var problems := ConfigValidator.validate_pickup(inv)
	if not problems.is_empty():
		m.append("shipping config: %s" % str(problems))
	var base: Dictionary = (inv["pickup"] as Dictionary).duplicate(true)
	for bad in [{ "near": -1, "far": 3, "spacing": 2 }, { "near": 2, "far": 1, "spacing": 2 }, { "near": 2, "far": 3, "spacing": 0 },
			{ "near": 1.5, "far": 3, "spacing": 2 }, {}]:
		var cfg := { "pickup": base.duplicate(true) }
		cfg["pickup"]["placement"] = bad
		if ConfigValidator.validate_pickup(cfg).is_empty():
			m.append("accepted %s" % str(bad))
	return _result(m)


## Live (encounter context) and reload (durable pending result, JSON round trip) give the same tiles. The seed is
## above 2^53, so it only survives the reload as a String (D-66). The board keys come from the production
## `PendingResultService.capture_or_consume`; the held card actors come from the production `_project_actor`.
## The held card itself is hand-built: a full `build_round_snapshot` needs a combat state (too heavy here).
static func _t_snapshot_tiles() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = PickupSnapshotTests._event("C1")["ctx"]
	var ectx := EncounterContext.new()
	ectx.encounter_id = "enc.test"
	ectx.placement_seed = 9007199254740993
	ectx.terrain = { "bounds": { "w": 7, "h": 5 }, "cells": [] }
	ectx.actors = [
		{ "id": "e0", "name": "Echo 0", "stats": { "max_hp": 10 }, "current_hp": 6, "faction": "echo",
			"grid_pos": { "col": 5, "row": 4 }, "is_dead": false },
		{ "id": "e1", "name": "Echo 1", "stats": { "max_hp": 10 }, "current_hp": 8, "faction": "echo",
			"grid_pos": { "col": 0, "row": 0 }, "is_dead": false },
		{ "id": "x0", "name": "Enemy", "stats": { "max_hp": 10 }, "current_hp": 0, "faction": "enemy",
			"grid_pos": { "col": 3, "row": 2 }, "is_dead": true }]
	ctx.encounter_ctx = ectx
	ctx.save_data["flow"] = { "state": "flow.splash", "context": {}, "pending_result": {} }
	ectx.final_snapshot = { "type": FlowStateIds.RESOLVE, "meta": { "t": 9 }, "actions": {}, "data": {
		"encounter_id": "enc.test", "victory": true, "objectives_remaining": 0, "reason": "", "round_ended": 3,
		"enemies_defeated": 2, "echoes_survived": 4, "objective_state": {},
		"actors": ectx.actors.map(func(a: Dictionary) -> Dictionary: return EncounterSnapshotBuilder._project_actor(a)) } }
	if PendingResultService.capture_or_consume(ctx, { "type": FlowStateIds.PICKUP }, 9) != "captured" \
			or str(PendingResultService.read(ctx.save_data).get("placement_seed", "")) != "9007199254740993":
		return { "ok": false, "error": "test setup: the pending result holds no board keys" }
	var live: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	for r: Dictionary in live["row"]:
		if not (r.get("tile") is Dictionary) or not (r["tile"] as Dictionary).has("col") or not (r["tile"] as Dictionary).has("row"):
			m.append("row entry without a tile: %s" % str(r))
	var i := 0
	for f: Dictionary in live["finds"]:
		if not (f.get("tile") is Dictionary) or int(f["cell"]) != i:
			m.append("find row tile or cell wrong: %s" % str(f))
		i += 1
	if (live["finds"] as Array).is_empty() or (live["row"] as Array).size() < 2 or int(live["placement_seed"]) != 9007199254740993:
		m.append("test setup: finds %d, row %d, seed %s" % [(live["finds"] as Array).size(), (live["row"] as Array).size(), live["placement_seed"]])
	ctx.encounter_ctx = null
	PickupSnapshotTests._json_trip(ctx)
	ctx.last_snapshot = {}
	var back: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if int(back["placement_seed"]) != 9007199254740993 or (back["actors"] as Array).size() != 3:
		m.append("reload seed %s, actors %d" % [back["placement_seed"], (back["actors"] as Array).size()])
	var tile_of: Callable = func(r: Dictionary) -> Dictionary: return r["tile"]
	if str((live["row"] as Array).map(tile_of)) != str((back["row"] as Array).map(tile_of)):
		m.append("row tiles differ after a reload")
	if str((live["finds"] as Array).map(tile_of)) != str((back["finds"] as Array).map(tile_of)):
		m.append("find tiles differ after a reload")
	return _result(m)
