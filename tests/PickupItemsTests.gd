# res://tests/PickupItemsTests.gd
# V2-ITEM-001b R6c: the finds in the intro. The reveal flip, the lift and the flight into the pack strip follow the plan at the clock
# time; the strip fills as each find lands. The state is a pure function of (plan, t). Part of the suite `pickup_ui`.

class_name PickupItemsTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/items_state_follows_the_plan_at_sample_times", Callable(PickupItemsTests, "_t_states"))
	runner.register_test("pickup_ui/items_flight_ends_on_the_slot_centre_at_any_zoom_and_pan", Callable(PickupItemsTests, "_t_zoom_pan"))
	runner.register_test("pickup_ui/items_flip_changes_the_face_at_the_middle_only", Callable(PickupItemsTests, "_t_flip"))
	runner.register_test("pickup_ui/items_strip_fills_after_each_landing_and_the_tone_changes_at_the_last", Callable(PickupItemsTests, "_t_strip"))
	runner.register_test("pickup_ui/items_intro_end_equals_the_idle_picture", Callable(PickupItemsTests, "_t_end_equals_idle"))
	runner.register_test("pickup_ui/items_clock_jump_equals_stepping_and_a_repeat_snapshot_keeps_the_state", Callable(PickupItemsTests, "_t_jump_and_repeat"))
	runner.register_test("pickup_ui/items_no_plan_draws_the_still_intro", Callable(PickupItemsTests, "_t_no_plan"))
	runner.register_test("pickup_ui/items_config_reaches_the_lift", Callable(PickupItemsTests, "_t_config"))
	runner.register_test("pickup_ui/items_carried_find_is_held_above_the_chooser_after_a_jump_and_flies_from_there", Callable(PickupItemsTests, "_t_carry"))
	runner.register_test("pickup_ui/items_beats_are_slower_and_come_from_the_config", Callable(PickupItemsTests, "_t_pacing"))
	runner.register_test("pickup_ui/items_frozen_chooser_lifts_nothing", Callable(PickupItemsTests, "_t_frozen"))
	runner.register_test("pickup_ui/items_source_has_no_node_creation_and_no_theme_change", Callable(PickupItemsTests, "_t_source"))


static func _fail(text: String) -> Dictionary:
	return { "ok": false, "error": text }


static func _real(kind: String, seed_text: String, phase: String = "intro", variant: String = "") -> Dictionary:
	return PickupRealBoard.snapshot(kind, phase, variant, seed_text)


static func _layer(fx: Dictionary) -> PickupFindsLayer:
	return (fx["combat"] as Node).get_node("%PickupFindsLayer") as PickupFindsLayer


static func _stage(fx: Dictionary) -> PickupEventStage:
	return PickupUiHostTests._stage(fx)


static func _strip(fx: Dictionary) -> PickupPackStrip:
	return _stage(fx).pack_strip()


## Moves the intro clock to `t` (forward only) in one tick.
static func _go(fx: Dictionary, t: float) -> void:
	_stage(fx).advance(maxf(t - _stage(fx).clock_time(), 0.0))


## The place a carried find is held above the chooser's token. The token layer moves a token on its next frame, so this lets one
## frame pass first (no clock tick) and reads the token's real drawn centre: a value the code under test computed from a stale
## token position cannot match it.
static func _head(fx: Dictionary, plan: Dictionary, look: Dictionary) -> Vector2:
	var tokens := (fx["combat"] as Node).get_node("%TokenLayer") as CombatTokenLayer
	tokens.call("_process", 1.0)
	var pos := tokens.display_cell_position(str(plan["chooser_id"])) + Vector2(0.0, tokens.visual_config.feet_offset_y)
	return pos - Vector2(0.0, tokens.visual_config.token_radius + float(look["carry_above"]))


static func _centre(tile: Control) -> Vector2:
	return tile.position + tile.size * 0.5


## A comparable picture of the finds layer: for every visible mark its find, face name, centre and scale.
static func _marks_view(fx: Dictionary, data: Dictionary) -> Array:
	var out: Array = []
	var layer := _layer(fx)
	var finds := PickupFindsLayer.ground_finds(data)
	for i in mini(finds.size(), layer.mark_count()):
		var tile := layer.mark(i)
		if tile.visible:
			out.append({ "find": str(finds[i]["find_id"]), "name": str((tile.get("row") as Dictionary).get("name", "")),
				"centre": _centre(tile).snapped(Vector2(0.01, 0.01)), "scale": tile.scale.snapped(Vector2(0.001, 0.001)) })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["find"]) < str(b["find"]))
	return out


