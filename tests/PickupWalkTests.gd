# res://tests/PickupWalkTests.gd
# V2-ITEM-001b R6b: the chooser walks the plan's legs on the token layer's own path walk, in step with the intro clock; the mote,
# halo and brightness fade when it starts; the idle picture has the chooser on its end tile. The other Echoes never move.

class_name PickupWalkTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const _DT := 0.05


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/walk_chooser_cell_follows_the_plan_legs_and_ends_on_the_end_tile", Callable(PickupWalkTests, "_t_cells"))
	runner.register_test("pickup_ui/walk_leg_is_a_path_walk_with_the_leg_time_and_no_telegraph", Callable(PickupWalkTests, "_t_leg_walk"))
	runner.register_test("pickup_ui/walk_repeat_snapshot_mid_walk_does_not_reset_the_chooser", Callable(PickupWalkTests, "_t_repeat_mid_walk"))
	runner.register_test("pickup_ui/walk_mote_halo_and_brightness_fade_when_the_chooser_starts", Callable(PickupWalkTests, "_t_fade"))
	runner.register_test("pickup_ui/walk_halo_follows_the_walking_token_during_the_fade", Callable(PickupWalkTests, "_t_halo_follows"))
	runner.register_test("pickup_ui/walk_end_tile_against_the_framed_box_probe", Callable(PickupWalkTests, "_t_end_tile_frame"))
	runner.register_test("pickup_ui/walk_idle_and_skip_draw_the_chooser_on_the_end_tile", Callable(PickupWalkTests, "_t_idle"))
	runner.register_test("pickup_ui/walk_frozen_chooser_steps_out_and_stops", Callable(PickupWalkTests, "_t_frozen"))
	runner.register_test("pickup_ui/walk_invalid_plan_draws_the_row_tile_and_no_walk", Callable(PickupWalkTests, "_t_invalid_plan"))
	runner.register_test("pickup_ui/walk_clock_jump_snaps_the_chooser_to_the_plan_tile", Callable(PickupWalkTests, "_t_snap"))
	runner.register_test("pickup_ui/walk_other_echoes_never_move_and_the_camera_stays_free", Callable(PickupWalkTests, "_t_others"))
	runner.register_test("pickup_ui/walk_token_move_duration_override_is_additive", Callable(PickupWalkTests, "_t_duration_override"))


static func _fail(text: String) -> Dictionary:
	return { "ok": false, "error": text }


static func _layer(fx: Dictionary) -> CombatTokenLayer:
	return (fx["combat"] as Node).get_node("%TokenLayer") as CombatTokenLayer


static func _stage(fx: Dictionary) -> PickupEventStage:
	return PickupUiHostTests._stage(fx)


## The grid cell of an actor's token ({ col, row }, {} when it has no token).
static func _cell(fx: Dictionary, actor_id: String) -> Dictionary:
	for tok: Dictionary in (_layer(fx).get("_tokens") as Array):
		if str(tok["actor_id"]) == actor_id:
			return tok["grid_pos"]
	return {}


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("col", -1)) == int(b.get("col", -2)) and int(a.get("row", -1)) == int(b.get("row", -2))


static func _entry(fx: Dictionary, actor_id: String) -> Dictionary:
	return (_layer(fx).get("_presentation_state") as Object).call("get_entry", actor_id)


static func _run(fx: Dictionary, until: float, each: Callable = Callable()) -> void:
	var stage := _stage(fx)
	while stage.clock_time() < until - 1e-9 and stage.is_clock_running():
		var step := minf(_DT, until - stage.clock_time())
		stage.advance(step)
		_layer(fx).call("_process", step)
		if each.is_valid():
			each.call()


static func _real(kind: String, seed_text: String, phase: String = "intro", variant: String = "") -> Dictionary:
	return PickupRealBoard.snapshot(kind, phase, variant, seed_text)


## The cell the plan says the chooser is walking to at `t`, worked out here from the legs alone.
static func _expected(plan: Dictionary, t: float) -> Dictionary:
	var cell: Dictionary = plan["chooser_cell"]
	for leg: Dictionary in plan["legs"]:
		if t >= float(leg["t0"]):
			cell = (leg["cells"] as Array)[(leg["cells"] as Array).size() - 1]
	return cell


