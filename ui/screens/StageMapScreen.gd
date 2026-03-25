## StageMapScreen
## Bespoke screen for flow.stage_map — two-panel stage progress UI.
## Left panel: sequential stage list with status badges.
## Right panel: detail view for the next stage to be entered.
## Stages are NOT selectable — they run in order. Single CTA to enter the next stage.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

@onready var _header_bar: PanelContainer    = %HeaderBar
@onready var _title_label: Label            = %TitleLabel
@onready var _subtitle_label: Label         = %SubtitleLabel
@onready var _left_panel: PanelContainer    = %LeftPanel
@onready var _left_panel_title: Label       = %LeftPanelTitle
@onready var _stage_list: VBoxContainer     = %StageList
@onready var _right_panel: PanelContainer   = %RightPanel
@onready var _right_vbox: VBoxContainer     = %RightVBox
@onready var _back_button: Button           = %BackButton
@onready var _enter_button: Button          = %EnterButton

# Palette — matching the game's dark West-African earthy tones
const COL_HEADER_BG   := Color("#5c3012")
const COL_LEFT_BG     := Color("#1c2a14")
const COL_RIGHT_BG    := Color("#233020")
const COL_COMPLETED   := Color("#2a7a3e")
const COL_NOT_STARTED := Color("#b05018")
const COL_LOCKED      := Color("#781818")
const COL_ENTER_BG    := Color("#c8a020")
const COL_TEXT        := Color("#f0e8d0")
const COL_TEXT_DIM    := Color("#908870")

func _ready() -> void:
	_apply_panel_bg(_header_bar, COL_HEADER_BG, 0, 12)
	_apply_panel_bg(_left_panel,  COL_LEFT_BG,  6, 10)
	_apply_panel_bg(_right_panel, COL_RIGHT_BG, 6, 12)
	_apply_button_style(_enter_button, COL_ENTER_BG)
	_enter_button.add_theme_color_override("font_color", Color("#1a1a0a"))

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "Snapshot missing 'type' key")
	assert(snap.has("data"), "Snapshot missing 'data' key")
	_clear()
	_render(snap["data"], snap.get("actions", {}))

func _clear() -> void:
	for child in _stage_list.get_children():
		child.queue_free()
	for child in _right_vbox.get_children():
		child.queue_free()

func _render(data: Dictionary, actions: Dictionary) -> void:
	var stages: Array        = data.get("stages", [])
	var realm_name: String   = str(data.get("realm_name", "Unknown Realm"))
	var completed: int       = int(data.get("stages_completed_count", 0))

	# Header
	_title_label.text    = "Currently: " + realm_name if not realm_name.is_empty() else "Stage Map"
	_subtitle_label.text = "(%d/%d) stages completed" % [completed, stages.size()]

	# Left panel title
	_left_panel_title.text = realm_name + " – Stages" if not realm_name.is_empty() else "Stages"

	# Stage rows (sequential, display only — no individual click)
	var next_stage: Dictionary = {}
	for stage in stages:
		_stage_list.add_child(_make_stage_row(stage))
		if next_stage.is_empty() and stage.get("status", "") in ["current", "not_started"]:
			next_stage = stage

	# Right detail panel — shows the next stage to be entered
	_build_detail(next_stage)

	# nav.back
	var back_action: Variant = actions.get("nav.back", {})
	if back_action is Dictionary and not back_action.is_empty():
		_back_button.pressed.connect(func(): action_requested.emit(back_action))
	else:
		_back_button.visible = false

	# cta.enter_stage
	var enter_action: Variant = actions.get("cta.enter_stage", {})
	if enter_action is Dictionary and not enter_action.is_empty():
		_enter_button.text    = str(enter_action.get("label", "Enter next stage"))
		_enter_button.disabled = bool(enter_action.get("disabled", false))
		_enter_button.pressed.connect(func(): action_requested.emit(enter_action))
	else:
		_enter_button.disabled = true

# ---------------------------------------------------------------------------
# Stage row builder
# ---------------------------------------------------------------------------

