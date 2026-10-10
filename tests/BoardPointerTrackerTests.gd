extends RefCounted
class_name BoardPointerTrackerTests

# Plain InputEvent objects fed straight to BoardPointerTracker. No scene, no viewport.


# Records what the tracker reports.
class Recorder extends RefCounted:
	var taps: Array[Vector2] = []
	var pans: Array[Vector2] = []
	func on_tap(pos: Vector2) -> void:
		taps.append(pos)
	func on_pan(delta: Vector2) -> void:
		pans.append(delta)


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("board_pointer/tap_below_threshold_fires_once",          Callable(BoardPointerTrackerTests, "_t_tap_below_threshold_fires_once"))
	runner.register_test("board_pointer/drag_above_threshold_pans_one_to_one",    Callable(BoardPointerTrackerTests, "_t_drag_above_threshold_pans_one_to_one"))
	runner.register_test("board_pointer/second_finger_cancels_tap",               Callable(BoardPointerTrackerTests, "_t_second_finger_cancels_tap"))
	runner.register_test("board_pointer/second_finger_cancels_drag_without_jump", Callable(BoardPointerTrackerTests, "_t_second_finger_cancels_drag_without_jump"))
	runner.register_test("board_pointer/space_press_is_drag_not_tap",             Callable(BoardPointerTrackerTests, "_t_space_press_is_drag_not_tap"))
	runner.register_test("board_pointer/mouse_cannot_continue_touch_drag",        Callable(BoardPointerTrackerTests, "_t_mouse_cannot_continue_touch_drag"))
	runner.register_test("board_pointer/reset_clears_everything",                 Callable(BoardPointerTrackerTests, "_t_reset_clears_everything"))
	runner.register_test("board_pointer/finger_zero_press_clears_stale_state",    Callable(BoardPointerTrackerTests, "_t_finger_zero_press_clears_stale_state"))
	runner.register_test("board_pointer/emulated_touch_before_mouse_one_tap",     Callable(BoardPointerTrackerTests, "_t_emulated_touch_before_mouse_one_tap"))
	runner.register_test("board_pointer/emulated_touch_before_mouse_one_drag",    Callable(BoardPointerTrackerTests, "_t_emulated_touch_before_mouse_one_drag"))
	runner.register_test("board_pointer/other_buttons_and_idle_motion_ignored",   Callable(BoardPointerTrackerTests, "_t_other_buttons_and_idle_motion_ignored"))
	runner.register_test("board_pointer/threshold_boundary_below_is_tap_exact_is_drag", Callable(BoardPointerTrackerTests, "_t_threshold_boundary_below_is_tap_exact_is_drag"))
	runner.register_test("board_pointer/handled_flag_marks_owner_release_and_drag", Callable(BoardPointerTrackerTests, "_t_handled_flag_marks_owner_release_and_drag"))


# -------------------------
# Helpers
# -------------------------

static func _make() -> Dictionary:
	var tracker := BoardPointerTracker.new()
	var rec := Recorder.new()
	tracker.tap.connect(rec.on_tap)
	tracker.drag_pan.connect(rec.on_pan)
	tracker.space_held_fn = func() -> bool: return false
	return { "t": tracker, "r": rec }


static func _mouse_button(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.button_index = button
	ev.pressed = pressed
	return ev


static func _mouse_move(pos: Vector2, held := true) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	return ev


static func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	return ev


static func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	return ev


# One event as the screen sees it: _input first, then _gui_input. Returns the handled flag.
static func _feed(t: BoardPointerTracker, ev: InputEvent) -> bool:
	t.note_touch(ev)
	return t.handle_event(ev)


static func _fail(msg: String) -> Dictionary:
	return { "ok": false, "error": msg }


# -------------------------
# Tests
# -------------------------

static func _t_tap_below_threshold_fires_once() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(104, 103)))
	_feed(t, _mouse_button(Vector2(104, 103), false))
	if r.taps.size() != 1:
		return _fail("expected 1 tap, got %d" % r.taps.size())
	if r.taps[0] != Vector2(104, 103):
		return _fail("tap position wrong: %s" % r.taps[0])
	if not r.pans.is_empty():
		return _fail("a sub-threshold move must not pan")
	return { "ok": true }


