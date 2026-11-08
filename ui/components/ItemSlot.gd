extends Control

## One slot of a panel: a cubby (Sanctum) or a round socket (pack) that holds at most one tile. It is the drop
## target of a drag; the tile is its drag source. `planner` is set by the owning panel:
## Callable(data: Dictionary, box: String, index: int) -> Dictionary with `kind` (see ItemMovePlan.plan).

signal chosen(box: String, index: int)
signal drop_requested(data: Dictionary, box: String, index: int)
signal hover_changed(box: String, index: int, plan: Dictionary)

@onready var _back: Panel = %Back
@onready var _tile: Button = %Tile
@onready var _hover: Panel = %Hover

var box := ""
var index := -1
var planner: Callable = Callable()


func setup(new_box: String, new_index: int, bed: int) -> void:
	box = new_box
	index = new_index
	custom_minimum_size = Vector2(bed, bed)
	_back.theme_type_variation = &"ItemSlotPack" if box == "pack" else &"ItemSlotSanct"
	_tile.drop_check = Callable(self, "_check_drop")
	_tile.drop_apply = Callable(self, "_apply_drop")
	if not _tile.pressed.is_connected(_on_tile_pressed):
		_tile.pressed.connect(_on_tile_pressed)
		_tile.drag_began.connect(_on_tile_drag)


func tile() -> Button:
	return _tile


## Shows the row in this slot, or empties the slot when `row` is empty.
func set_content(row: Dictionary, opts: Dictionary) -> void:
	if row.is_empty():
		_tile.visible = false
		_tile.focus_mode = Control.FOCUS_NONE
		_tile.row = {}
		return
	_tile.visible = true
	_tile.focus_mode = Control.FOCUS_ALL
	var o := opts.duplicate()
	o["box"] = box
	o["slot"] = index
	_tile.setup(row, o)


func has_content() -> bool:
	return _tile.visible and not _tile.row.is_empty()


func _on_tile_pressed() -> void:
	chosen.emit(box, index)


func _on_tile_drag(_t: Control) -> void:
	chosen.emit(box, index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not has_content():
		chosen.emit(box, -1)


func _check_drop(data: Variant) -> bool:
	return _can_drop_data(Vector2.ZERO, data)


func _apply_drop(data: Variant) -> void:
	_drop_data(Vector2.ZERO, data)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not bool((data as Dictionary).get("item_drag", false)) or not planner.is_valid():
		return false
	var p: Dictionary = planner.call(data, box, index)
	var kind := str(p.get("kind", ""))
	_hover.visible = kind != "none"
	_hover.theme_type_variation = &"ItemSlotHoverNo" if kind == "refuse" else &"ItemSlotHoverOk"
	hover_changed.emit(box, index, p)
	return kind != "none"


func _drop_data(_at: Vector2, data: Variant) -> void:
	_hover.visible = false
	drop_requested.emit(data, box, index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hover != null:
		_hover.visible = false
