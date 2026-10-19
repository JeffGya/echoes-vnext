# res://tests/MoraleInfluenceTests.gd
# The action layer reads the emotional status: one lean, softened by composure once, split into
# an afraid end and a bold end (BehaviorArbiter._score, _state_points). Every number comes from
# data/balance.json, so these tests hold when the PROPOSED DEFAULT values are tuned.

extends RefCounted
class_name MoraleInfluenceTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("morale/afraid_status_guards_despite_adjacent_enemy", Callable(MoraleInfluenceTests, "_t_afraid_status_guards_despite_adjacent_enemy"))
	runner.register_test("morale/status_metadata_carried_in_intent",           Callable(MoraleInfluenceTests, "_t_status_metadata_carried_in_intent"))
	runner.register_test("morale/advance_turn_action_log_has_status_fields",   Callable(MoraleInfluenceTests, "_t_advance_turn_action_log_has_status_fields"))
	runner.register_test("morale/snapshot_has_status_and_modifier",            Callable(MoraleInfluenceTests, "_t_snapshot_has_status_and_modifier"))
	runner.register_test("morale/composure_counted_once",                      Callable(MoraleInfluenceTests, "_t_composure_counted_once"))
	runner.register_test("morale/score_reads_only_the_status_lean",            Callable(MoraleInfluenceTests, "_t_score_reads_only_the_status_lean"))
	runner.register_test("morale/aduro_charges_when_afraid",                   Callable(MoraleInfluenceTests, "_t_aduro_charges_when_afraid"))
	runner.register_test("morale/enemy_reads_the_status",                      Callable(MoraleInfluenceTests, "_t_enemy_reads_the_status"))
	runner.register_test("morale/calling_signature_scales_by_afraid",          Callable(MoraleInfluenceTests, "_t_calling_signature_scales_by_afraid"))
	runner.register_test("morale/bold_status_raises_melee",                    Callable(MoraleInfluenceTests, "_t_bold_status_raises_melee"))
	runner.register_test("morale/afraid_curve_values",                         Callable(MoraleInfluenceTests, "_t_afraid_curve_values"))
	runner.register_test("morale/bark_triggers_follow_the_status",             Callable(MoraleInfluenceTests, "_t_bark_triggers_follow_the_status"))
	runner.register_test("morale/banter_bark_follows_calm_statuses",           Callable(MoraleInfluenceTests, "_t_banter_bark_follows_calm_statuses"))
	runner.register_test("morale/state_config_valid",                          Callable(MoraleInfluenceTests, "_t_state_config_valid"))
	runner.register_test("morale/state_config_rejects_bad_values",             Callable(MoraleInfluenceTests, "_t_state_config_rejects_bad_values"))
	runner.register_test("morale/bad_afraid_curve_exponent_scores_as_no_state_effect", Callable(MoraleInfluenceTests, "_t_bad_exponent_scores_as_no_state_effect"))
	runner.register_test("morale/arbiter_rejects_bad_afraid_curve_exponent",   Callable(MoraleInfluenceTests, "_t_arbiter_rejects_bad_afraid_curve_exponent"))


static func _data() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	return cs.get_balance()["data"] as Dictionary


static func _actor_cfg(data: Dictionary) -> Dictionary:
	return ConfigService.merge_actor_cfg(data["actor"] as Dictionary, data["maturity_expression"] as Dictionary)


static func _arbiter(data: Dictionary) -> BehaviorArbiter:
	return BehaviorArbiter.new(_actor_cfg(data), (data["combat"] as Dictionary)["movement"] as Dictionary)


## The afraid and bold ends the arbiter should see for this actor and composure.
static func _ends(data: Dictionary, actor: Dictionary, composure: float) -> Array:
	var table: Dictionary = EmotionStatusLean.table_of((data["combat"] as Dictionary)["movement"] as Dictionary)
	var lean: float = float(table[EmotionStatusLean.status_of(actor)])
	var keep: float = 1.0 - BehaviorArbiter.composure_dampen(_actor_cfg(data)) * composure
	var exponent: float = float((data["actor"] as Dictionary)["afraid_curve_exponent"])
	return [pow(maxf(0.0, -lean), exponent) * keep, maxf(0.0, lean) * keep]


