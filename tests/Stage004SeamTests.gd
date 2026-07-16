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
	runner.register_test("realm_ui/modal_clear_then_resize_does_not_represent",
		Callable(Stage004SeamTests, "_t_realm_modal_clear_then_resize_does_not_represent"))
	runner.register_test("realm_ui/modal_dismiss_then_resize_does_not_represent",
		Callable(Stage004SeamTests, "_t_realm_modal_dismiss_then_resize_does_not_represent"))
	runner.register_test("realm_ui/hidden_shell_resize_does_not_refresh_modal",
		Callable(Stage004SeamTests, "_t_hidden_shell_resize_does_not_refresh_modal"))
	runner.register_test("realm_ui/prebattle_modal_route_and_resolve_structure",
		Callable(Stage004SeamTests, "_t_prebattle_modal_route_and_resolve_structure"))
	runner.register_test("realm_ui/contact_and_directive_modal_safe_scroll_structure",
		Callable(Stage004SeamTests, "_t_contact_and_directive_modal_safe_scroll_structure"))
	runner.register_test("realm_ui/contact_modal_responsive_living_tree_states",
		Callable(Stage004SeamTests, "_t_contact_modal_responsive_living_tree_states"))
	runner.register_test("realm_ui/contact_modal_picker_refresh_and_response",
		Callable(Stage004SeamTests, "_t_contact_modal_picker_refresh_and_response"))
	runner.register_test("realm_ui/directive_long_copy_compact_geometry",
		Callable(Stage004SeamTests, "_t_directive_long_copy_compact_geometry"))
	runner.register_test("realm_ui/contact_speak_dismisses_before_action",
		Callable(Stage004SeamTests, "_t_contact_speak_dismisses_before_action"))
	runner.register_test("realm_ui/directive_select_action_before_dismiss",
		Callable(Stage004SeamTests, "_t_directive_select_action_before_dismiss"))
	runner.register_test("realm_ui/directive_same_id_refresh_then_dismiss",
		Callable(Stage004SeamTests, "_t_directive_same_id_refresh_then_dismiss"))
	runner.register_test("realm_ui/stage_map_responsive_columns_and_caps",
		Callable(Stage004SeamTests, "_t_stage_map_responsive_columns_and_caps"))
	runner.register_test("realm_ui/stage_map_in_tree_height_matrix",
		Callable(Stage004SeamTests, "_t_stage_map_in_tree_height_matrix"))
	runner.register_test("realm_ui/stage_explore_in_tree_vertical_regions",
		Callable(Stage004SeamTests, "_t_stage_explore_in_tree_vertical_regions"))
	runner.register_test("realm_ui/stage_preview_banner_safe_and_scrollable",
		Callable(Stage004SeamTests, "_t_stage_preview_banner_safe_and_scrollable"))
	runner.register_test("realm_ui/stage_preview_reuse_resets_fade_input_and_focus",
		Callable(Stage004SeamTests, "_t_stage_preview_reuse_resets_fade_input_and_focus"))
	runner.register_test("realm_ui/target_minima_and_spatial_caps",
		Callable(Stage004SeamTests, "_t_realm_target_minima_and_spatial_caps"))
	runner.register_test("realm_ui/hidden_realm_chrome_does_not_block_sanctum_nav",
		Callable(Stage004SeamTests, "_t_hidden_realm_chrome_does_not_block_sanctum_nav"))
	runner.register_test("realm_ui/ancestor_hide_disables_realm_chrome",
		Callable(Stage004SeamTests, "_t_ancestor_hide_disables_realm_chrome"))
	runner.register_test("realm_ui/echo_bar_safe_geometry_matrix",
		Callable(Stage004SeamTests, "_t_echo_bar_safe_geometry_matrix"))


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


# Realm responsive-modal regression: RealmShell stores the active modal request so
# a live resize can re-emit the same ID/payload to ModalHost.present(...). That
# tracking must be cleared on every later non-resolve snapshot BEFORE the active
# screen processes it. Otherwise dismissing/replacing a modal, then resizing, can
# resurrect stale UI.
static func _t_realm_modal_clear_then_resize_does_not_represent() -> Dictionary:
	var scene := preload("res://ui/shells/RealmShell.tscn")
	var shell := scene.instantiate() as RealmShell
	if shell == null:
		return { "ok": false, "error": "Failed to instantiate RealmShell" }
	shell.set("_echo_bar", shell.get_node("%EchoBar"))

	var emitted: Array = []
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload.duplicate(true) })
	)
	shell.call("on_modal_accepted", &"realm.resolve", { "snapshot": { "type": "flow.resolve" } })
	shell.call("_clear_tracked_modal")
	var after_clear_count := emitted.size()
	shell.set_layout({
		"profile": &"wide",
		"logical_size": Vector2(1600, 900),
		"safe_insets": Vector4(0, 0, 0, 24),
	})
	if emitted.size() != after_clear_count:
		if is_instance_valid(shell):
			shell.queue_free()
		return {
			"ok": false,
			"error": "Resize after non-resolve snapshot re-emitted stale modal request; count before=%d after=%d" % [after_clear_count, emitted.size()]
		}

	if is_instance_valid(shell):
		shell.queue_free()
	return { "ok": true }

static func _t_realm_modal_dismiss_then_resize_does_not_represent() -> Dictionary:
	var scene := preload("res://ui/shells/RealmShell.tscn")
	var shell := scene.instantiate() as RealmShell
	if shell == null:
		return { "ok": false, "error": "Failed to instantiate RealmShell" }
	shell.set("_echo_bar", shell.get_node("%EchoBar"))
	var emitted: Array = []
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload.duplicate(true) })
	)
	shell.call("on_modal_accepted", &"realm.resolve", { "snapshot": { "type": "flow.resolve" } })
	shell.on_modal_dismissed(&"realm.resolve")
	shell.set_layout({ "profile": &"wide", "logical_size": Vector2(1600, 900), "safe_insets": Vector4.ZERO })
	if emitted.size() != 0:
		if is_instance_valid(shell):
			shell.queue_free()
		return { "ok": false, "error": "Resize after matching modal dismissal re-emitted stale modal request" }
	if is_instance_valid(shell):
		shell.queue_free()
	return { "ok": true }

static func _t_hidden_shell_resize_does_not_refresh_modal() -> Dictionary:
	var scene := preload("res://ui/shells/RealmShell.tscn")
	var shell := scene.instantiate() as RealmShell
	if shell == null:
		return { "ok": false, "error": "Failed to instantiate RealmShell" }
	shell.set("_echo_bar", shell.get_node("%EchoBar"))
	var emitted: Array = []
	shell.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload.duplicate(true) })
	)
	shell.call("on_modal_accepted", &"realm.resolve", { "snapshot": { "type": "flow.resolve" } })
	shell.visible = false
	shell.set_layout({ "profile": &"wide", "logical_size": Vector2(1600, 900), "safe_insets": Vector4.ZERO })
	if emitted.size() != 0:
		shell.queue_free()
		return { "ok": false, "error": "Hidden RealmShell resize emitted stale modal refresh" }
	shell.visible = true
	shell.set_layout({ "profile": &"wide", "logical_size": Vector2(1700, 900), "safe_insets": Vector4(0, 0, 0, 12) })
	if emitted.size() != 1 or emitted[0].get("id", &"") != &"realm.resolve":
		shell.queue_free()
		return { "ok": false, "error": "Visible RealmShell resize did not refresh active modal request" }
	var payload: Dictionary = emitted[0].get("payload", {})
	var layout: Dictionary = payload.get("layout", {})
	if layout.get("logical_size", Vector2.ZERO) != Vector2(1700, 900):
		shell.queue_free()
		return { "ok": false, "error": "Visible RealmShell modal refresh did not carry updated layout" }
	shell.queue_free()
	return { "ok": true }

static func _t_prebattle_modal_route_and_resolve_structure() -> Dictionary:
	var shell_scene := preload("res://ui/shells/RealmShell.tscn")
	var shell := shell_scene.instantiate() as RealmShell
	if shell == null:
		return { "ok": false, "error": "Failed to instantiate RealmShell" }
	if shell.modal_scene_for(&"realm.prebattle") == null:
		shell.free()
		return { "ok": false, "error": "RealmShell did not map realm.prebattle to a modal scene" }

	var combat_scene := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
	var combat := combat_scene.instantiate() as CombatBoardScreen
	if combat == null:
		shell.free()
		return { "ok": false, "error": "Failed to instantiate CombatBoardScreen" }
	var emitted: Array = []
	combat.modal_requested.connect(func(modal_id: StringName, payload: Dictionary) -> void:
		emitted.append({ "id": modal_id, "payload": payload.duplicate(true) })
	)
	combat.set("_round_label", combat.get_node("RoundLabel"))
	combat.set("_objective_label", combat.get_node("ObjectiveLabel"))
	combat.set("_prebattle_panel", combat.get_node("PrebattlePanel"))
	combat.set("_prebattle_objective", combat.get_node("PrebattlePanel/PrebattleContent/ObjectivePanelLabel"))
	combat.set("_prebattle_intro_line", combat.get_node("%IntroLineLabel"))
	combat.set("_retreat_button", combat.get_node("PrebattlePanel/PrebattleContent/ButtonRow/RetreatButton"))
	combat.set("_enter_combat_button", combat.get_node("PrebattlePanel/PrebattleContent/ButtonRow/EnterCombatButton"))
	combat.call("_show_prebattle_panel",
		{
			"round_phase": "pre_combat",
			"board_cols": 2,
			"board_rows": 2,
			"actors": [],
			"objective_state": { "type": "defeat_enemies" },
			"combat_intro_line": "Claimant test line",
			"retreat_eligible": true,
			"retreat_tier_label": "Risky",
			"retreat_ase_cost": 7,
		},
		{
			"cta.combat_init": { "type": "combat.init", "slot": "cta.combat_init" },
			"cta.retreat": { "type": "encounter.retreat", "slot": "cta.retreat" },
		}
	)
	if emitted.size() != 1 or emitted[0].get("id", &"") != &"realm.prebattle":
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "Expected pre_combat snapshot to emit one realm.prebattle modal request" }
	var payload: Dictionary = emitted[0].get("payload", {})
	if str(payload.get("objective_label", "")) != "Defeat all enemies" or str(payload.get("intro_line", "")) != "Claimant test line":
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "Prebattle modal payload did not preserve objective/intro presentation fields" }

	var resolve_scene := preload("res://ui/screens/venture/ResolveScreen.tscn")
	var resolve := resolve_scene.instantiate() as ResolveScreen
	if resolve == null:
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "Failed to instantiate ResolveScreen" }
	if resolve.get_node_or_null("%SafeFrame") == null:
		resolve.free()
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "ResolveScreen missing authored SafeFrame" }
	if resolve.get_node_or_null(
		"SafeFrame/CenterContainer/ResultCard/CardMargin/CardLayout/BodyViewport/ScrollContainer"
	) == null:
		resolve.free()
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "ResolveScreen missing authored scroll body inside ResultCard" }
	if resolve.get_node_or_null(
		"SafeFrame/CenterContainer/ResultCard/CardMargin/CardLayout/FooterSurface/FooterMargin/ButtonRow"
	) == null:
		resolve.free()
		combat.queue_free()
		shell.free()
		return { "ok": false, "error": "ResolveScreen missing fixed footer ButtonRow outside scroll body" }
	resolve.free()
	combat.queue_free()
	shell.free()
	return { "ok": true }

static func _t_contact_and_directive_modal_safe_scroll_structure() -> Dictionary:
	var safe_failure := _assert_realm_modal_safe_frames_apply_layout()
	if not safe_failure.is_empty():
		return { "ok": false, "error": safe_failure }

	var contact_scene := preload("res://ui/overlays/realm/ContactModal.tscn")
	var contact := contact_scene.instantiate()
	if contact == null:
		return { "ok": false, "error": "Failed to instantiate ContactModal" }
	if contact.get_node_or_null("%SafeFrame") == null:
		contact.free()
		return { "ok": false, "error": "ContactModal missing SafeFrame" }
	var contact_scroll := contact.get_node_or_null("%BodyScroll") as ScrollContainer
	if contact_scroll == null:
		contact.free()
		return { "ok": false, "error": "ContactModal missing bounded BodyScroll" }
	if contact.get_node_or_null("SafeFrame/Center/Card/Content/ButtonRow") == null:
		contact.free()
		return { "ok": false, "error": "ContactModal missing fixed footer ButtonRow outside BodyScroll" }
	if contact.get_node_or_null("SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard4/CardButton") == null:
		contact.free()
		return { "ok": false, "error": "ContactModal missing fifth authored option-card target" }
	if (contact.get_node("SafeFrame/Center/Card/Content/ButtonRow") as Node).get_parent() == contact_scroll:
		contact.free()
		return { "ok": false, "error": "ContactModal footer is inside the scroll body" }
	contact.free()

	var directive_scene := preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn")
	var directive := directive_scene.instantiate()
	if directive == null:
		return { "ok": false, "error": "Failed to instantiate DirectiveSelectOverlay" }
	if not directive.visible:
		directive.free()
		return { "ok": false, "error": "DirectiveSelectOverlay is authored hidden inside the blocking ModalHost" }
	if directive.get_node_or_null("%SafeFrame") == null:
		directive.free()
		return { "ok": false, "error": "DirectiveSelectOverlay missing SafeFrame" }
	var directive_scroll := directive.get_node_or_null("%BodyScroll") as ScrollContainer
	if directive_scroll == null:
		directive.free()
		return { "ok": false, "error": "DirectiveSelectOverlay missing bounded BodyScroll" }
	var select_button := directive.get_node_or_null("%SelectButton") as Button
	if select_button == null or select_button.get_parent() == directive_scroll:
		directive.free()
		return { "ok": false, "error": "Directive primary Select footer is not fixed outside BodyScroll" }
	if select_button.custom_minimum_size.y < 56.0:
		directive.free()
		return { "ok": false, "error": "Directive primary Select footer is below 56px high" }
	var directive_panel := directive.get_node_or_null("%Panel") as PanelContainer
	if directive_panel == null or directive_panel.theme_type_variation != &"SanctumCard":
		directive.free()
		return { "ok": false, "error": "Directive modal is not using the authored Living Tree card treatment" }
	directive.free()
	return { "ok": true }

