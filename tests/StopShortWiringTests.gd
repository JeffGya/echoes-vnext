# res://tests/StopShortWiringTests.gd
# StopShortService wired into the arbiter, activation, trace, snapshot and debug command.
# Shipped data keeps the feature OFF; live tests turn it on via an override on the loaded config, never in balance.json.
# Parties come from the production path (EchoFactory.generate, EmotionService.init_echo, VectorService.init_vectors).

class_name StopShortWiringTests
extends RefCounted

const Activation = preload("res://core/movement/CombatActivationService.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")

const _TESTS: Array = [
	"activation_plays_benefit_and_result_validates",
	"activation_invalid_benefit_falls_back_to_planned_then_fallback",
	"activation_without_benefit_is_unchanged",
	"observe_reach_is_three_and_not_below_skill_reach",
	"screen_off_changes_nothing",
	"screen_vetoes_with_each_reason",
	"screen_keeps_legal_and_records_bias",
	"screen_can_empty_the_list",
	"screen_skips_non_echo",
	"debug_stop_short_default_and_on",
	"debug_stop_short_off_overrides_balance",
	"debug_stop_short_mid_fight_waits_for_next_encounter",
	"debug_stop_short_not_saved_and_bad_input",
	"debug_stop_short_status_line",
	"screen_enemy_conservative_unchanged_with_full_config",
	"trace_names_benefit_and_cause_only_when_decisive",
	"trace_player_safe_fields_unchanged",
	"finish_reports_interrupted_benefit",
	"binding_halt_short_of_stop_cell_skips_benefit",
	"stop_cell_reached_still_performs_benefit",
	"absent_stop_cell_keeps_old_behaviour",
	"refuse_turn_clears_streak",
	"hostile_control_read_at_last_edge",
	"runtime_status_line",
	"observe_mark_strength_and_overwrite_rules",
	"actor_projection_marks",
	"debug_emotion_set",
	"live_guard_stop_short_contract",
	"live_off_keeps_empty_stop_short",
	"live_streak_vetoes_second_stop",
	"live_observe_vs_skill_mark",
	"ledger_observe_total_only_guard_both",
	"report_rides_on_this_calls_entry",
]

const _TAG: String = "stop_short_wiring"


static func register(runner: CoreTestRunner) -> void:
	for name: String in _TESTS:
		runner.register_test("stop_short_wiring/%s" % name, Callable(StopShortWiringTests, "_t_%s" % name))



static func _res(errs: Array) -> Dictionary:
	return { "ok": errs.is_empty(), "error": "; ".join(errs) }


static func _eq(errs: Array, label: String, got: Variant, want: Variant) -> void:
	if got != want:
		errs.append("%s: got %s, want %s" % [label, str(got), str(want)])


static func _cell(col: int, row: int) -> Dictionary:
	return { "col": col, "row": row }


static func _plan(action_type: String, target_id: String = "") -> Dictionary:
	return { "type": action_type, "target_id": target_id, "payload": {} }


static func _cfg(over: Dictionary = {}) -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var cfg: Dictionary = (((cs.get_balance().get("data", {}) as Dictionary).get("actor", {}) as Dictionary)
		.get("stop_short", {}) as Dictionary).duplicate(true)
	cfg["enabled"] = true
	for k: String in over.keys():
		cfg[k] = over[k]
	return cfg


static func _activation_ctx() -> Dictionary:
	return {
		"origin": _cell(1, 1), "authoritative_walkable": {}, "bounds": { "w": 10, "h": 10 },
		"occupancy": {}, "terrain_costs": {}, "known_hazards": [], "perceived_actors": [],
		"relationships": {}, "objective_pressure": {}, "mover_id": "mover.1",
	}


static func _intent(path: Array, planned: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"mover_id": "mover.1", "activation_id": "activation.1", "goal_id": "goal.1",
		"option_id": "option.1", "path": path, "commitment": path.size(),
		"planned_action": planned, "fallback": fallback,
	}


static func _activate(intent: Dictionary, action_ctx: Dictionary) -> Dictionary:
	return Activation.activate(_activation_ctx(), intent, { "capacity": 6 },
		{ "triggered": { "unstable": false, "binding": false, "burning": false }, "config": {} }, action_ctx)



static func _t_activation_plays_benefit_and_result_validates() -> Dictionary:
	var errs: Array = []
	var intent: Dictionary = _intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), _plan("actor.guard"))
	var out: Dictionary = _activate(intent, {
		"purpose": "engage", "positions": { "enemy.1": _cell(4, 1) },
		"stop_short_benefit": _plan("actor.guard"),
	})
	_eq(errs, "resolved is the benefit", out["resolved_action"], _plan("actor.guard"))
	_eq(errs, "planned unchanged", out["planned_action"], _plan("melee_attack", "enemy.1"))
	_eq(errs, "fallback unchanged", out["fallback"], _plan("actor.guard"))
	_eq(errs, "result validates", bool(ResultContract.validate(out)["valid"]), true)
	# Observe: valid at reach 3 even though the planned melee is not.
	var observe: Dictionary = _activate(
		_intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), _plan("actor.guard")), {
		"purpose": "engage", "ranges": Activation.ACTION_RANGES,
		"positions": { "enemy.1": _cell(5, 1) }, "stop_short_benefit": _plan("actor.observe", "enemy.1"),
	})
	_eq(errs, "observe resolved", observe["resolved_action"]["type"], "actor.observe")
	_eq(errs, "observe result validates", bool(ResultContract.validate(observe)["valid"]), true)
	_eq(errs, "stop reason is movement's", observe["stop_reason"], "reached_destination")
	return _res(errs)


static func _t_activation_invalid_benefit_falls_back_to_planned_then_fallback() -> Dictionary:
	var errs: Array = []
	var ranges: Dictionary = Activation.ACTION_RANGES
	# Benefit target out of reach 3 at the final cell; planned melee is adjacent: planned wins.
	var planned_ok: Dictionary = _activate(
		_intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), _plan("actor.guard")), {
		"purpose": "engage", "ranges": ranges,
		"positions": { "enemy.1": _cell(3, 1), "enemy.2": _cell(9, 9) },
		"stop_short_benefit": _plan("actor.observe", "enemy.2"),
	})
	_eq(errs, "falls to planned", planned_ok["resolved_action"]["type"], "melee_attack")
	var fallback: Dictionary = _activate(
		_intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), _plan("actor.guard")), {
		"purpose": "engage", "ranges": ranges,
		"positions": { "enemy.1": _cell(8, 1), "enemy.2": _cell(9, 9) },
		"stop_short_benefit": _plan("actor.observe", "enemy.2"),
	})
	_eq(errs, "falls to fallback", fallback["resolved_action"]["type"], "actor.guard")
	_eq(errs, "fallback result validates", bool(ResultContract.validate(fallback)["valid"]), true)
	var none: Dictionary = _activate(
		_intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), {}), {
		"purpose": "engage", "ranges": ranges, "positions": { "enemy.1": _cell(8, 1), "enemy.2": _cell(9, 9) },
		"stop_short_benefit": _plan("actor.observe", "enemy.2"),
	})
	_eq(errs, "no action", (none["resolved_action"] as Dictionary).is_empty(), true)
	_eq(errs, "stop reason", none["stop_reason"], "action_invalid_no_fallback")
	return _res(errs)


