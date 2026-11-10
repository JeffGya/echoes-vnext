# res://core/economy/RecipeCostService.gd
# Owns the price of a recipe: the lookup of one price record in `data.inventory.recipes`, the checks of the
# whole block, and the afford check. Pure and static: no save write, no RNG, no log. It never reads `inputs`
# as a price: an item is never a currency. The payment itself is `EconomyService.pay_cost`.
#
# recipes: { <output type_id>: { <grade key>: { "make": record, "upgrade": record } } }
# record:  { "inputs": [ { "type_id": String, "count": int >= 1 } ], "cost": { "ekwan": int, "ase": int } }

class_name RecipeCostService
extends RefCounted

const OK := "ok"
const SHORT_ASE := "short_ase"
const SHORT_EKWAN := "short_ekwan"
const SHORT_BOTH := "short_both"
const UNKNOWN_RECIPE := "unknown_recipe"
const BAD_COST := "bad_cost"

const ROUTE_MAKE := "make"
const ROUTE_UPGRADE := "upgrade"
const ROUTES := [ROUTE_MAKE, ROUTE_UPGRADE]
## Grade key of a type that has no grade (a consumable, a material).
const UNGRADED := "ungraded"

const _BASE_KINDS := ["gear", "relic"]
const _RELIC := "relic"


## The price of one record: { reason_key, cost }. `cost` is { ekwan: int, ase: int } when the key is `ok`,
## else {}. `unknown_recipe`: this output cannot be made this way (no record, or an output, grade or input
## that does not exist, or a relic output). `bad_cost`: the record exists and its shape or a number is wrong.
## A missing grade is never free and never read from another grade.
static func cost_of(inv_cfg: Dictionary, output_type: String, grade_key: String, route: String) -> Dictionary:
	var recipes: Variant = inv_cfg.get("recipes", null)
	var grades: Variant = (recipes as Dictionary).get(output_type, null) if recipes is Dictionary else null
	var routes: Variant = (grades as Dictionary).get(grade_key, null) if grades is Dictionary else null
	var record: Variant = (routes as Dictionary).get(route, null) if routes is Dictionary else null
	if not ROUTES.has(route) or record == null:
		return { "reason_key": UNKNOWN_RECIPE, "cost": {} }
	var found := _record_problems(inv_cfg, output_type, grade_key, route, record)
	if not (found["unknown"] as Array).is_empty():
		return { "reason_key": UNKNOWN_RECIPE, "cost": {} }
	if not (found["bad"] as Array).is_empty():
		return { "reason_key": BAD_COST, "cost": {} }
	return { "reason_key": OK, "cost": read_cost((record as Dictionary)["cost"]) }


## Every problem of the `recipes` block, as text. Empty means valid. A missing or empty block is valid.
static func validate(inv_cfg: Dictionary) -> Array:
	var out: Array = []
	var recipes: Variant = inv_cfg.get("recipes", {})
	if not (recipes is Dictionary):
		return ["recipes is not a Dictionary"]
	for output_type in (recipes as Dictionary).keys():
		var grades: Variant = recipes[output_type]
		if not (grades is Dictionary) or (grades as Dictionary).is_empty():
			out.append("%s: no grade key" % str(output_type))
			continue
		for grade_key in (grades as Dictionary).keys():
			var at := "%s.%s" % [str(output_type), str(grade_key)]
			var routes: Variant = grades[grade_key]
			if not (routes is Dictionary) or (routes as Dictionary).is_empty():
				out.append("%s: no make and no upgrade" % at)
				continue
			for route in (routes as Dictionary).keys():
				if not ROUTES.has(route):
					out.append("%s: unknown route %s" % [at, str(route)])
					continue
				var found := _record_problems(inv_cfg, str(output_type), str(grade_key), str(route), routes[route])
				for p in (found["unknown"] as Array) + (found["bad"] as Array):
					out.append("%s.%s: %s" % [at, str(route), str(p)])
	return out


