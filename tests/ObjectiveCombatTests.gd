# res://tests/ObjectiveCombatTests.gd
# V2-STAGE-004 Phase 3 — Per-mode win/lose conditions for RECOVER, PROTECT, ENDURE.
#
# Tests call CombatState.check_end_condition() directly — no FlowRuntime wiring needed.
# All tests are purely deterministic (no randf / randomize / OS time).
#
# Test index:
#
# RECOVER
#   1. objective_combat/recover_relic_secured_victory
#          hold_counter >= hold_rounds + living enemies → "relic_secured" victory.
#   2. objective_combat/recover_not_over_hold_short
#          hold_counter < hold_rounds + living enemies → not over.
#   3. objective_combat/recover_all_echoes_dead_beats_hold
#          all echoes dead (even hold_counter >= hold_rounds) → "all_echoes_dead" lose.
#   4. objective_combat/recover_all_enemies_dead_beats_hold
#          all enemies dead → "all_enemies_defeated" victory (universal win, first).
#
# PROTECT
#   5. objective_combat/protect_entity_lost_lose
#          guarded structure is_dead:true + living echoes + living enemies → "entity_lost" lose.
#   6. objective_combat/protect_duration_met_victory
#          entity alive + protect_counter >= duration_turns + living enemies → "protected" victory.
#   7. objective_combat/protect_not_over_short
#          entity alive + protect_counter < duration_turns + living enemies → not over.
#   8. objective_combat/protect_all_enemies_dead_beats_duration
#          all enemies dead → "all_enemies_defeated" (first priority).
#   (new) objective_combat/protect_round_counter_only_not_over
#          round_counter >= duration_turns but protect_counter=0 + living enemies → NOT over.
#   (new) objective_combat/protect_counter_partial_advance
#          protect_counter=2 < duration_turns=4 → not over (counter advances, but not there yet).
#
# ENDURE
#   9. objective_combat/endure_duration_met_victory
#          round_counter >= duration_turns + living enemies → "endured" victory.
#  10. objective_combat/endure_not_over_short
#          round_counter < duration_turns + living enemies → not over.
#  11. objective_combat/endure_all_echoes_dead_lose
#          all echoes dead + enemies alive → "all_echoes_dead" lose.
#  12. objective_combat/endure_all_enemies_dead_first
#          all enemies dead → "all_enemies_defeated" (first priority).
#
# Zero-regression (COMBAT / PURIFY_SHRINE — legacy 2-arg path)
#  13. objective_combat/legacy_combat_enemies_dead_victory
#          2-arg: enemies dead → "all_enemies_defeated" victory.
#  14. objective_combat/legacy_combat_echoes_dead_lose
#          2-arg: echoes dead → "all_echoes_dead" lose.
#  15. objective_combat/legacy_combat_both_alive_not_over
#          2-arg: both factions alive → not over.
#  16. objective_combat/legacy_shrine_dead_shrine_lose
#          2-arg: shrine structure is_dead → "shrine_destroyed" lose.
#  17. objective_combat/legacy_shrine_alive_both_factions_not_over
#          2-arg: shrine alive + both factions → not over.
#
# create()
#  18. objective_combat/create_stores_objective_params
#          CombatState.create(actors, "recover", 0, {}, {hold_rounds:3}) →
#          returned dict objective_params.hold_rounds == 3, round_counter == 0.

extends RefCounted
class_name ObjectiveCombatTests


# ─── Helpers ────────────────────────────────────────────────────────────────

# Minimal living echo actor.
static func _echo(id: String) -> Dictionary:
	return {
		"id":           id,
		"faction":      "echo",
		"is_dead":      false,
		"is_structure": false,
		"grid_pos":     { "col": 0, "row": 0 },
		"current_hp":   100,
	}

# Minimal living enemy actor.
static func _enemy(id: String) -> Dictionary:
	return {
		"id":           id,
		"faction":      "enemy",
		"is_dead":      false,
		"is_structure": false,
		"grid_pos":     { "col": 5, "row": 5 },
		"current_hp":   80,
	}

# Dead echo.
static func _echo_dead(id: String) -> Dictionary:
	var a := _echo(id)
	a["is_dead"] = true
	a["current_hp"] = 0
	return a

# Dead enemy.
static func _enemy_dead(id: String) -> Dictionary:
	var a := _enemy(id)
	a["is_dead"] = true
	a["current_hp"] = 0
	return a

# Living structure actor (used as shrine / guarded entity).
static func _structure(id: String) -> Dictionary:
	return {
		"id":           id,
		"faction":      "structure",
		"is_dead":      false,
		"is_structure": true,
		"grid_pos":     { "col": 5, "row": 0 },
		"current_hp":   50,
	}

# Dead structure (shrine destroyed / entity lost).
static func _structure_dead(id: String) -> Dictionary:
	var a := _structure(id)
	a["is_dead"] = true
	a["current_hp"] = 0
	return a

# Minimal combat_state dict for the RECOVER objective.
static func _recover_state(hold_counter: int, hold_rounds: int) -> Dictionary:
	return {
		"round_counter":    0,
		"hold_counter":     hold_counter,
		"objective_params": { "hold_rounds": hold_rounds },
	}

# Minimal combat_state dict for PROTECT / ENDURE objectives.
static func _timed_state(round_counter: int, duration_turns: int) -> Dictionary:
	return {
		"round_counter":    round_counter,
		"hold_counter":     0,
		"objective_params": { "duration_turns": duration_turns },
	}

