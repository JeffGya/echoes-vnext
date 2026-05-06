extends Control

class_name SanctumScreen

signal action_requested(action: Dictionary)

const ThreadSlotItemScene: PackedScene = preload("res://ui/components/ThreadSlotItem.tscn")
const EmotionChipScene: PackedScene = preload("res://ui/components/EmotionChip.tscn")

@onready var title_label: Label = %TitleLabel
@onready var vow_mantra_label: Label = %VowMantraLabel
@onready var guidance_label: Label = %GuidanceLabel
@onready var ase_kicker_label: Label = %AseKickerLabel
@onready var ase_label: Label = %AseLabel
@onready var ase_rate_label: Label = %AseRateLabel
@onready var ase_delta_label: Label = %AseDeltaLabel

@onready var party_summary_label: Label = %PartySummaryLabel
@onready var party_empty_label: Label = %PartyEmptyLabel
@onready var party_scroll: ScrollContainer = %PartyScroll
@onready var party_list: VBoxContainer = %PartyList
@onready var party_entry_template: HBoxContainer = %PartyEntryTemplate
@onready var thread_count_label: Label = %ThreadCountLabel
@onready var thread_empty_label: Label = %ThreadEmptyLabel
@onready var thread_note_label: Label = %ThreadNoteLabel
@onready var thread_slots: HBoxContainer = %ThreadSlots

@onready var name_modal: Control = %NameModal
@onready var name_edit: LineEdit = %NameEdit
@onready var reroll_button: Button = %RerollButton
@onready var confirm_button: Button = %ConfirmButton

var _snapshot: Dictionary = {}
var _name_dirty := false
var _last_ase_balance: int = -1
var _ase_tween: Tween


func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(_on_name_edit_changed)


func set_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_render()


func _render() -> void:
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_name := str(data.get("sanctum_name", ""))
	var suggested := str(data.get("sanctum_name_suggested", "Sanctum"))
	var ase_balance := int(data.get("ase_balance", 0))
	var per_hour := float(data.get("ase_rate_per_hour_hint", 0.0))
	var party_slots_v: Variant = data.get("party_slots", [])
	var party_slots: Array = party_slots_v if party_slots_v is Array else []
	var thread_reserve_v: Variant = data.get("thread_reserve", [])
	var thread_reserve: Array = thread_reserve_v if thread_reserve_v is Array else []
	var reserve_cap := int(data.get("thread_reserve_cap", 4))
	var active_vow_v: Variant = data.get("active_vow", {})
	var active_vow: Dictionary = active_vow_v if active_vow_v is Dictionary else {}
	var has_active_realm := not str(data.get("realm_id", "")).is_empty()

	title_label.text = sanctum_name if not sanctum_name.is_empty() else suggested
	guidance_label.text = "Resume the active trial from the courtyard." if has_active_realm else "Choose where the house reaches outward next."
	ase_kicker_label.text = "Ase"

	if not active_vow.is_empty():
		var proverb_twi := str(active_vow.get("proverb_twi", ""))
		var proverb_en := str(active_vow.get("proverb_en", ""))
		vow_mantra_label.text = "%s - \"%s\"" % [proverb_twi, proverb_en]
		vow_mantra_label.visible = not proverb_twi.is_empty() or not proverb_en.is_empty()
	else:
		vow_mantra_label.visible = false

	ase_label.text = str(ase_balance)
	ase_rate_label.text = "~ %.1f per hour" % per_hour

	party_summary_label.text = "Chosen echoes for the next departure." if not party_slots.is_empty() else "No departure party is set."
	_rebuild_party_list(party_slots)
	_rebuild_thread_reserve(thread_reserve, reserve_cap)

	if _last_ase_balance != -1 and ase_balance != _last_ase_balance:
		var delta := ase_balance - _last_ase_balance
		_show_ase_delta(delta)
		_pulse_ase_label()
	_last_ase_balance = ase_balance

	if sanctum_name.is_empty():
		name_modal.visible = true
		if not _name_dirty:
			name_edit.text = suggested
			_name_dirty = false
		confirm_button.disabled = name_edit.text.strip_edges().is_empty()
	else:
		name_modal.visible = false
		_name_dirty = false


