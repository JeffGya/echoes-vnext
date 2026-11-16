class_name PickupSwapPlan
extends RefCounted

## Pure helpers for the pickup swap (V2-ITEM-001b U3). Port of the swap reducer of `pickup-event-playable.html`
## (`partners`, `twinPartners`, `swapRefusal`, `confirm`, preview). Reads a `flow.pickup` snapshot, returns plain data.
## The core decides every rule (`swap.targets`, `swap.twins`, `swap.reason_key`); this file only reads them.
## Ids are find ids (`finds[].find_id`) and pack entry ids (`pack.slots[].id`). Never shown to the player.

const PHASE_IDLE := "idle"
const REFUSAL_SAME := "same"
const REFUSAL_NO_TARGET := "no_target"
const REFUSAL_NOT_PARTNER := "not_partner"
const SIDE_FIELD := "field"
const SIDE_PACK := "pack"
const _ON_FIELD := ["left", "tried"]


## Ids the origin may be traded with (both directions are in the snapshot). [] when the swap is not offered.
static func legal_targets(snapshot: Dictionary, origin_id: String) -> Array:
	var out: Array = []
	var t_v: Variant = _swap(snapshot).get("targets", {})
	var list_v: Variant = (t_v as Dictionary).get(origin_id, []) if t_v is Dictionary else []
	for id: Variant in (list_v if list_v is Array else []):
		out.append(str(id))
	return out


## True when the player taps an item of the same type as the origin (mockup: 'These two are the same.').
## `swap.twins` holds them for the origin of the snapshot; for any other origin the type ids decide.
static func is_twin_refusal(snapshot: Dictionary, origin_id: String, target_id: String) -> bool:
	var sw := _swap(snapshot)
	# The core's own twin list is the authority for the origin it was built for; the type compare below covers
	# every other origin (the snapshot lists twins for one origin only).
	if str(sw.get("origin", "")) == origin_id and not origin_id.is_empty():
		return _strings(sw.get("twins", [])).has(target_id)
	var a := _item(snapshot, origin_id)
	var b := _item(snapshot, target_id)
	return not a.is_empty() and not b.is_empty() and a["side"] != b["side"] \
		and str(a["type_id"]) == str(b["type_id"]) and not str(a["type_id"]).is_empty()


## The trade of `origin_id` and `target_id` before it is confirmed. { ok, reason } when it is not a legal pair
## ("same" for a twin, "not_partner" otherwise). When ok:
##   find_id, pack_id, from_slot (index of the dropped entry in `pack.slots` now), slot (index of the incoming find in
##   the NEW order), cell (the find's field place),
##   pack_after: [{ id, type_id, name, ghost, from, slot }]  the pack panel in the order the core gives after the
##     commit: the dropped entry is removed and the incoming find is APPENDED last (a ghost, id = its pack entry id),
##   field_after: [{ id, type_id, name, ghost, from, cell }]  finds still on the field, plus the dropped item as a ghost,
##   dropped: { id, type_id, name, was_find, find_id }  the pack item that goes to the field and is lost (D-27, D-28);
##     `was_find` = a find taken in this event; it goes back to left (design 6.2),
##   lost_at_end: true, swap_left_after: 0.
static func preview(snapshot: Dictionary, origin_id: String, target_id: String) -> Dictionary:
	var a := _item(snapshot, origin_id)
	var b := _item(snapshot, target_id)
	if a.is_empty() or b.is_empty() or a["side"] == b["side"]:
		return { "ok": false, "reason": REFUSAL_NOT_PARTNER }
	if not legal_targets(snapshot, origin_id).has(target_id):
		return { "ok": false, "reason": REFUSAL_SAME if is_twin_refusal(snapshot, origin_id, target_id) else REFUSAL_NOT_PARTNER }
	var field: Dictionary = a if a["side"] == SIDE_FIELD else b
	var pack: Dictionary = a if a["side"] == SIDE_PACK else b
	var dropped := _dropped_of(snapshot, pack)
	var pack_after: Array = []
	for i in _slots(snapshot).size():
		var s: Dictionary = _slots(snapshot)[i]
		if i != int(pack["slot"]):
			pack_after.append({ "id": str(s.get("id", "")), "type_id": str(s.get("type_id", "")), "name": str(s.get("name", "")),
				"ghost": false, "from": SIDE_PACK, "slot": pack_after.size() })
	pack_after.append({ "id": "item:%s:%s" % [str(_data(snapshot).get("situation_id", "")), str(field["id"])],
		"type_id": str(field["type_id"]), "name": str(field["name"]), "ghost": true, "from": SIDE_FIELD, "slot": pack_after.size() })
	var field_after: Array = []
	for f: Dictionary in _field_finds(snapshot):
		if str(f["find_id"]) != str(field["id"]):
			field_after.append({ "id": str(f["find_id"]), "type_id": str(f["type_id"]), "name": str(f["name"]),
				"ghost": false, "from": SIDE_FIELD, "cell": int(f["cell"]) })
	field_after.append({ "id": str(pack["id"]), "type_id": str(pack["type_id"]), "name": str(pack["name"]),
		"ghost": true, "from": SIDE_PACK, "cell": int(field["cell"]) })
	return { "ok": true, "reason": "", "find_id": str(field["id"]), "pack_id": str(pack["id"]),
		"from_slot": int(pack["slot"]), "slot": pack_after.size() - 1,
		"cell": int(field["cell"]), "pack_after": pack_after, "field_after": field_after, "dropped": dropped,
		"lost_at_end": true, "swap_left_after": 0 }


