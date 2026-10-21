# res://tests/EconomyRewardTests.gd
# ECONOMY-004: Tests for RewardCalc + EconomyService.reward_encounter_complete(), and the pace
# rules (PaceService, docs/stories/pace-reward/design.md). Speed pays no Ase (D-49): pace feeds
# the HUD colour and the rank score only. The rank score table lives in econ_char.
#
# Tests 1-12: compute() base, echo bonus, pace fraction, redo multiplier, defeat, rank, payers.
# Tests 13-39: reward/pace_* — par per mode, pace_state, reached enemies, objective_state and
# resolve data per mode, ally kills, GUIDE_SPIRIT escort pace (decisions.md D-31 to D-33).

extends RefCounted
class_name EconomyRewardTests

const _COMBAT := EncounterResolutionModes.COMBAT


# ─── Config helpers ───────────────────────────────────────────────────────────

static func _default_cfg() -> Dictionary:
	return {
		"objective_weights": {
			"combat": 30,
			"shrine": 40,
			"boss":   60,
			# Types the tests do not assert on. A missing key would log the D-07 error.
			"pursue": 8, "recover": 12, "protect": 12, "endure": 14, "guide_spirit": 16,
		},
		"echo_survived_bonus":   10,
		"pace_full_ratio":       1.1,
		"pace_zero_ratio":       1.6,
		"redo_penalty_per_run":  0.10,
		"redo_penalty_floor":    0.50,
		"defeat_factor":         0.25,
		"rank_points": { "win": 0.4, "home": 0.4, "pace": 0.2 },
		"rank_thresholds": {
			"S": 0.90,
			"A": 0.75,
			"B": 0.55,
			"C": 0.35,
			"D": 0.15,
		},
	}


static func _make_save() -> Dictionary:
	return { "economy": { "ase": 0, "ekwan": 0 } }


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("reward/compute_base_only",        Callable(EconomyRewardTests, "_t_compute_base_only"))
	runner.register_test("reward/compute_multi_objectives", Callable(EconomyRewardTests, "_t_compute_multi_objectives"))
	runner.register_test("reward/compute_no_enemy_bonus",   Callable(EconomyRewardTests, "_t_compute_no_enemy_bonus"))
	runner.register_test("reward/compute_echo_bonus",       Callable(EconomyRewardTests, "_t_compute_echo_bonus"))
	runner.register_test("reward/pace_fraction_curve",       Callable(EconomyRewardTests, "_t_pace_fraction_curve"))
	runner.register_test("reward/pace_none_for_no_pace_mode", Callable(EconomyRewardTests, "_t_pace_none_for_no_pace_mode"))
	runner.register_test("reward/redo_multiplier_floor",    Callable(EconomyRewardTests, "_t_redo_multiplier_floor"))
	runner.register_test("reward/redo_multiplier_partial",  Callable(EconomyRewardTests, "_t_redo_multiplier_partial"))
	runner.register_test("reward/defeat_payout",            Callable(EconomyRewardTests, "_t_defeat_payout"))
	runner.register_test("reward/rank_S_first_run",         Callable(EconomyRewardTests, "_t_rank_S_first_run"))
	runner.register_test("reward/rank_F_poor_performance",  Callable(EconomyRewardTests, "_t_rank_F_poor_performance"))
	runner.register_test("reward/economy_service_adds_ase", Callable(EconomyRewardTests, "_t_economy_service_adds_ase"))
	runner.register_test("reward/pace_par_kill_modes",       Callable(EconomyRewardTests, "_t_pace_par_kill_modes"))
	runner.register_test("reward/pace_par_floor_at_one",     Callable(EconomyRewardTests, "_t_pace_par_floor_at_one"))
	runner.register_test("reward/pace_par_recover_nearest_echo", Callable(EconomyRewardTests, "_t_pace_par_recover_nearest_echo"))
	runner.register_test("reward/pace_par_pursue_hold_every_fight", Callable(EconomyRewardTests, "_t_pace_par_pursue_hold_every_fight"))
	runner.register_test("reward/pace_par_zero_for_no_pace_modes", Callable(EconomyRewardTests, "_t_pace_par_zero_for_no_pace_modes"))
	runner.register_test("reward/pace_state_transitions",    Callable(EconomyRewardTests, "_t_pace_state_transitions"))
	runner.register_test("reward/pace_reached_enemies_only_grow", Callable(EconomyRewardTests, "_t_pace_reached_enemies_only_grow"))
	runner.register_test("reward/pace_rank_changed_flag",    Callable(EconomyRewardTests, "_t_pace_rank_changed_flag"))
	runner.register_test("reward/pace_no_breakdown_row",     Callable(EconomyRewardTests, "_t_pace_no_breakdown_row"))
	runner.register_test("reward/pace_objective_state_per_mode", Callable(EconomyRewardTests, "_t_pace_objective_state_per_mode"))
	runner.register_test("reward/pace_resolve_data_combat",  Callable(EconomyRewardTests, "_t_pace_resolve_data_combat"))
	runner.register_test("reward/pace_endure_drive_reached_and_no_pace", Callable(EconomyRewardTests, "_t_pace_endure_drive_reached_and_no_pace"))
	runner.register_test("reward/pace_keeper_intro_no_pace", Callable(EconomyRewardTests, "_t_pace_keeper_intro_no_pace"))
	runner.register_test("reward/pace_party_kill_marks_reached", Callable(EconomyRewardTests, "_t_pace_party_kill_marks_reached"))
	runner.register_test("reward/pace_dead_enemy_not_newly_reached", Callable(EconomyRewardTests, "_t_pace_dead_enemy_not_newly_reached"))
	runner.register_test("reward/pace_ally_kill_sets", Callable(EconomyRewardTests, "_t_pace_ally_kill_sets"))
	runner.register_test("reward/pace_keeper_intro_real_path", Callable(EconomyRewardTests, "_t_pace_keeper_intro_real_path"))
	runner.register_test("reward/pace_runtime_records_reached_and_kills", Callable(EconomyRewardTests, "_t_pace_runtime_records_reached_and_kills"))
	runner.register_test("reward/pace_par_escort_nojoin_e_min", Callable(EconomyRewardTests, "_t_pace_par_escort_nojoin_e_min"))
	runner.register_test("reward/pace_par_escort_joined_is_kill_par", Callable(EconomyRewardTests, "_t_pace_par_escort_joined_is_kill_par"))
	runner.register_test("reward/pace_escort_reward_protect_none", Callable(EconomyRewardTests, "_t_pace_escort_reward_protect_none"))
	runner.register_test("reward/pace_guide_variant_agrees_setup_live_result", Callable(EconomyRewardTests, "_t_pace_guide_variant_agrees_setup_live_result"))
	runner.register_test("reward/pace_guide_spirit_runtime_escort_vs_protect", Callable(EconomyRewardTests, "_t_pace_guide_spirit_runtime_escort_vs_protect"))


