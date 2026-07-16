extends Control
class_name InstitutionDetailModal

signal action_requested(action: Dictionary)
signal dismiss_requested()

const EmotionPresentation := preload("res://ui/components/EmotionPresentation.gd")
const SanctumOccupantLayer := preload("res://ui/sanctum/SanctumOccupantLayer.gd")

@onready var safe_frame: MarginContainer = %SafeFrame
@onready var name_label: Label = %InstDetailName
@onready var condition_label: Label = %InstDetailCondition
@onready var passive_effect_label: Label = %PassiveEffectLabel
@onready var occupant_list: VBoxContainer = %InstDetailOccupantList
@onready var occupant_template: HBoxContainer = %OccupantRowTemplate
@onready var assign_button: Button = %InstDetailAssignButton
@onready var establish_button: Button = %InstDetailEstablishButton
@onready var back_button: Button = %InstDetailBackButton
@onready var picker_panel: PanelContainer = %EchoAssignPicker
@onready var picker_list: VBoxContainer = %PickerList
@onready var picker_template: Button = %PickerRowTemplate
@onready var picker_cancel_button: Button = %PickerCancelButton

var _institution_id := ""
var _inst_data: Dictionary = {}
var _detail_roster: Array = []
var _institutions: Array = []
var _compat_hints: Dictionary = {}
var _actions: Dictionary = {}

const _INSTITUTION_IDENTITY: Dictionary = {
	"hearth": "Care & Belonging",
	"training_grounds": "Readiness & Discipline",
}
const _INSTITUTION_CONDITION_PHRASES: Dictionary = {
	"healthy": "Thriving",
	"strained": "Under strain",
	"neglected": "Neglected",
}
const _INSTITUTION_CONDITION_COLORS: Dictionary = {
	"healthy": Color("#D4AF37"),
	"strained": Color("#C87941"),
	"neglected": Color("#5A5A6A"),
}
const _INSTITUTION_PASSIVE_EFFECT: Dictionary = {
	"hearth": "All echoes in the Sanctum recover +2 morale per hour",
	"training_grounds": "All echoes in the Sanctum gain +1 storyweight per hour",
}

func _ready() -> void:
	back_button.pressed.connect(func() -> void:
		dismiss_requested.emit()
	)
	assign_button.pressed.connect(_show_assign_picker)
	establish_button.pressed.connect(_on_establish_pressed)
	picker_cancel_button.pressed.connect(func() -> void:
		picker_panel.visible = false
	)
	occupant_template.visible = false
	picker_template.visible = false
	picker_panel.visible = false

func present(payload: Dictionary) -> void:
	_institution_id = str(payload.get("institution_id", ""))
	_inst_data = payload.get("institution", {}) if payload.get("institution", {}) is Dictionary else {}
	_detail_roster = payload.get("detail_roster", []) if payload.get("detail_roster", []) is Array else []
	_institutions = payload.get("institutions", []) if payload.get("institutions", []) is Array else []
	_compat_hints = payload.get("compat_hints", {}) if payload.get("compat_hints", {}) is Dictionary else {}
	_actions = payload.get("actions", {}) if payload.get("actions", {}) is Dictionary else {}
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)
	picker_panel.visible = false
	_render_detail()
	if bool(payload.get("show_assign_picker", false)):
		_show_assign_picker()

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)

