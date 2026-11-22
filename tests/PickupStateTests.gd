# res://tests/PickupStateTests.gd
# V2-ITEM-001b step C6: the finds cap and the take flag in the seam, the event record `stage.pickup` and its
# stamp, the one swap per path, and `InventoryRules.clear_path_marks` at the three path ends.
# The inventory cfg is the test cfg (InventoryServiceTests._cfg) plus the real `pick` block, a finds chance of
# 100% per slot (so the count equals the cap) and one cap band. Nothing here is wired into FlowRuntime.

class_name PickupStateTests
extends RefCounted

const _SIT := "s0"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_state/no_finds_or_a_loss_opens_nothing_and_writes_nothing", Callable(PickupStateTests, "_t_gate"))
	runner.register_test("pickup_state/open_follows_the_plan_order", Callable(PickupStateTests, "_t_order"))
	runner.register_test("pickup_state/second_open_returns_the_stored_record_and_writes_nothing", Callable(PickupStateTests, "_t_exactly_once"))
	runner.register_test("pickup_state/seam_refuses_finds_past_the_cap", Callable(PickupStateTests, "_t_over_cap"))
	runner.register_test("pickup_state/seam_take_false_writes_nothing", Callable(PickupStateTests, "_t_take_flag"))
	runner.register_test("pickup_state/pack_room_is_read_before_the_seam", Callable(PickupStateTests, "_t_room_before_seam"))
	runner.register_test("pickup_state/seam_refusal_taken_matches_the_rows", Callable(PickupStateTests, "_t_refuse_then_next"))
	runner.register_test("pickup_state/frozen_chooser_takes_nothing", Callable(PickupStateTests, "_t_frozen"))
	runner.register_test("pickup_state/one_swap_per_path_drops_a_held_piece", Callable(PickupStateTests, "_t_swap_once"))
	runner.register_test("pickup_state/swap_drops_a_gathered_row", Callable(PickupStateTests, "_t_swap_drops_row"))
	runner.register_test("pickup_state/path_marks_cleared_at_path_end", Callable(PickupStateTests, "_t_clear_path_end"))
	runner.register_test("pickup_state/path_marks_cleared_at_early_leave", Callable(PickupStateTests, "_t_clear_early_leave"))
	runner.register_test("pickup_state/path_marks_cleared_at_defeat", Callable(PickupStateTests, "_t_clear_defeat"))
	runner.register_test("pickup_state/leave_settlement_same_with_and_without_an_event", Callable(PickupStateTests, "_t_leave_unchanged"))
	runner.register_test("pickup_state/swap_drops_a_find_of_this_event_back_to_the_field", Callable(PickupStateTests, "_t_swap_drops_own_find"))
	runner.register_test("pickup_state/stamp_key_is_run_count_and_situation", Callable(PickupStateTests, "_t_stamp_key_halves"))
	runner.register_test("pickup_state/shipping_cfg_caps_the_seam_at_two", Callable(PickupStateTests, "_t_shipping_cap"))
	runner.register_test("pickup_state/seam_cap_counts_rows_first_so_a_repeat_writes_nothing", Callable(PickupStateTests, "_t_cap_repeat_any_order"))
	runner.register_test("pickup_state/chooser_view_judgment_and_composure_by_hand", Callable(PickupStateTests, "_t_chooser_view_numbers"))
	runner.register_test("pickup_state/nobody_standing_opens_nothing", Callable(PickupStateTests, "_t_nobody_standing"))
	runner.register_test("pickup_state/fallen_party_ids_use_ids_not_names", Callable(PickupStateTests, "_t_fallen_ids"))
	runner.register_test("pickup_state/every_find_refused_opens_nothing", Callable(PickupStateTests, "_t_all_refused"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _norm(v: Variant) -> String:
	return ItemPacksTests._norm(v)


## An ItemPacksTests context (realm.01, scale 1.0, five Echoes e0..e4) with the pickup cfg. `finds_cap` < 1 leaves
## the cap key out.
static func _ctx(finds_cap: int, pack: int, realm_seed: int = ItemPacksTests._SEED_NONE) -> FlowContext:
	var ctx := ItemPacksTests._ctx(realm_seed, 8, pack)
	var real := ConfigService.new()
	real.load_balance()
	var inv := InventoryServiceTests._cfg(8, pack, 5)
	inv["pick"] = ConfigService.get_inventory_cfg(real)["pick"]
	inv["finds_chance"] = { "base_by_slot_pct": [100, 100, 100, 100, 100, 100], "max_pct": 100,
		"rank_modifier_pct": { "C": 0, "B": 0, "A": 0, "S": 0 } }
	if finds_cap > 0:
		inv["finds_cap_by_realm_scale"] = [{ "scale": 1.0, "cap": finds_cap }]
	ctx.config_service.set("inv", inv)
	ctx.logger.set_level(StructuredLogger.LEVEL_DEBUG)
	return ctx


static func _finds(type_ids: Array) -> Array:
	var out: Array = []
	for i in type_ids.size():
		out.append(ItemPacksTests._find("f%d" % i, str(type_ids[i])))
	return out


static func _open(ctx: FlowContext, finds: Array, rank: String = "S", fallen: Array = [], sit: String = _SIT,
		t: int = 10) -> Dictionary:
	return PickupEventService.open_after_win(ctx, sit, rank, fallen, FlowStateIds.STAGE_EXPLORE, finds, t)


static func _log_types(ctx: FlowContext) -> Array:
	return ctx.logger.get_logs().map(func(e): return str((e as Dictionary)["type"]))


static func _econ(ctx: FlowContext) -> String:
	return _norm(ctx.save_data["economy"])


# ---------------------------------------------------------------------------
# Gate and order
# ---------------------------------------------------------------------------

static func _t_gate() -> Dictionary:
	var m: Array = []
	for c in [["no finds", [], "S"], ["a loss", _finds(["ph_weapon_a"]), "F"]]:
		var ctx := _ctx(2, 4)
		var before := _norm(ctx.save_data)
		var got := _open(ctx, c[1], c[2])
		if not got.is_empty() or _norm(ctx.save_data) != before or ctx.save_request:
			m.append("%s: record %s, save changed %s, save request %s" % [c[0], str(got),
				str(_norm(ctx.save_data) != before), str(ctx.save_request)])
		if ItemPacksTests._stage(ctx).has(PickupEventService.STAGE_KEY) or ItemPacksTests._stage(ctx).has(PickupEventService.SWAP_KEY):
			m.append("%s: a pickup key was written" % c[0])
	return _result(m)


static func _t_order() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(3, 4)
	# Give every Echo a taste (archetype valiant: gear first). Taste alone may still tie finds, so the search below picks a listing whose order differs.
	for e in ctx.save_data["sanctum"]["roster"]:
		(e as Dictionary)["archetype_birth"] = "valiant"
	var standing := ["e0", "e1", "e2", "e3", "e4"]
	var drawn := PickupChooser.draw(0, "stage.0", 0, _SIT, standing)
	var data := ConfigService.get_balance_data(ctx.config_service)
	var party := SanctumService.get_party_actors_static(ctx.save_data)
	var chooser := PickupEventService._chooser_view(ctx.save_data, data, party, standing, str(drawn["chooser_id"]))
	# The fixture chooser has no Judgment and little taste, so at the shipping sense_base 0.0 (D-67) several finds can
	# tie and the pick order would be the find order. Take the first listing of the four types whose pick order
	# differs from the find order, so the row order can show the plumbing.
	var pool := ["ph_weapon_a", "ph_relic_a", "ph_consumable_a", "ph_armor_a"]
	var finds: Array = []
	var want_order: Array = []
	for a in 4:
		for b in 4:
			for c in 4:
				if a == b or b == c or a == c or not finds.is_empty():
					continue
				var cand := _finds([pool[a], pool[b], pool[c], pool[6 - a - b - c]])
				var o: Array = PickupPick.order(chooser, cand.slice(0, 3), PickupPick.ctx_from(data)).map(
					func(f): return str(f["find_id"]))
				if str(o) != str(["f0", "f1", "f2"]):
					finds = cand
					want_order = o
	if finds.is_empty():
		return { "ok": false, "error": "test setup: no listing of the four types gives a pick order unlike the find order" }
	var rec := _open(ctx, finds)
	if rec.is_empty():
		return { "ok": false, "error": "no event opened" }
	var inv_cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	var n := FindsRules.roll_count(inv_cfg, 0, "stage.0", 0, _SIT, 1.0, "S")
	if n != 3 or (rec["finds"] as Array).size() != n:
		m.append("roll count %d, finds %d: the event must offer the first `count` finds" % [n, (rec["finds"] as Array).size()])
	if str(rec["chooser"]) != str(drawn["chooser_id"]) or str(rec["standing_ids"]) != str(standing):
		m.append("chooser %s of %s, expected %s" % [rec["chooser"], str(rec["standing_ids"]), drawn["chooser_id"]])
	if str(rec["order"]) != str(want_order) or str(rec["taken"]) != str(want_order):
		m.append("order %s taken %s, expected %s" % [str(rec["order"]), str(rec["taken"]), str(want_order)])
	var rows: Array = ItemPacksTests._ids_of_rows(ctx).filter(func(id): return str(id).begins_with("item:"))
	if str(rows) != str(want_order.map(func(id): return "item:%s:%s" % [_SIT, id])):
		m.append("rows %s: the seam must get the finds in pick order" % str(rows))
	if str(rec["case"]) != "C1" or str(rec["reaction"]) != "plus" or bool(rec["frozen"]) or not (rec["swap"] as Dictionary).is_empty():
		m.append("case %s reaction %s frozen %s swap %s" % [rec["case"], rec["reaction"], rec["frozen"], rec["swap"]])
	var keys: Array = rec.keys()
	keys.sort()
	var want_keys := ["case", "chooser", "fallen_names", "finds", "free", "frozen", "left", "order", "phase", "rank",
		"reaction", "realm_scale", "reason", "return_to", "run_count", "situation_id", "standing_ids", "swap", "taken",
		"tried", "win_t"]
	if str(keys) != str(want_keys):
		m.append("record keys %s" % str(keys))
	var types := _log_types(ctx)
	if types.find("economy.earnings.items") < 0 or types.find("economy.earnings.items") > types.find("inventory.pickup.open"):
		m.append("log order %s: the seam runs before the record is written" % str(types))
	if not ctx.save_request:
		m.append("no save request after the record was written")
	return _result(m)


static func _t_exactly_once() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var econ := _econ(ctx)
	var rec := _open(ctx, _finds(["ph_weapon_a", "ph_relic_a"]))
	if rec.is_empty():
		return { "ok": false, "error": "no event opened" }
	var stored := _norm(ctx.save_data)
	ctx.save_request = false
	ctx.logger.clear()
	var again := _open(ctx, _finds(["ph_weapon_a", "ph_relic_a"]), "S", [], _SIT, 99)
	if _norm(again) != _norm(rec):
		m.append("second open %s, expected the stored record" % str(again))
	if _norm(ctx.save_data) != stored or ctx.save_request or not ctx.logger.get_logs().is_empty():
		m.append("second open wrote, requested a save or logged: %s" % str(_log_types(ctx)))
	if int(again["win_t"]) != 10:
		m.append("win_t %d: the stamp keeps the first tick" % int(again["win_t"]))
	for fid in rec["taken"]:
		if not EarningsService.has_row(ItemPacksTests._stage(ctx), "item:%s:%s" % [_SIT, fid]):
			m.append("no row item:%s:%s" % [_SIT, fid])
	if _econ(ctx) != econ:
		m.append("the event changed the currency")
	# Another run of the Realm is another key: the event opens again.
	(ctx.save_data["realms"]["realm.01"] as Dictionary)["run_count"] = 1
	if _open(ctx, [ItemPacksTests._find("r1", "ph_armor_a")]).is_empty():
		m.append("a new run_count did not open a new event")
	return _result(m)


# ---------------------------------------------------------------------------
# The seam
# ---------------------------------------------------------------------------

static func _t_over_cap() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 8)
	var finds: Array = [ItemPacksTests._find("x", "nope")] + _finds(["ph_weapon_a", "ph_relic_a", "ph_armor_a", "ph_charm_a"])
	var got := ActiveStageService.record_found_items(ctx, _SIT, finds, 4)
	var want := { "taken": ["f0", "f1"], "left": [], "refused": [{ "find_id": "x", "reason_key": "unknown_kind" },
		{ "find_id": "f2", "reason_key": "over_cap" }, { "find_id": "f3", "reason_key": "over_cap" }] }
	if str(got) != str(want):
		m.append("result %s, expected %s" % [str(got), str(want)])
	var warns: Array = ctx.logger.get_logs().filter(func(e): return str(e["type"]) == "economy.earnings.over_cap")
	if warns.size() != 1 or int((warns[0] as Dictionary)["data"]["refused"]) != 2:
		m.append("over_cap log %s" % str(warns))
	# No cap key: no cap (test configs).
	var free_ctx := _ctx(0, 8)
	if (ActiveStageService.record_found_items(free_ctx, _SIT, finds, 4)["taken"] as Array).size() != 4:
		m.append("no cap key refused a find")
	return _result(m)


static func _t_take_flag() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(3, 4)
	var before := _norm(ItemPacksTests._stage(ctx))
	var got := ActiveStageService.record_found_items(ctx, _SIT, _finds(["ph_weapon_a", "ph_relic_a"]), 4, false)
	if str(got) != str({ "taken": [], "left": ["f0", "f1"], "refused": [] }):
		m.append("take false: %s" % str(got))
	if _norm(ItemPacksTests._stage(ctx)) != before or ctx.save_request:
		m.append("take false wrote a row or requested a save")
	return _result(m)


static func _t_room_before_seam() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	ItemPacksTests._hold(ctx, 2)
	var rec := _open(ctx, _finds(["ph_relic_a", "ph_armor_a"]))
	if str(rec.get("case")) != "C3" or str(rec.get("reaction")) != "plus" or int(rec.get("free", -1)) != 2 \
			or (rec.get("taken", []) as Array).size() != 2:
		m.append("case %s reaction %s free %s taken %s: room must be read before the seam writes" % [rec.get("case"),
			rec.get("reaction"), rec.get("free"), str(rec.get("taken"))])
	return _result(m)


static func _t_refuse_then_next() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(3, 3)
	ItemPacksTests._hold(ctx, 2)
	var finds: Array = [ItemPacksTests._find("x", "nope")] + _finds(["ph_relic_a", "ph_armor_a"])
	var rec := _open(ctx, finds)
	if rec.is_empty():
		return { "ok": false, "error": "no event opened" }
	var order: Array = rec["order"]
	if order.has("x") or (rec["finds"] as Array).size() != 2:
		m.append("the refused find is still in the event: order %s" % str(order))
	if str(rec["taken"]) != str([order[0]]) or str(rec["left"]) != str(["f0", "f1"].filter(func(id): return id != order[0])):
		m.append("taken %s left %s for order %s" % [str(rec["taken"]), str(rec["left"]), str(order)])
	var rows: Array = ItemPacksTests._ids_of_rows(ctx).filter(func(id): return str(id).begins_with("item:"))
	if str(rows) != str(["item:%s:%s" % [_SIT, order[0]]]):
		m.append("rows %s, expected what the record says was taken" % str(rows))
	if str(rec["case"]) != "C4" or str(rec["tried"]) != str(order[1]):
		m.append("case %s tried %s" % [rec["case"], rec["tried"]])
	if _log_types(ctx).has("inventory.pickup.taken_mismatch"):
		m.append("the case and the seam disagree")
	return _result(m)


static func _t_frozen() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var roster: Array = ctx.save_data["sanctum"]["roster"]
	(roster[2] as Dictionary)["emotion"] = { "morale_current": 50, "fear_current": 95 }
	var before := _norm(ItemPacksTests._stage(ctx)["earnings"])
	var rec := _open(ctx, _finds(["ph_weapon_a", "ph_relic_a"]), "S", ["e0", "e1", "e3", "e4"])
	if str(rec.get("chooser")) != "e2" or not bool(rec.get("frozen")) or str(rec.get("reason")) != "froze" \
			or str(rec.get("case")) != "frozen" or str(rec.get("reaction")) != "none":
		m.append("record %s" % str(rec))
	if not (rec.get("taken", [0]) as Array).is_empty() or str(rec.get("left")) != str(["f0", "f1"]) or str(rec.get("tried")) != "":
		m.append("taken %s left %s tried %s" % [str(rec.get("taken")), str(rec.get("left")), str(rec.get("tried"))])
	if _norm(ItemPacksTests._stage(ctx)["earnings"]) != before:
		m.append("a frozen chooser wrote an item row")
	if str(rec.get("fallen_names")) != str(["Echo 0", "Echo 1", "Echo 3", "Echo 4"]):
		m.append("fallen_names %s" % str(rec.get("fallen_names")))
	if not ctx.save_request or not ctx.save_request_reason.contains("inventory.pickup.open"):
		m.append("a frozen event requested no save: reason '%s'" % ctx.save_request_reason)
	var swap := PickupEventService.commit_swap(ctx, "f0", "x", 11)
	if str(swap["reason_key"]) != "frozen":
		m.append("swap after a freeze: %s" % str(swap))
	return _result(m)


# ---------------------------------------------------------------------------
# Swap
# ---------------------------------------------------------------------------

static func _t_swap_once() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 2)
	ItemPacksTests._hold(ctx, 2)
	var econ := _econ(ctx)
	var rec := _open(ctx, _finds(["ph_charm_a", "ph_relic_a"]))
	if str(rec.get("case")) != "C5":
		return { "ok": false, "error": "test setup: case %s, expected a full pack" % str(rec.get("case")) }
	ctx.save_request = false
	ctx.save_request_reason = ""
	var got := PickupEventService.commit_swap(ctx, "f1", "it.1", 11)
	var stage := ItemPacksTests._stage(ctx)
	if not ctx.save_request or not ctx.save_request_reason.contains("inventory.pickup.swap"):
		m.append("the swap requested no save: reason '%s'" % ctx.save_request_reason)
	if not bool(got["ok"]) or str(ItemPacksTests._pack_ids(ctx)) != str(["it.2"]):
		m.append("swap %s, pack %s" % [str(got), str(ItemPacksTests._pack_ids(ctx))])
	if str(ItemPacksTests._held_fates(ctx).get("it.1")) != "swap:0:%s/lost/swapped" % _SIT:
		m.append("held fates %s" % str(ItemPacksTests._held_fates(ctx)))
	if not EarningsService.has_row(stage, "item:%s:f1" % _SIT) or not PickupEventService.swap_used(stage):
		m.append("the find row or swap_used is missing")
	var rec2 := PickupEventService.record_of(stage)
	if not (rec2["taken"] as Array).has("f1") or (rec2["left"] as Array).has("f1") \
			or str((rec2["swap"] as Dictionary).get("dropped_id")) != "it.1":
		m.append("record after the swap %s" % str(rec2))
	if PickupEventService.commit_swap(ctx, "f0", "it.2", 12)["reason_key"] != "used":
		m.append("a second swap in the same event was not refused")
	# A later event on the same path: the swap stays spent.
	_open(ctx, [ItemPacksTests._find("h0", "ph_armor_a")], "S", [], "s1", 20)
	if PickupEventService.commit_swap(ctx, "h0", "it.2", 21)["reason_key"] != "used":
		m.append("a second event on the path got another swap")
	if _econ(ctx) != econ:
		m.append("the swap changed the currency")
	return _result(m)


