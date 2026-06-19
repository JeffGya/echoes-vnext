extends RefCounted

class_name SanctumLayoutService

const LAYOUT_VERSION := 5
const CENTER_CELL := Vector2i(0, 0)
const ASE_FLAME_CELL := Vector2i(0, 0)

# Chebyshev exclusion radius around any placed institution or the Ase Flame.
# No new institution may be placed within this distance of an existing one.
const PLACEMENT_EXCLUSION_RADIUS := 2

# Starter layout shape:
#   5×5 main sanctum — Ase Flame at center (0,0), x/y in [-2..2]
#   3×3 party staging area — connected below the main sanctum, y in [3..5], x in [-1..1]
const MAIN_SANCTUM_HALF := 2
const PARTY_HALF := 1
const PARTY_Y_START := 3
const PARTY_Y_END := 5


static func make_starter_layout() -> Dictionary:
	var tiles: Array = []
	# 5×5 main sanctum — Ase Flame anchored at (0,0).
	for y in range(-MAIN_SANCTUM_HALF, MAIN_SANCTUM_HALF + 1):
		for x in range(-MAIN_SANCTUM_HALF, MAIN_SANCTUM_HALF + 1):
			tiles.append({ "x": x, "y": y, "kind": "floor" })
	# 3×3 party staging area — connected directly below the main sanctum.
	for y in range(PARTY_Y_START, PARTY_Y_END + 1):
		for x in range(-PARTY_HALF, PARTY_HALF + 1):
			tiles.append({ "x": x, "y": y, "kind": "floor" })
	return {
		"version": LAYOUT_VERSION,
		"origin": { "x": 0, "y": 0 },
		"tiles": tiles,
	}


static func ensure_layout(save_data: Dictionary, inst_snapshot: Array = []) -> Dictionary:
	var sanctum := _ensure_sanctum(save_data)
	if not sanctum.has("layout") or not (sanctum["layout"] is Dictionary):
		sanctum["layout"] = make_starter_layout()
	else:
		var layout: Dictionary = sanctum["layout"]
		var version := 0
		if not layout.has("version") or (typeof(layout["version"]) != TYPE_INT and typeof(layout["version"]) != TYPE_FLOAT):
			version = 0
		else:
			version = int(layout["version"])
		if version < LAYOUT_VERSION:
			sanctum["layout"] = make_starter_layout()
			# Do NOT early-return — fall through so Ase Flame + institution tiles are added.
		if not layout.has("origin") or not (layout["origin"] is Dictionary):
			layout["origin"] = { "x": 0, "y": 0 }
		if not layout.has("tiles") or not (layout["tiles"] is Array) or (layout["tiles"] as Array).is_empty():
			layout["tiles"] = make_starter_layout()["tiles"]

	var layout: Dictionary = sanctum["layout"]
	var tiles: Array = layout["tiles"] as Array

	# Rebuild tiles fresh from save_data each call so positions stay in sync.
	# Start with the canonical starter floor, then layer in institution tiles.
	var starter := make_starter_layout()
	var base_tiles: Array = starter["tiles"]

	# Collect existing floor cell set for adjacency / validity checks.
	var floor_cells: Dictionary = {}
	for tile in base_tiles:
		floor_cells[Vector2i(int(tile["x"]), int(tile["y"]))] = true

	# Always include Ase Flame tile (permanent spiritual anchor at center).
	var ase_flame_entry := { "x": ASE_FLAME_CELL.x, "y": ASE_FLAME_CELL.y, "kind": "ase_flame" }

	# Add unlocked institution tiles from their saved positions.
	var inst_tiles: Array = []
	var institutions_v: Variant = (sanctum as Dictionary).get("institutions", {})
	var institutions: Dictionary = institutions_v if institutions_v is Dictionary else {}
	for inst_id in institutions:
		var inst_v: Variant = institutions.get(inst_id, {})
		var inst: Dictionary = inst_v if inst_v is Dictionary else {}
		if not bool(inst.get("unlocked", false)):
			continue
		var pos_v: Variant = inst.get("position", { "x": 0, "y": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "x": 0, "y": 0 }
		var cell := Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))
		inst_tiles.append({ "x": cell.x, "y": cell.y, "kind": "institution", "inst_id": inst_id })
		# Bridge: connect from nearest existing floor tile to the institution.
		var bridge := _bridge_cells(cell, floor_cells)
		for b in bridge:
			var bc: Vector2i = b
			if not floor_cells.has(bc):
				base_tiles.append({ "x": bc.x, "y": bc.y, "kind": "floor" })
				floor_cells[bc] = true
		# Ring: 3×3 floor plaza around the institution (8 surrounding tiles).
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue  # Institution tile itself — not a floor tile.
				var ring_cell := cell + Vector2i(dx, dy)
				if not floor_cells.has(ring_cell):
					base_tiles.append({ "x": ring_cell.x, "y": ring_cell.y, "kind": "floor" })
					floor_cells[ring_cell] = true

	# Compose final tile list: floor base + ase_flame + institutions.
	var final_tiles: Array = base_tiles.duplicate()
	final_tiles.append(ase_flame_entry)
	for it in inst_tiles:
		final_tiles.append(it)

	layout["tiles"] = final_tiles
	return layout


