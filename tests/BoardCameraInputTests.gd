extends RefCounted
class_name BoardCameraInputTests

# Input-routing tests for BoardCameraController inside the real SanctumShell scene.
# Events go through SubViewport.push_input(), so Godot's own _input -> GUI -> _unhandled_input
# order decides the result, not a direct call into the camera.

const SanctumShellScene := preload("res://ui/shells/SanctumShell.tscn")

const _BOARD_POINT := Vector2(640, 300)
const _LAYOUT := { "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1280, 720) }


# Records mouse buttons that survive the GUI pass.
class UnhandledMouseSentinel extends Node:
	var presses := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			presses += 1


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("board_camera.input/pan_gesture_scrolls_panel_not_camera", Callable(BoardCameraInputTests, "_t_pan_gesture_scrolls_panel_not_camera"))
	runner.register_test("board_camera.input/gestures_on_open_board_move_camera",   Callable(BoardCameraInputTests, "_t_gestures_on_open_board_move_camera"))
	runner.register_test("board_camera.input/space_drag_pans_through_stop_chrome",  Callable(BoardCameraInputTests, "_t_space_drag_pans_through_stop_chrome"))
	runner.register_test("board_camera.input/hidden_shell_camera_takes_no_input",   Callable(BoardCameraInputTests, "_t_hidden_shell_camera_takes_no_input"))
	runner.register_test("board_camera.view/world_layer_follows_camera",            Callable(BoardCameraInputTests, "_t_world_layer_follows_camera"))
	runner.register_test("board_camera.view/first_snapshot_centers_camera",         Callable(BoardCameraInputTests, "_t_first_snapshot_centers_camera"))
	runner.register_test("board_camera.view/manual_view_survives_snapshot_refresh", Callable(BoardCameraInputTests, "_t_manual_view_survives_snapshot_refresh"))
	runner.register_test("board_camera.view/pan_alone_survives_snapshot_refresh",   Callable(BoardCameraInputTests, "_t_pan_alone_survives_snapshot_refresh"))
	runner.register_test("board_camera.echo_detail/focus_accounts_for_renderer_position", Callable(BoardCameraInputTests, "_t_echo_detail_focus_accounts_for_renderer_position"))
	runner.register_test("board_camera.echo_detail/tap_different_echo_switches_detail",   Callable(BoardCameraInputTests, "_t_tap_different_echo_switches_detail"))
	runner.register_test("board_camera.bounds/starter_floor_pans_both_axes_large_view", Callable(BoardCameraInputTests, "_t_starter_floor_pans_both_axes_large_view"))
	runner.register_test("board_camera.bounds/starter_floor_pans_both_axes_base_view",  Callable(BoardCameraInputTests, "_t_starter_floor_pans_both_axes_base_view"))
	runner.register_test("board_camera.echo_detail/focus_tween_ends_without_snap",      Callable(BoardCameraInputTests, "_t_echo_detail_focus_tween_ends_without_snap"))
	runner.register_test("board_camera.echo_detail/tap_empty_board_closes_detail",        Callable(BoardCameraInputTests, "_t_tap_empty_board_closes_detail"))


static func _make_fixture(view_size: Vector2i = Vector2i(1280, 720)) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return {}
	var viewport := SubViewport.new()
	viewport.size = view_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var shell := SanctumShellScene.instantiate() as SanctumShell
	viewport.add_child(shell)
	shell.set_layout(_LAYOUT)
	shell.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 1 }, "data": {}, "actions": {} })
	SanctumLayoutTests._force_control_layout(shell)
	return { "viewport": viewport, "shell": shell, "camera": shell.camera }


static func _push_pan(vp: SubViewport, pos: Vector2, delta: Vector2) -> void:
	var ev := InputEventPanGesture.new()
	ev.position = pos
	ev.delta = delta
	vp.push_input(ev, true)


static func _push_magnify(vp: SubViewport, pos: Vector2, factor: float) -> void:
	var ev := InputEventMagnifyGesture.new()
	ev.position = pos
	ev.factor = factor
	vp.push_input(ev, true)


