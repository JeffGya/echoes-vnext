extends Node2D

class_name SanctumPlacementLayer

# Shown only during placement mode. Hidden otherwise.
# Draws four layers in _draw():
#   1. Isometric diamond grid overlay (Akan Gold 18%, fade-in)
#   2. Bridge tile preview (light gold rects)
#   3. Selected cell highlight ring (brighter gold)
#   4. Ghost building (valid=semi-transparent / invalid=red-tinted)

const COLOR_GHOST_FILL         := Color(0.102, 0.169, 0.133, 0.45)
const COLOR_GHOST_BORDER       := Color(0.831, 0.686, 0.216, 0.45)
const COLOR_GHOST_INVALID_FILL := Color(0.6, 0.1, 0.1, 0.45)
const COLOR_GHOST_INVALID_BORDER := Color(0.8, 0.2, 0.2, 0.55)
const COLOR_GRID_BASE          := Color(0.831, 0.686, 0.216, 1.0)  # Akan Gold — alpha multiplied by _grid_alpha
const COLOR_BRIDGE             := Color(0.831, 0.686, 0.216, 0.15)
const COLOR_HIGHLIGHT          := Color(0.831, 0.686, 0.216, 0.36)

# Grid state
var _grid_floor_cells: Array = []        # Array[Vector2] pixel positions of existing floor tiles
var _tile_size: Vector2 = Vector2(72.0, 36.0)
var _grid_alpha: float = 0.0             # 0.0 → 1.0 driven by Tween for fade-in
var _grid_tween: Tween = null

# Ghost state
var _ghost_position: Vector2 = Vector2(-9999.0, -9999.0)
var _ghost_inst_id: String = ""
var _ghost_is_valid: bool = true
var _bridge_pixel_positions: Array = []  # Array[Vector2]
var _selected_pixel_pos: Vector2 = Vector2(-9999.0, -9999.0)


func set_grid(floor_pixel_cells: Array, tile_size: Vector2) -> void:
	_grid_floor_cells = floor_pixel_cells.duplicate()
	_tile_size = tile_size

	# Kill any existing tween before starting a new fade.
	if _grid_tween != null and _grid_tween.is_valid():
		_grid_tween.kill()

	_grid_alpha = 0.0
	_grid_tween = create_tween()
	_grid_tween.tween_method(_set_grid_alpha, 0.0, 1.0, 0.2)
	queue_redraw()


func _set_grid_alpha(value: float) -> void:
	_grid_alpha = value
	queue_redraw()


func set_ghost(pixel_pos: Vector2, inst_id: String, is_valid: bool = true, bridge_pixel_positions: Array = []) -> void:
	_ghost_position = pixel_pos
	_ghost_inst_id  = inst_id
	_ghost_is_valid = is_valid
	_bridge_pixel_positions = bridge_pixel_positions.duplicate()
	_selected_pixel_pos = pixel_pos
	queue_redraw()


func clear() -> void:
	_grid_floor_cells = []
	_grid_alpha = 0.0
	if _grid_tween != null and _grid_tween.is_valid():
		_grid_tween.kill()
	_grid_tween = null

	_ghost_position       = Vector2(-9999.0, -9999.0)
	_ghost_inst_id        = ""
	_ghost_is_valid       = true
	_bridge_pixel_positions = []
	_selected_pixel_pos   = Vector2(-9999.0, -9999.0)
	queue_redraw()


func _draw() -> void:
	_draw_grid()
	_draw_bridge_preview()
	_draw_selected_highlight()
	_draw_ghost_building()


func _draw_grid() -> void:
	if _grid_floor_cells.is_empty() or _grid_alpha <= 0.0:
		return

	var half_w := _tile_size.x * 0.5
	var half_h := _tile_size.y * 0.5
	var grid_color := Color(COLOR_GRID_BASE.r, COLOR_GRID_BASE.g, COLOR_GRID_BASE.b, 0.18 * _grid_alpha)

	# Build a set of floor cell pixel positions for adjacency checks.
	# We draw grid cells only within 2 tile-widths of an existing floor tile
	# to avoid blanketing the entire screen.
	var floor_set: Dictionary = {}
	for p_v in _grid_floor_cells:
		if p_v is Vector2:
			floor_set[p_v] = true

	# Collect candidate grid positions: for each floor cell, include itself
	# and all neighbours within a 2-tile margin (in pixel space).
	var candidates: Dictionary = {}
	var offsets: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			offsets.append(Vector2(dx * _tile_size.x, dy * _tile_size.y))

	for p_v in _grid_floor_cells:
		if not (p_v is Vector2):
			continue
		var p: Vector2 = p_v
		for off in offsets:
			var candidate: Vector2 = p + off
			candidates[candidate] = true

	for pos_v in candidates:
		var pos: Vector2 = pos_v
		var pts := PackedVector2Array([
			Vector2(pos.x,          pos.y - half_h),   # top
			Vector2(pos.x + half_w, pos.y),             # right
			Vector2(pos.x,          pos.y + half_h),   # bottom
			Vector2(pos.x - half_w, pos.y),             # left
			Vector2(pos.x,          pos.y - half_h),   # close
		])
		draw_polyline(pts, grid_color, 1.0, true)


func _draw_bridge_preview() -> void:
	if _ghost_position.x <= -9000.0:
		return
	if _bridge_pixel_positions.is_empty():
		return

	var half_w := _tile_size.x * 0.5
	var half_h := _tile_size.y * 0.5
	for b_v in _bridge_pixel_positions:
		if not (b_v is Vector2):
			continue
		var pos: Vector2 = b_v
		# Draw a small filled isometric diamond at bridge positions.
		var pts := PackedVector2Array([
			Vector2(pos.x,          pos.y - half_h * 0.5),
			Vector2(pos.x + half_w * 0.5, pos.y),
			Vector2(pos.x,          pos.y + half_h * 0.5),
			Vector2(pos.x - half_w * 0.5, pos.y),
		])
		draw_colored_polygon(pts, COLOR_BRIDGE)


func _draw_selected_highlight() -> void:
	if _selected_pixel_pos.x <= -9000.0:
		return

	var pos: Vector2 = _selected_pixel_pos
	var half_w := _tile_size.x * 0.5
	var half_h := _tile_size.y * 0.5
	var pts := PackedVector2Array([
		Vector2(pos.x,          pos.y - half_h),
		Vector2(pos.x + half_w, pos.y),
		Vector2(pos.x,          pos.y + half_h),
		Vector2(pos.x - half_w, pos.y),
		Vector2(pos.x,          pos.y - half_h),
	])
	draw_polyline(pts, COLOR_HIGHLIGHT, 2.0, true)


func _draw_ghost_building() -> void:
	if _ghost_position.x <= -9000.0:
		return

	var pos: Vector2 = _ghost_position
	var rect_size := Vector2(44.0, 28.0)
	var top_left  := pos + Vector2(-rect_size.x * 0.5, -rect_size.y - 6.0)
	var rect      := Rect2(top_left, rect_size)

	if _ghost_is_valid:
		draw_rect(rect, COLOR_GHOST_FILL)
		draw_rect(rect, COLOR_GHOST_BORDER, false, 2.0)
	else:
		draw_rect(rect, COLOR_GHOST_INVALID_FILL)
		draw_rect(rect, COLOR_GHOST_INVALID_BORDER, false, 2.0)