static func _assert_realm_modal_safe_frames_apply_layout() -> String:
	var layout := {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4(5, 20, 24, 13),
	}
	var cases := [
		{
			"name": "ContactModal",
			"scene": preload("res://ui/overlays/realm/ContactModal.tscn"),
			"payload": {
				"layout": layout,
				"contact": {},
				"data": {},
				"actions": {},
			},
			"method": "present",
		},
		{
			"name": "EngagementModal",
			"scene": preload("res://ui/overlays/realm/EngagementModal.tscn"),
			"payload": {
				"layout": layout,
				"pending": {},
				"engage_action": {},
				"ignore_action": {},
			},
			"method": "present",
		},
		{
			"name": "PrebattleModal",
			"scene": preload("res://ui/overlays/realm/PrebattleModal.tscn"),
			"payload": {
				"layout": layout,
				"objective_label": "",
				"enter_action": {},
				"retreat_action": {},
			},
			"method": "present",
		},
		{
			"name": "ReturnHomeModal",
			"scene": preload("res://ui/overlays/realm/ReturnHomeModal.tscn"),
			"payload": {
				"layout": layout,
				"result": {},
			},
			"method": "present",
		},
		{
			"name": "SituationModal",
			"scene": preload("res://ui/overlays/realm/SituationModal.tscn"),
			"payload": {
				"layout": layout,
				"result": {},
			},
			"method": "present",
		},
		{
			"name": "DirectiveSelectOverlay",
			"scene": preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn"),
			"payload": {
				"layout": layout,
				"directive": {},
			},
			"method": "present",
		},
		{
			"name": "ResolveScreen",
			"scene": preload("res://ui/screens/venture/ResolveScreen.tscn"),
			"payload": layout,
			"method": "set_layout",
		},
	]
	for case_v in cases:
		var case: Dictionary = case_v
		var root: Node = (case["scene"] as PackedScene).instantiate()
		if root == null:
			return "Failed to instantiate %s" % str(case.get("name", "modal"))
		var safe_frame := root.get_node_or_null("%SafeFrame") as MarginContainer
		if safe_frame == null:
			root.queue_free()
			return "%s missing SafeFrame" % str(case["name"])
		if not safe_frame.has_method("set_layout"):
			root.queue_free()
			return "%s SafeFrame is not the shared SafeAreaContainer" % str(case["name"])
		safe_frame.call("set_layout", layout)
		var margins := Vector4(
			safe_frame.get_theme_constant("margin_left"),
			safe_frame.get_theme_constant("margin_top"),
			safe_frame.get_theme_constant("margin_right"),
			safe_frame.get_theme_constant("margin_bottom")
		)
		var expected := Vector4(16, 20, 24, 16)
		if margins != expected:
			root.queue_free()
			return "%s SafeFrame margins did not apply OS insets without chrome reservation; got=%s expected=%s" % [
				str(case["name"]),
				str(margins),
				str(expected),
			]
		root.queue_free()
	return ""

static func _t_contact_modal_responsive_living_tree_states() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for ContactModal geometry test" }
	var cases := [
		{
			"name": "compact",
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4.ZERO,
			"card_width": 880.0,
			"option_width": 248.0,
		},
		{
			"name": "wide",
			"size": Vector2i(1600, 900),
			"profile": &"wide",
			"insets": Vector4(24, 20, 36, 16),
			"card_width": 960.0,
			"option_width": 260.0,
		},
	]
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport := SubViewport.new()
		var viewport_size: Vector2i = case["size"]
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		fixture_host.add_child(viewport)
		var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
		viewport.add_child(host)
		var insets: Vector4 = case["insets"]
		var payload := _contact_picker_payload(
			{
				"profile": case["profile"],
				"logical_size": Vector2(viewport_size),
				"safe_insets": insets,
			},
			1,
			["echo.1", "echo.2", "echo.3", "echo.4", "echo.5"]
		)
		if not host.present_modal_for_id(
			&"realm.contact",
			preload("res://ui/overlays/realm/ContactModal.tscn"),
			payload
		):
			viewport.free()
			return { "ok": false, "error": "ModalHost failed to present ContactModal at %s" % str(case["name"]) }
		_force_realm_control_layout(host)
		var contact := host.get_node_or_null("%ModalSlot/ContactModal") as ContactModal
		if contact == null:
			viewport.free()
			return { "ok": false, "error": "ContactModal instance missing from ModalHost" }
		var card := contact.get_node_or_null("SafeFrame/Center/Card") as PanelContainer
		var body_scroll := contact.get_node_or_null("%BodyScroll") as ScrollContainer
		var footer := contact.get_node_or_null("SafeFrame/Center/Card/Content/ButtonRow") as HBoxContainer
		var npc_zone := contact.get_node_or_null("%NPCZone") as PanelContainer
		var line := contact.get_node_or_null("%LineLabel") as Label
		var meta := contact.get_node_or_null("%MetaLabel") as Label
		var reaction := contact.get_node_or_null("%ReactionLabel") as Label
		var option := contact.get_node_or_null("%OptionCard0") as PanelContainer
		var button := option.get_node_or_null("CardButton") as Button if option != null else null
		var name_label := option.get_node_or_null("CardContent/EchoNameLabel") as Label if option != null else null
		var calling_label := option.get_node_or_null("CardContent/CallingLabel") as Label if option != null else null
		var emotion_label := option.get_node_or_null("CardContent/EmotionRow/EmotionLabel") as Label if option != null else null
		var response_label := option.get_node_or_null("CardContent/ResponseLabel") as Label if option != null else null
		var stat_label := option.get_node_or_null("CardContent/StatTextureLabel") as Label if option != null else null
		var bid_label := option.get_node_or_null("CardContent/BidBadgeLabel") as Label if option != null else null
		var state_label := option.get_node_or_null("CardContent/StateLabel") as Label if option != null else null
		if card == null or body_scroll == null or footer == null or npc_zone == null \
				or line == null or meta == null or reaction == null or option == null \
				or button == null or name_label == null or calling_label == null \
				or emotion_label == null or response_label == null or stat_label == null \
				or bid_label == null or state_label == null:
			viewport.free()
			return { "ok": false, "error": "ContactModal authored responsive/state structure is incomplete" }
		var safe_left := maxf(16.0, ceilf(insets.x))
		var safe_top := maxf(16.0, ceilf(insets.y))
		var safe_right := maxf(16.0, ceilf(insets.z))
		var safe_bottom := maxf(16.0, ceilf(insets.w))
		var card_rect := card.get_global_rect()
		if card_rect.position.x < safe_left - 0.5 \
				or card_rect.end.x > float(viewport_size.x) - safe_right + 0.5 \
				or card_rect.position.y < safe_top - 0.5 \
				or card_rect.end.y > float(viewport_size.y) - safe_bottom + 0.5:
			viewport.free()
			return { "ok": false, "error": "ContactModal escaped safe bounds at %s: %s" % [str(case["name"]), str(card_rect)] }
		if not is_equal_approx(card_rect.size.x, float(case["card_width"])):
			viewport.free()
			return { "ok": false, "error": "ContactModal did not use the capped %s width; got %.1f" % [str(case["name"]), card_rect.size.x] }
		if option.size.x < 239.5 or option.size.x > 260.5 \
				or not is_equal_approx(option.custom_minimum_size.x, float(case["option_width"])):
			viewport.free()
			return { "ok": false, "error": "Contact option card is outside the 240–260 responsive width target at %s" % str(case["name"]) }
		if footer.get_parent() == body_scroll or footer.get_global_rect().end.y > card_rect.end.y + 0.5:
			viewport.free()
			return { "ok": false, "error": "Contact fixed footer is not reachable within the safe card" }
		if option.theme_type_variation != &"RealmContactOptionCard" \
				or button.theme_type_variation != &"RealmContactOptionButton" \
				or button.button_pressed or button.toggle_mode \
				or state_label.modulate.a > 0.01:
			viewport.free()
			return { "ok": false, "error": "Initial Contact option reads as selected instead of focused/default" }
		if viewport.gui_get_focus_owner() != button:
			viewport.free()
			return { "ok": false, "error": "ModalHost did not place initial focus on the first Contact option" }
		var option_style := option.get_theme_stylebox("panel") as StyleBoxFlat
		var focus_style := button.get_theme_stylebox("focus") as StyleBoxFlat
		if option_style == null or focus_style == null \
				or option_style.bg_color.r > 0.25 \
				or option_style.bg_color.g > 0.25 \
				or focus_style.bg_color.a > 0.12 \
				or not focus_style.border_color.is_equal_approx(Color(0.83137256, 0.6862745, 0.21568628, 0.95)) \
				or focus_style.border_color.is_equal_approx(Color(0.29803923, 0.6862745, 0.44705883, 1)):
			viewport.free()
			return { "ok": false, "error": "Contact first focus is not the subtle Living Grove gold outline distinct from green selection" }
		if line.get_theme_font_size("font_size") < 16 \
				or name_label.get_theme_font_size("font_size") < 16 \
				or calling_label.get_theme_font_size("font_size") < 14 \
				or emotion_label.get_theme_font_size("font_size") < 14 \
				or response_label.get_theme_font_size("font_size") < 16 \
				or stat_label.get_theme_font_size("font_size") < 13 \
				or bid_label.get_theme_font_size("font_size") < 13:
			viewport.free()
			return { "ok": false, "error": "ContactModal typography remains below the authored readability floor" }
		for text_label in [name_label, calling_label, emotion_label, response_label, stat_label]:
			var contrast := _realm_contrast_ratio(text_label.get_theme_color("font_color"), option_style.bg_color)
			if contrast < 4.5:
				viewport.free()
				return {
					"ok": false,
					"error": "Contact option label %s contrast %.2f is below 4.5:1" % [text_label.name, contrast],
				}
		var npc_style := npc_zone.get_theme_stylebox("panel") as StyleBoxFlat
		var npc_tint := npc_zone.self_modulate
		var npc_bg := Color(
			npc_style.bg_color.r * npc_tint.r,
			npc_style.bg_color.g * npc_tint.g,
			npc_style.bg_color.b * npc_tint.b,
			1
		) if npc_style != null else Color.BLACK
		if _realm_contrast_ratio(line.get_theme_color("font_color"), npc_bg) < 4.5:
			viewport.free()
			return { "ok": false, "error": "Contact NPC line contrast is below 4.5:1" }
		if meta.text != "speaks directly" or reaction.text != "Listens" \
				or meta.text.contains(reaction.text) or bid_label.text != "⬥":
			viewport.free()
			return { "ok": false, "error": "ContactModal drifted from the pre-migration disposition/reaction/badge copy" }
		viewport.free()
	return { "ok": true }