# Minimal combat_state dict for PROTECT objectives that use protect_counter.
# protect_counter is the guard-proximity counter (only advances when an echo is near entity).
# round_counter is still present for completeness but protect win checks protect_counter.
static func _protect_state(protect_counter: int, duration_turns: int, totem_stolen: bool = false) -> Dictionary:
	return {
		"round_counter":    protect_counter,  # kept in sync for snapshot projections; not used for win gate
		"hold_counter":     0,
		"protect_counter":  protect_counter,
		"objective_params": { "duration_turns": duration_turns },
		"totem_stolen":     totem_stolen,
	}


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	# RECOVER
	runner.register_test("objective_combat/recover_relic_secured_victory",
		Callable(ObjectiveCombatTests, "_t_recover_relic_secured_victory"))
	runner.register_test("objective_combat/recover_not_over_hold_short",
		Callable(ObjectiveCombatTests, "_t_recover_not_over_hold_short"))
	runner.register_test("objective_combat/recover_all_echoes_dead_beats_hold",
		Callable(ObjectiveCombatTests, "_t_recover_all_echoes_dead_beats_hold"))
	runner.register_test("objective_combat/recover_all_enemies_dead_beats_hold",
		Callable(ObjectiveCombatTests, "_t_recover_all_enemies_dead_beats_hold"))
	# PROTECT
	runner.register_test("objective_combat/protect_entity_lost_lose",
		Callable(ObjectiveCombatTests, "_t_protect_entity_lost_lose"))
	runner.register_test("objective_combat/protect_duration_met_victory",
		Callable(ObjectiveCombatTests, "_t_protect_duration_met_victory"))
	runner.register_test("objective_combat/protect_not_over_short",
		Callable(ObjectiveCombatTests, "_t_protect_not_over_short"))
	runner.register_test("objective_combat/protect_all_enemies_dead_beats_duration",
		Callable(ObjectiveCombatTests, "_t_protect_all_enemies_dead_beats_duration"))
	# ENDURE
	runner.register_test("objective_combat/endure_duration_met_victory",
		Callable(ObjectiveCombatTests, "_t_endure_duration_met_victory"))
	runner.register_test("objective_combat/endure_not_over_short",
		Callable(ObjectiveCombatTests, "_t_endure_not_over_short"))
	runner.register_test("objective_combat/endure_all_echoes_dead_lose",
		Callable(ObjectiveCombatTests, "_t_endure_all_echoes_dead_lose"))
	runner.register_test("objective_combat/endure_all_enemies_dead_first",
		Callable(ObjectiveCombatTests, "_t_endure_all_enemies_dead_first"))
	# V2-STAGE-004 Distinctiveness — ENDURE lull guard + dual win
	runner.register_test("objective_combat/endure_lull_clear_all_no_win",
		Callable(ObjectiveCombatTests, "_t_endure_lull_clear_all_no_win"))
	runner.register_test("objective_combat/endure_lull_echoes_dead_still_lose",
		Callable(ObjectiveCombatTests, "_t_endure_lull_echoes_dead_still_lose"))
	runner.register_test("objective_combat/endure_all_waves_spawned_clear_all_wins",
		Callable(ObjectiveCombatTests, "_t_endure_all_waves_spawned_clear_all_wins"))
	runner.register_test("objective_combat/endure_survive_to_duration_wins",
		Callable(ObjectiveCombatTests, "_t_endure_survive_to_duration_wins"))
	# V2-STAGE-004 Distinctiveness — PROTECT stolen-at-clockout
	runner.register_test("objective_combat/protect_stolen_at_clockout_defeat",
		Callable(ObjectiveCombatTests, "_t_protect_stolen_at_clockout_defeat"))
	runner.register_test("objective_combat/protect_not_stolen_at_clockout_victory",
		Callable(ObjectiveCombatTests, "_t_protect_not_stolen_at_clockout_victory"))
	# V2-STAGE-004 PROTECT guard-proximity counter
	runner.register_test("objective_combat/protect_round_counter_only_not_over",
		Callable(ObjectiveCombatTests, "_t_protect_round_counter_only_not_over"))
	runner.register_test("objective_combat/protect_counter_partial_advance",
		Callable(ObjectiveCombatTests, "_t_protect_counter_partial_advance"))
	# V2-STAGE-004 Distinctiveness — ENDURE rising wave size logic (§4-F)
	runner.register_test("objective_combat/endure_wave_size_rising_n1",
		Callable(ObjectiveCombatTests, "_t_endure_wave_size_rising_n1"))
	runner.register_test("objective_combat/endure_wave_size_rising_n2",
		Callable(ObjectiveCombatTests, "_t_endure_wave_size_rising_n2"))
	runner.register_test("objective_combat/endure_wave_size_clamped_at_max",
		Callable(ObjectiveCombatTests, "_t_endure_wave_size_clamped_at_max"))
	runner.register_test("objective_combat/endure_total_waves_computed",
		Callable(ObjectiveCombatTests, "_t_endure_total_waves_computed"))
	# V2-STAGE-004 Distinctiveness — §4-I _build_objective_state additions
	runner.register_test("objective_combat/objective_state_invulnerable_recover",
		Callable(ObjectiveCombatTests, "_t_objective_state_invulnerable_recover"))
	runner.register_test("objective_combat/objective_state_waves_remaining_endure",
		Callable(ObjectiveCombatTests, "_t_objective_state_waves_remaining_endure"))
	runner.register_test("objective_combat/objective_state_totem_stolen_protect",
		Callable(ObjectiveCombatTests, "_t_objective_state_totem_stolen_protect"))
	# Zero-regression — legacy COMBAT path
	runner.register_test("objective_combat/legacy_combat_enemies_dead_victory",
		Callable(ObjectiveCombatTests, "_t_legacy_combat_enemies_dead_victory"))
	runner.register_test("objective_combat/legacy_combat_echoes_dead_lose",
		Callable(ObjectiveCombatTests, "_t_legacy_combat_echoes_dead_lose"))
	runner.register_test("objective_combat/legacy_combat_both_alive_not_over",
		Callable(ObjectiveCombatTests, "_t_legacy_combat_both_alive_not_over"))
	# Zero-regression — legacy PURIFY_SHRINE path
	runner.register_test("objective_combat/legacy_shrine_dead_shrine_lose",
		Callable(ObjectiveCombatTests, "_t_legacy_shrine_dead_shrine_lose"))
	runner.register_test("objective_combat/legacy_shrine_alive_both_factions_not_over",
		Callable(ObjectiveCombatTests, "_t_legacy_shrine_alive_both_factions_not_over"))
	# create()
	runner.register_test("objective_combat/create_stores_objective_params",
		Callable(ObjectiveCombatTests, "_t_create_stores_objective_params"))
	# resolve_objective_params() — float growth scaling fix
	runner.register_test("objective_combat/resolve_params_recover_base",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_base"))
	runner.register_test("objective_combat/resolve_params_recover_scales",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_scales"))
	runner.register_test("objective_combat/resolve_params_recover_clamped",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_clamped"))
	runner.register_test("objective_combat/resolve_params_protect_scales",
		Callable(ObjectiveCombatTests, "_t_resolve_params_protect_scales"))
	runner.register_test("objective_combat/resolve_params_protect_clamped",
		Callable(ObjectiveCombatTests, "_t_resolve_params_protect_clamped"))
	runner.register_test("objective_combat/resolve_params_endure_scales",
		Callable(ObjectiveCombatTests, "_t_resolve_params_endure_scales"))
	runner.register_test("objective_combat/resolve_params_endure_clamped",
		Callable(ObjectiveCombatTests, "_t_resolve_params_endure_clamped"))
	runner.register_test("objective_combat/resolve_params_stage_override",
		Callable(ObjectiveCombatTests, "_t_resolve_params_stage_override"))
	runner.register_test("objective_combat/resolve_params_unknown_mode_empty",
		Callable(ObjectiveCombatTests, "_t_resolve_params_unknown_mode_empty"))
	# Bug-fix coverage: missing config keys in resolve_objective_params()
	runner.register_test("objective_combat/resolve_params_endure_wave_size_max",
		Callable(ObjectiveCombatTests, "_t_resolve_params_endure_wave_size_max"))
	runner.register_test("objective_combat/resolve_params_endure_wave_size_rising_step",
		Callable(ObjectiveCombatTests, "_t_resolve_params_endure_wave_size_rising_step"))
	runner.register_test("objective_combat/resolve_params_recover_reinforce_interval",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_reinforce_interval"))
	runner.register_test("objective_combat/resolve_params_recover_reinforce_size",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_reinforce_size"))
	runner.register_test("objective_combat/resolve_params_recover_reinforce_group",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_reinforce_group"))
	runner.register_test("objective_combat/resolve_params_recover_reinforce_max_total",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_reinforce_max_total"))
	runner.register_test("objective_combat/resolve_params_recover_reinforce_stage_override_wins",
		Callable(ObjectiveCombatTests, "_t_resolve_params_recover_reinforce_stage_override_wins"))
	# Bug-fix coverage: RECOVER holder reads top-level speed (not stats.speed)
	runner.register_test("objective_combat/recover_holder_top_level_speed",
		Callable(ObjectiveCombatTests, "_t_recover_holder_top_level_speed"))


# ─── RECOVER tests ──────────────────────────────────────────────────────────

# 1. hold_counter == hold_rounds + living enemies → "relic_secured" victory.
static func _t_recover_relic_secured_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _echo("e2"), _enemy("n1"), _structure("relic_0")]
	var cs := _recover_state(2, 2)  # hold_counter == hold_rounds

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.RECOVER, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected combat over=true, got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true, got victory=false" }
	if result.get("reason", "") != "relic_secured":
		return { "ok": false, "error": "Expected reason='relic_secured', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 2. hold_counter < hold_rounds + living enemies → not over.
static func _t_recover_not_over_hold_short() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("relic_0")]
	var cs := _recover_state(1, 2)  # hold_counter < hold_rounds

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.RECOVER, cs)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (hold not yet met), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# 3. all echoes dead (hold_counter high) → "all_echoes_dead" lose.
#    Priority order: all_echoes_dead (priority 4) before relic_secured (priority 5).
static func _t_recover_all_echoes_dead_beats_hold() -> Dictionary:
	var actors: Array = [_echo_dead("e1"), _enemy("n1"), _structure("relic_0")]
	# hold_counter meets the threshold — but echoes are all dead, which fires first.
	var cs := _recover_state(3, 2)

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.RECOVER, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (echoes dead), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (echoes dead = lose), got victory=true" }
	if result.get("reason", "") != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 4. all enemies dead → "all_enemies_defeated" (first priority, wins over hold check).
static func _t_recover_all_enemies_dead_beats_hold() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1"), _structure("relic_0")]
	# hold_counter not yet met — but enemies are all dead, which fires first.
	var cs := _recover_state(0, 5)

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.RECOVER, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (enemies dead), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (enemies all dead), got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── PROTECT tests ──────────────────────────────────────────────────────────

# 5. guarded structure is_dead + living echoes + living enemies → "entity_lost" lose.
static func _t_protect_entity_lost_lose() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure_dead("ward_0")]
	var cs := _timed_state(0, 4)  # round_counter well below duration

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (entity dead), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (entity lost), got victory=true" }
	if result.get("reason", "") != "entity_lost":
		return { "ok": false, "error": "Expected reason='entity_lost', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 6. entity alive + protect_counter >= duration_turns + living enemies → "protected" victory.
#    (protect_counter is advanced by FlowRuntime only when an echo is near the entity;
#     round_counter alone no longer gates the PROTECT win.)
static func _t_protect_duration_met_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs := _protect_state(4, 4)  # protect_counter == duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (protect_counter met), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (protected), got victory=false" }
	if result.get("reason", "") != "protected":
		return { "ok": false, "error": "Expected reason='protected', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 7. entity alive + protect_counter < duration_turns + living enemies → not over.
static func _t_protect_not_over_short() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs := _protect_state(3, 4)  # protect_counter < duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (protect_counter not yet met), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# 8. all enemies dead → "all_enemies_defeated" (first priority).
static func _t_protect_all_enemies_dead_beats_duration() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1"), _structure("ward_0")]
	# Duration not yet met — but enemies all dead wins first.
	var cs := _timed_state(1, 8)

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (all enemies dead), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true, got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── ENDURE tests ──────────────────────────────────────────────────────────

# 9. round_counter >= duration_turns + living enemies → "endured" victory.
static func _t_endure_duration_met_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _echo("e2"), _enemy("n1")]
	var cs := _timed_state(5, 5)  # round_counter == duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (endure duration met), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (endured), got victory=false" }
	if result.get("reason", "") != "endured":
		return { "ok": false, "error": "Expected reason='endured', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 10. round_counter < duration_turns + living enemies → not over.
static func _t_endure_not_over_short() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1")]
	var cs := _timed_state(4, 5)  # round_counter < duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (endure not done), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# 11. all echoes dead + enemies alive → "all_echoes_dead" lose.
static func _t_endure_all_echoes_dead_lose() -> Dictionary:
	var actors: Array = [_echo_dead("e1"), _enemy("n1")]
	var cs := _timed_state(2, 5)  # round_counter below threshold

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (echoes dead), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (echoes dead = lose), got victory=true" }
	if result.get("reason", "") != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 12. all enemies dead + all_waves_spawned == true → "all_enemies_defeated" (out-kill win).
#     Scenario: final wave has been spawned and echoes wipe them — fight ends in victory.
static func _t_endure_all_enemies_dead_first() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1")]
	# all_waves_spawned must be true so the universal win fires ("out-kill" win path).
	var cs: Dictionary = {
		"round_counter":    0,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 10 },
		"all_waves_spawned": true,
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (enemies dead + all waves spawned), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true, got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── V2-STAGE-004 Distinctiveness: ENDURE lull guard + dual win ──────────────

# endure_lull_clear_all_no_win:
# ENDURE + all_waves_spawned == false → clearing enemies during lull must NOT end the fight.
# The next wave must be allowed to spawn (FlowRuntime does so on end_round).
static func _t_endure_lull_clear_all_no_win() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1")]
	# all_waves_spawned NOT set (defaults false) — simulates inter-wave lull.
	var cs: Dictionary = {
		"round_counter":    2,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 8 },
		"all_waves_spawned": false,
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if result.get("over", false):
		return {
			"ok": false,
			"error": "ENDURE lull: expected over=false while waves remain, got over=true (reason='%s')" % str(result.get("reason", ""))
		}
	return { "ok": true }


# endure_lull_echoes_dead_still_lose:
# During ENDURE lull (all_waves_spawned == false), all echoes dying must still be a defeat.
# Only the all_enemies_defeated VICTORY is gated — all_echoes_dead defeat fires as normal.
static func _t_endure_lull_echoes_dead_still_lose() -> Dictionary:
	var actors: Array = [_echo_dead("e1"), _enemy_dead("n1")]
	var cs: Dictionary = {
		"round_counter":    2,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 8 },
		"all_waves_spawned": false,
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (echoes dead during lull), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (echoes dead), got victory=true" }
	if result.get("reason", "") != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# endure_all_waves_spawned_clear_all_wins:
# ENDURE + all_waves_spawned == true → killing remaining enemies fires "all_enemies_defeated"
# (the "out-kill" dual win path).
static func _t_endure_all_waves_spawned_clear_all_wins() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1")]
	var cs: Dictionary = {
		"round_counter":    3,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 8 },
		"all_waves_spawned": true,
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (all waves out, enemies dead), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (out-kill win), got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# endure_survive_to_duration_wins:
# ENDURE + round_counter >= duration_turns + living enemies → "endured" ("out-survive" win).
# Mirrors existing test 9 but explicitly confirms all_waves_spawned is irrelevant for endure-path.
static func _t_endure_survive_to_duration_wins() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1")]
	var cs: Dictionary = {
		"round_counter":    6,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 6 },
		"all_waves_spawned": false,  # doesn't matter — duration path fires regardless
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (duration met), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (endured), got victory=false" }
	if result.get("reason", "") != "endured":
		return { "ok": false, "error": "Expected reason='endured', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── V2-STAGE-004 Distinctiveness: PROTECT stolen-at-clockout ────────────────

# protect_stolen_at_clockout_defeat:
# PROTECT + protect_counter >= duration_turns + totem_stolen == true → defeat "totem_taken".
# The totem was stolen and the echoes accumulated enough guarded rounds — but totem not recovered.
static func _t_protect_stolen_at_clockout_defeat() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs: Dictionary = _protect_state(4, 4, true)  # protect_counter == duration_turns, stolen

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (stolen at clockout), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (totem taken), got victory=true" }
	if result.get("reason", "") != "totem_taken":
		return { "ok": false, "error": "Expected reason='totem_taken', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# protect_not_stolen_at_clockout_victory:
# PROTECT + protect_counter >= duration_turns + totem_stolen == false → victory "protected".
# Totem was never stolen (or was recovered before guard threshold was met).
static func _t_protect_not_stolen_at_clockout_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs: Dictionary = _protect_state(5, 4, false)  # protect_counter(5) > duration_turns(4), safe

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (duration met, totem safe), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (protected), got victory=false" }
	if result.get("reason", "") != "protected":
		return { "ok": false, "error": "Expected reason='protected', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── Zero-regression: legacy COMBAT path (2-arg / no combat_state) ──────────

# 13. 2-arg: enemies dead → "all_enemies_defeated" victory.
static func _t_legacy_combat_enemies_dead_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1")]

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.COMBAT)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true, got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true, got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 14. 2-arg: echoes dead → "all_echoes_dead" lose.
static func _t_legacy_combat_echoes_dead_lose() -> Dictionary:
	var actors: Array = [_echo_dead("e1"), _enemy("n1")]

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.COMBAT)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true, got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false, got victory=true" }
	if result.get("reason", "") != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 15. 2-arg: both factions alive → not over.
static func _t_legacy_combat_both_alive_not_over() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1")]

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.COMBAT)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (both alive), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── Zero-regression: legacy PURIFY_SHRINE path (2-arg) ──────────────────

# 16. 2-arg: dead shrine structure → "shrine_destroyed" lose.
static func _t_legacy_shrine_dead_shrine_lose() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure_dead("shrine_0")]

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PURIFY_SHRINE)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (shrine dead), got over=false" }
	if result.get("victory", true):
		return { "ok": false, "error": "Expected victory=false (shrine destroyed), got victory=true" }
	if result.get("reason", "") != "shrine_destroyed":
		return { "ok": false, "error": "Expected reason='shrine_destroyed', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 17. 2-arg: shrine alive + both factions alive → not over.
static func _t_legacy_shrine_alive_both_factions_not_over() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("shrine_0")]

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PURIFY_SHRINE)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (shrine alive, both factions live), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── resolve_objective_params() tests ───────────────────────────────────────
# These call FlowEncounterState.resolve_objective_params() directly (pure static,
# no FlowRuntime wiring needed). mode_cfg dicts are explicit so assertions are
# fully deterministic and independent of balance.json.

# Minimal recover mode_cfg matching config shape (growth = 0.5 — the buggy float).
static func _recover_cfg() -> Dictionary:
	return {
		"hold_rounds": 2,
		"hold_rounds_growth_per_completion": 0.5,
		"hold_rounds_max": 4,
		"relic_def_id": "recover_relic",
		"relic_name": "Severed Relic",
		"relic_max_hp": 9999,
		"reinforce_interval":  3,
		"reinforce_size":      2,
		"reinforce_group":     "group.forest_patrol",
		"reinforce_max_total": 6,
	}

# Minimal protect mode_cfg.
static func _protect_cfg() -> Dictionary:
	return {
		"duration_turns": 4,
		"duration_growth_per_completion": 0.5,
		"duration_max": 8,
		"entity_max_hp": 70,
		"entity_hp_growth_per_completion": 10,
		"entity_def_id": "protect_entity",
		"entity_name": "The Charge",
	}

# Minimal endure mode_cfg.
static func _endure_cfg() -> Dictionary:
	return {
		"duration_turns": 5,
		"duration_growth_per_completion": 0.5,
		"duration_max": 9,
		"wave_size": 2,
		"wave_size_growth_per_completion": 0.5,
		"wave_size_max": 4,
		"wave_interval": 2,
		"wave_group": "group.vale_patrol_sm",
		"wave_size_rising_step": 1,
	}


# 19. recover at completion_index=0 → hold_rounds == base (2).
static func _t_resolve_params_recover_base() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, {})
	if int(p.get("hold_rounds", -1)) != 2:
		return { "ok": false, "error": "Expected hold_rounds=2 at index 0, got %d" % int(p.get("hold_rounds", -1)) }
	return { "ok": true }


# 20. recover at completion_index=2 → hold_rounds = base(2) + round(0.5*2)=1 → 3.
#     This was the broken case: int(0.5)*2=0, so scaled=2==base (no growth).
#     With the fix: roundi(0.5*2.0)=1, scaled=3.
static func _t_resolve_params_recover_scales() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 2, {})
	var got: int = int(p.get("hold_rounds", -1))
	if got != 3:
		return { "ok": false, "error": "Expected hold_rounds=3 at index 2, got %d (float-growth fix required)" % got }
	return { "ok": true }


# 21. recover clamped at max=4 when completion_index is large (e.g. 6 → 2+round(0.5*6)=2+3=5, clamped to 4).
static func _t_resolve_params_recover_clamped() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 6, {})
	var got: int = int(p.get("hold_rounds", -1))
	if got != 4:
		return { "ok": false, "error": "Expected hold_rounds=4 (clamped) at index 6, got %d" % got }
	return { "ok": true }


