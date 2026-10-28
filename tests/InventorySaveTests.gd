# res://tests/InventorySaveTests.gd
# V2-ITEM-001a step 2: the `data.inventory` config block and the `inventory` save block.
# Covers: the new-save shape, the additive repair (missing block, wrong types, valid contents kept,
# id counter floor), the JSON round trip, `ConfigService.get_inventory_cfg`, the stage `held_fates`
# default, the placeholder leak guard and `economy.relics` staying as it was.
# Tests never depend on the PROVISIONAL numbers (D-25); `config_shape` checks key types only.
# Report: docs/stories/v2-item-001/step2-config-save.md

class_name InventorySaveTests
extends RefCounted


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("inventory_save/new_save_has_default_block", Callable(InventorySaveTests, "_t_new_save_block"))
	runner.register_test("inventory_save/old_save_gets_block_and_reports", Callable(InventorySaveTests, "_t_old_save_repaired"))
	runner.register_test("inventory_save/wrong_typed_block_is_repaired", Callable(InventorySaveTests, "_t_wrong_types"))
	runner.register_test("inventory_save/repair_keeps_valid_contents", Callable(InventorySaveTests, "_t_keeps_valid"))
	runner.register_test("inventory_save/repair_raises_next_seq_and_drops_junk", Callable(InventorySaveTests, "_t_seq_floor_and_junk"))
	runner.register_test("inventory_save/json_round_trip_keeps_ints", Callable(InventorySaveTests, "_t_json_round_trip"))
	runner.register_test("inventory_save/config_shape", Callable(InventorySaveTests, "_t_config_values"))
	runner.register_test("inventory_save/long_piece_id_is_ignored_for_next_seq", Callable(InventorySaveTests, "_t_long_id"))
	runner.register_test("inventory_save/bad_stack_quantity_is_dropped", Callable(InventorySaveTests, "_t_bad_quantity"))
	runner.register_test("inventory_save/huge_or_non_finite_counter_resets", Callable(InventorySaveTests, "_t_huge_counter"))
	runner.register_test("inventory_save/config_missing_returns_empty", Callable(InventorySaveTests, "_t_config_missing"))
	runner.register_test("inventory_save/stage_held_fates_default_and_repair", Callable(InventorySaveTests, "_t_held_fates"))
	runner.register_test("inventory_save/no_placeholder_in_config_or_new_save", Callable(InventorySaveTests, "_t_no_placeholder"))
	runner.register_test("inventory_save/economy_relics_unchanged", Callable(InventorySaveTests, "_t_relics_unchanged"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _default_block() -> Dictionary:
	return { "version": 1, "next_seq": 1, "items": [], "stacks": [], "pack": [] }


static func _piece(seq: int, type_id: String = "t_gear", kind: String = "gear") -> Dictionary:
	return { "id": "it.%d" % seq, "type_id": type_id, "kind": kind, "grade": "g0", "held_by": "" }


static func _repair(save: Dictionary, logger: StructuredLogger = null) -> bool:
	return SaveService._apply_additive_defaults_and_repairs(save, logger if logger != null else SaveBridgeTests._make_logger(), 0)


static func _config() -> ConfigService:
	var cfg := ConfigService.new()
	cfg.load_balance()
	return cfg


## True when a quoted or bare token starts with `ph_` (a placeholder id). "glyph_" is not a match.
static func _has_placeholder_id(text: String) -> bool:
	var re := RegEx.new()
	re.compile("(?<![A-Za-z0-9])ph_[A-Za-z0-9_]")
	return re.search(text) != null


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## A new save carries the block with the default shape. Counters are ints.
static func _t_new_save_block() -> Dictionary:
	var m: Array = []
	var save := SaveSchema.make_new_save(7)
	var inv_v: Variant = save.get("inventory", null)
	if not (inv_v is Dictionary):
		return { "ok": false, "error": "new save has no inventory Dictionary: %s" % str(inv_v) }
	var inv: Dictionary = inv_v
	if inv.keys().size() != 5:
		m.append("block keys %s, expected 5" % str(inv.keys()))
	if typeof(inv.get("version")) != TYPE_INT or int(inv["version"]) != 1:
		m.append("version %s, expected int 1" % str(inv.get("version")))
	if typeof(inv.get("next_seq")) != TYPE_INT or int(inv["next_seq"]) != 1:
		m.append("next_seq %s, expected int 1" % str(inv.get("next_seq")))
	for key in ["items", "stacks", "pack"]:
		if not (inv.get(key) is Array) or not (inv[key] as Array).is_empty():
			m.append("%s %s, expected []" % [key, str(inv.get(key))])
	# Two new saves never share the same arrays.
	var other := SaveSchema.make_new_save(8)
	(inv["items"] as Array).append(_piece(1))
	if not ((other["inventory"] as Dictionary)["items"] as Array).is_empty():
		m.append("two new saves share one items array")
	# A new save needs no repair for this block.
	var fresh := SaveSchema.make_new_save(9)
	var notes: Array = []
	if SaveService._repair_inventory_block(fresh, notes) or not notes.is_empty():
		m.append("repair changed a new save's block: %s" % str(notes))
	return _result(m)


## An old save (no block) gets the default block. The repair is reported in the `save.schema.repair` log.
static func _t_old_save_repaired() -> Dictionary:
	var m: Array = []
	var save := SaveBridgeTests._make_old_save()
	if save.has("inventory"):
		return { "ok": false, "error": "fixture old save already has inventory" }
	var logger := StructuredLogger.new()
	if not _repair(save, logger):
		m.append("repair of an old save returned false")
	if str(save.get("inventory")) != str(_default_block()):
		m.append("block after repair %s, expected %s" % [str(save.get("inventory")), str(_default_block())])
	var reported := false
	for e in logger.get_logs():
		if str(e.get("type", "")) != "save.schema.repair":
			continue
		var data_v: Variant = e.get("data", {})
		var notes_v: Variant = (data_v as Dictionary).get("notes", []) if data_v is Dictionary else []
		for note in (notes_v as Array):
			if str(note).begins_with("inventory block added"):
				reported = true
	if not reported:
		m.append("repair log has no 'inventory block added' note")
	# Second pass: the block is valid, so the block repair reports nothing.
	var notes2: Array = []
	if SaveService._repair_inventory_block(save, notes2) or not notes2.is_empty():
		m.append("second repair changed the block: %s" % str(notes2))
	return _result(m)


## A block of the wrong type, or with wrongly typed fields, is repaired field by field.
static func _t_wrong_types() -> Dictionary:
	var m: Array = []
	for bad in ["text", 5, [], null, 1.5]:
		var save := { "inventory": bad }
		var notes: Array = []
		if not SaveService._repair_inventory_block(save, notes) or str(save["inventory"]) != str(_default_block()):
			m.append("non-Dictionary block %s became %s" % [str(bad), str(save["inventory"])])
	var save2 := { "inventory": {
		"version": "1", "next_seq": -3, "items": "x", "stacks": 5, "pack": null } }
	var notes2: Array = []
	if not SaveService._repair_inventory_block(save2, notes2):
		m.append("wrongly typed fields reported no change")
	if str(save2["inventory"]) != str(_default_block()):
		m.append("wrongly typed fields became %s, expected the default block" % str(save2["inventory"]))
	if notes2.is_empty():
		m.append("wrongly typed fields left no repair note")
	# Missing fields in a Dictionary block.
	var save3 := { "inventory": { "items": [_piece(4)] } }
	var notes3: Array = []
	SaveService._repair_inventory_block(save3, notes3)
	var inv3: Dictionary = save3["inventory"]
	if (inv3["items"] as Array).size() != 1 or int(inv3["next_seq"]) != 5 or int(inv3["version"]) != 1:
		m.append("partial block became %s" % str(inv3))
	# A fractional float is not an integer: it falls back to 1.
	var save4 := { "inventory": { "version": 1.5, "next_seq": 2.5, "items": [], "stacks": [], "pack": [] } }
	SaveService._repair_inventory_block(save4, [])
	var inv4: Dictionary = save4["inventory"]
	if typeof(inv4["version"]) != TYPE_INT or int(inv4["version"]) != 1 or typeof(inv4["next_seq"]) != TYPE_INT or int(inv4["next_seq"]) != 1:
		m.append("fractional counters became %s" % str(inv4))
	return _result(m)


## A valid, populated block is not changed. The full repair pass leaves it equal, too.
static func _t_keeps_valid() -> Dictionary:
	var m: Array = []
	var block := {
		"version": 1, "next_seq": 6,
		"items": [_piece(1), _piece(3, "t_relic", "relic")],
		"stacks": [{ "type_id": "t_cons", "kind": "consumable", "quantity": 7 }, { "type_id": "t_mat", "kind": "material", "quantity": 20 }],
		"pack": [_piece(5)],
	}
	var save := SaveBridgeTests._make_old_save()
	save["inventory"] = block.duplicate(true)
	var before := JSON.stringify(save["inventory"])
	var notes: Array = []
	if SaveService._repair_inventory_block(save, notes) or not notes.is_empty():
		m.append("helper changed a valid block: %s" % str(notes))
	_repair(save)
	if JSON.stringify(save["inventory"]) != before:
		m.append("full repair changed a valid block: %s" % JSON.stringify(save["inventory"]))
	return _result(m)


## next_seq is raised above the highest piece id. A non-Dictionary entry is dropped. A good entry stays.
static func _t_seq_floor_and_junk() -> Dictionary:
	var m: Array = []
	var save := { "inventory": {
		"version": 1, "next_seq": 3,
		"items": [_piece(2), "junk", _piece(9), 4],
		"stacks": [{ "type_id": "t_cons", "kind": "consumable", "quantity": 3.0 }, null],
		"pack": [_piece(7)],
	} }
	var notes: Array = []
	if not SaveService._repair_inventory_block(save, notes):
		m.append("no change reported")
	var inv: Dictionary = save["inventory"]
	if int(inv["next_seq"]) != 10:
		m.append("next_seq %s, expected 10" % str(inv["next_seq"]))
	var ids: Array = []
	for p in (inv["items"] as Array):
		ids.append((p as Dictionary)["id"])
	if ids != ["it.2", "it.9"]:
		m.append("item ids %s, expected [it.2, it.9]" % str(ids))
	var stacks: Array = inv["stacks"]
	if stacks.size() != 1 or typeof((stacks[0] as Dictionary)["quantity"]) != TYPE_INT or int((stacks[0] as Dictionary)["quantity"]) != 3:
		m.append("stacks after repair %s" % str(stacks))
	if (inv["pack"] as Array).size() != 1:
		m.append("pack lost its valid piece")
	return _result(m)


## A JSON round trip turns ints into floats. The repair turns them back silently (no repair report) and keeps the contents.
static func _t_json_round_trip() -> Dictionary:
	var m: Array = []
	var save := SaveSchema.make_new_save(11)
	var inv: Dictionary = save["inventory"]
	inv["next_seq"] = 4
	(inv["items"] as Array).append(_piece(1))
	(inv["items"] as Array).append(_piece(2, "t_relic", "relic"))
	(inv["pack"] as Array).append(_piece(3))
	(inv["stacks"] as Array).append({ "type_id": "t_cons", "kind": "consumable", "quantity": 12 })
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(save))
	var linv: Dictionary = loaded["inventory"]
	# The fixture must show the float problem, or the test proves nothing.
	if typeof(linv["next_seq"]) != TYPE_FLOAT:
		m.append("fixture: next_seq did not become a float after JSON (type %d)" % typeof(linv["next_seq"]))
	# A whole float is valid. The block repair must report no change, or every load would rewrite the save.
	var round_notes: Array = []
	if SaveService._repair_inventory_block(loaded, round_notes) or not round_notes.is_empty():
		m.append("repair reported a change for a valid JSON-loaded block: %s" % str(round_notes))
	_repair(loaded)
	linv = loaded["inventory"]
	for key in ["version", "next_seq"]:
		if typeof(linv[key]) != TYPE_INT:
			m.append("%s is type %d after repair, expected int" % [key, typeof(linv[key])])
	if int(linv["next_seq"]) != 4 or int(linv["version"]) != 1:
		m.append("counters changed: %s" % str(linv))
	var qty: Variant = ((linv["stacks"] as Array)[0] as Dictionary)["quantity"]
	if typeof(qty) != TYPE_INT or int(qty) != 12:
		m.append("stack quantity %s (type %d), expected int 12" % [str(qty), typeof(qty)])
	if (linv["items"] as Array).size() != 2 or (linv["pack"] as Array).size() != 1:
		m.append("items or pack changed: %s" % str(linv))
	if str(((linv["items"] as Array)[1] as Dictionary)["id"]) != "it.2":
		m.append("piece id changed")
	return _result(m)


## get_inventory_cfg returns the expected keys with the expected types. No value is checked (D-25).
static func _t_config_values() -> Dictionary:
	var m: Array = []
	var cfg := ConfigService.get_inventory_cfg(_config())
	if cfg.is_empty():
		return { "ok": false, "error": "get_inventory_cfg returned {} for the shipping config" }
	for key in ["unique_cap", "pack_capacity", "stack_limit_default", "warn_room_at", "warn_pack_free_at"]:
		if not (typeof(cfg.get(key)) == TYPE_INT or typeof(cfg.get(key)) == TYPE_FLOAT):
			m.append("%s is not a number" % key)
	for key in ["kinds_enabled", "recycle_yield_ekwan", "definitions"]:
		if not (cfg.get(key) is Dictionary):
			m.append("%s is not a Dictionary" % key)
	if not (cfg.get("grades") is Array):
		m.append("grades is not an Array")
	return _result(m)


## A null service or a service with no balance loaded returns {}.
static func _t_config_missing() -> Dictionary:
	var m: Array = []
	if not ConfigService.get_inventory_cfg(null).is_empty():
		m.append("null service did not return {}")
	if not ConfigService.get_inventory_cfg(ConfigService.new()).is_empty():
		m.append("service with no balance loaded did not return {}")
	return _result(m)


## A new stage has `held_fates: []`. The repair adds it to an old stage, fixes a wrong type, keeps content.
static func _t_held_fates() -> Dictionary:
	var m: Array = []
	var made := StageModel.make(0, "combat", 1, [], {})
	if not (made.get("held_fates") is Array) or not (made["held_fates"] as Array).is_empty():
		m.append("StageModel.make gave held_fates %s, expected []" % str(made.get("held_fates")))
	var save := SaveBridgeTests._make_old_save_with_stage()
	var logger := StructuredLogger.new()
	_repair(save, logger)
	var st := SaveBridgeTests._get_stage0(save)
	if not (st.get("held_fates") is Array) or not (st["held_fates"] as Array).is_empty():
		m.append("repair gave held_fates %s, expected []" % str(st.get("held_fates")))
	var rec := { "id": "it.1", "type_id": "t_gear", "kind": "gear", "grade": "g0", "token": "0.0", "fate": "lost", "reason_key": "leave_some" }
	st["held_fates"] = [rec]
	_repair(save)
	if str((SaveBridgeTests._get_stage0(save)["held_fates"] as Array)) != str([rec]):
		m.append("repair changed a populated held_fates")
	st["held_fates"] = "bad"
	_repair(save)
	var after: Variant = SaveBridgeTests._get_stage0(save).get("held_fates")
	if not (after is Array) or not (after as Array).is_empty():
		m.append("wrongly typed held_fates became %s, expected []" % str(after))
	return _result(m)


## No `ph_` placeholder id in data/balance.json or in a new save (placeholders live under tests/ only).
static func _t_no_placeholder() -> Dictionary:
	var m: Array = []
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		return { "ok": false, "error": "cannot open res://data/balance.json" }
	var text := f.get_as_text()
	f.close()
	if _has_placeholder_id(text):
		m.append("data/balance.json holds a ph_ id")
	if _has_placeholder_id(JSON.stringify(SaveSchema.make_new_save(3))):
		m.append("a new save holds a ph_ id")
	# Guard self-check: the matcher finds a real placeholder and ignores "glyph_".
	if not _has_placeholder_id("\"ph_weapon_a\"") or _has_placeholder_id("\"glyph_fade_seconds\""):
		m.append("placeholder matcher is wrong")
	return _result(m)


## `economy.relics` is the old currency stub. This story does not touch it.
static func _t_relics_unchanged() -> Dictionary:
	var m: Array = []
	var fresh := SaveSchema.make_new_save(5)
	var econ: Dictionary = fresh["economy"]
	if typeof(econ.get("relics")) != TYPE_INT or int(econ["relics"]) != 0:
		m.append("new save economy.relics %s, expected int 0" % str(econ.get("relics")))
	if (fresh.get("inventory") as Dictionary).has("relics"):
		m.append("inventory block has a relics key")
	var old := SaveBridgeTests._make_old_save()
	_repair(old)
	if int((old["economy"] as Dictionary).get("relics", -1)) != 0:
		m.append("old save without relics did not get 0")
	var kept := SaveBridgeTests._make_old_save()
	(kept["economy"] as Dictionary)["relics"] = 5
	_repair(kept)
	if int((kept["economy"] as Dictionary)["relics"]) != 5:
		m.append("economy.relics 5 changed to %s" % str((kept["economy"] as Dictionary)["relics"]))
	if (kept["inventory"] as Dictionary).has("relics") or ((kept["inventory"] as Dictionary)["items"] as Array).size() != 0:
		m.append("economy.relics leaked into inventory")
	return _result(m)


## A piece id with more than 15 digits keeps its entry, never feeds next_seq, and a second repair changes nothing.
static func _t_long_id() -> Dictionary:
	var m: Array = []
	var save := { "inventory": { "version": 1, "next_seq": 1,
		"items": [{ "id": "it.9223372036854775807", "type_id": "t", "kind": "gear", "grade": "g0", "held_by": "" }, _piece(4)],
		"stacks": [], "pack": [] } }
	var notes: Array = []
	var first := SaveService._repair_inventory_block(save, notes)
	var inv: Dictionary = save["inventory"]
	if typeof(inv["next_seq"]) != TYPE_INT or int(inv["next_seq"]) != 5:
		m.append("next_seq %s, expected 5" % str(inv["next_seq"]))
	if (inv["items"] as Array).size() != 2:
		m.append("long-id entry was dropped")
	if not first:
		m.append("first repair did not raise next_seq")
	if notes.is_empty():
		m.append("no note for the long id")
	var save2 := { "inventory": { "version": 1, "next_seq": 1,
		"items": [{ "id": "it.9223372036854775807", "type_id": "t", "kind": "gear", "grade": "g0", "held_by": "" }],
		"stacks": [], "pack": [] } }
	var notes2: Array = []
	SaveService._repair_inventory_block(save2, notes2)
	if int((save2["inventory"] as Dictionary)["next_seq"]) != 1:
		m.append("long id fed next_seq: %s" % str((save2["inventory"] as Dictionary)["next_seq"]))
	if SaveService._repair_inventory_block(save2, []):
		m.append("second repair reported a change")
	return _result(m)


## A stack is kept only if quantity is a whole number of 1 or more. Each bad case is dropped and counted in a note.
static func _t_bad_quantity() -> Dictionary:
	var m: Array = []
	var bad: Array = [0.5, "3", -2, 0, null, "missing", 1e19]
	var stacks: Array = []
	for q in bad:
		var st := { "type_id": "t_cons", "kind": "consumable" }
		if not (typeof(q) == TYPE_STRING and q == "missing"):
			st["quantity"] = q
		stacks.append(st)
	stacks.append({ "type_id": "t_ok", "kind": "consumable", "quantity": 2.0 })
	var save := { "inventory": { "version": 1, "next_seq": 1, "items": [], "stacks": stacks, "pack": [] } }
	var notes: Array = []
	if not SaveService._repair_inventory_block(save, notes):
		m.append("no change reported")
	var out: Array = (save["inventory"] as Dictionary)["stacks"]
	if out.size() != 1 or typeof((out[0] as Dictionary)["quantity"]) != TYPE_INT or int((out[0] as Dictionary)["quantity"]) != 2:
		m.append("stacks after repair %s" % str(out))
	if not str(notes).contains("dropped %d" % bad.size()):
		m.append("note lacks the count %d: %s" % [bad.size(), str(notes)])
	if SaveService._repair_inventory_block(save, []):
		m.append("second repair reported a change")
	return _result(m)


## A counter above 2^53 or non-finite is invalid: it resets to 1 with a note.
static func _t_huge_counter() -> Dictionary:
	var m: Array = []
	for bad in [1e19, INF, -INF, NAN]:
		var save := { "inventory": { "version": bad, "next_seq": bad, "items": [], "stacks": [], "pack": [] } }
		var notes: Array = []
		if not SaveService._repair_inventory_block(save, notes):
			m.append("%s: no change reported" % str(bad))
		var inv: Dictionary = save["inventory"]
		if typeof(inv["version"]) != TYPE_INT or int(inv["version"]) != 1 or typeof(inv["next_seq"]) != TYPE_INT or int(inv["next_seq"]) != 1:
			m.append("%s: counters %s / %s" % [str(bad), str(inv["version"]), str(inv["next_seq"])])
		if notes.size() != 2:
			m.append("%s: %d notes, expected 2" % [str(bad), notes.size()])
	return _result(m)
