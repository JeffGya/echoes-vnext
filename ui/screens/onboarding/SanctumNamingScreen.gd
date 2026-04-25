extends Control

class_name SanctumNamingScreen

signal action_requested(action: Dictionary)

@onready var _cards_root: HBoxContainer = %CardsRoot
@onready var _custom_root: VBoxContainer = %CustomRoot
@onready var _glow: ColorRect = %Glow
@onready var _name_buttons: Array[Button] = [%NameButton1, %NameButton2, %NameButton3]
@onready var _name_labels: Array[Label] = [%NameLabel1, %NameLabel2, %NameLabel3]
@onready var _custom_option: Button = %CustomOptionButton
@onready var _custom_edit: LineEdit = %CustomNameEdit
@onready var _custom_submit: Button = %CustomSubmitButton

var _options: Array = []
var _confirm_action: Dictionary = {}


func _ready() -> void:
	for i in range(_name_buttons.size()):
		_name_buttons[i].pressed.connect(_on_name_pressed.bind(i))
	_custom_option.pressed.connect(_on_custom_option_pressed)
	_custom_submit.pressed.connect(_on_custom_submit_pressed)
	_glow.visible = false
	_custom_root.visible = false


func set_snapshot(snap: Dictionary) -> void:
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_v: Variant = actions.get("cta.confirm", {})
	_confirm_action = action_v if action_v is Dictionary else {}
	var options_v: Variant = data.get("name_options", [])
	_options = options_v if options_v is Array else []
	for i in range(3):
		var has_option := i < _options.size() and _options[i] is Dictionary
		_name_buttons[i].disabled = not has_option
		_name_labels[i].text = str((_options[i] as Dictionary).get("name", "Sanctum")) if has_option else "Sanctum"
		_name_buttons[i].text = "Choose"
	_cards_root.visible = true
	_custom_root.visible = false
	_glow.visible = false


func _on_name_pressed(index: int) -> void:
	if index >= _options.size() or not (_options[index] is Dictionary):
		return
	var option: Dictionary = _options[index]
	_confirm_name(str(option.get("name", "Sanctum")))


func _on_custom_option_pressed() -> void:
	_cards_root.visible = false
	_custom_root.visible = true
	_custom_edit.grab_focus()


func _on_custom_submit_pressed() -> void:
	_confirm_name(_custom_edit.text)


func _confirm_name(name: String) -> void:
	if _confirm_action.is_empty():
		return
	var action := _confirm_action.duplicate(true)
	action["name"] = name
	_glow.visible = true
	_glow.modulate = Color(0.15, 0.45, 0.25, 0.0)
	var tween := create_tween()
	tween.tween_property(_glow, "modulate", Color(0.82, 0.68, 0.22, 0.82), 0.35)
	tween.tween_interval(0.15)
	tween.tween_callback(func(): action_requested.emit(action))
