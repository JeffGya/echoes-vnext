# res://tests/PickupPackStripTests.gd
# V2-ITEM-001b step U4: the Travel pack strip of the pickup event. The strip mounts through the real RealmShell and
# the combat board, as PickupUiHostTests does. Snapshots are hand-built in the shape of PickupSnapshotBuilder `data.pack`.

class_name PickupPackStripTests
extends RefCounted

const RealmShellScene := preload("res://ui/shells/RealmShell.tscn")
const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const _NEW_FILES: Array = ["res://ui/screens/combat/PickupPackStrip.gd"]
const _BANNED_WORDS: Array = ["dispatch", "FlowContext", "Node.new", "StyleBoxFlat.new", "add_child"]
const _GAP := 24.0


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_ui/pack_strip_stack_shows_the_held_leaf", Callable(PickupPackStripTests, "_t_stack_leaf"))
	runner.register_test("pickup_ui/pack_strip_slot_count_equals_capacity", Callable(PickupPackStripTests, "_t_capacity"))
	runner.register_test("pickup_ui/pack_strip_tone_follows_the_snapshot", Callable(PickupPackStripTests, "_t_tone"))
	runner.register_test("pickup_ui/pack_strip_intro_shows_only_the_pre_event_pack", Callable(PickupPackStripTests, "_t_intro"))
	runner.register_test("pickup_ui/pack_strip_idle_shows_every_entry", Callable(PickupPackStripTests, "_t_idle"))
	runner.register_test("pickup_ui/pack_strip_allowance_tokens_read_the_snapshot", Callable(PickupPackStripTests, "_t_tokens"))
	runner.register_test("pickup_ui/pack_strip_sits_24_above_the_echo_bar_at_two_profiles", Callable(PickupPackStripTests, "_t_position"))
	runner.register_test("pickup_ui/pack_strip_repeat_snapshot_builds_nothing", Callable(PickupPackStripTests, "_t_repeat"))
	runner.register_test("pickup_ui/pack_strip_follows_a_swap_in_the_same_event", Callable(PickupPackStripTests, "_t_swap"))
	runner.register_test("pickup_ui/pack_strip_slot_centres_are_distinct_and_inside", Callable(PickupPackStripTests, "_t_centres"))
	runner.register_test("pickup_ui/pack_strip_unlisted_load_fills_slots", Callable(PickupPackStripTests, "_t_unlisted"))
	runner.register_test("pickup_ui/pack_strip_source_scan", Callable(PickupPackStripTests, "_t_source_scan"))


static func _slot(id: String, find_id: String = "", kind: String = "gear", source: String = "held") -> Dictionary:
	return { "id": id, "type_id": "ph_" + kind, "name": "Placeholder " + kind, "find_id": find_id, "kind": kind,
		"grade": "g1", "quantity": 1, "source": source, "mark_index": -1 }


static func _snap(phase: String, slots: Array, capacity: int = 4, tone: String = "plain", swap_left: int = 1,
		destroy_left: int = 1, carried: int = -1, run_count: int = 1, tone_before: String = "plain") -> Dictionary:
	return {
		"type": "flow.pickup", "meta": { "t": 1 },
		"data": { "phase": phase, "situation_id": "strip_test", "run_count": run_count, "encounter_id": "strip_test",
			"board_cols": 6, "board_rows": 5, "terrain": {}, "placement_seed": 0, "actors": [],
			"swap_left": swap_left, "destroy_left": destroy_left,
			"pack": { "slots": slots, "free": maxi(0, capacity - slots.size()), "capacity": capacity,
				"carried": slots.size() if carried < 0 else carried, "tone": tone, "tone_before": tone_before } },
		"actions": { "cta.continue": { "type": "pickup.continue", "slot": "cta.continue" } },
	}


static func _mount_at(first: Dictionary, size: Vector2i, profile: StringName) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if host == null:
		return {}
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var layer := CanvasLayer.new()
	layer.layer = 10
	vp.add_child(layer)
	var realm := RealmShellScene.instantiate() as RealmShell
	layer.add_child(realm)
	realm.set_layout({ "profile": profile, "safe_insets": Vector4.ZERO, "logical_size": Vector2(size) })
	realm.set_snapshot(first)
	var combat := realm.get("_active_overlay") as CombatBoardScreen
	if combat == null:
		vp.free()
		return {}
	return { "viewport": vp, "realm": realm, "combat": combat }


