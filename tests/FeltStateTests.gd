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
	runner.register_test("felt_state/slice_switches_ship_on", _t_slice_switches_ship_on)
	runner.register_test("felt_state/pull_follows_the_table_and_bounds", _t_pull_follows_the_table_and_bounds)
	runner.register_test("felt_state/spatial_utility_scales_only_the_pull_terms", _t_spatial_utility_scales_only_the_pull_terms)
	runner.register_test("felt_state/afraid_and_bold_contrast_through_state_machine", _t_contrast_through_state_machine)
	runner.register_test("felt_state/enemy_has_no_lean", _t_enemy_has_no_lean)
	runner.register_test("felt_state/temporary_ally_has_no_lean_or_steps", _t_temporary_ally_has_no_lean_or_steps)
	runner.register_test("felt_state/config_sections_validated", _t_config_sections_validated)
	runner.register_test("felt_state/all_switches_off_equals_block_absent", _t_all_switches_off_equals_absent)
	runner.register_test("felt_state/neutral_state_leaves_lean_and_steps_unchanged", _t_neutral_state_unchanged)
	runner.register_test("felt_state/state_steps_thresholds_follow_composure", _t_state_steps_thresholds)
	runner.register_test("felt_state/state_steps_floor_cap_and_off", _t_state_steps_floor_cap_and_off)
	runner.register_test("felt_state/state_steps_echo_only_and_par_blind", _t_state_steps_echo_only)
	runner.register_test("felt_state/state_steps_follow_state_each_activation", _t_state_steps_each_activation)
	runner.register_test("felt_state/frightened_carrier_keeps_valid_profile", _t_frightened_carrier)
	runner.register_test("felt_state/style_growth_scales_only_identity_parts", _t_style_growth_identity_only)
	runner.register_test("felt_state/style_growth_off_is_exactly_one", _t_style_growth_off)


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


static func _t_slice_switches_ship_on() -> Dictionary:
	var felt: Dictionary = _movement()["felt_state"] as Dictionary
	for key: String in ["lean", "steps", "style_growth"]:
		var block: Dictionary = felt[key] as Dictionary
		if block.get("enabled", null) != true:
			return _fail("felt_state.%s.enabled must ship as true" % key)
	return _pass()


## `movement` with the three switches set (null leaves the shipped value) or the block removed.
static func _felt(lean: Variant, steps: Variant, growth: Variant, absent: bool = false) -> Dictionary:
	var movement: Dictionary = _movement().duplicate(true)
	if absent:
		movement.erase("felt_state")
		return movement
	var felt: Dictionary = movement["felt_state"] as Dictionary
	for pair: Array in [["lean", lean], ["steps", steps], ["style_growth", growth]]:
		if pair[1] != null:
			(felt[pair[0]] as Dictionary)["enabled"] = pair[1]
	return movement


static func _t_pull_follows_the_table_and_bounds() -> Dictionary:
	var lean_cfg: Dictionary = (_movement()["felt_state"] as Dictionary)["lean"] as Dictionary
	for status: String in ["grounded", "whole"]:
		var neutral: Array = BehaviorArbiter.felt_pull(float(_table()[status]), lean_cfg)
		if neutral[0] != 1.0 or neutral[1] != 1.0:
			return _fail("%s must give exactly 1.0 and 1.0, got %s" % [status, str(neutral)])
	var pressed: Array = BehaviorArbiter.felt_pull(float(_table()["pressed"]), lean_cfg)
	if not (float(pressed[0]) < 1.0 and float(pressed[1]) > 1.0):
		return _fail("an afraid lean must lower progress and raise cohesion: %s" % str(pressed))
	var radiant: Array = BehaviorArbiter.felt_pull(float(_table()["radiant"]), lean_cfg)
	if not (float(radiant[0]) > 1.0 and float(radiant[1]) < 1.0):
		return _fail("a bold lean must raise progress and lower cohesion: %s" % str(radiant))
	var hollow: Array = BehaviorArbiter.felt_pull(-1.0, lean_cfg)
	if not (is_equal_approx(float(hollow[0]), float(lean_cfg["progress_floor"])) and is_equal_approx(float(hollow[1]), float(lean_cfg["cohesion_max"]))):
		return _fail("lean -1 must reach the afraid bounds exactly: %s" % str(hollow))
	var bold: Array = BehaviorArbiter.felt_pull(1.0, lean_cfg)
	if not (is_equal_approx(float(bold[0]), float(lean_cfg["progress_max"])) and is_equal_approx(float(bold[1]), float(lean_cfg["cohesion_min"]))):
		return _fail("lean +1 must reach the bold bounds exactly: %s" % str(bold))
	return _pass()


