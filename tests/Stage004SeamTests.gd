# res://tests/Stage004SeamTests.gd
# V2-STAGE-004 Phase 4, S16b — seam + exclusion tests for the three
# conversation→combat seams (ally auto-join, hostile Claimant forced combat,
# failed-Charge pressure) plus the temporary-ally end-condition exclusion.
#
# Prefers direct unit-level assertions where the logic is a pure/static helper
# (CombatState.check_end_condition, FlowEncounterState._project_actor,
# FlowEncounterState.build_final_snapshot). Where the invariant lives inline in
# FlowRuntime._apply_contact_outcome or FlowEncounterState.enter(), drives a real
# (but minimal) FlowRuntime + FlowEncounterState the same way
# CombatRoundtripIntegrationTests.gd does — no full round-loop needed, since all
# these seams fire at contact-resolution / encounter-entry time, before combat
# actually starts.
#
# Test index:
#   1.  seam/ally_injection_adds_actor_and_marks_consumed   (integration)
#   1b. seam/ally_injection_places_on_walkable_unoccupied_cell (integration, playtest regression)
#   2.  seam/no_ally_contact_no_ally_actor                  (integration, control)
#   3.  seam/claimant_failed_forces_combat_and_sets_markers (integration)
#   4.  seam/nonobjective_charge_failed_sets_hostile_flag   (integration)
#   5.  seam/objective_charge_failed_does_not_set_hostile_flag (integration, control)
#   6.  seam/charge_pressure_bumps_protect_duration_and_clears_flag (integration)
#   7.  seam/charge_pressure_bumps_endure_wave_size_and_clears_flag (integration)
#   8.  seam/companion_invite_created_on_successful_roll       (instance-method unit)
#   9.  seam/companion_invite_same_encounter_second_call_does_not_reroll (instance-method unit)
#   10. seam/companion_invite_dead_ally_gate_no_invite         (instance-method unit)
#   11. seam/companion_invite_nonvictory_gate_no_invite        (instance-method unit)
#   12. seam/project_actor_is_ally_true                       (pure unit)
#   13. seam/project_actor_is_ally_false_control               (pure unit)
#   14. seam/final_snapshot_has_combat_intro_line_and_no_recruit_offer_key (pure unit)
#   15. seam/objective_state_has_charge_pressure_applied_bool  (pure unit)
#
# V2-STAGE-004 Phase 4 — Jeff's Sanctum-event redesign (moves the earned-return companion
# invite off the Resolve screen onto a Sanctum-scoped, no-stack, persists-until-decided inbox):
#   19. seam/companion_invite_failed_roll_no_invite             (instance-method unit)
#   20. seam/companion_invite_no_stack_does_not_overwrite_pending (instance-method unit)
#   21. seam/clear_ally_fields_clears_contact_and_intro_not_companion_invite (instance-method unit)
#   22. seam/companion_accept_promotes_and_clears_invite         (instance-method integration)
#   23. seam/companion_decline_clears_invite_mints_nothing        (instance-method integration)
#   24. seam/sanctum_snapshot_projects_companion_invite            (pure unit)
#   25. seam/sanctum_snapshot_companion_invite_empty_when_none_pending (pure unit)
#
# Codex review fix regressions (P4 follow-up):
#   26. seam/victory_return_clears_ally_fields_and_preserves_companion_invite (integration)
#   27. seam/final_snapshot_excludes_ally_and_spirit_from_echo_tally (pure unit)
#
# All tests deterministic — no randf/randomize/OS time. Any RNG use goes through
# CampaignSeed-derived / caller-seeded RandomNumberGenerator, per project invariant.

extends RefCounted
class_name Stage004SeamTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("seam/ally_injection_adds_actor_and_marks_consumed",
		Callable(Stage004SeamTests, "_t_ally_injection_adds_actor_and_marks_consumed"))
	runner.register_test("seam/ally_injection_places_on_walkable_unoccupied_cell",
		Callable(Stage004SeamTests, "_t_ally_injection_places_on_walkable_unoccupied_cell"))
	runner.register_test("seam/no_ally_contact_no_ally_actor",
		Callable(Stage004SeamTests, "_t_no_ally_contact_no_ally_actor"))
	runner.register_test("seam/claimant_failed_forces_combat_and_sets_markers",
		Callable(Stage004SeamTests, "_t_claimant_failed_forces_combat_and_sets_markers"))
	runner.register_test("seam/nonobjective_charge_failed_sets_hostile_flag",
		Callable(Stage004SeamTests, "_t_nonobjective_charge_failed_sets_hostile_flag"))
	runner.register_test("seam/objective_charge_failed_does_not_set_hostile_flag",
		Callable(Stage004SeamTests, "_t_objective_charge_failed_does_not_set_hostile_flag"))
	runner.register_test("seam/charge_pressure_bumps_protect_duration_and_clears_flag",
		Callable(Stage004SeamTests, "_t_charge_pressure_bumps_protect_duration_and_clears_flag"))
	runner.register_test("seam/charge_pressure_bumps_endure_wave_size_and_clears_flag",
		Callable(Stage004SeamTests, "_t_charge_pressure_bumps_endure_wave_size_and_clears_flag"))
	runner.register_test("seam/companion_invite_created_on_successful_roll",
		Callable(Stage004SeamTests, "_t_companion_invite_created_on_successful_roll"))
	runner.register_test("seam/companion_invite_same_encounter_second_call_does_not_reroll",
		Callable(Stage004SeamTests, "_t_companion_invite_same_encounter_second_call_does_not_reroll"))
	runner.register_test("seam/companion_invite_dead_ally_gate_no_invite",
		Callable(Stage004SeamTests, "_t_companion_invite_dead_ally_gate_no_invite"))
	runner.register_test("seam/companion_invite_nonvictory_gate_no_invite",
		Callable(Stage004SeamTests, "_t_companion_invite_nonvictory_gate_no_invite"))
	runner.register_test("seam/project_actor_is_ally_true",
		Callable(Stage004SeamTests, "_t_project_actor_is_ally_true"))
	runner.register_test("seam/project_actor_is_ally_false_control",
		Callable(Stage004SeamTests, "_t_project_actor_is_ally_false_control"))
	runner.register_test("seam/final_snapshot_has_combat_intro_line_and_no_recruit_offer_key",
		Callable(Stage004SeamTests, "_t_final_snapshot_has_combat_intro_line_and_no_recruit_offer_key"))
	runner.register_test("seam/objective_state_has_charge_pressure_applied_bool",
		Callable(Stage004SeamTests, "_t_objective_state_has_charge_pressure_applied_bool"))
	runner.register_test("seam/companion_invite_failed_roll_no_invite",
		Callable(Stage004SeamTests, "_t_companion_invite_failed_roll_no_invite"))
	runner.register_test("seam/companion_invite_no_stack_does_not_overwrite_pending",
		Callable(Stage004SeamTests, "_t_companion_invite_no_stack_does_not_overwrite_pending"))
	runner.register_test("seam/clear_ally_fields_clears_contact_and_intro_not_companion_invite",
		Callable(Stage004SeamTests, "_t_clear_ally_fields_clears_contact_and_intro_not_companion_invite"))
	runner.register_test("seam/companion_accept_promotes_and_clears_invite",
		Callable(Stage004SeamTests, "_t_companion_accept_promotes_and_clears_invite"))
	runner.register_test("seam/companion_decline_clears_invite_mints_nothing",
		Callable(Stage004SeamTests, "_t_companion_decline_clears_invite_mints_nothing"))
	runner.register_test("seam/sanctum_snapshot_projects_companion_invite",
		Callable(Stage004SeamTests, "_t_sanctum_snapshot_projects_companion_invite"))
	runner.register_test("seam/sanctum_snapshot_companion_invite_empty_when_none_pending",
		Callable(Stage004SeamTests, "_t_sanctum_snapshot_companion_invite_empty_when_none_pending"))
	# Codex review fix regression tests (P4 follow-up).
	runner.register_test("seam/victory_return_clears_ally_fields_and_preserves_companion_invite",
		Callable(Stage004SeamTests, "_t_victory_return_clears_ally_fields_and_preserves_companion_invite"))
	runner.register_test("seam/final_snapshot_excludes_ally_and_spirit_from_echo_tally",
		Callable(Stage004SeamTests, "_t_final_snapshot_excludes_ally_and_spirit_from_echo_tally"))


