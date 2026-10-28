# res://tests/ItemPacksTests.gd
# V2-ITEM-001a step 4: item rows in the packs. The found-items seam, the early-leave draws for item rows and
# held pieces, the defeat loss and the path-end bank.
# Tests use their own inventory cfg (InventoryServiceTests._cfg) and the placeholder fixture. They never read
# the PROVISIONAL numbers (D-25). Realm seeds and their pinned draws:
#   stream `stage.settle.stage.0.0.0`: seed 0 rolls 0 (none), seed 1 rolls 57 (some), seed 2 rolls 90 (all).
#   stream `stage.settle.stage.0.0.1`: seed 7 rolls 63 (some). Seed 7 rolls 99 (all) on `...0.0.0`.
#   "some" keeps an entry when its own draw is below 50. Seed 1, stream `...0.0.0`: row draws for
#   item:s0:0..3 are 14, 2, 65, 67; held draws for it.1..it.4 are 69, 33, 66, 90.
#   Seed 7, stream `...0.0.1`: held draws for it.1..it.4 are 59, 42, 85, 54.
# Report: docs/stories/v2-item-001/step4-packs-rules.md

class_name ItemPacksTests
extends RefCounted

const _SEED_NONE := 0
const _SEED_SOME := 1
const _SEED_ALL := 2
const _SEED_REPEAT := 7


