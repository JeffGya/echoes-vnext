# res://tools/StretchBoardProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests stretchprobe`.
#
# Question (follow-up #14): do stretched GUIDE_SPIRIT / PURSUE boards have far less walkable
# ground than the same virtue has on a normal board?
#
# Drives StageTerrain.generate directly (docs/LESSONS.md #17) with signatures read from the raw
# balance.json. Virtue keys come from data.stages.map_shape.by_virtue, plus "default".
# Scenario A: 18x18 baseline. B: 18x90 and 90x18, signature unchanged.
# C: same boards, plateau_count_min/max multiplied by the long multiplier, on a COPY.
# Measures only. Writes no save file, asserts nothing.

class_name StretchBoardProbe
extends RefCounted


const SEEDS_PER_SCENARIO: int = 50
const BASE_DIM: int = 18
const LONG_MULT: float = 5.0  # data.combat.board.guide_spirit_override.long_multiplier


static func register(runner) -> void:
	runner.register_test("stretch_board_probe/run", func(): return run_all())


static func run_all() -> Dictionary:
	var balance: Dictionary = _load_balance()
	var map_shape: Dictionary = (((balance.get("data", {}) as Dictionary).get("stages", {}) as Dictionary)
		.get("map_shape", {}) as Dictionary)
	var by_virtue: Dictionary = map_shape.get("by_virtue", {}) as Dictionary
	if by_virtue.is_empty():
		print("STRETCH PROBE: data.stages.map_shape.by_virtue is empty - wrong config path.")
		return { "ok": true }
	var mult: float = float((((((balance.get("data", {}) as Dictionary).get("combat", {}) as Dictionary)
		.get("board", {}) as Dictionary).get("guide_spirit_override", {}) as Dictionary)
		.get("long_multiplier", LONG_MULT)))
	var sigs: Dictionary = {}
	for v in by_virtue.keys():
		sigs[str(v)] = by_virtue[v]
	sigs["default"] = map_shape.get("default", {})
	var names: Array = sigs.keys()
	names.sort()

	print("STRETCH PROBE: %d seeds per cell, multiplier %.1f, virtues: %s" % [SEEDS_PER_SCENARIO, mult, ", ".join(names)])
	var plan: Array = [
		["A  18x18 baseline", BASE_DIM, BASE_DIM, false],
		["B  18x90 tall, signature unchanged", BASE_DIM, int(BASE_DIM * mult), false],
		["B  90x18 wide, signature unchanged", int(BASE_DIM * mult), BASE_DIM, false],
		["C  18x90 tall, plateau count x%.1f" % mult, BASE_DIM, int(BASE_DIM * mult), true],
		["C  90x18 wide, plateau count x%.1f" % mult, int(BASE_DIM * mult), BASE_DIM, true],
	]
	for entry in plan:
		_run_scenario(str(entry[0]), int(entry[1]), int(entry[2]), bool(entry[3]), mult, names, sigs)
	return { "ok": true }


static func _run_scenario(label: String, w: int, h: int, scale_count: bool, mult: float,
		names: Array, sigs: Dictionary) -> void:
	print("")
	print("== %s  (%dx%d, area %d) ==" % [label, w, h, w * h])
	print("%-12s | %-22s | %-9s | %-14s | %-14s | %-12s" % [
		"virtue", "walkable share m/min/max", "plateaus", "regions m/max", "largest share", "empty run m/max"])
	for name in names:
		var sig: Dictionary = (sigs[name] as Dictionary).duplicate(true)
		if scale_count:
			sig["plateau_count_min"] = int(round(float(sig.get("plateau_count_min", 3)) * mult))
			sig["plateau_count_max"] = int(round(float(sig.get("plateau_count_max", 5)) * mult))
		var shares: Array = []
		var plat: Array = []
		var regs: Array = []
		var largest: Array = []
		var runs: Array = []
		for i in range(SEEDS_PER_SCENARIO):
			var seed_v: int = 3000000 + i * 7919
			var terrain: Dictionary = StageTerrain.generate(seed_v, i % 3, sig, { "w": w, "h": h },
				"combat.terrain.stretchprobe_%s_%d" % [name, i])
			var walk: Dictionary = StageTerrain.walkable_set(terrain)
			shares.append(float(walk.size()) / float(w * h))
			plat.append((terrain.get("plateaus", []) as Array).size())
			var info: Dictionary = _regions(walk)
			regs.append(int(info["count"]))
			largest.append(float(info["largest"]) / float(maxi(walk.size(), 1)))
			runs.append(_empty_run(walk, w, h))
		print("%-12s | %5.1f%% %5.1f%% %5.1f%%    | %4.1f %2d-%-2d | %5.1f %3d      | %5.1f%% (min %5.1f%%) | %5.1f %3d" % [
			name, _mean(shares) * 100.0, _min_f(shares) * 100.0, _max_f(shares) * 100.0,
			_mean(plat), _min_f(plat), _max_f(plat),
			_mean(regs), int(_max_f(regs)),
			_mean(largest) * 100.0, _min_f(largest) * 100.0,
			_mean(runs), int(_max_f(runs))])


## Shared-side flood fill. Returns { count, largest }.
static func _regions(walk: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var count: int = 0
	var largest: int = 0
	var deltas: Array = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	for start in walk.keys():
		if seen.has(start):
			continue
		count += 1
		var queue: Array = [start]
		seen[start] = true
		var head: int = 0
		while head < queue.size():
			var parts: PackedStringArray = (queue[head] as String).split(",")
			head += 1
			var c: int = int(parts[0])
			var r: int = int(parts[1])
			for d in deltas:
				var nk: String = "%d,%d" % [c + int(d[0]), r + int(d[1])]
				if walk.has(nk) and not seen.has(nk):
					seen[nk] = true
					queue.append(nk)
		largest = maxi(largest, queue.size())
	return { "count": count, "largest": largest }


## Longest run of consecutive lines with no walkable cell along the long axis
## (rows when the board is tall or square, columns when it is wide).
static func _empty_run(walk: Dictionary, w: int, h: int) -> int:
	var along_cols: bool = w > h
	var n: int = w if along_cols else h
	var filled: Dictionary = {}
	for k in walk.keys():
		var parts: PackedStringArray = (k as String).split(",")
		filled[int(parts[0]) if along_cols else int(parts[1])] = true
	var best: int = 0
	var cur: int = 0
	for i in range(n):
		if filled.has(i):
			cur = 0
		else:
			cur += 1
			best = maxi(best, cur)
	return best


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


static func _min_f(a: Array) -> float:
	var m: float = float(a[0])
	for v in a:
		m = minf(m, float(v))
	return m


static func _max_f(a: Array) -> float:
	var m: float = float(a[0])
	for v in a:
		m = maxf(m, float(v))
	return m


static func _load_balance() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}
