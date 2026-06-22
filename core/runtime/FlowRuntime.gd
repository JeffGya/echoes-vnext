# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

const FlowWeavingRiteStateScript  := preload("res://core/state/flow/states/sanctum/FlowWeavingRiteState.gd")
const WeavingRiteServiceScript    := preload("res://core/progression/WeavingRiteService.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")  # V2-STAGE-001
const FlowKeeperIntroStateScript  := preload("res://core/state/flow/states/onboarding/FlowKeeperIntroState.gd")
const KeeperIntroServiceScript    := preload("res://core/onboarding/KeeperIntroService.gd")
const StageExploreModelScript     := preload("res://core/realms/StageExploreModel.gd")                          # V2-STAGE-001
const SituationModelScript        := preload("res://core/realms/SituationModel.gd")                             # V2-STAGE-001
const ObjectiveModelScript        := preload("res://core/realms/ObjectiveModel.gd")                             # V2-STAGE-002
const ConversationServiceScript    := preload("res://core/realms/ConversationService.gd")    # V2-STAGE-003
const ContactModelScript           := preload("res://core/realms/ContactModel.gd")            # V2-STAGE-003
const SituationResolutionServiceScript := preload("res://core/realms/SituationResolutionService.gd")  # V2-STAGE-004
const StageTerrainScript               := preload("res://core/realms/StageTerrain.gd")                  # V2-STAGE-004-P2
## ConsequencePassService kept on disk for future use; not preloaded here.
const EmotionRecoveryServiceScript := preload("res://core/emotion/EmotionRecoveryService.gd")                    # V2-SANCTUM-001
const InstitutionServiceScript     := preload("res://core/sanctum/InstitutionService.gd")                         # V2-SANCTUM-002
const LeadershipEmotionServiceScript := preload("res://core/combat/LeadershipEmotionService.gd")

var logger: StructuredLogger
var config_service: ConfigService
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine
var econ: EconomyService
var directive_service: DirectiveService  # DIRECTIVE-001
var save_path: String

func _init(
	_logger: StructuredLogger,
	_config_service: ConfigService,
	_save_path: String = SaveSchema.DEFAULT_SAVE_PATH
) -> void:
	logger = _logger
	config_service = _config_service
	save_path = _save_path

func _next_tick() -> int:
	var t := flow_ctx.sim_tick
	flow_ctx.sim_tick += 1
	return t

func boot() -> Dictionary:
	# Flow owned ticks should start counting.
	flow_ctx = FlowContext.new()
	flow_ctx.sim_tick = 0
	flow_ctx.config_service = config_service
	flow_ctx.logger = logger  # GRID-002: allows flow states to log without changing State.enter() signature

	logger.debug(_next_tick(), "boot.start", "Boot sequence started", {})

	# Load configs
	var ok_balance := config_service.load_balance(logger, _next_tick())
	var ok_actors := config_service.load_actors(logger, _next_tick())
	var ok_realms := config_service.load_realms(logger, _next_tick())

	if not (ok_balance and ok_actors and ok_realms):
		logger.log_state_transition(_next_tick(), "boot", "error", "config_invalid")
		var snap := {
			"type": "error",
			"meta": { "tick": flow_ctx.sim_tick },
			"data": { "message": "Configuration validation failed. See logs." }
		}
		_log_snapshot_emitted(flow_ctx.sim_tick, snap, "boot.error")
		flow_ctx.last_snapshot = snap
		return snap

	# Save load/create. Only a genuinely absent save may create a new campaign.
	var load_result := SaveService.load_from_file(save_path, logger, _next_tick())
	var load_status := str(load_result.get("status", SaveService.LOAD_ERROR))
	var save: Dictionary = {}
	if load_status == SaveService.LOAD_MISSING:
		save = SaveService.make_new_save(12346)
		if not SaveService.save_to_file(save_path, save, logger, _next_tick()):
			return _build_save_error_snapshot(
				"The game could not create a verified save. Your campaign was not started.",
				load_result
			)
	elif load_status == SaveService.LOAD_ERROR:
		return _build_save_error_snapshot(
			"Your save files could not be verified. They were left untouched so recovery remains possible.",
			load_result
		)
	else:
		var loaded_data_v: Variant = load_result.get("data", {})
		if loaded_data_v is Dictionary:
			save = loaded_data_v
		if save.is_empty():
			return _build_save_error_snapshot(
				"A save was detected but no verified campaign data could be loaded.",
				load_result
			)

	flow_ctx.save_data = save
	if bool(load_result.get("needs_save_retry", false)):
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "save.recovery_retry"

	# V2-VOW-002: restore broken vow debuff chip from save (survives restarts).
	var _boot_sanc_v: Variant = save.get("sanctum", {})
	if _boot_sanc_v is Dictionary:
		var _boot_pbe_v: Variant = (_boot_sanc_v as Dictionary).get("pending_broken_vow_effect", {})
		if _boot_pbe_v is Dictionary and not (_boot_pbe_v as Dictionary).is_empty():
			flow_ctx.session_broken_vow_effect = (_boot_pbe_v as Dictionary).duplicate()

	# REALM-001: populate campaign_seed from save (was always null before this story)
	var _boot_camp_v: Variant = flow_ctx.save_data.get("campaign", {})
	var _boot_camp: Dictionary = _boot_camp_v if _boot_camp_v is Dictionary else {}
	flow_ctx.campaign_seed = CampaignSeed.new(int(_boot_camp.get("root_seed", 0)))

	# REALM-001: restore active realm_id from save (survives Continue)
	var _boot_realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var _boot_realms: Dictionary = _boot_realms_v if _boot_realms_v is Dictionary else {}
	for _rid in _boot_realms:
		var _rm: Dictionary = _boot_realms[_rid] if _boot_realms[_rid] is Dictionary else {}
		if _rm.get("status", "") == "active":
			flow_ctx.realm_id = str(_rid)
			break

	econ = EconomyService.new(flow_ctx.save_data)
	directive_service = DirectiveService.new(flow_ctx.save_data)  # DIRECTIVE-001
	directive_service.load_from_config(config_service.get_balance())  # V2-STAGE-004-P2: wire traversal fields

	# Flow state machine
	flow_machine = FlowStateMachine.new()
	flow_machine.register_default_states()
	flow_machine.start(flow_ctx, logger, _next_tick())

	# Flow should have placed last_snapshot already
	var out := flow_ctx.last_snapshot
	if load_status == SaveService.LOAD_RECOVERED:
		var out_meta_v: Variant = out.get("meta", {})
		var out_meta: Dictionary = out_meta_v if out_meta_v is Dictionary else {}
		out_meta["save_recovery"] = {
			"source": str(load_result.get("source", "backup")),
			"generation": int(load_result.get("generation", 0)),
			"message": "Your campaign was recovered from a verified backup. Your latest action may need repeating.",
		}
		out["meta"] = out_meta
		flow_ctx.last_snapshot = out
	_log_snapshot_emitted(flow_ctx.sim_tick, out, "boot.complete")
	return out

func _build_save_error_snapshot(message: String, load_result: Dictionary) -> Dictionary:
	var snap := {
		"type": "flow.save_error",
		"meta": {
			"t": flow_ctx.sim_tick,
			"save_status": str(load_result.get("status", SaveService.LOAD_ERROR)),
		},
		"data": {
			"title": "Campaign Save Needs Attention",
			"message": message,
			"detail": "Do not delete or replace the files. Restart once storage is available, or keep them for support recovery.",
		},
		"actions": {},
	}
	flow_ctx.last_snapshot = snap
	_log_snapshot_emitted(flow_ctx.sim_tick, snap, "boot.save_error")
	return snap

func dispatch(action: Dictionary) -> Dictionary:
	var t := _next_tick()
	var action_type := str(action.get("type", ""))
	if flow_ctx.weave_commit_locked and action_type != "weave.confirm":
		logger.debug(t, "weave.commit.locked", "Action blocked by weaving commitment lock", {
			"blocked_action": action_type,
		})
		var locked_out := flow_ctx.last_snapshot
		_log_snapshot_emitted(t, locked_out, "dispatch.weave_locked")
		return locked_out

	match action_type:
		
		# ---- Flow ----
		"flow.new_game":
			_handle_new_game(t)
			flow_machine.transition(FlowStateIds.ONBOARDING_INVOCATION, flow_ctx, logger, t, "ui.flow.new_game")
			
		"flow.advance":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.advance")

		"flow.go_state":
			var to_state := str(action.get("to", ""))
			to_state = _gate_state_for_keeper_intro(to_state)
			if to_state == FlowStateIds.SANCTUM:
				# V2-SANCTUM-001: defeat path — apply emotion modifiers + vow release on RESOLVE→SANCTUM.
				var _from_id: String = str(flow_machine._current_state_id)
				if _from_id == FlowStateIds.RESOLVE or _from_id == FlowStateIds.ENCOUNTER:
					# V2-COMBAT-001: defeat path — null ctx so re-entry initialises a fresh encounter.
					flow_ctx.encounter_ctx     = null
					flow_ctx.encounter_machine = null
					_apply_run_emotion_modifiers("defeat", t)
					_check_vow_release_condition(t)
				else:
					_apply_sanctum_emotion_tick(t)
			elif to_state == FlowStateIds.WEAVING_RITE:
				flow_ctx.selected_weave_thread_id = ""
				flow_ctx.selected_weave_echo_id = ""
				flow_ctx.weave_commit_locked = false
				flow_ctx.weave_resolution = {}
			elif to_state == FlowStateIds.STAGE_EXPLORE:
				# P1-FIX: non-final objective victory returns to stage_explore via go_state.
				# apply post-combat effects here (same as _handle_complete_stage minus advance_stage)
				# before encounter_ctx is cleared by the state exit.
				var _ncv_from: String = str(flow_machine._current_state_id)
				if _ncv_from == FlowStateIds.ENCOUNTER and flow_ctx.encounter_ctx != null:
					var _ncv_victory := bool(flow_ctx.encounter_ctx.combat_result.get("victory", false))
					if _ncv_victory:
						var _ncv_outcome := "win"
						_apply_encounter_emotion_drift(_ncv_outcome, t)
						_apply_combat_bond_triggers(t, _ncv_outcome)
						_apply_bond_aftermath_modifiers(t, _ncv_outcome)
						_seed_rival_stage_incidents(t)
						# Resolve the combat situation in the save (marks objective completed)
						if not flow_ctx.stage_id.is_empty():
							var _ncv_stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
							if not _ncv_stage.is_empty():
								var _ncv_map_v: Variant = _ncv_stage.get("explore_map", {})
								var _ncv_map: Dictionary = _ncv_map_v if _ncv_map_v is Dictionary else {}
								var _ncv_sit_id := str(_ncv_map.get("last_situation_id", ""))
								if not _ncv_sit_id.is_empty():
									var _ncv_sits_v: Variant = _ncv_map.get("situations", [])
									var _ncv_sits: Array = _ncv_sits_v if _ncv_sits_v is Array else []
									for _ncv_i in range(_ncv_sits.size()):
										var _ncv_sv: Variant = _ncv_sits[_ncv_i]
										if _ncv_sv is Dictionary and str((_ncv_sv as Dictionary).get("id", "")) == _ncv_sit_id:
											var _ncv_s: Dictionary = _ncv_sv
											_ncv_s["resolved"] = true
											_ncv_s["revealed"] = true
											_ncv_sits[_ncv_i] = _ncv_s
											if bool(_ncv_s.get("is_objective", false)):
												_ncv_map["objectives_found"] = int(_ncv_map.get("objectives_found", 0)) + 1
												var _ncv_obj_idx := int(_ncv_s.get("objective_index", -1))
												if _ncv_obj_idx >= 0:
													var _ncv_objs_v: Variant = _ncv_stage.get("objectives", [])
													if _ncv_objs_v is Array:
														var _ncv_objs: Array = _ncv_objs_v
														if _ncv_obj_idx < _ncv_objs.size() and _ncv_objs[_ncv_obj_idx] is Dictionary:
															_ncv_objs[_ncv_obj_idx]["completed"] = true
														_ncv_stage["objectives"] = _ncv_objs
											break
									_ncv_map["situations"] = _ncv_sits
									_ncv_stage["explore_map"] = _ncv_map
									FlowStageExploreStateScript._write_stage_back(flow_ctx, _ncv_stage)
									flow_ctx.save_request = true
									flow_ctx.save_request_reason = "stage.combat_resolved" \
										if flow_ctx.save_request_reason.is_empty() \
										else flow_ctx.save_request_reason + "|stage.combat_resolved"
									logger.info(t, "stage.combat_resolved.nonfinal", "Non-final objective resolved on victory", {
										"stage_id": flow_ctx.stage_id, "situation_id": _ncv_sit_id,
									})
						# Vow discovery reads is_dead from ectx.actors — must run before null
						_check_vow_discovery(t)
						flow_ctx.encounter_ctx     = null
						flow_ctx.encounter_machine = null
						flow_ctx.active_encounter_objective_index = -1
				# V2-VOW-002: evaluate vow condition on actual stage entry (covers first entry
				# via "Begin" and re-entry after defeat — both route through go_state→STAGE_EXPLORE).
				_apply_vow_stage_entry_condition(t)
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")

		"flow.select_realm":
			# REALM-001: create/retrieve RealmModel, then go directly to stage map
			var realm_id := str(action.get("realm_id", ""))
			flow_ctx.realm_id = realm_id
			RealmService.get_or_create(realm_id, flow_ctx, t)  # sets save_request internally
			flow_machine.transition(FlowStateIds.STAGE_MAP, flow_ctx, logger, t, "ui.realm_selected")

		"flow.select_stage":
			var stage_id := str(action.get("stage_id", ""))
			flow_ctx.stage_id     = stage_id
			flow_ctx.encounter_id = flow_ctx.realm_id + "." + stage_id  # BUG-003: was always ""
			flow_ctx.active_encounter_objective_index = -1  # V2-STAGE-002: reset on stage entry
			# PROG-009: persist skill loadout to save before entering the stage
			_persist_equipped_skills(t)
			# VOW-001 / V2-VOW-002: vow entry condition evaluated on actual entry (go_state→STAGE_EXPLORE),
			# not here — covers first entry and re-entry after defeat.
			logger.info(t, "state.stage_select", "Stage selected", { "stage_id": stage_id })
			flow_machine.transition(FlowStateIds.STAGE, flow_ctx, logger, t, "ui.flow.select_stage")

		# REALM-004: advance stage index; on realm complete, route to REALM_SELECT.
		# destination override allows cta.continue on victory to route to SANCTUM instead of STAGE_MAP.
		"flow.complete_stage":
			var dest_override := str(action.get("destination", ""))
			_handle_complete_stage(t, dest_override)

		"flow.continue":
			var is_first_boot: bool = bool(flow_ctx.save_data.get("first_boot", true))
			if is_first_boot:
				flow_ctx.save_data["first_boot"] = false
				flow_ctx.save_request = true
				flow_ctx.save_request_reason = "continue_first_boot"

			_apply_offline_accrual_if_needed(t, "flow.continue")
			# V2-SANCTUM-001: time-based emotion recovery catch-up on session continue
			var _cont_unix := int(Time.get_unix_time_from_system())
			_apply_emotion_recovery_if_needed(_cont_unix, t)

			# PROG-001: patch old echo dicts that pre-date draw-order v2 fields
			_repair_echo_schema(t)

			var _continue_cfg := config_service.get_balance()
			var _continue_step := OnboardingService.current_step(flow_ctx.save_data, _continue_cfg)
			if not OnboardingService.is_chapter_one_complete(flow_ctx.save_data) \
					and _continue_step != OnboardingService.STEP_COMPLETE:
				flow_machine.transition(
					OnboardingService.step_to_flow_id(_continue_step),
					flow_ctx,
					logger,
					t,
					"ui.flow.continue.onboarding"
				)
			elif not KeeperIntroServiceScript.is_complete(flow_ctx.save_data):
				var _keeper_step: String = KeeperIntroServiceScript.current_step(flow_ctx.save_data, _continue_cfg)
				if _keeper_step == KeeperIntroServiceScript.STEP_TRIAL and flow_ctx.encounter_ctx == null:
					KeeperIntroServiceScript.ensure_starter_party(flow_ctx.save_data)
					_setup_keeper_intro_trial_encounter(t)
				flow_machine.transition(
					KeeperIntroServiceScript.step_to_flow_id(_keeper_step),
					flow_ctx,
					logger,
					t,
					"ui.flow.continue.keeper_intro"
				)
			else:
				flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")

		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})

		# ---- Chapter I onboarding ----
		"onboarding.advance":
			_handle_onboarding_advance(t)

		"onboarding.fragment.hear":
			_handle_onboarding_fragment_hear(action, t)

		"onboarding.fragment.select":
			_handle_onboarding_fragment_select(action, t)

		"onboarding.fragment.confirm":
			_handle_onboarding_fragment_confirm(t)

		"onboarding.name.confirm":
			_handle_onboarding_name_confirm(action, t)

		# ---- Keeper intro after Chapter I ----
		"keeper_intro.call.answer":
			_handle_keeper_intro_call_answer(t)

		"keeper_intro.trial.finish":
			_handle_keeper_intro_trial_finish(t)

		"keeper_intro.rewind.continue":
			_handle_keeper_intro_rewind_continue(t)

		"keeper_intro.thread.continue":
			_handle_keeper_intro_thread_continue(t)

		"keeper_intro.awakening.choose":
			_handle_keeper_intro_awakening(action, t)

		"keeper_intro.weave.complete":
			_handle_keeper_intro_weave(t)

		"keeper_intro.complete":
			_handle_keeper_intro_complete(t)

		# ---- Debug Seed (SANCTUM-002) ----
		"debug.seed.show":
			_handle_debug_seed_show(t)

		"debug.seed.set":
			_handle_debug_seed_set(action, t, false)

		"debug.seed.reset":
			_handle_debug_seed_set(action, t, true)
			
		# ---- Debug Echo (SANCTUM-002) ----
		"debug.echo.gen_test":
			_handle_debug_echo_gen_test(t)

		# ---- Combat ----
		"combat.init":
			_handle_combat_init(t)

		# COMBAT-004: starts a new round, resolves the first actor, emits a per-actor snapshot.
		"combat.confirm_round":
			_handle_combat_confirm_round(t)

		# COMBAT-SEQ: advances to the next actor in initiative order; emits a per-actor snapshot.
		"combat.next_actor":
			_handle_combat_next_actor(t)

		# ---- Encounter ----
		"encounter.advance":
			var to_state := str(action.get("to", ""))
			if flow_ctx.encounter_machine == null or flow_ctx.encounter_ctx == null:
				logger.debug(t, "ui.encounter.advance", "Encounter not initialized", { "action": action })
			else:
				flow_ctx.encounter_machine.transition(to_state, flow_ctx.encounter_ctx, logger, t, "ui.encounter.advance")
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		# UI-004: player attempts to retreat before combat starts.
		# Roll is seeded for determinism; Ase spent win or lose.
		# Success → Sanctum. Failure → combat starts automatically.
		"encounter.retreat":
			_handle_encounter_retreat(action, t)

		"encounter.complete":
			# EMOTION-002: apply win/loss drift to all roster echoes before clearing encounter
			var enc_outcome := str(action.get("outcome", "loss"))
			_apply_encounter_emotion_drift(enc_outcome, t)
			flow_ctx.encounter_ctx = null
			flow_ctx.encounter_machine = null
			flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.encounter.complete")

		# ---- Economy ----
		"economy.settle_time":
			_handle_economy_settle_time(action, t)
			
		"economy.ase.add":
			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.add"))
			econ.add_ase(amount, reason, logger, t)
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"economy.ase.spend":
			# settle first (same as you do in debug.before_spend)
			var now_unix := int(action.get("now_unix", 0))
			if now_unix > 0:
				_handle_economy_settle_time({ "type":"economy.settle_time", "now_unix": now_unix, "source": "debug.before_spend" }, t)

			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.spend"))
			econ.spend_ase(amount, reason, logger, t)
			# include ok in snapshot? not needed now; debug prints it
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		# ---- Sanctum ----
		"sanctum.name.reroll":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
			var idx := int(sanctum.get("name_roll_index", 0)) + 1
			sanctum["name_roll_index"] = idx

			# No save request on reroll (no save spam)
			logger.debug(t, "sanctum.name.reroll", "Rerolled sanctum name suggestion", {
				"roll_index": idx
			})

			# IMPORTANT: no transition occurs, so we must refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		"sanctum.name.confirm":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary

			var raw := str(action.get("name", ""))
			var name := raw.strip_edges()

			# MVP sanitize rules (deterministic, no OS time)
			if name.length() < 2:
				name = "Sanctum"
			if name.length() > 24:
				name = name.substr(0, 24)

			sanctum["name"] = name

			# Request a save flush (Flow-owned choke point will do it once)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason != "":
				flow_ctx.save_request_reason += "|sanctum.name.confirm"
			else:
				flow_ctx.save_request_reason = "sanctum.name.confirm"

			logger.info(t, "sanctum.name.confirm", "Sanctum name set", {
				"name": name
			})

			# Refresh snapshot so the modal hides (sanctum_name is now set)
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
			
		"sanctum.summon":
			_handle_sanctum_summon(action, t)

		"sanctum.grade_select":
			_handle_sanctum_grade_select(action, t)

		"sanctum.party.toggle":
			_handle_sanctum_party_toggle(action, t)

		"sanctum.unlock_skill":
			_handle_sanctum_unlock_skill(action, t)

		# ---- Weaving Rite (V2-WEAVE-002) ----
		"weave.start_for_echo":
			_handle_weave_start_for_echo(action, t)

		"weave.select_thread":
			if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
				logger.debug(t, "weave.select_thread.ignored", "Selection ignored outside rite state", {})
			else:
				flow_ctx.selected_weave_thread_id = str(action.get("thread_id", ""))
				flow_ctx.weave_resolution = {}
				flow_ctx.weave_commit_locked = false
				flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"weave.begin_rite":
			_handle_weave_begin_rite(t)

		"weave.confirm":
			_handle_weave_confirm(t)

		"weave.enter_rite":
			flow_ctx.selected_weave_echo_id = ""
			flow_ctx.selected_weave_thread_id = ""
			flow_ctx.weave_resolution = {}
			flow_ctx.weave_commit_locked = false
			flow_machine.transition(FlowStateIds.WEAVING_RITE, flow_ctx, logger, t, "ui.weave.enter_rite")

		"weave.pick_echo":
			var echo_id := str(action.get("echo_id", "")).strip_edges()
			if str(flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.WEAVING_RITE and not echo_id.is_empty():
				flow_ctx.selected_weave_echo_id = echo_id
				flow_ctx.selected_weave_thread_id = ""
				flow_ctx.weave_resolution = {}
				flow_ctx.weave_commit_locked = false
				flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		# PROG-004: Keeper-confirmed rank-up from EchoParty.
		"sanctum.rank_up":
			_handle_sanctum_rank_up(action, t)

		# PROG-007: Keeper confirms a calling for an echo (may be deferred after rank-up).
		"sanctum.calling.confirm":
			_handle_sanctum_calling_confirm(action, t)

		# ---- Institutions (V2-SANCTUM-002) ----
		"sanctum.institution.establish":
			_handle_sanctum_institution_establish(action, t)

		"sanctum.institution.assign_echo":
			_handle_sanctum_institution_assign_echo(action, t)

		"sanctum.institution.remove_echo":
			_handle_sanctum_institution_remove_echo(action, t)

		# ---- Vows (VOW-001) ----
		"vow.pledge":
			_handle_vow_pledge(action, t)

		"vow.break":
			_handle_vow_break(t)

		"debug.vow.unlock":
			_handle_debug_vow_unlock(action, t)

		# ---- Directives (DIRECTIVE-001) ----
		"directive.select":
			_handle_directive_select(action, t)

		# ---- Skill Loadout (PROG-009) — assign/unassign while on STAGE_MAP ----
		"skill.assign":
			_handle_skill_assign(action, t)

		"skill.unassign":
			_handle_skill_unassign(action, t)

		# ---- Stage Exploration (V2-STAGE-001) ----
		"stage.advance_turn":
			_handle_stage_advance_turn(action, t)

		"stage.return_home":
			_handle_stage_return_home(action, t)

		"stage.engage_situation":
			_handle_stage_engage_situation(action, t)

		"stage.resolve_situation_choice":  # V2-STAGE-004: player picked a choice overlay option
			_handle_stage_resolve_situation_choice(action, t)

		"stage.ignore_situation":  # V2-STAGE-002: clear pending without resolving
			_handle_stage_ignore_situation(action, t)

		# ---- Stage Exploration V2-STAGE-003: NPC Contact conversation ----
		"stage.consult_echoes":
			_handle_stage_consult_echoes(action, t)

		"stage.speak_response":
			_handle_stage_speak_response(action, t)

		"stage.disengage_contact":
			_handle_stage_disengage_contact(action, t)

		"stage.confirm_return_home":
			flow_machine.transition(FlowStateIds.STAGE_MAP, flow_ctx, logger, t, "stage.return_home.confirmed")

		"stage.dismiss_overlay":
			var _stg := FlowStageExploreStateScript._get_current_stage(flow_ctx)
			if not _stg.is_empty():
				# Rebuild from save_data so overlay data (return_home_result, situation_overlay)
				# is stripped — refresh_snapshot() alone just re-validates the stale snapshot.
				flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		# UI actions
		"ui.dismiss_summon_reveals":
			flow_ctx.pending_summon_reveals.clear()
			logger.debug(t, "ui.dismiss_summon_reveals", "Dismissed summon reveal queue", {
				"remaining": flow_ctx.pending_summon_reveals.size()
			})
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

			# IMPORTANT: no transition occurs, so refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		_:
			logger.debug(t, "ui.action.unknown", "Unknown action type", { "action": action })

	# If we just entered flow.encounter, bootstrap the Encounter machine.
	_ensure_encounter_started(t)

	# Flow-owned save choke point (single save max per dispatch tick)
	if flow_ctx.save_request:
		var reason := str(flow_ctx.save_request_reason)
		var ok := SaveService.save_to_file(
			save_path,
			flow_ctx.save_data,
			logger,
			t
		)

		logger.debug(t, "save.flush", "Save flush executed", {
			"ok": ok,
			"reason": reason
		})

		# A failed flush remains queued and retries at the next dispatch boundary.
		if ok:
			flow_ctx.save_request = false
			flow_ctx.save_request_reason = ""

	# IMPORTANT: Subtask 2 will keep behavior identical:
	# return whatever Flow decided is current
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(t, out, "dispatch")
	return out

# Helper section for the flow actions
func _handle_sanctum_summon(action: Dictionary, t: int) -> void:
	# 0) parse count
	var count := int(action.get("count", 1))
	if count < 1:
		count = 1
	if count > 10:
		count = 10

	# 1) settle before spend
	var now_unix := int(action.get("now_unix", 0))
	if now_unix > 0:
		_handle_economy_settle_time({
			"type": "economy.settle_time",
			"now_unix": now_unix,
			"source": "sanctum.summon.before_spend"
		}, t)

	# 2) read cost (grade-based; fall back to flat key if grade missing)
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	var fallback_flat_cost := int(summ_cfg.get("ase_cost_per_summon", 60))
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}
	var grade := flow_ctx.selected_summon_grade
	var cost_each := int(grade_costs.get(grade, fallback_flat_cost))

	var total_cost := cost_each * count

	# 3) check funds
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_before := int(econ_data.get("ase", 0))

	if ase_before < total_cost:
		logger.info(t, "sanctum.summon.denied", "Not enough Ase to summon", {
			"ase": ase_before,
			"grade": grade,
			"cost_each": cost_each,
			"count": count,
			"total_cost": total_cost
		})
		return

	# 4) spend once
	var spend_reason := "summon.cost." + grade
	var ok_spend: bool = econ.spend_ase(total_cost, spend_reason, logger, t)
	if not ok_spend:
		logger.info(t, "sanctum.summon.denied", "Spend failed", {
			"ase": ase_before,
			"grade": grade,
			"total_cost": total_cost,
			"count": count
		})
		return

	# 5) generate + persist many
	var camp: Dictionary = {}
	if flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]
	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "sanctum.summon.denied", "Missing campaign seed_root", {})
		return

	var expr_v: Variant = data.get("maturity_expression", {})
	var expression_cfg: Dictionary = expr_v if expr_v is Dictionary else {}
	var result := SummonService.summon_paid_many(flow_ctx.save_data, seed_root, summ_cfg, count, logger, t, expression_cfg)

	if bool(result.get("ok", false)):
		# Append newly summoned echoes to transient reveal queue (NOT saved)
		var echoes_v: Variant = result.get("echoes", [])
		var echoes: Array = echoes_v if echoes_v is Array else []
		# PROG-005: extract vector config once for the loop (data dict is already resolved above)
		var vec_cfg_v: Variant = data.get("vectors", {})
		var vec_cfg: Dictionary = vec_cfg_v if vec_cfg_v is Dictionary else {}
		for e_v in echoes:
			if e_v is Dictionary:
				# EMOTION-001: initialise emotion block before the echo enters reveals/roster
				EmotionService.init_echo(e_v, logger, t)
				# PROG-005: initialise vector scores from archetype_init config
				VectorService.init_vectors(e_v, vec_cfg, logger, t)
				# Arrival bark — logged for debug output and telemetry (display-only, no side effects)
				var arch_v   := str(e_v.get("archetype_birth", ""))
				var t_v_bark := e_v.get("traits", {}) as Dictionary
				var tier_v   := ShoutBank.get_tier(
					int(t_v_bark.get("courage", 50)),
					int(t_v_bark.get("wisdom",  50)),
					int(t_v_bark.get("faith",   50))
				)
				var bark := ShoutBank.get_shout("arrival", arch_v, tier_v)
				logger.info(t, "sanctum.summon.bark", bark, {
					"echo_id": str(e_v.get("id", "")),
					"arch":    arch_v,
					"tier":    tier_v,
				})
				flow_ctx.pending_summon_reveals.append(e_v)

		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "sanctum.summon"

		# Rebuild snapshot so SummonScreen immediately reflects the updated Ase balance
		# and the pending_summon_reveals queue (reveal overlay). Without this, the screen
		# stays stale and repeated clicks each trigger a real summon — the root cause of
		# echoes accumulating silently across sessions.
		# Same static build_snapshot() pattern used by _handle_sanctum_grade_select.
		flow_ctx.last_snapshot = FlowSummonState.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _handle_sanctum_grade_select(action: Dictionary, t: int) -> void:
	var grade := str(action.get("grade", "")).strip_edges()
	if grade.is_empty():
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (empty grade)", {})
		return

	# Validate grade against the cost table in balance.json
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}

	if not grade_costs.has(grade):
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (invalid grade key)", {
			"grade": grade,
			"valid_grades": grade_costs.keys()
		})
		return

	flow_ctx.selected_summon_grade = grade

	var ase_cost := int(grade_costs.get(grade, 60))
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_balance := int(econ_data.get("ase", 0))

	logger.debug(t, "economy.summon.grade_select", "Summon grade selected", {
		"grade": grade,
		"ase_cost": ase_cost,
		"can_afford": ase_balance >= ase_cost,
	})

	# Rebuild snapshot mid-state (refresh_snapshot reads ctx.last_snapshot as-is for SUMMON)
	flow_ctx.last_snapshot = FlowSummonState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

# REALM-004: Advance stage index; on realm complete, clear context and route to REALM_SELECT.
# destination_override: when set, non-completed stages route there instead of STAGE_MAP.
# Realm completion always routes to REALM_SELECT regardless of override.
func _handle_complete_stage(t: int, destination_override: String = "") -> void:
	# Fix BUG-003: read outcome BEFORE nulling encounter_ctx so drift reflects the actual result.
	var outcome := "loss"
	var is_combat_victory := false
	if flow_ctx.encounter_ctx != null:
		var victory := bool(flow_ctx.encounter_ctx.combat_result.get("victory", false))
		outcome = "win" if victory else "loss"
		is_combat_victory = victory
	_apply_encounter_emotion_drift(outcome, t)
	# BOND-002: fire stage-level bond triggers + aftermath modifiers BEFORE nulling encounter context.
	_apply_combat_bond_triggers(t, outcome)
	_apply_bond_aftermath_modifiers(t, outcome)
	_seed_rival_stage_incidents(t)
	# V2-VOW-002: decrement pledge cooldown on stage completion (victory only).
	var _cd_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _cd_sanc_v is Dictionary:
		var _cd_sanc: Dictionary = _cd_sanc_v as Dictionary
		var _cd_rem := int(_cd_sanc.get("pledge_cooldown_stages_remaining", 0))
		if _cd_rem > 0:
			_cd_sanc["pledge_cooldown_stages_remaining"] = _cd_rem - 1

	# VOW-001: post-stage complete benefit (obi_nnim_kyere full-scout bonus).
	_apply_vow_stage_complete_benefit(t)

	# On combat victory: resolve the situation that triggered the encounter.
	# engage_situation deliberately left it unresolved so a defeat allows retry.
	if is_combat_victory and not flow_ctx.stage_id.is_empty():
		var _vstage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not _vstage.is_empty():
			var _vmap_v: Variant = _vstage.get("explore_map", {})
			var _vmap: Dictionary = _vmap_v if _vmap_v is Dictionary else {}
			var _vsit_id := str(_vmap.get("last_situation_id", ""))
			if not _vsit_id.is_empty():
				var _vsits_v: Variant = _vmap.get("situations", [])
				var _vsits: Array = _vsits_v if _vsits_v is Array else []
				for _vi in range(_vsits.size()):
					var _vsv: Variant = _vsits[_vi]
					if _vsv is Dictionary and str((_vsv as Dictionary).get("id", "")) == _vsit_id:
						var _vs: Dictionary = _vsv
						_vs["resolved"] = true
						_vs["revealed"] = true
						_vsits[_vi] = _vs
						if bool(_vs.get("is_objective", false)):
							_vmap["objectives_found"] = int(_vmap.get("objectives_found", 0)) + 1
							# V2-STAGE-002: mark the associated objective completed
							var _vobj_idx := int(_vs.get("objective_index", -1))
							if _vobj_idx >= 0:
								var _vstage_objs_v: Variant = _vstage.get("objectives", [])
								if _vstage_objs_v is Array:
									var _vstage_objs: Array = _vstage_objs_v
									if _vobj_idx < _vstage_objs.size() and _vstage_objs[_vobj_idx] is Dictionary:
										_vstage_objs[_vobj_idx]["completed"] = true
									_vstage["objectives"] = _vstage_objs
						break
				_vmap["situations"] = _vsits
				# Check stage completion after resolving
				var _vobj_found := int(_vmap.get("objectives_found", 0))
				var _vobj_total := int(_vmap.get("objectives_total", 0))
				if _vobj_total > 0 and _vobj_found >= _vobj_total:
					_vmap["party_state"] = StageExploreModelScript.STATE_COMPLETE
				_vstage["explore_map"] = _vmap
				FlowStageExploreStateScript._write_stage_back(flow_ctx, _vstage)
				flow_ctx.save_request = true
				if flow_ctx.save_request_reason.is_empty():
					flow_ctx.save_request_reason = "stage.combat_resolved"
				else:
					flow_ctx.save_request_reason += "|stage.combat_resolved"
				logger.info(t, "stage.combat_resolved", "Combat situation resolved on victory", {
					"stage_id":     flow_ctx.stage_id,
					"situation_id": _vsit_id,
					"obj_found":    _vmap.get("objectives_found", 0),
					"obj_total":    _vmap.get("objectives_total", 0),
				})

	# VOW-001: discovery check runs AFTER the combat-victory situation write-back so
	# all_situations_scouted reads the correct revealed state. ectx is still non-null
	# here so _check_vow_discovery can read is_dead from ectx.actors; nulled right after.
	_check_vow_discovery(t)
	flow_ctx.encounter_ctx     = null
	flow_ctx.encounter_machine = null
	flow_ctx.active_encounter_objective_index = -1  # V2-STAGE-002: reset after combat resolves

	# V2-WEAVE-001: load thread config (read-only)
	var _bal_v: Variant = flow_ctx.config_service.get_balance()
	var _bal: Dictionary = _bal_v if _bal_v is Dictionary else {}
	var _bal_data_v: Variant = _bal.get("data", {})
	var _bal_data: Dictionary = _bal_data_v if _bal_data_v is Dictionary else {}
	var _thread_cfg_v: Variant = _bal_data.get("threads", {})
	var _thread_cfg: Dictionary = _thread_cfg_v if _thread_cfg_v is Dictionary else {}

	# V2-WEAVE-001: contribute segment — grade from the final encounter snapshot
	if not _thread_cfg.is_empty() and not flow_ctx.realm_id.is_empty():
		var _snap_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
		var _snap_data: Dictionary = _snap_data_v if _snap_data_v is Dictionary else {}
		var _combat_grade := str(_snap_data.get("rank", "F"))
		RealmService.contribute_segment(flow_ctx, _combat_grade, _thread_cfg, t)

	var result := RealmService.advance_stage(flow_ctx, t)  # sets save_request + logs internally
	if result.get("is_completed", false):
		# V2-WEAVE-001: crystallize Threads before clearing realm context
		flow_ctx.last_realm_threads_earned = []
		if not _thread_cfg.is_empty():
			var _completed_realm_id := flow_ctx.realm_id  # capture BEFORE clearing
			flow_ctx.last_realm_threads_earned = ThreadService.crystallize_threads(
				_completed_realm_id, flow_ctx.save_data, _thread_cfg, t, flow_ctx.logger
			)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason.is_empty():
				flow_ctx.save_request_reason = "thread.crystallize"
			else:
				flow_ctx.save_request_reason += "|thread.crystallize"

		# Clear stale context so re-entry into a new realm starts clean
		flow_ctx.realm_id = ""
		flow_ctx.stage_id = ""
		flow_machine.transition(FlowStateIds.REALM_SELECT, flow_ctx, logger, t, "realm.complete")
	else:
		var dest: String = destination_override if destination_override != "" else FlowStateIds.STAGE_MAP
		# V2-SANCTUM-001: victory — apply emotion modifiers + vow release when routing back to Sanctum
		if dest == FlowStateIds.SANCTUM:
			_apply_run_emotion_modifiers("victory", t)
			_check_vow_release_condition(t)
		flow_machine.transition(dest, flow_ctx, logger, t, "realm.stage_complete")


