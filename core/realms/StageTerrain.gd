class_name StageTerrain

extends RefCounted

# =============================================================================
# StageTerrain — deterministic walkable terrain generator for explore maps.
#
# DESIGN CONTRACT (read before touching this file):
#
#   Terrain is generated from a per-realm landscape *signature* keyed by the
#   realm's virtue (e.g. "courage", "wisdom").  Stages within a realm vary
#   deterministically off the realm seed so no two stages are identical, yet the
#   same (realm_seed, stage_index, signature, bounds) triple always produces the
#   same terrain.
#
#   FUTURE seam: per-realm visual asset packs (tile sprites, ambient effects, sky
#   colour) will key off realm.id / realm.virtue AND the signature's `relief`
#   descriptor (e.g. "highland", "canyon", "delta").  This generation layer is
#   the ONLY place that maps a virtue→signature; the asset layer plugs in here
#   without touching generation logic.  Do NOT collapse or rename `relief`.
#
#   rng_namespace param (optional, default ""):
#     ""  (default) → prefix = "stage.{stage_index}.explore.terrain" — identical
#         to the legacy exploration paths; exploration behaviour is UNCHANGED.
#     non-empty     → prefix = rng_namespace verbatim, supplied by caller.
#         Intended for reuse on the combat board under a caller-owned namespace
#         (e.g. "combat.terrain.<encounter_id>") so the same generator can
#         produce a combat map without colliding with or altering exploration RNG.
#
# OUTPUT SHAPE (frozen — never change field names):
#   {
#     "bounds":    { "w": int, "h": int },
#     "plateaus":  [ { "col": int, "row": int, "w": int, "h": int,
#                      "cells": [ [col, row], ... ] }, ... ],
#     "bridges":   [ { "col": int, "row": int, "w": int, "h": int }, ... ],
#     "stragglers":[ { "col": int, "row": int }, ... ]
#   }
#
#   "cells" is an Array of [col, row] int pairs representing the IRREGULAR BLOB
#   occupying the plateau's bounding box (col,row,w,h).  Old saved terrain entries
#   without a "cells" key are handled by walkable_set falling back to bounding-rect
#   fill (backward compat).
#
# SIGNATURE SHAPE it RECEIVES (frozen — consume with .get defaults):
#   {
#     "relief":               String,   # "highland"|"canyon"|"delta"|... (future asset key)
#     "plateau_count_min":    int,
#     "plateau_count_max":    int,
#     "plateau_w_min":        int,
#     "plateau_w_max":        int,
#     "plateau_h_min":        int,
#     "plateau_h_max":        int,
#     "plateau_shape_bias":   String,   # "long"|"blocky"|"small"
#     "bridge_width":         int,      # >= 2
#     "bridge_density":       float,    # 0.0–1.0 probability of extra bridges
#     "straggler_count_min":  int,
#     "straggler_count_max":  int,
#   }
#
# RNG PATHS — all APPEND-ONLY (never reorder existing RealmGenerator paths):
#   The prefix below is "stage.{i}.explore.terrain" when rng_namespace=="".
#   When rng_namespace is non-empty the prefix equals rng_namespace verbatim.
#   "{prefix}.bounds"                  — (currently unused draw; reserved)
#   "{prefix}.plateau.{k}"             — size + position of plateau k
#   "{prefix}.plateau.{k}.shape"       — irregular blob erosion draws (NEW, append-only)
#   "{prefix}.bridge.{k}"              — connectivity bridge k
#   "{prefix}.straggler.count"         — straggler count draw
#   "{prefix}.straggler.{k}"           — straggler tile k
#
# IRREGULARIZATION METHOD — seeded border erosion:
#   After placing each plateau's bounding box, we generate an irregular blob via one
#   pass of seeded border-cell erosion using RNG path "…plateau.k.shape":
#     1. Start with the full set of bounding-box cells.
#     2. Compute "border" cells = cells with at least one 4-dir neighbour outside the set.
#     3. Iterate border cells in sorted order (deterministic).  For each, roll the shape
#        RNG — if roll < ERODE_PROBABILITY (~30%), tentatively remove the cell, then check:
#          a. The remaining set is still 8-connected (flood-fill check on candidate set).
#          b. Remaining cell count >= ceil(ERODE_MIN_FILL * w * h)  (≥60% of box).
#          c. The center cell (col + w/2, row + h/2) is always kept.
#        If all checks pass, the cell is removed permanently.
#   Result: a single 8-connected, substantial, non-rectangular organic island.
#   The bounding box fields (col, row, w, h) are UNCHANGED — placement/spacing use them.
# =============================================================================

# Safe fallback signature used when the caller passes an empty/partial signature.
const _FALLBACK_SIGNATURE: Dictionary = {
	"relief":               "highland",
	"plateau_count_min":    3,
	"plateau_count_max":    5,
	"plateau_w_min":        4,
	"plateau_w_max":        10,
	"plateau_h_min":        4,
	"plateau_h_max":        10,
	"plateau_shape_bias":   "blocky",
	"bridge_width":         2,
	"bridge_density":       0.3,
	"straggler_count_min":  2,
	"straggler_count_max":  5,
}

