extends RefCounted
class_name StageCameraSelectTests

# Shared board camera on Stage Exploration (decisions.md #100-#103). Each fixture is a real stage:
# FlowRuntime in flow.stage_explore, snapshots from StageExploreSnapshotBuilder, routed through the
# real RealmShell into the real StageExploreScreen. Input goes through SubViewport.push_input(), so
# Godot's GUI routing decides which node gets each press. RealmShell sits in a layer-10 CanvasLayer,
# as in AppRoot.tscn, so the camera moves only the board and not the chrome.

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")

const _VIEW := Vector2i(1280, 720)
const _CENTER := Vector2(640, 360)
const _LAYOUT := { "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1280, 720) }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("stage_camera/preview_has_no_camera_and_keeps_fade_and_begin_zoom", Callable(StageCameraSelectTests, "_t_preview_has_no_camera_and_keeps_fade_and_begin_zoom"))
	runner.register_test("stage_camera/preview_ignores_taps_and_wheel",         Callable(StageCameraSelectTests, "_t_preview_ignores_taps_and_wheel"))
	runner.register_test("stage_camera/explore_entry_centres_party_free_default_zoom", Callable(StageCameraSelectTests, "_t_explore_entry_centres_party_free_default_zoom"))
	runner.register_test("stage_camera/tap_party_locks_and_follows",            Callable(StageCameraSelectTests, "_t_tap_party_locks_and_follows"))
	runner.register_test("stage_camera/tap_revealed_situation_locks_and_follows", Callable(StageCameraSelectTests, "_t_tap_revealed_situation_locks_and_follows"))
	runner.register_test("stage_camera/tap_resolved_situation_locks_and_follows", Callable(StageCameraSelectTests, "_t_tap_resolved_situation_locks_and_follows"))
	runner.register_test("stage_camera/tap_uses_viewport_point_when_screen_is_offset", Callable(StageCameraSelectTests, "_t_tap_uses_viewport_point_when_screen_is_offset"))
	runner.register_test("stage_camera/party_wins_a_shared_cell",               Callable(StageCameraSelectTests, "_t_party_wins_a_shared_cell"))
	runner.register_test("stage_camera/tap_empty_board_releases_to_free",       Callable(StageCameraSelectTests, "_t_tap_empty_board_releases_to_free"))
	runner.register_test("stage_camera/unknown_and_unrevealed_ids_are_ignored", Callable(StageCameraSelectTests, "_t_unknown_and_unrevealed_ids_are_ignored"))
	runner.register_test("stage_camera/echo_card_tap_locks_the_party",          Callable(StageCameraSelectTests, "_t_echo_card_tap_locks_the_party"))
	runner.register_test("stage_camera/echo_card_tap_survives_a_stage_snapshot", Callable(StageCameraSelectTests, "_t_echo_card_tap_survives_a_stage_snapshot"))
	runner.register_test("stage_camera/echo_card_drag_does_not_lock_the_party", Callable(StageCameraSelectTests, "_t_echo_card_drag_does_not_lock_the_party"))
	runner.register_test("stage_camera/advance_locks_party_and_follows_the_drawn_token", Callable(StageCameraSelectTests, "_t_advance_locks_party_and_follows_the_drawn_token"))
	runner.register_test("stage_camera/lock_stays_after_the_walk",              Callable(StageCameraSelectTests, "_t_lock_stays_after_the_walk"))
	runner.register_test("stage_camera/manual_pan_holds_then_follow_resumes",   Callable(StageCameraSelectTests, "_t_manual_pan_holds_then_follow_resumes"))
	runner.register_test("stage_camera/drag_pans_one_to_one_and_is_not_a_tap",  Callable(StageCameraSelectTests, "_t_drag_pans_one_to_one_and_is_not_a_tap"))
	runner.register_test("stage_camera/space_click_is_not_a_tap",               Callable(StageCameraSelectTests, "_t_space_click_is_not_a_tap"))
	runner.register_test("stage_camera/two_finger_pinch_does_not_pan_or_tap",   Callable(StageCameraSelectTests, "_t_two_finger_pinch_does_not_pan_or_tap"))
	runner.register_test("stage_camera/wheel_steps_eased_and_zooms_toward_pointer", Callable(StageCameraSelectTests, "_t_wheel_steps_eased_and_zooms_toward_pointer"))
	runner.register_test("stage_camera/wheel_over_echo_bar_and_action_bar_does_not_zoom", Callable(StageCameraSelectTests, "_t_wheel_over_echo_bar_and_action_bar_does_not_zoom"))
	runner.register_test("stage_camera/z_steps_through_levels",                 Callable(StageCameraSelectTests, "_t_z_steps_through_levels"))
	runner.register_test("stage_camera/pinch_zooms_toward_pointer",             Callable(StageCameraSelectTests, "_t_pinch_zooms_toward_pointer"))
	runner.register_test("stage_camera/focus_loss_resets_stuck_pointer",        Callable(StageCameraSelectTests, "_t_focus_loss_resets_stuck_pointer"))
	runner.register_test("stage_camera/hide_resets_stuck_pointer",              Callable(StageCameraSelectTests, "_t_hide_resets_stuck_pointer"))
	runner.register_test("stage_camera/new_stage_entry_resets_stuck_pointer",   Callable(StageCameraSelectTests, "_t_new_stage_entry_resets_stuck_pointer"))
	runner.register_test("stage_camera/hidden_stage_takes_no_input_in_both_boot_orders", Callable(StageCameraSelectTests, "_t_hidden_stage_takes_no_input_in_both_boot_orders"))
	runner.register_test("stage_camera/shell_swap_hands_viewport_to_shown_camera", Callable(StageCameraSelectTests, "_t_shell_swap_hands_viewport_to_shown_camera"))
	runner.register_test("stage_camera/combat_swap_and_new_stage_start_free",   Callable(StageCameraSelectTests, "_t_combat_swap_and_new_stage_start_free"))
	runner.register_test("stage_camera/parked_refresh_keeps_manual_view",       Callable(StageCameraSelectTests, "_t_parked_refresh_keeps_manual_view"))
	runner.register_test("stage_camera/live_resize_keeps_focus_point",          Callable(StageCameraSelectTests, "_t_live_resize_keeps_focus_point"))
	runner.register_test("stage_camera/hidden_screen_disables_camera_and_world", Callable(StageCameraSelectTests, "_t_hidden_screen_disables_camera_and_world"))
	runner.register_test("stage_camera/parked_refresh_during_walk_keeps_token_and_target", Callable(StageCameraSelectTests, "_t_parked_refresh_during_walk_keeps_token_and_target"))
	runner.register_test("stage_camera/tap_on_chrome_bar_gaps_keeps_the_lock", Callable(StageCameraSelectTests, "_t_tap_on_chrome_bar_gaps_keeps_the_lock"))
	runner.register_test("stage_camera/modal_blocks_board_input",               Callable(StageCameraSelectTests, "_t_modal_blocks_board_input"))
	runner.register_test("stage_camera/bark_anchor_tracks_party_on_screen",     Callable(StageCameraSelectTests, "_t_bark_anchor_tracks_party_on_screen"))


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

static func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null


static func _runtime(env: Dictionary) -> FlowRuntime:
	return env["runtime"] as FlowRuntime


static func _snapshot(env: Dictionary, t: int = 1) -> Dictionary:
	return StageExploreSnapshotBuilder.build(_runtime(env).flow_ctx, t)


static func _make_fixture(tag: String, advance_first: bool = false) -> Dictionary:
	var host := _host()
	if host == null:
		return {}
	var env := FlowSnapshotFingerprintTests._setup_stage_explore_env("stage_camera_" + tag)
	if not bool(env.get("ok", false)):
		return {}
	if advance_first:
		_runtime(env).dispatch({ "type": "stage.advance_turn" })
	var snap := _snapshot(env)
	if str(snap.get("type", "")) != "flow.stage_explore":
		return {}
	var vp := SubViewport.new()
	vp.size = _VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var layer := CanvasLayer.new()
	layer.layer = 10
	vp.add_child(layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	layer.add_child(realm)
	realm.set_layout(_LAYOUT)
	realm.set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(realm)
	var stage := realm.get("_active_overlay") as StageExploreScreen
	if stage == null:
		vp.free()
		return {}
	return { "env": env, "viewport": vp, "realm": realm, "stage": stage, "camera": stage.camera, "snap": snap, "t": 1 }


# Same screen in preview mode, from the hand-built preview snapshot the seam tests use.
static func _make_preview_fixture() -> Dictionary:
	var host := _host()
	if host == null:
		return {}
	var vp := SubViewport.new()
	vp.size = _VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var layer := CanvasLayer.new()
	layer.layer = 10
	vp.add_child(layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	layer.add_child(realm)
	realm.set_layout(_LAYOUT)
	realm.set_snapshot(Stage004SeamTests._stage_preview_banner_snapshot(false))
	SanctumLayoutTests._force_control_layout(realm)
	var stage := realm.get("_active_overlay") as StageExploreScreen
	if stage == null:
		vp.free()
		return {}
	return { "viewport": vp, "realm": realm, "stage": stage, "camera": stage.camera }


# Rebuilds the snapshot with the production builder and routes it through RealmShell.
static func _refresh(fx: Dictionary) -> void:
	fx["t"] = int(fx["t"]) + 1
	var snap := _snapshot(fx["env"], int(fx["t"]))
	fx["snap"] = snap
	(fx["realm"] as RealmShell).set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(fx["realm"])


static func _advance(fx: Dictionary) -> void:
	_runtime(fx["env"]).dispatch({ "type": "stage.advance_turn" })
	_refresh(fx)


static func _data(fx: Dictionary) -> Dictionary:
	return (fx["snap"] as Dictionary)["data"]


static func _cell_of(pos: Dictionary) -> Vector2i:
	return Vector2i(int(pos.get("col", 0)), int(pos.get("row", 0)))


static func _party_cell(fx: Dictionary) -> Vector2i:
	return _cell_of(_data(fx)["party_pos"])


static func _board(fx: Dictionary) -> TileMapLayer:
	return (fx["stage"] as StageExploreScreen).get("_board") as TileMapLayer


static func _cell_world(fx: Dictionary, cell: Vector2i) -> Vector2:
	var board := _board(fx)
	return board.to_global(board.map_to_local(cell))


# Where a cell is drawn on screen, through the real canvas transform.
static func _cell_viewport(fx: Dictionary, cell: Vector2i) -> Vector2:
	(fx["camera"] as BoardCameraController).force_update_scroll()
	var board := _board(fx)
	return board.get_global_transform_with_canvas() * board.map_to_local(cell)


# Places the camera so the cell is drawn at `screen_offset` from the viewport centre. Open board
# around the centre is free of Stage chrome, so a press there reaches the screen root.
static func _frame_cell(fx: Dictionary, cell: Vector2i, screen_offset: Vector2) -> Vector2:
	var cam := fx["camera"] as BoardCameraController
	cam.position = _cell_world(fx, cell) - screen_offset / cam.zoom.x
	cam.force_update_scroll()
	return _cell_viewport(fx, cell)


# Runs camera follow, token animation and bark anchoring for `seconds` in 0.05 s frames. A running
# travel tween is stepped too, the way SceneTree would.
static func _step(fx: Dictionary, seconds: float) -> void:
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	var party := stage.get("_party_layer") as Node2D
	for i in range(int(ceil(seconds / 0.05))):
		var tween := stage.get("_travel_tween") as Tween
		if tween != null and tween.is_valid() and tween.is_running():
			tween.custom_step(0.05)
		cam._process(0.05)
		cam.force_update_scroll()
		party._process(0.05)
		stage._process(0.05)


static func _hovered_is_stage(fx: Dictionary, point: Vector2) -> bool:
	var vp := fx["viewport"] as SubViewport
	var mm := InputEventMouseMotion.new()
	mm.position = point
	mm.global_position = point
	vp.push_input(mm, true)
	return vp.gui_get_hovered_control() == fx["stage"]


static func _mouse_mode_ok(cam: BoardCameraController, mode: int, target: String) -> bool:
	return cam.mode == mode and cam.target_id == target


# Taps the target cell off-centre, then checks lock, target and that the follow brings it to the
# viewport centre. Returns "" on success.
static func _check_tap_locks_and_follows(fx: Dictionary, cell: Vector2i, want_target: String, label: String) -> String:
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var tap_point := _frame_cell(fx, cell, Vector2(160, 60))
	if not tap_point.is_equal_approx(_CENTER + Vector2(160, 60)):
		return "%s framed at %s, expected %s; board does not follow the camera" % [label, tap_point, _CENTER + Vector2(160, 60)]
	if not _hovered_is_stage(fx, tap_point):
		return "%s tap point is covered by a control; premise failed" % label
	CombatCameraSelectTests._tap(vp, tap_point)
	if not _mouse_mode_ok(cam, BoardCameraController.Mode.FOLLOW_ACTOR, want_target):
		return "Tapping the %s did not lock the camera (mode %d, target '%s', want '%s')" % [label, cam.mode, cam.target_id, want_target]
	_step(fx, 4.0)
	var drawn := _cell_viewport(fx, cell)
	if drawn.distance_to(_CENTER) > 2.0:
		return "Locked camera did not bring the %s to the centre (drawn at %s)" % [label, drawn]
	return ""


static func _fail(fx: Dictionary, msg: String) -> Dictionary:
	(fx["viewport"] as SubViewport).free()
	return { "ok": false, "error": msg }


static func _no_fixture() -> Dictionary:
	return { "ok": false, "error": "Fixture failed" }


# The first revealed situation of the snapshot, as { id, cell }, or {}.
static func _first_situation(fx: Dictionary) -> Dictionary:
	for sit_v in _data(fx).get("situations", []):
		var sit: Dictionary = sit_v
		if bool(sit.get("revealed", false)):
			return { "id": str(sit.get("id", "")), "cell": _cell_of(sit.get("pos", {})) }
	return {}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Preview has no camera. BoardRoot is fitted to the safe body, fades in with the screen (a Control
# modulate does not reach the CanvasLayer), and Begin zooms BoardRoot x3.
static func _t_preview_has_no_camera_and_keeps_fade_and_begin_zoom() -> Dictionary:
	var fx := _make_preview_fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var stage := fx["stage"] as StageExploreScreen
	var cam := fx["camera"] as BoardCameraController
	var board_root := stage.get_node("%BoardRoot") as Node2D
	var world := stage.get_node("WorldLayer") as CanvasLayer
	var errors: Array = []
	if cam.enabled or vp.get_camera_2d() == cam:
		errors.append("preview left the camera on")
	if not world.visible:
		errors.append("preview hides the world layer")
	var party_layer := stage.get_node("%PartyTokenLayer") as Node2D
	if not is_equal_approx(float(party_layer.get("_token_scale")), 1.0 / maxf(board_root.scale.x, 0.0001)):
		errors.append("preview token is not kept at its screen size (token scale %s)" % party_layer.get("_token_scale"))
	var preview_scale := float(stage.get("_preview_scale"))
	if preview_scale <= 0.0 or not board_root.scale.is_equal_approx(Vector2(preview_scale, preview_scale)):
		errors.append("preview did not fit BoardRoot (scale %s, preview scale %s)" % [board_root.scale, preview_scale])
	if not is_equal_approx(stage.modulate.a, 0.0) or not is_equal_approx(board_root.modulate.a, 0.0):
		errors.append("preview fade did not start from 0 on both the screen (%s) and the board (%s)" % [stage.modulate.a, board_root.modulate.a])
	var fade := stage.get("_preview_fade_tween") as Tween
	if fade == null or not fade.is_valid():
		errors.append("preview has no fade tween")
	else:
		fade.custom_step(1.0)
		if not is_equal_approx(stage.modulate.a, 1.0) or not is_equal_approx(board_root.modulate.a, 1.0):
			errors.append("preview fade did not end at 1 on both the screen (%s) and the board (%s)" % [stage.modulate.a, board_root.modulate.a])
	var emitted: Array = []
	stage.action_requested.connect(func(action: Dictionary) -> void: emitted.append(action))
	var start_pos := board_root.position
	var centre := stage.get("_preview_center") as Vector2
	stage.call("_on_begin_pressed")
	var transition := stage.get("_preview_transition_tween") as Tween
	if transition == null:
		errors.append("Begin created no zoom tween")
	else:
		transition.custom_step(1.0)
		var want_scale := preview_scale * 3.0
		var want_pos := centre - (centre - start_pos) * 3.0
		if not board_root.scale.is_equal_approx(Vector2(want_scale, want_scale)) or not board_root.position.is_equal_approx(want_pos):
			errors.append("Begin zoom ended at scale %s position %s, want %s and %s" % [board_root.scale, board_root.position, want_scale, want_pos])
	if cam.enabled:
		errors.append("the camera came on during the Begin zoom")
	if emitted.size() != 1 or str((emitted[0] as Dictionary).get("slot", "")) != "cta.start":
		errors.append("Begin did not emit cta.start once: %s" % [emitted])
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# The camera is off in preview, so a tap, a wheel notch and Z change nothing there.
static func _t_preview_ignores_taps_and_wheel() -> Dictionary:
	var fx := _make_preview_fixture()
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var stage := fx["stage"] as StageExploreScreen
	var cam := fx["camera"] as BoardCameraController
	var board_root := stage.get_node("%BoardRoot") as Node2D
	var scale_before := board_root.scale
	var pos_before := board_root.position
	var zoom_before := cam.zoom
	CombatCameraSelectTests._tap(vp, _CENTER)
	CombatCameraSelectTests._push_wheel(vp, _CENTER, true)
	CombatCameraSelectTests._push_z(vp)
	var mode := cam.mode
	var unchanged := board_root.scale == scale_before and board_root.position == pos_before and cam.zoom == zoom_before
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A tap in preview locked the camera (mode %d)" % mode }
	if not unchanged:
		return { "ok": false, "error": "Wheel, Z or a tap moved the preview board" }
	return { "ok": true }


# Preview, then explore: the first view centres on the party at the default zoom, FREE, BoardRoot
# back at scale 1 on the world origin.
static func _t_explore_entry_centres_party_free_default_zoom() -> Dictionary:
	var fx := _make_fixture("entry")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var stage := fx["stage"] as StageExploreScreen
	var cam := fx["camera"] as BoardCameraController
	var errors: Array = []
	if not cam.enabled or vp.get_camera_2d() != cam:
		errors.append("explore did not make its camera the viewport camera")
	if cam.mode != BoardCameraController.Mode.FREE:
		errors.append("explore started with camera mode %d, want FREE" % cam.mode)
	if not is_equal_approx(cam.zoom.x, 1.3):
		errors.append("default zoom is %s, want 1.3" % cam.zoom.x)
	var drawn := _cell_viewport(fx, _party_cell(fx))
	if drawn.distance_to(_CENTER) > 1.0:
		errors.append("party drawn at %s, want the viewport centre" % drawn)
	var board_root := stage.get_node("%BoardRoot") as Node2D
	if board_root.scale != Vector2.ONE:
		errors.append("BoardRoot scale is %s in explore, want 1" % board_root.scale)
	# From a preview: Begin zoom leaves BoardRoot scaled; the explore snapshot must undo it.
	cam.select("party")
	stage.set_snapshot(Stage004SeamTests._stage_preview_banner_snapshot(false))
	board_root.scale = Vector2(2.7, 2.7)
	stage.set_snapshot(fx["snap"])
	if cam.mode != BoardCameraController.Mode.FREE:
		errors.append("explore after preview kept a stale lock (mode %d)" % cam.mode)
	if not is_equal_approx(float(stage.get_node("%PartyTokenLayer").get("_token_scale")), 1.0):
		errors.append("explore kept the preview token scale")
	var visual := stage.call("_preview_visual_rect", int(_data(fx)["map_width"]), int(_data(fx)["map_height"])) as Rect2
	if not board_root.position.is_equal_approx(-visual.get_center()):
		errors.append("BoardRoot is not centred on the world origin (position %s, want %s)" % [board_root.position, -visual.get_center()])
	if board_root.scale != Vector2.ONE or not cam.enabled:
		errors.append("explore after preview left BoardRoot scale %s, camera enabled %s" % [board_root.scale, cam.enabled])
	if not is_equal_approx(cam.zoom.x, 1.3) or cam.mode != BoardCameraController.Mode.FREE:
		errors.append("explore after preview did not restart FREE at 1.3 (zoom %s, mode %d)" % [cam.zoom.x, cam.mode])
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_tap_party_locks_and_follows() -> Dictionary:
	var fx := _make_fixture("tap_party")
	if fx.is_empty():
		return _no_fixture()
	var err := _check_tap_locks_and_follows(fx, _party_cell(fx), "party", "party")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_tap_revealed_situation_locks_and_follows() -> Dictionary:
	var fx := _make_fixture("tap_sit", true)
	if fx.is_empty():
		return _no_fixture()
	var sit := _first_situation(fx)
	if sit.is_empty():
		return _fail(fx, "No revealed situation after the advance; premise failed")
	var err := _check_tap_locks_and_follows(fx, sit["cell"], str(sit["id"]), "situation")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


# A resolved situation stays revealed on the map, so it can be tapped like any other.
static func _t_tap_resolved_situation_locks_and_follows() -> Dictionary:
	var fx := _make_fixture("tap_resolved", true)
	if fx.is_empty():
		return _no_fixture()
	var sit := _first_situation(fx)
	if sit.is_empty():
		return _fail(fx, "No revealed situation after the advance; premise failed")
	var ctx := _runtime(fx["env"]).flow_ctx
	var stage_dict := FlowStageExploreState._get_current_stage(ctx)
	var explore_map: Dictionary = stage_dict.get("explore_map", {})
	for s_v in explore_map.get("situations", []):
		var s: Dictionary = s_v
		if str(s.get("id", "")) == str(sit["id"]):
			s["resolved"] = true
	FlowStageExploreState._write_stage_back(ctx, stage_dict)
	_refresh(fx)
	var resolved := false
	for s_v in _data(fx).get("situations", []):
		if str((s_v as Dictionary).get("id", "")) == str(sit["id"]):
			resolved = bool((s_v as Dictionary).get("resolved", false))
	if not resolved:
		return _fail(fx, "The situation is not resolved in the snapshot; premise failed")
	var err := _check_tap_locks_and_follows(fx, sit["cell"], str(sit["id"]), "resolved situation")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


# The tracker reports the position local to the screen. The tap must select with the viewport point,
# so a Stage that does not start at the viewport origin still hits the right cell.
static func _t_tap_uses_viewport_point_when_screen_is_offset() -> Dictionary:
	var fx := _make_fixture("offset")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	stage.position += Vector2(100, 0)
	var point := _frame_cell(fx, _party_cell(fx), Vector2(160, 60))
	if not is_equal_approx(point.x - (point.x - stage.get_global_transform_with_canvas().origin.x), 100.0):
		return _fail(fx, "The screen is not offset by 100; premise failed")
	CombatCameraSelectTests._tap(vp, point)
	var mouse_ok := _mouse_mode_ok(cam, BoardCameraController.Mode.FOLLOW_ACTOR, "party")
	cam.deselect()
	CombatCameraSelectTests._push_touch(vp, 0, point, true)
	CombatCameraSelectTests._push_touch(vp, 0, point, false)
	var touch_ok := _mouse_mode_ok(cam, BoardCameraController.Mode.FOLLOW_ACTOR, "party")
	vp.free()
	if not mouse_ok:
		return { "ok": false, "error": "A mouse tap on the party of an offset screen did not lock it" }
	if not touch_ok:
		return { "ok": false, "error": "A touch tap on the party of an offset screen did not lock it" }
	return { "ok": true }


# A revealed situation on the party's cell: the tap goes to the party.
static func _t_party_wins_a_shared_cell() -> Dictionary:
	var fx := _make_fixture("shared_cell", true)
	if fx.is_empty():
		return _no_fixture()
	var sit := _first_situation(fx)
	if sit.is_empty():
		return _fail(fx, "No revealed situation after the advance; premise failed")
	var ctx := _runtime(fx["env"]).flow_ctx
	var stage_dict := FlowStageExploreState._get_current_stage(ctx)
	var explore_map: Dictionary = stage_dict.get("explore_map", {})
	for s_v in explore_map.get("situations", []):
		var s: Dictionary = s_v
		if str(s.get("id", "")) == str(sit["id"]):
			s["pos"] = (explore_map["party_pos"] as Dictionary).duplicate()
	FlowStageExploreState._write_stage_back(ctx, stage_dict)
	_refresh(fx)
	var moved := _first_situation(fx)
	if moved.is_empty() or moved["cell"] != _party_cell(fx):
		return _fail(fx, "Situation is not on the party's cell; premise failed")
	var err := _check_tap_locks_and_follows(fx, _party_cell(fx), "party", "shared cell")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_tap_empty_board_releases_to_free() -> Dictionary:
	var fx := _make_fixture("tap_empty")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var err := _check_tap_locks_and_follows(fx, _party_cell(fx), "party", "party")
	if not err.is_empty():
		return _fail(fx, err)
	var empty_point := _CENTER + Vector2(-260, -130)
	var cell := _board(fx).local_to_map(_board(fx).get_global_transform_with_canvas().affine_inverse() * empty_point)
	if cell == _party_cell(fx) or not _hovered_is_stage(fx, empty_point):
		return _fail(fx, "Empty point is not open board; premise failed")
	CombatCameraSelectTests._tap(vp, empty_point)
	var mode := cam.mode
	var target := cam.target_id
	var before := cam.position
	_step(fx, 2.0)
	var still := cam.position == before
	vp.free()
	if mode != BoardCameraController.Mode.FREE or not target.is_empty():
		return { "ok": false, "error": "Empty-board tap left the camera locked (mode %d, target '%s')" % [mode, target] }
	if not still:
		return { "ok": false, "error": "FREE camera kept moving after the empty-board tap" }
	return { "ok": true }


static func _t_unknown_and_unrevealed_ids_are_ignored() -> Dictionary:
	var fx := _make_fixture("bad_ids", true)
	if fx.is_empty():
		return _no_fixture()
	var stage := fx["stage"] as StageExploreScreen
	var cam := fx["camera"] as BoardCameraController
	# A situation of the map that the snapshot does not carry yet is unrevealed.
	var ctx := _runtime(fx["env"]).flow_ctx
	var explore_map: Dictionary = FlowStageExploreState._get_current_stage(ctx).get("explore_map", {})
	var shown: Dictionary = {}
	for s_v in _data(fx).get("situations", []):
		shown[str((s_v as Dictionary).get("id", ""))] = true
	var hidden_id := ""
	for s_v in explore_map.get("situations", []):
		var sit_id := str((s_v as Dictionary).get("id", ""))
		if not shown.has(sit_id):
			hidden_id = sit_id
			break
	if hidden_id.is_empty():
		return _fail(fx, "Every situation is revealed; premise failed")
	for bad in ["sit.does_not_exist", hidden_id, "echo_0001"]:
		stage.select_board_target(bad)
		if cam.mode != BoardCameraController.Mode.FREE or not cam.target_id.is_empty():
			return _fail(fx, "select_board_target('%s') changed the camera (mode %d, target '%s')" % [bad, cam.mode, cam.target_id])
	(fx["viewport"] as SubViewport).free()
	return { "ok": true }


# ANSWERS.md #77 on Stage: every card carries id "" and means the party.
static func _t_echo_card_tap_locks_the_party() -> Dictionary:
	var fx := _make_fixture("card")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var realm := fx["realm"] as RealmShell
	var cards: Array = []
	for child in (realm.get_node("%EchoBar") as HBoxContainer).get_children():
		if not child.is_queued_for_deletion():
			cards.append(child)
	if cards.is_empty():
		return _fail(fx, "Echo bar has no cards; premise failed")
	var point := (cards[0] as Control).get_global_rect().get_center()
	CombatCameraSelectTests._tap(vp, point)
	var mode := cam.mode
	var target := cam.target_id
	vp.free()
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != "party":
		return { "ok": false, "error": "Card tap gave mode %d target '%s', want the party" % [mode, target] }
	return { "ok": true }


# Stage cards carry no id. A snapshot between the press and the release keeps the card (matched by
# position), so the tap still locks the party.
static func _t_echo_card_tap_survives_a_stage_snapshot() -> Dictionary:
	var fx := _make_fixture("card_snap")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var realm := fx["realm"] as RealmShell
	var card := ((realm.get_node("%EchoBar") as Node).get_children()[0]) as EchoCardItem
	var point := card.get_global_rect().get_center()
	var counter := CombatCameraSelectTests._Count.new()
	card.card_pressed.connect(counter.on_signal)
	CombatCameraSelectTests._push_left_button(vp, point, true)
	_refresh(fx)
	CombatCameraSelectTests._frame_end(realm)
	CombatCameraSelectTests._push_left_button(vp, point, false)
	var signals := counter.n
	var mode := cam.mode
	var target := cam.target_id
	vp.free()
	if signals != 1 or mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != "party":
		return { "ok": false, "error": "A snapshot between press and release lost the Stage card tap (signals %d, mode %d, target '%s')" % [signals, mode, target] }
	return { "ok": true }


# A press on a Stage card selects nothing; a drag that starts on it selects nothing; a tap selects on release.
static func _t_echo_card_drag_does_not_lock_the_party() -> Dictionary:
	var fx := _make_fixture("card_drag")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var cards: Array = []
	for child in ((fx["realm"] as RealmShell).get_node("%EchoBar") as HBoxContainer).get_children():
		if not child.is_queued_for_deletion():
			cards.append(child)
	if cards.is_empty():
		return _fail(fx, "Echo bar has no cards; premise failed")
	var point := (cards[0] as Control).get_global_rect().get_center()
	CombatCameraSelectTests._push_left_button(vp, point, true)
	var after_press := cam.mode
	CombatCameraSelectTests._push_motion(vp, point + Vector2(30, 0), Vector2(30, 0))
	CombatCameraSelectTests._push_left_button(vp, point + Vector2(30, 0), false)
	var after_drag := cam.mode
	CombatCameraSelectTests._tap(vp, point)
	var after_tap := cam.mode
	vp.free()
	if after_press != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A press on a card locked the party before the release" }
	if after_drag != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A drag that started on a card locked the party" }
	if after_tap != BoardCameraController.Mode.FOLLOW_ACTOR:
		return { "ok": false, "error": "A tap on a card did not lock the party" }
	return { "ok": true }


# One Advance: the lock is on at once and the follow target is the drawn token, frame by frame. The
# camera never gets closer to the destination than the token is, and the walk ends centred.
static func _t_advance_locks_party_and_follows_the_drawn_token() -> Dictionary:
	var fx := _make_fixture("walk")
	if fx.is_empty():
		return _no_fixture()
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	_advance(fx)
	var path: Array = _data(fx).get("traveled_path", [])
	if path.is_empty():
		return _fail(fx, "The advance walked no cell; premise failed")
	var errors: Array = []
	if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != "party":
		errors.append("Advance did not lock the party (mode %d, target '%s')" % [cam.mode, cam.target_id])
	var dest := _cell_world(fx, _party_cell(fx))
	var party := stage.get("_party_layer") as Node2D
	var worst_lead := -1e9
	var target_off := 0.0
	var mid_walk := false
	for f in range(60):
		_step(fx, 0.05)
		var drawn := _board(fx).to_global(party.call("display_position") as Vector2)
		worst_lead = maxf(worst_lead, drawn.distance_to(dest) - cam.position.distance_to(dest))
		target_off = maxf(target_off, (cam.get("_follow_target_local") as Vector2).distance_to(drawn))
		if drawn.distance_to(dest) > 1.0:
			mid_walk = true
	if not mid_walk:
		errors.append("The token was never seen mid-walk; premise failed")
	if worst_lead > 0.5:
		errors.append("The camera got %s px closer to the destination than the drawn token" % worst_lead)
	if target_off > 0.01:
		errors.append("The follow target was %s px away from the drawn token" % target_off)
	var dest_cell := _party_cell(fx)
	var drawn_final := _cell_viewport(fx, dest_cell)
	if drawn_final.distance_to(_CENTER) > 2.0:
		errors.append("camera ended with the party drawn at %s, want the centre" % drawn_final)
	var token := (party.call("display_position") as Vector2)
	if token.distance_to(_board(fx).map_to_local(dest_cell)) > 0.5:
		errors.append("party token ended at %s, want the destination cell %s" % [token, _board(fx).map_to_local(dest_cell)])
	(fx["viewport"] as SubViewport).free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


static func _t_lock_stays_after_the_walk() -> Dictionary:
	var fx := _make_fixture("stay")
	if fx.is_empty():
		return _no_fixture()
	var cam := fx["camera"] as BoardCameraController
	_advance(fx)
	_step(fx, 4.0)
	_refresh(fx)
	_step(fx, 1.0)
	var ok_lock := cam.mode == BoardCameraController.Mode.FOLLOW_ACTOR and cam.target_id == "party"
	var drawn := _cell_viewport(fx, _party_cell(fx))
	(fx["viewport"] as SubViewport).free()
	if not ok_lock:
		return { "ok": false, "error": "The lock ended after the walk (mode %d, target '%s')" % [cam.mode, cam.target_id] }
	if drawn.distance_to(_CENTER) > 2.0:
		return { "ok": false, "error": "The party is not centred after the walk (drawn at %s)" % drawn }
	return { "ok": true }


# A manual pan on a locked camera pauses the follow for 3 s, then the lock resumes.
static func _t_manual_pan_holds_then_follow_resumes() -> Dictionary:
	var fx := _make_fixture("hold")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var err := _check_tap_locks_and_follows(fx, _party_cell(fx), "party", "party")
	if not err.is_empty():
		return _fail(fx, err)
	var start := _CENTER + Vector2(-260, -130)
	CombatCameraSelectTests._push_left_button(vp, start, true)
	CombatCameraSelectTests._push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	CombatCameraSelectTests._push_motion(vp, start + Vector2(220, 0), Vector2(200, 0))
	CombatCameraSelectTests._push_left_button(vp, start + Vector2(220, 0), false)
	var held := cam.is_follow_held()
	var panned := cam.position
	_step(fx, 2.5)
	var during := cam.position
	var still_locked := cam.mode == BoardCameraController.Mode.FOLLOW_ACTOR and cam.target_id == "party"
	_step(fx, 4.0)
	var drawn := _cell_viewport(fx, _party_cell(fx))
	vp.free()
	if not held:
		return { "ok": false, "error": "A drag on a locked camera did not start the follow hold" }
	if not panned.is_equal_approx(during):
		return { "ok": false, "error": "Follow resumed inside the 3 s hold (%s -> %s)" % [panned, during] }
	if not still_locked:
		return { "ok": false, "error": "The drag released the lock instead of holding it" }
	if drawn.distance_to(_CENTER) > 2.0:
		return { "ok": false, "error": "Follow did not resume after the hold (party drawn at %s)" % drawn }
	return { "ok": true }


# A press that moves past the threshold pans 1:1 and never selects what was under it.
static func _t_drag_pans_one_to_one_and_is_not_a_tap() -> Dictionary:
	var fx := _make_fixture("drag")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var start := _frame_cell(fx, _party_cell(fx), Vector2.ZERO)
	var before := cam.position
	CombatCameraSelectTests._push_left_button(vp, start, true)
	CombatCameraSelectTests._push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	CombatCameraSelectTests._push_motion(vp, start + Vector2(60, 0), Vector2(40, 0))
	CombatCameraSelectTests._push_left_button(vp, start + Vector2(60, 0), false)
	var mode := cam.mode
	var pan := cam.position - before
	var want := -Vector2(60, 0) / cam.zoom.x
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A drag that started on the party locked it (mode %d)" % mode }
	if not pan.is_equal_approx(want):
		return { "ok": false, "error": "Drag moved the camera by %s, want %s" % [pan, want] }
	return { "ok": true }


static func _t_space_click_is_not_a_tap() -> Dictionary:
	var fx := _make_fixture("space")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _frame_cell(fx, _party_cell(fx), Vector2(160, 60))
	BoardCameraInputTests._set_space_held(true)
	if not Input.is_key_pressed(KEY_SPACE):
		BoardCameraInputTests._set_space_held(false)
		return _fail(fx, "Could not hold Space; premise failed")
	CombatCameraSelectTests._tap(vp, point)
	BoardCameraInputTests._set_space_held(false)
	var mode := cam.mode
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "Space+click on the party locked the camera (mode %d)" % mode }
	return { "ok": true }


static func _t_two_finger_pinch_does_not_pan_or_tap() -> Dictionary:
	var fx := _make_fixture("pinch2")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var a := _frame_cell(fx, _party_cell(fx), Vector2(160, 60))
	var b := a + Vector2(60, 0)
	var before := cam.position
	CombatCameraSelectTests._push_touch(vp, 0, a, true)
	CombatCameraSelectTests._push_touch(vp, 1, b, true)
	for i in range(1, 4):
		CombatCameraSelectTests._push_touch_drag(vp, 0, a - Vector2(10 * i, 0), Vector2(-10, 0))
		CombatCameraSelectTests._push_touch_drag(vp, 1, b + Vector2(10 * i, 0), Vector2(10, 0))
	var moved := cam.position - before
	CombatCameraSelectTests._push_touch(vp, 0, a - Vector2(30, 0), false)
	CombatCameraSelectTests._push_touch(vp, 1, b + Vector2(30, 0), false)
	var mode := cam.mode
	vp.free()
	if not moved.is_zero_approx():
		return { "ok": false, "error": "A two-finger gesture moved the camera by %s" % moved }
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A two-finger gesture counted as a tap (mode %d)" % mode }
	return { "ok": true }


static func _wheel_settled(fx: Dictionary, pos: Vector2, up: bool) -> void:
	CombatCameraSelectTests._push_wheel(fx["viewport"], pos, up)
	_step(fx, 1.0)


# One notch is x1.1, eased. FREE: the world point under the cursor stays under it.
static func _t_wheel_steps_eased_and_zooms_toward_pointer() -> Dictionary:
	var fx := _make_fixture("wheel")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _CENTER + Vector2(-260, -130)
	if not _hovered_is_stage(fx, point):
		return _fail(fx, "Wheel point is not open board; premise failed")
	var z0 := cam.zoom.x
	var world := CombatCameraSelectTests._screen_to_world(fx, point)
	CombatCameraSelectTests._push_wheel(vp, point, true)
	var immediate := cam.zoom.x
	var worst := 0.0
	for i in range(20):
		cam._process(0.05)
		worst = maxf(worst, CombatCameraSelectTests._world_to_screen(fx, world).distance_to(point))
	var z_up := cam.zoom.x
	_wheel_settled(fx, point, false)
	var z_back := cam.zoom.x
	vp.free()
	if not is_equal_approx(z_up, z0 * 1.1):
		return { "ok": false, "error": "Wheel up: zoom %s -> %s, want x1.1" % [z0, z_up] }
	if not is_equal_approx(immediate, z0):
		return { "ok": false, "error": "Wheel zoom jumped instead of easing (%s right after the notch)" % immediate }
	if worst > 0.5:
		return { "ok": false, "error": "The world point drifted %s px from the cursor during the ease" % worst }
	if not is_equal_approx(z_back, z0):
		return { "ok": false, "error": "Wheel down did not undo wheel up (%s, want %s)" % [z_back, z0] }
	return { "ok": true }


# The echo bar and the gaps of the action bar are hovered controls, so the wheel does not zoom.
static func _t_wheel_over_echo_bar_and_action_bar_does_not_zoom() -> Dictionary:
	var fx := _make_fixture("wheel_chrome")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	var bar := stage.get_node("%ActionBar") as Control
	var scroll := (fx["realm"] as RealmShell).get_node("%EchoBarScroll") as ScrollContainer
	var gap := Vector2.INF
	var rect := bar.get_global_rect()
	var x := rect.position.x + 2.0
	while x < rect.end.x:
		var candidate := Vector2(x, rect.get_center().y)
		_hovered_is_stage(fx, candidate)
		if vp.gui_get_hovered_control() == bar:
			gap = candidate
			break
		x += 4.0
	if gap == Vector2.INF:
		return _fail(fx, "The action bar has no gap between its buttons; premise failed")
	var z0 := cam.zoom
	_wheel_settled(fx, gap, true)
	var z_gap := cam.zoom
	_wheel_settled(fx, scroll.get_global_rect().get_center(), true)
	var z_bar := cam.zoom
	vp.free()
	if z_gap != z0:
		return { "ok": false, "error": "Wheel over a gap of the action bar zoomed the board (%s -> %s)" % [z0, z_gap] }
	if z_bar != z0:
		return { "ok": false, "error": "Wheel over the echo bar zoomed the board (%s -> %s)" % [z0, z_bar] }
	return { "ok": true }


# Stage uses Combat's levels: 0.5, 1.0, 1.5, 2.0, 2.2 (clamped). From the default 1.3, Z goes up.
static func _t_z_steps_through_levels() -> Dictionary:
	var fx := _make_fixture("z")
	if fx.is_empty():
		return _no_fixture()
	var cam := fx["camera"] as BoardCameraController
	var got: Array = []
	for i in range(6):
		CombatCameraSelectTests._push_z(fx["viewport"])
		_step(fx, 1.0)
		got.append(snappedf(cam.zoom.x, 0.001))
	(fx["viewport"] as SubViewport).free()
	var want := [1.5, 2.0, 2.2, 0.5, 1.0, 1.5]
	if got != want:
		return { "ok": false, "error": "Z sequence %s, want %s" % [got, want] }
	return { "ok": true }


static func _t_pinch_zooms_toward_pointer() -> Dictionary:
	var fx := _make_fixture("magnify")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _CENTER + Vector2(-260, -130)
	var world := CombatCameraSelectTests._screen_to_world(fx, point)
	var z0 := cam.zoom.x
	var ev := InputEventMagnifyGesture.new()
	ev.position = point
	ev.factor = 1.25
	vp.push_input(ev, true)
	var drawn := CombatCameraSelectTests._world_to_screen(fx, world)
	var z1 := cam.zoom.x
	vp.free()
	if is_equal_approx(z1, z0):
		return { "ok": false, "error": "Pinch did not zoom" }
	if drawn.distance_to(point) > 0.5:
		return { "ok": false, "error": "Pinch moved the world point under the cursor to %s (cursor %s)" % [drawn, point] }
	return { "ok": true }


static func _leave_pointers_stuck(fx: Dictionary) -> void:
	var vp := fx["viewport"] as SubViewport
	var p := _CENTER + Vector2(-260, -130)
	CombatCameraSelectTests._push_touch(vp, 0, p, true)
	CombatCameraSelectTests._push_touch(vp, 1, p + Vector2(40, 0), true)
	CombatCameraSelectTests._push_left_button(vp, p, true)


# After a reset, a tap on the party selects it and a mouse drag on the board pans 1:1.
static func _check_tap_and_drag_work(fx: Dictionary, label: String) -> String:
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	CombatCameraSelectTests._tap(vp, _frame_cell(fx, _party_cell(fx), Vector2(120, 40)))
	if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != "party":
		return "%s: tap did not select (mode %d, target '%s')" % [label, cam.mode, cam.target_id]
	cam.deselect()
	var start := _CENTER + Vector2(-260, -130)
	var before := cam.position
	CombatCameraSelectTests._push_left_button(vp, start, true)
	CombatCameraSelectTests._push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	CombatCameraSelectTests._push_motion(vp, start + Vector2(60, 0), Vector2(40, 0))
	CombatCameraSelectTests._push_left_button(vp, start + Vector2(60, 0), false)
	var pan := cam.position - before
	var want := -Vector2(60, 0) / cam.zoom.x
	if not pan.is_equal_approx(want):
		return "%s: drag panned %s, want %s" % [label, pan, want]
	return ""


static func _t_focus_loss_resets_stuck_pointer() -> Dictionary:
	for what in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var fx := _make_fixture("focus_%d" % what)
		if fx.is_empty():
			return _no_fixture()
		_leave_pointers_stuck(fx)
		(fx["stage"] as StageExploreScreen).notification(what)
		var err := _check_tap_and_drag_work(fx, "focus-out %d" % what)
		(fx["viewport"] as SubViewport).free()
		if not err.is_empty():
			return { "ok": false, "error": err }
	return { "ok": true }


static func _t_hide_resets_stuck_pointer() -> Dictionary:
	var fx := _make_fixture("hide")
	if fx.is_empty():
		return _no_fixture()
	_leave_pointers_stuck(fx)
	var realm := fx["realm"] as RealmShell
	realm.visible = false
	realm.visible = true
	var err := _check_tap_and_drag_work(fx, "hide")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


# Preview, then a fresh explore entry, with a finger and a press left stuck from before.
static func _t_new_stage_entry_resets_stuck_pointer() -> Dictionary:
	var fx := _make_fixture("entry_reset")
	if fx.is_empty():
		return _no_fixture()
	_leave_pointers_stuck(fx)
	var stage := fx["stage"] as StageExploreScreen
	stage.set_snapshot(Stage004SeamTests._stage_preview_banner_snapshot(false))
	stage.set_snapshot(fx["snap"])
	var err := _check_tap_and_drag_work(fx, "new stage entry")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _make_sanctum(under: Node) -> SanctumShell:
	var sanctum := (load("res://ui/shells/SanctumShell.tscn") as PackedScene).instantiate() as SanctumShell
	under.add_child(sanctum)
	sanctum.set_layout(_LAYOUT)
	sanctum.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 1 }, "data": {}, "actions": {} })
	return sanctum


