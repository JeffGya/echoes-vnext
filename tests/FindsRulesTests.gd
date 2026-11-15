# res://tests/FindsRulesTests.gd
# FindsRules (finds cap by realm scale, per-slot chance by rank, the count roll) and ConfigValidator.validate_finds.
# Tests use _cfg() (the D-46/D-50 numbers, fixed here) and never depend on the tuned shipping values,
# except the shipping-config validator test.

class_name FindsRulesTests
extends RefCounted

const _WIN_RANKS := ["D", "C", "B", "A", "S"]
const _SEEDS := [1, 42, 9001, 123456789, 7777777]

# [realm_seed, stage_id, run_count, situation_id, realm_scale, rank, pinned count].
const _GOLDEN := [
	[1, "stage_01", 0, "sit_a", 1.0, "C", 1],
	[1, "stage_01", 0, "sit_b", 1.0, "S", 1],
	[42, "stage_01", 1, "sit_a", 1.25, "C", 1],
	[42, "stage_02", 0, "sit_c", 1.25, "B", 2],
	[9001, "stage_02", 2, "sit_a", 1.75, "A", 1],
	[9001, "stage_03", 0, "sit_d", 1.75, "C", 3],
	[123456789, "stage_01", 0, "sit_a", 2.5, "S", 3],
	[123456789, "stage_04", 3, "sit_e", 2.5, "B", 2],
	[7777777, "stage_02", 1, "sit_b", 3.5, "C", 3],
	[7777777, "stage_05", 0, "sit_f", 3.5, "A", 1],
	[555, "stage_01", 0, "sit_a", 1.0, "C", 2],
	[555, "stage_01", 0, "sit_a", 1.0, "A", 2],
	[31337, "stage_03", 2, "sit_g", 1.25, "S", 3],
	[31337, "stage_03", 2, "sit_h", 1.25, "S", 3],
	[2024, "stage_06", 0, "sit_a", 1.75, "B", 1],
	[2024, "stage_06", 1, "sit_a", 1.75, "B", 3],
	[86, "stage_02", 0, "sit_i", 2.5, "C", 4],
	[86, "stage_02", 0, "sit_j", 3.5, "S", 4],
	[1000003, "stage_07", 4, "sit_k", 3.5, "B", 2],
	[1000003, "stage_07", 4, "sit_l", 1.0, "D", 0],
]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("finds_rules/cap_bands_and_edges", Callable(FindsRulesTests, "_t_cap_bands"))
	runner.register_test("finds_rules/cap_missing_key_is_no_cap", Callable(FindsRulesTests, "_t_cap_missing"))
	runner.register_test("finds_rules/slot_chance_per_rank_and_clamp", Callable(FindsRulesTests, "_t_chance"))
	runner.register_test("finds_rules/exactly_cap_draws_always", Callable(FindsRulesTests, "_t_exact_draws"))
	runner.register_test("finds_rules/count_is_the_number_of_hits", Callable(FindsRulesTests, "_t_count_is_hits"))
	runner.register_test("finds_rules/roll_uses_the_finds_stream", Callable(FindsRulesTests, "_t_stream"))
	runner.register_test("finds_rules/loss_rank_draws_nothing", Callable(FindsRulesTests, "_t_loss"))
	runner.register_test("finds_rules/same_inputs_same_count", Callable(FindsRulesTests, "_t_determinism"))
	runner.register_test("finds_rules/validator_accepts_test_and_shipping_config", Callable(FindsRulesTests, "_t_validator_ok"))
	runner.register_test("finds_rules/validator_rejects_each_bad_shape", Callable(FindsRulesTests, "_t_validator_bad"))
	runner.register_test("finds_rules/golden_counts", Callable(FindsRulesTests, "_t_golden"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _cfg() -> Dictionary:
	return {
		"finds_cap_by_realm_scale": [
			{ "scale": 1.0, "cap": 2 }, { "scale": 1.25, "cap": 3 }, { "scale": 1.75, "cap": 4 },
			{ "scale": 2.5, "cap": 5 }, { "scale": 3.5, "cap": 6 },
		],
		"finds_chance": {
			"base_by_slot_pct": [85, 60, 40, 25, 15, 8],
			"rank_modifier_pct": { "D": -10, "C": 0, "B": 5, "A": 10, "S": 15 },
			"max_pct": 98,
			"first_find_floor_pct": 60,
			"first_find_floor_rank": "C",
		},
	}


static func _rng(seed: int, path: String) -> RandomNumberGenerator:
	return CampaignSeed.get_rng_from(seed, path)


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Highest band at or below the scale; a scale a hair under an edge (float sum) stays on the edge band.
static func _t_cap_bands() -> Dictionary:
	var m: Array = []
	var cases := [
		[0.5, 2], [1.0, 2], [1.2499, 2], [1.25 - 0.000000001, 3], [1.25, 3], [1.5, 3], [1.75, 4],
		[1.0 + 0.25 * 3.0, 4], [2.4999, 4], [2.5, 5], [3.4999, 5], [3.5, 6], [10.0, 6],
	]
	for c in cases:
		var got := FindsRules.cap_for_scale(_cfg(), float(c[0]))
		if got != int(c[1]):
			m.append("scale %s: cap %d, expected %d" % [str(c[0]), got, int(c[1])])
	return _result(m)


static func _t_cap_missing() -> Dictionary:
	var m: Array = []
	if FindsRules.cap_for_scale({}, 1.0) != FindsRules.NO_CAP:
		m.append("a missing key does not give NO_CAP")
	if FindsRules.cap_for_scale({ "finds_cap_by_realm_scale": [] }, 1.0) != FindsRules.NO_CAP:
		m.append("an empty band list does not give NO_CAP")
	var no_cap := _cfg()
	no_cap.erase("finds_cap_by_realm_scale")
	if FindsRules.roll_count(no_cap, 42, "stage_01", 0, "sit_a", 1.0, "S") != 0:
		m.append("roll_count with no cap key is not 0")
	return _result(m)


static func _t_chance() -> Dictionary:
	var m: Array = []
	# rank -> chance of slots 0..5 with base [85,60,40,25,15,8] and max 98.
	var expected := {
		"D": [75, 50, 30, 15, 5, 0], "C": [85, 60, 40, 25, 15, 8], "B": [90, 65, 45, 30, 20, 13],
		"A": [95, 70, 50, 35, 25, 18], "S": [98, 75, 55, 40, 30, 23],
	}
	for rank in expected.keys():
		for slot in range(6):
			var got := FindsRules.slot_chance_pct(_cfg(), slot, rank)
			if got != int(expected[rank][slot]):
				m.append("%s slot %d: %d, expected %d" % [rank, slot, got, int(expected[rank][slot])])
	for bad in [["F", 0], ["", 0], ["X", 0], ["C", 6], ["C", -1]]:
		if FindsRules.slot_chance_pct(_cfg(), int(bad[1]), str(bad[0])) != 0:
			m.append("rank %s slot %d is not 0" % [str(bad[0]), int(bad[1])])
	# JSON floats read as whole numbers.
	var floats := _cfg()
	floats["finds_chance"]["base_by_slot_pct"] = [85.0, 60.0]
	if FindsRules.slot_chance_pct(floats, 1, "B") != 65:
		m.append("float config values are not read as whole numbers")
	return _result(m)


## The rng after the roll equals a fresh rng of the same seed advanced by exactly `cap` draws,
## also when every slot misses (chance 0) and when every slot hits (chance 100).
static func _t_exact_draws() -> Dictionary:
	var m: Array = []
	var none := _cfg()
	none["finds_chance"]["base_by_slot_pct"] = [0, 0, 0, 0, 0, 0]
	none["finds_chance"]["rank_modifier_pct"] = { "C": 0 }
	var all := _cfg()
	all["finds_chance"]["base_by_slot_pct"] = [100, 100, 100, 100, 100, 100]
	all["finds_chance"]["rank_modifier_pct"] = { "C": 0 }
	all["finds_chance"]["max_pct"] = 100
	for cfg_case in [["shipping", _cfg(), _WIN_RANKS], ["none", none, ["C"]], ["all", all, ["C"]]]:
		for seed in _SEEDS:
			for cap in range(1, 7):
				for rank in cfg_case[2]:
					var path := "inventory.finds.s.%d.x" % cap
					var used := _rng(seed, path)
					var hits := FindsRules.roll_count_with(cfg_case[1], used, cap, rank)
					var ref := _rng(seed, path)
					for i in range(cap):
						ref.randi_range(0, 99)
					if used.state != ref.state:
						m.append("%s seed %d cap %d rank %s: not exactly %d draws" % [cfg_case[0], seed, cap, rank, cap])
					if cfg_case[0] == "none" and hits != 0:
						m.append("chance 0 gave %d hits" % hits)
					if cfg_case[0] == "all" and hits != cap:
						m.append("chance 100 gave %d hits at cap %d" % [hits, cap])
	# Cap 8 with a 6-slot base: still 8 draws, and the two slots past the list never hit.
	for seed in _SEEDS:
		var used8 := _rng(seed, "inventory.finds.s.8.x")
		var hits8 := FindsRules.roll_count_with(all, used8, 8, "C")
		var ref8 := _rng(seed, "inventory.finds.s.8.x")
		for i in range(8):
			ref8.randi_range(0, 99)
		if used8.state != ref8.state:
			m.append("seed %d cap 8 over a 6-slot base: not exactly 8 draws" % seed)
		if hits8 != 6:
			m.append("seed %d cap 8 over a 6-slot base: %d hits, expected 6" % [seed, hits8])
	return _result(m)


## Independent slots: the count is the number of slots whose roll is below that slot's chance, also when
## an earlier slot missed. The sample must hold a miss followed by a hit, or the test proves nothing.
static func _t_count_is_hits() -> Dictionary:
	var m: Array = []
	var miss_then_hit := 0
	for seed in range(1, 201):
		for rank in _WIN_RANKS:
			var path := "inventory.finds.stage_01.0.sit_%d" % seed
			var got := FindsRules.roll_count_with(_cfg(), _rng(seed, path), 6, rank)
			var ref := _rng(seed, path)
			var hits := 0
			var missed := false
			for slot in range(6):
				var hit: bool = ref.randi_range(0, 99) < FindsRules.slot_chance_pct(_cfg(), slot, rank)
				if hit:
					hits += 1
					if missed:
						miss_then_hit += 1
				else:
					missed = true
			if got != hits:
				m.append("seed %d rank %s: count %d, hits %d" % [seed, rank, got, hits])
	if miss_then_hit == 0:
		m.append("the sample has no miss followed by a hit")
	return _result(m)


## Proves the path only. Each call builds its own generator, so a test here cannot show that an event leaves a
## settlement unchanged; C6/C9 prove that (a leave settlement is identical with and without an earlier event).
static func _t_stream() -> Dictionary:
	var m: Array = []
	if FindsRules.stream_path("stage_02", 3, "sit_x") != "inventory.finds.stage_02.3.sit_x":
		m.append("stream_path is %s" % FindsRules.stream_path("stage_02", 3, "sit_x"))
	for g in _GOLDEN:
		var cap := FindsRules.cap_for_scale(_cfg(), float(g[4]))
		var expected := FindsRules.roll_count_with(_cfg(),
			_rng(int(g[0]), "inventory.finds.%s.%d.%s" % [g[1], int(g[2]), g[3]]), cap, str(g[5]))
		var got := FindsRules.roll_count(_cfg(), int(g[0]), str(g[1]), int(g[2]), str(g[3]), float(g[4]), str(g[5]))
		if got != expected:
			m.append("%s: roll_count %d, the finds stream gives %d" % [str(g), got, expected])
	# Another situation id is another stream: the seeds differ and the counts are not all the same.
	var counts := {}
	for i in range(30):
		var sit := "sit_%d" % i
		if CampaignSeed.derive_from(42, FindsRules.stream_path("stage_01", 0, sit)) \
				== CampaignSeed.derive_from(42, FindsRules.stream_path("stage_01", 0, "sit_other")):
			m.append("%s has the seed of sit_other" % sit)
		counts[FindsRules.roll_count(_cfg(), 42, "stage_01", 0, sit, 3.5, "C")] = true
	if counts.size() < 2:
		m.append("30 situation ids gave one count: %s" % str(counts.keys()))
	return _result(m)


static func _t_loss() -> Dictionary:
	var m: Array = []
	for rank in ["F", "", "Z"]:
		var rng := _rng(42, "inventory.finds.stage_01.0.sit_a")
		var before := rng.state
		if FindsRules.roll_count_with(_cfg(), rng, 6, rank) != 0 or rng.state != before:
			m.append("rank '%s' drew or counted" % rank)
		if FindsRules.roll_count(_cfg(), 42, "stage_01", 0, "sit_a", 3.5, rank) != 0:
			m.append("roll_count at rank '%s' is not 0" % rank)
	var rng0 := _rng(42, "x")
	var before0 := rng0.state
	if FindsRules.roll_count_with(_cfg(), rng0, 0, "S") != 0 or rng0.state != before0:
		m.append("cap 0 drew or counted")
	return _result(m)


static func _t_determinism() -> Dictionary:
	var m: Array = []
	for g in _GOLDEN:
		var a := FindsRules.roll_count(_cfg(), int(g[0]), str(g[1]), int(g[2]), str(g[3]), float(g[4]), str(g[5]))
		var b := FindsRules.roll_count(_cfg(), int(g[0]), str(g[1]), int(g[2]), str(g[3]), float(g[4]), str(g[5]))
		if a != b:
			m.append("%s: %d then %d" % [str(g), a, b])
	return _result(m)


static func _t_validator_ok() -> Dictionary:
	var m: Array = []
	var problems := ConfigValidator.validate_finds(_cfg())
	if not problems.is_empty():
		m.append("the test config fails: %s" % str(problems))
	var shipping := ConfigService.get_inventory_cfg(InventorySaveTests._config())
	problems = ConfigValidator.validate_finds(shipping)
	if not problems.is_empty():
		m.append("the shipping config fails: %s" % str(problems))
	return _result(m)


## Each bad config breaks one rule and gives exactly one problem that names it (two where noted).
static func _t_validator_bad() -> Dictionary:
	var m: Array = []
	var cases: Array = []
	var c := _cfg()
	c.erase("finds_cap_by_realm_scale")
	cases.append(["bands missing", c, "missing or empty"])
	c = _cfg()
	c["finds_cap_by_realm_scale"] = []
	cases.append(["bands empty", c, "missing or empty"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][0] = 5
	cases.append(["band not a Dictionary", c, "a band is not"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][0]["scale"] = "1.0"
	cases.append(["band scale not a number", c, "a band is not"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][1]["scale"] = 1.0
	cases.append(["scales not ascending", c, "not ascending"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][0]["cap"] = 0
	cases.append(["cap below 1", c, "below 1"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][1]["cap"] = 1
	cases.append(["caps decreasing", c, "below the band before"])
	c = _cfg()
	c["finds_cap_by_realm_scale"][1]["cap"] = 2.5
	cases.append(["cap not whole", c, "a band is not"])
	c = _cfg()
	c.erase("finds_chance")
	cases.append(["chance missing", c, "finds_chance is missing"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [85, 60, 40, 25, 15]
	cases.append(["base shorter than the largest cap", c, "the largest cap needs 6"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [85, 90, 40, 25, 15, 8]
	cases.append(["base increasing", c, "base_by_slot_pct: 90"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [101, 60, 40, 25, 15, 8]
	cases.append(["base above 100", c, "base_by_slot_pct: 101"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [85, 60, 40, 25, 15, -1]
	cases.append(["base negative", c, "base_by_slot_pct: -1"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [85, 60.5, 40, 25, 15, 8]
	cases.append(["base not whole", c, "base_by_slot_pct: 60.5"])
	c = _cfg()
	c["finds_chance"]["rank_modifier_pct"]["S"] = 150
	cases.append(["modifier above 100", c, "rank_modifier_pct.S"])
	c = _cfg()
	c["finds_chance"]["rank_modifier_pct"]["D"] = -150
	cases.append(["modifier below -100", c, "rank_modifier_pct.D"])
	c = _cfg()
	c["finds_chance"]["rank_modifier_pct"] = {}
	cases.append(["modifiers empty (the floor rank then has no modifier too)", c, "rank_modifier_pct is missing or empty", 2])
	c = _cfg()
	c["finds_chance"]["max_pct"] = 101
	cases.append(["max above 100", c, "max_pct"])
	# A max below 1 or not whole also breaks the floor check, so these give two problems.
	c = _cfg()
	c["finds_chance"]["max_pct"] = 0
	cases.append(["max below 1 (slot 0 then clamps under the floor)", c, "max_pct", 2])
	c = _cfg()
	c["finds_chance"]["max_pct"] = 97.5
	cases.append(["max not whole (the floor check is then unusable)", c, "max_pct", 2])
	c = _cfg()
	c["finds_chance"].erase("first_find_floor_pct")
	cases.append(["floor missing", c, "unusable"])
	c = _cfg()
	c["finds_chance"]["first_find_floor_pct"] = 60.5
	cases.append(["floor not whole", c, "unusable"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [59, 59, 40, 25, 15, 8]
	cases.append(["first find one point below the floor", c, "below the floor 60%"])
	c = _cfg()
	c["finds_chance"] = "x"
	cases.append(["chance not a Dictionary", c, "finds_chance is missing or not a Dictionary"])
	c = _cfg()
	c["finds_chance"]["base_by_slot_pct"] = [55, 55, 40, 25, 15, 8]
	cases.append(["first find below the floor", c, "below the floor 60%"])
	c = _cfg()
	c["finds_chance"]["rank_modifier_pct"]["C"] = -30
	cases.append(["floor rank modifier pulls slot 0 below the floor", c, "below the floor 60%"])
	c = _cfg()
	c["finds_chance"]["first_find_floor_rank"] = "F"
	cases.append(["floor rank has no modifier", c, "unusable"])
	for bad in cases:
		var problems := ConfigValidator.validate_finds(bad[1])
		var count: int = bad[3] if bad.size() > 3 else 1
		if problems.size() != count or str(problems[0]).find(bad[2]) < 0:
			m.append("%s: %s" % [bad[0], str(problems)])
	# Floor edge: a first find exactly at the floor is valid.
	var edge := _cfg()
	edge["finds_chance"]["base_by_slot_pct"] = [60, 60, 40, 25, 15, 8]
	if not ConfigValidator.validate_finds(edge).is_empty():
		m.append("first find equal to the floor is refused: %s" % str(ConfigValidator.validate_finds(edge)))
	return _result(m)


## Pinned counts. A moved count means the stream path, the draw count, the hit rule or the band rule changed.
static func _t_golden() -> Dictionary:
	var m: Array = []
	var actual: Array = []
	for g in _GOLDEN:
		var got := FindsRules.roll_count(_cfg(), int(g[0]), str(g[1]), int(g[2]), str(g[3]), float(g[4]), str(g[5]))
		actual.append(got)
		if got != int(g[6]):
			m.append("%s: %d" % [str(g), got])
	if not m.is_empty():
		m.append("actual counts in table order: %s" % str(actual))
	return _result(m)
