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
	runner.register_test("inventory_paths/a_carried_stack_is_drawn_and_lost_like_a_carried_piece", Callable(InventoryPathTests, "_t_held_stack_settle"))
	runner.register_test("inventory_paths/a_carried_stack_is_drawn_on_a_some_leave", Callable(InventoryPathTests, "_t_held_stack_some"))
	runner.register_test("inventory_paths/a_failed_return_home_keeps_the_used_mark", Callable(InventoryPathTests, "_t_failed_leave_keeps_mark"))
	runner.register_test("inventory_paths/a_move_into_the_pack_leaves_the_slots_of_open_item_rows", Callable(InventoryPathTests, "_t_move_respects_reserved"))
	runner.register_test("inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full", Callable(InventoryPathTests, "_t_find_stack_to_pack"))
	runner.register_test("inventory_paths/a_big_stack_find_stays_within_the_pack_through_the_real_seam", Callable(InventoryPathTests, "_t_big_find_seam"))
	runner.register_test("inventory_paths/a_big_stack_find_leaves_the_slots_of_later_rows", Callable(InventoryPathTests, "_t_big_find_later_rows"))
	runner.register_test("inventory_paths/a_big_stack_find_leaves_the_slots_of_rows_in_other_realms", Callable(InventoryPathTests, "_t_big_find_other_realm"))
	runner.register_test("inventory_paths/a_refusal_key_is_in_the_next_snapshot_only", Callable(InventoryPathTests, "_t_refusal_key_one_shot"))
	runner.register_test("inventory_paths/each_refusal_reason_reaches_the_snapshot", Callable(InventoryPathTests, "_t_refusal_key_reasons"))
	runner.register_test("inventory_paths/the_refusal_key_is_never_saved_and_does_not_survive_a_reload", Callable(InventoryPathTests, "_t_refusal_key_not_saved"))
	runner.register_test("inventory_paths/item_names_are_on_at_risk_and_result_rows", Callable(InventoryPathTests, "_t_row_names"))
	runner.register_test("inventory_paths/item_names_survive_a_reload_of_the_result", Callable(InventoryPathTests, "_t_row_names_reload"))
	runner.register_test("inventory_paths/a_type_without_a_definition_has_no_name_key", Callable(InventoryPathTests, "_t_row_no_definition"))
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
	var key := _controller(env["rt"], env).handle_move(action, 9).error_code
	(env["rt"] as FlowRuntime).flow_ctx.pending_inventory_refusal = {}
	return key


static func _drop_key(env: Dictionary, action: Dictionary) -> String:
	var key := _controller(env["rt"], env).handle_discard(action, 9).error_code
	(env["rt"] as FlowRuntime).flow_ctx.pending_inventory_refusal = {}
	return key


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
## defeat, and stays in the pack at the path end or when the leave keeps it. Its report row has no mark.
static func _stack_row(reason: String) -> Dictionary:
	return { "type_id": "ph_material_a", "kind": "material", "grade": "", "quantity": 2, "source": "held",
		"mark_index": -1, "name": "Placeholder material A", "reason_key": reason }


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
	# Outcome all: the stack is kept and stays in the pack (D-42).
	var ctx2 := _stack_ctx(ItemPacksTests._SEED_ALL, 3)
	var kept: Dictionary = ItemPacksTests._leave(ctx2)["result"]["items"]
	var save2: Dictionary = ctx2.save_data["inventory"]
	if str(kept["kept"]) != str([_stack_row("ok")]) or not (kept["lost"] as Array).is_empty() \
			or (save2["pack_stacks"] as Array).size() != 1 or not (save2["stacks"] as Array).is_empty():
		m.append("all: %s, inventory %s" % [str(kept), JSON.stringify(save2)])
	# Outcome all with a full Sanctum: the same, the stack stays held.
	var ctx3 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
	var cfg3 := ConfigService.get_inventory_cfg(ctx3.config_service)
	InventoryService.intake(ctx3.save_data, cfg3, InventoryServiceTests._e("ph_weapon_a"), "direct")
	ctx3.save_data["inventory"]["pack_stacks"] = [{ "type_id": "ph_material_a", "kind": "material", "quantity": 2, "slot": 0 }]
	var stay: Dictionary = ItemPacksTests._leave(ctx3)["result"]["items"]
	if str(stay["kept"]) != str([_stack_row("ok")]) or (ctx3.save_data["inventory"]["pack_stacks"] as Array).size() != 1:
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
	# Path end: nothing is drawn and nothing moves; the stack stays in the pack.
	var ctx5 := _stack_ctx(ItemPacksTests._SEED_NONE, 3)
	ItemPacksTests._settle_path(ctx5, 3)
	if (ctx5.save_data["inventory"]["pack_stacks"] as Array).size() != 1 or not (ctx5.save_data["inventory"]["stacks"] as Array).is_empty():
		m.append("path end: %s" % JSON.stringify(ctx5.save_data["inventory"]))
	return _result(m)