static func ensure_starter_occupant(save_data: Dictionary, roster: Array = [], active_party_ids: Array = [], inst_snapshot: Array = []) -> Array:
	var sanctum := _ensure_sanctum(save_data)
	ensure_layout(save_data, inst_snapshot)
	var occupants: Array = []

	# Ase Flame always first — permanent spiritual anchor.
	occupants.append({
		"id":   "ase_flame",
		"name": "Ase Flame",
		"kind": "ase_flame",
		"x":    ASE_FLAME_CELL.x,
		"y":    ASE_FLAME_CELL.y,
	})

	# Institution markers — only show ESTABLISHED institutions on the map.
	# Candidates are shown in the Institutions panel UI only, not spatially.
	var institutions_v: Variant = (sanctum as Dictionary).get("institutions", {})
	var institutions: Dictionary = institutions_v if institutions_v is Dictionary else {}
	for inst_id in institutions:
		var inst_v: Variant = institutions.get(inst_id, {})
		var inst: Dictionary = inst_v if inst_v is Dictionary else {}
		var is_unlocked := bool(inst.get("unlocked", false))
		if not is_unlocked:
			continue  # Candidates not drawn on the map.
		var pos_v: Variant = inst.get("position", { "x": 0, "y": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "x": 0, "y": 0 }
		var cell := Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))
		occupants.append({
			"id":          inst_id,
			"name":        inst_id.capitalize().replace("_", " "),
			"kind":        "institution",
			"x":           cell.x,
			"y":           cell.y,
			"is_unlocked": true,
			"condition":   str(inst.get("condition", "neglected")),
		})

	# Use the provided roster if given, otherwise fall back to save_data roster.
	var use_roster: Array = roster
	if use_roster.is_empty():
		var roster_v: Variant = sanctum.get("roster", [])
		use_roster = roster_v if roster_v is Array else []

	# Place all roster echoes with the canonical player-facing emotional status.
	var party_set: Dictionary = {}
	for pid in active_party_ids:
		party_set[str(pid)] = true

	var echo_index := 0
	for echo_v in use_roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var echo_id := str(echo.get("id", ""))
		if echo_id.is_empty():
			continue

		# Determine zone based on assignment or party status.
		var assigned_inst := _find_institution_for_echo(echo_id, sanctum)
		var cell: Vector2i
		if not assigned_inst.is_empty():
			# Echo assigned to institution — place adjacent to its tile.
			var inst_v: Variant = institutions.get(assigned_inst, {})
			var inst: Dictionary = inst_v if inst_v is Dictionary else {}
			var pos_v: Variant = inst.get("position", { "x": 0, "y": 0 })
			var pos: Dictionary = pos_v if pos_v is Dictionary else { "x": 0, "y": 0 }
			var base_cell := Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))
			cell = Vector2i(base_cell.x + (echo_index % 3) - 1, base_cell.y + 1)
		elif party_set.has(echo_id):
			# Party member — staged in the 3×3 staging area; overflow into deeper rows.
			cell = Vector2i((echo_index % 3) - 1, PARTY_Y_START + (echo_index / 3))
		else:
			# Roaming echo — rows above Ase Flame; overflow into higher rows.
			cell = Vector2i((echo_index % 3) - 1, ASE_FLAME_CELL.y - 1 - (echo_index / 3))

		# Compute emotional_status at snapshot time (not stored in save).
		var emotional_status := "grounded"
		var emotion_v: Variant = echo.get("emotion", {})
		if emotion_v is Dictionary:
			var emotion: Dictionary = emotion_v
			var morale_current := int(emotion.get("morale_current", 50))
			var fear_current := int(emotion.get("fear_current", 0))
			emotional_status = EmotionService.get_emotional_status(morale_current, fear_current)

		occupants.append({
			"id":          echo_id,
			"name":        str(echo.get("name", "")),
			"kind":        "echo",
			"x":           cell.x,
			"y":           cell.y,
			"emotional_status": emotional_status,
		})
		echo_index += 1

	sanctum["occupants"] = occupants
	return occupants