static func _sample_times(plan: Dictionary) -> Array:
	var times: Array = []
	for f: Dictionary in plan["finds"]:
		var rv := float(f["reveal"])
		var rl := float(f["reveal_len"])
		times.append_array([rv - 0.02, rv + rl * 0.25, rv + rl + 0.02])
		if bool(f["walked"]) and not bool(f["is_try"]):
			times.append_array([(float(f["lift0"]) + float(f["lift1"])) * 0.5, (float(f["fly0"]) + float(f["fly1"])) * 0.5, float(f["fly1"]) + 0.02])
	times = times.filter(func(t: float) -> bool: return t > 0.0 and t < float(plan["total"]))
	times.sort()
	return times


static func _t_states() -> Dictionary:
	var errors: Array = []
	for combo: Array in [["many", "0"], ["empty", "0"], ["near", "0"]]:
		var snap := _real(combo[0], combo[1])
		if snap.is_empty():
			return _fail("the fixture fight did not reach the event")
		var fx := PickupUiHostTests._mount(snap)
		var plan := PickupEventPlan.build(snap)
		var layer := _layer(fx)
		var finds := PickupFindsLayer.ground_finds(snap["data"])
		var look: Dictionary = plan["items_look"]
		for t: float in _sample_times(plan):
			_go(fx, t)
			var items: Dictionary = PickupEventPlan.frame_at(plan, t)["items"]
			for i in finds.size():
				var f: Dictionary = finds[i]
				var item: Dictionary = items[str(f["find_id"])]
				var state := str(item["state"])
				if str(f["status"]) == "tried" and state in ["lifted", "flying", "pack"]:
					state = "revealed"
				var tile := layer.mark(i)
				var where := "%s %s find %d at %.2f (%s)" % [combo[0], combo[1], i, t, state]
				var faces: Array = layer.get("_faces")
				match state:
					"hidden":
						if not tile.visible or faces[i] != "empty" or not tile.scale.is_equal_approx(Vector2.ONE):
							errors.append(where + ": not the plain empty card")
					"revealed":
						var rev := float(item["rev"])
						if not tile.visible or (faces[i] == "real") != (rev >= 0.5) or absf(tile.scale.x - (absf(1.0 - 2.0 * rev) if rev < 1.0 else 1.0)) > 0.001:
							errors.append(where + ": wrong face or flip (rev %s, scale %s)" % [rev, tile.scale])
					"lifted":
						var want := layer.mark_center(i).lerp(_head(fx, plan, look), float(item["p"]))
						if not tile.visible or (faces[i] == "real") != (float(item["rev"]) >= 0.5) or _centre(tile).distance_to(want) > 1.0:
							errors.append(where + ": not carried from its tile to the chooser's head (at %s, wanted %s)" % [_centre(tile), want])
					"flying":
						var from: Vector2 = (layer.get("_fly_from") as Dictionary).get(str(f["find_id"]), Vector2.INF)
						var c := _centre(tile)
						if not tile.visible or tile.z_index != 1 or faces[i] != "real":
							errors.append(where + ": a flying tile must be visible, real and above the tokens")
						elif c.distance_to(from) < 0.01 and float(item["p"]) > 0.05:
							errors.append(where + ": the flying tile did not leave the lifted place")
					"pack":
						if tile.visible:
							errors.append(where + ": a landed find is still on the board")
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 3)) }