## Outcome "some": the carried stack draws once, on a stream named by its type and its order among the stacks of
## that type (D-43), never by its pack slot. The test predicts the draw from the stream name and checks that the
## same stack gives the same result in every pack slot. Two types and two seeds give both a keep and a loss.
static func _t_held_stack_some() -> Dictionary:
	var m: Array = []
	var kept_n := 0
	var lost_n := 0
	for type_id in ["ph_material_a", "ph_consumable_a"]:
		for seed_value in [ItemPacksTests._SEED_SOME, 13, 21, 34]:
			var results: Array = []
			for slot in [0, 3, 7]:
				var ctx := ItemPacksTests._ctx(seed_value, 3, 8)
				var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
				InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e(type_id, 2), "direct")
				InventoryService.move_entry(ctx.save_data, cfg, "sanctum", 0, "pack", slot)
				var r: Dictionary = ItemPacksTests._leave(ctx)
				if str(r["result"]["outcome"]) != "some":
					break
				var kept := not (r["result"]["items"]["kept"] as Array).is_empty()
				results.append(kept)
				if slot == 0:
					var realm_seed := int(RealmService.get_active(ctx).get("seed", 0))
					var name := "inventory.leave.%s.0.0.held.stack:%s:0" % [ctx.stage_id, type_id]
					var keeps := CampaignSeed.get_rng_from(realm_seed, name).randi_range(0, 99) < 50
					if keeps != kept:
						m.append("%s seed %d: predicted keep %s, got %s" % [type_id, seed_value, str(keeps), str(kept)])
					if kept:
						kept_n += 1
					else:
						lost_n += 1
			if results.size() > 1 and (results.has(true) and results.has(false)):
				m.append("%s seed %d: the result depends on the pack slot: %s" % [type_id, seed_value, str(results)])
	if kept_n == 0 or lost_n == 0:
		m.append("kept %d, lost %d; a draw that never varies proves nothing" % [kept_n, lost_n])
	return _result(m)


## F-04: a return home that fails (the escape roll fails, the path goes on) must keep the one-discard mark.
static func _t_failed_leave_keeps_mark() -> Dictionary:
	var env := _path_env("failed_leave")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	var fc := rt.flow_ctx
	var realm := VentureCharacterizationTests._realm(rt.get_save_data(), "realm.01")
	var turn := int((InventoryActionTests._stage_of(env)["explore_map"] as Dictionary).get("turn_count", 0))
	var found := false
	for s in range(0, 20000):
		if CampaignSeed.get_rng_from(s, "stage.escape.%s.%d" % [fc.stage_id, turn]).randi_range(0, 100) == 0:
			realm["seed"] = s
			found = true
			break
	if not found:
		return { "ok": false, "error": "test setup failed: no seed gives a failing escape roll" }
	rt.dispatch(_drop("pack", 0))
	if not bool(InventoryActionTests._stage_of(env).get("discard_used", false)):
		return { "ok": false, "error": "test setup: the discard did not set the mark" }
	rt.dispatch({ "type": "stage.return_home" })
	var map: Dictionary = InventoryActionTests._stage_of(env)["explore_map"]
	if str(map.get("party_state", "")) == "escaped":
		return { "ok": false, "error": "test setup: the escape succeeded" }
	if not bool(InventoryActionTests._stage_of(env).get("discard_used", false)):
		m.append("a failed return home cleared the mark")
	if _drop_key(env, _drop("pack", 1)) != "path_used":
		m.append("after a failed return home the second discard gave '%s'" % _drop_key(env, _drop("pack", 1)))
	return _result(m)


