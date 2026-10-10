class_name BoardCameraController
extends Camera2D

## Shared board camera controller for Sanctum, Combat, and Stage Exploration
## (ANSWERS.md #74-79; docs/stories/v2-combat-003.5/decisions.md #70-74). Script-only component attached to a
## real Camera2D node already present in each screen's own scene — see AGENTS.md's "never
## build UI structure in .gd" rule; a Camera2D has no children to construct here.
##
## Zoom is continuous (pinch, and the eased wheel where wheel_zoom_step is set) plus optional
## discrete levels: zoom_levels, stepped by Z and by step_zoom_level() (decisions.md #93-#95).
## Each screen sets its own exports in its scene (manual_resume_delay, wheel, levels, Space guard).

enum Mode { FREE, FOLLOW_ACTOR, FOLLOW_PARTY }

## Current mode. FREE is the default on entry and after deselect() — ANSWERS.md #76.
var mode: int = Mode.FREE
## The actors-array id currently locked via select(), empty outside FOLLOW_ACTOR.
var target_id: String = ""

var _content_size := Vector2.ZERO
var _bounds_pad := 0.0

var _min_zoom := 0.5
var _max_zoom := 2.0

# Trackpad two-finger pan only. Every drag (mouse, finger, Space+LMB) is 1:1 through drag_pan().
const _PAN_SPEED := 2.5
var _is_panning := false

## True once the player has panned or pinched. Screens that auto-center on content refresh must
## stop doing so after this, or every refresh undoes the player's view.
var has_manual_override := false

var _follow_target_local := Vector2.ZERO
var _has_follow_target := false
# decisions.md #72: keep the proven PURSUE lerp speed, now applied to every selection-lock.
const _FOLLOW_LERP_SPEED := 5.0

## Seconds a manual pan or pinch pauses a lock before the follow resumes (decisions.md #72: 3.0 for
## Combat). 0 means a locked camera ignores manual input, which Sanctum's detail view relies on.
@export var manual_resume_delay := 0.0
var _follow_hold_left := 0.0

## Zoom factor per mouse-wheel notch (eased). 0 turns wheel zoom off.
@export var wheel_zoom_step := 0.0
## Set: the wheel is read in _input and zooms only while this Control is the hovered control, that
## is, over open board; any panel, card or scroll area above the board is hovered instead.
## Null: the wheel is read in _unhandled_input, so a scroll area under the pointer takes it first.
@export var wheel_surface: Control
## When FREE, zoom keeps the world point under the pointer in place. A locked camera always zooms
## about the screen centre, so its target stays centred.
@export var zoom_to_pointer := false
## Space+LMB drag pan. Sanctum needs it (it has no plain drag). Combat turns it off: its screen
## pans every one-pointer drag 1:1 itself, and a second drag here would stack on top of that.
@export var space_drag_pan := true
## Space never presses a focused button while this is true (see _input). A shell turns it off
## while a sub-screen covers the board, so Space works on that screen's buttons.
@export var guard_space_on_buttons := true
## Discrete zoom levels for Z and step_zoom_level(). Empty turns Z off. Levels are clamped into the
## current zoom range, sorted and de-duplicated.
@export var zoom_levels := PackedFloat32Array()
# True while a screen tween (Sanctum's echo-detail focus and restore) owns zoom and position.
var _screen_animating := false

# Wheel zoom eases toward _zoom_target (0 = no ease running). Pinch stays immediate and cancels
# the ease. The ease runs in _process with the follow, so the two never fight like a Tween would.
var _zoom_target := 0.0
var _zoom_anchor := Vector2.ZERO
const _ZOOM_EASE_SPEED := 12.0


func _process(delta: float) -> void:
	# The zoom ease (wheel, Z, step_zoom_level) runs on every screen. The follow lerp runs only
	# when a screen pushes a target (Combat; Sanctum never calls set_follow_target_local()).
	# A screen tween holds both off through begin_screen_animation().
	if _zoom_target > 0.0:
		_step_zoom_ease(delta)
	if _follow_hold_left > 0.0:
		_follow_hold_left -= delta
		return
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
	_zoom_target = 0.0
	zoom = Vector2(default_zoom, default_zoom)


func select(target_id_in: String) -> void:
	mode = Mode.FOLLOW_ACTOR
	target_id = target_id_in
	_has_follow_target = false
	_follow_hold_left = 0.0


func follow_party() -> void:
	mode = Mode.FOLLOW_PARTY
	target_id = ""
	_has_follow_target = false
	_follow_hold_left = 0.0


