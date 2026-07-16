class_name RealmShell
extends Control

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

var _active_overlay: Control = null
var _resolve_overlay: Control = null
var _layout: Dictionary = {}
var _active_modal_id: StringName = &""
var _active_modal_payload: Dictionary = {}

var _stage_map_scene      := preload("res://ui/screens/venture/StageMapScreen.tscn")
var _stage_explore_scene  := preload("res://ui/screens/venture/StageExploreScreen.tscn")  # V2-STAGE-001
var _combat_board_scene   := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
var _resolve_scene        := preload("res://ui/screens/venture/ResolveScreen.tscn")
var _directive_modal_scene := preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn")
var _prebattle_modal_scene := preload("res://ui/overlays/realm/PrebattleModal.tscn")
var _contact_modal_scene := preload("res://ui/overlays/realm/ContactModal.tscn")
var _engagement_modal_scene := preload("res://ui/overlays/realm/EngagementModal.tscn")
var _situation_modal_scene := preload("res://ui/overlays/realm/SituationModal.tscn")
var _return_home_modal_scene := preload("res://ui/overlays/realm/ReturnHomeModal.tscn")

const EchoCardScene := preload("res://ui/components/EchoCardItem.tscn")
const _ECHO_BAR_HEIGHT := 88.0
const _CHROME_EDGE_INSET := 16.0
const _ECHO_BAR_MAX_WIDTH := 1440.0

var _scene_by_flow_type: Dictionary = {}

@onready var _overlay_root: Control      = $OverlayRoot
@onready var _chrome_layer: CanvasLayer = $ChromeLayer
@onready var _echo_bar_frame: MarginContainer = %EchoBarFrame
@onready var _echo_bar_scroll: ScrollContainer = %EchoBarScroll
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
	# CanvasLayer visibility is independent of its Control parent. Keep Realm
	# chrome inactive whenever routing or an ancestor hides this shell.
	visibility_changed.connect(_sync_chrome_layer_visibility)
	_sync_chrome_layer_visibility()
	_apply_shell_layout()

func _sync_chrome_layer_visibility() -> void:
	if _chrome_layer != null:
		_chrome_layer.visible = is_visible_in_tree()

func set_snapshot(snap: Dictionary) -> void:
	_update_echo_bar(snap)
	_show_overlay_for_type(str(snap.get("type", "")), snap)

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	_apply_shell_layout()
	if _active_overlay != null and _active_overlay.has_method("set_layout"):
		_active_overlay.call("set_layout", _layout)
	if _resolve_overlay != null and _resolve_overlay.has_method("set_layout"):
		_resolve_overlay.call("set_layout", _layout)
	if _active_modal_id != &"" and _can_refresh_active_modal_on_layout():
		var payload := _active_modal_payload.duplicate(true)
		payload["layout"] = _layout.duplicate(true)
		modal_requested.emit(_active_modal_id, payload)

func modal_scene_for(_modal_id: StringName) -> PackedScene:
	if _modal_id == &"realm.resolve":
		return _resolve_scene
	if _modal_id == &"realm.directive":
		return _directive_modal_scene
	if _modal_id == &"realm.prebattle":
		return _prebattle_modal_scene
	if _modal_id == &"realm.contact":
		return _contact_modal_scene
	if _modal_id == &"realm.engagement":
		return _engagement_modal_scene
	if _modal_id == &"realm.situation":
		return _situation_modal_scene
	if _modal_id == &"realm.return_home":
		return _return_home_modal_scene
	return null

func _can_refresh_active_modal_on_layout() -> bool:
	if not visible:
		return false
	if is_inside_tree() and not is_visible_in_tree():
		return false
	return true

# ─────────────────────────────────────────────────────────────
# Echo bar — shell-owned, live-updates on every snapshot
# ─────────────────────────────────────────────────────────────

