extends Node2D
class_name SanctumSpatialRenderer

@onready var floor: TileMapLayer = $Floor
@onready var floor2: TileMapLayer = $Floor2
@onready var occupants: SanctumOccupantLayer = $Occupants

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
	if floor2 != null:
		floor2.clear()

	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	var tiles_v: Variant = layout.get("tiles", [])
	var tiles: Array = tiles_v if tiles_v is Array else []
	for tile_v in tiles:
		if not (tile_v is Dictionary):
			continue
		var tile: Dictionary = tile_v
		var cell := Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0)))
		floor.set_cell(cell, 0, Vector2i(0, 0), 0)


func _render_occupants(occupants_v: Variant) -> void:
	if occupants == null or floor == null:
		return
	var source: Array = occupants_v if occupants_v is Array else []
	var out: Array = []
	for occupant_v in source:
		if not (occupant_v is Dictionary):
			continue
		var occupant: Dictionary = (occupant_v as Dictionary).duplicate(true)
		var cell := Vector2i(int(occupant.get("x", 0)), int(occupant.get("y", 0)))
		occupant["position"] = floor.position + floor.map_to_local(cell)
		out.append(occupant)
	_occupant_cache = out
	occupants.set_occupants(out)


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
	return _screen_position_for_occupant(get_primary_occupant_position())


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
		var screen_pos := _screen_position_for_occupant(pos)
		if screen_pos.distance_to(viewport_point) <= radius:
			return occupant
	return {}


func set_featured_occupant(occupant_id: String) -> void:
	if occupants == null:
		return
	occupants.set_featured_occupant(occupant_id)


func _screen_position_for_occupant(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position
