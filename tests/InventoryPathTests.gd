# res://tests/InventoryPathTests.gd
# The action path of the moves and the discard rules: inventory.move.apply and inventory.discard.apply through
# FlowRuntime.dispatch, where each is allowed (Sanctum, party prep, the path view), the one discard per path and
# its saved mark. The container work itself is in InventoryMoveTests.

class_name InventoryPathTests
extends RefCounted

const _MOVE := "inventory.move.apply"
const _DISCARD := "inventory.discard.apply"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_paths/move_in_the_sanctum", Callable(InventoryPathTests, "_t_move_sanctum"))
	runner.register_test("inventory_paths/move_refusals_change_nothing", Callable(InventoryPathTests, "_t_move_refusals"))
	runner.register_test("inventory_paths/move_in_party_prep_keeps_the_screen", Callable(InventoryPathTests, "_t_move_party_prep"))
	runner.register_test("inventory_paths/no_move_on_a_path_or_away_from_the_sanctum", Callable(InventoryPathTests, "_t_move_closed"))
	runner.register_test("inventory_paths/sanctum_discard_is_unlimited_and_takes_a_count", Callable(InventoryPathTests, "_t_discard_sanctum"))
	runner.register_test("inventory_paths/one_discard_per_path_on_a_pack_entry", Callable(InventoryPathTests, "_t_one_discard"))
	runner.register_test("inventory_paths/a_stack_discard_is_the_one_discard", Callable(InventoryPathTests, "_t_stack_is_the_one"))
	runner.register_test("inventory_paths/the_used_mark_survives_save_and_continue", Callable(InventoryPathTests, "_t_used_survives"))
	runner.register_test("inventory_paths/the_used_mark_is_saved_with_the_stage", Callable(InventoryPathTests, "_t_used_in_json"))
	runner.register_test("inventory_paths/a_new_path_resets_the_used_mark", Callable(InventoryPathTests, "_t_reset"))
	runner.register_test("inventory_paths/path_view_snapshot_carries_the_inventory", Callable(InventoryPathTests, "_t_path_snapshot"))
	runner.register_test("inventory_paths/a_carried_stack_is_drawn_lost_and_banked_like_a_carried_piece", Callable(InventoryPathTests, "_t_held_stack_settle"))
	runner.register_test("inventory_paths/a_carried_stack_is_drawn_on_a_some_leave", Callable(InventoryPathTests, "_t_held_stack_some"))
	runner.register_test("inventory_paths/dispatches_are_deterministic", Callable(InventoryPathTests, "_t_determinism"))
	runner.register_test("inventory_paths/new_save_and_config_hold_no_placeholder", Callable(InventoryPathTests, "_t_no_placeholder"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return InventoryServiceTests._result(m)


static func _mv(from_box: String, slot: int, to_box: String, to_slot: Variant = null) -> Dictionary:
	var p := { "from": from_box, "slot": slot, "to": to_box }
	if to_slot != null:
		p["to_slot"] = to_slot
	return { "type": _MOVE, "payload": p }


static func _drop(from_box: String, slot: int, count: Variant = null) -> Dictionary:
	var p := { "from": from_box, "slot": slot }
	if count != null:
		p["count"] = count
	return { "type": _DISCARD, "payload": p }


static func _controller(rt: FlowRuntime, env: Dictionary) -> InventoryController:
	return InventoryController.new(rt.flow_ctx, rt.config_service, env["logger"])


## The reason the controller gives for an action it refuses. Run it only for an action that is refused: a
## successful action would run twice.
static func _move_key(env: Dictionary, action: Dictionary) -> String:
	return _controller(env["rt"], env).handle_move(action, 9).error_code


static func _drop_key(env: Dictionary, action: Dictionary) -> String:
	return _controller(env["rt"], env).handle_discard(action, 9).error_code


static func _json_of(env: Dictionary) -> String:
	return JSON.stringify(InventoryActionTests._save(env), "", true)


## Dispatches a refused action and checks that nothing changed: the save, the snapshot, the flush count, one denied
## log. Returns the problem text or "".
static func _refused(env: Dictionary, action: Dictionary, key: String, what: String, log_type: String) -> String:
	var save_before := _json_of(env)
	var snap_before := JSON.stringify(InventoryActionTests._snap(env), "", true)
	var flushes := InventoryActionTests._dispatch(env, action)
	var got := _move_key(env, action) if str(action["type"]) == _MOVE else _drop_key(env, action)
	if flushes != 0 or _json_of(env) != save_before or JSON.stringify(InventoryActionTests._snap(env), "", true) != snap_before:
		return "%s: flushes %d or the save or the snapshot changed" % [what, flushes]
	if InventoryActionTests._log_count(env["logger"], log_type) < 1:
		return "%s: no %s log" % [what, log_type]
	if got != key:
		return "%s: reason '%s', expected '%s'" % [what, got, key]
	return ""


## Sanctum env with weapon (0), charm (1), a consumable stack of 3 (2) and a relic (3).
static func _stocked(tag: String, pack: int = 2) -> Dictionary:
	var env := InventoryActionTests._env(tag, 4, pack)
	var save := InventoryActionTests._save(env)
	var cfg: Dictionary = env["inv_cfg"]
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_charm_a"), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_consumable_a", 3), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_relic_a"), "direct")
	(env["rt"] as FlowRuntime).flow_machine.reenter((env["rt"] as FlowRuntime).flow_ctx, env["logger"], 3)
	return env


# ---------------------------------------------------------------------------
# Moves
# ---------------------------------------------------------------------------

static func _t_move_sanctum() -> Dictionary:
	var m: Array = []
	var env := _stocked("mv_sanctum", 3)
	var rt: FlowRuntime = env["rt"]
	var census := InventoryMoveTests._census(InventoryActionTests._save(env))
	# Piece to the pack: first free slot, one flush, the Sanctum snapshot rebuilt.
	var flushes := InventoryActionTests._dispatch(env, _mv("sanctum", 1, "pack"))
	var inv := InventoryActionTests._inv_snap(env)
	if flushes != 1 or str(InventoryActionTests._snap(env).get("type")) != FlowStateIds.SANCTUM:
		m.append("move: %d flushes, snapshot %s" % [flushes, str(InventoryActionTests._snap(env).get("type"))])
	if InventoryMoveTests._slots(inv, "pack") != [0] or InventoryMoveTests._slots(inv, "items") != [0, 3] \
			or int(inv["pack_count"]) != 1:
		m.append("rows after the move: %s" % JSON.stringify(inv))
	# Stack to a chosen pack slot; reorder inside the pack; merge is covered by the service suite.
	InventoryActionTests._dispatch(env, _mv("sanctum", 2, "pack", 1))
	InventoryActionTests._dispatch(env, _mv("pack", 1, "pack", 2))
	inv = InventoryActionTests._inv_snap(env)
	if InventoryMoveTests._slots(inv, "pack_stacks") != [2] or InventoryMoveTests._slots(inv, "pack") != [0]:
		m.append("pack after the stack move: stacks %s pieces %s" % [str(InventoryMoveTests._slots(inv, "pack_stacks")), str(InventoryMoveTests._slots(inv, "pack"))])
	# Back to the Sanctum, anywhere free.
	InventoryActionTests._dispatch(env, _mv("pack", 0, "sanctum", 2))
	inv = InventoryActionTests._inv_snap(env)
	if InventoryMoveTests._slots(inv, "items") != [0, 3, 2] or int(inv["pack_count"]) != 1:
		m.append("after the way back: %s" % JSON.stringify(inv))
	if InventoryMoveTests._census(InventoryActionTests._save(env)) != census:
		m.append("the dispatches changed the census")
	# The outcome: one save reason, a reenter, no error. The pack stack goes back.
	var out := _controller(rt, env).handle_move(_mv("pack", 2, "sanctum"), 9)
	if str(out.save_reasons) != str(["inventory.move"]) or not out.requires_reenter or out.error_code != "":
		m.append("outcome: %s / %s / '%s'" % [str(out.save_reasons), str(out.requires_reenter), out.error_code])
	# Nothing here is a snapshot action slot.
	for slot in (InventoryActionTests._snap(env)["actions"] as Dictionary):
		if str(slot).contains("inventory") or str(slot).contains("move"):
			m.append("actions holds a slot %s" % str(slot))
	InventoryActionTests._done(env)
	return _result(m)


static func _t_move_refusals() -> Dictionary:
	var m: Array = []
	var env := _stocked("mv_refuse", 1)
	InventoryActionTests._dispatch(env, _mv("sanctum", 0, "pack"))  # the pack (1 slot) is now full
	var cases: Array = [
		["no payload", { "type": _MOVE }, "bad_payload"],
		["from not a String", { "type": _MOVE, "payload": { "from": 5, "slot": 0, "to": "pack" } }, "bad_payload"],
		["slot missing", { "type": _MOVE, "payload": { "from": "sanctum", "to": "pack" } }, "bad_payload"],
		["slot negative", _mv("sanctum", -1, "pack"), "bad_payload"],
		["slot a fraction", { "type": _MOVE, "payload": { "from": "sanctum", "slot": 0.5, "to": "pack" } }, "bad_payload"],
		["to_slot a String", _mv("sanctum", 1, "pack", "x"), "bad_payload"],
		["unknown box", _mv("sanctum", 1, "moon"), "bad_box"],
		["empty source slot", _mv("sanctum", 9, "pack"), "unknown_entry"],
		["pack full", _mv("sanctum", 1, "pack"), "container_full"],
		["taken target slot", _mv("sanctum", 1, "sanctum", 3), "slot_taken"],
		["target out of range", _mv("sanctum", 1, "sanctum", 4), "bad_slot"],
		["same slot", _mv("sanctum", 1, "sanctum", 1), "no_change"],
		["stack on a piece", _mv("sanctum", 2, "sanctum", 1), "slot_taken"],
	]
	for c in cases:
		var problem := _refused(env, c[1], str(c[2]), str(c[0]), "inventory.move.denied")
		if problem != "":
			m.append(problem)
	InventoryActionTests._done(env)
	return _result(m)


static func _t_move_party_prep() -> Dictionary:
	var m: Array = []
	var env := _stocked("mv_prep")
	var rt: FlowRuntime = env["rt"]
	rt.flow_machine.transition(FlowStateIds.ECHO_PARTY, rt.flow_ctx, env["logger"], 4, "test")
	if str(InventoryActionTests._snap(env).get("type")) != FlowStateIds.ECHO_PARTY:
		InventoryActionTests._done(env)
		return { "ok": false, "error": "test setup: the runtime is not in party prep" }
	InventoryActionTests._dispatch(env, _mv("sanctum", 0, "pack"))
	var snap := InventoryActionTests._snap(env)
	var inv: Dictionary = (snap["data"] as Dictionary).get("inventory", {})
	if str(snap.get("type")) != FlowStateIds.ECHO_PARTY or InventoryMoveTests._slots(inv, "pack") != [0] \
			or int(inv.get("pack_count", -1)) != 1:
		m.append("party prep after the move: %s / %s" % [str(snap.get("type")), JSON.stringify(inv)])
	var out := _controller(rt, env).handle_move(_mv("pack", 0, "sanctum"), 9)
	if out.requires_reenter or not out.has_replacement_snapshot or str(out.save_reasons) != str(["inventory.move"]):
		m.append("party prep outcome: reenter %s, snapshot %s, reasons %s" % [str(out.requires_reenter),
			str(out.has_replacement_snapshot), str(out.save_reasons)])
	# A discard from party prep works the same way.
	InventoryActionTests._dispatch(env, _drop("sanctum", 1))
	if InventoryService.entry_at(InventoryActionTests._save(env), "sanctum", 1) != {}:
		m.append("the discard in party prep did not remove the piece")
	InventoryActionTests._done(env)
	return _result(m)


static func _t_move_closed() -> Dictionary:
	var m: Array = []
	# Away from the Sanctum.
	var env := _stocked("mv_closed")
	var rt: FlowRuntime = env["rt"]
	rt.flow_machine.transition(FlowStateIds.STAGE_MAP, rt.flow_ctx, env["logger"], 2, "test")
	InventoryActionTests._dispatch(env, { "type": "debug.seed.show" })  # flushes the save the transition queued
	var p := _refused(env, _mv("sanctum", 0, "pack"), "not_in_sanctum", "stage map", "inventory.move.denied")
	if p != "":
		m.append(p)
	InventoryActionTests._done(env)
	# The Sanctum screen while a path is live (the encounter Back route, or after Continue): D-40, moves work.
	var live := _stocked("mv_live")
	InventoryActionTests._live_path(live)
	(live["rt"] as FlowRuntime).flow_machine.reenter((live["rt"] as FlowRuntime).flow_ctx, live["logger"], 3)
	InventoryActionTests._dispatch(live, _mv("sanctum", 0, "pack"))
	if InventoryService.pack_count(InventoryActionTests._save(live)) != 1:
		m.append("a move on a Sanctum screen with a live path was refused")
	InventoryActionTests._dispatch(live, _mv("pack", 0, "sanctum"))
	if InventoryService.pack_count(InventoryActionTests._save(live)) != 0:
		m.append("the pack could not be emptied on a Sanctum screen with a live path")
	InventoryActionTests._done(live)
	# The path view.
	var ex := InventoryActionTests._explore_env("mv_explore", 4, 2)
	if not bool(ex.get("ok", false)):
		return ex
	var rt2: FlowRuntime = ex["rt"]
	InventoryService.intake(rt2.get_save_data(), ex["inv_cfg"], InventoryServiceTests._e("ph_weapon_a"), "direct")
	if str(rt2.flow_ctx.last_snapshot.get("type")) != FlowStateIds.STAGE_EXPLORE:
		return { "ok": false, "error": "test setup: not in the path view" }
	var before := JSON.stringify(rt2.get_save_data(), "", true)
	rt2.dispatch(_mv("sanctum", 0, "pack"))
	var key := _controller(rt2, ex).handle_move(_mv("sanctum", 0, "pack"), 9).error_code
	if key != "path_open" or JSON.stringify(rt2.get_save_data(), "", true) != before:
		m.append("path view: reason '%s' or the save changed" % key)
	return _result(m)


# ---------------------------------------------------------------------------
# Discards
# ---------------------------------------------------------------------------

static func _t_discard_sanctum() -> Dictionary:
	var m: Array = []
	var env := _stocked("dc_sanctum")
	var save := InventoryActionTests._save(env)
	# A stack: a partial count keeps the slot, then the whole rest.
	InventoryActionTests._dispatch(env, _drop("sanctum", 2, 1))
	var inv := InventoryActionTests._inv_snap(env)
	if int(inv["stacks"][0]["count"]) != 2 or int(inv["stacks"][0]["slot"]) != 2:
		m.append("partial count: %s" % JSON.stringify(inv["stacks"]))
	InventoryActionTests._dispatch(env, _drop("sanctum", 2, 2))
	if not (save["inventory"]["stacks"] as Array).is_empty():
		m.append("the whole rest did not remove the stack")
	# The count is checked: refusals change nothing.
	InventoryActionTests._dispatch(env, { "type": "debug.seed.show" })
	var p := _refused(env, _drop("sanctum", 0, 2), "count_range", "piece with a count of 2", "inventory.discard.denied")
	if p != "":
		m.append(p)
	p = _refused(env, _drop("sanctum", 0, "x"), "bad_payload", "count a String", "inventory.discard.denied")
	if p != "":
		m.append(p)
	p = _refused(env, _drop("sanctum", 9), "unknown_entry", "empty slot", "inventory.discard.denied")
	if p != "":
		m.append(p)
	# Unlimited, either container: three discards in a row, a pack piece among them.
	InventoryActionTests._dispatch(env, _mv("sanctum", 3, "pack"))
	var n_before := InventoryService.sanctum_used(save) + InventoryService.pack_count(save)
	InventoryActionTests._dispatch(env, _drop("pack", 0))
	InventoryActionTests._dispatch(env, _drop("sanctum", 0))
	InventoryActionTests._dispatch(env, _drop("sanctum", 1))
	var n_after := InventoryService.sanctum_used(save) + InventoryService.pack_count(save)
	if n_before != 3 or n_after != 0:
		m.append("unlimited discards: %d entries before, %d after" % [n_before, n_after])
	# The piece id address still works.
	InventoryService.intake(save, env["inv_cfg"], InventoryServiceTests._e("ph_armor_a"), "direct")
	InventoryActionTests._dispatch(env, InventoryActionTests._discard("it.4"))
	if InventoryService.sanctum_used(save) != 0:
		m.append("discard by item_id did not remove the piece")
	InventoryActionTests._done(env)
	return _result(m)


## Explore env (the path view): Sanctum weapon (0) and charm (1); pack: relic (0), a consumable stack of 3 (1).
static func _path_env(tag: String) -> Dictionary:
	var env := InventoryActionTests._explore_env(tag, 4, 3)
	if not bool(env.get("ok", false)):
		return env
	var rt: FlowRuntime = env["rt"]
	var save := rt.get_save_data()
	var cfg: Dictionary = env["inv_cfg"]
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		InventoryService.intake(save, cfg, InventoryServiceTests._e(t), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_consumable_a", 3), "direct")
	InventoryService.move_entry(save, cfg, "sanctum", 2, "pack")
	InventoryService.move_entry(save, cfg, "sanctum", 3, "pack")
	return env


static func _t_one_discard() -> Dictionary:
	var env := _path_env("one_discard")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc := rt.flow_ctx
	if InventoryRules.mode(fc) != InventoryRules.MODE_PATH:
		return { "ok": false, "error": "test setup: the screen is not the path view" }
	var inv_before: Dictionary = (fc.last_snapshot["data"] as Dictionary)["inventory"]
	var want_path := { "move_reason": "path_open", "discard_used": false, "discard_pack_reason": "", "discard_sanctum_reason": "not_in_pack" }
	if str(inv_before.get("path")) != str(want_path):
		m.append("path state before: %s" % str(inv_before.get("path")))
	# A Sanctum entry is refused on a path, used or not.
	var before := JSON.stringify(rt.get_save_data(), "", true)
	rt.dispatch(_drop("sanctum", 0))
	if JSON.stringify(rt.get_save_data(), "", true) != before or _drop_key(env, _drop("sanctum", 0)) != "not_in_pack":
		m.append("a Sanctum piece on a path: reason '%s'" % _drop_key(env, _drop("sanctum", 0)))
	# A pack piece takes the one discard.
	var flushes := InventoryActionTests._dispatch(env, _drop("pack", 0))
	var stage := InventoryActionTests._stage_of(env)
	var pack_ids := InventoryServiceTests._ids(rt.get_save_data(), "pack")
	if not pack_ids.is_empty() or not bool(stage.get("discard_used", false)) or flushes < 1:
		m.append("the pack discard: pack %s, used %s, flushes %d" % [str(pack_ids), str(stage.get("discard_used")), flushes])
	var snap_inv: Dictionary = (fc.last_snapshot["data"] as Dictionary).get("inventory", {})
	if str(fc.last_snapshot.get("type")) != FlowStateIds.STAGE_EXPLORE or not bool((snap_inv.get("path", {}) as Dictionary).get("discard_used", false)) \
			or str((snap_inv.get("path", {}) as Dictionary).get("discard_pack_reason", "")) != "path_used":
		m.append("the path view snapshot does not show the used discard: %s" % JSON.stringify(snap_inv.get("path")))
	# The second discard of the path is refused, stack or piece, by slot or by id. Nothing changes.
	before = JSON.stringify(rt.get_save_data(), "", true)
	for action in [_drop("pack", 1), _drop("pack", 1, 1)]:
		rt.dispatch(action)
		if JSON.stringify(rt.get_save_data(), "", true) != before or _drop_key(env, action) != "path_used":
			m.append("second discard: reason '%s'" % _drop_key(env, action))
	if _drop_key(env, _drop("sanctum", 0)) != "not_in_pack":
		m.append("a Sanctum piece on a used path: '%s'" % _drop_key(env, _drop("sanctum", 0)))
	return _result(m)


static func _t_stack_is_the_one() -> Dictionary:
	var env := _path_env("stack_one")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	# A partial stack discard (1 of 3) is the one discard of the path.
	InventoryActionTests._dispatch(env, _drop("pack", 1, 1))
	var stack: Dictionary = rt.get_save_data()["inventory"]["pack_stacks"][0]
	if int(stack["quantity"]) != 2 or int(stack["slot"]) != 1 or not bool(InventoryActionTests._stage_of(env).get("discard_used", false)):
		m.append("partial stack discard on a path: %s, used %s" % [str(stack), str(InventoryActionTests._stage_of(env).get("discard_used"))])
	var before := JSON.stringify(rt.get_save_data(), "", true)
	rt.dispatch(_drop("pack", 0))
	if JSON.stringify(rt.get_save_data(), "", true) != before or _drop_key(env, _drop("pack", 0)) != "path_used":
		m.append("the piece after the stack discard: reason '%s'" % _drop_key(env, _drop("pack", 0)))
	# A refused discard does not spend it: a bad count on a fresh path leaves the mark clear.
	var fresh := _path_env("stack_refused")
	if not bool(fresh.get("ok", false)):
		return fresh
	(fresh["rt"] as FlowRuntime).dispatch(_drop("pack", 1, 9))
	if bool(InventoryActionTests._stage_of(fresh).get("discard_used", false)):
		m.append("a refused count spent the discard")
	return _result(m)


static func _t_used_survives() -> Dictionary:
	var m: Array = []
	# The mark is set in the path view, saved, and read back after a quit and Continue.
	var env := InventoryActionTests._env("used_reload", 2, 2)
	InventoryActionTests._seed(env, ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a"])
	(InventoryActionTests._save(env)["realms"] as Dictionary)["realm.01"] = InventoryActionTests._saved_realm(true, "exploring", false)
	var rt: FlowRuntime = env["rt"]
	rt.flow_ctx.realm_id = "realm.01"
	if not InventoryRules.mark_discard_used(rt.flow_ctx):
		return { "ok": false, "error": "test setup: no stage record for the mark" }
	var re := InventoryActionTests._reload(env)
	var rt2: FlowRuntime = re["rt"]
	if not rt2.flow_ctx.stage_id.is_empty() or not InventoryRules.discard_used(rt2.flow_ctx):
		m.append("after Continue: stage_id '%s', used %s" % [rt2.flow_ctx.stage_id, str(InventoryRules.discard_used(rt2.flow_ctx))])
	# On the Sanctum screen the mark changes nothing: pack pieces still go (D-40).
	InventoryActionTests._dispatch(re, InventoryActionTests._discard("it.3"))
	if InventoryService.locate_piece(InventoryActionTests._save(re), "it.3") != {}:
		m.append("the Sanctum screen refused a pack discard because of the mark")
	# In the path view the same saved mark refuses the pack discard.
	rt2.flow_ctx.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE }
	if InventoryRules.discard_block_reason(rt2.flow_ctx, "pack") != "path_used":
		m.append("path view after Continue: '%s'" % InventoryRules.discard_block_reason(rt2.flow_ctx, "pack"))
	InventoryActionTests._done(re)
	InventoryActionTests._done(env)
	return _result(m)


## The mark is a plain bool on the stage record, so a JSON round trip of the save keeps it.
static func _t_used_in_json() -> Dictionary:
	var env := _path_env("used_json")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var stage := InventoryActionTests._stage_of(env)
	if stage.has("discard_used"):
		m.append("a new stage record already holds the mark")
	rt.dispatch(_drop("pack", 0))
	var copy: Dictionary = JSON.parse_string(JSON.stringify(rt.get_save_data()))
	var fc2 := FlowContext.new()
	fc2.save_data = copy
	fc2.realm_id = rt.flow_ctx.realm_id
	fc2.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE }
	if not InventoryRules.discard_used(fc2) or InventoryRules.discard_block_reason(fc2, "pack") != "path_used" \
			or InventoryRules.discard_block_reason(fc2, "sanctum") != "not_in_pack":
		m.append("the loaded copy lost the mark: used %s, pack '%s'" % [str(InventoryRules.discard_used(fc2)),
			InventoryRules.discard_block_reason(fc2, "pack")])
	return _result(m)


static func _t_reset() -> Dictionary:
	var m: Array = []
	# (a) An early leave ends the path: the mark is cleared.
	var env := _path_env("reset_leave")
	if not bool(env.get("ok", false)):
		return env
	var rt: FlowRuntime = env["rt"]
	InventoryRules.mark_discard_used(rt.flow_ctx)
	if not InventoryActionTests._force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	rt.dispatch({ "type": "stage.return_home" })
	if str(InventoryActionTests._stage_of(env)["explore_map"]["party_state"]) != "escaped" \
			or InventoryActionTests._stage_of(env).has("discard_used"):
		m.append("leave: party_state %s, mark %s" % [str(InventoryActionTests._stage_of(env)["explore_map"]["party_state"]),
			str(InventoryActionTests._stage_of(env).get("discard_used"))])
	# (b) A defeat ends the path.
	var env2 := _path_env("reset_defeat")
	if not bool(env2.get("ok", false)):
		return env2
	var fc2: FlowContext = (env2["rt"] as FlowRuntime).flow_ctx
	InventoryRules.mark_discard_used(fc2)
	ActiveStageService.lose_unsettled_packs(fc2, 5)
	if InventoryActionTests._stage_of(env2).has("discard_used"):
		m.append("defeat: the mark stayed")
	# (c) The path end (settlement) clears it as well.
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 3)
	ItemPacksTests._stage(ctx)["discard_used"] = true
	ItemPacksTests._settle_path(ctx, 3)
	if ItemPacksTests._stage(ctx).has("discard_used"):
		m.append("path end: the mark stayed")
	# (d) A cleared mark gives the next path its discard again.
	InventoryRules.clear_discard_used(InventoryActionTests._stage_of(env2))
	if InventoryRules.discard_block_reason(fc2, "pack") != "":
		m.append("a new path: the pack discard is still refused with '%s'" % InventoryRules.discard_block_reason(fc2, "pack"))
	return _result(m)


