extends Control

class_name SanctumScreen

signal action_requested(action: Dictionary)
signal echo_detail_closed

const ThreadSlotItemScene: PackedScene = preload("res://ui/components/ThreadSlotItem.tscn")
const EmotionChipScene: PackedScene = preload("res://ui/components/EmotionChip.tscn")

@onready var title_label: Label = %TitleLabel
@onready var vow_mantra_label: Label = %VowMantraLabel
@onready var _vow_compliance_label: Label = %VowComplianceLabel
@onready var guidance_label: Label = %GuidanceLabel
@onready var ase_kicker_label: Label = %AseKickerLabel
@onready var ase_label: Label = %AseLabel
@onready var ase_flame_tip: Label = %AseFlameTip
@onready var ase_delta_label: Label = %AseDeltaLabel
@onready var top_band: HBoxContainer = %TopBand
@onready var ekwan_label: Label = %EkwanLabel
@onready var _awakening_overlay: Control = %AwakeningOverlay
@onready var _awakening_grant_label: Label = %AwakeningGrantLabel
@onready var _awakening_dismiss: Button = %AwakeningDismiss

@onready var party_summary_label: Label = %PartySummaryLabel
@onready var party_empty_label: Label = %PartyEmptyLabel
@onready var party_scroll: ScrollContainer = %PartyScroll
@onready var party_list: VBoxContainer = %PartyList
@onready var party_entry_template: HBoxContainer = %PartyEntryTemplate
@onready var thread_count_label: Label = %ThreadCountLabel
@onready var thread_empty_label: Label = %ThreadEmptyLabel
@onready var thread_note_label: Label = %ThreadNoteLabel
@onready var thread_slots: HBoxContainer = %ThreadSlots
@onready var left_stack: VBoxContainer = %LeftStack
@onready var right_stack: VBoxContainer = %RightStack

@onready var echo_detail_panel: PanelContainer = %EchoDetailPanel
@onready var detail_back_button: Button = %DetailBackButton
@onready var detail_prev_button: Button = %DetailPrevButton
@onready var detail_next_button: Button = %DetailNextButton
@onready var tab_overview: Button = %TabOverview
@onready var tab_bonds: Button = %TabBonds
@onready var tab_skills: Button = %TabSkills
@onready var overview_page: Control = %OverviewPage
@onready var bonds_page: Control = %BondsPage
@onready var skills_page: Control = %SkillsPage
@onready var detail_pages_scroll: ScrollContainer = %DetailPagesScroll
@onready var detail_name_label: Label = %DetailNameLabel
@onready var detail_archetype_label: Label = %DetailArchetypeLabel
@onready var detail_calling_label: Label = %DetailCallingLabel
@onready var detail_vector_label: Label = %DetailVectorLabel
@onready var detail_emotion_chip: EmotionChip = %DetailEmotionChip
@onready var detail_bark_label: Label = %DetailBarkLabel
@onready var detail_standing_label: Label = %DetailStandingLabel
@onready var detail_step_label: Label = %DetailStepLabel
@onready var detail_storyweight_label: Label = %DetailStoryweightLabel
@onready var detail_storyweight_bar: ProgressBar = %DetailStoryweightBar
@onready var detail_stat_attack_value: Label = %DetailStatAttackValue
@onready var detail_stat_defense_value: Label = %DetailStatDefenseValue
@onready var detail_stat_intelligence_value: Label = %DetailStatIntelligenceValue
@onready var detail_stat_agility_value: Label = %DetailStatAgilityValue
@onready var detail_stat_charisma_value: Label = %DetailStatCharismaValue
@onready var detail_stat_speed_value: Label = %DetailStatSpeedValue
@onready var detail_stat_max_health_value: Label = %DetailStatMaxHealthValue
@onready var detail_action_divider: PanelContainer = %ActionDivider
@onready var detail_party_action: PanelContainer = %DetailPartyAction
@onready var detail_party_action_title: Label = %DetailPartyActionTitle
@onready var detail_party_action_subtitle: Label = %DetailPartyActionSubtitle
@onready var detail_party_action_button: Button = %DetailPartyActionButton

@onready var name_modal: Control = %NameModal
@onready var name_edit: LineEdit = %NameEdit
@onready var reroll_button: Button = %RerollButton
@onready var confirm_button: Button = %ConfirmButton

# V2-VOW-002: ActiveEffectsPanel + EffectDetailPanel
@onready var _effects_panel:    PanelContainer = %ActiveEffectsPanel
@onready var _effects_list:     HBoxContainer  = %ActiveEffectsList
@onready var _effect_detail:    PanelContainer = %EffectDetailPanel
@onready var _detail_headline:  Label          = %EffectDetailHeadline
@onready var _detail_body:      Label          = %EffectDetailBody
@onready var _detail_duration:  Label          = %EffectDetailDuration

# V2-SANCTUM-002: institution panels
@onready var _inst_detail_panel:     PanelContainer     = %InstitutionDetailPanel
@onready var _inst_detail_name:      Label              = %InstDetailName
@onready var _inst_detail_condition: Label              = %InstDetailCondition
@onready var _inst_occupant_list:    VBoxContainer      = %InstDetailOccupantList
@onready var _occupant_row_template: HBoxContainer      = %OccupantRowTemplate
@onready var _inst_assign_btn:       Button             = %InstDetailAssignButton
@onready var _inst_establish_btn:    Button             = %InstDetailEstablishButton
@onready var _inst_back_btn:         Button             = %InstDetailBackButton
@onready var _assign_picker:         PanelContainer     = %EchoAssignPicker
@onready var _picker_list:           VBoxContainer      = %PickerList
@onready var _picker_row_template:   Button             = %PickerRowTemplate
@onready var _picker_cancel_btn:     Button             = %PickerCancelButton

