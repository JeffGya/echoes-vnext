## StageScreen
## Bespoke screen for flow.stage — stage overview before committing to encounter.
## Shows stage info panel, explore-map overview preview, and Begin button.
## V2-DIRECTIVE-001: DirectiveSelectOverlay blocks all interaction until player confirms a directive.
## V2-STAGE-001: PreviewBoard renders the exploration tilemap at bird's-eye scale.
##   Pressing Begin zooms the preview and transitions to flow.stage_explore.
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

const ObjectiveScene := preload("res://ui/components/ObjectiveItem.tscn")

# Tile constants — same source/atlas as StageExploreScreen and CombatBoardScreen
const _TILE_SOURCE_ID:    int      = 0
const _TILE_ATLAS_COORDS: Vector2i = Vector2i(0, 0)

# Zoom-in timing before emitting Begin action
const _ZOOM_DURATION:  float = 0.35
const _ZOOM_SCALE_MUL: float = 3.0   # how much to scale during the zoom gesture

var _cached_start_action: Dictionary = {}
var _cached_back_action:  Dictionary = {}
var _preview_scale:       float      = 1.0   # computed overview scale
var _preview_center:      Vector2    = Vector2.ZERO
var _is_zooming:          bool       = false  # guard against double-press

@onready var _title_label:      Label       = %StageTitleLabel
@onready var _objective_label:  Label       = %ObjectiveLabel
@onready var _objectives_list:  VBoxContainer = %ObjectivesList
@onready var _encounter_button: Button      = %EncounterButton
@onready var _back_button:      Button      = %BackButton
@onready var _directive_overlay: Control   = %DirectiveSelectOverlay
@onready var _preview_board:    TileMapLayer = $PreviewBoard

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_encounter_button.pressed.connect(_on_encounter_pressed)
	_directive_overlay.action_requested.connect(_on_overlay_action)

# ─── Bespoke Screen Contract ─────────────────────────────────────────────────

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "Snapshot missing 'type' key")
	assert(snap.has("data"), "Snapshot missing 'data' key")
	_is_zooming = false
	_clear()
	_render(snap["data"], snap.get("actions", {}))
	# V2-DIRECTIVE-001: show directive overlay on every stage entry.
	var dir_v: Variant = snap["data"].get("directive", {})
	if dir_v is Dictionary and not (dir_v as Dictionary).is_empty():
		_directive_overlay.populate(dir_v as Dictionary)
		_directive_overlay.show()

func _clear() -> void:
	_title_label.text     = ""
	_objective_label.text = ""
	for child in _objectives_list.get_children():
		child.queue_free()
	_cached_start_action = {}
	_cached_back_action  = {}
	_preview_board.clear()
	_preview_board.scale    = Vector2.ONE
	_preview_board.position = Vector2.ZERO

func _render(data: Dictionary, actions: Dictionary) -> void:
	_title_label.text = str(data.get("stage_name", "Stage"))

	var raw_objs: Variant = data.get("objectives", [])
	var objectives: Array = raw_objs if raw_objs is Array else []

	if not objectives.is_empty():
		_objective_label.text = "%d objective%s" % [objectives.size(), "s" if objectives.size() > 1 else ""]
		for obj_v in objectives:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			var item: ObjectiveItem = ObjectiveScene.instantiate()
			_objectives_list.add_child(item)
			item.setup(obj)
	else:
		_objective_label.text = "Objective: " + _format_objective(str(data.get("objective_type", "")))

	# nav.back
	var back_v: Variant = actions.get("nav.back", {})
	if back_v is Dictionary and not back_v.is_empty():
		_cached_back_action = back_v
	else:
		_back_button.visible = false

	# cta.start
	var start_v: Variant = actions.get("cta.start", {})
	if start_v is Dictionary and not start_v.is_empty():
		_cached_start_action = start_v
	else:
		_encounter_button.disabled = true

	# V2-STAGE-001: fill exploration map preview
	var map_w := int(data.get("map_width",  30))
	var map_h := int(data.get("map_height", 30))
	_build_preview(map_w, map_h)

