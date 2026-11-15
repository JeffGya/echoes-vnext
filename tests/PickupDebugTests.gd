# res://tests/PickupDebugTests.gd
# V2-ITEM-001b step C10: the debug scenes of the pickup event (PickupDebug, DebugController): producer modes
# `event` and `arm`, `debug.pickup.scene.check|apply`, the forced count, the armed-finds rule, the "event now"
# Resolve card, and the console grammar. Most tests drive DebugController on a PickupStateTests context (five
# Echoes e0..e4, Standing 1..5, finds chance 100). Four tests go through the real dispatch.

class_name PickupDebugTests
extends RefCounted

const _IDS4: Array = ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a"]
const _CHECK := "debug.pickup.scene.check"
const _APPLY := "debug.pickup.scene.apply"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_debug/check_wrong_places_give_their_error_and_change_nothing", Callable(PickupDebugTests, "_t_places"))
	runner.register_test("pickup_debug/check_lists_the_setup_per_scene", Callable(PickupDebugTests, "_t_setup"))
	runner.register_test("pickup_debug/check_option_errors_change_nothing", Callable(PickupDebugTests, "_t_option_errors"))
	runner.register_test("pickup_debug/apply_without_confirm_changes_nothing", Callable(PickupDebugTests, "_t_apply_unconfirmed"))
	runner.register_test("pickup_debug/apply_with_confirm_sets_up_and_runs", Callable(PickupDebugTests, "_t_apply_confirmed"))
	runner.register_test("pickup_debug/event_mode_opens_now_with_defaults_and_a_fresh_situation", Callable(PickupDebugTests, "_t_event_defaults"))
	runner.register_test("pickup_debug/forced_count_is_capped_and_the_cap_override_works", Callable(PickupDebugTests, "_t_forced_count"))
	runner.register_test("pickup_debug/a_forced_count_on_a_loss_rank_opens_nothing", Callable(PickupDebugTests, "_t_loss_rank"))
	runner.register_test("pickup_debug/chooser_by_standing_by_id_and_fallen", Callable(PickupDebugTests, "_t_chooser"))
	runner.register_test("pickup_debug/held_and_swap_used_keys", Callable(PickupDebugTests, "_t_held"))
	runner.register_test("pickup_debug/bad_input_is_refused_with_a_key_and_changes_nothing", Callable(PickupDebugTests, "_t_bad_input"))
	runner.register_test("pickup_debug/arm_stores_the_finds_and_refuses_rank_and_fallen", Callable(PickupDebugTests, "_t_arm_unit"))
	runner.register_test("pickup_debug/event_now_continue_gives_a_resolve_card_then_the_path", Callable(PickupDebugTests, "_t_event_now_chain"))
	runner.register_test("pickup_debug/arm_then_a_real_won_fight_opens_the_event_with_the_real_rank", Callable(PickupDebugTests, "_t_arm_real_fight"))
	runner.register_test("pickup_debug/armed_finds_are_kept_when_a_win_opens_nothing", Callable(PickupDebugTests, "_t_armed_kept"))
	runner.register_test("pickup_debug/a_stamp_collision_opens_nothing_and_restores_the_save", Callable(PickupDebugTests, "_t_collision"))
	runner.register_test("pickup_debug/event_rows_carry_names_under_a_config_without_definitions", Callable(PickupDebugTests, "_t_names"))
	runner.register_test("pickup_debug/console_is_gated_to_debug_builds_and_parses_the_keys", Callable(PickupDebugTests, "_t_console"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Path view, five Echoes e0..e4 with Standing 1..5, cap `cap`, pack `pack`.
static func _ctx(cap: int = 2, pack: int = 4) -> FlowContext:
	var ctx := PickupStateTests._ctx(cap, pack)
	ctx.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE, "meta": { "t": 0 }, "data": {}, "actions": {} }
	var roster: Array = ctx.save_data["sanctum"]["roster"]
	for i in roster.size():
		(roster[i] as Dictionary)["rank"] = i + 1
	return ctx


static func _dbg(ctx: FlowContext) -> DebugController:
	return DebugController.new(ctx, ctx.config_service, ctx.logger)


static func _hash(ctx: FlowContext) -> String:
	return JSON.stringify(ctx.save_data, "", true)


static func _stage(ctx: FlowContext) -> Dictionary:
	return FlowStageExploreState._get_current_stage(ctx)


static func _record(ctx: FlowContext) -> Dictionary:
	return PickupEventService.record_of(_stage(ctx))


## The data of the newest log line of `type`, {} when none.
static func _log(logger: StructuredLogger, type: String) -> Dictionary:
	var logs := logger.get_logs()
	for i in range(logs.size() - 1, -1, -1):
		if str((logs[i] as Dictionary)["type"]) == type:
			return (logs[i] as Dictionary)["data"]
	return {}


static func _check(ctx: FlowContext, scene: String, options: Dictionary = {}, t: int = 40) -> Dictionary:
	_dbg(ctx).handle_pickup_scene_check({ "type": _CHECK, "payload": { "scene": scene, "options": options } }, t)
	return _log(ctx.logger, _CHECK)


static func _apply(ctx: FlowContext, scene: String, options: Dictionary, confirm: Variant, t: int = 41) -> FlowActionOutcome:
	var payload := { "scene": scene, "options": options }
	if confirm != null:
		payload["confirm"] = confirm
	return _dbg(ctx).handle_pickup_scene_apply({ "type": _APPLY, "payload": payload }, t)


static func _produce(ctx: FlowContext, mode: String, extra: Dictionary = {}, t: int = 42) -> FlowActionOutcome:
	var payload := { "mode": mode }
	payload.merge(extra)
	var o := _dbg(ctx).handle_inventory_produce({ "type": "debug.inventory.produce", "payload": payload }, t)
	if o.has_replacement_snapshot:
		ctx.last_snapshot = o.replacement_snapshot
	return o


## The armed options without the names map.
static func _opts(ctx: FlowContext) -> Dictionary:
	var o := ctx.pickup_armed_opts.duplicate()
	o.erase("names")
	return o


static func _unchanged(ctx: FlowContext, before: String, what: String, m: Array) -> void:
	if _hash(ctx) != before or ctx.save_request or not ctx.pickup_session.is_empty():
		m.append("%s changed the save, requested a save or set a session" % what)


# ---------------------------------------------------------------------------
# scene.check: places, setup, option errors
# ---------------------------------------------------------------------------

static func _t_places() -> Dictionary:
	var m: Array = []
	var cases := [
		[FlowStateIds.SANCTUM, "wrong_place", "Needs the path view. You are in the Sanctum."],
		[FlowStateIds.ENCOUNTER, "wrong_place", "Needs the path view. You are in a fight."],
		[FlowStateIds.RESOLVE, "wrong_place", "Needs the path view. You are in a result card."],
		[FlowStateIds.STAGE_MAP, "wrong_place", "Needs the path view. You are in the stage map."],
		[FlowStateIds.PICKUP, "event_open", "A pickup event is already open. Finish it first."],
		["flow.nowhere", "wrong_place", "Needs the path view. You are in an unknown screen (flow.nowhere)."],
	]
	for scene in PickupDebug.SCENES:
		for c in cases:
			var ctx := _ctx()
			ctx.last_snapshot["type"] = c[0]
			var before := _hash(ctx)
			var rep := _check(ctx, scene)
			if bool(rep.get("ok", true)) or not (rep.get("errors", []) as Array).has(c[2]) or not (rep.get("keys", []) as Array).has(c[1]):
				m.append("%s in '%s': expected '%s', got %s" % [scene, c[0], c[2], str(rep)])
			_unchanged(ctx, before, "%s check in '%s'" % [scene, c[0]], m)
		var live := _ctx()
		live.stage_id = ""
		var rep_live := _check(live, scene)
		if not (rep_live.get("keys", []) as Array).has("no_live_path") or not (rep_live.get("errors", []) as Array).has("Needs a live path. Begin a path in a realm first."):
			m.append("%s with no stage id: %s" % [scene, str(rep_live)])
		var no_realm := _ctx()
		no_realm.realm_id = ""
		if not (_check(no_realm, scene).get("keys", []) as Array).has("no_live_path"):
			m.append("%s with no realm gave no no_live_path" % scene)
		var empty := _ctx()
		empty.save_data["sanctum"]["active_party_ids"] = []
		var before_empty := _hash(empty)
		var rep_empty := _check(empty, scene)
		if not (rep_empty.get("errors", []) as Array).has("Needs at least one Echo in the party."):
			m.append("%s with no party: %s" % [scene, str(rep_empty)])
		_unchanged(empty, before_empty, "%s no-party check" % scene, m)
		var good := _ctx()
		var rep_good := _check(good, scene)
		if not bool(rep_good.get("ok", false)) or not (rep_good["errors"] as Array).is_empty() or (rep_good["setup"] as Array).is_empty():
			m.append("%s at the path view should be ready with a setup list: %s" % [scene, str(rep_good)])
	return _result(m)


static func _t_setup() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var before := _hash(ctx)
	var rep := _check(ctx, "event_now", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 2, "chooser_standing": 3,
		"held": ["ph_relic_a"], "swap_used": true, "frozen": true })
	var ids: Array = (rep.get("setup", []) as Array).map(func(r: Dictionary) -> String: return str(r["id"]))
	if str(ids) != str(["fear", "held", "swap_used", "finds"]):
		m.append("event_now rows %s" % str(ids))
	else:
		var rows: Array = rep["setup"]
		if str((rows[0] as Dictionary)["commands"]) != str(["emotion set e2 fear 95", "emotion set e2 morale 0"]):
			m.append("fear commands %s" % str((rows[0] as Dictionary)["commands"]))
		var want := "inventory produce event ids=ph_weapon_a,ph_charm_a count=2 rank=B standing=3 held=ph_relic_a swapused"
		if str((rows[3] as Dictionary)["commands"]) != str([want]) or str((rows[1] as Dictionary)["commands"]) != str([want]):
			m.append("run command %s, want %s" % [str((rows[3] as Dictionary)["commands"]), want])
		if not bool((rows[3] as Dictionary)["saves"]) or str((rows[1] as Dictionary)["text"]).is_empty():
			m.append("rows need text and the saves flag: %s" % str(rows))
	var arm := _check(ctx, "arm", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 2, "cap": 3 })
	var arm_rows: Array = arm.get("setup", [])
	if arm_rows.size() != 1 or str((arm_rows[0] as Dictionary)["id"]) != "finds" or bool((arm_rows[0] as Dictionary)["saves"]) \
			or str((arm_rows[0] as Dictionary)["commands"]) != str(["inventory produce arm ids=ph_weapon_a,ph_charm_a count=2 cap=3"]):
		m.append("arm rows %s" % str(arm_rows))
	var full := _check(ctx, "event_now", { "full_pack": true })
	var held_rows: Array = (full.get("setup", []) as Array).filter(func(r: Dictionary) -> bool: return str(r["id"]) == "held")
	if held_rows.size() != 1 or not str((held_rows[0] as Dictionary)["text"]).begins_with("Put 4 piece(s)"):
		m.append("full_pack should list 4 pieces (pack of 4): %s" % str(full))
	_unchanged(ctx, before, "the setup checks", m)
	return _result(m)