static func _t_swap_drops_row() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 2)
	ItemPacksTests._hold(ctx, 1)
	ItemPacksTests._add_rows(ctx, "s9", ["old"], "ph_armor_a")
	var rec := _open(ctx, _finds(["ph_charm_a", "ph_relic_a"]))
	if str(rec.get("case")) != "C5":
		return { "ok": false, "error": "test setup: case %s, expected a full pack" % str(rec.get("case")) }
	var got := PickupEventService.commit_swap(ctx, "f0", "item:s9:old", 11)
	if not bool(got["ok"]):
		m.append("swap %s" % str(got))
	if str(ItemPacksTests._row_fates(ctx).get("item:s9:old")) != "-L/lost/swapped":
		m.append("row fates %s" % str(ItemPacksTests._row_fates(ctx)))
	if str(ItemPacksTests._pack_ids(ctx)) != str(["it.1"]) or not EarningsService.has_row(ItemPacksTests._stage(ctx), "item:%s:f0" % _SIT):
		m.append("pack %s; the find row is missing" % str(ItemPacksTests._pack_ids(ctx)))
	return _result(m)


# ---------------------------------------------------------------------------
# clear_path_marks at the three path ends
# ---------------------------------------------------------------------------

static func _mark(stage: Dictionary) -> void:
	stage["discard_used"] = true
	stage[PickupEventService.SWAP_KEY] = true
	stage[PickupEventService.STAGE_KEY] = { "situation_id": _SIT, "run_count": 0 }


