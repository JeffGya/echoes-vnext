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
#     "islands":   [ { "col": int, "row": int, "w": int, "h": int,
#                      "cells": [ [col, row], ... ] }, ... ]
#   }
#
#   "cells" is an Array of [col, row] int pairs representing the IRREGULAR BLOB
#   occupying the plateau's bounding box (col,row,w,h).  Old saved terrain entries
#   without a "cells" key are handled by walkable_set falling back to bounding-rect
#   fill (backward compat).
#
#   V2-COMBAT-003 terrain commit 3 RENAMED "stragglers" to "islands" and changed what
#   the list holds: a straggler was ONE cell taken from the 8-direction neighbours of
#   existing ground, so by construction it always touched the board and could never be
#   an island (measured: 838 of 865 cut-off regions touched the main ground at a corner).
#   An island is a MULTI-CELL blob with a guaranteed ring of void around it. Its entry
#   carries the same { col, row, w, h, cells } shape as a plateau, where (col,row,w,h)
#   is the blob's bounding box.
#   walkable_set STILL READS the legacy "stragglers" key — see its doc comment.
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
#     "island_count_min":     int,      # V2-COMBAT-003 commit 3 (was straggler_count_min)
#     "island_count_max":     int,      # V2-COMBAT-003 commit 3 (was straggler_count_max)
#     "island_size_min":      int,      # >= 4; clamped down to fit the board — see below
#     "island_size_max":      int,      # >= island_size_min; clamped down to fit the board
#     "connect_min_region_cells": int,  # >= 2; default 6 (V2-COMBAT-003 terrain commit 2)
#   }
#
# CONNECTIVITY RULE (V2-COMBAT-003 terrain commit 2 — read before changing either half):
#   Two walkable cells belong to the same REGION only when they share a full side.
#   Diagonals do not join regions (`_flood_fill_components`). This is deliberately
#   stricter than `is_legal_edge`, which permits a diagonal step unless BOTH orthogonal
#   side cells are solid. Strict is the safe direction: an orthogonal step between two
#   walkable in-bounds cells is always a legal edge, so a board this generator calls
#   connected is certainly traversable by the movement layer.
#
#   The repair bridges every cut-off region of `connect_min_region_cells` cells or more
#   into the host region (the largest region; ties by numerically lowest col,row — the
#   same host rule GridService uses to place actors). Regions below that size are LEFT
#   ALONE by design: small islands are terrain variety, not a defect.
## ISLANDS (V2-COMBAT-003 terrain commit 3 — read before changing the island pass):
#
#   An island is a deliberate feature, NOT a defect. It is minted AFTER the connectivity
#   repair, and that ordering is the whole design: the repair fixes ACCIDENTAL splits,
#   islands are INTENTIONAL ones. Consequently the repair's "exactly one region of
#   >= connect_min_region_cells cells" guarantee covers PLATEAUS PLUS BRIDGES, never the
#   whole walkable set. A test that asserts it against the full set is testing the island
#   pass by mistake — strip the islands first.
#
#   Three properties hold by construction, and each is asserted by a test:
#
#   1. MOATED. No island cell is adjacent — in ANY of the 8 directions — to a cell of any
#      other region, including another island. Every island sits inside a clear ring of
#      void. This is enforced positively, not filtered for afterwards: an island may only
#      occupy cells outside `blocked`, which is the 8-direction DILATION of everything
#      walkable so far. A corner touch is therefore impossible, not merely rare.
#   2. MULTI-CELL AND SHARED-SIDE CONTIGUOUS. Growth only ever adds a cell that shares a
#      full SIDE with the blob, so an island is exactly ONE region under the same
#      connectivity rule the repair uses. `_ISLAND_MIN_CELLS` (4) is a hard floor: a blob
#      that cannot reach it is discarded rather than emitted, because a 1-cell island is
#      the defect this commit removes.
#   3. SIZED TO THE BOARD. Authored size is a REQUEST, clamped twice against board area:
#        per island — at most (w * h) / _ISLAND_MAX_AREA_DIVISOR   (1/16 of the board)
#        all islands — at most (w * h) / _ISLAND_TOTAL_AREA_DIVISOR (1/4 of the board)
#      Both keep a floor of _ISLAND_MIN_CELLS. Without this, wisdom's authored 8..50 would
#      swallow a 12x12 combat board (50 of 144 cells in ONE island, and up to six of them).
#      With it, 12x12 gives at most 9 cells per island and 36 in total; 22x22 gives 30 and
#      121; a 50x40 explore map gives 125 and 500, so the authored range binds instead.
#
#   COMPACTNESS. At each growth step the frontier cell with the MOST 8-direction contacts
#   with the blob so far wins; the RNG only breaks ties among equally-compact candidates.
#   Filling concavities before extending a limb is what keeps an island a blob rather than
#   a one-cell-wide worm.
#
#   NOT HERE: bridging an island back to the board is terrain commit 4. Nothing in this
#   pass connects an island to anything, and nothing may spawn on one (GridService places
#   every actor inside the host region — commit 1438789).
#
# RNG PATHS — all APPEND-ONLY (never reorder existing RealmGenerator paths):
#   The prefix below is "stage.{i}.explore.terrain" when rng_namespace=="".
#   When rng_namespace is non-empty the prefix equals rng_namespace verbatim.
#   "{prefix}.bounds"                  — (currently unused draw; reserved)
#   "{prefix}.plateau.{k}"             — size + position of plateau k
#   "{prefix}.plateau.{k}.shape"       — irregular blob erosion draws (NEW, append-only)
#   "{prefix}.bridge.{k}"              — connectivity bridge k, then the density-driven
#                                        extra bridges continuing from the same counter.
#                                        V2-COMBAT-003 terrain commit 2 adds NO namespace
#                                        and reorders none, but the repair now fires where
#                                        it used to be blind, so a board consumes more
#                                        bridge.K streams and the extra bridges start from
#                                        a higher K. Board geometry moved once, on purpose.
#   "{prefix}.island.count"            — island count draw (V2-COMBAT-003 commit 3;
#                                        RENAMED from "{prefix}.straggler.count")
#   "{prefix}.island.{k}"              — island k: its size draw, its seed-cell draw and
#                                        every growth draw, all on ITS OWN stream, so one
#                                        island's draws can never shift another's.
#                                        (RENAMED from "{prefix}.straggler.{k}"; an island
#                                        makes MORE than one draw, a straggler made exactly
#                                        one. Board geometry moved once, on purpose.)
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
	"island_count_min":     1,
	"island_count_max":     2,
	"island_size_min":      4,
	"island_size_max":      8,
	"connect_min_region_cells": 6,
}