## F-05: open item rows own pack slots (D-17), so a move into the pack cannot take them.
static func _t_move_respects_reserved() -> Dictionary:
	var m: Array = []
	var env := _stocked("rsv", 2)
	InventoryActionTests._live_path(env)
	var stage: Dictionary = (((InventoryActionTests._save(env)["realms"] as Dictionary)["realm.01"] as Dictionary)["stages"] as Array)[0]
	EarningsService.record_item(stage, "s0", "a", ItemPacksTests._entry("ph_armor_a"))
	var rt: FlowRuntime = env["rt"]
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 3)
	InventoryActionTests._dispatch(env, { "type": "debug.seed.show" })
	InventoryActionTests._dispatch(env, _mv("sanctum", 0, "pack"))
	if InventoryService.pack_count(InventoryActionTests._save(env)) != 1:
		m.append("the first move (one free slot) was refused")
	var p := _refused(env, _mv("sanctum", 1, "pack"), "container_full", "pack slot owned by an open row", "inventory.move.denied")
	if p != "":
		m.append(p)
	var load_info: Dictionary = InventoryActionTests._inv_snap(env)["pack_load"]
	if int(load_info["carried"]) > int(load_info["capacity"]):
		m.append("carried %s above capacity %s" % [str(load_info["carried"]), str(load_info["capacity"])])
	InventoryActionTests._done(env)
	return _result(m)


## The leave and the path end use the same intake: a gathered stack with a full Sanctum is KEPT, reason `to_pack`.
static func _t_find_stack_to_pack() -> Dictionary:
	var m: Array = []
	var want := { "type_id": "ph_consumable_a", "kind": "consumable", "grade": "g1", "quantity": 2, "source": "gathered",
		"mark_index": -1, "name": "Placeholder consumable A", "reason_key": "to_pack" }
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
	InventoryService.intake(ctx.save_data, ConfigService.get_inventory_cfg(ctx.config_service), InventoryServiceTests._e("ph_weapon_a"), "direct")
	ItemPacksTests._add_rows(ctx, "s0", [0], "ph_consumable_a")
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s1", "0", ItemPacksTests._entry("ph_consumable_a", 2))
	var leave: Dictionary = ItemPacksTests._leave(ctx)["result"]["items"]
	var kept: Array = leave["kept"]
	if kept.size() != 2 or not (leave["lost"] as Array).is_empty() or str(kept[1]) != str(want):
		m.append("leave: %s" % str(leave))
	# The second find merges into the pack stack of the first (1 + 2 = 3, the limit): one pack stack (D-45).
	var pstacks: Array = ctx.save_data["inventory"]["pack_stacks"]
	if pstacks.size() != 1 or int(pstacks[0]["quantity"]) != 3 or not (ctx.save_data["inventory"]["stacks"] as Array).is_empty():
		m.append("leave inventory: %s" % JSON.stringify(ctx.save_data["inventory"]))
	# Path end.
	var ctx2 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
	InventoryService.intake(ctx2.save_data, ConfigService.get_inventory_cfg(ctx2.config_service), InventoryServiceTests._e("ph_weapon_a"), "direct")
	EarningsService.record_item(ItemPacksTests._stage(ctx2), "s1", "0", ItemPacksTests._entry("ph_consumable_a", 2))
	var paid: Dictionary = ItemPacksTests._settle_path(ctx2, 4)
	var pkept: Array = (paid["items"] as Dictionary)["kept"]
	if pkept.size() != 1 or str(pkept[0]) != str(want) or (ctx2.save_data["inventory"]["pack_stacks"] as Array).size() != 1:
		m.append("path end: %s, inventory %s" % [str(paid.get("items")), JSON.stringify(ctx2.save_data["inventory"])])
	return _result(m)


static func _pack_entries(ctx: FlowContext) -> int:
	return InventoryService.pack_count(ctx.save_data)


static func _quantity_in_stacks(ctx: FlowContext) -> int:
	var n := 0
	for key in ["stacks", "pack_stacks"]:
		for st in (ctx.save_data["inventory"] as Dictionary).get(key, []):
			n += int(st["quantity"])
	return n


