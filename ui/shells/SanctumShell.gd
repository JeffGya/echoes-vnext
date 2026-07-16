extends Control

class_name SanctumShell

@onready var overlay_root: Control = %OverlayRoot
@onready var _world_layer: CanvasLayer = $WorldLayer
@onready var spatial_layer: Control = $WorldLayer/SpatialLayer
@onready var spatial_view: Node2D = $WorldLayer/SpatialLayer/SpatialView
@onready var camera: Camera2D = $WorldLayer/SpatialLayer/SpatialView/Camera2D
@onready var spatial_renderer: Node2D = $WorldLayer/SpatialLayer/SpatialView/SanctumSpatialRenderer2
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _overlay_container: Control = $UILayer/Control
@onready var _chrome_layer: CanvasLayer = $ChromeLayer
@onready var _notification_layer: CanvasLayer = $NotificationLayer
@onready var _notification_overlay: ColorRect = %NotificationOverlay
@onready var _notification_anchor: MarginContainer = %NotificationAnchor
@onready var _notification_panel: PanelContainer = %NotificationPanel
@onready var _notification_body_scroll: ScrollContainer = %NotificationBodyScroll
@onready var _notification_title: Label = %NotificationTitle
@onready var _notification_body: Label = %NotificationBody
@onready var _notification_detail: Label = %NotificationDetail
@onready var _notification_amount: Label = %NotificationAmount
@onready var _notification_dismiss: Button = %NotificationDismiss
@onready var _bottom_rail: Control = %BottomRail
@onready var _party_button: Button = %PartyButton
@onready var _summon_button: Button = %SummonButton
@onready var _realm_button: Button = %RealmButton
@onready var _vows_button: Button = %VowsButton
@onready var _weaving_button: Button = %WeavingButton

signal action_requested(action: Dictionary)
signal modal_requested(modal_id: StringName, payload: Dictionary)

var _active_overlay: Control = null
var _layout: Dictionary = {}
var _active_modal_id: StringName = &""
var _active_modal_payload: Dictionary = {}
# Nav actions cached from the last flow.sanctum snapshot.
# The shell owns the persistent nav bar so all sanctum-family screens share it.
var _cached_nav: Dictionary = {}

# Camera config (Phase B)
var _zoom_levels := [Vector2(0.5, 0.5), Vector2(1.0, 1.0), Vector2(1.5, 1.5), Vector2(2.0, 2.0)]
var _zoom_index := 2 # Start at 1.5× (index 2)
var _pan_speed  := 2.5

var _is_panning := false
var _last_pointer_pos := Vector2.ZERO
var _current_snap_type := ""
var _echo_detail_open := false
var _institutions_open := false
var _placement_mode := false
var _placement_building_id := ""
var _placement_selected_cell: Variant = null  # Vector2i or null
var _placement_valid_cells: Array = []
var _placement_floor_cells: Array = []
var _placement_occupied_cells: Array = []
var _saved_camera_position := Vector2.ZERO
var _saved_camera_zoom := Vector2.ONE
var _detail_zoom := Vector2(2.9, 2.9)
var _camera_tween: Tween
var _nav_bar_tween: Tween
var _notification_tween: Tween
var _notification_queue: Array = []
var _current_notification_id: String = ""

const _TONE_VARIATIONS: Dictionary = {
	"neutral":  &"SanctumNoticeNeutral",
	"positive": &"SanctumNoticePositive",
	"warning":  &"SanctumNoticeWarning",
	"negative": &"SanctumNoticeNegative",
}
const _TONE_AMOUNT_COLORS: Dictionary = {
	"neutral":  Color(0.176, 0.416, 0.310, 1),
	"positive": Color(0.176, 0.416, 0.310, 1),
	"warning":  Color(0.478, 0.310, 0.059, 1),
	"negative": Color(0.549, 0.157, 0.141, 1),
}
const _TONE_OVERLAY_COLORS: Dictionary = {
	"neutral":  Color(0.12, 0.20, 0.22, 0.45),
	"positive": Color(0.08, 0.18, 0.10, 0.45),
	"warning":  Color(0.22, 0.16, 0.04, 0.45),
	"negative": Color(0.22, 0.08, 0.06, 0.45),
}

# Camera clamp (Phase B)
const TILE_W := 72.0
const TILE_H := 36.0
const FLOOR_PAD := Vector2(240.0, 240.0) # wide enough to show full valid placement zone beyond floor edges
const _RAIL_HEIGHT := 88
const _RAIL_GAP := 8
const _CHROME_EDGE_INSET := 16
const _RAIL_SIDE_MARGIN := 16
const _RAIL_MAX_WIDTH := 980.0
const _NOTIFICATION_TOP_GAP := 32.0
const _NOTIFICATION_RAIL_GAP := 8.0
const _NOTIFICATION_COMPACT_MAX_WIDTH := 560.0
const _NOTIFICATION_STANDARD_MAX_WIDTH := 640.0
const _NOTIFICATION_WIDE_MAX_WIDTH := 720.0
const _NOTIFICATION_COMPACT_HEIGHT := 240.0
const _NOTIFICATION_STANDARD_HEIGHT := 260.0
const _NOTIFICATION_WIDE_HEIGHT := 280.0

