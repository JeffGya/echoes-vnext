# res://tests/PickupBarkTests.gd
# V2-ITEM-001b R4: the chooser's bark in the pickup event. It uses the existing BarkPopupLayer (the standard bubble), stays
# above the chooser's row token in the idle picture, and shows once per event. The intro shows none (U6 plays it).
# The board fixtures are the hand-built host snapshots; two tests use the real builder to compare with the planner text.

class_name PickupBarkTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const _CHOOSER := "a1"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/bark_persist_event_outlives_the_hold_time", Callable(PickupBarkTests, "_t_persist"))
	runner.register_test("pickup_ui/bark_plain_event_still_fades_after_the_hold_time", Callable(PickupBarkTests, "_t_plain_fades"))
	runner.register_test("pickup_ui/bark_idle_shows_one_popup_for_the_chooser_with_the_text_call_line", Callable(PickupBarkTests, "_t_idle"))
	runner.register_test("pickup_ui/bark_popup_sits_above_the_chooser_row_tile", Callable(PickupBarkTests, "_t_anchor"))
	runner.register_test("pickup_ui/bark_intro_shows_none", Callable(PickupBarkTests, "_t_intro"))
	runner.register_test("pickup_ui/bark_repeat_snapshot_keeps_the_same_popup", Callable(PickupBarkTests, "_t_repeat"))
	runner.register_test("pickup_ui/bark_intro_to_idle_flip_shows_it_once", Callable(PickupBarkTests, "_t_flip"))
	runner.register_test("pickup_ui/bark_leave_clears_it", Callable(PickupBarkTests, "_t_leave"))
	runner.register_test("pickup_ui/bark_new_event_clears_the_old_popup", Callable(PickupBarkTests, "_t_new_event"))
	runner.register_test("pickup_ui/bark_empty_text_shows_none_and_a_changed_text_replaces", Callable(PickupBarkTests, "_t_empty_and_changed"))
	runner.register_test("pickup_ui/bark_empty_encounter_id_keeps_the_popup_and_tokens", Callable(PickupBarkTests, "_t_empty_encounter_id"))
	runner.register_test("pickup_ui/bark_new_event_with_a_new_chooser_clears_the_old_popup", Callable(PickupBarkTests, "_t_new_chooser"))
	runner.register_test("pickup_ui/bark_follows_the_chooser_when_the_view_changes", Callable(PickupBarkTests, "_t_follow"))
	runner.register_test("pickup_ui/bark_line_depends_on_the_chooser_standing_band", Callable(PickupBarkTests, "_t_band"))
	runner.register_test("pickup_ui/bark_real_plan_anchors_above_the_chooser_end_tile_in_idle_and_none_in_intro", Callable(PickupBarkTests, "_t_real_end_tile"))
	runner.register_test("pickup_ui/bark_real_snapshots_use_the_planner_line", Callable(PickupBarkTests, "_t_real_text"))


## A host snapshot with a chooser (a1, second in the row) and a case that has a line.
static func _snap(phase: String = "idle", situation: String = "sit_a", case_key: String = "C1", reaction: String = "plus") -> Dictionary:
	var snap := PickupUiHostTests._pickup(situation, 1, phase)
	var data: Dictionary = snap["data"]
	data["case"] = case_key
	data["reaction"] = reaction
	data["reason"] = "identity"
	return snap


static func _layer(fx: Dictionary) -> BarkPopupLayer:
	return (fx["combat"] as Node).get_node("%BarkPopupLayer") as BarkPopupLayer


static func _popups(fx: Dictionary) -> Dictionary:
	return _layer(fx)._active_popups


static func _line(fx: Dictionary, actor_id: String) -> String:
	var entry: Dictionary = _popups(fx).get(actor_id, {})
	var node: Control = entry.get("node") as Control
	if node == null:
		return ""
	var label: Label = _layer(fx)._find_label(node)
	return label.text if label != null else ""


static func _expected(data: Dictionary) -> String:
	return PickupUiText.bark(str(data["case"]), str(data["reaction"]), str(data["reason"]), "low", 1)


## Steps the popup tween 1 s at a time until `seconds` are used. A finished tween is no longer valid and ends the loop earlier.
static func _advance(fx: Dictionary, actor_id: String, seconds: float) -> void:
	var entry: Dictionary = _popups(fx).get(actor_id, {})
	var tw: Tween = entry.get("tween") as Tween
	var left := seconds
	while tw != null and tw.is_valid() and left > 0.0:
		tw.custom_step(1.0)
		left -= 1.0


static func _done(fx: Dictionary, errors: Array) -> Dictionary:
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _event(actor_id: String, persist: bool) -> Dictionary:
	return { "actor_id": actor_id, "bark_line": "Test line.", "bark_context": "pickup", "bark_tier": "", "bark_target_id": "",
		"bark_priority": 1, "is_response": false, "persist": persist, "screen_pos": Vector2(100.0, 100.0) }