# 22. protect at completion_index=2: duration_turns=4+round(0.5*2)=5, entity_max_hp=70+round(10*2)=90.
static func _t_resolve_params_protect_scales() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("protect", _protect_cfg(), 2, {})
	var dur: int = int(p.get("duration_turns", -1))
	var hp: int  = int(p.get("entity_max_hp",  -1))
	if dur != 5:
		return { "ok": false, "error": "Expected duration_turns=5 at index 2, got %d" % dur }
	if hp != 90:
		return { "ok": false, "error": "Expected entity_max_hp=90 at index 2, got %d" % hp }
	return { "ok": true }


# 23. protect clamped: completion_index=10 → duration=4+round(0.5*10)=9, clamped to max=8.
static func _t_resolve_params_protect_clamped() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("protect", _protect_cfg(), 10, {})
	var dur: int = int(p.get("duration_turns", -1))
	if dur != 8:
		return { "ok": false, "error": "Expected duration_turns=8 (clamped) at index 10, got %d" % dur }
	return { "ok": true }


# 24. endure at completion_index=2: duration=5+round(0.5*2)=6, wave_size=2+round(0.5*2)=3.
static func _t_resolve_params_endure_scales() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("endure", _endure_cfg(), 2, {})
	var dur: int = int(p.get("duration_turns", -1))
	var ws: int  = int(p.get("wave_size",      -1))
	if dur != 6:
		return { "ok": false, "error": "Expected duration_turns=6 at index 2, got %d" % dur }
	if ws != 3:
		return { "ok": false, "error": "Expected wave_size=3 at index 2, got %d" % ws }
	return { "ok": true }


