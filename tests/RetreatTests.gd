# res://tests/RetreatTests.gd
# UI-004: Tests for RetreatService — speed gate, agi chance tier, roll, and filtering.
#
#   1. retreat/can_attempt_when_echo_faster
#   2. retreat/cannot_attempt_when_equal_speed
#   3. retreat/cannot_attempt_when_echo_slower
#   4. retreat/tier_guaranteed_from_high_agi_delta
#   5. retreat/tier_risky_from_negative_agi_delta
#   6. retreat/roll_success_at_100pct
#   7. retreat/roll_failure_at_0pct
#   8. retreat/excludes_dead_and_structures
#
# All tests are pure unit tests — no FlowRuntime, no save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name RetreatTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("retreat/can_attempt_when_echo_faster",            Callable(RetreatTests, "_t_can_attempt_when_echo_faster"))
	runner.register_test("retreat/cannot_attempt_when_equal_speed",         Callable(RetreatTests, "_t_cannot_attempt_when_equal_speed"))
	runner.register_test("retreat/cannot_attempt_when_echo_slower",         Callable(RetreatTests, "_t_cannot_attempt_when_echo_slower"))
	runner.register_test("retreat/tier_guaranteed_from_high_agi_delta",     Callable(RetreatTests, "_t_tier_guaranteed"))
	runner.register_test("retreat/tier_risky_from_negative_agi_delta",      Callable(RetreatTests, "_t_tier_risky"))
	runner.register_test("retreat/roll_success_at_100pct",                  Callable(RetreatTests, "_t_roll_success_at_100"))
	runner.register_test("retreat/roll_failure_at_0pct",                    Callable(RetreatTests, "_t_roll_failure_at_0"))
	runner.register_test("retreat/excludes_dead_and_structures",            Callable(RetreatTests, "_t_excludes_dead_and_structures"))
	runner.register_test("retreat/price_is_10_from_config",                 Callable(RetreatTests, "_t_price_from_config"))
	runner.register_test("retreat/denied_below_price",                      Callable(RetreatTests, "_t_denied_below_price"))
	runner.register_test("retreat/allowed_at_exact_price",                  Callable(RetreatTests, "_t_allowed_at_exact_price"))
	runner.register_test("retreat/allowed_above_price",                     Callable(RetreatTests, "_t_allowed_above_price"))
	runner.register_test("retreat/failed_retreat_still_spends",             Callable(RetreatTests, "_t_failed_retreat_spends"))
	runner.register_test("retreat/snapshot_affordable_and_price",           Callable(RetreatTests, "_t_snapshot_affordable"))
	runner.register_test("retreat/return_home_free_at_zero_ase",            Callable(RetreatTests, "_t_return_home_free"))
	runner.register_test("retreat/success_returns_to_path_with_card",       Callable(RetreatTests, "_t_success_returns_to_path"))
	runner.register_test("retreat/success_costs_one_turn",                  Callable(RetreatTests, "_t_success_costs_one_turn"))
	runner.register_test("retreat/normal_fight_passed_objective_fight_open", Callable(RetreatTests, "_t_normal_passed_objective_open"))
	runner.register_test("retreat/objective_fight_offered_again_at_once",   Callable(RetreatTests, "_t_objective_offered_again"))
	runner.register_test("retreat/card_has_no_percent_or_odds",             Callable(RetreatTests, "_t_card_no_percent_or_odds"))
	runner.register_test("retreat/failed_or_denied_changes_no_stage_state", Callable(RetreatTests, "_t_failed_or_denied_no_stage_change"))
	runner.register_test("retreat/standoff_steps_back_and_costs_one_turn",  Callable(RetreatTests, "_t_standoff_steps_back"))
	runner.register_test("retreat/standoff_objective_fight_returns_later",  Callable(RetreatTests, "_t_standoff_objective_later"))
	runner.register_test("retreat/standoff_sanctum_button_from_second",     Callable(RetreatTests, "_t_standoff_sanctum_button"))
	runner.register_test("retreat/standoff_records_deaths_before_the_stall", Callable(RetreatTests, "_t_standoff_records_deaths"))
	runner.register_test("retreat/standoff_cause_only_from_recorded_events", Callable(RetreatTests, "_t_standoff_cause"))
	runner.register_test("retreat/standoff_fear_drop_first_standoff_only",  Callable(RetreatTests, "_t_standoff_fear_drop"))
	runner.register_test("retreat/standoff_rerun_applies_no_second_drop",   Callable(RetreatTests, "_t_standoff_rerun_no_second_drop"))
	runner.register_test("retreat/stall_level_from_streak_no_numbers",      Callable(RetreatTests, "_t_stall_level"))
	runner.register_test("retreat/prebattle_stalled_before",                Callable(RetreatTests, "_t_prebattle_stalled_before"))
	runner.register_test("retreat/stalled_fight_rerun_is_deterministic",    Callable(RetreatTests, "_t_stalled_rerun_deterministic"))
	runner.register_test("retreat/path_has_no_turn_limit",                  Callable(RetreatTests, "_t_no_turn_limit"))
	runner.register_test("retreat/passive_income_ignores_turns",            Callable(RetreatTests, "_t_passive_income_ignores_turns"))
	runner.register_test("retreat/roll_same_after_reload",                  Callable(RetreatTests, "_t_roll_same_after_reload"))
	runner.register_test("retreat/roll_ignores_tick",                       Callable(RetreatTests, "_t_roll_ignores_tick"))
	runner.register_test("retreat/attempt_count_saved_and_keys_differ",     Callable(RetreatTests, "_t_attempt_count_saved_and_keys_differ"))
	runner.register_test("retreat/retreat_passed_fight_returns_later",      Callable(RetreatTests, "_t_retreat_passed_fight_returns_later"))
	runner.register_test("retreat/retreat_passed_fight_only_target",        Callable(RetreatTests, "_t_retreat_passed_fight_only_target"))
	runner.register_test("retreat/retreat_marks_pass_turn",                 Callable(RetreatTests, "_t_retreat_marks_pass_turn"))
	runner.register_test("retreat/failed_retreat_spend_survives_reload",    Callable(RetreatTests, "_t_failed_spend_survives_reload"))


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

## Builds a minimal live echo actor dict with given speed and agi.
static func _echo(speed: int, agi: int) -> Dictionary:
	return {
		"faction": "echo", "is_dead": false, "is_structure": false,
		"stats": { "speed": speed, "agi": agi, "max_hp": 80 },
	}

## Builds a minimal live enemy actor dict with given speed and agi.
static func _enemy(speed: int, agi: int) -> Dictionary:
	return {
		"faction": "enemy", "is_dead": false, "is_structure": false,
		"stats": { "speed": speed, "agi": agi, "max_hp": 80 },
	}

## Returns the standard 5-tier config array used in balance.json.
static func _tier_cfg() -> Array:
	return [
		{ "min_delta":   10, "label": "Guaranteed", "success_pct": 100 },
		{ "min_delta":    3, "label": "Low",         "success_pct":  80 },
		{ "min_delta":   -2, "label": "Moderate",    "success_pct":  60 },
		{ "min_delta":   -9, "label": "Risky",       "success_pct":  40 },
		{ "min_delta": -9999,"label": "Dangerous",   "success_pct":  20 },
	]


# ──────────────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────────────

# Test 1: can_attempt_when_echo_faster
# Echo avg speed 8 > enemy avg speed 6 → can_attempt true.
static func _t_can_attempt_when_echo_faster() -> Dictionary:
	var actors: Array = [_echo(8, 10), _enemy(6, 10)]
	if not RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=true when echo speed (8) > enemy speed (6)" }
	return { "ok": true }


