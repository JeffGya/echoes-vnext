extends Control

signal action_requested(action: Dictionary)

const _RANK_UP_OVERLAY_SCENE: PackedScene = preload("res://ui/overlays/RankUpOverlay.tscn")

@onready var echo_count_label: Label = %EchoCountLabel
@onready var party_count_label: Label = %PartyCountLabel
@onready var back_button: Button = %BackButton

@onready var echo_rows: VBoxContainer = %EchoRows
@onready var echo_row_template: HBoxContainer = %EchoRowTemplate

# Detail panel
@onready var detail_panel: Control = %DetailPanel
@onready var detail_name_label: Label = %DetailName
@onready var detail_shout_label: Label = %DetailShout
@onready var detail_hp_bar: ProgressBar = %DetailHPBar
@onready var detail_hp_label: Label = %DetailHPLabel
@onready var detail_calling_label: Label = %DetailCalling
@onready var detail_rank_label: Label = %DetailRank
@onready var detail_grade_label: Label = %DetailGrade
@onready var detail_level_label: Label = %DetailLevel
@onready var detail_xp_bar: ProgressBar = %DetailXPBar
@onready var detail_xp_label: Label = %DetailXPLabel
@onready var detail_archetype_label: Label = %DetailArchetype
@onready var stat_attack_value: Label = %StatAttackValue
@onready var stat_defense_value: Label = %StatDefenseValue
@onready var stat_intelligence_value: Label = %StatIntelligenceValue
@onready var stat_agility_value: Label = %StatAgilityValue
@onready var stat_charisma_value: Label = %StatCharismaValue
@onready var stat_speed_value: Label = %StatSpeedValue
@onready var detail_emotion_status: Label = %DetailEmotionStatus
@onready var detail_morale_bar: ProgressBar = %DetailMoraleBar
@onready var detail_fear_bar: ProgressBar = %DetailFearBar
@onready var detail_assign_party_btn: Button = %AssignPartyBtn
@onready var detail_assign_job_btn: Button = %AssignJobBtn
@onready var dominant_vector_label: Label = %DominantVectorLabel
@onready var calling_eligible_badge: Button = %CallingEligibleBadge
@onready var ascend_button: Button = %AscendButton
@onready var skills_tab_content: VBoxContainer = %SkillsTabContent
@onready var skill_slot_row2: HBoxContainer = %SkillSlotRow2
@onready var skill_slot_value1: Label = %SkillSlotValue1
@onready var skill_slot_value2: Label = %SkillSlotValue2
@onready var tab_base: Button = %TabBase
@onready var tab_skills: Button = %TabSkills
@onready var calling_info_btn: Button = %CallingInfoBtn
@onready var calling_info_overlay: Control = %CallingInfoOverlay
@onready var calling_info_title: Label = %CallingInfoTitle
@onready var calling_info_desc: Label = %CallingInfoDesc
@onready var calling_info_close_btn: Button = %CallingInfoCloseBtn

@onready var party_cards: VBoxContainer = %PartyCards
@onready var party_card_template: PanelContainer = %PartyCardTemplate

var _snap: Dictionary = {}
var _action_back: Dictionary = {}
var _echoes: Array = []
var _selected_echo_id: String = ""
var _max_party_size: int = 5
var _rank_up_overlay: RankUpOverlay = null


func _ready() -> void:
	detail_panel.visible = false
	calling_info_overlay.visible = false

	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not detail_assign_party_btn.pressed.is_connected(_on_assign_party_pressed):
		detail_assign_party_btn.pressed.connect(_on_assign_party_pressed)

	detail_assign_job_btn.disabled = true

	if not ascend_button.pressed.is_connected(_on_ascend_pressed):
		ascend_button.pressed.connect(_on_ascend_pressed)
	if not calling_eligible_badge.pressed.is_connected(_on_path_awaits_pressed):
		calling_eligible_badge.pressed.connect(_on_path_awaits_pressed)
	if not tab_base.pressed.is_connected(_on_tab_base_pressed):
		tab_base.pressed.connect(_on_tab_base_pressed)
	if not tab_skills.pressed.is_connected(_on_tab_skills_pressed):
		tab_skills.pressed.connect(_on_tab_skills_pressed)
	if not calling_info_btn.pressed.is_connected(_on_calling_info_pressed):
		calling_info_btn.pressed.connect(_on_calling_info_pressed)
	if not calling_info_close_btn.pressed.is_connected(_on_calling_info_close_pressed):
		calling_info_close_btn.pressed.connect(_on_calling_info_close_pressed)

	_rank_up_overlay = _RANK_UP_OVERLAY_SCENE.instantiate() as RankUpOverlay
	add_child(_rank_up_overlay)
	_rank_up_overlay.confirm_requested.connect(_on_rank_up_confirm_requested)
	_rank_up_overlay.dismissed.connect(_on_rank_up_dismissed)
	_rank_up_overlay.calling_confirm_requested.connect(_on_calling_confirm_requested)