# Minimum enforced bridge width (hard floor regardless of signature).
const _MIN_BRIDGE_WIDTH: int = 2

# Margin (cells) kept between any plateau edge and the map border.
const _BORDER_MARGIN: int = 1

# Maximum attempts to place a plateau without overlapping another.
const _PLATEAU_PLACE_ATTEMPTS: int = 20

# Irregular blob erosion parameters (seeded border erosion).
# Probability that a border cell is eroded away (per cell, one pass).
const _ERODE_PROBABILITY_NUMERATOR: int = 30    # out of 100
# Minimum fill fraction of bounding box that must remain after erosion (as a percentage, 0..100).
const _ERODE_MIN_FILL_PERCENT: int = 60

# Canonical cell key format — must match walkable_set / is_walkable callers.
# Use "%d,%d" % [col, row] everywhere in this file.


# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Generate a deterministic terrain dict for (realm_seed, stage_index).
## bounds = { "w": int, "h": int } — chosen by the caller (RealmGenerator).
## signature — see file header; missing keys fall back to _FALLBACK_SIGNATURE.
## rng_namespace — optional RNG prefix override.
##   ""  (default) → uses "stage.{stage_index}.explore.terrain" — byte-identical
##       to legacy exploration paths; exploration behaviour is fully unchanged.
##   non-empty     → uses rng_namespace verbatim as the prefix (e.g. a caller
##       supplying "combat.terrain.<encounter_id>" to reuse this generator for
##       the combat board without touching exploration RNG draws).
static func generate(
	realm_seed: int,
	stage_index: int,
	signature: Dictionary,
	bounds: Dictionary,
	rng_namespace: String = ""
) -> Dictionary:
	# Compute the single RNG prefix once — all internal path strings are built from it.
	# Default ("") reproduces the legacy exploration prefix byte-for-byte.
	var prefix: String = rng_namespace if rng_namespace != "" else "stage.%d.explore.terrain" % stage_index

	var w: int = max(int(bounds.get("w", 30)), 10)
	var h: int = max(int(bounds.get("h", 30)), 10)

	# Merge signature with fallback so all keys are present.
	var sig: Dictionary = {}
	for k in _FALLBACK_SIGNATURE:
		sig[k] = _FALLBACK_SIGNATURE[k]
	for k in signature:
		sig[k] = signature[k]

	var bridge_width: int = max(int(sig.get("bridge_width", 2)), _MIN_BRIDGE_WIDTH)
	var bridge_density: float = float(sig.get("bridge_density", 0.3))

	# ---- Plateau count ----
	var count_min: int = max(int(sig.get("plateau_count_min", 3)), 1)
	var count_max: int = max(int(sig.get("plateau_count_max", 5)), count_min)
	var count_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".bounds")
	var plateau_count: int = count_rng.randi_range(count_min, count_max)

	# ---- Place plateaus ----
	var plateaus: Array = []
	var p_w_min: int = max(int(sig.get("plateau_w_min", 4)), 2)
	var p_w_max: int = max(int(sig.get("plateau_w_max", 10)), p_w_min)
	var p_h_min: int = max(int(sig.get("plateau_h_min", 4)), 2)
	var p_h_max: int = max(int(sig.get("plateau_h_max", 10)), p_h_min)
	var shape_bias: String = str(sig.get("plateau_shape_bias", "blocky"))

	for k in range(plateau_count):
		var p_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".plateau.%d" % k)

		# Determine size from shape_bias
		var pw: int
		var ph: int
		match shape_bias:
			"long":
				# Width-biased: w gets the larger range, h gets the smaller
				pw = p_rng.randi_range(max(p_w_min, p_w_max / 2), p_w_max)
				ph = p_rng.randi_range(p_h_min, max(p_h_min, p_h_max / 2))
			"small":
				var small_w_max: int = max(p_w_min, (p_w_min + p_w_max) / 2)
				var small_h_max: int = max(p_h_min, (p_h_min + p_h_max) / 2)
				pw = p_rng.randi_range(p_w_min, small_w_max)
				ph = p_rng.randi_range(p_h_min, small_h_max)
			_:  # "blocky" or any other value
				pw = p_rng.randi_range(p_w_min, p_w_max)
				ph = p_rng.randi_range(p_h_min, p_h_max)

		# Clamp to fit within bounds minus border margin
		var max_col: int = w - _BORDER_MARGIN - pw
		var max_row: int = h - _BORDER_MARGIN - ph
		if max_col < _BORDER_MARGIN or max_row < _BORDER_MARGIN:
			# Bounds too small — shrink plateau to fit
			pw = max(1, w - 2 * _BORDER_MARGIN)
			ph = max(1, h - 2 * _BORDER_MARGIN)
			max_col = _BORDER_MARGIN
			max_row = _BORDER_MARGIN

		# Try up to _PLATEAU_PLACE_ATTEMPTS times to avoid exact duplicates.
		# We do not enforce full non-overlap; slight overlaps merge into one component.
		var placed := false
		var pc: int = _BORDER_MARGIN
		var pr: int = _BORDER_MARGIN
		for _attempt in range(_PLATEAU_PLACE_ATTEMPTS):
			var tc: int = p_rng.randi_range(_BORDER_MARGIN, max(_BORDER_MARGIN, max_col))
			var tr: int = p_rng.randi_range(_BORDER_MARGIN, max(_BORDER_MARGIN, max_row))
			# Accept if it does not perfectly duplicate an existing plateau position
			var duplicate := false
			for existing_v in plateaus:
				var existing: Dictionary = existing_v if existing_v is Dictionary else {}
				if int(existing.get("col", -999)) == tc and int(existing.get("row", -999)) == tr:
					duplicate = true
					break
			if not duplicate:
				pc = tc
				pr = tr
				placed = true
				break
		if not placed:
			# Consume remaining attempts so path stays consistent, then use last values
			pc = p_rng.randi_range(_BORDER_MARGIN, max(_BORDER_MARGIN, max_col))
			pr = p_rng.randi_range(_BORDER_MARGIN, max(_BORDER_MARGIN, max_row))

		# ---- Generate irregular blob for this plateau ----
		var shape_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".plateau.%d.shape" % k)
		var blob_cells: Array = _erode_plateau_blob(pc, pr, pw, ph, shape_rng)
		plateaus.append({ "col": pc, "row": pr, "w": pw, "h": ph, "cells": blob_cells })

	# ---- Connectivity: merge components with mandatory bridges ----
	# Build initial walkable set from plateaus only.
	var walkable_cells: Dictionary = _cells_from_plateaus(plateaus)

	# Connectivity guarantee: keep bridging until single component.
	var bridges: Array = []
	var bridge_k: int = 0
	# Safety cap: with correct two-leg bridges each iteration reduces the component
	# count by >=1, so this terminates in <= (components-1) iterations. The cap is a
	# defensive guard so a pathological case can never hang generation.
	var _bridge_safety: int = 0
	var _bridge_safety_max: int = plateaus.size() + 8

	var components := _flood_fill_components(walkable_cells)
	while components.size() > 1 and _bridge_safety < _bridge_safety_max:
		_bridge_safety += 1
		# Find the two nearest components (by minimum cell-pair Chebyshev distance).
		var best_dist: int = 999999
		var best_a_cell: String = ""
		var best_b_cell: String = ""
		var best_b_comp_idx: int = 1

		var comp_a: Array = components[0]
		for b_idx in range(1, components.size()):
			var comp_b: Array = components[b_idx]
			for ca in comp_a:
				var ca_parts := (ca as String).split(",")
				var ca_col: int = int(ca_parts[0])
				var ca_row: int = int(ca_parts[1])
				for cb in comp_b:
					var cb_parts := (cb as String).split(",")
					var cb_col: int = int(cb_parts[0])
					var cb_row: int = int(cb_parts[1])
					var dist: int = max(abs(ca_col - cb_col), abs(ca_row - cb_row))
					if dist < best_dist:
						best_dist = dist
						best_a_cell = ca
						best_b_cell = cb
						best_b_comp_idx = b_idx

		# Draw a mandatory bridge between best_a_cell and best_b_cell.
		var bridge_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".bridge.%d" % bridge_k)
		bridge_k += 1

		var a_parts := (best_a_cell as String).split(",")
		var b_parts := (best_b_cell as String).split(",")
		var ac: int = int(a_parts[0]);  var ar: int = int(a_parts[1])
		var bc: int = int(b_parts[0]);  var br: int = int(b_parts[1])

		# Draw a real connecting path: 1 rect for a straight bridge, 2 rects forming an
		# L for a diagonal one. A single straight leg would NOT connect diagonal
		# components and would loop forever — both legs are required.
		var bridge_rects := _make_bridge_rects(ac, ar, bc, br, bridge_width, w, h, bridge_rng)
		for _brk in bridge_rects:
			var br_rect: Dictionary = _brk if _brk is Dictionary else {}
			bridges.append(br_rect)
			var new_cells := _cells_from_rect(br_rect)
			for ck in new_cells:
				walkable_cells[ck] = true

		components = _flood_fill_components(walkable_cells)

	# ---- Optional extra bridges (bridge_density probability each) ----
	# We skip extra bridges if plateau_count <= 1 (nothing useful to bridge).
	if plateaus.size() >= 2:
		for k in range(plateaus.size() - 1):
			var extra_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".bridge.%d" % bridge_k)
			bridge_k += 1
			var roll: float = float(extra_rng.randi_range(0, 999)) / 1000.0
			if roll < bridge_density:
				var pa: Dictionary = plateaus[k] if plateaus[k] is Dictionary else {}
				var pb: Dictionary = plateaus[k + 1] if plateaus[k + 1] is Dictionary else {}
				var ac: int = int(pa.get("col", 0)) + int(pa.get("w", 1)) / 2
				var ar: int = int(pa.get("row", 0)) + int(pa.get("h", 1)) / 2
				var bc: int = int(pb.get("col", 0)) + int(pb.get("w", 1)) / 2
				var br: int = int(pb.get("row", 0)) + int(pb.get("h", 1)) / 2
				var bridge_rects := _make_bridge_rects(ac, ar, bc, br, bridge_width, w, h, extra_rng)
				for _brk in bridge_rects:
					var br_rect: Dictionary = _brk if _brk is Dictionary else {}
					bridges.append(br_rect)
					var new_cells := _cells_from_rect(br_rect)
					for ck in new_cells:
						walkable_cells[ck] = true

	# ---- Stragglers ----
	var strag_min: int = max(int(sig.get("straggler_count_min", 2)), 0)
	var strag_max: int = max(int(sig.get("straggler_count_max", 5)), strag_min)
	var strag_count_rng := CampaignSeed.get_rng_from(
		realm_seed, prefix + ".straggler.count"
	)
	var strag_count: int = strag_count_rng.randi_range(strag_min, strag_max)

	# Build list of candidate straggler positions: 8-dir neighbours of walkable cells
	# that are not already walkable and are within bounds.
	var stragglers: Array = []
	for sk in range(strag_count):
		var s_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".straggler.%d" % sk)
		var candidate_cells: Array = _adjacent_candidates(walkable_cells, w, h)
		if candidate_cells.is_empty():
			break
		var chosen_key: String = candidate_cells[s_rng.randi_range(0, candidate_cells.size() - 1)]
		walkable_cells[chosen_key] = true
		var parts := chosen_key.split(",")
		stragglers.append({ "col": int(parts[0]), "row": int(parts[1]) })

	return {
		"bounds":    { "w": w, "h": h },
		"plateaus":  plateaus,
		"bridges":   bridges,
		"stragglers": stragglers,
	}


