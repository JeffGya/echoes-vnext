# res://tests/PickupPointerLookTests.gd
# V2-ITEM-001b D-77: `data.pointer_look`, the pointer feel values from `data.inventory.pickup.pointer_look`.
# Registered from PickupSnapshotTests.register, so the suite name is `pickup_snapshot`.

class_name PickupPointerLookTests
extends RefCounted


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_snapshot/pointer_look_missing_keys_read_defaults_and_clamp", Callable(PickupPointerLookTests, "_t_defaults"))
	runner.register_test("pickup_snapshot/pointer_look_shipping_block_has_the_rule_table_keys", Callable(PickupPointerLookTests, "_t_shipping_keys"))
	runner.register_test("pickup_snapshot/pointer_look_is_in_the_snapshot_live_and_after_reload", Callable(PickupPointerLookTests, "_t_snapshot"))
	runner.register_test("pickup_snapshot/pointer_look_trail_count_caps_at_16_and_tables_must_rise", Callable(PickupPointerLookTests, "_t_trail_and_rising"))
	runner.register_test("pickup_snapshot/pointer_look_validator_accepts_shipping_and_rejects_bad", Callable(PickupPointerLookTests, "_t_validator"))


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _shipping_inv() -> Dictionary:
	var shipping := ConfigService.new()
	shipping.load_balance()
	return ConfigService.get_inventory_cfg(shipping)


static func _cfg(look: Variant) -> Dictionary:
	return { "pickup": { "pointer_look": look } }


## The defaults written out by hand from the rule table: the getter must give exactly these for a missing block.
static func _want_defaults() -> Dictionary:
	var out := {}
	for group: String in PickupSnapshotBuilder.POINTER_LOOK_RULES:
		var vals := {}
		for key: String in PickupSnapshotBuilder.POINTER_LOOK_RULES[group]:
			var rule: Array = PickupSnapshotBuilder.POINTER_LOOK_RULES[group][key]
			vals[key] = int(rule[0]) if bool(rule[3]) else float(rule[0])
		out[group] = vals
	out["tables"] = PickupSnapshotBuilder.POINTER_LOOK_TABLES.duplicate(true)
	return out


static func _t_defaults() -> Dictionary:
	var m: Array = []
	var want := _want_defaults()
	for cfg: Dictionary in [{}, { "pickup": {} }, _cfg({}), _cfg(3), _cfg({ "path": 1, "mote": "x", "tables": 2 })]:
		if str(PickupSnapshotBuilder.pointer_look(cfg)) != str(want):
			m.append("%s reads %s" % [str(cfg), str(PickupSnapshotBuilder.pointer_look(cfg))])
	# One key given: it is read, every other key keeps its default.
	var one := PickupSnapshotBuilder.pointer_look(_cfg({ "path": { "hold": 1.25 }, "mote": { "rise": 3 } }))
	var want_one := want.duplicate(true)
	want_one["path"]["hold"] = 1.25
	want_one["mote"]["rise"] = 3.0
	if str(one) != str(want_one):
		m.append("one key given: %s" % str(one))
	# Non-numbers read the default; out of range clamps; whole keys stay ints; max never below min.
	var odd := PickupSnapshotBuilder.pointer_look(_cfg({
		"path": { "pointer_lead": 0, "hold": -2, "path_slow_n": 0, "path_turn_min": 0.9, "path_turn_max": 0.5, "path_pace": "fast" },
		"mote": { "trail_count": 7.0, "halo_alpha": 3, "arc_min": 20, "arc_max": 10, "sink_fade_from": 1 } }))
	var p: Dictionary = odd["path"]
	var mo: Dictionary = odd["mote"]
	if float(p["pointer_lead"]) != 0.001 or float(p["hold"]) != 0.0 or p["path_slow_n"] != 1 or float(p["path_pace"]) != 0.19 \
			or float(p["path_turn_max"]) != 0.9:
		m.append("path clamps: %s" % str(p))
	if typeof(mo["trail_count"]) != TYPE_INT or mo["trail_count"] != 7 or float(mo["halo_alpha"]) != 1.0 \
			or float(mo["arc_max"]) != 20.0 or float(mo["sink_fade_from"]) != 0.99:
		m.append("mote clamps: %s" % str(mo))
	# A given tables block replaces the defaults; an entry that is not an Array of numbers is dropped.
	var tb := PickupSnapshotBuilder.pointer_look(_cfg({ "tables": { "3:1": [1, 2, 3, 4, 5, 6, 7], "4:0": "x", "2:1": [1, "a"] } }))
	if str(tb["tables"]) != str({ "3:1": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0] }):
		m.append("tables: %s" % str(tb["tables"]))
	return _result(m)


