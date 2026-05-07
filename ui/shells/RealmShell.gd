class_name RealmShell
extends Control

signal action_requested(action: Dictionary)

var _active_overlay: Control = null

var _stage_map_scene      := preload("res://ui/screens/venture/StageMapScreen.tscn")
var _stage_explore_scene  := preload("res://ui/screens/venture/StageExploreScreen.tscn")  # V2-STAGE-001
var _combat_board_scene   := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
var _resolve_scene        := preload("res://ui/screens/venture/ResolveScreen.tscn")

const EchoCardScene := preload("res://ui/components/EchoCardItem.tscn")

var _scene_by_flow_type: Dictionary = {}

@onready var _overlay_root: Control      = $OverlayRoot
@onready var _echo_bar:     HBoxContainer = %EchoBar

func _ready() -> void:
	_scene_by_flow_type = {
		"flow.stage_map":     _stage_map_scene,
		"flow.stage":         _stage_explore_scene,   # V2-STAGE-001: merged into StageExploreScreen
		"flow.stage_explore": _stage_explore_scene,   # V2-STAGE-001
		"flow.encounter":     _combat_board_scene,
		"flow.keeper_trial":  _combat_board_scene,
		"flow.resolve":       _resolve_scene,
	}

func set_snapshot(snap: Dictionary) -> void:
	_update_echo_bar(snap)
	_show_overlay_for_type(str(snap.get("type", "")), snap)

# ─────────────────────────────────────────────────────────────
# Echo bar — shell-owned, live-updates on every snapshot
# ─────────────────────────────────────────────────────────────

## Extracts party actors from the snapshot and rebuilds the bar.
## Called on every set_snapshot() — always reflects the latest HP + emotional state.
func _update_echo_bar(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var data: Dictionary = snap.get("data", {})

	var party: Array = []
	match snap_type:
		"flow.encounter", "flow.keeper_trial", "flow.resolve":
			# Encounter snapshots include all combatants — filter for echoes only.
			for a in data.get("actors", []):
				if a is Dictionary and str(a.get("faction", "")) == "echo":
					party.append(a)
		"flow.stage", "flow.stage_map", "flow.stage_explore":
			# Stage snapshots include party_preview: { name, rank, calling_origin }
			var preview: Variant = data.get("party_preview", [])
			if preview is Array:
				party = preview

	# Rebuild from scratch — max 5 cards, trivially fast.
	for child in _echo_bar.get_children():
		child.queue_free()
	for actor in party:
		if actor is Dictionary:
			var card: EchoCardItem = EchoCardScene.instantiate()
			_echo_bar.add_child(card)
			card.setup(actor)


# ─────────────────────────────────────────────────────────────
# Overlay routing
# ─────────────────────────────────────────────────────────────

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
	_overlay_root.add_child(overlay)
	_active_overlay = overlay as Control

	if _active_overlay != null and _active_overlay.has_signal("action_requested"):
		var ok := _active_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("RealmShell: failed to connect overlay action_requested (err=%d)" % ok)

	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)

func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)