func set_snapshot(snap: Dictionary) -> void:
	_snap = snap
	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}

	_echoes = data.get("echoes", []) if data.get("echoes") is Array else []
	_max_party_size = int(data.get("max_party_size", 5))

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}

	var party_count := 0
	for e_v in _echoes:
		if e_v is Dictionary and bool((e_v as Dictionary).get("in_party", false)):
			party_count += 1
	echo_count_label.text = "Echoes: %d" % _echoes.size()
	party_count_label.text = "Party: %d/%d" % [party_count, _max_party_size]

	if _echo_by_id(_selected_echo_id).is_empty() and not _echoes.is_empty():
		var first_v: Variant = _echoes[0]
		if first_v is Dictionary:
			_selected_echo_id = str((first_v as Dictionary).get("id", ""))

	_rebuild_echo_list()
	_rebuild_party_cards()

	var selected := _echo_by_id(_selected_echo_id)
	if selected.is_empty():
		detail_panel.visible = false
	else:
		detail_panel.visible = true
		_render_detail(selected)

	var rank_up_event_v: Variant = data.get("rank_up_event", null)
	if rank_up_event_v is Dictionary and not (rank_up_event_v as Dictionary).is_empty():
		if _rank_up_overlay != null:
			_rank_up_overlay.show_reveal(rank_up_event_v as Dictionary)


func _rebuild_echo_list() -> void:
	for c in echo_rows.get_children():
		c.queue_free()

	for e_v in _echoes:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v
		var row := echo_row_template.duplicate() as HBoxContainer
		row.visible = true

		var echo_id: String = str(e.get("id", ""))
		var name_lbl := _row_node(row, "NameLabel") as Label
		name_lbl.text = str(e.get("name", "Unknown"))

		var calling_lbl := _row_node(row, "CallingLabel") as Label
		calling_lbl.text = _calling_label(e)

		var rank_lbl := _row_node(row, "RankLabel") as Label
		rank_lbl.text = "R%d" % int(e.get("rank", 1))

		var level_lbl := _row_node(row, "LevelLabel") as Label
		level_lbl.text = "Lv %d" % int(e.get("level", 1))

		var party_badge := _row_node(row, "PartyBadge") as Label
		party_badge.visible = bool(e.get("in_party", false))

		var select_btn := _row_node(row, "SelectButton") as Button
		select_btn.pressed.connect(_on_echo_selected.bind(echo_id))

		row.modulate = Color(1.0, 0.9, 0.65) if echo_id == _selected_echo_id else Color(1, 1, 1)
		echo_rows.add_child(row)


func _rebuild_party_cards() -> void:
	for c in party_cards.get_children():
		c.queue_free()

	for e_v in _echoes:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v
		if not bool(e.get("in_party", false)):
			continue

		var card := party_card_template.duplicate() as PanelContainer
		card.visible = true
		var echo_id: String = str(e.get("id", ""))

		var name_lbl := _card_node(card, "CardNameLabel") as Label
		name_lbl.text = str(e.get("name", "Unknown"))

		var calling_lbl := _card_node(card, "CardCallingLabel") as Label
		calling_lbl.text = _calling_label(e)

		var archetype_lbl := _card_node(card, "CardArchetypeLabel") as Label
		archetype_lbl.text = str(e.get("archetype", "")).capitalize()

		var vector_lbl := _card_node(card, "CardVectorLabel") as Label
		vector_lbl.text = _vector_label(str(e.get("dominant_vector", "")))

		var select_btn := _card_node(card, "CardSelectButton") as Button
		select_btn.pressed.connect(_on_echo_selected.bind(echo_id))

		card.modulate = Color(1.0, 0.9, 0.65) if echo_id == _selected_echo_id else Color(1, 1, 1)
		party_cards.add_child(card)


