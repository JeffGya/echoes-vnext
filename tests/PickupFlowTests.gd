# res://tests/PickupFlowTests.gd
# V2-ITEM-001b step C9: the pickup event wired into a REAL won fight. Each fight runs through the real
# FlowRuntime.dispatch with the machine in ENCOUNTER (PickupCharacterizationTests._won_fight) and armed debug finds.
# The fixture config forces every finds slot to hit (chance 100) with a fixed cap, so the count does not depend on
# the seed. A frozen chooser would stop the swap steps; the tests say so in their message.

class_name PickupFlowTests
extends RefCounted

const _DENIED := "inventory.pickup.denied"
const _OPEN := "inventory.pickup.open"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_flow/armed_win_publishes_pickup_and_holds_the_result", Callable(PickupFlowTests, "_t_armed_win"))
	runner.register_test("pickup_flow/every_action_through_the_dispatch_then_resolve_then_path", Callable(PickupFlowTests, "_t_full_event"))
	runner.register_test("pickup_flow/armed_win_with_zero_finds_publishes_the_card_unchanged", Callable(PickupFlowTests, "_t_zero_finds"))
	runner.register_test("pickup_flow/hook_runs_after_bond_and_thread_in_an_objective_fight", Callable(PickupFlowTests, "_t_objective_order"))
	runner.register_test("pickup_flow/an_earlier_fallen_echo_cannot_choose", Callable(PickupFlowTests, "_t_fallen"))
	runner.register_test("pickup_flow/reload_resumes_idle_then_resolve_after_the_end", Callable(PickupFlowTests, "_t_reload"))
	runner.register_test("pickup_flow/refused_and_accepted_actions_keep_the_result", Callable(PickupFlowTests, "_t_hold"))
	runner.register_test("pickup_flow/replaying_the_hook_opens_nothing_new", Callable(PickupFlowTests, "_t_replay"))
	runner.register_test("pickup_flow/pending_result_keys_are_additive", Callable(PickupFlowTests, "_t_pending_keys"))
	runner.register_test("pickup_flow/reload_after_a_committed_swap_keeps_the_swap", Callable(PickupFlowTests, "_t_reload_after_swap"))
	runner.register_test("pickup_flow/stage_clearing_card_shows_the_items_after_the_event", Callable(PickupFlowTests, "_t_stage_clear_items"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _json(v: Variant) -> String:
	return JSON.stringify(v, "", true)


## Fixture inventory over the real balance: placeholder definitions, pack `pack`, finds cap `cap`, each slot hits
## with `chance` percent (100: every slot, 0: none).
static func _cfg(pack: int, cap: int, chance: int = 100) -> ConfigService:
	var c := InventoryActionTests._Cfg.new()
	c.load_balance()
	c.load_actors()
	c.load_realms()
	var real := ConfigService.new()
	real.load_balance()
	var real_inv := ConfigService.get_inventory_cfg(real)
	var inv := InventoryServiceTests._cfg(8, pack, 5)
	inv["pick"] = real_inv["pick"]
	inv["pickup"] = real_inv["pickup"]
	inv["finds_chance"] = { "base_by_slot_pct": [chance, chance, chance, chance, chance, chance], "max_pct": 100,
		"rank_modifier_pct": { "C": 0, "B": 0, "A": 0, "S": 0 } }
	inv["finds_cap_by_realm_scale"] = [{ "scale": 1.0, "cap": cap }]
	c.inv = inv
	return c


## Runs on the setup env before the engage: the config, both prologues done (so flow.continue reaches the
## pending result after a reboot), armed finds, and optionally a combat objective or an Echo fallen earlier.
static func _prepare(env: Dictionary, cfg: ConfigService, finds: Array, objective: bool, lost_index: int) -> void:
	var rt: FlowRuntime = env["runtime"]
	var fc: FlowContext = env["flow_ctx"]
	rt.config_service = cfg
	fc.config_service = cfg
	rt.logger.set_level(StructuredLogger.LEVEL_INFO)
	var ob_v: Variant = fc.save_data.get("onboarding", {})
	if ob_v is Dictionary:
		(ob_v as Dictionary)["chapter_one_complete"] = true
		(ob_v as Dictionary)["chapter_one_step"] = OnboardingService.STEP_COMPLETE
		(ob_v as Dictionary)["keeper_intro_complete"] = true
		(ob_v as Dictionary)["keeper_intro_step"] = "complete"
	fc.pickup_armed = finds.duplicate(true)
	var stage := FlowStageExploreState._get_current_stage(fc)
	if objective:
		stage["objectives"] = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
		var sits: Array = (stage["explore_map"] as Dictionary)["situations"]
		(sits[0] as Dictionary)["is_objective"] = true
		(sits[0] as Dictionary)["objective_index"] = 0
	if lost_index >= 0:
		var roster: Array = fc.save_data["sanctum"]["roster"]
		stage["lost_echo_names"] = [str((roster[lost_index] as Dictionary).get("name", ""))]
	FlowStageExploreState._write_stage_back(fc, stage)


static func _fight(tag: String, pack: int, cap: int, types: Array, objective: bool = false, lost_index: int = -1,
		chance: int = 100) -> Dictionary:
	var cfg := _cfg(pack, cap, chance)
	var env := PickupCharacterizationTests._won_fight("pickup_flow_" + tag,
		Callable(PickupFlowTests, "_prepare").bind(cfg, PickupStateTests._finds(types), objective, lost_index))
	env["cfg"] = cfg
	return env


static func _done(env: Dictionary) -> void:
	if env.has("rt"):
		TestSaveHarness.remove_save_artifacts((env["rt"] as FlowRuntime).save_path)


static func _types(fc: FlowContext) -> Array:
	return fc.logger.get_logs().map(func(e): return str((e as Dictionary)["type"]))


static func _last_denied(fc: FlowContext) -> String:
	var logs: Array = fc.logger.get_logs()
	for i in range(logs.size() - 1, -1, -1):
		if str(logs[i]["type"]) == _DENIED:
			return str((logs[i]["data"] as Dictionary).get("reason_key", ""))
	return ""


static func _stage(fc: FlowContext) -> Dictionary:
	return FlowStageExploreState._get_current_stage(fc)


static func _record(fc: FlowContext) -> Dictionary:
	return PickupEventService.record_of(_stage(fc))


static func _phase(fc: FlowContext) -> String:
	var d_v: Variant = fc.last_snapshot.get("data", {})
	return str((d_v as Dictionary).get("phase", "")) if d_v is Dictionary else ""


static func _pending(fc: FlowContext) -> Dictionary:
	return PendingResultService.read(fc.save_data)


static func _reboot(path: String, cfg_like: Dictionary) -> FlowRuntime:
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_INFO)
	var rt := FlowRuntime.new(logger, _cfg(int(cfg_like["pack"]), int(cfg_like["cap"])), path)
	rt.boot()
	return rt


static func _row_types(rows: Array) -> Array:
	return rows.map(func(r): return str((r as Dictionary)["type_id"]))


static func _type_of_find(record: Dictionary, find_id: String) -> String:
	return PickupSwapRules.type_of(record.get("finds", []), "find_id", find_id)


# ---------------------------------------------------------------------------
# (a) The ending dispatch publishes flow.pickup (intro) and holds the result; (i) the additive board keys.
# ---------------------------------------------------------------------------

static func _t_armed_win() -> Dictionary:
	var env := _fight("armed", 4, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var tr: Dictionary = env["trace"]
	if str(tr["type_at_flip"]) != FlowStateIds.PICKUP or str(tr["state_at_flip"]) != FlowStateIds.ENCOUNTER \
			or not bool(tr["pending_at_flip"]):
		m.append("at the ending dispatch: snapshot '%s', machine '%s', pending %s" % [tr["type_at_flip"], tr["state_at_flip"], str(tr["pending_at_flip"])])
	if _phase(fc) != PickupSnapshotBuilder.PHASE_INTRO or str(fc.pickup_session.get("phase", "")) != PickupSnapshotBuilder.PHASE_INTRO:
		m.append("phase '%s', session %s: the first publish is the intro" % [_phase(fc), str(fc.pickup_session)])
	if str(ectx.final_snapshot.get("type", "")) != FlowStateIds.RESOLVE:
		m.append("the held card is '%s'" % str(ectx.final_snapshot.get("type", "")))
	if not fc.pickup_armed.is_empty():
		m.append("the armed finds were not spent by the win")
	var rec := _record(fc)
	if rec.is_empty() or (rec["finds"] as Array).size() != 2 or str(rec["situation_id"]) != str(env["sit"]):
		m.append("record %s" % _json(rec))
	var pending := _pending(fc)
	if _json(pending.get("resolve_data", {})) != _json(ectx.final_snapshot["data"]):
		m.append("the pending result does not hold the Resolve card")
	if int(pending.get("created_t", -1)) != int(rec.get("win_t", -2)):
		m.append("created_t %s, win_t %s" % [str(pending.get("created_t")), str(rec.get("win_t"))])
	var d: Dictionary = fc.last_snapshot["data"]
	if _json(pending.get("terrain", null)) != _json(ectx.terrain) or str(pending.get("placement_seed", "")) != str(ectx.placement_seed):
		m.append("pending terrain/placement_seed %s %s" % [_json(pending.get("terrain", null)), str(pending.get("placement_seed", null))])
	var b: Variant = pending.get("bounds", null)
	if not (b is Dictionary) or int((b as Dictionary).get("w", -1)) != int(d["board_cols"]) or int((b as Dictionary).get("h", -1)) != int(d["board_rows"]):
		m.append("pending bounds %s, live board %s x %s" % [str(b), str(d["board_cols"]), str(d["board_rows"])])
	if (d["actors"] as Array).is_empty():
		m.append("the pickup snapshot has no board actors")
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (b) (g) Every pickup action through the real dispatch, the swap, Continue, the end mark, Resolve's own Continue.
# ---------------------------------------------------------------------------

static func _t_full_event() -> Dictionary:
	var env := _fight("full", 1, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var rec := _record(fc)
	if (rec["taken"] as Array).size() != 1 or (rec["left"] as Array).size() != 1:
		_done(env)
		return _result(["fixture: taken %s left %s frozen %s (pack 1, two finds)" % [str(rec["taken"]), str(rec["left"]), str(rec["frozen"])]])
	var x := str(rec["taken"][0])
	var y := str(rec["left"][0])
	var row_id := EarningsService.item_id(str(rec["situation_id"]), x)
	var pending_before := _json(_pending(fc))
	var steps: Array = [
		["pickup.select", { "pack_id": row_id }, "intro"], ["pickup.skip", {}, "idle"],
		["pickup.select", { "find_id": y }, "idle"], ["pickup.swap.start", {}, "swap_pick"],
		["pickup.swap.cancel", {}, "idle"], ["pickup.select", { "find_id": y }, "idle"],
		["pickup.swap.start", {}, "swap_pick"], ["pickup.swap.pick", { "id": row_id }, "swap_preview"],
		["pickup.swap.confirm", {}, "idle"],
	]
	for s: Array in steps:
		var out := rt.dispatch({ "type": s[0], "payload": s[1] })
		if str(out.get("type", "")) != FlowStateIds.PICKUP or _phase(fc) != s[2]:
			m.append("%s: type '%s', phase '%s', expected '%s'" % [s[0], out.get("type", ""), _phase(fc), s[2]])
	if _types(fc).has(_DENIED):
		m.append("a step was refused: '%s'" % _last_denied(fc))
	rec = _record(fc)
	if str((rec["swap"] as Dictionary).get("find_id", "")) != y or not (rec["taken"] as Array).has(y) or not (rec["left"] as Array).has(x):
		m.append("swap record %s, taken %s, left %s" % [_json(rec["swap"]), str(rec["taken"]), str(rec["left"])])
	if _json(_pending(fc)) != pending_before:
		m.append("a pickup action changed the pending result")
	# Continue publishes the held card with the final items read after the swap.
	var res := rt.dispatch({ "type": "pickup.continue", "payload": {} })
	var pr_v: Variant = (res.get("data", {}) as Dictionary).get("pickup_result", null)
	var pr: Dictionary = pr_v if pr_v is Dictionary else {}
	if str(res.get("type", "")) != FlowStateIds.RESOLVE or str(rt.flow_machine._current_state_id) != FlowStateIds.ENCOUNTER:
		m.append("continue published '%s' in machine '%s'" % [res.get("type", ""), rt.flow_machine._current_state_id])
	if not bool(pr.get("swap_used", false)) or _row_types(pr.get("taken", [])) != [_type_of_find(rec, y)] \
			or _row_types(pr.get("left", [])) != [_type_of_find(rec, x)] or str((pr.get("dropped", {}) as Dictionary).get("type_id", "")) != _type_of_find(rec, x) \
			or not (pr.get("lost", []) as Array).is_empty():
		m.append("pickup_result %s" % _json(pr))
	var card := (res["data"] as Dictionary).duplicate(true)
	card.erase("pickup_result")
	if _json(card) != _json(ectx.final_snapshot["data"]):
		m.append("the published card is not the held card plus pickup_result")
	if _json((_pending(fc).get("resolve_data", {}) as Dictionary).get("pickup_result", null)) != _json(pr):
		m.append("pickup_result is not attached to the pending result")
	if not PickupEventService.is_ended(_record(fc)) or not fc.pickup_session.is_empty():
		m.append("end mark: phase '%s', session %s" % [str(_record(fc).get("phase", "")), str(fc.pickup_session)])
	# After the end every pickup action is refused with `ended`; the swap cannot commit.
	for a: String in ["pickup.continue", "pickup.swap.confirm", "pickup.skip"]:
		var again := rt.dispatch({ "type": a, "payload": {} })
		if _last_denied(fc) != "ended" or str(again.get("type", "")) != FlowStateIds.RESOLVE:
			m.append("%s after the end: reason '%s', type '%s'" % [a, _last_denied(fc), again.get("type", "")])
	if _types(fc).count("inventory.pickup.finish") != 1 or _types(fc).count("inventory.pickup.swap") != 1:
		m.append("finish logs %d, swap logs %d" % [_types(fc).count("inventory.pickup.finish"), _types(fc).count("inventory.pickup.swap")])
	# Resolve's own Continue works as before and consumes the result.
	var go: Dictionary = (res.get("actions", {}) as Dictionary).get("cta.continue", {})
	var back := rt.dispatch(go)
	if str(back.get("type", "")) != FlowStateIds.STAGE_EXPLORE or fc.encounter_ctx != null or PendingResultService.has_pending(fc.save_data):
		m.append("Resolve Continue: type '%s', ectx %s, pending %s" % [back.get("type", ""), str(fc.encounter_ctx != null), str(PendingResultService.has_pending(fc.save_data))])
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (c) Armed finds but a count of 0: the hook runs to the finds roll and opens nothing. The byte pins of a win with
# no armed finds stay in pickup_char/win_with_no_finds_snapshot_and_save_are_pinned (not repeated here).
# ---------------------------------------------------------------------------

static func _t_zero_finds() -> Dictionary:
	var env := _fight("zero", 4, 2, ["ph_weapon_a", "ph_relic_a"], false, -1, 0)
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var tr: Dictionary = env["trace"]
	if str(tr["type_at_flip"]) != FlowStateIds.RESOLVE or _json(fc.last_snapshot) != _json(ectx.final_snapshot):
		m.append("published '%s'; the card must be the held final snapshot" % str(tr["type_at_flip"]))
	var stage := _stage(fc)
	if stage.has(PickupEventService.STAGE_KEY) or stage.has(PickupEventService.SWAP_KEY) or _types(fc).has(_OPEN):
		m.append("an event opened with a count of 0")
	# C10 rule: armed finds are spent only when an event opens; this win opened none, so they stay armed.
	if fc.pickup_armed.size() != 2 or not fc.pickup_session.is_empty() or not _types(fc).has("inventory.pickup.armed_kept"):
		m.append("armed %s, session %s: a win that opens nothing keeps the armed finds and logs armed_kept" % [str(fc.pickup_armed), str(fc.pickup_session)])
	var pending := _pending(fc)
	if pending.is_empty() or pending.has("terrain") or pending.has("placement_seed") or pending.has("bounds"):
		m.append("pending keys %s" % str(pending.keys()))
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (d) Hook order, an objective fight, an Echo fallen in an earlier fight.
# ---------------------------------------------------------------------------

static func _t_objective_order() -> Dictionary:
	var env := _fight("objective", 4, 2, ["ph_weapon_a", "ph_relic_a"], true)
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var fc: FlowContext = env["fc"]
	var types := _types(fc)
	var i_bond := types.rfind("bond.combat_triggers.applied")
	var i_seg := types.rfind("realm.recovery.segment")
	var i_open := types.rfind(_OPEN)
	if i_bond < 0 or i_seg < 0 or i_open < 0 or not (i_bond < i_seg and i_seg < i_open):
		m.append("log order bond %d, thread segment %d, pickup open %d: the hook must come last" % [i_bond, i_seg, i_open])
	if str(_pending(fc).get("outcome", "")) != PendingResultService.OUTCOME_VICTORY:
		m.append("outcome '%s', expected victory (the one objective is overcome)" % str(_pending(fc).get("outcome", "")))
	if str(fc.last_snapshot.get("type", "")) != FlowStateIds.PICKUP:
		m.append("the objective win published '%s'" % str(fc.last_snapshot.get("type", "")))
	_done(env)
	return _result(m)


static func _t_fallen() -> Dictionary:
	var env := _fight("fallen", 4, 2, ["ph_weapon_a", "ph_relic_a"], false, 2)
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var fc: FlowContext = env["fc"]
	var roster: Array = fc.save_data["sanctum"]["roster"]
	var fallen_name := str((roster[2] as Dictionary).get("name", ""))
	var rec := _record(fc)
	if rec.is_empty():
		_done(env)
		return _result(["no event opened"])
	var standing: Array = rec["standing_ids"]
	for e: Dictionary in roster:
		if str(e.get("name", "")) == fallen_name and standing.has(str(e.get("id", ""))):
			m.append("the earlier fallen Echo %s is standing" % str(e.get("id", "")))
	if not (rec["fallen_names"] as Array).has(fallen_name) or standing.has(str(rec["chooser"])) == false:
		m.append("fallen_names %s, chooser %s, standing %s" % [str(rec["fallen_names"]), str(rec["chooser"]), str(standing)])
	if standing.is_empty() or standing.size() >= roster.size():
		m.append("standing %s of %d" % [str(standing), roster.size()])
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (e) Reload: idle resume with the stored board; win_t ties the record to the result; after the end, Resolve.
# ---------------------------------------------------------------------------

static func _t_reload() -> Dictionary:
	var env := _fight("reload", 1, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var path := rt.save_path
	var cfg_like := { "pack": 1, "cap": 2 }
	var live: Dictionary = fc.last_snapshot["data"]
	var rec := _record(fc)
	# Quit in the middle of a swap: the session is never saved, so the reload resumes at idle.
	rt.dispatch({ "type": "pickup.skip", "payload": {} })
	var live_idle: Dictionary = PickupSnapshotBuilder.build(fc, 0, {})["data"]
	rt.dispatch({ "type": "pickup.select", "payload": { "find_id": str((rec["left"] as Array)[0]) } })
	rt.dispatch({ "type": "pickup.swap.start", "payload": {} })
	if _phase(fc) != PickupSnapshotBuilder.PHASE_SWAP_PICK:
		m.append("fixture: phase '%s' before the quit, expected swap_pick" % _phase(fc))

	# A record of another win (win_t != created_t) is not resumed. Probe on a scratch path, so the file stays.
	var rw := _reboot(path, cfg_like)
	rw.save_path = path + ".win_t_probe.json"
	var rw_stage := FlowStageExploreState.stage_by_index(rw.get_save_data()["realms"]["realm.01"], 0)
	PickupEventService.record_of(rw_stage)["win_t"] = int(PickupEventService.record_of(rw_stage)["win_t"]) + 1
	var probe := rw.dispatch({ "type": "flow.continue" })
	if str(probe.get("type", "")) != FlowStateIds.RESOLVE:
		m.append("a record of another win was resumed: '%s'" % str(probe.get("type", "")))
	TestSaveHarness.remove_save_artifacts(rw.save_path)

	var r2 := _reboot(path, cfg_like)
	var out := r2.dispatch({ "type": "flow.continue" })
	var pending := PendingResultService.read(r2.get_save_data())
	var d_v: Variant = out.get("data", {})
	var d: Dictionary = d_v if d_v is Dictionary else {}
	if str(out.get("type", "")) != FlowStateIds.PICKUP or str(d.get("phase", "")) != PickupSnapshotBuilder.PHASE_IDLE \
			or str(r2.flow_machine._current_state_id) != FlowStateIds.RESOLVE or not r2.flow_ctx.pickup_session.is_empty():
		m.append("reload: type '%s', phase '%s', machine '%s', session %s" % [out.get("type", ""), d.get("phase", ""), r2.flow_machine._current_state_id, str(r2.flow_ctx.pickup_session)])
	elif (d["actors"] as Array).size() != (live["actors"] as Array).size() or int(d["board_cols"]) != int(live["board_cols"]) \
			or int(d["board_rows"]) != int(live["board_rows"]) or int(d["placement_seed"]) != int(live["placement_seed"]) \
			or _json(d["terrain"]) != _json(pending.get("terrain", {})) or (d["terrain"] as Dictionary).size() != (live["terrain"] as Dictionary).size():
		m.append("reload board: actors %d/%d, size %sx%s/%sx%s, seed %s/%s" % [(d["actors"] as Array).size(), (live["actors"] as Array).size(),
			d["board_cols"], d["board_rows"], live["board_cols"], live["board_rows"], d["placement_seed"], live["placement_seed"]])
	if not d.is_empty():
		m.append_array(_same_idle(live_idle, d))
	# Continue after the reload publishes the card from the pending result, with the final items.
	var res := r2.dispatch({ "type": "pickup.continue", "payload": {} })
	if str(res.get("type", "")) != FlowStateIds.RESOLVE or not (res.get("data", {}) as Dictionary).has("pickup_result"):
		m.append("continue after the reload: type '%s', data keys %s" % [res.get("type", ""), str((res.get("data", {}) as Dictionary).keys())])
	# A reload after the end mark shows Resolve, not the event.
	var r3 := _reboot(path, cfg_like)
	var again := r3.dispatch({ "type": "flow.continue" })
	if str(again.get("type", "")) != FlowStateIds.RESOLVE or not (again.get("data", {}) as Dictionary).has("pickup_result"):
		m.append("reload after the end: type '%s'" % str(again.get("type", "")))
	_done(env)
	return _result(m)


## Messages for the keys of a reloaded idle snapshot that must equal the live idle snapshot. `row` is compared
## without `status`: flow.continue runs the wall-clock emotion recovery, which can move a status.
static func _same_idle(live: Dictionary, reloaded: Dictionary) -> Array:
	var m: Array = []
	for k in ["finds", "pack", "chooser", "swap", "order", "fallen", "case", "reason", "reaction", "frozen"]:
		if ItemPacksTests._norm(live.get(k)) != ItemPacksTests._norm(reloaded.get(k)):
			m.append("reload changed '%s': %s -> %s" % [k, ItemPacksTests._norm(live.get(k)), ItemPacksTests._norm(reloaded.get(k))])
	var strip := func(rows: Variant) -> String:
		return ItemPacksTests._norm((rows as Array).map(func(r): return [r["id"], r["name"], int(r["standing"]), r["is_chooser"]]))
	if strip.call(live.get("row", [])) != strip.call(reloaded.get("row", [])):
		m.append("reload changed 'row' (ids, names, standing, chooser)")
	return m


# ---------------------------------------------------------------------------
# (f) The hold rule and the bark gate.
# ---------------------------------------------------------------------------

static func _t_hold() -> Dictionary:
	var env := _fight("hold", 4, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	rt.logger.set_level(StructuredLogger.LEVEL_DEBUG)
	var before := _json(_pending(fc))
	var flushes := _types(fc).count("save.flush")
	rt.dispatch({ "type": "pickup.swap.confirm", "payload": {} })
	if _last_denied(fc) != "wrong_phase" or _json(_pending(fc)) != before or _types(fc).count("save.flush") != flushes:
		m.append("refused action: reason '%s', pending kept %s, flushes %d" % [_last_denied(fc), str(_json(_pending(fc)) == before), _types(fc).count("save.flush") - flushes])
	if _types(fc).has("flow.pending_result.consumed"):
		m.append("a pickup snapshot consumed the result")
	# An accepted action keeps the result too, and the bark gate clears the encounter actors' barks.
	(ectx.actors[0] as Dictionary)["_bark_line"] = "stale"
	rt.dispatch({ "type": "pickup.skip", "payload": {} })
	if _phase(fc) != PickupSnapshotBuilder.PHASE_IDLE or _json(_pending(fc)) != before:
		m.append("skip: phase '%s', pending kept %s" % [_phase(fc), str(_json(_pending(fc)) == before)])
	if str((ectx.actors[0] as Dictionary).get("_bark_line", "")) != "":
		m.append("the bark was not cleared after a flow.pickup publish")
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (h) Exactly once.
# ---------------------------------------------------------------------------

static func _t_replay() -> Dictionary:
	var env := _fight("replay", 4, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var stage_before := _json(_stage(fc))
	var opens := _types(fc).count(_OPEN)
	fc.pickup_armed = PickupStateTests._finds(["ph_charm_a", "ph_weapon_a"])
	rt._open_pickup_event(ectx.final_snapshot, 900)
	if _json(_stage(fc)) != stage_before or _types(fc).count(_OPEN) != opens or not fc.pickup_armed.is_empty():
		m.append("replay of an open event: stage same %s, opens +%d, armed %s" % [str(_json(_stage(fc)) == stage_before), _types(fc).count(_OPEN) - opens, str(fc.pickup_armed)])
	rt.dispatch({ "type": "pickup.skip", "payload": {} })
	rt.dispatch({ "type": "pickup.continue", "payload": {} })
	var card := _json(fc.last_snapshot)
	var ended := _json(_stage(fc))
	rt._open_pickup_event(ectx.final_snapshot, 901)
	if _json(fc.last_snapshot) != card or _json(_stage(fc)) != ended:
		m.append("a replay after the end re-opened the event: type '%s'" % str(fc.last_snapshot.get("type", "")))
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# (i) Pending-result keys: additive; an old result without them still builds.
# ---------------------------------------------------------------------------

static func _t_pending_keys() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = PickupSnapshotTests._event("C1")["ctx"]
	if PickupSnapshotTests._capture_pending(ctx) != "captured":
		return _result(["test setup: no capture"])
	var pending := PendingResultService.read(ctx.save_data)
	for k in ["terrain", "placement_seed", "bounds"]:
		if pending.has(k):
			m.append("a plain Resolve capture carries '%s'" % k)
	var plain := PendingResultService.build_snapshot(ctx, 20)
	if plain.is_empty() or (plain["data"] as Dictionary).has("pickup_result"):
		m.append("an old result: snapshot %s" % _json(plain))
	var pr := PickupSnapshotBuilder.result_of(PickupEventService.record_of(ItemPacksTests._stage(ctx)))
	PendingResultService.attach_pickup_result(ctx, 8, pr)
	if PendingResultService.build_snapshot(ctx, 21)["data"].has("pickup_result"):
		m.append("attach with another win_t wrote")
	PendingResultService.attach_pickup_result(ctx, 9, pr)
	var built: Dictionary = PendingResultService.build_snapshot(ctx, 22)["data"]
	if _json(built.get("pickup_result", null)) != _json(pr) or pr.is_empty():
		m.append("producer G pickup_result %s, expected %s" % [_json(built.get("pickup_result", null)), _json(pr)])
	var empty := {}
	ResolveSnapshotBuilder.add_pickup_result(empty, {})
	if not empty.is_empty():
		m.append("an empty pickup result wrote a key")
	return _result(m)


# ---------------------------------------------------------------------------
# A committed swap survives the JSON reload; the final card reads it.
# ---------------------------------------------------------------------------

static func _t_reload_after_swap() -> Dictionary:
	var env := _fight("reload_swap", 1, 2, ["ph_weapon_a", "ph_relic_a"])
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var rec := _record(fc)
	if (rec["taken"] as Array).size() != 1 or (rec["left"] as Array).size() != 1:
		_done(env)
		return _result(["fixture: taken %s left %s frozen %s (pack 1, two finds)" % [str(rec["taken"]), str(rec["left"]), str(rec["frozen"])]])
	var x := str(rec["taken"][0])
	var y := str(rec["left"][0])
	var row_id := EarningsService.item_id(str(rec["situation_id"]), x)
	for s: Array in [["pickup.skip", {}], ["pickup.select", { "find_id": y }], ["pickup.swap.start", {}],
			["pickup.swap.pick", { "id": row_id }], ["pickup.swap.confirm", {}]]:
		rt.dispatch({ "type": s[0], "payload": s[1] })
	if str((_record(fc)["swap"] as Dictionary).get("find_id", "")) != y:
		_done(env)
		return _result(["fixture: the swap did not commit (%s)" % _last_denied(fc)])
	var r2 := _reboot(rt.save_path, { "pack": 1, "cap": 2 })
	var out := r2.dispatch({ "type": "flow.continue" })
	var d: Dictionary = out.get("data", {}) if out.get("data", {}) is Dictionary else {}
	var r2_rec := PickupEventService.record_of(FlowStageExploreState._get_current_stage(r2.flow_ctx))
	if str(out.get("type", "")) != FlowStateIds.PICKUP or str(d.get("phase", "")) != PickupSnapshotBuilder.PHASE_IDLE:
		m.append("reload: type '%s', phase '%s'" % [out.get("type", ""), d.get("phase", "")])
	elif not bool((d["swap"] as Dictionary)["spent"]) or int(d["swap_left"]) != 0 \
			or str(((d["swap"] as Dictionary)["dropped"] as Dictionary).get("type_id", "")) != _type_of_find(rec, x):
		m.append("reload swap view %s, swap_left %s" % [ItemPacksTests._norm(d["swap"]), str(d["swap_left"])])
	if str((r2_rec.get("swap", {}) as Dictionary).get("find_id", "")) != y \
			or str(((r2_rec.get("swap", {}) as Dictionary).get("dropped", {}) as Dictionary).get("type_id", "")) != _type_of_find(rec, x) \
			or not PickupEventService.swap_used(FlowStageExploreState._get_current_stage(r2.flow_ctx)):
		m.append("reload record swap %s" % ItemPacksTests._norm(r2_rec.get("swap", {})))
	var res := r2.dispatch({ "type": "pickup.continue", "payload": {} })
	var pr_v: Variant = (res.get("data", {}) as Dictionary).get("pickup_result", null)
	var pr: Dictionary = pr_v if pr_v is Dictionary else {}
	if str(res.get("type", "")) != FlowStateIds.RESOLVE or not bool(pr.get("swap_used", false)) \
			or _row_types(pr.get("taken", [])) != [_type_of_find(rec, y)] or _row_types(pr.get("left", [])) != [_type_of_find(rec, x)] \
			or str((pr.get("dropped", {}) as Dictionary).get("type_id", "")) != _type_of_find(rec, x):
		m.append("final card after the reload: type '%s', pickup_result %s" % [res.get("type", ""), _json(pr)])
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# F1: a stage-clearing card shows the path-end items and the stage payout as they are after the event and the swap.
# ---------------------------------------------------------------------------

static func _t_stage_clear_items() -> Dictionary:
	var env := _fight("stage_items", 2, 3, ["ph_weapon_a", "ph_relic_a", "ph_charm_a"], true)
	if not bool(env["ok"]):
		_done(env)
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc: FlowContext = env["fc"]
	var ectx: EncounterContext = env["ectx"]
	var rec := _record(fc)
	if not (ectx.final_snapshot["data"] as Dictionary).has("stage_payout_rows") \
			or (rec["taken"] as Array).size() != 2 or (rec["left"] as Array).size() != 1:
		_done(env)
		return _result(["fixture: stage card %s, taken %s, left %s, frozen %s" % [
			str((ectx.final_snapshot["data"] as Dictionary).has("stage_payout_rows")), str(rec["taken"]), str(rec["left"]), str(rec["frozen"])]])
	var y := str(rec["left"][0])
	var row_id := EarningsService.item_id(str(rec["situation_id"]), str(rec["taken"][0]))
	for s: Array in [["pickup.skip", {}], ["pickup.select", { "find_id": y }], ["pickup.swap.start", {}],
			["pickup.swap.pick", { "id": row_id }], ["pickup.swap.confirm", {}]]:
		rt.dispatch({ "type": s[0], "payload": s[1] })
	if str((_record(fc)["swap"] as Dictionary).get("find_id", "")) != y:
		m.append("the swap did not commit: '%s'" % _last_denied(fc))
	var res := rt.dispatch({ "type": "pickup.continue", "payload": {} })
	var fresh := StageSettlementService.new(fc, fc.config_service, null, null).preview()
	var data: Dictionary = res.get("data", {}) if res.get("data", {}) is Dictionary else {}
	var want_items: Dictionary = fresh.get("items", {})
	if want_items.is_empty():
		m.append("fixture: the fresh preview has no items block, so the test cannot see the defect")
	if ItemPacksTests._norm((ectx.final_snapshot["data"] as Dictionary).get("items", {})) == ItemPacksTests._norm(want_items):
		m.append("fixture: the held card already showed the event's items")
	if ItemPacksTests._norm(data.get("items", {})) != ItemPacksTests._norm(want_items):
		m.append("card items %s, fresh preview %s" % [ItemPacksTests._norm(data.get("items", {})), ItemPacksTests._norm(want_items)])
	if ItemPacksTests._norm([data.get("stage_payout_rows"), data.get("stage_payout_ase"), data.get("stage_payout_ekwan")]) \
			!= ItemPacksTests._norm([fresh.get("rows"), fresh.get("ase"), fresh.get("ekwan")]):
		m.append("card stage payout differs from a fresh preview")
	var stored: Dictionary = _pending(fc).get("resolve_data", {})
	if ItemPacksTests._norm(stored.get("items", {})) != ItemPacksTests._norm(want_items) \
			or ItemPacksTests._norm(stored.get("stage_payout_rows")) != ItemPacksTests._norm(fresh.get("rows")):
		m.append("the pending result keeps the old items or payout")
	var replay: Dictionary = PendingResultService.build_snapshot(fc, 999)["data"]
	if ItemPacksTests._norm(replay.get("items", {})) != ItemPacksTests._norm(want_items):
		m.append("producer G replays other items")
	_done(env)
	return _result(m)