## F3-01. Sanctum of 1 slot, full. Pack of 3, empty. The real seam takes three finds (one pack slot each):
## consumable 8 (limit 3), relic, armor. The path end and an early leave with outcome "all" must keep the pack
## within its size: the stack find may start further pack stacks only in slots that no later row owns.
static func _t_big_find_seam() -> Dictionary:
	var m: Array = []
	for how in ["path_end", "leave"]:
		var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
		var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
		InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
		var finds := [ItemPacksTests._find("f0", "ph_consumable_a", 8), ItemPacksTests._find("f1", "ph_relic_a"),
			ItemPacksTests._find("f2", "ph_armor_a")]
		var got := ActiveStageService.record_found_items(ctx, "s0", finds, 2)
		if (got["taken"] as Array).size() != 3:
			m.append("%s: the seam took %s" % [how, str(got)])
		var items: Dictionary
		if how == "path_end":
			items = ItemPacksTests._settle_path(ctx, 5)["items"]
		else:
			var r: Dictionary = ItemPacksTests._leave(ctx)["result"]
			if str(r["outcome"]) != "all":
				m.append("leave outcome %s, expected all" % str(r["outcome"]))
			items = r["items"]
		if _pack_entries(ctx) > 3 or not InventoryService.validate(ctx.save_data, cfg).is_empty():
			m.append("%s: pack entries %d, validate %s" % [how, _pack_entries(ctx), str(InventoryService.validate(ctx.save_data, cfg))])
		# Conservation: 3 consumables kept, 5 reported lost; relic and armor are in the pack.
		var cons: Dictionary = (items["kept"] as Array)[0]
		if int(cons["quantity"]) != 3 or int(cons.get("lost_quantity", 0)) != 5 or _quantity_in_stacks(ctx) != 3 \
				or (items["kept"] as Array).size() != 3 or (ctx.save_data["inventory"]["pack"] as Array).size() != 2:
			m.append("%s: kept %s, inventory %s" % [how, str(items), JSON.stringify(ctx.save_data["inventory"])])
	return _result(m)


