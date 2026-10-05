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
	runner.register_test("board_camera.input/space_drag_does_not_press_focused_button", Callable(BoardCameraInputTests, "_t_space_drag_does_not_press_focused_button"))
	runner.register_test("board_camera.input/space_still_types_in_focused_line_edit",   Callable(BoardCameraInputTests, "_t_space_still_types_in_focused_line_edit"))
	runner.register_test("board_camera.input/space_guard_covers_any_base_button",      Callable(BoardCameraInputTests, "_t_space_guard_covers_any_base_button"))
	runner.register_test("board_camera.input/space_guard_off_when_camera_disabled",     Callable(BoardCameraInputTests, "_t_space_guard_off_when_camera_disabled"))
	runner.register_test("board_camera.input/space_still_presses_modal_button",         Callable(BoardCameraInputTests, "_t_space_still_presses_modal_button"))
	runner.register_test("board_camera.input/space_guard_works_in_echo_detail",         Callable(BoardCameraInputTests, "_t_space_guard_works_in_echo_detail"))
	runner.register_test("board_camera.input/space_guard_ignores_modal_host_name",      Callable(BoardCameraInputTests, "_t_space_guard_ignores_modal_host_name"))
	runner.register_test("board_camera.input/space_guard_follows_sanctum_view",         Callable(BoardCameraInputTests, "_t_space_guard_follows_sanctum_view"))
	runner.register_test("board_camera.zoom/sanctum_z_steps_levels_eased",             Callable(BoardCameraInputTests, "_t_sanctum_z_steps_levels_eased"))
	runner.register_test("board_camera.zoom/sanctum_wheel_eases_continuous_and_clamps", Callable(BoardCameraInputTests, "_t_sanctum_wheel_eases_continuous_and_clamps"))
	runner.register_test("board_camera.zoom/sanctum_wheel_zooms_toward_pointer",       Callable(BoardCameraInputTests, "_t_sanctum_wheel_zooms_toward_pointer"))
	runner.register_test("board_camera.zoom/sanctum_wheel_scrolls_panels_not_board",   Callable(BoardCameraInputTests, "_t_sanctum_wheel_scrolls_panels_not_board"))
	runner.register_test("board_camera.zoom/sanctum_wheel_then_z_goes_to_next_level",  Callable(BoardCameraInputTests, "_t_sanctum_wheel_then_z_goes_to_next_level"))
	runner.register_test("board_camera.zoom/sanctum_z_after_pinch_goes_to_next_level", Callable(BoardCameraInputTests, "_t_sanctum_z_after_pinch_goes_to_next_level"))
	runner.register_test("board_camera.zoom/sanctum_zoom_keys_ignored_in_echo_detail", Callable(BoardCameraInputTests, "_t_sanctum_zoom_keys_ignored_in_echo_detail"))
	runner.register_test("board_camera.zoom/sanctum_ease_does_not_fight_detail_tween", Callable(BoardCameraInputTests, "_t_sanctum_ease_does_not_fight_detail_tween"))
	runner.register_test("board_camera.zoom/hidden_sanctum_takes_no_zoom_input",       Callable(BoardCameraInputTests, "_t_hidden_sanctum_takes_no_zoom_input"))
	runner.register_test("board_camera.zoom/sanctum_quick_second_z_steps_from_target", Callable(BoardCameraInputTests, "_t_sanctum_quick_second_z_steps_from_target"))
	runner.register_test("board_camera.zoom/instant_camera_move_releases_input",      Callable(BoardCameraInputTests, "_t_instant_camera_move_releases_input"))
	runner.register_test("board_camera.zoom/modified_z_does_not_zoom",               Callable(BoardCameraInputTests, "_t_modified_z_does_not_zoom"))


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
	# Space+drag is 1:1: the world point under the pointer stays under it.
	var pan_got := cam.position - cam_before
	var pan_want := -Vector2(20, 0) / cam.zoom.x
	var pan_exact := pan_got.is_equal_approx(pan_want)
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
	if not pan_exact:
		return { "ok": false, "error": "Space+LMB drag moved the camera %s, want 1:1 %s" % [pan_got, pan_want] }
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
	var levels: Array = []
	for level in cam.zoom_levels:
		if not is_equal_approx(level, cam.zoom.x):
			levels.append(Vector2(level, level))
	levels.push_front(cam.zoom)
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


