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
	"pursue": 8, "combat": 10, "recover": 12, "protect": 12,
	"endure": 14, "shrine": 15, "guide_spirit": 16, "boss": 0,
}

# Ekwan of each type in data.rewards.objective_ekwan (D-29, working set B). Fights pay none.
const _TYPE_EKWAN := {
	"pursue": 2, "combat": 2, "protect": 3, "guide_spirit": 3,
	"endure": 4, "recover": 5, "shrine": 6, "boss": 0,
}

# Stage base (stage = [type, boss stub]; type boss = [boss] alone) -> run_count -> Ase.
# Ase = roundi(base x redo). The stage index and the realm virtue add nothing (D-40).
# The Echoes stipend is not in this table: `_settle_cell` settles with no fight, and the stage
# environment has a party of one Echo, so the stipend is one Echo x 2 Ase on every cell.
const _ONE_ECHO_STIPEND := 2
const _STAGE_ASE := {
	0:  { 0: 0, 1: 0 },
	8:  { 0: 8, 1: 7 },
	10: { 0: 10, 1: 9 },
	12: { 0: 12, 1: 11 },
	14: { 0: 14, 1: 13 },
	15: { 0: 15, 1: 14 },
	16: { 0: 16, 1: 14 },
}
# Stage Ekwan of a single completed type at run_count 1 (redo 0.9): roundi(amount x 0.9).
const _TYPE_EKWAN_RUN1 := {
	"pursue": 2, "combat": 2, "protect": 3, "guide_spirit": 3,
	"endure": 4, "recover": 5, "shrine": 5, "boss": 0,
}


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("econ_char/base_reward_per_type", Callable(EconomyCharacterizationTests, "_t_base_reward_per_type"))
	runner.register_test("econ_char/every_type_has_a_weight", Callable(EconomyCharacterizationTests, "_t_every_type_has_a_weight"))
	runner.register_test("econ_char/boss_stub_adds_zero", Callable(EconomyCharacterizationTests, "_t_boss_stub_adds_zero"))
	runner.register_test("econ_char/combat_and_shrine_single_objective", Callable(EconomyCharacterizationTests, "_t_combat_and_shrine"))
	runner.register_test("econ_char/multi_objective_stage_sums", Callable(EconomyCharacterizationTests, "_t_multi_objective"))
	runner.register_test("econ_char/partial_payout_uses_stage_base", Callable(EconomyCharacterizationTests, "_t_partial_payout"))
	runner.register_test("econ_char/unknown_type_logs_and_pays_zero", Callable(EconomyCharacterizationTests, "_t_unknown_type"))
	runner.register_test("econ_char/redo_multiplier_by_run_count", Callable(EconomyCharacterizationTests, "_t_redo_multiplier"))
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
	runner.register_test("econ_char/ledger_seen_default_false_and_action_sets_it", Callable(EconomyCharacterizationTests, "_t_ledger_seen"))


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
static func _encounter_pay(objectives: Array, victory: bool, run_count: int, fought_index: int = 0) -> Dictionary:
	var reward_cfg := _rewards_cfg()
	var objs: Array = objectives.duplicate(true)
	if not victory and fought_index >= 0:
		(objs[fought_index] as Dictionary)["completed"] = false
	var rd: Dictionary = RewardCalc.compute(
		victory, objs, 2, 2, 2, run_count, reward_cfg,
		EncounterResolutionModes.COMBAT, 0.0, "", null, 0, fought_index)
	var save := { "economy": { "ase": 0, "ekwan": 0 } }
	var econ := EconomyService.new(save)
	var paid: Dictionary = econ.reward_encounter_complete(
		victory,
		int(rd.get("consolation_base", 0)),
		float(rd.get("redo_multiplier", 1.0)), str(rd.get("rank", "F")), true, _logger(), 1)
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
	for c in [["combat", 10, 3], ["shrine", 15, 4]]:
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
## Stage 0, run 0: Ase = 25, Ekwan = combat 2 + shrine 6 = 8.
static func _t_multi_objective() -> Dictionary:
	var cfg := _rewards_cfg()
	var objs: Array = [
		_obj(0, "combat", true), _obj(1, "shrine", true),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false),
	]
	var mismatches: Array = []
	if RewardCalc.base_reward(objs, cfg) != 25:
		mismatches.append("sum of combat + shrine + boss is %d, expected 25" % RewardCalc.base_reward(objs, cfg))
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_multi")
	if not bool(env.get("ok", false)):
		return env
	var out := _settle_cell(env, objs, 0, 0, 1)
	if int(out.get("ase_awarded", -1)) != 25 + _ONE_ECHO_STIPEND or int(out.get("ekwan_awarded", -1)) != 8 \
			or _breakdown_delta(out, "Base objectives") != 25:
		mismatches.append("stage paid %s/%s base row %d, expected 27/8 base row 25" \
			% [str(out.get("ase_awarded")), str(out.get("ekwan_awarded")), _breakdown_delta(out, "Base objectives")])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## The retreat and return-home partial payouts are roundi(completed base x 0.12). The base comes