# Minimum enforced bridge width (hard floor regardless of signature).
const _MIN_BRIDGE_WIDTH: int = 2

# V2-COMBAT-003 terrain commit 2 — default `connect_min_region_cells`.
# A walkable region of at least this many cells that is cut off from the host region is a
# board split and gets bridged back in. A region below it is scenery and is left alone.
# 6 comes from the measured size distribution (docs/v2-combat-003-handoff.md §12.1): it is
# bimodal with an empty 6-to-10 bucket, so any threshold in 6..10 gives the same split.
const _MIN_CONNECT_REGION_CELLS: int = 6

# V2-COMBAT-003 terrain commit 3 — island sizing.
# Hard floor on island size. An island below this is discarded, never emitted: a one-cell
# "island" that touches the board at a corner is exactly the defect this commit removes.
const _ISLAND_MIN_CELLS: int = 4
# One island may never exceed board_area / _ISLAND_MAX_AREA_DIVISOR cells (floor
# _ISLAND_MIN_CELLS). Authored size is a request; the board has the final say.
const _ISLAND_MAX_AREA_DIVISOR: int = 16
# All islands together may never exceed board_area / _ISLAND_TOTAL_AREA_DIVISOR cells
# (floor _ISLAND_MIN_CELLS). Stops a high island_count from eating a small board even when
# each individual island is legal.
const _ISLAND_TOTAL_AREA_DIVISOR: int = 4

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
	# V2-COMBAT-003 terrain commit 2: the smallest cut-off region the connectivity repair
	# will bridge back in. Floor of 2 — a value of 0 or 1 would ask the repair to bridge in
	# every single cell on the board and defeat the design decision to keep small islands.
	var min_region_cells: int = max(
		int(sig.get("connect_min_region_cells", _MIN_CONNECT_REGION_CELLS)),
		2
	)

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

	# Connectivity guarantee: keep bridging until every SUBSTANTIAL region is joined to the
	# host region. "Substantial" means at least `min_region_cells` cells (signature key
	# `connect_min_region_cells`, default 6). A region of 5 cells or fewer is left alone —
	# those are scenery the design deliberately keeps, and under the shared-side rule they
	# are mostly the single cells that touch the board only at a corner.
	#
	# TERMINATION (V2-COMBAT-003 terrain commit 2 — the loop must be proven, not assumed):
	#   1. `_make_bridge_rects` returns rects whose union is SHARED-SIDE connected and
	#      contains both endpoint cells (proved in that function's header and asserted by
	#      terrain/bridge_connects_shared_side).
	#   2. Both endpoints lie in the two regions being joined, so after the bridge cells are
	#      added those two regions are one region.
	#   3. Every bridge cell is connected to the host, so no NON-host region can ever gain a
	#      cell. Non-host regions only disappear; they never grow and never appear.
	#   4. The host absorbs the candidate plus the bridge, so it strictly grows and stays
	#      the strictly largest region — the host identity can never move to another region.
	#   Therefore the count of non-host regions of >= min_region_cells strictly decreases
	#   every iteration, and the loop runs at most (initial component count) times.
	# The cap below is a safety net for a defect in that reasoning, not part of it: it fails
	# LOUDLY via push_error rather than quietly returning a split board.
	var bridges: Array = []
	var bridge_k: int = 0
	var _bridge_safety: int = 0

	var components := _flood_fill_components(walkable_cells)
	var _bridge_safety_max: int = components.size() + plateaus.size() + 8

	while true:
		var host_idx: int = _host_component_index(components)
		if host_idx < 0:
			break
		# Candidate regions: everything that is not the host and is big enough to matter.
		var candidate_indices: Array = []
		for ci in range(components.size()):
			if ci == host_idx:
				continue
			if (components[ci] as Array).size() >= min_region_cells:
				candidate_indices.append(ci)
		if candidate_indices.is_empty():
			break
		if _bridge_safety >= _bridge_safety_max:
			push_error(
				"StageTerrain: connectivity repair hit its %d-iteration ceiling with %d region(s) of >= %d cells still cut off (prefix '%s', bounds %dx%d). The board is SPLIT — a bridge failed to connect under the shared-side rule."
				% [_bridge_safety_max, candidate_indices.size(), min_region_cells, prefix, w, h]
			)
			break
		_bridge_safety += 1

		# Find the nearest cell pair between the host and any candidate region
		# (minimum Chebyshev distance; first match wins, and both the component order and
		# the cell order inside each component are numerically sorted, so ties resolve to
		# the numerically lowest (col,row) pair).
		var best_dist: int = 999999
		var best_a_cell: String = ""
		var best_b_cell: String = ""

		var comp_a: Array = components[host_idx]
		for b_idx in candidate_indices:
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

	# ---- The objective site guarantee (decision 25) ----
	# Decision 24 makes eight walkable neighbours the MINIMUM a static objective needs, and
	# that same test decides whether a region can host an objective at all. When the host
	# region offers no such cell the generator BUILDS one — a 3x3 block, one centre with
	# eight cells around it, joined to the host region — rather than emitting a board on
	# which the stage objective can never be placed legally and the stage can never be
	# completed.
	#
	# ORDER IS LOAD-BEARING. This runs AFTER the connectivity repair, so "host" already
	# means what it will mean on the finished board, and BEFORE the island pass, so the
	# island moat is computed against the new ground and no island can grow against it.
	#
	# It makes NO RNG draw. The site is chosen by a total order over the board: most
	# overlap with ground that already exists (so the block adds as little as possible),
	# ties by the numerically lowest centre. A candidate may not contain a walkable cell
	# of any OTHER region — merging a cut-off region into the host is the repair's job and
	# is governed by connect_min_region_cells, not by this pass.
	#
	# Every occurrence is recorded in terrain["objective_site_built"], present only when
	# the pass fired. A realm that fires often has plateau or island sizes that are wrong,
	# and the owner sees that as a COUNT rather than as a board that was silently repaired.
	var host_now: Dictionary = _host_cell_set(walkable_cells)
	var objective_site_built: Dictionary = {}
	if not _has_objective_site(host_now, walkable_cells):
		var site: Dictionary = _find_objective_site(host_now, walkable_cells, w, h)
		if not site.is_empty():
			var site_col: int = int(site["col"])
			var site_row: int = int(site["row"])
			var site_pairs: Array = []
			for dc in range(-1, 2):
				for dr in range(-1, 2):
					var scol: int = site_col + dc
					var srow: int = site_row + dr
					site_pairs.append([scol, srow])
					walkable_cells["%d,%d" % [scol, srow]] = true
			plateaus.append({
				"col": site_col - 1, "row": site_row - 1, "w": 3, "h": 3,
				"cells": site_pairs,
				"objective_site": true,
			})
			objective_site_built = { "col": site_col, "row": site_row }

	# ---- Islands (V2-COMBAT-003 terrain commit 3) ----
	# Deliberate, moated, multi-cell scenery. Minted LAST, after the connectivity repair,
	# so the repair's guarantee stays a statement about plateaus plus bridges. See the
	# ISLANDS block in the file header for the three properties this pass guarantees.
	var isl_count_min: int = max(int(sig.get("island_count_min", 1)), 0)
	var isl_count_max: int = max(int(sig.get("island_count_max", 2)), isl_count_min)
	var isl_count_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".island.count")
	var island_count: int = isl_count_rng.randi_range(isl_count_min, isl_count_max)

	# Size clamping. Authored size is a REQUEST; board area has the final say, so config
	# can never produce a nonsense layout (wisdom's 8..50 on a 12x12 board).
	var board_area: int = w * h
	var per_island_cap: int = max(_ISLAND_MIN_CELLS, board_area / _ISLAND_MAX_AREA_DIVISOR)
	var total_island_cap: int = max(_ISLAND_MIN_CELLS, board_area / _ISLAND_TOTAL_AREA_DIVISOR)
	var isl_size_max: int = clampi(
		max(int(sig.get("island_size_max", _ISLAND_MIN_CELLS)), _ISLAND_MIN_CELLS),
		_ISLAND_MIN_CELLS, per_island_cap
	)
	var isl_size_min: int = clampi(
		max(int(sig.get("island_size_min", _ISLAND_MIN_CELLS)), _ISLAND_MIN_CELLS),
		_ISLAND_MIN_CELLS, isl_size_max
	)

	var islands: Array = []
	var island_cells_used: int = 0
	for ik in range(island_count):
		if island_cells_used + _ISLAND_MIN_CELLS > total_island_cap:
			break
		# Each island derives its OWN stream, exactly as a straggler did. An island makes
		# more than one draw (size, seed cell, one per growth step), but every one of them
		# lands on this stream, so island k's draws can never shift island k+1's.
		var i_rng := CampaignSeed.get_rng_from(realm_seed, prefix + ".island.%d" % ik)
		var target: int = i_rng.randi_range(isl_size_min, isl_size_max)
		target = min(target, total_island_cap - island_cells_used)

		# `blocked` is the moat: everything walkable so far, DILATED by one cell in all 8
		# directions. Recomputed each pass so a later island is moated from an earlier one
		# as strictly as it is from the mainland.
		var blocked: Dictionary = _dilate_8(walkable_cells, w, h)
		var free_cells: Array = _free_island_cells(blocked, w, h)
		if free_cells.is_empty():
			break
		var seed_key: String = free_cells[i_rng.randi_range(0, free_cells.size() - 1)]
		var blob: Array = _grow_island(seed_key, target, blocked, w, h, i_rng)
		if blob.size() < _ISLAND_MIN_CELLS:
			# Not enough moated room here. Discard rather than emit a stub — a 1-cell
			# island is the defect this commit removes. The next island still gets a turn.
			continue

		blob.sort_custom(Callable(StageTerrain, "_cell_key_less"))
		var min_c: int = 999999
		var min_r: int = 999999
		var max_c: int = -999999
		var max_r: int = -999999
		var pairs: Array = []
		for bk in blob:
			var bparts := (bk as String).split(",")
			var bcol: int = int(bparts[0])
			var brow: int = int(bparts[1])
			pairs.append([bcol, brow])
			min_c = min(min_c, bcol)
			min_r = min(min_r, brow)
			max_c = max(max_c, bcol)
			max_r = max(max_r, brow)
			walkable_cells[bk] = true
		islands.append({
			"col": min_c, "row": min_r,
			"w": max_c - min_c + 1, "h": max_r - min_r + 1,
			"cells": pairs,
		})
		island_cells_used += blob.size()

	var out: Dictionary = {
		"bounds":    { "w": w, "h": h },
		"plateaus":  plateaus,
		"bridges":   bridges,
		"islands":   islands,
	}
	# Present ONLY when decision 25 fired, so a board that never needed the compensation is
	# byte-identical to one generated before this pass existed.
	if not objective_site_built.is_empty():
		out["objective_site_built"] = objective_site_built
	return out


