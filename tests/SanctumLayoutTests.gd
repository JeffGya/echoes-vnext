extends RefCounted
class_name SanctumLayoutTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.layout/ase_flame_always_in_layout",        Callable(SanctumLayoutTests, "_t_ase_flame_in_layout"))
	runner.register_test("sanctum.layout/ase_flame_always_in_occupants",      Callable(SanctumLayoutTests, "_t_ase_flame_in_occupants"))
	runner.register_test("sanctum.layout/institution_tile_after_establish",   Callable(SanctumLayoutTests, "_t_institution_tile_after_establish"))
	runner.register_test("sanctum.layout/all_echoes_placed_as_occupants",     Callable(SanctumLayoutTests, "_t_all_echoes_placed"))
	runner.register_test("sanctum.layout/echo_occupant_has_emotional_status", Callable(SanctumLayoutTests, "_t_echo_has_emotional_status"))
	runner.register_test("sanctum.layout/echo_near_placed_institution",       Callable(SanctumLayoutTests, "_t_echo_near_institution"))
	runner.register_test("sanctum.layout/valid_cells_exclude_occupied",       Callable(SanctumLayoutTests, "_t_valid_cells_exclude_occupied"))
	runner.register_test("sanctum.layout/valid_cells_not_in_exclusion",       Callable(SanctumLayoutTests, "_t_valid_cells_not_in_exclusion"))
	# check_placement_validity_from_data — one test per rule
	runner.register_test("sanctum.layout/validity_already_occupied",          Callable(SanctumLayoutTests, "_t_validity_already_occupied"))
	runner.register_test("sanctum.layout/validity_already_floor",             Callable(SanctumLayoutTests, "_t_validity_already_floor"))
	runner.register_test("sanctum.layout/validity_exclusion_zone",            Callable(SanctumLayoutTests, "_t_validity_exclusion_zone"))
	runner.register_test("sanctum.layout/validity_far_cell_is_valid",         Callable(SanctumLayoutTests, "_t_validity_far_cell_is_valid"))
	runner.register_test("sanctum.layout/validity_valid_cell",                Callable(SanctumLayoutTests, "_t_validity_valid_cell"))
	# get_bridge_preview_from_floor
	runner.register_test("sanctum.layout/bridge_preview_returns_cells",       Callable(SanctumLayoutTests, "_t_bridge_preview_returns_cells"))
	runner.register_test("sanctum.layout/bridge_preview_adjacent_is_empty",   Callable(SanctumLayoutTests, "_t_bridge_preview_adjacent_is_empty"))


static func _make_save(roster: Array = [], institutions: Dictionary = {}) -> Dictionary:
	var save := SaveSchema.make_new_save(42, "test")
	save["sanctum"]["roster"] = roster
	for iid in institutions:
		save["sanctum"]["institutions"][iid] = institutions[iid]
	return save


static func _make_echo(id_str: String, morale: int = 50) -> Dictionary:
	return {
		"id":     id_str,
		"name":   id_str,
		"rank":   1,
		"level":  1,
		"xp_total": 0,
		"emotion": { "morale_current": morale, "fear_current": 0 },
	}


# 1. Layout always contains ase_flame tile at (0,0)
static func _t_ase_flame_in_layout() -> Dictionary:
	var save := _make_save()
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		if str(tile.get("kind", "")) == "ase_flame" and int(tile.get("x", -1)) == 0 and int(tile.get("y", -1)) == 0:
			return { "ok": true }
	return { "ok": false, "error": "ase_flame tile not found at (0,0)" }


# 2. Occupants always contain ase_flame as first entry
static func _t_ase_flame_in_occupants() -> Dictionary:
	var save := _make_save()
	var occupants := SanctumLayoutService.snapshot_occupants(save)
	if occupants.is_empty():
		return { "ok": false, "error": "occupants empty" }
	var first_v: Variant = occupants[0]
	if not (first_v is Dictionary):
		return { "ok": false, "error": "first occupant not a dict" }
	var first: Dictionary = first_v
	if str(first.get("kind", "")) != "ase_flame":
		return { "ok": false, "error": "first occupant kind is not ase_flame: %s" % first.get("kind","") }
	return { "ok": true }


