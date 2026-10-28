class_name InventoryService
extends RefCounted

## The Sanctum inventory and the party pack. Pure statics on the `save` Dictionary (block `inventory`).
## No construction, no SaveService call, no scene tree, no RNG, no clock. The caller passes the tick `t`
## and a StructuredLogger when it wants a log line, and requests the save itself (`flow_ctx.request_save`).
## `cfg` is `ConfigService.get_inventory_cfg(...)`. A cfg value of the wrong type reads as 0 or as absent.
##
## Containers: `inventory.items` (unique pieces, the Sanctum, capped by `unique_cap`), `inventory.stacks`
## (consumables and materials, one stack per type, `stack_limit` each) and `inventory.pack` (held pieces).
## A cap that is lowered after a save can leave more pieces than the cap. No mutation drops a piece for it.
## Piece ids are minted at intake as `it.<n>`; a caller may supply one.
##
## Invariants (the tests assert them after every mutation):
##  1. Piece ids are unique across `items` and `pack`.
##  2. `intake` never puts a piece in `items` above `unique_cap`.
##  3. `intake` never puts a piece in `pack` while the Sanctum has room (`sanctum_room > 0`).
##  4. `discard`, `move_pack_to_sanctum` and a unique-piece `intake` that passes the entry checks run the
##     move first. They then leave `pack` empty or `sanctum_room == 0`, for every piece that can move
##     (a malformed piece stays). A raised cap leaves held pieces with room until the next such call.
## Reads never repair. `validate` lists problems; a read or a mutation skips a malformed entry.

const KIND_GEAR := "gear"
const KIND_RELIC := "relic"
const KIND_CONSUMABLE := "consumable"
const KIND_MATERIAL := "material"
const UNIQUE_KINDS: Array = [KIND_GEAR, KIND_RELIC]
const STACK_KINDS: Array = [KIND_CONSUMABLE, KIND_MATERIAL]
## `gathered`: the piece already owns a pack slot. `direct`: it needs a free pack slot.
const MODE_GATHERED := "gathered"
const MODE_DIRECT := "direct"
## Largest whole number a float holds exactly; JSON loads turn ints into floats.
const _SAFE_INT := 9007199254740992.0
const _SEQ_MAX_DIGITS := 15
const _MARK_COUNT := 6

# ---------------------------------------------------------------------------
# Reads (no mutation)
# ---------------------------------------------------------------------------

static func unique_count(save: Dictionary) -> int:
	return _arr(save, "items").size()


static func pack_count(save: Dictionary) -> int:
	return _arr(save, "pack").size()


static func sanctum_room(save: Dictionary, cfg: Dictionary) -> int:
	return maxi(0, _cfg_int(cfg, "unique_cap") - unique_count(save))


## `reserved` = pack slots held by gathered item rows of the live stage.
static func pack_free(save: Dictionary, cfg: Dictionary, reserved: int = 0) -> int:
	return maxi(0, _cfg_int(cfg, "pack_capacity") - pack_count(save) - maxi(0, reserved))


## Level rule: 0 none (nothing carried); 3 full (no free slot); 2 heavy (free <= `warn_pack_free_at`);
## 1 light (anything else carried).
static func pack_load(save: Dictionary, cfg: Dictionary, reserved: int = 0) -> Dictionary:
	var carried := pack_count(save) + maxi(0, reserved)
	var capacity := _cfg_int(cfg, "pack_capacity")
	var free := pack_free(save, cfg, reserved)
	var level := 1
	if carried <= 0:
		level = 0
	elif free <= 0:
		level = 3
	elif free <= _cfg_int(cfg, "warn_pack_free_at"):
		level = 2
	return { "carried": carried, "capacity": capacity, "free": free, "level": level }


