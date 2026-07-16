## StageMapScreen
## Bespoke screen for flow.stage_map — two-panel stage progress UI.
## Left panel: sequential stage list with status badges (StageRowItem scenes).
## Right panel: detail view for the next stage to be entered (ObjectiveItem scenes).
## Stages are NOT selectable — they run in order. Single CTA to enter the next stage.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

const StageRowScene     := preload("res://ui/components/StageRowItem.tscn")
const ObjectiveScene    := preload("res://ui/components/ObjectiveItem.tscn")
const EchoSkillRowScene := preload("res://ui/components/EchoSkillRow.tscn")
const RealmRecoveryCordScene := preload("res://ui/components/RealmRecoveryCord.tscn")
const _STANDARD_CONTENT_MAX_WIDTH := 1280.0
const _WIDE_CONTENT_MAX_WIDTH := 1400.0
const _LEFT_PANEL_MIN_WIDTH := 320.0
const _LEFT_PANEL_MAX_WIDTH := 440.0
const _LEFT_PANEL_WIDTH_RATIO := 0.32
const _COMPACT_PRIMARY_PANEL_HEIGHT := 300.0
const _COMPACT_SECONDARY_PANEL_HEIGHT := 240.0
const _COMPACT_SCROLL_STEP := 64

@onready var _title_label: Label            = %TitleLabel
@onready var _subtitle_label: Label         = %SubtitleLabel
@onready var _cord: RealmRecoveryCord       = %RecoveryCord
@onready var _left_panel_title: Label       = %LeftPanelTitle
@onready var _stage_list: VBoxContainer     = %StageList
@onready var _prep_bar: PanelContainer      = %PrepBar
@onready var _prep_row: HBoxContainer       = %PrepRow
@onready var _back_button: Button           = %BackButton
@onready var _enter_button: Button          = %EnterButton
@onready var _detail_complete_label: Label  = %DetailCompleteLabel
@onready var _detail_title_label: Label     = %DetailTitleLabel
@onready var _detail_status_label: Label    = %DetailStatusLabel
@onready var _objectives_header_label: Label = %ObjectivesHeaderLabel
@onready var _detail_no_objectives_label: Label = %DetailNoObjectivesLabel
@onready var _detail_objectives_list: VBoxContainer = %DetailObjectivesList
@onready var _detail_intel_label: Label = %DetailIntelLabel
@onready var _safe_frame: MarginContainer = %SafeFrame
@onready var _content_scroll: ScrollContainer = %ContentScroll
@onready var _content_row: GridContainer = %ContentRow
@onready var _left_panel: PanelContainer = %LeftPanel
@onready var _right_panel: PanelContainer = %RightPanel
@onready var _stage_scroll: ScrollContainer = %StageScroll

var _back_action: Dictionary = {}
var _enter_action: Dictionary = {}
var _layout: Dictionary = {}


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)
	_stage_scroll.gui_input.connect(_on_stage_scroll_gui_input)

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "Snapshot missing 'type' key")
	assert(snap.has("data"), "Snapshot missing 'data' key")
	_clear()
	_render(snap["data"], snap.get("actions", {}))
	_apply_layout()

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	_apply_layout()

func _clear() -> void:
	for child in _stage_list.get_children():
		child.queue_free()
	for child in _detail_objectives_list.get_children():
		child.queue_free()
	for child in _prep_row.get_children():
		child.queue_free()
	_reset_detail_panel()
	_back_action = {}
	_enter_action = {}

