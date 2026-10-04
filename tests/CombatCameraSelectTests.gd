extends RefCounted
class_name CombatCameraSelectTests

# Selection-lock camera on the combat board (ANSWERS.md #74-79, decisions.md #70-72).
# Each fixture is a real encounter: FlowRuntime + FlowEncounterState.enter() + combat.init, with the
# snapshot from EncounterSnapshotBuilder, routed through the real RealmShell into the real
# CombatBoardScreen. Input goes through SubViewport.push_input(), so Godot's GUI routing decides
# which node gets each press. RealmShell sits in a layer-10 CanvasLayer, as in Approot.tscn, so the
# camera moves only the board and not the combat chrome.

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")

const _VIEW := Vector2i(1280, 720)
const _CENTER := Vector2(640, 360)
const _LAYOUT := { "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": Vector2(1280, 720) }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_camera/no_auto_select_on_encounter_start",        Callable(CombatCameraSelectTests, "_t_no_auto_select_on_encounter_start"))
	runner.register_test("combat_camera/tap_echo_locks_and_follows",               Callable(CombatCameraSelectTests, "_t_tap_echo_locks_and_follows"))
	runner.register_test("combat_camera/tap_enemy_locks_and_follows",              Callable(CombatCameraSelectTests, "_t_tap_enemy_locks_and_follows"))
	runner.register_test("combat_camera/tap_structure_locks_and_follows",          Callable(CombatCameraSelectTests, "_t_tap_structure_locks_and_follows"))
	runner.register_test("combat_camera/tap_spirit_locks_and_follows",             Callable(CombatCameraSelectTests, "_t_tap_spirit_locks_and_follows"))
	runner.register_test("combat_camera/same_select_path_in_every_objective",      Callable(CombatCameraSelectTests, "_t_same_select_path_in_every_objective"))
	runner.register_test("combat_camera/tap_empty_board_releases_to_free",         Callable(CombatCameraSelectTests, "_t_tap_empty_board_releases_to_free"))
	runner.register_test("combat_camera/drag_pans_and_is_not_a_tap",               Callable(CombatCameraSelectTests, "_t_drag_pans_and_is_not_a_tap"))
	runner.register_test("combat_camera/drag_while_locked_holds_then_resumes",     Callable(CombatCameraSelectTests, "_t_drag_while_locked_holds_then_resumes"))
	runner.register_test("combat_camera/initiative_row_tap_selects_actor",         Callable(CombatCameraSelectTests, "_t_initiative_row_tap_selects_actor"))
	runner.register_test("combat_camera/echo_card_tap_selects_actor",              Callable(CombatCameraSelectTests, "_t_echo_card_tap_selects_actor"))
	runner.register_test("combat_camera/recenter_follows_party_centroid",          Callable(CombatCameraSelectTests, "_t_recenter_follows_party_centroid"))
	runner.register_test("combat_camera/guide_spirit_stretched_board_follow",      Callable(CombatCameraSelectTests, "_t_guide_spirit_stretched_board_follow"))
	runner.register_test("combat_camera/hidden_screen_disables_camera_and_board",  Callable(CombatCameraSelectTests, "_t_hidden_screen_disables_camera_and_board"))
	runner.register_test("combat_camera/bark_anchor_tracks_token_on_screen",       Callable(CombatCameraSelectTests, "_t_bark_anchor_tracks_token_on_screen"))
	runner.register_test("combat_camera/shell_swap_hands_viewport_to_shown_camera", Callable(CombatCameraSelectTests, "_t_shell_swap_hands_viewport_to_shown_camera"))
	runner.register_test("combat_camera/two_finger_pinch_does_not_pan_or_tap",     Callable(CombatCameraSelectTests, "_t_two_finger_pinch_does_not_pan_or_tap"))
	runner.register_test("combat_camera/engine_emulated_pointer_end_to_end",      Callable(CombatCameraSelectTests, "_t_engine_emulated_pointer_end_to_end"))
	runner.register_test("combat_camera/second_finger_on_chrome_stops_pan",       Callable(CombatCameraSelectTests, "_t_second_finger_on_chrome_stops_pan"))
	runner.register_test("combat_camera/wheel_scales_with_event_factor",          Callable(CombatCameraSelectTests, "_t_wheel_scales_with_event_factor"))
	runner.register_test("combat_camera/wheel_step_zero_with_surface_is_off",     Callable(CombatCameraSelectTests, "_t_wheel_step_zero_with_surface_is_off"))
	runner.register_test("combat_camera/bubble_does_not_block_wheel_or_tap",      Callable(CombatCameraSelectTests, "_t_bubble_does_not_block_wheel_or_tap"))
	runner.register_test("combat_camera/focus_loss_resets_stuck_pointer",         Callable(CombatCameraSelectTests, "_t_focus_loss_resets_stuck_pointer"))
	runner.register_test("combat_camera/hide_resets_stuck_pointer",               Callable(CombatCameraSelectTests, "_t_hide_resets_stuck_pointer"))
	runner.register_test("combat_camera/new_encounter_resets_stuck_pointer",      Callable(CombatCameraSelectTests, "_t_new_encounter_resets_stuck_pointer"))
	runner.register_test("combat_camera/app_root_rerender_keeps_drag",            Callable(CombatCameraSelectTests, "_t_app_root_rerender_keeps_drag"))
	runner.register_test("combat_camera/wheel_zoom_eases_over_frames",           Callable(CombatCameraSelectTests, "_t_wheel_zoom_eases_over_frames"))
	runner.register_test("combat_camera/buttons_take_no_focus_from_clicks",       Callable(CombatCameraSelectTests, "_t_buttons_take_no_focus_from_clicks"))
	runner.register_test("combat_camera/lost_touch_release_does_not_block_board", Callable(CombatCameraSelectTests, "_t_lost_touch_release_does_not_block_board"))
	runner.register_test("combat_camera/configure_zoom_range_cancels_wheel_ease",  Callable(CombatCameraSelectTests, "_t_configure_zoom_range_cancels_wheel_ease"))
	runner.register_test("combat_camera/z_steps_through_levels_and_wraps",        Callable(CombatCameraSelectTests, "_t_z_steps_through_levels_and_wraps"))
	runner.register_test("combat_camera/z_after_wheel_goes_to_next_level",        Callable(CombatCameraSelectTests, "_t_z_after_wheel_goes_to_next_level"))
	runner.register_test("combat_camera/z_in_focused_line_edit_types_letter",     Callable(CombatCameraSelectTests, "_t_z_in_focused_line_edit_types_letter"))
	runner.register_test("combat_camera/z_in_hidden_screen_does_nothing",         Callable(CombatCameraSelectTests, "_t_z_in_hidden_screen_does_nothing"))
	runner.register_test("combat_camera/z_while_locked_keeps_actor_centred",      Callable(CombatCameraSelectTests, "_t_z_while_locked_keeps_actor_centred"))
	runner.register_test("combat_camera/z_in_combat_with_hidden_sanctum_present", Callable(CombatCameraSelectTests, "_t_z_in_combat_with_hidden_sanctum_present"))
	runner.register_test("combat_camera/quick_second_z_steps_from_target",       Callable(CombatCameraSelectTests, "_t_quick_second_z_steps_from_target"))
	runner.register_test("combat_camera/magnify_zooms_and_holds_lock",            Callable(CombatCameraSelectTests, "_t_magnify_zooms_and_holds_lock"))
	runner.register_test("combat_camera/locked_actor_dies_falls_back_to_party",   Callable(CombatCameraSelectTests, "_t_locked_actor_dies_falls_back_to_party"))
	runner.register_test("combat_camera/dead_actor_board_card_and_row_do_nothing",          Callable(CombatCameraSelectTests, "_t_dead_actor_board_card_and_row_do_nothing"))
	runner.register_test("combat_camera/living_wins_over_dead_on_one_cell",       Callable(CombatCameraSelectTests, "_t_living_wins_over_dead_on_one_cell"))
	runner.register_test("combat_camera/new_encounter_resets_camera",             Callable(CombatCameraSelectTests, "_t_new_encounter_resets_camera"))
	runner.register_test("combat_camera/wheel_steps_zoom_and_stops_at_limits",    Callable(CombatCameraSelectTests, "_t_wheel_steps_zoom_and_stops_at_limits"))
	runner.register_test("combat_camera/wheel_over_panels_does_not_zoom",         Callable(CombatCameraSelectTests, "_t_wheel_over_panels_does_not_zoom"))
	runner.register_test("combat_camera/wheel_free_zooms_toward_pointer",         Callable(CombatCameraSelectTests, "_t_wheel_free_zooms_toward_pointer"))
	runner.register_test("combat_camera/wheel_locked_keeps_target_centred",       Callable(CombatCameraSelectTests, "_t_wheel_locked_keeps_target_centred"))
	runner.register_test("combat_camera/sanctum_wheel_uses_shared_rule",        Callable(CombatCameraSelectTests, "_t_sanctum_wheel_uses_shared_rule"))


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

