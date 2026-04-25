extends Node2D
class_name SanctumSpatialRenderer

@onready var floor: TileMapLayer = $Floor
@onready var floor2: TileMapLayer = $Floor2
@onready var occupants: SanctumOccupantLayer = $Occupants

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
	occupants.set_occupants(out)
