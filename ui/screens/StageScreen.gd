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
@onready var _objectives_list:  VBoxContainer  = %ObjectivesList
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
	_title_label.text     = ""
	_objective_label.text = ""
	for child in _objectives_list.get_children():
		child.queue_free()
	_cached_start_action  = {}
	_cached_back_action   = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	_title_label.text     = str(data.get("stage_name", "Stage"))

	var raw_objs: Variant  = data.get("objectives", [])
	var objectives: Array  = raw_objs if raw_objs is Array else []

	if not objectives.is_empty():
		_objective_label.text = "%d objective%s" % [objectives.size(), "s" if objectives.size() > 1 else ""]
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var type_label := str(obj.get("obj_type", "")).capitalize()
			var desc       := str(obj.get("obj_description", ""))
			var lbl        := Label.new()
			lbl.text       = "  %d. %s — %s" % [int(obj.get("obj_index", 0)) + 1, type_label, desc]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
			_objectives_list.add_child(lbl)
	else:
		_objective_label.text = "Objective: " + _format_objective(str(data.get("objective_type", "")))

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
