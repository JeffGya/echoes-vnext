# res://tests/EconomyRewardTests.gd
# ECONOMY-004: Tests for RewardCalc + EconomyService.reward_encounter_complete(), and the pace
# bonus rules (PaceService, docs/stories/pace-reward/design.md).
#
# Tests:
#   1.  reward/compute_base_only             — single combat obj → base = 30
#   2.  reward/compute_multi_objectives      — combat + shrine + boss → base = 130
#   3.  reward/compute_enemy_bonus           — 3 enemies → enemy_bonus = 15
#   4.  reward/compute_echo_bonus            — 2 echoes → echo_bonus = 20
#   5.  reward/pace_bonus_curve              — full / partial / zero at and around both limits
#   6.  reward/pace_bonus_zero_no_pace_mode  — no-pace mode or defeat → pace_bonus = 0
#   7.  reward/redo_multiplier_floor         — run_count=8 → redo_mul = 0.50
#   8.  reward/redo_multiplier_partial       — run_count=3 → redo_mul = 0.70
#   9.  reward/defeat_payout                 — defeat: total = round(base×0.25×redo_mul)
#   10. reward/rank_S_first_run              — perfect score + run_count=0 → rank = "S"
#   11. reward/rank_F_poor_performance       — poor perf + run_count=5 → rank = "F"
#   12. reward/economy_service_adds_ase      — both cadence payers add the correct amount
#   13-27. reward/pace_*                     — par per mode, pace_state, reached enemies, rank
#          ceiling, the "Pace bonus" row, objective_state and resolve data per mode

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
		},
		"enemy_defeated_bonus":  5,
		"echo_survived_bonus":   10,
		"pace_full_ratio":       1.1,
		"pace_zero_ratio":       1.6,
		"pace_bonus_pct":        0.05,
		"redo_penalty_per_run":  0.10,
		"redo_penalty_floor":    0.50,
		"defeat_factor":         0.25,
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
	runner.register_test("reward/compute_enemy_bonus",      Callable(EconomyRewardTests, "_t_compute_enemy_bonus"))
	runner.register_test("reward/compute_echo_bonus",       Callable(EconomyRewardTests, "_t_compute_echo_bonus"))
	runner.register_test("reward/pace_bonus_curve",         Callable(EconomyRewardTests, "_t_pace_bonus_curve"))
	runner.register_test("reward/pace_bonus_zero_no_pace_mode", Callable(EconomyRewardTests, "_t_pace_bonus_zero_no_pace_mode"))
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
	runner.register_test("reward/pace_rank_ceiling",         Callable(EconomyRewardTests, "_t_pace_rank_ceiling"))
	runner.register_test("reward/pace_rank_changed_flag",    Callable(EconomyRewardTests, "_t_pace_rank_changed_flag"))
	runner.register_test("reward/pace_breakdown_row",        Callable(EconomyRewardTests, "_t_pace_breakdown_row"))
	runner.register_test("reward/pace_objective_state_per_mode", Callable(EconomyRewardTests, "_t_pace_objective_state_per_mode"))
	runner.register_test("reward/pace_resolve_data_combat",  Callable(EconomyRewardTests, "_t_pace_resolve_data_combat"))
	runner.register_test("reward/pace_endure_drive_reached_and_no_pace", Callable(EconomyRewardTests, "_t_pace_endure_drive_reached_and_no_pace"))
	runner.register_test("reward/pace_keeper_intro_no_pace", Callable(EconomyRewardTests, "_t_pace_keeper_intro_no_pace"))
	runner.register_test("reward/pace_uses_captured_stage_base", Callable(EconomyRewardTests, "_t_pace_uses_captured_stage_base"))


# ─── Test 1 — single combat objective → base = 30 ────────────────────────────
static func _t_compute_base_only() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0, 0, 0)
	if int(result.get("base_reward", -1)) != 30:
		return { "ok": false, "error": "Expected base_reward=30, got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 2 — combat + shrine + boss → base = 130 ────────────────────────────
static func _t_compute_multi_objectives() -> Dictionary:
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS,   3),
	]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0, 0, 0)
	if int(result.get("base_reward", -1)) != 130:
		return { "ok": false, "error": "Expected base_reward=130 (30+40+60), got %d" % result.get("base_reward", -1) }
	return { "ok": true }


