extends Control

## Fill meters of the two panels, drawn. "ledger" (Sanctum): one thin bar per slot, ink fill for used slots, an
## ink frame near full, gold fill with an ink keyline at full. `pulse()` plays the one transition-into-full beat
## (0.4 s, reduced motion 0.15 s fade). Presentation only.

const _PULSE_SCALE := 1.15

var total := 0:
	set(v):
		total = v
		queue_redraw()
var used := 0:
	set(v):
		used = v
		queue_redraw()
## "", "near" or "full".
var level := "":
	set(v):
		level = v
		queue_redraw()
var _pulse_t := 0.0
var _tween: Tween = null


func _color(name: String) -> Color:
	return get_theme_color(name, "ItemGlyphs")


func pulse(seconds: float, reduced: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	if reduced:
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, seconds)
		return
	_tween.tween_method(_set_pulse, 0.0, 1.0, seconds * 0.5)
	_tween.tween_method(_set_pulse, 1.0, 0.0, seconds * 0.5)


func _set_pulse(t: float) -> void:
	_pulse_t = t
	queue_redraw()


func _draw() -> void:
	_draw_ledger()


func _draw_ledger() -> void:
	if total <= 0:
		return
	var ink := _color("ink")
	var gold := _color("gold")
	var frame := Rect2(Vector2.ZERO, size)
	if level == "full":
		draw_rect(frame, gold)
		draw_rect(frame, ink, false, 3.0)
	elif level == "near":
		draw_rect(frame.grow(-1.0), ink, false, 2.0)
	var inner := frame.grow(-4.0)
	var gap := 2.0
	var w := (inner.size.x - gap * float(total - 1)) / float(total)
	for i in total:
		var r := Rect2(inner.position.x + float(i) * (w + gap), inner.position.y, w, inner.size.y)
		if i == total - 1 and _pulse_t > 0.0:
			var k := 1.0 + (_PULSE_SCALE - 1.0) * _pulse_t
			r = Rect2(r.get_center() - r.size * k * 0.5, r.size * k)
		if i < used:
			draw_rect(r, ink)
		else:
			draw_rect(r, ink, false, 1.5)
