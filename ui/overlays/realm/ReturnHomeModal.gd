class_name ReturnHomeModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: Label = %BodyLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _safe_frame: MarginContainer = %SafeFrame

var _action: Dictionary = {}

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)

func present(payload: Dictionary) -> void:
	_apply_layout(payload)
	var result: Dictionary = payload.get("result", {})
	var success := bool(result.get("success", false))
	_title.text = "Return Home"
	_subtitle.text = "Escaped" if success else "Blocked"
	_body.text = str(result.get("message", ""))
	_continue_button.text = "Leave" if success else "Continue"
	_action = { "type": "stage.confirm_return_home" } if success else { "type": "stage.dismiss_overlay" }

func _on_continue_pressed() -> void:
	if _action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(_action)

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