# Returns Array of Vector2i — valid cells for placing a new institution.
# Rules: adjacent (8-dir) to existing floor, not occupied, not already floor,
# not within PLACEMENT_EXCLUSION_RADIUS (Chebyshev) of any institution or Ase Flame.
static func compute_valid_placement_cells(save_data: Dictionary, inst_snapshot: Array = []) -> Array:
	var layout := ensure_layout(save_data, inst_snapshot)
	var tiles: Array = layout.get("tiles", [])

	# Build floor cell set and occupied cell set.
	var floor_cells: Dictionary = {}
	var occupied_cells: Dictionary = {}
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		var kind := str(tile.get("kind", "floor"))
		floor_cells[cell] = true
		if kind != "floor":
			occupied_cells[cell] = true

	# Always mark Ase Flame as occupied.
	occupied_cells[ASE_FLAME_CELL] = true

	# Build exclusion zone: all cells within PLACEMENT_EXCLUSION_RADIUS of any
	# occupied non-floor tile (Chebyshev distance).
	var exclusion: Dictionary = {}
	for cell_v in occupied_cells:
		var center: Vector2i = cell_v
		for dy in range(-PLACEMENT_EXCLUSION_RADIUS, PLACEMENT_EXCLUSION_RADIUS + 1):
			for dx in range(-PLACEMENT_EXCLUSION_RADIUS, PLACEMENT_EXCLUSION_RADIUS + 1):
				exclusion[center + Vector2i(dx, dy)] = true

	# No floor-adjacency requirement: bridge tiles auto-connect any valid placement.
	# Search within a bounding box around the current floor + a margin.
	const SEARCH_MARGIN := 5
	var min_x := 999999; var max_x := -999999
	var min_y := 999999; var max_y := -999999
	for cell_v in floor_cells:
		var cell: Vector2i = cell_v
		if cell.x < min_x: min_x = cell.x
		if cell.x > max_x: max_x = cell.x
		if cell.y < min_y: min_y = cell.y
		if cell.y > max_y: max_y = cell.y

	var result: Array = []
	for y in range(min_y - SEARCH_MARGIN, max_y + SEARCH_MARGIN + 1):
		for x in range(min_x - SEARCH_MARGIN, max_x + SEARCH_MARGIN + 1):
			var cell := Vector2i(x, y)
			if floor_cells.has(cell): continue
			if occupied_cells.has(cell): continue
			if exclusion.has(cell): continue
			result.append(cell)
	return result


static func snapshot_layout(save_data: Dictionary, inst_snapshot: Array = []) -> Dictionary:
	return ensure_layout(save_data, inst_snapshot).duplicate(true)


static func snapshot_occupants(save_data: Dictionary, roster: Array = [], active_party_ids: Array = [], inst_snapshot: Array = []) -> Array:
	return ensure_starter_occupant(save_data, roster, active_party_ids, inst_snapshot).duplicate(true)


# Returns { "valid": bool, "reason": String } for a given candidate cell.
# Takes pre-computed floor_cells and occupied_cells arrays — no save_data needed.
# Used by SanctumShell during placement taps to check any tapped cell in real time.
static func check_placement_validity_from_data(
		cell: Vector2i,
		floor_cells: Array,      # Array[Vector2i] — all floor tiles
		occupied_cells: Array    # Array[Vector2i] — all non-floor tiles (institutions, ase_flame)
) -> Dictionary:
	var floor_set: Dictionary = {}
	for c in floor_cells:
		if c is Vector2i:
			floor_set[c] = true
	var occupied_set: Dictionary = {}
	for c in occupied_cells:
		if c is Vector2i:
			occupied_set[c] = true

	# Rule: already occupied by institution or Ase Flame
	if occupied_set.has(cell):
		return { "valid": false, "reason": "Already occupied" }

	# Rule: already a floor tile
	if floor_set.has(cell):
		return { "valid": false, "reason": "Already part of the floor" }

	# Build exclusion zone (Chebyshev PLACEMENT_EXCLUSION_RADIUS from any occupied cell)
	var exclusion: Dictionary = {}
	for oc in occupied_cells:
		if not (oc is Vector2i):
			continue
		var center: Vector2i = oc
		for dy in range(-PLACEMENT_EXCLUSION_RADIUS, PLACEMENT_EXCLUSION_RADIUS + 1):
			for dx in range(-PLACEMENT_EXCLUSION_RADIUS, PLACEMENT_EXCLUSION_RADIUS + 1):
				exclusion[center + Vector2i(dx, dy)] = true

	# Rule: within exclusion zone of an existing building or Ase Flame
	if exclusion.has(cell):
		return { "valid": false, "reason": "Too close to an existing building" }

	# No floor-adjacency requirement: bridge tiles auto-connect the new institution
	# to the nearest existing floor tile, so any cell outside the exclusion zone is valid.
	return { "valid": true, "reason": "" }