static func _t_spatial_utility_scales_only_the_pull_terms() -> Dictionary:
	var cfg: Dictionary = MovementArbitrationTests._spatial_cfg()["spatial_utility"] as Dictionary
	var arbiter := BehaviorArbiter.new({}, MovementArbitrationTests._spatial_cfg())
	var goal: Dictionary = {"urgency": 0.5, "purpose": "advance"}
	var option: Dictionary = {"objective_progress": 0.6, "cohesion": 0.5, "exposure": 0.3, "congestion": 0.2, "commitment": 1, "capacity": 4}
	var base: Dictionary = {}
	var scaled: Dictionary = {}
	var plain: float = arbiter._spatial_utility(goal, option, {}, cfg, base)
	if arbiter._spatial_utility(goal, option, {}, cfg, {}, 0.0, 0.0, 1.0, 1.0) != plain:
		return _fail("multipliers of 1.0 must reproduce the unscaled value exactly")
	arbiter._spatial_utility(goal, option, {}, cfg, scaled, 0.0, 0.0, 0.8, 1.25)
	var base_parts: Dictionary = base["parts"] as Dictionary
	var scaled_parts: Dictionary = scaled["parts"] as Dictionary
	for key: String in base_parts:
		var want: float = float(base_parts[key])
		if key == "objective_progress":
			want *= 0.8
		elif key == "cohesion":
			want *= 1.25
		if not is_equal_approx(float(scaled_parts[key]), want):
			return _fail("part %s: %s, wanted %s" % [key, scaled_parts[key], want])
	var sum := 0.0
	for key: String in scaled_parts:
		sum += float(scaled_parts[key])
	if not is_equal_approx(sum, float(scaled["raw"])):
		return _fail("the parts must still sum to raw: %s against %s" % [sum, scaled["raw"]])
	return _pass()


## One Echo (rank, fear, morale) through ActorStateMachine on the open fixture with a single route
## option. Returns {spatial, actor} for the route candidate, or {error}.
static func _machine_run(movement: Dictionary, rank: int, fear: int, morale: int) -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bdata: Dictionary = cs.get_balance()["data"] as Dictionary
	var fixture: Dictionary = MovementArbitrationTests._open_fixture(20, 4, {}, {})
	var actor: Dictionary = MovementArbitrationTests._judgment_actor(bdata, rank, "okofor", fear)
	actor["morale"] = morale
	actor["id"] = "echo.a"
	actor["grid_pos"] = {"col": 0, "row": 0}
	var options: Array = fixture["options"] as Array
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["option_id"]) < str(b["option_id"]))
	var context: Dictionary = {
		"actor": actor, "all_actors": [], "t": 1, "cfg": {"data": bdata},
		"movement_context": fixture["movement_context"], "movement_profile": fixture["profile"],
		"movement_goals": fixture["goals"], "movement_options": [options[options.size() - 1]],
	}
	var module := MovementArbitrationTests._InputsArbiter.new({}, movement)
	ActorStateMachine.new(actor, module).advance_turn(context, StructuredLogger.new(), 1)
	for key: String in ["winner", "runner_up"]:
		var spatial: Dictionary = (module.inputs.get(key, {}) as Dictionary).get("spatial", {}) as Dictionary
		if spatial.has("parts"):
			return {"spatial": spatial, "actor": actor}
	return {"error": "no route candidate reached the decision inputs"}


