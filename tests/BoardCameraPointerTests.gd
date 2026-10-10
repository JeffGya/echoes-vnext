extends RefCounted
class_name BoardCameraPointerTests

# Real SanctumShell, real input through SubViewport.push_input: tap versus drag on the board.
# Fixture and snapshots come from BoardCameraInputTests.

const _BOARD_POINT := Vector2(640, 300)
# A header card of the Sanctum overview covers this point.
const _PANEL_POINT := Vector2(100, 200)


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("board_camera.pointer/mouse_drag_pans_one_to_one",             Callable(BoardCameraPointerTests, "_t_mouse_drag_pans_one_to_one"))
	runner.register_test("board_camera.pointer/drag_on_a_panel_does_not_pan",           Callable(BoardCameraPointerTests, "_t_drag_on_a_panel_does_not_pan"))
	runner.register_test("board_camera.pointer/press_on_a_button_starts_nothing",       Callable(BoardCameraPointerTests, "_t_press_on_a_button_starts_nothing"))
	runner.register_test("board_camera.pointer/tap_below_threshold_opens_detail",       Callable(BoardCameraPointerTests, "_t_tap_below_threshold_opens_detail"))
	runner.register_test("board_camera.pointer/drag_over_an_echo_is_not_a_tap",         Callable(BoardCameraPointerTests, "_t_drag_over_an_echo_is_not_a_tap"))
	runner.register_test("board_camera.pointer/touch_drag_pans_one_to_one",             Callable(BoardCameraPointerTests, "_t_touch_drag_pans_one_to_one"))
	runner.register_test("board_camera.pointer/two_fingers_are_a_pinch_not_pan_or_tap", Callable(BoardCameraPointerTests, "_t_two_fingers_are_a_pinch_not_pan_or_tap"))
	runner.register_test("board_camera.pointer/space_drag_pans_once",                   Callable(BoardCameraPointerTests, "_t_space_drag_pans_once"))
	runner.register_test("board_camera.pointer/emulated_touch_and_mouse_pan_once",      Callable(BoardCameraPointerTests, "_t_emulated_touch_and_mouse_pan_once"))
	runner.register_test("board_camera.pointer/detail_lock_ignores_drag_keeps_taps",    Callable(BoardCameraPointerTests, "_t_detail_lock_ignores_drag_keeps_taps"))
	runner.register_test("board_camera.pointer/sub_screen_press_starts_nothing",        Callable(BoardCameraPointerTests, "_t_sub_screen_press_starts_nothing"))
	runner.register_test("board_camera.pointer/leaving_sanctum_resets_stuck_drag",      Callable(BoardCameraPointerTests, "_t_leaving_sanctum_resets_stuck_drag"))
	runner.register_test("board_camera.pointer/snapshot_refresh_keeps_drag",            Callable(BoardCameraPointerTests, "_t_snapshot_refresh_keeps_drag"))
	runner.register_test("board_camera.pointer/focus_loss_resets_stuck_drag",           Callable(BoardCameraPointerTests, "_t_focus_loss_resets_stuck_drag"))
	runner.register_test("board_camera.pointer/hide_resets_stuck_drag",                 Callable(BoardCameraPointerTests, "_t_hide_resets_stuck_drag"))
	runner.register_test("board_camera.pointer/hidden_shell_takes_no_pointer_input",    Callable(BoardCameraPointerTests, "_t_hidden_shell_takes_no_pointer_input"))
	runner.register_test("board_camera.pointer/lost_touch_release_does_not_block_tap",  Callable(BoardCameraPointerTests, "_t_lost_touch_release_does_not_block_tap"))
	runner.register_test("board_camera.pointer/placement_pick_happens_on_release",      Callable(BoardCameraPointerTests, "_t_placement_pick_happens_on_release"))
	runner.register_test("board_camera.pointer/placement_drag_pans_and_picks_nothing",  Callable(BoardCameraPointerTests, "_t_placement_drag_pans_and_picks_nothing"))
	runner.register_test("board_camera.pointer/placement_cancel_works_after_board_taps", Callable(BoardCameraPointerTests, "_t_placement_cancel_works_after_board_taps"))
	runner.register_test("board_camera.pointer/panel_kinds_stop_a_pan",                 Callable(BoardCameraPointerTests, "_t_panel_kinds_stop_a_pan"))
	runner.register_test("board_camera.pointer/clipped_button_does_not_block_open_board", Callable(BoardCameraPointerTests, "_t_clipped_button_does_not_block_open_board"))


