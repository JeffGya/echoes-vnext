extends VBoxContainer

## The party pack button with its single count (D-39) and the one departure line above it (D-36).
## Used by party details (party prep) and the path HUD. It only reports a press; the shell opens the pack panel.
## It reads `data.inventory`: `pack_count`, `pack_capacity`, `pack_load.level`.

signal toggle_requested

const ItemUiText := preload("res://ui/components/ItemUiText.gd")

@onready var _depart_line: HBoxContainer = %DepartLine
@onready var _leaf: Control = %LeafMark
@onready var _depart_label: Label = %DepartLabel
@onready var _button: Button = %PackButton
@onready var _mark: Control = %PackMark
@onready var _title: Label = %PackTitleLabel
@onready var _count: Label = %PackCountLabel
@onready var _chevron: Label = %PackChevron

var _open := false


func _ready() -> void:
	_title.text = ItemUiText.PARTY_PACK_BUTTON
	_depart_label.text = ItemUiText.DEPART_LINE
	_button.pressed.connect(func() -> void: toggle_requested.emit())
	_sync_open()


func set_inventory(inv: Dictionary) -> void:
	var carried := int(inv.get("pack_count", 0))
	var capacity := int(inv.get("pack_capacity", 0))
	var load_v: Variant = inv.get("pack_load", {})
	var level := int((load_v as Dictionary).get("level", 0)) if load_v is Dictionary else 0
	_count.text = ItemUiText.sockets_word(carried, capacity)
	_mark.level = level
	_depart_line.visible = carried > 0
	_button.tooltip_text = "%s, %s" % [ItemUiText.PARTY_PACK_BUTTON, _count.text]
	if "accessibility_name" in _button:
		_button.set("accessibility_name", _button.tooltip_text)


## The departure line sits on a dark surface (the path HUD) or a light panel (party details).
func set_on_dark(on: bool) -> void:
	_depart_label.theme_type_variation = &"ItemTextDark" if on else &"ItemTextLight"
	_leaf.leaf_tone = "cream" if on else "ink"


func set_open(open: bool) -> void:
	_open = open
	_sync_open()


func is_open() -> bool:
	return _open


func _sync_open() -> void:
	_button.theme_type_variation = &"ItemPackButtonOpen" if _open else &"ItemPackButton"
	_chevron.text = "<" if _open else ">"
