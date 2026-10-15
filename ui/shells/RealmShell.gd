class_name RealmShell
extends Control

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

var _active_overlay: Control = null
var _bar_is_stage := false
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
const _WHY_CARD_GAP := 8.0  # between the why card and the Advance bar

var _scene_by_flow_type: Dictionary = {}

@onready var _overlay_root: Control      = $OverlayRoot
@onready var _chrome_layer: CanvasLayer = $ChromeLayer
@onready var _echo_bar_frame: HBoxContainer = %EchoBarFrame
@onready var _party_card: EchoCardItem = %PartyCard
@onready var _echo_bar_scroll: ScrollContainer = %EchoBarScroll
@onready var _echo_bar:     HBoxContainer = %EchoBar
@onready var _why_card: StageWhyCard = %StageWhyCard

# The last stop mark: the snapshot's travel_why for the why card, and the control that holds the glyph.
var _stop_why: Dictionary = {}
var _stop_holder: Control = null
var _why_opener: Control = null
var _safe_rect := Rect2(16, 16, 1248, 688)
var _frame_width := 1248.0
# The mark is set but its beat has not come: it is invisible and a tap on it does nothing yet.
var _mark_hidden := false
# A press outside the card closed it; the tap that follows on release must not reopen it.
var _press_closed_card := false
var _pres: Dictionary = {}

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
	_party_card.setup_party(StageWhyText.text("ui", "party_card_label"))
	_party_card.card_pressed.connect(_on_party_card_pressed)
	_why_card.closed.connect(_on_why_closed)
	_apply_shell_layout()

func _sync_chrome_layer_visibility() -> void:
	if _chrome_layer != null:
		_chrome_layer.visible = is_visible_in_tree()

func set_snapshot(snap: Dictionary) -> void:
	_update_echo_bar(snap)
	# The screen first: on a travel snapshot it announces the walk, and the mark waits for its beat.
	_show_overlay_for_type(str(snap.get("type", "")), snap)
	_update_stop_mark(snap)

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
	_bar_is_stage = snap_type.begins_with("flow.stage")
	var data: Dictionary = snap.get("data", {})
	_party_card.visible = _bar_is_stage

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
			var preview: Variant = data.get("party_preview", [])
			if preview is Array:
				party = preview

	# Cards live across snapshots and are updated in place. A card that took a press must still be
	# there for its release, and the bar must not jump. Cards are matched by kind and actor id (by
	# kind and position when the id is empty); new ones are added, gone ones removed.
	var wanted: Array[Dictionary] = []
	var empty_ids: Dictionary = {}
	for actor in party:
		if actor is Dictionary:
			var kind := "ally" if bool(actor.get("is_ally", false)) else "plain"
			wanted.append({ "key": _card_key(kind, str(actor.get("id", "")), empty_ids), "kind": kind, "actor": actor, "progress": "" })
	# Append the spirit ally slot last so it reads as "one of the party" but stays distinct.
	if not spirit_actor.is_empty():
		var obj_state: Variant = data.get("objective_state", {})
		var progress_text: String = _spirit_progress_text(
			obj_state if obj_state is Dictionary else {})
		wanted.append({ "key": _card_key("spirit", str(spirit_actor.get("id", "")), empty_ids), "kind": "spirit", "actor": spirit_actor, "progress": progress_text })

	var existing: Dictionary = {}
	for child in _echo_bar.get_children():
		if child is EchoCardItem and not child.is_queued_for_deletion():
			existing[(child as EchoCardItem).slot_key] = child
	for i in range(wanted.size()):
		var entry: Dictionary = wanted[i]
		var card: EchoCardItem = existing.get(entry["key"]) as EchoCardItem
		if card == null:
			card = EchoCardScene.instantiate()
			_echo_bar.add_child(card)
			card.card_pressed.connect(_on_echo_card_pressed.bind(card))
			card.slot_key = str(entry["key"])
		else:
			existing.erase(entry["key"])
		match str(entry["kind"]):
			"ally":
				card.setup_ally(entry["actor"])
			"spirit":
				card.setup_spirit(entry["actor"], str(entry["progress"]))
			_:
				card.setup(entry["actor"])
		_echo_bar.move_child(card, i)
	for gone in existing.values():
		_echo_bar.remove_child(gone)
		(gone as Node).queue_free()
	_fit_echo_scroll()


## The party card, the gap and the cards form one centred group. The cards' scroll area takes the width
## the cards need, or what is left of the frame, so a long party scrolls and the party card stays pinned.
func _fit_echo_scroll() -> void:
	if _echo_bar_scroll == null or _echo_bar_frame == null or _party_card == null:
		return
	var left_of_cards := 0.0
	if _party_card.visible:
		left_of_cards = _party_card.custom_minimum_size.x + _echo_bar_frame.get_theme_constant("separation")
	_echo_bar_scroll.custom_minimum_size.x = minf(_echo_bar.get_combined_minimum_size().x, maxf(0.0, _frame_width - left_of_cards))


