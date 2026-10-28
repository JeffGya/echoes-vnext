# res://tests/InventoryServiceTests.gd
# V2-ITEM-001a step 3: InventoryService (reads, intake, move, discard, snapshot, validate, take_in_order).
# Tests use their own cfg dictionaries and never depend on the PROVISIONAL numbers (D-25).
# Report: docs/stories/v2-item-001/step3-inventory-service.md

class_name InventoryServiceTests
extends RefCounted

const FIXTURE := "res://tests/fixtures/inventory_placeholders.json"
const _BANNED_EXACT := ["ase", "ekwan"]
const _BANNED_PART := ["thread", "partial", "recover"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_service/twins_get_different_ids_and_marks", Callable(InventoryServiceTests, "_t_twins"))
	runner.register_test("inventory_service/stack_merge_and_limit", Callable(InventoryServiceTests, "_t_stacks"))
	runner.register_test("inventory_service/intake_order_and_modes", Callable(InventoryServiceTests, "_t_order"))
	runner.register_test("inventory_service/duplicate_piece_id", Callable(InventoryServiceTests, "_t_duplicate"))
	runner.register_test("inventory_service/rejections", Callable(InventoryServiceTests, "_t_rejections"))
	runner.register_test("inventory_service/move_pack_to_sanctum", Callable(InventoryServiceTests, "_t_move"))
	runner.register_test("inventory_service/discard_outcomes", Callable(InventoryServiceTests, "_t_discard"))
	runner.register_test("inventory_service/pack_load_levels", Callable(InventoryServiceTests, "_t_pack_load"))
	runner.register_test("inventory_service/snapshot_is_deep_copy_without_banned_keys", Callable(InventoryServiceTests, "_t_snapshot"))
	runner.register_test("inventory_service/fixed_calls_give_the_pinned_save", Callable(InventoryServiceTests, "_t_pinned"))
	runner.register_test("inventory_service/cfg_of_the_wrong_type_does_not_crash", Callable(InventoryServiceTests, "_t_cfg_types"))
	runner.register_test("inventory_service/intake_moves_held_pieces_first", Callable(InventoryServiceTests, "_t_move_first"))
	runner.register_test("inventory_service/remove_held_and_held_pieces", Callable(InventoryServiceTests, "_t_remove_held"))
	runner.register_test("inventory_service/stack_above_a_lowered_limit", Callable(InventoryServiceTests, "_t_stack_below"))
	runner.register_test("inventory_service/missing_cfg_keys_and_bad_next_seq", Callable(InventoryServiceTests, "_t_missing_keys"))
	runner.register_test("inventory_service/gathered_above_capacity_is_reported", Callable(InventoryServiceTests, "_t_gathered_over"))
	runner.register_test("inventory_service/malformed_entries_do_not_throw", Callable(InventoryServiceTests, "_t_malformed"))
	runner.register_test("inventory_service/json_round_trip_same_behavior", Callable(InventoryServiceTests, "_t_round_trip"))
	runner.register_test("inventory_service/invariants_hold_after_every_mutation", Callable(InventoryServiceTests, "_t_invariants"))
	runner.register_test("inventory_service/take_in_order_shape", Callable(InventoryServiceTests, "_t_take_in_order"))
	runner.register_test("inventory_service/logger_gets_one_line", Callable(InventoryServiceTests, "_t_logger"))
	runner.register_test("inventory_service/mark_count_comes_from_the_config", Callable(InventoryServiceTests, "_t_mark_count"))
	runner.register_test("inventory_service/no_placeholder_in_config_or_new_save", Callable(InventoryServiceTests, "_t_no_placeholder"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _fresh() -> Dictionary:
	return { "inventory": { "version": 1, "next_seq": 1, "items": [], "stacks": [], "pack": [] } }


static func _defs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if parsed is Dictionary and (parsed as Dictionary).get("definitions", null) is Dictionary:
		return (parsed as Dictionary)["definitions"]
	return {}


static func _cfg(cap: int, pack: int, limit: int = 5, warn_room: int = 1, warn_pack: int = 1, with_defs: bool = true) -> Dictionary:
	return {
		"unique_cap": cap, "pack_capacity": pack, "stack_limit_default": limit,
		"warn_room_at": warn_room, "warn_pack_free_at": warn_pack,
		"kinds_enabled": { "gear": true, "relic": true, "consumable": true, "material": true },
		"grades": [], "recycle_yield_ekwan": {}, "definitions": _defs() if with_defs else {},
	}


static func _kind_of(type_id: String) -> String:
	var def: Variant = _defs().get(type_id, {})
	return str((def as Dictionary).get("kind", "")) if def is Dictionary else ""


static func _e(type_id: String, qty: int = 1, piece_id: String = "") -> Dictionary:
	return { "type_id": type_id, "kind": _kind_of(type_id), "grade": "g1", "quantity": qty, "piece_id": piece_id }


static func _direct(save: Dictionary, cfg: Dictionary, type_id: String, reserved: int = 0) -> Dictionary:
	return InventoryService.intake(save, cfg, _e(type_id), InventoryService.MODE_DIRECT, reserved)


static func _inv(save: Dictionary) -> Dictionary:
	return save["inventory"]


static func _ids(save: Dictionary, key: String) -> Array:
	var out: Array = []
	for p in _inv(save)[key]:
		out.append(str((p as Dictionary).get("id", "?")))
	return out


static func _json(v: Variant) -> String:
	return JSON.stringify(v, "", true)


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _expect(m: Array, res: Dictionary, result: String, reason: String, what: String) -> void:
	if str(res.get("result")) != result or str(res.get("reason_key")) != reason:
		m.append("%s: got %s/%s, expected %s/%s" % [what, str(res.get("result")), str(res.get("reason_key")), result, reason])


## Walks a Variant tree and reports a banned dictionary key.
static func _banned_key(v: Variant) -> String:
	if v is Dictionary:
		for k in (v as Dictionary).keys():
			var ks := str(k).to_lower()
			if _BANNED_EXACT.has(ks):
				return ks
			for part in _BANNED_PART:
				if ks.contains(part):
					return ks
			var inner := _banned_key((v as Dictionary)[k])
			if inner != "":
				return inner
	elif v is Array:
		for x in v:
			var inner2 := _banned_key(x)
			if inner2 != "":
				return inner2
	return ""


## The invariants of InventoryService, for a state reached by service calls only.
## `allowed` = substrings of `validate` lines that are expected (a gathered piece above capacity, a lowered cap).
static func _check_invariants(save: Dictionary, cfg: Dictionary, label: String, m: Array, allowed: Array = []) -> void:
	var ids := {}
	for key in ["items", "pack"]:
		for id in _ids(save, key):
			if ids.has(id):
				m.append("%s: duplicate id %s" % [label, id])
			ids[id] = true
	if InventoryService.unique_count(save) > int(cfg["unique_cap"]) and not allowed.has("above unique_cap"):
		m.append("%s: items above the cap" % label)
	if InventoryService.pack_count(save) > 0 and InventoryService.sanctum_room(save, cfg) > 0:
		m.append("%s: pack holds pieces while the Sanctum has room" % label)
	for prob in InventoryService.validate(save, cfg):
		var expected := false
		for a in allowed:
			if str(prob).contains(str(a)):
				expected = true
		if not expected:
			m.append("%s: validate says %s" % [label, str(prob)])


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_twins() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(8, 4)
	var a := _direct(save, cfg, "ph_weapon_a")
	var b := _direct(save, cfg, "ph_weapon_a")
	var c := _direct(save, cfg, "ph_armor_a")
	_expect(m, a, "stored", "ok", "first twin")
	if a["item_id"] != "it.1" or b["item_id"] != "it.2" or c["item_id"] != "it.3":
		m.append("ids %s %s %s, expected it.1 it.2 it.3" % [a["item_id"], b["item_id"], c["item_id"]])
	if int(_inv(save)["next_seq"]) != 4:
		m.append("next_seq %s, expected 4" % str(_inv(save)["next_seq"]))
	var snap := InventoryService.snapshot(save, cfg)
	var marks: Array = []
	for row in snap["items"]:
		marks.append("%s:%d" % [row["type_id"], row["mark_index"]])
	if marks != ["ph_weapon_a:1", "ph_weapon_a:2", "ph_armor_a:3"]:
		m.append("marks %s" % str(marks))
	# A mark is the id number modulo 6: discarding an older twin changes no other mark.
	InventoryService.discard(save, cfg, "it.1", true)
	var marks2: Array = []
	for row in InventoryService.snapshot(save, cfg)["items"]:
		marks2.append("%s:%d" % [row["type_id"], row["mark_index"]])
	if marks2 != ["ph_weapon_a:2", "ph_armor_a:3"]:
		m.append("marks after a discard %s" % str(marks2))
	var wrap := _fresh()
	var wide := _cfg(9, 2)
	for pid in ["it.6", "it.7", "it.12", "it.13"]:
		InventoryService.intake(wrap, wide, _e("ph_weapon_a", 1, pid), "direct")
	(_inv(wrap)["items"] as Array).append({ "id": "x.1", "type_id": "ph_weapon_a", "kind": "gear", "grade": "", "held_by": "" })
	var wrap_marks: Array = []
	for row in InventoryService.snapshot(wrap, wide)["items"]:
		wrap_marks.append(int(row["mark_index"]))
	if wrap_marks != [0, 1, 0, 1, 0]:
		m.append("wrapped marks %s, expected [0, 1, 0, 1, 0]" % str(wrap_marks))
	if (_inv(save)["items"][0] as Dictionary).get("held_by", null) != "":
		m.append("held_by is not the empty String")
	# A twin in the pack gets its mark from its own id: it.2 is minted second.
	var small := _cfg(1, 2)
	var save2 := _fresh()
	_direct(save2, small, "ph_weapon_a")
	_direct(save2, small, "ph_weapon_a")
	var snap2 := InventoryService.snapshot(save2, small)
	if (snap2["pack"] as Array).size() != 1 or int(snap2["pack"][0]["mark_index"]) != 2:
		m.append("pack twin snapshot %s" % _json(snap2["pack"]))
	return _result(m)


static func _t_stacks() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(8, 4, 5)
	var r1 := InventoryService.intake(save, cfg, _e("ph_material_a", 3), "direct")
	_expect(m, r1, "stored", "ok", "first add")
	var r2 := InventoryService.intake(save, cfg, _e("ph_material_a", 4), "direct")
	_expect(m, r2, "partial", "stack_limit", "second add")
	if r2["quantity"] != 2 or r2["lost_quantity"] != 2:
		m.append("partial quantities %s" % _json(r2))
	var r3 := InventoryService.intake(save, cfg, _e("ph_material_a", 1), "direct")
	_expect(m, r3, "lost", "stack_limit", "full stack")
	var stacks: Array = _inv(save)["stacks"]
	if stacks.size() != 1 or int(stacks[0]["quantity"]) != 5:
		m.append("stacks %s" % _json(stacks))
	# The definition override (ph_consumable_a limit 3) beats the default 5.
	var r4 := InventoryService.intake(save, cfg, _e("ph_consumable_a", 9), "gathered")
	_expect(m, r4, "partial", "stack_limit", "override limit")
	if r4["quantity"] != 3 or r4["lost_quantity"] != 6:
		m.append("override quantities %s" % _json(r4))
	# A stack never takes a pack slot and has no total cap.
	if InventoryService.pack_count(save) != 0 or InventoryService.unique_count(save) != 0:
		m.append("a stack touched items or pack")
	# A whole-stack loss on a new type creates no empty stack.
	var zero := _cfg(8, 4, 0)
	var save2 := _fresh()
	var r5 := InventoryService.intake(save2, zero, _e("ph_material_a", 2), "direct")
	_expect(m, r5, "lost", "stack_limit", "limit 0")
	if not (_inv(save2)["stacks"] as Array).is_empty():
		m.append("limit 0 created an empty stack")
	var snap := InventoryService.snapshot(save, cfg)
	var at_limit := 0
	for s in snap["stacks"]:
		if s["at_limit"]:
			at_limit += 1
	if at_limit != 2:
		m.append("at_limit count %d, expected 2" % at_limit)
	return _result(m)


static func _t_order() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(2, 2)
	_expect(m, _direct(save, cfg, "ph_weapon_a"), "stored", "ok", "A")
	_expect(m, _direct(save, cfg, "ph_charm_a"), "stored", "ok", "B")
	var c := _direct(save, cfg, "ph_relic_a")
	_expect(m, c, "packed", "to_pack", "C direct")
	if c["item_id"] != "it.3":
		m.append("C id %s" % c["item_id"])
	_expect(m, _direct(save, cfg, "ph_armor_a"), "packed", "to_pack", "D direct")
	var seq_before := int(_inv(save)["next_seq"])
	var e := _direct(save, cfg, "ph_armor_a")
	_expect(m, e, "lost", "overflow", "E direct, both full")
	if e["lost_quantity"] != 1 or e["item_id"] != "" or int(_inv(save)["next_seq"]) != seq_before:
		m.append("a lost piece must burn no id: %s" % _json(e))
	_check_invariants(save, cfg, "order", m)
	# A gathered piece owns its slot: it packs even when the pack count is at capacity.
	var g := InventoryService.intake(save, cfg, _e("ph_armor_a"), "gathered")
	_expect(m, g, "packed", "to_pack", "gathered with a full pack")
	# `reserved` slots count against a direct arrival.
	var save2 := _fresh()
	var small := _cfg(1, 2)
	_direct(save2, small, "ph_weapon_a")
	_expect(m, _direct(save2, small, "ph_charm_a", 2), "lost", "overflow", "direct with reserved 2")
	_expect(m, _direct(save2, small, "ph_charm_a", 1), "packed", "to_pack", "direct with reserved 1")
	if InventoryService.pack_free(save2, small, 1) != 0 or InventoryService.pack_free(save2, small, 0) != 1:
		m.append("pack_free with reserved")
	var bad := InventoryService.intake(save2, small, _e("ph_weapon_a"), "sideways")
	_expect(m, bad, "rejected", "bad_entry", "unknown mode")
	return _result(m)


static func _t_duplicate() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(1, 2)
	var r1 := InventoryService.intake(save, cfg, _e("ph_weapon_a", 1, "it.7"), "direct")
	_expect(m, r1, "stored", "ok", "supplied id")
	if r1["item_id"] != "it.7" or int(_inv(save)["next_seq"]) != 8:
		m.append("supplied id kept next_seq at %s, expected 8" % str(_inv(save)["next_seq"]))
	var before := _json(save)
	var r2 := InventoryService.intake(save, cfg, _e("ph_charm_a", 1, "it.7"), "direct")
	_expect(m, r2, "rejected", "duplicate", "same id in items")
	var r3 := InventoryService.intake(save, cfg, _e("ph_charm_a", 1, "it.9"), "direct")
	_expect(m, r3, "packed", "to_pack", "supplied id to pack")
	var mid := _json(save)
	var r4 := InventoryService.intake(save, cfg, _e("ph_armor_a", 1, "it.9"), "gathered")
	_expect(m, r4, "rejected", "duplicate", "same id in pack")
	if _json(save) != mid:
		m.append("a duplicate changed the save")
	if before == mid:
		m.append("test setup: the pack intake changed nothing")
	var r5 := InventoryService.intake(save, cfg, _e("ph_armor_a"), "gathered")
	if r5["item_id"] != "it.10":
		m.append("next minted id %s, expected it.10" % r5["item_id"])
	return _result(m)


## Intake with a bad entry. `save` holds a held piece that a raised cap could move in, so a refusal that
## moved it would show in the JSON.
static func _refuse(m: Array, save: Dictionary, cfg: Dictionary, entry: Dictionary, mode: String, reason: String, what: String) -> void:
	var before := _json(save)
	_expect(m, InventoryService.intake(save, cfg, entry, mode), "rejected", reason, what)
	if _json(save) != before:
		m.append("%s changed the save" % what)


static func _t_rejections() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var small := _cfg(1, 3)
	_direct(save, small, "ph_weapon_a")
	_direct(save, small, "ph_charm_a")
	if _ids(save, "pack") != ["it.2"]:
		return { "ok": false, "error": "test setup: pack %s" % str(_ids(save, "pack")) }
	var cfg := _cfg(4, 2)
	var e1 := _e("ph_weapon_a")
	e1["kind"] = "sword"
	_refuse(m, save, cfg, e1, "direct", "unknown_kind", "unknown kind")
	var e2 := _e("ph_weapon_a")
	e2.erase("kind")
	_refuse(m, save, cfg, e2, "direct", "unknown_kind", "missing kind")
	var off := _cfg(4, 2)
	(off["kinds_enabled"] as Dictionary)["relic"] = false
	_refuse(m, save, off, _e("ph_relic_a"), "direct", "kind_disabled", "relic off")
	_refuse(m, save, cfg, _e("ph_nothing"), "direct", "unknown_kind", "kind-less type")
	var e3 := _e("ph_nothing")
	e3["kind"] = "gear"
	_refuse(m, save, cfg, e3, "direct", "unknown_type", "type not in definitions")
	var e4 := _e("ph_weapon_a")
	e4["type_id"] = ""
	_refuse(m, save, cfg, e4, "direct", "bad_entry", "empty type_id")
	_refuse(m, save, cfg, _e("ph_material_a", 0), "direct", "bad_entry", "quantity 0")
	_refuse(m, save, cfg, _e("ph_weapon_a"), "sideways", "bad_entry", "unknown mode")
	var e5 := _e("ph_weapon_a")
	e5["kind"] = "relic"
	_refuse(m, save, cfg, e5, "direct", "bad_entry", "entry kind differs from the definition kind")
	var e6 := _e("ph_material_a", 1)
	e6["kind"] = "consumable"
	_refuse(m, save, cfg, e6, "direct", "bad_entry", "stack entry kind differs from the definition kind")
	_refuse(m, save, cfg, _e("ph_weapon_a", 2), "direct", "bad_entry", "unique piece with quantity 2")
	_refuse(m, save, cfg, _e("ph_weapon_a", 0), "direct", "bad_entry", "unique piece with quantity 0")
	for bad_id in ["it.007", "it.+5", "it.-5", "it.0", "it.", "it.1234567890123456", "it.5x", "x.5", " it.5", "it.1.5"]:
		_refuse(m, save, cfg, _e("ph_weapon_a", 1, bad_id), "direct", "bad_entry", "piece_id %s" % bad_id)
	var e7 := _e("ph_weapon_a")
	e7["piece_id"] = 5
	_refuse(m, save, cfg, e7, "direct", "bad_entry", "non-String piece_id")
	var b := _json(save)
	_expect(m, InventoryService.intake({}, cfg, _e("ph_weapon_a"), "direct"), "rejected", "bad_state", "no block")
	var no_defs := _cfg(4, 2, 5, 1, 1, false)
	_expect(m, InventoryService.intake(save, no_defs, e3, "direct"), "stored", "ok", "empty definitions accept any type")
	if _json(save) == b:
		m.append("test setup: the accepted piece left no trace")
	# The accepted piece moved the held it.2 in first and took it.3 after it.
	if _ids(save, "items") != ["it.1", "it.2", "it.3"] or int(_inv(save)["next_seq"]) != 4:
		m.append("accepted piece: items %s, next_seq %s" % [str(_ids(save, "items")), str(_inv(save)["next_seq"])])
	var edge := _fresh()
	_expect(m, InventoryService.intake(edge, cfg, _e("ph_weapon_a", 1, "it.999999999999999"), "direct"), "stored", "ok", "15-digit id")
	if int(_inv(edge)["next_seq"]) != 1000000000000000:
		m.append("15-digit id next_seq %s" % str(_inv(edge)["next_seq"]))
	return _result(m)


static func _t_move() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(1, 4)
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a"]:
		_direct(save, cfg, t)
	if _ids(save, "pack") != ["it.2", "it.3", "it.4"]:
		m.append("setup pack %s" % str(_ids(save, "pack")))
	if InventoryService.move_pack_to_sanctum(save, cfg) != 0:
		m.append("moved with no room")
	var cfg3 := _cfg(3, 4)
	if InventoryService.move_pack_to_sanctum(save, cfg3) != 2:
		m.append("expected 2 moved")
	if _ids(save, "items") != ["it.1", "it.2", "it.3"] or _ids(save, "pack") != ["it.4"]:
		m.append("oldest-first order broken: items %s pack %s" % [str(_ids(save, "items")), str(_ids(save, "pack"))])
	if InventoryService.move_pack_to_sanctum(save, _cfg(9, 4)) != 1 or InventoryService.pack_count(save) != 0:
		m.append("final move")
	_check_invariants(save, _cfg(9, 4), "move", m)
	return _result(m)


static func _t_discard() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(2, 3)
	_direct(save, cfg, "ph_weapon_a")
	_direct(save, cfg, "ph_charm_a")
	_direct(save, cfg, "ph_relic_a")
	_direct(save, cfg, "ph_armor_a")
	InventoryService.intake(save, cfg, _e("ph_material_a", 2), "direct")
	var snapshot_before := _json(save)
	var r := InventoryService.discard(save, cfg, "it.1", false)
	_expect(m, r, "refused", "not_in_sanctum", "off path")
	r = InventoryService.discard(save, cfg, "it.99", true)
	_expect(m, r, "refused", "not_found", "unknown id")
	r = InventoryService.discard(save, cfg, "ph_material_a", true)
	_expect(m, r, "refused", "not_unique", "stack id")
	(_inv(save)["items"][1] as Dictionary)["held_by"] = "echo.1"
	r = InventoryService.discard(save, cfg, "it.2", true)
	_expect(m, r, "refused", "equipped", "equipped piece")
	(_inv(save)["items"][1] as Dictionary)["held_by"] = ""
	if _json(save) != snapshot_before:
		m.append("a refusal changed the save")
	# Pack piece, Sanctum full: frees a pack slot, moves nothing.
	r = InventoryService.discard(save, cfg, "it.4", true)
	_expect(m, r, "discarded", "ok", "pack piece")
	if r["moved"] != 0 or _ids(save, "pack") != ["it.3"] or InventoryService.unique_count(save) != 2:
		m.append("pack-piece discard: %s, pack %s" % [_json(r), str(_ids(save, "pack"))])
	# Sanctum piece: the oldest held piece moves in.
	r = InventoryService.discard(save, cfg, "it.1", true)
	_expect(m, r, "discarded", "ok", "Sanctum piece")
	if r["moved"] != 1 or _ids(save, "items") != ["it.2", "it.3"] or InventoryService.pack_count(save) != 0:
		m.append("Sanctum-piece discard: %s, items %s" % [_json(r), str(_ids(save, "items"))])
	_check_invariants(save, cfg, "discard", m)
	# A pack-piece discard also moves held pieces in when a raised cap left room.
	var save2 := _fresh()
	var tight := _cfg(1, 3)
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		_direct(save2, tight, t)
	var r2 := InventoryService.discard(save2, _cfg(2, 3), "it.3", true)
	_expect(m, r2, "discarded", "ok", "pack piece with room")
	if r2["moved"] != 1 or _ids(save2, "items") != ["it.1", "it.2"] or InventoryService.pack_count(save2) != 0:
		m.append("pack-piece discard with room: %s, items %s, pack %s" % [_json(r2), str(_ids(save2, "items")), str(_ids(save2, "pack"))])
	return _result(m)


static func _t_pack_load() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(1, 4, 5, 1, 1)
	var save := _fresh()
	_direct(save, cfg, "ph_weapon_a")
	var expect := [[0, 0, 0], [1, 1, 1], [2, 1, 1], [3, 2, 2], [4, 3, 3]]
	for step in expect.size():
		var pl := InventoryService.pack_load(save, cfg, 0)
		var want: Array = expect[step]
		if pl["carried"] != want[0] or pl["level"] != want[1]:
			m.append("pack %d: %s, expected carried %d level %d" % [step, _json(pl), want[0], want[1]])
		if step < 4:
			_direct(save, cfg, "ph_charm_a")
	# `reserved` counts as carried.
	var pl2 := InventoryService.pack_load(_fresh(), cfg, 3)
	if pl2["carried"] != 3 or pl2["free"] != 1 or pl2["level"] != 2:
		m.append("reserved 3: %s" % _json(pl2))
	var pl3 := InventoryService.pack_load(_fresh(), _cfg(1, 0), 0)
	if pl3["level"] != 0 or pl3["capacity"] != 0:
		m.append("capacity 0: %s" % _json(pl3))
	# Capacity 0 with pieces carried (gathered pieces): full, and the warn flag is on.
	var zero_cfg := _cfg(1, 0)
	var zero := _fresh()
	_direct(zero, zero_cfg, "ph_weapon_a")
	InventoryService.intake(zero, zero_cfg, _e("ph_charm_a"), "gathered")
	var pl4 := InventoryService.pack_load(zero, zero_cfg, 0)
	if pl4["carried"] != 1 or pl4["free"] != 0 or pl4["level"] != 3:
		m.append("capacity 0 carrying: %s" % _json(pl4))
	if not InventoryService.snapshot(zero, zero_cfg)["warn"]["pack"]:
		m.append("capacity 0 carrying: warn.pack is off")
	# `warn_pack_free_at` above the capacity: level 2 when something is carried, 0 and no warning when not.
	var wide := _cfg(1, 2, 5, 1, 9)
	var pl5 := InventoryService.pack_load(_fresh(), wide, 0)
	if pl5["level"] != 0 or InventoryService.snapshot(_fresh(), wide)["warn"]["pack"]:
		m.append("warn_pack_free_at above capacity, empty pack: %s" % _json(pl5))
	var pl6 := InventoryService.pack_load(_fresh(), wide, 1)
	if pl6["level"] != 2 or not InventoryService.snapshot(_fresh(), wide, 1)["warn"]["pack"]:
		m.append("warn_pack_free_at above capacity, one carried: %s" % _json(pl6))
	var snap := InventoryService.snapshot(save, cfg)
	if not snap["warn"]["room"] or not snap["warn"]["pack"]:
		m.append("warn booleans %s" % _json(snap["warn"]))
	var calm := InventoryService.snapshot(_fresh(), _cfg(8, 4, 5, 2, 1))
	if calm["warn"]["room"] or calm["warn"]["pack"]:
		m.append("warn on an empty inventory %s" % _json(calm["warn"]))
	# `unique_cap` 0 is a full Sanctum: room 0 and the room warning is on.
	var no_room := InventoryService.snapshot(_fresh(), _cfg(0, 2))
	if no_room["sanctum_room"] != 0 or not no_room["warn"]["room"]:
		m.append("unique_cap 0: %s" % _json(no_room))
	return _result(m)


static func _t_snapshot() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(2, 2)
	for t in ["ph_weapon_a", "ph_weapon_a", "ph_relic_a"]:
		_direct(save, cfg, t)
	InventoryService.intake(save, cfg, _e("ph_material_a", 2), "direct")
	var before := _json(save)
	var snap := InventoryService.snapshot(save, cfg, 1)
	var banned := _banned_key(snap)
	if banned != "":
		m.append("projection carries the banned key %s" % banned)
	for key in ["unique_count", "unique_cap", "sanctum_room", "pack_count", "items", "pack", "stacks", "pack_load", "warn"]:
		if not snap.has(key):
			m.append("projection lacks %s" % key)
	# Mutate every level of the projection, then compare.
	(snap["items"] as Array)[0]["type_id"] = "x"
	(snap["items"] as Array).clear()
	(snap["pack"] as Array).append({ "id": "junk" })
	(snap["stacks"] as Array)[0]["quantity"] = 999
	(snap["pack_load"] as Dictionary)["level"] = 9
	if _json(save) != before:
		m.append("mutating the projection changed the save")
	var again := InventoryService.snapshot(save, cfg, 1)
	if again["pack_load"]["level"] != 3 or (again["items"] as Array).size() != 2:
		m.append("second projection %s" % _json(again))
	return _result(m)


static func _script(save: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	for t in ["ph_weapon_a", "ph_weapon_a", "ph_relic_a", "ph_charm_a", "ph_armor_a", "ph_armor_a"]:
		out.append(_direct(save, cfg, t))
	out.append(InventoryService.intake(save, cfg, _e("ph_material_a", 4), "gathered"))
	out.append(InventoryService.intake(save, cfg, _e("ph_consumable_a", 4), "direct"))
	out.append(InventoryService.intake(save, cfg, _e("ph_weapon_a", 1, "it.20"), "direct"))
	out.append(InventoryService.discard(save, cfg, "it.1", true))
	out.append(InventoryService.discard(save, cfg, "it.4", true))
	out.append({ "result": "moved", "reason_key": str(InventoryService.move_pack_to_sanctum(save, cfg)), "item_id": "" })
	out.append(InventoryService.intake(save, cfg, _e("ph_relic_a"), "gathered"))
	return out


const _PINNED_RESULTS := "stored/ok/it.1,stored/ok/it.2,stored/ok/it.3,packed/to_pack/it.4,packed/to_pack/it.5,lost/overflow/,stored/ok/,partial/stack_limit/,lost/overflow/,discarded/ok/it.1,discarded/ok/it.4,moved/0/,packed/to_pack/it.6"
const _PINNED_SAVE := '{"inventory":{"items":[{"grade":"g1","held_by":"","id":"it.2","kind":"gear","type_id":"ph_weapon_a"},{"grade":"g1","held_by":"","id":"it.3","kind":"relic","type_id":"ph_relic_a"},{"grade":"g1","held_by":"","id":"it.5","kind":"gear","type_id":"ph_armor_a"}],"next_seq":7,"pack":[{"grade":"g1","held_by":"","id":"it.6","kind":"relic","type_id":"ph_relic_a"}],"stacks":[{"kind":"material","quantity":4,"type_id":"ph_material_a"},{"kind":"consumable","quantity":3,"type_id":"ph_consumable_a"}],"version":1}}'


## A fixed call sequence gives exactly this save and these results. A change to either is a decision.
static func _t_pinned() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var results: Array = []
	for r in _script(save, _cfg(3, 2)):
		results.append("%s/%s/%s" % [r["result"], r["reason_key"], r["item_id"]])
	var got_results := ",".join(results)
	if got_results != _PINNED_RESULTS:
		m.append("results changed:\n%s" % got_results)
	if _json(save) != _PINNED_SAVE:
		m.append("save changed:\n%s" % _json(save))
	return _result(m)


static func _t_malformed() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(5, 3)
	var good := { "id": "it.1", "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1", "held_by": "" }
	var save := _fresh()
	save["inventory"]["items"] = [
		good, 42, null, "str",
		{ "id": 5, "type_id": "ph_weapon_a", "kind": "gear" },
		{ "id": "it.2", "kind": "gear" },
		{ "id": "it.3", "type_id": "ph_charm_a", "kind": "sword" },
		{ "id": "it.1", "type_id": "ph_armor_a", "kind": "gear", "held_by": "" },
		{ "id": "it.4", "type_id": "ph_relic_a", "kind": "relic", "held_by": 7 },
		{ "id": "it.9", "type_id": "ph_armor_a", "kind": "gear", "grade": 5 },
	]
	save["inventory"]["pack"] = [{ "id": "it.5", "type_id": "ph_charm_a", "kind": "gear", "held_by": "" }, [], { "type_id": "x" }]
	save["inventory"]["stacks"] = [
		{ "type_id": "ph_material_a", "kind": "material", "quantity": "many" }, 7,
		{ "kind": "material", "quantity": 2 }, { "type_id": "ph_material_a", "kind": "gear", "quantity": 2 },
		{ "type_id": "ph_consumable_a", "kind": "consumable", "quantity": 2.0 },
	]
	var want_probs := [
		"items[1]: not a Dictionary", "items[2]: not a Dictionary", "items[3]: not a Dictionary",
		"items[4]: bad id", "items[5]: bad type_id", "items[6]: bad kind",
		"items[7]: duplicate id it.1", "items[8]: bad held_by", "items[9]: bad grade",
		"pack[1]: not a Dictionary", "pack[2]: bad id",
		"items: 10 pieces above unique_cap 5",
		"stacks[0]: bad quantity", "stacks[1]: not a Dictionary", "stacks[2]: bad type_id", "stacks[3]: bad kind",
		"next_seq: not above the highest piece id",
	]
	var probs := InventoryService.validate(save, cfg)
	if probs != want_probs:
		m.append("validate gave %s, expected %s" % [str(probs), str(want_probs)])
	var snap := InventoryService.snapshot(save, cfg, 0)
	var item_ids: Array = []
	for row in snap["items"]:
		item_ids.append(row["id"])
	if item_ids != ["it.1"]:
		m.append("snapshot kept %s, expected only the first well-formed it.1" % str(item_ids))
	if snap["stacks"].size() != 1 or snap["stacks"][0]["quantity"] != 2:
		m.append("snapshot stacks %s" % _json(snap["stacks"]))
	InventoryService.intake(save, cfg, _e("ph_weapon_a"), "direct")
	InventoryService.intake(save, cfg, _e("ph_material_a", 1), "direct")
	var cons := InventoryService.intake(save, cfg, _e("ph_consumable_a", 1), "direct")
	if cons["result"] != "stored" or int(save["inventory"]["stacks"][4]["quantity"]) != 3:
		m.append("a float quantity was not merged: %s" % _json(cons))
	var minted := InventoryService.intake(save, cfg, _e("ph_weapon_a", 1, "it.1"), "direct")
	_expect(m, minted, "rejected", "duplicate", "duplicate of a good piece")
	var r := InventoryService.discard(save, cfg, "it.4", true)
	_expect(m, r, "refused", "equipped", "non-String held_by is never discarded")
	r = InventoryService.discard(save, cfg, "5", true)
	_expect(m, r, "refused", "not_found", "non-String id")
	InventoryService.move_pack_to_sanctum(save, cfg)
	if InventoryService.held_pieces(save).size() != 1 or InventoryService.remove_held(save, ["it.4", "it.1"]).size() != 0:
		m.append("held_pieces or remove_held touched a malformed or non-pack piece")
	# A save with a broken block is refused, never changed.
	for bad in [{}, { "inventory": 5 }, { "inventory": { "items": {} } }]:
		var copy: Dictionary = (bad as Dictionary).duplicate(true)
		_expect(m, InventoryService.intake(copy, cfg, _e("ph_weapon_a"), "direct"), "rejected", "bad_state", "bad block")
		_expect(m, InventoryService.discard(copy, cfg, "it.1", true), "refused", "bad_state", "bad block discard")
		if InventoryService.move_pack_to_sanctum(copy, cfg) != 0 or not InventoryService.remove_held(copy, ["it.1"]).is_empty() \
				or not InventoryService.held_pieces(copy).is_empty() or _json(copy) != _json(bad):
			m.append("a bad block was changed")
		InventoryService.snapshot(copy, cfg)
		if InventoryService.validate(copy, cfg).is_empty():
			m.append("validate called a bad block clean")
	if not InventoryService.validate(_fresh(), cfg).is_empty():
		m.append("validate flags a clean save")
	return _result(m)


static func _tail(save: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	out.append(InventoryService.intake(save, cfg, _e("ph_weapon_a"), "direct"))
	out.append(InventoryService.intake(save, cfg, _e("ph_material_a", 4), "direct"))
	out.append(InventoryService.intake(save, cfg, _e("ph_relic_a"), "gathered"))
	out.append(InventoryService.discard(save, cfg, "it.1", true))
	out.append({ "moved": InventoryService.move_pack_to_sanctum(save, cfg) })
	out.append(InventoryService.intake(save, cfg, _e("ph_charm_a"), "direct"))
	return out


static func _t_round_trip() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(2, 2)
	var save := _fresh()
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		_direct(save, cfg, t)
	InventoryService.intake(save, cfg, _e("ph_material_a", 3), "direct")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(save))
	if typeof(loaded["inventory"]["next_seq"]) != TYPE_FLOAT:
		m.append("test setup: the round trip did not make floats")
	var snap_a := _json(InventoryService.snapshot(save, cfg, 1))
	var snap_b := _json(InventoryService.snapshot(loaded, cfg, 1))
	if snap_a != snap_b:
		m.append("snapshots differ after a round trip:\n%s\n%s" % [snap_a, snap_b])
	if not InventoryService.validate(loaded, cfg).is_empty():
		m.append("round-tripped save is not clean: %s" % str(InventoryService.validate(loaded, cfg)))
	var ra := _tail(save, cfg)
	var rb := _tail(loaded, cfg)
	if _json(ra) != _json(rb):
		m.append("results differ after a round trip:\n%s\n%s" % [_json(ra), _json(rb)])
	if _json(InventoryService.snapshot(save, cfg)) != _json(InventoryService.snapshot(loaded, cfg)):
		m.append("final snapshots differ")
	return _result(m)


static func _t_invariants() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(3, 2, 4)
	var save := _fresh()
	var types := ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a", "ph_material_a", "ph_consumable_a"]
	var allowed: Array = ["above pack_capacity"]
	var x := 12345
	for step in 160:
		x = (x * 1103515245 + 12345) % 2147483648
		var pick := (x >> 8) % 12
		var label := "step %d" % step
		var type_id: String = types[(x >> 12) % types.size()]
		var qty := 1 + (x >> 4) % 3 if type_id.contains("material") or type_id.contains("consumable") else 1
		var count_before := InventoryService.unique_count(save)
		if step == 80:
			cfg = _cfg(2, 2, 4)
			allowed.append("above unique_cap")
		if pick < 4:
			InventoryService.intake(save, cfg, _e(type_id, qty), "direct", (x >> 3) % 2)
		elif pick < 6:
			InventoryService.intake(save, cfg, _e(type_id, qty), "gathered")
		elif pick < 7:
			InventoryService.intake(save, cfg, _e(types[(x >> 12) % 4], 1, "it.%d" % (1 + (x >> 5) % 40)), "direct")
		elif pick < 10:
			var all := _ids(save, "items") + _ids(save, "pack")
			if not all.is_empty():
				InventoryService.discard(save, cfg, all[(x >> 6) % all.size()], true)
		else:
			InventoryService.move_pack_to_sanctum(save, cfg)
		if InventoryService.unique_count(save) > count_before and InventoryService.unique_count(save) > int(cfg["unique_cap"]):
			m.append("%s: a call put a piece in items above the cap" % label)
		_check_invariants(save, cfg, label, m, allowed)
		if m.size() > 3:
			break
	return _result(m)


static func _t_take_in_order() -> Dictionary:
	var m: Array = []
	var finds := [{ "find_id": "f1" }, { "find_id": "f2" }, { "find_id": "f3" }]
	var r := InventoryService.take_in_order(finds, 2)
	var want := { "model": "find_order", "chooser_id": "", "taken": ["f1", "f2"], "left": ["f3"], "draws": 0 }
	if _json(r) != _json(want):
		m.append("2 slots: %s" % _json(r))
	if _json(InventoryService.take_in_order(finds, 0)["taken"]) != "[]" or (InventoryService.take_in_order(finds, 0)["left"] as Array).size() != 3:
		m.append("0 slots")
	if (InventoryService.take_in_order(finds, 9)["left"] as Array).size() != 0 or (InventoryService.take_in_order(finds, -4)["taken"] as Array).size() != 0:
		m.append("many or negative slots")
	if (InventoryService.take_in_order([], 3)["taken"] as Array).size() != 0:
		m.append("no finds")
	# A find that is not a Dictionary is skipped and takes no slot.
	var mixed := InventoryService.take_in_order([5, null, "x", { "find_id": "a" }, [], { "find_id": "b" }, { "other": 1 }], 2)
	if _json(mixed["taken"]) != _json(["a", "b"]) or _json(mixed["left"]) != _json([""]):
		m.append("non-Dictionary finds: %s" % _json(mixed))
	return _result(m)


# ---------------------------------------------------------------------------
# Review-fix tests
# ---------------------------------------------------------------------------

static func _t_cfg_types() -> Dictionary:
	var m: Array = []
	# A kinds_enabled value that is not exactly true disables the kind.
	for v in ["yes", [], {}, 1, 0, null, "true", [true], { "a": true }]:
		var save := _fresh()
		var cfg := _cfg(4, 2)
		(cfg["kinds_enabled"] as Dictionary)["gear"] = v
		var before := _json(save)
		_expect(m, InventoryService.intake(save, cfg, _e("ph_weapon_a"), "direct"), "rejected", "kind_disabled", "kinds_enabled.gear = %s" % _json(v))
		if _json(save) != before:
			m.append("kind_disabled changed the save")
	# kinds_enabled itself of the wrong type, or without the kind: unknown_kind.
	for v2 in ["x", [], 5, null, { "relic": true }]:
		var cfg2 := _cfg(4, 2)
		cfg2["kinds_enabled"] = v2
		_expect(m, InventoryService.intake(_fresh(), cfg2, _e("ph_weapon_a"), "direct"), "rejected", "unknown_kind", "kinds_enabled = %s" % _json(v2))
	# Numbers and tables of the wrong type read as 0 or as absent; no call may throw.
	for bad in ["x", [], {}, null, true, 1.5]:
		var cfg3 := _cfg(4, 2)
		for key in ["unique_cap", "pack_capacity", "stack_limit_default", "warn_room_at", "warn_pack_free_at"]:
			cfg3[key] = bad
		var save3 := _fresh()
		var lbl := "numbers = %s" % _json(bad)
		_expect(m, InventoryService.intake(save3, cfg3, _e("ph_weapon_a"), "direct"), "lost", "overflow", lbl)
		_expect(m, InventoryService.intake(save3, cfg3, _e("ph_weapon_a"), "gathered"), "packed", "to_pack", lbl + " gathered")
		_expect(m, InventoryService.intake(save3, cfg3, _e("ph_material_a", 2), "direct"), "lost", "stack_limit", lbl + " stack")
		InventoryService.snapshot(save3, cfg3, 1)
		InventoryService.validate(save3, cfg3)
		InventoryService.pack_load(save3, cfg3, 1)
		InventoryService.discard(save3, cfg3, "it.1", true)
		InventoryService.move_pack_to_sanctum(save3, cfg3)
	for dv in ["x", [], 5, null, true]:
		var cfg4 := _cfg(4, 2)
		cfg4["definitions"] = dv
		var s4 := _fresh()
		_expect(m, InventoryService.intake(s4, cfg4, _e("ph_weapon_a"), "direct"), "stored", "ok", "definitions = %s" % _json(dv))
		_expect(m, InventoryService.intake(s4, cfg4, _e("ph_material_a", 9), "direct"), "partial", "stack_limit", "definitions = %s stack" % _json(dv))
		InventoryService.snapshot(s4, cfg4)
		InventoryService.validate(s4, cfg4)
	# A definition of the wrong shape.
	var cfg5 := _cfg(4, 2)
	(cfg5["definitions"] as Dictionary)["ph_armor_a"] = "junk"
	_expect(m, InventoryService.intake(_fresh(), cfg5, _e("ph_armor_a"), "direct"), "rejected", "unknown_type", "definition is a String")
	var cfg6 := _cfg(4, 2)
	(cfg6["definitions"] as Dictionary)["ph_armor_a"] = { "kind": ["gear"], "grade": 7 }
	_expect(m, InventoryService.intake(_fresh(), cfg6, _e("ph_armor_a"), "direct"), "rejected", "bad_entry", "definition kind is an Array")
	var cfg7 := _cfg(4, 2, 5)
	(cfg7["definitions"] as Dictionary)["ph_material_a"] = { "kind": "material", "stack_limit": "many" }
	var s7 := _fresh()
	_expect(m, InventoryService.intake(s7, cfg7, _e("ph_material_a", 9), "direct"), "partial", "stack_limit", "stack_limit is a String")
	if int(_inv(s7)["stacks"][0]["quantity"]) != 5:
		m.append("a wrong-typed stack_limit did not fall back to the default")
	var cfg8 := _cfg(4, 2)
	(cfg8["definitions"] as Dictionary)["ph_weapon_a"] = { "kind": "gear", "grade": 7 }
	var s8 := _fresh()
	var e8 := _e("ph_weapon_a")
	e8.erase("grade")
	InventoryService.intake(s8, cfg8, e8, "direct")
	if _inv(s8)["items"][0]["grade"] != "":
		m.append("a non-String definition grade was stored: %s" % _json(_inv(s8)["items"]))
	return _result(m)


static func _t_move_first() -> Dictionary:
	var m: Array = []
	var tight := _cfg(1, 3)
	var save := _fresh()
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a"]:
		_direct(save, tight, t)
	if _ids(save, "items") != ["it.1"] or _ids(save, "pack") != ["it.2", "it.3"]:
		return { "ok": false, "error": "test setup: items %s pack %s" % [str(_ids(save, "items")), str(_ids(save, "pack"))] }
	var raised := _cfg(3, 2)
	# A stack intake leaves the held pieces where they are.
	var stacked := save.duplicate(true)
	InventoryService.intake(stacked, raised, _e("ph_material_a", 1), "direct")
	if _ids(stacked, "pack") != ["it.2", "it.3"]:
		m.append("a stack intake moved held pieces: %s" % str(_ids(stacked, "pack")))
	# Cap 3: it.2 and it.3 move in first; the new piece then goes to the pack by the normal rule.
	var a := save.duplicate(true)
	var ra := _direct(a, raised, "ph_armor_a")
	_expect(m, ra, "packed", "to_pack", "new piece after the move")
	if _ids(a, "items") != ["it.1", "it.2", "it.3"] or _ids(a, "pack") != ["it.4"] or ra["item_id"] != "it.4":
		m.append("cap 3: items %s pack %s result %s" % [str(_ids(a, "items")), str(_ids(a, "pack")), _json(ra)])
	# Cap 4: the new piece takes the last Sanctum slot and the pack ends empty.
	var b := save.duplicate(true)
	_expect(m, _direct(b, _cfg(4, 2), "ph_armor_a"), "stored", "ok", "new piece with room left")
	if _ids(b, "items") != ["it.1", "it.2", "it.3", "it.4"] or InventoryService.pack_count(b) != 0:
		m.append("cap 4: items %s pack %s" % [str(_ids(b, "items")), str(_ids(b, "pack"))])
	# Cap 2: one held piece moves in; the new piece goes to the pack behind the other.
	var c := save.duplicate(true)
	_expect(m, InventoryService.intake(c, _cfg(2, 3), _e("ph_armor_a"), "gathered"), "packed", "to_pack", "gathered with one slot of room")
	if _ids(c, "items") != ["it.1", "it.2"] or _ids(c, "pack") != ["it.3", "it.4"]:
		m.append("cap 2: items %s pack %s" % [str(_ids(c, "items")), str(_ids(c, "pack"))])
	# A lost piece still lets the held pieces in.
	var d := save.duplicate(true)
	_expect(m, _direct(d, _cfg(2, 1), "ph_armor_a"), "lost", "overflow", "lost after the move")
	if _ids(d, "items") != ["it.1", "it.2"] or _ids(d, "pack") != ["it.3"]:
		m.append("lost case: items %s pack %s" % [str(_ids(d, "items")), str(_ids(d, "pack"))])
	_check_invariants(a, raised, "move-first a", m)
	_check_invariants(b, _cfg(4, 2), "move-first b", m)
	return _result(m)


static func _t_remove_held() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(1, 4)
	var save := _fresh()
	for t in ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_armor_a"]:
		_direct(save, cfg, t)
	var held := InventoryService.held_pieces(save)
	var held_ids: Array = []
	for row in held:
		held_ids.append(row["id"])
	if held_ids != ["it.2", "it.3", "it.4"]:
		m.append("held_pieces ids %s" % str(held_ids))
	if _json(held[1]) != _json({ "id": "it.3", "type_id": "ph_relic_a", "kind": "relic", "grade": "g1" }):
		m.append("held_pieces row %s" % _json(held[1]))
	held[0]["type_id"] = "x"
	(held as Array).clear()
	if _ids(save, "pack") != ["it.2", "it.3", "it.4"] or _inv(save)["pack"][0]["type_id"] != "ph_charm_a":
		m.append("held_pieces returned a live reference")
	var items_before := _json(_inv(save)["items"])
	var seq_before := int(_inv(save)["next_seq"])
	var removed := InventoryService.remove_held(save, ["it.4", "it.2", "it.99", 5, null, "it.1", ["it.3"]])
	var removed_ids: Array = []
	for row in removed:
		removed_ids.append(row["id"])
	if removed_ids != ["it.2", "it.4"]:
		m.append("removed %s, expected [it.2, it.4] in pack order" % str(removed_ids))
	if _json(removed[1]) != _json({ "id": "it.4", "type_id": "ph_armor_a", "kind": "gear", "grade": "g1" }):
		m.append("removed row %s" % _json(removed[1]))
	if _ids(save, "pack") != ["it.3"] or _json(_inv(save)["items"]) != items_before or int(_inv(save)["next_seq"]) != seq_before:
		m.append("remove_held changed more than the listed pack pieces")
	removed[0]["id"] = "junk"
	if _ids(save, "pack") != ["it.3"]:
		m.append("remove_held returned a live reference")
	if not InventoryService.remove_held(save, []).is_empty() or not InventoryService.remove_held(save, ["it.1", "it.2"]).is_empty():
		m.append("remove_held removed an unlisted, unknown or Sanctum piece")
	# The caller decides about the move: with room, the piece stays in the pack until it asks.
	if InventoryService.pack_count(save) != 1:
		m.append("remove_held moved a piece")
	if InventoryService.move_pack_to_sanctum(save, _cfg(3, 4)) != 1:
		m.append("move after remove_held")
	return _result(m)


static func _t_stack_below() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	_inv(save)["stacks"] = [{ "type_id": "ph_material_a", "kind": "material", "quantity": 5 }]
	var cfg := _cfg(4, 2, 3)
	var r := InventoryService.intake(save, cfg, _e("ph_material_a", 2), "direct")
	_expect(m, r, "lost", "stack_limit", "stack above a lowered limit")
	if r["quantity"] != 0 or r["lost_quantity"] != 2 or int(_inv(save)["stacks"][0]["quantity"]) != 5:
		m.append("lowered limit: %s, stack %s" % [_json(r), _json(_inv(save)["stacks"])])
	var row: Dictionary = InventoryService.snapshot(save, cfg)["stacks"][0]
	if not row["at_limit"] or row["limit"] != 3 or row["quantity"] != 5:
		m.append("snapshot row %s" % _json(row))
	if InventoryService.validate(save, cfg) != ["stacks[0]: quantity above the stack limit"]:
		m.append("validate: %s" % str(InventoryService.validate(save, cfg)))
	return _result(m)


static func _t_missing_keys() -> Dictionary:
	var m: Array = []
	var no_cap := _cfg(4, 2)
	no_cap.erase("unique_cap")
	var save := _fresh()
	_expect(m, _direct(save, no_cap, "ph_weapon_a"), "packed", "to_pack", "unique_cap missing")
	var snap := InventoryService.snapshot(save, no_cap)
	if snap["unique_cap"] != 0 or snap["sanctum_room"] != 0 or not snap["warn"]["room"]:
		m.append("unique_cap missing: %s" % _json(snap))
	var no_kinds := _cfg(4, 2)
	no_kinds.erase("kinds_enabled")
	_expect(m, InventoryService.intake(_fresh(), no_kinds, _e("ph_weapon_a"), "direct"), "rejected", "unknown_kind", "kinds_enabled missing")
	var no_defs := _cfg(4, 2)
	no_defs.erase("definitions")
	_expect(m, InventoryService.intake(_fresh(), no_defs, _e("ph_nothing_here", 1), "direct"), "rejected", "unknown_kind", "no kind in entry")
	var e := _e("ph_weapon_a")
	e["type_id"] = "anything"
	_expect(m, InventoryService.intake(_fresh(), no_defs, e, "direct"), "stored", "ok", "definitions missing")
	var none := {}
	_expect(m, InventoryService.intake(_fresh(), none, _e("ph_weapon_a"), "direct"), "rejected", "unknown_kind", "empty cfg")
	# next_seq invalid or missing: the next id sits above every piece id and next_seq is written back as an int.
	var cfg := _cfg(9, 2)
	for bad in ["x", null, 0, -5, 1.5, [], { "a": 1 }, true, 1e19]:
		var s := _fresh()
		_direct(s, cfg, "ph_weapon_a")
		_inv(s)["next_seq"] = bad
		var label := "next_seq = %s" % _json(bad)
		var found := InventoryService.validate(s, cfg)
		if found != ["next_seq: not above the highest piece id"]:
			m.append("%s: validate %s" % [label, str(found)])
		var r := _direct(s, cfg, "ph_charm_a")
		if r["item_id"] != "it.2" or typeof(_inv(s)["next_seq"]) != TYPE_INT or int(_inv(s)["next_seq"]) != 3:
			m.append("%s: id %s, next_seq %s" % [label, str(r["item_id"]), str(_inv(s)["next_seq"])])
		var r2 := InventoryService.intake(s, cfg, _e("ph_relic_a", 1, "it.9"), "direct")
		if r2["item_id"] != "it.9" or int(_inv(s)["next_seq"]) != 10:
			m.append("%s: supplied id %s, next_seq %s" % [label, str(r2["item_id"]), str(_inv(s)["next_seq"])])
	var missing := _fresh()
	_inv(missing).erase("next_seq")
	var rm := _direct(missing, cfg, "ph_weapon_a")
	if rm["item_id"] != "it.1" or int(_inv(missing)["next_seq"]) != 2:
		m.append("next_seq missing on an empty block: id %s, next_seq %s" % [str(rm["item_id"]), str(_inv(missing).get("next_seq"))])
	# A counter below an existing id never mints a taken id.
	var low := _fresh()
	_inv(low)["items"] = [{ "id": "it.1", "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1", "held_by": "" },
		{ "id": "it.2", "type_id": "ph_weapon_a", "kind": "gear", "grade": "g1", "held_by": "" }]
	_inv(low)["next_seq"] = 1
	var rl := _direct(low, cfg, "ph_charm_a")
	if rl["item_id"] != "it.3" or int(_inv(low)["next_seq"]) != 4:
		m.append("low next_seq: id %s, next_seq %s" % [str(rl["item_id"]), str(_inv(low)["next_seq"])])
	return _result(m)


static func _t_gathered_over() -> Dictionary:
	var m: Array = []
	var cfg := _cfg(1, 1)
	var save := _fresh()
	_direct(save, cfg, "ph_weapon_a")
	for t in ["ph_charm_a", "ph_relic_a", "ph_armor_a"]:
		_expect(m, InventoryService.intake(save, cfg, _e(t), "gathered"), "packed", "to_pack", "gathered " + t)
	if InventoryService.pack_count(save) != 3 or InventoryService.pack_free(save, cfg) != 0:
		m.append("pack %d, free %d" % [InventoryService.pack_count(save), InventoryService.pack_free(save, cfg)])
	var probs := InventoryService.validate(save, cfg)
	if probs != ["pack: 3 pieces above pack_capacity"]:
		m.append("validate: %s" % str(probs))
	_expect(m, _direct(save, cfg, "ph_weapon_a"), "lost", "overflow", "direct above capacity")
	var pl := InventoryService.pack_load(save, cfg, 0)
	if pl["level"] != 3 or pl["free"] != 0 or pl["carried"] != 3:
		m.append("pack_load %s" % _json(pl))
	return _result(m)


static func _t_logger() -> Dictionary:
	var m: Array = []
	var logger := StructuredLogger.new()
	var save := _fresh()
	var cfg := _cfg(2, 1)
	InventoryService.intake(save, cfg, _e("ph_weapon_a"), "direct", 0, logger, 5)
	InventoryService.discard(save, cfg, "it.1", true, logger, 6)
	var logs: Array = logger.get_logs()
	var types: Array = []
	for l in logs:
		types.append(str((l as Dictionary).get("type", "")))
	if types.count("inventory.intake") != 1 or types.count("inventory.discard") != 1:
		m.append("log types %s" % str(types))
	return _result(m)


static func _t_no_placeholder() -> Dictionary:
	var m: Array = []
	if InventorySaveTests._has_placeholder_id(FileAccess.get_file_as_string("res://data/balance.json")):
		m.append("data/balance.json holds a ph_ id")
	if InventorySaveTests._has_placeholder_id(JSON.stringify(SaveSchema.make_new_save(3))):
		m.append("a new save holds a ph_ id")
	var defs := _defs()
	for id in ["ph_weapon_a", "ph_charm_a", "ph_relic_a", "ph_consumable_a", "ph_material_a", "ph_armor_a"]:
		var d: Variant = defs.get(id, null)
		if not (d is Dictionary):
			m.append("fixture lacks %s" % id)
			continue
		var cost: Variant = (d as Dictionary).get("cost", null)
		if not (cost is Dictionary) or int((cost as Dictionary).get("ekwan", -1)) != 0 or int((cost as Dictionary).get("ase", -1)) != 0:
			m.append("%s cost is not { ekwan: 0, ase: 0 }" % id)
	if defs.size() != 6:
		m.append("fixture holds %d definitions, expected 6" % defs.size())
	return _result(m)


## L1: `mark_index` = id number modulo `data.inventory.mark_count`. A missing, zero, negative or wrong-type value
## reads as 6. The shipping balance.json must carry the key (its value is not pinned). One function (`mark_index_of`) serves the snapshot and the reports.
static func _t_mark_count() -> Dictionary:
	var m: Array = []
	var save := _fresh()
	var cfg := _cfg(20, 4)
	for i in 8:
		InventoryService.intake(save, cfg, _e("ph_weapon_a"), InventoryService.MODE_DIRECT)
	var default_marks: Array = []
	for row in InventoryService.snapshot(save, cfg)["items"]:
		default_marks.append(int((row as Dictionary)["mark_index"]))
	if str(default_marks) != str([1, 2, 3, 4, 5, 0, 1, 2]):
		m.append("no mark_count key: marks %s" % str(default_marks))
	var cfg4 := _cfg(20, 4)
	cfg4["mark_count"] = 4
	var marks4: Array = []
	for row in InventoryService.snapshot(save, cfg4)["items"]:
		marks4.append(int((row as Dictionary)["mark_index"]))
	if str(marks4) != str([1, 2, 3, 0, 1, 2, 3, 0]):
		m.append("mark_count 4: marks %s" % str(marks4))
	for bad in [0, -3, "x", null, 0.4]:
		var c := _cfg(20, 4)
		c["mark_count"] = bad
		if InventoryService.mark_count(c) != 6:
			m.append("mark_count %s reads as %d, expected 6" % [str(bad), InventoryService.mark_count(c)])
	var c1 := _cfg(20, 4)
	c1["mark_count"] = 1
	if InventoryService.mark_index_of(c1, "it.7") != 0 or InventoryService.mark_index_of(cfg4, "it.7") != 3 \
			or InventoryService.mark_index_of(cfg4, "bad") != 0 or InventoryService.mark_index_of(cfg, "it.7") != 1:
		m.append("mark_index_of: %d %d %d %d" % [InventoryService.mark_index_of(c1, "it.7"),
			InventoryService.mark_index_of(cfg4, "it.7"), InventoryService.mark_index_of(cfg4, "bad"),
			InventoryService.mark_index_of(cfg, "it.7")])
	var shipping: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var inv_cfg: Variant = ((shipping as Dictionary).get("data", {}) as Dictionary).get("inventory", {}) if shipping is Dictionary else {}
	if not (inv_cfg is Dictionary) or not ((inv_cfg as Dictionary).get("mark_count", null) is float) \
			or int((inv_cfg as Dictionary)["mark_count"]) < 1 or not (inv_cfg as Dictionary).has("_mark_count_comment"):
		m.append("balance.json data.inventory.mark_count must be a positive number with a comment (the value is not pinned)")
	return _result(m)
