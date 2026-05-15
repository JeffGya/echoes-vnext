extends Control

class_name SanctumGroundScene

# ---- Signals ----
signal echo_selected(echo_id: String)
signal institution_selected(institution_id: String)

# ---- Onready refs (all nodes authored in .tscn) ----
@onready var _ground_base:       ColorRect  = %GroundBase
@onready var _hearth_group:      Control    = %HearthGroup
@onready var _hearth_healthy:    Control    = %HearthHealthyLayer
@onready var _hearth_strained:   Control    = %HearthStrainedLayer
@onready var _hearth_neglected:  Control    = %HearthNeglectedLayer
@onready var _training_group:    Control    = %TrainingGroundsGroup
@onready var _training_healthy:  Control    = %TrainingHealthyLayer
@onready var _training_strained: Control    = %TrainingStrainedLayer
@onready var _training_neglected:Control    = %TrainingNeglectedLayer
@onready var _token_layer:       Control    = %EchoTokenLayer
@onready var _token_template:    Control    = %EchoTokenTemplate

# ---- Anchor positions authored in .tscn (Marker2D positions read at runtime) ----
# Zone -> Array of Vector2 anchor positions
var _zone_anchors: Dictionary = {}

# ---- Runtime token pool ----
var _active_tokens: Dictionary = {}  # echo_id -> Control node

# ---- Idle wander ----
var _idle_timer: float = 0.0
const IDLE_WANDER_INTERVAL := 8.0
const WANDER_RADIUS := 12.0

# ---- Scroll/pan/zoom state ----
var _offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
const ZOOM_MIN := 0.7
const ZOOM_MAX := 2.0
var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

@onready var _content_root: Control = %ContentRoot

# ---- Token colour map ----
const STATUS_COLORS: Dictionary = {
	"radiant":  Color(0.910, 0.816, 0.627, 1.0),  # #E8D0A0 — pale kente gold
	"whole":    Color(0.784, 0.663, 0.431, 1.0),  # #C8A96E — akan gold
	"grounded": Color(0.659, 0.525, 0.353, 1.0),  # #A8865A — warm brass
	"burdened": Color(0.478, 0.478, 0.541, 1.0),  # #7A7A8A — muted grey
	"pressed":  Color(0.910, 0.627, 0.188, 1.0),  # #E8A030 — amber warning
	"strained": Color(0.910, 0.255, 0.165, 1.0),  # #E8412A — ohene red
	"fraying":  Color(0.478, 0.376, 0.251, 1.0),  # #7A6040 — faded brass
	"hollow":   Color(0.290, 0.290, 0.353, 1.0),  # #4A4A5A — deep grey
}

const CONDITION_MODULATES: Dictionary = {
	"healthy":   Color(1.0, 1.0, 1.0, 1.0),          # full colour
	"strained":  Color(0.910, 0.753, 0.502, 1.0),     # #E8C080 — warm dim
	"neglected": Color(0.541, 0.478, 0.416, 1.0),     # #8A7A6A — greyed
}


func _ready() -> void:
	_build_zone_anchors()
	_token_template.visible = false


func _process(delta: float) -> void:
	_idle_timer += delta
	if _idle_timer >= IDLE_WANDER_INTERVAL:
		_idle_timer = 0.0
		_do_idle_wander()


# ---- Public API ----

func set_ground_data(ground_data: Dictionary) -> void:
	_update_institution_groups(ground_data)
	_update_echo_tokens(ground_data)


# ---- Institution group updates ----

func _update_institution_groups(gd: Dictionary) -> void:
	var visibility: Dictionary = gd.get("institution_visibility", {}) as Dictionary
	var conditions: Dictionary = gd.get("institution_conditions", {}) as Dictionary

	_set_institution_visible(_hearth_group, _hearth_healthy, _hearth_strained, _hearth_neglected,
		bool(visibility.get("hearth", false)), str(conditions.get("hearth", "neglected")))
	_set_institution_visible(_training_group, _training_healthy, _training_strained, _training_neglected,
		bool(visibility.get("training_grounds", false)), str(conditions.get("training_grounds", "neglected")))


func _set_institution_visible(group: Control, healthy: Control, strained: Control, neglected: Control, unlocked: bool, condition: String) -> void:
	group.visible = unlocked
	if not unlocked:
		return
	healthy.visible  = condition == "healthy"
	strained.visible = condition == "strained"
	neglected.visible = condition == "neglected"
	var tween := create_tween()
	tween.tween_property(group, "modulate", CONDITION_MODULATES.get(condition, Color.WHITE), 0.3)


# ---- Echo token updates ----

