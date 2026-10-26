# res://tests/EconomyCharacterizationTests.gd
# V2-ECONOMY-004 characterization of what the stage and encounter payers pay.
#
# Phase 3a set the weights (set B, boss 0). Phase 3b made every reader of the stage base count
# completed objectives only (D-11 to D-15). A test marked
#   # KNOWN DEFECT (<phase> will change this):
# carries a defect. The phase named there inverts that assertion. Do not invert it earlier.
# Report: docs/stories/v2-economy-004/phase1-characterization.md

class_name EconomyCharacterizationTests
extends RefCounted

const _STAGE_COUNT := 4
# Seeds per realm for the pool measurement. ECONOMY_CHAR_SEEDS=200 runs the full table (about 60 s).
const _DEFAULT_SEEDS := 25

# Weight of each type in data.rewards.objective_weights (D-09, D-10). A type with no key logs
# an error and pays 0 (D-07). The boss has a key with weight 0.
const _TYPE_WEIGHT := {
	"pursue": 16, "combat": 20, "recover": 24, "protect": 24,
	"endure": 28, "shrine": 30, "guide_spirit": 32, "boss": 0,
}

# Ekwan of each type in data.rewards.objective_ekwan (D-29, working set B). Fights pay none.
const _TYPE_EKWAN := {
	"pursue": 2, "combat": 2, "protect": 3, "guide_spirit": 3,
	"endure": 4, "recover": 5, "shrine": 6, "boss": 0,
}