class _Cfg extends ConfigService:
	var inv: Dictionary = {}

	func get_balance() -> Dictionary:
		var b := super.get_balance()
		var d: Dictionary = b.get("data", {})
		d["inventory"] = inv.duplicate(true)
		b["data"] = d
		return b


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("item_packs/earnings_item_rows", Callable(ItemPacksTests, "_t_earnings_rows"))
	runner.register_test("item_packs/found_items_fit_and_exceed_the_room", Callable(ItemPacksTests, "_t_found_items"))
	runner.register_test("item_packs/plan_counts_items_and_held_pieces", Callable(ItemPacksTests, "_t_plan_counts"))
	runner.register_test("item_packs/item_only_pack_draws_the_outcome_roll", Callable(ItemPacksTests, "_t_item_only_roll"))
	runner.register_test("item_packs/outcome_stream_equals_the_item_free_value", Callable(ItemPacksTests, "_t_outcome_stream"))
	runner.register_test("item_packs/some_draws_do_not_depend_on_order_or_other_entries", Callable(ItemPacksTests, "_t_draw_independence"))
	runner.register_test("item_packs/held_pieces_are_rolled", Callable(ItemPacksTests, "_t_held_rolled"))
	runner.register_test("item_packs/repeat_leave_draws_held_pieces_again", Callable(ItemPacksTests, "_t_repeat_leave"))
	runner.register_test("item_packs/survivor_stays_held_when_the_sanctum_is_full", Callable(ItemPacksTests, "_t_survivor_full"))
	runner.register_test("item_packs/retry_after_a_partial_state_does_not_redraw", Callable(ItemPacksTests, "_t_retry_token"))
	runner.register_test("item_packs/defeat_loses_item_rows_and_held_pieces_once", Callable(ItemPacksTests, "_t_defeat"))
	runner.register_test("item_packs/path_end_banks_item_rows_once", Callable(ItemPacksTests, "_t_path_end"))
	runner.register_test("item_packs/path_end_with_a_full_sanctum_keeps_pieces_held", Callable(ItemPacksTests, "_t_path_end_full"))
	runner.register_test("item_packs/json_round_trip_between_phases_gives_the_same_result", Callable(ItemPacksTests, "_t_round_trip"))
	runner.register_test("item_packs/item_free_results_equal_step_1", Callable(ItemPacksTests, "_t_item_free_pins"))
	runner.register_test("item_packs/found_items_refuse_what_intake_rejects", Callable(ItemPacksTests, "_t_refused_finds"))
	runner.register_test("item_packs/found_items_in_another_order_do_not_gather_twice", Callable(ItemPacksTests, "_t_find_order"))
	runner.register_test("item_packs/partial_stack_keeps_the_stored_quantity", Callable(ItemPacksTests, "_t_partial_stack"))
	runner.register_test("item_packs/rejected_intake_is_lost_with_its_reason", Callable(ItemPacksTests, "_t_rejected_mapping"))
	runner.register_test("item_packs/held_only_leave_returns_items_and_currency_keys", Callable(ItemPacksTests, "_t_held_only_result"))
	runner.register_test("item_packs/defeat_log_counts_items_and_keeps_the_item_free_payload", Callable(ItemPacksTests, "_t_defeat_log"))
	runner.register_test("item_packs/no_placeholder_id_in_config_or_core", Callable(ItemPacksTests, "_t_no_placeholder"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _three_objectives() -> Array:
	return ItemPacksCharacterizationTests._three_objectives()


## A fresh context with its own inventory cfg and an empty inventory block.
static func _ctx(realm_seed: int, cap: int, pack_cap: int, objs: Array = [], run_count: int = 0) -> FlowContext:
	var o: Array = objs if not objs.is_empty() else [EconomyCharacterizationTests._carry_boss()]
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", run_count, o, realm_seed)
	var c := _Cfg.new()
	c.load_balance()
	c.load_realms()
	c.inv = InventoryServiceTests._cfg(cap, pack_cap, 5)
	ctx.config_service = c
	ctx.save_data["inventory"] = InventoryServiceTests._fresh()["inventory"]
	ctx.logger = StructuredLogger.new()
	return ctx


static func _stage(ctx: FlowContext) -> Dictionary:
	return EconomyCharacterizationTests._carry_stage(ctx)


static func _inv(ctx: FlowContext) -> Dictionary:
	return ctx.save_data["inventory"]


static func _entry(type_id: String, qty: int = 1) -> Dictionary:
	return { "type_id": type_id, "kind": InventoryServiceTests._kind_of(type_id), "grade": "g1", "quantity": qty }


static func _find(find_id: String, type_id: String, qty: int = 1) -> Dictionary:
	var f := _entry(type_id, qty)
	f["find_id"] = find_id
	return f


## Writes item rows `item:<situation>:<n>` straight through the row writer, in the order given.
static func _add_rows(ctx: FlowContext, situation: String, ns: Array, type_id: String = "ph_weapon_a") -> void:
	for n in ns:
		EarningsService.record_item(_stage(ctx), situation, str(n), _entry(type_id))


## Puts held pieces `it.<from>`.. in the pack and raises the counter.
static func _hold(ctx: FlowContext, count: int, from: int = 1, type_id: String = "ph_weapon_a") -> void:
	var inv := _inv(ctx)
	for i in count:
		(inv["pack"] as Array).append({ "id": "it.%d" % (from + i), "type_id": type_id,
			"kind": InventoryServiceTests._kind_of(type_id), "grade": "g1", "held_by": "" })
	inv["next_seq"] = from + count


static func _leave(ctx: FlowContext, t: int = 1) -> Dictionary:
	var logger := StructuredLogger.new()
	var r := StageSettlementService.settle_leave(ctx, ctx.config_service,
		EconomyCharacterizationTests._carry_econ(ctx), 1.0, "test", logger, t)
	return { "result": r, "logger": logger }


static func _logs(got: Dictionary, type: String) -> Array:
	var out: Array = []
	for e in (got["logger"] as StructuredLogger).get_logs():
		if str(e["type"]) == type:
			out.append(e["data"])
	return out


static func _pack_ids(ctx: FlowContext) -> Array:
	return InventoryServiceTests._ids(ctx.save_data, "pack")


static func _item_ids(ctx: FlowContext) -> Array:
	return InventoryServiceTests._ids(ctx.save_data, "items")


## Row id -> "settled-share/fate/reason" of the first entry.
static func _row_fates(ctx: FlowContext) -> Dictionary:
	var out := {}
	for r_v in EarningsService.rows_of(_stage(ctx)):
		var r: Dictionary = r_v
		if EarningsService.is_item_row(r):
			var e: Dictionary = (r["items"] as Array)[0]
			out[str(r["id"])] = "%s%s/%s/%s" % ["S" if bool(r["settled"]) else "-", "L" if bool(r["lost"]) else "-",
				str(e.get("fate", "")), str(e.get("reason_key", ""))]
	return _sorted(out)


## Held-piece id -> "token/fate/reason".
static func _held_fates(ctx: FlowContext) -> Dictionary:
	var out := {}
	for r_v in EarningsService.held_fates_of(_stage(ctx)):
		var r: Dictionary = r_v
		out[str(r["id"])] = "%s/%s/%s" % [str(r["token"]), str(r["fate"]), str(r["reason_key"])]
	return _sorted(out)


## The dictionary with its keys in sorted order, so `str()` of two equal maps matches.
static func _sorted(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort()
	var out := {}
	for k in keys:
		out[k] = d[k]
	return out


static func _reload(ctx: FlowContext) -> void:
	ctx.save_data = JSON.parse_string(JSON.stringify(ctx.save_data))


static func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


static func _has_id_key(report: Dictionary) -> bool:
	for key in ["kept", "lost"]:
		for r in report[key]:
			if (r as Dictionary).has("id") or (r as Dictionary).has("item_id") or (r as Dictionary).has("piece_id"):
				return true
	return false


# ---------------------------------------------------------------------------
# 1. EarningsService
# ---------------------------------------------------------------------------

static func _t_earnings_rows() -> Dictionary:
	var m: Array = []
	var stage := { "index": 0 }
	if not EarningsService.record_found(stage, "m0", "money", 12):
		m.append("setup: the found row was refused")
	if not EarningsService.record_item(stage, "s0", "0", _entry("ph_weapon_a")) \
			or not EarningsService.record_item(stage, "s0", "1", _entry("ph_consumable_a", 2)):
		m.append("an item row was refused")
	if EarningsService.record_item(stage, "s0", "0", _entry("ph_charm_a")):
		m.append("a duplicate item row id was accepted")
	if EarningsService.record_item(stage, "", "5", _entry("ph_charm_a")):
		m.append("an empty situation id was accepted")
	if EarningsService.item_id("s0", "f3") != "item:s0:f3":
		m.append("item_id is %s" % EarningsService.item_id("s0", "f3"))
	var empty := EarningsService.make_row("item:s0:9", "item", "gear", 0, 0)
	if EarningsService.add_row(stage, empty):
		m.append("a row with no currency and no items was accepted")
	var row: Dictionary = EarningsService.row_of(stage, "item:s0:0")
	var e: Dictionary = (row.get("items", [{}]) as Array)[0]
	if int(row["ase"]) != 0 or int(row["ekwan"]) != 0 or bool(row["scaled"]) or bool(row["keep_on_defeat"]) \
			or str(row["source"]) != "item" or bool(row["settled"]) or bool(row["lost"]) or (row["items"] as Array).size() != 1 \
			or str(e.get("type_id")) != "ph_weapon_a" or str(e.get("kind")) != "gear" or str(e.get("grade")) != "g1" \
			or int(e.get("quantity", 0)) != 1 or str(e.get("fate")) != "gathered" or str(e.get("reason_key")) != "ok":
		m.append("row shape %s" % JSON.stringify(row))
	var plan := EarningsService.plan(stage, EconomyCharacterizationTests._rewards_cfg())
	if str(plan["ids"]) != str(["found:m0", "item:s0:0", "item:s0:1"]) or int(plan["scaled_ase"]) != 12 \
			or int(plan["scaled_ekwan"]) != 0 or int(plan["flat_ase"]) != 0 \
			or str(plan["sources"]["item"]) != str({ "rows": 2, "ase": 0, "all": 2 }) \
			or str(plan["sources"]["found"]) != str({ "rows": 1, "ase": 12, "all": 1 }):
		m.append("plan %s" % str(plan))
	row["settled"] = true
	plan = EarningsService.plan(stage, EconomyCharacterizationTests._rewards_cfg())
	if str(plan["sources"]["item"]) != str({ "rows": 1, "ase": 0, "all": 2 }) or EarningsService.open_item_rows(stage).size() != 1:
		m.append("after one settled: %s" % str(plan["sources"]["item"]))
	if EarningsService.mark_lost(stage) != 2 or not bool(EarningsService.row_of(stage, "item:s0:1")["lost"]):
		m.append("mark_lost did not count the open item row with the found row")
	return _result(m)


# ---------------------------------------------------------------------------
# 2. The seam: record_found_items
# ---------------------------------------------------------------------------

static func _t_found_items() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_NONE, 5, 2)
	var finds: Array = [_find("f0", "ph_weapon_a"), "not a find", _find("f1", "ph_relic_a"), _find("f2", "ph_charm_a")]
	var got := ActiveStageService.record_found_items(ctx, "s0", finds, 4)
	if str(got) != str({ "taken": ["f0", "f1"], "left": ["f2"], "refused": [{ "find_id": "", "reason_key": "bad_entry" }] }):
		m.append("first call returned %s" % str(got))
	var stage := _stage(ctx)
	var ids: Array = []
	for r in EarningsService.rows_of(stage):
		ids.append(str((r as Dictionary)["id"]))
	if str(ids) != str(["item:s0:f0", "item:s0:f1"]):
		m.append("row ids %s, expected the find ids" % str(ids))
	if not ctx.save_request or str(ctx.save_request_reason) != "economy.earnings.items":
		m.append("save request %s / %s" % [str(ctx.save_request), ctx.save_request_reason])
	var lines: Array = []
	for e in (ctx.logger as StructuredLogger).get_logs():
		if str(e["type"]) == "economy.earnings.items":
			lines.append(e["data"])
	if lines.size() != 1 or int(lines[0]["taken"]) != 2 or int(lines[0]["left"]) != 1 or int(lines[0]["refused"]) != 1 or int(lines[0]["free"]) != 2:
		m.append("log lines %s" % str(lines))
	var before := JSON.stringify(ctx.save_data)
	var again := ActiveStageService.record_found_items(ctx, "s0", finds, 5)
	if not (again["taken"] as Array).is_empty() or JSON.stringify(ctx.save_data) != before:
		m.append("a repeat call wrote or took: %s" % str(again))
	if InventoryService.pack_free(ctx.save_data, ConfigService.get_inventory_cfg(ctx.config_service),
			EarningsService.open_item_rows(stage).size()) != 0:
		m.append("the two open item rows do not hold the two pack slots")
	# A held piece takes a slot: capacity 2 with one held piece leaves room for one find.
	var ctx2 := _ctx(_SEED_NONE, 5, 2)
	_hold(ctx2, 1)
	var got2 := ActiveStageService.record_found_items(ctx2, "s0", [_find("a", "ph_weapon_a"), _find("b", "ph_charm_a")], 4)
	if str(got2) != str({ "taken": ["a"], "left": ["b"], "refused": [] }):
		m.append("with one held piece: %s" % str(got2))
	# A second situation adds to the open rows. No room is left, so nothing is taken.
	var got3 := ActiveStageService.record_found_items(ctx2, "s1", [_find("c", "ph_armor_a")], 6)
	if str(got3) != str({ "taken": [], "left": ["c"], "refused": [] }) or EarningsService.rows_of(_stage(ctx2)).size() != 1:
		m.append("full pack: %s, rows %d" % [str(got3), EarningsService.rows_of(_stage(ctx2)).size()])
	# No stage or no situation id: nothing is written.
	var none := ActiveStageService.record_found_items(ctx2, "", [_find("d", "ph_armor_a")], 7)
	if not (none["taken"] as Array).is_empty() or EarningsService.rows_of(_stage(ctx2)).size() != 1:
		m.append("an empty situation id wrote a row")
	return _result(m)


# ---------------------------------------------------------------------------
# 3. settle_plan
# ---------------------------------------------------------------------------

static func _t_plan_counts() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 5, 4)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	if not bool(plan["nothing_new"]) or int(plan["item_rows"]) != 0 or int(plan["held_pieces"]) != 0:
		m.append("empty: %s" % str(plan))
	_hold(ctx, 2)
	plan = StageSettlementService.settle_plan(ctx, ctx.config_service)
	if bool(plan["nothing_new"]) or int(plan["held_pieces"]) != 2 or int(plan["item_rows"]) != 0 or int(plan["rows"]) != 0:
		m.append("held only: %s" % str(plan))
	var ctx2 := _ctx(_SEED_ALL, 5, 4)
	_add_rows(ctx2, "s0", [0, 1])
	var before := JSON.stringify(ctx2.save_data)
	plan = StageSettlementService.settle_plan(ctx2, ctx2.config_service)
	if bool(plan["nothing_new"]) or int(plan["item_rows"]) != 2 or int(plan["held_pieces"]) != 0 or int(plan["rows"]) != 2 \
			or int(plan["ase"]) != 0 or str(plan["ids"]) != str(["item:s0:0", "item:s0:1"]):
		m.append("item rows only: %s" % str(plan))
	if JSON.stringify(ctx2.save_data) != before:
		m.append("settle_plan changed the save")
	EarningsService.mark_settled(_stage(ctx2), ["item:s0:0", "item:s0:1"], 100)
	plan = StageSettlementService.settle_plan(ctx2, ctx2.config_service)
	if not bool(plan["nothing_new"]) or int(plan["item_rows"]) != 0:
		m.append("settled item rows still count: %s" % str(plan))
	return _result(m)


# ---------------------------------------------------------------------------
# 4. settle_leave
# ---------------------------------------------------------------------------

## A pack with only item rows draws the outcome roll. Rolls 0 / 57 / 90 are the item-free values.
static func _t_item_only_roll() -> Dictionary:
	var m: Array = []
	# [seed, roll, outcome, row fate]. Seed 1 "some": the row's own draw is 14 (kept).
	for c in [[_SEED_NONE, 0, "none", "S-/lost/leave_none"], [_SEED_SOME, 57, "some", "S-/carried/ok"],
			[_SEED_ALL, 90, "all", "S-/carried/ok"]]:
		var ctx := _ctx(int(c[0]), 5, 4)
		_add_rows(ctx, "s0", [0])
		var got := _leave(ctx)
		var r: Dictionary = got["result"]
		var logs := _logs(got, "economy.settle.leave")
		var tag := "seed %d" % int(c[0])
		if str(r["outcome"]) != c[2] or int(r["ase"]) != 0 or int(r["ekwan"]) != 0:
			m.append("%s: result %s" % [tag, str(r)])
		if logs.size() != 1 or int(logs[0]["roll"]) != int(c[1]) or int(logs[0]["settle_count"]) != 0 \
				or str(logs[0]["marked_ids"]) != "[]":
			m.append("%s: leave log %s" % [tag, str(logs)])
		if str(_row_fates(ctx)) != str({ "item:s0:0": c[3] }):
			m.append("%s: row %s, expected %s" % [tag, str(_row_fates(ctx)), c[3]])
		var kept: bool = c[2] != "none"
		var row := EarningsService.row_of(_stage(ctx), "item:s0:0")
		if int(row["settled_share"]) != (100 if kept else 0) or int(_stage(ctx)["settle_count"]) != 1:
			m.append("%s: share %s, settle_count %s" % [tag, str(row["settled_share"]), str(_stage(ctx)["settle_count"])])
		if int(r["items"]["kept_count"]) != (1 if kept else 0) or int(r["items"]["lost_count"]) != (0 if kept else 1) \
				or _has_id_key(r["items"]):
			m.append("%s: items report %s" % [tag, str(r["items"])])
		if (_item_ids(ctx).size() == 1) != kept:
			m.append("%s: Sanctum pieces %s" % [tag, str(_item_ids(ctx))])
		var before := JSON.stringify(ctx.save_data)
		var repeat := _leave(ctx, 2)
		if str(repeat["result"]["outcome"]) != "nothing_new" or not _logs(repeat, "economy.settle.leave").is_empty() \
				or JSON.stringify(ctx.save_data) != before:
			m.append("%s: a repeat leave drew or changed the save" % tag)
	return _result(m)


## The outcome roll with item rows and held pieces present equals the item-free value of step 1, and the
## currency paid is unchanged. The item rows are not in `marked_ids`.
static func _t_outcome_stream() -> Dictionary:
	var m: Array = []
	# [seed, roll, outcome, ase, ekwan]
	for c in [[_SEED_NONE, 0, "none", 0, 0], [_SEED_SOME, 57, "some", 39, 7], [_SEED_ALL, 90, "all", 78, 14]]:
		var ctx := _ctx(int(c[0]), 5, 4, _three_objectives())
		_add_rows(ctx, "s0", [0, 1])
		_hold(ctx, 1)
		var got := _leave(ctx)
		var r: Dictionary = got["result"]
		var logs := _logs(got, "economy.settle.leave")
		var tag := "seed %d" % int(c[0])
		var expect_roll := CampaignSeed.get_rng_from(int(c[0]), "stage.settle.stage.0.0.0").randi_range(0, 99)
		if expect_roll != int(c[1]) or logs.size() != 1 or int(logs[0]["roll"]) != int(c[1]):
			m.append("%s: roll %s, pinned %d, stream %d" % [tag, str(logs), c[1], expect_roll])
		if str(r["outcome"]) != c[2] or int(r["ase"]) != int(c[3]) or int(r["ekwan"]) != int(c[4]):
			m.append("%s: result %s, expected %s %d/%d" % [tag, str(r), c[2], c[3], c[4]])
		if str(logs[0]["marked_ids"]) != str(["obj:0:0", "obj:0:1", "obj:0:2"]):
			m.append("%s: marked_ids %s" % [tag, str(logs[0]["marked_ids"])])
		var bal := ctx.save_data["economy"] as Dictionary
		if "%d/%d" % [int(bal["ase"]), int(bal["ekwan"])] != "%d/%d" % [int(c[3]), int(c[4])]:
			m.append("%s: balance %s" % [tag, str(bal)])
		if int(_stage(ctx)["settled_ase"]) != int(c[3]) or int(_stage(ctx)["settle_count"]) != 1:
			m.append("%s: stage totals" % tag)
	return _result(m)


## Seed 1, "some". An entry's draw depends on its id only. Pinned: item:s0:0 keeps (14), :1 keeps (2),
## :2 loses (65), :3 loses (67), held it.1 loses (69).
static func _t_draw_independence() -> Dictionary:
	var m: Array = []
	var a := _ctx(_SEED_SOME, 8, 4)
	_add_rows(a, "s0", [0, 2])
	var ga := _leave(a)
	var fa := _row_fates(a)
	var b := _ctx(_SEED_SOME, 8, 4)
	_add_rows(b, "s0", [3, 2, 1, 0])
	_hold(b, 1)
	var gb := _leave(b)
	var fb := _row_fates(b)
	if str(ga["result"]["outcome"]) != "some" or str(gb["result"]["outcome"]) != "some":
		m.append("outcomes %s / %s" % [str(ga["result"]["outcome"]), str(gb["result"]["outcome"])])
	var keep := "S-/carried/ok"
	var lose := "S-/lost/leave_some"
	if str(fa) != str({ "item:s0:0": keep, "item:s0:2": lose }):
		m.append("run A fates %s" % str(fa))
	if fb.get("item:s0:0") != keep or fb.get("item:s0:1") != keep or fb.get("item:s0:2") != lose or fb.get("item:s0:3") != lose:
		m.append("run B fates %s" % str(fb))
	if fa.get("item:s0:0") != fb.get("item:s0:0") or fa.get("item:s0:2") != fb.get("item:s0:2"):
		m.append("adding entries or reordering changed a fate")
	if str(_held_fates(b)) != str({ "it.1": "0.0/lost/leave_some" }):
		m.append("held fates %s" % str(_held_fates(b)))
	# Stream names, written out: the row and held draws come from `inventory.leave.<stage>.<run>.<count>.<kind>.<id>`.
	for c in [["row", "item:s0:0", 14], ["row", "item:s0:3", 67], ["held", "it.1", 69]]:
		var d := CampaignSeed.get_rng_from(_SEED_SOME, "inventory.leave.stage.0.0.0.%s.%s" % [c[0], c[1]]).randi_range(0, 99)
		if d != int(c[2]):
			m.append("draw %s %s is %d, pinned %d" % [c[0], c[1], d, c[2]])
	return _result(m)


## Held pieces are in the roll. A leave with ONLY held pieces draws the outcome roll.
static func _t_held_rolled() -> Dictionary:
	var m: Array = []
	# Seed 1 "some", Sanctum full (cap 0): it.2 (33) survives and stays held; it.1 (69), it.3 (66), it.4 (90) are lost.
	var ctx := _ctx(_SEED_SOME, 0, 4)
	_hold(ctx, 4)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	if bool(plan["nothing_new"]) or int(plan["held_pieces"]) != 4:
		m.append("plan before: %s" % str(plan))
	var got := _leave(ctx)
	var r: Dictionary = got["result"]
	var logs := _logs(got, "economy.settle.leave")
	if str(r["outcome"]) != "some" or logs.size() != 1 or int(logs[0]["roll"]) != 57:
		m.append("held only: result %s, logs %s" % [str(r["outcome"]), str(logs)])
	if str(_pack_ids(ctx)) != str(["it.2"]):
		m.append("pack after: %s" % str(_pack_ids(ctx)))
	var want := { "it.1": "0.0/lost/leave_some", "it.2": "0.0/carried/to_pack",
		"it.3": "0.0/lost/leave_some", "it.4": "0.0/lost/leave_some" }
	if str(_held_fates(ctx)) != str(want):
		m.append("held fates %s" % str(_held_fates(ctx)))
	if int(r["items"]["kept_count"]) != 1 or int(r["items"]["lost_count"]) != 3 or _has_id_key(r["items"]) \
			or str((r["items"]["kept"] as Array)[0]) != str({ "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1", "quantity": 1, "reason_key": "to_pack" }):
		m.append("items report %s" % str(r["items"]))
	var item_logs := _logs(got, "economy.settle.items")
	if item_logs.size() != 1 or int(item_logs[0]["draws"]) != 4 or int(item_logs[0]["held"]) != 4:
		m.append("items log %s" % str(item_logs))
	if int(_stage(ctx)["settle_count"]) != 1:
		m.append("settle_count %s" % str(_stage(ctx)["settle_count"]))
	# Seed 0 "none": every held piece is lost, no draw.
	var none := _ctx(_SEED_NONE, 0, 4)
	_hold(none, 2)
	var gn := _leave(none)
	var nl := _logs(gn, "economy.settle.items")
	if not _pack_ids(none).is_empty() or str(_held_fates(none)) != str({ "it.1": "0.0/lost/leave_none", "it.2": "0.0/lost/leave_none" }) \
			or nl.size() != 1 or int(nl[0]["draws"]) != 0:
		m.append("none: pack %s, fates %s, log %s" % [str(_pack_ids(none)), str(_held_fates(none)), str(nl)])
	# Seed 2 "all", Sanctum with room: every held piece survives and moves into the Sanctum.
	var all := _ctx(_SEED_ALL, 8, 4)
	_hold(all, 2)
	var ga := _leave(all)
	var al := _logs(ga, "economy.settle.items")
	if not _pack_ids(all).is_empty() or str(_item_ids(all)) != str(["it.1", "it.2"]) \
			or str(_held_fates(all)) != str({ "it.1": "0.0/carried/ok", "it.2": "0.0/carried/ok" }) \
			or al.size() != 1 or int(al[0]["draws"]) != 0 or int(al[0]["moved"]) != 2:
		m.append("all: pack %s, items %s, fates %s, log %s" % [str(_pack_ids(all)), str(_item_ids(all)), str(_held_fates(all)), str(al)])
	return _result(m)


## D-22: every early leave draws the held pieces again, with the new settle_count. Seed 7: the first leave
## rolls 99 (all), the second rolls 63 (some). The draws on count 1 for it.1..it.4 are 59, 42, 85, 54: only
## it.2 is kept. The draws on count 0 would keep it.2, it.3 and it.4 (18, 3, 34), so a stale count shows.
static func _t_repeat_leave() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_REPEAT, 0, 4)
	_hold(ctx, 4)
	var first := _leave(ctx, 1)
	var l1 := _logs(first, "economy.settle.leave")
	var all_held := { "it.1": "0.0/carried/to_pack", "it.2": "0.0/carried/to_pack", "it.3": "0.0/carried/to_pack", "it.4": "0.0/carried/to_pack" }
	if str(first["result"]["outcome"]) != "all" or int(l1[0]["roll"]) != 99 or str(_pack_ids(ctx)) != str(["it.1", "it.2", "it.3", "it.4"]) \
			or str(_held_fates(ctx)) != str(all_held):
		m.append("first leave: %s, pack %s, fates %s" % [str(first["result"]["outcome"]), str(_pack_ids(ctx)), str(_held_fates(ctx))])
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	if bool(plan["nothing_new"]) or int(plan["settle_count"]) != 1:
		m.append("plan after the first leave: %s" % str(plan))
	var second := _leave(ctx, 2)
	var l2 := _logs(second, "economy.settle.leave")
	if str(second["result"]["outcome"]) != "some" or l2.size() != 1 or int(l2[0]["roll"]) != 63 or int(l2[0]["settle_count"]) != 1:
		m.append("second leave: %s %s" % [str(second["result"]["outcome"]), str(l2)])
	var want := { "it.1": "0.1/lost/leave_some", "it.2": "0.1/carried/to_pack", "it.3": "0.1/lost/leave_some", "it.4": "0.1/lost/leave_some" }
	if str(_pack_ids(ctx)) != str(["it.2"]) or str(_held_fates(ctx)) != str(want):
		m.append("second leave: pack %s, fates %s" % [str(_pack_ids(ctx)), str(_held_fates(ctx))])
	for c in [["it.1", 59], ["it.2", 42], ["it.3", 85], ["it.4", 54]]:
		var d := CampaignSeed.get_rng_from(_SEED_REPEAT, "inventory.leave.stage.0.0.1.held.%s" % c[0]).randi_range(0, 99)
		if d != int(c[1]):
			m.append("held draw %s on count 1 is %d, pinned %d" % [c[0], d, c[1]])
	if int(_stage(ctx)["settle_count"]) != 2:
		m.append("settle_count %s" % str(_stage(ctx)["settle_count"]))
	return _result(m)