# ─── Test 1 — single combat objective → base = 30 ────────────────────────────
static func _t_compute_base_only() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(true, objs, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0)
	if int(result.get("base_reward", -1)) != 30:
		return { "ok": false, "error": "Expected base_reward=30, got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 2 — combat + shrine + boss → base = 130 ────────────────────────────
static func _t_compute_multi_objectives() -> Dictionary:
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2, {}, true),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 3, {}, true),
	]
	var result := RewardCalc.compute(true, objs, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0)
	if int(result.get("base_reward", -1)) != 130:
		return { "ok": false, "error": "Expected base_reward=130 (30+40+60), got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 3 — the enemy count pays nothing (D-40) ─────────────────────────────
static func _t_compute_no_enemy_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(true, objs, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0)
	if result.has("enemy_bonus") or result.has("pace_bonus"):
		return { "ok": false, "error": "compute() still returns a removed bonus: %s" % str(result.keys()) }
	return { "ok": true }


# ─── Test 4 — 2 echoes survived → echo_bonus = 20 ────────────────────────────
static func _t_compute_echo_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(true, objs, 2, 2, 10, 0, _default_cfg(), _COMBAT, 0.0)
	if int(result.get("echo_bonus", -1)) != 20:
		return { "ok": false, "error": "Expected echo_bonus=20 (2×10), got %d" % result.get("echo_bonus", -1) }
	return { "ok": true }


# ─── Test 5 — pace fraction curve; par 10, limits 1.1 / 1.6 ───────────────────
# Full at round <= 11, zero at round >= 16, straight line between. No Ase is paid for it.
static func _t_pace_fraction_curve() -> Dictionary:
	var cases := { 5: 1.0, 11: 1.0, 12: 0.8, 13: 0.6, 15: 0.2, 16: 0.0, 20: 0.0 }
	for rnd in cases:
		var f := PaceService.bonus_fraction(rnd, 10.0, 1.1, 1.6)
		if absf(f - float(cases[rnd])) > 0.0001:
			return { "ok": false, "error": "round %d: expected fraction %f, got %f" % [rnd, cases[rnd], f] }
	if PaceService.bonus_fraction(11, 10.0, 1.1, 1.6) != 1.0 or PaceService.bonus_fraction(16, 10.0, 1.1, 1.6) != 0.0:
		return { "ok": false, "error": "Fraction must be exactly 1.0 at the full limit and 0.0 at the zero limit" }
	if PaceService.bonus_fraction(3, 0.0, 1.1, 1.6) != 0.0:
		return { "ok": false, "error": "par 0 must give fraction 0.0" }
	return { "ok": true }


# ─── Test 6 — no pace for a no-pace mode or a par of 0; a defeat shows no pace_state ──
static func _t_pace_none_for_no_pace_mode() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	for mode in [EncounterResolutionModes.PROTECT, EncounterResolutionModes.ENDURE, EncounterResolutionModes.GUIDE_SPIRIT]:
		var r := RewardCalc.compute(true, objs, 0, 0, 1, 0, _default_cfg(), mode, 10.0)
		if bool(r.get("pace_mode", true)) or str(r.get("pace_state", "x")) != "":
			return { "ok": false, "error": "%s must carry no pace: %s" % [mode, str(r)] }
	var no_par := RewardCalc.compute(true, objs, 0, 0, 1, 0, _default_cfg(), _COMBAT, 0.0)
	if bool(no_par.get("pace_mode", true)):
		return { "ok": false, "error": "par 0 must carry no pace: %s" % str(no_par) }
	var defeat := RewardCalc.compute(false, objs, 0, 0, 1, 0, _default_cfg(), _COMBAT, 10.0)
	if not bool(defeat.get("pace_mode", false)) or str(defeat.get("pace_state", "x")) != "":
		return { "ok": false, "error": "A pace-mode defeat carries no pace_state (design §7): %s" % str(defeat) }
	return { "ok": true }


# ─── Test 7 — run_count=8 → redo_mul clamped to floor 0.50 ──────────────────
static func _t_redo_multiplier_floor() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(true, objs, 0, 0, 10, 8, _default_cfg(), _COMBAT, 0.0)
	var redo := float(result.get("redo_multiplier", -1.0))
	if abs(redo - 0.50) > 0.001:
		return { "ok": false, "error": "Expected redo_multiplier=0.50, got %f" % redo }
	return { "ok": true }


# ─── Test 8 — run_count=3 → redo_mul = 1.0 - 0.3 = 0.70 ────────────────────
static func _t_redo_multiplier_partial() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(true, objs, 0, 0, 10, 3, _default_cfg(), _COMBAT, 0.0)
	var redo := float(result.get("redo_multiplier", -1.0))
	if abs(redo - 0.70) > 0.001:
		return { "ok": false, "error": "Expected redo_multiplier=0.70, got %f" % redo }
	return { "ok": true }


# ─── Test 9 — defeat: total = round(base×0.25×redo_mul) ─────────────────────
static func _t_defeat_payout() -> Dictionary:
	var save   := _make_save()
	var svc    := EconomyService.new(save)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	# base = 30, redo_mul = 1.0 (run_count=0), defeat total = round(30×0.25×1.0) = 8.
	var result := svc.reward_encounter_complete(
		false, 30, 0, 0, 1.0, "F", true, logger, 0
	)
	var expected := roundi(30.0 * 0.25 * 1.0)
	if int(result.get("ase_awarded", -1)) != expected:
		return { "ok": false, "error": "Expected defeat payout=%d, got %d" % [expected, result.get("ase_awarded", -1)] }
	return { "ok": true }


# ─── Test 10 — all home, full pace, run_count=0 → rank = "S" ─────────────────
static func _t_rank_S_first_run() -> Dictionary:
	# score = 0.40 + 0.40 × (5/5) + 0.20 × 1.0 = 1.0 → S. Round 2 of par 10 is full pace.
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2, {}, true),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS, 3, {}, true),
	]
	var result := RewardCalc.compute(true, objs, 5, 5, 2, 0, _default_cfg(), _COMBAT, 10.0)
	if str(result.get("rank", "")) != "S":
		return { "ok": false, "error": "Expected rank=S, got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 11 — defeat + run_count=5 → rank = "F" ────────────────────────────
static func _t_rank_F_poor_performance() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var result := RewardCalc.compute(false, objs, 0, 1, 10, 5, _default_cfg(), _COMBAT, 10.0)
	if str(result.get("rank", "")) != "F":
		return { "ok": false, "error": "Expected rank=F (defeat+run_count=5), got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 12 — the two cadence payers each add their own half to save ────────
## V2-INFRA-003 Phase 8: reward_stage_complete() was ONE payer for two cadences. It is now two,
## and this test pins both halves and their sum. base=30 is the STAGE's summed objective weight
## and is paid by settle_stage_complete(); the 20 echo bonus is THIS fight's and is paid by
## reward_encounter_complete(). Two calls in two dispatches bank 20 + 30 = 50.
static func _t_economy_service_adds_ase() -> Dictionary:
	var save   := _make_save()
	var svc    := EconomyService.new(save)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	# Encounter cadence: 2 echoes home, echo bonus=20, redo=1.0 → 20
	var enc := svc.reward_encounter_complete(
		true, 30, 20, 2, 1.0, "B", true, logger, 0
	)
	if int(enc.get("ase_awarded", -1)) != 20:
		return { "ok": false, "error": "Expected encounter ase_awarded=20, got %d" % enc.get("ase_awarded", -1) }
	if int(save.get("economy", {}).get("ase", -1)) != 20:
		return { "ok": false, "error": "Expected save.economy.ase=20 after the encounter payout, got %d" % int(save.get("economy", {}).get("ase", -1)) }

	# Stage cadence: base=30, redo=1.0 → 30
	var stage := svc.settle_stage_complete(30, 1.0, logger, 0)
	if int(stage.get("ase_awarded", -1)) != 30:
		return { "ok": false, "error": "Expected stage ase_awarded=30, got %d" % stage.get("ase_awarded", -1) }

	var ase_after := int(save.get("economy", {}).get("ase", -1))
	if ase_after != 50:
		return { "ok": false, "error": "Expected save.economy.ase=50 across both cadences, got %d" % ase_after }
	return { "ok": true }


# ─── Pace fixtures ────────────────────────────────────────────────────────────
# Capacity: Standing 1 → 2, Standing 3 → 3. No aptitude term reaches either band.
static func _cap_cfg() -> Dictionary:
	return {
		"floor": 0, "cap": 6, "aptitude_base": 0,
		"agi_threshold_1": 99, "agi_threshold_2": 99,
		"standing_bands": [ {"min_standing": 1, "capacity": 2}, {"min_standing": 3, "capacity": 3} ],
	}


static func _actor(id: String, faction: String, col: int, row: int, extra: Dictionary = {}) -> Dictionary:
	var a: Dictionary = {
		"id": id, "name": id, "faction": faction, "grid_pos": { "col": col, "row": row },
		"standing": 1, "stats": { "agi": 0 }, "is_dead": false,
	}
	a.merge(extra, true)
	return a


## Two party echoes: A (0,0) capacity 2, B (0,2) capacity 3 → mean capacity 2.5.
static func _party() -> Array:
	return [
		_actor("echo_a", "echo", 0, 0),
		_actor("echo_b", "echo", 0, 2, { "standing": 3 }),
	]


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


# ─── Test 13 — kill modes: mean over echoes of the nearest enemy ─────────────
# A→E1 6, B→E1 6 → mean 6 / 2.5 = 2.4. The shrine and a far enemy do not count; neither does a
# joined ally (faction "echo", is_ally) with its own capacity.
static func _t_pace_par_kill_modes() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("enemy_1", "enemy", 6, 0))
	actors.append(_actor("enemy_2", "enemy", 9, 2))
	actors.append(_actor("shrine", "structure", 1, 1, { "is_structure": true }))
	actors.append(_actor("ally", "echo", 8, 0, { "is_ally": true, "standing": 3 }))
	for mode in [EncounterResolutionModes.COMBAT, EncounterResolutionModes.PURIFY_SHRINE]:
		var par := PaceService.compute_par(actors, mode, {}, _cap_cfg())
		if not _near(par, 2.4):
			return { "ok": false, "error": "%s: expected par 2.4, got %f" % [mode, par] }
	return { "ok": true }


# ─── Test 14 — travel_par is clamped to at least 1 and not rounded ────────────
static func _t_pace_par_floor_at_one() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("enemy_1", "enemy", 1, 0))  # A 1, B 2 → mean 1.5 / 2.5 = 0.6 → 1.0
	var par := PaceService.compute_par(actors, EncounterResolutionModes.COMBAT, {}, _cap_cfg())
	if not _near(par, 1.0):
		return { "ok": false, "error": "Expected par clamped to 1.0, got %f" % par }
	var far: Array = _party()
	far.append(_actor("enemy_1", "enemy", 7, 0))  # A 7, B 7 → 7 / 2.5 = 2.8, not rounded
	par = PaceService.compute_par(far, EncounterResolutionModes.COMBAT, {}, _cap_cfg())
	if not _near(par, 2.8):
		return { "ok": false, "error": "Expected unrounded par 2.8, got %f" % par }
	return { "ok": true }


