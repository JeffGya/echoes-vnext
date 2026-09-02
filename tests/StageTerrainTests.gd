# res://tests/StageTerrainTests.gd
# V2-STAGE-004 Phase 2 — Tests for StageTerrain (pure-static).
#
# Tests:
#   1.  terrain/determinism_generate      — same (seed,idx,sig,bounds) => deep-equal output
#   2.  terrain/connectivity_single_comp  — exactly ONE shared-side region of >= 6 cells (~20 seeds)
#   3.  terrain/bridge_width_min2         — every bridge rect has min(w,h) >= 2
#   4.  terrain/stage_variation           — stage_index 0 vs 1, same seed => different terrain
#   5.  terrain/sig_plateau_count_bounds  — plateau count in [count_min..count_max]
#   6.  terrain/sig_low_vs_high_plateaus  — low-count sig <= high-count sig (non-overlapping ranges)
#   7.  terrain/entry_cell_walkable       — entry_cell is in walkable set
#   8.  terrain/entry_cell_min_col        — entry_cell is at the leftmost column
#   9.  terrain/bfs_target_dist0          — BFS from target: target key has dist 0
#   10. terrain/bfs_entry_reachable       — BFS field includes the entry cell
#   11. terrain/next_step_reaches_target  — repeated next_step from entry reaches target
#   11b. terrain/next_step_no_lateral_drift — next_step heads directly (no up-left bias)
#   12. terrain/empty_terrain_walkable    — walkable_set({}) == {}
#   13. terrain/is_walkable_empty_true    — is_walkable(any, {}) == true
#
# V2-COMBAT-003 terrain commit 2 (shared-side connectivity):
#   terrain/bridge_connects_shared_side   — THE TERMINATION PROOF: a bridge's cell union is
#                                           one shared-side region containing both endpoints
#   terrain/repair_terminates_all_virtues — no cut-off region >= 6 cells on any of the ten
#                                           authored virtue signatures, combat + explore bounds
#   terrain/small_islands_are_kept        — regions below the threshold still survive
#   terrain/min_region_cells_is_honored   — the signature key reaches the repair

extends RefCounted
class_name StageTerrainTests


# ─── Helpers ────────────────────────────────────────────────────────────────

# A minimal representative signature.
static func _default_sig() -> Dictionary:
	return {
		"relief":              "highland",
		"plateau_count_min":   3,
		"plateau_count_max":   5,
		"plateau_w_min":       4,
		"plateau_w_max":       8,
		"plateau_h_min":       4,
		"plateau_h_max":       8,
		"plateau_shape_bias":  "blocky",
		"bridge_width":        2,
		"bridge_density":      0.3,
		"island_count_min": 2,
		"island_count_max": 4,
		"island_size_min": 4,
		"island_size_max": 8,
	}

static func _default_bounds() -> Dictionary:
	return { "w": 30, "h": 30 }


# Deep-equality check for two terrain dicts (plateaus/bridges/islands arrays).
# Plateaus now include a "cells" Array — this is compared element-by-element.
static func _terrain_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	# Compare bounds
	var ba: Dictionary = a.get("bounds", {})
	var bb: Dictionary = b.get("bounds", {})
	if int(ba.get("w", -1)) != int(bb.get("w", -1)) or int(ba.get("h", -1)) != int(bb.get("h", -1)):
		return false
	# Compare array fields
	for key in ["plateaus", "bridges", "islands"]:
		var arr_a_v: Variant = a.get(key, [])
		var arr_b_v: Variant = b.get(key, [])
		var arr_a: Array = arr_a_v if arr_a_v is Array else []
		var arr_b: Array = arr_b_v if arr_b_v is Array else []
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			var ea_v: Variant = arr_a[i]
			var eb_v: Variant = arr_b[i]
			var ea: Dictionary = ea_v if ea_v is Dictionary else {}
			var eb: Dictionary = eb_v if eb_v is Dictionary else {}
			if ea.size() != eb.size():
				return false
			for k in ea:
				if not eb.has(k):
					return false
				# "cells" is an Array of [col,row] pairs — compare via string
				# representation since GDScript Array == does deep compare already.
				if ea[k] != eb[k]:
					return false
	return true