## F3-01. Rows [relic, consumable 8], Sanctum full, empty pack of 4: the relic takes 1 slot and the stack takes the
## other 3 (3 + 3 + 2, nothing lost). A row's chunks must leave free exactly one slot for each row AFTER it, never
## for rows already settled. The preview equals the payout. Also: a row after the stack keeps its slot.
static func _t_big_find_later_rows() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 4)
	var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s0", "0", ItemPacksTests._entry("ph_relic_a"))
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s0", "1", ItemPacksTests._entry("ph_consumable_a", 8))
	var preview: Dictionary = ItemPacksTests._preview(ctx).get("items", {})
	var paid := StageSettlementService.card_items(ItemPacksTests._settle_path(ctx, 5)["items"])
	var q: Array = (ctx.save_data["inventory"]["pack_stacks"] as Array).map(func(st): return int(st["quantity"]))
	if q != [3, 3, 2] or _pack_entries(ctx) != 4 or not InventoryService.validate(ctx.save_data, cfg).is_empty():
		m.append("rows [relic, consumable 8]: pack stacks %s, entries %d, validate %s" % [str(q), _pack_entries(ctx),
			str(InventoryService.validate(ctx.save_data, cfg))])
	if (paid["lost"] as Array).size() != 0 or JSON.stringify(preview, "", true) != JSON.stringify(paid, "", true):
		m.append("preview %s, payout %s" % [JSON.stringify(preview), JSON.stringify(paid)])
	# The stack row first, the relic after it: the stack leaves the relic's slot free (3 + 3 + 1 slot).
	var ctx2 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 4)
	InventoryService.intake(ctx2.save_data, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
	EarningsService.record_item(ItemPacksTests._stage(ctx2), "s0", "0", ItemPacksTests._entry("ph_consumable_a", 8))
	EarningsService.record_item(ItemPacksTests._stage(ctx2), "s0", "1", ItemPacksTests._entry("ph_relic_a"))
	var paid2: Dictionary = ItemPacksTests._settle_path(ctx2, 5)["items"]
	var q2: Array = (ctx2.save_data["inventory"]["pack_stacks"] as Array).map(func(st): return int(st["quantity"]))
	var kept2: Array = paid2["kept"]
	if q2 != [3, 3, 2] or (ctx2.save_data["inventory"]["pack"] as Array).size() != 1 or _pack_entries(ctx2) != 4 \
			or kept2.size() != 2 or int(paid2["lost_count"]) != 0:
		m.append("rows [consumable 8, relic]: pack stacks %s, entries %d, report %s" % [str(q2), _pack_entries(ctx2), str(paid2)])
	# F4-03: the early leave (outcome all) counts the later rows the same way: [relic, consumable 8], pack of 4.
	var ctx3 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 4)
	InventoryService.intake(ctx3.save_data, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
	EarningsService.record_item(ItemPacksTests._stage(ctx3), "s0", "0", ItemPacksTests._entry("ph_relic_a"))
	EarningsService.record_item(ItemPacksTests._stage(ctx3), "s0", "1", ItemPacksTests._entry("ph_consumable_a", 8))
	var leave3: Dictionary = ItemPacksTests._leave(ctx3)["result"]
	var q3: Array = (ctx3.save_data["inventory"]["pack_stacks"] as Array).map(func(st): return int(st["quantity"]))
	if str(leave3["outcome"]) != "all" or q3 != [3, 3, 2] or _pack_entries(ctx3) != 4 or int(leave3["items"]["lost_count"]) != 0 \
			or not InventoryService.validate(ctx3.save_data, cfg).is_empty():
		m.append("leave, rows [relic, consumable 8]: outcome %s, pack stacks %s, entries %d, items %s" % [
			str(leave3["outcome"]), str(q3), _pack_entries(ctx3), str(leave3["items"])])
	return _result(m)


## F4-01. An open item row in ANOTHER Realm owns a pack slot too. Sanctum full (1 slot), pack of 3. Realm B holds an
## open relic row. Realm A finds consumable 8 through the real seam (free room 2 because Realm B's row counts). The
## path end and an early leave must keep the Realm B slot free: 3 + 3 kept, 2 lost, pack 2 of 3. When Realm B's row is
## settled later, the pack holds 3 entries and `validate` is empty.
static func _t_big_find_other_realm() -> Dictionary:
	var m: Array = []
	for how in ["path_end", "leave"]:
		var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 1, 3)
		var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
		InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_weapon_a"), "direct")
		var other := { "run_count": 0, "seed": 1, "stages": [{ "index": 0, "earnings": [] }] }
		(ctx.save_data["realms"] as Dictionary)["realm.02"] = other
		EarningsService.record_item((other["stages"] as Array)[0], "r2", "open", ItemPacksTests._entry("ph_relic_a"))
		var got := ActiveStageService.record_found_items(ctx, "s0", [ItemPacksTests._find("f0", "ph_consumable_a", 8)], 2)
		if (got["taken"] as Array).size() != 1:
			m.append("%s: the seam took %s" % [how, str(got)])
		var items: Dictionary
		if how == "path_end":
			items = ItemPacksTests._settle_path(ctx, 5)["items"]
		else:
			items = ItemPacksTests._leave(ctx)["result"]["items"]
		var kept: Dictionary = (items["kept"] as Array)[0]
		if _quantity_in_stacks(ctx) != 6 or int(kept["quantity"]) != 6 or int(kept.get("lost_quantity", 0)) != 2 or _pack_entries(ctx) != 2:
			m.append("%s: stacks hold %d, kept %s, pack entries %d" % [how, _quantity_in_stacks(ctx), str(kept), _pack_entries(ctx)])
		# Realm B's path ends: its relic row is banked into the slot that was kept for it.
		var res := InventoryService.intake(ctx.save_data, cfg, InventoryServiceTests._e("ph_relic_a"), "gathered", 0)
		var row: Dictionary = ((other["stages"] as Array)[0]["earnings"] as Array)[0]
		row["settled"] = true
		if str(res["result"]) != "packed" or _pack_entries(ctx) > 3 or not InventoryService.validate(ctx.save_data, cfg).is_empty():
			m.append("%s after Realm B: %s, entries %d, validate %s" % [how, str(res["result"]), _pack_entries(ctx),
				str(InventoryService.validate(ctx.save_data, cfg))])
	return _result(m)


## `data.inventory.refused` of a snapshot, or {}.
static func _refused_of(snap: Dictionary) -> Dictionary:
	var d: Variant = snap.get("data", null)
	if d is Dictionary and (d as Dictionary).get("inventory", null) is Dictionary:
		var r: Variant = ((d as Dictionary)["inventory"] as Dictionary).get("refused", null)
		return r if r is Dictionary else {}
	return {}