# V2-SANCTUM-002: institutions overlay + placement bar
@onready var _header_card:           PanelContainer     = %HeaderCard
@onready var _sanctum_mgmt_btn:      Button             = %SanctumMgmtBtn
@onready var _institutions_overlay:  PanelContainer     = %InstitutionsOverlay
@onready var _inst_list:             VBoxContainer      = %InstitutionList
@onready var _inst_overlay_back_btn: Button             = %InstOverlayBackBtn
@onready var _placement_bar:         HBoxContainer      = %PlacementConfirmBar
@onready var _placement_label:       Label              = %PlacementLabel
@onready var _placement_confirm_btn: Button             = %PlacementConfirmBtn
@onready var _placement_cancel_btn:  Button             = %PlacementCancelBtn
@onready var _placement_toast:       Label              = %PlacementToast
@onready var _inst_compact_strip:    Button             = %InstitutionsCompactStrip


var _snapshot: Dictionary = {}
var _name_dirty := false
var _current_institution_id := ""
var _placement_cell: Variant = null   # Vector2i or null — the cell selected in placement mode
var _toast_timer: SceneTreeTimer = null
var _strip_confirm_pending: bool = false
var _strip_confirm_timer: SceneTreeTimer = null
var _last_ase_balance: int = -1
var _ase_tween: Tween
var _echo_detail_open := false
var _detail_tab := "overview"
var _selected_echo_id := ""

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(_on_name_edit_changed)
	detail_back_button.pressed.connect(_on_detail_close_pressed)
	detail_prev_button.pressed.connect(_on_detail_prev_pressed)
	detail_next_button.pressed.connect(_on_detail_next_pressed)
	tab_overview.pressed.connect(_on_tab_selected.bind("overview"))
	tab_bonds.pressed.connect(_on_tab_selected.bind("bonds"))
	tab_skills.pressed.connect(_on_tab_selected.bind("skills"))
	detail_party_action_button.pressed.connect(_on_detail_party_pressed)
	_awakening_dismiss.pressed.connect(_on_awakening_dismiss_pressed)
	_apply_awakening_panel_style()
	# V2-SANCTUM-002: institution wiring
	_inst_back_btn.pressed.connect(_on_inst_detail_back_pressed)
	_inst_assign_btn.pressed.connect(_on_inst_assign_pressed)
	_inst_establish_btn.pressed.connect(_on_inst_establish_pressed)
	_picker_cancel_btn.pressed.connect(_on_picker_cancel_pressed)
	# Institutions overlay + placement bar
	if _sanctum_mgmt_btn != null:
		_sanctum_mgmt_btn.pressed.connect(show_institutions_panel)
	if _inst_overlay_back_btn != null:
		# Route through shell so _institutions_open stays in sync.
		_inst_overlay_back_btn.pressed.connect(func() -> void:
			action_requested.emit({ "type": "ui.close_institutions_panel" })
		)
	if _placement_confirm_btn != null:
		_placement_confirm_btn.pressed.connect(_on_placement_confirmed)
	if _placement_cancel_btn != null:
		_placement_cancel_btn.pressed.connect(_on_placement_cancelled)
	if _institutions_overlay != null:
		_institutions_overlay.visible = false
	if _placement_bar != null:
		_placement_bar.visible = false
	if _placement_toast != null:
		_placement_toast.visible = false
	if _inst_compact_strip != null:
		_inst_compact_strip.visible = false
		_inst_compact_strip.pressed.connect(_on_inst_compact_strip_pressed)


func set_snapshot(snap: Dictionary) -> void:
	_snapshot = snap
	_render()


