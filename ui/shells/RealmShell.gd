class_name RealmShell
extends Control

signal action_requested(action: Dictionary)

var _active_overlay: Control = null
var _resolve_overlay: Control = null

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
		# flow.resolve is NOT in this dict — handled as a dim modal overlay by _show_resolve_overlay()
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
	# flow.resolve is a dim modal overlay drawn ON TOP of the active venture screen.
	# It does NOT swap _active_overlay — the screen behind stays mounted. (V2-STAGE-004)
	if snap_type == "flow.resolve":
		_show_resolve_overlay(snap)
		return

	# Arriving at any non-resolve type: tear down any existing resolve overlay first
	# so the destination screen shows cleanly without the modal on top.
	if _resolve_overlay != null:
		_resolve_overlay.queue_free()
		_resolve_overlay = null

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

## Renders flow.resolve as a dim modal overlay added LAST to _overlay_root so it draws
## on top of whatever venture screen (_active_overlay) is currently mounted behind it.
## Reuses the existing instance on repeated resolve snapshots (e.g. score update mid-scene).
func _show_resolve_overlay(snap: Dictionary) -> void:
	# Snapshot-reuse: overlay already live — just push updated data.
	if _resolve_overlay != null and is_instance_valid(_resolve_overlay):
		if _resolve_overlay.has_method("set_snapshot"):
			_resolve_overlay.call("set_snapshot", snap)
		return

	# Fresh instantiation.
	var overlay := _resolve_scene.instantiate()
	_overlay_root.add_child(overlay)  # added last → draws on top of _active_overlay
	_resolve_overlay = overlay as Control

	if _resolve_overlay != null and _resolve_overlay.has_signal("action_requested"):
		var ok := _resolve_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("RealmShell: failed to connect resolve overlay action_requested (err=%d)" % ok)

	if _resolve_overlay != null and _resolve_overlay.has_method("set_snapshot"):
		_resolve_overlay.call("set_snapshot", snap)

func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)
