class_name BoardPointerTracker
extends RefCounted

# Tells a board tap from a one-pointer drag from a pinch. The owning screen forwards events and
# decides what a tap means and how the camera moves. No screen knowledge lives here.
#
# Wiring:
#   _input(event)      -> tracker.note_touch(event)       counts every finger, never consumes
#   _gui_input(event)  -> if tracker.handle_event(event): accept_event()

## A release that never became a drag, with one finger and no Space. Position is in the
## coordinates of the event that ended it.
signal tap(position: Vector2)
## One pointer moved past the threshold. 1:1 screen delta, ready for BoardCameraController.drag_pan.
signal drag_pan(screen_delta: Vector2)

const DRAG_THRESHOLD: float = 8.0
const MOUSE_POINTER := "mouse"

## Test seam. Set to a Callable returning bool to replace the global Input Space check.
var space_held_fn: Callable = Callable()

var _pointer_down: bool    = false
var _drag_active: bool     = false
var _last_pos: Vector2     = Vector2.ZERO
# project.godot enables emulate_touch_from_mouse: one mouse drag also sends a touch0 twin. Only
# the pointer that owns the gesture moves it, or the delta would apply twice.
var _owner: String         = ""
# Every finger down anywhere in the viewport. A finger on a button never reaches _gui_input of
# the screen root, but it still makes a pinch.
var _touches_down: Dictionary = {}
var _not_tap: bool         = false


static func touch_pointer(index: int) -> String:
	return "touch%d" % index


## Clears fingers, ownership and drag state. Call on focus loss, hide and a new encounter.
func reset() -> void:
	_touches_down.clear()
	_pointer_down = false
	_drag_active  = false
	_owner        = ""
	_not_tap      = false


func is_drag_active() -> bool:
	return _drag_active


func is_pointer_down() -> bool:
	return _pointer_down


func finger_count() -> int:
	return _touches_down.size()


## Finger counting. Call from _input, before the GUI pass. Ignores every other event type.
func note_touch(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var st := event as InputEventScreenTouch
	if st.pressed:
		# Index 0 starts a new gesture, so anything still recorded is from a release that never
		# arrived. Cost: if finger 0 lifts and lands again while another stays down, that other
		# finger is forgotten.
		if st.index == 0:
			reset()
		_touches_down[st.index] = true
		if _pointer_down and _touches_down.size() > 1:
			_not_tap = true
	else:
		_touches_down.erase(st.index)


## Pointer events. Call from _gui_input. Returns true when the screen should accept_event():
## the owner's release, or owner motion once the drag is active.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			_begin(mb.position, MOUSE_POINTER)
			return false
		return _end(mb.position, MOUSE_POINTER)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin(st.position, touch_pointer(st.index))
			return false
		return _end(st.position, touch_pointer(st.index))
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pointer_down and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update(mm.position, MOUSE_POINTER)
			return _drag_active and _owner == MOUSE_POINTER
		return false
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _pointer_down:
			_update(sd.position, touch_pointer(sd.index))
			return _drag_active and _owner == touch_pointer(sd.index)
	return false


# The first pointer down owns the gesture. A press from the owner re-seeds, so a lost release
# cannot leave the board stuck. Its emulated twin and any other pointer are ignored.
# Space+click is a pan gesture, never a tap.
func _begin(pos: Vector2, source: String) -> void:
	if _pointer_down and _owner != source:
		return
	_owner        = source
	_pointer_down = true
	_drag_active  = false
	_not_tap      = _touches_down.size() > 1 or _space_is_down()
	_last_pos     = pos


# While a second finger is down the origin still tracks the owner so the pan does not jump.
func _update(pos: Vector2, source: String) -> void:
	if not _pointer_down or _owner != source:
		return
	if _touches_down.size() > 1:
		_last_pos = pos
		return
	if not _drag_active:
		if _last_pos.distance_to(pos) < DRAG_THRESHOLD:
			return
		_drag_active = true
	var delta: Vector2 = pos - _last_pos
	_last_pos = pos
	drag_pan.emit(delta)


func _end(pos: Vector2, source: String) -> bool:
	if not _pointer_down or _owner != source:
		return false
	var was_tap := not _drag_active and not _not_tap
	_pointer_down = false
	_drag_active  = false
	_owner        = ""
	_not_tap      = false
	if was_tap:
		tap.emit(pos)
	return true


func _space_is_down() -> bool:
	if space_held_fn.is_valid():
		return bool(space_held_fn.call())
	return Input.is_key_pressed(KEY_SPACE)
