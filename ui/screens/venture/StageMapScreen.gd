## StageMapScreen
## Bespoke screen for flow.stage_map — two-panel stage progress UI.
## Left panel: sequential stage list with status badges (StageRowItem scenes).
## Right panel: detail view for the next stage to be entered (ObjectiveItem scenes).
## Stages are NOT selectable — they run in order. Single CTA to enter the next stage.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

const StageRowScene   := preload("res://ui/components/StageRowItem.tscn")
const ObjectiveScene  := preload("res://ui/components/ObjectiveItem.tscn")

@onready var _title_label: Label            = %TitleLabel
@onready var _subtitle_label: Label         = %SubtitleLabel
@onready var _left_panel_title: Label       = %LeftPanelTitle
@onready var _stage_list: VBoxContainer     = %StageList
@onready var _right_vbox: VBoxContainer     = %RightVBox
@onready var _back_button: Button           = %BackButton
@onready var _enter_button: Button          = %EnterButton

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
		_back_button.pressed.connect(func(): action_requested.emit(back_action))
	else:
		_back_button.visible = false

	# cta.enter_stage
	var enter_action: Variant = actions.get("cta.enter_stage", {})
	if enter_action is Dictionary and not enter_action.is_empty():
		_enter_button.text     = str(enter_action.get("label", "Enter next stage"))
		_enter_button.disabled = bool(enter_action.get("disabled", false))
		_enter_button.pressed.connect(func(): action_requested.emit(enter_action))
	else:
		_enter_button.disabled = true

# ---------------------------------------------------------------------------
# Right-panel detail builder
# ---------------------------------------------------------------------------

func _build_detail(stage: Dictionary) -> void:
	if stage.is_empty():
		var lbl := Label.new()
		lbl.text = "All stages complete."
		_right_vbox.add_child(lbl)
		return

	var status: String = str(stage.get("status", "locked"))

	# Header row: stage name + status text
	var detail_title := Label.new()
	detail_title.text = str(stage.get("name", "Unknown stage"))
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title.add_theme_font_size_override("font_size", 18)
	_right_vbox.add_child(detail_title)

	var status_lbl := Label.new()
	status_lbl.text = _badge_text(status)
	_right_vbox.add_child(status_lbl)

	_right_vbox.add_child(_spacer(8))

	# Objectives list
	var obj_header := Label.new()
	obj_header.text = "Objectives"
	obj_header.add_theme_font_size_override("font_size", 14)
	_right_vbox.add_child(obj_header)

	_right_vbox.add_child(_spacer(4))

	var raw_objs: Variant = stage.get("objectives", [])
	var objectives: Array = raw_objs if raw_objs is Array else []
	if objectives.is_empty():
		var no_obj := Label.new()
		no_obj.text = "  • No objectives loaded"
		_right_vbox.add_child(no_obj)
	else:
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var item: ObjectiveItem = ObjectiveScene.instantiate()
			_right_vbox.add_child(item)
			item.setup(obj)

	_right_vbox.add_child(_spacer(16))

	# Intel section — post-MVP roaming map will fill this
	var intel_header := Label.new()
	intel_header.text = "Gathered intel – none"
	_right_vbox.add_child(intel_header)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _badge_text(status: String) -> String:
	match status:
		"completed":              return "Completed"
		"current", "not_started": return "Not started"
		_:                        return "Locked"