func _update_echo_tokens(gd: Dictionary) -> void:
	var slots: Array = gd.get("echo_slots", []) as Array
	var seen_ids: Array = []
	for slot_v in slots:
		if not (slot_v is Dictionary):
			continue
		var slot: Dictionary = slot_v
		var echo_id := str(slot.get("echo_id", ""))
		if echo_id.is_empty():
			continue
		seen_ids.append(echo_id)
		var token: Control = _get_or_create_token(echo_id)
		var zone   := str(slot.get("zone", "roaming"))
		var idx    := int(slot.get("slot_index", 0))
		var status := str(slot.get("emotional_status", "grounded"))
		_apply_token_colour(token, status)
		_tween_token_to_slot(token, zone, idx)
	# Remove tokens for echoes no longer present
	for eid in _active_tokens.keys():
		if not seen_ids.has(eid):
			var old_token: Control = _active_tokens[eid]
			old_token.queue_free()
			_active_tokens.erase(eid)


func _get_or_create_token(echo_id: String) -> Control:
	if _active_tokens.has(echo_id):
		return _active_tokens[echo_id]
	var token: Control = _token_template.duplicate() as Control
	token.visible = true
	token.name = "Token_" + echo_id
	token.set_meta("echo_id", echo_id)
	_token_layer.add_child(token)
	_active_tokens[echo_id] = token
	return token


func _apply_token_colour(token: Control, status: String) -> void:
	var circle: ColorRect = token.get_node_or_null("TokenCircle") as ColorRect
	if circle == null:
		return
	var col: Color = STATUS_COLORS.get(status, STATUS_COLORS.get("grounded", Color.WHITE))
	var tween := create_tween()
	tween.tween_property(circle, "modulate", col, 0.25)


func _tween_token_to_slot(token: Control, zone: String, slot_index: int) -> void:
	var anchors: Array = _zone_anchors.get(zone, []) as Array
	if anchors.is_empty():
		return
	var safe_idx := slot_index % anchors.size()
	var target: Vector2 = anchors[safe_idx]
	var tween := create_tween()
	tween.tween_property(token, "position", target, 0.6).set_trans(Tween.TRANS_SINE)


func _do_idle_wander() -> void:
	for echo_id in _active_tokens:
		var token: Control = _active_tokens[echo_id]
		var wander_offset := Vector2(
			randf_range(-WANDER_RADIUS, WANDER_RADIUS),
			randf_range(-WANDER_RADIUS, WANDER_RADIUS)
		)
		var base: Vector2 = token.position
		var tween := create_tween()
		tween.tween_property(token, "position", base + wander_offset, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(token, "position", base, 1.2).set_trans(Tween.TRANS_SINE)


# ---- Scroll / pan / zoom ----

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				_is_dragging = false
			else:
				if not _is_dragging:
					_handle_tap(mb.position)
				_is_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(0.1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-0.1, mb.position)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_is_dragging = true
			_offset += mm.relative
			_apply_transform()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_offset += drag.relative
		_apply_transform()

	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and not _is_dragging:
			_handle_tap(touch.position)
		if not touch.pressed:
			_is_dragging = false


func _apply_zoom(delta: float, pivot: Vector2) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom + delta, ZOOM_MIN, ZOOM_MAX)
	var scale_change := _zoom / old_zoom
	_offset = pivot + (_offset - pivot) * scale_change
	_apply_transform()


func _apply_transform() -> void:
	_content_root.pivot_offset = size * 0.5
	_content_root.scale = Vector2(_zoom, _zoom)
	_content_root.position = _offset


# ---- Tap detection ----

func _handle_tap(tap_pos: Vector2) -> void:
	# Check echo tokens first (smaller targets on top)
	for echo_id in _active_tokens:
		var token: Control = _active_tokens[echo_id]
		if not token.visible:
			continue
		var rect := Rect2(token.global_position, token.size)
		if rect.has_point(tap_pos):
			echo_selected.emit(str(echo_id))
			return
	# Check building hitboxes
	_check_building_tap("hearth", _hearth_group, tap_pos)
	_check_building_tap("training_grounds", _training_group, tap_pos)


func _check_building_tap(inst_id: String, group: Control, tap_pos: Vector2) -> void:
	if not group.visible:
		return
	var rect := Rect2(group.global_position, group.size)
	if rect.has_point(tap_pos):
		institution_selected.emit(inst_id)


# ---- Zone anchor builder ----

func _build_zone_anchors() -> void:
	# Reads Marker2D child positions from EchoTokenLayer.
	# Uses child.position (local to EchoTokenLayer) — valid immediately in _ready(),
	# unlike global_position which requires a layout pass first.
	# Naming convention: HearthAnchor0..3, TrainingAnchor0..3, PartyAnchor0..4, RoamAnchor0..5
	_zone_anchors = { "hearth": [], "training_grounds": [], "party": [], "roaming": [] }
	for child in _token_layer.get_children():
		if not (child is Marker2D):
			continue
		var n := child.name as String
		var local_pos: Vector2 = (child as Marker2D).position
		if n.begins_with("HearthAnchor"):
			_zone_anchors["hearth"].append(local_pos)
		elif n.begins_with("TrainingAnchor"):
			_zone_anchors["training_grounds"].append(local_pos)
		elif n.begins_with("PartyAnchor"):
			_zone_anchors["party"].append(local_pos)
		elif n.begins_with("RoamAnchor"):
			_zone_anchors["roaming"].append(local_pos)