func _handle_new_game(t: int) -> void:
	# Create a new campaign root seed string (random once; then persisted)
	var seed_root := _generate_seed_root_string()
	var legacy_root_seed := _legacy_root_seed_from_seed_root(seed_root)

	# Replace current save with a fresh one
	var save := SaveService.make_new_save(legacy_root_seed)

	# Canonical campaign seed fields (SANCTUM-002)
	if not save.has("campaign") or typeof(save["campaign"]) != TYPE_DICTIONARY:
		save["campaign"] = {}
	var camp: Dictionary = save["campaign"]
	camp["seed_root"] = seed_root
	camp["seed_source"] = "random"

	# This is a brand-new run (menu first boot should not persist)
	save["first_boot"] = false
	var balance := config_service.get_balance()
	OnboardingService.ensure_onboarding(save, balance)
	SanctumLayoutService.ensure_layout(save)

	# Install save into runtime + rebuild economy service
	flow_ctx.save_data = save

	# REALM-001: populate campaign_seed from the newly generated save
	flow_ctx.campaign_seed = CampaignSeed.new(legacy_root_seed)
	# New game always starts with no active realm
	flow_ctx.realm_id = ""

	econ = EconomyService.new(flow_ctx.save_data)
	directive_service = DirectiveService.new(flow_ctx.save_data)  # DIRECTIVE-001
	directive_service.load_from_config(config_service.get_balance())  # V2-STAGE-004-P2: wire traversal fields

	# Request save flush via Flow-owned choke point
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|flow.new_game"
	else:
		flow_ctx.save_request_reason = "flow.new_game"

	# IMPORTANT: no transition has occurred yet when this runs, so refresh snapshot after mutation
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _handle_onboarding_advance(t: int) -> void:
	var cfg := config_service.get_balance()
	var step := OnboardingService.current_step(flow_ctx.save_data, cfg)
	var next := OnboardingService.next_step(step)
	if next == OnboardingService.STEP_COMPLETE:
		return

	OnboardingService.set_step(flow_ctx.save_data, cfg, next)
	_mark_save_requested("onboarding.advance")
	flow_machine.transition(OnboardingService.step_to_flow_id(next), flow_ctx, logger, t, "ui.onboarding.advance")

func _handle_onboarding_fragment_hear(action: Dictionary, t: int) -> void:
	var cfg := config_service.get_balance()
	var virtue := str(action.get("virtue", "")).strip_edges().to_lower()
	OnboardingService.mark_heard(flow_ctx.save_data, cfg, virtue)
	_mark_save_requested("onboarding.fragment.hear")
	_rebuild_current_onboarding_snapshot(t)

func _handle_onboarding_fragment_select(action: Dictionary, t: int) -> void:
	var cfg := config_service.get_balance()
	var virtue := str(action.get("virtue", "")).strip_edges().to_lower()
	OnboardingService.mark_heard(flow_ctx.save_data, cfg, virtue)
	OnboardingService.select_fragment(flow_ctx.save_data, cfg, virtue)
	_mark_save_requested("onboarding.fragment.select")
	_rebuild_current_onboarding_snapshot(t)

func _handle_onboarding_fragment_confirm(t: int) -> void:
	var cfg := config_service.get_balance()
	var selected := OnboardingService.selected_fragment(flow_ctx.save_data, cfg)
	if selected.is_empty():
		logger.debug(t, "onboarding.fragment.confirm.denied", "No fragment selected", {})
		_rebuild_current_onboarding_snapshot(t)
		return

	_grant_starter_echo_for_fragment(selected, t)
	OnboardingService.set_step(flow_ctx.save_data, cfg, OnboardingService.STEP_MEETING)
	_mark_save_requested("onboarding.fragment.confirm")
	flow_machine.transition(FlowStateIds.ONBOARDING_MEETING, flow_ctx, logger, t, "ui.onboarding.fragment.confirm")

func _handle_onboarding_name_confirm(action: Dictionary, t: int) -> void:
	var cfg := config_service.get_balance()
	var raw := str(action.get("name", "")).strip_edges()
	var name := raw
	if name.length() < 2:
		var options_v: Variant = OnboardingService.ensure_onboarding(flow_ctx.save_data, cfg).get("name_options", [])
		var options: Array = options_v if options_v is Array else []
		if not options.is_empty() and options[0] is Dictionary:
			name = str((options[0] as Dictionary).get("name", "Sanctum"))
		else:
			name = "Sanctum"
	if name.length() > 24:
		name = name.substr(0, 24)

	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	var sanctum: Dictionary = flow_ctx.save_data["sanctum"]
	sanctum["name"] = name
	OnboardingService.mark_complete(flow_ctx.save_data, cfg)
	KeeperIntroServiceScript.start_after_chapter_one(flow_ctx.save_data, cfg)

	# V2-ECONOMY-001: Ase Flame awakening — set flag only (Ase granted on trial completion, not here)
	var _aw_flame_v: Variant = sanctum.get("ase_flame", {})
	var _aw_flame: Dictionary = _aw_flame_v if _aw_flame_v is Dictionary else {}
	if not bool(_aw_flame.get("awakened", false)):
		_aw_flame["awakened"] = true
		sanctum["ase_flame"] = _aw_flame
		logger.info(t, "economy.ase_flame.awakened", "Ase Flame awakened", {})

	_mark_save_requested("onboarding.name.confirm")

	logger.info(t, "onboarding.name.confirm", "Chapter I complete; Sanctum name set", {
		"name": name
	})

	flow_machine.transition(FlowStateIds.KEEPER_CALL, flow_ctx, logger, t, "ui.onboarding.name.confirm")

func _gate_state_for_keeper_intro(to_state: String) -> String:
	if to_state in [
		FlowStateIds.SANCTUM,
		FlowStateIds.SUMMON,
		FlowStateIds.ECHO_PARTY,
		FlowStateIds.REALM_SELECT,
		FlowStateIds.VOW_MANAGE,
		FlowStateIds.WEAVING_RITE,
	]:
		var cfg := config_service.get_balance()
		if OnboardingService.is_chapter_one_complete(flow_ctx.save_data) \
				and not KeeperIntroServiceScript.is_complete(flow_ctx.save_data):
			var step: String = KeeperIntroServiceScript.current_step(flow_ctx.save_data, cfg)
			if step == KeeperIntroServiceScript.STEP_TRIAL and flow_ctx.encounter_ctx == null:
				KeeperIntroServiceScript.ensure_starter_party(flow_ctx.save_data)
				_setup_keeper_intro_trial_encounter(flow_ctx.sim_tick)
			return KeeperIntroServiceScript.step_to_flow_id(step)
	return to_state


func _handle_keeper_intro_call_answer(t: int) -> void:
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.ensure_starter_party(flow_ctx.save_data)
	_setup_keeper_intro_trial_encounter(t)
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_TRIAL)
	var onboarding: Dictionary = flow_ctx.save_data.get("onboarding", {})
	onboarding["keeper_trial_phase"] = KeeperIntroServiceScript.TRIAL_READY
	_mark_save_requested("keeper_intro.call.answer")
	flow_machine.transition(FlowStateIds.KEEPER_TRIAL, flow_ctx, logger, t, "keeper_intro.call.answer")


func _setup_keeper_intro_trial_encounter(t: int) -> void:
	var echo := OnboardingService.get_starter_echo(flow_ctx.save_data)
	if echo.is_empty():
		return
	var balance := config_service.get_balance()
	var bd: Dictionary = balance.get("data", {})
	var actor_cfg := {
		"birth_stats": bd.get("summoning", {}).get("birth_stats", {}),
		"enemy_types": bd.get("actor", {}).get("enemy_types", {}),
	}
	var echo_actor := EchoActor.from_echo(echo)
	echo_actor["grid_pos"] = { "col": 0, "row": 2 }
	var onboarding_v: Variant = flow_ctx.save_data.get("onboarding", {})
	var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
	var rewind_used := bool(onboarding.get("keeper_trial_rewind_used", false))
	echo_actor["_bark_line"] = "The wound knows us. I can still stand." if not rewind_used else "Again, then. I remember the edge."
	echo_actor["_bark_context"] = "combat_taunt"
	echo_actor["_bark_tier"] = "nascent"
	var wound := EnemyActor.from_definition({
		"id": "fragment_wound",
		"name": "Fragment Wound",
		"type": "fragment_wound",
		"level": 1,
		"faction": "enemy",
	}, t, actor_cfg)
	wound["grid_pos"] = { "col": 4, "row": 2 }
	wound["stats"]["max_hp"] = 18 if rewind_used else 28
	wound["stats"]["atk"] = 10 if rewind_used else 18
	wound["stats"]["def"] = 0 if rewind_used else 1
	wound["stats"]["agi"] = 2
	wound["current_hp"] = int(wound["stats"]["max_hp"])
	wound["speed"] = 2
	flow_ctx.encounter_ctx = EncounterContext.new()
	flow_ctx.encounter_ctx.encounter_id = "keeper_intro.first_trial"
	flow_ctx.encounter_ctx.resolution_mode = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx.actors = [echo_actor, wound]
	flow_ctx.encounter_ctx.placement_seed = 0
	flow_ctx.encounter_machine = EncounterStateMachine.new()
	flow_ctx.encounter_machine.register_default_states()
	var combat_cfg: Dictionary = bd.get("combat", {})
	flow_ctx.encounter_ctx.initiative_cfg = combat_cfg.get("initiative_modifiers", {})
	flow_ctx.encounter_id = "keeper_intro.first_trial"
	flow_ctx.stage_id = ""
	flow_ctx.realm_id = ""


func _is_keeper_intro_trial_active() -> bool:
	return flow_ctx.encounter_ctx != null and flow_ctx.encounter_ctx.encounter_id == "keeper_intro.first_trial"


func _keeper_intro_trial_lethal_echo_ids() -> Array[String]:
	var lethal_ids: Array[String] = []
	if not _is_keeper_intro_trial_active():
		return lethal_ids
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) != "echo":
			continue
		if int(actor.get("current_hp", 1)) <= 0 or bool(actor.get("is_dead", false)):
			lethal_ids.append(str(actor.get("id", "")))
	return lethal_ids


func _keeper_intro_trial_enemy_defeated() -> bool:
	if not _is_keeper_intro_trial_active():
		return false
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) == "enemy" and bool(actor.get("is_dead", false)):
			return true
	return false


func _keeper_intro_restore_echo_after_second_attempt(t: int, lethal_ids: Array[String]) -> void:
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("id", "")) in lethal_ids:
			actor["current_hp"] = 1
			actor["is_dead"] = false
			actor["death_round"] = 0
			actor["_bark_line"] = "Still here. Finish it."
			actor["_bark_context"] = "combat_resilient"
			actor["_bark_tier"] = "nascent"
	logger.info(t, "keeper_intro.trial.second_attempt.protected", "Second attempt Echo KO prevented without granting rewards", {
		"lethal_echo_ids": lethal_ids,
	})


func _handle_keeper_intro_trial_rewind(t: int, lethal_ids: Array[String]) -> void:
	var cfg := config_service.get_balance()
	var onboarding: Dictionary = KeeperIntroServiceScript.ensure_intro(flow_ctx.save_data, cfg)
	onboarding["keeper_trial_rewind_used"] = true
	onboarding["keeper_trial_phase"] = "rewind"
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_REWIND)
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.encounter_id = ""
	_mark_save_requested("keeper_intro.trial.rewind")
	logger.info(t, "keeper_intro.trial.rewind", "Anansi rewinds the first trial", {
		"lethal_echo_ids": lethal_ids,
	})
	flow_machine.transition(FlowStateIds.KEEPER_REWIND, flow_ctx, logger, t, "keeper_intro.trial.rewind")


func _handle_keeper_intro_rewind_continue(t: int) -> void:
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.ensure_starter_party(flow_ctx.save_data)
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_TRIAL)
	var onboarding: Dictionary = KeeperIntroServiceScript.ensure_intro(flow_ctx.save_data, cfg)
	onboarding["keeper_trial_phase"] = KeeperIntroServiceScript.TRIAL_READY
	_setup_keeper_intro_trial_encounter(t)
	_mark_save_requested("keeper_intro.rewind.continue")
	flow_machine.transition(FlowStateIds.KEEPER_TRIAL, flow_ctx, logger, t, "keeper_intro.rewind.continue")


func _handle_keeper_intro_trial_finish(t: int) -> void:
	if _is_keeper_intro_trial_active() and not _keeper_intro_trial_enemy_defeated():
		logger.info(t, "keeper_intro.trial.finish.blocked", "First trial rewards blocked until the Fragment Wound is defeated", {})
		flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.grant_trial_rewards(flow_ctx.save_data, cfg, econ, logger, t)
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.encounter_id = ""
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_THREAD_RETURN)
	_mark_save_requested("keeper_intro.trial.finish")
	flow_machine.transition(FlowStateIds.KEEPER_THREAD_RETURN, flow_ctx, logger, t, "keeper_intro.trial.finish")


func _handle_keeper_intro_thread_continue(t: int) -> void:
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_AWAKENING)
	_mark_save_requested("keeper_intro.thread.continue")
	flow_machine.transition(FlowStateIds.KEEPER_AWAKENING, flow_ctx, logger, t, "keeper_intro.thread.continue")


func _handle_keeper_intro_awakening(action: Dictionary, t: int) -> void:
	var cfg := config_service.get_balance()
	var choice := str(action.get("choice", "")).strip_edges()
	KeeperIntroServiceScript.awaken_flame(flow_ctx.save_data, cfg, choice, logger, t)
	var econ_data_v: Variant = flow_ctx.save_data.get("economy", {})
	if econ_data_v is Dictionary:
		var econ_data: Dictionary = econ_data_v
		econ_data["last_settle_unix"] = int(Time.get_unix_time_from_system())
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_WEAVING)
	_mark_save_requested("keeper_intro.awakening")
	flow_machine.transition(FlowStateIds.KEEPER_WEAVING, flow_ctx, logger, t, "keeper_intro.awakening")


func _handle_keeper_intro_weave(t: int) -> void:
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.apply_first_weave(flow_ctx.save_data, cfg, logger, t)
	KeeperIntroServiceScript.set_step(flow_ctx.save_data, cfg, KeeperIntroServiceScript.STEP_KEEPING)
	_mark_save_requested("keeper_intro.weave")
	flow_machine.transition(FlowStateIds.KEEPER_KEEPING, flow_ctx, logger, t, "keeper_intro.weave")


func _handle_keeper_intro_complete(t: int) -> void:
	var cfg := config_service.get_balance()
	KeeperIntroServiceScript.mark_complete(flow_ctx.save_data, cfg)
	_mark_save_requested("keeper_intro.complete")
	_apply_sanctum_emotion_tick(t)
	flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "keeper_intro.complete")

func _grant_starter_echo_for_fragment(fragment: Dictionary, t: int) -> void:
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	var sanctum: Dictionary = flow_ctx.save_data["sanctum"]
	if not sanctum.has("roster") or not (sanctum["roster"] is Array):
		sanctum["roster"] = []
	var roster: Array = sanctum["roster"]
	if bool(sanctum.get("starter_granted", false)) and not roster.is_empty():
		return

	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}
	var expr_v: Variant = data.get("maturity_expression", {})
	var expression_cfg: Dictionary = expr_v if expr_v is Dictionary else {}
	var vec_cfg_v: Variant = data.get("vectors", {})
	var vec_cfg: Dictionary = vec_cfg_v if vec_cfg_v is Dictionary else {}

	var camp_v: Variant = flow_ctx.save_data.get("campaign", {})
	var camp: Dictionary = camp_v if camp_v is Dictionary else {}
	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	var seed_path := "campaign.starter.0"
	var echo := EchoFactory.generate(seed_root, seed_path, 0, "starter", summ_cfg, expression_cfg)

	var selected_virtue := str(fragment.get("virtue", ""))
	var selected_vector := str(fragment.get("vector", ""))
	if selected_vector.is_empty():
		selected_vector = OnboardingService.vector_for_virtue(balance, selected_virtue)
	if not selected_vector.is_empty():
		echo["class_origin"] = selected_vector
	var gen_ctx_v: Variant = echo.get("generation_context", {})
	var gen_ctx: Dictionary = gen_ctx_v if gen_ctx_v is Dictionary else {}
	var mods_v: Variant = gen_ctx.get("modifiers", {})
	var mods: Dictionary = mods_v if mods_v is Dictionary else {}
	mods["starter_virtue"] = selected_virtue
	mods["starter_vector"] = selected_vector
	gen_ctx["modifiers"] = mods
	echo["generation_context"] = gen_ctx

	var echo_id := "echo_%04d" % (roster.size() + 1)
	echo["id"] = echo_id
	EmotionService.init_echo(echo, logger, t)
	VectorService.init_vectors(echo, vec_cfg, logger, t)
	roster.append(echo)
	sanctum["starter_granted"] = true
	SanctumLayoutService.ensure_starter_occupant(flow_ctx.save_data)

	logger.info(t, "onboarding.starter.grant", "Starter Echo granted from Chapter I fragment", {
		"echo_id": echo_id,
		"seed_path": seed_path,
		"virtue": selected_virtue,
		"vector": selected_vector,
	})

func _rebuild_current_onboarding_snapshot(t: int) -> void:
	var cfg := config_service.get_balance()
	var step := OnboardingService.current_step(flow_ctx.save_data, cfg)
	var flow_id := OnboardingService.step_to_flow_id(step)
	flow_ctx.last_snapshot = FlowOnboardingState.build_snapshot(flow_ctx, t, step, flow_id)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _mark_save_requested(reason: String) -> void:
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|" + reason
	else:
		flow_ctx.save_request_reason = reason