func _render() -> void:
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_name := str(data.get("sanctum_name", ""))
	var suggested := str(data.get("sanctum_name_suggested", "Sanctum"))
	var ase_balance := int(data.get("ase_balance", 0))
	var per_hour := float(data.get("ase_rate_per_hour", 0.0))
	var party_slots_v: Variant = data.get("party_slots", [])
	var party_slots: Array = party_slots_v if party_slots_v is Array else []
	var thread_reserve_v: Variant = data.get("thread_reserve", [])
	var thread_reserve: Array = thread_reserve_v if thread_reserve_v is Array else []
	var reserve_cap := int(data.get("thread_reserve_cap", 4))
	var active_vow_v: Variant = data.get("active_vow", {})
	var active_vow: Dictionary = active_vow_v if active_vow_v is Dictionary else {}
	var has_active_realm := not str(data.get("realm_id", "")).is_empty()
	var detail_roster_v: Variant = data.get("echo_detail_roster", [])
	var detail_roster: Array = detail_roster_v if detail_roster_v is Array else []

	title_label.text = sanctum_name if not sanctum_name.is_empty() else suggested
	guidance_label.text = "Resume the active trial from the courtyard." if has_active_realm else "Choose where the house reaches outward next."
	ase_kicker_label.text = "Ase"

	if not active_vow.is_empty():
		var proverb_twi := str(active_vow.get("proverb_twi", ""))
		var proverb_en := str(active_vow.get("proverb_en", ""))
		vow_mantra_label.text = "%s - \"%s\"" % [proverb_twi, proverb_en]
		vow_mantra_label.visible = not proverb_twi.is_empty() or not proverb_en.is_empty()
		# V2-VOW-002: compliance count under mantra — "N stages honored" when count > 0.
		var cc := int(active_vow.get("compliance_count", 0))
		if cc > 0:
			_vow_compliance_label.text = "%d stage%s honored" % [cc, "s" if cc != 1 else ""]
			_vow_compliance_label.visible = true
		else:
			_vow_compliance_label.visible = false
	else:
		vow_mantra_label.visible = false
		_vow_compliance_label.visible = false

	ase_label.text = str(ase_balance)

	# V2-ECONOMY-001: AseFlameTip — combined flame state + rate (replaces AseRateLabel)
	var ase_flame_awakened := bool(data.get("ase_flame_awakened", false))
	if ase_flame_awakened:
		ase_flame_tip.text = "Ase Flame recovering (~%.1f p/h)" % per_hour
		ase_flame_tip.add_theme_color_override("font_color", Color("#E8A030"))
	else:
		ase_flame_tip.text = "House dormant — Flame unlit"
		ase_flame_tip.add_theme_color_override("font_color", Color("#7A7A8A"))

	# V2-ECONOMY-001: Ekwan balance — show once any Ekwan has been earned
	var ekwan_balance := int(data.get("ekwan_balance", 0))
	ekwan_label.text    = "%d Ekwan" % ekwan_balance
	ekwan_label.visible = ekwan_balance > 0

	party_summary_label.text = "Chosen echoes for the next departure." if not party_slots.is_empty() else "No departure party is set."
	_rebuild_party_list(party_slots)
	_rebuild_thread_reserve(thread_reserve, reserve_cap)
	_render_echo_detail(detail_roster, str(data.get("featured_echo_id", "")))
	# V2-VOW-002: rebuild active effects chips
	_render_active_effects(data)
	# V2-SANCTUM-002: render institutions overlay + refresh detail if open
	_render_institutions(data)
	if _inst_detail_panel.visible and not _current_institution_id.is_empty():
		_refresh_institution_detail(data)

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

	# V2-ECONOMY-001: Awakening overlay — one-shot on first Sanctum entry after awakening
	if bool(data.get("show_awakening_overlay", false)):
		_awakening_grant_label.text = "+%d Ase" % int(data.get("awakening_grant", 40))
		_show_awakening_overlay()


func open_echo_detail(start_echo_id: String) -> void:
	var detail_roster := _detail_roster()
	if detail_roster.is_empty():
		return
	_echo_detail_open = true
	_detail_tab = "overview"
	_selected_echo_id = start_echo_id if _find_echo_detail_index(start_echo_id, detail_roster) != -1 else str(detail_roster[0].get("id", ""))
	detail_pages_scroll.scroll_vertical = 0
	_render()


func close_echo_detail() -> void:
	_echo_detail_open = false
	_detail_tab = "overview"
	detail_pages_scroll.scroll_vertical = 0
	_render()


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


func _render_echo_detail(detail_roster: Array, featured_echo_id: String) -> void:
	top_band.visible = not _echo_detail_open
	left_stack.visible = not _echo_detail_open
	right_stack.visible = not _echo_detail_open
	echo_detail_panel.visible = _echo_detail_open

	if not _echo_detail_open:
		return
	if detail_roster.is_empty():
		_echo_detail_open = false
		echo_detail_panel.visible = false
		left_stack.visible = true
		right_stack.visible = true
		return
	if _find_echo_detail_index(_selected_echo_id, detail_roster) == -1:
		_selected_echo_id = featured_echo_id if _find_echo_detail_index(featured_echo_id, detail_roster) != -1 else str(detail_roster[0].get("id", ""))

	var selected := _selected_echo(_selected_echo_id, detail_roster)
	detail_prev_button.disabled = detail_roster.size() <= 1
	detail_next_button.disabled = detail_roster.size() <= 1
	_apply_tab_state()

	detail_name_label.text = str(selected.get("name", "Echo"))
	var archetype_birth := _title_case(str(selected.get("archetype_birth", "")))
	detail_archetype_label.text = archetype_birth
	detail_calling_label.text = _title_case(str(selected.get("calling_origin", "Uncalled")))
	detail_vector_label.text = _vector_phrase(str(selected.get("dominant_vector", "")))
	detail_emotion_chip.setup(str(selected.get("emotional_status", "burdened")))
	var bark := str(selected.get("sanctum_bark", ""))
	detail_bark_label.visible = not bark.is_empty()
	detail_bark_label.text = "\"%s\"" % bark
	detail_standing_label.text = str(int(selected.get("standing", 1)))
	detail_step_label.text = "%d / %d" % [
		int(selected.get("step", 1)),
		int(selected.get("step_max", 5))
	]
	var storyweight_in_step := int(selected.get("storyweight_in_step", 0))
	var storyweight_per_step := maxi(1, int(selected.get("storyweight_per_step", 1)))
	detail_storyweight_label.text = "%d / %d" % [storyweight_in_step, storyweight_per_step]
	detail_storyweight_bar.max_value = storyweight_per_step
	detail_storyweight_bar.value = mini(storyweight_in_step, storyweight_per_step)
	var stats_v: Variant = selected.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}
	detail_stat_attack_value.text = str(int(stats.get("atk", 0)))
	detail_stat_defense_value.text = str(int(stats.get("def", 0)))
	detail_stat_intelligence_value.text = str(int(stats.get("int", 0)))
	detail_stat_agility_value.text = str(int(stats.get("agi", 0)))
	detail_stat_charisma_value.text = str(int(stats.get("cha", 0)))
	detail_stat_speed_value.text = str(int(stats.get("speed", 0)))
	detail_stat_max_health_value.text = str(int(stats.get("max_hp", 0)))
	if bool(selected.get("in_party", false)):
		detail_party_action_title.text = "Remove from Party"
		detail_party_action_subtitle.text = "Return this Echo from the departure."
	else:
		detail_party_action_title.text = "Assign to Party"
		detail_party_action_subtitle.text = "Add to your departure."