## Returns a Dictionary used as a set: key = "%d,%d" % [col,row] -> true,
## covering every cell in plateaus/bridges/islands (plus the legacy "stragglers" key).
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

	# Islands (V2-COMBAT-003 terrain commit 3).
	#
	# TWO keys are read, on purpose. "islands" is what the generator writes now. The legacy
	# "stragglers" key is kept as a DOCUMENTED FALLBACK for terrain already persisted in a
	# save (FlowStageExploreState calls terrain "permanent geometry — must survive session
	# reset"; SaveService repairs the field but not its contents).
	#
	# Saves are disposable and the owner accepts a clean break, so the fallback is not here
	# to preserve an old campaign. It is here because dropping the key is SILENT: an old
	# board would simply lose ground, no error, no failing test — the exact trap named in
	# docs/v2-combat-003-handoff.md section 12.6. Five lines of insurance against a silent
	# loss of walkable ground is the right trade. The generator never writes "stragglers"
	# again, so on any newly generated board this branch is dead code by construction.
	#
	# One loop serves both shapes: an island carries "cells" (a multi-cell blob), a legacy
	# straggler carries only col/row (exactly one cell).
	for list_key in ["islands", "stragglers"]:
		var list_v: Variant = terrain.get(list_key, [])
		var list: Array = list_v if list_v is Array else []
		for s_v in list:
			var s: Dictionary = s_v if s_v is Dictionary else {}
			var blob_v: Variant = s.get("cells", [])
			var blob: Array = blob_v if blob_v is Array else []
			if blob.is_empty():
				cells["%d,%d" % [int(s.get("col", 0)), int(s.get("row", 0))]] = true
				continue
			for pair_v in blob:
				var pair: Array = pair_v if pair_v is Array else []
				if pair.size() >= 2:
					cells["%d,%d" % [int(pair[0]), int(pair[1])]] = true

	return cells


