class_name BoardCameraController
extends Camera2D

## Shared board camera controller for Sanctum, Combat, and Stage Exploration
## (docs/stories/v2-combat-003.5/decisions.md #66-74). Script-only component attached to a
## real Camera2D node already present in each screen's own scene — see AGENTS.md's "never
## build UI structure in .gd" rule; a Camera2D has no children to construct here.
##
## Continuous zoom/pan primitive only. Discrete zoom-level snapping (Sanctum) and the
## follow-curve/resume-delay tuning for Combat/Stage stay in the consuming screen — decision #72
## keeps this component's zoom primitive continuous, not a shared discrete/continuous toggle.

enum Mode { FREE, FOLLOW_ACTOR, FOLLOW_PARTY }

## Current mode. FREE is the default on entry and after deselect() — decision #68.
var mode: int = Mode.FREE
## The actors-array id currently locked via select(), empty outside FOLLOW_ACTOR.
var target_id: String = ""

var _content_size := Vector2.ZERO
var _bounds_pad := 0.0

var _min_zoom := 0.5
var _max_zoom := 2.0

const _PAN_SPEED := 2.5
var _is_panning := false

## True once the player has panned or pinched. Screens that auto-center on content refresh must
## stop doing so after this, or every refresh undoes the player's view.
var has_manual_override := false

var _follow_target_local := Vector2.ZERO
var _has_follow_target := false
# decision #72: keep the proven PURSUE lerp speed, now applied to every selection-lock.
const _FOLLOW_LERP_SPEED := 5.0


func _process(delta: float) -> void:
	# Only screens that actively push a follow target (Combat/Stage, later stories) get the
	# per-frame lerp. Sanctum drives its own tweened focus-zoom and never calls
	# set_follow_target_local(), so this stays a no-op for it — avoids fighting that tween.
	if not _has_follow_target or mode == Mode.FREE:
		return
	position = position.lerp(_follow_target_local, clampf(_FOLLOW_LERP_SPEED * delta, 0.0, 1.0))
	_clamp_to_bounds()


func configure_bounds(content_size_px: Vector2, pad_px: float = 0.0) -> void:
	_content_size = content_size_px
	_bounds_pad = pad_px


func configure_zoom_range(min_zoom: float, max_zoom: float, default_zoom: float) -> void:
	_min_zoom = min_zoom
	_max_zoom = max_zoom
	zoom = Vector2(default_zoom, default_zoom)


func select(target_id_in: String) -> void:
	mode = Mode.FOLLOW_ACTOR
	target_id = target_id_in
	_has_follow_target = false


func follow_party() -> void:
	mode = Mode.FOLLOW_PARTY
	target_id = ""
	_has_follow_target = false


func deselect() -> void:
	mode = Mode.FREE
	target_id = ""
	_has_follow_target = false


func set_follow_target_local(pos: Vector2) -> void:
	_follow_target_local = pos
	_has_follow_target = true


func notify_content_resized(new_content_size_px: Vector2) -> void:
	_content_size = new_content_size_px
	_clamp_to_bounds()


## Re-applies the position clamp against the last configure_bounds()/zoom values, without
## changing bounds or zoom range. Callers use this after they change zoom themselves (discrete
## snap, tween) or after content/viewport geometry changes, exactly at the same points the
## pre-extraction code called its own private clamp — see SanctumShell.gd call sites.
func reclamp() -> void:
	_clamp_to_bounds()


# Input is split across two callbacks on purpose. Moving the gestures back into _input() makes
# the camera take every trackpad scroll in the app, so no ScrollContainer can scroll
# (BoardCameraInputTests proves both halves).
#   _input():            Space+LMB drag. It must run before the GUI pass, because the screen's
#                        full-rect MOUSE_FILTER_STOP chrome absorbs mouse buttons there.
#   _unhandled_input():  pinch and two-finger pan. The GUI pass gives these to the Control under
#                        the pointer first, so a panel under the cursor keeps its own scrolling.
# Locked modes (not FREE) suppress manual pan/zoom. A disabled camera (its screen is hidden)
# takes no input, because _input() still runs for hidden nodes.
func _accepts_manual_input() -> bool:
	return enabled and mode == Mode.FREE


func _input(event: InputEvent) -> void:
	if not _accepts_manual_input():
		_is_panning = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and Input.is_key_pressed(KEY_SPACE):
				_is_panning = true
				get_viewport().set_input_as_handled()
				return
			if not mb.pressed and _is_panning:
				_is_panning = false
				get_viewport().set_input_as_handled()
				return
		return

	if event is InputEventMouseMotion:
		if _is_panning:
			_pan_by_screen_delta((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_manual_input():
		return

	if event is InputEventMagnifyGesture:
		var factor := (event as InputEventMagnifyGesture).factor
		zoom = (zoom * factor).clamp(Vector2(_min_zoom, _min_zoom), Vector2(_max_zoom, _max_zoom))
		has_manual_override = true
		_clamp_to_bounds()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventPanGesture:
		_pan_by_screen_delta((event as InputEventPanGesture).delta)
		get_viewport().set_input_as_handled()


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	# Camera moves opposite to drag direction for "grab world" feel.
	var z := zoom.x
	if z <= 0.0:
		z = 1.0
	position -= (screen_delta * _PAN_SPEED) / z
	has_manual_override = true
	_clamp_to_bounds()


## The position the bounds clamp allows at at_zoom. Tween to this, not to a raw target: the
## reclamp after a tween would otherwise snap the view.
func clamped_position(pos: Vector2, at_zoom: Vector2) -> Vector2:
	if _content_size == Vector2.ZERO:
		return pos
	var safe_zoom := Vector2(maxf(at_zoom.x, 0.001), maxf(at_zoom.y, 0.001))
	var half_view := (get_viewport_rect().size / safe_zoom) * 0.5
	# Bounds are symmetric about local origin — every consuming screen is responsible for
	# centering its content on that origin before calling configure_bounds() (Sanctum already
	# does this via _center_camera_on_floor()).
	var half_content := _content_size * 0.5
	# The view-edge term alone goes negative on any axis where content plus pad fits in the view,
	# which locked that axis at center. The half_content floor keeps each axis pannable to the
	# content edge.
	var limit := Vector2(
		maxf(half_content.x + _bounds_pad - half_view.x, half_content.x),
		maxf(half_content.y + _bounds_pad - half_view.y, half_content.y))
	return pos.clamp(-limit, limit)


func _clamp_to_bounds() -> void:
	position = clamped_position(position, zoom)
