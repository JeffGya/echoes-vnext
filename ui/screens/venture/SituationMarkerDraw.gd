# res://ui/screens/venture/SituationMarkerDraw.gd
# Node2D that draws a small situation marker on the exploration map via _draw().
# Shape varies by situation type so the player can distinguish encounter kinds at a glance.
# Color varies by state: grey unknown, blue revealed, gold resolved-objective, grey resolved.
# Lives as a child of SituationLayer whose position tracks the board — marker.position
# is therefore in board-local pixels and moves correctly during the travel tween.

class_name SituationMarkerDraw
extends Node2D

const _RADIUS    := 14.0
const _FONT_SIZE := 11

var sit_type:    String = ""
var is_hidden:   bool   = true
var is_resolved: bool   = false
var is_objective: bool  = false


func setup(p_type: String, p_hidden: bool, p_resolved: bool, p_objective: bool) -> void:
	sit_type     = p_type
	is_hidden    = p_hidden
	is_resolved  = p_resolved
	is_objective = p_objective
	queue_redraw()


func _draw() -> void:
	if is_hidden:
		_draw_circle_shape(Color(0.35, 0.35, 0.45, 0.90), Color(0.50, 0.50, 0.60, 0.50))
		_draw_text("?")
		return

	if is_resolved:
		# Completed objective → Akan Gold; completed encounter → muted grey.
		var col := Color("#C8A96E") if is_objective else Color(0.40, 0.40, 0.40, 0.65)
		_draw_shape(col, col.darkened(0.30))
		_draw_text("✓")
	else:
		# Revealed but not yet resolved — blue fill.
		# Objectives get a gold outer ring so the player can spot required goals on the map.
		_draw_shape(Color(0.25, 0.55, 0.85, 0.90), Color(0.15, 0.35, 0.65, 0.80))
		if is_objective:
			_draw_objective_ring()


func _draw_shape(fill: Color, border: Color) -> void:
	match sit_type:
		"combat":
			_draw_square_shape(fill, border)
		"shrine":
			_draw_triangle_shape(fill, border)
		"loot", "money":
			_draw_diamond_shape(fill, border)
		_:
			# npc, recover, protect, endure, pursue, unknown
			_draw_circle_shape(fill, border)


func _draw_circle_shape(fill: Color, border: Color) -> void:
	draw_circle(Vector2.ZERO, _RADIUS, fill)
	draw_arc(Vector2.ZERO, _RADIUS, 0.0, TAU, 32, border, 1.5, true)


func _draw_square_shape(fill: Color, border: Color) -> void:
	var r    := _RADIUS * 0.82
	var rect := Rect2(-r, -r, r * 2.0, r * 2.0)
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1.5)


func _draw_triangle_shape(fill: Color, border: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(0.0,             -_RADIUS),
		Vector2( _RADIUS * 0.90,  _RADIUS * 0.72),
		Vector2(-_RADIUS * 0.90,  _RADIUS * 0.72),
	])
	draw_polygon(pts, PackedColorArray([fill, fill, fill]))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), border, 1.5)


func _draw_diamond_shape(fill: Color, border: Color) -> void:
	var pts := PackedVector2Array([
		Vector2( 0.0,              -_RADIUS),
		Vector2( _RADIUS * 0.75,   0.0),
		Vector2( 0.0,               _RADIUS),
		Vector2(-_RADIUS * 0.75,   0.0),
	])
	draw_polygon(pts, PackedColorArray([fill, fill, fill, fill]))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), border, 1.5)


func _draw_objective_ring() -> void:
	# Gold outer ring drawn just outside the shape to mark revealed required objectives.
	draw_arc(Vector2.ZERO, _RADIUS + 3.5, 0.0, TAU, 32, Color("#C8A96E"), 2.0, true)


func _draw_text(text: String) -> void:
	var font := ThemeDB.fallback_font
	var w    := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
	draw_string(font, Vector2(-w * 0.5, _FONT_SIZE * 0.38),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, Color.WHITE)
