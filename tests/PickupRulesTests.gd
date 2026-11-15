# res://tests/PickupRulesTests.gd
# PickupChooser (chooser draw, pointer plan), PickupCase (capacity cases C1 to C5, frozen, reaction class)
# and PickupSwapRules (swap legality). Pure: every save, stage and find is built by hand here.
# The golden tables pin the chooser id and the pointer start and laps per seed and path; each chooser row
# is also replayed by hand on the literal pick stream.

class_name PickupRulesTests
extends RefCounted

const _SEEDS := [1, 42, 9001, 123456789, 7777777]
const _PARTY := ["e1", "e2", "e3", "e4"]

# [realm_seed, stage_id, run_count, situation_id, party ids in slot order, fallen ids, pinned chooser id].
const _GOLDEN := [
	[1, "stage_01", 0, "sit_a", ["e1", "e2", "e3", "e4"], [], "e2"],
	[1, "stage_01", 0, "sit_b", ["e1", "e2", "e3", "e4"], [], "e3"],
	[42, "stage_01", 1, "sit_a", ["e1", "e2", "e3", "e4"], ["e2"], "e1"],
	[42, "stage_02", 0, "sit_c", ["e1", "e2", "e3"], [], "e1"],
	[9001, "stage_02", 2, "sit_a", ["e1", "e2", "e3", "e4", "e5"], [], "e2"],
	[9001, "stage_03", 0, "sit_d", ["e1", "e2", "e3", "e4", "e5"], ["e1", "e5"], "e3"],
	[123456789, "stage_01", 0, "sit_a", ["e1", "e2"], [], "e1"],
	[123456789, "stage_04", 3, "sit_e", ["e4", "e2", "e1", "e3"], [], "e4"],
	[7777777, "stage_02", 1, "sit_b", ["e1", "e2", "e3", "e4"], ["e3"], "e2"],
	[7777777, "stage_05", 0, "sit_f", ["e1", "e2", "e3", "e4"], ["e1", "e2", "e4"], "e3"],
	[555, "stage_01", 0, "sit_a", ["e1", "e2", "e3", "e4"], [], "e3"],
	[555, "stage_01", 0, "sit_z", ["e1", "e2", "e3", "e4"], [], "e2"],
	[31337, "stage_03", 2, "sit_g", ["e1", "e2", "e3"], ["e2"], "e3"],
	[2024, "stage_06", 0, "sit_a", ["e1", "e2", "e3", "e4", "e5"], [], "e3"],
]