## Returns true if cell {col,row} is walkable.
## If walkable is empty (legacy all-walkable sentinel), always returns true.
static func is_walkable(cell: Dictionary, walkable: Dictionary) -> bool:
	if walkable.is_empty():
		return true
	var key: String = "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]
	return walkable.has(key)


## Returns true when `to_cell` is a legal single-cell 8-direction edge from
## `from_cell`. `walkable` remains the collision authority; an empty set keeps
## the legacy all-walkable sentinel behavior, constrained by `bounds` when the
## caller supplies them.
##
## Diagonals may pass one solid orthogonal side, but not two. Actor occupancy is
## deliberately absent from this topology seam and therefore never forms a
## solid corner.
static func is_legal_edge(
	from_cell: Dictionary,
	to_cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary = {}
) -> bool:
	var from_col: int = int(from_cell.get("col", 0))
	var from_row: int = int(from_cell.get("row", 0))
	var to_col: int = int(to_cell.get("col", 0))
	var to_row: int = int(to_cell.get("row", 0))
	var delta_col: int = abs(to_col - from_col)
	var delta_row: int = abs(to_row - from_row)

	# Exactly one 8-direction edge: reject self and non-adjacent cells.
	if max(delta_col, delta_row) != 1:
		return false
	if not _is_walkable_in_bounds(from_cell, walkable, bounds):
		return false
	if not _is_walkable_in_bounds(to_cell, walkable, bounds):
		return false

	if delta_col == 1 and delta_row == 1:
		var side_col := { "col": to_col, "row": from_row }
		var side_row := { "col": from_col, "row": to_row }
		if not _is_walkable_in_bounds(side_col, walkable, bounds) \
				and not _is_walkable_in_bounds(side_row, walkable, bounds):
			return false

	return true


