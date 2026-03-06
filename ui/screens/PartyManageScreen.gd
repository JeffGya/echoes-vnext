# res://ui/screens/PartyManageScreen.gd
extends Control

signal action_requested(action: Dictionary)

@onready var title_label: Label = %Title
@onready var roster_list: VBoxContainer = %RosterList
@onready var party_list: VBoxContainer = %PartyList
@onready var party_header: Label = %PartyHeader
@onready var back_btn: Button = %Back
@onready var confirm_btn: Button = %Confirm

var _snap: Dictionary = {}
var _action_back: Dictionary = {}
var _action_confirm: Dictionary = {}

func _ready() -> void:
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if not confirm_btn.pressed.is_connected(_on_confirm_pressed):
		confirm_btn.pressed.connect(_on_confirm_pressed)
	_setup_drop_targets()

func _setup_drop_targets() -> void:
	# Party list: accepts drops from roster only, and only if party not full
	party_list.set_drag_forwarding(
		func(_p: Vector2) -> Variant: return null,
		func(_p: Vector2, data: Variant) -> bool:
			if not (data is Dictionary): return false
			if data.get("from_list", "") != "roster": return false
			var d: Dictionary = _snap.get("data", {}) if _snap.get("data") is Dictionary else {}
			var pending: Array = d.get("active_party_ids", []) if d.get("active_party_ids") is Array else []
			var max_size := int(d.get("max_party_size", 5))
			return pending.size() < max_size,
		func(_p: Vector2, data: Variant) -> void:
			var echo_id := str(data.get("echo_id", ""))
			if echo_id.is_empty(): return
			action_requested.emit({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	)
	# Roster list: accepts drops from party only
	roster_list.set_drag_forwarding(
		func(_p: Vector2) -> Variant: return null,
		func(_p: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.get("from_list", "") == "party",
		func(_p: Vector2, data: Variant) -> void:
			var echo_id := str(data.get("echo_id", ""))
			if echo_id.is_empty(): return
			action_requested.emit({ "type": "sanctum.party.toggle", "payload": { "echo_id": echo_id } })
	)

func set_snapshot(snap: Dictionary) -> void:
	_snap = snap

	var data: Dictionary = snap.get("data", {}) if snap.get("data") is Dictionary else {}
	var actions: Dictionary = snap.get("actions", {}) if snap.get("actions") is Dictionary else {}

	title_label.text = str(data.get("title", "Manage Party"))

	# Slot actions
	var back_v: Variant = actions.get("back", {})
	_action_back = back_v if back_v is Dictionary else {}

	var primary_v: Variant = actions.get("primary", {})
	_action_confirm = primary_v if primary_v is Dictionary else {}
	confirm_btn.disabled = not bool(_action_confirm.get("enabled", false))

	# Party header count
	var pending: Array = data.get("active_party_ids", []) if data.get("active_party_ids") is Array else []
	var max_size := int(data.get("max_party_size", 5))
	party_header.text = "Party (%d/%d)" % [pending.size(), max_size]

	# Rebuild roster list (only echoes NOT in party)
	_clear_children(roster_list)
	var roster: Array = data.get("roster", []) if data.get("roster") is Array else []
	for e_v in roster:
		if not (e_v is Dictionary): continue
		var e: Dictionary = e_v
		if bool(e.get("in_party", false)): continue
		roster_list.add_child(_make_draggable_row(e, "roster"))

	# Rebuild party list (only echoes IN party)
	_clear_children(party_list)
	for e_v in roster:
		if not (e_v is Dictionary): continue
		var e: Dictionary = e_v
		if not bool(e.get("in_party", false)): continue
		party_list.add_child(_make_draggable_row(e, "party"))

func _on_back_pressed() -> void:
	if _action_back.is_empty(): return
	action_requested.emit(_action_back)

func _on_confirm_pressed() -> void:
	if _action_confirm.is_empty(): return
	if bool(_action_confirm.get("enabled", true)) == false: return
	action_requested.emit(_action_confirm)

# -------------------------
# Draggable row builder
# -------------------------
func _make_draggable_row(e: Dictionary, from_list: String) -> Control:
	var echo_id := str(e.get("id", ""))
	var nm := str(e.get("name", ""))
	var rank := int(e.get("rank", 0))
	var has_level := e.has("level")
	var level := int(e.get("level", 0))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_DRAG

	var grip := Label.new()
	grip.text = "≡"
	row.add_child(grip)

	var name_lbl := Label.new()
	name_lbl.text = nm
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	if has_level:
		var lvl_lbl := Label.new()
		lvl_lbl.text = "Lv %d" % level
		row.add_child(lvl_lbl)

	var rank_lbl := Label.new()
	rank_lbl.text = "Rank %d" % rank
	row.add_child(rank_lbl)

	# Drag source: row provides drag data, does not accept drops
	row.set_drag_forwarding(
		func(_p: Vector2) -> Variant:
			var preview := Label.new()
			preview.text = nm
			row.set_drag_preview(preview)
			return { "echo_id": echo_id, "from_list": from_list },
		func(_p: Vector2, _d: Variant) -> bool: return false,
		func(_p: Vector2, _d: Variant) -> void: pass
	)

	return row

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
