class_name SituationModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: Label = %BodyLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _safe_frame: MarginContainer = %SafeFrame

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)

func present(payload: Dictionary) -> void:
	_apply_layout(payload)
	var result: Dictionary = payload.get("result", {})
	_title.text = "Situation"
	_subtitle.text = str(result.get("type", "")).capitalize()
	_body.text = str(result.get("result_text", ""))

func _on_continue_pressed() -> void:
	dismiss_requested.emit()
	action_requested.emit({ "type": "stage.dismiss_overlay" })

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
