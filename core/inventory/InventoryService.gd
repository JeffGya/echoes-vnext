class_name InventoryService
extends RefCounted

## The Sanctum inventory and the party pack. Pure statics on the `save` Dictionary (block `inventory`).
## No construction, no SaveService call, no scene tree, no RNG, no clock. The caller passes the tick `t`
## and a StructuredLogger when it wants a log line, and requests the save itself (`flow_ctx.request_save`).
## `cfg` is `ConfigService.get_inventory_cfg(...)`. A cfg value of the wrong type reads as 0 or as absent.
##
## Containers. The Sanctum holds `inventory.items` (unique pieces) and `inventory.stacks` (consumables and
## materials), together at most `unique_cap` entries. The party pack holds `inventory.pack` (pieces) and
## `inventory.pack_stacks` (stacks), together at most `pack_capacity` entries. A stack is one entry in one
## slot; a type may have several stacks, each up to `stack_limit`. Every entry has a saved integer `slot`
## inside its container. Intake and moves use the lowest free slot unless a slot is given.
## Tolerant read (not a shrink rule; D-41 defers the pack shrink rule and the Sanctum never shrinks): a stored slot at or above the size is kept as it is,
## and a new entry takes only a slot below the size. An entry with a missing, invalid or repeated slot reads as
## the lowest free slot, in array order, and gets that slot at the next mutation.
## Piece ids are minted at intake as `it.<n>`; a caller may supply one. A stack has no id: callers address
## any entry by container and slot.
##
## Invariants (the tests assert them after every mutation):
##  1. Piece ids are unique across `items` and `pack`.
##  2. `intake` never puts an entry in `items`/`stacks` above `unique_cap`.
##  3. Mode `direct` (the debug producer) never puts a piece in `pack` while the Sanctum has room (`sanctum_room > 0`).
##     Mode `pack_only` (D-49) puts finds in the pack by design, whatever the Sanctum holds.
##  4. No two entries of one container share a slot.
##  5. A move, a merge and a discard never mint an item. A move or a merge keeps the total quantity.
## Reads never repair. `validate` lists problems; a read or a mutation skips a malformed entry.

const KIND_GEAR := "gear"
const KIND_RELIC := "relic"
const KIND_CONSUMABLE := "consumable"
const KIND_MATERIAL := "material"
const UNIQUE_KINDS: Array = [KIND_GEAR, KIND_RELIC]
const STACK_KINDS: Array = [KIND_CONSUMABLE, KIND_MATERIAL]
## `direct`: Sanctum first, then a FREE pack slot (the F1 producer). `pack_only` (D-49): the settlement of a
## finished or abandoned path; a find owns a pack slot and goes to the pack only, never to the Sanctum.
const MODE_DIRECT := "direct"
const MODE_PACK_ONLY := "pack_only"
const BOX_SANCTUM := "sanctum"
const BOX_PACK := "pack"
const BOXES: Array = [BOX_SANCTUM, BOX_PACK]
## A held stack has no id. `held_pieces` and `remove_held` name it `stack:<type_id>:<pack slot>`.
const STACK_ID_PREFIX := "stack:"
## Largest whole number a float holds exactly; JSON loads turn ints into floats.
const _SAFE_INT := 9007199254740992.0
const _SEQ_MAX_DIGITS := 15
## Fallback for `data.inventory.mark_count` (a missing, zero or wrong-type value reads as this).
const _MARK_COUNT_DEFAULT := 6

# ---------------------------------------------------------------------------
# Reads (no mutation)
# ---------------------------------------------------------------------------

## Unique pieces in the Sanctum (malformed entries count).
static func unique_count(save: Dictionary) -> int:
	return _arr(save, "items").size()


## Entries in the Sanctum: pieces and stacks. This is the number `unique_cap` limits.
static func sanctum_used(save: Dictionary) -> int:
	return _arr(save, "items").size() + _arr(save, "stacks").size()


## Entries in the pack: pieces and stacks. This is the number `pack_capacity` limits.
static func pack_count(save: Dictionary) -> int:
	return _arr(save, "pack").size() + _arr(save, "pack_stacks").size()