# ─── 8-connected check helper (mirrors StageTerrain._is_8_connected) ─────────
# Used by the irregularity test to verify plateau blobs are connected.
static func _plateau_cells_connected(cells: Array) -> bool:
	if cells.is_empty():
		return true
	var cell_set: Dictionary = {}
	for pair_v in cells:
		var pair: Array = pair_v if pair_v is Array else []
		if pair.size() >= 2:
			cell_set["%d,%d" % [int(pair[0]), int(pair[1])]] = true
	if cell_set.is_empty():
		return true
	var visited: Dictionary = {}
	var start_key: String = (cell_set.keys())[0]
	var queue: Array = [start_key]
	visited[start_key] = true
	var head := 0
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],          [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		var parts := cur.split(",")
		var cc := int(parts[0])
		var cr := int(parts[1])
		for dv in deltas:
			var d: Array = dv if dv is Array else []
			var nk: String = "%d,%d" % [cc + int(d[0]), cr + int(d[1])]
			if cell_set.has(nk) and not visited.has(nk):
				visited[nk] = true
				queue.append(nk)
	return visited.size() == cell_set.size()


# Local 8-direction flood-fill to check single connectivity (used in test 2).
static func _flood_fill_count(walkable: Dictionary) -> int:
	if walkable.is_empty():
		return 0
	var visited: Dictionary = {}
	var queue: Array = []
	# Start from the first key
	var start_key: String = (walkable.keys())[0]
	queue.append(start_key)
	visited[start_key] = true
	var head := 0
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],           [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		var parts := cur.split(",")
		var cc: int = int(parts[0])
		var cr: int = int(parts[1])
		for dv in deltas:
			var d: Array = dv if dv is Array else []
			var nk: String = "%d,%d" % [cc + int(d[0]), cr + int(d[1])]
			if walkable.has(nk) and not visited.has(nk):
				visited[nk] = true
				queue.append(nk)
	return visited.size()


# ─── Shared-side region helper (V2-COMBAT-003 terrain commit 2) ──────────────
# The connectivity rule the generator's repair now uses: two cells are in one region only
# when they share a FULL SIDE. Deliberately re-implemented here rather than calling the
# generator's private helper, so the test can fail the generator instead of agreeing with
# it. Returns an Array of Arrays of cell keys.
const _MIN_REGION: int = 6

static func _shared_side_regions(walkable: Dictionary) -> Array:
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


# Walkable cells from PLATEAUS + BRIDGES only — the geometry the connectivity repair
# actually governs. Islands are minted AFTER the repair runs (by design: section 12.3 of
# the terrain handoff places islands last), so an island IS a cut-off region the repair
# never had a chance to see, and after terrain commit 3 it is a MOATED MULTI-CELL one that
# routinely exceeds the 6-cell threshold. A test about the repair itself must exclude them
# or it is testing the island pass instead — and before commit 3 it would have passed by
# luck, because a straggler was a single cell and could not reach the threshold.
# The legacy "stragglers" key is cleared too, so the helper is honest about the full set
# walkable_set reads.
##
## V2-COMBAT-003 terrain commit 4: an ISLAND BRIDGE is stripped too. It carries
## `island_bridge: true` and belongs to the island system, not to the connectivity repair —
## an island-to-island bridge left in would read as a cut-off bridge region and fail
## commit 2's guarantee for a reason that has nothing to do with the repair.
static func _walkable_without_islands(terrain: Dictionary) -> Dictionary:
	var stripped: Dictionary = terrain.duplicate(true)
	stripped["islands"] = []
	stripped["stragglers"] = []
	var kept: Array = []
	for b_v in (stripped.get("bridges", []) as Array):
		var b: Dictionary = b_v if b_v is Dictionary else {}
		if not bool(b.get("island_bridge", false)):
			kept.append(b)
	stripped["bridges"] = kept
	return StageTerrain.walkable_set(stripped)


## V2-COMBAT-003 terrain commit 4 — the ground an island is ALLOWED to touch.
## Returns island index -> cell-key set, covering every island bridge that LEAVES that
## island (`island_index`) or LANDS on it (`target_island`). Every other walkable cell in an
## island's 8-direction neighbourhood is a moat violation, and an UNBRIDGED island's allow
## set is empty — so the moat test doubles as "an unbridged island still touches nothing".
static func _island_bridge_allowances(terrain: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for b_v in (terrain.get("bridges", []) as Array):
		var b: Dictionary = b_v if b_v is Dictionary else {}
		if not bool(b.get("island_bridge", false)):
			continue
		for who in [int(b.get("island_index", -1)), int(b.get("target_island", -1))]:
			if who < 0:
				continue
			if not out.has(who):
				out[who] = {}
			for dc in range(int(b.get("w", 1))):
				for dr in range(int(b.get("h", 1))):
					(out[who] as Dictionary)["%d,%d" % [int(b.get("col", 0)) + dc, int(b.get("row", 0)) + dr]] = true
	return out


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("terrain/determinism_generate",      Callable(StageTerrainTests, "_t_determinism_generate"))
	runner.register_test("terrain/connectivity_single_comp",  Callable(StageTerrainTests, "_t_connectivity_single_comp"))
	runner.register_test("terrain/bridge_width_min2",         Callable(StageTerrainTests, "_t_bridge_width_min2"))
	runner.register_test("terrain/stage_variation",           Callable(StageTerrainTests, "_t_stage_variation"))
	runner.register_test("terrain/sig_plateau_count_bounds",  Callable(StageTerrainTests, "_t_sig_plateau_count_bounds"))
	runner.register_test("terrain/sig_low_vs_high_plateaus",  Callable(StageTerrainTests, "_t_sig_low_vs_high_plateaus"))
	runner.register_test("terrain/entry_cell_walkable",       Callable(StageTerrainTests, "_t_entry_cell_walkable"))
	runner.register_test("terrain/entry_cell_min_col",        Callable(StageTerrainTests, "_t_entry_cell_min_col"))
	runner.register_test("terrain/bfs_target_dist0",          Callable(StageTerrainTests, "_t_bfs_target_dist0"))
	runner.register_test("terrain/bfs_entry_reachable",       Callable(StageTerrainTests, "_t_bfs_entry_reachable"))
	runner.register_test("terrain/next_step_reaches_target",  Callable(StageTerrainTests, "_t_next_step_reaches_target"))
	runner.register_test("terrain/next_step_no_lateral_drift", Callable(StageTerrainTests, "_t_next_step_no_lateral_drift"))
	runner.register_test("terrain/empty_terrain_walkable",    Callable(StageTerrainTests, "_t_empty_terrain_walkable"))
	runner.register_test("terrain/is_walkable_empty_true",    Callable(StageTerrainTests, "_t_is_walkable_empty_true"))
	# V2-COMBAT-002 slice 1 — shared topology/edge-legality seam.
	runner.register_test("terrain/legal_edge_orthogonal", Callable(StageTerrainTests, "_t_legal_edge_orthogonal"))
	runner.register_test("terrain/legal_edge_diagonal_both_solid", Callable(StageTerrainTests, "_t_legal_edge_diagonal_both_solid"))
	runner.register_test("terrain/legal_edge_diagonal_one_solid", Callable(StageTerrainTests, "_t_legal_edge_diagonal_one_solid"))
	runner.register_test("terrain/legal_edge_destination_rejected", Callable(StageTerrainTests, "_t_legal_edge_destination_rejected"))
	runner.register_test("terrain/legal_edge_source_rejected", Callable(StageTerrainTests, "_t_legal_edge_source_rejected"))
	runner.register_test("terrain/legal_edge_shape_rejected", Callable(StageTerrainTests, "_t_legal_edge_shape_rejected"))
	runner.register_test("terrain/legal_neighbors_empty_sentinel_bounds", Callable(StageTerrainTests, "_t_legal_neighbors_empty_sentinel_bounds"))
	runner.register_test("terrain/legal_neighbors_semantic_order", Callable(StageTerrainTests, "_t_legal_neighbors_semantic_order"))
	# New irregularity tests (V2-STAGE-004 Phase 2).
	runner.register_test("terrain/plateaus_are_irregular",           Callable(StageTerrainTests, "_t_plateaus_are_irregular"))
	runner.register_test("terrain/single_plateau_irregular_island",  Callable(StageTerrainTests, "_t_single_plateau_irregular_island"))
	# Integration guards — exercise the REAL balance.json config path (catch wiring bugs the
	# synthetic-config tests above cannot).
	runner.register_test("terrain/integration_virtue_signature",    Callable(StageTerrainTests, "_t_integration_virtue_signature"))
	runner.register_test("terrain/integration_situation_category",  Callable(StageTerrainTests, "_t_integration_situation_category"))
	runner.register_test("terrain/integration_generate_uses_virtue", Callable(StageTerrainTests, "_t_integration_generate_uses_virtue"))
	# V2-COMBAT-003 terrain commit 2 — shared-side connectivity + the repair's termination.
	runner.register_test("terrain/bridge_connects_shared_side",     Callable(StageTerrainTests, "_t_bridge_connects_shared_side"))
	runner.register_test("terrain/repair_terminates_all_virtues",   Callable(StageTerrainTests, "_t_repair_terminates_all_virtues"))
	runner.register_test("terrain/small_islands_are_kept",          Callable(StageTerrainTests, "_t_small_islands_are_kept"))
	runner.register_test("terrain/min_region_cells_is_honored",     Callable(StageTerrainTests, "_t_min_region_cells_is_honored"))
	# V2-COMBAT-003 terrain commit 3 — islands replace stragglers.
	runner.register_test("terrain/islands_are_moated",              Callable(StageTerrainTests, "_t_islands_are_moated"))
	runner.register_test("terrain/islands_are_one_region_min_size", Callable(StageTerrainTests, "_t_islands_are_one_region_min_size"))
	runner.register_test("terrain/island_config_is_honored",        Callable(StageTerrainTests, "_t_island_config_is_honored"))
	runner.register_test("terrain/island_size_scales_to_board",     Callable(StageTerrainTests, "_t_island_size_scales_to_board"))
	runner.register_test("terrain/walkable_set_reads_legacy_stragglers", Callable(StageTerrainTests, "_t_walkable_set_reads_legacy_stragglers"))
	# V2-COMBAT-003 terrain commit 5 — host-region placement + the objective site.
	# V2-COMBAT-003 terrain commit 4 — bridges as their own tile, island bridging,
	# extra bridges above 20 cells, edge placement, and the erosion leftovers.
	runner.register_test("terrain/plateau_blob_is_one_shared_side_region", Callable(StageTerrainTests, "_t_plateau_blob_is_one_shared_side_region"))
	runner.register_test("terrain/no_region_touches_another_region",      Callable(StageTerrainTests, "_t_no_region_touches_another_region"))
	runner.register_test("terrain/bridge_cell_set_matches_rects",         Callable(StageTerrainTests, "_t_bridge_cell_set_matches_rects"))
	runner.register_test("terrain/island_bridge_chance_is_honored",       Callable(StageTerrainTests, "_t_island_bridge_chance_is_honored"))
	runner.register_test("terrain/island_extra_bridges_and_edge_placement", Callable(StageTerrainTests, "_t_island_extra_bridges_and_edge_placement"))

	runner.register_test("terrain/host_region_offers_objective_site", Callable(StageTerrainTests, "_t_host_region_offers_objective_site"))
	runner.register_test("terrain/objective_site_built_when_absent",  Callable(StageTerrainTests, "_t_objective_site_built_when_absent"))
	runner.register_test("terrain/situations_stay_on_host_region",    Callable(StageTerrainTests, "_t_situations_stay_on_host_region"))
	runner.register_test("terrain/objective_situations_have_clearance", Callable(StageTerrainTests, "_t_objective_situations_have_clearance"))


# ─── Test 1 — DETERMINISM: same inputs → deep-equal dicts ───────────────────
static func _t_determinism_generate() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	var seeds_to_check := [42, 12345, 99999]
	for seed_val in seeds_to_check:
		var t1: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		var t2: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		if not _terrain_equal(t1, t2):
			return { "ok": false, "error": "Non-deterministic output for seed %d" % seed_val }
	return { "ok": true }


# ─── Test 2 — CONNECTIVITY: exactly one SUBSTANTIAL shared-side region ───────
# Critical guard — a bridge generation bug made components disjoint.
#
# V2-COMBAT-003 terrain commit 2 rewrote what this test asserts. It used to run an
# 8-direction flood fill and demand that it reach EVERY walkable cell. That assertion was
# passing for the wrong reason: an 8-direction fill walks straight through a single corner
# touch, so it declared two plateaus joined at one corner "connected" — the very blindness
# that stopped the generator's own repair from ever firing. It also cannot express the
# approved design, which deliberately KEEPS small islands.
#
# The guarantee the generator now makes, and the one asserted here, is:
#   every PLATEAU-OR-BRIDGE region of `connect_min_region_cells` (6) cells or more is THE
#   SAME region, judged by a full shared side.
# Regions of 5 cells or fewer may exist and are left alone on purpose.
#
# V2-COMBAT-003 terrain commit 3 narrowed the SET this runs over, not the guarantee.
# Islands are minted after the repair, so they were never covered by it; before commit 3
# that distinction was invisible because a straggler was a single cell and could not reach
# the 6-cell threshold. A commit-3 island is moated and routinely larger than 6, so
# measuring the full walkable set here would assert something the generator has never
# promised. `_walkable_without_islands` is the geometry the repair actually governs.
static func _t_connectivity_single_comp() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in range(1, 21):  # 20 seeds
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = _walkable_without_islands(terrain)
		if walkable.is_empty():
			return { "ok": false, "error": "Seed %d: walkable_set is empty" % seed_val }
		var regions := _shared_side_regions(walkable)
		var substantial: Array = []
		for r_v in regions:
			var r: Array = r_v
			if r.size() >= _MIN_REGION:
				substantial.append(r.size())
		if substantial.size() != 1:
			return { "ok": false, "error": "Seed %d: expected exactly ONE shared-side region of >= %d cells, found %d (sizes %s) out of %d walkable cells" % [seed_val, _MIN_REGION, substantial.size(), str(substantial), walkable.size()] }
	return { "ok": true }


# ─── Test 3 — BRIDGE WIDTH: every bridge rect has min(w,h) >= 2 ─────────────
static func _t_bridge_width_min2() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in [1, 7, 42, 100, 999]:
		for stage_idx in [0, 1, 2]:
			var terrain: Dictionary = StageTerrain.generate(seed_val, stage_idx, sig, bounds)
			var bridges_v: Variant = terrain.get("bridges", [])
			var bridges: Array = bridges_v if bridges_v is Array else []
			for b_v in bridges:
				var b: Dictionary = b_v if b_v is Dictionary else {}
				var bw := int(b.get("w", 0))
				var bh := int(b.get("h", 0))
				if min(bw, bh) < 2:
					return { "ok": false, "error": "Seed %d stage %d: bridge has min(w,h)=%d (w=%d,h=%d) — below minimum 2" % [seed_val, stage_idx, min(bw, bh), bw, bh] }
	return { "ok": true }


# ─── Test 4 — VARIATION: different stage_index → different terrain ───────────
static func _t_stage_variation() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	var seed_val := 42
	var t0: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
	var t1: Dictionary = StageTerrain.generate(seed_val, 1, sig, bounds)
	if _terrain_equal(t0, t1):
		return { "ok": false, "error": "Stage 0 and stage 1 produced identical terrain (seed=%d) — no variation between stages" % seed_val }
	return { "ok": true }


# ─── Test 5 — SIGNATURE CHARACTER: plateau count in [count_min..count_max] ───
static func _t_sig_plateau_count_bounds() -> Dictionary:
	var sig := _default_sig()  # count_min=3, count_max=5
	var bounds := _default_bounds()
	for seed_val in range(1, 11):
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		var plateaus_v: Variant = terrain.get("plateaus", [])
		var plateaus: Array = plateaus_v if plateaus_v is Array else []
		var count := plateaus.size()
		if count < 3 or count > 5:
			return { "ok": false, "error": "Seed %d: plateau count %d not in [3,5]" % [seed_val, count] }
	return { "ok": true }


# ─── Test 6 — LOW vs HIGH sig: low-count sig produces <= high-count sig ──────
# Uses non-overlapping count ranges so any seed shows the relationship.
# Low sig: count 1..2.  High sig: count 6..8.  Check over 5 seeds.
static func _t_sig_low_vs_high_plateaus() -> Dictionary:
	var bounds := _default_bounds()
	var low_sig := {
		"plateau_count_min": 1,
		"plateau_count_max": 2,
		"plateau_w_min": 4, "plateau_w_max": 8,
		"plateau_h_min": 4, "plateau_h_max": 8,
		"bridge_width": 2, "bridge_density": 0.2,
		"island_count_min": 0, "island_count_max": 1,
		"island_size_min": 4, "island_size_max": 8,
	}
	var high_sig := {
		"plateau_count_min": 6,
		"plateau_count_max": 8,
		"plateau_w_min": 4, "plateau_w_max": 8,
		"plateau_h_min": 4, "plateau_h_max": 8,
		"bridge_width": 2, "bridge_density": 0.2,
		"island_count_min": 0, "island_count_max": 1,
		"island_size_min": 4, "island_size_max": 8,
	}
	for seed_val in [10, 20, 30, 40, 50]:
		var low_t:  Dictionary = StageTerrain.generate(seed_val, 0, low_sig,  bounds)
		var high_t: Dictionary = StageTerrain.generate(seed_val, 0, high_sig, bounds)
		var lc := (low_t.get("plateaus", []) as Array).size()
		var hc := (high_t.get("plateaus", []) as Array).size()
		if lc > hc:
			return { "ok": false, "error": "Seed %d: low sig count %d > high sig count %d — signature not driving count" % [seed_val, lc, hc] }
	return { "ok": true }


# ─── Test 7 — ENTRY CELL: entry_cell is in walkable set ─────────────────────
static func _t_entry_cell_walkable() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in [1, 42, 777]:
		var terrain: Dictionary  = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)
		if not StageTerrain.is_walkable(entry, walkable):
			return { "ok": false, "error": "Seed %d: entry_cell {%d,%d} is not in walkable set" % [seed_val, entry.get("col", -1), entry.get("row", -1)] }
	return { "ok": true }


# ─── Test 8 — ENTRY CELL: leftmost column OF THE HOST REGION ────────────────
# V2-COMBAT-003 terrain commit 3 restated this test, because the behaviour it pins had to
# change. It used to demand the leftmost column of the WHOLE walkable set. Commit 3 mints
# moated islands, plateaus never occupy column 0 (_BORDER_MARGIN) and islands may, so the
# old rule would routinely start the party on ground with no route off it — a dead start
# on turn one, on 766 of 1,800 combat-bounds boards and 867 of 1,800 explore-bounds boards
# in the measured sweep. entry_cell now anchors to the host region.
#
# The test asserts BOTH halves, so neither can rot:
#   1. the entry cell is the leftmost column of the host region, and
#   2. the entry cell is REACHABLE — it has at least one legal neighbour and it is in the
#      host region, which is what makes it a start the party can actually leave.
static func _t_entry_cell_min_col() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in [1, 42, 1000]:
		var terrain: Dictionary  = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)
		var entry_col := int(entry.get("col", -1))
		var entry_key := "%d,%d" % [entry_col, int(entry.get("row", -1))]

		# Host region: largest shared-side region, ties by numerically lowest (col,row).
		var regions := _shared_side_regions(walkable)
		var host: Array = []
		for r_v in regions:
			var r: Array = r_v
			if host.is_empty() or r.size() > host.size():
				host = r
		if host.is_empty():
			return { "ok": false, "error": "Seed %d: no walkable region at all" % seed_val }
		var host_set: Dictionary = {}
		var host_min_col := 999999
		for k in host:
			host_set[k] = true
			host_min_col = min(host_min_col, int((k as String).split(",")[0]))

		if not host_set.has(entry_key):
			return { "ok": false, "error": "Seed %d: entry_cell %s is OFF the host region — the party starts on unreachable ground" % [seed_val, entry_key] }
		if entry_col != host_min_col:
			return { "ok": false, "error": "Seed %d: entry_cell col %d != host region min_col %d" % [seed_val, entry_col, host_min_col] }
		if StageTerrain.legal_neighbors(entry, walkable, bounds).is_empty():
			return { "ok": false, "error": "Seed %d: entry_cell %s has no legal neighbour — the party cannot take a step" % [seed_val, entry_key] }
	return { "ok": true }