static func _t_path_snapshot() -> Dictionary:
	var env := _path_env("path_snap")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var snap := rt.flow_ctx.last_snapshot
	var inv: Dictionary = (snap["data"] as Dictionary).get("inventory", {})
	if inv.is_empty():
		return { "ok": false, "error": "the path view snapshot has no data.inventory" }
	rt.dispatch(_drop("pack", 1, 1))  # one stack discard: forces a rebuild of the path view
	inv = (rt.flow_ctx.last_snapshot["data"] as Dictionary)["inventory"]
	var pack_row: Dictionary = inv["pack_stacks"][0]
	if int(inv["pack_count"]) != 2 or int(inv["pack_load"]["level"]) < 1 or int(inv["pack_capacity"]) != 3 \
			or int(pack_row["count"]) != 2 or str(pack_row["name"]) != "Placeholder consumable A" or int(pack_row["slot"]) != 1:
		m.append("path inventory: %s" % JSON.stringify(inv))
	for slot in (rt.flow_ctx.last_snapshot["actions"] as Dictionary):
		if str(slot).contains("inventory") or str(slot).contains("discard"):
			m.append("actions holds a slot %s" % str(slot))
	return _result(m)


## A stack in the pack follows the carried-piece rules (D-19, D-20, D-22): drawn on an early leave, lost on
## defeat, moved into the Sanctum at the path end or when the leave keeps it. Its report row has no mark.
static func _stack_row(reason: String) -> Dictionary:
	return { "type_id": "ph_material_a", "kind": "material", "grade": "", "quantity": 2, "source": "held",
		"mark_index": -1, "reason_key": reason }