# 3. Established institution appears in layout tiles
static func _t_institution_tile_after_establish() -> Dictionary:
	var hearth := {
		"unlocked": true,
		"tier": 0,
		"condition": "neglected",
		"last_activated_unix": 0,
		"occupant_ids": [],
		"position": { "x": 3, "y": 0 },
	}
	var save := _make_save([], { "hearth": hearth })
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		if str(tile.get("kind", "")) == "institution" and str(tile.get("inst_id", "")) == "hearth":
			if int(tile.get("x", -1)) == 3 and int(tile.get("y", -1)) == 0:
				return { "ok": true }
	return { "ok": false, "error": "hearth institution tile not found at (3,0)" }


# 4. All roster echoes appear as occupants
static func _t_all_echoes_placed() -> Dictionary:
	var roster := [_make_echo("e1"), _make_echo("e2"), _make_echo("e3")]
	var save := _make_save(roster)
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	var echo_ids_found: Array = []
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo":
			echo_ids_found.append(str(occ.get("id", "")))
	for id_str in ["e1", "e2", "e3"]:
		if not echo_ids_found.has(id_str):
			return { "ok": false, "error": "echo %s not in occupants" % id_str }
	return { "ok": true }


# 5. Each Echo occupant exposes the canonical emotional status only.
static func _t_echo_has_emotional_status() -> Dictionary:
	var roster := [_make_echo("e1", 80)]  # 80 morale = inspired
	var save := _make_save(roster)
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo" and str(occ.get("id", "")) == "e1":
			var status := str(occ.get("emotional_status", ""))
			if status.is_empty():
				return { "ok": false, "error": "emotional_status missing for e1" }
			if occ.has("morale_tier"):
				return { "ok": false, "error": "occupant exposes legacy morale_tier" }
			return { "ok": true }
	return { "ok": false, "error": "echo e1 not found in occupants" }


# 6. Echo assigned to institution appears adjacent to its tile
static func _t_echo_near_institution() -> Dictionary:
	var hearth := {
		"unlocked": true,
		"tier": 0,
		"condition": "neglected",
		"last_activated_unix": 0,
		"occupant_ids": ["e1"],
		"position": { "x": 3, "y": 0 },
	}
	var roster := [_make_echo("e1")]
	var save := _make_save(roster, { "hearth": hearth })
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo" and str(occ.get("id", "")) == "e1":
			var ex := int(occ.get("x", -99))
			var ey := int(occ.get("y", -99))
			# Echo should be within 2 tiles of hearth at (3,0)
			var dist: int = max(abs(ex - 3), abs(ey - 0))
			if dist <= 2:
				return { "ok": true }
			return { "ok": false, "error": "echo e1 at (%d,%d) is not near hearth at (3,0)" % [ex, ey] }
	return { "ok": false, "error": "echo e1 not found" }


# 7. Valid placement cells don't include occupied positions (Ase Flame at 0,0)
static func _t_valid_cells_exclude_occupied() -> Dictionary:
	var save := _make_save()
	var cells: Array = SanctumLayoutService.compute_valid_placement_cells(save)
	for cell_v in cells:
		if cell_v is Vector2i:
			var cell: Vector2i = cell_v
			if cell == Vector2i(0, 0):
				return { "ok": false, "error": "valid cells include Ase Flame position (0,0)" }
	if cells.is_empty():
		return { "ok": false, "error": "valid cells is empty — expected at least some adjacents" }
	return { "ok": true }


# 8. All valid placement cells are outside the exclusion zone of every occupied tile
static func _t_valid_cells_not_in_exclusion() -> Dictionary:
	var save := _make_save()
	var cells: Array = SanctumLayoutService.compute_valid_placement_cells(save)
	if cells.is_empty():
		return { "ok": false, "error": "valid cells is empty — expected non-empty for 5×5 starter layout" }
	# Ase Flame at (0,0) with exclusion radius 2: no valid cell should be
	# within Chebyshev distance 2 of (0,0).
	const EXCL := SanctumLayoutService.PLACEMENT_EXCLUSION_RADIUS
	for cell_v in cells:
		if not (cell_v is Vector2i): continue
		var cell: Vector2i = cell_v
		var cheb := maxi(abs(cell.x), abs(cell.y))
		if cheb <= EXCL:
			return { "ok": false, "error": "valid cell (%d,%d) is within Ase Flame exclusion zone" % [cell.x, cell.y] }
	return { "ok": true }


# --- check_placement_validity_from_data tests ---
# Test setup: a single floor tile at (5,0), Ase Flame occupant at (0,0).
# This gives a clear scenario with no overlap between floor and exclusion zones.