# AppRoot keeps a hidden SanctumShell next to RealmShell. Whichever shell is added first, the hidden
# one must take no Z, wheel, tap or drag, and the shown one must still take them.
static func _t_hidden_stage_takes_no_input_in_both_boot_orders() -> Dictionary:
	var errors: Array = []
	for sanctum_first in [false, true]:
		var label := "sanctum first" if sanctum_first else "realm first"
		var host := _host()
		if host == null:
			return _no_fixture()
		var fx := _make_fixture("boot_%s" % label.replace(" ", "_"))
		if fx.is_empty():
			return _no_fixture()
		var vp := fx["viewport"] as SubViewport
		var realm := fx["realm"] as RealmShell
		var stage := fx["stage"] as StageExploreScreen
		var cam := fx["camera"] as BoardCameraController
		var layer := realm.get_parent() as CanvasLayer
		var sanctum := _make_sanctum(layer)
		if sanctum_first:
			layer.move_child(sanctum, 0)
		# Sanctum shown, Stage hidden.
		realm.visible = false
		sanctum.visible = true
		var stage_before := cam.zoom
		var stage_pos := cam.position
		CombatCameraSelectTests._push_z(vp)
		CombatCameraSelectTests._push_wheel(vp, _CENTER, true)
		CombatCameraSelectTests._tap(vp, _CENTER)
		for step in range(10):
			cam._process(0.05)
			sanctum.camera._process(0.05)
		CombatCameraSelectTests._push_touch(vp, 0, _CENTER, true)
		var counted: bool = (stage.get("_pointer") as BoardPointerTracker).finger_count() != 0
		CombatCameraSelectTests._push_touch(vp, 0, _CENTER, false)
		if counted:
			errors.append("%s: the hidden Stage counted a finger" % label)
		if cam.zoom != stage_before or cam.position != stage_pos or (stage.get("_pointer") as BoardPointerTracker).is_pointer_down():
			errors.append("%s: the hidden Stage reacted to input" % label)
		if not is_equal_approx(sanctum.camera.zoom_goal().x, 2.2) and not is_equal_approx(sanctum.camera.zoom.x, 2.2):
			# Z then wheel on a 2.0 start: the shown Sanctum took at least one of them.
			if sanctum.camera.zoom_goal().x == 2.0:
				errors.append("%s: the shown Sanctum took no input" % label)
		# Stage shown, Sanctum hidden.
		sanctum.visible = false
		realm.visible = true
		var sanctum_goal := sanctum.camera.zoom_goal().x
		var z0 := cam.zoom.x
		CombatCameraSelectTests._push_z(vp)
		for step in range(30):
			cam._process(0.05)
		if is_equal_approx(cam.zoom.x, z0):
			errors.append("%s: Z did not zoom the shown Stage" % label)
		if not is_equal_approx(sanctum.camera.zoom_goal().x, sanctum_goal):
			errors.append("%s: Z stepped the hidden Sanctum" % label)
		vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Sanctum and Stage each own a Camera2D in the one root viewport. AppRoot._show_screen() hides every
