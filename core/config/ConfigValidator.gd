class_name ConfigValidator
# Validates config dictionaries against expected schema versions and structures.

extends RefCounted

# Shared failure logger
static func _fail(logger: StructuredLogger, t: int, context: String, reason: String, data: Dictionary = {}) -> bool:
	if logger != null and t >= 0:
		var payload := {"context": context, "reason": reason}
		for k in data.keys():
			payload[k] = data[k]
		logger.debug(t, "config.validate.fail", "Config validation failed: " + reason, payload)
	return false

# Helpers logging mistakes
static func _require_key(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not dict.has(key):
		return _fail(logger, t, context, "Missing required key:" + key)
	return true

static func _require_int(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not _require_key(dict, key, context, logger, t):
		return false
	
	var v = dict[key]
	var vt := typeof(v)
	
	if vt == TYPE_INT:
		return true
		
	# Godot JSON sometimes parses numbers as float; accept 1.0 but reject 1.5
	if vt == TYPE_FLOAT:
		if float(v) == float(int(v)):
			return true
		return _fail(logger, t, context, "Key is float but not whole number: " + key, {"key": key, "value": v})
	
	return _fail(logger, t, context, "Key is not int: " + key, {"key": key, "type":vt}) 

static func _require_dict(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not _require_key(dict, key, context, logger, t):
		return false
	if typeof(dict[key]) != TYPE_DICTIONARY:
		return _fail(logger, t, context, "Key is not Dictionary: " + key, {"key": key, "type": typeof(dict[key])})
	return true
	
# Core validator
static func validate_root(root: Dictionary, expected_schema_version: int, context: String, logger: StructuredLogger = null, t: int = -1) -> bool:
	# root must have schema_version:int and data:Dictionary
	if not _require_int(root, "schema_version", context, logger, t):
		return false
	if int(root["schema_version"]) != expected_schema_version:
		return _fail(logger, t, context, "Unsupported schema_version", {
			"schema_version": int(root["schema_version"]),
			"expected": expected_schema_version
		})
	if not _require_dict(root, "data", context, logger, t):
		return false
	
	if logger != null and t >= 0:
		logger.debug(t, "config.validate", "Config validation OK", {
			"context": context,
			"schema_version": expected_schema_version
		})
	return true
	
# Thin wrappers per config
static func validate_balance(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "balance", logger, t)
	
static func validate_actors(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "actors", logger, t)

static func validate_realms(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "realms", logger, t)

# data.inventory finds keys (FindsRules). Returns one problem string per broken rule; [] = valid.
# Each problem is also logged through _fail under context "balance.inventory".
static func validate_finds(inv_cfg: Dictionary, logger: StructuredLogger = null, t: int = -1) -> Array:
	var out: Array = []
	var bands_v: Variant = inv_cfg.get("finds_cap_by_realm_scale", null)
	var max_cap := 0
	if not (bands_v is Array) or (bands_v as Array).is_empty():
		out.append("finds_cap_by_realm_scale is missing or empty")
	else:
		var prev_scale := -INF
		var prev_cap := 0
		for band in bands_v:
			if not (band is Dictionary) or not _is_num(band.get("scale")) or not _is_whole(band.get("cap")):
				out.append("finds_cap_by_realm_scale: a band is not { scale: number, cap: whole number }")
				continue
			var scale := float(band["scale"])
			var cap := int(band["cap"])
			if scale <= prev_scale:
				out.append("finds_cap_by_realm_scale: scales are not ascending at %s" % str(scale))
			if cap < 1 or cap < prev_cap:
				out.append("finds_cap_by_realm_scale: cap %d at scale %s is below 1 or below the band before" % [cap, str(scale)])
			prev_scale = scale
			prev_cap = cap
			max_cap = maxi(max_cap, cap)
	var chance_v: Variant = inv_cfg.get("finds_chance", null)
	if not (chance_v is Dictionary):
		out.append("finds_chance is missing or not a Dictionary")
	else:
		var chance: Dictionary = chance_v
		var base_v: Variant = chance.get("base_by_slot_pct", null)
		var base: Array = base_v if base_v is Array else []
		if base.size() < maxi(max_cap, 1):
			out.append("finds_chance.base_by_slot_pct has %d slots; the largest cap needs %d" % [base.size(), max_cap])
		var prev_base := 101
		for v in base:
			if not _is_whole(v) or int(v) < 0 or int(v) > 100 or int(v) > prev_base:
				out.append("finds_chance.base_by_slot_pct: %s is not a whole 0..100 at or below the slot before" % str(v))
				break
			prev_base = int(v)
		var mods_v: Variant = chance.get("rank_modifier_pct", null)
		var mods: Dictionary = mods_v if mods_v is Dictionary else {}
		if mods.is_empty():
			out.append("finds_chance.rank_modifier_pct is missing or empty")
		for rank in mods.keys():
			if not _is_whole(mods[rank]) or absi(int(mods[rank])) > 100:
				out.append("finds_chance.rank_modifier_pct.%s is not a whole -100..100" % str(rank))
		var max_v: Variant = chance.get("max_pct", null)
		if not _is_whole(max_v) or int(max_v) < 1 or int(max_v) > 100:
			out.append("finds_chance.max_pct is not a whole 1..100")
		var floor_v: Variant = chance.get("first_find_floor_pct", null)
		var floor_rank := str(chance.get("first_find_floor_rank", ""))
		if not _is_whole(floor_v) or not mods.has(floor_rank) or not _is_whole(mods[floor_rank]) \
				or base.is_empty() or not _is_whole(base[0]) or not _is_whole(max_v):
			out.append("finds_chance: first_find_floor_pct or first_find_floor_rank is missing or unusable")
		elif clampi(int(base[0]) + int(mods[floor_rank]), 0, int(max_v)) < int(floor_v):
			out.append("finds_chance: first find at rank %s is %d%%, below the floor %d%%" % [
				floor_rank, clampi(int(base[0]) + int(mods[floor_rank]), 0, int(max_v)), int(floor_v)])
	for p in out:
		_fail(logger, t, "balance.inventory", p)
	return out

# data.inventory.pick (PickupPick) and each calling's afraid_pick_signature. One problem string per broken rule;
# [] = valid. `calling_behavior` is data.maturity_expression.calling_behavior ({} skips the signature check).
# Test-only caller, like validate_finds; the game does not run it at load.
static func validate_pick(pick: Dictionary, calling_behavior: Dictionary = {}, logger: StructuredLogger = null, t: int = -1) -> Array:
	var out: Array = []
	var limit_v: Variant = pick.get("state_abs_limit", null)
	var limit := INF
	if _is_finite_num(limit_v) and float(limit_v) > 0.0:
		limit = float(limit_v)
	else:
		out.append("pick.state_abs_limit is not a finite number above 0")
	var tables := {
		"calling_pick": PickupPick.CALLINGS, "archetype_pick": PickupPick.ARCHETYPES,
		"vector_pick_muls": PickupPick.VECTORS, "trait_pick_muls": PickupPick.TRAITS, "stat_pick_muls": PickupPick.STATS,
	}
	for key: String in tables:
		var table_v: Variant = pick.get(key, null)
		if not (table_v is Dictionary):
			out.append("pick.%s is missing or not a Dictionary" % key)
			continue
		var table: Dictionary = table_v
		var want: Array = tables[key]
		for row_id: String in want:
			if not table.has(row_id):
				out.append("pick.%s has no row %s" % [key, row_id])
		for row_id in table.keys():
			if not want.has(str(row_id)):
				out.append("pick.%s has an unknown row %s" % [key, str(row_id)])
			else:
				_check_kind_row(out, "pick.%s.%s" % [key, str(row_id)], table[row_id], true, INF)
	for key in ["afraid_pick", "bold_pick"]:
		_check_kind_row(out, "pick.%s" % key, pick.get(key, null), true, limit)
	_check_kind_row(out, "pick.kind_weight", pick.get("kind_weight", null), false, INF)
	if pick.get("kind_weight", null) is Dictionary:
		for kind in (pick["kind_weight"] as Dictionary).keys():
			if _is_finite_num(pick["kind_weight"][kind]) and float(pick["kind_weight"][kind]) <= 0.0:
				out.append("pick.kind_weight.%s is not above 0" % str(kind))
	for key in ["worth_weight", "grade_step", "quantity_gain", "sense_base", "freeze_at"]:
		var v: Variant = pick.get(key, null)
		var ok := _is_finite_num(v)
		if ok:
			var f := float(v)
			ok = (f > 0.0 if key == "worth_weight" else f >= 0.0) and (f <= 1.0 if key == "sense_base" else true) \
				and (f > 0.0 and f <= 1.0 if key == "freeze_at" else true)
		if not ok:
			out.append("pick.%s is missing or out of range (worth_weight > 0, grade_step and quantity_gain >= 0, sense_base 0..1, freeze_at above 0 up to 1)" % key)
	if not _is_whole(pick.get("quantity_cap", null)) or int(pick["quantity_cap"]) < 1:
		out.append("pick.quantity_cap is not a whole number of 1 or more")
	for calling in calling_behavior.keys():
		var entry: Variant = calling_behavior[calling]
		if entry is Dictionary and (entry as Dictionary).has("afraid_pick_signature"):
			_check_kind_row(out, "calling_behavior.%s.afraid_pick_signature" % str(calling),
				entry["afraid_pick_signature"], false, limit, true)
	for p in out:
		_fail(logger, t, "balance.inventory.pick", p)
	return out

# `row` must be a Dictionary of finite numbers with only the four kinds. It must name all four unless `subset`
# (a signature may name any subset). `zero_sum`: the values sum to 0. `limit`: no value is larger in size.
static func _check_kind_row(out: Array, where: String, row: Variant, zero_sum: bool, limit: float, subset: bool = false) -> void:
	if not (row is Dictionary):
		out.append("%s is missing or not a Dictionary" % where)
		return
	var sum := 0.0
	for kind in PickupPick.KINDS:
		if not (row as Dictionary).has(kind) and not subset:
			out.append("%s has no value for %s" % [where, kind])
	for kind in (row as Dictionary).keys():
		var v: Variant = row[kind]
		if not PickupPick.KINDS.has(str(kind)):
			out.append("%s has an unknown kind %s" % [where, str(kind)])
		elif not _is_finite_num(v):
			out.append("%s.%s is not a finite number" % [where, str(kind)])
		else:
			sum += float(v)
			if absf(float(v)) > limit:
				out.append("%s.%s is over the limit %s" % [where, str(kind), str(limit)])
	if zero_sum and absf(sum) > 0.000001:
		out.append("%s does not sum to 0 (sum %s)" % [where, str(sum)])

static func _is_finite_num(v: Variant) -> bool:
	return _is_num(v) and is_finite(float(v))

static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

# JSON gives every number as a float: 60.0 is whole, 60.5 is not.
static func _is_whole(v: Variant) -> bool:
	return _is_num(v) and float(v) == float(int(v))
