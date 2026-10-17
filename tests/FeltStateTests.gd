# res://tests/FeltStateTests.gd
# EmotionStatusLean (pure), the band_lean table in data.combat.movement.felt_state, and the
# chip, Judgment and validation readers of the shared emotional status.

class_name FeltStateTests
extends RefCounted


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("felt_state/band_table_valid", _t_band_table_valid)
	runner.register_test("felt_state/bad_tables_rejected", _t_bad_tables_rejected)
	runner.register_test("felt_state/lean_follows_the_shared_status", _t_lean_follows_the_shared_status)
	runner.register_test("felt_state/fear_and_low_morale_combine_by_the_status", _t_fear_and_low_morale_combine)
	runner.register_test("felt_state/composure_softens_all_leans", _t_composure_softens_all_leans)
	runner.register_test("felt_state/neutral_states_give_zero", _t_neutral_states_give_zero)
	runner.register_test("felt_state/ladder_is_the_single_order", _t_ladder_is_the_single_order)
	runner.register_test("felt_state/arbiter_rejects_bad_table", _t_arbiter_rejects_bad_table)
	runner.register_test("felt_state/fear_lean_is_softened_by_composure", _t_fear_lean_is_softened_by_composure)
	runner.register_test("felt_state/chip_reads_max_of_fear_and_base", _t_chip_reads_max_of_fear_and_base)
	runner.register_test("felt_state/fear_lowers_judgment_through_the_status", _t_fear_lowers_judgment_through_the_status)
	runner.register_test("felt_state/slice_switches_ship_off", _t_slice_switches_ship_off)


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


static func _data() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	return cs.get_balance()["data"] as Dictionary


static func _movement() -> Dictionary:
	return (_data()["combat"] as Dictionary)["movement"] as Dictionary


static func _table() -> Dictionary:
	return EmotionStatusLean.table_of(_movement())


static func _dampen() -> float:
	return float((((_data()["maturity_expression"] as Dictionary)["composure_dampen_scale"]) as Dictionary)["value"])


static func _t_band_table_valid() -> Dictionary:
	var table: Dictionary = _table()
	if not EmotionStatusLean.is_valid(table):
		return _fail("the shipped band_lean table is not valid")
	for status: String in EmotionService.STATUS_LADDER:
		if not table.has(status):
			return _fail("missing status %s" % status)
	var previous := -1.0
	for status: String in EmotionService.STATUS_LADDER:
		if float(table[status]) < previous:
			return _fail("%s falls below the status before it" % status)
		previous = float(table[status])
	if float(table["grounded"]) != 0.0 or float(table["whole"]) != 0.0:
		return _fail("grounded and whole must be exactly 0")
	if table.size() != EmotionService.STATUS_LADDER.size():
		return _fail("the table holds a key that is not a status: %s" % str(table.keys()))
	return _pass()


static func _t_bad_tables_rejected() -> Dictionary:
	var good: Dictionary = _table()
	var bad: Array = []
	var missing: Dictionary = good.duplicate()
	missing.erase("pressed")
	bad.append(["missing status", missing])
	for label_value: Array in [["above 1", "radiant", 1.1], ["below -1", "hollow", -1.1], ["NaN", "pressed", NAN], ["INF", "radiant", INF],
			["string", "pressed", "0.5"], ["null", "pressed", null], ["falls along the ladder", "burdened", -0.95],
			["grounded not 0", "grounded", 0.01], ["whole not 0", "whole", -0.01]]:
		var table: Dictionary = good.duplicate()
		table[label_value[1]] = label_value[2]
		bad.append([label_value[0], table])
	bad.append(["not a table", "x"])
	for case: Array in bad:
		if EmotionStatusLean.is_valid(case[1]):
			return _fail("%s was accepted" % case[0])
	return _pass()


static func _t_lean_follows_the_shared_status() -> Dictionary:
	var table: Dictionary = _table()
	for morale: int in range(0, 101, 5):
		for fear: int in range(0, 101, 5):
			var actor: Dictionary = {"morale": morale, "fear": fear, "fear_base": 0}
			var status: String = EmotionService.get_emotional_status(morale, fear)
			if EmotionStatusLean.status_of(actor) != status:
				return _fail("morale %d fear %d: status %s, shared rule %s" % [morale, fear, EmotionStatusLean.status_of(actor), status])
			if EmotionStatusLean.lean(status, table) != float(table[status]):
				return _fail("morale %d fear %d: lean is not the table entry of %s" % [morale, fear, status])
	return _pass()


