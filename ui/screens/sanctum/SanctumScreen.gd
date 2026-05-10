extends Control

class_name SanctumScreen

signal action_requested(action: Dictionary)
signal echo_detail_closed

const ThreadSlotItemScene: PackedScene = preload("res://ui/components/ThreadSlotItem.tscn")
const EmotionChipScene: PackedScene = preload("res://ui/components/EmotionChip.tscn")

@onready var title_label: Label = %TitleLabel
@onready var vow_mantra_label: Label = %VowMantraLabel
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
@onready var echo_count_label : Label = %EchoCountLabel

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


var _snapshot: Dictionary = {}
var _name_dirty := false
var _last_ase_balance: int = -1
var _ase_tween: Tween
var _echo_detail_open := false
var _detail_tab := "overview"
var _selected_echo_id := ""
# V2-VOW-002: compliance count label under mantra (created in _ready, positioned after vow_mantra_label).
var _vow_compliance_label: Label = null

# V2-VOW-002: ST-E — compliance count label (lazily created, positioned below VowMantraLabel)
var _vow_compliance_lbl: Label = null
# V2-VOW-002: ST-H — currently open chip Button (for toggle-close detection)
var _active_chip_effect_id: String = ""



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
	detail_party_action_button.pressed.connect(_on_detail_party_pressed)	_awakening_dismiss.pressed.connect(_on_awakening_dismiss_pressed)
	_apply_awakening_panel_style()


	# V2-VOW-002: compliance count label — sibling of vow_mantra_label in HeaderStack.
	_vow_compliance_label = Label.new()
	_vow_compliance_label.add_theme_font_size_override("font_size", 12)
	_vow_compliance_label.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
	_vow_compliance_label.visible = false
	var _header_stack: VBoxContainer = vow_mantra_label.get_parent() as VBoxContainer
	if _header_stack != null:
		_header_stack.add_child(_vow_compliance_label)
		_header_stack.move_child(_vow_compliance_label, vow_mantra_label.get_index() + 1)


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
		if _vow_compliance_label != null:
			var cc := int(active_vow.get("compliance_count", 0))
			if cc > 0:
				_vow_compliance_label.text = "%d stage%s honored" % [cc, "s" if cc != 1 else ""]
				_vow_compliance_label.visible = true
			else:
				_vow_compliance_label.visible = false
	else:
		vow_mantra_label.visible = false
		if _vow_compliance_label != null:
			_vow_compliance_label.visible = false

	ase_label.text = str(ase_balance)
	ase_rate_label.text = "~ %.1f per hour" % per_hour

	party_summary_label.text = "Chosen echoes for the next departure." if not party_slots.is_empty() else "No departure party is set."
	_rebuild_party_list(party_slots)
	_rebuild_thread_reserve(thread_reserve, reserve_cap)
	_render_echo_detail(detail_roster, str(data.get("featured_echo_id", "")))
	# V2-VOW-002: rebuild active effects chips
	_render_active_effects(data)

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
# ─────────────────────────────────────────────────────────────
# V2-VOW-002 ST-H: Active Effects Panel helpers
# ─────────────────────────────────────────────────────────────

## Builds a 72×72 Ghost-style chip Button for one active effect entry.
## Symbol-only: ▲ (buff / Akan Gold) | ▼ (debuff / Ohene Red) | ● (neutral / Mist Blue).
## TODO: replace symbol Text with 24×24 TextureRect icon once assets delivered (Jeff).
func _build_effect_chip(effect: Dictionary) -> Button:
	var direction := str(effect.get("direction", "neutral"))
	var effect_id := str(effect.get("effect_id", ""))

	# Direction → symbol + color
	var symbol: String
	var chip_color: Color
	match direction:
		"buff":
			symbol     = "▲"
			chip_color = Color("#C8A96E")  # Akan Gold
		"debuff":
			symbol     = "▼"
			chip_color = Color("#E8412A")  # Ohene Red
		_:
			symbol     = "●"
			chip_color = Color("#7AB5C8")  # Mist Blue (The Loom accent / neutral)

	var btn := Button.new()
	btn.text = symbol
	btn.custom_minimum_size = Vector2(72, 72)
	btn.add_theme_color_override("font_color", chip_color)
	btn.add_theme_font_size_override("font_size", 20)

	# Ghost style: transparent background, direction-coloured 1px border, corner_radius=8
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0, 0, 0, 0)
	chip_style.border_color = chip_color
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", chip_style)
	btn.add_theme_stylebox_override("hover",  chip_style)
	btn.add_theme_stylebox_override("pressed", chip_style)

	btn.set_meta("effect_id", effect_id)
	btn.pressed.connect(_toggle_effect_detail.bind(effect, btn))
	return btn


