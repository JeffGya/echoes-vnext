# SanctumScreen.gd

extends Control

class_name SanctumScreen

signal action_requested(action: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var vow_mantra_label: Label = %VowMantraLabel  # VOW-001: active vow proverb under title
@onready var ase_label: Label = %AseLabel
@onready var ase_flame_tip: Label = %AseFlameTip
@onready var ase_delta_label: Label = %AseDeltaLabel
@onready var ekwan_label: Label = %EkwanLabel
@onready var _awakening_overlay: Control = %AwakeningOverlay
@onready var _awakening_grant_label: Label = %AwakeningGrantLabel
@onready var _awakening_dismiss: Button = %AwakeningDismiss
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

# V2-VOW-002: ST-H — Generic Active Effects Panel (RightSidebar, between Economy and ThreadReserve)
@onready var _effects_panel: PanelContainer = %ActiveEffectsPanel
@onready var _effects_list:  HBoxContainer  = %ActiveEffectsList
# V2-VOW-002: ST-H — Effect detail popout (floating overlay at screen root)
@onready var _effect_detail:   PanelContainer = %EffectDetailPanel
@onready var _detail_headline: Label           = %EffectDetailHeadline
@onready var _detail_body:     Label           = %EffectDetailBody
@onready var _detail_duration: Label           = %EffectDetailDuration


var _snapshot: Dictionary = {}
var _name_dirty := false

var _last_ase_balance: int = -1
var _ase_tween: Tween

# V2-VOW-002: ST-E — compliance count label (lazily created, positioned below VowMantraLabel)
var _vow_compliance_lbl: Label = null
# V2-VOW-002: ST-H — currently open chip Button (for toggle-close detection)
var _active_chip_effect_id: String = ""


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

	# V2-VOW-002 ST-E: compliance count label — "N stages honored" below the mantra proverb.
	# Created once, reused each render; positioned below VowMantraLabel (offset_top ~70).
	if _vow_compliance_lbl == null:
		_vow_compliance_lbl = Label.new()
		_vow_compliance_lbl.add_theme_font_size_override("font_size", 12)
		_vow_compliance_lbl.add_theme_color_override("font_color", Color("#A8865A"))  # Warm Brass
		_vow_compliance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_vow_compliance_lbl)
		_vow_compliance_lbl.layout_mode = 1
		_vow_compliance_lbl.anchor_left  = 0.5
		_vow_compliance_lbl.anchor_right  = 0.5
		_vow_compliance_lbl.anchor_top    = 0.0
		_vow_compliance_lbl.anchor_bottom = 0.0
		_vow_compliance_lbl.offset_left   = -175.0
		_vow_compliance_lbl.offset_top    = 70.0
		_vow_compliance_lbl.offset_right  = 175.0
		_vow_compliance_lbl.offset_bottom = 86.0
	var _comp_count := int(av.get("compliance_count", 0))
	if not av.is_empty() and vow_mantra_label.visible and _comp_count > 0:
		_vow_compliance_lbl.text    = "%d stage%s honored" % [_comp_count, "s" if _comp_count != 1 else ""]
		_vow_compliance_lbl.visible = true
	else:
		_vow_compliance_lbl.visible = false

	ase_label.text = "%d" % ase_balance

	# V2-ECONOMY-001: AseFlameTip replaces AseRateLabel — combined flame state + rate
	var ase_flame_awakened := bool(data.get("ase_flame_awakened", false))
	if ase_flame_awakened:
		ase_flame_tip.text = "Ase Flame recovering (~%.1f p/h)" % per_hour
		ase_flame_tip.add_theme_color_override("font_color", Color("#E8A030"))
	else:
		ase_flame_tip.text = "House dormant — Flame unlit"
		ase_flame_tip.add_theme_color_override("font_color", Color("#7A7A8A"))

	# V2-ECONOMY-001: Ekwan balance
	ekwan_label.text = "%d" % int(data.get("ekwan_balance", 0))

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
		# V2-VOICE-001: show sanctum bark below emotional_status if present.
		var bark_v: Variant = p.get("sanctum_bark", {})
		if bark_v is Dictionary:
			var bark_line := str((bark_v as Dictionary).get("line", ""))
			if not bark_line.is_empty():
				var bark_lbl := Label.new()
				bark_lbl.text = "\"%s\"" % bark_line
				bark_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
				bark_lbl.add_theme_font_size_override("font_size", 12)
				bark_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				_house_state_list.add_child(bark_lbl)

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

	# V2-VOW-002 ST-H: Active Effects Panel — generic chip row in RightSidebar.
	# Clears chip children each render; shows panel only when ≥1 effect present.
	for _ec in _effects_list.get_children():
		_ec.queue_free()
	var effects_v: Variant = data.get("active_effects", [])
	var effects: Array = effects_v if effects_v is Array else []
	if effects.size() > 0:
		for eff_v in effects:
			if eff_v is Dictionary:
				_effects_list.add_child(_build_effect_chip(eff_v as Dictionary))
		_effects_panel.visible = true
		_apply_panel_style(_effects_panel)
	else:
		_effects_panel.visible = false
	# Close detail popout if effects cleared (e.g. vow broken then re-entered stage)
	if effects.is_empty():
		_effect_detail.visible = false
		_active_chip_effect_id = ""

	name_modal.visible = false

	# V2-ECONOMY-001: Awakening overlay — one-shot on first Sanctum entry after awakening
	if bool(data.get("show_awakening_overlay", false)):
		_awakening_grant_label.text = "+%d Ase" % int(data.get("awakening_grant", 40))
		_show_awakening_overlay()

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(_on_name_edit_changed)
	_awakening_dismiss.pressed.connect(_on_awakening_dismiss_pressed)
	_apply_awakening_panel_style()

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
	