func deselect() -> void:
	mode = Mode.FREE
	target_id = ""
	_has_follow_target = false
	_follow_hold_left = 0.0


## True while a manual pan or pinch holds the lock paused.
func is_follow_held() -> bool:
	return _follow_hold_left > 0.0


## One-finger or mouse drag from the screen's own pointer tracking, which also tells a tap from a
## drag. 1:1 grab-the-world: the board point under the pointer stays under it.
func drag_pan(screen_delta: Vector2) -> void:
	if not _accepts_manual_input():
		return
	position -= screen_delta / maxf(zoom.x, 0.001)
	_note_manual_input()
	_clamp_to_bounds()


func set_follow_target_local(pos: Vector2) -> void:
	_follow_target_local = pos
	_has_follow_target = true


func notify_content_resized(new_content_size_px: Vector2) -> void:
	_content_size = new_content_size_px
	_clamp_to_bounds()


## Re-applies the position clamp against the last configure_bounds()/zoom values, without
## changing bounds or zoom range. Callers use this after they set zoom or position themselves
## (a tween) or after content or viewport geometry changes.
func reclamp() -> void:
	_clamp_to_bounds()


# Input is split across two callbacks on purpose. Moving the gestures back into _input() makes
# the camera take every trackpad scroll in the app, so no ScrollContainer can scroll
# (BoardCameraInputTests proves both halves).
#   _input():            Space+LMB drag. It must run before the GUI pass, because the screen's
#                        full-rect MOUSE_FILTER_STOP chrome absorbs mouse buttons there.
#                        Wheel zoom too when wheel_surface is set (hover gate); otherwise the
#                        wheel is read in _unhandled_input, after the GUI pass.
#   _unhandled_input():  pinch and two-finger pan. The GUI pass gives these to the Control under
#                        the pointer first, so a panel under the cursor keeps its own scrolling.
# Locked modes (not FREE) suppress manual pan/zoom unless manual_resume_delay is set. A disabled
# camera (its screen is hidden) takes no input, because _input() still runs for hidden nodes.
func _accepts_manual_input() -> bool:
	return enabled and not _screen_animating and (mode == Mode.FREE or manual_resume_delay > 0.0)


## A screen tween is about to drive zoom and position. Stops a running ease and blocks manual
## input until end_screen_animation(), so the two never write the zoom in the same frame.
func begin_screen_animation() -> void:
	_screen_animating = true
	_zoom_target = 0.0
	_is_panning = false


func end_screen_animation() -> void:
	_screen_animating = false


func cancel_zoom_ease() -> void:
	_zoom_target = 0.0


## The zoom the view is heading to: the ease target while easing, else the current zoom.
func zoom_goal() -> Vector2:
	return Vector2(_zoom_target, _zoom_target) if _zoom_target > 0.0 else zoom


## One level up (direction 1) or down (-1) through zoom_levels, eased about the screen centre.
## wrap: past the highest level go to the lowest (the Z key). Without wrap the ends hold.
## Returns false when the camera takes no manual zoom now.
func step_zoom_level(direction: int, wrap := false) -> bool:
	if not _accepts_manual_input():
		return false
	var levels := _usable_zoom_levels()
	if levels.is_empty():
		return false
	_zoom_target = _adjacent_zoom_level(levels, zoom_goal().x, direction, wrap)
	_zoom_anchor = get_viewport_rect().size * 0.5
	_note_manual_input()
	return true


func _note_manual_input() -> void:
	has_manual_override = true
	if mode != Mode.FREE:
		_follow_hold_left = manual_resume_delay


