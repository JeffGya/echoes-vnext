class_name CallingOptionCard
extends PanelContainer

signal selected(calling_id: String)

@export var selected_modulate: Color = Color(1.0, 0.85, 0.4)
@export var unselected_modulate: Color = Color(1, 1, 1)

@onready var calling_name_label: Label = %CallingNameLabel
@onready var compatibility_badge_label: Label = %CompatibilityBadgeLabel
@onready var description_label: Label = %DescriptionLabel
@onready var select_button: Button = %SelectButton

var _calling_id: String = ""


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)


func configure(calling_id: String, display_name: String, description: String, badge_text: String) -> void:
	_calling_id = calling_id
	calling_name_label.text = display_name
	description_label.text = description
	description_label.visible = not description.is_empty()
	compatibility_badge_label.text = badge_text
	compatibility_badge_label.visible = not badge_text.is_empty()
	set_selected(false)


func set_selected(is_selected: bool) -> void:
	modulate = selected_modulate if is_selected else unselected_modulate


func get_calling_id() -> String:
	return _calling_id


func _on_select_pressed() -> void:
	selected.emit(_calling_id)