## Returns a Dictionary used as a set: key = "%d,%d" % [col,row] -> true,
## covering every cell in plateaus/bridges/stragglers.
## If terrain is empty ({}) or has no plateaus, returns the FULL bounds rectangle
## as walkable (legacy fallback). If bounds are also missing, returns {} (all-walkable sentinel).
static func walkable_set(terrain: Dictionary) -> Dictionary:
	if terrain.is_empty():
		return {}

	var plateaus_v: Variant = terrain.get("plateaus", [])
	var plateaus: Array = plateaus_v if plateaus_v is Array else []
	if plateaus.is_empty():
		# Legacy fallback: full bounds rectangle
		var bounds_v: Variant = terrain.get("bounds", {})
		var bounds: Dictionary = bounds_v if bounds_v is Dictionary else {}
		if bounds.is_empty():
			return {}
		var bw: int = int(bounds.get("w", 0))
		var bh: int = int(bounds.get("h", 0))
		if bw <= 0 or bh <= 0:
			return {}
		var result: Dictionary = {}
		for c in range(bw):
			for r in range(bh):
				result["%d,%d" % [c, r]] = true
		return result

	var cells: Dictionary = {}

	# Plateaus — use irregular blob cells when present; fall back to bounding rect.
	for p_v in plateaus:
		var p: Dictionary = p_v if p_v is Dictionary else {}
		var blob_v: Variant = p.get("cells", [])
		var blob: Array = blob_v if blob_v is Array else []
		if not blob.is_empty():
			for pair_v in blob:
				var pair: Array = pair_v if pair_v is Array else []
				if pair.size() >= 2:
					cells["%d,%d" % [int(pair[0]), int(pair[1])]] = true
		else:
			# Backward compat: fill bounding rect (old saved terrain has no "cells")
			var pc: int = int(p.get("col", 0))
			var pr: int = int(p.get("row", 0))
			var pw: int = int(p.get("w", 1))
			var ph: int = int(p.get("h", 1))
			for dc in range(pw):
				for dr in range(ph):
					cells["%d,%d" % [pc + dc, pr + dr]] = true

	# Bridges
	var bridges_v: Variant = terrain.get("bridges", [])
	var bridges: Array = bridges_v if bridges_v is Array else []
	for b_v in bridges:
		var b: Dictionary = b_v if b_v is Dictionary else {}
		var bc: int = int(b.get("col", 0))
		var br: int = int(b.get("row", 0))
		var bw: int = int(b.get("w", 1))
		var bh: int = int(b.get("h", 1))
		for dc in range(bw):
			for dr in range(bh):
				cells["%d,%d" % [bc + dc, br + dr]] = true

	# Stragglers
	var stragglers_v: Variant = terrain.get("stragglers", [])
	var stragglers: Array = stragglers_v if stragglers_v is Array else []
	for s_v in stragglers:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		cells["%d,%d" % [int(s.get("col", 0)), int(s.get("row", 0))]] = true

	return cells