var _floor_bounds_sv := Rect2(Vector2.ZERO, Vector2.ZERO) # floor bounds in SpatialView-local pixels
 
# PackedScenes will be preloaded later
var _scene_by_flow_type: Dictionary = {}
var _sanctum_scene := preload("res://ui/screens/sanctum/SanctumScreen.tscn")
var _summon_scene := preload("res://ui/screens/sanctum/SummonScreen.tscn")
var _echo_party_scene := preload("res://ui/screens/sanctum/EchoPartyScreen.tscn")
var _realm_scene := preload("res://ui/screens/realm/RealmSelectScreen.tscn")
var _vow_scene := preload("res://ui/screens/sanctum/VowScreen.tscn")  # VOW-001
var _weaving_rite_scene := preload("res://ui/screens/sanctum/WeavingRiteScreen.tscn")  # V2-WEAVE-002
var _modal_scene_by_id: Dictionary = {
	&"summon_reveal": preload("res://ui/overlays/SummonRevealOverlay.tscn"),
	&"rank_up": preload("res://ui/overlays/RankUpOverlay.tscn"),
	&"awakening": preload("res://ui/overlays/sanctum/AwakeningModal.tscn"),
	&"companion_invite": preload("res://ui/overlays/sanctum/CompanionInviteModal.tscn"),
	&"vow_moment": preload("res://ui/overlays/sanctum/VowMomentModal.tscn"),
	&"institution_detail": preload("res://ui/overlays/sanctum/InstitutionDetailModal.tscn"),
	&"calling_info": preload("res://ui/overlays/sanctum/CallingInfoModal.tscn"),
}

func _ready() -> void:
	_scene_by_flow_type = {
		"flow.sanctum": _sanctum_scene,
		"flow.summon": _summon_scene,
		"flow.echo_party": _echo_party_scene,
		"flow.realm_select": _realm_scene,
		"flow.vow_manage": _vow_scene,  # VOW-001
		"flow.weaving_rite": _weaving_rite_scene,  # V2-WEAVE-002
	}

	_center_spatial_view()
	spatial_layer.resized.connect(_on_spatial_layer_resized)

	camera.zoom = _zoom_levels[_zoom_index]
	_recompute_floor_bounds()
	_clamp_camera_to_floor()
	# CanvasLayer does not inherit visibility from its Control parent.
	# Sync world, UI, chrome, and notification layers whenever the shell changes.
	visibility_changed.connect(_sync_ui_layer_visibility)
	_sync_ui_layer_visibility()
	_bind_nav_bar()
	_notification_panel.visible = false
	_notification_panel.modulate.a = 0.0
	_notification_overlay.visible = false
	_notification_dismiss.pressed.connect(_dismiss_notification)
	_update_safe_layout_frames()

func _sync_ui_layer_visibility() -> void:
	var effective_visible := is_visible_in_tree()
	_world_layer.visible = effective_visible
	_ui_layer.visible = effective_visible
	_chrome_layer.visible = effective_visible
	_notification_layer.visible = effective_visible
	# Camera2D.enabled is independent of node visibility in Godot 4.
	# Disable it when SanctumShell is hidden so it does not affect the viewport
	# while RealmShell (or any other screen) is active.
	camera.enabled = effective_visible


func set_snapshot(snap: Dictionary) -> void:
	_current_snap_type = str(snap.get("type", ""))
	_active_modal_id = &""
	_active_modal_payload = {}

	# 1) Update spatial background (read-only visual layer)
	# For now this is a stub. Later we will add proper renderer script.
	if spatial_renderer != null and spatial_renderer.has_method("render"):
		spatial_renderer.call("render", snap)
		_recompute_floor_bounds()
		if not _echo_detail_open:
			_center_camera_on_floor()

	# 2) Swap overlay UI based on flow snapshot type
	_show_overlay_for_type(_current_snap_type, snap)

	# 3) Cache nav actions from flow.sanctum and rebuild the persistent shell nav bar.
	# The cache is safe: cta.enter_stage (only conditional action) can only change via
	# flow.realm_select, which always returns to flow.sanctum before the player sees the
	# nav again — so the cache is never stale.
	if _current_snap_type == "flow.sanctum":
		var actions_v: Variant = snap.get("actions", {})
		if actions_v is Dictionary:
			_cached_nav = {}
			var actions_dict: Dictionary = actions_v
			for k: String in actions_dict.keys():
				if k.begins_with("nav.") or k.begins_with("cta."):
					var val: Variant = actions_dict[k]
					if val is Dictionary:
						_cached_nav[k] = val
			_bind_nav_bar()
	elif _echo_detail_open:
		_restore_echo_detail_shell_state()
	_update_rail_tone(_current_snap_type)
	_maybe_show_return_notice(snap)

func set_layout(layout: Dictionary) -> void:
	_layout = layout.duplicate(true)
	_update_safe_layout_frames()
	_refresh_active_modal_layout()

func modal_scene_for(modal_id: StringName) -> PackedScene:
	var scene_v: Variant = _modal_scene_by_id.get(modal_id, null)
	return scene_v if scene_v is PackedScene else null

func on_modal_dismissed(modal_id: StringName) -> void:
	if _active_modal_id != modal_id:
		return
	_active_modal_id = &""
	_active_modal_payload = {}

