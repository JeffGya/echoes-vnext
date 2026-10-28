# res://tests/InventoryActionTests.gd
# V2-ITEM-001a step 5: the action path. inventory.discard.apply and debug.inventory.produce through
# FlowRuntime.dispatch, and the data.inventory projection of the flow.sanctum snapshot.
# Tests use their own inventory cfg (InventoryServiceTests._cfg) and the placeholder fixture. They never read
# the PROVISIONAL numbers (D-25).
# Report: docs/stories/v2-item-001/step5-actions.md

class_name InventoryActionTests
extends RefCounted

const _PRODUCER_ACTION := "debug.inventory.produce"
const _PRODUCER_HANDLER := "handle_inventory_produce"
## The only files that may name the producer action or its handler. AppRoot is listed for its console command
## `inventory produce`; no file in core/ other than these two names either.
const _ACTION_FILES: Array = ["res://core/runtime/FlowRuntime.gd", "res://core/runtime/controllers/DebugController.gd",
		"res://ui/AppRoot.gd"]
const _HANDLER_FILES: Array = ["res://core/runtime/FlowRuntime.gd", "res://core/runtime/controllers/DebugController.gd"]
const _PH_FILES: Array = ["res://core/runtime/controllers/DebugController.gd"]


class _Cfg extends ConfigService:
	var inv: Dictionary = {}

	func get_balance() -> Dictionary:
		var b := super.get_balance()
		var d: Dictionary = b.get("data", {})
		d["inventory"] = inv.duplicate(true)
		b["data"] = d
		return b


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_actions/discard_a_sanctum_piece", Callable(InventoryActionTests, "_t_discard_sanctum"))
	runner.register_test("inventory_actions/discard_a_pack_piece", Callable(InventoryActionTests, "_t_discard_pack"))
	runner.register_test("inventory_actions/discard_refusals_change_nothing", Callable(InventoryActionTests, "_t_refusals"))
	runner.register_test("inventory_actions/discard_with_an_open_path", Callable(InventoryActionTests, "_t_path_open"))
	runner.register_test("inventory_actions/producer_direct", Callable(InventoryActionTests, "_t_produce_direct"))
	runner.register_test("inventory_actions/producer_denials_change_nothing", Callable(InventoryActionTests, "_t_produce_denials"))
	runner.register_test("inventory_actions/producer_gather_needs_a_live_path", Callable(InventoryActionTests, "_t_produce_gather"))
	runner.register_test("inventory_actions/producer_with_a_missing_fixture", Callable(InventoryActionTests, "_t_produce_no_fixture"))
	runner.register_test("inventory_actions/placeholders_appear_only_after_the_producer", Callable(InventoryActionTests, "_t_leak_guard"))
	runner.register_test("inventory_actions/no_other_code_calls_the_producer", Callable(InventoryActionTests, "_t_producer_callers"))
	runner.register_test("inventory_actions/snapshot_field_shape", Callable(InventoryActionTests, "_t_snapshot_shape"))
	runner.register_test("inventory_actions/snapshot_field_is_a_copy", Callable(InventoryActionTests, "_t_snapshot_copy"))
	runner.register_test("inventory_actions/discard_then_json_round_trip", Callable(InventoryActionTests, "_t_round_trip"))
	runner.register_test("inventory_actions/leave_item_report_reaches_the_card_and_survives_a_reload", Callable(InventoryActionTests, "_t_leave_chain"))
	runner.register_test("inventory_actions/item_free_leave_card_has_no_items_key", Callable(InventoryActionTests, "_t_leave_item_free"))
	runner.register_test("inventory_actions/return_home_is_refused_off_the_path", Callable(InventoryActionTests, "_t_return_home_refused"))
	runner.register_test("inventory_actions/path_end_item_report_reaches_the_destination_snapshot", Callable(InventoryActionTests, "_t_path_end_report"))
	runner.register_test("inventory_actions/discard_blocked_key_and_the_live_path_rule", Callable(InventoryActionTests, "_t_discard_blocked"))
	runner.register_test("inventory_actions/discard_guard_works_from_saved_state_after_a_reload", Callable(InventoryActionTests, "_t_discard_reload"))
	runner.register_test("inventory_actions/path_end_report_is_not_resent_by_a_later_dispatch", Callable(InventoryActionTests, "_t_clear_items_spent"))
	runner.register_test("inventory_actions/path_end_report_is_dropped_when_the_party_goes_to_the_stage_map", Callable(InventoryActionTests, "_t_clear_items_stage_map"))
	runner.register_test("inventory_actions/party_prep_inventory_is_always_present_and_a_copy", Callable(InventoryActionTests, "_t_party_prep_item_free"))
	runner.register_test("inventory_actions/sanctum_and_party_prep_count_open_rows_of_every_realm", Callable(InventoryActionTests, "_t_reserved_and_party_prep"))
	runner.register_test("inventory_actions/the_console_producer_is_gated_to_debug_builds", Callable(InventoryActionTests, "_t_console_gate"))
	runner.register_test("inventory_actions/same_dispatches_give_the_same_json", Callable(InventoryActionTests, "_t_determinism"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## A booted runtime in flow.sanctum with its own inventory cfg (empty definitions). Returns
## { rt, logger, cfg, inv_cfg, path }.
static func _env(tag: String, cap: int, pack: int) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	var cfg := _Cfg.new()
	cfg.inv = InventoryServiceTests._cfg(cap, pack, 5, 1, 1, false)
	var path := TestSaveHarness.fresh_save_path("inventory_actions_%s.json" % tag, "inventory_actions")
	var rt := FlowRuntime.new(logger, cfg, path)
	rt.boot()
	rt.flow_machine.transition(FlowStateIds.SANCTUM, rt.flow_ctx, logger, 1, "test")
	# Entering the Sanctum queues a layout save; one dispatch flushes it, so the tests count their own flushes.
	rt.dispatch({ "type": "debug.seed.show" })
	return { "rt": rt, "logger": logger, "cfg": cfg, "inv_cfg": cfg.inv, "path": path }


static func _done(env: Dictionary) -> void:
	TestSaveHarness.remove_save_artifacts(str(env["path"]))


static func _save(env: Dictionary) -> Dictionary:
	return (env["rt"] as FlowRuntime).flow_ctx.save_data


## Seeds the inventory straight through the service (direct mode), in the order given.
static func _seed(env: Dictionary, type_ids: Array) -> void:
	for type_id in type_ids:
		InventoryService.intake(_save(env), env["inv_cfg"], InventoryServiceTests._e(str(type_id)), "direct")


static func _ids(env: Dictionary, key: String) -> Array:
	return InventoryServiceTests._ids(_save(env), key)


static func _flushes(logger: StructuredLogger) -> int:
	var n := 0
	for e in logger.get_logs():
		if str((e as Dictionary).get("type", "")) == "save.flush":
			n += 1
	return n


static func _log_count(logger: StructuredLogger, type: String) -> int:
	var n := 0
	for e in logger.get_logs():
		if str((e as Dictionary).get("type", "")) == type:
			n += 1
	return n


## Dispatches one action and returns the number of save flushes it caused.
static func _dispatch(env: Dictionary, action: Dictionary) -> int:
	var logger: StructuredLogger = env["logger"]
	logger.clear()
	(env["rt"] as FlowRuntime).dispatch(action)
	return _flushes(logger)


static func _discard(id: Variant) -> Dictionary:
	return { "type": "inventory.discard.apply", "payload": { "item_id": id } }


static func _snap(env: Dictionary) -> Dictionary:
	return (env["rt"] as FlowRuntime).flow_ctx.last_snapshot


static func _inv_snap(env: Dictionary) -> Dictionary:
	var data: Dictionary = _snap(env).get("data", {})
	var v: Variant = data.get("inventory", null)
	return v if v is Dictionary else {}


## What the controller reports for an action: the outcome's error_code ("" on success). The controller is
## built beside the runtime and writes the same save, so this is used only for a refused action.
static func _refusal_key(env: Dictionary, action: Dictionary) -> String:
	var rt: FlowRuntime = env["rt"]
	var c := InventoryController.new(rt.flow_ctx, rt.config_service, env["logger"])
	return c.handle_discard(action, 9).error_code


## Top-level save keys whose value differs between a saved copy and the live save.
static func _top_diff(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for k in after:
		if not before.has(k) or _norm(before[k]) != _norm(after[k]):
			out.append(str(k))
	return out


static func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))


# ---------------------------------------------------------------------------
# Discard
# ---------------------------------------------------------------------------

## Cap 2, pack 2. Two Sanctum pieces, one held piece. Discarding a Sanctum piece frees a slot and the held
## piece moves in. One save flush. The snapshot is rebuilt.
static func _t_discard_sanctum() -> Dictionary:
	var m: Array = []
	var env := _env("sanctum", 2, 2)
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a"])
	if str(_ids(env, "items")) != str(["it.1", "it.2"]) or str(_ids(env, "pack")) != str(["it.3"]):
		m.append("seed: items %s pack %s" % [str(_ids(env, "items")), str(_ids(env, "pack"))])
	var flushes := _dispatch(env, _discard("it.1"))
	if flushes != 1:
		m.append("expected 1 save flush, got %d" % flushes)
	if str(_ids(env, "items")) != str(["it.2", "it.3"]) or not _ids(env, "pack").is_empty():
		m.append("after: items %s pack %s" % [str(_ids(env, "items")), str(_ids(env, "pack"))])
	if _save(env)["inventory"]["stacks"].size() != 1:
		m.append("the stack changed")
	var snap := _inv_snap(env)
	if str(_snap(env).get("type", "")) != FlowStateIds.SANCTUM or int(snap.get("unique_count", -1)) != 2 \
			or int(snap.get("pack_count", -1)) != 0:
		m.append("snapshot not rebuilt: %s" % str(snap))
	if _log_count(env["logger"], "inventory.discard") != 1:
		m.append("expected one inventory.discard log")
	_done(env)
	# The outcome itself carries one save reason and a reenter. (Re-entering the Sanctum may also queue a
	# save of its own, so the flush count above cannot prove the controller asked.)
	var env2 := _env("sanctum_outcome", 2, 2)
	_seed(env2, ["ph_weapon_a", "ph_charm_a"])
	var rt2: FlowRuntime = env2["rt"]
	var out := InventoryController.new(rt2.flow_ctx, rt2.config_service, env2["logger"]).handle_discard(_discard("it.1"), 9)
	if str(out.save_reasons) != str(["inventory.discard"]) or not out.requires_reenter or out.error_code != "":
		m.append("outcome: reasons %s reenter %s error '%s'" % [str(out.save_reasons), str(out.requires_reenter), out.error_code])
	var refused := InventoryController.new(rt2.flow_ctx, rt2.config_service, env2["logger"]).handle_discard(_discard("it.99"), 9)
	if not refused.save_reasons.is_empty() or refused.requires_reenter or refused.has_replacement_snapshot:
		m.append("a refusal asked for a save or a snapshot")
	_done(env2)
	return _result(m)


## Cap 2, pack 2. Discarding the held piece frees a pack slot and no Sanctum room.
static func _t_discard_pack() -> Dictionary:
	var m: Array = []
	var env := _env("pack", 2, 2)
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a"])
	if str(_ids(env, "pack")) != str(["it.3", "it.4"]):
		m.append("seed pack %s" % str(_ids(env, "pack")))
	var flushes := _dispatch(env, _discard("it.4"))
	if flushes != 1:
		m.append("expected 1 save flush, got %d" % flushes)
	if str(_ids(env, "items")) != str(["it.1", "it.2"]) or str(_ids(env, "pack")) != str(["it.3"]):
		m.append("after: items %s pack %s" % [str(_ids(env, "items")), str(_ids(env, "pack"))])
	if int(_inv_snap(env).get("pack_free", -1)) != 1:
		m.append("pack_free in the snapshot %s" % str(_inv_snap(env).get("pack_free")))
	_done(env)
	return _result(m)


## Unknown id, stack id, bad payloads, an equipped piece and a request away from the Sanctum. Each: the save
## is byte-equal, no flush, no snapshot change, and the controller names the reason.
static func _t_refusals() -> Dictionary:
	var m: Array = []
	var env := _env("refuse", 2, 2)
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a"])
	var before := JSON.stringify(_save(env), "", true)
	var before_copy: Dictionary = JSON.parse_string(before)
	var snap_before := JSON.stringify(_snap(env), "", true)
	var cases: Array = [
		["unknown id", _discard("it.99"), "not_found"],
		["stack id", _discard("ph_consumable_a"), "not_unique"],
		["missing id", { "type": "inventory.discard.apply", "payload": {} }, "bad_payload"],
		["no payload", { "type": "inventory.discard.apply" }, "bad_payload"],
		["non-String id", _discard(5), "bad_payload"],
		["empty id", _discard(""), "bad_payload"],
	]
	for c in cases:
		var flushes := _dispatch(env, c[1])
		if flushes != 0:
			m.append("%s: %d flushes" % [c[0], flushes])
		if JSON.stringify(_save(env), "", true) != before:
			m.append("%s: the save changed in %s" % [c[0], str(_top_diff(before_copy, _save(env)))])
		if JSON.stringify(_snap(env), "", true) != snap_before:
			m.append("%s: the snapshot changed" % c[0])
		if _log_count(env["logger"], "inventory.discard.denied") != 1:
			m.append("%s: expected one inventory.discard.denied log" % c[0])
		var key := _refusal_key(env, c[1])
		if key != c[2]:
			m.append("%s: reason %s, expected %s" % [c[0], key, c[2]])
	# Equipped piece.
	(((_save(env)["inventory"] as Dictionary)["items"] as Array)[0] as Dictionary)["held_by"] = "e1"
	var before_eq := JSON.stringify(_save(env), "", true)
	if _dispatch(env, _discard("it.1")) != 0 or JSON.stringify(_save(env), "", true) != before_eq:
		m.append("equipped: the save or the flush count changed")
	if _refusal_key(env, _discard("it.1")) != "equipped":
		m.append("equipped: reason %s" % _refusal_key(env, _discard("it.1")))
	# Away from the Sanctum (the party is on a path or in another screen).
	(((_save(env)["inventory"] as Dictionary)["items"] as Array)[0] as Dictionary)["held_by"] = ""
	var rt: FlowRuntime = env["rt"]
	rt.flow_machine.transition(FlowStateIds.STAGE_MAP, rt.flow_ctx, env["logger"], 2, "test")
	var away_type := str(_snap(env).get("type", ""))
	var before_away := JSON.stringify(_save(env), "", true)
	if away_type == FlowStateIds.SANCTUM:
		m.append("the test could not leave the Sanctum")
	if _dispatch(env, _discard("it.1")) != 0 or JSON.stringify(_save(env), "", true) != before_away:
		m.append("away: the save or the flush count changed")
	if _refusal_key(env, _discard("it.1")) != "not_in_sanctum":
		m.append("away: reason %s" % _refusal_key(env, _discard("it.1")))
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# Debug producer
# ---------------------------------------------------------------------------

## Defaults: three unique pieces fill cap 3, the consumable stacks. One flush. The cfg stays without
## definitions: the overlay lived in the call only.
## D-27: a discard is refused with `path_open` while the live path has an unsettled, not-lost item row, even
## when the last snapshot is flow.sanctum. A settled or lost row, or no live path, allows it.
static func _t_path_open() -> Dictionary:
	var m: Array = []
	var env := _env("pathopen", 3, 2)
	_seed(env, ["ph_weapon_a", "ph_charm_a"])
	var ids := _ids(env, "items")
	# (d) no live path: allowed.
	if _refusal_key(env, _discard("it.99")) != "not_found":
		m.append("no live path: the path check came first")
	# (a) one open item row: refused, nothing changes.
	_live_path(env)
	var stage: Dictionary = (((_save(env)["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array)[0]
	var row := { "id": "item:test:1", "items": [{ "type_id": "ph_relic_a", "kind": "relic", "grade": "", "quantity": 1 }],
		"settled": false, "lost": false }
	(stage["earnings"] as Array).append(row)
	if str(_snap(env).get("type", "")) != FlowStateIds.SANCTUM:
		m.append("the snapshot is not flow.sanctum")
	var before := JSON.stringify(_save(env), "", true)
	var flushes := _dispatch(env, _discard(ids[0]))
	if flushes != 0 or JSON.stringify(_save(env), "", true) != before:
		m.append("open row: flushes %d or the save changed" % flushes)
	if _refusal_key(env, _discard(ids[0])) != "path_open":
		m.append("open row: reason is not path_open")
	# (b) the same row settled, then lost: allowed.
	row["settled"] = true
	if _refusal_key(env, _discard("it.99")) != "not_found":
		m.append("settled row: still refused path_open")
	row["settled"] = false
	row["lost"] = true
	if _refusal_key(env, _discard("it.99")) != "not_found":
		m.append("lost row: still refused path_open")
	row["lost"] = false
	row["settled"] = true
	_dispatch(env, _discard(ids[0]))
	if _ids(env, "items").has(ids[0]):
		m.append("settled row: the discard did not remove the piece")
	# (c) the same id again: not_found.
	if _refusal_key(env, _discard(ids[0])) != "not_found":
		m.append("second discard of the same id is not not_found")
	_done(env)
	return _result(m)


static func _t_produce_direct() -> Dictionary:
	var m: Array = []
	var env := _env("produce", 3, 1)
	var flushes := _dispatch(env, { "type": _PRODUCER_ACTION })
	if flushes != 1:
		m.append("expected 1 save flush, got %d" % flushes)
	var inv: Dictionary = _save(env)["inventory"]
	var types: Array = (inv["items"] as Array).map(func(p): return str(p["type_id"]))
	if str(types) != str(["ph_weapon_a", "ph_charm_a", "ph_relic_a"]):
		m.append("items %s" % str(types))
	if str(_ids(env, "items")) != str(["it.1", "it.2", "it.3"]):
		m.append("ids %s" % str(_ids(env, "items")))
	if (inv["stacks"] as Array).size() != 1 or str(inv["stacks"][0]["type_id"]) != "ph_consumable_a" \
			or int(inv["stacks"][0]["quantity"]) != 1:
		m.append("stacks %s" % str(inv["stacks"]))
	if not (inv["pack"] as Array).is_empty():
		m.append("the pack is not empty")
	var cfg_defs: Variant = ConfigService.get_inventory_cfg(env["cfg"]).get("definitions", null)
	if not (cfg_defs is Dictionary) or not (cfg_defs as Dictionary).is_empty():
		m.append("the cfg kept the overlay: %s" % str(cfg_defs))
	if int(_inv_snap(env).get("unique_count", -1)) != 3:
		m.append("snapshot unique_count %s" % str(_inv_snap(env).get("unique_count")))
	# Explicit ids: a fourth piece goes to the pack, a fifth is lost (direct mode, overflow).
	var env2 := _env("produce2", 1, 1)
	_dispatch(env2, { "type": _PRODUCER_ACTION, "payload": { "ids": ["ph_weapon_a", "ph_charm_a", "ph_relic_a"], "mode": "direct" } })
	if str(_ids(env2, "items")) != str(["it.1"]) or str(_ids(env2, "pack")) != str(["it.2"]):
		m.append("explicit ids: items %s pack %s" % [str(_ids(env2, "items")), str(_ids(env2, "pack"))])
	_done(env)
	_done(env2)
	return _result(m)


## Bad mode, an id the fixture lacks, a stack-only list with a bad id after a good one: the whole call is
## denied, nothing changes, no flush, a denied log, and the controller names the reason.
static func _t_produce_denials() -> Dictionary:
	var m: Array = []
	var env := _env("deny", 3, 1)
	var before := JSON.stringify(_save(env), "", true)
	var cases: Array = [
		["bad mode", { "mode": "bogus" }, "bad_mode"],
		["unknown id after a good one", { "ids": ["ph_weapon_a", "nope"] }, "unknown_id"],
		["non-String id", { "ids": [7] }, "unknown_id"],
	]
	var rt: FlowRuntime = env["rt"]
	for c in cases:
		var action := { "type": _PRODUCER_ACTION, "payload": c[1] }
		var flushes := _dispatch(env, action)
		if flushes != 0 or JSON.stringify(_save(env), "", true) != before:
			m.append("%s: flushes %d or the save changed" % [c[0], flushes])
		if _log_count(env["logger"], "debug.inventory.produce.denied") != 1:
			m.append("%s: no denied log" % c[0])
		var key := DebugController.new(rt.flow_ctx, rt.config_service, env["logger"]).handle_inventory_produce(action, 9).error_code
		if key != c[2]:
			m.append("%s: reason %s, expected %s" % [c[0], key, c[2]])
	_done(env)
	return _result(m)


## A minimal live path: a realm record with stage 0 and `flow_ctx.realm_id` / `stage_id` set.
static func _live_path(env: Dictionary) -> void:
	var rt: FlowRuntime = env["rt"]
	var save := _save(env)
	(save["realms"] as Dictionary)["realm.01"] = { "run_count": 0, "seed": 1, "stages": [
		{ "index": 0, "objectives": [], "earnings": [], "settlement_receipt": {}, "explore_map": { "situations": [], "locked": true } }] }
	rt.flow_ctx.realm_id = "realm.01"
	rt.flow_ctx.stage_id = "stage.0"


static func _rows(env: Dictionary) -> Array:
	var stage: Dictionary = (((_save(env)["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array)[0]
	return (stage["earnings"] as Array).map(func(r): return str(r["id"]))


## `gather` writes item rows through the seam (one slot each, up to the free room) and touches no container.
## Without a live path it is denied.
static func _t_produce_gather() -> Dictionary:
	var m: Array = []
	var env := _env("gather", 5, 2)
	_live_path(env)
	var inv_before := JSON.stringify(_save(env)["inventory"], "", true)
	var flushes := _dispatch(env, { "type": _PRODUCER_ACTION,
		"payload": { "ids": ["ph_weapon_a", "ph_charm_a", "ph_relic_a"], "mode": "gather" } })
	if flushes != 1:
		m.append("expected 1 save flush, got %d" % flushes)
	var rows := _rows(env)
	if rows.size() != 2 or not str(rows[0]).begins_with("item:debug:") or str(rows[0]) == str(rows[1]):
		m.append("rows %s (pack room is 2)" % str(rows))
	if JSON.stringify(_save(env)["inventory"], "", true) != inv_before:
		m.append("gather changed the containers")
	# A second call has a new tick, so its finds are new; the pack is full, so nothing is gathered.
	_dispatch(env, { "type": _PRODUCER_ACTION, "payload": { "ids": ["ph_armor_a"], "mode": "gather" } })
	if _rows(env).size() != 2:
		m.append("a full pack took another row: %s" % str(_rows(env)))
	# No live path: realm set, stage id empty; and realm empty.
	var rt: FlowRuntime = env["rt"]
	var save_before := JSON.stringify(_save(env), "", true)
	var gather := { "type": _PRODUCER_ACTION, "payload": { "mode": "gather" } }
	rt.flow_ctx.stage_id = ""
	if _dispatch(env, gather) != 0 or JSON.stringify(_save(env), "", true) != save_before:
		m.append("no stage id: the save or the flush count changed")
	rt.flow_ctx.stage_id = "stage.0"
	rt.flow_ctx.realm_id = ""
	if _dispatch(env, gather) != 0 or JSON.stringify(_save(env), "", true) != save_before:
		m.append("no realm: the save or the flush count changed")
	var key := DebugController.new(rt.flow_ctx, rt.config_service, env["logger"]).handle_inventory_produce(gather, 9).error_code
	if key != "no_live_path":
		m.append("reason %s, expected no_live_path" % key)
	_done(env)
	return _result(m)


static func _t_produce_no_fixture() -> Dictionary:
	var m: Array = []
	var env := _env("nofixture", 3, 1)
	var rt: FlowRuntime = env["rt"]
	var before := JSON.stringify(_save(env), "", true)
	var dbg := DebugController.new(rt.flow_ctx, rt.config_service, env["logger"])
	dbg.produce_fixture_path = "res://tests/fixtures/does_not_exist.json"
	var outcome := dbg.handle_inventory_produce({ "type": _PRODUCER_ACTION }, 9)
	if outcome.error_code != "fixture_missing" or not outcome.save_reasons.is_empty():
		m.append("outcome %s / %s" % [outcome.error_code, str(outcome.save_reasons)])
	if JSON.stringify(_save(env), "", true) != before:
		m.append("the save changed")
	if _log_count(env["logger"], "debug.inventory.produce.denied") != 1:
		m.append("no denied log")
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# Leak guards
# ---------------------------------------------------------------------------

## A new save and the discard path hold no `ph_` string. After the producer ran, `ph_` pieces are in the save
## and every piece id still starts `it.`.
static func _t_leak_guard() -> Dictionary:
	var m: Array = []
	var env := _env("leak", 3, 1)
	if InventorySaveTests._has_placeholder_id(JSON.stringify(_save(env))):
		m.append("a new save holds a ph_ id")
	_dispatch(env, _discard("it.1"))
	_dispatch(env, _discard("ph_weapon_a"))
	if InventorySaveTests._has_placeholder_id(JSON.stringify(_save(env))):
		m.append("a refused discard wrote a ph_ id")
	_dispatch(env, { "type": _PRODUCER_ACTION })
	var text := JSON.stringify(_save(env))
	if not InventorySaveTests._has_placeholder_id(text):
		m.append("the producer left no ph_ id")
	var inv: Dictionary = _save(env)["inventory"]
	for p in (inv["items"] as Array) + (inv["pack"] as Array):
		if not str(p["id"]).begins_with("it.") or not str(p["type_id"]).begins_with("ph_"):
			m.append("piece %s" % str(p))
	_done(env)
	return _result(m)


## The repo has no debug gate in core: a `debug.*` action is reached by the F1 console only because nothing
## else sends it. This test pins that. Only the files in the allow lists may name the producer.
static func _t_producer_callers() -> Dictionary:
	var m: Array = []
	var files: Array = []
	_walk("res://core", files)
	_walk("res://ui", files)
	if files.size() < 100:
		m.append("the file walk found only %d files" % files.size())
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		if text.contains(_PRODUCER_ACTION) and not _ACTION_FILES.has(path):
			m.append("%s names %s" % [path, _PRODUCER_ACTION])
		if text.contains(_PRODUCER_HANDLER) and not _HANDLER_FILES.has(path):
			m.append("%s names %s" % [path, _PRODUCER_HANDLER])
		if str(path).begins_with("res://core") and not _PH_FILES.has(path) and InventorySaveTests._has_placeholder_id(text):
			m.append("%s holds a ph_ id" % path)
	# FlowRuntime routes the action to the debug controller and to no other.
	var rt_text := FileAccess.get_file_as_string("res://core/runtime/FlowRuntime.gd")
	if rt_text.count("handle_inventory_produce") != 1 or rt_text.count("\"debug.inventory.produce\":") != 1:
		m.append("FlowRuntime does not route the producer exactly once")
	return _result(m)


# ---------------------------------------------------------------------------
# Snapshot field
# ---------------------------------------------------------------------------

static func _sorted_keys(d: Dictionary) -> String:
	var k: Array = d.keys()
	k.sort()
	return str(k)


static func _forbidden_keys(v: Variant, path: String, out: Array) -> void:
	if v is Dictionary:
		for k in (v as Dictionary):
			var low := str(k).to_lower()
			for tok in low.split("_"):
				if tok == "thread" or tok == "ase" or tok == "ekwan" or tok == "threads":
					out.append("%s.%s" % [path, str(k)])
			_forbidden_keys((v as Dictionary)[k], "%s.%s" % [path, str(k)], out)
	elif v is Array:
		for i in (v as Array).size():
			_forbidden_keys((v as Array)[i], "%s[%d]" % [path, i], out)


static func _t_snapshot_shape() -> Dictionary:
	var m: Array = []
	var env := _env("shape", 2, 2)
	var rt: FlowRuntime = env["rt"]
	# A fresh game: the field exists and is empty.
	var fresh := _inv_snap(env)
	if fresh.is_empty() or int(fresh.get("unique_count", -1)) != 0 or int(fresh.get("unique_cap", -1)) != 2:
		m.append("fresh field %s" % str(fresh))
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a"])
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 3)
	var snap := _inv_snap(env)
	var want_keys := str(["items", "pack", "pack_capacity", "pack_count", "pack_free", "pack_load", "sanctum_room",
		"stacks", "unique_cap", "unique_count", "warn"])
	if _sorted_keys(snap) != want_keys:
		m.append("keys %s" % _sorted_keys(snap))
	if int(snap["unique_count"]) != 2 or int(snap["unique_cap"]) != 2 or int(snap["sanctum_room"]) != 0 \
			or int(snap["pack_count"]) != 1 or int(snap["pack_capacity"]) != 2 or int(snap["pack_free"]) != 1:
		m.append("counts %s" % str(snap))
	var row_keys := str(["equipped", "grade", "id", "kind", "mark_index", "type_id"])
	for r in (snap["items"] as Array) + (snap["pack"] as Array):
		if _sorted_keys(r) != row_keys:
			m.append("piece row keys %s" % _sorted_keys(r))
	if (snap["items"] as Array).size() != 2 or (snap["pack"] as Array).size() != 1 or (snap["stacks"] as Array).size() != 1:
		m.append("row counts %s" % str(snap))
	if _sorted_keys(snap["stacks"][0]) != str(["at_limit", "kind", "limit", "quantity", "type_id"]):
		m.append("stack row keys %s" % _sorted_keys(snap["stacks"][0]))
	if _sorted_keys(snap["pack_load"]) != str(["capacity", "carried", "free", "level"]) \
			or _sorted_keys(snap["warn"]) != str(["pack", "room"]):
		m.append("pack_load / warn keys")
	var bad: Array = []
	_forbidden_keys(snap, "inventory", bad)
	if not bad.is_empty():
		m.append("forbidden keys %s" % str(bad))
	# The discard is dispatched by the row: no slot in actions.
	for slot in (_snap(env)["actions"] as Dictionary):
		if str(slot).contains("inventory") or str(slot).contains("discard"):
			m.append("actions holds a slot %s" % str(slot))
	_done(env)
	return _result(m)


static func _t_snapshot_copy() -> Dictionary:
	var m: Array = []
	var env := _env("copy", 2, 2)
	var rt: FlowRuntime = env["rt"]
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a"])
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 3)
	var save_before := JSON.stringify(_save(env), "", true)
	var snap := _inv_snap(env)
	var snap_before := JSON.stringify(snap, "", true)
	# Mutate every part of the projection.
	((snap["items"] as Array)[0] as Dictionary)["type_id"] = "x"
	(snap["items"] as Array).clear()
	(snap["pack"] as Array).append({ "id": "it.77" })
	((snap["stacks"] as Array)[0] as Dictionary)["quantity"] = 99
	(snap["pack_load"] as Dictionary)["free"] = 99
	(snap["warn"] as Dictionary)["room"] = true
	snap["unique_cap"] = 99
	if JSON.stringify(_save(env), "", true) != save_before:
		m.append("a change to the projection reached the save")
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 4)
	if JSON.stringify(_inv_snap(env), "", true) != snap_before:
		m.append("a rebuilt projection differs from the first")
	_done(env)
	return _result(m)


# ---------------------------------------------------------------------------
# Round trip and determinism
# ---------------------------------------------------------------------------

## After a discard the save goes through JSON and comes back. A second discard on the original and on the loaded
## copy gives the same result and the same state, and `validate` is clean.
static func _t_round_trip() -> Dictionary:
	var m: Array = []
	var env := _env("trip", 2, 3)
	_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a", "ph_consumable_a"])
	_dispatch(env, _discard("it.2"))
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(_save(env)))
	var cfg: Dictionary = env["inv_cfg"]
	if _norm(_save(env)["inventory"]) != _norm(loaded["inventory"]):
		m.append("the inventory block changed in the round trip")
	var problems := InventoryService.validate(loaded, cfg)
	if not problems.is_empty():
		m.append("validate: %s" % str(problems))
	var a := InventoryService.discard(_save(env), cfg, "it.3", true)
	var b := InventoryService.discard(loaded, cfg, "it.3", true)
	if _norm(a) != _norm(b) or _norm(_save(env)["inventory"]) != _norm(loaded["inventory"]):
		m.append("a second discard differs after the round trip: %s vs %s" % [_norm(a), _norm(b)])
	# The piece ids keep counting up: a new piece after the round trip gets the next number.
	var ia := InventoryService.intake(_save(env), cfg, InventoryServiceTests._e("ph_charm_a"), "direct")
	var ib := InventoryService.intake(loaded, cfg, InventoryServiceTests._e("ph_charm_a"), "direct")
	if str(ia["item_id"]) != str(ib["item_id"]) or str(ia["item_id"]) == "":
		m.append("next id differs: %s vs %s" % [str(ia["item_id"]), str(ib["item_id"])])
	_done(env)
	return _result(m)


## Items it.2 (charm) and it.4 (armor), stacks consumable 2 and material 1, next_seq 5. Numbers are floats
## because the value is read back from JSON.
const _PINNED_FINAL := '{"items":[{"grade":"g1","held_by":"","id":"it.2","kind":"gear","type_id":"ph_charm_a"},{"grade":"g1","held_by":"","id":"it.4","kind":"gear","type_id":"ph_armor_a"}],"next_seq":5.0,"pack":[],"stacks":[{"kind":"consumable","quantity":2.0,"type_id":"ph_consumable_a"},{"kind":"material","quantity":1.0,"type_id":"ph_material_a"}],"version":1.0}'


static func _run_sequence(tag: String) -> String:
	var env := _env(tag, 3, 2)
	_dispatch(env, { "type": _PRODUCER_ACTION })
	_dispatch(env, _discard("it.1"))
	_dispatch(env, _discard("it.3"))
	_dispatch(env, { "type": _PRODUCER_ACTION, "payload": { "ids": ["ph_armor_a", "ph_material_a", "ph_consumable_a"], "mode": "direct" } })
	_dispatch(env, _discard("nope"))
	var out := JSON.stringify(_save(env)["inventory"], "", true)
	_done(env)
	return out


static func _t_determinism() -> Dictionary:
	var m: Array = []
	var a := _run_sequence("det_a")
	var b := _run_sequence("det_b")
	if a != b:
		m.append("two runs differ:\n%s\n%s" % [a, b])
	var compact := JSON.stringify(JSON.parse_string(a))
	if compact != _PINNED_FINAL:
		m.append("pinned literal differs:\n%s" % compact)
	return _result(m)


# ---------------------------------------------------------------------------
# Step 6 fixes: leave item report, return_home guard, path-end report, discard_blocked, party prep
# ---------------------------------------------------------------------------

## A real runtime on `flow.stage_explore` (stage.0 of realm.01) with its own inventory cfg. Returns the
## VentureCharacterizationTests env ({ ok, runtime, logger }) or its failure dictionary.
static func _explore_env(tag: String, cap: int, pack: int) -> Dictionary:
	var env := VentureCharacterizationTests._setup_explore_env(tag)
	if not bool(env.get("ok", false)):
		return env
	var rt: FlowRuntime = env["runtime"]
	((rt.config_service._balance["data"] as Dictionary))["inventory"] = InventoryServiceTests._cfg(cap, pack, 5)
	env["rt"] = rt
	env["inv_cfg"] = ConfigService.get_inventory_cfg(rt.config_service)
	return env


static func _stage_of(env: Dictionary) -> Dictionary:
	return FlowStageExploreState._get_current_stage((env["runtime"] as FlowRuntime).flow_ctx)


## Sets the realm seed so the first leave rolls "all" and the escape succeeds. Returns false when none is found.
static func _force_leave_all(env: Dictionary) -> bool:
	var rt: FlowRuntime = env["runtime"]
	var fc := rt.flow_ctx
	var realm := VentureCharacterizationTests._realm(rt.get_save_data(), "realm.01")
	var turn := int((_stage_of(env)["explore_map"] as Dictionary).get("turn_count", 0))
	var mul := StageSettlementService.retention_mul(rt.directive_service.get_active_directive())
	for s in range(0, 20000):
		if EconomyCharacterizationTests._expected_outcome(s, int(realm.get("run_count", 0)), 0, mul) == "all" \
				and CampaignSeed.get_rng_from(s, "stage.escape.%s.%d" % [fc.stage_id, turn]).randi_range(0, 100) > 90:
			realm["seed"] = s
			return true
	return false


static func _row_of(type_id: String, qty: int, source: String, mark: int, reason: String = "") -> Dictionary:
	var out := { "type_id": type_id, "kind": InventoryServiceTests._kind_of(type_id), "grade": "g1", "quantity": qty,
		"source": source, "mark_index": mark }
	if not reason.is_empty():
		out["reason_key"] = reason
	return out


## B1 + B3 + reload. Cap 2, pack 2. The Sanctum holds two pieces, one piece is held (it.3), the path holds an armor
## row (becomes it.4, in the pack) and a stack row. The outcome is "all". The explore preview lists the three at
## risk; the scout-return card carries `items`; the context field is spent; a JSON reload replays the same block.
static func _t_leave_chain() -> Dictionary:
	var env := _explore_env("leave_chain", 2, 2)
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["runtime"]
	var fc := rt.flow_ctx
	var save := rt.get_save_data()
	for ty in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		InventoryService.intake(save, env["inv_cfg"], InventoryServiceTests._e(ty), "direct")
	EarningsService.record_item(_stage_of(env), "s0", "a", ItemPacksTests._entry("ph_armor_a"))
	EarningsService.record_item(_stage_of(env), "s0", "b", ItemPacksTests._entry("ph_consumable_a", 2))
	if not _force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	# The preview on the path.
	var pre: Dictionary = StageExploreSnapshotBuilder.build(fc, 5)["data"]["carry_home_preview"]
	var want_risk: Array = [_row_of("ph_armor_a", 1, "gathered", -1), _row_of("ph_consumable_a", 2, "gathered", -1),
		_row_of("ph_relic_a", 1, "held", 3)]
	if str(pre.get("items_at_risk", [])) != str(want_risk) or bool(pre["nothing_new"]) or int(pre["ase"]) != 0:
		m.append("preview %s" % str(pre))
	# The leave.
	var out: Dictionary = rt.dispatch({ "type": "stage.return_home" })
	var data: Dictionary = out.get("data", {})
	var want_kept: Array = [_row_of("ph_relic_a", 1, "held", 3, "to_pack"), _row_of("ph_armor_a", 1, "gathered", 4, "to_pack"),
		_row_of("ph_consumable_a", 2, "gathered", -1, "ok")]
	var want_items := { "kept": want_kept, "lost": [] }
	if str(out.get("type", "")) != FlowStateIds.RESOLVE or str(data.get("run_type", "")) != "scout_return" \
			or str(data.get("settle_outcome", "")) != "all":
		m.append("card: type %s, run_type %s, outcome %s" % [str(out.get("type")), str(data.get("run_type")), str(data.get("settle_outcome"))])
	if str(data.get("items", {})) != str(want_items):
		m.append("card items %s, expected %s" % [str(data.get("items")), str(want_items)])
	if not fc.pending_scout_return_items.is_empty():
		m.append("the context field was not spent by the dispatch")
	# Stored with the durable result, replayed after a JSON reload.
	var stored := PendingResultService.read(save)
	if str((stored.get("resolve_data", {}) as Dictionary).get("items", {})) != str(want_items):
		m.append("the durable result lacks the items block")
	var fc2 := FlowContext.new()
	fc2.save_data = JSON.parse_string(JSON.stringify(save))
	var replay: Dictionary = PendingResultService.build_snapshot(fc2, 9)
	if _norm((replay.get("data", {}) as Dictionary).get("items", null)) != _norm(want_items):
		m.append("the reloaded card items %s" % str((replay.get("data", {}) as Dictionary).get("items")))
	# A second build of the first card is the same (the builder is pure).
	fc.pending_scout_return_items = StageSettlementService.card_items({ "kept": want_kept, "lost": [] })
	var b1 := VentureResolveSnapshotBuilder.build_scout_return_snapshot(fc, 20)
	var b2 := VentureResolveSnapshotBuilder.build_scout_return_snapshot(fc, 20)
	if _norm(b1) != _norm(b2) or not (b1["data"] as Dictionary).has("items"):
		m.append("the scout-return builder is not pure or lost items")
	fc.pending_scout_return_items = {}
	return _result(m)


## The leave card of an item-free pack has no `items` key, and its keys are the step 1 keys.
static func _t_leave_item_free() -> Dictionary:
	var env := _explore_env("leave_plain", 2, 2)
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["runtime"]
	var pre: Dictionary = StageExploreSnapshotBuilder.build(rt.flow_ctx, 5)["data"]["carry_home_preview"]
	var pre_keys: Array = pre.keys()
	pre_keys.sort()
	if str(pre_keys) != str(["ase", "ekwan", "gathered", "nothing_new", "overcome", "total"]):
		m.append("item-free preview keys %s" % str(pre_keys))
	if not _force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	var out: Dictionary = rt.dispatch({ "type": "stage.return_home" })
	var data: Dictionary = out.get("data", {})
	if str(data.get("run_type", "")) != "scout_return" or data.has("items"):
		m.append("item-free card: run_type %s, has items %s" % [str(data.get("run_type")), str(data.has("items"))])
	var keys: Array = data.keys()
	keys.sort()
	var want_keys := ["actors", "ase_awarded", "ekwan_awarded", "intel_count", "ledger_seen", "rank", "reward_breakdown",
		"run_type", "settle_outcome", "summary_line", "surface", "verdict", "victory"]
	if str(keys) != str(want_keys):
		m.append("item-free card keys %s" % str(keys))
	return _result(m)


## M1: `stage.return_home` is refused unless the last snapshot is the path. Refusals: after the first leave (the
## scout-return card), in the Sanctum. A refusal does not settle, draw, save or change the snapshot, and it logs
## `stage.return.denied`. The held pieces are drawn once.
static func _t_return_home_refused() -> Dictionary:
	var env := _explore_env("return_twice", 2, 4)
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]
	var save := rt.get_save_data()
	for ty in ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a"]:
		InventoryService.intake(save, env["inv_cfg"], InventoryServiceTests._e(ty), "direct")
	if not _force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	rt.dispatch({ "type": "stage.return_home" })
	var settle_count := int(_stage_of(env).get("settle_count", -1))
	if settle_count != 1:
		m.append("the first leave settled %d times, expected 1" % settle_count)
	var after_first := JSON.stringify(save, "", true)
	var type_first := str(rt.flow_ctx.last_snapshot.get("type", ""))
	# (a) Again, from the scout-return card.
	logger.clear()
	rt.dispatch({ "type": "stage.return_home" })
	if JSON.stringify(save, "", true) != after_first or _flushes(logger) != 0 or int(_stage_of(env).get("settle_count", -1)) != 1:
		m.append("a second return_home changed the save, flushed or settled again")
	if _log_count(logger, "stage.return.denied") != 1 or _log_count(logger, "economy.settle.leave") != 0 \
			or _log_count(logger, "stage.return_home") != 0:
		m.append("denied log %d, settle logs %d, attempt logs %d" % [_log_count(logger, "stage.return.denied"),
			_log_count(logger, "economy.settle.leave"), _log_count(logger, "stage.return_home")])
	if str(rt.flow_ctx.last_snapshot.get("type", "")) != type_first:
		m.append("a refusal replaced the snapshot")
	var outcome := rt._venture_controller().handle_return_home({ "type": "stage.return_home" }, 30)
	if outcome.error_code != "not_on_path" or not outcome.save_reasons.is_empty() or outcome.has_replacement_snapshot:
		m.append("outcome error '%s', reasons %s" % [outcome.error_code, str(outcome.save_reasons)])
	# (b) From the Sanctum.
	rt.dispatch({ "type": "flow.go_state", "to": "flow.sanctum" })
	var in_sanctum := JSON.stringify(save, "", true)
	if str(rt.flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.SANCTUM:
		m.append("test setup failed: not in the Sanctum")
	logger.clear()
	rt.dispatch({ "type": "stage.return_home" })
	if JSON.stringify(save, "", true) != in_sanctum or _log_count(logger, "stage.return.denied") != 1 \
			or _log_count(logger, "economy.settle.leave") != 0:
		m.append("a return_home in the Sanctum was not refused cleanly")
	return _result(m)


## L8: the path-end item report is carried to the snapshot of the complete_stage dispatch, only when an item was
## banked or lost, and is spent after that dispatch. An item-free path end adds no key.
static func _t_path_end_report() -> Dictionary:
	var rows: Array = []
	for with_item in [true, false]:
		var env := _explore_env("path_end_%s" % str(with_item), 2, 2)
		if not bool(env.get("ok", false)):
			return env
		var rt: FlowRuntime = env["runtime"]
		var realm := VentureCharacterizationTests._realm(rt.get_save_data(), "realm.01")
		if int(realm.get("stage_count", 0)) < 2:
			realm["stage_count"] = 2
		realm["current_stage_index"] = 0
		if with_item:
			EarningsService.record_item(_stage_of(env), "s0", "a", ItemPacksTests._entry("ph_armor_a"))
		var out: Dictionary = rt.dispatch({ "type": "flow.complete_stage", "destination": FlowStateIds.SANCTUM })
		rows.append({ "with_item": with_item, "out": out, "env": env })
	var m: Array = []
	var with_row: Dictionary = rows[0]
	var plain: Dictionary = rows[1]
	var data: Dictionary = (with_row["out"] as Dictionary).get("data", {})
	var want := { "kept": [_row_of("ph_armor_a", 1, "gathered", 1, "ok")], "lost": [] }
	if str((with_row["out"] as Dictionary).get("type", "")) != FlowStateIds.SANCTUM or str(data.get("stage_clear_items", {})) != str(want):
		m.append("path end with an item: type %s, stage_clear_items %s, expected %s" % [
			str((with_row["out"] as Dictionary).get("type")), str(data.get("stage_clear_items")), str(want)])
	if not ((with_row["env"] as Dictionary)["runtime"] as FlowRuntime).flow_ctx.pending_stage_clear_items.is_empty():
		m.append("the field was not spent")
	var plain_data: Dictionary = (plain["out"] as Dictionary).get("data", {})
	if str((plain["out"] as Dictionary).get("type", "")) != FlowStateIds.SANCTUM or plain_data.has("stage_clear_items"):
		m.append("an item-free path end: type %s, has the key %s" % [str((plain["out"] as Dictionary).get("type")), str(plain_data.has("stage_clear_items"))])
	# The next Sanctum build has no key (one-shot).
	var rt2: FlowRuntime = (with_row["env"] as Dictionary)["runtime"]
	rt2.flow_machine.reenter(rt2.flow_ctx, (with_row["env"] as Dictionary)["logger"], 40)
	if (rt2.flow_ctx.last_snapshot.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("the key stayed after the dispatch that set it")
	return _result(m)


## M3 + M4: `data.inventory.discard_blocked` is "path_open" only when the controller would refuse for the live path,
## and the controller uses the same function. Cases: no live stage; open row; held piece on an unsettled path;
## the same path after the party left it (escaped), after the path end (receipt), with nothing held.
static func _t_discard_blocked() -> Dictionary:
	var m: Array = []
	var base_keys := str(["items", "pack", "pack_capacity", "pack_count", "pack_free", "pack_load", "sanctum_room",
		"stacks", "unique_cap", "unique_count", "warn"])
	var with_key := str(["discard_blocked", "items", "pack", "pack_capacity", "pack_count", "pack_free", "pack_load",
		"sanctum_room", "stacks", "unique_cap", "unique_count", "warn"])
	# (a) No live stage: no key, the discard of a held piece works.
	var a := _env("blocked_a", 2, 2)
	_seed(a, ["ph_weapon_a", "ph_charm_a", "ph_relic_a"])
	(a["rt"] as FlowRuntime).flow_machine.reenter((a["rt"] as FlowRuntime).flow_ctx, a["logger"], 3)
	if _sorted_keys(_inv_snap(a)) != base_keys:
		m.append("(a) keys %s" % _sorted_keys(_inv_snap(a)))
	_dispatch(a, _discard("it.3"))
	if not _ids(a, "pack").is_empty():
		m.append("(a) no live stage: the held piece was not discarded")
	_done(a)
	# (b) Back-route: a live unsettled path, a held piece, no open row.
	var b := _env("blocked_b", 2, 2)
	_seed(b, ["ph_weapon_a", "ph_charm_a", "ph_relic_a"])
	_live_path(b)
	var rt: FlowRuntime = b["rt"]
	rt.flow_machine.reenter(rt.flow_ctx, b["logger"], 3)
	var snap := _inv_snap(b)
	if _sorted_keys(snap) != with_key or str(snap.get("discard_blocked", "")) != "path_open" \
			or ActiveStageService.discard_block_reason(rt.flow_ctx) != "path_open":
		m.append("(b) keys %s, discard_blocked '%s'" % [_sorted_keys(snap), str(snap.get("discard_blocked"))])
	_dispatch(b, { "type": "debug.seed.show" })  # flushes the layout save the re-entry queued
	var before := JSON.stringify(_save(b), "", true)
	for id in ["it.3", "it.1"]:
		var flushes := _dispatch(b, _discard(id))
		var key := _refusal_key(b, _discard(id))
		if flushes != 0 or JSON.stringify(_save(b), "", true) != before or key != "path_open":
			m.append("(b) a discard of %s: flushes %d, save changed %s, reason '%s'" % [id, flushes,
				str(JSON.stringify(_save(b), "", true) != before), key])
	# (c) The party left the path (escaped): the draw already happened, so the discard is allowed.
	var stage: Dictionary = (((_save(b)["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array)[0]
	(stage["explore_map"] as Dictionary)["party_state"] = "escaped"
	rt.flow_machine.reenter(rt.flow_ctx, b["logger"], 4)
	if (_inv_snap(b)).has("discard_blocked") or ActiveStageService.discard_block_reason(rt.flow_ctx) != "":
		m.append("(c) an escaped path still blocks")
	(stage["explore_map"] as Dictionary)["party_state"] = ""
	# (d) The path end stamped the receipt: allowed.
	stage["settlement_receipt"] = { "settled": true }
	rt.flow_machine.reenter(rt.flow_ctx, b["logger"], 5)
	if (_inv_snap(b)).has("discard_blocked") or ActiveStageService.discard_block_reason(rt.flow_ctx) != "":
		m.append("(d) a settled path still blocks")
	stage["settlement_receipt"] = {}
	# (e) An open row blocks with no held piece (D-27); the room counts the row.
	_dispatch(b, _discard("it.99"))
	EarningsService.record_item(stage, "s0", "a", ItemPacksTests._entry("ph_armor_a"))
	rt.flow_machine.reenter(rt.flow_ctx, b["logger"], 6)
	if str(_inv_snap(b).get("discard_blocked", "")) != "path_open" or int((_inv_snap(b)["pack_load"] as Dictionary)["carried"]) != 2:
		m.append("(e) open row: %s" % str(_inv_snap(b)))
	_done(b)
	# (f) A live path with nothing held and no row: nothing to dodge, allowed.
	var f := _env("blocked_f", 2, 2)
	_seed(f, ["ph_weapon_a", "ph_charm_a"])
	_live_path(f)
	(f["rt"] as FlowRuntime).flow_machine.reenter((f["rt"] as FlowRuntime).flow_ctx, f["logger"], 3)
	if (_inv_snap(f)).has("discard_blocked") or _refusal_key(f, _discard("it.99")) != "not_found":
		m.append("(f) a live path with an empty pack blocks")
	_done(f)
	return _result(m)


## A realm record as the save holds it, with stage 0 as the current stage.
static func _saved_realm(locked: bool, party_state: String, settled: bool) -> Dictionary:
	return { "run_count": 0, "seed": 1, "status": "active", "current_stage_index": 0, "stage_count": 2, "stages": [
		{ "index": 0, "objectives": [], "earnings": [], "settlement_receipt": { "settled": settled },
			"explore_map": { "situations": [], "locked": locked, "party_state": party_state } }] }


## Writes the save of `env`, then boots a NEW runtime from the file, the way Continue does, and puts it in the
## Sanctum. `boot()` restores the active realm but not `stage_id`.
static func _reload(env: Dictionary) -> Dictionary:
	var rt: FlowRuntime = env["rt"]
	rt.flow_ctx.request_save("test.reload")
	rt.dispatch({ "type": "debug.seed.show" })
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	var rt2 := FlowRuntime.new(logger, env["cfg"], str(env["path"]))
	rt2.boot()
	rt2.flow_machine.transition(FlowStateIds.SANCTUM, rt2.flow_ctx, logger, 1, "test")
	rt2.dispatch({ "type": "debug.seed.show" })
	return { "rt": rt2, "logger": logger, "cfg": env["cfg"], "inv_cfg": env["inv_cfg"], "path": env["path"] }


## The discard guard reads saved state, so a quit and Continue does not open it (`flow_ctx.stage_id` is empty after
## `boot()`). Each case: a save with one held piece (it.3), the runtime rebuilt from the file by `_reload`.
## Blocked: an entered, unsettled path; an open item row with nothing held. Allowed: a stage never entered (the
## player selected it and went back), an escaped party, a settled path. The last case is the same never-entered
## stage in a live session, where `stage_id` is set.
static func _t_discard_reload() -> Dictionary:
	var m: Array = []
	var cases := [
		{ "name": "entered", "realm": _saved_realm(true, "exploring", false), "row": false, "held": true, "want": "path_open" },
		{ "name": "open_row_only", "realm": _saved_realm(false, "exploring", false), "row": true, "held": false, "want": "path_open" },
		{ "name": "never_entered", "realm": _saved_realm(false, "exploring", false), "row": false, "held": true, "want": "" },
		{ "name": "escaped", "realm": _saved_realm(true, "escaped", false), "row": false, "held": true, "want": "" },
		{ "name": "settled", "realm": _saved_realm(true, "exploring", true), "row": false, "held": true, "want": "" },
	]
	for c_v in cases:
		var c: Dictionary = c_v
		var name := str(c["name"])
		var env := _env("reload_" + name, 2, 2)
		_seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a"] if bool(c["held"]) else ["ph_weapon_a", "ph_charm_a"])
		var realm: Dictionary = (c["realm"] as Dictionary).duplicate(true)
		(_save(env)["realms"] as Dictionary)["realm.01"] = realm
		if bool(c["row"]):
			EarningsService.record_item((realm["stages"] as Array)[0], "s0", "a", ItemPacksTests._entry("ph_armor_a"))
		var re := _reload(env)
		var rt2: FlowRuntime = re["rt"]
		if rt2.flow_ctx.realm_id != "realm.01" or not rt2.flow_ctx.stage_id.is_empty():
			m.append("%s: setup: realm_id '%s', stage_id '%s' after boot" % [name, rt2.flow_ctx.realm_id, rt2.flow_ctx.stage_id])
		var reason := ActiveStageService.discard_block_reason(rt2.flow_ctx)
		var shown := str(_inv_snap(re).get("discard_blocked", ""))
		if reason != str(c["want"]) or shown != str(c["want"]):
			m.append("%s: reason '%s', snapshot '%s', expected '%s'" % [name, reason, shown, str(c["want"])])
		var target := "it.3" if bool(c["held"]) else "it.1"
		var before := JSON.stringify(_save(re), "", true)
		var flushes := _dispatch(re, _discard(target))
		var changed := JSON.stringify(_save(re), "", true) != before
		if str(c["want"]) == "path_open" and (flushes != 0 or changed or _refusal_key(re, _discard(target)) != "path_open"):
			m.append("%s: the discard was not refused (flushes %d, changed %s)" % [name, flushes, str(changed)])
		if str(c["want"]) == "" and not changed:
			m.append("%s: the discard was refused" % name)
		_done(re)
		_done(env)
	# The same never-entered stage in a live session: stage_id is set, the stage is not entered.
	var live := _env("reload_live", 2, 2)
	_seed(live, ["ph_weapon_a", "ph_charm_a", "ph_relic_a"])
	_live_path(live)
	var stage: Dictionary = (((_save(live)["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array)[0]
	(stage["explore_map"] as Dictionary)["locked"] = false
	if ActiveStageService.discard_block_reason((live["rt"] as FlowRuntime).flow_ctx) != "":
		m.append("live session: a stage that was selected and never entered blocks the discard")
	_done(live)
	return _result(m)


## Runs complete_stage on a one-item path with `destination` ("" = the default) and returns { out, rt, logger }.
static func _path_end_env(tag: String, destination: String) -> Dictionary:
	var env := _explore_env(tag, 2, 2)
	if not bool(env.get("ok", false)):
		return env
	var rt: FlowRuntime = env["runtime"]
	var realm := VentureCharacterizationTests._realm(rt.get_save_data(), "realm.01")
	if int(realm.get("stage_count", 0)) < 2:
		realm["stage_count"] = 2
	realm["current_stage_index"] = 0
	EarningsService.record_item(_stage_of(env), "s0", "a", ItemPacksTests._entry("ph_armor_a"))
	var action := { "type": "flow.complete_stage" }
	if not destination.is_empty():
		action["destination"] = destination
	env["out"] = rt.dispatch(action)
	env["ok"] = true
	return env


## `stage_clear_items` is spent by the dispatch that publishes it: a later dispatch that does not rebuild the
## snapshot (a refused discard) returns a snapshot without the key, and so does `last_snapshot`.
static func _t_clear_items_spent() -> Dictionary:
	var env := _path_end_env("clear_spent", FlowStateIds.SANCTUM)
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["runtime"]
	var first: Dictionary = env["out"]
	if not (first.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("the dispatch that ended the path did not return the report")
	if (rt.flow_ctx.last_snapshot.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("last_snapshot kept the report after it was published")
	var later: Dictionary = rt.dispatch(_discard("it.99"))
	if str(later.get("type", "")) != FlowStateIds.SANCTUM or (later.get("data", {}) as Dictionary).has("stage_clear_items") \
			or (rt.flow_ctx.last_snapshot.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("a later dispatch that does not rebuild the snapshot sent the report again")
	return _result(m)


## Pinned behaviour: when the path ends to `flow.stage_map` (the default destination), the report is not shown
## and not kept. The dispatch clears `pending_stage_clear_items`, the stage map snapshot has no
## `stage_clear_items` key, and a Sanctum shown later has none either. The settled rows stay in the save.
## Where this report shows for the stage map is a decision for the UI step (decisions.md, D-29).
static func _t_clear_items_stage_map() -> Dictionary:
	var env := _path_end_env("clear_map", "")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["runtime"]
	var out: Dictionary = env["out"]
	if str(out.get("type", "")) != FlowStateIds.STAGE_MAP or (out.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("stage map: type %s, has the key %s" % [str(out.get("type")), str((out.get("data", {}) as Dictionary).has("stage_clear_items"))])
	if not rt.flow_ctx.pending_stage_clear_items.is_empty():
		m.append("the report stayed in the context after the dispatch")
	rt.flow_machine.transition(FlowStateIds.SANCTUM, rt.flow_ctx, env["logger"], 50, "test")
	if (rt.flow_ctx.last_snapshot.get("data", {}) as Dictionary).has("stage_clear_items"):
		m.append("a later Sanctum showed the dropped report")
	var settled := 0
	for r_v in EarningsService.rows_of(_stage_of(env)):
		if EarningsService.is_item_row(r_v) and bool((r_v as Dictionary).get("settled", false)):
			settled += 1
	if settled != 1:
		m.append("expected the item row settled in the save, found %d" % settled)
	return _result(m)


## D-29: `flow.echo_party` `data.inventory` is present for an item-free save, with the Sanctum projection's shape
## and the test config's numbers, and it is a copy.
static func _t_party_prep_item_free() -> Dictionary:
	var m: Array = []
	var env := _env("party_free", 4, 3)
	var rt: FlowRuntime = env["rt"]
	var inv_before := JSON.stringify(_save(env)["inventory"], "", true)
	var data: Dictionary = FlowEchoPartyState.build_snapshot(rt.flow_ctx, 4)["data"]
	var inv_v: Variant = data.get("inventory", null)
	if not (inv_v is Dictionary):
		_done(env)
		return { "ok": false, "error": "flow.echo_party data has no inventory for an item-free save" }
	var inv: Dictionary = inv_v
	var want_keys := str(["items", "pack", "pack_capacity", "pack_count", "pack_free", "pack_load", "sanctum_room",
		"stacks", "unique_cap", "unique_count", "warn"])
	if _sorted_keys(inv) != want_keys:
		m.append("keys %s" % _sorted_keys(inv))
	if int(inv["unique_cap"]) != 4 or int(inv["pack_capacity"]) != 3 or int(inv["pack_free"]) != 3 \
			or int(inv["pack_count"]) != 0 or int(inv["sanctum_room"]) != 4 or not (inv["items"] as Array).is_empty() \
			or not (inv["pack"] as Array).is_empty() or int((inv["pack_load"] as Dictionary)["level"]) != 0:
		m.append("values %s" % str(inv))
	if _norm(inv) != _norm(InventoryService.snapshot(_save(env), env["inv_cfg"], 0)):
		m.append("not the Sanctum projection")
	# A copy: writing into it changes neither the save nor a second build.
	inv["pack_free"] = 99
	(inv["pack_load"] as Dictionary)["level"] = 3
	(inv["items"] as Array).append({ "id": "x" })
	var again: Dictionary = (FlowEchoPartyState.build_snapshot(rt.flow_ctx, 5)["data"] as Dictionary)["inventory"]
	if int(again["pack_free"]) != 3 or int((again["pack_load"] as Dictionary)["level"]) != 0 or not (again["items"] as Array).is_empty() \
			or JSON.stringify(_save(env)["inventory"], "", true) != inv_before:
		m.append("the projection reaches the save or a later build")
	_done(env)
	return _result(m)


## M2 + B4: the Sanctum `reserved` and the party prep projection count the open item rows of every Realm. The
## `flow.echo_party` data gains `inventory` (the same projection) and no other key.
static func _t_reserved_and_party_prep() -> Dictionary:
	var m: Array = []
	var env := _env("reserved", 4, 3)
	var rt: FlowRuntime = env["rt"]
	var other := { "run_count": 0, "seed": 1, "stages": [{ "index": 0, "earnings": [] }] }
	(_save(env)["realms"] as Dictionary)["realm.02"] = other
	var plain := _inv_snap(env)
	var plain_pack_load := str(plain["pack_load"])
	EarningsService.record_item((other["stages"] as Array)[0], "r2", "open", ItemPacksTests._entry("ph_weapon_a"))
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 3)
	var snap := _inv_snap(env)
	if int((snap["pack_load"] as Dictionary)["carried"]) != 1 or int(snap["pack_free"]) != 2 or int(snap["pack_count"]) != 0 \
			or plain_pack_load == str(snap["pack_load"]):
		m.append("sanctum: pack_load %s, pack_free %s" % [str(snap["pack_load"]), str(snap["pack_free"])])
	if str(snap.get("discard_blocked", "")) != "path_open":
		m.append("an open row in another realm must block the discard, got '%s'" % str(snap.get("discard_blocked")))
	# Party prep.
	var party: Dictionary = FlowEchoPartyState.build_snapshot(rt.flow_ctx, 4)
	var data: Dictionary = party["data"]
	var keys: Array = data.keys()
	keys.sort()
	if str(keys) != str(["active_party_ids", "echo_count", "echoes", "inventory", "max_party_size", "party_count", "thread_count", "title"]):
		m.append("echo_party data keys %s" % str(keys))
	var want := InventoryService.snapshot(_save(env), env["inv_cfg"], 1)
	if _norm(data.get("inventory", null)) != _norm(want):
		m.append("echo_party inventory %s, expected %s" % [str(data.get("inventory")), str(want)])
	var bad: Array = []
	_forbidden_keys(data.get("inventory", {}), "inventory", bad)
	if not bad.is_empty():
		m.append("forbidden keys %s" % str(bad))
	# The projection is a copy.
	((data["inventory"] as Dictionary)["pack_load"] as Dictionary)["free"] = 99
	if int(InventoryService.snapshot(_save(env), env["inv_cfg"], 1)["pack_load"]["free"]) == 99:
		m.append("the party prep projection reaches the save")
	_done(env)
	return _result(m)


## L5: the F1 console command refuses outside a debug build. The check comes before the dispatch. (The core
## action is unchanged and not gated.)
static func _t_console_gate() -> Dictionary:
	var src := FileAccess.get_file_as_string("res://ui/AppRoot.gd")
	var start := src.find("func _run_inventory_command(")
	if start < 0:
		return { "ok": false, "error": "_run_inventory_command not found" }
	var end := src.find("\nfunc ", start + 10)
	var body := src.substr(start, end - start if end > 0 else src.length() - start)
	var gate := body.find("OS.is_debug_build()")
	var dispatch := body.find("runtime.dispatch")
	var m: Array = []
	if gate < 0 or dispatch < 0 or gate > dispatch:
		m.append("the OS.is_debug_build() check must come before runtime.dispatch (gate %d, dispatch %d)" % [gate, dispatch])
	var core := FileAccess.get_file_as_string("res://core/runtime/controllers/DebugController.gd")
	if core.contains("is_debug_build"):
		m.append("the core action must stay as it is (no build gate in core/)")
	return _result(m)