# ─────────────────────────────────────────────────────────────────────────────
# Shared setup — mirrors CombatRoundtripIntegrationTests.gd's _setup(): boot a
# real FlowRuntime, create realm.01 (irregular terrain + explore_map), and seed
# a small roster. Each test uses a unique tag → unique save path, so tests never
# share state.
# ─────────────────────────────────────────────────────────────────────────────
static func _boot_env(tag: String) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, "/tmp/echoes-vnext-tests/seam_" + tag + ".json")
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, t)
	if rm.is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0." + tag

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(3):
		var echo: Dictionary = EchoFactory.generate(tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		roster.append(echo)
		party_ids.append(str(echo.get("id", "")))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids

	return { "runtime": runtime, "flow_ctx": flow_ctx, "t": t }


# ─────────────────────────────────────────────────────────────────────────────
# 1-2. Ally injection (S12 auto-join) — FlowEncounterState.enter()
# ─────────────────────────────────────────────────────────────────────────────

# With explore_map.ally_contact set and ally_consumed_in_encounter false, entering
# the encounter injects an is_ally actor into the actor set and marks it consumed.
static func _t_ally_injection_adds_actor_and_marks_consumed() -> Dictionary:
	var env: Dictionary = _boot_env("ally_inject")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["ally_contact"] = { "id": "contact.ally.inject_test", "name": "Test Ally" }
	explore_map["ally_consumed_in_encounter"] = false
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var found_ally := false
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_ally", false)):
			found_ally = true
			break
	if not found_ally:
		return { "ok": false, "error": "No is_ally actor injected into ectx.actors despite explore_map.ally_contact being set" }

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if not bool(map_after.get("ally_consumed_in_encounter", false)):
		return { "ok": false, "error": "Expected explore_map.ally_consumed_in_encounter=true after ally auto-join" }
	return { "ok": true }


# Playtest regression: the auto-joined Temporary Ally must spawn on a real, walkable,
# unoccupied cell — not the EnemyActor.from_definition grid_pos placeholder { col:0,
# row:0 } (core/actors/EnemyActor.gd:75), which is VOID on _boot_env's irregular
# realm.01 terrain and left the ally stranded off-board with no legal move
# (GridService.move_toward roots over the walkable set — see
# core/state/flow/states/venture/FlowEncounterState.gd, ally auto-join block).
# _boot_env() already generates irregular terrain (RealmService.get_or_create for a
# real realm_id), so this exercises the exact board shape the playtest hit.
static func _t_ally_injection_places_on_walkable_unoccupied_cell() -> Dictionary:
	var env: Dictionary = _boot_env("ally_inject_pos")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["ally_contact"] = { "id": "contact.ally.inject_pos_test", "name": "Test Ally" }
	explore_map["ally_consumed_in_encounter"] = false
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	# Confirm this encounter actually generated irregular terrain — if it didn't
	# (e.g. legacy full-rect fallback), the walkable-void bug can't manifest and
	# this test would pass vacuously. Fail loudly instead of silently no-opping.
	if ectx.terrain.is_empty():
		return { "ok": false, "error": "Expected _boot_env's realm.01 encounter to generate irregular terrain (ectx.terrain empty) — cannot exercise the walkable-void regression" }
	var walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain)
	if walkable.is_empty():
		return { "ok": false, "error": "Expected a non-empty walkable set from ectx.terrain" }

	var ally_actor: Dictionary = {}
	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_ally", false)):
			ally_actor = a_v
			break
	if ally_actor.is_empty():
		return { "ok": false, "error": "No is_ally actor injected into ectx.actors despite explore_map.ally_contact being set" }

	var ally_pos: Dictionary = ally_actor.get("grid_pos", {})
	var ally_col: int = int(ally_pos.get("col", -1))
	var ally_row: int = int(ally_pos.get("row", -1))
	var ally_key: String = str(ally_col) + "," + str(ally_row)

	if ally_col == 0 and ally_row == 0:
		return { "ok": false, "error": "Ally spawned at the (0,0) void-default grid_pos instead of a real board cell — regression of the off-board playtest bug" }
	if not walkable.has(ally_key):
		return { "ok": false, "error": "Ally grid_pos %s is not in the board's walkable set — ally would spawn off-board (VOID)" % ally_key }

	# Uniqueness: the ally's cell must not coincide with any other actor's cell.
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var other: Dictionary = a_v
		if other.get("id", "") == ally_actor.get("id", ""):
			continue
		var op: Dictionary = other.get("grid_pos", {})
		if int(op.get("col", -2)) == ally_col and int(op.get("row", -2)) == ally_row:
			return { "ok": false, "error": "Ally grid_pos %s collides with actor '%s'" % [ally_key, str(other.get("id", ""))] }

	return { "ok": true }