# Space reaches the viewport as a key event (the GUI's ui_accept) and also sets the Input state
# the camera's Space+LMB drag reads. Both halves, as a real key press does.
static func _push_space(vp: SubViewport, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.unicode = 32
	ev.pressed = pressed
	_set_space_held(pressed)
	vp.push_input(ev, true)


# A clicked rail button keeps keyboard focus. Holding Space to pan must not press it again.
static func _t_space_drag_does_not_press_focused_button() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 2 }, "data": {}, "actions": {
		"nav.summon": { "type": "flow.go_state", "to": "flow.summon", "label": "Summon" } } })
	SanctumLayoutTests._force_control_layout(shell)
	var button := shell.get_node_or_null("%SummonButton") as Button
	if button == null or button.disabled or not button.is_visible_in_tree():
		vp.free()
		return { "ok": false, "error": "Summon rail button missing, disabled or hidden; premise failed" }
	var presses := [0]
	button.pressed.connect(func(): presses[0] += 1)
	var point := button.get_global_rect().get_center()
	_push_left_button(vp, point, true)
	_push_left_button(vp, point, false)
	var focused := vp.gui_get_focus_owner() == button
	var after_click: int = presses[0]
	_push_space(vp, true)
	var cam_before := cam.position
	_push_left_button(vp, _BOARD_POINT, true)
	_push_motion(vp, _BOARD_POINT + Vector2(20, 0), Vector2(20, 0))
	_push_left_button(vp, _BOARD_POINT + Vector2(20, 0), false)
	_push_space(vp, false)
	var panned := cam.position != cam_before
	var total: int = presses[0]
	vp.free()
	if after_click != 1 or not focused:
		return { "ok": false, "error": "Click gave %d presses, focused=%s; premise failed" % [after_click, focused] }
	if total != 1:
		return { "ok": false, "error": "Space+drag pressed the focused rail button again (%d presses)" % total }
	if not panned:
		return { "ok": false, "error": "Space+drag did not pan while a button had focus" }
	return { "ok": true }


# The guard is for buttons only: a focused text field still receives Space.
static func _t_space_still_types_in_focused_line_edit() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var field := LineEdit.new()
	field.size = Vector2(200, 40)
	vp.add_child(field)
	field.grab_focus()
	var focused := vp.gui_get_focus_owner() == field
	var enabled := cam.enabled
	_push_space(vp, true)
	_push_space(vp, false)
	var text := field.text
	vp.free()
	if not focused or not enabled:
		return { "ok": false, "error": "LineEdit focused=%s, camera enabled=%s; premise failed" % [focused, enabled] }
	if text != " ":
		return { "ok": false, "error": "Focused LineEdit got '%s' from Space, want a space" % text }
	return { "ok": true }


# Presses Space once (press and release) and returns how many times `button` fired.
static func _space_presses(vp: SubViewport, button: BaseButton) -> int:
	var presses := [0]
	var on_pressed := func(): presses[0] += 1
	button.pressed.connect(on_pressed)
	_push_space(vp, true)
	_push_space(vp, false)
	button.pressed.disconnect(on_pressed)
	return presses[0]


static func _focused_texture_button(vp: SubViewport) -> TextureButton:
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.position = Vector2(8, 8)
	vp.add_child(button)
	button.grab_focus()
	return button