# ─── Test 15 — RECOVER: nearest echo to the relic, plus hold_rounds − 1 ───────
# A→relic 4, B→relic 3 → nearest 3 / 2.5 = 1.2 (a mean would give 1.4); hold 3 → + 2 = 3.2.
static func _t_pace_par_recover_nearest_echo() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("relic", "structure", 3, 4, { "is_structure": true, "is_objective_relic": true }))
	actors.append(_actor("enemy_1", "enemy", 1, 1))
	var par := PaceService.compute_par(actors, EncounterResolutionModes.RECOVER, { "hold_rounds": 3 }, _cap_cfg())
	if not _near(par, 3.2):
		return { "ok": false, "error": "Expected RECOVER par 3.2, got %f" % par }
	return { "ok": true }


# ─── Test 16 — PURSUE: quarry distance, contain_rounds − 1 on every fight ─────
# A→quarry 8, B→quarry 8 → 3.2; contain 3 → + 2 = 5.2. The nearer escort enemy does not count.
# Par is fixed at fight start, so a kill-reason win and a contain-reason win pay against the same
# par (decisions.md D-08).
static func _t_pace_par_pursue_hold_every_fight() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("quarry", "enemy", 8, 0, { "is_quarry": true }))
	actors.append(_actor("escort", "enemy", 1, 0))
	var par := PaceService.compute_par(actors, EncounterResolutionModes.PURSUE, { "contain_rounds": 3 }, _cap_cfg())
	if not _near(par, 5.2):
		return { "ok": false, "error": "Expected PURSUE par 5.2, got %f" % par }
	# Round 5 of par 5.2 is ratio 0.96 → full pace, whatever the win reason.
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var r := RewardCalc.compute(true, objs, 5, 5, 5, 0, _default_cfg(), EncounterResolutionModes.PURSUE, par)
	if str(r.get("pace_state", "")) != PaceService.PACE_FULL:
		return { "ok": false, "error": "Expected full pace at round 5, got %s" % str(r) }
	return { "ok": true }


# ─── Test 17 — no-pace modes get no par ───────────────────────────────────────
static func _t_pace_par_zero_for_no_pace_modes() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("enemy_1", "enemy", 6, 0))
	for mode in [EncounterResolutionModes.PROTECT, EncounterResolutionModes.ENDURE, EncounterResolutionModes.GUIDE_SPIRIT]:
		var par := PaceService.compute_par(actors, mode, { "hold_rounds": 3, "contain_rounds": 3 }, _cap_cfg())
		if par != 0.0:
			return { "ok": false, "error": "%s: expected par 0.0, got %f" % [mode, par] }
	return { "ok": true }


# ─── Test 18 — pace_state per round, par 10: it follows the pace fraction (design §7) ──
# Full to round 11, partial 12-15, none from 16. The stage base plays no part.
static func _t_pace_state_transitions() -> Dictionary:
	for rnd in range(0, 20):
		var expected := PaceService.PACE_FULL
		if rnd >= 16:
			expected = PaceService.PACE_NONE
		elif rnd >= 12:
			expected = PaceService.PACE_PARTIAL
		var got := PaceService.pace_state(rnd, 10.0, 1.1, 1.6)
		if got != expected:
			return { "ok": false, "error": "round %d: expected %s, got %s" % [rnd, expected, got] }
	if PaceService.pace_state(3, 0.0, 1.1, 1.6) != "":
		return { "ok": false, "error": "par 0 must give an empty pace_state" }
	# Result side: the result reports the same state as the live call.
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var r := RewardCalc.compute(true, objs, 0, 0, 15, 0, _default_cfg(), _COMBAT, 10.0)
	if str(r.get("pace_state", "")) != PaceService.PACE_PARTIAL:
		return { "ok": false, "error": "round 15: expected state partial, got %s" % str(r) }
	return { "ok": true }