static func _t_zoom_pan() -> Dictionary:
	var snap := _real("empty", "0")
	var fx := PickupUiHostTests._mount(snap)
	var combat := fx["combat"] as CombatBoardScreen
	var plan := PickupEventPlan.build(snap)
	var layer := _layer(fx)
	var errors: Array = []
	var taken: Array = (plan["finds"] as Array).filter(func(f: Dictionary) -> bool: return bool(f["walked"]) and not bool(f["is_try"]))
	if taken.is_empty():
		return PickupBarkTests._done(fx, ["the fixture has no taken find"])
	var f: Dictionary = taken[0]
	var finds := PickupFindsLayer.ground_finds(snap["data"])
	var index := 0
	for i in finds.size():
		if str(finds[i]["find_id"]) == str(f["find_id"]):
			index = i
	var before := layer.get_global_transform_with_canvas()
	var seen := 0
	for view: Array in [[1.0, Vector2.ZERO], [0.6, Vector2(120.0, -60.0)], [1.7, Vector2(-80.0, 40.0)]]:
		combat.camera.zoom = Vector2(float(view[0]), float(view[0]))
		combat.camera.position += view[1] as Vector2
		combat.camera.force_update_scroll()
		var xf := layer.get_global_transform_with_canvas()
		if not xf.is_equal_approx(before):
			seen += 1
		before = xf
		_stage(fx).advance(0.0)
		# Just before the flight ends the tile is on the slot, as big as the slot bed.
		var t := float(f["fly1"]) - 0.0005
		if _stage(fx).clock_time() < t:
			_go(fx, t)
		else:
			_stage(fx).advance(0.0)
		var strip := _strip(fx)
		var slot := strip.slot_index_of_find(str(f["find_id"]))
		var want := strip.get_canvas_transform() * strip.slot_global_center(slot)
		var tile := layer.mark(index)
		var got := xf * _centre(tile)
		if not tile.visible or got.distance_to(want) > 1.0:
			errors.append("zoom %s: the flying tile ends at %s, the slot centre is %s" % [view[0], got, want])
		var edge := tile.size.x * tile.scale.y * xf.get_scale().x
		if absf(edge - strip.bed_size()) > 1.0:
			errors.append("zoom %s: the tile is %s px wide on arrival, the slot bed is %s" % [view[0], edge, strip.bed_size()])
		# The clock is forward only: rewind by remounting is not needed, later views read the same moment.
	if seen < 1:
		errors.append("the camera changes did not move the canvas transform, so the test proves nothing")
	return PickupBarkTests._done(fx, errors)


static func _t_flip() -> Dictionary:
	var snap := _real("empty", "0")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var layer := _layer(fx)
	var f: Dictionary = (plan["finds"] as Array)[0]
	var finds := PickupFindsLayer.ground_finds(snap["data"])
	var index := 0
	for i in finds.size():
		if str(finds[i]["find_id"]) == str(f["find_id"]):
			index = i
	var errors: Array = []
	var rv := float(f["reveal"])
	var rl := float(f["reveal_len"])
	# Find the times where the smooth reveal passes 0.5 and check the face on both sides of it.
	var mid := rv + rl * 0.5
	_go(fx, mid - 0.01)
	var faces_before: String = (layer.get("_faces") as Array)[index]
	var scale_before := layer.mark(index).scale.x
	_go(fx, mid + 0.01)
	var faces_after: String = (layer.get("_faces") as Array)[index]
	var scale_after := layer.mark(index).scale.x
	if faces_before != "empty" or faces_after != "real":
		errors.append("the face does not change at the middle of the flip (%s, %s)" % [faces_before, faces_after])
	if scale_before > 0.2 or scale_after > 0.2:
		errors.append("the card is not edge on at the middle (%s, %s)" % [scale_before, scale_after])
	_go(fx, rv + rl + 0.01)
	if absf(layer.mark(index).scale.x - 1.0) > 0.001:
		errors.append("the card is not full width after the flip")
	return PickupBarkTests._done(fx, errors)


static func _t_strip() -> Dictionary:
	var errors: Array = []
	var tone_changes := 0
	for combo: Array in [["empty", "0"], ["near", "0"]]:
		var snap := _real(combo[0], combo[1])
		var fx := PickupUiHostTests._mount(snap)
		var plan := PickupEventPlan.build(snap)
		var strip := _strip(fx)
		var taken: Array = (plan["finds"] as Array).filter(func(f: Dictionary) -> bool: return bool(f["walked"]) and not bool(f["is_try"]))
		taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["fly1"]) < float(b["fly1"]))
		if taken.is_empty():
			errors.append("%s: no taken find" % combo[0])
		var tone_before: String = str(snap["data"]["pack"]["tone_before"])
		var tone_after: String = str(snap["data"]["pack"]["tone"])
		if tone_before != tone_after:
			tone_changes += 1
		for k in taken.size():
			var f: Dictionary = taken[k]
			var slot := strip.slot_index_of_find(str(f["find_id"]))
			_go(fx, float(f["fly1"]) - 0.02)
			var before: Dictionary = (strip.view()["cells"] as Array)[slot]
			var tone_mid := str(strip.view()["tone"])
			_go(fx, float(f["fly1"]) + 0.02)
			var after: Dictionary = (strip.view()["cells"] as Array)[slot]
			if str(before["kind"]) != "empty" or str(after["kind"]) != "item" or str(after["row"]["find_id"]) != str(f["find_id"]):
				errors.append("%s find %d: slot %d is %s before and %s after its landing" % [combo[0], k, slot, before["kind"], after["kind"]])
			var last := k == taken.size() - 1
			if str(strip.view()["tone"]) != (tone_after if last else tone_before) or (last and tone_mid != tone_before and tone_before != tone_after):
				errors.append("%s find %d: tone %s after its landing (before it: %s), expected %s" % [combo[0], k, strip.view()["tone"], tone_mid, tone_after if last else tone_before])
		PickupUiHostTests._free(fx)
	if tone_changes == 0:
		errors.append("no fixture changes tone, so the tone check proves nothing")
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 3)) }