func _make_stage_row(stage: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 38)
	row.add_theme_constant_override("separation", 8)

	# Status badge
	row.add_child(_make_badge(str(stage.get("status", "locked"))))

	# Stage name — RichTextLabel so completed stages get strikethrough
	var name_rtl := RichTextLabel.new()
	name_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_rtl.fit_content = true
	name_rtl.scroll_active = false
	name_rtl.bbcode_enabled = true
	var name_str  := str(stage.get("name", "Unknown stage"))
	var obj_count := int(stage.get("objective_count", 0))
	var obj_suffix := " (%d obj)" % obj_count if obj_count > 0 else ""
	if stage.get("status", "") == "completed":
		name_rtl.text = "[color=#908870][s]%s%s[/s][/color]" % [name_str, obj_suffix]
	else:
		name_rtl.text = "[color=#f0e8d0]%s[/color][color=#908870]%s[/color]" % [name_str, obj_suffix]
	row.add_child(name_rtl)

	# Arrow
	var arrow := Label.new()
	arrow.text = "►"
	arrow.add_theme_color_override("font_color", COL_TEXT_DIM)
	row.add_child(arrow)

	return row

func _make_badge(status: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _badge_color(status)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(90, 0)

	var lbl := Label.new()
	lbl.text = _badge_text(status)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", COL_TEXT)
	panel.add_child(lbl)
	return panel

func _badge_color(status: String) -> Color:
	match status:
		"completed":              return COL_COMPLETED
		"current", "not_started": return COL_NOT_STARTED
		_:                        return COL_LOCKED

func _badge_text(status: String) -> String:
	match status:
		"completed":              return "Completed"
		"current", "not_started": return "Not started"
		_:                        return "Locked"

# ---------------------------------------------------------------------------
# Right-panel detail builder
# ---------------------------------------------------------------------------

func _build_detail(stage: Dictionary) -> void:
	if stage.is_empty():
		var lbl := Label.new()
		lbl.text = "All stages complete."
		lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		_right_vbox.add_child(lbl)
		return

	var status: String = str(stage.get("status", "locked"))

	# Header row: stage name + status badge
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)

	var detail_title := Label.new()
	detail_title.text = str(stage.get("name", "Unknown objective"))
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title.add_theme_font_size_override("font_size", 18)
	detail_title.add_theme_color_override("font_color", COL_TEXT)
	header_row.add_child(detail_title)
	header_row.add_child(_make_badge(status))
	_right_vbox.add_child(header_row)

	_right_vbox.add_child(_spacer(8))

	# Objectives list
	var obj_header := Label.new()
	obj_header.text = "Objectives"
	obj_header.add_theme_font_size_override("font_size", 14)
	obj_header.add_theme_color_override("font_color", COL_TEXT)
	_right_vbox.add_child(obj_header)

	_right_vbox.add_child(_spacer(4))

	var raw_objs: Variant = stage.get("objectives", [])
	var objectives: Array = raw_objs if raw_objs is Array else []
	if objectives.is_empty():
		var no_obj := Label.new()
		no_obj.text = "  • No objectives loaded"
		no_obj.add_theme_color_override("font_color", COL_TEXT_DIM)
		_right_vbox.add_child(no_obj)
	else:
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var type_label := str(obj.get("obj_type", "")).capitalize()
			var desc       := str(obj.get("obj_description", ""))
			var obj_lbl    := Label.new()
			obj_lbl.text   = "  %d. %s — %s" % [int(obj.get("obj_index", 0)) + 1, type_label, desc]
			obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			obj_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
			_right_vbox.add_child(obj_lbl)

	_right_vbox.add_child(_spacer(16))

	# Intel section — post-MVP roaming map will fill this
	var intel_header := Label.new()
	intel_header.text = "Gathered intel – none"
	intel_header.add_theme_color_override("font_color", COL_TEXT)
	_right_vbox.add_child(intel_header)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _apply_panel_bg(panel: PanelContainer, color: Color, radius: int, margin: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", style)

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