## from ActiveStageService.get_stage_base_reward, the same sum the stage payer uses. Every
## pre-boss objective here is completed.
static func _t_partial_payout() -> Dictionary:
	var cfg := _config()
	var factor := float(ConfigService.get_rewards_cfg(cfg).get("partial_intel_reward_factor", 0.12))
	var mismatches: Array = []
	for c in [[["combat"], 10, 1], [["guide_spirit"], 16, 2], [["combat", "shrine"], 25, 3], [["pursue"], 8, 1]]:
		var objs: Array = []
		for k in range((c[0] as Array).size()):
			objs.append(_obj(k, c[0][k], true))
		objs.append(ObjectiveModel.make(objs.size(), ObjectiveModel.TYPE_BOSS, 2, {}, false, false))
		var ctx := _stage_ctx(cfg, objs)
		var base := ActiveStageService.get_stage_base_reward(ctx, cfg)
		var partial := roundi(float(base) * factor)
		if base != int(c[1]) or partial != int(c[2]):
			mismatches.append("%s: base %d partial %d, expected %d / %d" % [str(c[0]), base, partial, int(c[1]), int(c[2])])
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


static func _stage_ctx(cfg: ConfigService, objs: Array, fought_index: int = -1) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = cfg
	ctx.realm_id = "realm.01"
	ctx.stage_id = "stage.0"
	ctx.active_encounter_objective_index = fought_index
	ctx.save_data = { "realms": { "realm.01": { "stages": [ { "index": 0, "objectives": objs } ] } } }
	return ctx


## D-07: a type with no key logs economy.reward.unknown_objective_type and counts 0. It never
## falls back to combat, in every reader of the stage base.
static func _t_unknown_type() -> Dictionary:
	var cfg := _rewards_cfg()
	var mismatches: Array = []
	var logger := StructuredLogger.new()
	var objs: Array = [{ "type": "mystery", "completed": true }, _obj(1, "combat", true)]
	var base := RewardCalc.base_reward(objs, cfg, logger, 7)
	if base != 10:
		mismatches.append("unknown + combat paid %d, expected 10" % base)
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


static func _t_redo_multiplier() -> Dictionary:
	var cfg := _rewards_cfg()
	var m0 := RewardCalc.redo_multiplier(0, cfg)
	var m1 := RewardCalc.redo_multiplier(1, cfg)
	var ok := is_equal_approx(m0, 1.0) and is_equal_approx(m1, 0.9)
	return { "ok": ok, "error": "redo multiplier run 0 = %s, run 1 = %s" % [str(m0), str(m1)] }