func _render_detail() -> void:
	name_label.text = _institution_id.replace("_", " ").capitalize()
	var condition := str(_inst_data.get("condition", "neglected"))
	var identity := str(_INSTITUTION_IDENTITY.get(_institution_id, ""))
	var phrase := str(_INSTITUTION_CONDITION_PHRASES.get(condition, condition.capitalize()))
	condition_label.text = ("%s - %s" % [identity, phrase]) if not identity.is_empty() else phrase
	condition_label.modulate = _INSTITUTION_CONDITION_COLORS.get(condition, Color.WHITE)
	passive_effect_label.text = str(_INSTITUTION_PASSIVE_EFFECT.get(_institution_id, ""))
	passive_effect_label.visible = not passive_effect_label.text.is_empty()
	_rebuild_occupants()
	var is_unlocked := bool(_inst_data.get("unlocked", _inst_data.get("is_unlocked", false)))
	var is_candidate := bool(_inst_data.get("is_candidate", false))
	var occupant_count := (_inst_data.get("occupant_ids", []) as Array).size()
	assign_button.visible = is_unlocked and occupant_count < 4
	establish_button.visible = is_candidate and not is_unlocked
	var slot_key := "cta.establish." + _institution_id
	var establish_v: Variant = _actions.get(slot_key, {})
	if establish_v is Dictionary:
		var establish: Dictionary = establish_v
		establish_button.disabled = bool(establish.get("disabled", false))
		var payload_v: Variant = establish.get("payload", {})
		var payload: Dictionary = payload_v if payload_v is Dictionary else {}
		establish_button.text = "Establish (%d Ekwan)" % int(payload.get("establish_ekwan_cost", 10))

func _rebuild_occupants() -> void:
	for child in occupant_list.get_children():
		if child != occupant_template:
			occupant_list.remove_child(child)
			child.free()
	for oid_v in (_inst_data.get("occupant_ids", []) as Array):
		var oid := str(oid_v)
		var row := occupant_template.duplicate() as HBoxContainer
		row.visible = true
		var name_node := row.find_child("OccupantName", true, false) as Label
		if name_node != null:
			name_node.text = _echo_name(oid)
		var dot_node := row.find_child("OccupantEmotionDot", true, false) as Label
		if dot_node != null:
			dot_node.modulate = SanctumOccupantLayer.fill_for_emotional_status(_echo_status(oid))
		var remove_button := row.find_child("OccupantRemoveButton", true, false) as Button
		if remove_button != null:
			remove_button.pressed.connect(_on_remove_pressed.bind(oid))
		occupant_list.add_child(row)

func _show_assign_picker() -> void:
	for child in picker_list.get_children():
		if child != picker_template:
			picker_list.remove_child(child)
			child.free()
	var assigned_ids: Array = []
	for inst_v in _institutions:
		if not (inst_v is Dictionary):
			continue
		for oid in ((inst_v as Dictionary).get("occupant_ids", []) as Array):
			assigned_ids.append(str(oid))
	var inst_hints: Dictionary = _compat_hints.get(_institution_id, {}) as Dictionary
	for echo_v in _detail_roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var eid := str(echo.get("id", ""))
		if eid.is_empty() or assigned_ids.has(eid):
			continue
		var row := picker_template.duplicate() as Button
		row.visible = true
		var hint := str(inst_hints.get(eid, ""))
		row.text = str(echo.get("name", "Echo")) + ("\n" + hint if not hint.is_empty() else "")
		row.pressed.connect(_on_assign_pressed.bind(eid))
		picker_list.add_child(row)
	picker_panel.visible = true

func _echo_name(echo_id: String) -> String:
	for echo_v in _detail_roster:
		if echo_v is Dictionary and str((echo_v as Dictionary).get("id", "")) == echo_id:
			return str((echo_v as Dictionary).get("name", echo_id))
	return echo_id

func _echo_status(echo_id: String) -> String:
	for echo_v in _detail_roster:
		if echo_v is Dictionary and str((echo_v as Dictionary).get("id", "")) == echo_id:
			return EmotionPresentation.normalize(str((echo_v as Dictionary).get("emotional_status", "")))
	return EmotionPresentation.DEFAULT_STATUS

func _on_remove_pressed(echo_id: String) -> void:
	action_requested.emit({
		"type": "sanctum.institution.remove_echo",
		"payload": { "institution_id": _institution_id, "echo_id": echo_id },
	})

func _on_assign_pressed(echo_id: String) -> void:
	picker_panel.visible = false
	action_requested.emit({
		"type": "sanctum.institution.assign_echo",
		"payload": { "institution_id": _institution_id, "echo_id": echo_id },
	})

func _on_establish_pressed() -> void:
	var slot_key := "cta.establish." + _institution_id
	var action_v: Variant = _actions.get(slot_key, {})
	if action_v is Dictionary:
		action_requested.emit((action_v as Dictionary).duplicate(true))
