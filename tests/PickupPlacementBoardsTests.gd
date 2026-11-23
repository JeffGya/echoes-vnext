# res://tests/PickupPlacementBoardsTests.gd
# Robustness of PickupPlacement on real seeded combat terrain (StageTerrain.generate with the shipping realm 1 courage
# and realm 2 wisdom signatures) for the square sizes 10, 20, 30 and 50 plus the real stretched size 140x28.
# One pass builds every case; each registered test asserts one property over all cases. Registered from
# PickupSnapshotTests.register, so the suite name is `pickup_snapshot`.
# Set PICKUP_BOARDS_REPORT=1 in the environment to print the per-size tables (lines start with `PBOARD`).
# Set PICKUP_BOARDS_ONLY="10x10;140x28" to build only those sizes. A filter that matches no size fails the `total` test.

class_name PickupPlacementBoardsTests
extends RefCounted

const _SQUARE := [10, 20, 30, 50]
# The real stretched size: a 28 square with GUIDE_SPIRIT x5 on one axis. [cols, rows, stretch].
const _REAL := [[140, 28, 5.0]]
const _VIRTUES := ["courage", "wisdom"]
const _SEEDS := [1013, 2027, 3041, 4057, 5071, 6089, 7103, 8123]
const _TILE := Vector2(128, 64)
const _VIEWS := [Vector2(1280, 720), Vector2(1920, 1080)]
const _ECHO_BAR := 88.0
const _PAD := 16.0
const _ZOOM_MAX := 2.2
const _ZOOM_DEFAULT := 1.3

static var _cache: Dictionary = {}


static func register(runner: CoreTestRunner) -> void:
	for p: String in ["total", "in_bounds_walkable_region", "distinct_echoes", "finds_off_row", "finds_distinct",
			"row_shape", "deterministic", "builder_equals_place", "camera_is_valid"]:
		runner.register_test("pickup_snapshot/boards_%s_on_real_islands_10_to_50" % p,
			Callable(PickupPlacementBoardsTests, "_t_" + p))


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m.slice(0, 6)) + (" ... +%d more" % (m.size() - 6) if m.size() > 6 else "") }


static func _t_total() -> Dictionary: return _result(_data()["total"])
static func _t_in_bounds_walkable_region() -> Dictionary: return _result(_data()["region"])
static func _t_distinct_echoes() -> Dictionary: return _result(_data()["distinct"])
static func _t_finds_off_row() -> Dictionary: return _result(_data()["off_row"])
static func _t_finds_distinct() -> Dictionary: return _result(_data()["finds_distinct"])
static func _t_row_shape() -> Dictionary: return _result(_data()["shape"])
static func _t_deterministic() -> Dictionary: return _result(_data()["determinism"])
static func _t_builder_equals_place() -> Dictionary: return _result(_data()["builder"])
static func _t_camera_is_valid() -> Dictionary: return _result(_data()["camera"])