# Helpers
func _handle_debug_seed_show(t: int) -> void:
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", ""))
	var seed_source := str(camp.get("seed_source", ""))
	var root_seed := int(camp.get("root_seed", 0))

	logger.info(t, "debug.seed.show", "Seed show", {
		"seed_root": seed_root,
		"seed_source": seed_source,
		"root_seed": root_seed
	})

	# Refresh is optional, but harmless and keeps UI consistent if you display seed-derived hints.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_debug_seed_set(action: Dictionary, t: int, do_reset: bool) -> void:
	var seed_root := str(action.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.seed.denied", "Denied seed set/reset (empty seed_root)", {})
		return

	# Ensure campaign dict exists
	if not flow_ctx.save_data.has("campaign") or typeof(flow_ctx.save_data["campaign"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]

	# Update canonical seed fields
	camp["seed_root"] = seed_root
	camp["seed_source"] = "debug"

	# Keep legacy root_seed in sync for current systems (e.g., sanctum name suggestion)
	camp["root_seed"] = _legacy_root_seed_from_seed_root(seed_root)

	# Reset sanctum data if requested
	if do_reset:
		if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
			flow_ctx.save_data["sanctum"] = {}
		var sanctum: Dictionary = flow_ctx.save_data["sanctum"]

		# Reset everything test-relevant
		sanctum["name"] = ""
		sanctum["name_roll_index"] = 0
		sanctum["roster"] = []
		sanctum["active_party_ids"] = []
		sanctum["summon_count"] = 0
		sanctum["starter_granted"] = false

		logger.info(t, "debug.seed.reset", "Seed reset applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})
	else:
		logger.info(t, "debug.seed.set", "Seed set applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})

	# Save once via Flow-owned choke point
	flow_ctx.save_request = true
	var reason := "debug.seed.reset" if do_reset else "debug.seed.set"
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|" + reason
	else:
		flow_ctx.save_request_reason = reason

	# IMPORTANT: no flow transition occurs, so refresh snapshot immediately
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

## UI-004: Player attempts retreat before round 1.
## Gate (speed) and tier (agi) were computed at snapshot time and baked into the action dict.
## Ase is spent regardless of roll outcome.
## Success → clear encounter, go to Sanctum. Failure → start combat immediately.
func _handle_encounter_retreat(action: Dictionary, t: int) -> void:
	if flow_ctx.encounter_ctx == null:
		logger.debug(t, "encounter.retreat.no_op", "Retreat: no active encounter context", {})
		return

	var ase_cost:    int = int(action.get("ase_cost",    0))
	var success_pct: int = int(action.get("success_pct", 0))
	var encounter_id: String = flow_ctx.encounter_ctx.encounter_id

	# Spend Ase (always, win or lose). Guard: only spend if player can afford.
	if ase_cost > 0:
		if econ.can_afford_ase(ase_cost):
			econ.spend_ase(ase_cost, "encounter.retreat", logger, t)
		else:
			logger.debug(t, "encounter.retreat.no_ase", "Retreat: insufficient Ase — no spend", {
				"ase_cost": ase_cost, "ase_balance": econ.get_ase()
			})

	# Seeded roll for determinism.
	var rng := RandomNumberGenerator.new()
	if flow_ctx.campaign_seed != null:
		rng = flow_ctx.campaign_seed.get_rng("encounter.retreat." + encounter_id + "." + str(t))
	else:
		rng.seed = hash("encounter.retreat." + encounter_id + str(t))

	var roll_result: Dictionary = RetreatService.roll_retreat(success_pct, rng)
	var success: bool = bool(roll_result.get("success", false))

	logger.info(t, "encounter.retreat", "Retreat attempted", {
		"encounter_id": encounter_id,
		"ase_cost":     ase_cost,
		"success_pct":  success_pct,
		"success":      success,
	})

	if success:
		# V2-ECONOMY-001: Intel-gated partial Ase award before clearing encounter context.
		var _intel_count := _count_revealed_situations()
		var _partial_ase := 0
		if _intel_count > 0:
			var _pf := float(_get_balance_rewards_cfg().get("partial_intel_reward_factor", 0.12))
			_partial_ase = roundi(float(_get_stage_base_reward()) * _pf)
			if _partial_ase > 0:
				econ.add_ase(_partial_ase, "retreat_intel_partial", logger, t)
		flow_ctx.pending_scout_return_ase         = _partial_ase
		flow_ctx.pending_scout_return_intel_count = _intel_count

		# Clear encounter context — no emotion drift on retreat.
		flow_ctx.encounter_ctx    = null
		flow_ctx.encounter_machine = null
		flow_ctx.save_request      = true
		flow_ctx.save_request_reason = "encounter.retreat"
		# V2-SANCTUM-001: withdrawal — apply emotion modifiers + vow release before resolve.
		_apply_run_emotion_modifiers("withdrawal", t)
		_check_vow_release_condition(t)
		flow_ctx.last_snapshot = _build_scout_return_snapshot(t)
		flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "encounter.retreat.scout_return")
	else:
		logger.info(t, "encounter.retreat.failed", "Retreat failed — combat begins", {
			"encounter_id": encounter_id,
		})
		# Start combat immediately.
		_handle_combat_init(t)


## COMBAT-001: initializes CombatState, logs combat.init, saves, and rebuilds snapshot.
func _handle_combat_init(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_machine == null:
		logger.debug(t, "combat.init.no_op", "combat.init with no encounter context", {})
		return

	# If machine hasn't been started yet (edge case), start it first.
	if flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		flow_ctx.encounter_machine.start(flow_ctx.encounter_ctx, logger, t)

	# Transition to ROUNDS — EncounterRoundsState.enter() creates CombatState on ectx.
	flow_ctx.encounter_machine.transition(
		EncounterStateIds.ROUNDS, flow_ctx.encounter_ctx, logger, t, "combat.init")

	# Log after EncounterRoundsState.enter() has set combat_state.
	var cs: Dictionary = flow_ctx.encounter_ctx.combat_state
	logger.info(t, "combat.init", "Combat state initialized", {
		"actor_count":   cs.get("actors", []).size(),
		"objective":     cs.get("objective", ""),
		"round_counter": int(cs.get("round_counter", 0)),
	})
	# COMBAT-002: log round_start with full initiative order for determinism audit.
	var order: Array = cs.get("initiative_order", [])
	logger.info(t, "combat.round_start", "Round 0 initiative set", {
		"round_counter":    int(cs.get("round_counter", 0)),
		"actor_count":      order.size(),
		"initiative_order": order,
	})

	# Save checkpoint on combat start.
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "combat.init"

	# Rebuild flow.encounter snapshot with combat state included.
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: starts a new round, clears round-scoped state, resolves the first living actor,
## and emits a per-actor snapshot. Subsequent actors are driven by combat.next_actor.
func _handle_combat_confirm_round(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_ctx.combat_state.is_empty():
		logger.debug(t, "combat.confirm_round.no_op", "Confirm round: no active combat state", {})
		return

	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state

	# Guard: combat already over — ignore stale presses.
	if bool(combat_state.get("combat_over", false)):
		return

	# 1. Log round_start before incrementing.
	var prev_round: int = int(combat_state.get("round_counter", 0))
	logger.info(t, "combat.round_start", "Round starting", { "round": prev_round + 1 })

	# 2. Clear round-scoped state on all actors (guard_state is runtime-only — not persisted).
	for actor_v in ectx.actors:
		if actor_v is Dictionary:
			actor_v["guard_state"] = false
	ectx.last_round_results = []
	ectx.last_actor_action  = {}
	ectx.round_bark_events  = []  # V2-VOICE-001: reset reactive bark queue each round

	# 3. Advance round counter, reset actor pointer, mark round active.
	combat_state["round_counter"]        = prev_round + 1
	combat_state["current_actor_index"]  = 0
	combat_state["round_phase"]          = "in_round"

	# 4. Resolve the first actor (emits snapshot with cta.next_actor).
	_resolve_next_actor(t)


## COMBAT-SEQ: advances one step in the current round — resolves the next living actor
## and emits a per-actor snapshot.
func _handle_combat_next_actor(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_ctx.combat_state.is_empty():
		return
	if bool(flow_ctx.encounter_ctx.combat_state.get("combat_over", false)):
		return
	_resolve_next_actor(t)


## COMBAT-SEQ: finds the next living actor from current_actor_index, resolves their turn,
## appends the result to last_round_results, emits a per-actor snapshot.
## If no living actor remains, calls _end_round() instead.
func _resolve_next_actor(t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state

	# Find the next living actor starting at current_actor_index.
	var next_idx: int = _find_next_living_actor_idx(ectx)
	if next_idx == -1:
		_end_round(t)
		return

	# Advance pointers — current_actor_index advances PAST this actor after resolution.
	combat_state["active_initiative_index"] = next_idx

	var order: Array = combat_state.get("initiative_order", [])
	var actor_id: String = str(order[next_idx].get("id", ""))
	var actor: Dictionary = _find_actor_by_id(ectx.actors, actor_id)

	# Read config blocks.
	var balance: Dictionary = config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var leadership_expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var grid_cfg: Dictionary = bdata.get("grid", {})
	var actor_cfg: Dictionary = bdata.get("actor", {})
	var prog_cfg_block: Dictionary    = bdata.get("progression", {})
	var birth_stats_block: Dictionary = bdata.get("summoning", {}).get("birth_stats", {})
	var round: int = int(combat_state.get("round_counter", 0))

	# COMBAT-006: find shrine and compute context fields for purify_shrine objective.
	var shrine_alive: bool    = false
	var shrine_hp_ratio: float = 1.0
	if ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				shrine_alive = true
				var s_max: int = int(a_v.get("stats", {}).get("max_hp", 0))
				if s_max > 0:
					shrine_hp_ratio = clampf(float(a_v.get("current_hp", s_max)) / float(s_max), 0.0, 1.0)
				break

	# VOW-001: pass active vow into per-turn context so BehaviorArbiter can apply vow bias.
	var _vow_ctx := VowService.get_active_vow(flow_ctx.save_data)

	# BOND-002: pass social graph into per-turn context for bond-aware behavior bias.
	var _bond_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _bond_sanctum: Dictionary = _bond_sanctum_v if _bond_sanctum_v is Dictionary else {}
	var _bonds_for_ctx: Array = _bond_sanctum.get("bonds", []) as Array

	# V2-STAGE-004 P3a: thread terrain walkable set + board dims into movement board_cfg.
	# Only when encounter_ctx.terrain is non-empty (i.e. irregular terrain was generated).
	# Absent terrain → board_cfg is the raw grid_cfg → legacy 10×10 behaviour unchanged.
	var movement_board_cfg: Dictionary = grid_cfg
	if ectx != null and not ectx.terrain.is_empty():
		var _mv_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain)
		var _mv_bounds: Dictionary   = ectx.terrain.get("bounds", {})
		movement_board_cfg = grid_cfg.duplicate(true)
		movement_board_cfg["walkable"]   = _mv_walkable
		if _mv_bounds.has("w"):
			movement_board_cfg["board_cols"] = int(_mv_bounds["w"])
		if _mv_bounds.has("h"):
			movement_board_cfg["board_rows"] = int(_mv_bounds["h"])

	# Build per-turn context — matches ActorStateMachine.advance_turn() contract.
	var ctx: Dictionary = {
		"actor":                   actor,
		"all_actors":              ectx.actors,
		"board_cfg":               movement_board_cfg,
		"cfg":                     balance,
		"t":                       t,
		"round":                   round,
		# COMBAT-006: shrine context fields for BehaviorArbiter + MeleeBehaviorModule.
		"purifier_id":             ectx.purifier_id,
		"is_purifier":             str(actor.get("id", "")) == ectx.purifier_id,
		"shrine_alive":            shrine_alive,
		"shrine_hp_ratio":         shrine_hp_ratio,
		"prefer_objective_target": actor.get("faction", "") == "enemy" \
			and (ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE \
				or ectx.resolution_mode == EncounterResolutionModes.PROTECT \
				or ectx.resolution_mode == EncounterResolutionModes.RECOVER),
		# VOW-001: active vow dict (or {}) for BehaviorArbiter vow bias layer.
		"active_vow":              _vow_ctx,
		# VOW-001: echo party size for tikoro_nko_agyina party-size gate.
		"party_size":              ectx.actors.filter(func(a): return str(a.get("faction","")) == "echo" and not bool(a.get("is_dead", false))).size(),
		# BOND-002: social graph for bond-aware behavior bias (BehaviorArbiter._apply_bond_bias).
		"bonds":                   _bonds_for_ctx,
		"bond_thresholds":         _get_bond_thresholds_cfg(),
		"bond_behavior_cfg":       _get_bond_behavior_cfg(),
		# V2-VOICE-001: reactive bark queue — read-only; actors read this to fire rally_ally barks.
		"round_bark_events":       ectx.round_bark_events,
		"directive":               {} if _is_keeper_intro_trial_active() else (directive_service.get_active_directive() if directive_service != null else {}),
		# V2-STAGE-004 Distinctiveness: mode identity + PROTECT theft context for BehaviorArbiter.
		"resolution_mode":         str(ectx.resolution_mode),
		"totem_stolen":            bool(ectx.combat_state.get("totem_stolen", false)),
		"totem_carrier_id":        str(ectx.combat_state.get("totem_carrier_id", "")),
	}

	# V2-STAGE-004 Distinctiveness §4-C: mode directive injection.
	# Merge mode-specific directive_intent_weights into a COPY of the player directive —
	# never mutate the shared player directive dict.
	# Gate: skip during keeper-intro trial (mirrors the existing keeper-intro guard above).
	if not _is_keeper_intro_trial_active():
		var _mode_dw_src: Dictionary = {}
		var _di_mode: String = str(ectx.resolution_mode)
		var _di_bdata: Dictionary = config_service.get_balance().get("data", {})
		var _di_modes_cfg: Dictionary = _di_bdata.get("combat", {}).get("objective_modes", {})
		var _di_mode_cfg: Dictionary = _di_modes_cfg.get(_di_mode, {})
		var _di_raw_dw: Variant = _di_mode_cfg.get("directive_intent_weights", {})
		if _di_raw_dw is Dictionary and not (_di_raw_dw as Dictionary).is_empty():
			# Determine whether this actor is eligible for mode directive injection.
			var _di_apply: bool = false
			match _di_mode:
				EncounterResolutionModes.RECOVER:
					# Only the designated holder receives mode directive weights.
					_di_apply = str(actor.get("id", "")) == str(ectx.combat_state.get("recover_holder_id", "")) \
						and str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false))
				EncounterResolutionModes.PROTECT:
					# All living echoes receive mode directive (interpose bias).
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false))
				EncounterResolutionModes.PURIFY_SHRINE:
					# All NON-purifier echoes receive mode directive.
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false)) \
						and not bool(ctx.get("is_purifier", false))
				_:
					_di_apply = false  # ENDURE / COMBAT: no mode directive.
			if _di_apply:
				_mode_dw_src = _di_raw_dw as Dictionary
		if not _mode_dw_src.is_empty():
			# Duplicate the player directive to avoid mutating the shared object.
			var _base_dir: Dictionary = ctx.get("directive", {})
			var _dir_copy: Dictionary = _base_dir.duplicate(true)
			if not _dir_copy.has("intent_weights"):
				_dir_copy["intent_weights"] = {}
			var _iw_copy: Dictionary = (_dir_copy["intent_weights"] as Dictionary).duplicate(true)
			for _dw_key in _mode_dw_src:
				_iw_copy[_dw_key] = float(_iw_copy.get(_dw_key, 0.0)) + float(_mode_dw_src[_dw_key])
			_dir_copy["intent_weights"] = _iw_copy
			ctx["directive"] = _dir_copy

	# Resolve this actor's turn.
	var asm := ActorStateMachine.new(actor, null, actor_cfg)
	var intent: Dictionary = asm.advance_turn(ctx, logger, t)
	var action_type: String = intent.get("action_type", "actor.idle")

	# V2-VOICE-001: after advance_turn, if actor produced a high-signal bark, append to round queue.
	# Reactive barks in subsequent actors' turns read this queue via ctx["round_bark_events"].
	var _bark_ctx_post: String = str(actor.get("_bark_context", ""))
	if not _bark_ctx_post.is_empty() and _bark_ctx_post in [
		"combat_last_stand", "combat_fear_extreme", "combat_resilient", "combat_taunt", "combat_ko"
	]:
		ectx.round_bark_events.append({
			"actor_id":    str(actor.get("id", "")),
			"faction":     str(actor.get("faction", "")),
			"bark_context": _bark_ctx_post,
			"grid_pos":    actor.get("grid_pos", {}),
		})

	logger.debug(t, "combat.actor_turn", "%s → %s" % [actor.get("name", "?"), action_type], {
		"round":       round,
		"actor_id":    actor.get("id", ""),
		"actor_name":  actor.get("name", ""),
		"action_type": action_type,
		"faction":     actor.get("faction", ""),
	})

	# Resolve the action and append result to last_round_results.
	match action_type:
		"melee_attack":
			var target_id: String = str(intent.get("target_id", ""))
			var target: Dictionary = _find_actor_by_id(ectx.actors, target_id)
			if not target.is_empty() and not target.get("is_dead", false):
				var result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, round)
				if not result.is_empty():
					result["source_name"] = str(actor.get("name", ""))
					result["target_name"] = str(target.get("name", ""))
					ectx.last_round_results.append(result)
					var kill_str: String = " (kills)" if result.get("is_kill", false) else ""
					logger.info(t, "combat.action_resolved",
					"%s attacks %s for %d%s" % [actor.get("name", "?"), target.get("name", "?"), int(result.get("damage", 0)), kill_str], result)
					# In-combat fear accumulation: each hit adds fear pressure to the defender (runtime dict only).
					var combat_emo_cfg: Dictionary = bdata.get("combat", {}).get("emotion", {})
					var fear_per_hit: int = int(combat_emo_cfg.get("fear_per_hit", 2))
					var hit_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
						target, fear_per_hit, ectx.actors, leadership_expr_cfg)
					target["fear"] = mini(100, int(target.get("fear", 0)) + hit_fear_applied)
					logger.debug(t, "combat.fear.hit", "%s gains fear from hit" % target.get("name", "?"), {
						"actor_id": str(target.get("id", "")),
						"delta":    hit_fear_applied,
						"new_fear": int(target.get("fear", 0)),
					})
					# Kill bonus: killer gets morale + fear reduction; living Echo allies get a ripple.
					if result.get("is_kill", false):
						_apply_kill_momentum(actor, ectx.actors, leadership_expr_cfg, t)
						var morale_per_kill: int      = int(combat_emo_cfg.get("morale_per_kill",       25))
						var fear_reduce_per_kill: int = int(combat_emo_cfg.get("fear_reduce_per_kill",  15))
						var morale_ripple: int         = int(combat_emo_cfg.get("morale_ripple_per_kill", 10))
						var fear_ripple: int           = int(combat_emo_cfg.get("fear_ripple_per_kill",    5))
						actor["morale"] = mini(100, int(actor.get("morale", 50)) + morale_per_kill)
						actor["fear"]   = maxi(0,   int(actor.get("fear",   0)) - fear_reduce_per_kill)
						logger.info(t, "combat.kill_boost", "%s gains morale from kill" % actor.get("name", "?"), {
							"actor_id":     str(actor.get("id", "")),
							"morale_delta": morale_per_kill,
							"fear_delta":   -fear_reduce_per_kill,
						})
						for ally_v in ectx.actors:
							var ally: Dictionary = ally_v if ally_v is Dictionary else {}
							if str(ally.get("id", "")) == str(actor.get("id", "")): continue
							if ally.get("is_dead", false): continue
							if str(ally.get("faction", "")) != "echo": continue
							ally["morale"] = mini(100, int(ally.get("morale", 50)) + morale_ripple)
							ally["fear"]   = maxi(0,   int(ally.get("fear",   0)) - fear_ripple)
							logger.info(t, "combat.kill_ripple",
								"%s ripple from %s kill" % [ally.get("name", "?"), actor.get("name", "?")], {
								"ally_id":      str(ally.get("id", "")),
								"morale_delta": morale_ripple,
								"fear_delta":   -fear_ripple,
							})
					# Trigger 5b: guard absorb — guarding Echo absorbs a hit and gains morale.
					var guard_absorb_morale: int = int(combat_emo_cfg.get("morale_on_guard_absorb", 4))
					if result.get("damage", 0) > 0 \
							and target.get("guard_state", false) \
							and not result.get("is_kill", false):
						target["morale"] = mini(100, int(target.get("morale", 50)) + guard_absorb_morale)
						logger.info(t, "actor.guard_absorb_morale", "Guard absorbed hit — morale tick", {
							"actor_id": str(target.get("id", "")),
							"morale":   target["morale"],
							"delta":    guard_absorb_morale,
						})
					# Triggers 2+6: near-death — first HP drop to ≤ 25% fires morale+fear once per actor.
					var nd_max_hp: int = int(target.get("max_hp", 1))
					if nd_max_hp > 0 \
							and not target.get("_near_death_morale_fired", false) \
							and int(target.get("current_hp", 1)) * 4 <= nd_max_hp \
							and int(target.get("current_hp", 1)) > 0:
						target["_near_death_morale_fired"] = true
						var nd_morale: int = int(combat_emo_cfg.get("morale_on_near_death", 7))
						var nd_fear:   int = int(combat_emo_cfg.get("fear_on_near_death", 8))
						target["morale"] = mini(100, int(target.get("morale", 50)) + nd_morale)
						var nd_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
							target, nd_fear, ectx.actors, leadership_expr_cfg)
						target["fear"]   = mini(100, int(target.get("fear", 0)) + nd_fear_applied)
						logger.info(t, "actor.near_death", "Near-death trigger — morale+fear tick", {
							"actor_id": str(target.get("id", "")),
							"morale":   target["morale"],
							"fear":     target["fear"],
							"fear_delta": nd_fear_applied,
						})
					# V2-VOICE-001: kill is now confirmed — upgrade bark to combat_ko if eligible.
					var _ko_vk: int = (t + str(actor.get("id", "")).hash()) % 997
					asm.finalize_combat_bark(result.get("is_kill", false), _ko_vk)
					# If finalize promoted bark to combat_ko, add it to round_bark_events.
					if str(actor.get("_bark_context", "")) == "combat_ko":
						ectx.round_bark_events.append({
							"actor_id":     str(actor.get("id", "")),
							"faction":      str(actor.get("faction", "")),
							"bark_context": "combat_ko",
							"grid_pos":     actor.get("grid_pos", {}),
						})
			else:
				# Target was dead or missing when this actor's turn resolved — log and skip.
				logger.info(t, "combat.attack_invalid_target",
					"%s's attack target already dead — turn skipped" % actor.get("name", "?"), {
					"actor_id":  str(actor.get("id", "")),
					"target_id": target_id,
				})
				ectx.last_round_results.append({
					"action_type": "actor.idle",
					"source_id":   str(actor.get("id", "")),
					"source_name": str(actor.get("name", "")),
					"target_id":   "",
					"target_name": "",
					"damage":      0,
					"is_kill":     false,
				})
		"actor.guard":
			var guard_result: Dictionary = CombatService.resolve_action("actor.guard", actor, {}, round)
			if not guard_result.is_empty():
				guard_result["source_name"] = str(actor.get("name", ""))
				ectx.last_round_results.append(guard_result)
				logger.info(t, "combat.guard_taken",
					"%s guards" % actor.get("name", "?"), { "actor_id": actor.get("id", "") })
		"actor.refuse":
			logger.info(t, "combat.action_refused",
				"%s refuses (fear %d)" % [actor.get("name", "?"), int(actor.get("fear", 0))], {
				"actor_id": actor.get("id", ""),
				"fear":     int(actor.get("fear", 0)),
			})
			ectx.last_round_results.append({
				"action_type": "actor.refuse",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   "",
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})
		"actor.move":
			var move_target_id: String = str(intent.get("target_id", ""))
			var move_target: Dictionary = _find_actor_by_id(ectx.actors, move_target_id)
			var move_target_name: String = str(move_target.get("name", "")) if not move_target.is_empty() else ""
			logger.debug(t, "combat.actor_moved",
				"%s moves toward %s" % [actor.get("name", "?"), move_target_name if not move_target_name.is_empty() else move_target_id], {
				"actor_id":    actor.get("id", ""),
				"actor_name":  actor.get("name", ""),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"grid_pos":    actor.get("grid_pos", {}),
				"round":       round,
			})
			ectx.last_round_results.append({
				"action_type": "actor.move",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"damage":      0,
				"is_kill":     false,
				"to_pos":      actor.get("grid_pos", {}).duplicate(),
			})
		_:
			ectx.last_round_results.append({
				"action_type": action_type,
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   str(intent.get("target_id", "")),
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})

	if _is_keeper_intro_trial_active():
		var lethal_ids: Array[String] = _keeper_intro_trial_lethal_echo_ids()
		if not lethal_ids.is_empty():
			var onboarding_v: Variant = flow_ctx.save_data.get("onboarding", {})
			var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
			if not bool(onboarding.get("keeper_trial_rewind_used", false)):
				_handle_keeper_intro_trial_rewind(t, lethal_ids)
				return
			_keeper_intro_restore_echo_after_second_attempt(t, lethal_ids)

	if not ectx.last_round_results.is_empty():
		ectx.last_actor_action = ectx.last_round_results.back().duplicate()

	# PROG-003: accumulate echo action log for XP virtue multiplier at resolve.
	# Only echo-faction actors contribute. Accumulated across all rounds.
	if str(actor.get("faction", "")) == "echo" and not ectx.last_round_results.is_empty():
		var last_res: Dictionary = ectx.last_round_results.back()
		var eid: String = str(actor.get("id", ""))
		if not ectx.echo_action_logs.has(eid):
			ectx.echo_action_logs[eid] = { "melee_count": 0, "guard_count": 0, "kill_count": 0, "total_count": 0 }
		var alog: Dictionary = ectx.echo_action_logs[eid]
		match str(last_res.get("action_type", "")):
			"melee_attack":
				alog["melee_count"] += 1
				alog["total_count"] += 1
				if bool(last_res.get("is_kill", false)):
					alog["kill_count"] += 1
					# XP tuning: kill XP applied immediately for mid-combat stat bump.
					var roster_echo: Dictionary = _find_roster_echo(str(actor.get("id", "")))
					if not roster_echo.is_empty():
						ProgressionService.apply_mid_combat_kill_xp(
							roster_echo, actor, prog_cfg_block, birth_stats_block,
							_get_realm_xp_multiplier(), logger, t
						)
			"actor.guard":
				alog["guard_count"] += 1
				alog["total_count"] += 1
			"actor.move", "actor.idle", "actor.refuse":
				alog["total_count"] += 1

	# Advance current_actor_index past this actor so the next call finds the correct one.
	combat_state["current_actor_index"] = next_idx + 1

	# Emit per-actor snapshot — UI shows updated board + arrow + action text for this actor.
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: called after the last actor in the round has acted.
## Logs round_end, checks end condition, resets round state, emits round-end snapshot.
func _end_round(t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state
	var round: int = int(combat_state.get("round_counter", 0))
	var leadership_expr_cfg: Dictionary = config_service.get_balance().get(
		"data", {}).get("maturity_expression", {})

	# Build remaining_actors list (living — for round_end log).
	var remaining_actors: Array = []
	for a_v in ectx.actors:
		if a_v is Dictionary and not a_v.get("is_dead", false):
			remaining_actors.append(str(a_v.get("id", "")))

	logger.info(t, "combat.round_end", "Round complete", {
		"round":            round,
		"remaining_actors": remaining_actors,
	})

	# COMBAT-006: apply per-round shrine drain before end-condition check (drain can kill shrine).
	var shrine_hp_val: int = 0
	if ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
		var balance_drain: Dictionary = config_service.get_balance()
		var shrine_cfg_drain: Dictionary = balance_drain.get("data", {}).get("combat", {}).get("shrine", {})
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				var drain_result: Dictionary = ShrineService.apply_drain(a_v, shrine_cfg_drain)
				shrine_hp_val = int(drain_result.get("shrine_hp", 0))
				if shrine_hp_val <= 0:
					a_v["is_dead"]     = true
					a_v["death_round"] = round
				logger.info(t, "combat.shrine_drain", "Shrine drained this round", {
					"shrine_id":     str(a_v.get("id", "")),
					"drain":         int(drain_result.get("drain", 0)),
					"shrine_hp":     shrine_hp_val,
					"stacks_active": a_v.get("purify_stacks", []).size(),
				})
				# Decrement purifier cooldown (min 0).
				if not ectx.purifier_id.is_empty():
					for pa_v in ectx.actors:
						if pa_v is Dictionary and str(pa_v.get("id", "")) == ectx.purifier_id:
							pa_v["purify_cooldown"] = maxi(0, int(pa_v.get("purify_cooldown", 0)) - 1)
							break
				# Shrine morale drain: each wave grinds down the party's will (runtime dict only).
				var morale_drain_wave: int = int(shrine_cfg_drain.get("morale_drain_per_wave", 5))
				var shrine_morale_affected: int = 0
				for em_a in ectx.actors:
					if em_a is Dictionary and not em_a.get("is_dead", false) \
							and em_a.get("faction", "") == "echo":
						var applied_drain := LeadershipEmotionServiceScript.apply_morale_loss(
							em_a, morale_drain_wave, ectx.actors, leadership_expr_cfg, round)
						em_a["morale"] = maxi(0, int(em_a.get("morale", 50)) - applied_drain)
						shrine_morale_affected += 1
				if shrine_morale_affected > 0:
					logger.info(t, "combat.shrine.morale_drain", "Shrine wave drains echo morale", {
						"delta":          -morale_drain_wave,
						"affected_count": shrine_morale_affected,
					})
				break
		# Capture shrine_hp even if alive (for snapshot).
		if shrine_hp_val == 0:
			for a_v in ectx.actors:
				if a_v is Dictionary and a_v.get("is_structure", false):
					shrine_hp_val = int(a_v.get("current_hp", 0))
					break

	# In-combat emotion tick — applied to runtime actor dicts only; save data unchanged here.
	var emo_tick_cfg: Dictionary = config_service.get_balance().get("data", {}).get("combat", {}).get("emotion", {})

	# A) Ally KO fear spread: when a comrade falls, surviving same-faction actors gain fear.
	var fear_per_ally_ko: int = int(emo_tick_cfg.get("fear_per_ally_ko", 4))
	for res_v in ectx.last_round_results:
		if res_v is Dictionary and int(res_v.get("defender_hp_after", 1)) <= 0:
			var ko_id: String = str(res_v.get("target_id", ""))
			var ko_actor: Dictionary = _find_actor_by_id(ectx.actors, ko_id)
			if ko_actor.is_empty():
				continue
			var ko_faction: String = str(ko_actor.get("faction", ""))
			var ko_spread_count: int = 0
			for sp_a in ectx.actors:
				if sp_a is Dictionary and not sp_a.get("is_dead", false) \
						and str(sp_a.get("id", "")) != ko_id \
						and str(sp_a.get("faction", "")) == ko_faction \
						and not sp_a.get("is_structure", false):
					var ko_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
						sp_a, fear_per_ally_ko, ectx.actors, leadership_expr_cfg, true)
					sp_a["fear"] = mini(100, int(sp_a.get("fear", 0)) + ko_fear_applied)
					ko_spread_count += 1
			if ko_spread_count > 0:
				logger.info(t, "combat.fear.ally_ko", "Ally KO spreads fear to survivors", {
					"ko_actor_id":    ko_id,
					"affected_count": ko_spread_count,
					"delta":          fear_per_ally_ko,
				})

	# B) Per-round fear tick: baseline fear accumulation for all living actors.
	var fear_per_round: int = int(emo_tick_cfg.get("fear_per_round", 1))
	for tick_a in ectx.actors:
		if tick_a is Dictionary and not tick_a.get("is_dead", false) \
				and not tick_a.get("is_structure", false):
			var round_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
				tick_a, fear_per_round, ectx.actors, leadership_expr_cfg)
			tick_a["fear"] = mini(100, int(tick_a.get("fear", 0)) + round_fear_applied)
	logger.debug(t, "combat.emotion.tick", "Round fear tick applied", {
		"round":      round,
		"fear_delta": fear_per_round,
	})

	# C) Morale decay every N rounds: long fights grind echo morale (echo actors only).
	var morale_decay_n: int  = int(emo_tick_cfg.get("morale_decay_n_rounds", 3))
	var morale_decay_amt: int = int(emo_tick_cfg.get("morale_decay_amount", 1))
	if morale_decay_n > 0 and round % morale_decay_n == 0:
		for dec_a in ectx.actors:
			if dec_a is Dictionary and not dec_a.get("is_dead", false) \
					and dec_a.get("faction", "") == "echo":
				var decay_applied := LeadershipEmotionServiceScript.apply_morale_loss(
					dec_a, morale_decay_amt, ectx.actors, leadership_expr_cfg, round)
				dec_a["morale"] = maxi(0, int(dec_a.get("morale", 50)) - decay_applied)
		logger.debug(t, "combat.emotion.morale_decay", "Round morale decay applied", {
			"round": round,
			"delta": -morale_decay_amt,
		})

	# D) Outnumbering advantage (T5): Echoes outnumbering enemies reduces fear at end of round.
	var t5_living_echoes: Array = []
	var t5_living_enemies: Array = []
	for t5_a in ectx.actors:
		if not (t5_a is Dictionary) or t5_a.get("is_dead", false) or t5_a.get("is_structure", false):
			continue
		if str(t5_a.get("faction", "")) == "echo":
			t5_living_echoes.append(t5_a)
		elif str(t5_a.get("faction", "")) == "enemy":
			t5_living_enemies.append(t5_a)
	if t5_living_echoes.size() > t5_living_enemies.size() and not t5_living_echoes.is_empty():
		var outnumber_fear: int = int(emo_tick_cfg.get("fear_reduce_on_outnumber", 2))
		for t5_echo in t5_living_echoes:
			t5_echo["fear"] = maxi(0, int(t5_echo.get("fear", 0)) - outnumber_fear)
		logger.debug(t, "combat.emotion.outnumber", "Echoes outnumber enemies — fear reduction", {
			"echo_count":  t5_living_echoes.size(),
			"enemy_count": t5_living_enemies.size(),
			"delta":       -outnumber_fear,
		})

	# E) Witness ally refuse (T7): nearby Echoes gain fear when a comrade freezes this round.
	var witness_fear: int   = int(emo_tick_cfg.get("fear_on_witness_refuse", 4))
	var witness_radius: int = int(emo_tick_cfg.get("witness_refuse_radius", 3))
	for t7_res in ectx.last_round_results:
		if not (t7_res is Dictionary): continue
		if str(t7_res.get("action_type", "")) != "actor.refuse": continue
		var t7_refuser_id: String = str(t7_res.get("source_id", ""))
		var t7_refuser_pos: Dictionary = {}
		for t7_a in ectx.actors:
			if t7_a is Dictionary and str(t7_a.get("id", "")) == t7_refuser_id:
				t7_refuser_pos = t7_a.get("grid_pos", {})
				break
		if t7_refuser_pos.is_empty(): continue
		for t7_obs in ectx.actors:
			if not (t7_obs is Dictionary): continue
			if t7_obs.get("is_dead", false): continue
			if str(t7_obs.get("faction", "")) != "echo": continue
			if str(t7_obs.get("id", "")) == t7_refuser_id: continue
			var t7_obs_pos: Dictionary = t7_obs.get("grid_pos", {})
			if GridService.manhattan_distance(t7_refuser_pos, t7_obs_pos) <= witness_radius:
				var witness_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
					t7_obs, witness_fear, ectx.actors, leadership_expr_cfg, true)
				t7_obs["fear"] = mini(100, int(t7_obs.get("fear", 0)) + witness_fear_applied)
				logger.debug(t, "combat.emotion.witness_refuse", "Witness ally freeze — fear tick", {
					"observer_id": str(t7_obs.get("id", "")),
					"refuser_id":  t7_refuser_id,
					"delta":       witness_fear,
				})

	# F) Overwhelmed (T8): Echo targeted by 2+ attackers in one round gains fear.
	var overwhelm_threshold: int = int(emo_tick_cfg.get("overwhelmed_threshold", 2))
	var overwhelm_fear: int      = int(emo_tick_cfg.get("fear_on_overwhelmed", 5))
	var t8_attack_counts: Dictionary = {}
	for t8_res in ectx.last_round_results:
		if not (t8_res is Dictionary): continue
		if str(t8_res.get("action_type", "")) != "melee_attack": continue
		var t8_tid: String = str(t8_res.get("target_id", ""))
		if t8_tid.is_empty(): continue
		t8_attack_counts[t8_tid] = t8_attack_counts.get(t8_tid, 0) + 1
	for t8_tid in t8_attack_counts:
		if t8_attack_counts[t8_tid] >= overwhelm_threshold:
			var t8_victim: Dictionary = _find_actor_by_id(ectx.actors, t8_tid)
			if t8_victim.is_empty() or t8_victim.get("is_dead", false): continue
			var overwhelm_applied := LeadershipEmotionServiceScript.apply_fear_gain(
				t8_victim, overwhelm_fear, ectx.actors, leadership_expr_cfg)
			t8_victim["fear"] = mini(100, int(t8_victim.get("fear", 0)) + overwhelm_applied)
			logger.info(t, "combat.emotion.overwhelmed", "Echo overwhelmed by multiple attackers", {
				"actor_id":       t8_tid,
				"attacker_count": t8_attack_counts[t8_tid],
				"delta":          overwhelm_fear,
			})

	# G) Consecutive no-damage (T9): Echo that dealt no damage for N rounds loses morale.
	var no_dmg_threshold: int = int(emo_tick_cfg.get("consecutive_no_damage_threshold", 2))
	var no_dmg_morale: int    = int(emo_tick_cfg.get("morale_on_consecutive_no_damage", -3))
	for t9_a in ectx.actors:
		if not (t9_a is Dictionary): continue
		if t9_a.get("is_dead", false): continue
		if str(t9_a.get("faction", "")) != "echo": continue
		var t9_id: String = str(t9_a.get("id", ""))
		var t9_dealt: bool = false
		for t9_res in ectx.last_round_results:
			if t9_res is Dictionary \
					and str(t9_res.get("source_id", "")) == t9_id \
					and int(t9_res.get("damage", 0)) > 0:
				t9_dealt = true
				break
		if t9_dealt:
			t9_a["_no_damage_streak"] = 0
		else:
			t9_a["_no_damage_streak"] = int(t9_a.get("_no_damage_streak", 0)) + 1
			if int(t9_a["_no_damage_streak"]) >= no_dmg_threshold:
				var no_damage_loss := LeadershipEmotionServiceScript.apply_morale_loss(
					t9_a, abs(no_dmg_morale), ectx.actors, leadership_expr_cfg, round)
				t9_a["morale"] = maxi(0, int(t9_a.get("morale", 50)) - no_damage_loss)
				logger.debug(t, "combat.emotion.no_damage_streak", "Echo helplessness — morale decay", {
					"actor_id": t9_id,
					"streak":   t9_a["_no_damage_streak"],
					"delta":    no_dmg_morale,
				})

	# V2-STAGE-004 P3a — RECOVER: update hold_counter based on echo adjacency to the relic.
	# Gate: RECOVER only; COMBAT / PURIFY_SHRINE / other modes are byte-identical.
	if ectx.resolution_mode == EncounterResolutionModes.RECOVER:
		# Locate the relic: first living is_structure actor.
		var _relic: Dictionary = {}
		for _ra in ectx.actors:
			if _ra is Dictionary and bool(_ra.get("is_structure", false)) \
					and not bool(_ra.get("is_dead", false)):
				_relic = _ra
				break
		if not _relic.is_empty():
			var _relic_pos: Dictionary = _relic.get("grid_pos", {})
			var _any_adjacent: bool = false
			for _re_a in ectx.actors:
				if not (_re_a is Dictionary): continue
				if bool(_re_a.get("is_dead", false)): continue
				if str(_re_a.get("faction", "")) != "echo": continue
				if GridService.is_adjacent(_re_a.get("grid_pos", {}), _relic_pos):
					_any_adjacent = true
					break
			if _any_adjacent:
				combat_state["hold_counter"] = int(combat_state.get("hold_counter", 0)) + 1
			else:
				combat_state["hold_counter"] = 0
			logger.debug(t, "combat.recover.hold", "RECOVER hold_counter updated", {
				"round":        round,
				"hold_counter": int(combat_state.get("hold_counter", 0)),
				"adjacent":     _any_adjacent,
			})

		# V2-STAGE-004 Distinctiveness §4-D: designate holder once (deterministic pick).
		# Among living echoes: highest speed; tiebreak highest stats.agi; tiebreak lowest id.
		if str(combat_state.get("recover_holder_id", "")) == "":
			var _holder_best: Dictionary = {}
			for _hd_a in ectx.actors:
				if not (_hd_a is Dictionary): continue
				if bool(_hd_a.get("is_dead", false)): continue
				if str(_hd_a.get("faction", "")) != "echo": continue
				if _holder_best.is_empty():
					_holder_best = _hd_a
				else:
					var _hd_spd: int  = int(_hd_a.get("speed", 0))
					var _hb_spd: int  = int(_holder_best.get("speed", 0))
					if _hd_spd > _hb_spd:
						_holder_best = _hd_a
					elif _hd_spd == _hb_spd:
						var _hd_agi: int = int(_hd_a.get("stats", {}).get("agi", 0))
						var _hb_agi: int = int(_holder_best.get("stats", {}).get("agi", 0))
						if _hd_agi > _hb_agi:
							_holder_best = _hd_a
						elif _hd_agi == _hb_agi:
							# Tiebreak: lowest id string (lexicographic).
							if str(_hd_a.get("id", "")) < str(_holder_best.get("id", "")):
								_holder_best = _hd_a
			if not _holder_best.is_empty():
				combat_state["recover_holder_id"] = str(_holder_best.get("id", ""))
				logger.info(t, "combat.recover.holder_assigned", "RECOVER holder designated", {
					"round":     round,
					"holder_id": str(combat_state.get("recover_holder_id", "")),
					"holder_name": str(_holder_best.get("name", "")),
				})

		# V2-STAGE-004 Distinctiveness §4-E: RECOVER reinforcement spawn.
		# Trigger: round > 0, divisible by reinforce_interval, and under max total.
		var _rec_obj2: Dictionary = combat_state.get("objective_params", {})
		var _reinf_interval: int   = int(_rec_obj2.get("reinforce_interval", 2))
		var _reinf_size: int       = int(_rec_obj2.get("reinforce_size", 1))
		var _reinf_group: String   = str(_rec_obj2.get("reinforce_group", "group.vale_patrol_sm"))
		var _reinf_max: int        = int(_rec_obj2.get("reinforce_max_total", 4))
		var _rec_round: int        = int(combat_state.get("round_counter", 0))
		var _rec_reinf_count: int  = int(combat_state.get("recover_reinforce_count", 0))
		if _rec_round > 0 and _reinf_interval > 0 \
				and _rec_round % _reinf_interval == 0 \
				and _rec_reinf_count < _reinf_max:
			# Build actor_cfg matching FlowEncounterState.enter() shape.
			var _ri_actor_cfg: Dictionary = {}
			var _ri_actors_json: Dictionary = {}
			if flow_ctx.config_service != null:
				var _ri_bal: Dictionary = flow_ctx.config_service.get_balance()
				var _ri_bd: Dictionary  = _ri_bal.get("data", {})
				_ri_actor_cfg = {
					"birth_stats": _ri_bd.get("summoning", {}).get("birth_stats", {}),
					"enemy_types": _ri_bd.get("actor", {}).get("enemy_types", {}),
				}
				_ri_actors_json = flow_ctx.config_service.get_actors()
			var _ri_actors_data: Dictionary = _ri_actors_json.get("data", {})
			var _ri_enemies_dict: Dictionary = _ri_actors_data.get("enemies", {})
			var _ri_groups_dict: Dictionary  = _ri_actors_data.get("groups", {})
			var _ri_group_def: Dictionary    = _ri_groups_dict.get(_reinf_group, {})
			var _ri_spawns: Array = _ri_group_def.get("spawns", []) if not _ri_group_def.is_empty() else []
			var _ri_new_actors: Array = []
			var _ri_built: int = 0
			var _ri_tmpl_idx: int = 0
			while _ri_built < _reinf_size and not _ri_spawns.is_empty():
				var _ri_sp: Dictionary = _ri_spawns[_ri_tmpl_idx % _ri_spawns.size()]
				_ri_tmpl_idx += 1
				if not (_ri_sp is Dictionary): continue
				var _ri_template_id: String = str(_ri_sp.get("template_id", ""))
				var _ri_tmpl: Dictionary = _ri_enemies_dict.get(_ri_template_id, {})
				if _ri_tmpl.is_empty(): continue
				var _ri_type_key: String = _ri_template_id
				if _ri_type_key.begins_with("enemy."):
					_ri_type_key = _ri_type_key.substr(6)
				var _ri_defn: Dictionary = {
					"id":      "recover_reinf_%d_%d" % [_rec_round, _ri_built],
					"name":   str(_ri_tmpl.get("name", _ri_template_id)),
					"type":   _ri_type_key,
					"faction": "enemy",
				}
				_ri_new_actors.append(EnemyActor.from_definition(_ri_defn, t, _ri_actor_cfg))
				_ri_built += 1
			# Placement: enemy-side (highest columns), deterministic — reuse ENDURE placement logic.
			var _ri_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain) \
				if not ectx.terrain.is_empty() else {}
			var _ri_occupied: Dictionary = {}
			for _ri_oa in ectx.actors:
				if _ri_oa is Dictionary and not bool(_ri_oa.get("is_dead", false)):
					var _ri_op: Dictionary = _ri_oa.get("grid_pos", {})
					if not _ri_op.is_empty():
						_ri_occupied["%d,%d" % [int(_ri_op.get("col", 0)), int(_ri_op.get("row", 0))]] = true
			if not _ri_walkable.is_empty():
				var _ri_candidate_keys: Array = []
				for _ri_k in _ri_walkable:
					if not _ri_occupied.has(_ri_k):
						_ri_candidate_keys.append(_ri_k)
				_ri_candidate_keys.sort_custom(func(a: String, b: String) -> bool:
					var _ap := a.split(","); var _bp := b.split(",")
					var _ac: int = int(_ap[0]); var _bc: int = int(_bp[0])
					if _ac != _bc: return _ac > _bc  # highest col first (enemy side)
					var _ar: int = int(_ap[1]); var _br: int = int(_bp[1])
					if _ar != _br: return _ar < _br   # row asc tiebreak
					return _ac < _bc                  # col asc final tiebreak
				)
				var _ri_cell_idx: int = 0
				for _ri_na in _ri_new_actors:
					if _ri_cell_idx >= _ri_candidate_keys.size():
						break
					var _ri_ck: String = _ri_candidate_keys[_ri_cell_idx]
					var _ri_ck_parts := _ri_ck.split(",")
					GridService.assign_grid_pos(_ri_na,
						int(_ri_ck_parts[0]), int(_ri_ck_parts[1]))
					_ri_occupied[_ri_ck] = true
					_ri_cell_idx += 1
			else:
				# Legacy path (no terrain): rightmost columns.
				var _ri_bal_leg: Dictionary = {}
				if flow_ctx.config_service != null:
					_ri_bal_leg = flow_ctx.config_service.get_balance()
				var _ri_grid_leg: Dictionary = _ri_bal_leg.get("data", {}).get("grid", {})
				var _ri_cols: int = GridService.get_board_cols(_ri_grid_leg)
				var _ri_rows: int = GridService.get_board_rows(_ri_grid_leg)
				var _ri_leg_cells: Array = []
				for _ri_leg_c in range(_ri_cols - 1, -1, -1):
					for _ri_leg_r in range(_ri_rows):
						var _ri_leg_k: String = "%d,%d" % [_ri_leg_c, _ri_leg_r]
						if not _ri_occupied.has(_ri_leg_k):
							_ri_leg_cells.append({ "col": _ri_leg_c, "row": _ri_leg_r })
				var _ri_leg_idx: int = 0
				for _ri_na in _ri_new_actors:
					if _ri_leg_idx >= _ri_leg_cells.size():
						break
					var _ri_leg_cell: Dictionary = _ri_leg_cells[_ri_leg_idx]
					GridService.assign_grid_pos(_ri_na,
						int(_ri_leg_cell.get("col", 0)), int(_ri_leg_cell.get("row", 0)))
					_ri_occupied["%d,%d" % [int(_ri_leg_cell.get("col", 0)), int(_ri_leg_cell.get("row", 0))]] = true
					_ri_leg_idx += 1
			# Append to ectx.actors + END of initiative_order (never re-sort).
			var _ri_init_order: Array = combat_state.get("initiative_order", [])
			for _ri_na in _ri_new_actors:
				ectx.actors.append(_ri_na)
				_ri_init_order.append({ "id": str(_ri_na.get("id", "")), "name": str(_ri_na.get("name", "")) })
			combat_state["initiative_order"] = _ri_init_order
			combat_state["recover_reinforce_count"] = _rec_reinf_count + _ri_new_actors.size()
			logger.info(t, "combat.recover.reinforce", "RECOVER reinforcement spawned", {
				"round":              _rec_round,
				"count":              _ri_new_actors.size(),
				"reinforce_group":    _reinf_group,
				"total_reinforced":   int(combat_state.get("recover_reinforce_count", 0)),
			})

	# V2-STAGE-004 P3a — ENDURE: spawn an enemy wave at the configured interval.
	# Gate: ENDURE only; COMBAT / PURIFY_SHRINE / other modes are byte-identical.
	if ectx.resolution_mode == EncounterResolutionModes.ENDURE:
		var _end_obj: Dictionary = combat_state.get("objective_params", {})
		var _wave_interval: int      = int(_end_obj.get("wave_interval", 2))
		var _wave_size_base: int     = int(_end_obj.get("wave_size", 2))
		var _wave_size_max: int      = int(_end_obj.get("wave_size_max", 4))
		var _wave_size_rising: int   = int(_end_obj.get("wave_size_rising_step", 0))
		var _wave_group: String      = str(_end_obj.get("wave_group", "group.vale_patrol_sm"))
		var _duration_turns: int     = int(_end_obj.get("duration_turns", 5))
		var _round_no: int           = int(combat_state.get("round_counter", 0))

		# V2-STAGE-004 Distinctiveness §4-F: compute total_waves once (count intervals in range).
		if not combat_state.has("total_waves"):
			var _tw: int = 0
			if _wave_interval > 0:
				for _r in range(1, _duration_turns):
					if _r % _wave_interval == 0:
						_tw += 1
			combat_state["total_waves"] = _tw

		# Spawn when: not round 0, divisible by interval, and before the final/winning round.
		if _round_no > 0 and _wave_interval > 0 \
				and _round_no % _wave_interval == 0 \
				and _round_no < _duration_turns:
			# §4-F: rising wave size — N = waves_spawned (1-indexed after increment).
			var _waves_so_far: int = int(combat_state.get("waves_spawned", 0))
			var _wave_n: int       = _waves_so_far + 1  # 1-indexed for this spawn
			var _wave_size: int    = clampi(_wave_size_base + (_wave_n - 1) * _wave_size_rising, _wave_size_base, _wave_size_max)
			# Build actor_cfg same as FlowEncounterState.enter() does.
			var _w_actor_cfg: Dictionary = {}
			var _w_actors_json: Dictionary = {}
			if flow_ctx.config_service != null:
				var _w_bal: Dictionary = flow_ctx.config_service.get_balance()
				var _w_bd: Dictionary  = _w_bal.get("data", {})
				_w_actor_cfg = {
					"birth_stats": _w_bd.get("summoning", {}).get("birth_stats", {}),
					"enemy_types": _w_bd.get("actor", {}).get("enemy_types", {}),
				}
				_w_actors_json = flow_ctx.config_service.get_actors()
			var _w_actors_data: Dictionary = _w_actors_json.get("data", {})
			var _w_enemies_dict: Dictionary = _w_actors_data.get("enemies", {})
			var _w_groups_dict: Dictionary  = _w_actors_data.get("groups", {})
			var _w_group_def: Dictionary    = _w_groups_dict.get(_wave_group, {})
			# Collect spawn templates from the group, repeating to fill wave_size.
			var _w_spawns: Array = _w_group_def.get("spawns", []) if not _w_group_def.is_empty() else []
			var _w_new_actors: Array = []
			var _w_built: int = 0
			var _w_tmpl_idx: int = 0
			while _w_built < _wave_size and not _w_spawns.is_empty():
				var _w_sp: Dictionary = _w_spawns[_w_tmpl_idx % _w_spawns.size()]
				_w_tmpl_idx += 1
				if not (_w_sp is Dictionary): continue
				var _w_template_id: String = str(_w_sp.get("template_id", ""))
				var _w_tmpl: Dictionary = _w_enemies_dict.get(_w_template_id, {})
				if _w_tmpl.is_empty(): continue
				var _w_type_key: String = _w_template_id
				if _w_type_key.begins_with("enemy."):
					_w_type_key = _w_type_key.substr(6)
				var _w_defn: Dictionary = {
					"id":      "wave_%d_%d" % [_round_no, _w_built],
					"name":   str(_w_tmpl.get("name", _w_template_id)),
					"type":   _w_type_key,
					"faction": "enemy",
				}
				_w_new_actors.append(EnemyActor.from_definition(_w_defn, t, _w_actor_cfg))
				_w_built += 1

			# Determine walkable cells; use ENEMY-SIDE (highest columns) for placement.
			# Purely deterministic: sort walkable cells descending by col, tiebreak row then col.
			var _w_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain) \
				if not ectx.terrain.is_empty() else {}
			# Build occupied set from all living actors.
			var _w_occupied: Dictionary = {}
			for _w_oa in ectx.actors:
				if _w_oa is Dictionary and not bool(_w_oa.get("is_dead", false)):
					var _w_op: Dictionary = _w_oa.get("grid_pos", {})
					if not _w_op.is_empty():
						_w_occupied["%d,%d" % [int(_w_op.get("col", 0)), int(_w_op.get("row", 0))]] = true
			if not _w_walkable.is_empty():
				# Build candidate cells sorted descending by col (highest col = enemy side),
				# tiebreak row asc then col asc for full determinism.
				var _w_candidate_keys: Array = []
				for _w_k in _w_walkable:
					if not _w_occupied.has(_w_k):
						_w_candidate_keys.append(_w_k)
				_w_candidate_keys.sort_custom(func(a: String, b: String) -> bool:
					var _ap := a.split(","); var _bp := b.split(",")
					var _ac: int = int(_ap[0]); var _bc: int = int(_bp[0])
					if _ac != _bc: return _ac > _bc  # highest col first (enemy side)
					var _ar: int = int(_ap[1]); var _br: int = int(_bp[1])
					if _ar != _br: return _ar < _br   # row asc tiebreak
					return _ac < _bc                  # col asc final tiebreak
				)
				var _w_cell_idx: int = 0
				for _w_na in _w_new_actors:
					if _w_cell_idx >= _w_candidate_keys.size():
						break
					var _w_ck: String = _w_candidate_keys[_w_cell_idx]
					var _w_ck_parts := _w_ck.split(",")
					GridService.assign_grid_pos(_w_na,
						int(_w_ck_parts[0]), int(_w_ck_parts[1]))
					_w_occupied[_w_ck] = true
					_w_cell_idx += 1
			else:
				# Legacy path (no terrain): mirror GridService enemy packing — rightmost columns.
				var _w_bal_leg: Dictionary = {}
				if flow_ctx.config_service != null:
					_w_bal_leg = flow_ctx.config_service.get_balance()
				var _w_grid_leg: Dictionary = _w_bal_leg.get("data", {}).get("grid", {})
				var _w_cols: int = GridService.get_board_cols(_w_grid_leg)
				var _w_rows: int = GridService.get_board_rows(_w_grid_leg)
				# Collect unoccupied rightmost cells: descending col, ascending row.
				var _w_leg_cells: Array = []
				for _w_leg_c in range(_w_cols - 1, -1, -1):
					for _w_leg_r in range(_w_rows):
						var _w_leg_k: String = "%d,%d" % [_w_leg_c, _w_leg_r]
						if not _w_occupied.has(_w_leg_k):
							_w_leg_cells.append({ "col": _w_leg_c, "row": _w_leg_r })
				var _w_leg_idx: int = 0
				for _w_na in _w_new_actors:
					if _w_leg_idx >= _w_leg_cells.size():
						break
					var _w_leg_cell: Dictionary = _w_leg_cells[_w_leg_idx]
					GridService.assign_grid_pos(_w_na,
						int(_w_leg_cell.get("col", 0)), int(_w_leg_cell.get("row", 0)))
					_w_occupied["%d,%d" % [int(_w_leg_cell.get("col", 0)), int(_w_leg_cell.get("row", 0))]] = true
					_w_leg_idx += 1

			# Append new actors to ectx.actors and their ids to the END of initiative_order.
			# Never re-sort — "readiness computed once" invariant (V2-COMBAT-001) preserved.
			var _w_init_order: Array = combat_state.get("initiative_order", [])
			for _w_na in _w_new_actors:
				ectx.actors.append(_w_na)
				_w_init_order.append({ "id": str(_w_na.get("id", "")), "name": str(_w_na.get("name", "")) })
			combat_state["initiative_order"] = _w_init_order
			# §4-F: increment waves_spawned and set all_waves_spawned flag.
			combat_state["waves_spawned"] = _waves_so_far + 1
			combat_state["all_waves_spawned"] = int(combat_state.get("waves_spawned", 0)) >= int(combat_state.get("total_waves", 9999))
			logger.info(t, "combat.wave.spawned", "ENDURE wave spawned", {
				"round":            _round_no,
				"count":            _w_new_actors.size(),
				"wave_group":       _wave_group,
				"wave_n":           _wave_n,
				"wave_size_used":   _wave_size,
				"waves_spawned":    int(combat_state.get("waves_spawned", 0)),
				"total_waves":      int(combat_state.get("total_waves", 0)),
				"all_waves_spawned": bool(combat_state.get("all_waves_spawned", false)),
			})

	# V2-STAGE-004 Distinctiveness §4-G: PROTECT theft block.
	# Gate: PROTECT only. Locate the totem (first living is_structure actor).
	if ectx.resolution_mode == EncounterResolutionModes.PROTECT:
		var _prot_totem: Dictionary = {}
		for _pt_a in ectx.actors:
			if _pt_a is Dictionary and bool(_pt_a.get("is_structure", false)) \
					and not bool(_pt_a.get("is_dead", false)):
				_prot_totem = _pt_a
				break
		if not _prot_totem.is_empty():
			var _pt_totem_pos: Dictionary = _prot_totem.get("grid_pos", {})
			# Recovery first: if stolen and carrier is dead/absent → clear theft state.
			if bool(combat_state.get("totem_stolen", false)):
				var _pt_carrier_id: String = str(combat_state.get("totem_carrier_id", ""))
				var _pt_carrier: Dictionary = _find_actor_by_id(ectx.actors, _pt_carrier_id)
				var _pt_carrier_dead: bool = _pt_carrier.is_empty() or bool(_pt_carrier.get("is_dead", false))
				if _pt_carrier_dead:
					combat_state["totem_stolen"] = false
					combat_state["totem_carrier_id"] = ""
					if not _pt_carrier.is_empty():
						_pt_carrier["_carrier_double_damage"] = false
					logger.info(t, "combat.protect.theft_cleared", "PROTECT carrier down — theft cleared", {
						"round":       round,
						"carrier_id":  _pt_carrier_id,
					})
			# Theft roll: only when NOT already stolen.
			elif not bool(combat_state.get("totem_stolen", false)):
				# Determine if totem is guarded (any living echo adjacent to totem).
				var _pt_guarded: bool = false
				for _pt_echo in ectx.actors:
					if not (_pt_echo is Dictionary): continue
					if bool(_pt_echo.get("is_dead", false)): continue
					if str(_pt_echo.get("faction", "")) != "echo": continue
					if GridService.is_adjacent(_pt_echo.get("grid_pos", {}), _pt_totem_pos):
						_pt_guarded = true
						break
				if not _pt_guarded:
					# Find living enemy adjacent to totem with lowest id (deterministic).
					var _pt_adj_enemy: Dictionary = {}
					for _pt_en in ectx.actors:
						if not (_pt_en is Dictionary): continue
						if bool(_pt_en.get("is_dead", false)): continue
						if str(_pt_en.get("faction", "")) != "enemy": continue
						if bool(_pt_en.get("is_structure", false)): continue
						if GridService.is_adjacent(_pt_en.get("grid_pos", {}), _pt_totem_pos):
							if _pt_adj_enemy.is_empty() or \
									str(_pt_en.get("id", "")) < str(_pt_adj_enemy.get("id", "")):
								_pt_adj_enemy = _pt_en
					if not _pt_adj_enemy.is_empty():
						# Roll theft via CampaignSeed — one derive per round, append-only namespace.
						var _pt_encounter_id: String = str(ectx.encounter_id)
						var _pt_theft_rng: RandomNumberGenerator = RandomNumberGenerator.new()
						if flow_ctx.campaign_seed != null:
							_pt_theft_rng = flow_ctx.campaign_seed.get_rng(
								"combat.theft.%s.%d" % [_pt_encounter_id, round])
						else:
							_pt_theft_rng.seed = hash("combat.theft.%s.%d" % [_pt_encounter_id, round])
						# Read theft_chance from balance config.
						var _pt_bal: Dictionary = {}
						if flow_ctx.config_service != null:
							_pt_bal = flow_ctx.config_service.get_balance()
						var _pt_theft_chance: float = float(
							_pt_bal.get("data", {}).get("combat", {})
								.get("objective_modes", {})
								.get("protect", {})
								.get("theft_chance", 0.5))
						if _pt_theft_rng.randf() < _pt_theft_chance:
							combat_state["totem_stolen"]     = true
							combat_state["totem_carrier_id"] = str(_pt_adj_enemy.get("id", ""))
							_pt_adj_enemy["_carrier_double_damage"] = true
							_pt_adj_enemy["_double_damage_mult"] = float(
								_pt_bal.get("data", {}).get("combat", {})
									.get("objective_modes", {})
									.get("protect", {})
									.get("double_damage_mult", 2.0))
							logger.info(t, "combat.protect.theft", "PROTECT totem stolen!", {
								"round":       round,
								"carrier_id":  str(_pt_adj_enemy.get("id", "")),
								"carrier_name": str(_pt_adj_enemy.get("name", "")),
							})

	# V2-STAGE-004 Distinctiveness §4-G2: PROTECT guard-proximity counter.
	# protect_counter only advances on rounds where at least one living echo is within
	# protect_guard_radius (Chebyshev) of the protected entity. Resets when unguarded
	# (mirrors RECOVER hold_counter). Gate: PROTECT only. Run AFTER theft resolution for this round.
	if ectx.resolution_mode == EncounterResolutionModes.PROTECT:
		var _pg_entity: Dictionary = {}
		for _pg_a in ectx.actors:
			if _pg_a is Dictionary and bool(_pg_a.get("is_structure", false)) \
					and not bool(_pg_a.get("is_dead", false)):
				_pg_entity = _pg_a
				break
		if not _pg_entity.is_empty():
			var _pg_entity_pos: Dictionary = _pg_entity.get("grid_pos", {})
			# Read guard radius from balance config (default 2).
			var _pg_bal: Dictionary = {}
			if flow_ctx.config_service != null:
				_pg_bal = flow_ctx.config_service.get_balance()
			var _pg_guard_radius: int = int(
				_pg_bal.get("data", {}).get("combat", {})
					.get("objective_modes", {})
					.get("protect", {})
					.get("protect_guard_radius", 2))
			# Check whether any living echo is within guard radius of the entity.
			var _pg_guarded: bool = false
			for _pg_echo in ectx.actors:
				if not (_pg_echo is Dictionary): continue
				if bool(_pg_echo.get("is_dead", false)): continue
				if str(_pg_echo.get("faction", "")) != "echo": continue
				if GridService.chebyshev_distance(_pg_echo.get("grid_pos", {}), _pg_entity_pos) \
						<= _pg_guard_radius:
					_pg_guarded = true
					break
			if _pg_guarded:
				combat_state["protect_counter"] = int(combat_state.get("protect_counter", 0)) + 1
			else:
				# Not guarded: reset to 0 (mirrors RECOVER hold_counter reset-on-leave semantics).
				combat_state["protect_counter"] = 0
			logger.debug(t, "combat.protect.guard", "PROTECT guard progress", {
				"round":           round,
				"protect_counter": int(combat_state.get("protect_counter", 0)),
				"guarded":         _pg_guarded,
			})

	# Check end condition — pass combat_state so RECOVER/PROTECT/ENDURE checks read
	# round_counter, hold_counter, and objective_params.
	# COMBAT and PURIFY_SHRINE omit combat_state in the old call but the 3-arg form is
	# byte-identical for those modes (new branches are gated on their objective strings).
	var end_check: Dictionary = CombatState.check_end_condition(ectx.actors, ectx.resolution_mode, combat_state)
	if end_check.get("over", false):
		combat_state["combat_over"] = true
		# COMBAT-005: store result on ectx so build_snapshot() can surface it.
		# COMBAT-006: include shrine_hp in result for snapshot display.
		ectx.combat_result = {
			"victory":     bool(end_check.get("victory", false)),
			"reason":      str(end_check.get("reason", "")),
			"round_ended": round,
			"shrine_hp":   shrine_hp_val,
		}
		logger.info(t, "combat.end", "Combat ended", {
			"victory":   bool(end_check.get("victory", false)),
			"reason":    str(end_check.get("reason", "")),
			"round":     round,
			"shrine_hp": shrine_hp_val,
		})

	# Reset round-phase state — snapshot will show cta.confirm_round (or nothing if combat_over).
	combat_state["round_phase"]          = "idle"
	combat_state["current_actor_index"]  = 0
	combat_state["active_initiative_index"] = 0
	ectx.last_actor_action = {}

	# COMBAT-007: build the appropriate snapshot and persist it in-memory on ectx.
	if bool(combat_state.get("combat_over", false)):
		var _arr_victory: bool = bool(ectx.combat_result.get("victory", false))

		# V2-STAGE-002: on victory, resolve the situation AND mark objective complete BEFORE
		# the final snapshot so objectives_remaining is accurate AND the situation is not
		# re-targeted if the player returns to stage_explore.
		if _arr_victory:
			_resolve_combat_situation_and_objective(flow_ctx, t)

		# V2-VOICE-001: write arrival barks to ≤2 party echo save entries BEFORE final snapshot
		# so build_final_snapshot() can read them via echo["_sanctum_bark"].
		_select_arrival_barks_for_party(_arr_victory, t)
		# V2-VOW-002: probe benefit before final snapshot so resolve screen can include it.
		_store_vow_benefit_preview(t)
		# FinalCombatSnapshot — emits type "flow.resolve"; stored on ectx.final_snapshot.
		var final_snap: Dictionary = FlowEncounterState.build_final_snapshot(flow_ctx, t)
		ectx.final_snapshot    = final_snap
		flow_ctx.last_snapshot = final_snap
	else:
		# RoundSnapshot — emits type "flow.encounter"; stored on ectx.last_round_snapshot.
		var round_snap: Dictionary = FlowEncounterState.build_round_snapshot(flow_ctx, t)
		ectx.last_round_snapshot = round_snap
		flow_ctx.last_snapshot   = round_snap
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _apply_kill_momentum(
	source: Dictionary,
	actors: Array,
	expr_cfg: Dictionary,
	t: int
) -> void:
	if not LeadershipEmotionServiceScript.is_whole_leader(source, expr_cfg):
		return
	var traits: Array = source.get("leadership_traits", []) as Array
	if not ("kill_momentum" in traits):
		return
	var effect := LeadershipEmotionServiceScript.get_trait_effect("kill_momentum", expr_cfg)
	var morale_boost := int(effect.get("morale_boost", 0))
	var radius := LeadershipEmotionServiceScript.get_trait_radius(
		source, "kill_momentum", expr_cfg)
	var allies := LeadershipEmotionServiceScript.get_nearby_living_echo_allies(
		source, actors, radius)
	if morale_boost <= 0 or allies.is_empty():
		return
	for ally_v in allies:
		var ally: Dictionary = ally_v
		ally["morale"] = clampi(int(ally.get("morale", 50)) + morale_boost, 0, 100)
	logger.info(t, "actor.leadership.kill_momentum", "Leadership kill momentum fired", {
		"actor_id": source.get("id", ""),
		"morale_boost": morale_boost,
		"radius": radius,
		"allies_affected": allies.size(),
	})