static func _t_option_errors() -> Dictionary:
	var m: Array = []
	var cases := [
		["event_now", { "count": 0 }, "bad_count"], ["event_now", { "cap": 0 }, "bad_cap"], ["event_now", { "rank": "Z" }, "bad_rank"],
		["event_now", { "rank": "F" }, "loss_rank"], ["event_now", { "ids": ["nope"] }, "unknown_id"],
		["event_now", { "ids": "ph_weapon_a" }, "bad_ids"], ["event_now", { "chooser_standing": 99 }, "no_such_standing"],
		["event_now", { "chooser_standing": 2, "chooser_id": "e0" }, "chooser_conflict"], ["event_now", { "chooser_id": "zz" }, "bad_chooser"],
		["event_now", { "fallen": "zz" }, "bad_fallen"], ["event_now", { "frozen": true }, "frozen_needs_chooser"],
		["event_now", { "held": ["ph_weapon_a", "ph_weapon_a", "ph_weapon_a", "ph_weapon_a", "ph_weapon_a"] }, "pack_room"],
		["arm", { "frozen": true, "chooser_standing": 2 }, "frozen_not_for_arm"], ["event_now", { "count": 13 }, "count_too_big"],
		["event_now", { "cap": 13 }, "cap_too_big"], ["event_now", { "ids": [] }, "bad_ids"],
		["event_now", { "ids": ["ph_weapon_a"], "count": 2 }, "count_exceeds_ids"], ["arm", { "ids": ["ph_weapon_a"], "count": 2 }, "count_exceeds_ids"],
		["arm", { "rank": "S" }, "rank_not_allowed"], ["arm", { "fallen": "e1" }, "fallen_not_allowed"], ["arm", { "count": -3 }, "bad_count"],
		["nothing", {}, ""],
	]
	for c in cases:
		var ctx := _ctx()
		var before := _hash(ctx)
		if c[0] == "nothing":
			_dbg(ctx).handle_pickup_scene_check({ "type": _CHECK, "payload": { "scene": "bogus" } }, 40)
			if not _log(ctx.logger, "debug.pickup.scene.denied").get("reason_key", "") == "bad_scene":
				m.append("an unknown scene is not denied with bad_scene")
		else:
			var rep := _check(ctx, c[0], c[1])
			if bool(rep.get("ok", true)) or not (rep.get("keys", []) as Array).has(c[2]):
				m.append("%s %s: expected key %s, got %s" % [c[0], str(c[1]), c[2], str(rep)])
		_unchanged(ctx, before, "%s %s" % [c[0], str(c[1])], m)
	return _result(m)


