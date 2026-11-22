# res://tests/PickupPointerTests.gd
# V2-ITEM-001b R6a (D-76): the pointer of the intro is a drifting ivory mote, not the selection ring. The path is the planner's
# racetrack; the pose is a pure function; the stage owns the clock; the board places the nodes. The Echoes stay still.

class_name PickupPointerTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const _DT := 0.05
const _EPS := 0.001
const _RADIUS := 20.0
const _HEAD := 56.0
const _LATERAL := Vector2(64.0, 32.0)


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/pointer_mote_hidden_before_pointer0_and_after_the_intro", Callable(PickupPointerTests, "_t_hidden"))
	runner.register_test("pickup_ui/pointer_mote_values_come_from_the_snapshot", Callable(PickupPointerTests, "_t_look_reaches_the_pose"))
	runner.register_test("pickup_ui/pointer_mote_fades_in_during_the_lead", Callable(PickupPointerTests, "_t_fade"))
	runner.register_test("pickup_ui/pointer_mote_is_on_the_path_at_each_knot_time", Callable(PickupPointerTests, "_t_knots"))
	runner.register_test("pickup_ui/pointer_mote_never_nan_and_alpha_in_range", Callable(PickupPointerTests, "_t_finite"))
	runner.register_test("pickup_ui/pointer_mote_lands_with_no_overshoot_then_sinks_and_the_halo_opens", Callable(PickupPointerTests, "_t_land"))
	runner.register_test("pickup_ui/pointer_pose_is_total_and_finite", Callable(PickupPointerTests, "_t_pose_total"))
	runner.register_test("pickup_ui/pointer_mote_textures_and_landing_length_match_the_scene_and_the_planner", Callable(PickupPointerTests, "_t_scene_numbers"))
	runner.register_test("pickup_ui/pointer_halo_breathes_inside_a_long_hold", Callable(PickupPointerTests, "_t_breath"))
	runner.register_test("pickup_ui/pointer_mote_trail_and_shadow", Callable(PickupPointerTests, "_t_trail_shadow"))
	runner.register_test("pickup_ui/pointer_mote_colour_is_the_living_grove_ivory_and_no_stroke_is_drawn", Callable(PickupPointerTests, "_t_ivory_and_scan"))
	runner.register_test("pickup_ui/pointer_mote_follows_the_clock_and_lands_above_the_chooser", Callable(PickupPointerTests, "_t_host_land"))
	runner.register_test("pickup_ui/pointer_no_selection_ring_in_intro_or_idle", Callable(PickupPointerTests, "_t_no_ring"))
	runner.register_test("pickup_ui/pointer_no_mote_in_idle_flip_leave_or_clear", Callable(PickupPointerTests, "_t_no_mote"))
	runner.register_test("pickup_ui/pointer_repeat_snapshot_keeps_the_clock", Callable(PickupPointerTests, "_t_repeat"))
	runner.register_test("pickup_ui/pointer_new_identity_restarts_the_clock_and_hides_the_mote", Callable(PickupPointerTests, "_t_new_identity"))
	runner.register_test("pickup_ui/pointer_mote_moves_no_token_and_not_the_camera", Callable(PickupPointerTests, "_t_nothing_else_moves"))
	runner.register_test("pickup_ui/pointer_clock_runs_to_the_plan_total_then_stops", Callable(PickupPointerTests, "_t_stops"))


static func _fail(text: String) -> Dictionary:
	return { "ok": false, "error": text }


static func _plan(n: int = 5, chooser: int = 2) -> Dictionary:
	return PickupEventPlan.build(PickupPlannerTests._snap({ "n": n, "chooser": chooser, "phase": "intro" }))


## Row tokens on a straight row, left to right, one grid step apart (screen +64, -32).
static func _positions(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2(100.0, 300.0) + Vector2(64.0, -32.0) * float(i))
	return out


