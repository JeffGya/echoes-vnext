extends RefCounted

## Snapshot fixtures for the inventory UI tests and screenshots. Sizes and rows are arbitrary test values; they
## do not read data/balance.json. The shapes copy `InventoryService.snapshot` (inventory rows) and the item report
## rows (docs/stories/v2-item-001/step7-backend-moves-slots.md, final contract).
## Everything under res:// ships, so no real item name is used.


static func piece(slot: int, kind: String, grade: String, mark: int, item_name: String, type_id: String = "") -> Dictionary:
	var tid := type_id if not type_id.is_empty() else "ph_%s_%d" % [kind, slot]
	return { "id": "it.%d" % (slot + 100), "type_id": tid, "kind": kind, "grade": grade, "mark_index": mark,
		"equipped": false, "name": item_name, "slot": slot }


static func stack(slot: int, kind: String, count: int, limit: int, item_name: String, type_id: String = "") -> Dictionary:
	var tid := type_id if not type_id.is_empty() else "ph_%s_%d" % [kind, slot]
	return { "type_id": tid, "kind": kind, "name": item_name, "slot": slot, "count": count,
		"stack_limit": limit, "at_limit": count >= limit }


## Builds `data.inventory`. `sanct` and `pack` are Arrays of piece and stack rows (a stack has `count`).
static func inventory(sanct_size: int, pack_size: int, sanct: Array, pack: Array, path: Dictionary = {}) -> Dictionary:
	var items: Array = []
	var stacks: Array = []
	var pack_items: Array = []
	var pack_stacks: Array = []
	for r in sanct:
		(stacks if (r as Dictionary).has("count") else items).append(r)
	for r in pack:
		(pack_stacks if (r as Dictionary).has("count") else pack_items).append(r)
	var used := items.size() + stacks.size()
	var carried := pack_items.size() + pack_stacks.size()
	var free := maxi(0, pack_size - carried)
	var level := 0
	if carried > 0:
		level = 3 if free <= 0 else (2 if free <= 1 else 1)
	var inv := {
		"unique_count": items.size(), "sanctum_used": used, "unique_cap": sanct_size, "sanctum_room": maxi(0, sanct_size - used),
		"pack_count": carried, "pack_capacity": pack_size, "pack_free": free,
		"items": items, "stacks": stacks, "pack": pack_items, "pack_stacks": pack_stacks,
		"pack_load": { "carried": carried, "capacity": pack_size, "free": free, "level": level },
		"warn": { "room": maxi(0, sanct_size - used) <= 2, "pack": carried > 0 and free <= 1 },
	}
	if not path.is_empty():
		inv["path"] = path
	return inv


## 20 Sanctum slots, 4 pack slots: pieces in scattered slots, two stacks, two carried pieces.
static func standard() -> Dictionary:
	return inventory(20, 4, [
		piece(0, "gear", "g2", 1, "Test gear A"),
		piece(1, "relic", "g3", 4, "Test relic B"),
		stack(3, "consumable", 12, 20, "Test potion C", "ph_potion"),
		piece(4, "gear", "g1", 2, "Test gear D"),
		stack(7, "material", 20, 20, "Test fibre E", "ph_fibre"),
		piece(8, "gear", "g1", 3, "Test gear F"),
		stack(12, "consumable", 6, 20, "Test potion C", "ph_potion"),
	], [
		piece(0, "gear", "g3", 0, "Test gear G"),
		stack(2, "consumable", 5, 20, "Test potion C", "ph_potion"),
	])


static func full_both() -> Dictionary:
	var sanct: Array = []
	for i in 6:
		sanct.append(piece(i, ["gear", "relic"][i % 2], "g%d" % (1 + i % 3), i % 6, "Test piece %s" % "ABCDEF"[i]))
	var pack: Array = []
	for i in 4:
		pack.append(piece(i, "gear", "g1", i, "Test carried %s" % "ABCD"[i]))
	return inventory(6, 4, sanct, pack)


static func path_data(used: bool) -> Dictionary:
	return { "move_reason": "path_open", "discard_used": used,
		"discard_pack_reason": "path_used" if used else "", "discard_sanctum_reason": "not_in_pack" }


static func sanctum_snap(inv: Dictionary) -> Dictionary:
	return { "type": "flow.sanctum", "meta": { "t": 1 }, "data": { "inventory": inv }, "actions": {} }


static func party_snap(inv: Dictionary) -> Dictionary:
	return { "type": "flow.echo_party", "meta": { "t": 1 }, "data": { "inventory": inv }, "actions": {} }


static func path_snap(inv: Dictionary) -> Dictionary:
	return { "type": "flow.stage_explore", "meta": { "t": 1 }, "data": { "inventory": inv }, "actions": {} }


# ── Item report rows (result cards, leave confirmation) ────────

static func report_row(kind: String, grade: String, mark: int, source: String, reason: String, quantity: int = 1,
		item_name: String = "") -> Dictionary:
	var row := { "type_id": "ph_%s" % kind, "kind": kind, "grade": grade, "quantity": quantity,
		"source": source, "mark_index": mark, "reason_key": reason }
	if not item_name.is_empty():
		row["name"] = item_name
	return row


## `data.items` of a leave card: two survivors and three lost pieces.
static func items_block() -> Dictionary:
	return {
		"kept": [
			report_row("gear", "g2", 1, "held", "ok", 1, "Test gear A"),
			report_row("consumable", "", -1, "gathered", "to_pack", 5, "Test potion C"),
		],
		"lost": [
			report_row("relic", "g3", 4, "held", "leave_some", 1, "Test relic B"),
			report_row("gear", "g1", 2, "gathered", "leave_some", 1, "Test gear D"),
			report_row("material", "", -1, "gathered", "leave_some", 7, "Test fibre E"),
		],
	}