# shell, then shows one; the shown shell's camera must be the one driving the viewport. In preview
# the Stage has no camera, so nothing drives it.
static func _t_shell_swap_hands_viewport_to_shown_camera() -> Dictionary:
	var fx := _make_fixture("swap")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var realm := fx["realm"] as RealmShell
	var stage_cam := fx["camera"] as BoardCameraController
	var sanctum := _make_sanctum(realm.get_parent())
	stage_cam.zoom = Vector2(0.7, 0.7)
	sanctum.camera.zoom = Vector2(1.9, 1.9)
	var steps := [
		{ "show": sanctum, "want": sanctum.camera },
		{ "show": realm, "want": stage_cam },
		{ "show": sanctum, "want": sanctum.camera },
	]
	for step in steps:
		realm.visible = false
		sanctum.visible = false
		(step["show"] as Control).visible = true
		var want := step["want"] as BoardCameraController
		want.force_update_scroll()
		var current := vp.get_camera_2d()
		var drawn_scale := vp.get_canvas_transform().get_scale().x
		if current != want or not is_equal_approx(drawn_scale, want.zoom.x):
			var msg := "After showing %s the viewport camera is %s at scale %s, want %s at %s" % [
				(step["show"] as Node).name, current, drawn_scale, want, want.zoom.x]
			vp.free()
			return { "ok": false, "error": msg }
	# Preview in the shown realm: its camera is off and drives nothing.
	sanctum.visible = false
	realm.visible = true
	(fx["stage"] as StageExploreScreen).set_snapshot(Stage004SeamTests._stage_preview_banner_snapshot(false))
	var still_drives := vp.get_camera_2d() == stage_cam
	vp.free()
	if still_drives:
		return { "ok": false, "error": "The Stage camera still drives the viewport in preview" }
	return { "ok": true }


