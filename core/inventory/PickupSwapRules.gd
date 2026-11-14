class_name PickupSwapRules
extends RefCounted

## Swap legality in the pickup event (design document section 6.2; D-24, D-27, D-28, D-43). Pure statics:
## nothing here commits a swap. `event` = the `PickupCase.resolve` result. `finds` = every find of the event
## ({ find_id, type_id }). `pack_items` = `pack_entries` read AFTER the seam wrote this event's rows.
## Refusal keys: "frozen", "used", "has_room", "nothing_left", "same", "no_target", "bad_pair".


## What the pack holds, as { id, type_id }: held pieces and stacks (`InventoryService.held_pieces` ids),
## then the open item rows of `stage` (row ids). Open rows of another stage use room but are not listed.
static func pack_entries(save: Dictionary, stage: Dictionary) -> Array:
	var out: Array = []
	for row in InventoryService.held_pieces(save):
		out.append({ "id": str(row["id"]), "type_id": str(row["type_id"]) })
	for r in EarningsService.open_item_rows(stage):
		out.append({ "id": str(r["id"]), "type_id": str(((r["items"] as Array)[0] as Dictionary).get("type_id", "")) })
	return out


## Whether the event offers the swap at all: { ok, reason_key }. Needs a pack that is full after the
## picks, a find left on the field and at least one legal pair. With no legal pair: "same" when every
## possible pair is a twin, else "no_target" (no pack item listed, or a pair refused for another reason).
static func offer(event: Dictionary, finds: Array, pack_items: Array, swap_used: bool) -> Dictionary:
	var gate := _gate(event, swap_used)
	if not gate["ok"]:
		return gate
	var all_twins := not pack_items.is_empty()
	for fid in event.get("left", []):
		for item in pack_items:
			var key: String = pair(event, finds, pack_items, swap_used, str(fid),
				str((item as Dictionary).get("id", "")))["reason_key"]
			if key.is_empty():
				return _res("")
			all_twins = all_twins and key == "same"
	return _res("same" if all_twins else "no_target")


# UNWIRED (target: V2-ITEM-003): swap legality ignores equipped or in-use items
## One field find out of `event.left` for one pack item; never two pack items, two field items or a twin.
static func pair(event: Dictionary, finds: Array, pack_items: Array, swap_used: bool, find_id: String,
		pack_id: String) -> Dictionary:
	var gate := _gate(event, swap_used)
	if not gate["ok"]:
		return gate
	var find_type: String = _type_of(finds, "find_id", find_id) if (event.get("left", []) as Array).has(find_id) else ""
	var pack_type := _type_of(pack_items, "id", pack_id)
	if find_type.is_empty() or pack_type.is_empty():
		return _res("bad_pair")
	if find_type == pack_type:
		return _res("same")
	return _res("")


## Pack ids that make a legal pair with the selected field find, in `pack_items` order. [] when refused.
static func targets(event: Dictionary, finds: Array, pack_items: Array, swap_used: bool, find_id: String) -> Array:
	var out: Array = []
	for item in pack_items:
		var pid := str((item as Dictionary).get("id", ""))
		if pair(event, finds, pack_items, swap_used, find_id, pid)["ok"]:
			out.append(pid)
	return out


static func _gate(event: Dictionary, swap_used: bool) -> Dictionary:
	if str(event.get("case", "")) == PickupCase.CASE_FROZEN:
		return _res("frozen")
	if swap_used:
		return _res("used")
	if int(event.get("free", 0)) - (event.get("taken", []) as Array).size() > 0:
		return _res("has_room")
	if (event.get("left", []) as Array).is_empty():
		return _res("nothing_left")
	return _res("")


## The type_id of the first entry whose `key` is `id`, or "".
static func _type_of(entries: Array, key: String, id: String) -> String:
	if id.is_empty():
		return ""
	for e in entries:
		if e is Dictionary and str((e as Dictionary).get(key, "")) == id:
			return str((e as Dictionary).get("type_id", ""))
	return ""


static func _res(reason_key: String) -> Dictionary:
	return { "ok": reason_key.is_empty(), "reason_key": reason_key }
