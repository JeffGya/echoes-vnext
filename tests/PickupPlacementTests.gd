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
	runner.register_test("pickup_snapshot/placement_anchor_ignores_the_fight_cells", Callable(PickupPlacementTests, "_t_anchor_ignores_cells"))
	runner.register_test("pickup_snapshot/placement_anchor_outside_region_or_board_stays_total", Callable(PickupPlacementTests, "_t_anchor_outside"))
	runner.register_test("pickup_snapshot/placement_hash_is_pinned_and_the_ui_hash_calls_it", Callable(PickupPlacementTests, "_t_hash_equal"))
	runner.register_test("pickup_snapshot/placement_constants_come_from_config", Callable(PickupPlacementTests, "_t_config"))
	runner.register_test("pickup_snapshot/camera_frame_defaults_clamps_and_config", Callable(PickupPlacementTests, "_t_camera_config"))
	runner.register_test("pickup_snapshot/camera_frame_validator_accepts_shipping_and_rejects_bad", Callable(PickupPlacementTests, "_t_camera_validator"))
	runner.register_test("pickup_snapshot/camera_frame_is_in_the_snapshot_live_and_after_reload", Callable(PickupPlacementTests, "_t_camera_snapshot"))
	runner.register_test("pickup_snapshot/placement_config_validator_accepts_shipping_and_rejects_bad", Callable(PickupPlacementTests, "_t_validator"))
	runner.register_test("pickup_snapshot/placement_tiles_in_the_snapshot_are_live_equal_to_reload", Callable(PickupPlacementTests, "_t_snapshot_tiles"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _a(id: String, col: int, row: int) -> Dictionary:
	return { "id": id, "grid_pos": { "col": col, "row": row } }


static func _cfg(near: int = 2, far: int = 3, spacing: int = 2, entry_col: int = -2, entry_row: int = 0) -> Dictionary:
	return { "pickup": { "placement": { "near": near, "far": far, "spacing": spacing,
		"entry_offset": { "col": entry_col, "row": entry_row } } } }


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


## Hand-derived. Anchor = board centre + entry_offset (-2, 0), so 7 x 5 gives (3,2) + (-2,0) = (1,2) and 10 x 10 gives
## (5,5) + (-2,0) = (3,5). A line is scored by the Chebyshev distance of its doubled centre to twice the anchor.
## n = 3, 7 x 5, doubled anchor (2,4): axis 0 start (c,r) has centre (2c+2, 2r), so (0,2) scores 0; axis 1 start
## (c,r) has centre (2c, 2r+2), so (1,1) scores 0. No other line scores 0. The hash of [seed, sit, run, axis, col, row]
## picks between the two; the test computes both hashes with `hash_of`. 10 x 10 (doubled anchor (6,10)): axis 0
## start (2,5) and axis 1 start (3,4). The Echo fight cells are scattered on purpose: they play no part.
static func _t_worked_row() -> Dictionary:
	var m: Array = []
	var echoes := [_a("e0", 6, 4), _a("e1", 0, 0), _a("e2", 3, 3)]
	var ids := ["e0", "e1", "e2"]
	# 7 x 5: the two distance-0 lines are axis 0 start (0,2) and axis 1 start (1,1).
	var r: Dictionary = _run(echoes, ids, [])["row"]
	var horizontal := PickupPlacement.hash_of([_SEED, _SIT, _RUN, 0, 0, 2]) <= PickupPlacement.hash_of([_SEED, _SIT, _RUN, 1, 1, 1])
	var want := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)] if horizontal else [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	for i in 3:
		if _t(r[ids[i]]) != want[i]:
			m.append("7x5: %s at %s, want %s" % [ids[i], str(r[ids[i]]), str(want[i])])
	# 10 x 10: anchor (3,5); axis 0 start (2,5) and axis 1 start (3,4).
	var r2: Dictionary = _run(echoes, ids, [], {}, 10, 10)["row"]
	var horizontal2 := PickupPlacement.hash_of([_SEED, _SIT, _RUN, 0, 2, 5]) <= PickupPlacement.hash_of([_SEED, _SIT, _RUN, 1, 3, 4])
	var want2 := [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)] if horizontal2 else [Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)]
	for i in 3:
		if _t(r2[ids[i]]) != want2[i]:
			m.append("10x10: %s at %s, want %s" % [ids[i], str(r2[ids[i]]), str(want2[i])])
	# The hash, not the axis, decides: find a seed whose axis 1 hash is lower and expect the vertical line (7 x 5).
	var vertical_seen := false
	for sd in 60:
		if PickupPlacement.hash_of([sd, _SIT, _RUN, 1, 1, 1]) < PickupPlacement.hash_of([sd, _SIT, _RUN, 0, 0, 2]):
			vertical_seen = true
			var o: Dictionary = PickupPlacement.place({}, 7, 5, sd, _SIT, _RUN, echoes, ids, [], _cfg())["row"]
			if _t(o["e0"]) != Vector2i(1, 1) or _t(o["e2"]) != Vector2i(1, 3):
				m.append("seed %d: axis 1 hash is lower but the row is %s" % [sd, str(o)])
	if not vertical_seen:
		m.append("test setup: no seed in 0..59 prefers axis 1")
	var one: Dictionary = _run([_a("e0", 6, 4)], ["e0"], [])["row"]
	if _t(one["e0"]) != Vector2i(1, 2):
		m.append("n = 1 at %s, want the anchor (1,2)" % str(one["e0"]))
	return _result(m)