# Test 2: cannot_attempt_when_equal_speed
# Echo avg speed == enemy avg speed → can_attempt false (strictly greater required).
static func _t_cannot_attempt_when_equal_speed() -> Dictionary:
	var actors: Array = [_echo(6, 10), _enemy(6, 10)]
	if RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=false when echo speed (6) == enemy speed (6)" }
	return { "ok": true }


# Test 3: cannot_attempt_when_echo_slower
# Echo avg speed 4 < enemy avg speed 7 → can_attempt false.
static func _t_cannot_attempt_when_echo_slower() -> Dictionary:
	var actors: Array = [_echo(4, 10), _enemy(7, 10)]
	if RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=false when echo speed (4) < enemy speed (7)" }
	return { "ok": true }


# Test 4: tier_guaranteed_from_high_agi_delta
# Echo agi 30, enemy agi 15 → delta +15 ≥ +10 → Guaranteed tier (100%).
static func _t_tier_guaranteed() -> Dictionary:
	# Speed gate passes (echo faster).
	var actors: Array = [_echo(8, 30), _enemy(6, 15)]
	var tier: Dictionary = RetreatService.get_chance_tier(actors, _tier_cfg())
	if tier.is_empty():
		return { "ok": false, "error": "Expected a tier dict, got empty" }
	if str(tier.get("label", "")) != "Guaranteed":
		return { "ok": false, "error": "Expected label='Guaranteed', got: %s" % str(tier.get("label")) }
	if int(tier.get("success_pct", -1)) != 100:
		return { "ok": false, "error": "Expected success_pct=100, got: %d" % int(tier.get("success_pct")) }
	return { "ok": true }


# Test 5: tier_risky_from_negative_agi_delta
# Echo agi 10, enemy agi 15 → delta -5 → Risky tier (40%).
static func _t_tier_risky() -> Dictionary:
	var actors: Array = [_echo(8, 10), _enemy(6, 15)]
	var tier: Dictionary = RetreatService.get_chance_tier(actors, _tier_cfg())
	if tier.is_empty():
		return { "ok": false, "error": "Expected a tier dict, got empty" }
	if str(tier.get("label", "")) != "Risky":
		return { "ok": false, "error": "Expected label='Risky', got: %s" % str(tier.get("label")) }
	if int(tier.get("success_pct", -1)) != 40:
		return { "ok": false, "error": "Expected success_pct=40, got: %d" % int(tier.get("success_pct")) }
	return { "ok": true }


# Test 6: roll_success_at_100pct
# success_pct=100 → always returns { success: true } regardless of RNG.
static func _t_roll_success_at_100() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(10):
		var result: Dictionary = RetreatService.roll_retreat(100, rng)
		if not bool(result.get("success", false)):
			return { "ok": false, "error": "Expected success=true at 100%% success_pct (roll %d)" % i }
	return { "ok": true }


# Test 7: roll_failure_at_0pct
# success_pct=0 → always returns { success: false }.
static func _t_roll_failure_at_0() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(10):
		var result: Dictionary = RetreatService.roll_retreat(0, rng)
		if bool(result.get("success", true)):
			return { "ok": false, "error": "Expected success=false at 0%% success_pct (roll %d)" % i }
	return { "ok": true }


# Test 8: excludes_dead_and_structures
# A dead echo and a structure enemy should not affect averages.
# Live echo speed 8, dead echo speed 1 (should be ignored) → avg echo speed = 8.
# Live enemy speed 6, structure speed 100 (should be ignored) → avg enemy speed = 6.
# → can_attempt should be true (8 > 6).
static func _t_excludes_dead_and_structures() -> Dictionary:
	var dead_echo: Dictionary = {
		"faction": "echo", "is_dead": true, "is_structure": false,
		"stats": { "speed": 1, "agi": 1, "max_hp": 80 },
	}
	var shrine: Dictionary = {
		"faction": "enemy", "is_dead": false, "is_structure": true,
		"stats": { "speed": 100, "agi": 100, "max_hp": 200 },
	}
	var actors: Array = [_echo(8, 10), dead_echo, _enemy(6, 10), shrine]
	if not RetreatService.can_attempt(actors):
		return { "ok": false, "error": "Expected can_attempt=true; dead/structure actors must be excluded from speed avg" }
	return { "ok": true }


# ──────────────────────────────────────────────────────────────────────────────
# V2-ECONOMY-004 step 5.4: price 10 and denial (D-46, D-79). These drive a real FlowRuntime.
# ──────────────────────────────────────────────────────────────────────────────

## Runs one retreat dispatch at a fixed balance. The action carries a fake price (999) on purpose:
## the handler must ignore it and read the config.
static func _retreat_at(tag: String, ase: int, success_pct: int) -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for %s" % tag }
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.save_data["economy"]["ase"] = ase
	var snap: Dictionary = (env["runtime"] as FlowRuntime).dispatch(
		{ "type": "encounter.retreat", "ase_cost": 999, "success_pct": success_pct })
	return { "ok": true, "flow_ctx": flow_ctx, "snap": snap, "ase_after": int(flow_ctx.save_data["economy"]["ase"]) }


static func _t_price_from_config() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var cost: int = RetreatService.get_ase_cost(config)
	if cost != 10:
		return { "ok": false, "error": "expected retreat price 10 from data.combat.retreat_ase_cost, got %d" % cost }
	return { "ok": true }


static func _t_denied_below_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_denied", 9, 100)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	if int(r["ase_after"]) != 9:
		return { "ok": false, "error": "denied retreat changed the balance: 9 -> %d" % int(r["ase_after"]) }
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "denied retreat cleared the encounter" }
	if flow_ctx.pending_scout_return_ase != 0:
		return { "ok": false, "error": "denied retreat set a partial payout" }
	var denial: Variant = (r["snap"] as Dictionary).get("data", {}).get("retreat_denied", null)
	if not (denial is Dictionary) or str(denial.get("reason", "")) != "insufficient_ase" or int(denial.get("ase_cost", 0)) != 10:
		return { "ok": false, "error": "no retreat_denied outcome in the returned snapshot: %s" % str(denial) }
	return { "ok": true }


static func _t_allowed_at_exact_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_exact", 10, 100)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 0:
		return { "ok": false, "error": "expected balance 0 after a 10 Ase retreat from 10, got %d" % int(r["ase_after"]) }
	if (r["flow_ctx"] as FlowContext).encounter_ctx != null:
		return { "ok": false, "error": "paid retreat at 100%% did not leave the encounter" }
	return { "ok": true }


static func _t_allowed_above_price() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_above", 25, 100)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 15:
		return { "ok": false, "error": "expected balance 15 after retreat from 25, got %d" % int(r["ase_after"]) }
	return { "ok": true }


static func _t_failed_retreat_spends() -> Dictionary:
	var r: Dictionary = _retreat_at("rt_fail", 25, 0)
	if not bool(r.get("ok", false)):
		return r
	if int(r["ase_after"]) != 15:
		return { "ok": false, "error": "a failed retreat must still spend 10: expected 15, got %d" % int(r["ase_after"]) }
	if (r["flow_ctx"] as FlowContext).encounter_ctx == null:
		return { "ok": false, "error": "a failed retreat at 0%% must leave combat running" }
	return { "ok": true }


