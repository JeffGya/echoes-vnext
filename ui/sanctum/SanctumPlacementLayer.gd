extends Node2D

class_name SanctumPlacementLayer

# Shown only during placement mode. Hidden otherwise.
# Valid cell highlights: pulsing gold arc rings at each valid tile center.
# Ghost building: dim version of the institution rect when a cell is selected.

const COLOR_VALID_ARC  := Color(0.831, 0.686, 0.216, 0.55)  # #D4AF37 55%
const COLOR_GHOST_FILL := Color(0.102, 0.169, 0.133, 0.45)
const COLOR_GHOST_BORDER := Color(0.831, 0.686, 0.216, 0.45)

var _valid_positions: Array = []   # Array of Vector2 (pixel positions)
var _ghost_position: Vector2 = Vector2(-9999.0, -9999.0)
var _ghost_inst_id: String = ""


func set_valid_cells(pixel_positions: Array) -> void:
	_valid_positions = pixel_positions.duplicate()
	queue_redraw()


func set_ghost(pixel_pos: Vector2, inst_id: String) -> void:
	_ghost_position = pixel_pos
	_ghost_inst_id  = inst_id
	queue_redraw()


func clear() -> void:
	_valid_positions = []
	_ghost_position  = Vector2(-9999.0, -9999.0)
	_ghost_inst_id   = ""
	queue_redraw()


func _draw() -> void:
	for pos_v in _valid_positions:
		if not (pos_v is Vector2):
			continue
		var pos: Vector2 = pos_v
		draw_arc(pos + Vector2(0.0, -6.0), 22.0, 0.0, TAU, 48, COLOR_VALID_ARC, 2.5, true)

	if _ghost_position.x > -9000.0:
		_draw_ghost_building(_ghost_position)


func _draw_ghost_building(pos: Vector2) -> void:
	var rect_size := Vector2(28.0, 18.0)
	var top_left  := pos + Vector2(-rect_size.x * 0.5, -rect_size.y - 6.0)
	var rect      := Rect2(top_left, rect_size)
	draw_rect(rect, COLOR_GHOST_FILL)
	draw_rect(rect, COLOR_GHOST_BORDER, false, 2.0)