## Hand-worked band. One Echo, 7 x 5: the row tile and the row centre are the anchor (1,2). Chebyshev distance 2..3
## from (1,2): cols 3 and 4 on every row (10 tiles: 2 and 3 away) plus cols 0..2 on rows 0 and 4 (6 tiles, 2 away on
## the row axis) = 16. Cols 5 and 6 are 4 and 5 away. Rows 1..3 on cols 0..2 are within 1.
static func _t_worked_find() -> Dictionary:
	var m: Array = []
	var cand: Array = []
	for c in [3, 4]:
		for r in 5:
			cand.append(Vector2i(c, r))
	for c in [0, 1, 2]:
		for r in [0, 4]:
			cand.append(Vector2i(c, r))
	if cand.size() != 16:
		m.append("hand list has %d tiles, want 16" % cand.size())
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
	if got != Vector2i(1, 4):
		m.append("golden find tile is %s, pinned (1,4)" % str(got))
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
	# 3 x 1 board, Echoes on (0,0) and (1,0), entry offset (+1, 0): the anchor is (2,0), the row moves to (1,0) (2,0),
	# and the old start tile (0,0) is the one tile left: the find must lie there.
	var o := _run([_a("e0", 0, 0), _a("e1", 1, 0)], ["e0", "e1"], ["f0"], {}, 3, 1, _cfg(0, 5, 1, 1, 0))
	if _t(o["row"]["e0"]) != Vector2i(1, 0) or _t(o["finds"]["f0"]) != Vector2i(0, 0):
		m.append("row %s, find %s; want the row on (1,0) (2,0) and the find on the old start tile (0,0)" % [str(o["row"]), str(o["finds"])])
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
	# 2 x 2 board: the anchor (1,1) + (-2,0) clamps to (0,1), which is the row tile; 3 non-row tiles. Five finds: 3 distinct tiles, then the pile reuses a taken tile.
	var out := _run([_a("e0", 0, 0)], ["e0"], _ids("f", 5), {}, 2, 2)
	var tiles := {}
	for fid in out["finds"]:
		var t := _t(out["finds"][fid])
		tiles[str(t)] = true
		if t == Vector2i(0, 1) or t.x > 1 or t.y > 1:
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
	# No Echo has a cell. The anchor never used cells, so the row is the one an Echo with a cell would get: anchor
	# (1,2) on 7 x 5, a pair of touching tiles within distance 1 of it.
	var out := _run([], ["a", "b"], ["f0"])
	var ra := _t(out["row"]["a"])
	var rb := _t(out["row"]["b"])
	var step := rb - ra
	if _cheb(ra, Vector2i(1, 2)) > 1 or _cheb(rb, Vector2i(1, 2)) > 1 or (step != Vector2i(1, 0) and step != Vector2i(0, 1)):
		m.append("row of two without cells: %s %s" % [str(ra), str(rb)])
	if not (out["finds"] as Dictionary).has("f0"):
		m.append("no find tile")
	if str(out["row"]) != str(_run([_a("a", 6, 4), _a("b", 0, 0)], ["a", "b"], ["f0"])["row"]):
		m.append("the row depends on the Echo cells")
	return _result(m)


static func _t_anchor_ignores_cells() -> Dictionary:
	var m: Array = []
	var ids := ["e0", "e1", "e2"]
	var near_centre := [_a("e0", 3, 2), _a("e1", 3, 3), _a("e2", 2, 2), _a("x", 5, 1)]
	var far_corners := [_a("e0", 6, 4), _a("e1", 0, 0), _a("e2", 6, 0), _a("x", 1, 1)]
	var a := _run(near_centre, ids, ["f0", "f1"])
	var b := _run(far_corners, ids, ["f0", "f1"])
	if str(a) != str(b):
		m.append("the fight cells change the result: %s / %s" % [str(a), str(b)])
	return _result(m)


