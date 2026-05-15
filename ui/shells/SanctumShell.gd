extends Control

class_name SanctumShell

@onready var overlay_root: Control = %OverlayRoot
@onready var spatial_layer: Control = $SpatialLayer
@onready var spatial_view: Node2D = $SpatialLayer/SpatialView
@onready var camera: Camera2D = $SpatialLayer/SpatialView/Camera2D
@onready var spatial_renderer: Node2D = $SpatialLayer/SpatialView/SanctumSpatialRenderer2
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _notification_layer: CanvasLayer = $NotificationLayer
@onready var _notification_overlay: ColorRect = %NotificationOverlay
@onready var _notification_panel: PanelContainer = %NotificationPanel
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

var _active_overlay: Control = null
# Nav actions cached from the last flow.sanctum snapshot.
# The shell owns the persistent nav bar so all sanctum-family screens share it.
var _cached_nav: Dictionary = {}

# Camera config (Phase B)
var _zoom_levels := [Vector2(1.0, 1.0), Vector2(1.5, 1.5)]
var _zoom_index := 1 # Start at 1.5
var _pan_speed  := 2.5

var _is_panning := false
var _last_pointer_pos := Vector2.ZERO
var _current_snap_type := ""
var _echo_detail_open := false
var _institutions_open := false
var _placement_mode := false
var _placement_building_id := ""
var _placement_selected_cell: Variant = null  # Vector2i or null
var _saved_camera_position := Vector2.ZERO
var _saved_camera_zoom := Vector2.ONE
var _detail_zoom := Vector2(2.9, 2.9)
var _camera_tween: Tween
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
const FLOOR_PAD := Vector2(160.0, 160.0) # allow some "void" around edges

var _floor_bounds_sv := Rect2(Vector2.ZERO, Vector2.ZERO) # floor bounds in SpatialView-local pixels
 
# PackedScenes will be preloaded later
var _scene_by_flow_type: Dictionary = {}
var _sanctum_scene := preload("res://ui/screens/sanctum/SanctumScreen.tscn")
var _summon_scene := preload("res://ui/screens/sanctum/SummonScreen.tscn")
var _echo_party_scene := preload("res://ui/screens/sanctum/EchoPartyScreen.tscn")
var _realm_scene := preload("res://ui/screens/realm/RealmSelectScreen.tscn")
var _vow_scene := preload("res://ui/screens/sanctum/VowScreen.tscn")  # VOW-001
var _weaving_rite_scene := preload("res://ui/screens/sanctum/WeavingRiteScreen.tscn")  # V2-WEAVE-002

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
	# Sync UILayer visibility whenever SanctumShell is shown/hidden.
	visibility_changed.connect(_sync_ui_layer_visibility)
	_bind_nav_bar()
	_notification_panel.visible = false
	_notification_panel.modulate.a = 0.0
	_notification_overlay.visible = false
	_notification_dismiss.pressed.connect(_dismiss_notification)

func _sync_ui_layer_visibility() -> void:
	_ui_layer.visible = visible
	_notification_layer.visible = visible
	# Camera2D.enabled is independent of node visibility in Godot 4.
	# Disable it when SanctumShell is hidden so it does not affect the viewport
	# while RealmShell (or any other screen) is active.
	camera.enabled = visible


func set_snapshot(snap: Dictionary) -> void:
	_current_snap_type = str(snap.get("type", ""))

	# 1) Update spatial background (read-only visual layer)
	# For now this is a stub. Later we will add proper renderer script.
	if spatial_renderer != null and spatial_renderer.has_method("render"):
		spatial_renderer.call("render", snap)
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
	