# ---------------------------------------------------------------------------
# scene.apply
# ---------------------------------------------------------------------------

static func _t_apply_unconfirmed() -> Dictionary:
	var m: Array = []
	for confirm in [null, false, "yes", 1, "true"]:
		var ctx := _ctx()
		var before := _hash(ctx)
		var o := _apply(ctx, "event_now", { "ids": ["ph_weapon_a"], "count": 1, "frozen": true, "chooser_standing": 2, "held": ["ph_relic_a"] }, confirm)
		_unchanged(ctx, before, "apply with confirm %s" % str(confirm), m)
		if o.has_replacement_snapshot or not o.save_reasons.is_empty() or o.error_code != "" or not _record(ctx).is_empty():
			m.append("apply with confirm %s ran or errored: %s / %s" % [str(confirm), o.error_code, str(o.save_reasons)])
		var rep := _log(ctx.logger, _APPLY)
		if bool(rep.get("applied", true)) or (rep.get("setup", []) as Array).is_empty():
			m.append("apply with confirm %s should log applied=false and the setup list: %s" % [str(confirm), str(rep)])
		var e1: Dictionary = (ctx.save_data["sanctum"]["roster"] as Array)[1]
		if (e1.get("emotion", {}) as Dictionary).get("fear_current", 0) == 95:
			m.append("the fear was set without a yes")
	var armed := _ctx()
	_apply(armed, "arm", { "ids": ["ph_weapon_a"] }, null)
	if not armed.pickup_armed.is_empty():
		m.append("arm was armed without a yes")
	var wrong := _ctx()
	wrong.last_snapshot["type"] = FlowStateIds.SANCTUM
	var before_wrong := _hash(wrong)
	var o_wrong := _apply(wrong, "event_now", {}, true)
	if o_wrong.error_code != "wrong_place" or o_wrong.has_replacement_snapshot or _hash(wrong) != before_wrong or not _record(wrong).is_empty():
		m.append("a confirmed apply in the wrong place must error and change nothing: '%s'" % o_wrong.error_code)
	return _result(m)