## Returns true if cell {col,row} is walkable.
## If walkable is empty (legacy all-walkable sentinel), always returns true.
static func is_walkable(cell: Dictionary, walkable: Dictionary) -> bool:
	if walkable.is_empty():
		return true
	var key: String = "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]
	return walkable.has(key)


## Returns the entry cell {col,row}: the leftmost walkable column, and among that
## column's walkable rows the one nearest to row = bounds.h / 2.
## If walkable is empty (legacy), returns {col:0, row: bounds.h/2}.
static func entry_cell(walkable: Dictionary, bounds: Dictionary) -> Dictionary:
	var bh: int = int(bounds.get("h", 30))
	var mid: int = bh / 2

	if walkable.is_empty():
		return { "col": 0, "row": mid }

	# Find the minimum column among all walkable cells.
	var min_col: int = 999999
	for key in walkable:
		var parts := (key as String).split(",")
		var c: int = int(parts[0])
		if c < min_col:
			min_col = c

	# Among all cells in that column, pick the one whose row is closest to mid.
	var best_row: int = -1
	var best_dist: int = 999999
	for key in walkable:
		var parts := (key as String).split(",")
		var c: int = int(parts[0])
		var r: int = int(parts[1])
		if c != min_col:
			continue
		var d: int = abs(r - mid)
		if d < best_dist or (d == best_dist and r < best_row):
			best_dist = d
			best_row = r

	if best_row < 0:
		return { "col": 0, "row": mid }

	return { "col": min_col, "row": best_row }