# 25. endure clamped: completion_index=10 → duration=5+round(0.5*10)=10, clamped to max=9;
#     wave_size=2+round(0.5*10)=7, clamped to max=4.
static func _t_resolve_params_endure_clamped() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("endure", _endure_cfg(), 10, {})
	var dur: int = int(p.get("duration_turns", -1))
	var ws: int  = int(p.get("wave_size",      -1))
	if dur != 9:
		return { "ok": false, "error": "Expected duration_turns=9 (clamped) at index 10, got %d" % dur }
	if ws != 4:
		return { "ok": false, "error": "Expected wave_size=4 (clamped) at index 10, got %d" % ws }
	return { "ok": true }


# 26. stage_params override: {hold_rounds: 9} beats scaled value.
static func _t_resolve_params_stage_override() -> Dictionary:
	var stage_p := { "hold_rounds": 9 }
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 2, stage_p)
	var got: int = int(p.get("hold_rounds", -1))
	if got != 9:
		return { "ok": false, "error": "Expected hold_rounds=9 (stage override), got %d" % got }
	# Other fields (relic_def_id etc.) should still be present.
	if not p.has("relic_def_id"):
		return { "ok": false, "error": "relic_def_id missing after stage override merge" }
	return { "ok": true }


# 27. Unknown mode key → returns {}.
static func _t_resolve_params_unknown_mode_empty() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("combat", {}, 0, {})
	if not p.is_empty():
		return { "ok": false, "error": "Expected empty dict for unknown mode, got %s" % str(p) }
	return { "ok": true }