# Control: with no ally_contact set, no is_ally actor should appear — byte-identical
# to an encounter with no ally at all.
static func _t_no_ally_contact_no_ally_actor() -> Dictionary:
	var env: Dictionary = _boot_env("ally_control")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	for a_v in ectx.actors:
		if a_v is Dictionary and bool((a_v as Dictionary).get("is_ally", false)):
			return { "ok": false, "error": "Unexpected is_ally actor present with no ally_contact set" }
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 3. Claimant failed → forced combat — FlowRuntime._apply_contact_outcome
# ─────────────────────────────────────────────────────────────────────────────

# A failed claimant outcome must set active_encounter_objective_index == -1 and
# durably mark explore_map.combat_intro_reason == "claimant_hostile" so the
# forced encounter resolves as plain COMBAT and can project the intro line.
static func _t_claimant_failed_forces_combat_and_sets_markers() -> Dictionary:
	var env: Dictionary = _boot_env("claimant_forced")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	# Non-trivial starting value proves the branch actively resets it, not that it
	# merely happened to already be -1.
	flow_ctx.active_encounter_objective_index = 2
	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	var sit_id := "sit_claimant_forced_test"
	var situations: Array = explore_map.get("situations", [])
	situations.append({ "id": sit_id, "resolved": false, "revealed": true, "is_objective": false, "objective_index": -1 })
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	var contact: Dictionary = { "id": sit_id, "role": "claimant", "outcome": "failed" }
	runtime._apply_contact_outcome(contact, stage, explore_map, t)

	if int(flow_ctx.active_encounter_objective_index) != -1:
		return {
			"ok": false,
			"error": "Expected active_encounter_objective_index=-1 after claimant-failed forced combat, got %d" \
				% int(flow_ctx.active_encounter_objective_index)
		}

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if str(map_after.get("combat_intro_reason", "")) != "claimant_hostile":
		return {
			"ok": false,
			"error": "Expected explore_map.combat_intro_reason='claimant_hostile', got '%s'" \
				% str(map_after.get("combat_intro_reason", ""))
		}
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 4-5. Charge pressure marker — FlowRuntime._apply_contact_outcome "charge" role
# ─────────────────────────────────────────────────────────────────────────────

# A failed NON-objective Charge raises pressure: explore_map.hostile_charge_sit_id
# is set to the failed situation's id (consumed once by the next PROTECT/ENDURE
# objective combat — see tests 6-7).
static func _t_nonobjective_charge_failed_sets_hostile_flag() -> Dictionary:
	var env: Dictionary = _boot_env("charge_nonobj")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	var sit_id := "sit_charge_nonobj_test"
	var situations: Array = explore_map.get("situations", [])
	situations.append({ "id": sit_id, "resolved": false, "revealed": true, "is_objective": false, "objective_index": -1 })
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	var contact: Dictionary = { "id": sit_id, "role": "charge", "outcome": "failed" }
	runtime._apply_contact_outcome(contact, stage, explore_map, t)

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if str(map_after.get("hostile_charge_sit_id", "")) != sit_id:
		return {
			"ok": false,
			"error": "Expected explore_map.hostile_charge_sit_id='%s', got '%s'" \
				% [sit_id, str(map_after.get("hostile_charge_sit_id", ""))]
		}
	return { "ok": true }


# Control: a failed OBJECTIVE Charge keeps its existing abandon-the-stage path and
# must NOT set hostile_charge_sit_id (that marker is non-objective-only).
static func _t_objective_charge_failed_does_not_set_hostile_flag() -> Dictionary:
	var env: Dictionary = _boot_env("charge_obj")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	var sit_id := "sit_charge_obj_test"
	var situations: Array = explore_map.get("situations", [])
	situations.append({ "id": sit_id, "resolved": false, "revealed": true, "is_objective": true, "objective_index": 0 })
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	var contact: Dictionary = { "id": sit_id, "role": "charge", "outcome": "failed" }
	runtime._apply_contact_outcome(contact, stage, explore_map, t)

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if not str(map_after.get("hostile_charge_sit_id", "")).is_empty():
		return {
			"ok": false,
			"error": "Objective Charge fail must not set hostile_charge_sit_id, got '%s'" \
				% str(map_after.get("hostile_charge_sit_id", ""))
		}
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 6-7. Charge pressure consumption — FlowEncounterState.enter() objective bump
# ─────────────────────────────────────────────────────────────────────────────

# When explore_map.hostile_charge_sit_id is set, the next PROTECT objective combat's
# duration_turns is bumped +1 (data.combat.charge_pressure.protect_duration_bonus)
# vs. the unflagged baseline, ectx.charge_pressure_applied is set true, and the
# flag is cleared (consumed exactly once).
static func _t_charge_pressure_bumps_protect_duration_and_clears_flag() -> Dictionary:
	# Baseline: fresh realm, PROTECT objective, no hostile_charge_sit_id set.
	var env_base: Dictionary = _boot_env("charge_protect_base")
	if env_base.is_empty():
		return { "ok": false, "error": "baseline setup failed (realm not created)" }
	var flow_ctx_base: FlowContext = env_base["flow_ctx"]
	var t: int = env_base["t"]
	flow_ctx_base.dev_combat_objective = EncounterResolutionModes.PROTECT
	flow_ctx_base.encounter_ctx = null
	flow_ctx_base.encounter_machine = null
	var enc_base := FlowEncounterState.new()
	enc_base.enter(flow_ctx_base, t)
	var baseline_duration: int = int(flow_ctx_base.encounter_ctx.objective_params.get("duration_turns", -1))
	if baseline_duration < 0:
		return { "ok": false, "error": "baseline PROTECT objective_params.duration_turns missing" }

	# Bumped: separate fresh env, hostile_charge_sit_id pre-set BEFORE enter().
	var env_bumped: Dictionary = _boot_env("charge_protect_bumped")
	if env_bumped.is_empty():
		return { "ok": false, "error": "bumped setup failed (realm not created)" }
	var flow_ctx_bumped: FlowContext = env_bumped["flow_ctx"]
	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx_bumped)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["hostile_charge_sit_id"] = "sit_pressure_protect_test"
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx_bumped, stage)

	flow_ctx_bumped.dev_combat_objective = EncounterResolutionModes.PROTECT
	flow_ctx_bumped.encounter_ctx = null
	flow_ctx_bumped.encounter_machine = null
	var enc_bumped := FlowEncounterState.new()
	enc_bumped.enter(flow_ctx_bumped, t)
	var bumped_duration: int = int(flow_ctx_bumped.encounter_ctx.objective_params.get("duration_turns", -1))

	if bumped_duration != baseline_duration + 1:
		return {
			"ok": false,
			"error": "Expected PROTECT duration_turns bumped by +1 (baseline=%d, bumped=%d)" \
				% [baseline_duration, bumped_duration]
		}
	if not bool(flow_ctx_bumped.encounter_ctx.charge_pressure_applied):
		return { "ok": false, "error": "Expected ectx.charge_pressure_applied=true after PROTECT charge-pressure bump" }

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx_bumped)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if not str(map_after.get("hostile_charge_sit_id", "x")).is_empty():
		return {
			"ok": false,
			"error": "Expected explore_map.hostile_charge_sit_id cleared (consumed once) after PROTECT combat entered, got '%s'" \
				% str(map_after.get("hostile_charge_sit_id", ""))
		}
	return { "ok": true }