static func _t_snapshot_affordable() -> Dictionary:
	for case in [[9, false], [10, true], [11, true]]:
		var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "rt_snap_%d" % case[0])
		if env.is_empty():
			return { "ok": false, "error": "setup failed" }
		var flow_ctx: FlowContext = env["flow_ctx"]
		flow_ctx.save_data["economy"]["ase"] = case[0]
		var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 1)
		var data: Dictionary = snap.get("data", {})
		if int(data.get("retreat_ase_cost", -1)) != 10 or bool(data.get("retreat_affordable", not case[1])) != case[1]:
			return { "ok": false, "error": "balance %d: cost=%s affordable=%s" % [case[0], str(data.get("retreat_ase_cost")), str(data.get("retreat_affordable"))] }
	return { "ok": true }


static func _t_return_home_free() -> Dictionary:
	var env: Dictionary = PendingResultTests._drive_withdrawal("rt_home", 0)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var awarded: int = int(PendingResultTests._data_of(env["card"]).get("ase_awarded", -1))
	var ase: int = int(runtime.get_save_data()["economy"]["ase"])
	if ase != awarded:
		return { "ok": false, "error": "return home at 0 Ase: balance %d != partial %d, so something was spent" % [ase, awarded] }
	return { "ok": true }


# ──────────────────────────────────────────────────────────────────────────────
# V2-ECONOMY-004 step 6.2 (D-106): a successful retreat returns the party to the path.
# ──────────────────────────────────────────────────────────────────────────────

## Engages the first situation of stage.0 (as production does: last_situation_id and the objective
## index), then retreats. `objective` true = the fight belongs to an objective (index >= 0).
static func _engaged_retreat(tag: String, objective: bool, success_pct: int = 100, ase: int = 50, pad: int = 0) -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, tag)
	if env.is_empty():
		return { "ok": false, "error": "setup failed for %s" % tag }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var emap: Dictionary = stage["explore_map"]
	var sit: Dictionary = (emap["situations"] as Array)[0]
	sit["revealed"] = true
	sit["passed"] = false
	emap["last_situation_id"] = str(sit["id"])
	emap["turn_count"] = 3
	emap["locked"] = true
	flow_ctx.active_encounter_objective_index = 0 if objective else -1
	flow_ctx.save_data["economy"]["ase"] = ase
	for _i in range(pad):
		(env["runtime"] as FlowRuntime).dispatch({ "type": "debug.seed.show" })
	var encounter_id: String = flow_ctx.encounter_ctx.encounter_id
	var card: Dictionary = (env["runtime"] as FlowRuntime).dispatch(
		{ "type": "encounter.retreat", "success_pct": success_pct })
	return { "ok": true, "encounter_id": encounter_id, "env": env, "runtime": env["runtime"], "flow_ctx": flow_ctx, "card": card, "sit_id": str(sit["id"]) }


static func _explore_map_of(flow_ctx: FlowContext) -> Dictionary:
	return FlowStageExploreState._get_current_stage(flow_ctx).get("explore_map", {})


static func _sit_of(flow_ctx: FlowContext, sit_id: String) -> Dictionary:
	for s_v in (_explore_map_of(flow_ctx).get("situations", []) as Array):
		if str((s_v as Dictionary).get("id", "")) == sit_id:
			return s_v
	return {}