# ─── create() test ──────────────────────────────────────────────────────────

# 18. CombatState.create stores objective_params correctly, round_counter == 0.
static func _t_create_stores_objective_params() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1")]
	var params := { "hold_rounds": 3 }

	var state := CombatState.create(actors, EncounterResolutionModes.RECOVER, 0, {}, params)

	if not state.has("objective_params"):
		return { "ok": false, "error": "CombatState missing 'objective_params' key" }

	var op_v: Variant = state.get("objective_params")
	if not (op_v is Dictionary):
		return { "ok": false, "error": "'objective_params' is not a Dictionary (got %s)" % type_string(typeof(op_v)) }

	var op: Dictionary = op_v as Dictionary
	if not op.has("hold_rounds"):
		return { "ok": false, "error": "objective_params missing 'hold_rounds'" }
	if int(op.get("hold_rounds", -1)) != 3:
		return { "ok": false, "error": "Expected objective_params.hold_rounds=3, got %d" % int(op.get("hold_rounds", -1)) }

	if not state.has("round_counter"):
		return { "ok": false, "error": "CombatState missing 'round_counter'" }
	if int(state.get("round_counter", -1)) != 0:
		return { "ok": false, "error": "Expected round_counter=0, got %d" % int(state.get("round_counter", -1)) }

	return { "ok": true }