static func _t_apply_confirmed() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var o := _apply(ctx, "event_now", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 2, "chooser_standing": 3, "frozen": true,
		"held": ["ph_relic_a"] }, true)
	var rec := _record(ctx)
	var e2: Dictionary = (ctx.save_data["sanctum"]["roster"] as Array)[2]
	var emo: Dictionary = e2.get("emotion", {})
	if int(emo.get("fear_current", -1)) != 95 or int(emo.get("morale_current", -1)) != 0:
		m.append("the frozen setup did not set fear 95 and morale 0: %s" % str(emo))
	if not o.has_replacement_snapshot or str(o.replacement_snapshot.get("type", "")) != FlowStateIds.PICKUP \
			or not o.save_reasons.has("debug.pickup.event_now"):
		m.append("apply did not publish flow.pickup with a save reason: %s" % str(o.save_reasons))
	if rec.is_empty() or str(rec.get("chooser", "")) != "e2" or (InventoryService.held_pieces(ctx.save_data) as Array).size() != 1:
		m.append("the event or the held piece is missing: chooser '%s'" % str(rec.get("chooser", "")))
	if not bool(_log(ctx.logger, _APPLY).get("applied", false)):
		m.append("the apply log should say applied")
	if not o.save_reasons.has("debug.pickup.scene.apply"):
		m.append("the frozen writes need a save reason: %s" % str(o.save_reasons))
	_frozen_log_matches(ctx, rec, "standing 3", m)
	var calm := _ctx(2, 4)
	_apply(calm, "event_now", { "ids": ["ph_weapon_a"], "count": 1, "chooser_standing": 5, "frozen": true }, true)
	_frozen_log_matches(calm, _record(calm), "standing 5", m)
	var arm_frozen := _ctx()
	var before_af := _hash(arm_frozen)
	var o_af := _apply(arm_frozen, "arm", { "frozen": true, "chooser_standing": 2 }, true)
	if o_af.error_code != "frozen_not_for_arm" or _hash(arm_frozen) != before_af or not arm_frozen.pickup_armed.is_empty():
		m.append("arm with frozen must be refused with frozen_not_for_arm: '%s'" % o_af.error_code)
	var arm := _ctx(2, 4)
	var o_arm := _apply(arm, "arm", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 1 }, true)
	if arm.pickup_armed.size() != 2 or int(arm.pickup_armed_opts.get("count", 0)) != 1 or not _record(arm).is_empty() or o_arm.has_replacement_snapshot:
		m.append("a confirmed arm should arm 2 finds with count 1 and open nothing: %s" % str(arm.pickup_armed_opts))
	return _result(m)


## The log `debug.pickup.scene.frozen_not_reached` exists exactly when the record is not frozen.
static func _frozen_log_matches(ctx: FlowContext, rec: Dictionary, label: String, m: Array) -> void:
	var logged := not _log(ctx.logger, "debug.pickup.scene.frozen_not_reached").is_empty()
	if rec.is_empty() or logged == bool(rec.get("frozen", false)):
		m.append("%s: frozen=%s but the frozen_not_reached line is %s" % [label, str(rec.get("frozen", "?")), "present" if logged else "absent"])


# ---------------------------------------------------------------------------
# Producer: event mode
# ---------------------------------------------------------------------------

static func _t_event_defaults() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(3, 6)
	var o := _produce(ctx, "event", { "ids": ["ph_weapon_a", "ph_charm_a", "ph_relic_a"], "count": 3 }, 42)
	var rec := _record(ctx)
	if o.error_code != "" or str(ctx.last_snapshot.get("type", "")) != FlowStateIds.PICKUP \
			or str((ctx.last_snapshot["data"] as Dictionary).get("phase", "")) != PickupSnapshotBuilder.PHASE_INTRO \
			or str(ctx.pickup_session.get("phase", "")) != PickupSnapshotBuilder.PHASE_INTRO:
		m.append("the event did not publish the intro: '%s' / %s" % [o.error_code, str(ctx.pickup_session)])
	if str(rec.get("situation_id", "")) != "debug.1" or str(rec.get("rank", "")) != "B" or not bool(rec.get("debug_event", false)) \
			or str(rec.get("return_to", "")) != FlowStateIds.STAGE_EXPLORE or (rec.get("finds", []) as Array).size() != 3 \
			or str(rec.get("phase", "")) != PickupEventService.PHASE_IDLE:
		m.append("record %s" % JSON.stringify(rec))
	if not o.save_reasons.has("debug.pickup.event_now"):
		m.append("no save reason")
	# A second event after the first one ended gets its own situation id.
	var fin := PickupController.new(ctx, ctx.config_service, ctx.logger).finish(43)
	ctx.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE, "meta": { "t": 43 }, "data": {}, "actions": {} }
	_produce(ctx, "event", { "ids": ["ph_weapon_a"], "count": 1 }, 44)
	if str(fin["situation_id"]) != "debug.1" or str(_record(ctx).get("situation_id", "")) != "debug.2" or int(_stage(ctx).get(PickupDebug.SEQ_KEY, 0)) != 2 or str(_record(ctx).get("phase", "")) != "idle":
		m.append("the second event kept the old stamp: %s" % str(_record(ctx).get("situation_id", "")))
	# An event while one is open is refused.
	var open_o := _produce(ctx, "event", {}, 45)
	if open_o.error_code != "event_open":
		m.append("an event over an open one gave '%s'" % open_o.error_code)
	return _result(m)


