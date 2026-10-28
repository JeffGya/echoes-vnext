# res://tests/ItemPacksCharacterizationTests.gd
# V2-ITEM-001a step 1: characterization of the packs, the early-leave settle, the defeat loss and the
# path-end bank when no row holds an item. It pins today's behaviour. It changes no production code.
#
# A test marked
#   # KNOWN DEFECT (V2-ITEM-001a will change this):
# carries a defect. Step 4 of V2-ITEM-001a inverts that assertion. Do not invert it earlier.
# Report: docs/stories/v2-item-001/step1-characterization.md
#
# Fixtures come from EconomyCharacterizationTests (`_carry_ctx` and friends). Values: realm.01, run 0,
# shrine 30 Ase / 6 Ekwan, recover 24 / 5, protect 24 / 3, fight 6 / 0, five party Echoes (stipend 10).
# `_gather(ctx, n, found)` adds fight rows `enc:f0`.. and the found row `found:m0`.

class_name ItemPacksCharacterizationTests
extends RefCounted

# Realm seeds whose first stream `stage.settle.stage.0.0.0` rolls into each outcome (table 50 / 30 / 20):
# seed 0 rolls 0 (none), seed 1 rolls 57 (some), seed 2 rolls 90 (all).
const _SEED_NONE := 0
const _SEED_SOME := 1
const _SEED_ALL := 2
# Run count 1: seed 4 rolls 62 (some) on the stream `stage.settle.stage.0.1.1`.
const _SEED_RUN1 := 4