func _input(event: InputEvent) -> void:
	# Space is the pan key on a board screen. A button keeps keyboard focus after a click, and
	# Space (ui_accept) would press it again. Swallow Space before the GUI pass when a button outside
	# a modal has focus. Needs only `enabled`, so it also covers a locked camera (Sanctum's echo
	# detail). Text fields and modal buttons still get Space; Input.is_key_pressed() still reads it.
	if enabled and guard_space_on_buttons and event is InputEventKey and _is_space(event as InputEventKey):
		if _space_would_press_board_button():
			get_viewport().set_input_as_handled()
		return

	if not _accepts_manual_input():
		_is_panning = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and wheel_surface != null and _is_wheel_zoom(mb):
			_wheel_zoom(mb)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and space_drag_pan and Input.is_key_pressed(KEY_SPACE):
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
			drag_pan((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_manual_input():
		return

	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_zoom_by(magnify.factor, magnify.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventPanGesture:
		_pan_by_screen_delta((event as InputEventPanGesture).delta)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and wheel_surface == null and _is_wheel_zoom(mb):
			_wheel_zoom(mb)
		return

	# Z in _unhandled_input, so a focused text field keeps the letter.
	if event is InputEventKey and _is_zoom_cycle_key(event as InputEventKey):
		if step_zoom_level(1, true):
			get_viewport().set_input_as_handled()


# Only a plain Z (Shift allowed): Ctrl/Cmd/Alt+Z are shortcuts such as undo.
func _is_zoom_cycle_key(key: InputEventKey) -> bool:
	return not zoom_levels.is_empty() and key.pressed and not key.echo and key.keycode == KEY_Z \
			and not key.ctrl_pressed and not key.meta_pressed and not key.alt_pressed


func _usable_zoom_levels() -> Array:
	var out: Array = []
	for level in zoom_levels:
		var z := clampf(level, _min_zoom, _max_zoom)
		if not out.any(func(o: float) -> bool: return is_equal_approx(o, z)):
			out.append(z)
	out.sort()
	return out


# Relative to the current zoom, not an index, so stepping also works after a wheel or pinch zoom.
static func _adjacent_zoom_level(levels: Array, current: float, direction: int, wrap: bool) -> float:
	if direction > 0:
		for level in levels:
			if level > current + 0.001:
				return level
		return levels[0] if wrap else levels[-1]
	for i in range(levels.size() - 1, -1, -1):
		if levels[i] < current - 0.001:
			return levels[i]
	return levels[-1] if wrap else levels[0]


static func _is_space(key: InputEventKey) -> bool:
	return key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE


# A modal is a dialog the player answers with the keyboard; ModalHost moves focus into it.
func _space_would_press_board_button() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if not (focused is BaseButton):
		return false
	var node: Node = focused
	while node != null:
		if node is ModalHost:
			return false
		node = node.get_parent()
	return true


# With wheel_surface set, the wheel is handled in _input(), before the GUI pass, so the hover test
# decides alone: over open board the hovered control is wheel_surface itself. Without it, the
# GUI pass has already offered the wheel to the Control under the pointer.
func _is_wheel_zoom(mb: InputEventMouseButton) -> bool:
	if wheel_zoom_step <= 0.0:
		return false
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	return wheel_surface == null or get_viewport().gui_get_hovered_control() == wheel_surface


func _wheel_zoom(mb: InputEventMouseButton) -> void:
	# factor is the scroll amount: 1.0 for a classic notch, a fraction for smooth or
	# high-resolution wheels. Godot documents 0 as "not supported", so 0 is one notch.
	var amount := mb.factor if mb.factor > 0.0 else 1.0
	var step := wheel_zoom_step if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / wheel_zoom_step
	# Notches during an ease build on its target, so fast scrolling adds up.
	_zoom_target = clampf(zoom_goal().x * pow(step, amount), _min_zoom, _max_zoom)
	_zoom_anchor = mb.position
	_note_manual_input()
	get_viewport().set_input_as_handled()


func _zoom_by(factor: float, screen_pos: Vector2) -> void:
	_zoom_target = 0.0
	_set_zoom_about(clampf(zoom.x * factor, _min_zoom, _max_zoom), screen_pos)
	_note_manual_input()


func _step_zoom_ease(delta: float) -> void:
	var next := lerpf(zoom.x, _zoom_target, clampf(_ZOOM_EASE_SPEED * delta, 0.0, 1.0))
	if absf(next - _zoom_target) < 0.0005:
		next = _zoom_target
		_zoom_target = 0.0
	_set_zoom_about(next, _zoom_anchor)


# FREE with zoom_to_pointer: the world point under screen_pos stays under it. Otherwise the zoom
# is about the screen centre, so a locked target stays centred.
func _set_zoom_about(new_zoom: float, screen_pos: Vector2) -> void:
	var old_zoom := zoom.x
	zoom = Vector2(new_zoom, new_zoom)
	if zoom_to_pointer and mode == Mode.FREE:
		var from_centre := screen_pos - get_viewport_rect().size * 0.5
		position += from_centre / old_zoom - from_centre / new_zoom
	_clamp_to_bounds()


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	# Camera moves opposite to drag direction for "grab world" feel.
	var z := zoom.x
	if z <= 0.0:
		z = 1.0
	position -= (screen_delta * _PAN_SPEED) / z
	_note_manual_input()
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