# [realm_seed, stage_id, run_count, situation_id, n, chooser index, pinned start, pinned laps].
const _POINTER_GOLDEN := [
	[1, "stage_01", 0, "sit_a", 4, 2, 0, 2],
	[42, "stage_01", 1, "sit_a", 3, 0, 1, 1],
	[9001, "stage_02", 2, "sit_a", 5, 4, 3, 1],
	[123456789, "stage_01", 0, "sit_a", 2, 1, 0, 2],
	[7777777, "stage_05", 0, "sit_f", 1, 0, 0, 2],
	[555, "stage_01", 0, "sit_z", 4, 0, 3, 2],
]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_rules/standing_keeps_party_order_and_drops_fallen", Callable(PickupRulesTests, "_t_standing"))
	runner.register_test("pickup_rules/chooser_golden_and_hand_replay", Callable(PickupRulesTests, "_t_chooser_golden"))
	runner.register_test("pickup_rules/chooser_exactly_one_draw", Callable(PickupRulesTests, "_t_one_draw"))
	runner.register_test("pickup_rules/chooser_equal_chance", Callable(PickupRulesTests, "_t_equal_chance"))
	runner.register_test("pickup_rules/chooser_never_a_fallen_echo", Callable(PickupRulesTests, "_t_never_fallen"))
	runner.register_test("pickup_rules/chooser_stream_and_situation", Callable(PickupRulesTests, "_t_stream"))
	runner.register_test("pickup_rules/chooser_no_standing_echo", Callable(PickupRulesTests, "_t_no_standing"))
	runner.register_test("pickup_rules/pointer_rules", Callable(PickupRulesTests, "_t_pointer"))
	runner.register_test("pickup_rules/pointer_golden", Callable(PickupRulesTests, "_t_pointer_golden"))
	runner.register_test("pickup_rules/pointer_laps_follow_config", Callable(PickupRulesTests, "_t_laps_config"))
	runner.register_test("pickup_rules/severe_band_follows_config", Callable(PickupRulesTests, "_t_severe_config"))
	runner.register_test("pickup_rules/pointer_laps_clamp_odd_config", Callable(PickupRulesTests, "_t_laps_clamp"))
	runner.register_test("pickup_rules/pickup_config_validator", Callable(PickupRulesTests, "_t_pickup_validator"))
	runner.register_test("pickup_rules/pack_room_counts_carried_and_open_rows", Callable(PickupRulesTests, "_t_pack_room"))
	runner.register_test("pickup_rules/cases_c1_to_c5", Callable(PickupRulesTests, "_t_cases"))
	runner.register_test("pickup_rules/frozen_takes_nothing", Callable(PickupRulesTests, "_t_frozen"))
	runner.register_test("pickup_rules/reaction_severe_band", Callable(PickupRulesTests, "_t_severe"))
	runner.register_test("pickup_rules/swap_refusals", Callable(PickupRulesTests, "_t_swap_refusals"))
	runner.register_test("pickup_rules/swap_pairs_and_targets", Callable(PickupRulesTests, "_t_swap_pairs"))
	runner.register_test("pickup_rules/empty_order_is_frozen", Callable(PickupRulesTests, "_t_empty_order"))
	runner.register_test("pickup_rules/order_subset_of_finds", Callable(PickupRulesTests, "_t_order_subset"))
	runner.register_test("pickup_rules/tried_follows_pick_order", Callable(PickupRulesTests, "_t_tried_order"))
	runner.register_test("pickup_rules/pack_entries_stack_and_rows", Callable(PickupRulesTests, "_t_pack_entries"))
	runner.register_test("pickup_rules/offer_no_target_vs_same", Callable(PickupRulesTests, "_t_no_target"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _rng(seed: int, path: String) -> RandomNumberGenerator:
	return CampaignSeed.get_rng_from(seed, path)


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _cfg(capacity: int = 4) -> Dictionary:
	return { "pack_capacity": capacity }


static func _find(id: String, type_id: String) -> Dictionary:
	return { "find_id": id, "type_id": type_id, "kind": "gear", "grade": "", "quantity": 1 }


## A save whose pack holds one unique piece per entry of `held_types` (carried from an earlier path) and
## whose live stage (realms.realm.01.stages[0]) holds one open item row per entry of `row_types`.
static func _save(held_types: Array, row_types: Array = []) -> Dictionary:
	var pack: Array = []
	for i in held_types.size():
		pack.append({ "id": "it.%d" % (i + 1), "type_id": str(held_types[i]), "kind": "gear" })
	var stage := {}
	for i in row_types.size():
		EarningsService.record_item(stage, "sit_old", "g%d" % (i + 1),
			{ "type_id": str(row_types[i]), "kind": "gear", "grade": "", "quantity": 1 })
	return {
		"inventory": { "items": [], "stacks": [], "pack": pack, "pack_stacks": [] },
		"realms": { "realm.01": { "stages": [stage] } },
	}


static func _stage(save: Dictionary) -> Dictionary:
	return ((save["realms"]["realm.01"]["stages"] as Array)[0]) as Dictionary


static func _actor(morale: int, fear: int, fear_base: int = 0) -> Dictionary:
	return { "morale": morale, "fear": fear, "fear_base": fear_base, "faction": "echo", "kind": "echo" }


static func _calm() -> Dictionary:
	return _actor(50, 0)


## Finds in `ids` order (the pick order the test hands in).
static func _ordered(finds: Array, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		for f in finds:
			if f["find_id"] == id:
				out.append(f)
	return out


static func _check_case(m: Array, label: String, got: Dictionary, case_id: String, taken: Array, tried: String,
		left: Array, reaction: String, free: int) -> void:
	var want := { "case": case_id, "taken": taken, "tried": tried, "left": left, "reaction": reaction, "free": free }
	for key in want.keys():
		if got.get(key) != want[key]:
			m.append("%s: %s is %s, expected %s" % [label, key, str(got.get(key)), str(want[key])])


# ---------------------------------------------------------------------------
# Chooser
# ---------------------------------------------------------------------------

static func _t_standing() -> Dictionary:
	var m: Array = []
	var cases := [
		[["e1", "e2", "e3", "e4"], [], ["e1", "e2", "e3", "e4"]],
		[["e4", "e2", "e1", "e3"], [], ["e4", "e2", "e1", "e3"]],
		[["e1", "e2", "e3", "e4"], ["e2", "e4"], ["e1", "e3"]],
		[["e1", "", "e2", "e1"], [], ["e1", "e2"]],
		[["e1", "e2"], ["e1", "e2"], []],
		[["e1", "e2"], ["x9"], ["e1", "e2"]],
	]
	for c in cases:
		var got := PickupChooser.standing_ids(c[0], c[1])
		if got != c[2]:
			m.append("party %s fallen %s: %s, expected %s" % [str(c[0]), str(c[1]), str(got), str(c[2])])
	return _result(m)


## Pinned chooser per row, and the same index replayed by hand on the literal pick stream.
static func _t_chooser_golden() -> Dictionary:
	var m: Array = []
	var actual: Array = []
	for g in _GOLDEN:
		var standing := PickupChooser.standing_ids(g[4], g[5])
		var got := PickupChooser.draw(int(g[0]), str(g[1]), int(g[2]), str(g[3]), standing)
		actual.append(got["chooser_id"])
		if str(got["chooser_id"]) != str(g[6]):
			m.append("%s: chooser %s" % [str(g), str(got["chooser_id"])])
		var replay := _rng(int(g[0]), "inventory.pick.%s.%d.%s" % [g[1], int(g[2]), g[3]]).randi_range(0, standing.size() - 1)
		if int(got["index"]) != replay or str(got["chooser_id"]) != str(standing[replay]) or int(got["n"]) != standing.size():
			m.append("%s: draw %s, hand replay index %d" % [str(g), str(got), replay])
	if not m.is_empty():
		m.append("actual choosers in table order: %s" % str(actual))
	return _result(m)


## One randi_range(0, n - 1) for every n >= 1; none for n == 0. For n >= 2 the state must also move.
static func _t_one_draw() -> Dictionary:
	var m: Array = []
	for seed in _SEEDS:
		for n in range(0, 7):
			var path := PickupChooser.stream_path("stage_01", 0, "sit_%d" % n)
			var used := _rng(seed, path)
			var before := used.state
			var idx := PickupChooser.draw_with(used, n)
			var ref := _rng(seed, path)
			if n >= 1:
				ref.randi_range(0, n - 1)
			if used.state != ref.state:
				m.append("seed %d n %d: not exactly one draw" % [seed, n])
			if n >= 2 and used.state == before:
				m.append("seed %d n %d: the state did not move" % [seed, n])
			if n == 0 and idx != -1:
				m.append("seed %d n 0: index %d" % [seed, idx])
			if n >= 1 and (idx < 0 or idx >= n):
				m.append("seed %d n %d: index %d out of range" % [seed, n, idx])
	return _result(m)


## 1200 situations per row size: every index is chosen, each within 20% of an equal share.
static func _t_equal_chance() -> Dictionary:
	var m: Array = []
	for n in range(2, 6):
		var counts: Array = []
		counts.resize(n)
		counts.fill(0)
		var standing := ["e1", "e2", "e3", "e4", "e5"].slice(0, n)
		for k in range(1200):
			counts[int(PickupChooser.draw(42, "stage_01", 0, "sit_%d" % k, standing)["index"])] += 1
		var share := 1200.0 / n
		for i in n:
			if counts[i] < share * 0.8 or counts[i] > share * 1.2:
				m.append("n %d: counts %s are not near %.0f each" % [n, str(counts), share])
				break
	return _result(m)


static func _t_never_fallen() -> Dictionary:
	var m: Array = []
	var party := ["e1", "e2", "e3", "e4", "e5"]
	for fallen in [["e2", "e4"], ["e1"], ["e5"], ["e1", "e2", "e3", "e4"]]:
		var seen := {}
		var standing := PickupChooser.standing_ids(party, fallen)
		for k in range(300):
			var id := str(PickupChooser.draw(9001, "stage_02", 1, "sit_%d" % k, standing)["chooser_id"])
			seen[id] = true
			if (fallen as Array).has(id):
				m.append("fallen %s: %s was chosen" % [str(fallen), id])
				break
		var want := standing.duplicate()
		var got := seen.keys()
		got.sort()
		want.sort()
		if got != want:
			m.append("fallen %s: chosen set %s, expected every standing Echo %s" % [str(fallen), str(got), str(want)])
	return _result(m)


static func _t_stream() -> Dictionary:
	var m: Array = []
	var path := PickupChooser.stream_path("stage_02", 3, "sit_x")
	if path != "inventory.pick.stage_02.3.sit_x":
		m.append("stream_path is %s" % path)
	for bad in ["stage.settle", "inventory.leave", "inventory.finds"]:
		if path.begins_with(bad) or PickupChooser.pointer_path("stage_02", 3, "sit_x").begins_with(bad):
			m.append("a path shares the %s namespace" % bad)
	if CampaignSeed.derive_from(42, path) == CampaignSeed.derive_from(42, PickupChooser.pointer_path("stage_02", 3, "sit_x")):
		m.append("the pointer hash equals the pick stream seed")
	for g in _GOLDEN:
		var standing := PickupChooser.standing_ids(g[4], g[5])
		var a := PickupChooser.draw(int(g[0]), str(g[1]), int(g[2]), str(g[3]), standing)
		var b := PickupChooser.draw(int(g[0]), str(g[1]), int(g[2]), str(g[3]), standing)
		if a != b:
			m.append("%s: %s then %s" % [str(g), str(a), str(b)])
	# Another situation id is another stream: the seeds differ and the choosers are not all the same.
	var picked := {}
	for i in range(30):
		var sit := "sit_%d" % i
		if CampaignSeed.derive_from(42, PickupChooser.stream_path("stage_01", 0, sit)) \
				== CampaignSeed.derive_from(42, PickupChooser.stream_path("stage_01", 0, "sit_other")):
			m.append("%s has the seed of sit_other" % sit)
		picked[PickupChooser.draw(42, "stage_01", 0, sit, _PARTY)["chooser_id"]] = true
	if picked.size() < 2:
		m.append("30 situation ids gave one chooser: %s" % str(picked.keys()))
	return _result(m)


static func _t_no_standing() -> Dictionary:
	var m: Array = []
	var got := PickupChooser.draw(42, "stage_01", 0, "sit_a", PickupChooser.standing_ids(_PARTY, _PARTY))
	if got != { "chooser_id": "", "index": -1, "n": 0 }:
		m.append("no standing Echo: %s" % str(got))
	return _result(m)


# ---------------------------------------------------------------------------
# Pointer
# ---------------------------------------------------------------------------

static func _t_pointer() -> Dictionary:
	var m: Array = []
	var laps_seen := {}
	for n in range(1, 7):
		for idx in n:
			var starts := {}
			for k in range(40):
				var sit := "sit_%d" % k
				var p := PickupChooser.pointer(_cfg(), 42, "stage_01", 0, sit, n, idx)
				if p != PickupChooser.pointer(_cfg(), 42, "stage_01", 0, sit, n, idx):
					m.append("n %d idx %d %s: not the same twice" % [n, idx, sit])
				var start := int(p["start"])
				var laps := int(p["laps"])
				if int(p["n"]) != n or start < 0 or start >= n or (n >= 2 and start == idx) or (n == 1 and start != 0):
					m.append("n %d idx %d %s: bad plan %s" % [n, idx, sit, str(p)])
				if laps < 1 or laps > 2:
					m.append("n %d idx %d %s: laps %d out of range" % [n, idx, sit, laps])
				starts[start] = true
				laps_seen[laps] = true
			if n >= 3 and starts.size() < 2:
				m.append("n %d idx %d: the start never varies %s" % [n, idx, str(starts.keys())])
	if laps_seen.size() != 2 - 1 + 1:
		m.append("laps seen %s" % str(laps_seen.keys()))
	for bad in [[0, 0], [3, 3], [3, -1]]:
		var p := PickupChooser.pointer(_cfg(), 42, "stage_01", 0, "sit_a", int(bad[0]), int(bad[1]))
		if int(p["start"]) != -1 or int(p["laps"]) != 0:
			m.append("n %d idx %d: %s, expected no plan" % [int(bad[0]), int(bad[1]), str(p)])
	return _result(m)


static func _t_pointer_golden() -> Dictionary:
	var m: Array = []
	for g in _POINTER_GOLDEN:
		var p := PickupChooser.pointer(_cfg(), int(g[0]), str(g[1]), int(g[2]), str(g[3]), int(g[4]), int(g[5]))
		if int(p["start"]) != int(g[6]) or int(p["laps"]) != int(g[7]):
			m.append("%s: %s" % [str(g), str(p)])
	return _result(m)


static func _pickup_cfg(laps_min: int, laps_max: int, severe_from: String = "burdened") -> Dictionary:
	return { "pickup": { "pointer_laps_min": laps_min, "pointer_laps_max": laps_max, "severe_from_status": severe_from } }


static func _t_laps_config() -> Dictionary:
	var m: Array = []
	var shipping := ConfigService.get_inventory_cfg(InventorySaveTests._config())
	for g in _POINTER_GOLDEN:
		var p := PickupChooser.pointer(shipping, int(g[0]), str(g[1]), int(g[2]), str(g[3]), int(g[4]), int(g[5]))
		if int(p["laps"]) != int(g[7]):
			m.append("shipping config: %s gives laps %d" % [str(g), int(p["laps"])])
	var seen := {}
	for k in range(60):
		var p := PickupChooser.pointer(_pickup_cfg(3, 5), 42, "stage_01", 0, "sit_%d" % k, 4, 1)
		var laps := int(p["laps"])
		if laps < 3 or laps > 5:
			m.append("laps 3..5: got %d" % laps)
		seen[laps] = true
	if seen.size() != 3:
		m.append("laps 3..5: saw %s" % str(seen.keys()))
	for k in range(20):
		if int(PickupChooser.pointer(_pickup_cfg(4, 4), 42, "stage_01", 0, "sit_%d" % k, 4, 1)["laps"]) != 4:
			m.append("laps 4..4 is not always 4")
			break
	return _result(m)


## Odd config values: min 0 reads as 1; max below min reads as min (no modulo by zero); min above 1 holds.
static func _t_laps_clamp() -> Dictionary:
	var m: Array = []
	for c in [[0, 0, 1], [0, 2, -1], [-3, -3, 1], [3, 1, 3], [2, 0, 2]]:
		for k in range(12):
			var laps := int(PickupChooser.pointer(_pickup_cfg(c[0], c[1]), 42, "stage_01", 0, "sit_%d" % k, 4, 1)["laps"])
			var lo := maxi(1, int(c[0]))
			var hi := maxi(lo, int(c[1]))
			if laps < lo or laps > hi or (int(c[2]) > 0 and laps != int(c[2])):
				m.append("min %d max %d: laps %d outside %d..%d" % [c[0], c[1], laps, lo, hi])
				break
	return _result(m)


static func _t_severe_config() -> Dictionary:
	var m: Array = []
	var two := [_find("f1", "salve"), _find("f2", "charm")]
	var full := PickupCase.pack_room(_save(["blade", "shield", "ring", "crown"]), _cfg())
	var burdened := _actor(50, 45)
	var pressed := _actor(50, 55)
	var hesitant := _actor(30, 0)
	var cases := [
		["burdened, from burdened", burdened, "burdened", "none"],
		["burdened, from pressed", burdened, "pressed", "minus"],
		["pressed, from pressed", pressed, "pressed", "none"],
		["hesitant, from hesitant", hesitant, "hesitant", "none"],
		["pressed, unknown id", pressed, "no_such_status", "minus"],
	]
	for c in cases:
		var cfg := _pickup_cfg(1, 2, c[2])
		if PickupCase.resolve(two, two, full, false, c[1], cfg)["reaction"] != c[3]:
			m.append("%s: reaction is not %s" % [c[0], c[3]])
	if PickupCase.is_severe(burdened, {}) != true or PickupCase.is_severe(hesitant, {}) != false:
		m.append("a missing pickup block does not read as burdened")
	return _result(m)


static func _t_pickup_validator() -> Dictionary:
	var m: Array = []
	var shipping := ConfigService.get_inventory_cfg(InventorySaveTests._config())
	var problems := ConfigValidator.validate_pickup(shipping)
	if not problems.is_empty():
		m.append("the shipping config fails: %s" % str(problems))
	if not ConfigValidator.validate_pickup(_pickup_cfg(2, 2)).is_empty():
		m.append("min equal to max is refused")
	var bad := [
		["no block", {}],
		["block not a Dictionary", { "pickup": 3 }],
		["min 0", _pickup_cfg(0, 2)],
		["min fraction", { "pickup": { "pointer_laps_min": 1.5, "pointer_laps_max": 2, "severe_from_status": "burdened" } }],
		["max below min", _pickup_cfg(3, 2)],
		["max fraction", { "pickup": { "pointer_laps_min": 1, "pointer_laps_max": 2.5, "severe_from_status": "burdened" } }],
		["max missing", { "pickup": { "pointer_laps_min": 1, "severe_from_status": "burdened" } }],
		["unknown status", _pickup_cfg(1, 2, "tired")],
		["status missing", { "pickup": { "pointer_laps_min": 1, "pointer_laps_max": 2 } }],
	]
	for b in bad:
		if ConfigValidator.validate_pickup(b[1]).is_empty():
			m.append("%s: not refused" % b[0])
	return _result(m)


# ---------------------------------------------------------------------------
# Cases and reaction
# ---------------------------------------------------------------------------

## A carried entry from an earlier path and every open item row of the save use a slot; a settled row does not.
static func _t_pack_room() -> Dictionary:
	var m: Array = []
	var save := _save(["charm"], ["salve", "root"])
	(EarningsService.rows_of(_stage(save))[1] as Dictionary)["settled"] = true
	var other := {}
	EarningsService.record_item(other, "sit_far", "g1", { "type_id": "ring", "kind": "gear", "grade": "", "quantity": 1 })
	save["realms"]["realm.02"] = { "stages": [other] }
	var room := PickupCase.pack_room(save, _cfg())
	if int(room["carried"]) != 3 or int(room["free"]) != 1:
		m.append("carried %d free %d, expected 3 and 1" % [int(room["carried"]), int(room["free"])])
	if int(PickupCase.pack_room(_save([]), _cfg())["carried"]) != 0:
		m.append("an empty pack carries something")
	return _result(m)


static func _t_cases() -> Dictionary:
	var m: Array = []
	var three := [_find("f1", "salve"), _find("f2", "charm"), _find("f3", "root")]
	var four := three + [_find("f4", "ring")]
	var two := [_find("f1", "salve"), _find("f2", "charm")]
	var calm := _calm()

	var got := PickupCase.resolve(three, _ordered(three, ["f3", "f1", "f2"]), PickupCase.pack_room(_save([]), _cfg()), false, calm, _cfg())
	_check_case(m, "C1 empty, all fit", got, "C1", ["f3", "f1", "f2"], "", [], "plus", 4)

	got = PickupCase.resolve(four, _ordered(four, ["f4", "f2", "f1", "f3"]), PickupCase.pack_room(_save([]), _cfg(2)), false, calm, _cfg())
	_check_case(m, "C2 empty, some fit", got, "C2", ["f4", "f2"], "f1", ["f1", "f3"], "none", 2)

	got = PickupCase.resolve(two, _ordered(two, ["f2", "f1"]), PickupCase.pack_room(_save(["blade"]), _cfg()), false, calm, _cfg())
	_check_case(m, "C3 partly full, all fit", got, "C3", ["f2", "f1"], "", [], "plus", 3)

	# Partly full by one carried piece and one open row of an earlier situation: S = 1.
	got = PickupCase.resolve(three, _ordered(three, ["f3", "f1", "f2"]),
		PickupCase.pack_room(_save(["blade", "shield"], ["herb"]), _cfg()), false, calm, _cfg())
	_check_case(m, "C4 partly full, some fit", got, "C4", ["f3"], "f1", ["f1", "f2"], "none", 1)

	got = PickupCase.resolve(two, _ordered(two, ["f2", "f1"]),
		PickupCase.pack_room(_save(["blade", "shield", "ring", "crown"]), _cfg()), false, calm, _cfg())
	_check_case(m, "C5 full, none fit", got, "C5", [], "f2", ["f1", "f2"], "minus", 0)

	# Full by three carried pieces from an earlier path and one open row: still C5.
	got = PickupCase.resolve(two, _ordered(two, ["f1", "f2"]),
		PickupCase.pack_room(_save(["blade", "shield", "ring"], ["herb"]), _cfg()), false, calm, _cfg())
	_check_case(m, "C5 full with a carried entry", got, "C5", [], "f1", ["f1", "f2"], "minus", 0)

	# Exact fit into a partly full pack is "all fit".
	got = PickupCase.resolve(two, _ordered(two, ["f1", "f2"]), PickupCase.pack_room(_save(["blade", "shield"]), _cfg()), false, calm, _cfg())
	_check_case(m, "C3 exact fit", got, "C3", ["f1", "f2"], "", [], "plus", 2)

	got = PickupCase.resolve([], [], PickupCase.pack_room(_save([]), _cfg()), false, calm, _cfg())
	_check_case(m, "no finds", got, "", [], "", [], "none", 4)
	return _result(m)


## A frozen chooser takes nothing, holds nothing up, leaves every find in find order, reaction "none".
static func _t_frozen() -> Dictionary:
	var m: Array = []
	var two := [_find("f1", "salve"), _find("f2", "charm")]
	for c in [[_save([]), 4], [_save(["blade", "shield", "ring", "crown"]), 0], [_save(["blade"]), 3]]:
		for order in [[], _ordered(two, ["f2", "f1"])]:
			var got := PickupCase.resolve(two, order, PickupCase.pack_room(c[0], _cfg()), true, _actor(50, 0), _cfg())
			_check_case(m, "frozen, free %d, order size %d" % [int(c[1]), (order as Array).size()], got,
				"frozen", [], "", ["f1", "f2"], "none", int(c[1]))
	return _result(m)


## No extra minus for a chooser in the severe band (burdened or worse, D-34); the plus still applies.
static func _t_severe() -> Dictionary:
	var m: Array = []
	var two := [_find("f1", "salve"), _find("f2", "charm")]
	var three := two + [_find("f3", "root")]
	var full := PickupCase.pack_room(_save(["blade", "shield", "ring", "crown"]), _cfg())
	var actors := [
		["calm", _calm(), "grounded", "minus"],
		["hesitant (one above burdened)", _actor(30, 0), "hesitant", "minus"],
		["burdened by fear", _actor(50, 45), "burdened", "none"],
		["burdened by fear_base", _actor(50, 0, 45), "burdened", "none"],
		["burdened by morale", _actor(24, 0), "burdened", "none"],
		["pressed", _actor(50, 55), "pressed", "none"],
		["hollow", _actor(50, 90), "hollow", "none"],
	]
	for a in actors:
		if EmotionStatusLean.status_of(a[1]) != a[2]:
			m.append("%s: status %s, the fixture expects %s" % [a[0], EmotionStatusLean.status_of(a[1]), a[2]])
		var got := PickupCase.resolve(two, two, full, false, a[1], _cfg())
		if got["reaction"] != a[3]:
			m.append("%s, full pack: reaction %s, expected %s" % [a[0], got["reaction"], a[3]])
	var burdened := _actor(50, 45)
	if PickupCase.resolve(two, two, PickupCase.pack_room(_save([]), _cfg()), false, burdened, _cfg())["reaction"] != "plus":
		m.append("a burdened chooser lost the plus when everything fits")
	if PickupCase.resolve(three, three, PickupCase.pack_room(_save(["blade", "shield"]), _cfg()), false, burdened, _cfg())["reaction"] != "none":
		m.append("a burdened chooser with some fit is not none")
	return _result(m)


# ---------------------------------------------------------------------------
# Swap
# ---------------------------------------------------------------------------

## A full pack (four carried pieces) and two finds: f1 salve, f2 charm (a twin of the carried it.1).
static func _full_setup() -> Dictionary:
	var save := _save(["charm", "shield", "blade", "ring"])
	var finds := [_find("f1", "salve"), _find("f2", "charm")]
	var event := PickupCase.resolve(finds, finds, PickupCase.pack_room(save, _cfg()), false, _calm(), _cfg())
	return { "save": save, "finds": finds, "event": event, "pack": PickupSwapRules.pack_entries(save, _stage(save)) }


static func _t_swap_refusals() -> Dictionary:
	var m: Array = []
	var s := _full_setup()
	if PickupSwapRules.offer(s["event"], s["finds"], s["pack"], false) != { "ok": true, "reason_key": "" }:
		m.append("full pack with finds left: %s" % str(PickupSwapRules.offer(s["event"], s["finds"], s["pack"], false)))
	var cases: Array = []
	cases.append(["used", s["event"], s["finds"], s["pack"], true, "used"])
	var frozen := PickupCase.resolve(s["finds"], [], PickupCase.pack_room(s["save"], _cfg()), true, _calm(), _cfg())
	cases.append(["frozen", frozen, s["finds"], s["pack"], false, "frozen"])
	cases.append(["frozen and used", frozen, s["finds"], s["pack"], true, "frozen"])
	# Room left after the picks: C1 and C3.
	var empty := _save([])
	var c1 := PickupCase.resolve(s["finds"], s["finds"], PickupCase.pack_room(empty, _cfg()), false, _calm(), _cfg())
	cases.append(["has_room C1", c1, s["finds"], PickupSwapRules.pack_entries(empty, _stage(empty)), false, "has_room"])
	cases.append(["used before has_room", c1, s["finds"], [], true, "used"])
	var one := _save(["blade"])
	var c3 := PickupCase.resolve(s["finds"], s["finds"], PickupCase.pack_room(one, _cfg()), false, _calm(), _cfg())
	cases.append(["has_room C3", c3, s["finds"], PickupSwapRules.pack_entries(one, _stage(one)), false, "has_room"])
	# Exact fit: the pack is full after the picks and nothing is left.
	var half := _save(["blade", "shield"])
	var fit := PickupCase.resolve(s["finds"], s["finds"], PickupCase.pack_room(half, _cfg()), false, _calm(), _cfg())
	cases.append(["nothing_left", fit, s["finds"], PickupSwapRules.pack_entries(half, _stage(half)), false, "nothing_left"])
	# Every pair is a twin.
	var twins := _save(["charm", "charm", "charm", "charm"])
	var charm := [_find("f1", "charm")]
	var all_twin := PickupCase.resolve(charm, charm, PickupCase.pack_room(twins, _cfg()), false, _calm(), _cfg())
	cases.append(["same", all_twin, charm, PickupSwapRules.pack_entries(twins, _stage(twins)), false, "same"])
	for c in cases:
		var got := PickupSwapRules.offer(c[1], c[2], c[3], c[4])
		if got != { "ok": false, "reason_key": c[5] }:
			m.append("%s: %s" % [c[0], str(got)])
		if not PickupSwapRules.targets(c[1], c[2], c[3], c[4], "f1").is_empty():
			m.append("%s: targets are not empty" % c[0])
	return _result(m)


static func _t_swap_pairs() -> Dictionary:
	var m: Array = []
	var s := _full_setup()
	var ids := (s["pack"] as Array).map(func(p: Dictionary) -> String: return str(p["id"]))
	if ids != ["it.1", "it.2", "it.3", "it.4"]:
		m.append("pack entries %s" % str(ids))
	var pairs := [
		["field find for a pack item", "f1", "it.1", ""],
		["the held-up item for a pack item", "f1", "it.4", ""],
		["twin", "f2", "it.1", "same"],
		["twin's other partner", "f2", "it.2", ""],
		["two pack items", "it.1", "it.2", "bad_pair"],
		["two field items", "f1", "f2", "bad_pair"],
		["unknown find", "f9", "it.2", "bad_pair"],
		["unknown pack item", "f1", "it.9", "bad_pair"],
		["empty ids", "", "", "bad_pair"],
	]
	for p in pairs:
		var got := PickupSwapRules.pair(s["event"], s["finds"], s["pack"], false, str(p[1]), str(p[2]))
		if got != { "ok": str(p[3]).is_empty(), "reason_key": p[3] }:
			m.append("%s: %s" % [p[0], str(got)])
	if PickupSwapRules.pair(s["event"], s["finds"], s["pack"], true, "f1", "it.1")["reason_key"] != "used":
		m.append("a legal pair after the swap was used is not refused with used")
	var t1 := PickupSwapRules.targets(s["event"], s["finds"], s["pack"], false, "f1")
	if t1 != ["it.1", "it.2", "it.3", "it.4"]:
		m.append("targets of f1: %s" % str(t1))
	var t2 := PickupSwapRules.targets(s["event"], s["finds"], s["pack"], false, "f2")
	if t2 != ["it.2", "it.3", "it.4"]:
		m.append("targets of the twin f2: %s" % str(t2))

	# C4: a gathered row of this event fills the pack; it is a target, and a twin of it is not.
	var save := _save(["blade", "shield"], ["herb"])
	var finds := [_find("f1", "salve"), _find("f2", "herb"), _find("f3", "root")]
	var event := PickupCase.resolve(finds, _ordered(finds, ["f3", "f1", "f2"]), PickupCase.pack_room(save, _cfg()), false, _calm(), _cfg())
	EarningsService.record_item(_stage(save), "sit_now", "f3", finds[2])
	var pack := PickupSwapRules.pack_entries(save, _stage(save))
	if PickupSwapRules.offer(event, finds, pack, false)["reason_key"] != "":
		m.append("C4 full after the picks: %s" % str(PickupSwapRules.offer(event, finds, pack, false)))
	var t3 := PickupSwapRules.targets(event, finds, pack, false, "f2")
	if t3 != ["it.1", "it.2", "item:sit_now:f3"]:
		m.append("C4 targets of the herb find: %s" % str(t3))
	if PickupSwapRules.pair(event, finds, pack, false, "f3", "it.1")["reason_key"] != "bad_pair":
		m.append("C4: a taken find is still a field item")
	return _result(m)


# ---------------------------------------------------------------------------
# QA follow-ups (M1, M3, L1, L2)
# ---------------------------------------------------------------------------

## Finds with an empty order and frozen false: the frozen shape, and the swap refuses with "frozen".
static func _t_empty_order() -> Dictionary:
	var m: Array = []
	var save := _save(["charm", "shield", "blade", "ring"])
	var two := [_find("f1", "salve"), _find("f2", "root")]
	var got := PickupCase.resolve(two, [], PickupCase.pack_room(save, _cfg()), false, _calm(), _cfg())
	_check_case(m, "empty order, full pack", got, "frozen", [], "", ["f1", "f2"], "none", 0)
	var offer := PickupSwapRules.offer(got, two, PickupSwapRules.pack_entries(save, _stage(save)), false)
	if offer != { "ok": false, "reason_key": "frozen" }:
		m.append("empty order: offer %s" % str(offer))
	return _result(m)


## An order that ranks only some finds keeps the old rule: taken and tried come from the order only, and
## every find not taken stays left.
static func _t_order_subset() -> Dictionary:
	var m: Array = []
	var three := [_find("f1", "salve"), _find("f2", "charm"), _find("f3", "root")]
	var got := PickupCase.resolve(three, _ordered(three, ["f3"]), PickupCase.pack_room(_save([]), _cfg(2)), false, _calm(), _cfg())
	_check_case(m, "subset order, room 2", got, "C2", ["f3"], "", ["f1", "f2"], "none", 2)
	got = PickupCase.resolve(three, _ordered(three, ["f2", "f1"]), PickupCase.pack_room(_save([]), _cfg(1)), false, _calm(), _cfg())
	_check_case(m, "subset order, room 1", got, "C2", ["f2"], "f1", ["f1", "f3"], "none", 1)
	return _result(m)


## C2 where the pick order of the left finds differs from find order: tried is the next PICK, not the next find.
static func _t_tried_order() -> Dictionary:
	var m: Array = []
	var four := [_find("f1", "salve"), _find("f2", "charm"), _find("f3", "root"), _find("f4", "ring")]
	var got := PickupCase.resolve(four, _ordered(four, ["f4", "f2", "f3", "f1"]),
		PickupCase.pack_room(_save([]), _cfg(2)), false, _calm(), _cfg())
	_check_case(m, "C2 pick order", got, "C2", ["f4", "f2"], "f3", ["f1", "f3"], "none", 2)
	return _result(m)


## A carried stack is a pack entry and a twin of a field find of its type; open rows of another stage and
## settled or lost rows are not listed (another stage's open row still counts in pack_room).
static func _t_pack_entries() -> Dictionary:
	var m: Array = []
	var save := _save(["charm", "shield", "blade"], ["herb", "moss", "bark"])
	save["inventory"]["pack_stacks"] = [{ "type_id": "salve", "kind": "consumable", "quantity": 2, "slot": 3 }]
	var rows := EarningsService.rows_of(_stage(save))
	(rows[1] as Dictionary)["settled"] = true
	(rows[2] as Dictionary)["lost"] = true
	var other := {}
	EarningsService.record_item(other, "sit_far", "g1", { "type_id": "ring", "kind": "gear", "grade": "", "quantity": 1 })
	save["realms"]["realm.02"] = { "stages": [other] }
	var room := PickupCase.pack_room(save, _cfg(6))
	if int(room["carried"]) != 6:
		m.append("carried %d, expected 6 (3 pieces, 1 stack, 1 open row here, 1 open row in another stage)" % int(room["carried"]))
	var pack := PickupSwapRules.pack_entries(save, _stage(save))
	var ids := pack.map(func(p: Dictionary) -> String: return str(p["id"]))
	if ids != ["it.1", "it.2", "it.3", "stack:salve:3", "item:sit_old:g1"]:
		m.append("pack entries %s" % str(ids))
	var finds := [_find("f1", "salve"), _find("f2", "root")]
	var event := PickupCase.resolve(finds, finds, room, false, _calm(), _cfg())
	if str(event["case"]) != "C5":
		m.append("fixture is not a full pack: %s" % str(event))
	var twin := PickupSwapRules.pair(event, finds, pack, false, "f1", "stack:salve:3")
	if twin != { "ok": false, "reason_key": "same" }:
		m.append("salve find for the carried salve stack: %s" % str(twin))
	if PickupSwapRules.pair(event, finds, pack, false, "f2", "stack:salve:3")["reason_key"] != "":
		m.append("root find for the carried salve stack is refused")
	if PickupSwapRules.pair(event, finds, pack, false, "f2", "item:sit_far:g1")["reason_key"] != "bad_pair":
		m.append("another stage's open row is a swap target")
	return _result(m)


## No legal pair: "same" only when every pair is a twin; "no_target" when no pack item is listed or a pair
## fails for another reason.
static func _t_no_target() -> Dictionary:
	var m: Array = []
	var s := _full_setup()
	var got := PickupSwapRules.offer(s["event"], s["finds"], [], false)
	if got != { "ok": false, "reason_key": "no_target" }:
		m.append("no pack item listed: %s" % str(got))
	var untyped := [{ "id": "it.1", "type_id": "" }, { "id": "it.2", "type_id": "charm" }]
	var charm := [_find("f1", "charm")]
	var event := PickupCase.resolve(charm, charm, PickupCase.pack_room(_save(["charm", "charm", "charm", "charm"]), _cfg()), false, _calm(), _cfg())
	got = PickupSwapRules.offer(event, charm, untyped, false)
	if got != { "ok": false, "reason_key": "no_target" }:
		m.append("a twin and an untyped pack item: %s" % str(got))
	got = PickupSwapRules.offer(event, charm, [{ "id": "it.1", "type_id": "charm" }, { "id": "it.2", "type_id": "charm" }], false)
	if got != { "ok": false, "reason_key": "same" }:
		m.append("every pair a twin: %s" % str(got))
	return _result(m)