static func _make_encounter(objective: String, guide_mode: String = "") -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.dir() + "combat_camera_slot.json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, 0).is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.camera_" + objective

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate("camera_" + objective, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids
	flow_ctx.dev_combat_objective = objective
	flow_ctx.dev_guide_mode = guide_mode
	flow_ctx.dev_guide_joins = "nojoin" if objective == EncounterResolutionModes.GUIDE_SPIRIT else ""
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	FlowEncounterState.new().enter(flow_ctx, 0)
	runtime.dispatch({ "type": "combat.init" })
	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": flow_ctx.encounter_ctx }


static func _snapshot(env: Dictionary) -> Dictionary:
	return EncounterSnapshotBuilder.build_round_snapshot(env["flow_ctx"], 1)


static func _make_fixture(objective: String, guide_mode: String = "") -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if host == null:
		return {}
	var env := _make_encounter(objective, guide_mode)
	if env.is_empty():
		return {}
	var snap := _snapshot(env)
	if str(snap.get("type", "")) != "flow.encounter":
		return {}
	var vp := SubViewport.new()
	vp.size = _VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var content_layer := CanvasLayer.new()
	content_layer.layer = 10
	vp.add_child(content_layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	content_layer.add_child(realm)
	realm.set_layout(_LAYOUT)
	realm.set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(realm)
	var combat := realm.get("_active_overlay") as CombatBoardScreen
	if combat == null:
		vp.free()
		return {}
	return { "env": env, "viewport": vp, "realm": realm, "combat": combat, "camera": combat.camera, "snap": snap }


static func _push_left_button(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.pressed = pressed
	vp.push_input(ev, true)


static func _push_motion(vp: SubViewport, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(ev, true)


static func _tap(vp: SubViewport, pos: Vector2) -> void:
	_push_left_button(vp, pos, true)
	_push_left_button(vp, pos, false)


static func _push_touch(vp: SubViewport, index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	vp.push_input(ev, true)


static func _push_touch_drag(vp: SubViewport, index: int, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = relative
	vp.push_input(ev, true)


static func _is_empty_point(combat: CombatBoardScreen, point: Vector2) -> bool:
	var cell: Vector2i = combat.call("_cell_at_viewport_point", point)
	return (combat.call("_actors_on_cell", cell) as Array).is_empty()


# An open-board point near the centre with no actor on its cell, or Vector2.INF.
static func _empty_point_near_centre(combat: CombatBoardScreen, centre: Vector2 = _CENTER) -> Vector2:
	for offset in [Vector2(0, -130), Vector2(260, 0), Vector2(-260, 0), Vector2(0, 130), Vector2(200, -120)]:
		var candidate: Vector2 = centre + offset
		if _is_empty_point(combat, candidate):
			return candidate
	return Vector2.INF


static func _ectx_actor(fx: Dictionary, actor_id: String) -> Dictionary:
	for a_v in (fx["env"] as Dictionary)["ectx"].actors:
		if a_v is Dictionary and str(a_v.get("id", "")) == actor_id:
			return a_v
	return {}


static func _kill(fx: Dictionary, actor_id: String) -> void:
	var a := _ectx_actor(fx, actor_id)
	a["is_dead"] = true
	a["current_hp"] = 0


# Rebuilds the snapshot with the production builder and routes it through RealmShell.
static func _refresh(fx: Dictionary) -> void:
	var snap := _snapshot(fx["env"])
	fx["snap"] = snap
	(fx["realm"] as RealmShell).set_snapshot(snap)
	SanctumLayoutTests._force_control_layout(fx["realm"])


static func _living_echoes(fx: Dictionary) -> Array:
	var out: Array = []
	for a_v in (fx["combat"] as CombatBoardScreen).get("_last_actors"):
		if a_v is Dictionary and str(a_v.get("faction", "")) == "echo" and _is_living(a_v) \
				and not bool(a_v.get("is_spirit", false)):
			out.append(a_v)
	return out


static func _party_centroid_world(fx: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	var echoes := _living_echoes(fx)
	for a in echoes:
		sum += _token_world_pos(fx, a)
	return sum / float(echoes.size())


# Runs the camera follow for `seconds` in 0.05 s frames, the way SceneTree would.
static func _step(fx: Dictionary, seconds: float) -> void:
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var frames := int(ceil(seconds / 0.05))
	for i in range(frames):
		cam._process(0.05)
		cam.force_update_scroll()
		combat._process(0.05)


static func _actor_where(fx: Dictionary, pred: Callable) -> Dictionary:
	for a_v in (fx["combat"] as CombatBoardScreen).get("_last_actors"):
		if a_v is Dictionary and pred.call(a_v):
			return a_v
	return {}


static func _cell(actor: Dictionary) -> Vector2i:
	var gp: Dictionary = actor.get("grid_pos", {})
	return Vector2i(int(gp.get("col", 0)), int(gp.get("row", 0)))


# Where the actor's token is drawn on screen, through the real canvas transform.
static func _token_viewport_pos(fx: Dictionary, actor: Dictionary) -> Vector2:
	var cam := fx["camera"] as BoardCameraController
	cam.force_update_scroll()
	var board := (fx["combat"] as CombatBoardScreen).get("_board") as TileMapLayer
	return board.get_global_transform_with_canvas() * board.map_to_local(_cell(actor))


static func _token_world_pos(fx: Dictionary, actor: Dictionary) -> Vector2:
	var board := (fx["combat"] as CombatBoardScreen).get("_board") as TileMapLayer
	return board.to_global(board.map_to_local(_cell(actor)))


# Places the camera so the token is drawn at `screen_offset` from the viewport centre. Open board
# around the centre is free of combat chrome, so a tap there reaches the screen root.
static func _frame_token(fx: Dictionary, actor: Dictionary, screen_offset: Vector2) -> Vector2:
	var cam := fx["camera"] as BoardCameraController
	cam.position = _token_world_pos(fx, actor) - screen_offset / cam.zoom.x
	cam.force_update_scroll()
	return _token_viewport_pos(fx, actor)


static func _is_living(a: Dictionary) -> bool:
	return str(a.get("status", "")) != "dead" and not bool(a.get("is_dead", false))


# Taps the actor's token off-centre, then checks lock, target and that the follow brings the
# token to the viewport centre. Returns "" on success.
static func _check_tap_locks_and_follows(fx: Dictionary, actor: Dictionary, label: String) -> String:
	if actor.is_empty():
		return "Fixture has no %s actor" % label
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var actor_id := str(actor.get("id", ""))
	var tap_point := _frame_token(fx, actor, Vector2(160, 60))
	if not tap_point.is_equal_approx(_CENTER + Vector2(160, 60)):
		return "%s token framed at %s, expected %s; board does not follow the camera" % [label, tap_point, _CENTER + Vector2(160, 60)]
	_tap(vp, tap_point)
	if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != actor_id:
		return "Tapping the %s token did not lock the camera (mode %d, target '%s', want '%s')" % [label, cam.mode, cam.target_id, actor_id]
	_step(fx, 4.0)
	var drawn := _token_viewport_pos(fx, actor)
	if drawn.distance_to(_CENTER) > 2.0:
		return "Locked camera did not bring the %s token to the centre (drawn at %s)" % [label, drawn]
	return ""


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# ANSWERS.md #76: nothing is selected when an encounter starts, in any mode, PURSUE included.
static func _t_no_auto_select_on_encounter_start() -> Dictionary:
	for objective in [EncounterResolutionModes.COMBAT, EncounterResolutionModes.PURSUE, EncounterResolutionModes.GUIDE_SPIRIT]:
		var fx := _make_fixture(objective, "escort" if objective == EncounterResolutionModes.GUIDE_SPIRIT else "")
		if fx.is_empty():
			return { "ok": false, "error": "Fixture failed for %s" % objective }
		var cam := fx["camera"] as BoardCameraController
		var before := cam.position
		_step(fx, 2.0)
		var mode := cam.mode
		var moved := cam.position != before
		var zoom := cam.zoom.x
		(fx["viewport"] as SubViewport).free()
		if mode != BoardCameraController.Mode.FREE:
			return { "ok": false, "error": "%s encounter started with camera mode %d, want FREE" % [objective, mode] }
		if moved:
			return { "ok": false, "error": "%s camera moved on its own with nothing selected" % objective }
		if not is_equal_approx(zoom, 1.3):
			return { "ok": false, "error": "%s default zoom is %s, want 1.3 (decisions.md #71)" % [objective, zoom] }
	return { "ok": true }


static func _t_tap_echo_locks_and_follows() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_tap_enemy_locks_and_follows() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var enemy := _actor_where(fx, func(a): return str(a.get("faction", "")) == "enemy" \
			and not bool(a.get("is_structure", false)) and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, enemy, "enemy")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_tap_structure_locks_and_follows() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.PURIFY_SHRINE)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var shrine := _actor_where(fx, func(a): return bool(a.get("is_structure", false)))
	var err := _check_tap_locks_and_follows(fx, shrine, "structure")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_tap_spirit_locks_and_follows() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.GUIDE_SPIRIT, "escort")
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var spirit := _actor_where(fx, func(a): return bool(a.get("is_spirit", false)))
	var err := _check_tap_locks_and_follows(fx, spirit, "spirit")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


# No mode gating: the same tap selects an echo in every objective type.
static func _t_same_select_path_in_every_objective() -> Dictionary:
	var objectives := [
		EncounterResolutionModes.COMBAT, EncounterResolutionModes.PURIFY_SHRINE,
		EncounterResolutionModes.RECOVER, EncounterResolutionModes.PROTECT,
		EncounterResolutionModes.ENDURE, EncounterResolutionModes.PURSUE,
		EncounterResolutionModes.GUIDE_SPIRIT,
	]
	for objective in objectives:
		var fx := _make_fixture(objective, "protect" if objective == EncounterResolutionModes.GUIDE_SPIRIT else "")
		if fx.is_empty():
			return { "ok": false, "error": "Fixture failed for %s" % objective }
		var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a) \
				and not bool(a.get("is_spirit", false)))
		var err := _check_tap_locks_and_follows(fx, echo, "echo in %s" % objective)
		(fx["viewport"] as SubViewport).free()
		if not err.is_empty():
			return { "ok": false, "error": err }
	return { "ok": true }


# ANSWERS.md #76: a tap on board space with no actor releases the lock to FREE.
static func _t_tap_empty_board_releases_to_free() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var empty_point := _empty_point_near_centre(combat)
	if empty_point == Vector2.INF:
		vp.free()
		return { "ok": false, "error": "No empty board point near the centre; test premise failed" }
	_tap(vp, empty_point)
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


# A press that moves past the drag threshold pans 1:1 and never selects what was under it.
static func _t_drag_pans_and_is_not_a_tap() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var start := _frame_token(fx, echo, Vector2.ZERO)
	var cam_before := cam.position
	_push_left_button(vp, start, true)
	_push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	_push_motion(vp, start + Vector2(60, 0), Vector2(40, 0))
	_push_left_button(vp, start + Vector2(60, 0), false)
	var mode := cam.mode
	var pan := cam.position - cam_before
	# Once past the threshold the whole 60 px pans, so the world point under the pointer stays there.
	var expected := -Vector2(60, 0) / cam.zoom.x
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "A drag that started on a token selected it (mode %d)" % mode }
	if not pan.is_equal_approx(expected):
		return { "ok": false, "error": "Drag moved the camera by %s, expected %s" % [pan, expected] }
	return { "ok": true }


# decisions.md #72: a manual pan on a locked camera pauses the follow for 3 s, then the lock resumes.
static func _t_drag_while_locked_holds_then_resumes() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var start := _CENTER + Vector2(0, -100)
	_push_left_button(vp, start, true)
	_push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	_push_motion(vp, start + Vector2(220, 0), Vector2(200, 0))
	_push_left_button(vp, start + Vector2(220, 0), false)
	var held := cam.is_follow_held()
	var panned_pos := cam.position
	_step(fx, 2.5)
	var during_hold := cam.position
	var still_locked := cam.mode == BoardCameraController.Mode.FOLLOW_ACTOR and cam.target_id == str(echo.get("id", ""))
	_step(fx, 4.0)
	var drawn := _token_viewport_pos(fx, echo)
	vp.free()
	if not held:
		return { "ok": false, "error": "Drag on a locked camera did not start the follow hold" }
	if panned_pos.is_equal_approx(during_hold) == false:
		return { "ok": false, "error": "Follow resumed inside the 3 s hold (%s -> %s)" % [panned_pos, during_hold] }
	if not still_locked:
		return { "ok": false, "error": "Drag released the lock instead of holding it" }
	if drawn.distance_to(_CENTER) > 2.0:
		return { "ok": false, "error": "Follow did not resume after the hold (token drawn at %s)" % drawn }
	return { "ok": true }


static func _t_initiative_row_tap_selects_actor() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var order: Array = (fx["snap"] as Dictionary).get("data", {}).get("initiative_order", [])
	var list := combat.get("_initiative_list") as VBoxContainer
	SanctumLayoutTests._force_control_layout(combat)
	var rows: Array = []
	for child in list.get_children():
		if not child.is_queued_for_deletion():
			rows.append(child)
	if order.size() < 3 or rows.size() != order.size():
		vp.free()
		return { "ok": false, "error": "Initiative panel has %d rows for %d entries; premise failed" % [rows.size(), order.size()] }
	var index := order.size() - 1
	var want := str((order[index] as Dictionary).get("id", ""))
	var row := rows[index] as Control
	if not row.is_visible_in_tree() or row.size.y <= 0.0:
		vp.free()
		return { "ok": false, "error": "Initiative row is not laid out; premise failed" }
	_tap(vp, row.get_global_rect().get_center())
	var mode := cam.mode
	var target := cam.target_id
	vp.free()
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != want:
		return { "ok": false, "error": "Initiative row tap gave mode %d target '%s', want '%s'" % [mode, target, want] }
	return { "ok": true }


# ANSWERS.md #77: the shared RealmShell echo bar forwards a card tap to the active screen.
static func _t_echo_card_tap_selects_actor() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.GUIDE_SPIRIT, "escort")
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var realm := fx["realm"] as RealmShell
	var bar := realm.get_node("%EchoBar") as HBoxContainer
	var cards: Array = []
	for child in bar.get_children():
		if not child.is_queued_for_deletion():
			cards.append(child)
	if cards.size() < 2:
		vp.free()
		return { "ok": false, "error": "Echo bar has %d cards; premise failed" % cards.size() }
	# Party cards follow actors-array order; the spirit card is always last.
	var echoes: Array = []
	for a_v in (fx["combat"] as CombatBoardScreen).get("_last_actors"):
		if a_v is Dictionary and str(a_v.get("faction", "")) == "echo" and not bool(a_v.get("is_spirit", false)):
			echoes.append(str(a_v.get("id", "")))
	var spirit_id := str(_actor_where(fx, func(a): return bool(a.get("is_spirit", false))).get("id", ""))
	var checks := [
		{ "card": cards[1], "want": echoes[1] },
		{ "card": cards[cards.size() - 1], "want": spirit_id },
	]
	var scroll := realm.get_node("%EchoBarScroll") as ScrollContainer
	for check in checks:
		var card := check["card"] as Control
		# Six cards overflow the bar; scroll the card into view as a player would.
		scroll.scroll_horizontal = int(card.position.x)
		SanctumLayoutTests._force_control_layout(realm)
		var point := card.get_global_rect().get_center()
		if not scroll.get_global_rect().has_point(point):
			vp.free()
			return { "ok": false, "error": "Card centre %s is outside the visible bar; premise failed" % point }
		_tap(vp, point)
		if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != str(check["want"]):
			var got := cam.target_id
			vp.free()
			return { "ok": false, "error": "Card tap gave target '%s', want '%s'" % [got, check["want"]] }
	vp.free()
	return { "ok": true }


static func _t_recenter_follows_party_centroid() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var button := combat.get_node("%RecenterButton") as Button
	if not button.is_visible_in_tree():
		(fx["viewport"] as SubViewport).free()
		return { "ok": false, "error": "Recenter button hidden in the fixture; premise failed" }
	cam.position = Vector2(400, -200)
	_tap(fx["viewport"], button.get_global_rect().get_center())
	_step(fx, 4.0)
	var want := cam.clamped_position(_party_centroid_world(fx), cam.zoom)
	var mode := cam.mode
	var got := cam.position
	(fx["viewport"] as SubViewport).free()
	if mode != BoardCameraController.Mode.FOLLOW_PARTY:
		return { "ok": false, "error": "Recenter left camera mode %d, want FOLLOW_PARTY" % mode }
	if got.distance_to(want) > 1.0:
		return { "ok": false, "error": "Recenter camera at %s, party centroid %s" % [got, want] }
	return { "ok": true }


# GUIDE_SPIRIT escort on its stretched board. The spirit is selected by
# a tap and the camera follows it to the far end of the long axis. The spirit is moved in the
# encounter context and the snapshot is rebuilt by the production builder, as a round would.
static func _t_guide_spirit_stretched_board_follow() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.GUIDE_SPIRIT, "escort")
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var realm := fx["realm"] as RealmShell
	var combat := fx["combat"] as CombatBoardScreen
	var data: Dictionary = (fx["snap"] as Dictionary).get("data", {})
	var cols := int(data.get("board_cols", 0))
	var rows := int(data.get("board_rows", 0))
	if maxi(cols, rows) < 60:
		vp.free()
		return { "ok": false, "error": "GUIDE_SPIRIT board is %dx%d, not stretched; premise failed" % [cols, rows] }
	var min_zoom: float = cam.get("_min_zoom")
	var span: Vector2 = combat.get("_board_span_px")
	var want_min := clampf(720.0 / maxf(span.x, span.y) * 0.90, 0.05, 0.35)
	if not is_equal_approx(min_zoom, want_min) or min_zoom >= 0.4:
		vp.free()
		return { "ok": false, "error": "min_zoom %s on a %dx%d board, want %s (decisions.md #70)" % [min_zoom, cols, rows, want_min] }

	var spirit := _actor_where(fx, func(a): return bool(a.get("is_spirit", false)))
	var err := _check_tap_locks_and_follows(fx, spirit, "spirit")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var start_cam := cam.position

	var ectx = (fx["env"] as Dictionary)["ectx"]
	var far_cell := Vector2i(cols - 2, rows / 2) if cols >= rows else Vector2i(cols / 2, rows - 2)
	for a_v in ectx.actors:
		if a_v is Dictionary and bool(a_v.get("is_spirit", false)):
			a_v["grid_pos"] = { "col": far_cell.x, "row": far_cell.y }
	realm.set_snapshot(_snapshot(fx["env"]))
	_step(fx, 6.0)
	var moved_spirit := _actor_where(fx, func(a): return bool(a.get("is_spirit", false)))
	var drawn := _token_viewport_pos(fx, moved_spirit)
	var travelled := cam.position.distance_to(start_cam)
	var mode := cam.mode
	vp.free()
	if _cell(moved_spirit) != far_cell:
		return { "ok": false, "error": "Rebuilt snapshot did not carry the spirit move; premise failed" }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		return { "ok": false, "error": "Lock dropped when the spirit moved (mode %d)" % mode }
	if travelled < 1000.0:
		return { "ok": false, "error": "Camera travelled only %s px along the stretched board" % travelled }
	if drawn.distance_to(_CENTER) > 2.0:
		return { "ok": false, "error": "Camera did not follow the spirit to the far end (drawn at %s)" % drawn }
	return { "ok": true }