static func _mounted(first: Dictionary) -> Dictionary:
	return PickupUiHostTests._mount(first)


static func _t_persist() -> Dictionary:
	var fx := _mounted(PickupUiHostTests._encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var layer := _layer(fx)
	layer.show_barks([_event("p1", true)])
	_advance(fx, "p1", BarkPopupLayer.HOLD_DURATION + BarkPopupLayer.FADE_OUT_DURATION + 6.0)
	var errors: Array = []
	if not layer.has_popup("p1"):
		errors.append("a persist popup was gone after the hold time")
	elif (_popups(fx)["p1"]["node"] as Control).modulate.a < 0.99:
		errors.append("a persist popup is not fully shown after the fade-in")
	layer.clear_all()
	if layer.has_popup("p1"):
		errors.append("clear_all left a persist popup")
	return _done(fx, errors)


static func _t_plain_fades() -> Dictionary:
	var fx := _mounted(PickupUiHostTests._encounter())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var layer := _layer(fx)
	layer.show_barks([_event("n1", false)])
	var errors: Array = []
	if not layer.has_popup("n1"):
		errors.append("the plain popup did not appear")
	_advance(fx, "n1", BarkPopupLayer.HOLD_DURATION + BarkPopupLayer.FADE_OUT_DURATION + 6.0)
	if layer.has_popup("n1"):
		errors.append("a plain popup stayed after the hold time")
	return _done(fx, errors)


static func _t_idle() -> Dictionary:
	var snap := _snap()
	var fx := _mounted(snap)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var expected := _expected(snap["data"])
	var popups := _popups(fx)
	var errors: Array = []
	if expected.is_empty():
		errors.append("the fixture has no bark line")
	if popups.size() != 1 or not popups.has(_CHOOSER):
		errors.append("expected one popup for the chooser, got %s" % [popups.keys()])
	elif _line(fx, _CHOOSER) != expected:
		errors.append("popup text '%s', expected '%s'" % [_line(fx, _CHOOSER), expected])
	elif CombatBoardScreen.pickup_bark_text(snap["data"]) != expected:
		errors.append("pickup_bark_text differs from the PickupUiText line")
	return _done(fx, errors)


static func _t_anchor() -> Dictionary:
	var snap := _snap()
	var fx := _mounted(snap)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	var row_actor: Dictionary = {}
	for actor: Dictionary in CombatBoardScreen.pickup_row_actors(snap["data"]):
		if str(actor["id"]) == _CHOOSER:
			row_actor = actor
	var fight_actor: Dictionary = {}
	for actor: Dictionary in snap["data"]["actors"]:
		if str(actor["id"]) == _CHOOSER:
			fight_actor = actor
	if row_actor.is_empty() or not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no chooser actor or popup"])
	var popup := _popups(fx)[_CHOOSER]["node"] as Control
	var sz: Vector2 = popup.size if popup.size != Vector2.ZERO else popup.get_combined_minimum_size()
	var at: Vector2 = combat._actor_screen_pos(row_actor) + BarkPopupLayer.ORIGINAL_OFFSET - sz * 0.5
	if popup.position.distance_to(at) > 0.5:
		errors.append("popup at %s, expected %s (above the row tile)" % [popup.position, at])
	var fight_at: Vector2 = combat._actor_screen_pos(fight_actor) + BarkPopupLayer.ORIGINAL_OFFSET - sz * 0.5
	if popup.position.distance_to(fight_at) <= 0.5:
		errors.append("popup sits above the fight cell, not the row tile")
	if combat._last_actors.is_empty():
		errors.append("_last_actors is empty, so _process would not follow the camera")
	return _done(fx, errors)


static func _t_intro() -> Dictionary:
	var fx := _mounted(_snap("intro"))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var errors: Array = []
	if not _popups(fx).is_empty():
		errors.append("the intro showed %d popups" % _popups(fx).size())
	return _done(fx, errors)


static func _t_repeat() -> Dictionary:
	var fx := _mounted(_snap())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no popup after the first idle snapshot"])
	var first: Control = _popups(fx)[_CHOOSER]["node"]
	realm.set_snapshot(_snap())
	realm.set_snapshot(_snap())
	if _popups(fx).size() != 1:
		errors.append("a repeat snapshot gave %d popups" % _popups(fx).size())
	elif _popups(fx)[_CHOOSER]["node"] != first:
		errors.append("a repeat snapshot restarted the popup")
	return _done(fx, errors)


static func _t_flip() -> Dictionary:
	var fx := _mounted(_snap("intro"))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if not _popups(fx).is_empty():
		errors.append("popup in the intro")
	realm.set_snapshot(_snap("idle"))
	if _popups(fx).size() != 1 or not _popups(fx).has(_CHOOSER):
		errors.append("the flip gave %s popups, expected one for the chooser" % [_popups(fx).keys()])
	return _done(fx, errors)


static func _t_leave() -> Dictionary:
	var fx := _mounted(_snap())
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if _popups(fx).is_empty():
		errors.append("no popup before leaving")
	realm.set_snapshot(PickupUiHostTests._encounter())
	if not _popups(fx).is_empty():
		errors.append("leaving left %d popups" % _popups(fx).size())
	if (fx["combat"] as CombatBoardScreen)._pickup_bark_key != "":
		errors.append("leaving kept the bark key")
	return _done(fx, errors)


static func _t_new_event() -> Dictionary:
	var fx := _mounted(_snap("idle", "sit_a"))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no popup in the first event"])
	var old: Control = _popups(fx)[_CHOOSER]["node"]
	realm.set_snapshot(_snap("idle", "sit_b"))
	if _popups(fx).size() != 1 or _popups(fx)[_CHOOSER]["node"] == old:
		errors.append("a new event with the same line did not give one fresh popup")
	realm.set_snapshot(_snap("intro", "sit_c"))
	if not _popups(fx).is_empty():
		errors.append("a new event in the intro kept the old popup")
	return _done(fx, errors)


static func _t_empty_and_changed() -> Dictionary:
	var fx := _mounted(_snap("idle", "sit_a", ""))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	var errors: Array = []
	if not _popups(fx).is_empty():
		errors.append("empty text still showed a popup")
	realm.set_snapshot(_snap("idle", "sit_a", "C1"))
	var one := _line(fx, _CHOOSER)
	realm.set_snapshot(_snap("idle", "sit_a", "C5", "none"))
	var two := _line(fx, _CHOOSER)
	if one.is_empty() or two.is_empty() or one == two or _popups(fx).size() != 1:
		errors.append("a text change in the same event gave '%s' then '%s' (%d popups)" % [one, two, _popups(fx).size()])
	realm.set_snapshot(_snap("idle", "sit_a", ""))
	if not _popups(fx).is_empty():
		errors.append("text that became empty left a popup")
	return _done(fx, errors)


## The production path: a real snapshot with a valid plan. In idle the bark sits above the chooser's END tile, not its row tile;
## the intro shows none. The reference is the same snapshot with no `pointer_look` (no plan: the chooser stays on its row tile): the
## popup must move by exactly the screen distance between the two tiles.
static func _t_real_end_tile() -> Dictionary:
	var snap := PickupRealBoard.snapshot("many", "idle", "plus")
	var intro := PickupRealBoard.snapshot("many", "intro")
	if snap.is_empty() or intro.is_empty():
		return { "ok": false, "error": "the fixture fight did not reach the event" }
	var plan := PickupEventPlan.build(snap)
	var chooser := str(plan["chooser_id"])
	var no_plan := snap.duplicate(true)
	(no_plan["data"] as Dictionary).erase("pointer_look")
	var fx_row := _mounted(no_plan)
	var row_pos := Vector2.INF
	if _popups(fx_row).has(chooser):
		row_pos = (_popups(fx_row)[chooser]["node"] as Control).position
	_free_fx(fx_row)
	var fx := _mounted(snap)
	var combat := fx["combat"] as CombatBoardScreen
	var errors: Array = []
	if not _popups(fx).has(chooser) or row_pos == Vector2.INF:
		return _done(fx, ["no bark popup for the chooser (plan %s, no plan %s)" % [_popups(fx).has(chooser), row_pos != Vector2.INF]])
	var actors := CombatBoardScreen.pickup_row_actors(snap["data"])
	var at_end := CombatBoardScreen.pickup_actors_at(actors, chooser, { "cell": plan["chooser_end_cell"] })
	var end_screen := Vector2.ZERO
	var row_screen := Vector2.ZERO
	for a: Dictionary in at_end:
		if str(a["id"]) == chooser:
			end_screen = combat._actor_screen_pos(a)
	for a: Dictionary in actors:
		if str(a["id"]) == chooser:
			row_screen = combat._actor_screen_pos(a)
	var popup := _popups(fx)[chooser]["node"] as Control
	if end_screen.distance_to(row_screen) < 1.0:
		errors.append("the fixture's end tile is on the row tile: the test proves nothing")
	# The popup is clamped or sized by the bark layer, so the shift matches within a few pixels (the tiles are about 245 px apart).
	if ((popup.position - row_pos) - (end_screen - row_screen)).length() > 15.0:
		errors.append("the popup moved by %s, the end tile is %s from the row tile" % [popup.position - row_pos, end_screen - row_screen])
	_free_fx(fx)
	var fx2 := _mounted(intro)
	if not _popups(fx2).is_empty():
		errors.append("the intro shows a bark")
	return _done(fx2, errors)


static func _free_fx(fx: Dictionary) -> void:
	PickupUiHostTests._free(fx)


static func _t_real_text() -> Dictionary:
	var errors: Array = []
	for variant: String in ["plus", "none", "frozen"]:
		var snap := PickupRealBoard.snapshot("many", "idle", variant)
		if snap.is_empty():
			return { "ok": false, "error": "the fixture fight did not reach the event" }
		var planned: String = str((PickupEventPlan.build(snap)["bark"] as Dictionary)["text"])
		var fx := _mounted(snap)
		if fx.is_empty():
			return { "ok": false, "error": "mount failed" }
		var chooser := CombatBoardScreen.pickup_chooser_id(snap["data"])
		var shown := _line(fx, chooser)
		if planned.is_empty() or shown != planned:
			errors.append("%s: popup '%s', planner '%s'" % [variant, shown, planned])
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## A reload can publish no encounter id. The board must not read that as a new fight on every snapshot.
static func _t_empty_encounter_id() -> Dictionary:
	var first := _snap()
	(first["data"] as Dictionary)["encounter_id"] = ""
	var fx := _mounted(first)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	if not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no popup after the first snapshot"])
	var node: Control = _popups(fx)[_CHOOSER]["node"]
	var errors: Array = []
	for i in 2:
		var again := _snap()
		(again["data"] as Dictionary)["encounter_id"] = ""
		realm.set_snapshot(again)
	if not _popups(fx).has(_CHOOSER) or _popups(fx)[_CHOOSER]["node"] != node:
		errors.append("an empty encounter id restarted or killed the popup on a repeat snapshot")
	return _done(fx, errors)


## The new event must clear the old chooser's popup even while that Echo is still in the row.
static func _t_new_chooser() -> Dictionary:
	var fx := _mounted(_snap("idle", "sit_a"))
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var realm := fx["realm"] as RealmShell
	if not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no popup in the first event"])
	var next := _snap("idle", "sit_b")
	for entry: Dictionary in next["data"]["row"]:
		entry["is_chooser"] = str(entry["id"]) != _CHOOSER
	realm.set_snapshot(next)
	var errors: Array = []
	if _popups(fx).has(_CHOOSER):
		errors.append("the old chooser kept its popup in the new event")
	if _popups(fx).size() != 1 or not _popups(fx).has("a2"):
		errors.append("expected one popup for the new chooser, got %s" % [_popups(fx).keys()])
	return _done(fx, errors)


## A view change moves the screen anchor of the token. The host `_process` re-anchors the bubble from the canvas transform.
## A headless test cannot move the Camera2D transform (it applies at frame time), so the test moves the board and calls the
## host's own re-anchor path (`_update_bark_positions(_last_actors)`, the call `_process` makes).
static func _t_follow() -> Dictionary:
	var snap := _snap()
	var fx := _mounted(snap)
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	if not _popups(fx).has(_CHOOSER):
		return _done(fx, ["no popup"])
	var popup := _popups(fx)[_CHOOSER]["node"] as Control
	var before := popup.position
	(combat.get_node("%Board") as TileMapLayer).position += Vector2(60.0, 40.0)
	combat._update_bark_positions(combat._last_actors)
	var row_actor: Dictionary = {}
	for actor: Dictionary in CombatBoardScreen.pickup_row_actors(snap["data"]):
		if str(actor["id"]) == _CHOOSER:
			row_actor = actor
	var sz: Vector2 = popup.size if popup.size != Vector2.ZERO else popup.get_combined_minimum_size()
	var at: Vector2 = combat._actor_screen_pos(row_actor) + BarkPopupLayer.ORIGINAL_OFFSET - sz * 0.5
	var errors: Array = []
	if popup.position.distance_to(before) < 1.0:
		errors.append("the bubble did not move with the board")
	if popup.position.distance_to(at) > 0.5:
		errors.append("the bubble is at %s, expected %s" % [popup.position, at])
	return _done(fx, errors)


## Case C2 uses the standing band (low, mid, high). Two standings in two bands must give two lines.
static func _t_band() -> Dictionary:
	var lines: Array = []
	for standing: int in [1, 9]:
		var snap := _snap("idle", "sit_a", "C2", "plus")
		for entry: Dictionary in snap["data"]["row"]:
			entry["standing"] = standing
		var fx := _mounted(snap)
		if fx.is_empty():
			return { "ok": false, "error": "mount failed" }
		lines.append(_line(fx, _CHOOSER))
		PickupUiHostTests._free(fx)
	var errors: Array = []
	if str(lines[0]).is_empty() or str(lines[1]).is_empty() or lines[0] == lines[1]:
		errors.append("standing 1 and 9 gave '%s' and '%s'" % [lines[0], lines[1]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