# Stage -> Combat hands the viewport to the Combat camera once the old Stage is gone. Combat ->
# Stage builds a new Stage instance (as RealmShell does after every combat): FREE, default zoom,
# centred on the party.
static func _t_combat_swap_and_new_stage_start_free() -> Dictionary:
	var fx := _make_fixture("combat_swap")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var realm := fx["realm"] as RealmShell
	var old_stage := fx["stage"] as StageExploreScreen
	var old_cam := fx["camera"] as BoardCameraController
	# Leave the old Stage zoomed, panned and locked.
	CombatCameraSelectTests._tap(vp, _frame_cell(fx, _party_cell(fx), Vector2(160, 60)))
	old_cam.zoom = Vector2(2.0, 2.0)
	var combat_env := CombatCameraSelectTests._make_encounter(EncounterResolutionModes.COMBAT)
	if combat_env.is_empty():
		return _fail(fx, "Combat setup failed")
	realm.set_snapshot(CombatCameraSelectTests._snapshot(combat_env))
	SanctumLayoutTests._force_control_layout(realm)
	var combat := realm.get("_active_overlay") as CombatBoardScreen
	if combat == null:
		return _fail(fx, "RealmShell did not mount combat; premise failed")
	old_stage.free()
	var errors: Array = []
	if vp.get_camera_2d() != combat.camera:
		errors.append("after Stage -> Combat the viewport camera is %s, want the Combat camera" % vp.get_camera_2d())
	# Back to exploration: a new Stage instance.
	realm.set_snapshot(fx["snap"])
	SanctumLayoutTests._force_control_layout(realm)
	var new_stage := realm.get("_active_overlay") as StageExploreScreen
	combat.free()
	if new_stage == null or new_stage == old_stage:
		return _fail(fx, "RealmShell did not build a new Stage; premise failed")
	var cam := new_stage.camera
	fx["stage"] = new_stage
	fx["camera"] = cam
	if cam.mode != BoardCameraController.Mode.FREE or not is_equal_approx(cam.zoom.x, 1.3):
		errors.append("the new Stage started with mode %d zoom %s, want FREE at 1.3" % [cam.mode, cam.zoom.x])
	if _cell_viewport(fx, _party_cell(fx)).distance_to(_CENTER) > 1.0:
		errors.append("the new Stage is not centred on the party")
	if vp.get_camera_2d() != cam:
		errors.append("after Combat -> Stage the viewport camera is %s, want the new Stage camera" % vp.get_camera_2d())
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# A snapshot that moves nobody must not undo the player's pan and zoom.
static func _t_parked_refresh_keeps_manual_view() -> Dictionary:
	var fx := _make_fixture("parked")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var start := _CENTER + Vector2(-260, -130)
	CombatCameraSelectTests._push_left_button(vp, start, true)
	CombatCameraSelectTests._push_motion(vp, start + Vector2(30, 0), Vector2(30, 0))
	CombatCameraSelectTests._push_motion(vp, start + Vector2(130, 40), Vector2(100, 40))
	CombatCameraSelectTests._push_left_button(vp, start + Vector2(130, 40), false)
	CombatCameraSelectTests._push_wheel(vp, start, true)
	_step(fx, 1.0)
	var pos := cam.position
	var zoom := cam.zoom
	_refresh(fx)
	_refresh(fx)
	_step(fx, 1.0)
	var kept := cam.position == pos and cam.zoom == zoom
	vp.free()
	if pos.is_zero_approx():
		return { "ok": false, "error": "The pan did not move the camera; premise failed" }
	if not kept:
		return { "ok": false, "error": "A parked snapshot refresh reset the manual view (%s/%s -> %s/%s)" % [pos, zoom, cam.position, cam.zoom] }
	return { "ok": true }


