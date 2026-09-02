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
#                  GridService.largest_walkable_region use. A diagonal is legal unless
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
#
# V2-COMBAT-003 terrain commit 3 EXTENDED it, keeping every commit-2 column intact, to
# answer the three acceptance questions for the island rewrite:
#   * the ISLAND SIZE DISTRIBUTION per virtue, in buckets — the goal is 4-and-up with an
#     even spread upward, against the measured 819-of-865 single cells before the change;
#   * TOUCHING ISLANDS — an island cell adjacent in ANY of the 8 directions to a cell that
#     is not its own. This MUST be zero; a corner touch is the ambiguity being removed;
#   * CUT-OFF REGIONS OF >= 6 CELLS AMONG PLATEAUS AND BRIDGES ONLY — commit 2's guarantee,
#     which islands are outside of by design, so it is measured on the stripped set.
# It also counts boards whose explore ENTRY CELL lands off the host region, because
# StageTerrain.entry_cell picks the leftmost walkable column and an island may own it.
# The combat bounds now include the DOUBLED shapes (12x48 PURSUE, 60x12 GUIDE_SPIRIT) that
# section 12.8 found the commit-2 builder had excluded.

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
	# The DOUBLED combat shapes. PURSUE doubles rows, GUIDE_SPIRIT doubles columns
	# (ANSWERS.md #122). Section 12.8 recorded that the commit-2 builder measured
	# 12x12..22x22 only and therefore excluded exactly the shapes where the largest splits
	# were originally found. They are part of the combat regime here.
	combat_bounds.append({ "w": 12, "h": 48 })
	combat_bounds.append({ "w": 60, "h": 12 })

	# Explore-map bounds. RealmGenerator._generate_explore_map draws width/height in
	# [30..45] (StageExploreModel.MIN_WIDTH/HEIGHT plus the config span) with a +2 bump per
	# stage index. The explore screen and the venture screen both render THIS terrain, so
	# it must be measured too — the combat board is only one of the two consumers.
	var explore_bounds: Array = []
	for c2 in range(11):
		explore_bounds.append({ "w": 30 + c2 * 2, "h": 30 + c2 })

	var virtues: Array = by_virtue.keys()
	virtues.sort()

	_measure("COMBAT BOARD (%dx%d .. %dx%d plus the doubled 12x48 and 60x12, data.combat.board)"
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
	# V2-COMBAT-003 terrain commit 3 accumulators.
	var isl_hist: Dictionary = {}       # virtue -> bucket label -> count
	var isl_total: Dictionary = {}      # virtue -> island count
	var isl_min: Dictionary = {}
	var isl_max: Dictionary = {}
	var isl_sum: Dictionary = {}
	var touch_violations: Array = []
	var repair_violations: Array = []
	var entry_off_host: int = 0
	var entry_examples: Array = []
	# Proxy for RealmGenerator._place_situations, which places a situation on ANY walkable
	# cell. The fraction of walkable cells lying off the host region IS the probability a
	# uniformly-placed situation — including a stage OBJECTIVE — lands somewhere the party
	# cannot reach. Measured here because it is a consequence of commit 3 that commit 3
	# does not fix; commit 5 owns host-region placement.
	var off_host_cells: int = 0
	var all_cells: int = 0

	# ── V2-COMBAT-003 terrain commit 5 ───────────────────────────────────────
	# The two real placement paths, driven through their production entry points.
	#
	# EXPLORE — RealmGenerator._place_situations, called with the same arguments
	# _generate_explore_map passes it. Counted: situations landing off the host region, and
	# OBJECTIVE situations whose eight neighbours are not all walkable (decision 24).
	#
	# COMBAT — the two-call pattern every objective spawn in EncounterObjectiveSpawnService
	# uses: GridService.collect_unoccupied_cells over the walkable set minus the actors
	# place_actors already positioned, then GridService.place_on_terrain with a depth-scaled
	# target column. Reproduced here, not re-invented: the same functions, the same order.
	var sit_total: int = 0
	var sit_off_host: int = 0
	var sit_obj_total: int = 0
	var sit_obj_off_host: int = 0
	var sit_obj_no_clearance: int = 0
	var sit_examples: Array = []
	var cmb_obj_total: int = 0
	var cmb_obj_off_host: int = 0
	var cmb_obj_no_clearance: int = 0
	var cmb_examples: Array = []
	# Rule 25 — how often the generator had to BUILD an objective site, per virtue.
	var built_sites: Dictionary = {}
	# Do the two host rules agree? StageTerrain (and entry_cell) judge regions by SHARED
	# SIDE; GridService judges them by legal-edge. A cell of the shared-side host that is
	# NOT in the legal-edge host would mean the two authorities disagree about the board.
	var host_rule_disagree: int = 0

	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}

		var boards: int = 0
		var bad_ss: int = 0
		var bad_le: int = 0
		var max_cut: int = 0
		var region_total: int = 0
		isl_hist[virtue] = {}
		isl_total[virtue] = 0
		isl_min[virtue] = 999999
		isl_max[virtue] = 0
		isl_sum[virtue] = 0
		built_sites[virtue] = 0

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

			# ---- V2-COMBAT-003 terrain commit 3 measurements ----
			var islands_v: Variant = terrain.get("islands", [])
			var islands: Array = islands_v if islands_v is Array else []
			for isl_v in islands:
				var isl: Dictionary = isl_v if isl_v is Dictionary else {}
				var own: Dictionary = {}
				for pr_v in (isl.get("cells", []) as Array):
					var pr: Array = pr_v
					own["%d,%d" % [int(pr[0]), int(pr[1])]] = true
				var sz2: int = own.size()
				isl_total[virtue] = int(isl_total[virtue]) + 1
				isl_sum[virtue] = int(isl_sum[virtue]) + sz2
				isl_min[virtue] = mini(int(isl_min[virtue]), sz2)
				isl_max[virtue] = maxi(int(isl_max[virtue]), sz2)
				var lbl: String = _size_bucket(sz2)
				(isl_hist[virtue] as Dictionary)[lbl] = int((isl_hist[virtue] as Dictionary).get(lbl, 0)) + 1
				# THE MOAT. Every 8-direction neighbour of every island cell must be either
				# this island's own cell or void. One hit here is the whole finding.
				for own_k in own.keys():
					var op := (own_k as String).split(",")
					var oc: int = int(op[0])
					var orow: int = int(op[1])
					for dc2 in range(-1, 2):
						for dr2 in range(-1, 2):
							if dc2 == 0 and dr2 == 0:
								continue
							var nk2: String = "%d,%d" % [oc + dc2, orow + dr2]
							if own.has(nk2):
								continue
							if walkable.has(nk2):
								touch_violations.append(
									"    TOUCH %s #%d bounds=%dx%d island cell %s touches foreign walkable %s"
									% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)), own_k, nk2])

			# Commit 2's guarantee, measured on the geometry the repair actually governs:
			# plateaus plus bridges. Islands are minted after the repair by design.
			var stripped: Dictionary = terrain.duplicate(true)
			stripped["islands"] = []
			stripped["stragglers"] = []
			var pb_walkable: Dictionary = StageTerrain.walkable_set(stripped)
			var pb_regions: Array = _regions_shared_side(pb_walkable)
			var pb_host: int = _host_index(pb_regions)
			for pri in range(pb_regions.size()):
				if pri == pb_host:
					continue
				if (pb_regions[pri] as Array).size() >= REPORT_MIN_REGION:
					repair_violations.append(
						"    REPAIR %s #%d bounds=%dx%d cut-off plateau/bridge region of %d cells"
						% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)),
							(pb_regions[pri] as Array).size()])

			# Explore entry cell: StageTerrain.entry_cell takes the LEFTMOST walkable
			# column, and after commit 3 an island may own it. Measured, not assumed.
			var entry: Dictionary = StageTerrain.entry_cell(walkable, bounds)
			var entry_key: String = "%d,%d" % [int(entry.get("col", -1)), int(entry.get("row", -1))]

			var ss: Array = _regions_shared_side(walkable)
			region_total += ss.size()
			var ss_host: int = _host_index(ss)
			if ss_host >= 0 and not (ss[ss_host] as Array).has(entry_key):
				entry_off_host += 1
				if entry_examples.size() < 6:
					entry_examples.append("    ENTRY %s #%d bounds=%dx%d entry=%s is OFF the host region"
						% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)), entry_key])
			all_cells += walkable.size()
			if ss_host >= 0:
				off_host_cells += walkable.size() - (ss[ss_host] as Array).size()
			# ---- V2-COMBAT-003 terrain commit 5 measurements ----
			var host_set: Dictionary = {}
			if ss_host >= 0:
				for hk in (ss[ss_host] as Array):
					host_set[hk] = true
			if terrain.has("objective_site_built"):
				built_sites[virtue] = int(built_sites.get(virtue, 0)) + 1

			# EXPLORE — the real situation placer.
			var sit_objectives: Array = [
				{ "type": "shrine" }, { "type": "recover" },
			]
			var sits: Array = RealmGenerator._place_situations(
				realm_seed, stage_index, int(bounds.get("w", 0)), int(bounds.get("h", 0)),
				5, 2, sit_objectives, {}, walkable)
			for s_v in sits:
				var sd: Dictionary = s_v if s_v is Dictionary else {}
				var sp: Dictionary = sd.get("pos", {}) as Dictionary
				var sk: String = "%d,%d" % [int(sp.get("col", -1)), int(sp.get("row", -1))]
				sit_total += 1
				var s_off: bool = not host_set.has(sk)
				if s_off:
					sit_off_host += 1
				if bool(sd.get("is_objective", false)):
					sit_obj_total += 1
					if s_off:
						sit_obj_off_host += 1
					if not _has_clearance(sk, walkable, {}):
						sit_obj_no_clearance += 1
					if (s_off or not _has_clearance(sk, walkable, {})) and sit_examples.size() < 8:
						sit_examples.append(
							"    SIT %s #%d bounds=%dx%d objective at %s off_host=%s clearance=%s"
							% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)), sk,
								str(s_off), str(_has_clearance(sk, walkable, {}))])

			# COMBAT — the objective-spawn placement pattern.
			var cmb_cell: Dictionary = _probe_combat_objective(walkable, bounds)
			if not cmb_cell.is_empty():
				var ck: String = "%d,%d" % [int(cmb_cell.get("col", -1)), int(cmb_cell.get("row", -1))]
				cmb_obj_total += 1
				var c_off: bool = not host_set.has(ck)
				if c_off:
					cmb_obj_off_host += 1
				var c_clear: bool = _has_clearance(ck, walkable, cmb_cell.get("occupied", {}))
				if not c_clear:
					cmb_obj_no_clearance += 1
				if (c_off or not c_clear) and cmb_examples.size() < 8:
					cmb_examples.append(
						"    CMBOBJ %s #%d bounds=%dx%d cell=%s off_host=%s clearance=%s"
						% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)), ck,
							str(c_off), str(c_clear)])

			# Host-rule agreement between StageTerrain (shared side) and GridService (legal edge).
			var le_host_set: Dictionary = GridService.largest_walkable_region(walkable, bounds)
			var disagree: bool = false
			for hk2 in host_set.keys():
				if not le_host_set.has(hk2):
					disagree = true
					break
			if disagree:
				host_rule_disagree += 1

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

	# ── V2-COMBAT-003 terrain commit 3 ───────────────────────────────────────
	_say("")
	_say("ISLAND SIZE DISTRIBUTION per virtue (deliberate islands, terrain[\"islands\"]):")
	_say("%-14s | %7s | %5s | %5s | %6s | %s" % ["virtue", "islands", "min", "max", "mean", "buckets 4-5/6-10/11-25/26-50/51+"])
	_say("---------------+---------+-------+-------+--------+---------------------------------")
	var grand: int = 0
	var grand_buckets: Dictionary = {}
	for virtue_v2 in virtues:
		var v2: String = str(virtue_v2)
		var n2: int = int(isl_total.get(v2, 0))
		grand += n2
		var hist: Dictionary = isl_hist.get(v2, {})
		var parts2: Array = []
		for lbl2 in _BUCKETS:
			var cnt: int = int(hist.get(lbl2, 0))
			grand_buckets[lbl2] = int(grand_buckets.get(lbl2, 0)) + cnt
			parts2.append("%s:%d" % [lbl2, cnt])
		_say("%-14s | %7d | %5d | %5d | %6.1f | %s" % [
			v2, n2,
			0 if n2 == 0 else int(isl_min.get(v2, 0)),
			int(isl_max.get(v2, 0)),
			0.0 if n2 == 0 else float(int(isl_sum.get(v2, 0))) / float(n2),
			" ".join(PackedStringArray(parts2))])
	var gparts: Array = []
	for lbl3 in _BUCKETS:
		gparts.append("%s:%d" % [lbl3, int(grand_buckets.get(lbl3, 0))])
	_say("---------------+---------+-------+-------+--------+---------------------------------")
	_say("%-14s | %7d | %5s | %5s | %6s | %s" % ["TOTAL", grand, "", "", "", " ".join(PackedStringArray(gparts))])
	_say("  (an island below 4 cells is impossible by construction — the generator discards it)")

	_say("")
	_say("MOAT — island cells touching ANY foreign walkable cell at a side OR a corner: %d" % touch_violations.size())
	_say("  MUST BE ZERO. A corner touch is the ambiguity terrain commit 3 removes.")
	for tv in touch_violations.slice(0, 20):
		_say(str(tv))

	_say("")
	_say("COMMIT 2 GUARANTEE — cut-off PLATEAU/BRIDGE regions of >= %d cells: %d" % [REPORT_MIN_REGION, repair_violations.size()])
	_say("  Measured on the stripped set: islands are minted AFTER the repair by design.")
	for rv in repair_violations.slice(0, 20):
		_say(str(rv))

	_say("")
	_say("EXPLORE ENTRY CELL off the host region: %d of %d boards" % [entry_off_host, tot_boards])
	for ev in entry_examples:
		_say(str(ev))

	_say("")
	_say("SITUATION PLACEMENT EXPOSURE — walkable cells lying OFF the host region: %d of %d (%.1f%%)"
		% [off_host_cells, all_cells, 100.0 * float(off_host_cells) / float(max(all_cells, 1))])
	_say("  RealmGenerator._place_situations places a situation on ANY walkable cell, so this")
	_say("  is the per-situation probability of landing somewhere unreachable, OBJECTIVES")
	_say("  INCLUDED. Terrain commit 3 raises it and does NOT fix it — commit 5 owns")
	_say("  host-region placement (handoff decisions 22-25).")

	# ── V2-COMBAT-003 terrain commit 5 ───────────────────────────────────────
	_say("")
	_say("SITUATION PLACEMENT, MEASURED — RealmGenerator._place_situations on every board:")
	_say("  situations placed                     : %d" % sit_total)
	_say("  ... OFF the host region               : %d  (MUST BE ZERO)" % sit_off_host)
	_say("  objective situations                  : %d" % sit_obj_total)
	_say("  ... OFF the host region               : %d  (MUST BE ZERO)" % sit_obj_off_host)
	_say("  ... without 8 walkable neighbours     : %d  (MUST BE ZERO)" % sit_obj_no_clearance)
	for sv in sit_examples:
		_say(str(sv))

	_say("")
	_say("COMBAT OBJECTIVE PLACEMENT, MEASURED — place_actors then collect_unoccupied_cells")
	_say("then place_on_terrain, the EncounterObjectiveSpawnService pattern:")
	_say("  objectives placed                     : %d" % cmb_obj_total)
	_say("  ... OFF the host region               : %d  (MUST BE ZERO)" % cmb_obj_off_host)
	_say("  ... without 8 walkable free neighbours: %d" % cmb_obj_no_clearance)
	for cv in cmb_examples:
		_say(str(cv))

	_say("")
	_say("RULE 25 — boards where the generator BUILT an objective site, per virtue:")
	var built_total: int = 0
	for bv in virtues:
		var bvs: String = str(bv)
		var bn: int = int(built_sites.get(bvs, 0))
		built_total += bn
		_say("  %-14s : %d of %d" % [bvs, bn, BOARDS_PER_VIRTUE])
	_say("  %-14s : %d of %d" % ["TOTAL", built_total, tot_boards])
	_say("  Not a failure. A realm that fires often has island sizes that are wrong.")

	_say("")
	_say("HOST RULE AGREEMENT — boards where a shared-side host cell is NOT in the")
	_say("legal-edge host (StageTerrain vs GridService disagree): %d of %d" % [host_rule_disagree, tot_boards])


