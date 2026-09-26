# res://tools/BoardSizeOptionsProbe.gd
#
# INVESTIGATION TOOL — not a test, not wired into ui/AppRoot.gd. Standalone `--script` runner
# so it needs no UI wiring at all (mechanics-developer scope excludes ui/).
#
# Run:
#   godot --headless --script res://tools/BoardSizeOptionsProbe.gd --quit
#
# V2-COMBAT-003.5 Phase 2c — MEASUREMENT ONLY. Answers, for Courage (realm.01) and Wisdom
# (realm.02) at completion_index = 0 (fresh realm, board = base_cols x base_rows = 12x12,
# confirmed at EncounterSetupService.gd:322-333), what each of the three recorded options
# would produce. It does not change core/combat/EncounterSetupService.gd or any signature in
# data/balance.json. Mutates nothing, writes no save, asserts nothing.
#
# Reads data.stages.map_shape.by_virtue and data.combat.board straight off disk through the
# same raw-JSON helper tools/TerrainRegionProbe.gd uses, and drives StageTerrain.generate —
# the real production entry point — directly. Per docs/LESSONS.md #17: a probe that builds
# ConfigService fresh (empty balance) or samples one realm produces meaningless numbers; this
# probe avoids both mistakes.
#
# Scenarios per virtue:
#   current_12   — board 12x12 (the completion_index=0 board at measurement time), signature UNCHANGED.
#                  This is option 3, the do-nothing baseline.
#   base_16      — board 16x16, signature UNCHANGED. Option 1, candidate base_cols/rows=16.
#   base_18      — board 18x18, signature UNCHANGED. Option 1, candidate base_cols/rows=18.
#   scaled_12    — board 12x12, signature SCALED DOWN by (12/22) — 22 being max_cols/max_rows,
#                  i.e. treating the authored plateau/island sizes as tuned for the largest
#                  board and linearly scaling them to the smallest. ASSUMPTION: no reference
#                  board size is recorded anywhere for what the authored sizes target: this
#                  probe picks max_cols/max_rows (22) because it is the only other sized
#                  quantity in data.combat.board. A different reference would change the
#                  scaled_12 numbers; the current_12 and base_16/18 numbers do not depend on it.
#
# For every board this measures, per plateau: the ACTUAL w/h StageTerrain placed (after the
# "shrink to fit inside bounds minus border margin" path at StageTerrain.gd:359-367) and the
# ACTUAL cell count after eroding the blob. Per island: the ACTUAL cell count after the
# per-island / total-island area clamp (StageTerrain.gd:583-591). It also flood-fills the
# plateau-only cell set (shared-side, 4-direction) to count how many DISTINCT plateau regions
# survive placement — authored plateau_count minted N plateaus, but overlapping placement can
# merge two into one visible mass, which is exactly the "not distinguishable" failure mode.

extends SceneTree


const BOARDS_PER_SCENARIO: int = 50
const REFERENCE_BOARD_DIM: int = 22  # data.combat.board.max_cols / max_rows — see header.

const VIRTUES: Array = ["courage", "wisdom"]