static func _pose(plan: Dictionary, t: float) -> Dictionary:
	return PickupPointerMote.pose_at(plan, _positions(int(plan["n"])), _LATERAL, t, _RADIUS)


static func _finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


static func _mote_look(plan: Dictionary) -> Dictionary:
	return (plan["pointer"] as Dictionary)["mote"]


## A changed `mote` value in the snapshot changes the pose and the node values; the script holds no tunable number.
static func _t_look_reaches_the_pose() -> Dictionary:
	var snap := PickupPlannerTests._snap({ "phase": "intro" })
	var base := PickupEventPlan.build(snap)
	snap["data"]["pointer_look"]["mote"]["rise"] = 40.0
	snap["data"]["pointer_look"]["mote"]["above_head"] = 10.0
	snap["data"]["pointer_look"]["mote"]["halo_alpha"] = 0.9
	var plan := PickupEventPlan.build(snap)
	var p0 := float(plan["times"]["pointer0"])
	# At pointer0 the mote sits `rise` below its rest height: y = base - (radius + above_head) + rise.
	var dy := ((_pose(plan, p0)["mote"] as Vector2) - (_pose(base, p0)["mote"] as Vector2)).y
	if absf(dy - ((40.0 - 16.0) + (36.0 - 10.0))) > 0.01:
		return _fail("rise or above_head from the config does not move the mote (dy %s)" % dy)
	var land := p0 + float(plan["pointer"]["land_t"])
	if absf(float(_pose(plan, land + 0.45)["halo_alpha"]) - float(_pose(base, land + 0.45)["halo_alpha"])) < 0.05:
		return _fail("halo_alpha from the config does not change the halo")
	var fx := PickupUiHostTests._mount(PickupUiHostTests._pickup("sit_a", 1, "idle"))
	if fx.is_empty():
		return _fail("mount failed")
	var errors: Array = []
	var pose := _pose(plan, land + 0.45)
	_mote(fx).apply_pose(pose, _mote_look(plan), 128.0)
	var halo := _mote(fx).get_node("%Halo") as Sprite2D
	var want := float(_mote_look(plan)["halo_diameter_tiles"]) * 128.0 * 0.5 * float(pose["halo_scale"]) / PickupPointerMote.TEXTURE_RADIUS
	if absf(halo.scale.x - want) > 1e-4:
		errors.append("halo size does not follow halo_diameter_tiles")
	return PickupBarkTests._done(fx, errors)


static func _t_hidden() -> Dictionary:
	var plan := _plan()
	var p0 := float(plan["times"]["pointer0"])
	if bool(_pose(plan, p0 - 0.01)["visible"]) or bool(_pose(plan, 0.0)["visible"]):
		return _fail("visible before pointer0")
	if not bool(_pose(plan, p0)["visible"]):
		return _fail("not visible at pointer0")
	if bool(_pose(plan, float(plan["total"]))["visible"]) or bool(_pose(plan, float(plan["total"]) + 3.0)["visible"]):
		return _fail("visible after the intro ends")
	if bool(PickupPointerMote.pose_at({}, [], _LATERAL, 1.0, _RADIUS)["visible"]) \
			or bool(PickupPointerMote.pose_at({}, _positions(5), _LATERAL, 1.0, _RADIUS)["visible"]):
		return _fail("visible with no plan")
	var no_pointer := plan.duplicate(true)
	no_pointer.erase("pointer")
	if bool(PickupPointerMote.pose_at(no_pointer, _positions(5), _LATERAL, p0 + 1.0, _RADIUS)["visible"]):
		return _fail("visible with a plan that has no pointer key")
	if bool(PickupPointerMote.pose_at(plan, _positions(2), _LATERAL, p0 + 1.0, _RADIUS)["visible"]):
		return _fail("visible with fewer positions than the chooser index")
	return { "ok": true }