func _render(data: Dictionary, actions: Dictionary) -> void:
	var stages: Array        = data.get("stages", [])
	var realm_name: String   = str(data.get("realm_name", "Unknown Realm"))
	var completed: int       = int(data.get("stages_completed_count", 0))
	var realm_complete: bool = bool(data.get("realm_complete", false))

	# Header
	_title_label.text = "Currently: " + realm_name if not realm_name.is_empty() else "Stage Map"
	if realm_complete:
		_subtitle_label.text = "Realm complete — all stages cleared."
	else:
		_subtitle_label.text = "(%d/%d) stages completed" % [completed, stages.size()]

	# Left panel title
	_left_panel_title.text = realm_name + " – Stages" if not realm_name.is_empty() else "Stages"

	# Stage rows — sequential, display only
	var next_stage: Dictionary = {}
	for stage in stages:
		var row: StageRowItem = StageRowScene.instantiate()
		_stage_list.add_child(row)
		row.setup(stage)
		if next_stage.is_empty() and stage.get("status", "") in ["current", "not_started"]:
			next_stage = stage

	# Right detail panel
	_build_detail(next_stage)

	# nav.back
	var back_action: Variant = actions.get("nav.back", {})
	if back_action is Dictionary and not back_action.is_empty():
		_back_button.visible = true
		_back_action = back_action
	else:
		_back_button.visible = false
		_back_action = {}

	# cta.enter_stage
	var enter_action: Variant = actions.get("cta.enter_stage", {})
	if enter_action is Dictionary and not enter_action.is_empty():
		_enter_button.text     = str(enter_action.get("label", "Enter next stage"))
		_enter_button.disabled = bool(enter_action.get("disabled", false))
		_enter_action = enter_action
	else:
		_enter_button.disabled = true
		_enter_action = {}

	# V2-WEAVE-001: Recovery Cord — per-stage quality track
	var recovery_segments_v: Variant = data.get("recovery_segments", [])
	var recovery_segments: Array = recovery_segments_v if recovery_segments_v is Array else []
	var stage_count_c: int = int(data.get("stage_count", stages.size()))
	var realm_virtue_c: String = str(data.get("realm_virtue", ""))
	if _cord != null:
		_cord.setup(stage_count_c, recovery_segments, realm_virtue_c)

	# PROG-009: Party prep bar — skill selection for called echoes before entering the stage.
	var party_prep_v: Variant = data.get("party_prep", [])
	var party_prep: Array = party_prep_v if party_prep_v is Array else []
	_build_prep_bar(party_prep)

# ---------------------------------------------------------------------------
# PROG-009: Party prep bar — skill dropdowns for called echoes
# ---------------------------------------------------------------------------

func _build_prep_bar(party_prep: Array) -> void:
	_prep_bar.visible = not party_prep.is_empty()
	for prep_entry in party_prep:
		if not (prep_entry is Dictionary):
			continue
		var row: EchoSkillRow = EchoSkillRowScene.instantiate()
		_prep_row.add_child(row)
		row.setup(prep_entry)
		row.skill_selected.connect(_on_echo_skill_selected)

func _on_echo_skill_selected(echo_id: String, skill_id: String) -> void:
	if skill_id.is_empty():
		action_requested.emit({
			"type":    "skill.unassign",
			"payload": { "echo_id": echo_id, "slot": "0" },
		})
	else:
		action_requested.emit({
			"type":    "skill.assign",
			"payload": { "echo_id": echo_id, "slot": "0", "skill_id": skill_id },
		})

# ---------------------------------------------------------------------------
# Right-panel detail builder
# ---------------------------------------------------------------------------

func _build_detail(stage: Dictionary) -> void:
	_reset_detail_panel()

	if stage.is_empty():
		_detail_complete_label.visible = true
		return

	var status: String = str(stage.get("status", "locked"))

	# Header row: stage name + status text
	_detail_title_label.text = str(stage.get("name", "Unknown stage"))
	_detail_status_label.text = _badge_text(status)
	_detail_status_label.theme_type_variation = _badge_theme_key(status)
	_detail_title_label.visible = true
	_detail_status_label.visible = true
	_objectives_header_label.visible = true

	var raw_objs: Variant = stage.get("objectives", [])
	var objectives: Array = raw_objs if raw_objs is Array else []
	if objectives.is_empty():
		_detail_no_objectives_label.visible = true
	else:
		_detail_objectives_list.visible = true
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var item: ObjectiveItem = ObjectiveScene.instantiate()
			_detail_objectives_list.add_child(item)
			item.setup(obj)

	# Intel section — post-MVP roaming map will fill this
	_detail_intel_label.visible = true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _reset_detail_panel() -> void:
	_detail_complete_label.visible = false
	_detail_title_label.visible = false
	_detail_status_label.visible = false
	_objectives_header_label.visible = false
	_detail_no_objectives_label.visible = false
	_detail_objectives_list.visible = false
	_detail_intel_label.visible = false