## BFS over 8-directional walkable neighbours from target {col,row}.
## Returns { "col,row": int_distance }.
## Deterministic neighbour order (fixed delta iteration: rows then cols, ascending).
## If walkable is empty, returns {} (caller treats empty dist_field as legacy mode).
static func bfs_distance_field(target: Dictionary, walkable: Dictionary) -> Dictionary:
	if walkable.is_empty():
		return {}

	var dist_field: Dictionary = {}
	var queue: Array = []

	var start_key: String = "%d,%d" % [int(target.get("col", 0)), int(target.get("row", 0))]
	if not walkable.has(start_key):
		return {}

	dist_field[start_key] = 0
	queue.append(start_key)

	var head: int = 0
	# Deterministic 8-direction order: row delta outer (-1,0,1), col delta inner (-1,0,1),
	# skipping (0,0). This ordering is fixed and must not change.
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],           [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]

	while head < queue.size():
		var cur_key: String = queue[head]
		head += 1
		var cur_parts := cur_key.split(",")
		var cur_c: int = int(cur_parts[0])
		var cur_r: int = int(cur_parts[1])
		var cur_dist: int = int(dist_field[cur_key])

		for delta_v in deltas:
			var delta: Array = delta_v if delta_v is Array else []
			var nc: int = cur_c + int(delta[0])
			var nr: int = cur_r + int(delta[1])
			var nk: String = "%d,%d" % [nc, nr]
			if walkable.has(nk) and not dist_field.has(nk):
				dist_field[nk] = cur_dist + 1
				queue.append(nk)

	return dist_field


## Returns an Array of { "col": int, "row": int } Dictionaries for every WALKABLE cell
## within Chebyshev distance `radius` of `center` (inclusive). Pure-deterministic, no RNG.
## If walkable is empty (legacy sentinel) the caller is responsible for the full-rect fallback.
## V2-STAGE-004 Phase 2.5 — fog-of-war tile discovery.
static func cells_within_radius(center: Dictionary, radius: int, walkable: Dictionary) -> Array:
	var cc: int = int(center.get("col", 0))
	var cr: int = int(center.get("row", 0))
	var result: Array = []
	for dc in range(-radius, radius + 1):
		for dr in range(-radius, radius + 1):
			var nc: int = cc + dc
			var nr: int = cr + dr
			var nk: String = "%d,%d" % [nc, nr]
			# When walkable is empty (legacy all-walkable sentinel) every cell is walkable.
			if walkable.is_empty() or walkable.has(nk):
				result.append({ "col": nc, "row": nr })
	return result


## BFS from `from_cell` over 8-dir walkable neighbours; returns the nearest walkable cell
## whose "%d,%d" key is NOT in `explored` (pure-deterministic, no RNG).
## Tiebreak: smallest BFS distance, then smallest row, then smallest col.
## If every reachable walkable cell is already explored, returns `from_cell` unchanged.
## Delta ordering matches bfs_distance_field for consistency.
## V2-STAGE-004 Phase 2.5 — frontier exploration AI.
static func nearest_unexplored(from_cell: Dictionary, walkable: Dictionary, explored: Dictionary) -> Dictionary:
	var fc: int = int(from_cell.get("col", 0))
	var fr: int = int(from_cell.get("row", 0))
	var start_key: String = "%d,%d" % [fc, fr]

	# Edge-case: empty walkable (legacy sentinel) — treat as all explored, return from_cell.
	if walkable.is_empty():
		return from_cell

	# BFS distance from start_key to each reachable cell.
	var dist_field: Dictionary = {}
	dist_field[start_key] = 0
	var queue: Array = [start_key]

	# Deterministic 8-direction order matching bfs_distance_field.
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],           [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]

	var head: int = 0
	var best_col: int = -1
	var best_row: int = -1
	var best_dist: int = 999999

	while head < queue.size():
		var cur_key: String = queue[head]
		head += 1
		var cur_parts := cur_key.split(",")
		var cur_c: int = int(cur_parts[0])
		var cur_r: int = int(cur_parts[1])
		var cur_dist: int = int(dist_field[cur_key])

		# Prune: once we've found a best at distance D, don't expand nodes deeper than D.
		if cur_dist > best_dist:
			continue

		if not explored.has(cur_key):
			# Unexplored — check tiebreak: (dist, row, col) ascending.
			if cur_dist < best_dist \
					or (cur_dist == best_dist and cur_r < best_row) \
					or (cur_dist == best_dist and cur_r == best_row and cur_c < best_col):
				best_dist = cur_dist
				best_row  = cur_r
				best_col  = cur_c
			# Still expand (there may be closer unexplored cells via other paths only if
			# this is the first level — but BFS guarantees level-order, so any node at the
			# same distance is equally close; we just need to scan the full level for tiebreak).

		for delta_v in deltas:
			var delta: Array = delta_v if delta_v is Array else []
			var nc: int = cur_c + int(delta[0])
			var nr: int = cur_r + int(delta[1])
			var nk: String = "%d,%d" % [nc, nr]
			if walkable.has(nk) and not dist_field.has(nk):
				var nd: int = cur_dist + 1
				# Only enqueue if it can possibly improve or tie the current best.
				if nd <= best_dist:
					dist_field[nk] = nd
					queue.append(nk)

	if best_col < 0:
		return from_cell

	return { "col": best_col, "row": best_row }