static func _t_contrast_through_state_machine() -> Dictionary:
	var on: Dictionary = _felt(true, false, false)
	var off: Dictionary = _felt(false, false, false)
	var lean_cfg: Dictionary = (on["felt_state"] as Dictionary)["lean"] as Dictionary
	var ratios: Dictionary = {}
	for case: Array in [["young_afraid", 1, 60, 50], ["seasoned_afraid", 9, 60, 50], ["young_bold", 1, 0, 80]]:
		var calm: Dictionary = _machine_run(off, int(case[1]), int(case[2]), int(case[3]))
		var felt: Dictionary = _machine_run(on, int(case[1]), int(case[2]), int(case[3]))
		if calm.has("error") or felt.has("error"):
			return _fail("%s: %s %s" % [case[0], calm.get("error", ""), felt.get("error", "")])
		var calm_parts: Dictionary = (calm["spatial"] as Dictionary)["parts"] as Dictionary
		var felt_parts: Dictionary = (felt["spatial"] as Dictionary)["parts"] as Dictionary
		if float(calm_parts["objective_progress"]) <= 0.0:
			return _fail("%s: fixture scored no progress" % case[0])
		var composure: float = float((felt["actor"] as Dictionary)["_composure"])
		var lean: float = EmotionStatusLean.soften(
			float(_table()[EmotionService.get_emotional_status(int(case[3]), int(case[2]))]), composure, _dampen())
		var want: Array = BehaviorArbiter.felt_pull(lean, lean_cfg)
		var got: float = float(felt_parts["objective_progress"]) / float(calm_parts["objective_progress"])
		if not is_equal_approx(got, float(want[0])):
			return _fail("%s: progress ratio %s, wanted %s (composure %s)" % [case[0], got, want[0], composure])
		if float(felt_parts["urgency"]) != float(calm_parts["urgency"]) or float(felt_parts["exposure"]) != float(calm_parts["exposure"]):
			return _fail("%s: urgency and exposure must stay unscaled" % case[0])
		ratios[case[0]] = got
	if not (float(ratios["young_afraid"]) < float(ratios["seasoned_afraid"]) and float(ratios["seasoned_afraid"]) < 1.0):
		return _fail("a seasoned Echo must lean less than a young one: %s" % str(ratios))
	if float(ratios["young_bold"]) <= 1.0:
		return _fail("a radiant Echo must push progress above 1.0: %s" % str(ratios))
	return _pass()


static func _t_enemy_has_no_lean() -> Dictionary:
	var texts: Array = []
	for movement: Dictionary in [_felt(true, true, true), _felt(false, false, false)]:
		var fixture: Dictionary = MovementArbitrationTests._open_fixture(20, 4, {}, {})
		var context: Dictionary = fixture["context"] as Dictionary
		var actor: Dictionary = context["actor"] as Dictionary
		actor["faction"] = "enemy"
		actor["fear"] = 95
		var result: Dictionary = BehaviorArbiter.new({}, movement).select_movement_intent(
			context, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary,
			fixture["goals"] as Array, fixture["options"] as Array)
		if not bool(result.get("valid", false)):
			return _fail("selection failed: %s" % str(result))
		texts.append(var_to_str(result))
	if texts[0] != texts[1]:
		return _fail("an enemy at fear 95 must decide the same with the felt-state switches on and off")
	return _pass()


## A temporary ally has the Echo faction and an enemy kind. Slices 5 and 6 use one gate, EmotionStatusLean.is_echo.
static func _t_temporary_ally_has_no_lean_or_steps() -> Dictionary:
	if EmotionStatusLean.is_echo({"faction": "echo", "actor_type": "enemy"}) or not EmotionStatusLean.is_echo({"faction": "echo", "actor_type": "echo"}):
		return _fail("is_echo must reject a temporary ally and accept an Echo")
	var texts: Array = []
	for movement: Dictionary in [_felt(true, false, false), _felt(false, false, false)]:
		var fixture: Dictionary = MovementArbitrationTests._open_fixture(20, 4, {}, {})
		var context: Dictionary = fixture["context"] as Dictionary
		var actor: Dictionary = context["actor"] as Dictionary
		actor["actor_type"] = "enemy"
		actor["fear"] = 95
		var result: Dictionary = BehaviorArbiter.new({}, movement).select_movement_intent(
			context, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary,
			fixture["goals"] as Array, fixture["options"] as Array)
		texts.append(var_to_str(result))
	if texts[0] != texts[1]:
		return _fail("a temporary ally at fear 95 must decide the same with the lean on and off")
	var on: Dictionary = _felt(false, true, false)
	var ally: Dictionary = _mover(3, 90, 50, 0.2)
	ally["actor_type"] = "enemy"
	ally.erase("kind")
	if int(_live_profile(ally, on)["capacity"]) != int(MovementProfileService.derive_profile(ally, _movement()["capacity"] as Dictionary)["capacity"]):
		return _fail("a temporary ally must not lose steps")
	return _pass()


