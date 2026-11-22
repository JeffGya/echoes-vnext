class_name ItemDetailsBlock
extends VBoxContainer

## The detail block of one item: a big tile, name, kind, grade, count and a where line. The 001a panels and the pickup
## details card both show it, so both read the same lines from the same rows.

const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const ItemMovePlan := preload("res://ui/components/ItemMovePlan.gd")

@onready var _tile: Button = %BigTile
@onready var _name: Label = %NameLabel
@onready var _kind: Label = %KindLabel
@onready var _grade: Label = %GradeLabel
@onready var _count: Label = %CountLabel
@onready var _where: Label = %WhereLabel


## `tile_opts` goes to `ItemTile.setup` (box, bed, ring). `where` is the line under the block.
func show_row(row: Dictionary, where: String, tile_opts: Dictionary) -> void:
	var stack := ItemMovePlan.is_stack(row)
	_tile.setup(row, tile_opts)
	_tile.set_selected(false)
	_name.text = ItemUiText.display_name(row)
	_kind.text = "%s: %s" % [ItemUiText.KIND_LABEL, ItemUiText.kind_name(str(row.get("kind", "")))]
	var pips: int = _tile.pips_of(row)
	_grade.visible = not stack and pips > 0
	_grade.text = "%s: %d" % [ItemUiText.GRADE_LABEL, pips]
	if stack:
		var limit_text := ItemUiText.stack_count(int(row.get("count", row.get("quantity", 0))), int(row.get("stack_limit", 0)))
		_count.text = "%s: %s%s" % [ItemUiText.COUNT_LABEL, limit_text,
			(" " + ItemUiText.AT_LIMIT) if bool(row.get("at_limit", false)) else ""]
	else:
		_count.text = "%s: 1" % ItemUiText.COUNT_LABEL
	_where.text = where


func tile() -> Button:
	return _tile