static func _mount(first: Dictionary) -> Dictionary:
	return _mount_at(first, Vector2i(1280, 720), &"standard")


static func _stage(fx: Dictionary) -> PickupEventStage:
	return (fx["combat"] as Node).get_node("%PickupEventStage") as PickupEventStage


static func _strip(fx: Dictionary) -> PickupPackStrip:
	return _stage(fx).pack_strip()


static func _fail(fx: Dictionary, error: String) -> Dictionary:
	if not fx.is_empty():
		PickupUiHostTests._free(fx)
	return { "ok": false, "error": error }


static func _done(fx: Dictionary, errors: Array) -> Dictionary:
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _visible_slots(strip: PickupPackStrip) -> Array:
	var out: Array = []
	for node in strip.get_node("%Slots").get_children():
		if (node as Control).visible:
			out.append(node)
	return out


static func _back_of(slot: Node) -> StringName:
	return (slot.get_node("Back") as Panel).theme_type_variation


static func _t_stack_leaf() -> Dictionary:
	var errors: Array = []
	var map: Dictionary = PickupPackStrip.SOURCE_TILE
	if str(map.get("stack", "")) != "held":
		errors.append("a held stack maps to leaf %s, want held (D-71)" % str(map.get("stack", "")))
	if str(map.get("gathered", "")) != "gathered" or str(map.get("held", "")) != "held":
		errors.append("held or gathered leaf map changed: %s" % str(map))
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_capacity() -> Dictionary:
	var errors: Array = []
	var fx := _mount(_snap("idle", [], 4))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	for cap in [4, 5, 2, 8]:
		(fx["realm"] as RealmShell).set_snapshot(_snap("idle", [], cap))
		var shown: int = _visible_slots(_strip(fx)).size()
		if shown != cap or _strip(fx).slot_count() != cap:
			errors.append("capacity %d shows %d slots (slot_count %d)" % [cap, shown, _strip(fx).slot_count()])
	return _done(fx, errors)


static func _t_tone() -> Dictionary:
	var errors: Array = []
	var fx := _mount(_snap("idle", []))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var want := { "plain": &"ItemPanelPack", "near": &"ItemPanelPackNear", "full": &"ItemPanelPackHeavy" }
	for tone: String in want.keys():
		(fx["realm"] as RealmShell).set_snapshot(_snap("idle", [_slot("a")], 4, tone))
		var got: StringName = (_strip(fx).get_node("%Panel") as PanelContainer).theme_type_variation
		if got != want[tone]:
			errors.append("tone %s gives %s, want %s" % [tone, got, want[tone]])
	return _done(fx, errors)


static func _t_intro() -> Dictionary:
	var errors: Array = []
	var slots: Array = [_slot("held1"), _slot("item:s:f0", "f0", "relic", "gathered"), _slot("held2", "", "consumable", "stack")]
	var fx := _mount(_snap("intro", slots, 4, "full", 1, 1, -1, 1, "near"))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var view: Dictionary = _strip(fx).view()
	var cells: Array = view["cells"]
	var kinds: Array = cells.map(func(c: Dictionary) -> String: return str(c["kind"]))
	if kinds != ["item", "item", "empty", "empty"]:
		errors.append("intro cells are %s" % str(kinds))
	for c: Dictionary in cells:
		if str((c["row"] as Dictionary).get("find_id", "")) != "":
			errors.append("intro shows a taken find")
	if str(view["tone"]) != "near":
		errors.append("intro tone %s: the strip must show pack.tone_before (near), not pack.tone (full) and not its own rule" % str(view["tone"]))
	return _done(fx, errors)


