extends RefCounted
class_name SanctumLayoutTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.layout/ase_flame_always_in_layout",        Callable(SanctumLayoutTests, "_t_ase_flame_in_layout"))
	runner.register_test("sanctum.layout/ase_flame_always_in_occupants",      Callable(SanctumLayoutTests, "_t_ase_flame_in_occupants"))
	runner.register_test("sanctum.layout/institution_tile_after_establish",   Callable(SanctumLayoutTests, "_t_institution_tile_after_establish"))
	runner.register_test("sanctum.layout/all_echoes_placed_as_occupants",     Callable(SanctumLayoutTests, "_t_all_echoes_placed"))
	runner.register_test("sanctum.layout/echo_occupant_has_morale_tier",      Callable(SanctumLayoutTests, "_t_echo_has_morale_tier"))
	runner.register_test("sanctum.layout/echo_near_placed_institution",       Callable(SanctumLayoutTests, "_t_echo_near_institution"))
	runner.register_test("sanctum.layout/valid_cells_exclude_occupied",       Callable(SanctumLayoutTests, "_t_valid_cells_exclude_occupied"))
	runner.register_test("sanctum.layout/valid_cells_adjacent_to_floor",      Callable(SanctumLayoutTests, "_t_valid_cells_adjacent_to_floor"))


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
static func _t_ase_flame_in_layout(_ctx: Dictionary) -> Dictionary:
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
static func _t_ase_flame_in_occupants(_ctx: Dictionary) -> Dictionary:
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
static func _t_institution_tile_after_establish(_ctx: Dictionary) -> Dictionary:
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
static func _t_all_echoes_placed(_ctx: Dictionary) -> Dictionary:
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


# 5. Each echo occupant has morale_tier string
static func _t_echo_has_morale_tier(_ctx: Dictionary) -> Dictionary:
	var roster := [_make_echo("e1", 80)]  # 80 morale = inspired
	var save := _make_save(roster)
	var occupants := SanctumLayoutService.snapshot_occupants(save, roster, [])
	for occ_v in occupants:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("kind", "")) == "echo" and str(occ.get("id", "")) == "e1":
			var tier := str(occ.get("morale_tier", ""))
			if tier.is_empty():
				return { "ok": false, "error": "morale_tier missing for e1" }
			return { "ok": true }
	return { "ok": false, "error": "echo e1 not found in occupants" }


# 6. Echo assigned to institution appears adjacent to its tile
static func _t_echo_near_institution(_ctx: Dictionary) -> Dictionary:
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
			var dist := max(abs(ex - 3), abs(ey - 0))
			if dist <= 2:
				return { "ok": true }
			return { "ok": false, "error": "echo e1 at (%d,%d) is not near hearth at (3,0)" % [ex, ey] }
	return { "ok": false, "error": "echo e1 not found" }


# 7. Valid placement cells don't include occupied positions (Ase Flame at 0,0)
static func _t_valid_cells_exclude_occupied(_ctx: Dictionary) -> Dictionary:
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


# 8. All valid placement cells are adjacent (8-dir) to an existing floor tile
static func _t_valid_cells_adjacent_to_floor(_ctx: Dictionary) -> Dictionary:
	var save := _make_save()
	var layout := SanctumLayoutService.snapshot_layout(save)
	var tiles: Array = layout.get("tiles", [])
	var floor_cells: Dictionary = {}
	for tile_v in tiles:
		if tile_v is Dictionary:
			var tile: Dictionary = tile_v
			if str(tile.get("kind", "")) == "floor":
				floor_cells[Vector2i(int(tile.get("x",0)), int(tile.get("y",0)))] = true

	var dirs := [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1, 0),                 Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]

	var cells: Array = SanctumLayoutService.compute_valid_placement_cells(save)
	for cell_v in cells:
		if not (cell_v is Vector2i):
			continue
		var cell: Vector2i = cell_v
		var adjacent := false
		for d in dirs:
			if floor_cells.has(cell + d):
				adjacent = true
				break
		if not adjacent:
			return { "ok": false, "error": "valid cell (%d,%d) has no adjacent floor tile" % [cell.x, cell.y] }
	return { "ok": true }