## An offset that leaves the board is clamped into the board rectangle; an anchor on void is handled by the nearest line.
static func _t_anchor_outside() -> Dictionary:
	var m: Array = []
	var ids := ["e0", "e1", "e2"]
	var echoes := [_a("e0", 1, 1), _a("e1", 2, 1), _a("e2", 3, 1)]
	for eo in [Vector2i(-50, -50), Vector2i(50, 50), Vector2i(-50, 50), Vector2i(0, 0)]:
		for board in [[7, 5], [3, 3], [2, 9]]:
			var cfg := _cfg(2, 3, 2, eo.x, eo.y)
			var out := _run(echoes, ids, ["f0", "f1"], {}, board[0], board[1], cfg)
			for t_v: Variant in (out["row"] as Dictionary).values() + (out["finds"] as Dictionary).values():
				var t := _t(t_v)
				if t.x < 0 or t.y < 0 or t.x >= board[0] or t.y >= board[1]:
					m.append("offset %s board %s: tile %s is off the board" % [str(eo), str(board), str(t)])
			if (out["row"] as Dictionary).size() != 3 or (out["finds"] as Dictionary).size() != 2:
				m.append("offset %s board %s: a tile is missing" % [str(eo), str(board)])
	# A 1 x 1 board holds no row of 3: the Echoes keep their tiles, and every tile still exists.
	var tiny := _run(echoes, ids, ["f0", "f1"], {}, 1, 1)
	if (tiny["row"] as Dictionary).size() != 3 or (tiny["finds"] as Dictionary).size() != 2:
		m.append("1 x 1 board: a tile is missing %s" % str(tiny))
	# Anchor (clamped) on a void tile: the terrain keeps one far column; the row is still found.
	var column := { "bounds": { "w": 7, "h": 5 }, "plateaus": [{ "col": 6, "row": 0, "w": 1, "h": 5, "cells": [[6, 0], [6, 1], [6, 2], [6, 3], [6, 4]] }] }
	var out2 := _run(echoes, ids, ["f0"], column, 7, 5)
	for t_v: Variant in (out2["row"] as Dictionary).values():
		if _t(t_v).x != 6:
			m.append("row left the only region: %s" % str(t_v))
	return _result(m)


static func _t_hash_equal() -> Dictionary:
	var m: Array = []
	# One implementation: the UI helper calls the core one. Fixed values pin the FNV-1a result (computed by hand, outside Godot).
	var pinned: Array = [[["a"], 1678518572], [["a", 2, 3], 361284839], [[], 2166136261], [[[1, 2], "b"], 998078772]]
	for row: Array in pinned:
		var got := PickupPlacement.hash_of(row[0])
		var ui := PickupEventPlan.hash_of(row[0])
		if got != int(row[1]) or ui != got:
			m.append("%s: core %d, ui %d, want %d" % [str(row[0]), got, ui, int(row[1])])
	return _result(m)


static func _t_config() -> Dictionary:
	var m: Array = []
	var d := PickupPlacement.settings({})
	if d != { "near": 2, "far": 3, "spacing": 2, "entry_offset": { "col": -2, "row": 0 } }:
		m.append("missing keys read %s, want 2, 3, 2, -2/0" % str(d))
	var shipping := ConfigService.new()
	shipping.load_balance()
	var inv := ConfigService.get_inventory_cfg(shipping)
	if PickupPlacement.settings(inv) != { "near": 2, "far": 3, "spacing": 2, "entry_offset": { "col": -2, "row": 0 } }:
		m.append("shipping config reads %s" % str(PickupPlacement.settings(inv)))
	if PickupPlacement.settings(_cfg(0, 0, 0)) != { "near": 0, "far": 0, "spacing": 1, "entry_offset": { "col": -2, "row": 0 } }:
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
	# Entry offset: moving it moves the row tile (n = 1: the anchor itself, board centre (8,8) + offset).
	for eo in [Vector2i(-2, 0), Vector2i(0, 3), Vector2i(4, -1)]:
		var at := _t(_run(actors, ["e0"], [], {}, 17, 17, _cfg(2, 3, 2, eo.x, eo.y))["row"]["e0"])
		if at != Vector2i(8, 8) + eo:
			m.append("entry_offset %s put the row at %s" % [str(eo), str(at)])
	var wide := _run(actors, ["e0"], ids, {}, 17, 17, _cfg(4, 6, 2))
	for d2: Dictionary in (wide["finds"] as Dictionary).values():
		var dist := _cheb(_t(d2), Vector2i(6, 8))
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
			{ "near": 1.5, "far": 3, "spacing": 2 }, {}, { "near": 2, "far": 3, "spacing": 2, "entry_offset": { "col": 1.5, "row": 0 } },
			{ "near": 2, "far": 3, "spacing": 2, "entry_offset": { "col": 1 } }]:
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