static func _t_cells() -> Dictionary:
	var errors: Array = []
	for combo: Array in [["many", "0"], ["many", "1"], ["empty", "0"]]:
		var snap := _real(combo[0], combo[1])
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var fx := PickupUiHostTests._mount(snap)
		var plan := PickupEventPlan.build(snap)
		var chooser := str(plan["chooser_id"])
		if (plan["legs"] as Array).size() < 2:
			errors.append("%s %s: expected an out leg and a walk" % combo)
		if not _same(_cell(fx, chooser), plan["chooser_cell"]):
			errors.append("%s %s: the chooser does not start on its row tile" % combo)
		_run(fx, float(plan["total"]), func() -> void:
			var t := _stage(fx).clock_time()
			if not _same(_cell(fx, chooser), _expected(plan, t)) and errors.size() < 3:
				errors.append("%s %s: at %s the chooser cell is %s, the legs say %s" % [combo[0], combo[1], t, _cell(fx, chooser), _expected(plan, t)]))
		var out_leg: Dictionary = plan["legs"][0]
		if str(out_leg["kind"]) != "out":
			errors.append("the first leg is not the out leg")
		if not _same(_cell(fx, chooser), plan["chooser_end_cell"]):
			errors.append("%s %s: at the plan total the chooser is not on chooser_end_cell" % combo)
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _telegraph_idle(fx: Dictionary) -> bool:
	var tl := (fx["combat"] as Node).get_node("%MoveTelegraphLayer") as Node
	return float(tl.get("_time_left")) <= 0.0 and tl.get("_settle_cell") == null


static func _t_leg_walk() -> Dictionary:
	var snap := _real("many", "0")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var errors: Array = []
	var legs: Array = plan["legs"]
	for k in mini(legs.size(), 3):
		var leg: Dictionary = legs[k]
		_run(fx, float(leg["t0"]) + 0.02)
		var entry := _entry(fx, chooser)
		var queue: Array = entry.get("path_queue", [])
		var seconds := float(entry.get("seg_duration", 0.0)) * float(queue.size())
		var want := float(leg["t1"]) - float(leg["t0"])
		if queue.is_empty() or absf(seconds - want) > 0.01:
			errors.append("leg %d: path walk of %s s over %d points, the leg takes %s s" % [k, seconds, queue.size(), want])
		if queue.size() != (leg["cells"] as Array).size() - 1:
			errors.append("leg %d: the walk has %d points, the leg enters %d cells" % [k, queue.size(), (leg["cells"] as Array).size() - 1])
		if not _telegraph_idle(fx):
			errors.append("leg %d: a telegraph is showing" % k)
		# Half way through the leg the token is between its start and end tile (it really moves), at the end it is on the end tile.
		var board := (fx["combat"] as Node).get_node("%Board") as TileMapLayer
		var cells: Array = leg["cells"]
		var first := board.map_to_local(Vector2i(int(cells[0]["col"]), int(cells[0]["row"])))
		var last_c: Dictionary = cells[cells.size() - 1]
		var last := board.map_to_local(Vector2i(int(last_c["col"]), int(last_c["row"])))
		_run(fx, (float(leg["t0"]) + float(leg["t1"])) * 0.5)
		var mid := _layer(fx).display_cell_position(chooser)
		if mid.distance_to(first) < 1.0 or mid.distance_to(last) < 1.0:
			errors.append("leg %d: the token is not between its tiles half way (at %s)" % [k, mid])
		_run(fx, float(leg["t1"]) + 0.02)
		if _layer(fx).display_cell_position(chooser).distance_to(last) > 1.0:
			errors.append("leg %d: the token is not on the end tile after the leg" % k)
	return PickupBarkTests._done(fx, errors)


static func _t_repeat_mid_walk() -> Dictionary:
	var snap := _real("many", "0")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var leg: Dictionary = plan["legs"][0]
	_run(fx, (float(leg["t0"]) + float(leg["t1"])) * 0.5)
	var before := _entry(fx, chooser)
	var starts := _stage(fx).start_count()
	var cell := _cell(fx, chooser).duplicate()
	(fx["realm"] as RealmShell).set_snapshot(snap.duplicate(true))
	var after := _entry(fx, chooser)
	var errors: Array = []
	var board := (fx["combat"] as Node).get_node("%Board") as TileMapLayer
	var cells: Array = leg["cells"]
	var end_cell: Dictionary = cells[cells.size() - 1]
	_run(fx, float(leg["t1"]) + 0.05)
	if _layer(fx).display_cell_position(chooser).distance_to(board.map_to_local(Vector2i(int(end_cell["col"]), int(end_cell["row"])))) > 1.0:
		errors.append("after a repeat snapshot the walk did not finish on the leg's end tile")
	if _stage(fx).start_count() != starts or _stage(fx).clock_time() == 0.0:
		errors.append("a repeat snapshot restarted the clock")
	if not _same(_cell(fx, chooser), cell) or (before["path_queue"] as Array).is_empty() or (after["path_queue"] as Array).size() != (before["path_queue"] as Array).size() \
			or not (after["display_pos"] as Vector2).is_equal_approx(before["display_pos"] as Vector2):
		errors.append("a repeat snapshot in the middle of the walk reset or restarted the chooser")
	return PickupBarkTests._done(fx, errors)