# Same as above for ENDURE's wave_size (data.combat.charge_pressure.endure_wave_bonus).
static func _t_charge_pressure_bumps_endure_wave_size_and_clears_flag() -> Dictionary:
	var env_base: Dictionary = _boot_env("charge_endure_base")
	if env_base.is_empty():
		return { "ok": false, "error": "baseline setup failed (realm not created)" }
	var flow_ctx_base: FlowContext = env_base["flow_ctx"]
	var t: int = env_base["t"]
	flow_ctx_base.dev_combat_objective = EncounterResolutionModes.ENDURE
	flow_ctx_base.encounter_ctx = null
	flow_ctx_base.encounter_machine = null
	var enc_base := FlowEncounterState.new()
	enc_base.enter(flow_ctx_base, t)
	var baseline_wave_size: int = int(flow_ctx_base.encounter_ctx.objective_params.get("wave_size", -1))
	if baseline_wave_size < 0:
		return { "ok": false, "error": "baseline ENDURE objective_params.wave_size missing" }

	var env_bumped: Dictionary = _boot_env("charge_endure_bumped")
	if env_bumped.is_empty():
		return { "ok": false, "error": "bumped setup failed (realm not created)" }
	var flow_ctx_bumped: FlowContext = env_bumped["flow_ctx"]
	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx_bumped)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["hostile_charge_sit_id"] = "sit_pressure_endure_test"
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx_bumped, stage)

	flow_ctx_bumped.dev_combat_objective = EncounterResolutionModes.ENDURE
	flow_ctx_bumped.encounter_ctx = null
	flow_ctx_bumped.encounter_machine = null
	var enc_bumped := FlowEncounterState.new()
	enc_bumped.enter(flow_ctx_bumped, t)
	var bumped_wave_size: int = int(flow_ctx_bumped.encounter_ctx.objective_params.get("wave_size", -1))

	if bumped_wave_size != baseline_wave_size + 1:
		return {
			"ok": false,
			"error": "Expected ENDURE wave_size bumped by +1 (baseline=%d, bumped=%d)" \
				% [baseline_wave_size, bumped_wave_size]
		}
	if not bool(flow_ctx_bumped.encounter_ctx.charge_pressure_applied):
		return { "ok": false, "error": "Expected ectx.charge_pressure_applied=true after ENDURE charge-pressure bump" }

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx_bumped)
	var map_after: Dictionary = stage_after.get("explore_map", {})
	if not str(map_after.get("hostile_charge_sit_id", "x")).is_empty():
		return {
			"ok": false,
			"error": "Expected explore_map.hostile_charge_sit_id cleared (consumed once) after ENDURE combat entered, got '%s'" \
				% str(map_after.get("hostile_charge_sit_id", ""))
		}
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 8-11, 19-20. Companion invite compute-once / no-stack / gating — FlowRuntime
# instance method _compute_ally_recruit_offer_if_eligible(is_victory, rounds_total, t).
# Called directly (underscore is convention only; no real GDScript privacy —
# precedent: LeadershipEmotionTests.gd calls runtime._apply_kill_momentum(...)).
# flow_ctx.dev_force_recruit forces the roll outcome ("success"/"fail") so these
# tests don't depend on the seeded roll landing a particular way.
# ─────────────────────────────────────────────────────────────────────────────

# Builds a minimal env with a joined is_ally actor + a source ally_contact on
# explore_map — the two preconditions _compute_ally_recruit_offer_if_eligible
# requires before it will write anything.
static func _make_ally_offer_env(tag: String, ally_dead: bool = false) -> Dictionary:
	var env: Dictionary = _boot_env(tag)
	if env.is_empty():
		return {}
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]

	var ectx := EncounterContext.new()
	ectx.encounter_id = flow_ctx.encounter_id
	ectx.echo_action_logs = {
		"ally_test_01": { "damage_dealt": 20, "damage_taken": 10, "kills": 1 },
	}
	var ally_actor: Dictionary = {
		"id": "ally_test_01", "name": "Test Ally", "faction": "echo",
		"is_ally": true, "is_dead": ally_dead, "current_hp": 50, "death_round": 0,
		"stats": { "max_hp": 60 }, "traits": { "courage": 60, "wisdom": 50, "faith": 40 },
		"archetype_birth": "warrior", "vector_scores": {},
	}
	ectx.actors = [ally_actor]
	flow_ctx.encounter_ctx = ectx

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["ally_contact"] = {
		"id": "contact.ally.offer_test", "name": "Test Ally",
		"virtue_primary": "courage", "virtue_secondary": "wisdom",
		"morale": 70, "fear": 10, "conv_score_sum": 5.0, "winning_turns": 2, "turn_count": 3,
	}
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	return { "runtime": runtime, "flow_ctx": flow_ctx, "ectx": ectx }


# V2-STAGE-004 Phase 4 redesign: the invite now lives on save_data.sanctum.companion_invite
# (a one-slot Sanctum inbox), not on explore_map.
static func _read_companion_invite(flow_ctx: FlowContext) -> Dictionary:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var invite_v: Variant = sanctum.get("companion_invite", {})
	return invite_v if invite_v is Dictionary else {}


# A living joined ally + victory + a source ally_contact + a successful (forced) roll →
# a companion invite is written to sanctum.companion_invite with the expected shape.
# The invite must NOT carry encounter_id/rolled_success — those only made sense when the
# offer lived on the resolve screen; an invite in the Sanctum inbox only ever exists because
# the roll succeeded.
static func _t_companion_invite_created_on_successful_roll() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_created")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.dev_force_recruit = "success"

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 0)

	var invite: Dictionary = _read_companion_invite(flow_ctx)
	if invite.is_empty():
		return { "ok": false, "error": "Expected sanctum.companion_invite to be written for a victorious encounter with a living joined ally and a successful roll" }
	if not invite.has("chance") or not invite.has("ally_name") or not invite.has("ally_actor") or not invite.has("source_contact"):
		return { "ok": false, "error": "companion_invite missing expected keys (chance/ally_name/ally_actor/source_contact)" }
	if invite.has("encounter_id"):
		return { "ok": false, "error": "companion_invite should not carry 'encounter_id' — that was a resolve-offer-only field" }
	if invite.has("rolled_success"):
		return { "ok": false, "error": "companion_invite should not carry 'rolled_success' — an invite only exists when the roll succeeded" }
	return { "ok": true }