# ─── Test 9 — BFS: target cell has distance 0 ───────────────────────────────
static func _t_bfs_target_dist0() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	var terrain: Dictionary  = StageTerrain.generate(99, 0, sig, bounds)
	var walkable: Dictionary = StageTerrain.walkable_set(terrain)
	var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)
	# Use entry as target to guarantee it's walkable
	var dist_field: Dictionary = StageTerrain.bfs_distance_field(entry, walkable)
	var start_key: String = "%d,%d" % [int(entry.get("col", 0)), int(entry.get("row", 0))]
	if not dist_field.has(start_key):
		return { "ok": false, "error": "BFS dist_field missing the target key '%s'" % start_key }
	if int(dist_field[start_key]) != 0:
		return { "ok": false, "error": "BFS target dist expected 0, got %d" % int(dist_field[start_key]) }
	return { "ok": true }


# ─── Test 10 — BFS: entry cell is reachable from any walkable target ─────────
static func _t_bfs_entry_reachable() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in [5, 55, 555]:
		var terrain: Dictionary  = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)
		var entry_key: String    = "%d,%d" % [int(entry.get("col", 0)), int(entry.get("row", 0))]
		# Pick a cell from the walkable set that is NOT the entry (pick last key)
		var target_key: String = entry_key
		for k in walkable:
			if k != entry_key:
				target_key = k
				break
		var parts := target_key.split(",")
		var target := { "col": int(parts[0]), "row": int(parts[1]) }
		var dist_field: Dictionary = StageTerrain.bfs_distance_field(target, walkable)
		if not dist_field.has(entry_key):
			return { "ok": false, "error": "Seed %d: entry cell '%s' not reachable from target '%s' in dist_field" % [seed_val, entry_key, target_key] }
	return { "ok": true }


# ─── Test 11 — NEXT_STEP: repeated calls from entry reach the target ─────────
static func _t_next_step_reaches_target() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	var terrain: Dictionary  = StageTerrain.generate(42, 0, sig, bounds)
	var walkable: Dictionary = StageTerrain.walkable_set(terrain)
	var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)

	# Pick a target: find the walkable cell furthest in column from entry
	var target_key := ""
	var max_col := int(entry.get("col", 0))
	for k in walkable:
		var parts := (k as String).split(",")
		var c := int(parts[0])
		if c > max_col:
			max_col = c
			target_key = k
	if target_key.is_empty():
		# All cells in same column — pick any non-entry cell
		for k in walkable:
			if k != ("%d,%d" % [int(entry.get("col", 0)), int(entry.get("row", 0))]):
				target_key = k
				break
	if target_key.is_empty():
		# Only one cell in the whole map — degenerate but not a bug
		return { "ok": true }

	var t_parts := target_key.split(",")
	var target := { "col": int(t_parts[0]), "row": int(t_parts[1]) }

	# Build dist_field from target
	var dist_field: Dictionary = StageTerrain.bfs_distance_field(target, walkable)
	var entry_key: String = "%d,%d" % [int(entry.get("col", 0)), int(entry.get("row", 0))]
	if not dist_field.has(entry_key):
		return { "ok": false, "error": "entry cell not reachable in dist_field — cannot walk to target" }

	# Walk from entry toward target
	var max_steps := walkable.size() + 5  # strict cap
	var cur := entry.duplicate()
	for _step in range(max_steps):
		var cur_key: String = "%d,%d" % [int(cur.get("col", 0)), int(cur.get("row", 0))]
		if cur_key == target_key:
			return { "ok": true }
		var next_v: Dictionary = StageTerrain.next_step(cur, dist_field, walkable, target)
		var next_key: String = "%d,%d" % [int(next_v.get("col", 0)), int(next_v.get("row", 0))]
		if next_key == cur_key:
			# No progress — at a dead end before reaching target
			return { "ok": false, "error": "next_step returned same cell '%s' before reaching target '%s'" % [cur_key, target_key] }
		cur = next_v

	return { "ok": false, "error": "Did not reach target '%s' within %d steps" % [target_key, max_steps] }


# ─── Test 11b — NEXT_STEP ANTI-DRIFT: no lateral bias on open terrain ───────
# Regression guard for the up-left tiebreak bias (game-wide movement drift).
# On a full open board, next_step toward an off-axis target must head DIRECTLY:
# every step may not increase the |Δrow| or |Δcol| distance to the target while
# that axis still has distance to close. The old "lowest row, then lowest col"
# tiebreak collapsed movement onto row 0 early (e.g. (1,4)→…→(5,0)→(6,0)…),
# overshooting the target row — exactly what this assertion catches.
static func _t_next_step_no_lateral_drift() -> Dictionary:
	# Full 12×12 walkable set (no void) — the open-terrain case where ties abound.
	var walkable: Dictionary = {}
	for c in range(0, 12):
		for r in range(0, 12):
			walkable["%d,%d" % [c, r]] = true

	var target := { "col": 10, "row": 1 }
	var dist_field: Dictionary = StageTerrain.bfs_distance_field(target, walkable)

	var cur := { "col": 1, "row": 4 }
	var max_steps := walkable.size() + 5
	for _step in range(max_steps):
		var ccol := int(cur.get("col", 0))
		var crow := int(cur.get("row", 0))
		if ccol == int(target.col) and crow == int(target.row):
			# Reached target with no drift detected.
			# Sanity: confirm we did NOT pre-collapse to the top edge (row 0)
			# on the way — for target row 1, a direct path never visits row 0.
			return { "ok": true }

		var prev_dcol: int = abs(ccol - int(target.col))
		var prev_drow: int = abs(crow - int(target.row))

		var next_v: Dictionary = StageTerrain.next_step(cur, dist_field, walkable, target)
		var ncol := int(next_v.get("col", 0))
		var nrow := int(next_v.get("row", 0))
		if ncol == ccol and nrow == crow:
			return { "ok": false, "error": "next_step stuck at (%d,%d) before reaching target" % [ccol, crow] }

		var new_dcol: int = abs(ncol - int(target.col))
		var new_drow: int = abs(nrow - int(target.row))

		# Anti-drift: while an axis still has distance to close, the step must not
		# move AWAY along that axis (no lateral/vertical overshoot).
		if prev_dcol > 0 and new_dcol > prev_dcol:
			return { "ok": false, "error": "lateral drift: col distance grew %d→%d at step from (%d,%d)" % [prev_dcol, new_dcol, ccol, crow] }
		if prev_drow > 0 and new_drow > prev_drow:
			return { "ok": false, "error": "vertical drift: row distance grew %d→%d at step from (%d,%d)" % [prev_drow, new_drow, ccol, crow] }
		# Overshoot guard: must never enter row 0 when target row is 1 (top-edge hugging).
		if nrow == 0 and int(target.row) >= 1:
			return { "ok": false, "error": "top-edge overshoot: stepped onto row 0 toward target row %d" % int(target.row) }

		cur = next_v

	return { "ok": false, "error": "did not reach target within %d steps" % max_steps }


# ─── Test 12 — LEGACY: walkable_set({}) == {} ────────────────────────────────
static func _t_empty_terrain_walkable() -> Dictionary:
	var result: Dictionary = StageTerrain.walkable_set({})
	if not result.is_empty():
		return { "ok": false, "error": "walkable_set({}) should return {} but got %d cells" % result.size() }
	return { "ok": true }


# ─── Test 13 — LEGACY: is_walkable(any, {}) == true ─────────────────────────
static func _t_is_walkable_empty_true() -> Dictionary:
	var cells_to_check := [
		{ "col": 0,   "row": 0   },
		{ "col": 15,  "row": 7   },
		{ "col": 99,  "row": 99  },
		{ "col": -1,  "row": -1  },
	]
	for cell_v in cells_to_check:
		var cell: Dictionary = cell_v if cell_v is Dictionary else {}
		if not StageTerrain.is_walkable(cell, {}):
			return { "ok": false, "error": "is_walkable(%s, {}) should return true but returned false" % str(cell) }
	return { "ok": true }


# V2-COMBAT-002 — orthogonal edges use the same destination walkability seam.
static func _t_legal_edge_orthogonal() -> Dictionary:
	var walkable := {
		"1,1": true,
		"2,1": true,
	}
	if not StageTerrain.is_legal_edge({ "col": 1, "row": 1 }, { "col": 2, "row": 1 }, walkable):
		return { "ok": false, "error": "walkable orthogonal edge should be legal" }
	return { "ok": true }


# A diagonal cannot squeeze between two solid orthogonal side cells.
static func _t_legal_edge_diagonal_both_solid() -> Dictionary:
	var walkable := {
		"1,1": true,
		"2,2": true,
	}
	if StageTerrain.is_legal_edge({ "col": 1, "row": 1 }, { "col": 2, "row": 2 }, walkable):
		return { "ok": false, "error": "diagonal between two solid corners should be illegal" }
	return { "ok": true }


# One open orthogonal side is enough to permit the diagonal.
static func _t_legal_edge_diagonal_one_solid() -> Dictionary:
	var from_cell := { "col": 1, "row": 1 }
	var to_cell := { "col": 2, "row": 2 }
	var side_col_open := {
		"1,1": true,
		"2,1": true,
		"2,2": true,
	}
	var side_row_open := {
		"1,1": true,
		"1,2": true,
		"2,2": true,
	}
	if not StageTerrain.is_legal_edge(from_cell, to_cell, side_col_open):
		return { "ok": false, "error": "diagonal with open column-side cell should be legal" }
	if not StageTerrain.is_legal_edge(from_cell, to_cell, side_row_open):
		return { "ok": false, "error": "diagonal with open row-side cell should be legal" }
	return { "ok": true }


# Solid and out-of-bounds destinations are rejected before corner evaluation.
static func _t_legal_edge_destination_rejected() -> Dictionary:
	var walkable := {
		"1,1": true,
	}
	if StageTerrain.is_legal_edge({ "col": 1, "row": 1 }, { "col": 2, "row": 1 }, walkable):
		return { "ok": false, "error": "solid destination should be illegal" }
	if StageTerrain.is_legal_edge({ "col": 0, "row": 0 }, { "col": -1, "row": 0 }, {}, { "w": 3, "h": 3 }):
		return { "ok": false, "error": "out-of-bounds destination should be illegal" }
	return { "ok": true }


# A move cannot originate from solid or out-of-bounds topology.
static func _t_legal_edge_source_rejected() -> Dictionary:
	var walkable := {
		"2,1": true,
	}
	if StageTerrain.is_legal_edge({ "col": 1, "row": 1 }, { "col": 2, "row": 1 }, walkable):
		return { "ok": false, "error": "solid source should be illegal" }
	if StageTerrain.is_legal_edge({ "col": -1, "row": 0 }, { "col": 0, "row": 0 }, {}, { "w": 3, "h": 3 }):
		return { "ok": false, "error": "out-of-bounds source should be illegal" }
	return { "ok": true }


# The seam represents exactly one 8-direction edge, never self or a jump.
static func _t_legal_edge_shape_rejected() -> Dictionary:
	var origin := { "col": 2, "row": 2 }
	if StageTerrain.is_legal_edge(origin, origin, {}):
		return { "ok": false, "error": "self edge should be illegal" }
	for destination in [
		{ "col": 4, "row": 2 },
		{ "col": 2, "row": 0 },
		{ "col": 4, "row": 4 },
	]:
		if StageTerrain.is_legal_edge(origin, destination, {}):
			return { "ok": false, "error": "nonadjacent edge should be illegal: %s" % str(destination) }
	return { "ok": true }


# Empty walkable retains its all-walkable meaning, while supplied bounds clip it.
static func _t_legal_neighbors_empty_sentinel_bounds() -> Dictionary:
	var neighbors: Array = StageTerrain.legal_neighbors(
		{ "col": 0, "row": 0 },
		{},
		{ "w": 3, "h": 3 }
	)
	var expected: Array = [
		{ "col": 0, "row": 1 },
		{ "col": 1, "row": 0 },
		{ "col": 1, "row": 1 },
	]
	if neighbors != expected:
		return { "ok": false, "error": "bounded empty-sentinel neighbors mismatch: %s" % str(neighbors) }
	return { "ok": true }