static func _data() -> Dictionary:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func _k(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _v(d: Variant) -> Vector2i:
	return Vector2i(int((d as Dictionary)["col"]), int((d as Dictionary)["row"]))


## Same average as PickupPlacement._average (integer, rounds up at half).
static func _centre(cells: Array) -> Vector2i:
	var n := cells.size()
	var sc := 0
	var sr := 0
	for c: Vector2i in cells:
		sc += c.x
		sr += c.y
	@warning_ignore("integer_division")
	return Vector2i((sc + n / 2) / n, (sr + n / 2) / n)


## Screen position of a tile centre (DIAMOND_RIGHT, vertical offset): col step (+64,-32), row step (+64,+32).
static func _px(c: Vector2i) -> Vector2:
	return Vector2(64.0 * (c.x + c.y), 32.0 * (c.y - c.x))


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	@warning_ignore("integer_division")
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else (float(s[s.size() / 2 - 1]) + float(s[s.size() / 2])) / 2.0


static func _is_straight(tiles: Array) -> bool:
	var same_row := true
	var same_col := true
	for i in range(1, tiles.size()):
		var a: Vector2i = tiles[i - 1]
		var b: Vector2i = tiles[i]
		same_row = same_row and a.y == b.y and b.x - a.x == 1
		same_col = same_col and a.x == b.x and b.y - a.y == 1
	return tiles.size() >= 1 and (same_row or same_col or tiles.size() == 1)


static func _connected(tiles: Array) -> bool:
	if tiles.is_empty():
		return true
	var seen := { _k(tiles[0]): true }
	var stack: Array = [tiles[0]]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for t: Vector2i in tiles:
			if not seen.has(_k(t)) and _cheb(c, t) == 1:
				seen[_k(t)] = true
				stack.append(t)
	return seen.size() == tiles.size()


static func _build() -> Dictionary:
	var out := { "total": [], "region": [], "distinct": [], "off_row": [], "finds_distinct": [], "shape": [],
		"determinism": [], "builder": [], "camera": [], "stats": {}, "report": [] }
	var shipping := ConfigService.new()
	shipping.load_balance()
	var inv := ConfigService.get_inventory_cfg(shipping)
	var stages_cfg: Dictionary = ConfigService.get_balance_data(shipping).get("stages", {})
	var cfg := PickupPlacement.settings(inv)
	var sizes: Array = []
	for s: int in _SQUARE:
		sizes.append([s, s, 1.0])
	for r: Array in _REAL:
		sizes.append(r)
	for sz: Array in sizes:
		var cols := int(sz[0])
		var rows := int(sz[1])
		var label := "%dx%d" % [cols, rows]
		var only := OS.get_environment("PICKUP_BOARDS_ONLY")
		if only != "" and not (";" + only + ";").contains(";" + label + ";"):
			continue
		var t_size := Time.get_ticks_msec()
		var st: Dictionary = out["stats"].get(label, { "cases": 0, "calls": 0, "straight": 0, "chain": 0, "own": 0,
			"row_dist": [], "finds": 0, "fallback_finds": 0, "max_ms": 0.0, "walk": [], "region": [], "islands": [],
			"zoom": [[], []], "fit": [0, 0], "fit_margin": [0, 0], "camcases": [0, 0], "at_min_zoom": [0, 0] })
		for vi_ in _VIRTUES.size():
			var virtue: String = _VIRTUES[vi_]
			var sig := EncounterSetupService.scale_signature_for_stretch(
				RealmGenerator._resolve_terrain_signature({ "virtue": virtue }, stages_cfg), float(sz[2]))
			for si in range(vi_, _SEEDS.size(), _VIRTUES.size()):
				var rs: int = _SEEDS[si]
				var terrain := StageTerrain.generate(rs, si % 3, sig, { "w": cols, "h": rows },
					"combat.terrain.boards_%s_%s_%d" % [label, virtue, rs])
				var tb: Dictionary = terrain.get("bounds", {})
				if int(tb.get("w", -1)) != cols or int(tb.get("h", -1)) != rows:
					out["region"].append("%s %s %d: generator bounds %s, want %dx%d" % [label, virtue, rs, str(tb), cols, rows])
				var walk := StageTerrain.walkable_set(terrain)
				var region := GridService.largest_walkable_region(walk, { "w": cols, "h": rows })
				var rcells: Array = []
				for k: String in region:
					var p := k.split(",")
					rcells.append(Vector2i(int(p[0]), int(p[1])))
				rcells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
				st["walk"].append(walk.size())
				st["region"].append(region.size())
				st["islands"].append((terrain.get("islands", []) as Array).size())
				var plan: Array = [[5, 1], [5, 2], [5, 3], [5, 4], [5, 5], [5, 6]]
				if si <= 1:
					plan.append_array([[1, 3], [3, 3]])
				for pl: Array in plan:
					_one_case(out, st, cfg, inv, terrain, walk, region, rcells, cols, rows, label, virtue, rs, int(pl[0]), int(pl[1]))
				st["cases"] += 1
		out["stats"][label] = st
		if OS.get_environment("PICKUP_BOARDS_REPORT") != "":
			print("PBOARD built %s in %d ms" % [label, Time.get_ticks_msec() - t_size])
	if (out["stats"] as Dictionary).is_empty():
		out["total"].append("PICKUP_BOARDS_ONLY '%s' matched no board size" % OS.get_environment("PICKUP_BOARDS_ONLY"))
	_report(out, sizes)
	return out


static func _one_case(out: Dictionary, st: Dictionary, cfg: Dictionary, inv: Dictionary, terrain: Dictionary,
		walk: Dictionary, region: Dictionary, rcells: Array, cols: int, rows: int, label: String, virtue: String,
		rs: int, n: int, f: int) -> void:
	var tag := "%s %s seed=%d n=%d f=%d" % [label, virtue, rs, n, f]
	if rcells.size() < n:
		out["region"].append("%s: region has only %d cells" % [tag, rcells.size()])
		return
	var sit := "s%d" % (rs % 7)
	var run_count := 1 + (rs % 3)
	var pseed := PickupPlacement.hash_of([rs, label, virtue])
	# Echoes: n distinct cells chosen by hash from the left third of the region (fight-end cells), enemies from the right.
	var scored: Array = []
	for c: Vector2i in rcells:
		scored.append([PickupPlacement.hash_of([pseed, "echo", c.x, c.y]), c.x, c.y])
	scored.sort()
	@warning_ignore("integer_division")
	var third := maxi(rcells.size() / 3, n)
	var left_cells: Array = rcells.slice(0, third)
	var cand: Array = []
	for c: Vector2i in left_cells:
		cand.append([PickupPlacement.hash_of([pseed, "echo", c.x, c.y]), c.x, c.y])
	cand.sort()
	var actors: Array = []
	var row_ids: Array = []
	for i in n:
		var id := "echo_%d" % i
		row_ids.append(id)
		actors.append({ "id": id, "grid_pos": { "col": int(cand[i][1]), "row": int(cand[i][2]) } })
	for j in 3:
		var c: Vector2i = rcells[rcells.size() - 1 - j]
		actors.append({ "id": "enemy_%d" % j, "grid_pos": { "col": c.x, "row": c.y } })
	var find_ids: Array = []
	for i in f:
		find_ids.append("find_%d" % i)

	var data := { "terrain": terrain.duplicate(true), "board_cols": cols, "board_rows": rows, "placement_seed": pseed,
		"situation_id": sit, "run_count": run_count, "actors": actors.duplicate(true),
		"row": row_ids.map(func(id: String) -> Dictionary: return { "id": id }),
		"finds": find_ids.map(func(id: String) -> Dictionary: return { "find_id": id }) }
	var t0 := Time.get_ticks_usec()
	PickupSnapshotBuilder._add_tiles(data, inv)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	st["calls"] += 1
	st["max_ms"] = maxf(st["max_ms"], ms)
	var check_direct := f == 6 or n != 5
	var placed: Dictionary = {}
	if check_direct:
		placed = PickupPlacement.place(terrain, cols, rows, pseed, sit, run_count, actors, row_ids, find_ids, inv)
	var row_tiles: Array = []
	var find_tiles: Array = []
	for r: Dictionary in data["row"]:
		row_tiles.append(_v(r["tile"]))
		if check_direct and _v((placed["row"] as Dictionary)[str(r["id"])]) != _v(r["tile"]):
			out["builder"].append("%s: row %s builder != place" % [tag, r["id"]])
	for fd: Dictionary in data["finds"]:
		find_tiles.append(_v(fd["tile"]))
		if check_direct and _v((placed["finds"] as Dictionary)[str(fd["find_id"])]) != _v(fd["tile"]):
			out["builder"].append("%s: find %s builder != place" % [tag, fd["find_id"]])
	if not check_direct:
		placed = { "row": {}, "finds": {} }
		for i in n:
			placed["row"][row_ids[i]] = { "col": row_tiles[i].x, "row": row_tiles[i].y }
		for i in f:
			placed["finds"][find_ids[i]] = { "col": find_tiles[i].x, "row": find_tiles[i].y }

	# total
	if row_tiles.size() != n or find_tiles.size() != f:
		out["total"].append("%s: %d row tiles, %d find tiles" % [tag, row_tiles.size(), find_tiles.size()])
	for r: Dictionary in data["row"]:
		if not (r.get("tile") is Dictionary):
			out["total"].append("%s: no row tile for %s" % [tag, r["id"]])
	for fd: Dictionary in data["finds"]:
		if not (fd.get("tile") is Dictionary):
			out["total"].append("%s: no find tile for %s" % [tag, fd["find_id"]])
	# in bounds, walkable, largest region
	for t: Vector2i in row_tiles + find_tiles:
		if t.x < 0 or t.y < 0 or t.x >= cols or t.y >= rows:
			out["region"].append("%s: tile %s out of bounds" % [tag, str(t)])
		elif not walk.has(_k(t)):
			out["region"].append("%s: tile %s is void" % [tag, str(t)])
		elif not region.has(_k(t)):
			out["region"].append("%s: tile %s outside the largest region" % [tag, str(t)])
	# own-tile fallback legitimately keeps own cells: distinctness holds there as well because the Echo cells differ
	var seen := {}
	for t: Vector2i in row_tiles:
		if seen.has(_k(t)):
			out["distinct"].append("%s: two Echoes on %s" % [tag, str(t)])
		seen[_k(t)] = true
	var row_set := seen
	var free_exists := region.size() > row_set.size()
	if free_exists:
		for t: Vector2i in find_tiles:
			if row_set.has(_k(t)):
				out["off_row"].append("%s: find on row tile %s" % [tag, str(t)])
	var fseen := {}
	var dup := false
	for t: Vector2i in find_tiles:
		dup = dup or fseen.has(_k(t))
		fseen[_k(t)] = true
	if dup and region.size() - row_set.size() >= f:
		out["finds_distinct"].append("%s: finds share a tile, free tiles %d" % [tag, region.size() - row_set.size()])
	# row shape
	var shape := "own"
	var own_ok := true
	for i in n:
		own_ok = own_ok and row_tiles[i] == Vector2i(int(actors[i]["grid_pos"]["col"]), int(actors[i]["grid_pos"]["row"]))
	if _is_straight(row_tiles):
		shape = "straight"
	elif _connected(row_tiles):
		shape = "chain"
	elif not own_ok:
		out["shape"].append("%s: row is neither straight, connected, nor the own tiles: %s" % [tag, str(row_tiles)])
	st[shape] += 1
	# distance of the row centre to the shifted anchor, and the find band
	@warning_ignore("integer_division")
	var anchor := Vector2i(clampi(cols / 2 + int(cfg["entry_offset"]["col"]), 0, cols - 1),
		clampi(rows / 2 + int(cfg["entry_offset"]["row"]), 0, rows - 1))
	var centre := _centre(row_tiles)
	st["row_dist"].append(_cheb(centre, anchor))
	for t: Vector2i in find_tiles:
		var d := _cheb(t, centre)
		st["finds"] += 1
		if d < int(cfg["near"]) or d > int(cfg["far"]):
			st["fallback_finds"] += 1
	# determinism
	if check_direct:
		var again := PickupPlacement.place(terrain, cols, rows, pseed, sit, run_count, actors, row_ids, find_ids, inv)
		if JSON.stringify(again) != JSON.stringify(placed):
			out["determinism"].append("%s: second call differs" % tag)
	# camera, only for the 5-Echo 6-find case (the widest spread)
	if n == 5 and f == 6:
		_camera(out, st, tag, row_tiles + find_tiles, cols, rows)


static func _camera(out: Dictionary, st: Dictionary, tag: String, cells: Array, cols: int, rows: int) -> void:
	var pts := PackedVector2Array()
	for c: Vector2i in cells:
		pts.append(_px(c))
	var span_x := 64.0 * (cols + rows - 2) + 128.0
	var span_y := 32.0 * (cols + rows - 2) + 64.0
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	box = box.grow_individual(_TILE.x * 0.5, _TILE.y * 0.5, _TILE.x * 0.5, _TILE.y * 0.5)
	for vi in _VIEWS.size():
		var view: Vector2 = _VIEWS[vi]
		var min_zoom := clampf(minf(view.x, view.y) / maxf(span_x, span_y) * 0.90, 0.05, 0.35)
		var usable := Rect2(_PAD, _PAD, view.x - 2.0 * _PAD, view.y - _PAD - _ECHO_BAR - _PAD)
		var fr := PickupCameraFrame.frame(pts, _TILE, view, usable, _ZOOM_DEFAULT, min_zoom, _ZOOM_MAX, 0.75, 48.0)
		if not bool(fr["valid"]) or not is_finite(float(fr["zoom"])) or float(fr["zoom"]) < min_zoom - 0.0001 \
				or float(fr["zoom"]) > _ZOOM_MAX + 0.0001:
			out["camera"].append("%s view %s: frame %s (min_zoom %.3f)" % [tag, str(view), str(fr), min_zoom])
			continue
		var z := float(fr["zoom"])
		st["camcases"][vi] += 1
		st["zoom"][vi].append(z)
		if box.size.x * z <= usable.size.x + 0.001 and box.size.y * z <= usable.size.y + 0.001:
			st["fit"][vi] += 1
		if box.size.x * z <= usable.size.x - 96.0 + 0.001 and box.size.y * z <= usable.size.y - 96.0 + 0.001:
			st["fit_margin"][vi] += 1
		if absf(z - min_zoom) < 0.0001:
			st["at_min_zoom"][vi] += 1


static func _report(out: Dictionary, sizes: Array) -> void:
	if OS.get_environment("PICKUP_BOARDS_REPORT") == "":
		return
	print("PBOARD size | cases calls | straight chain own | row_dist median max | finds fallback | max_ms | walk(min/med) region(min/med) islands(med)")
	for sz: Array in sizes:
		var l := "%dx%d" % [int(sz[0]), int(sz[1])]
		if not out["stats"].has(l):
			continue
		var s: Dictionary = out["stats"][l]
		print("PBOARD %s | %d %d | %d %d %d | %.1f %d | %d %d | %.1f | %d/%d %d/%d %d" % [l, s["cases"], s["calls"], s["straight"],
			s["chain"], s["own"], _median(s["row_dist"]), (s["row_dist"] as Array).max(), s["finds"], s["fallback_finds"],
			s["max_ms"], (s["walk"] as Array).min(), _median(s["walk"]), (s["region"] as Array).min(), _median(s["region"]),
			_median(s["islands"])])
	print("PBOARD camera: size | view | median zoom, min zoom | fit usable | fit usable-margin | at min zoom | cases")
	for sz: Array in sizes:
		var l := "%dx%d" % [int(sz[0]), int(sz[1])]
		if not out["stats"].has(l):
			continue
		var s: Dictionary = out["stats"][l]
		for vi in 2:
			var zs: Array = s["zoom"][vi]
			if zs.is_empty():
				continue
			print("PBOARD cam %s | %s | %.3f %.3f | %d | %d | %d | %d" % [l, str(_VIEWS[vi]), _median(zs), zs.min(),
				s["fit"][vi], s["fit_margin"][vi], s["at_min_zoom"][vi], s["camcases"][vi]])