static func _stack_ctx(seed_value: int, cap: int) -> FlowContext:
	var ctx := ItemPacksTests._ctx(seed_value, cap, 3)
	var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_material_a", 2), "direct")
	InventoryService.move_entry(ctx.save_data, cfg, "sanctum", 0, "pack")
	return ctx


static func _t_held_stack_settle() -> Dictionary:
	var m: Array = []
	# The plan and the preview count the stack.
	var ctx := _stack_ctx(ItemPacksTests._SEED_NONE, 3)
	if int(StageSettlementService.settle_plan(ctx, ctx.config_service)["held_pieces"]) != 1:
		m.append("settle_plan does not count the held stack")
	var risk := StageSettlementService.items_at_risk(ctx, ctx.config_service)
	var want_risk := _stack_row("")
	want_risk.erase("reason_key")
	if str(risk) != str([want_risk]):
		m.append("items_at_risk %s" % str(risk))
	# Outcome none: the stack is lost, recorded, and leaves the pack.
	var lost: Dictionary = ItemPacksTests._leave(ctx)["result"]["items"]
	var save: Dictionary = ctx.save_data["inventory"]
	if str(lost["lost"]) != str([_stack_row("leave_none")]) or not (lost["kept"] as Array).is_empty() \
			or not (save["pack_stacks"] as Array).is_empty() or not (save["stacks"] as Array).is_empty():
		m.append("none: %s, inventory %s" % [str(lost), JSON.stringify(save)])
	if not str(ItemPacksTests._held_fates(ctx)).contains("stack:ph_material_a:0"):
		m.append("none: no held fate for the stack: %s" % str(ItemPacksTests._held_fates(ctx)))
	# Outcome all: the stack is kept and moves into the Sanctum.
	var ctx2 := _stack_ctx(ItemPacksTests._SEED_ALL, 3)
	var kept: Dictionary = ItemPacksTests._leave(ctx2)["result"]["items"]
	var save2: Dictionary = ctx2.save_data["inventory"]
	if str(kept["kept"]) != str([_stack_row("ok")]) or not (kept["lost"] as Array).is_empty() \
			or not (save2["pack_stacks"] as Array).is_empty() or (save2["stacks"] as Array).size() != 1:
		m.append("all: %s, inventory %s" % [str(kept), JSON.stringify(save2)])
	# Outcome all with a full Sanctum: the stack stays held.
	var ctx3 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
	var cfg3 := ConfigService.get_inventory_cfg(ctx3.config_service)
	InventoryService.intake(ctx3.save_data, cfg3, InventoryServiceTests._e("ph_weapon_a"), "direct")
	ctx3.save_data["inventory"]["pack_stacks"] = [{ "type_id": "ph_material_a", "kind": "material", "quantity": 2, "slot": 0 }]
	var stay: Dictionary = ItemPacksTests._leave(ctx3)["result"]["items"]
	if str(stay["kept"]) != str([_stack_row("to_pack")]) or (ctx3.save_data["inventory"]["pack_stacks"] as Array).size() != 1:
		m.append("all, full Sanctum: %s" % str(stay))
	# Defeat: lost with the reason defeat; a second defeat changes nothing.
	var ctx4 := _stack_ctx(ItemPacksTests._SEED_ALL, 3)
	ActiveStageService.lose_unsettled_packs(ctx4, 3)
	if not (ctx4.save_data["inventory"]["pack_stacks"] as Array).is_empty() \
			or str(ItemPacksTests._held_fates(ctx4)) != str({ "stack:ph_material_a:0": "defeat/lost/defeat" }):
		m.append("defeat: %s, fates %s" % [JSON.stringify(ctx4.save_data["inventory"]), str(ItemPacksTests._held_fates(ctx4))])
	var after := JSON.stringify(ctx4.save_data)
	ActiveStageService.lose_unsettled_packs(ctx4, 4)
	if JSON.stringify(ctx4.save_data) != after:
		m.append("a repeat defeat changed the save")
	# Path end: the stack moves into the Sanctum; nothing is drawn.
	var ctx5 := _stack_ctx(ItemPacksTests._SEED_NONE, 3)
	ItemPacksTests._settle_path(ctx5, 3)
	if not (ctx5.save_data["inventory"]["pack_stacks"] as Array).is_empty() or (ctx5.save_data["inventory"]["stacks"] as Array).size() != 1:
		m.append("path end: %s" % JSON.stringify(ctx5.save_data["inventory"]))
	return _result(m)


