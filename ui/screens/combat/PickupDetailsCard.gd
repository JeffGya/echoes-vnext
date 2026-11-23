class_name PickupDetailsCard
extends Control

## The details card of one item in the pickup event (V2-ITEM-001b U7). It shows the shared `ItemDetailsBlock` and a Close button.
## It sits in its own CanvasLayer above the bark layer, with an arrow toward the item. It sends no action itself: Close and Esc
## emit `close_requested`. There is no motion (B8) and no Swap button yet (U8).

signal close_requested

const ItemUiText := preload("res://ui/components/ItemUiText.gd")

## Layout geometry, not a feel value, so it stays in code and not in data/balance.json (ANSWERS #83, documented reason).
## GAP: distance from the item to the card. The arrow is a 14 px square turned 45 degrees (half diagonal 9.9), so it never reaches the item.
const GAP := 12.0
## ARROW_INSET: keeps the arrow off the rounded card corner: the `ItemDetailsPanel` corner radius (16) plus half the arrow (7), rounded up.
const ARROW_INSET := 24.0

@onready var _panel: PanelContainer = %Panel
@onready var _arrow: Panel = %Arrow
@onready var _block: ItemDetailsBlock = %Block
@onready var _close: Button = %CloseButton

var _id := ""
var _plan: Dictionary = {}


func _ready() -> void:
	_close.text = PickupUiText.line("btn.close")
	_close.pressed.connect(func() -> void: close_requested.emit())


## Open means shown now: the card layer follows the stage, so a hidden board closes the card for input too.
func is_open() -> bool:
	var layer := get_parent() as CanvasLayer
	return visible and not _id.is_empty() and (layer == null or layer.visible)


func current_id() -> String:
	return _id


func close_button() -> Button:
	return _close


func block() -> ItemDetailsBlock:
	return _block


# UNWIRED (target: V2-ITEM-002): the catalogue gives each item a description line; the card shows none until then
## `sel` is a `PickupHitRules.selection` result.
func show_selection(sel: Dictionary) -> void:
	var row: Dictionary = sel["row"]
	var pack := str(sel["side"]) == "pack"
	if _id != str(sel["id"]):
		_plan = {}
	_id = str(sel["id"])
	_block.show_row(row, PickupUiText.where_text("pack" if pack else "ground"), { "box": "pack" if pack else "", "bed": 88 })
	if "accessibility_name" in _close:
		_close.set("accessibility_name", "%s, %s, %s" % [_close.text, PickupUiText.line("a11y.details"), ItemUiText.display_name(row)])
	visible = true


func hide_card() -> void:
	_id = ""
	_plan = {}
	visible = false


## Places the card by `PickupDetailsPlan` and returns the plan. `anchor` is the item's screen rect, `usable` where the card may lie,
## `obstacles` what it should not cover; `first` and `last` tell whether a pack tile ends the strip. The card keeps its side from the
## last call for the same item. Called again on every camera move.
func place(anchor: Rect2, usable: Rect2, obstacles: Array, kind: String, first: bool = true, last: bool = true) -> Dictionary:
	_panel.reset_size()
	var size_v := _panel.get_combined_minimum_size()
	_plan = PickupDetailsPlan.plan(anchor, size_v, usable, obstacles, kind, GAP, ARROW_INSET, first, last, str(_plan.get("side", "")))
	_panel.position = _plan["position"]
	_panel.size = size_v
	# The arrow is a square turned 45 degrees behind the panel, so the same node points out of any edge.
	_arrow.position = (_plan["position"] as Vector2) + (_plan["arrow_at"] as Vector2) - _arrow.size * 0.5
	return _plan


func last_plan() -> Dictionary:
	return _plan


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
