extends Node2D
class_name SanctumSpatialRenderer

@onready var floor: TileMapLayer          = $Floor
@onready var occupants: SanctumOccupantLayer    = $Occupants
@onready var _building_layer: SanctumBuildingLayer  = $SanctumBuildingLayer
@onready var _placement_layer: SanctumPlacementLayer = $SanctumPlacementLayer

var _occupant_cache: Array = []

func render(snap: Dictionary) -> void:
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	_render_layout(data.get("sanctum_layout", {}))
	_render_occupants(data.get("sanctum_occupants", []))


func _render_layout(layout_v: Variant) -> void:
	if floor == null:
		return
	floor.clear()

	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	var tiles_v: Variant = layout.get("tiles", [])
	var tiles: Array = tiles_v if tiles_v is Array else []
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		var kind := str(tile.get("kind", "floor"))
		# Only floor tiles go into the TileMapLayer; other kinds are drawn by layer scripts.
		if kind == "floor":
			floor.set_cell(cell, 0, Vector2i(0, 0), 0)


func _render_occupants(occupants_v: Variant) -> void:
	if floor == null:
		return
	var source: Array = occupants_v if occupants_v is Array else []

	var buildings: Array = []
	var echoes: Array    = []
	var all_with_positions: Array = []

	for occupant_v in source:
		if not (occupant_v is Dictionary):
			continue
		var occupant: Dictionary = (occupant_v as Dictionary).duplicate(true)
		var cell := Vector2i(int(occupant.get("x", 0)), int(occupant.get("y", 0)))
		occupant["position"] = floor.position + floor.map_to_local(cell)
		all_with_positions.append(occupant)
		var kind := str(occupant.get("kind", "echo"))
		if kind in ["ase_flame", "institution"]:
			buildings.append(occupant)
		else:
			echoes.append(occupant)

	# Cache the position-enriched copies so hit detection works correctly.
	_occupant_cache = all_with_positions

	if _building_layer != null:
		_building_layer.set_buildings(buildings)
	if occupants != null:
		occupants.set_occupants(echoes)


# --- Placement mode API ---

func set_valid_placement_cells(_tile_cells: Array) -> void:
	if _placement_layer == null or floor == null:
		return
	# Initialise the grid overlay from the current floor state.
	# Valid-cell-only highlights have been replaced by any-cell-tap with validity tinting,
	# so we only need the grid — not individual valid cell positions.
	var floor_pixels := get_floor_pixel_cells()
	var ts := Vector2(72.0, 36.0)
	if floor.tile_set != null:
		ts = Vector2(floor.tile_set.tile_size)
	_placement_layer.visible = true
	_placement_layer.set_grid(floor_pixels, ts)


func set_ghost_building(tile_cell: Vector2i, inst_id: String, is_valid: bool = true, bridge_cells: Array = []) -> void:
	if _placement_layer == null or floor == null:
		return
	var pixel_pos := floor.position + floor.map_to_local(tile_cell)
	var bridge_pixels: Array = []
	for bc_v in bridge_cells:
		if bc_v is Vector2i:
			bridge_pixels.append(floor.position + floor.map_to_local(bc_v as Vector2i))
	_placement_layer.set_ghost(pixel_pos, inst_id, is_valid, bridge_pixels)


# Returns the tile cell at the given viewport point, with NO validity filter.
# Returns Vector2i(-999, -999) if the floor node is unavailable.
# Uses the viewport canvas transform (which incorporates Camera2D zoom + position)
# to correctly map screen coordinates to world space at any zoom level.
func cell_at_viewport_point(vp_point: Vector2) -> Vector2i:
	if floor == null:
		return Vector2i(-999, -999)
	# Step 1: screen → world (accounts for Camera2D zoom and pan)
	var world_pt := get_viewport().get_canvas_transform().affine_inverse() * vp_point
	# Step 2: world → SanctumSpatialRenderer local space
	var local_pt := get_global_transform().affine_inverse() * world_pt
	# Step 3: renderer-local → TileMapLayer cell
	var map_pt := local_pt - floor.position
	return floor.local_to_map(map_pt)


# Returns pixel positions for every cell currently painted in the floor TileMapLayer.
func get_floor_pixel_cells() -> Array:
	if floor == null:
		return []
	var result: Array = []
	for cell in floor.get_used_cells():
		result.append(floor.position + floor.map_to_local(cell))
	return result


func clear_placement_mode() -> void:
	if _placement_layer != null:
		_placement_layer.clear()
		_placement_layer.visible = false


# Kept for backward compatibility — superseded by cell_at_viewport_point().
# Always returns sentinel; _valid_positions no longer exists in SanctumPlacementLayer.
func find_valid_cell_at_viewport_point(_vp_point: Vector2, _radius: float = 42.0) -> Vector2i:
	return Vector2i(-999, -999)


# --- Existing helpers (unchanged) ---

func get_primary_occupant_id() -> String:
	if _occupant_cache.is_empty():
		return ""
	var first_v: Variant = _occupant_cache[0]
	if not (first_v is Dictionary):
		return ""
	return str((first_v as Dictionary).get("id", ""))


func get_primary_occupant_position() -> Vector2:
	if _occupant_cache.is_empty():
		return Vector2.ZERO
	var first_v: Variant = _occupant_cache[0]
	if not (first_v is Dictionary):
		return Vector2.ZERO
	var pos_v: Variant = (first_v as Dictionary).get("position", Vector2.ZERO)
	return pos_v if pos_v is Vector2 else Vector2.ZERO


func get_primary_occupant_screen_position() -> Vector2:
	return _screen_position_for_local(get_primary_occupant_position())


func find_occupant_at_global_point(global_point: Vector2, radius: float = 28.0) -> Dictionary:
	var local_point := to_local(global_point)
	for occupant_v in _occupant_cache:
		if not (occupant_v is Dictionary):
			continue
		var occupant: Dictionary = occupant_v
		var pos_v: Variant = occupant.get("position", Vector2.ZERO)
		var pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
		if pos.distance_to(local_point) <= radius:
			return occupant
	return {}


func find_occupant_at_viewport_point(viewport_point: Vector2, radius: float = 42.0) -> Dictionary:
	for occupant_v in _occupant_cache:
		if not (occupant_v is Dictionary):
			continue
		var occupant: Dictionary = occupant_v
		var pos_v: Variant = occupant.get("position", Vector2.ZERO)
		var pos: Vector2 = pos_v if pos_v is Vector2 else Vector2.ZERO
		var screen_pos := _screen_position_for_local(pos)
		if screen_pos.distance_to(viewport_point) <= radius:
			return occupant
	return {}


func set_featured_occupant(occupant_id: String) -> void:
	if occupants == null:
		return
	occupants.set_featured_occupant(occupant_id)


func _screen_position_for_local(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position


# Kept for backward compatibility (was named differently in some call sites).
func _screen_position_for_occupant(local_position: Vector2) -> Vector2:
	return _screen_position_for_local(local_position)