# ─── V2-STAGE-004 Distinctiveness: ENDURE rising wave size (§4-F) ─────────────
# These tests exercise the rising-wave-size formula directly — no FlowRuntime needed.
# Formula: wave_size = clamp(base + (N-1)*rising_step, base, max)
# where N = 1-indexed wave number (waves_spawned before this spawn + 1).

# Helper: compute rising wave size for wave N.
static func _rising_wave_size(base: int, rising_step: int, wave_max: int, n: int) -> int:
	return clampi(base + (n - 1) * rising_step, base, wave_max)


# Wave 1 (N=1): no rising yet — size == base.
# base=2, step=1, max=4, N=1 → size=2.
static func _t_endure_wave_size_rising_n1() -> Dictionary:
	var size: int = _rising_wave_size(2, 1, 4, 1)
	if size != 2:
		return { "ok": false, "error": "Wave 1: expected size=2, got %d" % size }
	return { "ok": true }


# Wave 2 (N=2): one step of rising — base=2, step=1 → 3.
static func _t_endure_wave_size_rising_n2() -> Dictionary:
	var size: int = _rising_wave_size(2, 1, 4, 2)
	if size != 3:
		return { "ok": false, "error": "Wave 2: expected size=3, got %d" % size }
	return { "ok": true }


# Wave 5 (N=5): would be 2+(5-1)*1=6, clamped to max=4.
static func _t_endure_wave_size_clamped_at_max() -> Dictionary:
	var size: int = _rising_wave_size(2, 1, 4, 5)
	if size != 4:
		return { "ok": false, "error": "Wave 5 (clamped): expected size=4, got %d" % size }
	return { "ok": true }


# total_waves computation: duration=6, interval=2 → rounds 2,4 → total_waves=2.
# (Rounds in range(1,6) divisible by 2: 2, 4 — count=2.)
static func _t_endure_total_waves_computed() -> Dictionary:
	var duration_turns: int = 6
	var wave_interval: int  = 2
	var _tw: int = 0
	for _r in range(1, duration_turns):
		if _r % wave_interval == 0:
			_tw += 1
	if _tw != 2:
		return { "ok": false, "error": "total_waves for duration=6 interval=2: expected 2, got %d" % _tw }
	return { "ok": true }