## D-24: a survivor stays held when the Sanctum is full, whether it was held before or gathered now.
static func _t_survivor_full() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 1, 4)
	(_inv(ctx)["items"] as Array).append({ "id": "it.1", "type_id": "ph_armor_a", "kind": "gear", "grade": "g1", "held_by": "" })
	_hold(ctx, 1, 2)
	_add_rows(ctx, "s0", [0], "ph_relic_a")
	var got := _leave(ctx)
	if str(got["result"]["outcome"]) != "all" or str(_item_ids(ctx)) != str(["it.1"]) or str(_pack_ids(ctx)) != str(["it.2", "it.3"]):
		m.append("outcome %s, Sanctum %s, pack %s" % [str(got["result"]["outcome"]), str(_item_ids(ctx)), str(_pack_ids(ctx))])
	if str(_row_fates(ctx)) != str({ "item:s0:0": "S-/carried/to_pack" }) or str(_held_fates(ctx)) != str({ "it.2": "0.0/carried/to_pack" }):
		m.append("row fates %s, held fates %s" % [str(_row_fates(ctx)), str(_held_fates(ctx))])
	if not InventoryService.validate(ctx.save_data, ConfigService.get_inventory_cfg(ctx.config_service)).is_empty():
		m.append("validate: %s" % str(InventoryService.validate(ctx.save_data, ConfigService.get_inventory_cfg(ctx.config_service))))
	return _result(m)