static func _t_idle() -> Dictionary:
	var errors: Array = []
	var slots: Array = [_slot("held1"), _slot("item:s:f0", "f0", "relic", "gathered"), _slot("held2", "", "consumable", "stack")]
	var fx := _mount(_snap("idle", slots, 4, "near"))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var cells: Array = _strip(fx).view()["cells"]
	var kinds: Array = cells.map(func(c: Dictionary) -> String: return str(c["kind"]))
	if kinds != ["item", "item", "item", "empty"]:
		errors.append("idle cells are %s" % str(kinds))
	var shown := 0
	for slot in _visible_slots(_strip(fx)):
		if _back_of(slot) == &"PickupSlotEmpty":
			continue
		shown += 1
	if shown != 3:
		errors.append("%d filled slots drawn, want 3" % shown)
	return _done(fx, errors)


static func _t_tokens() -> Dictionary:
	var errors: Array = []
	var fx := _mount(_snap("idle", [], 4, "plain", 1, 0))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var strip := _strip(fx)
	var swap := strip.get_node("%SwapToken") as PanelContainer
	var destroy := strip.get_node("%DestroyToken") as PanelContainer
	if (strip.get_node("%SwapCount") as Label).text != "1" or (strip.get_node("%DestroyCount") as Label).text != "0":
		errors.append("counts read %s and %s" % [(strip.get_node("%SwapCount") as Label).text, (strip.get_node("%DestroyCount") as Label).text])
	if swap.tooltip_text != PickupUiText.line("allow.swap_left") or destroy.tooltip_text != ItemUiText.PATH_USED:
		errors.append("lines '%s' / '%s'" % [swap.tooltip_text, destroy.tooltip_text])
	if swap.theme_type_variation != &"PickupAllowance" or destroy.theme_type_variation != &"PickupAllowanceSpent":
		errors.append("token styles %s / %s" % [swap.theme_type_variation, destroy.theme_type_variation])
	(fx["realm"] as RealmShell).set_snapshot(_snap("idle", [], 4, "plain", 0, 1))
	if swap.tooltip_text != PickupUiText.line("allow.swap_none") or destroy.tooltip_text != ItemUiText.PATH_LEFT:
		errors.append("after the swap: '%s' / '%s'" % [swap.tooltip_text, destroy.tooltip_text])
	if swap.theme_type_variation != &"PickupAllowanceSpent" or destroy.theme_type_variation != &"PickupAllowance":
		errors.append("styles after the swap %s / %s" % [swap.theme_type_variation, destroy.theme_type_variation])
	return _done(fx, errors)


static func _t_position() -> Dictionary:
	var errors: Array = []
	for profile_case: Array in [[Vector2i(1280, 720), &"standard"], [Vector2i(1920, 1080), &"wide"], [Vector2i(960, 540), &"compact"]]:
		var fx := _mount_at(_snap("idle", [_slot("a")], 4, "plain"), profile_case[0], profile_case[1])
		if fx.is_empty():
			return _fail(fx, "mount failed at %s" % str(profile_case[0]))
		(fx["combat"] as CombatBoardScreen).call("_place_pickup_strip")
		var frame := (fx["realm"] as Node).get_node("%EchoBarFrame") as Control
		var bar: Rect2 = frame.get_global_rect()
		var rect: Rect2 = _strip(fx).panel_global_rect()
		if absf(bar.size.y - 88.0) > 0.5:
			errors.append("%s: layout not settled, bar height %s" % [str(profile_case[0]), str(bar.size.y)])
		if absf((bar.position.y - rect.end.y) - _GAP) > 1.0:
			errors.append("%s: gap is %s, want %s" % [str(profile_case[0]), str(bar.position.y - rect.end.y), str(_GAP)])
		if rect.intersects(bar):
			errors.append("%s: the strip overlaps the EchoBar" % str(profile_case[0]))
		var debug := (fx["combat"] as Node).get_node("%PickupDebugContinue") as Control
		if debug != null and debug.visible and rect.intersects(debug.get_global_rect()):
			errors.append("%s: the strip overlaps the debug Continue" % str(profile_case[0]))
		var centre: float = rect.position.x + rect.size.x * 0.5
		if absf(centre - float((profile_case[0] as Vector2i).x) * 0.5) > 1.0:
			errors.append("%s: the strip is not centred (%s)" % [str(profile_case[0]), str(centre)])
		PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_repeat() -> Dictionary:
	var errors: Array = []
	var slots: Array = [_slot("held1"), _slot("held2", "", "relic")]
	var fx := _mount(_snap("idle", slots))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var strip := _strip(fx)
	var ids_before: Array = strip.find_children("*", "", true, false).map(func(n: Node) -> int: return n.get_instance_id())
	var renders: int = strip.render_count()
	(fx["realm"] as RealmShell).set_snapshot(_snap("idle", slots))
	_stage(fx).apply_snapshot(_snap("idle", slots))
	var ids_after: Array = strip.find_children("*", "", true, false).map(func(n: Node) -> int: return n.get_instance_id())
	if ids_before != ids_after:
		errors.append("the node set changed after a repeat snapshot")
	if strip.render_count() != renders:
		errors.append("a repeat snapshot rendered again (%d -> %d)" % [renders, strip.render_count()])
	return _done(fx, errors)