## Among the 8-dir walkable neighbours of from_cell, picks the one with the smallest
## dist_field value (strictly less than from_cell's own distance).
##
## Tiebreak (when several progressing neighbours share the minimal BFS distance):
##   1. smallest chebyshev distance to `target`  (geometrically closest along the
##      straight line — removes the up-left directional bias on open terrain)
##   2. smallest manhattan distance to `target`
##   3. stable fallback: lowest row, then lowest col (fully deterministic).
## When `target` is empty (unknown), falls back to the legacy lowest-row/col tiebreak.
##
## Returns from_cell unchanged if no progressing neighbour (dead-end safety).
## Pure / deterministic — no RNG, no OS time.
static func next_step(from_cell: Dictionary, dist_field: Dictionary, walkable: Dictionary, target: Dictionary = {}) -> Dictionary:
	var fc: int = int(from_cell.get("col", 0))
	var fr: int = int(from_cell.get("row", 0))
	var from_key: String = "%d,%d" % [fc, fr]
	var from_dist: int = dist_field.get(from_key, 999999) if dist_field.has(from_key) else 999999

	var has_target: bool = not target.is_empty()
	var tc: int = int(target.get("col", 0))
	var tr: int = int(target.get("row", 0))

	var best_col: int = fc
	var best_row: int = fr
	var best_dist: int = from_dist
	var best_cheb: int = 0
	var best_man: int = 0
	var found: bool = false

	# Deterministic 8-direction: row delta outer, col delta inner (ascending).
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dc == 0 and dr == 0:
				continue
			var nc: int = fc + dc
			var nr: int = fr + dr
			var nk: String = "%d,%d" % [nc, nr]
			if not is_walkable({ "col": nc, "row": nr }, walkable):
				continue
			if not dist_field.has(nk):
				continue
			var nd: int = int(dist_field[nk])
			if nd >= from_dist:
				continue

			# Geometry-to-target tiebreak metrics (only meaningful when target known).
			var dcol: int = abs(nc - tc)
			var drow: int = abs(nr - tr)
			var cheb: int = max(dcol, drow)
			var man: int = dcol + drow

			var better: bool = false
			if not found:
				better = true
			elif nd < best_dist:
				better = true
			elif nd == best_dist:
				if has_target:
					if cheb < best_cheb:
						better = true
					elif cheb == best_cheb and man < best_man:
						better = true
					elif cheb == best_cheb and man == best_man and (nr < best_row or (nr == best_row and nc < best_col)):
						better = true
				elif nr < best_row or (nr == best_row and nc < best_col):
					# Legacy tiebreak when target unknown.
					better = true

			if better:
				best_dist = nd
				best_col = nc
				best_row = nr
				best_cheb = cheb
				best_man = man
				found = true

	return { "col": best_col, "row": best_row }


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

## Build a cell-key dict from an Array of plateau dicts.
## Uses plateau["cells"] (irregular blob) when present and non-empty;
## falls back to filling the bounding rect for old saved terrain without "cells".
static func _cells_from_plateaus(plateaus: Array) -> Dictionary:
	var cells: Dictionary = {}
	for p_v in plateaus:
		var p: Dictionary = p_v if p_v is Dictionary else {}
		var blob_v: Variant = p.get("cells", [])
		var blob: Array = blob_v if blob_v is Array else []
		if not blob.is_empty():
			# Irregular blob path
			for pair_v in blob:
				var pair: Array = pair_v if pair_v is Array else []
				if pair.size() >= 2:
					cells["%d,%d" % [int(pair[0]), int(pair[1])]] = true
		else:
			# Backward-compat: fill bounding rect
			var c0: int = int(p.get("col", 0))
			var r0: int = int(p.get("row", 0))
			var pw: int = int(p.get("w", 1))
			var ph: int = int(p.get("h", 1))
			for dc in range(pw):
				for dr in range(ph):
					cells["%d,%d" % [c0 + dc, r0 + dr]] = true
	return cells


