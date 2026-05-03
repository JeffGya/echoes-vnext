# res://ui/screens/combat/BarkTail.gd
# V2-VOICE-002: Speech bubble tail — a downward-pointing triangle drawn via _draw().
# Visual structure (size, color) is authored in BarkPopupLayer.tscn.
# This script only executes the draw call; no nodes are created here.
class_name BarkTail
extends Control

@export var color: Color = Color(0.239, 0.353, 0.278, 0.85)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(w,   0.0),
		Vector2(w * 0.5, h),
	]), color)
