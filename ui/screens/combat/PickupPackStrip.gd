class_name PickupPackStrip
extends Control

## The Travel pack on the pickup event (V2-ITEM-001b U4). Reads `data.pack`, `swap_left`, `destroy_left`, `phase`.
## Static: no motion (U6) and no tappable tiles (U7). Slots are authored in the scene (eight at most); the script
## shows `capacity` of them. Reuses ItemSlot and ItemTile from the 001a pack. No strap line (D-59).
## `phase == intro` shows only the pre-event contents: the taken finds fly in later (U6).
## Position: bottom edge GAP_ABOVE_BAR above the EchoBar top (D-69). `place` gets that top from the board.
## Root `modulate.a` is the fade hook of U6.

const ItemUiText := preload("res://ui/components/ItemUiText.gd")

const MAX_SLOTS := 8
const GAP_ABOVE_BAR := 24.0
const BED_DEFAULT := 72
const BED_COMPACT := 64
const FALLBACK_BAR_HEIGHT := 104.0
const TONE_VARIATION := {
	"plain": &"ItemPanelPack",
	"near": &"ItemPanelPackNear",
	"full": &"ItemPanelPackHeavy",
}
const SOURCE_TILE := { "held": "held", "gathered": "gathered", "stack": "gathered" }

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %TitleLabel
@onready var _word: Label = %WordLabel
@onready var _swap_token: PanelContainer = %SwapToken
@onready var _swap_count: Label = %SwapCount
@onready var _destroy_token: PanelContainer = %DestroyToken
@onready var _destroy_count: Label = %DestroyCount
@onready var _slots_box: HBoxContainer = %Slots

var _slots: Array[Control] = []
var _view: Dictionary = {}
var _sig := ""
var _bed: int = BED_DEFAULT
var _bar_top: float = NAN
var _renders := 0


func _ready() -> void:
	for child in _slots_box.get_children():
		_slots.append(child as Control)
	_title.text = ItemUiText.PACK_TITLE
	if not _view.is_empty():
		_render()
	_place()


## Idempotent: the same content draws nothing again.
func apply_snapshot(snapshot: Dictionary) -> void:
	_view = view_of(snapshot)
	if is_node_ready():
		_render()
		_place()


func set_profile(profile: StringName) -> void:
	var next: int = BED_COMPACT if profile == &"compact" else BED_DEFAULT
	if next == _bed:
		return
	_bed = next
	if is_node_ready():
		_render()
		_place()


## `bar_top_global` is the top edge of the EchoBar in global coordinates; NAN uses the shell's own bar height.
func place(bar_top_global: float) -> void:
	_bar_top = bar_top_global
	if is_node_ready():
		_place()


func slot_count() -> int:
	return int(_view.get("count", 0))


func slot_global_center(index: int) -> Vector2:
	if _slots.is_empty() or slot_count() <= 0:
		return Vector2.ZERO
	return _slots[clampi(index, 0, slot_count() - 1)].get_global_rect().get_center()


func panel_global_rect() -> Rect2:
	return _panel.get_global_rect()


func render_count() -> int:
	return _renders


func view() -> Dictionary:
	return _view


## Pure: snapshot -> { count, tone, cells[{kind: item|unlisted|empty, row}], swap_left, destroy_left }.
static func view_of(snapshot: Dictionary) -> Dictionary:
	var data: Dictionary = _dict(snapshot.get("data", {}))
	var pack: Dictionary = _dict(data.get("pack", {}))
	var intro: bool = str(data.get("phase", "")) == "intro"
	var listed: Array = _arr(pack.get("slots", []))
	var cells: Array = []
	for s_v: Variant in listed:
		var s: Dictionary = _dict(s_v)
		if intro and not str(s.get("find_id", "")).is_empty():
			continue
		cells.append({ "kind": "item", "row": s })
	var unlisted: int = maxi(0, int(pack.get("carried", 0)) - listed.size())
	for _i in unlisted:
		cells.append({ "kind": "unlisted", "row": {} })
	var capacity: int = int(pack.get("capacity", 0))
	var count: int = clampi(maxi(capacity if capacity > 0 else PickupEventPlan.PACK_SLOTS_DEFAULT, cells.size()), 1, MAX_SLOTS)
	var used: int = mini(cells.size(), count)
	while cells.size() < count:
		cells.append({ "kind": "empty", "row": {} })
	cells.resize(count)
	var tone: String = str(pack.get("tone", "plain"))
	if intro:
		tone = tone_for(used, count)
	return { "count": count, "tone": tone, "cells": cells,
		"swap_left": int(data.get("swap_left", 0)), "destroy_left": int(data.get("destroy_left", 0)) }


