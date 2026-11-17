# res://tests/PickupFindsLayerTests.gd
# V2-ITEM-001b R3: the finds that lie on the board tiles during the pickup event (D-72 e). Real snapshots through the
# real builder; the layer lives in the real Combat board scene.

class_name PickupFindsLayerTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const _SCAN_FILES: Array = ["res://ui/screens/combat/PickupFindsLayer.gd"]
const _BANNED_WORDS: Array = ["Node.new", "add_child", "StyleBoxFlat.new", "Color(", "theme_type_variation", ".text ="]

static var _cache := {}


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/finds_only_left_tried_lost_with_a_tile_are_ground_finds", Callable(PickupFindsLayerTests, "_t_pure"))
	runner.register_test("pickup_ui/finds_one_mark_per_ground_find_on_its_tile", Callable(PickupFindsLayerTests, "_t_on_tile"))
	runner.register_test("pickup_ui/finds_taken_finds_get_no_mark", Callable(PickupFindsLayerTests, "_t_taken"))
	runner.register_test("pickup_ui/finds_frozen_finds_all_lie_on_the_ground", Callable(PickupFindsLayerTests, "_t_frozen"))
	runner.register_test("pickup_ui/finds_hidden_finds_use_the_empty_row_tile", Callable(PickupFindsLayerTests, "_t_hidden"))
	runner.register_test("pickup_ui/finds_repeat_snapshot_changes_nothing_and_a_swap_redraws", Callable(PickupFindsLayerTests, "_t_repeat"))
	runner.register_test("pickup_ui/finds_leave_clears_and_hides", Callable(PickupFindsLayerTests, "_t_leave"))
	runner.register_test("pickup_ui/finds_never_share_a_tile_with_a_token", Callable(PickupFindsLayerTests, "_t_no_token_tile"))
	runner.register_test("pickup_ui/finds_marks_ignore_the_mouse_and_draw_under_the_tokens", Callable(PickupFindsLayerTests, "_t_inert_and_order"))
	runner.register_test("pickup_ui/finds_art_lies_inside_the_usable_rect_after_framing", Callable(PickupFindsLayerTests, "_t_clearance"))
	runner.register_test("pickup_ui/finds_intro_draws_every_find_hidden_even_taken_ones", Callable(PickupFindsLayerTests, "_t_intro"))
	runner.register_test("pickup_ui/finds_idle_with_the_same_data_draws_only_non_taken_revealed", Callable(PickupFindsLayerTests, "_t_idle_same"))
	runner.register_test("pickup_ui/pack_strip_intro_holds_no_find_of_this_event", Callable(PickupFindsLayerTests, "_t_pack_strip_intro"))
	runner.register_test("pickup_ui/finds_intro_to_idle_flip_redraws_once_and_keeps_the_event", Callable(PickupFindsLayerTests, "_t_flip"))
	runner.register_test("pickup_ui/finds_camera_frames_the_same_find_tiles_in_intro_and_idle", Callable(PickupFindsLayerTests, "_t_frame_cells"))
	runner.register_test("pickup_ui/finds_seven_finds_draw_at_most_six_marks", Callable(PickupFindsLayerTests, "_t_cap"))
	runner.register_test("pickup_ui/finds_an_empty_tile_is_skipped_by_the_layer_and_the_camera", Callable(PickupFindsLayerTests, "_t_empty_tile"))
	runner.register_test("pickup_ui/finds_never_share_a_tile_or_a_centre_with_a_row_echo_in_many_scenes", Callable(PickupFindsLayerTests, "_t_many_apart"))
	runner.register_test("pickup_ui/finds_art_inside_usable_in_many_scenes_and_compact", Callable(PickupFindsLayerTests, "_t_clearance_many"))
	runner.register_test("pickup_ui/finds_source_scan", Callable(PickupFindsLayerTests, "_t_source_scan"))


static func _snap(kind: String, phase: String = "idle", variant: String = "", seed_text: String = "") -> Dictionary:
	var key := "%s/%s/%s/%s" % [kind, phase, variant, seed_text]
	if not _cache.has(key):
		_cache[key] = PickupRealBoard.snapshot(kind, phase, variant, seed_text)
	return (_cache[key] as Dictionary).duplicate(true)