static func _t_activation_without_benefit_is_unchanged() -> Dictionary:
	var errs: Array = []
	var intent: Dictionary = _intent([_cell(2, 1)], _plan("melee_attack", "enemy.1"), _plan("actor.guard"))
	var base: Dictionary = _activate(intent, { "purpose": "engage", "positions": { "enemy.1": _cell(3, 1) } })
	var with_empty: Dictionary = _activate(intent, {
		"purpose": "engage", "positions": { "enemy.1": _cell(3, 1) }, "stop_short_benefit": {} })
	_eq(errs, "identical result", JSON.stringify(with_empty), JSON.stringify(base))
	_eq(errs, "planned resolved", base["resolved_action"]["type"], "melee_attack")
	return _res(errs)


static func _t_observe_reach_is_three_and_not_below_skill_reach() -> Dictionary:
	var errs: Array = []
	_eq(errs, "observe reach", Activation.reach_for("actor.observe"), 3)
	_eq(errs, "not below skill reach", Activation.reach_for("actor.observe") <= Activation.SKILL_REACH, true)
	_eq(errs, "skill mark reach", Activation.reach_for("actor.mark"), Activation.SKILL_REACH)
	_eq(errs, "constant", Activation.OBSERVE_REACH, 3)
	return _res(errs)



static func _candidate(option_id: String, purpose: String = "engage", urgency: float = 0.5) -> Dictionary:
	return {
		"_movement_route": true, "_movement_goal_id": "goal.a", "_movement_option_id": option_id,
		"_movement_path": [_cell(2, 1)],
		"_movement_goal": { "purpose": purpose, "urgency": urgency },
		"_movement_option": { "cohesion": 0.0, "hostile_control_sources": [] },
		"_score_bias": {},
	}


static func _style_of(option_id: String, goal_id: String) -> String:
	var prefix: String = "option.%s." % goal_id.trim_prefix("goal.")
	if not option_id.begins_with(prefix):
		return ""
	return option_id.trim_prefix(prefix).get_slice(".", 0)


static func _actor(over: Dictionary = {}) -> Dictionary:
	var actor: Dictionary = {
		"id": "echo_0001", "actor_type": "echo", "faction": "echo", "fear": 45, "fear_base": 0, "morale": 60,
		"dominant_vector": "", "stats": { "def": 5 }, "guard_state": false,
	}
	for k: String in over.keys():
		actor[k] = over[k]
	return actor


static func _hostiles(dist_col: int) -> Array:
	return [{ "id": "enemy_1", "faction": "enemy", "grid_pos": _cell(dist_col, 1), "is_dead": false }]


static func _run_screen(candidates: Array, actor: Dictionary, hostile_col: int, cfg: Dictionary) -> Array:
	return StopShortContextService.screen(
		candidates, actor, _hostiles(hostile_col), { "calling_family": "", "judgment": 0.3 },
		{ "relationships": { "enemy_1": "hostile" } }, [], 2, Callable(StopShortWiringTests, "_style_of"), cfg)


static func _t_screen_off_changes_nothing() -> Dictionary:
	var errs: Array = []
	var cands: Array = [_candidate("option.a.conservative"), _candidate("option.a.direct")]
	var before: String = JSON.stringify(cands)
	var vetoes: Array = _run_screen(cands, _actor(), 5, _cfg({ "enabled": false }))
	_eq(errs, "no vetoes", vetoes.size(), 0)
	_eq(errs, "candidates identical", JSON.stringify(cands), before)
	_eq(errs, "empty cfg", _run_screen(cands, _actor(), 5, {}).size(), 0)
	return _res(errs)


static func _t_screen_vetoes_with_each_reason() -> Dictionary:
	var errs: Array = []
	# hostile at col 5: stop cell (2,1) is 3 away, so guard is legal and the cell is outside reach.
	var cases: Array = [
		["no_benefit", _actor(), 20, "engage", 0.5],
		["urgency_critical", _actor(), 5, "engage", 1.0],
		["hostile_in_reach", _actor(), 3, "engage", 0.5],
		["streak", _actor({ StopShortContextService.STREAK_KEY: true }), 5, "engage", 0.5],
		["purpose_excluded", _actor(), 5, "withdraw", 0.5],
		["no_cause", _actor({ "fear": 0 }), 5, "engage", 0.5],
	]
	for case_v: Variant in cases:
		var c: Array = case_v as Array
		var cands: Array = [_candidate("option.a.conservative", str(c[3]), float(c[4])), _candidate("option.a.direct")]
		var vetoes: Array = _run_screen(cands, c[1] as Dictionary, int(c[2]), _cfg())
		_eq(errs, "%s veto count" % str(c[0]), vetoes.size(), 1)
		if vetoes.size() == 1:
			_eq(errs, "%s reason" % str(c[0]), (vetoes[0] as Dictionary)["reason"], str(c[0]))
			_eq(errs, "%s option" % str(c[0]), (vetoes[0] as Dictionary)["option_id"], "option.a.conservative")
		_eq(errs, "%s only the direct route stays" % str(c[0]), cands.size(), 1)
		_eq(errs, "%s kept id" % str(c[0]), (cands[0] as Dictionary)["_movement_option_id"], "option.a.direct")
	return _res(errs)


static func _t_screen_keeps_legal_and_records_bias() -> Dictionary:
	var errs: Array = []
	var cands: Array = [_candidate("option.a.conservative"), _candidate("option.a.direct")]
	var vetoes: Array = _run_screen(cands, _actor(), 5, _cfg())
	_eq(errs, "no veto", vetoes.size(), 0)
	_eq(errs, "both kept", cands.size(), 2)
	var stop: Dictionary = (cands[0] as Dictionary).get("_stop_short", {}) as Dictionary
	_eq(errs, "tagged", stop.get("benefit_id", ""), "guard")
	_eq(errs, "direct untouched", (cands[1] as Dictionary).has("_stop_short"), false)
	var bias: float = StopShortContextService.record_bias(cands[0] as Dictionary)
	_eq(errs, "bias is weight x strength", is_equal_approx(bias, 6.0), true)
	_eq(errs, "bias recorded under the cause key",
		is_equal_approx(float(((cands[0] as Dictionary)["_score_bias"] as Dictionary).get("stop_short.fear", 0.0)), 6.0), true)
	_eq(errs, "no bias on a normal route", StopShortContextService.record_bias(cands[1] as Dictionary), 0.0)
	var tag: Dictionary = StopShortContextService.trace_tag(cands[0] as Dictionary)
	_eq(errs, "tag", [tag["cause_id"], tag["benefit_id"], tag["source"], tag["code"]], ["fear", "guard", "emotion", "fear"])
	_eq(errs, "no tag for a normal route", StopShortContextService.trace_tag(cands[1] as Dictionary).is_empty(), true)
	return _res(errs)