static func _t_swap() -> Dictionary:
	var errors: Array = []
	var before: Array = [_slot("h1"), _slot("h2", "", "relic"), _slot("h3", "", "charm"), _slot("h4", "", "consumable", "stack")]
	var after: Array = [_slot("h1"), _slot("h2", "", "relic"), _slot("h3", "", "charm"), _slot("item:s:f0", "f0", "gear", "gathered")]
	var fx := _mount(_snap("idle", before, 4, "full", 1))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var stage := _stage(fx)
	var strip := _strip(fx)
	var renders: int = strip.render_count()
	var starts: int = stage.start_count()
	(fx["realm"] as RealmShell).set_snapshot(_snap("idle", after, 4, "full", 0))
	if stage.start_count() != starts:
		errors.append("a swap restarted the event")
	if strip.render_count() != renders + 1:
		errors.append("the swap did not redraw the strip once")
	var cells: Array = strip.view()["cells"]
	if str((((cells[3] as Dictionary)["row"]) as Dictionary).get("find_id", "")) != "f0":
		errors.append("slot 4 does not show the swapped-in find")
	if (strip.get_node("%SwapCount") as Label).text != "0":
		errors.append("the swap token still shows a swap left")
	return _done(fx, errors)


static func _t_centres() -> Dictionary:
	var errors: Array = []
	var fx := _mount(_snap("idle", [_slot("a"), _slot("b", "", "relic")], 4))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var strip := _strip(fx)
	(fx["combat"] as CombatBoardScreen).call("_place_pickup_strip")
	var rect: Rect2 = strip.panel_global_rect()
	var seen: Array = []
	for i in strip.slot_count():
		var c: Vector2 = strip.slot_global_center(i)
		if not rect.has_point(c):
			errors.append("centre %d %s is outside the strip %s" % [i, str(c), str(rect)])
		if seen.has(c):
			errors.append("centre %d repeats" % i)
		seen.append(c)
	if strip.slot_count() != 4:
		errors.append("slot_count is %d" % strip.slot_count())
	return _done(fx, errors)


static func _t_unlisted() -> Dictionary:
	var errors: Array = []
	var fx := _mount(_snap("idle", [_slot("a")], 4, "near", 1, 1, 3))
	if fx.is_empty():
		return _fail(fx, "mount failed")
	var strip := _strip(fx)
	var kinds: Array = (strip.view()["cells"] as Array).map(func(c: Dictionary) -> String: return str(c["kind"]))
	if kinds != ["item", "unlisted", "unlisted", "empty"]:
		errors.append("cells are %s" % str(kinds))
	var slots: Array = _visible_slots(strip)
	if _back_of(slots[1] as Node) != &"ItemSlotPack" or _back_of(slots[3] as Node) != &"PickupSlotEmpty":
		errors.append("unlisted and empty slots look the same")
	return _done(fx, errors)


static func _t_source_scan() -> Dictionary:
	var errors: Array = []
	var literal := RegEx.new()
	literal.compile("\"(?:[^\"\\\\]|\\\\.)*\"")
	for path: String in _NEW_FILES:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("%s unreadable" % path)
		for word: String in _BANNED_WORDS:
			if text.contains(word):
				errors.append("%s contains %s" % [path, word])
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for m: RegExMatch in literal.search_all(line):
				if m.get_string().contains(" "):
					errors.append("%s has a string with a space (player text belongs in PickupUiText): %s" % [path, line.strip_edges()])
					break
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