## The shipping block names exactly the keys of `POINTER_LOOK_RULES`. No value is compared: Jeff tunes the values.
static func _t_shipping_keys() -> Dictionary:
	var m: Array = []
	var block_v: Variant = (_shipping_inv().get("pickup", {}) as Dictionary).get("pointer_look", null)
	if not (block_v is Dictionary):
		return _result(["the shipping config has no pointer_look block"])
	var block: Dictionary = block_v
	for group: String in PickupSnapshotBuilder.POINTER_LOOK_RULES:
		var g_v: Variant = block.get(group, null)
		var g: Dictionary = g_v if g_v is Dictionary else {}
		var want: Array = (PickupSnapshotBuilder.POINTER_LOOK_RULES[group] as Dictionary).keys()
		var got: Array = g.keys()
		want.sort()
		got.sort()
		if want != got:
			m.append("pointer_look.%s keys differ from the rule table: %s" % [group, str(got)])
	if not (block.get("tables", null) is Dictionary):
		m.append("pointer_look.tables is not a Dictionary")
	return _result(m)


## A changed config changes `data.pointer_look`, and a reload (no encounter context, JSON round trip) gives the same.
static func _t_snapshot() -> Dictionary:
	var m: Array = []
	var ctx: FlowContext = PickupSnapshotTests._event("C1")["ctx"]
	var d0: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if str(d0.get("pointer_look")) != str(_want_defaults()):
		m.append("default pointer_look %s" % str(d0.get("pointer_look")))
	var inv: Dictionary = ctx.config_service.get("inv")
	inv["pickup"] = { "pointer_look": { "path": { "pointer_start": 0.8 }, "mote": { "halo_alpha": 0.4 } } }
	var d1: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	var got: Dictionary = d1.get("pointer_look", {})
	if float(got.get("path", {}).get("pointer_start", -1)) != 0.8 or float(got.get("mote", {}).get("halo_alpha", -1)) != 0.4:
		m.append("a config change did not reach the snapshot: %s" % str(got))
	for group: String in PickupSnapshotBuilder.POINTER_LOOK_RULES:
		for key: String in PickupSnapshotBuilder.POINTER_LOOK_RULES[group]:
			if not (got.get(group, {}) as Dictionary).has(key):
				m.append("the snapshot has no pointer_look.%s.%s" % [group, key])
	if not got.has("tables"):
		m.append("the snapshot has no pointer_look.tables")
	ctx.encounter_ctx = null
	PickupSnapshotTests._json_trip(ctx)
	ctx.last_snapshot = {}
	var d2: Dictionary = PickupSnapshotTests._build(ctx)["data"]
	if str(d2.get("pointer_look")) != str(d1.get("pointer_look")):
		m.append("after a reload %s, live %s" % [str(d2.get("pointer_look")), str(d1.get("pointer_look"))])
	return _result(m)