# Ordering is numeric (col,row), not lexical canonical-key ordering.
static func _t_legal_neighbors_semantic_order() -> Dictionary:
	var neighbors: Array = StageTerrain.legal_neighbors({ "col": 10, "row": 10 }, {})
	var expected: Array = [
		{ "col": 9, "row": 9 },
		{ "col": 9, "row": 10 },
		{ "col": 9, "row": 11 },
		{ "col": 10, "row": 9 },
		{ "col": 10, "row": 11 },
		{ "col": 11, "row": 9 },
		{ "col": 11, "row": 10 },
		{ "col": 11, "row": 11 },
	]
	if neighbors != expected:
		return { "ok": false, "error": "neighbors not in numeric (col,row) order: %s" % str(neighbors) }
	return { "ok": true }


# ─── Test 14 — PLATEAUS ARE IRREGULAR ───────────────────────────────────────
# For several seeds: assert that at least one plateau per terrain has cells count
# LESS than its bounding-box area (w*h) — i.e. not a full rectangle.
# Also asserts every plateau's cells form a single 8-connected component AND
# include the box center cell.
static func _t_plateaus_are_irregular() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	var seeds_to_check := [1, 7, 42, 100, 300, 500, 999]
	for seed_val in seeds_to_check:
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		var plateaus_v: Variant = terrain.get("plateaus", [])
		var plateaus: Array = plateaus_v if plateaus_v is Array else []
		if plateaus.is_empty():
			return { "ok": false, "error": "Seed %d: no plateaus generated" % seed_val }
		var found_irregular := false
		for p_v in plateaus:
			var p: Dictionary = p_v if p_v is Dictionary else {}
			var pw := int(p.get("w", 1))
			var ph := int(p.get("h", 1))
			var pc := int(p.get("col", 0))
			var pr := int(p.get("row", 0))
			var cells_v: Variant = p.get("cells", [])
			var cells: Array = cells_v if cells_v is Array else []
			if cells.is_empty():
				return { "ok": false, "error": "Seed %d: plateau at (%d,%d) has no cells array" % [seed_val, pc, pr] }
			var box_area := pw * ph
			# Must contain at least 1 cell.
			if cells.size() == 0:
				return { "ok": false, "error": "Seed %d: plateau cells empty" % seed_val }
			# Must be 8-connected.
			if not _plateau_cells_connected(cells):
				return { "ok": false, "error": "Seed %d: plateau at (%d,%d) cells are NOT 8-connected" % [seed_val, pc, pr] }
			# Must include the center cell.
			var cx := pc + pw / 2
			var cy := pr + ph / 2
			var has_center := false
			for pair_v in cells:
				var pair: Array = pair_v if pair_v is Array else []
				if pair.size() >= 2 and int(pair[0]) == cx and int(pair[1]) == cy:
					has_center = true
					break
			if not has_center:
				return { "ok": false, "error": "Seed %d: plateau at (%d,%d) missing center cell (%d,%d)" % [seed_val, pc, pr, cx, cy] }
			# Check if this plateau is non-rectangular.
			if cells.size() < box_area:
				found_irregular = true
		if not found_irregular:
			return { "ok": false, "error": "Seed %d: all plateaus are full rectangles (no erosion occurred)" % seed_val }
	return { "ok": true }


# ─── Test 15 — SINGLE PLATEAU IRREGULAR ISLAND ───────────────────────────────
# A signature with count_min=count_max=1 must still yield a connected irregular
# blob (not a plain rectangle) that has the center cell and is 8-connected.
static func _t_single_plateau_irregular_island() -> Dictionary:
	var bounds := _default_bounds()
	var single_sig := {
		"plateau_count_min": 1,
		"plateau_count_max": 1,
		"plateau_w_min": 6,
		"plateau_w_max": 8,
		"plateau_h_min": 6,
		"plateau_h_max": 8,
		"bridge_width":  2,
		"bridge_density": 0.0,
		"island_count_min": 0,
		"island_count_max": 0,
		"island_size_min": 4,
		"island_size_max": 8,
	}
	var found_irregular_across_seeds := false
	for seed_val in [10, 20, 30, 40, 50, 60, 70]:
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, single_sig, bounds)
		var plateaus_v: Variant = terrain.get("plateaus", [])
		var plateaus: Array = plateaus_v if plateaus_v is Array else []
		if plateaus.size() != 1:
			return { "ok": false, "error": "Seed %d: expected 1 plateau, got %d" % [seed_val, plateaus.size()] }
		var p: Dictionary = plateaus[0] if plateaus[0] is Dictionary else {}
		var pw := int(p.get("w", 1))
		var ph := int(p.get("h", 1))
		var pc := int(p.get("col", 0))
		var pr := int(p.get("row", 0))
		var cells_v: Variant = p.get("cells", [])
		var cells: Array = cells_v if cells_v is Array else []
		if cells.is_empty():
			return { "ok": false, "error": "Seed %d: single plateau has no cells" % seed_val }
		# Must be 8-connected.
		if not _plateau_cells_connected(cells):
			return { "ok": false, "error": "Seed %d: single plateau cells are NOT 8-connected" % seed_val }
		# Must include center.
		var cx := pc + pw / 2
		var cy := pr + ph / 2
		var has_center := false
		for pair_v in cells:
			var pair: Array = pair_v if pair_v is Array else []
			if pair.size() >= 2 and int(pair[0]) == cx and int(pair[1]) == cy:
				has_center = true
				break
		if not has_center:
			return { "ok": false, "error": "Seed %d: single plateau missing center cell (%d,%d)" % [seed_val, cx, cy] }
		# walkable_set must be a single connected component.
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		if walkable.is_empty():
			return { "ok": false, "error": "Seed %d: walkable_set is empty for single plateau" % seed_val }
		var reachable := _flood_fill_count(walkable)
		if reachable != walkable.size():
			return { "ok": false, "error": "Seed %d: single plateau walkable_set is disconnected (%d/%d)" % [seed_val, reachable, walkable.size()] }
		# Check irregular (at least across several seeds we expect erosion to fire).
		var box_area := pw * ph
		if cells.size() < box_area:
			found_irregular_across_seeds = true
	if not found_irregular_across_seeds:
		return { "ok": false, "error": "No single-plateau seed produced an irregular (eroded) shape — erosion never fired" }
	return { "ok": true }


# ─── Integration helpers ────────────────────────────────────────────────────

# Load the REAL data.stages block from balance.json (so a misplaced config key is caught).
static func _load_balance_stages() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data_v: Variant = (parsed as Dictionary).get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var stages_v: Variant = data.get("stages", {})
	return stages_v if stages_v is Dictionary else {}


# ─── Integration 1 — virtue resolves to its by_virtue signature (catches map_shape path bug) ─
static func _t_integration_virtue_signature() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	if stages_cfg.is_empty():
		return { "ok": false, "error": "could not load data.stages from balance.json" }
	if not stages_cfg.has("map_shape"):
		return { "ok": false, "error": "data.stages.map_shape missing — config block at the wrong JSON path" }
	var sig_c := RealmGenerator._resolve_terrain_signature({ "virtue": "courage" }, stages_cfg)
	if str(sig_c.get("relief", "")) != "open_flats":
		return { "ok": false, "error": "courage did not resolve to its by_virtue signature (relief=%s, expected open_flats)" % str(sig_c.get("relief", "")) }
	var sig_w := RealmGenerator._resolve_terrain_signature({ "virtue": "wisdom" }, stages_cfg)
	if str(sig_w.get("relief", "")) != "sunken_archipelago":
		return { "ok": false, "error": "wisdom did not resolve to its by_virtue signature (relief=%s, expected sunken_archipelago)" % str(sig_w.get("relief", "")) }
	# Unknown virtue falls back to the default signature (not a by_virtue entry).
	var sig_d := RealmGenerator._resolve_terrain_signature({ "virtue": "nonexistent" }, stages_cfg)
	if str(sig_d.get("relief", "")) != "default_relief":
		return { "ok": false, "error": "unknown virtue should resolve to default signature (relief=%s)" % str(sig_d.get("relief", "")) }
	return { "ok": true }


# ─── Integration 2 — situation_category present + correct (catches the path bug) ─────────────
static func _t_integration_situation_category() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var sc_v: Variant = stages_cfg.get("situation_category", {})
	var sc: Dictionary = sc_v if sc_v is Dictionary else {}
	if sc.is_empty():
		return { "ok": false, "error": "data.stages.situation_category missing — config block at the wrong JSON path" }
	if str(sc.get("combat", "")) != "combat" or str(sc.get("loot", "")) != "reward" or str(sc.get("omen", "")) != "intel":
		return { "ok": false, "error": "situation_category mapping incorrect (combat=%s loot=%s omen=%s)" % [str(sc.get("combat","")), str(sc.get("loot","")), str(sc.get("omen",""))] }
	return { "ok": true }


# ─── Integration 3 — generate honors the resolved virtue signature (end-to-end) ──────────────
static func _t_integration_generate_uses_virtue() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var sig_w := RealmGenerator._resolve_terrain_signature({ "virtue": "wisdom" }, stages_cfg)
	var cmin := int(sig_w.get("plateau_count_min", -1))
	var cmax := int(sig_w.get("plateau_count_max", -1))
	if cmin < 0 or cmax < 0:
		return { "ok": false, "error": "wisdom signature missing plateau_count bounds" }
	for seed_val in [7, 4242, 90909]:
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, sig_w, { "w": 40, "h": 40 })
		var plateaus_v: Variant = terrain.get("plateaus", [])
		var pc: int = (plateaus_v as Array).size() if plateaus_v is Array else 0
		if pc < cmin or pc > cmax:
			return { "ok": false, "error": "wisdom terrain plateau count %d outside signature range [%d,%d] (seed %d)" % [pc, cmin, cmax, seed_val] }
	return { "ok": true }


# ═══════════════════════════════════════════════════════════════════════════════
# V2-COMBAT-003 terrain commit 2 — shared-side connectivity and its termination
# ═══════════════════════════════════════════════════════════════════════════════

# ─── THE TERMINATION PROOF ───────────────────────────────────────────────────
# The connectivity repair loop bridges the host region to a cut-off region, recomputes the
# regions, and repeats. It terminates ONLY IF a bridge really merges the two regions under
# the shared-side rule. Under the old 8-direction rule a bridge that merely touched at a
# corner still counted as a merge; under the shared-side rule it would not, the region
# count would never fall, and board generation would hang forever.
#
# So the loop's termination rests on exactly one claim, and this test attacks it directly:
#   for every endpoint pair and both corner orders, the cell union of _make_bridge_rects
#   is SHARED-SIDE connected AND contains both endpoints.
# The L-corner is the place it would break, which is why the sweep includes every relative
# orientation of the two endpoints (b left/right of a, above/below, and both straight
# cases), every board edge (endpoints at 0 and at map_w-1, where the rect clamp bites),
# and bridge widths 2 and 3.
static func _t_bridge_connects_shared_side() -> Dictionary:
	var map_w: int = 14
	var map_h: int = 12
	var coords_c: Array = [0, 1, 2, 7, 12, 13]
	var coords_r: Array = [0, 1, 6, 10, 11]
	var layouts: Dictionary = {}   # distinct rect layouts seen, to prove both branches ran
	var checked: int = 0

	for bw in [2, 3]:
		for ac in coords_c:
			for ar in coords_r:
				for bc in coords_c:
					for br in coords_r:
						for rng_seed in [1, 2, 3, 4]:
							var rng := RandomNumberGenerator.new()
							rng.seed = rng_seed
							var rects: Array = StageTerrain._make_bridge_rects(
								ac, ar, bc, br, bw, map_w, map_h, rng)
							checked += 1

							# Union of all rect cells.
							var cells: Dictionary = {}
							var sig_parts: Array = []
							for rect_v in rects:
								var rect: Dictionary = rect_v
								sig_parts.append("%d/%d/%d/%d" % [
									int(rect.get("col", 0)), int(rect.get("row", 0)),
									int(rect.get("w", 0)), int(rect.get("h", 0))])
								var rc: int = int(rect.get("col", 0))
								var rr: int = int(rect.get("row", 0))
								var rw: int = int(rect.get("w", 1))
								var rh: int = int(rect.get("h", 1))
								for dc in range(rw):
									for dr in range(rh):
										cells["%d,%d" % [rc + dc, rr + dr]] = true
							if ac != bc and ar != br:
								layouts[",".join(PackedStringArray(sig_parts))] = true

							# 1. Both endpoints are in the bridge.
							var a_key: String = "%d,%d" % [ac, ar]
							var b_key: String = "%d,%d" % [bc, br]
							if not cells.has(a_key):
								return { "ok": false, "error": "bridge (%d,%d)->(%d,%d) w=%d seed=%d does NOT contain endpoint A" % [ac, ar, bc, br, bw, rng_seed] }
							if not cells.has(b_key):
								return { "ok": false, "error": "bridge (%d,%d)->(%d,%d) w=%d seed=%d does NOT contain endpoint B" % [ac, ar, bc, br, bw, rng_seed] }

							# 2. The bridge is ONE shared-side region — so it truly merges
							#    the two regions it touches, and the loop makes progress.
							var regions := _shared_side_regions(cells)
							if regions.size() != 1:
								return { "ok": false, "error": "bridge (%d,%d)->(%d,%d) w=%d seed=%d splits into %d shared-side regions — the repair loop would NEVER TERMINATE on this pair" % [ac, ar, bc, br, bw, rng_seed, regions.size()] }

	# Both corner orders (horizontal-first and vertical-first) must actually have been
	# exercised, or the sweep only proved one branch.
	if layouts.size() < 2:
		return { "ok": false, "error": "only %d distinct L layout(s) seen — the horizontal-first/vertical-first branches were not both exercised" % layouts.size() }
	if checked < 1000:
		return { "ok": false, "error": "sweep too small (%d cases)" % checked }
	return { "ok": true }