static func _t_fade() -> Dictionary:
	var plan := _plan()
	var p0 := float(plan["times"]["pointer0"])
	var a := _pose(plan, p0)
	var b := _pose(plan, p0 + 0.15)
	var c := _pose(plan, p0 + 0.30)
	if float(a["alpha"]) != 0.0 or absf(float(a["scale"]) - 0.5) > 1e-6:
		return _fail("start alpha %s scale %s" % [a["alpha"], a["scale"]])
	if not (float(b["alpha"]) > 0.0 and float(b["alpha"]) < 1.0 and float(b["scale"]) > 0.5 and float(b["scale"]) < 1.0):
		return _fail("no fade in the middle of the lead")
	if absf(float(c["alpha"]) - 1.0) > 1e-6 or absf(float(c["scale"]) - 1.0) > 1e-6:
		return _fail("end alpha %s scale %s" % [c["alpha"], c["scale"]])
	var rise := ((a["mote"] as Vector2) - (c["mote"] as Vector2)).y
	if absf(rise - float(_mote_look(plan)["rise"])) > 0.01 or not (float(b["mote"].y) < float(a["mote"].y)):
		return _fail("the mote does not rise %s px during the lead (%s)" % [_mote_look(plan)["rise"], rise])
	return { "ok": true }


static func _t_knots() -> Dictionary:
	var plan := _plan()
	var pos := _positions(5)
	var p0 := float(plan["times"]["pointer0"])
	var path: Array = plan["pointer"]["path"]
	for i in path.size():
		var mv: Dictionary = path[i]
		var side := 1.0 if i >= 5 and i <= 8 else 0.0
		var want := PickupPointerMote.path_point(pos, _LATERAL, float(mv["to"]), side) + Vector2(0.0, -_HEAD)
		var tables: Array = PickupPlannerTests._look()["tables"]["5:2"]
		if absf(float(mv["t1"]) - float(tables[i])) > 1e-9:
			return _fail("move %d arrives at %s, the table has %s" % [i, mv["t1"], tables[i]])
		if str(mv["kind"]) == "turn":
			continue
		var got: Vector2 = _pose(plan, p0 + float(mv["t1"]) - 1e-9)["mote"]
		if got.distance_to(want) > 0.5:
			return _fail("move %d ends at %s, expected %s" % [i, got, want])
	return { "ok": true }


static func _t_finite() -> Dictionary:
	for n: int in [1, 2, 3, 5, 7]:
		var plan := _plan(n, n / 2)
		var t := -1.0
		while t < 12.0:
			var pose := _pose(plan, t)
			if not _finite(pose["mote"]) or not _finite(pose["ground"]) or float(pose["alpha"]) < 0.0 or float(pose["alpha"]) > 1.0 \
					or not is_finite(float(pose["scale"])) or not is_finite(float(pose["halo_alpha"])):
				return _fail("bad pose, n %d at %s" % [n, t])
			for tr: Dictionary in pose["trail"]:
				if not _finite(tr["pos"]) or float(tr["alpha"]) < 0.0 or float(tr["alpha"]) > 1.0:
					return _fail("bad trail, n %d at %s" % [n, t])
			t += 0.013
	return { "ok": true }


