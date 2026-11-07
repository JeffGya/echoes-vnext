extends RefCounted

## What a move or a discard would do, read from `data.inventory` only. This predicts the result so the panel can
## show a hover hint and a reason line before it dispatches. The core stays the authority: it checks every
## action again and refuses what it must. Reason keys are the core keys (`inventory.move.apply`).

const BOX_SANCT := "sanctum"
const BOX_PACK := "pack"
const STACK_KINDS: Array[String] = ["consumable", "material"]


static func is_stack(row: Dictionary) -> bool:
	return STACK_KINDS.has(str(row.get("kind", "")))


static func capacity(inv: Dictionary, box: String) -> int:
	return int(inv.get("unique_cap", 0)) if box == BOX_SANCT else int(inv.get("pack_capacity", 0))


static func entries(inv: Dictionary, box: String) -> Array:
	var out: Array = []
	var keys: Array = ["items", "stacks"] if box == BOX_SANCT else ["pack", "pack_stacks"]
	for k in keys:
		var v: Variant = inv.get(k, [])
		if v is Array:
			for r in (v as Array):
				if r is Dictionary:
					out.append(r)
	return out


## Slots drawn: the container size, or one more than the highest used slot when an entry sits past the size.
static func drawn_slots(inv: Dictionary, box: String) -> int:
	var n := capacity(inv, box)
	for r in entries(inv, box):
		n = maxi(n, int((r as Dictionary).get("slot", -1)) + 1)
	return n


static func entry_at(inv: Dictionary, box: String, slot: int) -> Dictionary:
	for r in entries(inv, box):
		if int((r as Dictionary).get("slot", -1)) == slot:
			return r
	return {}


## Lowest slot below the container size that holds no entry, or -1.
static func free_slot(inv: Dictionary, box: String) -> int:
	for i in capacity(inv, box):
		if entry_at(inv, box, i).is_empty():
			return i
	return -1


static func is_full(inv: Dictionary, box: String) -> bool:
	if box == BOX_SANCT:
		return int(inv.get("sanctum_room", 0)) <= 0 or free_slot(inv, box) < 0
	return int(inv.get("pack_free", 0)) <= 0 or free_slot(inv, box) < 0


static func _refuse(reason: String) -> Dictionary:
	return { "kind": "refuse", "reason": reason, "to_slot": -1 }


## { kind: "none"|"reorder"|"place"|"merge"|"refuse", reason: String, to_slot: int }.
## `to_slot` -1 means the lowest free slot of `to`.
static func plan(inv: Dictionary, from: String, slot: int, to: String, to_slot: int) -> Dictionary:
	if inv.has("path"):
		return _refuse("path_open")
	var src := entry_at(inv, from, slot)
	if src.is_empty():
		return _refuse("unknown_entry")
	if from == to and (to_slot < 0 or to_slot == slot):
		return { "kind": "none", "reason": "", "to_slot": slot }
	if to_slot >= 0:
		var tgt := entry_at(inv, to, to_slot)
		if not tgt.is_empty():
			return _onto(src, tgt, to_slot)
		if to_slot >= capacity(inv, to):
			return _refuse("bad_slot")
		if from == to:
			return { "kind": "reorder", "reason": "", "to_slot": to_slot }
		if is_full(inv, to):
			return _refuse("container_full")
		return { "kind": "place", "reason": "", "to_slot": to_slot }
	if is_full(inv, to):
		return _refuse("container_full")
	return { "kind": "place", "reason": "", "to_slot": free_slot(inv, to) }


static func _onto(src: Dictionary, tgt: Dictionary, to_slot: int) -> Dictionary:
	if not (is_stack(src) and is_stack(tgt)):
		return _refuse("slot_taken")
	if str(src.get("type_id", "")) != str(tgt.get("type_id", "")):
		return _refuse("type_mismatch")
	if int(tgt.get("count", 0)) >= int(tgt.get("stack_limit", 0)):
		return _refuse("stack_limit")
	return { "kind": "merge", "reason": "", "to_slot": to_slot }


## "" when a discard from `box` is allowed by the screen, else the core reason key. Read from `data.inventory.path`.
static func discard_block(inv: Dictionary, box: String) -> String:
	var path_v: Variant = inv.get("path", null)
	if not (path_v is Dictionary):
		return ""
	var path: Dictionary = path_v
	return str(path.get("discard_pack_reason", "")) if box == BOX_PACK else str(path.get("discard_sanctum_reason", "not_in_pack"))