# Objective Ase and Ekwan of a stage with one completed pre-boss objective of each type (the boss
# type is the boss stub alone), by realm and run_count: [Ase, Ekwan]. Ase = round(weight x realm scale
# x replay factor), D-54 and D-63. The Echoes stipend is not in this table: `_settle_cell` settles
# with no fight, and the stage environment has a party of one Echo, so the stipend is one Echo x
# 2 Ase on every cell.
const _ONE_ECHO_STIPEND := 2
const _STAGE_CELLS := {
	"realm.01": {
		0: { "pursue": [16, 2], "combat": [20, 2], "recover": [24, 5], "protect": [24, 3], "endure": [28, 4], "shrine": [30, 6], "guide_spirit": [32, 3], "boss": [0, 0] },
		1: { "pursue": [6, 1], "combat": [7, 1], "recover": [8, 2], "protect": [8, 1], "endure": [10, 1], "shrine": [11, 2], "guide_spirit": [11, 1], "boss": [0, 0] },
	},
	"realm.02": {
		0: { "pursue": [20, 3], "combat": [25, 3], "recover": [30, 6], "protect": [30, 4], "endure": [35, 5], "shrine": [38, 8], "guide_spirit": [40, 4], "boss": [0, 0] },
		1: { "pursue": [7, 1], "combat": [9, 1], "recover": [11, 2], "protect": [11, 1], "endure": [12, 2], "shrine": [13, 3], "guide_spirit": [14, 1], "boss": [0, 0] },
	},
}
# The base row of the stage payout is the Ase after the realm scale and before the replay factor.
const _REALM_SCALE := { "realm.01": 1.0, "realm.02": 1.25 }


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("econ_char/base_reward_per_type", Callable(EconomyCharacterizationTests, "_t_base_reward_per_type"))
	runner.register_test("econ_char/every_type_has_a_weight", Callable(EconomyCharacterizationTests, "_t_every_type_has_a_weight"))
	runner.register_test("econ_char/boss_stub_adds_zero", Callable(EconomyCharacterizationTests, "_t_boss_stub_adds_zero"))
	runner.register_test("econ_char/combat_and_shrine_single_objective", Callable(EconomyCharacterizationTests, "_t_combat_and_shrine"))
	runner.register_test("econ_char/multi_objective_stage_sums", Callable(EconomyCharacterizationTests, "_t_multi_objective"))
	runner.register_test("econ_char/partial_payout_uses_stage_base", Callable(EconomyCharacterizationTests, "_t_partial_payout"))
	runner.register_test("econ_char/unknown_type_logs_and_pays_zero", Callable(EconomyCharacterizationTests, "_t_unknown_type"))
	runner.register_test("econ_char/realm_scale_and_replay_factor", Callable(EconomyCharacterizationTests, "_t_scale_and_replay"))
	runner.register_test("econ_char/stage_ase_rounds_once_on_the_sum", Callable(EconomyCharacterizationTests, "_t_ase_rounds_once"))
	runner.register_test("econ_char/stage_payout_realm_scale_not_on_stipend", Callable(EconomyCharacterizationTests, "_t_scale_not_on_stipend"))
	runner.register_test("econ_char/consolation_takes_scale_and_replay", Callable(EconomyCharacterizationTests, "_t_consolation_scaled"))
	runner.register_test("econ_char/partial_factors_follow_the_realm", Callable(EconomyCharacterizationTests, "_t_partial_factors"))
	runner.register_test("econ_char/removed_bonus_keys_absent", Callable(EconomyCharacterizationTests, "_t_removed_keys_absent"))
	runner.register_test("econ_char/rank_score_table", Callable(EconomyCharacterizationTests, "_t_rank_table"))
	runner.register_test("econ_char/death_caps_rank_at_a", Callable(EconomyCharacterizationTests, "_t_death_cap"))
	runner.register_test("econ_char/rank_ignores_replay_factor", Callable(EconomyCharacterizationTests, "_t_rank_ignores_replay"))
	runner.register_test("econ_char/death_lowers_rank", Callable(EconomyCharacterizationTests, "_t_death_lowers_rank"))
	runner.register_test("econ_char/speed_never_outranks_survival", Callable(EconomyCharacterizationTests, "_t_speed_vs_survival"))
	runner.register_test("econ_char/no_pace_mode_not_capped", Callable(EconomyCharacterizationTests, "_t_no_pace_not_capped"))
	runner.register_test("econ_char/speed_pays_no_ase", Callable(EconomyCharacterizationTests, "_t_speed_pays_no_ase"))
	runner.register_test("econ_char/stage_payer_matrix", Callable(EconomyCharacterizationTests, "_t_stage_payer_matrix"))
	runner.register_test("econ_char/ekwan_per_type", Callable(EconomyCharacterizationTests, "_t_ekwan_per_type"))
	runner.register_test("econ_char/ekwan_sums_completed_only", Callable(EconomyCharacterizationTests, "_t_ekwan_completed_only"))
	runner.register_test("econ_char/ekwan_unknown_type_logs_and_pays_zero", Callable(EconomyCharacterizationTests, "_t_ekwan_unknown_type"))
	runner.register_test("econ_char/ekwan_replay_rounds_once_on_the_sum", Callable(EconomyCharacterizationTests, "_t_ekwan_replay"))
	runner.register_test("econ_char/encounter_payer_victory", Callable(EconomyCharacterizationTests, "_t_encounter_victory"))
	runner.register_test("econ_char/encounter_payer_defeat", Callable(EconomyCharacterizationTests, "_t_encounter_defeat"))
	runner.register_test("econ_char/fights_pay_no_ekwan", Callable(EconomyCharacterizationTests, "_t_fights_pay_no_ekwan"))
	runner.register_test("econ_char/objective_model_writes_type_not_obj_type", Callable(EconomyCharacterizationTests, "_t_model_key"))
	runner.register_test("econ_char/ekwan_old_keys_removed", Callable(EconomyCharacterizationTests, "_t_old_keys_removed"))
	runner.register_test("econ_char/fast_generation_matches_realm_service", Callable(EconomyCharacterizationTests, "_t_fast_matches_service"))
	runner.register_test("econ_char/objective_pool_frequency", Callable(EconomyCharacterizationTests, "_t_pool_frequency"))
	runner.register_test("econ_char/stage_payer_pays_completed_only", Callable(EconomyCharacterizationTests, "_t_stage_payer_completed_only"))
	runner.register_test("econ_char/uncompleted_optional_adds_nothing", Callable(EconomyCharacterizationTests, "_t_uncompleted_adds_nothing"))
	runner.register_test("econ_char/pace_base_completed_plus_fought", Callable(EconomyCharacterizationTests, "_t_pace_base"))
	runner.register_test("econ_char/first_defeat_pays_fought_weight", Callable(EconomyCharacterizationTests, "_t_first_defeat"))
	runner.register_test("econ_char/partials_pay_completed_weights", Callable(EconomyCharacterizationTests, "_t_partials_completed"))
	runner.register_test("econ_char/rank_not_lowered_by_unreached", Callable(EconomyCharacterizationTests, "_t_rank_unreached"))
	runner.register_test("econ_char/cause_encounter_rows", Callable(EconomyCharacterizationTests, "_t_cause_encounter_rows"))
	runner.register_test("econ_char/cause_zero_by_rule_rows", Callable(EconomyCharacterizationTests, "_t_cause_zero_rows"))
	runner.register_test("econ_char/cause_stage_rows", Callable(EconomyCharacterizationTests, "_t_cause_stage_rows"))
	runner.register_test("econ_char/cause_scout_return_rows", Callable(EconomyCharacterizationTests, "_t_cause_scout_rows"))
	runner.register_test("econ_char/cause_boss_stub_excluded_from_total", Callable(EconomyCharacterizationTests, "_t_cause_boss_stub"))
	runner.register_test("econ_char/cause_rows_survive_pending_copy", Callable(EconomyCharacterizationTests, "_t_cause_pending_copy"))
	runner.register_test("econ_char/cause_old_saved_row_replays", Callable(EconomyCharacterizationTests, "_t_cause_old_row_replays"))
	runner.register_test("econ_char/stage_preview_equals_paid", Callable(EconomyCharacterizationTests, "_t_stage_preview"))
	runner.register_test("econ_char/stage_payout_keys_on_real_victory_card", Callable(EconomyCharacterizationTests, "_t_stage_payout_card"))
	runner.register_test("econ_char/stipend_per_echo_and_cap", Callable(EconomyCharacterizationTests, "_t_stipend_counts"))
	runner.register_test("econ_char/stipend_replay_cap", Callable(EconomyCharacterizationTests, "_t_stipend_replay"))
	runner.register_test("econ_char/stipend_dead_echo_and_no_encounter", Callable(EconomyCharacterizationTests, "_t_stipend_dead_and_none"))
	runner.register_test("econ_char/stipend_dead_echo_on_real_card", Callable(EconomyCharacterizationTests, "_t_stipend_real_card"))
	runner.register_test("econ_char/settle_plan_gathered_by_realm_and_run", Callable(EconomyCharacterizationTests, "_t_settle_plan_gathered"))
	runner.register_test("econ_char/settle_odds_come_from_config_and_scout_shifts_them", Callable(EconomyCharacterizationTests, "_t_settle_odds_from_config"))
	runner.register_test("econ_char/settle_roll_seeded_distribution", Callable(EconomyCharacterizationTests, "_t_settle_roll_seeded_distribution"))
	runner.register_test("econ_char/settle_pays_once_and_marks", Callable(EconomyCharacterizationTests, "_t_settle_pays_once_and_marks"))
	runner.register_test("econ_char/settle_nothing_new_changes_nothing", Callable(EconomyCharacterizationTests, "_t_settle_nothing_new_changes_nothing"))
	runner.register_test("econ_char/settle_reroll_blocked_by_cancel_reload_retry", Callable(EconomyCharacterizationTests, "_t_settle_reroll_blocked"))
	runner.register_test("econ_char/settle_scout_never_pays_over_the_gathered_amount", Callable(EconomyCharacterizationTests, "_t_settle_scout_never_over_100"))
	runner.register_test("econ_char/settle_defeat_keeps_what_the_leave_paid", Callable(EconomyCharacterizationTests, "_t_settle_defeat_keeps_paid"))
	runner.register_test("econ_char/settle_stage_end_pays_unsettled_only", Callable(EconomyCharacterizationTests, "_t_settle_stage_end_pays_unsettled_only"))
	runner.register_test("econ_char/settle_rows_memo_not_negative", Callable(EconomyCharacterizationTests, "_t_settle_rows_memo"))
	runner.register_test("econ_char/settle_worked_example_74", Callable(EconomyCharacterizationTests, "_t_settle_worked_example"))
	runner.register_test("econ_char/settle_replay_resets_marks", Callable(EconomyCharacterizationTests, "_t_settle_replay_resets_marks"))
	runner.register_test("econ_char/settle_return_home_dispatch_word_outcome_no_odds", Callable(EconomyCharacterizationTests, "_t_settle_return_home_dispatch"))
	runner.register_test("econ_char/settle_retreat_pays_nothing", Callable(EconomyCharacterizationTests, "_t_settle_retreat_pays_nothing"))
	runner.register_test("econ_char/intel_gained_absent_zero_present_count_absent_on_defeat", Callable(EconomyCharacterizationTests, "_t_intel_gained"))
	runner.register_test("econ_char/intel_gained_replays_from_stored_result", Callable(EconomyCharacterizationTests, "_t_intel_gained_replay"))
	runner.register_test("econ_char/death_record_carries_to_later_fight", Callable(EconomyCharacterizationTests, "_t_death_record"))
	runner.register_test("econ_char/thread_whole_and_objective_overcome_keys", Callable(EconomyCharacterizationTests, "_t_thread_and_overcome"))
	runner.register_test("econ_char/death_record_old_save_and_replay", Callable(EconomyCharacterizationTests, "_t_death_record_old_and_replay"))
	runner.register_test("econ_char/ledger_seen_default_false_and_action_sets_it", Callable(EconomyCharacterizationTests, "_t_ledger_seen"))
	runner.register_test("econ_char/stipend_reads_death_record_without_encounter", Callable(EconomyCharacterizationTests, "_t_stipend_record_no_encounter"))
	runner.register_test("econ_char/reboot_after_death_pays_what_the_card_showed", Callable(EconomyCharacterizationTests, "_t_reboot_after_death"))
	runner.register_test("econ_char/reboot_replayed_card_pays_what_it_showed", Callable(EconomyCharacterizationTests, "_t_reboot_replayed_card"))
	runner.register_test("econ_char/charge_completion_after_death_pays_with_record", Callable(EconomyCharacterizationTests, "_t_charge_after_death"))
	runner.register_test("econ_char/death_record_survives_return_home_and_replay_starts_empty", Callable(EconomyCharacterizationTests, "_t_death_record_lifetime"))
	runner.register_test("econ_char/missing_rewards_key_logs_and_returns_safe_value", Callable(EconomyCharacterizationTests, "_t_missing_key_logs"))
	runner.register_test("econ_char/contact_claimant_good_ase_is_20_and_missing_key_logs", Callable(EconomyCharacterizationTests, "_t_claimant_good_ase"))
	runner.register_test("econ_char/balance_defeat_factor_is_one_quarter", Callable(EconomyCharacterizationTests, "_t_defeat_factor_config"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _config() -> ConfigService:
	var cfg := ConfigService.new()
	cfg.load_balance()
	cfg.load_realms()
	return cfg


static func _rewards_cfg() -> Dictionary:
	return ConfigService.get_rewards_cfg(_config())


## Production shape at settlement: one completed pre-boss objective, then the boss stub, which
## is never completed (RealmGenerator.generate). `boss` as a type has no pre-boss form, so it
## is the boss stub alone.
static func _objectives(type: String) -> Array:
	var boss := ObjectiveModel.make(1, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	if type == ObjectiveModel.TYPE_BOSS:
		return [ObjectiveModel.make(0, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)]
	return [ObjectiveModel.make(0, type, 1, {}, true), boss]


static func _obj(index: int, type: String, completed: bool) -> Dictionary:
	return ObjectiveModel.make(index, type, 1, {}, completed)


static func _logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level(StructuredLogger.LEVEL_OFF)
	return logger


static func _expected_base(type: String) -> int:
	return int(_TYPE_WEIGHT[type])


## `fought_index` is the objective being fought. A defeat leaves it uncompleted, as in production.
static func _encounter_pay(objectives: Array, victory: bool, run_count: int, fought_index: int = 0,
		realm_scale: float = 1.0) -> Dictionary:
	var reward_cfg := _rewards_cfg()
	var objs: Array = objectives.duplicate(true)
	if not victory and fought_index >= 0:
		(objs[fought_index] as Dictionary)["completed"] = false
	var rd: Dictionary = RewardCalc.compute(
		victory, objs, 2, 2, 2, run_count, reward_cfg,
		EncounterResolutionModes.COMBAT, 0.0, "", null, 0, fought_index, realm_scale)
	var save := { "economy": { "ase": 0, "ekwan": 0 } }
	var econ := EconomyService.new(save)
	var paid: Dictionary = econ.reward_encounter_complete(
		victory,
		int(rd.get("consolation_base", 0)),
		float(rd.get("realm_scale", 1.0)), float(rd.get("replay_factor", 1.0)),
		str(rd.get("rank", "F")), true, _logger(), 1, 0.25)
	paid["base_reward"] = int(rd.get("base_reward", 0))
	paid["balance_ase"] = int((save["economy"] as Dictionary)["ase"])
	paid["balance_ekwan"] = int((save["economy"] as Dictionary)["ekwan"])
	return paid


# ---------------------------------------------------------------------------
# Pure reward math
# ---------------------------------------------------------------------------

static func _t_base_reward_per_type() -> Dictionary:
	var cfg := _rewards_cfg()
	var weights: Dictionary = cfg.get("objective_weights", {})
	var mismatches: Array = []
	for type in _TYPE_WEIGHT:
		if int(weights.get(type, -1)) != int(_TYPE_WEIGHT[type]):
			mismatches.append("objective_weights.%s is %s, expected %d" % [type, str(weights.get(type)), int(_TYPE_WEIGHT[type])])
	if weights.size() != _TYPE_WEIGHT.size():
		mismatches.append("objective_weights keys changed: %s" % str(weights))
	for type in ObjectiveModel.VALID_TYPES:
		if not _TYPE_WEIGHT.has(type):
			mismatches.append("VALID_TYPES gained a type this suite does not record: %s" % type)
			continue
		var base := RewardCalc.base_reward(_objectives(type), cfg)
		if base != _expected_base(type):
			mismatches.append("%s: base %d, expected %d" % [type, base, _expected_base(type)])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _t_every_type_has_a_weight() -> Dictionary:
	var cfg := _rewards_cfg()
	var weights: Dictionary = cfg.get("objective_weights", {})
	var logger := StructuredLogger.new()
	var mismatches: Array = []
	for type in ObjectiveModel.VALID_TYPES:
		if not weights.has(type):
			mismatches.append("%s has no key in objective_weights" % type)
		if RewardCalc.base_reward([_obj(0, type, true)], cfg, logger, 1) != _expected_base(type):
			mismatches.append("%s alone does not pay its weight" % type)
	if not logger.get_logs().is_empty():
		mismatches.append("a configured type logged: %s" % str(logger.get_logs()))
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## D-10: the boss has a key with weight 0, so it pays nothing and logs nothing.
static func _t_boss_stub_adds_zero() -> Dictionary:
	var cfg := _rewards_cfg()
	var logger := StructuredLogger.new()
	var mismatches: Array = []
	for type in ObjectiveModel.VALID_TYPES:
		if type == ObjectiveModel.TYPE_BOSS:
			continue
		var with_boss := RewardCalc.base_reward(_objectives(type), cfg, logger, 1)
		var without := RewardCalc.base_reward([_obj(0, type, true)], cfg, logger, 1)
		if with_boss != without:
			mismatches.append("%s: boss stub adds %d" % [type, with_boss - without])
	if not logger.get_logs().is_empty():
		mismatches.append("the boss stub logged: %s" % str(logger.get_logs()))
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## Single combat and single shrine objective, through the encounter reward math.
static func _t_combat_and_shrine() -> Dictionary:
	var cfg := _rewards_cfg()
	var mismatches: Array = []
	for c in [["combat", 20, 5], ["shrine", 30, 8]]:
		for victory in [true, false]:
			var rd: Dictionary = RewardCalc.compute(
				victory, [_obj(0, c[0], victory)], 2, 2, 2, 0, cfg,
				EncounterResolutionModes.COMBAT, 0.0, "", null, 0, 0)
			if int(rd["base_reward"]) != int(c[1]):
				mismatches.append("%s victory=%s base %d, expected %d" % [c[0], str(victory), int(rd["base_reward"]), int(c[1])])
		var paid := _encounter_pay([_obj(0, c[0], true)], false, 0)
		if int(paid["ase_awarded"]) != int(c[2]):
			mismatches.append("%s defeat paid %d, expected %d" % [c[0], int(paid["ase_awarded"]), int(c[2])])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## Three objectives (realm.02 shape plus the boss stub), both pre-boss objectives completed: the
## base is the sum; the boss adds 0.
## Stage 0, run 0: Ase = 50, Ekwan = combat 2 + shrine 6 = 8.
static func _t_multi_objective() -> Dictionary:
	var cfg := _rewards_cfg()
	var objs: Array = [
		_obj(0, "combat", true), _obj(1, "shrine", true),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false),
	]
	var mismatches: Array = []
	if RewardCalc.base_reward(objs, cfg) != 50:
		mismatches.append("sum of combat + shrine + boss is %d, expected 50" % RewardCalc.base_reward(objs, cfg))
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_multi")
	if not bool(env.get("ok", false)):
		return env
	var out := _settle_cell(env, objs, 0, 0, 1)
	if int(out.get("ase_awarded", -1)) != 50 + _ONE_ECHO_STIPEND or int(out.get("ekwan_awarded", -1)) != 8 \
			or _breakdown_delta(out, "Base objectives") != 50:
		mismatches.append("stage paid %s/%s base row %d, expected 52/8 base row 50" \
			% [str(out.get("ase_awarded")), str(out.get("ekwan_awarded")), _breakdown_delta(out, "Base objectives")])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## REWRITTEN (D-104 to D-106): the 12% partial factor is gone. The amount a return home gathers is
## the completed stage base itself (`settle_plan`); the roll then pays 0%, 50% or 100% of it.
## The base is the same sum the stage payer uses. Every pre-boss objective here is completed.
static func _t_partial_payout() -> Dictionary:
	var cfg := _config()
	var mismatches: Array = []
	for c in [[["combat"], 20, 2], [["guide_spirit"], 32, 3], [["combat", "shrine"], 50, 8], [["pursue"], 16, 2]]:
		var objs: Array = []
		for k in range((c[0] as Array).size()):
			objs.append(_obj(k, c[0][k], true))
		objs.append(ObjectiveModel.make(objs.size(), ObjectiveModel.TYPE_BOSS, 2, {}, false, false))
		var ctx := _stage_ctx(cfg, objs)
		var base := ActiveStageService.get_stage_base_reward(ctx, cfg)
		var plan := StageSettlementService.settle_plan(ctx, cfg)
		if base != int(c[1]) or int(plan["ase"]) != int(c[1]) or int(plan["ekwan"]) != int(c[2]):
			mismatches.append("%s: base %d gathered %s/%s, expected %d / %d" % [str(c[0]), base, plan["ase"], plan["ekwan"], int(c[1]), int(c[2])])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _stage_ctx(cfg: ConfigService, objs: Array, fought_index: int = -1) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = cfg
	ctx.realm_id = "realm.01"
	ctx.stage_id = "stage.0"
	ctx.active_encounter_objective_index = fought_index
	ctx.save_data = { "realms": { "realm.01": { "stages": [ { "index": 0, "objectives": objs } ] } } }
	return ctx


## Follow-up 31: no code default. A missing `data.rewards` key logs once per read and returns the
## neutral value; a present key logs nothing.
static func _t_missing_key_logs() -> Dictionary:
	var mismatches: Array = []
	var logger := StructuredLogger.new()
	var order: Array = ["realm.01", "realm.02"]
	if not is_equal_approx(RewardCalc.realm_scale("realm.02", order, {}, logger, 5), 1.0):
		mismatches.append("realm_scale with no step is not 1.0")
	if not is_equal_approx(RewardCalc.replay_factor(1, {}, logger, 5), 1.0):
		mismatches.append("replay_factor with no key is not 1.0")
	# Step 5.14 (F2): the Echoes stipend keys read through the same reader.
	var echo_logger := StructuredLogger.new()
	var echo_ctx := _stage_ctx(_config(), [])
	var echo_svc := StageSettlementService.new(echo_ctx, echo_ctx.config_service, null, null)
	var tally: Dictionary = echo_svc._echo_home({ "run_count": 1 }, {}, echo_logger, 5)
	var echo_keys: Array = []
	for le in echo_logger.get_logs():
		echo_keys.append(str((le["data"] as Dictionary).get("key")))
	if echo_keys != ["echo_home_ase", "echo_home_cap_replay"] or int(tally["rate"]) != 0 or int(tally["cap"]) != 0:
		mismatches.append("echo_home with no keys logged %s, tally %s" % [str(echo_keys), str(tally)])
	var logs := logger.get_logs()
	if logs.size() != 2:
		mismatches.append("expected 2 log lines, got %d" % logs.size())
	else:
		var e: Dictionary = logs[0]
		if str(e["type"]) != "economy.reward.missing_config_key" or int(e["t"]) != 5 \
				or str((e["data"] as Dictionary).get("key")) != "realm_scale_step":
			mismatches.append("log line is %s" % str(e))
	var quiet := StructuredLogger.new()
	var cfg := _rewards_cfg()
	RewardCalc.realm_scale("realm.02", order, cfg, quiet, 5)
	RewardCalc.replay_factor(1, cfg, quiet, 5)
	if not quiet.get_logs().is_empty():
		mismatches.append("a complete config logged %s" % str(quiet.get_logs()))
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _t_claimant_good_ase() -> Dictionary:
	var quiet := StructuredLogger.new()
	var v := ContactController.claimant_good_ase(_rewards_cfg(), quiet, 7)
	var mismatches: Array = []
	if v != 20 or not quiet.get_logs().is_empty():
		mismatches.append("shipped value %d (expected 20), logs %s" % [v, str(quiet.get_logs())])
	var loud := StructuredLogger.new()
	var missing := ContactController.claimant_good_ase({}, loud, 7)
	var logs := loud.get_logs()
	if missing != 0 or logs.size() != 1 or int(logs[0]["t"]) != 7 \
			or str((logs[0]["data"] as Dictionary).get("key")) != "contact_claimant_good_ase":
		mismatches.append("missing key paid %d, logs %s" % [missing, str(logs)])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _t_defeat_factor_config() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var v: float = RewardCalc.cfg_num(ConfigService.get_rewards_cfg(config), "defeat_factor", -1.0)
	return { "ok": is_equal_approx(v, 0.25), "error": "data.rewards.defeat_factor is %s, expected 0.25" % str(v) }


## D-07: a type with no key logs economy.reward.unknown_objective_type and counts 0. It never
## falls back to combat, in every reader of the stage base.
static func _t_unknown_type() -> Dictionary:
	var cfg := _rewards_cfg()
	var mismatches: Array = []
	var logger := StructuredLogger.new()
	var objs: Array = [{ "type": "mystery", "completed": true }, _obj(1, "combat", true)]
	var base := RewardCalc.base_reward(objs, cfg, logger, 7)
	if base != 20:
		mismatches.append("unknown + combat paid %d, expected 20" % base)
	var logs := logger.get_logs()
	if logs.size() != 1:
		mismatches.append("expected 1 log line, got %d" % logs.size())
	else:
		var e: Dictionary = logs[0]
		var d: Dictionary = e["data"]
		if str(e["type"]) != "economy.reward.unknown_objective_type" or int(e["t"]) != 7 \
				or str(d.get("type")) != "mystery" or int(d.get("objective_index", -1)) != 0:
			mismatches.append("log line is %s" % str(e))
	# A configured type whose key is removed also logs and pays 0 (no combat default).
	var trimmed := cfg.duplicate(true)
	(trimmed["objective_weights"] as Dictionary).erase("shrine")
	var logger2 := StructuredLogger.new()
	if RewardCalc.base_reward([_obj(0, "shrine", true)], trimmed, logger2, 3) != 0 \
			or logger2.get_logs().size() != 1:
		mismatches.append("shrine without a key did not pay 0 with one log line")
	# An objective that is not selected is never looked up, so an unknown type there logs nothing.
	var logger3 := StructuredLogger.new()
	if RewardCalc.base_reward([{ "type": "mystery", "completed": false }], cfg, logger3, 3) != 0 \
			or not logger3.get_logs().is_empty():
		mismatches.append("an uncompleted unknown type logged or paid")
	# The stage payer logs it too.
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_unknown")
	if not bool(env.get("ok", false)):
		return env
	var before := (env["logger"] as StructuredLogger).get_logs().size()
	var out := _settle_cell(env, [{ "type": "mystery", "index": 0, "completed": true }], 0, 0, 1)
	var seen := false
	for e_v in (env["logger"] as StructuredLogger).get_logs().slice(before):
		if str((e_v as Dictionary)["type"]) == "economy.reward.unknown_objective_type":
			seen = true
	if not seen or _breakdown_delta(out, "Base objectives") != 0:
		mismatches.append("stage payer: logged=%s base row %d" % [str(seen), _breakdown_delta(out, "Base objectives")])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## D-63: scale = 1 + step x (position in realm_order - 1); outside the list it is 1.0. D-54: the
## replay factor is flat, and 1.0 on a first run. Both read from data.rewards.
static func _t_scale_and_replay() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	var order: Array = ConfigService.get_realm_order(_config())
	if order != ["realm.01", "realm.02"]:
		m.append("realm_order is %s, expected [realm.01, realm.02]" % str(order))
	var by_rule: Array = ["realm.01", "realm.02", "realm.03", "realm.04"]
	for c in [["realm.01", 1.0], ["realm.02", 1.25], ["realm.03", 1.5], ["realm.04", 1.75]]:
		var got := RewardCalc.realm_scale(c[0], by_rule, cfg)
		if not is_equal_approx(got, c[1]):
			m.append("%s scale %s, expected %s" % [c[0], str(got), str(c[1])])
	for outside in ["realm.prologue", "", "realm.09"]:
		if not is_equal_approx(RewardCalc.realm_scale(outside, by_rule, cfg), 1.0):
			m.append("'%s' is outside realm_order and must scale 1.0" % outside)
	if not is_equal_approx(float(cfg.get("realm_scale_step", 0.0)), 0.25) \
			or not is_equal_approx(float(cfg.get("replay_factor", 0.0)), 0.35):
		m.append("data.rewards holds step %s, replay %s" % [str(cfg.get("realm_scale_step")), str(cfg.get("replay_factor"))])
	for run_count in [-1, 0]:
		if not is_equal_approx(RewardCalc.replay_factor(run_count, cfg), 1.0):
			m.append("run_count %d must take no factor" % run_count)
	for run_count in [1, 2, 9]:
		if not is_equal_approx(RewardCalc.replay_factor(run_count, cfg), 0.35):
			m.append("run_count %d must take the flat 0.35" % run_count)
	# The step is read from config, not fixed in code.
	var wide := cfg.duplicate(true)
	wide["realm_scale_step"] = 0.5
	if not is_equal_approx(RewardCalc.realm_scale("realm.03", by_rule, wide), 2.0):
		m.append("realm_scale_step 0.5 must give realm.03 a scale of 2.0")
	# The factors of the real stage context.
	var ctx := _stage_ctx(_config(), [_obj(0, "combat", true)])
	var f := ActiveStageService.get_payout_factors(ctx, ctx.config_service)
	if not is_equal_approx(float(f["realm_scale"]), 1.0) or not is_equal_approx(float(f["replay_factor"]), 1.0):
		m.append("realm.01 run 0 factors %s" % str(f))
	(ctx.save_data["realms"]["realm.01"] as Dictionary)["run_count"] = 2
	ctx.realm_id = "realm.02"
	ctx.save_data["realms"]["realm.02"] = (ctx.save_data["realms"]["realm.01"] as Dictionary).duplicate(true)
	f = ActiveStageService.get_payout_factors(ctx, ctx.config_service)
	if not is_equal_approx(float(f["realm_scale"]), 1.25) or not is_equal_approx(float(f["replay_factor"]), 0.35):
		m.append("realm.02 run 2 factors %s" % str(f))
	ctx.realm_id = "realm.prologue"
	f = ActiveStageService.get_payout_factors(ctx, ctx.config_service)
	if not is_equal_approx(float(f["realm_scale"]), 1.0):
		m.append("the prologue must scale 1.0, got %s" % str(f))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-30, D-54: Ase and Ekwan are rounded ONCE on the stage sum, after the scale and the factor.
## Each cell is chosen so that per-objective rounding gives another number. Pure rows, so realm.03
## (not in the shipped realm_order) is reached by the rule.
static func _t_ase_rounds_once() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	var counts := { "overcome": 2, "total": 2 }
	# [objective types, realm scale, replay factor, Ase, Ekwan, why]
	for c in [
		[["shrine"], 1.0, 0.35, 11, 2, "30 x 0.35 = 10.5 -> 11 (x.5 Ase); 6 x 0.35 = 2.1"],
		[["recover"], 1.25, 0.35, 11, 2, "24 x 0.4375 = 10.5 -> 11 (x.5 Ase)"],
		[["shrine"], 1.25, 1.0, 38, 8, "30 x 1.25 = 37.5 -> 38 (x.5 Ase); 6 x 1.25 = 7.5 -> 8 (x.5 Ekwan)"],
		[["recover", "protect"], 1.0, 0.35, 17, 3, "48 x 0.35 = 16.8 -> 17, per objective 8 + 8; Ekwan 8 x 0.35 = 2.8"],
		[["endure", "endure", "combat"], 1.0, 0.35, 27, 4, "Ekwan 10 x 0.35 = 3.5 -> 4 (x.5 Ekwan), per objective 1 + 1 + 1"],
		[["recover", "recover"], 1.25, 1.0, 60, 13, "Ekwan 10 x 1.25 = 12.5 -> 13 (x.5 Ekwan), per objective 6 + 6"],
		[["shrine", "combat"], 1.25, 0.35, 22, 4, "50 x 0.4375 = 21.875 -> 22; Ekwan 8 x 0.4375 = 3.5 -> 4 (x.5 Ekwan)"],
		[["shrine", "combat"], 1.5, 0.35, 26, 4, "realm.03 by rule: 50 x 0.525 = 26.25; Ekwan 8 x 0.525 = 4.2"],
	]:
		var objs: Array = []
		for k in range((c[0] as Array).size()):
			objs.append(_obj(k, c[0][k], true))
		var rows := EconomyService.stage_payout_rows(RewardCalc.base_reward(objs, cfg), c[1], c[2], counts,
			RewardCalc.stage_ekwan(objs, cfg))
		if int(rows["ase"]) != int(c[3]) or int(rows["ekwan"]) != int(c[4]):
			m.append("%s scale %s x %s: paid %d/%d, expected %d/%d (%s)" % [str(c[0]), str(c[1]), str(c[2]),
				int(rows["ase"]), int(rows["ekwan"]), int(c[3]), int(c[4]), str(c[5])])
		var total_rows := 0
		for row_v in rows["breakdown"]:
			total_rows += int((row_v as Dictionary)["delta"])
		if total_rows != int(rows["ase"]):
			m.append("%s: the rows add to %d, the payout is %d" % [str(c[0]), total_rows, int(rows["ase"])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-63, D-53: the realm scale and the replay factor leave the Echoes stipend alone. The replay
## row exists only when the factor lowers the amount, and carries the factor as `factor`.
static func _t_scale_not_on_stipend() -> Dictionary:
	var m: Array = []
	var home := { "alive": 3, "started": 3, "lost": [], "rate": 2, "cap": 10, "replay": false }
	var plain := EconomyService.stage_payout_rows(20, 1.0, 1.0, {}, 2, home)
	var scaled := EconomyService.stage_payout_rows(20, 1.5, 1.0, {}, 2, home)
	var replayed := EconomyService.stage_payout_rows(20, 1.5, 0.35, {}, 2, home)
	for c in [["run 0 realm.01", plain, 20 + 6], ["realm.03 run 0", scaled, 30 + 6], ["realm.03 replay", replayed, 11 + 6]]:
		var stipend := _row_by_cause(c[1]["breakdown"], "echoes_alive")
		if int(stipend.get("delta", -1)) != 6 or int(c[1]["ase"]) != int(c[2]):
			m.append("%s: stipend row %s, stage ase %s, expected stipend 6 and ase %d" \
				% [c[0], JSON.stringify(stipend), str(c[1]["ase"]), int(c[2])])
	if not _row_by_cause(plain["breakdown"], "replay").is_empty() or not _row_by_cause(scaled["breakdown"], "replay").is_empty():
		m.append("a replay row exists with no replay factor")
	var replay_row := _row_by_cause(replayed["breakdown"], "replay")
	# 20 x 1.5 = 30 before the factor; 30 x 0.35 = 10.5 -> 11; the delta is -19.
	if int(replay_row.get("delta", 0)) != -19 \
			or not is_equal_approx(float((replay_row.get("params", {}) as Dictionary).get("factor", 0.0)), 0.35):
		m.append("replay row %s, expected delta -19 and factor 0.35" % JSON.stringify(replay_row))
	var base_row := _row_by_cause(replayed["breakdown"], "objectives_overcome")
	if int(base_row.get("delta", 0)) != 30 or not is_equal_approx(float((base_row.get("params", {}) as Dictionary).get("realm_scale", 0.0)), 1.5):
		m.append("base row %s, expected delta 30 and realm_scale 1.5" % JSON.stringify(base_row))
	# A zero base has nothing to lower: no replay row.
	if not _row_by_cause(EconomyService.stage_payout_rows(0, 1.25, 0.35)["breakdown"], "replay").is_empty():
		m.append("a replay row exists on a base of 0")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## ASSUMED (phase5-3-build.md): the defeat consolation takes the realm scale and the replay factor
## of the objective it is paid for: round(weight x scale x 0.25 x replay). The 0.25 is unchanged.
static func _t_consolation_scaled() -> Dictionary:
	var m: Array = []
	# [type, run_count, realm scale, expected]
	for c in [
		["combat", 0, 1.0, 5], ["combat", 1, 1.0, 2], ["shrine", 0, 1.0, 8], ["shrine", 1, 1.0, 3],
		["combat", 0, 1.25, 6], ["combat", 1, 1.25, 2], ["shrine", 0, 1.25, 9], ["shrine", 1, 1.25, 3],
		["guide_spirit", 0, 1.25, 10], ["guide_spirit", 1, 1.25, 4], ["pursue", 1, 1.5, 2], ["boss", 0, 1.25, 0],
	]:
		var paid := _encounter_pay(_objectives(c[0]), false, c[1], 0, c[2])
		if int(paid["ase_awarded"]) != int(c[3]):
			m.append("%s run %d scale %s: consolation %d, expected %d" % [c[0], c[1], str(c[2]), int(paid["ase_awarded"]), int(c[3])])
		var sum := 0
		for row_v in paid["breakdown"]:
			sum += int((row_v as Dictionary)["delta"])
		if int(c[3]) > 0 and sum != int(paid["ase_awarded"]):
			m.append("%s run %d scale %s: the rows add to %d, paid %d" % [c[0], c[1], str(c[2]), sum, int(paid["ase_awarded"])])
	# A replay never pays more consolation than the same defeat on a first run.
	for type in ["pursue", "combat", "recover", "endure", "shrine", "guide_spirit"]:
		for scale in [1.0, 1.25, 1.5]:
			if int(_encounter_pay(_objectives(type), false, 1, 0, scale)["ase_awarded"]) \
					> int(_encounter_pay(_objectives(type), false, 0, 0, scale)["ase_awarded"]):
				m.append("%s scale %s: a replay pays more consolation than a first run" % [type, str(scale)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## REWRITTEN (D-104 to D-106): the gathered amount of a return home follows the realm scale and the replay
## factor, with no 12% factor. A replay never gathers more than the first run.
static func _t_partial_factors() -> Dictionary:
	var m: Array = []
	var cfg := _config()
	var boss := ObjectiveModel.make(1, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	# [realm, run_count, gathered Ase of a completed shrine (30)]: 30; 30 x 0.35 = 10.5 -> 11; 37.5 -> 38; 13.125 -> 13.
	for c in [["realm.01", 0, 30], ["realm.01", 1, 11], ["realm.02", 0, 38], ["realm.02", 1, 13]]:
		var ctx := _stage_ctx(cfg, [_obj(0, "shrine", true), boss.duplicate(true)])
		var stage_realm: Dictionary = ctx.save_data["realms"]["realm.01"]
		stage_realm["run_count"] = c[1]
		ctx.save_data["realms"][c[0]] = stage_realm
		ctx.realm_id = c[0]
		var gathered := int(StageSettlementService.settle_plan(ctx, cfg)["ase"])
		if gathered != c[2]:
			m.append("%s run %d: gathered %d, expected %d" % [c[0], c[1], gathered, c[2]])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Names removed by D-40, D-49 and D-54. None may stay in data.rewards or in core/ (no alias).
const _REMOVED_NAMES := [
	"redo_penalty_per_run", "redo_penalty_floor", "redo_multiplier",
	"enemy_defeated_bonus", "virtue_bonuses", "stage_index_bonus_per", "realm_order_multiplier",
	"calculate_stage_reward", "pace_bonus_pct", "max_bonus_ase", "bonus_ase", "pace_bonus",
	"bonus_earned", "bonus_missed", "enemy_bonus", "pace_stage_base",
	"echo_survived_bonus", "echo_bonus",
]

static func _t_removed_keys_absent() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	for name in _REMOVED_NAMES:
		if cfg.has(name):
			m.append("data.rewards still has %s" % name)
	if not cfg.has("rank_points"):
		m.append("data.rewards.rank_points missing")
	var pending: Array = ["res://core"]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			pending.append(dir_path + "/" + sub)
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path + "/" + file_name)
			for name in _REMOVED_NAMES:
				if text.contains(name):
					m.append("%s/%s still names %s" % [dir_path, file_name, name])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Stage payer (StageSettlementService.settle -> EconomyService.settle_stage_complete)
# ---------------------------------------------------------------------------

## Pays one cell through the real settle() on a real booted runtime and returns the payout.
static func _settle_cell(env: Dictionary, objectives: Array, stage_index: int, run_count: int, n: int,
		preview_out: Dictionary = {}, realm_id: String = "realm.01",
		settled_ase: int = 0, settled_ekwan: int = 0) -> Dictionary:
	var runtime: FlowRuntime = env["runtime"]
	var save_data: Dictionary = runtime.get_save_data()
	if realm_id != "realm.01" and not (save_data["realms"] as Dictionary).has(realm_id):
		(save_data["realms"] as Dictionary)[realm_id] = VentureCharacterizationTests._realm(save_data, "realm.01").duplicate(true)
	var realm: Dictionary = VentureCharacterizationTests._realm(save_data, realm_id)
	var stages: Array = realm["stages"]
	var stage: Dictionary = {}
	for s_v in stages:
		if int((s_v as Dictionary).get("index", -1)) == stage_index:
			stage = s_v
	if stage.is_empty():
		stage = StageModel.make(stage_index, "combat", stage_index, [], {})
		stages.append(stage)
	stage["objectives"] = objectives
	stage["settlement_receipt"] = {}
	stage.erase("settled_ase")
	stage.erase("settled_ekwan")
	if settled_ase > 0 or settled_ekwan > 0:
		stage["settled_ase"] = settled_ase
		stage["settled_ekwan"] = settled_ekwan
	realm["run_count"] = run_count
	realm["run_index"] = 0
	var economy: Dictionary = save_data["economy"]
	economy["ase"] = 0
	economy["ekwan"] = 0
	runtime.flow_ctx.realm_id = realm_id
	runtime.flow_ctx.stage_id = "stage.%d" % stage_index
	if preview_out != null:
		var before := JSON.stringify(save_data, "", true)
		var svc := StageSettlementService.new(runtime.flow_ctx, runtime.config_service, null, null)
		preview_out["first"] = svc.preview()
		preview_out["second"] = svc.preview()
		preview_out["pure"] = JSON.stringify(save_data, "", true) == before
	var econ := EconomyService.new(save_data)
	var payout: Dictionary = StageSettlementService.new(
		runtime.flow_ctx, runtime.config_service, econ, env["logger"]).settle(true, 5000 + n)
	payout["balance_ase"] = int(economy["ase"])
	payout["balance_ekwan"] = int(economy["ekwan"])
	return payout


static func _t_stage_payer_matrix() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_stage")
	if not bool(env.get("ok", false)):
		return env
	var mismatches: Array = []
	var n := 0
	for realm_id in _STAGE_CELLS:
		for run_count in [0, 1]:
			for type in ObjectiveModel.VALID_TYPES:
				for i in range(_STAGE_COUNT):
					n += 1
					var pv: Dictionary = {}
					var out := _settle_cell(env, _objectives(type), i, run_count, n, pv, realm_id)
					var cell := "%s %s run %d stage %d" % [realm_id, type, run_count, i]
					var want_ase: int = int(_STAGE_CELLS[realm_id][run_count][type][0]) + _ONE_ECHO_STIPEND
					var want_ekwan: int = _STAGE_CELLS[realm_id][run_count][type][1]
					if int(out.get("ase_awarded", -1)) != want_ase or int(out.get("balance_ase", -1)) != want_ase:
						mismatches.append("%s ase %s/%s, expected %d" % [cell, str(out.get("ase_awarded")), str(out.get("balance_ase")), want_ase])
					if int(out.get("ekwan_awarded", -1)) != want_ekwan or int(out.get("balance_ekwan", -1)) != want_ekwan:
						mismatches.append("%s ekwan %s/%s, expected %d" % [cell, str(out.get("ekwan_awarded")), str(out.get("balance_ekwan")), want_ekwan])
					var first: Dictionary = pv["first"]
					if int(first.get("ase", -1)) != want_ase or int(first.get("ekwan", -1)) != want_ekwan:
						mismatches.append("%s preview %s/%s, expected %d/%d" % [cell, str(first.get("ase")), str(first.get("ekwan")), want_ase, want_ekwan])
					for row_v in out.get("breakdown", []):
						if str((row_v as Dictionary).get("currency", "")) == "ekwan":
							mismatches.append("%s has an Ekwan breakdown row (D-32)" % cell)
					var base_row := _breakdown_delta(out, "Base objectives")
					var want_base := RewardCalc.round_payout(float(_TYPE_WEIGHT[type]) * float(_REALM_SCALE[realm_id]))
					if base_row != want_base:
						mismatches.append("%s base row %d, expected %d" % [cell, base_row, want_base])
					var replay_row := _row_by_cause(out.get("breakdown", []), "replay")
					var changes: bool = run_count > 0 and int(_STAGE_CELLS[realm_id][run_count][type][0]) != want_base
					if changes != not replay_row.is_empty():
						mismatches.append("%s replay row present=%s, expected %s" % [cell, str(not replay_row.is_empty()), str(changes)])
					elif changes and (int(replay_row["delta"]) != int(_STAGE_CELLS[realm_id][run_count][type][0]) - want_base \
							or not is_equal_approx(float((replay_row["params"] as Dictionary).get("factor", 0.0)), 0.35)):
						mismatches.append("%s replay row %s" % [cell, JSON.stringify(replay_row)])
					if not _row_by_cause(out.get("breakdown", []), "realm_virtue").is_empty():
						mismatches.append("%s has a realm_virtue row (D-40)" % cell)
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _breakdown_delta(payout: Dictionary, label: String) -> int:
	for row_v in payout.get("breakdown", []):
		if str((row_v as Dictionary).get("label", "")) == label:
			return int((row_v as Dictionary).get("delta", 0))
	return 0


## Each type, completed alone, pays its configured Ekwan; the config holds exactly the recorded
## types (D-29), including the boss at 0, so every VALID_TYPES entry has a key.
static func _t_ekwan_per_type() -> Dictionary:
	var cfg := _rewards_cfg()
	var table: Dictionary = cfg.get("objective_ekwan", {})
	var logger := StructuredLogger.new()
	var m: Array = []
	for type in ObjectiveModel.VALID_TYPES:
		if not table.has(type):
			m.append("objective_ekwan has no key for %s" % type)
		if not _TYPE_EKWAN.has(type):
			m.append("VALID_TYPES gained a type this suite does not record: %s" % type)
			continue
		var got := RewardCalc.stage_ekwan([_obj(0, type, true)], cfg, logger, 1)
		if got != int(_TYPE_EKWAN[type]) or int(table.get(type, -1)) != int(_TYPE_EKWAN[type]):
			m.append("%s pays %d (config %s), expected %d" % [type, got, str(table.get(type)), int(_TYPE_EKWAN[type])])
	if table.size() != _TYPE_EKWAN.size():
		m.append("objective_ekwan keys changed: %s" % str(table))
	if not logger.get_logs().is_empty():
		m.append("a configured type logged: %s" % str(logger.get_logs()))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-06, D-16: the stage Ekwan is the SUM over completed objectives. An objective that is not
## completed pays 0 and is never looked up. The boss stub pays 0.
static func _t_ekwan_completed_only() -> Dictionary:
	var cfg := _rewards_cfg()
	var boss := ObjectiveModel.make(3, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var m: Array = []
	var both: Array = [_obj(0, "combat", true), _obj(1, "recover", true), boss]
	if RewardCalc.stage_ekwan(both, cfg) != 7:
		m.append("combat + recover paid %d, expected 7" % RewardCalc.stage_ekwan(both, cfg))
	var one: Array = [_obj(0, "combat", true), _obj(1, "recover", false), boss]
	if RewardCalc.stage_ekwan(one, cfg) != 2:
		m.append("an incomplete recover changed the sum: %d, expected 2" % RewardCalc.stage_ekwan(one, cfg))
	var none: Array = [_obj(0, "shrine", false), boss]
	if RewardCalc.stage_ekwan(none, cfg) != 0:
		m.append("an incomplete shrine paid %d, expected 0" % RewardCalc.stage_ekwan(none, cfg))
	var logger := StructuredLogger.new()
	if RewardCalc.stage_ekwan([{ "type": "mystery", "completed": false }], cfg, logger, 3) != 0 \
			or not logger.get_logs().is_empty():
		m.append("an uncompleted unknown type logged or paid")
	# Through the real stage payer: only the completed objective pays and is banked.
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_ekwan_sum")
	if not bool(env.get("ok", false)):
		return env
	var out := _settle_cell(env, one, 0, 0, 1)
	if int(out.get("ekwan_awarded", -1)) != 2 or int(out.get("balance_ekwan", -1)) != 2:
		m.append("stage paid ekwan %s/%s, expected 2/2" % [str(out.get("ekwan_awarded")), str(out.get("balance_ekwan"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-07 for the Ekwan table: a selected type with no key logs the unknown-type event naming the
## table, and pays 0. It never falls back to combat.
static func _t_ekwan_unknown_type() -> Dictionary:
	var cfg := _rewards_cfg()
	var m: Array = []
	var logger := StructuredLogger.new()
	var objs: Array = [{ "type": "mystery", "completed": true }, _obj(1, "combat", true)]
	if RewardCalc.stage_ekwan(objs, cfg, logger, 7) != 2:
		m.append("unknown + combat paid %d, expected 2" % RewardCalc.stage_ekwan(objs, cfg))
	var logs := logger.get_logs()
	if logs.size() != 1:
		m.append("expected 1 log line, got %d" % logs.size())
	else:
		var e: Dictionary = logs[0]
		var d: Dictionary = e["data"]
		if str(e["type"]) != "economy.reward.unknown_objective_type" or int(e["t"]) != 7 \
				or str(d.get("type")) != "mystery" or str(d.get("table")) != "objective_ekwan":
			m.append("log line is %s" % str(e))
	var trimmed := cfg.duplicate(true)
	(trimmed["objective_ekwan"] as Dictionary).erase("shrine")
	var logger2 := StructuredLogger.new()
	if RewardCalc.stage_ekwan([_obj(0, "shrine", true)], trimmed, logger2, 3) != 0 or logger2.get_logs().size() != 1:
		m.append("shrine without an Ekwan key did not pay 0 with one log line")
	# The Ase table still has the key, so the Ase base logs nothing for it.
	var logger3 := StructuredLogger.new()
	if RewardCalc.base_reward([_obj(0, "shrine", true)], trimmed, logger3, 3) != 30 or not logger3.get_logs().is_empty():
		m.append("the Ase table was affected by the missing Ekwan key")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-30, D-54: the stage Ekwan follows the replay factor (flat 0.35) and the realm scale, and is
## rounded ONCE on the stage sum. x.5 cells: endure 4 + endure 4 + combat 2 = 10 at 0.35 = 3.5 -> 4,
## while per-objective rounding gives 1 + 1 + 1 = 3; recover 5 + recover 5 at 1.25 = 12.5 -> 13,
## while per-objective rounding gives 6 + 6 = 12 (roundi rounds half away from zero).
static func _t_ekwan_replay() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_ekwan_replay")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(3, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var m: Array = []
	var n := 0
	# [objective types, realm, run_count, expected Ekwan]
	for c in [
		[["recover"], "realm.01", 1, 2], [["protect"], "realm.01", 1, 1], [["protect"], "realm.01", 6, 1],
		[["endure", "endure", "combat"], "realm.01", 1, 4], [["shrine", "guide_spirit"], "realm.01", 0, 9],
		[["shrine", "guide_spirit"], "realm.01", 5, 3], [["combat"], "realm.01", 5, 1], [["pursue"], "realm.01", 6, 1],
		[["recover", "recover"], "realm.02", 0, 13], [["shrine", "combat"], "realm.02", 1, 4],
		[["shrine"], "realm.02", 0, 8],
	]:
		n += 1
		var objs: Array = []
		for k in range((c[0] as Array).size()):
			objs.append(_obj(k, c[0][k], true))
		objs.append(boss.duplicate(true))
		var out := _settle_cell(env, objs, 0, int(c[2]), 20 + n, {}, c[1])
		if int(out.get("ekwan_awarded", -1)) != int(c[3]) or int(out.get("balance_ekwan", -1)) != int(c[3]):
			m.append("%s %s run %d paid ekwan %s/%s, expected %d" \
				% [str(c[0]), c[1], int(c[2]), str(out.get("ekwan_awarded")), str(out.get("balance_ekwan")), int(c[3])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Encounter payer (EconomyService.reward_encounter_complete)
# ---------------------------------------------------------------------------

## Fight: 2 of 2 echoes, a no-pace mode. A won fight pays 0 Ase and has no rows (D-43, D-44):
## the Echoes stipend is a stage payout row.
static func _t_encounter_victory() -> Dictionary:
	var want := { 0: 0, 1: 0 }
	var mismatches: Array = []
	for type in ObjectiveModel.VALID_TYPES:
		for run_count in [0, 1]:
			var paid := _encounter_pay(_objectives(type), true, run_count)
			if int(paid["ase_awarded"]) != want[run_count] or int(paid["balance_ase"]) != want[run_count]:
				mismatches.append("%s run %d victory ase %d" % [type, run_count, int(paid["ase_awarded"])])
			if int(paid["ekwan_awarded"]) != 0 or int(paid["balance_ekwan"]) != 0:
				mismatches.append("%s run %d victory ekwan %d, expected 0 (D-28)" % [type, run_count, int(paid["ekwan_awarded"])])
			if int(paid["base_reward"]) != _expected_base(type):
				mismatches.append("%s base_reward %d" % [type, int(paid["base_reward"])])
			if not (paid["breakdown"] as Array).is_empty():
				mismatches.append("%s run %d victory has rows %s" % [type, run_count, JSON.stringify(paid["breakdown"])])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## Defeat pays round(base x scale x 0.25 x replay), the one consolation. The base is the weight of
## the fought objective (D-13); here the fought objective is the only pre-boss objective.
static func _t_encounter_defeat() -> Dictionary:
	# fought weight -> run_count -> Ase, at realm.01. A defeat pays no Ekwan (D-28).
	var want := {
		0:  { 0: 0, 1: 0 },
		16: { 0: 4, 1: 1 },
		20: { 0: 5, 1: 2 },
		24: { 0: 6, 1: 2 },
		28: { 0: 7, 1: 2 },
		30: { 0: 8, 1: 3 },
		32: { 0: 8, 1: 3 },
	}
	var mismatches: Array = []
	for type in ObjectiveModel.VALID_TYPES:
		var base := _expected_base(type)
		for run_count in [0, 1]:
			var paid := _encounter_pay(_objectives(type), false, run_count)
			var w: int = want[base][run_count]
			if int(paid["ase_awarded"]) != w or int(paid["ekwan_awarded"]) != 0 or int(paid["balance_ekwan"]) != 0:
				mismatches.append("%s run %d defeat paid %d/%d, expected %d/0" \
					% [type, run_count, int(paid["ase_awarded"]), int(paid["ekwan_awarded"]), w])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## D-28, D-32: no fight result carries Ekwan, and no breakdown row has currency "ekwan".
static func _t_fights_pay_no_ekwan() -> Dictionary:
	var m: Array = []
	for c in [[true, 1.0], [true, 0.35], [false, 1.0], [false, 0.35]]:
		var paid := _pay(c[0], c[1])
		if int(paid["ekwan_awarded"]) != 0:
			m.append("%s paid ekwan %d" % [str(c), int(paid["ekwan_awarded"])])
		for row_v in paid["breakdown"]:
			if str((row_v as Dictionary).get("currency", "")) != "ase":
				m.append("%s has a non-Ase row %s" % [str(c), JSON.stringify(row_v)])
	var repeat := _pay(false, 1.0, false)
	if int(repeat["ekwan_awarded"]) != 0:
		m.append("a repeat defeat paid ekwan")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# The key defect (D66, D83)
# ---------------------------------------------------------------------------

static func _t_model_key() -> Dictionary:
	var obj := ObjectiveModel.make(0, "shrine", 1)
	var ok := obj.has("type") and not obj.has("obj_type")
	return { "ok": ok, "error": "ObjectiveModel keys: %s" % str(obj.keys()) }


## D-27: the old Ekwan keys are gone from the config and from every file in core/, and the
## stage payer no longer reads the first objective's type (D-06).
static func _t_old_keys_removed() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	for key in ["ekwan_base_factor", "ekwan_shrine_multiplier"]:
		if cfg.has(key):
			m.append("data.rewards still has %s" % key)
	var stack: Array = ["res://core"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path.path_join(sub))
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			var path := dir_path.path_join(file)
			var text := FileAccess.get_file_as_string(path)
			for word in ["ekwan_base_factor", "ekwan_shrine_multiplier", "ekwan_factor"]:
				if text.contains(word):
					m.append("%s still mentions %s" % [path, word])
	var settle_text := FileAccess.get_file_as_string("res://core/economy/StageSettlementService.gd")
	if settle_text.contains(".get(\"type\", \"combat\")"):
		m.append("StageSettlementService still defaults an objective type to combat")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Objective draw pool of realm.01 and realm.02 (RealmGenerator)
# ---------------------------------------------------------------------------

# seed count -> realm -> { stages, zero (stages whose non-boss weight sum is 0), pre (pre-boss
# objective count -> stages), types (objective type -> count, boss included) }
const _POOL := {
	25: {
		"realm.01": { "stages": 89, "zero": 0, "pre": { 1: 89 },
			"types": { "combat": 15, "shrine": 12, "recover": 13, "protect": 8, "endure": 11, "pursue": 18, "guide_spirit": 12, "boss": 89 } },
		"realm.02": { "stages": 151, "zero": 0, "pre": { 1: 80, 2: 71 },
			"types": { "combat": 32, "shrine": 43, "recover": 36, "protect": 25, "endure": 26, "pursue": 21, "guide_spirit": 39, "boss": 151 } },
	},
	200: {
		"realm.01": { "stages": 700, "zero": 0, "pre": { 1: 700 },
			"types": { "combat": 98, "shrine": 100, "recover": 106, "protect": 88, "endure": 104, "pursue": 120, "guide_spirit": 84, "boss": 700 } },
		"realm.02": { "stages": 1187, "zero": 0, "pre": { 1: 576, 2: 611 },
			"types": { "combat": 244, "shrine": 271, "recover": 259, "protect": 241, "endure": 244, "pursue": 256, "guide_spirit": 283, "boss": 1187 } },
	},
}


static func _make_ctx(root_seed: int, cfg: ConfigService) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = cfg
	ctx.campaign_seed = CampaignSeed.new(root_seed)
	ctx.save_data = { "realms": {} }
	ctx.logger = _logger()
	return ctx


## Same objectives as RealmService.get_or_create (see _t_fast_matches_service), with small
## explore maps: the maps cost most of the time and draw from separate RNG paths.
static func _fast_stages(realm_id: String, root_seed: int, realms: Dictionary, stages_cfg: Dictionary) -> Array:
	var rc: Dictionary = realms[realm_id]
	var realm_seed: int = CampaignSeed.new(root_seed).derive(str(rc["seed_namespace"]) + ".run.0")
	var count := CampaignSeed.get_rng_from(realm_seed, "stage_count").randi_range(int(rc["stage_count_min"]), int(rc["stage_count_max"]))
	return RealmGenerator.generate(realm_seed, count, int(rc["obj_count_min"]), int(rc["obj_count_max"]),
		{
			"objective_pool": rc["objective_pool"],
			"sit_count_min": int(rc["sit_count_min"]), "sit_count_max": int(rc["sit_count_min"]),
			"map_width_min": 30, "map_width_max": 30, "map_height_min": 30, "map_height_max": 30,
		}, stages_cfg)


static func _objective_signature(stages: Array) -> String:
	var parts: Array = []
	for st in stages:
		var ts: Array = []
		for o in st["objectives"]:
			ts.append("%s:%d" % [str(o["type"]), int(o["seed"])])
		parts.append(",".join(ts))
	return "|".join(parts)


static func _t_fast_matches_service() -> Dictionary:
	var cfg := _config()
	var realms: Dictionary = cfg.get_realms()["data"]["realms"]
	var stages_cfg: Dictionary = cfg.get_balance()["data"]["stages"]
	var mismatches: Array = []
	for realm_id in ["realm.01", "realm.02"]:
		for s in range(1, 4):
			var model: Dictionary = RealmService.get_or_create(realm_id, _make_ctx(s, cfg), 0)
			if _objective_signature(model["stages"]) != _objective_signature(_fast_stages(realm_id, s, realms, stages_cfg)):
				mismatches.append("%s seed %d differs from RealmService" % [realm_id, s])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _t_pool_frequency() -> Dictionary:
	var seeds := int(OS.get_environment("ECONOMY_CHAR_SEEDS")) if OS.get_environment("ECONOMY_CHAR_SEEDS") != "" else _DEFAULT_SEEDS
	var cfg := _config()
	var rewards: Dictionary = ConfigService.get_rewards_cfg(cfg)
	var realms: Dictionary = cfg.get_realms()["data"]["realms"]
	var stages_cfg: Dictionary = cfg.get_balance()["data"]["stages"]
	var measured := {}
	for realm_id in ["realm.01", "realm.02"]:
		var row := { "stages": 0, "zero": 0, "pre": {}, "types": {} }
		for s in range(1, seeds + 1):
			for st in _fast_stages(realm_id, s, realms, stages_cfg):
				row["stages"] += 1
				var non_boss_weight := 0
				var pre := 0
				for o in st["objectives"]:
					var type := str(o["type"])
					row["types"][type] = int(row["types"].get(type, 0)) + 1
					if type != ObjectiveModel.TYPE_BOSS:
						pre += 1
						non_boss_weight += RewardCalc.base_reward([o], rewards, null, 0, RewardCalc.MODE_FOUGHT, 0)
				row["pre"][pre] = int(row["pre"].get(pre, 0)) + 1
				if non_boss_weight == 0:
					row["zero"] += 1
		measured[realm_id] = row
	if not _POOL.has(seeds):
		return { "ok": false, "error": "no frozen table for %d seeds; measured %s" % [seeds, str(measured)] }
	return { "ok": _same(measured, _POOL[seeds]),
		"error": "measured %s, frozen %s" % [str(measured), str(_POOL[seeds])] }


## Order-free comparison of two nested Dictionaries of ints.
static func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	return a == b


# ---------------------------------------------------------------------------
# Phase 3b: completed-only base in every reader (D-11 to D-15)
# These tests call the pure helper, the settle() payer and compute() directly. They do not
# dispatch a real retreat or return-home: both need a booted fight or a built explore map, so the
# two handlers are covered by the formula plus the shared get_stage_base_reward() read.
# ---------------------------------------------------------------------------

## (a) The stage payer pays the weights of completed objectives. Stage 0, run 0: combat done
## (20), shrine not done, boss stub: base row 20, Ase 20.
static func _t_stage_payer_completed_only() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_completed_only")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var out := _settle_cell(env, [_obj(0, "combat", true), _obj(1, "shrine", false), boss], 0, 0, 1)
	var mismatches: Array = []
	if _breakdown_delta(out, "Base objectives") != 20 or int(out.get("ase_awarded", -1)) != 20 + _ONE_ECHO_STIPEND:
		mismatches.append("one of two objectives done: base row %d, ase %s, expected 20 / 22" \
			% [_breakdown_delta(out, "Base objectives"), str(out.get("ase_awarded"))])
	out = _settle_cell(env, [_obj(0, "combat", false), boss.duplicate(true)], 0, 0, 2)
	if _breakdown_delta(out, "Base objectives") != 0 or int(out.get("ase_awarded", -1)) != _ONE_ECHO_STIPEND:
		mismatches.append("nothing done: base row %d, ase %s, expected 0 / 2" \
			% [_breakdown_delta(out, "Base objectives"), str(out.get("ase_awarded"))])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (b) An uncompleted optional objective adds nothing; completing it adds its weight.
static func _t_uncompleted_adds_nothing() -> Dictionary:
	var cfg := _rewards_cfg()
	var optional := ObjectiveModel.make(1, ObjectiveModel.TYPE_PURSUE, 1, {}, false, false)
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var objs: Array = [_obj(0, "combat", true), optional, boss]
	var mismatches: Array = []
	var skipped := RewardCalc.base_reward(objs, cfg)
	(objs[1] as Dictionary)["completed"] = true
	var done := RewardCalc.base_reward(objs, cfg)
	if skipped != 20 or done != 36:
		mismatches.append("optional skipped %d (expected 20), done %d (expected 36)" % [skipped, done])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (c) The completed-plus-fought base is the completed objectives plus the fought one, so the
## first fight of a stage has a base (completed-only would give 0).
static func _t_pace_base() -> Dictionary:
	var cfg := _config()
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var mismatches: Array = []
	var first := _stage_ctx(cfg, [_obj(0, "guide_spirit", false), _obj(1, "combat", false), boss], 0)
	var plain := ActiveStageService.get_stage_base_reward(first, cfg)
	var pace := ActiveStageService.get_stage_base_reward(first, cfg, null, 0, RewardCalc.MODE_COMPLETED_PLUS_FOUGHT)
	if plain != 0 or pace != 32:
		mismatches.append("first fight: completed-only %d (expected 0), pace base %d (expected 32)" % [plain, pace])
	var second := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], 1)
	pace = ActiveStageService.get_stage_base_reward(second, cfg, null, 0, RewardCalc.MODE_COMPLETED_PLUS_FOUGHT)
	if pace != 52:
		mismatches.append("second fight: pace base %d, expected 52 (32 done + 20 fought)" % pace)
	var none := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], -1)
	pace = ActiveStageService.get_stage_base_reward(none, cfg, null, 0, RewardCalc.MODE_COMPLETED_PLUS_FOUGHT)
	if pace != 32:
		mismatches.append("no fought objective: pace base %d, expected 32" % pace)
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (d) The first defeat of a stage pays 25% of the fought objective's weight, not of the stage sum.
## Fought: shrine (30), after a completed combat (20): round(30 x 0.25) = 8 Ase.
static func _t_first_defeat() -> Dictionary:
	var objs: Array = [_obj(0, "combat", true), _obj(1, "shrine", false)]
	var paid := _encounter_pay(objs, false, 0, 1)
	var mismatches: Array = []
	if int(paid["ase_awarded"]) != 8:
		mismatches.append("defeat on the second objective paid %d, expected 8" % int(paid["ase_awarded"]))
	var first := _encounter_pay([_obj(0, "combat", false), _obj(1, "shrine", false)], false, 0, 0)
	if int(first["ase_awarded"]) != 5:
		mismatches.append("first defeat with no completed objective paid %d, expected 5" % int(first["ase_awarded"]))
	var no_objective := _encounter_pay([_obj(0, "combat", true)], false, 0, -1)
	if int(no_objective["ase_awarded"]) != 0:
		mismatches.append("defeat of a non-objective situation paid %d, expected 0" % int(no_objective["ase_awarded"]))
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (e) REWRITTEN (D-104 to D-106): what a return home gathers is the completed weights (no 12% factor), and
## nothing before any completion (`nothing_new`, so the payer draws no roll).
static func _t_partials_completed() -> Dictionary:
	var cfg := _config()
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var mismatches: Array = []
	var before := _stage_ctx(cfg, [_obj(0, "guide_spirit", false), _obj(1, "combat", false), boss], 0)
	var base := ActiveStageService.get_stage_base_reward(before, cfg)
	var plan := StageSettlementService.settle_plan(before, cfg)
	if base != 0 or int(plan["ase"]) != 0 or not bool(plan["nothing_new"]):
		mismatches.append("before any completion: base %d plan %s, expected 0 and nothing_new" % [base, str(plan)])
	var after := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], 1)
	base = ActiveStageService.get_stage_base_reward(after, cfg)
	plan = StageSettlementService.settle_plan(after, cfg)
	if base != 32 or int(plan["ase"]) != 32 or int(plan["ekwan"]) != 3 or bool(plan["nothing_new"]):
		mismatches.append("after one completion: base %d plan %s, expected 32 / 32 / 3" % [base, str(plan)])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (f) Rank reads no objective weight: an objective the party never reached changes nothing.
static func _t_rank_unreached() -> Dictionary:
	var cfg := _rewards_cfg()
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var with_unreached: Array = [_obj(0, "combat", true), _obj(1, "shrine", false), boss]
	var without: Array = [_obj(0, "combat", true), boss]
	var mismatches: Array = []
	for c in [[2, 2], [1, 2], [0, 2]]:
		for victory in [true, false]:
			var a: Dictionary = RewardCalc.compute(victory, with_unreached, c[0], c[1], 2, 0, cfg,
				EncounterResolutionModes.COMBAT, 0.0, "", null, 0, 0)
			var b: Dictionary = RewardCalc.compute(victory, without, c[0], c[1], 2, 0, cfg,
				EncounterResolutionModes.COMBAT, 0.0, "", null, 0, 0)
			if str(a["rank"]) != str(b["rank"]) or int(a["base_reward"]) != int(b["base_reward"]):
				mismatches.append("%s %s: rank %s/%s base %d/%d" % [str(c), str(victory),
					str(a["rank"]), str(b["rank"]), int(a["base_reward"]), int(b["base_reward"])])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


# ---------------------------------------------------------------------------
# Payout row causes (Phase 3c). Rows gain `cause` and `params`; `delta` never changes.
# ---------------------------------------------------------------------------

static func _row_by_cause(breakdown: Array, cause: String) -> Dictionary:
	for row_v in breakdown:
		if row_v is Dictionary and str((row_v as Dictionary).get("cause", "")) == cause:
			return row_v
	return {}


## Pays one encounter straight through EconomyService with explicit inputs.
static func _pay(victory: bool, replay: float, eligible: bool = true, scale: float = 1.0) -> Dictionary:
	var econ := EconomyService.new({ "economy": { "ase": 0, "ekwan": 0 } })
	return econ.reward_encounter_complete(victory, 10, scale, replay, "B", eligible, _logger(), 1, 0.25)


static func _t_cause_encounter_rows() -> Dictionary:
	var m: Array = []
	for factor in [0.35, 1.0]:
		var win := _pay(true, factor)
		if int(win["ase_awarded"]) != 0 or not (win["breakdown"] as Array).is_empty():
			m.append("a won fight at replay factor %s paid %s rows %s" % [str(factor), str(win["ase_awarded"]), JSON.stringify(win["breakdown"])])
	var bd: Array = _pay(false, 0.35)["breakdown"]
	var replay := _row_by_cause(bd, "replay")
	if replay.is_empty() or not is_equal_approx(float((replay.get("params", {}) as Dictionary).get("factor", 0.0)), 0.35):
		m.append("defeat replay row or factor: %s" % JSON.stringify(replay))
	if not _row_by_cause(_pay(false, 1.0)["breakdown"], "replay").is_empty():
		m.append("replay row present at replay factor 1.0 (run_count 0)")
	var defeat: Array = _pay(false, 0.35)["breakdown"]
	var parts: Array = []
	for row_v in defeat:
		if str((row_v as Dictionary).get("cause", "")) == "defeat_consolation":
			parts.append(str(((row_v as Dictionary).get("params", {}) as Dictionary).get("part", "")))
	if parts != ["base", "penalty"]:
		m.append("defeat_consolation parts %s" % str(parts))
	for row_v in bd:
		var row: Dictionary = row_v
		if not row.has("cause") or not (row.get("params") is Dictionary) or not row.has("label") or not row.has("currency"):
			m.append("row missing a key: %s" % JSON.stringify(row))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_cause_zero_rows() -> Dictionary:
	var m: Array = []
	var paid := _pay(false, 1.0, false)
	var bd: Array = paid["breakdown"]
	if int(paid["ase_awarded"]) != 0 or bd.size() != 1 or str((bd[0] as Dictionary).get("cause", "")) != "repeat_defeat" \
			or int((bd[0] as Dictionary).get("delta", -1)) != 0:
		m.append("repeat defeat rows: %s" % JSON.stringify(bd))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_cause_stage_rows() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_cause_stage")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var m: Array = []
	var out := _settle_cell(env, [_obj(0, "combat", true), _obj(1, "shrine", false), boss], 0, 1, 1)
	var bd: Array = out["breakdown"]
	var base := _row_by_cause(bd, "objectives_overcome")
	var p: Dictionary = base.get("params", {})
	if int(p.get("overcome", -1)) != 1 or int(p.get("total", -1)) != 2:
		m.append("objectives_overcome params %s, expected overcome 1 of 2 (boss stub excluded)" % JSON.stringify(base))
	if not _row_by_cause(bd, "realm_virtue").is_empty():
		m.append("realm_virtue row present (D-40)")
	if _row_by_cause(bd, "replay").is_empty():
		m.append("replay row missing at run_count 1")
	for row_v in bd:
		if str((row_v as Dictionary).get("currency", "")) == "ekwan":
			m.append("a breakdown row has currency ekwan (D-32)")
	out = _settle_cell(env, [_obj(0, "combat", true), boss.duplicate(true)], 0, 0, 2)
	if not _row_by_cause(out["breakdown"], "replay").is_empty():
		m.append("replay row present at run_count 0")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _scout_ctx(objs: Array, ase: int) -> FlowContext:
	var ctx := _stage_ctx(_config(), objs)
	ctx.pending_scout_return_ase = ase
	ctx.pending_scout_return_intel_count = 2
	return ctx


static func _t_cause_scout_rows() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var done: Array = [_obj(0, "combat", true), _obj(1, "shrine", false), boss]
	# REWRITTEN (D-105/D-106): the return-home row is named by the settle outcome (`settle_some`), not the
	# old fixed `partial_return_home` cause. A retreat settles nothing, so it has no row until step 6.2.
	var ctx_home := _scout_ctx(done, 3)
	ctx_home.pending_scout_return_settle_outcome = "some"
	var home: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(ctx_home, 1)["data"]["reward_breakdown"]
	var retreat: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(
		_scout_ctx(done, 0), 1, "scout_return", "partial_retreat")["data"]["reward_breakdown"]
	if home.size() != 1 or str((home[0] as Dictionary).get("cause", "")) != "settle_some" \
			or int(((home[0] as Dictionary).get("params", {}) as Dictionary).get("overcome", -1)) != 1 \
			or int(((home[0] as Dictionary).get("params", {}) as Dictionary).get("total", -1)) != 2 \
			or int((home[0] as Dictionary).get("delta", -1)) != 3:
		m.append("return-home row: %s" % JSON.stringify(home))
	if not retreat.is_empty():
		m.append("retreat row (a retreat settles nothing): %s" % JSON.stringify(retreat))
	var none: Array = [_obj(0, "combat", false), boss.duplicate(true)]
	var zero: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(
		_scout_ctx(none, 0), 1, "scout_return", "partial_retreat")["data"]["reward_breakdown"]
	if zero.size() != 1 or str((zero[0] as Dictionary).get("cause", "")) != "nothing_overcome_yet" \
			or int((zero[0] as Dictionary).get("delta", -1)) != 0 \
			or str(((zero[0] as Dictionary).get("params", {}) as Dictionary).get("partial", "")) != "partial_retreat":
		m.append("zero partial row: %s" % JSON.stringify(zero))
	var forced: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(
		_scout_ctx(none, 0), 1, "forced_retreat")["data"]["reward_breakdown"]
	if not forced.is_empty():
		m.append("forced_retreat carries rows: %s" % JSON.stringify(forced))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_cause_boss_stub() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var objs: Array = [_obj(0, "combat", true), _obj(1, "shrine", false), boss]
	var counts := RewardCalc.objective_counts(objs, cfg)
	if int(counts["overcome"]) != 1 or int(counts["total"]) != 2:
		m.append("with the boss excluded: %s" % str(counts))
	var no_exclusion := cfg.duplicate(true)
	no_exclusion["objective_count_excluded_types"] = []
	counts = RewardCalc.objective_counts(objs, no_exclusion)
	if int(counts["total"]) != 3:
		m.append("with the list emptied the boss must count: %s" % str(counts))
	if RewardCalc.base_reward(objs, cfg) != 20:
		m.append("the exclusion list changed a payout")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_cause_pending_copy() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_cause_copy")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var row := { "label": "Echoes home", "delta": 2, "currency": "ase", "cause": "echoes_alive", "params": { "x": 1 } }
	var card := { "type": FlowStateIds.RESOLVE, "meta": { "t": 1 }, "actions": {}, "data": {
		"encounter_id": "enc", "victory": true, "objectives_remaining": 0,
		"ase_awarded": 2, "reward_breakdown": [row] } }
	if PendingResultService.capture_or_consume(runtime.flow_ctx, card, 1) != "captured":
		return { "ok": false, "error": "the card was not captured" }
	var stored: Dictionary = PendingResultService.read(runtime.get_save_data())
	var copied: Array = (stored["economy"] as Dictionary)["reward_breakdown"]
	var replayed: Array = PendingResultService.build_snapshot(runtime.flow_ctx, 2)["data"]["reward_breakdown"]
	var m: Array = []
	for pair in [["durable copy", copied], ["replay", replayed]]:
		var rows: Array = pair[1]
		if rows.size() != 1 or str((rows[0] as Dictionary).get("cause", "")) != "echoes_alive" \
				or int(((rows[0] as Dictionary).get("params", {}) as Dictionary).get("x", 0)) != 1:
			m.append("%s lost cause or params: %s" % [pair[0], JSON.stringify(rows)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_cause_old_row_replays() -> Dictionary:
	var old_row := { "label": "Echoes home", "delta": 2, "currency": "ase" }
	var ctx := FlowContext.new()
	ctx.save_data = { "flow": { "pending_result": { "resolve_data": {
		"encounter_id": "enc", "victory": true, "ase_awarded": 2, "reward_breakdown": [old_row] },
		"next_action": {} } } }
	var snap := PendingResultService.build_snapshot(ctx, 3)
	var rows: Array = (snap.get("data", {}) as Dictionary).get("reward_breakdown", [])
	var m: Array = []
	if rows.size() != 1 or JSON.stringify(rows[0]) != JSON.stringify(old_row):
		m.append("old row changed or lost on replay: %s" % JSON.stringify(rows))
	if bool((snap["data"] as Dictionary).get("ledger_seen", true)):
		m.append("an old save must replay ledger_seen as false")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_ledger_seen() -> Dictionary:
	var m: Array = []
	if SaveSchema.ledger_seen({}) or SaveSchema.ledger_seen({ "ui_flags": "bad" }):
		m.append("a save without ui_flags must read false")
	if SaveSchema.ledger_seen(SaveSchema.make_new_save(1)):
		m.append("a new save must start false")
	var old_save := SaveSchema.make_new_save(1)
	old_save.erase("ui_flags")
	SaveService._apply_additive_defaults_and_repairs(old_save)
	if not old_save.has("ui_flags") or SaveSchema.ledger_seen(old_save):
		m.append("the repair must add ui_flags.result_ledger_seen = false")
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_ledger_seen")
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var save: Dictionary = runtime.get_save_data()
	save.erase("ui_flags")
	if SaveSchema.ledger_seen(save):
		m.append("an old save must read false")
	runtime.dispatch({ "type": "resolve.ledger.mark_seen" })
	if not SaveSchema.ledger_seen(runtime.get_save_data()):
		m.append("the action did not set the flag")
	runtime.dispatch({ "type": "resolve.ledger.mark_seen" })
	if not SaveSchema.ledger_seen(runtime.get_save_data()):
		m.append("a second dispatch cleared the flag")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Phase 5.1: the rank score (D-49). 0.40 win + 0.40 x home share + 0.20 x pace fraction.
# Pace fraction with par 20, full 1.1, zero 1.6: round 22 = 1.0, round 27 = 0.5, round 32 = 0.
# ---------------------------------------------------------------------------

const _PAR := 20.0
const _SLOW := 32
const _PARTIAL := 27
const _FULL := 22
const _GRADE_STEPS := ["F", "D", "C", "B", "A", "S"]

static func _win_rank(alive: int, started: int, round_ended: int, mode: String = EncounterResolutionModes.COMBAT,
		run_count: int = 0) -> String:
	var par := _PAR if mode == EncounterResolutionModes.COMBAT else 0.0
	return str(RewardCalc.compute(true, [_obj(0, "combat", true)], alive, started, round_ended, run_count,
		_rewards_cfg(), mode, par).get("rank", ""))


static func _t_rank_table() -> Dictionary:
	# started, alive -> [slow, partial, full]  (phase5-risk-and-rank.md section 4.2)
	var table := [
		[1, 1, ["A", "S", "S"]], [2, 2, ["A", "S", "S"]], [2, 1, ["B", "B", "A"]],
		[3, 3, ["A", "S", "S"]], [3, 2, ["B", "A", "A"]], [3, 1, ["C", "B", "B"]],
	]
	var m: Array = []
	for row in table:
		var got := [_win_rank(row[1], row[0], _SLOW), _win_rank(row[1], row[0], _PARTIAL), _win_rank(row[1], row[0], _FULL)]
		if got != row[2]:
			m.append("%d started %d home: %s, expected %s" % [row[0], row[1], str(got), str(row[2])])
	# A defeat is F whatever the pace and the survivors.
	var lost := RewardCalc.compute(false, [_obj(0, "combat", false)], 1, 3, _FULL, 0, _rewards_cfg(),
		EncounterResolutionModes.COMBAT, _PAR, "", null, 0, 0)
	if str(lost["rank"]) != "F":
		m.append("a defeat ranked %s, expected F" % str(lost["rank"]))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-69: any death caps a win at A. The score alone gives S at 4 and 5 started (one lost, full pace
## = 0.90), so those rows prove the cap. At 1 to 3 started the score is already below A or at A.
## Grades for [slow, partial, full], one dead, 1 to 5 started; and all home for the same sizes.
static func _t_death_cap() -> Dictionary:
	var m: Array = []
	var dead_table := {
		1: ["C", "C", "B"], 2: ["B", "B", "A"], 3: ["B", "A", "A"], 4: ["B", "A", "A"], 5: ["B", "A", "A"],
	}
	var home_table := {
		1: ["A", "S", "S"], 2: ["A", "S", "S"], 3: ["A", "S", "S"], 4: ["A", "S", "S"], 5: ["A", "S", "S"],
	}
	for started in [1, 2, 3, 4, 5]:
		var paces := [_SLOW, _PARTIAL, _FULL]
		for i in 3:
			var dead := _win_rank(started - 1, started, paces[i])
			var home := _win_rank(started, started, paces[i])
			if dead != dead_table[started][i]:
				m.append("%d started 1 dead pace %d: %s, expected %s" % [started, i, dead, dead_table[started][i]])
			if home != home_table[started][i]:
				m.append("%d started all home pace %d: %s, expected %s" % [started, i, home, home_table[started][i]])
			if _GRADE_STEPS.find(dead) > _GRADE_STEPS.find("A"):
				m.append("%d started 1 dead pace %d: %s is above A" % [started, i, dead])
	# More than one death is capped too.
	if _GRADE_STEPS.find(_win_rank(3, 5, _FULL)) > _GRADE_STEPS.find("A"):
		m.append("5 started 2 dead full pace is above A")
	# A death with full pace never outranks all home with no pace.
	for started in [1, 2, 3, 4, 5]:
		if _GRADE_STEPS.find(_win_rank(started - 1, started, _FULL)) > _GRADE_STEPS.find(_win_rank(started, started, _SLOW)):
			m.append("%d started: dead + full pace outranks all home + slow" % started)
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-74, D-75: the replay factor does not touch the rank, and S is allowed on any run.
static func _t_rank_ignores_replay() -> Dictionary:
	var m: Array = []
	for started in [1, 2, 3, 4, 5]:
		for alive in range(0, started + 1):
			for r in [_SLOW, _PARTIAL, _FULL]:
				var base := _win_rank(alive, started, r, EncounterResolutionModes.COMBAT, 0)
				for runs in [1, 3, 9]:
					var got := _win_rank(alive, started, r, EncounterResolutionModes.COMBAT, runs)
					if got != base:
						m.append("%d/%d round %d run %d: %s, run 0 gave %s" % [alive, started, r, runs, got, base])
	for runs in [1, 3]:
		if _win_rank(3, 3, _FULL, EncounterResolutionModes.COMBAT, runs) != "S":
			m.append("all home full pace run_count %d is not S" % runs)
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## A death lowers the grade at every pace (1 to 3 Echoes started).
static func _t_death_lowers_rank() -> Dictionary:
	var m: Array = []
	for started in [2, 3]:
		for r in [_SLOW, _PARTIAL, _FULL]:
			var home := _GRADE_STEPS.find(_win_rank(started, started, r))
			var one_dead := _GRADE_STEPS.find(_win_rank(started - 1, started, r))
			if one_dead >= home:
				m.append("%d started, round %d: all home %s, one dead %s" % [started, r,
					_GRADE_STEPS[home], _GRADE_STEPS[one_dead]])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Relation: with 1 to 3 Echoes started, a FULL-pace win that lost an Echo never ranks above a
## SLOW win that kept everyone home. Speed also never lowers a grade.
## This does not hold from 4 Echoes started (one lost, full pace = 0.90 = S); see phase5-1-build.md.
static func _t_speed_vs_survival() -> Dictionary:
	var m: Array = []
	for started in [1, 2, 3]:
		var slow_home := _GRADE_STEPS.find(_win_rank(started, started, _SLOW))
		for alive in range(0, started):
			if _GRADE_STEPS.find(_win_rank(alive, started, _FULL)) > slow_home:
				m.append("%d started %d home: a full-pace win outranks a slow all-home win" % [started, alive])
		for alive in range(0, started + 1):
			if _GRADE_STEPS.find(_win_rank(alive, started, _FULL)) < _GRADE_STEPS.find(_win_rank(alive, started, _SLOW)):
				m.append("%d started %d home: speed lowered the grade" % [started, alive])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## A no-pace mode takes the full pace points, so all home is S there, as a fast all-home win is.
static func _t_no_pace_not_capped() -> Dictionary:
	var m: Array = []
	for mode in [EncounterResolutionModes.PROTECT, EncounterResolutionModes.ENDURE]:
		for started in [1, 2, 3]:
			if _win_rank(started, started, 12, mode) != "S":
				m.append("%s %d started all home ranked %s, expected S" % [mode, started, _win_rank(started, started, 12, mode)])
		if _win_rank(1, 2, 12, mode) != "A":
			m.append("%s 2 started 1 home ranked %s, expected A" % [mode, _win_rank(1, 2, 12, mode)])
	var rd := RewardCalc.compute(true, [_obj(0, "combat", true)], 2, 2, 12, 0, _rewards_cfg(),
		EncounterResolutionModes.ENDURE, 0.0)
	if bool(rd["pace_mode"]) or str(rd["pace_state"]) != "" or bool(rd["pace_changed_rank"]):
		m.append("a no-pace mode carries pace state: %s" % str(rd))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Part A pays no Ase for speed: a full-pace win and a slow win pay the same, on the fight and on the stage.
static func _t_speed_pays_no_ase() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	var paid: Array = []
	for r in [_FULL, _PARTIAL, _SLOW]:
		var rd := RewardCalc.compute(true, [_obj(0, "combat", true)], 2, 2, r, 0, cfg,
			EncounterResolutionModes.COMBAT, _PAR, "", null, 0, 0)
		var econ := EconomyService.new({ "economy": { "ase": 0, "ekwan": 0 } })
		var res := econ.reward_encounter_complete(true, int(rd["consolation_base"]),
			float(rd["realm_scale"]), float(rd["replay_factor"]), str(rd["rank"]), true, _logger(), 1, 0.25)
		paid.append(int(res["ase_awarded"]))
		if not (res["breakdown"] as Array).is_empty():
			m.append("round %d: expected no rows, got %s" % [r, JSON.stringify(res["breakdown"])])
	if paid != [0, 0, 0]:
		m.append("full / partial / slow paid %s, expected 0 each" % str(paid))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The preview is read-only and shows what the next settle pays, row for row (D-24).
static func _t_stage_preview() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_stage_preview")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var n := 0
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	# Case 0: combat done, shrine open (base 20, Ekwan 2). Case 1: recover + protect done (Ekwan 8).
	var cases: Array = [
		[_obj(0, "combat", true), _obj(1, "shrine", false), boss],
		[_obj(0, "recover", true), _obj(1, "protect", true), boss],
	]
	for stage_index in [0, 2]:
		for run_count in [0, 1, 3]:
			n += 1
			var case_index := n % 2
			var objs: Array = (cases[case_index] as Array).duplicate(true)
			var pv: Dictionary = {}
			var paid := _settle_cell(env, objs, stage_index, run_count, 10 + n, pv)
			var tag := "stage %d run %d case %d" % [stage_index, run_count, case_index]
			if not bool(pv["pure"]):
				m.append("%s: preview changed save_data" % tag)
			if JSON.stringify(pv["first"]) != JSON.stringify(pv["second"]):
				m.append("%s: two previews differ" % tag)
			var ase_rows: Array = []
			for row_v in paid["breakdown"]:
				if str((row_v as Dictionary).get("currency", "")) == "ase":
					ase_rows.append(row_v)
			var first: Dictionary = pv["first"]
			if JSON.stringify(first.get("rows", [])) != JSON.stringify(ase_rows):
				m.append("%s: preview rows %s, paid rows %s" % [tag, JSON.stringify(first.get("rows")), JSON.stringify(ase_rows)])
			if int(first.get("ase", -1)) != int(paid["ase_awarded"]) or int(paid["balance_ase"]) != int(paid["ase_awarded"]):
				m.append("%s: preview ase %s, paid %s" % [tag, str(first.get("ase")), str(paid["ase_awarded"])])
			# D-31: the preview Ekwan is what the payer banks.
			if int(first.get("ekwan", -1)) != int(paid["ekwan_awarded"]) or int(paid["balance_ekwan"]) != int(paid["ekwan_awarded"]):
				m.append("%s: preview ekwan %s, paid %s, balance %s" \
					% [tag, str(first.get("ekwan")), str(paid["ekwan_awarded"]), str(paid["balance_ekwan"])])
			# Completed-only base: case 0 pays combat (20) and not the open shrine; case 1 pays 24 + 24.
			var want_base := 20 if case_index == 0 else 48
			var base_row := _row_by_cause(first.get("rows", []), "objectives_overcome")
			if int(base_row.get("delta", -1)) != want_base:
				m.append("%s: preview base row %s, expected %d" % [tag, JSON.stringify(base_row), want_base])
			# A settled stage previews nothing.
			if not StageSettlementService.new(env["runtime"].flow_ctx, env["runtime"].config_service, null, null).preview().is_empty():
				m.append("%s: a settled stage still previews" % tag)
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Builds the final Resolve card in the production order: win (or lose) the fight, run the
## pre-snapshot resolve call so the fought objective is completed (FlowRuntime ~1704), then
## FlowEncounterState.build_final_snapshot. The fight itself is not played: the combat result is
## set directly, which is all build_final_snapshot reads. Stage 0 holds `objectives`; objective 0
## is the fought one, linked to situation "sit.econ".
static func _final_card(tag: String, objectives: Array, victory: bool, kill_first_echo: bool = false,
		revealed_during_fight: int = 0) -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter("combat", tag)
	if env.is_empty():
		return {}
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	stage["objectives"] = objectives
	stage["settlement_receipt"] = {}
	stage["explore_map"] = {
		"last_situation_id": "sit.econ",
		"situations": [{ "id": "sit.econ", "resolved": false, "revealed": true,
			"is_objective": true, "objective_index": 0 },
			{ "id": "sit.h1", "resolved": false, "revealed": false },
			{ "id": "sit.h2", "resolved": false, "revealed": false }],
	}
	# The fixture replaced the map after production setup, so record the start count again as setup does.
	flow_ctx.encounter_start_revealed_count = ActiveStageService.count_revealed_situations(flow_ctx)
	# Production code reveals nothing during a fight today; this stands in for a future reveal.
	for i in range(revealed_during_fight):
		stage["explore_map"]["situations"][1 + i]["revealed"] = true
	ectx.combat_result = { "victory": victory, "reason": "all_enemies_defeated", "round_ended": 4 }
	ectx.combat_state["combat_over"] = true
	if kill_first_echo:
		for a_v in ectx.actors:
			if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "echo":
				(a_v as Dictionary)["is_dead"] = true
				env["dead_name"] = str((a_v as Dictionary).get("name", ""))
				break
	if victory:
		env["runtime"]._stage_explore_session_service().resolve_combat_situation_and_objective(
			5, true, true, "stage.combat_resolved", "econ_char pre-snapshot", true)
	env["card"] = FlowEncounterState.build_final_snapshot(flow_ctx, 6)
	return env


static func _req(index: int, type: String, completed: bool) -> Dictionary:
	var o := ObjectiveModel.make(index, type, 1, {}, completed)
	o["required"] = true
	return o


static func _t_stage_payout_card() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)

	# (a) Stage-ending victory: shrine done earlier, combat (fought) won now, boss stub.
	var env := _final_card("econ_char_card_a", [_req(0, "combat", false), _req(1, "shrine", true), boss], true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var data: Dictionary = env["card"]["data"]
	if int(data.get("objectives_remaining", -1)) != 0:
		m.append("(a) fixture: objectives_remaining %s, expected 0" % str(data.get("objectives_remaining")))
	if not data.has("stage_payout_rows") or not data.has("stage_payout_ase") or not data.has("stage_payout_ekwan"):
		m.append("(a) victory card lacks stage_payout keys: %s" % str(data.keys()))
	else:
		var base := _row_by_cause(data["stage_payout_rows"], "objectives_overcome")
		var p: Dictionary = base.get("params", {})
		if int(p.get("overcome", -1)) != 2 or int(p.get("total", -1)) != 2 or int(base.get("delta", -1)) != 50:
			m.append("(a) objectives_overcome row %s, expected 2 of 2 and delta 50" % JSON.stringify(base))
		var runtime: FlowRuntime = env["runtime"]
		var before := int(runtime.get_save_data()["economy"]["ase"])
		var ekwan_before := int(runtime.get_save_data()["economy"]["ekwan"])
		runtime.dispatch({ "type": "flow.complete_stage" })
		var paid := int(runtime.get_save_data()["economy"]["ase"]) - before
		var paid_ekwan := int(runtime.get_save_data()["economy"]["ekwan"]) - ekwan_before
		if paid != int(data["stage_payout_ase"]):
			m.append("(a) flow.complete_stage paid %d, card previewed %d" % [paid, int(data["stage_payout_ase"])])
		# combat 2 + shrine 6, both completed by now, run_count 0.
		if paid_ekwan != int(data["stage_payout_ekwan"]) or paid_ekwan != 8:
			m.append("(a) flow.complete_stage paid ekwan %d, card previewed %s, expected 8" \
				% [paid_ekwan, str(data["stage_payout_ekwan"])])
		# D-43, D-44: the harness party is 5 Echoes, all home: the stage row pays 10, the fight pays 0.
		var home := _row_by_cause(data["stage_payout_rows"], "echoes_alive")
		var hp: Dictionary = home.get("params", {})
		if int(home.get("delta", -1)) != 10 or int(hp.get("alive", -1)) != 5 or int(hp.get("started", -1)) != 5 \
				or not (hp.get("lost", [1]) as Array).is_empty() or int(hp.get("cap", -1)) != 10 or bool(hp.get("replay", true)):
			m.append("(a) echoes_alive stage row %s, expected 10 Ase, 5 of 5, no lost, cap 10, no replay" % JSON.stringify(home))
		if int(data["stage_payout_ase"]) != 50 + 10:
			m.append("(a) stage_payout_ase %s, expected 60" % str(data["stage_payout_ase"]))
		if int(data.get("ase_awarded", -1)) != 0 or not _row_by_cause(data.get("reward_breakdown", []), "echoes_alive").is_empty():
			m.append("(a) won fight card ase_awarded %s rows %s, expected 0 and no echoes_alive row" \
				% [str(data.get("ase_awarded")), JSON.stringify(data.get("reward_breakdown"))])
		if int(data.get("echoes_survived", -1)) != 5:
			m.append("(a) echoes_survived %s, expected 5 (the chip still reads it)" % str(data.get("echoes_survived")))
		# D-28: the fight itself paid no Ekwan, so the card's own figure is 0.
		if int(data.get("ekwan_awarded", -1)) != 0:
			m.append("(a) fight card ekwan_awarded %s, expected 0" % str(data.get("ekwan_awarded")))

	# (b) Mid-stage victory: a second required objective is still open.
	env = _final_card("econ_char_card_b", [_req(0, "combat", false), _req(1, "shrine", false), boss], true)
	data = env["card"]["data"]
	if int(data.get("objectives_remaining", -1)) != 1:
		m.append("(b) fixture: objectives_remaining %s, expected 1" % str(data.get("objectives_remaining")))
	if data.has("stage_payout_rows") or data.has("stage_payout_ase") or data.has("stage_payout_ekwan"):
		m.append("(b) mid-stage victory card carries stage_payout keys")

	# (c) Defeat, with every required objective already done, so only `victory` can keep the keys off.
	env = _final_card("econ_char_card_c", [_req(0, "combat", true), _req(1, "shrine", true), boss], false)
	data = env["card"]["data"]
	if int(data.get("objectives_remaining", -1)) != 0 or bool(data.get("victory", true)):
		m.append("(c) fixture: remaining %s victory %s" % [str(data.get("objectives_remaining")), str(data.get("victory"))])
	if data.has("stage_payout_rows") or data.has("stage_payout_ase") or data.has("stage_payout_ekwan"):
		m.append("(c) defeat card carries stage_payout keys")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Echoes stipend (Phase 5.2: D-43 to D-46, D-53, D-81)
# ---------------------------------------------------------------------------

static func _echo_actor(id: String, dead: bool, extra: Dictionary = {}) -> Dictionary:
	var a := { "id": id, "name": "Name " + id, "faction": "echo", "is_dead": dead }
	a.merge(extra, true)
	return a


## The stage preview of a stage with one completed combat objective, on a bare context: no
## booted runtime. `actors` null means no encounter context (nobody fought); `party` then sizes
## the active party in the save.
static func _stipend_preview(actors: Variant, party: int, run_count: int) -> Dictionary:
	var objs: Array = [_obj(0, "combat", true)]
	var ctx := _stage_ctx(_config(), objs)
	var realm: Dictionary = (ctx.save_data["realms"] as Dictionary)["realm.01"]
	realm["run_count"] = run_count
	var roster: Array = []
	var ids: Array = []
	for i in party:
		roster.append({ "id": "e%d" % i, "name": "Name e%d" % i })
		ids.append("e%d" % i)
	ctx.save_data["sanctum"] = { "roster": roster, "active_party_ids": ids }
	if actors != null:
		ctx.encounter_ctx = EncounterContext.new()
		ctx.encounter_ctx.actors = actors
	return StageSettlementService.new(ctx, ctx.config_service, null, null).preview()


static func _stipend_row(preview: Dictionary) -> Dictionary:
	return _row_by_cause(preview.get("rows", []), "echoes_alive")


## D-43: 1 to 5 Echoes home pay 2, 4, 6, 8, 10. More than 5 stay at the cap of 10.
static func _t_stipend_counts() -> Dictionary:
	var m: Array = []
	var want := { 1: 2, 2: 4, 3: 6, 4: 8, 5: 10, 6: 10, 7: 10 }
	for n in want:
		var actors: Array = []
		for i in n:
			actors.append(_echo_actor("e%d" % i, false))
		var pv := _stipend_preview(actors, 0, 0)
		var row := _stipend_row(pv)
		var p: Dictionary = row.get("params", {})
		if int(row.get("delta", -1)) != want[n] or int(p.get("alive", -1)) != n or int(p.get("started", -1)) != n \
				or int(p.get("cap", -1)) != 10 or bool(p.get("replay", true)):
			m.append("%d home: row %s, expected delta %d" % [n, JSON.stringify(row), want[n]])
		if int(pv.get("ase", -1)) != 20 + int(want[n]):
			m.append("%d home: stage ase %s, expected %d" % [n, str(pv.get("ase")), 20 + int(want[n])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-53: on a replay the rate stays 2 and the cap falls to 5. The stipend ignores the replay factor.
static func _t_stipend_replay() -> Dictionary:
	var m: Array = []
	var want := { 1: 2, 2: 4, 3: 5, 5: 5 }
	for n in want:
		var actors: Array = []
		for i in n:
			actors.append(_echo_actor("e%d" % i, false))
		var pv := _stipend_preview(actors, 0, 1)
		var row := _stipend_row(pv)
		var p: Dictionary = row.get("params", {})
		if int(row.get("delta", -1)) != want[n] or int(p.get("cap", -1)) != 5 or not bool(p.get("replay", false)):
			m.append("%d home on a replay: row %s, expected delta %d, cap 5" % [n, JSON.stringify(row), want[n]])
		# base 20 x 0.35 = 7, plus the stipend untouched by the factor.
		if int(pv.get("ase", -1)) != 7 + int(want[n]):
			m.append("%d home on a replay: stage ase %s, expected %d" % [n, str(pv.get("ase")), 7 + int(want[n])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## One dead Echo: alive, started and the lost NAME. Allies and the spirit never count. The
## no-encounter path counts the whole active party as home (ASSUMED in phase5-2-build.md).
static func _t_stipend_dead_and_none() -> Dictionary:
	var m: Array = []
	var actors: Array = [
		_echo_actor("a", false), _echo_actor("b", true), _echo_actor("c", false),
		_echo_actor("ally", false, { "is_ally": true }), _echo_actor("sp", true, { "is_spirit": true }),
		{ "id": "en", "name": "Enemy", "faction": "enemy", "is_dead": true },
	]
	var row := _stipend_row(_stipend_preview(actors, 0, 0))
	var p: Dictionary = row.get("params", {})
	if int(row.get("delta", -1)) != 4 or int(p.get("alive", -1)) != 2 or int(p.get("started", -1)) != 3 \
			or str(p.get("lost", [])) != str(["Name b"]):
		m.append("one dead of three: row %s, expected 4 Ase, 2 of 3, lost [Name b]" % JSON.stringify(row))
	for key in (p.keys() if p is Dictionary else []):
		if str(key).contains("id"):
			m.append("params carry an id-like key: %s" % str(key))
	var all_dead := _stipend_row(_stipend_preview([_echo_actor("a", true)], 0, 0))
	if all_dead.is_empty() or int(all_dead.get("delta", -1)) != 0 \
			or str((all_dead.get("params", {}) as Dictionary).get("lost", [])) != str(["Name a"]):
		m.append("all dead: row %s, expected a delta-0 row naming the lost Echo" % JSON.stringify(all_dead))
	var none := _stipend_row(_stipend_preview(null, 3, 0))
	var np: Dictionary = none.get("params", {})
	if int(none.get("delta", -1)) != 6 or int(np.get("alive", -1)) != 3 or int(np.get("started", -1)) != 3 \
			or not (np.get("lost", [1]) as Array).is_empty():
		m.append("no-encounter, party of 3: row %s, expected 6 Ase, 3 of 3" % JSON.stringify(none))
	if not _stipend_row(_stipend_preview(null, 0, 0)).is_empty():
		m.append("an empty party still gets a stipend row")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The real stage-ending victory card with one Echo dead: the row names it, the preview equals
## what flow.complete_stage pays, and the fight itself pays nothing.
static func _t_stipend_real_card() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var env := _final_card("econ_char_card_dead", [_req(0, "combat", false), _req(1, "shrine", true), boss], true, true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var data: Dictionary = env["card"]["data"]
	var row := _row_by_cause(data.get("stage_payout_rows", []), "echoes_alive")
	var p: Dictionary = row.get("params", {})
	if int(row.get("delta", -1)) != 8 or int(p.get("alive", -1)) != 4 or int(p.get("started", -1)) != 5 \
			or str(p.get("lost", [])) != str([str(env.get("dead_name", "?"))]):
		m.append("one dead of five: row %s, expected 8 Ase, 4 of 5, lost [%s]" % [JSON.stringify(row), str(env.get("dead_name"))])
	if int(data.get("echoes_survived", -1)) != 4:
		m.append("echoes_survived %s, expected 4" % str(data.get("echoes_survived")))
	if int(data.get("ase_awarded", -1)) != 0:
		m.append("the won fight paid %s Ase at fight level, expected 0" % str(data.get("ase_awarded")))
	var runtime: FlowRuntime = env["runtime"]
	var before := int(runtime.get_save_data()["economy"]["ase"])
	runtime.dispatch({ "type": "flow.complete_stage" })
	var paid := int(runtime.get_save_data()["economy"]["ase"]) - before
	if paid != int(data.get("stage_payout_ase", -2)) or paid != 50 + 8:
		m.append("flow.complete_stage paid %d, card previewed %s, expected 58" % [paid, str(data.get("stage_payout_ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# D-104 to D-106: a return home settles by one roll (step 6.1)
# ---------------------------------------------------------------------------

## A pure context: one stage, objectives as given, one revealed situation, five party Echoes (so the
## stage-end stipend is the 10 Ase cap), the realm's run_count and seed.
static func _carry_ctx(realm_id: String, run_count: int, objs: Array, realm_seed: int = 0) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = _config()
	ctx.realm_id = realm_id
	ctx.stage_id = "stage.0"
	var stage := { "index": 0, "objectives": objs, "settlement_receipt": {},
		"explore_map": { "situations": [{ "id": "s0", "revealed": true }] } }
	var roster: Array = []
	var ids: Array = []
	for i in 5:
		roster.append({ "id": "e%d" % i, "name": "Echo %d" % i })
		ids.append("e%d" % i)
	ctx.save_data = { "economy": { "ase": 0, "ekwan": 0 },
		"sanctum": { "roster": roster, "active_party_ids": ids },
		"realms": { realm_id: { "run_count": run_count, "seed": realm_seed, "stages": [stage] } } }
	return ctx


static func _carry_econ(ctx: FlowContext) -> EconomyService:
	return EconomyService.new(ctx.save_data)


static func _carry_stage(ctx: FlowContext) -> Dictionary:
	return ((ctx.save_data["realms"] as Dictionary)[ctx.realm_id] as Dictionary)["stages"][0]


static func _carry_boss() -> Dictionary:
	return ObjectiveModel.make(9, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)


static func _leave(ctx: FlowContext, mul: float = 1.0, t: int = 1) -> Dictionary:
	return StageSettlementService.settle_leave(ctx, ctx.config_service, _carry_econ(ctx), mul, "test", _logger(), t)


## The outcome the stream `stage.settle.<stage_id>.<run>.<count>` gives for a seed. Written out
## here on purpose: it pins the stream name and the 0..99 draw against the table.
static func _expected_outcome(realm_seed: int, run_count: int, settle_count: int, mul: float = 1.0) -> String:
	var roll := CampaignSeed.get_rng_from(realm_seed,
		"stage.settle.stage.0.%d.%d" % [run_count, settle_count]).randi_range(0, 99)
	var cum := 0.0
	for row in StageSettlementService.carry_table(_rewards_cfg(), mul):
		cum += float(row["pct"])
		if float(roll) < cum:
			return str(row["outcome"])
	return "all"


## The first seed from 0 whose first roll gives `outcome`.
static func _seed_for(outcome: String, mul: float = 1.0, run_count: int = 0, settle_count: int = 0) -> int:
	for s in range(0, 5000):
		if _expected_outcome(s, run_count, settle_count, mul) == outcome:
			return s
	return -1


## Gathered amount: no 12% factor, no subtraction (the old `carry_plan`). Shrine 30/6 + recover 24/5 +
## protect 24/3 = Ase 78, Ekwan 14, one rounding on each sum, with the realm scale and replay factor.
## [realm, run_count, Ase, Ekwan]: 78; 97.5 -> 98; 27.3 -> 27; 34.125 -> 34. Ekwan 14; 17.5 -> 18; 4.9 -> 5; 6.125 -> 6.
static func _t_settle_plan_gathered() -> Dictionary:
	var m: Array = []
	for c in [["realm.01", 0, 78, 14], ["realm.02", 0, 98, 18], ["realm.01", 1, 27, 5], ["realm.02", 1, 34, 6]]:
		var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", true), _obj(2, "protect", true), _carry_boss()]
		var ctx := _carry_ctx(c[0], c[1], objs)
		var before := JSON.stringify(ctx.save_data)
		var plan := StageSettlementService.settle_plan(ctx, ctx.config_service)
		if int(plan["ase"]) != int(c[2]) or int(plan["ekwan"]) != int(c[3]):
			m.append("%s run %d: gathered %s/%s, expected %d/%d" % [c[0], c[1], plan["ase"], plan["ekwan"], c[2], c[3]])
		if int(plan["overcome"]) != 3 or int(plan["total"]) != 3 or bool(plan["nothing_new"]) or (plan["indexes"] as Array).size() != 3:
			m.append("%s run %d: plan %s, expected 3 of 3 (boss stub excluded), 3 indexes" % [c[0], c[1], str(plan)])
		if JSON.stringify(ctx.save_data) != before:
			m.append("%s run %d: settle_plan changed the save" % [c[0], c[1]])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The odds come from `data.rewards.carry_odds` and `carry_shares`. 50/30/20 is the shipped table.
## Scout multiplies the weights of the outcomes that pay something by 1.5 and renormalises:
## 50 / 45 / 30 -> 40 / 36 / 24. A table with other numbers changes the result: nothing is hard-coded.
static func _t_settle_odds_from_config() -> Dictionary:
	var m: Array = []
	var cfg := _rewards_cfg()
	var plain := StageSettlementService.carry_table(cfg, 1.0)
	var scout := StageSettlementService.carry_table(cfg, 1.5)
	var want_plain := [50.0, 30.0, 20.0]
	var want_scout := [40.0, 36.0, 24.0]
	var want_share := [0.0, 0.5, 1.0]
	if plain.size() != 3 or scout.size() != 3:
		return { "ok": false, "error": "carry_table sizes %d / %d, expected 3" % [plain.size(), scout.size()] }
	for i in 3:
		if absf(float(plain[i]["pct"]) - want_plain[i]) > 0.0001 or absf(float(scout[i]["pct"]) - want_scout[i]) > 0.0001:
			m.append("row %d: plain %s scout %s, expected %s / %s" % [i, plain[i]["pct"], scout[i]["pct"], want_plain[i], want_scout[i]])
		if absf(float(plain[i]["share"]) - want_share[i]) > 0.0001 or float(scout[i]["share"]) > 1.0:
			m.append("row %d: share %s, expected %s and never above 1" % [i, plain[i]["share"], want_share[i]])
	var other := cfg.duplicate(true)
	other["carry_odds"] = { "none": 0, "some": 0, "all": 10 }
	other["carry_shares"] = { "none": 0.0, "some": 0.5, "all": 1.0 }
	var t_all := StageSettlementService.carry_table(other, 1.5)
	if absf(float(t_all[2]["pct"]) - 100.0) > 0.0001:
		m.append("odds 0/0/10 gave %s, expected 100 for 'all'" % str(t_all))
	var broken := cfg.duplicate(true)
	broken.erase("carry_odds")
	if not StageSettlementService.carry_table(broken, 1.0, _logger()).is_empty():
		m.append("a missing carry_odds must give an empty table")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Over 600 seeds the shipped table lands near 50 / 30 / 20 (and Scout near 40 / 36 / 24), the same seed always
## gives the same answer, and Scout never turns a paying roll into a loss: a roll that pays for a plain
## party also pays for a Scout party, and Scout loses less often.
static func _t_settle_roll_seeded_distribution() -> Dictionary:
	var m: Array = []
	var plain := { "none": 0, "some": 0, "all": 0 }
	var scout := { "none": 0, "some": 0, "all": 0 }
	var n := 600
	for s in n:
		var a := _expected_outcome(s, 0, 0, 1.0)
		var b := _expected_outcome(s, 0, 0, 1.5)
		if a != _expected_outcome(s, 0, 0, 1.0):
			m.append("seed %d is not repeatable" % s)
			break
		plain[a] += 1
		scout[b] += 1
		if a != "none" and b == "none":
			m.append("seed %d pays plain (%s) but not for Scout" % [s, a])
			break
	for k in ["none", "some", "all"]:
		var wp: float = {"none": 0.5, "some": 0.3, "all": 0.2}[k]
		var ws: float = {"none": 0.4, "some": 0.36, "all": 0.24}[k]
		if absf(float(plain[k]) / n - wp) > 0.07 or absf(float(scout[k]) / n - ws) > 0.07:
			m.append("%s: plain %d scout %d of %d, expected near %s / %s" % [k, plain[k], scout[k], n, wp, ws])
	if int(scout["none"]) >= int(plain["none"]):
		m.append("Scout lost as often as plain: %d vs %d" % [scout["none"], plain["none"]])
	# The real payer lands on the same outcome the stream gives.
	for want in ["none", "some", "all"]:
		var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", true), _obj(2, "protect", true), _carry_boss()]
		var ctx := _carry_ctx("realm.01", 0, objs, _seed_for(want))
		var got := _leave(ctx)
		if str(got["outcome"]) != want:
			m.append("settle_leave gave %s, the stream gives %s" % [got["outcome"], want])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## One roll pays Ase and Ekwan once through the economy, marks every settled objective, writes the
## running totals, and a second leave with nothing new changes nothing.
## Shrine 30/6 + recover 24/5 + protect 24/3 = 78 / 14. All: 78 / 14. Some: 39 / 7. None: 0 / 0.
static func _t_settle_pays_once_and_marks() -> Dictionary:
	var m: Array = []
	for c in [["all", 78, 14, 100], ["some", 39, 7, 50], ["none", 0, 0, 0]]:
		var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", true), _obj(2, "protect", true), _carry_boss()]
		var ctx := _carry_ctx("realm.01", 0, objs, _seed_for(c[0]))
		var got := _leave(ctx)
		var st := _carry_stage(ctx)
		var bal := ctx.save_data["economy"] as Dictionary
		if str(got["outcome"]) != c[0] or int(got["ase"]) != int(c[1]) or int(got["ekwan"]) != int(c[2]):
			m.append("%s: outcome %s paid %s/%s, expected %d/%d" % [c[0], got["outcome"], got["ase"], got["ekwan"], c[1], c[2]])
		if int(bal["ase"]) != int(c[1]) or int(bal["ekwan"]) != int(c[2]):
			m.append("%s: balance %s, expected paid once %d/%d" % [c[0], str(bal), c[1], c[2]])
		for i in 3:
			var o: Dictionary = st["objectives"][i]
			if not bool(o.get("settled", false)) or int(o.get("settled_share", -1)) != int(c[3]):
				m.append("%s: objective %d %s, expected settled with share %d" % [c[0], i, str(o), c[3]])
		if bool((st["objectives"][3] as Dictionary).get("settled", false)):
			m.append("%s: the boss stub was marked settled" % c[0])
		if int(st.get("settled_ase", -1)) != int(c[1]) or int(st.get("settled_ekwan", -1)) != int(c[2]) or int(st.get("settle_count", -1)) != 1:
			m.append("%s: stage totals %s, expected %d/%d and count 1" % [c[0], str(st), c[1], c[2]])
		if st.has("carried_ase") or st.has("carried_ekwan"):
			m.append("%s: the removed carried_* fields were written" % c[0])
		var again := _leave(ctx, 1.0, 2)
		if str(again["outcome"]) != "nothing_new" or int(again["ase"]) != 0 or int(bal["ase"]) != int(c[1]) \
				or int(st.get("settle_count", -1)) != 1:
			m.append("%s: a second leave gave %s, balance %s, count %s" % [c[0], str(again), str(bal), str(st.get("settle_count"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Nothing new draws nothing and changes nothing: no completed objective, only the boss stub, and an
## objective already settled. The roll stream is rebuilt from the stage state each time, so "no draw"
## shows as "no state change": no mark, no settle_count, no payment.
static func _t_settle_nothing_new_changes_nothing() -> Dictionary:
	var m: Array = []
	for objs in [
			[_obj(0, "shrine", false), _carry_boss()],
			[_carry_boss()],
			[_obj(0, "shrine", true), _carry_boss()]]:
		var ctx := _carry_ctx("realm.01", 0, objs.duplicate(true), _seed_for("all"))
		if (objs[0] as Dictionary).get("type") == "shrine" and bool((objs[0] as Dictionary).get("completed")):
			((_carry_stage(ctx)["objectives"] as Array)[0] as Dictionary)["settled"] = true
		var before := JSON.stringify(ctx.save_data)
		var got := _leave(ctx)
		if str(got["outcome"]) != "nothing_new" or int(got["ase"]) != 0 or int(got["ekwan"]) != 0:
			m.append("%s: %s, expected nothing_new 0/0" % [JSON.stringify(objs), str(got)])
		if JSON.stringify(ctx.save_data) != before:
			m.append("%s: the save changed" % JSON.stringify(objs))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Cancel, reload and retry cannot re-roll. A cancel never reaches the payer (the plan is pure). After a
## reload (the save through JSON, so ints become floats) the marks hold and the leave is nothing_new. A
## retry on the same stage state finds the same marks. Only an objective completed later is rolled, on the
## next stream (count 1).
static func _t_settle_reroll_blocked() -> Dictionary:
	var m: Array = []
	var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", false), _carry_boss()]
	var ctx := _carry_ctx("realm.01", 0, objs, _seed_for("none", 1.0, 0, 0))
	var before_cancel := JSON.stringify(ctx.save_data)
	StageSettlementService.settle_plan(ctx, ctx.config_service)
	StageSettlementService.settle_plan(ctx, ctx.config_service)
	if JSON.stringify(ctx.save_data) != before_cancel:
		m.append("a plan (the cancelled panel) changed the save")
	var first := _leave(ctx)
	if str(first["outcome"]) != "none":
		return { "ok": false, "error": "setup: expected a none roll, got %s" % str(first) }
	var reloaded := _carry_ctx("realm.01", 0, [], 0)
	reloaded.save_data = JSON.parse_string(JSON.stringify(ctx.save_data))
	for attempt in 3:
		var retry := _leave(reloaded, 1.0, 10 + attempt)
		if str(retry["outcome"]) != "nothing_new" or int(retry["ase"]) != 0:
			m.append("retry %d after reload gave %s, expected nothing_new" % [attempt, str(retry)])
	((_carry_stage(reloaded)["objectives"] as Array)[1] as Dictionary)["completed"] = true
	var later := _leave(reloaded, 1.0, 20)
	var st := _carry_stage(reloaded)
	var obj0: Dictionary = st["objectives"][0]
	if str(later["outcome"]) != _expected_outcome(0, 0, 1) or int(st.get("settle_count", -1)) != 2:
		m.append("the later objective gave %s count %s, expected the count-1 stream (%s) and count 2" \
			% [str(later), str(st.get("settle_count")), _expected_outcome(0, 0, 1)])
	if int(obj0.get("settled_share", -1)) != 0 or int(reloaded.save_data["economy"]["ase"]) != int(later["ase"]):
		m.append("the first objective's none result changed: %s balance %s" % [str(obj0), str(reloaded.save_data["economy"])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Scout raises the odds, never the amount: a Scout party that rolls "all" gets 100% of the gathered amount,
## not 150%. Same seed, same stream; Scout turns some seeds from none into a payout.
static func _t_settle_scout_never_over_100() -> Dictionary:
	var m: Array = []
	var s_all := _seed_for("all", 1.5)
	var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", true), _carry_boss()]
	var ctx := _carry_ctx("realm.01", 0, objs, s_all)
	var scout := { "intel_retention": true, "intel_retention_bonus": 1.5 }
	var mul := StageSettlementService.retention_mul(scout)
	if mul != 1.5 or StageSettlementService.retention_mul({ "intel_retention": false, "intel_retention_bonus": 1.5 }) != 1.0 \
			or StageSettlementService.retention_mul({}) != 1.0:
		m.append("retention_mul wrong: %s" % str(mul))
	var got := _leave(ctx, mul)
	if str(got["outcome"]) != "all" or int(got["ase"]) != 54 or int(got["ekwan"]) != 11:
		m.append("Scout 'all' paid %s, expected all 54/11 (never above the gathered 54/11)" % str(got))
	var flip := -1
	for s in range(0, 5000):
		if _expected_outcome(s, 0, 0, 1.0) == "none" and _expected_outcome(s, 0, 0, 1.5) != "none":
			flip = s
			break
	if flip < 0:
		m.append("no seed turns none into a payout for Scout")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Nothing overcome writes nothing; a defeat keeps what the leave paid; the stage-end preview keeps
## the memo row, not a negative row.
static func _t_settle_defeat_keeps_paid() -> Dictionary:
	var m: Array = []
	var objs: Array = [_obj(0, "shrine", true), _obj(1, "recover", false), _carry_boss()]
	var ctx := _carry_ctx("realm.01", 0, objs, _seed_for("all"))
	var econ := _carry_econ(ctx)
	var got := StageSettlementService.settle_leave(ctx, ctx.config_service, econ, 1.0, "test", _logger(), 1)
	var svc := StageSettlementService.new(ctx, ctx.config_service, econ, _logger())
	var lost := svc.settle(false, 2)
	var bal := ctx.save_data["economy"] as Dictionary
	if not lost.is_empty() or int(bal["ase"]) != int(got["ase"]) or int(got["ase"]) != 30 or int(bal["ekwan"]) != 6:
		m.append("defeat: settle returned %s, balance %s, expected {} and the leave's 30/6 kept" % [str(lost), str(bal)])
	if _carry_stage(ctx).has("settlement_receipt") and bool((_carry_stage(ctx)["settlement_receipt"] as Dictionary).get("settled", false)):
		m.append("a defeat stamped the stage receipt")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The stage end pays only the unsettled completed objectives plus the stipend, and shows a memo row.
## A settled objective pays nothing more. Preview (pure) and settle agree on a real runtime.
static func _t_settle_stage_end_pays_unsettled_only() -> Dictionary:
	var m: Array = []
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_settle_stage_end")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(3, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var settled := _obj(0, "combat", true)
	settled["settled"] = true
	settled["settled_share"] = 50
	var objs: Array = [settled, _obj(1, "recover", true), _obj(2, "shrine", true), boss]
	var pv := {}
	# Unsettled recover 24/5 + shrine 30/6 = 54 / 11, plus the one-Echo stipend (2). The combat 20/2 pays nothing.
	var out := _settle_cell(env, objs, 0, 0, 1, pv, "realm.01", 10, 1)
	var base := _row_by_cause(out["breakdown"], "objectives_overcome")
	var memo := _row_by_cause(out["breakdown"], "settled_on_leave")
	var sum := 0
	for r_v in out["breakdown"]:
		sum += int((r_v as Dictionary).get("delta", 0))
	if int(out.get("ase_awarded", -1)) != 54 + _ONE_ECHO_STIPEND or int(out.get("ekwan_awarded", -1)) != 11:
		m.append("paid %s/%s, expected 56/11" % [out.get("ase_awarded"), out.get("ekwan_awarded")])
	if int(base.get("delta", -1)) != 54 or int((base.get("params", {}) as Dictionary).get("overcome", -1)) != 3 \
			or int((base.get("params", {}) as Dictionary).get("total", -1)) != 3:
		m.append("base row %s, expected 54 and 3 of 3 (all completed still count)" % JSON.stringify(base))
	if int(memo.get("delta", -1)) != 0 or int((memo.get("params", {}) as Dictionary).get("settled_ase", -1)) != 10 \
			or int((memo.get("params", {}) as Dictionary).get("settled_ekwan", -1)) != 1:
		m.append("memo row %s, expected delta 0 with settled 10/1" % JSON.stringify(memo))
	if not _row_by_cause(out["breakdown"], "carried_advance").is_empty():
		m.append("the removed carried_advance row is back")
	if sum != int(out.get("ase_awarded", -1)):
		m.append("rows sum to %d, paid %s" % [sum, out.get("ase_awarded")])
	var first: Dictionary = pv.get("first", {})
	if int(first.get("ase", -1)) != 56 or int(first.get("ekwan", -1)) != 11 or not bool(pv.get("pure", false)):
		m.append("preview %s/%s pure=%s, expected 56/11" % [first.get("ase"), first.get("ekwan"), pv.get("pure")])
	var rt: FlowRuntime = env["runtime"]
	var again := StageSettlementService.new(rt.flow_ctx, rt.config_service, EconomyService.new(rt.get_save_data()),
		env["logger"]).settle(true, 6000)
	if not again.is_empty():
		m.append("second settle paid again: %s" % str(again))
	# No settled objective and no settled totals: no memo row.
	var plain := _settle_cell(env, [_obj(0, "combat", true), _obj(1, "shrine", true), boss], 0, 0, 2)
	if int(plain.get("ase_awarded", -1)) != 50 + _ONE_ECHO_STIPEND or int(plain.get("ekwan_awarded", -1)) != 8 \
			or not _row_by_cause(plain["breakdown"], "settled_on_leave").is_empty():
		m.append("no leave: paid %s/%s, expected 52/8 and no memo row" % [plain.get("ase_awarded"), plain.get("ekwan_awarded")])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## The pure row producer: the settled amounts change no total, only add the memo row (delta 0).
static func _t_settle_rows_memo() -> Dictionary:
	var m: Array = []
	var echo := { "alive": 1, "started": 1, "lost": [], "rate": 2, "cap": 10, "replay": false }
	var r := EconomyService.stage_payout_rows(30, 1.0, 1.0, {}, 6, echo, 100, 100)
	var memo := _row_by_cause(r["breakdown"], "settled_on_leave")
	if int(r["ase"]) != 32 or int(r["ekwan"]) != 6 or int(memo.get("delta", -1)) != 0:
		m.append("settled 100/100: %s, expected totals 32 / 6 and a memo row with delta 0" % JSON.stringify(r))
	for row_v in r["breakdown"]:
		if int((row_v as Dictionary).get("delta", 0)) < 0:
			m.append("negative row %s" % JSON.stringify(row_v))
	var z := EconomyService.stage_payout_rows(30, 1.0, 1.0, {}, 6, echo, 0, 0)
	if not _row_by_cause(z["breakdown"], "settled_on_leave").is_empty() or int(z["ase"]) != 32:
		m.append("zero settled: %s, expected no memo row" % JSON.stringify(z))
	var ekwan_only := EconomyService.stage_payout_rows(30, 1.0, 1.0, {}, 6, echo, 0, 3)
	if _row_by_cause(ekwan_only["breakdown"], "settled_on_leave").is_empty():
		m.append("Ekwan-only settle must still show the memo row")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Design worked example: objectives combat 20, recover 24, shrine 30 (G = 74), stipend 10 (five Echoes home).
## Leave after 1 done, then finish: none 64, some 74, all 84 in total. Leave after 2 done: none 40 + 0 = 40,
## some 62, all 84. The total is the leave payment plus the stage-end preview.
static func _t_settle_worked_example() -> Dictionary:
	var m: Array = []
	for c in [[1, "none", 64], [1, "some", 74], [1, "all", 84], [2, "none", 40], [2, "some", 62], [2, "all", 84]]:
		var done := int(c[0])
		var objs: Array = [_obj(0, "combat", done >= 1), _obj(1, "recover", done >= 2), _obj(2, "shrine", false), _carry_boss()]
		var ctx := _carry_ctx("realm.01", 0, objs, _seed_for(c[1]))
		var econ := _carry_econ(ctx)
		var got := StageSettlementService.settle_leave(ctx, ctx.config_service, econ, 1.0, "test", _logger(), 1)
		if str(got["outcome"]) != c[1]:
			m.append("%d done %s: outcome %s" % [done, c[1], got["outcome"]])
		for o_v in (_carry_stage(ctx)["objectives"] as Array):
			if str((o_v as Dictionary).get("type")) != "boss":
				(o_v as Dictionary)["completed"] = true
		var end := StageSettlementService.new(ctx, ctx.config_service, econ, null).preview()
		var total := int(got["ase"]) + int(end["ase"])
		if total != int(c[2]):
			m.append("%d done %s: %d at the leave + %d at the end = %d, expected %d" % [done, c[1], got["ase"], end["ase"], total, c[2]])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## A replay builds the stage objectives fresh (RealmService.get_or_create -> RealmGenerator), so the
## `settled` marks and the settled totals of the first run do not carry over. Checked on a real runtime.
static func _t_settle_replay_resets_marks() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_settle_replay")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var runtime: FlowRuntime = env["runtime"]
	var save_data: Dictionary = runtime.get_save_data()
	var realm: Dictionary = VentureCharacterizationTests._realm(save_data, "realm.01")
	for s_v in (realm["stages"] as Array):
		var st: Dictionary = s_v
		st["settled_ase"] = 7
		st["settled_ekwan"] = 1
		st["settle_count"] = 2
		for o_v in (st["objectives"] as Array):
			(o_v as Dictionary)["completed"] = true
			(o_v as Dictionary)["settled"] = true
			(o_v as Dictionary)["settled_share"] = 100
	realm["status"] = RealmModel.STATUS_COMPLETED
	realm["is_completed"] = true
	var fresh := RealmService.get_or_create("realm.01", runtime.flow_ctx, 9000)
	if int(fresh.get("run_count", -1)) != 1:
		return { "ok": false, "error": "setup: replay run_count %s, expected 1" % str(fresh.get("run_count")) }
	var seen := 0
	for s_v in (fresh["stages"] as Array):
		var st: Dictionary = s_v
		if st.has("settled_ase") or st.has("settled_ekwan") or st.has("settle_count"):
			m.append("stage %s kept settled totals: %s" % [st.get("index"), JSON.stringify(st)])
		for o_v in (st["objectives"] as Array):
			seen += 1
			var o: Dictionary = o_v
			if bool(o.get("settled", false)) or o.has("settled_share") or bool(o.get("completed", false)):
				m.append("replay objective kept a mark: %s" % JSON.stringify(o))
	if seen == 0:
		m.append("the replay has no objectives to check")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Keys that would show a share or odds. None may appear in any snapshot key.
const _FORBIDDEN_KEYS := ["settled_share", "carry_odds", "carry_shares", "share", "odds", "pct", "percent", "chance"]

static func _forbidden_in(node: Variant, path: String, found: Array) -> void:
	if node is Dictionary:
		for k in (node as Dictionary):
			if _FORBIDDEN_KEYS.has(str(k)):
				found.append("%s.%s" % [path, str(k)])
			_forbidden_in((node as Dictionary)[k], path + "." + str(k), found)
	elif node is Array:
		for i in (node as Array).size():
			_forbidden_in((node as Array)[i], "%s[%d]" % [path, i], found)


## Real return-home dispatch. The explore snapshot previews the gathered amount (no odds); the action
## pays what the stream rolls; the Resolve card names the outcome as a word with the amounts paid now and
## holds no percent and no odds; the preview after the return says nothing new.
static func _t_settle_return_home_dispatch() -> Dictionary:
	var env := VentureCharacterizationTests._setup_explore_env("econ_char_settle_home")
	if not bool(env.get("ok", false)):
		return env
	var m: Array = []
	var runtime: FlowRuntime = env["runtime"]
	var flow_ctx: FlowContext = runtime.flow_ctx
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	stage["objectives"] = [_obj(0, "shrine", true), _obj(1, "recover", true), _carry_boss()]
	var emap: Dictionary = stage["explore_map"]
	var sits: Array = emap.get("situations", [])
	if sits.is_empty():
		return { "ok": false, "error": "test setup failed: the stage has no situation" }
	(sits[0] as Dictionary)["revealed"] = true
	var realm := VentureCharacterizationTests._realm(runtime.get_save_data(), "realm.01")
	var realm_seed := int(realm.get("seed", 0))
	var directive: Dictionary = runtime.directive_service.get_active_directive()
	var threshold: int = maxi(0, 40 - int(directive.get("escape_bonus", 0)))
	var turn := -1
	for cand in range(0, 200):
		if CampaignSeed.get_rng_from(realm_seed, "stage.escape.%s.%d" % [flow_ctx.stage_id, cand]).randi_range(0, 100) > threshold:
			turn = cand
			break
	if turn < 0:
		return { "ok": false, "error": "test setup failed: no successful escape roll" }
	emap["turn_count"] = turn
	runtime.get_save_data()["economy"]["ase"] = 0
	runtime.get_save_data()["economy"]["ekwan"] = 0
	var mul := StageSettlementService.retention_mul(directive)
	var want := _expected_outcome(realm_seed, int(realm.get("run_count", 0)), 0, mul)
	var share: float = {"none": 0.0, "some": 0.5, "all": 1.0}[want]
	var snap_pre: Dictionary = StageExploreSnapshotBuilder.build(flow_ctx, 50)
	var pre: Dictionary = snap_pre["data"]["carry_home_preview"]
	var bad: Array = []
	_forbidden_in(snap_pre, "explore", bad)
	if int(pre["ase"]) != 54 or int(pre["ekwan"]) != 11 or int(pre["overcome"]) != 2 or int(pre["total"]) != 2 \
			or bool(pre["nothing_new"]) or pre.size() != 5:
		m.append("preview %s, expected the gathered 54/11, 2 of 2, nothing_new false and no other key" % str(pre))
	var out: Dictionary = runtime.dispatch({ "type": "stage.return_home" })
	var data: Dictionary = out.get("data", {})
	var econ: Dictionary = runtime.get_save_data()["economy"]
	var want_ase := RewardCalc.round_payout(54.0 * share)
	var want_ekwan := RewardCalc.round_payout(11.0 * share)
	if str(data.get("settle_outcome", "")) != want:
		m.append("card outcome %s, the stream gives %s" % [str(data.get("settle_outcome")), want])
	if int(data.get("ase_awarded", -1)) != want_ase or int(data.get("ekwan_awarded", -1)) != want_ekwan \
			or int(econ["ase"]) != want_ase or int(econ["ekwan"]) != want_ekwan:
		m.append("card %s/%s balance %s/%s, expected %d/%d" % [data.get("ase_awarded"), data.get("ekwan_awarded"),
			econ["ase"], econ["ekwan"], want_ase, want_ekwan])
	var row := _row_by_cause(data.get("reward_breakdown", []), "settle_" + want)
	if row.is_empty() or int(row.get("delta", -1)) != want_ase:
		m.append("no settle_%s row with delta %d: %s" % [want, want_ase, JSON.stringify(data.get("reward_breakdown"))])
	_forbidden_in(out, "resolve", bad)
	for r_v in data.get("reward_breakdown", []):
		var text := JSON.stringify(r_v).to_lower()
		for word in ["%", "half", "odds", "chance", "percent"]:
			if text.contains(word):
				m.append("ledger row holds '%s': %s" % [word, text])
	if not bad.is_empty():
		m.append("snapshot keys that show a share or odds: %s" % str(bad))
	var after: Dictionary = StageExploreSnapshotBuilder.build(flow_ctx, 51)["data"]["carry_home_preview"]
	if int(after["ase"]) != 0 or int(after["ekwan"]) != 0 or not bool(after["nothing_new"]):
		m.append("preview after the return %s, expected 0/0 and nothing_new" % str(after))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-106: a successful combat retreat does NOT settle. It costs 10 Ase, pays nothing, marks nothing, and
## the pre-combat preview carries no amount. (Step 6.2 reworks the rest of the retreat.)
static func _t_settle_retreat_pays_nothing() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "econ_char_settle_retreat")
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var m: Array = []
	var flow_ctx: FlowContext = env["flow_ctx"]
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	stage["objectives"] = [_obj(0, "shrine", true), _obj(1, "recover", true), _carry_boss()]
	stage["explore_map"] = { "situations": [{ "id": "sit.econ", "resolved": false, "revealed": true }] }
	flow_ctx.save_data["economy"]["ase"] = 50
	flow_ctx.save_data["economy"]["ekwan"] = 0
	var pre: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 1)["data"]["carry_retreat_preview"]
	var out: Dictionary = (env["runtime"] as FlowRuntime).dispatch(
		{ "type": "encounter.retreat", "ase_cost": 999, "success_pct": 100 })
	var data: Dictionary = out.get("data", {})
	var econ: Dictionary = flow_ctx.save_data["economy"]
	var st := FlowStageExploreState._get_current_stage(flow_ctx)
	if int(pre["ase"]) != 0 or int(pre["ekwan"]) != 0 or int(pre["overcome"]) != 2 or int(pre["total"]) != 2:
		m.append("preview %s, expected 0/0 and 2 of 2" % str(pre))
	# REWRITTEN (6.2): the retreat card is the pulled-back card (D-106). It carries no amount at all,
	# so "paid nothing" is now the balance alone, plus the absence of any amount key on the card.
	if data.has("ase_awarded") or data.has("ekwan_awarded") or int(econ["ase"]) != 40 or int(econ["ekwan"]) != 0:
		m.append("retreat card %s balance %s/%s, expected no amount keys and 40/0 (10 Ase cost)" % [
			JSON.stringify(data), econ["ase"], econ["ekwan"]])
	if st.has("settle_count") or st.has("settled_ase") or bool((st["objectives"][0] as Dictionary).get("settled", false)):
		m.append("a retreat settled: %s" % JSON.stringify(st))
	if data.has("settle_outcome"):
		m.append("a retreat card carries settle_outcome")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_intel_gained() -> Dictionary:
	var m: Array = []
	var objs: Array = [_req(0, "combat", false), ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)]

	var none := _final_card("econ_char_intel_0", objs.duplicate(true), true)
	if none.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var fc0: FlowContext = none["flow_ctx"]
	if fc0.encounter_start_revealed_count < 0:
		m.append("setup did not record the start count")
	if (none["card"]["data"] as Dictionary).has("intel_gained"):
		m.append("victory with no new reveal carries intel_gained")

	for n in [1, 2]:
		var env := _final_card("econ_char_intel_%d" % n, objs.duplicate(true), true, false, n)
		if int(env["card"]["data"].get("intel_gained", -1)) != n:
			m.append("%d reveals: intel_gained %s" % [n, str(env["card"]["data"].get("intel_gained"))])

	var lost := _final_card("econ_char_intel_lost", objs.duplicate(true), false, false, 2)
	if (lost["card"]["data"] as Dictionary).has("intel_gained"):
		m.append("defeat card carries intel_gained")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_intel_gained_replay() -> Dictionary:
	var m: Array = []
	var objs: Array = [_req(0, "combat", false), ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)]
	var env := _final_card("econ_char_intel_replay", objs, true, false, 2)
	var fc: FlowContext = env["flow_ctx"]
	var card: Dictionary = env["card"]
	PendingResultService.capture_or_consume(fc, card, 7)
	var stored := PendingResultService.read(fc.save_data)
	if int((stored.get("resolve_data", {}) as Dictionary).get("intel_gained", -1)) != 2:
		m.append("stored result lost intel_gained")
	var replay := PendingResultService.build_snapshot(fc, 8)
	if int((replay.get("data", {}) as Dictionary).get("intel_gained", -1)) != 2:
		m.append("replayed card lost intel_gained")
	var zero := _final_card("econ_char_intel_replay0", objs.duplicate(true), true)
	PendingResultService.capture_or_consume(zero["flow_ctx"], zero["card"], 7)
	if (PendingResultService.build_snapshot(zero["flow_ctx"], 8)["data"] as Dictionary).has("intel_gained"):
		m.append("replayed zero card gained an intel_gained key")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# ---------------------------------------------------------------------------
# Stage death record, thread_whole, objective_overcome (Phase 5.11: D-45, D-50, D-81, D-98)
# ---------------------------------------------------------------------------

static func _kill_echo(ectx: EncounterContext, nth: int) -> String:
	var seen := 0
	for a_v in ectx.actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("faction", "")) == "echo":
			if seen == nth:
				(a_v as Dictionary)["is_dead"] = true
				return str((a_v as Dictionary).get("name", ""))
			seen += 1
	return ""


static func _revive_all(ectx: EncounterContext) -> void:
	for a_v in ectx.actors:
		if a_v is Dictionary:
			(a_v as Dictionary)["is_dead"] = false


static func _t_death_record() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var env := _final_card("econ_char_record", [_req(0, "combat", false), _req(1, "shrine", true), boss], true, true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	var runtime: FlowRuntime = env["runtime"]
	var first := str(env["dead_name"])
	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)

	# (i) the builder wrote nothing; the hook writes.
	if stage.has("lost_echo_names"):
		m.append("build_final_snapshot wrote lost_echo_names")
	var card1: Dictionary = env["card"]["data"]
	if bool(card1.get("thread_whole", true)):
		m.append("fight 1 killed an Echo but thread_whole is true")
	runtime._stage_explore_session_service().record_fight_deaths(7)
	runtime._stage_explore_session_service().record_fight_deaths(7)
	if str(stage.get("lost_echo_names", [])) != str([first]):
		m.append("after fight 1 the record is %s, expected [%s] once" % [str(stage.get("lost_echo_names")), first])

	# (a) fight 2 kills nobody: the record keeps the name, the card and the row use it.
	_revive_all(ectx)
	var card2: Dictionary = FlowEncounterState.build_final_snapshot(flow_ctx, 8)["data"]
	if bool(card2.get("thread_whole", true)):
		m.append("(a) fight 2 card: thread_whole true after a death in fight 1")
	var row := _row_by_cause(card2.get("stage_payout_rows", []), "echoes_alive")
	var p: Dictionary = row.get("params", {})
	if int(p.get("alive", -1)) != 4 or int(p.get("started", -1)) != 5 or str(p.get("lost", [])) != str([first]) \
			or int(row.get("delta", -1)) != 8:
		m.append("(a) fight 2 row %s, expected 8 Ase, 4 of 5, lost [%s]" % [JSON.stringify(row), first])
	# (g) preview == paid.
	var before := int(runtime.get_save_data()["economy"]["ase"])
	runtime.dispatch({ "type": "flow.complete_stage" })
	var paid := int(runtime.get_save_data()["economy"]["ase"]) - before
	if paid != int(card2.get("stage_payout_ase", -2)) or paid != 58:
		m.append("(g) flow.complete_stage paid %d, card previewed %s, expected 58" % [paid, str(card2.get("stage_payout_ase"))])

	# (d) names stay unique when the same Echo dies again, and keep the order of death.
	# complete_stage cleared the encounter; restore it for the hook.
	flow_ctx.encounter_ctx = ectx
	_kill_echo(ectx, 0)
	var second := _kill_echo(ectx, 1)
	var svc := runtime._stage_explore_session_service()
	svc.record_fight_deaths(9)
	var want := [first, second]
	if str(stage.get("lost_echo_names", [])) != str(want):
		m.append("(d) record %s, expected %s" % [str(stage.get("lost_echo_names")), str(want)])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_thread_and_overcome() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var objs: Array = [_req(0, "combat", false), _req(1, "shrine", false), boss]

	# (b), (e) victory, nobody dead: thread_whole true; the fought objective is named from config.
	var env := _final_card("econ_char_thread_b", objs.duplicate(true), true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var data: Dictionary = env["card"]["data"]
	if data.get("thread_whole", null) != true:
		m.append("(b) clean win: thread_whole %s, expected true" % str(data.get("thread_whole")))
	var oo: Dictionary = data.get("objective_overcome", {}) if data.get("objective_overcome") is Dictionary else {}
	if int(oo.get("index", -1)) != 0 or str(oo.get("type", "")) != "combat" or str(oo.get("label", "")) != "Clear" \
			or oo.size() != 3:
		m.append("(e) objective_overcome %s, expected {index 0, type combat, label Clear}" % JSON.stringify(oo))

	# (e) no linked objective: the key is absent.
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.active_encounter_objective_index = -1
	if FlowEncounterState.build_final_snapshot(flow_ctx, 7)["data"].has("objective_overcome"):
		m.append("(e) objective_overcome present with no linked objective")

	# (f) a dead Echo in THIS fight alone makes thread_whole false.
	var dead := _final_card("econ_char_thread_dead", objs.duplicate(true), true, true)
	if (dead["card"]["data"] as Dictionary).get("thread_whole", null) != false:
		m.append("(f) win with a death: thread_whole %s, expected false" % str((dead["card"]["data"] as Dictionary).get("thread_whole")))

	# (e), (f) defeat: neither key.
	var lost := _final_card("econ_char_thread_lost", objs.duplicate(true), false)
	var ld: Dictionary = lost["card"]["data"]
	if ld.has("thread_whole") or ld.has("objective_overcome"):
		m.append("(f) defeat card carries thread_whole or objective_overcome: %s" % str(ld.keys()))
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_death_record_old_and_replay() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var env := _final_card("econ_char_record_old", [_req(0, "combat", false), boss], true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var fc: FlowContext = env["flow_ctx"]
	# (c) a stage without the field reads empty and nothing needs a migration.
	if FlowStageExploreState._get_current_stage(fc).has("lost_echo_names") \
			or not ActiveStageService.stage_lost_echo_names(fc).is_empty():
		m.append("(c) a stage without the field does not read empty")
	# (h) the replayed card keeps both keys.
	var card: Dictionary = env["card"]
	var data: Dictionary = card["data"]
	if not data.has("thread_whole") or not data.has("objective_overcome"):
		m.append("(h) fixture card lacks a key: %s" % str(data.keys()))
	PendingResultService.capture_or_consume(fc, card, 7)
	var replay: Dictionary = PendingResultService.build_snapshot(fc, 8)["data"]
	if replay.get("thread_whole", null) != data.get("thread_whole") \
			or JSON.stringify(replay.get("objective_overcome")) != JSON.stringify(data.get("objective_overcome")):
		m.append("(h) replayed card %s / %s, stored %s / %s" % [str(replay.get("thread_whole")),
			JSON.stringify(replay.get("objective_overcome")), str(data.get("thread_whole")), JSON.stringify(data.get("objective_overcome"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-103 (F4): a death stays on the stage record through a return home, so visit 2 keeps the
## reduced stipend; a re-run builds a fresh realm model, so a replay starts with no record.
static func _t_death_record_lifetime() -> Dictionary:
	var m: Array = []
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var env := _final_card("econ_char_lifetime", [_req(0, "combat", false), _req(1, "shrine", true), boss], true, true)
	if env.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var runtime: FlowRuntime = env["runtime"]
	var fc: FlowContext = env["flow_ctx"]
	var first := str(env["dead_name"])
	runtime._stage_explore_session_service().record_fight_deaths(7)
	fc.encounter_ctx = null
	runtime.dispatch({ "type": "stage.return_home" })
	if str(ActiveStageService.stage_lost_echo_names(fc)) != str([first]):
		m.append("after return home the record is %s, expected [%s]" % [str(ActiveStageService.stage_lost_echo_names(fc)), first])
	var svc := StageSettlementService.new(fc, fc.config_service, null, null)
	var p: Dictionary = _stipend_row(svc.preview()).get("params", {})
	if str(p.get("lost", [])) != str([first]):
		m.append("visit 2 stipend row lost %s, expected [%s]" % [str(p.get("lost")), first])
	# Stage cleared: the next run of the realm is a new model with new stages.
	var realm_id := fc.realm_id
	var old_model: Dictionary = fc.save_data["realms"][realm_id]
	var old_runs := int(old_model.get("run_count", 0))
	old_model["status"] = RealmModel.STATUS_COMPLETED
	var fresh: Dictionary = RealmService.get_or_create(realm_id, fc, 20)
	if int(fresh.get("run_count", 0)) != old_runs + 1:
		m.append("re-run did not increment run_count")
	for s_v in fresh.get("stages", []):
		if (s_v as Dictionary).has("lost_echo_names"):
			m.append("a replay stage inherited lost_echo_names")
			break
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-50 and D-102 (D1): with no fight context the stipend reads the stage death record, and an
## empty or missing record leaves the whole active party home.
static func _t_stipend_record_no_encounter() -> Dictionary:
	var m: Array = []
	var objs: Array = [_obj(0, "combat", true)]
	var ctx := _stage_ctx(_config(), objs)
	var roster: Array = []
	var ids: Array = []
	for i in 3:
		roster.append({ "id": "e%d" % i, "name": "Name e%d" % i })
		ids.append("e%d" % i)
	ctx.save_data["sanctum"] = { "roster": roster, "active_party_ids": ids }
	var svc := StageSettlementService.new(ctx, ctx.config_service, null, null)
	# (e) an old save has no field; (c) an empty record. Both leave everyone home.
	var stage: Dictionary = FlowStageExploreState._get_current_stage(ctx)
	if stage.has("lost_echo_names"):
		m.append("fixture stage already has the field")
	var row := _stipend_row(svc.preview())
	if int((row.get("params", {}) as Dictionary).get("alive", -1)) != 3 or int(row.get("delta", -1)) != 6:
		m.append("(e) no field: row %s, expected 3 of 3, 6 Ase" % JSON.stringify(row))
	stage["lost_echo_names"] = []
	row = _stipend_row(svc.preview())
	if int((row.get("params", {}) as Dictionary).get("alive", -1)) != 3 or int(row.get("delta", -1)) != 6:
		m.append("(c) empty record: row %s, expected 3 of 3, 6 Ase" % JSON.stringify(row))
	# A record naming one party Echo: that Echo is not home.
	stage["lost_echo_names"] = ["Name e1"]
	var pv := svc.preview()
	row = _stipend_row(pv)
	var p: Dictionary = row.get("params", {})
	if int(p.get("alive", -1)) != 2 or int(p.get("started", -1)) != 3 or str(p.get("lost", [])) != str(["Name e1"]) \
			or int(row.get("delta", -1)) != 4 or int(pv.get("ase", -1)) != 24:
		m.append("record [Name e1]: row %s, ase %s, expected 2 of 3, 4 Ase, stage 24" % [JSON.stringify(row), str(pv.get("ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## Fight 1 kills an Echo and writes the record; the game saves; a NEW runtime boots from the file.
## Returns { runtime (rebooted), card, dead_name } or an empty dict.
static func _death_then_reboot(tag: String, replay_card: bool) -> Dictionary:
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var env := _final_card(tag, [_req(0, "combat", false), _req(1, "shrine", true), boss], true, true)
	if env.is_empty():
		return {}
	var runtime: FlowRuntime = env["runtime"]
	var fc: FlowContext = env["flow_ctx"]
	var ob: Dictionary = runtime.get_save_data()["onboarding"]
	ob["chapter_one_complete"] = true
	ob["chapter_one_step"] = OnboardingService.STEP_COMPLETE
	ob["keeper_intro_complete"] = true
	ob["keeper_intro_step"] = "complete"
	runtime._stage_explore_session_service().record_fight_deaths(7)
	if replay_card:
		PendingResultService.capture_or_consume(fc, env["card"], 7)
	SaveService.save_to_file(runtime.save_path, fc.save_data, _logger(), 7)
	var rebooted := FlowRuntime.new(_logger(), ConfigService.new(), runtime.save_path)
	rebooted.boot()
	return { "runtime": rebooted, "card": env["card"], "dead_name": env["dead_name"] }


## D1: after a quit and reload there is no fight context. The stage card said 4 of 5 home; the
## payout must say the same.
static func _t_reboot_after_death() -> Dictionary:
	var m: Array = []
	var r := _death_then_reboot("econ_char_reboot", false)
	if r.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var rt: FlowRuntime = r["runtime"]
	var dead := str(r["dead_name"])
	var shown: Dictionary = r["card"]["data"]
	# Without a pending card, flow.continue does not restore the stage ids; set them as the card replay does.
	rt.flow_ctx.realm_id = "realm.01"
	rt.flow_ctx.stage_id = "stage.0"
	if rt.flow_ctx.encounter_ctx != null:
		m.append("the rebooted context still has a fight context; the test proves nothing")
	var pv := StageSettlementService.new(rt.flow_ctx, rt.config_service, null, null).preview()
	var row := _stipend_row(pv)
	var p: Dictionary = row.get("params", {})
	if int(p.get("alive", -1)) != 4 or int(p.get("started", -1)) != 5 or str(p.get("lost", [])) != str([dead]):
		m.append("reload preview row %s, expected 4 of 5, lost [%s]" % [JSON.stringify(row), dead])
	var before := int(rt.get_save_data()["economy"]["ase"])
	rt.dispatch({ "type": "flow.complete_stage" })
	var paid := int(rt.get_save_data()["economy"]["ase"]) - before
	if paid != int(pv.get("ase", -1)) or paid != int(shown.get("stage_payout_ase", -2)) or paid != 58:
		m.append("paid %d, reload preview %s, card %s, expected all 58" % [paid, str(pv.get("ase")), str(shown.get("stage_payout_ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D1 on the replayed Resolve card: the card shown after the quit equals what its button pays.
static func _t_reboot_replayed_card() -> Dictionary:
	var m: Array = []
	var r := _death_then_reboot("econ_char_reboot_card", true)
	if r.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var rt: FlowRuntime = r["runtime"]
	var dead := str(r["dead_name"])
	var replayed: Dictionary = rt.dispatch({ "type": "flow.continue" })
	var rd: Dictionary = replayed.get("data", {})
	var act: Dictionary = (replayed.get("actions", {}) as Dictionary).get("cta.next_stage", {})
	if act.is_empty():
		return { "ok": false, "error": "replayed card has no cta.next_stage: type %s" % str(replayed.get("type")) }
	var row := _row_by_cause(rd.get("stage_payout_rows", []), "echoes_alive")
	var p: Dictionary = row.get("params", {})
	if int(p.get("alive", -1)) != 4 or str(p.get("lost", [])) != str([dead]):
		m.append("replayed row %s, expected 4 of 5, lost [%s]" % [JSON.stringify(row), dead])
	var before := int(rt.get_save_data()["economy"]["ase"])
	rt.dispatch(act)
	var paid := int(rt.get_save_data()["economy"]["ase"]) - before
	if paid != int(rd.get("stage_payout_ase", -2)) or paid != 58:
		m.append("paid %d, replayed card %s, expected both 58" % [paid, str(rd.get("stage_payout_ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D1 on the contact path: a good charge contact completes the last required objective with no
## fight context (ContactController calls mark_stage_objective_completed). An earlier death stays lost.
static func _t_charge_after_death() -> Dictionary:
	var m: Array = []
	var r := _death_then_reboot("econ_char_charge", false)
	if r.is_empty():
		return { "ok": false, "error": "harness did not build an encounter" }
	var rt: FlowRuntime = r["runtime"]
	var dead := str(r["dead_name"])
	rt.flow_ctx.realm_id = "realm.01"
	rt.flow_ctx.stage_id = "stage.0"
	var stage: Dictionary = FlowStageExploreState._get_current_stage(rt.flow_ctx)
	var objs: Array = stage["objectives"]
	(objs[0] as Dictionary)["completed"] = false
	rt._stage_explore_session_service().mark_stage_objective_completed(0, 9)
	var pv := StageSettlementService.new(rt.flow_ctx, rt.config_service, null, null).preview()
	var p: Dictionary = _stipend_row(pv).get("params", {})
	if rt.flow_ctx.encounter_ctx != null or int(p.get("alive", -1)) != 4 or str(p.get("lost", [])) != str([dead]):
		m.append("charge path row %s, expected 4 of 5, lost [%s], no fight context" % [JSON.stringify(p), dead])
	var before := int(rt.get_save_data()["economy"]["ase"])
	rt.dispatch({ "type": "flow.complete_stage" })
	var paid := int(rt.get_save_data()["economy"]["ase"]) - before
	if paid != int(pv.get("ase", -1)):
		m.append("paid %d, preview %s" % [paid, str(pv.get("ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }
