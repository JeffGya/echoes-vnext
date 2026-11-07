extends Button

## One item tile for every surface (panels, details, modal, result cards, leave confirmation).
## A tile shows a plate on its own bed, at most three marks (grade pips, twin notch, source leaf) and a
## count capsule for a stack. States: in the Sanctum, carried, at risk, kept, lost. The tile never shows an
## id; `display_name()` is the row `name`, else the kind word.
## It reads one snapshot row: kind, name, grade ("g1".."g3"), mark_index, count or quantity, stack_limit, at_limit.

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const SCENE_PATH := "res://ui/components/ItemTile.tscn"
const STACK_KINDS: Array[String] = ["consumable", "material"]
const LIFT := 8.0
const REVEAL_RISE := 8.0
const LOST_FADE_SECONDS := 0.5
const LOST_PLATE_ALPHA := 0.35

signal drag_began(tile: Control)

@onready var _body: Control = %Body
@onready var _bed: Panel = %Bed
@onready var _edge: Panel = %PlateEdge
@onready var _plate: Panel = %Plate
@onready var _glyphs: Control = %Glyphs
@onready var _capsule: PanelContainer = %Capsule
@onready var _count: RichTextLabel = %CountLabel
@onready var _selected: Panel = %SelectedRing

var row: Dictionary = {}
var box := ""
var slot := -1
var state := ""
var drag_enabled := false
## Set by the owning ItemSlot: a drop on the tile is a drop on the slot.
var drop_check: Callable = Callable()
var drop_apply: Callable = Callable()
var _leaf := ""
var _ghost: Tween = null
var _reveal: Tween = null


## opts: box ("sanctum"|"pack"|""), slot, state ("", "at_risk", "kept", "lost"), source ("held"|"gathered"|""),
## bed (edge length, 72 or 80), drag (bool).
func setup(new_row: Dictionary, opts: Dictionary = {}) -> void:
	row = new_row
	box = str(opts.get("box", ""))
	slot = int(opts.get("slot", -1))
	drag_enabled = bool(opts.get("drag", false))
	var bed := float(opts.get("bed", 72))
	custom_minimum_size = Vector2(bed, bed)
	var kind := str(row.get("kind", ""))
	var stack := is_stack_row(row)
	_glyphs.kind = kind
	_glyphs.is_stack = stack
	_glyphs.pips = 0 if stack else pips_of(row)
	_glyphs.mark = -1 if stack else int(row.get("mark_index", -1))
	_leaf = ""
	var source := str(opts.get("source", ""))
	if box == "pack" or not source.is_empty():
		_leaf = "gathered" if source == "gathered" else "held"
	_bed.theme_type_variation = &"ItemBedHeavy" if box == "pack" else &"ItemBed"
	_edge.visible = stack
	_edge.offset_left = 6.0
	_edge.offset_top = 6.0
	_edge.offset_right = -2.0
	_edge.offset_bottom = -2.0
	var inset := 2.0 if stack else 4.0
	_plate.offset_left = inset
	_plate.offset_top = inset
	_plate.offset_right = -(inset + 4.0 if stack else inset)
	_plate.offset_bottom = -(inset + 4.0 if stack else inset)
	_capsule.visible = stack
	if stack:
		var n := stack_count_of(row)
		var at_limit := bool(row.get("at_limit", false))
		_count.text = "[u]x%d[/u]" % n if at_limit else "x%d" % n
		_capsule.theme_type_variation = &"ItemCapsuleLimit" if at_limit else &"ItemCapsule"
	tooltip_text = display_name()
	if "accessibility_name" in self:
		set("accessibility_name", describe())
	apply_state(str(opts.get("state", "")))


static func is_stack_row(r: Dictionary) -> bool:
	return STACK_KINDS.has(str(r.get("kind", "")))


static func stack_count_of(r: Dictionary) -> int:
	return int(r.get("count", r.get("quantity", 1)))


## Grade pips 1..3 from a grade string such as "g2". No digit gives none.
static func pips_of(r: Dictionary) -> int:
	var g := str(r.get("grade", ""))
	var digits := ""
	for ch in g:
		if ch >= "0" and ch <= "9":
			digits += ch
	return clampi(digits.to_int(), 0, 3) if not digits.is_empty() else 0


func display_name() -> String:
	return ItemUiText.display_name(row)


func describe() -> String:
	var parts: Array[String] = [display_name()]
	var kind_word := ItemUiText.kind_name(str(row.get("kind", "")))
	if not kind_word.is_empty() and kind_word != display_name():
		parts.append(kind_word)
	if is_stack_row(row):
		parts.append("x%d" % stack_count_of(row))
	elif pips_of(row) > 0:
		parts.append("%s %d" % [ItemUiText.GRADE_LABEL, pips_of(row)])
	return ", ".join(parts)


func set_selected(on: bool) -> void:
	_selected.theme_type_variation = &"ItemTileSelectedDark" if box == "pack" else &"ItemTileSelected"
	_selected.visible = on


## Sets the state at once. Kept: bronze 3 line, no leaf. Lost: ghost fill, dashed outline, lifted body.
func apply_state(new_state: String) -> void:
	_kill_ghost()
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	_reveal = null
	state = new_state
	var lost := state == "lost"
	_glyphs.at_risk = state == "at_risk"
	_glyphs.leaf = "" if state == "kept" else _leaf
	_glyphs.lost = 1.0 if lost else 0.0
	_plate.theme_type_variation = &"ItemPlateLost" if lost else (&"ItemPlateKept" if state == "kept" else &"ItemPlate")
	_edge.theme_type_variation = &"ItemPlateEdgeLost" if lost else &"ItemPlateEdge"
	_plate.modulate.a = 1.0
	_edge.modulate.a = 1.0
	_capsule.modulate.a = 0.8 if lost else 1.0
	_body.position.y = -LIFT if lost else 0.0


## Plays the lost motion: the fill goes to 35 percent, the marks to 60 percent, the dashed outline appears and the
## body rises LIFT units. `lift` is 0 for reduced motion. Ends in the same state as apply_state("lost").
func play_lost(seconds: float, lift: float = LIFT) -> void:
	_kill_ghost()
	if seconds <= 0.0 or not is_inside_tree():
		apply_state("lost")
		return
	state = "lost"
	_ghost = create_tween()
	_ghost.tween_method(_ghost_step.bind(lift), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ghost.tween_callback(apply_state.bind("lost"))


## Appears: fades in and rises RISE units to rest. `rise` is 0 for reduced motion (a plain fade).
func reveal(seconds: float, rise: float = REVEAL_RISE) -> void:
	modulate.a = 0.0
	if seconds <= 0.0 or not is_inside_tree():
		modulate.a = 1.0
		return
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	var rest := _body.position.y
	_body.position.y = rest + rise
	_reveal = create_tween().set_parallel(true)
	_reveal.tween_property(self, "modulate:a", 1.0, seconds)
	_reveal.tween_property(_body, "position:y", rest, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func is_ghosting() -> bool:
	return _ghost != null and _ghost.is_valid() and _ghost.is_running()


## Ends a running lost motion at its final state.
func finish_motion() -> void:
	if is_ghosting():
		apply_state("lost")


func _ghost_step(t: float, lift: float) -> void:
	_glyphs.lost = t
	_plate.modulate.a = lerpf(1.0, LOST_PLATE_ALPHA, t)
	_edge.modulate.a = lerpf(1.0, LOST_PLATE_ALPHA, t)
	_capsule.modulate.a = lerpf(1.0, 0.8, t)
	_body.position.y = -lift * t


func _kill_ghost() -> void:
	if _ghost != null and _ghost.is_valid():
		_ghost.kill()
	_ghost = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or box.is_empty() or slot < 0:
		return null
	var preview := (load(SCENE_PATH) as PackedScene).instantiate() as Button
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.focus_mode = Control.FOCUS_NONE
	set_drag_preview(preview)
	preview.setup(row, { "box": box, "slot": -1, "bed": size.x })
	preview.modulate.a = 0.92
	(preview.get_node("%Body") as Control).position = -size * 0.5
	drag_began.emit(self)
	return { "item_drag": true, "from": box, "slot": slot, "row": row }


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drop_check.is_valid() and bool(drop_check.call(data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if drop_apply.is_valid():
		drop_apply.call(data)