## { fx, combat, layer } or { error } when the real fight did not reach the event.
static func _open(kind: String, phase: String = "idle", variant: String = "", seed_text: String = "") -> Dictionary:
	var snap := _snap(kind, phase, variant, seed_text)
	if snap.is_empty():
		return { "error": "the fixture fight did not reach the event" }
	var fx := PickupUiHostTests._mount(snap)
	if fx.is_empty():
		return { "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	return { "fx": fx, "combat": combat, "layer": combat.get_node("%PickupFindsLayer") as PickupFindsLayer, "snap": snap }


static func _done(o: Dictionary, errors: Array) -> Dictionary:
	if o.has("fx"):
		PickupUiHostTests._free(o["fx"])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _fail(o: Dictionary) -> Dictionary:
	return { "ok": false, "error": str(o["error"]) }


static func _tile_of(f: Dictionary) -> Vector2i:
	return Vector2i(int(f["tile"]["col"]), int(f["tile"]["row"]))


static func _t_pure() -> Dictionary:
	var tile := { "col": 1, "row": 1 }
	var data := { "phase": "idle", "finds": [
		{ "find_id": "a", "status": "taken", "tile": tile }, { "find_id": "b", "status": "left", "tile": tile },
		{ "find_id": "c", "status": "tried", "tile": tile }, { "find_id": "d", "status": "lost", "tile": tile },
		{ "find_id": "e", "status": "left" }] }
	var ids: Array = PickupFindsLayer.ground_finds(data).map(func(f: Dictionary) -> String: return str(f["find_id"]))
	var errors: Array = []
	if ids != ["b", "c", "d"]:
		errors.append("ground finds %s, expected [b, c, d]" % [ids])
	data["phase"] = "intro"
	ids = PickupFindsLayer.ground_finds(data).map(func(f: Dictionary) -> String: return str(f["find_id"]))
	if ids != ["a", "b", "c", "d"]:
		errors.append("intro finds %s, expected [a, b, c, d] (every find with a tile)" % [ids])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_on_tile() -> Dictionary:
	var o := _open("full")
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var ground := PickupFindsLayer.ground_finds(o["snap"]["data"])
	if ground.is_empty():
		errors.append("the full fixture has no ground find, the check proves nothing")
	if layer.mark_count() != ground.size() or not layer.visible:
		errors.append("%d marks, visible %s, expected %d" % [layer.mark_count(), layer.visible, ground.size()])
	for i in mini(layer.mark_count(), ground.size()):
		var want: Vector2 = combat._board.map_to_local(_tile_of(ground[i])) + Vector2(0.0, layer.visual_config.feet_offset_y)
		var tile := layer.mark(i)
		if not layer.mark_center(i).is_equal_approx(want):
			errors.append("mark %d centre %s, expected %s" % [i, layer.mark_center(i), want])
		if not (tile.position + tile.size * 0.5).is_equal_approx(want) or not tile.visible:
			errors.append("mark %d tile is not centred on its tile" % i)
		if str(tile.row.get("kind", "")) != str(ground[i]["kind"]):
			errors.append("mark %d shows kind %s, expected %s" % [i, tile.row.get("kind", ""), ground[i]["kind"]])
	return _done(o, errors)


static func _t_taken() -> Dictionary:
	var o := _open("empty")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var taken := 0
	for f: Dictionary in o["snap"]["data"]["finds"]:
		taken += 1 if str(f["status"]) == "taken" else 0
	if taken == 0:
		errors.append("the empty fixture has no taken find, the check proves nothing")
	if layer.mark_count() != 0 or layer.visible:
		errors.append("%d marks for taken finds, visible %s" % [layer.mark_count(), layer.visible])
	for i in layer.get_child_count():
		if (layer.get_child(i) as Control).visible:
			errors.append("mark %d is visible" % i)
	return _done(o, errors)


static func _t_frozen() -> Dictionary:
	var o := _open("empty", "idle", "frozen")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var n: int = (o["snap"]["data"]["finds"] as Array).size()
	if n == 0 or layer.mark_count() != n:
		errors.append("%d marks for %d lost finds" % [layer.mark_count(), n])
	return _done(o, errors)


static func _t_hidden() -> Dictionary:
	var o := _open("full", "intro")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var finds: Array = o["snap"]["data"]["finds"]
	if finds.is_empty() or bool(finds[0]["revealed"]):
		errors.append("the intro fixture has a revealed find, the check proves nothing")
	if layer.mark_count() != 1 or not (layer.mark(0) as Button).get("row").is_empty():
		errors.append("a hidden find did not use the empty row tile")
	elif not str(layer.mark(0).tooltip_text).is_empty():
		errors.append("a hidden find tooltip names the item: %s" % layer.mark(0).tooltip_text)
	elif "accessibility_name" in layer.mark(0) and not str(layer.mark(0).get("accessibility_name")).is_empty():
		errors.append("a hidden find accessibility name names the item: %s" % layer.mark(0).get("accessibility_name"))
	return _done(o, errors)


static func _t_repeat() -> Dictionary:
	var o := _open("full")
	if o.has("error"):
		return _fail(o)
	var realm := o["fx"]["realm"] as RealmShell
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var before := layer.render_count()
	realm.set_snapshot(_snap("full"))
	if layer.render_count() != before:
		errors.append("a repeat snapshot redrew the finds")
	var swapped := _snap("full")
	var extra: Dictionary = (swapped["data"]["finds"][0] as Dictionary).duplicate(true)
	extra["find_id"] = "swapped_out"
	extra["tile"] = { "col": 0, "row": 0 }
	(swapped["data"]["finds"] as Array).append(extra)
	realm.set_snapshot(swapped)
	if layer.mark_count() != 2 or layer.render_count() == before:
		errors.append("a swap snapshot with one more find drew %d marks" % layer.mark_count())
	return _done(o, errors)


static func _t_leave() -> Dictionary:
	var o := _open("full")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	if layer.mark_count() == 0:
		errors.append("no mark before leaving, the check proves nothing")
	(o["fx"]["realm"] as RealmShell).set_snapshot(PickupUiHostTests._encounter())
	if layer.visible or layer.mark_count() != 0 or (layer.mark(0) as Control).visible:
		errors.append("the layer still shows finds after the event")
	return _done(o, errors)


static func _t_no_token_tile() -> Dictionary:
	var errors: Array = []
	for spec: Array in [["empty", "idle", ""], ["near", "idle", ""], ["full", "idle", ""], ["empty", "idle", "frozen"]]:
		var snap := _snap(spec[0], spec[1], spec[2])
		if snap.is_empty():
			errors.append("%s did not reach the event" % [spec])
			continue
		var data: Dictionary = snap["data"]
		var row_tiles: Array = (data["row"] as Array).map(func(r: Dictionary) -> Vector2i: return _tile_of(r))
		if row_tiles.is_empty():
			errors.append("%s has no row tile" % [spec])
		for f: Dictionary in data["finds"]:
			if row_tiles.has(_tile_of(f)):
				errors.append("%s: find %s shares tile %s with an Echo token" % [spec, f["find_id"], _tile_of(f)])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_inert_and_order() -> Dictionary:
	var o := _open("full")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	for i in layer.get_child_count():
		var tile := layer.get_child(i) as Control
		if tile.mouse_filter != Control.MOUSE_FILTER_IGNORE or tile.focus_mode != Control.FOCUS_NONE:
			errors.append("mark %d takes the mouse or the focus" % i)
	if layer.get_child_count() != PickupFindsLayer.MAX_MARKS:
		errors.append("%d authored marks, expected %d" % [layer.get_child_count(), PickupFindsLayer.MAX_MARKS])
	var tokens: Node = (o["combat"] as CombatBoardScreen).get_node("%TokenLayer")
	if layer.get_index() >= tokens.get_index() or layer.get_parent() != tokens.get_parent():
		errors.append("the finds layer does not draw before the token layer")
	return _done(o, errors)


static func _t_clearance() -> Dictionary:
	return _clearance_of(_open("full"), "")


## Every art corner of every mark must land in the usable rect after the camera is framed and clamped.
static func _clearance_of(o: Dictionary, profile: String) -> Dictionary:
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	if profile == "compact":
		(o["fx"]["viewport"] as SubViewport).size = Vector2i(960, 540)
		(o["fx"]["realm"] as RealmShell).set_layout({ "profile": &"compact", "safe_insets": Vector4.ZERO, "logical_size": Vector2(960, 540) })
	combat.frame_pickup_camera(false)
	if layer.mark_count() == 0:
		errors.append("no mark, the check proves nothing")
	var usable := PickupCameraFrameTests._usable_of(combat)
	var half := layer.bed() * 0.5
	var shadow_bottom: float = layer.visual_config.shadow_offset.y + layer.visual_config.shadow_size.y * 0.5
	for i in layer.mark_count():
		var c := layer.mark_center(i)
		for corner: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, shadow_bottom), Vector2(half, shadow_bottom)]:
			var world: Vector2 = combat._board_root.position + c + corner
			var s := (world - combat.camera.get_screen_center_position()) * combat.camera.zoom.x + combat.get_viewport_rect().size * 0.5
			if not usable.has_point(s):
				errors.append("%s mark %d corner %s lands at %s, outside %s (zoom %s)" % [profile, i, corner, s, usable, combat.camera.zoom.x])
	return _done(o, errors)


