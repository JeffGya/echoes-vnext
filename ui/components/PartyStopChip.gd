class_name PartyStopChip
extends PanelContainer
## The stop glyph for a stop that names no Echo. A tap opens the why card.

signal pressed

@onready var _glyph: TextureRect = %ChipGlyph

var _pointer := BoardPointerTracker.new()
var _motion: StopMarkMotion
var _pending_tex: Texture2D
var _glyph_pressed := false
## The snapshot's presentation timings, set by RealmShell. Read for the press feedback.
var presentation: Dictionary = {}


func _ready() -> void:
	_pointer.space_held_fn = func() -> bool: return false
	_pointer.tap.connect(func(pos: Vector2) -> void:
		if Rect2(Vector2.ZERO, size).has_point(pos):
			pressed.emit())
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_release)
	_motion = StopMarkMotion.new(self, self)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows the glyph for `kind`; "" or an unknown kind hides the chip.
func set_stop_glyph(kind: String, accessible_name: String = "") -> void:
	_motion.stop()
	_pending_tex = null
	_glyph_pressed = false
	var tex := StopGlyphs.texture(kind)
	_glyph.texture = tex
	visible = tex != null
	modulate = Color.WHITE
	accessibility_name = accessible_name


## Same holder, new mark: the old shape fades out, the new one is swapped in unseen and settles at its beat.
func swap_stop_glyph_after_fade(kind: String, accessible_name: String, seconds: float) -> void:
	_pending_tex = StopGlyphs.texture(kind)
	accessibility_name = accessible_name
	_motion.fade_out(seconds, _apply_pending_glyph)


func _apply_pending_glyph() -> void:
	if _pending_tex != null:
		_glyph.texture = _pending_tex
		_pending_tex = null
	modulate.a = 0.0


## The old mark while the next Advance computes.
func dim_stop_glyph() -> void:
	_motion.stop()
	modulate.a = 0.5


func hide_stop_glyph_for_beat() -> void:
	if _pending_tex == null:
		_motion.hide_for_beat()


func settle_stop_glyph(p: Dictionary) -> void:
	_apply_pending_glyph()
	_motion.settle(p, false)


func fade_out_stop_glyph(seconds: float) -> void:
	_motion.fade_out(seconds, set_stop_glyph.bind("", ""))


func stop_motion() -> void:
	_motion.stop()


func _release() -> void:
	if _glyph_pressed:
		_glyph_pressed = false
		_motion.press(false, presentation)


func _on_gui_input(event: InputEvent) -> void:
	var down := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if down and visible and modulate.a > 0.01 and not _glyph_pressed:
		_glyph_pressed = true
		_motion.press(true, presentation)
	elif not down and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag):
		_release()
	if has_focus() and event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()
		return
	_pointer.handle_event(event)


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), StopGlyphs.FOCUS_RING, false, 3.0)