static func _push_left_button(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	vp.push_input(ev, true)


static func _push_motion(vp: SubViewport, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	vp.push_input(ev, true)


# BoardCameraController reads the global Input key state, so the test drives it there.
static func _set_space_held(held: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = held
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


# Jeff's symptom: trackpad scroll over a Sanctum panel moved the board instead of the panel.
static func _t_pan_gesture_scrolls_panel_not_camera() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.push_notification({
		"id": "board_camera.scroll",
		"title": "Scroll fixture",
		"body": "A long line for the scroll body. ".repeat(60),
		"detail": "More text below the fold. ".repeat(60),
		"amount": "",
		"tone": "positive",
		"auto_dismiss": false,
		"blocking_overlay": false,
	})
	SanctumLayoutTests._force_control_layout(shell)
	var scroll := shell.get_node_or_null("%NotificationBodyScroll") as ScrollContainer
	if scroll == null or not scroll.is_visible_in_tree():
		vp.free()
		return { "ok": false, "error": "Notification scroll body is not visible in the fixture" }
	var vbar := scroll.get_v_scroll_bar()
	if vbar.max_value <= vbar.page:
		vp.free()
		return { "ok": false, "error": "Fixture content does not overflow; the scroll check would prove nothing" }
	var cam_before := cam.position
	var scroll_before := scroll.scroll_vertical
	_push_pan(vp, scroll.get_global_rect().get_center(), Vector2(0, 4))
	var scrolled := scroll.scroll_vertical > scroll_before
	var cam_moved := cam.position != cam_before
	vp.free()
	if not scrolled:
		return { "ok": false, "error": "Pan gesture over the panel did not scroll it (%d -> unchanged)" % scroll_before }
	if cam_moved:
		return { "ok": false, "error": "Board camera took a pan gesture that was over a scrollable panel" }
	return { "ok": true }


# Guard against over-correcting: gestures over open board still drive the camera, even though
# the full-rect UILayer/Control (MOUSE_FILTER_STOP) covers that point.
static func _t_gestures_on_open_board_move_camera() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var chrome := shell.get_node_or_null("UILayer/Control") as Control
	if chrome == null or chrome.mouse_filter != Control.MOUSE_FILTER_STOP \
			or not chrome.get_global_rect().has_point(_BOARD_POINT):
		vp.free()
		return { "ok": false, "error": "Fixture no longer has STOP chrome over the board point; test premise changed" }
	var cam_before := cam.position
	_push_pan(vp, _BOARD_POINT, Vector2(0, 4))
	var panned := cam.position != cam_before
	var zoom_before := cam.zoom
	_push_magnify(vp, _BOARD_POINT, 0.8)
	var zoomed := cam.zoom != zoom_before
	vp.free()
	if not panned:
		return { "ok": false, "error": "Two-finger pan over open board did not move the camera" }
	if not zoomed:
		return { "ok": false, "error": "Pinch over open board did not zoom the camera" }
	return { "ok": true }


# The original Story 1 fix: Space+LMB drag must reach the camera through the STOP chrome.
static func _t_space_drag_pans_through_stop_chrome() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var sentinel := UnhandledMouseSentinel.new()
	vp.add_child(sentinel)

	# Premise: a plain LMB press on the board never survives the GUI pass. If this changes,
	# the _input() route for drag-pan is no longer needed and this test must be revisited.
	_push_left_button(vp, _BOARD_POINT, true)
	_push_left_button(vp, _BOARD_POINT, false)
	if sentinel.presses != 0:
		vp.free()
		return { "ok": false, "error": "LMB on the board reached _unhandled_input; STOP chrome premise changed" }

	_set_space_held(true)
	if not Input.is_key_pressed(KEY_SPACE):
		_set_space_held(false)
		vp.free()
		return { "ok": false, "error": "Could not hold Space through Input.parse_input_event" }
	_push_left_button(vp, _BOARD_POINT, true)
	var started := bool(cam.get("_is_panning"))
	var cam_before := cam.position
	_push_motion(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	var moved := cam.position != cam_before
	_push_left_button(vp, _BOARD_POINT + Vector2(20, 0), false)
	var stopped := not bool(cam.get("_is_panning"))
	var cam_after_release := cam.position
	_push_motion(vp, _BOARD_POINT + Vector2(40, 0), Vector2(20, 0))
	var still_after_release := cam.position == cam_after_release
	_set_space_held(false)
	vp.free()
	if not started:
		return { "ok": false, "error": "Space+LMB over STOP chrome did not start a camera drag" }
	if not moved:
		return { "ok": false, "error": "Mouse motion during Space+LMB drag did not move the camera" }
	if not stopped or not still_after_release:
		return { "ok": false, "error": "Releasing LMB did not end the camera drag" }
	return { "ok": true }


# SanctumShell is hidden, not freed, while RealmShell is active. _input() still runs on hidden
# nodes, so the camera must ignore input while its shell is hidden (camera.enabled is false).
static func _t_hidden_shell_camera_takes_no_input() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.visible = false
	if cam.enabled:
		vp.free()
		return { "ok": false, "error": "Hiding SanctumShell did not disable its camera" }
	var cam_before := cam.position
	var zoom_before := cam.zoom
	_push_pan(vp, _BOARD_POINT, Vector2(0, 4))
	_push_magnify(vp, _BOARD_POINT, 1.2)
	_set_space_held(true)
	_push_left_button(vp, _BOARD_POINT, true)
	var started := bool(cam.get("_is_panning"))
	_push_motion(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	_push_left_button(vp, _BOARD_POINT + Vector2(20, 0), false)
	_set_space_held(false)
	var changed := cam.position != cam_before or cam.zoom != zoom_before
	vp.free()
	if started or changed:
		return { "ok": false, "error": "Hidden Sanctum camera still reacted to input" }
	return { "ok": true }


# A real floor, so _center_camera_on_floor() and the bounds clamp both run.
static func _floor_snapshot(t: int) -> Dictionary:
	var tiles: Array = []
	for x in range(-8, 9):
		for y in range(-8, 9):
			tiles.append({ "x": x, "y": y, "kind": "floor" })
	return { "type": "flow.sanctum", "meta": { "t": t }, "data": { "sanctum_layout": { "tiles": tiles } }, "actions": {} }


# Where the board is actually drawn on screen. Camera2D writes the viewport canvas transform;
# only this proves the drawn board follows it.
static func _board_screen_xform(shell: SanctumShell, cam: BoardCameraController) -> Transform2D:
	cam.force_update_scroll()
	return shell.spatial_renderer.get_global_transform_with_canvas()


# Jeff's playtest: camera state changed on every input, the board on screen never moved. The board
# sits in its own CanvasLayer, which ignores the camera unless it follows the viewport.
static func _t_world_layer_follows_camera() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_floor_snapshot(2))
	var before := _board_screen_xform(shell, cam)
	_push_pan(vp, _BOARD_POINT, Vector2(0, 4))
	var after_pan := _board_screen_xform(shell, cam)
	_push_magnify(vp, _BOARD_POINT, 0.8)
	var after_zoom := _board_screen_xform(shell, cam)
	vp.free()
	if is_equal_approx(before.get_scale().x, 1.0):
		return { "ok": false, "error": "Board drawn at scale 1.0 while camera zoom is 2.0; the camera does not reach the board" }
	if after_pan.origin.is_equal_approx(before.origin):
		return { "ok": false, "error": "Pan moved the camera but not the board on screen" }
	if is_equal_approx(after_zoom.get_scale().x, after_pan.get_scale().x):
		return { "ok": false, "error": "Pinch zoomed the camera but not the board on screen" }
	return { "ok": true }


# Before the player touches the camera, a snapshot still re-centers it on the floor.
static func _t_first_snapshot_centers_camera() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	cam.position = Vector2(37, 21)
	shell.set_snapshot(_floor_snapshot(2))
	var pos := cam.position
	vp.free()
	if pos != Vector2.ZERO:
		return { "ok": false, "error": "Snapshot before any manual input did not re-center the camera (at %s)" % pos }
	return { "ok": true }


# Sanctum snapshots arrive every second or two. A pan or pinch must survive the next one, including
# one that lands between two magnify events of the same pinch.
static func _t_manual_view_survives_snapshot_refresh() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_floor_snapshot(2))
	_push_magnify(vp, _BOARD_POINT, 0.9)
	var zoom_mid := cam.zoom
	shell.set_snapshot(_floor_snapshot(3))
	var zoom_kept_mid := cam.zoom == zoom_mid
	_push_magnify(vp, _BOARD_POINT, 0.9)
	var zoom_end := cam.zoom
	_push_pan(vp, _BOARD_POINT, Vector2(10, 6))
	var pos_manual := cam.position
	shell.set_snapshot(_floor_snapshot(4))
	var pos_after := cam.position
	var zoom_after := cam.zoom
	vp.free()
	if pos_manual == Vector2.ZERO:
		return { "ok": false, "error": "Pan did not move the camera off center; test premise failed" }
	if not zoom_kept_mid or not zoom_end.is_equal_approx(Vector2(2.0, 2.0) * 0.81):
		return { "ok": false, "error": "Snapshot during a pinch changed zoom (mid %s, end %s)" % [zoom_mid, zoom_end] }
	if pos_after != pos_manual:
		return { "ok": false, "error": "Snapshot refresh reset the manual pan (%s -> %s)" % [pos_manual, pos_after] }
	if zoom_after != zoom_end:
		return { "ok": false, "error": "Snapshot refresh changed the manual zoom (%s -> %s)" % [zoom_end, zoom_after] }
	return { "ok": true }


# Pan with no pinch first, so the pan itself must mark the view as the player's.
static func _t_pan_alone_survives_snapshot_refresh() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_floor_snapshot(2))
	_push_pan(vp, _BOARD_POINT, Vector2(10, 6))
	var pos_manual := cam.position
	shell.set_snapshot(_floor_snapshot(3))
	var pos_after := cam.position
	vp.free()
	if pos_manual == Vector2.ZERO:
		return { "ok": false, "error": "Pan did not move the camera off center; test premise failed" }
	if pos_after != pos_manual:
		return { "ok": false, "error": "Snapshot refresh reset a pan-only view (%s -> %s)" % [pos_manual, pos_after] }
	return { "ok": true }


# A real starter layout (asymmetric main sanctum + party staging area) so spatial_renderer.position
# lands away from zero after _center_camera_on_floor() — needed to prove the coordinate-space fix.
static func _echo_occupant_snapshot(t: int, echo_ids: Array) -> Dictionary:
	var roster: Array = []
	for id_str in echo_ids:
		roster.append(SanctumLayoutTests._make_echo(id_str))
	var save := SanctumLayoutTests._make_save(roster)
	var layout := SanctumLayoutService.make_starter_layout()
	var occupants := SanctumLayoutService.snapshot_occupants(save)
	return { "type": "flow.sanctum", "meta": { "t": t }, "data": { "sanctum_layout": layout, "sanctum_occupants": occupants }, "actions": {} }


static func _occupant_local_position(shell: SanctumShell, occupant_id: String) -> Vector2:
	var cache_v: Variant = shell.spatial_renderer.get("_occupant_cache")
	var cache: Array = cache_v if cache_v is Array else []
	for occ_v in cache:
		if not (occ_v is Dictionary):
			continue
		var occ: Dictionary = occ_v
		if str(occ.get("id", "")) == occupant_id:
			var pos_v: Variant = occ.get("position", Vector2.ZERO)
			return pos_v if pos_v is Vector2 else Vector2.ZERO
	return Vector2.ZERO


static func _viewport_point_for_occupant(shell: SanctumShell, occupant_id: String) -> Vector2:
	var local_pos := _occupant_local_position(shell, occupant_id)
	return shell.spatial_renderer.get_global_transform_with_canvas() * local_pos


# Bug 1: _focus_camera_for_echo_detail() must add spatial_renderer.position (SpatialView-local
# space) to occupant_pos (spatial_renderer-local space) — see SanctumShell.gd's own comment.
static func _t_echo_detail_focus_accounts_for_renderer_position() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a"]))
	SanctumLayoutTests._force_control_layout(shell)

	var renderer_offset: Vector2 = shell.spatial_renderer.position
	if renderer_offset.is_equal_approx(Vector2.ZERO):
		vp.free()
		return { "ok": false, "error": "spatial_renderer.position is zero in this fixture; cannot prove the coordinate-space fix" }

	var occupant_local := _occupant_local_position(shell, "echo_a")
	shell.call("_focus_camera_for_echo_detail", occupant_local, false)

	var detail_zoom: Vector2 = shell.get("_detail_zoom")
	var horizontal_shift := (shell.spatial_layer.size.x / detail_zoom.x) * 0.20
	var expected := renderer_offset + occupant_local - Vector2(horizontal_shift, 0.0)
	var cam_pos: Vector2 = shell.camera.position
	vp.free()
	if not cam_pos.is_equal_approx(expected):
		return { "ok": false, "error": "Camera focus ignored spatial_renderer.position offset (got %s, expected %s)" % [cam_pos, expected] }
	return { "ok": true }


# Bug 2 (b): tapping a different echo while detail is open switches the camera target and the
# featured occupant, and must not re-save the pre-detail camera state from the already-zoomed view.
static func _t_tap_different_echo_switches_detail() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a", "echo_b"]))
	SanctumLayoutTests._force_control_layout(shell)

	var point_a := _viewport_point_for_occupant(shell, "echo_a")
	var point_b := _viewport_point_for_occupant(shell, "echo_b")
	if point_a.is_equal_approx(Vector2.ZERO) or point_b.is_equal_approx(Vector2.ZERO) or point_a.is_equal_approx(point_b):
		vp.free()
		return { "ok": false, "error": "Fixture occupant points invalid: a=%s b=%s" % [point_a, point_b] }

	_push_left_button(vp, point_a, true)
	_push_left_button(vp, point_a, false)
	var opened_a := bool(shell.get("_echo_detail_open")) and str(shell.get("_featured_echo_id")) == "echo_a"
	if not opened_a:
		vp.free()
		return { "ok": false, "error": "Tapping echo_a did not open its detail (featured=%s)" % shell.get("_featured_echo_id") }
	var saved_pos: Vector2 = shell.get("_saved_camera_position")
	var saved_zoom: Vector2 = shell.get("_saved_camera_zoom")

	# Simulate the camera having already animated into the detail-zoomed framing (as it would
	# mid-tween in real play) before switching echoes, so a wrongly-re-saved value is observable.
	# Recompute point_b under the moved camera so the hit-test at the new viewport pixel still
	# lands on echo_b (the tap point is screen space, which the camera move re-maps).
	cam.position = Vector2(999.0, -999.0)
	cam.zoom = Vector2(5.0, 5.0)
	var point_b_after_move := _viewport_point_for_occupant(shell, "echo_b")

	_push_left_button(vp, point_b_after_move, true)
	_push_left_button(vp, point_b_after_move, false)
	var featured_after := str(shell.get("_featured_echo_id"))
	var target_after := cam.target_id
	var switched := featured_after == "echo_b" and target_after == "echo_b"
	var saved_unchanged := Vector2(shell.get("_saved_camera_position")) == saved_pos \
			and Vector2(shell.get("_saved_camera_zoom")) == saved_zoom
	vp.free()
	if not switched:
		return { "ok": false, "error": "Tapping a different echo did not switch the featured occupant/camera target (featured=%s target=%s)" % [featured_after, target_after] }
	if not saved_unchanged:
		return { "ok": false, "error": "Switching echoes re-saved the pre-detail camera state" }
	return { "ok": true }


# Bug 2 (c): tapping empty board space while detail is open closes it the same way the back
# button does, restoring the camera to FREE mode.
static func _t_tap_empty_board_closes_detail() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a"]))
	SanctumLayoutTests._force_control_layout(shell)

	var point_a := _viewport_point_for_occupant(shell, "echo_a")
	if point_a.is_equal_approx(Vector2.ZERO):
		vp.free()
		return { "ok": false, "error": "Fixture occupant point invalid" }

	_push_left_button(vp, point_a, true)
	_push_left_button(vp, point_a, false)
	if not bool(shell.get("_echo_detail_open")):
		vp.free()
		return { "ok": false, "error": "Tapping echo_a did not open its detail" }

	var empty_point := Vector2(4, 4)  # top-left corner: no occupant, no chrome control
	_push_left_button(vp, empty_point, true)
	_push_left_button(vp, empty_point, false)
	var closed := not bool(shell.get("_echo_detail_open"))
	var cam_free := cam.mode == BoardCameraController.Mode.FREE and cam.target_id == ""
	vp.free()
	if not closed:
		return { "ok": false, "error": "Tapping empty board space did not close the open detail view" }
	if not cam_free:
		return { "ok": false, "error": "Closing detail via empty tap did not restore the camera to FREE mode" }
	return { "ok": true }



# 2048x1280 is the logical view of a 2560x1600 px window: ResponsiveLayoutController caps
# ui_scale at 1.25, so a bigger window shows more world. With the old clamp the starter floor
# plus pad fit that view horizontally, so the x axis locked at center and only y panned.
const _LARGE_VIEW := Vector2i(2048, 1280)


# Pans each axis at every Sanctum zoom level and returns an error string, or "" when both axes
# moved by the full, unclamped pan amount.
static func _check_both_axes_pan(view_size: Vector2i) -> String:
	var fx := _make_fixture(view_size)
	if fx.is_empty():
		return "Ready fixture host unavailable"
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a"]))
	SanctumLayoutTests._force_control_layout(shell)
	var content: Vector2 = cam.get("_content_size")
	if content == Vector2.ZERO:
		vp.free()
		return "Starter floor gave the camera no bounds; test premise failed"
	var board_point := Vector2(view_size) * Vector2(0.5, 0.4)
	var pan_delta := 10.0
	# Default zoom first, so a failure names the zoom the player starts at.
	var levels: Array = (shell.get("_zoom_levels") as Array).duplicate()
	var default_zoom: Vector2 = levels.pop_at(int(shell.get("_zoom_index")))
	levels.push_front(default_zoom)
	for zoom_v in levels:
		var z: Vector2 = zoom_v
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			cam.zoom = z
			cam.position = Vector2.ZERO
			_push_pan(vp, board_point, axis * pan_delta)
			var expected: Vector2 = -axis * pan_delta * 2.5 / z.x
			if not cam.position.is_equal_approx(expected):
				var got := cam.position
				vp.free()
				return "View %s zoom %s, content %s: pan along %s moved camera to %s, expected %s" % [view_size, z.x, content, axis, got, expected]
	vp.free()
	return ""


static func _t_starter_floor_pans_both_axes_large_view() -> Dictionary:
	var err := _check_both_axes_pan(_LARGE_VIEW)
	return { "ok": err.is_empty(), "error": err }


static func _t_starter_floor_pans_both_axes_base_view() -> Dictionary:
	var err := _check_both_axes_pan(Vector2i(1280, 720))
	return { "ok": err.is_empty(), "error": err }


# The focus tween used to end on a target outside the clamp, and its closing reclamp then threw the
# view back toward center. The tween must end where the clamp leaves it.
static func _t_echo_detail_focus_tween_ends_without_snap() -> Dictionary:
	var fx := _make_fixture(_LARGE_VIEW)
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a"]))
	SanctumLayoutTests._force_control_layout(shell)
	var point_a := _viewport_point_for_occupant(shell, "echo_a")
	_push_left_button(vp, point_a, true)
	_push_left_button(vp, point_a, false)
	var tw: Tween = shell.get("_camera_tween")
	if not bool(shell.get("_echo_detail_open")) or tw == null or not tw.is_valid():
		vp.free()
		return { "ok": false, "error": "Tapping echo_a did not start the focus tween" }
	tw.custom_step(0.419)
	var before_reclamp := cam.position
	tw.custom_step(0.1)
	var after_reclamp := cam.position
	vp.free()
	if before_reclamp.distance_to(after_reclamp) > 2.0:
		return { "ok": false, "error": "Focus tween ended at %s, then the reclamp snapped it to %s" % [before_reclamp, after_reclamp] }
	return { "ok": true }
