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
	runner.register_test("retreat/forced_retreat_still_ends_at_sanctum",    Callable(RetreatTests, "_t_forced_retreat_unchanged"))
	runner.register_test("retreat/roll_same_after_reload",                  Callable(RetreatTests, "_t_roll_same_after_reload"))
	runner.register_test("retreat/roll_ignores_tick",                       Callable(RetreatTests, "_t_roll_ignores_tick"))
	runner.register_test("retreat/attempt_count_saved_and_keys_differ",     Callable(RetreatTests, "_t_attempt_count_saved_and_keys_differ"))
	runner.register_test("retreat/retreat_passed_fight_returns_later",      Callable(RetreatTests, "_t_retreat_passed_fight_returns_later"))
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


## D-106 item 6: the forced retreat (a stalemate) does not share the new path. It ends at the Sanctum
## card, costs no turn and passes nothing, so the party is not put back in front of the same stalemate.
static func _t_forced_retreat_unchanged() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_forced", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var flow_ctx: FlowContext = r["flow_ctx"]
	var ase_before := int(flow_ctx.save_data["economy"]["ase"])
	(r["runtime"] as FlowRuntime)._resolve_forced_retreat(99)
	var card: Dictionary = flow_ctx.last_snapshot
	var cta: Dictionary = (card.get("actions", {}) as Dictionary).get("cta.continue", {})
	var emap := _explore_map_of(flow_ctx)
	var m: Array = []
	if str(card.get("data", {}).get("run_type", "")) != "forced_retreat" or str(cta.get("to", "")) != FlowStateIds.SANCTUM:
		m.append("forced retreat card changed: %s %s" % [card.get("data", {}).get("run_type"), str(cta)])
	if int(emap.get("turn_count", -1)) != 3 or bool(_sit_of(flow_ctx, str(r["sit_id"])).get("passed", false)):
		m.append("forced retreat changed the stage: turn %s" % str(emap.get("turn_count")))
	if int(flow_ctx.save_data["economy"]["ase"]) != ase_before:
		m.append("forced retreat changed Ase")
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


## The cost of that: a re-roll after a reload is possible, but the failed attempt's 10 Ase is already
## on disk, so every re-roll is paid.
static func _t_failed_spend_survives_reload() -> Dictionary:
	var r: Dictionary = _engaged_retreat("rt_reload", false, 0, 50)
	if not bool(r.get("ok", false)):
		return r
	var runtime: FlowRuntime = r["runtime"]
	var again := FlowRuntime.new(StructuredLogger.new(), ConfigService.new(), runtime.save_path)
	again.boot()
	var ase := int(again.get_save_data().get("economy", {}).get("ase", -1))
	return { "ok": ase == 40, "error": "expected 40 Ase on disk after a failed retreat from 50, got %d" % ase }