func _apply_tab_state() -> void:
	tab_overview.theme_type_variation = &"SanctumDrawerTabButtonActive" if _detail_tab == "overview" else &"SanctumDrawerTabButton"
	tab_bonds.theme_type_variation = &"SanctumDrawerTabButtonActive" if _detail_tab == "bonds" else &"SanctumDrawerTabButton"
	tab_skills.theme_type_variation = &"SanctumDrawerTabButtonActive" if _detail_tab == "skills" else &"SanctumDrawerTabButton"
	overview_page.visible = _detail_tab == "overview"
	bonds_page.visible = _detail_tab == "bonds"
	skills_page.visible = _detail_tab == "skills"
	detail_action_divider.visible = _detail_tab == "overview"
	detail_party_action.visible = _detail_tab == "overview"
	detail_pages_scroll.scroll_vertical = 0


func _detail_roster() -> Array:
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var roster_v: Variant = data.get("echo_detail_roster", [])
	return roster_v if roster_v is Array else []


func _selected_echo(echo_id: String, detail_roster: Array) -> Dictionary:
	var idx := _find_echo_detail_index(echo_id, detail_roster)
	if idx == -1:
		return {}
	var echo_v: Variant = detail_roster[idx]
	return echo_v if echo_v is Dictionary else {}


func _find_echo_detail_index(echo_id: String, detail_roster: Array) -> int:
	for i in range(detail_roster.size()):
		var echo_v: Variant = detail_roster[i]
		if echo_v is Dictionary and str((echo_v as Dictionary).get("id", "")) == echo_id:
			return i
	return -1


func _cycle_echo_detail(delta: int) -> void:
	var detail_roster := _detail_roster()
	if detail_roster.size() <= 1:
		return
	var current_idx := _find_echo_detail_index(_selected_echo_id, detail_roster)
	if current_idx == -1:
		current_idx = 0
	var next_idx := int(posmod(current_idx + delta, detail_roster.size()))
	_selected_echo_id = str((detail_roster[next_idx] as Dictionary).get("id", ""))
	_render()


func _title_case(value: String) -> String:
	if value.is_empty():
		return "Uncalled"
	return value.replace("_", " ").capitalize()


func _vector_phrase(vector_id: String) -> String:
	match vector_id:
		"pillar":
			return "Pillar's steadiness"
		"protector":
			return "Protector's care"
		"vanguard":
			return "Vanguard's charge"
		"seeker":
			return "Seeker's curiosity"
		"strategist":
			return "Strategist's foresight"
		"opportunist":
			return "Opportunist's timing"
		"skeptic":
			return "Skeptic's caution"
		"mediator":
			return "Mediator's accord"
		"devoted":
			return "Devoted's fidelity"
		"nurturer":
			return "Nurturer's care"
		_:
			return _title_case(vector_id)


func _on_name_edit_changed(new_text: String) -> void:
	_name_dirty = true
	confirm_button.disabled = new_text.strip_edges().is_empty()


func _on_reroll_pressed() -> void:
	action_requested.emit({"type": "sanctum.name.reroll"})


func _on_confirm_pressed() -> void:
	action_requested.emit({"type": "sanctum.name.confirm", "name": name_edit.text.strip_edges()})


func _on_detail_prev_pressed() -> void:
	_cycle_echo_detail(-1)


func _on_detail_next_pressed() -> void:
	_cycle_echo_detail(1)


func _on_tab_selected(tab_id: String) -> void:
	_detail_tab = tab_id
	_render()


func _on_detail_close_pressed() -> void:
	close_echo_detail()
	echo_detail_closed.emit()


func _on_detail_party_pressed() -> void:
	var detail_roster := _detail_roster()
	var selected := _selected_echo(_selected_echo_id, detail_roster)
	if selected.is_empty():
		return
	action_requested.emit({
		"type": "sanctum.party.toggle",
		"payload": { "echo_id": str(selected.get("id", "")) },
	})


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


# ─────────────────────────────────────────────────────────────
# V2-VOW-002: Active effects panel
# ─────────────────────────────────────────────────────────────

func _render_active_effects(data: Dictionary) -> void:
	for _ch in _effects_list.get_children():
		_ch.queue_free()
	_effect_detail.visible = false

	var effects_v: Variant = data.get("active_effects", [])
	var effects: Array = effects_v if effects_v is Array else []
	if effects.is_empty():
		_effects_panel.visible = false
		return

	for eff_v in effects:
		var eff: Dictionary = eff_v if eff_v is Dictionary else {}
		if eff.is_empty():
			continue
		_effects_list.add_child(_build_effect_chip(eff))
	_effects_panel.visible = true