## { ekwan: int, ase: int } from a `cost` value, or {} when it is not exactly those two keys with whole
## numbers of 0 or more. JSON gives every number as a float, so 10.0 reads as 10; 10.5 is refused.
static func read_cost(cost: Variant) -> Dictionary:
	if not (cost is Dictionary) or (cost as Dictionary).size() != 2:
		return {}
	var ekwan := _whole((cost as Dictionary).get("ekwan", null))
	var ase := _whole((cost as Dictionary).get("ase", null))
	if ekwan < 0 or ase < 0:
		return {}
	return { "ekwan": ekwan, "ase": ase }


## The afford check of one `cost` against two balances. Changes nothing. A side that costs 0 is never short.
static func afford(cost: Variant, ase_balance: int, ekwan_balance: int) -> String:
	var price := read_cost(cost)
	if price.is_empty():
		return BAD_COST
	var ase_short: bool = int(price["ase"]) > 0 and ase_balance < int(price["ase"])
	var ekwan_short: bool = int(price["ekwan"]) > 0 and ekwan_balance < int(price["ekwan"])
	if ase_short and ekwan_short:
		return SHORT_BOTH
	if ase_short:
		return SHORT_ASE
	return SHORT_EKWAN if ekwan_short else OK


# ---- internals ----

## The problems of one record, split by the reason key the lookup returns for them:
## { unknown: Array of String, bad: Array of String }.
static func _record_problems(inv_cfg: Dictionary, output_type: String, grade_key: String, route: String,
		record: Variant) -> Dictionary:
	var unknown: Array = []
	var bad: Array = []
	var output_def := InventoryService.def_of(inv_cfg, output_type)
	if output_def.is_empty():
		unknown.append("output type has no definition")
	elif output_def.get("kind", null) is String and output_def["kind"] == _RELIC:
		unknown.append("a relic cannot be made or upgraded")
	var ladder: Variant = inv_cfg.get("grades", null)
	if grade_key != UNGRADED and not (ladder is Array and (ladder as Array).has(grade_key)):
		unknown.append("grade key is not in grades")
	elif grade_key == UNGRADED and output_def.get("grade", "") != "":
		unknown.append("grade key ungraded on a type that has a grade")
	if not (record is Dictionary):
		bad.append("record is not a Dictionary")
		return { "unknown": unknown, "bad": bad }
	if read_cost((record as Dictionary).get("cost", null)).is_empty():
		bad.append("cost is not { ekwan, ase } in whole numbers of 0 or more")
	var inputs: Variant = (record as Dictionary).get("inputs", null)
	if not (inputs is Array):
		bad.append("inputs is not an Array")
		return { "unknown": unknown, "bad": bad }
	var seen: Array = []
	var has_base := false
	for input in (inputs as Array):
		var type_id: Variant = (input as Dictionary).get("type_id", null) if input is Dictionary else null
		if not (type_id is String) or _whole((input as Dictionary).get("count", null)) < 1:
			bad.append("an input is not { type_id: String, count: 1 or more }")
			continue
		if seen.has(type_id):
			bad.append("input type %s is listed twice" % type_id)
		seen.append(type_id)
		var def := InventoryService.def_of(inv_cfg, type_id)
		if def.is_empty():
			unknown.append("input type %s has no definition" % type_id)
		elif _BASE_KINDS.has(def.get("kind", null)):
			has_base = true
	if route == ROUTE_UPGRADE and not has_base:
		bad.append("an upgrade needs a gear or relic input")
	return { "unknown": unknown, "bad": bad }


## The value as an int when it is a whole number of 0 or more, else -1.
static func _whole(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return int(v) if int(v) >= 0 else -1
	# 2^53: above it a float no longer holds every whole number.
	if typeof(v) == TYPE_FLOAT and float(v) >= 0.0 and float(v) <= 9007199254740992.0 and float(v) == floorf(float(v)):
		return int(v)
	return -1