## A held piece that already has a record with this settle's token is not drawn. Seed 1 would lose it.1 (69).
static func _t_retry_token() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_SOME, 0, 4)
	_hold(ctx, 2)
	EarningsService.put_held_fate(_stage(ctx), { "id": "it.1", "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1",
		"token": "0.0", "fate": "carried", "reason_key": "to_pack" })
	var got := _leave(ctx)
	var il := _logs(got, "economy.settle.items")
	if str(_pack_ids(ctx)) != str(["it.1", "it.2"]) or str(_held_fates(ctx)) != str({ "it.1": "0.0/carried/to_pack", "it.2": "0.0/carried/to_pack" }) \
			or il.size() != 1 or int(il[0]["draws"]) != 1 or int(il[0]["held"]) != 1:
		m.append("pack %s, fates %s, log %s" % [str(_pack_ids(ctx)), str(_held_fates(ctx)), str(il)])
	# A full cycle: leave, then put settle_count back (a state saved with the records but not the count).
	var ctx2 := _ctx(_SEED_SOME, 0, 4)
	_hold(ctx2, 4)
	_leave(ctx2)
	_stage(ctx2)["settle_count"] = 0
	var fates_before := _held_fates(ctx2)
	var again := _leave(ctx2, 2)
	var al := _logs(again, "economy.settle.items")
	if not al.is_empty() or str(_pack_ids(ctx2)) != str(["it.2"]) or str(_held_fates(ctx2)) != str(fates_before):
		m.append("retry drew again: log %s, pack %s, fates %s" % [str(al), str(_pack_ids(ctx2)), str(_held_fates(ctx2))])
	return _result(m)