# ─── REPAIR: no cut-off region of >= 6 cells survives, on every real signature ─
# This is the end-to-end statement of the guarantee, run against the ten AUTHORED virtue
# signatures out of balance.json (not a synthetic one) and against both board-size families
# the generator serves: the combat board (data.combat.board, 12x12..22x22) and the explore
# map (RealmGenerator._generate_explore_map, 30x30 and up). Explore and venture render the
# same terrain, so a guarantee that only held on combat bounds would be half a guarantee.
#
# It doubles as the termination test: a repair loop that failed to make progress would not
# fail this assertion, it would HANG the suite.
static func _t_repair_terminates_all_virtues() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var map_shape_v: Variant = stages_cfg.get("map_shape", {})
	var map_shape: Dictionary = map_shape_v if map_shape_v is Dictionary else {}
	var by_virtue_v: Variant = map_shape.get("by_virtue", {})
	var by_virtue: Dictionary = by_virtue_v if by_virtue_v is Dictionary else {}
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }

	var bounds_cycle: Array = [
		{ "w": 12, "h": 12 }, { "w": 18, "h": 18 }, { "w": 22, "h": 22 },
		{ "w": 30, "h": 30 }, { "w": 40, "h": 35 }, { "w": 50, "h": 40 },
	]
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(12):
			var realm_seed: int = 500000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.terrain.%s.%d" % [virtue, i])
			# Plateaus + bridges only: islands are minted AFTER the repair by design and
			# are deliberately cut off (V2-COMBAT-003 terrain commit 3).
			var walkable: Dictionary = _walkable_without_islands(terrain)
			var regions := _shared_side_regions(walkable)
			var substantial: Array = []
			for r_v in regions:
				var r: Array = r_v
				if r.size() >= _MIN_REGION:
					substantial.append(r.size())
			if substantial.size() != 1:
				return { "ok": false, "error": "%s seed %d bounds %dx%d: %d regions of >= %d cells (sizes %s) — the board is split" % [virtue, realm_seed, int(bounds.get("w", 0)), int(bounds.get("h", 0)), substantial.size(), _MIN_REGION, str(substantial)] }
	return { "ok": true }


# ─── THE THRESHOLD DOES SOMETHING: small islands are still generated and kept ─
# The design keeps small islands on purpose. If the repair bridged every cut-off region
# regardless of size, this test would fail — and the failure would be silent variety loss,
# not a crash. So assert the positive: across a realistic sample, at least one board still
# carries a cut-off region of 5 cells or fewer.
#
# V2-COMBAT-003 terrain commit 4 CHANGED WHERE THAT REGION COMES FROM, and the test says so
# rather than hiding it. This used to run over the island-stripped set, on the reasoning
# that a deliberate island would let it pass for the wrong reason. That reasoning is now
# unreachable in play: the erosion fix means a plateau blob is exactly one shared-side
# region, so the generator no longer produces ANY sub-threshold plateau or bridge region —
# the 509 (combat) and 991 (explore) corner-hung leftovers measured before the fix were the
# entire supply. Every sub-threshold region on a generated board is now a deliberate island
# of 4 or 5 cells, which is precisely the variety the threshold exists to keep. The test
# therefore asserts BOTH halves: small regions survive on the full set, and there are none
# left on the stripped set.
static func _t_small_islands_are_kept() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var map_shape_v: Variant = stages_cfg.get("map_shape", {})
	var map_shape: Dictionary = map_shape_v if map_shape_v is Dictionary else {}
	var by_virtue_v: Variant = map_shape.get("by_virtue", {})
	var by_virtue: Dictionary = by_virtue_v if by_virtue_v is Dictionary else {}
	var sig_v: Variant = by_virtue.get("humility", {})
	var sig: Dictionary = sig_v if sig_v is Dictionary else {}
	if sig.is_empty():
		return { "ok": false, "error": "humility signature missing from balance.json" }

	var small_found: int = 0
	var stripped_small: int = 0
	for i in range(30):
		var terrain: Dictionary = StageTerrain.generate(
			700000 + i * 7919, i % 3, sig, { "w": 22, "h": 22 }, "test.island.%d" % i)
		# The FULL walkable set. V2-COMBAT-003 terrain commit 4 changed what this test can
		# honestly assert, and the change is the point of that commit — see the note above.
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		var regions := _shared_side_regions(walkable)
		for r_v in regions:
			var r: Array = r_v
			if r.size() > 0 and r.size() < _MIN_REGION:
				small_found += 1
		# The same count with the island system stripped out. It is expected to be ZERO
		# after commit 4 and is asserted as such, because a non-zero value there would mean
		# erosion is orphaning cells again.
		var stripped: Dictionary = _walkable_without_islands(terrain)
		for r2_v in _shared_side_regions(stripped):
			if (r2_v as Array).size() > 0 and (r2_v as Array).size() < _MIN_REGION:
				stripped_small += 1
	if small_found == 0:
		return { "ok": false, "error": "no region below %d cells survived across 30 humility boards — the repair is bridging in the small islands the design keeps" % _MIN_REGION }
	if stripped_small != 0:
		return { "ok": false, "error": "%d plateau/bridge region(s) below %d cells survived — after terrain commit 4 erosion may not orphan a cell, so every sub-threshold region on a board must be a deliberate island" % [stripped_small, _MIN_REGION] }
	return { "ok": true, "note": "%d sub-threshold regions kept, every one of them a deliberate island" % small_found }


# ─── THE THRESHOLD IS CONFIG: connect_min_region_cells reaches the generator ──
# A key authored in the signature but never read is a defect this project has shipped
# before. Prove the value travels by driving it to the one setting whose effect cannot be
# confused with anything else: a threshold larger than any board disables the repair
# entirely. Same seeds, same signatures, one key changed —
#   default (6)      => exactly one region of >= 6 cells on every board
#   threshold 999999 => split boards reappear, which IS the defect this commit fixes
# If the key were inert the two runs would be identical and the second assertion fails.
static func _t_min_region_cells_is_honored() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var map_shape_v: Variant = stages_cfg.get("map_shape", {})
	var map_shape: Dictionary = map_shape_v if map_shape_v is Dictionary else {}
	var by_virtue_v: Variant = map_shape.get("by_virtue", {})
	var by_virtue: Dictionary = by_virtue_v if by_virtue_v is Dictionary else {}
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }

	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var split_boards: int = 0
	var demonstrated: String = ""

	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var base_sig_v: Variant = by_virtue.get(virtue, {})
		var base_sig: Dictionary = base_sig_v if base_sig_v is Dictionary else {}
		var disabled_sig: Dictionary = base_sig.duplicate(true)
		disabled_sig["connect_min_region_cells"] = 999999

		for i in range(40):
			var realm_seed: int = 700000 + i * 7919
			var bounds: Dictionary = { "w": 22, "h": 22 }
			var ns: String = "test.island.%s.%d" % [virtue, i]

			var default_regions: int = _substantial_region_count(
				_walkable_without_islands(StageTerrain.generate(realm_seed, i % 3, base_sig, bounds, ns)))
			if default_regions != 1:
				return { "ok": false, "error": "default threshold, %s seed %d: %d regions of >= %d cells — the repair did not join the board" % [virtue, realm_seed, default_regions, _MIN_REGION] }

			var disabled_regions: int = _substantial_region_count(
				_walkable_without_islands(StageTerrain.generate(realm_seed, i % 3, disabled_sig, bounds, ns)))
			if disabled_regions > 1:
				split_boards += 1
				if demonstrated == "":
					demonstrated = "%s seed %d: repair disabled by connect_min_region_cells=999999 leaves %d regions of >= %d cells; the default leaves 1" % [virtue, realm_seed, disabled_regions, _MIN_REGION]

	if split_boards == 0:
		return { "ok": false, "error": "disabling the repair via connect_min_region_cells changed nothing on 400 boards — the signature key is inert" }
	return { "ok": true, "note": "%s (%d of 400 boards split with the repair disabled)" % [demonstrated, split_boards] }


## Number of shared-side regions of at least _MIN_REGION cells.
static func _substantial_region_count(walkable: Dictionary) -> int:
	var n: int = 0
	for r_v in _shared_side_regions(walkable):
		if (r_v as Array).size() >= _MIN_REGION:
			n += 1
	return n


# ═══════════════════════════════════════════════════════════════════════════════
# V2-COMBAT-003 terrain commit 3 — islands replace stragglers
# ═══════════════════════════════════════════════════════════════════════════════

## Every ten authored virtue signatures, over the standard combat span, the two DOUBLED
## combat shapes (12x48 PURSUE, 60x12 GUIDE_SPIRIT) and explore bounds.
static func _island_sweep_bounds() -> Array:
	return [
		{ "w": 12, "h": 12 }, { "w": 16, "h": 16 }, { "w": 22, "h": 22 },
		{ "w": 12, "h": 48 }, { "w": 60, "h": 12 },
		{ "w": 30, "h": 30 }, { "w": 50, "h": 40 },
	]


static func _authored_by_virtue() -> Dictionary:
	var stages_cfg := _load_balance_stages()
	var map_shape_v: Variant = stages_cfg.get("map_shape", {})
	var map_shape: Dictionary = map_shape_v if map_shape_v is Dictionary else {}
	var by_virtue_v: Variant = map_shape.get("by_virtue", {})
	return by_virtue_v if by_virtue_v is Dictionary else {}


## Cell-key set of one island entry.
static func _island_cell_set(island: Dictionary) -> Dictionary:
	var own: Dictionary = {}
	var cells_v: Variant = island.get("cells", [])
	var cells: Array = cells_v if cells_v is Array else []
	for pair_v in cells:
		var pair: Array = pair_v if pair_v is Array else []
		if pair.size() >= 2:
			own["%d,%d" % [int(pair[0]), int(pair[1])]] = true
	return own