## `pointer_pose` alone: any time (before 0, after the end, NaN, INF) and any plan gives a finite pose.
static func _t_pose_total() -> Dictionary:
	for n: int in [1, 2, 3, 4, 5, 6, 7]:
		for reduced: bool in [false, true]:
			var plan := PickupEventPlan.build(PickupPlannerTests._snap({ "n": n, "chooser": n / 2, "phase": "intro" }), { "reduced": reduced })
			var times: Array = [-1.0, 0.0, NAN, INF, -INF, 1e9]
			var t := -0.5
			while t < 12.0:
				times.append(t)
				t += 0.037
			for tt: float in times:
				var pose := PickupEventPlan.pointer_pose(plan, tt)
				for k: String in ["pos_row", "side", "arc", "arc_k", "speed", "lt"]:
					if not is_finite(float(pose[k])) and not (k == "lt" and not bool(pose["visible"])):
						return _fail("n %d reduced %s t %s: %s is %s" % [n, reduced, tt, k, pose[k]])
	# A partial plan (a missing key, a mote with no halo_fade_out, no fade_t) gives the hidden pose and no error.
	var whole := PickupEventPlan.build(PickupPlannerTests._snap({ "phase": "intro" }))
	var partials: Array = []
	for key: String in ["mote", "fade_t", "knots", "path", "lead", "land_t", "land_phase_len", "land_index", "n", "reduced"]:
		var cut := whole.duplicate(true)
		(cut["pointer"] as Dictionary).erase(key)
		partials.append(cut)
	var no_fade := whole.duplicate(true)
	(no_fade["pointer"]["mote"] as Dictionary).erase("halo_fade_out")
	partials.append(no_fade)
	var no_times := whole.duplicate(true)
	(no_times["times"] as Dictionary).erase("pointer0")
	partials.append(no_times)
	for cut: Dictionary in partials:
		if bool(PickupEventPlan.pointer_pose(cut, 1.5)["visible"]):
			return _fail("a partial plan shows the pointer")
	for bad: Dictionary in [{}, { "valid": false }, { "valid": true, "times": { "pointer0": 0.5 }, "total": 9.0, "pointer": {} }]:
		if bool(PickupEventPlan.pointer_pose(bad, 1.0)["visible"]) and bad.get("pointer", null) == null:
			return _fail("visible for a plan with no pointer")
	return { "ok": true }


## The sprite scale divides by TEXTURE_RADIUS, so it must be half the authored gradient width; the planner's landing length
## must equal the mote's wind-up plus sink (the planner does not read the presentation class).
static func _t_scene_numbers() -> Dictionary:
	var fx := PickupUiHostTests._mount(PickupUiHostTests._pickup("sit_a", 1, "idle"))
	if fx.is_empty():
		return _fail("mount failed")
	var mote := _mote(fx)
	var errors: Array = []
	for n: String in ["Halo", "Shadow", "Mote", "Trail1", "Trail5"]:
		var tex := (mote.get_node("%" + n) as Sprite2D).texture as GradientTexture2D
		if tex == null or absf(float(tex.width) * 0.5 - PickupPointerMote.TEXTURE_RADIUS) > 1e-6 or tex.width != tex.height:
			errors.append("%s texture is not a square with half width %s" % [n, PickupPointerMote.TEXTURE_RADIUS])
	var pp: Dictionary = _plan()["pointer"]
	if absf(float(pp["land_phase_len"]) - (float(pp["mote"]["wind_up_len"]) + float(pp["mote"]["sink_len"]))) > 1e-9:
		errors.append("land_phase_len %s differs from wind_up_len + sink_len" % pp["land_phase_len"])
	return PickupBarkTests._done(fx, errors)