# ---------------------------------------------------------------------------
# 5. Defeat
# ---------------------------------------------------------------------------

static func _t_defeat() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 0, 4, [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	_add_rows(ctx, "s0", [0, 1])
	_add_rows(ctx, "s1", [0], "ph_charm_a")
	EarningsService.mark_settled(_stage(ctx), ["item:s1:0"], 100)
	_hold(ctx, 2)
	var lost := ActiveStageService.lose_unsettled_packs(ctx, 3)
	if lost != 3:
		m.append("lost %d rows, expected the objective row and two item rows" % lost)
	var want := { "item:s0:0": "-L/lost/defeat", "item:s0:1": "-L/lost/defeat", "item:s1:0": "S-/gathered/ok" }
	if str(_row_fates(ctx)) != str(want):
		m.append("row fates %s" % str(_row_fates(ctx)))
	if not _pack_ids(ctx).is_empty() or str(_held_fates(ctx)) != str({ "it.1": "defeat/lost/defeat", "it.2": "defeat/lost/defeat" }):
		m.append("pack %s, held fates %s" % [str(_pack_ids(ctx)), str(_held_fates(ctx))])
	var logs: Array = []
	for e in (ctx.logger as StructuredLogger).get_logs():
		if str(e["type"]) == "economy.earnings.lost":
			logs.append(e["data"])
	if logs.size() != 1 or int(logs[0]["items"]) != 2 or int(logs[0]["held"]) != 2 or int(logs[0]["rows"]) != 3:
		m.append("log %s" % str(logs))
	var after := JSON.stringify(ctx.save_data)
	if ActiveStageService.lose_unsettled_packs(ctx, 4) != 0 or JSON.stringify(ctx.save_data) != after:
		m.append("a repeat defeat marked or removed something")
	var bal := ctx.save_data["economy"] as Dictionary
	if int(bal["ase"]) != 0 or int(bal["ekwan"]) != 0:
		m.append("the defeat moved the balance")
	# Held pieces only: the pack is emptied although no row is lost.
	var ctx2 := _ctx(_SEED_ALL, 0, 4)
	_hold(ctx2, 2)
	if ActiveStageService.lose_unsettled_packs(ctx2, 3) != 0 or not _pack_ids(ctx2).is_empty() \
			or EarningsService.held_fates_of(_stage(ctx2)).size() != 2:
		m.append("held only: pack %s, fates %s" % [str(_pack_ids(ctx2)), str(_held_fates(ctx2))])
	# Pieces in the Sanctum are safe.
	var ctx3 := _ctx(_SEED_ALL, 4, 4)
	(_inv(ctx3)["items"] as Array).append({ "id": "it.1", "type_id": "ph_armor_a", "kind": "gear", "grade": "g1", "held_by": "" })
	ActiveStageService.lose_unsettled_packs(ctx3, 3)
	if str(_item_ids(ctx3)) != str(["it.1"]):
		m.append("a defeat touched a Sanctum piece")
	return _result(m)


# ---------------------------------------------------------------------------
# 6. Path end
# ---------------------------------------------------------------------------

static func _settle_path(ctx: FlowContext, t: int) -> Dictionary:
	var econ := EconomyCharacterizationTests._carry_econ(ctx)
	return StageSettlementService.new(ctx, ctx.config_service, econ, EconomyCharacterizationTests._logger()).settle(true, t)


static func _t_path_end() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 8, 4)
	_hold(ctx, 1)
	var stage := _stage(ctx)
	EarningsService.record_item(stage, "s0", "0", _entry("ph_relic_a"))
	EarningsService.record_item(stage, "s0", "1", _entry("ph_consumable_a", 2))
	var paid := _settle_path(ctx, 5)
	var items: Dictionary = paid.get("items", {})
	if int(items.get("kept_count", -1)) != 2 or int(items.get("lost_count", -1)) != 0 or _has_id_key(items):
		m.append("payout items %s" % str(items))
	if str(_item_ids(ctx)) != str(["it.1", "it.2"]) or not _pack_ids(ctx).is_empty():
		m.append("Sanctum %s, pack %s: the held piece moves in first, then the relic" % [str(_item_ids(ctx)), str(_pack_ids(ctx))])
	var stacks: Array = _inv(ctx)["stacks"]
	if stacks.size() != 1 or str((stacks[0] as Dictionary)["type_id"]) != "ph_consumable_a" or int((stacks[0] as Dictionary)["quantity"]) != 2:
		m.append("stacks %s" % JSON.stringify(stacks))
	if str(_row_fates(ctx)) != str({ "item:s0:0": "S-/carried/ok", "item:s0:1": "S-/carried/ok" }):
		m.append("row fates %s" % str(_row_fates(ctx)))
	for id in ["item:s0:0", "item:s0:1"]:
		if int(EarningsService.row_of(stage, id)["settled_share"]) != 100:
			m.append("%s settled_share is not 100" % id)
	if not EarningsService.held_fates_of(stage).is_empty():
		m.append("path end wrote held fates (held pieces are not rolled)")
	var receipt: Dictionary = stage.get("settlement_receipt", {})
	if not bool(receipt.get("settled", false)) or str(receipt.get("outcome", "")) != "cleared":
		m.append("receipt %s" % str(receipt))
	var after := JSON.stringify(ctx.save_data)
	if not _settle_path(ctx, 6).is_empty() or JSON.stringify(ctx.save_data) != after:
		m.append("a second settle returned something or changed the save")
	# A row already settled by a leave is not banked again.
	var ctx2 := _ctx(_SEED_ALL, 8, 4)
	EarningsService.record_item(_stage(ctx2), "s0", "0", _entry("ph_relic_a"))
	_leave(ctx2)
	var count := _item_ids(ctx2).size()
	var paid2 := _settle_path(ctx2, 5)
	if count != 1 or _item_ids(ctx2).size() != 1 or int((paid2.get("items", {}) as Dictionary).get("kept_count", -1)) != 0:
		m.append("path end banked a row the leave had settled: %s" % str(paid2.get("items")))
	return _result(m)