# The camera keeps its world point and zoom through a live resize, and the zoom floor follows.
static func _t_live_resize_keeps_focus_point() -> Dictionary:
	var fx := _make_fixture("resize")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var realm := fx["realm"] as RealmShell
	var cam := fx["camera"] as BoardCameraController
	var min_before: float = cam.get("_min_zoom")
	cam.zoom = Vector2(0.9, 0.9)
	cam.position = Vector2(150.0, -60.0)
	vp.size = Vector2i(1800, 900)
	realm.set_layout({ "profile": &"wide", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1800, 900) })
	var min_after: float = cam.get("_min_zoom")
	var kept := cam.position.is_equal_approx(Vector2(150.0, -60.0)) and cam.zoom.is_equal_approx(Vector2(0.9, 0.9))
	vp.free()
	if not kept:
		return { "ok": false, "error": "Live resize moved the camera or changed the zoom (%s, %s)" % [cam.position, cam.zoom] }
	if min_after <= min_before:
		return { "ok": false, "error": "Live resize did not refit the zoom floor (%s -> %s)" % [min_before, min_after] }
	return { "ok": true }


# A modal covers the board: nothing reaches it while the modal is open.
static func _t_modal_blocks_board_input() -> Dictionary:
	var fx := _make_fixture("modal")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 40
	vp.add_child(modal_layer)
	var host := (load("res://ui/components/ModalHost.tscn") as PackedScene).instantiate() as ModalHost
	modal_layer.add_child(host)
	var button := Button.new()
	button.text = "OK"
	button.custom_minimum_size = Vector2(120, 48)
	var dialog := PackedScene.new()
	dialog.pack(button)
	button.free()
	if not host.present_modal(dialog) or not host.has_active_modal():
		return _fail(fx, "Modal did not open; premise failed")
	var point := _frame_cell(fx, _party_cell(fx), Vector2(160, 60))
	var z0 := cam.zoom
	var pos0 := cam.position
	CombatCameraSelectTests._tap(vp, point)
	CombatCameraSelectTests._push_left_button(vp, point, true)
	CombatCameraSelectTests._push_motion(vp, point + Vector2(80, 0), Vector2(80, 0))
	CombatCameraSelectTests._push_left_button(vp, point + Vector2(80, 0), false)
	CombatCameraSelectTests._push_wheel(vp, point, true)
	_step(fx, 1.0)
	var mode := cam.mode
	var moved := cam.position != pos0
	var zoomed := cam.zoom != z0
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A tap through an open modal locked the camera (mode %d)" % mode }
	if moved or zoomed:
		return { "ok": false, "error": "A drag or wheel through an open modal moved the camera (moved=%s, zoomed=%s)" % [moved, zoomed] }
	return { "ok": true }