func _initialize() -> void:
	print("")
	print("================================================================")
	print(" BOARD SIZE OPTIONS PROBE — V2-COMBAT-003.5 Phase 2c (measure only)")
	print("================================================================")

	var balance := _load_balance()
	var data: Dictionary = balance.get("data", {}) as Dictionary
	var stages_cfg: Dictionary = data.get("stages", {}) as Dictionary
	var map_shape: Dictionary = stages_cfg.get("map_shape", {}) as Dictionary
	var by_virtue: Dictionary = map_shape.get("by_virtue", {}) as Dictionary
	var combat_cfg: Dictionary = (data.get("combat", {}) as Dictionary).get("board", {}) as Dictionary

	if by_virtue.is_empty():
		print("FAIL: data.stages.map_shape.by_virtue is empty — wrong config path.")
		quit(1)
		return

	var base_cols: int = int(combat_cfg.get("base_cols", 18))
	var base_rows: int = int(combat_cfg.get("base_rows", 18))
	print("Confirmed from data.combat.board: base_cols=%d base_rows=%d (this IS the board at completion_index=0)"
		% [base_cols, base_rows])

	for virtue in VIRTUES:
		if not by_virtue.has(virtue):
			print("SKIP: virtue '%s' not found in data.stages.map_shape.by_virtue" % virtue)
			continue
		var sig: Dictionary = (by_virtue[virtue] as Dictionary).duplicate(true)
		print("")
		print("################################################################")
		print(" VIRTUE: %s" % virtue)
		print("################################################################")
		print("  authored plateau_count: %d-%d   plateau_w: %d-%d  plateau_h: %d-%d  bias=%s"
			% [int(sig.get("plateau_count_min", 0)), int(sig.get("plateau_count_max", 0)),
				int(sig.get("plateau_w_min", 0)), int(sig.get("plateau_w_max", 0)),
				int(sig.get("plateau_h_min", 0)), int(sig.get("plateau_h_max", 0)),
				str(sig.get("plateau_shape_bias", ""))])
		print("  authored island_count: %d-%d    island_size: %d-%d   bridge_density=%.2f"
			% [int(sig.get("island_count_min", 0)), int(sig.get("island_count_max", 0)),
				int(sig.get("island_size_min", 0)), int(sig.get("island_size_max", 0)),
				float(sig.get("bridge_density", 0.0))])

		_run_scenario("current_12 (OPTION 3 — baseline, today's behaviour)", virtue, sig,
			{ "w": base_cols, "h": base_rows })
		_run_scenario("base_16 (OPTION 1 candidate — base_cols/rows=16)", virtue, sig,
			{ "w": 16, "h": 16 })
		_run_scenario("base_18 (OPTION 1 candidate — base_cols/rows=18)", virtue, sig,
			{ "w": 18, "h": 18 })
		_run_scenario("scaled_12 (OPTION 2 — signature scaled to 12x12, see header ASSUMPTION)",
			virtue, _scaled_signature(sig, base_cols, base_rows), { "w": base_cols, "h": base_rows })

	print("")
	print("Done.")
	quit(0)


## Linearly scales plateau w/h and island size ranges from REFERENCE_BOARD_DIM down to the
## target board. StageTerrain still applies its own floors (plateau w/h >= 2, island size
## floor 4), so a scaled value below those floors is not a bug in this probe — it IS the
## "shrinks to nothing" finding the story asks for.
func _scaled_signature(sig: Dictionary, target_w: int, target_h: int) -> Dictionary:
	var out: Dictionary = sig.duplicate(true)
	var fw: float = float(target_w) / float(REFERENCE_BOARD_DIM)
	var fh: float = float(target_h) / float(REFERENCE_BOARD_DIM)
	var f_area: float = sqrt(fw * fh)
	out["plateau_w_min"] = maxi(2, roundi(float(sig.get("plateau_w_min", 4)) * fw))
	out["plateau_w_max"] = maxi(2, roundi(float(sig.get("plateau_w_max", 8)) * fw))
	out["plateau_h_min"] = maxi(2, roundi(float(sig.get("plateau_h_min", 4)) * fh))
	out["plateau_h_max"] = maxi(2, roundi(float(sig.get("plateau_h_max", 8)) * fh))
	out["island_size_min"] = maxi(1, roundi(float(sig.get("island_size_min", 4)) * f_area))
	out["island_size_max"] = maxi(1, roundi(float(sig.get("island_size_max", 8)) * f_area))
	return out


func _run_scenario(label: String, virtue: String, sig: Dictionary, bounds: Dictionary) -> void:
	var w: int = int(bounds.get("w", 12))
	var h: int = int(bounds.get("h", 12))
	var board_area: int = w * h
	var per_island_cap: int = maxi(4, board_area / 16)
	var total_island_cap: int = maxi(4, board_area / 4)

	var plateau_w_samples: Array = []
	var plateau_h_samples: Array = []
	var plateau_cell_samples: Array = []
	var plateau_shrunk: int = 0
	var plateau_authored_total: int = 0
	var plateau_region_counts: Array = []

	var island_cell_samples: Array = []
	var island_clamped: int = 0
	var island_authored_total: int = 0

	var authored_w_min: int = int(sig.get("plateau_w_min", 0))
	var authored_h_min: int = int(sig.get("plateau_h_min", 0))

	for i in range(BOARDS_PER_SCENARIO):
		var realm_seed: int = 2000000 + i * 7919
		var stage_index: int = i % 3
		var terrain: Dictionary = StageTerrain.generate(
			realm_seed, stage_index, sig, bounds,
			"probe.boardsize.%s.%d" % [virtue, i]
		)

		var plateaus: Array = terrain.get("plateaus", []) as Array
		plateau_authored_total += plateaus.size()
		var plateau_walkable: Dictionary = {}
		for p_v in plateaus:
			var p: Dictionary = p_v as Dictionary
			var pw: int = int(p.get("w", 0))
			var ph: int = int(p.get("h", 0))
			plateau_w_samples.append(pw)
			plateau_h_samples.append(ph)
			if pw < authored_w_min or ph < authored_h_min:
				plateau_shrunk += 1
			var cells: Array = p.get("cells", []) as Array
			plateau_cell_samples.append(cells.size())
			for c_v in cells:
				var c: Array = c_v
				plateau_walkable["%d,%d" % [int(c[0]), int(c[1])]] = true
		plateau_region_counts.append(_count_regions(plateau_walkable))

		var islands: Array = terrain.get("islands", []) as Array
		island_authored_total += islands.size()
		for isl_v in islands:
			var isl: Dictionary = isl_v as Dictionary
			var cells2: Array = isl.get("cells", []) as Array
			var sz: int = cells2.size()
			island_cell_samples.append(sz)
			if sz >= per_island_cap:
				island_clamped += 1

	print("")
	print("  -- %s -- bounds=%dx%d area=%d per_island_cap=%d total_island_cap=%d"
		% [label, w, h, board_area, per_island_cap, total_island_cap])
	print("     plateaus generated: %d   avg actual w=%.1f h=%.1f   avg cells=%.1f"
		% [plateau_authored_total, _avg(plateau_w_samples), _avg(plateau_h_samples), _avg(plateau_cell_samples)])
	print("     plateaus hitting the shrink-to-fit path (w<%d or h<%d authored min): %d of %d"
		% [authored_w_min, authored_h_min, plateau_shrunk, plateau_authored_total])
	print("     distinct plateau regions per board (shared-side flood fill), avg=%.2f — authored plateau_count avg=%.2f"
		% [_avg(plateau_region_counts), float(plateau_authored_total) / float(BOARDS_PER_SCENARIO)])
	if island_authored_total > 0:
		print("     islands generated: %d   avg actual size=%.1f   min=%d max=%d   clamped-to-cap: %d of %d"
			% [island_authored_total, _avg(island_cell_samples), _min_i(island_cell_samples),
				_max_i(island_cell_samples), island_clamped, island_authored_total])
	else:
		print("     islands generated: 0")


## Shared-side (4-direction) connected-component count over a cell-key dictionary.
func _count_regions(walkable: Dictionary) -> int:
	var visited: Dictionary = {}
	var count: int = 0
	var deltas: Array = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	for start_key in walkable.keys():
		if visited.has(start_key):
			continue
		count += 1
		var queue: Array = [start_key]
		visited[start_key] = true
		var head: int = 0
		while head < queue.size():
			var cur: String = queue[head]
			head += 1
			var parts := (cur as String).split(",")
			var cc: int = int(parts[0])
			var cr: int = int(parts[1])
			for d_v in deltas:
				var d: Array = d_v
				var nk: String = "%d,%d" % [cc + int(d[0]), cr + int(d[1])]
				if walkable.has(nk) and not visited.has(nk):
					visited[nk] = true
					queue.append(nk)
	return count


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _min_i(a: Array) -> int:
	if a.is_empty():
		return 0
	var m: int = int(a[0])
	for v in a:
		m = mini(m, int(v))
	return m


func _max_i(a: Array) -> int:
	if a.is_empty():
		return 0
	var m: int = int(a[0])
	for v in a:
		m = maxi(m, int(v))
	return m


## Reads the raw balance.json off disk — same helper shape TerrainRegionProbe.gd uses.
func _load_balance() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}