static func _t_contact_modal_picker_refresh_and_response() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for ContactModal interaction test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var host := preload("res://ui/components/ModalHost.tscn").instantiate() as ModalHost
	viewport.add_child(host)
	var compact_layout := {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4.ZERO,
	}
	var ids := ["echo.1", "echo.2", "echo.3", "echo.4", "echo.5"]
	var picker_payload := _contact_picker_payload(compact_layout, 1, ids)
	if not host.present_modal_for_id(
		&"realm.contact",
		preload("res://ui/overlays/realm/ContactModal.tscn"),
		picker_payload
	):
		viewport.free()
		return { "ok": false, "error": "ModalHost failed to present Contact picker" }
	_force_realm_control_layout(host)
	var contact := host.get_node_or_null("%ModalSlot/ContactModal") as ContactModal
	if contact == null:
		viewport.free()
		return { "ok": false, "error": "Contact picker instance missing" }
	var roots: Array[PanelContainer] = []
	var buttons: Array[Button] = []
	var states: Array[Label] = []
	for index in range(5):
		var root := contact.get_node_or_null(
			"SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard%d" % index
		) as PanelContainer
		var button := root.get_node_or_null("CardButton") as Button if root != null else null
		var state := root.get_node_or_null("CardContent/StateLabel") as Label if root != null else null
		if root == null or button == null or state == null:
			viewport.free()
			return { "ok": false, "error": "Contact picker option %d is incomplete" % index }
		roots.append(root)
		buttons.append(button)
		states.append(state)
	var initial_rects: Array[Rect2] = []
	for root in roots:
		initial_rects.append(root.get_global_rect())
	for index in range(3):
		buttons[index].grab_focus()
		_push_realm_accept(viewport)
		_force_realm_control_layout(host)
		if roots[index].theme_type_variation != &"RealmContactOptionSelected" \
				or states[index].text != "✓" or states[index].modulate.a < 0.99 \
				or buttons[index].button_pressed or buttons[index].disabled:
			viewport.free()
			return { "ok": false, "error": "Contact picker did not author a clear selected state for option %d" % index }
	for index in range(roots.size()):
		var current_rect := roots[index].get_global_rect()
		if not current_rect.position.is_equal_approx(initial_rects[index].position) \
				or not current_rect.size.is_equal_approx(initial_rects[index].size):
			viewport.free()
			return { "ok": false, "error": "Contact option geometry shifted when selection state label appeared" }
	var confirm := contact.get_node_or_null("%ConfirmButton") as Button
	if confirm == null or confirm.disabled:
		viewport.free()
		return { "ok": false, "error": "Contact picker Confirm did not enable after selection" }
	if roots[3].theme_type_variation != &"RealmContactOptionUnavailable" \
			or not states[3].text.strip_edges().is_empty() \
			or states[3].modulate.a > 0.01 or roots[3].modulate.a > 0.55 \
			or not buttons[3].disabled:
		viewport.free()
		return { "ok": false, "error": "Contact picker max-3 state does not make remaining cards clearly unavailable" }
	buttons[0].grab_focus()
	_push_realm_accept(viewport)
	_force_realm_control_layout(host)
	if roots[0].theme_type_variation != &"RealmContactOptionCard" \
			or states[0].modulate.a > 0.01 or buttons[3].disabled \
			or roots[3].theme_type_variation != &"RealmContactOptionCard":
		viewport.free()
		return { "ok": false, "error": "Contact picker deselection did not reopen unavailable cards" }
	buttons[0].grab_focus()
	_push_realm_accept(viewport)
	_force_realm_control_layout(host)
	buttons[1].grab_focus()
	var focus_style := buttons[1].get_theme_stylebox("focus") as StyleBoxFlat
	var selected_style := roots[0].get_theme_stylebox("panel") as StyleBoxFlat
	if viewport.gui_get_focus_owner() != buttons[1] \
			or roots[1].theme_type_variation != &"RealmContactOptionSelected" \
			or focus_style == null or selected_style == null \
			or focus_style.border_color.is_equal_approx(selected_style.border_color):
		viewport.free()
		return { "ok": false, "error": "Contact picker focus is not visually distinct from committed selection" }
	var wide_payload := picker_payload.duplicate(true)
	wide_payload["layout"] = {
		"profile": &"wide",
		"logical_size": Vector2(1600, 900),
		"safe_insets": Vector4(24, 20, 36, 16),
	}
	viewport.size = Vector2i(1600, 900)
	host.present_modal_for_id(&"realm.contact", preload("res://ui/overlays/realm/ContactModal.tscn"), wide_payload)
	_force_realm_control_layout(host)
	if roots[0].theme_type_variation != &"RealmContactOptionSelected" \
			or roots[1].theme_type_variation != &"RealmContactOptionSelected" \
			or roots[2].theme_type_variation != &"RealmContactOptionSelected" \
			or confirm.disabled or viewport.gui_get_focus_owner() != buttons[1]:
		viewport.free()
		return { "ok": false, "error": "Same-contact layout refresh lost picker selection, Confirm state, or valid focus" }
	confirm.grab_focus()
	var new_payload := _contact_picker_payload(wide_payload["layout"], 2, ["echo.1", "echo.2", "echo.3", "echo.4"])
	host.present_modal_for_id(&"realm.contact", preload("res://ui/overlays/realm/ContactModal.tscn"), new_payload)
	_force_realm_control_layout(host)
	for index in range(4):
		if roots[index].theme_type_variation != &"RealmContactOptionCard" \
				or states[index].modulate.a > 0.01 or buttons[index].disabled \
				or buttons[index].button_pressed or roots[index].modulate != Color.WHITE:
			viewport.free()
			return { "ok": false, "error": "New Contact payload retained stale state on option %d" % index }
	if not confirm.disabled or viewport.gui_get_focus_owner() != buttons[0]:
		viewport.free()
		return { "ok": false, "error": "New Contact payload did not reset selection and safe initial focus" }
	var events: Array[String] = []
	var emitted_actions: Array[Dictionary] = []
	contact.dismiss_requested.connect(func() -> void:
		events.append("dismiss")
	)
	contact.action_requested.connect(func(action: Dictionary) -> void:
		events.append("action")
		emitted_actions.append(action.duplicate(true))
	)
	var response_payload := _contact_response_payload(wide_payload["layout"], 2)
	host.present_modal_for_id(&"realm.contact", preload("res://ui/overlays/realm/ContactModal.tscn"), response_payload)
	_force_realm_control_layout(host)
	if buttons[0].toggle_mode or buttons[0].button_pressed \
			or roots[0].theme_type_variation != &"RealmContactOptionCard" \
			or states[0].modulate.a > 0.01:
		viewport.free()
		return { "ok": false, "error": "Contact response card became a picker toggle" }
	buttons[0].grab_focus()
	_push_realm_accept(viewport)
	var expected_action: Dictionary = response_payload["actions"]["cta.speak_response.echo.1"]
	if events != ["dismiss", "action"] \
			or emitted_actions.size() != 1 or emitted_actions[0] != expected_action:
		viewport.free()
		return { "ok": false, "error": "Contact response did not dispatch immediately after dismiss with the exact action" }
	viewport.free()
	return { "ok": true }

static func _t_contact_speak_dismisses_before_action() -> Dictionary:
	var contact_scene := preload("res://ui/overlays/realm/ContactModal.tscn")
	var contact := contact_scene.instantiate()
	if contact == null:
		return { "ok": false, "error": "Failed to instantiate ContactModal" }
	var events: Array[String] = []
	contact.dismiss_requested.connect(func() -> void:
		events.append("dismiss")
	)
	contact.action_requested.connect(func(action: Dictionary) -> void:
		events.append("action:%s" % str(action.get("type", "")))
	)
	contact.call("present", {
		"layout": {
			"profile": &"compact",
			"logical_size": Vector2(960, 540),
			"safe_insets": Vector4.ZERO,
		},
		"contact": {
			"name": "Witness",
			"role_label": "A Witness",
			"npc_line": "Choose who speaks.",
		},
		"data": {
			"contact_responses": [
				{
					"echo_id": "echo.1",
					"echo_name": "Ama",
					"calling": "Keeper",
					"emotional_status": "steady",
					"response_text": "I will answer.",
				},
			],
		},
		"actions": {
			"cta.speak_response.echo.1": {
				"type": "stage.speak_response",
				"slot": "cta.speak_response.echo.1",
				"payload": { "echo_id": "echo.1" },
			},
		},
	})
	var card_button := contact.get_node_or_null("SafeFrame/Center/Card/Content/BodyScroll/Body/Options/OptionCard0/CardButton") as Button
	if card_button == null:
		contact.queue_free()
		return { "ok": false, "error": "ContactModal response card button missing" }
	contact.call("_on_option_pressed", 0)
	if events.size() != 2 or events[0] != "dismiss" or events[1] != "action:stage.speak_response":
		contact.queue_free()
		return { "ok": false, "error": "Contact speak response did not dismiss before action; events=%s" % str(events) }
	contact.queue_free()
	return { "ok": true }

static func _t_directive_select_action_before_dismiss() -> Dictionary:
	var directive_scene := preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn")
	var directive := directive_scene.instantiate()
	if directive == null:
		return { "ok": false, "error": "Failed to instantiate DirectiveSelectOverlay" }
	directive.set("_tag_0", directive.get_node("%Tag0"))
	directive.set("_tag_1", directive.get_node("%Tag1"))
	directive.set("_arrow_left", directive.get_node("%ArrowLeft"))
	directive.set("_arrow_right", directive.get_node("%ArrowRight"))
	directive.set("_title", directive.get_node("%DirectiveTitle"))
	directive.set("_description", directive.get_node("%DirectiveDescription"))
	directive.set("_pro_0", directive.get_node("%Pro0"))
	directive.set("_pro_1", directive.get_node("%Pro1"))
	directive.set("_con_0", directive.get_node("%Con0"))
	directive.set("_con_1", directive.get_node("%Con1"))
	directive.set("_select_btn", directive.get_node("%SelectButton"))
	directive.set("_safe_frame", directive.get_node("%SafeFrame"))
	directive.set("_panel", directive.get_node("%Panel"))
	directive.set("_body_scroll", directive.get_node("%BodyScroll"))
	var events: Array[String] = []
	var emitted_actions: Array = []
	directive.action_requested.connect(func(action: Dictionary) -> void:
		events.append("action")
		emitted_actions.append(action.duplicate(true))
	)
	directive.dismiss_requested.connect(func() -> void:
		events.append("dismiss")
	)
	directive.call("present", {
		"layout": {
			"profile": &"compact",
			"logical_size": Vector2(960, 540),
			"safe_insets": Vector4.ZERO,
		},
		"directive": {
			"active_id": "directive.scout",
			"directives": [
				{
					"id": "directive.scout",
					"label": "Scout Carefully",
					"description": "The land will speak if you give it time.",
					"pros": [],
					"cons": [],
				},
				{
					"id": "directive.none",
					"label": "Seek Signs",
					"description": "Move with the road.",
					"pros": [],
					"cons": [],
				},
			],
		},
	})
	directive.call("_on_select_pressed")
	if events.size() != 2 or events[0] != "action" or events[1] != "dismiss":
		directive.queue_free()
		return { "ok": false, "error": "Directive select did not emit action before dismiss; events=%s" % str(events) }
	if emitted_actions.size() != 1 or emitted_actions[0] != {
		"type": "directive.select",
		"directive_id": "directive.scout",
		"slot": "directive.confirm",
	}:
		directive.queue_free()
		return { "ok": false, "error": "Directive select action shape changed; actions=%s" % str(emitted_actions) }
	directive.queue_free()
	return { "ok": true }

static func _t_directive_long_copy_compact_geometry() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for directive geometry test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var directive := preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn").instantiate() as Control
	viewport.add_child(directive)
	var long_copy := (
		"The roots remember every careful footfall, every promise made beneath the leaves, "
		+ "and every danger hidden beyond the next bend. "
		+ "Listen for the story beneath the obvious path before committing the party. "
	)
	directive.call("present", {
		"layout": {
			"profile": &"compact",
			"logical_size": Vector2(960, 540),
			"safe_insets": Vector4.ZERO,
		},
		"directive": {
			"active_id": "directive.scout",
			"directives": [
				{
					"id": "directive.scout",
					"label": "Scout Carefully",
					"description": long_copy + long_copy,
					"pros": [long_copy, long_copy],
					"cons": [long_copy, long_copy],
				},
				{
					"id": "directive.none",
					"label": "Seek Signs",
					"description": long_copy,
					"pros": [long_copy, long_copy],
					"cons": [long_copy, long_copy],
				},
			],
		},
	})
	_force_realm_control_layout(directive)
	var panel := directive.get_node_or_null("%Panel") as Control
	var body_scroll := directive.get_node_or_null("%BodyScroll") as ScrollContainer
	var select_button := directive.get_node_or_null("%SelectButton") as Button
	var tag_0 := directive.get_node_or_null("%Tag0") as Button
	var tag_1 := directive.get_node_or_null("%Tag1") as Button
	var arrow_left := directive.get_node_or_null("%ArrowLeft") as Button
	var con_1 := directive.get_node_or_null("%Con1") as Control
	if panel == null or body_scroll == null or select_button == null or tag_0 == null \
			or tag_1 == null or arrow_left == null or con_1 == null:
		viewport.free()
		return { "ok": false, "error": "Directive compact fixture lacks authored card/body/footer controls" }
	var safe_rect := Rect2(Vector2(16, 16), Vector2(928, 508))
	var panel_rect := panel.get_global_rect()
	if not safe_rect.encloses(panel_rect):
		viewport.free()
		return { "ok": false, "error": "Directive long-copy card escaped compact safe frame: %s" % str(panel_rect) }
	var vbar := body_scroll.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= vbar.page:
		viewport.free()
		return { "ok": false, "error": "Directive long-copy body does not overflow through its authored scroller" }
	if _is_descendant_of_realm(select_button, body_scroll):
		viewport.free()
		return { "ok": false, "error": "Directive Select CTA moved inside the scrolling body" }
	if select_button.get_global_rect().end.y > safe_rect.end.y + 0.5:
		viewport.free()
		return { "ok": false, "error": "Directive Select CTA is not reachable inside compact safe bounds" }
	body_scroll.ensure_control_visible(con_1)
	_force_realm_control_layout(directive)
	if body_scroll.scroll_vertical <= 0 \
			or not body_scroll.get_global_rect().intersects(con_1.get_global_rect()):
		viewport.free()
		return { "ok": false, "error": "Directive long-copy final content cannot be reached through BodyScroll" }
	if tag_0.theme_type_variation != &"SanctumTabButtonActive" \
			or tag_1.theme_type_variation != &"SanctumTabButton" \
			or arrow_left.theme_type_variation != &"SanctumTabButton" \
			or select_button.theme_type_variation != &"RealmModalPrimaryButton":
		viewport.free()
		return { "ok": false, "error": "Directive controls do not use scoped Living Tree theme roles" }
	for state in ["normal", "focus"]:
		var style := arrow_left.get_theme_stylebox(state) as StyleBoxFlat
		var font_key := "font_focus_color" if state == "focus" else "font_color"
		if style == null:
			viewport.free()
			return { "ok": false, "error": "Directive arrow lacks resolved %s Living Tree style" % state }
		var ratio := _realm_contrast_ratio(arrow_left.get_theme_color(font_key), style.bg_color)
		if ratio < 4.5:
			viewport.free()
			return { "ok": false, "error": "Directive arrow %s contrast %.2f is below 4.5:1" % [state, ratio] }
	viewport.free()
	return { "ok": true }