## Build a cell-key dict from a rect { col, row, w, h }.
static func _cells_from_rect(rect: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	var rc: int = int(rect.get("col", 0))
	var rr: int = int(rect.get("row", 0))
	var rw: int = int(rect.get("w", 1))
	var rh: int = int(rect.get("h", 1))
	for dc in range(rw):
		for dr in range(rh):
			cells["%d,%d" % [rc + dc, rr + dr]] = true
	return cells


## Flood-fill connected-components on walkable_cells (8-directional).
## Returns Array of Arrays, each inner Array is a list of cell keys.
static func _flood_fill_components(walkable_cells: Dictionary) -> Array:
	var visited: Dictionary = {}
	var components: Array = []

	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],           [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]

	for key in walkable_cells:
		if visited.has(key):
			continue
		# BFS from this cell
		var component: Array = []
		var queue: Array = [key]
		visited[key] = true
		var head: int = 0
		while head < queue.size():
			var cur: String = queue[head]
			head += 1
			component.append(cur)
			var parts := (cur as String).split(",")
			var cc: int = int(parts[0])
			var cr: int = int(parts[1])
			for delta_v in deltas:
				var delta: Array = delta_v if delta_v is Array else []
				var nc: int = cc + int(delta[0])
				var nr: int = cr + int(delta[1])
				var nk: String = "%d,%d" % [nc, nr]
				if walkable_cells.has(nk) and not visited.has(nk):
					visited[nk] = true
					queue.append(nk)
		components.append(component)

	return components


## Build a REAL connecting bridge path from (ac,ar) to (bc,br). Returns an Array of
## rect dicts:
##   - same col or same row -> 1 straight rect
##   - diagonal             -> 2 rects forming an L (one horizontal leg + one vertical leg)
## Each rect has thickness `bridge_width` and is clamped to map bounds. For the L, the
## two legs overlap at the corner and each leg covers its endpoint cell, so the union is
## a single connected band that includes BOTH (ac,ar) and (bc,br). This guarantees the
## two components actually merge — a single leg would not, and the connectivity loop
## would never terminate. The corner direction (horizontal-first vs vertical-first) is
## chosen deterministically via rng.
static func _make_bridge_rects(
	ac: int, ar: int,
	bc: int, br: int,
	bridge_width: int,
	map_w: int, map_h: int,
	rng: RandomNumberGenerator
) -> Array:
	# Straight vertical
	if ac == bc:
		var min_r: int = min(ar, br)
		var max_r: int = max(ar, br)
		var col_start: int = clamp(ac - bridge_width / 2, 0, max(0, map_w - bridge_width))
		return [{
			"col": col_start, "row": min_r,
			"w": bridge_width, "h": max_r - min_r + 1,
		}]
	# Straight horizontal
	if ar == br:
		var min_c: int = min(ac, bc)
		var max_c: int = max(ac, bc)
		var row_start: int = clamp(ar - bridge_width / 2, 0, max(0, map_h - bridge_width))
		return [{
			"col": min_c, "row": row_start,
			"w": max_c - min_c + 1, "h": bridge_width,
		}]

	# Diagonal: build both legs of an L so the path is genuinely connected.
	var horiz_first: bool = (rng.randi() % 2 == 0)
	var rects: Array = []
	var hmin_c: int = min(ac, bc)
	var hmax_c: int = max(ac, bc)
	var vmin_r: int = min(ar, br)
	var vmax_r: int = max(ar, br)

	if horiz_first:
		# Horizontal leg along row ar (ac..bc), then vertical leg along col bc (ar..br).
		var h_row_start: int = clamp(ar - bridge_width / 2, 0, max(0, map_h - bridge_width))
		rects.append({
			"col": hmin_c, "row": h_row_start,
			"w": hmax_c - hmin_c + 1, "h": bridge_width,
		})
		var v_col_start: int = clamp(bc - bridge_width / 2, 0, max(0, map_w - bridge_width))
		rects.append({
			"col": v_col_start, "row": vmin_r,
			"w": bridge_width, "h": vmax_r - vmin_r + 1,
		})
	else:
		# Vertical leg along col ac (ar..br), then horizontal leg along row br (ac..bc).
		var v_col_start2: int = clamp(ac - bridge_width / 2, 0, max(0, map_w - bridge_width))
		rects.append({
			"col": v_col_start2, "row": vmin_r,
			"w": bridge_width, "h": vmax_r - vmin_r + 1,
		})
		var h_row_start2: int = clamp(br - bridge_width / 2, 0, max(0, map_h - bridge_width))
		rects.append({
			"col": hmin_c, "row": h_row_start2,
			"w": hmax_c - hmin_c + 1, "h": bridge_width,
		})
	return rects