# Compute-once guard: a second call for the SAME encounter_id must not re-roll (and must not
# touch the already-written invite), even if the ally's underlying state changed between calls.
static func _t_companion_invite_same_encounter_second_call_does_not_reroll() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_noreroll")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	flow_ctx.dev_force_recruit = "success"

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 0)
	var invite1: Dictionary = _read_companion_invite(flow_ctx).duplicate(true)
	if invite1.is_empty():
		return { "ok": false, "error": "first call did not write a companion invite" }

	# Mutate the ally drastically — if the second call recomputed, the combat
	# component (and very likely chance) would differ.
	(ectx.actors[0] as Dictionary)["current_hp"] = 1
	ectx.echo_action_logs["ally_test_01"] = { "damage_dealt": 0, "damage_taken": 0, "kills": 0 }

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 1)
	var invite2: Dictionary = _read_companion_invite(flow_ctx)

	if int(invite2.get("chance", -1)) != int(invite1.get("chance", -2)):
		return {
			"ok": false,
			"error": "Expected identical chance across calls for the same encounter_id (no re-roll), got %d vs %d" \
				% [int(invite1.get("chance", -2)), int(invite2.get("chance", -1))]
		}
	return { "ok": true }


# Gate: a dead ally (even on victory, even with a forced-success roll) must not produce an
# invite — the dead-ally gate runs before the roll is ever evaluated.
static func _t_companion_invite_dead_ally_gate_no_invite() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_dead_gate", true)
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.dev_force_recruit = "success"

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 0)

	var invite: Dictionary = _read_companion_invite(flow_ctx)
	if not invite.is_empty():
		return { "ok": false, "error": "Expected no companion_invite written when the joined ally is dead" }
	return { "ok": true }


# Gate: a non-victory (even with a living ally, even with a forced-success roll) must not
# produce an invite.
static func _t_companion_invite_nonvictory_gate_no_invite() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_nonvictory_gate")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.dev_force_recruit = "success"

	runtime._compute_ally_recruit_offer_if_eligible(false, 3, 0)

	var invite: Dictionary = _read_companion_invite(flow_ctx)
	if not invite.is_empty():
		return { "ok": false, "error": "Expected no companion_invite written when the encounter was not a victory" }
	return { "ok": true }


# A forced-fail roll on an otherwise-eligible victory must produce no invite at all (the new
# model only ever writes to sanctum.companion_invite on success — there is no persisted
# "failed offer" record like the old resolve-screen field had).
static func _t_companion_invite_failed_roll_no_invite() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_failed_roll")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	flow_ctx.dev_force_recruit = "fail"

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 0)

	var invite: Dictionary = _read_companion_invite(flow_ctx)
	if not invite.is_empty():
		return { "ok": false, "error": "Expected no companion_invite written when the roll fails" }
	return { "ok": true }


# No-stack guard: a SECOND, DIFFERENT victorious encounter's successful roll must not
# overwrite a companion invite that's already pending — one waiting companion max. Uses a
# different encounter_id (not a repeat of the same one) so this exercises the no-stack guard
# specifically, distinct from the same-encounter compute-once guard tested above.
static func _t_companion_invite_no_stack_does_not_overwrite_pending() -> Dictionary:
	var env: Dictionary = _make_ally_offer_env("invite_nostack")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var ectx: EncounterContext = env["ectx"]
	flow_ctx.dev_force_recruit = "success"

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 0)
	var invite1: Dictionary = _read_companion_invite(flow_ctx).duplicate(true)
	if invite1.is_empty():
		return { "ok": false, "error": "first encounter did not write a companion invite" }

	# Simulate a second, later victorious encounter with a different joined ally.
	ectx.encounter_id = str(flow_ctx.encounter_id) + ".second"
	(ectx.actors[0] as Dictionary)["id"] = "ally_test_02"
	(ectx.actors[0] as Dictionary)["name"] = "Second Ally"
	ectx.echo_action_logs = {
		"ally_test_02": { "damage_dealt": 20, "damage_taken": 10, "kills": 1 },
	}

	runtime._compute_ally_recruit_offer_if_eligible(true, 3, 1)
	var invite2: Dictionary = _read_companion_invite(flow_ctx)

	if str(invite2.get("ally_name", "")) != str(invite1.get("ally_name", "")):
		return {
			"ok": false,
			"error": "Expected the pending companion invite to survive a second (different-encounter) successful roll unchanged (no-stack), got ally_name '%s' instead of '%s'" \
				% [str(invite2.get("ally_name", "")), str(invite1.get("ally_name", ""))]
		}
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 12-15. Projection shapes — pure static helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _minimal_actor(overrides: Dictionary = {}) -> Dictionary:
	var a: Dictionary = {
		"id": "proj_test_actor", "name": "Proj Test", "faction": "echo",
		"current_hp": 40, "is_dead": false,
		"stats": { "max_hp": 40 }, "morale": 50, "fear": 0,
		"grid_pos": { "col": 0, "row": 0 }, "skill_slots": [""],
	}
	for k in overrides:
		a[k] = overrides[k]
	return a


# _project_actor(actor_with_is_ally) output must carry is_ally (bool) == true.
static func _t_project_actor_is_ally_true() -> Dictionary:
	var actor: Dictionary = _minimal_actor({ "is_ally": true })
	var proj: Dictionary = FlowEncounterState._project_actor(actor)

	if not proj.has("is_ally"):
		return { "ok": false, "error": "projected actor missing 'is_ally' key" }
	if typeof(proj["is_ally"]) != TYPE_BOOL:
		return { "ok": false, "error": "projected actor 'is_ally' is not a bool (got type %d)" % typeof(proj["is_ally"]) }
	if not bool(proj["is_ally"]):
		return { "ok": false, "error": "expected projected is_ally == true" }
	return { "ok": true }


# Control: an actor without is_ally set projects is_ally == false.
static func _t_project_actor_is_ally_false_control() -> Dictionary:
	var actor: Dictionary = _minimal_actor()
	var proj: Dictionary = FlowEncounterState._project_actor(actor)

	if not proj.has("is_ally"):
		return { "ok": false, "error": "projected actor missing 'is_ally' key" }
	if bool(proj["is_ally"]):
		return { "ok": false, "error": "expected projected is_ally == false for a normal echo actor" }
	return { "ok": true }