func bottom_content_exclusion() -> int:
	return _bottom_chrome_inset() + _RAIL_HEIGHT + _RAIL_GAP
	
func _show_overlay_for_type(snap_type: String, snap: Dictionary) -> void:
	if not _scene_by_flow_type.has(snap_type):
		push_warning("SanctumShell: no overlay mapped for snapshot type: " + snap_type)
		return
	
	var packed: PackedScene = _scene_by_flow_type[snap_type]
	if packed == null:
		return
	
	# If the same overlay scene is already active, refresh it in place.
	if _active_overlay != null and _active_overlay.scene_file_path == packed.resource_path:
		if _active_overlay.has_method("set_snapshot"):
			_active_overlay.call("set_snapshot", snap)
		_update_safe_layout_frames()
		return
	
	# Otherwise replace overlay
	if _active_overlay != null:
		if _echo_detail_open:
			_restore_echo_detail_shell_state()
		_active_overlay.queue_free()
		_active_overlay = null
		
	var overlay := packed.instantiate()
	overlay_root.add_child(overlay)
	_active_overlay = overlay as Control
	
	# Bubble action_requested up to AppRoot
	if _active_overlay != null and _active_overlay.has_signal("action_requested"):
		var ok := _active_overlay.connect("action_requested", Callable(self, "_on_overlay_action_requested"))
		if ok != OK:
			push_warning("SanctumShell: failed to connect overlay action_requested (err=%d)" % ok)
	if _active_overlay != null and _active_overlay.has_signal("modal_requested"):
		var modal_ok := _active_overlay.connect("modal_requested", Callable(self, "_on_overlay_modal_requested"))
		if modal_ok != OK:
			push_warning("SanctumShell: failed to connect overlay modal_requested (err=%d)" % modal_ok)
	if _active_overlay != null and _active_overlay.has_signal("echo_detail_closed"):
		var close_ok := _active_overlay.connect("echo_detail_closed", Callable(self, "_on_overlay_echo_detail_closed"))
		if close_ok != OK:
			push_warning("SanctumShell: failed to connect echo_detail_closed (err=%d)" % close_ok)
		
	# Give snapshot to overlay
	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)
	if _active_overlay != null and _active_overlay.has_method("set_layout"):
		_active_overlay.call("set_layout", _layout)
	_update_safe_layout_frames()

func _update_safe_layout_frames() -> void:
	var safe: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var safe_left := int(ceilf(safe.x))
	var safe_right := int(ceilf(safe.z))
	if _bottom_rail != null:
		var bottom_inset := _bottom_chrome_inset()
		var logical_size_v: Variant = _layout.get("logical_size", Vector2(1280, 720))
		var logical_size: Vector2 = logical_size_v if logical_size_v is Vector2 else Vector2(1280, 720)
		var viewport_w := maxf(320.0, float(logical_size.x))
		var available_w := maxf(320.0, viewport_w - float(safe_left + safe_right + (_RAIL_SIDE_MARGIN * 2)))
		var rail_w := minf(_RAIL_MAX_WIDTH, available_w)
		var rail_left := float(safe_left + _RAIL_SIDE_MARGIN) + maxf(0.0, (available_w - rail_w) * 0.5)
		_bottom_rail.offset_top = -float(_RAIL_HEIGHT + bottom_inset)
		_bottom_rail.offset_bottom = -float(bottom_inset)
		_bottom_rail.offset_left = rail_left
		_bottom_rail.offset_right = rail_left + rail_w
	_update_notification_layout()
	if _active_overlay != null:
		if _active_overlay.has_method("set_bottom_content_exclusion"):
			_active_overlay.call("set_bottom_content_exclusion", bottom_content_exclusion())
		if _active_overlay.has_method("set_layout"):
			_active_overlay.call("set_layout", _layout)

func _update_notification_layout() -> void:
	if _notification_anchor == null:
		return
	var logical_size_v: Variant = _layout.get("logical_size", Vector2(1280, 720))
	var logical_size: Vector2 = logical_size_v if logical_size_v is Vector2 else Vector2(1280, 720)
	var safe: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	var safe_left := maxf(16.0, ceilf(safe.x))
	var safe_top := maxf(16.0, ceilf(safe.y))
	var safe_right := maxf(16.0, ceilf(safe.z))
	var safe_bottom := maxf(16.0, ceilf(safe.w))
	var profile: StringName = _layout.get("profile", &"standard")
	var width_cap := _NOTIFICATION_STANDARD_MAX_WIDTH
	var height_cap := _NOTIFICATION_STANDARD_HEIGHT
	match profile:
		&"compact":
			width_cap = _NOTIFICATION_COMPACT_MAX_WIDTH
			height_cap = _NOTIFICATION_COMPACT_HEIGHT
		&"wide":
			width_cap = _NOTIFICATION_WIDE_MAX_WIDTH
			height_cap = _NOTIFICATION_WIDE_HEIGHT
	var available_width := maxf(0.0, logical_size.x - safe_left - safe_right)
	var card_width := minf(width_cap, available_width)
	var card_left := safe_left + maxf(0.0, (available_width - card_width) * 0.5)
	var card_top := safe_top + _NOTIFICATION_TOP_GAP
	var rail_top := logical_size.y - safe_bottom - float(_RAIL_HEIGHT)
	var available_height := maxf(0.0, rail_top - _NOTIFICATION_RAIL_GAP - card_top)
	var card_height := minf(height_cap, available_height)
	_notification_anchor.offset_left = card_left
	_notification_anchor.offset_top = card_top
	_notification_anchor.offset_right = card_left + card_width
	_notification_anchor.offset_bottom = card_top + card_height
	if _notification_body_scroll != null:
		_notification_body_scroll.custom_minimum_size.y = 72.0 if profile == &"compact" else 88.0