# ─── Test 3 — 3 enemies defeated → enemy_bonus = 15 ──────────────────────────
static func _t_compute_enemy_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 3, 3, 0, 0, 10, 0, _default_cfg(), _COMBAT, 0.0, 0, 0)
	if int(result.get("enemy_bonus", -1)) != 15:
		return { "ok": false, "error": "Expected enemy_bonus=15 (3×5), got %d" % result.get("enemy_bonus", -1) }
	return { "ok": true }


# ─── Test 4 — 2 echoes survived → echo_bonus = 20 ────────────────────────────
static func _t_compute_echo_bonus() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 2, 2, 10, 0, _default_cfg(), _COMBAT, 0.0, 0, 0)
	if int(result.get("echo_bonus", -1)) != 20:
		return { "ok": false, "error": "Expected echo_bonus=20 (2×10), got %d" % result.get("echo_bonus", -1) }
	return { "ok": true }


# ─── Test 5 — pace bonus curve: base 60, pace_bonus_pct 0.05 → max 3; par 10 ────
# Limits 1.1 / 1.6 → full at round ≤ 11, zero at round ≥ 16, straight line between.
static func _t_pace_bonus_curve() -> Dictionary:
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1),
	]
	# round → expected pace_bonus: 13 is ratio 1.3, fraction 0.6, 60 × 0.05 × 0.6 = 1.8 → 2.
	var cases := { 5: 3, 11: 3, 12: 2, 13: 2, 15: 1, 16: 0, 20: 0 }
	for rnd in cases:
		var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, rnd, 0, _default_cfg(), _COMBAT, 10.0, 0, 60)
		if int(result.get("pace_bonus", -1)) != int(cases[rnd]):
			return { "ok": false, "error": "round %d: expected pace_bonus=%d, got %d" \
				% [rnd, cases[rnd], result.get("pace_bonus", -1)] }
	var f_mid := PaceService.bonus_fraction(13, 10.0, 1.1, 1.6)
	if absf(f_mid - 0.6) > 0.0001:
		return { "ok": false, "error": "Expected fraction 0.6 at ratio 1.3, got %f" % f_mid }
	if PaceService.bonus_fraction(11, 10.0, 1.1, 1.6) != 1.0 or PaceService.bonus_fraction(16, 10.0, 1.1, 1.6) != 0.0:
		return { "ok": false, "error": "Fraction must be exactly 1.0 at the full limit and 0.0 at the zero limit" }
	return { "ok": true }


# ─── Test 6 — no pace bonus for a no-pace mode, a par of 0, or a defeat ───────
static func _t_pace_bonus_zero_no_pace_mode() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	for mode in [EncounterResolutionModes.PROTECT, EncounterResolutionModes.ENDURE, EncounterResolutionModes.GUIDE_SPIRIT]:
		var r := RewardCalc.compute(true, objs, 0, 0, 0, 0, 1, 0, _default_cfg(), mode, 10.0, 0, 30)
		if int(r.get("pace_bonus", -1)) != 0 or bool(r.get("pace_mode", true)) or str(r.get("pace_state", "x")) != "":
			return { "ok": false, "error": "%s must carry no pace: %s" % [mode, str(r)] }
	var no_par := RewardCalc.compute(true, objs, 0, 0, 0, 0, 1, 0, _default_cfg(), _COMBAT, 0.0, 0, 30)
	if int(no_par.get("pace_bonus", -1)) != 0 or bool(no_par.get("pace_mode", true)):
		return { "ok": false, "error": "par 0 must carry no pace: %s" % str(no_par) }
	var defeat := RewardCalc.compute(false, objs, 0, 0, 0, 0, 1, 0, _default_cfg(), _COMBAT, 10.0, 0, 30)
	if int(defeat.get("pace_bonus", -1)) != 0 or not bool(defeat.get("pace_mode", false)) \
			or str(defeat.get("pace_state", "x")) != "":
		return { "ok": false, "error": "A pace-mode defeat pays 0 and carries no pace_state (design §7): %s" % str(defeat) }
	return { "ok": true }


# ─── Test 7 — run_count=8 → redo_mul clamped to floor 0.50 ──────────────────
static func _t_redo_multiplier_floor() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 8, _default_cfg(), _COMBAT, 0.0, 0, 0)
	var redo := float(result.get("redo_multiplier", -1.0))
	if abs(redo - 0.50) > 0.001:
		return { "ok": false, "error": "Expected redo_multiplier=0.50, got %f" % redo }
	return { "ok": true }


