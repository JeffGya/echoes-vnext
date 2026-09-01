# res://tools/TerrainRegionProbe.gd
#
# INVESTIGATION TOOL — not a test. Registered only under `-- tests terrainregionprobe`.
#
# Answers ONE question, for V2-COMBAT-003 terrain commit 2:
#
#   Across all ten virtue settings in data.stages.map_shape.by_virtue, how many generated
#   boards contain a CUT-OFF REGION of N or more cells?
#
# "Cut-off" is judged two ways, both computed on the SAME boards:
#
#   shared-side  — two walkable cells are in one region only when they share a full side
#                  (4-direction adjacency). This is the rule the generator's connectivity
#                  repair uses after commit 2. It is deliberately STRICTER than the
#                  movement layer, so anything it calls connected is certainly traversable.
#   legal-edge   — StageTerrain.legal_neighbors, i.e. exactly what the movement layer and
#                  GridService._largest_walkable_region use. A diagonal is legal unless
#                  BOTH orthogonal side cells are solid. This is the rule that decides
#                  whether an actor can really walk off the ground it stands on.
#
# The host region is the largest region, ties broken by the numerically lowest (col,row)
# cell — the same tie-break GridService uses to pick the placement region. Every other
# region is "cut off".
#
# The probe MEASURES ONLY. It calls StageTerrain.generate and StageTerrain.walkable_set —
# the exact production entry points — with signatures read from the real balance.json
# through ConfigService, and with combat-board bounds taken from data.combat.board. It
# mutates nothing, writes no save, and asserts nothing.
#
# Run it on the tree BEFORE a generator change and again AFTER, and diff the two tables.

class_name TerrainRegionProbe
extends RefCounted


const REPORT_PATH := "user://terrain_region_probe_report.txt"
static var _sink: FileAccess = null

## Boards generated per virtue. 10 virtues x 180 = 1,800 boards, matching the sample size
## of the measurement recorded in docs/v2-combat-003-handoff.md section 12.1.
const BOARDS_PER_VIRTUE: int = 180

## The size at or above which a cut-off region is a defect rather than deliberate scenery.
## Mirrors the `connect_min_region_cells` terrain-signature default.
const REPORT_MIN_REGION: int = 6


## Boards printed in full detail regardless of outcome, so one concrete board can be
## compared line-for-line across a generator change. Entries are [virtue, index, regime].
const DEMO_BOARDS: Array = [
	["humility", 39, "combat"],
	["acceptance", 24, "explore"],
]

static var _flagged: Array = []


static func register(runner) -> void:
	runner.register_test("terrain_region_probe/run", func(): return run_all())


static func _say(line: String) -> void:
	print(line)
	if _sink != null:
		_sink.store_line(line)
		_sink.flush()


# ── Adjacency rules ──────────────────────────────────────────────────────────

## Regions under the shared-side rule (orthogonal only, no diagonals).
static func _regions_shared_side(walkable: Dictionary) -> Array:
	var keys: Array = walkable.keys()
	keys.sort()
	var visited: Dictionary = {}
	var regions: Array = []
	var deltas: Array = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	for start_key in keys:
		if visited.has(start_key):
			continue
		var region: Array = []
		var queue: Array = [start_key]
		visited[start_key] = true
		var head: int = 0
		while head < queue.size():
			var cur: String = queue[head]
			head += 1
			region.append(cur)
			var parts := (cur as String).split(",")
			var cc: int = int(parts[0])
			var cr: int = int(parts[1])
			for d_v in deltas:
				var d: Array = d_v
				var nk: String = "%d,%d" % [cc + int(d[0]), cr + int(d[1])]
				if walkable.has(nk) and not visited.has(nk):
					visited[nk] = true
					queue.append(nk)
		regions.append(region)
	return regions


## Regions under StageTerrain.legal_neighbors — the movement layer's own rule.
static func _regions_legal_edge(walkable: Dictionary, bounds: Dictionary) -> Array:
	var keys: Array = walkable.keys()
	keys.sort()
	var visited: Dictionary = {}
	var regions: Array = []
	for start_key in keys:
		if visited.has(start_key):
			continue
		var region: Array = []
		var queue: Array = [start_key]
		visited[start_key] = true
		var head: int = 0
		while head < queue.size():
			var cur: String = queue[head]
			head += 1
			region.append(cur)
			var parts := (cur as String).split(",")
			var cell: Dictionary = { "col": int(parts[0]), "row": int(parts[1]) }
			for n in StageTerrain.legal_neighbors(cell, walkable, bounds):
				var nk: String = "%d,%d" % [int(n.get("col", 0)), int(n.get("row", 0))]
				if not visited.has(nk):
					visited[nk] = true
					queue.append(nk)
		regions.append(region)
	return regions