static func _t_path_end_full() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 1, 4)
	(_inv(ctx)["items"] as Array).append({ "id": "it.1", "type_id": "ph_armor_a", "kind": "gear", "grade": "g1", "held_by": "" })
	_hold(ctx, 1, 2)
	EarningsService.record_item(_stage(ctx), "s0", "0", _entry("ph_relic_a"))
	var paid := _settle_path(ctx, 5)
	var kept: Array = (paid.get("items", {}) as Dictionary).get("kept", [])
	if kept.size() != 1 or str((kept[0] as Dictionary).get("reason_key")) != "to_pack":
		m.append("payout items %s" % str(paid.get("items")))
	if str(_item_ids(ctx)) != str(["it.1"]) or str(_pack_ids(ctx)) != str(["it.2", "it.3"]):
		m.append("Sanctum %s, pack %s: both pieces stay held" % [str(_item_ids(ctx)), str(_pack_ids(ctx))])
	if not EarningsService.held_fates_of(_stage(ctx)).is_empty():
		m.append("held pieces were rolled at path end")
	return _result(m)


# ---------------------------------------------------------------------------
# 7. Save round trip and item-free pins
# ---------------------------------------------------------------------------

## Runs one scenario through record, leave, record, leave, record and path end. With `reload` the save goes
## through JSON between every phase (ints come back as floats). The final saves must match.
static func _scenario(reload: bool) -> Dictionary:
	var ctx := _ctx(_SEED_REPEAT, 1, 3)
	(_inv(ctx)["items"] as Array).append({ "id": "it.1", "type_id": "ph_armor_a", "kind": "gear", "grade": "g1", "held_by": "" })
	_hold(ctx, 1, 2)
	var trace: Array = []
	var steps := ["a", "b", "c", "d", "e", "f"]
	for step in steps:
		if step == "a":
			trace.append(ActiveStageService.record_found_items(ctx, "s0", [_find("x", "ph_relic_a"), _find("y", "ph_consumable_a", 2)], 1))
		elif step == "b":
			trace.append(_leave(ctx, 2)["result"])
		elif step == "c":
			trace.append(ActiveStageService.record_found_items(ctx, "s1", [_find("z", "ph_charm_a")], 3))
		elif step == "d":
			trace.append(_leave(ctx, 4)["result"])
		elif step == "e":
			trace.append(ActiveStageService.record_found_items(ctx, "s2", [_find("w", "ph_weapon_a")], 5))
		else:
			trace.append(_settle_path(ctx, 6))
		if reload:
			_reload(ctx)
	return { "save": _norm(ctx.save_data), "trace": _norm(trace), "ctx": ctx }


static func _t_round_trip() -> Dictionary:
	var m: Array = []
	var straight := _scenario(false)
	var reloaded := _scenario(true)
	if straight["save"] != reloaded["save"]:
		m.append("final saves differ after JSON round trips:\n%s\n%s" % [straight["save"], reloaded["save"]])
	if straight["trace"] != reloaded["trace"]:
		m.append("phase results differ after JSON round trips:\n%s\n%s" % [straight["trace"], reloaded["trace"]])
	var ctx: FlowContext = straight["ctx"]
	var problems := InventoryService.validate(ctx.save_data, ConfigService.get_inventory_cfg(ctx.config_service))
	if not problems.is_empty():
		m.append("validate: %s" % str(problems))
	# A leave replayed from the saved state before it gives the same result as the first run.
	var base := _ctx(_SEED_SOME, 0, 4)
	_hold(base, 3)
	EarningsService.record_item(_stage(base), "s0", "0", _entry("ph_weapon_a"))
	EarningsService.record_item(_stage(base), "s0", "1", _entry("ph_charm_a"))
	var saved := JSON.stringify(base.save_data)
	var first := _leave(base)
	var replay := _ctx(_SEED_SOME, 0, 4)
	replay.save_data = JSON.parse_string(saved)
	var second := _leave(replay)
	if _norm(first["result"]) != _norm(second["result"]) or _norm(base.save_data) != _norm(replay.save_data):
		m.append("a leave replayed from the saved state differs")
	return _result(m)