# ─── Test 19 — reached_enemy_ids only grows, and only in the five reach modes ──
static func _t_pace_reached_enemies_only_grow() -> Dictionary:
	var actors: Array = [
		_actor("echo_a", "echo", 0, 0),
		_actor("echo_dead", "echo", 5, 4, { "is_dead": true }),
		_actor("enemy_1", "enemy", 1, 1),
		_actor("enemy_2", "enemy", 5, 5),
	]
	var cs: Dictionary = CombatState.create(actors, EncounterResolutionModes.ENDURE)
	PaceService.record_reached_enemies(actors, cs)
	if cs["reached_enemy_ids"] != ["enemy_1"]:
		return { "ok": false, "error": "round 1: expected [enemy_1] (a dead echo reaches nobody), got %s" % str(cs["reached_enemy_ids"]) }
	# enemy_1 walks away and dies; a new wave enemy lands adjacent. Nothing is removed.
	actors[2]["grid_pos"] = { "col": 7, "row": 7 }
	actors[2]["is_dead"] = true
	actors.append(_actor("wave_enemy", "enemy", 0, 1))
	PaceService.record_reached_enemies(actors, cs)
	if cs["reached_enemy_ids"] != ["enemy_1", "wave_enemy"]:
		return { "ok": false, "error": "round 2: expected [enemy_1, wave_enemy], got %s" % str(cs["reached_enemy_ids"]) }
	var combat_cs: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT)
	PaceService.record_reached_enemies(actors, combat_cs)
	if not (combat_cs["reached_enemy_ids"] as Array).is_empty():
		return { "ok": false, "error": "COMBAT must not track reached enemies" }
	return { "ok": true }


# ─── Test 21 — pace_changed_rank: true only when the pace points move the grade ─
# 2 started, 1 home: slow 0.60 B, full 0.80 A. 2 home, full: 1.00 S against 0.80 A without pace.
static func _t_pace_rank_changed_flag() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	# [home, round, expected rank, expected flag]; par 20: round 22 is full pace, round 32 is none.
	for c in [[1, 22, "A", true], [1, 32, "B", false], [2, 22, "S", true], [2, 32, "A", false]]:
		var r := RewardCalc.compute(true, objs, c[0], 2, c[1], 0, _default_cfg(), _COMBAT, 20.0)
		if str(r.get("rank", "")) != c[2] or bool(r.get("pace_changed_rank", false)) != c[3]:
			return { "ok": false, "error": "case %s: got %s" % [str(c), str(r)] }
	var none := RewardCalc.compute(true, objs, 1, 2, 5, 0, _default_cfg(), EncounterResolutionModes.ENDURE, 0.0)
	if bool(none.get("pace_changed_rank", true)):
		return { "ok": false, "error": "a no-pace mode must not report a pace rank change" }
	return { "ok": true }


# ─── Test 22 — no breakdown row for pace, win or defeat, pace mode or not ─────
static func _t_pace_no_breakdown_row() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	for victory in [true, false]:
		var res := EconomyService.new(_make_save()).reward_encounter_complete(
			victory, 60, 50, 5, 1.0, "S", true, logger, 0)
		for row in res.get("breakdown", []):
			if str(row.get("label", "")) == "Pace bonus" or str(row.get("cause", "")).begins_with("bonus_"):
				return { "ok": false, "error": "victory=%s: pace row present: %s" % [victory, str(row)] }
	return { "ok": true }


# ─── Test 23 — objective_state carries pace_state iff the mode is a pace mode ──
# Checked before combat.init (combat_state empty, read from ectx.pace_cfg) and after it.
static func _t_pace_objective_state_per_mode() -> Dictionary:
	var modes := [
		[EncounterResolutionModes.COMBAT, {}, true],
		[EncounterResolutionModes.PURIFY_SHRINE, {}, true],
		[EncounterResolutionModes.RECOVER, { "hold_rounds": 3 }, true],
		[EncounterResolutionModes.PURSUE, { "contain_rounds": 3 }, true],
		[EncounterResolutionModes.PROTECT, {}, false],
		[EncounterResolutionModes.ENDURE, {}, false],
		[EncounterResolutionModes.GUIDE_SPIRIT, { "guide_mode": "protect" }, false],
		[EncounterResolutionModes.GUIDE_SPIRIT, { "guide_mode": "escort" }, true],
	]
	for m in modes:
		var actors: Array = _party()
		actors.append(_actor("enemy_1", "enemy", 6, 0, { "is_quarry": m[0] == EncounterResolutionModes.PURSUE }))
		actors.append(_actor("relic", "structure", 3, 4, { "is_structure": true, "is_objective_relic": true }))
		var ectx := EncounterContext.new()
		ectx.resolution_mode = m[0]
		ectx.actors = actors
		ectx.objective_params = m[1]
		var par := PaceService.compute_par(actors, m[0], m[1], _cap_cfg())
		if par > 0.0:
			ectx.pace_cfg = { "par_rounds": par, "pace_full_ratio": 1.1, "pace_zero_ratio": 1.6 }
		var pre: Dictionary = EncounterSnapshotBuilder._build_objective_state(ectx, {})
		var cs: Dictionary = CombatState.create(actors, m[0], 0, {}, m[1], {}, ectx.pace_cfg)
		cs["round_counter"] = 1
		var live: Dictionary = EncounterSnapshotBuilder._build_objective_state(ectx, cs)
		for os in [pre, live]:
			if os.has("pace_state") != m[2]:
				return { "ok": false, "error": "%s %s: pace_state present=%s, expected %s" % [m[0], str(m[1]), os.has("pace_state"), m[2]] }
			if m[2] and str(os["pace_state"]) != PaceService.PACE_FULL:
				return { "ok": false, "error": "%s: expected pace_state full at round 0-1, got %s" % [m[0], os["pace_state"]] }
			if os.has("par_rounds") or os.has("pace_ratio"):
				return { "ok": false, "error": "%s: raw pace floats must stay out of the snapshot" % m[0] }
	return { "ok": true }


# ─── Test 24 — real COMBAT fight: resolve data and objective_state agree ───────
static func _t_pace_resolve_data_combat() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "pace_combat")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var ectx: EncounterContext = env["ectx"]
	if float(ectx.pace_cfg.get("par_rounds", 0.0)) < 1.0:
		return { "ok": false, "error": "COMBAT setup must set par_rounds >= 1, got %s" % str(ectx.pace_cfg) }
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(env["runtime"], ectx, 30)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "fight did not end in 30 rounds" }
	var data: Dictionary = (env["flow_ctx"] as FlowContext).last_snapshot.get("data", {})
	var state := str(data.get("pace_state", ""))
	if not state in [PaceService.PACE_FULL, PaceService.PACE_PARTIAL, PaceService.PACE_NONE]:
		return { "ok": false, "error": "resolve pace_state missing or invalid: '%s'" % state }
	if str((data.get("objective_state", {}) as Dictionary).get("pace_state", "")) != state:
		return { "ok": false, "error": "objective_state.pace_state must equal the final pace_state" }
	if not data.has("pace_changed_rank") or data.has("pace_bonus_awarded"):
		return { "ok": false, "error": "resolve data needs pace_changed_rank and no pace_bonus_awarded: %s" % str(data.keys()) }
	if not bool(data.get("victory", false)):
		return { "ok": false, "error": "fixture must be a win for this test" }
	var rows: Array = (data.get("reward_breakdown", []) as Array).filter(
		func(r): return str(r.get("label", "")) == "Pace bonus")
	if not rows.is_empty():
		return { "ok": false, "error": "speed pays no Ase, but a Pace bonus row exists: %s" % str(rows) }
	# Same fight re-read as a defeat: the result shows nothing about pace (design §7).
	ectx.combat_result["victory"] = false
	var lost: Dictionary = FlowEncounterState.build_final_snapshot(env["flow_ctx"], 0).get("data", {})
	for key in ["pace_state", "pace_bonus_awarded", "pace_changed_rank"]:
		if lost.has(key):
			return { "ok": false, "error": "defeat result data must not carry %s" % key }
	if (lost.get("objective_state", {}) as Dictionary).has("pace_state"):
		return { "ok": false, "error": "defeat objective_state must not carry pace_state" }
	for row in lost.get("reward_breakdown", []):
		if str(row.get("label", "")) == "Pace bonus":
			return { "ok": false, "error": "defeat must not show a Pace bonus row" }
	return { "ok": true }


