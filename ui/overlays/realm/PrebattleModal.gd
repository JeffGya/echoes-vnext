class_name PrebattleModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _objective: Label = %ObjectiveLabel
@onready var _intro: Label = %IntroLineLabel
@onready var _retreat_button: Button = %RetreatButton
@onready var _enter_button: Button = %EnterCombatButton
@onready var _safe_frame: MarginContainer = %SafeFrame

var _enter_action: Dictionary = {}
var _retreat_action: Dictionary = {}

func _ready() -> void:
	_enter_button.pressed.connect(_on_enter_pressed)
	_retreat_button.pressed.connect(_on_retreat_pressed)

func present(payload: Dictionary) -> void:
	_apply_layout(payload)
	_objective.text = str(payload.get("objective_label", ""))
	var intro_line := str(payload.get("intro_line", ""))
	_intro.text = intro_line
	_intro.visible = not intro_line.is_empty()
	_enter_action = payload.get("enter_action", {}).duplicate(true)
	_retreat_action = payload.get("retreat_action", {}).duplicate(true)
	_enter_button.disabled = _enter_action.is_empty()
	_retreat_button.disabled = not bool(payload.get("retreat_enabled", false))
	_retreat_button.text = str(payload.get("retreat_label", "Retreat is not possible"))

func _on_enter_pressed() -> void:
	if _enter_action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(_enter_action)

func _on_retreat_pressed() -> void:
	if _retreat_action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(_retreat_action)

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