func _build_effect_chip(effect: Dictionary) -> Button:
	var direction := str(effect.get("direction", "neutral"))
	var chip := Button.new()
	chip.custom_minimum_size = Vector2(72, 72)
	chip.focus_mode = Control.FOCUS_NONE
	match direction:
		"buff":
			chip.text = "▲"
			chip.add_theme_color_override("font_color", Color("#C8A96E"))  # Akan Gold
		"debuff":
			chip.text = "▼"
			chip.add_theme_color_override("font_color", Color("#E8412A"))  # Ohene Red
		_:
			chip.text = "●"
			chip.add_theme_color_override("font_color", Color("#7AB5C8"))  # Mist Blue
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	match direction:
		"buff":    style.border_color = Color("#C8A96E")
		"debuff":  style.border_color = Color("#E8412A")
		_:         style.border_color = Color("#7AB5C8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	chip.add_theme_stylebox_override("normal", style)
	chip.add_theme_stylebox_override("hover", style)
	chip.add_theme_stylebox_override("pressed", style)
	chip.pressed.connect(_toggle_effect_detail.bind(effect, chip))
	return chip


func _toggle_effect_detail(effect: Dictionary, chip: Button) -> void:
	var effect_id := str(effect.get("effect_id", ""))
	if _effect_detail.visible and str(_effect_detail.get_meta("active_effect_id", "")) == effect_id:
		_effect_detail.visible = false
		return

	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color("#3E3E58")
	detail_style.border_color = Color("#A8865A")
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(8)
	detail_style.shadow_color = Color(0, 0, 0, 0.4)
	detail_style.shadow_size = 4
	_effect_detail.add_theme_stylebox_override("panel", detail_style)

	_detail_headline.text = str(effect.get("headline", ""))
	_detail_headline.add_theme_color_override("font_color", Color("#C8A96E"))
	_detail_body.text = str(effect.get("body", ""))
	_detail_body.add_theme_color_override("font_color", Color("#E8D0A0"))
	_detail_duration.text = str(effect.get("duration_hint", ""))
	_detail_duration.add_theme_color_override("font_color", Color("#A8865A"))

	_effect_detail.set_meta("active_effect_id", effect_id)
	await get_tree().process_frame
	var chip_gpos := chip.global_position
	_effect_detail.global_position = Vector2(chip_gpos.x - _effect_detail.size.x - 8.0, chip_gpos.y)
	var vp_size := get_viewport_rect().size
	_effect_detail.global_position.x = clampf(_effect_detail.global_position.x, 0.0, vp_size.x - _effect_detail.size.x)
	_effect_detail.global_position.y = clampf(_effect_detail.global_position.y, 0.0, vp_size.y - _effect_detail.size.y)

	_effect_detail.modulate.a = 0.0
	_effect_detail.visible = true
	var tw := create_tween()
	tw.tween_property(_effect_detail, "modulate:a", 1.0, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if not _effect_detail.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_effect_detail.visible = false


# ─────────────────────────────────────────────────────────────
# V2-ECONOMY-001: Awakening overlay helpers
# ─────────────────────────────────────────────────────────────

func _apply_awakening_panel_style() -> void:
	var inner_panel := _awakening_overlay.find_child("InnerPanel", true, false)
	if inner_panel == null or not (inner_panel is PanelContainer):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3E3E58")
	style.set_corner_radius_all(8)
	(inner_panel as PanelContainer).add_theme_stylebox_override("panel", style)


func _show_awakening_overlay() -> void:
	_awakening_overlay.modulate.a = 0.0
	_awakening_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_awakening_overlay, "modulate:a", 1.0, 0.25)


func _on_awakening_dismiss_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(_awakening_overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): _awakening_overlay.visible = false)


# ─────────────────────────────────────────────────────────────
# V2-SANCTUM-002: Institution handlers
# ─────────────────────────────────────────────────────────────

# ---- Institutions overlay ----

func show_institutions_panel() -> void:
	if _institutions_overlay == null:
		return
	_institutions_overlay.visible = true
	_render_institutions(_snapshot.get("data", {}) if _snapshot.get("data", {}) is Dictionary else {})


func hide_institutions_panel() -> void:
	if _institutions_overlay == null:
		return
	_institutions_overlay.visible = false


func show_placement_bar(inst_id: String) -> void:
	if _placement_bar == null:
		return
	var display := inst_id.replace("_", " ").capitalize()
	if _placement_label != null:
		_placement_label.text = "Tap a location to place " + display
	if _placement_confirm_btn != null:
		_placement_confirm_btn.disabled = true
	_placement_bar.visible = true
	_placement_cell = null
	# Clear panels — only the economy (Ase/Ekwan) card stays visible in placement mode.
	if _header_card != null:
		_header_card.visible = false
	if left_stack != null:
		left_stack.visible = false
	if right_stack != null:
		right_stack.visible = false
	# Minimise institutions panel to compact strip — keeps context visible.
	_minimise_institutions_panel()


func _minimise_institutions_panel() -> void:
	if _institutions_overlay != null:
		_institutions_overlay.visible = false
	if _inst_compact_strip != null:
		_inst_compact_strip.visible = true
	_strip_confirm_pending = false
	_strip_confirm_timer = null


func hide_placement_bar() -> void:
	if _placement_bar != null:
		_placement_bar.visible = false
	if _placement_toast != null:
		_placement_toast.visible = false
	_toast_timer = null
	_placement_cell = null
	# Restore panels that were hidden on placement entry.
	if _header_card != null:
		_header_card.visible = true
	if left_stack != null:
		left_stack.visible = true
	if right_stack != null:
		right_stack.visible = true
	# Re-expand institutions panel so player lands back where they were.
	_expand_institutions_panel()