## Extracts party actors from the snapshot and rebuilds the bar.
## Called on every set_snapshot() — always reflects the latest HP + emotional state.
func _update_echo_bar(snap: Dictionary) -> void:
	var snap_type := str(snap.get("type", ""))
	var data: Dictionary = snap.get("data", {})

	var party: Array = []
	# GUIDE_SPIRIT: the escorted/protected ally is projected into data.actors with is_spirit=true.
	# It may carry faction "echo" (fights alongside) or "structure" (a protected totem) — so the
	# regular faction filter would either miss it or blend it in. We pull it out separately and
	# render it as a distinct gold-accented ally slot at the end of the bar.
	var spirit_actor: Dictionary = {}
	match snap_type:
		"flow.encounter", "flow.keeper_trial", "flow.resolve":
			# Encounter snapshots include all combatants — filter for echoes only.
			for a in data.get("actors", []):
				if not (a is Dictionary):
					continue
				if bool(a.get("is_spirit", false)):
					spirit_actor = a
				elif bool(a.get("is_ally", false)):
					# V2-STAGE-004 P4 S15-UI-A: a combat RECRUITED_ALLY is a normal party-side
					# card (rendered inline, not the single dedicated spirit slot) with the
					# Mist Blue "⊕ ALLY" badge via setup_ally().
					party.append(a)
				elif str(a.get("faction", "")) == "echo":
					party.append(a)
		"flow.stage", "flow.stage_map", "flow.stage_explore":
			# Stage snapshots include party_preview: { name, rank, calling_origin }
			var preview: Variant = data.get("party_preview", [])
			if preview is Array:
				party = preview

	# Rebuild from scratch — max 5 party cards + optional spirit, trivially fast.
	for child in _echo_bar.get_children():
		child.queue_free()
	for actor in party:
		if actor is Dictionary:
			var card: EchoCardItem = EchoCardScene.instantiate()
			_echo_bar.add_child(card)
			if bool(actor.get("is_ally", false)):
				card.setup_ally(actor)
			else:
				card.setup(actor)

	# Append the spirit ally slot last so it reads as "one of the party" but stays distinct.
	if not spirit_actor.is_empty():
		var obj_state: Variant = data.get("objective_state", {})
		var progress_text: String = _spirit_progress_text(
			obj_state if obj_state is Dictionary else {})
		var spirit_card: EchoCardItem = EchoCardScene.instantiate()
		_echo_bar.add_child(spirit_card)
		spirit_card.setup_spirit(spirit_actor, progress_text)


## Composes the spirit ally's one-line objective status from objective_state.
## escort → "Arrived" (destination reached) / "Escorting"; protect → "N rounds left" / "Protect".
## Returns "Fallen" when the spirit is dead. Empty objective_state degrades to "" (no line).
func _spirit_progress_text(obj_state: Dictionary) -> String:
	if obj_state.is_empty():
		return ""
	if obj_state.has("spirit_alive") and not bool(obj_state.get("spirit_alive", true)):
		return "Fallen"
	var guide_mode: String = str(obj_state.get("guide_mode", ""))
	if guide_mode == "escort":
		return "Arrived" if bool(obj_state.get("destination_reached", false)) else "Escorting"
	var rounds_remaining: int = int(obj_state.get("rounds_remaining", 0))
	if rounds_remaining > 0:
		return "%d rounds left" % rounds_remaining
	return "Protect"

func _apply_shell_layout() -> void:
	var insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var logical_size_v: Variant = _layout.get("logical_size", Vector2(1280, 720))
	var logical_size: Vector2 = logical_size_v if logical_size_v is Vector2 else Vector2(1280, 720)
	var safe_left := maxf(_CHROME_EDGE_INSET, ceilf(insets.x))
	var safe_right := maxf(_CHROME_EDGE_INSET, ceilf(insets.z))
	var safe_bottom := maxf(_CHROME_EDGE_INSET, ceilf(insets.w))
	var available_width := maxf(0.0, logical_size.x - safe_left - safe_right)
	var frame_width := minf(_ECHO_BAR_MAX_WIDTH, available_width)
	var frame_left := safe_left + maxf(0.0, (available_width - frame_width) * 0.5)
	if _echo_bar_frame == null:
		_echo_bar_frame = get_node_or_null("%EchoBarFrame") as MarginContainer
	if _echo_bar_scroll == null:
		_echo_bar_scroll = get_node_or_null("%EchoBarScroll") as ScrollContainer
	if _echo_bar_frame != null:
		_echo_bar_frame.offset_left = frame_left
		_echo_bar_frame.offset_right = frame_left + frame_width
		_echo_bar_frame.offset_top = -(_ECHO_BAR_HEIGHT + safe_bottom)
		_echo_bar_frame.offset_bottom = -safe_bottom
	if _echo_bar_scroll != null:
		# Overflow remains discoverable on desktop and touch: the authored
		# horizontal scrollbar appears only when the party exceeds the frame.
		_echo_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_echo_bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