static func sanctum_room(save: Dictionary, cfg: Dictionary) -> int:
	return maxi(0, box_size(cfg, BOX_SANCTUM) - sanctum_used(save))


## The configured number of slots of a container.
static func box_size(cfg: Dictionary, box: String) -> int:
	return _cfg_int(cfg, "unique_cap" if box == BOX_SANCTUM else "pack_capacity")


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


## How many different marks the UI has: `data.inventory.mark_count`, or 6 when it is missing or below 1.
static func mark_count(cfg: Dictionary) -> int:
	var n := _cfg_int(cfg, "mark_count")
	return n if n > 0 else _MARK_COUNT_DEFAULT


## The `mark_index` of a piece id: its number modulo `mark_count` (0 when the id has no valid number, -1 for
## the id of a held stack).
## The snapshot rows and the item report rows use this one function.
static func mark_index_of(cfg: Dictionary, piece_id: String) -> int:
	if piece_id.begins_with(STACK_ID_PREFIX):
		return -1
	return maxi(0, _seq_of(piece_id)) % mark_count(cfg)


## What the party carries, as copies: the valid pieces of `pack` in pack order `{ id, type_id, kind, grade }`,
## then the valid stacks of `pack_stacks` in array order `{ id, type_id, kind, grade: "", quantity, order }` with the
## id `stack:<type_id>:<slot>` (`order`: see `draw_id`). A malformed entry and a second piece with a repeated id are left out.
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
	var stacks := _arr(save, "pack_stacks")
	var refs: Array = (_layout(save, BOX_PACK)["entries"] as Array).filter(func(r): return bool(r["stack"]))
	for ref in refs:
		var row := _held_stack_row(stacks[ref["index"]], int(ref["slot"]))
		var rank := 0
		for other in refs:
			if int(other["slot"]) < int(ref["slot"]) and stacks[other["index"]]["type_id"] == row["type_id"]:
				rank += 1
		row["order"] = rank
		out.append(row)
	return out


## The name a leave draw uses for a carried entry. A piece: its id. A carried stack: `stack:<type_id>:<n>`, with
## n its order among the carried stacks of that type by slot (`order`), so moving it inside the pack never
## changes its draw.
static func draw_id(row: Dictionary) -> String:
	if row.has("order"):
		return "%s%s:%d" % [STACK_ID_PREFIX, row["type_id"], int(row["order"])]
	return str(row["id"])