static func _points(data: Dictionary, action_type: String, ends: Array) -> float:
	var row: Dictionary = ((data["actor"] as Dictionary)["state_action_points"] as Dictionary)[action_type] as Dictionary
	return float(ends[0]) * float(row["afraid"]) + float(ends[1]) * float(row["bold"])


static func _echo(id: String, calling: String, morale: int, fear: int) -> Dictionary:
	return {
		"id": id, "faction": "echo", "actor_type": "echo", "calling_origin": calling,
		"traits": {"courage": 0, "wisdom": 0, "faith": 0}, "vector_scores": {},
		"fear": fear, "morale": morale, "grid_pos": {"col": 0, "row": 0},
	}


static func _enemy(id: String) -> Dictionary:
	return {"id": id, "faction": "enemy", "grid_pos": {"col": 1, "row": 0}}


static func _components(arbiter: BehaviorArbiter, action_type: String, actor: Dictionary, composure: float,
		calling_behavior: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	arbiter._score(action_type, actor, {}, {}, "nascent", calling_behavior, {}, 0.1, 0.0, composure, 0.3, out)
	return out


# -------------------------
# Tests
# -------------------------

## A strongly afraid onyamesu (guard base high) guards next to an enemy.
static func _t_afraid_status_guards_despite_adjacent_enemy() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_morale_001", "onyamesu", 10, 0)
	var intent: Dictionary = _arbiter(data).select_intent({"actor": actor, "all_actors": [_enemy("enemy_morale_001")], "t": 1})
	if str(intent.get("action_type", "")) != "actor.guard":
		return _fail("Expected actor.guard for an afraid onyamesu, got: %s" % str(intent.get("action_type")))
	return _pass()


static func _t_status_metadata_carried_in_intent() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_morale_002", "aduro", 10, 0)
	var intent: Dictionary = _arbiter(data).select_intent({"actor": actor, "all_actors": [_enemy("enemy_morale_002")], "t": 2})
	var status: String = EmotionStatusLean.status_of(actor)
	if str(intent.get("emotional_status", "")) != status:
		return _fail("intent.emotional_status expected '%s', got '%s'" % [status, str(intent.get("emotional_status"))])
	var expected: float = _points(data, str(intent["action_type"]), _ends(data, actor, 0.4))
	if not is_equal_approx(float(intent.get("state_points", INF)), expected):
		return _fail("intent.state_points expected %f, got %s" % [expected, str(intent.get("state_points"))])
	if intent.has("morale_tier") or intent.has("morale_modifier"):
		return _fail("the old morale keys must be gone: %s" % str(intent))
	return _pass()


## ActorStateMachine logs the status and the rounded state points of the winner.
static func _t_advance_turn_action_log_has_status_fields() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_morale_003", "onyamesu", 10, 0)
	var sm := ActorStateMachine.new(actor, _arbiter(data))
	var logger := StructuredLogger.new()
	logger.set_level("debug")
	sm.advance_turn({"actor": actor, "all_actors": [_enemy("enemy_morale_003")], "t": 3}, logger, 3)
	var adata: Dictionary = {}
	for entry: Dictionary in logger.get_logs():
		if str(entry.get("type", "")) == "actor.action" and adata.is_empty():
			adata = entry.get("data", {}) as Dictionary
	if adata.is_empty():
		return _fail("No actor.action log event found")
	var expected: int = roundi(_points(data, str(adata["action_type"]), _ends(data, actor, float(actor["_composure"]))))
	if str(adata.get("emotional_status", "")) != EmotionStatusLean.status_of(actor):
		return _fail("actor.action emotional_status: %s" % str(adata.get("emotional_status")))
	if not adata.has("action_weight_modifier") or int(adata["action_weight_modifier"]) != expected or expected == 0:
		return _fail("actor.action action_weight_modifier expected %d (non-zero), got %s" % [expected, str(adata.get("action_weight_modifier"))])
	if adata.has("morale_tier"):
		return _fail("actor.action still logs morale_tier")
	return _pass()


static func _t_snapshot_has_status_and_modifier() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_morale_004", "onyamesu", 10, 0)
	var sm := ActorStateMachine.new(actor, _arbiter(data))
	var logger := StructuredLogger.new()
	sm.advance_turn({"actor": actor, "all_actors": [_enemy("enemy_morale_004")], "t": 4}, logger, 4)
	var snapshot: Dictionary = sm.get_snapshot()
	var action_type: String = str((snapshot["last_action"] as Dictionary)["action_type"])
	var expected: int = roundi(_points(data, action_type, _ends(data, actor, float(actor["_composure"]))))
	if str(snapshot.get("emotional_status", "")) != EmotionStatusLean.status_of(actor):
		return _fail("snapshot.emotional_status: %s" % str(snapshot.get("emotional_status")))
	if int(snapshot.get("action_weight_modifier", -999)) != expected or snapshot.has("morale_tier"):
		return _fail("snapshot.action_weight_modifier expected %d without morale_tier: %s" % [expected, str(snapshot)])
	return _pass()


## Composure softens the lean and nothing else: fear_factor = 1 - fear_active_dampen x afraid.
static func _t_composure_counted_once() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_once", "uncalled", 50, 60)
	var ends: Array = _ends(data, actor, 0.5)
	var expected: float = 1.0 - float((data["actor"] as Dictionary)["fear_active_dampen"]) * float(ends[0])
	var got: float = float(_components(_arbiter(data), "melee_attack", actor, 0.5)["fear_factor"])
	if float(ends[0]) <= 0.0:
		return _fail("fixture must be afraid")
	if not is_equal_approx(got, expected):
		return _fail("fear_factor at composure 0.5 expected %f, got %f" % [expected, got])
	return _pass()


## Two actors with other raw fear and morale but the same status score the same.
static func _t_score_reads_only_the_status_lean() -> Dictionary:
	var data: Dictionary = _data()
	var arbiter: BehaviorArbiter = _arbiter(data)
	var by_fear: Dictionary = _echo("echo_a", "uncalled", 50, 47)
	var by_morale: Dictionary = _echo("echo_b", "uncalled", 22, 10)
	by_morale["fear_base"] = 5
	if EmotionStatusLean.status_of(by_fear) != EmotionStatusLean.status_of(by_morale):
		return _fail("fixture statuses differ: %s vs %s" % [EmotionStatusLean.status_of(by_fear), EmotionStatusLean.status_of(by_morale)])
	for action_type: String in ["melee_attack", "protect_ally", "actor.guard", "actor.idle", "actor.move"]:
		var a: float = arbiter._score(action_type, by_fear, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3)
		var b: float = arbiter._score(action_type, by_morale, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3)
		if a != b:
			return _fail("%s: same status scored %f and %f" % [action_type, a, b])
	return _pass()


## Aduro's afraid_points_override replaces the afraid end; the fear factor still dampens melee.
static func _t_aduro_charges_when_afraid() -> Dictionary:
	var data: Dictionary = _data()
	var arbiter: BehaviorArbiter = _arbiter(data)
	var actor: Dictionary = _echo("echo_aduro", "aduro", 10, 0)
	var aduro: Dictionary = ((data["maturity_expression"] as Dictionary)["calling_behavior"] as Dictionary)["aduro"] as Dictionary
	var override: Dictionary = aduro["afraid_points_override"] as Dictionary
	var afraid: float = float(_ends(data, actor, 0.4)[0])
	for action_type: String in override:
		var got: float = float(_components(arbiter, action_type, actor, 0.4, aduro)["morale_bonus"])
		if not is_equal_approx(got, afraid * float(override[action_type])):
			return _fail("%s: expected %f, got %f" % [action_type, afraid * float(override[action_type]), got])
	var melee: Dictionary = _components(arbiter, "melee_attack", actor, 0.4, aduro)
	var plain: Dictionary = _components(arbiter, "melee_attack", actor, 0.4, {})
	if float(melee["morale_bonus"]) <= 0.0 or float(plain["morale_bonus"]) >= 0.0:
		return _fail("aduro must charge when afraid and a plain Echo must not: %f / %f" % [melee["morale_bonus"], plain["morale_bonus"]])
	if float(melee["fear_factor"]) >= 1.0:
		return _fail("the fear factor must still dampen aduro's melee")
	return _pass()


## Enemies read the same status as Echoes in the action layer.
static func _t_enemy_reads_the_status() -> Dictionary:
	var data: Dictionary = _data()
	var arbiter: BehaviorArbiter = _arbiter(data)
	var echo: Dictionary = _echo("echo_x", "enemy", 10, 70)
	var enemy: Dictionary = echo.duplicate(true)
	enemy["faction"] = "enemy"
	enemy["actor_type"] = "enemy"
	var e: Dictionary = _components(arbiter, "melee_attack", enemy, 0.4)
	var a: Dictionary = _components(arbiter, "melee_attack", echo, 0.4)
	if float(e["fear_factor"]) >= 1.0 or float(e["morale_bonus"]) == 0.0:
		return _fail("an afraid enemy must read the status: %s" % str(e))
	if e["fear_factor"] != a["fear_factor"] or e["morale_bonus"] != a["morale_bonus"]:
		return _fail("enemy and Echo with one status differ: %s vs %s" % [str(e), str(a)])
	return _pass()


## A calling signature adds afraid x its configured points, and nothing when calm.
static func _t_calling_signature_scales_by_afraid() -> Dictionary:
	var data: Dictionary = _data()
	var arbiter: BehaviorArbiter = _arbiter(data)
	var callings: Dictionary = (data["maturity_expression"] as Dictionary)["calling_behavior"] as Dictionary
	var checked: int = 0
	for calling: String in callings:
		var behavior: Variant = callings[calling]
		if not behavior is Dictionary or not (behavior as Dictionary).has("afraid_signature"):
			continue
		var signature: Dictionary = (behavior as Dictionary)["afraid_signature"] as Dictionary
		for action_type: String in signature:
			for fixture: Array in [[10, 0], [50, 0]]:
				var actor: Dictionary = _echo("echo_sig", calling, int(fixture[0]), int(fixture[1]))
				var afraid: float = float(_ends(data, actor, 0.0)[0])
				var with_sig: float = float(_components(arbiter, action_type, actor, 0.0, behavior)["base"])
				var without: float = float(_components(arbiter, action_type, actor, 0.0, {})["base"])
				if not is_equal_approx(with_sig - without, afraid * float(signature[action_type])):
					return _fail("%s %s: signature added %f, expected %f" % [calling, action_type, with_sig - without, afraid * float(signature[action_type])])
				checked += 1
	if checked == 0:
		return _fail("no afraid_signature in config")
	return _pass()


static func _t_bold_status_raises_melee() -> Dictionary:
	var data: Dictionary = _data()
	var actor: Dictionary = _echo("echo_bold", "uncalled", 80, 0)
	var ends: Array = _ends(data, actor, 0.4)
	var got: Dictionary = _components(_arbiter(data), "melee_attack", actor, 0.4)
	if float(ends[1]) <= 0.0 or float(got["fear_factor"]) != 1.0:
		return _fail("fixture must be bold and unafraid: %s" % str(ends))
	if not is_equal_approx(float(got["morale_bonus"]), _points(data, "melee_attack", ends)) or float(got["morale_bonus"]) <= 0.0:
		return _fail("bold melee points: %s" % str(got))
	return _pass()


## The curve acts on the unsoftened lean, then composure softens once; slices 5 and 6 stay linear.
static func _t_afraid_curve_values() -> Dictionary:
	var table: Dictionary = EmotionStatusLean.table_of(_data()["combat"]["movement"] as Dictionary)
	for status: String in ["hollow", "burdened", "hesitant"]:
		var lean: float = float(table[status])
		var raw: float = -lean
		if not is_equal_approx(EmotionStatusLean.curved_afraid(lean, 2.5, 0.0, 0.4), pow(raw, 2.5)):
			return _fail("%s: curve at k 2.5 must be %f" % [status, pow(raw, 2.5)])
		if not is_equal_approx(EmotionStatusLean.curved_afraid(lean, 2.5, 0.5, 0.4), pow(raw, 2.5) * 0.8):
			return _fail("%s: composure must scale the curved value once" % status)
		if not is_equal_approx(EmotionStatusLean.afraid(EmotionStatusLean.soften(lean, 0.5, 0.4)), raw * 0.8):
			return _fail("%s: the linear afraid() of slices 5 and 6 changed" % status)
	if EmotionStatusLean.curved_afraid(float(table["radiant"]), 2.5, 0.0, 0.4) != 0.0:
		return _fail("a bold status must have no afraid value")
	return _pass()


static func _bark_context(start_status: String, end_status: String, action_type: String) -> String:
	var asm := ActorStateMachine.new({"id": "echo.bark", "fear": 0, "morale": 50}, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", action_type, 0, 0, start_status, end_status, false, false, "", 0, 0,
		false, 0, "", "", "", 0, calm_statuses(), CombatDivergenceBarkTests.routine_bark_cfg())
	return asm._bark_context


static func calm_statuses() -> Array:
	return (_data()["maturity_expression"] as Dictionary)["combat_banter"]["calm_statuses"] as Array


## Banter follows the status after the turn, not raw fear or the morale tier.
static func _t_banter_bark_follows_calm_statuses() -> Dictionary:
	for status: String in EmotionService.STATUS_LADDER:
		var banters: bool = _bark_context(status, status, "actor.guard") == "combat_banter"
		if banters != (status in calm_statuses()):
			return _fail("status %s: banter %s, calm statuses are %s" % [status, banters, calm_statuses()])
	if calm_statuses().is_empty():
		return _fail("fixture: the calm status list is empty")
	return _pass()


## "morale falling" fires when the status gets worse, for any cause; "inspired" fires at radiant.
static func _t_bark_triggers_follow_the_status() -> Dictionary:
	if _bark_context("grounded", "burdened", "actor.guard") != "combat_morale_falling":
		return _fail("a worse status must select combat_morale_falling")
	if _bark_context("burdened", "grounded", "actor.guard") == "combat_morale_falling" \
			or _bark_context("pressed", "pressed", "actor.guard") == "combat_morale_falling":
		return _fail("a better or equal status must not select combat_morale_falling")
	if _bark_context("radiant", "radiant", "melee_attack") != "combat_inspired":
		return _fail("radiant + melee must select combat_inspired")
	if _bark_context("whole", "whole", "melee_attack") == "combat_inspired":
		return _fail("only radiant selects combat_inspired")
	return _pass()


static func _t_state_config_valid() -> Dictionary:
	var errors: Array[String] = BehaviorArbiter.state_config_errors(_data())
	if not errors.is_empty():
		return _fail("balance.json status-point tables are invalid: %s" % str(errors))
	return _pass()


static func _t_state_config_rejects_bad_values() -> Dictionary:
	var cases: Array = [
		["actor.afraid_curve_exponent", func(d: Dictionary) -> void:
			d["actor"]["afraid_curve_exponent"] = 4.5],
		["actor.afraid_curve_exponent", func(d: Dictionary) -> void:
			d["actor"]["afraid_curve_exponent"] = 0.5],
		["combat.initiative_modifiers.bold_points", func(d: Dictionary) -> void:
			d["combat"]["initiative_modifiers"]["bold_points"] = "high"],
		["combat.initiative_modifiers.afraid_points", func(d: Dictionary) -> void:
			(d["combat"]["initiative_modifiers"] as Dictionary).erase("afraid_points")],
		["actor.state_action_points.melee_attack", func(d: Dictionary) -> void:
			var limit: float = float(d["actor"]["state_action_points"]["max_abs"])
			d["actor"]["state_action_points"]["melee_attack"]["bold"] = limit + 1.0],
		["actor.state_action_points.actor.fly", func(d: Dictionary) -> void:
			d["actor"]["state_action_points"]["actor.fly"] = {"afraid": 0.0, "bold": 0.0}],
		["actor.state_action_points.actor.move", func(d: Dictionary) -> void:
			(d["actor"]["state_action_points"]["actor.move"] as Dictionary).erase("bold")],
		["actor.state_action_points.max_abs", func(d: Dictionary) -> void:
			d["actor"]["state_action_points"]["max_abs"] = 0.0],
		["actor.movement_style_weights.follow_through_bias.calm", func(d: Dictionary) -> void:
			d["actor"]["movement_style_weights"]["follow_through_bias"]["calm"] = {}],
		["actor.movement_style_weights.follow_through_bias.bold", func(d: Dictionary) -> void:
			d["actor"]["movement_style_weights"]["follow_through_bias"]["bold"]["dancing"] = 1.0],
		["maturity_expression.calling_behavior.okomfo.afraid_signature", func(d: Dictionary) -> void:
			d["maturity_expression"]["calling_behavior"]["okomfo"]["afraid_signature"]["actor.fly"] = 1.0],
		["maturity_expression.calling_behavior.aduro.afraid_points_override", func(d: Dictionary) -> void:
			var limit: float = float(d["actor"]["state_action_points"]["max_abs"])
			d["maturity_expression"]["calling_behavior"]["aduro"]["afraid_points_override"]["melee_attack"] = limit + 1.0],
	]
	for case: Array in cases:
		var data: Dictionary = _data().duplicate(true)
		(case[1] as Callable).call(data)
		var errors: Array[String] = BehaviorArbiter.state_config_errors(data)
		if not errors.has(str(case[0])):
			return _fail("expected %s in %s" % [case[0], str(errors)])
	return _pass()


static func _t_bad_exponent_scores_as_no_state_effect() -> Dictionary:
	var data: Dictionary = _data()
	var movement: Dictionary = ((data["combat"] as Dictionary)["movement"] as Dictionary).duplicate(true)
	var no_table: Dictionary = movement.duplicate(true)
	no_table.erase("felt_state")
	var cfg: Dictionary = _actor_cfg(data)
	var actor: Dictionary = _echo("echo_exp", "onyamesu", 10, 0)
	var ctx: Dictionary = {"actor": actor, "all_actors": [_enemy("enemy_exp")], "t": 1}
	var neutral: BehaviorArbiter = BehaviorArbiter.new(cfg, no_table)
	var shipped: BehaviorArbiter = BehaviorArbiter.new(cfg, movement)
	for bad: Variant in [0.5, 4.5, INF, NAN]:
		var bad_cfg: Dictionary = cfg.duplicate(true)
		bad_cfg["afraid_curve_exponent"] = bad
		var arbiter: BehaviorArbiter = BehaviorArbiter.new(bad_cfg, movement)
		for action_type: String in ["melee_attack", "protect_ally", "actor.guard", "actor.idle", "actor.move"]:
			var got: float = arbiter._score(action_type, actor, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3)
			var want: float = neutral._score(action_type, actor, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3)
			if not is_finite(got) or got != want:
				return _fail("%s with exponent %s scored %s, no-state score is %s" % [action_type, str(bad), str(got), str(want)])
		var intent: Dictionary = arbiter.select_intent(ctx)
		if not is_finite(float(intent.get("priority", 0.0))) or float(intent.get("state_points", 0.0)) != 0.0:
			return _fail("exponent %s leaked into the intent: %s" % [str(bad), str(intent)])
	var moved: float = shipped._score("actor.guard", actor, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3)
	if moved == neutral._score("actor.guard", actor, {}, {}, "nascent", {}, {}, 0.1, 0.0, 0.3, 0.3):
		return _fail("the shipped exponent must still change the score of an afraid actor")
	return _pass()


static func _t_arbiter_rejects_bad_afraid_curve_exponent() -> Dictionary:
	var data: Dictionary = _data()
	var movement: Dictionary = (data["combat"] as Dictionary)["movement"] as Dictionary
	if not bool(BehaviorArbiter.new(_actor_cfg(data), movement)._validate_spatial_config()["valid"]):
		return _fail("the shipped exponent was rejected")
	if not bool(BehaviorArbiter.new({}, movement)._validate_spatial_config()["valid"]):
		return _fail("the default exponent was rejected")
	for bad: Variant in [0.5, 4.5, "x", INF, NAN]:
		var cfg: Dictionary = _actor_cfg(data).duplicate(true)
		cfg["afraid_curve_exponent"] = bad
		var verdict: Dictionary = BehaviorArbiter.new(cfg, movement)._validate_spatial_config()
		if bool(verdict["valid"]) or str(verdict["reason"]) != "invalid_afraid_curve_exponent":
			return _fail("%s must fail with invalid_afraid_curve_exponent: %s" % [str(bad), str(verdict)])
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