## The screen can empty the list. The arbiter's `no_candidates` guard before `candidates[0]`
## is not reachable through select_movement_intent: `actor.idle` is always a candidate.
static func _t_screen_can_empty_the_list() -> Dictionary:
	var errs: Array = []
	var empty: Array = []
	_eq(errs, "empty input: no vetoes", _run_screen(empty, _actor(), 5, _cfg()).size(), 0)
	_eq(errs, "empty input stays empty", empty.size(), 0)
	var cands: Array = [_candidate("option.a.conservative")]
	var vetoes: Array = _run_screen(cands, _actor({ "fear": 0 }), 5, _cfg())
	_eq(errs, "all vetoed", vetoes.size(), 1)
	_eq(errs, "list emptied", cands.size(), 0)
	return _res(errs)


## A non-Echo keeps its `conservative` route untouched, even with every Echo gate open:
## no veto, no tag, no bias, no benefit.
static func _t_screen_skips_non_echo() -> Dictionary:
	var errs: Array = []
	for kind: String in ["enemy", "spirit", ""]:
		var cands: Array = [_candidate("option.a.conservative"), _candidate("option.a.direct")]
		var before: String = JSON.stringify(cands)
		var vetoes: Array = _run_screen(cands, _actor({ "actor_type": kind, "faction": "enemy" }), 5, _cfg())
		_eq(errs, "%s: no veto" % kind, vetoes.size(), 0)
		_eq(errs, "%s: candidates unchanged" % kind, JSON.stringify(cands), before)
		_eq(errs, "%s: no bias" % kind, StopShortContextService.record_bias(cands[0] as Dictionary), 0.0)
		_eq(errs, "%s: no tag" % kind, StopShortContextService.trace_tag(cands[0] as Dictionary).is_empty(), true)
	# Control: the same board stops an Echo, so the skip above is the actor type and nothing else.
	var echo_cands: Array = [_candidate("option.a.conservative")]
	_run_screen(echo_cands, _actor(), 5, _cfg())
	_eq(errs, "echo control is tagged", (echo_cands[0] as Dictionary).has("_stop_short"), true)
	return _res(errs)



static func _entry(score: float, bias: Dictionary, tag: Dictionary) -> Dictionary:
	var entry: Dictionary = {
		"action_type": "melee_attack", "target_id": "enemy_1", "score": score,
		"components": { "base": score - float(bias.get("stop_short.fear", 0.0)), "fear_factor": 1.0, "calling_mul": 1.0 },
		"spatial": {}, "bias": bias,
	}
	if not tag.is_empty():
		entry["stop_short"] = tag
	return entry


static func _t_trace_names_benefit_and_cause_only_when_decisive() -> Dictionary:
	var errs: Array = []
	var tag: Dictionary = { "cause_id": "fear", "benefit_id": "guard", "source": "emotion", "code": "fear" }
	var div_cfg: Dictionary = { "legibility_bands": { "vague_max": 0.0, "explicit_min": 0.5 } }
	# Cause decisive: removing the emotion source loses the 6.0 bias and the runner-up wins.
	var decisive: Dictionary = DecisionTrace.build({
		"winner": _entry(26.0, { "stop_short.fear": 6.0 }, tag), "runner_up": _entry(24.0, {}, {}),
		"decision_scale": 10.0, "purpose": "engage", "subject_id": "enemy_1",
		"commitment": 1, "capacity": 2, "hard_override": "",
	}, 0.9, div_cfg)
	_eq(errs, "benefit named", (decisive["message_args"] as Dictionary).get("benefit", ""), "guard")
	_eq(errs, "decisive primary source", (decisive["primary"] as Dictionary)["source"], "emotion")
	_eq(errs, "decisive primary code", (decisive["primary"] as Dictionary)["code"], "fear")
	# Cause not decisive: the winner leads by far more than the bias.
	var weak: Dictionary = DecisionTrace.build({
		"winner": _entry(40.0, { "stop_short.fear": 1.0 }, tag), "runner_up": _entry(24.0, {}, {}),
		"decision_scale": 10.0, "purpose": "engage", "subject_id": "enemy_1",
		"commitment": 1, "capacity": 2, "hard_override": "",
	}, 0.9, div_cfg)
	_eq(errs, "weak: benefit still named", (weak["message_args"] as Dictionary).get("benefit", ""), "guard")
	_eq(errs, "weak: cause is not the reason", (weak["primary"] as Dictionary)["source"] == "emotion", false)
	var plain: Dictionary = DecisionTrace.build({
		"winner": _entry(40.0, {}, {}), "runner_up": _entry(24.0, {}, {}),
		"decision_scale": 10.0, "purpose": "engage", "subject_id": "", "commitment": 1, "capacity": 2, "hard_override": "",
	}, 0.9, div_cfg)
	_eq(errs, "normal winner has no benefit arg", (plain["message_args"] as Dictionary).has("benefit"), false)
	return _res(errs)


static func _t_trace_player_safe_fields_unchanged() -> Dictionary:
	var errs: Array = []
	_eq(errs, "fields", DecisionTrace.PLAYER_SAFE_FIELDS, ["primary", "purpose", "message_key", "message_args", "voice_tone"])
	_eq(errs, "primary fields", DecisionTrace.PLAYER_SAFE_PRIMARY_FIELDS, ["code", "source", "subject_id"])
	var tag: Dictionary = { "cause_id": "fear", "benefit_id": "guard", "source": "emotion", "code": "fear" }
	var built: Dictionary = DecisionTrace.build({
		"winner": _entry(26.0, { "stop_short.fear": 6.0 }, tag), "runner_up": _entry(24.0, {}, {}),
		"decision_scale": 10.0, "purpose": "engage", "subject_id": "", "commitment": 1, "capacity": 2, "hard_override": "",
	}, 0.9, { "legibility_bands": { "vague_max": 0.0, "explicit_min": 0.5 } })
	var safe: Dictionary = DecisionTrace.sanitize(built)
	var keys: Array = safe.keys()
	keys.sort()
	var want: Array = DecisionTrace.PLAYER_SAFE_FIELDS.duplicate()
	want.sort()
	_eq(errs, "sanitized keys", keys, want)
	return _res(errs)