## Immutable projection for UI and readiness: a fresh tree built from scalars, so a caller cannot reach
## the save through it. Piece rows carry the real `id` for core callers. The UI layer must NOT print it:
## it tells twins apart with `mark_index`, the number part of the piece id modulo `mark_count` (config,
## default 6; 0 when the id has no valid number). Discarding another piece never changes a mark.
## Every row carries `name` (the definition name, "" when the definition has none) and `slot`.
## Piece row: id, type_id, kind, grade, mark_index, equipped, name, slot.
## Stack row: type_id, kind, name, slot, count, stack_limit, at_limit.
## `items`/`stacks` are the Sanctum entries, `pack`/`pack_stacks` the pack entries. `unique_cap` and
## `pack_capacity` are the container sizes; a row `slot` may be at or above its size only for an entry written past the size (a gathered find) or read from outside data.
## It holds no Thread, partial-recovery, Ase or Ekwan key. A malformed entry is left out.
static func snapshot(save: Dictionary, cfg: Dictionary, reserved: int = 0) -> Dictionary:
	var items_out: Array = []
	var pack_out: Array = []
	var stacks_out: Array = []
	var pack_stacks_out: Array = []
	var seen := {}
	for box in BOXES:
		var pieces := _arr(save, _piece_key(box))
		var stacks := _arr(save, _stack_key(box))
		for ref in _layout(save, box)["entries"]:
			if bool(ref["stack"]):
				var s: Dictionary = stacks[ref["index"]]
				var type_id := str(s["type_id"])
				var qty := _to_int(s["quantity"])
				var limit := _stack_limit(cfg, _def_of(cfg, type_id))
				(stacks_out if box == BOX_SANCTUM else pack_stacks_out).append({
					"type_id": type_id, "kind": str(s["kind"]), "name": name_of(cfg, type_id),
					"slot": int(ref["slot"]), "count": qty, "stack_limit": limit, "at_limit": qty >= limit })
			else:
				var p: Dictionary = pieces[ref["index"]]
				if seen.has(p["id"]):
					continue
				seen[p["id"]] = true
				(items_out if box == BOX_SANCTUM else pack_out).append({
					"id": p["id"], "type_id": p["type_id"], "kind": p["kind"], "grade": str(p.get("grade", "")),
					"mark_index": maxi(0, _seq_of(p["id"])) % mark_count(cfg),
					"equipped": str(p.get("held_by", "")) != "",
					"name": name_of(cfg, str(p["type_id"])), "slot": int(ref["slot"]) })
	var room := sanctum_room(save, cfg)
	var load_info := pack_load(save, cfg, reserved)
	return {
		"unique_count": unique_count(save), "sanctum_used": sanctum_used(save),
		"unique_cap": box_size(cfg, BOX_SANCTUM), "sanctum_room": room,
		"pack_count": pack_count(save), "pack_capacity": load_info["capacity"], "pack_free": load_info["free"],
		"items": items_out, "stacks": stacks_out, "pack": pack_out, "pack_stacks": pack_stacks_out,
		"pack_load": load_info,
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
	var cap := box_size(cfg, BOX_SANCTUM)
	if sanctum_used(save) > cap:
		out.append("items: %d entries above unique_cap %d" % [sanctum_used(save), cap])
	if pack_count(save) > box_size(cfg, BOX_PACK):
		out.append("pack: %d entries above pack_capacity" % pack_count(save))
	for key in ["stacks", "pack_stacks"]:
		var stacks := _arr(save, key)
		for i in stacks.size():
			var sp := _stack_problem(stacks[i])
			if sp != "":
				out.append("%s[%d]: %s" % [key, i, sp])
				continue
			var s: Dictionary = stacks[i]
			if _to_int(s["quantity"]) > _stack_limit(cfg, _def_of(cfg, str(s["type_id"]))):
				out.append("%s[%d]: quantity above the stack limit" % [key, i])
	for box in BOXES:
		out.append_array(_slot_problems(save, cfg, box))
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
## id must be `it.<n>`, n from 1 to 15 digits, no leading zero).
## A unique piece (`direct`) goes to `items` when room exists, else to `pack` when `pack_free` is above 0, else it
## is lost. A lost piece burns no id. Mode `pack_only` (D-49): the piece goes to the pack
## slot its row owns (the lowest free one, one above the size if none is free), never to `items`; result
## `stored`/`ok`.
## A stack find (D-45) fills these steps in order, as far as the quantity goes: 1) merge into same-type Sanctum
## stacks with room; 2) new Sanctum stacks in free Sanctum slots, each up to the limit; 3) merge into same-type
## pack stacks with room; 4) new pack stacks in free pack slots (`pack_only`: one slot above the pack size if none
## is free; every further chunk and every `direct` chunk: only while `pack_free(reserved)` is above 0, with
## `reserved` = for `pack_only` the open item rows still to settle after this one); 5) the rest, for which no slot is left, is lost
## and always reports `overflow` (D-46); a find is never refused for its size. Result `stored`/`ok` when all stayed in the Sanctum,
## `packed`/`to_pack` when any went to the pack, `partial` when some was lost. Mode `pack_only` (D-49) skips steps
## 1 and 2: a stack find merges into a same-type pack stack, then starts pack stacks (steps 3 and 4) and never
## touches the Sanctum; result `stored`/`ok` when all of it was kept, `partial`/`overflow` when some was lost.
## Intake never moves the pack, and nothing else moves it on its own (D-42): only `move_entry` does.
## Returns { result, reason_key, item_id, quantity, lost_quantity }.
static func intake(save: Dictionary, cfg: Dictionary, entry: Dictionary, mode: String, reserved: int = 0,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var res := _intake(save, cfg, entry, mode, reserved)
	if logger != null:
		logger.info(t, "inventory.intake", str(res["result"]), { "reason_key": res["reason_key"],
			"type_id": str(entry.get("type_id", "")), "item_id": res["item_id"], "mode": mode })
	return res


## Removes held entries by id, one entry per listed id, pieces in pack order and then stacks. A piece id is its
## `id`; a held stack is named `stack:<type_id>:<slot>` as `held_pieces` lists it. An unknown id is ignored.
## Returns copies in the shape `held_pieces` lists: `{ id, type_id, kind, grade }` for a piece and the same plus
## `quantity` for a stack. It draws nothing and does not move other entries.
static func remove_held(save: Dictionary, ids: Array) -> Array:
	var removed: Array = []
	if not _block_ok(save):
		return removed
	var want := {}
	for id_v in ids:
		if id_v is String:
			want[id_v] = true
	var stack_cut := {}
	var pack_stacks := _arr(save, "pack_stacks")
	for ref in _layout(save, BOX_PACK)["entries"]:
		if bool(ref["stack"]):
			var row := _held_stack_row(pack_stacks[ref["index"]], int(ref["slot"]))
			if want.has(row["id"]):
				want.erase(row["id"])
				stack_cut[int(ref["index"])] = row
	var inv: Dictionary = save["inventory"]
	var kept: Array = []
	for p in inv["pack"]:
		if piece_problem(p) == "" and want.has((p as Dictionary)["id"]):
			want.erase((p as Dictionary)["id"])
			removed.append(_row(p))
		else:
			kept.append(p)
	inv["pack"] = kept
	if not stack_cut.is_empty():
		var kept_stacks: Array = []
		for i in pack_stacks.size():
			if stack_cut.has(i):
				removed.append(stack_cut[i])
			else:
				kept_stacks.append(pack_stacks[i])
		inv["pack_stacks"] = kept_stacks
	return removed


## Discards one unique piece, addressed by its id, from `items` or `pack`. Only in the Sanctum (`in_sanctum`; the
## caller applies the path rules). Nothing else moves. Returns { result: discarded|refused, reason_key, item_id }.
## Refusals: `not_in_sanctum`, `bad_state`, `equipped`, `not_unique` (the id names a stack type), `not_found`.
static func discard(save: Dictionary, cfg: Dictionary, item_id: String, in_sanctum: bool,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var res := _discard(save, cfg, item_id, in_sanctum)
	if logger != null:
		logger.info(t, "inventory.discard", str(res["result"]), { "reason_key": res["reason_key"],
			"item_id": item_id })
	return res


## Where the piece with this id sits: `{ box, slot }`, or {} when no valid piece has the id.
static func locate_piece(save: Dictionary, item_id: String) -> Dictionary:
	for box in BOXES:
		var pieces := _arr(save, _piece_key(box))
		for ref in _layout(save, box)["entries"]:
			if not bool(ref["stack"]) and _is_str(pieces[ref["index"]].get("id", null), item_id):
				return { "box": box, "slot": int(ref["slot"]) }
	return {}


## What sits at `box`/`slot`: `{ stack: bool, type_id, quantity }` (quantity 1 for a piece), or {} when empty.
static func entry_at(save: Dictionary, box: String, slot: int) -> Dictionary:
	var ref := _ref_at(save, box, slot)
	if ref.is_empty():
		return {}
	var e: Dictionary = _arr(save, ref["key"])[ref["index"]]
	return { "stack": bool(ref["stack"]), "type_id": str(e["type_id"]),
		"quantity": _to_int(e["quantity"]) if bool(ref["stack"]) else 1 }


## Discards the entry at `box`/`slot`. A piece takes no count (`count` -1 or 1). A stack takes `count` from 1 to
## its quantity: -1 means the whole stack; a smaller count lowers the quantity and keeps the slot. The caller
## applies the path rules. A refusal changes nothing.
## Returns { result: discarded|refused, reason_key, box, slot, count, remaining }.
## Refusals: `bad_state`, `bad_box`, `unknown_entry`, `equipped` (a piece held by an Echo), `count_range`.
static func discard_entry(save: Dictionary, cfg: Dictionary, box: String, slot: int, count: int = -1,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var res := _discard_entry(save, box, slot, count)
	if logger != null:
		logger.info(t, "inventory.discard", str(res["result"]), { "reason_key": res["reason_key"],
			"box": box, "slot": slot, "count": res["count"] })
	return res


## Moves, reorders or merges the entry at `from_box`/`from_slot`. `to_slot` -1 means the lowest free slot.
##  - Other container, free target slot or none given: the whole entry moves (result `moved`).
##  - Same container, free target slot: the slot changes (result `reordered`).
##  - Target slot holds a stack of the same type and the source is a stack: the target takes the source count up to
##    its stack limit (result `merged`); a remainder stays in the source slot; an emptied source is removed.
##    A merge needs no free slot, so it works into a full container.
## Any other occupied target slot is refused; nothing swaps. A refusal changes nothing.
## Returns { result: moved|reordered|merged|refused, reason_key, from_box, from_slot, to_box, to_slot, merged,
## remaining }. `merged` = quantity added to the target; `remaining` = quantity left in the source after a merge.
## Refusals: `bad_state`, `bad_box`, `unknown_entry`, `bad_slot` (target slot below 0 or at or above the size),
## `no_change` (same entry, or same container with no target slot), `slot_taken`, `type_mismatch` (a stack on a
## stack of another type), `stack_limit` (target stack already at its limit), `container_full`. A move into the
## pack counts `reserved` (open item rows) as taken slots.
static func move_entry(save: Dictionary, cfg: Dictionary, from_box: String, from_slot: int, to_box: String,
		to_slot: int = -1, logger: StructuredLogger = null, t: int = 0, reserved: int = 0) -> Dictionary:
	var res := _move_entry(save, cfg, from_box, from_slot, to_box, to_slot, reserved)
	if logger != null:
		logger.info(t, "inventory.move", str(res["result"]), { "reason_key": res["reason_key"],
			"from_box": from_box, "from_slot": from_slot, "to_box": to_box, "to_slot": to_slot })
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
	if mode != MODE_DIRECT and mode != MODE_PACK_ONLY:
		return _res("rejected", "bad_entry")
	var bad := check_entry(cfg, entry)
	if bad != "":
		return _res("rejected", bad)
	var kind: String = entry["kind"]
	var type_id: String = entry["type_id"]
	if STACK_KINDS.has(kind):
		return _intake_stack(save, cfg, entry, kind, type_id, mode, reserved)
	return _intake_unique(save, cfg, entry, kind, type_id, mode, reserved)


static func _intake_stack(save: Dictionary, cfg: Dictionary, entry: Dictionary, kind: String, type_id: String,
		mode: String, reserved: int) -> Dictionary:
	var pack_only := mode == MODE_PACK_ONLY
	var qty := _to_int(entry.get("quantity", 0))
	var limit := _stack_limit(cfg, _def_of(cfg, type_id))
	var left := qty
	var in_pack := 0
	var added := 0
	# 1. merge into same-type Sanctum stacks with room (array order)
	var take := 0 if pack_only else _stack_fill(save, "stacks", kind, type_id, limit, left)
	left -= take
	added += take
	# 2. new Sanctum stacks in free Sanctum slots
	while not pack_only and left > 0 and limit > 0 and sanctum_room(save, cfg) > 0:
		var slot := _first_free(_layout(save, BOX_SANCTUM), box_size(cfg, BOX_SANCTUM))
		if slot < 0:
			break
		_commit_layouts(save)
		var chunk := mini(limit, left)
		_live_arr(save, "stacks").append({ "type_id": type_id, "kind": kind, "quantity": chunk, "slot": slot })
		left -= chunk
		added += chunk
	# 3. merge into same-type pack stacks with room (needs no slot)
	take = _stack_fill(save, "pack_stacks", kind, type_id, limit, left)
	left -= take
	added += take
	in_pack += take
	# 4. new pack stacks in free pack slots. The FIRST new pack stack of a `pack_only` find uses the slot its row
	# owns (if none is free below the size, one slot above). Every further chunk, and every `direct` chunk, needs
	# `pack_free(reserved) > 0`; for `pack_only`, `reserved` = the open item rows still to settle after this one.
	var made := 0
	while left > 0 and limit > 0 and ((pack_only and made == 0) or pack_free(save, cfg, reserved) > 0):
		var lay := _layout(save, BOX_PACK)
		var slot2 := _first_free(lay, box_size(cfg, BOX_PACK))
		if slot2 < 0:
			if not pack_only or made > 0:
				break
			slot2 = _lowest_free(lay)
		_commit_layouts(save)
		var chunk2 := mini(limit, left)
		_live_arr(save, "pack_stacks").append({ "type_id": type_id, "kind": kind, "quantity": chunk2, "slot": slot2 })
		left -= chunk2
		added += chunk2
		in_pack += chunk2
		made += 1
	if left == 0:
		return _res("packed", "to_pack", "", added) if in_pack > 0 and not pack_only else _res("stored", "ok", "", added)
	# 5. what no slot holds is lost, always as `overflow` (D-46). Stored + lost = the find quantity.
	return _res("partial" if added > 0 else "lost", "overflow", "", added, left)


## Adds up to `want` to the same-type stacks of `key` that have room, in array order. Returns how much it added.
static func _stack_fill(save: Dictionary, key: String, kind: String, type_id: String, limit: int, want: int) -> int:
	var added := 0
	for s_v in _arr(save, key):
		if want - added <= 0:
			break
		if _stack_problem(s_v) != "" or s_v["type_id"] != type_id or s_v["kind"] != kind:
			continue
		var take := clampi(limit - _to_int((s_v as Dictionary)["quantity"]), 0, want - added)
		if take > 0:
			if added == 0:
				_commit_layouts(save)
			(s_v as Dictionary)["quantity"] = _to_int((s_v as Dictionary)["quantity"]) + take
			added += take
	return added


static func _intake_unique(save: Dictionary, cfg: Dictionary, entry: Dictionary, kind: String, type_id: String,
		mode: String, reserved: int) -> Dictionary:
	var pack_only := mode == MODE_PACK_ONLY
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
	var to_items := not pack_only and sanctum_room(save, cfg) > 0
	if not to_items and not pack_only and pack_free(save, cfg, reserved) <= 0:
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
	_commit_layouts(save)
	var box := BOX_SANCTUM if to_items else BOX_PACK
	var lay := _layout(save, box)
	var slot := _first_free(lay, box_size(cfg, box))
	piece["slot"] = slot if slot >= 0 else _lowest_free(lay)
	(inv[_piece_key(box)] as Array).append(piece)
	if to_items or pack_only:
		return _res("stored", "ok", pid, 1)
	return _res("packed", "to_pack", pid, 1)


static func _discard(save: Dictionary, cfg: Dictionary, item_id: String, in_sanctum: bool) -> Dictionary:
	var refused := func(reason: String) -> Dictionary:
		return { "result": "refused", "reason_key": reason, "item_id": item_id }
	if not in_sanctum:
		return refused.call("not_in_sanctum")
	if not _block_ok(save):
		return refused.call("bad_state")
	var at := locate_piece(save, item_id)
	if at.is_empty():
		for key in ["stacks", "pack_stacks"]:
			for s_v in _arr(save, key):
				if s_v is Dictionary and _is_str((s_v as Dictionary).get("type_id", null), item_id):
					return refused.call("not_unique")
		return refused.call("not_found")
	var res := _discard_entry(save, str(at["box"]), int(at["slot"]), -1)
	return { "result": res["result"], "reason_key": res["reason_key"], "item_id": item_id }


static func _discard_entry(save: Dictionary, box: String, slot: int, count: int) -> Dictionary:
	var refused := func(reason: String) -> Dictionary:
		return { "result": "refused", "reason_key": reason, "box": box, "slot": slot, "count": count, "remaining": 0 }
	if not BOXES.has(box):
		return refused.call("bad_box")
	if not _block_ok(save):
		return refused.call("bad_state")
	var ref := _ref_at(save, box, slot)
	if ref.is_empty():
		return refused.call("unknown_entry")
	var arr: Array = _arr(save, ref["key"])
	var e: Dictionary = arr[ref["index"]]
	var qty := 1
	if bool(ref["stack"]):
		qty = _to_int(e["quantity"])
		var n := qty if count == -1 else count
		if n < 1 or n > qty:
			return refused.call("count_range")
		count = n
	else:
		if count != -1 and count != 1:
			return refused.call("count_range")
		if not _is_str(e.get("held_by", ""), ""):
			return refused.call("equipped")
		count = 1
	_commit_layouts(save)
	var remaining := qty - count
	if remaining > 0:
		e["quantity"] = remaining
	else:
		arr.remove_at(ref["index"])
	return { "result": "discarded", "reason_key": "ok", "box": box, "slot": slot, "count": count, "remaining": remaining }


static func _move_entry(save: Dictionary, cfg: Dictionary, from_box: String, from_slot: int, to_box: String,
		to_slot: int, reserved: int) -> Dictionary:
	var out := func(result: String, reason: String, merged: int = 0, remaining: int = 0, landed: int = -1) -> Dictionary:
		return { "result": result, "reason_key": reason, "from_box": from_box, "from_slot": from_slot,
			"to_box": to_box, "to_slot": landed, "merged": merged, "remaining": remaining }
	if not BOXES.has(from_box) or not BOXES.has(to_box):
		return out.call("refused", "bad_box")
	if not _block_ok(save):
		return out.call("refused", "bad_state")
	var src := _ref_at(save, from_box, from_slot)
	if src.is_empty():
		return out.call("refused", "unknown_entry")
	var size := box_size(cfg, to_box)
	if to_slot < -1 or to_slot >= size:
		return out.call("refused", "bad_slot")
	var to_lay := _layout(save, to_box)
	var src_arr: Array = _arr(save, src["key"])
	var e: Dictionary = src_arr[src["index"]]
	var target: Dictionary = (to_lay["taken"] as Dictionary).get(to_slot, {}) if to_slot >= 0 else {}
	if not target.is_empty():
		if from_box == to_box and int(target["index"]) == int(src["index"]) and target["key"] == src["key"]:
			return out.call("refused", "no_change")
		if not (bool(src["stack"]) and bool(target["stack"])):
			return out.call("refused", "slot_taken")
		var t_stack: Dictionary = _arr(save, target["key"])[target["index"]]
		if t_stack["type_id"] != e["type_id"] or t_stack["kind"] != e["kind"]:
			return out.call("refused", "type_mismatch")
		var room := _stack_limit(cfg, _def_of(cfg, str(e["type_id"]))) - _to_int(t_stack["quantity"])
		if room <= 0:
			return out.call("refused", "stack_limit")
		_commit_layouts(save)
		var amount := mini(room, _to_int(e["quantity"]))
		t_stack["quantity"] = _to_int(t_stack["quantity"]) + amount
		var remaining := _to_int(e["quantity"]) - amount
		if remaining > 0:
			e["quantity"] = remaining
		else:
			src_arr.remove_at(src["index"])
		return out.call("merged", "ok", amount, remaining, to_slot)
	if from_box == to_box and to_slot < 0:
		return out.call("refused", "no_change")
	var slot := to_slot if to_slot >= 0 else _first_free(to_lay, size)
	# Open item rows own pack slots (D-17): a move into the pack cannot take them.
	var count_in_to := sanctum_used(save) if to_box == BOX_SANCTUM else pack_count(save) + maxi(0, reserved)
	if slot < 0 or (from_box != to_box and count_in_to >= size):
		return out.call("refused", "container_full")
	_commit_layouts(save)
	if from_box == to_box:
		e["slot"] = slot
		return out.call("reordered", "ok", 0, 0, slot)
	src_arr.remove_at(src["index"])
	e["slot"] = slot
	_live_arr(save, _stack_key(to_box) if bool(src["stack"]) else _piece_key(to_box)).append(e)
	return out.call("moved", "ok", 0, 0, slot)


# ---- slots ----

static func _piece_key(box: String) -> String:
	return "items" if box == BOX_SANCTUM else "pack"


static func _stack_key(box: String) -> String:
	return "stacks" if box == BOX_SANCTUM else "pack_stacks"


## The stored slot as a whole number of 0 or more, else -1.
static func _slot_of(entry: Variant) -> int:
	return maxi(-1, _to_int((entry as Dictionary).get("slot", null), -1))


## The slot layout of one container: `{ taken: { slot: ref }, entries: [ref] }`, `ref` = `{ key, index, slot,
## stack }` (`key` the save array, `index` its position). Entries are the well-formed pieces then the well-formed
## stacks, in array order. An entry keeps its stored slot when that is a whole number of 0 or more and no earlier
## entry holds it; the others take the lowest free numbers in array order. Pure: nothing is written.
static func _layout(save: Dictionary, box: String) -> Dictionary:
	var taken := {}
	var entries: Array = []
	var pending: Array = []
	for is_stack in [false, true]:
		var key := _stack_key(box) if is_stack else _piece_key(box)
		var arr := _arr(save, key)
		for i in arr.size():
			var bad := _stack_problem(arr[i]) if is_stack else piece_problem(arr[i])
			if bad != "":
				continue
			var ref := { "key": key, "index": i, "slot": _slot_of(arr[i]), "stack": is_stack }
			if int(ref["slot"]) >= 0 and not taken.has(ref["slot"]):
				taken[ref["slot"]] = ref
			else:
				pending.append(ref)
			entries.append(ref)
	var next := 0
	for ref in pending:
		while taken.has(next):
			next += 1
		ref["slot"] = next
		taken[next] = ref
	return { "taken": taken, "entries": entries }


## The lowest slot below `size` that no entry holds, or -1.
static func _first_free(layout: Dictionary, size: int) -> int:
	for i in size:
		if not (layout["taken"] as Dictionary).has(i):
			return i
	return -1


## The lowest slot that no entry holds, with no upper bound.
static func _lowest_free(layout: Dictionary) -> int:
	var i := 0
	while (layout["taken"] as Dictionary).has(i):
		i += 1
	return i


## The ref of the entry in `slot` of a container, or {}.
static func _ref_at(save: Dictionary, box: String, slot: int) -> Dictionary:
	var taken: Dictionary = _layout(save, box)["taken"]
	return taken.get(slot, {}) if slot >= 0 else {}


## Writes the effective slot into every well-formed entry of both containers. Call it right before a mutation
## writes, so a stored slot never differs from the layout the mutation used.
static func _commit_layouts(save: Dictionary) -> void:
	for box in BOXES:
		for ref in _layout(save, box)["entries"]:
			var e: Dictionary = _arr(save, ref["key"])[ref["index"]]
			if _slot_of(e) != int(ref["slot"]):
				e["slot"] = int(ref["slot"])


## Slot problems of one container, from the stored values: missing or invalid, used twice, at or above the size.
static func _slot_problems(save: Dictionary, cfg: Dictionary, box: String) -> Array:
	var out: Array = []
	var size := box_size(cfg, box)
	var used := {}
	for is_stack in [false, true]:
		var key := _stack_key(box) if is_stack else _piece_key(box)
		var arr := _arr(save, key)
		for i in arr.size():
			if (_stack_problem(arr[i]) if is_stack else piece_problem(arr[i])) != "":
				continue
			var slot := _slot_of(arr[i])
			if slot < 0:
				out.append("%s[%d]: missing or invalid slot" % [key, i])
			elif used.has(slot):
				out.append("%s[%d]: slot %d used twice" % [key, i, slot])
			else:
				used[slot] = true
				if slot >= size:
					out.append("%s[%d]: slot %d at or above the size %d" % [key, i, slot, size])
	return out


static func _held_stack_row(s: Dictionary, slot: int) -> Dictionary:
	return { "id": "%s%s:%d" % [STACK_ID_PREFIX, s["type_id"], slot], "type_id": s["type_id"], "kind": s["kind"],
		"grade": "", "quantity": _to_int(s["quantity"]) }


## The array in the save, created empty when missing. Callers check `_block_ok` first.
static func _live_arr(save: Dictionary, key: String) -> Array:
	var inv: Dictionary = save["inventory"]
	if not (inv.get(key, null) is Array):
		inv[key] = []
	return inv[key]


## The definition name of a type, or "" when there is none. Never the type id. The rows of the snapshot, the
## at-risk rows and the result rows use this one function.
static func name_of(cfg: Dictionary, type_id: String) -> String:
	var n: Variant = _def_of(cfg, type_id).get("name", "")
	return n if n is String else ""


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