func _rebuild_party_list(party_slots: Array) -> void:
	for child in party_list.get_children():
		if child == party_entry_template:
			continue
		child.queue_free()

	party_empty_label.visible = party_slots.is_empty()
	party_scroll.visible = not party_slots.is_empty()
	party_scroll.custom_minimum_size.y = 0.0
	if party_slots.is_empty():
		return

	var row_count := 0
	for slot_v in party_slots:
		if not (slot_v is Dictionary):
			continue
		var slot: Dictionary = slot_v
		var row := party_entry_template.duplicate() as HBoxContainer
		row.visible = true
		var existing_chip := row.find_child("EntryMoodChip", true, false)
		if existing_chip != null:
			existing_chip.queue_free()
		(row.find_child("EntryNameLabel", true, false) as Label).text = str(slot.get("name", "Echo"))
		var chip := EmotionChipScene.instantiate()
		chip.name = "EntryMoodChip"
		chip.call("setup", str(slot.get("emotional_status", "")))
		row.add_child(chip)
		row.move_child(chip, 1)
		(row.find_child("EntryStepLabel", true, false) as Label).text = "Standing %d  Step %d" % [
			int(slot.get("standing", 1)),
			int(slot.get("step", 1))
		]
		party_list.add_child(row)
		row_count += 1

	call_deferred("_sync_party_scroll_height")


func _sync_party_scroll_height() -> void:
	if party_scroll == null or party_list == null:
		return
	var content_height := party_list.get_combined_minimum_size().y
	var max_visible_height := 112.0
	party_scroll.custom_minimum_size.y = minf(content_height, max_visible_height)


func _rebuild_thread_reserve(thread_reserve: Array, reserve_cap: int) -> void:
	for child in thread_slots.get_children():
		child.queue_free()

	thread_count_label.text = "%d thread%s held in reserve." % [thread_reserve.size(), "" if thread_reserve.size() == 1 else "s"]
	thread_empty_label.visible = thread_reserve.is_empty()
	thread_note_label.text = "Weaving begins from an Echo's rite path."

	for i in range(reserve_cap):
		var slot: ThreadSlotItem = ThreadSlotItemScene.instantiate()
		thread_slots.add_child(slot)
		if i < thread_reserve.size():
			var thread_v: Variant = thread_reserve[i]
			var thread: Dictionary = thread_v if thread_v is Dictionary else {}
			slot.setup_filled(str(thread.get("virtue", "")), str(thread.get("quality_tier", "broken")))
		else:
			slot.setup_empty()


func _on_name_edit_changed(new_text: String) -> void:
	_name_dirty = true
	confirm_button.disabled = new_text.strip_edges().is_empty()


func _on_reroll_pressed() -> void:
	action_requested.emit({"type": "sanctum.name.reroll"})


func _on_confirm_pressed() -> void:
	action_requested.emit({"type": "sanctum.name.confirm", "name": name_edit.text.strip_edges()})


func _pulse_ase_label() -> void:
	if _ase_tween != null and _ase_tween.is_running():
		_ase_tween.kill()

	ase_label.scale = Vector2.ONE
	_ase_tween = create_tween()
	_ase_tween.tween_property(ase_label, "scale", Vector2(1.04, 1.04), 0.08)
	_ase_tween.tween_property(ase_label, "scale", Vector2.ONE, 0.12)


func _show_ase_delta(delta: int) -> void:
	ase_delta_label.visible = true
	ase_delta_label.text = "%+d" % delta
	ase_delta_label.modulate.a = 1.0
	var start_y := ase_delta_label.position.y

	var tween := create_tween()
	tween.tween_property(ase_delta_label, "position:y", start_y - 6.0, 0.25)
	tween.tween_property(ase_delta_label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		ase_delta_label.visible = false
		ase_delta_label.position.y = start_y
	)
