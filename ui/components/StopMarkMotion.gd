class_name StopMarkMotion
extends RefCounted
## Motion for one stop mark (a glyph on an Echo card, or a card). Presentation only.
## `target` is the control that appears, settles and is pressed; `host` also dims on a press.
## `reduced` is the one reduced-motion flag. A settings story will set it; nothing sets it today.

static var reduced := false

var _target: Control
var _host: Control
var _settle: Tween
var _press: Tween
var _fade: Tween


static func pres(p: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = p.get(key, fallback)
	return float(v) if v is int or v is float else fallback


## How long the mark takes to appear. The screen builds the timeline from this, the mark plays it.
static func settle_seconds(p: Dictionary, named: bool) -> float:
	if reduced:
		return pres(p, "reduced_motion_fade_seconds", 0.15)
	return pres(p, "glyph_settle_seconds" if named else "chip_settle_seconds", 0.25)


func _init(target: Control, host: Control) -> void:
	_target = target
	_host = host


func hide_for_beat() -> void:
	stop()
	_target.modulate.a = 0.0
	_target.scale = Vector2.ONE


func settle(p: Dictionary, named: bool) -> void:
	stop()
	_target.pivot_offset = _target.size * 0.5
	_target.modulate.a = 0.0
	var seconds := settle_seconds(p, named)
	_settle = _target.create_tween().set_parallel(true)
	if reduced:
		_settle.tween_property(_target, "modulate:a", 1.0, seconds)
		return
	var over := pres(p, "glyph_settle_overshoot_scale", 1.1)
	_target.scale = Vector2.ONE * pres(p, "glyph_settle_from_scale", 0.95)
	_settle.tween_property(_target, "modulate:a", 1.0, seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settle.tween_property(_target, "scale", Vector2.ONE * over, seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settle.chain().tween_property(_target, "scale", Vector2.ONE, seconds * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Fades the old mark out while the next walk runs, then calls `done`.
func fade_out(seconds: float, done: Callable) -> void:
	if _fade != null and _fade.is_valid():
		return
	_fade = _target.create_tween()
	_fade.tween_property(_target, "modulate:a", 0.0, seconds)
	_fade.tween_callback(done)


## Touch feedback: scale 0.95 and brightness 0.85, back on release. A press ends a running settle.
func press(down: bool, p: Dictionary) -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
		_target.modulate.a = 1.0
		_target.scale = Vector2.ONE
	if _press != null and _press.is_valid():
		_press.kill()
	var seconds := pres(p, "glyph_press_seconds", 0.08)
	var level := 0.85 if down else 1.0
	_press = _target.create_tween().set_parallel(true)
	_press.tween_method(_set_brightness.bind(_target), _target.modulate.r, level, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _host != _target:
		_press.tween_method(_set_brightness.bind(_host), _host.modulate.r, level, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not reduced:
		_target.pivot_offset = _target.size * 0.5
		_press.tween_property(_target, "scale", Vector2.ONE * (0.95 if down else 1.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _set_brightness(level: float, node: Control) -> void:
	node.modulate = Color(level, level, level, node.modulate.a)


func stop() -> void:
	for t in [_settle, _press, _fade]:
		if t != null and t.is_valid():
			t.kill()
	_fade = null
	_target.scale = Vector2.ONE
	_target.modulate = Color(1, 1, 1, _target.modulate.a)
	if _host != _target:
		_host.modulate = Color.WHITE