static func _cam(zoom: Variant, margin: Variant, secs: Variant) -> Dictionary:
	return { "pickup": { "camera": { "floor_zoom": zoom, "margin_px": margin, "tween_seconds": secs } } }


static func _t_camera_config() -> Dictionary:
	var m: Array = []
	var want := { "floor_zoom": 0.75, "margin_px": 48.0, "tween_seconds": 0.45 }
	if PickupSnapshotBuilder.camera_frame({}) != want or PickupSnapshotBuilder.camera_frame({ "pickup": {} }) != want:
		m.append("a missing block reads %s, want %s" % [str(PickupSnapshotBuilder.camera_frame({})), str(want)])
	var shipping := ConfigService.new()
	shipping.load_balance()
	if PickupSnapshotBuilder.camera_frame(ConfigService.get_inventory_cfg(shipping)) != want:
		m.append("shipping config reads %s" % str(PickupSnapshotBuilder.camera_frame(ConfigService.get_inventory_cfg(shipping))))
	if PickupSnapshotBuilder.camera_frame(_cam(1.5, 20, 0.2)) != { "floor_zoom": 1.5, "margin_px": 20.0, "tween_seconds": 0.2 }:
		m.append("config values are not read: %s" % str(PickupSnapshotBuilder.camera_frame(_cam(1.5, 20, 0.2))))
	if PickupSnapshotBuilder.camera_frame(_cam(0.0, -5, -1)) != { "floor_zoom": 0.05, "margin_px": 0.0, "tween_seconds": 0.0 } \
			or float(PickupSnapshotBuilder.camera_frame(_cam(9.0, 1, 1))["floor_zoom"]) != 2.2:
		m.append("clamps are wrong")
	return _result(m)


static func _t_camera_validator() -> Dictionary:
	var m: Array = []
	var shipping := ConfigService.new()
	shipping.load_balance()
	var inv := ConfigService.get_inventory_cfg(shipping)
	if not ConfigValidator.validate_pickup(inv).is_empty():
		m.append("shipping config: %s" % str(ConfigValidator.validate_pickup(inv)))
	var base: Dictionary = (inv["pickup"] as Dictionary).duplicate(true)
	for bad in [_cam(0, 48, 0.45), _cam(-1.0, 48, 0.45), _cam("a", 48, 0.45), _cam(0.75, -1, 0.45), _cam(0.75, 48, -0.1), _cam(0.75, null, 0.45)]:
		var cfg := { "pickup": base.duplicate(true) }
		cfg["pickup"]["camera"] = (bad["pickup"] as Dictionary)["camera"]
		if ConfigValidator.validate_pickup(cfg).is_empty():
			m.append("accepted %s" % str(bad["pickup"]["camera"]))
	var good := { "pickup": base.duplicate(true) }
	good["pickup"]["camera"] = { "floor_zoom": 1, "margin_px": 0, "tween_seconds": 0 }
	if not ConfigValidator.validate_pickup(good).is_empty():
		m.append("rejected a valid camera block: %s" % str(ConfigValidator.validate_pickup(good)))
	var none := { "pickup": base.duplicate(true) }
	none["pickup"].erase("camera")
	if not ConfigValidator.validate_pickup(none).is_empty():
		m.append("the camera block must stay optional")
	return _result(m)


## A changed config changes `data.camera_frame`, and a reload (no encounter context, JSON round trip) gives the same.
static func _t_camera_snapshot() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = PickupSnapshotTests._event("C1")["ctx"]
	var d0: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if d0.get("camera_frame") != { "floor_zoom": 0.75, "margin_px": 48.0, "tween_seconds": 0.45 }:
		m.append("default camera_frame %s" % str(d0.get("camera_frame")))
	var inv: Dictionary = ctx.config_service.get("inv")
	inv["pickup"] = { "camera": { "floor_zoom": 1.25, "margin_px": 30, "tween_seconds": 0.1 } }
	var d1: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if d1.get("camera_frame") != { "floor_zoom": 1.25, "margin_px": 30.0, "tween_seconds": 0.1 }:
		m.append("a config change did not reach the snapshot: %s" % str(d1.get("camera_frame")))
	ctx.encounter_ctx = null
	PickupSnapshotTests._json_trip(ctx)
	ctx.last_snapshot = {}
	var d2: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if str(d2.get("camera_frame")) != str(d1.get("camera_frame")):
		m.append("after a reload %s, live %s" % [str(d2.get("camera_frame")), str(d1.get("camera_frame"))])
	return _result(m)
