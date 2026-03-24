# res://ui/screens/RealmSelectScreen.gd
# UI-003 foundation: Realm selection screen.
# Shows all realm cards with name, virtue, status badge, and a Select button per row.
# Per-row tap dispatches flow.select_realm directly (not via snapshot.actions).
# nav.back slot dispatches back to Sanctum.
#
# This is a minimal but fully wired screen. UI-003 will expand it with
# proper card design, status badges, lock visuals, and West African aesthetic.

extends Control

signal action_requested(action: Dictionary)

@onready var title_label: Label     = %Title
@onready var realm_list: VBoxContainer = %RealmList
@onready var back_btn: Button       = %Back

var _action_back: Dictionary = {}

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)

func set_snapshot(snap: Dictionary) -> void:
	var data: Dictionary    = snap.get("data", {})    if snap.get("data")    is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	title_label.text = str(data.get("title", "Select Realm"))

	var back_v: Variant = actions.get("nav.back", {})
	_action_back = back_v if back_v is Dictionary else {}
	back_btn.disabled = _action_back.is_empty()

	_rebuild_realm_list(data)

func _rebuild_realm_list(data: Dictionary) -> void:
	for c in realm_list.get_children():
		c.queue_free()

	var realms_v: Variant = data.get("realms", [])
	var realms: Array = realms_v if realms_v is Array else []
	var current_id := str(data.get("current_realm_id", ""))

	for r_v in realms:
		if not (r_v is Dictionary):
			continue
		var r: Dictionary = r_v
		realm_list.add_child(_make_realm_row(r, current_id))

func _make_realm_row(r: Dictionary, current_id: String) -> Control:
	var rid     := str(r.get("id", ""))
	var name_s  := str(r.get("name", rid))
	var virtue  := str(r.get("virtue", ""))
	var status  := str(r.get("status", "not_started"))
	var locked  := bool(r.get("locked", false))
	var is_active := rid == current_id

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name + virtue
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = name_s
	info.add_child(name_lbl)

	var virtue_lbl := Label.new()
	virtue_lbl.text = virtue.capitalize()
	info.add_child(virtue_lbl)

	# Status badge label
	var badge_text := status
	if locked:
		badge_text = "locked"
	elif is_active:
		badge_text = "active ★"
	var badge := Label.new()
	badge.text = "[%s]" % badge_text
	row.add_child(badge)

	# Select button — disabled when locked
	var btn := Button.new()
	btn.text = "Select"
	btn.disabled = locked
	btn.pressed.connect(func() -> void:
		action_requested.emit({
			"type":     "flow.select_realm",
			"realm_id": rid,
		})
	)
	row.add_child(btn)

	return row

func _on_back_pressed() -> void:
	if _action_back.is_empty():
		return
	action_requested.emit(_action_back)