static func _t_fade() -> Dictionary:
	var snap := _real("many", "0")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var step0 := float(plan["pointer"]["fade_t"])
	var fade_len := float(plan["pointer"]["mote"]["halo_fade_out"])
	var layer := _layer(fx)
	var mote := (fx["combat"] as Node).get_node("%PickupPointerMote") as PickupPointerMote
	var halo := mote.get_node("%Halo") as Sprite2D
	var errors: Array = []
	_run(fx, step0 - 0.02)
	var full := halo.modulate.a
	var lift := float((layer.get("_brighten") as Dictionary).get(chooser, 0.0))
	if full <= 0.0 or lift <= 0.0:
		errors.append("no halo or brightness before the chooser walks")
	_run(fx, step0 + fade_len * 0.5)
	if not (halo.modulate.a > 0.0 and halo.modulate.a < full) or not (float((layer.get("_brighten") as Dictionary).get(chooser, 0.0)) < lift):
		errors.append("the halo and the brightness do not fade during the fade time")
	_run(fx, step0 + fade_len + 0.05)
	if mote.visible or (halo.get_parent() as Node2D).visible or not (layer.get("_brighten") as Dictionary).is_empty():
		errors.append("the mote (%s), halo (%s) or brightness (%s) is still shown after the fade (clock %s, fade ends %s)" % [mote.visible,
			(halo.get_parent() as Node2D).visible, layer.get("_brighten"), _stage(fx).clock_time(), step0 + fade_len])
	return PickupBarkTests._done(fx, errors)


## During the fade the halo sits on the walking token's draw position (display position plus the feet offset), so it goes with it.
static func _t_halo_follows() -> Dictionary:
	var snap := _real("many", "0")
	var fx := PickupUiHostTests._mount(snap)
	var layer := _layer(fx)
	# A non-zero feet offset (on a private copy of the config) makes a sign error fail.
	var cfg := layer.visual_config.duplicate() as CombatTokenVisualConfig
	cfg.feet_offset_y = 10.0
	layer.visual_config = cfg
	(fx["realm"] as RealmShell).set_snapshot(snap.duplicate(true))
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var halo := ((fx["combat"] as Node).get_node("%PickupPointerMote") as PickupPointerMote).get_node("%Halo") as Sprite2D
	var fade_t := float(plan["pointer"]["fade_t"])
	var fade_len := float(plan["pointer"]["mote"]["halo_fade_out"])
	_run(fx, fade_t + 0.02)
	var errors: Array = []
	var first := halo.position
	var moved := false
	var stage := _stage(fx)
	while stage.clock_time() < fade_t + fade_len - 0.06 and stage.is_clock_running():
		stage.advance(_DT)
		var want := layer.display_cell_position(chooser) + Vector2(0.0, cfg.feet_offset_y)
		if halo.position.distance_to(want) > 0.01 and errors.size() < 2:
			errors.append("at %s the halo is at %s, the token draw position is %s" % [stage.clock_time(), halo.position, want])
		moved = moved or halo.position.distance_to(first) > 1.0
		layer.call("_process", _DT)
	if not moved:
		errors.append("the halo did not move with the walking token")
	return PickupBarkTests._done(fx, errors)


