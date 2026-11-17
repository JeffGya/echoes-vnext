class_name PickupFindsLayer
extends Node2D

## The finds that lie on the board during the pickup event. Static: no motion, no tags, no hit areas.
## Each mark is an ItemTile centred on its tile like a token, with a ground ellipse from the token shadow config.
## In the intro every find lies on its tile, taken or not (nothing is in the pack yet). After the intro only the
## finds still on the ground get a mark; taken finds are in the Travel pack. A hidden find (not revealed) shows the
## tile of an empty row: the hatch plate, no kind shape, no grade, no name.

const PHASE_INTRO := "intro"
## Six marks are authored in the scene. This equals the last band of `finds_cap_by_realm_scale` in data/balance.json;
## a larger list draws the first six.
const MAX_MARKS := 6
const GROUND_STATUSES: Array[String] = ["left", "tried", "lost"]

@export var visual_config: CombatTokenVisualConfig

var _marks: Array[Button] = []
var _centers: Array[Vector2] = []
var _sig := ""
var _renders := 0


func _ready() -> void:
	for child in get_children():
		_marks.append(child as Button)
	if visual_config == null:
		visual_config = CombatTokenVisualConfig.new()
	_apply([], false)


## True for a `tile` with both `col` and `row`. An empty dictionary is no tile.
static func tile_valid(tile: Variant) -> bool:
	return tile is Dictionary and (tile as Dictionary).has("col") and (tile as Dictionary).has("row")


## Pure: the finds of a pickup snapshot that lie on the board, in snapshot order, capped at MAX_MARKS.
static func ground_finds(data: Dictionary) -> Array:
	var out: Array = []
	var intro := str(data.get("phase", "")) == PHASE_INTRO
	var finds_v: Variant = data.get("finds", [])
	if not (finds_v is Array):
		return out
	for f_v: Variant in finds_v:
		if not (f_v is Dictionary):
			continue
		var f: Dictionary = f_v
		if (intro or GROUND_STATUSES.has(str(f.get("status", "")))) and tile_valid(f.get("tile", null)) and out.size() < MAX_MARKS:
			out.append(f)
	return out


## `board` maps a tile to its board-local centre, the call every token uses. The same finds draw nothing again.
func show_finds(data: Dictionary, board: TileMapLayer) -> void:
	var finds := ground_finds(data)
	var centers: Array[Vector2] = []
	for f: Dictionary in finds:
		var t: Dictionary = f["tile"]
		centers.append(board.map_to_local(Vector2i(int(t.get("col", 0)), int(t.get("row", 0)))) + Vector2(0.0, visual_config.feet_offset_y))
	var sig := JSON.stringify([finds, centers], "", true)
	if sig == _sig:
		return
	_sig = sig
	_centers = centers
	_apply(finds, true)


func clear() -> void:
	if _sig.is_empty():
		return
	_sig = ""
	_centers = []
	_apply([], false)


## The edge of a mark: the token diameter, so a find fills the same footprint as an Echo token.
func bed() -> float:
	var radius: float = visual_config.token_radius if visual_config != null else CombatTokenVisualConfig.new().token_radius
	return radius * 2.0


# Test accessors.
func mark_count() -> int:
	return _centers.size()


func mark(index: int) -> Button:
	return _marks[index]


func mark_center(index: int) -> Vector2:
	return _centers[index]


func render_count() -> int:
	return _renders


func _apply(finds: Array, shown: bool) -> void:
	_renders += 1
	visible = shown and not finds.is_empty()
	var edge := bed()
	for i in _marks.size():
		var tile := _marks[i]
		tile.visible = i < finds.size()
		if i >= finds.size():
			continue
		var f: Dictionary = finds[i]
		tile.call("setup", f if bool(f.get("revealed", false)) else {}, { "bed": edge })
		tile.size = Vector2(edge, edge)
		tile.position = _centers[i] - Vector2(edge, edge) * 0.5
	queue_redraw()


func _draw() -> void:
	for c in _centers:
		draw_ellipse(c + visual_config.shadow_offset, visual_config.shadow_size.x * 0.5,
			visual_config.shadow_size.y * 0.5, visual_config.shadow_color)
