extends Control

class_name KeeperIntroScreen

signal action_requested(action: Dictionary)

@onready var _renderer: Node2D = %SanctumSpatialRenderer
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _thread_card: PanelContainer = %ThreadSigilCard
@onready var _flame_core: ColorRect = %FlameCore
@onready var _cta_button: Button = %CtaButton
@onready var _choice_buttons: Array[Button] = [%ChoiceButton1, %ChoiceButton2, %ChoiceButton3]

var _cta_action: Dictionary = {}
var _choice_actions: Array[Dictionary] = []
var _lines: Array[String] = []
var _line_index := 0
var _typing_tween: Tween
var _line_is_typing := false


func _ready() -> void:
	_cta_button.pressed.connect(_on_cta_pressed)
	for i in range(_choice_buttons.size()):
		_choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))


func set_snapshot(snap: Dictionary) -> void:
	if _renderer != null and _renderer.has_method("render"):
		_renderer.call("render", snap)
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	_title_label.text = str(data.get("title", ""))
	var lines_v: Variant = data.get("lines", [])
	var lines: Array = lines_v if lines_v is Array else []
	_lines.clear()
	for line_v in lines:
		_lines.append(str(line_v))
	if _lines.is_empty():
		_lines.append("")
	_line_index = 0
	var step := str(data.get("step", ""))

	_thread_card.visible = step == "thread_returns" or step == "first_weaving"
	if _thread_card.visible:
		_thread_card.call("bind_thread", {
			"id": str(data.get("first_thread_id", "")),
			"display_name": "First Thread",
			"virtue": str(data.get("selected_virtue", "")),
			"quality_tier": "clean",
		}, true, "Woven")
		_thread_card.call("set_selectable", false)
	var flame_v: Variant = data.get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	_flame_core.visible = step == "awakening_rite" or bool(flame.get("awakened", false))

	var cta_v: Variant = actions.get("cta.continue", {})
	_cta_action = cta_v if cta_v is Dictionary else {}
	_cta_button.text = str(_cta_action.get("label", "Continue"))
	_cta_button.disabled = bool(_cta_action.get("disabled", false))

	_choice_actions.clear()
	var choice_slots := ["choice.guard", "choice.listen", "choice.return"]
	for i in range(_choice_buttons.size()):
		var slot: String = choice_slots[i]
		var action_v: Variant = actions.get(slot, {})
		var action: Dictionary = action_v if action_v is Dictionary else {}
		_choice_actions.append(action)
		_choice_buttons[i].text = str(action.get("label", ""))
		_choice_buttons[i].disabled = bool(action.get("disabled", false))
	_show_current_line()


func _show_current_line() -> void:
	_stop_typewriter()
	_line_is_typing = true
	_body_label.text = ""
	_sync_action_visibility()
	_typing_tween = create_tween()
	var text := _lines[_line_index] if _line_index < _lines.size() else ""
	for i in range(text.length()):
		_typing_tween.tween_callback(func(idx := i): _body_label.text = text.substr(0, idx + 1))
		_typing_tween.tween_interval(0.02)
	_typing_tween.tween_callback(Callable(self, "_on_typewriter_finished"))


func _stop_typewriter() -> void:
	if _typing_tween != null and _typing_tween.is_running():
		_typing_tween.kill()
	_typing_tween = null
	_line_is_typing = false


func _on_typewriter_finished() -> void:
	_line_is_typing = false
	_sync_action_visibility()


func _sync_action_visibility() -> void:
	var can_show_actions := not _line_is_typing
	var has_more_lines := _line_index < _lines.size() - 1
	_cta_button.visible = can_show_actions and (has_more_lines or not _cta_action.is_empty())
	_cta_button.text = "Continue" if has_more_lines else str(_cta_action.get("label", "Continue"))
	for i in range(_choice_buttons.size()):
		var has_action := i < _choice_actions.size() and not _choice_actions[i].is_empty()
		_choice_buttons[i].visible = can_show_actions and not has_more_lines and has_action


func _on_cta_pressed() -> void:
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_show_current_line()
		return
	if not _cta_action.is_empty():
		action_requested.emit(_cta_action)


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _choice_actions.size():
		return
	var action := _choice_actions[index]
	if not action.is_empty():
		action_requested.emit(action)