static func _t_forced_count() -> Dictionary:
	var m: Array = []
	var capped := _ctx(2, 6)
	_produce(capped, "event", { "ids": _IDS4, "count": 4 })
	var crec := _record(capped)
	if (crec.get("finds", []) as Array).size() != 2:
		m.append("count 4 on a realm cap of 2 should offer 2, got %d" % (crec.get("finds", []) as Array).size())
	var refused := int(_log(capped.logger, "economy.earnings.over_cap").get("refused", 0))
	if refused != 2:
		m.append("the seam should refuse 2 finds with over_cap, refused %d" % refused)
	var offered: Array = (crec.get("taken", []) as Array) + (crec.get("left", []) as Array)
	var fids: Array = (crec.get("finds", []) as Array).map(func(f: Dictionary) -> String: return str(f["find_id"]))
	var order: Array = crec.get("order", [])
	offered.sort()
	fids.sort()
	var order_sorted := order.duplicate()
	order_sorted.sort()
	if offered != fids or order_sorted != fids:
		m.append("offered ids %s, finds %s, pick order %s must be the same two finds" % [str(offered), str(fids), str(order)])
	var over := _ctx(2, 6)
	_produce(over, "event", { "ids": _IDS4, "count": 4, "cap": 4 })
	var rec := _record(over)
	if (rec.get("finds", []) as Array).size() != 4 or (_log(over.logger, "economy.earnings.over_cap")).size() != 0:
		m.append("cap=4 should offer 4 finds with no over_cap, got %d" % (rec.get("finds", []) as Array).size())
	var rolled := _ctx(3, 6)
	_produce(rolled, "event", { "ids": _IDS4, "cap": 3 })
	if (_record(rolled).get("finds", []) as Array).size() != 3:
		m.append("count absent with cap=3 and chance 100 should roll 3, got %d" % (_record(rolled).get("finds", []) as Array).size())
	var plain := _ctx(2, 6)
	var direct := PickupEventService.open_after_win(plain, "sx", "S", [], FlowStateIds.STAGE_EXPLORE,
		PickupStateTests._finds(_IDS4), 9)
	if (direct.get("finds", []) as Array).size() != 2:
		m.append("no debug input must keep the rolled count (cap 2), got %d" % (direct.get("finds", []) as Array).size())
	return _result(m)


static func _t_loss_rank() -> Dictionary:
	var m: Array = []
	var finds := PickupStateTests._finds(_IDS4)
	var ctx := _ctx(2, 6)
	var before := _hash(ctx)
	for rank in ["F", "Z", ""]:
		var rec := PickupEventService.open_after_win(ctx, "lx", rank, [], FlowStateIds.STAGE_EXPLORE, finds, 9, { "count": 2 })
		if not rec.is_empty():
			m.append("a forced count on loss rank '%s' opened an event" % rank)
	var zero := PickupEventService.open_after_win(ctx, "lx", "S", [], FlowStateIds.STAGE_EXPLORE, finds, 9, { "count": 0 })
	if not zero.is_empty():
		m.append("a forced count of 0 opened an event")
	if _hash(ctx) != before or ctx.save_request or not _stage(ctx).get("pickup", {}).is_empty():
		m.append("a refused forced count wrote to the save")
	var win := PickupEventService.open_after_win(ctx, "lx", "S", [], FlowStateIds.STAGE_EXPLORE, finds, 9, { "count": 2 })
	if (win.get("finds", []) as Array).size() != 2:
		m.append("the same call on a win rank should open 2 finds")
	return _result(m)


static func _t_chooser() -> Dictionary:
	var m: Array = []
	for pair in [[1, "e0"], [3, "e2"], [5, "e4"]]:
		var ctx := _ctx(2, 6)
		_produce(ctx, "event", { "ids": ["ph_weapon_a"], "chooser_standing": pair[0] })
		if str(_record(ctx).get("chooser", "")) != pair[1]:
			m.append("standing=%d chose '%s', expected %s" % [pair[0], str(_record(ctx).get("chooser", "")), pair[1]])
	var by_id := _ctx(2, 6)
	_produce(by_id, "event", { "ids": ["ph_weapon_a"], "chooser_id": "e1" })
	if str(_record(by_id).get("chooser", "")) != "e1":
		m.append("chooser=e1 chose '%s'" % str(_record(by_id).get("chooser", "")))
	var fallen := _ctx(2, 6)
	_produce(fallen, "event", { "ids": ["ph_weapon_a"], "fallen": "e2" })
	var rec := _record(fallen)
	if (rec.get("standing_ids", []) as Array).has("e2") or not (rec.get("fallen_names", []) as Array).has("Echo 2") or str(rec.get("chooser", "")) == "e2":
		m.append("fallen=e2 should leave e2 out of the standing list: %s" % str(rec.get("standing_ids", [])))
	var gone := _ctx(2, 6)
	var o := _produce(gone, "event", { "ids": ["ph_weapon_a"], "fallen": "e2", "chooser_standing": 3 })
	if o.error_code != "no_such_standing" or not _record(gone).is_empty():
		m.append("standing=3 with e2 fallen gave '%s'" % o.error_code)
	return _result(m)


static func _t_held() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	_produce(ctx, "event", { "ids": ["ph_weapon_a"], "count": 1, "held": ["ph_relic_a", "ph_charm_a"], "swap_used": true })
	if (InventoryService.held_pieces(ctx.save_data) as Array).size() != 2:
		m.append("held= should put 2 pieces in the pack, got %d" % (InventoryService.held_pieces(ctx.save_data) as Array).size())
	if not PickupEventService.swap_used(_stage(ctx)):
		m.append("swapused did not set the swap mark")
	if _record(ctx).is_empty() or int(_record(ctx).get("free", -1)) != 2:
		m.append("the case should see 2 free slots after the held pieces: %s" % str(_record(ctx).get("free", "")))
	var none := _ctx(2, 4)
	_produce(none, "event", { "ids": ["ph_weapon_a"], "count": 1 })
	if PickupEventService.swap_used(_stage(none)) or (InventoryService.held_pieces(none.save_data) as Array).size() != 0:
		m.append("without the keys no held piece and no swap mark")
	return _result(m)