# RealmShell is hidden, not freed, while Sanctum is active. The combat camera must not keep
# driving the viewport, and the board layer must not keep drawing.
static func _t_hidden_screen_disables_camera_and_board() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var world := combat.get_node("WorldLayer") as CanvasLayer
	var shown_ok := cam.enabled and world.visible
	(fx["realm"] as RealmShell).visible = false
	var hidden_ok := not cam.enabled and not world.visible
	(fx["realm"] as RealmShell).visible = true
	var reshown_ok := cam.enabled and world.visible
	(fx["viewport"] as SubViewport).free()
	if not shown_ok:
		return { "ok": false, "error": "Visible combat screen has camera or board layer off" }
	if not hidden_ok:
		return { "ok": false, "error": "Hiding RealmShell left the combat camera enabled or the board layer visible" }
	if not reshown_ok:
		return { "ok": false, "error": "Showing RealmShell again did not restore the camera and board layer" }
	return { "ok": true }


# Bark bubbles stay screen-space. When the camera pans, the screen's own _process must move a live
# bubble by the same screen distance as its token.
static func _t_bark_anchor_tracks_token_on_screen() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var combat := fx["combat"] as CombatBoardScreen
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var echo_id := str(echo.get("id", ""))
	var token_before := _frame_token(fx, echo, Vector2.ZERO)
	var layer := combat.get_node("%BarkPopupLayer")
	layer.call("show_barks", [{ "actor_id": echo_id, "bark_line": "Stay close.", "bark_context": "",
			"bark_tier": "", "bark_priority": 1, "is_response": false, "screen_pos": token_before }])
	var entry: Dictionary = (layer.get("_active_popups") as Dictionary).get(echo_id, {})
	var popup := entry.get("node") as Control
	if popup == null:
		vp.free()
		return { "ok": false, "error": "Bark popup was not created; premise failed" }
	_step(fx, 0.05)
	var popup_before := popup.position
	# A real drag pan through the screen root.
	var start := _empty_point_near_centre(combat)
	_push_left_button(vp, start, true)
	_push_motion(vp, start + Vector2(30, 0), Vector2(30, 0))
	_push_motion(vp, start + Vector2(110, 40), Vector2(80, 40))
	_push_left_button(vp, start + Vector2(110, 40), false)
	_step(fx, 0.05)
	var token_moved := _token_viewport_pos(fx, echo) - token_before
	var popup_moved := popup.position - popup_before
	vp.free()
	if token_moved.length() < 50.0:
		return { "ok": false, "error": "Pan moved the token only %s; premise failed" % token_moved }
	if popup_moved.distance_to(token_moved) > 0.5:
		return { "ok": false, "error": "Bubble moved %s on screen, token moved %s" % [popup_moved, token_moved] }
	return { "ok": true }