## Index of the host region: largest, ties broken by numerically lowest (col,row).
static func _host_index(regions: Array) -> int:
	var best: int = -1
	for i in range(regions.size()):
		if best < 0:
			best = i
			continue
		var a: Array = regions[i]
		var b: Array = regions[best]
		if a.size() > b.size():
			best = i
		elif a.size() == b.size() and _key_less(_min_key(a), _min_key(b)):
			best = i
	return best


static func _min_key(keys: Array) -> String:
	var best: String = ""
	var have: bool = false
	for k in keys:
		if not have or _key_less(k, best):
			best = k
			have = true
	return best


static func _key_less(a: String, b: String) -> bool:
	var pa := (a as String).split(",")
	var pb := (b as String).split(",")
	var ac: int = int(pa[0])
	var ar: int = int(pa[1])
	var bc: int = int(pb[0])
	var br: int = int(pb[1])
	if ac != bc:
		return ac < bc
	return ar < br


# ── Driver ───────────────────────────────────────────────────────────────────

## Reads the raw balance.json off disk — same helper shape StageTerrainTests uses for its
## integration guards, so the probe exercises the real authored config, not a stub.
static func _load_balance() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

static func run_all() -> Dictionary:
	_sink = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_say("")
	_say("================================================================")
	_say(" TERRAIN REGION PROBE — cut-off regions per virtue (measure only)")
	_say("================================================================")

	var balance := _load_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var stages_v: Variant = data.get("stages", {})
	var stages_cfg: Dictionary = stages_v if stages_v is Dictionary else {}
	var map_shape_v: Variant = stages_cfg.get("map_shape", {})
	var map_shape: Dictionary = map_shape_v if map_shape_v is Dictionary else {}
	var by_virtue_v: Variant = map_shape.get("by_virtue", {})
	var by_virtue: Dictionary = by_virtue_v if by_virtue_v is Dictionary else {}
	if by_virtue.is_empty():
		_say("FAIL: data.stages.map_shape.by_virtue is empty — wrong config path.")
		return { "ok": false, "error": "map_shape.by_virtue empty" }

	# Combat-board bounds, straight out of data.combat.board: base 12x12, +1 per realm
	# completion, clamped to 22x22. The probe cycles the whole span.
	var combat_v: Variant = data.get("combat", {})
	var combat_cfg: Dictionary = combat_v if combat_v is Dictionary else {}
	var board_cfg_v: Variant = combat_cfg.get("board", {})
	var board_cfg: Dictionary = board_cfg_v if board_cfg_v is Dictionary else {}
	var base_cols: int = int(board_cfg.get("base_cols", 12))
	var base_rows: int = int(board_cfg.get("base_rows", 12))
	var max_cols: int = int(board_cfg.get("max_cols", 22))
	var max_rows: int = int(board_cfg.get("max_rows", 22))
	var growth: int = int(board_cfg.get("growth_per_completion", 1))

	var combat_bounds: Array = []
	for c in range(11):
		combat_bounds.append({
			"w": mini(base_cols + c * growth, max_cols),
			"h": mini(base_rows + c * growth, max_rows),
		})

	# Explore-map bounds. RealmGenerator._generate_explore_map draws width/height in
	# [30..45] (StageExploreModel.MIN_WIDTH/HEIGHT plus the config span) with a +2 bump per
	# stage index. The explore screen and the venture screen both render THIS terrain, so
	# it must be measured too — the combat board is only one of the two consumers.
	var explore_bounds: Array = []
	for c2 in range(11):
		explore_bounds.append({ "w": 30 + c2 * 2, "h": 30 + c2 })

	var virtues: Array = by_virtue.keys()
	virtues.sort()

	_measure("COMBAT BOARD (%dx%d .. %dx%d, data.combat.board)"
		% [base_cols, base_rows, max_cols, max_rows], "combat", virtues, by_virtue, combat_bounds)
	_measure("EXPLORE MAP (30x30 .. 50x40, RealmGenerator._generate_explore_map)",
		"explore", virtues, by_virtue, explore_bounds)

	_say("")
	_say("Done.")
	if _sink != null:
		_sink.close()
		_sink = null
	return { "ok": true }