# The bubble is screen-space. When the camera pans, the screen's _process must move a live bubble by
# the same screen distance as the party token.
static func _t_bark_anchor_tracks_party_on_screen() -> Dictionary:
	var fx := _make_fixture("bark")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var stage := fx["stage"] as StageExploreScreen
	var token_before := _frame_cell(fx, _party_cell(fx), Vector2.ZERO)
	var layer := stage.get_node("%BarkPopupLayer")
	layer.call("show_barks", [{ "actor_id": "party", "bark_line": "Stay close.", "bark_context": "",
			"bark_tier": "", "bark_priority": 1, "is_response": false, "screen_pos": token_before }])
	var entry: Dictionary = (layer.get("_active_popups") as Dictionary).get("party", {})
	var popup := entry.get("node") as Control
	if popup == null:
		return _fail(fx, "Bark popup was not created; premise failed")
	_step(fx, 0.05)
	var popup_before := popup.position
	var start := _CENTER + Vector2(-260, -130)
	CombatCameraSelectTests._push_left_button(vp, start, true)
	CombatCameraSelectTests._push_motion(vp, start + Vector2(30, 0), Vector2(30, 0))
	CombatCameraSelectTests._push_motion(vp, start + Vector2(110, 40), Vector2(80, 40))
	CombatCameraSelectTests._push_left_button(vp, start + Vector2(110, 40), false)
	_step(fx, 0.05)
	var token_moved := _cell_viewport(fx, _party_cell(fx)) - token_before
	var popup_moved := popup.position - popup_before
	vp.free()
	if token_moved.length() < 50.0:
		return { "ok": false, "error": "Pan moved the token only %s; premise failed" % token_moved }
	if popup_moved.distance_to(token_moved) > 0.5:
		return { "ok": false, "error": "Bubble moved %s on screen, token moved %s" % [popup_moved, token_moved] }
	return { "ok": true }