## Probe, never a failing assert: does the chooser's end tile (and each leg tile) lie inside the R2b framed box (row and find tile
## centres grown by half a tile on each side)? The result is printed (R6AFRAME) for the report.
static func _t_end_tile_frame() -> Dictionary:
	for combo: Array in [["many", "0"], ["many", "1"], ["empty", "0"], ["empty", "1"]]:
		var snap := _real(combo[0], combo[1])
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var fx := PickupUiHostTests._mount(snap)
		var board := (fx["combat"] as Node).get_node("%Board") as TileMapLayer
		var half := Vector2(board.tile_set.tile_size) * 0.5
		var plan := PickupEventPlan.build(snap)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c: Vector2i in CombatBoardScreen.pickup_frame_cells(snap["data"]):
			var p := board.map_to_local(c)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		lo -= half
		hi += half
		var report: Array = []
		var tiles: Array = []
		for leg: Dictionary in plan["legs"]:
			tiles.append_array(leg["cells"])
		for c: Dictionary in tiles:
			var p := board.map_to_local(Vector2i(int(c["col"]), int(c["row"])))
			var inside := p.x - half.x >= lo.x and p.x + half.x <= hi.x and p.y - half.y >= lo.y and p.y + half.y <= hi.y
			report.append("(%d,%d)%s" % [int(c["col"]), int(c["row"]), "" if inside else " OUTSIDE"])
		print("R6AFRAME ", combo, " end=", plan["chooser_end_cell"], " box=", lo, hi, " leg tiles: ", " ".join(report))
		PickupUiHostTests._free(fx)
	return { "ok": true }


static func _t_idle() -> Dictionary:
	var errors: Array = []
	for combo: Array in [["many", "0"], ["many", "1"], ["empty", "1"], ["near", "0"]]:
		var snap := _real(combo[0], combo[1], "idle")
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var plan := PickupEventPlan.build(snap)
		var chooser := str(plan["chooser_id"])
		var fx := PickupUiHostTests._mount(snap)
		if not _same(_cell(fx, chooser), plan["chooser_end_cell"]):
			errors.append("%s %s: idle chooser on %s, end tile %s" % [combo[0], combo[1], _cell(fx, chooser), plan["chooser_end_cell"]])
		for e: Dictionary in snap["data"]["row"]:
			if str(e["id"]) != chooser and not _same(_cell(fx, str(e["id"])), e["tile"]):
				errors.append("%s %s: an Echo other than the chooser left its row tile" % combo)
		PickupUiHostTests._free(fx)
	# Skip in the middle of the walk: the idle snapshot puts the chooser on the end tile.
	var intro := _real("many", "0")
	var fx2 := PickupUiHostTests._mount(intro)
	var plan2 := PickupEventPlan.build(intro)
	var leg: Dictionary = plan2["legs"][0]
	_run(fx2, (float(leg["t0"]) + float(leg["t1"])) * 0.5)
	var idle := intro.duplicate(true)
	idle["data"]["phase"] = "idle"
	(fx2["realm"] as RealmShell).set_snapshot(idle)
	_layer(fx2).call("_process", 1.0)
	var board := (fx2["combat"] as Node).get_node("%Board") as TileMapLayer
	var end_cell: Dictionary = plan2["chooser_end_cell"]
	var want := board.map_to_local(Vector2i(int(end_cell["col"]), int(end_cell["row"])))
	if not _same(_cell(fx2, str(plan2["chooser_id"])), end_cell) or _layer(fx2).display_cell_position(str(plan2["chooser_id"])).distance_to(want) > 0.5:
		errors.append("after Skip the chooser is not on the end tile")
	PickupUiHostTests._free(fx2)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_frozen() -> Dictionary:
	var snap := _real("near", "0", "intro", "frozen")
	if snap.is_empty():
		return _fail("the fixture fight did not reach the event")
	var plan := PickupEventPlan.build(snap)
	var fx := PickupUiHostTests._mount(snap)
	var chooser := str(plan["chooser_id"])
	var errors: Array = []
	var legs: Array = plan["legs"]
	if legs.size() != 1 or str(legs[0]["kind"]) != "out":
		errors.append("a frozen chooser should have only the out leg, it has %d legs" % legs.size())
	_run(fx, float(plan["total"]))
	var out_cells: Array = legs[0]["cells"]
	if not _same(_cell(fx, chooser), out_cells[out_cells.size() - 1]) or not _same(_cell(fx, chooser), plan["chooser_end_cell"]):
		errors.append("the frozen chooser does not stop on the out tile")
	return PickupBarkTests._done(fx, errors)


