# res://tests/PickupInputTests.gd
# V2-ITEM-001b U7: input on the pickup event. A tap or a key chooses a find or a pack tile, the details card opens, the camera keeps
# the finds apart, the allowance tokens show their line. Real snapshots through the real builder (PickupRealBoard); real mouse events
# pushed through the viewport. The pure rules are tested without a node.

class_name PickupInputTests
extends RefCounted

const PickupRealBoard := preload("res://tests/fixtures/PickupRealBoard.gd")
const ItemUiText := preload("res://ui/components/ItemUiText.gd")
const ItemMovePlan := preload("res://ui/components/ItemMovePlan.gd")
const InventoryPanelsScene := preload("res://ui/components/InventoryPanels.tscn")
const _SUITE := "pickup_ui"
const _NEW_FILES: Array = [
	"res://ui/screens/combat/PickupHitRules.gd", "res://ui/screens/combat/PickupDetailsCard.gd",
	"res://ui/components/ItemDetailsBlock.gd", "res://ui/screens/combat/PickupDetailsPlan.gd", "res://ui/screens/combat/PickupPackStrip.gd", "res://ui/screens/combat/PickupEventStage.gd",
]
const _BANNED_WORDS: Array = ["dispatch", "FlowContext", "Node.new", "StyleBoxFlat.new", "add_child", "Color(", ".new("]

static var _cache := {}


static func register(runner: CoreTestRunner) -> void:
	var t := func(name: String, fn: String) -> void:
		runner.register_test("%s/input_%s" % [_SUITE, name], Callable(PickupInputTests, fn))
	t.call("select_rule_allows_idle_ground_finds_and_pack_only", "_t_can_select")
	t.call("hit_test_takes_the_later_find_and_the_edge", "_t_hit")
	t.call("min_zoom_keeps_a_48_target_and_an_8_gap", "_t_min_zoom")
	t.call("plan_takes_the_first_side_without_coverage_in_the_order_of_the_item", "_t_plan_order")
	t.call("plan_find_near_the_right_edge_picks_left_and_near_the_left_edge_picks_right", "_t_plan_edges")
	t.call("plan_with_a_token_on_each_side_picks_the_least_covered_side", "_t_plan_least")
	t.call("plan_never_covers_its_anchor_and_stays_in_the_usable_rect", "_t_plan_anchor")
	t.call("plan_fully_blocked_picks_least_coverage_and_a_bark_weighs_half", "_t_plan_blocked")
	t.call("plan_pack_tile_uses_left_only_as_first_and_right_only_as_last", "_t_plan_pack_ends")
	t.call("plan_keeps_its_side_until_a_free_side_exists_or_it_no_longer_fits", "_t_plan_sticky")
	t.call("card_arrow_points_out_of_all_four_sides", "_t_arrow_sides")
	t.call("first_pack_slot_of_the_select_pack_fixture_picks_left_with_no_coverage", "_t_plan_first_slot")
	t.call("every_pack_slot_card_sits_close_to_its_tile_and_covers_no_slot", "_t_plan_pack_slots")
	t.call("pack_card_obstacles_leave_out_actors_finds_and_the_strip", "_t_pack_obstacles")
	t.call("find_card_still_avoids_the_actors_and_picks_its_least_covered_side", "_t_find_avoids")
	t.call("planner_uses_the_obstacles_of_the_real_snapshot_and_layers", "_t_plan_real_obstacles")
	t.call("hit_target_covers_the_drawn_find_at_zoom_2", "_t_hit_zoom")
	t.call("forward_tab_from_the_last_target_wraps_to_the_first_find", "_t_tab_wrap")
	t.call("a_hidden_board_or_a_resolve_card_closes_the_card_and_keeps_esc", "_t_hidden")
	t.call("a_real_click_on_a_pack_tile_selects_and_leaves_no_focus_ring", "_t_click_tile")
	t.call("a_real_esc_closes_the_card", "_t_real_esc")
	t.call("an_empty_slot_sends_nothing_unless_a_card_is_open", "_t_empty_slot")
	t.call("the_card_reads_x1_of_n_for_a_stack_find_and_a_stack_in_the_pack", "_t_stack_line")
	t.call("pack_card_may_cover_the_bark_and_a_find_card_may_not", "_t_bark_obstacle")
	t.call("usable_rect_keeps_the_16_unit_safe_zone", "_t_usable")
	t.call("a_joypad_dpad_right_or_down_enters_the_first_find_like_tab", "_t_pad")
	t.call("the_card_returns_the_focus_to_what_opened_the_current_card", "_t_opener")
	t.call("a_changed_finds_list_moves_or_drops_the_keyboard_focus", "_t_focus_list")
	t.call("keys_stay_with_a_control_outside_the_pickup_event", "_t_foreign_focus")
	t.call("the_camera_fit_wins_over_the_floor_when_the_box_does_not_fit", "_t_fit_wins")
	t.call("camera_frame_probe_spacing_1", "_t_frame_probe")
	t.call("selection_reads_the_find_and_the_pack_row", "_t_selection")
	t.call("hit_a_real_mouse_event_reaches_the_board_tap_and_no_world_button", "_t_real_mouse")
	t.call("tap_on_a_find_selects_and_a_second_tap_closes", "_t_tap_toggle")
	t.call("nothing_opens_in_the_intro", "_t_intro_inert")
	t.call("tap_on_open_board_closes_the_card_and_never_releases_the_camera", "_t_tap_empty")
	t.call("card_shows_the_shared_block_above_the_bark", "_t_card")
	t.call("card_closes_when_its_item_leaves_the_screen", "_t_card_offscreen")
	t.call("close_button_is_outline_48_high_and_esc_closes", "_t_close")
	t.call("pack_tile_chooses_in_idle_only", "_t_pack_choose")
	t.call("selected_find_and_focused_find_share_the_cream_ring", "_t_rings")
	t.call("pack_tile_ring_and_focus_use_the_cream_look", "_t_pack_ring")
	t.call("keyboard_focus_enters_after_a_key_and_tab_walks_the_order", "_t_tab")
	t.call("accept_on_a_focused_find_chooses_it_and_close_returns_the_focus", "_t_accept")
	t.call("allowance_tokens_open_the_cause_tooltip", "_t_tokens")
	t.call("cursor_is_a_pointing_hand_over_a_selectable_find_in_idle_only", "_t_cursor")
	t.call("camera_floor_follows_the_finds_and_leave_restores_it", "_t_floor")
	t.call("card_arrow_is_the_only_new_variation_and_reuses_theme_colours", "_t_theme")
	t.call("strip_box_separation_is_8", "_t_separation")
	t.call("source_scan", "_t_scan")
	runner.register_test("inventory_ui/item_tile_setup_without_the_new_ring_option_is_unchanged", Callable(PickupInputTests, "_t_tile_no_ring"))
	runner.register_test("inventory_ui/details_block_is_one_component_for_the_panels_and_the_pickup_card", Callable(PickupInputTests, "_t_one_block"))


# ── Helpers ─────────────────────────────────────────────────────────────────

static func _snap(kind: String, phase: String = "idle", variant: String = "none") -> Dictionary:
	var key := "%s/%s/%s" % [kind, phase, variant]
	if not _cache.has(key):
		_cache[key] = PickupRealBoard.snapshot(kind, phase, variant, "")
	return (_cache[key] as Dictionary).duplicate(true)