func _unhandled_input(event: InputEvent) -> void:
	# Don't steal UI clicks: only pan when dragging with MMB or Space+LMB for now.
	# We'll add touch-pan next (one finger drag on empty space). After we decide UI gesture rules.
	
	# --- Zoom wheel (dev convenience) ---
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if _echo_detail_open:
			return

		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_toggle_zoom(mb.button_index == MOUSE_BUTTON_WHEEL_UP)
			get_viewport().set_input_as_handled()
			return

		# Space + LMB starts panning (trackpad friendly)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and Input.is_key_pressed(KEY_SPACE):
				_is_panning = true
				get_viewport().set_input_as_handled()
				return
			if not mb.pressed and _is_panning:
				_is_panning = false
				get_viewport().set_input_as_handled()
				return
	
	# Pinch-to-zoom (mobile) — smooth continuous zoom, NOT snap-to-level.
	# Works in both normal view and placement mode.
	if event is InputEventMagnifyGesture:
		if _echo_detail_open:
			return
		var factor := (event as InputEventMagnifyGesture).factor
		var new_zoom := (camera.zoom * factor).clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
		camera.zoom = new_zoom
		_clamp_camera_to_floor()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventPanGesture:
		if _echo_detail_open:
			return
		var pg := event as InputEventPanGesture
		# pg.delta is already a screen-space delta
		_pan_by_delta(pg.delta)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if _echo_detail_open:
			return
		if _is_panning:
			var mm := event as InputEventMouseMotion
			_pan_by_delta(mm.relative)
			get_viewport().set_input_as_handled()
			return

	# Z toggles zoom levels
	if event is InputEventKey and event.pressed and not event.echo:
		if _echo_detail_open:
			return
		var k := event as InputEventKey
		if k.keycode == KEY_Z:
			_zoom_index = (_zoom_index + 1) % _zoom_levels.size()
			camera.zoom = _zoom_levels[_zoom_index]
			_clamp_camera_to_floor()
			get_viewport().set_input_as_handled()
			return


func _input(event: InputEvent) -> void:
	if _echo_detail_open:
		return
	if _current_snap_type != "flow.sanctum":
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Input.is_key_pressed(KEY_SPACE):
		return
	if _control_or_ancestor_is_interactive(get_viewport().gui_get_hovered_control()):
		return

	if _placement_mode:
		# _input() fires before GUI/mouse_filter processing, so placement taps are
		# caught here regardless of what Controls are in the scene tree.
		# Use gui_get_hover_control() to detect when the cursor is over a UI button
		# (Cancel, Confirm, strip) and let it handle its own click via _gui_input.
		if _try_placement_tap(mb.position):
			get_viewport().set_input_as_handled()
		return

	# Normal mode: check hit, route by kind.
	if _try_open_occupant_at_viewport_point(mb.position):
		get_viewport().set_input_as_handled()

func _bottom_chrome_inset() -> int:
	var safe: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	return maxi(_CHROME_EDGE_INSET, int(ceilf(safe.w)))

func _control_or_ancestor_is_interactive(control: Control) -> bool:
	var current := control
	while current != null:
		if current is BaseButton or current is LineEdit or current is TextEdit \
				or current is Range or current is ItemList or current is Tree:
			return true
		current = current.get_parent() as Control
	return false