# Returns the bridge floor cells that would be auto-generated if a building were
# placed at `target`. Takes a pre-computed floor_cells array — no save_data needed.
# Used for placement preview only — does not mutate any state.
static func get_bridge_preview_from_floor(target: Vector2i, floor_cells: Array) -> Array:
	var floor_dict: Dictionary = {}
	for c in floor_cells:
		if c is Vector2i:
			floor_dict[c] = true
	return _bridge_cells(target, floor_dict)


# Returns ALL floor tiles that would be auto-generated when placing an institution
# at `target`: the full bridge path from the nearest floor tile + the 3×3 ring
# of floor tiles surrounding the institution. Used for the placement ghost preview
# so the player sees the full floor expansion before confirming.
static func get_placement_floor_preview(target: Vector2i, floor_cells: Array) -> Array:
	var floor_dict: Dictionary = {}
	for c in floor_cells:
		if c is Vector2i:
			floor_dict[c] = true
	# Start with the bridge path.
	var preview: Array = _bridge_cells(target, floor_dict).duplicate()
	# Add the 3×3 ring around the institution (8 surrounding tiles).
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Institution tile itself — not previewed as floor.
			var ring_cell := target + Vector2i(dx, dy)
			if not floor_dict.has(ring_cell) and not preview.has(ring_cell):
				preview.append(ring_cell)
	return preview


# --- Private helpers ---

static func _ensure_sanctum(save_data: Dictionary) -> Dictionary:
	if not save_data.has("sanctum") or not (save_data["sanctum"] is Dictionary):
		save_data["sanctum"] = {}
	return save_data["sanctum"] as Dictionary


# Returns bridge floor cells connecting a new institution cell to the nearest
# existing floor tile. Walks the full L-shaped path (x-axis first, then y-axis)
# so any placement distance is fully connected — not just adjacent placements.
static func _bridge_cells(target: Vector2i, floor_cells: Dictionary) -> Array:
	var nearest := Vector2i(0, 0)
	var best_dist := 999999
	for cell_v in floor_cells:
		var cell: Vector2i = cell_v
		var dist: int = abs(target.x - cell.x) + abs(target.y - cell.y)
		if dist < best_dist:
			best_dist = dist
			nearest = cell
	if best_dist <= 1:
		return []
	var bridge: Array = []
	var cx := nearest.x
	var cy := nearest.y
	# Walk x first, then y, until we reach the cell adjacent to the target.
	while cx != target.x or cy != target.y:
		if cx != target.x:
			cx += sign(target.x - cx)
		elif cy != target.y:
			cy += sign(target.y - cy)
		var step := Vector2i(cx, cy)
		if step == target:
			break  # Never add the institution cell itself as a bridge tile.
		if not floor_cells.has(step):
			bridge.append(step)
	return bridge


# Finds which institution an echo is assigned to, using save_data directly.
static func _find_institution_for_echo(echo_id: String, sanctum: Dictionary) -> String:
	var institutions_v: Variant = sanctum.get("institutions", {})
	if not (institutions_v is Dictionary):
		return ""
	var institutions: Dictionary = institutions_v
	for inst_id in institutions:
		var inst_v: Variant = institutions.get(inst_id, {})
		if not (inst_v is Dictionary):
			continue
		var inst: Dictionary = inst_v
		var occupants_v: Variant = inst.get("occupant_ids", [])
		if not (occupants_v is Array):
			continue
		var occupants: Array = occupants_v
		if echo_id in occupants:
			return inst_id
	return ""