func _expand_institutions_panel() -> void:
	if _inst_compact_strip != null:
		_inst_compact_strip.visible = false
	_strip_confirm_pending = false
	_strip_confirm_timer = null
	if _institutions_overlay != null:
		_institutions_overlay.visible = true


func _on_inst_compact_strip_pressed() -> void:
	if _placement_cell == null:
		# No valid cell selected — exit placement immediately.
		action_requested.emit({ "type": "ui.exit_placement_mode" })
		return

	if _strip_confirm_pending:
		# Second tap within the 2s window — exit placement.
		_strip_confirm_pending = false
		_strip_confirm_timer = null
		action_requested.emit({ "type": "ui.exit_placement_mode" })
		return

	# First tap with a valid cell selected — show inline "tap again to cancel".
	_strip_confirm_pending = true
	var prev_label_text := ""
	if _placement_label != null:
		prev_label_text = _placement_label.text
		_placement_label.text = "Tap again to cancel placement"
	_strip_confirm_timer = get_tree().create_timer(2.0)
	var captured := _strip_confirm_timer
	_strip_confirm_timer.timeout.connect(func() -> void:
		if _strip_confirm_timer == captured:
			_strip_confirm_pending = false
			_strip_confirm_timer = null
			if _placement_label != null:
				_placement_label.text = "Tap Confirm to place"
	, CONNECT_ONE_SHOT)


func on_placement_cell_selected(cell: Vector2i, is_valid: bool = true, reason: String = "") -> void:
	_placement_cell = cell if is_valid else null
	if _placement_confirm_btn != null:
		_placement_confirm_btn.disabled = not is_valid
	if _placement_label != null:
		if is_valid:
			_placement_label.text = "Tap Confirm to place"
		else:
			_placement_label.text = reason if not reason.is_empty() else "Cannot place here"
	if not is_valid and not reason.is_empty():
		_show_reason_toast(reason)


func _show_reason_toast(reason: String) -> void:
	if _placement_toast == null:
		return
	_placement_toast.text = reason
	_placement_toast.visible = true
	# Cancel previous timer by dropping the reference — its timeout is ignored via null check.
	_toast_timer = null
	_toast_timer = get_tree().create_timer(2.0)
	var captured_timer := _toast_timer
	_toast_timer.timeout.connect(func() -> void:
		# Only hide if this timer is still the active one (prevents stale callbacks).
		if _toast_timer == captured_timer:
			if _placement_toast != null:
				_placement_toast.visible = false
			_toast_timer = null
	, CONNECT_ONE_SHOT)


func open_institution_detail(institution_id: String) -> void:
	if institution_id == "ase_flame":
		show_institutions_panel()
		return
	_current_institution_id = institution_id
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	_refresh_institution_detail(data)
	_inst_detail_panel.visible = true
	_assign_picker.visible = false


func _render_institutions(data: Dictionary) -> void:
	if _inst_list == null or not _institutions_overlay.visible:
		return
	var actions_v: Variant = _snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var institutions_v: Variant = data.get("institutions", [])
	var institutions: Array = institutions_v if institutions_v is Array else []
	var ekwan_balance := int(data.get("ekwan_balance", 0))

	# Clear existing dynamic rows and reset alternating index.
	for child in _inst_list.get_children():
		child.queue_free()
	_inst_row_index = 0

	# Ase Flame row (always first, no action button)
	_inst_list.add_child(_build_inst_row_label("Ase Flame", "Spiritual anchor", "Always active", false))

	for inst_v in institutions:
		if not (inst_v is Dictionary):
			continue
		var inst: Dictionary = inst_v
		var inst_id      := str(inst.get("id", ""))
		var is_unlocked  := bool(inst.get("is_unlocked", false))
		var is_candidate := bool(inst.get("is_candidate", false))
		var condition    := str(inst.get("condition", "neglected"))
		var display      := inst_id.replace("_", " ").capitalize()
		var identity     := str(_INSTITUTION_IDENTITY.get(inst_id, ""))

		if is_unlocked:
			var panel := _build_inst_row_label(display, identity, condition.capitalize(), true)
			var inner_row: HBoxContainer = panel.get_meta("inner_row")
			var btn := Button.new()
			btn.text = "Manage"
			btn.theme_type_variation = &"SanctumTertiaryButton"
			btn.pressed.connect(open_institution_detail.bind(inst_id))
			inner_row.add_child(btn)
			_inst_list.add_child(panel)
		elif is_candidate:
			var slot_key := "cta.establish." + inst_id
			var action_v: Variant = actions.get(slot_key, {})
			var action: Dictionary = action_v if action_v is Dictionary else {}
			var cost := int(action.get("payload", {}).get("establish_ekwan_cost", 0)) if not action.is_empty() else 0
			var can_afford := ekwan_balance >= cost if cost > 0 else true
			var cost_str := ("%d Ekwan" % cost) if cost > 0 else ""
			var panel := _build_inst_row_label(display, identity, cost_str, true)
			var inner_row: HBoxContainer = panel.get_meta("inner_row")
			var btn := Button.new()
			btn.text = "Establish"
			btn.theme_type_variation = &"SanctumTertiaryButton"
			btn.disabled = not can_afford
			if not btn.disabled:
				btn.pressed.connect(_on_inst_overlay_establish_pressed.bind(inst_id))
			inner_row.add_child(btn)
			_inst_list.add_child(panel)
		else:
			# Threshold not met — disabled row with lock icon
			var panel := _build_inst_row_label(display, identity, "", false)
			var inner_row: HBoxContainer = panel.get_meta("inner_row")
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.theme_type_variation = &"SanctumMuted"
			inner_row.add_child(lock_lbl)
			_inst_list.add_child(panel)