func _show_overlay_for_type(snap_type: String, snap: Dictionary) -> void:
	if not _scene_by_flow_type.has(snap_type):
		push_warning("SanctumShell: no overlay mapped for snapshot type: " + snap_type)
		return
	
	var packed: PackedScene = _scene_by_flow_type[snap_type]
	if packed == null:
		return
	
	# if same overlay if event is InputEventKey and event.pressed and event.echo:scene class already active, just update snapshot
	if _active_overlay != null and _active_overlay.scene_file_path == packed.resource_path:
		if _active_overlay.has_method("set_snapshot"):
			_active_overlay.call("set_snapshot", snap)
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
	if _active_overlay != null and _active_overlay.has_signal("echo_detail_closed"):
		var close_ok := _active_overlay.connect("echo_detail_closed", Callable(self, "_on_overlay_echo_detail_closed"))
		if close_ok != OK:
			push_warning("SanctumShell: failed to connect echo_detail_closed (err=%d)" % close_ok)
		
	# Give snapshot to overlay
	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)

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
	
	# Pinch-to-zoom (mobile)
	if event is InputEventMagnifyGesture:
		if _echo_detail_open or _placement_mode or _institutions_open:
			return
		var factor := (event as InputEventMagnifyGesture).factor
		var new_zoom := (camera.zoom * factor).clamp(_zoom_levels[0], _zoom_levels[_zoom_levels.size() - 1])
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
			_zoom_index = 1 - _zoom_index
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

	# Placement mode: route taps to placement handler; swallow all others.
	if _placement_mode:
		if _try_placement_tap(mb.position):
			get_viewport().set_input_as_handled()
		return

	# Normal mode: check hit, route by kind.
	if _try_open_occupant_at_viewport_point(mb.position):
		get_viewport().set_input_as_handled()


# ---- HELPERS ----
func _on_overlay_action_requested(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	# Intercept placement mode lifecycle — do NOT forward to FlowRuntime.
	if action_type == "ui.enter_placement_mode":
		var inst_id   := str(action.get("payload", {}).get("institution_id", ""))
		var cells_v: Variant = action.get("payload", {}).get("valid_cells", [])
		var cells: Array = cells_v if cells_v is Array else []
		_enter_placement_mode(inst_id, cells)
		return
	if action_type == "ui.exit_placement_mode":
		_exit_placement_mode()
		return
	action_requested.emit(action)


func _on_overlay_echo_detail_closed() -> void:
	_restore_echo_detail_shell_state()

func _bind_nav_bar() -> void:
	_bind_button(_party_button, _action_for_slot("nav.echo_party"), "Party")
	_bind_button(_summon_button, _action_for_slot("nav.summon"), "Summon")
	_bind_realm_button()
	_bind_button(_vows_button, _action_for_slot("nav.vow_manage"), "Vows")
	_bind_button(_weaving_button, {}, "Weaving", "Choose an Echo first.")

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

func _enter_placement_mode(inst_id: String, valid_cells: Array) -> void:
	close_institutions_panel()
	_placement_mode = true
	_placement_building_id = inst_id
	_placement_selected_cell = null
	if spatial_renderer != null and spatial_renderer.has_method("set_valid_placement_cells"):
		spatial_renderer.call("set_valid_placement_cells", valid_cells)
	if _active_overlay != null and _active_overlay.has_method("show_placement_bar"):
		_active_overlay.call("show_placement_bar", inst_id)


func _exit_placement_mode() -> void:
	_placement_mode = false
	_placement_building_id = ""
	_placement_selected_cell = null
	if spatial_renderer != null and spatial_renderer.has_method("clear_placement_mode"):
		spatial_renderer.call("clear_placement_mode")
	if _active_overlay != null and _active_overlay.has_method("hide_placement_bar"):
		_active_overlay.call("hide_placement_bar")


func _try_placement_tap(viewport_point: Vector2) -> bool:
	if spatial_renderer == null or not spatial_renderer.has_method("find_valid_cell_at_viewport_point"):
		return false
	var cell_v: Variant = spatial_renderer.call("find_valid_cell_at_viewport_point", viewport_point)
	if not (cell_v is Vector2i):
		return false
	var cell: Vector2i = cell_v
	if cell == Vector2i(-999, -999):
		return false
	_placement_selected_cell = cell
	if spatial_renderer.has_method("set_ghost_building"):
		spatial_renderer.call("set_ghost_building", cell, _placement_building_id)
	if _active_overlay != null and _active_overlay.has_method("on_placement_cell_selected"):
		_active_overlay.call("on_placement_cell_selected", cell)
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