## Generate an irregular organic blob for a plateau bounding box using seeded
## border erosion.  Returns an Array of [col, row] int pairs.
##
## Algorithm (one-pass seeded erosion):
##   1. Start with all cells in the bounding rect.
##   2. Iterate border cells (cells with >= 1 out-of-set 4-dir neighbour) in sorted
##      order for determinism.  The center cell is always protected.
##   3. For each border cell roll shape_rng (0..99).  If roll < _ERODE_PROBABILITY_NUMERATOR:
##        a. Build the candidate set without this cell.
##        b. Verify the candidate set is still 8-connected.
##        c. Verify remaining count >= ceil(_ERODE_MIN_FILL_PERCENT% * w * h).
##        If all pass: remove the cell permanently.
##   4. Return surviving cells as Array of [col, row].
static func _erode_plateau_blob(col: int, row: int, pw: int, ph: int, shape_rng: RandomNumberGenerator) -> Array:
	# Build initial set as a Dictionary of "c,r" -> true for fast membership tests.
	var cell_set: Dictionary = {}
	for dc in range(pw):
		for dr in range(ph):
			cell_set["%d,%d" % [col + dc, row + dr]] = true

	# Protect the center cell always.
	var center_c: int = col + pw / 2
	var center_r: int = row + ph / 2
	var center_key: String = "%d,%d" % [center_c, center_r]

	# Minimum cells to keep.
	var total_box: int = pw * ph
	var min_cells: int = int(ceil(float(total_box) * float(_ERODE_MIN_FILL_PERCENT) / 100.0))
	# Always keep at least 1.
	min_cells = max(min_cells, 1)

	# One erosion pass: build sorted border-cell list then iterate.
	var border_cells: Array = _compute_border_cells(cell_set, col, row, pw, ph)
	# Sort for determinism (already sorted by _compute_border_cells, but be explicit).
	border_cells.sort()

	for bk in border_cells:
		# Skip if already removed in this pass.
		if not cell_set.has(bk):
			continue
		# Protect center.
		if bk == center_key:
			continue
		# Roll for erosion.
		var roll: int = shape_rng.randi_range(0, 99)
		if roll >= _ERODE_PROBABILITY_NUMERATOR:
			continue
		# Would removing this cell violate min-fill?
		if cell_set.size() - 1 < min_cells:
			continue
		# Check 8-connectivity of candidate set (set minus this cell).
		cell_set.erase(bk)
		if not _is_8_connected(cell_set):
			# Restore — would disconnect.
			cell_set[bk] = true

	# Convert to Array of [col, row] pairs.
	var result: Array = []
	for ck in cell_set:
		var parts: PackedStringArray = (ck as String).split(",")
		result.append([int(parts[0]), int(parts[1])])
	# Sort for determinism.
	result.sort()
	return result


## Compute border cells of a set within bounding box (col,row,pw,ph).
## A "border" cell has at least one 4-dir neighbour that is NOT in the set
## (i.e., outside the blob).  Returns sorted Array of "c,r" keys.
static func _compute_border_cells(cell_set: Dictionary, _col: int, _row: int, _pw: int, _ph: int) -> Array:
	var border: Dictionary = {}
	var dirs4: Array = [[-1, 0], [1, 0], [0, -1], [0, 1]]
	for ck in cell_set:
		var parts: PackedStringArray = (ck as String).split(",")
		var cc: int = int(parts[0])
		var cr: int = int(parts[1])
		for d_v in dirs4:
			var d: Array = d_v if d_v is Array else []
			var nk: String = "%d,%d" % [cc + int(d[0]), cr + int(d[1])]
			if not cell_set.has(nk):
				border[ck] = true
				break
	var result: Array = border.keys()
	result.sort()
	return result


## Check whether a cell-key Dictionary forms a single 8-connected component.
## Returns true if empty (trivially connected) or fully connected.
static func _is_8_connected(cell_set: Dictionary) -> bool:
	if cell_set.is_empty():
		return true
	var visited: Dictionary = {}
	var start_key: String = (cell_set.keys())[0]
	var queue: Array = [start_key]
	visited[start_key] = true
	var head: int = 0
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],          [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		var parts: PackedStringArray = (cur as String).split(",")
		var cc: int = int(parts[0])
		var cr: int = int(parts[1])
		for delta_v in deltas:
			var delta: Array = delta_v if delta_v is Array else []
			var nk: String = "%d,%d" % [cc + int(delta[0]), cr + int(delta[1])]
			if cell_set.has(nk) and not visited.has(nk):
				visited[nk] = true
				queue.append(nk)
	return visited.size() == cell_set.size()


## Returns candidate straggler cells: 8-dir neighbours of walkable cells
## that are not already walkable, within (0,0)–(w-1, h-1).
static func _adjacent_candidates(walkable_cells: Dictionary, map_w: int, map_h: int) -> Array:
	var candidates: Dictionary = {}
	var deltas: Array = [
		[-1, -1], [-1, 0], [-1, 1],
		[ 0, -1],           [ 0, 1],
		[ 1, -1], [ 1, 0], [ 1, 1],
	]
	for key in walkable_cells:
		var parts := (key as String).split(",")
		var cc: int = int(parts[0])
		var cr: int = int(parts[1])
		for delta_v in deltas:
			var delta: Array = delta_v if delta_v is Array else []
			var nc: int = cc + int(delta[0])
			var nr: int = cr + int(delta[1])
			if nc < 0 or nc >= map_w or nr < 0 or nr >= map_h:
				continue
			var nk: String = "%d,%d" % [nc, nr]
			if not walkable_cells.has(nk):
				candidates[nk] = true
	# Return as sorted array for determinism
	var result: Array = candidates.keys()
	result.sort()
	return result
