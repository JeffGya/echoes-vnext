class_name PickupFindsLayer
extends Node2D

## The finds that lie on the board during the pickup event. `show_finds` draws a still picture; `show_intro` draws the intro at one
## time (reveal flip, carry to the chooser's head, flight into the pack strip). No tags, no hit areas.
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
# Intro: what each mark shows now. "" = not set, "empty" = the empty card, "real" = the find's own face. A shadow scale of
# 0 draws no shadow.
var _faces: Array[String] = []
var _shadows: Array[float] = []
# find id -> where its flight started (the carried place at that time), kept until it lands.
var _fly_from: Dictionary = {}


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


## The intro at one time, from `PickupEventPlan.frame_at(plan, t).items`. `look` = `plan.items_look`. `target` is called with a
## find id and returns { center: screen position of the pack slot, bed: its edge in screen px } or {}. The camera can pan and zoom,
## so the slot is turned into board coordinates here on every call. Draws the same marks as `show_finds` (all finds in the intro).
## `chooser_pos` is the board position of the chooser's token centre at this time (INF when unknown); a carried find is held above it.
func show_intro(data: Dictionary, board: TileMapLayer, items: Dictionary, look: Dictionary, target: Callable, chooser_pos: Vector2 = Vector2.INF,
		reduced: bool = false) -> void:
	show_finds(data, board)
	var finds := ground_finds(data)
	var xf := get_global_transform_with_canvas()
	var edge := bed()
	# A carried find is held above the chooser's head: its token centre now, the token radius and `carry_above` higher.
	var head := Vector2.INF
	if chooser_pos != Vector2.INF:
		head = chooser_pos - Vector2(0.0, visual_config.token_radius + float(look.get("carry_above", 0.0)))
	for i in mini(finds.size(), _centers.size()):
		var f: Dictionary = finds[i]
		var fid := str(f.get("find_id", ""))
		var slot: Dictionary = target.call(fid) if target.is_valid() else {}
		var world: Dictionary = {}
		if not slot.is_empty():
			world = to_board_target(xf, slot["center"] as Vector2, float(slot["bed"]), edge)
		var item: Dictionary = items.get(fid, {})
		if str(item.get("state", "")) == "flying":
			if not _fly_from.has(fid):
				_fly_from[fid] = head if head != Vector2.INF else _centers[i]
		else:
			_fly_from.erase(fid)
		var pose := item_pose(item, str(f.get("status", "")), _centers[i], look, world, head, _fly_from.get(fid, head), reduced)
		var tile := _marks[i]
		tile.visible = bool(pose["visible"])
		_shadows[i] = float(pose["shadow"]) if bool(pose["visible"]) else 0.0
		if not tile.visible:
			continue
		var face := "real" if bool(pose["face_real"]) else "empty"
		if _faces[i] != face:
			_faces[i] = face
			tile.call("setup", f if face == "real" else {}, { "bed": edge })
		tile.size = Vector2(edge, edge)
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2(float(pose["flip"]) * float(pose["scale"]), float(pose["scale"]))
		tile.position = (pose["center"] as Vector2) - tile.size * 0.5
		tile.z_index = int(pose["z"])
		tile.modulate.a = float(pose["alpha"])
	queue_redraw()


## Pure: where a pack slot is in board coordinates. `xf` is the layer's transform to the canvas (it holds the camera pan and
## zoom), `screen_center` the slot centre and `bed` its edge, both in screen px, `edge` the find's edge in board px. `scale` is
## the factor that makes the find as big as the slot bed on arrival.
static func to_board_target(xf: Transform2D, screen_center: Vector2, bed: float, edge: float) -> Dictionary:
	var zoom := maxf(xf.get_scale().x, 0.0001)
	return { "center": xf.affine_inverse() * screen_center, "scale": bed / maxf(edge * zoom, 0.0001) }