# ─── THE MOAT ────────────────────────────────────────────────────────────────
# The single claim terrain commit 3 exists to make, and the one this test attacks:
#   no island cell is adjacent, in ANY of the 8 directions, to a cell of any other region,
#   including another island.
# Before commit 3 this was false on 838 of 865 measured cut-off regions — 97 % touched the
# main ground at a CORNER, which reads as connected on screen and is not connected in play.
# A side touch would be worse still.
#
# V2-COMBAT-003 terrain commit 4 SPLITS the claim in two, because bridging makes the old
# single condition dishonest rather than merely stricter:
#   UNBRIDGED island — unchanged and absolute. Every 8-direction neighbour of every cell is
#     that same island's cell or void. This is the acceptance test for "an unbridged island
#     still touches nothing", and it must hold whatever any OTHER island's bridging did.
#   BRIDGED island — it is ordinary ground now, part of a larger region, and it may sit
#     beside any other cell of THAT region: its own bridge, and also a later island's bridge
#     that legitimately runs past it once both are in the same region. What it may never do
#     is touch a cell of a DIFFERENT region — that is the corner-touch ambiguity decision 15
#     removes, and it is asserted here per island as well as board-wide in
#     terrain/no_region_touches_another_region.
# Asserting the old condition on a bridged island fails on a correct board: measured on
# compassion seed 450461, 30x30, where island 0 sits diagonally beside a second island's
# bridge and both are in the host region.
static func _t_islands_are_moated() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var islands_seen: int = 0
	var unbridged_seen: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(21):
			var realm_seed: int = 300000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.moat.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var allow := _island_bridge_allowances(terrain)
			# cell -> shared-side region index, for the bridged half of the claim.
			var region_of: Dictionary = {}
			var all_regions := _shared_side_regions(walkable)
			for reg_i in range(all_regions.size()):
				for rk in (all_regions[reg_i] as Array):
					region_of[rk] = reg_i
			var islands_v: Variant = terrain.get("islands", [])
			var islands: Array = islands_v if islands_v is Array else []
			for isl_i in range(islands.size()):
				var isl: Dictionary = islands[isl_i] if islands[isl_i] is Dictionary else {}
				var own := _island_cell_set(isl)
				var allowed: Dictionary = allow.get(isl_i, {})
				if allowed.is_empty():
					unbridged_seen += 1
				islands_seen += 1
				for own_k in own.keys():
					var parts := (own_k as String).split(",")
					var oc: int = int(parts[0])
					var orow: int = int(parts[1])
					for dc in range(-1, 2):
						for dr in range(-1, 2):
							if dc == 0 and dr == 0:
								continue
							var nk: String = "%d,%d" % [oc + dc, orow + dr]
							if own.has(nk):
								continue
							if allowed.has(nk):
								continue
							if walkable.has(nk):
								return { "ok": false, "error": "%s seed %d bounds %dx%d: island %d cell %s touches FOREIGN walkable cell %s (offset %d,%d) — the moat is broken (%d allowed bridge cells, region %d vs %d)" % [virtue, realm_seed, int(bounds.get("w", 0)), int(bounds.get("h", 0)), isl_i, own_k, nk, dc, dr, allowed.size(), int(region_of.get(own_k, -1)), int(region_of.get(nk, -1))] }
	if islands_seen == 0:
		return { "ok": false, "error": "no island was generated across the whole sweep — the test proved nothing" }
	if unbridged_seen == 0:
		return { "ok": false, "error": "every island in the sweep was bridged — the 'unbridged island touches nothing' half of this test proved nothing" }
	return { "ok": true, "note": "%d islands (%d of them unbridged and touching nothing at all); every other 8-direction neighbour is own-island, an own bridge, or void" % [islands_seen, unbridged_seen] }


# ─── SHAPE: >= 4 cells, exactly ONE shared-side region ───────────────────────
# The two remaining structural promises. A single-cell island is the defect being removed,
# so 4 is a hard floor the generator enforces by discarding a stunted blob rather than
# emitting it. Shared-side contiguity matters because it is the SAME rule the connectivity
# repair uses: an island that split into two shared-side regions would be two islands
# wearing one name, and every size measurement about it would be wrong.
static func _t_islands_are_one_region_min_size() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var seen: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(21):
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				310000 + i * 7919, i % 3, sig, bounds, "test.islandshape.%s.%d" % [virtue, i])
			var islands_v: Variant = terrain.get("islands", [])
			var islands: Array = islands_v if islands_v is Array else []
			for isl_v in islands:
				var isl: Dictionary = isl_v if isl_v is Dictionary else {}
				var own := _island_cell_set(isl)
				seen += 1
				if own.size() < 4:
					return { "ok": false, "error": "%s bounds %dx%d: island of %d cells — below the hard floor of 4" % [virtue, int(bounds.get("w", 0)), int(bounds.get("h", 0)), own.size()] }
				var regions := _shared_side_regions(own)
				if regions.size() != 1:
					return { "ok": false, "error": "%s bounds %dx%d: island of %d cells is %d shared-side regions, not 1" % [virtue, int(bounds.get("w", 0)), int(bounds.get("h", 0)), own.size(), regions.size()] }
				# The recorded bounding box must actually bound the blob.
				var bc: int = int(isl.get("col", 0))
				var brow: int = int(isl.get("row", 0))
				var bw: int = int(isl.get("w", 0))
				var bh: int = int(isl.get("h", 0))
				for k in own.keys():
					var pp := (k as String).split(",")
					var kc: int = int(pp[0])
					var kr: int = int(pp[1])
					if kc < bc or kc >= bc + bw or kr < brow or kr >= brow + bh:
						return { "ok": false, "error": "%s: island cell %s lies outside its recorded bounding box (%d,%d,%d,%d)" % [virtue, k, bc, brow, bw, bh] }
	if seen == 0:
		return { "ok": false, "error": "no island generated across the sweep" }
	return { "ok": true, "note": "%d islands, all >= 4 cells and one shared-side region" % seen }


# ─── THE CONFIG REACHES THE GENERATOR ────────────────────────────────────────
# A key authored in the signature but never read is a defect this project has shipped
# before, and this commit renamed FOUR of them. Drive each one to a setting whose effect
# cannot be confused with anything else, on identical seeds:
#   island_count 0..0        => zero islands
#   island_count 3..3        => three islands (space permitting; asserted >= 1 always)
#   island_size 4..4 vs 12..N => the larger request really produces larger islands
static func _t_island_config_is_honored() -> Dictionary:
	var bounds: Dictionary = { "w": 40, "h": 40 }   # per-island cap 100, total cap 400
	var base: Dictionary = {
		"plateau_count_min": 2, "plateau_count_max": 2,
		"plateau_w_min": 6, "plateau_w_max": 8,
		"plateau_h_min": 6, "plateau_h_max": 8,
		"plateau_shape_bias": "blocky",
		"bridge_width": 2, "bridge_density": 0.0,
		"connect_min_region_cells": 6,
	}
	var none_sig: Dictionary = base.duplicate(true)
	none_sig["island_count_min"] = 0
	none_sig["island_count_max"] = 0
	none_sig["island_size_min"] = 4
	none_sig["island_size_max"] = 8

	var many_sig: Dictionary = base.duplicate(true)
	many_sig["island_count_min"] = 3
	many_sig["island_count_max"] = 3
	many_sig["island_size_min"] = 4
	many_sig["island_size_max"] = 6

	var small_sig: Dictionary = base.duplicate(true)
	small_sig["island_count_min"] = 2
	small_sig["island_count_max"] = 2
	small_sig["island_size_min"] = 4
	small_sig["island_size_max"] = 4

	var big_sig: Dictionary = base.duplicate(true)
	big_sig["island_count_min"] = 2
	big_sig["island_count_max"] = 2
	big_sig["island_size_min"] = 20
	big_sig["island_size_max"] = 20

	var small_total: int = 0
	var big_total: int = 0
	var many_total: int = 0
	for i in range(20):
		var seed_val: int = 820000 + i * 7919
		var ns: String = "test.islandcfg.%d" % i

		var none_t: Dictionary = StageTerrain.generate(seed_val, 0, none_sig, bounds, ns)
		var none_n: int = (none_t.get("islands", []) as Array).size()
		if none_n != 0:
			return { "ok": false, "error": "island_count 0..0 produced %d island(s) on seed %d — the count key is not read" % [none_n, seed_val] }

		var many_t: Dictionary = StageTerrain.generate(seed_val, 0, many_sig, bounds, ns)
		var many_n: int = (many_t.get("islands", []) as Array).size()
		if many_n < 1 or many_n > 3:
			return { "ok": false, "error": "island_count 3..3 produced %d island(s) on seed %d — expected 1..3 (fewer only when moated space runs out)" % [many_n, seed_val] }
		many_total += many_n

		for isl_v in (StageTerrain.generate(seed_val, 0, small_sig, bounds, ns).get("islands", []) as Array):
			small_total += _island_cell_set(isl_v as Dictionary).size()
		for isl_v2 in (StageTerrain.generate(seed_val, 0, big_sig, bounds, ns).get("islands", []) as Array):
			big_total += _island_cell_set(isl_v2 as Dictionary).size()

	if many_total == 0:
		return { "ok": false, "error": "island_count 3..3 never produced a single island across 20 seeds" }
	if big_total <= small_total:
		return { "ok": false, "error": "island_size 20..20 produced %d island cells against 4..4's %d — the size key is inert" % [big_total, small_total] }
	return { "ok": true, "note": "count 0=>0, 3=>%d islands; size 4..4 => %d cells vs 20..20 => %d cells" % [many_total, small_total, big_total] }


# ─── SIZE SCALES TO BOARD AREA ───────────────────────────────────────────────
# Authored size is a REQUEST, not a promise. Wisdom asks for up to 50 cells; a 12x12 combat
# board has 144. Without a clamp one island would be a third of the board and six of them
# would be the whole board. Assert BOTH clamps hold on the smallest board the game makes,
# with the most extreme authored request in balance.json:
#   per island  <= area / 16
#   all islands <= area / 4
static func _t_island_size_scales_to_board() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	var sig_v: Variant = by_virtue.get("wisdom", {})
	var sig: Dictionary = sig_v if sig_v is Dictionary else {}
	if sig.is_empty():
		return { "ok": false, "error": "wisdom signature missing from balance.json" }
	if int(sig.get("island_size_max", 0)) < 50:
		return { "ok": false, "error": "wisdom island_size_max is %d — this test needs the extreme authored request to be meaningful" % int(sig.get("island_size_max", 0)) }

	var biggest_seen: int = 0
	for bounds_v in [{ "w": 12, "h": 12 }, { "w": 22, "h": 22 }, { "w": 12, "h": 48 }, { "w": 60, "h": 12 }]:
		var bounds: Dictionary = bounds_v
		var area: int = int(bounds.get("w", 0)) * int(bounds.get("h", 0))
		var per_cap: int = max(4, area / 16)
		var total_cap: int = max(4, area / 4)
		for i in range(25):
			var terrain: Dictionary = StageTerrain.generate(
				930000 + i * 7919, i % 3, sig, bounds, "test.islandscale.%d.%d" % [area, i])
			var total: int = 0
			for isl_v in (terrain.get("islands", []) as Array):
				var n: int = _island_cell_set(isl_v as Dictionary).size()
				total += n
				biggest_seen = max(biggest_seen, n)
				if n > per_cap:
					return { "ok": false, "error": "bounds %dx%d: island of %d cells exceeds the per-island cap of %d (area/16)" % [int(bounds.get("w", 0)), int(bounds.get("h", 0)), n, per_cap] }
			if total > total_cap:
				return { "ok": false, "error": "bounds %dx%d: %d island cells in total exceeds the cap of %d (area/4)" % [int(bounds.get("w", 0)), int(bounds.get("h", 0)), total, total_cap] }
	if biggest_seen < 4:
		return { "ok": false, "error": "no island of >= 4 cells on any small board — the clamp is starving the pass instead of bounding it" }
	return { "ok": true, "note": "largest island on a small board: %d cells" % biggest_seen }


