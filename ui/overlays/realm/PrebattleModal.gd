class_name PrebattleModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _objective: Label = %ObjectiveLabel
@onready var _intro: Label = %IntroLineLabel
@onready var _retreat_button: Button = %RetreatButton
@onready var _enter_button: Button = %EnterCombatButton
@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _carried: CarriedHomePanel = %CarriedPanel
@onready var _retreat_note: Label = %RetreatNoteLabel

const Strings := preload("res://ui/components/CarriedHomePresentation.gd")

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
	# After a refused retreat the price and the balance come from data.retreat_denied.
	var denied_v: Variant = payload.get("retreat_denied", {})
	var denied: Dictionary = denied_v if denied_v is Dictionary else {}
	_retreat_note.text = Strings.retreat_denied_line(int(denied.get("ase_cost", 0)), int(denied.get("ase_balance", 0))) \
		if not denied.is_empty() else ""
	_retreat_note.visible = not denied.is_empty()
	# The retreat decision: what a successful retreat would carry home, with the party beside it.
	var carry_v: Variant = payload.get("carry", {})
	var party_v: Variant = payload.get("party", [])
	_carried.present(carry_v if carry_v is Dictionary else {}, party_v if party_v is Array else [])

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