static func _t_invalid_plan() -> Dictionary:
	var errors: Array = []
	for phase: String in ["intro", "idle"]:
		var snap := PickupUiHostTests._pickup("sit_a", 1, phase)
		var fx := PickupUiHostTests._mount(snap)
		for e: Dictionary in snap["data"]["row"]:
			if not _same(_cell(fx, str(e["id"])), e["tile"]):
				errors.append("%s: the Echo %s is not on its row tile with no plan" % [phase, e["id"]])
		if _stage(fx).is_clock_running():
			errors.append("%s: a clock runs with no plan" % phase)
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_snap() -> Dictionary:
	var snap := _real("many", "0")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var board := (fx["combat"] as Node).get_node("%Board") as TileMapLayer
	var errors: Array = []
	# One jump to the end of the out leg: the token is there at once (one frame of the layer), with no walk queued.
	var out_leg: Dictionary = plan["legs"][0]
	_stage(fx).advance(float(out_leg["t1"]))
	_layer(fx).call("_process", 0.01)
	var out_cells: Array = out_leg["cells"]
	var out_cell: Dictionary = out_cells[out_cells.size() - 1]
	var want := board.map_to_local(Vector2i(int(out_cell["col"]), int(out_cell["row"])))
	if not _same(_cell(fx, chooser), out_cell) or _layer(fx).display_cell_position(chooser).distance_to(want) > 0.5 \
			or not (_entry(fx, chooser)["path_queue"] as Array).is_empty():
		errors.append("a jump to the end of the out leg did not place the chooser on the out tile")
	# One jump over every remaining leg: the end tile.
	_stage(fx).advance(float(plan["total"]))
	_layer(fx).call("_process", 0.01)
	var end_cell: Dictionary = plan["chooser_end_cell"]
	var want_end := board.map_to_local(Vector2i(int(end_cell["col"]), int(end_cell["row"])))
	if not _same(_cell(fx, chooser), end_cell) or _layer(fx).display_cell_position(chooser).distance_to(want_end) > 0.5:
		errors.append("a jump over the legs did not place the chooser on the end tile")
	return PickupBarkTests._done(fx, errors)


static func _t_others() -> Dictionary:
	var errors: Array = []
	for seed_text: String in ["0", "1"]:
		var snap := _real("many", seed_text)
		var fx := PickupUiHostTests._mount(snap)
		var combat := fx["combat"] as CombatBoardScreen
		var plan := PickupEventPlan.build(snap)
		var chooser := str(plan["chooser_id"])
		var rows: Array = snap["data"]["row"]
		var cam_pos := combat.camera.position
		_run(fx, float(plan["total"]), func() -> void:
			for e: Dictionary in rows:
				if str(e["id"]) != chooser and not _same(_cell(fx, str(e["id"])), e["tile"]) and errors.size() < 3:
					errors.append("seed %s: Echo %s changed cell" % [seed_text, e["id"]])
			_layer(fx).call("_process", _DT)
			if combat.camera.mode != BoardCameraController.Mode.FREE or combat.camera.target_id != "":
				errors.append("camera left FREE"))
		if combat.camera.position != cam_pos:
			errors.append("camera position changed")
		if not _telegraph_idle(fx):
			errors.append("a telegraph is showing")
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 3)) }


## The per-token `move_duration` is read before the layer's own value; without it the layer value stands.
static func _t_duration_override() -> Dictionary:
	var layer := CombatTokenLayer.new()
	var errors: Array = []
	var tok := func(cell: int, extra: Dictionary) -> Array[Dictionary]:
		var d := { "actor_id": "a", "grid_pos": { "col": cell, "row": 0 }, "cell_pos": Vector2(float(cell) * 64.0, 0.0), "faction": "echo" }
		d.merge(extra)
		return [d] as Array[Dictionary]
	layer.apply_snapshot(tok.call(0, {}))
	var path: Array[Vector2] = [Vector2(64.0, 0.0), Vector2(128.0, 0.0)]
	var walk := { "action_type": "pickup.walk", "source_id": "a" }
	var event: Dictionary = layer.apply_snapshot(tok.call(2, { "move_duration": 1.2 }), "", walk, path)
	var entry: Dictionary = (layer.get("_presentation_state") as Object).call("get_entry", "a")
	if not event.is_empty():
		errors.append("a pickup.walk made a telegraph")
	if absf(float(entry["seg_duration"]) * 2.0 - 1.2) > 1e-6 or (entry["path_queue"] as Array).size() != 2:
		errors.append("the walk does not take the token's own time (%s)" % [entry])
	layer.reset_presentation()
	layer.apply_snapshot(tok.call(0, {}))
	layer.apply_snapshot(tok.call(2, {}), "", walk, path)
	var plain: Dictionary = (layer.get("_presentation_state") as Object).call("get_entry", "a")
	if absf(float(plain["seg_duration"]) * 2.0 - layer.visual_config.move_duration) > 1e-6:
		errors.append("without the key the layer time (%s) is not used (%s)" % [layer.visual_config.move_duration, plain["seg_duration"]])
	layer.free()
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
