class_name PickupDebugContinue
extends HBoxContainer

## Temporary debug-only buttons so the event never dead-ends before the real Continue exists.
## Remove this node, its scene and its tests in U9. It sends the snapshot's own slot actions.

signal action_requested(action: Dictionary)

@onready var _skip_button: Button = %SkipButton
@onready var _continue_button: Button = %ContinueButton

var _skip_action: Dictionary = {}
var _continue_action: Dictionary = {}


static func is_available() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	if not is_available():
		queue_free()
		return
	_skip_button.pressed.connect(func() -> void: _send(_skip_action))
	_continue_button.pressed.connect(func() -> void: _send(_continue_action))
	apply_actions({})


func apply_actions(actions: Dictionary) -> void:
	if not is_available():
		return
	var skip_v: Variant = actions.get("overlay.skip", {})
	var continue_v: Variant = actions.get("cta.continue", {})
	_skip_action = skip_v if skip_v is Dictionary else {}
	_continue_action = continue_v if continue_v is Dictionary else {}
	_skip_button.visible = not _skip_action.is_empty()
	_continue_button.visible = not _continue_action.is_empty()
	visible = _skip_button.visible or _continue_button.visible


func _send(action: Dictionary) -> void:
	if not action.is_empty():
		action_requested.emit(action)