# V2-STAGE-004 Phase 4 redesign: build_final_snapshot's data dict must NO LONGER carry an
# 'ally_recruit_offer' key at all (the earned-return companion invite moved to the Sanctum —
# see FlowSanctumState / sanctum.companion.accept/decline), while combat_intro_line (String)
# is untouched and still populated when the save-data-backed stage explore_map carries it.
# Also asserts no cta.recruit_accept/decline CTAs are ever emitted on resolve.
static func _t_final_snapshot_has_combat_intro_line_and_no_recruit_offer_key() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()

	var ctx := FlowContext.new()
	ctx.config_service = cs
	ctx.realm_id = "realm.01"
	ctx.stage_id = "stage.0"
	ctx.save_data = {
		"realms": {
			"realm.01": {
				"stages": [
					{
						"index": 0,
						"explore_map": {
							"combat_intro_reason": "claimant_hostile",
						},
					},
				],
			},
		},
	}

	var ectx := EncounterContext.new()
	ectx.encounter_id  = "test_enc_final_snap"
	ectx.placement_seed = 1
	ectx.actors = []
	ectx.combat_state  = { "combat_over": true, "objective": "defeat_enemies", "round_counter": 2 }
	ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 2 }
	ctx.encounter_ctx = ectx

	var snap: Dictionary = FlowEncounterState.build_final_snapshot(ctx, 1)
	var data: Dictionary = snap.get("data", {})

	if data.has("ally_recruit_offer"):
		return { "ok": false, "error": "final snapshot data must no longer carry 'ally_recruit_offer' — the invite moved to the Sanctum (V2-STAGE-004 Phase 4 redesign)" }

	if not data.has("combat_intro_line"):
		return { "ok": false, "error": "final snapshot data missing 'combat_intro_line' key" }
	if typeof(data["combat_intro_line"]) != TYPE_STRING:
		return { "ok": false, "error": "final snapshot 'combat_intro_line' is not a String" }
	if str(data["combat_intro_line"]).is_empty():
		return { "ok": false, "error": "expected a non-empty combat_intro_line when combat_intro_reason='claimant_hostile'" }

	var actions: Dictionary = snap.get("actions", {})
	if actions.has("cta.recruit_accept") or actions.has("cta.recruit_decline"):
		return { "ok": false, "error": "final snapshot actions must never contain recruit CTAs — decisions now happen via sanctum.companion.accept/decline" }

	return { "ok": true }


# _build_objective_state's output must carry charge_pressure_applied (bool),
# reflecting ectx.charge_pressure_applied.
static func _t_objective_state_has_charge_pressure_applied_bool() -> Dictionary:
	var ectx_false := EncounterContext.new()
	ectx_false.resolution_mode = "defeat_enemies"
	ectx_false.actors = []
	ectx_false.charge_pressure_applied = false
	var state_false: Dictionary = FlowEncounterState._build_objective_state(ectx_false, {})
	if not state_false.has("charge_pressure_applied"):
		return { "ok": false, "error": "objective_state missing 'charge_pressure_applied' key" }
	if typeof(state_false["charge_pressure_applied"]) != TYPE_BOOL:
		return { "ok": false, "error": "objective_state 'charge_pressure_applied' is not a bool" }
	if bool(state_false["charge_pressure_applied"]):
		return { "ok": false, "error": "expected charge_pressure_applied == false by default" }

	var ectx_true := EncounterContext.new()
	ectx_true.resolution_mode = "protect"
	ectx_true.actors = []
	ectx_true.charge_pressure_applied = true
	var state_true: Dictionary = FlowEncounterState._build_objective_state(ectx_true, {})
	if not bool(state_true.get("charge_pressure_applied", false)):
		return { "ok": false, "error": "expected charge_pressure_applied == true when ectx.charge_pressure_applied is true" }

	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 21-25. V2-STAGE-004 Phase 4 — Jeff's Sanctum-event redesign: teardown must leave the
# Sanctum-scoped invite alone, and the new sanctum.companion.accept/decline actions +
# FlowSanctumState projection must behave correctly.
# ─────────────────────────────────────────────────────────────────────────────

# Encounter teardown (_clear_ally_fields_if_present) must still clear the encounter-scoped
# ally_contact / ally_contact_id / ally_consumed_in_encounter / combat_intro_reason fields,
# but must NOT touch a pending sanctum.companion_invite — the invite is Sanctum-scoped now
# and persists until the player explicitly accepts/declines it (no auto-clear on teardown).
static func _t_clear_ally_fields_clears_contact_and_intro_not_companion_invite() -> Dictionary:
	var env: Dictionary = _boot_env("clear_fields")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["ally_contact"] = { "id": "contact.ally.clear_test", "name": "Test Ally" }
	explore_map["ally_contact_id"] = "contact.ally.clear_test"
	explore_map["ally_consumed_in_encounter"] = true
	explore_map["combat_intro_reason"] = "claimant_hostile"
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	flow_ctx.save_data["sanctum"]["companion_invite"] = {
		"chance": 60, "ally_name": "Pending Ally",
	}

	runtime._clear_ally_fields_if_present(t)

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})

	if not (map_after.get("ally_contact", { "__missing__": true }) as Dictionary).is_empty():
		return { "ok": false, "error": "Expected explore_map.ally_contact cleared to {}" }
	if str(map_after.get("ally_contact_id", "unset")) != "":
		return { "ok": false, "error": "Expected explore_map.ally_contact_id cleared to ''" }
	if not str(map_after.get("combat_intro_reason", "unset")).is_empty():
		return { "ok": false, "error": "Expected explore_map.combat_intro_reason cleared to ''" }

	var invite_after: Dictionary = _read_companion_invite(flow_ctx)
	if invite_after.is_empty() or str(invite_after.get("ally_name", "")) != "Pending Ally":
		return { "ok": false, "error": "Expected sanctum.companion_invite to survive encounter teardown untouched, got %s" % str(invite_after) }
	return { "ok": true }