var _inst_row_index := 0

func _build_inst_row_label(title: String, subtitle: String, detail: String, enabled: bool) -> PanelContainer:
	# Alternate between SanctumDrawerRow and SanctumDrawerRowAlt for two-tone readability.
	var variation: StringName = &"SanctumDrawerRow" if (_inst_row_index % 2 == 0) else &"SanctumDrawerRowAlt"
	_inst_row_index += 1

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = variation

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.theme_type_variation = &"ContentBasePanel"
	vbox.add_child(title_lbl)

	if not subtitle.is_empty():
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.theme_type_variation = &"SanctumDrawerMeta"
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(sub_lbl)

	if not detail.is_empty():
		var det_lbl := Label.new()
		det_lbl.text = detail
		det_lbl.theme_type_variation = &"SanctumMuted"
		vbox.add_child(det_lbl)

	if not enabled:
		panel.modulate = Color(1.0, 1.0, 1.0, 0.5)

	# Return the panel as the root; callers add buttons via row.add_child().
	# We expose the inner row via metadata so callers can append action buttons.
	panel.set_meta("inner_row", row)
	return panel


func _on_inst_overlay_establish_pressed(inst_id: String) -> void:
	_current_institution_id = inst_id
	# Forward placement context arrays from snapshot data to SanctumShell via action.
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var cells_v: Variant = data.get("valid_placement_cells", [])
	var floor_v: Variant = data.get("placement_floor_cells", [])
	var occ_v: Variant   = data.get("placement_occupied_cells", [])
	action_requested.emit({
		"type":    "ui.enter_placement_mode",
		"payload": {
			"institution_id": inst_id,
			"valid_cells":    cells_v,
			"floor_cells":    floor_v,
			"occupied_cells": occ_v,
		},
	})


func _on_placement_confirmed() -> void:
	if _current_institution_id.is_empty() or _placement_cell == null:
		return
	var cell: Vector2i = _placement_cell
	action_requested.emit({
		"type":    "sanctum.institution.establish",
		"payload": {
			"institution_id": _current_institution_id,
			"position":       { "x": cell.x, "y": cell.y },
		},
	})
	action_requested.emit({ "type": "ui.exit_placement_mode" })


func _on_placement_cancelled() -> void:
	action_requested.emit({ "type": "ui.exit_placement_mode" })


const _INSTITUTION_IDENTITY: Dictionary = {
	"hearth":           "Care & Belonging",
	"training_grounds": "Readiness & Discipline",
}


func _on_ground_institution_selected(institution_id: String) -> void:
	open_institution_detail(institution_id)


func _on_ground_echo_selected(echo_id: String) -> void:
	open_echo_detail(echo_id)


func _on_inst_detail_back_pressed() -> void:
	_inst_detail_panel.visible = false
	_assign_picker.visible = false
	_current_institution_id = ""


func _on_inst_assign_pressed() -> void:
	if _current_institution_id.is_empty():
		return
	var data_v: Variant = _snapshot.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	_populate_assign_picker(data)
	_assign_picker.visible = true


func _on_inst_establish_pressed() -> void:
	if _current_institution_id.is_empty():
		return
	var actions_v: Variant = _snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var slot_key := "cta.establish." + _current_institution_id
	var action_v: Variant = actions.get(slot_key, {})
	if not (action_v is Dictionary) or (action_v as Dictionary).is_empty():
		return
	action_requested.emit(action_v as Dictionary)


func _on_picker_cancel_pressed() -> void:
	_assign_picker.visible = false


func _on_inst_establish_btn_from_picker(echo_id: String) -> void:
	if _current_institution_id.is_empty():
		return
	action_requested.emit({
		"type":    "sanctum.institution.assign_echo",
		"payload": { "institution_id": _current_institution_id, "echo_id": echo_id },
	})
	_assign_picker.visible = false


const _INSTITUTION_CONDITION_COLORS: Dictionary = {
	"healthy":  Color("#D4AF37"),  # Akan Gold
	"strained": Color("#C87941"),  # Amber
	"neglected": Color("#5A5A6A"), # Grey
}
const _INSTITUTION_CONDITION_PHRASES: Dictionary = {
	"healthy":  "Thriving",
	"strained": "Under strain",
	"neglected": "Neglected",
}
const _INSTITUTION_PASSIVE_EFFECT: Dictionary = {
	"hearth":           "All echoes in the Sanctum recover +2 morale per hour",
	"training_grounds": "All echoes in the Sanctum gain +1 storyweight per hour",
}