# -------------------------
# Helpers
# -------------------------

static func _fixture(echo_ids: Array = ["echo_a", "echo_b"]) -> Dictionary:
	var fx := BoardCameraInputTests._make_fixture()
	if fx.is_empty():
		return {}
	var shell := fx["shell"] as SanctumShell
	shell.set_snapshot(BoardCameraInputTests._echo_occupant_snapshot(2, echo_ids))
	SanctumLayoutTests._force_control_layout(shell)
	fx["pointer"] = shell.get("_pointer")
	return fx


static func _press(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.pressed = pressed
	vp.push_input(ev, true)


static func _move(vp: SubViewport, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(ev, true)


static func _touch(vp: SubViewport, index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	vp.push_input(ev, true)


static func _touch_drag(vp: SubViewport, index: int, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = relative
	vp.push_input(ev, true)


static func _echo_point(fx: Dictionary, echo_id: String) -> Vector2:
	return BoardCameraInputTests._viewport_point_for_occupant(fx["shell"] as SanctumShell, echo_id)


static func _classify(fx: Dictionary, point: Vector2) -> int:
	return int((fx["shell"] as SanctumShell).call("_classify_press", point))


static func _detail_open(fx: Dictionary) -> bool:
	return bool((fx["shell"] as SanctumShell).get("_echo_detail_open"))


static func _fail(vp: SubViewport, msg: String) -> Dictionary:
	vp.free()
	return { "ok": false, "error": msg }


static func _no_fixture() -> Dictionary:
	return { "ok": false, "error": "Ready fixture host unavailable" }


# -------------------------
# Tests
# -------------------------

static func _t_mouse_drag_pans_one_to_one() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	if _classify(fx, _BOARD_POINT) != 0:
		return _fail(vp, "Test point is not open board; premise failed")
	var before := cam.position
	_press(vp, _BOARD_POINT, true)
	_move(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	_move(vp, _BOARD_POINT + Vector2(30, 10), Vector2(10, 10))
	_press(vp, _BOARD_POINT + Vector2(30, 10), false)
	var got := cam.position - before
	var want := -Vector2(30, 10) / cam.zoom.x
	var open := _detail_open(fx)
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "Plain drag moved the camera %s, want 1:1 %s" % [got, want] }
	if open:
		return { "ok": false, "error": "A drag opened the echo detail" }
	return { "ok": true }


static func _t_drag_on_a_panel_does_not_pan() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	if _classify(fx, _PANEL_POINT) != 1:
		return _fail(vp, "Test point is not on a panel; premise failed")
	var before := cam.position
	_press(vp, _PANEL_POINT, true)
	_move(vp, _PANEL_POINT + Vector2(40, 0), Vector2(40, 0))
	_move(vp, _PANEL_POINT + Vector2(80, 0), Vector2(40, 0))
	_press(vp, _PANEL_POINT + Vector2(80, 0), false)
	var moved := cam.position != before
	vp.free()
	if moved:
		return { "ok": false, "error": "A drag that started on a panel panned the board" }
	return { "ok": true }


static func _t_press_on_a_button_starts_nothing() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var tracker := fx["pointer"] as BoardPointerTracker
	var button := shell.get_node_or_null("%SummonButton") as Button
	if button == null or not button.is_visible_in_tree():
		return _fail(vp, "Rail button hidden; premise failed")
	var point := button.get_global_rect().get_center()
	var before := cam.position
	_press(vp, point, true)
	var started := tracker.is_pointer_down()
	_move(vp, point + Vector2(40, 0), Vector2(40, 0))
	_press(vp, point + Vector2(40, 0), false)
	var moved := cam.position != before
	vp.free()
	if started:
		return { "ok": false, "error": "A press on a rail button started a gesture" }
	if moved:
		return { "ok": false, "error": "A drag from a rail button panned the board" }
	return { "ok": true }


static func _t_tap_below_threshold_opens_detail() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var point := _echo_point(fx, "echo_a")
	_press(vp, point, true)
	_move(vp, point + Vector2(5, 0), Vector2(5, 0))
	_press(vp, point + Vector2(5, 0), false)
	var open := _detail_open(fx)
	var featured := str((fx["shell"] as SanctumShell).get("_featured_echo_id"))
	vp.free()
	if not open or featured != "echo_a":
		return { "ok": false, "error": "A tap with 5 px of movement did not open the detail (open=%s, featured=%s)" % [open, featured] }
	return { "ok": true }


static func _t_drag_over_an_echo_is_not_a_tap() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var point := _echo_point(fx, "echo_a")
	_press(vp, point, true)
	_move(vp, point + Vector2(20, 0), Vector2(20, 0))
	_press(vp, point + Vector2(20, 0), false)
	var open := _detail_open(fx)
	vp.free()
	if open:
		return { "ok": false, "error": "A drag of 20 px opened the echo detail" }
	return { "ok": true }


static func _t_touch_drag_pans_one_to_one() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var before := cam.position
	_touch(vp, 0, _BOARD_POINT, true)
	_touch_drag(vp, 0, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	_touch_drag(vp, 0, _BOARD_POINT + Vector2(30, 10), Vector2(10, 10))
	_touch(vp, 0, _BOARD_POINT + Vector2(30, 10), false)
	var got := cam.position - before
	var want := -Vector2(30, 10) / cam.zoom.x
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "One-finger drag moved the camera %s, want 1:1 %s" % [got, want] }
	return { "ok": true }


static func _t_two_fingers_are_a_pinch_not_pan_or_tap() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _echo_point(fx, "echo_a")
	var other := _BOARD_POINT + Vector2(120, 0)
	var before := cam.position
	_touch(vp, 0, point, true)
	_touch(vp, 1, other, true)
	_touch_drag(vp, 0, point + Vector2(30, 0), Vector2(30, 0))
	_touch_drag(vp, 1, other + Vector2(30, 0), Vector2(30, 0))
	_touch(vp, 0, point + Vector2(30, 0), false)
	_touch(vp, 1, other + Vector2(30, 0), false)
	var moved := cam.position != before
	var open := _detail_open(fx)
	vp.free()
	if moved:
		return { "ok": false, "error": "A two-finger gesture panned the board" }
	if open:
		return { "ok": false, "error": "A two-finger gesture counted as a tap" }
	return { "ok": true }


# Space+drag belongs to the camera. The tracker must not add a second pan on top of it.
static func _t_space_drag_pans_once() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	BoardCameraInputTests._set_space_held(true)
	if not Input.is_key_pressed(KEY_SPACE):
		BoardCameraInputTests._set_space_held(false)
		return _fail(vp, "Could not hold Space; premise failed")
	var before := cam.position
	_press(vp, _BOARD_POINT, true)
	_move(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	_press(vp, _BOARD_POINT + Vector2(20, 0), false)
	var got := cam.position - before
	var want := -Vector2(20, 0) / cam.zoom.x
	var echo_point := _echo_point(fx, "echo_a")
	_press(vp, echo_point, true)
	_press(vp, echo_point, false)
	BoardCameraInputTests._set_space_held(false)
	var open := _detail_open(fx)
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "Space+drag moved the camera %s, want exactly once 1:1 %s" % [got, want] }
	if open:
		return { "ok": false, "error": "Space+click on an echo opened the detail" }
	return { "ok": true }


# project.godot emulates touch from the mouse: the engine sends touch 0 first, then the mouse event.
static func _t_emulated_touch_and_mouse_pan_once() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var before := cam.position
	_touch(vp, 0, _BOARD_POINT, true)
	_press(vp, _BOARD_POINT, true)
	_touch_drag(vp, 0, _BOARD_POINT + Vector2(30, 0), Vector2(30, 0))
	_move(vp, _BOARD_POINT + Vector2(30, 0), Vector2(30, 0))
	_touch(vp, 0, _BOARD_POINT + Vector2(30, 0), false)
	_press(vp, _BOARD_POINT + Vector2(30, 0), false)
	var got := cam.position - before
	var want := -Vector2(30, 0) / cam.zoom.x
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "Emulated mouse drag moved the camera %s, want once 1:1 %s" % [got, want] }
	return { "ok": true }


# The detail view locks the camera, so a drag pans nothing. Taps still switch echoes and close it.
static func _t_detail_lock_ignores_drag_keeps_taps() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var shell := fx["shell"] as SanctumShell
	var point_a := _echo_point(fx, "echo_a")
	_press(vp, point_a, true)
	_press(vp, point_a, false)
	if not _detail_open(fx):
		return _fail(vp, "Tap did not open the detail; premise failed")
	var locked := cam.position
	_press(vp, _BOARD_POINT, true)
	_move(vp, _BOARD_POINT + Vector2(40, 0), Vector2(40, 0))
	_press(vp, _BOARD_POINT + Vector2(40, 0), false)
	var errors: Array = []
	if cam.position != locked:
		errors.append("a drag moved the locked camera")
	if not _detail_open(fx):
		errors.append("a drag closed the detail")
	cam.position = Vector2(300, -200)
	var point_b := _echo_point(fx, "echo_b")
	_press(vp, point_b, true)
	_press(vp, point_b, false)
	if str(shell.get("_featured_echo_id")) != "echo_b":
		errors.append("a tap on another echo did not switch the detail")
	var empty_point := Vector2(4, 4)
	_press(vp, empty_point, true)
	_press(vp, empty_point, false)
	if _detail_open(fx):
		errors.append("a tap on empty board did not close the detail")
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_sub_screen_press_starts_nothing() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var tracker := fx["pointer"] as BoardPointerTracker
	shell.set_snapshot({ "type": "flow.summon", "meta": { "t": 3 }, "data": {}, "actions": {} })
	SanctumLayoutTests._force_control_layout(shell)
	var before := cam.position
	_press(vp, _BOARD_POINT, true)
	var started := tracker.is_pointer_down()
	_move(vp, _BOARD_POINT + Vector2(40, 0), Vector2(40, 0))
	_press(vp, _BOARD_POINT + Vector2(40, 0), false)
	var moved := cam.position != before
	vp.free()
	if started:
		return { "ok": false, "error": "A press on a sub-screen started a board gesture" }
	if moved:
		return { "ok": false, "error": "A drag on a sub-screen panned the board" }
	return { "ok": true }


static func _t_leaving_sanctum_resets_stuck_drag() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var tracker := fx["pointer"] as BoardPointerTracker
	_press(vp, _BOARD_POINT, true)
	if not tracker.is_pointer_down():
		return _fail(vp, "Press did not start a gesture; premise failed")
	shell.set_snapshot({ "type": "flow.summon", "meta": { "t": 3 }, "data": {}, "actions": {} })
	var down := tracker.is_pointer_down()
	vp.free()
	if down:
		return { "ok": false, "error": "Leaving flow.sanctum left a gesture owned" }
	return { "ok": true }


# Sanctum snapshots arrive every second or two. A refresh must not cut a drag in progress.
static func _t_snapshot_refresh_keeps_drag() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	_press(vp, _BOARD_POINT, true)
	_move(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	shell.set_snapshot(BoardCameraInputTests._echo_occupant_snapshot(3, ["echo_a", "echo_b"]))
	var before := cam.position
	_move(vp, _BOARD_POINT + Vector2(60, 0), Vector2(40, 0))
	var got := cam.position - before
	var want := -Vector2(40, 0) / cam.zoom.x
	_press(vp, _BOARD_POINT + Vector2(60, 0), false)
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "Drag after a snapshot refresh moved %s, want %s" % [got, want] }
	return { "ok": true }


static func _t_focus_loss_resets_stuck_drag() -> Dictionary:
	var errors: Array = []
	for what in [MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		var fx := _fixture()
		if fx.is_empty():
			return _no_fixture()
		var vp := fx["viewport"] as SubViewport
		var shell := fx["shell"] as SanctumShell
		var tracker := fx["pointer"] as BoardPointerTracker
		_touch(vp, 0, _BOARD_POINT, true)
		_touch(vp, 1, _BOARD_POINT + Vector2(50, 0), true)
		shell.notification(what)
		if tracker.is_pointer_down() or tracker.finger_count() != 0:
			errors.append("notification %d left state behind" % what)
		vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_hide_resets_stuck_drag() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var tracker := fx["pointer"] as BoardPointerTracker
	_touch(vp, 0, _BOARD_POINT, true)
	_touch(vp, 1, _BOARD_POINT + Vector2(50, 0), true)
	shell.visible = false
	var left := tracker.is_pointer_down() or tracker.finger_count() != 0
	vp.free()
	if left:
		return { "ok": false, "error": "Hiding the shell left a gesture or fingers behind" }
	return { "ok": true }


static func _t_hidden_shell_takes_no_pointer_input() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var tracker := fx["pointer"] as BoardPointerTracker
	var point := _echo_point(fx, "echo_a")
	shell.visible = false
	var before := cam.position
	_press(vp, point, true)
	_press(vp, point, false)
	var open := _detail_open(fx)
	_press(vp, _BOARD_POINT, true)
	var started := tracker.is_pointer_down()
	_move(vp, _BOARD_POINT + Vector2(40, 0), Vector2(40, 0))
	_press(vp, _BOARD_POINT + Vector2(40, 0), false)
	_touch(vp, 0, _BOARD_POINT, true)
	var counted := tracker.finger_count() != 0
	var moved := cam.position != before
	vp.free()
	if open or started or moved or counted:
		return { "ok": false, "error": "Hidden shell reacted to pointer input (detail=%s, gesture=%s, moved=%s, finger=%s)" % [open, started, moved, counted] }
	return { "ok": true }


# A pinch ends with one release lost. A later single tap on an echo must still open its detail.
static func _t_lost_touch_release_does_not_block_tap() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var tracker := fx["pointer"] as BoardPointerTracker
	_touch(vp, 0, _BOARD_POINT, true)
	_touch(vp, 1, _BOARD_POINT + Vector2(50, 0), true)
	_touch(vp, 0, _BOARD_POINT, false)
	var stuck := tracker.finger_count()
	var point := _echo_point(fx, "echo_a")
	_touch(vp, 0, point, true)
	_touch(vp, 0, point, false)
	var open := _detail_open(fx)
	vp.free()
	if stuck != 1:
		return { "ok": false, "error": "Expected one stuck finger before the tap, got %d; premise failed" % stuck }
	if not open:
		return { "ok": false, "error": "A tap after a lost release did not open the detail" }
	return { "ok": true }


# Each kind of surface that covers the board stops a drag that starts on it.
static func _t_panel_kinds_stop_a_pan() -> Dictionary:
	var errors: Array = []
	for kind in ["ScrollContainer", "PanelContainer", "Panel", "ColorRect"]:
		var fx := _fixture()
		if fx.is_empty():
			return _no_fixture()
		var vp := fx["viewport"] as SubViewport
		var chrome := (fx["shell"] as SanctumShell).get_node("UILayer/Control") as Control
		if _classify(fx, _BOARD_POINT) != 0:
			return _fail(vp, "Test point is not open board; premise failed")
		var surface := ClassDB.instantiate(kind) as Control
		surface.position = _BOARD_POINT - Vector2(50, 50)
		surface.size = Vector2(100, 100)
		chrome.add_child(surface)
		if _classify(fx, _BOARD_POINT) != 1:
			errors.append("%s over the board did not count as a panel" % kind)
		vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# A button scrolled out of a clipping parent is not under the pointer, even if its rectangle is.
static func _t_clipped_button_does_not_block_open_board() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var chrome := (fx["shell"] as SanctumShell).get_node("UILayer/Control") as Control
	if _classify(fx, _BOARD_POINT) != 0:
		return _fail(vp, "Test point is not open board; premise failed")
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2.ZERO
	clip.size = Vector2(100, 100)
	var button := Button.new()
	button.position = _BOARD_POINT - Vector2(40, 20)
	button.size = Vector2(80, 40)
	clip.add_child(button)
	chrome.add_child(clip)
	var hit := _classify(fx, _BOARD_POINT)
	vp.free()
	if hit != 0:
		return { "ok": false, "error": "A clipped-out button blocked a press on open board (classified %d)" % hit }
	return { "ok": true }


# Counts cell picks the shell reports to its overlay.
class PickSpy extends Control:
	var picks := 0
	func on_placement_cell_selected(_cell: Vector2i, _is_valid: bool, _reason: String) -> void:
		picks += 1


static func _enter_placement(fx: Dictionary) -> void:
	var floor_cells: Array = []
	var occupied: Array = []
	for tile_v in SanctumLayoutService.make_starter_layout().get("tiles", []):
		var tile: Dictionary = tile_v
		var cell := Vector2i(int(tile["x"]), int(tile["y"]))
		if str(tile.get("kind", "")) == "floor":
			floor_cells.append(cell)
		else:
			occupied.append(cell)
	(fx["shell"] as SanctumShell).call("_on_overlay_action_requested", { "type": "ui.enter_placement_mode", "payload": {
		"institution_id": "inst_test", "valid_cells": [], "floor_cells": floor_cells, "occupied_cells": occupied } })
	SanctumLayoutTests._force_control_layout(fx["shell"] as SanctumShell)


# The shell reports picks to _active_overlay. A spy takes its place so each pick can be counted.
static func _spy_on_picks(fx: Dictionary) -> PickSpy:
	var spy := PickSpy.new()
	(fx["shell"] as SanctumShell).add_child(spy)
	(fx["shell"] as SanctumShell).set("_active_overlay", spy)
	return spy


static func _t_placement_pick_happens_on_release() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	_enter_placement(fx)
	var spy := _spy_on_picks(fx)
	if _classify(fx, _BOARD_POINT) == 2:
		return _fail(vp, "Test point is covered by a control; premise failed")
	_press(vp, _BOARD_POINT, true)
	var after_press := spy.picks
	_press(vp, _BOARD_POINT, false)
	var after_release := spy.picks
	_press(vp, _BOARD_POINT, true)
	_press(vp, _BOARD_POINT, false)
	var after_second := spy.picks
	vp.free()
	if after_press != 0:
		return { "ok": false, "error": "A placement pick fired on the press (%d)" % after_press }
	if after_release != 1:
		return { "ok": false, "error": "One tap gave %d picks, want 1" % after_release }
	if after_second != 2:
		return { "ok": false, "error": "Two taps gave %d picks, want 2" % after_second }
	return { "ok": true }


static func _t_placement_drag_pans_and_picks_nothing() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	_enter_placement(fx)
	var spy := _spy_on_picks(fx)
	if _classify(fx, _BOARD_POINT) != 0:
		return _fail(vp, "Test point is not open board in placement mode; premise failed")
	var before := cam.position
	_press(vp, _BOARD_POINT, true)
	_move(vp, _BOARD_POINT + Vector2(30, 0), Vector2(30, 0))
	_press(vp, _BOARD_POINT + Vector2(30, 0), false)
	var got := cam.position - before
	var want := -Vector2(30, 0) / cam.zoom.x
	var picks := spy.picks
	vp.free()
	if not got.is_equal_approx(want):
		return { "ok": false, "error": "A 30 px drag in placement mode moved the camera %s, want %s" % [got, want] }
	if picks != 0:
		return { "ok": false, "error": "A drag in placement mode picked a cell (%d picks)" % picks }
	return { "ok": true }


static func _t_placement_cancel_works_after_board_taps() -> Dictionary:
	var fx := _fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	_enter_placement(fx)
	if not bool(shell.get("_placement_mode")):
		return _fail(vp, "Placement mode did not start; premise failed")
	var label := shell.find_child("PlacementLabel", true, false) as Label
	var cancel := shell.find_child("PlacementCancelBtn", true, false) as Button
	if label == null or cancel == null or not cancel.is_visible_in_tree():
		return _fail(vp, "Placement bar is not visible; premise failed")
	var label_before := label.text
	for i in range(2):
		_press(vp, _BOARD_POINT, true)
		_press(vp, _BOARD_POINT, false)
	var picked := label.text != label_before
	if not bool(shell.get("_placement_mode")):
		return _fail(vp, "Board taps ended placement mode; premise failed")
	var point := cancel.get_global_rect().get_center()
	_press(vp, point, true)
	_press(vp, point, false)
	var still := bool(shell.get("_placement_mode"))
	vp.free()
	if not picked:
		return { "ok": false, "error": "Board taps did not change the placement label; premise failed" }
	if still:
		return { "ok": false, "error": "Cancel did not end placement mode after board taps" }
	return { "ok": true }
