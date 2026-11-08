# res://tests/InventoryMoveTests.gd
# Slots, moves, merges and count discards of InventoryService (container work only; the action path and the path
# rules are in InventoryPathTests). Tests use their own cfg (InventoryServiceTests._cfg) and the placeholder
# fixture, never the shipping sizes.

class_name InventoryMoveTests
extends RefCounted


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_moves/intake_takes_the_lowest_free_slot", Callable(InventoryMoveTests, "_t_first_free"))
	runner.register_test("inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full", Callable(InventoryMoveTests, "_t_stack_to_pack"))
	runner.register_test("inventory_moves/pack_only_intake_never_touches_the_sanctum", Callable(InventoryMoveTests, "_t_pack_only"))
	runner.register_test("inventory_moves/validate_checks_slots", Callable(InventoryMoveTests, "_t_validate_slots"))
	runner.register_test("inventory_moves/entries_without_a_slot_and_a_resized_container", Callable(InventoryMoveTests, "_t_resize"))
	runner.register_test("inventory_moves/move_both_ways_with_and_without_a_slot", Callable(InventoryMoveTests, "_t_move"))
	runner.register_test("inventory_moves/reorder_into_an_empty_slot_never_swaps", Callable(InventoryMoveTests, "_t_reorder"))
	runner.register_test("inventory_moves/merge_exact_partial_limit_and_mismatch", Callable(InventoryMoveTests, "_t_merge"))
	runner.register_test("inventory_moves/refusals_change_nothing_and_name_the_reason", Callable(InventoryMoveTests, "_t_refusals"))
	runner.register_test("inventory_moves/discard_entry_takes_a_count_for_stacks_only", Callable(InventoryMoveTests, "_t_discard_entry"))
	runner.register_test("inventory_moves/moves_never_mint_or_destroy_an_item", Callable(InventoryMoveTests, "_t_conservation"))
	runner.register_test("inventory_moves/held_stacks_are_settled_like_held_pieces", Callable(InventoryMoveTests, "_t_held_stacks"))
	runner.register_test("inventory_moves/rows_carry_name_slot_and_the_container_sizes", Callable(InventoryMoveTests, "_t_snapshot_rows"))
	runner.register_test("inventory_moves/a_json_round_trip_keeps_slots_and_moves", Callable(InventoryMoveTests, "_t_round_trip"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _result(m: Array) -> Dictionary:
	return InventoryServiceTests._result(m)


static func _json(v: Variant) -> String:
	return InventoryServiceTests._json(v)


static func _expect(m: Array, res: Dictionary, result: String, reason: String, what: String) -> void:
	InventoryServiceTests._expect(m, res, result, reason, what)


## Slots of the rows in a snapshot list, in list order.
static func _slots(snap: Dictionary, key: String) -> Array:
	return (snap[key] as Array).map(func(r): return int(r["slot"]))


static func _put(save: Dictionary, cfg: Dictionary, type_id: String, qty: int = 1) -> Dictionary:
	return InventoryService.intake(save, cfg, InventoryServiceTests._e(type_id, qty), "direct")


static func _mv(save: Dictionary, cfg: Dictionary, from_box: String, from_slot: int, to_box: String, to_slot: int = -1) -> Dictionary:
	return InventoryService.move_entry(save, cfg, from_box, from_slot, to_box, to_slot)


## Every piece id in both containers, sorted, and the quantity per stack type over all four arrays.
static func _census(save: Dictionary) -> String:
	var ids: Array = InventoryServiceTests._ids(save, "items") + InventoryServiceTests._ids(save, "pack")
	ids.sort()
	var qty := {}
	for key in ["stacks", "pack_stacks"]:
		for s in (save["inventory"] as Dictionary).get(key, []):
			qty[s["type_id"]] = int(qty.get(s["type_id"], 0)) + int(s["quantity"])
	return _json([ids, qty])


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_first_free() -> Dictionary:
	var m: Array = []
	var save := InventoryServiceTests._fresh()
	var cfg := InventoryServiceTests._cfg(5, 3)
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_charm_a")
	_put(save, cfg, "ph_material_a", 2)
	_put(save, cfg, "ph_relic_a")
	var snap := InventoryService.snapshot(save, cfg)
	if _slots(snap, "items") != [0, 1, 3] or _slots(snap, "stacks") != [2]:
		m.append("fresh slots: items %s stacks %s" % [str(_slots(snap, "items")), str(_slots(snap, "stacks"))])
	# A gap is refilled before the end: discard the piece in slot 1, the next piece takes it.
	InventoryService.discard(save, cfg, "it.2", true)
	_put(save, cfg, "ph_armor_a")
	snap = InventoryService.snapshot(save, cfg)
	if _slots(snap, "items") != [0, 3, 1]:
		m.append("the gap was not refilled: %s" % str(_slots(snap, "items")))
	# The pack numbers its own slots from 0.
	_put(save, cfg, "ph_charm_a")
	_expect(m, _put(save, cfg, "ph_charm_a"), "packed", "to_pack", "second piece to the pack")
	if _slots(InventoryService.snapshot(save, cfg), "pack") != [0]:
		m.append("pack slots %s" % str(_slots(InventoryService.snapshot(save, cfg), "pack")))
	# A stack takes a slot of the Sanctum only when it is new; a merge needs none.
	var full := InventoryServiceTests._fresh()
	var cfg2 := InventoryServiceTests._cfg(2, 1)
	_put(full, cfg2, "ph_material_a", 1)
	_put(full, cfg2, "ph_weapon_a")
	_expect(m, _put(full, cfg2, "ph_material_a", 2), "stored", "ok", "merge into the full Sanctum")
	_expect(m, _put(full, cfg2, "ph_consumable_a", 1), "packed", "to_pack", "new stack, Sanctum full, free pack slot")
	_expect(m, _put(full, cfg2, "ph_consumable_a", 1), "packed", "to_pack", "merge into the pack stack")
	_expect(m, _put(full, cfg2, "ph_consumable_a", 3), "partial", "overflow", "pack stack takes 1, the rest finds no slot")
	_expect(m, _put(full, cfg2, "ph_consumable_a", 1), "lost", "overflow", "Sanctum and pack full")
	if InventoryService.sanctum_used(full) != 2 or int(full["inventory"]["stacks"][0]["quantity"]) != 3 \
			or (full["inventory"]["pack_stacks"] as Array).size() != 1 or int(full["inventory"]["pack_stacks"][0]["slot"]) != 0 \
			or int(full["inventory"]["pack_stacks"][0]["quantity"]) != 3:
		m.append("full Sanctum: %s" % _json(full["inventory"]))
	return _result(m)


## D-45: a stack find fills, in order: 1) a same-type Sanctum stack with room, 2) new Sanctum stacks, 3) a same-type
## pack stack with room, 4) new pack stacks, 5) the rest is lost, always as `overflow` (D-46). Stored plus lost
## is the find quantity. Consumables stop at 3 (the fixture), materials at 5 (the cfg).
static func _t_stack_to_pack() -> Dictionary:
	var m: Array = []
	var cons := "ph_consumable_a"
	# F2-01: the Sanctum stack is at its limit and slots are free: the find starts a new Sanctum stack, nothing is lost.
	var a := InventoryServiceTests._fresh()
	var cfg_a := InventoryServiceTests._cfg(4, 4)
	_put(a, cfg_a, cons, 3)
	var r := _put(a, cfg_a, cons, 2)
	_expect(m, r, "stored", "ok", "Sanctum stack at its limit, free slots")
	if (a["inventory"]["stacks"] as Array).size() != 2 or int(a["inventory"]["stacks"][1]["quantity"]) != 2 \
			or not (a["inventory"].get("pack_stacks", []) as Array).is_empty() or int(r["lost_quantity"]) != 0:
		m.append("new Sanctum stack: %s / %s" % [_json(r), _json(a["inventory"])])
	# Multi-step: 1 merges, then a new Sanctum stack, then the rest spills into a new pack stack.
	var b := InventoryServiceTests._fresh()
	var cfg_b := InventoryServiceTests._cfg(2, 2)
	_put(b, cfg_b, cons, 2)
	var census := _census(b)
	r = _put(b, cfg_b, cons, 7)
	_expect(m, r, "packed", "to_pack", "merge, new Sanctum stack, pack stack")
	var sq: Array = (b["inventory"]["stacks"] as Array).map(func(s): return int(s["quantity"]))
	var pq: Array = (b["inventory"]["pack_stacks"] as Array).map(func(s): return int(s["quantity"]))
	if sq != [3, 3] or pq != [3] or int(r["quantity"]) != 7 or int(r["lost_quantity"]) != 0:
		m.append("multi-step: Sanctum %s pack %s result %s" % [str(sq), str(pq), _json(r)])
	if _census(b) == census:
		m.append("the multi-step find changed nothing")
	if not InventoryService.validate(b, cfg_b).is_empty():
		m.append("multi-step validate: %s" % str(InventoryService.validate(b, cfg_b)))
	# F2-02: a find merges into a same-type PACK stack with room before it takes a new pack slot.
	var c := InventoryServiceTests._fresh()
	var cfg_c := InventoryServiceTests._cfg(1, 2)
	_put(c, cfg_c, "ph_weapon_a")
	_expect(m, _put(c, cfg_c, cons, 2), "packed", "to_pack", "first pack stack")
	_expect(m, _put(c, cfg_c, cons, 1), "packed", "to_pack", "merge into the pack stack")
	if (c["inventory"]["pack_stacks"] as Array).size() != 1 or int(c["inventory"]["pack_stacks"][0]["quantity"]) != 3:
		m.append("pack merge: %s" % _json(c["inventory"]))
	_expect(m, _put(c, cfg_c, cons, 2), "packed", "to_pack", "full pack stack: a new pack stack")
	if (c["inventory"]["pack_stacks"] as Array).size() != 2:
		m.append("the second pack stack is missing: %s" % _json(c["inventory"]))
	# Both full: lost as overflow, nothing changes.
	var d := InventoryServiceTests._fresh()
	var cfg_d := InventoryServiceTests._cfg(1, 1)
	_put(d, cfg_d, "ph_weapon_a")
	_put(d, cfg_d, cons, 3)
	var before := _json(d)
	_expect(m, _put(d, cfg_d, cons, 1), "lost", "overflow", "both full")
	if _json(d) != before:
		m.append("a lost stack changed the save")
	# Above the limit with no slot left for the rest: overflow (D-46), the part that fits is kept.
	var e := InventoryServiceTests._fresh()
	var cfg_e := InventoryServiceTests._cfg(1, 2)
	_put(e, cfg_e, "ph_weapon_a")
	r = _put(e, cfg_e, cons, 8)
	_expect(m, r, "partial", "overflow", "8 against a limit of 3 and two pack slots")
	if int(r["quantity"]) + int(r["lost_quantity"]) != 8 or int(r["quantity"]) != 6 or (e["inventory"]["pack_stacks"] as Array).size() != 2:
		m.append("limit spill: %s / %s" % [_json(r), _json(e["inventory"])])
	# Mode difference. Pack of 1 slot, full: direct is lost; gathered owns a slot and goes ONE slot above the size.
	var f := InventoryServiceTests._fresh()
	var cfg_f := InventoryServiceTests._cfg(1, 1)
	_put(f, cfg_f, "ph_weapon_a")
	_put(f, cfg_f, "ph_relic_a")
	_expect(m, _put(f, cfg_f, cons, 1), "lost", "overflow", "direct, pack full")
	var g := f.duplicate(true)
	r = InventoryService.intake(g, cfg_f, InventoryServiceTests._e(cons, 8), "pack_only")
	_expect(m, r, "partial", "overflow", "pack_only, pack full: one stack above the size")
	var gp: Array = g["inventory"].get("pack_stacks", [])
	if gp.size() != 1 or int(gp[0]["slot"]) < 1 or int(r["quantity"]) != 3:
		m.append("gathered fallback: %s / %s" % [_json(r), _json(g["inventory"])])
	# Pack slots reserved by open item rows: direct cannot use them, gathered owns one.
	var h := InventoryServiceTests._fresh()
	_put(h, cfg_f, "ph_weapon_a")
	before = _json(h)
	_expect(m, InventoryService.intake(h, cfg_f, InventoryServiceTests._e(cons, 1), "direct", 1), "lost", "overflow", "direct, the last slot is reserved")
	if _json(h) != before:
		m.append("a direct stack took a reserved slot")
	_expect(m, InventoryService.intake(h, cfg_f, InventoryServiceTests._e(cons, 1), "pack_only", 1), "stored", "ok", "pack_only, reserved slot")
	return _result(m)


## D-49: mode `pack_only` (a find at a path end or a kept leave) puts a piece or a stack in the pack, never in the
## Sanctum, also when the Sanctum is empty. `direct` keeps its Sanctum-first order.
static func _t_pack_only() -> Dictionary:
	var m: Array = []
	var cons := "ph_consumable_a"
	for sanctum_state in ["empty", "full"]:
		var save := InventoryServiceTests._fresh()
		var cfg := InventoryServiceTests._cfg(2, 4)
		if sanctum_state == "full":
			_put(save, cfg, "ph_weapon_a")
			_put(save, cfg, "ph_charm_a")
		var before_sanctum := _json([save["inventory"]["items"], save["inventory"]["stacks"]])
		var r := InventoryService.intake(save, cfg, InventoryServiceTests._e("ph_relic_a"), "pack_only", 0)
		_expect(m, r, "stored", "ok", "piece, %s Sanctum" % sanctum_state)
		if InventoryService.locate_piece(save, str(r["item_id"])).get("box", "") != "pack":
			m.append("%s: the piece is not in the pack" % sanctum_state)
		var rs := InventoryService.intake(save, cfg, InventoryServiceTests._e(cons, 5), "pack_only", 0)
		_expect(m, rs, "stored", "ok", "stack, %s Sanctum" % sanctum_state)
		var pq: Array = (save["inventory"]["pack_stacks"] as Array).map(func(st): return int(st["quantity"]))
		if pq != [3, 2] or int(rs["quantity"]) + int(rs["lost_quantity"]) != 5:
			m.append("%s: pack stacks %s, result %s" % [sanctum_state, str(pq), _json(rs)])
		# A second find merges into the pack stack with room.
		InventoryService.intake(save, cfg, InventoryServiceTests._e(cons, 1), "pack_only", 0)
		pq = (save["inventory"]["pack_stacks"] as Array).map(func(st): return int(st["quantity"]))
		if pq != [3, 3]:
			m.append("%s: no pack merge: %s" % [sanctum_state, str(pq)])
		if _json([save["inventory"]["items"], save["inventory"]["stacks"]]) != before_sanctum and sanctum_state == "empty":
			m.append("empty: the Sanctum was touched")
		if sanctum_state == "full" and _json([save["inventory"]["items"], save["inventory"]["stacks"]]) != before_sanctum:
			m.append("full: the Sanctum was touched")
		if not InventoryService.validate(save, cfg).is_empty():
			m.append("%s: validate %s" % [sanctum_state, str(InventoryService.validate(save, cfg))])
	# What no free pack slot can hold is lost as overflow; the later-rows rule (reserved) holds slots back.
	var tight := InventoryServiceTests._fresh()
	var cfg_t := InventoryServiceTests._cfg(4, 2)
	var r2 := InventoryService.intake(tight, cfg_t, InventoryServiceTests._e(cons, 9), "pack_only", 1)
	_expect(m, r2, "partial", "overflow", "9 against a limit of 3 and one free slot after the held one")
	if int(r2["quantity"]) != 3 or int(r2["lost_quantity"]) != 6 or not (tight["inventory"]["stacks"] as Array).is_empty():
		m.append("tight pack: %s / %s" % [_json(r2), _json(tight["inventory"])])
	# `direct` (the debug producer) keeps the Sanctum first.
	var sv := InventoryServiceTests._fresh()
	var rr := InventoryService.intake(sv, InventoryServiceTests._cfg(2, 2), InventoryServiceTests._e("ph_relic_a"), "direct", 0)
	if InventoryService.locate_piece(sv, str(rr["item_id"])).get("box", "") != "sanctum":
		m.append("direct: no longer Sanctum first")
	return _result(m)


static func _t_validate_slots() -> Dictionary:
	var m: Array = []
	var save := InventoryServiceTests._fresh()
	var cfg := InventoryServiceTests._cfg(4, 2)
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_charm_a")
	_put(save, cfg, "ph_material_a", 1)
	if not InventoryService.validate(save, cfg).is_empty():
		m.append("a clean save: %s" % str(InventoryService.validate(save, cfg)))
	var inv: Dictionary = save["inventory"]
	(inv["items"][1] as Dictionary)["slot"] = 0
	if InventoryService.validate(save, cfg) != ["items[1]: slot 0 used twice"]:
		m.append("two entries in one slot: %s" % str(InventoryService.validate(save, cfg)))
	(inv["items"][1] as Dictionary)["slot"] = 1
	(inv["stacks"][0] as Dictionary)["slot"] = 0
	if InventoryService.validate(save, cfg) != ["stacks[0]: slot 0 used twice"]:
		m.append("a stack on a piece slot: %s" % str(InventoryService.validate(save, cfg)))
	(inv["stacks"][0] as Dictionary)["slot"] = 4
	if InventoryService.validate(save, cfg) != ["stacks[0]: slot 4 at or above the size 4"]:
		m.append("slot out of range: %s" % str(InventoryService.validate(save, cfg)))
	(inv["stacks"][0] as Dictionary)["slot"] = -1
	if InventoryService.validate(save, cfg) != ["stacks[0]: missing or invalid slot"]:
		m.append("negative slot: %s" % str(InventoryService.validate(save, cfg)))
	(inv["stacks"][0] as Dictionary)["slot"] = "x"
	if InventoryService.validate(save, cfg) != ["stacks[0]: missing or invalid slot"]:
		m.append("text slot: %s" % str(InventoryService.validate(save, cfg)))
	(inv["stacks"][0] as Dictionary)["slot"] = 2.0
	if not InventoryService.validate(save, cfg).is_empty():
		m.append("a whole float slot (JSON) is valid: %s" % str(InventoryService.validate(save, cfg)))
	# The pack is validated against its own size.
	(inv["pack"] as Array).append({ "id": "it.9", "type_id": "ph_relic_a", "kind": "relic", "grade": "g1", "held_by": "", "slot": 2 })
	inv["next_seq"] = 10
	if InventoryService.validate(save, cfg) != ["pack[0]: slot 2 at or above the size 2"]:
		m.append("pack slot out of range: %s" % str(InventoryService.validate(save, cfg)))
	return _result(m)


## Tolerant read (not a shrink rule; D-41 defers it). An entry without a valid slot reads as the lowest free
## slot and gets it at the next mutation. A stored slot at or above the size is kept; new entries use slots
## below the size only.
static func _t_resize() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(5, 2)
	var save := InventoryServiceTests._fresh()
	var inv: Dictionary = save["inventory"]
	inv["items"] = [
		{ "id": "it.1", "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1", "held_by": "" },
		{ "id": "it.2", "type_id": "ph_charm_a", "kind": "gear", "grade": "g1", "held_by": "", "slot": 0 },
	]
	inv["stacks"] = [{ "type_id": "ph_material_a", "kind": "material", "quantity": 2 }]
	inv["next_seq"] = 3
	var before := _json(save)
	var snap := InventoryService.snapshot(save, cfg)
	if _slots(snap, "items") != [1, 0] or _slots(snap, "stacks") != [2]:
		m.append("slotless read: items %s stacks %s" % [str(_slots(snap, "items")), str(_slots(snap, "stacks"))])
	if _json(save) != before:
		m.append("a read changed the save")
	_put(save, cfg, "ph_relic_a")
	if int(inv["items"][0]["slot"]) != 1 or int(inv["stacks"][0]["slot"]) != 2 or int(inv["items"][2]["slot"]) != 3:
		m.append("the mutation did not store the read slots: %s" % _json(inv))
	# Growth: a larger size adds slots and moves nothing.
	var grown := InventoryServiceTests._cfg(8, 2)
	_put(save, grown, "ph_armor_a")
	if int(inv["items"][3]["slot"]) != 4 or not InventoryService.validate(save, grown).is_empty():
		m.append("growth: %s %s" % [_json(inv["items"]), str(InventoryService.validate(save, grown))])
	# Shrink: entries at slots 0..4 stay when the size drops to 3.
	var small := InventoryServiceTests._cfg(3, 0)
	snap = InventoryService.snapshot(save, small)
	if _slots(snap, "items") != [1, 0, 3, 4] or _slots(snap, "stacks") != [2] or int(snap["unique_cap"]) != 3:
		m.append("shrink read: items %s stacks %s" % [str(_slots(snap, "items")), str(_slots(snap, "stacks"))])
	_expect(m, _put(save, small, "ph_charm_a"), "lost", "overflow", "a full container after the cut")
	# Free the slots 0, 1 and 3: two entries are left (slots 2 and 4), so one entry fits again, in a slot below 3.
	InventoryService.discard(save, small, "it.2", true)
	InventoryService.discard(save, small, "it.1", true)
	InventoryService.discard(save, small, "it.3", true)
	var r := _put(save, small, "ph_charm_a")
	var placed := InventoryService.snapshot(save, small)
	if str(r["result"]) != "stored" or not _slots(placed, "items").has(0) or _slots(placed, "items").has(5):
		m.append("a new entry must take a slot below the size: %s %s" % [_json(r), str(_slots(placed, "items"))])
	var kept := _slots(placed, "items")
	if not kept.has(4):
		m.append("the entry above the size moved: %s" % str(kept))
	return _result(m)


static func _t_move() -> Dictionary:
	var m: Array = []
	var save := InventoryServiceTests._fresh()
	var cfg := InventoryServiceTests._cfg(4, 3)
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_charm_a")
	_put(save, cfg, "ph_consumable_a", 2)
	var census := _census(save)
	# Sanctum piece to the pack: lowest free slot.
	var r := _mv(save, cfg, "sanctum", 1, "pack")
	_expect(m, r, "moved", "ok", "piece to the pack")
	var snap := InventoryService.snapshot(save, cfg)
	if _slots(snap, "pack") != [0] or _slots(snap, "items") != [0] or str(r["to_slot"]) != "0":
		m.append("after the first move: pack %s items %s result %s" % [str(_slots(snap, "pack")), str(_slots(snap, "items")), _json(r)])
	# Sanctum stack to the pack with a target slot.
	r = _mv(save, cfg, "sanctum", 2, "pack", 2)
	_expect(m, r, "moved", "ok", "stack to the pack, slot 2")
	snap = InventoryService.snapshot(save, cfg)
	if _slots(snap, "pack_stacks") != [2] or not (snap["stacks"] as Array).is_empty() or int(snap["pack_stacks"][0]["count"]) != 2:
		m.append("the stack did not arrive in pack slot 2: %s" % _json(snap["pack_stacks"]))
	# Pack back to the Sanctum, both kinds. The stack moves whole and keeps its count.
	_expect(m, _mv(save, cfg, "pack", 2, "sanctum"), "moved", "ok", "stack back")
	_expect(m, _mv(save, cfg, "pack", 0, "sanctum", 3), "moved", "ok", "piece back to slot 3")
	snap = InventoryService.snapshot(save, cfg)
	if _slots(snap, "items") != [0, 3] or _slots(snap, "stacks") != [1] or int(snap["pack_count"]) != 0:
		m.append("after the way back: items %s stacks %s" % [str(_slots(snap, "items")), str(_slots(snap, "stacks"))])
	if _census(save) != census:
		m.append("the census changed: %s vs %s" % [_census(save), census])
	if not InventoryService.validate(save, cfg).is_empty():
		m.append("validate: %s" % str(InventoryService.validate(save, cfg)))
	# The Sanctum has no room for a piece from a full pack... and the other way round.
	var tight := InventoryServiceTests._fresh()
	var cfg2 := InventoryServiceTests._cfg(1, 1)
	_put(tight, cfg2, "ph_weapon_a")
	_put(tight, cfg2, "ph_charm_a")
	_expect(m, _mv(tight, cfg2, "pack", 0, "sanctum"), "refused", "container_full", "pack to a full Sanctum")
	_expect(m, _mv(tight, cfg2, "sanctum", 0, "pack"), "refused", "container_full", "Sanctum to a full pack")
	return _result(m)


static func _t_reorder() -> Dictionary:
	var m: Array = []
	var save := InventoryServiceTests._fresh()
	var cfg := InventoryServiceTests._cfg(5, 3)
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_charm_a")
	_put(save, cfg, "ph_material_a", 2)
	var r := _mv(save, cfg, "sanctum", 0, "sanctum", 4)
	_expect(m, r, "reordered", "ok", "piece into an empty slot")
	r = _mv(save, cfg, "sanctum", 2, "sanctum", 3)
	_expect(m, r, "reordered", "ok", "stack into an empty slot")
	var snap := InventoryService.snapshot(save, cfg)
	if _slots(snap, "items") != [4, 1] or _slots(snap, "stacks") != [3]:
		m.append("slots after the reorder: items %s stacks %s" % [str(_slots(snap, "items")), str(_slots(snap, "stacks"))])
	if _ids_in_order(save) != ["it.1", "it.2"]:
		m.append("a reorder changed the order of the pieces")
	# No swap: an occupied slot refuses, whatever sits on either side.
	var before := _json(save)
	_expect(m, _mv(save, cfg, "sanctum", 4, "sanctum", 1), "refused", "slot_taken", "piece on a piece")
	_expect(m, _mv(save, cfg, "sanctum", 3, "sanctum", 1), "refused", "slot_taken", "stack on a piece")
	_expect(m, _mv(save, cfg, "sanctum", 1, "sanctum", 3), "refused", "slot_taken", "piece on a stack")
	_expect(m, _mv(save, cfg, "sanctum", 4, "sanctum", 4), "refused", "no_change", "piece on its own slot")
	_expect(m, _mv(save, cfg, "sanctum", 4, "sanctum"), "refused", "no_change", "same container, no slot")
	if _json(save) != before:
		m.append("a refusal changed the save")
	# Across containers a taken target slot is refused as well; the caller omits the slot to take the first free one.
	_mv(save, cfg, "sanctum", 1, "pack", 0)
	before = _json(save)
	_expect(m, _mv(save, cfg, "sanctum", 4, "pack", 0), "refused", "slot_taken", "piece onto a pack piece")
	_expect(m, _mv(save, cfg, "sanctum", 4, "pack"), "moved", "ok", "piece to the first free pack slot")
	return _result(m)


static func _ids_in_order(save: Dictionary) -> Array:
	return InventoryServiceTests._ids(save, "items")


static func _t_merge() -> Dictionary:
	var m: Array = []
	var save := InventoryServiceTests._fresh()
	var cfg := InventoryServiceTests._cfg(6, 3)  # stack limit 5 for materials; the fixture limits consumables to 3
	_put(save, cfg, "ph_material_a", 4)
	_mv(save, cfg, "sanctum", 0, "pack")
	_put(save, cfg, "ph_material_a", 3)
	var census := _census(save)
	# Partial: 4 from the pack onto 3 in the Sanctum. Limit 5, room 2: 2 move, 2 stay in the source slot.
	var r := _mv(save, cfg, "pack", 0, "sanctum", 0)
	_expect(m, r, "merged", "ok", "partial merge")
	if int(r["merged"]) != 2 or int(r["remaining"]) != 2:
		m.append("partial merge numbers: %s" % _json(r))
	var snap := InventoryService.snapshot(save, cfg)
	if int(snap["stacks"][0]["count"]) != 5 or int(snap["pack_stacks"][0]["count"]) != 2 or int(snap["pack_stacks"][0]["slot"]) != 0:
		m.append("after the partial merge: %s / %s" % [_json(snap["stacks"]), _json(snap["pack_stacks"])])
	if _census(save) != census:
		m.append("the partial merge changed the total")
	# At the limit: the target is full, the merge is refused and nothing changes.
	var before := _json(save)
	_expect(m, _mv(save, cfg, "pack", 0, "sanctum", 0), "refused", "stack_limit", "merge onto a full stack")
	if _json(save) != before:
		m.append("the refusal changed the save")
	# Exact: the target has room for the whole source. The source slot empties.
	var exact := InventoryServiceTests._fresh()
	_put(exact, cfg, "ph_material_a", 3)
	_mv(exact, cfg, "sanctum", 0, "pack")
	_put(exact, cfg, "ph_material_a", 2)
	r = _mv(exact, cfg, "pack", 0, "sanctum", 0)
	_expect(m, r, "merged", "ok", "exact merge")
	if int(r["merged"]) != 3 or int(r["remaining"]) != 0 or not (exact["inventory"]["pack_stacks"] as Array).is_empty() \
			or int(exact["inventory"]["stacks"][0]["quantity"]) != 5:
		m.append("exact merge: %s, %s" % [_json(r), _json(exact["inventory"])])
	# Same container: stacks merge inside the Sanctum too (two stacks built through the pack).
	var inner := InventoryServiceTests._fresh()
	_put(inner, cfg, "ph_material_a", 2)
	_mv(inner, cfg, "sanctum", 0, "pack")
	_put(inner, cfg, "ph_material_a", 2)
	_mv(inner, cfg, "pack", 0, "sanctum", 3)
	r = _mv(inner, cfg, "sanctum", 3, "sanctum", 0)
	_expect(m, r, "merged", "ok", "merge inside the Sanctum")
	if (inner["inventory"]["stacks"] as Array).size() != 1 or int(inner["inventory"]["stacks"][0]["quantity"]) != 4:
		m.append("merge inside the Sanctum: %s" % _json(inner["inventory"]["stacks"]))
	# A merge needs no free slot: the full pack takes it.
	var fullpack := InventoryServiceTests._fresh()
	var cfg2 := InventoryServiceTests._cfg(4, 2)
	_put(fullpack, cfg2, "ph_weapon_a")
	_put(fullpack, cfg2, "ph_material_a", 1)
	_mv(fullpack, cfg2, "sanctum", 0, "pack")
	_mv(fullpack, cfg2, "sanctum", 1, "pack")
	_put(fullpack, cfg2, "ph_material_a", 2)
	if InventoryService.pack_count(fullpack) != 2:
		m.append("setup: the pack is not full")
	_expect(m, _mv(fullpack, cfg2, "sanctum", 0, "pack", 1), "merged", "ok", "merge into a full pack")
	if int(fullpack["inventory"]["pack_stacks"][0]["quantity"]) != 3 or InventoryService.pack_count(fullpack) != 2:
		m.append("merge into a full pack: %s" % _json(fullpack["inventory"]))
	# Type mismatch and a stack onto a piece.
	var mix := InventoryServiceTests._fresh()
	_put(mix, cfg, "ph_material_a", 1)
	_put(mix, cfg, "ph_consumable_a", 1)
	_put(mix, cfg, "ph_weapon_a")
	before = _json(mix)
	_expect(m, _mv(mix, cfg, "sanctum", 0, "sanctum", 1), "refused", "type_mismatch", "material onto consumable")
	_expect(m, _mv(mix, cfg, "sanctum", 0, "sanctum", 2), "refused", "slot_taken", "stack onto a piece")
	if _json(mix) != before:
		m.append("a mismatch changed the save")
	# The stack limit of a type comes from its definition: consumables stop at 3.
	var cons := InventoryServiceTests._fresh()
	_put(cons, cfg, "ph_consumable_a", 2)
	_mv(cons, cfg, "sanctum", 0, "pack")
	_put(cons, cfg, "ph_consumable_a", 2)
	r = _mv(cons, cfg, "pack", 0, "sanctum", 0)
	if int(r["merged"]) != 1 or int(r["remaining"]) != 1:
		m.append("definition limit 3: %s" % _json(r))
	return _result(m)


static func _t_refusals() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(3, 2)
	var save := InventoryServiceTests._fresh()
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_material_a", 5)
	_put(save, cfg, "ph_consumable_a", 1)
	_mv(save, cfg, "sanctum", 0, "pack")
	_put(save, cfg, "ph_weapon_a")
	_mv(save, cfg, "sanctum", 0, "pack")
	_put(save, cfg, "ph_charm_a")
	# Now: Sanctum material (1), consumable (2), charm (0); pack full with two pieces.
	var cases: Array = [
		["bad from box", "moon", 0, "pack", -1, "bad_box"],
		["bad to box", "sanctum", 0, "moon", -1, "bad_box"],
		["empty source slot", "sanctum", 7, "pack", -1, "unknown_entry"],
		["negative source slot", "sanctum", -1, "pack", -1, "unknown_entry"],
		["target below -1", "sanctum", 0, "pack", -2, "bad_slot"],
		["target at the size", "sanctum", 0, "pack", 2, "bad_slot"],
		["target above the size", "sanctum", 0, "sanctum", 9, "bad_slot"],
		["pack full", "sanctum", 0, "pack", -1, "container_full"],
		["taken pack slot", "sanctum", 0, "pack", 1, "slot_taken"],
		["same slot", "sanctum", 0, "sanctum", 0, "no_change"],
		["type mismatch", "sanctum", 1, "sanctum", 2, "type_mismatch"],
	]
	for c in cases:
		var before := _json(save)
		var r := _mv(save, cfg, c[1], c[2], c[3], c[4])
		_expect(m, r, "refused", str(c[5]), str(c[0]))
		if _json(save) != before:
			m.append("%s: the save changed" % str(c[0]))
	# A block that is not a block.
	for bad in [{}, { "inventory": 5 }, { "inventory": { "items": {} } }]:
		_expect(m, _mv(bad as Dictionary, cfg, "sanctum", 0, "pack"), "refused", "bad_state", "bad block")
		_expect(m, InventoryService.discard_entry(bad as Dictionary, cfg, "sanctum", 0), "refused", "bad_state", "bad block discard")
	return _result(m)


static func _t_discard_entry() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(4, 3)
	var save := InventoryServiceTests._fresh()
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_material_a", 5)
	_mv(save, cfg, "sanctum", 1, "pack")
	_put(save, cfg, "ph_material_a", 4)
	# A partial count lowers the quantity and keeps the slot.
	var r := InventoryService.discard_entry(save, cfg, "sanctum", 1, 1)
	_expect(m, r, "discarded", "ok", "one of four")
	if int(r["remaining"]) != 3 or int(r["count"]) != 1 or int(save["inventory"]["stacks"][0]["quantity"]) != 3 \
			or int(save["inventory"]["stacks"][0]["slot"]) != 1:
		m.append("partial discard: %s %s" % [_json(r), _json(save["inventory"]["stacks"])])
	# A count of 0, above the quantity, or below -1 is refused and changes nothing.
	var before := _json(save)
	for bad in [0, 4, 99, -2]:
		_expect(m, InventoryService.discard_entry(save, cfg, "sanctum", 1, bad), "refused", "count_range", "count %d" % bad)
	if _json(save) != before:
		m.append("a count refusal changed the save")
	# The whole stack: the default count, or the exact quantity.
	_expect(m, InventoryService.discard_entry(save, cfg, "sanctum", 1), "discarded", "ok", "the whole stack")
	if not (save["inventory"]["stacks"] as Array).is_empty():
		m.append("the whole stack stayed")
	_expect(m, InventoryService.discard_entry(save, cfg, "pack", 0, 5), "discarded", "ok", "a pack stack, exact count")
	if not (save["inventory"]["pack_stacks"] as Array).is_empty():
		m.append("the pack stack stayed")
	# A piece takes no count.
	var psave := InventoryServiceTests._fresh()
	_put(psave, cfg, "ph_weapon_a")
	_put(psave, cfg, "ph_charm_a")
	_expect(m, InventoryService.discard_entry(psave, cfg, "sanctum", 0, 2), "refused", "count_range", "piece with count 2")
	_expect(m, InventoryService.discard_entry(psave, cfg, "sanctum", 0, 1), "discarded", "ok", "piece with count 1")
	_expect(m, InventoryService.discard_entry(psave, cfg, "sanctum", 1), "discarded", "ok", "piece, no count")
	_expect(m, InventoryService.discard_entry(psave, cfg, "sanctum", 1), "refused", "unknown_entry", "empty slot")
	_expect(m, InventoryService.discard_entry(psave, cfg, "moon", 1), "refused", "bad_box", "bad box")
	# An equipped piece stays.
	_put(psave, cfg, "ph_relic_a")
	(psave["inventory"]["items"][0] as Dictionary)["held_by"] = "echo.1"
	before = _json(psave)
	_expect(m, InventoryService.discard_entry(psave, cfg, "sanctum", 0), "refused", "equipped", "equipped piece")
	if _json(psave) != before:
		m.append("the equipped refusal changed the save")
	return _result(m)


## Deterministic pseudo-random moves, merges and discards-free: the piece ids and the quantity per type never
## change, every container stays valid, and no two entries share a slot.
static func _t_conservation() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(7, 4, 6)
	var save := InventoryServiceTests._fresh()
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		_put(save, cfg, t)
	_put(save, cfg, "ph_material_a", 4)
	_put(save, cfg, "ph_consumable_a", 3)
	_mv(save, cfg, "sanctum", 3, "pack")
	_put(save, cfg, "ph_material_a", 5)
	var census := _census(save)
	var x := 987
	var landed := { "moved": 0, "reordered": 0, "merged": 0, "refused": 0 }
	for step in 400:
		x = (x * 1103515245 + 12345) % 2147483648
		var from_box := "sanctum" if (x >> 4) % 2 == 0 else "pack"
		var to_box := "sanctum" if (x >> 6) % 2 == 0 else "pack"
		var to_slot := ((x >> 9) % 8) - 1
		var r := _mv(save, cfg, from_box, (x >> 13) % 7, to_box, to_slot)
		landed[str(r["result"])] = int(landed.get(str(r["result"]), 0)) + 1
		if _census(save) != census:
			m.append("step %d: the census changed after %s" % [step, _json(r)])
			break
		var probs := InventoryService.validate(save, cfg)
		if not probs.is_empty():
			m.append("step %d: validate says %s after %s" % [step, str(probs), _json(r)])
			break
	if int(landed["moved"]) < 10 or int(landed["reordered"]) < 10 or int(landed["merged"]) < 1 or int(landed["refused"]) < 10:
		m.append("the sequence did not reach every outcome: %s" % _json(landed))
	return _result(m)


static func _t_held_stacks() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(4, 3)
	var save := InventoryServiceTests._fresh()
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_material_a", 3)
	_put(save, cfg, "ph_charm_a")
	_mv(save, cfg, "sanctum", 1, "pack", 1)
	_mv(save, cfg, "sanctum", 0, "pack", 0)
	var held := InventoryService.held_pieces(save)
	if held.size() != 2 or str(held[0]["id"]) != "it.1" or str(held[1]["id"]) != "stack:ph_material_a:1" \
			or int(held[1]["quantity"]) != 3 or str(held[1]["kind"]) != "material":
		m.append("held_pieces: %s" % _json(held))
	if InventoryService.mark_index_of(cfg, "stack:ph_material_a:1") != -1:
		m.append("a held stack has a mark")
	# Remove the stack by its held id; the piece stays.
	var removed := InventoryService.remove_held(save, ["stack:ph_material_a:1", "stack:nope:0", "it.99"])
	if removed.size() != 1 or int(removed[0]["quantity"]) != 3 or InventoryService.pack_count(save) != 1:
		m.append("remove_held: %s, pack %d" % [_json(removed), InventoryService.pack_count(save)])
	# The draw name of a carried stack is its order among the stacks of its type, never its slot.
	var save2 := InventoryServiceTests._fresh()
	var cfg2 := InventoryServiceTests._cfg(4, 6)
	_put(save2, cfg2, "ph_material_a", 2)
	_mv(save2, cfg2, "sanctum", 0, "pack", 3)
	_put(save2, cfg2, "ph_material_a", 3)
	_mv(save2, cfg2, "sanctum", 0, "pack", 1)
	var names: Array = InventoryService.held_pieces(save2).map(func(h): return InventoryService.draw_id(h))
	if names != ["stack:ph_material_a:1", "stack:ph_material_a:0"]:
		m.append("draw names by slot order: %s" % str(names))
	# The order is counted per type: a stack of another type never changes it (D-43).
	var mixed := InventoryServiceTests._fresh()
	_put(mixed, cfg2, "ph_material_a", 2)
	_mv(mixed, cfg2, "sanctum", 0, "pack", 3)
	_put(mixed, cfg2, "ph_consumable_a", 2)
	_mv(mixed, cfg2, "sanctum", 0, "pack", 0)
	_put(mixed, cfg2, "ph_material_a", 3)
	_mv(mixed, cfg2, "sanctum", 0, "pack", 1)
	var by_qty := func(save_v: Dictionary) -> Dictionary:
		var out := {}
		for h in InventoryService.held_pieces(save_v):
			out["%s/%d" % [h["type_id"], int(h["quantity"])]] = InventoryService.draw_id(h)
		return out
	var before_names: Dictionary = by_qty.call(mixed)
	if before_names != { "ph_material_a/2": "stack:ph_material_a:1", "ph_consumable_a/2": "stack:ph_consumable_a:0",
			"ph_material_a/3": "stack:ph_material_a:0" }:
		m.append("per-type draw names: %s" % _json(before_names))
	_mv(mixed, cfg2, "pack", 0, "pack", 5)  # the consumable stack goes to the end of the pack
	var after_names: Dictionary = by_qty.call(mixed)
	if after_names != before_names:
		m.append("moving a stack of another type changed the draw names: %s" % _json(after_names))
	# One stack of a type keeps its draw name wherever it sits in the pack.
	var save3 := InventoryServiceTests._fresh()
	_put(save3, cfg2, "ph_material_a", 2)
	_mv(save3, cfg2, "sanctum", 0, "pack", 0)
	for slot in [4, 1, 5, 2]:
		_mv(save3, cfg2, "pack", int(InventoryService.held_pieces(save3)[0]["id"].split(":")[2]), "pack", slot)
		if InventoryService.draw_id(InventoryService.held_pieces(save3)[0]) != "stack:ph_material_a:0":
			m.append("the draw name changed with the slot %d" % slot)
	return _result(m)


static func _t_snapshot_rows() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(6, 3)
	var save := InventoryServiceTests._fresh()
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_consumable_a", 2)
	_put(save, cfg, "ph_material_a", 1)
	_mv(save, cfg, "sanctum", 2, "pack")
	_mv(save, cfg, "sanctum", 0, "pack", 2)
	var snap := InventoryService.snapshot(save, cfg)
	if int(snap["unique_cap"]) != 6 or int(snap["pack_capacity"]) != 3 or int(snap["pack_count"]) != 2 \
			or int(snap["sanctum_used"]) != 1 or int(snap["sanctum_room"]) != 5:
		m.append("sizes and counts: %s" % _json(snap))
	var piece: Dictionary = snap["pack"][0]
	if str(piece["name"]) != "Placeholder weapon A" or int(piece["slot"]) != 2 or str(piece["name"]) == str(piece["type_id"]):
		m.append("piece row: %s" % _json(piece))
	var stack: Dictionary = snap["stacks"][0]
	if str(stack["name"]) != "Placeholder consumable A" or int(stack["count"]) != 2 or int(stack["stack_limit"]) != 3 \
			or bool(stack["at_limit"]) or int(stack["slot"]) != 1:
		m.append("stack row: %s" % _json(stack))
	var pstack: Dictionary = snap["pack_stacks"][0]
	if str(pstack["name"]) != "Placeholder material A" or int(pstack["slot"]) != 0 or int(pstack["count"]) != 1 or int(pstack["stack_limit"]) != 5:
		m.append("pack stack row: %s" % _json(pstack))
	if InventoryService.pack_load(save, cfg)["carried"] != 2:
		m.append("pack_load does not count the pack stack")
	# A definition without a name gives "", never the id.
	var bare := InventoryServiceTests._cfg(6, 3, 5, 1, 1, false)
	var bare_snap := InventoryService.snapshot(save, bare)
	if str(bare_snap["pack"][0]["name"]) != "" or str(bare_snap["stacks"][0]["name"]) != "":
		m.append("a missing name is not empty: %s" % _json(bare_snap["stacks"]))
	# The projection holds no id of a stack and no Ase, Ekwan or Thread key.
	var banned := InventoryServiceTests._banned_key(snap)
	if banned != "":
		m.append("banned key %s" % banned)
	return _result(m)


static func _t_round_trip() -> Dictionary:
	var m: Array = []
	var cfg := InventoryServiceTests._cfg(5, 3)
	var save := InventoryServiceTests._fresh()
	_put(save, cfg, "ph_weapon_a")
	_put(save, cfg, "ph_material_a", 3)
	_mv(save, cfg, "sanctum", 1, "pack", 2)
	_mv(save, cfg, "sanctum", 0, "sanctum", 4)
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(save))
	if not InventoryService.validate(loaded, cfg).is_empty():
		m.append("validate after the round trip: %s" % str(InventoryService.validate(loaded, cfg)))
	if _json(InventoryService.snapshot(loaded, cfg)) != _json(InventoryService.snapshot(save, cfg)):
		m.append("the snapshots differ after the round trip")
	var a := _mv(save, cfg, "pack", 2, "sanctum")
	var b := _mv(loaded, cfg, "pack", 2, "sanctum")
	if _json(a) != _json(b) or _json(InventoryService.snapshot(loaded, cfg)) != _json(InventoryService.snapshot(save, cfg)):
		m.append("the same move gives another result after the round trip")
	return _result(m)