static func _card_key(kind: String, actor_id: String, empty_ids: Dictionary) -> String:
	if not actor_id.is_empty():
		return "%s|%s" % [kind, actor_id]
	var n := int(empty_ids.get(kind, 0))
	empty_ids[kind] = n + 1
	return "%s|#%d" % [kind, n]


# ─────────────────────────────────────────────────────────────
# Stop mark (D-41, D-42) and why card (D-32)
# ─────────────────────────────────────────────────────────────

## The mark is drawn from snapshot.stop, so it survives a reload. It sits on the named Echo's card,
## or on the party card when no Echo is named. The card is found by stop.echo_id; the display name
## in travel_why is the fallback for a row without an id. The id is never shown.
func _update_stop_mark(snap: Dictionary) -> void:
	var data: Dictionary = snap.get("data", {})
	var stop_v: Variant = data.get("stop", {})
	var stop: Dictionary = stop_v if stop_v is Dictionary else {}
	var why_v: Variant = data.get("travel_why", {})
	_stop_why = why_v if why_v is Dictionary else {}
	var pres_v: Variant = data.get("presentation", {})
	_pres = pres_v if pres_v is Dictionary else {}
	_why_card.open_seconds = StopMarkMotion.pres(_pres, "why_open_seconds", 0.15)
	_why_card.close_seconds = StopMarkMotion.pres(_pres, "why_close_seconds", 0.1)
	_party_card.presentation = _pres
	var kind := str(stop.get("kind", "")) if str(snap.get("type", "")) == "flow.stage_explore" else ""
	if StopGlyphs.texture(kind) == null:
		kind = ""
	var named := str(_stop_why.get("named_echo_name", ""))
	var echo_id := str(stop.get("echo_id", ""))
	var holder: EchoCardItem = null
	for child in _echo_bar.get_children():
		if not (child is EchoCardItem) or kind == "" or holder != null or echo_id.is_empty():
			continue
		var card := child as EchoCardItem
		var by_id := not card.actor_id().is_empty()
		if (by_id and card.actor_id() == echo_id) or (not by_id and not named.is_empty() and card.display_name() == named):
			holder = card
	var open_name := StageWhyText.text("ui", "open_why")
	var fade := StopMarkMotion.pres(_pres, "reduced_motion_fade_seconds" if StopMarkMotion.reduced else "glyph_fade_seconds", 0.2)
	for child in _echo_bar.get_children():
		if child is EchoCardItem:
			var card := child as EchoCardItem
			card.presentation = _pres
			if child == holder:
				if _mark_hidden and card.has_stop_glyph():
					card.swap_stop_glyph_after_fade(kind, open_name, fade)
				else:
					card.set_stop_glyph(kind, open_name)
			elif _mark_hidden and card.has_stop_glyph():
				card.fade_out_stop_glyph(fade)
			else:
				card.set_stop_glyph("", open_name)
	var party_name := _party_card.party_label.text
	if holder == null and kind != "":
		if _mark_hidden and _party_card.has_stop_glyph():
			_party_card.swap_stop_glyph_after_fade(kind, party_name, fade)
		else:
			_party_card.set_stop_glyph(kind, party_name)
	elif _mark_hidden and _party_card.has_stop_glyph():
		_party_card.fade_out_stop_glyph(fade)
	else:
		_party_card.set_stop_glyph("", party_name)
	_stop_holder = holder if holder != null else (_party_card if kind != "" else null)
	if _stop_holder == null:
		_mark_hidden = false
		_why_card.close()
	elif _mark_hidden:
		_stop_holder.call("hide_stop_glyph_for_beat")
	elif _why_card.is_open():
		_why_card.open(_stop_why)
		_place_why_card()


func _toggle_why(opener: Control) -> void:
	if _mark_hidden:
		return
	if _why_card.is_open():
		_why_card.close()
	elif _stop_holder != null or _has_journey_entry():
		_why_opener = opener
		_why_card.open(_stop_why)
		_place_why_card()


## The last journey entry: travel_why with at least one non-empty slot.
func _has_journey_entry() -> bool:
	return _stop_why.values().any(func(v: Variant) -> bool: return str(v) != "")


## The party token is an alias for the party card: the mark, else the last journey entry. Its tap fires on release; a press that just closed the
## card already made the net result "closed", so the release must not open it again.
func _on_why_requested() -> void:
	if _press_closed_card:
		_press_closed_card = false
		return
	if not _mark_hidden and not _why_card.is_open() and (_stop_holder != null or _has_journey_entry()):
		_why_opener = _stop_holder if _stop_holder != null else _party_card
		_why_card.open(_stop_why)
		_place_why_card()