static func _t_config_sections_validated() -> Dictionary:
	var ranges: Dictionary = (_movement()["felt_state"] as Dictionary)["ranges"] as Dictionary
	var bad_cases: Array = [
		["lean", "progress_floor", NAN], ["lean", "cohesion_max", INF], ["lean", "progress_max", "1.2"], ["lean", "enabled", "yes"],
		["steps", "composure_default", NAN], ["style_growth", "enabled", 1],
	]
	var good_cases: Array = []
	for section: String in ["lean", "steps"]:
		var section_ranges: Dictionary = ranges[section] as Dictionary
		for key: String in section_ranges:
			var bounds: Array = section_ranges[key] as Array
			bad_cases.append([section, key, float(bounds[0]) - 0.01])
			bad_cases.append([section, key, float(bounds[1]) + 0.01])
			good_cases.append([section, key, bounds[0]])
			good_cases.append([section, key, bounds[1]])
	var counts: Array = ranges["step_counts"] as Array
	for key: String in ["penalty_steps", "bonus_steps"]:
		bad_cases.append(["steps", key, int(counts.max()) + 1])
		bad_cases.append(["steps", key, int(counts.min()) - 1])
		for count: Variant in counts:
			good_cases.append(["steps", key, count])
	for case: Array in bad_cases:
		var movement: Dictionary = _movement().duplicate(true)
		((movement["felt_state"] as Dictionary)[case[0]] as Dictionary)[case[1]] = case[2]
		var verdict: Dictionary = BehaviorArbiter.new({}, movement)._validate_spatial_config()
		if bool(verdict["valid"]):
			return _fail("%s.%s = %s was accepted" % [case[0], case[1], str(case[2])])
		((movement["felt_state"] as Dictionary)[case[0]] as Dictionary)["enabled"] = false
		if case[1] != "enabled" and not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("%s.%s = %s was rejected while the section is off" % [case[0], case[1], str(case[2])])
	for section: String in ["lean", "steps", "style_growth"]:
		var movement: Dictionary = _movement().duplicate(true)
		(movement["felt_state"] as Dictionary).erase(section)
		if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("a missing %s section must stay valid (off)" % section)
	for bound: Array in good_cases:
		var movement: Dictionary = _movement().duplicate(true)
		((movement["felt_state"] as Dictionary)[bound[0]] as Dictionary)[bound[1]] = bound[2]
		if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
			return _fail("%s.%s = %s sits on the allowed range and was rejected" % [bound[0], bound[1], str(bound[2])])
	var no_ranges: Dictionary = _movement().duplicate(true)
	(no_ranges["felt_state"] as Dictionary).erase("ranges")
	if bool(BehaviorArbiter.new({}, no_ranges)._validate_spatial_config()["valid"]):
		return _fail("an enabled section without felt_state.ranges must fail loudly")
	return _pass()


## select_movement_intent on a fear-60 and a fear-95 Echo: the whole decision output as text.
static func _decision_text(movement: Dictionary, fear: int, morale: int) -> String:
	var fixture: Dictionary = MovementArbitrationTests._open_fixture(20, 4, {"col": 6, "row": 0}, {})
	var context: Dictionary = fixture["context"] as Dictionary
	var actor: Dictionary = context["actor"] as Dictionary
	actor["fear"] = fear
	actor["morale"] = morale
	var result: Dictionary = BehaviorArbiter.new({}, movement).select_movement_intent(
		context, fixture["movement_context"] as Dictionary, fixture["profile"] as Dictionary,
		fixture["goals"] as Array, fixture["options"] as Array)
	return var_to_str(result)