# ─── Test 26 — the keeper-intro trial is a no-pace fight (design §7) ─────
static func _t_pace_keeper_intro_no_pace() -> Dictionary:
	for enc_id in ["keeper_intro.first_trial", "realm.test.stage.0.combat"]:
		var flow_ctx := FlowContext.new()
		flow_ctx.encounter_ctx = EncounterContext.new()
		flow_ctx.encounter_ctx.encounter_id = enc_id
		flow_ctx.encounter_ctx.resolution_mode = _COMBAT
		var actors: Array = _party()
		actors.append(_actor("enemy_1", "enemy", 6, 0))
		flow_ctx.encounter_ctx.actors = actors
		EncounterSetupService.new(flow_ctx)._setup_pace(0)
		var is_intro: bool = enc_id == "keeper_intro.first_trial"
		if flow_ctx.encounter_ctx.pace_cfg.is_empty() != is_intro:
			return { "ok": false, "error": "%s: pace_cfg=%s" % [enc_id, str(flow_ctx.encounter_ctx.pace_cfg)] }
		var os: Dictionary = EncounterSnapshotBuilder._build_objective_state(flow_ctx.encounter_ctx, {})
		if os.has("pace_state") == is_intro:
			return { "ok": false, "error": "%s: pace_state present=%s" % [enc_id, os.has("pace_state")] }
	return { "ok": true }


# ─── Test 25 — real ENDURE fight: reached ids only grow across waves; no pace data ──
static func _t_pace_endure_drive_reached_and_no_pace() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.ENDURE, "pace_endure")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })
	var previous: Array = []
	for _r in range(30):
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard := 0
		while guard < 40 and str(ectx.combat_state.get("round_phase", "")) == "in_round" \
				and not bool(ectx.combat_state.get("combat_over", false)):
			guard += 1
			runtime.dispatch({ "type": "combat.next_actor" })
		var now: Array = (ectx.combat_state.get("reached_enemy_ids", []) as Array).duplicate()
		if now.slice(0, previous.size()) != previous:
			return { "ok": false, "error": "reached_enemy_ids lost or reordered an id: %s -> %s" % [str(previous), str(now)] }
		previous = now
		if bool(ectx.combat_state.get("combat_over", false)):
			break
	if int(ectx.combat_state.get("waves_spawned", 0)) < 1:
		return { "ok": false, "error": "fixture spawned no ENDURE wave — the test proves nothing" }
	if float(ectx.combat_state.get("par_rounds", -1.0)) != 0.0:
		return { "ok": false, "error": "ENDURE must have par_rounds 0.0" }
	var data: Dictionary = (env["flow_ctx"] as FlowContext).last_snapshot.get("data", {})
	for key in ["pace_state", "pace_bonus_awarded", "pace_changed_rank"]:
		if data.has(key):
			return { "ok": false, "error": "ENDURE resolve data must not carry %s" % key }
	if (data.get("objective_state", {}) as Dictionary).has("pace_state"):
		return { "ok": false, "error": "ENDURE objective_state must not carry pace_state" }
	for row in data.get("reward_breakdown", []):
		if str(row.get("label", "")) == "Pace bonus":
			return { "ok": false, "error": "ENDURE must not show a Pace bonus row" }
	return { "ok": true }


# ─── Test 29 — a party-echo kill marks the enemy reached, also when that echo is dead ──
static func _t_pace_party_kill_marks_reached() -> Dictionary:
	var actors: Array = [
		# The killer died later in the same round and stands far from the enemy's cell.
		_actor("echo_a", "echo", 0, 0, { "is_dead": true }),
		_actor("echo_b", "echo", 0, 9),
		_actor("enemy_1", "enemy", 7, 7, { "is_dead": true }),
	]
	var cs: Dictionary = CombatState.create(actors, EncounterResolutionModes.PURSUE)
	PaceService.record_kill({ "action_type": "melee_attack", "attacker_id": "echo_a",
		"target_id": "enemy_1", "is_kill": true }, actors, cs)
	PaceService.record_reached_enemies(actors, cs)
	if cs["reached_enemy_ids"] != ["enemy_1"] or not (cs["ally_killed_enemy_ids"] as Array).is_empty():
		return { "ok": false, "error": "expected reached [enemy_1], got %s / %s" % [str(cs["reached_enemy_ids"]), str(cs["ally_killed_enemy_ids"])] }
	# A non-kill hit and a non-melee result record nothing.
	actors.append(_actor("enemy_2", "enemy", 9, 9))
	PaceService.record_kill({ "action_type": "melee_attack", "attacker_id": "echo_b",
		"target_id": "enemy_2", "is_kill": false }, actors, cs)
	PaceService.record_kill({ "action_type": "actor.move", "attacker_id": "echo_b",
		"target_id": "enemy_2", "is_kill": false }, actors, cs)
	if cs["reached_enemy_ids"] != ["enemy_1"]:
		return { "ok": false, "error": "a non-kill must not mark reached: %s" % str(cs["reached_enemy_ids"]) }
	return { "ok": true }


# ─── Test 30 — a dead enemy is not checked at its last cell (QA defect 4) ─────
static func _t_pace_dead_enemy_not_newly_reached() -> Dictionary:
	var actors: Array = [
		_actor("echo_a", "echo", 0, 0),
		# Died without a party kill (for example a hazard), next to a living echo.
		_actor("enemy_1", "enemy", 1, 0, { "is_dead": true }),
		_actor("enemy_2", "enemy", 1, 1),
	]
	var cs: Dictionary = CombatState.create(actors, EncounterResolutionModes.ENDURE)
	PaceService.record_reached_enemies(actors, cs)
	if cs["reached_enemy_ids"] != ["enemy_2"]:
		return { "ok": false, "error": "expected [enemy_2] only, got %s" % str(cs["reached_enemy_ids"]) }
	return { "ok": true }


