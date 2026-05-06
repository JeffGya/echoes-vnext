extends Control

class_name InvocationScreen

signal action_requested(action: Dictionary)

@onready var _hint: Label = %HintLabel

var _action: Dictionary = {}
var _pending_snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _pending_snapshot.is_empty():
		_apply_snapshot(_pending_snapshot)
		_pending_snapshot = {}


func set_snapshot(snap: Dictionary) -> void:
	if not is_node_ready():
		_pending_snapshot = snap.duplicate(true)
		return
	_apply_snapshot(snap)


func _apply_snapshot(snap: Dictionary) -> void:
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var action_v: Variant = actions.get("cta.continue", {})
	_action = action_v if action_v is Dictionary else {}
	_hint.text = "CLICK ANYWHERE OR PRESS ANY BUTTON"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_emit_continue()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_emit_continue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_emit_continue()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_emit_continue()


func _emit_continue() -> void:
	if not _action.is_empty():
		action_requested.emit(_action)