## Same rule as the mockup `packTone` and `PickupEventPlan._tone_for`: full at no free slot, near at one free slot.
static func tone_for(used: int, count: int) -> String:
	if used >= count:
		return "full"
	return "near" if used == count - 1 else "plain"


static func bottom_edge(bar_top_global: float) -> float:
	return bar_top_global - GAP_ABOVE_BAR


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


func _render() -> void:
	var sig := JSON.stringify([_view, _bed], "", true)
	if sig == _sig:
		return
	_sig = sig
	_renders += 1
	var tone: String = str(_view.get("tone", "plain"))
	var variation: StringName = TONE_VARIATION.get(tone, &"ItemPanelPack")
	_panel.theme_type_variation = variation
	_word.text = PickupUiText.tone_word(tone)
	_word.visible = not _word.text.is_empty()
	_token(_swap_token, _swap_count, int(_view.get("swap_left", 0)), PickupUiText.swap_allowance(int(_view.get("swap_left", 0))))
	_token(_destroy_token, _destroy_count, int(_view.get("destroy_left", 0)), PickupUiText.destroy_allowance(int(_view.get("destroy_left", 0))))
	var cells: Array = _arr(_view.get("cells", []))
	var count: int = int(_view.get("count", 0))
	for i in _slots.size():
		var slot: Control = _slots[i]
		slot.visible = i < count
		if i >= count:
			continue
		var cell: Dictionary = _dict(cells[i])
		var kind: String = str(cell.get("kind", "empty"))
		var back: Panel = slot.get_node("Back") as Panel
		slot.call("setup", "pack", i, _bed)
		if kind == "item":
			var row: Dictionary = _dict(cell.get("row", {}))
			var source: String = str(SOURCE_TILE.get(str(row.get("source", "")), ""))
			back.theme_type_variation = &"ItemSlotPack"
			slot.call("set_content", row, { "bed": _bed, "source": source })
			(slot.call("tile") as Button).focus_mode = Control.FOCUS_NONE
		else:
			back.theme_type_variation = &"ItemSlotPack" if kind == "unlisted" else &"PickupSlotEmpty"
			slot.call("set_content", {}, {})
		if "accessibility_name" in slot:
			slot.set("accessibility_name", PickupUiText.line("a11y.empty_slot") if kind == "empty" else "")


func _token(token: PanelContainer, count_label: Label, left: int, line: String) -> void:
	count_label.text = str(left)
	token.tooltip_text = line
	token.theme_type_variation = &"PickupAllowance" if left > 0 else &"PickupAllowanceSpent"
	if "accessibility_name" in token:
		token.set("accessibility_name", line)


func _place() -> void:
	var host := get_parent() as Control
	var host_bottom: float = host.get_global_rect().end.y if host != null else 0.0
	var bar_top: float = _bar_top if not is_nan(_bar_top) else host_bottom - FALLBACK_BAR_HEIGHT
	var size_v: Vector2 = _panel.get_combined_minimum_size()
	offset_left = -size_v.x * 0.5
	offset_right = size_v.x * 0.5
	offset_bottom = bottom_edge(bar_top) - host_bottom
	offset_top = offset_bottom - size_v.y
	# Containers sort on the next frame; a flight or a test reads the slot rects now.
	for node: Node in [_panel, _panel.get_child(0), _slots_box.get_parent(), _slots_box]:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
