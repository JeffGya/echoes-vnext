# res://ui/components/CauseTooltip.gd
# Floating "why" tooltip for one payout row. One instance per screen, last child so it draws on top
# (top_level + z_index). It never takes part in a container, so opening it never moves a row.
# Opens on hover, focus or tap of a row's (i) button. Closes on a tap outside the (i) or on Esc.

class_name CauseTooltip
extends Control

## Gap between the (i) button and the panel, in logical units.
@export var anchor_gap: float = 10.0
## Smallest distance kept between the panel and the screen edge.
@export var screen_margin: float = 8.0
## Smallest distance kept between the arrow and a panel corner.
@export var arrow_inset: float = 20.0

@onready var _panel: PanelContainer = %Panel
@onready var _arrow: Panel = %Arrow
@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel

var _anchor: Control = null
var _pinned := false


func is_open() -> bool:
	return visible


func anchor() -> Control:
	return _anchor


func is_pinned() -> bool:
	return _pinned


## pinned is true for a tap. A second tap on the same anchor closes the tooltip.
func show_for(anchor_control: Control, title: String, text: String, pinned: bool) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	var same := visible and _anchor == anchor_control
	if pinned and same and _pinned:
		hide_tooltip()
		return
	_pinned = pinned or (same and _pinned)
	_anchor = anchor_control
	_title.text = title
	_body.text = text
	_panel.reset_size()
	visible = true
	_place()
	# Wrapped text settles one layout pass later; place again with the final height.
	_place.call_deferred()


## force false (mouse left) keeps a tapped tooltip open.
func release(anchor_control: Control, force: bool) -> void:
	if anchor_control != _anchor:
		return
	if force or not _pinned:
		hide_tooltip()


func hide_tooltip() -> void:
	visible = false
	_anchor = null
	_pinned = false


func _place() -> void:
	if not visible or _anchor == null or not is_instance_valid(_anchor):
		return
	_panel.reset_size()
	var panel_size := _panel.size
	var anchor_rect := _anchor.get_global_rect()
	var screen := get_viewport_rect()
	var center_x := anchor_rect.position.x + anchor_rect.size.x * 0.5
	var left := clampf(center_x - panel_size.x * 0.5,
		screen.position.x + screen_margin, screen.end.x - panel_size.x - screen_margin)
	var below_top := anchor_rect.end.y + anchor_gap
	var below := below_top + panel_size.y + screen_margin <= screen.end.y
	var top := below_top if below else anchor_rect.position.y - anchor_gap - panel_size.y
	top = clampf(top, screen.position.y + screen_margin, maxf(screen.position.y + screen_margin, screen.end.y - panel_size.y - screen_margin))
	global_position = Vector2(left, top)
	var arrow_x := clampf(center_x - left, arrow_inset, panel_size.x - arrow_inset)
	var half := _arrow.size.x * 0.5
	_arrow.position = Vector2(arrow_x - half, -half if below else panel_size.y - half)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_tooltip()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if _anchor == null or not _anchor.get_global_rect().has_point(_anchor.get_global_mouse_position()):
			hide_tooltip()
