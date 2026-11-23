# res://tests/PickupIntroTests.gd
# V2-ITEM-001b R6d: the bark in the intro at the plan's time, the skip transition, and reduced motion. Part of the suite `pickup_ui`.

class_name PickupIntroTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/intro_bark_shows_at_the_plan_time_once_and_the_flip_keeps_it", Callable(PickupIntroTests, "_t_bark"))
	runner.register_test("pickup_ui/intro_skip_shows_the_idle_picture_at_once_and_fades_the_mote", Callable(PickupIntroTests, "_t_skip"))
	runner.register_test("pickup_ui/intro_new_event_inside_a_skip_fade_leaves_no_old_mote", Callable(PickupIntroTests, "_t_new_event_in_fade"))
	runner.register_test("pickup_ui/intro_reduced_motion_flag_gives_short_plain_beats", Callable(PickupIntroTests, "_t_reduced"))
	runner.register_test("pickup_ui/intro_reduced_plan_skip_state_equals_the_last_frame", Callable(PickupIntroTests, "_t_reduced_skip_state"))
	runner.register_test("pickup_ui/intro_flag_off_builds_the_normal_plan", Callable(PickupIntroTests, "_t_flag_off"))


static func _fail(text: String) -> Dictionary:
	return { "ok": false, "error": text }


static func _real(kind: String, seed_text: String, phase: String = "intro") -> Dictionary:
	return PickupRealBoard.snapshot(kind, phase, "", seed_text)


static func _popup_count(fx: Dictionary) -> int:
	return PickupBarkTests._popups(fx).size()


static func _t_bark() -> Dictionary:
	var snap := _real("empty", "0")
	var idle := _real("empty", "0", "idle")
	if snap.is_empty() or idle.is_empty():
		return _fail("the fixture fight did not reach the event")
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var t0 := float(plan["bark"]["t0"])
	var errors: Array = []
	var fx := PickupUiHostTests._mount(snap)
	PickupItemsTests._go(fx, t0 - 0.05)
	if _popup_count(fx) != 0:
		errors.append("a bark before its time")
	PickupItemsTests._go(fx, t0 + 0.05)
	if _popup_count(fx) != 1 or not PickupBarkTests._popups(fx).has(chooser):
		return PickupBarkTests._done(fx, ["no single popup for the chooser after the bark time (%d)" % _popup_count(fx)])
	var node: Control = PickupBarkTests._popups(fx)[chooser]["node"]
	if PickupBarkTests._line(fx, chooser) != str(plan["bark"]["text"]):
		errors.append("the intro bark is not the planner line")
	var pos := node.position
	# The flip to idle keeps the same popup (no second bubble, no restart).
	(fx["realm"] as RealmShell).set_snapshot(idle)
	if _popup_count(fx) != 1 or (PickupBarkTests._popups(fx)[chooser]["node"] as Control) != node:
		errors.append("the flip to idle changed the popup")
	# The same place as the idle picture of the same event.
	var fx_idle := PickupUiHostTests._mount(idle)
	if not PickupBarkTests._popups(fx_idle).has(chooser) or ((PickupBarkTests._popups(fx_idle)[chooser]["node"] as Control).position - pos).length() > 15.0:
		errors.append("the intro bark is not where the idle bark is")
	if PickupBarkTests._line(fx_idle, chooser) != PickupBarkTests._line(fx, chooser):
		errors.append("the idle line differs from the intro line")
	PickupUiHostTests._free(fx_idle)
	# A jump past the bark time gives the same popup as stepping.
	var jumped := PickupUiHostTests._mount(snap)
	PickupItemsTests._go(jumped, t0 + 0.05)
	if _popup_count(jumped) != 1 or ((PickupBarkTests._popups(jumped)[chooser]["node"] as Control).position - pos).length() > 0.5:
		errors.append("a jump past the bark time does not give the stepped popup")
	PickupUiHostTests._free(jumped)
	return PickupBarkTests._done(fx, errors)