static func _t_all_switches_off_equals_absent() -> Dictionary:
	# The action layer and style read band_lean with no switch, so "absent" keeps the table.
	var sections_absent: Dictionary = _felt(null, null, null, true)
	sections_absent["felt_state"] = {"band_lean": EmotionStatusLean.table_of(_movement())}
	for state: Array in [[60, 50], [95, 3], [0, 90]]:
		var absent: String = _decision_text(sections_absent, int(state[0]), int(state[1]))
		var off: String = _decision_text(_felt(false, false, false), int(state[0]), int(state[1]))
		if absent != off:
			return _fail("fear %d morale %d: switches off differ from the block absent" % [int(state[0]), int(state[1])])
		if absent.find("felt") >= 0:
			return _fail("the decision output carries a felt-state key while off")
		var on: String = _decision_text(_felt(true, null, null), int(state[0]), int(state[1]))
		if on == absent:
			return _fail("fear %d morale %d: the lean switch changed nothing, so the test proves nothing" % [int(state[0]), int(state[1])])
	return _pass()


static func _t_neutral_state_unchanged() -> Dictionary:
	var absent: String = _decision_text(_felt(null, null, null, true), 0, 50)
	var lean_on: String = _decision_text(_felt(true, true, false), 0, 50)
	if absent != lean_on:
		return _fail("a grounded Echo must decide the same with the lean on")
	return _pass()


static func _live_env(mover: Dictionary, movement: Dictionary) -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.actors = [mover, BehaviorCharacterizationTests._enemy_actor("enemy.a", 6, 5)]
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.combat_state = {}
	ectx.purifier_id = ""
	var flow_ctx := FlowContext.new()
	flow_ctx.encounter_ctx = ectx
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var bdata: Dictionary = BehaviorCharacterizationTests._real_bdata()
	(bdata["combat"] as Dictionary)["movement"] = movement
	var board_cfg: Dictionary = {"board_cols": 10, "board_rows": 10, "walkable": BehaviorCharacterizationTests._full_walkable(10, 10)}
	return {"live": LiveMovementContextService.new(flow_ctx, logger), "ectx": ectx, "bdata": bdata, "board_cfg": board_cfg}


static func _live_profile(mover: Dictionary, movement: Dictionary, env: Dictionary = {}) -> Dictionary:
	if env.is_empty():
		env = _live_env(mover, movement)
	var ectx: EncounterContext = env["ectx"]
	var prepared: Dictionary = (env["live"] as LiveMovementContextService).prepare_live_movement_context(
		mover, ectx, ectx.combat_state, env["board_cfg"], env["bdata"], 0)
	return prepared.get("profile", {}) as Dictionary


static func _mover(rank: int, fear: int, morale: int, composure: Variant = null) -> Dictionary:
	var mover: Dictionary = BehaviorCharacterizationTests._echo_actor("echo.m", 0, 5)
	mover["rank"] = rank
	mover["fear"] = fear
	mover["morale"] = morale
	if composure != null:
		mover["_composure"] = float(composure)
	return mover


static func _t_state_steps_thresholds() -> Dictionary:
	var on: Dictionary = _felt(false, true, false)
	# [rank, fear, morale, composure, expected capacity]; rank 3 derives 3 steps, rank 1 derives 2.
	var cases: Array = [
		[3, 0, 50, 0.2, 3], [3, 45, 50, 0.2, 2], [3, 45, 50, 0.4, 3], [3, 55, 50, 0.4, 2],
		[3, 55, 50, 0.8, 2], [3, 65, 50, 0.85, 2], [3, 65, 50, 0.95, 2], [3, 55, 50, 0.95, 3],
		[3, 90, 50, 0.95, 2], [3, 0, 75, 0.2, 4], [3, 0, 75, 0.95, 3], [1, 90, 50, 0.0, 2], [1, 0, 75, 0.2, 3],
	]
	for case: Array in cases:
		var profile: Dictionary = _live_profile(_mover(int(case[0]), int(case[1]), int(case[2]), case[3]), on)
		if int(profile.get("capacity", -1)) != int(case[4]):
			return _fail("rank %d fear %d morale %d composure %s: capacity %s, wanted %d" % [case[0], case[1], case[2], case[3], profile.get("capacity"), case[4]])
	return _pass()