# Sanctum and Combat each own a Camera2D in the one root viewport. AppRoot._show_screen() hides
# every shell, then shows one; the shown shell's camera must be the one driving the viewport.
static func _t_shell_swap_hands_viewport_to_shown_camera() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var realm := fx["realm"] as RealmShell
	var combat_cam := fx["camera"] as BoardCameraController
	var sanctum := (load("res://ui/shells/SanctumShell.tscn") as PackedScene).instantiate() as SanctumShell
	(realm.get_parent() as CanvasLayer).add_child(sanctum)
	sanctum.set_layout(_LAYOUT)
	sanctum.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 1 }, "data": {}, "actions": {} })
	var steps := [
		{ "show": sanctum, "want": sanctum.camera },
		{ "show": realm, "want": combat_cam },
		{ "show": sanctum, "want": sanctum.camera },
	]
	combat_cam.zoom = Vector2(0.7, 0.7)
	sanctum.camera.zoom = Vector2(1.9, 1.9)
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
	vp.free()
	return { "ok": true }


# Two fingers moving apart (a pinch) must neither pan nor count as a tap. Finger 0's release
# would otherwise be a tap on empty board and drop the lock. After finger 1 lifts, finger 0 pans
# again from where it is, with no jump.
static func _t_two_finger_pinch_does_not_pan_or_tap() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var a := _empty_point_near_centre(combat)
	if a == Vector2.INF or not _is_empty_point(combat, a):
		vp.free()
		return { "ok": false, "error": "No empty board point; premise failed" }
	var b := a + Vector2(60, 0)
	var cam_before := cam.position
	_push_touch(vp, 0, a, true)
	_push_touch(vp, 1, b, true)
	for i in range(1, 4):
		_push_touch_drag(vp, 0, a - Vector2(10 * i, 0), Vector2(-10, 0))
		_push_touch_drag(vp, 1, b + Vector2(10 * i, 0), Vector2(10, 0))
	var pinch_moved := cam.position - cam_before
	_push_touch(vp, 1, b + Vector2(30, 0), false)
	var a_now := a - Vector2(30, 0)
	_push_touch_drag(vp, 0, a_now + Vector2(20, 0), Vector2(20, 0))
	_push_touch_drag(vp, 0, a_now + Vector2(60, 0), Vector2(40, 0))
	var after_lift := cam.position - cam_before
	var expected_after := -Vector2(60, 0) / cam.zoom.x
	_push_touch(vp, 0, a_now + Vector2(60, 0), false)
	var mode := cam.mode
	var target := cam.target_id
	# Second pinch: finger 0 never moves past the threshold and lifts first. Its release must not
	# be a tap on empty board, which would drop the lock.
	_push_touch(vp, 0, a, true)
	_push_touch(vp, 1, b, true)
	_push_touch_drag(vp, 1, b + Vector2(40, 0), Vector2(40, 0))
	_push_touch(vp, 0, a, false)
	_push_touch(vp, 1, b + Vector2(40, 0), false)
	var mode2 := cam.mode
	var target2 := cam.target_id
	vp.free()
	if mode2 != BoardCameraController.Mode.FOLLOW_ACTOR or target2 != str(echo.get("id", "")):
		return { "ok": false, "error": "Second pinch: finger 0 release acted as a tap (mode %d, target '%s')" % [mode2, target2] }
	if not pinch_moved.is_zero_approx():
		return { "ok": false, "error": "Two-finger pinch moved the camera by %s" % pinch_moved }
	if not after_lift.is_equal_approx(expected_after):
		return { "ok": false, "error": "One-finger pan after the pinch moved %s, expected %s" % [after_lift, expected_after] }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != str(echo.get("id", "")):
		return { "ok": false, "error": "Pinch release acted as a tap (mode %d, target '%s')" % [mode, target] }
	return { "ok": true }


# Pinch gesture (trackpad magnify) on Combat: unlocked it zooms; locked it zooms and starts the
# 3 s follow hold (decisions.md #72).
static func _t_magnify_zooms_and_holds_lock() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"])
	var zoom_before := cam.zoom
	var ev := InputEventMagnifyGesture.new()
	ev.position = point
	ev.factor = 0.8
	vp.push_input(ev, true)
	var free_zoomed := not cam.zoom.is_equal_approx(zoom_before)
	var free_held := cam.is_follow_held()
	var echo := _actor_where(fx, func(a): return str(a.get("faction", "")) == "echo" and _is_living(a))
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var locked_zoom_before := cam.zoom
	var ev2 := InputEventMagnifyGesture.new()
	ev2.position = point
	ev2.factor = 1.2
	vp.push_input(ev2, true)
	var locked_zoomed := not cam.zoom.is_equal_approx(locked_zoom_before)
	var locked_held := cam.is_follow_held()
	vp.free()
	if not free_zoomed:
		return { "ok": false, "error": "Magnify on a FREE combat camera did not zoom" }
	if free_held:
		return { "ok": false, "error": "Magnify on a FREE camera started a follow hold" }
	if not locked_zoomed or not locked_held:
		return { "ok": false, "error": "Magnify on a locked camera: zoomed=%s held=%s, want both" % [locked_zoomed, locked_held] }
	return { "ok": true }


# The locked actor dies -> the camera follows the party (ANSWERS.md #78). Killed through ectx, snapshot rebuilt
# by the production builder.
static func _t_locked_actor_dies_falls_back_to_party() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var echo := _living_echoes(fx)[0] as Dictionary
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	_kill(fx, str(echo.get("id", "")))
	_refresh(fx)
	var mode := cam.mode
	_step(fx, 4.0)
	var want := cam.clamped_position(_party_centroid_world(fx), cam.zoom)
	var got := cam.position
	vp.free()
	if mode != BoardCameraController.Mode.FOLLOW_PARTY:
		return { "ok": false, "error": "Locked actor died; camera mode %d, want FOLLOW_PARTY" % mode }
	if got.distance_to(want) > 1.0:
		return { "ok": false, "error": "After the death the camera is at %s, living party centroid %s" % [got, want] }
	return { "ok": true }


# ANSWERS.md #78: a dead actor cannot be locked. A tap on its cell, its card or its initiative
# row changes nothing.
static func _t_dead_actor_board_card_and_row_do_nothing() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echoes := _living_echoes(fx)
	var dead_id := str((echoes[1] as Dictionary).get("id", ""))
	var keeper := echoes[0] as Dictionary
	_kill(fx, dead_id)
	_refresh(fx)
	var dead := _actor_where(fx, func(a): return str(a.get("id", "")) == dead_id)
	if _is_living(dead) or (combat.call("_actors_on_cell", _cell(dead)) as Array).size() != 1:
		vp.free()
		return { "ok": false, "error": "Dead echo not alone on its cell, or not dead in the snapshot; premise failed" }
	var err := _check_tap_locks_and_follows(fx, keeper, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var keeper_id := str(keeper.get("id", ""))
	_tap(vp, _frame_token(fx, dead, Vector2(120, 40)))
	var after_token := [cam.mode, cam.target_id]
	# Party cards follow actors order (faction echo or ally); dead echoes keep their card.
	var card_index := -1
	var i := 0
	for a_v in combat.get("_last_actors"):
		if a_v is Dictionary and (str(a_v.get("faction", "")) == "echo" or bool(a_v.get("is_ally", false))) \
				and not bool(a_v.get("is_spirit", false)):
			if str(a_v.get("id", "")) == dead_id:
				card_index = i
			i += 1
	var cards: Array = []
	for child in (fx["realm"] as RealmShell).get_node("%EchoBar").get_children():
		if not child.is_queued_for_deletion():
			cards.append(child)
	var card := cards[card_index] as Control
	var scroll := (fx["realm"] as RealmShell).get_node("%EchoBarScroll") as ScrollContainer
	scroll.scroll_horizontal = int(card.position.x)
	SanctumLayoutTests._force_control_layout(fx["realm"])
	_tap(vp, card.get_global_rect().get_center())
	var after_card := [cam.mode, cam.target_id]
	# The dead echo's initiative row.
	var order: Array = (fx["snap"] as Dictionary).get("data", {}).get("initiative_order", [])
	var rows: Array = []
	for child in (combat.get("_initiative_list") as VBoxContainer).get_children():
		if not child.is_queued_for_deletion():
			rows.append(child)
	SanctumLayoutTests._force_control_layout(combat)
	var row_index := -1
	for idx in range(order.size()):
		if str((order[idx] as Dictionary).get("id", "")) == dead_id:
			row_index = idx
	if row_index < 0 or rows.size() != order.size():
		vp.free()
		return { "ok": false, "error": "Dead echo has no initiative row; premise failed" }
	_tap(vp, (rows[row_index] as Control).get_global_rect().get_center())
	var after_row := [cam.mode, cam.target_id]
	vp.free()
	var want := [BoardCameraController.Mode.FOLLOW_ACTOR, keeper_id]
	if after_row != want:
		return { "ok": false, "error": "Tap on a dead echo's initiative row changed the lock to %s, want %s" % [after_row, want] }
	if after_token != want:
		return { "ok": false, "error": "Tap on a dead actor's cell changed the lock to %s, want %s" % [after_token, want] }
	if after_card != want:
		return { "ok": false, "error": "Press on a dead echo's card changed the lock to %s, want %s" % [after_card, want] }
	return { "ok": true }


# A living and a dead actor on one cell: the tap selects the living one, whichever comes first
# in the actors array.
static func _t_living_wins_over_dead_on_one_cell() -> Dictionary:
	for dead_first in [true, false]:
		var fx := _make_fixture(EncounterResolutionModes.COMBAT)
		if fx.is_empty():
			return { "ok": false, "error": "Fixture failed" }
		var vp := fx["viewport"] as SubViewport
		var cam := fx["camera"] as BoardCameraController
		var living_id := str((_living_echoes(fx)[0] as Dictionary).get("id", ""))
		var dead_id := str(_actor_where(fx, func(a): return str(a.get("faction", "")) == "enemy" \
				and not bool(a.get("is_structure", false))).get("id", ""))
		var living := _ectx_actor(fx, living_id)
		var dead := _ectx_actor(fx, dead_id)
		_kill(fx, dead_id)
		dead["grid_pos"] = (living["grid_pos"] as Dictionary).duplicate()
		var actors: Array = (fx["env"] as Dictionary)["ectx"].actors
		actors.erase(dead)
		var at := actors.find(living)
		actors.insert(at if dead_first else at + 1, dead)
		_refresh(fx)
		var snap_living := _actor_where(fx, func(a): return str(a.get("id", "")) == living_id)
		var on_cell: Array = (fx["combat"] as CombatBoardScreen).call("_actors_on_cell", _cell(snap_living))
		if on_cell.size() != 2:
			vp.free()
			return { "ok": false, "error": "Expected 2 actors on the shared cell, got %d; premise failed" % on_cell.size() }
		_tap(vp, _frame_token(fx, snap_living, Vector2(120, 40)))
		var mode := cam.mode
		var target := cam.target_id
		vp.free()
		if mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != living_id:
			return { "ok": false, "error": "dead_first=%s: tap gave mode %d target '%s', want living '%s'" % [dead_first, mode, target, living_id] }
	return { "ok": true }


# A second encounter on the same mounted screen starts FREE, at the origin and the default zoom,
# even after the player panned, zoomed and locked in the first one.
static func _t_new_encounter_resets_camera() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echo := _living_echoes(fx)[0] as Dictionary
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	cam.zoom = Vector2(0.7, 0.7)
	cam.position += Vector2(150, 80)
	var env2 := _make_encounter(EncounterResolutionModes.ENDURE)
	var snap2 := _snapshot(env2)
	var id1 := str((fx["snap"] as Dictionary).get("data", {}).get("encounter_id", ""))
	var id2 := str(snap2.get("data", {}).get("encounter_id", ""))
	if id1 == id2 or id2.is_empty():
		vp.free()
		return { "ok": false, "error": "Second encounter id '%s' is not new; premise failed" % id2 }
	(fx["realm"] as RealmShell).set_snapshot(snap2)
	var same_screen: bool = (fx["realm"] as RealmShell).get("_active_overlay") == combat
	var mode := cam.mode
	var pos := cam.position
	var zoom := cam.zoom.x
	vp.free()
	if not same_screen:
		return { "ok": false, "error": "RealmShell replaced the combat screen; the reset path was not exercised" }
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "New encounter kept camera mode %d, want FREE" % mode }
	if not pos.is_zero_approx():
		return { "ok": false, "error": "New encounter kept camera position %s, want origin" % pos }
	if not is_equal_approx(zoom, 1.3):
		return { "ok": false, "error": "New encounter kept zoom %s, want 1.3" % zoom }
	return { "ok": true }