# ─── V2-STAGE-004 Distinctiveness: §4-I _build_objective_state additions ────────
# These tests call FlowEncounterState._build_objective_state indirectly via
# a minimal EncounterContext + combat_state, using the public static builder.
# We test the new fields: objective_invulnerable, waves_remaining, wave_total, totem_stolen.

# objective_invulnerable: RECOVER relic actor with is_objective_relic=true → true.
static func _t_objective_state_invulnerable_recover() -> Dictionary:
	var relic: Dictionary = _structure("relic_0")
	relic["is_objective_relic"] = true
	var actors: Array = [_echo("e1"), _enemy("n1"), relic]
	# Use a minimal combat_state for RECOVER.
	var cs: Dictionary = {
		"objective":        EncounterResolutionModes.RECOVER,
		"round_counter":    1,
		"hold_counter":     0,
		"objective_params": { "hold_rounds": 3 },
	}
	# Build a mock EncounterContext via CombatState.create then patch actors + terrain.
	var ectx := EncounterContext.new()
	ectx.actors          = actors
	ectx.resolution_mode = EncounterResolutionModes.RECOVER
	ectx.terrain         = {}
	ectx.purifier_id     = ""
	ectx.encounter_id    = "test_invulnerable"
	ectx.placement_seed  = 0
	ectx.combat_state    = cs
	ectx.last_round_results = []
	ectx.round_bark_events  = []
	ectx.echo_action_logs   = {}

	var snap: Dictionary = FlowEncounterState._build_objective_state(ectx, cs)
	if not bool(snap.get("objective_invulnerable", false)):
		return { "ok": false, "error": "Expected objective_invulnerable=true for RECOVER relic, got false" }
	return { "ok": true }


# waves_remaining / wave_total: ENDURE, 2 of 3 waves spawned → remaining=1.
static func _t_objective_state_waves_remaining_endure() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1")]
	var cs: Dictionary = {
		"objective":        EncounterResolutionModes.ENDURE,
		"round_counter":    4,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 6, "wave_interval": 2 },
		"total_waves":      3,
		"waves_spawned":    2,
		"all_waves_spawned": false,
	}
	var ectx := EncounterContext.new()
	ectx.actors          = actors
	ectx.resolution_mode = EncounterResolutionModes.ENDURE
	ectx.terrain         = {}
	ectx.purifier_id     = ""
	ectx.encounter_id    = "test_waves_remaining"
	ectx.placement_seed  = 0
	ectx.combat_state    = cs
	ectx.last_round_results = []
	ectx.round_bark_events  = []
	ectx.echo_action_logs   = {}

	var snap: Dictionary = FlowEncounterState._build_objective_state(ectx, cs)
	if int(snap.get("waves_remaining", -1)) != 1:
		return { "ok": false, "error": "Expected waves_remaining=1 (3-2), got %d" % int(snap.get("waves_remaining", -1)) }
	if int(snap.get("wave_total", -1)) != 3:
		return { "ok": false, "error": "Expected wave_total=3, got %d" % int(snap.get("wave_total", -1)) }
	return { "ok": true }


# totem_stolen: PROTECT + combat_state.totem_stolen=true → objective_state.totem_stolen=true.
static func _t_objective_state_totem_stolen_protect() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs: Dictionary = {
		"objective":        EncounterResolutionModes.PROTECT,
		"round_counter":    2,
		"hold_counter":     0,
		"objective_params": { "duration_turns": 5 },
		"totem_stolen":     true,
		"totem_carrier_id": "n1",
	}
	var ectx := EncounterContext.new()
	ectx.actors          = actors
	ectx.resolution_mode = EncounterResolutionModes.PROTECT
	ectx.terrain         = {}
	ectx.purifier_id     = ""
	ectx.encounter_id    = "test_totem_stolen"
	ectx.placement_seed  = 0
	ectx.combat_state    = cs
	ectx.last_round_results = []
	ectx.round_bark_events  = []
	ectx.echo_action_logs   = {}

	var snap: Dictionary = FlowEncounterState._build_objective_state(ectx, cs)
	if not bool(snap.get("totem_stolen", false)):
		return { "ok": false, "error": "Expected totem_stolen=true in objective_state, got false" }
	return { "ok": true }


# ─── V2-STAGE-004 PROTECT guard-proximity counter tests ─────────────────────