## Outcome "some": the carried stack draws once, on its own stream named by type and pack slot. The test predicts
## the draw from the stream name, so a change of the key fails it. Six pack slots give both a keep and a loss.
static func _t_held_stack_some() -> Dictionary:
	var m: Array = []
	var kept_n := 0
	var lost_n := 0
	for slot in 6:
		var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_SOME, 3, 8)
		var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
		InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_material_a", 2), "direct")
		InventoryService.move_entry(ctx.save_data, cfg, "sanctum", 0, "pack", slot)
		var realm_seed := int(RealmService.get_active(ctx).get("seed", 0))
		var name := "inventory.leave.%s.0.0.held.stack:ph_material_a:%d" % [ctx.stage_id, slot]
		var keeps := CampaignSeed.get_rng_from(realm_seed, name).randi_range(0, 99) < 50
		var r: Dictionary = ItemPacksTests._leave(ctx)
		var items: Dictionary = r["result"]["items"]
		var want_kept := [_stack_row("ok")] if keeps else []
		var want_lost := [] if keeps else [_stack_row("leave_some")]
		if str(r["result"]["outcome"]) != "some" or str(items["kept"]) != str(want_kept) or str(items["lost"]) != str(want_lost):
			m.append("slot %d: outcome %s, predicted keep %s, items %s" % [slot, str(r["result"]["outcome"]), str(keeps), str(items)])
		if keeps:
			kept_n += 1
			if (ctx.save_data["inventory"]["stacks"] as Array).size() != 1:
				m.append("slot %d: the kept stack is not in the Sanctum" % slot)
		else:
			lost_n += 1
			if not (ctx.save_data["inventory"]["pack_stacks"] as Array).is_empty() or not (ctx.save_data["inventory"]["stacks"] as Array).is_empty():
				m.append("slot %d: the lost stack is still held" % slot)
	if kept_n == 0 or lost_n == 0:
		m.append("the six slots gave kept %d and lost %d; a draw that never varies proves nothing" % [kept_n, lost_n])
	return _result(m)


