extends HBoxContainer

@onready var _name_label: Label = %NameLabel
@onready var _action_label: Label = %ActionLabel


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
