class_name ReturnHomeModal
extends Control

## Two modes. Confirm mode (payload.confirm): opens BEFORE the action, shows what the party has
## gathered (no odds), and only Confirm sends the action, once. Result mode: the failed-escape display
## (the core writes return_home_result only when the escape fails).

signal action_requested(action: Dictionary)
signal dismiss_requested

const Strings := preload("res://ui/components/CarriedHomePresentation.gd")

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: Label = %BodyLabel
@onready var _warning: Label = %WarningLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _confirm_row: HBoxContainer = %ConfirmRow
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _gathered: Label = %GatheredLabel
@onready var _risk: Label = %RiskLabel
@onready var _keeps: Label = %KeepsLabel

var _action: Dictionary = {}
var _confirm_mode := false
var _sent := false

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)

func present(payload: Dictionary) -> void:
	_apply_layout(payload)
	_sent = false
	_confirm_mode = bool(payload.get("confirm", false))
	_title.text = Strings.CONFIRM_TITLE
	_confirm_row.visible = _confirm_mode
	_continue_button.visible = not _confirm_mode
	if _confirm_mode:
		var action_v: Variant = payload.get("action", {})
		_action = action_v if action_v is Dictionary else {}
		_subtitle.visible = false
		_body.text = Strings.CONFIRM_QUESTION
		_warning.text = Strings.CONFIRM_WARNING
		_warning.visible = true
		_confirm_button.text = Strings.CONFIRM_LABEL
		_cancel_button.text = Strings.CANCEL_LABEL
		_confirm_button.disabled = _action.is_empty()
		# The gathered block sums every source in the packs. Nothing in them shows the empty line, and
		# then the risk line has nothing to warn about.
		var carry_v: Variant = payload.get("carry", {})
		var carry: Dictionary = carry_v if carry_v is Dictionary else {}
		var packs_v: Variant = carry.get("gathered", {})
		var packs: Dictionary = packs_v if packs_v is Dictionary else {}
		var gathered := Strings.gathered_line(int(packs.get("ase", 0)), int(packs.get("ekwan", 0)))
		_gathered.text = gathered if not gathered.is_empty() else Strings.GATHERED_EMPTY
		_gathered.visible = true
		_risk.text = Strings.RISK_LINE
		_risk.visible = not gathered.is_empty()
		_keeps.text = Strings.KEEPS_LINE
		_keeps.visible = true
		_cancel_button.grab_focus()
		return
	# Result mode: the escape failed. Nothing was carried, so no gathered figure shows.
	var result: Dictionary = payload.get("result", {})
	_subtitle.visible = true
	_subtitle.text = Strings.FAILED_SUBTITLE
	_warning.visible = false
	_body.text = str(result.get("message", ""))
	_continue_button.text = "Continue"
	_action = { "type": "stage.dismiss_overlay" }
	_gathered.visible = false
	_risk.visible = false
	_keeps.visible = false

func _on_continue_pressed() -> void:
	if _action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(_action)

## Confirm sends the action once. A second press does nothing.
func _on_confirm_pressed() -> void:
	if _sent or _action.is_empty():
		return
	_sent = true
	_confirm_button.disabled = true
	dismiss_requested.emit()
	action_requested.emit(_action)

func _on_cancel_pressed() -> void:
	if _sent:
		return
	dismiss_requested.emit()

## Hardware Back is Cancel in confirm mode, like Esc. The result display ignores it.
func handle_go_back() -> void:
	if _confirm_mode:
		_on_cancel_pressed()

## Esc is Cancel in confirm mode.
func _input(event: InputEvent) -> void:
	if _confirm_mode and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