# ─── Explore map overview ────────────────────────────────────────────────────

## Fill the PreviewBoard with all tiles and scale it so the full isometric
## diamond fits in the body area between the top bar (136px) and bottom bar (90px from bottom).
func _build_preview(cols: int, rows: int) -> void:
	_preview_board.clear()
	for c in range(cols):
		for r in range(rows):
			_preview_board.set_cell(Vector2i(c, r), _TILE_SOURCE_ID, _TILE_ATLAS_COORDS)

	# After filling, compute bounding box corners using map_to_local
	var tl: Vector2 = _preview_board.map_to_local(Vector2i(0,        0       ))
	var tr: Vector2 = _preview_board.map_to_local(Vector2i(cols - 1, 0       ))
	var bl: Vector2 = _preview_board.map_to_local(Vector2i(0,        rows - 1))
	var br: Vector2 = _preview_board.map_to_local(Vector2i(cols - 1, rows - 1))

	var map_pixel_w: float = max(tr.x, br.x) - min(tl.x, bl.x)
	var map_pixel_h: float = max(bl.y, br.y) - min(tl.y, tr.y)

	# Available body area: from y=136 (below top bar) to y=size.y-90 (above bottom bar)
	# Leave 24px margin on each side
	var available_w: float = size.x - 48.0
	var available_h: float = (size.y - 90.0) - 136.0 - 48.0

	if map_pixel_w <= 0.0 or map_pixel_h <= 0.0 or available_w <= 0.0 or available_h <= 0.0:
		return

	_preview_scale = min(available_w / map_pixel_w, available_h / map_pixel_h)
	_preview_board.scale = Vector2(_preview_scale, _preview_scale)

	# Find the center of the diamond in local unscaled coordinates
	var map_center_local := (tl + tr + bl + br) / 4.0
	# Target screen position: horizontally centered, vertically in the body
	var body_center_y: float = 136.0 + (size.y - 90.0 - 136.0) / 2.0
	_preview_center = Vector2(size.x / 2.0, body_center_y)

	# Position the board so map_center_local × scale lands on screen center
	_preview_board.position = _preview_center - map_center_local * _preview_scale

# ─── Button handlers ─────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if not _cached_back_action.is_empty():
		action_requested.emit(_cached_back_action)

func _on_encounter_pressed() -> void:
	if _cached_start_action.is_empty() or _is_zooming:
		return
	_is_zooming = true
	_encounter_button.disabled = true

	# Zoom-in gesture: scale the preview board up before transitioning
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	var target_scale := Vector2(_preview_scale * _ZOOM_SCALE_MUL, _preview_scale * _ZOOM_SCALE_MUL)
	var current_pos  := _preview_board.position
	# Keep the center of the map pinned while scaling up
	var map_offset   := _preview_center - current_pos  # vector from board origin to screen center
	var target_pos   := _preview_center - map_offset * _ZOOM_SCALE_MUL

	tween.parallel().tween_property(_preview_board, "scale",    target_scale, _ZOOM_DURATION)
	tween.parallel().tween_property(_preview_board, "position", target_pos,   _ZOOM_DURATION)
	tween.parallel().tween_property(self,           "modulate", Color(1, 1, 1, 0), _ZOOM_DURATION)

	tween.finished.connect(_emit_start_action)

func _emit_start_action() -> void:
	action_requested.emit(_cached_start_action)

func _on_overlay_action(action: Dictionary) -> void:
	action_requested.emit(action)

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _format_objective(obj_type: String) -> String:
	match obj_type:
		"purify_shrine":  return "Purify the Shrine"
		"defeat_enemies": return "Defeat All Enemies"
		_: return obj_type.capitalize() if not obj_type.is_empty() else "Unknown"
