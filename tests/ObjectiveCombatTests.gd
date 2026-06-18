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
#          entity alive + round_counter >= duration_turns + living enemies → "protected" victory.
#   7. objective_combat/protect_not_over_short
#          entity alive + round_counter < duration_turns + living enemies → not over.
#   8. objective_combat/protect_all_enemies_dead_beats_duration
#          all enemies dead → "all_enemies_defeated" (first priority).
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


# 6. entity alive + round_counter >= duration_turns + living enemies → "protected" victory.
static func _t_protect_duration_met_victory() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs := _timed_state(4, 4)  # round_counter == duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (duration met), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true (protected), got victory=false" }
	if result.get("reason", "") != "protected":
		return { "ok": false, "error": "Expected reason='protected', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# 7. entity alive + round_counter < duration_turns + living enemies → not over.
static func _t_protect_not_over_short() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy("n1"), _structure("ward_0")]
	var cs := _timed_state(3, 4)  # round_counter < duration_turns

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.PROTECT, cs)

	if result.get("over", true):
		return { "ok": false, "error": "Expected over=false (duration not yet met), got over=true (reason='%s')" % str(result.get("reason", "")) }
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


# 12. all enemies dead → "all_enemies_defeated" (first priority over endure check).
static func _t_endure_all_enemies_dead_first() -> Dictionary:
	var actors: Array = [_echo("e1"), _enemy_dead("n1")]
	# Duration not met — but enemies all dead wins first.
	var cs := _timed_state(0, 10)

	var result := CombatState.check_end_condition(actors, EncounterResolutionModes.ENDURE, cs)

	if not result.get("over", false):
		return { "ok": false, "error": "Expected over=true (enemies dead), got over=false" }
	if not result.get("victory", false):
		return { "ok": false, "error": "Expected victory=true, got victory=false" }
	if result.get("reason", "") != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got '%s'" % str(result.get("reason", "")) }
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