## Returns all legal one-cell neighbours in stable numeric (col, row) order.
## Numeric ordering is intentional: sorting canonical string keys would place
## multi-digit and negative coordinates in lexical rather than semantic order.
static func legal_neighbors(
	cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary = {}
) -> Array:
	var col: int = int(cell.get("col", 0))
	var row: int = int(cell.get("row", 0))
	var result: Array = []
	for delta_col in range(-1, 2):
		for delta_row in range(-1, 2):
			if delta_col == 0 and delta_row == 0:
				continue
			var candidate := {
				"col": col + delta_col,
				"row": row + delta_row,
			}
			if is_legal_edge(cell, candidate, walkable, bounds):
				result.append(candidate)
	return result


## Returns the party's explore entry cell {col,row}: the leftmost column OF THE HOST
## REGION, and among that column's cells the one nearest to row = bounds.h / 2.
## If walkable is empty (legacy), returns {col:0, row: bounds.h/2}.
##
## V2-COMBAT-003 terrain commit 3 — WHY THE HOST REGION AND NOT THE WHOLE SET.
##
## This used to take the leftmost column of the ENTIRE walkable set. That was safe only by
## accident: the old straggler pass minted single cells that touched existing ground at a
## corner, and the explore layer's own reachability rule (bfs_distance_field, immediately
## below) is a plain 8-direction fill, so a corner touch was genuinely walkable in
## exploration even though the generator's stricter shared-side rule called it cut off.
##
## A commit-3 island is MOATED: it has a clear ring of void on all eight sides, so it is
## cut off under BOTH rules. Plateaus never occupy column 0 (_BORDER_MARGIN), islands may,
## and the entry cell is chosen by leftmost column — so an island would routinely capture
## the party's start and freeze exploration on turn one, with no route anywhere.
##
## Measured on 1,800 boards per regime, ten virtue signatures, before and after the island
## rewrite: entry landed off the host region on 158/1,800 combat-bounds and 144/1,800
## explore-bounds boards BEFORE (all of them 8-direction reachable, so all of them
## harmless), and would have landed there on 766/1,800 and 867/1,800 AFTER, every one of
## them a genuine dead start. Anchoring the entry to the host region removes both classes.
##
## The host rule is the same one the connectivity repair and GridService.largest_walkable_region
## use: largest region, ties by numerically lowest (col,row). Regions are judged by SHARED
## SIDE, the stricter of the two rules, so a cell this function returns is reachable under
## the explore layer's looser 8-direction fill as well.
##
## This function makes NO RNG draw, before or after the change.
static func entry_cell(walkable: Dictionary, bounds: Dictionary) -> Dictionary:
	var bh: int = int(bounds.get("h", 30))
	var mid: int = bh / 2

	if walkable.is_empty():
		return { "col": 0, "row": mid }

	# Restrict to the host region. Falls back to the whole set if the fill somehow yields
	# nothing, so this can never return worse than the pre-commit-3 behaviour.
	var components := _flood_fill_components(walkable)
	var host_idx: int = _host_component_index(components)
	var pool: Dictionary = walkable
	if host_idx >= 0:
		var host_set: Dictionary = {}
		for k in (components[host_idx] as Array):
			host_set[k] = true
		if not host_set.is_empty():
			pool = host_set

	# Find the minimum column among all pool cells.
	var min_col: int = 999999
	for key in pool:
		var parts := (key as String).split(",")
		var c: int = int(parts[0])
		if c < min_col:
			min_col = c

	# Among all cells in that column, pick the one whose row is closest to mid.
	var best_row: int = -1
	var best_dist: int = 999999
	for key in pool:
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