static func _t_drag_above_threshold_pans_one_to_one() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(120, 100)))
	_feed(t, _mouse_move(Vector2(130, 110)))
	_feed(t, _mouse_button(Vector2(130, 110), false))
	if r.pans.size() != 2:
		return _fail("expected 2 pans, got %d" % r.pans.size())
	if r.pans[0] != Vector2(20, 0) or r.pans[1] != Vector2(10, 10):
		return _fail("pan deltas not 1:1: %s" % [r.pans])
	if not r.taps.is_empty():
		return _fail("a drag must not tap")
	return { "ok": true }


static func _t_second_finger_cancels_tap() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _touch(1, Vector2(300, 100), true))
	_feed(t, _touch(1, Vector2(300, 100), false))
	_feed(t, _touch(0, Vector2(100, 100), false))
	if not r.taps.is_empty():
		return _fail("a second finger must cancel the tap")
	# A fresh single tap works afterwards.
	_feed(t, _touch(0, Vector2(50, 50), true))
	_feed(t, _touch(0, Vector2(50, 50), false))
	if r.taps.size() != 1:
		return _fail("tap after the pinch should fire once, got %d" % r.taps.size())
	return { "ok": true }


static func _t_second_finger_cancels_drag_without_jump() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _drag(0, Vector2(120, 100)))
	if r.pans.size() != 1:
		return _fail("drag should pan before the second finger")
	# Second finger lands on a button: only note_touch sees it.
	t.note_touch(_touch(1, Vector2(400, 400), true))
	_feed(t, _drag(0, Vector2(160, 100)))
	_feed(t, _drag(0, Vector2(170, 100)))
	if r.pans.size() != 1:
		return _fail("no pan while two fingers are down, got %d" % r.pans.size())
	t.note_touch(_touch(1, Vector2(400, 400), false))
	_feed(t, _drag(0, Vector2(175, 100)))
	if r.pans.size() != 2 or r.pans[1] != Vector2(5, 0):
		return _fail("pan after the pinch must start from the tracked origin: %s" % [r.pans])
	_feed(t, _touch(0, Vector2(175, 100), false))
	if not r.taps.is_empty():
		return _fail("no tap after a drag")
	return { "ok": true }


static func _t_space_press_is_drag_not_tap() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	t.space_held_fn = func() -> bool: return true
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_button(Vector2(100, 100), false))
	if not r.taps.is_empty():
		return _fail("Space+click must not tap")
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(130, 100)))
	_feed(t, _mouse_button(Vector2(130, 100), false))
	if r.pans.size() != 1 or not r.taps.is_empty():
		return _fail("Space+drag must pan and not tap")
	t.space_held_fn = func() -> bool: return false
	_feed(t, _mouse_button(Vector2(10, 10), true))
	_feed(t, _mouse_button(Vector2(10, 10), false))
	if r.taps.size() != 1:
		return _fail("tap without Space should fire")
	return { "ok": true }


static func _t_mouse_cannot_continue_touch_drag() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(200, 100)))
	if not r.pans.is_empty():
		return _fail("a mouse move must not pan a touch-owned drag")
	_feed(t, _drag(0, Vector2(130, 100)))
	if r.pans.size() != 1 or r.pans[0] != Vector2(30, 0):
		return _fail("the owning touch must still pan: %s" % [r.pans])
	if _feed(t, _mouse_button(Vector2(200, 100), false)):
		return _fail("a mouse release must not end a touch-owned drag")
	if not t.is_pointer_down():
		return _fail("touch drag must still be live after a foreign mouse release")
	return { "ok": true }


static func _t_reset_clears_everything() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _touch(1, Vector2(200, 100), true))
	_feed(t, _drag(0, Vector2(150, 100)))
	t.reset()
	if t.finger_count() != 0 or t.is_pointer_down() or t.is_drag_active():
		return _fail("reset left state behind")
	if _feed(t, _touch(0, Vector2(150, 100), false)):
		return _fail("a release after reset must not be owned")
	if not r.taps.is_empty():
		return _fail("reset must not fire a tap")
	# Board works again.
	_feed(t, _mouse_button(Vector2(5, 5), true))
	_feed(t, _mouse_button(Vector2(5, 5), false))
	if r.taps.size() != 1:
		return _fail("tap after reset should fire")
	return { "ok": true }