static func _t_bad_input() -> Dictionary:
	var m: Array = []
	var cases := [
		["event", { "count": 0 }, "bad_count"], ["event", { "ids": ["nope"] }, "unknown_id"], ["event", { "rank": "Z" }, "bad_rank"],
		["event", { "rank": "F" }, "loss_rank"], ["event", { "cap": 0 }, "bad_cap"], ["arm", { "count": 0 }, "bad_count"],
		["arm", { "rank": "A" }, "rank_not_allowed"], ["bogus", {}, "bad_mode"],
		["event", { "frozen": true, "chooser_standing": 2 }, "scene_only_option"], ["arm", { "full_pack": true }, "scene_only_option"],
		["event", { "ids": [] }, "bad_ids"], ["event", { "ids": ["ph_weapon_a"], "count": 2 }, "count_exceeds_ids"],
	]
	for c in cases:
		var ctx := _ctx()
		var before := _hash(ctx)
		var o := _produce(ctx, c[0], c[1])
		if o.error_code != c[2] or o.has_replacement_snapshot or not o.save_reasons.is_empty():
			m.append("%s %s gave '%s', expected %s" % [c[0], str(c[1]), o.error_code, c[2]])
		_unchanged(ctx, before, "%s %s" % [c[0], str(c[1])], m)
		if not ctx.pickup_armed.is_empty() or not _record(ctx).is_empty():
			m.append("%s %s armed or opened something" % [c[0], str(c[1])])
	var places := [[FlowStateIds.SANCTUM, "wrong_place"], [FlowStateIds.ENCOUNTER, "wrong_place"], [FlowStateIds.PICKUP, "event_open"]]
	for p in places:
		for mode in ["event", "arm"]:
			var ctx := _ctx()
			ctx.last_snapshot["type"] = p[0]
			var before := _hash(ctx)
			var o := _produce(ctx, mode)
			if o.error_code != p[1]:
				m.append("%s in '%s' gave '%s'" % [mode, p[0], o.error_code])
			_unchanged(ctx, before, "%s in '%s'" % [mode, p[0]], m)
	var empty := _ctx()
	empty.save_data["sanctum"]["active_party_ids"] = []
	if _produce(empty, "event").error_code != "no_party":
		m.append("no party should give no_party")
	var nolive := _ctx()
	nolive.stage_id = ""
	if _produce(nolive, "arm").error_code != "no_live_path":
		m.append("no live path should give no_live_path")
	return _result(m)


