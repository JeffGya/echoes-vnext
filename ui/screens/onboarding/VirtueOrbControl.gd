extends Control

class_name VirtueOrbControl

@export var orb_color: Color = Color("#D4AF37")
@export var selected: bool = false

var _phase := 0.0


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.27
	var pulse := 1.0
	if selected:
		pulse = 1.0 + sin(_phase * 5.0) * 0.12
	for i in range(8, 0, -1):
		var t := float(i) / 8.0
		var alpha := (0.08 if not selected else 0.16) * (1.0 - t)
		draw_circle(center, radius * (1.0 + t * 1.8) * pulse, Color(orb_color.r, orb_color.g, orb_color.b, alpha))
	draw_circle(center, radius * pulse, Color(orb_color.r, orb_color.g, orb_color.b, 0.58))
	draw_circle(center, radius * 0.52 * pulse, Color(1.0, 0.96, 0.82, 0.72))
	if selected:
		draw_arc(center, radius * 1.35 * pulse, 0.0, TAU, 64, Color("#F5E6D3"), 2.0, true)