## Names removed by D-40 and D-49. None may stay in data.rewards or in core/ (no alias).
const _REMOVED_NAMES := [
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
		preview_out: Dictionary = {}) -> Dictionary:
	var runtime: FlowRuntime = env["runtime"]
	var save_data: Dictionary = runtime.get_save_data()
	var realm: Dictionary = VentureCharacterizationTests._realm(save_data, "realm.01")
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
	realm["run_count"] = run_count
	realm["run_index"] = 0
	var economy: Dictionary = save_data["economy"]
	economy["ase"] = 0
	economy["ekwan"] = 0
	runtime.flow_ctx.realm_id = "realm.01"
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
	for type in ObjectiveModel.VALID_TYPES:
		var base := _expected_base(type)
		for run_count in [0, 1]:
			for i in range(_STAGE_COUNT):
				n += 1
				var out := _settle_cell(env, _objectives(type), i, run_count, n)
				var want_ase: int = _STAGE_ASE[base][run_count] + _ONE_ECHO_STIPEND
				var want_ekwan: int = _TYPE_EKWAN[type] if run_count == 0 else _TYPE_EKWAN_RUN1[type]
				var cell := "%s run %d stage %d" % [type, run_count, i]
				if int(out.get("ase_awarded", -1)) != want_ase or int(out.get("balance_ase", -1)) != want_ase:
					mismatches.append("%s ase %s/%s, expected %d" % [cell, str(out.get("ase_awarded")), str(out.get("balance_ase")), want_ase])
				if int(out.get("ekwan_awarded", -1)) != want_ekwan or int(out.get("balance_ekwan", -1)) != want_ekwan:
					mismatches.append("%s ekwan %s/%s, expected %d" % [cell, str(out.get("ekwan_awarded")), str(out.get("balance_ekwan")), want_ekwan])
				for row_v in out.get("breakdown", []):
					if str((row_v as Dictionary).get("currency", "")) == "ekwan":
						mismatches.append("%s has an Ekwan breakdown row (D-32)" % cell)
				var base_row := _breakdown_delta(out, "Base objectives")
				if base_row != base:
					mismatches.append("%s base row %d, expected %d" % [cell, base_row, base])
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
	if RewardCalc.base_reward([_obj(0, "shrine", true)], trimmed, logger3, 3) != 15 or not logger3.get_logs().is_empty():
		m.append("the Ase table was affected by the missing Ekwan key")
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-30: the stage Ekwan follows the replay factor and is rounded ONCE on the stage sum. The
## x.5 cells are pinned: Set B recover 5 at 0.7 = 3.5, protect 3 at 0.5 = 1.5 (roundi rounds half
## away from zero). combat 2 + protect 3 at 0.7 = 3.5 -> 4, while per-objective rounding gives
## roundi(1.4) + roundi(2.1) = 3.
static func _t_ekwan_replay() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_ekwan_replay")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(3, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var m: Array = []
	var n := 0
	# [objective types, run_count, expected Ekwan]. Redo: run 3 = 0.7, run 5 and 6 = 0.5 (floor).
	for c in [
		[["recover"], 3, 4], [["protect"], 5, 2], [["protect"], 6, 2],
		[["combat", "protect"], 3, 4], [["shrine", "guide_spirit"], 0, 9],
		[["shrine", "guide_spirit"], 5, 5], [["combat"], 5, 1], [["pursue"], 6, 1],
	]:
		n += 1
		var objs: Array = []
		for k in range((c[0] as Array).size()):
			objs.append(_obj(k, c[0][k], true))
		objs.append(boss.duplicate(true))
		var out := _settle_cell(env, objs, 0, int(c[1]), 20 + n)
		if int(out.get("ekwan_awarded", -1)) != int(c[2]) or int(out.get("balance_ekwan", -1)) != int(c[2]):
			m.append("%s run %d paid ekwan %s/%s, expected %d" \
				% [str(c[0]), int(c[1]), str(out.get("ekwan_awarded")), str(out.get("balance_ekwan")), int(c[2])])
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