static func _left_marks(stage: Dictionary) -> Array:
	return ["discard_used", PickupEventService.SWAP_KEY, PickupEventService.STAGE_KEY].filter(func(k): return stage.has(k))


## StageSettlementService.settle (path end).
static func _t_clear_path_end() -> Dictionary:
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 3)
	_mark(ItemPacksTests._stage(ctx))
	if ItemPacksTests._settle_path(ctx, 3).is_empty():
		return { "ok": false, "error": "test setup: the settlement paid nothing, so it did not reach the clear" }
	var left := _left_marks(ItemPacksTests._stage(ctx))
	return _result([] if left.is_empty() else ["path end left %s" % str(left)])


## VentureController.handle_return_home, escape succeeds (early leave).
static func _t_clear_early_leave() -> Dictionary:
	var env := InventoryPathTests._path_env("pickup_state_leave")
	if not bool(env.get("ok", false)):
		return env
	_mark(InventoryActionTests._stage_of(env))
	if not InventoryActionTests._force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	(env["rt"] as FlowRuntime).dispatch({ "type": "stage.return_home" })
	var stage := InventoryActionTests._stage_of(env)
	var m: Array = []
	if str((stage["explore_map"] as Dictionary).get("party_state", "")) != "escaped":
		m.append("the escape did not succeed")
	if not _left_marks(stage).is_empty():
		m.append("early leave left %s" % str(_left_marks(stage)))
	return _result(m)