## D-48: a refused move or discard publishes `data.inventory.refused = { action, reason }` in exactly the next
## snapshot. The snapshot after it (a later dispatch, or `last_snapshot`) does not carry it. An accepted action
## gives none.
static func _t_refusal_key_one_shot() -> Dictionary:
	var m: Array = []
	var env := _stocked("rk_one", 2)
	var rt: FlowRuntime = env["rt"]
	InventoryActionTests._dispatch(env, { "type": "debug.seed.show" })
	var out := rt.dispatch(_mv("sanctum", 0, "sanctum", 1))  # slot taken
	if _refused_of(out) != { "action": "move", "reason": "slot_taken" }:
		m.append("the dispatch result has %s" % str(_refused_of(out)))
	if not _refused_of(rt.flow_ctx.last_snapshot).is_empty():
		m.append("last_snapshot keeps the key")
	if not _refused_of(rt.dispatch({ "type": "debug.seed.show" })).is_empty():
		m.append("the next dispatch carries the key again")
	# A discard refusal is named `discard`.
	out = rt.dispatch(_drop("sanctum", 9))
	if _refused_of(out) != { "action": "discard", "reason": "unknown_entry" }:
		m.append("discard refusal: %s" % str(_refused_of(out)))
	# Nothing else changed: the save is byte-equal across a refusal.
	var before := _json_of(env)
	rt.dispatch(_mv("sanctum", 0, "sanctum", 1))
	if _json_of(env) != before:
		m.append("a refusal changed the save")
	# An accepted move and an accepted discard give no key.
	if not _refused_of(rt.dispatch(_mv("sanctum", 0, "pack"))).is_empty() or not _refused_of(rt.dispatch(_drop("sanctum", 1))).is_empty():
		m.append("an accepted action carries a refusal key")
	if not _refused_of(rt.flow_ctx.last_snapshot).is_empty() or not rt.flow_ctx.pending_inventory_refusal.is_empty():
		m.append("state left over after accepted actions")
	# A refusal on a screen without data.inventory sets nothing.
	rt.flow_machine.transition(FlowStateIds.STAGE_MAP, rt.flow_ctx, env["logger"], 4, "test")
	var away := rt.dispatch(_mv("sanctum", 0, "pack"))
	if not _refused_of(away).is_empty() or not rt.flow_ctx.pending_inventory_refusal.is_empty():
		m.append("a refusal on the stage map set a key")
	InventoryActionTests._done(env)
	return _result(m)