static func _t_land() -> Dictionary:
	var plan := _plan()
	var pos := _positions(5)
	var p0 := float(plan["times"]["pointer0"])
	var land := p0 + float(plan["pointer"]["land_t"])
	var chooser: Vector2 = pos[2] + Vector2(0.0, -_HEAD)
	if (_pose(plan, land)["mote"] as Vector2).distance_to(chooser) > 0.01:
		return _fail("the mote is not above the chooser at the landing")
	# No overshoot: in the last move the mote only gets closer to the chooser, and after it only the height changes.
	var last: Dictionary = plan["pointer"]["path"][(plan["pointer"]["path"] as Array).size() - 1]
	var prev := 1e9
	var t := p0 + float(last["t0"])
	while t <= land:
		var d := ((_pose(plan, t)["mote"] as Vector2) - chooser).length()
		if d > prev + 1e-6:
			return _fail("the mote moves away from the chooser at %s" % t)
		prev = d
		t += 0.01
	var lift := _pose(plan, land + 0.08)["mote"] as Vector2
	var sunk := _pose(plan, land + 0.20)["mote"] as Vector2
	if absf(lift.x - chooser.x) > 0.01 or absf(sunk.x - chooser.x) > 0.01 or lift.y > chooser.y - 3.9 or sunk.y < lift.y:
		return _fail("the landing is not a wind-up lift then a sink: lift %s, sunk %s" % [lift, sunk])
	var end := _pose(plan, land + 0.36)
	if float(end["alpha"]) > 0.01 or absf(float(end["scale"]) - 0.6) > 0.01 or absf((end["mote"] as Vector2).y - (chooser.y + 16.0)) > 0.5:
		return _fail("after the sink alpha %s scale %s y %s" % [end["alpha"], end["scale"], end["mote"]])
	if float(_pose(plan, land + 0.07)["halo_alpha"]) != 0.0 or float(_pose(plan, land + 0.10)["halo_alpha"]) <= 0.0:
		return _fail("the halo does not open when the sink starts")
	var h1 := float(_pose(plan, land + 0.15)["halo_scale"])
	var h2 := float(_pose(plan, land + 0.30)["halo_scale"])
	var h3 := float(_pose(plan, land + 0.38)["halo_scale"])
	if not (h1 < h2 and h2 < h3 and absf(h3 - 1.0) < 1e-6):
		return _fail("the halo does not open to full: %s %s %s" % [h1, h2, h3])
	if float(_pose(plan, land + 0.10)["brighten"]) != 0.0 or absf(float(_pose(plan, land + 0.60)["brighten"]) - float(_mote_look(plan)["brighten"])) > 1e-6:
		return _fail("the chooser brightness lift is wrong")
	return { "ok": true }


## The breath needs a hold longer than the breath period, or the fade ends it first: a fixture with a 2.0 s hold.
static func _t_breath() -> Dictionary:
	var snap := PickupPlannerTests._snap({ "phase": "intro" })
	snap["data"]["pointer_look"]["path"]["hold"] = 2.0
	var plan := PickupEventPlan.build(snap)
	var land := float(plan["times"]["pointer0"]) + float(plan["pointer"]["land_t"])
	var fade_t := float(plan["pointer"]["fade_t"])
	var open_end := 0.08 + float(_mote_look(plan)["halo_open"])
	var t1 := land + open_end + 0.4
	var t2 := land + open_end + 1.2
	if t2 >= fade_t:
		return _fail("the samples are not inside the hold")
	var a1 := float(_pose(plan, t1)["halo_alpha"])
	var a2 := float(_pose(plan, t2)["halo_alpha"])
	if a1 <= 0.0 or a2 <= 0.0 or absf(a1 - a2) < 0.005:
		return _fail("the halo does not breathe inside the hold (%s, %s)" % [a1, a2])
	if float(PickupEventPlan.pointer_pose(plan, t1)["fade"]) != 1.0:
		return _fail("the samples are inside the fade")
	return { "ok": true }