# 9. Already-occupied cell returns "Already occupied"
static func _t_validity_already_occupied() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(0, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for occupied cell, got valid" }
	if str(result.get("reason", "")) != "Already occupied":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 10. Floor-tile cell returns "Already part of the floor"
static func _t_validity_already_floor() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(5, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for floor cell, got valid" }
	if str(result.get("reason", "")) != "Already part of the floor":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 11. Cell within Chebyshev-2 of occupied returns "Too close to an existing building"
static func _t_validity_exclusion_zone() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (2,0) is Chebyshev distance 2 from (0,0) — inside the exclusion zone
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(2, 0), floor_cells, occupied_cells)
	if bool(result.get("valid", true)):
		return { "ok": false, "error": "expected invalid for exclusion-zone cell, got valid" }
	if str(result.get("reason", "")) != "Too close to an existing building":
		return { "ok": false, "error": "wrong reason: %s" % result.get("reason", "") }
	return { "ok": true }


# 12. A far cell outside the exclusion zone is now valid (no adjacency requirement)
static func _t_validity_far_cell_is_valid() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (10,10) is far from floor and outside all exclusion zones — should be valid.
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(10, 10), floor_cells, occupied_cells)
	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected valid for far cell (10,10), got: %s" % result.get("reason", "") }
	return { "ok": true }


# 13. A valid cell returns { "valid": true, "reason": "" }
static func _t_validity_valid_cell() -> Dictionary:
	var floor_cells: Array = [Vector2i(5, 0)]
	var occupied_cells: Array = [Vector2i(0, 0)]
	# (6,0) is adjacent to (5,0), not in floor, not occupied,
	# and Chebyshev distance from (0,0) = 6 — well outside exclusion zone
	var result := SanctumLayoutService.check_placement_validity_from_data(
		Vector2i(6, 0), floor_cells, occupied_cells)
	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected valid for (6,0), got invalid: %s" % result.get("reason", "") }
	if str(result.get("reason", "")) != "":
		return { "ok": false, "error": "expected empty reason for valid cell, got: %s" % result.get("reason", "") }
	return { "ok": true }


# --- get_bridge_preview_from_floor tests ---

# 14. Target 3 tiles away in x returns a full connecting path
static func _t_bridge_preview_returns_cells() -> Dictionary:
	var floor_cells: Array = [Vector2i(0, 0)]
	# target at (3,0): nearest floor = (0,0), dist = 3.
	# Full path: (1,0) → (2,0) → stop before target (3,0).
	var bridge: Array = SanctumLayoutService.get_bridge_preview_from_floor(
		Vector2i(3, 0), floor_cells)
	if bridge.is_empty():
		return { "ok": false, "error": "expected bridge cells for target (3,0), got empty" }
	if not bridge.has(Vector2i(1, 0)):
		return { "ok": false, "error": "expected (1,0) in bridge, got %s" % str(bridge) }
	if not bridge.has(Vector2i(2, 0)):
		return { "ok": false, "error": "expected (2,0) in bridge, got %s" % str(bridge) }
	return { "ok": true }


# 15. Target already adjacent to floor returns empty bridge
static func _t_bridge_preview_adjacent_is_empty() -> Dictionary:
	var floor_cells: Array = [Vector2i(0, 0)]
	# (1,1) is diagonally adjacent to (0,0) — manhattan distance 2 but Chebyshev 1
	# _bridge_cells uses manhattan (abs(dx)+abs(dy)) for nearest, then returns [] if dist<=1
	# Actually _bridge_cells checks abs(dx)+abs(dy): abs(1)+abs(1)=2, so best_dist=2>1
	# Step x: cx=1, step=(1,0). Not in floor. bridge=[(1,0)]
	# Step y: cy=1, step=(1,1). Not in floor. bridge=[(1,0),(1,1)]
	# So (1,1) returns 2 bridge cells. Use (0,1) instead:
	# (0,1): abs(0)+abs(1)=1 → best_dist=1 ≤ 1 → return []
	var bridge: Array = SanctumLayoutService.get_bridge_preview_from_floor(
		Vector2i(0, 1), floor_cells)
	if not bridge.is_empty():
		return { "ok": false, "error": "expected empty bridge for adjacent target (0,1), got %s" % str(bridge) }
	return { "ok": true }