## Bounds-aware form of is_walkable used by shared edge legality. Bounds are
## optional for compatibility; when supplied they describe a zero-based w x h
## rectangle.
static func _is_walkable_in_bounds(
	cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary
) -> bool:
	if not bounds.is_empty():
		var col: int = int(cell.get("col", 0))
		var row: int = int(cell.get("row", 0))
		var width: int = int(bounds.get("w", 0))
		var height: int = int(bounds.get("h", 0))
		if col < 0 or row < 0 or col >= width or row >= height:
			return false
	return is_walkable(cell, walkable)

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


## Flood-fill connected-components on walkable_cells under the SHARED-SIDE rule:
## two cells belong to one component only when they share a full side (4-direction
## adjacency). Diagonals never join two components.
##
## V2-COMBAT-003 terrain commit 2 — this used to be plain 8-direction adjacency, which
## counted two plateaus touching at a single corner as ONE component. The connectivity
## repair above therefore believed such a board was already whole and built no bridge,
## so the guarantee existed in the code and never fired. Measured cut-off regions reached
## 176 cells on explore-map bounds.
##
## The shared-side rule is deliberately STRICTER than `is_legal_edge`, which allows a
## diagonal step as long as ONE orthogonal side cell is open. Strictness is the safe
## direction: an orthogonal step between two walkable in-bounds cells is always a legal
## edge, so anything this function calls connected is certainly traversable in play. The
## converse does not hold, and that is fine — it only means the repair may bridge ground
## that was already walkable by a diagonal squeeze.
##
## Traversal is seeded from the cell keys in numeric (col, row) order, so both the order
## of the returned components and the order of cells inside each component are fully
## deterministic and independent of Dictionary insertion order. Each component's cell list
## is returned in numeric (col, row) order as well.
##
## Returns Array of Arrays, each inner Array is a list of cell keys.
static func _flood_fill_components(walkable_cells: Dictionary) -> Array:
	var visited: Dictionary = {}
	var components: Array = []

	# Shared side only — no diagonals.
	var deltas: Array = [
		          [ 0, -1],
		[-1, 0],           [ 1, 0],
		          [ 0,  1],
	]

	var seed_keys: Array = walkable_cells.keys()
	seed_keys.sort_custom(Callable(StageTerrain, "_cell_key_less"))

	for key in seed_keys:
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
		component.sort_custom(Callable(StageTerrain, "_cell_key_less"))
		components.append(component)

	return components


## True if cell key `a` sorts before cell key `b` in numeric (col, row) order.
## NOT a lexical string compare — that would order "10,2" before "9,1".
static func _cell_key_less(a: String, b: String) -> bool:
	var pa := (a as String).split(",")
	var pb := (b as String).split(",")
	var ac: int = int(pa[0])
	var ar: int = int(pa[1])
	var bc: int = int(pb[0])
	var br: int = int(pb[1])
	if ac != bc:
		return ac < bc
	return ar < br