static func _t_trail_shadow() -> Dictionary:
	var plan := _plan()
	var p0 := float(plan["times"]["pointer0"])
	var fast := _pose(plan, p0 + 0.9)
	var trail: Array = fast["trail"]
	if trail.size() != 5:
		return _fail("%d trail samples in a glide, expected 5" % trail.size())
	for i in range(1, trail.size()):
		if float(trail[i]["alpha"]) >= float(trail[i - 1]["alpha"]) or float(trail[i]["scale"]) >= float(trail[i - 1]["scale"]):
			return _fail("the trail does not fade and shrink")
	if float(trail[0]["alpha"]) > 0.5:
		return _fail("the trail starts too bright")
	if not (_pose(plan, p0 + 0.1)["trail"] as Array).is_empty() or not (_pose(plan, p0 + float(plan["pointer"]["land_t"]) + 0.5)["trail"] as Array).is_empty():
		return _fail("a trail at rest")
	# Higher mote: softer, smaller shadow (compare the arc top of the slow last move with rest).
	var last: Dictionary = plan["pointer"]["path"][(plan["pointer"]["path"] as Array).size() - 1]
	var mid := p0 + (float(last["t0"]) + float(last["t1"])) * 0.5
	var high := _pose(plan, mid)
	var rest := _pose(plan, p0 + float(plan["pointer"]["land_t"]) - 1e-9)
	if not (float(high["shadow_scale"]) < float(rest["shadow_scale"]) and float(high["shadow_alpha"]) < float(rest["shadow_alpha"])):
		return _fail("the shadow is not softer and smaller under a higher mote")
	if float(PickupEventPlan.pointer_pose(plan, mid)["arc_k"]) <= float(PickupEventPlan.pointer_pose(plan, p0 + 0.9)["arc_k"]):
		return _fail("a slow hop is not higher than a fast one")
	return { "ok": true }


static func _t_ivory_and_scan() -> Dictionary:
	if not PickupPointerMote.IVORY.is_equal_approx(Color.html("F5F0E8")):
		return _fail("the mote colour is not #F5F0E8")
	var src := FileAccess.get_file_as_string("res://ui/screens/combat/PickupPointerMote.gd")
	for banned: String in ["draw_arc", "draw_circle", "draw_line", "draw_polyline", "draw_rect", "draw_polygon", "draw_texture", "_draw(", "Line2D", "ally_ring", "active_ring", "add_child", ".new()"]:
		if src.contains(banned):
			return _fail("PickupPointerMote.gd contains %s" % banned)
	var scene := FileAccess.get_file_as_string("res://ui/screens/combat/CombatBoardScreen.tscn")
	var a := scene.find("[node name=\"PickupPointerHalo\"")
	var b := scene.find("[node name=\"DistanceLayer\"")
	var part := scene.substr(a, b - a)
	if a < 0 or b < a or part.contains("Line2D") or part.contains("Polygon2D") or part.contains("material ="):
		return _fail("the mote scene part has a line, a polygon or a material")
	if scene.contains("blend_mode") or scene.contains("CanvasItemMaterial"):
		return _fail("the board scene has a blend mode or a CanvasItemMaterial (the pointer uses normal blend)")
	for old: String in ["PickupPointerLight", "LIGHT_GAIN", "pointer_style"]:
		if scene.contains(old):
			return _fail("the old light is still in the board scene (%s)" % old)
	return { "ok": true }


static func _mote(fx: Dictionary) -> PickupPointerMote:
	return (fx["combat"] as Node).get_node("%PickupPointerMote") as PickupPointerMote


static func _active(fx: Dictionary) -> String:
	return str((fx["combat"].get_node("%TokenLayer") as Node).get("_active_actor_id"))


static func _stage(fx: Dictionary) -> PickupEventStage:
	return PickupUiHostTests._stage(fx)


static func _real(seed_text: String, phase: String = "intro") -> Dictionary:
	return PickupRealBoard.snapshot("many", phase, "", seed_text)


static func _ids(snap: Dictionary) -> Array:
	return (snap["data"]["row"] as Array).map(func(e: Dictionary) -> String: return str(e["id"]))


## Advances the clock in steps up to `until` seconds of clock time; `each` is called after every step.
static func _run(fx: Dictionary, until: float, each: Callable = Callable()) -> void:
	var stage := _stage(fx)
	while stage.clock_time() < until - 1e-9 and stage.is_clock_running():
		stage.advance(minf(_DT, until - stage.clock_time()))
		if each.is_valid():
			each.call()