## ActiveStageService.lose_unsettled_packs (defeat).
static func _t_clear_defeat() -> Dictionary:
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 3)
	_mark(ItemPacksTests._stage(ctx))
	ActiveStageService.lose_unsettled_packs(ctx, 3)
	var left := _left_marks(ItemPacksTests._stage(ctx))
	return _result([] if left.is_empty() else ["defeat left %s" % str(left)])


# ---------------------------------------------------------------------------
# The new streams never move a leave settlement
# ---------------------------------------------------------------------------

## Two saves, same seed ("some", so every item draw matters). A opens an event; B writes the same rows through the
## seam with no event. The leave result, the row and held fates, the leave logs and the save (without
## `stage.pickup`) must be equal.
static func _t_leave_unchanged() -> Dictionary:
	var m: Array = []
	var a := _ctx(2, 4, ItemPacksTests._SEED_SOME)
	var b := _ctx(2, 4, ItemPacksTests._SEED_SOME)
	for c in [a, b]:
		ItemPacksTests._hold(c, 1)
	var finds := _finds(["ph_weapon_a", "ph_relic_a"])
	var rec := _open(a, finds)
	if (rec.get("taken", []) as Array).size() != 2:
		return { "ok": false, "error": "test setup: event %s" % str(rec) }
	var ordered: Array = (rec["order"] as Array).map(func(id): return finds[int(str(id).substr(1))])
	ActiveStageService.record_found_items(b, _SIT, ordered, 10)
	var la := ItemPacksTests._leave(a, 30)
	var lb := ItemPacksTests._leave(b, 30)
	if _norm(la["result"]) != _norm(lb["result"]):
		m.append("leave result %s vs %s" % [_norm(la["result"]), _norm(lb["result"])])
	if _norm((la["logger"] as StructuredLogger).get_logs()) != _norm((lb["logger"] as StructuredLogger).get_logs()):
		m.append("the leave logs differ")
	if str(ItemPacksTests._row_fates(a)) != str(ItemPacksTests._row_fates(b)) \
			or str(ItemPacksTests._held_fates(a)) != str(ItemPacksTests._held_fates(b)):
		m.append("fates %s %s vs %s %s" % [ItemPacksTests._row_fates(a), ItemPacksTests._held_fates(a),
			ItemPacksTests._row_fates(b), ItemPacksTests._held_fates(b)])
	ItemPacksTests._stage(a).erase(PickupEventService.STAGE_KEY)
	if _norm(a.save_data) != _norm(b.save_data):
		m.append("the saves differ after the leave")
	return _result(m)