## Defeat pays roundi(base x 0.25 x redo), the one consolation. The base is the weight of the
## fought objective (D-13); here the fought objective is the only pre-boss objective.
static func _t_encounter_defeat() -> Dictionary:
	# fought weight -> run_count -> Ase. A defeat pays no Ekwan (D-28).
	var want := {
		0:  { 0: 0, 1: 0 },
		8:  { 0: 2, 1: 2 },
		10: { 0: 3, 1: 2 },
		12: { 0: 3, 1: 3 },
		14: { 0: 4, 1: 3 },
		15: { 0: 4, 1: 3 },
		16: { 0: 4, 1: 4 },
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
	for c in [[true, 1.0], [true, 0.9], [false, 1.0], [false, 0.7]]:
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
## (10), shrine not done, boss stub: base row 10, Ase 10.
static func _t_stage_payer_completed_only() -> Dictionary:
	var env := VentureCharacterizationTests._setup_stage_env("econ_char_completed_only")
	if not bool(env.get("ok", false)):
		return env
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var out := _settle_cell(env, [_obj(0, "combat", true), _obj(1, "shrine", false), boss], 0, 0, 1)
	var mismatches: Array = []
	if _breakdown_delta(out, "Base objectives") != 10 or int(out.get("ase_awarded", -1)) != 10 + _ONE_ECHO_STIPEND:
		mismatches.append("one of two objectives done: base row %d, ase %s, expected 10 / 12" \
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
	if skipped != 10 or done != 18:
		mismatches.append("optional skipped %d (expected 10), done %d (expected 18)" % [skipped, done])
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
	if plain != 0 or pace != 16:
		mismatches.append("first fight: completed-only %d (expected 0), pace base %d (expected 16)" % [plain, pace])
	var second := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], 1)
	pace = ActiveStageService.get_stage_base_reward(second, cfg, null, 0, RewardCalc.MODE_COMPLETED_PLUS_FOUGHT)
	if pace != 26:
		mismatches.append("second fight: pace base %d, expected 26 (16 done + 10 fought)" % pace)
	var none := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], -1)
	pace = ActiveStageService.get_stage_base_reward(none, cfg, null, 0, RewardCalc.MODE_COMPLETED_PLUS_FOUGHT)
	if pace != 16:
		mismatches.append("no fought objective: pace base %d, expected 16" % pace)
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (d) The first defeat of a stage pays 25% of the fought objective's weight, not of the stage sum.
## Fought: shrine (15), after a completed combat (10): roundi(15 x 0.25) = 4 Ase.
static func _t_first_defeat() -> Dictionary:
	var objs: Array = [_obj(0, "combat", true), _obj(1, "shrine", false)]
	var paid := _encounter_pay(objs, false, 0, 1)
	var mismatches: Array = []
	if int(paid["ase_awarded"]) != 4:
		mismatches.append("defeat on the second objective paid %d, expected 4" % int(paid["ase_awarded"]))
	var first := _encounter_pay([_obj(0, "combat", false), _obj(1, "shrine", false)], false, 0, 0)
	if int(first["ase_awarded"]) != 3:
		mismatches.append("first defeat with no completed objective paid %d, expected 3" % int(first["ase_awarded"]))
	var no_objective := _encounter_pay([_obj(0, "combat", true)], false, 0, -1)
	if int(no_objective["ase_awarded"]) != 0:
		mismatches.append("defeat of a non-objective situation paid %d, expected 0" % int(no_objective["ase_awarded"]))
	return { "ok": mismatches.is_empty(), "error": "; ".join(mismatches) }


## (e) Retreat and return-home partials: roundi(completed base x 0.12), 0 before any completion.
## The Scout intel_retention_bonus multiplies that base, so it multiplies 0.
static func _t_partials_completed() -> Dictionary:
	var cfg := _config()
	var factor := float(ConfigService.get_rewards_cfg(cfg).get("partial_intel_reward_factor", 0.12))
	var boss := ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 2, {}, false, false)
	var mismatches: Array = []
	var before := _stage_ctx(cfg, [_obj(0, "guide_spirit", false), _obj(1, "combat", false), boss], 0)
	var base := ActiveStageService.get_stage_base_reward(before, cfg)
	if base != 0 or roundi(float(base) * factor * 1.5) != 0:
		mismatches.append("before any completion: base %d, expected 0" % base)
	var after := _stage_ctx(cfg, [_obj(0, "guide_spirit", true), _obj(1, "combat", false), boss], 1)
	base = ActiveStageService.get_stage_base_reward(after, cfg)
	if base != 16 or roundi(float(base) * factor) != 2:
		mismatches.append("after one completion: base %d partial %d, expected 16 / 2" % [base, roundi(float(base) * factor)])
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
static func _pay(victory: bool, redo: float, eligible: bool = true) -> Dictionary:
	var econ := EconomyService.new({ "economy": { "ase": 0, "ekwan": 0 } })
	return econ.reward_encounter_complete(victory, 10, redo, "B", eligible, _logger(), 1)