# ── V2-COMBAT-003 terrain commit 5 helpers ───────────────────────────────────

## Decision 24: a static objective needs all EIGHT neighbouring tiles walkable and free.
## `occupied` is the actor occupancy set on the combat path and empty on the explore path,
## where nothing but other situations stands on the board.
static func _has_clearance(key: String, walkable: Dictionary, occupied: Dictionary) -> bool:
	var parts := (key as String).split(",")
	if parts.size() != 2:
		return false
	var c: int = int(parts[0])
	var r: int = int(parts[1])
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var nk: String = "%d,%d" % [c + dc, r + dr]
			if not walkable.has(nk):
				return false
			if occupied.has(nk):
				return false
	return true


## Reproduces one objective spawn exactly as EncounterObjectiveSpawnService performs it:
## place six actors per faction with GridService.place_actors, build the occupancy set,
## collect the unoccupied walkable cells, then rank them by a depth-scaled target column.
## Returns { col, row, occupied } — `occupied` so the caller can judge clearance against
## the same board state the real spawn sees.
static func _probe_combat_objective(walkable: Dictionary, bounds: Dictionary) -> Dictionary:
	var cols: int = int(bounds.get("w", 0))
	var rows: int = int(bounds.get("h", 0))
	var board_cfg: Dictionary = {
		"board_cols": cols, "board_rows": rows, "walkable": walkable,
	}
	var echoes: Array = []
	var enemies: Array = []
	for k in range(4):
		echoes.append(_probe_actor("echo_%d" % k))
		enemies.append(_probe_actor("enemy_%d" % k))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	GridService.place_actors(echoes, enemies, board_cfg, rng, {})
	var occupied: Dictionary = GridService.occupied_cells([echoes, enemies])
	# Mirrors the production call sites after V2-COMBAT-003 terrain commit 5: host region
	# on collect_unoccupied_cells, clearance context on place_on_terrain.
	var region: Dictionary = GridService.largest_walkable_region(walkable, bounds)
	var candidates: Array = GridService.collect_unoccupied_cells(walkable, occupied, region)
	if candidates.is_empty():
		return {}
	var col_range: Dictionary = GridService.candidate_column_range(candidates)
	# Depth fraction 0.35 — EncounterObjectiveSpawnService._depth_fraction at completion 0.
	var target_col: int = roundi(
		float(col_range["min_col"]) + 0.35 * float(int(col_range["max_col"]) - int(col_range["min_col"])))
	var mid_row: float = float(rows - 1) * 0.5
	var cell: Dictionary = GridService.place_on_terrain(
		candidates, float(target_col), mid_row, GridService.PLACE_METRIC_AXIS,
		{ "walkable": walkable, "occupied": occupied })
	if cell.is_empty():
		return {}
	return { "col": int(cell["col"]), "row": int(cell["row"]), "occupied": occupied }


static func _probe_actor(id: String) -> Dictionary:
	var a: Dictionary = ActorSchema.get_defaults()
	a["id"] = id
	a["name"] = id
	a["stats"] = { "max_hp": 100, "atk": 5, "def": 3, "agi": 3, "int": 3, "cha": 2 }
	a["speed"] = 3
	a["archetype_birth"] = "brave"
	a["calling_origin"] = "blade"
	a["traits"] = { "courage": 40, "faith": 30, "wisdom": 30 }
	a["vector_scores"] = { "vanguard": 50, "protector": 20, "seeker": 20, "pillar": 10 }
	return a


const _BUCKETS: Array = ["1", "2-3", "4-5", "6-10", "11-25", "26-50", "51+"]

static func _size_bucket(n: int) -> String:
	if n == 1:
		return "1"
	if n <= 3:
		return "2-3"
	if n <= 5:
		return "4-5"
	if n <= 10:
		return "6-10"
	if n <= 25:
		return "11-25"
	if n <= 50:
		return "26-50"
	return "51+"


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