## Item-free packs with an empty inventory block give the step 1 values.
static func _t_item_free_pins() -> Dictionary:
	var m: Array = []
	for c in [[_SEED_NONE, 0, "none", 0, 0, 0], [_SEED_SOME, 57, "some", 39, 7, 50], [_SEED_ALL, 90, "all", 78, 14, 100]]:
		var ctx := _ctx(int(c[0]), 5, 4, _three_objectives())
		var before_inv := JSON.stringify(ctx.save_data["inventory"])
		var got := _leave(ctx)
		var r: Dictionary = got["result"]
		var logs := _logs(got, "economy.settle.leave")
		var tag := "seed %d" % int(c[0])
		if str(r["outcome"]) != c[2] or int(r["ase"]) != int(c[3]) or int(r["ekwan"]) != int(c[4]) \
				or logs.size() != 1 or int(logs[0]["roll"]) != int(c[1]) or int(logs[0]["share_pct"]) != int(c[5]) \
				or str(logs[0]["marked_ids"]) != str(["obj:0:0", "obj:0:1", "obj:0:2"]):
			m.append("%s: result %s, logs %s" % [tag, str(r), str(logs)])
		if int(r["items"]["kept_count"]) != 0 or int(r["items"]["lost_count"]) != 0 or not _logs(got, "economy.settle.items").is_empty():
			m.append("%s: an item-free leave reported or logged items" % tag)
		if JSON.stringify(ctx.save_data["inventory"]) != before_inv:
			m.append("%s: an item-free leave changed the inventory block" % tag)
		for r_v in EarningsService.rows_of(_stage(ctx)):
			if not bool((r_v as Dictionary)["settled"]) or int((r_v as Dictionary)["settled_share"]) != int(c[5]):
				m.append("%s: row %s" % [tag, str(r_v)])
	# Nothing new: byte-equal save, no log.
	var ctx2 := _ctx(_SEED_ALL, 5, 4)
	var before := JSON.stringify(ctx2.save_data)
	var nn := _leave(ctx2)
	if str(nn["result"]["outcome"]) != "nothing_new" or JSON.stringify(ctx2.save_data) != before \
			or not _logs(nn, "economy.settle.leave").is_empty():
		m.append("nothing new: %s" % str(nn["result"]))
	# Path end with no item row: step 1 values (54 Ase + 10 stipend, 6 Ekwan) and no inventory change.
	var ctx3 := _ctx(_SEED_ALL, 5, 4, [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	EconomyCharacterizationTests._gather(ctx3, 2, 12)
	var inv_before := JSON.stringify(ctx3.save_data["inventory"])
	var paid := _settle_path(ctx3, 5)
	if int(paid.get("ase_awarded", -1)) != 64 or int(paid.get("ekwan_awarded", -1)) != 6 \
			or int((paid.get("items", {}) as Dictionary).get("kept_count", -1)) != 0 \
			or JSON.stringify(ctx3.save_data["inventory"]) != inv_before:
		m.append("path end %s" % str(paid))
	# Defeat with no item row and no held piece: the step 1 count, the inventory is untouched.
	var ctx4 := _ctx(_SEED_ALL, 5, 4, [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	EconomyCharacterizationTests._gather(ctx4, 2, 12)
	var inv4 := JSON.stringify(ctx4.save_data["inventory"])
	if ActiveStageService.lose_unsettled_packs(ctx4, 3) != 4 or JSON.stringify(ctx4.save_data["inventory"]) != inv4 \
			or not EarningsService.held_fates_of(_stage(ctx4)).is_empty():
		m.append("defeat changed the inventory or the held fates")
	return _result(m)


## No placeholder id reaches the shipped config or the code of this step.
static func _t_no_placeholder() -> Dictionary:
	var m: Array = []
	for path in ["res://data/balance.json", "res://core/economy/EarningsService.gd", "res://core/economy/StageSettlementService.gd",
			"res://core/realms/ActiveStageService.gd"]:
		if InventorySaveTests._has_placeholder_id(FileAccess.get_file_as_string(path)):
			m.append("%s holds a ph_ id" % path)
	return _result(m)


# ---------------------------------------------------------------------------
# 8. Review fixes
# ---------------------------------------------------------------------------

## A refused find takes no slot and is never gathered. A valid find after the refused ones still takes the slot.
static func _t_refused_finds() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_NONE, 5, 1)
	((ctx.config_service as _Cfg).inv["kinds_enabled"] as Dictionary)["material"] = false
	var no_id := _entry("ph_weapon_a")
	var stack0 := _find("b5", "ph_consumable_a", 0)
	var finds: Array = [
		{ "find_id": "b1", "type_id": "ph_weapon_a", "kind": "zzz", "grade": "g1", "quantity": 1 },
		_find("b2", "ph_material_a"),
		_find("b3", "ph_weapon_a", 2),
		{ "find_id": "b4", "type_id": "nope", "kind": "gear", "grade": "g1", "quantity": 1 },
		stack0, no_id, _find("ok", "ph_relic_a")]
	var got := ActiveStageService.record_found_items(ctx, "s0", finds, 4)
	var want_refused := [{ "find_id": "b1", "reason_key": "unknown_kind" }, { "find_id": "b2", "reason_key": "kind_disabled" },
		{ "find_id": "b3", "reason_key": "bad_entry" }, { "find_id": "b4", "reason_key": "unknown_type" },
		{ "find_id": "b5", "reason_key": "bad_entry" }, { "find_id": "", "reason_key": "bad_entry" }]
	if str(got) != str({ "taken": ["ok"], "left": [], "refused": want_refused }):
		m.append("result %s" % str(got))
	var ids: Array = []
	for r in EarningsService.rows_of(_stage(ctx)):
		ids.append(str((r as Dictionary)["id"]))
	if str(ids) != str(["item:s0:ok"]):
		m.append("rows %s" % str(ids))
	var lines: Array = []
	for e in (ctx.logger as StructuredLogger).get_logs():
		if str(e["type"]) == "economy.earnings.items":
			lines.append(e["data"])
	if lines.size() != 1 or int(lines[0]["refused"]) != 6 or int(lines[0]["taken"]) != 1 or int(lines[0]["free"]) != 1:
		m.append("log %s" % str(lines))
	# Only refused finds: nothing is written and no save is requested.
	var ctx2 := _ctx(_SEED_NONE, 5, 1)
	var only := ActiveStageService.record_found_items(ctx2, "s0", [_find("b3", "ph_weapon_a", 2)], 4)
	if (only["refused"] as Array).size() != 1 or not (only["taken"] as Array).is_empty() or ctx2.save_request \
			or not EarningsService.rows_of(_stage(ctx2)).is_empty():
		m.append("refused only: %s" % str(only))
	return _result(m)


## The row id uses the find id: the same finds in another order gather nothing twice.
static func _t_find_order() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_NONE, 5, 4)
	var finds: Array = [_find("x", "ph_weapon_a"), _find("y", "ph_relic_a"), _find("z", "ph_charm_a")]
	var first := ActiveStageService.record_found_items(ctx, "s0", finds, 1)
	if str(first["taken"]) != str(["x", "y", "z"]):
		m.append("first call %s" % str(first))
	var before := JSON.stringify(ctx.save_data)
	var again := ActiveStageService.record_found_items(ctx, "s0", [finds[2], finds[0], finds[1]], 2)
	if not (again["taken"] as Array).is_empty() or not (again["left"] as Array).is_empty() or JSON.stringify(ctx.save_data) != before:
		m.append("a reordered repeat wrote or took: %s" % str(again))
	if EarningsService.open_item_rows(_stage(ctx)).size() != 3:
		m.append("rows %d, expected 3" % EarningsService.open_item_rows(_stage(ctx)).size())
	return _result(m)


## A stack above the limit: the entry keeps the stored quantity and `lost_quantity`, at a leave and at path end.
static func _t_partial_stack() -> Dictionary:
	var m: Array = []
	var want_row := { "type_id": "ph_consumable_a", "kind": "consumable", "grade": "g1", "quantity": 3,
		"reason_key": "stack_limit", "lost_quantity": 5 }
	for c in ["leave", "path"]:
		var ctx := _ctx(_SEED_ALL, 8, 4)
		EarningsService.record_item(_stage(ctx), "s0", "a", _entry("ph_consumable_a", 8))
		var report: Dictionary
		if c == "leave":
			report = _leave(ctx)["result"]["items"]
		else:
			report = _settle_path(ctx, 5)["items"]
		var row := EarningsService.row_of(_stage(ctx), "item:s0:a")
		var e: Dictionary = (row["items"] as Array)[0]
		if int(e["quantity"]) != 3 or int(e["lost_quantity"]) != 5 or str(e["reason_key"]) != "stack_limit" or str(e["fate"]) != "carried":
			m.append("%s: entry %s" % [c, JSON.stringify(e)])
		if int(report["kept_count"]) != 1 or int(report["lost_count"]) != 0 or str((report["kept"] as Array)[0]) != str(want_row):
			m.append("%s: report %s" % [c, str(report)])
		var stacks: Array = _inv(ctx)["stacks"]
		if stacks.size() != 1 or int((stacks[0] as Dictionary)["quantity"]) != 3:
			m.append("%s: stacks %s" % [c, JSON.stringify(stacks)])
	return _result(m)


## Every `rejected` intake result is a lost entry with the intake reason, and its row ends with share 0.
static func _t_rejected_mapping() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_ALL, 8, 8)
	((ctx.config_service as _Cfg).inv["kinds_enabled"] as Dictionary)["consumable"] = false
	var stage := _stage(ctx)
	var unknown_kind := _entry("ph_weapon_a")
	unknown_kind["kind"] = "zzz"
	var unknown_type := _entry("nope")
	unknown_type["kind"] = "gear"
	EarningsService.record_item(stage, "s0", "k", unknown_kind)
	EarningsService.record_item(stage, "s0", "d", _entry("ph_consumable_a"))
	EarningsService.record_item(stage, "s0", "b", _entry("ph_weapon_a", 2))
	EarningsService.record_item(stage, "s0", "t", unknown_type)
	var got := _leave(ctx)
	var r: Dictionary = got["result"]
	var want := { "item:s0:b": "S-/lost/bad_entry", "item:s0:d": "S-/lost/kind_disabled",
		"item:s0:k": "S-/lost/unknown_kind", "item:s0:t": "S-/lost/unknown_type" }
	if str(r["outcome"]) != "all" or str(_row_fates(ctx)) != str(want):
		m.append("outcome %s, fates %s" % [str(r["outcome"]), str(_row_fates(ctx))])
	if int(r["items"]["kept_count"]) != 0 or int(r["items"]["lost_count"]) != 4:
		m.append("report %s" % str(r["items"]))
	var reasons: Array = []
	for row in r["items"]["lost"]:
		reasons.append(str((row as Dictionary)["reason_key"]))
	if str(reasons) != str(["unknown_kind", "kind_disabled", "bad_entry", "unknown_type"]):
		m.append("reported reasons %s" % str(reasons))
	for id in want:
		if int(EarningsService.row_of(stage, id)["settled_share"]) != 0:
			m.append("%s settled_share is not 0" % id)
	if not _item_ids(ctx).is_empty() or not _pack_ids(ctx).is_empty() or not (_inv(ctx)["stacks"] as Array).is_empty():
		m.append("a rejected entry reached the inventory")
	return _result(m)


## A leave with only held pieces returns the item report and the usual currency keys.
static func _t_held_only_result() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_SEED_SOME, 0, 4)
	_hold(ctx, 4)
	var r: Dictionary = _leave(ctx)["result"]
	var keys := r.keys()
	keys.sort()
	if str(keys) != str(["ase", "ekwan", "intel_count", "items", "outcome", "overcome", "total"]):
		m.append("keys %s" % str(keys))
	if str(r["outcome"]) != "some" or int(r["ase"]) != 0 or int(r["ekwan"]) != 0 or int(r["total"]) != 0:
		m.append("currency %s" % str(r))
	var items: Dictionary = r["items"]
	if int(items["kept_count"]) != 1 or int(items["lost_count"]) != 3 or (items["kept"] as Array).size() != 1 \
			or (items["lost"] as Array).size() != 3:
		m.append("items %s" % str(items))
	return _result(m)