## COMBAT-SEQ: scans initiative_order from current_actor_index forward.
## Returns the index of the next living actor, or -1 if all actors in the order have gone.
func _find_next_living_actor_idx(ectx: EncounterContext) -> int:
	var order: Array = ectx.combat_state.get("initiative_order", [])
	var start: int = int(ectx.combat_state.get("current_actor_index", 0))
	for i in range(start, order.size()):
		var aid: String = str(order[i].get("id", ""))
		var a: Dictionary = _find_actor_by_id(ectx.actors, aid)
		if not a.is_empty() and not a.get("is_dead", false):
			return i
	return -1


## Returns the first actor dict matching actor_id in the array, or {} if not found.
func _find_actor_by_id(actors: Array, actor_id: String) -> Dictionary:
	for a_v in actors:
		if a_v is Dictionary and str(a_v.get("id", "")) == actor_id:
			return a_v
	return {}


func _generate_seed_root_string() -> String:
	# Dev-safe randomness: allowed only as an input at New Game.
	# Uses OS crypto bytes, not global RNG.
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	return bytes.hex_encode()

func _legacy_root_seed_from_seed_root(seed_root: String) -> int:
	# Temporary compatibility: several MVP systems still use CampaignSeed(int).
	# Derive a deterministic int from the first 8 hex chars (32-bit).
	if seed_root.length() < 8:
		return 0
	var prefix := seed_root.substr(0, 8)
	# Parse as hex via "0x" prefix
	return int("0x" + prefix)

func _handle_debug_echo_gen_test(t: int) -> void:
	# Pull seed_root from save
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.echo.gen_test.denied", "Denied echo gen test (missing seed_root)", {})
		return

	# Pull summoning config from balance.json
	var balance := config_service.get_balance()
	var data_v : Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v : Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	# Generate same path twice
	var path0 := "campaign.summon.0"
	var e1: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)
	var e2: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)

	# Generate different path
	var path1 := "campaign.summon.1"
	var e3: Dictionary = EchoFactory.generate(seed_root, path1, 1, "summon", summ_cfg)

	var fp1 := _echo_fingerprint(e1)
	var fp2 := _echo_fingerprint(e2)
	var fp3 := _echo_fingerprint(e3)

	logger.info(t, "debug.echo.gen_test", "EchoFactory determinism test", {
		"seed_root": seed_root,
		"path_a": path0,
		"path_b": path1,
		"fingerprint_1": fp1,
		"fingerprint_2": fp2,
		"fingerprint_3": fp3,
		"same_path_equal": fp1 == fp2,
		"diff_path_differs": fp1 != fp3,
	})

	# No state transition: refresh snapshot so UI/debug panels remain in sync
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _echo_fingerprint(e: Dictionary) -> String:
	# Stable, human-readable digest for determinism checks.
	# Do NOT include id (caller assigns it).
	var name := str(e.get("name", ""))
	var gender := str(e.get("gender", ""))
	var rarity := str(e.get("rarity", ""))
	var calling := str(e.get("calling_origin", ""))
	var arch := str(e.get("archetype_birth", ""))
	var traits_v : Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var stats_v : Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	return "%s|%s|%s|%s|%s|c%dw%df%d|hp%datk%ddef%dagi%dint%dcha%d" % [
		name,
		gender,
		rarity,
		calling,
		arch,
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]

func _handle_economy_settle_time(action: Dictionary, t: int) -> void:
	var now_unix := int(action.get("now_unix", 0))
	var source := str(action.get("source", ""))
	
	if now_unix <= 0:
		logger.info(t, "economy.time_anomaly", "Denied settle (invalid now_unix)", {
			"now_unix": now_unix,
			"source": source
		})
		return
		
	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		logger.info(t, "economy.settle.denied", "No economy data in save", {
			"source": source
		})
		return
		
	var econ_data := flow_ctx.save_data["economy"] as Dictionary
	var last_settle := int(econ_data.get("last_settle_unix", now_unix))
	
	var raw_delta := now_unix - last_settle
	var delta_seconds := raw_delta
	
	# Clamp policy (MVP)
	var clamped_negative := false
	var clamped_cap := false
	
	if delta_seconds < 0:
		delta_seconds = 0
		clamped_negative = true
		
	var max_delta_seconds := _get_max_online_settle_delta_seconds()
	if delta_seconds > max_delta_seconds:
		delta_seconds = max_delta_seconds
		clamped_cap = true
	
	var note := ""
	if clamped_cap:
		note = "delta clamped to cap (likely boot catch-up; not offline accrual)"
	elif clamped_negative:
		note = "negative delta clamped to 0"
	
	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	if not _is_ase_flame_awakened():
		ase_per_min = 0.0
	var rate_per_sec := ase_per_min / 60.0
	
	# Multiplier seam (Faith later) - optional input, default 1.0
	var multiplier := float(action.get("multiplier", 1.0))
	
	# Compute gain
	var gain := EconomyAccrualService.compute_online_settle_gain(delta_seconds, rate_per_sec, multiplier)
	
	var settle_reason := "economy.settle_time.normal"
	if clamped_cap:
		settle_reason = "economy.settle_time.catch_up"
	elif clamped_negative:
		settle_reason = "economy.settle_time.anomaly"

	# Apply via EconomyService (keep logging cnetralized there)
	if gain > 0:
		# Replace this call with your EconomyService signature if different.
		econ.add_ase(gain, settle_reason, logger, t)
	var boost_gain: int = KeeperIntroServiceScript.apply_ase_boost_from_save(flow_ctx.save_data, config_service.get_balance(), delta_seconds)
	if boost_gain > 0:
		econ.add_ase(boost_gain, "keeper_intro.ase_flame_boost", logger, t)
	
	# Update settle guard even if gain=0 (prevents re-settling same window)
	econ_data["last_settle_unix"] = now_unix
	
	# Structured settle log (Core truth)
	var settle_msg := "Ase settled"
	if clamped_cap:
		settle_msg = "Ase settled (clamped)"
	elif clamped_negative:
		settle_msg = "Ase settled (time anomaly)"

	logger.debug(t, "economy.settle", settle_msg, {
		"source": source,
		"now_unix": now_unix,
		"last_settle_unix_before": last_settle,
		"raw_delta_seconds": raw_delta,
		"delta_seconds_used": delta_seconds,
		"clamped_negative": clamped_negative,
		"clamped_cap": clamped_cap,
		"cap_seconds": max_delta_seconds,
		"note": note,
		"ase_per_min_base": ase_per_min,
		"multiplier": multiplier,
		"gain": gain + boost_gain,
		"base_gain": gain,
		"boost_gain": boost_gain,
		"ase_after": int(econ_data.get("ase", 0)),
	})
	
	# V2-SANCTUM-001: piggyback emotion recovery on the bank timer settle
	_apply_emotion_recovery_if_needed(now_unix, t)

	# V2-SANCTUM-002: update institution conditions + apply bank-tick modifiers
	var _inst_cfg_b := _get_institutions_cfg()
	var _bldg_cfg_b := _get_buildings_cfg()
	if not _inst_cfg_b.is_empty():
		for _inst_id_b in InstitutionServiceScript.ALL_INSTITUTIONS:
			InstitutionServiceScript.update_condition(
				_inst_id_b, flow_ctx.save_data,
				_inst_cfg_b.get(_inst_id_b, {}) as Dictionary,
				now_unix, logger, t)
		InstitutionServiceScript.apply_institution_modifiers(
			flow_ctx.save_data, _bldg_cfg_b, _inst_cfg_b, logger, t)

	# V2-SANCTUM-002: apply passive institution effects to all roster echoes (social gravity).
	# Hearth → morale/hr for all echoes; Training Grounds → storyweight/hr for all echoes.
	var _hours_elapsed := float(delta_seconds) / 3600.0
	if _hours_elapsed > 0.0:
		InstitutionServiceScript.apply_passive_effects(
			flow_ctx.save_data, _hours_elapsed, _inst_cfg_b, logger, t)

	# IMPORTANT: settle_time can occur without a flow transition (e.g., Sanctum bank interval),
	# so we must refresh snapshot so UI updates immediately.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _is_ase_flame_awakened() -> bool:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return false
	var flame_v: Variant = (sanctum_v as Dictionary).get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	return bool(flame.get("awakened", false))
	
func _apply_offline_accrual_if_needed(t: int, source: String) -> int:
	# Offline accrual must only happen when the player enters the session (flow.continue),
	# not on boot/splash/menu. Uses OS time only here.
	var now_unix := int(Time.get_unix_time_from_system())

	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		flow_ctx.save_data["economy"] = {}
	var econ_data := flow_ctx.save_data["economy"] as Dictionary

	# V2-ECONOMY-001: gate on ase_flame.awakened — house is dormant before onboarding completes
	var _sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _sanctum_gate: Dictionary = _sanctum_v if _sanctum_v is Dictionary else {}
	var _flame_v: Variant = _sanctum_gate.get("ase_flame", {})
	var _flame_gate: Dictionary = _flame_v if _flame_v is Dictionary else {}
	if not bool(_flame_gate.get("awakened", false)):
		logger.debug(t, "economy.offline.noop", "Offline accrual skipped (house dormant)", { "source": source })
		return 0

	var last_offline := int(econ_data.get("last_offline_unix", now_unix))
	var raw_delta := now_unix - last_offline

	# Nothing to do (or suspicious backwards time)
	if raw_delta <= 0:
		if raw_delta < 0:
			logger.info(t, "economy.time_anomaly", "Offline accrual denied (time went backwards)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		else:
			logger.debug(t, "economy.offline.skip", "Offline accrual skipped (no elapsed time)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		return 0

	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	if not _is_ase_flame_awakened():
		logger.debug(t, "economy.offline.skip", "Offline accrual skipped (Ase Flame dormant)", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix": last_offline,
			"raw_delta_seconds": raw_delta
		})
		econ_data["last_offline_unix"] = now_unix
		econ_data["last_settle_unix"] = now_unix
		flow_ctx.save_request = true
		if flow_ctx.save_request_reason != "":
			flow_ctx.save_request_reason += "|economy.offline_guard"
		else:
			flow_ctx.save_request_reason = "economy.offline_guard"
		return 0

	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0
	var offline_start_factor := float(econ_cfg.get("offline_start_factor", 0.06))
	var base_offline_cap_seconds := int(econ_cfg.get("offline_cap_seconds", 151200))
	var continuity_cap_bonus_seconds := int(econ_cfg.get("offline_continuity_cap_bonus_seconds", 14400))
	var stability_cap_bonus_seconds := int(econ_cfg.get("offline_stability_cap_bonus_seconds", 7200))
	var stability_cap_penalty_seconds := int(econ_cfg.get("offline_stability_cap_penalty_seconds", 43200))
	var continuity_multiplier_bonus := float(econ_cfg.get("offline_continuity_multiplier_bonus", 0.25))
	var stability_multiplier_bonus := float(econ_cfg.get("offline_stability_multiplier_bonus", 0.15))
	var stability_multiplier_penalty := float(econ_cfg.get("offline_stability_multiplier_penalty", 0.45))
	var min_multiplier := float(econ_cfg.get("offline_min_multiplier", 0.05))
	var max_multiplier := float(econ_cfg.get("offline_max_multiplier", 1.2))
	var min_cap_seconds := int(econ_cfg.get("offline_min_cap_seconds", 108000))
	var max_cap_seconds := int(econ_cfg.get("offline_max_cap_seconds", 172800))

	var retention_ctx := _build_offline_retention_context()
	var continuity_norm := float(retention_ctx.get("continuity_norm", 0.0))
	var stability_score := float(retention_ctx.get("stability_score", 0.0))
	var continuity_bonus := continuity_norm * continuity_multiplier_bonus
	var stability_multiplier_delta := stability_score * (stability_multiplier_bonus if stability_score >= 0.0 else stability_multiplier_penalty)
	var multiplier := clampf(0.8 + continuity_bonus + stability_multiplier_delta, min_multiplier, max_multiplier)
	var cap_adjust := roundi(continuity_norm * float(continuity_cap_bonus_seconds))
	if stability_score >= 0.0:
		cap_adjust += roundi(stability_score * float(stability_cap_bonus_seconds))
	else:
		cap_adjust -= roundi(absf(stability_score) * float(stability_cap_penalty_seconds))
	var offline_cap_seconds := clampi(base_offline_cap_seconds + cap_adjust, min_cap_seconds, max_cap_seconds)

	# Clamp elapsed to the dynamic taper window. Time beyond the window carries no further charge.
	var delta_seconds := raw_delta
	var clamped_cap := false
	if offline_cap_seconds > 0 and delta_seconds > offline_cap_seconds:
		delta_seconds = offline_cap_seconds
		clamped_cap = true

	# V2-ECONOMY-001: boost stub — no-op now, extensibility hook for future bank-tick boost system
	var _boost := float(_flame_gate.get("boost_per_bank_tick", 0.0))
	multiplier += _boost


	var ase_before := int(econ_data.get("ase", 0))

	var gain := EconomyAccrualService.compute_offline_gain(
		delta_seconds,
		rate_per_sec,
		multiplier,
		offline_start_factor,
		offline_cap_seconds
	)

	# Apply via EconomyService (centralizes ledger logs)
	if gain > 0:
		econ.add_ase(gain, "economy.offline_accrual", logger, t)
		logger.debug(t, "economy.offline.apply", "Offline accrual applied", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"continuity_norm": continuity_norm,
			"stability_score": stability_score,
			"gain": gain,
			"ase_before": ase_before,
			"ase_after": int(econ_data.get("ase", 0)),
		})
	else:
		logger.debug(t, "economy.offline.noop", "Offline accrual no-op", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"continuity_norm": continuity_norm,
			"stability_score": stability_score,
			"gain": gain,
		})

	if gain > 0 or bool(retention_ctx.get("severe_disorder", false)):
		flow_ctx.pending_return_notification = _build_offline_return_notification(
			gain,
			retention_ctx,
			raw_delta,
			multiplier,
			now_unix
		)

	# Update guards ONLY here (so we don't re-award next launch)
	econ_data["last_offline_unix"] = now_unix

	# Also reset last_settle_unix so online settle doesn't mint a "catch-up" window after continue
	econ_data["last_settle_unix"] = now_unix

	# Persist via Flow boundary save policy (sanctioned boundary)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|economy.offline_accrual"
	else:
		flow_ctx.save_request_reason = "economy.offline_accrual"
	
	return gain

func _build_offline_retention_context() -> Dictionary:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var continuity_raw := clampi(int(sanctum.get("continuity", 0)), 0, 100)
	var continuity_norm := clampf(float(continuity_raw) / 100.0, 0.0, 1.0)

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var morale_total := 0.0
	var fear_total := 0.0
	var counted := 0
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		morale_total += float(int(emo.get("morale_current", 50)))
		fear_total += float(int(emo.get("fear_current", 0)))
		counted += 1

	var avg_morale := 50.0
	var avg_fear := 0.0
	if counted > 0:
		avg_morale = morale_total / float(counted)
		avg_fear = fear_total / float(counted)

	var morale_score := clampf((avg_morale - 50.0) / 50.0, -1.0, 1.0)
	var fear_score := clampf((avg_fear - 20.0) / 80.0, -1.0, 1.0)
	var emotion_score := clampf((morale_score * 0.7) - (fear_score * 0.85), -1.0, 1.0)

	var vow_v: Variant = sanctum.get("active_vow", {})
	var active_vow: Dictionary = vow_v if vow_v is Dictionary else {}
	var vow_score := 0.0
	var violation_streak := 0
	if not active_vow.is_empty():
		var streak_keys := [
			"consecutive_small_deployments",
			"consecutive_same_calling_deployments",
			"consecutive_blind_engagements",
		]
		for key: String in streak_keys:
			violation_streak = maxi(violation_streak, int(active_vow.get(key, 0)))
		if violation_streak <= 0:
			vow_score = 0.08
		elif violation_streak == 1:
			vow_score = -0.18
		else:
			vow_score = -0.55

	var stability_score := clampf(emotion_score + vow_score, -1.0, 1.0)
	var severe_disorder := violation_streak >= 2 or avg_morale <= 35.0 or avg_fear >= 70.0 or stability_score <= -0.65
	return {
		"continuity_norm": continuity_norm,
		"avg_morale": avg_morale,
		"avg_fear": avg_fear,
		"stability_score": stability_score,
		"violation_streak": violation_streak,
		"severe_disorder": severe_disorder,
	}

func _build_offline_return_notification(
	gain: int,
	retention_ctx: Dictionary,
	raw_delta_seconds: int,
	retention_multiplier: float,
	now_unix: int
) -> Dictionary:
	var severe_disorder := bool(retention_ctx.get("severe_disorder", false))
	var stability_score := float(retention_ctx.get("stability_score", 0.0))
	var title := "The Flame Held"
	var body := "A little charge remained in your absence."
	var tone := "neutral"
	if severe_disorder and gain <= 0:
		title = "The Flame Faltered"
		body = "The Sanctum could not hold much charge in your absence."
		tone = "negative"
	elif gain <= 3 or stability_score < -0.15 or retention_multiplier < 0.8:
		title = "The Flame Guttered"
		body = "Only a little charge remained while you were away."
		tone = "warning"
	elif gain >= 12 or stability_score > 0.25 or retention_multiplier >= 1.0:
		title = "The Flame Held Steady"
		body = "The Sanctum kept a faithful charge in your absence."
		tone = "positive"
	var amount := ("+%d Ase retained" % gain) if gain > 0 else "No charge was retained"
	return {
		"id":               "offline.%d.%d" % [now_unix, raw_delta_seconds],
		"title":            title,
		"body":             body,
		"detail":           "",
		"amount":           amount,
		"tone":             tone,
		"auto_dismiss":     true,
		"blocking_overlay": true,
		"duration_seconds": 4.2,
	}
	
func _get_drift_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	var drift_v: Variant = emo.get("drift", {})
	return drift_v if drift_v is Dictionary else {}


# EMOTION-002/003: applies combat win/loss morale+fear deltas + fear_base mutation + morale streak tracking.
func _apply_encounter_emotion_drift(outcome: String, t: int) -> void:
	var drift := _get_drift_cfg()
	var fear_threshold        := int(drift.get("fear_threshold",            80))
	var fear_base_per_win     := int(drift.get("fear_base_per_win",          1))
	var fear_base_per_loss    := int(drift.get("fear_base_per_loss",         1))
	var fear_base_max         := int(drift.get("fear_base_max",             40))
	var streak_threshold      := int(drift.get("morale_base_streak_threshold", 3))
	var morale_base_delta     := int(drift.get("morale_base_delta",          1))
	var morale_base_max       := int(drift.get("morale_base_max",           90))
	var morale_base_min       := int(drift.get("morale_base_min",           10))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		# Morale + fear current deltas (unchanged from EMOTION-002)
		if outcome == "win":
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_win_morale",   10)), "combat_exit_win",  logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_win_fear",      -5)), "combat_exit_win",  fear_threshold, logger, t)
		else:
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_loss_morale", -15)), "combat_exit_loss", logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_loss_fear",    20)), "combat_exit_loss", fear_threshold, logger, t)

		# EMOTION-003: mutate fear_base per outcome
		var emo := EmotionService.get_emotion(echo_v)
		var fb := int(emo.get("fear_base", 0))
		if outcome == "win":
			fb = maxi(0, fb - fear_base_per_win)
		else:
			fb = mini(fear_base_max, fb + fear_base_per_loss)
		EmotionService.set_fear_base(echo_v, fb, logger, t)

		# EMOTION-003: streak tracking for morale_base mutation
		var win_streak  := int(emo.get("win_streak",  0))
		var loss_streak := int(emo.get("loss_streak", 0))
		if outcome == "win":
			win_streak  += 1
			loss_streak  = 0
			if win_streak >= streak_threshold:
				var mb := clampi(int(emo.get("morale_base", 50)) + morale_base_delta, morale_base_min, morale_base_max)
				EmotionService.set_morale_base(echo_v, mb, logger, t)
				win_streak = 0
		else:
			loss_streak += 1
			win_streak   = 0
			if loss_streak >= streak_threshold:
				var mb := clampi(int(emo.get("morale_base", 50)) - morale_base_delta, morale_base_min, morale_base_max)
				EmotionService.set_morale_base(echo_v, mb, logger, t)
				loss_streak = 0
		# Write streak counters back directly (no setter needed — they're transient accumulators)
		echo_v["emotion"]["win_streak"]  = win_streak
		echo_v["emotion"]["loss_streak"] = loss_streak
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|encounter.emotion_drift"
	else:
		flow_ctx.save_request_reason = "encounter.emotion_drift"


# EMOTION-002/003: applies sanctum morale recovery and bidirectional fear recovery toward each echo's base.
func _apply_sanctum_emotion_tick(t: int) -> void:
	var drift := _get_drift_cfg()
	var tick_morale  := int(drift.get("sanctum_tick_morale", 2))
	# EMOTION-003: abs value used — direction determined by position relative to fear_base
	var tick_fear_abs: Variant = abs(int(drift.get("sanctum_tick_fear", -3)))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		var emo := EmotionService.get_emotion(echo_v)
		var morale_base    := int(emo.get("morale_base",    50))
		var morale_current := int(emo.get("morale_current", 50))
		# Morale: recovery only moves toward base — never above it
		if morale_current < morale_base:
			EmotionService.apply_morale_delta(echo_v, tick_morale, "sanctum_tick", logger, t)

		# EMOTION-003: Fear — bidirectional recovery toward fear_base; never overshoots
		var fear_base    := int(emo.get("fear_base",    0))
		var fear_current := int(emo.get("fear_current", 0))
		if fear_current > fear_base:
			# Too high — tick down; clamp so result doesn't go below fear_base
			var delta := -mini(tick_fear_abs, fear_current - fear_base)
			EmotionService.apply_fear_delta(echo_v, delta, "sanctum_tick", 999, logger, t)
		elif fear_current < fear_base:
			# Below base (kill euphoria) — tick back up; clamp so result doesn't exceed fear_base
			var delta := mini(tick_fear_abs, fear_base - fear_current)
			EmotionService.apply_fear_delta(echo_v, delta, "sanctum_tick", 999, logger, t)


func _get_balance_economy_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}

	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var econ_v = data.get("economy", {})
	var econ_cfg: Dictionary = econ_v as Dictionary if econ_v is Dictionary else {}

	return econ_cfg

func _get_balance_rewards_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rewards_v = data.get("rewards", {})
	return rewards_v if rewards_v is Dictionary else {}

# V2-ECONOMY-001: Count how many situations in the current stage have been revealed.
func _count_revealed_situations() -> int:
	if flow_ctx.realm_id.is_empty() or flow_ctx.stage_id.is_empty():
		return 0
	var _stage_idx := int(flow_ctx.stage_id.replace("stage.", ""))
	var _realm_v: Variant = flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {})
	var _realm: Dictionary = _realm_v if _realm_v is Dictionary else {}
	var _stages_v: Variant = _realm.get("stages", [])
	var _stages: Array = _stages_v if _stages_v is Array else []
	if _stage_idx >= _stages.size() or not _stages[_stage_idx] is Dictionary:
		return 0
	var _stage: Dictionary = _stages[_stage_idx]
	var _emap_v: Variant = _stage.get("explore_map", {})
	var _emap: Dictionary = _emap_v if _emap_v is Dictionary else {}
	var _sits_v: Variant = _emap.get("situations", [])
	var _sits: Array = _sits_v if _sits_v is Array else []
	var count := 0
	for s in _sits:
		if s is Dictionary and bool((s as Dictionary).get("revealed", false)):
			count += 1
	return count

# V2-ECONOMY-001: Get the base reward for the current stage's primary objective type.
func _get_stage_base_reward() -> int:
	var _stage_idx := int(flow_ctx.stage_id.replace("stage.", ""))
	var _realm_v: Variant = flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {})
	var _realm: Dictionary = _realm_v if _realm_v is Dictionary else {}
	var _stages_v: Variant = _realm.get("stages", [])
	var _stages: Array = _stages_v if _stages_v is Array else []
	var _obj_type := "combat"
	if _stage_idx < _stages.size() and _stages[_stage_idx] is Dictionary:
		var _stage: Dictionary = _stages[_stage_idx]
		var _objs_v: Variant = _stage.get("objectives", [])
		var _objs: Array = _objs_v if _objs_v is Array else []
		if not _objs.is_empty() and _objs[0] is Dictionary:
			_obj_type = str((_objs[0] as Dictionary).get("obj_type", "combat"))
	var _w_v: Variant = _get_balance_rewards_cfg().get("objective_weights", {})
	var _w: Dictionary = _w_v if _w_v is Dictionary else {}
	return int(_w.get(_obj_type, _w.get("combat", 30)))

# V2-ECONOMY-001: Build the scout-return resolve snapshot for retreat / return_home.
func _build_scout_return_snapshot(t: int) -> Dictionary:
	var _ase   := flow_ctx.pending_scout_return_ase
	var _intel := flow_ctx.pending_scout_return_intel_count
	var breakdown: Array = []
	if _ase > 0:
		breakdown.append({ "label": "Scout return", "delta": _ase, "currency": "ase" })

	var actor_preview: Array = []
	var _sanctum_svc := SanctumService.new(flow_ctx.save_data)
	var _party_actors := _sanctum_svc.get_party_actors()
	for _a_v in _party_actors:
		if not _a_v is Dictionary:
			continue
		var _a: Dictionary = _a_v
		var _emo_v: Variant = _a.get("emotion", {})
		var _emo: Dictionary = _emo_v if _emo_v is Dictionary else {}
		actor_preview.append({
			"id":               str(_a.get("id", "")),
			"name":             str(_a.get("name", "")),
			"calling_origin":   str(_a.get("calling_origin", "")),
			"emotional_status": EmotionService.get_emotional_status(
				int(_emo.get("morale_current", 50)),
				int(_emo.get("fear_current",   0))
			),
		})

	flow_ctx.pending_scout_return_ase         = 0
	flow_ctx.pending_scout_return_intel_count = 0

	var _intel_plural := "s" if _intel != 1 else ""
	return {
		"type": FlowStateIds.RESOLVE,
		"meta": { "sim_tick": t },
		"data": {
			"run_type":        "scout_return",
			"ase_awarded":     _ase,
			"ekwan_awarded":   0,
			"intel_count":     _intel,
			"reward_breakdown": breakdown,
			"actors":          actor_preview,
			"victory":         false,
			"rank":            "",
			# P1 CLOSE: additive fields for unified Resolve component.
			"surface":       "scout_return",
			"verdict":       "",
			"summary_line":  "%d crossing%s mapped." % [_intel, _intel_plural],
		},
		"actions": {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "Return to Sanctum",
				"slot":  "cta.continue",
			}
		}
	}
	
func _get_max_online_settle_delta_seconds() -> int:
	# Online settle guard. Offline accrual has its own capped window.
	return 3600 # 1 hour
	
func get_save_data() -> Dictionary:
	return flow_ctx.save_data

func get_tick() -> int:
	return int(flow_ctx.sim_tick)