# CanvasLayer visibility and Camera2D.enabled do not follow the Control, so a hidden Stage must switch
# its camera and world layer off itself, and back on when shown again.
static func _t_hidden_screen_disables_camera_and_world() -> Dictionary:
	var fx := _make_fixture("hidden")
	if fx.is_empty():
		return _no_fixture()
	var cam := fx["camera"] as BoardCameraController
	var world := (fx["stage"] as StageExploreScreen).get_node("WorldLayer") as CanvasLayer
	var shown_ok := cam.enabled and world.visible
	(fx["realm"] as RealmShell).visible = false
	var hidden_ok := not cam.enabled and not world.visible
	(fx["realm"] as RealmShell).visible = true
	var reshown_ok := cam.enabled and world.visible
	(fx["viewport"] as SubViewport).free()
	if not shown_ok:
		return { "ok": false, "error": "Visible Stage has its camera or world layer off" }
	if not hidden_ok:
		return { "ok": false, "error": "Hiding RealmShell left the Stage camera enabled or the world layer visible" }
	if not reshown_ok:
		return { "ok": false, "error": "Showing RealmShell again did not restore the camera and world layer" }
	return { "ok": true }


# A snapshot that moves nobody can arrive while the party is still walking. It must not snap the
# token to its destination or pull the follow target ahead of the drawn token.
static func _t_parked_refresh_during_walk_keeps_token_and_target() -> Dictionary:
	var fx := _make_fixture("walk_refresh")
	if fx.is_empty():
		return _no_fixture()
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	_advance(fx)
	var path: Array = _data(fx).get("traveled_path", [])
	var tween := stage.get("_travel_tween") as Tween
	if path.size() < 2 or tween == null or not tween.is_valid():
		return _fail(fx, "The advance did not walk two cells; premise failed")
	tween.custom_step(0.001)
	var party := stage.get("_party_layer") as Node2D
	_refresh(fx)
	var token: Vector2 = party.call("display_position")
	var dest_local := _board(fx).map_to_local(_party_cell(fx))
	stage._process(0.05)
	var target: Vector2 = cam.get("_follow_target_local")
	var drawn_world := _board(fx).to_global(token)
	(fx["viewport"] as SubViewport).free()
	if token.is_equal_approx(dest_local):
		return { "ok": false, "error": "A parked refresh during the walk snapped the token to its destination" }
	if not target.is_equal_approx(drawn_world):
		return { "ok": false, "error": "A parked refresh during the walk moved the follow target to %s, want the drawn token %s" % [target, drawn_world] }
	return { "ok": true }