# ─── Test 31 — an ally or spirit kill goes to the ally set; a party kill marks reached ──
static func _t_pace_ally_kill_sets() -> Dictionary:
	# record_kill sorts the killers: ally and spirit go to the ally set in every mode.
	var actors: Array = [
		_actor("echo_a", "echo", 0, 0),
		_actor("ally", "echo", 0, 1, { "is_ally": true }),
		_actor("spirit", "echo", 0, 2, { "is_spirit": true }),
		_actor("enemy_1", "enemy", 1, 0, { "is_dead": true }),
		_actor("enemy_2", "enemy", 1, 1, { "is_dead": true }),
		_actor("enemy_3", "enemy", 1, 2, { "is_dead": true }),
	]
	for mode in [EncounterResolutionModes.COMBAT, EncounterResolutionModes.ENDURE]:
		var cs: Dictionary = CombatState.create(actors, mode)
		PaceService.record_kill({ "action_type": "melee_attack", "attacker_id": "echo_a", "target_id": "enemy_1", "is_kill": true }, actors, cs)
		PaceService.record_kill({ "action_type": "melee_attack", "attacker_id": "ally", "target_id": "enemy_2", "is_kill": true }, actors, cs)
		PaceService.record_kill({ "action_type": "melee_attack", "attacker_id": "spirit", "target_id": "enemy_3", "is_kill": true }, actors, cs)
		if cs["ally_killed_enemy_ids"] != ["enemy_2", "enemy_3"]:
			return { "ok": false, "error": "%s: ally set %s" % [mode, str(cs["ally_killed_enemy_ids"])] }
		var expect_reached: Array = ["enemy_1"] if mode == EncounterResolutionModes.ENDURE else []
		if cs["reached_enemy_ids"] != expect_reached:
			return { "ok": false, "error": "%s: reached %s" % [mode, str(cs["reached_enemy_ids"])] }

	# reached [e1, e2], the party killed e1, the ally killed the REACHED e2: the set difference is 1.
	var ecs: Dictionary = { "reached_enemy_ids": ["e1", "e2"], "ally_killed_enemy_ids": ["e2"] }
	if PaceService.rank_reached_count(ecs) != 1:
		return { "ok": false, "error": "set difference: expected 1, got %d" % PaceService.rank_reached_count(ecs) }
	# An ally kill of an enemy that never reached is subtracted once only.
	var once: Dictionary = { "reached_enemy_ids": ["e1"], "ally_killed_enemy_ids": ["e2"] }
	if PaceService.rank_reached_count(once) != 1:
		return { "ok": false, "error": "an unreached ally kill must not lower the reached count" }
	return { "ok": true }


# ─── Test 33 — the real keeper-intro path carries no pace data (decisions.md D-18) ──
# KeeperIntroService.setup_trial_encounter() builds its own encounter context, not through
# EncounterSetupService._setup_pace(). Drive it through the real dispatches.
static func _t_pace_keeper_intro_real_path() -> Dictionary:
	var runtime := OnboardingTests._prepare_named_runtime()
	runtime.dispatch({ "type": "keeper_intro.call.answer" })
	var ectx: EncounterContext = runtime.flow_ctx.encounter_ctx
	if ectx == null or ectx.encounter_id != "keeper_intro.first_trial":
		return { "ok": false, "error": "keeper trial encounter not set up" }
	if not ectx.pace_cfg.is_empty():
		return { "ok": false, "error": "keeper trial pace_cfg must be empty, got %s" % str(ectx.pace_cfg) }
	runtime.dispatch({ "type": "combat.init" })
	if float(ectx.combat_state.get("par_rounds", -1.0)) != 0.0:
		return { "ok": false, "error": "keeper trial par_rounds must be 0.0" }
	runtime.dispatch({ "type": "combat.confirm_round" })
	var snaps: Array = [runtime.flow_ctx.last_snapshot]
	OnboardingTests._defeat_trial_wound(runtime)
	ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 1 }
	ectx.combat_state["combat_over"] = true
	snaps.append(FlowEncounterState.build_final_snapshot(runtime.flow_ctx, 7))
	for snap in snaps:
		var data: Dictionary = (snap as Dictionary).get("data", {})
		if not data.has("objective_state"):
			return { "ok": false, "error": "%s: expected an objective_state to check" % str(snap.get("type", "")) }
		if (data["objective_state"] as Dictionary).has("pace_state"):
			return { "ok": false, "error": "%s: objective_state must not carry pace_state" % str(snap.get("type", "")) }
		for key in ["pace_state", "pace_bonus_awarded", "pace_changed_rank"]:
			if data.has(key):
				return { "ok": false, "error": "%s: data must not carry %s" % [str(snap.get("type", "")), key] }
		for row in data.get("reward_breakdown", []):
			if str(row.get("label", "")) == "Pace bonus":
				return { "ok": false, "error": "keeper trial must not show a Pace bonus row" }
	return { "ok": true }


# ─── Test 34 — the runtime records reached enemies and kills (decisions.md D-23) ──
# Drives real fights through FlowRuntime. The test checks the combat_state sets that
# FlowRuntime writes through PaceService.record_kill() and PaceService.record_reached_enemies().
# Each fight must show evidence, so an empty set cannot pass:
#   1. Adjacency evidence: a living enemy is next to a living party echo at round end, and it
#      was not in reached_enemy_ids before that round. Only record_reached_enemies() adds it.
#   2. Kill evidence: a party echo kills an enemy that was not in reached_enemy_ids before
#      that dispatch. The enemy is dead at round end, so only record_kill() adds it.
static func _t_pace_runtime_records_reached_and_kills() -> Dictionary:
	# (a) Adjacency. On these fixture seeds no party echo kills an enemy.
	for f in [[EncounterResolutionModes.ENDURE, "pace_endure"],
			[EncounterResolutionModes.PURSUE, "pace_pursue"],
			[EncounterResolutionModes.PROTECT, "pace_protect"]]:
		var r := _drive_reach_fight(f[0], f[1], false)
		if not str(r["error"]).is_empty():
			return { "ok": false, "error": "%s: %s" % [f[0], r["error"]] }
		if (r["adjacent"] as Array).is_empty():
			return { "ok": false, "error": "%s: no enemy became reached by adjacency; the test proves nothing" % f[0] }
	# (b) Kill. Every enemy starts the fight with 1 HP, so the first party hit kills.
	# On this seed a party echo kills pursue_quarry_01 in the round of first contact.
	var k := _drive_reach_fight(EncounterResolutionModes.PURSUE, "pace_pursue", true)
	if not str(k["error"]).is_empty():
		return { "ok": false, "error": "pursue, weak enemies: %s" % k["error"] }
	if (k["killed"] as Array).is_empty():
		return { "ok": false, "error": "pursue, weak enemies: no party kill of an unreached enemy; the test proves nothing" }
	return { "ok": true }


## Drives one fight to its end. Returns { error, adjacent, killed }: error is "" or the first
## failed check; adjacent and killed hold the ids of the evidence (see Test 34).
## weak_enemies sets every enemy to 1 HP after combat.init.
static func _drive_reach_fight(mode: String, seed_tag: String, weak_enemies: bool) -> Dictionary:
	var out := { "error": "", "adjacent": [], "killed": [] }
	var env: Dictionary = FlowFingerprintTests._setup_encounter(mode, seed_tag)
	if env.is_empty():
		out["error"] = "setup failed"
		return out
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })
	if weak_enemies:
		for a in ectx.actors:
			if str(a.get("faction", "")) == "enemy" and not bool(a.get("is_structure", false)):
				a["current_hp"] = 1
	var cs: Dictionary = ectx.combat_state
	for _r in range(40):
		var round_start: Array = (ectx.combat_state.get("reached_enemy_ids", []) as Array).duplicate()
		var first := true
		var guard := 0
		while guard < 60:
			guard += 1
			var before: Array = (ectx.combat_state.get("reached_enemy_ids", []) as Array).duplicate()
			var from := 0 if first else ectx.last_round_results.size()
			runtime.dispatch({ "type": "combat.confirm_round" if first else "combat.next_actor" })
			first = false
			cs = ectx.combat_state
			var err := _check_kills(ectx, from, before, out["killed"])
			if not err.is_empty():
				out["error"] = err
				return out
			if str(cs.get("round_phase", "")) != "in_round" or bool(cs.get("combat_over", false)):
				break
		if bool(cs.get("combat_over", false)):
			break
		var err2 := _check_round_end_adjacency(ectx, round_start, out["adjacent"])
		if not err2.is_empty():
			out["error"] = err2
			return out
	return out