static func _t_fear_and_low_morale_combine() -> Dictionary:
	var table: Dictionary = _table()
	var by_fear: String = EmotionService.get_emotional_status(50, 50)
	var by_morale: String = EmotionService.get_emotional_status(20, 0)
	var both: String = EmotionService.get_emotional_status(20, 50)
	var ladder: Array = EmotionService.STATUS_LADDER
	if both != by_morale or ladder.find(both) >= ladder.find(by_fear):
		return _fail("fixture broken: %s / %s / %s" % [by_fear, by_morale, both])
	var afraid_both: float = EmotionStatusLean.afraid(EmotionStatusLean.lean(both, table))
	if afraid_both < EmotionStatusLean.afraid(EmotionStatusLean.lean(by_fear, table)) \
			or afraid_both < EmotionStatusLean.afraid(EmotionStatusLean.lean(by_morale, table)):
		return _fail("fear and low morale together must be at least as afraid as either alone")
	return _pass()


static func _t_composure_softens_all_leans() -> Dictionary:
	var dampen: float = _dampen()
	for lean_value: float in [-1.0, -0.55, 0.0, 0.7]:
		if not is_equal_approx(EmotionStatusLean.soften(lean_value, 0.0, dampen), lean_value):
			return _fail("composure 0 must not soften %s" % lean_value)
		if not is_equal_approx(EmotionStatusLean.soften(lean_value, 1.0, dampen), lean_value * (1.0 - dampen)):
			return _fail("composure 1 must keep %s of %s" % [1.0 - dampen, lean_value])
		if not is_equal_approx(EmotionStatusLean.soften(lean_value, 7.0, dampen), EmotionStatusLean.soften(lean_value, 1.0, dampen)):
			return _fail("composure must be clamped to 1")
	var table: Dictionary = _table()
	var afraid_actor: Dictionary = {"morale": 50, "fear": 60}
	var bold_actor: Dictionary = {"morale": 80, "fear": 0}
	var calm_afraid: float = EmotionStatusLean.afraid_of(afraid_actor, table, 0.0, dampen)
	var calm_bold: float = EmotionStatusLean.bold(EmotionStatusLean.soften(EmotionStatusLean.lean(EmotionStatusLean.status_of(bold_actor), table), 0.0, dampen))
	if calm_afraid <= 0.0 or calm_bold <= 0.0:
		return _fail("fixture broken: afraid %s bold %s" % [calm_afraid, calm_bold])
	if not is_equal_approx(EmotionStatusLean.afraid_of(afraid_actor, table, 1.0, dampen), calm_afraid * (1.0 - dampen)):
		return _fail("afraid lean at composure 1 is not softened by the dampen scale")
	if EmotionStatusLean.afraid_of(afraid_actor, {}, 0.0, dampen) != 0.0:
		return _fail("an empty table must give 0")
	return _pass()


static func _t_neutral_states_give_zero() -> Dictionary:
	var table: Dictionary = _table()
	var dampen: float = _dampen()
	var default_echo: Dictionary = {"morale": 50, "fear": 0, "fear_base": 0}
	for actor: Dictionary in [default_echo, {"morale": 60, "fear": 30}, {"morale": 69, "fear": 0}]:
		for composure: float in [0.0, 0.5, 1.0]:
			if EmotionStatusLean.soften(EmotionStatusLean.lean(EmotionStatusLean.status_of(actor), table), composure, dampen) != 0.0 \
					or EmotionStatusLean.afraid_of(actor, table, composure, dampen) != 0.0:
				return _fail("%s at composure %s must give lean 0" % [str(actor), composure])
	var expect: Array = [
		[{"morale": 72, "fear": 10}, "radiant"], [{"morale": 37, "fear": 0}, "uncertain"], [{"morale": 30, "fear": 0}, "hesitant"],
	]
	for case: Array in expect:
		if EmotionStatusLean.status_of(case[0]) != case[1] or EmotionStatusLean.lean(case[1], table) == 0.0:
			return _fail("%s must read %s with a non-zero lean" % [str(case[0]), case[1]])
	return _pass()


static func _t_ladder_is_the_single_order() -> Dictionary:
	for i: int in EmotionService.STATUS_LADDER.size():
		if EncounterSnapshotBuilder._emotional_status_rank(EmotionService.STATUS_LADDER[i]) != i:
			return _fail("rank of %s is not its ladder index" % EmotionService.STATUS_LADDER[i])
	if EncounterSnapshotBuilder._emotional_status_rank("nonsense") != EmotionService.STATUS_LADDER.find("hesitant"):
		return _fail("an unknown status must rank as hesitant")
	return _pass()


static func _t_arbiter_rejects_bad_table() -> Dictionary:
	var movement: Dictionary = _movement().duplicate(true)
	if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
		return _fail("the shipped movement config was rejected")
	((movement["felt_state"] as Dictionary)["band_lean"] as Dictionary)["hollow"] = 0.5
	var verdict: Dictionary = BehaviorArbiter.new({}, movement)._validate_spatial_config()
	if bool(verdict["valid"]) or str(verdict["reason"]) != "invalid_felt_state_band_lean":
		return _fail("a falling table must fail with invalid_felt_state_band_lean: %s" % str(verdict))
	movement["felt_state"] = "x"
	if bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
		return _fail("a felt_state that is not a block was accepted")
	movement.erase("felt_state")
	if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
		return _fail("a missing felt_state block must stay valid")
	return _pass()


