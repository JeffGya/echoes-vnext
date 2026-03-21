class_name RealmShell
extends Control

signal action_requested(action: Dictionary)

var _active_overlay: Control = null

var _stage_map_scene  := preload("res://ui/screens/StageMapScreen.tscn")
var _stage_scene      := preload("res://ui/screens/StageScreen.tscn")
var _combat_board_scene := preload("res://ui/screens/CombatBoardScreen.tscn")
var _resolve_scene    := preload("res://ui/screens/ResolveScreen.tscn")

var _scene_by_flow_type: Dictionary = {}

func _ready() -> void:
	_scene_by_flow_type = {
		"flow.stage_map": _stage_map_scene,
		"flow.stage":     _stage_scene,
		"flow.encounter": _combat_board_scene,
		"flow.resolve":   _resolve_scene,
	}

func set_snapshot(snap: Dictionary) -> void:
	_show_overlay_for_type(str(snap.get("type", "")), snap)

func _show_overlay_for_type(snap_type: String, snap: Dictionary) -> void:
	if not _scene_by_flow_type.has(snap_type):
		push_warning("RealmShell: no overlay mapped for snapshot type: " + snap_type)
		return

	var packed: PackedScene = _scene_by_flow_type[snap_type]
	if packed == null:
		return

	# Scene reuse: if same scene is already active, just update snapshot
	if _active_overlay != null and _active_overlay.scene_file_path == packed.resource_path:
		if _active_overlay.has_method("set_snapshot"):
			_active_overlay.call("set_snapshot", snap)
		return

	# Otherwise replace overlay
	if _active_overlay != null:
		_active_overlay.queue_free()
		_active_overlay = null

	var overlay := packed.instantiate()
	add_child(overlay)
	_active_overlay = overlay as Control

	if _active_overlay != null and _active_overlay.has_signal("action_requested"):
		var ok := _active_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("RealmShell: failed to connect overlay action_requested (err=%d)" % ok)

	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)

func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)
