class_name PickupCase
extends RefCounted

## The capacity case of one pickup event and the chooser's reaction class (design document sections 6.1
## and 7; D-24, D-33, D-34, D-39, D-43, D-55). Pure statics. No RNG, no writes, no emotion change.

const CASE_FROZEN := "frozen"
const REACTION_PLUS := "plus"
const REACTION_NONE := "none"
const REACTION_MINUS := "minus"
## D-34 "burdened or worse": this status and every status before it on `EmotionService.STATUS_LADDER`.
const SEVERE_FROM := "burdened"


## Pack room as the found-items seam counts it: held entries plus the open item rows of the whole save.
## Read it BEFORE the seam writes this event's rows, or the taken finds count twice.
static func pack_room(save: Dictionary, inv_cfg: Dictionary) -> Dictionary:
	return InventoryService.pack_load(save, inv_cfg, EarningsService.open_item_rows_in_save(save))


static func is_severe(actor: Dictionary) -> bool:
	var at: int = EmotionService.STATUS_LADDER.find(EmotionStatusLean.status_of(actor))
	return at >= 0 and at <= EmotionService.STATUS_LADDER.find(SEVERE_FROM)


## `finds`: every find of the event, in find order. `order`: `PickupPick.order` for the chooser (ignored
## when `frozen`). `room`: `pack_room`. `actor`: the chooser's actor view (for the severe band).
## Returns { case, taken, tried, left, reaction, free }: `taken` in pick order, `left` in find order and
## holding `tried` (the held-up item, "" when none), `free` = S before the event.
## A frozen chooser (or an empty `order` with finds): case "frozen", nothing taken, no tried item, every find left, reaction "none".
## No finds: case "", reaction "none" (the event never opens then).
static func resolve(finds: Array, order: Array, room: Dictionary, frozen: bool, actor: Dictionary) -> Dictionary:
	var free := maxi(0, int(room.get("free", 0)))
	var all_ids := _ids(finds)
	if all_ids.is_empty() and not frozen:
		return _out("", [], "", [], REACTION_NONE, free)
	# `PickupPick.order` returns [] only for a frozen chooser, so an empty order over real finds is frozen.
	if frozen or order.is_empty():
		return _out(CASE_FROZEN, [], "", all_ids, REACTION_NONE, free)
	var ranked := _ids(order)
	var taken := ranked.slice(0, free)
	var tried: String = str(ranked[free]) if ranked.size() > free else ""
	var left := all_ids.filter(func(id: String) -> bool: return not taken.has(id))
	var empty_pack := int(room.get("carried", 0)) <= 0
	if left.is_empty():
		return _out("C1" if empty_pack else "C3", taken, "", left, REACTION_PLUS, free)
	if free == 0:
		return _out("C5", taken, tried, left, REACTION_NONE if is_severe(actor) else REACTION_MINUS, free)
	return _out("C2" if empty_pack else "C4", taken, tried, left, REACTION_NONE, free)


static func _out(case_id: String, taken: Array, tried: String, left: Array, reaction: String, free: int) -> Dictionary:
	return { "case": case_id, "taken": taken, "tried": tried, "left": left, "reaction": reaction, "free": free }


static func _ids(finds: Array) -> Array:
	var out: Array = []
	for f in finds:
		if f is Dictionary:
			out.append(str((f as Dictionary).get("find_id", "")))
	return out