func _ensure_encounter_started(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.ENCOUNTER:
		return
	if flow_ctx.encounter_ctx == null:
		return
	if flow_ctx.encounter_machine == null:
		return
	if not flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		return
	flow_ctx.encounter_machine.start(flow_ctx.encounter_ctx, logger, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _log_snapshot_emitted(t: int, snapshot: Dictionary, reason: String) -> void:
	# COMBAT-007: include field_count for determinism audit (LOG_SNAPSHOT_EMITTED contract).
	var data_v: Variant = snapshot.get("data", {})
	var field_count: int = data_v.size() if data_v is Dictionary else 0
	logger.debug(t, "snapshot.emitted", "Snapshot emitted", {
		"reason":        reason,
		"snapshot_type": str(snapshot.get("type", "")),
		"field_count":   field_count,
	})
	
func _get_party_max_size() -> int:
	var max_party_size := 5
	if config_service == null:
		return max_party_size

	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var s_v: Variant = data.get("sanctum", {})
	var s_cfg: Dictionary = s_v if s_v is Dictionary else {}

	return int(s_cfg.get("party_max_size", 5))
	
func _handle_sanctum_party_toggle(action: Dictionary, t: int) -> void:
	# Allow from EchoParty and Sanctum (EchoDetail party button); ignore elsewhere.
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY and snap_type != FlowStateIds.SANCTUM:
		logger.debug(t, "sanctum.party.toggle.ignored", "Party toggle ignored (outside sanctum family)", {
			"snapshot_type": snap_type
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}

	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (missing echo_id)", {})
		return

	# Ensure pending exists (should have been initialized on enter, but be defensive)
	if flow_ctx.pending_party_ids == null:
		flow_ctx.pending_party_ids = []
	if not (flow_ctx.pending_party_ids is Array):
		flow_ctx.pending_party_ids = []

	# V2-PROG-009: When toggling from flow.sanctum (EchoDetail party button), sync
	# pending_party_ids from active_party_ids so the toggle operates on the current list.
	if snap_type == FlowStateIds.SANCTUM:
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _s: Dictionary = _s_v if _s_v is Dictionary else {}
		var _ap_v: Variant = _s.get("active_party_ids", [])
		flow_ctx.pending_party_ids = (_ap_v if _ap_v is Array else []).duplicate()

	# Validate echo_id exists in roster (prevent selecting ghost ids)
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var exists := false
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			exists = true
			break

	if not exists:
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	var max_party_size := _get_party_max_size()

	# Toggle behavior
	var added := false
	if flow_ctx.pending_party_ids.has(echo_id):
		flow_ctx.pending_party_ids.erase(echo_id)
		added = false
	else:
		if flow_ctx.pending_party_ids.size() >= max_party_size:
			logger.info(t, "sanctum.party.toggle_denied", "Party is full", {
				"echo_id": echo_id,
				"max_party_size": max_party_size,
				"pending_count": flow_ctx.pending_party_ids.size()
			})
			return
		flow_ctx.pending_party_ids.append(echo_id)
		added = true

		# BOND-001: record party encounter with all current party members (before this echo was added)
		if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
			flow_ctx.save_data["sanctum"] = {}
		var bond_sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
		var enc_v = bond_sanctum.get("party_encounters", [])
		var encounters: Array = enc_v if enc_v is Array else []
		for existing_id_v in flow_ctx.pending_party_ids:
			var existing_id: String = str(existing_id_v)
			if existing_id == echo_id:
				continue
			encounters = SocialGraphService.record_encounter(encounters, echo_id, existing_id)
		bond_sanctum["party_encounters"] = encounters

	logger.debug(t, "sanctum.party.toggle", "Party toggled", {
		"echo_id": echo_id,
		"added": added,
		"pending_count": flow_ctx.pending_party_ids.size(),
		"max_party_size": max_party_size
	})

	# Immediate apply: persist selection on each toggle.
	if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["sanctum"] = {}
	var sanctum_for_save: Dictionary = flow_ctx.save_data["sanctum"]
	sanctum_for_save["active_party_ids"] = flow_ctx.pending_party_ids.duplicate()
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|sanctum.party.autosave"
	else:
		flow_ctx.save_request_reason = "sanctum.party.autosave"

	# V2-PROG-009: Rebuild the appropriate snapshot.
	# SANCTUM: full reenter so echo_detail_roster reflects updated in_party flags.
	# ECHO_PARTY: build party snapshot as before.
	if snap_type == FlowStateIds.SANCTUM:
		flow_machine.reenter(flow_ctx, logger, t)
	else:
		flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


# V2-PROG-009: Unlock a skill from the constellation skill tree.
# Validates: SANCTUM state, skill exists, calling confirmed, not already unlocked, can afford.
# Spends 40 Ase, appends skill_id to echo["unlocked_skills"], triggers save + reenter.
func _handle_sanctum_unlock_skill(action: Dictionary, t: int) -> void:
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.SANCTUM:
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id  := str(payload.get("echo_id",  "")).strip_edges()
	var skill_id := str(payload.get("skill_id", "")).strip_edges()
	if echo_id.is_empty() or skill_id.is_empty():
		return

	# Validate skill exists in config
	var balance: Dictionary = flow_ctx.config_service.get_balance()
	var bal_data_v: Variant = balance.get("data", {})
	var bal_data: Dictionary = bal_data_v if bal_data_v is Dictionary else {}
	var skills_cfg_v: Variant = bal_data.get("skills", {})
	var skills_cfg: Dictionary = skills_cfg_v if skills_cfg_v is Dictionary else {}
	var defs_v: Variant = skills_cfg.get("definitions", {})
	var defs: Dictionary = defs_v if defs_v is Dictionary else {}
	if not defs.has(skill_id):
		logger.debug(t, "sanctum.unlock_skill.denied", "Unknown skill_id", { "skill_id": skill_id })
		return

	# Find echo in roster (mutable reference — Dictionary is a reference type in GDScript)
	var echo_ref := _find_roster_echo(echo_id)
	if echo_ref.is_empty():
		return

	# Calling must be confirmed
	if SkillDefinition.get_slot_count(echo_ref, skills_cfg) < 1:
		logger.debug(t, "sanctum.unlock_skill.denied", "Calling not confirmed", { "echo_id": echo_id })
		return

	# Skill family must be accessible for the echo's calling (strong or light alignment).
	# Guards against stale / bypassed payloads that reference skills outside the calling's constellation.
	var defn: Dictionary = defs.get(skill_id, {}) as Dictionary
	var skill_family := str(defn.get("skill_family", ""))
	var echo_calling := str(echo_ref.get("calling", ""))
	var align_table_v: Variant = skills_cfg.get("calling_family_alignment", {})
	var align_table: Dictionary = align_table_v if align_table_v is Dictionary else {}
	var calling_align_v: Variant = align_table.get(echo_calling, {})
	var calling_align: Dictionary = calling_align_v if calling_align_v is Dictionary else {}
	var accessible: Array = []
	for fid_v in calling_align.get("strong", []):
		accessible.append(str(fid_v))
	for fid_v in calling_align.get("light", []):
		accessible.append(str(fid_v))
	if not skill_family.is_empty() and not accessible.is_empty() \
			and not (skill_family in accessible):
		logger.debug(t, "sanctum.unlock_skill.denied", "Skill family not accessible for calling", {
			"echo_id": echo_id, "skill_id": skill_id,
			"skill_family": skill_family, "accessible": accessible,
		})
		return

	# Not already unlocked
	var ul_v: Variant = echo_ref.get("unlocked_skills", [])
	var ul: Array = ul_v if ul_v is Array else []
	if skill_id in ul:
		logger.debug(t, "sanctum.unlock_skill.denied", "Already unlocked", { "skill_id": skill_id })
		return

	# Ase cost from unlock_conditions (defn already loaded above)
	var uc_v: Variant = defn.get("unlock_conditions", {})
	var uc: Dictionary = uc_v if uc_v is Dictionary else {}
	var ase_cost := int(uc.get("ase_cost", 0))

	# Settle time so accrued Ase is applied before the afford check
	_handle_economy_settle_time({ "type": "economy.settle_time", "now_unix": int(Time.get_unix_time_from_system()) }, t)

	if not econ.can_afford_ase(ase_cost):
		logger.debug(t, "sanctum.unlock_skill.denied", "Insufficient Ase", {
			"echo_id": echo_id, "skill_id": skill_id, "cost": ase_cost
		})
		return

	econ.spend_ase(ase_cost, "skill.unlock", logger, t)

	ul.append(skill_id)
	echo_ref["unlocked_skills"] = ul

	logger.info(t, "sanctum.skill.unlock", "Skill unlocked", {
		"echo_id": echo_id, "skill_id": skill_id, "ase_cost": ase_cost
	})

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|skill.unlock"
	else:
		flow_ctx.save_request_reason = "skill.unlock"

	flow_machine.reenter(flow_ctx, logger, t)


func _handle_weave_start_for_echo(action: Dictionary, t: int) -> void:
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY and snap_type != FlowStateIds.SANCTUM:
		logger.debug(t, "weave.start_for_echo.ignored", "weave.start_for_echo ignored outside Sanctum family", {
			"snapshot_type": snap_type,
		})
		return

	var echo_id := str(action.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Missing echo_id for rite start", {})
		return

	var echo_ref := _find_roster_echo(echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Echo not found in roster", {
			"echo_id": echo_id,
		})
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	if threads.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "No threads in reserve", {
			"echo_id": echo_id,
		})
		return

	flow_ctx.selected_weave_echo_id = echo_id
	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	flow_machine.transition(FlowStateIds.WEAVING_RITE, flow_ctx, logger, t, "ui.weave.start_for_echo")


func _handle_weave_begin_rite(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.begin_rite.ignored", "weave.begin_rite ignored outside rite state", {})
		return

	var thread_id := str(flow_ctx.selected_weave_thread_id).strip_edges()
	var echo_id := str(flow_ctx.selected_weave_echo_id).strip_edges()
	if thread_id.is_empty() or echo_id.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Missing selected thread or echo", {
			"thread_id": thread_id,
			"echo_id": echo_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var thread_v: Variant = threads.get(thread_id, {})
	if not (thread_v is Dictionary):
		logger.debug(t, "weave.begin_rite.denied", "Selected thread not found in reserve", {
			"thread_id": thread_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return
	var thread: Dictionary = thread_v

	var echo_ref := _find_roster_echo(echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Selected echo not found in roster", {
			"echo_id": echo_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var rite_cfg := _get_weaving_rite_cfg()
	var resonance_candidates: Array = WeavingRiteServiceScript.get_candidates(thread, roster, flow_ctx.save_data, rite_cfg)

	var outcome: String = WeavingRiteServiceScript.resolve_outcome(echo_ref, thread, flow_ctx.save_data, rite_cfg)
	flow_ctx.weave_commit_locked = true
	WeavingRiteServiceScript.apply_outcome(outcome, echo_id, thread_id, flow_ctx.save_data, logger, t)

	# V2-CONTINUITY-001: Thread outcome drives Continuity.
	var _cont_cfg := _get_continuity_cfg()
	if outcome == "accept":
		var _cont_pts := int(_cont_cfg.get("thread_integration_points", 5))
		ContinuityService.add_points(flow_ctx.save_data, _cont_pts, "thread.integration", logger, t)
	elif outcome == "reject":
		var _rej_base := int(_cont_cfg.get("thread_reject_base_penalty", 2))
		var _rej_max  := int(_cont_cfg.get("thread_reject_max_penalty", 10))
		ContinuityService.apply_reject_penalty(flow_ctx.save_data, echo_id, _rej_base, _rej_max, "thread.reject", logger, t)
	# "defer" → no Continuity change

	var non_chosen: Array = []
	non_chosen = WeavingRiteServiceScript.get_non_chosen_consequences(resonance_candidates, echo_id, outcome, rite_cfg)
	if not non_chosen.is_empty():
		_apply_weave_non_chosen_consequences(non_chosen, echo_id, t)

	# V2-VOICE-001: select rite bark for chosen echo.
	var _rite_ctx_key := "rite.thread_" + outcome
	var _rite_arch := str(echo_ref.get("archetype_birth", "loyal"))
	var _rite_calling := str(echo_ref.get("calling_origin", ""))
	var _rite_band := _get_expression_band_for_echo(echo_ref)
	var _rite_vk: int = (t + str(echo_id).hash()) % 997
	var _rite_line := ShoutBank.get_expression_shout(_rite_ctx_key, _rite_arch, _rite_band, _rite_calling, _rite_vk)

	flow_ctx.weave_resolution = {
		"outcome": outcome,
		"thread_id": thread_id,
		"thread_virtue": str(thread.get("virtue", "unknown")),
		"thread_quality_tier": str(thread.get("quality_tier", "broken")),
		"echo_id": echo_id,
		"echo_name": str(echo_ref.get("name", "")),
		"non_chosen": non_chosen,
		"aftermath_lines": _build_weave_aftermath_lines(outcome, echo_ref, thread, non_chosen),
		# V2-VOICE-001: rite bark line for WeavingRiteScreen outcome display.
		"echo_bark": { "line": _rite_line, "context": _rite_ctx_key },
	}

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|weave.begin_rite"
	else:
		flow_ctx.save_request_reason = "weave.begin_rite"

	flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_weave_confirm(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.confirm.ignored", "weave.confirm ignored outside rite state", {})
		return

	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.selected_weave_echo_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.weave.confirm")


func _apply_weave_non_chosen_consequences(non_chosen: Array, chosen_id: String, t: int) -> void:
	if non_chosen.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v

	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var thresholds := _get_bond_thresholds_cfg()

	var drift := _get_drift_cfg()
	var fear_threshold := int(drift.get("fear_threshold", 80))
	var applied := 0
	for c_v in non_chosen:
		if not (c_v is Dictionary):
			continue
		var c: Dictionary = c_v
		var target_id := str(c.get("echo_id", "")).strip_edges()
		if target_id.is_empty() or target_id == chosen_id:
			continue

		var echo_ref := _find_roster_echo(target_id)
		if echo_ref.is_empty():
			continue

		var morale_delta := int(c.get("morale_delta", 0))
		var fear_delta := int(c.get("fear_delta", 0))
		var bond_delta := int(c.get("bond_delta", 0))

		if morale_delta != 0:
			EmotionService.apply_morale_delta(echo_ref, morale_delta, "weave.non_chosen", logger, t)
		if fear_delta != 0:
			EmotionService.apply_fear_delta(echo_ref, fear_delta, "weave.non_chosen", fear_threshold, logger, t)
		if bond_delta != 0:
			bonds = SocialGraphService.apply_score_delta(
				bonds,
				chosen_id,
				target_id,
				bond_delta,
				thresholds,
				logger,
				t
			)
		applied += 1

	sanctum["bonds"] = bonds
	flow_ctx.save_data["sanctum"] = sanctum

	if applied > 0:
		logger.info(t, "weave.non_chosen.applied", "Applied non-chosen weave consequences", {
			"chosen_id": chosen_id,
			"affected_count": applied,
		})


func _build_weave_aftermath_lines(outcome: String, echo: Dictionary, thread: Dictionary, non_chosen: Array) -> Array:
	var echo_name := str(echo.get("name", "This echo"))
	var virtue := str(thread.get("virtue", "story"))
	var lines: Array = []
	match outcome:
		"accept":
			lines.append("%s accepts the %s thread." % [echo_name, virtue])
			lines.append("The weave settles and the reserve releases its hold.")
			if not non_chosen.is_empty():
				lines.append("The other resonant Echoes leave with tightened bonds and shaken hearts.")
		"reject":
			lines.append("%s rejects the %s thread." % [echo_name, virtue])
			lines.append("The thread is consumed in refusal, and identity is clarified.")
			if not non_chosen.is_empty():
				lines.append("Others who leaned toward this thread take the refusal personally.")
		"defer":
			lines.append("%s defers the %s thread." % [echo_name, virtue])
			lines.append("A memory mark remains; the thread returns to reserve.")
			if not non_chosen.is_empty():
				lines.append("The waiting unsettles nearby hearts, even without full rupture.")
		_:
			lines.append("The rite resolves without a clear outcome.")
	return lines


func _get_weaving_rite_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rite_v: Variant = data.get("weaving_rite", {})
	return rite_v if rite_v is Dictionary else {}


# V2-CONTINUITY-001
func _get_continuity_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var cont_v: Variant = data.get("continuity", {})
	return cont_v if cont_v is Dictionary else {}


func _get_bond_thresholds_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var thresholds_v: Variant = sanctum_cfg.get("bond_thresholds", {})
	return thresholds_v if thresholds_v is Dictionary else {}


# BOND-002: reads balance.data.sanctum.bond_triggers (all delta values).
func _get_bond_triggers_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var triggers_v: Variant = sanctum_cfg.get("bond_triggers", {})
	return triggers_v if triggers_v is Dictionary else {}


# BOND-002: reads balance.data.actor.bond_behavior (combat score bias values).
func _get_bond_behavior_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actor_v: Variant = data.get("actor", {})
	var actor_cfg: Dictionary = actor_v if actor_v is Dictionary else {}
	var behavior_v: Variant = actor_cfg.get("bond_behavior", {})
	return behavior_v if behavior_v is Dictionary else {}


# BOND-002: reads balance.data.sanctum.rival_archetypes (pairs list).
func _get_rival_archetypes_cfg() -> Array:
	if config_service == null:
		return []
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var pairs_v: Variant = sanctum_cfg.get("rival_archetypes", [])
	return pairs_v if pairs_v is Array else []


# BOND-002: reads balance.data.emotion.recovery.bonds (grief/survival modifier values).
func _get_bond_recovery_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo_cfg: Dictionary = emo_v if emo_v is Dictionary else {}
	var rec_v: Variant = emo_cfg.get("recovery", {})
	var rec_cfg: Dictionary = rec_v if rec_v is Dictionary else {}
	var bonds_v: Variant = rec_cfg.get("bonds", {})
	return bonds_v if bonds_v is Dictionary else {}


# BOND-002: Fires all stage-level bond score deltas after a combat stage ends.
# Must be called BEFORE encounter_ctx is nulled (reads ectx.actors + echo_action_logs).
func _apply_combat_bond_triggers(t: int, outcome: String) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var bond_cfg := _get_bond_triggers_cfg()
	var thresholds := _get_bond_thresholds_cfg()
	var rival_pairs_cfg := _get_rival_archetypes_cfg()

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []

	# V2-VOICE-001: snapshot pre-combat friend pairs (before any deltas are applied).
	# Used at end of function to detect newly-formed bonds.
	var _pre_friend_pair_keys: Dictionary = {}  # "id_a|id_b" → true

	var is_victory := outcome == "win"

	# Collect echo actors + classify KO'd vs surviving
	var echo_actors: Array = []
	var ko_echo_ids: Array = []
	var surviving_echo_ids: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		echo_actors.append(a)
		var aid := str(a.get("id", ""))
		if a.get("is_dead", false):
			ko_echo_ids.append(aid)
		else:
			surviving_echo_ids.append(aid)

	# Near-wipe: victory AND at least one echo KO'd (party survived but took losses)
	var near_wipe := is_victory and not ko_echo_ids.is_empty()

	# V2-VOICE-001: snapshot pre-combat friend pairs (before any bond deltas are applied).
	# Bonds array is mutated in place by apply_score_delta, so we must capture this BEFORE the loop.
	for _pre_i in range(echo_actors.size()):
		for _pre_j in range(_pre_i + 1, echo_actors.size()):
			var _pre_a_id := str((echo_actors[_pre_i] as Dictionary).get("id", ""))
			var _pre_b_id := str((echo_actors[_pre_j] as Dictionary).get("id", ""))
			var _pre_edge := SocialGraphService.get_edge(bonds, _pre_a_id, _pre_b_id)
			if not _pre_edge.is_empty():
				var _pre_str := int(_pre_edge.get("strength", 0))
				if SocialGraphService.get_bond_type(_pre_str, thresholds) == "friend":
					var _pair_key: String = _pre_a_id + "|" + _pre_b_id if _pre_a_id < _pre_b_id else _pre_b_id + "|" + _pre_a_id
					_pre_friend_pair_keys[_pair_key] = true

	# Iterate all canonical pairs of echo actors
	for i in range(echo_actors.size()):
		for j in range(i + 1, echo_actors.size()):
			var a: Dictionary = echo_actors[i]
			var b: Dictionary = echo_actors[j]
			var a_id := str(a.get("id", ""))
			var b_id := str(b.get("id", ""))

			var a_arch := str(a.get("archetype_birth", ""))
			var b_arch := str(b.get("archetype_birth", ""))
			var is_incompat := SocialGraphService.is_rival_archetype_pair(a_arch, b_arch, rival_pairs_cfg)

			# shared_combat_proximity: +1 for all pairs that shared the board
			var proximity_delta := int(bond_cfg.get("shared_combat_proximity", 1))
			bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, proximity_delta, thresholds, logger, t)

			# shared_stage_win (+3) or stage_defeat_shared (-3): all pairs, every stage
			if is_victory:
				var win_delta := int(bond_cfg.get("shared_stage_win", 3))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, win_delta, thresholds, logger, t)
			else:
				var loss_delta := int(bond_cfg.get("stage_defeat_shared", -3))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, loss_delta, thresholds, logger, t)

			# archetype_incompatible_shared_stage: -5 for incompatible archetype pairs
			if is_incompat:
				var incompat_delta := int(bond_cfg.get("archetype_incompatible_shared_stage", -5))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, incompat_delta, thresholds, logger, t)

			# ko_incompatible_no_protect: -10 if incompatible pair, one KO'd, neither guarded
			var a_ko := a_id in ko_echo_ids
			var b_ko := b_id in ko_echo_ids
			if is_incompat and (a_ko or b_ko):
				var a_guards := int(ectx.echo_action_logs.get(a_id, {}).get("guard_count", 0))
				var b_guards := int(ectx.echo_action_logs.get(b_id, {}).get("guard_count", 0))
				if a_guards == 0 and b_guards == 0:
					var incompat_ko_delta := int(bond_cfg.get("ko_incompatible_no_protect", -10))
					bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, incompat_ko_delta, thresholds, logger, t)

			# protect_action_for_ally: +8 if friend-tier pair and either guarded during stage
			var edge_now := SocialGraphService.get_edge(bonds, a_id, b_id)
			var strength_now := int(edge_now.get("strength", 0))
			var bond_type_now := SocialGraphService.get_bond_type(strength_now, thresholds)
			if bond_type_now == "friend":
				var a_guards_p := int(ectx.echo_action_logs.get(a_id, {}).get("guard_count", 0))
				var b_guards_p := int(ectx.echo_action_logs.get(b_id, {}).get("guard_count", 0))
				if a_guards_p > 0 or b_guards_p > 0:
					var protect_delta := int(bond_cfg.get("protect_action_for_ally", 8))
					bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, protect_delta, thresholds, logger, t)

			# witnessed_ally_sacrifice: +12 when one bonded (non-neutral) echo was KO'd
			if (a_ko or b_ko) and not (a_ko and b_ko):
				var edge_sac := SocialGraphService.get_edge(bonds, a_id, b_id)
				if not edge_sac.is_empty():
					var strength_sac := int(edge_sac.get("strength", 0))
					var bond_type_sac := SocialGraphService.get_bond_type(strength_sac, thresholds)
					if bond_type_sac != "neutral":
						var sac_delta := int(bond_cfg.get("witnessed_ally_sacrifice", 12))
						bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, sac_delta, thresholds, logger, t)

			# near_wipe_survival_together: +10 if victory, ≥1 KO'd elsewhere, both in this pair survived
			if near_wipe and not a_ko and not b_ko:
				var nw_delta := int(bond_cfg.get("near_wipe_survival_together", 10))
				bonds = SocialGraphService.apply_score_delta(bonds, a_id, b_id, nw_delta, thresholds, logger, t)

	# V2-VOICE-001: detect newly-formed friend bonds (crossed threshold this combat).
	# Compare post-combat friend pairs against the pre-combat snapshot captured above.
	var _new_friend_pairs: Array = []
	for _i in range(echo_actors.size()):
		for _j in range(_i + 1, echo_actors.size()):
			var _fa: Dictionary = echo_actors[_i]
			var _fb: Dictionary = echo_actors[_j]
			var _fa_id := str(_fa.get("id", ""))
			var _fb_id := str(_fb.get("id", ""))
			var _edge := SocialGraphService.get_edge(bonds, _fa_id, _fb_id)
			if _edge.is_empty():
				continue
			var _str_now := int(_edge.get("strength", 0))
			var _bond_now := SocialGraphService.get_bond_type(_str_now, thresholds)
			if _bond_now == "friend":
				var _pair_key: String = _fa_id + "|" + _fb_id if _fa_id < _fb_id else _fb_id + "|" + _fa_id
				if not _pre_friend_pair_keys.has(_pair_key):
					_new_friend_pairs.append([_fa, _fb])

	sanctum["bonds"] = bonds
	flow_ctx.save_data["sanctum"] = sanctum
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason.is_empty():
		flow_ctx.save_request_reason = "bond.combat_triggers"
	else:
		flow_ctx.save_request_reason += "|bond.combat_triggers"

	logger.info(t, "bond.combat_triggers.applied", "Combat bond triggers fired", {
		"outcome":           outcome,
		"echo_count":        echo_actors.size(),
		"ko_count":          ko_echo_ids.size(),
		"near_wipe":         near_wipe,
	})

	# V2-VOICE-001: write bond_formed barks for newly-formed friend pairs.
	var _roster_v2: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	var _roster_arr: Array = _roster_v2 if _roster_v2 is Array else []
	for _pair_v in _new_friend_pairs:
		var _pair: Array = _pair_v
		if _pair.size() < 2:
			continue
		_select_sanctum_bark_for_actor_and_write(_pair[0], "sanctum.bond_formed", t, _roster_arr)
		_select_sanctum_bark_for_actor_and_write(_pair[1], "sanctum.bond_formed", t, _roster_arr)
		logger.debug(t, "voice.bond_formed_bark", "Bond formed bark written", {
			"actor_a": str((_pair[0] as Dictionary).get("id", "")),
			"actor_b": str((_pair[1] as Dictionary).get("id", "")),
		})
	if not _new_friend_pairs.is_empty():
		var _sanctum_mut: Variant = flow_ctx.save_data.get("sanctum", {})
		if _sanctum_mut is Dictionary:
			(_sanctum_mut as Dictionary)["roster"] = _roster_arr


# BOND-002: Applies EmotionRecoveryService modifiers to surviving roster echoes after combat.
# Grief: bonded echo (non-neutral) was KO'd → slowed morale recovery, heightened fear recovery.
# Shared survival bonus: near-wipe victory AND bonded friend also survived → improved recovery.
# Must be called BEFORE encounter_ctx is nulled.
func _apply_bond_aftermath_modifiers(t: int, outcome: String) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var thresholds := _get_bond_thresholds_cfg()
	var bond_rec_cfg := _get_bond_recovery_cfg()
	if bond_rec_cfg.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var is_victory := outcome == "win"

	# Collect KO'd and surviving echo IDs from encounter actors
	var ko_ids: Array = []
	var surviving_ids: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		var aid := str(a.get("id", ""))
		if a.get("is_dead", false):
			ko_ids.append(aid)
		else:
			surviving_ids.append(aid)

	var near_wipe := is_victory and not ko_ids.is_empty()

	# Apply modifiers to surviving roster echoes (not runtime actor dicts)
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var echo_id := str(echo.get("id", ""))
		if not (echo_id in surviving_ids):
			continue

		# Grief: check if any bonded (non-neutral) echo was KO'd
		var bonded_ko := false
		for ko_id in ko_ids:
			var edge := SocialGraphService.get_edge(bonds, echo_id, ko_id)
			if edge.is_empty():
				continue
			var strength := int(edge.get("strength", 0))
			if SocialGraphService.get_bond_type(strength, thresholds) != "neutral":
				bonded_ko = true
				break

		if bonded_ko:
			var grief_morale_mul := float(bond_rec_cfg.get("grief_morale_mul", 0.5))
			var grief_fear_mul   := float(bond_rec_cfg.get("grief_fear_mul",   1.5))
			var grief_ticks      := int(bond_rec_cfg.get("grief_ticks",        3))
			EmotionRecoveryService.set_modifier(echo, grief_morale_mul, grief_fear_mul, grief_ticks, logger, t)
		elif near_wipe:
			# Shared survival bonus: bonded friend also survived the near-wipe
			var bonded_friend_survived := false
			for surv_id in surviving_ids:
				if surv_id == echo_id:
					continue
				var edge := SocialGraphService.get_edge(bonds, echo_id, surv_id)
				if edge.is_empty():
					continue
				var strength := int(edge.get("strength", 0))
				if SocialGraphService.get_bond_type(strength, thresholds) == "friend":
					bonded_friend_survived = true
					break
			if bonded_friend_survived:
				var surv_morale_mul := float(bond_rec_cfg.get("shared_survival_morale_mul", 1.5))
				var surv_fear_mul   := float(bond_rec_cfg.get("shared_survival_fear_mul",   0.7))
				var surv_ticks      := int(bond_rec_cfg.get("shared_survival_ticks",         2))
				EmotionRecoveryService.set_modifier(echo, surv_morale_mul, surv_fear_mul, surv_ticks, logger, t)


# BOND-002: Seeds rival_incidents[] for V2-SANCTUM-005 (incident system).
# For each rival-tier pair among encounter actors: appends canonical [a_id, b_id] if not present.
# Must be called BEFORE encounter_ctx is nulled.
func _seed_rival_stage_incidents(t: int) -> void:
	if flow_ctx.encounter_ctx == null:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx

	var thresholds := _get_bond_thresholds_cfg()

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var incidents_v: Variant = sanctum.get("rival_incidents", [])
	var incidents: Array = incidents_v if incidents_v is Array else []

	# Collect echo actor IDs from this encounter
	var echo_ids: Array = []
	for a_v in ectx.actors:
		if a_v is Dictionary and str(a_v.get("faction", "")) == "echo":
			echo_ids.append(str(a_v.get("id", "")))

	var added := 0
	for i in range(echo_ids.size()):
		for j in range(i + 1, echo_ids.size()):
			var a_id: String = echo_ids[i]
			var b_id: String = echo_ids[j]
			var edge := SocialGraphService.get_edge(bonds, a_id, b_id)
			if edge.is_empty():
				continue
			var strength := int(edge.get("strength", 0))
			if SocialGraphService.get_bond_type(strength, thresholds) != "rival":
				continue
			# Canonical pair (alphabetical)
			var pair: Array = [a_id, b_id] if a_id < b_id else [b_id, a_id]
			var already_seeded := false
			for inc_v in incidents:
				if (inc_v is Array) and (inc_v as Array).size() >= 2:
					var inc: Array = inc_v
					if str(inc[0]) == pair[0] and str(inc[1]) == pair[1]:
						already_seeded = true
						break
			if not already_seeded:
				incidents.append(pair)
				added += 1

	if added > 0:
		sanctum["rival_incidents"] = incidents
		flow_ctx.save_data["sanctum"] = sanctum
		flow_ctx.save_request = true
		if flow_ctx.save_request_reason.is_empty():
			flow_ctx.save_request_reason = "bond.rival_incidents"
		else:
			flow_ctx.save_request_reason += "|bond.rival_incidents"
		logger.info(t, "bond.rival_incidents.seeded", "Rival incident seeds written", {
			"added": added,
			"total": incidents.size(),
		})


## PROG-001: one-time repair pass for echo fields added after draw-order v1.
## Called on flow.continue — patches roster echoes missing class_origin / level.
## If any echoes were patched, requests a save flush so defaults persist.
func _repair_echo_schema(t: int) -> void:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var patched_count := 0
	for e_v in roster:
		if e_v is Dictionary:
			if EchoFactory.repair_echo_fields(e_v):
				patched_count += 1

	if patched_count > 0:
		flow_ctx.save_request = true
		if flow_ctx.save_request_reason != "":
			flow_ctx.save_request_reason += "|sanctum.schema.repair"
		else:
			flow_ctx.save_request_reason = "sanctum.schema.repair"
		logger.info(t, "sanctum.schema.repair", "Repaired old echo fields", {
			"patched": patched_count,
			"roster_size": roster.size()
		})

# PROG-004: Executes Keeper-confirmed rank-up for a single echo.
# Valid from ECHO_PARTY snapshots.
func _handle_sanctum_rank_up(action: Dictionary, t: int) -> void:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.rank_up.ignored", "Rank-up ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (missing echo_id)", {})
		return

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	var echo_idx: int = -1
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			echo_idx = i
			break

	if echo_idx == -1:
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	# Read prog_cfg and calling_cfg from balance.json.
	var prog_cfg_v: Variant = {}
	var birth_stats_v: Variant = {}
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		prog_cfg_v    = bd.get("progression", {})
		birth_stats_v = bd.get("summoning", {}).get("birth_stats", {})
		calling_cfg_v = bd.get("calling", {})
	var prog_cfg: Dictionary    = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var birth_stats: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Guard: must be eligible.
	if not ProgressionService.is_rank_up_eligible(echo_ref, prog_cfg):
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (not eligible)", {
			"echo_id": echo_id,
			"level": int(echo_ref.get("level", 1)),
			"rank":  int(echo_ref.get("rank", 1)),
		})
		return

	# Execute rank-up — mutates echo_ref in place (roster[echo_idx] is the same ref).
	var event: Dictionary = ProgressionService.execute_rank_up(
		echo_ref,
		flow_ctx.campaign_seed,
		prog_cfg,
		birth_stats,
		calling_cfg,
		logger,
		t
	)

	# Persist.
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|progression.rank_up"
	else:
		flow_ctx.save_request_reason = "progression.rank_up"

	# V2-VOICE-001: write progress.rank_up bark to the echo's save entry.
	var _ru_roster_v: Variant = sanctum.get("roster", [])
	var _ru_roster: Array = _ru_roster_v if _ru_roster_v is Array else []
	_select_sanctum_bark_for_echo_data_and_write(echo_ref, "progress.rank_up", t, _ru_roster)
	sanctum["roster"] = _ru_roster
	flow_ctx.save_data["sanctum"] = sanctum

	# Rebuild EchoParty snapshot with updated roster data.
	flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)

	# Attach the rank-up event to the snapshot data so the UI can drive the reveal overlay.
	if flow_ctx.last_snapshot.has("data") and flow_ctx.last_snapshot["data"] is Dictionary:
		flow_ctx.last_snapshot["data"]["rank_up_event"] = event


# PROG-007: Confirms a Keeper-chosen calling for an echo.
# Valid from ECHO_PARTY snapshots.
func _handle_sanctum_calling_confirm(action: Dictionary, t: int) -> void:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.calling.ignored", "Calling confirm ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	var chosen_calling_id: String = str(payload.get("chosen_calling_id", "")).strip_edges()

	if echo_id.is_empty() or chosen_calling_id.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (missing echo_id or chosen_calling_id)", {})
		return

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			break

	if echo_ref.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	# Guard: must have a calling pending (calling_eligible=true and no calling set yet).
	if not CallingService.is_calling_pending(echo_ref):
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (no calling pending)", {
			"echo_id":         echo_id,
			"calling_eligible": bool(echo_ref.get("calling_eligible", false)),
			"calling":         str(echo_ref.get("calling", "")),
		})
		return

	# Read calling_cfg from balance.json.
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		calling_cfg_v = bal.get("data", {}).get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Confirm the calling — mutates echo_ref in place.
	var confirmed: String = CallingService.confirm_calling(echo_ref, chosen_calling_id, calling_cfg, logger, t)
	if confirmed.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (invalid chosen_calling_id)", {
			"echo_id":           echo_id,
			"chosen_calling_id": chosen_calling_id,
		})
		return

	# Persist.
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|progression.calling.confirm"
	else:
		flow_ctx.save_request_reason = "progression.calling.confirm"

	# V2-VOICE-001: write calling_settled bark to the echo's save entry.
	var _cs_roster_v: Variant = (flow_ctx.save_data.get("sanctum", {}) as Dictionary).get("roster", [])
	var _cs_roster: Array = _cs_roster_v if _cs_roster_v is Array else []
	_select_sanctum_bark_for_echo_data_and_write(echo_ref, "sanctum.calling_settled", t, _cs_roster)
	var _cs_sanctum_m: Variant = flow_ctx.save_data.get("sanctum", {})
	if _cs_sanctum_m is Dictionary:
		(_cs_sanctum_m as Dictionary)["roster"] = _cs_roster

	# Rebuild EchoParty snapshot.
	flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)

	# Attach calling_event so UI can react (clear pending indicator, etc.).
	if flow_ctx.last_snapshot.has("data") and flow_ctx.last_snapshot["data"] is Dictionary:
		flow_ctx.last_snapshot["data"]["calling_event"] = {
			"echo_id":    echo_id,
			"calling":    confirmed,
		}


# V2-DIRECTIVE-001: writes the chosen directive to stage_context, requests save, refreshes snapshot.
func _handle_directive_select(action: Dictionary, t: int) -> void:
	var id := str(action.get("directive_id", ""))
	directive_service.set_active_directive(id, logger, t)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|directive.select"
	else:
		flow_ctx.save_request_reason = "directive.select"
	# Lesson 9: non-SANCTUM states read ctx.last_snapshot as-is on refresh.
	# STAGE uses static build_snapshot() — rebuild before refresh so snapshot reflects the new choice.
	if flow_ctx.last_snapshot.get("type", "") == FlowStateIds.STAGE:
		flow_ctx.last_snapshot = FlowStageState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ── XP tuning helpers (ST5) ──────────────────────────────────────────────────

## Returns the save_data roster entry for the given echo_id, or {} if not found.
func _find_roster_echo(echo_id: String) -> Dictionary:
	if echo_id.is_empty():
		return {}
	var sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not sanc_v is Dictionary:
		return {}
	var roster_v: Variant = (sanc_v as Dictionary).get("roster", [])
	if not roster_v is Array:
		return {}
	for entry_v in roster_v:
		if entry_v is Dictionary and str(entry_v.get("id", "")) == echo_id:
			return entry_v as Dictionary
	return {}


## PROG-009: Assigns a skill to an echo slot while on STAGE_MAP party prep.
## Updates flow_ctx.pending_equipped_skills and rebuilds the STAGE_MAP snapshot.
func _handle_skill_assign(action: Dictionary, t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.assign.ignored", "skill.assign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id  := str(payload.get("echo_id",  "")).strip_edges()
	var slot     := str(payload.get("slot",     "0")).strip_edges()
	var skill_id := str(payload.get("skill_id", "")).strip_edges()

	if echo_id.is_empty() or skill_id.is_empty():
		logger.debug(t, "skill.assign.denied", "skill.assign missing echo_id or skill_id", { "payload": payload })
		return

	if not flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id] = {}
	flow_ctx.pending_equipped_skills[echo_id][slot] = skill_id

	logger.debug(t, "skill.assign", "Skill assigned", {
		"echo_id": echo_id, "slot": slot, "skill_id": skill_id
	})
	flow_ctx.last_snapshot = FlowStageMapState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## PROG-009: Unassigns a skill from an echo slot while on STAGE_MAP party prep.
func _handle_skill_unassign(action: Dictionary, t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.unassign.ignored", "skill.unassign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	var slot    := str(payload.get("slot",    "0")).strip_edges()

	if echo_id.is_empty():
		logger.debug(t, "skill.unassign.denied", "skill.unassign missing echo_id", {})
		return

	if flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id].erase(slot)

	logger.debug(t, "skill.unassign", "Skill unassigned", {
		"echo_id": echo_id, "slot": slot
	})
	flow_ctx.last_snapshot = FlowStageMapState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## PROG-009: Persists pending_equipped_skills to each echo in the roster and flags a save.
## Called by flow.select_stage (on cta.enter_stage) before transitioning to STAGE.
func _persist_equipped_skills(t: int) -> void:
	if flow_ctx.pending_equipped_skills.is_empty():
		return

	var sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanc_v if sanc_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	for echo_id in flow_ctx.pending_equipped_skills.keys():
		var eq: Dictionary = flow_ctx.pending_equipped_skills[echo_id]
		for i in range(roster.size()):
			var e: Dictionary = roster[i] if roster[i] is Dictionary else {}
			if str(e.get("id", "")) == str(echo_id):
				roster[i]["equipped_skills"] = eq.duplicate()
				break

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|skill.persist"
	else:
		flow_ctx.save_request_reason = "skill.persist"

	logger.info(t, "skill.persist", "Equipped skills persisted to save", {
		"equipped_count": flow_ctx.pending_equipped_skills.size()
	})