## Toggles the EffectDetailPanel popout for the tapped chip.
## Opens to the left of the chip; fades in over 250ms. Tap same chip → closes.
func _toggle_effect_detail(effect: Dictionary, chip: Button) -> void:
	var effect_id := str(effect.get("effect_id", ""))

	# Toggle: if already showing this effect's detail, close it.
	if _effect_detail.visible and _active_chip_effect_id == effect_id:
		_effect_detail.visible = false
		_active_chip_effect_id = ""
		return

	# Apply Ash Smoke panel style (elevated surface, matches modal depth)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color     = Color("#3E3E58")  # Ash Smoke
	detail_style.border_color = Color("#A8865A")  # Warm Brass
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(8)
	detail_style.shadow_color = Color(0, 0, 0, 0.4)
	detail_style.shadow_size  = 4
	_effect_detail.add_theme_stylebox_override("panel", detail_style)

	# Populate labels
	_detail_headline.text = str(effect.get("headline", ""))
	_detail_body.text     = str(effect.get("body",     ""))
	_detail_duration.text = str(effect.get("duration_hint", ""))

	# Position: open to the left of the chip, or fall back near chip
	_effect_detail.visible    = false
	_effect_detail.modulate.a = 0.0
	_effect_detail.visible    = true
	await get_tree().process_frame  # let Godot compute panel size
	var chip_gpos := chip.global_position
	var panel_w   := _effect_detail.size.x
	_effect_detail.global_position = Vector2(
		chip_gpos.x - panel_w - 8.0,
		chip_gpos.y
	)

	_active_chip_effect_id = effect_id

	# 250ms fade-in (matches screen swap budget)
	var tw := create_tween()
	tw.tween_property(_effect_detail, "modulate:a", 1.0, 0.25)


## Applies Dusk Slate + Warm Brass border panel style to the effects panel.
## Called each render to keep styling in sync (no .tscn StyleBoxFlat dependency).
func _apply_panel_style(panel: PanelContainer) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color("#2D2D44")  # Dusk Slate
	panel_style.border_color = Color("#A8865A")  # Warm Brass
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)


## Closes the EffectDetailPanel on any click/tap outside of it.
func _unhandled_input(event: InputEvent) -> void:
	if not _effect_detail.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# Close if tap lands outside the panel rect
		var panel_rect := _effect_detail.get_global_rect()
		if not panel_rect.has_point((event as InputEventMouseButton).global_position):
			_effect_detail.visible = false
			_active_chip_effect_id = ""
			get_viewport().set_input_as_handled()



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
	# Clear previous chips.
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
	# Symbol per direction (TODO: replace with 24×24 TextureRect icon once assets delivered — Jeff)
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
	# Ghost style — transparent bg, direction-coloured border
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
	# Toggle off if same chip tapped again.
	if _effect_detail.visible and str(_effect_detail.get_meta("active_effect_id", "")) == effect_id:
		_effect_detail.visible = false
		return

	# Apply elevated surface style.
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color("#3E3E58")
	detail_style.border_color = Color("#A8865A")
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(8)
	detail_style.shadow_color = Color(0, 0, 0, 0.4)
	detail_style.shadow_size = 4
	_effect_detail.add_theme_stylebox_override("panel", detail_style)

	# Populate content.
	_detail_headline.text = str(effect.get("headline", ""))
	_detail_headline.add_theme_color_override("font_color", Color("#C8A96E"))
	_detail_body.text = str(effect.get("body", ""))
	_detail_body.add_theme_color_override("font_color", Color("#E8D0A0"))
	_detail_duration.text = str(effect.get("duration_hint", ""))
	_detail_duration.add_theme_color_override("font_color", Color("#A8865A"))

	_effect_detail.set_meta("active_effect_id", effect_id)
	# Position: to the left of the chip, flush with the right sidebar edge.
	await get_tree().process_frame  # ensure size is known
	var chip_gpos := chip.global_position
	_effect_detail.global_position = Vector2(chip_gpos.x - _effect_detail.size.x - 8.0, chip_gpos.y)
	# Clamp to screen bounds
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
	