static func _t_host_land() -> Dictionary:
	var errors: Array = []
	for seed_text: String in ["0", "1"]:
		var snap := _real(seed_text)
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var plan := PickupEventPlan.build(snap)
		var fx := PickupUiHostTests._mount(snap)
		if fx.is_empty():
			return _fail("mount failed")
		var mote := _mote(fx)
		if mote.visible:
			errors.append("seed %s: the mote shows on the first frame" % seed_text)
		var combat := fx["combat"] as CombatBoardScreen
		var layer := combat.get_node("%TokenLayer") as CombatTokenLayer
		# A non-zero feet offset (on a private copy of the config) makes a sign error in the positions fail.
		var cfg := layer.visual_config.duplicate() as CombatTokenVisualConfig
		cfg.feet_offset_y = 10.0
		layer.visual_config = cfg
		(fx["realm"] as RealmShell).set_snapshot(snap.duplicate(true))
		var chooser_id := str(plan["chooser_id"])
		var tile: Dictionary = {}
		for e: Dictionary in snap["data"]["row"]:
			if bool(e["is_chooser"]):
				tile = e["tile"]
		var draw_pos := (combat.get_node("%Board") as TileMapLayer).map_to_local(Vector2i(int(tile["col"]), int(tile["row"]))) + Vector2(0.0, cfg.feet_offset_y)
		var want := draw_pos - Vector2(0.0, cfg.token_radius + float(plan["pointer"]["mote"]["above_head"]))
		var start := mote.get_node("%Mote") as Sprite2D
		var seen := { "moved": false, "last": Vector2.INF }
		_run(fx, float(plan["times"]["pointer0"]) + 1.0, func() -> void:
			if start.position != seen["last"] and seen["last"] != Vector2.INF:
				seen["moved"] = true
			seen["last"] = start.position)
		if not mote.visible or not seen["moved"]:
			errors.append("seed %s: the mote does not move during the glide" % seed_text)
		_run(fx, float(plan["times"]["pointer0"]) + float(plan["pointer"]["land_t"]))
		if not mote.visible or start.position.distance_to(want) > 0.5:
			errors.append("seed %s: the mote is at %s at the landing, the chooser head is %s" % [seed_text, start.position, want])
		_run(fx, float(plan["pointer"]["fade_t"]) - 0.05)
		var halo := mote.get_node("%Halo") as Sprite2D
		if not (halo.get_parent() as Node2D).visible or halo.modulate.a <= 0.0 or halo.position.distance_to(draw_pos) > 0.5:
			errors.append("seed %s: the halo is not open behind the chooser" % seed_text)
		if float((layer.get("_brighten") as Dictionary).get(chooser_id, 0.0)) <= 0.0:
			errors.append("seed %s: the chooser token is not brightened" % seed_text)
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_no_ring() -> Dictionary:
	var errors: Array = []
	for phase: String in ["intro", "idle"]:
		var snap := _real("0", phase)
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var fx := PickupUiHostTests._mount(snap)
		var seen: Array = [_active(fx)]
		if phase == "intro":
			_run(fx, float(PickupEventPlan.build(snap)["total"]) - 0.1, func() -> void: seen.append(_active(fx)))
		for id: String in seen:
			if id != "":
				errors.append("%s: token %s has the selection ring" % [phase, id])
				break
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_no_mote() -> Dictionary:
	var snap := _real("0")
	var fx := PickupUiHostTests._mount(snap)
	var stage := _stage(fx)
	var mote := _mote(fx)
	var layer := fx["combat"].get_node("%TokenLayer") as CombatTokenLayer
	var errors: Array = []
	_run(fx, 2.0)
	if not mote.visible:
		errors.append("no mote in the intro at 2 s")
	var idle := snap.duplicate(true)
	idle["data"]["phase"] = "idle"
	(fx["realm"] as RealmShell).set_snapshot(idle)
	# The mote fades out over `mote.skip_fade` after the flip; once the fade is over nothing is left.
	(fx["combat"] as Node).call("_process", 1.0)
	if mote.visible or stage.is_clock_running() or stage.is_processing() or not (layer.get("_brighten") as Dictionary).is_empty():
		errors.append("mote, clock or brightness after the flip to idle")
	var idle_first := PickupUiHostTests._mount(_real("0", "idle"))
	if _mote(idle_first).visible or _stage(idle_first).is_processing():
		errors.append("mote or clock when idle starts the event")
	PickupUiHostTests._free(idle_first)
	var fx2 := PickupUiHostTests._mount(snap)
	_run(fx2, float(PickupEventPlan.build(snap)["total"]) - 0.2)
	(fx2["realm"] as RealmShell).set_snapshot(PickupUiHostTests._encounter())
	if _mote(fx2).visible or _stage(fx2).is_clock_running() or _stage(fx2).is_processing():
		errors.append("mote or clock after leave")
	PickupUiHostTests._free(fx2)
	return PickupBarkTests._done(fx, errors)