## Returns the realm XP multiplier for the current realm based on run_index.
## Reads realm_id from flow_ctx and run_index from save_data["realms"].
## Returns 1.0 on any guard failure.
func _get_realm_xp_multiplier() -> float:
	if flow_ctx == null:
		return 1.0
	var realm_id: String = str(flow_ctx.realm_id)
	if realm_id.is_empty():
		return 1.0
	var prog_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		prog_cfg_v = bd.get("progression", {})
	var prog_cfg_r: Dictionary = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var rate: float = float(prog_cfg_r.get("realm_xp_multiplier_per_realm", 0.0))
	if rate <= 0.0:
		return 1.0
	var realms_v: Variant = flow_ctx.save_data.get("realms", {})
	if not realms_v is Dictionary:
		return 1.0
	var realm_entry_v: Variant = (realms_v as Dictionary).get(realm_id, {})
	if not realm_entry_v is Dictionary:
		return 1.0
	var run_idx: int = int((realm_entry_v as Dictionary).get("run_index", 0))
	return 1.0 + float(run_idx) * rate


# ---------------------------------------------------------------------------
# V2-SANCTUM-002 institution handlers
# ---------------------------------------------------------------------------

func _handle_sanctum_institution_establish(action: Dictionary, t: int) -> void:
	var payload: Dictionary = action.get("payload", {})
	var inst_id := str(payload.get("institution_id", ""))
	if inst_id.is_empty():
		return
	var pos_dict_v: Variant = payload.get("position", { "x": 0, "y": 0 })
	var pos_dict: Dictionary = pos_dict_v if pos_dict_v is Dictionary else { "x": 0, "y": 0 }
	var position := Vector2i(int(pos_dict.get("x", 0)), int(pos_dict.get("y", 0)))
	var inst_cfg := _get_institutions_cfg()
	if InstitutionServiceScript.establish(inst_id, flow_ctx.save_data, econ, inst_cfg, logger, t, position):
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "institution.establish"
		# reenter() re-runs FlowSanctumState.enter() so sanctum_layout + sanctum_occupants
		# reflect the newly established institution before refresh_snapshot() emits the UI update.
		flow_machine.reenter(flow_ctx, logger, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_sanctum_institution_assign_echo(action: Dictionary, t: int) -> void:
	var payload   := action.get("payload", {}) as Dictionary
	var inst_id   := str(payload.get("institution_id", ""))
	var echo_id   := str(payload.get("echo_id", ""))
	if inst_id.is_empty() or echo_id.is_empty():
		return
	var inst_cfg := _get_institutions_cfg()
	if InstitutionServiceScript.assign_echo(inst_id, echo_id, flow_ctx.save_data, econ, inst_cfg, logger, t):
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "institution.assign_echo"
		flow_machine.reenter(flow_ctx, logger, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_sanctum_institution_remove_echo(action: Dictionary, t: int) -> void:
	var payload := action.get("payload", {}) as Dictionary
	var inst_id := str(payload.get("institution_id", ""))
	var echo_id := str(payload.get("echo_id", ""))
	if inst_id.is_empty() or echo_id.is_empty():
		return
	var inst_cfg := _get_institutions_cfg()
	if InstitutionServiceScript.remove_echo(inst_id, echo_id, flow_ctx.save_data, econ, inst_cfg, logger, t):
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "institution.remove_echo"
		flow_machine.reenter(flow_ctx, logger, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _get_institutions_cfg() -> Dictionary:
	var data_v: Variant = config_service.get_balance().get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var inst_v: Variant = data.get("institutions", {})
	return inst_v if inst_v is Dictionary else {}


func _get_buildings_cfg() -> Dictionary:
	var data_v: Variant = config_service.get_balance().get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emotion_v: Variant = (data.get("emotion", {}) as Dictionary).get("recovery", {})
	var recovery: Dictionary = emotion_v if emotion_v is Dictionary else {}
	var bldg_v: Variant = recovery.get("buildings", {})
	return bldg_v if bldg_v is Dictionary else {}


# ---------------------------------------------------------------------------
# VOW-001 handlers
# ---------------------------------------------------------------------------

func _handle_vow_pledge(action: Dictionary, t: int) -> void:
	var vow_id := str(action.get("vow_id", ""))
	var tier   := int(action.get("tier", 1))

	if vow_id.is_empty():
		logger.debug(t, "vow.pledge_denied", "Missing vow_id in action", { "action": action })
		flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var cfg := config_service.get_balance()
	var ok := VowService.pledge_vow(vow_id, tier, cfg, flow_ctx.save_data, flow_ctx, logger, t)
	# Rebuild snapshot from current save_data so UI reflects the pledge outcome.
	# refresh_snapshot() reads ctx.last_snapshot as-is for non-SANCTUM states — must
	# assign the rebuilt snapshot first (same pattern as FlowSummonState.build_snapshot).
	flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
	if ok:
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
	else:
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_vow_break(t: int) -> void:
	var cfg := config_service.get_balance()

	var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
	if summary.is_empty():
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# Apply morale/fear deltas + EmotionRecovery modifier to all roster echoes.
	_apply_vow_break_aftermath(summary, cfg, t)

	# Rebuild snapshot from current save_data so UI reflects the break outcome.
	flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_debug_vow_unlock(action: Dictionary, t: int) -> void:
	var vow_id := str(action.get("vow_id", ""))
	if vow_id.is_empty():
		push_warning("debug.vow.unlock: missing vow_id")
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return
	VowService.unlock_vow(vow_id, "debug", flow_ctx.save_data, flow_ctx, logger, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# VOW-001: Check if any vow was discovered by a scenario condition during this stage.
# Called from _handle_complete_stage after stage data is finalized.
func _check_vow_discovery(t: int) -> void:
	var cfg := config_service.get_balance()
	var defs := VowService.get_definitions(cfg)
	if defs.is_empty():
		return

	var unlocked := VowService.get_unlocked_vows(flow_ctx.save_data)

	# Determine combat outcome from the final resolve snapshot.
	var _last_snap_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
	var _last_snap_data: Dictionary = _last_snap_data_v if _last_snap_data_v is Dictionary else {}
	var is_victory := bool(_last_snap_data.get("victory", false))

	# Collect party actor dicts from ectx.actors — use runtime actors (not save roster) so
	# is_dead reflects actual combat deaths (is_dead is runtime-only, never written to save).
	# ectx is still non-null here; it is nulled immediately after _check_vow_discovery returns.
	var party_ids: Array = []
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if sanctum_v is Dictionary:
		var p_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v

	var party_actors: Array = []
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		for a_v in ectx.actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if str(a.get("faction", "")) == "echo" and party_ids.has(str(a.get("id", ""))):
				party_actors.append(a)

	# Gather current stage situations (already updated by situation write-back before this call).
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v

	for vow_id in defs:
		if unlocked.has(vow_id):
			continue
		var defn_v: Variant = defs[vow_id]
		if not (defn_v is Dictionary):
			continue
		var scenario := str((defn_v as Dictionary).get("unlock_scenario", ""))
		if VowService.evaluate_discovery_scenario(scenario, party_actors, situations, is_victory):
			VowService.unlock_vow(vow_id, flow_ctx.realm_id, flow_ctx.save_data, flow_ctx, logger, t)
			# V2-VOW-002: record in session list for "Discovered" badge and ResolveScreen reveal.
			# and "Discovered" badge on VowScreen. Resets on new FlowContext (new boot).
			var _disc_defn := VowService.get_definition(vow_id, cfg)
			if not _disc_defn.is_empty():
				flow_ctx.session_unlocked_vows.append({
					"vow_id":      vow_id,
					"vow_name":    str(_disc_defn.get("vow_name", "")),
					"proverb_twi": str(_disc_defn.get("proverb_twi", "")),
					"proverb_en":  str(_disc_defn.get("proverb_en", "")),
				})


# VOW-001 / V2-VOW-002: Apply stage-entry vow condition (party size / calling diversity).
# Called from flow.go_state → STAGE_EXPLORE (covers first entry and re-entry after defeat).
func _apply_vow_stage_entry_condition(t: int) -> void:
	# V2-VOW-002: tick guard — prevents double-fire if two paths both route through STAGE_EXPLORE.
	if t == flow_ctx.vow_entry_check_t:
		return
	flow_ctx.vow_entry_check_t = t

	# V2-VOW-002: clear transient state from previous stage entry.
	flow_ctx.vow_outcome = {}
	flow_ctx.session_broken_vow_effect = {}
	# Also clear the persisted debuff chip from save_data.
	var _clear_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _clear_sanc_v is Dictionary:
		(_clear_sanc_v as Dictionary).erase("pending_broken_vow_effect")

	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	var cfg: Dictionary = config_service.get_balance()
	var result := VowService.evaluate_stage_condition(flow_ctx.save_data, party_ids, cfg)

	var status := str(result.get("status", "none"))
	if status == "none":
		return

	# V2-VOW-002: on compliant entry, increment compliance_count + lifetime honors.
	if status == "compliant":
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		if _s_v is Dictionary:
			var _av_s: Dictionary = (_s_v as Dictionary).get("active_vow", {})
			if not _av_s.is_empty():
				var _new_count := int(_av_s.get("compliance_count", 0)) + 1
				_av_s["compliance_count"] = _new_count
				(_s_v as Dictionary)["active_vow"] = _av_s
				flow_ctx.save_data["sanctum"] = _s_v
			# Increment lifetime vow_stats.honors (direct index — .get() returns a temp copy).
			var _sanc_h: Dictionary = _s_v as Dictionary
			if not _sanc_h.has("vow_stats") or not (_sanc_h["vow_stats"] is Dictionary):
				_sanc_h["vow_stats"] = {"honors": 0, "breaks": 0}
			var _vstats_h: Dictionary = _sanc_h["vow_stats"]
			_vstats_h["honors"] = int(_vstats_h.get("honors", 0)) + 1
		# Store vow_outcome for the ResolveScreen (compliant event).
		if flow_ctx.vow_outcome.is_empty():
			var _vow_id := str(av.get("vow_id", ""))
			var _defn   := VowService.get_definition(_vow_id, cfg)
			flow_ctx.vow_outcome = {
				"event":       "compliant",
				"vow_id":      _vow_id,
				"vow_name":    str(_defn.get("vow_name", "")),
				"tier":        int(av.get("tier", 1)),
				"morale_delta": int(result.get("morale_delta", 0)),
				"fear_delta":   int(result.get("fear_delta", 0)),
				"compliance_count": int(flow_ctx.save_data.get("sanctum", {})
					.get("active_vow", {}).get("compliance_count", 0)),
			}

	# Apply morale / fear deltas to all party echoes
	var morale_d := int(result.get("morale_delta", 0))
	var fear_d   := int(result.get("fear_delta", 0))
	_apply_vow_emotion_to_party(party_ids, morale_d, fear_d, "vow.condition." + status, cfg, t)

	# V2-VOW-002: compliance tracking — increment count and record outcome for resolve screen.
	if status == "compliant":
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _new_count := 0
		if _s_v is Dictionary:
			var _av_s: Dictionary = (_s_v as Dictionary).get("active_vow", {})
			if not _av_s.is_empty():
				_new_count = int(_av_s.get("compliance_count", 0)) + 1
				_av_s["compliance_count"] = _new_count
				(_s_v as Dictionary)["active_vow"] = _av_s
		# Store compliant vow_outcome only if break hasn't already set it (break takes precedence).
		if flow_ctx.vow_outcome.is_empty():
			var _av_c := VowService.get_active_vow(flow_ctx.save_data)
			var _defn_c := VowService.get_definition(str(_av_c.get("vow_id", "")), cfg)
			flow_ctx.vow_outcome = {
				"event":            "compliant",
				"vow_id":           str(_av_c.get("vow_id", "")),
				"vow_name":         str(_defn_c.get("vow_name", "")),
				"proverb_twi":      str(_defn_c.get("proverb_twi", "")),
				"tier":             int(_av_c.get("tier", 1)),
				"morale_delta":     morale_d,
				"fear_delta":       0,
				"bond_score_delta": 0,
				"ase_delta":        0,
				"echoes_affected":  party_ids,
				"compliance_count": _new_count,
			}

	# V2-VOICE-001: vow stage-entry bark from party leader (or first party echo).
	if status in ["benefit", "penalty"]:
		var _vow_bark_ctx := "vow." + status
		var _vow_roster_v: Variant = sanctum.get("roster", [])
		var _vow_roster: Array = _vow_roster_v if _vow_roster_v is Array else []
		# Find party leader (first echo in active_party_ids that is in roster).
		var _vow_speaker: Dictionary = {}
		for _pid in party_ids:
			for _re in _vow_roster:
				if _re is Dictionary and str((_re as Dictionary).get("id", "")) == str(_pid):
					_vow_speaker = _re
					break
			if not _vow_speaker.is_empty():
				break
		if not _vow_speaker.is_empty():
			_select_sanctum_bark_for_echo_data_and_write(_vow_speaker, _vow_bark_ctx, t, _vow_roster)
			sanctum["roster"] = _vow_roster
			flow_ctx.save_data["sanctum"] = sanctum

	var should_break := bool(result.get("should_auto_break", false))

	var log_type := "vow.condition.auto_break" if should_break else ("vow.condition." + status)
	logger.info(t, log_type, "Vow stage condition evaluated", {
		"vow_id":      str(av.get("vow_id", "")),
		"status":      status,
		"party_size":  party_ids.size(),
		"auto_break":  should_break,
	})
	flow_ctx.save_request = true

	if should_break:
		var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
		if not summary.is_empty():
			_apply_vow_break_aftermath(summary, cfg, t)


# VOW-001: Apply situation-engagement vow condition (obi_nnim_kyere revealed check).
# sit_was_revealed: captured BEFORE the engagement mutation sets revealed=true.
func _apply_vow_engage_condition(sit_was_revealed: bool, t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	# Build a minimal situation dict reflecting the pre-engagement revealed state.
	var sit_peek := { "revealed": sit_was_revealed }
	var cfg := config_service.get_balance()
	var result := VowService.evaluate_engage_condition(
		flow_ctx.save_data, sit_peek, flow_ctx.stage_id, cfg
	)

	var status := str(result.get("status", "none"))
	if status == "none":
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var party_ids: Array = []
	if sanctum_v is Dictionary:
		var party_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if party_v is Array:
			party_ids = party_v

	var morale_d := int(result.get("morale_delta", 0))
	var fear_d   := int(result.get("fear_delta", 0))
	_apply_vow_emotion_to_party(party_ids, morale_d, fear_d, "vow.engage." + status, cfg, t)

	var should_break := bool(result.get("should_auto_break", false))
	logger.info(t, "vow.engage." + status, "Vow engage condition evaluated", {
		"vow_id":     str(av.get("vow_id", "")),
		"status":     status,
		"revealed":   sit_was_revealed,
		"auto_break": should_break,
	})
	flow_ctx.save_request = true

	if should_break:
		var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
		if not summary.is_empty():
			_apply_vow_break_aftermath(summary, cfg, t)


# VOW-001: Apply post-stage completion vow benefit (obi_nnim_kyere full-scout bonus).
func _apply_vow_stage_complete_benefit(t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	var cfg := config_service.get_balance()

	# Gather current stage situations for the full-scout check.
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v

	var result := VowService.evaluate_stage_complete_benefit(flow_ctx.save_data, situations, cfg)
	var morale_d := int(result.get("morale_delta", 0))
	if morale_d == 0:
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var party_ids: Array = []
	if sanctum_v is Dictionary:
		var party_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if party_v is Array:
			party_ids = party_v

	_apply_vow_emotion_to_party(party_ids, morale_d, 0, "vow.stage_complete.benefit", cfg, t)
	logger.info(t, "vow.stage_complete.benefit", "Vow full-scout bonus applied", {
		"vow_id":      str(av.get("vow_id", "")),
		"morale_delta": morale_d,
	})
	# V2-VOW-002: store vow_outcome for resolve screen (overwrites preview set by _store_vow_benefit_preview).
	var _defn_b := VowService.get_definition(str(av.get("vow_id", "")), cfg)
	flow_ctx.vow_outcome = {
		"event":            "benefit",
		"vow_id":           str(av.get("vow_id", "")),
		"vow_name":         str(_defn_b.get("vow_name", "")),
		"proverb_twi":      str(_defn_b.get("proverb_twi", "")),
		"tier":             int(av.get("tier", 1)),
		"morale_delta":     morale_d,
		"fear_delta":       0,
		"bond_score_delta": 0,
		"ase_delta":        0,
		"echoes_affected":  party_ids,
	}
	flow_ctx.save_request = true


# VOW-001: Shared helper — applies morale/fear deltas to party echoes via EmotionService.
func _apply_vow_emotion_to_party(
	party_ids: Array,
	morale_d:  int,
	fear_d:    int,
	cause:     String,
	cfg:       Dictionary,
	t:         int
) -> void:
	if morale_d == 0 and fear_d == 0:
		return
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return
	var fear_threshold := int(cfg.get("data", {}).get("emotion", {}).get("fear_threshold", 80))
	for echo_v in (roster_v as Array):
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if not party_ids.has(str(echo.get("id", ""))):
			continue
		if morale_d != 0:
			EmotionService.apply_morale_delta(echo, morale_d, cause, logger, t)
		if fear_d != 0:
			EmotionService.apply_fear_delta(echo, fear_d, cause, fear_threshold, logger, t)


# VOW-001: Apply EmotionRecoveryService.set_modifier on vow break (shared between manual and auto-break).
func _apply_vow_break_aftermath(summary: Dictionary, cfg: Dictionary, t: int) -> void:
	# V2-VOW-002: write vow_outcome for ResolveScreen "The promise fractured." section.
	var _break_vow_id := str(summary.get("vow_id", ""))
	var _break_defn   := VowService.get_definition(_break_vow_id, cfg)
	var _break_name   := str(_break_defn.get("vow_name", ""))
	flow_ctx.vow_outcome = {
		"event":       "break",
		"vow_id":      _break_vow_id,
		"vow_name":    _break_name,
		"tier":        int(summary.get("tier", 1)),
		"morale_delta": int(summary.get("morale_delta", 0)),
		"fear_delta":   int(summary.get("fear_delta", 0)),
		"ase_delta":    -int(summary.get("ase_spent", 0)),
	}
	# V2-VOW-002: transient debuff chip for the Sanctum Active Effects panel.
	# Cleared on the next stage entry (_apply_vow_stage_entry_condition).
	var _break_morale := int(summary.get("morale_delta", 0))
	var _break_fear   := int(summary.get("fear_delta",   0))
	var _break_ase    := -int(summary.get("ase_spent",   0))
	var _break_body   := "Applied to all echoes in your roster:"
	if _break_morale != 0:
		_break_body += "\nMorale %+d" % _break_morale
	if _break_fear != 0:
		_break_body += "\nFear %+d" % _break_fear
	if _break_ase != 0:
		_break_body += "\n%+d Ase" % _break_ase
	flow_ctx.session_broken_vow_effect = {
		"effect_id":    "vow_broken",
		"label":        _break_name,
		"direction":    "debuff",
		"headline":     "Vow Broken — " + _break_name,
		"body":         _break_body,
		"duration_hint": "Clears when you re-enter a stage.",
		"source":       "vow",
	}
	# V2-VOW-002: persist the debuff chip to save_data so it survives restarts.
	var _pbe_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _pbe_sanc_v is Dictionary:
		(_pbe_sanc_v as Dictionary)["pending_broken_vow_effect"] = flow_ctx.session_broken_vow_effect.duplicate()
		# Set pledge cooldown from config (tuneable: data.vows.pledge_cooldown_stages).
		var _cd_vows_v: Variant = cfg.get("data", {})
		var _cd_vows: Dictionary = {}
		if _cd_vows_v is Dictionary:
			var _cd_data: Dictionary = _cd_vows_v as Dictionary
			var _cd_v: Variant = _cd_data.get("vows", {})
			if _cd_v is Dictionary:
				_cd_vows = _cd_v as Dictionary
		var _cd_stages := int(_cd_vows.get("pledge_cooldown_stages", 1))
		(_pbe_sanc_v as Dictionary)["pledge_cooldown_stages_remaining"] = _cd_stages
	# V2-VOW-002: increment lifetime breaks count (direct index — .get() returns a temp copy).
	if _pbe_sanc_v is Dictionary:
		var _sanc_b: Dictionary = _pbe_sanc_v as Dictionary
		if not _sanc_b.has("vow_stats") or not (_sanc_b["vow_stats"] is Dictionary):
			_sanc_b["vow_stats"] = {"honors": 0, "breaks": 0}
		var _vstats_b: Dictionary = _sanc_b["vow_stats"]
		_vstats_b["breaks"] = int(_vstats_b.get("breaks", 0)) + 1

	# Also apply immediate morale/fear to roster (same as _handle_vow_break manual path).
	var morale_d := int(summary.get("morale_delta", 0))
	var fear_d   := int(summary.get("fear_delta", 0))
	var recovery_cfg_v: Variant = cfg.get("data", {})
	var recovery_cfg: Dictionary = {}
	if recovery_cfg_v is Dictionary:
		var em_v: Variant = (recovery_cfg_v as Dictionary).get("emotion", {})
		if em_v is Dictionary:
			var rec_v: Variant = (em_v as Dictionary).get("recovery", {})
			if rec_v is Dictionary:
				recovery_cfg = rec_v

	var vow_morale_mul := float(recovery_cfg.get("modifier_vow_break_morale_mul", 0.5))
	var vow_fear_mul   := float(recovery_cfg.get("modifier_vow_break_fear_mul", 0.5))
	var mod_ticks      := int(recovery_cfg.get("modifier_ticks_duration", 120))
	var fear_threshold := int(cfg.get("data", {}).get("emotion", {}).get("fear_threshold", 80))

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return

	for echo_v in (roster_v as Array):
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if morale_d != 0:
			EmotionService.apply_morale_delta(echo, morale_d, "vow.break", logger, t)
		if fear_d != 0:
			EmotionService.apply_fear_delta(echo, fear_d, "vow.break", fear_threshold, logger, t)
		EmotionRecoveryService.set_modifier(echo, vow_morale_mul, vow_fear_mul, mod_ticks, logger, t)

	# V2-VOW-002: enrich vow_outcome with proverb_twi, bond_score_delta, echoes_affected.
	flow_ctx.vow_outcome["proverb_twi"]      = str(_break_defn.get("proverb_twi", ""))
	flow_ctx.vow_outcome["bond_score_delta"] = int(summary.get("bond_score_delta", 0))
	flow_ctx.vow_outcome["echoes_affected"]  = _get_roster_echo_ids()

	# V2-CONTINUITY-001: Vow break costs Continuity. Stacks every time.
	var _vb_cont_cfg := _get_continuity_cfg()
	var _vb_pen      := int(_vb_cont_cfg.get("vow_break_penalty", 3))
	ContinuityService.apply_penalty(flow_ctx.save_data, _vb_pen, "vow.break", logger, t)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-001: Stage exploration handlers
# ────────────────────────────────────────────────────────────────────────────

## Move the party to the nearest unresolved situation (directive-guided).
## On arrival: runs a stub reveal check.
##   - High roll (>50): situation is revealed; snapshot rebuilt to show type.
##   - Low roll (<=50): party stumbles in blind → dispatch stage.engage_situation.
## If situation was already revealed on arrival → dispatch stage.engage_situation.
func _handle_stage_advance_turn(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.advance.no_stage", "advance_turn: no active stage", {})
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	if str(explore_map.get("party_state", "")) != StageExploreModelScript.STATE_EXPLORING:
		logger.debug(t, "stage.advance.not_exploring", "advance_turn: party not in exploring state", {
			"party_state": explore_map.get("party_state", "")
		})
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# V2-STAGE-004-P2: resolve directive once for this turn
	var directive := directive_service.get_active_directive()
	var step_budget := int(directive.get("step_budget", 3))
	# V2-STAGE-004 Phase 2.5: reveal_radius replaces passive_reveal_radius as the primary fog lever.
	# Both directives always reveal (radius is the differentiator — Scout wide, Seek narrow).
	var reveal_radius := int(directive.get("reveal_radius", directive.get("passive_reveal_radius", 2)))

	# V2-STAGE-004-P2: build walkable set once (supports both terrain maps and legacy saves)
	var walkable := _explore_walkable(explore_map)

	# V2-STAGE-004 Phase 2.5: load durable explored_cells set (fog state).
	var explored_cells_v: Variant = explore_map.get("explored_cells", {})
	var explored_cells: Dictionary = explored_cells_v if explored_cells_v is Dictionary else {}

	# V2-STAGE-004 Phase 2.5 (Finding 2): entry-fog seed delegated to the shared static helper.
	# Idempotent (empty-guard inside); no-op when already seeded by _reset_session_state.
	# Passing precise_intel_bias from the resolved directive keeps intel quality consistent.
	var _adv_precise_bias := int(directive.get("precise_intel_bias", 0))
	var _adv_realm_seed   := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	FlowStageExploreStateScript.seed_entry_fog_if_needed(
		explore_map, walkable, reveal_radius, _adv_precise_bias, _adv_realm_seed,
		flow_ctx.stage_id, logger, t
	)
	# Re-read explored_cells after the seed (may have been populated by the helper above).
	var _ec_post_v: Variant = explore_map.get("explored_cells", {})
	explored_cells = _ec_post_v if _ec_post_v is Dictionary else {}

	# V2-STAGE-004 Phase 2.5: fog-of-war 3-tier target selection (replaces category-only _find_target_situation).
	var target := _find_explore_target(explore_map, directive, walkable, explored_cells)

	if target.is_empty():
		# All walkable cells explored and no discovered unresolved situations — nothing left.
		logger.debug(t, "stage.advance.no_target", "advance_turn: no target found (all explored, all resolved)", {})
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# One explore-turn consumed per Advance call
	explore_map["turn_count"] = int(explore_map.get("turn_count", 0)) + 1

	var target_pos_v: Variant = target.get("pos", { "col": 0, "row": 0 })
	var target_pos: Dictionary = target_pos_v if target_pos_v is Dictionary else { "col": 0, "row": 0 }
	var is_frontier := bool(target.get("is_frontier", false))
	var target_sit_id := str(target.get("id", ""))

	# V2-STAGE-004-P2: partial-move toward target up to step_budget steps
	var dist_field: Dictionary = {}
	if not walkable.is_empty():
		dist_field = StageTerrainScript.bfs_distance_field(target_pos, walkable)

	# Capture pre-advance party position as the first entry in the traveled path.
	var _pre_move_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var _pre_move: Dictionary = _pre_move_v if _pre_move_v is Dictionary else { "col": 0, "row": 0 }

	var stepped: Array = []
	var steps := 0
	while steps < step_budget:
		var here_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
		var here: Dictionary = here_v if here_v is Dictionary else { "col": 0, "row": 0 }
		if int(here.get("col", 0)) == int(target_pos.get("col", 0)) \
				and int(here.get("row", 0)) == int(target_pos.get("row", 0)):
			break
		var nxt: Dictionary
		if dist_field.is_empty():
			# Corruption-safety only: _explore_walkable always returns a populated set
			# (terrain or full WxH rect), so dist_field is empty ONLY if the target cell
			# itself is non-walkable (a malformed map). Step directly rather than hang.
			nxt = target_pos
		else:
			nxt = StageTerrainScript.next_step(here, dist_field, walkable, target_pos)
		# Dead-end safety: next_step returns from_cell unchanged
		if int(nxt.get("col", 0)) == int(here.get("col", 0)) \
				and int(nxt.get("row", 0)) == int(here.get("row", 0)):
			break
		explore_map["party_pos"] = nxt
		stepped.append(nxt)
		steps += 1

	# V2-STAGE-004-P2: stash full path walked this turn for UI chained-tween animation.
	# Shape: Array of { col, row } — pre-advance cell followed by each stepped cell.
	# Presentation-only; does not affect determinism. Cleared by next advance or session reset.
	if stepped.is_empty():
		explore_map["last_traveled_path"] = []
	else:
		var _path: Array = [{ "col": int(_pre_move.get("col", 0)), "row": int(_pre_move.get("row", 0)) }]
		for _sp in stepped:
			var _sp_d: Dictionary = _sp if _sp is Dictionary else {}
			_path.append({ "col": int(_sp_d.get("col", 0)), "row": int(_sp_d.get("row", 0)) })
		explore_map["last_traveled_path"] = _path

	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }

	# V2-STAGE-004 Phase 2.5: ALWAYS-ON fog lift for every stepped cell.
	# Both directives lift fog; reveal_radius is the lever (Scout wide, Seek narrow).
	# Run BEFORE arrival check so the cell we land on is always in explored_cells.
	var _all_stepped_cells: Array = [party_pos]  # final party cell always included
	for _fstep in stepped:
		var _fstep_d: Dictionary = _fstep if _fstep is Dictionary else {}
		_all_stepped_cells.append(_fstep_d)

	for _step_cell_v in _all_stepped_cells:
		var _step_cell: Dictionary = _step_cell_v if _step_cell_v is Dictionary else {}
		# Lift fog: add every walkable cell within reveal_radius of this stepped cell.
		var _fog_cells := StageTerrainScript.cells_within_radius(_step_cell, reveal_radius, walkable)
		for _fc_v in _fog_cells:
			var _fc: Dictionary = _fc_v if _fc_v is Dictionary else {}
			explored_cells["%d,%d" % [int(_fc.get("col", 0)), int(_fc.get("row", 0))]] = true

	explore_map["explored_cells"] = explored_cells

	# Tile-based discovery sweep: reveal every unresolved situation whose cell is now in
	# explored_cells. This is a superset of the old radius check — any situation whose tile
	# was fog-lifted during movement (within reveal_radius of any stepped cell) is guaranteed
	# revealed. Invariant: tile in explored_cells ⟺ situation on it is revealed.
	FlowStageExploreStateScript._reveal_explored_situations_static(explore_map, explored_cells, _adv_precise_bias, _adv_realm_seed, flow_ctx.stage_id, logger, t)

	# V2-STAGE-004 Phase 2.5: arrival/engage check — check whether the final party cell
	# holds a discovered, unresolved, non-frontier situation (includes situations discovered
	# en route during this advance via the fog-lift pass above).
	var _party_key: String = "%d,%d" % [int(party_pos.get("col", 0)), int(party_pos.get("row", 0))]
	var _arrived_sit_id := ""
	var _arrived_real_sit := false

	# Check if any discovered+unresolved situation is at party's final position.
	# V2-STAGE-004 Phase 2.5 (pass-fix): only trigger engagement for a passed node when it
	# is the current deliberate target (Tier-4 re-offer).  Walking PAST a passed node en route
	# to the frontier must NOT re-prompt — that is the key fix for the "return to same node" bug.
	var sits_check_v: Variant = explore_map.get("situations", [])
	var sits_check: Array = sits_check_v if sits_check_v is Array else []
	for _acs_v in sits_check:
		var _acs: Dictionary = _acs_v if _acs_v is Dictionary else {}
		if bool(_acs.get("resolved", false)):
			continue
		if not bool(_acs.get("revealed", false)):
			continue
		# Skip passed nodes unless this is exactly the node we deliberately re-targeted
		# (Tier-4 re-offer puts the objective's id into target_sit_id before this check).
		var _acs_id := str(_acs.get("id", ""))
		if bool(_acs.get("passed", false)) and _acs_id != target_sit_id:
			continue
		var _acp_v: Variant = _acs.get("pos", { "col": 0, "row": 0 })
		var _acp: Dictionary = _acp_v if _acp_v is Dictionary else { "col": 0, "row": 0 }
		var _ack: String = "%d,%d" % [int(_acp.get("col", 0)), int(_acp.get("row", 0))]
		if _ack == _party_key:
			_arrived_sit_id   = _acs_id
			_arrived_real_sit = true
			break

	var arrived := _arrived_real_sit \
		or (not is_frontier \
			and int(party_pos.get("col", 0)) == int(target_pos.get("col", 0)) \
			and int(party_pos.get("row", 0)) == int(target_pos.get("row", 0)) \
			and not target_sit_id.is_empty())

	if _arrived_real_sit:
		# Parked on a discovered+unresolved real situation — queue engagement popup.
		explore_map["last_situation_id"]   = _arrived_sit_id
		explore_map["pending_situation_id"] = _arrived_sit_id
		explore_map["in_transit"]           = false
		explore_map["target_situation_id"]  = ""
	elif arrived and not target_sit_id.is_empty():
		# Reached the targeted real situation by position (dist==0 case).
		explore_map["last_situation_id"]   = target_sit_id
		explore_map["pending_situation_id"] = target_sit_id
		explore_map["in_transit"]           = false
		explore_map["target_situation_id"]  = ""
	else:
		# IN-TRANSIT toward frontier or mid-way to a real situation; no engagement popup.
		explore_map["in_transit"]          = true
		explore_map["target_situation_id"] = target_sit_id if not is_frontier else ""

	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request        = true
	flow_ctx.save_request_reason = "stage.advance_turn"

	logger.info(t, "stage.advance_turn", "Party advanced", {
		"stage_id":           flow_ctx.stage_id,
		"target_id":          target_sit_id,
		"is_frontier":        is_frontier,
		"arrived":            arrived,
		"steps_taken":        steps,
		"turn_count":         int(explore_map.get("turn_count", 0)),
		"explored_count":     explored_cells.size(),
	})

	# Build fresh snapshot from mutated save_data so the pending popup and disabled
	# advance button are reflected in the returned snapshot. refresh_snapshot() alone
	# only re-validates ctx.last_snapshot — it does not rebuild from save_data.
	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## Party attempts to return home before completing all objectives.
## Escape check: seeded roll > (40 - directive.escape_bonus) = success.
## Success → party_state = "escaped", transition to flow.stage_map.
## Failure → return_failed flag in snapshot (full consequence deferred to V2-INTEL-002).
func _handle_stage_return_home(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.return.no_stage", "return_home: no active stage", {})
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var turn_count := int(explore_map.get("turn_count", 0))
	var realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))

	# V2-STAGE-004-P2: directive-driven escape threshold
	var directive := directive_service.get_active_directive()
	var escape_threshold := maxi(0, 40 - int(directive.get("escape_bonus", 0)))

	var rng := CampaignSeed.get_rng_from(
		realm_seed,
		"stage.escape.%s.%d" % [flow_ctx.stage_id, turn_count]
	)
	var roll := rng.randi_range(0, 100)
	var success := roll > escape_threshold

	logger.info(t, "stage.return_home", "Party return home attempt", {
		"stage_id":        flow_ctx.stage_id,
		"roll":            roll,
		"escape_threshold": escape_threshold,
		"success":         success,
		"turn_count":      turn_count,
	})

	if success:
		explore_map["party_state"] = StageExploreModelScript.STATE_ESCAPED
		stage["explore_map"] = explore_map
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		flow_ctx.save_request        = true
		flow_ctx.save_request_reason = "stage.escaped"

		# V2-ECONOMY-001: Intel-gated partial Ase award.
		# V2-STAGE-004-P2: intel_retention keeps full revealed-count value (no penalty on withdrawal).
		var _intel_count := _count_revealed_situations()
		var _partial_ase := 0
		if _intel_count > 0:
			var _pf := float(_get_balance_rewards_cfg().get("partial_intel_reward_factor", 0.12))
			# V2-STAGE-004-P2: intel_retention — a directive that retains intel on a failed/partial
			# withdrawal multiplies the partial reward by its `intel_retention_bonus` (data-driven,
			# default 1.0 = no change). Scout (retention true, bonus 1.5) keeps more of the value it
			# gathered; Seek (false) does not. Magnitude is tunable in data.directives.
			var _retention_mul := 1.0
			if bool(directive.get("intel_retention", false)):
				_retention_mul = float(directive.get("intel_retention_bonus", 1.0))
			_partial_ase = roundi(float(_get_stage_base_reward()) * _pf * _retention_mul)
			if _partial_ase > 0:
				econ.add_ase(_partial_ase, "return_home_intel_partial", logger, t)
		flow_ctx.pending_scout_return_ase         = _partial_ase
		flow_ctx.pending_scout_return_intel_count = _intel_count

		_apply_sanctum_emotion_tick(t)
		flow_ctx.last_snapshot = _build_scout_return_snapshot(t)
		flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "stage.return_home.scout_return")
	else:
		# Escape failed — show overlay. Full consequence mechanic deferred to V2-INTEL-002.
		stage["explore_map"] = explore_map
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		var snap_fail := FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
		snap_fail["data"]["return_home_result"] = {
			"success": false,
			"message": "The way is blocked. The party cannot leave yet.",
		}
		flow_ctx.last_snapshot = snap_fail
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


## Resolve a situation the party has reached.
## Marks situation resolved + revealed. Increments objectives_found if applicable.
## Routes: combat → flow.encounter; npc/loot/money → inline overlay stub.
## All objectives found → flow.complete_stage.
func _handle_stage_engage_situation(action: Dictionary, t: int) -> void:
	var sit_id := str(action.get("situation_id", ""))
	if sit_id.is_empty():
		logger.debug(t, "stage.engage.no_id", "engage_situation: missing situation_id", {})
		return

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	# Clear pending state — engagement is now committed
	explore_map["pending_situation_id"] = ""
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	# VOW-001: capture revealed state before engagement mutation so obi_nnim_kyere can check it.
	var _sit_was_revealed := false
	for _sv_peek in situations:
		if _sv_peek is Dictionary and str((_sv_peek as Dictionary).get("id", "")) == sit_id:
			_sit_was_revealed = bool((_sv_peek as Dictionary).get("revealed", false))
			break

	# Find and mutate the situation — set ONLY revealed (not resolved).
	var sit: Dictionary = {}
	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s["revealed"] = true
			# V2-INTEL-001: write firsthand intel on direct engagement if not already scouted
			var eng_clues_v: Variant = s.get("intel_clues", [])
			var eng_clues: Array = eng_clues_v if eng_clues_v is Array else []
			if eng_clues.is_empty():
				eng_clues.append(_intel_clue_for_type(str(s.get("type", ""))))
			s["intel_clues"] = eng_clues
			if str(s.get("intel_quality", "")).is_empty():
				s["intel_quality"] = "rough"
			situations[i] = s
			sit = s
			break

	if sit.is_empty():
		logger.debug(t, "stage.engage.not_found", "engage_situation: situation not found", {
			"situation_id": sit_id
		})
		return

	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.engage_situation"

	# VOW-001: evaluate engage condition (obi_nnim_kyere revealed check).
	_apply_vow_engage_condition(_sit_was_revealed, t)

	# V2-STAGE-002: set active objective index for encounter resolution mode lookup.
	var _sit_obj_index := int(sit.get("objective_index", -1))
	flow_ctx.active_encounter_objective_index = _sit_obj_index

	var sit_type := str(sit.get("type", ""))

	logger.info(t, "stage.engage_situation", "Party engaged situation", {
		"stage_id":        flow_ctx.stage_id,
		"situation_id":    sit_id,
		"type":            sit_type,
		"is_objective":    sit.get("is_objective", false),
		"objective_index": _sit_obj_index,
		"obj_found":       explore_map.get("objectives_found", 0),
		"obj_total":       explore_map.get("objectives_total", 0),
	})

	# V2-STAGE-004: route via SituationResolutionService.
	var _track := SituationResolutionServiceScript.route(sit_type, bool(sit.get("is_objective", false)))

	if _track == "async":
		# Compute encounter_approach context before handing off.
		var _ea_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _ea_sanctum: Dictionary = _ea_sanctum_v if _ea_sanctum_v is Dictionary else {}
		var _ea_roster_v: Variant = _ea_sanctum.get("roster", [])
		var _ea_roster: Array = _ea_roster_v if _ea_roster_v is Array else []
		var _ea_party_ids_v: Variant = _ea_sanctum.get("active_party_ids", [])
		var _ea_party_ids: Array = _ea_party_ids_v if _ea_party_ids_v is Array else []
		var _ea_fear_sum  := 0
		var _ea_morale_sum := 0
		var _ea_count := 0
		for _ea_echo_v in _ea_roster:
			if not (_ea_echo_v is Dictionary):
				continue
			var _ea_echo: Dictionary = _ea_echo_v
			if str(_ea_echo.get("id", "")) not in _ea_party_ids:
				continue
			var _ea_emo_v: Variant = _ea_echo.get("emotion", {})
			var _ea_emo: Dictionary = _ea_emo_v if _ea_emo_v is Dictionary else {}
			_ea_fear_sum   += int(_ea_emo.get("fear_current",   0))
			_ea_morale_sum += int(_ea_emo.get("morale_current", 0))
			_ea_count += 1
		var _ea_avg_fear   := (_ea_fear_sum   / _ea_count) if _ea_count > 0 else 0
		var _ea_avg_morale := (_ea_morale_sum / _ea_count) if _ea_count > 0 else 0
		var _ea_flow_v: Variant = flow_ctx.save_data.get("flow", {})
		var _ea_flow: Dictionary = _ea_flow_v if _ea_flow_v is Dictionary else {}
		var _ea_directive := str(_ea_flow.get("active_directive", "directive.scout_carefully"))
		var _stage_ctx_v: Variant = flow_ctx.save_data.get("stage_context", {})
		var _stage_ctx: Dictionary = _stage_ctx_v if _stage_ctx_v is Dictionary else {}
		_stage_ctx["encounter_approach"] = {
			"turns_taken":             int(explore_map.get("turn_count", 0)),
			"directive_id":            _ea_directive,
			"situation_was_revealed":  _sit_was_revealed,
			"party_avg_fear":          _ea_avg_fear,
			"party_avg_morale":        _ea_avg_morale,
		}
		flow_ctx.save_data["stage_context"] = _stage_ctx
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "stage.encounter_approach"

		var _engage_reason := "stage.engage.shrine" if sit_type == ObjectiveModelScript.TYPE_SHRINE \
			else "stage.engage.combat"
		flow_machine.transition(FlowStateIds.ENCOUNTER, flow_ctx, logger, t, _engage_reason)
		return

	# in_explore branch
	# V2-STAGE-003: NPC with contact dict → start conversation.
	if sit_type == SituationModelScript.TYPE_NPC:
		var _contact_dict_v: Variant = sit.get("contact", {})
		var _contact_dict: Dictionary = _contact_dict_v if _contact_dict_v is Dictionary else {}
		if not _contact_dict.is_empty():
			_start_contact_conversation(sit, sit_id, explore_map, stage, t)
			return

	# V2-STAGE-004: resolve in-explore via SituationResolutionService.
	var _realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	var _res_rng := CampaignSeed.get_rng_from(_realm_seed, "stage.resolution.%s" % sit_id)

	var _sit_bal_v: Variant = config_service.get_balance().get("data", {})
	var _sit_bal: Dictionary = _sit_bal_v if _sit_bal_v is Dictionary else {}
	var _stages_cfg_v: Variant = _sit_bal.get("stages", {})
	var _stages_cfg: Dictionary = _stages_cfg_v if _stages_cfg_v is Dictionary else {}

	var _r := SituationResolutionServiceScript.resolve_in_explore(sit, _stages_cfg, _res_rng)

	if str(_r.get("panel_kind", "")) == "choice":
		# Do not resolve — player must pick a choice first.
		var _snap := FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
		_snap["data"]["situation_overlay"] = {
			"situation_id": sit_id,
			"type":         sit_type,
			"result_text":  "",
			"panel_kind":   "choice",
			"choices":      _r.get("choices", []),
		}
		flow_ctx.last_snapshot = _snap
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# acknowledge / take / leave — apply effects, resolve, then route to RESOLVE screen.
	var _in_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _in_sanctum: Dictionary = _in_sanctum_v if _in_sanctum_v is Dictionary else {}
	var _in_roster_v: Variant = _in_sanctum.get("roster", [])
	var _in_roster: Array = _in_roster_v if _in_roster_v is Array else []
	var _in_party_ids_v: Variant = _in_sanctum.get("active_party_ids", [])
	var _in_party_ids: Array = _in_party_ids_v if _in_party_ids_v is Array else []
	var _in_fear_delta:   int = int(_r.get("fear_delta",   0))
	var _in_morale_delta: int = int(_r.get("morale_delta", 0))

	# P1 CLOSE: Capture pre-emotion status for each affected active party echo.
	var _in_pre_status: Dictionary = {}
	for _in_pre_v in _in_roster:
		if not (_in_pre_v is Dictionary):
			continue
		var _in_pre_e: Dictionary = _in_pre_v
		var _in_pre_id := str(_in_pre_e.get("id", ""))
		if _in_pre_id not in _in_party_ids:
			continue
		if _in_fear_delta == 0 and _in_morale_delta == 0:
			continue
		var _in_pre_emo_v: Variant = _in_pre_e.get("emotion", {})
		var _in_pre_emo: Dictionary = _in_pre_emo_v if _in_pre_emo_v is Dictionary else {}
		_in_pre_status[_in_pre_id] = EmotionService.get_emotional_status(
			int(_in_pre_emo.get("morale_current", 50)),
			int(_in_pre_emo.get("fear_current",   0))
		)

	for _in_echo_v in _in_roster:
		if not (_in_echo_v is Dictionary):
			continue
		var _in_echo: Dictionary = _in_echo_v
		if str(_in_echo.get("id", "")) not in _in_party_ids:
			continue
		if _in_fear_delta != 0:
			EmotionService.apply_fear_delta(_in_echo, _in_fear_delta,
				"situation." + sit_type, 80, logger, t)
		if _in_morale_delta != 0:
			EmotionService.apply_morale_delta(_in_echo, _in_morale_delta,
				"situation." + sit_type, logger, t)

	if int(_r.get("ase_delta", 0)) > 0:
		econ.add_ase(int(_r.get("ase_delta", 0)), "situation.money", logger, t)

	var _loot_results_v: Variant = _r.get("loot_results", [])
	var _loot_results: Array = _loot_results_v if _loot_results_v is Array else []
	if _loot_results.size() > 0:
		var _em_loot_v: Variant = explore_map.get("loot_results", [])
		var _em_loot: Array = _em_loot_v if _em_loot_v is Array else []
		for _loot_entry in _loot_results:
			_em_loot.append(_loot_entry)
		explore_map["loot_results"] = _em_loot

	# Mark resolved and update objectives if applicable.
	for _ri2 in range(situations.size()):
		var _sv2: Variant = situations[_ri2]
		if _sv2 is Dictionary and str((_sv2 as Dictionary).get("id", "")) == sit_id:
			var _s2: Dictionary = _sv2
			_s2["resolved"] = true
			situations[_ri2] = _s2
			break
	if bool(sit.get("is_objective", false)):
		explore_map["objectives_found"] = int(explore_map.get("objectives_found", 0)) + 1
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.resolve_in_explore"

	# P1 CLOSE: Build emotion_summary (post deltas applied).
	var _in_emotion_summary: Array = []
	# Compute direction from the situation's deltas (uniform for all echoes).
	var _in_direction: String
	if _in_morale_delta > 0:
		_in_direction = "lift"
	elif _in_fear_delta < 0:
		_in_direction = "ease"
	elif _in_morale_delta < 0 or _in_fear_delta > 0:
		_in_direction = "fall"
	else:
		_in_direction = "steady"
	for _in_post_v in _in_roster:
		if not (_in_post_v is Dictionary):
			continue
		var _in_post_e: Dictionary = _in_post_v
		var _in_post_id := str(_in_post_e.get("id", ""))
		if _in_post_id not in _in_party_ids:
			continue
		if not _in_pre_status.has(_in_post_id):
			continue
		var _in_post_emo_v: Variant = _in_post_e.get("emotion", {})
		var _in_post_emo: Dictionary = _in_post_emo_v if _in_post_emo_v is Dictionary else {}
		_in_emotion_summary.append({
			"echo_id":               _in_post_id,
			"name":                  str(_in_post_e.get("name", "")),
			"pre_emotional_status":  _in_pre_status[_in_post_id],
			"post_emotional_status": EmotionService.get_emotional_status(
				int(_in_post_emo.get("morale_current", 50)),
				int(_in_post_emo.get("fear_current",   0))
			),
			"direction": _in_direction,
			"tag":       "",
		})

	# P1 CLOSE: Build effects array.
	var _in_effects: Array = []
	# Loot kind chips.
	for _loot_chip in _loot_results:
		if _loot_chip is Dictionary:
			var _loot_kind := str((_loot_chip as Dictionary).get("kind", ""))
			if not _loot_kind.is_empty():
				_in_effects.append({
					"kind":  "item",
					"label": _loot_kind.capitalize(),
					"value": "",
					"tone":  "item",
				})
	# Intel clue chip (first clue, if any).
	var _in_clues_v: Variant = sit.get("intel_clues", [])
	var _in_clues: Array = _in_clues_v if _in_clues_v is Array else []
	if _in_clues.size() > 0 and not str(_in_clues[0]).is_empty():
		_in_effects.append({
			"kind":  "intel",
			"label": str(_in_clues[0]),
			"value": "",
			"tone":  "intel",
		})

	# P1 CLOSE: Transition to RESOLVE screen instead of overlay.
	_resolve_situation_to_screen(
		sit, sit_id, _in_emotion_summary, _in_effects,
		str(_r.get("result_text", "")), int(_r.get("ase_delta", 0)), t
	)


# V2-STAGE-003: NPC conversation setup — extracted from _handle_stage_engage_situation.
# Called when sit_type == TYPE_NPC and contact dict is non-empty.
# Behavior is byte-identical to the inlined V2-STAGE-003 block (no resolved undo needed
# since we no longer set resolved up front in the engage handler).
func _start_contact_conversation(sit: Dictionary, sit_id: String, explore_map: Dictionary, stage: Dictionary, t: int) -> void:
	var contact_dict_v: Variant = sit.get("contact", {})
	var contact_dict: Dictionary = contact_dict_v if contact_dict_v is Dictionary else {}

	var _sit_bal_v: Variant = config_service.get_balance().get("data", {})
	var _sit_bal: Dictionary = _sit_bal_v if _sit_bal_v is Dictionary else {}

	# Apply turn-count modifier based on NPC starting emotion
	var contact_work := contact_dict.duplicate(true)
	var npc_fear  := int(contact_work.get("fear",   50))
	var npc_morale := int(contact_work.get("morale", 50))
	var tc := int(contact_work.get("turn_count", 2))
	if npc_fear > 60:
		tc = max(1, tc - 1)
	elif npc_morale < 30:
		tc += 1
	contact_work["turn_count"] = tc

	# Load contact_responses data
	var response_data := _load_contact_responses()

	# Load contact config
	var contact_cfg_bal_v: Variant = _sit_bal.get("contact", {})
	var contact_cfg_bal: Dictionary = contact_cfg_bal_v if contact_cfg_bal_v is Dictionary else {}

	# Read active directive
	var _dir_id := str(flow_ctx.save_data.get("flow", {}).get("active_directive", "directive.scout_carefully") \
		if flow_ctx.save_data.get("flow", null) is Dictionary else "directive.scout_carefully")

	# Build party echoes (active party only)
	var _party_echoes := _get_active_party_echoes()

	# Compute initial bids
	var bid_state := ConversationServiceScript.compute_bids(
		_party_echoes, contact_work, _dir_id, contact_cfg_bal
	)

	# Set NPC opening line from burden_variant (authored in contact_responses.json)
	var _bv := str(contact_work.get("burden_variant", ""))
	var _bv_role_data_v: Variant = response_data.get(str(contact_work.get("role", "")), {})
	var _bv_role_data: Dictionary = _bv_role_data_v if _bv_role_data_v is Dictionary else {}
	var _bv_variants_v: Variant = _bv_role_data.get("burden_variants", {})
	var _bv_variants: Dictionary = _bv_variants_v if _bv_variants_v is Dictionary else {}
	var _bv_variant_v: Variant = _bv_variants.get(_bv, {})
	var _bv_variant: Dictionary = _bv_variant_v if _bv_variant_v is Dictionary else {}
	contact_work["npc_line"] = str(_bv_variant.get("opening", ""))

	# Auto-generate responses if party ≤ 3
	var contact_responses: Array = []
	if _party_echoes.size() <= 3:
		contact_responses = ConversationServiceScript.generate_responses(
			_party_echoes, contact_work, contact_cfg_bal, response_data, t, bid_state
		)

	explore_map["pending_contact"] = contact_work
	explore_map["contact_responses"] = contact_responses
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.contact.start"

	logger.info(t, "stage.contact.start", "NPC conversation started", {
		"stage_id":    flow_ctx.stage_id,
		"situation_id": sit_id,
		"role":        str(contact_work.get("role", "")),
		"name":        str(contact_work.get("name", "")),
	})

	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004: Resolve a choice-overlay option (obstacle / structure).
# ────────────────────────────────────────────────────────────────────────────

# Payload: { "situation_id": String, "choice_id": String }
func _handle_stage_resolve_situation_choice(action: Dictionary, t: int) -> void:
	var sit_id    := str(action.get("situation_id", ""))
	var choice_id := str(action.get("choice_id", ""))
	if sit_id.is_empty() or choice_id.is_empty():
		logger.debug(t, "stage.resolve_choice.invalid", "resolve_situation_choice: missing payload", {
			"situation_id": sit_id, "choice_id": choice_id
		})
		return

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	# Find the situation.
	var sit: Dictionary = {}
	for _sv in situations:
		if _sv is Dictionary and str((_sv as Dictionary).get("id", "")) == sit_id:
			sit = _sv
			break

	if sit.is_empty():
		logger.debug(t, "stage.resolve_choice.not_found", "resolve_situation_choice: situation not found", {
			"situation_id": sit_id
		})
		return

	var sit_type := str(sit.get("type", ""))

	# Seeded rng — same namespace as resolve_in_explore (no draws made in resolve_choice currently).
	var _realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	var _rng := CampaignSeed.get_rng_from(_realm_seed, "stage.resolution.%s" % sit_id)

	var _sit_bal_v: Variant = config_service.get_balance().get("data", {})
	var _sit_bal: Dictionary = _sit_bal_v if _sit_bal_v is Dictionary else {}
	var _stages_cfg_v: Variant = _sit_bal.get("stages", {})
	var _stages_cfg: Dictionary = _stages_cfg_v if _stages_cfg_v is Dictionary else {}

	var _c := SituationResolutionServiceScript.resolve_choice(sit, choice_id, _stages_cfg, _rng)

	# P1 CLOSE: Capture pre-emotion status before applying choice deltas.
	var _rc_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _rc_sanctum: Dictionary = _rc_sanctum_v if _rc_sanctum_v is Dictionary else {}
	var _rc_roster_v: Variant = _rc_sanctum.get("roster", [])
	var _rc_roster: Array = _rc_roster_v if _rc_roster_v is Array else []
	var _rc_party_ids_v: Variant = _rc_sanctum.get("active_party_ids", [])
	var _rc_party_ids: Array = _rc_party_ids_v if _rc_party_ids_v is Array else []
	var _rc_fear_delta:   int = int(_c.get("fear_delta",   0))
	var _rc_morale_delta: int = int(_c.get("morale_delta", 0))

	var _rc_pre_status: Dictionary = {}
	for _rc_pre_v in _rc_roster:
		if not (_rc_pre_v is Dictionary):
			continue
		var _rc_pre_e: Dictionary = _rc_pre_v
		var _rc_pre_id := str(_rc_pre_e.get("id", ""))
		if _rc_pre_id not in _rc_party_ids:
			continue
		if _rc_fear_delta == 0 and _rc_morale_delta == 0:
			continue
		var _rc_pre_emo_v: Variant = _rc_pre_e.get("emotion", {})
		var _rc_pre_emo: Dictionary = _rc_pre_emo_v if _rc_pre_emo_v is Dictionary else {}
		_rc_pre_status[_rc_pre_id] = EmotionService.get_emotional_status(
			int(_rc_pre_emo.get("morale_current", 50)),
			int(_rc_pre_emo.get("fear_current",   0))
		)

	# Apply emotion effects to active party.
	for _rc_echo_v in _rc_roster:
		if not (_rc_echo_v is Dictionary):
			continue
		var _rc_echo: Dictionary = _rc_echo_v
		if str(_rc_echo.get("id", "")) not in _rc_party_ids:
			continue
		if _rc_fear_delta != 0:
			EmotionService.apply_fear_delta(_rc_echo, _rc_fear_delta,
				"situation." + sit_type, 80, logger, t)
		if _rc_morale_delta != 0:
			EmotionService.apply_morale_delta(_rc_echo, _rc_morale_delta,
				"situation." + sit_type, logger, t)

	# Advance turn count by choice's turn_cost.
	explore_map["turn_count"] = int(explore_map.get("turn_count", 0)) + int(_c.get("turn_cost", 0))

	# Mark situation resolved.
	for _ri3 in range(situations.size()):
		var _sv3: Variant = situations[_ri3]
		if _sv3 is Dictionary and str((_sv3 as Dictionary).get("id", "")) == sit_id:
			var _s3: Dictionary = _sv3
			_s3["resolved"] = true
			situations[_ri3] = _s3
			break
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.resolve_choice"

	# P1 CLOSE: Build emotion_summary and effects, then route to RESOLVE screen.
	var _rc_emotion_summary: Array = []
	var _rc_direction: String
	if _rc_morale_delta > 0:
		_rc_direction = "lift"
	elif _rc_fear_delta < 0:
		_rc_direction = "ease"
	elif _rc_morale_delta < 0 or _rc_fear_delta > 0:
		_rc_direction = "fall"
	else:
		_rc_direction = "steady"
	for _rc_post_v in _rc_roster:
		if not (_rc_post_v is Dictionary):
			continue
		var _rc_post_e: Dictionary = _rc_post_v
		var _rc_post_id := str(_rc_post_e.get("id", ""))
		if _rc_post_id not in _rc_party_ids:
			continue
		if not _rc_pre_status.has(_rc_post_id):
			continue
		var _rc_post_emo_v: Variant = _rc_post_e.get("emotion", {})
		var _rc_post_emo: Dictionary = _rc_post_emo_v if _rc_post_emo_v is Dictionary else {}
		_rc_emotion_summary.append({
			"echo_id":               _rc_post_id,
			"name":                  str(_rc_post_e.get("name", "")),
			"pre_emotional_status":  _rc_pre_status[_rc_post_id],
			"post_emotional_status": EmotionService.get_emotional_status(
				int(_rc_post_emo.get("morale_current", 50)),
				int(_rc_post_emo.get("fear_current",   0))
			),
			"direction": _rc_direction,
			"tag":       "",
		})

	# Turn-cost chip for find_route / any turn_cost > 0.
	var _rc_effects: Array = []
	var _rc_turn_cost := int(_c.get("turn_cost", 0))
	if _rc_turn_cost > 0 or choice_id == "find_route":
		_rc_effects.append({
			"kind":  "objective",
			"label": "+%d turn" % _rc_turn_cost,
			"value": "",
			"tone":  "objective",
		})

	_resolve_situation_to_screen(
		sit, sit_id, _rc_emotion_summary, _rc_effects,
		str(_c.get("result_text", "")), 0, t
	)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-002 private helpers
# ────────────────────────────────────────────────────────────────────────────

# V2-STAGE-002: Dismiss the engagement popup without resolving the situation.
# Clears pending_situation_id — intel gathered (revealed state) is preserved.
# Party stays parked at the situation's position; the next Advance will naturally
# bypass it (distance = 0 is skipped in _find_target_situation) and move on.
func _handle_stage_ignore_situation(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var sit_id := str(explore_map.get("pending_situation_id", ""))

	# V2-STAGE-004 Phase 2.5 (pass-fix): mark the ignored situation as passed=true
	# so _find_explore_target skips it in Tiers 1–2 and the party explores the frontier
	# instead of immediately re-targeting the same node.  revealed stays true (it remains
	# visible on the map).  A passed OBJECTIVE is re-offered once the map is fully explored
	# (Tier 4) so the stage stays completable.
	if not sit_id.is_empty():
		var _pass_sits_v: Variant = explore_map.get("situations", [])
		var _pass_sits: Array = _pass_sits_v if _pass_sits_v is Array else []
		for _ps_v in _pass_sits:
			if not (_ps_v is Dictionary):
				continue
			var _ps: Dictionary = _ps_v
			if str(_ps.get("id", "")) == sit_id:
				_ps["passed"] = true
				break
		explore_map["situations"] = _pass_sits

	explore_map["pending_situation_id"] = ""
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.ignore_situation"

	logger.debug(t, "stage.explore.situation_ignored", "Engagement popup dismissed — situation marked passed", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})

	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-003: NPC Contact conversation handlers
# ────────────────────────────────────────────────────────────────────────────

# stage.consult_echoes — player selects up to 3 echoes to hear this turn.
# Generates responses for the selected echoes; stores in explore_map.contact_responses.
func _handle_stage_consult_echoes(action: Dictionary, t: int) -> void:
	var echo_ids_v: Variant = action.get("echo_ids", [])
	var echo_ids: Array = echo_ids_v if echo_ids_v is Array else []
	if echo_ids.is_empty():
		logger.debug(t, "stage.consult.invalid", "consult_echoes: no echo_ids provided", {})
		return
	# Trim to max 3 — button auto-passes all party IDs; handler caps the consultation.
	if echo_ids.size() > 3:
		echo_ids = echo_ids.slice(0, 3)

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var contact_v: Variant = explore_map.get("pending_contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	if contact.is_empty():
		return

	# Load configs
	var bal_v: Variant = config_service.get_balance().get("data", {})
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var contact_cfg_v: Variant = bal.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}
	var response_data := _load_contact_responses()

	# Read active directive
	var dir_id := str(flow_ctx.save_data.get("flow", {}).get("active_directive", "directive.scout_carefully") \
		if flow_ctx.save_data.get("flow", null) is Dictionary else "directive.scout_carefully")

	# Build selected echo dicts
	var all_party := _get_active_party_echoes()
	var selected_echoes: Array = []
	for echo_v in all_party:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) in echo_ids:
			selected_echoes.append(echo)

	# Track ignored bids
	var bid_state := ConversationServiceScript.compute_bids(all_party, contact, dir_id, contact_cfg)
	var ignored_counts_v: Variant = contact.get("ignored_bid_counts", {})
	var ignored_counts: Dictionary = ignored_counts_v if ignored_counts_v is Dictionary else {}
	for eid in bid_state:
		if str(bid_state[eid]) != "" and eid not in echo_ids:
			ignored_counts[eid] = int(ignored_counts.get(eid, 0)) + 1
	contact["ignored_bid_counts"] = ignored_counts

	# Generate responses for selected echoes
	contact["consulted_ids_this_turn"] = echo_ids
	var contact_responses := ConversationServiceScript.generate_responses(
		selected_echoes, contact, contact_cfg, response_data, t, bid_state
	)

	explore_map["pending_contact"] = contact
	explore_map["contact_responses"] = contact_responses
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.consult_echoes"

	logger.info(t, "stage.consult_echoes", "Echo consultation choices made", {
		"stage_id":    flow_ctx.stage_id,
		"echo_ids":    echo_ids,
	})

	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# stage.speak_response — player picks which consulted echo speaks; advances conversation turn.
func _handle_stage_speak_response(action: Dictionary, t: int) -> void:
	var speaking_id := str(action.get("echo_id", ""))
	if speaking_id.is_empty():
		return

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var contact_v: Variant = explore_map.get("pending_contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	if contact.is_empty():
		return

	# Find the chosen response
	var responses_v: Variant = explore_map.get("contact_responses", [])
	var responses: Array = responses_v if responses_v is Array else []
	var chosen_response: Dictionary = {}
	for r_v in responses:
		var r: Dictionary = r_v if r_v is Dictionary else {}
		if str(r.get("echo_id", "")) == speaking_id:
			chosen_response = r
			break
	if chosen_response.is_empty():
		logger.debug(t, "stage.speak.not_found", "speak_response: echo_id not in responses", { "echo_id": speaking_id })
		return

	var turn_score := float(chosen_response.get("resonance_score", 0.5))

	# Load config
	var bal_v: Variant = config_service.get_balance().get("data", {})
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var contact_cfg_v: Variant = bal.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}

	# Apply NPC reaction
	var reaction := ConversationServiceScript.apply_npc_reaction(contact, turn_score, contact_cfg)
	contact["fear"]   = clampi(int(contact.get("fear",   50)) + int(reaction.get("fear_delta",   0)), 0, 100)
	contact["morale"] = clampi(int(contact.get("morale", 50)) + int(reaction.get("morale_delta", 0)), 0, 100)
	contact["npc_reaction_word"] = _derive_contact_reaction_word(turn_score)

	# Record speaking echo
	var speaking_ids_v: Variant = contact.get("speaking_echo_ids", [])
	var speaking_ids: Array = speaking_ids_v if speaking_ids_v is Array else []
	speaking_ids.append(speaking_id)
	contact["speaking_echo_ids"] = speaking_ids

	# Record consulted echoes for this turn into overall consulted list
	var consulted_this_v: Variant = contact.get("consulted_ids_this_turn", [])
	var consulted_this: Array = consulted_this_v if consulted_this_v is Array else []
	var overall_consulted_v: Variant = contact.get("consulted_echo_ids", [])
	var overall_consulted: Array = overall_consulted_v if overall_consulted_v is Array else []
	for ceid in consulted_this:
		if ceid not in overall_consulted:
			overall_consulted.append(ceid)
	contact["consulted_echo_ids"] = overall_consulted

	# Social effects
	var all_party := _get_active_party_echoes()
	var all_party_ids: Array = []
	for ep_v in all_party:
		var ep: Dictionary = ep_v if ep_v is Dictionary else {}
		all_party_ids.append(str(ep.get("id", "")))
	var not_consulted: Array = []
	for pid in all_party_ids:
		if pid not in consulted_this:
			not_consulted.append(pid)

	var sanctum_save_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum_save: Dictionary = sanctum_save_v if sanctum_save_v is Dictionary else {}
	var bonds_v: Variant = sanctum_save.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []

	var social_effects := ConversationServiceScript.get_social_effects(
		consulted_this, speaking_id, not_consulted, all_party, bonds, contact_cfg, turn_score
	)

	var roster_v: Variant = sanctum_save.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	for effect_v in social_effects:
		var effect: Dictionary = effect_v if effect_v is Dictionary else {}
		var eid := str(effect.get("echo_id", ""))
		var mdelta := int(effect.get("morale_delta", 0))
		var bdelta := int(effect.get("bond_delta", 0))
		var btarget := str(effect.get("bond_target_id", ""))

		# Apply morale delta
		if mdelta != 0:
			for echo_v in roster:
				if not (echo_v is Dictionary):
					continue
				var echo: Dictionary = echo_v
				if str(echo.get("id", "")) == eid:
					EmotionService.apply_morale_delta(echo, mdelta, "contact.social." + str(effect.get("reason", "")), logger, t)
					break

		# Apply bond delta
		if bdelta != 0 and not btarget.is_empty():
			sanctum_save["bonds"] = SocialGraphService.apply_score_delta(
				bonds, eid, btarget, bdelta,
				config_service.get_balance().get("data", {}).get("sanctum", {}).get("bond_triggers", {}).get("thresholds", {"friend_min": 30, "rival_max": -30}),
				logger, t
			)
			bonds = sanctum_save["bonds"]

	# Storyweight partial step for speaker (if score >= threshold)
	var sw_threshold := float(contact_cfg.get("storyweight_speak_threshold", 0.5))
	if turn_score >= sw_threshold:
		for echo_v in roster:
			if not (echo_v is Dictionary):
				continue
			var echo: Dictionary = echo_v
			if str(echo.get("id", "")) == speaking_id:
				var current_sw := int(echo.get("storyweight", echo.get("xp_total", 0)))
				var sw_gain    := int(contact_cfg.get("storyweight_speak_partial_step", 0))
				if sw_gain > 0:
					echo["storyweight"] = current_sw + sw_gain
					echo["xp_total"]    = current_sw + sw_gain
				break

	# Increment turn
	contact["turn_current"] = int(contact.get("turn_current", 0)) + 1
	contact["consulted_ids_this_turn"] = []
	var turn_current := int(contact.get("turn_current", 0))
	var turn_count   := int(contact.get("turn_count",   2))

	var next_state := str(reaction.get("next_state", ""))
	var conversation_over := (turn_current >= turn_count) or next_state == "failed"

	if conversation_over:
		# Resolve outcome
		var outcome: String
		if next_state == "failed":
			outcome = "failed"
		else:
			outcome = ConversationServiceScript.resolve_outcome(contact, contact_cfg)
		contact["outcome"] = outcome
		contact["state"]   = "concluded" if outcome != "failed" else "failed"

		_apply_contact_outcome(contact, stage, explore_map, t)
		return

	# Conversation continues — derive NPC follow-up line, then save and rebuild
	var _next_party := _get_active_party_echoes()
	var _next_responses: Array = []
	var _next_resp_data := _load_contact_responses()

	# Derive the NPC's next-turn line from the reaction word set above
	var _nf_data_v: Variant = _next_resp_data.get("npc_followup", {})
	var _nf_data: Dictionary = _nf_data_v if _nf_data_v is Dictionary else {}
	var _nf_role_v: Variant = _nf_data.get(str(contact.get("role", "")), {})
	var _nf_role: Dictionary = _nf_role_v if _nf_role_v is Dictionary else {}
	contact["npc_line"] = str(_nf_role.get(str(contact.get("npc_reaction_word", "")).to_lower(), ""))

	explore_map["pending_contact"] = contact

	# Auto-regenerate responses for the next turn when party ≤ 3 (mirrors the initial engagement path).
	# For party > 3, responses stay empty so the picker fires via cta.consult_echoes.
	if _next_party.size() <= 3:
		var _next_dir_id := str(flow_ctx.save_data.get("flow", {}).get("active_directive", "directive.scout_carefully") \
			if flow_ctx.save_data.get("flow", null) is Dictionary else "directive.scout_carefully")
		var _next_bids := ConversationServiceScript.compute_bids(_next_party, contact, _next_dir_id, contact_cfg)
		_next_responses = ConversationServiceScript.generate_responses(
			_next_party, contact, contact_cfg, _next_resp_data, t, _next_bids
		)
	explore_map["contact_responses"] = _next_responses
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.speak_response"

	logger.info(t, "stage.speak_response", "Echo spoke; conversation continues", {
		"stage_id":     flow_ctx.stage_id,
		"echo_id":      speaking_id,
		"turn_score":   turn_score,
		"turn_current": turn_current,
		"turn_count":   turn_count,
		"npc_fear":     contact.get("fear",   0),
		"npc_morale":   contact.get("morale", 0),
	})

	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# stage.disengage_contact — player exits mid-conversation. No outcome; stage continues.
func _handle_stage_disengage_contact(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var contact_v: Variant = explore_map.get("pending_contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	var sit_id := str(contact.get("id", ""))

	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	var log_reason := "stage.contact.disengaged"
	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if not (s_v is Dictionary):
			continue
		var sit: Dictionary = s_v
		if str(sit.get("id", "")) != sit_id:
			continue
		# Objective-linked Charge: leave unresolved so the party can re-engage
		if str(contact.get("role", "")) == "charge" and bool(sit.get("is_objective", false)):
			sit["revealed"] = true
			# resolved stays false
			log_reason = "stage.contact.disengaged_objective_charge"
		else:
			# Mark situation resolved (no outcome) so the party won't re-engage
			sit["resolved"] = true
		situations[i] = sit
		break
	explore_map["situations"] = situations
	explore_map["pending_contact"] = {}
	explore_map["contact_responses"] = []
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.disengage_contact"

	logger.info(t, log_reason, "Player disengaged from NPC conversation", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})

	flow_ctx.last_snapshot = FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# Apply conversation outcome by role: intel clues, map reveals, objective, emotion, continuity, fear bleed.
func _apply_contact_outcome(
	contact: Dictionary, stage: Dictionary, explore_map: Dictionary, t: int
) -> void:
	var role    := str(contact.get("role",    "witness"))
	var outcome := str(contact.get("outcome", "failed"))
	var sit_id  := str(contact.get("id",      ""))

	var bal_v: Variant = config_service.get_balance().get("data", {})
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var contact_cfg_v: Variant = bal.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}

	# Find the situation in explore_map
	var sits_v: Variant = explore_map.get("situations", [])
	var map_situations: Array = sits_v if sits_v is Array else []
	var sit_ref: Dictionary = {}
	var sit_ref_idx := -1
	for _si in range(map_situations.size()):
		var _sv: Variant = map_situations[_si]
		if _sv is Dictionary and str((_sv as Dictionary).get("id", "")) == sit_id:
			sit_ref = _sv
			sit_ref_idx = _si
			break

	match role:
		"witness":
			if outcome == "good":
				if sit_ref_idx >= 0:
					var clues_v: Variant = sit_ref.get("intel_clues", [])
					var clues: Array = clues_v if clues_v is Array else []
					clues.append("A Witness shared what they saw here. The path ahead is clearer.")
					# V2-STAGE-003: check for thread_resonance clue
					var vp := str(contact.get("virtue_primary", ""))
					var vs := str(contact.get("virtue_secondary", ""))
					if not vp.is_empty():
						clues.append("thread_resonance|%s|%s" % [vp, vs])
					sit_ref["intel_clues"]   = clues
					sit_ref["intel_quality"] = "precise"
					map_situations[sit_ref_idx] = sit_ref
			elif outcome == "partial":
				if sit_ref_idx >= 0:
					var clues_v2: Variant = sit_ref.get("intel_clues", [])
					var clues2: Array = clues_v2 if clues_v2 is Array else []
					clues2.append("The Witness spoke carefully. Something was gleaned, though not all.")
					sit_ref["intel_clues"]   = clues2
					sit_ref["intel_quality"] = "rough"
					map_situations[sit_ref_idx] = sit_ref

		"guide":
			if outcome in ["good", "partial"]:
				var reveal_n := 2 if outcome == "good" else 1
				# Directive: seek_signs adds +1 reveal — persisted at stage_context.active_directive_id
				var _dir_id2 := str(flow_ctx.save_data.get("stage_context", {}).get("active_directive_id", "") \
					if flow_ctx.save_data.get("stage_context", null) is Dictionary else "")
				if "seek_signs" in _dir_id2:
					var dir_fx_v: Variant = contact_cfg.get("directive_effects", {}).get("seek_signs", {})
					var dir_fx: Dictionary = dir_fx_v if dir_fx_v is Dictionary else {}
					reveal_n += int(dir_fx.get("guide_reveal_bonus", 0))
				# Reveal nearest unrevealed situations
				var revealed_count := 0
				for _gi in range(map_situations.size()):
					if revealed_count >= reveal_n:
						break
					var _gs: Variant = map_situations[_gi]
					if not (_gs is Dictionary):
						continue
					var _gsd: Dictionary = _gs
					if not bool(_gsd.get("revealed", false)) and str(_gsd.get("id", "")) != sit_id:
						_gsd["revealed"] = true
						map_situations[_gi] = _gsd
						revealed_count += 1
				if outcome == "good":
					var vp2 := str(contact.get("virtue_primary", ""))
					var vs2 := str(contact.get("virtue_secondary", ""))
					if sit_ref_idx >= 0 and not vp2.is_empty():
						var gc_v: Variant = sit_ref.get("intel_clues", [])
						var gc: Array = gc_v if gc_v is Array else []
						gc.append("thread_resonance|%s|%s" % [vp2, vs2])
						sit_ref["intel_clues"] = gc
						map_situations[sit_ref_idx] = sit_ref

		"charge":
			var is_objective := bool(sit_ref.get("is_objective", false)) if not sit_ref.is_empty() else false
			var obj_index    := int(sit_ref.get("objective_index", -1)) if not sit_ref.is_empty() else -1
			if outcome == "good":
				if is_objective and obj_index >= 0:
					_mark_stage_objective_completed(flow_ctx, obj_index, t)
				# Party morale boost
				_apply_morale_to_party(+8, "contact.charge.good", t)
			elif outcome == "partial":
				_apply_morale_to_party(+4, "contact.charge.partial", t)
			elif outcome == "failed" and is_objective:
				# Automatic stage failure for objective-linked Charge
				contact["state"] = "failed"
				explore_map["pending_contact"] = {}
				explore_map["contact_responses"] = []
				var fail_count := int(explore_map.get("contact_fail_count", 0)) + 1
				explore_map["contact_fail_count"] = fail_count
				explore_map["situations"] = map_situations
				stage["explore_map"] = explore_map
				FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
				flow_ctx.save_request = true
				flow_ctx.save_request_reason = "stage.charge.fail"

				logger.info(t, "stage.charge.fail", "Objective Charge failed — stage abandoned", {
					"stage_id":       flow_ctx.stage_id,
					"situation_id":   sit_id,
					"contact_fail_count": fail_count,
				})

				flow_ctx.last_snapshot = _build_contact_resolve_snapshot(contact, "failed", false, t)
				flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "stage_abandoned_charge_fled")
				return

		"claimant":
			if outcome == "good":
				# Small Ase reward
				var _ase_reward := 20
				econ.add_ase(_ase_reward, "contact.claimant.good", logger, t)
				_apply_morale_to_party(+5, "contact.claimant.good", t)
			elif outcome == "partial":
				_apply_morale_to_party(+3, "contact.claimant.partial", t)
			elif outcome == "failed":
				contact["state"] = "failed"
				# Hostile slot (V2-STAGE-004 will wire actual combat) — surfaced via contact_result
				logger.info(t, "stage.claimant.hostile", "Claimant turned hostile", {
					"stage_id": flow_ctx.stage_id,
					"situation_id": sit_id,
				})

		"temporary_ally":
			if outcome == "good":
				contact["allied"] = true
				# Continuity gain
				var cont_pts := int(contact_cfg.get("continuity_temporary_ally_good", 5))
				ContinuityService.add_points(flow_ctx.save_data, cont_pts, "contact.ally.good", logger, t)
				logger.info(t, "stage.ally.gained", "Temporary ally earned", {
					"stage_id": flow_ctx.stage_id,
					"situation_id": sit_id,
				})
			elif outcome == "partial":
				# Parting intel clue
				if sit_ref_idx >= 0:
					var pa_v: Variant = sit_ref.get("intel_clues", [])
					var pa: Array = pa_v if pa_v is Array else []
					pa.append("The potential ally declined to join, but offered a parting word.")
					sit_ref["intel_clues"] = pa
					map_situations[sit_ref_idx] = sit_ref

	# Combat fear bleed on hard fail
	if outcome == "failed":
		var fear_bleed := int(contact_cfg.get("combat_fear_bleed", 8))
		if fear_bleed > 0:
			var _fb_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
			var _fb_sanctum: Dictionary = _fb_sanctum_v if _fb_sanctum_v is Dictionary else {}
			var _fb_roster_v: Variant = _fb_sanctum.get("roster", [])
			var _fb_roster: Array = _fb_roster_v if _fb_roster_v is Array else []
			var _fb_party_ids_v: Variant = _fb_sanctum.get("active_party_ids", [])
			var _fb_party_ids: Array = _fb_party_ids_v if _fb_party_ids_v is Array else []
			for _fb_echo_v in _fb_roster:
				if not (_fb_echo_v is Dictionary):
					continue
				var _fb_echo: Dictionary = _fb_echo_v
				if str(_fb_echo.get("id", "")) not in _fb_party_ids:
					continue
				EmotionService.apply_fear_delta(_fb_echo, fear_bleed, "contact.fail.fear_bleed", 80, logger, t)

	# Mark situation resolved
	if sit_ref_idx >= 0:
		sit_ref["resolved"] = true
		sit_ref["revealed"]  = true
		map_situations[sit_ref_idx] = sit_ref
		if bool(sit_ref.get("is_objective", false)) and outcome == "good":
			explore_map["objectives_found"] = int(explore_map.get("objectives_found", 0)) + 1

	explore_map["situations"] = map_situations
	explore_map["pending_contact"] = {}
	explore_map["contact_responses"] = []
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.contact.resolved"

	logger.info(t, "stage.contact.resolved", "NPC conversation resolved", {
		"stage_id":   flow_ctx.stage_id,
		"role":       role,
		"outcome":    outcome,
		"sit_id":     sit_id,
	})

	flow_ctx.last_snapshot = _build_contact_resolve_snapshot(contact, outcome, true, t)
	flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "stage.contact.resolve_screen")


# Returns a short, player-facing outcome description.
func _contact_outcome_text(role: String, outcome: String) -> String:
	match role + "." + outcome:
		"witness.good":    return "The Witness shared what they know. Intel written."
		"witness.partial": return "The Witness spoke carefully. Rough intel gathered."
		"witness.failed":  return "The Witness withdrew. Nothing was learned."
		"guide.good":      return "The Guide revealed the path ahead."
		"guide.partial":   return "The Guide hinted at nearby ground."
		"guide.failed":    return "The Guide fell silent. Nothing revealed."
		"charge.good":     return "The presence steadied. The objective is met."
		"charge.partial":  return "Some ground was found, but not enough."
		"charge.failed":   return "The Charge fled. The stage cannot continue."
		"claimant.good":   return "The Claimant's claim was heard. Terms agreed."
		"claimant.partial": return "The Claimant held their ground but did not escalate."
		"claimant.failed": return "The Claimant turned hostile."
		"temporary_ally.good":    return "An ally was earned."
		"temporary_ally.partial": return "The potential ally gave what they could, then left."
		"temporary_ally.failed":  return "The ally declined and departed."
	return "The conversation ended."


# Builds a flow.resolve snapshot for a concluded contact conversation.
# go_back_to_stage: true → cta.continue returns to flow.stage_explore; false → returns to flow.sanctum.
func _build_contact_resolve_snapshot(
	contact: Dictionary,
	outcome: String,
	go_back_to_stage: bool,
	t: int
) -> Dictionary:
	var role := str(contact.get("role", ""))
	var role_label := role.capitalize().replace("_", " ")

	# Try to get the authored outcome text from contact_responses.json
	var resp_data := _load_contact_responses()
	var outcome_texts_v: Variant = resp_data.get("outcome_texts", {})
	var outcome_texts: Dictionary = outcome_texts_v if outcome_texts_v is Dictionary else {}
	var outcome_text := str(outcome_texts.get(role + "/" + outcome, _contact_outcome_text(role, outcome)))

	var continue_to := FlowStateIds.STAGE_EXPLORE if go_back_to_stage else FlowStateIds.SANCTUM
	var continue_label := "Return to Stage" if go_back_to_stage else "Return to Sanctum"

	var _contact_verdict: String
	match outcome:
		"good":    _contact_verdict = "good"
		"partial": _contact_verdict = "partial"
		"failed":  _contact_verdict = "missed"
		_:         _contact_verdict = ""

	return {
		"type": FlowStateIds.RESOLVE,
		"data": {
			"run_type":    "contact_result",
			"role":        role,
			"role_label":  role_label,
			"outcome":     outcome,
			"outcome_text": outcome_text,
			# P1 CLOSE: additive fields for unified Resolve component.
			"surface":      "npc_contact",
			"verdict":      _contact_verdict,
			"summary_line": outcome_text,
		},
		"actions": {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    continue_to,
				"label": continue_label,
				"slot":  "cta.continue",
			},
		},
		"meta": { "t": t },
	}


