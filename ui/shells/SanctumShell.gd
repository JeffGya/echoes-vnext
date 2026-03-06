extends Control

class_name SanctumShell

@onready var overlay_root: Control = %OverlayRoot
@onready var spatial_layer: Control = $SpatialLayer
@onready var spatial_view: Node2D = $SpatialLayer/SpatialView
@onready var camera: Camera2D = $SpatialLayer/SpatialView/Camera2D
@onready var spatial_renderer: Node2D = $SpatialLayer/SpatialView/SanctumSpatialRenderer2

signal action_requested(action: Dictionary)

var _active_overlay: Control = null

# Camera config (Phase B)
var _zoom_levels := [Vector2(1.0, 1.0), Vector2(1.5, 1.5)]
var _zoom_index := 1 # Start at 1.5
var _pan_speed  := 1.0

var _is_panning := false
var _last_pointer_pos := Vector2.ZERO

# Camera clamp (Phase B)
const TILE_W := 128.0
const TILE_H := 64.0
const FLOOR_PAD := Vector2(160.0, 160.0) # allow some "void" around edges

var _floor_bounds_sv := Rect2(Vector2.ZERO, Vector2.ZERO) # floor bounds in SpatialView-local pixels
 
# PackedScenes will be preloaded later
var _scene_by_flow_type: Dictionary = {}
var _sanctum_scene := preload("res://ui/screens/SanctumScreen.tscn")
var _summon_scene := preload("res://ui/screens/SummonScreen.tscn")
var _party_scene := preload("res://ui/screens/PartyManageScreen.tscn")
#var _echo_scene := preload("res://ui/screens/EchoManageScreen.tscn")
#var _realm_scene := preload("res://ui/screens/RealmSelectScreen.tscn")

func _ready() -> void:
	_scene_by_flow_type = {
		"flow.sanctum": _sanctum_scene,
		"flow.summon": _summon_scene,
		"flow.party_manage": _party_scene,
		#"flow.echo_manage": _echo_scene,
		#"flow.realm_select": _realm_scene,
	}
	
	_center_spatial_view()
	spatial_layer.resized.connect(_on_spatial_layer_resized)
	
	camera.zoom = _zoom_levels[_zoom_index]
	_recompute_floor_bounds()
	_clamp_camera_to_floor()

func set_snapshot(snap: Dictionary) -> void:
	# 1) Update spatial background (read-only visual layer)
	# For now this is a stub. Later we will add proper renderer script.
	if spatial_renderer != null and spatial_renderer.has_method("render"):
		spatial_renderer.call("render", snap)
	
	# 2) Swap overlay UI based on flow snapshot type
	var snap_type := str(snap.get("type", ""))
	_show_overlay_for_type(snap_type, snap)
	
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
		
	# Give snapshot to overlay
	if _active_overlay != null and _active_overlay.has_method("set_snapshot"):
		_active_overlay.call("set_snapshot", snap)

func _unhandled_input(event: InputEvent) -> void:
	# Don't steal UI clicks: only pan when dragging with MMB or Space+LMB for now.
	# We'll add touch-pan next (one finger drag on empty space). After we decide UI gesture rules.
	
	# --- Zoom wheel (dev convenience) ---
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

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
	
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		# pg.delta is already a screen-space delta
		_pan_by_delta(pg.delta)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if _is_panning:
			var mm := event as InputEventMouseMotion
			_pan_by_delta(mm.relative)
			get_viewport().set_input_as_handled()
			return

	# Z toggles zoom levels
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_Z:
			_zoom_index = 1 - _zoom_index
			camera.zoom = _zoom_levels[_zoom_index]
			_clamp_camera_to_floor()
			get_viewport().set_input_as_handled()
			return


# ---- HELPERS ----
func _on_overlay_action_requested(action: Dictionary) -> void:
	action_requested.emit(action) 
	
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