static func _t_finish_reports_interrupted_benefit() -> Dictionary:
	var errs: Array = []
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var actor: Dictionary = _actor()
	var asm := ActorStateMachine.new(actor)
	var stop: Dictionary = StopShortService.evaluate({
		"actor_type": "echo", "purpose": "engage", "urgency": 0.5, "fear": 45, "fear_base": 0, "morale": 60,
		"capacity": 2, "def": 5, "hostiles": [{ "id": "enemy_1", "dist": 3, "marked": false }],
	}, _cfg())
	var made: Dictionary = { "_stop_short": stop }
	var intent: Dictionary = made.duplicate(true)
	var performed_result: Dictionary = { "resolved_action": _plan("actor.guard"), "final_destination": _cell(2, 1) }
	StopShortContextService.finish(actor, intent, performed_result, asm, logger, 3)
	var report: Dictionary = intent["_stop_short_report"] as Dictionary
	_eq(errs, "benefit", report["benefit"], "guard")
	_eq(errs, "performed", report["performed"], true)
	_eq(errs, "stop cell", report["stop_cell"], _cell(2, 1))
	_eq(errs, "subject empty for guard", report["subject_actor_id"], "")
	_eq(errs, "streak flag set", actor.get(StopShortContextService.STREAK_KEY, false), true)
	_eq(errs, "consumed", intent.has("_stop_short"), false)
	_eq(errs, "no interrupt log when performed", _log_types(logger).has("movement.stop_short_interrupted"), false)

	var intent2: Dictionary = made.duplicate(true)
	StopShortContextService.finish(actor, intent2, { "resolved_action": _plan("melee_attack", "enemy_1"),
		"final_destination": _cell(2, 1) }, asm, logger, 4)
	_eq(errs, "not performed", (intent2["_stop_short_report"] as Dictionary)["performed"], false)
	_eq(errs, "interrupt logged", _log_types(logger).has("movement.stop_short_interrupted"), true)

	var intent3: Dictionary = {}
	StopShortContextService.finish(actor, intent3, {}, asm, logger, 5)
	_eq(errs, "normal step has no report", intent3.has("_stop_short_report"), false)
	_eq(errs, "normal step clears the streak", actor.has(StopShortContextService.STREAK_KEY), false)
	return _res(errs)


## Runs a 3-cell stop-short (planned stop (4,1)) through activation and finish. A Binding hazard at
## `hazard` (empty: none) halts the mover on that cell. `with_cell` false omits "stop_short_cell".
static func _stop_run(hazard: Dictionary, with_cell: bool) -> Dictionary:
	var ctx: Dictionary = _activation_ctx()
	if not hazard.is_empty():
		ctx["known_hazards"] = [HazardFact.build("h.b", hazard, "binding")]
	var hazard_ctx: Dictionary = {
		"triggered": { "unstable": false, "binding": false, "burning": false },
		"config": { "types": ["unstable", "binding", "burning"], "binding": { "stops_movement": true } },
	}
	var action_ctx: Dictionary = {
		"purpose": "engage", "positions": { "enemy.1": _cell(9, 9) },
		"stop_short_benefit": _plan("actor.guard"),
	}
	if with_cell:
		action_ctx["stop_short_cell"] = _cell(4, 1)
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1), _cell(4, 1)], _plan("melee_attack", "enemy.1"), {})
	var result: Dictionary = Activation.activate(ctx, intent, { "capacity": 6 }, hazard_ctx, action_ctx)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var actor: Dictionary = _actor()
	var stop: Dictionary = StopShortService.evaluate({
		"actor_type": "echo", "purpose": "engage", "urgency": 0.5, "fear": 45, "fear_base": 0, "morale": 60,
		"capacity": 2, "def": 5, "hostiles": [{ "id": "enemy_1", "dist": 3, "marked": false }],
	}, _cfg())
	var stop_intent: Dictionary = { "_stop_short": stop }
	StopShortContextService.finish(actor, stop_intent, result, ActorStateMachine.new(actor), logger, 3)
	return { "result": result, "report": stop_intent["_stop_short_report"], "types": _log_types(logger) }


static func _t_binding_halt_short_of_stop_cell_skips_benefit() -> Dictionary:
	var errs: Array = []
	var run: Dictionary = _stop_run(_cell(3, 1), true)
	var result: Dictionary = run["result"] as Dictionary
	_eq(errs, "mover halted short", result["final_destination"], _cell(3, 1))
	_eq(errs, "benefit not resolved", (result["resolved_action"] as Dictionary).is_empty(), true)
	_eq(errs, "performed false", (run["report"] as Dictionary)["performed"], false)
	_eq(errs, "interrupt logged", (run["types"] as Array).has("movement.stop_short_interrupted"), true)
	return _res(errs)


static func _t_stop_cell_reached_still_performs_benefit() -> Dictionary:
	var errs: Array = []
	var run: Dictionary = _stop_run({}, true)
	_eq(errs, "mover reached stop cell", (run["result"] as Dictionary)["final_destination"], _cell(4, 1))
	_eq(errs, "performed true", (run["report"] as Dictionary)["performed"], true)
	_eq(errs, "no interrupt log", (run["types"] as Array).has("movement.stop_short_interrupted"), false)
	return _res(errs)


static func _t_absent_stop_cell_keeps_old_behaviour() -> Dictionary:
	var errs: Array = []
	var run: Dictionary = _stop_run(_cell(3, 1), false)
	_eq(errs, "mover halted short", (run["result"] as Dictionary)["final_destination"], _cell(3, 1))
	_eq(errs, "benefit still performed", (run["report"] as Dictionary)["performed"], true)
	return _res(errs)


## An absolute-fear refuse returns early from apply_live_activation, before `finish` runs.
## The streak must still end, or the next conservative route is vetoed as consecutive.
static func _t_refuse_turn_clears_streak() -> Dictionary:
	var errs: Array = []
	var actor: Dictionary = _actor({ StopShortContextService.STREAK_KEY: true })
	var logger := StructuredLogger.new()
	var live := LiveMovementContextService.new(null, logger)
	var returned: Dictionary = live.apply_live_activation(
		actor, { "action_type": "actor.refuse" }, {}, ActorStateMachine.new(actor), {}, 7)
	_eq(errs, "early path returns nothing", returned.is_empty(), true)
	_eq(errs, "streak cleared", actor.has(StopShortContextService.STREAK_KEY), false)
	var cands: Array = [_candidate("option.a.conservative")]
	_eq(errs, "next conservative route not vetoed", _run_screen(cands, actor, 5, _cfg()).size(), 0)
	_eq(errs, "next conservative route kept", cands.size(), 1)
	var held: Array = [_candidate("option.a.conservative")]
	var control: Array = _run_screen(held, _actor({ StopShortContextService.STREAK_KEY: true }), 5, _cfg())
	_eq(errs, "control: a kept streak still vetoes", control.size(), 1)
	return _res(errs)


static func _controller(id: String, col: int, row: int) -> Dictionary:
	return { "id": id, "position": _cell(col, row), "is_dead": false, "is_ko": false,
		"is_structure": false, "controlling_state": true }


