class_name PartyStopChip
extends PanelContainer
## The stop glyph for a stop that names no Echo. A tap opens the why card.

signal pressed

@onready var _glyph: TextureRect = %ChipGlyph

var _pointer := BoardPointerTracker.new()


func _ready() -> void:
	_pointer.space_held_fn = func() -> bool: return false
	_pointer.tap.connect(func(pos: Vector2) -> void:
		if Rect2(Vector2.ZERO, size).has_point(pos):
			pressed.emit())
	gui_input.connect(_on_gui_input)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows the glyph for `kind`; "" or an unknown kind hides the chip.
func set_stop_glyph(kind: String, accessible_name: String = "") -> void:
	var tex := StopGlyphs.texture(kind)
	_glyph.texture = tex
	visible = tex != null
	modulate = Color.WHITE
	accessibility_name = accessible_name


## The old mark while the next Advance computes.
func dim_stop_glyph() -> void:
	modulate.a = 0.5


func _on_gui_input(event: InputEvent) -> void:
	if has_focus() and event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()
		return
	_pointer.handle_event(event)


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color("#F5F1E7"), false, 3.0)