const _PH_ITEM := { "type": "ph_char_item", "quantity": 1 }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("item_packs_char/plan_with_zero_rows", Callable(ItemPacksCharacterizationTests, "_t_plan_zero_rows"))
	runner.register_test("item_packs_char/plan_with_objective_rows_only", Callable(ItemPacksCharacterizationTests, "_t_plan_objective_rows"))
	runner.register_test("item_packs_char/plan_with_fight_and_found_rows", Callable(ItemPacksCharacterizationTests, "_t_plan_fight_found"))
	runner.register_test("item_packs_char/leave_roll_fixed_seeds", Callable(ItemPacksCharacterizationTests, "_t_leave_fixed_seeds"))
	runner.register_test("item_packs_char/leave_second_settle_uses_next_stream", Callable(ItemPacksCharacterizationTests, "_t_leave_next_stream"))
	runner.register_test("item_packs_char/leave_nothing_new_and_repeat_draw_nothing", Callable(ItemPacksCharacterizationTests, "_t_leave_nothing_new"))
	runner.register_test("item_packs_char/defeat_loses_unsettled_keeps_kept_and_repeats_idempotent", Callable(ItemPacksCharacterizationTests, "_t_defeat"))
	runner.register_test("item_packs_char/path_end_pays_unsettled_once", Callable(ItemPacksCharacterizationTests, "_t_path_end_once"))
	runner.register_test("item_packs_char/path_end_pays_nothing_for_settled_or_lost_rows", Callable(ItemPacksCharacterizationTests, "_t_path_end_settled_lost"))
	runner.register_test("item_packs_char/add_row_rejects_empty_currency_and_duplicate_id", Callable(ItemPacksCharacterizationTests, "_t_add_row_rejects"))
	runner.register_test("item_packs_char/nothing_new_ignores_items", Callable(ItemPacksCharacterizationTests, "_t_nothing_new_ignores_items"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _three_objectives() -> Array:
	return [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._obj(1, "recover", true),
		EconomyCharacterizationTests._obj(2, "protect", true), EconomyCharacterizationTests._carry_boss()]


## A leave with a log that is kept: returns { result, leave_logs } (the `economy.settle.leave` entries).
static func _leave_logged(ctx: FlowContext, t: int = 1) -> Dictionary:
	var logger := StructuredLogger.new()
	var result := StageSettlementService.settle_leave(ctx, ctx.config_service,
		EconomyCharacterizationTests._carry_econ(ctx), 1.0, "test", logger, t)
	var hits: Array = []
	for e in logger.get_logs():
		if str(e["type"]) == "economy.settle.leave":
			hits.append(e["data"])
	return { "result": result, "leave_logs": hits }


static func _balance(ctx: FlowContext) -> String:
	var bal := ctx.save_data["economy"] as Dictionary
	return "%d/%d" % [int(bal["ase"]), int(bal["ekwan"])]


static func _row_flags(stage: Dictionary) -> Dictionary:
	var out := {}
	for r_v in EarningsService.rows_of(stage):
		var r: Dictionary = r_v
		out[str(r["id"])] = "%s%s" % ["S" if bool(r["settled"]) else "-", "L" if bool(r["lost"]) else "-"]
	return out


# ---------------------------------------------------------------------------
# 1. plan and settle_plan
# ---------------------------------------------------------------------------

## No row: nothing new, no ids, no counts. The boss stub has no row.
static func _t_plan_zero_rows() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0, [EconomyCharacterizationTests._carry_boss()])
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	var want := { "ase": 0, "ekwan": 0, "overcome": 0, "total": 0, "ids": [], "nothing_new": true, "settled_ase": 0,
		"settled_ekwan": 0, "rows": 0, "fight_rows": 0, "found_rows": 0, "settle_count": 0 }
	if str(plan) != str(want):
		m.append("settle_plan %s, expected %s" % [str(plan), str(want)])
	var packs := EarningsService.plan(EconomyCharacterizationTests._carry_stage(ctx), EconomyCharacterizationTests._rewards_cfg())
	if str(packs["ids"]) != "[]" or int(packs["scaled_ase"]) != 0 or int(packs["flat_ase"]) != 0 \
			or str(packs["sources"]) != str({ "objective": { "rows": 0, "ase": 0, "all": 0 },
				"encounter": { "rows": 0, "ase": 0, "all": 0 }, "found": { "rows": 0, "ase": 0, "all": 0 } }):
		m.append("EarningsService.plan %s, expected empty ids, zero sums and zero sources" % str(packs))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Two objective rows (shrine 30/6, recover 24/5): ids in write order, 54 Ase, 11 Ekwan, not nothing_new.
static func _t_plan_objective_rows() -> Dictionary:
	var m: Array = []
	var objs: Array = [EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._obj(1, "recover", true),
		EconomyCharacterizationTests._carry_boss()]
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0, objs)
	var before := JSON.stringify(ctx.save_data)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	var want := { "ase": 54, "ekwan": 11, "overcome": 2, "total": 2, "ids": ["obj:0:0", "obj:0:1"], "nothing_new": false,
		"settled_ase": 0, "settled_ekwan": 0, "rows": 2, "fight_rows": 0, "found_rows": 0, "settle_count": 0 }
	if str(plan) != str(want):
		m.append("settle_plan %s, expected %s" % [str(plan), str(want)])
	var packs := EarningsService.plan(EconomyCharacterizationTests._carry_stage(ctx), EconomyCharacterizationTests._rewards_cfg())
	if int(packs["scaled_ase"]) != 54 or int(packs["scaled_ekwan"]) != 11 or int(packs["flat_ase"]) != 0 \
			or str(packs["sources"]["objective"]) != str({ "rows": 2, "ase": 54, "all": 2 }):
		m.append("EarningsService.plan %s, expected scaled 54/11, flat 0, objective rows 2 ase 54 all 2" % str(packs))
	if JSON.stringify(ctx.save_data) != before:
		m.append("a plan changed the save")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Objective + two fights + a found row: ids in write order; a settled row leaves ids but stays in `all`.