# Real hover first (a motion event), then one wheel notch, both through push_input.
static func _push_wheel(vp: SubViewport, pos: Vector2, up: bool, factor: float = 1.0) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	vp.push_input(mm, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.factor = factor
		ev.pressed = pressed
		vp.push_input(ev, true)


# One wheel notch, then frames until the zoom ease has finished.
static func _wheel_settled(fx: Dictionary, pos: Vector2, up: bool, factor: float = 1.0) -> void:
	_push_wheel(fx["viewport"], pos, up, factor)
	_step(fx, 1.0)


# Where a world point is drawn on screen under the current camera.
static func _world_to_screen(fx: Dictionary, world: Vector2) -> Vector2:
	var cam := fx["camera"] as BoardCameraController
	cam.force_update_scroll()
	return (fx["viewport"] as SubViewport).get_canvas_transform() * world


static func _screen_to_world(fx: Dictionary, screen: Vector2) -> Vector2:
	var cam := fx["camera"] as BoardCameraController
	cam.force_update_scroll()
	return (fx["viewport"] as SubViewport).get_canvas_transform().affine_inverse() * screen


# One notch multiplies or divides zoom by 1.1, clamped to the pinch range.
static func _t_wheel_steps_zoom_and_stops_at_limits() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"])
	var z0 := cam.zoom.x
	_wheel_settled(fx, point, true)
	var z_up := cam.zoom.x
	_wheel_settled(fx, point, false)
	var z_back := cam.zoom.x
	for i in range(40):
		_wheel_settled(fx, point, true)
	var z_max := cam.zoom.x
	for i in range(80):
		_wheel_settled(fx, point, false)
	var z_min := cam.zoom.x
	var want_min: float = cam.get("_min_zoom")
	vp.free()
	if not is_equal_approx(z_up, z0 * 1.1):
		return { "ok": false, "error": "Wheel up over open board: zoom %s -> %s, want x1.1" % [z0, z_up] }
	if not is_equal_approx(z_back, z0):
		return { "ok": false, "error": "Wheel down did not undo wheel up (%s, want %s)" % [z_back, z0] }
	if not is_equal_approx(z_max, 2.2):
		return { "ok": false, "error": "Wheel zoom-in stopped at %s, want max 2.2" % z_max }
	if not is_equal_approx(z_min, want_min):
		return { "ok": false, "error": "Wheel zoom-out stopped at %s, want min %s" % [z_min, want_min] }
	return { "ok": true }


# Over the initiative panel and the echo bar the hovered control is not the board, so the wheel
# must not zoom. The echo bar overflows here (GUIDE_SPIRIT: 5 echoes + spirit).
static func _t_wheel_over_panels_does_not_zoom() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.GUIDE_SPIRIT, "escort")
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var panel := combat.get("_initiative_panel") as Control
	var scroll := (fx["realm"] as RealmShell).get_node("%EchoBarScroll") as ScrollContainer
	if not panel.is_visible_in_tree() or scroll.get_h_scroll_bar().max_value <= scroll.get_h_scroll_bar().page:
		vp.free()
		return { "ok": false, "error": "Initiative panel hidden or echo bar not overflowing; premise failed" }
	var z0 := cam.zoom
	_wheel_settled(fx, panel.get_global_rect().get_center(), true)
	var z_panel := cam.zoom
	var bar_point := scroll.get_global_rect().get_center()
	var h_before := scroll.scroll_horizontal
	_wheel_settled(fx, bar_point, false)
	var z_bar := cam.zoom
	var hovered_bar := vp.gui_get_hovered_control()
	var in_bar := hovered_bar != null and scroll.is_ancestor_of(hovered_bar)
	var bar_scrolled := scroll.scroll_horizontal > h_before
	vp.free()
	if z_panel != z0:
		return { "ok": false, "error": "Wheel over the initiative panel zoomed the board (%s -> %s)" % [z0, z_panel] }
	if z_bar != z0:
		return { "ok": false, "error": "Wheel over the echo bar zoomed the board (%s -> %s)" % [z0, z_bar] }
	if not in_bar:
		return { "ok": false, "error": "Echo bar point was not hovering inside the scroll area; premise failed" }
	if not bar_scrolled:
		return { "ok": false, "error": "Wheel over the echo bar did not scroll it; the bar lost its wheel" }
	return { "ok": true }


# FREE: the world point under the cursor stays under the cursor (wheel and pinch alike).
static func _t_wheel_free_zooms_toward_pointer() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"]) + Vector2(40, 30)
	if point.distance_to(_CENTER) < 100.0:
		vp.free()
		return { "ok": false, "error": "Pointer too close to the centre to tell pointer zoom from centre zoom" }
	var errors: Array = []
	for step in ["wheel_up", "wheel_down", "pinch_out"]:
		var world := _screen_to_world(fx, point)
		var zoom_before := cam.zoom.x
		var worst := 0.0
		match step:
			"wheel_up", "wheel_down":
				_push_wheel(vp, point, step == "wheel_up")
				# The ease runs over frames; the point must stay under the cursor at every frame.
				for i in range(20):
					cam._process(0.05)
					worst = maxf(worst, _world_to_screen(fx, world).distance_to(point))
			"pinch_out":
				var ev := InputEventMagnifyGesture.new()
				ev.position = point
				ev.factor = 1.25
				vp.push_input(ev, true)
		if worst > 0.5:
			errors.append("%s let the world point drift %s px from the cursor during the ease" % [step, worst])
		var drawn := _world_to_screen(fx, world)
		if is_equal_approx(cam.zoom.x, zoom_before):
			errors.append("%s did not zoom" % step)
		elif drawn.distance_to(point) > 0.5:
			errors.append("%s moved the world point under the cursor to %s (cursor %s)" % [step, drawn, point])
	var mode := cam.mode
	vp.free()
	if mode != BoardCameraController.Mode.FREE:
		return { "ok": false, "error": "Zoom changed the camera mode to %d" % mode }
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Locked: the wheel zooms about the centre, so the target stays centred, and starts the hold.
static func _t_wheel_locked_keeps_target_centred() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var echo := _living_echoes(fx)[0] as Dictionary
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var point := _empty_point_near_centre(fx["combat"])
	var z0 := cam.zoom.x
	_wheel_settled(fx, point, true)
	var zoomed := not is_equal_approx(cam.zoom.x, z0)
	var held := cam.is_follow_held()
	var drawn := _token_viewport_pos(fx, echo)
	var mode := cam.mode
	vp.free()
	if not zoomed:
		return { "ok": false, "error": "Wheel on a locked camera did not zoom" }
	if not held:
		return { "ok": false, "error": "Wheel on a locked camera did not start the follow hold" }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		return { "ok": false, "error": "Wheel released the lock (mode %d)" % mode }
	if drawn.distance_to(_CENTER) > 2.0:
		return { "ok": false, "error": "Wheel moved the locked target off centre (drawn at %s)" % drawn }
	return { "ok": true }