static func _t_repeat() -> Dictionary:
	var snap := _real("0")
	var fx := PickupUiHostTests._mount(snap)
	var stage := _stage(fx)
	var mote := _mote(fx)
	_run(fx, 1.6)
	var starts := stage.start_count()
	var t_before := stage.clock_time()
	var pos := (mote.get_node("%Mote") as Sprite2D).position
	(fx["realm"] as RealmShell).set_snapshot(snap.duplicate(true))
	var errors: Array = []
	if stage.start_count() != starts or not stage.is_clock_running() or stage.clock_time() != t_before:
		errors.append("a repeat snapshot restarted or stopped the clock")
	if not mote.visible or (mote.get_node("%Mote") as Sprite2D).position != pos:
		errors.append("a repeat snapshot moved or hid the mote")
	return PickupBarkTests._done(fx, errors)


static func _t_new_identity() -> Dictionary:
	var snap := _real("0")
	var fx := PickupUiHostTests._mount(snap)
	_run(fx, 1.6)
	var next := snap.duplicate(true)
	next["data"]["run_count"] = int(next["data"]["run_count"]) + 1
	(fx["realm"] as RealmShell).set_snapshot(next)
	var errors: Array = []
	if _mote(fx).visible or not _stage(fx).is_clock_running() or _stage(fx).clock_time() != 0.0:
		errors.append("a new event kept the mote or did not restart the clock")
	return PickupBarkTests._done(fx, errors)


static func _t_nothing_else_moves() -> Dictionary:
	var snap := _real("1")
	var fx := PickupUiHostTests._mount(snap)
	var combat := fx["combat"] as CombatBoardScreen
	var layer := combat.get_node("%TokenLayer") as CombatTokenLayer
	var ids := _ids(snap)
	var rest: Array = ids.map(func(id: String) -> Vector2: return layer.display_cell_position(id))
	var chooser := str(PickupEventPlan.build(snap)["chooser_id"])
	var cam_pos := combat.camera.position
	var errors: Array = []
	_run(fx, 8.0, func() -> void:
		for k in ids.size():
			if ids[k] != chooser and layer.display_cell_position(ids[k]) != rest[k]:
				errors.append("token %s moved" % ids[k])
		if combat.camera.mode != BoardCameraController.Mode.FREE or combat.camera.target_id != "":
			errors.append("camera left FREE"))
	if combat.camera.position != cam_pos:
		errors.append("camera position changed")
	return PickupBarkTests._done(fx, errors.slice(0, 3))


static func _t_stops() -> Dictionary:
	var snap := _real("0")
	var fx := PickupUiHostTests._mount(snap)
	var stage := _stage(fx)
	var total := float(PickupEventPlan.build(snap)["total"])
	var errors: Array = []
	_run(fx, total - 0.2)
	if not stage.is_clock_running() or not stage.is_processing():
		errors.append("the clock stopped early")
	stage.advance(1.0)
	if stage.is_clock_running() or stage.is_processing() or absf(stage.clock_time() - total) > 1e-6:
		errors.append("the clock does not stop at the plan total")
	return PickupBarkTests._done(fx, errors)