static func _t_cause_encounter_rows() -> Dictionary:
	var m: Array = []
	for redo in [0.9, 1.0]:
		var win := _pay(true, redo)
		if int(win["ase_awarded"]) != 0 or not (win["breakdown"] as Array).is_empty():
			m.append("a won fight at redo %s paid %s rows %s" % [str(redo), str(win["ase_awarded"]), JSON.stringify(win["breakdown"])])
	var bd: Array = _pay(false, 0.9)["breakdown"]
	var replay := _row_by_cause(bd, "replay")
	if replay.is_empty() or not is_equal_approx(float((replay.get("params", {}) as Dictionary).get("factor", 0.0)), 0.9):
		m.append("defeat replay row or factor: %s" % JSON.stringify(replay))
	if not _row_by_cause(_pay(false, 1.0)["breakdown"], "replay").is_empty():
		m.append("replay row present at redo 1.0 (run_count 0)")
	var defeat: Array = _pay(false, 0.9)["breakdown"]
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
	var home: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(_scout_ctx(done, 3), 1)["data"]["reward_breakdown"]
	var retreat: Array = VentureResolveSnapshotBuilder.build_scout_return_snapshot(
		_scout_ctx(done, 3), 1, "scout_return", "partial_retreat")["data"]["reward_breakdown"]
	if home.size() != 1 or str((home[0] as Dictionary).get("cause", "")) != "partial_return_home" \
			or int(((home[0] as Dictionary).get("params", {}) as Dictionary).get("overcome", -1)) != 1 \
			or int(((home[0] as Dictionary).get("params", {}) as Dictionary).get("total", -1)) != 2 \
			or int((home[0] as Dictionary).get("delta", -1)) != 3:
		m.append("return-home row: %s" % JSON.stringify(home))
	if retreat.size() != 1 or str((retreat[0] as Dictionary).get("cause", "")) != "partial_retreat":
		m.append("retreat row: %s" % JSON.stringify(retreat))
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
	if RewardCalc.base_reward(objs, cfg) != 10:
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
			float(rd["redo_multiplier"]), str(rd["rank"]), true, _logger(), 1)
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
	# Case 0: combat done, shrine open (base 10, Ekwan 2). Case 1: recover + protect done (Ekwan 8).
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
			# Completed-only base: case 0 pays combat (10) and not the open shrine; case 1 pays 12 + 12.
			var want_base := 10 if case_index == 0 else 24
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
static func _final_card(tag: String, objectives: Array, victory: bool, kill_first_echo: bool = false) -> Dictionary:
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
			"is_objective": true, "objective_index": 0 }],
	}
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
		if int(p.get("overcome", -1)) != 2 or int(p.get("total", -1)) != 2 or int(base.get("delta", -1)) != 25:
			m.append("(a) objectives_overcome row %s, expected 2 of 2 and delta 25" % JSON.stringify(base))
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
		if int(data["stage_payout_ase"]) != 25 + 10:
			m.append("(a) stage_payout_ase %s, expected 35" % str(data["stage_payout_ase"]))
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
		if int(pv.get("ase", -1)) != 10 + int(want[n]):
			m.append("%d home: stage ase %s, expected %d" % [n, str(pv.get("ase")), 10 + int(want[n])])
	return { "ok": m.is_empty(), "error": "; ".join(m) }


## D-53: on a replay the rate stays 2 and the cap falls to 5. The stipend ignores the redo factor.
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
		# base 10 x 0.9 = 9, plus the stipend untouched by the factor.
		if int(pv.get("ase", -1)) != 9 + int(want[n]):
			m.append("%d home on a replay: stage ase %s, expected %d" % [n, str(pv.get("ase")), 9 + int(want[n])])
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
	if paid != int(data.get("stage_payout_ase", -2)) or paid != 25 + 8:
		m.append("flow.complete_stage paid %d, card previewed %s, expected 33" % [paid, str(data.get("stage_payout_ase"))])
	return { "ok": m.is_empty(), "error": "; ".join(m) }