## Only the final edge of the route decides whether Observe is blocked. Guard is closed
## (guard_state) and the cause is a sight calling, so Observe is the only legal benefit.
static func _t_hostile_control_read_at_last_edge() -> Dictionary:
	var errs: Array = []
	var cases: Array = [
		["controlled first edge only", _controller("enemy_2", 0, 1), ["enemy_2"], 0],
		["controlled last edge", _controller("enemy_2", 4, 2), [], 1],
	]
	for case_v: Variant in cases:
		var c: Array = case_v as Array
		var cand: Dictionary = _candidate("option.a.conservative")
		cand["_movement_path"] = [_cell(2, 1), _cell(3, 1)]
		cand["_movement_option"] = { "cohesion": 0.0, "hostile_control_sources": c[2] }
		var movement_context: Dictionary = {
			"relationships": { "enemy_1": "hostile", "enemy_2": "hostile" },
			"origin": _cell(1, 1), "perceived_actors": [c[1]],
		}
		var cands: Array = [cand]
		var vetoes: Array = StopShortContextService.screen(
			cands, _actor({ "guard_state": true, "fear": 0 }), _hostiles(5), { "calling_family": "sight", "judgment": 0.8 },
			movement_context, [], 2, Callable(StopShortWiringTests, "_style_of"), _cfg())
		_eq(errs, "%s: veto count" % str(c[0]), vetoes.size(), int(c[3]))
		if int(c[3]) == 1 and vetoes.size() == 1:
			_eq(errs, "%s: reason" % str(c[0]), (vetoes[0] as Dictionary)["reason"], "no_benefit")
		if int(c[3]) == 0:
			_eq(errs, "%s: observe is the benefit" % str(c[0]),
				((cand.get("_stop_short", {}) as Dictionary).get("benefit_id", "")), "observe")
	return _res(errs)


static func _t_runtime_status_line() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _setup("status_line", {})
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var rt: FlowRuntime = env["runtime"]
	var actor_cfg: Dictionary = (rt.config_service.get_balance()["data"] as Dictionary)["actor"] as Dictionary
	_eq(errs, "matches the service line", rt.stop_short_status_line(),
		StopShortContextService.status_line(actor_cfg, "", rt.flow_ctx.encounter_ctx))
	_eq(errs, "names the encounter", rt.stop_short_status_line().contains("this encounter = balance.json"), true)
	rt.dispatch({ "type": "debug.stop_short.set", "mode": "on" })
	_eq(errs, "shows the override", rt.stop_short_status_line().contains("override = on"), true)
	return _res(errs)


static func _log_types(logger: StructuredLogger) -> Array:
	var out: Array = []
	for e_v: Variant in logger.get_logs():
		out.append(str((e_v as Dictionary).get("type", "")))
	return out



static func _observer(id: String) -> Dictionary:
	return { "id": id, "actor_type": "echo", "faction": "echo", "calling_origin": "", "stats": {}, "traits": {},
		"grid_pos": _cell(1, 1), "current_hp": 10 }


static func _apply(actor: Dictionary, action: String, target: String, all_actors: Array, cfg: Dictionary) -> void:
	var asm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	asm.update_passive_state_from_activation({ "action_type": action, "target_id": target },
		{ "all_actors": all_actors, "cfg": cfg }, 1, false, logger)


static func _t_observe_mark_strength_and_overwrite_rules() -> Dictionary:
	var errs: Array = []
	var cs := ConfigService.new()
	cs.load_balance()
	var cfg: Dictionary = cs.get_balance()
	var enemy: Dictionary = { "id": "enemy_1", "faction": "enemy", "actor_type": "enemy", "grid_pos": _cell(3, 1),
		"current_hp": 50, "stats": { "max_hp": 50 } }
	var observer: Dictionary = _observer("echo_0001")
	var skiller: Dictionary = _observer("echo_0002")
	var all: Array = [observer, skiller, enemy]

	_apply(observer, "actor.observe", "enemy_1", all, cfg)
	_eq(errs, "observe marks", enemy.get("marked_by", ""), "echo_0001")
	_eq(errs, "observe strength", float(enemy.get("marked_strength", 0.0)), 5.0)
	_eq(errs, "observe length", int(enemy.get("_mark_duration", 0)), 1)
	_eq(errs, "observe kind", enemy.get("_mark_kind", ""), "observe")
	_eq(errs, "melee bonus 5", _melee_bonus(enemy), 5.0)

	_apply(skiller, "actor.mark", "enemy_1", all, cfg)
	_eq(errs, "skill overwrites observe", enemy.get("marked_by", ""), "echo_0002")
	_eq(errs, "skill duration", int(enemy.get("_mark_duration", 0)), 2)
	_eq(errs, "skill clears observe strength", enemy.has("marked_strength"), false)
	_eq(errs, "skill clears observe kind", enemy.has("_mark_kind"), false)
	_eq(errs, "melee bonus 10", _melee_bonus(enemy), 10.0)

	_apply(observer, "actor.observe", "enemy_1", all, cfg)
	_eq(errs, "observe never overwrites a skill mark", enemy.get("marked_by", ""), "echo_0002")
	_eq(errs, "skill duration kept", int(enemy.get("_mark_duration", 0)), 2)

	var short: Dictionary = enemy.duplicate(true)
	short["marked_by"] = "echo_0001"
	short["_mark_duration"] = 1
	short["marked_strength"] = 5.0
	short["_mark_kind"] = "observe"
	_apply(short, "actor.idle", "", [short], cfg)
	_eq(errs, "tick clears mark", short.has("marked_by"), false)
	_eq(errs, "tick clears strength", short.has("marked_strength"), false)
	_eq(errs, "tick clears kind", short.has("_mark_kind"), false)
	return _res(errs)


static func _melee_bonus(enemy: Dictionary) -> float:
	var ally: Dictionary = { "id": "echo_ally", "faction": "echo", "actor_type": "echo",
		"grid_pos": { "col": 2, "row": 1 }, "current_hp": 50, "stats": { "max_hp": 50 } }
	var enemy_pos: Dictionary = enemy.duplicate()
	enemy_pos["grid_pos"] = { "col": 3, "row": 1 }
	for c: Dictionary in ActionCandidateGenerator.generate_candidates(
			ally, [ally, enemy_pos], { "skills_cfg": {} }, "forming", {}, {}, 2, 0.0, {}, {}):
		if str(c.get("action_type", "")) == "melee_attack":
			return float(c.get("_mark_bonus", -1.0))
	return -1.0


static func _t_actor_projection_marks() -> Dictionary:
	var errs: Array = []
	var base: Dictionary = { "id": "e1", "stats": { "max_hp": 10 }, "grid_pos": _cell(1, 1) }
	var plain: Dictionary = EncounterSnapshotBuilder._project_actor(base.duplicate(true))
	_eq(errs, "unmarked is_marked", plain["is_marked"], false)
	_eq(errs, "unmarked kind", plain["mark_kind"], "")
	var skill: Dictionary = base.duplicate(true)
	skill["marked_by"] = "echo_0001"
	var skill_p: Dictionary = EncounterSnapshotBuilder._project_actor(skill)
	_eq(errs, "skill is_marked", skill_p["is_marked"], true)
	_eq(errs, "skill kind", skill_p["mark_kind"], "skill")
	var obs: Dictionary = skill.duplicate(true)
	obs["_mark_kind"] = "observe"
	_eq(errs, "observe kind", EncounterSnapshotBuilder._project_actor(obs)["mark_kind"], "observe")
	_eq(errs, "no internal key leaks", EncounterSnapshotBuilder._project_actor(obs).has("_mark_kind"), false)
	return _res(errs)



