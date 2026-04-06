# SanctumScreen.gd

extends Control

class_name SanctumScreen

signal action_requested(action: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var vow_mantra_label: Label = %VowMantraLabel  # VOW-001: active vow proverb under title
@onready var ase_label: Label = %AseLabel
@onready var ase_rate_label: Label = %AseRateLabel
@onready var ase_delta_label: Label = %AseDeltaLabel
@onready var echo_count_label : Label = %EchoCountLabel

@onready var echo_preview_1: Label = %EchoPreview1
@onready var echo_preview_2: Label = %EchoPreview2
@onready var echo_preview_3: Label = %EchoPreview3
@onready var party_slots_label: Label = %PartySlots

@onready var name_modal: Control = %NameModal
@onready var name_edit: LineEdit = %NameEdit
@onready var reroll_button: Button = %RerollButton
@onready var confirm_button: Button = %ConfirmButton


var _snapshot: Dictionary = {}
var _name_dirty := false

var _last_ase_balance: int = -1
var _ase_tween: Tween


func set_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_render()
	
func _render() -> void:
	var data_v = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var ase_balance := int(data.get("ase_balance", 0))
	var per_hour := float(data.get("ase_rate_per_hour_hint", 0.0))

	var sanctum_name := str(data.get("sanctum_name", ""))
	var suggested := str(data.get("sanctum_name_suggested", "Sanctum"))
		
	title_label.text = sanctum_name if sanctum_name != "" else "Sanctum"

	# VOW-001: display active vow proverb as a mantra under the sanctum title
	var av_v: Variant = data.get("active_vow", {})
	var av: Dictionary = av_v if av_v is Dictionary else {}
	if vow_mantra_label != null:
		if not av.is_empty() and str(av.get("proverb_twi", "")) != "":
			var twi := str(av.get("proverb_twi", ""))
			var en  := str(av.get("proverb_en", ""))
			vow_mantra_label.text = "%s — \"%s\"" % [twi, en]
			vow_mantra_label.visible = true
		else:
			vow_mantra_label.visible = false

	ase_label.text = "%d" % ase_balance
	ase_rate_label.text = "~ %.1f p/h" % per_hour
	echo_count_label.text = "%d echoes" % int(data.get("roster_count", 0))
	

	# Party slots (SANCTUM-003 Subtask 4)
	var slots_v: Variant = data.get("party_slots", [])
	var slots: Array = slots_v if slots_v is Array else []
	if slots.is_empty():
		party_slots_label.text = "No party set"
	else:
		var lines: Array = []
		for s_v in slots:
			if not (s_v is Dictionary):
				continue
			var s: Dictionary = s_v
			var nm := str(s.get("name", "?"))
			var lv := int(s.get("step", 1))
			var rk := int(s.get("standing", 1))
			lines.append("%s  Step%d  S%d" % [nm, lv, rk])
		party_slots_label.text = "Party:\n" + "\n".join(lines)

	# Ase animate on change
	if _last_ase_balance != -1 and ase_balance != _last_ase_balance:
		var delta := ase_balance - _last_ase_balance
		_show_ase_delta(delta)
		_pulse_ase_label()

	_last_ase_balance = ase_balance

	if sanctum_name == "":
		# Modal opening edge: reset dirty so first suggestion shows and rerolls work
		if not name_modal.visible:
			_name_dirty = false

		name_modal.visible = true

		# Keep synced to suggestion unless user has started typing
		if not _name_dirty:
			name_edit.text = suggested

		name_edit.grab_focus()
	else:
		name_modal.visible = false

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(_on_name_edit_changed)

# Helpers
func _on_name_edit_changed(_new_text: String) -> void:
	_name_dirty = true

func _on_reroll_pressed() -> void:
		action_requested.emit({ "type": "sanctum.name.reroll" })

func _on_confirm_pressed() -> void:
		action_requested.emit({ "type": "sanctum.name.confirm", "name": name_edit.text })

func _pulse_ase_label() -> void:
	if _ase_tween != null and _ase_tween.is_running():
		_ase_tween.kill()

	ase_label.scale = Vector2.ONE
	_ase_tween = create_tween()
	_ase_tween.tween_property(ase_label, "scale", Vector2(1.04, 1.04), 0.08)
	_ase_tween.tween_property(ase_label, "scale", Vector2.ONE, 0.12)

func _show_ase_delta(delta: int) -> void:
	ase_delta_label.visible = true
	ase_delta_label.text = ("%+d" % delta) # shows +5 / -2

	var start_y := ase_delta_label.position.y
	ase_delta_label.modulate.a = 1.0

	var tw := create_tween()
	tw.tween_property(ase_delta_label, "position:y", start_y - 6.0, 0.25)
	tw.tween_property(ase_delta_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		ase_delta_label.visible = false
		ase_delta_label.position.y = start_y
	)
	
