## StageScreen
## Bespoke screen for flow.stage — stage overview before committing to encounter.
## Shows stage info panel, party bar, and trigger button.
## Hex map rendering deferred to a future story.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

const COL_BG       := Color("#1a1a10")
const COL_INFO_BG  := Color(0.10, 0.08, 0.05, 0.85)
const COL_CARD_BG  := Color(0.10, 0.12, 0.07, 0.92)
const COL_TEXT     := Color("#f0e8d0")
const COL_TEXT_DIM := Color("#908870")
const COL_ENTER_BG := Color("#c8a020")

var _cached_start_action: Dictionary = {}
var _cached_back_action:  Dictionary = {}

@onready var _info_panel:       PanelContainer = %InfoPanel
@onready var _title_label:      Label          = %StageTitleLabel
@onready var _objective_label:  Label          = %ObjectiveLabel
@onready var _party_bar:        HBoxContainer  = %PartyBar
@onready var _encounter_button: Button         = %EncounterButton
@onready var _back_button:      Button         = %BackButton

func _ready() -> void:
	# Background colour via StyleBox on self
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	add_theme_stylebox_override("panel", bg)

	# Info panel style
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = COL_INFO_BG
	info_style.set_corner_radius_all(8)
	info_style.set_content_margin_all(14)
	_info_panel.add_theme_stylebox_override("panel", info_style)

	_title_label.add_theme_color_override("font_color", COL_TEXT)
	_objective_label.add_theme_color_override("font_color", COL_TEXT_DIM)

	_apply_button_style(_encounter_button, COL_ENTER_BG)
	_encounter_button.add_theme_color_override("font_color", Color("#1a1a0a"))

	_back_button.pressed.connect(_on_back_pressed)
	_encounter_button.pressed.connect(_on_encounter_pressed)

# ---------------------------------------------------------------------------
# Bespoke Screen Contract
# ---------------------------------------------------------------------------

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "Snapshot missing 'type' key")
	assert(snap.has("data"), "Snapshot missing 'data' key")
	_clear()
	_render(snap["data"], snap.get("actions", {}))

func _clear() -> void:
	for c in _party_bar.get_children():
		c.queue_free()
	_title_label.text     = ""
	_objective_label.text = ""
	_cached_start_action  = {}
	_cached_back_action   = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	_title_label.text     = str(data.get("stage_name", "Stage"))
	_objective_label.text = "Objective: " + _format_objective(str(data.get("objective_type", "")))

	_build_party_bar(data.get("party_preview", []))

	# nav.back
	var back_v: Variant = actions.get("nav.back", {})
	if back_v is Dictionary and not back_v.is_empty():
		_cached_back_action = back_v
	else:
		_back_button.visible = false

	# cta.start
	var start_v: Variant = actions.get("cta.start", {})
	if start_v is Dictionary and not start_v.is_empty():
		_cached_start_action   = start_v
		_encounter_button.text = str(start_v.get("label", "Start Encounter →"))
	else:
		_encounter_button.disabled = true

# ---------------------------------------------------------------------------
# Party bar
# ---------------------------------------------------------------------------

func _build_party_bar(party: Array) -> void:
	for i in 5:
		_party_bar.add_child(_make_party_card(party[i] if i < party.size() else {}))

func _make_party_card(member: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COL_CARD_BG
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	# Image placeholder row
	var img_row := HBoxContainer.new()
	img_row.add_theme_constant_override("separation", 6)

	var placeholder := ColorRect.new()
	placeholder.custom_minimum_size = Vector2(28, 28)
	placeholder.color = Color("#504840")
	img_row.add_child(placeholder)

	var name_lbl := Label.new()
	name_lbl.text = str(member.get("name", "Empty")) if not member.is_empty() else "—"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 11)
	img_row.add_child(name_lbl)
	vbox.add_child(img_row)

	# HP bar placeholder
	var hp_bar := ProgressBar.new()
	hp_bar.value = 100 if not member.is_empty() else 0
	hp_bar.custom_minimum_size = Vector2(0, 5)
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	# Status
	var status_lbl := Label.new()
	status_lbl.text = "Ready" if not member.is_empty() else ""
	status_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	status_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_lbl)

	return card

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _on_back_pressed() -> void:
	if not _cached_back_action.is_empty():
		action_requested.emit(_cached_back_action)

func _on_encounter_pressed() -> void:
	if not _cached_start_action.is_empty():
		action_requested.emit(_cached_start_action)

func _format_objective(obj_type: String) -> String:
	match obj_type:
		"purify_shrine":  return "Purify the Shrine"
		"defeat_enemies": return "Defeat All Enemies"
		_: return obj_type.capitalize() if not obj_type.is_empty() else "Unknown"

func _apply_button_style(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(6)
	normal.content_margin_left   = 20
	normal.content_margin_right  = 20
	normal.content_margin_top    = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)
