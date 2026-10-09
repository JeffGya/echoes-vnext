# res://tests/StopShortServiceTests.gd
# StopShortService (pure), data.actor.stop_short, StopShortText.
# Parties come from the production path (EchoFactory.generate, EmotionService.init_echo, VectorService.init_vectors).

class_name StopShortServiceTests
extends RefCounted

const _TESTS: Array = [
	"block_loads_with_spec_values",
	"disabled_returns_no_stop",
	"gate_g2_purpose_excluded",
	"gate_g3_urgency_critical",
	"gate_g4_hostile_in_reach",
	"gate_g5_streak",
	"gate_g6_no_cause",
	"gate_g7_no_benefit",
	"gate_order_is_g1_to_g7",
	"fear_strength_boundaries",
	"fear_base_floor_blend",
	"morale_strength_boundaries",
	"min_cause_strength_applies",
	"identity_affinity_by_family",
	"identity_affinity_by_vector",
	"identity_scales_with_standing",
	"cause_registry_rows",
	"benefit_guard_predicate",
	"benefit_observe_predicate",
	"benefit_hold_predicate",
	"benefit_choice_and_order",
	"bias_is_weight_times_strength",
	"determinism_100_calls",
	"production_party_context",
	"text_bank_every_key_resolves",
	"text_bank_no_ids_or_code_words",
	"text_bank_missing_key_fails",
	"text_bank_pronouns_only_in_flagged_lines",
	"fear_affinity_guard_only",
	"fear_stop_vetoed_when_guard_illegal",
	"tie_break_hold_first_with_ally_near",
]


static func register(runner: CoreTestRunner) -> void:
	for name: String in _TESTS:
		runner.register_test("stop_short/%s" % name, Callable(StopShortServiceTests, "_t_%s" % name))


static func _balance() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	return cs.get_balance()


static func _cfg(enabled: bool = true) -> Dictionary:
	var cfg: Dictionary = ((_balance().get("data", {}) as Dictionary).get("actor", {}) as Dictionary).get("stop_short", {}) as Dictionary
	cfg = cfg.duplicate(true)
	cfg["enabled"] = enabled
	return cfg