## Skip while the mote is on its way, while a find is carried and while one flies.
static func _t_skip() -> Dictionary:
	var snap := _real("empty", "0")
	var idle := _real("empty", "0", "idle")
	var plan := PickupEventPlan.build(snap)
	var f := PickupItemsTests._taken_first(plan)
	var errors: Array = []
	var fade := float(plan["pointer"]["mote"]["skip_fade"])
	var fx_idle := PickupUiHostTests._mount(idle)
	var want_marks := PickupItemsTests._marks_view(fx_idle, idle["data"])
	var want_strip := PickupItemsTests._strip_picture(PickupItemsTests._strip(fx_idle))
	PickupUiHostTests._free(fx_idle)
	for when: Array in [["pointer", float(plan["times"]["pointer0"]) + 0.5 * float(plan["pointer"]["total"])], ["carry", (float(f["lift0"]) + float(f["lift1"])) * 0.5], ["flight", (float(f["fly0"]) + float(f["fly1"])) * 0.5]]:
		var fx := PickupUiHostTests._mount(snap)
		var combat := fx["combat"] as CombatBoardScreen
		PickupItemsTests._go(fx, float(when[1]))
		var mote := combat.get_node("%PickupPointerMote") as PickupPointerMote
		var halo_layer := combat.get_node("%PickupPointerHalo") as Node2D
		var before_alpha := (mote.get_node("%Mote") as Sprite2D).modulate.a
		(fx["realm"] as RealmShell).set_snapshot(idle)
		var tag := str(when[0])
		if JSON.stringify(PickupItemsTests._marks_view(fx, idle["data"])) != JSON.stringify(want_marks) or PickupItemsTests._strip_picture(PickupItemsTests._strip(fx)) != want_strip:
			errors.append("%s: the finds or the strip are not the idle picture at once" % tag)
		if _popup_count(fx) != 1:
			errors.append("%s: the bark is not shown at once" % tag)
		if not mote.visible and when[0] == "pointer":
			errors.append("%s: the mote vanished at once instead of fading" % tag)
		combat.call("_process", fade * 0.5)
		var mid_alpha := (mote.get_node("%Mote") as Sprite2D).modulate.a
		if mote.visible and not (mid_alpha < before_alpha or before_alpha == 0.0):
			errors.append("%s: the mote does not fade (%s then %s)" % [tag, before_alpha, mid_alpha])
		combat.call("_process", fade + 0.1)
		var layer := PickupItemsTests._layer(fx)
		var ghost := false
		for i in layer.mark_count():
			if layer.mark(i).visible and (layer.mark(i).z_index != 0 or layer.mark(i).modulate.a < 1.0):
				ghost = true
		if mote.visible or halo_layer.visible or ghost or not ((combat.get_node("%TokenLayer") as Node).get("_brighten") as Dictionary).is_empty():
			errors.append("%s: a mote, halo, brightness or ghost card remains after the fade" % tag)
		(fx["realm"] as RealmShell).set_snapshot(idle)
		if float(combat.get("_pickup_skip_left")) >= 0.0 or mote.visible:
			errors.append("%s: a second flip did something" % tag)
		if combat.camera.mode != BoardCameraController.Mode.FREE:
			errors.append("%s: the camera left FREE" % tag)
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 3)) }


## The flag on: run the body, then put the flag back (a failed check must not leak it).
## A new event inside the fade after a Skip, also one whose plan is not valid: the old mote and its fade are gone, with no error.
static func _t_new_event_in_fade() -> Dictionary:
	var snap := _real("empty", "0")
	var idle := _real("empty", "0", "idle")
	var plan := PickupEventPlan.build(snap)
	var errors: Array = []
	for broken: bool in [false, true]:
		var fx := PickupUiHostTests._mount(snap)
		var combat := fx["combat"] as CombatBoardScreen
		PickupItemsTests._go(fx, float(plan["times"]["pointer0"]) + 0.5 * float(plan["pointer"]["total"]))
		(fx["realm"] as RealmShell).set_snapshot(idle)
		if float(combat.get("_pickup_skip_left")) < 0.0:
			errors.append("the skip fade did not start")
		var next := snap.duplicate(true)
		next["data"]["run_count"] = int(next["data"]["run_count"]) + 1
		if broken:
			(next["data"] as Dictionary).erase("pointer_look")
		(fx["realm"] as RealmShell).set_snapshot(next)
		var mote := combat.get_node("%PickupPointerMote") as PickupPointerMote
		if float(combat.get("_pickup_skip_left")) >= 0.0 or not (combat.get("_pickup_last_pose") as Dictionary).is_empty() or mote.visible:
			errors.append("broken %s: the old fade or mote survived a new event" % broken)
		combat.call("_process", float(plan["pointer"]["mote"]["skip_fade"]) + 0.1)
		if mote.visible or not ((combat.get_node("%TokenLayer") as Node).get("_brighten") as Dictionary).is_empty():
			errors.append("broken %s: a mote or a brightness is left after the new event" % broken)
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_reduced() -> Dictionary:
	StopMarkMotion.reduced = false
	StopMarkMotion.reduced = true
	var result := _reduced_body()
	StopMarkMotion.reduced = false
	return result