# sanctum.companion.accept must promote the pending invite into exactly one new roster echo
# (via RecruitmentService.promote_ally_to_echo), clear sanctum.companion_invite, and rebuild
# the Sanctum snapshot so the returned snapshot's data.companion_invite reads back {}
# (proves the modal would dismiss).
static func _t_companion_accept_promotes_and_clears_invite() -> Dictionary:
	var env: Dictionary = _boot_env("companion_accept")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]

	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.SANCTUM })

	var roster_before: Array = flow_ctx.save_data["sanctum"]["roster"]
	var roster_size_before: int = roster_before.size()

	flow_ctx.save_data["sanctum"]["companion_invite"] = {
		"chance": 80, "conversation": 10, "combat": 10, "fit": 10, "cap": 75,
		"ally_name": "Accepted Ally",
		"ally_actor": {
			"id": "ally_test_accept", "name": "Accepted Ally", "faction": "echo",
			"is_ally": true, "is_dead": false, "current_hp": 50,
			"stats": { "max_hp": 60 }, "traits": { "courage": 60, "wisdom": 50, "faith": 40 },
			"archetype_birth": "warrior", "vector_scores": {},
		},
		"source_contact": {
			"id": "contact.ally.accept_test", "name": "Accepted Ally",
			"virtue_primary": "courage", "virtue_secondary": "wisdom",
		},
	}

	var out: Dictionary = runtime.dispatch({ "type": "sanctum.companion.accept" })

	var roster_after: Array = flow_ctx.save_data["sanctum"]["roster"]
	if roster_after.size() != roster_size_before + 1:
		return {
			"ok": false,
			"error": "Expected roster size to grow by 1 after sanctum.companion.accept (%d -> %d), got %d" \
				% [roster_size_before, roster_size_before + 1, roster_after.size()]
		}

	var invite_after: Dictionary = _read_companion_invite(flow_ctx)
	if not invite_after.is_empty():
		return { "ok": false, "error": "Expected sanctum.companion_invite cleared to {} after accept, got %s" % str(invite_after) }

	var data_out: Dictionary = out.get("data", {})
	if not (data_out.get("companion_invite", { "__missing__": true }) as Dictionary).is_empty():
		return { "ok": false, "error": "Expected the post-accept Sanctum snapshot to project companion_invite == {}" }

	return { "ok": true }


# sanctum.companion.decline must clear sanctum.companion_invite and mint nothing (roster size
# unchanged), and the returned snapshot's data.companion_invite must read back {}.
static func _t_companion_decline_clears_invite_mints_nothing() -> Dictionary:
	var env: Dictionary = _boot_env("companion_decline")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]

	runtime.dispatch({ "type": "flow.go_state", "to": FlowStateIds.SANCTUM })

	var roster_before: Array = flow_ctx.save_data["sanctum"]["roster"]
	var roster_size_before: int = roster_before.size()

	flow_ctx.save_data["sanctum"]["companion_invite"] = {
		"chance": 80, "ally_name": "Declined Ally",
		"ally_actor": { "id": "ally_test_decline", "name": "Declined Ally" },
		"source_contact": { "id": "contact.ally.decline_test", "name": "Declined Ally" },
	}

	var out: Dictionary = runtime.dispatch({ "type": "sanctum.companion.decline" })

	var roster_after: Array = flow_ctx.save_data["sanctum"]["roster"]
	if roster_after.size() != roster_size_before:
		return {
			"ok": false,
			"error": "Expected roster size unchanged after sanctum.companion.decline (%d), got %d" \
				% [roster_size_before, roster_after.size()]
		}

	var invite_after: Dictionary = _read_companion_invite(flow_ctx)
	if not invite_after.is_empty():
		return { "ok": false, "error": "Expected sanctum.companion_invite cleared to {} after decline, got %s" % str(invite_after) }

	var data_out: Dictionary = out.get("data", {})
	if not (data_out.get("companion_invite", { "__missing__": true }) as Dictionary).is_empty():
		return { "ok": false, "error": "Expected the post-decline Sanctum snapshot to project companion_invite == {}" }

	return { "ok": true }


# FlowSanctumState.enter() must project data.companion_invite from
# save_data.sanctum.companion_invite when a companion invite is pending.
static func _t_sanctum_snapshot_projects_companion_invite() -> Dictionary:
	var env: Dictionary = _boot_env("sanctum_projects_invite")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	flow_ctx.save_data["sanctum"]["companion_invite"] = {
		"chance": 55, "ally_name": "Projected Ally",
	}

	var state := FlowSanctumState.new()
	state.enter(flow_ctx, t)

	var data: Dictionary = flow_ctx.last_snapshot.get("data", {})
	if not data.has("companion_invite"):
		return { "ok": false, "error": "flow.sanctum snapshot data missing 'companion_invite' key" }
	var invite: Dictionary = data["companion_invite"]
	if str(invite.get("ally_name", "")) != "Projected Ally":
		return { "ok": false, "error": "Expected companion_invite to project the pending sanctum.companion_invite, got %s" % str(invite) }
	return { "ok": true }


# Control: with no companion_invite pending, the Sanctum snapshot must project {}.
static func _t_sanctum_snapshot_companion_invite_empty_when_none_pending() -> Dictionary:
	var env: Dictionary = _boot_env("sanctum_no_invite")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	var state := FlowSanctumState.new()
	state.enter(flow_ctx, t)

	var data: Dictionary = flow_ctx.last_snapshot.get("data", {})
	var invite_v: Variant = data.get("companion_invite", { "__missing__": true })
	if not (invite_v is Dictionary) or not (invite_v as Dictionary).is_empty():
		return { "ok": false, "error": "Expected companion_invite == {} when no invite is pending, got %s" % str(invite_v) }
	return { "ok": true }


# ─────────────────────────────────────────────────────────────────────────────
# 26-27. Codex review fix regressions (P4 follow-up)
# ─────────────────────────────────────────────────────────────────────────────