# ---------------------------------------------------------------------------
# QA follow-ups (M1 to M4, L2, L3)
# ---------------------------------------------------------------------------

## M1: the dropped entry is a row of this event. Its find goes back to `left` (find order) and the row is lost.
static func _t_swap_drops_own_find() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	ItemPacksTests._hold(ctx, 3)
	var rec := _open(ctx, _finds(["ph_relic_a", "ph_armor_a"]))
	if str(rec.get("case")) != "C4" or (rec.get("taken", []) as Array).size() != 1:
		return { "ok": false, "error": "test setup: case %s taken %s" % [str(rec.get("case")), str(rec.get("taken"))] }
	var took := str(rec["taken"][0])
	var other := "f1" if took == "f0" else "f0"
	var got := PickupEventService.commit_swap(ctx, other, "item:%s:%s" % [_SIT, took], 11)
	var after := PickupEventService.record_of(ItemPacksTests._stage(ctx))
	if not bool(got["ok"]):
		m.append("swap %s" % str(got))
	if str(after["taken"]) != str([other]) or str(after["left"]) != str([took]):
		m.append("taken %s left %s, expected [%s] and [%s]" % [str(after["taken"]), str(after["left"]), other, took])
	if str(ItemPacksTests._row_fates(ctx).get("item:%s:%s" % [_SIT, took])) != "-L/lost/swapped":
		m.append("row fates %s" % str(ItemPacksTests._row_fates(ctx)))
	if not PickupEventService.swap_used(ItemPacksTests._stage(ctx)):
		m.append("swap_used is not set")
	return _result(m)