static func _t_trail_and_rising() -> Dictionary:
	var m: Array = []
	var inv := _shipping_inv()
	var base: Dictionary = (inv["pickup"] as Dictionary).duplicate(true)
	if int(PickupSnapshotBuilder.pointer_look(_cfg({ "mote": { "trail_count": 99 } }))["mote"]["trail_count"]) != 16:
		m.append("trail_count 99 did not clamp to 16")
	var cfg := { "pickup": base.duplicate(true) }
	cfg["pickup"]["pointer_look"] = { "mote": { "trail_count": 99 } }
	if ConfigValidator.validate_pickup(cfg).is_empty():
		m.append("the validator accepted trail_count 99")
	var good := [0.68, 0.96, 1.42, 1.72, 2.06, 2.70, 3.60]
	var repeat := [0.68, 0.96, 0.96, 1.72, 2.06, 2.70, 3.60]
	var early := [0.2, 0.96, 1.42, 1.72, 2.06, 2.70, 3.60]
	var tb: Dictionary = PickupSnapshotBuilder.pointer_look(_cfg({ "tables": { "3:1": good, "3:0": repeat, "4:0": early } }))["tables"]
	if not tb.has("3:1"):
		m.append("a rising table was dropped")
	if tb.has("3:0") or tb.has("4:0"):
		m.append("a repeated time or a first time not above pointer_lead was kept: %s" % str(tb.keys()))
	return _result(m)


static func _t_validator() -> Dictionary:
	var m: Array = []
	var inv := _shipping_inv()
	if not ConfigValidator.validate_pickup(inv).is_empty():
		m.append("shipping config: %s" % str(ConfigValidator.validate_pickup(inv)))
	var base: Dictionary = (inv["pickup"] as Dictionary).duplicate(true)
	var none := { "pickup": base.duplicate(true) }
	none["pickup"].erase("pointer_look")
	if not ConfigValidator.validate_pickup(none).is_empty():
		m.append("the pointer_look block must stay optional")
	var sparse := { "pickup": base.duplicate(true) }
	sparse["pickup"]["pointer_look"] = { "path": { "hold": 0 }, "mote": { "trail_count": 0 } }
	if not ConfigValidator.validate_pickup(sparse).is_empty():
		m.append("rejected a sparse valid block: %s" % str(ConfigValidator.validate_pickup(sparse)))
	var bad := [
		["not a Dictionary", 4],
		["group not a Dictionary", { "path": [] }],
		["unknown key", { "mote": { "glow": 1 } }],
		["negative time", { "path": { "hold": -0.1 } }],
		["zero divisor", { "path": { "path_arc_span": 0 } }],
		["zero lead", { "path": { "pointer_lead": 0.0 } }],
		["string", { "mote": { "rise": "16" } }],
		["fraction count", { "path": { "path_slow_n": 2.5 } }],
		["zero slow_n", { "path": { "path_slow_n": 0 } }],
		["alpha above 1", { "mote": { "halo_alpha": 1.5 } }],
		["sink fade 1", { "mote": { "sink_fade_from": 1 } }],
		["turn max below min", { "path": { "path_turn_min": 0.5, "path_turn_max": 0.4 } }],
		["arc max below min", { "mote": { "arc_max": 5 } }],
		["tables not a Dictionary", { "tables": [] }],
		["table key", { "tables": { "five": [1.0] } }],
		["table land past n", { "tables": { "3:3": [1, 2, 3, 4, 5] } }],
		["table length", { "tables": { "3:1": [0.68, 0.96] } }],
		["table not rising", { "tables": { "3:1": [0.68, 0.96, 0.9, 1.72, 2.06, 2.70, 3.60] } }],
		["table first time not after the lead", { "tables": { "3:1": [0.2, 0.96, 1.42, 1.72, 2.06, 2.70, 3.60] } }],
	]
	for b: Array in bad:
		var cfg := { "pickup": base.duplicate(true) }
		cfg["pickup"]["pointer_look"] = b[1]
		if ConfigValidator.validate_pickup(cfg).is_empty():
			m.append("accepted %s" % str(b[0]))
	return _result(m)
