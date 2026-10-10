class_name CombatMoveTelegraphLayer
extends Node2D

const CombatTokenVisualConfigScript := preload("res://ui/screens/combat/CombatTokenVisualConfig.gd")

@export var visual_config = CombatTokenVisualConfigScript.new()

var _cell_pos: Vector2 = Vector2.ZERO
var _time_left: float = 0.0
var _settle_cell: Variant = null  # Vector2 while the stop-short diamond shows


func _ready() -> void:
	if visual_config == null:
		visual_config = CombatTokenVisualConfigScript.new()


func show_move_telegraph(event: Dictionary) -> void:
	_cell_pos = event.get("cell_pos", Vector2.ZERO)
	_time_left = max(float(event.get("duration", visual_config.telegraph_lead_time)), 0.0)
	_settle_cell = null
	queue_redraw()


## Cream stop marker at the settle of a performed stop-short; the next clear or move telegraph removes it.
func show_settle_diamond(cell_pos: Vector2, stop_short: Dictionary) -> void:
	if settle_diamond_wanted(stop_short, visual_config.settle_diamond_enabled):
		_settle_cell = cell_pos
		queue_redraw()


static func settle_diamond_wanted(stop_short: Dictionary, enabled: bool) -> bool:
	return enabled and bool(stop_short.get("performed", false))


func clear_telegraph() -> void:
	_time_left = 0.0
	_settle_cell = null
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = max(_time_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if visual_config == null:
		return
	if _time_left > 0.0:
		_draw_diamond(_cell_pos, visual_config.telegraph_fill_color, visual_config.telegraph_outline_color)
	if _settle_cell != null:
		var cream: Color = visual_config.stance_color
		_draw_diamond(_settle_cell, Color(cream, visual_config.telegraph_fill_color.a), cream)


func _draw_diamond(center: Vector2, fill: Color, outline: Color) -> void:
	var half: Vector2 = visual_config.telegraph_half_size
	var points := PackedVector2Array([
		center + Vector2(0.0, -half.y),
		center + Vector2(half.x, 0.0),
		center + Vector2(0.0, half.y),
		center + Vector2(-half.x, 0.0),
	])
	draw_polygon(points, PackedColorArray([fill, fill, fill, fill]))
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], outline, visual_config.telegraph_outline_width)