static func _t_debug_emotion_set() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _setup("debug_emotion", {})
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var roster: Array = runtime.get_save_data()["sanctum"]["roster"]
	var echo: Dictionary = roster[0] as Dictionary
	var id: String = str(echo["id"])
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "fear", "value": 30 })
	_eq(errs, "fear", int(echo["emotion"]["fear_current"]), 30)
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "fear_base", "value": 33 })
	_eq(errs, "fear_base", int(echo["emotion"]["fear_base"]), 33)
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "morale", "value": 12 })
	_eq(errs, "morale", int(echo["emotion"]["morale_current"]), 12)
	var actor: Dictionary = EchoActor.from_echo(echo)
	_eq(errs, "actor fear", actor["fear"], 30)
	_eq(errs, "actor fear_base", actor["fear_base"], 33)
	_eq(errs, "actor morale", actor["morale"], 12)
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "fear", "value": 250 })
	_eq(errs, "clamped high", int(echo["emotion"]["fear_current"]), 100)
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "morale", "value": -5 })
	_eq(errs, "clamped low", int(echo["emotion"]["morale_current"]), 0)
	var before: String = JSON.stringify(roster)
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": "nobody", "field": "fear", "value": 10 })
	runtime.dispatch({ "type": "debug.emotion.set", "echo_id": id, "field": "bogus", "value": 10 })
	_eq(errs, "denied changes nothing", JSON.stringify(roster), before)
	return _res(errs)



static func _setup(tag: String, equip: Dictionary, overrides: Dictionary = {}, dev: String = "") -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("debug")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.fresh_save_path("%s_%s.json" % [_TAG, tag]))
	runtime.boot()
	if not overrides.is_empty():
		var block: Dictionary = (((config._balance["data"] as Dictionary)["actor"] as Dictionary)["stop_short"]) as Dictionary
		for k: String in overrides.keys():
			block[k] = overrides[k]
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0
	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.%s" % tag
	flow_ctx.save_data["economy"]["ase"] = 0
	flow_ctx.save_data["economy"]["ekwan"] = 0
	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var vec_cfg: Dictionary = bal.get("data", {}).get("vectors", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, vec_cfg, logger, t)
		FlowFingerprintTests._promote_echo_rank(echo, 3, bal, flow_ctx.campaign_seed, logger, t)
		if i == 0:
			echo["equipped_skills"] = equip.duplicate(true)
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids
	flow_ctx.dev_combat_objective = "combat"
	if not dev.is_empty():
		runtime.dispatch({ "type": "debug.stop_short.set", "mode": dev })
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	if flow_ctx.encounter_ctx == null:
		return {}
	return { "runtime": runtime, "ectx": flow_ctx.encounter_ctx, "logger": logger }


## One real turn for echo_0001 at (1,1), the nearest hostile `dist` cells east, other actors parked far away.
static func _live_turn(tag: String, overrides: Dictionary, actor_over: Dictionary, dist: int,
		equip: Dictionary = {}, dev: String = "", mid_fight_dev: String = "") -> Dictionary:
	var env: Dictionary = _setup(tag, equip, overrides, dev)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })
	runtime.dispatch({ "type": "combat.confirm_round" })
	if not mid_fight_dev.is_empty():
		runtime.dispatch({ "type": "debug.stop_short.set", "mode": mid_fight_dev })
	ectx.terrain = {}  # open 10x10 board: generated islands can leave the stop cell unroutable
	var actor: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, "echo_0001")
	var enemy: Dictionary = {}
	var far_col: int = 9
	for a_v: Variant in ectx.actors:
		var a: Dictionary = a_v as Dictionary
		if a == actor:
			continue
		if enemy.is_empty() and str(a.get("faction", "")) == "enemy" and not bool(a.get("is_structure", false)):
			enemy = a
			continue
		GridService.assign_grid_pos(a, far_col, 9 - (far_col % 3))
		far_col -= 1
	if actor.is_empty() or enemy.is_empty():
		return { "ok": false, "error": "missing actor or enemy" }
	GridService.assign_grid_pos(actor, 1, 1)
	GridService.assign_grid_pos(enemy, 1 + dist, 1)
	actor.erase("last_intent")
	for k: String in actor_over.keys():
		actor[k] = actor_over[k]
	var order: Array = ectx.combat_state.get("initiative_order", []) as Array
	var idx: int = -1
	for i in range(order.size()):
		if str((order[i] as Dictionary).get("id", "")) == "echo_0001":
			idx = i
	if idx < 0:
		return { "ok": false, "error": "echo_0001 not in initiative order" }
	ectx.combat_state["current_actor_index"] = idx
	var before: int = ectx.last_round_results.size()
	var logger: StructuredLogger = env["logger"]
	logger.clear()
	var snapshot: Dictionary = runtime.dispatch({ "type": "combat.next_actor" })
	if ectx.last_round_results.size() <= before:
		return { "ok": false, "error": "no turn resolved" }
	return {
		"ok": true, "actor": actor, "enemy": enemy, "ectx": ectx, "logger": logger, "snapshot": snapshot,
		"entry": ectx.last_round_results.back(), "last": ectx.last_actor_action,
		"types": _log_types(logger), "runtime": runtime,
	}


## Weight high enough that the stop-short wins on every fixture below (shipped is 6.0).
const _ON: Dictionary = { "enabled": true, "stop_short_weight": 40.0 }


## Feature off in this encounter's config copy (balance.json ships it on) with the strong weight.
const _OFF: Dictionary = { "enabled": false, "stop_short_weight": 40.0 }


static func _t_live_guard_stop_short_contract() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("guard_on", _ON, { "fear": 45, "fear_base": 0, "morale": 60 }, 4)
	if not bool(r["ok"]):
		return r
	var last: Dictionary = r["last"] as Dictionary
	var ss: Dictionary = last.get("stop_short", {}) as Dictionary
	_eq(errs, "stop_short present and filled", ss.is_empty(), false)
	if ss.is_empty():
		errs.append("types: %s resolved: %s" % [str(r["types"]), str(last.get("action_type", ""))])
		return _res(errs)
	var keys: Array = ss.keys()
	keys.sort()
	_eq(errs, "contract keys", keys, ["benefit", "performed", "stop_cell", "subject_actor_id", "trace"])
	_eq(errs, "no anchor fields", ss.has("anchor_actor_ids") or ss.has("planned_end_cell"), false)
	_eq(errs, "benefit", ss["benefit"], "guard")
	_eq(errs, "performed", ss["performed"], true)
	var path: Array = last.get("path", []) as Array
	_eq(errs, "stop cell is the last path cell", ss["stop_cell"], path.back() if not path.is_empty() else {})
	_eq(errs, "resolved action", last.get("action_type", ""), "actor.guard")
	var trace: Dictionary = ss["trace"] as Dictionary
	var trace_keys: Array = trace.keys()
	trace_keys.sort()
	var want: Array = DecisionTrace.PLAYER_SAFE_FIELDS.duplicate()
	want.sort()
	_eq(errs, "trace is a sanitized trace", trace_keys, want)
	var primary_keys: Array = (trace["primary"] as Dictionary).keys()
	primary_keys.sort()
	_eq(errs, "trace primary fields", primary_keys, ["code", "source", "subject_id"])
	_eq(errs, "trace names the benefit", (trace["message_args"] as Dictionary).get("benefit", ""), "guard")
	_eq(errs, "round result carries it", ((r["entry"] as Dictionary).get("stop_short", {}) as Dictionary).get("benefit", ""), "guard")
	_eq(errs, "guard state set", bool((r["actor"] as Dictionary).get("guard_state", false)), true)
	_eq(errs, "streak flag", bool((r["actor"] as Dictionary).get(StopShortContextService.STREAK_KEY, false)), true)
	_eq(errs, "selected logged", (r["types"] as Array).has("movement.stop_short_selected"), true)
	var snap_ss: Dictionary = (((r["snapshot"] as Dictionary).get("data", {}) as Dictionary)
		.get("last_actor_action", {}) as Dictionary).get("stop_short", {}) as Dictionary
	_eq(errs, "snapshot carries it", snap_ss.get("benefit", ""), "guard")
	return _res(errs)