## M2: each half of the stamp key opens a new event and replaces the record.
static func _t_stamp_key_halves() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var realm: Dictionary = ctx.save_data["realms"]["realm.01"]
	realm["run_count"] = 1
	_open(ctx, [ItemPacksTests._find("a0", "ph_weapon_a"), ItemPacksTests._find("a1", "ph_relic_a")], "S", [], _SIT, 10)
	realm["run_count"] = 2
	var rec := _open(ctx, [ItemPacksTests._find("b0", "ph_armor_a"), ItemPacksTests._find("b1", "ph_charm_a")], "S", [], _SIT, 20)
	var stored := PickupEventService.record_of(ItemPacksTests._stage(ctx))
	if int(rec.get("run_count", -1)) != 2 or int(stored.get("run_count", -1)) != 2 or int(rec.get("win_t", -1)) != 20 \
			or str((rec.get("finds", []) as Array).map(func(f): return f["find_id"])) != str(["b0", "b1"]):
		m.append("run_count half: returned %s, stored run_count %s" % [str(rec), str(stored.get("run_count"))])
	var ctx2 := _ctx(2, 4)
	_open(ctx2, _finds(["ph_weapon_a"]), "S", [], "s0", 10)
	var rec2 := _open(ctx2, [ItemPacksTests._find("c0", "ph_relic_a")], "S", [], "s1", 20)
	if str(rec2.get("situation_id")) != "s1" or int(rec2.get("run_count", -1)) != 0 \
			or str(PickupEventService.record_of(ItemPacksTests._stage(ctx2)).get("situation_id")) != "s1":
		m.append("situation half: returned %s" % str(rec2))
	return _result(m)