## { fx, combat, layer, strip, stage, snap, sent } or { error }. The camera is framed at once; `sent` collects the actions the board emits.
static func _open(kind: String = "many", phase: String = "idle", variant: String = "none") -> Dictionary:
	var snap := _snap(kind, phase, variant)
	if snap.is_empty():
		return { "error": "the fixture fight did not reach the event" }
	var fx := PickupUiHostTests._mount(snap)
	if fx.is_empty():
		return { "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	combat.frame_pickup_camera(false)
	var sent: Array = []
	combat.action_requested.connect(func(a: Dictionary) -> void: sent.append(a))
	return { "fx": fx, "combat": combat, "layer": combat.get_node("%PickupFindsLayer") as PickupFindsLayer,
		"stage": combat.get_node("%PickupEventStage") as PickupEventStage, "snap": snap, "sent": sent,
		"vp": fx["viewport"] as SubViewport }


static func _stripof(o: Dictionary) -> PickupPackStrip:
	return (o["stage"] as PickupEventStage).pack_strip()


static func _done(o: Dictionary, errors: Array) -> Dictionary:
	if o.has("fx"):
		PickupUiHostTests._free(o["fx"])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _fail(o: Dictionary) -> Dictionary:
	return { "ok": false, "error": str(o["error"]) }


## The same snapshot with `data.selected` set the way the builder writes it.
static func _select(o: Dictionary, side: String, id: String) -> void:
	var snap: Dictionary = (o["snap"] as Dictionary).duplicate(true)
	(snap["data"] as Dictionary)["selected"] = { "id": id, "side": side } if not id.is_empty() else {}
	o["snap"] = snap
	((o["fx"] as Dictionary)["realm"] as RealmShell).set_snapshot(snap)


static func _first_find_id(o: Dictionary) -> String:
	return (o["layer"] as PickupFindsLayer).find_id_at(0)


static func _click(o: Dictionary, point: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = point
		ev.global_position = point
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.pressed = pressed
		(o["vp"] as SubViewport).push_input(ev, true)


static func _key(o: Dictionary, code: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.shift_pressed = shift
	ev.pressed = true
	(o["vp"] as SubViewport).push_input(ev, false)


## A key press and its release: a Button acts on the release.
static func _tap_key(o: Dictionary, code: Key) -> void:
	_key(o, code)
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = false
	(o["vp"] as SubViewport).push_input(ev, false)


static func _selects(sent: Array) -> Array:
	return sent.filter(func(a: Dictionary) -> bool: return str(a.get("type", "")) == "pickup.select")


# ── Pure rules ──────────────────────────────────────────────────────────────

static func _t_can_select() -> Dictionary:
	var errors: Array = []
	for status in ["left", "tried", "lost"]:
		if not PickupHitRules.can_select("idle", "find", status):
			errors.append("a %s find must be selectable in idle" % status)
	if PickupHitRules.can_select("idle", "find", "taken"):
		errors.append("a taken find has no mark and is not selectable")
	for phase in ["intro", "swap_pick", "swap_preview", ""]:
		if PickupHitRules.can_select(phase, "find", "left") or PickupHitRules.can_select(phase, "pack", ""):
			errors.append("nothing is selectable in phase '%s'" % phase)
	if not PickupHitRules.can_select("idle", "pack", ""):
		errors.append("a pack tile is selectable in idle")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_hit() -> Dictionary:
	var errors: Array = []
	var centers: Array = [Vector2(100, 100), Vector2(120, 100)]
	if PickupHitRules.hit(Vector2(110, 100), centers) != 1:
		errors.append("a pile gives the tap to the later (drawn on top) find")
	if PickupHitRules.hit(Vector2(100, 100) + Vector2(24, 0), [Vector2(100, 100)]) != 0:
		errors.append("the edge of the 48 target hits")
	if PickupHitRules.hit(Vector2(100, 100) + Vector2(24.5, 0), [Vector2(100, 100)]) != -1:
		errors.append("a point outside the target hits")
	if PickupHitRules.hit(Vector2.ZERO, []) != -1:
		errors.append("no centres gives -1")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_min_zoom() -> Dictionary:
	var errors: Array = []
	# Two finds 2 tiles apart on the nearest diagonal of a 128 x 64 board: (64, 96) tile steps x 1 = 115.4 px.
	var near := Vector2(64.0, 96.0).length()
	var z := PickupHitRules.min_zoom([Vector2.ZERO, Vector2(64, 96), Vector2(500, 500)])
	if absf(z - 56.0 / near) > 0.0001 or z < 0.48 or z > 0.49:
		errors.append("floor %f, wanted 56 / %f (about 0.485)" % [z, near])
	if near * z < PickupHitRules.TARGET + PickupHitRules.GAP - 0.001:
		errors.append("at the floor two finds are closer than 48 + 8")
	if PickupHitRules.min_zoom([Vector2.ZERO]) != 0.0 or PickupHitRules.min_zoom([]) != 0.0:
		errors.append("fewer than two finds need no floor")
	if PickupHitRules.min_zoom([Vector2.ZERO, Vector2.ZERO]) != 0.0:
		errors.append("two finds on one point give no floor (a divide by zero)")
	var pile := PickupHitRules.min_zoom([Vector2.ZERO, Vector2.ZERO, Vector2(100, 0)])
	if absf(pile - 0.56) > 0.0001:
		errors.append("a pile plus a third find: %f, wanted 56 / 100 (the pile is one target)" % pile)
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_selection() -> Dictionary:
	var data := { "selected": { "id": "f1", "side": "find" }, "finds": [{ "find_id": "f0", "status": "left" }, { "find_id": "f1", "status": "tried" }],
		"pack": { "slots": [{ "id": "p1", "name": "x" }] } }
	var errors: Array = []
	var a := PickupHitRules.selection(data)
	if str(a.get("id", "")) != "f1" or str(a.get("status", "")) != "tried" or str(a.get("side", "")) != "find":
		errors.append("find selection %s" % [a])
	data["selected"] = { "id": "p1", "side": "pack" }
	var b := PickupHitRules.selection(data)
	if str(b.get("id", "")) != "p1" or str((b["row"] as Dictionary).get("name", "")) != "x":
		errors.append("pack selection %s" % [b])
	data["selected"] = { "id": "gone", "side": "pack" }
	if not PickupHitRules.selection(data).is_empty() or not PickupHitRules.selection({}).is_empty():
		errors.append("an id with no row, or no selection, gives {}")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


# ── Card placement (PickupDetailsPlan) ──────────────────────────────────────

const _SCREEN := Rect2(8, 8, 1264, 600)
const _CARD := Vector2(320, 200)


## `at` is "first", "last" or "middle" for a pack tile; a find is both first and last. `prev` is the side the card had.
static func _plan(anchor: Rect2, obstacles: Array = [], kind: String = "find", at: String = "middle", prev: String = "") -> Dictionary:
	return PickupDetailsPlan.plan(anchor, _CARD, _SCREEN, obstacles, kind, 12.0, 24.0, kind != "pack" or at == "first", kind != "pack" or at == "last", prev)


static func _ob(r: Rect2, w: float = 1.0) -> Dictionary:
	return PickupDetailsPlan.obstacle(r, w)


static func _t_plan_order() -> Dictionary:
	var errors: Array = []
	var a := Rect2(600, 300, 48, 48)
	if str(_plan(a)["side"]) != "left":
		errors.append("a find with nothing round it takes left, got %s" % _plan(a)["side"])
	var strip := Rect2(480, 480, 340, 130)
	var tile := Rect2(488, 540, 48, 48)
	if str(_plan(tile, [], "pack", "first")["side"]) != "left":
		errors.append("the first pack tile takes left, got %s" % _plan(tile, [], "pack", "first")["side"])
	# Tie order: block left, then right, then above in turn; every other side stays free.
	var card_left := Rect2((_plan(a)["position"] as Vector2), Vector2(40, _CARD.y))
	var f1 := _plan(a, [_ob(card_left)])
	if str(f1["side"]) != "right":
		errors.append("find, left blocked: %s, wanted right" % f1["side"])
	var f2 := _plan(a, [_ob(card_left), _ob(Rect2(a.end.x + 22, 330, 100, 40))])
	if str(f2["side"]) != "above":
		errors.append("find, left and right blocked: %s, wanted above" % f2["side"])
	var p1 := _plan(tile, [_ob(Rect2(tile.position.x - 12 - _CARD.x - 10, 300, _CARD.x + 40, 400))], "pack", "first")
	if str(p1["side"]) != "above":
		errors.append("pack tile, left blocked: %s, wanted above (before right)" % p1["side"])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_plan_edges() -> Dictionary:
	var errors: Array = []
	var right := _plan(Rect2(1200, 300, 48, 48))
	if str(right["side"]) != "left":
		errors.append("a find near the right edge picks %s, wanted left" % right["side"])
	var left := _plan(Rect2(20, 300, 48, 48))
	if str(left["side"]) != "right":
		errors.append("a find near the left edge picks %s, wanted right" % left["side"])
	var corner := _plan(Rect2(20, 20, 48, 48))
	if str(corner["side"]) not in ["right", "below"] or not bool(corner["valid"]):
		errors.append("a find in the corner picks %s" % corner["side"])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_plan_least() -> Dictionary:
	var errors: Array = []
	var a := Rect2(600, 300, 48, 48)
	# A token on each side; the right side gets the smallest one.
	var obs: Array = [_ob(Rect2(a.position.x - 12 - 100, 300, 40, 40)), _ob(Rect2(a.end.x + 12 + 100, 300, 20, 20)),
		_ob(Rect2(560, a.position.y - 12 - 150, 60, 60)), _ob(Rect2(560, a.end.y + 12 + 50, 60, 60))]
	var p := _plan(a, obs)
	var best := INF
	for side in p["covered"]:
		best = minf(best, float(p["covered"][side]))
	if str(p["side"]) != "right" or absf(float(p["covered"][p["side"]]) - best) > 0.001 or best <= 0.0:
		errors.append("picked %s with %s, wanted right with the least area" % [p["side"], p["covered"]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_plan_anchor() -> Dictionary:
	var errors: Array = []
	var checked := 0
	for x in range(8, 1230, 97):
		for y in range(8, 560, 83):
			var a := Rect2(x, y, 48, 48)
			var p := _plan(a)
			checked += 1
			if not bool(p["valid"]):
				continue
			var card := Rect2(p["position"], _CARD)
			if card.intersects(a):
				errors.append("the card covers its item at %s: side %s" % [a.position, p["side"]])
			if not _SCREEN.grow(0.01).encloses(card):
				errors.append("the card leaves the usable rect at %s: %s" % [a.position, card])
	if checked < 50:
		errors.append("%d anchors checked" % checked)
	# A usable rect that fits the card but leaves no side: the plan is invalid and still lies inside the rect.
	var tight := Rect2(300, 200, 330, 210)
	for centre in [Vector2(465, 305), Vector2(320, 220), Vector2(610, 390)]:
		var inv := PickupDetailsPlan.plan(Rect2(centre - Vector2(24, 24), Vector2(48, 48)), _CARD, tight, [], "find", 12.0, 24.0)
		if bool(inv["valid"]) or not tight.grow(0.01).encloses(Rect2(inv["position"], _CARD)):
			errors.append("an invalid plan at %s leaves the usable rect: %s" % [centre, inv["position"]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 4)) }


static func _t_plan_blocked() -> Dictionary:
	var errors: Array = []
	var a := Rect2(600, 300, 48, 48)
	var wide := Rect2(0, 0, 1280, 720)
	# Every side is covered, left by most and below by least.
	var big: Array = [_ob(Rect2(a.position.x - 12 - 320, 200, 320, 200), 1.0), _ob(Rect2(a.end.x + 12, 200, 200, 200), 1.0),
		_ob(Rect2(520, a.position.y - 12 - 200, 320, 100), 1.0), _ob(Rect2(520, a.end.y + 12, 100, 100), 1.0)]
	var p := _plan(a, big)
	if str(p["side"]) != "below" or float(p["covered"]["below"]) <= 0.0:
		errors.append("fully blocked: picked %s with %s, wanted the least covered (below)" % [p["side"], p["covered"]])
	# A bark of 1.5 times the area of a token costs 0.75 of it, so the card covers the bark.
	var token := _ob(Rect2(a.position.x - 12 - 100, 250, 100, 100), 1.0)
	var bark := _ob(Rect2(a.end.x + 12, 250, 150, 100), PickupDetailsPlan.BARK_WEIGHT)
	var fill: Array = [_ob(Rect2(560, 100, 100, 100), 5.0), _ob(Rect2(600, 480, 100, 80), 5.0)]
	var q := _plan(a, [token, bark] + fill)
	if str(q["side"]) != "right":
		errors.append("bark against token: picked %s with %s, wanted right (the bark)" % [q["side"], q["covered"]])
	if is_equal_approx(PickupDetailsPlan.BARK_WEIGHT, 0.5) == false:
		errors.append("the bark weight is not one half")
	# Everything covered by the same area: the order decides (left for a find, left for a pack tile).
	var all: Array = [_ob(wide)]
	var strip := Rect2(480, 480, 340, 130)
	var first := Rect2(488, 540, 48, 48)
	if str(_plan(a, all)["side"]) != "left" or str(_plan(first, all, "pack", "first")["side"]) != "left":
		errors.append("equal coverage: the order must decide, got %s and %s" % [_plan(a, all)["side"], _plan(first, all, "pack", "first")["side"]])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_plan_pack_ends() -> Dictionary:
	var errors: Array = []
	var middle := Rect2(600, 540, 48, 48)
	var m := _plan(middle, [], "pack", "middle")
	if str(m["side"]) != "above":
		errors.append("a middle tile: %s, wanted above (left needs the first tile, right the last)" % m["side"])
	# Close above the tile: the card bottom is `gap` over the tile top, so it covers the strip header (no strip obstacle).
	var card := Rect2(m["position"], _CARD)
	if absf(card.end.y - (middle.position.y - 12.0)) > 0.01:
		errors.append("the middle card is not close above its tile: %s" % card)
	var last := Rect2(764, 540, 48, 48)
	if str(_plan(last, [], "pack", "last")["side"]) != "above":
		errors.append("the last tile: %s, wanted above (Jeff, D-86)" % _plan(last, [], "pack", "last")["side"])
	var above_block := Rect2(500, 150, 400, 380)
	var l2 := _plan(last, [_ob(above_block)], "pack", "last")
	if str(l2["side"]) != "right":
		errors.append("the last tile with above blocked: %s, wanted right" % l2["side"])
	var first := Rect2(488, 540, 48, 48)
	if str(_plan(first, [], "pack", "first")["side"]) != "left":
		errors.append("the first tile takes left")
	var l3 := _plan(first, [_ob(Rect2(0, 400, 480, 220))], "pack", "first")
	if str(l3["side"]) != "above":
		errors.append("the first tile with the left blocked: %s, wanted above" % l3["side"])
	if str(_plan(middle, [_ob(Rect2(0, 0, 1280, 720))], "pack", "middle")["side"]) not in ["above", "below"]:
		errors.append("a middle tile never takes left or right")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## F13: the card keeps its side while it fits, unless it covers something and another side covers nothing.
static func _t_plan_sticky() -> Dictionary:
	var errors: Array = []
	var a := Rect2(600, 300, 48, 48)
	var base := _plan(a)
	if str(base["side"]) != "left":
		errors.append("free find: %s" % base["side"])
	if str(_plan(a, [], "find", "middle", "above")["side"]) != "above":
		errors.append("a free side it has is kept even when an earlier side is free too")
	var right_pos := PickupDetailsPlan._position("right", a, _CARD, _SCREEN, 12.0)
	# The previous side (right) covers a little and the left side covers nothing: the card moves.
	if str(_plan(a, [_ob(Rect2(right_pos + Vector2(10, 10), Vector2(20, 20)))], "find", "middle", "right")["side"]) != "left":
		errors.append("a side with coverage is left when another side is free")
	# Every side covers something and the previous one is not the least: it stays.
	var each: Array = []
	for side in PickupDetailsPlan.SIDES:
		var pos := PickupDetailsPlan._position(side, a, _CARD, _SCREEN, 12.0)
		each.append(_ob(Rect2(pos + Vector2(10, 10), Vector2(20 if side != "below" else 5, 20)), 1.0))
	var keep := _plan(a, each, "find", "middle", "right")
	if str(keep["side"]) != "right":
		errors.append("the previous side is kept when none is free, got %s with %s" % [keep["side"], keep["covered"]])
	var fresh := _plan(a, each)
	if str(fresh["side"]) != "below":
		errors.append("with no previous side the least covered wins, got %s" % fresh["side"])
	# A previous side that no longer fits is dropped.
	var edge := Rect2(1240, 300, 24, 48)
	if str(_plan(edge, [], "find", "middle", "right")["side"]) == "right":
		errors.append("a side that does not fit is kept")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_arrow_sides() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var card := (o["stage"] as PickupEventStage).card()
	var layer: PickupFindsLayer = o["layer"]
	_select(o, "find", layer.find_id_at(0))
	var errors: Array = []
	var anchor := Rect2(600, 300, 48, 48)
	var panel := card.get_node("%Panel") as Control
	var arrow := card.get_node("%Arrow") as Control
	var usable := Rect2(8, 8, 1264, 700)
	for side in PickupDetailsPlan.SIDES:
		# Block every other side so that the planner has to take `side`; the card forgets its earlier side.
		card.hide_card()
		var obs: Array = []
		for other in PickupDetailsPlan.SIDES:
			if other != side:
				var pos := PickupDetailsPlan._position(other, anchor, panel.get_combined_minimum_size(), usable, PickupDetailsCard.GAP)
				if pos != Vector2.INF:
					obs.append(PickupDetailsPlan.obstacle(Rect2(pos, panel.get_combined_minimum_size()), 10.0))
		var p := card.place(anchor, usable, obs, "find")
		if str(p["side"]) != side:
			errors.append("could not force %s, got %s" % [side, p["side"]])
			continue
		var c := arrow.position + arrow.size * 0.5
		var r := Rect2(panel.position, panel.size)
		var on_edge := false
		match side:
			"left":
				on_edge = absf(c.x - r.end.x) < 0.5 and c.y >= r.position.y and c.y <= r.end.y
			"right":
				on_edge = absf(c.x - r.position.x) < 0.5 and c.y >= r.position.y and c.y <= r.end.y
			"above":
				on_edge = absf(c.y - r.end.y) < 0.5 and c.x >= r.position.x and c.x <= r.end.x
			"below":
				on_edge = absf(c.y - r.position.y) < 0.5 and c.x >= r.position.x and c.x <= r.end.x
		if not on_edge:
			errors.append("the arrow centre %s is not on the %s edge of %s" % [c, side, r])
		if arrow.theme_type_variation != &"PickupCardArrow":
			errors.append("arrow variation")
	return _done(o, errors)


static func _slots_of(o: Dictionary) -> Array:
	return ((o["snap"] as Dictionary)["data"]["pack"]["slots"] as Array)


static func _chosen_coverage(o: Dictionary, pack_card: bool = false) -> float:
	var card := (o["stage"] as PickupEventStage).card()
	var p := card.last_plan()
	return PickupDetailsPlan.coverage(Rect2(p["position"], (card.get_node("%Panel") as Control).size), (o["combat"] as CombatBoardScreen)._pickup_obstacles("", pack_card))


static func _t_plan_first_slot() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var card := (o["stage"] as PickupEventStage).card()
	var errors: Array = []
	_select(o, "pack", str(_slots_of(o)[0]["id"]))
	var p := card.last_plan()
	if str(p.get("side", "")) != "left" or not bool(p.get("valid", false)):
		errors.append("the first pack slot picks %s, covered %s" % [p.get("side", ""), p.get("covered", {})])
	if _chosen_coverage(o, true) > 0.0001:
		errors.append("the card on the left covers %f of obstacles" % _chosen_coverage(o, true))
	var panel := card.get_node("%Panel") as Control
	if not (o["combat"] as CombatBoardScreen)._pickup_usable_rect().grow(0.01).encloses(Rect2(panel.position, panel.size)):
		errors.append("the card is not inside the usable rect")
	return _done(o, errors)


static func _slot_rects(o: Dictionary) -> Array:
	var strip := _stripof(o)
	var out: Array = []
	for i in strip.slot_count():
		out.append(strip.slot_global_rect(i))
	return out


## Every listed pack slot in turn: the card sits close to its tile, never covers it or any slot, and keeps the allowed sides.
static func _t_plan_pack_slots() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var card := (o["stage"] as PickupEventStage).card()
	var strip := _stripof(o)
	var panel := card.get_node("%Panel") as Control
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	var n := mini(_slots_of(o).size(), strip.slot_count())
	for i in n:
		_select(o, "pack", str(_slots_of(o)[i]["id"]))
		var p := card.last_plan()
		var r := Rect2(panel.position, panel.size)
		var tile := strip.slot_global_rect(i)
		if not bool(p.get("valid", false)):
			errors.append("slot %d has no valid side" % i)
		for slot_rect: Rect2 in _slot_rects(o):
			if r.intersects(slot_rect):
				errors.append("the card of slot %d covers a slot of the row" % i)
		var side := str(p.get("side", ""))
		if (i > 0 and i < n - 1 and side != "above") or (i == 0 and side not in ["left", "above"]) or (i == n - 1 and i > 0 and side not in ["right", "above"]):
			errors.append("slot %d picked %s" % [i, side])
		# Short arrow: the card edge on the tile side is `gap` from the tile.
		var edge := {"left": tile.position.x - r.end.x, "right": r.position.x - tile.end.x, "above": tile.position.y - r.end.y, "below": r.position.y - tile.end.y}
		if side in edge and absf(float(edge[side]) - PickupDetailsCard.GAP) > 0.51:
			errors.append("slot %d: the card is %f from its tile, wanted %f" % [i, edge[side], PickupDetailsCard.GAP])
		if side == "above":
			# The header band lies between the strip top and the tiles. Which header parts it covers depends on the slot: a slot at the
			# right end covers the tokens and not the title (the card is 320 wide, the strip 344).
			var strip_rect := strip.panel_global_rect()
			if not r.intersects(Rect2(strip_rect.position, Vector2(strip_rect.size.x, tile.position.y - strip_rect.position.y))):
				errors.append("slot %d: an above card must cover the strip header" % i)
		if combat._pickup_obstacles("", true).any(func(d: Dictionary) -> bool: return (d["rect"] as Rect2) == strip.panel_global_rect()):
			errors.append("the strip is an obstacle of a pack card")
	return _done(o, errors)


static func _t_pack_obstacles() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var strip := _stripof(o)
	var errors: Array = []
	var rects: Array = combat._pickup_obstacles("", true).map(func(d: Dictionary) -> Rect2: return d["rect"])
	if rects.has(strip.panel_global_rect()):
		errors.append("the strip is an obstacle of a pack card")
	var centers := layer.screen_centers()
	for c: Vector2 in centers:
		if rects.any(func(r: Rect2) -> bool: return r.get_center().distance_to(c) < 0.01):
			errors.append("a find is an obstacle of a pack card")
	var find_rects: Array = combat._pickup_obstacles(layer.find_id_at(0)).map(func(d: Dictionary) -> Rect2: return d["rect"])
	if find_rects.size() <= rects.size() + 1:
		errors.append("a find card must keep its actors, finds and strip: %d against %d" % [find_rects.size(), rects.size()])
	var bar := combat._echo_bar_top()
	if not is_nan(bar) and not rects.any(func(r: Rect2) -> bool: return is_equal_approx(r.position.y, bar)):
		errors.append("the EchoBar is not an obstacle of a pack card")
	return _done(o, errors)


static func _t_find_avoids() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var card := (o["stage"] as PickupEventStage).card()
	var errors: Array = []
	var any_token := false
	for i in layer.mark_count():
		_select(o, "find", layer.find_id_at(i))
		var p := card.last_plan()
		var best := INF
		for side in p["covered"]:
			best = minf(best, float(p["covered"][side]))
		if not bool(p.get("valid", false)) or absf(float(p["covered"][p["side"]]) - best) > 0.001:
			errors.append("find %d picks %s with %s" % [i, p.get("side", ""), p.get("covered", {})])
		var again := PickupDetailsPlan.coverage(Rect2(p["position"], (card.get_node("%Panel") as Control).size), combat._pickup_obstacles(layer.find_id_at(i)))
		if absf(again - float(p["covered"][p["side"]])) > 0.01:
			errors.append("find %d: the plan used other obstacles than the board gives" % i)
		any_token = any_token or combat._pickup_obstacles(layer.find_id_at(i)).size() > 4
	if not any_token:
		errors.append("a find card has no actor obstacles")
	return _done(o, errors)


static func _t_hit_zoom() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	combat.camera.zoom = Vector2(2.0, 2.0)
	var scale := layer.get_global_transform_with_canvas().get_scale().x
	var half := combat._pickup_find_half()
	if scale < 1.9 or half < layer.bed() * scale * 0.5 - 0.01 or half <= PickupHitRules.TARGET * 0.5:
		errors.append("at zoom 2 the half size is %f (scale %f)" % [half, scale])
	var c: Vector2 = layer.screen_centers()[0]
	if combat._pickup_find_at(c + Vector2(half - 2.0, 0.0)) != 0:
		errors.append("a tap on the drawn find edge (%f from its centre) misses" % (half - 2.0))
	if combat._pickup_find_at(c + Vector2(half + 6.0, 0.0)) == 0:
		errors.append("a tap outside the drawn find hits")
	var anchor: Rect2 = combat._pickup_anchor_rect(PickupHitRules.selection({ "selected": { "id": layer.find_id_at(0), "side": "find" }, "finds": (o["snap"] as Dictionary)["data"]["finds"] }))
	if absf(anchor.size.x - half * 2.0) > 0.01:
		errors.append("the card anchor (%f) and the hit target (%f) differ" % [anchor.size.x, half * 2.0])
	return _done(o, errors)


static func _t_tab_wrap() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var vp := o["vp"] as SubViewport
	var errors: Array = []
	var cont: Button = combat._pickup_debug.continue_button()
	cont.grab_focus()
	_key(o, KEY_TAB)
	if layer.focus_index() != 0 or vp.gui_get_focus_owner() != null:
		errors.append("Tab from Continue: find %d, owner %s" % [layer.focus_index(), vp.gui_get_focus_owner()])
	# Without the debug buttons the last pack tile is the last target.
	layer.set_focus_index(-1)
	combat._pickup_debug.hide()
	var last := _stripof(o).focus_targets().back() as Control
	last.grab_focus()
	_key(o, KEY_TAB)
	if layer.focus_index() != 0 or vp.gui_get_focus_owner() != null:
		errors.append("Tab from the last pack tile: find %d, owner %s" % [layer.focus_index(), vp.gui_get_focus_owner()])
	return _done(o, errors)


static func _t_hidden() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var stage: PickupEventStage = o["stage"]
	var card := stage.card()
	var errors: Array = []
	_select(o, "find", _first_find_id(o))
	if not card.is_open():
		errors.append("the card did not open")
	o["sent"].clear()
	combat.hide()
	var layer := stage.get_node("%CardLayer") as CanvasLayer
	if layer.visible or card.is_open():
		errors.append("a hidden board leaves the card layer on (%s) or the card open" % layer.visible)
	_key(o, KEY_ESCAPE)
	if not (o["sent"] as Array).is_empty():
		errors.append("Esc closed a card of a hidden board: %s" % [o["sent"]])
	combat.show()
	if not layer.visible:
		errors.append("the card layer does not come back with the board")
	PickupUiHostTests._free(o["fx"])
	# The held Resolve card opens over the board after Continue: the card is gone and Esc is not taken.
	var snap := _snap("many", "resolve", "")
	var open := _open()
	if snap.is_empty() or open.has("error"):
		return { "ok": false, "error": "no resolve snapshot or mount" }
	_select(open, "find", _first_find_id(open))
	open["sent"].clear()
	# Continue goes out through the board; then the Resolve snapshot opens over the board, which stays mounted.
	(open["combat"] as CombatBoardScreen)._pickup_debug.continue_button().pressed.emit()
	((open["fx"] as Dictionary)["realm"] as RealmShell).set_snapshot(snap)
	open["sent"] = (open["sent"] as Array).filter(func(a: Dictionary) -> bool: return str(a.get("type", "")) != "pickup.continue")
	var st := open["stage"] as PickupEventStage
	if st.card().is_open():
		errors.append("the card is still open after the Resolve snapshot")
	_key(open, KEY_ESCAPE)
	_key(open, KEY_TAB)
	if not _selects(open["sent"]).is_empty() or (open["layer"] as PickupFindsLayer).focus_index() != -1:
		errors.append("the event took input after the Resolve snapshot: %s, focus %d" % [open["sent"], (open["layer"] as PickupFindsLayer).focus_index()])
	return _done(open, errors)


static func _rings(o: Dictionary) -> int:
	var n := 0
	var layer: PickupFindsLayer = o["layer"]
	for i in layer.mark_count():
		n += 1 if _ring_of(layer.mark(i)).visible else 0
	for t: Control in _stripof(o).focus_targets():
		if t is Button and _ring_of(t as Button).visible:
			n += 1
	return n


## Applies the last `pickup.select` the board sent, as core would: the next snapshot carries it.
static func _apply_sent(o: Dictionary) -> void:
	var sel := _selects(o["sent"])
	var p: Dictionary = sel.back()["payload"] if not sel.is_empty() else {}
	if p.has("find_id"):
		_select(o, "find", str(p["find_id"]))
	elif p.has("pack_id"):
		_select(o, "pack", str(p["pack_id"]))
	else:
		_select(o, "", "")


static func _t_click_tile() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var strip := _stripof(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var tile := strip.focus_targets()[2] as Button
	var row: Dictionary = _slots_of(o)[0]
	_click(o, tile.get_global_rect().get_center())
	var sel := _selects(o["sent"])
	if sel.size() != 1 or str((sel[0]["payload"] as Dictionary).get("pack_id", "")) != str(row["id"]):
		errors.append("a real click on a pack tile sent %s" % [o["sent"]])
	if tile.has_focus():
		errors.append("the tile keeps the engine focus after a mouse click")
	_apply_sent(o)
	if _rings(o) != 1:
		errors.append("%d rings after the click (the selected tile only)" % _rings(o))
	o["sent"].clear()
	_click(o, tile.get_global_rect().get_center())
	if tile.has_focus() or _selects(o["sent"]).size() != 1 or not (_selects(o["sent"])[0]["payload"] as Dictionary).is_empty():
		errors.append("a second click must close and leave no focus: %s" % [o["sent"]])
	_apply_sent(o)
	if _rings(o) != 0:
		errors.append("%d rings after the second click" % _rings(o))
	o["sent"].clear()
	_click(o, tile.get_global_rect().get_center())
	_apply_sent(o)
	o["sent"].clear()
	_click(o, layer.screen_centers()[1])
	_apply_sent(o)
	if _rings(o) != 1 or not _ring_of(layer.mark(1)).visible:
		errors.append("after a find tap there must be one ring, on the find: %d" % _rings(o))
	return _done(o, errors)


static func _t_empty_slot() -> Dictionary:
	var o := _open("empty")
	if o.has("error"):
		return _fail(o)
	var strip := _stripof(o)
	var errors: Array = []
	var empty := strip.slot_count() - 1
	if _slots_of(o).size() >= strip.slot_count():
		errors.append("the fixture has no empty slot")
	strip._on_slot_chosen("pack", empty)
	if not (o["sent"] as Array).is_empty():
		errors.append("an empty slot with nothing selected sent %s" % [o["sent"]])
	_select(o, "pack", str(_slots_of(o)[0]["id"]))
	o["sent"].clear()
	strip._on_slot_chosen("pack", empty)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("an empty slot with a card open must close it, sent %s" % [o["sent"]])
	return _done(o, errors)


static func _pad(o: Dictionary, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	(o["vp"] as SubViewport).push_input(ev, false)


## N1: the D-pad enters like Tab, through the default `ui_right` and `ui_down` actions (project.godot has no [input] section).
static func _t_pad() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var probe := InputEventJoypadButton.new()
	probe.button_index = JOY_BUTTON_DPAD_RIGHT
	probe.pressed = true
	if not probe.is_action_pressed("ui_right"):
		errors.append("the default ui_right has no joypad D-pad event")
	_pad(o, JOY_BUTTON_DPAD_RIGHT)
	if layer.focus_index() != 0:
		errors.append("D-pad right with no focus entered find %d, wanted 0" % layer.focus_index())
	_pad(o, JOY_BUTTON_DPAD_RIGHT)
	if layer.focus_index() != 1:
		errors.append("D-pad right again went to %d, wanted 1" % layer.focus_index())
	layer.set_focus_index(-1)
	_pad(o, JOY_BUTTON_DPAD_DOWN)
	if layer.focus_index() != 0:
		errors.append("D-pad down with no focus entered find %d, wanted 0" % layer.focus_index())
	# Not read: a stick (InputEventJoypadMotion) never enters. The engine's default `ui_accept` has no joypad event, so a pad cannot press a mark.
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	layer.set_focus_index(-1)
	(o["vp"] as SubViewport).push_input(stick, false)
	if layer.focus_index() != -1:
		errors.append("a stick entered a find")
	return _done(o, errors)


## N2: Esc returns the focus to what opened the CURRENT card, not to an older opener.
static func _t_opener() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var strip := _stripof(o)
	var card := (o["stage"] as PickupEventStage).card()
	var vp := o["vp"] as SubViewport
	var errors: Array = []
	_key(o, KEY_TAB)
	_key(o, KEY_ENTER)
	_apply_sent(o)
	if not card.is_open() or not card.close_button().has_focus():
		errors.append("Enter on find A did not open the card with the focus on Close")
	var tile := strip.focus_targets()[2] as Button
	tile.grab_focus()
	o["sent"].clear()
	_tap_key(o, KEY_ENTER)
	_apply_sent(o)
	if card.current_id() != str(_slots_of(o)[0]["id"]):
		errors.append("Enter on the pack tile did not switch the card to it")
	o["sent"].clear()
	_key(o, KEY_ESCAPE)
	_apply_sent(o)
	if card.is_open() or not tile.has_focus() or layer.focus_index() != -1:
		errors.append("Esc must return the focus to the pack tile: open %s, tile focus %s, find focus %d, owner %s" % [card.is_open(), tile.has_focus(), layer.focus_index(), vp.gui_get_focus_owner()])
	# The other way round: a tile opened the card, then a find does.
	tile.grab_focus()
	_tap_key(o, KEY_ENTER)
	_apply_sent(o)
	tile.release_focus()
	layer.set_focus_index(1)
	o["sent"].clear()
	_key(o, KEY_ENTER)
	_apply_sent(o)
	_key(o, KEY_ESCAPE)
	_apply_sent(o)
	if layer.focus_index() != 1 or tile.has_focus():
		errors.append("Esc must return the focus to find 1, got find %d, tile focus %s" % [layer.focus_index(), tile.has_focus()])
	return _done(o, errors)


## N3: the focus follows its find by id when the list changes and drops when the find leaves.
static func _t_focus_list() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	if layer.mark_count() < 3:
		return _done(o, ["the fixture needs three finds"])
	var focused := layer.find_id_at(2)
	layer.set_focus_index(2)
	var snap: Dictionary = (o["snap"] as Dictionary).duplicate(true)
	((snap["data"]["finds"] as Array)[0] as Dictionary)["status"] = "taken"
	((o["fx"] as Dictionary)["realm"] as RealmShell).set_snapshot(snap)
	if layer.mark_count() != 2 or layer.focus_index() != 1 or layer.find_id_at(layer.focus_index()) != focused:
		errors.append("an earlier find left: focus %d of %d, wanted 1 on %s" % [layer.focus_index(), layer.mark_count(), focused])
	var snap2: Dictionary = (o["snap"] as Dictionary).duplicate(true)
	for f: Dictionary in snap2["data"]["finds"]:
		if str(f["find_id"]) == focused:
			f["status"] = "taken"
	((o["fx"] as Dictionary)["realm"] as RealmShell).set_snapshot(snap2)
	if layer.focus_index() != -1 or _rings(o) != 0:
		errors.append("the focused find left: focus %d, rings %d" % [layer.focus_index(), _rings(o)])
	((o["fx"] as Dictionary)["realm"] as RealmShell).set_snapshot(o["snap"])
	if layer.focus_index() != -1:
		errors.append("the focus came back by itself: %d" % layer.focus_index())
	return _done(o, errors)


## N4: a Control outside the event (the F1 debug field) that owns the focus keeps Enter and Tab.
static func _t_foreign_focus() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var field := LineEdit.new()
	combat.add_child(field)
	field.grab_focus()
	if not field.has_focus():
		errors.append("the test field did not take the focus")
	_key(o, KEY_TAB)
	if layer.focus_index() != -1:
		errors.append("Tab entered a find while a LineEdit had the focus")
	# The field's own Tab moved the focus on; give it back before Enter.
	field.grab_focus()
	layer.set_focus_index(0)
	o["sent"].clear()
	_key(o, KEY_ENTER)
	if not (o["sent"] as Array).is_empty():
		errors.append("Enter selected a find while a LineEdit had the focus: %s" % [o["sent"]])
	field.release_focus()
	layer.set_focus_index(0)
	o["sent"].clear()
	_key(o, KEY_ENTER)
	if _selects(o["sent"]).size() != 1:
		errors.append("Enter does not select the focused find without the field: %s" % [o["sent"]])
	field.free()
	return _done(o, errors)


## N5 probe: two finds 64 board px apart (spacing 1) ask for a floor of 0.875. `frame` clamps to its minimum, so it stays valid and
## keeps zoom 0.875 even when the box does not fit: the finds' floor wins over the fit unless the board lowers it.
static func _t_frame_probe() -> Dictionary:
	var errors: Array = []
	var floor := PickupHitRules.min_zoom([Vector2.ZERO, Vector2(0, 64)])
	if absf(floor - 0.875) > 0.0001:
		errors.append("spacing 1 diagonal floor %f, wanted 0.875" % floor)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(0, 64), Vector2(900, 300), Vector2(-700, 200)])
	var usable := Rect2(16, 16, 700, 300)
	var tile := Vector2(128, 64)
	var fit := PickupCameraFrame.fit_zoom(points, tile, usable, 48.0)
	var framed := PickupCameraFrame.frame(points, tile, Vector2(1280, 720), usable, 1.3, floor, 2.2, 0.75, 48.0)
	if not bool(framed["valid"]) or absf(float(framed["zoom"]) - floor) > 0.0001 or fit >= floor:
		errors.append("probe: valid %s zoom %f fit %f floor %f" % [framed["valid"], float(framed["zoom"]), fit, floor])
	var low := PickupCameraFrame.frame(points, tile, Vector2(1280, 720), usable, 1.3, minf(floor, fit), 2.2, 0.75, 48.0)
	if absf(float(low["zoom"]) - fit) > 0.0001:
		errors.append("with the floor lowered to the fit the frame gives %f, wanted %f" % [float(low["zoom"]), fit])
	if PickupCameraFrame.fit_zoom(PackedVector2Array(), tile, usable, 48.0) != 0.0:
		errors.append("no points must give fit 0")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


## N5: a screen too small for the box at the finds' floor: the fit wins, every find stays on screen, and the camera floor gives way.
static func _t_fit_wins() -> Dictionary:
	var snap := _snap("many", "idle", "none")
	if snap.is_empty():
		return { "ok": false, "error": "no snapshot" }
	var fx := PickupPackStripTests._mount_at(snap, Vector2i(800, 450), &"compact")
	if fx.is_empty():
		return { "ok": false, "error": "mount failed" }
	var combat := fx["combat"] as CombatBoardScreen
	var layer := combat.get_node("%PickupFindsLayer") as PickupFindsLayer
	var errors: Array = []
	combat.frame_pickup_camera(false)
	var view := Rect2(Vector2.ZERO, Vector2(800, 450))
	if combat._pickup_fit_cap == INF:
		errors.append("no conflict at 800 x 450: floor %f, zoom %f" % [combat._pickup_floor_derived, combat.camera.zoom.x])
	else:
		if absf(combat._pickup_zoom_floor - combat._pickup_fit_cap) > 0.0001 or combat._pickup_zoom_floor >= combat._pickup_floor_derived:
			errors.append("the camera floor %f must give way to the fit %f (finds ask %f)" % [combat._pickup_zoom_floor, combat._pickup_fit_cap, combat._pickup_floor_derived])
		if combat.camera.zoom.x > combat._pickup_fit_cap + 0.0001:
			errors.append("the camera zoom %f is above the fit %f" % [combat.camera.zoom.x, combat._pickup_fit_cap])
	for c: Vector2 in layer.screen_centers():
		if not view.has_point(c):
			errors.append("a find lies off screen at %s" % c)
	PickupUiHostTests._free(fx)
	return { "ok": errors.is_empty(), "error": "; ".join(errors.slice(0, 4)) }


static func _t_real_esc() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var errors: Array = []
	_select(o, "find", _first_find_id(o))
	o["sent"].clear()
	_key(o, KEY_ESCAPE)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("a real Esc sent %s" % [o["sent"]])
	return _done(o, errors)


static func _t_stack_line() -> Dictionary:
	var errors: Array = []
	var found := 0
	for kind in ["many", "near"]:
		var o := _open(kind)
		if o.has("error"):
			return _fail(o)
		var card := (o["stage"] as PickupEventStage).card()
		var data: Dictionary = (o["snap"] as Dictionary)["data"]
		var cases: Array = []
		for f: Dictionary in data["finds"]:
			if ItemMovePlan.is_stack(f) and str(f["status"]) != "taken":
				cases.append(["find", str(f["find_id"]), f])
		for sl: Dictionary in data["pack"]["slots"]:
			if ItemMovePlan.is_stack(sl):
				cases.append(["pack", str(sl["id"]), sl])
		for c: Array in cases:
			found += 1
			_select(o, str(c[0]), str(c[1]))
			var row: Dictionary = c[2]
			var want := "%s: %s" % [ItemUiText.COUNT_LABEL, ItemUiText.stack_count(int(row.get("quantity", 0)), int(row.get("stack_limit", 0)))]
			var text := (card.block().get_node("%CountLabel") as Label).text
			if int(row.get("stack_limit", 0)) <= 0 or text != want or not text.contains(" of "):
				errors.append("%s row of %s: the card reads '%s', wanted '%s' (stack_limit %s)" % [c[0], kind, text, want, row.get("stack_limit", "missing")])
		PickupUiHostTests._free(o["fx"])
	if found == 0:
		errors.append("the fixtures have no stack row")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_bark_obstacle() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	var barks: Array = combat._bark_popup_layer.popup_rects()
	if barks.is_empty():
		errors.append("the fixture shows no bark")
	var pack_rects: Array = combat._pickup_obstacles("", true).map(func(d: Dictionary) -> Rect2: return d["rect"])
	var find_obs: Array = combat._pickup_obstacles(_first_find_id(o))
	var find_rects: Array = find_obs.map(func(d: Dictionary) -> Rect2: return d["rect"])
	for r: Rect2 in barks:
		if pack_rects.has(r):
			errors.append("a bark is an obstacle of a pack card")
		if not find_rects.has(r):
			errors.append("a bark is no obstacle of a find card")
	for d: Dictionary in find_obs:
		if barks.has(d["rect"]) and not is_equal_approx(float(d["weight"]), PickupDetailsPlan.BARK_WEIGHT):
			errors.append("a bark has weight %f" % float(d["weight"]))
	return _done(o, errors)


static func _t_usable() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var u: Rect2 = (o["combat"] as CombatBoardScreen)._pickup_usable_rect()
	var errors: Array = []
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	if u.position.x < 16.0 - 0.01 or u.position.y < 16.0 - 0.01 or u.end.x > view.end.x - 16.0 + 0.01:
		errors.append("the usable rect %s is closer than 16 to the screen edge" % u)
	return _done(o, errors)


static func _t_plan_real_obstacles() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var layer: PickupFindsLayer = o["layer"]
	var strip := _stripof(o)
	var errors: Array = []
	var obs: Array = combat._pickup_obstacles(layer.find_id_at(0))
	var rects: Array = obs.map(func(d: Dictionary) -> Rect2: return d["rect"])
	if not rects.has(strip.panel_global_rect()):
		errors.append("the strip rect is not an obstacle")
	var tokens := combat.get_node("%TokenLayer") as CombatTokenLayer
	var xf := tokens.get_global_transform_with_canvas()
	var radius: float = tokens.visual_config.token_radius * xf.get_scale().x
	var token_rects := 0
	for a: Dictionary in combat._last_actors:
		var at := tokens.display_cell_position(str(a["id"]))
		if at == Vector2.INF:
			continue
		token_rects += 1
		var c := xf * (at + Vector2(0.0, tokens.visual_config.feet_offset_y))
		if not rects.has(Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
			errors.append("the drawn token of %s is not an obstacle" % a["id"])
	if token_rects == 0:
		errors.append("no token in the scene")
	var marks := layer.mark_count() - 1
	var centers := layer.screen_centers()
	var found := 0
	for i in range(1, layer.mark_count()):
		if rects.any(func(r: Rect2) -> bool: return r.get_center().distance_to(centers[i]) < 0.01):
			found += 1
	if found != marks or rects.any(func(r: Rect2) -> bool: return r.get_center().distance_to(centers[0]) < 0.01):
		errors.append("other finds are obstacles, the own find is not: %d of %d" % [found, marks])
	# Not hand-copied: moving the finds layer moves its obstacles.
	layer.position += Vector2(40, 0)
	var moved: Array = combat._pickup_obstacles(layer.find_id_at(0)).map(func(d: Dictionary) -> Rect2: return d["rect"])
	if moved == rects:
		errors.append("the obstacles did not follow the finds layer")
	return _done(o, errors)


# ── Real input ──────────────────────────────────────────────────────────────

## F3: a real mouse press and release pushed through the viewport reaches the board's tap and no world button gets it.
static func _t_real_mouse() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var pressed := [0]
	for i in layer.get_child_count():
		(layer.get_child(i) as Button).pressed.connect(func() -> void: pressed[0] += 1)
	var at: Vector2 = layer.screen_centers()[0]
	if not Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(at):
		errors.append("the first find lies off screen at %s" % at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	(o["vp"] as SubViewport).push_input(motion, true)
	var hovered := (o["vp"] as SubViewport).gui_get_hovered_control()
	if hovered != null and layer.is_ancestor_of(hovered):
		errors.append("a world button is under the pointer: %s" % hovered.name)
	_click(o, at)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or str((sel[0]["payload"] as Dictionary).get("find_id", "")) != _first_find_id(o):
		errors.append("the tap sent %s, wanted select of the first find" % [o["sent"]])
	if pressed[0] != 0:
		errors.append("a world button took the press")
	return _done(o, errors)


static func _t_tap_toggle() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	var second: Vector2 = layer.screen_centers()[1]
	_click(o, second)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or str((sel[0]["payload"] as Dictionary).get("find_id", "")) != layer.find_id_at(1):
		errors.append("a tap on the second find sent %s" % [o["sent"]])
	_select(o, "find", layer.find_id_at(1))
	o["sent"].clear()
	_click(o, second)
	sel = _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("a second tap on the selected find must close, sent %s" % [o["sent"]])
	return _done(o, errors)


static func _t_intro_inert() -> Dictionary:
	var o := _open("many", "intro", "")
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	if layer.mark_count() == 0:
		errors.append("the intro draws no find")
	for c: Vector2 in layer.screen_centers():
		_click(o, c)
	if not (o["sent"] as Array).is_empty():
		errors.append("a tap in the intro sent %s; Skip is the only action" % [o["sent"]])
	if (o["stage"] as PickupEventStage).card().is_open():
		errors.append("the card is open in the intro")
	return _done(o, errors)


static func _t_tap_empty() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	var far := Vector2(20, 120)
	for c: Vector2 in (o["layer"] as PickupFindsLayer).screen_centers():
		if c.distance_to(far) < 60.0:
			far = Vector2(1200, 120)
	var mode_before := int(combat.camera.mode)
	_click(o, far)
	if not (o["sent"] as Array).is_empty():
		errors.append("an empty tap with no card open sent %s" % [o["sent"]])
	_select(o, "find", _first_find_id(o))
	_click(o, far)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("an empty tap with the card open must close it, sent %s" % [o["sent"]])
	if int(combat.camera.mode) != mode_before:
		errors.append("an empty tap changed the camera mode")
	return _done(o, errors)


static func _t_card() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var card := (o["stage"] as PickupEventStage).card()
	var errors: Array = []
	if card.is_open():
		errors.append("the card is open with nothing selected")
	_select(o, "find", layer.find_id_at(0))
	var row: Dictionary = (PickupHitRules.selection((o["snap"] as Dictionary)["data"]))["row"]
	if not card.is_open() or card.current_id() != layer.find_id_at(0):
		errors.append("the card did not open for the selected find")
	var name_label := card.block().get_node("%NameLabel") as Label
	if name_label.text != ItemUiText.display_name(row):
		errors.append("name line '%s'" % name_label.text)
	if (card.block().get_node("%WhereLabel") as Label).text != PickupUiText.where_text("ground"):
		errors.append("where line for a find on the ground")
	if card.close_button().text != PickupUiText.line("btn.close"):
		errors.append("close text '%s'" % card.close_button().text)
	var anchor := Rect2((layer.screen_centers()[0] as Vector2) - Vector2(24, 24), Vector2(48, 48))
	var panel := card.get_node("%Panel") as Control
	var rect := Rect2(panel.position, panel.size)
	if rect.intersects(anchor):
		errors.append("the card covers its item")
	if not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect):
		errors.append("the card leaves the screen: %s" % rect)
	var bark := (o["combat"] as Node).get_node("%BarkPopupLayer") as Node
	var bark_layer := _canvas_layer_of(bark)
	var card_layer := (o["stage"] as Node).get_node("%CardLayer") as CanvasLayer
	if bark_layer == null or card_layer.layer <= bark_layer.layer or card_layer.layer >= 40:
		errors.append("the card layer %d must be above the bark layer and below the modal layer 40" % card_layer.layer)
	# A pack tile selected: the pack line.
	var slot_row: Dictionary = ((o["snap"] as Dictionary)["data"]["pack"]["slots"] as Array)[0]
	_select(o, "pack", str(slot_row["id"]))
	if (card.block().get_node("%WhereLabel") as Label).text != ItemUiText.WHERE_PACK:
		errors.append("where line for a pack item")
	_select(o, "", "")
	if card.is_open():
		errors.append("the card stays open after the selection cleared")
	return _done(o, errors)


static func _canvas_layer_of(node: Node) -> CanvasLayer:
	var n := node
	while n != null:
		if n is CanvasLayer:
			return n as CanvasLayer
		n = n.get_parent()
	return null


static func _t_card_offscreen() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	_select(o, "find", _first_find_id(o))
	o["sent"].clear()
	layer.position += Vector2(6000, 0)
	combat.call("_update_pickup_card", false)
	combat.call("_update_pickup_card", false)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("an item off screen must close the card once, sent %s" % [o["sent"]])
	return _done(o, errors)


static func _t_close() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var card := (o["stage"] as PickupEventStage).card()
	var errors: Array = []
	_select(o, "find", _first_find_id(o))
	var b := card.close_button()
	if b.theme_type_variation != &"ItemButtonOutline" or b.get_combined_minimum_size().y < 48.0:
		errors.append("Close is %s, %s high" % [b.theme_type_variation, b.get_combined_minimum_size().y])
	o["sent"].clear()
	b.pressed.emit()
	var sel := _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("Close sent %s" % [o["sent"]])
	o["sent"].clear()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	card._input(esc)
	if _selects(o["sent"]).size() != 1:
		errors.append("Esc sent %s" % [o["sent"]])
	return _done(o, errors)


static func _t_pack_choose() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var strip := _stripof(o)
	var errors: Array = []
	var row: Dictionary = (((o["snap"] as Dictionary)["data"] as Dictionary)["pack"]["slots"] as Array)[0]
	strip._on_slot_chosen("pack", 0)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or str((sel[0]["payload"] as Dictionary).get("pack_id", "")) != str(row["id"]):
		errors.append("a pack tile sent %s" % [o["sent"]])
	_select(o, "pack", str(row["id"]))
	o["sent"].clear()
	strip._on_slot_chosen("pack", 0)
	sel = _selects(o["sent"])
	if sel.size() != 1 or not (sel[0]["payload"] as Dictionary).is_empty():
		errors.append("the selected pack tile again must close, sent %s" % [o["sent"]])
	var tile := strip.focus_targets().back() as Button
	if tile == null or tile.focus_mode != Control.FOCUS_ALL:
		errors.append("a pack tile takes focus in idle")
	PickupUiHostTests._free(o["fx"])
	var intro := _open("many", "intro", "")
	if intro.has("error"):
		return _fail(intro)
	var s2 := _stripof(intro)
	s2._on_slot_chosen("pack", 0)
	if not (intro["sent"] as Array).is_empty():
		errors.append("a pack tile sent %s in the intro" % [intro["sent"]])
	if s2.focus_targets().size() != 2:
		errors.append("in the intro only the two tokens take focus, got %d targets" % s2.focus_targets().size())
	return _done(intro, errors)


static func _ring_of(tile: Button) -> Panel:
	return tile.get_node("%SelectedRing") as Panel


static func _t_rings() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var errors: Array = []
	for i in layer.mark_count():
		if _ring_of(layer.mark(i)).visible:
			errors.append("mark %d shows a ring with nothing selected" % i)
	_select(o, "find", layer.find_id_at(1))
	var r := _ring_of(layer.mark(1))
	if not r.visible or r.theme_type_variation != &"ItemTileSelectedDark":
		errors.append("the selected find shows %s, visible %s" % [r.theme_type_variation, r.visible])
	if _ring_of(layer.mark(0)).visible:
		errors.append("an unselected find shows a ring")
	layer.set_focus_index(2)
	var f := _ring_of(layer.mark(2))
	if not f.visible or f.theme_type_variation != &"ItemTileSelectedDark":
		errors.append("the focused find shows %s, visible %s" % [f.theme_type_variation, f.visible])
	layer.set_focus_index(-1)
	if _ring_of(layer.mark(2)).visible:
		errors.append("the ring stays after the focus left")
	return _done(o, errors)


static func _t_pack_ring() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var strip := _stripof(o)
	var errors: Array = []
	var row: Dictionary = (((o["snap"] as Dictionary)["data"] as Dictionary)["pack"]["slots"] as Array)[0]
	_select(o, "pack", str(row["id"]))
	var tile := strip.focus_targets()[2] as Button
	var r := _ring_of(tile)
	if not tile.ring or not r.visible or r.theme_type_variation != &"ItemTileSelectedDark":
		errors.append("selected pack tile: ring %s, visible %s, %s" % [tile.ring, r.visible, r.theme_type_variation])
	var other := strip.focus_targets()[3] as Button
	if _ring_of(other).visible:
		errors.append("an unselected pack tile shows a ring")
	other.grab_focus()
	if not other.has_focus() or not _ring_of(other).visible:
		errors.append("a focused pack tile shows the cream ring (focus %s)" % other.has_focus())
	other.release_focus()
	if _ring_of(other).visible:
		errors.append("the ring stays after the focus left")
	return _done(o, errors)


static func _t_tab() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var strip := _stripof(o)
	var vp := o["vp"] as SubViewport
	var errors: Array = []
	if layer.focus_index() != -1 or vp.gui_get_focus_owner() != null:
		errors.append("focus is taken before any key")
	_key(o, KEY_TAB)
	if layer.focus_index() != 0:
		errors.append("the first Tab enters on the first find, at %d" % layer.focus_index())
	for k in range(1, layer.mark_count()):
		_key(o, KEY_TAB)
		if layer.focus_index() != k:
			errors.append("Tab %d reached find %d" % [k, layer.focus_index()])
	_key(o, KEY_TAB)
	if layer.focus_index() != -1 or vp.gui_get_focus_owner() != strip.focus_targets()[0]:
		errors.append("after the last find Tab goes to the first token (find %d)" % layer.focus_index())
	_key(o, KEY_TAB, true)
	if layer.focus_index() != layer.mark_count() - 1:
		errors.append("Shift+Tab from the first token goes back to the last find, at %d" % layer.focus_index())
	for _k in range(layer.mark_count() - 1):
		_key(o, KEY_TAB, true)
	if layer.focus_index() != 0:
		errors.append("Shift+Tab walks the finds backward, at %d" % layer.focus_index())
	_key(o, KEY_TAB, true)
	if layer.focus_index() != -1:
		errors.append("Shift+Tab before the first find leaves the finds, at %d" % layer.focus_index())
	_key(o, KEY_TAB)
	# A mouse press clears the keyboard focus.
	var click_at := Vector2(20, 120)
	_click(o, click_at)
	if layer.focus_index() != -1:
		errors.append("a mouse press leaves the keyboard focus on a find")
	return _done(o, errors)


static func _t_accept() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var card := (o["stage"] as PickupEventStage).card()
	var errors: Array = []
	_key(o, KEY_TAB)
	_key(o, KEY_ENTER)
	var sel := _selects(o["sent"])
	if sel.size() != 1 or str((sel[0]["payload"] as Dictionary).get("find_id", "")) != layer.find_id_at(0):
		errors.append("Enter on the focused find sent %s" % [o["sent"]])
	_select(o, "find", layer.find_id_at(0))
	if not card.close_button().has_focus():
		errors.append("the card takes the focus after a key")
	if layer.focus_index() != -1:
		errors.append("the mark keeps the keyboard focus while the card has it")
	_select(o, "", "")
	if layer.focus_index() != 0:
		errors.append("closing returns the focus to the find, at %d" % layer.focus_index())
	# After a mouse tap the card does not take the focus.
	_click(o, layer.screen_centers()[1])
	_select(o, "find", layer.find_id_at(1))
	if card.close_button().has_focus():
		errors.append("the card took the focus after a mouse tap")
	return _done(o, errors)


static func _t_tokens() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var stage: PickupEventStage = o["stage"]
	var strip := _stripof(o)
	var swap := strip.get_node("%SwapToken") as PanelContainer
	var tip := stage.tooltip()
	var errors: Array = []
	swap.mouse_entered.emit()
	if not tip.is_open() or tip.anchor() != swap or (tip.get_node("%BodyLabel") as Label).text != strip.token_line(true):
		errors.append("hover did not open the tooltip with the swap line")
	swap.mouse_exited.emit()
	if tip.is_open():
		errors.append("the tooltip stays after the mouse left")
	swap.focus_entered.emit()
	if not tip.is_open():
		errors.append("focus did not open the tooltip")
	swap.focus_exited.emit()
	if tip.is_open():
		errors.append("the tooltip stays after the focus left")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	swap.gui_input.emit(tap)
	swap.mouse_exited.emit()
	if not tip.is_open() or not tip.is_pinned():
		errors.append("a tap must pin the tooltip")
	var destroy := strip.get_node("%DestroyToken") as PanelContainer
	destroy.mouse_entered.emit()
	if (tip.get_node("%BodyLabel") as Label).text != strip.token_line(false) or (tip.get_node("%TitleLabel") as Label).text != ItemUiText.BTN_LET_GO:
		errors.append("the destroy token shows another line")
	if not swap.tooltip_text.is_empty() or not destroy.tooltip_text.is_empty():
		errors.append("a native tooltip would show beside the CauseTooltip")
	if swap.focus_mode != Control.FOCUS_ALL or destroy.focus_mode != Control.FOCUS_ALL:
		errors.append("the tokens take no focus")
	return _done(o, errors)


static func _t_cursor() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var layer: PickupFindsLayer = o["layer"]
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	# A motion with no button down never reaches _gui_input through push_input in a headless viewport (proved by a print), so the
	# handler is called directly; the click tests above prove the real-event path of the same function.
	var move := func(p: Vector2) -> void:
		var ev := InputEventMouseMotion.new()
		ev.position = p
		ev.global_position = p
		combat._gui_input(ev)
	move.call(layer.screen_centers()[0])
	if combat.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		errors.append("no hand over a selectable find")
	move.call(Vector2(20, 120))
	if combat.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		errors.append("the hand stays on open board")
	move.call(layer.screen_centers()[0])
	combat.call("_leave_pickup")
	if combat.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		errors.append("the hand stays after the event ended")
	PickupUiHostTests._free(o["fx"])
	var intro := _open("many", "intro", "")
	if intro.has("error"):
		return _fail(intro)
	var c2: CombatBoardScreen = intro["combat"]
	var ev2 := InputEventMouseMotion.new()
	var p2: Vector2 = (intro["layer"] as PickupFindsLayer).screen_centers()[0]
	ev2.position = p2
	ev2.global_position = p2
	c2._gui_input(ev2)
	if c2.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		errors.append("a hand over a find in the intro")
	return _done(intro, errors)


static func _t_floor() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var combat: CombatBoardScreen = o["combat"]
	var errors: Array = []
	var points: Array = []
	var tiles := combat._board as TileMapLayer
	for f: Dictionary in PickupFindsLayer.ground_finds((o["snap"] as Dictionary)["data"]):
		points.append(tiles.map_to_local(Vector2i(int(f["tile"]["col"]), int(f["tile"]["row"]))))
	var want := PickupHitRules.min_zoom(points)
	# A large board lowers the normal minimum under the floor, so the floor is the one that binds.
	combat._board_span_px = Vector2(9000.0, 4500.0)
	combat._pickup_zoom_floor = 0.0
	combat.call("_apply_pickup_zoom_floor", (o["snap"] as Dictionary)["data"])
	var base := combat._min_zoom_for_span(combat._board_span_px)
	if base >= want:
		errors.append("the test board is too small: base %f, floor %f" % [base, want])
	var floor_now := float(combat.camera.get("_min_zoom"))
	if want <= 0.0:
		errors.append("the fixture has fewer than two finds")
	if absf(floor_now - maxf(base, want)) > 0.0001:
		errors.append("camera floor %f, wanted max(%f, %f)" % [floor_now, base, want])
	var nearest := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			nearest = minf(nearest, (points[i] as Vector2).distance_to(points[j] as Vector2))
	if nearest * floor_now < PickupHitRules.TARGET + PickupHitRules.GAP - 0.01 and want > base:
		errors.append("at the floor the nearest finds are %f px apart" % (nearest * floor_now))
	combat.camera.zoom = Vector2(want * 1.5, want * 1.5)
	combat.camera.call("_zoom_by", 0.01, Vector2(640, 360))
	if combat.camera.zoom.x < floor_now - 0.0001:
		errors.append("the camera zoomed below the floor: %f" % combat.camera.zoom.x)
	combat.call("_leave_pickup")
	if absf(float(combat.camera.get("_min_zoom")) - base) > 0.0001:
		errors.append("leaving did not restore the normal minimum: %f vs %f" % [float(combat.camera.get("_min_zoom")), base])
	return _done(o, errors)


static func _t_theme() -> Dictionary:
	var theme := load("res://assets/theme/LivingTreeSystem.tres") as Theme
	var errors: Array = []
	if not theme.has_stylebox("panel", &"PickupCardArrow") or theme.get_type_variation_base(&"PickupCardArrow") != &"Panel" \
			or theme.get_type_variation_base(&"PayoutTooltipArrow") != &"Panel":
		errors.append("PickupCardArrow must be a Panel variation like PayoutTooltipArrow")
	else:
		var arrow := theme.get_stylebox("panel", &"PickupCardArrow") as StyleBoxFlat
		var card := theme.get_stylebox("panel", &"ItemDetailsPanel") as StyleBoxFlat
		if arrow.bg_color != card.bg_color or arrow.border_color != card.border_color:
			errors.append("the arrow uses another fill or border than the card")
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_separation() -> Dictionary:
	var o := _open()
	if o.has("error"):
		return _fail(o)
	var box := _stripof(o).get_node("Panel/Box") as VBoxContainer
	var errors: Array = []
	if box.get_theme_constant("separation") != 8:
		errors.append("strip box separation %d" % box.get_theme_constant("separation"))
	return _done(o, errors)


static func _t_scan() -> Dictionary:
	var errors: Array = []
	for path: String in _NEW_FILES:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("%s unreadable" % path)
		for word: String in _BANNED_WORDS:
			if text.contains(word):
				errors.append("%s contains %s" % [path, word])
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


# ── Shared component (inventory_ui) ─────────────────────────────────────────

static func _mount_host(host: Control) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var root: Node = tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if root == null:
		return false
	root.add_child(host)
	return true


static func _t_tile_no_ring() -> Dictionary:
	var tile := (load("res://ui/components/ItemTile.tscn") as PackedScene).instantiate() as Button
	var host := Control.new()
	host.add_child(tile)
	if not _mount_host(host):
		host.free()
		return { "ok": false, "error": "no UISnapshotRenderer host" }
	var errors: Array = []
	var row := { "kind": "gear", "name": "Test gear", "grade": "g2", "mark_index": 1 }
	tile.setup(row)
	tile.set_selected(true)
	var ring := tile.get_node("%SelectedRing") as Panel
	if tile.ring or not ring.visible or ring.theme_type_variation != &"ItemTileSelected":
		errors.append("a plain tile selects with %s" % ring.theme_type_variation)
	tile.set_selected(false)
	tile.grab_focus()
	if ring.visible:
		errors.append("focus shows a ring on a tile without the ring option")
	tile.release_focus()
	tile.setup(row, { "box": "pack" })
	tile.set_selected(true)
	if ring.theme_type_variation != &"ItemTileSelectedDark":
		errors.append("a pack tile selects with %s" % ring.theme_type_variation)
	tile.setup(row, { "ring": true })
	tile.set_selected(true)
	if not tile.ring or ring.theme_type_variation != &"ItemTileSelectedDark":
		errors.append("the ring option gives %s" % ring.theme_type_variation)
	host.free()
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }


static func _t_one_block() -> Dictionary:
	var errors: Array = []
	var panels := InventoryPanelsScene.instantiate()
	var block_in_panels := panels.get_node("%DetailsBlock") as ItemDetailsBlock
	var card := (load("res://ui/screens/combat/PickupDetailsCard.tscn") as PackedScene).instantiate()
	var block_in_card := card.get_node("%Block") as ItemDetailsBlock
	const BLOCK := "res://ui/components/ItemDetailsBlock.tscn"
	if block_in_panels.scene_file_path != BLOCK or block_in_card.scene_file_path != BLOCK:
		errors.append("the blocks come from %s and %s, wanted %s" % [block_in_panels.scene_file_path, block_in_card.scene_file_path, BLOCK])
	var host := Control.new()
	host.add_child(panels)
	host.add_child(card)
	if not _mount_host(host):
		host.free()
		return { "ok": false, "error": "no UISnapshotRenderer host" }
	var row := { "kind": "gear", "name": "Test gear", "grade": "g2", "mark_index": 1 }
	block_in_panels.show_row(row, "w", { "box": "pack", "bed": 88 })
	block_in_card.show_row(row, "w", { "box": "pack", "bed": 88 })
	for label in ["NameLabel", "KindLabel", "GradeLabel", "CountLabel", "WhereLabel"]:
		if (block_in_panels.get_node("%" + label) as Label).text != (block_in_card.get_node("%" + label) as Label).text:
			errors.append("%s differs between the panels and the card" % label)
	host.free()
	return { "ok": errors.is_empty(), "error": "; ".join(errors) }