# Sanctum uses the same wheel rule as Combat: wheel_zoom_step 1.1, eased (2.0 -> 2.2 per notch).
static func _t_sanctum_wheel_uses_shared_rule() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if host == null:
		return { "ok": false, "error": "Fixture host unavailable" }
	var vp := SubViewport.new()
	vp.size = _VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var sanctum := (load("res://ui/shells/SanctumShell.tscn") as PackedScene).instantiate() as SanctumShell
	vp.add_child(sanctum)
	sanctum.set_layout(_LAYOUT)
	sanctum.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 1 }, "data": {}, "actions": {} })
	SanctumLayoutTests._force_control_layout(sanctum)
	var step := sanctum.camera.wheel_zoom_step
	var zoom_before := sanctum.camera.zoom
	_push_wheel(vp, Vector2(640, 300), true)
	for i in range(20):
		sanctum.camera._process(0.05)
	var zoom_after := sanctum.camera.zoom
	vp.free()
	if not is_equal_approx(step, 1.1):
		return { "ok": false, "error": "Sanctum camera wheel_zoom_step is %s, want 1.1" % step }
	if not zoom_before.is_equal_approx(Vector2(2.0, 2.0)) or not zoom_after.is_equal_approx(Vector2(2.2, 2.2)):
		return { "ok": false, "error": "Sanctum wheel: zoom %s -> %s; want one notch, 2.0 -> 2.2" % [zoom_before, zoom_after] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Real engine input: Input.parse_input_event() in the root window, so the engine itself makes the
# emulated touch0 twin of each mouse event (emulate_touch_from_mouse). push_input() cannot.
# ---------------------------------------------------------------------------

class InputSpy extends Node:
	var seen: Array = []
	func _input(event: InputEvent) -> void:
		seen.append(event.get_class())


static func _parse(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


static func _parse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.pressed = pressed
	_parse(ev)


static func _parse_motion(pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_parse(ev)


static func _parse_drag(start: Vector2) -> void:
	_parse_button(start, true)
	_parse_motion(start + Vector2(20, 0), Vector2(20, 0))
	_parse_motion(start + Vector2(60, 0), Vector2(40, 0))
	_parse_button(start + Vector2(60, 0), false)


# (a) plain mouse drag pans 1:1 once, (b) Space+LMB drag pans 1:1 once and a Space click
# keeps the lock, (c) a plain click on a token selects it.
static func _t_engine_emulated_pointer_end_to_end() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var root := tree.root
	var env := _make_encounter(EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return { "ok": false, "error": "Encounter setup failed" }
	var size := root.get_visible_rect().size
	var host := tree.current_scene.get_node_or_null("UISnapshotRenderer")
	if host == null:
		return { "ok": false, "error": "Fixture host unavailable" }
	# Under the root window's own canvas (no SubViewport). The root itself is busy in AppRoot._ready.
	var layer := CanvasLayer.new()
	layer.layer = 60
	host.add_child(layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	layer.add_child(realm)
	realm.set_layout({ "profile": &"standard", "safe_insets": Vector4.ZERO, "logical_size": size })
	realm.set_snapshot(_snapshot(env))
	SanctumLayoutTests._force_control_layout(realm)
	var combat := realm.get("_active_overlay") as CombatBoardScreen
	var cam := combat.camera
	var previous_cam := root.get_camera_2d()
	cam.make_current()
	var spy := InputSpy.new()
	host.add_child(spy)
	var fx := { "env": env, "viewport": root, "realm": realm, "combat": combat, "camera": cam }
	var centre := size * 0.5
	var errors: Array = []

	var start := _empty_point_near_centre(combat, centre)
	if start == Vector2.INF:
		errors.append("No empty board point; premise failed")
	else:
		# (a) plain drag
		var before := cam.position
		spy.seen.clear()
		_parse_drag(start)
		var pan_a := cam.position - before
		var want := -Vector2(60, 0) / cam.zoom.x
		if not spy.seen.has("InputEventScreenTouch") or not spy.seen.has("InputEventScreenDrag"):
			errors.append("Engine did not emulate touch from mouse (saw %s); premise failed" % [spy.seen])
		elif spy.seen.find("InputEventScreenTouch") > spy.seen.find("InputEventMouseButton"):
			errors.append("Engine sent the mouse event before its touch twin (%s); premise changed" % [spy.seen])
		if not pan_a.is_equal_approx(want):
			errors.append("(a) plain drag panned %s, want %s" % [pan_a, want])
		if cam.mode != BoardCameraController.Mode.FREE:
			errors.append("(a) plain drag changed mode to %d" % cam.mode)

		# (b) Space+LMB drag while locked, then Space click with no motion
		var echo := _living_echoes(fx)[0] as Dictionary
		cam.select(str(echo.get("id", "")))
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.physical_keycode = KEY_SPACE
		space.pressed = true
		_parse(space)
		before = cam.position
		_parse_drag(start)
		var pan_b := cam.position - before
		_parse_button(start, true)
		_parse_button(start, false)
		var space_up := space.duplicate() as InputEventKey
		space_up.pressed = false
		_parse(space_up)
		if not pan_b.is_equal_approx(want):
			errors.append("(b) Space+LMB drag panned %s, want %s" % [pan_b, want])
		if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != str(echo.get("id", "")):
			errors.append("(b) Space+LMB lost the lock (mode %d, target '%s')" % [cam.mode, cam.target_id])

		# (c) plain click on a token
		cam.deselect()
		var other := _living_echoes(fx)[1] as Dictionary
		var point := _frame_token(fx, other, Vector2(120, 40))
		_parse_button(point, true)
		_parse_button(point, false)
		if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != str(other.get("id", "")):
			errors.append("(c) plain click did not select (mode %d, target '%s')" % [cam.mode, cam.target_id])

	spy.free()
	layer.free()
	if previous_cam != null and is_instance_valid(previous_cam):
		previous_cam.make_current()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Finger 1 lands on an initiative row, which takes every touch, so the screen root never sees
# it. Finger 0 on the board must still stop panning, and its release must not be a tap.
static func _t_second_finger_on_chrome_stops_pan() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echo := _living_echoes(fx)[0] as Dictionary
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		vp.free()
		return { "ok": false, "error": err }
	var list := combat.get("_initiative_list") as VBoxContainer
	SanctumLayoutTests._force_control_layout(combat)
	var row: Control = null
	for child in list.get_children():
		if not child.is_queued_for_deletion():
			row = child
	var a := _empty_point_near_centre(combat)
	if row == null or a == Vector2.INF:
		vp.free()
		return { "ok": false, "error": "No initiative row or empty board point; premise failed" }
	var b := row.get_global_rect().get_center()
	var cam_before := cam.position
	_push_touch(vp, 0, a, true)
	_push_touch(vp, 1, b, true)
	for i in range(1, 4):
		_push_touch_drag(vp, 0, a - Vector2(10 * i, 0), Vector2(-10, 0))
		_push_touch_drag(vp, 1, b + Vector2(10 * i, 0), Vector2(10, 0))
	var moved := cam.position - cam_before
	_push_touch(vp, 0, a - Vector2(30, 0), false)
	_push_touch(vp, 1, b + Vector2(30, 0), false)
	var mode := cam.mode
	var target := cam.target_id
	var down: Dictionary = combat.get("_touches_down")
	var leftover := down.size()
	vp.free()
	if not moved.is_zero_approx():
		return { "ok": false, "error": "Finger 0 kept panning while finger 1 was on a row (moved %s)" % moved }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or target != str(echo.get("id", "")):
		return { "ok": false, "error": "Pinch with a finger on chrome acted as a tap (mode %d, target '%s')" % [mode, target] }
	if leftover != 0:
		return { "ok": false, "error": "%d fingers still counted after both lifted" % leftover }
	return { "ok": true }


# Zoom scales with the event factor; an ordinary notch (1.0) and an unsupported factor (0) are one step.
static func _t_wheel_scales_with_event_factor() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"])
	var cases := [[1.0, 1.1], [0.5, sqrt(1.1)], [0.0, 1.1], [3.0, pow(1.1, 3.0)]]
	var errors: Array = []
	for c in cases:
		cam.zoom = Vector2(1.0, 1.0)
		_wheel_settled(fx, point, true, c[0])
		if not is_equal_approx(cam.zoom.x, c[1]):
			errors.append("factor %s: zoom %s, want %s" % [c[0], cam.zoom.x, c[1]])
	cam.zoom = Vector2(1.0, 1.0)
	_wheel_settled(fx, point, false, 0.5)
	if not is_equal_approx(cam.zoom.x, 1.0 / sqrt(1.1)):
		errors.append("wheel down factor 0.5: zoom %s, want %s" % [cam.zoom.x, 1.0 / sqrt(1.1)])
	cam.zoom = Vector2(2.1, 2.1)
	_wheel_settled(fx, point, true, 3.0)
	if not is_equal_approx(cam.zoom.x, 2.2):
		errors.append("factor 3.0 near max: zoom %s, want clamp 2.2" % cam.zoom.x)
	var min_zoom: float = cam.get("_min_zoom")
	cam.zoom = Vector2(min_zoom * 1.05, min_zoom * 1.05)
	_wheel_settled(fx, point, false, 3.0)
	if not is_equal_approx(cam.zoom.x, min_zoom):
		errors.append("factor 3.0 near min: zoom %s, want clamp %s" % [cam.zoom.x, min_zoom])
	# Factor 0 means "not supported": it is one ordinary notch, so on a locked camera it starts the
	# hold like any manual zoom.
	cam.select(str((_living_echoes(fx)[0] as Dictionary).get("id", "")))
	_wheel_settled(fx, point, true, 0.0)
	if not cam.is_follow_held():
		errors.append("factor 0 on a locked camera did not start the follow hold")
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# A screen that sets wheel_surface but keeps wheel_zoom_step 0 gets no wheel zoom.
static func _t_wheel_step_zero_with_surface_is_off() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	cam.wheel_zoom_step = 0.0
	if cam.wheel_surface == null:
		vp.free()
		return { "ok": false, "error": "wheel_surface is not set; premise failed" }
	var z0 := cam.zoom
	_push_wheel(vp, _empty_point_near_centre(fx["combat"]), true)
	var z1 := cam.zoom
	vp.free()
	if z1 != z0:
		return { "ok": false, "error": "Wheel zoomed with wheel_zoom_step 0 (%s -> %s)" % [z0, z1] }
	return { "ok": true }


# A speech bubble over the board is visual only, in all three templates (original, reaction,
# divergence). The wheel over it zooms, and a tap on the token under it selects that token.
static func _t_bubble_does_not_block_wheel_or_tap() -> Dictionary:
	var kinds := [
		{ "kind": "original",   "is_response": false, "context": "" },
		{ "kind": "reaction",   "is_response": true,  "context": "" },
		{ "kind": "divergence", "is_response": false, "context": "combat_divergence" },
	]
	for k in kinds:
		var err := _check_bubble_passes_input(k)
		if not err.is_empty():
			return { "ok": false, "error": err }
	return { "ok": true }


static func _check_bubble_passes_input(k: Dictionary) -> String:
	var kind := str(k["kind"])
	if BarkPopupLayer.resolve_template_kind(str(k["context"]), bool(k["is_response"])) != kind:
		return "%s: event does not resolve to the %s template; premise failed" % [kind, kind]
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return "Fixture failed"
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var echoes := _living_echoes(fx)
	var target := echoes[1] as Dictionary
	var point := _frame_token(fx, target, Vector2(120, 40))
	var layer := combat.get_node("%BarkPopupLayer")
	# The bubble belongs to another echo but is centred on the target token. _show_bark_popup is
	# the layer's own path; show_barks delays reactions behind a timer that does not run here.
	var offset: Vector2 = BarkPopupLayer.REACTION_OFFSET if kind == "reaction" else BarkPopupLayer.ORIGINAL_OFFSET
	var speaker_id := str((echoes[0] as Dictionary).get("id", ""))
	layer.call("_show_bark_popup", { "actor_id": speaker_id, "bark_line": "Watch the left side.",
			"bark_context": k["context"], "bark_tier": "", "bark_priority": 1,
			"is_response": k["is_response"], "screen_pos": point - offset })
	var popup := ((layer.get("_active_popups") as Dictionary).get(speaker_id, {}) as Dictionary).get("node") as Control
	SanctumLayoutTests._force_control_layout(combat)
	if popup == null or not popup.get_global_rect().has_point(point):
		vp.free()
		return "%s: bubble does not cover the token point; premise failed" % kind
	var z0 := cam.zoom.x
	_push_wheel(vp, point, true)
	var hovered_control := vp.gui_get_hovered_control()
	_step(fx, 1.0)
	var hovered := str(hovered_control.name) if hovered_control != null else "null"
	var zoomed := not is_equal_approx(cam.zoom.x, z0)
	cam.zoom = Vector2(z0, z0)
	point = _frame_token(fx, target, Vector2(120, 40))
	popup.position = point - popup.size * 0.5
	var still_covered := popup.get_global_rect().has_point(point)
	_tap(vp, point)
	var mode := cam.mode
	var got := cam.target_id
	vp.free()
	if not zoomed:
		return "%s: wheel over a bubble did not zoom (hovered %s)" % [kind, hovered]
	if not still_covered:
		return "%s: bubble moved off the token before the tap; premise failed" % kind
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or got != str(target.get("id", "")):
		return "%s: tap through a bubble did not select the token (mode %d, target '%s')" % [kind, mode, got]
	return ""


# Two fingers and the mouse go down on open board and their releases never arrive, as when the
# window loses focus mid-drag.
static func _leave_pointers_stuck(fx: Dictionary) -> void:
	var vp := fx["viewport"] as SubViewport
	var p := _empty_point_near_centre(fx["combat"])
	_push_touch(vp, 0, p, true)
	_push_touch(vp, 1, p + Vector2(40, 0), true)
	_push_left_button(vp, p, true)


# After a reset, a tap on a token selects it and a mouse drag on the board pans 1:1. "" on success.
static func _check_tap_and_drag_work(fx: Dictionary, label: String) -> String:
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var echo := _living_echoes(fx)[1] as Dictionary
	_tap(vp, _frame_token(fx, echo, Vector2(120, 40)))
	if cam.mode != BoardCameraController.Mode.FOLLOW_ACTOR or cam.target_id != str(echo.get("id", "")):
		return "%s: tap did not select (mode %d, target '%s')" % [label, cam.mode, cam.target_id]
	cam.deselect()
	var start := _empty_point_near_centre(fx["combat"])
	var before := cam.position
	_push_left_button(vp, start, true)
	_push_motion(vp, start + Vector2(20, 0), Vector2(20, 0))
	_push_motion(vp, start + Vector2(60, 0), Vector2(40, 0))
	_push_left_button(vp, start + Vector2(60, 0), false)
	var pan := cam.position - before
	var want := -Vector2(60, 0) / cam.zoom.x
	if not pan.is_equal_approx(want):
		return "%s: drag panned %s, want %s" % [label, pan, want]
	return ""


static func _t_focus_loss_resets_stuck_pointer() -> Dictionary:
	for what in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var fx := _make_fixture(EncounterResolutionModes.COMBAT)
		if fx.is_empty():
			return { "ok": false, "error": "Fixture failed" }
		_leave_pointers_stuck(fx)
		(fx["combat"] as CombatBoardScreen).notification(what)
		var err := _check_tap_and_drag_work(fx, "focus-out %d" % what)
		(fx["viewport"] as SubViewport).free()
		if not err.is_empty():
			return { "ok": false, "error": err }
	return { "ok": true }


static func _t_hide_resets_stuck_pointer() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	_leave_pointers_stuck(fx)
	var realm := fx["realm"] as RealmShell
	realm.visible = false
	realm.visible = true
	var err := _check_tap_and_drag_work(fx, "hide")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


static func _t_new_encounter_resets_stuck_pointer() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	_leave_pointers_stuck(fx)
	var env2 := _make_encounter(EncounterResolutionModes.ENDURE)
	fx["env"] = env2
	_refresh(fx)
	var err := _check_tap_and_drag_work(fx, "new encounter")
	(fx["viewport"] as SubViewport).free()
	return { "ok": err.is_empty(), "error": err }


# Through the real AppRoot._render_snapshot path. A second snapshot for the shown screen must not
# hide and re-show the shell, because that fires visibility_changed and the combat screen then
# drops a drag in progress. Leaving the screen is a real hide and must still reset the pointer.
# Uses the AppRoot that hosts this test run (a fresh one would start the runner again in _ready),
# and restores its previous screen afterwards.
static func _t_app_root_rerender_keeps_drag() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var app := tree.current_scene
	if app == null or not app.has_method("_render_snapshot"):
		return { "ok": false, "error": "AppRoot not available; premise failed" }
	var previous_snap: Dictionary = (app.get("_last_snapshot") as Dictionary).duplicate(true)
	var previous_type := str(previous_snap.get("type", ""))
	if app.get("_realm_shell") != null or previous_type in (app.get("VENTURE_FAMILY") as Array):
		return { "ok": false, "error": "AppRoot already shows a venture screen (%s); premise failed" % previous_type }
	var previous_cam := tree.root.get_camera_2d()
	var env := _make_encounter(EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return { "ok": false, "error": "Encounter setup failed" }
	app.call("_render_snapshot", _snapshot(env))
	var realm := app.get("_realm_shell") as RealmShell
	var combat := realm.get("_active_overlay") as CombatBoardScreen if realm != null else null
	var errors: Array = []
	if combat == null:
		errors.append("AppRoot did not mount the combat screen")
	elif bool((app.get("modal_host") as Node).call("has_active_modal")):
		errors.append("A modal is open over the board; premise failed")
	else:
		SanctumLayoutTests._force_control_layout(realm)
		combat.camera.make_current()
		var root := tree.root
		var start := _empty_point_near_centre(combat, root.get_visible_rect().size * 0.5)
		var press := InputEventMouseButton.new()
		press.position = start
		press.global_position = start
		press.button_index = MOUSE_BUTTON_LEFT
		press.button_mask = MOUSE_BUTTON_MASK_LEFT
		press.pressed = true
		root.push_input(press, true)
		var move := InputEventMouseMotion.new()
		move.position = start + Vector2(20, 0)
		move.global_position = move.position
		move.relative = Vector2(20, 0)
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(move, true)
		if not bool(combat.get("_drag_active")):
			errors.append("Drag did not start on the board in the root viewport; premise failed")
		else:
			# Second snapshot of the same encounter, as auto-play sends every actor step.
			app.call("_render_snapshot", _snapshot(env))
			var still_down := bool(combat.get("_drag_pointer_down")) and bool(combat.get("_drag_active"))
			var cam_before := combat.camera.position
			var move2 := move.duplicate() as InputEventMouseMotion
			move2.position = start + Vector2(60, 0)
			move2.global_position = move2.position
			move2.relative = Vector2(40, 0)
			root.push_input(move2, true)
			var pan := combat.camera.position - cam_before
			var want := -Vector2(40, 0) / combat.camera.zoom.x
			if not still_down:
				errors.append("A second snapshot render dropped the drag in progress")
			elif not pan.is_equal_approx(want):
				errors.append("Drag after the second render panned %s, want %s" % [pan, want])
			# Leave the screen with the drag still down: a real hide must reset the pointer.
			app.call("_render_snapshot", previous_snap)
			if realm.visible:
				errors.append("Leaving did not hide RealmShell; premise failed")
			elif bool(combat.get("_drag_pointer_down")) or not (combat.get("_touches_down") as Dictionary).is_empty():
				errors.append("Leaving the screen did not reset the pointer state")
		var release := press.duplicate() as InputEventMouseButton
		release.pressed = false
		release.button_mask = 0
		root.push_input(release, true)
	if realm != null:
		realm.free()
		app.set("_realm_shell", null)
	app.call("_render_snapshot", previous_snap)
	if previous_cam != null and is_instance_valid(previous_cam):
		previous_cam.make_current()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# One wheel notch eases the zoom over frames instead of jumping. Notches during an ease add up on
# the target. A pinch during the ease applies at once and stops the ease.
static func _t_wheel_zoom_eases_over_frames() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"])
	var errors: Array = []
	var z0 := cam.zoom.x
	_push_wheel(vp, point, true)
	if not is_equal_approx(cam.zoom.x, z0):
		errors.append("Zoom jumped on the notch itself (%s -> %s)" % [z0, cam.zoom.x])
	var seen: Array = []
	for i in range(30):
		cam._process(0.05)
		seen.append(cam.zoom.x)
	var first: float = seen[0]
	if not (first > z0 and first < z0 * 1.1 - 0.001):
		errors.append("First frame zoom %s is not between %s and %s" % [first, z0, z0 * 1.1])
	for i in range(1, seen.size()):
		if float(seen[i]) < float(seen[i - 1]):
			errors.append("Zoom went back during the ease at frame %d" % i)
			break
	if not is_equal_approx(float(seen[-1]), z0 * 1.1):
		errors.append("Ease ended at %s, want %s" % [seen[-1], z0 * 1.1])
	# Two quick notches add up.
	var z1 := cam.zoom.x
	_push_wheel(vp, point, true)
	cam._process(0.05)
	_push_wheel(vp, point, true)
	_step(fx, 1.5)
	if not is_equal_approx(cam.zoom.x, z1 * 1.21):
		errors.append("Two quick notches ended at %s, want %s" % [cam.zoom.x, z1 * 1.21])
	# A pinch during an ease applies at once and stops the ease.
	_push_wheel(vp, point, false)
	cam._process(0.05)
	var mid := cam.zoom.x
	var ev := InputEventMagnifyGesture.new()
	ev.position = point
	ev.factor = 1.2
	vp.push_input(ev, true)
	var after_pinch := cam.zoom.x
	_step(fx, 1.0)
	if not is_equal_approx(after_pinch, mid * 1.2):
		errors.append("Pinch during an ease gave %s, want immediate %s" % [after_pinch, mid * 1.2])
	if not is_equal_approx(cam.zoom.x, after_pinch):
		errors.append("Ease kept running after the pinch (%s -> %s)" % [after_pinch, cam.zoom.x])
	vp.free()
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# A click must not leave a combat button focused. Otherwise Space (ui_accept), held for a
# Space+drag, presses that button again.
static func _t_buttons_take_no_focus_from_clicks() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	var names := ["BackButton", "StartCombatButton", "AutoToggleButton", "SpeedBar/SpeedSlowButton",
			"SpeedBar/SpeedNormalButton", "SpeedBar/SpeedFastButton", "RecenterButton",
			"CombatResultOverlay/ResultContent/EndCombatButton"]
	for n in names:
		var b := combat.get_node_or_null(n) as BaseButton
		if b == null:
			errors.append("%s not found" % n)
		elif b.focus_mode != Control.FOCUS_NONE:
			errors.append("%s focus_mode is %d, want FOCUS_NONE" % [n, b.focus_mode])
	var button := combat.get_node("%RecenterButton") as Button
	if not button.is_visible_in_tree():
		vp.free()
		return { "ok": false, "error": "Recenter button hidden; premise failed" }
	var presses := [0]
	button.pressed.connect(func(): presses[0] += 1)
	_tap(vp, button.get_global_rect().get_center())
	var button_focused := vp.gui_get_focus_owner() == button
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		vp.push_input(key, true)
	var count: int = presses[0]
	vp.free()
	if count != 1:
		errors.append("Recenter pressed %d times after a click and a Space key, want 1" % count)
	if button_focused:
		errors.append("Click left the recenter button focused")
	if not errors.is_empty():
		return { "ok": false, "error": "; ".join(errors) }
	return { "ok": true }


# Finger 1's release never arrives after a pinch. A later finger-0 tap on a token still selects it.
# (The pinch rules themselves are asserted by the two pinch tests.)
static func _t_lost_touch_release_does_not_block_board() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var combat := fx["combat"] as CombatBoardScreen
	var a := _empty_point_near_centre(combat)
	# Pinch, then finger 0 lifts and finger 1's release is lost.
	_push_touch(vp, 0, a, true)
	_push_touch(vp, 1, a + Vector2(40, 0), true)
	_push_touch(vp, 0, a, false)
	var stuck := (combat.get("_touches_down") as Dictionary).size()
	var target := _living_echoes(fx)[1] as Dictionary
	var point := _frame_token(fx, target, Vector2(120, 40))
	_push_touch(vp, 0, point, true)
	_push_touch(vp, 0, point, false)
	var mode := cam.mode
	var got := cam.target_id
	vp.free()
	if stuck != 1:
		return { "ok": false, "error": "Expected one stuck finger before the tap, got %d; premise failed" % stuck }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR or got != str(target.get("id", "")):
		return { "ok": false, "error": "Tap after a lost release did not select (mode %d, target '%s')" % [mode, got] }
	return { "ok": true }


# A new zoom range (new encounter or resize) sets the zoom directly. A wheel ease still running
# from before must stop, or it would pull the zoom away from the new default.
static func _t_configure_zoom_range_cancels_wheel_ease() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	_push_wheel(vp, _empty_point_near_centre(fx["combat"]), true)
	cam._process(0.05)
	var easing: bool = float(cam.get("_zoom_target")) > 0.0
	var min_zoom: float = cam.get("_min_zoom")
	cam.configure_zoom_range(min_zoom, 2.2, 0.9)
	_step(fx, 1.0)
	var z := cam.zoom.x
	vp.free()
	if not easing:
		return { "ok": false, "error": "No wheel ease was running; premise failed" }
	if not is_equal_approx(z, 0.9):
		return { "ok": false, "error": "Zoom %s after configure_zoom_range(…, 0.9); the old wheel ease kept running" % z }
	return { "ok": true }


static func _push_z(vp: SubViewport) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_Z
		ev.physical_keycode = KEY_Z
		ev.unicode = 122
		ev.pressed = pressed
		vp.push_input(ev, true)


# Z, then frames until the zoom ease has finished. Returns the settled zoom.
static func _z_settled(fx: Dictionary) -> float:
	_push_z(fx["viewport"])
	_step(fx, 1.0)
	return (fx["camera"] as BoardCameraController).zoom.x


# Combat levels are Sanctum's five, clamped into [min_zoom, 2.2]: 0.5, 1.0, 1.5, 2.0, 2.2. From the
# default 1.3, Z goes up a level each press and wraps to the lowest after the highest.
static func _t_z_steps_through_levels_and_wraps() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	var start := cam.zoom.x
	var got: Array = []
	for i in range(6):
		got.append(snappedf(_z_settled(fx), 0.001))
	(fx["viewport"] as SubViewport).free()
	var want := [1.5, 2.0, 2.2, 0.5, 1.0, 1.5]
	if not is_equal_approx(start, 1.3):
		return { "ok": false, "error": "Start zoom %s, want 1.3; premise failed" % start }
	if got != want:
		return { "ok": false, "error": "Z sequence %s, want %s" % [got, want] }
	return { "ok": true }


static func _t_z_after_wheel_goes_to_next_level() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	var point := _empty_point_near_centre(fx["combat"])
	_wheel_settled(fx, point, false)
	_wheel_settled(fx, point, false)
	var after_wheel := cam.zoom.x
	var after_z := _z_settled(fx)
	(fx["viewport"] as SubViewport).free()
	if not (after_wheel > 1.0 and after_wheel < 1.5):
		return { "ok": false, "error": "Wheel zoom %s is not between 1.0 and 1.5; premise failed" % after_wheel }
	if not is_equal_approx(after_z, 1.5):
		return { "ok": false, "error": "Z after a wheel zoom to %s went to %s, want the next level 1.5" % [after_wheel, after_z] }
	return { "ok": true }


static func _t_z_in_focused_line_edit_types_letter() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var vp := fx["viewport"] as SubViewport
	var cam := fx["camera"] as BoardCameraController
	var field := LineEdit.new()
	field.size = Vector2(200, 40)
	vp.add_child(field)
	field.grab_focus()
	var focused := vp.gui_get_focus_owner() == field
	var z0 := cam.zoom.x
	var z1 := _z_settled(fx)
	var text := field.text
	vp.free()
	if not focused:
		return { "ok": false, "error": "LineEdit did not take focus; premise failed" }
	if text != "z":
		return { "ok": false, "error": "Focused LineEdit got '%s' from Z, want 'z'" % text }
	if not is_equal_approx(z1, z0):
		return { "ok": false, "error": "Z into a text field also zoomed the board (%s -> %s)" % [z0, z1] }
	return { "ok": true }


static func _t_z_in_hidden_screen_does_nothing() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	(fx["realm"] as RealmShell).visible = false
	var disabled := not cam.enabled
	var z0 := cam.zoom.x
	var z1 := _z_settled(fx)
	(fx["viewport"] as SubViewport).free()
	if not disabled:
		return { "ok": false, "error": "Hidden screen left the camera enabled; premise failed" }
	if not is_equal_approx(z1, z0):
		return { "ok": false, "error": "Z zoomed a hidden screen's camera (%s -> %s)" % [z0, z1] }
	return { "ok": true }


# Locked: Z zooms about the screen centre, so the locked actor stays centred, and it starts the
# manual-zoom hold like the wheel and pinch.
static func _t_z_while_locked_keeps_actor_centred() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	var echo := _living_echoes(fx)[0] as Dictionary
	var err := _check_tap_locks_and_follows(fx, echo, "echo")
	if not err.is_empty():
		(fx["viewport"] as SubViewport).free()
		return { "ok": false, "error": err }
	var z0 := cam.zoom.x
	_push_z(fx["viewport"])
	var held := cam.is_follow_held()
	var worst := 0.0
	for i in range(20):
		_step(fx, 0.05)
		worst = maxf(worst, _token_viewport_pos(fx, echo).distance_to(_CENTER))
	var z1 := cam.zoom.x
	var mode := cam.mode
	(fx["viewport"] as SubViewport).free()
	if is_equal_approx(z1, z0):
		return { "ok": false, "error": "Z on a locked camera did not zoom" }
	if not held:
		return { "ok": false, "error": "Z on a locked camera did not start the follow hold" }
	if mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		return { "ok": false, "error": "Z released the lock (mode %d)" % mode }
	if worst > 2.0:
		return { "ok": false, "error": "Locked actor drifted %s px from the centre during the Z zoom" % worst }
	return { "ok": true }


# AppRoot keeps a hidden SanctumShell next to RealmShell. Here Sanctum is added after RealmShell,
# so its nodes see input first. Z in Combat must still zoom Combat, and must not step the hidden
# Sanctum's zoom.
static func _t_z_in_combat_with_hidden_sanctum_present() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var realm := fx["realm"] as RealmShell
	var sanctum := (load("res://ui/shells/SanctumShell.tscn") as PackedScene).instantiate() as SanctumShell
	(realm.get_parent() as CanvasLayer).add_child(sanctum)
	sanctum.set_layout(_LAYOUT)
	sanctum.set_snapshot({ "type": "flow.sanctum", "meta": { "t": 1 }, "data": {}, "actions": {} })
	sanctum.visible = false
	var cam := fx["camera"] as BoardCameraController
	var sanctum_before := sanctum.camera.zoom_goal().x
	var z0 := cam.zoom.x
	var z1 := _z_settled(fx)
	var sanctum_after := sanctum.camera.zoom_goal().x
	(fx["viewport"] as SubViewport).free()
	if is_equal_approx(z1, z0):
		return { "ok": false, "error": "Z did not zoom Combat while a hidden SanctumShell was present (Sanctum zoom %s -> %s)" % [sanctum_before, sanctum_after] }
	if not is_equal_approx(sanctum_after, sanctum_before):
		return { "ok": false, "error": "Z in Combat also stepped the hidden Sanctum zoom (%s -> %s)" % [sanctum_before, sanctum_after] }
	return { "ok": true }


# A second Z before the first ease ends steps from the first press's target. From 1.3: the first Z
# heads to 1.5, the second to 2.0 (not 1.5 again from the mid-ease zoom).
static func _t_quick_second_z_steps_from_target() -> Dictionary:
	var fx := _make_fixture(EncounterResolutionModes.COMBAT)
	if fx.is_empty():
		return { "ok": false, "error": "Fixture failed" }
	var cam := fx["camera"] as BoardCameraController
	_push_z(fx["viewport"])
	cam._process(0.05)
	var mid := cam.zoom.x
	var end := _z_settled(fx)
	(fx["viewport"] as SubViewport).free()
	if not (mid > 1.3 and mid < 1.5):
		return { "ok": false, "error": "Mid-ease zoom %s is not between 1.3 and 1.5; premise failed" % mid }
	if not is_equal_approx(end, 2.0):
		return { "ok": false, "error": "Two quick Z presses from 1.3 ended at %s, want 2.0" % end }
	return { "ok": true }