## Index of the HOST component: the largest one, ties broken by the numerically lowest
## (col, row) cell. Same rule GridService.largest_walkable_region uses to pick the region
## every actor is placed in, so the generator repairs toward the region play actually uses.
## Returns -1 for an empty component list.
static func _host_component_index(components: Array) -> int:
	var best: int = -1
	for i in range(components.size()):
		if best < 0:
			best = i
			continue
		var cur: Array = components[i]
		var champ: Array = components[best]
		if cur.size() > champ.size():
			best = i
		elif cur.size() == champ.size() and cur.size() > 0 \
				and _cell_key_less(str(cur[0]), str(champ[0])):
			# Components are cell-sorted, so element 0 IS the numerically lowest cell.
			best = i
	return best


## The host region of `walkable_cells` as a set of "col,row" keys — largest region under
## the shared-side rule, ties by the numerically lowest cell. Empty when there is no
## walkable ground at all.
static func _host_cell_set(walkable_cells: Dictionary) -> Dictionary:
	var components := _flood_fill_components(walkable_cells)
	var host_idx: int = _host_component_index(components)
	var out: Dictionary = {}
	if host_idx < 0:
		return out
	for k in (components[host_idx] as Array):
		out[k] = true
	return out


## Decision 24, as a terrain test: does `key` have all EIGHT neighbours walkable?
## Occupancy is not this function's business — nothing stands on a board being generated.
static func has_eight_walkable_neighbours(key: String, walkable_cells: Dictionary) -> bool:
	var parts := (key as String).split(",")
	if parts.size() != 2:
		return false
	var c: int = int(parts[0])
	var r: int = int(parts[1])
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			if not walkable_cells.has("%d,%d" % [c + dc, r + dr]):
				return false
	return true


## True when the host region already offers at least one legal objective site.
## A cell whose eight neighbours are all walkable is, with the cell itself, a 3x3 block of
## mutually shared-side-connected ground, so if the cell is in the host region the whole
## block is too.
static func _has_objective_site(host: Dictionary, walkable_cells: Dictionary) -> bool:
	for k in host.keys():
		if has_eight_walkable_neighbours(str(k), walkable_cells):
			return true
	return false


## Chooses the centre of the 3x3 block decision 25 builds. Returns {} when no legal
## candidate exists, in which case the board is emitted unchanged — a silent partial repair
## would be worse than a measurable gap.
##
## A candidate centre must satisfy all three:
##   * the whole 3x3 fits inside the bounds;
##   * every one of the nine cells is either void or already in the host region — a cell of
##     another region would be absorbed, which is the connectivity repair's decision to make
##     and not this pass's;
##   * at least one of the nine cells is already host, which is what joins the block to the
##     host region: the nine cells are mutually shared-side connected, so one host cell
##     among them puts all nine in the host region.
## Ranked by overlap with existing ground descending — the block that adds the fewest new
## cells wins — then by the numerically lowest centre. No RNG.
static func _find_objective_site(host: Dictionary, walkable_cells: Dictionary, w: int, h: int) -> Dictionary:
	var best_col: int = -1
	var best_row: int = -1
	var best_overlap: int = -1
	for cc in range(1, w - 1):
		for rr in range(1, h - 1):
			var overlap: int = 0
			var legal: bool = true
			for dc in range(-1, 2):
				for dr in range(-1, 2):
					var nk: String = "%d,%d" % [cc + dc, rr + dr]
					if not walkable_cells.has(nk):
						continue
					if host.has(nk):
						overlap += 1
					else:
						legal = false
			if not legal or overlap < 1:
				continue
			if overlap > best_overlap:
				best_overlap = overlap
				best_col = cc
				best_row = rr
	if best_col < 0:
		return {}
	return { "col": best_col, "row": best_row }


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
##
## SHARED-SIDE PROOF (V2-COMBAT-003 terrain commit 2). The repair loop now judges
## connectivity by a shared side, not by 8-direction adjacency, so "the legs overlap at
## the corner" has to be exact. It is, and here is why — the L-corner is where it could
## have failed:
##   * Each leg is a FULL RECTANGLE of cells, so each leg on its own is shared-side
##     connected.
##   * The horizontal leg spans rows [h_row_start, h_row_start + bridge_width - 1], and
##     h_row_start = clamp(ar - bridge_width / 2, 0, map_h - bridge_width). For any ar in
##     [0, map_h - 1] that span CONTAINS row ar: the clamp can only pull the span toward
##     ar, never past it. Its column span [min(ac,bc), max(ac,bc)] contains both ac and bc.
##   * By the same argument the vertical leg's column span contains column bc, and its row
##     span [min(ar,br), max(ar,br)] contains both ar and br.
##   * Therefore cell (bc, ar) lies in BOTH legs. The two legs SHARE A CELL — they do not
##     merely touch at a corner — so their union is shared-side connected, and it contains
##     (ac, ar) and (bc, br).
##   * The vertical-first branch is the mirror image and shares cell (ac, br).
## Asserted directly by terrain/bridge_connects_shared_side over the full L-shape space.
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