## Pure: how one find looks at one moment. `item` is a `frame_at(...).items` entry, `status` the snapshot status, `center` the
## tile centre (board px), `look` the `items` config block, `target` a `to_board_target` result or {}.
## state hidden: the empty card. From `revealed` on: a flip (width 1 to 0 to 1 over the reveal; the face changes at the middle).
## lifted: the find is carried from its tile up to `head` (the held place above the chooser's token) and stays there; it draws
## above the tokens (z 1) once it moves; the ground shadow stays on its tile and shrinks. flying: from `fly_from` (the carried place
## when the flight began) to the slot with an arc of `arc_px`, growing to the slot size, above the tokens (z 1), no shadow. pack: gone.
## A `tried` find is only revealed: it never lifts (the held item is not built). `reduced`: no flip squash (the face changes at once at the
## middle of the reveal), no carry and no arc; a flying find stays on its tile and fades out (`alpha`).
static func item_pose(item: Dictionary, status: String, center: Vector2, look: Dictionary, target: Dictionary, head: Vector2 = Vector2.INF,
		fly_from: Vector2 = Vector2.INF, reduced: bool = false) -> Dictionary:
	var state := str(item.get("state", "hidden"))
	if status == "tried" and state in ["lifted", "flying", "pack"]:
		state = "revealed"
	var p := float(item.get("p", 0.0))
	var rev := float(item.get("rev", 0.0))
	var out := { "visible": true, "center": center, "flip": 1.0, "scale": 1.0, "face_real": false, "shadow": 1.0, "z": 0, "state": state, "alpha": 1.0 }
	if state != "hidden":
		# The flip runs on its own clock: it can still be turning while the find already rises.
		out["face_real"] = rev >= 0.5
		out["flip"] = 1.0 if reduced else (absf(1.0 - 2.0 * rev) if rev < 1.0 else 1.0)
	if reduced and state in ["lifted", "flying"]:
		# Reduced motion: the card is revealed in place, then fades from the ground as its pack slot appears. No rise, no arc, no flip.
		out["alpha"] = 1.0 - p if state == "flying" else 1.0
		return out
	match state:
		"lifted":
			out["center"] = center.lerp(head, p) if head != Vector2.INF else center
			out["z"] = 1 if p > 0.0 else 0
			out["shadow"] = 1.0 - float(look.get("shadow_scale_drop", 0.0)) * p
		"flying":
			out["shadow"] = 0.0
			out["z"] = 1
			var from := fly_from if fly_from != Vector2.INF else center
			var to: Vector2 = target.get("center", from)
			out["center"] = from.lerp(to, p) - Vector2(0.0, float(look.get("arc_px", 0.0)) * sin(PI * p))
			out["scale"] = lerpf(1.0, float(target.get("scale", 1.0)), p)
		"pack":
			out["visible"] = false
			out["shadow"] = 0.0
	return out


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
	_faces.clear()
	_shadows.clear()
	_fly_from.clear()
	for _i in _marks.size():
		_faces.append("")
		_shadows.append(1.0)
	var edge := bed()
	for i in _marks.size():
		var tile := _marks[i]
		tile.visible = i < finds.size()
		if i >= finds.size():
			continue
		var f: Dictionary = finds[i]
		tile.call("setup", f if bool(f.get("revealed", false)) else {}, { "bed": edge })
		tile.size = Vector2(edge, edge)
		tile.scale = Vector2.ONE
		tile.z_index = 0
		tile.modulate.a = 1.0
		tile.position = _centers[i] - Vector2(edge, edge) * 0.5
	queue_redraw()


func _draw() -> void:
	for i in _centers.size():
		var k := _shadows[i] if i < _shadows.size() else 1.0
		if k > 0.0:
			draw_ellipse(_centers[i] + visual_config.shadow_offset, visual_config.shadow_size.x * 0.5 * k,
				visual_config.shadow_size.y * 0.5 * k, visual_config.shadow_color)