## Every party-echo melee kill of an enemy in the new results must be in reached_enemy_ids.
## Every ally or spirit melee kill of an enemy must be in ally_killed_enemy_ids.
static func _check_kills(ectx: EncounterContext, from: int, before: Array, evidence: Array) -> String:
	var cs: Dictionary = ectx.combat_state
	for i in range(from, ectx.last_round_results.size()):
		var res: Dictionary = ectx.last_round_results[i]
		if str(res.get("action_type", "")) != "melee_attack" or not bool(res.get("is_kill", false)):
			continue
		var target := EncounterContext.find_actor_by_id(ectx.actors, str(res.get("target_id", "")))
		var killer := EncounterContext.find_actor_by_id(ectx.actors, str(res.get("attacker_id", "")))
		if str(target.get("faction", "")) != "enemy" or bool(target.get("is_structure", false)):
			continue
		var enemy_id := str(target.get("id", ""))
		if bool(killer.get("is_ally", false)) or bool(killer.get("is_spirit", false)):
			if not enemy_id in (cs.get("ally_killed_enemy_ids", []) as Array):
				return "ally kill of %s is not in ally_killed_enemy_ids" % enemy_id
		elif str(killer.get("faction", "")) == "echo":
			if not enemy_id in (cs.get("reached_enemy_ids", []) as Array):
				return "party kill of %s by %s is not in reached_enemy_ids %s" % [
					enemy_id, str(killer.get("id", "")), str(cs.get("reached_enemy_ids", []))]
			if not enemy_id in before:
				evidence.append(enemy_id)
	return ""


## At round end, every living enemy within Chebyshev 1 of a living party echo is reached.
static func _check_round_end_adjacency(ectx: EncounterContext, round_start: Array, evidence: Array) -> String:
	var reached: Array = ectx.combat_state.get("reached_enemy_ids", [])
	for e in ectx.actors:
		if str(e.get("faction", "")) != "enemy" or bool(e.get("is_structure", false)) or bool(e.get("is_dead", false)):
			continue
		for p in ectx.actors:
			if str(p.get("faction", "")) != "echo" or bool(p.get("is_dead", false)) \
					or bool(p.get("is_ally", false)) or bool(p.get("is_spirit", false)):
				continue
			if GridService.chebyshev_distance(e.get("grid_pos", {}), p.get("grid_pos", {})) > 1:
				continue
			var enemy_id := str(e.get("id", ""))
			if not enemy_id in reached:
				return "round %d: %s is next to %s but not in reached_enemy_ids %s" % [
					int(ectx.combat_state.get("round_counter", 0)), enemy_id, str(p.get("id", "")), str(reached)]
			if not enemy_id in round_start and not enemy_id in evidence:
				evidence.append(enemy_id)
			break
	return ""


# ─── GUIDE_SPIRIT escort pace (decisions.md D-31, D-32, D-33) ─────────────────
## Party A (0,0) cap 2, B (0,2) cap 3 → mean 2.5. Spirit at (4,6), destination (4,13).
static func _escort_params(joins: bool) -> Dictionary:
	return { "guide_mode": "escort", "spirit_joins_battle": joins,
		"destination_col": 4, "destination_row": 13 }


# ─── Test 35 — non-joined escort par, E-min (D-33) ────────────────────────────
# Nearest echo→spirit: A 6, B 4 → (4 − 1) / 2.5 = 1.2 (a mean would give 1.6).
# Spirit→destination 7 / spirit capacity 1 = 7. Par 8.2, no hold term.
# The near enemy, the adjacent Temporary Ally and the hold params do not count.
static func _t_pace_par_escort_nojoin_e_min() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("spirit", "structure", 4, 6, { "is_structure": true, "is_spirit": true }))
	actors.append(_actor("enemy_1", "enemy", 1, 0))
	actors.append(_actor("ally", "echo", 4, 5, { "is_ally": true, "standing": 3 }))
	var params := _escort_params(false)
	params["hold_rounds"] = 3
	params["contain_rounds"] = 3
	var par := PaceService.compute_par(actors, EncounterResolutionModes.GUIDE_SPIRIT, params, _cap_cfg())
	if not _near(par, 8.2):
		return { "ok": false, "error": "Expected escort E-min par 8.2, got %f" % par }
	# An echo next to a spirit that stands on its destination: max(1, 0 + 0) = 1.
	var close: Array = [_actor("echo_a", "echo", 3, 6),
		_actor("spirit", "structure", 4, 6, { "is_structure": true, "is_spirit": true })]
	var at_dest := { "guide_mode": "escort", "spirit_joins_battle": false,
		"destination_col": 4, "destination_row": 6 }
	par = PaceService.compute_par(close, EncounterResolutionModes.GUIDE_SPIRIT, at_dest, _cap_cfg())
	if not _near(par, 1.0):
		return { "ok": false, "error": "Expected escort par clamped to 1.0, got %f" % par }
	# Column 0 and row 0 are valid destinations (the board edge). The echo is adjacent, so only
	# the spirit walk counts: 4 cells to col 0, 6 cells to row 0 (QA finding F1).
	for edge in [[0, 6, 4.0], [4, 0, 6.0]]:
		var edge_dest := { "guide_mode": "escort", "spirit_joins_battle": false,
			"destination_col": edge[0], "destination_row": edge[1] }
		par = PaceService.compute_par(close, EncounterResolutionModes.GUIDE_SPIRIT, edge_dest, _cap_cfg())
		if not _near(par, edge[2]):
			return { "ok": false, "error": "Expected escort par %f for destination (%d, %d), got %f" % [edge[2], edge[0], edge[1], par] }
	return { "ok": true }


# ─── Test 36 — joined escort par is the kill-mode party travel par (D-32) ─────
# Same party and enemy as Test 13: par 2.4. The joined spirit (faction echo, is_spirit,
# capacity 3) is not party: counted, it would give 1.625.
static func _t_pace_par_escort_joined_is_kill_par() -> Dictionary:
	var actors: Array = _party()
	actors.append(_actor("enemy_1", "enemy", 6, 0))
	actors.append(_actor("spirit", "echo", 5, 0, { "is_spirit": true, "standing": 3 }))
	var escort := PaceService.compute_par(actors, EncounterResolutionModes.GUIDE_SPIRIT,
		_escort_params(true), _cap_cfg())
	var combat := PaceService.compute_par(actors, _COMBAT, {}, _cap_cfg())
	if not _near(escort, 2.4) or not _near(escort, combat):
		return { "ok": false, "error": "Expected joined escort par 2.4 = COMBAT par, got %f / %f" % [escort, combat] }
	for joins in [false, true]:
		var protect := { "guide_mode": "protect", "spirit_joins_battle": joins }
		var p := PaceService.compute_par(actors, EncounterResolutionModes.GUIDE_SPIRIT, protect, _cap_cfg())
		if p != 0.0:
			return { "ok": false, "error": "GUIDE_SPIRIT protect must have par 0.0, got %f" % p }
	return { "ok": true }