## What the UI shows after the core confirmed the swap (read the new snapshot). { ok: false } when no swap is
## spent or nothing was dropped. When ok: dropped { id, type_id, name, was_find, find_id }, in_find_id (the find now
## in the pack), slot (its place in `pack.slots`, which is the core order: -1 when not listed), lost_at_end, swap_left, pack_ids.
static func after_confirm(snapshot: Dictionary) -> Dictionary:
	var sw := _swap(snapshot)
	var d_v: Variant = sw.get("dropped", {})
	var dropped_raw: Dictionary = d_v if d_v is Dictionary else {}
	var pack_ids: Array = _slots(snapshot).map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	if not bool(sw.get("spent", false)) or dropped_raw.is_empty():
		return { "ok": false, "pack_ids": pack_ids, "swap_left": int(_data(snapshot).get("swap_left", 0)) }
	var fid := _find_id_of_pack_id(snapshot, str(dropped_raw.get("id", "")))
	var dropped := { "id": str(dropped_raw.get("id", "")), "type_id": str(dropped_raw.get("type_id", "")),
		"name": str(dropped_raw.get("name", "")), "was_find": not fid.is_empty(), "find_id": fid }
	var in_id := ""
	var best := -1
	for f: Dictionary in _finds(snapshot):
		if str(f.get("status", "")) == "taken" and int(f.get("pick_index", -1)) > best:
			best = int(f["pick_index"])
			in_id = str(f["find_id"])
	var slot := -1
	for i in _slots(snapshot).size():
		if str((_slots(snapshot)[i] as Dictionary).get("find_id", "")) == in_id and not in_id.is_empty():
			slot = i
	return { "ok": true, "dropped": dropped, "in_find_id": in_id, "slot": slot, "lost_at_end": true,
		"swap_left": int(_data(snapshot).get("swap_left", 0)), "pack_ids": pack_ids }


## The Swap button of the details panel (D-25, D-54). The selected item comes from `data.selected`.
## { visible, enabled, refusal_key, action }.
##   frozen chooser or any phase but idle or nothing selected: not visible (no button at all, D-54);
##   offered and the selected item has a legal partner: visible and enabled, `action` = the `cta.swap` action;
##   otherwise visible and disabled, `refusal_key` = swap.reason_key, or "same" when every possible partner is a twin,
##   or "no_target" when the selected id cannot be swapped.
static func button_state(snapshot: Dictionary) -> Dictionary:
	var data := _data(snapshot)
	var hidden := { "visible": false, "enabled": false, "refusal_key": "", "action": {} }
	var sel_v: Variant = data.get("selected", {})
	var sel: Dictionary = sel_v if sel_v is Dictionary else {}
	if bool(data.get("frozen", false)) or str(data.get("phase", "")) != PHASE_IDLE or sel.is_empty():
		return hidden
	var sw := _swap(snapshot)
	var id := str(sel.get("id", ""))
	var targets_v: Variant = sw.get("targets", {})
	var targets: Dictionary = targets_v if targets_v is Dictionary else {}
	if bool(sw.get("offered", false)):
		if not targets.has(id):
			return { "visible": true, "enabled": false, "refusal_key": REFUSAL_NO_TARGET, "action": {} }
		if not (targets[id] as Array).is_empty():
			var act_v: Variant = (snapshot.get("actions", {}) as Dictionary).get("cta.swap", {}) if snapshot.get("actions", {}) is Dictionary else {}
			return { "visible": true, "enabled": true, "refusal_key": "", "action": act_v if act_v is Dictionary else {} }
		return { "visible": true, "enabled": false, "refusal_key": REFUSAL_SAME, "action": {} }
	var key := str(sw.get("reason_key", ""))
	return { "visible": true, "enabled": false, "refusal_key": key if not key.is_empty() else REFUSAL_NO_TARGET, "action": {} }