static func _t_plan_fight_found() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0,
		[EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	EconomyCharacterizationTests._gather(ctx, 2, 12)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	var want := { "ase": 54, "ekwan": 6, "overcome": 1, "total": 1, "ids": ["obj:0:0", "enc:f0", "enc:f1", "found:m0"],
		"nothing_new": false, "settled_ase": 0, "settled_ekwan": 0, "rows": 4, "fight_rows": 2, "found_rows": 1, "settle_count": 0 }
	if str(plan) != str(want):
		m.append("settle_plan %s, expected %s" % [str(plan), str(want)])
	var stage := EconomyCharacterizationTests._carry_stage(ctx)
	EarningsService.mark_settled(stage, ["enc:f0"], 50)
	var packs := EarningsService.plan(stage, EconomyCharacterizationTests._rewards_cfg())
	if str(packs["ids"]) != str(["obj:0:0", "enc:f1", "found:m0"]) or int(packs["scaled_ase"]) != 48 \
			or str(packs["sources"]["encounter"]) != str({ "rows": 1, "ase": 6, "all": 2 }) \
			or str(packs["sources"]["found"]) != str({ "rows": 1, "ase": 12, "all": 1 }):
		m.append("after settling enc:f0 the packs read %s, expected 3 ids, 48 Ase, encounter rows 1 ase 6 all 2" % str(packs))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# 2. settle_leave
# ---------------------------------------------------------------------------

## Stream `stage.settle.stage.0.0.0` with realm seed 0, 1 and 2 gives roll 0, 57, 90: none, some, all.
## Gathered 78 Ase / 14 Ekwan (shrine + recover + protect). Pins outcome, paid amounts, marks and the log.
static func _t_leave_fixed_seeds() -> Dictionary:
	var m: Array = []
	# [seed, roll, outcome, ase, ekwan, share_pct]
	for c in [[_SEED_NONE, 0, "none", 0, 0, 0], [_SEED_SOME, 57, "some", 39, 7, 50], [_SEED_ALL, 90, "all", 78, 14, 100]]:
		var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0, _three_objectives(), int(c[0]))
		var got := _leave_logged(ctx)
		var r: Dictionary = got["result"]
		var st := EconomyCharacterizationTests._carry_stage(ctx)
		var tag := "seed %d" % int(c[0])
		if str(r["outcome"]) != c[2] or int(r["ase"]) != int(c[3]) or int(r["ekwan"]) != int(c[4]) \
				or int(r["overcome"]) != 3 or int(r["total"]) != 3:
			m.append("%s: result %s, expected %s paid %d/%d" % [tag, str(r), c[2], c[3], c[4]])
		if _balance(ctx) != "%d/%d" % [int(c[3]), int(c[4])]:
			m.append("%s: balance %s, expected %d/%d" % [tag, _balance(ctx), c[3], c[4]])
		var logs: Array = got["leave_logs"]
		if logs.size() != 1 or int((logs[0] as Dictionary)["roll"]) != int(c[1]) or str((logs[0] as Dictionary)["outcome"]) != c[2] \
				or int((logs[0] as Dictionary)["share_pct"]) != int(c[5]) or int((logs[0] as Dictionary)["settle_count"]) != 0 \
				or str((logs[0] as Dictionary)["marked_ids"]) != str(["obj:0:0", "obj:0:1", "obj:0:2"]):
			m.append("%s: leave log %s, expected roll %d, share %d, count 0, 3 marked ids" % [tag, str(logs), c[1], c[5]])
		for r_v in EarningsService.rows_of(st):
			if not bool((r_v as Dictionary)["settled"]) or int((r_v as Dictionary)["settled_share"]) != int(c[5]):
				m.append("%s: row %s, expected settled with share %d" % [tag, str(r_v), c[5]])
		if int(st["settle_count"]) != 1 or int(st["settled_ase"]) != int(c[3]) or int(st["settled_ekwan"]) != int(c[4]):
			m.append("%s: stage totals count %s ase %s ekwan %s" % [tag, str(st["settle_count"]), str(st["settled_ase"]), str(st["settled_ekwan"])])
		if StageSettlementService.settle_plan(ctx, ctx.config_service)["nothing_new"] != true:
			m.append("%s: the plan after the leave is not nothing_new" % tag)
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Run count 1 (replay factor), seed 4: the first leave uses `stage.settle.stage.0.1.0` (roll 0: none); a fight row won
## after it is a new row, and the second leave uses `stage.settle.stage.0.1.1` (roll 62: some, 1 Ase).
static func _t_leave_next_stream() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 1, _three_objectives(), _SEED_RUN1)
	var first := _leave_logged(ctx, 1)
	var first_log: Dictionary = (first["leave_logs"] as Array)[0] if (first["leave_logs"] as Array).size() == 1 else {}
	if int(first_log.get("settle_count", -1)) != 0 or int(first_log.get("roll", -1)) != 0 or str(first["result"]["outcome"]) != "none" \
			or int(first["result"]["ase"]) != 0 or int(first["result"]["ekwan"]) != 0:
		m.append("first leave %s, log %s" % [str(first["result"]), str(first_log)])
	EconomyCharacterizationTests._gather(ctx, 1, 0)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	if str(plan["ids"]) != str(["enc:f0"]) or int(plan["settle_count"]) != 1:
		m.append("plan after the new fight %s, expected ids [enc:f0] and settle_count 1" % str(plan))
	var second := _leave_logged(ctx, 2)
	var second_log: Dictionary = (second["leave_logs"] as Array)[0] if (second["leave_logs"] as Array).size() == 1 else {}
	if int(second_log.get("settle_count", -1)) != 1 or int(second_log.get("roll", -1)) != 62 \
			or str(second["result"]["outcome"]) != "some" or int(second["result"]["ase"]) != 1 or int(second["result"]["ekwan"]) != 0 \
			or str(second_log.get("marked_ids")) != str(["enc:f0"]):
		m.append("second leave %s, log %s" % [str(second["result"]), str(second_log)])
	if int(EconomyCharacterizationTests._carry_stage(ctx)["settle_count"]) != 2:
		m.append("settle_count %s, expected 2" % str(EconomyCharacterizationTests._carry_stage(ctx)["settle_count"]))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Nothing new: no roll log, no mark, no payment, no count, the save is byte-equal. A repeat call after a
