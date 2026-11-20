# res://tests/PickupSnapshotTests.gd
# V2-ITEM-001b step C7: the `flow.pickup` snapshot (PickupSnapshotBuilder), the id `FlowStateIds.PICKUP` and
# `InventoryRules.mode` for it. Fixtures come from PickupStateTests (real events opened through
# PickupEventService); nothing here is wired into FlowRuntime.

class_name PickupSnapshotTests
extends RefCounted

const _SIT := "s0"
const _ACTION_TYPES := { "overlay.skip": "pickup.skip", "cta.continue": "pickup.continue", "cta.swap": "pickup.swap.start",
	"back": "pickup.swap.cancel", "cta.confirm": "pickup.swap.confirm" }
const _DATA_KEYS := ["actors", "board_cols", "board_rows", "camera_frame", "case", "chooser", "confirm_leave_items", "destroy_left",
	"encounter_id", "fallen", "finds", "frozen", "order", "pack", "phase", "placement_seed", "pointer_look", "reaction",
	"reason", "return_to", "row", "run_count", "selected", "situation_id", "swap", "swap_left", "terrain"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_snapshot/shape_for_the_five_cases_and_frozen", Callable(PickupSnapshotTests, "_t_shape"))
	runner.register_test("pickup_snapshot/actions_per_phase_and_no_nav_back", Callable(PickupSnapshotTests, "_t_actions"))
	runner.register_test("pickup_snapshot/hidden_in_intro_revealed_after", Callable(PickupSnapshotTests, "_t_revealed"))
	runner.register_test("pickup_snapshot/pack_tone_follows_the_load_level", Callable(PickupSnapshotTests, "_t_tone"))
	runner.register_test("pickup_snapshot/pack_tone_before_leaves_out_the_finds_of_this_event", Callable(PickupSnapshotTests, "_t_tone_before"))
	runner.register_test("pickup_snapshot/swap_offered_and_refused_keys", Callable(PickupSnapshotTests, "_t_swap_keys"))
	runner.register_test("pickup_snapshot/swap_phase_falls_back_when_unsupported", Callable(PickupSnapshotTests, "_t_phase_fallback"))
	runner.register_test("pickup_snapshot/swap_and_destroy_left_and_leave_flag", Callable(PickupSnapshotTests, "_t_tokens_and_directive"))
	runner.register_test("pickup_snapshot/row_chooser_and_fallen", Callable(PickupSnapshotTests, "_t_row_chooser"))
	runner.register_test("pickup_snapshot/board_keys_and_actors_for_a_redraw", Callable(PickupSnapshotTests, "_t_board"))
	runner.register_test("pickup_snapshot/build_is_pure_and_repeatable", Callable(PickupSnapshotTests, "_t_pure"))
	runner.register_test("pickup_snapshot/no_record_gives_the_error_snapshot", Callable(PickupSnapshotTests, "_t_no_record"))
	runner.register_test("pickup_snapshot/snapshot_passes_the_machine_validator", Callable(PickupSnapshotTests, "_t_valid"))
	runner.register_test("pickup_snapshot/inventory_mode_is_none_for_pickup", Callable(PickupSnapshotTests, "_t_mode"))
	runner.register_test("pickup_snapshot/order_and_pick_index_follow_the_record", Callable(PickupSnapshotTests, "_t_order"))
	runner.register_test("pickup_snapshot/swap_starts_from_either_side", Callable(PickupSnapshotTests, "_t_both_sides"))
	runner.register_test("pickup_snapshot/swap_carries_the_dropped_item_through_a_json_round_trip", Callable(PickupSnapshotTests, "_t_dropped"))
	runner.register_test("pickup_snapshot/numbers_stay_ints_after_a_json_round_trip", Callable(PickupSnapshotTests, "_t_json_ints"))
	runner.register_test("pickup_snapshot/selected_is_valid_only_for_the_record", Callable(PickupSnapshotTests, "_t_selected"))
	runner.register_test("pickup_snapshot/board_actors_come_from_the_durable_result_after_a_reload", Callable(PickupSnapshotTests, "_t_pending_board"))
	runner.register_test("pickup_snapshot/tried_find_and_pack_slot_fields", Callable(PickupSnapshotTests, "_t_tried_and_slots"))
	runner.register_test("pickup_snapshot/chooser_standing_return_to_and_tick", Callable(PickupSnapshotTests, "_t_standing_meta"))
	runner.register_test("pickup_snapshot/build_leaves_the_flow_context_alone_and_terrain_is_a_copy", Callable(PickupSnapshotTests, "_t_context_untouched"))
	PickupPlacementBoardsTests.register(runner)
	PickupPlacementTests.register(runner)  # D-72: board tiles; no ui/ edit needed, the suite name stays pickup_snapshot
	PickupPointerLookTests.register(runner)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _norm(v: Variant) -> String:
	return ItemPacksTests._norm(v)


## An open event. kind: C1..C5 or "frozen". Returns { ctx, rec }.
static func _event(kind: String, fallen: Array = [], ranks: bool = false) -> Dictionary:
	var ctx: FlowContext
	var finds: Array
	match kind:
		"C1":
			ctx = PickupStateTests._ctx(2, 4)
			finds = PickupStateTests._finds(["ph_weapon_a", "ph_relic_a"])
		"C2":
			ctx = PickupStateTests._ctx(3, 2)
			finds = PickupStateTests._finds(["ph_weapon_a", "ph_relic_a", "ph_charm_a"])
		"C3":
			ctx = PickupStateTests._ctx(2, 4)
			ItemPacksTests._hold(ctx, 1)
			finds = PickupStateTests._finds(["ph_weapon_a", "ph_relic_a"])
		"C4":
			ctx = PickupStateTests._ctx(3, 3)
			ItemPacksTests._hold(ctx, 1)
			finds = PickupStateTests._finds(["ph_weapon_a", "ph_relic_a", "ph_charm_a"])
		"C5":
			ctx = PickupStateTests._ctx(2, 2)
			ItemPacksTests._hold(ctx, 2)
			finds = PickupStateTests._finds(["ph_charm_a", "ph_relic_a"])
		"twins":
			ctx = PickupStateTests._ctx(1, 2)
			ItemPacksTests._hold(ctx, 2)
			finds = PickupStateTests._finds(["ph_weapon_a"])
		_:
			ctx = PickupStateTests._ctx(2, 4)
			(ctx.save_data["sanctum"]["roster"][2] as Dictionary)["emotion"] = { "morale_current": 50, "fear_current": 95 }
			fallen = ["e0", "e1", "e3", "e4"]
			finds = PickupStateTests._finds(["ph_weapon_a", "ph_relic_a"])
	if ranks:
		var roster: Array = ctx.save_data["sanctum"]["roster"]
		for i in roster.size():
			(roster[i] as Dictionary)["rank"] = i + 2
	var rec := PickupStateTests._open(ctx, finds, "S", fallen)
	return { "ctx": ctx, "rec": rec }


static func _build(ctx: FlowContext, session: Dictionary = {}) -> Dictionary:
	return PickupSnapshotBuilder.build(ctx, 5, session)


static func _keys(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k


static func _has_null(v: Variant) -> bool:
	if v == null:
		return true
	if v is Dictionary:
		for k in (v as Dictionary):
			if _has_null((v as Dictionary)[k]):
				return true
	elif v is Array:
		for x in (v as Array):
			if _has_null(x):
				return true
	return false


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_shape() -> Dictionary:
	var m: Array = []
	var want := { "C1": ["C1", "plus"], "C2": ["C2", "none"], "C3": ["C3", "plus"], "C4": ["C4", "none"],
		"C5": ["C5", "minus"], "frozen": ["frozen", "none"] }
	for kind in want:
		var ev := _event(kind)
		if ev["rec"].is_empty():
			m.append("%s: no event opened" % kind)
			continue
		var snap := _build(ev["ctx"])
		var d: Dictionary = snap["data"]
		var w: Array = want[kind]
		if str(snap["type"]) != "flow.pickup" or str(snap["type"]) != FlowStateIds.PICKUP:
			m.append("%s: type %s" % [kind, snap["type"]])
		if str(_keys(snap)) != str(["actions", "data", "meta", "type"]):
			m.append("%s: top keys %s" % [kind, str(_keys(snap))])
		if str(_keys(d)) != str(_DATA_KEYS):
			m.append("%s: data keys %s" % [kind, str(_keys(d))])
		if str(d["case"]) != w[0] or str(d["reaction"]) != w[1] or str(d["phase"]) != "idle":
			m.append("%s: case %s reaction %s phase %s" % [kind, d["case"], d["reaction"], d["phase"]])
		var counts := { "taken": 0, "tried": 0, "left": 0, "lost": 0 }
		for f: Dictionary in d["finds"]:
			counts[str(f["status"])] += 1
		var rec: Dictionary = ev["rec"]
		if counts["taken"] != (rec["taken"] as Array).size() or counts["tried"] != (0 if str(rec["tried"]).is_empty() else 1):
			m.append("%s: status counts %s against record taken %s tried '%s'" % [kind, str(counts), str(rec["taken"]), rec["tried"]])
		if kind == "frozen" and (counts["lost"] != 2 or bool(d["frozen"]) == false or str(d["reason"]) != "froze"):
			m.append("frozen: counts %s frozen %s reason %s" % [str(counts), d["frozen"], d["reason"]])
		if kind != "frozen" and counts["lost"] != 0:
			m.append("%s: a find is lost without a freeze" % kind)
		if counts["taken"] + counts["tried"] + counts["left"] + counts["lost"] != (d["finds"] as Array).size():
			m.append("%s: a find has an unknown status" % kind)
		for f: Dictionary in d["finds"]:
			for k in ["find_id", "type_id", "name", "kind", "grade", "quantity", "cell", "tile", "status", "revealed", "pick_index"]:
				if not f.has(k):
					m.append("%s: find row misses %s" % [kind, k])
		var pk: Dictionary = d["pack"]
		if str(_keys(pk)) != str(["capacity", "carried", "free", "slots", "tone", "tone_before"]):
			m.append("%s: pack keys %s" % [kind, str(_keys(pk))])
		var gathered := (pk["slots"] as Array).filter(func(s): return str(s["source"]) == "gathered").size()
		if gathered != counts["taken"]:
			m.append("%s: %d gathered pack slots for %d taken finds" % [kind, gathered, counts["taken"]])
	return _result(m)


static func _t_actions() -> Dictionary:
	var m: Array = []
	var ev := _event("C5")
	var ctx: FlowContext = ev["ctx"]
	var origin := ""
	var target := ""
	var d0: Dictionary = _build(ctx)["data"]
	for fid in (d0["swap"]["targets"] as Dictionary):
		origin = str(fid)
		target = str((d0["swap"]["targets"][fid] as Array)[0])
		break
	var cases := [
		["intro", { "phase": "intro" }, ["overlay.skip"]],
		["idle", {}, ["cta.continue", "cta.swap"]],
		["swap_pick", { "phase": "swap_pick", "swap_origin": origin }, ["back"]],
		["swap_preview", { "phase": "swap_preview", "swap_origin": origin, "swap_target": target }, ["back", "cta.confirm"]],
	]
	for c in cases:
		var snap := _build(ctx, c[1])
		var keys := _keys(snap["actions"])
		if str(keys) != str(c[2]) or str(snap["data"]["phase"]) != str(c[0]):
			m.append("%s: phase %s, actions %s, expected %s" % [c[0], snap["data"]["phase"], str(keys), str(c[2])])
		if (snap["actions"] as Dictionary).has("nav.back"):
			m.append("%s: nav.back present" % c[0])
		for slot in snap["actions"]:
			if str(snap["actions"][slot].get("slot", "")) != str(slot):
				m.append("%s: action slot field differs from its key %s" % [c[0], slot])
			if str(snap["actions"][slot].get("type", "")) != str(_ACTION_TYPES[slot]):
				m.append("%s: slot %s has type '%s', expected '%s'" % [c[0], slot, snap["actions"][slot].get("type"), _ACTION_TYPES[slot]])
	# Not offered: no cta.swap in idle (room left; frozen).
	for kind in ["C1", "frozen"]:
		var keys := _keys(_build(_event(kind)["ctx"])["actions"])
		if str(keys) != str(["cta.continue"]):
			m.append("%s idle: actions %s" % [kind, str(keys)])
	return _result(m)


static func _t_revealed() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C4")["ctx"]
	for c in [["intro", false], ["idle", true]]:
		var d: Dictionary = _build(ctx, { "phase": c[0] })["data"]
		for f: Dictionary in d["finds"]:
			if bool(f["revealed"]) != c[1]:
				m.append("%s: find %s revealed %s" % [c[0], f["find_id"], f["revealed"]])
	# Statuses do not depend on the phase.
	if str((_build(ctx, { "phase": "intro" })["data"]["finds"] as Array).map(func(f): return f["status"])) \
			!= str((_build(ctx)["data"]["finds"] as Array).map(func(f): return f["status"])):
		m.append("the status of a find changed with the phase")
	return _result(m)


static func _t_tone() -> Dictionary:
	var m: Array = []
	for c in [["C1", "plain", 2, 2], ["C3", "near", 3, 1], ["C5", "full", 2, 0], ["C4", "full", 3, 0]]:
		var pk: Dictionary = _build(_event(c[0])["ctx"])["data"]["pack"]
		if str(pk["tone"]) != c[1] or int(pk["carried"]) != c[2] or int(pk["free"]) != c[3] or int(pk["capacity"]) != c[2] + c[3]:
			m.append("%s: tone %s carried %s free %s capacity %s, expected %s" % [c[0], pk["tone"], pk["carried"],
				pk["free"], pk["capacity"], str(c)])
	return _result(m)


## `tone_before` counts only what was carried before the event, with the same `warn_pack_free_at` rule.
static func _t_tone_before() -> Dictionary:
	var m: Array = []
	# Nothing held, two finds fill a pack of two: tone full, tone_before plain.
	var a: Dictionary = _build(_event("C2")["ctx"])["data"]["pack"]
	if str(a["tone"]) != "full" or str(a["tone_before"]) != "plain":
		m.append("empty before, full after: tone %s tone_before %s" % [a["tone"], a["tone_before"]])
	# Three held in a pack of four, one find: one free slot before (near), full after.
	var ctx: FlowContext = PickupStateTests._ctx(1, 4)
	ItemPacksTests._hold(ctx, 3)
	PickupStateTests._open(ctx, PickupStateTests._finds(["ph_weapon_a"]), "S", [])
	var b: Dictionary = _build(ctx)["data"]["pack"]
	if str(b["tone"]) != "full" or str(b["tone_before"]) != "near":
		m.append("one free before: tone %s tone_before %s" % [b["tone"], b["tone_before"]])
	# Two held in a pack of four, two finds: two free before. Plain at warn 1, near at warn 2.
	for c in [[1, "plain"], [2, "near"]]:
		var ctx2: FlowContext = PickupStateTests._ctx(2, 4)
		ItemPacksTests._hold(ctx2, 2)
		var inv: Dictionary = ConfigService.get_inventory_cfg(ctx2.config_service).duplicate(true)
		inv["warn_pack_free_at"] = c[0]
		ctx2.config_service.set("inv", inv)
		PickupStateTests._open(ctx2, PickupStateTests._finds(["ph_weapon_a", "ph_relic_a"]), "S", [])
		var pk: Dictionary = _build(ctx2)["data"]["pack"]
		if str(pk["tone_before"]) != c[1]:
			m.append("warn_pack_free_at %d: tone_before %s, expected %s" % [c[0], pk["tone_before"], c[1]])
	return _result(m)


static func _t_swap_keys() -> Dictionary:
	var m: Array = []
	var ev := _event("C5")
	var ctx: FlowContext = ev["ctx"]
	var sw: Dictionary = _build(ctx)["data"]["swap"]
	if not bool(sw["offered"]) or str(sw["reason_key"]) != "" or bool(sw["spent"]):
		m.append("C5 swap %s" % str(sw))
	var held: Array = _build(ctx)["data"]["pack"]["slots"]
	var held_ids := held.map(func(s): return str(s["id"]))
	if str(_keys(sw["targets"])) != str(_sorted((ev["rec"]["left"] as Array) + held_ids)):
		m.append("targets keyed %s, left %s, pack %s" % [str(_keys(sw["targets"])), str(ev["rec"]["left"]), str(held_ids)])
	for key in sw["targets"]:
		for other in sw["targets"][key]:
			var key_is_find: bool = (ev["rec"]["left"] as Array).has(key)
			if key_is_find != held_ids.has(other) or not (sw["targets"][other] as Array).has(key):
				m.append("target %s of %s is on the wrong side or not mirrored" % [other, key])
	for kind in [["C1", "has_room"], ["frozen", "frozen"], ["twins", "same"]]:
		var s: Dictionary = _build(_event(kind[0])["ctx"])["data"]["swap"]
		if bool(s["offered"]) or str(s["reason_key"]) != kind[1] or not (s["targets"] as Dictionary).is_empty():
			m.append("%s: swap %s, expected refusal %s" % [kind[0], str(s), kind[1]])
	# After the one swap: spent, "used", the taken find sits in the pack as a gathered slot.
	var done := PickupEventService.commit_swap(ctx, "f1", "it.1", 11)
	var after := _build(ctx)
	var s2: Dictionary = after["data"]["swap"]
	if not bool(done["ok"]) or bool(s2["offered"]) or str(s2["reason_key"]) != "used" or not bool(s2["spent"]) \
			or int(after["data"]["swap_left"]) != 0:
		m.append("after the swap: %s, swap_left %s" % [str(s2), after["data"]["swap_left"]])
	if str(_keys(after["actions"])) != str(["cta.continue"]):
		m.append("after the swap: actions %s" % str(_keys(after["actions"])))
	var f1 := (after["data"]["finds"] as Array).filter(func(f): return str(f["find_id"]) == "f1")
	var slot1 := (after["data"]["pack"]["slots"] as Array).filter(func(s): return str(s["find_id"]) == "f1")
	if f1.size() != 1 or str(f1[0]["status"]) != "taken" or slot1.size() != 1 or str(slot1[0]["source"]) != "gathered":
		m.append("the swapped-in find: %s, slot %s" % [str(f1), str(slot1)])
	return _result(m)


static func _sorted(a: Array) -> Array:
	var b: Array = a.map(func(x): return str(x))
	b.sort()
	return b


static func _t_phase_fallback() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C5")["ctx"]
	var d0: Dictionary = _build(ctx)["data"]
	var origin := str((d0["swap"]["targets"] as Dictionary).keys()[0])
	var target := str((d0["swap"]["targets"][origin] as Array)[0])
	var checks := [
		["unknown phase", { "phase": "dance" }, "idle"],
		["swap_pick without origin", { "phase": "swap_pick" }, "idle"],
		["swap_pick with an unknown find", { "phase": "swap_pick", "swap_origin": "zz" }, "idle"],
		["preview without a target", { "phase": "swap_preview", "swap_origin": origin }, "swap_pick"],
		["preview with an illegal target", { "phase": "swap_preview", "swap_origin": origin, "swap_target": "zz" }, "swap_pick"],
		["preview ok", { "phase": "swap_preview", "swap_origin": origin, "swap_target": target }, "swap_preview"],
	]
	for c in checks:
		var got := str(_build(ctx, c[1])["data"]["phase"])
		if got != c[2]:
			m.append("%s: phase %s, expected %s" % [c[0], got, c[2]])
	for c in [["swap_pick with a session target", { "phase": "swap_pick", "swap_origin": origin, "swap_target": target }],
			["preview with an illegal target", { "phase": "swap_preview", "swap_origin": origin, "swap_target": "zz" }]]:
		var sw: Dictionary = _build(ctx, c[1])["data"]["swap"]
		if str(sw["target"]) != "" or str(sw["origin"]) != origin:
			m.append("%s: origin '%s' target '%s'" % [c[0], sw["origin"], sw["target"]])
	# Swap phases never survive a refused swap (the room case).
	var room: FlowContext = _event("C1")["ctx"]
	if str(_build(room, { "phase": "swap_pick", "swap_origin": "f0" })["data"]["phase"]) != "idle":
		m.append("a swap phase was kept in an event that offers no swap")
	# The preview carries its choice; twins of the origin are listed in a swap phase only.
	var pv: Dictionary = _build(ctx, { "phase": "swap_preview", "swap_origin": origin, "swap_target": target })["data"]["swap"]
	if str(pv["origin"]) != origin or str(pv["target"]) != target:
		m.append("preview origin/target %s" % str(pv))
	if str(d0["swap"]["origin"]) != "" or str(d0["swap"]["target"]) != "":
		m.append("idle snapshot carries an origin or target")
	return _result(m)


static func _t_tokens_and_directive() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C5")["ctx"]
	var d: Dictionary = _build(ctx)["data"]
	if int(d["swap_left"]) != 1 or int(d["destroy_left"]) != 1 or not bool(d["confirm_leave_items"]):
		m.append("start: swap_left %s destroy_left %s confirm %s (Scout Carefully is the default Directive)" % [
			d["swap_left"], d["destroy_left"], d["confirm_leave_items"]])
	InventoryRules.mark_discard_used(ctx)
	ctx.save_data["stage_context"] = { "active_directive_id": "directive.seek_signs" }
	var d2: Dictionary = _build(ctx)["data"]
	if int(d2["destroy_left"]) != 0 or bool(d2["confirm_leave_items"]) or int(d2["swap_left"]) != 1:
		m.append("after the discard and Seek Signs: destroy_left %s confirm %s swap_left %s" % [
			d2["destroy_left"], d2["confirm_leave_items"], d2["swap_left"]])
	return _result(m)


static func _t_row_chooser() -> Dictionary:
	var m: Array = []
	var ev := _event("C1", ["e1"])
	var ctx: FlowContext = ev["ctx"]
	var rec: Dictionary = ev["rec"]
	var d: Dictionary = _build(ctx)["data"]
	var ids: Array = (d["row"] as Array).map(func(r): return str(r["id"]))
	if str(ids) != str(["e0", "e2", "e3", "e4"]) or str(d["fallen"]) != str(["Echo 1"]):
		m.append("row %s fallen %s" % [str(ids), str(d["fallen"])])
	var ch: Dictionary = d["chooser"]
	if str(ch.get("id")) != str(rec["chooser"]) or str(ch.get("name")) != "Echo %s" % str(rec["chooser"]).trim_prefix("e"):
		m.append("chooser %s, record chooser %s" % [str(ch), rec["chooser"]])
	var flagged := (d["row"] as Array).filter(func(r): return bool(r["is_chooser"]))
	if flagged.size() != 1 or str(flagged[0]["id"]) != str(rec["chooser"]):
		m.append("chooser flags %s" % str(flagged))
	var party := SanctumService.get_party_actors_static(ctx.save_data)
	for r: Dictionary in d["row"]:
		for a: Dictionary in party:
			if str(a["id"]) == str(r["id"]) and (str(r["status"]) != EmotionStatusLean.status_of(a) or str(r["name"]) != str(a["name"])
					or int(r["standing"]) != int(a["rank"])):
				m.append("row %s: status/name/standing differ from the actor" % r["id"])
	if d.has("pointer"):
		m.append("the retired pointer plan is still published (D-77)")
	return _result(m)


static func _t_board() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C1")["ctx"]
	var d0: Dictionary = _build(ctx)["data"]
	var grid: Dictionary = ConfigService.get_balance_data(ctx.config_service).get("grid", {})
	if not (d0["actors"] as Array).is_empty() or int(d0["board_cols"]) != GridService.get_board_cols(grid) \
			or int(d0["board_rows"]) != GridService.get_board_rows(grid):
		m.append("no encounter: actors %s cols %s rows %s" % [str(d0["actors"]), d0["board_cols"], d0["board_rows"]])
	var ectx := EncounterContext.new()
	ectx.encounter_id = "enc.test"
	ectx.placement_seed = 77
	ectx.terrain = { "bounds": { "w": 7, "h": 5 }, "cells": [] }
	ectx.actors = [{ "id": "e0", "name": "Echo 0", "stats": { "max_hp": 10 }, "current_hp": 6, "faction": "echo",
		"grid_pos": { "col": 2, "row": 3 }, "is_dead": false, "_bark_line": "hello" }]
	ctx.encounter_ctx = ectx
	var d: Dictionary = _build(ctx)["data"]
	var a: Dictionary = (d["actors"] as Array)[0] if not (d["actors"] as Array).is_empty() else {}
	if int(d["board_cols"]) != 7 or int(d["board_rows"]) != 5 or int(d["placement_seed"]) != 77 \
			or str(d["encounter_id"]) != "enc.test" or str(d["terrain"].get("bounds")) != str({ "w": 7, "h": 5 }):
		m.append("board keys %s %s %s %s" % [d["board_cols"], d["board_rows"], d["placement_seed"], d["encounter_id"]])
	if a.get("id") != "e0" or int(a.get("hp", -1)) != 6 or str(a.get("grid_pos")) != str({ "col": 2, "row": 3 }):
		m.append("actor projection %s" % str(a))
	if str(a.get("bark_line", "x")) != "" or str((ectx.actors[0] as Dictionary)["_bark_line"]) != "hello":
		m.append("bark_line must be empty in the snapshot and untouched in the encounter")
	# After a reload there is no encounter context: the actors come from the held resolve snapshot.
	ctx.encounter_ctx = null
	ctx.last_snapshot = { "type": FlowStateIds.RESOLVE, "data": { "actors": [{ "id": "e9", "bark_line": "old" }] } }
	var d2: Dictionary = _build(ctx)["data"]
	if str(d2["actors"]) != str([{ "id": "e9", "bark_line": "" }]) \
			or str((ctx.last_snapshot["data"]["actors"][0] as Dictionary)["bark_line"]) != "old":
		m.append("reload actors %s; the held snapshot must stay unchanged" % str(d2["actors"]))
	return _result(m)


static func _t_pure() -> Dictionary:
	var m: Array = []
	for kind in ["C5", "frozen"]:
		var ev := _event(kind)
		var ctx: FlowContext = ev["ctx"]
		ctx.save_request = false
		ctx.save_request_reason = ""
		var stage_before := _norm(ItemPacksTests._stage(ctx))
		var save_before := _norm(ctx.save_data)
		var rec_before := _norm(PickupEventService.record_of(ItemPacksTests._stage(ctx)))
		var a := _build(ctx)
		var b := _build(ctx)
		for session in [{ "phase": "intro" }, { "phase": "swap_pick", "swap_origin": "f0" }]:
			_build(ctx, session)
		if _norm(a) != _norm(b):
			m.append("%s: two builds differ" % kind)
		if _norm(ctx.save_data) != save_before or _norm(ItemPacksTests._stage(ctx)) != stage_before \
				or _norm(PickupEventService.record_of(ItemPacksTests._stage(ctx))) != rec_before:
			m.append("%s: the build changed the save or the record" % kind)
		if ctx.save_request:
			m.append("%s: the build requested a save" % kind)
		# The snapshot is a copy: writing anywhere into it leaves the record and the save alone.
		_scribble(a)
		if _norm(ctx.save_data) != save_before:
			m.append("%s: writing into the snapshot changed the save" % kind)
		if _norm(PickupEventService.record_of(ItemPacksTests._stage(ctx))) != rec_before:
			m.append("%s: the snapshot aliases the record" % kind)
	return _result(m)


static func _scribble(v: Variant) -> void:
	if v is Dictionary:
		for k in (v as Dictionary).keys():
			_scribble((v as Dictionary)[k])
			if (v as Dictionary)[k] is String:
				(v as Dictionary)[k] = "zz"
		(v as Dictionary)["zz"] = 1
	elif v is Array:
		for i in (v as Array).size():
			_scribble((v as Array)[i])
			if (v as Array)[i] is String:
				(v as Array)[i] = "zz"
		(v as Array).append("zz")


static func _json_trip(ctx: FlowContext) -> void:
	ctx.save_data = JSON.parse_string(JSON.stringify(ctx.save_data))


static func _t_no_record() -> Dictionary:
	var m: Array = []
	var ctx := PickupStateTests._ctx(2, 4)
	var snap := _build(ctx)
	if str(snap["type"]) != FlowStateIds.PICKUP or str(snap["data"]) != str({ "error": "no_pickup_event" }) \
			or not (snap["actions"] as Dictionary).is_empty() or int(snap["meta"]["t"]) != 5:
		m.append("snapshot without a record: %s" % str(snap))
	return _result(m)


static func _t_valid() -> Dictionary:
	var m: Array = []
	var sm := FlowStateMachine.new()
	for kind in ["C1", "C5", "frozen"]:
		var snap := _build(_event(kind)["ctx"])
		# `_validate_snapshot` asserts on a broken snapshot; a valid one passes without a sound.
		sm._validate_snapshot(snap, StructuredLogger.new(), 5)
		if sm._contains_null(snap) or _has_null(snap):
			m.append("%s: the snapshot holds a null" % kind)
	sm._validate_snapshot(_build(PickupStateTests._ctx(2, 4)), StructuredLogger.new(), 5)
	return _result(m)


static func _t_mode() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C5")["ctx"]
	ctx.last_snapshot = _build(ctx)
	if InventoryRules.mode(ctx) != InventoryRules.MODE_NONE:
		m.append("mode in the event is '%s'" % InventoryRules.mode(ctx))
	if InventoryRules.move_block_reason(ctx) != "not_in_sanctum" or InventoryRules.discard_block_reason(ctx, InventoryService.BOX_PACK) != "not_in_sanctum":
		m.append("moves or discards are not refused in the event: '%s' '%s'" % [InventoryRules.move_block_reason(ctx),
			InventoryRules.discard_block_reason(ctx, InventoryService.BOX_PACK)])
	ctx.last_snapshot = { "type": FlowStateIds.STAGE_EXPLORE }
	if InventoryRules.mode(ctx) != InventoryRules.MODE_PATH:
		m.append("test setup: the path view is no longer MODE_PATH")
	return _result(m)


# ---------------------------------------------------------------------------
# Order, either-side swap, dropped item, ints, selection, reload board, details
# ---------------------------------------------------------------------------

static func _t_order() -> Dictionary:
	var m: Array = []
	for kind in ["C1", "C4", "C5", "frozen"]:
		var ev := _event(kind)
		var rec: Dictionary = ev["rec"]
		var d: Dictionary = _build(ev["ctx"])["data"]
		if str(d["order"]) != str(rec["order"]):
			m.append("%s: order %s, record %s" % [kind, str(d["order"]), str(rec["order"])])
		for f: Dictionary in d["finds"]:
			var want: int = (rec["taken"] as Array).find(f["find_id"])
			if int(f["pick_index"]) != want:
				m.append("%s: find %s pick_index %s, expected %d" % [kind, f["find_id"], f["pick_index"], want])
	return _result(m)


## Fixture: one weapon and one relic held, finds weapon (f0) and charm (f1), pack full.
static func _mixed() -> FlowContext:
	var ctx := PickupStateTests._ctx(2, 2)
	ItemPacksTests._hold(ctx, 1, 1, "ph_weapon_a")
	ItemPacksTests._hold(ctx, 1, 2, "ph_relic_a")
	PickupStateTests._open(ctx, PickupStateTests._finds(["ph_weapon_a", "ph_charm_a"]))
	return ctx


static func _t_both_sides() -> Dictionary:
	var m: Array = []
	var ctx := _mixed()
	var sw: Dictionary = _build(ctx)["data"]["swap"]
	var want := { "f0": ["it.2"], "f1": ["it.1", "it.2"], "it.1": ["f1"], "it.2": ["f0", "f1"] }
	if str(sw["targets"]) != str(want):
		m.append("targets %s, expected %s" % [str(sw["targets"]), str(want)])
	var cases := [
		["field origin f0", { "phase": "swap_pick", "swap_origin": "f0" }, "swap_pick", ["it.1"]],
		["pack origin it.1", { "phase": "swap_pick", "swap_origin": "it.1" }, "swap_pick", ["f0"]],
		["field origin f1 (no twin)", { "phase": "swap_pick", "swap_origin": "f1" }, "swap_pick", []],
		["pack origin it.2 (no twin)", { "phase": "swap_pick", "swap_origin": "it.2" }, "swap_pick", []],
		["pack origin, field target", { "phase": "swap_preview", "swap_origin": "it.2", "swap_target": "f0" }, "swap_preview", []],
		["field origin, pack target", { "phase": "swap_preview", "swap_origin": "f1", "swap_target": "it.1" }, "swap_preview", []],
		["pack origin, twin target", { "phase": "swap_preview", "swap_origin": "it.1", "swap_target": "f0" }, "swap_pick", ["f0"]],
		["field origin, twin target", { "phase": "swap_preview", "swap_origin": "f0", "swap_target": "it.1" }, "swap_pick", ["it.1"]],
		["no legal target", { "phase": "swap_pick", "swap_origin": "zz" }, "idle", []],
	]
	for c in cases:
		var d: Dictionary = _build(ctx, c[1])["data"]
		if str(d["phase"]) != c[2] or str(d["swap"]["twins"]) != str(c[3]):
			m.append("%s: phase %s twins %s, expected %s %s" % [c[0], d["phase"], str(d["swap"]["twins"]), c[2], str(c[3])])
		if c[2] == "swap_preview" and str(d["swap"]["target"]) != str(c[1]["swap_target"]):
			m.append("%s: target '%s'" % [c[0], d["swap"]["target"]])
		if c[2] == "swap_pick" and str(d["swap"]["target"]) != "":
			m.append("%s: a target in swap_pick" % c[0])
	# A pack origin whose only partner is a twin has no legal swap: it falls back to idle.
	var twin_only := PickupStateTests._ctx(1, 1)
	ItemPacksTests._hold(twin_only, 1, 1, "ph_weapon_a")
	PickupStateTests._open(twin_only, PickupStateTests._finds(["ph_weapon_a"]))
	if str(_build(twin_only, { "phase": "swap_pick", "swap_origin": "it.1" })["data"]["phase"]) != "idle":
		m.append("a swap from a twin-only pack item was kept")
	return _result(m)


static func _t_dropped() -> Dictionary:
	var m: Array = []
	var ctx := PickupStateTests._ctx(2, 2)
	ItemPacksTests._hold(ctx, 2, 1, "ph_armor_a")
	PickupStateTests._open(ctx, PickupStateTests._finds(["ph_charm_a", "ph_relic_a"]))
	if not (_build(ctx)["data"]["swap"]["dropped"] as Dictionary).is_empty():
		m.append("dropped before any swap")
	var inv_cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	var done := PickupEventService.commit_swap(ctx, "f1", "it.1", 11)
	var want := { "id": "it.1", "type_id": "ph_armor_a", "name": InventoryService.name_of(inv_cfg, "ph_armor_a"),
		"kind": InventoryServiceTests._kind_of("ph_armor_a"), "grade": "g1", "quantity": 1 }
	for round in ["live", "json"]:
		if round == "json":
			_json_trip(ctx)
		var d: Dictionary = _build(ctx)["data"]
		var got: Dictionary = d["swap"]["dropped"]
		if not bool(done["ok"]) or str(got) != str(want) or typeof(got.get("quantity")) != TYPE_INT:
			m.append("%s: dropped %s, expected %s" % [round, str(got), str(want)])
		if (d["pack"]["slots"] as Array).any(func(s): return str(s["id"]) == "it.1"):
			m.append("%s: the dropped piece is still a pack slot" % round)
	return _result(m)


static func _t_json_ints() -> Dictionary:
	var m: Array = []
	var ctx := PickupStateTests._ctx(2, 2)
	ItemPacksTests._hold(ctx, 2, 1, "ph_armor_a")
	PickupStateTests._open(ctx, PickupStateTests._finds(["ph_charm_a", "ph_relic_a"]))
	PickupEventService.commit_swap(ctx, "f1", "it.1", 11)
	InventoryRules.mark_discard_used(ctx)
	_json_trip(ctx)
	var d: Dictionary = _build(ctx)["data"]
	var ints: Array = []
	for k in ["run_count", "swap_left", "destroy_left", "board_cols", "board_rows", "placement_seed"]:
		ints.append([k, d[k]])
	ints.append(["pointer_look.path.path_slow_n", d["pointer_look"]["path"]["path_slow_n"]])
	ints.append(["pointer_look.mote.trail_count", d["pointer_look"]["mote"]["trail_count"]])
	for k in ["free", "capacity", "carried"]:
		ints.append(["pack." + k, d["pack"][k]])
	ints.append(["chooser.standing", d["chooser"]["standing"]])
	for r: Dictionary in d["row"]:
		ints.append(["row.standing", r["standing"]])
	for f: Dictionary in d["finds"]:
		for k in ["quantity", "cell", "pick_index"]:
			ints.append(["finds." + k, f[k]])
	for sl: Dictionary in d["pack"]["slots"]:
		for k in ["quantity", "mark_index"]:
			ints.append(["slot." + k, sl[k]])
	ints.append(["dropped.quantity", d["swap"]["dropped"]["quantity"]])
	for pair in ints:
		if typeof(pair[1]) != TYPE_INT:
			m.append("%s is type %d, not an int" % [pair[0], typeof(pair[1])])
	return _result(m)


static func _t_selected() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C3")["ctx"]
	var cases := [
		["a find", { "selected": "f0" }, { "id": "f0", "side": "find" }],
		["a pack item", { "selected": "it.1" }, { "id": "it.1", "side": "pack" }],
		["a gathered pack item", { "selected": "item:s0:f0" }, { "id": "item:s0:f0", "side": "pack" }],
		["an unknown id", { "selected": "zz" }, {}],
		["an empty id", { "selected": "" }, {}],
		["no key", {}, {}],
		["a hidden find in the intro", { "phase": "intro", "selected": "f0" }, {}],
		["a pack item in the intro", { "phase": "intro", "selected": "it.1" }, { "id": "it.1", "side": "pack" }],
	]
	for c in cases:
		var got: Variant = _build(ctx, c[1])["data"]["selected"]
		if str(got) != str(c[2]):
			m.append("%s: selected %s, expected %s" % [c[0], str(got), str(c[2])])
	return _result(m)


## The durable result is built by PendingResultService from a real capture, not by hand.
static func _capture_pending(ctx: FlowContext) -> String:
	# A real save always has `flow`; PendingResultService._flow_dict loses its write when the key is missing.
	ctx.save_data["flow"] = { "state": "flow.splash", "context": {}, "pending_result": {} }
	var snap := { "type": FlowStateIds.RESOLVE, "meta": { "t": 9 }, "actions": {}, "data": { "encounter_id": "enc.test",
		"victory": true, "objectives_remaining": 0, "reason": "", "round_ended": 3, "enemies_defeated": 2,
		"echoes_survived": 4, "objective_state": {}, "actors": [{ "id": "e0", "name": "Echo 0", "hp": 6, "max_hp": 10,
		"grid_pos": { "col": 2, "row": 3 }, "bark_line": "old" }] } }
	return PendingResultService.capture_or_consume(ctx, snap, 9)


static func _t_pending_board() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C1")["ctx"]
	var grid: Dictionary = ConfigService.get_balance_data(ctx.config_service).get("grid", {})
	if _capture_pending(ctx) != "captured":
		return { "ok": false, "error": "test setup: the pending result was not captured" }
	if not PendingResultService.has_pending(ctx.save_data):
		return { "ok": false, "error": "test setup: capture returned captured but the save holds no result" }
	# A rebuild after the event published: the held snapshot is a flow.pickup one, another resolve snapshot would be wrong.
	ctx.last_snapshot = _build(ctx)
	var cases := [["rebuild", false], ["reload", true]]
	for c in cases:
		if c[1]:
			_json_trip(ctx)
			ctx.last_snapshot = {}
		var d: Dictionary = _build(ctx)["data"]
		var actors: Array = d["actors"]
		if actors.size() != 1 or str(actors[0]["id"]) != "e0" or str(actors[0]["bark_line"]) != "":
			m.append("%s: actors %s" % [c[0], str(actors)])
		if str(d["encounter_id"]) != "enc.test":
			m.append("%s: encounter_id '%s'" % [c[0], d["encounter_id"]])
		if not (d["terrain"] as Dictionary).is_empty() or int(d["placement_seed"]) != 0 \
				or int(d["board_cols"]) != GridService.get_board_cols(grid):
			m.append("%s: terrain/placement/board size are not the documented defaults" % c[0])
	# The durable result wins over a held resolve snapshot.
	ctx.last_snapshot = { "type": FlowStateIds.RESOLVE, "data": { "actors": [{ "id": "e9" }] } }
	if str((_build(ctx)["data"]["actors"] as Array).map(func(a): return a["id"])) != str(["e0"]):
		m.append("a held resolve snapshot beat the durable result")
	# The durable result is not changed by the build.
	var before := _norm(PendingResultService.read(ctx.save_data))
	_build(ctx)
	if _norm(PendingResultService.read(ctx.save_data)) != before:
		m.append("the build changed the durable result")
	return _result(m)


static func _t_tried_and_slots() -> Dictionary:
	var m: Array = []
	var ev := _event("C4")
	var rec: Dictionary = ev["rec"]
	var d: Dictionary = _build(ev["ctx"])["data"]
	var tried := (d["finds"] as Array).filter(func(f): return str(f["status"]) == "tried")
	var want_id := str((rec["order"] as Array)[int(rec["free"])])
	if tried.size() != 1 or str(tried[0]["find_id"]) != want_id or str(tried[0]["find_id"]) != str(rec["tried"]):
		m.append("tried finds %s, expected only %s (the first find past the free slots in pick order)" % [str(tried), want_id])
	var lefts := (d["finds"] as Array).filter(func(f): return str(f["status"]) == "left")
	if not lefts.is_empty():
		m.append("C4 has %d plain left finds, expected none" % lefts.size())
	# Slot fields: a held piece, a stack and gathered rows.
	var ctx := PickupStateTests._ctx(2, 3)
	ItemPacksTests._hold(ctx, 1)
	ctx.save_data["inventory"]["pack_stacks"] = [{ "type_id": "ph_consumable_a", "kind": "consumable",
		"quantity": 3, "slot": 1 }]
	var rec2 := PickupStateTests._open(ctx, PickupStateTests._finds(["ph_charm_a"]))
	var cfg := ConfigService.get_inventory_cfg(ctx.config_service)
	var slots: Array = _build(ctx)["data"]["pack"]["slots"]
	var by_id := {}
	for sl: Dictionary in slots:
		by_id[str(sl["id"])] = sl
	var want := {
		"it.1": { "type_id": "ph_weapon_a", "name": InventoryService.name_of(cfg, "ph_weapon_a"), "kind": InventoryServiceTests._kind_of("ph_weapon_a"),
			"grade": "g1", "quantity": 1, "source": "held", "mark_index": InventoryService.mark_index_of(cfg, "it.1"), "find_id": "" },
		"stack:ph_consumable_a:1": { "type_id": "ph_consumable_a", "name": InventoryService.name_of(cfg, "ph_consumable_a"),
			"kind": "consumable", "grade": "", "quantity": 3, "source": "stack", "mark_index": -1, "find_id": "" },
		"item:s0:f0": { "type_id": "ph_charm_a", "name": InventoryService.name_of(cfg, "ph_charm_a"), "kind": InventoryServiceTests._kind_of("ph_charm_a"),
			"grade": str(((rec2["finds"] as Array)[0] as Dictionary)["grade"]), "quantity": 1, "source": "gathered", "mark_index": -1, "find_id": "f0" },
	}
	if by_id.size() != want.size():
		m.append("pack slot ids %s, expected %s" % [str(by_id.keys()), str(want.keys())])
	for id in want:
		if not by_id.has(id):
			m.append("pack slot %s is missing" % id)
			continue
		for k in want[id]:
			if str(by_id[id].get(k)) != str(want[id][k]):
				m.append("slot %s: %s is '%s', expected '%s'" % [id, k, by_id[id].get(k), want[id][k]])
	return _result(m)


static func _t_standing_meta() -> Dictionary:
	var m: Array = []
	var ev := _event("C1", [], true)
	var d: Dictionary = _build(ev["ctx"])["data"]
	var snap := _build(ev["ctx"])
	var rank := int(str(ev["rec"]["chooser"]).trim_prefix("e")) + 2
	if int(d["chooser"]["standing"]) != rank:
		m.append("chooser.standing %s, expected the roster rank %d" % [d["chooser"]["standing"], rank])
	for r: Dictionary in d["row"]:
		if int(r["standing"]) != int(str(r["id"]).trim_prefix("e")) + 2:
			m.append("row %s standing %s" % [r["id"], r["standing"]])
	if str(d["return_to"]) != FlowStateIds.STAGE_EXPLORE or int(snap["meta"]["t"]) != 5:
		m.append("return_to '%s', meta %s" % [d["return_to"], str(snap["meta"])])
	return _result(m)


static func _t_context_untouched() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = _event("C5")["ctx"]
	var ectx := EncounterContext.new()
	ectx.terrain = { "bounds": { "w": 7, "h": 5 }, "cells": [{ "c": 1 }] }
	ctx.encounter_ctx = ectx
	ctx.last_snapshot = { "type": "flow.encounter", "data": { "x": [1, 2] }, "meta": { "t": 1 }, "actions": {} }
	var before := _norm(ctx.last_snapshot)
	var session_before: Variant = ctx.get("pickup_session")
	var fields_before := [ctx.realm_id, ctx.stage_id, ctx.save_request, ctx.save_request_reason, ctx.encounter_ctx, _norm(ectx.actors)]
	var snap := _build(ctx, { "phase": "swap_pick", "swap_origin": "f0" })
	(snap["data"]["terrain"]["bounds"] as Dictionary)["w"] = 99
	(snap["data"]["terrain"]["cells"] as Array).append("zz")
	if str(ectx.terrain) != str({ "bounds": { "w": 7, "h": 5 }, "cells": [{ "c": 1 }] }):
		m.append("the terrain of the snapshot aliases the encounter terrain")
	if _norm(ctx.last_snapshot) != before or str(ctx.get("pickup_session")) != str(session_before):
		m.append("the build changed last_snapshot or pickup_session")
	if str([ctx.realm_id, ctx.stage_id, ctx.save_request, ctx.save_request_reason, ctx.encounter_ctx, _norm(ectx.actors)]) != str(fields_before):
		m.append("the build changed another FlowContext field")
	return _result(m)