# The guard checks BaseButton, so a TextureButton (not a Button) is covered too.
static func _t_space_guard_covers_any_base_button() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var button := _focused_texture_button(vp)
	var focused := vp.gui_get_focus_owner() == button
	var presses := _space_presses(vp, button)
	vp.free()
	if not focused:
		return { "ok": false, "error": "TextureButton did not take focus; premise failed" }
	if presses != 0:
		return { "ok": false, "error": "Space pressed a focused TextureButton %d times while the camera was enabled" % presses }
	return { "ok": true }


# A disabled camera (its screen is hidden) leaves Space alone.
static func _t_space_guard_off_when_camera_disabled() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var button := _focused_texture_button(vp)
	shell.visible = false
	var disabled := not cam.enabled
	var focused := vp.gui_get_focus_owner() == button
	var presses := _space_presses(vp, button)
	vp.free()
	if not disabled or not focused:
		return { "ok": false, "error": "Camera disabled=%s, button focused=%s; premise failed" % [disabled, focused] }
	if presses != 1:
		return { "ok": false, "error": "Space pressed the focused button %d times with the camera disabled, want 1" % presses }
	return { "ok": true }


# A dialog in the real ModalHost keeps Space: its focused button still fires.
static func _t_space_still_presses_modal_button() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var host := (load("res://ui/components/ModalHost.tscn") as PackedScene).instantiate() as ModalHost
	# A different node name, so only a type check (not a name check) finds the modal host.
	host.name = "DialogHost"
	vp.add_child(host)
	var dialog_button := Button.new()
	dialog_button.text = "OK"
	dialog_button.custom_minimum_size = Vector2(120, 48)
	var dialog := PackedScene.new()
	dialog.pack(dialog_button)
	dialog_button.free()
	var shown := host.present_modal(dialog)
	var focused := vp.gui_get_focus_owner()
	var in_modal := focused is Button and host.is_ancestor_of(focused)
	var enabled := cam.enabled
	var presses := _space_presses(vp, focused as BaseButton) if in_modal else -1
	vp.free()
	if not shown or not in_modal or not enabled:
		return { "ok": false, "error": "Modal shown=%s, focus in modal=%s, camera enabled=%s; premise failed" % [shown, in_modal, enabled] }
	if presses != 1:
		return { "ok": false, "error": "Space pressed the focused modal button %d times, want 1" % presses }
	return { "ok": true }


# Sanctum's echo detail locks the camera with manual_resume_delay 0, so the camera takes no manual
# input there. A clicked detail tab keeps focus; Space must still not press it again.
static func _t_space_guard_works_in_echo_detail() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	# The detail panel renders from data.echo_detail_roster; without it the panel stays hidden.
	var snap := _echo_occupant_snapshot(2, ["echo_a"])
	snap["data"]["echo_detail_roster"] = [SanctumLayoutTests._make_echo("echo_a")]
	shell.set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(shell)
	var point_a := _viewport_point_for_occupant(shell, "echo_a")
	_push_left_button(vp, point_a, true)
	_push_left_button(vp, point_a, false)
	SanctumLayoutTests._force_control_layout(shell)
	var tab := shell.get_node_or_null("UILayer/Control/OverlayRoot").find_child("TabBonds", true, false) as Button
	var open := bool(shell.get("_echo_detail_open"))
	var locked: bool = cam.mode != BoardCameraController.Mode.FREE and cam.enabled and not bool(cam.call("_accepts_manual_input"))
	if not open or not locked or tab == null or not tab.is_visible_in_tree():
		vp.free()
		return { "ok": false, "error": "Detail open=%s, camera locked and enabled without manual input=%s, tab visible=%s; premise failed" % [open, locked, tab != null and tab.is_visible_in_tree()] }
	var clicks := [0]
	tab.pressed.connect(func(): clicks[0] += 1)
	var tab_point := tab.get_global_rect().get_center()
	_push_left_button(vp, tab_point, true)
	_push_left_button(vp, tab_point, false)
	var focused := vp.gui_get_focus_owner() == tab
	var after_click: int = clicks[0]
	var presses := _space_presses(vp, tab)
	vp.free()
	if after_click != 1 or not focused:
		return { "ok": false, "error": "Tab click gave %d presses, focused=%s; premise failed" % [after_click, focused] }
	if presses != 0:
		return { "ok": false, "error": "Space pressed the focused echo-detail tab %d times" % presses }
	return { "ok": true }