# ─── Test 8 — run_count=3 → redo_mul = 1.0 - 0.3 = 0.70 ────────────────────
static func _t_redo_multiplier_partial() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(true, objs, 0, 0, 0, 0, 10, 3, _default_cfg(), _COMBAT, 0.0, 0, 0)
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
	# V2-INFRA-003 Phase 8: reward_stage_complete → reward_encounter_complete; the virtue_bonus
	# parameter left with the stage cadence and consolation_eligible (true here — a first defeat)
	# took its place. The defeat branch itself is unchanged, so the expected payout is unchanged.
	var result := svc.reward_encounter_complete(
		false, 30, 0, 0, 0, 0, 0, false, 1.0, "F", true, 0.0, logger, 0
	)
	var expected := roundi(30.0 * 0.25 * 1.0)
	if int(result.get("ase_awarded", -1)) != expected:
		return { "ok": false, "error": "Expected defeat payout=%d, got %d" % [expected, result.get("ase_awarded", -1)] }
	return { "ok": true }


# ─── Test 10 — perfect score + run_count=0 → rank = "S" ──────────────────────
static func _t_rank_S_first_run() -> Dictionary:
	# Victory, all 5 enemies killed, all 5 echoes survived, round 2 of par 10 (full pace), first run
	# base=130 (combat+shrine+boss), max_possible = 130+(5×5)+(5×10)+round(130×0.05) = 130+25+50+7 = 212
	# numerator = 130 + 25 + 50 + 7 = 212, perf_ratio = 212/212 = 1.0, rank_score = 1.0 → S
	var objs: Array = [
		ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1),
		ObjectiveModel.make(1, ObjectiveModel.TYPE_SHRINE, 2),
		ObjectiveModel.make(2, ObjectiveModel.TYPE_BOSS,   3),
	]
	var result := RewardCalc.compute(true, objs, 5, 5, 5, 5, 2, 0, _default_cfg(), _COMBAT, 10.0, 0, 130)
	if str(result.get("rank", "")) != "S":
		return { "ok": false, "error": "Expected rank=S, got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 11 — defeat + run_count=5 → rank = "F" ────────────────────────────
static func _t_rank_F_poor_performance() -> Dictionary:
	# Defeat scenario: base=30, 1 enemy on board (total), 1 echo total, slow round, run_count=5
	# defeat_numerator = round(30×0.25) = 8
	# max_possible = 30 + (1×5) + (1×10) + round(30×0.05) = 30+5+10+2 = 47
	# rank_score = (8/47) × 0.50 = 0.085 → F
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var result := RewardCalc.compute(false, objs, 0, 1, 0, 1, 10, 5, _default_cfg(), _COMBAT, 10.0, 0, 30)
	if str(result.get("rank", "")) != "F":
		return { "ok": false, "error": "Expected rank=F (defeat+run_count=5), got '%s'" % result.get("rank", "") }
	return { "ok": true }


# ─── Test 12 — the two cadence payers each add their own half to save ────────
## V2-INFRA-003 Phase 8: reward_stage_complete() was ONE payer for two cadences. It is now two,
## and this test pins both halves and their sum. base=30 is the STAGE's summed objective weight
## and is paid by settle_stage_complete(); the 10 enemy + 10 echo bonuses are THIS fight's and
## are paid by reward_encounter_complete(). Before the split one call banked 50; after it, two
## calls in two dispatches bank 20 + 30 = the same 50, which is the point — the split moved
## WHEN each component pays, not HOW MUCH.
static func _t_economy_service_adds_ase() -> Dictionary:
	var save   := _make_save()
	var svc    := EconomyService.new(save)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	# Encounter cadence: 2 enemy bonus=10, 1 echo bonus=10, no pace, redo=1.0 → 20
	var enc := svc.reward_encounter_complete(
		true, 30, 10, 2, 10, 1, 0, false, 1.0, "B", true, 0.0, logger, 0
	)
	if int(enc.get("ase_awarded", -1)) != 20:
		return { "ok": false, "error": "Expected encounter ase_awarded=20, got %d" % enc.get("ase_awarded", -1) }
	if int(save.get("economy", {}).get("ase", -1)) != 20:
		return { "ok": false, "error": "Expected save.economy.ase=20 after the encounter payout, got %d" % int(save.get("economy", {}).get("ase", -1)) }

	# Stage cadence: base=30, redo=1.0, no virtue bonus → 30
	var stage := svc.settle_stage_complete(30, 1.0, 0, 0.0, logger, 0)
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
	# Round 5 of par 5.2 is ratio 0.96 → full bonus, whatever the win reason.
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1)]
	var r := RewardCalc.compute(true, objs, 2, 2, 5, 5, 5, 0, _default_cfg(), EncounterResolutionModes.PURSUE, par, 2, 60)
	if int(r.get("pace_bonus", -1)) != 3 or str(r.get("pace_state", "")) != PaceService.PACE_FULL:
		return { "ok": false, "error": "Expected full pace (3, full) at round 5, got %s" % str(r) }
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