# ────────────────────────────────────────────────────────────────────────────
# P1 CLOSE: Unified Resolve snapshot builder for in-explore situation outcomes.
# Mirrors _build_contact_resolve_snapshot. Called by _resolve_situation_to_screen.
# ────────────────────────────────────────────────────────────────────────────
func _build_situation_resolve_snapshot(
		sit: Dictionary,
		summary_line: String,
		emotion_summary: Array,
		effects: Array,
		ase_awarded: int,
		t: int
) -> Dictionary:
	var sit_type := str(sit.get("type", ""))

	# verdict: take-types → "carried"; acknowledge/leave (omen/ritual/npc) → "passed";
	# choice-resolved (obstacle/structure) → "passed".
	var _verdict: String
	match sit_type:
		SituationModelScript.TYPE_LOOT, SituationModelScript.TYPE_MONEY:
			_verdict = "carried"
		_:
			_verdict = "passed"

	var _breakdown: Array = []
	if ase_awarded > 0:
		_breakdown.append({ "label": "Found", "delta": ase_awarded, "currency": "ase" })

	return {
		"type": FlowStateIds.RESOLVE,
		"meta": { "t": t },
		"data": {
			"run_type":        "situation_result",
			"surface":         sit_type,
			"verdict":         _verdict,
			"summary_line":    summary_line,
			"emotion_summary": emotion_summary,
			"effects":         effects,
			"ase_awarded":     ase_awarded,
			"ekwan_awarded":   0,
			"reward_breakdown": _breakdown,
		},
		"actions": {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.STAGE_EXPLORE,
				"label": "Return to Stage",
				"slot":  "cta.continue",
			},
		},
	}


