# res://tests/PickupCameraFrameTests.gd
# V2-ITEM-001b R2b: camera framing of the pickup event (D-73). Pure planner tests first, then the real board host:
# the camera ends on the planner values, every row and find tile is inside the usable rect, and the camera stays FREE.

class_name PickupCameraFrameTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const _TILE := Vector2(128, 64)
const _VIEW := Vector2(1280, 720)
const _USABLE := Rect2(16, 16, 1248, 500)
const _CFG := { "floor_zoom": 0.75, "margin_px": 48.0, "tween_seconds": 0.0 }
const _SCAN_FILES: Array = ["res://ui/screens/combat/PickupCameraFrame.gd"]
const _BANNED_WORDS: Array = ["extends Node", "get_viewport", "Node.new", "add_child"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/camera_frame_one_point_keeps_a_zoom_that_fits", Callable(PickupCameraFrameTests, "_t_one_point"))
	runner.register_test("pickup_ui/camera_frame_two_far_points_zoom_out_to_the_fit", Callable(PickupCameraFrameTests, "_t_far_points"))
	runner.register_test("pickup_ui/camera_frame_every_point_projects_inside_usable_minus_margin", Callable(PickupCameraFrameTests, "_t_projection"))
	runner.register_test("pickup_ui/camera_frame_zoom_rules", Callable(PickupCameraFrameTests, "_t_zoom_rules"))
	runner.register_test("pickup_ui/camera_frame_empty_points_are_invalid", Callable(PickupCameraFrameTests, "_t_empty"))
	runner.register_test("pickup_ui/camera_frame_box_centre_lands_on_the_usable_centre", Callable(PickupCameraFrameTests, "_t_off_centre"))
	runner.register_test("pickup_ui/camera_frame_bad_numbers_give_finite_results", Callable(PickupCameraFrameTests, "_t_finite"))
	runner.register_test("pickup_ui/camera_frame_source_scan", Callable(PickupCameraFrameTests, "_t_source_scan"))
	runner.register_test("pickup_ui/camera_opens_on_the_planner_framing_with_every_tile_inside", Callable(PickupCameraFrameTests, "_t_open"))
	runner.register_test("pickup_ui/camera_repeat_and_swap_snapshots_do_not_move_it", Callable(PickupCameraFrameTests, "_t_repeat"))
	runner.register_test("pickup_ui/camera_is_free_after_open_even_if_the_fight_locked_it", Callable(PickupCameraFrameTests, "_t_free"))
	runner.register_test("pickup_ui/camera_keeps_a_manual_pan_on_layout_change", Callable(PickupCameraFrameTests, "_t_pan_kept"))
	runner.register_test("pickup_ui/camera_reframes_on_layout_change_without_a_pan", Callable(PickupCameraFrameTests, "_t_reframe"))
	runner.register_test("pickup_ui/camera_ignores_an_echo_tap_during_the_event", Callable(PickupCameraFrameTests, "_t_tap_ignored"))
	runner.register_test("pickup_ui/camera_leave_kills_the_running_tween", Callable(PickupCameraFrameTests, "_t_leave"))
	runner.register_test("pickup_ui/camera_without_camera_frame_does_not_move", Callable(PickupCameraFrameTests, "_t_no_cfg"))
	runner.register_test("pickup_ui/camera_new_event_frames_again_after_leave", Callable(PickupCameraFrameTests, "_t_second_event"))
	runner.register_test("pickup_ui/camera_frame_huge_points_are_invalid_not_infinite", Callable(PickupCameraFrameTests, "_t_huge"))
	runner.register_test("pickup_ui/camera_fight_then_pickup_on_the_same_screen_frames_to_the_planner", Callable(PickupCameraFrameTests, "_t_fight_then_pickup"))
	runner.register_test("pickup_ui/camera_new_event_queues_the_deferred_framing", Callable(PickupCameraFrameTests, "_t_deferred_in_source"))
	runner.register_test("pickup_ui/camera_real_fixture_tiles_land_inside_usable", Callable(PickupCameraFrameTests, "_t_real_fixture_inside"))
	runner.register_test("pickup_ui/camera_edge_tiles_of_a_small_board_land_inside_usable", Callable(PickupCameraFrameTests, "_t_edge_tiles"))
	runner.register_test("pickup_ui/real_fixture_seeds_give_both_row_axes", Callable(PickupCameraFrameTests, "_t_axis_seeds"))


# ---- pure planner ----

static func _frame(points: Array, current: float = 1.3, usable: Rect2 = _USABLE, zmin: float = 0.3, zmax: float = 2.2,
		floor_zoom: float = 0.75, margin: float = 48.0) -> Dictionary:
	return PickupCameraFrame.frame(PackedVector2Array(points), _TILE, _VIEW, usable, current, zmin, zmax, floor_zoom, margin)


static func _project(p: Vector2, framed: Dictionary) -> Vector2:
	return (p - (framed["position"] as Vector2)) * float(framed["zoom"]) + _VIEW * 0.5


static func _t_one_point() -> Dictionary:
	var framed := _frame([Vector2.ZERO], 2.0)
	var errors: Array = []
	if not bool(framed["valid"]) or not is_equal_approx(float(framed["zoom"]), 2.0):
		errors.append("one point at zoom 2.0 gave %s" % [framed])
	if not (framed["position"] as Vector2).is_equal_approx(Vector2(0.0, 47.0)):
		errors.append("position %s, expected (0, 47)" % [framed["position"]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_far_points() -> Dictionary:
	var framed := _frame([Vector2(-1000, 0), Vector2(1000, 0)])
	var fit := (_USABLE.size.x - 96.0) / (2000.0 + _TILE.x)
	var errors: Array = []
	if not is_equal_approx(float(framed["zoom"]), fit):
		errors.append("zoom %s, expected the fit %s" % [framed["zoom"], fit])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_projection() -> Dictionary:
	var errors: Array = []
	var sets: Array = [
		[Vector2(-300, -120), Vector2(260, 90)],
		[Vector2(500, 400), Vector2(520, 410), Vector2(-40, 0)],
		[Vector2(-900, 300), Vector2(900, -300), Vector2(0, 0)],
	]
	for pts: Array in sets:
		for current in [0.4, 1.3, 2.2]:
			var framed := _frame(pts, current)
			var inner := _USABLE.grow(-48.0 + 0.01)
			for p: Vector2 in pts:
				var s := _project(p, framed)
				var half := _TILE * 0.5 * float(framed["zoom"])
				if not inner.encloses(Rect2(s - half, half * 2.0)):
					errors.append("point %s at zoom %s projects to %s, outside %s" % [p, current, s, inner])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_zoom_rules() -> Dictionary:
	var pts := [Vector2(-300, 0), Vector2(300, 0)]
	var fit := (_USABLE.size.x - 96.0) / (600.0 + _TILE.x)
	var errors: Array = []
	var checks: Array = [
		["current above fit", _frame(pts, fit + 0.5), fit],
		["current between floor and fit", _frame(pts, 0.8, _USABLE, 0.3, 2.2, 0.75), 0.8],
		["current below floor", _frame(pts, 0.4, _USABLE, 0.3, 2.2, 0.75), minf(0.75, fit)],
		["fit below floor", _frame([Vector2(-2000, 0), Vector2(2000, 0)], 0.4, _USABLE, 0.1, 2.2, 0.75), (_USABLE.size.x - 96.0) / (4000.0 + _TILE.x)],
		["clamped to max", _frame([Vector2.ZERO], 5.0, _USABLE, 0.3, 2.2, 0.75), 2.2],
		["clamped to min", _frame([Vector2(-5000, 0), Vector2(5000, 0)], 1.0, _USABLE, 0.3, 2.2, 0.75), 0.3],
	]
	for c: Array in checks:
		if not is_equal_approx(float((c[1] as Dictionary)["zoom"]), float(c[2])):
			errors.append("%s: zoom %s, expected %s" % [c[0], (c[1] as Dictionary)["zoom"], c[2]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_empty() -> Dictionary:
	var framed := _frame([], 1.1)
	var errors: Array = []
	if bool(framed["valid"]) or not is_equal_approx(float(framed["zoom"]), 1.1):
		errors.append("empty points gave %s" % [framed])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_off_centre() -> Dictionary:
	var usable := Rect2(300, 40, 500, 400)
	var pts := [Vector2(10, 20), Vector2(150, 90)]
	var framed := _frame(pts, 1.0, usable)
	var box_centre := Vector2(80, 55)
	var s := _project(box_centre, framed)
	var errors: Array = []
	if not s.is_equal_approx(usable.get_center()):
		errors.append("box centre projects to %s, usable centre %s" % [s, usable.get_center()])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_finite() -> Dictionary:
	var errors: Array = []
	var bad: Array = [
		PickupCameraFrame.frame(PackedVector2Array([Vector2(NAN, 0), Vector2(5, 5)]), _TILE, _VIEW, _USABLE, 1.0, 0.3, 2.2, 0.75, 48.0),
		PickupCameraFrame.frame(PackedVector2Array([Vector2.ZERO]), _TILE, _VIEW, Rect2(0, 0, 0, 0), 1.0, 0.3, 2.2, 0.75, 48.0),
		PickupCameraFrame.frame(PackedVector2Array([Vector2.ZERO]), Vector2.ZERO, _VIEW, _USABLE, 1.0, 0.3, 2.2, 0.75, 48.0),
		PickupCameraFrame.frame(PackedVector2Array([Vector2.ZERO]), _TILE, _VIEW, _USABLE, NAN, NAN, NAN, NAN, NAN),
		PickupCameraFrame.frame(PackedVector2Array([Vector2.ZERO]), _TILE, _VIEW, Rect2(0, 0, 50, 50), 1.0, 0.3, 2.2, 0.75, 400.0),
		PickupCameraFrame.frame(PackedVector2Array([Vector2.ZERO]), _TILE, _VIEW, _USABLE, 1.0, 0.3, 2.2, 0.75, -10.0),
	]
	for i in bad.size():
		var framed: Dictionary = bad[i]
		var pos: Vector2 = framed["position"]
		if not is_finite(float(framed["zoom"])) or not is_finite(pos.x) or not is_finite(pos.y):
			errors.append("case %d not finite: %s" % [i, framed])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_source_scan() -> Dictionary:
	var errors: Array = []
	for path: String in _SCAN_FILES:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("%s unreadable" % path)
		for word: String in _BANNED_WORDS:
			if text.contains(word):
				errors.append("%s contains %s" % [path, word])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


# ---- real board host ----

static func _pickup(cfg: Dictionary = _CFG, situation: String = "sit_a", run_count: int = 1, cols: int = 8, rows: int = 8) -> Dictionary:
	var snap := PickupUiHostTests._pickup(situation, run_count, "idle", cols, rows)
	var data: Dictionary = snap["data"]
	data["row"] = [
		{ "id": "a2", "name": "Kofi", "standing": 1, "status": "grounded", "is_chooser": false, "tile": { "col": 1, "row": 1 } },
		{ "id": "a1", "name": "Ama", "standing": 1, "status": "grounded", "is_chooser": true, "tile": { "col": 2, "row": 1 } },
	]
	data["finds"] = [{ "find_id": "f1", "tile": { "col": 5, "row": 4 } }, { "find_id": "f2", "tile": { "col": 4, "row": 2 } }]
	if not cfg.is_empty():
		data["camera_frame"] = cfg.duplicate()
	return snap


## The deferred call of the screen cannot run inside a synchronous test, so the test makes it.
static func _open(snap: Dictionary, then_frame: bool = true) -> Dictionary:
	var fx := PickupUiHostTests._mount(snap)
	if fx.is_empty():
		return fx
	if then_frame:
		(fx["combat"] as CombatBoardScreen).frame_pickup_camera(true)
	return fx


static func _cam(fx: Dictionary) -> BoardCameraController:
	return (fx["combat"] as CombatBoardScreen).camera


static func _usable_of(combat: CombatBoardScreen) -> Rect2:
	var view := combat.get_viewport_rect().size
	var insets: Vector4 = combat._layout.get("safe_insets", Vector4.ZERO)
	var bottom := combat._echo_bar_top()
	if is_nan(bottom):
		bottom = view.y - ceilf(insets.w) - combat._ECHO_BAR_HEIGHT
	bottom = minf(bottom, combat.get_node("%PickupEventStage").pack_strip().panel_global_rect().position.y - 8.0)
	var left := ceilf(insets.x) + 16.0
	var top := ceilf(insets.y) + 16.0
	return Rect2(left, top, view.x - ceilf(insets.z) - 16.0 - left, bottom - top)


static func _screen_of(combat: CombatBoardScreen, cell: Vector2i) -> Vector2:
	var world: Vector2 = combat._board_root.position + combat._board.map_to_local(cell)
	var cam := combat.camera
	return (world - cam.get_screen_center_position()) * cam.zoom.x + combat.get_viewport_rect().size * 0.5


static func _tiles_inside(combat: CombatBoardScreen, usable: Rect2, errors: Array) -> void:
	for cell: Vector2i in combat._pickup_cells:
		var s := _screen_of(combat, cell)
		if not usable.has_point(s):
			errors.append("tile %s at %s is outside %s" % [cell, s, usable])


## The camera must equal the planner for `from_zoom` (the zoom the screen had when the framing ran).
static func _planner_errors(combat: CombatBoardScreen, usable: Rect2, from_zoom: float, errors: Array) -> void:
	var points := PackedVector2Array()
	for cell: Vector2i in combat._pickup_cells:
		points.append(combat._board_root.position + combat._board.map_to_local(cell))
	var framed := PickupCameraFrame.frame(points, Vector2(combat._board.tile_set.tile_size), combat.get_viewport_rect().size, usable,
		from_zoom, combat._min_zoom_for_span(combat._board_span_px), combat._ZOOM_MAX, 0.75, 48.0)
	var expected_zoom: float = framed["zoom"]
	if not is_equal_approx(combat.camera.zoom.x, expected_zoom):
		errors.append("zoom %s, planner %s" % [combat.camera.zoom.x, expected_zoom])
	var expected_pos: Vector2 = combat.camera.clamped_position(framed["position"], Vector2(expected_zoom, expected_zoom))
	if not combat.camera.position.is_equal_approx(expected_pos):
		errors.append("position %s, planner %s" % [combat.camera.position, expected_pos])


static func _t_open() -> Dictionary:
	var fx := _open(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	if combat._pickup_cells.size() != 4:
		errors.append("%d framed tiles, expected 2 row and 2 find" % combat._pickup_cells.size())
	var usable := _usable_of(combat)
	_planner_errors(combat, usable, float(combat._ZOOM_DEFAULT), errors)
	_tiles_inside(combat, usable, errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_repeat() -> Dictionary:
	var fx := _open(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var cam := _cam(fx)
	var zoom_before := cam.zoom
	var pos_before := cam.position
	var errors: Array = []
	if (fx["combat"] as CombatBoardScreen)._pickup_frame_due:
		errors.append("the framing was still due after it ran, the check proves nothing")
	realm.set_snapshot(_pickup())
	var swapped := _pickup()
	swapped["data"]["pack"] = { "slots": [] }
	realm.set_snapshot(swapped)
	if (fx["combat"] as CombatBoardScreen)._pickup_frame_due:
		errors.append("a repeat or swap snapshot asked for a new framing")
	if cam.zoom != zoom_before or cam.position != pos_before:
		errors.append("camera moved on a repeat or swap snapshot: %s %s -> %s %s" % [zoom_before, pos_before, cam.zoom, cam.position])
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_free() -> Dictionary:
	var fx := PickupUiHostTests._mount(PickupUiHostTests._encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	combat.select_board_target("a1")
	if combat.camera.mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		errors.append("the fight did not lock the camera, the check proves nothing")
	(fx["realm"] as RealmShell).set_snapshot(_pickup(_CFG, "sit_a", 1, 6, 5))
	if combat._camera_needs_reset:
		errors.append("the pickup asked for a camera reset, so only deselect would not be tested")
	if combat.camera.mode != BoardCameraController.Mode.FREE or combat.camera.target_id != "":
		errors.append("the camera is still locked on %s after the event opened" % combat.camera.target_id)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_pan_kept() -> Dictionary:
	var fx := _open(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	combat.camera.drag_pan(Vector2(40, 10))
	var errors: Array = []
	if not combat.camera.has_manual_override:
		errors.append("drag_pan did not set the manual override, the check proves nothing")
	var pos := combat.camera.position
	var zoom := combat.camera.zoom
	var layout: Dictionary = PickupUiHostTests._LAYOUT.duplicate()
	layout["safe_insets"] = Vector4(60, 30, 60, 30)
	(fx["realm"] as RealmShell).set_layout(layout)
	if combat.camera.position != pos or combat.camera.zoom != zoom:
		errors.append("a layout change moved a panned camera: %s -> %s" % [pos, combat.camera.position])
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_reframe() -> Dictionary:
	var fx := _open(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var pos := combat.camera.position
	var layout: Dictionary = PickupUiHostTests._LAYOUT.duplicate()
	layout["safe_insets"] = Vector4(160, 30, 0, 30)
	(fx["realm"] as RealmShell).set_layout(layout)
	var errors: Array = []
	if combat.camera.position == pos:
		errors.append("a layout change with no pan did not reframe")
	_tiles_inside(combat, _usable_of(combat), errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_tap_ignored() -> Dictionary:
	var fx := PickupUiHostTests._mount(PickupUiHostTests._encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	combat._on_board_tap(_screen_of(combat, Vector2i(2, 3)))
	if combat.camera.mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		errors.append("control: a tap on a token in the fight did not lock the camera, the tap check proves nothing")
	(fx["realm"] as RealmShell).set_snapshot(_pickup(_CFG, "sit_a", 1, 6, 5))
	combat.select_board_target("a1")
	combat._on_board_tap(_screen_of(combat, Vector2i(2, 1)))
	if combat.camera.mode != BoardCameraController.Mode.FREE:
		errors.append("an Echo tap locked the pickup camera")
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_leave() -> Dictionary:
	var cfg := _CFG.duplicate()
	cfg["tween_seconds"] = 0.5
	var fx := _open(_pickup(cfg))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	var tween: Tween = combat._pickup_camera_tween
	if tween == null or not tween.is_valid() or not tween.is_running():
		errors.append("no running tween after open with tween_seconds 0.5, the check proves nothing")
	(fx["realm"] as RealmShell).set_snapshot(PickupUiHostTests._encounter())
	if tween != null and tween.is_valid():
		errors.append("the tween survived the leave")
	if combat._pickup_camera_tween != null:
		errors.append("the tween reference stayed after the leave")
	if combat.camera._screen_animating:
		errors.append("the camera stayed held by a screen animation")
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_no_cfg() -> Dictionary:
	var fx := PickupUiHostTests._mount(_pickup({}))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var pos := combat.camera.position
	var zoom := combat.camera.zoom
	combat.frame_pickup_camera(true)
	var errors: Array = []
	if combat.camera.position != pos or combat.camera.zoom != zoom:
		errors.append("the camera moved without camera_frame")
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_second_event() -> Dictionary:
	var fx := _open(_pickup())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var realm := fx["realm"] as RealmShell
	realm.set_snapshot(PickupUiHostTests._encounter())
	combat.camera.drag_pan(Vector2(80, 0))
	var errors: Array = []
	if not combat.camera.has_manual_override:
		errors.append("drag_pan did not set the manual override, the check proves nothing")
	realm.set_snapshot(_pickup(_CFG, "sit_a", 1))
	combat.frame_pickup_camera(true)
	if combat.camera.has_manual_override:
		errors.append("a new event kept the manual override of the fight")
	_tiles_inside(combat, _usable_of(combat), errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_huge() -> Dictionary:
	var framed := _frame([Vector2(-2e38, 0), Vector2(2e38, 0)])
	var pos: Vector2 = framed["position"]
	var errors: Array = []
	if bool(framed["valid"]):
		errors.append("points near +-2e38 gave a valid frame: %s" % [framed])
	if not is_finite(float(framed["zoom"])) or not is_finite(pos.x) or not is_finite(pos.y):
		errors.append("huge points gave a result that is not finite: %s" % [framed])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## The deferred framing cannot run inside a synchronous test (the runner cannot await), so this test makes the call that
## the deferred line makes and checks `_pickup_frame_due`; `_t_deferred_in_source` guards the deferred line itself.
static func _t_fight_then_pickup() -> Dictionary:
	var fx := PickupUiHostTests._mount(PickupUiHostTests._encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	combat.select_board_target("a1")
	if combat.camera.mode != BoardCameraController.Mode.FOLLOW_ACTOR:
		errors.append("the fight did not lock the camera, the check proves nothing")
	realm.set_snapshot(_pickup(_CFG, "sit_a", 1, 6, 5))
	if realm.get("_active_overlay") != combat:
		errors.append("the pickup did not reuse the screen of the fight")
	if not combat._pickup_frame_due:
		errors.append("a new event did not mark the framing as due")
	if combat.camera.mode != BoardCameraController.Mode.FREE:
		errors.append("the camera is not FREE after the event opened")
	var zoom_at_frame := combat.camera.zoom.x
	combat.frame_pickup_camera(true)
	if combat._pickup_frame_due:
		errors.append("the framing is still due after it ran")
	_planner_errors(combat, _usable_of(combat), zoom_at_frame, errors)
	_tiles_inside(combat, _usable_of(combat), errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_deferred_in_source() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://ui/screens/combat/CombatBoardScreen.gd")
	var start := text.find("func _render_pickup(")
	var end := text.find("\nfunc ", start + 1)
	var body := text.substr(start, end - start) if start >= 0 and end > start else ""
	var errors: Array = []
	if not body.contains("call_deferred(\"frame_pickup_camera\", true)"):
		errors.append("_render_pickup no longer queues the deferred framing")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_real_fixture_inside() -> Dictionary:
	var snap := PickupRealBoard.snapshot("full")
	if snap.is_empty():
		return { "ok": false, "error": "the fixture fight did not reach the event" }
	var fx := PickupUiHostTests._mount(snap)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	combat.frame_pickup_camera(false)
	var errors: Array = []
	if combat._pickup_cells.is_empty():
		errors.append("the real snapshot gave no tiles to frame")
	_tiles_inside(combat, _usable_of(combat), errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_edge_tiles() -> Dictionary:
	var snap := _pickup(_CFG, "sit_a", 1, 6, 5)
	var data: Dictionary = snap["data"]
	data["row"] = [
		{ "id": "a2", "name": "Kofi", "standing": 1, "status": "grounded", "is_chooser": false, "tile": { "col": 0, "row": 4 } },
		{ "id": "a1", "name": "Ama", "standing": 1, "status": "grounded", "is_chooser": true, "tile": { "col": 1, "row": 4 } },
	]
	data["finds"] = [{ "find_id": "f1", "tile": { "col": 5, "row": 4 } }, { "find_id": "f2", "tile": { "col": 5, "row": 0 } }]
	var fx := PickupUiHostTests._mount(snap)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	combat.frame_pickup_camera(false)
	var errors: Array = []
	_tiles_inside(combat, _usable_of(combat), errors)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## Seed 0 gives a row-axis line (falls to the right on screen), seed 1 a col-axis line (rises to the right). Fixtures pickup_idle_axis_a and _b.
const _AXIS_SEEDS := { 0: "row", 1: "col" }


## Step between the first two row tiles: (1, 0) is the col axis, (0, 1) is the row axis.
static func _axis_of(snap: Dictionary) -> String:
	var row: Array = snap["data"]["row"]
	if row.size() < 2:
		return "short"
	var a: Dictionary = (row[0] as Dictionary)["tile"]
	var b: Dictionary = (row[1] as Dictionary)["tile"]
	return "col" if int(b["col"]) != int(a["col"]) else "row"


static func _t_axis_seeds() -> Dictionary:
	var errors: Array = []
	for seed_value: int in _AXIS_SEEDS:
		var snap := PickupRealBoard.snapshot("empty", "idle", "plus", str(seed_value))
		if snap.is_empty():
			errors.append("seed %d: the fixture fight did not reach the event" % seed_value)
			continue
		var n := (snap["data"]["row"] as Array).size()
		if n < 3:
			errors.append("seed %d: a row of %d Echoes cannot show an axis" % [seed_value, n])
		elif _axis_of(snap) != str(_AXIS_SEEDS[seed_value]):
			errors.append("seed %d gave the %s axis, expected %s" % [seed_value, _axis_of(snap), _AXIS_SEEDS[seed_value]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