static func _strip_picture(strip: PickupPackStrip) -> String:
	var v := strip.view()
	return JSON.stringify([v["cells"], v["tone"], v["count"]], "", true)


static func _t_end_equals_idle() -> Dictionary:
	var errors: Array = []
	for combo: Array in [["empty", "0"], ["many", "0"]]:
		var intro := _real(combo[0], combo[1])
		var idle := _real(combo[0], combo[1], "idle")
		if intro.is_empty() or idle.is_empty():
			return _fail("the fixture fight did not reach the event")
		var fx := PickupUiHostTests._mount(intro)
		_go(fx, float(PickupEventPlan.build(intro)["total"]))
		var fx2 := PickupUiHostTests._mount(idle)
		var a := _marks_view(fx, intro["data"])
		var b := _marks_view(fx2, idle["data"])
		if JSON.stringify(a) != JSON.stringify(b):
			errors.append("%s %s: the finds at the intro end are %s, idle %s" % [combo[0], combo[1], a, b])
		if _strip_picture(_strip(fx)) != _strip_picture(_strip(fx2)):
			errors.append("%s %s: the strip at the intro end differs from the idle strip" % [combo[0], combo[1]])
		PickupUiHostTests._free(fx)
		PickupUiHostTests._free(fx2)
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 2)) }


static func _t_jump_and_repeat() -> Dictionary:
	var snap := _real("empty", "0")
	var plan := PickupEventPlan.build(snap)
	var f: Dictionary = ((plan["finds"] as Array).filter(func(x: Dictionary) -> bool: return bool(x["walked"]) and not bool(x["is_try"])))[0]
	var at := (float(f["fly0"]) + float(f["fly1"])) * 0.5
	var stepped := PickupUiHostTests._mount(snap)
	var t := 0.0
	while t < at:
		t = minf(t + 0.05, at)
		_go(stepped, t)
	var jumped := PickupUiHostTests._mount(snap)
	_go(jumped, at)
	var errors: Array = []
	if JSON.stringify(_marks_view(stepped, snap["data"])) != JSON.stringify(_marks_view(jumped, snap["data"])) \
			or _strip_picture(_strip(stepped)) != _strip_picture(_strip(jumped)):
		errors.append("a jump of the clock does not give the state of stepping")
	var before := JSON.stringify(_marks_view(stepped, snap["data"]))
	var strip_before := _strip_picture(_strip(stepped))
	var starts := _stage(stepped).start_count()
	(stepped["realm"] as RealmShell).set_snapshot(snap.duplicate(true))
	if JSON.stringify(_marks_view(stepped, snap["data"])) != before or _strip_picture(_strip(stepped)) != strip_before or _stage(stepped).start_count() != starts:
		errors.append("a repeat snapshot reset the finds, the strip or the clock")
	PickupUiHostTests._free(jumped)
	return PickupBarkTests._done(stepped, errors)


static func _t_no_plan() -> Dictionary:
	var snap := _real("empty", "0")
	(snap["data"] as Dictionary).erase("pointer_look")
	var fx := PickupUiHostTests._mount(snap)
	var errors: Array = []
	var layer := _layer(fx)
	var faces: Array = layer.get("_faces")
	for i in layer.mark_count():
		if layer.mark(i).visible and faces[i] != "":
			errors.append("a mark was drawn by the intro with no plan")
	var legacy := PickupPackStrip.view_of(snap)
	if _strip_picture(_strip(fx)) != JSON.stringify([legacy["cells"], legacy["tone"], legacy["count"]], "", true):
		errors.append("the strip is not the still pre-event strip")
	if _stage(fx).is_clock_running():
		errors.append("a clock runs with no plan")
	return PickupBarkTests._done(fx, errors)