static func _t_arm_unit() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 6)
	var before := _hash(ctx)
	var o := _produce(ctx, "arm", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 1, "cap": 3, "chooser_standing": 2 })
	if o.error_code != "" or ctx.pickup_armed.size() != 2 or str(_opts(ctx)) != str({ "count": 1, "cap": 3, "chooser_id": "e1" }):
		m.append("arm stored %d finds, options %s, error '%s'" % [ctx.pickup_armed.size(), str(ctx.pickup_armed_opts), o.error_code])
	if _hash(ctx) != before or not _record(ctx).is_empty() or o.has_replacement_snapshot or not ctx.pickup_session.is_empty() \
			or not o.save_reasons.is_empty():
		m.append("arm without held or swapused must change the save and the view in no way")
	if str(ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		m.append("arm moved the player")
	return _result(m)


# ---------------------------------------------------------------------------
# Through the real dispatch
# ---------------------------------------------------------------------------

## The two-situation runtime of the C9 tests, moved to the path view, with the fixture config.
static func _prepare_live(env: Dictionary, cfg: ConfigService) -> void:
	PickupFlowTests._prepare(env, cfg, [], false, -1)
	(env["runtime"] as FlowRuntime).dispatch({ "type": "flow.go_state", "to": FlowStateIds.STAGE_EXPLORE })


static func _live(tag: String, pack: int, cap: int, chance: int = 100) -> Dictionary:
	var env := CombatRoundtripIntegrationTests._setup_two_combat_situations("pickup_debug_" + tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	_prepare_live(env, PickupFlowTests._cfg(pack, cap, chance))
	env["rt"] = env["runtime"]
	env["fc"] = env["flow_ctx"]
	env["ok"] = true
	return env


static func _t_event_now_chain() -> Dictionary:
	var env := _live("chain", 4, 2)
	if not bool(env["ok"]):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		m.append("the setup is not on the path view: '%s'" % str(fc.last_snapshot.get("type", "")))
	var options := { "ids": ["ph_weapon_a", "ph_relic_a"], "count": 2 }
	var before := JSON.stringify(rt.get_save_data(), "", true)
	rt.dispatch({ "type": _CHECK, "payload": { "scene": "event_now", "options": options } })
	rt.dispatch({ "type": _APPLY, "payload": { "scene": "event_now", "options": options } })
	if not bool(_log(fc.logger, _CHECK).get("ok", false)) or bool(_log(fc.logger, _APPLY).get("applied", true)) \
			or str(fc.last_snapshot.get("type", "")) != FlowStateIds.STAGE_EXPLORE or not _record(fc).is_empty():
		m.append("check and an unconfirmed apply must route through dispatch and change nothing")
	if JSON.stringify(rt.get_save_data(), "", true) != before:
		m.append("check and unconfirmed apply changed the save through the dispatch")
	rt.dispatch({ "type": _APPLY, "payload": { "scene": "event_now", "options": options, "confirm": true } })
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.PICKUP or str((fc.last_snapshot["data"] as Dictionary).get("phase", "")) != "intro":
		m.append("a confirmed apply should publish the intro, got '%s'" % str(fc.last_snapshot.get("type", "")))
	var first_sit := str(_record(fc).get("situation_id", ""))
	rt.dispatch({ "type": "pickup.skip", "payload": {} })
	rt.dispatch({ "type": "pickup.continue", "payload": {} })
	var card := fc.last_snapshot
	var rec := _record(fc)
	if str(card.get("type", "")) != FlowStateIds.RESOLVE or str(rt.flow_machine._current_state_id) != FlowStateIds.RESOLVE:
		m.append("Continue should publish a Resolve card and move the machine to RESOLVE: '%s' / '%s'" % [card.get("type", ""), rt.flow_machine._current_state_id])
	var cdata: Dictionary = card.get("data", {})
	if JSON.stringify(cdata.get("pickup_result", null), "", true) != JSON.stringify(PickupSnapshotBuilder.result_of(rec), "", true) \
			or (cdata.get("pickup_result", {}) as Dictionary).is_empty():
		m.append("the card does not carry the final items")
	if cdata.has("encounter_id") or cdata.has("enemies_defeated") or cdata.has("run_type"):
		m.append("the card must carry no combat stats and no run_type: %s" % str(cdata.keys()))
	if PendingResultService.has_pending(rt.get_save_data()):
		m.append("the event-now card made a pending result")
	var go: Dictionary = (card.get("actions", {}) as Dictionary).get("cta.continue", {})
	if str(go.get("type", "")) != "flow.go_state" or str(go.get("to", "")) != FlowStateIds.STAGE_EXPLORE or str(rec.get("phase", "")) != "done":
		m.append("the card's Continue is %s, record phase '%s'" % [str(go), str(rec.get("phase", ""))])
	rt.dispatch(go)
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.STAGE_EXPLORE or str(rt.flow_machine._current_state_id) != FlowStateIds.STAGE_EXPLORE:
		m.append("the Resolve Continue did not return to the path: '%s' / '%s'" % [fc.last_snapshot.get("type", ""), rt.flow_machine._current_state_id])
	rt.dispatch({ "type": "debug.inventory.produce", "payload": { "mode": "event", "ids": ["ph_charm_a"], "count": 1 } })
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.PICKUP or str(_record(fc).get("situation_id", "")) == first_sit:
		m.append("a second event after the chain did not open with a fresh situation id")
	PickupFlowTests._done(env)
	return _result(m)


static func _t_arm_real_fight() -> Dictionary:
	var cfg := PickupFlowTests._cfg(4, 2)
	var arm := func(env: Dictionary) -> void:
		_prepare_live(env, cfg)
		(env["runtime"] as FlowRuntime).dispatch({ "type": "debug.inventory.produce", "payload": { "mode": "arm", "ids": _IDS4, "count": 1 } })
	var env := PickupCharacterizationTests._won_fight("pickup_debug_arm", arm)
	if not bool(env["ok"]):
		PickupFlowTests._done(env)
		return env
	var m: Array = []
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var rec := _record(fc)
	var real_rank := str((ectx.final_snapshot["data"] as Dictionary).get("rank", ""))
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.PICKUP or rec.is_empty():
		m.append("the armed win did not open the event: '%s'" % str(fc.last_snapshot.get("type", "")))
	if str(rec.get("rank", "")) != real_rank or real_rank.is_empty() or rec.has("debug_event") or str(rec.get("situation_id", "")) != str(env["sit"]):
		m.append("the event must use the real rank '%s' and the real situation '%s': %s / %s" % [real_rank, env["sit"], rec.get("rank", ""), rec.get("situation_id", "")])
	if (rec.get("finds", []) as Array).size() != 1:
		m.append("count=1 should offer 1 find, got %d" % (rec.get("finds", []) as Array).size())
	if not fc.pickup_armed.is_empty() or not fc.pickup_armed_opts.is_empty():
		m.append("an opened event must spend the armed finds and options")
	if str(ectx.final_snapshot.get("type", "")) != FlowStateIds.RESOLVE:
		m.append("the fight's own card must wait behind the event")
	PickupFlowTests._done(env)
	return _result(m)


static func _t_armed_kept() -> Dictionary:
	var cfg := PickupFlowTests._cfg(4, 2, 0)
	var arm := func(env: Dictionary) -> void:
		_prepare_live(env, cfg)
		(env["runtime"] as FlowRuntime).dispatch({ "type": "debug.inventory.produce", "payload": { "mode": "arm", "ids": _IDS4, "cap": 3 } })
	var env := PickupCharacterizationTests._won_fight("pickup_debug_kept", arm)
	if not bool(env["ok"]):
		PickupFlowTests._done(env)
		return env
	var m: Array = []
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	if fc.pickup_armed.size() != 4 or str(_opts(fc)) != str({ "cap": 3 }):
		m.append("a win that opens nothing must keep the armed finds and options: %d / %s" % [fc.pickup_armed.size(), str(fc.pickup_armed_opts)])
	if str(_log(fc.logger, "inventory.pickup.armed_kept").get("reason", "")) != "no_event":
		m.append("armed_kept must log the reason no_event")
	if not _record(fc).is_empty() or str(fc.last_snapshot.get("type", "")) != FlowStateIds.RESOLVE or JSON.stringify(fc.last_snapshot) != JSON.stringify(ectx.final_snapshot):
		m.append("the win should publish its own card and no event")
	PickupFlowTests._done(env)
	return _result(m)


static func _t_collision() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var stage := _stage(ctx)
	var run_count := int(RealmService.get_active(ctx).get("run_count", 0))
	stage["pickup"] = { "run_count": run_count, "situation_id": "debug.1", "phase": "done", "win_t": -5 }
	var before := _hash(ctx)
	var o := _produce(ctx, "event", { "ids": ["ph_weapon_a", "ph_charm_a"], "count": 2, "held": ["ph_relic_a"], "swap_used": true,
		"chooser_standing": 3 })
	if o.error_code != "not_opened" or o.has_replacement_snapshot:
		m.append("an ended stamp must give not_opened, got '%s'" % o.error_code)
	_unchanged(ctx, before, "the collision", m)
	var frozen := _ctx(2, 4)
	_stage(frozen)["pickup"] = { "run_count": run_count, "situation_id": "debug.1", "phase": "done", "win_t": -5 }
	var before_f := _hash(frozen)
	var o_f := _apply(frozen, "event_now", { "ids": ["ph_weapon_a"], "count": 1, "chooser_standing": 3, "frozen": true, "held": ["ph_relic_a"] }, true)
	if o_f.error_code != "not_opened" or _hash(frozen) != before_f or frozen.save_request:
		m.append("a failing apply with the frozen writes must restore the emotion, pack, swap mark and counter")
	return _result(m)


static func _t_names() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(2, 4)
	var inv: Dictionary = (ctx.config_service.get("inv") as Dictionary).duplicate(true)
	inv["definitions"] = {}
	ctx.config_service.set("inv", inv)
	_produce(ctx, "event", { "ids": ["ph_weapon_a", "ph_relic_a"], "count": 2 })
	var rows: Array = _record(ctx).get("finds", [])
	if rows.size() != 2:
		m.append("expected 2 rows, got %d" % rows.size())
	for r in rows:
		var want := InventoryServiceTests._name_of(str((r as Dictionary)["type_id"]))
		if str((r as Dictionary)["name"]).is_empty() or str((r as Dictionary)["name"]) != want:
			m.append("row %s has name '%s', expected '%s'" % [str((r as Dictionary)["type_id"]), str((r as Dictionary)["name"]), want])
	var arm := _ctx(2, 4)
	arm.config_service.set("inv", inv)
	_produce(arm, "arm", { "ids": ["ph_weapon_a"] })
	if (arm.pickup_armed_opts.get("names", {}) as Dictionary).is_empty():
		m.append("arm must carry the names map for the next won fight")
	return _result(m)


# ---------------------------------------------------------------------------
# Console
# ---------------------------------------------------------------------------

static func _t_console() -> Dictionary:
	var m: Array = []
	var src := FileAccess.get_file_as_string("res://ui/AppRoot.gd")
	for fn in ["func _run_inventory_command(", "func _run_pickup_command("]:
		var start := src.find(fn)
		if start < 0:
			m.append("%s not found" % fn)
			continue
		var end := src.find("\nfunc ", start + 10)
		var body := src.substr(start, end - start if end > 0 else src.length() - start)
		var gate := body.find("OS.is_debug_build()")
		var dispatch := body.find("runtime.dispatch")
		if gate < 0 or dispatch < 0 or gate > dispatch:
			m.append("%s: the debug-build check must come before runtime.dispatch (gate %d, dispatch %d)" % [fn, gate, dispatch])
	for path in ["res://core/runtime/controllers/DebugController.gd", "res://core/inventory/PickupDebug.gd"]:
		if FileAccess.get_file_as_string(path).contains("is_debug_build"):
			m.append("%s must not hold a build gate (the console owns it)" % path)
	var app: GDScript = load("res://ui/AppRoot.gd")
	var r: Dictionary = app.parse_pickup_options(PackedStringArray(["inventory", "produce", "event", "ids=a,b", "grades=g1,g2", "count=3", "RANK=c",
		"standing=6", "chooser=e1", "fallen=e2", "cap=5", "held=x,y", "swapused", "frozen", "fullpack"]), 3)
	var want := { "ids": ["a", "b"], "grades": ["g1", "g2"], "count": 3, "rank": "C", "chooser_standing": 6, "chooser_id": "e1", "fallen": "e2",
		"cap": 5, "held": ["x", "y"], "swap_used": true, "frozen": true, "full_pack": true }
	if not bool(r["ok"]) or JSON.stringify(r["payload"], "", true) != JSON.stringify(want, "", true):
		m.append("parse gave %s" % JSON.stringify(r))
	for words in [["x", "x", "x", "count=abc"], ["x", "x", "x", "bogus=1"], ["x", "x", "x", "count="], ["x", "x", "x", "nope"]]:
		var bad: Dictionary = app.parse_pickup_options(PackedStringArray(words), 3)
		if bool(bad["ok"]) or not str(bad["usage"]).begins_with("Usage:") or not (bad["payload"] as Dictionary).is_empty():
			m.append("%s should give the usage line" % str(words))
	var no_scene_flags: Dictionary = app.parse_pickup_options(PackedStringArray(["x", "x", "x", "frozen"]), 3, false)
	var no_full: Dictionary = app.parse_pickup_options(PackedStringArray(["x", "x", "x", "fullpack"]), 3, false)
	var swap_ok: Dictionary = app.parse_pickup_options(PackedStringArray(["x", "x", "x", "swapused"]), 3, false)
	var empty_ids: Dictionary = app.parse_pickup_options(PackedStringArray(["x", "x", "x", "ids="]), 3, false)
	if bool(no_scene_flags["ok"]) or bool(no_full["ok"]) or not bool(swap_ok["ok"]) or bool(empty_ids["ok"]):
		m.append("frozen and fullpack belong to the scene commands; ids= with nothing is an error")
	for label in ["debug.pickup.scene.check", "debug.pickup.scene.apply"]:
		if FileAccess.get_file_as_string("res://core/runtime/FlowRuntime.gd").count("\"%s\":" % label) != 1:
			m.append("%s must be routed exactly once" % label)
	return _result(m)