## Which items stay lit while the player picks the other side of the swap (mockup `idleView` swapPick).
## `origin_id` "" reads `swap.origin`. { origin, items: { id: { role, dim, tappable } } } for every find on the
## field and every pack entry. role: "origin", "legal", "twin" or "other". Legal items and the origin are lit;
## a twin is dimmed but tappable (it shows the refusal line); other items are dimmed and not tappable.
static func dim_map(snapshot: Dictionary, origin_id: String) -> Dictionary:
	var origin := origin_id if not origin_id.is_empty() else str(_swap(snapshot).get("origin", ""))
	var legal := legal_targets(snapshot, origin)
	var items := {}
	var ids: Array = _field_finds(snapshot).map(func(f: Dictionary) -> String: return str(f["find_id"]))
	ids.append_array(_slots(snapshot).map(func(s: Dictionary) -> String: return str(s.get("id", ""))))
	for id: String in ids:
		var role := "other"
		if id == origin:
			role = "origin"
		elif legal.has(id):
			role = "legal"
		elif not origin.is_empty() and is_twin_refusal(snapshot, origin, id):
			role = "twin"
		items[id] = { "role": role, "dim": role == "twin" or role == "other", "tappable": role == "legal" or role == "twin" }
	return { "origin": origin, "items": items }


# ---------------------------------------------------------------------------
# Snapshot readers
# ---------------------------------------------------------------------------

static func _data(snapshot: Dictionary) -> Dictionary:
	var d: Variant = snapshot.get("data", {})
	return d if d is Dictionary else {}


static func _swap(snapshot: Dictionary) -> Dictionary:
	var s: Variant = _data(snapshot).get("swap", {})
	return s if s is Dictionary else {}


static func _strings(v: Variant) -> Array:
	var out: Array = []
	for x: Variant in (v if v is Array else []):
		out.append(str(x))
	return out


static func _finds(snapshot: Dictionary) -> Array:
	var v: Variant = _data(snapshot).get("finds", [])
	return (v as Array).filter(func(f: Variant) -> bool: return f is Dictionary) if v is Array else []


static func _field_finds(snapshot: Dictionary) -> Array:
	return _finds(snapshot).filter(func(f: Dictionary) -> bool: return _ON_FIELD.has(str(f.get("status", ""))))


static func _slots(snapshot: Dictionary) -> Array:
	var pack_v: Variant = _data(snapshot).get("pack", {})
	var v: Variant = (pack_v as Dictionary).get("slots", []) if pack_v is Dictionary else []
	return (v as Array).filter(func(s: Variant) -> bool: return s is Dictionary) if v is Array else []


## { id, side, type_id, name, slot, cell } of a field find or a pack entry; {} when the id is neither.
static func _item(snapshot: Dictionary, id: String) -> Dictionary:
	for f: Dictionary in _field_finds(snapshot):
		if str(f["find_id"]) == id:
			return { "id": id, "side": SIDE_FIELD, "type_id": str(f.get("type_id", "")), "name": str(f.get("name", "")),
				"slot": -1, "cell": int(f.get("cell", 0)) }
	var slots := _slots(snapshot)
	for i in slots.size():
		if str((slots[i] as Dictionary).get("id", "")) == id:
			return { "id": id, "side": SIDE_PACK, "type_id": str((slots[i] as Dictionary).get("type_id", "")),
				"name": str((slots[i] as Dictionary).get("name", "")), "slot": i, "cell": -1 }
	return {}


## The find id behind a pack entry id of this event, "" for a held piece. Same prefix rule as the snapshot builder.
static func _find_id_of_pack_id(snapshot: Dictionary, pack_id: String) -> String:
	var prefix := "item:%s:" % str(_data(snapshot).get("situation_id", ""))
	if not pack_id.begins_with(prefix):
		return ""
	var fid := pack_id.trim_prefix(prefix)
	for f: Dictionary in _finds(snapshot):
		if str(f.get("find_id", "")) == fid:
			return fid
	return ""


static func _dropped_of(snapshot: Dictionary, pack: Dictionary) -> Dictionary:
	var fid := ""
	for s: Dictionary in _slots(snapshot):
		if str(s.get("id", "")) == str(pack["id"]):
			fid = str(s.get("find_id", ""))
	var was_find := false
	for f: Dictionary in _finds(snapshot):
		if str(f.get("find_id", "")) == fid and str(f.get("status", "")) == "taken":
			was_find = not fid.is_empty()
	return { "id": str(pack["id"]), "type_id": str(pack["type_id"]), "name": str(pack["name"]),
		"was_find": was_find, "find_id": fid if was_find else "" }
