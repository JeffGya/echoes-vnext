## StageScreen
## Bespoke screen for flow.stage — stage overview before committing to encounter.
## Shows stage info panel and trigger button.
## Hex map rendering deferred to a future story.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

const ObjectiveScene := preload("res://ui/components/ObjectiveItem.tscn")

var _cached_start_action: Dictionary = {}
var _cached_back_action:  Dictionary = {}

@onready var _title_label:      Label         = %StageTitleLabel
@onready var _objective_label:  Label         = %ObjectiveLabel
@onready var _objectives_list:  VBoxContainer = %ObjectivesList
@onready var _encounter_button: Button        = %EncounterButton
@onready var _back_button:      Button        = %BackButton

func _ready() -> void:
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
	_title_label.text = str(data.get("stage_name", "Stage"))

	var raw_objs: Variant  = data.get("objectives", [])
	var objectives: Array  = raw_objs if raw_objs is Array else []

	if not objectives.is_empty():
		_objective_label.text = "%d objective%s" % [objectives.size(), "s" if objectives.size() > 1 else ""]
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var item: ObjectiveItem = ObjectiveScene.instantiate()
			_objectives_list.add_child(item)
			item.setup(obj)
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
