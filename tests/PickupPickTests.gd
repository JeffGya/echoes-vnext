# res://tests/PickupPickTests.gd
# PickupPick (the pick rule of the pickup event) and ConfigValidator.validate_pick.
# Tests use a small _pick() config (rows copied from D-12, fixed here) so the hand arithmetic stays short.
# Only the shipping-config tests read data/balance.json.

class_name PickupPickTests
extends RefCounted

const EPS := 0.000001


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_pick/shipping_config_validates", Callable(PickupPickTests, "_t_shipping"))
	runner.register_test("pickup_pick/worked_characters_by_hand", Callable(PickupPickTests, "_t_worked"))
	runner.register_test("pickup_pick/each_table_moves_the_result", Callable(PickupPickTests, "_t_tables"))
	runner.register_test("pickup_pick/judgment_scales_vector_and_trait_only", Callable(PickupPickTests, "_t_judgment_scale"))
	runner.register_test("pickup_pick/worth_grade_and_quantity_cap", Callable(PickupPickTests, "_t_worth"))
	runner.register_test("pickup_pick/frozen_boundary_curved_and_softened", Callable(PickupPickTests, "_t_frozen"))
	runner.register_test("pickup_pick/order_and_tie_rule", Callable(PickupPickTests, "_t_order"))
	runner.register_test("pickup_pick/signature_applies", Callable(PickupPickTests, "_t_signature"))
	runner.register_test("pickup_pick/invalid_exponent_adds_nothing", Callable(PickupPickTests, "_t_exponent"))
	runner.register_test("pickup_pick/reason_class", Callable(PickupPickTests, "_t_reason"))
	runner.register_test("pickup_pick/validator_rejects_each_bad_shape", Callable(PickupPickTests, "_t_validator_bad"))
	runner.register_test("pickup_pick/two_rows_per_table_add_up", Callable(PickupPickTests, "_t_two_rows"))
	runner.register_test("pickup_pick/calling_read_confirmed_else_origin", Callable(PickupPickTests, "_t_calling_read"))
	runner.register_test("pickup_pick/tie_epsilon_and_string_order", Callable(PickupPickTests, "_t_tie_eps"))
	runner.register_test("pickup_pick/judgment_is_clamped", Callable(PickupPickTests, "_t_judgment_clamp"))
	runner.register_test("pickup_pick/reason_tie_order", Callable(PickupPickTests, "_t_reason_tie"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _pick() -> Dictionary:
	return {
		"calling_pick": {
			"okofor": { "gear": 6, "relic": -2, "consumable": 4, "material": -8 },
			"aduro": { "gear": 8, "relic": -4, "consumable": -2, "material": -2 },
		},
		"archetype_pick": { "valiant": { "gear": 6, "relic": -2, "consumable": -2, "material": -2 } },
		"vector_pick_muls": {
			"vanguard": { "gear": 0.09, "relic": -0.03, "consumable": 0, "material": -0.06 },
			"protector": { "gear": 0.09, "relic": -0.03, "consumable": 0.03, "material": -0.09 },
		},
		"trait_pick_muls": {
			"courage": { "gear": 0.2, "relic": -0.2, "consumable": 0, "material": 0 },
			"wisdom": { "gear": -0.1, "relic": 0.1, "consumable": -0.1, "material": 0.1 },
		},
		"stat_pick_muls": {
			"def": { "gear": 0.15, "relic": 0, "consumable": 0, "material": -0.15 },
			"atk": { "gear": 0.07, "relic": -0.07, "consumable": 0, "material": 0 },
		},
		"afraid_pick": { "gear": 4, "relic": -8, "consumable": 16, "material": -12 },
		"bold_pick": { "gear": 6, "relic": 10, "consumable": -8, "material": -8 },
		"state_abs_limit": 30,
		"kind_weight": { "gear": 3, "relic": 4, "consumable": 2, "material": 1 },
		"grade_step": 1.5, "quantity_gain": 0.5, "quantity_cap": 3, "worth_weight": 6, "sense_base": 0.3,
		"freeze_at": 0.5,
	}


static func _actor() -> Dictionary:
	return {
		"calling": "okofor", "calling_origin": "okofor", "archetype_birth": "valiant",
		"vector_scores": { "vanguard": 60, "protector": 0 }, "traits": { "courage": 50, "wisdom": 0 }, "stats": { "def": 20, "atk": 0 },
		"morale": 50, "fear": 0, "fear_base": 0, "faction": "echo", "kind": "echo",
	}


## ctx with a band_lean table that gives the actor's own status the lean `lean`.
static func _ctx(actor: Dictionary, lean: float, exponent: Variant = 1.0) -> Dictionary:
	return {
		"pick": _pick(), "grades": ["common", "fine"],
		"table": { EmotionStatusLean.status_of(actor): lean },
		"exponent": exponent, "dampen": 0.4, "id_scale": { "trait": 0.35, "vector": 0.35 },
		"calling_behavior": {
			"okofor": { "afraid_pick_signature": { "consumable": 8.0, "gear": 4.0 } },
			"aduro": { "afraid_pick_signature": { "gear": 6.0, "consumable": -4.0 } },
		},
	}


static func _chooser(actor: Dictionary, judgment: float, composure: float = 0.0) -> Dictionary:
	return { "actor": actor, "judgment": judgment, "composure": composure }


static func _gear() -> Dictionary:
	return { "find_id": "f1", "kind": "gear", "grade": "", "quantity": 1 }


static func _cons() -> Dictionary:
	return { "find_id": "f2", "kind": "consumable", "grade": "fine", "quantity": 2 }


static func _mat() -> Dictionary:
	return { "find_id": "f3", "kind": "material", "grade": "", "quantity": 1 }


static func _total(chooser: Dictionary, find: Dictionary, ctx: Dictionary) -> float:
	return float(PickupPick.appeal(chooser, find, ctx)["total"])


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _shipping_data() -> Dictionary:
	return (InventorySaveTests._config().get_balance() as Dictionary).get("data", {}) as Dictionary


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_shipping() -> Dictionary:
	var m: Array = []
	var data := _shipping_data()
	var pick: Dictionary = (data["inventory"] as Dictionary).get("pick", {})
	var problems := ConfigValidator.validate_pick(pick, (data["maturity_expression"] as Dictionary)["calling_behavior"])
	if not problems.is_empty():
		m.append("the shipping config fails: %s" % str(problems))
	var ctx := PickupPick.ctx_from(data)
	if not BehaviorArbiter.is_valid_afraid_curve_exponent(ctx["exponent"]) or (ctx["table"] as Dictionary).is_empty():
		m.append("ctx_from did not read the exponent or the band_lean table")
	var scale := ctx["id_scale"] as Dictionary
	if not _near(float(scale.get("vector", -1)), 0.35) or not _near(float(scale.get("trait", -1)), 0.35):
		m.append("ctx id_scale is not 0.35 / 0.35: %s" % str(scale))
	if not _near(float(ctx["dampen"]), 0.4):
		m.append("ctx dampen is %s, expected 0.4" % str(ctx["dampen"]))
	if not (ctx["grades"] is Array):
		m.append("ctx grades is not an Array")
	var sig: Variant = ((ctx["calling_behavior"] as Dictionary).get("okofor", {}) as Dictionary).get("afraid_pick_signature", null)
	if not (sig is Dictionary) or not _near(float((sig as Dictionary).get("consumable", 0.0)), 8.0):
		m.append("ctx calling_behavior has no okofor afraid_pick_signature (consumable 8): %s" % str(sig))
	# An afraid okofor chooser on the shipping ctx (band_lean forced to -0.3 for its own status) gets signature points.
	var afraid_ctx := ctx.duplicate()
	afraid_ctx["table"] = { EmotionStatusLean.status_of(_actor()): -0.3 }
	var sp := PickupPick.appeal(_chooser(_actor(), 0.5), _cons(), afraid_ctx)["parts"] as Dictionary
	if float(sp["signature"]) <= 0.0:
		m.append("an afraid okofor chooser got no signature points on the shipping ctx: %s" % str(sp))
	var a := PickupPick.appeal(_chooser(_actor(), 0.5), _gear(), ctx)
	if not is_finite(float(a["total"])) or float(a["identity"]) == 0.0:
		m.append("a shipping appeal is not finite or has no identity: %s" % str(a))
	if int(pick["calling_pick"].size()) != 6 or int(pick["archetype_pick"].size()) != 9 \
			or int(pick["vector_pick_muls"].size()) != 10 or int(pick["stat_pick_muls"].size()) != 6:
		m.append("a shipping table has the wrong row count")
	return _result(m)


## Four worked characters, two finds each. Hand arithmetic (D-12 rule), actor = okofor, valiant, vanguard 60,
## courage 50, def 20, composure 0:
##   gear find (ungraded, qty 1): worth 3.   consumable find (grade fine = index 1, qty 2): worth 2 + 1.5 + 0.5 = 4.
##   A  J 0.2 calm: vector scale 1.07, sense factor 0.3 + 0.7 x 0.2 = 0.44.
##     gear identity = 6 + 6 + 5.4 x 1.07 (5.778) + 10 x 1.07 (10.7) + 3 = 31.478; sense 3 x 6 x 0.44 = 7.92; total 39.398
##     cons identity = 4 - 2 = 2; sense 4 x 6 x 0.44 = 10.56; total 12.56
##   B  J 0.8 calm: scale 1.28, factor 0.3 + 0.56 = 0.86.
##     gear identity = 6 + 6 + 6.912 + 12.8 + 3 = 34.712; sense 18 x 0.86 = 15.48; total 50.192
##     cons identity 2; sense 24 x 0.86 = 20.64; total 22.64
##   C  J 0.2, afraid 0.3 (lean -0.3, exponent 1, composure 0):
##     gear state = 0.3 x 4 + 0.3 x 4 (signature) = 2.4; total 31.478 + 7.92 + 2.4 = 41.798
##     cons state = 0.3 x 16 + 0.3 x 8 = 7.2; total 2 + 10.56 + 7.2 = 19.76
##   D  J 0.8, bold 0.8 (lean +0.8): gear state 0.8 x 6 = 4.8; total 34.712 + 15.48 + 4.8 = 54.992
##     cons state 0.8 x -8 = -6.4; total 2 + 20.64 - 6.4 = 16.24
static func _t_worked() -> Dictionary:
	var m: Array = []
	var calm := _actor()
	var cases := [
		["A gear", 0.2, 0.0, _gear(), 39.398], ["A cons", 0.2, 0.0, _cons(), 12.56],
		["B gear", 0.8, 0.0, _gear(), 50.192], ["B cons", 0.8, 0.0, _cons(), 22.64],
		["C gear", 0.2, -0.3, _gear(), 41.798], ["C cons", 0.2, -0.3, _cons(), 19.76],
		["D gear", 0.8, 0.8, _gear(), 54.992], ["D cons", 0.8, 0.8, _cons(), 16.24],
	]
	for c in cases:
		var got := _total(_chooser(calm, float(c[1])), c[3], _ctx(calm, float(c[2])))
		if not _near(got, float(c[4])):
			m.append("%s: %s, expected %s" % [c[0], str(got), str(c[4])])
	var a := PickupPick.appeal(_chooser(calm, 0.2), _gear(), _ctx(calm, 0.0))
	if not _near(float(a["identity"]), 31.478) or not _near(float(a["sense"]), 7.92) or not _near(float(a["state"]), 0.0):
		m.append("A gear parts: %s" % str(a))
	return _result(m)


## Each source moves the gear total by exactly its own term when only that source changes.
static func _t_tables() -> Dictionary:
	var m: Array = []
	var base := _actor()
	var ctx := _ctx(base, 0.0)
	var ch := _chooser(base, 0.0)  # Judgment 0: the vector and trait scale is 1.0, so each delta is the raw term.
	var base_total := _total(ch, _gear(), ctx)
	var variants := [
		["calling aduro (+2 gear over okofor)", { "calling": "aduro", "calling_origin": "aduro" }, 2.0],
		["archetype none (-6)", { "archetype_birth": "none" }, -6.0],
		["vector 0 (-5.4)", { "vector_scores": { "vanguard": 0 } }, -5.4],
		["trait 0 (-10)", { "traits": { "courage": 0 } }, -10.0],
		["stat 0 (-3)", { "stats": { "def": 0 } }, -3.0],
	]
	for v in variants:
		var actor := base.duplicate(true)
		for k in (v[1] as Dictionary):
			actor[k] = v[1][k]
		var delta := _total(_chooser(actor, 0.0), _gear(), _ctx(actor, 0.0)) - base_total
		if not _near(delta, float(v[2])):
			m.append("%s: moved %s" % [v[0], str(delta)])
	# A confirmed "uncalled" falls back to calling_origin, as combat reads it.
	var fallback := base.duplicate(true)
	fallback["calling"] = "uncalled"
	if not _near(_total(_chooser(fallback, 0.0), _gear(), ctx), base_total):
		m.append("calling 'uncalled' did not fall back to calling_origin")
	return _result(m)


static func _t_judgment_scale() -> Dictionary:
	var m: Array = []
	var actor := _actor()
	var lo := PickupPick.appeal(_chooser(actor, 0.0), _gear(), _ctx(actor, 0.0))["parts"] as Dictionary
	var hi := PickupPick.appeal(_chooser(actor, 1.0), _gear(), _ctx(actor, 0.0))["parts"] as Dictionary
	# J 0 -> 1.0x, J 1 -> 1.35x on the vector sum (5.4) and trait sum (10) only.
	if not _near(float(lo["vector"]), 5.4) or not _near(float(hi["vector"]), 5.4 * 1.35):
		m.append("vector part: %s then %s" % [str(lo["vector"]), str(hi["vector"])])
	if not _near(float(lo["trait"]), 10.0) or not _near(float(hi["trait"]), 10.0 * 1.35):
		m.append("trait part: %s then %s" % [str(lo["trait"]), str(hi["trait"])])
	for key in ["calling", "archetype", "stat"]:
		if not _near(float(lo[key]), float(hi[key])):
			m.append("%s part moved with Judgment: %s then %s" % [key, str(lo[key]), str(hi[key])])
	return _result(m)


static func _t_worth() -> Dictionary:
	var m: Array = []
	var ctx := _ctx(_actor(), 0.0)
	var cases := [
		[{ "kind": "gear", "grade": "", "quantity": 1 }, 3.0],
		[{ "kind": "gear", "grade": "fine", "quantity": 1 }, 4.5],
		[{ "kind": "gear", "grade": "not_in_list", "quantity": 1 }, 3.0],
		[{ "kind": "consumable", "grade": "", "quantity": 3 }, 3.0],
		[{ "kind": "consumable", "grade": "", "quantity": 9 }, 3.0],
		[{ "kind": "consumable", "grade": "", "quantity": 0 }, 2.0],
	]
	for c in cases:
		var got := PickupPick.worth_of(c[0], ctx)
		if not _near(got, float(c[1])):
			m.append("%s: worth %s, expected %s" % [str(c[0]), str(got), str(c[1])])
	return _result(m)


## The chooser takes nothing at afraid >= freeze_at, where afraid is curved and then softened by composure.
static func _t_frozen() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var finds := [_gear(), _cons()]
	# At the boundary: afraid exactly 0.5 freezes; a hair under does not.
	var at := _ctx(a, -0.5)
	if not PickupPick.frozen(_chooser(a, 0.5), at) or not PickupPick.order(_chooser(a, 0.5), finds, at).is_empty():
		m.append("afraid 0.5 at freeze_at 0.5 did not freeze or still took finds")
	var under := _ctx(a, -0.4999)
	if PickupPick.frozen(_chooser(a, 0.5), under) or PickupPick.order(_chooser(a, 0.5), finds, under).size() != 2:
		m.append("afraid 0.4999 froze or took the wrong number of finds")
	# Curved: raw 0.6 squared is 0.36, so it does not freeze at 0.5.
	if PickupPick.frozen(_chooser(a, 0.5), _ctx(a, -0.6, 2.0)):
		m.append("the exponent was not applied to the freeze check")
	# Softened: 0.6 x (1 - 0.4 x 1.0) = 0.36 at full composure; at composure 0 it freezes.
	if PickupPick.frozen(_chooser(a, 0.5, 1.0), _ctx(a, -0.6)):
		m.append("composure did not soften the freeze check")
	if not PickupPick.frozen(_chooser(a, 0.5, 0.0), _ctx(a, -0.6)):
		m.append("afraid 0.6 with no composure did not freeze")
	# Bold never freezes.
	if PickupPick.frozen(_chooser(a, 0.5), _ctx(a, 1.0)):
		m.append("a bold chooser froze")
	return _result(m)


static func _t_order() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var ctx := _ctx(a, 0.0)
	var ch := _chooser(a, 0.2)
	# Totals at J 0.2 (worked case A): gear 39.398, cons 12.56, material -14.212
	# (identity -8 - 2 - 3.852 - 3 = -16.852, sense 6 x 0.44 = 2.64).
	var ids := func(list: Array) -> Array:
		return list.map(func(f: Dictionary) -> String: return str(f["find_id"]))
	var got: Array = ids.call(PickupPick.order(ch, [_mat(), _cons(), _gear()], ctx))
	if got != ["f1", "f2", "f3"]:
		m.append("order by total: %s" % str(got))
	# Tie: two identical finds go to the lower find_id, whatever the input order.
	var x := { "find_id": "b", "kind": "gear", "grade": "", "quantity": 1 }
	var y := { "find_id": "a", "kind": "gear", "grade": "", "quantity": 1 }
	for input in [[x, y], [y, x]]:
		got = ids.call(PickupPick.order(ch, input, ctx))
		if got != ["a", "b"]:
			m.append("tie order for input %s: %s" % [str(ids.call(input)), str(got)])
	if not PickupPick.order(ch, [], ctx).is_empty():
		m.append("no finds gave a non-empty order")
	return _result(m)


static func _t_signature() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var ctx := _ctx(a, -0.3)
	var with_sig := PickupPick.appeal(_chooser(a, 0.2), _cons(), ctx)["parts"] as Dictionary
	if not _near(float(with_sig["signature"]), 2.4) or not _near(float(with_sig["afraid"]), 4.8):
		m.append("signature parts: %s" % str(with_sig))
	ctx["calling_behavior"] = {}
	if not _near(float(PickupPick.appeal(_chooser(a, 0.2), _cons(), ctx)["parts"]["signature"]), 0.0):
		m.append("a calling with no signature still got points")
	# A calm chooser gets no signature points (they scale with afraid).
	if not _near(float(PickupPick.appeal(_chooser(a, 0.2), _cons(), _ctx(a, 0.0))["parts"]["signature"]), 0.0):
		m.append("a calm chooser got signature points")
	return _result(m)


## An exponent outside 1..4, NaN, a string or a missing key makes both ends 0 (as BehaviorArbiter does),
## so the status adds nothing and the chooser never freezes.
static func _t_exponent() -> Dictionary:
	var m: Array = []
	var a := _actor()
	for bad in [0.5, 4.5, NAN, "2", null]:
		var ctx := _ctx(a, -0.9, bad)
		var ends := PickupPick.state_ends(_chooser(a, 0.5), ctx)
		if float(ends[0]) != 0.0 or float(ends[1]) != 0.0 or PickupPick.frozen(_chooser(a, 0.5), ctx):
			m.append("exponent %s: ends %s or frozen" % [str(bad), str(ends)])
		if not _near(float(PickupPick.appeal(_chooser(a, 0.5), _gear(), ctx)["state"]), 0.0):
			m.append("exponent %s: state points not 0" % str(bad))
	for good in [1.0, 2.5, 4.0]:
		if float(PickupPick.state_ends(_chooser(a, 0.5), _ctx(a, -0.5, good))[0]) <= 0.0:
			m.append("exponent %s was refused" % str(good))
	return _result(m)


static func _t_reason() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var cases := [
		["identity (gear, J 0.2, calm)", _chooser(a, 0.2), _gear(), _ctx(a, 0.0), "identity"],
		["sense (consumable, J 0.8, calm)", _chooser(a, 0.8), _cons(), _ctx(a, 0.0), "sense"],
		["state (consumable, J 0.2, afraid 0.45: 10.8 over sense 10.56)", _chooser(a, 0.2), _cons(), _ctx(a, -0.45), "state"],
		["froze", _chooser(a, 0.2), _gear(), _ctx(a, -0.5), "froze"],
	]
	for c in cases:
		var got := PickupPick.reason(c[1], c[2], c[3])
		if got != c[4]:
			m.append("%s: %s" % [c[0], got])
	return _result(m)


static func _t_validator_bad() -> Dictionary:
	var m: Array = []
	var ok := ConfigValidator.validate_pick(_full_pick())
	if not ok.is_empty():
		m.append("the full test config fails: %s" % str(ok))
	var cases: Array = []
	var c := _full_pick()
	(c["calling_pick"] as Dictionary).erase("okofor")
	cases.append(["missing calling row", c, "has no row okofor", 1])
	c = _full_pick()
	c["archetype_pick"]["wizard"] = { "gear": 0, "relic": 0, "consumable": 0, "material": 0 }
	cases.append(["extra archetype row", c, "unknown row wizard", 1])
	c = _full_pick()
	(c["vector_pick_muls"]["seeker"] as Dictionary).erase("relic")
	cases.append(["a kind missing", c, "has no value for relic", 1])
	c = _full_pick()
	c["trait_pick_muls"]["courage"]["gold"] = 0.0
	cases.append(["an extra kind", c, "unknown kind gold", 1])
	c = _full_pick()
	c["stat_pick_muls"]["int"]["gear"] = NAN
	cases.append(["NaN value", c, "not a finite number", 1])
	c = _full_pick()
	c["calling_pick"]["aduro"]["gear"] = 9
	cases.append(["row sum not 0", c, "does not sum to 0", 1])
	c = _full_pick()
	c["afraid_pick"] = { "gear": 31, "relic": -8, "consumable": -11, "material": -12 }
	cases.append(["state value over the limit", c, "over the limit", 1])
	c = _full_pick()
	c["state_abs_limit"] = 0
	cases.append(["limit not above 0", c, "state_abs_limit", 1])
	for v in [0.0, 1.5, -0.1]:
		c = _full_pick()
		c["freeze_at"] = v
		cases.append(["freeze_at %s" % str(v), c, "pick.freeze_at", 1])
	c = _full_pick()
	c["worth_weight"] = 0
	cases.append(["worth_weight 0", c, "pick.worth_weight", 1])
	c = _full_pick()
	c["quantity_cap"] = 2.5
	cases.append(["quantity_cap not whole", c, "quantity_cap", 1])
	c = _full_pick()
	c["kind_weight"]["gear"] = 0
	cases.append(["kind_weight 0", c, "kind_weight.gear", 1])
	c = _full_pick()
	c["sense_base"] = 1.5
	cases.append(["sense_base above 1", c, "sense_base", 1])
	c = _full_pick()
	c.erase("bold_pick")
	cases.append(["bold_pick missing", c, "pick.bold_pick is missing", 1])
	c = _full_pick()
	c["afraid_pick"] = { "gear": 5, "relic": -8, "consumable": 16, "material": -12 }
	cases.append(["afraid_pick row sums to 1 (inside the limit)", c, "pick.afraid_pick does not sum to 0", 1])
	c = _full_pick()
	c["bold_pick"] = { "gear": 6, "relic": 10, "consumable": -8, "material": -7 }
	cases.append(["bold_pick row sums to 1 (inside the limit)", c, "pick.bold_pick does not sum to 0", 1])
	for key in ["grade_step", "quantity_gain", "sense_base"]:
		c = _full_pick()
		c[key] = -0.1
		cases.append(["%s negative" % key, c, "pick.%s" % key, 1])
	c = _full_pick()
	c["quantity_cap"] = 0
	cases.append(["quantity_cap 0", c, "quantity_cap", 1])
	for bad in cases:
		var problems := ConfigValidator.validate_pick(bad[1])
		if problems.size() != int(bad[3]) or str(problems[0]).find(bad[2]) < 0:
			m.append("%s: %s" % [bad[0], str(problems)])
	# Signatures: a subset of kinds is fine, an unknown kind, NaN or a value over the limit is not.
	var cb := { "okofor": { "afraid_pick_signature": { "gear": 4.0 } }, "uncalled": { "retreat_threshold": 0.3 } }
	if not ConfigValidator.validate_pick(_full_pick(), cb).is_empty():
		m.append("a one-kind signature was refused")
	for sig in [{ "gold": 1.0 }, { "gear": NAN }, { "gear": 31.0 }, "x"]:
		cb["okofor"]["afraid_pick_signature"] = sig
		if ConfigValidator.validate_pick(_full_pick(), cb).size() != 1:
			m.append("bad signature %s: %s" % [str(sig), str(ConfigValidator.validate_pick(_full_pick(), cb))])
	return _result(m)


## A pick config with a row for every calling, archetype, vector, trait and stat (all zero-sum).
static func _full_pick() -> Dictionary:
	var pick := _pick()
	var zero := { "gear": 0, "relic": 0, "consumable": 0, "material": 0 }
	var tables := {
		"calling_pick": PickupPick.CALLINGS, "archetype_pick": PickupPick.ARCHETYPES,
		"vector_pick_muls": PickupPick.VECTORS, "trait_pick_muls": PickupPick.TRAITS, "stat_pick_muls": PickupPick.STATS,
	}
	for key: String in tables:
		for id: String in tables[key]:
			if not (pick[key] as Dictionary).has(id):
				pick[key][id] = zero.duplicate()
	return pick


## Two rows per table must add (`+=`): hand total, actor with vanguard 60, protector 30, courage 50, wisdom 10,
## def 20, atk 10, Judgment 0, gear find, calm. vector 60 x 0.09 + 30 x 0.09 = 8.1; trait 50 x 0.2 + 10 x -0.1 = 9;
## stat 20 x 0.15 + 10 x 0.07 = 3.7; calling 6; archetype 6; sense 3 x 6 x 0.3 = 5.4. Total 6 + 6 + 8.1 + 9 + 3.7 + 5.4 = 38.2.
static func _t_two_rows() -> Dictionary:
	var m: Array = []
	var a := _actor()
	a["vector_scores"] = { "vanguard": 60, "protector": 30 }
	a["traits"] = { "courage": 50, "wisdom": 10 }
	a["stats"] = { "def": 20, "atk": 10 }
	var r := PickupPick.appeal(_chooser(a, 0.0), _gear(), _ctx(a, 0.0))
	var parts := r["parts"] as Dictionary
	for c in [["vector", 8.1], ["trait", 9.0], ["stat", 3.7], ["total", 38.2]]:
		var got := float(parts[c[0]]) if c[0] != "total" else float(r["total"])
		if not _near(got, float(c[1])):
			m.append("%s: %s, expected %s" % [c[0], str(got), str(c[1])])
	return _result(m)


## The calling cell comes from `calling` when it is a real id, else from `calling_origin` (as combat reads it).
## okofor gear 6, aduro gear 8.
static func _t_calling_read() -> Dictionary:
	var m: Array = []
	var cases := [["uncalled", "okofor", 6.0], ["", "okofor", 6.0], ["aduro", "okofor", 8.0], ["okofor", "aduro", 6.0]]
	for c in cases:
		var a := _actor()
		a["calling"] = c[0]
		a["calling_origin"] = c[1]
		var got := float(PickupPick.appeal(_chooser(a, 0.0), _gear(), _ctx(a, 0.0))["parts"]["calling"])
		if not _near(got, float(c[2])):
			m.append("calling '%s' origin '%s': cell %s, expected %s" % [c[0], c[1], str(got), str(c[2])])
	return _result(m)


## Totals closer than TIE_EPS are a tie (lower find_id first); farther apart they order by value.
## At Judgment 0 sense = worth x 6 x 0.3 = 1.8 x worth, so a quantity_gain of d / 1.8 moves the total by d.
## Base total 35.8 (6 + 6 + 5.4 + 10 + 3 + 5.4). Also pins the documented String order: "f10" before "f2".
static func _t_tie_eps() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var ch := _chooser(a, 0.0)
	var ids := func(list: Array) -> Array:
		return list.map(func(f: Dictionary) -> String: return str(f["find_id"]))
	var low := { "find_id": "a", "kind": "gear", "grade": "", "quantity": 1 }
	var high := { "find_id": "b", "kind": "gear", "grade": "", "quantity": 2 }
	var ctx := _ctx(a, 0.0)
	var pk := ctx["pick"] as Dictionary
	pk["quantity_gain"] = 1e-7 / 1.8
	var got: Array = ids.call(PickupPick.order(ch, [high, low], ctx))
	if got != ["a", "b"]:
		m.append("a 1e-7 gap is a tie, expected a then b: %s" % str(got))
	pk["quantity_gain"] = 1e-5 / 1.8
	got = ids.call(PickupPick.order(ch, [low, high], ctx))
	if got != ["b", "a"]:
		m.append("a 1e-5 gap orders by value, expected b then a: %s" % str(got))
	var f10 := { "find_id": "f10", "kind": "gear", "grade": "", "quantity": 1 }
	var f2 := { "find_id": "f2", "kind": "gear", "grade": "", "quantity": 1 }
	got = ids.call(PickupPick.order(ch, [f2, f10], _ctx(a, 0.0)))
	if got != ["f10", "f2"]:
		m.append("String order on equal totals, expected f10 then f2: %s" % str(got))
	return _result(m)


static func _t_judgment_clamp() -> Dictionary:
	var m: Array = []
	var a := _actor()
	var ctx := _ctx(a, 0.0)
	for pair in [[-0.5, 0.0], [1.5, 1.0]]:
		for find in [_gear(), _cons()]:
			var outside := PickupPick.appeal(_chooser(a, float(pair[0])), find, ctx)
			var inside := PickupPick.appeal(_chooser(a, float(pair[1])), find, ctx)
			if not _near(float(outside["total"]), float(inside["total"])) or str(outside["parts"]) != str(inside["parts"]):
				m.append("Judgment %s differs from %s on %s" % [str(pair[0]), str(pair[1]), str(find["kind"])])
	return _result(m)


## Equal parts: gear, Judgment 0.5, sense_base 0.5 (factor 0.75), so sense = 3 x 6 x 0.75 = 13.5; afraid 0.5 x afraid_pick 27
## = 13.5; calling cell 13.5. All three equal gives "identity"; identity 0 with sense = state gives "sense".
static func _t_reason_tie() -> Dictionary:
	var m: Array = []
	var a := { "calling": "okofor", "calling_origin": "okofor", "archetype_birth": "none", "vector_scores": {}, "traits": {},
		"stats": {}, "morale": 50, "fear": 0, "fear_base": 0, "faction": "echo", "kind": "echo" }
	var ctx := _ctx(a, -0.5)
	ctx["calling_behavior"] = {}
	var pick := ctx["pick"] as Dictionary
	pick["sense_base"] = 0.5
	pick["freeze_at"] = 1.0
	pick["afraid_pick"] = { "gear": 27, "relic": 0, "consumable": 0, "material": 0 }
	var calling_rows := pick["calling_pick"] as Dictionary
	calling_rows["okofor"] = { "gear": 13.5, "relic": 0, "consumable": 0, "material": 0 }
	var ch := _chooser(a, 0.5)
	var r := PickupPick.appeal(ch, _gear(), ctx)
	if not _near(float(r["identity"]), 13.5) or not _near(float(r["sense"]), 13.5) or not _near(float(r["state"]), 13.5):
		m.append("the parts are not equal: %s" % str(r))
	if PickupPick.reason(ch, _gear(), ctx) != "identity":
		m.append("a three-way tie did not give identity")
	calling_rows["okofor"] = { "gear": 0, "relic": 0, "consumable": 0, "material": 0 }
	if PickupPick.reason(ch, _gear(), ctx) != "sense":
		m.append("a sense and state tie did not give sense")
	return _result(m)