## settle is nothing_new in the same way. (Also pinned in econ_char/settle_nothing_new_changes_nothing; this
## one adds the log and the repeat.)
static func _t_leave_nothing_new() -> Dictionary:
	var m: Array = []
	for objs in [[EconomyCharacterizationTests._carry_boss()],
			[EconomyCharacterizationTests._obj(0, "shrine", false), EconomyCharacterizationTests._carry_boss()]]:
		var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0, objs, _SEED_ALL)
		var before := JSON.stringify(ctx.save_data)
		var got := _leave_logged(ctx)
		if str(got["result"]["outcome"]) != "nothing_new" or int(got["result"]["ase"]) != 0 or int(got["result"]["ekwan"]) != 0 \
				or not (got["leave_logs"] as Array).is_empty() or JSON.stringify(ctx.save_data) != before:
			m.append("%s: %s, logs %s, expected nothing_new, no log and an equal save" % [JSON.stringify(objs), str(got["result"]), str(got["leave_logs"])])
	var ctx2 := EconomyCharacterizationTests._carry_ctx("realm.01", 0, _three_objectives(), _SEED_ALL)
	var first := _leave_logged(ctx2)
	var after_first := JSON.stringify(ctx2.save_data)
	var repeat := _leave_logged(ctx2, 2)
	if str(first["result"]["outcome"]) != "all" or str(repeat["result"]["outcome"]) != "nothing_new" \
			or int(repeat["result"]["ase"]) != 0 or not (repeat["leave_logs"] as Array).is_empty() \
			or JSON.stringify(ctx2.save_data) != after_first or _balance(ctx2) != "78/14":
		m.append("repeat after settle: %s, logs %s, balance %s, expected nothing_new, no log, an equal save and 78/14" \
			% [str(repeat["result"]), str(repeat["leave_logs"]), _balance(ctx2)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# 3. Defeat
# ---------------------------------------------------------------------------

## `lose_unsettled_packs` marks every unsettled row that is not kept on defeat as lost. A settled row and a
## kept row stay. A repeat marks nothing. The balance does not move.
static func _t_defeat() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0,
		[EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()], _SEED_ALL)
	EconomyCharacterizationTests._gather(ctx, 2, 12)
	var stage := EconomyCharacterizationTests._carry_stage(ctx)
	EarningsService.add_row(stage, EarningsService.make_row("keep:1", "found", "money", 5, 0, true, true))
	EarningsService.mark_settled(stage, ["enc:f0"], 50)
	var lost := ActiveStageService.lose_unsettled_packs(ctx, 3)
	var want := { "obj:0:0": "-L", "enc:f0": "S-", "enc:f1": "-L", "found:m0": "-L", "keep:1": "--" }
	if lost != 3 or str(_row_flags(stage)) != str(want):
		m.append("lost %d, flags %s, expected 3 and %s" % [lost, str(_row_flags(stage)), str(want)])
	if ActiveStageService.lose_unsettled_packs(ctx, 4) != 0 or str(_row_flags(stage)) != str(want):
		m.append("a repeat loss marked a row or changed the flags: %s" % str(_row_flags(stage)))
	if _balance(ctx) != "0/0":
		m.append("the defeat moved the balance to %s" % _balance(ctx))
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	if str(plan["ids"]) != str(["keep:1"]) or int(plan["ase"]) != 5 or bool(plan["nothing_new"]):
		m.append("plan after the defeat %s, expected only keep:1 with 5 Ase" % str(plan))
	# A stage with no row loses nothing.
	var empty := EconomyCharacterizationTests._carry_ctx("realm.01", 0, [EconomyCharacterizationTests._carry_boss()])
	if ActiveStageService.lose_unsettled_packs(empty, 5) != 0:
		m.append("an empty pack lost a row")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# 4. Path-end bank (StageSettlementService.settle)
# ---------------------------------------------------------------------------

## Path end pays every unsettled row once, plus the stipend (10 Ase, five Echoes): 54 + 10 Ase, 6 Ekwan.
## `settlement_receipt` stops the second call.
static func _t_path_end_once() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0,
		[EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	EconomyCharacterizationTests._gather(ctx, 2, 12)
	var econ := EconomyCharacterizationTests._carry_econ(ctx)
	var svc := StageSettlementService.new(ctx, ctx.config_service, econ, EconomyCharacterizationTests._logger())
	var paid := svc.settle(true, 5)
	if int(paid.get("ase_awarded", -1)) != 64 or int(paid.get("ekwan_awarded", -1)) != 6 or _balance(ctx) != "64/6":
		m.append("path end paid %s/%s, balance %s, expected 64/6" % [str(paid.get("ase_awarded")), str(paid.get("ekwan_awarded")), _balance(ctx)])
	var receipt: Dictionary = EconomyCharacterizationTests._carry_stage(ctx).get("settlement_receipt", {})
	if not bool(receipt.get("settled", false)) or str(receipt.get("result_id", "")) != "realm.01.stage.0" \
			or str(receipt.get("outcome", "")) != "cleared" or int(receipt.get("settled_t", -1)) != 5:
		m.append("receipt %s, expected settled, realm.01.stage.0, cleared, t 5" % str(receipt))
	var again := svc.settle(true, 6)
	if not again.is_empty() or _balance(ctx) != "64/6":
		m.append("a second settle returned %s and balance %s, expected {} and 64/6" % [str(again), _balance(ctx)])
	if not svc.preview().is_empty():
		m.append("preview after the receipt is not empty")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Path end pays nothing for a row settled by a leave or a row lost by a defeat. Only the stipend and rows
## written since remain.
static func _t_path_end_settled_lost() -> Dictionary:
	var m: Array = []
	# A leave settles 54/6 first (seed 2 rolls all). Path end then pays the stipend only.
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0,
		[EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()], _SEED_ALL)
	EconomyCharacterizationTests._gather(ctx, 2, 12)
	var left := _leave_logged(ctx)
	var paid := StageSettlementService.new(ctx, ctx.config_service, EconomyCharacterizationTests._carry_econ(ctx),
		EconomyCharacterizationTests._logger()).settle(true, 5)
	if str(left["result"]["outcome"]) != "all" or int(left["result"]["ase"]) != 54 or int(left["result"]["ekwan"]) != 6 \
			or int(paid.get("ase_awarded", -1)) != 10 or int(paid.get("ekwan_awarded", -1)) != 0 or _balance(ctx) != "64/6":
		m.append("leave then path end: leave %s, path end %s/%s, balance %s, expected 54/6, then the 10 stipend, balance 64/6" \
			% [str(left["result"]), str(paid.get("ase_awarded")), str(paid.get("ekwan_awarded")), _balance(ctx)])
	# A defeat loses the rows. Path end then pays the stipend only.
	var ctx2 := EconomyCharacterizationTests._carry_ctx("realm.01", 0,
		[EconomyCharacterizationTests._obj(0, "shrine", true), EconomyCharacterizationTests._carry_boss()])
	EconomyCharacterizationTests._gather(ctx2, 2, 12)
	ActiveStageService.lose_unsettled_packs(ctx2, 3)
	var paid2 := StageSettlementService.new(ctx2, ctx2.config_service, EconomyCharacterizationTests._carry_econ(ctx2),
		EconomyCharacterizationTests._logger()).settle(true, 5)
	if int(paid2.get("ase_awarded", -1)) != 10 or int(paid2.get("ekwan_awarded", -1)) != 0 or _balance(ctx2) != "10/0":
		m.append("defeat then path end paid %s/%s, balance %s, expected the 10 stipend only" \
			% [str(paid2.get("ase_awarded")), str(paid2.get("ekwan_awarded")), _balance(ctx2)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# 5 and 6. Known defects
# ---------------------------------------------------------------------------

## `add_row` rejects an empty id, a duplicate id and a row with 0 Ase and 0 Ekwan.
## KNOWN DEFECT (V2-ITEM-001a will change this): the 0 Ase / 0 Ekwan check (EarningsService.gd:49) also
## rejects a row that holds items. An item-only row must be accepted later; step 4 inverts the third
## assertion below. The empty-id and duplicate-id rejections stay.
static func _t_add_row_rejects() -> Dictionary:
	var m: Array = []
	var stage := { "index": 0 }
	var dup := EarningsService.make_row("x:1", "found", "money", 5, 0)
	if not EarningsService.add_row(stage, dup):
		m.append("the first add returned false")
	if EarningsService.add_row(stage, EarningsService.make_row("x:1", "found", "money", 9, 9)):
		m.append("a duplicate id was accepted")
	if EarningsService.add_row(stage, EarningsService.make_row("", "found", "money", 5, 0)):
		m.append("an empty id was accepted")
	# KNOWN DEFECT (V2-ITEM-001a will change this): an item-only row is rejected today.
	var item_row := EarningsService.make_row("item:1", "item", "ph_char_item", 0, 0)
	item_row["items"] = [_PH_ITEM.duplicate()]
	if EarningsService.add_row(stage, item_row):
		m.append("an item-only row was accepted; this characterization expects the rejection (step 4 inverts it)")
	var rows := EarningsService.rows_of(stage)
	if rows.size() != 1 or str((rows[0] as Dictionary)["id"]) != "x:1" or int((rows[0] as Dictionary)["ase"]) != 5:
		m.append("rows %s, expected only the first row x:1 with 5 Ase" % JSON.stringify(rows))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## A row with an item and 0 Ase / 0 Ekwan (built by hand, as `add_row` refuses it) is an unsettled row, so
## the plan lists its id and counts it in `rows`, but `nothing_new` ignores its items.
## KNOWN DEFECT (V2-ITEM-001a will change this): StageSettlementService.gd:295 reads only Ase and Ekwan,
## so a leave with only items gathered returns nothing_new, draws no roll and marks no row. Step 4 makes
## `nothing_new` count items. A defeat today does lose such a row (it is unsettled and not kept).
static func _t_nothing_new_ignores_items() -> Dictionary:
	var m: Array = []
	var ctx := EconomyCharacterizationTests._carry_ctx("realm.01", 0, [EconomyCharacterizationTests._carry_boss()], _SEED_ALL)
	var stage := EconomyCharacterizationTests._carry_stage(ctx)
	var row := EarningsService.make_row("item:1", "found", "ph_char_item", 0, 0)
	row["items"] = [_PH_ITEM.duplicate()]
	(stage["earnings"] as Array).append(row)
	var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
	# KNOWN DEFECT (V2-ITEM-001a will change this): nothing_new is true although an unsettled item row exists.
	if not bool(plan["nothing_new"]) or str(plan["ids"]) != str(["item:1"]) or int(plan["rows"]) != 1 \
			or int(plan["ase"]) != 0 or int(plan["ekwan"]) != 0:
		m.append("plan %s, expected nothing_new true, ids [item:1], rows 1, 0/0" % str(plan))
	var before := JSON.stringify(ctx.save_data)
	var got := _leave_logged(ctx)
	if str(got["result"]["outcome"]) != "nothing_new" or not (got["leave_logs"] as Array).is_empty() \
			or JSON.stringify(ctx.save_data) != before or bool(row["settled"]) or int(stage.get("settle_count", 0)) != 0:
		m.append("leave %s, logs %s: expected nothing_new, no roll, no mark, an equal save" % [str(got["result"]), str(got["leave_logs"])])
	if ActiveStageService.lose_unsettled_packs(ctx, 3) != 1 or not bool(row["lost"]):
		m.append("defeat did not lose the unsettled item row")
	return { "ok": m.is_empty(), "error": "; ".join(m) }