static func _t_finger_zero_press_clears_stale_state() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	# Two fingers land. Neither release ever arrives.
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _touch(1, Vector2(200, 100), true))
	if t.finger_count() != 2:
		return _fail("setup: two fingers expected")
	_feed(t, _touch(0, Vector2(50, 50), true))
	if t.finger_count() != 1:
		return _fail("finger 0 press must clear stale fingers, count is %d" % t.finger_count())
	_feed(t, _touch(0, Vector2(50, 50), false))
	if r.taps.size() != 1:
		return _fail("tap after a lost release should fire once, got %d" % r.taps.size())
	return { "ok": true }


static func _t_emulated_touch_before_mouse_one_tap() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	# emulate_touch_from_mouse: the engine sends touch idx0 BEFORE the mouse event.
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _touch(0, Vector2(100, 100), false))
	_feed(t, _mouse_button(Vector2(100, 100), false))
	if r.taps.size() != 1:
		return _fail("expected exactly 1 tap, got %d" % r.taps.size())
	if t.is_pointer_down() or t.finger_count() != 0:
		return _fail("state not clean after the click")
	return { "ok": true }


static func _t_emulated_touch_before_mouse_one_drag() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _touch(0, Vector2(100, 100), true))
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _drag(0, Vector2(130, 100)))
	_feed(t, _mouse_move(Vector2(130, 100)))
	_feed(t, _drag(0, Vector2(150, 100)))
	_feed(t, _mouse_move(Vector2(150, 100)))
	_feed(t, _touch(0, Vector2(150, 100), false))
	_feed(t, _mouse_button(Vector2(150, 100), false))
	if r.pans.size() != 2 or r.pans[0] != Vector2(30, 0) or r.pans[1] != Vector2(20, 0):
		return _fail("expected one pan stream of 30 then 20: %s" % [r.pans])
	if not r.taps.is_empty():
		return _fail("a drag must not tap")
	return { "ok": true }


static func _t_other_buttons_and_idle_motion_ignored() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _mouse_button(Vector2(100, 100), true, MOUSE_BUTTON_RIGHT))
	if t.is_pointer_down():
		return _fail("right button must not start a gesture")
	_feed(t, _mouse_move(Vector2(200, 100), false))
	_feed(t, _drag(0, Vector2(300, 100)))
	_feed(t, _mouse_button(Vector2(100, 100), false, MOUSE_BUTTON_RIGHT))
	if not r.taps.is_empty() or not r.pans.is_empty():
		return _fail("ignored events must report nothing")
	# Held-button check: motion with no left mask does not pan a live mouse gesture.
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(160, 100), false))
	if not r.pans.is_empty():
		return _fail("motion without the left button must not pan")
	return { "ok": true }


static func _t_handled_flag_marks_owner_release_and_drag() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	if _feed(t, _mouse_button(Vector2(100, 100), true)):
		return _fail("a press must not be handled")
	if _feed(t, _mouse_move(Vector2(103, 100))):
		return _fail("motion below the threshold must not be handled")
	if not _feed(t, _mouse_move(Vector2(130, 100))):
		return _fail("motion past the threshold must be handled")
	if not _feed(t, _mouse_button(Vector2(130, 100), false)):
		return _fail("the owner release must be handled")
	if _feed(t, _mouse_button(Vector2(130, 100), false)):
		return _fail("a release with no owner must not be handled")
	return { "ok": true }


# Rule pinned: a motion that ends below 8 px from the origin is not a drag, so the release is a tap.
# A motion that ends exactly 8 px away is a drag. Combat's old code returned only when
# `_drag_last_pos.distance_to(pos) < _DRAG_THRESHOLD` (CombatBoardScreen.gd, `_update_pointer_drag`).
static func _t_threshold_boundary_below_is_tap_exact_is_drag() -> Dictionary:
	var f := _make()
	var t := f["t"] as BoardPointerTracker
	var r := f["r"] as Recorder
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(107.99, 100)))
	_feed(t, _mouse_button(Vector2(107.99, 100), false))
	if r.taps.size() != 1 or not r.pans.is_empty():
		return _fail("7.99 px must be a tap with no pan (taps %d, pans %d)" % [r.taps.size(), r.pans.size()])
	_feed(t, _mouse_button(Vector2(100, 100), true))
	_feed(t, _mouse_move(Vector2(108, 100)))
	_feed(t, _mouse_button(Vector2(108, 100), false))
	if r.taps.size() != 1:
		return _fail("exactly 8 px must not be a tap")
	if r.pans.size() != 1 or r.pans[0] != Vector2(8, 0):
		return _fail("exactly 8 px must pan once by 8: %s" % [r.pans])
	return { "ok": true }