func _refresh_institution_detail(data: Dictionary) -> void:
	var institutions_v: Variant = data.get("institutions", [])
	var institutions: Array = institutions_v if institutions_v is Array else []
	var inst_data: Dictionary = {}
	for entry_v in institutions:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("id", "")) == _current_institution_id:
			inst_data = entry
			break
	if inst_data.is_empty():
		return

	var display_name := _current_institution_id.replace("_", " ").capitalize()
	_inst_detail_name.text = display_name

	# Social identity label (V2 language)
	var identity := str(_INSTITUTION_IDENTITY.get(_current_institution_id, ""))

	var condition := str(inst_data.get("condition", "neglected"))
	var cond_phrase := str(_INSTITUTION_CONDITION_PHRASES.get(condition, condition.capitalize()))
	var cond_color: Color = _INSTITUTION_CONDITION_COLORS.get(condition, Color.WHITE)
	_inst_detail_condition.text = ("%s — %s" % [identity, cond_phrase]) if not identity.is_empty() else cond_phrase
	_inst_detail_condition.modulate = cond_color

	# Passive effect description (V2 language)
	var passive_effect := str(_INSTITUTION_PASSIVE_EFFECT.get(_current_institution_id, ""))

	# Occupant rows (also shows morale tier dot per echo)
	for child in _inst_occupant_list.get_children():
		if child == _occupant_row_template:
			continue
		child.queue_free()
	var detail_roster_v: Variant = data.get("echo_detail_roster", [])
	var detail_roster: Array = detail_roster_v if detail_roster_v is Array else []
	for oid_v in (inst_data.get("occupant_ids", []) as Array):
		var oid := str(oid_v)
		var echo_name := oid
		var echo_morale_tier := "steady"
		for er_v in detail_roster:
			if not (er_v is Dictionary):
				continue
			var er: Dictionary = er_v
			if str(er.get("id", "")) == oid:
				echo_name = str(er.get("name", oid))
				var emo_v: Variant = er.get("emotion", {})
				if emo_v is Dictionary:
					var morale_current := int((emo_v as Dictionary).get("morale_current", 50))
					echo_morale_tier = EmotionService.get_morale_tier(morale_current)
				break
		var row := _occupant_row_template.duplicate() as HBoxContainer
		row.visible = true
		var name_label := row.find_child("OccupantName", true, false)
		if name_label is Label:
			(name_label as Label).text = echo_name
		# Morale tier indicator dot (modulate the row to reflect emotion state)
		var dot_color := SanctumOccupantLayer._fill_for_morale_tier(echo_morale_tier)
		var dot_lbl := Label.new()
		dot_lbl.text = "●"
		dot_lbl.modulate = dot_color
		row.add_child(dot_lbl)
		row.move_child(dot_lbl, 0)
		var remove_btn := row.find_child("OccupantRemoveButton", true, false)
		if remove_btn is Button:
			(remove_btn as Button).pressed.connect(_on_occupant_remove_pressed.bind(oid))
		_inst_occupant_list.add_child(row)

	# Show/hide buttons
	var is_unlocked := bool(inst_data.get("unlocked", false))
	var is_candidate := bool(inst_data.get("is_candidate", false))
	var occupant_count := (inst_data.get("occupant_ids", []) as Array).size()
	var capacity := 4  # default; actual is in config
	_inst_assign_btn.visible   = is_unlocked and occupant_count < capacity
	_inst_establish_btn.visible = is_candidate and not is_unlocked
	# Disable establish if insufficient Ekwan (the action slot carries disabled flag)
	var actions_v: Variant = _snapshot.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var slot_key := "cta.establish." + _current_institution_id
	var action_dict_v: Variant = actions.get(slot_key, {})
	if action_dict_v is Dictionary and not (action_dict_v as Dictionary).is_empty():
		_inst_establish_btn.disabled = bool((action_dict_v as Dictionary).get("disabled", false))
		_inst_establish_btn.text = "Establish (%d Ekwan)" % int(
			((action_dict_v as Dictionary).get("payload", {}) as Dictionary).get("establish_ekwan_cost", 10))


func _populate_assign_picker(data: Dictionary) -> void:
	for child in _picker_list.get_children():
		if child == _picker_row_template:
			continue
		child.queue_free()

	var detail_roster_v: Variant = data.get("echo_detail_roster", [])
	var detail_roster: Array = detail_roster_v if detail_roster_v is Array else []
	var compat_hints_v: Variant = data.get("institution_compat_hints", {})
	var compat_hints: Dictionary = compat_hints_v if compat_hints_v is Dictionary else {}
	var inst_hints: Dictionary = compat_hints.get(_current_institution_id, {}) as Dictionary

	# Exclude echoes already assigned to any institution
	var institutions_v: Variant = data.get("institutions", [])
	var institutions: Array = institutions_v if institutions_v is Array else []
	var assigned_ids: Array = []
	for entry_v in institutions:
		if not (entry_v is Dictionary):
			continue
		for oid in ((entry_v as Dictionary).get("occupant_ids", []) as Array):
			assigned_ids.append(str(oid))

	for echo_v in detail_roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var eid := str(echo.get("id", ""))
		if eid.is_empty() or assigned_ids.has(eid):
			continue
		var ename := str(echo.get("name", "Echo"))
		var hint := str(inst_hints.get(eid, ""))
		var row := _picker_row_template.duplicate() as Button
		row.visible = true
		row.text = ename + ("\n" + hint if not hint.is_empty() else "")
		row.pressed.connect(_on_inst_establish_btn_from_picker.bind(eid))
		_picker_list.add_child(row)


func _on_occupant_remove_pressed(echo_id: String) -> void:
	action_requested.emit({
		"type":    "sanctum.institution.remove_echo",
		"payload": { "institution_id": _current_institution_id, "echo_id": echo_id },
	})