static func _t_fear_lean_is_softened_by_composure() -> Dictionary:
	var movement: Dictionary = _movement()
	var arbiter := BehaviorArbiter.new({}, movement)
	var actor: Dictionary = {"morale": 50, "fear": 60, "fear_base": 0}
	var bound: float = float((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])
	var afraid: float = maxf(0.0, -float(_table()[EmotionService.get_emotional_status(50, 60)]))
	for composure: float in [0.0, 0.3, 1.0]:
		var want: float = bound * afraid * (1.0 - _dampen() * composure)
		if not is_equal_approx(arbiter._fear_lean(actor, composure), want):
			return _fail("composure %s: lean %s, expected %s" % [composure, arbiter._fear_lean(actor, composure), want])
	return _pass()


static func _t_chip_reads_max_of_fear_and_base() -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.chip", "faction": "echo", "morale": 50, "fear": 0, "fear_base": 50,
		"stats": {"max_hp": 10}, "current_hp": 10,
	}
	var chip: String = str(EncounterSnapshotBuilder._project_actor(actor)["emotional_status"])
	var sim: String = EmotionService.get_emotional_status(50, 50)
	if chip != sim:
		return _fail("the chip shows %s, the sim reads %s" % [chip, sim])
	if chip == EmotionService.get_emotional_status(50, 0):
		return _fail("fixture broken: raw fear and max(fear, fear_base) give the same status")
	return _pass()


static func _t_fear_lowers_judgment_through_the_status() -> Dictionary:
	var data: Dictionary = _data()
	var expr_cfg: Dictionary = data["maturity_expression"] as Dictionary
	var weight: float = float((((expr_cfg["autonomy_outputs"] as Dictionary)["judgment"]) as Dictionary)["fear_pressure_weight"])
	var table: Dictionary = _table()
	var judgments: Dictionary = {}
	for label_pair: Array in [["calm", 50, 0], ["burdened", 50, 50], ["low_morale", 20, 0]]:
		var actor: Dictionary = {"rank": 3, "morale": label_pair[1], "fear": label_pair[2], "fear_base": 0, "calling": "okofor"}
		var inputs: Dictionary = MaturityExpressionService.build_ctx_inputs(actor, [], {}, data, {}, {}, 0.0)
		if inputs["band_lean"] != table:
			return _fail("build_ctx_inputs must carry the band_lean table")
		judgments[label_pair[0]] = float(MaturityExpressionService.derive_expression(actor, inputs, expr_cfg)["judgment"])
	var afraid_burdened: float = EmotionStatusLean.afraid(float(table["burdened"]))
	var afraid_pressed: float = EmotionStatusLean.afraid(float(table["pressed"]))
	if judgments["calm"] - weight * afraid_burdened <= 0.0:
		return _fail("fixture broken: Judgment is clamped at 0")
	if not is_equal_approx(float(judgments["calm"]) - float(judgments["burdened"]), weight * afraid_burdened):
		return _fail("burdened should lower Judgment by %s, got %s" % [weight * afraid_burdened, float(judgments["calm"]) - float(judgments["burdened"])])
	if not is_equal_approx(float(judgments["calm"]) - float(judgments["low_morale"]), weight * afraid_pressed):
		return _fail("low morale should lower Judgment by %s, got %s" % [weight * afraid_pressed, float(judgments["calm"]) - float(judgments["low_morale"])])
	var no_table: Dictionary = {"rank": 3, "morale": 50, "fear": 90, "fear_base": 0, "calling": "okofor"}
	var bare: Dictionary = MaturityExpressionService.build_ctx_inputs(no_table, [], {}, data, {}, {}, 0.0)
	bare.erase("band_lean")
	var calm_actor: Dictionary = {"rank": 3, "morale": 50, "fear": 0, "fear_base": 0, "calling": "okofor"}
	var with_fear: float = float(MaturityExpressionService.derive_expression(no_table, bare, expr_cfg)["judgment"])
	var without: float = float(MaturityExpressionService.derive_expression(calm_actor, bare, expr_cfg)["judgment"])
	if with_fear > without + 0.0000001:
		return _fail("without a table fear must not raise Judgment")
	return _pass()


static func _t_slice_switches_ship_off() -> Dictionary:
	var felt: Dictionary = _movement()["felt_state"] as Dictionary
	for key: String in ["lean", "steps", "style_growth"]:
		var block: Dictionary = felt[key] as Dictionary
		if not block.has("enabled") or block["enabled"] != false:
			return _fail("felt_state.%s.enabled must ship as false" % key)
	return _pass()