static func _t_directive_same_id_refresh_then_dismiss() -> Dictionary:
	var host_scene := preload("res://ui/components/ModalHost.tscn")
	var fixture_scene := preload("res://tests/ui_responsive/TestModalFixture.tscn")
	var host := host_scene.instantiate() as Control
	if host == null:
		return { "ok": false, "error": "Failed to instantiate ModalHost" }
	if not bool(host.call("present_modal_for_id", &"realm.directive", fixture_scene, { "value": 1 })):
		host.free()
		return { "ok": false, "error": "Failed to present initial directive fixture" }
	var active := host.get("_active_modal") as Control
	if active == null:
		host.free()
		return { "ok": false, "error": "Directive fixture did not become active" }
	var events: Array[String] = []
	host.connect("action_requested", func(_action: Dictionary) -> void:
		events.append("action")
		var refreshed: bool = bool(host.call(
			"present_modal_for_id",
			&"realm.directive",
			fixture_scene,
			{ "value": 2 }
		))
		events.append("refresh" if refreshed else "refresh_rejected")
	)
	host.connect("modal_dismissed", func(_modal_id: StringName) -> void:
		events.append("dismiss")
	)
	active.emit_signal("action_requested", { "type": "directive.select" })
	active.emit_signal("dismiss_requested")
	if events != ["action", "refresh", "dismiss"]:
		host.free()
		return {
			"ok": false,
			"error": "Synchronous same-ID directive refresh/dismiss order changed; events=%s" % str(events),
		}
	if bool(host.call("has_active_modal")) or host.visible:
		host.free()
		return { "ok": false, "error": "Directive modal remained blocking after synchronous refresh then dismiss" }
	host.free()
	return { "ok": true }

static func _t_stage_map_responsive_columns_and_caps() -> Dictionary:
	var stage_map_scene := preload("res://ui/screens/venture/StageMapScreen.tscn")
	var stage_map := stage_map_scene.instantiate()
	if stage_map == null:
		return { "ok": false, "error": "Failed to instantiate StageMapScreen" }
	stage_map.set("_safe_frame", stage_map.get_node("%SafeFrame"))
	stage_map.set("_content_scroll", stage_map.get_node("%ContentScroll"))
	stage_map.set("_content_row", stage_map.get_node("%ContentRow"))
	stage_map.set("_left_panel", stage_map.get_node("%LeftPanel"))
	stage_map.set("_right_panel", stage_map.get_node("%RightPanel"))
	stage_map.set("_stage_scroll", stage_map.get_node("%StageScroll"))
	stage_map.set("_back_button", stage_map.get_node("%BackButton"))
	stage_map.call("set_layout", {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4(0, 24, 0, 24),
	})
	var content_row := stage_map.get_node_or_null("%ContentRow") as GridContainer
	if content_row == null:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap ContentRow is not an authored GridContainer" }
	if content_row.columns != 1:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap compact profile did not switch to one primary column" }
	stage_map.call("set_layout", {
		"profile": &"wide",
		"logical_size": Vector2(1800, 900),
		"safe_insets": Vector4.ZERO,
	})
	var right_panel := stage_map.get_node_or_null("%RightPanel") as PanelContainer
	if content_row.columns != 2:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap wide profile did not restore two columns" }
	if right_panel == null or right_panel.custom_minimum_size.x > 960.0:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap wide detail panel is not capped at readable width" }
	if content_row.size_flags_horizontal != Control.SIZE_SHRINK_CENTER:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap wide content row is not shrink-centered to leave surplus space" }
	if content_row.custom_minimum_size.x < 1399.0:
		stage_map.queue_free()
		return { "ok": false, "error": "StageMap wide content remains compact instead of using its approved desktop width" }
	stage_map.queue_free()
	return { "ok": true }

