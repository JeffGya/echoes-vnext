# res://ui/screens/venture/StepProgressBar.gd
# V2-STAGE-004 Phase 5: kente-diamond step budget display for the explore action bar.
#
# One diamond segment per step. The segment count is set by the screen via set_budget():
# while PARKED it equals the directive's step_budget (how far the party can go at rest);
# while IN MOTION it equals the number of tiles actually walked this advance (traveled_path
# segment count), so the bar depletes cleanly to zero in sync with the travel tween instead
# of showing the full budget with a dimmed, confusing remainder. Filled diamonds represent
# steps still available; dimmed diamonds represent spent steps. The filled count decrements
# as the party's travel tween walks each cell of traveled_path (screen calls set_spent()),
# and is reset by set_budget() at the start of each snapshot render.
#
# This node draws its diamonds via _draw() only (canvas drawing — permitted in script per
# Lesson 5; no child nodes are constructed here). The adjacent fraction label ("3/5") is an
# authored sibling Label the screen updates directly.
#
# Graceful degradation: budget defaults to 0. When step_budget is absent from the snapshot
# the screen simply never calls set_budget()/set_spent() with meaningful values, the node
# draws nothing, and the container collapses to zero height — the screen renders as today.

extends Control

const _DIAMOND_W: float   = 14.0     # half-width of each diamond
const _DIAMOND_H: float   = 9.0      # half-height of each diamond
const _GAP:       float   = 8.0      # horizontal gap between diamond centres beyond width

const _COLOR_FILLED  := Color("#C8A96E")               # Akan Gold — available step
const _COLOR_SPENT   := Color(0.30, 0.30, 0.36, 0.70)  # dim slate — spent step
const _COLOR_BORDER  := Color(0.0, 0.0, 0.0, 0.55)     # subtle outline for legibility

var _budget: int = 0
var _spent:  int = 0


func _ready() -> void:
	# Height enough to hold a diamond with a little padding.
	custom_minimum_size = Vector2(0.0, (_DIAMOND_H * 2.0) + 6.0)


## Set the total number of diamonds (step_budget). Resets spent to 0.
func set_budget(budget: int) -> void:
	_budget = max(0, budget)
	_spent  = 0
	_update_min_width()
	queue_redraw()


## Set how many leading diamonds are dimmed (steps already consumed this turn).
func set_spent(spent: int) -> void:
	_spent = clampi(spent, 0, _budget)
	queue_redraw()


func _update_min_width() -> void:
	var seg_span: float = (_DIAMOND_W * 2.0) + _GAP
	var total_w: float  = 0.0 if _budget <= 0 else seg_span * float(_budget) - _GAP
	custom_minimum_size = Vector2(total_w, (_DIAMOND_H * 2.0) + 6.0)


func _draw() -> void:
	if _budget <= 0:
		return
	var seg_span: float = (_DIAMOND_W * 2.0) + _GAP
	var cy: float       = size.y * 0.5
	for i in range(_budget):
		var cx: float = _DIAMOND_W + float(i) * seg_span
		var centre := Vector2(cx, cy)
		var filled: bool = i >= _spent   # leading _spent diamonds are dimmed
		var fill: Color  = _COLOR_FILLED if filled else _COLOR_SPENT
		_draw_diamond(centre, fill)


func _draw_diamond(centre: Vector2, fill: Color) -> void:
	var pts := PackedVector2Array([
		centre + Vector2(0.0,          -_DIAMOND_H),
		centre + Vector2( _DIAMOND_W,   0.0),
		centre + Vector2(0.0,           _DIAMOND_H),
		centre + Vector2(-_DIAMOND_W,   0.0),
	])
	draw_colored_polygon(pts, fill)
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		_COLOR_BORDER, 1.0, true
	)