# ─── Test 18 — pace_state per round, par 10: the colour follows the Ase (design §7) ──
# base 60 (max 3 Ase): full to round 11, partial 12-15, none from 16.
# base 30 (max 1.5 Ase): round 15 pays roundi(0.3) = 0, so it is "none", not "partial".
static func _t_pace_state_transitions() -> Dictionary:
	for c in [[60, 16], [30, 15]]:
		for rnd in range(0, 20):
			var expected := PaceService.PACE_FULL
			if rnd >= int(c[1]):
				expected = PaceService.PACE_NONE
			elif rnd >= 12:
				expected = PaceService.PACE_PARTIAL
			var got := PaceService.pace_state(rnd, 10.0, 1.1, 1.6, c[0], 0.05)
			if got != expected:
				return { "ok": false, "error": "base %d round %d: expected %s, got %s" % [c[0], rnd, expected, got] }
	if PaceService.pace_state(3, 0.0, 1.1, 1.6, 60, 0.05) != "":
		return { "ok": false, "error": "par 0 must give an empty pace_state" }
	# Result side: the same partial ratio that pays 0 Ase reports "none".
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1)]
	var r := RewardCalc.compute(true, objs, 0, 0, 0, 0, 15, 0, _default_cfg(), _COMBAT, 10.0, 0, 30)
	if int(r.get("pace_bonus", -1)) != 0 or str(r.get("pace_state", "")) != PaceService.PACE_NONE:
		return { "ok": false, "error": "base 30 round 15: expected bonus 0 and state none, got %s" % str(r) }
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


# ─── Test 20 — rank ceiling: reached enemies for reach modes, pace only for pace modes ──
# base 60, 0 kills, 5/5 echoes survive, 10 enemies on the board, 2 reached, round 1 of par 10.
static func _t_pace_rank_ceiling() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1)]
	var cfg := _default_cfg()
	var cases := [
		# ENDURE: 110 / (60 + 2×5 + 50) = 0.917 → S. No pace term on either side.
		[EncounterResolutionModes.ENDURE, 2, "S"],
		# ENDURE, 10 reached: 110 / 160 = 0.69 → B.
		[EncounterResolutionModes.ENDURE, 10, "B"],
		# RECOVER, full pace: 113 / (60 + 10 + 50 + 3) = 0.919 → S.
		[EncounterResolutionModes.RECOVER, 2, "S"],
		# COMBAT keeps total_enemies: 113 / (60 + 50 + 50 + 3) = 0.69 → B, reached ignored.
		[EncounterResolutionModes.COMBAT, 2, "B"],
	]
	for c in cases:
		var r := RewardCalc.compute(true, objs, 0, 10, 5, 5, 1, 0, cfg, c[0], 10.0, c[1], 60)
		if str(r.get("rank", "")) != c[2]:
			return { "ok": false, "error": "%s reached=%d: expected %s, got %s" % [c[0], c[1], c[2], r.get("rank", "")] }
	return { "ok": true }