## Each refusal reason maps to its key, from the Sanctum and from the path view.
static func _t_refusal_key_reasons() -> Dictionary:
	var m: Array = []
	var env := InventoryActionTests._env("rk_reasons", 6, 3)
	var rt: FlowRuntime = env["rt"]
	var save := InventoryActionTests._save(env)
	var cfg: Dictionary = env["inv_cfg"]
	cfg["stack_limit_default"] = 3  # the live test config: a stack of 3 is full
	for t in ["ph_weapon_a", "ph_charm_a"]:
		InventoryService.intake(save, cfg, InventoryServiceTests._e(t), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_consumable_a", 3), "direct")
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_material_a", 2), "direct")
	InventoryService.move_entry(save, cfg, "sanctum", 2, "pack", 0)
	InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_consumable_a", 3), "direct")
	rt.flow_machine.reenter(rt.flow_ctx, env["logger"], 3)
	InventoryActionTests._dispatch(env, { "type": "debug.seed.show" })
	var cases: Array = [
		["move", _mv("sanctum", 0, "sanctum", 1), "slot_taken"],
		["move", _mv("sanctum", 0, "sanctum", 6), "bad_slot"],
		["move", _mv("sanctum", 5, "pack"), "unknown_entry"],
		["move", _mv("sanctum", 3, "sanctum", 2), "type_mismatch"],
		["move", _mv("pack", 0, "sanctum", 2), "stack_limit"],
		["move", _mv("sanctum", 0, "sanctum", 0), "no_change"],
		["move", _mv("sanctum", 0, "moon"), "bad_box"],
		["move", { "type": _MOVE }, "bad_payload"],
		["discard", _drop("sanctum", 0, 2), "count_range"],
		["discard", _drop("sanctum", 5), "unknown_entry"],
		["discard", _drop("moon", 0), "bad_box"],
		["discard", { "type": _DISCARD, "payload": {} }, "bad_payload"],
		["discard", InventoryActionTests._discard("it.99"), "not_found"],
		["discard", InventoryActionTests._discard("ph_material_a"), "not_unique"],
	]
	for c in cases:
		var got := _refused_of(rt.dispatch(c[1]))
		if got != { "action": c[0], "reason": c[2] }:
			m.append("%s %s: %s (inventory %s)" % [c[0], c[2], str(got), JSON.stringify(save["inventory"])])
	# container_full: a pack of 1 that is full.
	var full := _stocked("rk_full", 1)
	InventoryActionTests._dispatch(full, _mv("sanctum", 0, "pack"))
	var got_full := _refused_of((full["rt"] as FlowRuntime).dispatch(_mv("sanctum", 1, "pack")))
	if got_full != { "action": "move", "reason": "container_full" }:
		m.append("container_full: %s" % str(got_full))
	InventoryActionTests._done(full)
	InventoryActionTests._done(env)
	# The path view: path_open, not_in_pack, path_used.
	var ex := _path_env("rk_path")
	if not bool(ex.get("ok", false)):
		return ex
	var prt: FlowRuntime = ex["rt"]
	for c in [["move", _mv("sanctum", 0, "pack"), "path_open"], ["discard", _drop("sanctum", 0), "not_in_pack"]]:
		var g := _refused_of(prt.dispatch(c[1]))
		if g != { "action": c[0], "reason": c[2] }:
			m.append("path view %s: %s" % [c[2], str(g)])
	prt.dispatch(_drop("pack", 0))
	var used := _refused_of(prt.dispatch(_drop("pack", 1)))
	if used != { "action": "discard", "reason": "path_used" }:
		m.append("path_used: %s" % str(used))
	if str(prt.flow_ctx.last_snapshot.get("type")) != FlowStateIds.STAGE_EXPLORE:
		m.append("the path view lost its snapshot type")
	return _result(m)


## The key is not in the save and does not come back after a quit and Continue.
static func _t_refusal_key_not_saved() -> Dictionary:
	var m: Array = []
	var env := _stocked("rk_save", 2)
	var rt: FlowRuntime = env["rt"]
	rt.dispatch(_mv("sanctum", 0, "sanctum", 1))
	rt.flow_ctx.request_save("test.refusal")
	rt.dispatch({ "type": "debug.seed.show" })
	if JSON.stringify(InventoryActionTests._save(env)).contains("refus"):
		m.append("the save holds a refusal field")
	var re := InventoryActionTests._reload(env)
	if not _refused_of((re["rt"] as FlowRuntime).flow_ctx.last_snapshot).is_empty() \
			or not (re["rt"] as FlowRuntime).flow_ctx.pending_inventory_refusal.is_empty():
		m.append("the key came back after a reload")
	InventoryActionTests._done(re)
	InventoryActionTests._done(env)
	return _result(m)


static func _all_rows_named(rows: Array, want: Dictionary) -> String:
	for r in rows:
		var row: Dictionary = r
		if str(row.get("name", "<none>")) != str(want.get(str(row["type_id"]), "<unknown>")):
			return "row %s has name '%s'" % [str(row["type_id"]), str(row.get("name", "<none>"))]
	return ""


const _NAMES := { "ph_weapon_a": "Placeholder weapon A", "ph_relic_a": "Placeholder relic A", "ph_armor_a": "Placeholder armor A",
	"ph_consumable_a": "Placeholder consumable A", "ph_material_a": "Placeholder material A" }


## D-48: `name` (the definition name, as on the inventory rows) is on the at-risk rows, the leave rows (kept and lost),
## the defeat rows and the stage-clear preview and payout rows. It is additive: the old keys stay.
static func _t_row_names() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 4)
	var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	ItemPacksTests._hold(ctx, 1, 1, "ph_relic_a")
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s0", "0", ItemPacksTests._entry("ph_armor_a"))
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s0", "1", ItemPacksTests._entry("ph_consumable_a", 2))
	var risk := StageSettlementService.items_at_risk(ctx, ctx.config_service)
	var bad := _all_rows_named(risk, _NAMES)
	if risk.size() != 3 or bad != "" or not (risk[0] as Dictionary).has("mark_index"):
		m.append("at risk: %s %s" % [bad, str(risk)])
	# Stage-clear preview and payout.
	var preview: Dictionary = ItemPacksTests._preview(ctx).get("items", {})
	bad = _all_rows_named((preview.get("kept", []) as Array) + (preview.get("lost", []) as Array), _NAMES)
	if (preview.get("kept", []) as Array).size() != 2 or bad != "":
		m.append("preview: %s %s" % [bad, str(preview)])
	var paid: Dictionary = ItemPacksTests._settle_path(ctx, 5)["items"]
	if JSON.stringify(StageSettlementService.card_items(paid), "", true) != JSON.stringify(preview, "", true):
		m.append("the payout rows differ from the preview")
	# Early leave: kept (a held and a gathered row) and lost rows.
	for outcome_seed in [[ItemPacksTests._SEED_ALL, "kept"], [ItemPacksTests._SEED_NONE, "lost"]]:
		var c2 := ItemPacksTests._ctx(int(outcome_seed[0]), 4, 4)
		ItemPacksTests._hold(c2, 1, 1, "ph_relic_a")
		EarningsService.record_item(ItemPacksTests._stage(c2), "s0", "0", ItemPacksTests._entry("ph_armor_a"))
		var items: Dictionary = ItemPacksTests._leave(c2)["result"]["items"]
		var rows: Array = items[str(outcome_seed[1])]
		bad = _all_rows_named(rows, _NAMES)
		if rows.size() != 2 or bad != "":
			m.append("leave %s: %s %s" % [str(outcome_seed[1]), bad, str(rows)])
	# Defeat (a context with an encounter): rows and held pieces.
	var c3 := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 4)
	c3.encounter_ctx = EncounterContext.new()
	ItemPacksTests._hold(c3, 1, 1, "ph_relic_a")
	EarningsService.record_item(ItemPacksTests._stage(c3), "s0", "0", ItemPacksTests._entry("ph_armor_a"))
	ActiveStageService.lose_unsettled_packs(c3, 3)
	var lost_rows: Array = (c3.encounter_ctx.packs_lost.get("items", []) as Array)
	bad = _all_rows_named(lost_rows, _NAMES)
	if lost_rows.size() != 2 or bad != "":
		m.append("defeat: %s %s" % [bad, str(lost_rows)])
	if cfg.is_empty():
		m.append("test setup: no inventory cfg")
	return _result(m)


