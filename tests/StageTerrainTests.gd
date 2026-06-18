# res://tests/StageTerrainTests.gd
# V2-STAGE-004 Phase 2 — Tests for StageTerrain (pure-static).
#
# Tests:
#   1.  terrain/determinism_generate      — same (seed,idx,sig,bounds) => deep-equal output
#   2.  terrain/connectivity_single_comp  — walkable_set is one connected component (~20 seeds)
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
		"straggler_count_min": 2,
		"straggler_count_max": 4,
	}

static func _default_bounds() -> Dictionary:
	return { "w": 30, "h": 30 }


# Deep-equality check for two terrain dicts (plateaus/bridges/stragglers arrays).
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
	for key in ["plateaus", "bridges", "stragglers"]:
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
	# New irregularity tests (V2-STAGE-004 Phase 2).
	runner.register_test("terrain/plateaus_are_irregular",           Callable(StageTerrainTests, "_t_plateaus_are_irregular"))
	runner.register_test("terrain/single_plateau_irregular_island",  Callable(StageTerrainTests, "_t_single_plateau_irregular_island"))
	# Integration guards — exercise the REAL balance.json config path (catch wiring bugs the
	# synthetic-config tests above cannot).
	runner.register_test("terrain/integration_virtue_signature",    Callable(StageTerrainTests, "_t_integration_virtue_signature"))
	runner.register_test("terrain/integration_situation_category",  Callable(StageTerrainTests, "_t_integration_situation_category"))
	runner.register_test("terrain/integration_generate_uses_virtue", Callable(StageTerrainTests, "_t_integration_generate_uses_virtue"))


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


# ─── Test 2 — CONNECTIVITY: walkable set is a single connected component ─────
# Critical guard — a bridge generation bug made components disjoint.
static func _t_connectivity_single_comp() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in range(1, 21):  # 20 seeds
		var terrain: Dictionary = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		if walkable.is_empty():
			return { "ok": false, "error": "Seed %d: walkable_set is empty" % seed_val }
		var reachable_count := _flood_fill_count(walkable)
		if reachable_count != walkable.size():
			return { "ok": false, "error": "Seed %d: walkable set has %d cells but flood-fill reached only %d — disconnected component found" % [seed_val, walkable.size(), reachable_count] }
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
		"straggler_count_min": 0, "straggler_count_max": 1,
	}
	var high_sig := {
		"plateau_count_min": 6,
		"plateau_count_max": 8,
		"plateau_w_min": 4, "plateau_w_max": 8,
		"plateau_h_min": 4, "plateau_h_max": 8,
		"bridge_width": 2, "bridge_density": 0.2,
		"straggler_count_min": 0, "straggler_count_max": 1,
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


# ─── Test 8 — ENTRY CELL: at the leftmost walkable column ───────────────────
static func _t_entry_cell_min_col() -> Dictionary:
	var sig    := _default_sig()
	var bounds := _default_bounds()
	for seed_val in [1, 42, 1000]:
		var terrain: Dictionary  = StageTerrain.generate(seed_val, 0, sig, bounds)
		var walkable: Dictionary = StageTerrain.walkable_set(terrain)
		var entry: Dictionary    = StageTerrain.entry_cell(walkable, bounds)
		var entry_col := int(entry.get("col", -1))
		# Find true minimum col in walkable
		var min_col := 999999
		for key in walkable:
			var parts := (key as String).split(",")
			var c := int(parts[0])
			if c < min_col:
				min_col = c
		if entry_col != min_col:
			return { "ok": false, "error": "Seed %d: entry_cell col %d != min_col %d" % [seed_val, entry_col, min_col] }
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
		"straggler_count_min": 0,
		"straggler_count_max": 0,
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