## The defeat log carries `items` and `held` only when above 0; an item-free defeat logs the step 1 payload.
static func _t_defeat_log() -> Dictionary:
	var m: Array = []
	var objs := [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()]
	var ctx := _ctx(_SEED_ALL, 0, 4, objs)
	_add_rows(ctx, "s0", [0, 1])
	_hold(ctx, 2)
	var rows := ActiveStageService.lose_unsettled_packs(ctx, 3)
	var logs: Array = []
	for e in (ctx.logger as StructuredLogger).get_logs():
		if str(e["type"]) == "economy.earnings.lost":
			logs.append(e["data"])
	if rows != 3 or logs.size() != 1 or int(logs[0]["rows"]) != 3 or int(logs[0]["items"]) != 2 or int(logs[0]["held"]) != 2:
		m.append("rows %d, log %s" % [rows, str(logs)])
	var plain := _ctx(_SEED_ALL, 0, 4, objs)
	EconomyCharacterizationTests._gather(plain, 2, 12)
	var n := ActiveStageService.lose_unsettled_packs(plain, 3)
	var plain_logs: Array = []
	for e in (plain.logger as StructuredLogger).get_logs():
		if str(e["type"]) == "economy.earnings.lost":
			plain_logs.append(e["data"])
	if n != 4 or plain_logs.size() != 1 or str((plain_logs[0] as Dictionary).keys()) != str(["stage_id", "rows", "ase", "ekwan"]) \
			or int(plain_logs[0]["rows"]) != 4:
		m.append("item-free log %s" % str(plain_logs))
	return _result(m)