static func _t_clearance_many() -> Dictionary:
	var errors: Array = []
	for spec: Array in [["many", "intro", "", ""], ["many", "idle", "", ""], ["many", "intro", "", "1"], ["many", "intro", "", "compact"]]:
		var compact: bool = spec[3] == "compact"
		var r := _clearance_of(_open(spec[0], spec[1], spec[2], "" if compact else spec[3]), "compact" if compact else "")
		if not bool(r["ok"]):
			errors.append("%s: %s" % [spec, r["error"]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_cap() -> Dictionary:
	var o := _open("full")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var data: Dictionary = (o["snap"]["data"] as Dictionary).duplicate(true)
	var finds: Array = []
	for i in 7:
		var f: Dictionary = (data["finds"][0] as Dictionary).duplicate(true)
		f["find_id"] = "f%d" % i
		f["tile"] = { "col": i, "row": 0 }
		f["status"] = "left"
		finds.append(f)
	data["finds"] = finds
	layer.show_finds(data, (o["combat"] as CombatBoardScreen)._board)
	var errors: Array = []
	if layer.mark_count() != PickupFindsLayer.MAX_MARKS or PickupFindsLayer.ground_finds(data).size() != PickupFindsLayer.MAX_MARKS:
		errors.append("%d marks for 7 finds, expected %d" % [layer.mark_count(), PickupFindsLayer.MAX_MARKS])
	return _done(o, errors)


static func _t_empty_tile() -> Dictionary:
	var data := { "phase": "intro", "finds": [{ "find_id": "a", "status": "left", "tile": {} }, { "find_id": "b", "status": "left", "tile": { "col": 1 } },
		{ "find_id": "c", "status": "left", "tile": { "col": 1, "row": 2 } }],
		"row": [{ "id": "x", "tile": {} }] }
	var errors: Array = []
	if PickupFindsLayer.ground_finds(data).size() != 1:
		errors.append("the layer drew %d finds, expected only the one with col and row" % PickupFindsLayer.ground_finds(data).size())
	var cells := CombatBoardScreen.pickup_frame_cells(data)
	if cells != [Vector2i(1, 2)]:
		errors.append("the camera framed %s, expected [(1, 2)]" % [cells])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## A find never shares a tile with a row Echo, and its mark centre never equals a token centre (real builder, real host).
static func _t_many_apart() -> Dictionary:
	var errors: Array = []
	for spec: Array in [["many", "intro", ""], ["many", "idle", ""], ["many", "intro", "1"], ["many", "idle", "1"]]:
		var o := _open(spec[0], spec[1], "", spec[2])
		if o.has("error"):
			errors.append("%s: %s" % [spec, o["error"]])
			continue
		var combat: CombatBoardScreen = o["combat"]
		var layer: PickupFindsLayer = o["layer"]
		var row: Array = o["snap"]["data"]["row"]
		if row.is_empty() or layer.mark_count() == 0:
			errors.append("%s: no row Echo or no mark, the check proves nothing" % [spec])
		var row_tiles: Array = row.map(func(r: Dictionary) -> Vector2i: return _tile_of(r))
		for i in layer.mark_count():
			if row_tiles.has(_tile_of(PickupFindsLayer.ground_finds(o["snap"]["data"])[i])):
				errors.append("%s: find %d shares a tile with an Echo" % [spec, i])
			for r: Dictionary in row:
				var token := combat._token_layer.display_cell_position(str(r["id"]))
				if token != Vector2.INF and token.is_equal_approx(layer.mark_center(i) - Vector2(0.0, layer.visual_config.feet_offset_y)):
					errors.append("%s: mark %d stands where token %s stands" % [spec, i, r["id"]])
		_done(o, [])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## The intro picture: every find on its tile in the empty-card look, the taken ones too.
static func _t_intro() -> Dictionary:
	var o := _open("empty", "intro")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	var finds: Array = o["snap"]["data"]["finds"]
	var taken := finds.filter(func(f: Dictionary) -> bool: return str(f["status"]) == "taken").size()
	if taken == 0:
		errors.append("the intro fixture has no taken find, the check proves nothing")
	if finds.is_empty() or layer.mark_count() != finds.size():
		errors.append("%d marks for %d finds" % [layer.mark_count(), finds.size()])
	for i in mini(layer.mark_count(), finds.size()):
		if not (layer.mark(i) as Button).get("row").is_empty():
			errors.append("mark %d is revealed in the intro" % i)
		var want: Vector2 = combat._board.map_to_local(_tile_of(finds[i])) + Vector2(0.0, layer.visual_config.feet_offset_y)
		if not layer.mark_center(i).is_equal_approx(want):
			errors.append("mark %d is not on its tile" % i)
	return _done(o, errors)


static func _t_idle_same() -> Dictionary:
	var o := _open("empty", "idle")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var finds: Array = o["snap"]["data"]["finds"]
	var intro_finds: Array = _snap("empty", "intro")["data"]["finds"]
	if intro_finds.size() != finds.size() or finds.is_empty():
		errors.append("intro and idle fixtures differ in the number of finds")
	var open := finds.filter(func(f: Dictionary) -> bool: return str(f["status"]) != "taken")
	if layer.mark_count() != open.size() or open.size() >= finds.size():
		errors.append("%d marks, expected %d of %d finds (some must be taken)" % [layer.mark_count(), open.size(), finds.size()])
	for i in layer.mark_count():
		if (layer.mark(i) as Button).get("row").is_empty():
			errors.append("mark %d is hidden in the idle phase" % i)
	return _done(o, errors)


static func _t_pack_strip_intro() -> Dictionary:
	var snap := _snap("empty", "intro")
	if snap.is_empty():
		return { "ok": false, "error": "the fixture fight did not reach the event" }
	var errors: Array = []
	var pack: Dictionary = snap["data"]["pack"]
	var from_event := (pack["slots"] as Array).filter(func(s: Dictionary) -> bool: return str(s.get("find_id", "")) != "")
	if from_event.is_empty():
		errors.append("the intro pack lists no find of this event, the check proves nothing")
	for cell: Dictionary in PickupPackStrip.view_of(snap)["cells"]:
		if cell["kind"] == "item" and str((cell["row"] as Dictionary).get("find_id", "")) != "":
			errors.append("the intro strip shows find %s" % cell["row"]["find_id"])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_flip() -> Dictionary:
	var o := _open("empty", "intro")
	if o.has("error"):
		return _fail(o)
	var realm := o["fx"]["realm"] as RealmShell
	var layer: PickupFindsLayer = o["layer"]
	var stage := PickupUiHostTests._stage(o["fx"])
	var errors: Array = []
	var identity := stage.identity()
	var before := layer.render_count()
	var idle := _snap("empty", "idle")
	realm.set_snapshot(idle)
	if layer.render_count() != before + 1:
		errors.append("the flip redrew %d times, expected 1" % (layer.render_count() - before))
	realm.set_snapshot(idle)
	if layer.render_count() != before + 1:
		errors.append("a repeat idle snapshot redrew the finds")
	if stage.identity() != identity or identity.is_empty():
		errors.append("the flip changed the event identity %s -> %s" % [identity, stage.identity()])
	return _done(o, errors)


static func _t_frame_cells() -> Dictionary:
	var errors: Array = []
	var a := CombatBoardScreen.pickup_frame_cells(_snap("empty", "intro")["data"])
	var b := CombatBoardScreen.pickup_frame_cells(_snap("empty", "idle")["data"])
	if a.is_empty() or a != b:
		errors.append("framed tiles differ: intro %s, idle %s" % [a, b])
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