## The card opens centred above the tapped card, inside the safe area, with its bottom edge just above
## the Advance bar.
func _place_why_card() -> void:
	var source: Control = _why_opener if _why_opener != null and is_instance_valid(_why_opener) else _stop_holder
	if source == null:
		return
	var rect := source.get_global_rect()
	var card_size := _why_card.get_combined_minimum_size()
	var bar_top := _echo_bar_frame.get_global_rect().position.y
	if _active_overlay != null and _active_overlay.has_method("advance_bar_top"):
		bar_top = float(_active_overlay.call("advance_bar_top"))
	_why_card.size = card_size
	_why_card.position = Vector2(
		clampf(rect.get_center().x - card_size.x * 0.5, _safe_rect.position.x, maxf(_safe_rect.position.x, _safe_rect.end.x - card_size.x)),
		maxf(_safe_rect.position.y, bar_top - _WHY_CARD_GAP - card_size.y))


func _on_why_closed() -> void:
	if _why_opener != null and is_instance_valid(_why_opener) and _why_opener.is_visible_in_tree():
		_why_opener.grab_focus()
	_why_opener = null


## The next Advance has started: the old mark goes dim and the card closes. A new snapshot redraws both.
func _on_advance_started() -> void:
	_why_card.close()
	_stop_motion_off()
	if _stop_holder != null and not _mark_hidden:
		_stop_holder.call("dim_stop_glyph")


func _on_travel_started() -> void:
	_stop_motion_off()
	_mark_hidden = true


## The beats come from the screen's walk tween, so the shell and the screen share one clock.
func _on_stop_beat(beat: StringName) -> void:
	if _stop_holder == null:
		return
	match beat:
		&"mark":
			_mark_hidden = false
			_stop_holder.call("settle_stop_glyph", _pres)
		&"pulse":
			if _stop_holder is EchoCardItem:
				(_stop_holder as EchoCardItem).pulse_portrait(_pres)


func _stop_motion_off() -> void:
	for child in _echo_bar.get_children():
		if child is EchoCardItem:
			(child as EchoCardItem).stop_motion()
	_party_card.stop_motion()


func _exit_tree() -> void:
	_stop_motion_off()


# A press outside the card closes it and is not consumed, so the Advance button still gets it.
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.is_pressed():
		set_deferred("_press_closed_card", false)  # after this release's tap has been handled
	if not _why_card.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		_why_card.close()
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		var point: Vector2 = (event as InputEventMouse).position if event is InputEventMouse else (event as InputEventScreenTouch).position
		if not _why_card.get_global_rect().has_point(point) \
				and not (_stop_holder != null and _stop_holder.get_global_rect().has_point(point)) \
				and not (_why_opener != null and is_instance_valid(_why_opener) and _why_opener.get_global_rect().has_point(point)):
			_press_closed_card = true
			_why_card.close()


## ANSWERS.md #77: a card tap locks the active screen's camera onto that actor. On a Stage
## snapshot the id only matches the stop glyph, so the tap means the party ("").
func _on_echo_card_pressed(actor_id: String, card: EchoCardItem) -> void:
	if card.has_stop_glyph():
		_toggle_why(card)
	if _active_overlay != null and _active_overlay.has_method("select_board_target"):
		_active_overlay.call("select_board_target", "" if _bar_is_stage else actor_id)


## A tap on the party card: the why card of the stop mark, or the last journey entry when no mark shows.
func _on_party_card_pressed(_actor_id: String) -> void:
	if _press_closed_card:
		_press_closed_card = false
		return
	_toggle_why(_party_card)


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
	_frame_width = frame_width
	_safe_rect = Rect2(safe_left, maxf(_CHROME_EDGE_INSET, ceilf(insets.y)), available_width, maxf(0.0, logical_size.y - maxf(_CHROME_EDGE_INSET, ceilf(insets.y)) - safe_bottom))
	var frame_left := safe_left + maxf(0.0, (available_width - frame_width) * 0.5)
	if _echo_bar_frame == null:
		_echo_bar_frame = get_node_or_null("%EchoBarFrame") as HBoxContainer
	if _echo_bar_scroll == null:
		_echo_bar_scroll = get_node_or_null("%EchoBarScroll") as ScrollContainer
	_fit_echo_scroll()
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
	if _why_card != null and _why_card.is_open():
		_place_why_card()


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
	if _active_overlay != null and _active_overlay.has_signal("advance_started"):
		_active_overlay.connect("advance_started", _on_advance_started)
	if _active_overlay != null and _active_overlay.has_signal("travel_started"):
		_active_overlay.connect("travel_started", _on_travel_started)
	if _active_overlay != null and _active_overlay.has_signal("stop_beat"):
		_active_overlay.connect("stop_beat", _on_stop_beat)
	if _active_overlay != null and _active_overlay.has_signal("why_requested"):
		_active_overlay.connect("why_requested", _on_why_requested)
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
