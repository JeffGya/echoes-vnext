# res://ui/screens/RealmInitScreen.gd
# UI-003 foundation: Realm overview card shown after a realm is selected.
# Displays name, virtue, description, stage_count, and seed (debug).
# Actions: cta.begin → stage_map, nav.back → realm_select.
#
# This is a minimal but fully wired screen. UI-003 will expand it with
# proper card design, artwork, and West African aesthetic.

extends Control

signal action_requested(action: Dictionary)

@onready var name_label:        Label       = %RealmName
@onready var virtue_label:      Label       = %Virtue
@onready var description_label: Label       = %Description
@onready var stage_count_label: Label       = %StageCount
@onready var stage_list:        VBoxContainer = %StageList
@onready var seed_label:        Label       = %Seed
@onready var begin_btn:         Button      = %Begin
@onready var back_btn:          Button      = %Back

var _action_begin: Dictionary = {}
var _action_back:  Dictionary = {}

func _ready() -> void:
	begin_btn.pressed.connect(_on_begin_pressed)
	back_btn.pressed.connect(_on_back_pressed)

func set_snapshot(snap: Dictionary) -> void:
	var data: Dictionary    = snap.get("data", {})    if snap.get("data")    is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	name_label.text        = str(data.get("name", "Unknown Realm"))
	virtue_label.text      = "Virtue: %s" % str(data.get("virtue", "")).capitalize()
	description_label.text = str(data.get("description", ""))
	stage_count_label.text = "Stages: %d" % int(data.get("stage_count", 0))
	seed_label.text        = "Seed: %d" % int(data.get("seed", 0))

	# Rebuild stage list
	for child in stage_list.get_children():
		child.queue_free()
	var stages_v: Variant = data.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	for s in stages:
		var lbl := Label.new()
		var type_label := str(s.get("stage_type", "")).capitalize()
		var obj_count  := int(s.get("objective_count", 0))
		var desc       := str(s.get("stage_description", ""))
		lbl.text = "Stage %d — %s (%d obj): %s" % [
			int(s.get("stage_index", 0)) + 1,
			type_label,
			obj_count,
			desc,
		]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stage_list.add_child(lbl)

	var begin_v: Variant = actions.get("cta.begin", {})
	_action_begin = begin_v if begin_v is Dictionary else {}
	begin_btn.disabled = _action_begin.is_empty()

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}
	back_btn.disabled = _action_back.is_empty()

func _on_begin_pressed() -> void:
	if _action_begin.is_empty():
		return
	action_requested.emit(_action_begin)

func _on_back_pressed() -> void:
	if _action_back.is_empty():
		return
	action_requested.emit(_action_back)