static func _sequence(tag: String) -> String:
	var env := _stocked(tag, 4)
	InventoryActionTests._dispatch(env, _mv("sanctum", 1, "pack"))
	InventoryActionTests._dispatch(env, _mv("sanctum", 2, "pack", 3))
	InventoryActionTests._dispatch(env, _mv("pack", 0, "sanctum", 1))
	InventoryActionTests._dispatch(env, _drop("pack", 3, 2))
	InventoryActionTests._dispatch(env, _mv("pack", 3, "sanctum"))
	InventoryActionTests._dispatch(env, _drop("sanctum", 0))
	var out := JSON.stringify(InventoryActionTests._save(env)["inventory"], "", true)
	InventoryActionTests._done(env)
	return out


static func _t_determinism() -> Dictionary:
	var m: Array = []
	var a := _sequence("det_a")
	var b := _sequence("det_b")
	if a != b:
		m.append("two runs differ:\n%s\n%s" % [a, b])
	if not a.contains("\"slot\""):
		m.append("the final inventory holds no slots: %s" % a)
	return _result(m)


## No placeholder id may reach balance.json or a new save. The shipping sizes can grow: they are whole numbers
## above 0 and are the only numbers the snapshot reads for the container sizes.
static func _t_no_placeholder() -> Dictionary:
	var m: Array = []
	var text := FileAccess.get_file_as_string("res://data/balance.json")
	if InventorySaveTests._has_placeholder_id(text):
		m.append("balance.json holds a ph_ id")
	var parsed: Variant = JSON.parse_string(text)
	var inv: Dictionary = (((parsed as Dictionary)["data"] as Dictionary)["inventory"]) if parsed is Dictionary else {}
	for key in ["unique_cap", "pack_capacity"]:
		if not (inv.get(key) is float or inv.get(key) is int) or int(inv.get(key)) < 1:
			m.append("%s is not a whole number above 0: %s" % [key, str(inv.get(key))])
	if not (inv.get("definitions", null) is Dictionary) or not (inv["definitions"] as Dictionary).is_empty():
		m.append("shipping definitions are not empty")
	if InventorySaveTests._has_placeholder_id(JSON.stringify(SaveSchema.make_new_save(5))):
		m.append("a new save holds a ph_ id")
	return _result(m)