## The result rows are stored with the durable result and replayed after a reload: the name comes back.
static func _t_row_names_reload() -> Dictionary:
	var env := _path_env("names_reload")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var rt: FlowRuntime = env["rt"]
	EarningsService.record_item(InventoryActionTests._stage_of(env), "s0", "a", ItemPacksTests._entry("ph_armor_a"))
	if not InventoryActionTests._force_leave_all(env):
		return { "ok": false, "error": "test setup failed: no seed rolls all with a successful escape" }
	var out: Dictionary = rt.dispatch({ "type": "stage.return_home" })
	var kept: Array = ((out.get("data", {}) as Dictionary).get("items", {}) as Dictionary).get("kept", [])
	if kept.is_empty() or _all_rows_named(kept, _NAMES) != "":
		m.append("the leave card rows: %s" % str(kept))
	var fc2 := FlowContext.new()
	fc2.save_data = JSON.parse_string(JSON.stringify(rt.get_save_data()))
	var replay: Dictionary = PendingResultService.build_snapshot(fc2, 9)
	var rkept: Array = (((replay.get("data", {}) as Dictionary).get("items", {}) as Dictionary).get("kept", []) as Array)
	if rkept.is_empty() or _all_rows_named(rkept, _NAMES) != "":
		m.append("the replayed card rows: %s" % str(rkept))
	return _result(m)


## A type with no definition: no `name` key on any row, and no crash. The real balance.json has no definitions.
static func _t_row_no_definition() -> Dictionary:
	var m: Array = []
	var ctx := ItemPacksTests._ctx(ItemPacksTests._SEED_ALL, 4, 4)
	(ctx.config_service as ItemPacksTests._Cfg).inv["definitions"] = {}
	ItemPacksTests._hold(ctx, 1, 1, "ph_relic_a")
	EarningsService.record_item(ItemPacksTests._stage(ctx), "s0", "0", ItemPacksTests._entry("ph_armor_a"))
	var risk := StageSettlementService.items_at_risk(ctx, ctx.config_service)
	var items: Dictionary = ItemPacksTests._leave(ctx)["result"]["items"]
	var rows: Array = risk + (items["kept"] as Array) + (items["lost"] as Array)
	if rows.size() != 4:
		m.append("expected 4 rows, got %d" % rows.size())
	for r in rows:
		if (r as Dictionary).has("name"):
			m.append("a row without a definition has a name: %s" % str(r))
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