## V2-COMBAT-003 terrain commit 3 — THE MOAT.
## Returns `walkable_cells` UNION its full 8-direction dilation, clipped to the board.
## Every cell in the result is either ground or touches ground at a side or a corner, so a
## cell OUTSIDE the result is guaranteed to have a clear ring of void between it and every
## existing region. Island placement and island growth both draw only from outside it.
static func _dilate_8(walkable_cells: Dictionary, map_w: int, map_h: int) -> Dictionary:
	var blocked: Dictionary = {}
	for key in walkable_cells:
		var parts := (key as String).split(",")
		var cc: int = int(parts[0])
		var cr: int = int(parts[1])
		for dc in range(-1, 2):
			for dr in range(-1, 2):
				var nc: int = cc + dc
				var nr: int = cr + dr
				if nc < 0 or nc >= map_w or nr < 0 or nr >= map_h:
					continue
				blocked["%d,%d" % [nc, nr]] = true
	return blocked


## Every in-bounds cell an island may legally occupy, in stable numeric (col,row) order.
## Numeric, not lexical: "10,3" sorts before "9,3" as a string, and a lexical order would
## bias every island seed toward multi-digit columns.
static func _free_island_cells(blocked: Dictionary, map_w: int, map_h: int) -> Array:
	var result: Array = []
	for c in range(map_w):
		for r in range(map_h):
			var k: String = "%d,%d" % [c, r]
			if not blocked.has(k):
				result.append(k)
	return result


## Grow one island blob from `seed_key` toward `target` cells and return its cell keys.
##
## Two invariants, both load-bearing:
##   * Every added cell shares a full SIDE with the blob, so the island is exactly ONE
##     region under the shared-side rule the connectivity repair uses.
##   * Every added cell is outside `blocked`, so the moat survives growth. `blocked` is a
##     snapshot taken before this island began and never includes this island's own cells,
##     which is why the blob may touch itself and nothing else.
##
## COMPACTNESS: the frontier cell with the most 8-direction contacts with the blob wins.
## That fills concavities before extending a limb, which is what stops an island becoming
## a one-cell-wide worm. The RNG only chooses among equally-compact candidates.
##
## Returns fewer than `target` cells when the moated space runs out; the caller discards a
## blob below _ISLAND_MIN_CELLS rather than emitting a stub.
static func _grow_island(
	seed_key: String,
	target: int,
	blocked: Dictionary,
	map_w: int,
	map_h: int,
	rng: RandomNumberGenerator
) -> Array:
	var blob: Dictionary = { seed_key: true }
	var order: Array = [seed_key]
	var side_deltas: Array = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	while order.size() < target:
		var frontier: Dictionary = {}
		for k in order:
			var parts := (k as String).split(",")
			var cc: int = int(parts[0])
			var cr: int = int(parts[1])
			for d_v in side_deltas:
				var d: Array = d_v
				var nc: int = cc + int(d[0])
				var nr: int = cr + int(d[1])
				if nc < 0 or nc >= map_w or nr < 0 or nr >= map_h:
					continue
				var nk: String = "%d,%d" % [nc, nr]
				if blocked.has(nk) or blob.has(nk):
					continue
				frontier[nk] = true
		if frontier.is_empty():
			break
		var keys: Array = frontier.keys()
		keys.sort_custom(Callable(StageTerrain, "_cell_key_less"))
		var best_score: int = -1
		var best: Array = []
		for k2 in keys:
			var score: int = _contacts_8(k2, blob)
			if score > best_score:
				best_score = score
				best = [k2]
			elif score == best_score:
				best.append(k2)
		var chosen: String = best[rng.randi_range(0, best.size() - 1)]
		blob[chosen] = true
		order.append(chosen)
	return order


## Number of the 8 neighbours of `key` that are already in `blob`.
static func _contacts_8(key: String, blob: Dictionary) -> int:
	var parts := (key as String).split(",")
	var cc: int = int(parts[0])
	var cr: int = int(parts[1])
	var n: int = 0
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			if blob.has("%d,%d" % [cc + dc, cr + dr]):
				n += 1
	return n