# ─── Test 37 — escort carries pace; protect and a defeat carry none; no Ase for it ──
static func _t_pace_escort_reward_protect_none() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	var gs := EncounterResolutionModes.GUIDE_SPIRIT
	# [victory, guide_mode, expected pace_mode, expected state]
	var cases := [
		[true, "escort", true, PaceService.PACE_FULL],
		[false, "escort", true, ""],
		[true, "protect", false, ""],
	]
	for c in cases:
		var r := RewardCalc.compute(c[0], objs, 5, 5, 5, 0, _default_cfg(), gs, 8.2, c[1])
		if bool(r.get("pace_mode", false)) != c[2] or str(r.get("pace_state", "x")) != c[3]:
			return { "ok": false, "error": "case %s: got %s" % [str(c), str(r)] }
		var res := EconomyService.new(_make_save()).reward_encounter_complete(c[0], 60,
			int(r["echo_bonus"]), 5, 1.0, str(r["rank"]), true, logger, 0)
		for row in res.get("breakdown", []):
			if str(row.get("label", "")) == "Pace bonus":
				return { "ok": false, "error": "case %s: a Pace bonus row exists: %s" % [str(c), str(row)] }
	return { "ok": true }


# ─── Test 38 — setup, live snapshot and result agree on escort vs protect ─────
static func _t_pace_guide_variant_agrees_setup_live_result() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1, {}, true)]
	for guide_mode in ["escort", "protect"]:
		var expected: bool = guide_mode == "escort"
		var flow_ctx := FlowContext.new()
		var ectx := EncounterContext.new()
		flow_ctx.encounter_ctx = ectx
		ectx.encounter_id = "realm.test.stage.0.guide"
		ectx.resolution_mode = EncounterResolutionModes.GUIDE_SPIRIT
		ectx.objective_params = _escort_params(false)
		ectx.objective_params["guide_mode"] = guide_mode
		var actors: Array = _party()
		actors.append(_actor("spirit", "structure", 4, 6, { "is_structure": true, "is_spirit": true }))
		ectx.actors = actors
		EncounterSetupService.new(flow_ctx)._setup_pace(0)
		if ectx.pace_cfg.is_empty() == expected:
			return { "ok": false, "error": "%s: setup pace_cfg=%s" % [guide_mode, str(ectx.pace_cfg)] }
		var cs: Dictionary = CombatState.create(actors, ectx.resolution_mode, 0, {}, ectx.objective_params, {}, ectx.pace_cfg)
		cs["round_counter"] = 1
		for os in [EncounterSnapshotBuilder._build_objective_state(ectx, {}),
				EncounterSnapshotBuilder._build_objective_state(ectx, cs)]:
			if os.has("pace_state") != expected:
				return { "ok": false, "error": "%s: live pace_state present=%s" % [guide_mode, os.has("pace_state")] }
		var r := RewardCalc.compute(true, objs, 5, 5, 1, 0, _default_cfg(), ectx.resolution_mode,
			float(cs.get("par_rounds", 0.0)), str(cs.get("guide_mode", "")))
		if bool(r.get("pace_mode", false)) != expected:
			return { "ok": false, "error": "%s: result pace_mode=%s" % [guide_mode, str(r.get("pace_mode"))] }
	return { "ok": true }


# ─── Test 39 — real GUIDE_SPIRIT fights through FlowRuntime ───────────────────
# Escort (both join states) sets par and a live pace_state; protect sets neither. The result
# agrees: a win carries pace_state, a defeat carries none, and no fight shows a Pace bonus row.
static func _t_pace_guide_spirit_runtime_escort_vs_protect() -> Dictionary:
	var escort_wins := 0
	for f in [["escort", "nojoin", true], ["escort", "join", true], ["protect", "nojoin", false]]:
		var env: Dictionary = FlowFingerprintTests._setup_encounter(
			EncounterResolutionModes.GUIDE_SPIRIT, "pace_guide_%s_%s" % [f[0], f[1]], f[0], f[1])
		if env.is_empty():
			return { "ok": false, "error": "%s: setup failed" % str(f) }
		var runtime: FlowRuntime = env["runtime"]
		var flow_ctx: FlowContext = env["flow_ctx"]
		var ectx: EncounterContext = env["ectx"]
		if str(ectx.objective_params.get("guide_mode", "")) != f[0]:
			return { "ok": false, "error": "%s: fixture rolled guide_mode %s" % [str(f), ectx.objective_params.get("guide_mode")] }
		runtime.dispatch({ "type": "combat.init" })
		var par := float(ectx.combat_state.get("par_rounds", -1.0))
		if (par > 0.0) != f[2] or (not f[2] and par != 0.0):
			return { "ok": false, "error": "%s: par_rounds %f" % [str(f), par] }
		if f[0] == "escort" and f[1] == "join":
			# combat.init moves no actor, so ectx.actors still hold the fight-start cells.
			var cap_cfg: Dictionary = flow_ctx.config_service.get_balance().get("data", {}).get(
				"combat", {}).get("movement", {}).get("capacity", {})
			var kill_par := PaceService.compute_par(ectx.actors, _COMBAT, {}, cap_cfg)
			if not _near(par, kill_par):
				return { "ok": false, "error": "joined escort par %f != COMBAT-style par %f" % [par, kill_par] }
		var saw_live := false
		for _r in range(30):
			runtime.dispatch({ "type": "combat.confirm_round" })
			var guard := 0
			while guard < 60 and str(ectx.combat_state.get("round_phase", "")) == "in_round" \
					and not bool(ectx.combat_state.get("combat_over", false)):
				guard += 1
				runtime.dispatch({ "type": "combat.next_actor" })
			if bool(ectx.combat_state.get("combat_over", false)):
				break
			var live: Dictionary = (flow_ctx.last_snapshot.get("data", {}) as Dictionary).get("objective_state", {})
			if live.has("pace_state") != f[2]:
				return { "ok": false, "error": "%s: live pace_state present=%s" % [str(f), live.has("pace_state")] }
			saw_live = true
		if not saw_live:
			return { "ok": false, "error": "%s: the fight ended before a live snapshot; the test proves nothing" % str(f) }
		if not bool(ectx.combat_state.get("combat_over", false)):
			return { "ok": false, "error": "%s: fight did not end in 30 rounds" % str(f) }
		var data: Dictionary = flow_ctx.last_snapshot.get("data", {})
		var win := bool(data.get("victory", false))
		var expect_pace: bool = f[2] and win
		var rows: Array = (data.get("reward_breakdown", []) as Array).filter(
			func(row): return str(row.get("label", "")) == "Pace bonus")
		if data.has("pace_state") != expect_pace or not rows.is_empty():
			return { "ok": false, "error": "%s win=%s: resolve pace_state=%s rows=%s" % [
				str(f), win, str(data.get("pace_state", "")), str(rows)] }
		if expect_pace:
			escort_wins += 1
	if escort_wins == 0:
		return { "ok": false, "error": "no escort fixture won; the result half proves nothing" }
	return { "ok": true }
