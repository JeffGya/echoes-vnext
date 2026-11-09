# res://tests/RecipeCostTests.gd
# The recipe price contract: RecipeCostService (lookup, validate, afford) and EconomyService.pay_cost.
# The cfg is the placeholder definitions plus the placeholder recipes and the grades g1 and g2. It is built
# new for each test and never comes from data/balance.json, except in the shipping data test.

class_name RecipeCostTests
extends RefCounted

const FIXTURE := "res://tests/fixtures/recipe_placeholders.json"
# The fixture prices: [output type, grade key, route, ekwan, ase].
const _PRICES := [
	["ph_weapon_a", "g1", "make", 7, 25],
	["ph_weapon_a", "g2", "make", 14, 45],
	["ph_weapon_a", "g2", "upgrade", 10, 32],
	["ph_charm_a", "g1", "make", 3, 45],
	["ph_consumable_a", "ungraded", "make", 2, 10],
	["ph_armor_a", "g1", "make", 8, 25],
]
const _MATERIAL := { "type_id": "ph_material_a", "count": 1 }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("recipe_cost/fixture_prices_are_read", Callable(RecipeCostTests, "_t_fixture_prices"))
	runner.register_test("recipe_cost/pay_takes_exactly_the_price", Callable(RecipeCostTests, "_t_pay_both"))
	runner.register_test("recipe_cost/short_side_pays_nothing", Callable(RecipeCostTests, "_t_short"))
	runner.register_test("recipe_cost/exact_balance_and_never_negative", Callable(RecipeCostTests, "_t_exact"))
	runner.register_test("recipe_cost/zero_side_is_skipped", Callable(RecipeCostTests, "_t_zero_side"))
	runner.register_test("recipe_cost/one_pay_spends_once", Callable(RecipeCostTests, "_t_once"))
	runner.register_test("recipe_cost/unknown_recipe", Callable(RecipeCostTests, "_t_unknown"))
	runner.register_test("recipe_cost/bad_cost", Callable(RecipeCostTests, "_t_bad_cost"))
	runner.register_test("recipe_cost/validate_finds_broken_records", Callable(RecipeCostTests, "_t_validate"))
	runner.register_test("recipe_cost/shipping_recipes_are_valid", Callable(RecipeCostTests, "_t_shipping"))
	runner.register_test("recipe_cost/negative_balance_zero_side_is_ok", Callable(RecipeCostTests, "_t_negative_zero_side"))
	runner.register_test("recipe_cost/ungraded_key_needs_a_gradeless_type", Callable(RecipeCostTests, "_t_ungraded_key"))
	runner.register_test("recipe_cost/item_rows_keep_no_currency", Callable(RecipeCostTests, "_t_item_rows"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _cfg() -> Dictionary:
	var cfg := InventoryServiceTests._cfg(20, 4)
	cfg["grades"] = ["g1", "g2"]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	cfg["recipes"] = (parsed as Dictionary).get("recipes", null) if parsed is Dictionary else null
	return cfg


## The cfg with one record set (the path is made when it does not exist).
static func _cfg_with(output_type: String, grade_key: String, route: String, record: Variant) -> Dictionary:
	var cfg := _cfg()
	var recipes: Dictionary = cfg["recipes"]
	if not recipes.has(output_type):
		recipes[output_type] = {}
	if not (recipes[output_type] as Dictionary).has(grade_key):
		recipes[output_type][grade_key] = {}
	recipes[output_type][grade_key][route] = record
	return cfg


static func _record(inputs: Variant, ekwan: Variant = 1, ase: Variant = 1) -> Dictionary:
	return { "inputs": inputs, "cost": { "ekwan": ekwan, "ase": ase } }


## [save, logger, EconomyService]. The logger keeps info lines, so a test can count them.
static func _env(ase: int, ekwan: int) -> Array:
	var save := { "economy": { "ase": ase, "ekwan": ekwan } }
	return [save, StructuredLogger.new(), EconomyService.new(save)]


static func _pay(env: Array, ekwan: Variant, ase: Variant) -> String:
	return (env[2] as EconomyService).pay_cost({ "ekwan": ekwan, "ase": ase }, "test.pay", env[1], 0)


static func _bal(env: Array) -> String:
	var econ: Dictionary = (env[0] as Dictionary)["economy"]
	return "%d/%d" % [int(econ["ekwan"]), int(econ["ase"])]


static func _log_count(env: Array, type: String) -> int:
	var n := 0
	for l in (env[1] as StructuredLogger).get_logs():
		if str(l.get("type", "")) == type:
			n += 1
	return n


static func _key(cfg: Dictionary, output_type: String, grade_key: String, route: String) -> String:
	return str(RecipeCostService.cost_of(cfg, output_type, grade_key, route)["reason_key"])


## Paths of the records whose Ekwan and Ase are both 0.
static func _zero_prices(recipes: Dictionary) -> Array:
	var out: Array = []
	for output_type in recipes.keys():
		for grade_key in (recipes[output_type] as Dictionary).keys():
			for route in (recipes[output_type][grade_key] as Dictionary).keys():
				var cost: Dictionary = RecipeCostService.read_cost(recipes[output_type][grade_key][route].get("cost", null))
				if not cost.is_empty() and int(cost["ekwan"]) == 0 and int(cost["ase"]) == 0:
					out.append("%s.%s.%s" % [output_type, grade_key, route])
	return out


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_fixture_prices() -> Dictionary:
	var m: Array = []
	var cfg := _cfg()
	var problems := RecipeCostService.validate(cfg)
	if not problems.is_empty():
		m.append("the fixture does not pass validate: %s" % str(problems))
	var records := 0
	for output_type in (cfg["recipes"] as Dictionary).keys():
		for grade_key in (cfg["recipes"][output_type] as Dictionary).keys():
			records += (cfg["recipes"][output_type][grade_key] as Dictionary).size()
	if records != _PRICES.size():
		m.append("the fixture holds %d records, expected %d" % [records, _PRICES.size()])
	for p in _PRICES:
		var got := RecipeCostService.cost_of(cfg, p[0], p[1], p[2])
		var cost: Dictionary = got["cost"]
		if got["reason_key"] != "ok" or typeof(cost.get("ekwan")) != TYPE_INT or typeof(cost.get("ase")) != TYPE_INT \
				or cost["ekwan"] != p[3] or cost["ase"] != p[4]:
			m.append("%s %s %s: got %s" % [p[0], p[1], p[2], str(got)])
	return _result(m)


static func _t_pay_both() -> Dictionary:
	var m: Array = []
	var cfg := _cfg()
	for p in _PRICES:
		var env := _env(100, 50)
		var cost: Dictionary = RecipeCostService.cost_of(cfg, p[0], p[1], p[2])["cost"]
		var key := (env[2] as EconomyService).pay_cost(cost, "craft.%s.%s" % [p[2], p[0]], env[1], 0)
		if key != "ok" or _bal(env) != "%d/%d" % [50 - int(p[3]), 100 - int(p[4])]:
			m.append("%s %s %s: key %s, balance %s" % [p[0], p[1], p[2], key, _bal(env)])
	return _result(m)


static func _t_short() -> Dictionary:
	var m: Array = []
	# [ase balance, ekwan balance, expected key] against the price 7 Ekwan / 25 Ase.
	for c in [[24, 50, "short_ase"], [100, 6, "short_ekwan"], [24, 6, "short_both"], [0, 0, "short_both"]]:
		var env := _env(c[0], c[1])
		var key := _pay(env, 7, 25)
		if key != c[2] or _bal(env) != "%d/%d" % [c[1], c[0]]:
			m.append("ase %d ekwan %d: key %s, balance %s" % [c[0], c[1], key, _bal(env)])
		if RecipeCostService.afford({ "ekwan": 7, "ase": 25 }, c[0], c[1]) != c[2]:
			m.append("afford(ase %d, ekwan %d) is not %s" % [c[0], c[1], c[2]])
		if _log_count(env, "economy.ase.spend") + _log_count(env, "economy.ekwan.spend") != 0 \
				or _log_count(env, "economy.pay") != 0 or _log_count(env, "economy.pay.denied") != 1:
			m.append("ase %d ekwan %d: wrong log lines" % [c[0], c[1]])
	return _result(m)


static func _t_exact() -> Dictionary:
	var m: Array = []
	var exact := _env(25, 7)
	if _pay(exact, 7, 25) != "ok" or _bal(exact) != "0/0":
		m.append("exact balance: %s" % _bal(exact))
	if _pay(exact, 7, 25) != "short_both" or _bal(exact) != "0/0":
		m.append("a pay from 0 changed the balance: %s" % _bal(exact))
	# 20 Ekwan / 60 Ase holds two prices of 7 / 25. Every later pay is refused and no balance goes below 0.
	var env := _env(60, 20)
	var paid := 0
	for i in 5:
		if _pay(env, 7, 25) == "ok":
			paid += 1
		var econ: Dictionary = (env[0] as Dictionary)["economy"]
		if int(econ["ase"]) < 0 or int(econ["ekwan"]) < 0:
			m.append("a balance is below 0 after pay %d: %s" % [i, _bal(env)])
	if paid != 2 or _bal(env) != "6/10":
		m.append("paid %d times, balance %s, expected 2 and 6/10" % [paid, _bal(env)])
	return _result(m)


static func _t_zero_side() -> Dictionary:
	var m: Array = []
	var ase_only := _env(10, 0)
	if _pay(ase_only, 0, 5) != "ok" or _bal(ase_only) != "0/5":
		m.append("0 Ekwan / 5 Ase with no Ekwan held: %s" % _bal(ase_only))
	var ekwan_only := _env(0, 10)
	if _pay(ekwan_only, 3, 0) != "ok" or _bal(ekwan_only) != "7/0":
		m.append("3 Ekwan / 0 Ase with no Ase held: %s" % _bal(ekwan_only))
	var free := _env(4, 4)
	if _pay(free, 0, 0) != "ok" or _bal(free) != "4/4":
		m.append("a price of 0 / 0: %s" % _bal(free))
	if (free[1] as StructuredLogger).get_logs().size() != 1 or _log_count(free, "economy.pay") != 1:
		m.append("a price of 0 / 0 must write exactly one line (economy.pay)")
	for env in [ase_only, ekwan_only, free]:
		if _log_count(env, "economy.ase.spend_denied") + _log_count(env, "economy.ekwan.spend_denied") != 0:
			m.append("a side that costs 0 wrote a denied line")
	return _result(m)


static func _t_once() -> Dictionary:
	var m: Array = []
	var env := _env(100, 50)
	_pay(env, 7, 25)
	for type in ["economy.pay", "economy.ase.spend", "economy.ekwan.spend"]:
		if _log_count(env, type) != 1:
			m.append("%s was logged %d times" % [type, _log_count(env, type)])
	for l in (env[1] as StructuredLogger).get_logs():
		if l["type"] == "economy.pay" and (l["data"] as Dictionary).get("reason_key", null) != "ok":
			m.append("the economy.pay line has no reason_key ok: %s" % str(l["data"]))
	if (env[1] as StructuredLogger).get_logs().size() != 3 or _bal(env) != "43/75":
		m.append("one pay: %d log lines, balance %s" % [(env[1] as StructuredLogger).get_logs().size(), _bal(env)])
	return _result(m)


static func _t_unknown() -> Dictionary:
	var m: Array = []
	var cfg := _cfg()
	# No record: an unknown output, a grade with no record, a route with no record, a route that does not exist.
	for q in [["ph_nope", "g1", "make"], ["ph_weapon_a", "g3", "make"], ["ph_charm_a", "g2", "make"],
			["ph_weapon_a", "ungraded", "make"], ["ph_weapon_a", "g1", "upgrade"], ["ph_weapon_a", "g1", "repair"],
			["ph_weapon_a", "g1", ""], ["ph_relic_a", "g2", "make"]]:
		var got := RecipeCostService.cost_of(cfg, q[0], q[1], q[2])
		if got["reason_key"] != "unknown_recipe" or not (got["cost"] as Dictionary).is_empty():
			m.append("%s: got %s" % [str(q), str(got)])
	# A record that names something that does not exist, or a relic output.
	var good := _record([_MATERIAL])
	if _key(_cfg_with("ph_ghost", "g1", "make", good), "ph_ghost", "g1", "make") != "unknown_recipe":
		m.append("an output with no definition is not unknown_recipe")
	if _key(_cfg_with("ph_weapon_a", "g9", "make", good), "ph_weapon_a", "g9", "make") != "unknown_recipe":
		m.append("a grade that is not in grades is not unknown_recipe")
	if _key(_cfg_with("ph_relic_a", "g2", "make", good), "ph_relic_a", "g2", "make") != "unknown_recipe":
		m.append("a relic output is not unknown_recipe")
	var ghost_input := _record([{ "type_id": "ph_ghost", "count": 1 }], 1, "x")
	if _key(_cfg_with("ph_weapon_a", "g1", "make", ghost_input), "ph_weapon_a", "g1", "make") != "unknown_recipe":
		m.append("an input with no definition (and a bad cost) is not unknown_recipe: unknown_recipe comes first")
	for broken in [null, [], "x"]:
		var no_block := _cfg()
		no_block["recipes"] = broken
		if _key(no_block, "ph_weapon_a", "g1", "make") != "unknown_recipe":
			m.append("recipes = %s is not unknown_recipe" % str(broken))
	return _result(m)


static func _t_bad_cost() -> Dictionary:
	var m: Array = []
	for bad in [10.5, -1, -1.0, "7", true, null, NAN, INF, 1e300, 9007199254740994.0]:
		for side in ["ekwan", "ase"]:
			var cost := { "ekwan": 1, "ase": 1 }
			cost[side] = bad
			var cfg := _cfg_with("ph_weapon_a", "g1", "make", { "inputs": [_MATERIAL], "cost": cost })
			if _key(cfg, "ph_weapon_a", "g1", "make") != "bad_cost":
				m.append("cost_of with %s = %s is not bad_cost" % [side, str(bad)])
			var env := _env(50, 50)
			var key := (env[2] as EconomyService).pay_cost(cost, "test.pay", env[1], 0)
			if key != "bad_cost" or _bal(env) != "50/50":
				m.append("pay_cost with %s = %s: key %s, balance %s" % [side, str(bad), key, _bal(env)])
			var logs: Array = (env[1] as StructuredLogger).get_logs()
			if logs.size() != 1 or logs[0]["type"] != "economy.pay.config_error" or logs[0]["sev"] != StructuredLogger.LEVEL_ERROR:
				m.append("pay_cost with %s = %s did not write one error line" % [side, str(bad)])
	# A missing key is not 0. An extra key is refused.
	for cost in [{ "ekwan": 1 }, { "ase": 1 }, {}, { "ekwan": 1, "ase": 1, "gold": 1 }]:
		var cfg := _cfg_with("ph_weapon_a", "g1", "make", { "inputs": [_MATERIAL], "cost": cost })
		var env := _env(50, 50)
		if _key(cfg, "ph_weapon_a", "g1", "make") != "bad_cost" \
				or (env[2] as EconomyService).pay_cost(cost, "test.pay", env[1], 0) != "bad_cost" or _bal(env) != "50/50":
			m.append("cost %s is not bad_cost" % str(cost))
	if _key(_cfg_with("ph_weapon_a", "g1", "make", { "inputs": [_MATERIAL] }), "ph_weapon_a", "g1", "make") != "bad_cost":
		m.append("a record with no cost is not bad_cost")
	if _key(_cfg_with("ph_weapon_a", "g1", "make", "x"), "ph_weapon_a", "g1", "make") != "bad_cost":
		m.append("a record that is not a Dictionary is not bad_cost")
	# A whole-number float is a valid price and reads as an int.
	var whole := RecipeCostService.cost_of(_cfg_with("ph_weapon_a", "g1", "make", _record([_MATERIAL], 10.0, 0.0)), "ph_weapon_a", "g1", "make")
	if whole["reason_key"] != "ok" or typeof(whole["cost"].get("ekwan")) != TYPE_INT or whole["cost"]["ekwan"] != 10 or whole["cost"]["ase"] != 0:
		m.append("10.0 / 0.0: got %s" % str(whole))
	var float_env := _env(50, 50)
	if _pay(float_env, 10.0, 5.0) != "ok" or _bal(float_env) != "40/45":
		m.append("pay of 10.0 / 5.0: balance %s" % _bal(float_env))
	return _result(m)


static func _t_validate() -> Dictionary:
	var m: Array = []
	var weapon := { "type_id": "ph_weapon_a", "count": 1 }
	# [label, output type, grade key, route, record, text the problem must hold]
	var broken := [
		["relic make", "ph_relic_a", "g2", "make", _record([_MATERIAL]), "relic"],
		["relic upgrade", "ph_relic_a", "g2", "upgrade", _record([{ "type_id": "ph_relic_a", "count": 1 }]), "relic"],
		["upgrade with no base", "ph_weapon_a", "g1", "upgrade", _record([_MATERIAL]), "gear or relic"],
		["upgrade with no input", "ph_weapon_a", "g1", "upgrade", _record([]), "gear or relic"],
		["input listed twice", "ph_weapon_a", "g1", "make", _record([_MATERIAL, { "type_id": "ph_material_a", "count": 3 }]), "twice"],
		["unknown input", "ph_weapon_a", "g1", "make", _record([{ "type_id": "ph_ghost", "count": 1 }]), "ph_ghost"],
		["unknown output", "ph_ghost", "g1", "make", _record([_MATERIAL]), "output type"],
		["grade off the ladder", "ph_weapon_a", "g9", "make", _record([_MATERIAL]), "grade key"],
		["count 0", "ph_weapon_a", "g1", "make", _record([{ "type_id": "ph_material_a", "count": 0 }]), "input"],
		["count 1.5", "ph_weapon_a", "g1", "make", _record([{ "type_id": "ph_material_a", "count": 1.5 }]), "input"],
		["input not a Dictionary", "ph_weapon_a", "g1", "make", _record(["ph_material_a"]), "input"],
		["no inputs key", "ph_weapon_a", "g1", "make", { "cost": { "ekwan": 1, "ase": 1 } }, "inputs"],
		["bad cost", "ph_weapon_a", "g1", "make", _record([_MATERIAL], 1, 2.5), "cost"],
		["unknown route", "ph_weapon_a", "g1", "repair", _record([_MATERIAL]), "route"],
	]
	for b in broken:
		var problems := RecipeCostService.validate(_cfg_with(b[1], b[2], b[3], b[4]))
		if problems.size() != 1 or not str(problems[0]).contains(b[5]):
			m.append("%s: problems %s" % [b[0], str(problems)])
	# A consumable is not a base: an upgrade with only a consumable input is refused by validate and cost_of.
	var consumable_only := _cfg_with("ph_weapon_a", "g1", "upgrade", _record([{ "type_id": "ph_consumable_a", "count": 1 }]))
	var consumable_problems := RecipeCostService.validate(consumable_only)
	if consumable_problems.size() != 1 or not str(consumable_problems[0]).contains("gear or relic") \
			or _key(consumable_only, "ph_weapon_a", "g1", "upgrade") != "bad_cost":
		m.append("an upgrade with only a consumable: %s" % str(consumable_problems))
	# Valid: a relic as an input (it is also the base of the upgrade), no input on a make, a price of 0 / 0.
	for ok_record in [["upgrade", _record([{ "type_id": "ph_relic_a", "count": 1 }])], ["upgrade", _record([weapon])],
			["make", _record([])], ["make", _record([_MATERIAL], 0, 0)]]:
		var problems := RecipeCostService.validate(_cfg_with("ph_weapon_a", "g1", ok_record[0], ok_record[1]))
		if not problems.is_empty():
			m.append("a valid %s record has problems: %s" % [ok_record[0], str(problems)])
	# The block and its levels.
	var empty_route := _cfg()
	empty_route["recipes"]["ph_weapon_a"]["g1"] = {}
	var empty_type := _cfg()
	empty_type["recipes"]["ph_weapon_a"] = {}
	var not_a_dict := _cfg()
	not_a_dict["recipes"] = []
	for bad_cfg in [empty_route, empty_type, not_a_dict]:
		if RecipeCostService.validate(bad_cfg).size() != 1:
			m.append("a broken block gives %s" % str(RecipeCostService.validate(bad_cfg)))
	var none := _cfg()
	none.erase("recipes")
	var empty := _cfg()
	empty["recipes"] = {}
	if not RecipeCostService.validate(none).is_empty() or not RecipeCostService.validate(empty).is_empty():
		m.append("a missing or empty recipes block must be valid")
	return _result(m)


static func _t_negative_zero_side() -> Dictionary:
	var m: Array = []
	if RecipeCostService.afford({ "ekwan": 0, "ase": 5 }, 10, -3) != "ok":
		m.append("0 Ekwan with a balance of -3 is not ok")
	if RecipeCostService.afford({ "ekwan": 5, "ase": 0 }, -3, 10) != "ok":
		m.append("0 Ase with a balance of -3 is not ok")
	if RecipeCostService.afford({ "ekwan": 5, "ase": 0 }, -3, 2) != "short_ekwan":
		m.append("a priced side must stay short")
	var env := _env(10, -3)
	if _pay(env, 0, 5) != "ok" or _bal(env) != "-3/5":
		m.append("pay 0 Ekwan / 5 Ase with -3 Ekwan: %s" % _bal(env))
	return _result(m)


static func _t_ungraded_key() -> Dictionary:
	var m: Array = []
	var gear := _cfg_with("ph_weapon_a", "ungraded", "make", _record([_MATERIAL]))
	if _key(gear, "ph_weapon_a", "ungraded", "make") != "unknown_recipe" or RecipeCostService.validate(gear).size() != 1:
		m.append("a gear under ungraded is not refused")
	# A laddered key on a type whose grade is "" is not refused by this rule.
	var gradeless := _cfg_with("ph_consumable_a", "g1", "make", _record([_MATERIAL]))
	if _key(gradeless, "ph_consumable_a", "g1", "make") != "ok":
		m.append("a laddered key on a gradeless type must stay ok")
	if _key(_cfg(), "ph_consumable_a", "ungraded", "make") != "ok":
		m.append("the fixture consumable under ungraded is not ok")
	return _result(m)


## Shipping data: `data.inventory.recipes` passes validate, holds no placeholder id and no free make.
static func _t_shipping() -> Dictionary:
	var m: Array = []
	var config := InventorySaveTests._config()
	var inv_cfg := ConfigService.get_inventory_cfg(config)
	if not (inv_cfg.get("recipes", null) is Dictionary):
		return { "ok": false, "error": "data.inventory.recipes is not a Dictionary" }
	var recipes := ConfigService.get_recipes_cfg(config)
	if JSON.stringify(recipes) != JSON.stringify(inv_cfg["recipes"]) or not ConfigService.get_recipes_cfg(null).is_empty():
		m.append("get_recipes_cfg does not return data.inventory.recipes, or is not {} for a null service")
	var problems := RecipeCostService.validate(inv_cfg)
	if not problems.is_empty():
		m.append("shipping recipes do not pass validate: %s" % str(problems))
	if InventorySaveTests._has_placeholder_id(JSON.stringify(recipes)):
		m.append("shipping recipes hold a ph_ id")
	if not _zero_prices(recipes).is_empty():
		m.append("shipping recipes with a price of 0 Ekwan and 0 Ase: %s" % str(_zero_prices(recipes)))
	# The detector itself: it finds a free record and finds none in the fixture.
	var free := _cfg_with("ph_charm_a", "g2", "make", _record([_MATERIAL], 0, 0))
	if str(_zero_prices(free["recipes"])) != str(["ph_charm_a.g2.make"]) or not _zero_prices(_cfg()["recipes"]).is_empty():
		m.append("_zero_prices does not find exactly the free record")
	return _result(m)


## An item is never a currency: its row in the packs holds 0 Ase and 0 Ekwan before and after a payment.
static func _t_item_rows() -> Dictionary:
	var m: Array = []
	var stage := { "index": 0 }
	if not EarningsService.record_item(stage, "s0", "0", ItemPacksTests._entry("ph_weapon_a")):
		m.append("setup: the item row was refused")
	var before := JSON.stringify(stage)
	var env := _env(100, 50)
	if _pay(env, 7, 25) != "ok":
		m.append("setup: the pay failed")
	var rows := EarningsService.rows_of(stage)
	if rows.size() != 1 or int(rows[0]["ase"]) != 0 or int(rows[0]["ekwan"]) != 0 or JSON.stringify(stage) != before:
		m.append("the item row changed: %s" % JSON.stringify(stage))
	return _result(m)