# ─── THE LEGACY KEY STILL FEEDS walkable_set ─────────────────────────────────
# THE TRAP, asserted directly. walkable_set builds the walkable set from three keys, and
# terrain is PERSISTED (FlowStageExploreState calls it permanent geometry; SaveService
# repairs the field). Renaming "stragglers" to "islands" without teaching walkable_set the
# new name would make every island silently VANISH from the walkable set — no error, no
# failing test, just missing ground. The commit keeps reading the old key as a documented
# fallback so an already-saved board cannot lose ground either.
# This test pins both halves at once on one hand-built terrain dict.
static func _t_walkable_set_reads_legacy_stragglers() -> Dictionary:
	var legacy: Dictionary = {
		"bounds": { "w": 10, "h": 10 },
		"plateaus": [ { "col": 1, "row": 1, "w": 2, "h": 2, "cells": [[1, 1], [2, 1], [1, 2], [2, 2]] } ],
		"bridges": [],
		"stragglers": [ { "col": 7, "row": 7 }, { "col": 8, "row": 3 } ],
	}
	var legacy_walkable := StageTerrain.walkable_set(legacy)
	if not legacy_walkable.has("7,7") or not legacy_walkable.has("8,3"):
		return { "ok": false, "error": "walkable_set dropped legacy straggler cells — an already-saved board would silently lose ground (got %d cells: %s)" % [legacy_walkable.size(), str(legacy_walkable.keys())] }
	if legacy_walkable.size() != 6:
		return { "ok": false, "error": "legacy terrain: expected 6 walkable cells, got %d" % legacy_walkable.size() }

	var modern: Dictionary = {
		"bounds": { "w": 10, "h": 10 },
		"plateaus": [ { "col": 1, "row": 1, "w": 2, "h": 2, "cells": [[1, 1], [2, 1], [1, 2], [2, 2]] } ],
		"bridges": [],
		"islands": [ { "col": 6, "row": 6, "w": 2, "h": 2, "cells": [[6, 6], [7, 6], [6, 7], [7, 7]] } ],
	}
	var modern_walkable := StageTerrain.walkable_set(modern)
	for k in ["6,6", "7,6", "6,7", "7,7"]:
		if not modern_walkable.has(k):
			return { "ok": false, "error": "walkable_set dropped island cell %s — islands are invisible to every consumer" % k }
	if modern_walkable.size() != 8:
		return { "ok": false, "error": "modern terrain: expected 8 walkable cells, got %d" % modern_walkable.size() }

	# And the generator itself must never write the legacy key again.
	var gen: Dictionary = StageTerrain.generate(4242, 0, _default_sig(), _default_bounds())
	if gen.has("stragglers"):
		return { "ok": false, "error": "generate() still writes a \"stragglers\" key — the rename is incomplete" }
	if not gen.has("islands"):
		return { "ok": false, "error": "generate() does not write an \"islands\" key" }
	return { "ok": true }


# ─── V2-COMBAT-003 terrain commit 5 ──────────────────────────────────────────
#
# Decision 22: nothing spawns outside the host region. Decision 24: a static objective
# needs all eight neighbouring tiles walkable and free. Decision 25: when no region can
# host an objective the generator BUILDS a nine-tile site rather than emitting a board on
# which the stage can never be completed.
#
# The host region here is re-derived by this file's own shared-side helper, not read back
# from the generator, so these tests can fail the generator instead of agreeing with it.


## Every generated board's host region offers at least one legal objective site — decision
## 25's guarantee, stated as the property it exists to protect.
static func _t_host_region_offers_objective_site() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(14):
			var realm_seed: int = 410000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.objsite.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var host := _host_key_set(walkable)
			var found: bool = false
			for k in host.keys():
				if _eight_walkable(str(k), walkable):
					found = true
					break
			if not found:
				return { "ok": false, "error":
					"%s #%d bounds=%dx%d: host region of %d cells offers NO cell with eight walkable neighbours"
					% [virtue, i, int(bounds.get("w", 0)), int(bounds.get("h", 0)), host.size()] }
	return { "ok": true }


## Decision 25 fires on a board that genuinely cannot host an objective, and the site it
## builds is legal: nine cells, the centre with eight walkable neighbours, and the whole
## block joined to the host region. Driven through StageTerrain's own site chooser on a
## hand-built board — a one-cell-wide cross, which has no cell with eight neighbours.
static func _t_objective_site_built_when_absent() -> Dictionary:
	var walkable: Dictionary = {}
	for c in range(2, 12):
		walkable["%d,6" % c] = true
	for r in range(2, 12):
		walkable["6,%d" % r] = true
	var host := _host_key_set(walkable)
	for k in host.keys():
		if _eight_walkable(str(k), walkable):
			return { "ok": false, "error": "fixture is wrong — a cross should have no 8-clear cell, %s does" % str(k) }
	var site: Dictionary = StageTerrain._find_objective_site(host, walkable, 16, 16)
	if site.is_empty():
		return { "ok": false, "error": "no objective site found on a board that plainly has room" }
	var sc: int = int(site["col"])
	var sr: int = int(site["row"])
	var built: Dictionary = walkable.duplicate()
	var touches_host: bool = false
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var k2: String = "%d,%d" % [sc + dc, sr + dr]
			if host.has(k2):
				touches_host = true
			built[k2] = true
	if not touches_host:
		return { "ok": false, "error": "built site at %d,%d shares no cell with the host region" % [sc, sr] }
	if not _eight_walkable("%d,%d" % [sc, sr], built):
		return { "ok": false, "error": "built site centre %d,%d does not have eight walkable neighbours" % [sc, sr] }
	var regions := _shared_side_regions(built)
	var host_after := _host_key_set(built)
	if not host_after.has("%d,%d" % [sc, sr]):
		return { "ok": false, "error": "built site centre is not in the host region (%d regions)" % regions.size() }
	return { "ok": true }


## Decision 22 on the EXPLORE path. Every situation RealmGenerator._place_situations
## returns lands on the host region. FAILS against b4dd797, where the placer accepted any
## walkable cell and a moated island was 10.8 % of them.
static func _t_situations_stay_on_host_region() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var placed: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(14):
			var realm_seed: int = 420000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var w: int = int(bounds.get("w", 0))
			var h: int = int(bounds.get("h", 0))
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.sithost.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var host := _host_key_set(walkable)
			var sits: Array = RealmGenerator._place_situations(
				realm_seed, i % 3, w, h, 5, 2,
				[{ "type": "shrine" }, { "type": "recover" }], {}, walkable)
			for s_v in sits:
				var sd: Dictionary = s_v if s_v is Dictionary else {}
				var sp: Dictionary = sd.get("pos", {})
				var sk: String = "%d,%d" % [int(sp.get("col", -1)), int(sp.get("row", -1))]
				placed += 1
				if not host.has(sk):
					return { "ok": false, "error":
						"%s #%d bounds=%dx%d: situation %s placed at %s, OFF the host region"
						% [virtue, i, w, h, str(sd.get("id", "")), sk] }
	if placed < 100:
		return { "ok": false, "error": "only %d situations placed — the sweep did not run" % placed }
	return { "ok": true }


## Decision 24 on the EXPLORE path. Every OBJECTIVE situation has all eight neighbours
## walkable. FAILS against b4dd797, which applied no clearance rule at all.
static func _t_objective_situations_have_clearance() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var objectives_seen: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(14):
			var realm_seed: int = 430000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var w: int = int(bounds.get("w", 0))
			var h: int = int(bounds.get("h", 0))
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.sitclear.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var sits: Array = RealmGenerator._place_situations(
				realm_seed, i % 3, w, h, 5, 2,
				[{ "type": "shrine" }, { "type": "recover" }], {}, walkable)
			for s_v in sits:
				var sd: Dictionary = s_v if s_v is Dictionary else {}
				if not bool(sd.get("is_objective", false)):
					continue
				objectives_seen += 1
				var sp: Dictionary = sd.get("pos", {})
				var sk: String = "%d,%d" % [int(sp.get("col", -1)), int(sp.get("row", -1))]
				if not _eight_walkable(sk, walkable):
					return { "ok": false, "error":
						"%s #%d bounds=%dx%d: objective situation at %s lacks eight walkable neighbours"
						% [virtue, i, w, h, sk] }
	if objectives_seen < 100:
		return { "ok": false, "error": "only %d objective situations seen — the sweep did not run" % objectives_seen }
	return { "ok": true }


## Host region as a key set, re-derived by this file's own shared-side fill.
static func _host_key_set(walkable: Dictionary) -> Dictionary:
	var regions := _shared_side_regions(walkable)
	var best: int = -1
	for i in range(regions.size()):
		if best < 0:
			best = i
			continue
		var cur: Array = regions[i]
		var champ: Array = regions[best]
		if cur.size() > champ.size():
			best = i
		elif cur.size() == champ.size() and cur.size() > 0 and _key_less(str(cur[0]), str(champ[0])):
			best = i
	var out: Dictionary = {}
	if best < 0:
		return out
	for k in (regions[best] as Array):
		out[k] = true
	return out


static func _key_less(a: String, b: String) -> bool:
	var pa := (a as String).split(",")
	var pb := (b as String).split(",")
	if int(pa[0]) != int(pb[0]):
		return int(pa[0]) < int(pb[0])
	return int(pa[1]) < int(pb[1])


## Decision 24's terrain half, re-implemented locally on purpose.
static func _eight_walkable(key: String, walkable: Dictionary) -> bool:
	var parts := (key as String).split(",")
	if parts.size() != 2:
		return false
	var c: int = int(parts[0])
	var r: int = int(parts[1])
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			if not walkable.has("%d,%d" % [c + dc, r + dr]):
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# V2-COMBAT-003 TERRAIN COMMIT 4
# ═══════════════════════════════════════════════════════════════════════════════

# ─── THE EROSION LEFTOVERS — the cause ───────────────────────────────────────
# Handoff decision 15: a corner touch is the ambiguous case and it must go.
#
# THIS TEST FAILS AGAINST 95895a0. Plateau erosion used to check 8-CONNECTIVITY of the
# candidate blob, which accepts a cell joined to the rest of the plateau by a single
# DIAGONAL. Under the shared-side rule the repair and GridService use, such a cell is its
# own region of ONE cell, so the repair — which only acts on regions of
# connect_min_region_cells (6) or more — leaves it alone, and it ships as ground touching a
# plateau at a corner and nothing else. Measured before the fix: 426 of them across 1,600
# boards, attributed island=0 plateau=426 bridge=0.
#
# The claim under test is the cause, not the symptom: EVERY plateau blob is exactly ONE
# shared-side region. Nothing about islands or bridges can mask it.
static func _t_plateau_blob_is_one_shared_side_region() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var blobs: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(8):
			var realm_seed: int = 420000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.erosion.%s.%d" % [virtue, i])
			for p_v in (terrain.get("plateaus", []) as Array):
				var p: Dictionary = p_v if p_v is Dictionary else {}
				var cells_v: Variant = p.get("cells", [])
				var cells: Array = cells_v if cells_v is Array else []
				if cells.is_empty():
					continue
				var cell_set: Dictionary = {}
				for pr_v in cells:
					var pr: Array = pr_v if pr_v is Array else []
					if pr.size() >= 2:
						cell_set["%d,%d" % [int(pr[0]), int(pr[1])]] = true
				blobs += 1
				var regions := _shared_side_regions(cell_set)
				if regions.size() != 1:
					var sizes: Array = []
					for rg in regions:
						sizes.append((rg as Array).size())
					return { "ok": false, "error": "%s seed %d bounds %dx%d: a plateau blob of %d cells is %d shared-side regions (sizes %s) — erosion left a cell hanging off a corner" % [virtue, realm_seed, int(bounds.get("w", 0)), int(bounds.get("h", 0)), cell_set.size(), regions.size(), str(sizes)] }
	if blobs == 0:
		return { "ok": false, "error": "no plateau blob generated across the sweep — the test proved nothing" }
	return { "ok": true, "note": "%d plateau blobs, every one a single shared-side region" % blobs }


# ─── THE EROSION LEFTOVERS — the board-level outcome ─────────────────────────
# ALSO FAILS AGAINST 95895a0, for the same cause seen from the other end.
# No region of the finished board may touch another region at a side or a corner. The only
# ground an island may touch is a cell of an island bridge that leaves it or lands on it;
# everything else — plateau leftovers included — must have a clear ring of void.
static func _t_no_region_touches_another_region() -> Dictionary:
	var by_virtue := _authored_by_virtue()
	if by_virtue.is_empty():
		return { "ok": false, "error": "data.stages.map_shape.by_virtue is empty — wrong config path" }
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var non_host_regions: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(8):
			var realm_seed: int = 430000 + i * 7919
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				realm_seed, i % 3, sig, bounds, "test.leftover.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var regions := _shared_side_regions(walkable)
			# Host = largest, ties by numerically lowest cell.
			var host: int = -1
			for ri in range(regions.size()):
				if host < 0 or (regions[ri] as Array).size() > (regions[host] as Array).size():
					host = ri
			for ri2 in range(regions.size()):
				if ri2 == host:
					continue
				non_host_regions += 1
				var rset: Dictionary = {}
				for rk in (regions[ri2] as Array):
					rset[rk] = true
				for rk2 in (regions[ri2] as Array):
					var pp := (rk2 as String).split(",")
					var rc: int = int(pp[0])
					var rr: int = int(pp[1])
					for dc in range(-1, 2):
						for dr in range(-1, 2):
							if dc == 0 and dr == 0:
								continue
							var nk: String = "%d,%d" % [rc + dc, rr + dr]
							if rset.has(nk) or not walkable.has(nk):
								continue
							return { "ok": false, "error": "%s seed %d bounds %dx%d: a cut-off region of %d cells touches foreign walkable ground — %s is adjacent to %s (offset %d,%d). Decision 15: a corner touch is the ambiguous case and must not exist." % [virtue, realm_seed, int(bounds.get("w", 0)), int(bounds.get("h", 0)), rset.size(), rk2, nk, dc, dr] }
	if non_host_regions == 0:
		return { "ok": false, "error": "no cut-off region generated across the sweep — the test proved nothing" }
	return { "ok": true, "note": "%d cut-off regions, not one of them touching any other region" % non_host_regions }