# The bars at the bottom take their own presses: a tap in a gap between their controls is not a tap
# on the board, so it must not release the lock.
static func _t_tap_on_chrome_bar_gaps_keeps_the_lock() -> Dictionary:
	var fx := _make_fixture("bar_gaps")
	if fx.is_empty():
		return _no_fixture()
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var stage := fx["stage"] as StageExploreScreen
	for bar_name in ["%ActionBar", "%StepBudgetRow"]:
		var bar := stage.get_node(bar_name) as Control
		if not bar.is_visible_in_tree():
			return _fail(fx, "%s is hidden; premise failed" % bar_name)
		var gap := Vector2.INF
		var rect := bar.get_global_rect()
		var x := rect.position.x + 2.0
		while x < rect.end.x:
			var candidate := Vector2(x, rect.get_center().y)
			_hovered_is_stage(fx, candidate)
			if vp.gui_get_hovered_control() == bar:
				gap = candidate
				break
			x += 4.0
		if gap == Vector2.INF:
			return _fail(fx, "%s has no gap; premise failed" % bar_name)
		cam.select("party")
		CombatCameraSelectTests._tap(vp, gap)
		if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR:
			return _fail(fx, "A tap in a gap of %s released the lock" % bar_name)
	vp.free()
	return { "ok": true }