static func _t_state_steps_floor_cap_and_off() -> Dictionary:
	var capacity_cfg: Dictionary = _movement()["capacity"] as Dictionary
	var six: Dictionary = MovementProfile.build(6, [{"source": "x", "capacity": 6}], true, "echo", {})
	if MovementProfileService.apply_state_steps(six, 1, capacity_cfg) != six:
		return _fail("capacity 6 gaining a step must return the profile unchanged")
	var floor_profile: Dictionary = MovementProfileService.derive_profile(_mover(1, 0, 50), capacity_cfg)
	var again: Dictionary = MovementProfileService.apply_state_steps(floor_profile, -1, capacity_cfg)
	if var_to_str(again) != var_to_str(floor_profile) or int(again["capacity"]) != int(capacity_cfg["floor"]):
		return _fail("the floor must hold and leave source_terms untouched")
	var stepped: Dictionary = MovementProfileService.apply_state_steps(floor_profile, 1, capacity_cfg)
	var last: Dictionary = (stepped["source_terms"] as Array).back() as Dictionary
	if int(stepped["capacity"]) != int(floor_profile["capacity"]) + 1 or last != {"source": "state_steps", "capacity": 1}:
		return _fail("a changed capacity must append one state_steps term: %s" % str(stepped))
	if not bool(MovementProfile.validate(stepped)["valid"]):
		return _fail("a stepped profile must stay valid")
	var mover: Dictionary = _mover(3, 90, 50, 0.2)
	var derived: String = var_to_str(MovementProfileService.derive_profile(mover, capacity_cfg))
	for movement: Dictionary in [_felt(false, false, false), _felt(null, null, null, true)]:
		if var_to_str(_live_profile(mover, movement)) != derived:
			return _fail("with the switch off the live profile must equal derive_profile")
	return _pass()


static func _t_state_steps_echo_only() -> Dictionary:
	var on: Dictionary = _felt(false, true, false)
	var capacity_cfg: Dictionary = _movement()["capacity"] as Dictionary
	var enemy: Dictionary = _mover(3, 90, 50, 0.2)
	enemy["faction"] = "enemy"
	if int(_live_profile(enemy, on)["capacity"]) != int(MovementProfileService.derive_profile(enemy, capacity_cfg)["capacity"]):
		return _fail("an enemy must not lose steps")
	var override_profile: Dictionary = MovementProfileService.derive_profile(
		_mover(3, 90, 50, 0.2), capacity_cfg, {"authored_override": {"source": "guide", "capacity": 1}})
	if MovementProfileService.apply_state_steps(override_profile, 1, capacity_cfg) != override_profile:
		return _fail("an authored override must stay unchanged")
	var afraid: Dictionary = MovementProfileService.derive_profile(_mover(3, 90, 10), capacity_cfg)
	var calm: Dictionary = MovementProfileService.derive_profile(_mover(3, 0, 50), capacity_cfg)
	if var_to_str(afraid) != var_to_str(calm):
		return _fail("derive_profile must not read the emotional state (the par uses it)")
	return _pass()


static func _t_state_steps_each_activation() -> Dictionary:
	var on: Dictionary = _felt(false, true, false)
	var mover: Dictionary = _mover(3, 0, 50, 0.2)
	var env: Dictionary = _live_env(mover, on)
	var before: int = int(_live_profile(mover, on, env)["capacity"])
	mover["fear"] = 70
	var during: int = int(_live_profile(mover, on, env)["capacity"])
	mover["fear"] = 0
	var after: int = int(_live_profile(mover, on, env)["capacity"])
	if not (before == 3 and during == 2 and after == 3):
		return _fail("capacity must follow the state each activation: %d, %d, %d" % [before, during, after])
	var fresh: Dictionary = _mover(3, 45, 50)
	var default_composure: float = float(((on["felt_state"] as Dictionary)["steps"] as Dictionary)["composure_default"])
	var lean: float = EmotionStatusLean.soften(float(_table()["burdened"]), default_composure, _dampen())
	var expected: int = 2 if lean <= -float(((on["felt_state"] as Dictionary)["steps"] as Dictionary)["penalty_at"]) else 3
	if int(_live_profile(fresh, on)["capacity"]) != expected:
		return _fail("without a previous composure the config default must be used")
	return _pass()