func _on_echo_selected(echo_id: String) -> void:
	_selected_echo_id = echo_id
	var selected := _echo_by_id(echo_id)
	if selected.is_empty():
		detail_panel.visible = false
		return
	detail_panel.visible = true
	_render_detail(selected)
	_rebuild_echo_list()
	_rebuild_party_cards()


func _render_detail(e: Dictionary) -> void:
	var name_str := str(e.get("name", ""))
	var rank := int(e.get("rank", 1))
	var rarity := str(e.get("rarity", "uncalled"))
	var level := int(e.get("level", 1))
	var xp_to_next := int(e.get("xp_to_next", 0))
	var archetype := str(e.get("archetype", ""))
	var hp_max := int(e.get("hp_max", 0))
	var morale := int(e.get("morale", 50))
	var fear := int(e.get("fear", 0))
	var status := str(e.get("morale_status", "Normal"))
	var in_party := bool(e.get("in_party", false))
	var shout := str(e.get("current_shout", ""))
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	detail_name_label.text = name_str
	detail_shout_label.text = shout
	detail_shout_label.visible = not shout.is_empty()

	detail_hp_bar.max_value = maxi(1, hp_max)
	detail_hp_bar.value = hp_max
	detail_hp_label.text = "HP %d/%d" % [hp_max, hp_max]

	detail_rank_label.text = "Rank %d" % rank
	detail_grade_label.text = rarity.capitalize()
	detail_level_label.text = "Level %d" % level

	var dominant_vector: String = str(e.get("dominant_vector", ""))
	var calling_eligible: bool = bool(e.get("calling_eligible", false))
	var rank_up_eligible: bool = bool(e.get("rank_up_eligible", false))

	dominant_vector_label.visible = not dominant_vector.is_empty()
	if not dominant_vector.is_empty():
		dominant_vector_label.text = _vector_label(dominant_vector)

	var confirmed_calling: String = str(e.get("calling", ""))
	var calling_description: String = str(e.get("calling_description", ""))
	if not confirmed_calling.is_empty():
		detail_calling_label.visible = true
		detail_calling_label.text = confirmed_calling.capitalize()
		calling_info_btn.visible = not calling_description.is_empty()
		calling_eligible_badge.visible = false
	elif calling_eligible:
		detail_calling_label.visible = true
		detail_calling_label.text = "Calling Undecided"
		calling_info_btn.visible = false
		calling_eligible_badge.visible = true
		calling_eligible_badge.text = "⚡ Path Awaits"
	else:
		detail_calling_label.visible = false
		calling_info_btn.visible = false
		calling_eligible_badge.visible = false

	ascend_button.visible = rank_up_eligible
	if rank_up_eligible:
		ascend_button.text = "▲ Ascend to Rank %d" % (rank + 1)

	var xp_in_level: int = int(e.get("xp_in_level", 0))
	var xp_per_level: int = int(e.get("xp_per_level", 100))
	if xp_to_next > 0:
		detail_xp_bar.max_value = maxi(1, xp_per_level)
		detail_xp_bar.value = xp_in_level
		detail_xp_label.text = "XP %d/%d" % [xp_in_level, xp_per_level]
	else:
		detail_xp_bar.max_value = 1
		detail_xp_bar.value = 1
		detail_xp_label.text = "XP MAX"

	detail_archetype_label.text = archetype.capitalize()

	stat_attack_value.text = str(int(stats.get("atk", 0)))
	stat_defense_value.text = str(int(stats.get("def", 0)))
	stat_intelligence_value.text = str(int(stats.get("int", 0)))
	stat_agility_value.text = str(int(stats.get("agi", 0)))
	stat_charisma_value.text = str(int(stats.get("cha", 0)))
	stat_speed_value.text = str(int(stats.get("speed", 0)))

	detail_emotion_status.text = status
	detail_morale_bar.max_value = 100
	detail_morale_bar.value = morale
	detail_fear_bar.max_value = 100
	detail_fear_bar.value = fear

	detail_assign_party_btn.text = "Remove from party" if in_party else "Assign to party"

	var calling_confirmed: bool = not str(e.get("calling", "")).is_empty()
	tab_skills.disabled = not calling_confirmed
	skills_tab_content.visible = false
	tab_base.theme_type_variation = "ButtonPrimary"
	tab_skills.theme_type_variation = "ButtonSecondary"

	var skill_slots_v: Variant = e.get("skill_slots", [])
	var skill_slots: Array = skill_slots_v if skill_slots_v is Array else []
	skill_slot_value1.text = skill_slots[0] if skill_slots.size() >= 1 and not str(skill_slots[0]).is_empty() else "\u2014"
	var has_slot2: bool = skill_slots.size() >= 2
	skill_slot_row2.visible = has_slot2
	if has_slot2:
		skill_slot_value2.text = "\u2014" if str(skill_slots[1]).is_empty() else str(skill_slots[1])


