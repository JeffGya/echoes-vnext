extends Control

class_name AnansiWebScreen

signal action_requested(action: Dictionary)

const LINE := "You have been pulled here because names are trying to come home. Hold them carefully, Keeper. Not all of them want to be whole."

@onready var _line_label: Label = %LineLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _safe_frame: Control = %SafeFrame

var _action: Dictionary = {}
var _typing_tween: Tween


func _ready() -> void:
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.pressed.connect(_on_continue_pressed)

func set_layout(layout: Dictionary) -> void:
	if is_node_ready() and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)

func set_snapshot(snap: Dictionary) -> void:
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_v: Variant = actions.get("cta.continue", {})
	_action = action_v if action_v is Dictionary else {}
	_start_typewriter()


func _start_typewriter() -> void:
	if _typing_tween != null and _typing_tween.is_running():
		_typing_tween.kill()
	_line_label.text = ""
	_continue_button.visible = false
	_typing_tween = create_tween()
	for i in range(LINE.length()):
		_typing_tween.tween_callback(func(idx := i): _line_label.text = LINE.substr(0, idx + 1))
		_typing_tween.tween_interval(0.025)
	_typing_tween.tween_callback(func(): _continue_button.visible = true)
	_typing_tween.tween_callback(func(): _continue_button.grab_focus())


func _on_continue_pressed() -> void:
	if not _action.is_empty():
		action_requested.emit(_action)