# A plain Control that is merely NAMED "ModalHost" is not a modal: Space stays guarded there.
static func _t_space_guard_ignores_modal_host_name() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var impostor := Control.new()
	impostor.name = "ModalHost"
	vp.add_child(impostor)
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(48, 48)
	impostor.add_child(button)
	button.grab_focus()
	var focused := vp.gui_get_focus_owner() == button
	var presses := _space_presses(vp, button)
	vp.free()
	if not focused:
		return { "ok": false, "error": "Button under the impostor did not take focus; premise failed" }
	if presses != 0:
		return { "ok": false, "error": "Space pressed a button under a non-modal node named ModalHost %d times" % presses }
	return { "ok": true }


# The guard follows the real SanctumShell view: on the board view Space never presses a focused
# button; on Summon and Echo Party it does; back on the board the guard returns.
static func _t_space_guard_follows_sanctum_view() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var steps := [
		{ "type": "flow.sanctum",   "want": 0 },
		{ "type": "flow.summon",    "want": 1 },
		{ "type": "flow.sanctum",   "want": 0 },
		{ "type": "flow.echo_party", "want": 1 },
		{ "type": "flow.sanctum",   "want": 0 },
	]
	var errors: Array = []
	var t := 2
	for step in steps:
		shell.set_snapshot({ "type": step["type"], "meta": { "t": t }, "data": {}, "actions": {} })
		t += 1
		SanctumLayoutTests._force_control_layout(shell)
		var button := _focused_texture_button(vp)
		if vp.gui_get_focus_owner() != button or not cam.enabled:
			errors.append("%s: button focused=%s, camera enabled=%s; premise failed" % [step["type"], vp.gui_get_focus_owner() == button, cam.enabled])
		else:
			var presses := _space_presses(vp, button)
			if presses != int(step["want"]):
				errors.append("%s: Space pressed the focused button %d times, want %d" % [step["type"], presses, step["want"]])
		button.free()
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _push_key_z(vp: SubViewport) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_Z
		ev.physical_keycode = KEY_Z
		ev.unicode = 122
		ev.pressed = pressed
		vp.push_input(ev, true)


# Sanctum zoom levels (decisions.md #94): the shared camera's zoom_levels [0.5, 1.0, 1.5, 2.0, 2.5].
# Z and the wheel both step one level and ease. Z wraps; the wheel holds at the ends.

static func _settle(cam: BoardCameraController, seconds: float = 1.0) -> void:
	for i in range(int(ceil(seconds / 0.05))):
		cam._process(0.05)