func _on_back_pressed() -> void:
	if not _action_back.is_empty():
		action_requested.emit(_action_back)


func _on_assign_party_pressed() -> void:
	var selected := _echo_by_id(_selected_echo_id)
	if selected.is_empty():
		return
	action_requested.emit({
		"type": "sanctum.party.toggle",
		"payload": { "echo_id": str(selected.get("id", "")) },
	})


func _on_ascend_pressed() -> void:
	var selected := _echo_by_id(_selected_echo_id)
	if selected.is_empty() or _rank_up_overlay == null:
		return
	_rank_up_overlay.show_confirm(selected)


func _on_rank_up_confirm_requested(echo_id: String) -> void:
	action_requested.emit({
		"type": "sanctum.rank_up",
		"payload": { "echo_id": echo_id },
	})


func _on_rank_up_dismissed() -> void:
	pass


func _on_path_awaits_pressed() -> void:
	var selected := _echo_by_id(_selected_echo_id)
	if selected.is_empty() or _rank_up_overlay == null:
		return
	var options_v: Variant = selected.get("calling_options", [])
	var options: Array = options_v if options_v is Array else []
	if options.is_empty():
		return
	_rank_up_overlay.show_calling(str(selected.get("id", "")), options)


func _on_calling_confirm_requested(echo_id: String, chosen_calling_id: String) -> void:
	action_requested.emit({
		"type": "sanctum.calling.confirm",
		"payload": { "echo_id": echo_id, "chosen_calling_id": chosen_calling_id },
	})


func _on_tab_base_pressed() -> void:
	skills_tab_content.visible = false
	tab_base.theme_type_variation = "ButtonPrimary"
	tab_skills.theme_type_variation = "ButtonSecondary"


func _on_tab_skills_pressed() -> void:
	if tab_skills.disabled:
		return
	skills_tab_content.visible = true
	tab_base.theme_type_variation = "ButtonSecondary"
	tab_skills.theme_type_variation = "ButtonPrimary"


func _on_calling_info_pressed() -> void:
	var selected := _echo_by_id(_selected_echo_id)
	if selected.is_empty():
		return
	calling_info_title.text = str(selected.get("calling", "")).capitalize()
	calling_info_desc.text = str(selected.get("calling_description", ""))
	calling_info_overlay.visible = true


func _on_calling_info_close_pressed() -> void:
	calling_info_overlay.visible = false


func _echo_by_id(echo_id: String) -> Dictionary:
	if echo_id.is_empty():
		return {}
	for e_v in _echoes:
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == echo_id:
			return e_v as Dictionary
	return {}


func _row_node(row: Node, node_name: String) -> Node:
	var found := row.find_child(node_name, true, false)
	assert(found != null, "EchoPartyScreen: row template missing node '%s'" % node_name)
	return found


func _card_node(card: Node, node_name: String) -> Node:
	var found := card.find_child(node_name, true, false)
	assert(found != null, "EchoPartyScreen: card template missing node '%s'" % node_name)
	return found


func _calling_label(e: Dictionary) -> String:
	var confirmed_calling: String = str(e.get("calling", ""))
	if not confirmed_calling.is_empty():
		return confirmed_calling.capitalize()
	if bool(e.get("calling_eligible", false)):
		return "Calling Undecided"
	return "Uncalled"


static func _vector_label(vector: String) -> String:
	match vector:
		"vanguard":  return "Vanguard spirit"
		"seeker":    return "Seeker's curiosity"
		"pillar":    return "Pillar's steadiness"
		"protector": return "Protector's shelter"
		_:           return ""