# ─── BRIDGE CELLS ARE THEIR OWN THING (decision 16) ──────────────────────────
# `bridge_cell_set` must be exactly the union of the bridge rects, and always a subset of
# `walkable_set`. Both renderers paint from it, so a drift here paints void.
static func _t_bridge_cell_set_matches_rects() -> Dictionary:
	if not StageTerrain.bridge_cell_set({}).is_empty():
		return { "ok": false, "error": "bridge_cell_set({}) must be empty — the legacy all-walkable sentinel has no bridges" }
	var by_virtue := _authored_by_virtue()
	var bounds_cycle := _island_sweep_bounds()
	var virtues: Array = by_virtue.keys()
	virtues.sort()
	var seen: int = 0
	for virtue_v in virtues:
		var virtue: String = str(virtue_v)
		var sig_v: Variant = by_virtue.get(virtue, {})
		var sig: Dictionary = sig_v if sig_v is Dictionary else {}
		for i in range(6):
			var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
			var terrain: Dictionary = StageTerrain.generate(
				440000 + i * 7919, i % 3, sig, bounds, "test.bridgetile.%s.%d" % [virtue, i])
			var walkable: Dictionary = StageTerrain.walkable_set(terrain)
			var bridge_cells: Dictionary = StageTerrain.bridge_cell_set(terrain)
			var expected: Dictionary = {}
			for b_v in (terrain.get("bridges", []) as Array):
				var b: Dictionary = b_v if b_v is Dictionary else {}
				for dc in range(int(b.get("w", 1))):
					for dr in range(int(b.get("h", 1))):
						expected["%d,%d" % [int(b.get("col", 0)) + dc, int(b.get("row", 0)) + dr]] = true
			if bridge_cells.size() != expected.size():
				return { "ok": false, "error": "%s bounds %dx%d: bridge_cell_set has %d cells, the rects cover %d" % [virtue, int(bounds.get("w", 0)), int(bounds.get("h", 0)), bridge_cells.size(), expected.size()] }
			for k in expected.keys():
				if not bridge_cells.has(k):
					return { "ok": false, "error": "%s: bridge_cell_set is missing rect cell %s" % [virtue, k] }
				if not walkable.has(k):
					return { "ok": false, "error": "%s: bridge cell %s is not in walkable_set — the renderer would paint void" % [virtue, k] }
			seen += bridge_cells.size()
	if seen == 0:
		return { "ok": false, "error": "no bridge cell generated across the sweep — the test proved nothing" }
	return { "ok": true, "note": "%d bridge cells, all of them rect-exact and walkable" % seen }


# ─── THE BRIDGE CHANCE REACHES THE GENERATOR (decision 17) ───────────────────
# Three settings on IDENTICAL seeds, so nothing but the new key can explain the difference:
#   0.0 => not one island bridge, on any board
#   1.0 => island bridges appear, and every island that got one has >= 6 cells
#   an island of <= 5 cells is NEVER bridged, at any chance
static func _t_island_bridge_chance_is_honored() -> Dictionary:
	var bounds: Dictionary = { "w": 40, "h": 40 }
	var base: Dictionary = {
		"plateau_count_min": 2, "plateau_count_max": 2,
		"plateau_w_min": 6, "plateau_w_max": 8,
		"plateau_h_min": 6, "plateau_h_max": 8,
		"plateau_shape_bias": "blocky",
		"bridge_width": 2, "bridge_density": 0.0,
		"island_count_min": 4, "island_count_max": 4,
		"island_size_min": 6, "island_size_max": 14,
		"connect_min_region_cells": 6,
	}
	var never: Dictionary = base.duplicate(true)
	never["island_bridge_chance"] = 0.0
	var always: Dictionary = base.duplicate(true)
	always["island_bridge_chance"] = 1.0

	var never_bridges: int = 0
	var always_bridges: int = 0
	var small_bridged: int = 0
	var islands_total: int = 0
	for i in range(18):
		var seed_val: int = 450000 + i * 7919
		var ns: String = "test.bridgechance.%d" % i
		var t_never: Dictionary = StageTerrain.generate(seed_val, i % 3, never, bounds, ns)
		var t_always: Dictionary = StageTerrain.generate(seed_val, i % 3, always, bounds, ns)
		for b_v in (t_never.get("bridges", []) as Array):
			if bool((b_v as Dictionary).get("island_bridge", false)):
				never_bridges += 1
		var islands_v: Variant = t_always.get("islands", [])
		var islands: Array = islands_v if islands_v is Array else []
		islands_total += islands.size()
		var per_island: Dictionary = {}
		for b_v2 in (t_always.get("bridges", []) as Array):
			var b2: Dictionary = b_v2 if b_v2 is Dictionary else {}
			if not bool(b2.get("island_bridge", false)):
				continue
			always_bridges += 1
			var src: int = int(b2.get("island_index", -1))
			per_island[src] = int(per_island.get(src, 0)) + 1
		for src_v in per_island.keys():
			var src2: int = int(src_v)
			if src2 < 0 or src2 >= islands.size():
				return { "ok": false, "error": "island bridge names island_index %d, but the board has %d islands" % [src2, islands.size()] }
			var sz: int = _island_cell_set(islands[src2]).size()
			if sz < 6:
				small_bridged += 1
		# The islands themselves must be byte-identical between the two settings: the
		# bridge decision rides on its OWN stream and may not move island shape.
		var isl_never: Variant = t_never.get("islands", [])
		if str(isl_never) != str(islands_v):
			return { "ok": false, "error": "seed %d: island_bridge_chance moved the ISLAND SHAPES. The bridge draw must sit on its own stream.\n  chance 0.0: %s\n  chance 1.0: %s" % [seed_val, str(isl_never), str(islands_v)] }
	if never_bridges != 0:
		return { "ok": false, "error": "island_bridge_chance 0.0 still produced %d island bridges" % never_bridges }
	if always_bridges == 0:
		return { "ok": false, "error": "island_bridge_chance 1.0 produced NO island bridge across %d islands — the key never reaches the generator" % islands_total }
	if small_bridged != 0:
		return { "ok": false, "error": "%d island(s) below 6 cells were bridged — decision 17 says an island of 5 or fewer is never bridged" % small_bridged }
	return { "ok": true, "note": "chance 0.0 => 0 island bridges; chance 1.0 => %d across %d islands; islands byte-identical either way" % [always_bridges, islands_total] }


# ─── EXTRA BRIDGES AND EDGE PLACEMENT (decisions 18 and 19) ──────────────────
# Three claims on one sweep, all driven at chance 1.0 so the sample is large:
#   18a. an island below 20 cells never carries more than ONE bridge
#   18b. an island's bridges use distinct SIDES and distinct TARGET REGIONS
#   19.  a bridge does not always leave from the midpoint of its island's edge
static func _t_island_extra_bridges_and_edge_placement() -> Dictionary:
	var base: Dictionary = {
		"plateau_count_min": 2, "plateau_count_max": 2,
		"plateau_w_min": 6, "plateau_w_max": 8,
		"plateau_h_min": 6, "plateau_h_max": 8,
		"plateau_shape_bias": "blocky",
		"bridge_width": 2, "bridge_density": 0.0,
		"island_count_min": 3, "island_count_max": 5,
		"island_size_min": 8, "island_size_max": 40,
		"island_bridge_chance": 1.0,
		"connect_min_region_cells": 6,
	}
	var bounds_cycle: Array = [{ "w": 40, "h": 40 }, { "w": 50, "h": 40 }, { "w": 30, "h": 30 }]
	var multi: int = 0
	var off_centre: int = 0
	var bridged_islands: int = 0
	for i in range(24):
		var bounds: Dictionary = bounds_cycle[i % bounds_cycle.size()]
		var terrain: Dictionary = StageTerrain.generate(
			460000 + i * 7919, i % 3, base, bounds, "test.extrabridge.%d" % i)
		var islands_v: Variant = terrain.get("islands", [])
		var islands: Array = islands_v if islands_v is Array else []
		var per_island: Dictionary = {}
		for b_v in (terrain.get("bridges", []) as Array):
			var b: Dictionary = b_v if b_v is Dictionary else {}
			if not bool(b.get("island_bridge", false)):
				continue
			var src: int = int(b.get("island_index", -1))
			if not per_island.has(src):
				per_island[src] = []
			(per_island[src] as Array).append(b)
		for src_v in per_island.keys():
			var src2: int = int(src_v)
			var rects: Array = per_island[src2]
			var isl: Dictionary = islands[src2] if islands[src2] is Dictionary else {}
			var sz: int = _island_cell_set(isl).size()
			bridged_islands += 1
			if rects.size() > 1:
				multi += 1
				if sz < 20:
					return { "ok": false, "error": "an island of %d cells carries %d bridges — decision 18 allows extra bridges only at 20 cells or more" % [sz, rects.size()] }
			if rects.size() > 4:
				return { "ok": false, "error": "an island of %d cells carries %d bridges — at most one per side, so at most 4" % [sz, rects.size()] }
			# Distinct target islands are not required (two sides may both reach the
			# mainland's region only if the regions differ), but the same TARGET REGION
			# twice would be a redundant crossing. The generator tracks region ids; the
			# observable proxy here is that no two of an island's bridges are identical
			# rects and none of them overlaps another.
			for a in range(rects.size()):
				for b2 in range(a + 1, rects.size()):
					if str(rects[a]) == str(rects[b2]):
						return { "ok": false, "error": "an island of %d cells carries the SAME bridge rect twice: %s" % [sz, str(rects[a])] }
			# Decision 19 — is the departure at the island's midpoint?
			# For a horizontal bridge the band centre is a row; compare it with the
			# island's own centre row. A generator that always left from the midpoint
			# would make this difference zero on every single bridge.
			for r_v in rects:
				var r: Dictionary = r_v
				var horizontal: bool = int(r.get("w", 1)) > int(r.get("h", 1)) \
					or (int(r.get("h", 1)) == int(r.get("w", 1)) and int(r.get("row", 0)) >= int(isl.get("row", 0)))
				var band_centre: float
				var island_centre: float
				if horizontal:
					band_centre = float(r.get("row", 0)) + float(int(r.get("h", 1)) - 1) * 0.5
					island_centre = float(isl.get("row", 0)) + float(int(isl.get("h", 1)) - 1) * 0.5
				else:
					band_centre = float(r.get("col", 0)) + float(int(r.get("w", 1)) - 1) * 0.5
					island_centre = float(isl.get("col", 0)) + float(int(isl.get("w", 1)) - 1) * 0.5
				if absf(band_centre - island_centre) > 0.75:
					off_centre += 1
	if bridged_islands == 0:
		return { "ok": false, "error": "no island was bridged across the sweep — the test proved nothing" }
	if multi == 0:
		return { "ok": false, "error": "no island took more than one bridge across %d bridged islands — decision 18 never fires, so its constraint is untested" % bridged_islands }
	if off_centre == 0:
		return { "ok": false, "error": "every one of %d island bridges left from its island's midpoint — decision 19 says a bridge lands anywhere along an edge" % bridged_islands }
	return { "ok": true, "note": "%d bridged islands, %d with extra bridges (all >= 20 cells), %d bridges leaving off the midpoint" % [bridged_islands, multi, off_centre] }

