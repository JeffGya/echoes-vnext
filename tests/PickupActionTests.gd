# res://tests/PickupActionTests.gd
# V2-ITEM-001b step C8: the seven pickup.* actions (PickupController) and their routing in FlowRuntime.dispatch.
# Fixtures come from PickupSnapshotTests / PickupStateTests (real events). The controller is driven directly;
# two tests go through the real dispatch: the labels are routed, and one successful action per label does its work.

class_name PickupActionTests
extends RefCounted

const _ALL: Array = [
	["pickup.skip", {}], ["pickup.select", { "find_id": "f0" }], ["pickup.swap.start", {}],
	["pickup.swap.pick", { "id": "it.2" }], ["pickup.swap.confirm", {}], ["pickup.swap.cancel", {}],
	["pickup.continue", {}],
]
const _DENIED := "inventory.pickup.denied"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_actions/every_action_is_refused_without_an_open_event", Callable(PickupActionTests, "_t_no_event"))
	runner.register_test("pickup_actions/every_action_is_refused_when_the_snapshot_is_not_pickup", Callable(PickupActionTests, "_t_not_pickup"))
	runner.register_test("pickup_actions/skip_moves_intro_to_idle_only", Callable(PickupActionTests, "_t_skip"))
	runner.register_test("pickup_actions/select_validates_like_the_snapshot", Callable(PickupActionTests, "_t_select"))
	runner.register_test("pickup_actions/select_is_refused_in_a_swap_phase", Callable(PickupActionTests, "_t_select_phase"))
	runner.register_test("pickup_actions/swap_start_from_a_find_and_from_a_pack_item", Callable(PickupActionTests, "_t_start"))
	runner.register_test("pickup_actions/swap_start_refusals", Callable(PickupActionTests, "_t_start_refused"))
	runner.register_test("pickup_actions/swap_pick_takes_a_legal_partner_of_either_side", Callable(PickupActionTests, "_t_pick"))
	runner.register_test("pickup_actions/swap_pick_refuses_twin_unknown_bad_payload_and_wrong_phase", Callable(PickupActionTests, "_t_pick_refused"))
	runner.register_test("pickup_actions/confirm_commits_one_swap_from_a_find_origin", Callable(PickupActionTests, "_t_confirm_find"))
	runner.register_test("pickup_actions/confirm_commits_one_swap_from_a_pack_origin", Callable(PickupActionTests, "_t_confirm_pack"))
	runner.register_test("pickup_actions/second_confirm_and_confirm_outside_preview_are_refused", Callable(PickupActionTests, "_t_confirm_refused"))
	runner.register_test("pickup_actions/cancel_returns_to_idle_from_pick_and_preview", Callable(PickupActionTests, "_t_cancel"))
	runner.register_test("pickup_actions/continue_ends_the_event_in_idle_only", Callable(PickupActionTests, "_t_continue"))
	runner.register_test("pickup_actions/repeat_snapshots_keep_the_event_identity", Callable(PickupActionTests, "_t_identity"))
	runner.register_test("pickup_actions/session_is_never_saved_and_only_a_swap_writes", Callable(PickupActionTests, "_t_save"))
	runner.register_test("pickup_actions/frozen_event_offers_no_swap", Callable(PickupActionTests, "_t_frozen"))
	runner.register_test("pickup_actions/labels_are_routed_by_the_real_dispatch", Callable(PickupActionTests, "_t_routing"))
	runner.register_test("pickup_actions/select_without_ids_closes_the_details", Callable(PickupActionTests, "_t_select_clear"))
	runner.register_test("pickup_actions/skip_closes_the_details", Callable(PickupActionTests, "_t_skip_clears"))
	runner.register_test("pickup_actions/a_taken_find_selected_by_find_id_starts_a_swap", Callable(PickupActionTests, "_t_taken_swap"))
	runner.register_test("pickup_actions/one_successful_action_per_label_through_the_real_dispatch", Callable(PickupActionTests, "_t_routing_success"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _norm(v: Variant) -> String:
	return ItemPacksTests._norm(v)


## Publishes the pickup snapshot for `session`, the way the hook will, and returns the context.
static func _live(ctx: FlowContext, session: Dictionary = {}) -> FlowContext:
	ctx.pickup_session = session
	ctx.last_snapshot = PickupSnapshotBuilder.build(ctx, 5, session)
	ctx.save_request = false
	return ctx


## Full pack, f0 (weapon) f1 (charm) on the field, it.1 (weapon) it.2 (relic) in the pack. Twin: f0 and it.1.
static func _mixed(session: Dictionary = {}) -> FlowContext:
	return _live(PickupSnapshotTests._mixed(), session)


static func _run(ctx: FlowContext, type: String, payload: Dictionary = {}, t: int = 7) -> FlowActionOutcome:
	var c := PickupController.new(ctx, ctx.config_service, ctx.logger)
	var a := { "type": type, "payload": payload }
	var o: FlowActionOutcome
	match type:
		"pickup.skip": o = c.handle_skip(a, t)
		"pickup.select": o = c.handle_select(a, t)
		"pickup.swap.start": o = c.handle_swap_start(a, t)
		"pickup.swap.pick": o = c.handle_swap_pick(a, t)
		"pickup.swap.confirm": o = c.handle_swap_confirm(a, t)
		"pickup.swap.cancel": o = c.handle_swap_cancel(a, t)
		_: o = c.handle_continue(a, t)
	if o.has_replacement_snapshot:
		ctx.last_snapshot = o.replacement_snapshot
	return o


static func _count(ctx: FlowContext, type: String) -> int:
	return PickupStateTests._log_types(ctx).count(type)


## "" when the action is refused with `key` and nothing changed: snapshot, session, save, save request, one log.
static func _refused(ctx: FlowContext, type: String, payload: Dictionary, key: String) -> String:
	var snap := _norm(ctx.last_snapshot)
	var sess := _norm(ctx.pickup_session)
	var save := _norm(ctx.save_data)
	var denied := _count(ctx, _DENIED)
	ctx.save_request = false
	var o := _run(ctx, type, payload)
	var why: Array = []
	if o.error_code != key:
		why.append("error_code '%s'" % o.error_code)
	if o.has_replacement_snapshot or _norm(ctx.last_snapshot) != snap:
		why.append("snapshot changed")
	if _norm(ctx.pickup_session) != sess:
		why.append("session changed")
	if _norm(ctx.save_data) != save or ctx.save_request:
		why.append("save touched")
	if _count(ctx, _DENIED) != denied + 1:
		why.append("no single denied log")
	return "" if why.is_empty() else "%s %s expected '%s': %s" % [type, str(payload), key, ", ".join(why)]


static func _data(ctx: FlowContext) -> Dictionary:
	return ctx.last_snapshot["data"]


static func _record(ctx: FlowContext) -> Dictionary:
	return PickupEventService.record_of(ItemPacksTests._stage(ctx))


## "" when the last snapshot shows `phase` and the session holds the same phase.
static func _at(ctx: FlowContext, phase: String) -> String:
	if str(_data(ctx)["phase"]) != phase or str(ctx.pickup_session.get("phase", "")) != phase:
		return "phase '%s' / session '%s', expected '%s'" % [_data(ctx)["phase"], ctx.pickup_session.get("phase", ""), phase]
	return ""


## Both-sides fixture where a find has no partner: pack it.1 and it.2 are weapons, f0 is a weapon, f1 a charm.
static func _lonely() -> FlowContext:
	var ctx := PickupStateTests._ctx(2, 2)
	ItemPacksTests._hold(ctx, 2, 1, "ph_weapon_a")
	PickupStateTests._open(ctx, PickupStateTests._finds(["ph_weapon_a", "ph_charm_a"]))
	return _live(ctx)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_no_event() -> Dictionary:
	var m: Array = []
	var ctx := PickupStateTests._ctx(2, 4)
	_live(ctx, { "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.2" })
	for a: Array in _ALL:
		var why := _refused(ctx, a[0], a[1], "no_event")
		if not why.is_empty():
			m.append(why)
	return _result(m)


static func _t_not_pickup() -> Dictionary:
	var m: Array = []
	var ctx := _mixed({ "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.2" })
	ctx.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE, "data": {}, "actions": {}, "meta": {} }
	for a: Array in _ALL:
		var why := _refused(ctx, a[0], a[1], "not_pickup")
		if not why.is_empty():
			m.append(why)
	if bool(ItemPacksTests._stage(ctx).get(PickupEventService.SWAP_KEY, false)):
		m.append("a swap was committed outside the pickup snapshot")
	return _result(m)


static func _t_skip() -> Dictionary:
	var m: Array = []
	var ctx := _mixed({ "phase": "intro" })
	if str(_data(ctx)["phase"]) != "intro":
		m.append("fixture is not in the intro")
	var o := _run(ctx, "pickup.skip")
	if o.error_code != "" or not o.has_replacement_snapshot:
		m.append("skip: error '%s', snapshot %s" % [o.error_code, str(o.has_replacement_snapshot)])
	var why := _at(ctx, "idle")
	if not why.is_empty():
		m.append("after skip: " + why)
	if not bool(_data(ctx)["finds"][0]["revealed"]):
		m.append("finds are still hidden after skip")
	for phase in ["idle", "swap_pick", "swap_preview"]:
		var c2 := _mixed({ "phase": phase, "swap_origin": "f1", "swap_target": "it.1" })
		var w := _refused(c2, "pickup.skip", {}, "wrong_phase")
		if not w.is_empty():
			m.append("skip in %s: %s" % [phase, w])
	return _result(m)


static func _t_select() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	for pair: Array in [["find_id", "f0", "find"], ["pack_id", "it.2", "pack"], ["find_id", "f1", "find"]]:
		var o := _run(ctx, "pickup.select", { pair[0]: pair[1] })
		var sel: Dictionary = _data(ctx)["selected"]
		if o.error_code != "" or str(sel.get("id", "")) != pair[1] or str(sel.get("side", "")) != pair[2]:
			m.append("select %s: error '%s', selected %s" % [pair[1], o.error_code, str(sel)])
		if str(ctx.pickup_session.get("selected", "")) != pair[1]:
			m.append("session selected '%s'" % ctx.pickup_session.get("selected", ""))
	var intro := _mixed({ "phase": "intro" })
	var w := _refused(intro, "pickup.select", { "find_id": "f0" }, "not_selectable")
	if not w.is_empty():
		m.append("hidden find in the intro: " + w)
	var o2 := _run(intro, "pickup.select", { "pack_id": "it.1" })
	if o2.error_code != "" or str(_data(intro)["selected"].get("id", "")) != "it.1" or str(_data(intro)["phase"]) != "intro":
		m.append("a pack item must be selectable in the intro and keep the intro: error '%s'" % o2.error_code)
	for c: Array in [[{ "find_id": "zz" }, "not_selectable"], [{ "pack_id": "zz" }, "not_selectable"],
			[{ "find_id": "it.1" }, "not_selectable"], [{ "pack_id": "f0" }, "not_selectable"],
			[{ "find_id": "f0", "pack_id": "it.1" }, "bad_payload"], [{ "find_id": 3 }, "bad_payload"],
			[{ "pack_id": 3 }, "bad_payload"], [{ "find_id": "", "pack_id": 3 }, "bad_payload"]]:
		var why := _refused(_mixed(), "pickup.select", c[0], c[1])
		if not why.is_empty():
			m.append(why)
	return _result(m)


static func _t_select_phase() -> Dictionary:
	var m: Array = []
	for s: Dictionary in [{ "phase": "swap_pick", "swap_origin": "f0" },
			{ "phase": "swap_preview", "swap_origin": "f1", "swap_target": "it.1" }]:
		var why := _refused(_mixed(s), "pickup.select", { "find_id": "f0" }, "wrong_phase")
		if not why.is_empty():
			m.append(why)
	return _result(m)


static func _t_start() -> Dictionary:
	var m: Array = []
	for c: Array in [["find", { "find_id": "f1" }, "f1"], ["pack", { "pack_id": "it.2" }, "it.2"]]:
		var ctx := _mixed()
		_run(ctx, "pickup.select", c[1])
		var o := _run(ctx, "pickup.swap.start")
		var why := _at(ctx, "swap_pick")
		if o.error_code != "" or not why.is_empty():
			m.append("%s origin: error '%s' %s" % [c[0], o.error_code, why])
		if str(_data(ctx)["swap"]["origin"]) != c[2] or str(ctx.pickup_session.get("swap_origin", "")) != c[2]:
			m.append("%s origin: swap.origin '%s'" % [c[0], _data(ctx)["swap"]["origin"]])
		if not _data(ctx)["selected"].is_empty():
			m.append("%s origin: details stay selected during the swap" % c[0])
	return _result(m)


static func _t_start_refused() -> Dictionary:
	var m: Array = []
	var why := _refused(_mixed(), "pickup.swap.start", {}, "not_selectable")
	if not why.is_empty():
		m.append("nothing selected: " + why)
	for s: Dictionary in [{ "phase": "intro" }, { "phase": "swap_pick", "swap_origin": "f1", "selected": "f1" }]:
		var ctx := _mixed(s)
		var w := _refused(ctx, "pickup.swap.start", {}, "wrong_phase")
		if not w.is_empty():
			m.append("phase %s: %s" % [s["phase"], w])
	# A find with no legal partner: both pack items are twins of it.
	var lonely := _lonely()
	_run(lonely, "pickup.select", { "find_id": "f0" })
	var w2 := _refused(lonely, "pickup.swap.start", {}, "no_target")
	if not w2.is_empty():
		m.append("find without partner: " + w2)
	# Not offered: the pack has room (C1).
	var roomy := _live(PickupSnapshotTests._event("C1")["ctx"])
	_run(roomy, "pickup.select", { "find_id": "f0" })
	var w3 := _refused(roomy, "pickup.swap.start", {}, "has_room")
	if not w3.is_empty():
		m.append("pack with room: " + w3)
	# Every pair is a twin: the swap is not offered ("same").
	var twins := _live(PickupSnapshotTests._event("twins")["ctx"])
	_run(twins, "pickup.select", { "find_id": "f0" })
	var w4 := _refused(twins, "pickup.swap.start", {}, "same")
	if not w4.is_empty():
		m.append("only twins: " + w4)
	# The swap of the path is spent.
	var used := _mixed()
	_swap(used, "f0", "it.2")
	_run(used, "pickup.select", { "find_id": "f1" })
	var w5 := _refused(used, "pickup.swap.start", {}, "used")
	if not w5.is_empty():
		m.append("swap already used: " + w5)
	return _result(m)


## Runs a whole swap through the actions: select origin, start, pick target, confirm.
static func _swap(ctx: FlowContext, origin: String, target: String) -> void:
	_run(ctx, "pickup.select", { ("find_id" if origin.begins_with("f") else "pack_id"): origin })
	_run(ctx, "pickup.swap.start")
	_run(ctx, "pickup.swap.pick", { "id": target })
	_run(ctx, "pickup.swap.confirm")


static func _t_pick() -> Dictionary:
	var m: Array = []
	for c: Array in [["find origin", "find_id", "f0", "it.2"], ["pack origin", "pack_id", "it.2", "f1"],
			["pack origin twin-free", "pack_id", "it.1", "f1"]]:
		var ctx := _mixed()
		_run(ctx, "pickup.select", { c[1]: c[2] })
		_run(ctx, "pickup.swap.start")
		var o := _run(ctx, "pickup.swap.pick", { "id": c[3] })
		var why := _at(ctx, "swap_preview")
		if o.error_code != "" or not why.is_empty():
			m.append("%s: error '%s' %s" % [c[0], o.error_code, why])
		var sw: Dictionary = _data(ctx)["swap"]
		if str(sw["origin"]) != c[2] or str(sw["target"]) != c[3]:
			m.append("%s: origin '%s' target '%s'" % [c[0], sw["origin"], sw["target"]])
		if not ctx.last_snapshot["actions"].has("cta.confirm"):
			m.append("%s: preview has no cta.confirm" % c[0])
	return _result(m)


static func _t_pick_refused() -> Dictionary:
	var m: Array = []
	var pick := { "phase": "swap_pick", "swap_origin": "f0" }
	for c: Array in [[pick, { "id": "it.1" }, "not_partner"], [pick, { "id": "f1" }, "not_partner"],
			[pick, { "id": "f0" }, "not_partner"], [pick, { "id": "zz" }, "not_partner"],
			[pick, {}, "bad_payload"], [pick, { "id": "" }, "bad_payload"], [pick, { "id": 4 }, "bad_payload"],
			[{ "phase": "idle" }, { "id": "it.2" }, "wrong_phase"], [{ "phase": "intro" }, { "id": "it.2" }, "wrong_phase"],
			[{ "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.2" }, { "id": "it.2" }, "wrong_phase"]]:
		var why := _refused(_mixed(c[0]), "pickup.swap.pick", c[1], c[2])
		if not why.is_empty():
			m.append(why)
	# From the pack side the twin is refused too.
	var why2 := _refused(_mixed({ "phase": "swap_pick", "swap_origin": "it.1" }), "pickup.swap.pick", { "id": "f0" }, "not_partner")
	if not why2.is_empty():
		m.append("pack origin, twin: " + why2)
	return _result(m)


static func _t_confirm_find() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	_run(ctx, "pickup.select", { "find_id": "f0" })
	_run(ctx, "pickup.swap.start")
	_run(ctx, "pickup.swap.pick", { "id": "it.2" })
	ctx.save_request = false
	var o := _run(ctx, "pickup.swap.confirm")
	m.append_array(_swapped(ctx, o, "f0", "it.2"))
	return _result(m)


static func _t_confirm_pack() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	_run(ctx, "pickup.select", { "pack_id": "it.2" })
	_run(ctx, "pickup.swap.start")
	_run(ctx, "pickup.swap.pick", { "id": "f0" })
	ctx.save_request = false
	var o := _run(ctx, "pickup.swap.confirm")
	m.append_array(_swapped(ctx, o, "f0", "it.2"))
	return _result(m)


## Messages (empty when fine) for a committed swap of `find_id` against `pack_id`.
static func _swapped(ctx: FlowContext, o: FlowActionOutcome, find_id: String, pack_id: String) -> Array:
	var m: Array = []
	if o.error_code != "" or not o.has_replacement_snapshot:
		m.append("confirm: error '%s'" % o.error_code)
	var why := _at(ctx, "idle")
	if not why.is_empty():
		m.append(why)
	var sw: Dictionary = _record(ctx).get("swap", {})
	if str(sw.get("find_id", "")) != find_id or str(sw.get("dropped_id", "")) != pack_id:
		m.append("record swap %s" % str(sw))
	if not PickupEventService.swap_used(ItemPacksTests._stage(ctx)):
		m.append("swap_used not set")
	if _count(ctx, "inventory.pickup.swap") != 1:
		m.append("swap logs: %d" % _count(ctx, "inventory.pickup.swap"))
	if not ctx.save_request:
		m.append("no save request")
	if not _data(ctx)["selected"].is_empty() or bool(_data(ctx)["swap"]["offered"]) or int(_data(ctx)["swap_left"]) != 0:
		m.append("selected / offered / swap_left not reset: %s" % str(_data(ctx)["swap"]))
	if str(_data(ctx)["swap"]["dropped"].get("id", "")) != pack_id:
		m.append("dropped %s" % str(_data(ctx)["swap"]["dropped"]))
	return m


static func _t_confirm_refused() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	_swap(ctx, "f0", "it.2")
	var why := _refused(ctx, "pickup.swap.confirm", {}, "wrong_phase")
	if not why.is_empty():
		m.append("second confirm: " + why)
	# A stale session cannot revive the used swap.
	ctx.pickup_session = { "phase": "swap_preview", "swap_origin": "f1", "swap_target": "it.1" }
	var why2 := _refused(ctx, "pickup.swap.confirm", {}, "wrong_phase")
	if not why2.is_empty():
		m.append("confirm on a stale preview session: " + why2)
	if _count(ctx, "inventory.pickup.swap") != 1:
		m.append("swap committed %d times" % _count(ctx, "inventory.pickup.swap"))
	for s: Dictionary in [{ "phase": "intro" }, { "phase": "idle" }, { "phase": "swap_pick", "swap_origin": "f0" }]:
		var w := _refused(_mixed(s), "pickup.swap.confirm", {}, "wrong_phase")
		if not w.is_empty():
			m.append("phase %s: %s" % [s["phase"], w])
	return _result(m)


static func _t_cancel() -> Dictionary:
	var m: Array = []
	for s: Dictionary in [{ "phase": "swap_pick", "swap_origin": "f0" },
			{ "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.2" }]:
		var ctx := _mixed(s)
		var o := _run(ctx, "pickup.swap.cancel")
		var why := _at(ctx, "idle")
		if o.error_code != "" or not why.is_empty():
			m.append("%s: error '%s' %s" % [s["phase"], o.error_code, why])
		if not _data(ctx)["swap"]["origin"].is_empty() or not _data(ctx)["swap"]["target"].is_empty():
			m.append("%s: origin or target kept" % s["phase"])
		if PickupEventService.swap_used(ItemPacksTests._stage(ctx)) or ctx.save_request:
			m.append("%s: cancel wrote" % s["phase"])
		if not ctx.last_snapshot["actions"].has("cta.swap"):
			m.append("%s: swap is not offered again after cancel" % s["phase"])
	for s: Dictionary in [{ "phase": "intro" }, { "phase": "idle" }]:
		var w := _refused(_mixed(s), "pickup.swap.cancel", {}, "wrong_phase")
		if not w.is_empty():
			m.append("phase %s: %s" % [s["phase"], w])
	return _result(m)


static func _t_continue() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	var rec := _record(ctx).duplicate(true)
	var save := _norm(ctx.save_data)
	ctx.pickup_session = { "phase": "idle", "selected": "f0" }
	# The fixture has no fight and no pending result: there is no held Resolve card, so nothing is published.
	var o := _run(ctx, "pickup.continue")
	if o.error_code != "" or o.has_replacement_snapshot or o.transition_to != "" or not o.save_reasons.is_empty():
		m.append("continue outcome: error '%s', snapshot %s, transition '%s'" % [o.error_code, str(o.has_replacement_snapshot), o.transition_to])
	if not ctx.pickup_session.is_empty():
		m.append("session not cleared: %s" % str(ctx.pickup_session))
	# C9: the only write is the durable end mark.
	rec["phase"] = PickupEventService.PHASE_DONE
	if _norm(_record(ctx)) != _norm(rec) or not ctx.save_request or not ctx.save_request_reason.contains("inventory.pickup.finish"):
		m.append("continue: record %s, save request %s '%s'" % [_norm(_record(ctx)), str(ctx.save_request), ctx.save_request_reason])
	# The whole save differs only by the end mark: undo it, compare, put it back.
	_record(ctx)["phase"] = PickupEventService.PHASE_IDLE
	if _norm(ctx.save_data) != save:
		m.append("continue wrote more than the end mark")
	_record(ctx)["phase"] = PickupEventService.PHASE_DONE
	for a: Array in _ALL:
		var ended := _refused(ctx, a[0], a[1], "ended")
		if not ended.is_empty():
			m.append("after the end: " + ended)
	if _count(ctx, "inventory.pickup.finish") != 1:
		m.append("finish logs: %d" % _count(ctx, "inventory.pickup.finish"))
	var fin := PickupController.new(ctx, ctx.config_service, ctx.logger).finish(8)
	var r := _record(ctx)
	if str(fin.get("situation_id", "")) != str(r["situation_id"]) or int(fin.get("run_count", -1)) != int(r["run_count"]) \
			or str(fin.get("return_to", "")) != FlowStateIds.STAGE_EXPLORE or bool(fin.get("swap_used", true)):
		m.append("finish result %s" % str(fin))
	for s: Dictionary in [{ "phase": "intro" }, { "phase": "swap_pick", "swap_origin": "f0" },
			{ "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.2" }]:
		var w := _refused(_mixed(s), "pickup.continue", {}, "wrong_phase")
		if not w.is_empty():
			m.append("phase %s: %s" % [s["phase"], w])
	var swapped := _mixed()
	_swap(swapped, "f0", "it.2")
	if not bool(PickupController.new(swapped, swapped.config_service, swapped.logger).finish(9)["swap_used"]):
		m.append("finish does not report the swap")
	return _result(m)


static func _t_identity() -> Dictionary:
	var m: Array = []
	var ctx := _mixed({ "phase": "intro" })
	var first := _data(ctx)
	var steps: Array = [["pickup.select", { "pack_id": "it.1" }], ["pickup.skip", {}], ["pickup.select", { "find_id": "f0" }],
		["pickup.swap.start", {}], ["pickup.swap.pick", { "id": "it.2" }], ["pickup.swap.cancel", {}]]
	for s: Array in steps:
		var o := _run(ctx, s[0], s[1])
		var d := _data(ctx)
		if o.error_code != "" or str(d["situation_id"]) != str(first["situation_id"]) or int(d["run_count"]) != int(first["run_count"]):
			m.append("%s: error '%s', identity %s/%s" % [s[0], o.error_code, d["situation_id"], d["run_count"]])
		if str(ctx.last_snapshot["type"]) != FlowStateIds.PICKUP:
			m.append("%s: type %s" % [s[0], ctx.last_snapshot["type"]])
	return _result(m)


static func _t_save() -> Dictionary:
	var m: Array = []
	var ctx := _mixed({ "phase": "intro" })
	var before := _norm(ctx.save_data)
	for s: Array in [["pickup.select", { "pack_id": "it.1" }], ["pickup.skip", {}], ["pickup.select", { "find_id": "f0" }],
			["pickup.swap.start", {}], ["pickup.swap.pick", { "id": "it.2" }], ["pickup.swap.cancel", {}]]:
		var o := _run(ctx, s[0], s[1])
		if o.error_code != "" or not o.save_reasons.is_empty() or ctx.save_request or _norm(ctx.save_data) != before:
			m.append("%s wrote: error '%s', save request %s" % [s[0], o.error_code, str(ctx.save_request)])
	if before.contains("swap_origin") or before.contains("pickup_session"):
		m.append("the session is in the save")
	# A swap writes its own rows and nothing else.
	var other := _norm([ctx.save_data["economy"], ctx.save_data["sanctum"]])
	_swap(ctx, "f0", "it.2")
	if _norm([ctx.save_data["economy"], ctx.save_data["sanctum"]]) != other:
		m.append("a swap changed the economy or the sanctum")
	if not ctx.save_request or not ctx.save_request_reason.contains("inventory.pickup.swap"):
		m.append("swap save reason '%s'" % ctx.save_request_reason)
	var after := _norm(ctx.save_data)
	if after.contains("swap_origin") or after.contains("pickup_session"):
		m.append("the session is in the save after a swap")
	return _result(m)


static func _t_frozen() -> Dictionary:
	var m: Array = []
	var ctx := _live(PickupSnapshotTests._event("frozen")["ctx"])
	if str(_data(ctx)["case"]) != "frozen":
		return _result(["fixture is not frozen: " + str(_data(ctx)["case"])])
	var o := _run(ctx, "pickup.select", { "find_id": "f0" })
	if o.error_code != "":
		m.append("a revealed find of a frozen event must be selectable: " + o.error_code)
	var why := _refused(ctx, "pickup.swap.start", {}, "frozen")
	if not why.is_empty():
		m.append(why)
	var forced := _live(PickupSnapshotTests._event("frozen")["ctx"], { "phase": "swap_pick", "swap_origin": "f0" })
	if str(_data(forced)["phase"]) != "idle":
		m.append("a frozen event kept a swap phase")
	var w := _refused(forced, "pickup.swap.confirm", {}, "wrong_phase")
	if not w.is_empty():
		m.append("confirm on a frozen event: " + w)
	return _result(m)


static func _t_routing() -> Dictionary:
	var m: Array = []
	var src := FileAccess.get_file_as_string("res://core/runtime/FlowRuntime.gd")
	for a: Array in _ALL:
		if not src.contains("\t\t\t\"%s\":\n" % a[0]):
			m.append("label %s is not a dispatch case" % a[0])
	var env := InventoryActionTests._env("pickup", 2, 2)
	var logger: StructuredLogger = env["logger"]
	for a: Array in _ALL:
		var flushes := InventoryActionTests._dispatch(env, { "type": a[0], "payload": a[1] })
		if InventoryActionTests._log_count(logger, _DENIED) != 1 or flushes != 0:
			m.append("%s: denied logs %d, flushes %d" % [a[0], InventoryActionTests._log_count(logger, _DENIED), flushes])
	InventoryActionTests._done(env)
	return _result(m)


static func _t_select_clear() -> Dictionary:
	var m: Array = []
	for phase in ["intro", "idle"]:
		for p: Dictionary in [{}, { "find_id": "" }, { "pack_id": "" }, { "find_id": "", "pack_id": "" }]:
			var ctx := _mixed({ "phase": phase })
			_run(ctx, "pickup.select", { "pack_id": "it.1" })
			if _data(ctx)["selected"].is_empty():
				m.append("%s: fixture did not select" % phase)
			var o := _run(ctx, "pickup.select", p)
			if o.error_code != "" or not o.has_replacement_snapshot:
				m.append("%s %s: error '%s'" % [phase, str(p), o.error_code])
			if not _data(ctx)["selected"].is_empty() or str(ctx.pickup_session.get("selected", "x")) != "":
				m.append("%s %s: details stay open: %s" % [phase, str(p), str(_data(ctx)["selected"])])
			if str(_data(ctx)["phase"]) != phase or str(ctx.pickup_session.get("phase", "")) != phase:
				m.append("%s %s: phase changed to '%s'" % [phase, str(p), _data(ctx)["phase"]])
	for s: Dictionary in [{ "phase": "swap_pick", "swap_origin": "f0" },
			{ "phase": "swap_preview", "swap_origin": "f1", "swap_target": "it.1" }]:
		var why := _refused(_mixed(s), "pickup.select", {}, "wrong_phase")
		if not why.is_empty():
			m.append("clear in %s: %s" % [s["phase"], why])
	return _result(m)


static func _t_skip_clears() -> Dictionary:
	var m: Array = []
	var ctx := _mixed({ "phase": "intro" })
	_run(ctx, "pickup.select", { "pack_id": "it.1" })
	if str(_data(ctx)["selected"].get("id", "")) != "it.1":
		m.append("fixture did not select in the intro")
	var o := _run(ctx, "pickup.skip")
	if o.error_code != "" or not _data(ctx)["selected"].is_empty() or str(ctx.pickup_session.get("selected", "x")) != "":
		m.append("skip kept the details: error '%s', selected %s" % [o.error_code, str(_data(ctx)["selected"])])
	return _result(m)


## C2: three finds, a pack of two. The test reads which finds the seam took, so it does not depend on the pick order.
static func _t_taken_swap() -> Dictionary:
	var m: Array = []
	var ctx := _live(PickupSnapshotTests._event("C2")["ctx"])
	var rec := _record(ctx)
	var taken: Array = rec["taken"]
	var left: Array = (rec["finds"] as Array).map(func(f: Dictionary) -> String: return str(f["find_id"])).filter(
		func(id: String) -> bool: return not taken.has(id))
	if taken.is_empty() or left.is_empty() or not bool(_data(ctx)["swap"]["offered"]):
		return _result(["fixture: taken %s, left %s, offered %s" % [str(taken), str(left), str(_data(ctx)["swap"]["offered"])]])
	var taken_id: String = taken[0]
	var left_id: String = left[0]
	var pack_id := EarningsService.item_id(str(rec["situation_id"]), taken_id)
	var o := _run(ctx, "pickup.select", { "find_id": taken_id })
	var sel: Dictionary = _data(ctx)["selected"]
	if o.error_code != "" or str(sel.get("id", "")) != taken_id or str(sel.get("side", "")) != "find":
		m.append("select taken find: error '%s', selected %s" % [o.error_code, str(sel)])
	o = _run(ctx, "pickup.swap.start")
	var why := _at(ctx, "swap_pick")
	if o.error_code != "" or not why.is_empty():
		m.append("swap.start from a taken find: error '%s' %s" % [o.error_code, why])
	if str(ctx.pickup_session.get("swap_origin", "")) != pack_id or str(_data(ctx)["swap"]["origin"]) != pack_id:
		m.append("origin is '%s', expected the pack id '%s'" % [ctx.pickup_session.get("swap_origin", ""), pack_id])
	o = _run(ctx, "pickup.swap.pick", { "id": left_id })
	if o.error_code != "" or not _at(ctx, "swap_preview").is_empty():
		m.append("swap.pick of a left find: error '%s' %s" % [o.error_code, _at(ctx, "swap_preview")])
	o = _run(ctx, "pickup.swap.confirm")
	if o.error_code != "" or not _at(ctx, "idle").is_empty():
		m.append("swap.confirm: error '%s' %s" % [o.error_code, _at(ctx, "idle")])
	var sw: Dictionary = _record(ctx).get("swap", {})
	if str(sw.get("find_id", "")) != left_id or str(sw.get("dropped_id", "")) != pack_id:
		m.append("record swap %s, expected find %s dropping %s" % [str(sw), left_id, pack_id])
	if _count(ctx, "inventory.pickup.swap") != 1:
		m.append("swap logs: %d" % _count(ctx, "inventory.pickup.swap"))
	var why2 := _refused(ctx, "pickup.swap.confirm", {}, "wrong_phase")
	if not why2.is_empty():
		m.append("second confirm: " + why2)
	return _result(m)


## The runtime of the dispatch tests: its context is the fixture, so the real dispatch drives the real controller.
## The machine stays in the Sanctum, so a refresh logs a tolerated debug `snapshot.mismatch`. The flush may
## fail on the fixture save; no assertion here reads it.
static func _routed(session: Dictionary) -> Dictionary:
	var ctx := _mixed(session)
	var env := InventoryActionTests._env("pickup_ok", 2, 2)
	var rt: FlowRuntime = env["rt"]
	rt.flow_ctx = ctx
	rt.config_service = ctx.config_service
	rt.logger = ctx.logger
	return { "env": env, "rt": rt, "ctx": ctx }


static func _t_routing_success() -> Dictionary:
	var m: Array = []
	var r := _routed({ "phase": "intro" })
	var rt: FlowRuntime = r["rt"]
	var ctx: FlowContext = r["ctx"]
	var steps: Array = [
		["pickup.select", { "pack_id": "it.1" }, "intro", "it.1"],
		["pickup.select", {}, "intro", ""],
		["pickup.select", { "pack_id": "it.1" }, "intro", "it.1"],
		["pickup.skip", {}, "idle", ""],
		["pickup.select", { "find_id": "f0" }, "idle", "f0"],
		["pickup.swap.start", {}, "swap_pick", ""],
		["pickup.swap.pick", { "id": "it.2" }, "swap_preview", ""],
		["pickup.swap.cancel", {}, "idle", ""],
		["pickup.select", { "find_id": "f0" }, "idle", "f0"],
		["pickup.swap.start", {}, "swap_pick", ""],
		["pickup.swap.pick", { "id": "it.2" }, "swap_preview", ""],
	]
	for s: Array in steps:
		rt.dispatch({ "type": s[0], "payload": s[1] })
		var why := _at(ctx, s[2])
		if not why.is_empty() or str(ctx.last_snapshot["type"]) != FlowStateIds.PICKUP:
			m.append("%s %s: %s, type %s" % [s[0], str(s[1]), why, ctx.last_snapshot["type"]])
		if str(_data(ctx)["selected"].get("id", "")) != s[3]:
			m.append("%s %s: selected '%s', expected '%s'" % [s[0], str(s[1]), _data(ctx)["selected"].get("id", ""), s[3]])
	if str(_data(ctx)["swap"]["origin"]) != "f0" or str(_data(ctx)["swap"]["target"]) != "it.2":
		m.append("preview pair %s" % str(_data(ctx)["swap"]))
	if _count(ctx, "inventory.pickup.swap") != 0:
		m.append("a swap was committed before confirm")
	rt.dispatch({ "type": "pickup.swap.confirm", "payload": {} })
	var why2 := _at(ctx, "idle")
	var sw: Dictionary = _record(ctx).get("swap", {})
	if not why2.is_empty() or str(sw.get("find_id", "")) != "f0" or str(sw.get("dropped_id", "")) != "it.2" \
			or _count(ctx, "inventory.pickup.swap") != 1:
		m.append("swap.confirm: %s, record swap %s, swap logs %d" % [why2, str(sw), _count(ctx, "inventory.pickup.swap")])
	rt.dispatch({ "type": "pickup.continue", "payload": {} })
	if not ctx.pickup_session.is_empty() or _count(ctx, "inventory.pickup.finish") != 1:
		m.append("continue: session %s, finish logs %d" % [str(ctx.pickup_session), _count(ctx, "inventory.pickup.finish")])
	if _count(ctx, _DENIED) != 0:
		m.append("a successful step was refused: %d denied logs" % _count(ctx, _DENIED))
	InventoryActionTests._done(r["env"])
	return _result(m)