static func _t_config() -> Dictionary:
	var snap := _real("empty", "0")
	(snap["data"]["pointer_look"]["items"] as Dictionary)["carry_above"] = 60.0
	var plan := PickupEventPlan.build(snap)
	var fx := PickupUiHostTests._mount(snap)
	var f: Dictionary = ((plan["finds"] as Array).filter(func(x: Dictionary) -> bool: return bool(x["walked"]) and not bool(x["is_try"])))[0]
	var finds := PickupFindsLayer.ground_finds(snap["data"])
	var index := 0
	for i in finds.size():
		if str(finds[i]["find_id"]) == str(f["find_id"]):
			index = i
	_go(fx, float(f["lift1"]) + 0.01)
	var errors: Array = []
	var held := _head(fx, plan, plan["items_look"])
	if float(plan["items_look"]["carry_above"]) != 60.0 or _centre(_layer(fx).mark(index)).distance_to(held) > 1.0:
		errors.append("carry_above 60 from the config: the carried find is at %s, the head place is %s" % [_centre(_layer(fx).mark(index)), held])
	return PickupBarkTests._done(fx, errors)


static func _taken_first(plan: Dictionary) -> Dictionary:
	var taken: Array = (plan["finds"] as Array).filter(func(x: Dictionary) -> bool: return bool(x["walked"]) and not bool(x["is_try"]))
	taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["lift0"]) < float(b["lift0"]))
	return taken[0]


static func _index_of(snap: Dictionary, find_id: String) -> int:
	var finds := PickupFindsLayer.ground_finds(snap["data"])
	for i in finds.size():
		if str(finds[i]["find_id"]) == find_id:
			return i
	return 0


## Carry: after a jump of the clock the card is above the chooser's drawn head (read after a frame of the token layer, no new tick), in
## the hold, at the start of a flight and for a flight entered by a jump; the flight starts at the carried place.
static func _t_carry() -> Dictionary:
	var snap := _real("empty", "0")
	var plan := PickupEventPlan.build(snap)
	var look: Dictionary = plan["items_look"]
	var f := _taken_first(plan)
	var index := _index_of(snap, str(f["find_id"]))
	var errors: Array = []
	# A jump of the clock (no stepping): the token layer has not moved the token yet when the card is placed. After one frame of
	# the token layer, with no new clock tick, the card must still be above the token's drawn centre, in the hold and at the
	# start of the flight, and a jump into the middle of a flight must have started the flight from the same place.
	for when: Array in [["hold", (float(f["lift1"]) + float(f["fly0"])) * 0.5, 1.0], ["flight start", float(f["fly0"]) + 0.002, 3.0],
			["mid flight", (float(f["fly0"]) + float(f["fly1"])) * 0.5, 1.0]]:
		var jumped := PickupUiHostTests._mount(snap)
		_go(jumped, float(when[1]))
		var head_now := _head(jumped, plan, look)
		var tile := _layer(jumped).mark(index)
		if when[0] != "mid flight" and _centre(tile).distance_to(head_now) > float(when[2]):
			errors.append("%s after a jump: the card is at %s, the chooser's drawn head place is %s" % [when[0], _centre(tile), head_now])
		var from: Vector2 = (_layer(jumped).get("_fly_from") as Dictionary).get(str(f["find_id"]), Vector2.INF)
		if when[0] != "hold" and from.distance_to(head_now) > 1.0:
			errors.append("%s after a jump: the flight started from %s, the head place is %s" % [when[0], from, head_now])
		PickupUiHostTests._free(jumped)
	var fx := PickupUiHostTests._mount(snap)
	var layer := _layer(fx)
	_go(fx, (float(f["lift1"]) + float(f["fly0"])) * 0.5)
	var head := _head(fx, plan, look)
	if _centre(layer.mark(index)).distance_to(head) > 1.0:
		errors.append("in the hold the card is at %s, the chooser's head place is %s" % [_centre(layer.mark(index)), head])
	# While the chooser stands the card is placed from the plan, not from the live token: a token that is somewhere else (an
	# artificial move, never in play) does not drag the card, and the flight starts from the planned head place.
	var combat := fx["combat"] as CombatBoardScreen
	var base: Array = combat.get("_pickup_base_actors")
	var elsewhere := CombatBoardScreen.pickup_actors_at(base, str(plan["chooser_id"]), { "cell": { "col": 3, "row": 3 }, "snap": true })
	combat.call("_draw_tokens", elsewhere, "", {})
	_stage(fx).advance(0.0)
	if _centre(layer.mark(index)).distance_to(head) > 1.0:
		errors.append("a displaced token dragged the card of a standing chooser (card %s, planned head %s)" % [_centre(layer.mark(index)), head])
	_go(fx, float(f["fly0"]) + 0.002)
	if _centre(layer.mark(index)).distance_to(head) > 3.0:
		errors.append("the flight does not start at the planned carried place (%s, head %s)" % [_centre(layer.mark(index)), head])
	return PickupBarkTests._done(fx, errors)