static func _t_stage_map_in_tree_height_matrix() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for StageMap geometry test" }
	var cases := [
		{
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4.ZERO,
		},
		{
			"size": Vector2i(1600, 900),
			"profile": &"wide",
			"insets": Vector4.ZERO,
		},
		{
			"size": Vector2i(1920, 900),
			"profile": &"wide",
			"insets": Vector4(24, 30, 36, 20),
		},
	]
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport := SubViewport.new()
		var viewport_size: Vector2i = case["size"]
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		fixture_host.add_child(viewport)
		var stage_map := preload("res://ui/screens/venture/StageMapScreen.tscn").instantiate() as Control
		viewport.add_child(stage_map)
		var insets: Vector4 = case["insets"]
		stage_map.call("set_layout", {
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		stage_map.call("set_snapshot", _stage_map_geometry_snapshot())
		_force_realm_control_layout(stage_map)
		var safe_frame := stage_map.get_node_or_null("%SafeFrame") as Control
		var content_scroll := stage_map.get_node_or_null("%ContentScroll") as ScrollContainer
		var content_row := stage_map.get_node_or_null("%ContentRow") as GridContainer
		var left_panel := stage_map.get_node_or_null("%LeftPanel") as Control
		var right_panel := stage_map.get_node_or_null("%RightPanel") as Control
		var stage_scroll := stage_map.get_node_or_null("%StageScroll") as ScrollContainer
		var back_button := stage_map.get_node_or_null("%BackButton") as Button
		var skill_picker := stage_map.find_child("SkillPicker", true, false) as OptionButton
		var prep_bar := stage_map.get_node_or_null("%PrepBar") as Control
		var bottom_bar := stage_map.find_child("BottomBar", true, false) as Control
		if safe_frame == null or content_scroll == null or content_row == null or left_panel == null \
				or right_panel == null or stage_scroll == null or back_button == null \
				or skill_picker == null or prep_bar == null or bottom_bar == null:
			viewport.free()
			return { "ok": false, "error": "StageMap geometry fixture lacks authored layout regions" }
		var scroll_rect := content_scroll.get_global_rect()
		var content_rect := content_row.get_global_rect()
		var bottom_rect := bottom_bar.get_global_rect()
		var safe_top := maxf(16.0, ceilf(insets.y))
		var safe_bottom := maxf(16.0, ceilf(insets.w)) + 88.0 + 8.0
		var expected_body_height := (
			float(viewport_size.y)
			- safe_top
			- safe_bottom
			- 72.0
			- 80.0
			- prep_bar.size.y
		)
		if absf(scroll_rect.size.y - expected_body_height) > 1.0:
			viewport.free()
			return {
				"ok": false,
				"error": "StageMap %s visible body uses %.1f of %.1f available vertical units" % [
					str(viewport_size),
					scroll_rect.size.y,
					expected_body_height,
				],
			}
		if scroll_rect.end.y > bottom_rect.position.y + 0.5:
			viewport.free()
			return { "ok": false, "error": "StageMap content overlaps its fixed bottom action region at %s" % str(viewport_size) }
		var left_rect := left_panel.get_global_rect()
		var right_rect := right_panel.get_global_rect()
		var back_rect := back_button.get_global_rect()
		if back_rect.position.x < maxf(16.0, ceilf(insets.x)) - 0.5 \
				or back_rect.position.y < maxf(16.0, ceilf(insets.y)) - 0.5:
			viewport.free()
			return { "ok": false, "error": "StageMap BackButton ignores converted safe insets at %s" % str(viewport_size) }
		if skill_picker.custom_minimum_size.y < 48.0 or skill_picker.size.y < 48.0:
			viewport.free()
			return { "ok": false, "error": "StageMap party-prep SkillPicker is below the 48-unit target" }
		if str(case["profile"]) == "compact":
			if content_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED \
					or stage_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
					or stage_scroll.mouse_filter != Control.MOUSE_FILTER_PASS:
				viewport.free()
				return { "ok": false, "error": "StageMap compact composition has more than one vertical scroll owner" }
			if left_rect.end.y > right_rect.position.y + 0.5:
				viewport.free()
				return { "ok": false, "error": "StageMap compact panels overlap at %s" % str(viewport_size) }
			if left_rect.position.y > content_rect.position.y + 0.5 \
					or right_rect.end.y < content_rect.end.y - 0.5:
				viewport.free()
				return {
					"ok": false,
					"error": "StageMap compact panel rows do not cover the full scrollable content body",
				}
			if left_rect.size.y < 299.0 or right_rect.size.y < 239.0:
				viewport.free()
				return { "ok": false, "error": "StageMap compact panels collapsed below their readable authored heights" }
			var outer_vbar := content_scroll.get_v_scroll_bar()
			if outer_vbar == null or outer_vbar.max_value <= outer_vbar.page:
				viewport.free()
				return { "ok": false, "error": "StageMap compact secondary panel overflow is not reachable by scrolling" }
			content_scroll.scroll_vertical = 0
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			wheel.factor = 2.0
			wheel.position = stage_scroll.get_global_rect().get_center()
			stage_scroll.gui_input.emit(wheel)
			_force_realm_control_layout(stage_map)
			if content_scroll.scroll_vertical <= 0 or stage_scroll.scroll_vertical != 0:
				viewport.free()
				return { "ok": false, "error": "StageMap wheel input over the compact stage list did not advance its outer scroll owner" }
			content_scroll.ensure_control_visible(right_panel)
			_force_realm_control_layout(stage_map)
			if content_scroll.scroll_vertical <= 0 \
					or not content_scroll.get_global_rect().intersects(right_panel.get_global_rect()):
				viewport.free()
				return { "ok": false, "error": "StageMap compact detail panel cannot be brought into the visible scroll body" }
		else:
			if content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
					or stage_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED \
					or stage_scroll.mouse_filter != Control.MOUSE_FILTER_STOP:
				viewport.free()
				return { "ok": false, "error": "StageMap desktop composition did not return scroll ownership to the stage list" }
			if content_rect.size.y < scroll_rect.size.y - 1.0 \
					or left_rect.size.y < scroll_rect.size.y - 1.0 \
					or right_rect.size.y < scroll_rect.size.y - 1.0:
				viewport.free()
				return { "ok": false, "error": "StageMap desktop panels do not expand through the available body height" }
			if stage_scroll.size.y < scroll_rect.size.y * 0.55:
				viewport.free()
				return { "ok": false, "error": "StageMap stage list remains vertically compacted at %s" % str(viewport_size) }
		viewport.free()
	return { "ok": true }

static func _t_stage_explore_in_tree_vertical_regions() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for StageExplore geometry test" }
	var cases := [
		{
			"name": "compact",
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4.ZERO,
			"hud_width": 520.0,
		},
		{
			"name": "wide",
			"size": Vector2i(1600, 900),
			"profile": &"wide",
			"insets": Vector4.ZERO,
			"hud_width": 720.0,
		},
		{
			"name": "wide_insets",
			"size": Vector2i(1920, 900),
			"profile": &"wide",
			"insets": Vector4(24, 0, 36, 20),
			"hud_width": 720.0,
		},
	]
	var compact_spatial_width := 0.0
	var wide_spatial_width := 0.0
	var compact_hud_width := 0.0
	var wide_hud_width := 0.0
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport := SubViewport.new()
		var viewport_size: Vector2i = case["size"]
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		fixture_host.add_child(viewport)
		var explore := preload("res://ui/screens/venture/StageExploreScreen.tscn").instantiate() as Control
		viewport.add_child(explore)
		var insets: Vector4 = case["insets"]
		var step_row := explore.get_node_or_null("%StepBudgetRow") as Control
		var action_bar := explore.get_node_or_null("%ActionBar") as Control
		var bottom_region := explore.get_node_or_null("%BottomHudRegion") as Control
		var hud_card := explore.get_node_or_null("HudStrip") as PanelContainer
		var directive_badge := explore.get_node_or_null("%DirectiveBadge") as Control
		var stage_info := explore.get_node_or_null("StageInfoPanel") as Control
		var turn_label := explore.get_node_or_null("%TurnLabel") as Label
		var objectives_label := explore.get_node_or_null("%ObjectivesLabel") as Label
		var party_state_label := explore.get_node_or_null("%PartyStateLabel") as Label
		var transient_layer := explore.get_node_or_null("TransientLayer") as CanvasLayer
		if step_row == null or action_bar == null or bottom_region == null \
				or hud_card == null or directive_badge == null or stage_info == null \
				or turn_label == null or objectives_label == null or party_state_label == null \
				or transient_layer == null:
			viewport.free()
			return { "ok": false, "error": "StageExplore lacks authored top or bottom HUD regions" }
		if hud_card.visible or stage_info.visible:
			viewport.free()
			return { "ok": false, "error": "StageExplore authors a blank HUD or preview panel before its first snapshot" }
		explore.call("set_layout", {
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		explore.call("set_snapshot", _stage_explore_reuse_snapshot())
		_force_realm_control_layout(explore)
		var safe_left := maxf(16.0, ceilf(insets.x))
		var safe_top := maxf(16.0, ceilf(insets.y))
		var safe_right := maxf(16.0, ceilf(insets.z))
		var safe_bottom := maxf(16.0, ceilf(insets.w))
		var echo_top := float(viewport_size.y) - safe_bottom - 88.0
		var step_rect := step_row.get_global_rect()
		var action_rect := action_bar.get_global_rect()
		var bottom_rect := bottom_region.get_global_rect()
		var hud_rect := hud_card.get_global_rect()
		var badge_rect := directive_badge.get_global_rect()
		var spatial_rect: Rect2 = explore.call("_explore_spatial_rect", {
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		if not hud_card.visible or not directive_badge.visible \
				or stage_info.visible or stage_info.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			viewport.free()
			return { "ok": false, "error": "Explore entry left a stale preview panel or failed to show its authored HUD cluster" }
		if hud_card.theme_type_variation != &"RealmExploreHudCard" \
				or not is_equal_approx(hud_rect.size.x, float(case["hud_width"])) \
				or not is_equal_approx(hud_rect.size.y, 56.0):
			viewport.free()
			return { "ok": false, "error": "StageExplore HUD is not the capped Living Tree card at %s: %s" % [str(case["name"]), str(hud_rect)] }
		if hud_rect.position.x < safe_left - 0.5 \
				or hud_rect.position.y < safe_top - 0.5 \
				or badge_rect.end.x > float(viewport_size.x) - safe_right + 0.5:
			viewport.free()
			return { "ok": false, "error": "StageExplore top HUD cluster escaped safe bounds at %s" % str(case["name"]) }
		if hud_rect.end.x > badge_rect.position.x - 12.0 + 0.5 \
				or not is_equal_approx(hud_rect.get_center().y, badge_rect.get_center().y):
			viewport.free()
			return { "ok": false, "error": "StageExplore HUD card overlaps or misaligns the Directive badge at %s" % str(case["name"]) }
		if not is_equal_approx(spatial_rect.position.y, hud_rect.end.y + 12.0) \
				or badge_rect.end.y > spatial_rect.position.y - 12.0 + 0.5:
			viewport.free()
			return { "ok": false, "error": "StageExplore top HUD cluster overlaps the reserved spatial field at %s" % str(case["name"]) }
		var hud_input_failure := _assert_realm_control_tree_ignores_input(hud_card)
		var badge_input_failure := _assert_realm_control_tree_ignores_input(directive_badge)
		if not hud_input_failure.is_empty() or not badge_input_failure.is_empty():
			viewport.free()
			return {
				"ok": false,
				"error": hud_input_failure if not hud_input_failure.is_empty() else badge_input_failure,
			}
		if turn_label.text != "Turn 0" \
				or objectives_label.text != "Objectives: 0 / 2" \
				or party_state_label.text != "Exploring":
			viewport.free()
			return { "ok": false, "error": "StageExplore HUD lost one of its three canonical information fields" }
		var hud_style := hud_card.get_theme_stylebox("panel") as StyleBoxFlat
		if hud_style == null:
			viewport.free()
			return { "ok": false, "error": "StageExplore HUD Living Tree style did not resolve" }
		for label in [turn_label, objectives_label, party_state_label]:
			var contrast := _realm_contrast_ratio(label.get_theme_color("font_color"), hud_style.bg_color)
			if label.get_theme_font_size("font_size") < 15 or contrast < 4.5:
				viewport.free()
				return {
					"ok": false,
					"error": "StageExplore HUD label %s is unreadable; size=%d contrast=%.2f" % [
						label.name,
						label.get_theme_font_size("font_size"),
						contrast,
					],
				}
		if bottom_rect.end.y > echo_top - 12.0 + 0.5:
			viewport.free()
			return {
				"ok": false,
				"error": "StageExplore bottom HUD region overlaps EchoBar exclusion at %s" % str(viewport_size),
			}
		if action_rect.end.y > echo_top - 12.0 + 0.5:
			viewport.free()
			return {
				"ok": false,
				"error": "StageExplore actions overlap EchoBar exclusion at %s: action bottom %.1f, EchoBar top %.1f" % [
					str(viewport_size),
					action_rect.end.y,
					echo_top,
				],
			}
		if step_rect.end.y > action_rect.position.y - 12.0 + 0.5:
			viewport.free()
			return { "ok": false, "error": "StageExplore Step budget overlaps action controls at %s" % str(viewport_size) }
		if bottom_rect.size.y < 99.5 or bottom_rect.size.y > 100.5:
			viewport.free()
			return { "ok": false, "error": "StageExplore bottom HUD authored region changed height at %s" % str(viewport_size) }
		if action_rect.position.x < safe_left - 0.5 \
				or action_rect.end.x > float(viewport_size.x) - safe_right + 0.5:
			viewport.free()
			return { "ok": false, "error": "StageExplore action bar escapes horizontal safe bounds at %s" % str(viewport_size) }
		var action_rect_with_steps := action_rect
		step_row.hide()
		_force_realm_control_layout(explore)
		var action_rect_without_steps := action_bar.get_global_rect()
		if action_rect_without_steps != action_rect_with_steps:
			viewport.free()
			return { "ok": false, "error": "StageExplore hiding preview-irrelevant Step budget collapsed or shifted its action region" }
		explore.hide()
		_force_realm_control_layout(explore)
		if transient_layer.visible:
			viewport.free()
			return { "ok": false, "error": "StageExplore transient CanvasLayer remains visible after cross-shell hide" }
		explore.show()
		_force_realm_control_layout(explore)
		if not transient_layer.visible:
			viewport.free()
			return { "ok": false, "error": "StageExplore transient CanvasLayer did not restore with its screen" }
		if str(case["name"]) == "compact":
			compact_spatial_width = spatial_rect.size.x
			compact_hud_width = hud_rect.size.x
		elif str(case["name"]) == "wide":
			wide_spatial_width = spatial_rect.size.x
			wide_hud_width = hud_rect.size.x
		viewport.free()
	if wide_spatial_width <= compact_spatial_width \
			or wide_spatial_width - compact_spatial_width <= wide_hud_width - compact_hud_width:
		return {
			"ok": false,
			"error": "Wide StageExplore does not give surplus width to the spatial field while HUD caps remain stable",
		}
	return { "ok": true }

static func _t_stage_preview_banner_safe_and_scrollable() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Stage preview banner test" }
	var cases := [
		{
			"name": "compact",
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4.ZERO,
			"height": 96.0,
		},
		{
			"name": "wide",
			"size": Vector2i(1600, 900),
			"profile": &"wide",
			"insets": Vector4(24, 20, 36, 16),
			"height": 96.0,
		},
	]
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport := SubViewport.new()
		var viewport_size: Vector2i = case["size"]
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		fixture_host.add_child(viewport)
		var explore := preload("res://ui/screens/venture/StageExploreScreen.tscn").instantiate() as StageExploreScreen
		viewport.add_child(explore)
		var insets: Vector4 = case["insets"]
		explore.set_layout({
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		explore.set_snapshot(_stage_preview_banner_snapshot(false))
		_force_realm_control_layout(explore)
		var panel := explore.get_node_or_null("StageInfoPanel") as PanelContainer
		var back := explore.get_node_or_null("%BackButton") as Button
		var scroll := explore.get_node_or_null("%PreviewInfoScroll") as ScrollContainer
		var columns := explore.get_node_or_null("%InfoColumns") as HBoxContainer
		var title := explore.get_node_or_null("%StageTitleLabel") as Label
		var objective := explore.get_node_or_null("%ObjectiveTitleLabel") as Label
		var directive := explore.get_node_or_null("%DirectiveLabel") as Label
		var proverb := explore.get_node_or_null("%VowProverbLabel") as Label
		var condition := explore.get_node_or_null("%VowConditionLabel") as Label
		if panel == null or back == null or scroll == null or columns == null \
				or title == null or objective == null or directive == null \
				or proverb == null or condition == null:
			viewport.free()
			return { "ok": false, "error": "Stage preview banner authored structure is incomplete" }
		if panel.theme_type_variation != &"RealmStagePreviewCard":
			viewport.free()
			return { "ok": false, "error": "Stage preview banner is not using its Realm Living Tree card role" }
		var labels := columns.find_children("*", "Label", true, false)
		if labels.size() != 5:
			viewport.free()
			return {
				"ok": false,
				"error": "Stage preview banner duplicated information labels; expected 5, got %d" % labels.size(),
			}
		var safe_left := maxf(16.0, ceilf(insets.x))
		var safe_top := maxf(16.0, ceilf(insets.y))
		var safe_right := maxf(16.0, ceilf(insets.z))
		var panel_rect := panel.get_global_rect()
		if panel_rect.position.x < safe_left - 0.5 \
				or panel_rect.end.x > float(viewport_size.x) - safe_right + 0.5 \
				or panel_rect.position.y < safe_top - 0.5:
			viewport.free()
			return { "ok": false, "error": "Stage preview banner escaped safe bounds at %s: %s" % [str(case["name"]), str(panel_rect)] }
		if not is_equal_approx(panel_rect.size.y, float(case["height"])) \
				or panel_rect.size.y >= float(viewport_size.y) * 0.25:
			viewport.free()
			return { "ok": false, "error": "Stage preview banner is not vertically bounded at %s: %s" % [str(case["name"]), str(panel_rect)] }
		if panel_rect.size.x > 1120.5:
			viewport.free()
			return { "ok": false, "error": "Stage preview banner exceeded its readable width cap" }
		if str(case["name"]) == "compact" and back.get_global_rect().intersects(panel_rect):
			viewport.free()
			return { "ok": false, "error": "Compact Back target overlaps the Stage preview banner" }
		if str(case["name"]) == "wide" and not is_equal_approx(panel_rect.size.x, 1120.0):
			viewport.free()
			return { "ok": false, "error": "Wide Stage preview banner did not retain its 1120-unit cap" }
		var preview_rect: Rect2 = explore.call("_preview_safe_rect")
		if not is_equal_approx(preview_rect.position.y, panel_rect.end.y + 16.0):
			viewport.free()
			return { "ok": false, "error": "Preview map top is not derived from the actual banner end" }
		if str(case["name"]) == "compact" and preview_rect.size.y < 239.5:
			viewport.free()
			return { "ok": false, "error": "Compact preview banner leaves less than ~240 units for the spatial field" }
		var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style == null:
			viewport.free()
			return { "ok": false, "error": "Stage preview Living Tree card style is unavailable" }
		for label in [title, objective, directive, proverb, condition]:
			var contrast := _realm_contrast_ratio(label.get_theme_color("font_color"), panel_style.bg_color)
			if contrast < 4.5:
				viewport.free()
				return {
					"ok": false,
					"error": "Stage preview label %s contrast %.2f is below 4.5:1" % [label.name, contrast],
				}
		if title.get_theme_font_size("font_size") < 20 \
				or objective.get_theme_font_size("font_size") < 15 \
				or directive.get_theme_font_size("font_size") < 15 \
				or proverb.get_theme_font_size("font_size") < 15 \
				or condition.get_theme_font_size("font_size") < 15:
			viewport.free()
			return { "ok": false, "error": "Stage preview typography remains below readable authored sizes" }
		var normal_vbar := scroll.get_v_scroll_bar()
		if normal_vbar == null or normal_vbar.max_value > normal_vbar.page + 0.5 or normal_vbar.visible:
			var overflow_error := "Normal Stage preview copy unnecessarily scrolls at %s; max=%.1f page=%.1f visible=%s scroll=%s content_min=%s" % [
				str(case["name"]),
				normal_vbar.max_value if normal_vbar != null else -1.0,
				normal_vbar.page if normal_vbar != null else -1.0,
				str(normal_vbar.visible) if normal_vbar != null else "missing",
				str(scroll.size),
				str(columns.get_combined_minimum_size()),
			]
			viewport.free()
			return { "ok": false, "error": overflow_error }
		explore.set_snapshot(_stage_preview_banner_snapshot(true))
		_force_realm_control_layout(explore)
		var scroll_rect := scroll.get_global_rect()
		var columns_rect := columns.get_global_rect()
		var vbar := scroll.get_v_scroll_bar()
		if not scroll.clip_contents \
				or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
				or columns_rect.position.x < scroll_rect.position.x - 0.5 \
				or columns_rect.end.x > scroll_rect.end.x + 0.5:
			viewport.free()
			return { "ok": false, "error": "Long Stage preview copy is not horizontally contained" }
		if vbar == null or vbar.max_value <= vbar.page or not vbar.visible:
			viewport.free()
			return { "ok": false, "error": "Long Stage preview copy is not reachable through bounded vertical overflow" }
		scroll.scroll_vertical = 0
		for step in range(12):
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			wheel.factor = 2.0
			wheel.position = scroll_rect.get_center()
			viewport.push_input(wheel, true)
		_force_realm_control_layout(explore)
		if scroll.scroll_vertical <= 0:
			viewport.free()
			return { "ok": false, "error": "Long Stage preview copy did not respond to vertical wheel input" }
		scroll.ensure_control_visible(condition)
		_force_realm_control_layout(explore)
		if not scroll_rect.intersects(condition.get_global_rect()):
			viewport.free()
			return { "ok": false, "error": "Stage preview vow condition cannot be brought into the visible banner" }
		viewport.free()
	return { "ok": true }

static func _t_stage_preview_reuse_resets_fade_input_and_focus() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Stage preview reuse test" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var explore := preload("res://ui/screens/venture/StageExploreScreen.tscn").instantiate() as StageExploreScreen
	viewport.add_child(explore)
	explore.set_layout({
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4.ZERO,
	})
	var emitted: Array[Dictionary] = []
	explore.action_requested.connect(func(action: Dictionary) -> void:
		emitted.append(action.duplicate(true))
	)
	explore.set_snapshot(_stage_preview_banner_snapshot(false))
	_force_realm_control_layout(explore)
	var panel := explore.get_node_or_null("StageInfoPanel") as PanelContainer
	var back := explore.get_node_or_null("%BackButton") as Button
	var begin := explore.get_node_or_null("%BeginButton") as Button
	var advance := explore.get_node_or_null("%AdvanceButton") as Button
	var hud_card := explore.get_node_or_null("HudStrip") as PanelContainer
	var turn_label := explore.get_node_or_null("%TurnLabel") as Label
	var objectives_label := explore.get_node_or_null("%ObjectivesLabel") as Label
	var party_state_label := explore.get_node_or_null("%PartyStateLabel") as Label
	if panel == null or back == null or begin == null or advance == null \
			or hud_card == null or turn_label == null \
			or objectives_label == null or party_state_label == null:
		viewport.free()
		return { "ok": false, "error": "Stage preview reuse fixture is incomplete" }
	if not panel.visible or not is_equal_approx(panel.modulate.a, 1.0) \
			or panel.mouse_filter != Control.MOUSE_FILTER_STOP or hud_card.visible:
		viewport.free()
		return { "ok": false, "error": "Preview entry did not establish its banner without a stale explore HUD" }
	if viewport.gui_get_focus_owner() != begin:
		viewport.free()
		return { "ok": false, "error": "Begin was not established as the pre-modal preview focus target" }
	explore.call("_on_begin_pressed")
	var transition := explore.get("_preview_transition_tween") as Tween
	if transition == null:
		viewport.free()
		return { "ok": false, "error": "Begin did not create the preview transition tween" }
	transition.custom_step(1.0)
	_force_realm_control_layout(explore)
	if panel.modulate.a > 0.01 or back.modulate.a > 0.01:
		viewport.free()
		return { "ok": false, "error": "Preview transition did not exercise the StageInfo/Back fade state" }
	if begin.has_focus() or back.has_focus():
		viewport.free()
		return { "ok": false, "error": "Fading preview controls retained focus during transition" }
	var expected_start := {
		"type": "flow.go_state",
		"slot": "cta.start",
		"label": "Begin",
		"to": "flow.stage_explore",
	}
	if emitted.size() != 1 or emitted[0] != expected_start:
		viewport.free()
		return { "ok": false, "error": "Preview transition changed its Begin action: %s" % str(emitted) }
	explore.set_snapshot(_stage_explore_reuse_snapshot())
	_force_realm_control_layout(explore)
	if panel.visible or not is_equal_approx(panel.modulate.a, 1.0) \
			or panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		viewport.free()
		return { "ok": false, "error": "Reused explore mode left StageInfo visible, faded, or input-blocking" }
	if not hud_card.visible or hud_card.modulate != Color.WHITE \
			or turn_label.text.is_empty() or objectives_label.text.is_empty() \
			or party_state_label.text.is_empty():
		viewport.free()
		return { "ok": false, "error": "Reused explore mode left a hidden, faded, or empty information card" }
	if back.visible or not is_equal_approx(back.modulate.a, 1.0) \
			or back.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		viewport.free()
		return { "ok": false, "error": "Reused explore mode left Back visible, faded, or input-blocking" }
	if begin.has_focus() or back.has_focus() or viewport.gui_get_focus_owner() != advance:
		viewport.free()
		return { "ok": false, "error": "Explore mode did not hand focus from hidden preview controls to Advance" }
	explore.set_snapshot(_stage_preview_banner_snapshot(false))
	_force_realm_control_layout(explore)
	if not panel.visible or not is_equal_approx(panel.modulate.a, 1.0) \
			or panel.mouse_filter != Control.MOUSE_FILTER_STOP \
			or not is_equal_approx(back.modulate.a, 1.0) \
			or viewport.gui_get_focus_owner() != begin or hud_card.visible:
		viewport.free()
		return { "ok": false, "error": "Returning to preview did not reset banner/back/focus or hide the explore HUD" }
	viewport.free()
	return { "ok": true }

static func _stage_preview_banner_snapshot(long_copy: bool) -> Dictionary:
	var proverb_twi := "Praye, se woyi baako a na ebu; wokabomu a emmu"
	var proverb_en := "A broomstick breaks alone, but together the bundle cannot be broken."
	var condition_hint := "Travel with three Echoes so the party carries the vow together."
	if long_copy:
		proverb_twi = " ".join(PackedStringArray([proverb_twi, proverb_twi, proverb_twi, proverb_twi]))
		proverb_en = " ".join(PackedStringArray([proverb_en, proverb_en, proverb_en, proverb_en]))
		condition_hint = " ".join(PackedStringArray([
			condition_hint,
			"Keep every companion within the promise while the path narrows.",
			"Do not let the pressure of the Realm separate the travelling party.",
			"The condition remains visible and reviewable before committing to the stage.",
		]))
	return {
		"type": "flow.stage",
		"meta": { "t": 1 },
		"data": {
			"realm_id": "realm.preview.test",
			"stage_id": "stage.preview.test",
			"stage_name": (
				"The Listening Grove Where Every Remembered Path Returns to the Living Tree"
				if long_copy
				else "The Listening Grove"
			),
			"map_width": 6,
			"map_height": 6,
			"map_entry_pos": { "col": 1, "row": 1 },
			"map_situations": [],
			"objective_count": 2,
			"directive": {},
			"active_vow": {
				"proverb_twi": proverb_twi,
				"proverb_en": proverb_en,
				"condition_status": "met",
				"condition_hint": condition_hint,
			},
		},
		"actions": {
			"cta.start": {
				"type": "flow.go_state",
				"slot": "cta.start",
				"label": "Begin",
				"to": "flow.stage_explore",
			},
			"nav.back": {
				"type": "flow.go_state",
				"slot": "nav.back",
				"label": "Back",
				"to": "flow.stage_map",
			},
		},
	}

static func _stage_explore_reuse_snapshot() -> Dictionary:
	return {
		"type": "flow.stage_explore",
		"meta": { "t": 2 },
		"data": {
			"realm_id": "realm.preview.test",
			"stage_id": "stage.preview.test",
			"map_width": 6,
			"map_height": 6,
			"party_pos": { "col": 1, "row": 1 },
			"situations": [],
			"directive": {
				"id": "directive.scout_carefully",
				"label": "Scout Carefully",
			},
			"turn_count": 0,
			"objectives_found": 0,
			"objectives_total": 2,
			"party_state": "exploring",
			"step_budget": 3,
		},
		"actions": {},
	}

static func _stage_map_geometry_snapshot() -> Dictionary:
	var stages: Array = []
	for i in range(6):
		stages.append({
			"id": "stage.%d" % i,
			"name": "Stage %d" % (i + 1),
			"status": "current" if i == 0 else "locked",
			"objectives": [
				{
					"id": "objective.%d" % i,
					"label": "Recover the missing thread",
					"completed": false,
				},
			],
		})
	return {
		"type": "flow.stage_map",
		"meta": { "t": 0 },
		"data": {
			"realm_name": "The Testing Grove",
			"stages": stages,
			"stages_completed_count": 0,
			"realm_complete": false,
			"recovery_segments": [],
			"stage_count": stages.size(),
			"realm_virtue": "courage",
			"party_prep": [
				{
					"echo_id": "echo.test",
					"echo_name": "Ama",
					"calling_id": "guardian",
					"has_unlocked_skills": true,
					"available_skills": [
						{
							"skill_id": "skill.guard",
							"display_name": "Hold Fast",
							"skill_family": "protection",
						},
					],
					"equipped_skill_id": "",
				},
			],
		},
		"actions": {
			"nav.back": {
				"type": "flow.go_state",
				"slot": "nav.back",
				"to": "flow.realm_select",
			},
			"cta.enter_stage": {
				"type": "flow.go_state",
				"slot": "cta.enter_stage",
				"label": "Enter next stage",
				"to": "flow.stage",
			},
		},
	}

static func _contact_picker_payload(layout: Dictionary, turn_current: int, echo_ids: Array) -> Dictionary:
	var bids: Array[Dictionary] = []
	for index in range(echo_ids.size()):
		var echo_id := str(echo_ids[index])
		bids.append({
			"echo_id": echo_id,
			"echo_name": ["Ama", "Kojo", "Esi", "Yaw", "Abena"][index % 5],
			"calling": ["Keeper", "Witness", "Guide", "Mender", "Bearer"][index % 5],
			"emotional_status": ["steady", "grounded", "whole", "uncertain", "radiant"][index % 5],
			"hint": "Offers a distinct perspective grounded in their remembered story.",
			"bid_type": "alignment" if index % 2 == 0 else "reactive",
		})
	return {
		"layout": layout.duplicate(true),
		"contact": {
			"id": "contact.witness.test",
			"name": "Nana Adwoa",
			"role": "witness",
			"role_label": "A Witness",
			"disposition": "bold",
			"fear": 24,
			"morale": 68,
			"turn_current": turn_current,
			"turn_count": 3,
			"npc_line": "Choose who should answer this story.",
			"npc_reaction_word": "Listens",
		},
		"data": {
			"contact_echo_bids": bids,
			"contact_responses": [],
		},
		"actions": {
			"cta.consult_echoes": {
				"type": "stage.consult_echoes",
				"slot": "cta.consult_echoes",
			},
			"cta.disengage_contact": {
				"type": "stage.disengage_contact",
				"slot": "cta.disengage_contact",
			},
		},
	}

static func _contact_response_payload(layout: Dictionary, turn_current: int) -> Dictionary:
	var response_action := {
		"type": "stage.speak_response",
		"slot": "cta.speak_response.echo.1",
		"payload": { "echo_id": "echo.1" },
	}
	return {
		"layout": layout.duplicate(true),
		"contact": {
			"id": "contact.witness.test",
			"name": "Nana Adwoa",
			"role": "witness",
			"role_label": "A Witness",
			"disposition": "bold",
			"fear": 24,
			"morale": 68,
			"turn_current": turn_current,
			"turn_count": 3,
			"npc_line": "Ama has chosen her response.",
			"npc_reaction_word": "Listens",
		},
		"data": {
			"contact_echo_bids": [],
			"contact_responses": [
				{
					"echo_id": "echo.1",
					"echo_name": "Ama",
					"calling": "Keeper",
					"emotional_status": "steady",
					"response_text": "I will answer with the memory we recovered.",
					"stat_texture": "Courage +2",
					"bid_type": "alignment",
				},
			],
		},
		"actions": {
			"cta.speak_response.echo.1": response_action,
			"cta.disengage_contact": {
				"type": "stage.disengage_contact",
				"slot": "cta.disengage_contact",
			},
		},
	}

static func _force_realm_control_layout(root: Node) -> void:
	for pass_index in range(4):
		root.propagate_notification(Control.NOTIFICATION_RESIZED)
		root.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)

static func _is_descendant_of_realm(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

static func _assert_realm_control_tree_ignores_input(root: Node) -> String:
	if root is Control:
		var control := root as Control
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return "%s can block StageExplore spatial input" % str(control.get_path())
	for child in root.get_children():
		var failure := _assert_realm_control_tree_ignores_input(child)
		if not failure.is_empty():
			return failure
	return ""

static func _realm_contrast_ratio(a: Color, b: Color) -> float:
	var lighter := maxf(_realm_relative_luminance(a), _realm_relative_luminance(b))
	var darker := minf(_realm_relative_luminance(a), _realm_relative_luminance(b))
	return (lighter + 0.05) / (darker + 0.05)

static func _realm_relative_luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	var linear: Array[float] = []
	for channel_v in channels:
		var channel := float(channel_v)
		linear.append(channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

static func _t_realm_target_minima_and_spatial_caps() -> Dictionary:
	var scenes := [
		preload("res://ui/screens/venture/StageMapScreen.tscn"),
		preload("res://ui/screens/venture/StageExploreScreen.tscn"),
		preload("res://ui/screens/combat/CombatBoardScreen.tscn"),
		preload("res://ui/screens/venture/ResolveScreen.tscn"),
		preload("res://ui/screens/venture/DirectiveSelectOverlay.tscn"),
		preload("res://ui/overlays/realm/ContactModal.tscn"),
		preload("res://ui/overlays/realm/PrebattleModal.tscn"),
		preload("res://ui/overlays/realm/EngagementModal.tscn"),
		preload("res://ui/overlays/realm/SituationModal.tscn"),
		preload("res://ui/overlays/realm/ReturnHomeModal.tscn"),
	]
	for packed in scenes:
		var root: Node = (packed as PackedScene).instantiate()
		var failure := _assert_button_target_minima(root)
		root.free()
		if not failure.is_empty():
			return { "ok": false, "error": failure }

	var shell_scene := preload("res://ui/shells/RealmShell.tscn")
	var shell := shell_scene.instantiate()
	if shell == null:
		return { "ok": false, "error": "Failed to instantiate RealmShell" }
	var overlay_root := shell.get_node_or_null("OverlayRoot") as Control
	if overlay_root == null or overlay_root.offset_bottom != 0.0:
		shell.free()
		return { "ok": false, "error": "RealmShell OverlayRoot is not full viewport" }
	var chrome_root := shell.get_node_or_null("ChromeLayer/ChromeRoot") as Control
	var echo_bar_frame := shell.get_node_or_null("%EchoBarFrame") as Control
	var echo_bar_scroll := shell.get_node_or_null("%EchoBarScroll") as ScrollContainer
	var echo_bar := shell.get_node_or_null("%EchoBar") as Control
	if chrome_root == null or chrome_root.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		shell.free()
		return { "ok": false, "error": "Realm full-screen chrome root must ignore pointer input" }
	shell.set("_echo_bar", echo_bar)
	shell.call("set_layout", {
		"profile": &"standard",
		"logical_size": Vector2(1280, 720),
		"safe_insets": Vector4.ZERO,
	})
	if echo_bar_frame == null \
			or echo_bar_frame.offset_left != 16.0 \
			or echo_bar_frame.offset_right != 1264.0 \
			or echo_bar_frame.offset_bottom != -16.0 \
			or echo_bar_frame.offset_top != -104.0:
		shell.free()
		return { "ok": false, "error": "Realm EchoBar frame must retain 16-unit safe edges" }
	if echo_bar_scroll == null \
			or not echo_bar_scroll.clip_contents \
			or echo_bar_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		shell.free()
		return { "ok": false, "error": "Realm EchoBar must use an authored clipped horizontal scroller" }
	if echo_bar == null or echo_bar.get_parent() != echo_bar_scroll:
		shell.free()
		return { "ok": false, "error": "Realm EchoBar cards are not contained by the bounded scroller" }
	shell.free()

	var stage_explore_scene := preload("res://ui/screens/venture/StageExploreScreen.tscn")
	var stage_explore := stage_explore_scene.instantiate()
	if stage_explore == null:
		return { "ok": false, "error": "Failed to instantiate StageExploreScreen" }
	stage_explore.set("_hud_strip", stage_explore.get_node("HudStrip"))
	stage_explore.set("_stage_info", stage_explore.get_node("StageInfoPanel"))
	stage_explore.set("_back_btn", stage_explore.get_node("%BackButton"))
	stage_explore.set("_bottom_hud_region", stage_explore.get_node("%BottomHudRegion"))
	stage_explore.set("_step_budget_row", stage_explore.get_node("%StepBudgetRow"))
	stage_explore.set("_directive_badge", stage_explore.get_node("%DirectiveBadge"))
	stage_explore.set("_party_layer", stage_explore.get_node("PartyTokenLayer"))
	stage_explore.call("set_layout", {
		"profile": &"wide",
		"logical_size": Vector2(1800, 900),
		"safe_insets": Vector4.ZERO,
	})
	var directive_badge := stage_explore.get_node_or_null("%DirectiveBadge") as PanelContainer
	if directive_badge == null or absf((directive_badge.offset_right - directive_badge.offset_left) - 204.0) > 0.1:
		stage_explore.queue_free()
		return { "ok": false, "error": "StageExplore directive badge is not capped while field gains wide space" }
	var board := stage_explore.get_node_or_null("Board") as TileMapLayer
	if board == null:
		stage_explore.queue_free()
		return { "ok": false, "error": "StageExplore board missing" }
	board.set_cell(Vector2i(4, 7), 0, Vector2i.ZERO)
	board.set_cell(Vector2i(5, 7), 0, Vector2i.ZERO)
	board.set_cell(Vector2i(6, 8), 0, Vector2i.ZERO)
	board.set_cell(Vector2i(8, 10), 0, Vector2i.ZERO)
	board.set_cell(Vector2i(9, 10), 0, Vector2i.ZERO)
	stage_explore.set("_board", board)
	stage_explore.call("_build_preview", 30, 30)
	var first_cell := Vector2i(4, 7)
	var last_cell := Vector2i(9, 10)
	var tl := board.map_to_local(first_cell)
	var tr := board.map_to_local(Vector2i(last_cell.x, first_cell.y))
	var bl := board.map_to_local(Vector2i(first_cell.x, last_cell.y))
	var br := board.map_to_local(last_cell)
	var center_min := Vector2(
		minf(minf(tl.x, tr.x), minf(bl.x, br.x)),
		minf(minf(tl.y, tr.y), minf(bl.y, br.y))
	)
	var center_max := Vector2(
		maxf(maxf(tl.x, tr.x), maxf(bl.x, br.x)),
		maxf(maxf(tl.y, tr.y), maxf(bl.y, br.y))
	)
	# Independent authored-tile footprint: 128×96 texture, origin y=-16.
	var visual_min := center_min - Vector2(64, 64)
	var visual_max := center_max + Vector2(64, 32)
	var preview_scale := float(stage_explore.get("_preview_scale"))
	var transformed_min := board.position + visual_min * preview_scale
	var transformed_max := board.position + visual_max * preview_scale
	var safe_preview: Rect2 = stage_explore.call("_preview_safe_rect")
	var epsilon := 0.1
	if transformed_min.x < safe_preview.position.x - epsilon \
			or transformed_min.y < safe_preview.position.y - epsilon \
			or transformed_max.x > safe_preview.end.x + epsilon \
			or transformed_max.y > safe_preview.end.y + epsilon:
		stage_explore.queue_free()
		return {
			"ok": false,
			"error": "Stage preview tile visuals escape safe bounds; visual=%s..%s safe=%s" % [
				str(transformed_min),
				str(transformed_max),
				str(safe_preview),
			],
		}
	var visual_size := visual_max - visual_min
	var expected_scale := minf(safe_preview.size.x / visual_size.x, safe_preview.size.y / visual_size.y)
	if not is_equal_approx(preview_scale, expected_scale):
		stage_explore.queue_free()
		return {
			"ok": false,
			"error": "Stage preview leaves usable spatial area idle; scale=%f expected=%f" % [
				preview_scale,
				expected_scale,
			],
		}
	stage_explore.set("_current_mode", &"preview")
	stage_explore.set("_current_map_size", Vector2i(30, 30))
	stage_explore.call("set_layout", {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4.ZERO,
	})
	var compact_preview_scale := float(stage_explore.get("_preview_scale"))
	if is_equal_approx(compact_preview_scale, preview_scale):
		stage_explore.queue_free()
		return { "ok": false, "error": "Stage preview did not refit after a live profile change" }
	var compact_preview_rect: Rect2 = stage_explore.call("_preview_safe_rect")
	if compact_preview_rect.size.y < 240.0:
		stage_explore.queue_free()
		return {
			"ok": false,
			"error": "Stage compact preview leaves only %.1f units for the spatial field" % compact_preview_rect.size.y,
		}
	stage_explore.set("_current_mode", &"explore")
	var compact_layout := {
		"profile": &"compact",
		"logical_size": Vector2(960, 540),
		"safe_insets": Vector4.ZERO,
	}
	var compact_focus: Vector2 = (stage_explore.call("_explore_spatial_rect", compact_layout) as Rect2).get_center()
	var focused_world_point := (visual_min + visual_max) * 0.5
	board.scale = Vector2(0.77, 0.77)
	board.position = compact_focus - focused_world_point * board.scale.x
	var compact_board_position := board.position
	stage_explore.call("set_layout", {
		"profile": &"wide",
		"logical_size": Vector2(1800, 900),
		"safe_insets": Vector4.ZERO,
	})
	var wide_layout := {
		"profile": &"wide",
		"logical_size": Vector2(1800, 900),
		"safe_insets": Vector4.ZERO,
	}
	var wide_focus: Vector2 = (stage_explore.call("_explore_spatial_rect", wide_layout) as Rect2).get_center()
	var focused_after_resize := (wide_focus - board.position) / board.scale.x
	if not focused_after_resize.is_equal_approx(focused_world_point) \
			or board.scale != Vector2(0.77, 0.77) \
			or board.position == compact_board_position:
		stage_explore.queue_free()
		return { "ok": false, "error": "StageExplore live resize did not preserve its focused world point and zoom" }
	stage_explore.queue_free()

	var combat_scene := preload("res://ui/screens/combat/CombatBoardScreen.tscn")
	var combat := combat_scene.instantiate()
	if combat == null:
		return { "ok": false, "error": "Failed to instantiate CombatBoardScreen" }
	combat.set("_back_button", combat.get_node("BackButton"))
	combat.set("_board", combat.get_node("Board"))
	combat.set("_move_telegraph_layer", combat.get_node("MoveTelegraphLayer"))
	combat.set("_token_layer", combat.get_node("TokenLayer"))
	combat.set("_distance_layer", combat.get_node("DistanceLayer"))
	combat.set("_round_label", combat.get_node("RoundLabel"))
	combat.set("_objective_banner", combat.get_node("%ObjectiveBanner"))
	combat.set("_recenter_button", combat.get_node("%RecenterButton"))
	combat.set("_cta_button", combat.get_node("StartCombatButton"))
	combat.set("_manual_toggle", combat.get_node("AutoToggleButton"))
	combat.set("_initiative_panel", combat.get_node("InitiativePanel"))
	combat.set("_prebattle_panel", combat.get_node("PrebattlePanel"))
	combat.set("_current_cols", 0)
	combat.set("_current_rows", 0)
	combat.call("set_layout", {
		"profile": &"wide",
		"logical_size": Vector2(1800, 900),
		"safe_insets": Vector4.ZERO,
	})
	var objective_banner := combat.get_node_or_null("%ObjectiveBanner") as PanelContainer
	var initiative_panel := combat.get_node_or_null("InitiativePanel") as PanelContainer
	if objective_banner == null or absf((objective_banner.offset_right - objective_banner.offset_left) - 344.0) > 0.1:
		combat.queue_free()
		return { "ok": false, "error": "Combat objective panel is not capped while board gains wide space" }
	if initiative_panel == null or absf((initiative_panel.offset_right - initiative_panel.offset_left) - 240.0) > 0.1:
		combat.queue_free()
		return { "ok": false, "error": "Combat initiative panel is not capped while board gains wide space" }
	combat.queue_free()
	return { "ok": true }

static func _assert_button_target_minima(root: Node) -> String:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is Button):
			continue
		var button := node as Button
		var min_size := button.custom_minimum_size
		var authored_width := min_size.x
		if authored_width <= 0.0:
			authored_width = absf(button.offset_right - button.offset_left)
		if authored_width <= 0.0 and (button.size_flags_horizontal & Control.SIZE_EXPAND) != 0:
			authored_width = 48.0
		if button.name == "CardButton":
			var parent_control := button.get_parent() as Control
			if parent_control != null:
				authored_width = maxf(authored_width, parent_control.custom_minimum_size.x)
				min_size.y = maxf(min_size.y, parent_control.custom_minimum_size.y)
		var required_height := 56.0 if button.theme_type_variation == &"ButtonPrimary" else 48.0
		if authored_width < 48.0 or min_size.y < required_height:
			return "%s/%s target is below minimum; width=%.1f height=%.1f required_height=%.1f" % [
				root.name,
				button.name,
				authored_width,
				min_size.y,
				required_height,
			]
	return ""

static func _t_hidden_realm_chrome_does_not_block_sanctum_nav() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Realm-to-Sanctum input regression" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var sanctum_scene := preload("res://ui/shells/SanctumShell.tscn")
	var realm_scene := preload("res://ui/shells/RealmShell.tscn")
	var sanctum := sanctum_scene.instantiate() as SanctumShell
	var realm := realm_scene.instantiate() as RealmShell
	# Realm is deliberately later in tree order: if its layer remains active, its
	# overlapping EchoBar wins input over the Sanctum rail.
	viewport.add_child(sanctum)
	viewport.add_child(realm)
	var layout := {
		"profile": &"standard",
		"logical_size": Vector2(1280, 720),
		"safe_insets": Vector4.ZERO,
	}
	sanctum.set_layout(layout)
	realm.set_layout(layout)
	sanctum.set_snapshot({
		"type": "flow.sanctum",
		"meta": { "t": 1 },
		"data": {},
		"actions": {
			"nav.echo_party": {
				"type": "flow.go_state",
				"slot": "nav.echo_party",
				"label": "Party",
				"to": "flow.echo_party",
			},
		},
	})
	sanctum.hide()
	realm.show()
	_force_realm_control_layout(sanctum)
	_force_realm_control_layout(realm)
	var chrome_layer := realm.get_node_or_null("ChromeLayer") as CanvasLayer
	if chrome_layer == null or not chrome_layer.visible:
		viewport.free()
		return { "ok": false, "error": "Visible RealmShell did not activate its ChromeLayer" }
	var nav_actions: Array[Dictionary] = []
	sanctum.action_requested.connect(func(action: Dictionary) -> void:
		nav_actions.append(action.duplicate(true))
	)
	var party_button := sanctum.get_node_or_null("%PartyButton") as Button
	var echo_frame := realm.get_node_or_null("%EchoBarFrame") as Control
	if party_button == null or echo_frame == null:
		viewport.free()
		return { "ok": false, "error": "Missing real Sanctum Party target or Realm EchoBar frame" }
	realm.hide()
	sanctum.show()
	_force_realm_control_layout(sanctum)
	_force_realm_control_layout(realm)
	if chrome_layer.visible:
		viewport.free()
		return { "ok": false, "error": "Hidden RealmShell left its CanvasLayer active over Sanctum" }
	if not party_button.is_visible_in_tree() or party_button.disabled:
		viewport.free()
		return { "ok": false, "error": "Sanctum Party action was not reachable after Realm routing" }
	var party_center := party_button.get_global_rect().get_center()
	if not echo_frame.get_global_rect().has_point(party_center):
		viewport.free()
		return { "ok": false, "error": "Input fixture did not overlap the Realm EchoBar and Sanctum Party target" }
	_push_realm_pointer_click(viewport, party_center)
	var expected_action := {
		"type": "flow.go_state",
		"slot": "nav.echo_party",
		"label": "Party",
		"to": "flow.echo_party",
	}
	if nav_actions.size() != 1 or nav_actions[0] != expected_action:
		viewport.free()
		return {
			"ok": false,
			"error": "Expected one unchanged Party nav action after Realm hide, got %s" % str(nav_actions),
		}
	viewport.free()
	return { "ok": true }

static func _t_ancestor_hide_disables_realm_chrome() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for Realm inherited visibility regression" }
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var ancestor := Control.new()
	ancestor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(ancestor)
	var realm_scene := preload("res://ui/shells/RealmShell.tscn")
	var realm := realm_scene.instantiate() as RealmShell
	ancestor.add_child(realm)
	var chrome_layer := realm.get_node_or_null("ChromeLayer") as CanvasLayer
	if chrome_layer == null or not chrome_layer.visible:
		viewport.free()
		return { "ok": false, "error": "Visible Realm ancestor did not activate ChromeLayer" }
	ancestor.hide()
	if chrome_layer.visible:
		viewport.free()
		return { "ok": false, "error": "Ancestor-hidden RealmShell left ChromeLayer active" }
	ancestor.show()
	if not chrome_layer.visible:
		viewport.free()
		return { "ok": false, "error": "Restored Realm ancestor did not reactivate ChromeLayer" }
	viewport.free()
	return { "ok": true }

static func _t_echo_bar_safe_geometry_matrix() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var fixture_host := tree.current_scene.get_node_or_null("UISnapshotRenderer") if tree != null and tree.current_scene != null else null
	if fixture_host == null:
		return { "ok": false, "error": "Ready fixture host unavailable for EchoBar geometry regression" }
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fixture_host.add_child(viewport)
	var realm_scene := preload("res://ui/shells/RealmShell.tscn")
	var realm := realm_scene.instantiate() as RealmShell
	viewport.add_child(realm)
	var party: Array = []
	for index in range(5):
		party.append({
			"name": "Echo %d" % index,
			"rank": 1,
			"calling_origin": "Warden",
			"emotional_status": "Steady",
		})
	realm.call("_update_echo_bar", {
		"type": "flow.stage",
		"data": { "party_preview": party },
	})
	var frame := realm.get_node_or_null("%EchoBarFrame") as Control
	var scroll := realm.get_node_or_null("%EchoBarScroll") as ScrollContainer
	var echo_bar := realm.get_node_or_null("%EchoBar") as HBoxContainer
	if frame == null or scroll == null or echo_bar == null:
		viewport.free()
		return { "ok": false, "error": "Realm EchoBar bounded frame structure is incomplete" }
	if not scroll.clip_contents \
			or scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED \
			or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		viewport.free()
		return { "ok": false, "error": "EchoBar overflow is not clipped and horizontally reachable" }
	var cases := [
		{
			"name": "compact",
			"size": Vector2i(960, 540),
			"profile": &"compact",
			"insets": Vector4.ZERO,
		},
		{
			"name": "desktop",
			"size": Vector2i(1600, 900),
			"profile": &"wide",
			"insets": Vector4.ZERO,
		},
		{
			"name": "ultrawide_cutout",
			"size": Vector2i(3440, 1440),
			"profile": &"wide",
			"insets": Vector4(80, 32, 120, 48),
		},
	]
	var desktop_card_size := Vector2.ZERO
	var desktop_frame_width := 0.0
	for case_v in cases:
		var case: Dictionary = case_v
		var viewport_size: Vector2i = case["size"]
		var insets: Vector4 = case["insets"]
		viewport.size = viewport_size
		realm.set_layout({
			"profile": case["profile"],
			"logical_size": Vector2(viewport_size),
			"safe_insets": insets,
		})
		scroll.scroll_horizontal = 0
		_force_realm_control_layout(realm)
		var frame_rect := frame.get_global_rect()
		var safe_left := maxf(16.0, ceilf(insets.x))
		var safe_right := maxf(16.0, ceilf(insets.z))
		var safe_bottom := maxf(16.0, ceilf(insets.w))
		var available_width := float(viewport_size.x) - safe_left - safe_right
		var expected_width := minf(1440.0, available_width)
		var expected_left := safe_left + maxf(0.0, (available_width - expected_width) * 0.5)
		var expected_rect := Rect2(
			Vector2(expected_left, float(viewport_size.y) - safe_bottom - 88.0),
			Vector2(expected_width, 88.0)
		)
		if not frame_rect.position.is_equal_approx(expected_rect.position) \
				or not frame_rect.size.is_equal_approx(expected_rect.size):
			viewport.free()
			return {
				"ok": false,
				"error": "EchoBar frame escaped safe/capped geometry at %s; got=%s expected=%s" % [
					str(case["name"]),
					str(frame_rect),
					str(expected_rect),
				],
			}
		var scroll_rect := scroll.get_global_rect()
		if scroll_rect.position.x < safe_left - 0.1 \
				or scroll_rect.end.x > float(viewport_size.x) - safe_right + 0.1 \
				or scroll_rect.end.y > float(viewport_size.y) - safe_bottom + 0.1:
			viewport.free()
			return { "ok": false, "error": "EchoBar clipped viewport escaped safe rect at %s" % str(case["name"]) }
		var cards := echo_bar.get_children()
		if cards.size() != 5:
			viewport.free()
			return { "ok": false, "error": "EchoBar card order/count changed during responsive layout" }
		var first_card := cards[0] as Control
		var last_card := cards[cards.size() - 1] as Control
		if first_card == null or last_card == null:
			viewport.free()
			return { "ok": false, "error": "EchoBar fixture cards were not Controls" }
		var hbar := scroll.get_h_scroll_bar()
		if echo_bar.get_combined_minimum_size().x > scroll.size.x + 0.1:
			if hbar == null or hbar.max_value <= hbar.page:
				viewport.free()
				return { "ok": false, "error": "Overflowing EchoBar is not horizontally scrollable at %s" % str(case["name"]) }
			if not hbar.visible or not hbar.is_visible_in_tree():
				viewport.free()
				return { "ok": false, "error": "Overflowing EchoBar scrollbar is not discoverable at %s" % str(case["name"]) }
			if not scroll_rect.intersects(first_card.get_global_rect()):
				viewport.free()
				return { "ok": false, "error": "First EchoBar card is not reachable at scroll origin" }
			if str(case["name"]) == "compact":
				var drag_start := scroll_rect.position + Vector2(scroll_rect.size.x - 24.0, scroll_rect.size.y * 0.5)
				var drag_end := scroll_rect.position + Vector2(24.0, scroll_rect.size.y * 0.5)
				_push_realm_touch_drag(viewport, drag_start, drag_end)
				_force_realm_control_layout(realm)
			scroll.scroll_horizontal = 0
			_force_realm_control_layout(realm)
			_push_realm_horizontal_wheel(viewport, scroll_rect.get_center(), 12)
			_force_realm_control_layout(realm)
			if scroll.scroll_horizontal <= 0:
				viewport.free()
				return {
					"ok": false,
					"error": "EchoBar did not respond to real horizontal-wheel input at %s" % str(case["name"]),
				}
			if not scroll_rect.intersects(last_card.get_global_rect()):
				viewport.free()
				return {
					"ok": false,
					"error": "Last EchoBar card is not reachable after real horizontal-wheel input at %s" % str(case["name"]),
				}
		if first_card.get_global_rect().position.y < scroll_rect.position.y - 0.1 \
				or first_card.get_global_rect().end.y > scroll_rect.end.y + 0.1:
			viewport.free()
			return { "ok": false, "error": "EchoBar card is vertically clipped by its horizontal scroll policy" }
		if str(case["name"]) == "desktop":
			desktop_card_size = first_card.size
			desktop_frame_width = frame_rect.size.x
		elif str(case["name"]) == "ultrawide_cutout":
			if not first_card.size.is_equal_approx(desktop_card_size):
				viewport.free()
				return { "ok": false, "error": "Echo cards uniformly enlarged on ultrawide layout" }
			if not is_equal_approx(frame_rect.size.x, desktop_frame_width):
				viewport.free()
				return { "ok": false, "error": "EchoBar frame grew beyond its wide-layout cap" }
	viewport.free()
	return { "ok": true }

static func _push_realm_pointer_click(viewport: SubViewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	viewport.push_input(release, true)

static func _push_realm_accept(viewport: SubViewport) -> void:
	var press := InputEventAction.new()
	press.action = &"ui_accept"
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	viewport.push_input(release, true)

static func _push_realm_touch_drag(viewport: SubViewport, start: Vector2, end: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	viewport.push_input(touch, true)
	var previous := start
	for step in range(1, 7):
		var position := start.lerp(end, float(step) / 6.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = position
		drag.relative = position - previous
		drag.velocity = drag.relative * 60.0
		viewport.push_input(drag, true)
		previous = position
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = end
	release.pressed = false
	viewport.push_input(release, true)

static func _push_realm_horizontal_wheel(viewport: SubViewport, position: Vector2, steps: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	for step in range(steps):
		var wheel := InputEventMouseButton.new()
		wheel.position = position
		wheel.global_position = position
		wheel.button_index = MOUSE_BUTTON_WHEEL_RIGHT
		wheel.factor = 1.0
		wheel.pressed = true
		viewport.push_input(wheel, true)
