extends HBoxContainer

## Tap on the row. The combat screen locks its camera onto this actor.
signal row_pressed(actor_id: String)

@onready var _name_label: Label = %NameLabel
@onready var _action_label: Label = %ActionLabel

var _actor_id: String = ""


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func set_actor_id(actor_id: String) -> void:
	_actor_id = actor_id


# Every button and touch event is accepted, so no press or release on a row reaches the
# board-tap handler on the screen root behind it.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			row_pressed.emit(_actor_id)


func setup_row(actor_name: String, action_text: String, is_active: bool, is_dead: bool, active_action_color: Color) -> void:
	_action_label.text = action_text

	if is_dead:
		_name_label.text = "X  %s" % actor_name
		_name_label.add_theme_color_override("font_color", Color.RED)
		_action_label.add_theme_color_override("font_color", Color.RED)
		self_modulate = Color(1, 1, 1, 0.4)
		return

	self_modulate = Color(1, 1, 1, 1)
	if is_active:
		_name_label.text = "→  %s" % actor_name
		_name_label.add_theme_color_override("font_color", Color.YELLOW)
		_action_label.add_theme_color_override("font_color", active_action_color)
	else:
		_name_label.text = "   %s" % actor_name
		_name_label.add_theme_color_override("font_color", Color.WHITE)
		_action_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