static func _reduced_body() -> Dictionary:
	var snap := _real("empty", "0")
	var normal := PickupEventPlan.build(snap, { "reduced": false })
	var fx := PickupUiHostTests._mount(snap)
	var plan := PickupEventPlan.build(snap, PickupEventPlan.board_opts())
	var errors: Array = []
	var combat := fx["combat"] as CombatBoardScreen
	var layer := PickupItemsTests._layer(fx)
	if not bool(plan["reduced"]) or PickupItemsTests._stage(fx).plan() != combat.get("_pickup_plan"):
		errors.append("the flag did not reach the plan, or the stage and the board built different plans")
	if float(plan["total"]) >= float(normal["total"]) or float(plan["walk_ease"]) != 0.0 or not (plan["pointer"]["path"] as Array).is_empty():
		errors.append("reduced plan: total %s (normal %s), walk_ease %s" % [plan["total"], normal["total"], plan["walk_ease"]])
	var look: Dictionary = plan["reduced_look"]
	if (plan["legs"] as Array).size() < 2:
		errors.append("the fixture should have an out leg and a walk leg")
	for leg: Dictionary in plan["legs"]:
		var want := float(look["step_len"]) if str(leg["kind"]) == "out" else float(look["leg_len"])
		if absf(float(leg["t1"]) - float(leg["t0"]) - want) > 1e-6:
			errors.append("a reduced %s leg does not take %s s" % [leg["kind"], want])
	var f := PickupItemsTests._taken_first(plan)
	var index := PickupItemsTests._index_of(snap, str(f["find_id"]))
	var finds := PickupFindsLayer.ground_finds(snap["data"])
	var t := 0.0
	var strip := PickupItemsTests._strip(fx)
	var seen_fade := false
	while t < float(plan["total"]):
		t = minf(t + 0.03, float(plan["total"]))
		PickupItemsTests._go(fx, t)
		(combat.get_node("%TokenLayer") as Node).call("_process", 0.03)
		for i in finds.size():
			var tile := layer.mark(i)
			if tile.visible and (absf(tile.scale.x - 1.0) > 1e-6 or absf(tile.scale.y - 1.0) > 1e-6 or (PickupItemsTests._centre(tile) - layer.mark_center(i)).length() > 0.01):
				errors.append("a card squashed, scaled or moved in reduced motion (at %.2f)" % t)
				break
		var entry: Dictionary = (combat.get_node("%TokenLayer") as Node).get("_presentation_state").call("get_entry", str(plan["chooser_id"]))
		var queue: Array = entry.get("path_queue", [])
		if not queue.is_empty() and (float(entry.get("seg_duration", 0.0)) * float(queue.size()) > float(look["leg_len"]) + 1e-6 or float(entry.get("walk_ease", 0.0)) != 0.0):
			errors.append("a reduced walk is longer than %s s or eased" % look["leg_len"])
		if t >= float(f["fly0"]) and t < float(f["fly1"]) and layer.mark(index).modulate.a < 1.0 and strip.view()["cells"] is Array:
			var slot := strip.slot_index_of_find(str(f["find_id"]))
			var cell: Dictionary = (strip.view()["cells"] as Array)[slot]
			seen_fade = seen_fade or (str(cell["kind"]) == "item" and float(cell.get("alpha", 1.0)) < 1.0)
	if not seen_fade:
		errors.append("the ground card and the strip slot did not cross-fade")
	return PickupBarkTests._done(fx, errors.slice(0, 3))


static func _t_reduced_skip_state() -> Dictionary:
	StopMarkMotion.reduced = false
	var snap := _real("empty", "0")
	var plan := PickupEventPlan.build(snap, { "reduced": true })
	var skip := PickupEventPlan.skip_to_idle(snap, { "reduced": true })
	var last := PickupEventPlan.frame_at(plan, float(plan["total"]))
	for k: String in ["echoes", "items", "phase"]:
		if JSON.stringify(skip[k]) != JSON.stringify(last[k]):
			return _fail("reduced: skip_to_idle differs from frame_at(total) in %s" % k)
	if JSON.stringify(skip["pack"]["slots"]) != JSON.stringify(last["pack"]["slots"]) or str(skip["pack"]["tone"]) != str(last["pack"]["tone"]):
		return _fail("reduced: the pack of skip_to_idle differs from the last frame")
	return { "ok": true }


static func _t_flag_off() -> Dictionary:
	StopMarkMotion.reduced = false
	var snap := _real("empty", "0")
	if StopMarkMotion.reduced or bool(PickupEventPlan.board_opts()["reduced"]):
		return _fail("the reduced-motion flag is on")
	var a := PickupEventPlan.build(snap, PickupEventPlan.board_opts())
	var b := PickupEventPlan.build(snap)
	var reduced := PickupEventPlan.build(snap, { "reduced": true })
	if a != b or bool(a["reduced"]) or float(a["total"]) <= float(reduced["total"]) or float(a["walk_ease"]) != float(snap["data"]["pointer_look"]["path"]["walk_ease"]):
		return _fail("with the flag off the plan is not the normal one (total %s, reduced %s)" % [a["total"], reduced["total"]])
	return { "ok": true }
