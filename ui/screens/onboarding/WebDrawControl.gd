extends Control

class_name WebDrawControl

@export var web_color: Color = Color("#F5E6D3", 0.42)
@export var glow_color: Color = Color("#D4AF37", 0.55)
@export var center_glow: bool = true

var _phase := 0.0


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var rings := 5
	var spokes := 14
	for r in range(1, rings + 1):
		var points := PackedVector2Array()
		var rr := radius * float(r) / float(rings)
		for s in range(spokes + 1):
			var a := TAU * float(s) / float(spokes)
			var wobble := sin(_phase + float(r + s) * 0.7) * 4.0
			points.append(center + Vector2(cos(a), sin(a)) * (rr + wobble))
		draw_polyline(points, web_color, 1.2, true)
	for s in range(spokes):
		var a2 := TAU * float(s) / float(spokes)
		var dir := Vector2(cos(a2), sin(a2))
		draw_line(center, center + dir * radius, web_color, 1.0, true)
	if center_glow:
		for i in range(7, 0, -1):
			var t := float(i) / 7.0
			var pulse := 1.0 + sin(_phase * 2.0) * 0.08
			draw_circle(center, 70.0 * t * pulse, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * (1.0 - t) * 0.7))