## The new pacing comes from the config: reveal, carry, hold, flight and the pause before the next stop; the plan is longer.
static func _t_pacing() -> Dictionary:
	var snap := _real("empty", "0")
	var plan := PickupEventPlan.build(snap)
	var look: Dictionary = plan["items_look"]
	var errors: Array = []
	var reduced_total := float(PickupEventPlan.build(snap, { "reduced": true })["total"])
	if float(plan["total"]) <= reduced_total:
		errors.append("the plan total %s is not longer than the reduced one %s" % [plan["total"], reduced_total])
	var taken: Array = (plan["finds"] as Array).filter(func(x: Dictionary) -> bool: return bool(x["walked"]) and not bool(x["is_try"]))
	taken.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["lift0"]) < float(b["lift0"]))
	for k in taken.size():
		var f: Dictionary = taken[k]
		if absf(float(f["reveal_len"]) - float(look["reveal_len"])) > 1e-6 or absf(float(f["lift1"]) - float(f["lift0"]) - float(look["carry_len"])) > 1e-6 \
				or absf(float(f["fly0"]) - float(f["lift1"]) - float(look["carry_hold"])) > 1e-6 or absf(float(f["fly1"]) - float(f["fly0"]) - float(look["fly_len"])) > 1e-6:
			errors.append("find %d: the beats do not follow the config" % k)
		if float(f["lift0"]) < float(f["arrive"]) + float(look["reveal_len"]) - 1e-6:
			errors.append("find %d: the carry starts before the flip ends" % k)
		if k + 1 < taken.size() and float(taken[k + 1]["walk0"]) < float(f["fly1"]) + float(look["step_gap"]) - 1e-6:
			errors.append("find %d: the chooser leaves before the pause after the landing" % k)
	# A changed config changes the plan: a longer flight and a longer carry hold.
	var slow := _real("empty", "0")
	slow["data"]["pointer_look"]["items"]["fly_len"] = 1.0
	slow["data"]["pointer_look"]["items"]["carry_hold"] = 0.5
	var slow_plan := PickupEventPlan.build(slow)
	var sf := _taken_first(slow_plan)
	if absf(float(sf["fly1"]) - float(sf["fly0"]) - 1.0) > 1e-6 or absf(float(sf["fly0"]) - float(sf["lift1"]) - 0.5) > 1e-6 or float(slow_plan["total"]) <= float(plan["total"]):
		errors.append("fly_len and carry_hold from the config do not reach the plan")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_frozen() -> Dictionary:
	var snap := _real("near", "0", "intro", "frozen")
	if snap.is_empty():
		return _fail("the fixture fight did not reach the event")
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap)
	var layer := _layer(fx)
	var errors: Array = []
	var t := 0.0
	while t < float(plan["total"]):
		t = minf(t + 0.1, float(plan["total"]))
		_go(fx, t)
		for i in layer.mark_count():
			if layer.mark(i).visible and (layer.mark(i).z_index != 0 or layer.mark(i).position.y + layer.mark(i).size.y * 0.5 < layer.mark_center(i).y - 0.01):
				errors.append("a find was lifted or flew in a frozen intro (at %.2f)" % t)
				break
	var after := _marks_view(fx, snap["data"])
	if after.size() != PickupFindsLayer.ground_finds(snap["data"]).size():
		errors.append("the finds are not all on the ground at the end of a frozen intro")
	return PickupBarkTests._done(fx, errors.slice(0, 2))


static func _t_source() -> Dictionary:
	for path: String in ["res://ui/screens/combat/PickupFindsLayer.gd", "res://ui/screens/combat/PickupPackStrip.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for banned: String in ["add_child", "Label.new", "Button.new", "Panel.new", "StyleBoxFlat", "theme_type_variation = &\"Pickup"]:
			if src.contains(banned) and not (path.ends_with("PickupPackStrip.gd") and banned.begins_with("theme_type")):
				return _fail("%s contains %s" % [path, banned])
	var layer_src := FileAccess.get_file_as_string("res://ui/screens/combat/PickupFindsLayer.gd")
	if layer_src.contains("Color(") or layer_src.contains("Color.html"):
		return _fail("the finds layer holds a colour of its own")
	return { "ok": true }