static func _t_live_off_keeps_empty_stop_short() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("guard_off", { "enabled": false }, { "fear": 45, "fear_base": 0, "morale": 60 }, 4)
	if not bool(r["ok"]):
		return r
	var last: Dictionary = r["last"] as Dictionary
	_eq(errs, "key always present", last.has("stop_short"), true)
	_eq(errs, "empty when off", (last.get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	_eq(errs, "no entry stamp", (r["entry"] as Dictionary).has("stop_short"), false)
	for type: String in r["types"]:
		_eq(errs, "no stop-short log " + type, type.begins_with("movement.stop_short"), false)
	_eq(errs, "no streak key", (r["actor"] as Dictionary).has(StopShortContextService.STREAK_KEY), false)
	# Control S2: shipped weight, no fear, no broken morale.
	var calm: Dictionary = _live_turn("guard_calm", { "enabled": true }, { "fear": 0, "fear_base": 0, "morale": 60, "dominant_vector": "" }, 4)
	if not bool(calm["ok"]):
		return calm
	_eq(errs, "calm echo does not stop", ((calm["last"] as Dictionary).get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	return _res(errs)


static func _t_live_streak_vetoes_second_stop() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("streak", _ON, {
		"fear": 45, "fear_base": 0, "morale": 60, StopShortContextService.STREAK_KEY: true }, 4)
	if not bool(r["ok"]):
		return r
	_eq(errs, "no stop", ((r["last"] as Dictionary).get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	_eq(errs, "veto logged", (r["types"] as Array).has("movement.stop_short_vetoed"), true)
	var reasons: Array = []
	for e_v: Variant in (r["logger"] as StructuredLogger).get_logs():
		var e: Dictionary = e_v as Dictionary
		if str(e.get("type", "")) == "movement.stop_short_vetoed":
			reasons.append(str((e.get("data", {}) as Dictionary).get("reason", "")))
	_eq(errs, "reason", reasons.has("streak"), true)
	_eq(errs, "streak cleared after a normal step", (r["actor"] as Dictionary).has(StopShortContextService.STREAK_KEY), false)
	return _res(errs)


static func _t_live_observe_vs_skill_mark() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("observe", _ON, {
		"fear": 0, "fear_base": 0, "morale": 60, "dominant_vector": "skeptic" }, 4)
	if not bool(r["ok"]):
		return r
	var ss: Dictionary = (r["last"] as Dictionary).get("stop_short", {}) as Dictionary
	if ss.is_empty():
		errs.append("no stop-short; types: %s" % str(r["types"]))
		return _res(errs)
	_eq(errs, "benefit", ss["benefit"], "observe")
	_eq(errs, "performed", ss["performed"], true)
	_eq(errs, "subject is the hostile", ss["subject_actor_id"], str((r["enemy"] as Dictionary)["id"]))
	_eq(errs, "resolved action", (r["last"] as Dictionary).get("action_type", ""), "actor.observe")
	_eq(errs, "target marked", (r["enemy"] as Dictionary).get("marked_by", ""), "echo_0001")
	_eq(errs, "observe strength", float((r["enemy"] as Dictionary).get("marked_strength", 0.0)), 5.0)
	_eq(errs, "snapshot projection", EncounterSnapshotBuilder._project_actor(r["enemy"] as Dictionary)["mark_kind"], "observe")
	return _res(errs)



## balance.json ships enabled true, so a frightened Echo stops short with no command. With the
## config copy off, `stopshort on` before the encounter starts turns it on for that encounter.
static func _t_debug_stop_short_default_and_on() -> Dictionary:
	var errs: Array = []
	var weight: Dictionary = { "stop_short_weight": 40.0 }
	var fear: Dictionary = { "fear": 45, "fear_base": 0, "morale": 60 }
	var dflt: Dictionary = _live_turn("dev_default", weight, fear, 4)
	if not bool(dflt["ok"]):
		return dflt
	_eq(errs, "default override empty", (dflt["ectx"] as EncounterContext).stop_short_override, "")
	_eq(errs, "default: stop-short", ((dflt["last"] as Dictionary).get("stop_short", {}) as Dictionary).get("benefit", ""), "guard")
	var off: Dictionary = _live_turn("dev_cfg_off", _OFF, fear, 4)
	if not bool(off["ok"]):
		return off
	_eq(errs, "config off: no stop", ((off["last"] as Dictionary).get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	var on: Dictionary = _live_turn("dev_on", _OFF, fear, 4, {}, "on")
	if not bool(on["ok"]):
		return on
	_eq(errs, "encounter captured on", (on["ectx"] as EncounterContext).stop_short_override, "on")
	_eq(errs, "on: stop-short", ((on["last"] as Dictionary).get("stop_short", {}) as Dictionary).get("benefit", ""), "guard")
	var rt: FlowRuntime = on["runtime"]
	var block: Dictionary = (((rt.config_service.get_balance()["data"] as Dictionary)["actor"] as Dictionary)["stop_short"]) as Dictionary
	_eq(errs, "config not written", bool(block["enabled"]), false)
	_eq(errs, "status field", rt.flow_ctx.dev_stop_short, "on")
	return _res(errs)


static func _t_debug_stop_short_off_overrides_balance() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("dev_off", _ON, { "fear": 45, "fear_base": 0, "morale": 60 }, 4, {}, "off")
	if not bool(r["ok"]):
		return r
	_eq(errs, "off: no stop", ((r["last"] as Dictionary).get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	for type: String in r["types"]:
		_eq(errs, "off: no stop-short log " + type, type.begins_with("movement.stop_short"), false)
	var cfg: Dictionary = { "stop_short": { "enabled": true, "stop_short_weight": 6.0 } }
	var out: Dictionary = StopShortContextService.with_override(cfg, "off")
	_eq(errs, "override copy", bool((out["stop_short"] as Dictionary)["enabled"]), false)
	_eq(errs, "input untouched", bool((cfg["stop_short"] as Dictionary)["enabled"]), true)
	_eq(errs, "no override returns the same dict", is_same(StopShortContextService.with_override(cfg, ""), cfg), true)
	return _res(errs)


## A mid-fight `stopshort on` does nothing in the running encounter; the next encounter has it.
static func _t_debug_stop_short_mid_fight_waits_for_next_encounter() -> Dictionary:
	var errs: Array = []
	var r: Dictionary = _live_turn("dev_mid", _OFF,
		{ "fear": 45, "fear_base": 0, "morale": 60 }, 4, {}, "", "on")
	if not bool(r["ok"]):
		return r
	var ectx: EncounterContext = r["ectx"]
	_eq(errs, "running encounter keeps its start value", ectx.stop_short_override, "")
	_eq(errs, "mid-fight: no stop", ((r["last"] as Dictionary).get("stop_short", {"x": 1}) as Dictionary).is_empty(), true)
	var rt: FlowRuntime = r["runtime"]
	_eq(errs, "override recorded", rt.flow_ctx.dev_stop_short, "on")
	rt.flow_ctx.encounter_ctx = null
	rt.flow_ctx.encounter_machine = null
	FlowEncounterState.new().enter(rt.flow_ctx, 0)
	_eq(errs, "next encounter has it", rt.flow_ctx.encounter_ctx.stop_short_override if rt.flow_ctx.encounter_ctx != null else "missing", "on")
	return _res(errs)


static func _t_debug_stop_short_not_saved_and_bad_input() -> Dictionary:
	var errs: Array = []
	var env: Dictionary = _setup("dev_save", {})
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var rt: FlowRuntime = env["runtime"]
	var logger: StructuredLogger = env["logger"]
	for bad: String in ["", "maybe", "ON ", "1"]:
		logger.clear()
		rt.dispatch({ "type": "debug.stop_short.set", "mode": bad })
		var denied: bool = _log_types(logger).has("debug.stop_short.set.denied")
		if bad == "ON ":
			_eq(errs, "case and space accepted", rt.flow_ctx.dev_stop_short, "on")
			rt.flow_ctx.dev_stop_short = ""
			continue
		_eq(errs, "'%s' denied" % bad, denied, true)
		_eq(errs, "'%s' changes nothing" % bad, rt.flow_ctx.dev_stop_short, "")
	# Taken after the dispatches above, which flush the save the encounter setup requested.
	var before: String = JSON.stringify(rt.get_save_data())
	rt.dispatch({ "type": "debug.stop_short.set", "mode": "on" })
	_eq(errs, "save data unchanged", JSON.stringify(rt.get_save_data()), before)
	_eq(errs, "no save request", rt.flow_ctx.save_request, false)
	var reloaded := FlowContext.new()
	_eq(errs, "a new session starts without override", reloaded.dev_stop_short, "")
	_eq(errs, "a new encounter context starts without override", EncounterContext.new().stop_short_override, "")
	return _res(errs)


static func _t_debug_stop_short_status_line() -> Dictionary:
	var errs: Array = []
	var cfg: Dictionary = { "stop_short": { "enabled": false } }
	_eq(errs, "default", StopShortContextService.status_line(cfg, "", null),
		"stopshort: override = none | balance.json enabled = false | this encounter = no encounter")
	var ectx := EncounterContext.new()
	_eq(errs, "encounter on balance.json", StopShortContextService.status_line(cfg, "on", ectx),
		"stopshort: override = on | balance.json enabled = false | this encounter = balance.json")
	ectx.stop_short_override = "off"
	_eq(errs, "encounter captured off", StopShortContextService.status_line({ "stop_short": { "enabled": true } }, "off", ectx),
		"stopshort: override = off | balance.json enabled = true | this encounter = off")
	_eq(errs, "missing block reads false", StopShortContextService.status_line({}, "", null).contains("enabled = false"), true)
	return _res(errs)


## With the feature on, an enemy `conservative` candidate keeps its shape: it is not
## vetoed, tagged, biased or given a benefit, and nothing is logged for it.
static func _t_screen_enemy_conservative_unchanged_with_full_config() -> Dictionary:
	var errs: Array = []
	var cands: Array = [_candidate("option.a.conservative")]
	var before: String = JSON.stringify(cands)
	var vetoes: Array = _run_screen(cands, _actor({ "actor_type": "enemy", "faction": "enemy", "fear": 90 }), 2, _cfg({ "stop_short_weight": 40.0 }))
	_eq(errs, "no veto entry", vetoes.size(), 0)
	_eq(errs, "candidate list unchanged", JSON.stringify(cands), before)
	var c: Dictionary = cands[0] as Dictionary
	_eq(errs, "no _stop_short", c.has("_stop_short"), false)
	_eq(errs, "no bias", StopShortContextService.record_bias(c), 0.0)
	_eq(errs, "score_bias stays empty", (c["_score_bias"] as Dictionary).is_empty(), true)
	return _res(errs)


## A stop-short observe step counts in total_count only (no observe_count); a guard counts
## in guard_count and total_count.
static func _t_ledger_observe_total_only_guard_both() -> Dictionary:
	var errs: Array = []
	var ledger := ContributionLedgerService.new(FlowContext.new(), StructuredLogger.new())
	var ectx := EncounterContext.new()
	var actor: Dictionary = { "id": "echo_x", "faction": "echo" }
	ectx.last_round_results.append({ "action_type": "actor.observe", "source_id": "echo_x" })
	ledger.accumulate_turn(actor, ectx, {}, {}, 1)
	var alog: Dictionary = ectx.echo_action_logs["echo_x"] as Dictionary
	_eq(errs, "observe total", alog["total_count"], 1)
	_eq(errs, "observe guard_count", alog["guard_count"], 0)
	_eq(errs, "observe melee_count", alog["melee_count"], 0)
	_eq(errs, "no observe_count field", alog.has("observe_count"), false)
	ectx.last_round_results.append({ "action_type": "actor.guard", "source_id": "echo_x" })
	ledger.accumulate_turn(actor, ectx, {}, {}, 2)
	_eq(errs, "guard total", alog["total_count"], 2)
	_eq(errs, "guard guard_count", alog["guard_count"], 1)
	return _res(errs)


## The report is attached to the entry this call appended, never to an older entry.
## (CombatService._resolve_guard never returns {}, so the empty-guard arm cannot be reached.)
static func _t_report_rides_on_this_calls_entry() -> Dictionary:
	var errs: Array = []
	var actor: Dictionary = { "id": "echo_x", "name": "X", "faction": "echo", "guard_state": false }
	var ectx := EncounterContext.new()
	ectx.actors = [actor]
	ectx.last_round_results.append({ "action_type": "actor.move", "source_id": "other" })
	var svc := CombatTurnActionService.new(StructuredLogger.new())
	var intent: Dictionary = { "action_type": "actor.guard", "_stop_short_report": { "benefit": "guard" } }
	svc.resolve_activation(actor, intent, "actor.guard", ActorStateMachine.new(actor), ectx, {}, {}, 1, 1)
	_eq(errs, "one new entry", ectx.last_round_results.size(), 2)
	_eq(errs, "old entry untouched", (ectx.last_round_results[0] as Dictionary).has("stop_short"), false)
	_eq(errs, "new entry carries report", (ectx.last_round_results[1] as Dictionary).has("stop_short"), true)
	return _res(errs)
