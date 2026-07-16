extends Control

class_name FirstSanctumEncounterScreen

signal action_requested(action: Dictionary)

@onready var _renderer: Node2D = %SanctumSpatialRenderer
@onready var _narrator: Label = %NarratorLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _safe_frame: Control = %SafeFrame

var _action: Dictionary = {}
var _lines: Array[String] = []
var _line_index := 0
var _typing_tween: Tween


func _ready() -> void:
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.pressed.connect(_on_continue_pressed)

func set_layout(layout: Dictionary) -> void:
	if is_node_ready() and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)

func set_snapshot(snap: Dictionary) -> void:
	if _renderer != null and _renderer.has_method("render"):
		_renderer.call("render", snap)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var echo_v: Variant = data.get("starter_echo", {})
	var echo: Dictionary = echo_v if echo_v is Dictionary else {}
	var echo_name := str(echo.get("name", "The Echo"))
	_lines = [
		"%s has landed in your empty sanctum. Here your story begins." % echo_name,
		"The house is empty but no longer silent.",
		"Your house will grow around this circle. Fragments arrive and become people here.",
	]
	_line_index = 0
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_v: Variant = actions.get("cta.continue", {})
	_action = action_v if action_v is Dictionary else {}
	_show_current_line()


func _show_current_line() -> void:
	if _typing_tween != null and _typing_tween.is_running():
		_typing_tween.kill()
	_continue_button.visible = false
	_narrator.text = ""
	var line := _lines[_line_index] if _line_index < _lines.size() else ""
	_typing_tween = create_tween()
	for i in range(line.length()):
		_typing_tween.tween_callback(func(idx := i): _narrator.text = line.substr(0, idx + 1))
		_typing_tween.tween_interval(0.02)
	_typing_tween.tween_callback(func(): _continue_button.visible = true)
	_typing_tween.tween_callback(func(): _continue_button.grab_focus())


func _on_continue_pressed() -> void:
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_show_current_line()
		return
	if not _action.is_empty():
		action_requested.emit(_action)