# P1 CLOSE: Shared helper — transitions to RESOLVE screen for a resolved in-explore situation.
# Keeps: resolved=true + save already set by caller. Only the OUTPUT (snapshot + transition) changes.
func _resolve_situation_to_screen(
		sit: Dictionary,
		_sit_id: String,
		emotion_summary: Array,
		effects: Array,
		summary_line: String,
		ase_awarded: int,
		t: int
) -> void:
	var _snap := _build_situation_resolve_snapshot(sit, summary_line, emotion_summary, effects, ase_awarded, t)
	flow_ctx.last_snapshot = _snap
	flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "stage.situation.resolve_screen")


# Maps a turn_score to a reaction word that keys into npc_followup in contact_responses.json.
func _derive_contact_reaction_word(turn_score: float) -> String:
	if turn_score > 0.8:  return "Opening"
	if turn_score >= 0.5: return "Steadied"
	if turn_score >= 0.3: return "Uncertain"
	return "Withdrawn"


# Returns a lazy-loaded dict from data/conversations/contact_responses.json.
# Cached after first load. Pure read — no side effects.
var _contact_responses_cache: Dictionary = {}
func _load_contact_responses() -> Dictionary:
	if not _contact_responses_cache.is_empty():
		return _contact_responses_cache
	var path := "res://data/conversations/contact_responses.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_contact_responses_cache = parsed
	return _contact_responses_cache


# Returns Array of echo dicts for all active party members.
func _get_active_party_echoes() -> Array:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var result: Array = []
	for echo_v in roster:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) in party_ids:
			result.append(echo)
	return result


# Apply morale delta to all active party echoes.
func _apply_morale_to_party(delta: int, reason: String, t: int) -> void:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if str(echo.get("id", "")) not in party_ids:
			continue
		EmotionService.apply_morale_delta(echo, delta, reason, logger, t)


# V2-STAGE-002: On combat victory, mark the situation resolved AND the objective completed
# in one operation. Called from _end_round() before build_final_snapshot() so that:
# (a) objectives_remaining is accurate in the resolve snapshot, and
# (b) if the player returns to stage_explore, the situation is already resolved and will
#     not be re-targeted by advance_turn.
func _resolve_combat_situation_and_objective(flow_ctx_arg: FlowContext, t: int) -> void:
	if flow_ctx_arg.stage_id.is_empty():
		return
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx_arg)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var vmap: Dictionary = map_v if map_v is Dictionary else {}
	var vsit_id := str(vmap.get("last_situation_id", ""))
	if vsit_id.is_empty():
		return
	var vsits_v: Variant = vmap.get("situations", [])
	if not (vsits_v is Array):
		return
	var vsits: Array = vsits_v
	for _vi in range(vsits.size()):
		var _vsv: Variant = vsits[_vi]
		if not (_vsv is Dictionary):
			continue
		if str((_vsv as Dictionary).get("id", "")) != vsit_id:
			continue
		var _vs: Dictionary = _vsv
		if bool(_vs.get("resolved", false)):
			break  # Already resolved (e.g. _handle_complete_stage ran first) — no-op
		_vs["resolved"] = true
		_vs["revealed"]  = true
		vsits[_vi] = _vs
		if bool(_vs.get("is_objective", false)):
			vmap["objectives_found"] = int(vmap.get("objectives_found", 0)) + 1
			# Mark the objective completed
			var _vobj_idx := int(_vs.get("objective_index", -1))
			if _vobj_idx >= 0:
				var _vstage_objs_v: Variant = stage.get("objectives", [])
				if _vstage_objs_v is Array:
					var _vstage_objs: Array = _vstage_objs_v
					if _vobj_idx < _vstage_objs.size() and _vstage_objs[_vobj_idx] is Dictionary:
						_vstage_objs[_vobj_idx]["completed"] = true
					stage["objectives"] = _vstage_objs
		vmap["situations"] = vsits
		stage["explore_map"] = vmap
		FlowStageExploreStateScript._write_stage_back(flow_ctx_arg, stage)
		flow_ctx_arg.save_request = true
		if flow_ctx_arg.save_request_reason.is_empty():
			flow_ctx_arg.save_request_reason = "stage.combat_resolved"
		else:
			flow_ctx_arg.save_request_reason += "|stage.combat_resolved"
		logger.info(t, "stage.combat_resolved", "Combat situation resolved on victory (pre-snapshot)", {
			"stage_id":     flow_ctx_arg.stage_id,
			"situation_id": vsit_id,
			"objective_index": int(_vsv.get("objective_index", -1) if _vsv is Dictionary else -1),
		})
		break


# V2-STAGE-002: Mark stage.objectives[objective_index].completed = true in save_data.
# Used for stub-completed types (recover/protect/endure/pursue) and after combat victory.
func _mark_stage_objective_completed(flow_ctx_arg: FlowContext, objective_index: int, t: int) -> void:
	if objective_index < 0:
		return
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx_arg)
	if stage.is_empty():
		return
	var objs_v: Variant = stage.get("objectives", [])
	if not (objs_v is Array):
		return
	var objs: Array = objs_v
	if objective_index < objs.size() and objs[objective_index] is Dictionary:
		objs[objective_index]["completed"] = true
		stage["objectives"] = objs
		FlowStageExploreStateScript._write_stage_back(flow_ctx_arg, stage)
		flow_ctx_arg.save_request = true
		if flow_ctx_arg.save_request_reason.is_empty():
			flow_ctx_arg.save_request_reason = "stage.objective.completed"
		else:
			flow_ctx_arg.save_request_reason += "|stage.objective.completed"
		logger.debug(t, "stage.objective.completed", "Stage objective marked completed", {
			"stage_id":        flow_ctx_arg.stage_id,
			"objective_index": objective_index,
		})


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-001 private helpers  (V2-STAGE-004-P2: rewritten — directive-weighted BFS scoring)
# ────────────────────────────────────────────────────────────────────────────

# Build the walkable set for an explore_map.
# Returns the StageTerrain-derived set when terrain is present.
# Falls back to a full width×height rectangle for legacy/empty saves so BFS
# and step movement work uniformly on all maps.
func _explore_walkable(explore_map: Dictionary) -> Dictionary:
	var terrain_v: Variant = explore_map.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	var walkable: Dictionary = StageTerrainScript.walkable_set(terrain)
	if not walkable.is_empty():
		return walkable
	# Legacy or empty terrain — fill a full rectangle so movement costs turns
	var w := int(explore_map.get("width",  30))
	var h := int(explore_map.get("height", 30))
	var full: Dictionary = {}
	for c in range(w):
		for r in range(h):
			full["%d,%d" % [c, r]] = true
	return full


# Find the best next unresolved situation using directive-weighted BFS scoring.
# Inputs:
#   explore_map  — current stage explore map
#   directive    — full directive dict (from DirectiveService.get_active_directive())
#   walkable     — pre-built walkable set (from _explore_walkable); empty = legacy all-open
# Scoring: weight = target_preference[category] * (1 / (bfs_distance + 1))
# Situations at BFS distance 0 are skipped (party parked on them) unless all remaining
# are at distance 0, in which case the highest-weighted one is returned so re-engagement works.
func _find_target_situation(explore_map: Dictionary, directive: Dictionary, walkable: Dictionary) -> Dictionary:
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }

	# Resolve situation_category map from balance config
	var sit_cat_map: Dictionary = {}
	if config_service != null:
		var _b_v: Variant = config_service.get_balance()
		var _b: Dictionary = _b_v if _b_v is Dictionary else {}
		var _bd_v: Variant = _b.get("data", {})
		var _bd: Dictionary = _bd_v if _bd_v is Dictionary else {}
		var _bs_v: Variant = _bd.get("stages", {})
		var _bs: Dictionary = _bs_v if _bs_v is Dictionary else {}
		var _sc_v: Variant = _bs.get("situation_category", {})
		sit_cat_map = _sc_v if _sc_v is Dictionary else {}

	var target_pref_v: Variant = directive.get("target_preference", {})
	var target_pref: Dictionary = target_pref_v if target_pref_v is Dictionary else {}

	# BFS distance field from party position
	var dist_from_party: Dictionary = {}
	if not walkable.is_empty():
		dist_from_party = StageTerrainScript.bfs_distance_field(party_pos, walkable)

	var best_sit: Dictionary = {}
	var best_score := -1.0
	var best_d0_sit: Dictionary = {}
	var best_d0_score := -1.0

	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue

		var pos_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }

		# Determine BFS distance (fallback to Chebyshev for legacy all-open maps)
		var d: int
		if dist_from_party.is_empty():
			d = GridService.chebyshev_distance(party_pos, pos)
		else:
			var pk: String = "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]
			var d_v: Variant = dist_from_party.get(pk, -1)
			d = int(d_v)
			if d < 0:
				continue  # Unreachable — skip

		# Determine category generically (no directive id names allowed)
		var sit_type := str(sit.get("type", ""))
		var category: String
		if bool(sit.get("is_objective", false)):
			category = "objective"
		else:
			category = str(sit_cat_map.get(sit_type, "intel"))

		var weight := float(target_pref.get(category, 1.0))
		var score := weight * (1.0 / (float(d) + 1.0))

		if d == 0:
			# Collect best d==0 candidate separately for the fallback path
			if score > best_d0_score:
				best_d0_score = score
				best_d0_sit   = sit
		else:
			if score > best_score:
				best_score = score
				best_sit   = sit

	if not best_sit.is_empty():
		return best_sit

	# Fallback: all remaining unresolved situations are at d==0.
	# Return the highest-weighted one so re-engagement is always possible.
	if not best_d0_sit.is_empty():
		return best_d0_sit

	return {}


# V2-STAGE-004 Phase 2.5: Four-tier fog-of-war target selection.
# Replaces _find_target_situation as the sole caller in _handle_stage_advance_turn.
#
# Priority:
#   Tier 1 — nearest DISCOVERED unresolved OBJECTIVE situation (BFS distance),
#             excluding nodes where passed==true (player skipped them; let them explore).
#   Tier 2 — best DISCOVERED unresolved non-objective situation scored by directive
#             target_preference[category], excluding passed==true nodes,
#             only when score >= 1.0 and reachable.
#   Tier 3 — FRONTIER: nearest walkable cell not yet in explored_cells (BFS, deterministic).
#             Returns synthetic { "id": "", "pos": <cell>, "is_frontier": true }.
#   Tier 4 — FRONTIER EXHAUSTED (nearest_unexplored == party_pos, i.e. whole map explored):
#             Re-offer the nearest unresolved OBJECTIVE including passed ones — so the stage
#             remains completable when all optional nodes were skipped.
#             Non-objective passed nodes are NEVER re-offered (player dismissed them on purpose).
#             If no objective exists either, returns {} (nothing left; party parks).
#
# No directive ID may be named here. All behaviour comes from reading directive fields.
func _find_explore_target(
	explore_map: Dictionary,
	directive: Dictionary,
	walkable: Dictionary,
	explored_cells: Dictionary
) -> Dictionary:
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }

	# BFS distance field from party position (used for Tier 1 and Tier 2 BFS distances).
	var dist_from_party: Dictionary = {}
	if not walkable.is_empty():
		dist_from_party = StageTerrainScript.bfs_distance_field(party_pos, walkable)

	# ---- Tier 1: discovered, unresolved OBJECTIVE situations (not passed) ----
	var best_obj_sit: Dictionary = {}
	var best_obj_dist: int = 999999
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if not bool(sit.get("is_objective", false)):
			continue
		if not bool(sit.get("revealed", false)):
			continue  # undiscovered — fog; not targetable
		if bool(sit.get("passed", false)):
			continue  # player skipped it — do not re-target until Tier 4
		var pos_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var d: int
		if dist_from_party.is_empty():
			d = GridService.chebyshev_distance(party_pos, pos)
		else:
			var pk: String = "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]
			var d_v: Variant = dist_from_party.get(pk, -1)
			if int(d_v) < 0:
				continue  # unreachable
			d = int(d_v)
		if d < best_obj_dist:
			best_obj_dist = d
			best_obj_sit  = sit
	if not best_obj_sit.is_empty():
		return best_obj_sit

	# ---- Tier 2: discovered, unresolved non-objective situations (directive-biased, not passed) ----
	var sit_cat_map: Dictionary = {}
	if config_service != null:
		var _b_v: Variant = config_service.get_balance()
		var _b: Dictionary = _b_v if _b_v is Dictionary else {}
		var _bd_v: Variant = _b.get("data", {})
		var _bd: Dictionary = _bd_v if _bd_v is Dictionary else {}
		var _bs_v: Variant = _bd.get("stages", {})
		var _bs: Dictionary = _bs_v if _bs_v is Dictionary else {}
		var _sc_v: Variant = _bs.get("situation_category", {})
		sit_cat_map = _sc_v if _sc_v is Dictionary else {}

	var target_pref_v: Variant = directive.get("target_preference", {})
	var target_pref: Dictionary = target_pref_v if target_pref_v is Dictionary else {}

	var best_sit: Dictionary = {}
	var best_score := -1.0
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if bool(sit.get("is_objective", false)):
			continue  # handled in Tier 1
		if not bool(sit.get("revealed", false)):
			continue  # undiscovered — fog; not targetable
		if bool(sit.get("passed", false)):
			continue  # player skipped it; never re-target non-objective passed nodes
		var pos_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var d: int
		if dist_from_party.is_empty():
			d = GridService.chebyshev_distance(party_pos, pos)
		else:
			var pk: String = "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]
			var d_v: Variant = dist_from_party.get(pk, -1)
			if int(d_v) < 0:
				continue  # unreachable
			d = int(d_v)
		var sit_type := str(sit.get("type", ""))
		var category := str(sit_cat_map.get(sit_type, "intel"))
		var weight := float(target_pref.get(category, 1.0))
		var score := weight * (1.0 / (float(d) + 1.0))
		if score > best_score:
			best_score = score
			best_sit   = sit
	# Only commit to a discovered node if the directive meaningfully prefers it (weight >= 1.0).
	if not best_sit.is_empty() and best_score >= 1.0:
		return best_sit

	# ---- Tier 3: frontier — nearest walkable unexplored cell ----
	var frontier_cell := StageTerrainScript.nearest_unexplored(party_pos, walkable, explored_cells)
	var fk: String = "%d,%d" % [int(frontier_cell.get("col", 0)), int(frontier_cell.get("row", 0))]
	var pk_party: String = "%d,%d" % [int(party_pos.get("col", 0)), int(party_pos.get("row", 0))]
	if fk != pk_party:
		# There is still unexplored frontier — head there.
		return { "id": "", "pos": frontier_cell, "is_frontier": true }

	# ---- Tier 4: frontier exhausted — re-offer nearest unresolved OBJECTIVE (including passed) ----
	# The whole reachable map is explored. If the player had previously passed an objective,
	# the stage cannot be completed until they engage it — re-offer it here so the stage stays
	# completable. Non-objective passed nodes are NOT re-offered.
	var best_obj4_sit: Dictionary = {}
	var best_obj4_dist: int = 999999
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if not bool(sit.get("is_objective", false)):
			continue  # only objectives are re-offered (non-objective passed nodes stay skipped)
		if not bool(sit.get("revealed", false)):
			continue  # still fog — cannot target
		var pos_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var d: int
		if dist_from_party.is_empty():
			d = GridService.chebyshev_distance(party_pos, pos)
		else:
			var pk4: String = "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]
			var d_v: Variant = dist_from_party.get(pk4, -1)
			if int(d_v) < 0:
				continue  # unreachable
			d = int(d_v)
		if d < best_obj4_dist:
			best_obj4_dist = d
			best_obj4_sit  = sit
	if not best_obj4_sit.is_empty():
		return best_obj4_sit

	# Nothing left — whole map explored and nothing actionable remains (or all situations resolved).
	return {}


# Mark a specific situation as revealed in save_data.
func _mark_situation_revealed(stage: Dictionary, sit_id: String, t: int) -> void:
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s["revealed"] = true
			situations[i] = s
			break

	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.reveal"

	logger.info(t, "stage.situation.revealed", "Situation revealed before engagement", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})


# V2-INTEL-001: Returns the atmospheric intel clue written to a situation on first scout reveal.
# Not called on direct engagement — engagement-reveal is firsthand, not prior intel.
# Delegates to the static in FlowStageExploreState (single source of truth for the match table).
func _intel_clue_for_type(sit_type: String) -> String:
	return FlowStageExploreStateScript._intel_clue_for_type_static(sit_type)


# ── V2-VOICE-001: Sanctum bark helpers ───────────────────────────────────────

## Selects up to `voice.sanctum_max_barkers` (default 2) party echoes to receive a sanctum bark.
## Step 1: event echo (most directly involved). Step 2: urgency tiebreaker.
## party_actors: Array of runtime actor dicts (faction=echo, from ectx.actors).
## Returns Array[Dictionary] of ≤2 actor dicts.
func _select_sanctum_barkers(party_actors: Array, event_echo_id: String, t: int) -> Array:
	var voice_cfg: Dictionary = config_service.get_balance().get("data", {}).get("voice", {})
	var max_barkers: int = int(voice_cfg.get("sanctum_max_barkers", 2))
	if party_actors.is_empty():
		return []

	var result: Array = []
	var remaining: Array = []

	# Step 1: prioritise the event echo.
	for a_v in party_actors:
		var a: Dictionary = a_v
		if str(a.get("id", "")) == event_echo_id:
			result.append(a)
		else:
			remaining.append(a)

	if result.is_empty():
		remaining = party_actors.duplicate()

	if result.size() >= max_barkers or remaining.is_empty():
		return result

	# Step 2: urgency tiebreaker — highest urgency score wins.
	var urgency_sorted: Array = remaining.duplicate()
	urgency_sorted.sort_custom(func(aa, bb):
		return _voice_urgency_score(aa) > _voice_urgency_score(bb)
	)
	result.append(urgency_sorted[0])
	return result


## Urgency score for sanctum barker selection.
## (morale_tier == "broken" ? 30 : 0) + fear_current - morale_current
func _voice_urgency_score(actor: Dictionary) -> int:
	var morale: int = int(actor.get("morale", 50))
	var fear: int   = int(actor.get("fear",   0))
	var broken_bonus: int = 30 if morale < 25 else 0
	return broken_bonus + fear - morale


## Computes expression_band for a save-data echo dict using rank + config.
## Falls back to "nascent" if config is missing.
func _get_expression_band_for_echo(echo: Dictionary) -> String:
	var bal: Dictionary = config_service.get_balance()
	var maturity_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var band_by_standing: Dictionary = maturity_cfg.get("band_by_standing", {})
	if band_by_standing.is_empty():
		return "nascent"
	var rank: int = int(echo.get("rank", 1))
	return MaturityExpressionService.get_expression_band(rank, band_by_standing)


## Selects a sanctum bark for a runtime actor dict and writes `_sanctum_bark` to
## the matching save-data roster entry.
## actor: runtime actor dict (has id, archetype_birth, calling_origin, morale, fear).
## roster: save-data Array (mutated in place).
func _select_sanctum_bark_for_actor_and_write(actor: Dictionary, context_key: String, t: int, roster: Array) -> void:
	var arch    := str(actor.get("archetype_birth", "loyal"))
	var calling := str(actor.get("calling_origin", ""))
	var band    := str(actor.get("expression_band", "nascent"))
	var vk: int = (t + str(actor.get("id", "")).hash()) % 997
	var line    := ShoutBank.get_expression_shout(context_key, arch, band, calling, vk)
	if line.is_empty():
		return
	var bark := { "line": line, "context": context_key }
	var actor_id := str(actor.get("id", ""))
	for i in range(roster.size()):
		if roster[i] is Dictionary and str((roster[i] as Dictionary).get("id", "")) == actor_id:
			(roster[i] as Dictionary)["_sanctum_bark"] = bark
			return


## Selects a sanctum bark for a save-data echo dict and writes `_sanctum_bark` to
## the matching roster entry.
## echo_data: save-data echo dict (has id, archetype_birth, calling_origin, rank).
## roster: save-data Array (mutated in place).
func _select_sanctum_bark_for_echo_data_and_write(echo_data: Dictionary, context_key: String, t: int, roster: Array) -> void:
	var arch    := str(echo_data.get("archetype_birth", "loyal"))
	var calling := str(echo_data.get("calling_origin", ""))
	var band    := _get_expression_band_for_echo(echo_data)
	var vk: int = (t + str(echo_data.get("id", "")).hash()) % 997
	var line    := ShoutBank.get_expression_shout(context_key, arch, band, calling, vk)
	if line.is_empty():
		return
	var bark := { "line": line, "context": context_key }
	var echo_id := str(echo_data.get("id", ""))
	for i in range(roster.size()):
		if roster[i] is Dictionary and str((roster[i] as Dictionary).get("id", "")) == echo_id:
			(roster[i] as Dictionary)["_sanctum_bark"] = bark
			return


## Selects arrival barks for up to 2 party echoes and writes them to save-data roster entries.
## Called in _end_round() BEFORE build_final_snapshot() so the snapshot can include arrival_bark.
## is_victory: true = victory context, false = defeat.
func _select_arrival_barks_for_party(is_victory: bool, t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var roster_v: Variant  = sanctum.get("roster", [])
	var roster: Array      = roster_v if roster_v is Array else []
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array   = party_ids_v if party_ids_v is Array else []

	# Collect alive party echo actors from ectx (runtime, post-combat values).
	var party_actors: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		if not (str(a.get("id", "")) in party_ids):
			continue
		party_actors.append(a)

	if party_actors.is_empty():
		return

	# Event echo: on defeat, the echo with highest fear; on victory, none (urgency only).
	var event_echo_id := ""
	if not is_victory:
		var max_fear := -1
		for a_v in party_actors:
			var a: Dictionary = a_v
			var f: int = int(a.get("fear", 0))
			if f > max_fear:
				max_fear = f
				event_echo_id = str(a.get("id", ""))

	var base_ctx := "sanctum.arrival_victory" if is_victory else "sanctum.arrival_defeat"
	var barkers: Array = _select_sanctum_barkers(party_actors, event_echo_id, t)

	for actor_v in barkers:
		var actor: Dictionary = actor_v
		# Overlay broken bark if morale < 25 (broken tier).
		var bark_ctx := base_ctx
		if int(actor.get("morale", 50)) < 25:
			bark_ctx = "sanctum.broken"
		_select_sanctum_bark_for_actor_and_write(actor, bark_ctx, t, roster)

	sanctum["roster"] = roster
	flow_ctx.save_data["sanctum"] = sanctum
	logger.debug(t, "voice.arrival_barks_written", "Arrival barks written", {
		"is_victory":   is_victory,
		"barker_count": barkers.size(),
	})


## V2-VOW-002: Pure probe — evaluates whether a stage-complete vow benefit is due and stores a
## provisional vow_outcome on FlowContext so build_final_snapshot() can include it in the
## resolve snapshot. No emotion mutations here; actual deltas are applied later by
## _apply_vow_stage_complete_benefit() inside _handle_complete_stage().
func _store_vow_benefit_preview(t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return
	# Do not overwrite a break outcome already stored this stage.
	if not flow_ctx.vow_outcome.is_empty():
		return
	var cfg := config_service.get_balance()
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v
	var result := VowService.evaluate_stage_complete_benefit(flow_ctx.save_data, situations, cfg)
	var morale_d := int(result.get("morale_delta", 0))
	if morale_d == 0:
		return  # no benefit due — leave vow_outcome empty
	var defn := VowService.get_definition(str(av.get("vow_id", "")), cfg)
	var party_ids: Array = []
	var sanctum_vp: Variant = flow_ctx.save_data.get("sanctum", {})
	if sanctum_vp is Dictionary:
		var p_v: Variant = (sanctum_vp as Dictionary).get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v
	flow_ctx.vow_outcome = {
		"event":            "benefit",
		"vow_id":           str(av.get("vow_id", "")),
		"vow_name":         str(defn.get("vow_name", "")),
		"proverb_twi":      str(defn.get("proverb_twi", "")),
		"tier":             int(av.get("tier", 1)),
		"morale_delta":     morale_d,
		"fear_delta":       0,
		"bond_score_delta": 0,
		"ase_delta":        0,
		"echoes_affected":  party_ids,
	}


## V2-VOW-002: Returns Array of echo id Strings from the save-data roster.
## Used by _apply_vow_break_aftermath() to populate vow_outcome.echoes_affected.
func _get_roster_echo_ids() -> Array:
	var ids: Array = []
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return ids
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return ids
	for echo_v in (roster_v as Array):
		if echo_v is Dictionary:
			ids.append(str((echo_v as Dictionary).get("id", "")))
	return ids


# ---------------------------------------------------------------------------
# V2-SANCTUM-001 — Emotion recovery + consequence helpers
# ---------------------------------------------------------------------------

func _get_emotion_recovery_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	var rec_v: Variant = emo.get("recovery", {})
	return rec_v if rec_v is Dictionary else {}


func _get_fear_threshold() -> int:
	var drift := _get_drift_cfg()
	return int(drift.get("fear_threshold", 80))


func _apply_emotion_recovery_if_needed(now_unix: int, t: int) -> void:
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	if not (econ_v is Dictionary):
		return
	var econ_data: Dictionary = econ_v as Dictionary
	var last_settle := int(econ_data.get("last_emotion_settle_unix", 0))
	if last_settle <= 0:
		econ_data["last_emotion_settle_unix"] = now_unix
		_mark_save_requested("emotion.recovery_clock")
		return

	var elapsed := now_unix - last_settle
	if elapsed <= 0:
		return

	var cfg := _get_emotion_recovery_cfg()
	if cfg.is_empty():
		return

	var fear_threshold := _get_fear_threshold()
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	# V2-PROG-010: pass full cfg_data so EmotionRecoveryService can apply rank-based fear bonus.
	var _emo_cfg_data: Dictionary = {}
	if flow_ctx.config_service != null:
		_emo_cfg_data = flow_ctx.config_service.get_balance().get("data", {})
	var changed := EmotionRecoveryServiceScript.apply_recovery_from_elapsed(
		roster, elapsed, cfg, fear_threshold, logger, t, _emo_cfg_data)

	if changed.size() > 0:
		sanctum["roster"] = roster
		flow_ctx.save_request = true
		if flow_ctx.save_request_reason.is_empty():
			flow_ctx.save_request_reason = "emotion.recovery"
		else:
			flow_ctx.save_request_reason += "|emotion.recovery"
		logger.info(t, "emotion.recovery", "Emotion recovery applied", {
			"elapsed_seconds": elapsed,
			"echoes_changed":  changed.size(),
		})

	econ_data["last_emotion_settle_unix"] = now_unix
	# Persist the consumed recovery window even when rounding/clamps produced no
	# emotion delta; otherwise a later dispatch can settle the same elapsed time twice.
	_mark_save_requested("emotion.recovery_clock")


func _apply_run_emotion_modifiers(outcome: String, t: int) -> void:
	var cfg := _get_emotion_recovery_cfg()
	if cfg.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return

	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	var ticks := int(cfg.get("modifier_ticks_duration", 3))

	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v as Dictionary
		if not party_ids.has(str(echo.get("id", ""))):
			continue
		var morale_mul := 1.0
		var fear_mul   := 1.0
		match outcome:
			"victory":
				morale_mul = float(cfg.get("modifier_victory_morale_mul",  1.5))
			"defeat":
				fear_mul   = float(cfg.get("modifier_defeat_fear_mul",     0.5))
			"withdrawal":
				morale_mul = float(cfg.get("modifier_survived_morale_mul", 1.25))
		EmotionRecoveryServiceScript.set_modifier(echo, morale_mul, fear_mul, ticks, logger, t)

	# V2-SANCTUM-002: compose institution modifiers with run-outcome modifiers for party echoes
	var _inst_cfg := _get_institutions_cfg()
	var _bldg_cfg := _get_buildings_cfg()
	if not _inst_cfg.is_empty() and not _bldg_cfg.is_empty():
		for echo_v2 in roster:
			if not (echo_v2 is Dictionary):
				continue
			var echo2: Dictionary = echo_v2 as Dictionary
			var echo2_id := str(echo2.get("id", ""))
			if not party_ids.has(echo2_id):
				continue
			var inst_for := InstitutionServiceScript.find_institution_for_echo(echo2_id, flow_ctx.save_data)
			if inst_for.is_empty():
				continue
			var cond := InstitutionServiceScript.get_condition(inst_for, flow_ctx.save_data)
			if cond == InstitutionServiceScript.CONDITION_NEGLECTED:
				continue
			var b_cfg: Dictionary = _bldg_cfg.get(inst_for, {}) as Dictionary
			var inst_morale := float(b_cfg.get("morale_mul_" + cond, 1.0))
			var inst_fear   := float(b_cfg.get("fear_mul_"   + cond, 1.0))
			var inst_ticks  := int(b_cfg.get("ticks", ticks))
			var rm: Dictionary = echo2.get("recovery_modifiers", {}) as Dictionary
			var existing_morale := float(rm.get("morale_multiplier", 1.0))
			var existing_fear   := float(rm.get("fear_multiplier",   1.0))
			EmotionRecoveryServiceScript.set_modifier(echo2, existing_morale * inst_morale, existing_fear * inst_fear, inst_ticks, logger, t)

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason.is_empty():
		flow_ctx.save_request_reason = "emotion.run_modifier"
	else:
		flow_ctx.save_request_reason += "|emotion.run_modifier"


func _check_vow_release_condition(t: int) -> bool:
	var active_vow := VowService.get_active_vow(flow_ctx.save_data)
	if active_vow.is_empty():
		return false
	var vow_outcome_v: Variant = flow_ctx.save_data.get("flow", {})
	if vow_outcome_v is Dictionary:
		var vow_outcome_dict: Dictionary = (vow_outcome_v as Dictionary).get("vow_outcome", {})
		if str(vow_outcome_dict.get("event", "")) == "benefit":
			VowService.release_vow(flow_ctx.save_data, null, logger, t)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason.is_empty():
				flow_ctx.save_request_reason = "vow.released"
			else:
				flow_ctx.save_request_reason += "|vow.released"
			return true
	return false


## _build_run_consequence_notification removed — Resolve screen already presents this data.