# BUG 1 regression: _apply_victory_return_to_explore() (the non-final-objective
# victory path, "flow.go_state"→STAGE_EXPLORE while flow_machine is in ENCOUNTER)
# must clear the encounter-scoped ally/intro fields the same way every other
# teardown path does (defeat go_state→SANCTUM, retreat, encounter.complete,
# _handle_complete_stage) — otherwise a stale ally_consumed_in_encounter=true
# leaks onto the next objective in the same multi-objective stage and a SECOND
# earned ally never joins. A pending sanctum.companion_invite must survive
# untouched, since it is Sanctum-scoped (not encounter-scoped) and is captured
# at combat-end time (_compute_ally_recruit_offer_if_eligible), strictly before
# this handler ever runs.
static func _t_victory_return_clears_ally_fields_and_preserves_companion_invite() -> Dictionary:
	var env: Dictionary = _boot_env("victory_return_clear")
	if env.is_empty():
		return { "ok": false, "error": "setup failed (realm not created)" }
	var runtime = env["runtime"]
	var flow_ctx: FlowContext = env["flow_ctx"]
	var t: int = env["t"]

	# Simulate a PRIOR ally auto-join in this same multi-objective stage that was
	# never torn down — the exact leak this bug produces without the fix.
	var stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var explore_map: Dictionary = stage.get("explore_map", {})
	explore_map["ally_contact"] = { "id": "contact.ally.victory_return_test", "name": "Stale Ally" }
	explore_map["ally_contact_id"] = "contact.ally.victory_return_test"
	explore_map["ally_consumed_in_encounter"] = true
	explore_map["combat_intro_reason"] = "claimant_hostile"
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)

	# A pending Sanctum companion invite (from an earlier, unrelated victory) must
	# survive this teardown untouched — it is not encounter-scoped.
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	flow_ctx.save_data["sanctum"]["companion_invite"] = {
		"chance": 55, "ally_name": "Untouched Companion",
	}

	# Build a real encounter_ctx (mirrors _boot_env-style setup used elsewhere in this
	# file) and mark it a victory, then put the flow machine in ENCOUNTER — the exact
	# precondition _apply_victory_return_to_explore() checks before it runs its body.
	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	flow_ctx.encounter_ctx.combat_result = {
		"victory": true, "reason": "all_enemies_defeated", "round_ended": 2,
	}
	runtime.flow_machine._current_state_id = FlowStateIds.ENCOUNTER

	runtime._apply_victory_return_to_explore(t)

	var stage_after: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	var map_after: Dictionary = stage_after.get("explore_map", {})

	if bool(map_after.get("ally_consumed_in_encounter", true)):
		return { "ok": false, "error": "Expected explore_map.ally_consumed_in_encounter reset to false after victory-return teardown (BUG 1 regression)" }
	if not (map_after.get("ally_contact", { "__missing__": true }) as Dictionary).is_empty():
		return { "ok": false, "error": "Expected explore_map.ally_contact cleared to {} after victory-return teardown" }
	if str(map_after.get("ally_contact_id", "unset")) != "":
		return { "ok": false, "error": "Expected explore_map.ally_contact_id cleared to ''" }
	if not str(map_after.get("combat_intro_reason", "unset")).is_empty():
		return { "ok": false, "error": "Expected explore_map.combat_intro_reason cleared to ''" }

	var invite_after: Dictionary = _read_companion_invite(flow_ctx)
	if invite_after.is_empty() or str(invite_after.get("ally_name", "")) != "Untouched Companion":
		return { "ok": false, "error": "Expected sanctum.companion_invite to survive victory-return teardown untouched, got %s" % str(invite_after) }

	return { "ok": true }


# BUG 2 regression: build_final_snapshot()'s echo tally (total_echoes / echoes_survived,
# which feed RewardCalc's echo_bonus and rank denominator) must exclude combatants with
# is_ally == true or is_spirit == true — they are temporary combat participants, not
# roster echoes. Compares a snapshot with 3 roster echoes (2 alive, 1 dead) against an
# otherwise-identical snapshot that ALSO has a living joined ally and a dead joined
# spirit: echoes_survived, rank, and ase_awarded must be byte-identical, since the
# non-roster combatants must not move the tally either way.
static func _t_final_snapshot_excludes_ally_and_spirit_from_echo_tally() -> Dictionary:
	var roster_actors: Array = [
		_minimal_actor({ "id": "roster_echo_1", "name": "Roster Echo 1", "faction": "echo",
			"current_hp": 40, "is_dead": false }),
		_minimal_actor({ "id": "roster_echo_2", "name": "Roster Echo 2", "faction": "echo",
			"current_hp": 40, "is_dead": false }),
		_minimal_actor({ "id": "roster_echo_3", "name": "Roster Echo 3", "faction": "echo",
			"current_hp": 0, "is_dead": true }),
		_minimal_actor({ "id": "enemy_1", "name": "Enemy 1", "faction": "enemy",
			"current_hp": 0, "is_dead": true }),
	]
	var actors_with_ally_and_spirit: Array = roster_actors.duplicate(true)
	actors_with_ally_and_spirit.append(_minimal_actor({
		"id": "joined_ally_1", "name": "Joined Ally", "faction": "echo",
		"current_hp": 30, "is_dead": false, "is_ally": true,
	}))
	actors_with_ally_and_spirit.append(_minimal_actor({
		"id": "joined_spirit_1", "name": "Joined Spirit", "faction": "echo",
		"current_hp": 0, "is_dead": true, "is_spirit": true,
	}))

	var snap_baseline: Dictionary = _final_snapshot_for_actors(roster_actors, "test_enc_tally_baseline")
	var snap_with_ally_spirit: Dictionary = _final_snapshot_for_actors(actors_with_ally_and_spirit, "test_enc_tally_ally_spirit")

	var data_baseline: Dictionary = snap_baseline.get("data", {})
	var data_with: Dictionary = snap_with_ally_spirit.get("data", {})

	if int(data_baseline.get("echoes_survived", -1)) != 2:
		return { "ok": false, "error": "Baseline setup sanity check failed: expected echoes_survived == 2, got %d" % int(data_baseline.get("echoes_survived", -1)) }

	if int(data_with.get("echoes_survived", -1)) != int(data_baseline.get("echoes_survived", -2)):
		return {
			"ok": false,
			"error": "Expected echoes_survived to exclude the living is_ally combatant (BUG 2 regression) — baseline %d, with ally+spirit %d" \
				% [int(data_baseline.get("echoes_survived", -2)), int(data_with.get("echoes_survived", -1))]
		}

	if str(data_with.get("rank", "")) != str(data_baseline.get("rank", "")):
		return {
			"ok": false,
			"error": "Expected rank to be unaffected by the ally/spirit combatants (BUG 2 regression) — baseline '%s', with ally+spirit '%s'" \
				% [str(data_baseline.get("rank", "")), str(data_with.get("rank", ""))]
		}

	if int(data_with.get("ase_awarded", -1)) != int(data_baseline.get("ase_awarded", -2)):
		return {
			"ok": false,
			"error": "Expected ase_awarded to be unaffected by the ally/spirit combatants (BUG 2 regression) — baseline %d, with ally+spirit %d" \
				% [int(data_baseline.get("ase_awarded", -2)), int(data_with.get("ase_awarded", -1))]
		}

	return { "ok": true }


# Shared builder for the BUG 2 regression test — mirrors
# _t_final_snapshot_has_combat_intro_line_and_no_recruit_offer_key's minimal-context
# pattern (bare FlowContext + EncounterContext, real ConfigService for reward config).
static func _final_snapshot_for_actors(actors: Array, encounter_id: String) -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()

	var ctx := FlowContext.new()
	ctx.config_service = cs
	ctx.realm_id = "realm.01"
	ctx.stage_id = "stage.0"
	ctx.save_data = {
		"realms": {
			"realm.01": {
				"stages": [
					{ "index": 0, "explore_map": {} },
				],
			},
		},
	}

	var ectx := EncounterContext.new()
	ectx.encounter_id  = encounter_id
	ectx.placement_seed = 1
	ectx.actors = actors
	ectx.combat_state  = { "combat_over": true, "objective": "defeat_enemies", "round_counter": 2 }
	ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 2 }
	ctx.encounter_ctx = ectx

	return FlowEncounterState.build_final_snapshot(ctx, 1)