## A legal base case: fear 30 (strength 0.4), hostile 3 cells away, capacity 2.
static func _ctx(over: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {
		"actor_type": "echo", "purpose": "engage", "urgency": 0.5,
		"fear": 30, "fear_base": 0, "morale": 60,
		"calling_family": "", "dominant_vector": "", "judgment": 0.0,
		"capacity": 2, "def": 5, "guard_state": false,
		"stop_in_hostile_reach": false, "previous_stop_short": false,
		"stop_cell_hostile_control": false,
		"cohesion_stop": 0.0, "cohesion_full": 0.0,
		"hostiles": [{ "id": "enemy_a", "dist": 3, "marked": false }],
	}
	for k: String in over.keys():
		ctx[k] = over[k]
	return ctx


static func _res(errs: Array) -> Dictionary:
	return { "ok": errs.is_empty(), "error": "; ".join(errs) }


static func _eq(errs: Array, label: String, got: Variant, want: Variant) -> void:
	if got != want:
		errs.append("%s: got %s, want %s" % [label, str(got), str(want)])


static func _near(errs: Array, label: String, got: float, want: float) -> void:
	if absf(got - want) > 0.0001:
		errs.append("%s: got %s, want %s" % [label, str(got), str(want)])


static func _veto_of(ctx: Dictionary, cfg: Dictionary) -> String:
	return str(StopShortService.evaluate(ctx, cfg).get("veto", "?"))


static func _t_block_loads_with_spec_values() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg(false)
	_eq(errs, "block present", cfg.is_empty(), false)
	var raw: Dictionary = ((_balance().get("data", {}) as Dictionary).get("actor", {}) as Dictionary).get("stop_short", {}) as Dictionary
	_eq(errs, "enabled", raw.get("enabled", true), false)
	_near(errs, "stop_short_weight", float(cfg["stop_short_weight"]), 6.0)
	_near(errs, "min_cause_strength", float(cfg["min_cause_strength"]), 0.15)
	_eq(errs, "fear floor", int(cfg["fear"]["floor"]), 20)
	_eq(errs, "fear full", int(cfg["fear"]["full"]), 45)
	_near(errs, "morale shaken", float(cfg["morale_strength"]["shaken"]), 0.0)
	_near(errs, "morale broken", float(cfg["morale_strength"]["broken"]), 0.8)
	var fam: Dictionary = cfg["identity"]["family_affinity"]
	_near(errs, "anchor guard", float(fam["anchor"]["guard"]), 0.8)
	_near(errs, "anchor hold", float(fam["anchor"]["hold"]), 0.8)
	_near(errs, "anchor observe", float(fam["anchor"]["observe"]), 0.2)
	_near(errs, "sight observe", float(fam["sight"]["observe"]), 0.8)
	_near(errs, "sight guard", float(fam["sight"]["guard"]), 0.3)
	_near(errs, "sight hold", float(fam["sight"]["hold"]), 0.3)
	var vec: Dictionary = cfg["identity"]["vector_affinity"]
	_near(errs, "skeptic observe", float(vec["skeptic"]["observe"]), 0.6)
	_near(errs, "seeker observe", float(vec["seeker"]["observe"]), 0.6)
	_near(errs, "pillar hold", float(vec["pillar"]["hold"]), 0.6)
	_near(errs, "devoted hold", float(vec["devoted"]["hold"]), 0.5)
	_near(errs, "protector guard", float(vec["protector"]["guard"]), 0.5)
	_near(errs, "judgment base", float(cfg["identity"]["judgment_base"]), 0.5)
	_eq(errs, "observe has no range key", (cfg["observe"] as Dictionary).has("range"), false)
	_eq(errs, "observe marked_strength", int(cfg["observe"]["marked_strength"]), 5)
	_eq(errs, "observe mark_rounds", int(cfg["observe"]["mark_rounds"]), 1)
	_near(errs, "hold min cohesion", float(cfg["hold"]["min_cohesion"]), 0.5)
	_eq(errs, "guard extra", int(cfg["guard"]["hostile_reach_extra"]), 1)
	return _res(errs)


static func _t_disabled_returns_no_stop() -> Dictionary:
	# The disabled and non-Echo early returns live in StopShortContextService.screen
	var errs: Array = []
	_eq(errs, "shipped data is off", bool(_cfg(false).get("enabled", true)), false)
	_eq(errs, "legal base case stops", StopShortService.evaluate(_ctx(), _cfg())["stop"], true)
	return _res(errs)


static func _t_gate_g2_purpose_excluded() -> Dictionary:
	var errs: Array = []
	for purpose: String in ["withdraw", "read", "hold"]:
		_eq(errs, purpose, _veto_of(_ctx({ "purpose": purpose }), _cfg()), "purpose_excluded")
	_eq(errs, "escort allowed", _veto_of(_ctx({ "purpose": "escort" }), _cfg()), "")
	return _res(errs)


static func _t_gate_g3_urgency_critical() -> Dictionary:
	var errs: Array = []
	_eq(errs, "1.0", _veto_of(_ctx({ "urgency": 1.0 }), _cfg()), "urgency_critical")
	_eq(errs, "0.99", _veto_of(_ctx({ "urgency": 0.99 }), _cfg()), "")
	return _res(errs)


static func _t_gate_g4_hostile_in_reach() -> Dictionary:
	var errs: Array = []
	_eq(errs, "in reach", _veto_of(_ctx({ "stop_in_hostile_reach": true }), _cfg()), "hostile_in_reach")
	return _res(errs)


static func _t_gate_g5_streak() -> Dictionary:
	var errs: Array = []
	_eq(errs, "streak", _veto_of(_ctx({ "previous_stop_short": true }), _cfg()), "streak")
	return _res(errs)


static func _t_gate_g6_no_cause() -> Dictionary:
	var errs: Array = []
	_eq(errs, "calm steady echo", _veto_of(_ctx({ "fear": 0, "morale": 60 }), _cfg()), "no_cause")
	_eq(errs, "shaken morale alone", _veto_of(_ctx({ "fear": 0, "morale": 30 }), _cfg()), "no_cause")
	var edge: Dictionary = _ctx({ "fear": 0, "calling_family": "edge", "dominant_vector": "vanguard" })
	_eq(errs, "edge identity", _veto_of(edge, _cfg()), "no_cause")
	# A cause exists only for observe, and observe is not legal: the cause has no legal benefit.
	var only_guard_benefit: Dictionary = _ctx({
		"fear": 0, "dominant_vector": "skeptic", "judgment": 1.0,
		"hostiles": [{ "id": "enemy_a", "dist": 3, "marked": true }],
	})
	_eq(errs, "cause for a missing benefit", _veto_of(only_guard_benefit, _cfg()), "no_benefit")
	return _res(errs)


static func _t_gate_g7_no_benefit() -> Dictionary:
	var errs: Array = []
	var far: Dictionary = _ctx({ "hostiles": [{ "id": "enemy_a", "dist": 8, "marked": false }] })
	_eq(errs, "no hostile near, no allies", _veto_of(far, _cfg()), "no_benefit")
	_eq(errs, "no hostiles at all", _veto_of(_ctx({ "hostiles": [] }), _cfg()), "no_benefit")
	return _res(errs)


static func _t_gate_order_is_g1_to_g7() -> Dictionary:
	var errs: Array = []
	var all_bad: Dictionary = _ctx({
		"purpose": "withdraw", "urgency": 1.0,
		"stop_in_hostile_reach": true, "previous_stop_short": true, "fear": 0, "hostiles": [],
	})
	var order: Array = [
		["purpose", "engage", "urgency_critical"],
		["urgency", 0.5, "hostile_in_reach"],
		["stop_in_hostile_reach", false, "streak"],
		["previous_stop_short", false, "no_cause"],
		["fear", 30, "no_benefit"],
	]
	_eq(errs, "first", _veto_of(all_bad, _cfg()), "purpose_excluded")
	for step_v: Variant in order:
		var step: Array = step_v as Array
		all_bad[str(step[0])] = step[1]
		_eq(errs, "after fixing " + str(step[0]), _veto_of(all_bad, _cfg()), str(step[2]))
	return _res(errs)


static func _t_fear_strength_boundaries() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	_near(errs, "fear 19", StopShortService.fear_strength({ "fear": 19 }, cfg), 0.0)
	_near(errs, "fear 20", StopShortService.fear_strength({ "fear": 20 }, cfg), 0.0)
	_near(errs, "fear 32", StopShortService.fear_strength({ "fear": 32 }, cfg), 12.0 / 25.0)
	_near(errs, "fear 45", StopShortService.fear_strength({ "fear": 45 }, cfg), 1.0)
	_near(errs, "fear 90 clamps", StopShortService.fear_strength({ "fear": 90 }, cfg), 1.0)
	var at_19: Dictionary = StopShortService.cause_strength("fear", "guard", _ctx({ "fear": 19 }), cfg)
	_near(errs, "cause fear 19", float(at_19["strength"]), 0.0)
	var at_45: Dictionary = StopShortService.cause_strength("fear", "guard", _ctx({ "fear": 45 }), cfg)
	_near(errs, "cause fear 45", float(at_45["strength"]), 1.0)
	_eq(errs, "fear code", at_45["code"], "fear")
	_eq(errs, "fear source", at_45["source"], "emotion")
	return _res(errs)


static func _t_fear_base_floor_blend() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	_near(errs, "fear_base above fear", StopShortService.fear_strength({ "fear": 0, "fear_base": 45 }, cfg), 1.0)
	_near(errs, "fear above fear_base", StopShortService.fear_strength({ "fear": 45, "fear_base": 0 }, cfg), 1.0)
	_near(errs, "both low", StopShortService.fear_strength({ "fear": 10, "fear_base": 15 }, cfg), 0.0)
	return _res(errs)


static func _t_morale_strength_boundaries() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	_near(errs, "morale 0", StopShortService.morale_strength({ "morale": 0 }, cfg), 0.8)
	_near(errs, "morale 24 broken", StopShortService.morale_strength({ "morale": 24 }, cfg), 0.8)
	_near(errs, "morale 25 shaken is 0", StopShortService.morale_strength({ "morale": 25 }, cfg), 0.0)
	_near(errs, "morale 49 shaken is 0", StopShortService.morale_strength({ "morale": 49 }, cfg), 0.0)
	_near(errs, "morale 50 steady", StopShortService.morale_strength({ "morale": 50 }, cfg), 0.0)
	_near(errs, "morale 100", StopShortService.morale_strength({ "morale": 100 }, cfg), 0.0)
	var broken: Dictionary = StopShortService.cause_strength("fear", "guard", _ctx({ "fear": 0, "morale": 24 }), cfg)
	_near(errs, "cause broken", float(broken["strength"]), 0.8)
	_eq(errs, "morale code", broken["code"], "morale")
	var shaken: Dictionary = StopShortService.cause_strength("fear", "guard", _ctx({ "fear": 0, "morale": 25 }), cfg)
	_near(errs, "cause shaken", float(shaken["strength"]), 0.0)
	var both: Dictionary = StopShortService.cause_strength("fear", "guard", _ctx({ "fear": 45, "morale": 10 }), cfg)
	_near(errs, "larger of fear and morale", float(both["strength"]), 1.0)
	_eq(errs, "fear wins code", both["code"], "fear")
	return _res(errs)


static func _t_min_cause_strength_applies() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	_eq(errs, "fear 23", _veto_of(_ctx({ "fear": 23 }), cfg), "no_cause")
	_eq(errs, "fear 24", _veto_of(_ctx({ "fear": 24 }), cfg), "")
	return _res(errs)


static func _t_identity_affinity_by_family() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var table: Dictionary = {
		"anchor": { "guard": 0.8, "hold": 0.8, "observe": 0.2 },
		"sight": { "guard": 0.3, "hold": 0.3, "observe": 0.8 },
		"edge": { "guard": 0.0, "hold": 0.0, "observe": 0.0 },
	}
	for family: String in table.keys():
		for benefit: String in table[family].keys():
			var got: Dictionary = StopShortService.cause_strength(
				"identity", benefit, _ctx({ "calling_family": family, "judgment": 1.0 }), cfg)
			_near(errs, "%s/%s" % [family, benefit], float(got["strength"]), float(table[family][benefit]))
	var anchor: Dictionary = StopShortService.cause_strength("identity", "guard", _ctx({ "calling_family": "anchor" }), cfg)
	_eq(errs, "family source", anchor["source"], "calling")
	_eq(errs, "family code", anchor["code"], "calling_weight")
	_near(errs, "no family", float(StopShortService.cause_strength("identity", "guard", _ctx(), cfg)["strength"]), 0.0)
	_near(errs, "unknown family", float(StopShortService.cause_strength("identity", "guard", _ctx({ "calling_family": "x" }), cfg)["strength"]), 0.0)
	return _res(errs)


static func _t_identity_affinity_by_vector() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var table: Array = [
		["skeptic", "observe", 0.6], ["seeker", "observe", 0.6], ["pillar", "hold", 0.6],
		["devoted", "hold", 0.5], ["protector", "guard", 0.5],
		["vanguard", "guard", 0.0], ["nurturer", "hold", 0.0], ["skeptic", "guard", 0.0],
	]
	for row_v: Variant in table:
		var row: Array = row_v as Array
		var got: Dictionary = StopShortService.cause_strength(
			"identity", str(row[1]), _ctx({ "dominant_vector": str(row[0]), "judgment": 1.0 }), cfg)
		_near(errs, "%s/%s" % [str(row[0]), str(row[1])], float(got["strength"]), float(row[2]))
	var vec: Dictionary = StopShortService.cause_strength("identity", "observe", _ctx({ "dominant_vector": "skeptic" }), cfg)
	_eq(errs, "vector source", vec["source"], "vector")
	_eq(errs, "vector code", vec["code"], "values")
	var both: Dictionary = StopShortService.cause_strength(
		"identity", "observe", _ctx({ "calling_family": "sight", "dominant_vector": "skeptic", "judgment": 1.0 }), cfg)
	_near(errs, "larger of family and vector", float(both["strength"]), 0.8)
	_eq(errs, "family wins the larger", both["source"], "calling")
	return _res(errs)


static func _t_identity_scales_with_standing() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var low: Dictionary = StopShortService.cause_strength("identity", "guard", _ctx({ "calling_family": "anchor", "judgment": 0.0 }), cfg)
	var high: Dictionary = StopShortService.cause_strength("identity", "guard", _ctx({ "calling_family": "anchor", "judgment": 1.0 }), cfg)
	_near(errs, "judgment 0 is half", float(low["strength"]), 0.4)
	_near(errs, "judgment 1 is full", float(high["strength"]), 0.8)
	# Standing 1 (judgment 0) anchor stays above min_cause_strength; it can still stop.
	var anchor_ctx: Dictionary = _ctx({ "fear": 0, "calling_family": "anchor", "judgment": 0.0 })
	_eq(errs, "identity alone can stop", StopShortService.evaluate(anchor_ctx, cfg)["stop"], true)
	_eq(errs, "identity cause id", StopShortService.evaluate(anchor_ctx, cfg)["cause_id"], "identity")
	return _res(errs)


static func _t_cause_registry_rows() -> Dictionary:
	var errs: Array = []
	var ids: Array = []
	for row_v: Variant in StopShortService.CAUSE_ROWS:
		var row: Dictionary = row_v as Dictionary
		ids.append(str(row["id"]))
	_eq(errs, "registry rows", ids, ["fear", "identity"])
	for reserved: String in ["directive", "guidance", "bond", "vow"]:
		_eq(errs, "reserved has no row: " + reserved, ids.has(reserved), false)
		var got: Dictionary = StopShortService.cause_strength(reserved, "guard", _ctx({ "fear": 90 }), _cfg())
		_near(errs, "reserved has no logic: " + reserved, float(got["strength"]), 0.0)
	_eq(errs, "bias key", StopShortService.bias_key("fear"), "stop_short.fear")
	for code_source: Array in [["emotion", "fear"], ["emotion", "morale"], ["calling", "calling_weight"], ["vector", "values"]]:
		_eq(errs, "trace source known: " + str(code_source[0]), DecisionTrace.SOURCES.has(str(code_source[0])), true)
		_eq(errs, "text clause exists: " + str(code_source[1]), StopShortText.has_key(["cause_clause", str(code_source[1])]), true)
	return _res(errs)


static func _t_benefit_guard_predicate() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var ok_ctx: Dictionary = _ctx({ "hostiles": [{ "id": "e", "dist": 3, "marked": true }] })
	_eq(errs, "hostile at capacity + 1", StopShortService.benefit_plan("guard", ok_ctx, cfg).is_empty(), false)
	var far: Dictionary = _ctx({ "hostiles": [{ "id": "e", "dist": 4, "marked": true }] })
	_eq(errs, "hostile at capacity + 2", StopShortService.benefit_plan("guard", far, cfg).is_empty(), true)
	_eq(errs, "def 0", StopShortService.benefit_plan("guard", _ctx({ "def": 0 }), cfg).is_empty(), true)
	_eq(errs, "def 1", StopShortService.benefit_plan("guard", _ctx({ "def": 1 }), cfg).is_empty(), false)
	_eq(errs, "guard_state already set", StopShortService.benefit_plan("guard", _ctx({ "guard_state": true }), cfg).is_empty(), true)
	_eq(errs, "capacity 4 reaches 5", StopShortService.benefit_plan("guard", _ctx({
		"capacity": 4, "hostiles": [{ "id": "e", "dist": 5, "marked": true }] }), cfg).is_empty(), false)
	var plan: Dictionary = StopShortService.benefit_plan("guard", _ctx(), cfg)
	_eq(errs, "guard action", plan["action_type"], "actor.guard")
	_eq(errs, "guard has no target", plan["target_id"], "")
	return _res(errs)


static func _t_benefit_observe_predicate() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var plan: Dictionary = StopShortService.benefit_plan("observe", _ctx(), cfg)
	_eq(errs, "observe action", plan.get("action_type", ""), "actor.observe")
	_eq(errs, "observe target", plan.get("target_id", ""), "enemy_a")
	_eq(errs, "dist 4 too far", StopShortService.benefit_plan("observe", _ctx({
		"hostiles": [{ "id": "e", "dist": 4, "marked": false }] }), cfg).is_empty(), true)
	_eq(errs, "marked hostile", StopShortService.benefit_plan("observe", _ctx({
		"hostiles": [{ "id": "e", "dist": 2, "marked": true }] }), cfg).is_empty(), true)
	_eq(errs, "control edge on last step", StopShortService.benefit_plan("observe", _ctx({
		"stop_cell_hostile_control": true }), cfg).is_empty(), true)
	var two: Dictionary = StopShortService.benefit_plan("observe", _ctx({ "hostiles": [
		{ "id": "enemy_c", "dist": 3, "marked": false },
		{ "id": "enemy_b", "dist": 3, "marked": false },
		{ "id": "enemy_d", "dist": 2, "marked": true },
		{ "id": "enemy_e", "dist": 2, "marked": false },
	] }), cfg)
	_eq(errs, "nearest unmarked wins", two["target_id"], "enemy_e")
	var tie: Dictionary = StopShortService.benefit_plan("observe", _ctx({ "hostiles": [
		{ "id": "enemy_c", "dist": 3, "marked": false },
		{ "id": "enemy_b", "dist": 3, "marked": false },
	] }), cfg)
	_eq(errs, "tie goes to lowest id", tie["target_id"], "enemy_b")
	return _res(errs)


static func _t_benefit_hold_predicate() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	_eq(errs, "0.5 vs 0.0", StopShortService.benefit_plan("hold", _ctx({ "cohesion_stop": 0.5, "cohesion_full": 0.0 }), cfg).is_empty(), false)
	_eq(errs, "below 0.5", StopShortService.benefit_plan("hold", _ctx({ "cohesion_stop": 0.49, "cohesion_full": 0.0 }), cfg).is_empty(), true)
	_eq(errs, "not better than full route", StopShortService.benefit_plan("hold", _ctx({ "cohesion_stop": 0.6, "cohesion_full": 0.6 }), cfg).is_empty(), true)
	_eq(errs, "full route worse", StopShortService.benefit_plan("hold", _ctx({ "cohesion_stop": 0.6, "cohesion_full": 0.2 }), cfg).is_empty(), false)
	_eq(errs, "no allies", StopShortService.benefit_plan("hold", _ctx(), cfg).is_empty(), true)
	var plan: Dictionary = StopShortService.benefit_plan("hold", _ctx({ "cohesion_stop": 0.6 }), cfg)
	_eq(errs, "hold action is guard", plan["action_type"], "actor.guard")
	_eq(errs, "unknown benefit", StopShortService.benefit_plan("range", _ctx(), cfg).is_empty(), true)
	return _res(errs)


static func _t_benefit_choice_and_order() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var s1: Dictionary = StopShortService.evaluate(_ctx({ "fear": 30 }), cfg)
	_eq(errs, "S1 stop", s1["stop"], true)
	_eq(errs, "S1 guard", s1["benefit_id"], "guard")
	_eq(errs, "S1 plan", s1["benefit_plan"]["action_type"], "actor.guard")
	_eq(errs, "S1 cause", s1["cause_id"], "fear")
	_eq(errs, "S1 source", s1["cause_source"], "emotion")
	_eq(errs, "S1 code", s1["cause_code"], "fear")
	var sight: Dictionary = StopShortService.evaluate(_ctx({ "fear": 0, "calling_family": "sight", "judgment": 1.0 }), cfg)
	_eq(errs, "S3 benefit", sight["benefit_id"], "observe")
	_eq(errs, "S3 plan", sight["benefit_plan"]["action_type"], "actor.observe")
	_eq(errs, "S3 target", sight["benefit_plan"]["target_id"], "enemy_a")
	_eq(errs, "S3 cause", sight["cause_id"], "identity")
	_eq(errs, "S3 source", sight["cause_source"], "calling")
	var anchor_hold: Dictionary = StopShortService.evaluate(_ctx({
		"fear": 0, "calling_family": "anchor", "judgment": 1.0,
		"hostiles": [{ "id": "enemy_a", "dist": 9, "marked": false }],
		"cohesion_stop": 0.8, "cohesion_full": 0.2 }), cfg)
	_eq(errs, "S3b benefit", anchor_hold["benefit_id"], "hold")
	_eq(errs, "S3b cause", anchor_hold["cause_id"], "identity")
	_eq(errs, "S3c edge never stops for identity", StopShortService.evaluate(_ctx({
		"fear": 0, "calling_family": "edge", "judgment": 1.0 }), cfg)["stop"], false)
	var morale_only: Dictionary = StopShortService.evaluate(_ctx({ "fear": 0, "morale": 10 }), cfg)
	_eq(errs, "broken morale stops", morale_only["stop"], true)
	_eq(errs, "broken morale code", morale_only["cause_code"], "morale")
	var strongest: Dictionary = StopShortService.evaluate(_ctx({
		"fear": 45, "calling_family": "sight", "judgment": 1.0 }), cfg)
	_eq(errs, "strongest cause wins", strongest["cause_id"], "fear")
	_eq(errs, "S2 control: steady and calm moves on", StopShortService.evaluate(_ctx({ "fear": 0, "morale": 60 }), cfg)["stop"], false)
	return _res(errs)


static func _t_bias_is_weight_times_strength() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var out: Dictionary = StopShortService.evaluate(_ctx({ "fear": 45 }), cfg)
	_near(errs, "weight 6 x 1.0", float(out["bias"]), 6.0)
	cfg["stop_short_weight"] = 7.5
	var out2: Dictionary = StopShortService.evaluate(_ctx({ "fear": 30 }), cfg)
	_near(errs, "weight 7.5 x 0.4", float(out2["bias"]), 3.0)
	_near(errs, "strength", float(out2["strength"]), 0.4)
	return _res(errs)


static func _t_determinism_100_calls() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var ctx: Dictionary = _ctx({ "calling_family": "anchor", "dominant_vector": "pillar", "judgment": 0.37, "cohesion_stop": 0.7 })
	var before: String = JSON.stringify(ctx)
	var first: String = JSON.stringify(StopShortService.evaluate(ctx, cfg))
	for i in range(100):
		if JSON.stringify(StopShortService.evaluate(ctx, cfg)) != first:
			errs.append("call %d differed" % i)
			break
	_eq(errs, "ctx not mutated", JSON.stringify(ctx), before)
	return _res(errs)


static func _t_production_party_context() -> Dictionary:
	var errs: Array = []
	var bal: Dictionary = _balance()
	var data: Dictionary = bal.get("data", {}) as Dictionary
	var summ_cfg: Dictionary = data.get("summoning", {}) as Dictionary
	var expr_cfg: Dictionary = data.get("maturity_expression", {}) as Dictionary
	var vec_cfg: Dictionary = data.get("vectors", {}) as Dictionary
	var calling_defs: Dictionary = (data.get("calling", {}) as Dictionary).get("definitions", {}) as Dictionary
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var cfg: Dictionary = _cfg()
	var legal: int = 0
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate("stop_short_party", "echo.%d" % i, i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		EmotionService.init_echo(echo, logger, 0)
		VectorService.init_vectors(echo, vec_cfg, logger, 0)
		var emo: Dictionary = echo["emotion"] as Dictionary
		var family: String = str((calling_defs.get(str(echo.get("calling_origin", "")), {}) as Dictionary).get("family", ""))
		var ctx: Dictionary = _ctx({
			"fear": int(emo["fear_current"]), "fear_base": int(emo["fear_base"]),
			"morale": int(emo["morale_current"]), "calling_family": family,
			"dominant_vector": str(echo.get("dominant_vector", "")), "judgment": 0.0,
		})
		var out: Dictionary = StopShortService.evaluate(ctx, cfg)
		var again: Dictionary = StopShortService.evaluate(ctx, cfg)
		_eq(errs, "echo %d repeatable" % i, JSON.stringify(out), JSON.stringify(again))
		if bool(out["stop"]):
			legal += 1
			_eq(errs, "echo %d has a benefit" % i, StopShortService.BENEFITS.has(str(out["benefit_id"])), true)
		else:
			_eq(errs, "echo %d veto is known" % i, [
				"no_cause", "no_benefit"].has(str(out["veto"])), true)
		_eq(errs, "echo %d birth morale never broken" % i, int(emo["morale_current"]) >= 25, true)
	return _res(errs)


static func _t_text_bank_every_key_resolves() -> Dictionary:
	var errs: Array = []
	for benefit: String in ["guard", "observe", "hold", "return_route"]:
		_eq(errs, "row_word " + benefit, StopShortText.has_key(["row_word", benefit]), true)
		_eq(errs, "plain " + benefit, StopShortText.has_key(["reason_line", benefit, "plain"]), true)
		_eq(errs, "row_word text " + benefit, StopShortText.row_word(benefit).is_empty(), false)
		_eq(errs, "reason text " + benefit, StopShortText.reason_line(benefit).is_empty(), false)
	for code: String in ["fear", "morale", "calling_weight", "values"]:
		_eq(errs, "clause " + code, StopShortText.has_key(["cause_clause", code]), true)
		_eq(errs, "clause text " + code, StopShortText.cause_clause(code).is_empty(), false)
	_eq(errs, "first person", StopShortText.reason_line("guard").begins_with("I "), true)
	_eq(errs, "morale clause is not the fear clause", StopShortText.cause_clause("morale") != StopShortText.cause_clause("fear"), true)
	_eq(errs, "morale line does not blame the ground", StopShortText.reason_line("guard", "morale").to_lower().contains("ground"), false)
	_eq(errs, "guard with fear uses its own line", StopShortText.reason_line("guard", "fear").length() > StopShortText.reason_line("guard").length(), true)
	_eq(errs, "code without own line uses plain", StopShortText.reason_line("hold", "fear"), StopShortText.reason_line("hold"))
	var line_count: int = StopShortText.all_lines().size()
	_eq(errs, "lines found", line_count > 0, true)
	return _res(errs)


static func _t_text_bank_no_ids_or_code_words() -> Dictionary:
	var errs: Array = []
	var banned: Array = ["actor", "echo_", "enemy_", "stop_short", "_", "benefit", "cause", "trace",
		"guard_state", "calling_weight", "morale_", "fear_", "id:", "null"]
	for line_v: Variant in StopShortText.all_lines():
		var line: String = str(line_v)
		var shown: String = line
		for word_v: Variant in banned:
			if shown.to_lower().contains(str(word_v)):
				errs.append("'%s' contains '%s'" % [shown, str(word_v)])
		for ch: String in shown:
			if ch >= "0" and ch <= "9":
				errs.append("'%s' contains a digit" % shown)
				break
		if shown.contains("{") or shown.contains("}"):
			errs.append("'%s' has a token" % shown)
	return _res(errs)


static func _t_text_bank_missing_key_fails() -> Dictionary:
	var errs: Array = []
	_eq(errs, "unknown benefit row word", StopShortText.has_key(["row_word", "range"]), false)
	_eq(errs, "unknown section", StopShortText.has_key(["nope", "guard"]), false)
	_eq(errs, "unknown clause", StopShortText.has_key(["cause_clause", "directive_order"]), false)
	_eq(errs, "lookup ok flag", StopShortText.lookup(["row_word", "range"])["ok"], false)
	_eq(errs, "a dictionary is not a line", StopShortText.has_key(["row_word"]), false)
	_eq(errs, "note keys are not lines", StopShortText.all_lines().has(StopShortText.lookup(["_status"])["text"]), false)
	return _res(errs)


static func _t_text_bank_pronouns_only_in_flagged_lines() -> Dictionary:
	var errs: Array = []
	var flagged: Array = StopShortText.about_other_lines()
	var words: Array = ["he", "she", "him", "her", "his", "hers", "himself", "herself"]
	for line_v: Variant in StopShortText.all_lines():
		var line: String = str(line_v)
		if flagged.has(line):
			continue
		var cleaned: String = line.to_lower()
		for ch: String in [".", ",", "!", "?", "'", "\""]:
			cleaned = cleaned.replace(ch, " ")
		for token: String in cleaned.split(" ", false):
			if words.has(token):
				errs.append("'%s' has the pronoun '%s'" % [line, token])
	return _res(errs)


static func _t_fear_affinity_guard_only() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	for cause_ctx: Dictionary in [_ctx({ "fear": 45 }), _ctx({ "fear": 0, "morale": 10 })]:
		_near(errs, "guard", float(StopShortService.cause_strength("fear", "guard", cause_ctx, cfg)["strength"]), 1.0 if int(cause_ctx["fear"]) == 45 else 0.8)
		_near(errs, "observe", float(StopShortService.cause_strength("fear", "observe", cause_ctx, cfg)["strength"]), 0.0)
		_near(errs, "hold", float(StopShortService.cause_strength("fear", "hold", cause_ctx, cfg)["strength"]), 0.0)
	return _res(errs)


## Fear or broken morale stops only for guard. When guard is not legal the veto is no_benefit
## (a cause exists, its benefit is not legal), even when observe or hold would be legal.
static func _t_fear_stop_vetoed_when_guard_illegal() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var observe_legal: Dictionary = { "def": 0, "cohesion_stop": 0.8, "cohesion_full": 0.1 }
	_eq(errs, "fear, guard illegal (def 0)", _veto_of(_ctx(observe_legal), cfg), "no_benefit")
	_eq(errs, "broken morale, guard already set", _veto_of(_ctx({ "fear": 0, "morale": 5, "guard_state": true }), cfg), "no_benefit")
	_eq(errs, "broken morale, hostile too far", _veto_of(_ctx({
		"fear": 0, "morale": 5, "hostiles": [{ "id": "e", "dist": 4, "marked": false }] }), cfg), "no_benefit")
	_eq(errs, "broken morale, guard legal", _veto_of(_ctx({ "fear": 0, "morale": 5 }), cfg), "")
	return _res(errs)


## Equal strength gives Hold first when the Hold predicate is true (ally near), else Guard.
static func _t_tie_break_hold_first_with_ally_near() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = _cfg()
	var anchor: Dictionary = { "fear": 0, "calling_family": "anchor", "judgment": 1.0 }
	var ally: Dictionary = anchor.duplicate()
	ally["cohesion_stop"] = 0.8
	ally["cohesion_full"] = 0.2
	var with_ally: Dictionary = StopShortService.evaluate(_ctx(ally), cfg)
	_eq(errs, "anchor with ally near: hold", with_ally["benefit_id"], "hold")
	_eq(errs, "hold plays guard", with_ally["benefit_plan"]["action_type"], "actor.guard")
	_eq(errs, "anchor without ally: guard", StopShortService.evaluate(_ctx(anchor), cfg)["benefit_id"], "guard")
	var weak_ally: Dictionary = anchor.duplicate()
	weak_ally["cohesion_stop"] = 0.4
	_eq(errs, "ally below the Hold threshold: guard", StopShortService.evaluate(_ctx(weak_ally), cfg)["benefit_id"], "guard")
	var not_better: Dictionary = anchor.duplicate()
	not_better["cohesion_stop"] = 0.8
	not_better["cohesion_full"] = 0.8
	_eq(errs, "full route as close: guard", StopShortService.evaluate(_ctx(not_better), cfg)["benefit_id"], "guard")
	var s3b: Dictionary = StopShortService.evaluate(_ctx({
		"fear": 0, "morale": 60, "calling_family": "anchor", "judgment": 0.0,
		"cohesion_stop": 0.6, "cohesion_full": 0.1 }), cfg)
	_eq(errs, "S3b stop", s3b["stop"], true)
	_eq(errs, "S3b benefit", s3b["benefit_id"], "hold")
	_eq(errs, "S3b cause", s3b["cause_id"], "identity")
	# Ally near does not beat a stronger guard cause (fear 45 gives guard 1.0 against hold 0.8).
	var fear_wins: Dictionary = StopShortService.evaluate(_ctx({
		"fear": 45, "calling_family": "anchor", "judgment": 1.0, "cohesion_stop": 0.8, "cohesion_full": 0.2 }), cfg)
	_eq(errs, "stronger guard cause still wins", fear_wins["benefit_id"], "guard")
	return _res(errs)