# ---- HELPERS ----
func _on_overlay_action_requested(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	# Intercept placement mode lifecycle — do NOT forward to FlowRuntime.
	if action_type == "ui.enter_placement_mode":
		var payload_v: Variant = action.get("payload", {})
		var payload: Dictionary = payload_v if payload_v is Dictionary else {}
		var inst_id    := str(payload.get("institution_id", ""))
		var cells_v: Variant  = payload.get("valid_cells", [])
		var floor_v: Variant  = payload.get("floor_cells", [])
		var occ_v: Variant    = payload.get("occupied_cells", [])
		var cells: Array      = cells_v if cells_v is Array else []
		var floor_cells: Array = floor_v if floor_v is Array else []
		var occ_cells: Array   = occ_v if occ_v is Array else []
		_enter_placement_mode(inst_id, cells, floor_cells, occ_cells)
		return
	if action_type == "ui.exit_placement_mode":
		_exit_placement_mode()
		return
	if action_type == "ui.close_institutions_panel":
		close_institutions_panel()
		return
	action_requested.emit(action)

func _on_overlay_modal_requested(modal_id: StringName, payload: Dictionary) -> void:
	if modal_id == &"":
		_active_modal_id = &""
		_active_modal_payload = {}
		return
	modal_requested.emit(modal_id, _payload_with_layout(payload))

func on_modal_accepted(modal_id: StringName, payload: Dictionary) -> void:
	_active_modal_id = modal_id
	_active_modal_payload = payload.duplicate(true)

func _refresh_active_modal_layout() -> void:
	if _active_modal_id == &"":
		return
	if not visible:
		return
	modal_requested.emit(_active_modal_id, _payload_with_layout(_active_modal_payload))

func _payload_with_layout(payload: Dictionary) -> Dictionary:
	var next := payload.duplicate(true)
	next["layout"] = _layout.duplicate(true)
	return next


func _on_overlay_echo_detail_closed() -> void:
	_restore_echo_detail_shell_state()

func _bind_nav_bar() -> void:
	_bind_button(_party_button, _action_for_slot("nav.echo_party"), "Party")
	_bind_button(_summon_button, _action_for_slot("nav.summon"), "Summon")
	_bind_realm_button()
	_bind_button(_vows_button, _action_for_slot("nav.vow_manage"), "Vows")
	_bind_button(_weaving_button, _action_for_slot("nav.weaving_rite"), "Weaving")

func _maybe_show_return_notice(snap: Dictionary) -> void:
	if _current_snap_type != "flow.sanctum":
		return
	var data_v: Variant = snap.get("data", {})
	if not (data_v is Dictionary):
		return
	var notice_v: Variant = (data_v as Dictionary).get("return_notification", {})
	if not (notice_v is Dictionary) or (notice_v as Dictionary).is_empty():
		return
	push_notification(notice_v as Dictionary)

func push_notification(notif: Dictionary) -> void:
	var notif_id := str(notif.get("id", ""))
	if notif_id.is_empty() or notif_id == _current_notification_id:
		return
	for queued: Variant in _notification_queue:
		if str((queued as Dictionary).get("id", "")) == notif_id:
			return
	if _notification_panel.visible:
		_notification_queue.append(notif)
	else:
		_show_notification(notif)

func _show_notification(notif: Dictionary) -> void:
	_current_notification_id = str(notif.get("id", ""))

	_notification_title.text = str(notif.get("title", ""))
	_notification_body.text = str(notif.get("body", ""))
	var detail := str(notif.get("detail", ""))
	_notification_detail.text = detail
	_notification_detail.visible = not detail.is_empty()
	var amount := str(notif.get("amount", ""))
	_notification_amount.text = amount
	_notification_amount.visible = not amount.is_empty()

	var tone := str(notif.get("tone", "neutral"))
	var variation: StringName = _TONE_VARIATIONS.get(tone, &"SanctumNoticeNeutral")
	_notification_panel.theme_type_variation = variation
	var amount_color: Color = _TONE_AMOUNT_COLORS.get(tone, Color(0.176, 0.416, 0.310, 1))
	_notification_amount.add_theme_color_override("font_color", amount_color)

	var blocking := bool(notif.get("blocking_overlay", false))
	if blocking:
		_notification_overlay.color = _TONE_OVERLAY_COLORS.get(tone, Color(0.12, 0.20, 0.22, 0.45))
		_notification_overlay.visible = true
	else:
		_notification_overlay.visible = false

	if _notification_tween != null and _notification_tween.is_running():
		_notification_tween.kill()
	_notification_panel.visible = true
	_notification_panel.modulate.a = 0.0
	_notification_tween = create_tween()
	_notification_tween.tween_property(_notification_panel, "modulate:a", 1.0, 0.22)

	var auto_dismiss := bool(notif.get("auto_dismiss", true))
	if auto_dismiss:
		var duration := maxf(float(notif.get("duration_seconds", 4.2)), 1.5)
		_notification_tween.tween_interval(duration)
		_notification_tween.tween_property(_notification_panel, "modulate:a", 0.0, 0.25)
		_notification_tween.tween_callback(_on_notification_hidden)

func _on_notification_hidden() -> void:
	_notification_panel.visible = false
	_notification_overlay.visible = false
	_current_notification_id = ""
	if not _notification_queue.is_empty():
		_show_notification(_notification_queue.pop_front() as Dictionary)

func _dismiss_notification() -> void:
	if not _notification_panel.visible:
		return
	if _notification_tween != null and _notification_tween.is_running():
		_notification_tween.kill()
	var tw := create_tween()
	tw.tween_property(_notification_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(_on_notification_hidden)


func _bind_button(button: Button, action: Dictionary, fallback_label: String, tooltip: String = "") -> void:
	if button == null:
		return

	var desired_text := fallback_label
	var disabled := true
	if not action.is_empty():
		desired_text = str(action.get("label", fallback_label))
		disabled = bool(action.get("disabled", false))

	button.text = desired_text
	button.disabled = disabled
	button.tooltip_text = tooltip

	var pressed_list: Array = button.pressed.get_connections()
	for conn_v in pressed_list:
		if conn_v is Dictionary:
			var callable_v: Variant = (conn_v as Dictionary).get("callable", Callable())
			if callable_v is Callable:
				var callable: Callable = callable_v
				if callable.is_valid():
					button.pressed.disconnect(callable)

	if not disabled and not action.is_empty():
		button.pressed.connect(_on_overlay_action_requested.bind(action))


func _bind_realm_button() -> void:
	var enter_action := _action_for_slot("cta.enter_stage")
	var realm_select_action := _action_for_slot("nav.realm_select")
	if not enter_action.is_empty() and not bool(enter_action.get("disabled", false)):
		_bind_button(_realm_button, enter_action, "Resume Trial")
		_realm_button.text = "Resume Trial"
		_realm_button.tooltip_text = ""
		return

	_bind_button(_realm_button, realm_select_action, "Choose Realm")
	_realm_button.text = "Choose Realm"
	_realm_button.tooltip_text = ""


func _action_for_slot(slot: String) -> Dictionary:
	var action_v: Variant = _cached_nav.get(slot, {})
	return action_v if action_v is Dictionary else {}


func _update_rail_tone(snap_type: String) -> void:
	if _bottom_rail == null:
		return
	if _echo_detail_open:
		_bottom_rail.modulate = Color(1, 1, 1, 0.72)
		return
	_bottom_rail.modulate = Color(1, 1, 1, 1.0 if snap_type == "flow.sanctum" else 0.86)

func _pan_by_delta(screen_delta: Vector2) -> void:
	# Camera moves opposite to drag direction for "grab world" feel.
	var z := camera.zoom.x
	if z <= 0.0:
		z = 1.0
	camera.position -= (screen_delta * _pan_speed) / z
	_clamp_camera_to_floor()
	
func _toggle_zoom(zoom_in: bool) -> void:
	# Only 2 levels for MVP: near/far toggle.
	# Wheel up = zoom in (closer)
	if zoom_in:
		_zoom_index = min(_zoom_index + 1, _zoom_levels.size() - 1)
	else:
		_zoom_index = max(_zoom_index - 1, 0)
		
	camera.zoom = _zoom_levels[_zoom_index]
	_clamp_camera_to_floor()


# Routes a tap to the correct handler based on the hit occupant kind.
func _try_open_occupant_at_viewport_point(viewport_point: Vector2) -> bool:
	if spatial_renderer == null or not spatial_renderer.has_method("find_occupant_at_viewport_point"):
		return false
	var hit_v: Variant = spatial_renderer.call("find_occupant_at_viewport_point", viewport_point)
	var hit: Dictionary = hit_v if hit_v is Dictionary else {}
	if hit.is_empty():
		return false
	var kind := str(hit.get("kind", "echo"))
	var occupant_id := str(hit.get("id", ""))
	if occupant_id.is_empty():
		return false

	if kind == "ase_flame" or kind == "institution":
		open_institutions_panel()
		return true

	# Echo tap — existing flow
	return _try_open_echo_detail_at_viewport_point_from_hit(hit)


# Legacy helper kept for backward compatibility and clarity.
func _try_open_echo_detail_at_viewport_point(viewport_point: Vector2) -> bool:
	if spatial_renderer == null or not spatial_renderer.has_method("find_occupant_at_viewport_point"):
		return false
	var hit_v: Variant = spatial_renderer.call("find_occupant_at_viewport_point", viewport_point)
	var hit: Dictionary = hit_v if hit_v is Dictionary else {}
	if hit.is_empty():
		return false
	return _try_open_echo_detail_at_viewport_point_from_hit(hit)


func _try_open_echo_detail_at_viewport_point_from_hit(hit: Dictionary) -> bool:
	if _active_overlay == null or not _active_overlay.has_method("open_echo_detail"):
		return false
	var occupant_id := str(hit.get("id", ""))
	if occupant_id.is_empty():
		return false
	_saved_camera_position = camera.position
	_saved_camera_zoom = camera.zoom
	_echo_detail_open = true
	_active_overlay.call("open_echo_detail", occupant_id)
	if spatial_renderer != null and spatial_renderer.has_method("set_featured_occupant"):
		spatial_renderer.call("set_featured_occupant", occupant_id)
	_focus_camera_for_echo_detail(true)
	_update_rail_tone(_current_snap_type)
	return true


# ---- Institutions panel ----

func open_institutions_panel() -> void:
	if _institutions_open:
		return
	_institutions_open = true
	if _active_overlay != null and _active_overlay.has_method("show_institutions_panel"):
		_active_overlay.call("show_institutions_panel")


func close_institutions_panel() -> void:
	if not _institutions_open:
		return
	_institutions_open = false
	if _active_overlay != null and _active_overlay.has_method("hide_institutions_panel"):
		_active_overlay.call("hide_institutions_panel")


# ---- Placement mode ----

func dismiss_nav_bar(animated: bool = true) -> void:
	if _bottom_rail == null:
		return
	if _nav_bar_tween != null and _nav_bar_tween.is_running():
		_nav_bar_tween.kill()
	if animated:
		_nav_bar_tween = create_tween()
		_nav_bar_tween.set_trans(Tween.TRANS_SINE)
		_nav_bar_tween.set_ease(Tween.EASE_IN)
		_nav_bar_tween.parallel().tween_property(_bottom_rail, "modulate:a", 0.0, 0.2)
	else:
		_bottom_rail.modulate.a = 0.0
	_bottom_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE


func restore_nav_bar(animated: bool = true) -> void:
	if _bottom_rail == null:
		return
	if _nav_bar_tween != null and _nav_bar_tween.is_running():
		_nav_bar_tween.kill()
	if animated:
		_nav_bar_tween = create_tween()
		_nav_bar_tween.set_trans(Tween.TRANS_SINE)
		_nav_bar_tween.set_ease(Tween.EASE_OUT)
		_nav_bar_tween.parallel().tween_property(_bottom_rail, "modulate:a", 1.0, 0.2)
	else:
		_bottom_rail.modulate.a = 1.0
	_bottom_rail.mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_placement_mode(inst_id: String, valid_cells: Array, floor_cells: Array = [], occupied_cells: Array = []) -> void:
	close_institutions_panel()
	dismiss_nav_bar()
	_placement_mode = true
	_placement_building_id = inst_id
	_placement_selected_cell = null
	_placement_valid_cells    = valid_cells
	_placement_floor_cells    = floor_cells
	_placement_occupied_cells = occupied_cells
	# Allow map taps to reach _unhandled_input. Three Control layers would
	# otherwise consume every click before _unhandled_input fires:
	#   1. UILayer/Control (full-screen, STOP by default)
	#   2. SanctumScreen overlay (full-screen, STOP by default)
	#   3. WorldLayer/SpatialLayer (full-screen Control, STOP by default)
	# Setting all three to PASS lets clicks on empty map space fall through.
	# Buttons inside the overlay (Cancel, Confirm, strip) keep their own STOP
	# filter and continue to capture their own clicks correctly.
	if _overlay_container != null:
		_overlay_container.mouse_filter = Control.MOUSE_FILTER_PASS
	if _active_overlay != null:
		_active_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	if spatial_renderer != null and spatial_renderer.has_method("set_valid_placement_cells"):
		spatial_renderer.call("set_valid_placement_cells", valid_cells)
	if _active_overlay != null and _active_overlay.has_method("show_placement_bar"):
		_active_overlay.call("show_placement_bar", inst_id)


func _exit_placement_mode() -> void:
	_placement_mode = false
	_placement_building_id = ""
	_placement_selected_cell = null
	_placement_valid_cells    = []
	_placement_floor_cells    = []
	_placement_occupied_cells = []
	# Restore normal mouse blocking so UI panels capture clicks as intended.
	if _overlay_container != null:
		_overlay_container.mouse_filter = Control.MOUSE_FILTER_STOP
	if _active_overlay != null:
		_active_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if spatial_renderer != null and spatial_renderer.has_method("clear_placement_mode"):
		spatial_renderer.call("clear_placement_mode")
	if _active_overlay != null and _active_overlay.has_method("hide_placement_bar"):
		_active_overlay.call("hide_placement_bar")
	restore_nav_bar()
	# Sync flag — panel is re-expanded by hide_placement_bar → _expand_institutions_panel.
	_institutions_open = true


func _try_placement_tap(viewport_point: Vector2) -> bool:
	if spatial_renderer == null or not spatial_renderer.has_method("cell_at_viewport_point"):
		return false

	var cell_v: Variant = spatial_renderer.call("cell_at_viewport_point", viewport_point)
	if not (cell_v is Vector2i):
		return false
	var cell: Vector2i = cell_v
	if cell == Vector2i(-999, -999):
		return false

	# Check validity from pre-computed arrays (no save_data needed in UI layer).
	var validity: Dictionary = SanctumLayoutService.check_placement_validity_from_data(
		cell, _placement_floor_cells, _placement_occupied_cells)
	var is_valid: bool = bool(validity.get("valid", false))
	var reason: String = str(validity.get("reason", ""))

	# Compute full floor preview (bridge + 3×3 ring) only for valid cells.
	var bridge_cells: Array = []
	if is_valid:
		bridge_cells = SanctumLayoutService.get_placement_floor_preview(
			cell, _placement_floor_cells)

	# Store selection (null when invalid — Confirm must stay disabled).
	_placement_selected_cell = cell if is_valid else null

	# Show ghost at tapped cell regardless of validity (red-tinted if invalid).
	if spatial_renderer.has_method("set_ghost_building"):
		spatial_renderer.call("set_ghost_building", cell, _placement_building_id, is_valid, bridge_cells)

	# Notify the active overlay (SanctumScreen) so it can update label + toast.
	if _active_overlay != null and _active_overlay.has_method("on_placement_cell_selected"):
		_active_overlay.call("on_placement_cell_selected", cell, is_valid, reason)

	return true


func _focus_camera_for_echo_detail(animated: bool) -> void:
	if spatial_renderer == null or not spatial_renderer.has_method("get_primary_occupant_position"):
		return
	var occupant_pos_v: Variant = spatial_renderer.call("get_primary_occupant_position")
	if not (occupant_pos_v is Vector2):
		return
	var occupant_pos: Vector2 = occupant_pos_v
	var safe_zoom := Vector2(max(_detail_zoom.x, 0.001), max(_detail_zoom.y, 0.001))
	var horizontal_shift := (spatial_layer.size.x / safe_zoom.x) * 0.20
	var target_position := occupant_pos - Vector2(horizontal_shift, 0.0)
	_animate_camera_to(target_position, _detail_zoom, animated)


func _restore_echo_detail_shell_state() -> void:
	if not _echo_detail_open:
		return
	_echo_detail_open = false
	if spatial_renderer != null and spatial_renderer.has_method("set_featured_occupant"):
		spatial_renderer.call("set_featured_occupant", "")
	_animate_camera_to(_saved_camera_position, _saved_camera_zoom, true)
	_update_rail_tone(_current_snap_type)


func _animate_camera_to(target_position: Vector2, target_zoom: Vector2, animated: bool) -> void:
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	if not animated:
		camera.position = target_position
		camera.zoom = target_zoom
		_clamp_camera_to_floor()
		return
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.parallel().tween_property(camera, "zoom", target_zoom, 0.42)
	_camera_tween.parallel().tween_property(camera, "position", target_position, 0.42)
	_camera_tween.tween_callback(_clamp_camera_to_floor)
	
func _center_camera_on_floor() -> void:
	if spatial_renderer == null:
		return

	var floor := spatial_renderer.get_node_or_null("Floor")
	if floor == null:
		return

	if floor is TileMapLayer:
		var tm := floor as TileMapLayer
		var rect: Rect2i = tm.get_used_rect()
		if rect.size == Vector2i.ZERO:
			return

		# center tile in tile coords
		var center_cell := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)

		# convert to local pixels (TileMapLayer local space)
		var center_local := tm.map_to_local(center_cell)

		# Move the whole renderer so this point becomes (0,0) of SpatialView
		# (tm.position is included because map_to_local is local-to-tm, not including tm.position)
		spatial_renderer.position = -(tm.position + center_local)

		# Camera stays at origin; panning/zoom works from there
		camera.position = Vector2.ZERO
		_recompute_floor_bounds()
		_clamp_camera_to_floor()
	
func _center_spatial_view() -> void:
	# Put Node2D origin in the middle of the available UI rect
	spatial_view.position = spatial_layer.size * 0.5
	
func _on_spatial_layer_resized() -> void:
	_center_spatial_view()
	_recompute_floor_bounds()
	_clamp_camera_to_floor()
	
func _recompute_floor_bounds() -> void:
	_floor_bounds_sv = Rect2(Vector2.ZERO, Vector2.ZERO)

	if spatial_renderer == null:
		return

	var floor := spatial_renderer.get_node_or_null("Floor")
	if floor == null or not (floor is TileMapLayer):
		return

	var tm := floor as TileMapLayer
	var rect_cells: Rect2i = tm.get_used_rect()
	if rect_cells.size == Vector2i.ZERO:
		return

	# Corners in cell space
	var c0 := rect_cells.position
	var c1 := rect_cells.position + Vector2i(rect_cells.size.x, 0)
	var c2 := rect_cells.position + Vector2i(0, rect_cells.size.y)
	var c3 := rect_cells.position + rect_cells.size

	# Convert corners to TileMapLayer-local pixels
	var p0 := tm.map_to_local(c0)
	var p1 := tm.map_to_local(c1)
	var p2 := tm.map_to_local(c2)
	var p3 := tm.map_to_local(c3)

	# Find min/max in TileMapLayer-local
	var min_x : Variant = min(p0.x, p1.x, p2.x, p3.x)
	var max_x : Variant = max(p0.x, p1.x, p2.x, p3.x)
	var min_y : Variant = min(p0.y, p1.y, p2.y, p3.y)
	var max_y : Variant = max(p0.y, p1.y, p2.y, p3.y)

	# Expand to include full tile footprint (diamond half extents)
	var half := Vector2(TILE_W * 0.5, TILE_H * 0.5)
	min_x -= half.x
	max_x += half.x
	min_y -= half.y
	max_y += half.y

	# Convert into SpatialView-local pixels:
	# tm is under spatial_renderer, both are Node2D under spatial_view,
	# so local-to-spatial_view is: spatial_renderer.position + tm.position + local_point
	var offset := spatial_renderer.position + tm.position
	var top_left := offset + Vector2(min_x, min_y)
	var size := Vector2(max_x - min_x, max_y - min_y)

	_floor_bounds_sv = Rect2(top_left, size)

func _clamp_camera_to_floor() -> void:
	if _floor_bounds_sv.size == Vector2.ZERO:
		return

	# Visible size in world units depends on zoom
	var z := camera.zoom
	var safe_z := Vector2(max(z.x, 0.001), max(z.y, 0.001))
	var half_view := (spatial_layer.size / safe_z) * 0.5

	var min_x := _floor_bounds_sv.position.x - FLOOR_PAD.x + half_view.x
	var max_x := _floor_bounds_sv.position.x + _floor_bounds_sv.size.x + FLOOR_PAD.x - half_view.x
	var min_y := _floor_bounds_sv.position.y - FLOOR_PAD.y + half_view.y
	var max_y := _floor_bounds_sv.position.y + _floor_bounds_sv.size.y + FLOOR_PAD.y - half_view.y

	# If the view is larger than bounds on an axis, lock to center on that axis
	if min_x > max_x:
		camera.position.x = (min_x + max_x) * 0.5
	else:
		camera.position.x = clamp(camera.position.x, min_x, max_x)

	if min_y > max_y:
		camera.position.y = (min_y + max_y) * 0.5
	else:
		camera.position.y = clamp(camera.position.y, min_y, max_y)