## The valid pieces of `pack` in pack order, as copies `{ id, type_id, kind, grade }`. A malformed piece
## and a second piece with a repeated id are left out.
static func held_pieces(save: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for key in ["items", "pack"]:
		for p_v in _arr(save, key):
			if piece_problem(p_v) != "" or seen.has((p_v as Dictionary)["id"]):
				continue
			seen[(p_v as Dictionary)["id"]] = true
			if key == "pack":
				out.append(_row(p_v))
	return out


## Immutable projection for UI and readiness: a fresh tree built from scalars, so a caller cannot reach
## the save through it. Piece rows carry the real `id` for core callers. The UI layer must NOT print it:
## it tells twins apart with `mark_index`, the number part of the piece id modulo 6 (0 when the id has no
## valid number). Discarding another piece never changes a mark.
## It holds no Thread, partial-recovery, Ase or Ekwan key. A malformed piece is left out.
static func snapshot(save: Dictionary, cfg: Dictionary, reserved: int = 0) -> Dictionary:
	var items_out: Array = []
	var pack_out: Array = []
	for p in _collect_pieces(save):
		var row := {
			"id": p["id"], "type_id": p["type_id"], "kind": p["kind"], "grade": p["grade"],
			"mark_index": maxi(0, p["seq"]) % _MARK_COUNT, "equipped": p["equipped"],
		}
		if p["in_pack"]:
			pack_out.append(row)
		else:
			items_out.append(row)
	var stacks_out: Array = []
	for s_v in _arr(save, "stacks"):
		if _stack_problem(s_v) != "":
			continue
		var s: Dictionary = s_v
		var qty := _to_int(s["quantity"])
		var limit := _stack_limit(cfg, _def_of(cfg, str(s["type_id"])))
		stacks_out.append({ "type_id": str(s["type_id"]), "kind": str(s["kind"]), "quantity": qty,
			"limit": limit, "at_limit": qty >= limit })
	var room := sanctum_room(save, cfg)
	var load_info := pack_load(save, cfg, reserved)
	return {
		"unique_count": unique_count(save), "unique_cap": _cfg_int(cfg, "unique_cap"), "sanctum_room": room,
		"pack_count": pack_count(save), "pack_capacity": load_info["capacity"], "pack_free": load_info["free"],
		"items": items_out, "pack": pack_out, "stacks": stacks_out, "pack_load": load_info,
		"warn": {
			# `unique_cap` 0 gives room 0, so the Sanctum counts as full.
			"room": room <= _cfg_int(cfg, "warn_room_at"),
			"pack": load_info["carried"] > 0 and load_info["free"] <= _cfg_int(cfg, "warn_pack_free_at"),
		},
	}


## Problems found in the block, as strings. Empty when clean. Reads nothing it could repair.
static func validate(save: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	if not _block_ok(save):
		out.append("block: missing, not a Dictionary, or items/stacks/pack not an Array")
		return out
	var seen := {}
	for key in ["items", "pack"]:
		var arr := _arr(save, key)
		for i in arr.size():
			var prob := piece_problem(arr[i])
			if prob != "":
				out.append("%s[%d]: %s" % [key, i, prob])
				continue
			var id: String = (arr[i] as Dictionary)["id"]
			if seen.has(id):
				out.append("%s[%d]: duplicate id %s" % [key, i, id])
			seen[id] = true
	var cap := _cfg_int(cfg, "unique_cap")
	if unique_count(save) > cap:
		out.append("items: %d pieces above unique_cap %d" % [unique_count(save), cap])
	if pack_count(save) > _cfg_int(cfg, "pack_capacity"):
		out.append("pack: %d pieces above pack_capacity" % pack_count(save))
	if pack_count(save) > 0 and sanctum_room(save, cfg) > 0:
		out.append("pack: holds pieces while the Sanctum has room")
	var stack_types := {}
	var stacks := _arr(save, "stacks")
	for i in stacks.size():
		var sp := _stack_problem(stacks[i])
		if sp != "":
			out.append("stacks[%d]: %s" % [i, sp])
			continue
		var s: Dictionary = stacks[i]
		if stack_types.has(s["type_id"]):
			out.append("stacks[%d]: second stack of %s" % [i, s["type_id"]])
		stack_types[s["type_id"]] = true
		if _to_int(s["quantity"]) > _stack_limit(cfg, _def_of(cfg, str(s["type_id"]))):
			out.append("stacks[%d]: quantity above the stack limit" % i)
	var inv: Dictionary = save["inventory"]
	var top := 0
	for id_v in seen.keys():
		top = maxi(top, _seq_of(str(id_v)))
	if _to_int(inv.get("next_seq", 0)) <= top:
		out.append("next_seq: not above the highest piece id")
	return out


## "" when the piece is well formed, else the first problem. `grade` and `held_by` may be absent (read
## as ""); when present they must be Strings. SaveService repair uses this check too.
static func piece_problem(p: Variant) -> String:
	if not (p is Dictionary):
		return "not a Dictionary"
	var d: Dictionary = p
	var id_v: Variant = d.get("id", null)
	if not (id_v is String) or (id_v as String).is_empty():
		return "bad id"
	var type_v: Variant = d.get("type_id", null)
	if not (type_v is String) or (type_v as String).is_empty():
		return "bad type_id"
	if not UNIQUE_KINDS.has(d.get("kind", null)):
		return "bad kind"
	if d.has("grade") and not (d["grade"] is String):
		return "bad grade"
	if d.has("held_by") and not (d["held_by"] is String):
		return "bad held_by"
	return ""


# ---------------------------------------------------------------------------
# Mutations. A refusal changes nothing.
# ---------------------------------------------------------------------------

## `entry` = { type_id, kind, grade, quantity, piece_id }. `quantity` is read for stacks; a unique piece
## has quantity 1 or none. `piece_id` is optional for a unique piece (empty mints `it.<next_seq>`; a given
## id must be `it.<n>`, n from 1 to 15 digits, no leading zero). A stack goes to its Sanctum stack and the
## surplus above the limit is lost. A unique piece first lets held pieces into the Sanctum, then goes to
## `items` when room exists, else to `pack` (`gathered`: always; `direct`: needs `pack_free`), else it is
## lost. A lost piece burns no id.
## Returns { result, reason_key, item_id, quantity, lost_quantity }.
static func intake(save: Dictionary, cfg: Dictionary, entry: Dictionary, mode: String, reserved: int = 0,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var res := _intake(save, cfg, entry, mode, reserved)
	if logger != null:
		logger.info(t, "inventory.intake", str(res["result"]), { "reason_key": res["reason_key"],
			"type_id": str(entry.get("type_id", "")), "item_id": res["item_id"], "mode": mode })
	return res


## Moves held pieces into the Sanctum, oldest first, while room exists. Returns how many moved.
static func move_pack_to_sanctum(save: Dictionary, cfg: Dictionary) -> int:
	if not _block_ok(save):
		return 0
	var inv: Dictionary = save["inventory"]
	var items: Array = inv["items"]
	var pack: Array = inv["pack"]
	var ids := _id_set(save)
	var room := sanctum_room(save, cfg)
	var kept: Array = []
	var moved := 0
	for p in pack:
		if room > 0 and piece_problem(p) == "" and int(ids.get((p as Dictionary)["id"], 0)) == 1:
			items.append(p)
			room -= 1
			moved += 1
		else:
			kept.append(p)
	inv["pack"] = kept
	return moved


## Removes the held pieces whose ids are listed, one piece per listed id, in pack order. An unknown id is
## ignored. Returns copies `{ id, type_id, kind, grade }` of the removed pieces. It draws nothing and does
## not move other held pieces: the caller decides whether to call `move_pack_to_sanctum`.
static func remove_held(save: Dictionary, ids: Array) -> Array:
	var removed: Array = []
	if not _block_ok(save):
		return removed
	var want := {}
	for id_v in ids:
		if id_v is String:
			want[id_v] = true
	var inv: Dictionary = save["inventory"]
	var kept: Array = []
	for p in inv["pack"]:
		if piece_problem(p) == "" and want.has((p as Dictionary)["id"]):
			want.erase((p as Dictionary)["id"])
			removed.append(_row(p))
		else:
			kept.append(p)
	inv["pack"] = kept
	return removed


## Discards one unique piece from `items` or `pack`. Only in the Sanctum. After a successful discard the
## held pieces move in while room exists. Returns { result: discarded|refused, reason_key, item_id, moved }.
static func discard(save: Dictionary, cfg: Dictionary, item_id: String, in_sanctum: bool,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var res := _discard(save, cfg, item_id, in_sanctum)
	if logger != null:
		logger.info(t, "inventory.discard", str(res["result"]), { "reason_key": res["reason_key"],
			"item_id": item_id, "moved": res["moved"] })
	return res


## Default piece choice: the first `free_slots` finds are taken, in find order. A replacement chooser keeps
## this output shape. Pure: no RNG, no save. A find that is not a Dictionary is skipped.
static func take_in_order(finds: Array, free_slots: int) -> Dictionary:
	var taken: Array = []
	var left: Array = []
	var slots := maxi(0, free_slots)
	for f in finds:
		if not (f is Dictionary):
			continue
		var fid: Variant = (f as Dictionary).get("find_id", "")
		if taken.size() < slots:
			taken.append(fid)
		else:
			left.append(fid)
	return { "model": "find_order", "chooser_id": "", "taken": taken, "left": left, "draws": 0 }


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _res(result: String, reason: String, item_id: String = "", quantity: int = 0, lost: int = 0) -> Dictionary:
	return { "result": result, "reason_key": reason, "item_id": item_id, "quantity": quantity, "lost_quantity": lost }


static func _row(p: Variant) -> Dictionary:
	var d: Dictionary = p
	return { "id": d["id"], "type_id": d["type_id"], "kind": d["kind"], "grade": str(d.get("grade", "")) }


## The entry checks `intake` runs after the mode check: "" when the entry may enter, else the reason key.
## Kind known and enabled, type id present and known (when definitions exist), definition kind equal, unique
## quantity 1 (when given), stack quantity a whole number of 1 or more. Pure.
static func check_entry(cfg: Dictionary, entry: Dictionary) -> String:
	var kind: Variant = entry.get("kind", null)
	var enabled_v: Variant = cfg.get("kinds_enabled", null)
	var enabled: Dictionary = enabled_v if enabled_v is Dictionary else {}
	if not (kind is String) or not (UNIQUE_KINDS.has(kind) or STACK_KINDS.has(kind)) or not enabled.has(kind):
		return "unknown_kind"
	if not (enabled[kind] is bool and enabled[kind]):
		return "kind_disabled"
	var type_v: Variant = entry.get("type_id", null)
	if not (type_v is String) or (type_v as String).is_empty():
		return "bad_entry"
	var defs: Variant = cfg.get("definitions", null)
	if defs is Dictionary and not (defs as Dictionary).is_empty():
		var def := _def_of(cfg, type_v as String)
		if def.is_empty():
			return "unknown_type"
		if not _is_str(def.get("kind", null), kind):
			return "bad_entry"
	if STACK_KINDS.has(kind):
		if _to_int(entry.get("quantity", 0)) < 1:
			return "bad_entry"
	elif entry.has("quantity") and _to_int(entry["quantity"], -1) != 1:
		return "bad_entry"
	return ""


static func _intake(save: Dictionary, cfg: Dictionary, entry: Dictionary, mode: String, reserved: int) -> Dictionary:
	if not _block_ok(save):
		return _res("rejected", "bad_state")
	if mode != MODE_GATHERED and mode != MODE_DIRECT:
		return _res("rejected", "bad_entry")
	var bad := check_entry(cfg, entry)
	if bad != "":
		return _res("rejected", bad)
	var kind: String = entry["kind"]
	var type_id: String = entry["type_id"]
	if STACK_KINDS.has(kind):
		return _intake_stack(save, cfg, entry, kind, type_id)
	return _intake_unique(save, cfg, entry, kind, type_id, mode == MODE_GATHERED, reserved)


static func _intake_stack(save: Dictionary, cfg: Dictionary, entry: Dictionary, kind: String, type_id: String) -> Dictionary:
	var qty := _to_int(entry.get("quantity", 0))
	var stacks: Array = (save["inventory"] as Dictionary)["stacks"]
	var limit := _stack_limit(cfg, _def_of(cfg, type_id))
	var found: Variant = null
	for s_v in stacks:
		if _stack_problem(s_v) == "" and s_v["type_id"] == type_id and s_v["kind"] == kind:
			found = s_v
			break
	var have := _to_int((found as Dictionary)["quantity"]) if found != null else 0
	var add := clampi(limit - have, 0, qty)
	var lost := qty - add
	if add > 0:
		if found != null:
			(found as Dictionary)["quantity"] = have + add
		else:
			stacks.append({ "type_id": type_id, "kind": kind, "quantity": add })
	if lost == 0:
		return _res("stored", "ok", "", add)
	return _res("partial" if add > 0 else "lost", "stack_limit", "", add, lost)


static func _intake_unique(save: Dictionary, cfg: Dictionary, entry: Dictionary, kind: String, type_id: String,
		gathered: bool, reserved: int) -> Dictionary:
	var inv: Dictionary = save["inventory"]
	var supplied: Variant = entry.get("piece_id", "")
	if supplied != null and not (supplied is String):
		return _res("rejected", "bad_entry")
	var pid: String = supplied if supplied != null else ""
	if not pid.is_empty() and _seq_of(pid) < 1:
		return _res("rejected", "bad_entry")
	var ids := _id_set(save)
	if not pid.is_empty() and ids.has(pid):
		return _res("rejected", "duplicate", pid)
	# Held pieces enter the Sanctum before the new piece takes a slot.
	move_pack_to_sanctum(save, cfg)
	var to_items := sanctum_room(save, cfg) > 0
	if not to_items and not gathered and pack_free(save, cfg, reserved) <= 0:
		return _res("lost", "overflow", "", 0, 1)
	var seq := maxi(1, _to_int(inv.get("next_seq", 1), 1))
	if pid.is_empty():
		while ids.has("it.%d" % seq):
			seq += 1
		pid = "it.%d" % seq
	inv["next_seq"] = maxi(seq, _seq_of(pid) + 1)
	var grade_v: Variant = entry.get("grade", _def_of(cfg, type_id).get("grade", ""))
	var piece := { "id": pid, "type_id": type_id, "kind": kind,
		"grade": grade_v if grade_v is String else "", "held_by": "" }
	if to_items:
		(inv["items"] as Array).append(piece)
		return _res("stored", "ok", pid, 1)
	(inv["pack"] as Array).append(piece)
	return _res("packed", "to_pack", pid, 1)


static func _discard(save: Dictionary, cfg: Dictionary, item_id: String, in_sanctum: bool) -> Dictionary:
	var refused := func(reason: String) -> Dictionary:
		return { "result": "refused", "reason_key": reason, "item_id": item_id, "moved": 0 }
	if not in_sanctum:
		return refused.call("not_in_sanctum")
	if not _block_ok(save):
		return refused.call("bad_state")
	var inv: Dictionary = save["inventory"]
	for key in ["items", "pack"]:
		var arr: Array = inv[key]
		for i in arr.size():
			if not (arr[i] is Dictionary) or not _is_str(arr[i].get("id", null), item_id):
				continue
			if not _is_str((arr[i] as Dictionary).get("held_by", ""), ""):
				return refused.call("equipped")
			arr.remove_at(i)
			var moved := move_pack_to_sanctum(save, cfg)
			return { "result": "discarded", "reason_key": "ok", "item_id": item_id, "moved": moved }
	for s_v in inv["stacks"]:
		if s_v is Dictionary and _is_str((s_v as Dictionary).get("type_id", null), item_id):
			return refused.call("not_unique")
	return refused.call("not_found")


# ---- shape checks ----

static func _block_ok(save: Dictionary) -> bool:
	var inv_v: Variant = save.get("inventory", null)
	if not (inv_v is Dictionary):
		return false
	var inv: Dictionary = inv_v
	return inv.get("items", null) is Array and inv.get("stacks", null) is Array and inv.get("pack", null) is Array


static func _stack_problem(s: Variant) -> String:
	if not (s is Dictionary):
		return "not a Dictionary"
	var d: Dictionary = s
	var type_v: Variant = d.get("type_id", null)
	if not (type_v is String) or (type_v as String).is_empty():
		return "bad type_id"
	if not STACK_KINDS.has(d.get("kind", null)):
		return "bad kind"
	if _to_int(d.get("quantity", null), -1) < 1:
		return "bad quantity"
	return ""


# ---- small helpers ----

## True only for a String equal to `want`; any other type compares false without an operator error.
static func _is_str(v: Variant, want: String) -> bool:
	return v is String and v == want


## Whole number as int, else `fallback`. Accepts a whole float within 2^53 (a JSON round trip).
static func _to_int(v: Variant, fallback: int = 0) -> int:
	var tv := typeof(v)
	if tv == TYPE_INT:
		return int(v)
	if tv == TYPE_FLOAT and is_finite(float(v)) and absf(float(v)) <= _SAFE_INT and float(v) == floorf(float(v)):
		return int(v)
	return fallback


static func _cfg_int(cfg: Dictionary, key: String) -> int:
	return maxi(0, _to_int(cfg.get(key, 0)))


## The live array in the save, or a detached [] when the block or the field is missing. Callers that
## write check `_block_ok` first.
static func _arr(save: Dictionary, key: String) -> Array:
	var inv_v: Variant = save.get("inventory", null)
	if inv_v is Dictionary:
		var a: Variant = (inv_v as Dictionary).get(key, null)
		if a is Array:
			return a
	return []


## A copy of the definition of a type, or {} when none exists.
static func _def_of(cfg: Dictionary, type_id: String) -> Dictionary:
	var defs: Variant = cfg.get("definitions", null)
	if defs is Dictionary and (defs as Dictionary).get(type_id, null) is Dictionary:
		return ((defs as Dictionary)[type_id] as Dictionary).duplicate()
	return {}


static func _stack_limit(cfg: Dictionary, def: Dictionary) -> int:
	var override := _to_int(def.get("stack_limit", 0))
	return override if override > 0 else _cfg_int(cfg, "stack_limit_default")


static func _id_set(save: Dictionary) -> Dictionary:
	var ids := {}
	for key in ["items", "pack"]:
		for p in _arr(save, key):
			if p is Dictionary and (p as Dictionary).get("id", null) is String:
				var id: String = (p as Dictionary)["id"]
				ids[id] = int(ids.get(id, 0)) + 1
	return ids


## N of `it.<N>` (N from 1 to 15 digits, no sign, no leading zero), or -1 for any other id.
static func _seq_of(id: String) -> int:
	if not id.begins_with("it."):
		return -1
	var n := id.substr(3)
	if n.is_empty() or n.length() > _SEQ_MAX_DIGITS or n.begins_with("0"):
		return -1
	for i in n.length():
		var c := n.unicode_at(i)
		if c < 48 or c > 57:
			return -1
	return n.to_int()


## Well-formed, first-seen pieces of `items` then `pack`, with the fields the snapshot needs.
static func _collect_pieces(save: Dictionary) -> Array:
	var all: Array = []
	var seen := {}
	for key in ["items", "pack"]:
		for p_v in _arr(save, key):
			if piece_problem(p_v) != "":
				continue
			var p: Dictionary = p_v
			if seen.has(p["id"]):
				continue
			seen[p["id"]] = true
			all.append({ "id": p["id"], "type_id": p["type_id"], "kind": p["kind"], "grade": str(p.get("grade", "")),
				"equipped": str(p.get("held_by", "")) != "", "in_pack": key == "pack", "seq": _seq_of(p["id"]) })
	return all
