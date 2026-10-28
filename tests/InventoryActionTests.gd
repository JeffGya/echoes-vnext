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
		{ "index": 0, "objectives": [], "earnings": [], "settlement_receipt": {}, "explore_map": { "situations": [] } }] }
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