## M3: the shipping inventory cfg (realm.01, scale 1.0, cap 2, pack 4).
static func _t_shipping_cap() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_NONE, 8, 4)
	var real := ConfigService.new()
	real.load_balance()
	ctx.config_service.set("inv", ConfigService.get_inventory_cfg(real))
	var got := ActiveStageService.record_found_items(ctx, _SIT, _finds(["ph_weapon_a", "ph_relic_a", "ph_armor_a", "ph_charm_a"]), 4)
	var want := { "taken": ["f0", "f1"], "left": [], "refused": [{ "find_id": "f2", "reason_key": "over_cap" },
		{ "find_id": "f3", "reason_key": "over_cap" }] }
	if str(got) != str(want):
		m.append("first call %s, expected %s" % [str(got), str(want)])
	var got2 := ActiveStageService.record_found_items(ctx, _SIT,
		[ItemPacksTests._find("g0", "ph_weapon_a"), ItemPacksTests._find("g1", "ph_relic_a")], 5)
	if str(got2["taken"]) != str(["g0", "g1"]):
		m.append("second call %s" % str(got2))
	if ItemPacksTests._ids_of_rows(ctx).filter(func(id): return str(id).begins_with("item:")).size() != 4:
		m.append("rows %s" % str(ItemPacksTests._ids_of_rows(ctx)))
	return _result(m)


## M4: rows of the listed finds use the cap first, wherever they stand, so a repeat in any order writes nothing.
static func _t_cap_repeat_any_order() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var a := ItemPacksTests._find("a", "ph_weapon_a")
	var b := ItemPacksTests._find("b", "ph_relic_a")
	var c := ItemPacksTests._find("c", "ph_armor_a")
	var got := ActiveStageService.record_found_items(ctx, _SIT, [a, b, c], 4)
	if str(got) != str({ "taken": ["a", "b"], "left": [], "refused": [{ "find_id": "c", "reason_key": "over_cap" }] }):
		m.append("call 1 %s" % str(got))
	var rows := _norm(ItemPacksTests._stage(ctx)["earnings"])
	var got2 := ActiveStageService.record_found_items(ctx, _SIT, [c, a, b], 5)
	if not (got2["taken"] as Array).is_empty() or _norm(ItemPacksTests._stage(ctx)["earnings"]) != rows:
		m.append("call 2 in another order %s wrote a row" % str(got2))
	if str(got2["refused"]) != str([{ "find_id": "c", "reason_key": "over_cap" }]):
		m.append("call 2 refused %s" % str(got2["refused"]))
	ctx.save_request = false
	var got3 := ActiveStageService.record_found_items(ctx, _SIT, [b], 6)
	if str(got3) != str({ "taken": [], "left": [], "refused": [] }) or ctx.save_request \
			or _norm(ItemPacksTests._stage(ctx)["earnings"]) != rows:
		m.append("a repeat below the cap: %s" % str(got3))
	return _result(m)


