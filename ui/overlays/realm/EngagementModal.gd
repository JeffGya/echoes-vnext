class_name EngagementModal
extends Control

signal action_requested(action: Dictionary)
signal dismiss_requested

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: Label = %BodyLabel
@onready var _detail: Label = %DetailLabel
@onready var _enter_button: Button = %EnterButton
@onready var _pass_button: Button = %PassButton
@onready var _choice_column: VBoxContainer = %ChoiceColumn
@onready var _choice_0: Button = %ChoiceButton0
@onready var _choice_1: Button = %ChoiceButton1
@onready var _safe_frame: MarginContainer = %SafeFrame

var _enter_action: Dictionary = {}
var _pass_action: Dictionary = {}
var _choice_actions: Array = []

func _ready() -> void:
	_enter_button.pressed.connect(_on_enter_pressed)
	_pass_button.pressed.connect(_on_pass_pressed)
	_choice_0.pressed.connect(_on_choice_pressed.bind(0))
	_choice_1.pressed.connect(_on_choice_pressed.bind(1))

func present(payload: Dictionary) -> void:
	_apply_layout(payload)
	var pending: Dictionary = payload.get("pending", {})
	var engage_action: Dictionary = payload.get("engage_action", {})
	var ignore_action: Dictionary = payload.get("ignore_action", {})
	_enter_action = engage_action.duplicate(true)
	_pass_action = ignore_action.duplicate(true)
	_choice_actions.clear()

	var revealed := bool(pending.get("revealed", false))
	var is_objective := bool(pending.get("is_objective", false)) and revealed
	_title.text = "Objective" if is_objective else "Encounter"
	_title.remove_theme_color_override("font_color")
	if is_objective:
		_title.add_theme_color_override("font_color", Color("#C8A96E"))
	_subtitle.text = str(pending.get("type", "")).capitalize() if revealed else "Unknown"
	_body.text = "The party stands before the situation. Commit to engage?" if revealed else "The party senses something ahead. Enter to discover what awaits."
	_detail.text = _detail_text(pending)
	_detail.visible = not _detail.text.is_empty()
	_populate_choices(pending)
	_enter_button.visible = _choice_actions.is_empty()
	_pass_button.visible = not _pass_action.is_empty()

func _populate_choices(pending: Dictionary) -> void:
	var choices_v: Variant = pending.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	var buttons: Array = [_choice_0, _choice_1]
	var situation_id := str(pending.get("situation_id", ""))
	for i in range(buttons.size()):
		var button := buttons[i] as Button
		if i >= choices.size():
			button.visible = false
			continue
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {}
		var choice_id := str(choice.get("id", ""))
		if choice_id.is_empty():
			button.visible = false
			continue
		button.text = str(choice.get("label", choice_id.capitalize()))
		button.visible = true
		_choice_actions.append({
			"type": "stage.resolve_situation_choice",
			"situation_id": situation_id,
			"choice_id": choice_id,
		})
	_choice_column.visible = not _choice_actions.is_empty()

func _detail_text(pending: Dictionary) -> String:
	var lines: Array[String] = []
	var clues_v: Variant = pending.get("intel_clues", [])
	if clues_v is Array and not (clues_v as Array).is_empty():
		lines.append(str((clues_v as Array)[0]))
	var enemy_est := str(pending.get("enemy_estimate", ""))
	if not enemy_est.is_empty():
		lines.append(enemy_est)
	return "\n".join(lines)

func _on_enter_pressed() -> void:
	_emit_exiting_action(_enter_action)

func _on_pass_pressed() -> void:
	_emit_exiting_action(_pass_action)

func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _choice_actions.size():
		return
	_emit_exiting_action(_choice_actions[index])

func _emit_exiting_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	dismiss_requested.emit()
	action_requested.emit(action)

func _apply_layout(payload: Dictionary) -> void:
	var layout_v: Variant = payload.get("layout", {})
	var layout: Dictionary = layout_v if layout_v is Dictionary else {}
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", layout)