# ─── Test 21 — pace_changed_rank: true only when the pace bonus moves the rank ─
# COMBAT, base 60, 1 of 3 killed, 5/5 survive: max 128, S needs 115.2. 115 alone is A; +3 is S.
static func _t_pace_rank_changed_flag() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1)]
	var fast := RewardCalc.compute(true, objs, 1, 3, 5, 5, 5, 0, _default_cfg(), _COMBAT, 10.0, 0, 60)
	if str(fast.get("rank", "")) != "S" or not bool(fast.get("pace_changed_rank", false)):
		return { "ok": false, "error": "Expected S with pace_changed_rank, got %s" % str(fast) }
	var slow := RewardCalc.compute(true, objs, 1, 3, 5, 5, 20, 0, _default_cfg(), _COMBAT, 10.0, 0, 60)
	if str(slow.get("rank", "")) != "A" or bool(slow.get("pace_changed_rank", true)):
		return { "ok": false, "error": "Expected A without pace_changed_rank, got %s" % str(slow) }
	return { "ok": true }


# ─── Test 22 — "Pace bonus" row: every pace-mode win, 0 included; never otherwise ──
static func _t_pace_breakdown_row() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	# [victory, pace_bonus, pace_mode, expected row delta or null for no row]
	var cases := [ [true, 3, true, 3], [true, 0, true, 0], [true, 0, false, null], [false, 0, true, null] ]
	for c in cases:
		var svc := EconomyService.new(_make_save())
		var res := svc.reward_encounter_complete(
			c[0], 60, 5, 1, 50, 5, c[1], c[2], 1.0, "S", true, 0.0, logger, 0)
		var rows: Array = []
		for row in res.get("breakdown", []):
			if str(row.get("label", "")) == "Pace bonus":
				rows.append(row)
		if c[3] == null:
			if not rows.is_empty():
				return { "ok": false, "error": "case %s: expected no Pace bonus row, got %s" % [str(c), str(rows)] }
		elif rows.size() != 1 or int(rows[0].get("delta", -1)) != int(c[3]):
			return { "ok": false, "error": "case %s: expected one Pace bonus row of %d, got %s" % [str(c), c[3], str(rows)] }
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
		[EncounterResolutionModes.GUIDE_SPIRIT, { "guide_mode": "escort" }, false],
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
			ectx.pace_cfg = { "par_rounds": par, "pace_full_ratio": 1.1, "pace_zero_ratio": 1.6,
				"pace_bonus_pct": 0.05, "stage_base": 60 }
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
	if not data.has("pace_bonus_awarded") or not data.has("pace_changed_rank"):
		return { "ok": false, "error": "resolve data lacks pace_bonus_awarded / pace_changed_rank: %s" % str(data.keys()) }
	if not bool(data.get("victory", false)):
		return { "ok": false, "error": "fixture must be a win for this test" }
	var rows: Array = (data.get("reward_breakdown", []) as Array).filter(
		func(r): return str(r.get("label", "")) == "Pace bonus")
	if rows.size() != 1 or int(rows[0].get("delta", -1)) != int(data["pace_bonus_awarded"]):
		return { "ok": false, "error": "expected one Pace bonus row equal to pace_bonus_awarded, got %s" % str(rows) }
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


# ─── Test 27 — the result pace bonus uses the fight-start stage base (decisions.md D-21) ──
# Objectives sum to 60, captured base is 30: full pace pays roundi(30 × 0.05) = 2, not 3.
# Rank keeps base 60: max = 60 + 50 + 2 = 112, numerator 112 → S.
static func _t_pace_uses_captured_stage_base() -> Dictionary:
	var objs: Array = [ObjectiveModel.make(0, ObjectiveModel.TYPE_COMBAT, 1), ObjectiveModel.make(1, ObjectiveModel.TYPE_COMBAT, 1)]
	var r := RewardCalc.compute(true, objs, 0, 0, 5, 5, 1, 0, _default_cfg(), _COMBAT, 10.0, 0, 30)
	if int(r.get("base_reward", -1)) != 60 or int(r.get("pace_bonus", -1)) != 2 or str(r.get("rank", "")) != "S":
		return { "ok": false, "error": "Expected base 60, pace_bonus 2, rank S, got %s" % str(r) }
	# Partial at round 14: 30 × 0.05 × 0.4 = 0.6 → 1 Ase → "partial", same as the live state.
	var p := RewardCalc.compute(true, objs, 0, 0, 5, 5, 14, 0, _default_cfg(), _COMBAT, 10.0, 0, 30)
	if str(p.get("pace_state", "")) != PaceService.pace_state(14, 10.0, 1.1, 1.6, 30, 0.05):
		return { "ok": false, "error": "result pace_state must equal the live state for the same base" }
	return { "ok": true }
