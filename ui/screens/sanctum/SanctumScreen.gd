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
@onready var party_slots_label: Label        = %PartySlots
@onready var _party_slot_list: VBoxContainer = %PartySlotList
@onready var _house_state_list: VBoxContainer = %HouseStateList

@onready var name_modal: Control = %NameModal
@onready var name_edit: LineEdit = %NameEdit
@onready var reroll_button: Button = %RerollButton
@onready var confirm_button: Button = %ConfirmButton

# V2-WEAVE-001: Thread Reserve Strip
@onready var _thread_slots: HBoxContainer = %ThreadSlots
const ThreadSlotItemScene: PackedScene = preload("res://ui/components/ThreadSlotItem.tscn")


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
	

	# Party slots (SANCTUM-003 Subtask 4 + V2-EMOTION-001 morale)
	var slots_v: Variant = data.get("party_slots", [])
	var slots: Array = slots_v if slots_v is Array else []
	if slots.is_empty():
		party_slots_label.text = "No party set"
	else:
		party_slots_label.text = "Party: %d" % slots.size()
	for child in _party_slot_list.get_children():
		child.queue_free()
	for s_v in slots:
		if not (s_v is Dictionary):
			continue
		var s: Dictionary = s_v
		var nm := str(s.get("name", "?"))
		# V2-EMOTION-002: unified emotional_status replaces morale_tier.
		var es := str(s.get("emotional_status", ""))
		var lbl := Label.new()
		lbl.text = "%s — [%s]" % [nm, es.capitalize()] if es != "" else nm
		lbl.theme_type_variation = &"ContentBasePanel"
		_party_slot_list.add_child(lbl)

	# V2-EMOTION-002: House State strip — roster_preview first 3 echoes.
	for child in _house_state_list.get_children():
		child.queue_free()
	var preview_v: Variant = data.get("roster_preview", [])
	var preview: Array = preview_v if preview_v is Array else []
	var house_limit: int = mini(3, preview.size())
	for i in range(house_limit):
		var p_v: Variant = preview[i]
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		var p_nm := str(p.get("name", "?"))
		var p_emo_v: Variant = p.get("emotion", {})
		var p_emo: Dictionary = p_emo_v if p_emo_v is Dictionary else {}
		var p_es := str(p_emo.get("emotional_status", ""))
		var lbl2 := Label.new()
		lbl2.text = "%s — [%s]" % [p_nm, p_es.capitalize()] if p_es != "" else p_nm
		lbl2.theme_type_variation = &"ContentBasePanel"
		_house_state_list.add_child(lbl2)

	# Ase animate on change
	if _last_ase_balance != -1 and ase_balance != _last_ase_balance:
		var delta := ase_balance - _last_ase_balance
		_show_ase_delta(delta)
		_pulse_ase_label()

	_last_ase_balance = ase_balance

	# V2-WEAVE-001: Thread Reserve Strip
	var thread_reserve_v: Variant = data.get("thread_reserve", [])
	var thread_reserve: Array = thread_reserve_v if thread_reserve_v is Array else []
	var reserve_cap: int = int(data.get("thread_reserve_cap", 4))
	_rebuild_thread_reserve(thread_reserve, reserve_cap)

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

# V2-WEAVE-001: Rebuild the 4-slot Thread Reserve Strip from snapshot data.
func _rebuild_thread_reserve(thread_reserve: Array, reserve_cap: int) -> void:
	if _thread_slots == null:
		return
	for c in _thread_slots.get_children():
		c.queue_free()
	for i in range(reserve_cap):
		var slot: ThreadSlotItem = ThreadSlotItemScene.instantiate()
		_thread_slots.add_child(slot)
		if i < thread_reserve.size():
			var t_v: Variant = thread_reserve[i]
			var t_d: Dictionary = t_v if t_v is Dictionary else {}
			slot.setup_filled(str(t_d.get("virtue", "")), str(t_d.get("quality_tier", "broken")))
		else:
			slot.setup_empty()


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
	