## L2: Judgment and composure of `_chooser_view` against hand numbers, with a hand-made cfg.
## rank 5 of 9: rank_strength 0.5. Bonds: friend e1 (standing), friend e2 (fallen): support 1 / 4 = 0.25.
## Judgment = 0.5 x 0.5 + 0.25 x 0.4 = 0.35 (0.45 if the fallen friend counted).
## Traits 60/40/50: level 0.5, evenness 0.8, balance 0.5 x (1 - 0.5 x 0.2) = 0.45. Spike (20 - 0) / 100 = 0.2.
## Composure = 0.5 x 0.6 + 0.45 x 0.4 - 0.2 x 1.0 = 0.28 (no dread weight, ceiling 1).
static func _t_chooser_view_numbers() -> Dictionary:
	var m: Array = []
	var data := {
		"sanctum": { "bond_thresholds": { "rival_max": -30, "friend_min": 30 } },
		"maturity_expression": { "rank_strength_scale": { "max_rank": 9 }, "autonomy_outputs": {
			"judgment": { "rank_strength_weight": 0.5, "bond_support_weight": 0.4 },
			"composure": { "rank_strength_weight": 0.6, "trait_balance_weight": 0.4, "situational_spike_weight": 1.0 },
			"bond_scale": { "max_bonds": 4 }, "trait_balance": { "evenness_weight": 0.5 } } },
	}
	var echo := { "id": "e0", "name": "Echo 0", "rank": 5, "traits": { "courage": 60, "wisdom": 40, "faith": 50 },
		"emotion": { "morale_current": 50, "fear_current": 20, "fear_base": 0 } }
	var party: Array = [EchoActor.from_echo(echo), EchoActor.from_echo({ "id": "e1" }), EchoActor.from_echo({ "id": "e2" })]
	var save := { "sanctum": { "bonds": [{ "actor_a": "e0", "actor_b": "e1", "strength": 50 },
		{ "actor_a": "e2", "actor_b": "e0", "strength": 50 }] } }
	var view := PickupEventService._chooser_view(save, data, party, ["e0", "e1"], "e0")
	if absf(float(view["judgment"]) - 0.35) > 1e-9 or absf(float(view["composure"]) - 0.28) > 1e-9:
		m.append("judgment %.12f composure %.12f, expected 0.35 and 0.28" % [float(view["judgment"]), float(view["composure"])])
	if str((view["actor"] as Dictionary).get("id")) != "e0":
		m.append("actor %s" % str(view["actor"]))
	return _result(m)


## L3: every party Echo fell.
static func _t_nobody_standing() -> Dictionary:
	var ctx := _ctx(2, 4)
	var before := _norm(ctx.save_data)
	var got := _open(ctx, _finds(["ph_weapon_a"]), "S", ["e0", "e1", "e2", "e3", "e4"])
	if not got.is_empty() or _norm(ctx.save_data) != before or ctx.save_request:
		return { "ok": false, "error": "record %s, save changed %s" % [str(got), str(_norm(ctx.save_data) != before)] }
	return _result([])


## L3: the seam refuses every find: no event, no stamp, no row.
## Codex review on PR 132: two Echoes can share a name, so the fallen set must follow ids.
static func _t_fallen_ids() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(3, 4)
	var roster: Array = ctx.save_data["sanctum"]["roster"]
	(roster[1] as Dictionary)["name"] = str((roster[0] as Dictionary)["name"])
	var shared := str((roster[0] as Dictionary)["name"])
	var stage := ItemPacksTests._stage(ctx)
	stage["lost_echo_names"] = [shared]
	stage["lost_echo_ids"] = ["e0"]
	var got := PickupEventService.fallen_party_ids(ctx, [])
	if str(got) != str(["e0"]):
		m.append("two Echoes share the name %s, only e0 fell: got %s" % [shared, str(got)])
	# A stage saved before the id field: an ambiguous name is not guessed, a unique one still counts.
	stage.erase("lost_echo_ids")
	if not PickupEventService.fallen_party_ids(ctx, []).is_empty():
		m.append("a legacy stage with an ambiguous name must guess nobody: %s" % str(PickupEventService.fallen_party_ids(ctx, [])))
	stage["lost_echo_names"] = [str((roster[3] as Dictionary)["name"])]
	if str(PickupEventService.fallen_party_ids(ctx, [])) != str(["e3"]):
		m.append("a legacy stage with a unique name: got %s" % str(PickupEventService.fallen_party_ids(ctx, [])))
	# The fight just played: two dead Echoes with the same name are both recorded by id.
	stage.erase("lost_echo_names")
	var actors: Array = [
		{ "faction": "echo", "id": "e0", "name": shared, "is_dead": true },
		{ "faction": "echo", "id": "e1", "name": shared, "is_dead": true },
		{ "faction": "echo", "id": "e2", "name": "Echo 2", "is_dead": false },
		{ "faction": "echo", "id": "ally", "name": "Ally", "is_dead": true, "is_ally": true },
	]
	if str(ActiveStageService.lost_echo_ids_with(ctx, actors)) != str(["e0", "e1"]):
		m.append("dead ids %s" % str(ActiveStageService.lost_echo_ids_with(ctx, actors)))
	return _result(m)


static func _t_all_refused() -> Dictionary:
	var ctx := _ctx(2, 4)
	var before := _norm(ctx.save_data)
	var got := _open(ctx, [ItemPacksTests._find("x", "nope"), ItemPacksTests._find("y", "nope")])
	if not got.is_empty() or _norm(ctx.save_data) != before \
			or ItemPacksTests._stage(ctx).has(PickupEventService.STAGE_KEY):
		return { "ok": false, "error": "record %s, save changed %s" % [str(got), str(_norm(ctx.save_data) != before)] }
	return _result([])