static func _t_frightened_carrier() -> Dictionary:
	var on: Dictionary = _felt(false, true, false)
	var profile: Dictionary = _live_profile(_mover(3, 90, 50, 0.2), on)
	if int(profile["capacity"]) != 2:
		return _fail("fixture should hold a frightened capacity-2 carrier, got %s" % profile.get("capacity"))
	var state: Dictionary = ProtectCustodyTests._carried({"col": 1, "row": 1}, "echo.m", "echo")
	var report: Dictionary = ProtectCustodyService.apply_carrier_burden(profile, state, "echo.m", ProtectCustodyTests._protect_cfg())
	if not bool(MovementProfile.validate(report["profile"] as Dictionary)["valid"]):
		return _fail("the burdened frightened carrier is invalid: %s" % str(MovementProfile.validate(report["profile"] as Dictionary)))
	return _pass()


static func _style_cfg() -> Dictionary:
	return {
		"vector_bias": {"protector": {"guarded": 1.0}}, "calling_family_bias": {"anchor": {"guarded": 2.0}},
		"fear_weight": {"guarded": 4.0}, "follow_through_bias": {"afraid": {"guarded": 8.0}},
		"bond_weight": {"guarded": 16.0}, "vow_ward_weight": {"guarded": 32.0}, "trait_nudge": {"bold": {"guarded": 64.0}},
	}


static func _style_score(vector_mul: float, trait_mul: float) -> float:
	return MovementStyleService._score_style(
		"guarded", {"protector": 1.0}, "anchor", {"bold": 1.0}, 1.0, 0.0, 1.0, -1.0, _style_cfg(), vector_mul, trait_mul)


static func _t_style_growth_identity_only() -> Dictionary:
	var base: float = _style_score(1.0, 1.0)
	if not is_equal_approx(base, 1.0 + 2.0 + 4.0 + 8.0 + 16.0 + 32.0 + 64.0):
		return _fail("fixture sum is wrong: %s" % base)
	var grown: float = _style_score(1.35, 1.35)
	if not is_equal_approx(grown, (1.0 + 2.0 + 64.0) * 1.35 + 4.0 + 8.0 + 16.0 + 32.0):
		return _fail("only vector, family and trait parts may grow: %s" % grown)
	if not is_equal_approx(_style_score(2.0, 1.0) - base, 3.0) or not is_equal_approx(_style_score(1.0, 2.0) - base, 64.0):
		return _fail("vector_mul must reach vector and family parts only; trait_mul the trait part only")
	var data: Dictionary = _data()
	var scale: Dictionary = (data["maturity_expression"] as Dictionary)["identity_weight_scale"] as Dictionary
	var growth: Dictionary = BehaviorArbiter.new({}, _felt(null, null, true))._style_growth(0.5)
	if not is_equal_approx(float(growth["vector_mul"]), 1.0 + 0.5 * float(scale["vector"])) \
			or not is_equal_approx(float(growth["trait_mul"]), 1.0 + 0.5 * float(scale["trait"])):
		return _fail("growth must be 1 + J x identity_weight_scale: %s" % str(growth))
	return _pass()


static func _t_style_growth_off() -> Dictionary:
	for movement: Dictionary in [_felt(null, null, false), _felt(null, null, null, true)]:
		for j: float in [0.0, 0.3, 1.0]:
			var growth: Dictionary = BehaviorArbiter.new({}, movement)._style_growth(j)
			if growth["vector_mul"] != 1.0 or growth["trait_mul"] != 1.0:
				return _fail("growth off must give exactly 1.0 and 1.0 at J %s: %s" % [j, str(growth)])
	return _pass()