static func _t_success_returns_to_path() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_path", false)
	if not bool(r.get("ok", false)):
		return r
	var card: Dictionary = r["card"]
	var data: Dictionary = card.get("data", {})
	var cta: Dictionary = (card.get("actions", {}) as Dictionary).get("cta.continue", {})
	var m: Array = []
	if str(card.get("type", "")) != FlowStateIds.RESOLVE or str(data.get("run_type", "")) != "retreat_return":
		m.append("expected a flow.resolve card with run_type retreat_return, got %s / %s" % [card.get("type"), data.get("run_type")])
	if str(data.get("retreat_outcome", "")) != "pulled_back" or data.get("can_reenter", null) != false:
		m.append("expected retreat_outcome pulled_back and can_reenter false for a normal fight: %s" % str(data))
	if str(cta.get("type", "")) != "stage.retreat_return" or cta.has("to"):
		m.append("expected cta.continue stage.retreat_return, got %s" % str(cta))
	if m.is_empty():
		var back: Dictionary = (r["runtime"] as FlowRuntime).dispatch({ "type": "stage.retreat_return" })
		if str(back.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
			m.append("cta.continue did not return to stage_explore: %s" % str(back.get("type", "")))
		# The same action from any other card must do nothing.
		var again: Dictionary = (r["runtime"] as FlowRuntime).dispatch({ "type": "stage.retreat_return" })
		if str(again.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
			m.append("a repeated stage.retreat_return left stage_explore: %s" % str(again.get("type", "")))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_success_costs_one_turn() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_turn", false)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var turns := int(_explore_map_of(flow_ctx).get("turn_count", -1))
	var ase := int(flow_ctx.save_data["economy"]["ase"])
	var m: Array = []
	if turns != 4:
		m.append("turn_count 3 -> expected 4 after a retreat, got %d" % turns)
	if ase != 40:
		m.append("expected 50 - 10 Ase, got %d" % ase)
	if (r["card"] as Dictionary).get("data", {}).has("ase_awarded"):
		m.append("the retreat card carries an amount")
	var st := FlowStageExploreState._get_current_stage(flow_ctx)
	if st.has("settle_count") or st.has("settled_ase"):
		m.append("a retreat settled")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_normal_passed_objective_open() -> Dictionary:
	var m: Array = []
	for objective in [false, true]:
		var r: Dictionary = _engaged_retreat("rt_pass_%s" % str(objective), objective)
		if not bool(r.get("ok", false)):
			return r
		var flow_ctx: FlowContext = r["flow_ctx"]
		var sit: Dictionary = _sit_of(flow_ctx, str(r["sit_id"]))
		var passed := bool(sit.get("passed", false))
		var reoffer := str(_explore_map_of(flow_ctx).get("retreat_reoffer_id", ""))
		var can: Variant = (r["card"] as Dictionary).get("data", {}).get("can_reenter", null)
		if objective and (passed or reoffer != str(r["sit_id"]) or can != true):
			m.append("objective fight: passed=%s reoffer='%s' can_reenter=%s" % [passed, reoffer, can])
		if not objective and (not passed or not reoffer.is_empty() or can != false):
			m.append("normal fight: passed=%s reoffer='%s' can_reenter=%s" % [passed, reoffer, can])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## An objective fight is offered again as soon as the party is back; a normal fight is not.
## last_situation_id must survive the entry, because the victory path resolves the situation by it.
static func _t_objective_offered_again() -> Dictionary:
	var m: Array = []
	for objective in [true, false]:
		var r: Dictionary = _engaged_retreat("rt_again_%s" % str(objective), objective)
		if not bool(r.get("ok", false)):
			return r
		var back: Dictionary = (r["runtime"] as FlowRuntime).dispatch({ "type": "stage.retreat_return" })
		var pending: Variant = back.get("data", {}).get("situation_pending", null)
		var emap := _explore_map_of(r["flow_ctx"])
		if objective:
			if not (pending is Dictionary) or str((pending as Dictionary).get("situation_id", "")) != str(r["sit_id"]):
				m.append("objective fight not offered on return: %s" % str(pending))
			if str(emap.get("last_situation_id", "")) != str(r["sit_id"]):
				m.append("last_situation_id lost on return: '%s'" % str(emap.get("last_situation_id", "")))
		elif pending is Dictionary and not (pending as Dictionary).is_empty():
			m.append("normal fight offered again at once: %s" % str(pending))
		if emap.has("retreat_reoffer_id"):
			m.append("the re-offer key outlived the entry")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_card_no_percent_or_odds() -> Dictionary:
	var card: Dictionary = VentureResolveSnapshotBuilder.build_retreat_return_snapshot(true, 1)
	var text := JSON.stringify(card).to_lower()
	var m: Array = []
	for bad in ["%", "percent", "odds", "chance", "success_pct", "half", "ase_awarded", "ekwan_awarded"]:
		if text.contains(bad):
			m.append("card contains '%s'" % bad)
	return { "ok": m.is_empty(), "error": "; ".join(m) + " in " + text }


## A failed roll starts combat, and a denied retreat changes nothing: neither costs a turn nor passes the fight.
static func _t_failed_or_denied_no_stage_change() -> Dictionary:
	var m: Array = []
	for case in [["fail", 0, 50], ["denied", 100, 9]]:
		var r: Dictionary = _engaged_retreat("rt_nochange_" + case[0], false, case[1], case[2])
		if not bool(r.get("ok", false)):
			return r
		var flow_ctx: FlowContext = r["flow_ctx"]
		var emap := _explore_map_of(flow_ctx)
		if int(emap.get("turn_count", -1)) != 3 or bool(_sit_of(flow_ctx, str(r["sit_id"])).get("passed", false)) or emap.has("retreat_reoffer_id"):
			m.append("%s changed the stage: turn %s" % [case[0], str(emap.get("turn_count"))])
		if str((r["card"] as Dictionary).get("data", {}).get("run_type", "")) == "retreat_return":
			m.append("%s published the pulled-back card" % case[0])
		if flow_ctx.encounter_ctx == null:
			m.append("%s dropped the encounter" % case[0])
		if case[0] == "fail" and (flow_ctx.encounter_ctx.combat_state as Dictionary).is_empty():
			m.append("a failed retreat did not start combat")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ──────────────────────────────────────────────────────────────────────────────
# D-116: a stalemate is a standoff. The party steps back onto the path.
# ──────────────────────────────────────────────────────────────────────────────

static func _echo_actor(ectx: EncounterContext, n: int = 0) -> Dictionary:
	var seen := 0
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "echo":
			if seen == n:
				return a_v
			seen += 1
	return {}


## Records one round in which `actor` refused, through the same function _end_round calls.
static func _refuse(ectx: EncounterContext, actor: Dictionary, round_no: int = 1) -> void:
	ectx.combat_state["round_counter"] = round_no
	ectx.last_round_results = [{ "action_type": "actor.refuse", "source_id": str(actor["id"]),
		"source_name": str(actor["name"]) }]
	StandoffService.record_round(ectx, false)


static func _roster_entry(flow_ctx: FlowContext, id: String) -> Dictionary:
	for e_v in flow_ctx.save_data["sanctum"]["roster"]:
		if str((e_v as Dictionary).get("id", "")) == id:
			return e_v
	return {}


## An engaged fight (normal or objective) that then stalls and ends as a standoff, with one earlier
## unsettled pack row on the stage. Returns the harness dict plus the card and the pack rows before.
static func _standoff(tag: String, objective: bool, refuse: bool = true, prior_count: int = 0) -> Dictionary:
	var r: Dictionary = _engaged_retreat(tag, objective, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	EarningsService.add_row(stage, EarningsService.make_row("enc:old", "encounter", "fight", 6, 0))
	if prior_count > 0:
		_sit_of(flow_ctx, str(r["sit_id"]))["standoff_count"] = prior_count
	r["rows_before"] = JSON.stringify(EarningsService.rows_of(stage))
	r["ase_before"] = int(flow_ctx.save_data["economy"]["ase"])
	if refuse:
		var echo := _echo_actor(flow_ctx.encounter_ctx)
		r["echo"] = echo
		_refuse(flow_ctx.encounter_ctx, echo, 4)
	(r["runtime"] as FlowRuntime)._resolve_forced_retreat(99)
	r["card"] = flow_ctx.last_snapshot
	return r


## The party steps back: one turn, no Ase, no pack touched, the fight marked passed and counted, no amount on
## the card. Replaces the test that pinned the old Sanctum exit (a free exit with the packs intact).
static func _t_standoff_steps_back() -> Dictionary:
	var r: Dictionary = _standoff("rt_standoff", false)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var card: Dictionary = r["card"]
	var data: Dictionary = card.get("data", {})
	var actions: Dictionary = card.get("actions", {})
	var emap := _explore_map_of(flow_ctx)
	var sit := _sit_of(flow_ctx, str(r["sit_id"]))
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var m: Array = []
	if str(card.get("type", "")) != FlowStateIds.RESOLVE or str(data.get("run_type", "")) != "standoff":
		m.append("expected a flow.resolve card with run_type standoff, got %s / %s" % [card.get("type"), data.get("run_type")])
	var keys: Array = data.keys()
	keys.sort()
	if keys != ["calmed_names", "can_go_sanctum", "cause", "froze_names", "run_type", "standoff_count", "standoff_outcome"]:
		m.append("card data keys: %s" % str(keys))
	if str(data.get("standoff_outcome", "")) != "nobody_moved" or int(data.get("standoff_count", 0)) != 1 \
			or data.get("can_go_sanctum", null) != false or str(data.get("cause", "")) != "froze" \
			or data.get("froze_names", null) != [str((r["echo"] as Dictionary)["name"])]:
		m.append("card facts: %s" % str(data))
	var cta: Dictionary = actions.get("cta.continue", {})
	if actions.keys() != ["cta.continue"] or str(cta.get("type", "")) != "stage.standoff_return" or cta.has("to"):
		m.append("first standoff must offer one button, stage.standoff_return: %s" % str(actions))
	var text := JSON.stringify(card).to_lower()
	for bad in ["%", "percent", "odds", "ase_awarded", "ekwan_awarded", "reward_breakdown", "success_pct"]:
		if text.contains(bad):
			m.append("card contains '%s'" % bad)
	if int(emap.get("turn_count", -1)) != 4:
		m.append("turn_count 3 -> expected 4, got %s" % str(emap.get("turn_count")))
	if int(flow_ctx.save_data["economy"]["ase"]) != int(r["ase_before"]):
		m.append("a standoff changed Ase")
	if not bool(sit.get("passed", false)) or int(sit.get("retreat_pass_turn", -1)) != 4 or int(sit.get("standoff_count", 0)) != 1:
		m.append("fight not marked for a later turn: %s" % str(sit))
	if JSON.stringify(EarningsService.rows_of(stage)) != str(r["rows_before"]):
		m.append("a standoff changed the packs: %s" % JSON.stringify(EarningsService.rows_of(stage)))
	if stage.has("settle_count") or stage.has("settled_ase") or emap.has("retreat_reoffer_id"):
		m.append("a standoff settled or re-offered at once")
	if flow_ctx.encounter_ctx != null:
		m.append("the encounter was not dropped")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116: an OBJECTIVE fight is not offered at once after a standoff (unlike a chosen retreat). It carries the
## later-turn marker, and Tier 4 offers it only on a later turn, also when it is the only target left.
static func _t_standoff_objective_later() -> Dictionary:
	var r: Dictionary = _standoff("rt_standoff_obj", true)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var m: Array = []
	var sit := _sit_of(flow_ctx, str(r["sit_id"]))
	if not bool(sit.get("passed", false)) or int(sit.get("retreat_pass_turn", -1)) != 4 or _explore_map_of(flow_ctx).has("retreat_reoffer_id"):
		m.append("objective fight after a standoff: %s" % str(sit))
	var back: Dictionary = (r["runtime"] as FlowRuntime).dispatch({ "type": "stage.standoff_return" })
	var pending: Variant = back.get("data", {}).get("situation_pending", null)
	if str(back.get("type", "")) != FlowStateIds.STAGE_EXPLORE or (pending is Dictionary and not (pending as Dictionary).is_empty()):
		m.append("objective fight offered at once after a standoff: %s" % str(pending))
	# Tier 4, both kinds of fight, same turn and later turn.
	var cs := ConfigService.new()
	cs.load_balance()
	var ctx := FlowContext.new()
	ctx.realm_id = "realm.01"
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var session := ActiveStageService.new(ctx, cs, logger)
	var directive: Dictionary = ConfigService.get_directives_cfg(cs).get("directive.scout_carefully", {})
	var walkable: Dictionary = {}
	var explored: Dictionary = {}
	for c in 6:
		for rw in 3:
			walkable["%d,%d" % [c, rw]] = true
			explored["%d,%d" % [c, rw]] = true
	for case in [["objective, same turn", true, 4, 4, false], ["objective, later turn", true, 4, 5, true],
			["normal, same turn", false, 4, 4, false], ["normal, later turn", false, 4, 5, true]]:
		var fight: Dictionary = SituationModel.make("fight", SituationModel.TYPE_NPC, 4, 1, 900, bool(case[1]))
		fight["revealed"] = true
		fight["passed"] = true
		fight["retreat_pass_turn"] = case[2]
		var em := { "situations": [fight], "party_pos": { "col": 0, "row": 1 }, "turn_count": case[3] }
		var pick := session.find_explore_target(em, directive, walkable, explored, { "index": 0 })
		if (str(pick.get("id", "")) == "fight") != bool(case[4]):
			m.append("%s: expected offered=%s, got %s" % [case[0], case[4], str(pick.get("id", "<none>"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116 (3): the first standoff on a fight offers one button; the second also offers the Sanctum. The second
## is a REAL second standoff: the fight is entered again and stalls again. The Sanctum button sends the same
## action with to_sanctum and the explore snapshot then asks the UI to open the return confirmation, once.
static func _t_standoff_sanctum_button() -> Dictionary:
	var r: Dictionary = _standoff("rt_standoff_two", false)
	if not bool(r.get("ok", false)):
		return r
	var runtime: FlowRuntime = r["runtime"]
	var flow_ctx: FlowContext = r["flow_ctx"]
	var m: Array = []
	# to_sanctum on the first card is ignored: the card did not offer it.
	var first: Dictionary = runtime.dispatch({ "type": "stage.standoff_return", "to_sanctum": true })
	if str(first.get("type", "")) != FlowStateIds.STAGE_EXPLORE or first.get("data", {}).has("return_confirm_requested"):
		m.append("first standoff: to_sanctum was honoured or the card did not return to the path")
	# The party arrives at the same fight again (arrival sets last_situation_id) and it stalls again.
	_explore_map_of(flow_ctx)["last_situation_id"] = str(r["sit_id"])
	flow_ctx.encounter_ctx = null
	FlowEncounterState.new().enter(flow_ctx, 100)
	if flow_ctx.encounter_ctx == null:
		return { "ok": false, "error": "could not enter the fight again" }
	_refuse(flow_ctx.encounter_ctx, _echo_actor(flow_ctx.encounter_ctx), 6)
	runtime._resolve_forced_retreat(101)
	var card: Dictionary = flow_ctx.last_snapshot
	var data: Dictionary = card.get("data", {})
	var actions: Dictionary = card.get("actions", {})
	var sanctum: Dictionary = actions.get("cta.sanctum", {})
	if int(data.get("standoff_count", 0)) != 2 or data.get("can_go_sanctum", null) != true:
		m.append("second standoff facts: %s" % str(data))
	if str(sanctum.get("type", "")) != "stage.standoff_return" or sanctum.get("to_sanctum", null) != true \
			or str((actions.get("cta.continue", {}) as Dictionary).get("type", "")) != "stage.standoff_return":
		m.append("second standoff buttons: %s" % str(actions))
	var to_path: Dictionary = {}
	var to_sanctum: Dictionary = {}
	# Press the plain button on a copy of the state, then the Sanctum button.
	to_sanctum = runtime.dispatch({ "type": "stage.standoff_return", "to_sanctum": true })
	if str(to_sanctum.get("type", "")) != FlowStateIds.STAGE_EXPLORE or to_sanctum.get("data", {}).get("return_confirm_requested", null) != true:
		m.append("the Sanctum button did not return to the path with return_confirm_requested: %s" % str(to_sanctum.get("data", {}).keys()))
	if flow_ctx.pending_return_confirm:
		m.append("the one-shot flag outlived the dispatch")
	to_path = runtime.dispatch({ "type": "stage.dismiss_overlay" })
	if to_path.get("data", {}).has("return_confirm_requested"):
		m.append("return_confirm_requested stayed on a later snapshot")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116 (2): deaths before the stall count. The fight's dead party Echoes join the stage death record, and the
## earlier deaths stay. These are the names the stipend, the Thread flag and the rank cap read.
static func _t_standoff_records_deaths() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_standoff_dead", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	stage["lost_echo_names"] = ["Earlier"]
	var dead := _echo_actor(flow_ctx.encounter_ctx, 1)
	dead["is_dead"] = true
	(r["runtime"] as FlowRuntime)._resolve_forced_retreat(99)
	var names: Array = ActiveStageService.stage_lost_echo_names(flow_ctx)
	var m: Array = []
	if names != ["Earlier", str(dead["name"])]:
		m.append("expected the earlier death and this fight's death on the stage record, got %s" % str(names))
	if ActiveStageService.lost_echo_names_with(flow_ctx, []) != names:
		m.append("the rule the stipend and the Thread flag read does not return the record")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116 (4b): the cause comes from recorded events only. A refusal by a party Echo is "froze" (newest first,
## two names at most); a guard with no refusal is "blocked"; an enemy refusal or nothing is "unknown". Progress
## clears the record. No recorded event marks a position block, so it reads as "unknown".
static func _t_standoff_cause() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_cause", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var ectx: EncounterContext = (r["flow_ctx"] as FlowContext).encounter_ctx
	var a := _echo_actor(ectx, 0)
	var b := _echo_actor(ectx, 1)
	var c := _echo_actor(ectx, 2)
	var m: Array = []
	var enemy: Dictionary = {}
	for x_v in ectx.actors:
		if x_v is Dictionary and str((x_v as Dictionary).get("faction", "")) == "enemy":
			enemy = x_v
			break
	StandoffService.record_round(ectx, true)
	_refuse(ectx, enemy, 1)
	if not (ectx.stall_record.get("refused", []) as Array).is_empty():
		m.append("an enemy refusal was recorded as a party Echo freezing")
	ectx.last_round_results = [{ "action_type": "actor.guard", "source_id": str(enemy["id"]), "source_name": "x" }]
	StandoffService.record_round(ectx, false)
	_refuse(ectx, a, 2)
	_refuse(ectx, b, 3)
	_refuse(ectx, c, 4)
	_refuse(ectx, a, 5)
	var order: Array = (ectx.stall_record["refused"] as Array).map(func(e): return str((e as Dictionary)["name"]))
	if order != [str(b["name"]), str(c["name"]), str(a["name"])]:
		m.append("refusal order (oldest first, latest wins): %s" % str(order))
	if StandoffService.latest_froze_name(ectx) != str(a["name"]):
		m.append("latest_froze_name: %s" % StandoffService.latest_froze_name(ectx))
	StandoffService.record_round(ectx, true)
	if not ectx.stall_record.is_empty() or StandoffService.latest_froze_name(ectx) != "":
		m.append("progress did not clear the record")
	# The facts the card gets.
	var cases := [["froze", [a, b, c]], ["blocked", []], ["unknown", []]]
	for case in cases:
		var e2: Dictionary = _engaged_retreat("rt_cause_" + case[0], false, 0, 50)
		var x2: EncounterContext = (e2["flow_ctx"] as FlowContext).encounter_ctx
		StandoffService.record_round(x2, true)
		for who in case[1]:
			_refuse(x2, _echo_actor(x2, ((case[1] as Array).find(who))), 2)
		if case[0] == "blocked":
			x2.last_round_results = [{ "action_type": "actor.guard", "source_id": "x", "source_name": "x" }]
			StandoffService.record_round(x2, false)
		var facts := StandoffService.resolve(e2["flow_ctx"], 50)
		if str(facts["cause"]) != case[0] or (facts["froze_names"] as Array).size() != (2 if case[0] == "froze" else 0):
			m.append("%s: facts %s" % [case[0], str(facts)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-118 + D-116 (5): a standoff writes the fight's final fear to the roster (as every ending fight does), then the
## fear drop falls once, on the FIRST standoff, for each party Echo that froze: written-back fear minus
## data.combat.stalemate.standoff_fear_drop, clamped at 0. Only Echoes whose fear fell are named as calmed.
## Replaces the old test that set the SAVED fear first, because the saved fear is now overwritten by the fight's.
static func _t_standoff_fear_drop() -> Dictionary:
	var m: Array = []
	for case in [["95 -> 85", 95, 0, 85, true], ["5 -> 0", 5, 0, 0, true], ["0 cannot fall", 0, 0, 0, false],
			["second standoff, written back, no drop", 95, 1, 95, false]]:
		var r: Dictionary = _engaged_retreat("rt_fear_%s" % str(case[0]).left(3), false, 0, 50)
		if not bool(r.get("ok", false)):
			return r
		var flow_ctx: FlowContext = r["flow_ctx"]
		var echo := _echo_actor(flow_ctx.encounter_ctx)
		var entry := _roster_entry(flow_ctx, str(echo["id"]))
		entry["emotion"] = { "faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 30, "fear_base": 0 }
		echo["fear"] = case[1]
		var bystander := _echo_actor(flow_ctx.encounter_ctx, 1)
		bystander["fear"] = 40
		if int(case[2]) > 0:
			_sit_of(flow_ctx, str(r["sit_id"]))["standoff_count"] = case[2]
		_refuse(flow_ctx.encounter_ctx, echo, 5)
		(r["runtime"] as FlowRuntime)._resolve_forced_retreat(60)
		var calmed: Array = flow_ctx.last_snapshot["data"]["calmed_names"]
		var after := int((entry["emotion"] as Dictionary)["fear_current"])
		if after != case[3] or (calmed == [str(echo["name"])]) != bool(case[4]) or (not bool(case[4]) and not calmed.is_empty()):
			m.append("%s: saved fear %d, calmed %s" % [case[0], after, str(calmed)])
		if int(_roster_entry(flow_ctx, str(bystander["id"]))["emotion"]["fear_current"]) != 40:
			m.append("%s: an Echo that did not freeze changed fear (write-back only)" % case[0])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-118: the drop is not applied twice across reruns. First standoff: 95 written back, 85 after the drop, named
## as calmed. The fight is entered again; the Echo starts at 85, freezes again at 90 and the second standoff
## writes 90 back with no drop and no calmed name.
static func _t_standoff_rerun_no_second_drop() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_fear_rerun", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var runtime: FlowRuntime = r["runtime"]
	var flow_ctx: FlowContext = r["flow_ctx"]
	var echo := _echo_actor(flow_ctx.encounter_ctx)
	var id := str(echo["id"])
	echo["fear"] = 95
	_refuse(flow_ctx.encounter_ctx, echo, 3)
	runtime._resolve_forced_retreat(70)
	var m: Array = []
	var first: Dictionary = flow_ctx.last_snapshot["data"]
	if int(_roster_entry(flow_ctx, id)["emotion"]["fear_current"]) != 85 or first["calmed_names"] != [str(echo["name"])]:
		m.append("first standoff: saved fear %s, calmed %s" % [str(_roster_entry(flow_ctx, id)["emotion"]["fear_current"]), str(first["calmed_names"])])
	_explore_map_of(flow_ctx)["last_situation_id"] = str(r["sit_id"])
	flow_ctx.encounter_ctx = null
	FlowEncounterState.new().enter(flow_ctx, 100)
	var echo2 := _echo_actor(flow_ctx.encounter_ctx)
	echo2["fear"] = 90
	_refuse(flow_ctx.encounter_ctx, echo2, 4)
	runtime._resolve_forced_retreat(71)
	var second: Dictionary = flow_ctx.last_snapshot["data"]
	if int(_roster_entry(flow_ctx, id)["emotion"]["fear_current"]) != 90 or not (second["calmed_names"] as Array).is_empty() \
			or int(second["standoff_count"]) != 2:
		m.append("second standoff: saved fear %s, calmed %s, count %s" % [str(_roster_entry(flow_ctx, id)["emotion"]["fear_current"]), str(second["calmed_names"]), str(second["standoff_count"])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116 (6): stall_level is 0 below the first threshold, 1 from it, 2 from the second (0.5 and 0.8 of a limit of 15
## are streaks 8 and 12). It is derived, so a progress round clears it, and the snapshot carries no streak and no limit.
static func _t_stall_level() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_level", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var cfg: Dictionary = ectx.stalemate_cfg
	var m: Array = []
	var seen: Array = []
	for streak in range(0, 16):
		ectx.combat_state["no_progress_streak"] = streak
		ectx.combat_state["no_progress_round_limit"] = 15
		seen.append(StandoffService.level(ectx.combat_state, cfg))
	var want: Array = []
	for streak in range(0, 16):
		want.append(0 if streak < 8 else (1 if streak < 12 else 2))
	if seen != want:
		m.append("levels for streak 0..15: %s" % str(seen))
	if StandoffService.level(ectx.combat_state, {}) != 0:
		m.append("a missing threshold must switch the warning off")
	ectx.combat_state["no_progress_streak"] = 13
	_refuse(ectx, _echo_actor(ectx), 9)
	var snap_a: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 5)
	var data: Dictionary = snap_a["data"]
	if int(data.get("stall_level", -1)) != 2 or str(data.get("stall_froze_name", "")) != str(_echo_actor(ectx)["name"]):
		m.append("round snapshot: stall_level %s, stall_froze_name '%s'" % [str(data.get("stall_level")), str(data.get("stall_froze_name"))])
	for key in data.keys():
		if str(key).contains("streak") or str(key).contains("limit") or str(key).contains("no_progress"):
			m.append("the round snapshot leaks a counter: %s" % str(key))
	if JSON.stringify(EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 5)) != JSON.stringify(snap_a):
		m.append("build_round_snapshot is not pure with the stall keys")
	ectx.combat_state["no_progress_streak"] = 0
	StandoffService.record_round(ectx, true)
	var snap_b: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 6)
	if int(snap_b["data"].get("stall_level", -1)) != 0 or str(snap_b["data"].get("stall_froze_name", "x")) != "":
		m.append("progress did not clear the warning")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-116 (7): the round snapshot of the engaged situation says whether it has stalled before.
static func _t_prebattle_stalled_before() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_prebattle", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var m: Array = []
	var before: Variant = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 5)["data"].get("stalled_before", null)
	_sit_of(flow_ctx, str(r["sit_id"]))["standoff_count"] = 1
	var after: Variant = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 6)["data"].get("stalled_before", null)
	if before != false or after != true:
		m.append("stalled_before: expected false then true, got %s then %s" % [str(before), str(after)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Item 9c. A stalled fight that is entered again with unchanged inputs stalls the same way, round by round,
## although the dispatch counter, the stage turn and the retreat attempts have all moved on. Nothing in the fight reads them.
static func _t_stalled_rerun_deterministic() -> Dictionary:
	var env: Dictionary = CombatRoundtripIntegrationTests._setup_no_progress("standoff_rerun")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var limit := CombatRoundtripIntegrationTests._no_progress_round_limit(runtime)
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	stage["explore_map"] = { "turn_count": 3, "last_situation_id": "", "situations": [] }
	stage["retreat_attempts"] = 2
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	var first := _stall_trace(runtime, flow_ctx, limit)
	if int(_explore_map_of(flow_ctx).get("turn_count", -1)) != 4:
		return { "ok": false, "error": "the standoff did not move the stage turn, so the rerun proves nothing" }
	flow_ctx.encounter_id = "realm.01.stage.0.standoff_rerun"
	FlowEncounterState.new().enter(flow_ctx, 500)
	if flow_ctx.encounter_ctx == null or not CombatRoundtripIntegrationTests._trim_to_stalled_pair(flow_ctx.encounter_ctx):
		return { "ok": false, "error": "could not enter the fight again" }
	for _i in range(9):
		runtime.dispatch({ "type": "debug.seed.show" })
	var second := _stall_trace(runtime, flow_ctx, limit)
	var m: Array = []
	if first.is_empty() or first != second:
		m.append("the rerun differs: first %d chars, second %d chars" % [first.length(), second.length()])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Every round: the streak, the round counter and each actor's cell, hit points and flags.
static func _stall_trace(runtime: FlowRuntime, flow_ctx: FlowContext, limit: int) -> String:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var trace: Array = []
	runtime.dispatch({ "type": "combat.init" })
	for _r in range(limit):
		if flow_ctx.encounter_ctx == null:
			break
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard := 0
		while guard < 40 and flow_ctx.encounter_ctx != null:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)) or str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({ "type": "combat.next_actor" })
		var row: Array = [int(ectx.combat_state.get("round_counter", -1)), int(ectx.combat_state.get("no_progress_streak", -1))]
		for a_v in ectx.actors:
			var a: Dictionary = a_v
			row.append([str(a["id"]), a.get("grid_pos", {}), int(a.get("current_hp", -1)), bool(a.get("is_dead", false)), int(a.get("fear", -1)), int(a.get("morale", -1))])
		trace.append(row)
	return JSON.stringify(trace) if flow_ctx.encounter_ctx == null and trace.size() == limit else ""


## Item 9a. A path has no turn limit: a stage that has run for 100000 turns still advances.
static func _t_no_turn_limit() -> Dictionary:
	var env := VentureCharacterizationTests._setup_explore_env("rt_no_limit")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = runtime.flow_ctx
	var emap := _explore_map_of(flow_ctx)
	emap["turn_count"] = 100000
	var snap: Dictionary = runtime.dispatch({ "type": "stage.advance_turn" })
	var turns := int(_explore_map_of(flow_ctx).get("turn_count", -1))
	var m: Array = []
	if turns <= 100000 or str(snap.get("type", "")) != FlowStateIds.STAGE_EXPLORE:
		m.append("turn 100000: after one Advance the turn is %d and the state is %s" % [turns, str(snap.get("type", ""))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Item 9b. Passive time income (economy.settle_time) is paid by clock seconds. The stage turn is not an input,
## so a standoff's extra turn earns nothing.
static func _t_passive_income_ignores_turns() -> Dictionary:
	var gains: Array = []
	for turns in [0, 500]:
		var env := VentureCharacterizationTests._setup_explore_env("rt_income_%d" % turns)
		if not bool(env.get("ok", false)):
			return env
		var runtime: FlowRuntime = env["runtime"]
		var flow_ctx: FlowContext = runtime.flow_ctx
		flow_ctx.save_data["sanctum"]["ase_flame"] = { "awakened": true }
		_explore_map_of(flow_ctx)["turn_count"] = turns
		flow_ctx.save_data["economy"]["ase"] = 0
		flow_ctx.save_data["economy"]["last_settle_unix"] = 1000000
		runtime.dispatch({ "type": "economy.settle_time", "now_unix": 1000600 })
		gains.append(int(flow_ctx.save_data["economy"]["ase"]))
	var m: Array = []
	if gains[0] <= 0 or gains[0] != gains[1]:
		m.append("income for 600 s at turn 0 and turn 500: %s (must be equal and above 0)" % str(gains))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-109. The roll key is built from saved numbers only: run_count, stage turn_count and the saved
## attempt counter. It replaces the dispatch counter t, which boot() restarts at 0 (the old test here
## pinned that a reload changes t; that fact no longer reaches the roll). The key is rebuilt from a
## REAL reload of the save, and the roll it gives must equal the live roll, at two different ticks.
static func _t_roll_same_after_reload() -> Dictionary:
	var m: Array = []
	for pad in [0, 7]:
		var r: Dictionary = _engaged_retreat("rt_key_%d" % pad, false, 50, 50, pad)
		if not bool(r.get("ok", false)):
			return r
		var live_success: bool = (r["flow_ctx"] as FlowContext).encounter_ctx == null
		var again := FlowRuntime.new(StructuredLogger.new(), ConfigService.new(), (r["runtime"] as FlowRuntime).save_path)
		again.boot()
		var stage := FlowStageExploreState._get_current_stage(again.flow_ctx)
		var attempts := int(stage.get("retreat_attempts", -1))
		var turn := int(stage.get("explore_map", {}).get("turn_count", -1)) - (1 if live_success else 0)
		var run_count := int(RealmService.get_active(again.flow_ctx).get("run_count", 0))
		var key := "encounter.retreat.%s.%d.%d.%d" % [r["encounter_id"], run_count, turn, attempts - 1]
		var expected: bool = bool(RetreatService.roll_retreat(50, again.flow_ctx.campaign_seed.get_rng(key)).get("success", false))
		if attempts != 1 or expected != live_success:
			m.append("pad %d: attempts=%d, live success=%s, success rebuilt from the reloaded save=%s" % [pad, attempts, live_success, expected])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The same saved state gives the same outcome at different ticks (the old key made this differ).
static func _t_roll_ignores_tick() -> Dictionary:
	var seen: Dictionary = {}
	for pad in [0, 1, 2, 3, 11]:
		var r: Dictionary = _engaged_retreat("rt_same", false, 50, 50, pad)
		if not bool(r.get("ok", false)):
			return r
		seen[(r["flow_ctx"] as FlowContext).encounter_ctx == null] = true
	return { "ok": seen.size() == 1, "error": "the retreat outcome changed with the tick: %s" % str(seen.keys()) }


## Every attempt, won or lost, is counted on the stage record and saved; a denied one is not.
## A later attempt has a different key, so it draws from a different stream.
static func _t_attempt_count_saved_and_keys_differ() -> Dictionary:
	var m: Array = []
	for pct in [0, 100]:
		var r: Dictionary = _engaged_retreat("rt_att_%d" % pct, false, pct, 50)
		if not bool(r.get("ok", false)):
			return r
		var again := FlowRuntime.new(StructuredLogger.new(), ConfigService.new(), (r["runtime"] as FlowRuntime).save_path)
		again.boot()
		var n := int(FlowStageExploreState._get_current_stage(again.flow_ctx).get("retreat_attempts", -1))
		if n != 1:
			m.append("pct %d: expected retreat_attempts 1 on disk after one attempt, got %d" % [pct, n])
	var denied: Dictionary = _engaged_retreat("rt_att_denied", false, 100, 5)
	if not bool(denied.get("ok", false)):
		return denied
	if int(FlowStageExploreState._get_current_stage(denied["flow_ctx"]).get("retreat_attempts", 0)) != 0:
		m.append("a denied retreat counted as an attempt")
	var r2: Dictionary = _engaged_retreat("rt_att_keys", false, 0, 50)
	var ctx: FlowContext = r2["flow_ctx"]
	var k1 := ActiveStageService.next_retreat_roll_key(ctx, "e")
	var k2 := ActiveStageService.next_retreat_roll_key(ctx, "e")
	if k1 == k2 or int(FlowStageExploreState._get_current_stage(ctx).get("retreat_attempts", 0)) != 3:
		m.append("expected two different keys and 3 attempts counted, got '%s' '%s'" % [k1, k2])
	# Different keys give independent streams: the first draws must not all be equal.
	var draws: Dictionary = {}
	for i in range(16):
		draws[ctx.campaign_seed.get_rng("encounter.retreat.e.0.3.%d" % i).randi_range(0, 99)] = true
	if draws.size() < 2:
		m.append("16 attempt keys gave one draw: the attempt number does not change the stream")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-109: Tier 4 re-offers a normal fight passed by a retreat, on a later turn, after other targets.
## A fight passed by stage.ignore_situation (no retreat_pass_turn) is never re-offered.
static func _t_retreat_passed_fight_returns_later() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var ctx := FlowContext.new()
	ctx.realm_id = "realm.01"
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var session := ActiveStageService.new(ctx, cs, logger)
	var directive: Dictionary = ConfigService.get_directives_cfg(cs).get("directive.scout_carefully", {})
	var walkable: Dictionary = {}
	var explored: Dictionary = {}
	for c in 6:
		for rw in 3:
			walkable["%d,%d" % [c, rw]] = true
			explored["%d,%d" % [c, rw]] = true
	var m: Array = []
	var cases := [
		["retreat, same turn", { "retreat_pass_turn": 4 }, 4, false],
		["retreat, later turn", { "retreat_pass_turn": 4 }, 5, true],
		["ignore (no marker), later turn", {}, 9, false],
	]
	for c in cases:
		var fight: Dictionary = SituationModel.make("fight", SituationModel.TYPE_NPC, 4, 1, 900, false)
		fight["revealed"] = true
		fight["passed"] = true
		for k in (c[1] as Dictionary):
			fight[k] = c[1][k]
		var em := { "situations": [fight], "party_pos": { "col": 0, "row": 1 }, "turn_count": c[2] }
		var pick := session.find_explore_target(em, directive, walkable, explored, { "index": 0 })
		if (str(pick.get("id", "")) == "fight") != bool(c[3]):
			m.append("%s: expected offered=%s, got %s" % [c[0], c[3], str(pick.get("id", "<none>"))])
	# After the other targets: an unvisited situation and an open frontier both come first.
	var fight2: Dictionary = SituationModel.make("fight", SituationModel.TYPE_NPC, 4, 1, 900, false)
	fight2["revealed"] = true
	fight2["passed"] = true
	fight2["retreat_pass_turn"] = 1
	var other: Dictionary = SituationModel.make("other", SituationModel.TYPE_NPC, 2, 1, 901, false)
	other["revealed"] = true
	var em2 := { "situations": [fight2, other], "party_pos": { "col": 0, "row": 1 }, "turn_count": 9 }
	if str(session.find_explore_target(em2, directive, walkable, explored, { "index": 0 }).get("id", "")) != "other":
		m.append("an unvisited situation must come before the retreated fight")
	var open_walk := walkable.duplicate()
	open_walk["6,1"] = true
	var em3 := { "situations": [fight2], "party_pos": { "col": 0, "row": 1 }, "turn_count": 9 }
	if not bool(session.find_explore_target(em3, directive, open_walk, explored, { "index": 0 }).get("is_frontier", false)):
		m.append("an open frontier must come before the retreated fight")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## F2 (QA probe): the map is fully explored and one retreat-passed normal fight is the only target left.
## The counter must still move while the party is parked, so the fight is offered on a later Advance,
## never on the retreat turn itself.
static func _t_retreat_passed_fight_only_target() -> Dictionary:
	var env := VentureCharacterizationTests._setup_explore_env("rt_only_target")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = runtime.flow_ctx
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	var emap: Dictionary = stage["explore_map"]
	var sits: Array = emap.get("situations", [])
	if sits.is_empty():
		return { "ok": false, "error": "test setup failed: the stage has no situation" }
	var explored: Dictionary = {}
	for key_v in ActiveStageService.explore_walkable(emap).keys():
		explored[str(key_v)] = true
	emap["explored_cells"] = explored
	for i in range(sits.size()):
		(sits[i] as Dictionary)["resolved"] = i != 0
	var fight: Dictionary = sits[0]
	fight["revealed"] = true
	fight["passed"] = true
	fight["is_objective"] = false
	emap["turn_count"] = 0
	fight["retreat_pass_turn"] = 0
	emap["pending_situation_id"] = ""
	var m: Array = []
	runtime.dispatch({ "type": "stage.advance_turn" })
	var em := _explore_map_of(flow_ctx)
	if int(em.get("turn_count", -1)) != 1 or str(em.get("pending_situation_id", "")) + str(em.get("target_situation_id", "")) != "":
		m.append("retreat turn parked: expected turn 1 and no target, got turn %s" % str(em.get("turn_count")))
	runtime.dispatch({ "type": "stage.advance_turn" })
	em = _explore_map_of(flow_ctx)
	var heading := str(em.get("pending_situation_id", "")) + str(em.get("target_situation_id", ""))
	if heading != str(fight["id"]):
		m.append("later turn: expected the party to go for the fight '%s', got '%s' (turn %s)" % [str(fight["id"]), heading, str(em.get("turn_count"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The retreat itself writes the marker for a normal fight only, with the turn it ended on.
static func _t_retreat_marks_pass_turn() -> Dictionary:
	var m: Array = []
	for objective in [false, true]:
		var r: Dictionary = _engaged_retreat("rt_mark_%s" % str(objective), objective)
		if not bool(r.get("ok", false)):
			return r
		var sit := _sit_of(r["flow_ctx"], str(r["sit_id"]))
		if objective and sit.has("retreat_pass_turn"):
			m.append("objective fight got a pass turn")
		if not objective and int(sit.get("retreat_pass_turn", -1)) != 4:
			m.append("normal fight: expected retreat_pass_turn 4, got %s" % str(sit.get("retreat_pass_turn", "<none>")))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## A failed attempt's 10 Ase and its attempt count are already on disk after a reload, so a retry is paid
## and rolls the next attempt key.
static func _t_failed_spend_survives_reload() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_reload", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var runtime: FlowRuntime = r["runtime"]
	var again := FlowRuntime.new(StructuredLogger.new(), ConfigService.new(), runtime.save_path)
	again.boot()
	var ase := int(again.get_save_data().get("economy", {}).get("ase", -1))
	return { "ok": ase == 40, "error": "expected 40 Ase on disk after a failed retreat from 50, got %d" % ase }