# ─────────────────────────────────────────────────────────────
# Overlay routing
# ─────────────────────────────────────────────────────────────

func _show_overlay_for_type(snap_type: String, snap: Dictionary) -> void:
	# flow.resolve is a dim modal overlay drawn ON TOP of the active venture screen.
	# It does NOT swap _active_overlay — the screen behind stays mounted. (V2-STAGE-004)
	if snap_type == "flow.resolve":
		_emit_realm_modal(&"realm.resolve", {
			"snapshot": snap.duplicate(true),
			"layout": _layout.duplicate(true),
		})
		return

	_clear_tracked_modal()

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
	if _active_overlay != null and _active_overlay.has_signal("modal_requested"):
		var modal_ok := _active_overlay.connect("modal_requested", Callable(self, "_on_overlay_modal_requested"))
		if modal_ok != OK:
			push_warning("RealmShell: failed to connect overlay modal_requested (err=%d)" % modal_ok)

	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)
	if _active_overlay != null and _active_overlay.has_method("set_layout"):
		_active_overlay.call("set_layout", _layout)

## Renders flow.resolve as a dim modal overlay added directly to RealmShell as the LAST
## child so it draws — and receives input — on top of both the active venture screen
## (_active_overlay, inside _overlay_root) AND the persistent %EchoBar (P4 playtest fix).
## Reuses the existing instance on repeated resolve snapshots (e.g. score update mid-scene).
func _show_resolve_overlay(snap: Dictionary) -> void:
	# Snapshot-reuse: overlay already live — just push updated data.
	if _resolve_overlay != null and is_instance_valid(_resolve_overlay):
		if _resolve_overlay.has_method("set_snapshot"):
			_resolve_overlay.call("set_snapshot", snap)
		return

	# Fresh instantiation.
	# P4 playtest fix: parent directly to RealmShell (not _overlay_root) and force
	# it to be the LAST child so it draws — and receives input — above %EchoBar.
	# _overlay_root reserves bottom space for the EchoBar (offset_bottom = -133)
	# and sits BEFORE %EchoBar in the tree, so anything mounted inside it is
	# occluded by the persistent bar. flow.resolve is a true full-screen modal
	# (its DimBackdrop must cover the EchoBar too), so it escapes that reserved
	# region entirely instead of being bounded by it.
	var overlay := _resolve_scene.instantiate()
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	_resolve_overlay = overlay as Control

	if _resolve_overlay != null and _resolve_overlay.has_signal("action_requested"):
		var ok := _resolve_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("RealmShell: failed to connect resolve overlay action_requested (err=%d)" % ok)

	if _resolve_overlay != null and _resolve_overlay.has_method("set_snapshot"):
		_resolve_overlay.call("set_snapshot", snap)
	if _resolve_overlay != null and _resolve_overlay.has_method("set_layout"):
		_resolve_overlay.call("set_layout", _layout)

func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action)

func _on_overlay_modal_requested(modal_id: StringName, payload: Dictionary) -> void:
	_emit_realm_modal(modal_id, payload)

func _emit_realm_modal(modal_id: StringName, payload: Dictionary) -> void:
	var next_payload := payload.duplicate(true)
	next_payload["layout"] = _layout.duplicate(true)
	modal_requested.emit(modal_id, next_payload)

func on_modal_accepted(modal_id: StringName, payload: Dictionary) -> void:
	_active_modal_id = modal_id
	_active_modal_payload = payload.duplicate(true)

func _clear_tracked_modal() -> void:
	_active_modal_id = &""
	_active_modal_payload = {}

func on_modal_dismissed(modal_id: StringName) -> void:
	if modal_id == _active_modal_id:
		_clear_tracked_modal()