func _on_back_pressed() -> void:
	if not _back_action.is_empty():
		action_requested.emit(_back_action)


func _on_enter_pressed() -> void:
	if not _enter_action.is_empty() and not _enter_button.disabled:
		action_requested.emit(_enter_action)

func _on_stage_scroll_gui_input(event: InputEvent) -> void:
	if str(_layout.get("profile", "standard")) != "compact":
		return
	var delta := 0
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			delta = maxi(1, int(ceilf(mouse_event.factor))) * _COMPACT_SCROLL_STEP
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			delta = -maxi(1, int(ceilf(mouse_event.factor))) * _COMPACT_SCROLL_STEP
	elif event is InputEventPanGesture:
		delta = int(roundf((event as InputEventPanGesture).delta.y * _COMPACT_SCROLL_STEP))
	if delta != 0:
		# Compact StageScroll is display-only; all wheel/touch movement is applied
		# to the outer content scroller so the detail panel remains reachable.
		_content_scroll.scroll_vertical += delta

func _badge_text(status: String) -> String:
	match status:
		"completed":              return "Completed"
		"current", "not_started": return "Not started"
		_:                        return "Locked"

func _badge_theme_key(status: String) -> StringName:
	match status:
		"completed":              return &"StatusBadge.Completed"
		"current", "not_started": return &"StatusBadge.NotStarted"
		"in_progress":            return &"StatusBadge.InProgress"
		_:                        return &"StatusBadge.Locked"

func _apply_layout() -> void:
	if _safe_frame != null and _safe_frame.has_method("set_layout"):
		_safe_frame.call("set_layout", _layout)
	var profile := str(_layout.get("profile", "standard"))
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var safe_left := maxf(16.0, ceilf(insets.x))
	var safe_top := maxf(16.0, ceilf(insets.y))
	_back_button.offset_left = safe_left
	_back_button.offset_top = safe_top
	_back_button.offset_right = safe_left + 80.0
	_back_button.offset_bottom = safe_top + 48.0
	if _content_row == null:
		return
	if profile == "compact":
		_content_row.columns = 1
		_content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_row.custom_minimum_size = Vector2.ZERO
		_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_stage_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		# Compact is a scrollable single-primary-column composition. Give the stage
		# list a full readable panel before the secondary detail panel rather than
		# letting GridContainer compress both rows into the visible body height.
		_left_panel.custom_minimum_size = Vector2(0, _COMPACT_PRIMARY_PANEL_HEIGHT)
		_right_panel.custom_minimum_size = Vector2(0, _COMPACT_SECONDARY_PANEL_HEIGHT)
	else:
		_content_row.columns = 2
		_content_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_stage_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		var logical_size: Vector2 = _layout.get("logical_size", Vector2(1280, 720))
		var safe_width := maxf(
			0.0,
			logical_size.x
				- maxf(16.0, ceilf(insets.x))
				- maxf(16.0, ceilf(insets.z))
		)
		var max_width := _WIDE_CONTENT_MAX_WIDTH if profile == "wide" else _STANDARD_CONTENT_MAX_WIDTH
		var content_width := minf(safe_width, max_width)
		var left_width := clampf(
			content_width * _LEFT_PANEL_WIDTH_RATIO,
			_LEFT_PANEL_MIN_WIDTH,
			_LEFT_PANEL_MAX_WIDTH
		)
		var right_width := maxf(560.0, content_width - left_width)
		_left_panel.custom_minimum_size = Vector2(left_width, 0)
		_right_panel.custom_minimum_size = Vector2(right_width, 0)
		_content_row.custom_minimum_size = Vector2(content_width, 0)