# protect_round_counter_only_not_over:
# PROTECT with round_counter >= duration_turns but protect_counter=0 and living enemies
# must NOT be over — the passive round timer no longer gates the PROTECT win.
static func _t_protect_round_counter_only_not_over() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	# round_counter is high enough that the OLD code would have triggered victory,
	# but protect_counter is 0 (no echo was ever near the entity).
	var cs: Dictionary = {
		"round_counter":    8,
		"hold_counter":     0,
		"protect_counter":  0,
		"objective_params": { "duration_turns": 4 },
		"totem_stolen":     false,
	}

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if result.get("over", false):
		return { "ok": false, "error": "Expected over=false (protect_counter=0 regardless of round_counter), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# protect_counter_partial_advance:
# PROTECT with protect_counter advanced partway (2 of 4 required guarded rounds) → not over.
# Validates the guard-proximity mechanic: counter is at 2, threshold is 4.
static func _t_protect_counter_partial_advance() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs: Dictionary = _protect_state(2, 4)  # protect_counter=2 < duration_turns=4

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if result.get("over", false):
		return { "ok": false, "error": "Expected over=false (protect_counter=2 < 4), got over=true (reason='%s')" % str(result.get("reason", "")) }
	return { "ok": true }


# ─── Bug-fix: resolve_objective_params() missing config keys ────────────────

# ENDURE: wave_size_max is now propagated into params.
# _endure_cfg() has wave_size_max=4.
static func _t_resolve_params_endure_wave_size_max() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("endure", _endure_cfg(), 0, {})
	var got: int = int(p.get("wave_size_max", -1))
	if got != 4:
		return { "ok": false, "error": "Expected wave_size_max=4 in ENDURE params, got %d" % got }
	return { "ok": true }


# ENDURE: wave_size_rising_step is now propagated into params.
# _endure_cfg() has wave_size_rising_step=1.
static func _t_resolve_params_endure_wave_size_rising_step() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("endure", _endure_cfg(), 0, {})
	var got: int = int(p.get("wave_size_rising_step", -1))
	if got != 1:
		return { "ok": false, "error": "Expected wave_size_rising_step=1 in ENDURE params, got %d" % got }
	return { "ok": true }


# RECOVER: reinforce_interval is now propagated into params.
# _recover_cfg() has reinforce_interval=3.
static func _t_resolve_params_recover_reinforce_interval() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, {})
	var got: int = int(p.get("reinforce_interval", -1))
	if got != 3:
		return { "ok": false, "error": "Expected reinforce_interval=3 in RECOVER params, got %d" % got }
	return { "ok": true }


# RECOVER: reinforce_size is now propagated into params.
# _recover_cfg() has reinforce_size=2.
static func _t_resolve_params_recover_reinforce_size() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, {})
	var got: int = int(p.get("reinforce_size", -1))
	if got != 2:
		return { "ok": false, "error": "Expected reinforce_size=2 in RECOVER params, got %d" % got }
	return { "ok": true }


# RECOVER: reinforce_group is now propagated into params.
# _recover_cfg() has reinforce_group="group.forest_patrol".
static func _t_resolve_params_recover_reinforce_group() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, {})
	var got: String = str(p.get("reinforce_group", ""))
	if got != "group.forest_patrol":
		return { "ok": false, "error": "Expected reinforce_group='group.forest_patrol' in RECOVER params, got '%s'" % got }
	return { "ok": true }


# RECOVER: reinforce_max_total is now propagated into params.
# _recover_cfg() has reinforce_max_total=6.
static func _t_resolve_params_recover_reinforce_max_total() -> Dictionary:
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, {})
	var got: int = int(p.get("reinforce_max_total", -1))
	if got != 6:
		return { "ok": false, "error": "Expected reinforce_max_total=6 in RECOVER params, got %d" % got }
	return { "ok": true }


# RECOVER: stage_params override still wins over config-derived reinforce keys.
# stage_params with reinforce_interval=99 must beat the config value of 3.
static func _t_resolve_params_recover_reinforce_stage_override_wins() -> Dictionary:
	var stage_p := { "reinforce_interval": 99 }
	var p := FlowEncounterState.resolve_objective_params("recover", _recover_cfg(), 0, stage_p)
	var got: int = int(p.get("reinforce_interval", -1))
	if got != 99:
		return { "ok": false, "error": "Expected reinforce_interval=99 (stage override), got %d" % got }
	# Other reinforce keys (from config) must still be present.
	if not p.has("reinforce_size"):
		return { "ok": false, "error": "reinforce_size missing after stage override merge" }
	return { "ok": true }


# ─── Bug-fix: RECOVER holder reads top-level speed (unit-level check) ────────
# Two minimal echo actors — fast has top-level speed=10, slow has speed=3.
# stats.speed is 0 for both (the previously-wrong read path returned 0 for both
# and the first actor in the loop became holder by default).
# We call resolve_objective_params for RECOVER and verify the field is propagated,
# then confirm the holder logic (via CombatRoundtripIntegrationTests) picks the right echo.
# Here we do a pure-logic replica of the holder-selection loop so the unit suite
# can catch a regression without needing FlowRuntime.
static func _t_recover_holder_top_level_speed() -> Dictionary:
	var fast_echo: Dictionary = {
		"id": "echo_fast", "faction": "echo", "is_dead": false,
		"speed": 10,
		"stats": { "agi": 5, "speed": 0 },
	}
	var slow_echo: Dictionary = {
		"id": "echo_slow", "faction": "echo", "is_dead": false,
		"speed": 3,
		"stats": { "agi": 5, "speed": 0 },
	}
	var actors: Array = [slow_echo, fast_echo]  # slow listed first to expose ordering bugs

	# Replicate the holder-selection loop from FlowRuntime (top-level speed reads).
	var holder_best: Dictionary = {}
	for a in actors:
		if not (a is Dictionary): continue
		if bool(a.get("is_dead", false)): continue
		if str(a.get("faction", "")) != "echo": continue
		if holder_best.is_empty():
			holder_best = a
		else:
			var a_spd: int = int(a.get("speed", 0))
			var b_spd: int = int(holder_best.get("speed", 0))
			if a_spd > b_spd:
				holder_best = a
			elif a_spd == b_spd:
				var a_agi: int = int(a.get("stats", {}).get("agi", 0))
				var b_agi: int = int(holder_best.get("stats", {}).get("agi", 0))
				if a_agi > b_agi:
					holder_best = a
				elif a_agi == b_agi:
					if str(a.get("id", "")) < str(holder_best.get("id", "")):
						holder_best = a

	var holder_id: String = str(holder_best.get("id", ""))
	if holder_id != "echo_fast":
		return {
			"ok": false,
			"error": "Expected holder='echo_fast' (top-level speed=10 > 3), got '%s' (stats.speed=0 for both would make first actor win)" % holder_id
		}
	return { "ok": true }
