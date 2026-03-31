class_name CombatMoveTelegraphLayer
extends Node2D

const CombatTokenVisualConfigScript := preload("res://ui/screens/combat/CombatTokenVisualConfig.gd")

@export var visual_config = CombatTokenVisualConfigScript.new()

var _cell_pos: Vector2 = Vector2.ZERO
var _time_left: float = 0.0


func _ready() -> void:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()


func show_move_telegraph(event: Dictionary) -> void:
	_cell_pos = event.get("cell_pos", Vector2.ZERO)
	_time_left = max(float(event.get("duration", visual_config.telegraph_lead_time)), 0.0)
	queue_redraw()


func clear_telegraph() -> void:
	_time_left = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = max(_time_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _time_left <= 0.0 or visual_config == null:
		return

	var half: Vector2 = visual_config.telegraph_half_size
	var points := PackedVector2Array([
		_cell_pos + Vector2(0.0, -half.y),
		_cell_pos + Vector2(half.x, 0.0),
		_cell_pos + Vector2(0.0, half.y),
		_cell_pos + Vector2(-half.x, 0.0),
	])
	var fill_colors := PackedColorArray([
		visual_config.telegraph_fill_color,
		visual_config.telegraph_fill_color,
		visual_config.telegraph_fill_color,
		visual_config.telegraph_fill_color,
	])

	draw_polygon(points, fill_colors)
	for i in range(points.size()):
		var next_idx: int = (i + 1) % points.size()
		draw_line(
			points[i],
			points[next_idx],
			visual_config.telegraph_outline_color,
			visual_config.telegraph_outline_width
		)