## One measurement pass over every virtue for one family of board bounds.
static func _measure(regime: String, regime_tag: String, virtues: Array, by_virtue: Dictionary, bounds_cycle: Array) -> void:
	_flagged = []
	_say("")
	_say("----------------------------------------------------------------")
	_say(" %s" % regime)
	_say("----------------------------------------------------------------")
	_say("Boards per virtue: %d   min reported region: %d cells" % [BOARDS_PER_VIRTUE, REPORT_MIN_REGION])
	_say("")
	_say("%-14s | %6s | %10s | %10s | %9s | %9s" % [
		"virtue", "boards", "cutoff>=6", "cutoff>=6", "maxcut", "regions"])
	_say("%-14s | %6s | %10s | %10s | %9s | %9s" % [
		"", "", "sharedside", "legaledge", "cells", "avg"])
	_say("---------------+--------+------------+------------+-----------+----------")

	var tot_boards: int = 0
	var tot_ss: int = 0
	var tot_le: int = 0
	var size_hist: Dictionary = {}

	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}

		var boards: int = 0
		var bad_ss: int = 0
		var bad_le: int = 0
		var max_cut: int = 0
		var region_total: int = 0

		for i in range(BOARDS_PER_VIRTUE):
			var realm_seed: int = 1000000 + i * 7919
			var stage_index: int = i % 3
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, stage_index, sig, bounds,
				"probe.terrain.%s.%d" % [virtue, i]
			)
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			boards += 1

			var ss: Array = _regions_shared_side(walkable)
			region_total += ss.size()
			var ss_host: int = _host_index(ss)
			var ss_flag: bool = false
			for ri in range(ss.size()):
				if ri == ss_host:
					continue
				var sz: int = (ss[ri] as Array).size()
				size_hist[sz] = int(size_hist.get(sz, 0)) + 1
				if sz >= REPORT_MIN_REGION:
					ss_flag = true
					if sz > max_cut:
						max_cut = sz
			if ss_flag:
				bad_ss += 1
				_flagged.append("    %s #%d seed=%d stage=%d bounds=%dx%d bridges=%d regions=%s" % [
					virtue, i, realm_seed, stage_index, int(bounds.get("w", 0)), int(bounds.get("h", 0)),
					(terrain.get("bridges", []) as Array).size(), _region_sizes(ss)])

			# Demonstration boards — printed in full whether or not they are flagged, so the
			# same board can be compared line-for-line before and after a generator change.
			for demo_v in DEMO_BOARDS:
				var demo: Array = demo_v
				if str(demo[0]) == virtue and int(demo[1]) == i and str(demo[2]) == regime_tag:
					_say("  DEMO %s #%d seed=%d stage=%d bounds=%dx%d bridges=%d walkable=%d regions=%s" % [
						virtue, i, realm_seed, stage_index,
						int(bounds.get("w", 0)), int(bounds.get("h", 0)),
						(terrain.get("bridges", []) as Array).size(), walkable.size(), _region_sizes(ss)])

			var le: Array = _regions_legal_edge(walkable, bounds)
			var le_host: int = _host_index(le)
			var le_flag: bool = false
			for ri2 in range(le.size()):
				if ri2 == le_host:
					continue
				if (le[ri2] as Array).size() >= REPORT_MIN_REGION:
					le_flag = true
			if le_flag:
				bad_le += 1

		tot_boards += boards
		tot_ss += bad_ss
		tot_le += bad_le
		_say("%-14s | %6d | %10d | %10d | %9d | %9.2f" % [
			virtue, boards, bad_ss, bad_le, max_cut, float(region_total) / float(max(boards, 1))])

	_say("---------------+--------+------------+------------+-----------+----------")
	_say("%-14s | %6d | %10d | %10d |" % ["TOTAL", tot_boards, tot_ss, tot_le])
	_say("")
	_say("Cut-off region size histogram (shared-side rule, all virtues):")
	var buckets: Dictionary = { "1": 0, "2": 0, "3-5": 0, "6-10": 0, "11-25": 0, "26-50": 0, "51+": 0 }
	for s_v in size_hist.keys():
		var s: int = int(s_v)
		var n: int = int(size_hist[s_v])
		if s == 1:
			buckets["1"] += n
		elif s == 2:
			buckets["2"] += n
		elif s <= 5:
			buckets["3-5"] += n
		elif s <= 10:
			buckets["6-10"] += n
		elif s <= 25:
			buckets["11-25"] += n
		elif s <= 50:
			buckets["26-50"] += n
		else:
			buckets["51+"] += n
	for label in ["1", "2", "3-5", "6-10", "11-25", "26-50", "51+"]:
		_say("  %-7s : %d" % [label, int(buckets[label])])
	_say("")
	_say("Boards flagged with a cut-off region of >= %d cells (%d):" % [REPORT_MIN_REGION, _flagged.size()])
	for line in _flagged:
		_say(str(line))


## "hostsize + cut-off sizes" summary of one region list, host first.
static func _region_sizes(regions: Array) -> String:
	var host: int = _host_index(regions)
	var others: Array = []
	for i in range(regions.size()):
		if i == host:
			continue
		others.append((regions[i] as Array).size())
	others.sort()
	others.reverse()
	var host_size: int = 0 if host < 0 else (regions[host] as Array).size()
	return "host=%d cutoff=%s" % [host_size, str(others)]