static func _push_wheel_notch(vp: SubViewport, up: bool) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = _BOARD_POINT
	mm.global_position = _BOARD_POINT
	vp.push_input(mm, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = _BOARD_POINT
		ev.global_position = _BOARD_POINT
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.factor = 1.0
		ev.pressed = pressed
		vp.push_input(ev, true)


static func _t_sanctum_z_steps_levels_eased() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var start := cam.zoom.x
	_push_key_z(vp)
	var right_after := cam.zoom.x
	cam._process(0.05)
	var one_frame := cam.zoom.x
	_settle(cam)
	var seq: Array = [snappedf(cam.zoom.x, 0.001)]
	for i in range(2):
		_push_key_z(vp)
		_settle(cam)
		seq.append(snappedf(cam.zoom.x, 0.001))
	vp.free()
	if not is_equal_approx(start, 2.0):
		return { "ok": false, "error": "Sanctum start zoom %s, want 2.0" % start }
	if not is_equal_approx(right_after, 2.0) or not (one_frame > 2.0 and one_frame < 2.5):
		return { "ok": false, "error": "Z did not ease: %s at once, %s after one frame" % [right_after, one_frame] }
	if seq != [2.5, 0.5, 1.0]:
		return { "ok": false, "error": "Sanctum Z sequence %s, want [2.5, 0.5, 1.0]" % [seq] }
	return { "ok": true }


# One wheel rule for every board camera (decisions.md #95): 1.1x per notch, eased, notches add up
# on the ease target, clamped to the range 0.5-2.5.
static func _t_sanctum_wheel_eases_continuous_and_clamps() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	_push_wheel_notch(vp, true)
	var right_after := cam.zoom.x
	cam._process(0.05)
	var one_frame := cam.zoom.x
	_settle(cam)
	if not is_equal_approx(right_after, 2.0) or not (one_frame > 2.0 and one_frame < 2.2):
		errors.append("Wheel did not ease: %s at once, %s after one frame" % [right_after, one_frame])
	if not is_equal_approx(cam.zoom.x, 2.2):
		errors.append("One notch from 2.0 gave %s, want 2.2" % cam.zoom.x)
	cam.zoom = Vector2(1.0, 1.0)
	_push_wheel_notch(vp, true)
	cam._process(0.05)
	_push_wheel_notch(vp, true)
	_settle(cam)
	if not is_equal_approx(cam.zoom.x, 1.21):
		errors.append("Two quick notches from 1.0 gave %s, want 1.21" % cam.zoom.x)
	for i in range(20):
		_push_wheel_notch(vp, true)
	_settle(cam)
	if not is_equal_approx(cam.zoom.x, 2.5):
		errors.append("Wheel in stopped at %s, want 2.5" % cam.zoom.x)
	for i in range(40):
		_push_wheel_notch(vp, false)
	_settle(cam, 2.0)
	if not is_equal_approx(cam.zoom.x, 0.5):
		errors.append("Wheel out stopped at %s, want 0.5" % cam.zoom.x)
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_sanctum_z_after_pinch_goes_to_next_level() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	_push_magnify(vp, _BOARD_POINT, 0.8)
	var after_pinch := cam.zoom.x
	_push_key_z(vp)
	_settle(cam)
	var after_z := cam.zoom.x
	vp.free()
	if not is_equal_approx(after_pinch, 1.6):
		return { "ok": false, "error": "Pinch gave %s, want an immediate 1.6; premise failed" % after_pinch }
	if not is_equal_approx(after_z, 2.0):
		return { "ok": false, "error": "Z after a pinch to 1.6 went to %s, want the next level 2.0" % after_z }
	return { "ok": true }


# Opens the echo detail by a real tap and runs its focus tween to the end.
static func _open_detail_and_finish_tween(fx: Dictionary) -> bool:
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var snap := _echo_occupant_snapshot(2, ["echo_a"])
	snap["data"]["echo_detail_roster"] = [SanctumLayoutTests._make_echo("echo_a")]
	shell.set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(shell)
	var point_a := _viewport_point_for_occupant(shell, "echo_a")
	_push_left_button(vp, point_a, true)
	_push_left_button(vp, point_a, false)
	var tw: Tween = shell.get("_camera_tween")
	if not bool(shell.get("_echo_detail_open")) or tw == null or not tw.is_valid():
		return false
	for i in range(12):
		tw.custom_step(0.05)
		(fx["camera"] as BoardCameraController)._process(0.05)
	return true


static func _t_sanctum_zoom_keys_ignored_in_echo_detail() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	if not _open_detail_and_finish_tween(fx):
		vp.free()
		return { "ok": false, "error": "Echo detail did not open with its focus tween; premise failed" }
	var detail_zoom := cam.zoom
	_push_key_z(vp)
	_push_wheel_notch(vp, true)
	_push_wheel_notch(vp, false)
	_settle(cam)
	var after := cam.zoom
	var goal := cam.zoom_goal()
	vp.free()
	if not detail_zoom.is_equal_approx(Vector2(2.9, 2.9)):
		return { "ok": false, "error": "Detail zoom %s, want 2.9; premise failed" % detail_zoom }
	if after != detail_zoom or goal != detail_zoom:
		return { "ok": false, "error": "Z or wheel changed the zoom in echo detail (%s -> %s, goal %s)" % [detail_zoom, after, goal] }
	return { "ok": true }


# A running Z ease stops when the detail focus tween starts, and Z during the restore tween is
# ignored. Both tweens end exactly on their target zoom. Closing returns to the zoom the player was
# heading to (the Z target 2.0, not the mid-ease value), and the next Z goes to 2.5.
static func _t_sanctum_ease_does_not_fight_detail_tween() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	_push_magnify(vp, _BOARD_POINT, 0.8)
	var pinched := cam.zoom
	_push_key_z(vp)
	cam._process(0.05)
	var easing_before := float(cam.get("_zoom_target")) > 0.0
	if not _open_detail_and_finish_tween(fx):
		vp.free()
		return { "ok": false, "error": "Echo detail did not open; premise failed" }
	if not easing_before:
		errors.append("No Z ease was running before the detail opened; premise failed")
	if not cam.zoom.is_equal_approx(Vector2(2.9, 2.9)):
		errors.append("Detail tween ended at zoom %s, want 2.9 (the ease fought it)" % cam.zoom)
	var saved: Vector2 = shell.get("_saved_camera_zoom")
	if not saved.is_equal_approx(Vector2(2.0, 2.0)):
		errors.append("Saved zoom %s, want the ease target 2.0 (not a mid-ease value)" % saved)
	# Close by tapping empty board, then press Z during the restore tween.
	_push_left_button(vp, Vector2(4, 4), true)
	_push_left_button(vp, Vector2(4, 4), false)
	var tw: Tween = shell.get("_camera_tween")
	if tw == null or not tw.is_valid():
		vp.free()
		return { "ok": false, "error": "Closing the detail started no restore tween; premise failed" }
	tw.custom_step(0.1)
	_push_key_z(vp)
	for i in range(12):
		tw.custom_step(0.05)
		cam._process(0.05)
	var restored := cam.zoom
	_settle(cam)
	var settled := cam.zoom
	_push_key_z(vp)
	_settle(cam)
	var next_z := cam.zoom.x
	vp.free()
	if not restored.is_equal_approx(Vector2(2.0, 2.0)) or settled != restored:
		errors.append("Restore ended at %s then drifted to %s, want 2.0 (Z during the tween must be ignored)" % [restored, settled])
	if not is_equal_approx(next_z, 2.5):
		errors.append("Z after the detail closed went to %s, want the next level 2.5" % next_z)
	if not is_equal_approx(pinched.x, 1.6):
		errors.append("Pinch gave %s, want 1.6; premise failed" % pinched)
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_hidden_sanctum_takes_no_zoom_input() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.visible = false
	var z0 := cam.zoom
	_push_key_z(vp)
	_push_wheel_notch(vp, true)
	_settle(cam)
	var z1 := cam.zoom
	var goal := cam.zoom_goal()
	vp.free()
	if z1 != z0 or goal != z0:
		return { "ok": false, "error": "Hidden Sanctum zoom changed (%s -> %s, goal %s)" % [z0, z1, goal] }
	return { "ok": true }


# A second Z before the first ease ends steps from the first press's target, not from the
# mid-ease zoom. From 1.0: the first Z heads to 1.5, the second to 2.0.
static func _t_sanctum_quick_second_z_steps_from_target() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	for i in range(3):
		_push_key_z(vp)
		_settle(cam)
	var start := cam.zoom.x
	_push_key_z(vp)
	cam._process(0.05)
	var mid := cam.zoom.x
	_push_key_z(vp)
	_settle(cam)
	var end := cam.zoom.x
	vp.free()
	if not is_equal_approx(start, 1.0) or not (mid > 1.0 and mid < 1.5):
		return { "ok": false, "error": "Start %s, mid-ease %s; want 1.0 and a value between 1.0 and 1.5; premise failed" % [start, mid] }
	if not is_equal_approx(end, 2.0):
		return { "ok": false, "error": "Two quick Z presses from 1.0 ended at %s, want 2.0" % end }
	return { "ok": true }


# The instant camera move (animated = false) must release a running tween's input hold and stop
# a running ease, or input stays locked and the ease pulls the zoom away.
static func _t_instant_camera_move_releases_input() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	# Case 1: an instant move while a tween runs.
	shell.call("_animate_camera_to", Vector2(30, 20), Vector2(1.5, 1.5), true)
	var locked := not bool(cam.call("_accepts_manual_input"))
	shell.call("_animate_camera_to", Vector2.ZERO, Vector2(1.0, 1.0), false)
	var tw: Tween = shell.get("_camera_tween")
	if tw != null and tw.is_valid():
		tw.custom_step(1.0)
	_push_key_z(vp)
	_settle(cam)
	if not locked:
		errors.append("The tween did not hold input; premise failed")
	if not is_equal_approx(cam.zoom.x, 1.5):
		errors.append("After an instant move during a tween, Z gave %s, want 1.5 (input stayed locked)" % cam.zoom.x)
	# Case 2: an instant move while a Z ease runs.
	_push_key_z(vp)
	cam._process(0.05)
	var easing := float(cam.get("_zoom_target")) > 0.0
	shell.call("_animate_camera_to", Vector2.ZERO, Vector2(1.0, 1.0), false)
	_settle(cam)
	var after := cam.zoom.x
	vp.free()
	if not easing:
		errors.append("No ease was running before the instant move; premise failed")
	if not is_equal_approx(after, 1.0):
		errors.append("An ease kept running after the instant move to 1.0 (zoom %s)" % after)
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Ctrl+Z, Cmd+Z (meta) and Alt+Z are shortcuts such as undo; only a plain Z cycles the zoom.
static func _t_modified_z_does_not_zoom() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	for modifier in ["ctrl", "meta", "alt"]:
		var z0 := cam.zoom_goal()
		for pressed in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = KEY_Z
			ev.physical_keycode = KEY_Z
			ev.pressed = pressed
			ev.ctrl_pressed = modifier == "ctrl"
			ev.meta_pressed = modifier == "meta"
			ev.alt_pressed = modifier == "alt"
			vp.push_input(ev, true)
		_settle(cam)
		if cam.zoom != z0:
			errors.append("%s+Z zoomed (%s -> %s)" % [modifier, z0, cam.zoom])
	_push_key_z(vp)
	_settle(cam)
	var plain := cam.zoom.x
	vp.free()
	if not is_equal_approx(plain, 2.5):
		errors.append("Plain Z gave %s, want 2.5; premise failed" % plain)
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Where a world point is drawn in the viewport under the current Sanctum camera.
static func _sanctum_world_to_screen(shell: SanctumShell, cam: BoardCameraController, world: Vector2) -> Vector2:
	cam.force_update_scroll()
	return shell.spatial_view.get_global_transform_with_canvas() * world


static func _t_sanctum_wheel_zooms_toward_pointer() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	shell.set_snapshot(_echo_occupant_snapshot(2, ["echo_a"]))
	SanctumLayoutTests._force_control_layout(shell)
	cam.zoom = Vector2(1.0, 1.0)
	cam.position = Vector2.ZERO
	var pointer := _BOARD_POINT + Vector2(60, 40)
	var world := shell.spatial_view.get_global_transform_with_canvas().affine_inverse() * pointer
	_push_wheel_notch_at(vp, pointer, true)
	var worst := 0.0
	for i in range(20):
		cam._process(0.05)
		worst = maxf(worst, _sanctum_world_to_screen(shell, cam, world).distance_to(pointer))
	var z := cam.zoom.x
	vp.free()
	if not is_equal_approx(z, 1.1):
		return { "ok": false, "error": "One notch from 1.0 gave %s, want 1.1; premise failed" % z }
	if worst > 0.5:
		return { "ok": false, "error": "World point under the cursor drifted %s px during the wheel ease" % worst }
	return { "ok": true }


static func _push_wheel_notch_at(vp: SubViewport, pos: Vector2, up: bool) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	vp.push_input(mm, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.factor = 1.0
		ev.pressed = pressed
		vp.push_input(ev, true)


# Two real Sanctum scroll panels: the board view's party list and the notification body. A wheel
# over each scrolls it and does not zoom the board.
static func _t_sanctum_wheel_scrolls_panels_not_board() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var shell := fx["shell"] as SanctumShell
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	var slots: Array = []
	for i in range(8):
		slots.append({ "name": "Echo %d" % i, "standing": 1, "step": 1, "emotional_status": "Steady" })
	shell.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 2 }, "data": { "party_slots": slots }, "actions": {} })
	var screen := shell.get_node("UILayer/Control/OverlayRoot").get_child(0)
	screen.call("_sync_party_scroll_height")
	SanctumLayoutTests._force_control_layout(shell)
	var party := screen.get_node_or_null("%PartyScroll") as ScrollContainer
	if party == null or not party.is_visible_in_tree() or party.get_v_scroll_bar().max_value <= party.get_v_scroll_bar().page:
		errors.append("Party list missing, hidden or not overflowing; premise failed")
	else:
		var z0 := cam.zoom_goal()
		var before := party.scroll_vertical
		_push_wheel_notch_at(vp, party.get_global_rect().get_center(), false)
		_settle(cam)
		if party.scroll_vertical <= before:
			errors.append("Wheel over the party list did not scroll it")
		if cam.zoom != z0 or cam.zoom_goal() != z0:
			errors.append("Wheel over the party list zoomed the board (%s -> %s)" % [z0, cam.zoom])
	shell.push_notification({
		"id": "board_camera.wheel_scroll", "title": "Scroll fixture",
		"body": "A long line for the scroll body. ".repeat(60), "detail": "More text below the fold. ".repeat(60),
		"amount": "", "tone": "positive", "auto_dismiss": false, "blocking_overlay": false,
	})
	SanctumLayoutTests._force_control_layout(shell)
	var body := shell.get_node_or_null("%NotificationBodyScroll") as ScrollContainer
	if body == null or not body.is_visible_in_tree() or body.get_v_scroll_bar().max_value <= body.get_v_scroll_bar().page:
		errors.append("Notification body missing, hidden or not overflowing; premise failed")
	else:
		var z1 := cam.zoom_goal()
		var before_body := body.scroll_vertical
		_push_wheel_notch_at(vp, body.get_global_rect().get_center(), false)
		_settle(cam)
		if body.scroll_vertical <= before_body:
			errors.append("Wheel over the notification body did not scroll it")
		if cam.zoom != z1 or cam.zoom_goal() != z1:
			errors.append("Wheel over the notification body zoomed the board (%s -> %s)" % [z1, cam.zoom])
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# The wheel leaves a zoom between levels; Z then goes to the first level above it.
static func _t_sanctum_wheel_then_z_goes_to_next_level() -> Dictionary:
	var fx := _make_fixture()
	if fx.is_empty():
		return { "ok": false, "error": "Ready fixture host unavailable" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	_push_wheel_notch(vp, false)
	_settle(cam)
	var after_wheel := cam.zoom.x
	_push_key_z(vp)
	_settle(cam)
	var after_z := cam.zoom.x
	vp.free()
	if not is_equal_approx(after_wheel, 2.0 / 1.1):
		return { "ok": false, "error": "One notch out from 2.0 gave %s, want %s; premise failed" % [after_wheel, 2.0 / 1.1] }
	if not is_equal_approx(after_z, 2.0):
		return { "ok": false, "error": "Z after the wheel (%s) went to %s, want the next level 2.0" % [after_wheel, after_z] }
	return { "ok": true }

