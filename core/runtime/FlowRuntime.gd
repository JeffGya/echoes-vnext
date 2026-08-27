# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

# V2-INFRA-003 Phase 5 Slice D: six venture preload consts (FlowStageExploreStateScript,
# StageExploreModelScript, SituationModelScript, ObjectiveModelScript,
# SituationResolutionServiceScript, ConversationServiceScript) were orphaned by this
# slice — every remaining reference moved to VentureController /
# ActiveStageService / ContactConversationService, which reach those classes by
# their global class_name. Removed rather than left preloading venture code this file
# no longer touches.
const FlowKeeperIntroStateScript  := preload("res://core/state/flow/states/onboarding/FlowKeeperIntroState.gd")
const KeeperIntroServiceScript    := preload("res://core/onboarding/KeeperIntroService.gd")
const StageTerrainScript               := preload("res://core/realms/StageTerrain.gd")                  # V2-STAGE-004-P2
const PursueEscapeServiceScript        := preload("res://core/movement/PursueEscapeService.gd")
const GuideSpiritActivationServiceScript := preload("res://core/movement/GuideSpiritActivationService.gd")
## ConsequencePassService kept on disk for future use; not preloaded here.
const EmotionRecoveryServiceScript := preload("res://core/emotion/EmotionRecoveryService.gd")                    # V2-SANCTUM-001
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
		var snap := _build_config_error_snapshot(flow_ctx.sim_tick)
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
		_mark_save_requested("save.recovery_retry")

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
	#
	# V2-INFRA-003 Phase 8C: the prologue Realm is excluded from this generic scan and restored
	# EXPLICITLY below instead. Two reasons, and both matter:
	#   - a prologue left "active" in an old save must never win this scan over a real Realm,
	#     which would silently point a resumed campaign at the internal run;
	#   - the prologue is nonetheless resumable. Quitting mid-prologue and pressing Continue has
	#     to put the player back into it, and `onboarding.opening_realm_status == "active"` is
	#     the authoritative statement that it is the run in progress — which is exactly what
	#     D85 observed `save.flow.state` was supposed to be and never became.
	# A real Realm always wins: the explicit restore only fires if the scan found nothing.
	var _boot_realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var _boot_realms: Dictionary = _boot_realms_v if _boot_realms_v is Dictionary else {}
	for _rid in _boot_realms:
		if RealmService.is_prologue_run(str(_rid)):
			continue
		var _rm: Dictionary = _boot_realms[_rid] if _boot_realms[_rid] is Dictionary else {}
		if _rm.get("status", "") == "active":
			flow_ctx.realm_id = str(_rid)
			break
	if flow_ctx.realm_id.is_empty() \
			and OpeningRealmService.get_status(flow_ctx.save_data) == OpeningRealmService.STATUS_ACTIVE:
		var _boot_prologue_v: Variant = _boot_realms.get(RealmService.PROLOGUE_REALM_ID, {})
		var _boot_prologue: Dictionary = _boot_prologue_v if _boot_prologue_v is Dictionary else {}
		if str(_boot_prologue.get("status", "")) == "active":
			flow_ctx.realm_id = RealmService.PROLOGUE_REALM_ID

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

## V2-INFRA-003 Slice B1: the boot-time config-load-failure snapshot, in the same
## four-key shape as every other flow snapshot ("flow.config_error" does not collide
## with any registered FlowStateIds entry). Extracted to a static helper so the exact
## shape production emits can be unit-tested directly (see tests/SnapshotContractTests.gd)
## without needing to force a real config file failure.
static func _build_config_error_snapshot(t: int) -> Dictionary:
	return {
		"type": "flow.config_error",
		"meta": { "t": t },
		"data": { "message": "Configuration validation failed. See logs." },
		"actions": {},
	}

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
	# Weave commitment lock blocks the action from entering the match below, but dispatch
	# still falls through to the common closure (encounter bootstrap + save flush) so a
	# save queued by an earlier dispatch is never left stranded behind a locked action.
	var weave_locked := flow_ctx.weave_commit_locked and action_type != "weave.confirm"
	if weave_locked:
		logger.debug(t, "weave.commit.locked", "Action blocked by weaving commitment lock", {
			"blocked_action": action_type,
		})

	if not weave_locked:
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
						# FIX (P4 review bug 2): the defeat RESOLVE→SANCTUM path skipped ally-field
						# teardown entirely — clear before nulling ctx, mirroring the encounter.complete
						# and _handle_complete_stage call sites, so a stale combat_intro_reason/offer
						# never leaks onto the next unrelated encounter.
						_recruitment_consequence_service().clear_ally_fields_if_present(t)
						flow_ctx.encounter_ctx     = null
						flow_ctx.encounter_machine = null
						_emotion_consequence_service().apply_run_emotion_modifiers("defeat", t)
						_vow_consequence_service().check_vow_release_condition(t)
					else:
						_emotion_consequence_service().apply_sanctum_emotion_tick(t)
				elif to_state == FlowStateIds.WEAVING_RITE:
					flow_ctx.selected_weave_thread_id = ""
					flow_ctx.selected_weave_echo_id = ""
					flow_ctx.weave_commit_locked = false
					flow_ctx.weave_resolution = {}
				elif to_state == FlowStateIds.STAGE_EXPLORE:
					# P1-FIX: non-final objective victory returns to stage_explore via go_state.
					# V2-STAGE-004 Phase 4 (S14): extracted into _apply_victory_return_to_explore()
					# — pure move, no behaviour change for this call site.
					_apply_victory_return_to_explore(t)
				flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")
	
			# V2-INFRA-003 Phase 5 Slice D: routed to VentureController.
			"flow.select_realm":
				_apply_action_outcome(_venture_controller().handle_select_realm(action, t), t)

			# V2-INFRA-003 Phase 6 Slice 6F: routed to VentureController. Slice D's STEP 0a
			# blocker (this body called _progression_controller().persist_equipped_skills(t),
			# and a controller may never call another controller) is gone — that function is
			# now core/progression/SkillLoadoutService.gd. This was the last of the routed
			# actions with a provisional owner.
			"flow.select_stage":
				_apply_action_outcome(_venture_controller().handle_select_stage(action, t), t)
	
			# REALM-004: advance stage index; on realm complete, route to REALM_SELECT.
			# destination override allows cta.continue on victory to route to SANCTUM instead of STAGE_MAP.
			"flow.complete_stage":
				_apply_action_outcome(_venture_controller().handle_complete_stage(action, t), t)
	
			"flow.continue":
				var is_first_boot: bool = bool(flow_ctx.save_data.get("first_boot", true))
				if is_first_boot:
					flow_ctx.save_data["first_boot"] = false
					_mark_save_requested("continue_first_boot")
	
				_offline_accrual_service().apply_if_needed(t, "flow.continue")
				# V2-SANCTUM-001: time-based emotion recovery catch-up on session continue
				var _cont_unix := int(Time.get_unix_time_from_system())
				_emotion_consequence_service().apply_emotion_recovery_if_needed(_cont_unix, t)
	
				# PROG-001: patch old echo dicts that pre-date draw-order v2 fields
				# V2-INFRA-003 Phase 4 Slice 8: SanctumService.repair_echo_schema() is now a
				# static function (moved from FlowRuntime._repair_echo_schema) — see the note
				# near the old definition site for why it did not move to SanctumController.
				if SanctumService.repair_echo_schema(flow_ctx.save_data, logger, t):
					_mark_save_requested("sanctum.schema.repair")
	
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
						KeeperIntroServiceScript.setup_trial_encounter(flow_ctx, _continue_cfg, t)
					flow_machine.transition(
						KeeperIntroServiceScript.step_to_flow_id(_keeper_step),
						flow_ctx,
						logger,
						t,
						"ui.flow.continue.keeper_intro"
					)
				elif PendingResultService.has_pending(flow_ctx.save_data):
					# V2-INFRA-003 Phase 8B: a run ended and its result was never seen through.
					# Route back to the card instead of the Sanctum. FlowResolveState.enter()
					# rebuilds it from save.flow.pending_result (producer G) — there is no live
					# snapshot to pass through after a relaunch, which is exactly why the
					# durable record exists.
					#
					# PLACED LAST of the three branches, after onboarding and the keeper intro,
					# so neither resume path changes. It cannot compete with them in practice:
					# a pending result is only ever written while a realm is active
					# (PendingResultService.capture_or_consume gates on flow_ctx.realm_id) and
					# the keeper trial runs with realm_id "".
					PendingResultService.restore_run_context(flow_ctx)
					flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.flow.continue.pending_result")
				else:
					flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")
	
			"flow.settings":
				logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})
	
			"flow.quit":
				logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})
	
			# ---- Chapter I onboarding ----
			# V2-INFRA-003 Phase 4 Slice 9 (Part A): routed to OnboardingController. The
			# controller returns a FlowActionOutcome describing what should happen (transition /
			# replacement snapshot / save) — it never transitions or saves by itself.
			# _apply_action_outcome() is the single place that acts on it.
			"onboarding.advance":
				_apply_action_outcome(_onboarding_controller().handle_advance(t), t)

			"onboarding.fragment.hear":
				_apply_action_outcome(_onboarding_controller().handle_fragment_hear(action, t), t)

			"onboarding.fragment.select":
				_apply_action_outcome(_onboarding_controller().handle_fragment_select(action, t), t)

			"onboarding.fragment.confirm":
				_apply_action_outcome(_onboarding_controller().handle_fragment_confirm(t), t)

			"onboarding.name.confirm":
				_apply_action_outcome(_onboarding_controller().handle_name_confirm(action, t), t)
	
			# ---- Keeper intro after Chapter I ----
			# V2-INFRA-003 Phase 4 Slice 9 (Part B): routed to OnboardingController (same
			# controller/factory as the Part A onboarding.* actions above).
			"keeper_intro.call.answer":
				_apply_action_outcome(_onboarding_controller().handle_call_answer(t), t)

			"keeper_intro.trial.finish":
				_apply_action_outcome(_onboarding_controller().handle_trial_finish(t), t)

			"keeper_intro.rewind.continue":
				_apply_action_outcome(_onboarding_controller().handle_rewind_continue(t), t)

			"keeper_intro.thread.continue":
				_apply_action_outcome(_onboarding_controller().handle_thread_continue(t), t)

			"keeper_intro.awakening.choose":
				_apply_action_outcome(_onboarding_controller().handle_awakening(action, t), t)

			"keeper_intro.weave.complete":
				_apply_action_outcome(_onboarding_controller().handle_weave(t), t)

			"keeper_intro.complete":
				_apply_action_outcome(_onboarding_controller().handle_complete(t), t)
	
			# ---- Debug Seed (SANCTUM-002) ----
			# V2-INFRA-003 Phase 4 Slice 6a: DebugController owns these actions. Controllers
			# report intent via FlowActionOutcome; they never transition or save by themselves.
			# _apply_action_outcome() is the single place that acts on it.
			"debug.seed.show":
				_apply_action_outcome(_debug_controller().handle_seed_show(t), t)

			"debug.seed.set":
				_apply_action_outcome(_debug_controller().handle_seed_set(action, t), t)

			"debug.seed.reset":
				_apply_action_outcome(_debug_controller().handle_seed_reset(action, t), t)

			# ---- Debug Echo (SANCTUM-002) ----
			"debug.echo.gen_test":
				_apply_action_outcome(_debug_controller().handle_echo_gen_test(t), t)
	
			# ────────────────────────────────────────────────────────────────────
			# COMBAT / ENCOUNTER — FlowRuntime OWNS these six actions. THIS IS A
			# DECISION, NOT AN UNFINISHED STATE. There is no CombatController, and
			# there is deliberately not going to be one in this story.
			# ────────────────────────────────────────────────────────────────────
			# 67 of the 73 actions dispatch() routes go to a controller in one line.
			# These six do not, and nothing else in this file would tell you whether
			# that is a choice or debt. It is a choice. Full write-up and the cost of
			# reversing it are on the V2-COMBAT-004 Notion page; the decision is also
			# recorded in docs/v2-infra-003-defect-register.md.
			#
			# The ownership rule Half A set is "every action has exactly one owner",
			# not "every domain has a controller". These six have exactly one owner
			# and it is named here.
			#
			# THREE MEASURED BLOCKERS — they apply to combat.confirm_round,
			# combat.next_actor and encounter.advance:
			#   1. _resolve_next_actor transitions to KEEPER_REWIND from inside the
			#      per-actor turn and returns bare. There is no FlowActionOutcome in
			#      flight on that path to carry the transition, so the body cannot be
			#      translated to the controller contract without adding a fourth
			#      FlowActionOutcome field (requires_reenter / suppress_refresh /
			#      requires_refresh were each added for exactly such a call site, so
			#      this is a cost, not an impossibility).
			#   2. _resolve_next_actor calls _end_round, so a controller must take
			#      both functions or neither.
			#   3. _actor_cfg_merged_cache is a per-FlowRuntime memo whose correct
			#      lifetime is one campaign. Every controller here is constructed per
			#      call, so a CombatController would rebuild the memo ~240x per
			#      encounter — reintroducing the exact cost the memo removes. A
			#      static var was rejected: it is a silent cross-campaign determinism
			#      fault.
			#
			# THE HONEST REASON FOR THE OTHER THREE IS COHESION, NOT IMPOSSIBILITY.
			# Do not read the blockers above as covering all six. encounter.retreat,
			# combat.init and encounter.complete have no turn-loop coupling and each
			# maps onto a FlowActionOutcome today: retreat is snapshot_outcome() plus
			# transition_to, combat.init is snapshot_outcome() plus a save reason, and
			# encounter.complete is two service calls and a transition. They are kept
			# here because splitting the combat domain — three actions in a controller,
			# three left inline, one turn loop straddling both — would be worse than
			# either extreme: it is precisely the ambiguous, half-decomposed ownership
			# this story exists to remove. Six actions with one owner is coherent;
			# three-and-three is not.
			#
			# The bodies DID leave. _end_round and _resolve_next_actor are now service
			# orchestration and snapshot publication — CombatTurnContextService,
			# CombatTurnActionService, LiveMovementContextService,
			# ContributionLedgerService, CombatRound{Emotion,Spawn,GuideSpirit,
			# Objective,Shrine}Service. What did not move is the ROUTING, and only the
			# routing.
			# ---- Combat ----
			"combat.init":
				_handle_combat_init(t)
	
			# Starts a new round, resolves the first actor, emits a per-actor snapshot.
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
				_emotion_consequence_service().apply_encounter_emotion_drift(enc_outcome, t)
				# V2-STAGE-004 Phase 4 (S12): ally is spent for one battle only — clear before nulling ctx.
				_recruitment_consequence_service().clear_ally_fields_if_present(t)
				flow_ctx.encounter_ctx = null
				flow_ctx.encounter_machine = null
				flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.encounter.complete")
	
			# ---- Recruitment (V2-STAGE-004 Phase 4 S14 redesign): Sanctum-scoped earned-return
			# companion invite accept/decline (see FlowSanctumState data.companion_invite) ----
			"sanctum.companion.accept":
				_apply_action_outcome(_sanctum_controller().handle_companion_accept(t), t)

			"sanctum.companion.decline":
				_apply_action_outcome(_sanctum_controller().handle_companion_decline(t), t)
	
			# ---- Economy ----
			# V2-INFRA-003 Phase 4 Slice 7: routed to EconomySettlementController. The
			# controller returns a FlowActionOutcome describing what should happen (transition /
			# replacement snapshot / save) — it never transitions or saves by itself.
			# _apply_action_outcome() is the single place that acts on it.
			"economy.settle_time":
				_apply_action_outcome(_economy_settlement_controller().handle_settle_time(action, t), t)

			"economy.ase.add":
				_apply_action_outcome(_economy_settlement_controller().handle_ase_add(action, t), t)

			"economy.ase.spend":
				_apply_action_outcome(_economy_settlement_controller().handle_ase_spend(action, t), t)
			
			# ---- Sanctum ----
			# V2-INFRA-003 Phase 4 Slice 8: routed to SanctumController. The controller returns
			# a FlowActionOutcome describing what should happen (transition / replacement
			# snapshot / reenter / save) — it never transitions, reenters, or saves by itself.
			# _apply_action_outcome() is the single place that acts on it.
			"sanctum.name.reroll":
				_apply_action_outcome(_sanctum_controller().handle_name_reroll(t), t)

			"sanctum.name.confirm":
				_apply_action_outcome(_sanctum_controller().handle_name_confirm(action, t), t)

			"sanctum.summon":
				_apply_action_outcome(_sanctum_controller().handle_summon(action, t), t)

			"sanctum.grade_select":
				_apply_action_outcome(_sanctum_controller().handle_grade_select(action, t), t)

			"sanctum.party.toggle":
				_apply_action_outcome(_sanctum_controller().handle_party_toggle(action, t), t)

			"sanctum.unlock_skill":
				_apply_action_outcome(_progression_controller().handle_unlock_skill(action, t), t)
	
			# ---- Weaving Rite (V2-WEAVE-002) ----
			# V2-INFRA-003 Phase 4 Slice 1: routed to WeaveController, the first bounded
			# domain controller. The controller returns a FlowActionOutcome describing what
			# should happen (transition / replacement snapshot / save) — it never transitions
			# or saves by itself. _apply_action_outcome() is the single place that acts on it.
			"weave.start_for_echo":
				_apply_action_outcome(_weave_controller().handle_start_for_echo(action, t), t)

			"weave.select_thread":
				_apply_action_outcome(_weave_controller().handle_select_thread(action, t), t)

			"weave.begin_rite":
				_apply_action_outcome(_weave_controller().handle_begin_rite(t), t)

			"weave.confirm":
				_apply_action_outcome(_weave_controller().handle_confirm(t), t)

			"weave.enter_rite":
				_apply_action_outcome(_weave_controller().handle_enter_rite(t), t)

			"weave.pick_echo":
				_apply_action_outcome(_weave_controller().handle_pick_echo(action, t), t)
	
			# PROG-004: Keeper-confirmed rank-up from EchoParty.
			# V2-INFRA-003 Phase 4 Slice 6b: routed to ProgressionController.
			"sanctum.rank_up":
				_apply_action_outcome(_progression_controller().handle_rank_up(action, t), t)

			# PROG-007: Keeper confirms a calling for an echo (may be deferred after rank-up).
			# V2-INFRA-003 Phase 4 Slice 6b: routed to ProgressionController.
			"sanctum.calling.confirm":
				_apply_action_outcome(_progression_controller().handle_calling_confirm(action, t), t)
	
			# ---- Institutions (V2-SANCTUM-002) ----
			# V2-INFRA-003 Phase 4 Slice 8: routed to SanctumController.
			"sanctum.institution.establish":
				_apply_action_outcome(_sanctum_controller().handle_institution_establish(action, t), t)

			"sanctum.institution.assign_echo":
				_apply_action_outcome(_sanctum_controller().handle_institution_assign_echo(action, t), t)

			"sanctum.institution.remove_echo":
				_apply_action_outcome(_sanctum_controller().handle_institution_remove_echo(action, t), t)
	
			# ---- Vows (VOW-001) ----
			# V2-INFRA-003 Phase 4 Slice 2: VowController owns these 3 actions. Controllers
			# report intent via FlowActionOutcome; they never transition or save by themselves.
			# _apply_action_outcome() is the single place that acts on it.
			"vow.pledge":
				_apply_action_outcome(_vow_controller().handle_pledge(action, t), t)

			"vow.break":
				_apply_action_outcome(_vow_controller().handle_break(t), t)

			"debug.vow.unlock":
				_apply_action_outcome(_vow_controller().handle_debug_unlock(action, t), t)
	
			# ---- V2-STAGE-004 Phase 4 dev commands (manual testing aids; dev-only) ----
			# V2-INFRA-003 Phase 4 Slice 6a: DebugController owns these actions too.
			"debug.ally.spawn":
				_apply_action_outcome(_debug_controller().handle_spawn_ally(t), t)

			"debug.claimant.force_combat":
				_apply_action_outcome(_debug_controller().handle_force_claimant_combat(t), t)

			"debug.charge_pressure.set":
				_apply_action_outcome(_debug_controller().handle_force_charge_pressure(action, t), t)
	
			# ---- Directives (DIRECTIVE-001) ----
			"directive.select":
				_apply_action_outcome(_venture_controller().handle_directive_select(action, t), t)
	
			# ---- Skill Loadout (PROG-009) — assign/unassign while on STAGE_MAP ----
			# V2-INFRA-003 Phase 4 Slice 6b: routed to ProgressionController.
			"skill.assign":
				_apply_action_outcome(_progression_controller().handle_skill_assign(action, t), t)

			"skill.unassign":
				_apply_action_outcome(_progression_controller().handle_skill_unassign(action, t), t)
	
			# ---- Stage Exploration (V2-STAGE-001) ----
			# V2-INFRA-003 Phase 5 Slice D: routed to VentureController. The controller reports
			# intent; _apply_action_outcome() is the single place that acts on it.
			"stage.advance_turn":
				_apply_action_outcome(_venture_controller().handle_advance_turn(action, t), t)

			"stage.return_home":
				_apply_action_outcome(_venture_controller().handle_return_home(action, t), t)

			"stage.engage_situation":
				_apply_action_outcome(_venture_controller().handle_engage_situation(action, t), t)

			"stage.resolve_situation_choice":  # V2-STAGE-004: player picked a choice overlay option
				_apply_action_outcome(_venture_controller().handle_resolve_situation_choice(action, t), t)

			"stage.ignore_situation":  # V2-STAGE-002: clear pending without resolving
				_apply_action_outcome(_venture_controller().handle_ignore_situation(action, t), t)
	
			# ---- Stage Exploration V2-STAGE-003: NPC Contact conversation ----
			# V2-INFRA-003 Phase 5 Slice C: routed to ContactController. The controller reports
			# intent; _apply_action_outcome() is the single place that acts on it.
			"stage.consult_echoes":
				_apply_action_outcome(_contact_controller().handle_consult_echoes(action, t), t)
	
			"stage.speak_response":
				_apply_action_outcome(_contact_controller().handle_speak_response(action, t), t)
	
			"stage.disengage_contact":
				_apply_action_outcome(_contact_controller().handle_disengage_contact(action, t), t)
	
			"stage.confirm_return_home":
				_apply_action_outcome(_venture_controller().handle_confirm_return_home(action, t), t)

			# V2-INFRA-003 Phase 5 Slice D: originally planned as runtime-owned, but its body
			# rebuilds a stage-explore snapshot, so it is venture-domain and moved with the rest.
			"stage.dismiss_overlay":
				_apply_action_outcome(_venture_controller().handle_dismiss_overlay(action, t), t)
	
			# UI actions
			# V2-INFRA-003 Phase 4 Slice 8: routed to SanctumController. MUTATES
			# flow_ctx.pending_summon_reveals — not publication-only.
			"ui.dismiss_summon_reveals":
				_apply_action_outcome(_sanctum_controller().handle_dismiss_summon_reveals(t), t)

			_:
				logger.debug(t, "ui.action.unknown", "Unknown action type", { "action": action })
	
		# If we just entered flow.encounter, bootstrap the Encounter machine.
		_ensure_encounter_started(t)

	# V2-INFRA-003 Phase 8B: make the run result durable, or consume it.
	#
	# ONE call, gated on the type of the snapshot this dispatch is about to publish — the same
	# gate shape as the pending_awakening_banner and scout-return one-shots further down. It
	# sits HERE, before the flush, and not down there with them, for one reason: those two only
	# zero volatile FlowContext ints and request no save, while this writes save data. A save
	# requested after the flush is not written until the NEXT dispatch, and FlowContext
	# .request_save() pipe-joins reasons, so the reason string of an unrelated later dispatch
	# would be corrupted. Publication order is unaffected: flow_ctx.last_snapshot is already the
	# value `out` reads below, and this call never changes it.
	#
	# Publishing a flow.resolve card that represents a run outcome (victory / partial / defeat /
	# withdrawal) captures it into save.flow.pending_result; publishing anything else consumes
	# a pending one. Both branches are no-ops in the common case, so the great majority of
	# dispatches queue no extra save.
	PendingResultService.capture_or_consume(flow_ctx, flow_ctx.last_snapshot, t)

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
	_log_snapshot_emitted(t, out, "dispatch.weave_locked" if weave_locked else "dispatch")

	# V2-INFRA-003 Phase 3 (slice A follow-up): consume the two Sanctum one-shot flags here,
	# exactly once, AFTER the snapshot that surfaced their derived values
	# (show_awakening_overlay / return_notification, built by SanctumSnapshotBuilder.build())
	# has been published and logged. This is the single choke point for the "shown exactly
	# once" contract — a second refresh_snapshot() within the same dispatch can no longer
	# swallow the overlay, because SanctumSnapshotBuilder.build() never clears these flags
	# itself.
	#
	# GATE: only clear when `out` is actually a flow.sanctum snapshot. flow.continue can set
	# pending_return_notification (via OfflineAccrualService.apply_if_needed) and then land on a
	# keeper-intro step instead of Sanctum (keeper intro incomplete). An unconditional clear
	# here would discard the notice before the player ever reaches Sanctum to see it. Do NOT
	# "simplify" this back to an unconditional clear.
	if str(out.get("type", "")) == FlowStateIds.SANCTUM:
		flow_ctx.pending_awakening_banner = false
		flow_ctx.pending_return_notification = {}

	# V2-INFRA-003 Phase 5 Slice B: consume the two scout-return one-shots here, exactly once,
	# AFTER the snapshot that surfaced them (VentureResolveSnapshotBuilder
	# .build_scout_return_snapshot(), a pure
	# ResolveSnapshotBuilder composition) has been published and logged. Mirrors the
	# pending_awakening_banner gate immediately above; it is the same "shown exactly once"
	# contract moved to the same single choke point, so the builder no longer has to zero its
	# own source and a repeat call is byte-identical.
	#
	# GATE on run_type as well as type: flow.resolve is emitted by six producers, five of which
	# have nothing to do with scouting. A combat resolve must never zero an Ase/intel value the
	# player has not yet been shown. Do NOT "simplify" this to the type check alone.
	#
	# The two SETTERS — encounter.retreat and stage.return_home, both of which then build the
	# scout-return snapshot in the same dispatch — are unchanged and stay where they are.
	if str(out.get("type", "")) == FlowStateIds.RESOLVE \
			and str((out.get("data", {}) as Dictionary).get("run_type", "")) == "scout_return":
		flow_ctx.pending_scout_return_ase         = 0
		flow_ctx.pending_scout_return_intel_count = 0

	# V2-INFRA-003 Phase 3 (slice C): consume _bark_line here, exactly once, AFTER the snapshot
	# that surfaced it (flow.encounter / flow.keeper_trial / flow.resolve, built by
	# EncounterSnapshotBuilder.build_round_snapshot()/build_final_snapshot() via the pure, read-only
	# _project_actor()) has been published and logged. Mirrors the pending_awakening_banner gate
	# immediately above — the builders only READ _bark_line now; this is the single choke point
	# that clears it, restoring the "one-shot display" contract without any builder mutating its
	# own source.
	#
	# EVIDENCE this is the correct site (see BUILD report for the full trace): every call to
	# either builder — FlowEncounterState.enter(), _handle_combat_init(), _resolve_next_actor(),
	# _end_round() (both the round-snapshot and final-snapshot branches),
	# FlowKeeperIntroState.build_trial_snapshot(), and the keeper_intro.trial.finish blocked
	# guard — happens exactly once inside a single dispatch() call, and dispatch() is the sole
	# entry point (core/AGENTS.md: "All state mutations via FlowRuntime.dispatch() — never
	# bypass"). So clearing once here, gated on `out`'s type, reproduces the old per-call clear
	# exactly, with no double-clear and no missed clear.
	#
	# Do NOT move this to _end_round() (or gate it only on "the round genuinely advanced" via
	# combat.confirm_round/round_counter): build_round_snapshot() is ALSO called once per actor
	# turn (combat.next_actor), each its own dispatch() at the SAME round_counter. A bark set for
	# actor A on A's turn must vanish again before actor B's turn snapshot is built a dispatch
	# later, in the very same combat round — clearing only when round_counter increments would
	# let A's bark bleed into every other actor's per-turn snapshot for the rest of that round.
	# Gating on snapshot type (not on any round-boundary condition) is what keeps this correct at
	# the actual "shown once" granularity, which is per published snapshot, not per round.
	if str(out.get("type", "")) == FlowStateIds.ENCOUNTER \
			or str(out.get("type", "")) == FlowStateIds.KEEPER_TRIAL \
			or str(out.get("type", "")) == FlowStateIds.RESOLVE:
		var _bark_clear_ectx: EncounterContext = flow_ctx.encounter_ctx
		if _bark_clear_ectx != null:
			for _bark_clear_actor_v in _bark_clear_ectx.actors:
				if _bark_clear_actor_v is Dictionary:
					(_bark_clear_actor_v as Dictionary)["_bark_line"] = ""

	return out

# V2-INFRA-003 Phase 4 Slice 8: _handle_sanctum_summon / _handle_sanctum_grade_select moved to
# core/runtime/controllers/SanctumController.gd (handle_summon / handle_grade_select). Call
# sites now go through _sanctum_controller().

# P1-FIX / V2-STAGE-004 Phase 4 (S14): non-final-objective victory returning to STAGE_EXPLORE.
# Applies post-combat effects (mirrors _handle_complete_stage minus advance_stage), resolves the
# triggering situation in the save, and nulls encounter_ctx — all BEFORE the state exit clears it.
# Extracted from the "flow.go_state"→STAGE_EXPLORE match case (pure move, no behaviour change for
# that call site).
func _apply_victory_return_to_explore(t: int) -> void:
	var _ncv_from: String = str(flow_machine._current_state_id)
	if _ncv_from == FlowStateIds.ENCOUNTER and flow_ctx.encounter_ctx != null:
		var _ncv_victory := bool(flow_ctx.encounter_ctx.combat_result.get("victory", false))
		if _ncv_victory:
			var _ncv_outcome := "win"
			_emotion_consequence_service().apply_encounter_emotion_drift(_ncv_outcome, t)
			_bond_consequence_service().apply_combat_bond_triggers(t, _ncv_outcome)
			_bond_consequence_service().apply_bond_aftermath_modifiers(t, _ncv_outcome)
			_bond_consequence_service().seed_rival_stage_incidents(t)
			# Resolve the combat situation in the save (marks objective completed).
			# V2-INFRA-003 Phase 5 Slice A: this block used to be a drifted second copy of
			# _resolve_combat_situation_and_objective(). Both now run the one implementation on
			# ActiveStageService; every difference is an explicit argument here.
			# skip_if_already_resolved=false and commit_only_when_modified=false reproduce this
			# path's exact present behaviour, including the two defects recorded in that file's
			# header (no already-resolved guard; unconditional write-back/save/log). Fixing them
			# is a behaviour change and is out of scope for a pure extraction.
			_stage_explore_session_service().resolve_combat_situation_and_objective(
				t, false, false,
				"stage.combat_resolved.nonfinal",
				"Non-final objective resolved on victory",
				false
			)
			# Vow discovery reads is_dead from ectx.actors — must run before null
			_vow_consequence_service().check_vow_discovery(t)
			# FIX (Codex review bug 1): this non-final-objective victory path nulled the
			# encounter without clearing the encounter-scoped ally/intro fields, unlike the
			# other teardown paths (defeat go_state→SANCTUM, retreat, encounter.complete,
			# _handle_complete_stage). That left ally_consumed_in_encounter=true (and a stale
			# combat_intro_reason) on explore_map, so a SECOND temporary ally earned later in
			# the same multi-objective stage was seen as already-consumed and never joined the
			# next fight. Safe here: the companion invite (if any) was already captured into
			# save_data.sanctum.companion_invite at combat-end (RecruitmentConsequenceService
			# .compute_ally_recruit_offer_if_eligible, called from the round-resolution path
			# before this handler ever runs), and clear_ally_fields_if_present() explicitly
			# does not touch that key.
			_recruitment_consequence_service().clear_ally_fields_if_present(t)
			flow_ctx.encounter_ctx     = null
			flow_ctx.encounter_machine = null
			flow_ctx.active_encounter_objective_index = -1
	# V2-VOW-002: evaluate vow condition on actual stage entry (covers first entry
	# via "Begin" and re-entry after defeat — both route through go_state→STAGE_EXPLORE).
	_vow_consequence_service().apply_vow_stage_entry_condition(t)


func _handle_new_game(t: int) -> void:
	# Create a new campaign root seed string (random once; then persisted)
	var seed_root := CampaignSeed.generate_seed_root_string()
	var legacy_root_seed := CampaignSeed.legacy_root_seed_from_seed_root(seed_root)

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
	_mark_save_requested("flow.new_game")

	# IMPORTANT: no transition has occurred yet when this runs, so refresh snapshot after mutation
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

## V2-INFRA-003 Phase 4 Slice 9: _setup_keeper_intro_trial_encounter moved to
## KeeperIntroService.setup_trial_encounter() (see that file's header for the full "why" — this
## call site is one of two non-dispatched-action reasons it could not move to
## OnboardingController alongside the keeper_intro.* handlers).
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
				KeeperIntroServiceScript.setup_trial_encounter(flow_ctx, cfg, flow_ctx.sim_tick)
			return KeeperIntroServiceScript.step_to_flow_id(step)
	return to_state

## V2-INFRA-003: single choke point for requesting a save from inside FlowRuntime.
## Delegates to FlowContext.request_save() so there is exactly one implementation of the
## set-flag + accumulate-reason logic (shared with callers outside this file that hold a
## FlowContext directly, e.g. RealmService, VowService, FlowEncounterState, FlowStageExploreState).
func _mark_save_requested(reason: String = "") -> void:
	flow_ctx.request_save(reason)


## V2-INFRA-003 Phase 4 Slice 1: builds a fresh WeaveController scoped to the current
## flow_ctx/config_service/logger. Constructed per-call (not cached on a member) so it is
## always correct even when a caller (tests included) replaces flow_ctx after FlowRuntime
## construction and before dispatch() — boot() is the normal path, but several tests build
## FlowRuntime directly and assign flow_ctx by hand. The controller itself is cheap
## (RefCounted, no setup work) so per-dispatch construction has no meaningful cost.
func _weave_controller() -> WeaveController:
	return WeaveController.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 4 Slice 2: builds a fresh VowController scoped to the current
## flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above.
func _vow_controller() -> VowController:
	return VowController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 4 Slice 6a: builds a fresh DebugController scoped to the current
## flow_ctx/config_service/logger. Same per-call construction rationale as _weave_controller()
## above.
func _debug_controller() -> DebugController:
	return DebugController.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 4 Slice 6b: builds a fresh ProgressionController scoped to the current
## flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above.
## V2-INFRA-003 Phase 4 Slice 10: gained the econ dependency when sanctum.unlock_skill (and its
## settle-before-afford-check pre-step) moved onto this controller.
func _progression_controller() -> ProgressionController:
	return ProgressionController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 4 Slice 7: builds a fresh EconomySettlementController scoped to the
## current flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above. Owns the 3 dispatched economy.* actions.
func _economy_settlement_controller() -> EconomySettlementController:
	return EconomySettlementController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Half A review correction C1: builds a fresh OfflineAccrualService scoped to the
## current flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above. One caller — the "flow.continue" arm of dispatch(). This is a
## service, not a controller: offline accrual is not a dispatched action of its own, it is a
## consequence hook that flow.continue runs on the way in.
func _offline_accrual_service() -> OfflineAccrualService:
	return OfflineAccrualService.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 4 Slice 10: FlowRuntime's own private _economy_settlement_service() factory
## (used by the settle-before-afford-check pre-step) is removed — its only two callers,
## _handle_sanctum_summon and _handle_sanctum_unlock_skill, both moved off FlowRuntime
## (SanctumController.handle_summon() in Slice 8, ProgressionController.handle_unlock_skill() in
## Slice 10). Each controller builds its own EconomySettlementService via its own private
## _economy_settlement_service() — controllers may not reach back into FlowRuntime, so this
## factory could not simply be shared.


## V2-INFRA-003 Phase 4 Slice 2: builds a fresh VowConsequenceService scoped to the current
## flow_ctx/config_service/econ/logger. Used by the several stage/encounter/return call sites
## that invoke vow consequence hooks directly (not via a dispatched action, so not through
## _apply_action_outcome()).
func _vow_consequence_service() -> VowConsequenceService:
	return VowConsequenceService.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 4 Slice 3: builds a fresh NarrativeVoiceService scoped to the current
## flow_ctx/config_service/logger. Same per-call construction rationale as _weave_controller()
## above — cheap RefCounted, always correct even if flow_ctx is replaced after construction.
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 4 Slice 4: builds a fresh EmotionConsequenceService scoped to the current
## flow_ctx/config_service/logger. Same per-call construction rationale as _weave_controller()
## above. Used by the several stage/encounter/keeper-intro/contact/economy call sites that
## invoke emotion consequence hooks directly (not via a dispatched action).
func _emotion_consequence_service() -> EmotionConsequenceService:
	return EmotionConsequenceService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6A: builds a fresh CombatRoundEmotionService scoped to the
## current flow_ctx/config_service/logger. Same per-call construction rationale as the
## factories above. One caller — _end_round(), once per round. This is a FACTORY, not a
## delegating stub: the seven-term procedure body lives entirely on the service and no
## forwarder for it remains here.
func _combat_round_emotion_service() -> CombatRoundEmotionService:
	return CombatRoundEmotionService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6B: builds a fresh CombatRoundSpawnService, same per-call
## construction rationale as the factories above. One caller — _end_round(), once per round,
## which holds the instance across both calls so RECOVER and ENDURE see the same object. This
## is a FACTORY, not a delegating stub: both procedure bodies live entirely on the service and
## no forwarder for either remains here.
func _combat_round_spawn_service() -> CombatRoundSpawnService:
	return CombatRoundSpawnService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6C: builds a fresh CombatRoundGuideSpiritService, same per-call
## construction rationale as the factories above. One caller — _end_round(), once per round.
## This is a FACTORY, not a delegating stub: the whole GUIDE_SPIRIT objective phase lives on
## the service and no forwarder for it remains here.
func _combat_round_guide_spirit_service() -> CombatRoundGuideSpiritService:
	return CombatRoundGuideSpiritService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6D: builds a fresh CombatRoundObjectiveService, same per-call
## construction rationale as the factories above. One caller — _end_round(), once per round,
## which holds the instance across all three calls so PROTECT theft, PROTECT guard and PURSUE
## contain see the same object. This is a FACTORY, not a delegating stub: all three procedure
## bodies live entirely on the service and no forwarder for any of them remains here.
func _combat_round_objective_service() -> CombatRoundObjectiveService:
	return CombatRoundObjectiveService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6E: builds a fresh CombatRoundShrineService, same per-call
## construction rationale as the factories above. One caller — _end_round(), once per round.
## This is a FACTORY, not a delegating stub: the whole PURIFY_SHRINE drain phase lives on the
## service and no forwarder for it remains here.
func _combat_round_shrine_service() -> CombatRoundShrineService:
	return CombatRoundShrineService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6H. Per-call construction, same rationale as the factories above:
## cheap RefCounted, always correct even if flow_ctx/directive_service is replaced after
## FlowRuntime construction. One caller — _resolve_next_actor(), once per actor turn.
func _combat_turn_context_service() -> CombatTurnContextService:
	return CombatTurnContextService.new(flow_ctx, config_service, directive_service, logger)


## V2-INFRA-003 Phase 6 Slice 6H. Takes only the logger: the action-resolution body reads no
## config and never touches flow_ctx. One caller — _resolve_next_actor(), once per actor turn.
func _combat_turn_action_service() -> CombatTurnActionService:
	return CombatTurnActionService.new(logger)


## V2-INFRA-003 Phase 6 Slice 6H. Two dependencies, not three — the contribution ledger reads no
## config of its own. One caller — _resolve_next_actor(), once per actor turn. The class's three
## primitives are static and are called without an instance.
func _contribution_ledger_service() -> ContributionLedgerService:
	return ContributionLedgerService.new(flow_ctx, logger)


## V2-INFRA-003 Phase 4 Slice 4: builds a fresh BondConsequenceService scoped to the current
## flow_ctx/config_service/logger. Same per-call construction rationale as _weave_controller()
## above. Used by the two combat-teardown call sites (_apply_victory_return_to_explore,
## _handle_complete_stage) that invoke bond consequence hooks directly.
func _bond_consequence_service() -> BondConsequenceService:
	return BondConsequenceService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 4 Slice 5: builds a fresh RecruitmentConsequenceService scoped to the
## current flow_ctx/config_service/logger. Same per-call construction rationale as
## _weave_controller() above. Used by the six combat-teardown / go_state call sites that invoke
## the earned-return recruit-offer compute + ally-field teardown hooks directly.
func _recruitment_consequence_service() -> RecruitmentConsequenceService:
	return RecruitmentConsequenceService.new(flow_ctx, config_service, logger)

## V2-INFRA-003 Phase 5 Slice A: builds a fresh ActiveStageService scoped to the
## current flow_ctx/config_service/logger. Same per-call construction rationale as
## _weave_controller() above — RefCounted, no setup work, and always correct even when a
## caller replaces flow_ctx after FlowRuntime construction. Only the stateful members
## (find_explore_target / mark_stage_objective_completed /
## resolve_combat_situation_and_objective) go through this; the pure helpers are static and
## are called as ActiveStageService.<name>() directly at their call sites.
## V2-INFRA-003 Phase 5 Slice E: the three long procedure bodies Slice D added to that service
## live on StageExploreTurnService / SituationEngagementService now, and VentureController
## builds those itself. This factory keeps only the members listed above.
func _stage_explore_session_service() -> ActiveStageService:
	return ActiveStageService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 4 Slice 8: builds a fresh SanctumController scoped to the current
## flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above. Owns 11 actions: sanctum.summon, sanctum.grade_select,
## sanctum.party.toggle, sanctum.name.reroll, sanctum.name.confirm,
## sanctum.institution.establish/assign_echo/remove_echo, sanctum.companion.accept/decline,
## ui.dismiss_summon_reveals.
func _sanctum_controller() -> SanctumController:
	return SanctumController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 5 Slice C: builds a fresh ContactController scoped to the current
## flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above. Owns 3 actions: stage.consult_echoes, stage.speak_response,
## stage.disengage_contact. `econ` is needed by apply_contact_outcome()'s claimant/good branch
## (econ.add_ase for the Ase reward).
func _contact_controller() -> ContactController:
	return ContactController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 5 Slice D: builds a fresh VentureController scoped to the current
## flow_ctx/config_service/econ/directive_service/logger. Same per-call construction rationale
## as _weave_controller() above. Owns 10 actions: stage.advance_turn, stage.engage_situation,
## stage.resolve_situation_choice, flow.complete_stage, stage.return_home,
## stage.ignore_situation, directive.select, stage.dismiss_overlay, flow.select_realm,
## stage.confirm_return_home. `directive_service` is a dependency because three of those
## handlers resolve the active directive (advance_turn's step budget / reveal radius,
## return_home's escape bonus, and directive.select itself).
func _venture_controller() -> VentureController:
	return VentureController.new(flow_ctx, config_service, econ, directive_service, logger)


## V2-INFRA-003 Phase 4 Slice 9: builds a fresh OnboardingController scoped to the current
## flow_ctx/config_service/econ/logger. Same per-call construction rationale as
## _weave_controller() above. Owns 5 Chapter-I onboarding actions (Part A: onboarding.advance,
## onboarding.fragment.hear, onboarding.fragment.select, onboarding.fragment.confirm,
## onboarding.name.confirm) plus 7 Keeper-intro actions (Part B: keeper_intro.call.answer,
## keeper_intro.trial.finish, keeper_intro.rewind.continue, keeper_intro.thread.continue,
## keeper_intro.awakening.choose, keeper_intro.weave.complete, keeper_intro.complete). `econ`
## is needed by Part B's handle_trial_finish() (KeeperIntroService.grant_trial_rewards()).
func _onboarding_controller() -> OnboardingController:
	return OnboardingController.new(flow_ctx, config_service, econ, logger)


## V2-INFRA-003 Phase 4 Slice 1: single application point for a controller's returned
## FlowActionOutcome. Controllers report intent (replacement snapshot / transition / save
## reasons) but never act on it themselves — this is the only place that assigns
## flow_ctx.last_snapshot from a controller, calls flow_machine.transition()/
## refresh_snapshot() on a controller's behalf, or turns a controller's save_reasons into an
## actual flow_ctx.request_save() call. error_code/handled are available on the outcome for
## future controllers; this slice's 6 weave actions never set error_code.
func _apply_action_outcome(outcome: FlowActionOutcome, t: int) -> void:
	if outcome == null:
		return
	# V2-INFRA-003 Phase 4 Slice 8: requires_reenter is checked before has_replacement_snapshot —
	# reenter() rebuilds and assigns flow_ctx.last_snapshot itself (re-running the current
	# state's enter()), so a controller reporting requires_reenter never also sets
	# has_replacement_snapshot. See FlowActionOutcome.requires_reenter / .reenter_outcome().
	if outcome.requires_reenter:
		flow_machine.reenter(flow_ctx, logger, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
	elif outcome.has_replacement_snapshot:
		flow_ctx.last_snapshot = outcome.replacement_snapshot
		# V2-INFRA-003 Phase 4 Slice 6b: sanctum.rank_up / sanctum.calling.confirm report
		# suppress_refresh — the only two actions that assign a replacement snapshot but never
		# call flow_machine.refresh_snapshot() (see FlowActionOutcome.suppress_refresh).
		if not outcome.suppress_refresh:
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
	elif outcome.requires_refresh:
		# V2-INFRA-003 Phase 5 Slice D: stage.advance_turn's not-exploring guard and
		# directive.select's non-STAGE branch refresh a snapshot they never rebuilt.
		# See FlowActionOutcome.requires_refresh / .refresh_outcome().
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
	if outcome.transition_to != "":
		flow_machine.transition(outcome.transition_to, flow_ctx, logger, t, outcome.transition_reason)
	for reason in outcome.save_reasons:
		_mark_save_requested(reason)


# Helpers
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
		var _intel_count := ActiveStageService.count_revealed_situations(flow_ctx)
		var _partial_ase := 0
		if _intel_count > 0:
			var _pf := float(ConfigService.get_rewards_cfg(config_service).get("partial_intel_reward_factor", 0.12))
			_partial_ase = roundi(float(ActiveStageService.get_stage_base_reward(flow_ctx, config_service)) * _pf)
			if _partial_ase > 0:
				econ.add_ase(_partial_ase, "retreat_intel_partial", logger, t)
		flow_ctx.pending_scout_return_ase         = _partial_ase
		flow_ctx.pending_scout_return_intel_count = _intel_count

		# Clear encounter context — no emotion drift on retreat.
		# FIX (P4 review bug 2): retreat-success also skipped ally-field teardown — clear
		# before nulling ctx, mirroring the encounter.complete / _handle_complete_stage /
		# defeat go_state→SANCTUM call sites.
		_recruitment_consequence_service().clear_ally_fields_if_present(t)
		flow_ctx.encounter_ctx    = null
		flow_ctx.encounter_machine = null
		_mark_save_requested("encounter.retreat")
		# V2-SANCTUM-001: withdrawal — apply emotion modifiers + vow release before resolve.
		_emotion_consequence_service().apply_run_emotion_modifiers("withdrawal", t)
		_vow_consequence_service().check_vow_release_condition(t)
		# V2-INFRA-003 Phase 5 Slice D: producer C moved to ActiveStageService
		# (two callers, two domains — see that file's header). Same pure function.
		flow_ctx.last_snapshot = VentureResolveSnapshotBuilder.build_scout_return_snapshot(flow_ctx, t)
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
	_mark_save_requested("combat.init")

	# Rebuild flow.encounter snapshot with combat state included.
	flow_ctx.last_snapshot = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t)
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


## V2-INFRA-003 Phase 6 Slice 6G: builds a fresh LiveMovementContextService scoped to the
## current flow_ctx/logger. Same per-call construction rationale as the factories above —
## RefCounted, no setup work, and the service is stateless between calls, so a fresh instance
## is byte-exact. config_service is deliberately NOT passed: the service never reads it, and
## both of its preparation entry points already take `bdata` from the caller.
##
## This is a FACTORY, not a delegating stub: all 27 moved functions live entirely on the
## service and no forwarder for any of them remains here.
func _live_movement_context_service() -> LiveMovementContextService:
	return LiveMovementContextService.new(flow_ctx, logger)


## Per-run MEMO of ConfigService.merge_actor_cfg(). Config is immutable for the life of this
## FlowRuntime — config_service.load_balance() runs exactly once, at boot() (grep-verified: no
## other production call site reloads balance mid-run) — so _resolve_next_actor() would
## otherwise rebuild the same merged dict on every single actor turn (6v6 x 20 rounds ≈ 240
## rebuilds) for a result that never changes.
##
## V2-INFRA-003 Phase 6 Slice 6G: the PURE merge moved to ConfigService.merge_actor_cfg(); this
## memo stayed. Its correct lifetime is exactly one FlowRuntime, i.e. one campaign, and an
## instance member is the only owner with that lifetime. A `static var` on either class would
## be process-wide, so two campaigns — or two test suites in one Godot process — could read
## each other's entries: a silent determinism bug. Cost of keeping it here: FlowRuntime holds
## one field of derived config, and the moved-out merge gained no caller of its own.
var _actor_cfg_merged_cache: Dictionary = {}
func _get_actor_cfg_merged(actor_data_cfg: Dictionary, maturity_cfg: Dictionary) -> Dictionary:
	if _actor_cfg_merged_cache.is_empty():
		_actor_cfg_merged_cache = ConfigService.merge_actor_cfg(actor_data_cfg, maturity_cfg)
	return _actor_cfg_merged_cache


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
	var actor: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, actor_id)

	# Read config blocks.
	var balance: Dictionary = config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var leadership_expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	# V2-PROG-012 Phase 0: BehaviorArbiter reads seven tuning keys that are authored in
	# data.maturity_expression (identity_weight_scale, composure_dampen_scale,
	# directive_interpretation_mul [V2-PROG-012 Phase 6: renamed from directive_band_mul],
	# press_*, protect_ally_grounded_*). Without this merge they were unreachable and silently
	# fell through to BehaviorArbiter._DEFAULTS, making the balance.json values decorative.
	# data.actor wins on collision so existing behaviour is unchanged. See
	# ConfigService.merge_actor_cfg() / _get_actor_cfg_merged() above for the merge + per-run cache.
	var actor_cfg: Dictionary = _get_actor_cfg_merged(bdata.get("actor", {}), leadership_expr_cfg)
	var prog_cfg_block: Dictionary    = bdata.get("progression", {})
	var birth_stats_block: Dictionary = bdata.get("summoning", {}).get("birth_stats", {})
	var round: int = int(combat_state.get("round_counter", 0))

	# V2-INFRA-003 Phase 6 Slice 6H: the per-turn ctx dict (shrine scan, active vow, bonds,
	# terrain board_cfg, mode directive injection) moved to CombatTurnContextService. It is a
	# pure builder — it writes nothing — so this call is a straight substitution for the 124
	# lines that were here.
	var _turn_ctx_built: Dictionary = _combat_turn_context_service().build_turn_context(
		actor, ectx, balance, bdata, round, t)
	var ctx: Dictionary = _turn_ctx_built["ctx"]
	var movement_board_cfg: Dictionary = _turn_ctx_built["board_cfg"]

	# V2-INFRA-003 Phase 6 Slice 6G: one instance held across this whole activation, so the
	# preparation, the activation and the purify side effect all address the same object.
	var _live_movement := _live_movement_context_service()
	var movement_prepared: Dictionary = _live_movement.prepare_live_movement_context(
		actor, ectx, combat_state, movement_board_cfg, bdata, t)
	if bool(movement_prepared.get("valid", false)) and bool(movement_prepared.get("selection_enabled", false)):
		ctx["movement_context"] = movement_prepared["movement_context"]
		ctx["movement_profile"] = movement_prepared["profile"]
		ctx["movement_goals"] = movement_prepared["goals"]
		ctx["movement_options"] = movement_prepared["options"]

	# Resolve this actor's turn.
	var movement_cfg_for_asm: Dictionary = movement_prepared.get("movement_cfg", {}) as Dictionary
	var behavior_module: BehaviorModule = null
	if ectx.resolution_mode == EncounterResolutionModes.PURSUE and bool(actor.get("is_quarry", false)):
		behavior_module = FleeBehaviorModule.new(movement_board_cfg)
	var asm := ActorStateMachine.new(actor, behavior_module, actor_cfg, movement_cfg_for_asm)
	var intent: Dictionary = asm.advance_turn(ctx, logger, t)
	var _movement_result: Dictionary = _live_movement.apply_live_activation(actor, intent, movement_prepared, asm, ctx, t)
	var action_type: String = intent.get("action_type", "actor.idle")

	# V2-INFRA-003 Phase 6 Slice 6H: the activation bark append, the combat.actor_turn log and
	# the five-arm action match (with every melee consequence inside it) moved to
	# CombatTurnActionService. Exactly one last_round_results entry is still appended per call.
	_combat_turn_action_service().resolve_activation(
		actor, intent, action_type, asm, ectx, bdata, leadership_expr_cfg, round, t)

	# Primary actions resolve before end-of-activation Burning. Purify is an
	# external side effect and therefore shares this post-action boundary.
	if action_type == "actor.purify_shrine" and not bool(actor.get("is_dead", false)):
		_live_movement.apply_live_purify_shrine(actor, str(intent.get("target_id", "")), ctx, t)
	LiveHazardOutcomeService.apply(actor, _movement_result, t, logger, true)

	if KeeperIntroServiceScript.is_trial_active(flow_ctx):
		var lethal_ids: Array[String] = KeeperIntroServiceScript.trial_lethal_echo_ids(flow_ctx)
		if not lethal_ids.is_empty():
			var onboarding_v: Variant = flow_ctx.save_data.get("onboarding", {})
			var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
			if not bool(onboarding.get("keeper_trial_rewind_used", false)):
				# V2-INFRA-003 Phase 4 Slice 9: apply_trial_rewind() mutates save_data/nulls the
				# encounter context but does NOT transition (service, no flow_machine — see
				# KeeperIntroService.apply_trial_rewind()'s header note). This call site still
				# holds flow_machine directly, so it performs the KEEPER_REWIND transition itself
				# immediately afterward, exactly matching pre-extraction behaviour.
				KeeperIntroServiceScript.apply_trial_rewind(flow_ctx, config_service.get_balance(), logger, t, lethal_ids)
				flow_machine.transition(FlowStateIds.KEEPER_REWIND, flow_ctx, logger, t, "keeper_intro.trial.rewind")
				return
			KeeperIntroServiceScript.restore_echo_after_second_attempt(flow_ctx, logger, t, lethal_ids)

	if not ectx.last_round_results.is_empty():
		ectx.last_actor_action = ectx.last_round_results.back().duplicate(true)
		# V2-COMBAT-002 Slice 6D: presentation-only path threading. The traversed
		# path already exists in the activation result but evaporated here, so
		# tokens lerped straight through walls. Stamped additively for EVERY
		# action_type (a move-then-melee activation appends the MELEE entry, and
		# that entry must still carry the path). Keys are always present so the
		# snapshot shape stays stable; `path` is actual_traversed_cells VERBATIM
		# (origin is contract-excluded and the array MAY be empty).
		var _path_from_pos: Dictionary = (actor.get("grid_pos", {}) as Dictionary).duplicate(true)
		var _path_cells: Array = []
		if str(ectx.last_actor_action.get("source_id", "")) == str(actor.get("id", "")):
			var _mv_result: Dictionary = intent.get("movement_result", {}) as Dictionary
			if not _mv_result.is_empty():
				var _mv_actual: Array = _mv_result.get("actual_traversed_cells", []) as Array
				if not _mv_actual.is_empty():
					_path_cells = _mv_actual.duplicate(true)
					_path_from_pos = (_mv_result.get("origin", _path_from_pos) as Dictionary).duplicate(true)
		ectx.last_actor_action["from_pos"] = _path_from_pos
		ectx.last_actor_action["path"]     = _path_cells

	# V2-INFRA-003 Phase 6 Slice 6H: the PROG-003 accumulator and the S14b support fold moved to
	# ContributionLedgerService, which now owns EncounterContext.echo_action_logs outright.
	_contribution_ledger_service().accumulate_turn(
		actor, ectx, prog_cfg_block, birth_stats_block, t)

	# Advance current_actor_index past this actor so the next call finds the correct one.
	combat_state["current_actor_index"] = next_idx + 1

	# V2-INFRA-003 Phase 6 Slice 6H: PURSUE quarry edge-escape detection moved to
	# CombatRoundObjectiveService, beside the PURSUE contain counter it shares a remit with.
	# Still called AFTER the index advance, exactly where it ran before.
	_combat_round_objective_service().apply_pursue_quarry_escape(
		actor, ectx, movement_board_cfg, t)

	# Emit per-actor snapshot — UI shows updated board + arrow + action text for this actor.
	flow_ctx.last_snapshot = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t)
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

	# V2-INFRA-003 Phase 6 (slices 6A-6E): the eight per-round consequence phases below were moved
	# out of this function into five core/combat/CombatRound*Service.gd siblings, grouped by
	# resolution mode. Each carries its own mode gate, so every mode it does not own is
	# byte-identical. None requests a save or holds a flow_machine. Read a service's own header
	# for its full read/write set, its placement rationale, and its defect notes.
	#
	# THE ORDER IS LOAD-BEARING and must not change:
	#   SHRINE drain -> emotion tick -> RECOVER -> ENDURE -> GUIDE_SPIRIT -> PROTECT theft ->
	#   PROTECT guard -> PURSUE contain -> check_end_condition.
	# The drain runs first because it can kill the shrine, which the end check must see, and
	# because the emotion tick re-adjusts the morale it writes. PROTECT guard must follow PROTECT
	# theft in the same round: check_end_condition reads protect_counter and totem_stolen together.

	# COMBAT-006 shrine drain. NOT VOID — the returned hp is consumed twice below, in
	# ectx.combat_result and in the combat.end log line.
	var shrine_hp_val: int = _combat_round_shrine_service().apply_shrine_drain_round(
		ectx, round, leadership_expr_cfg, t)

	# The seven-term in-combat emotion tick (ally-KO fear spread, per-round fear tick, morale
	# decay, outnumber relief, witness-refuse, overwhelmed, no-damage streak).
	_combat_round_emotion_service().apply_round_emotion_tick(ectx, round, leadership_expr_cfg, t)

	# RECOVER (hold counter, one-time holder designation, interval reinforcement spawn), then the
	# ENDURE wave spawn.
	var _spawn_service := _combat_round_spawn_service()
	_spawn_service.apply_recover_round(ectx, round, t)
	_spawn_service.apply_endure_wave_spawn(ectx, t)

	# The GUIDE_SPIRIT escort/skittish phase (barks, escort-started and destination-reached
	# latches, the skittish should-move decision, the protect-hold counter, and the two
	# GuideSpiritActivationService activations).
	#
	# V2-INFRA-003 Phase 6 Slice 6G: the preparation itself now lives on
	# LiveMovementContextService, together with the eight _movement_* helpers it transitively
	# depends on and that the ordinary per-actor activation path shares. The guide-spirit
	# service still owns the GATE — asking it keeps the preparation exactly as lazy as it was
	# before, so no mode newly pays the full-grid cost.
	var _guide_service := _combat_round_guide_spirit_service()
	var _guide_prepared: Dictionary = {}
	if CombatRoundGuideSpiritService.needs_activation_context(ectx):
		_guide_prepared = _live_movement_context_service().prepare_guide_spirit_activation_context(
			EncounterContext.find_actor_by_id(ectx.actors, str(combat_state.get("spirit_id", ""))),
			ectx, combat_state, config_service.get_balance().get("data", {}), t)
	_guide_service.apply_guide_spirit_round(ectx, round, _guide_prepared, t)

	# The three PROTECT/PURSUE objective-progress phases: the theft roll with its carrier-down
	# recovery branch, the guard-proximity protect_counter, and the PURSUE contain_counter.
	#
	# THE ROUND COUNTER STAYS HERE. The theft roll is the only RNG in any of these phases and its
	# seed path embeds the round counter ("combat.theft.%s.%d"), so `round` is passed in rather
	# than re-read and combat_state["round_counter"] is neither read nor incremented there.
	var _objective_service := _combat_round_objective_service()
	_objective_service.apply_protect_theft_round(ectx, round, t)
	_objective_service.apply_protect_guard_round(ectx, round, t)
	_objective_service.apply_pursue_contain_round(ectx, round, t)

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

		# V2-STAGE-004 Phase 4 (S14): compute the earned-return ally recruit offer ONCE, here —
		# before any downstream teardown path (encounter.complete / _handle_complete_stage /
		# flow.go_state→STAGE_EXPLORE) clears explore_map.ally_contact or nulls encounter_ctx.
		# No-op (byte-identical) when there is no joined ally, the ally died, or this wasn't a
		# victory. See ANSWERS.md #28/#31.
		_recruitment_consequence_service().compute_ally_recruit_offer_if_eligible(_arr_victory, round, t)

		# V2-STAGE-002: on victory, resolve the situation AND mark objective complete BEFORE
		# the final snapshot so objectives_remaining is accurate AND the situation is not
		# re-targeted if the player returns to stage_explore.
		if _arr_victory:
			_stage_explore_session_service().resolve_combat_situation_and_objective(
				t, true, true,
				"stage.combat_resolved",
				"Combat situation resolved on victory (pre-snapshot)",
				true
			)

		# V2-VOICE-001: write arrival barks to ≤2 party echo save entries BEFORE final snapshot
		# so build_final_snapshot() can read them via echo["_sanctum_bark"].
		_voice_service().select_arrival_barks_for_party(_arr_victory, t)
		# V2-VOW-002: probe benefit before final snapshot so resolve screen can include it.
		_vow_consequence_service().store_vow_benefit_preview(t)
		# FinalCombatSnapshot — emits type "flow.resolve"; stored on ectx.final_snapshot.
		var final_snap: Dictionary = FlowEncounterState.build_final_snapshot(flow_ctx, t)
		ectx.final_snapshot    = final_snap
		flow_ctx.last_snapshot = final_snap
	else:
		# RoundSnapshot — emits type "flow.encounter"; stored on ectx.last_round_snapshot.
		var round_snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t)
		ectx.last_round_snapshot = round_snap
		flow_ctx.last_snapshot   = round_snap
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: scans initiative_order from current_actor_index forward.
## Returns the index of the next living actor, or -1 if all actors in the order have gone.
func _find_next_living_actor_idx(ectx: EncounterContext) -> int:
	var order: Array = ectx.combat_state.get("initiative_order", [])
	var start: int = int(ectx.combat_state.get("current_actor_index", 0))
	for i in range(start, order.size()):
		var aid: String = str(order[i].get("id", ""))
		var a: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, aid)
		if not a.is_empty() and not a.get("is_dead", false):
			return i
	return -1


# V2-INFRA-003 Half A review correction C2: _generate_seed_root_string moved to
# CampaignSeed.generate_seed_root_string(). Its consecutive-line partner
# _legacy_root_seed_from_seed_root moved there in Phase 4 Slice 6a on the reason "the class
# that already owns every other 'derive a seed value from a seed string' concern" — which
# applies to minting the string exactly as much as to consuming it. Single call site,
# _handle_new_game. No shim here.

# V2-INFRA-003 Phase 4 Slice 7: _handle_economy_settle_time (the online bank-timer settle,
# ~140 lines: Ase accrual, emotion recovery piggyback, institution tick) moved to
# core/economy/EconomySettlementService.gd (settle()) — see that file's header for the full
# three-settlements/three-clocks writeup and what changed (nothing but the trailing
# refresh_snapshot() call, which callers now handle themselves). Call sites now go through
# _economy_settlement_controller() (the economy.* dispatched actions), SanctumController's own
# private _economy_settlement_service() (handle_summon()'s settle-before-spend pre-step, moved
# there in Phase 4 Slice 8), or ProgressionController's own private _economy_settlement_service()
# (handle_unlock_skill()'s settle-before-afford-check pre-step, moved there in Phase 4 Slice 10).
#
# _is_ase_flame_awakened moved to KeeperIntroService.is_ase_flame_awakened(save_data) — it was
# also called by the offline-accrual block below (a second, unrelated domain), so
# ConfigService/KeeperIntroService's "true owner" rule applies, not a private FlowRuntime helper.
# (That block has since left too — see correction C1 below; both callers still share the
# relocated function, which is the point of moving it to its true owner rather than inlining it.)

# V2-INFRA-003 Half A review correction C1: _apply_offline_accrual_if_needed,
# _build_offline_retention_context and _build_offline_return_notification (258 lines — the
# largest block of domain logic left in this file, and the only place in it that authored
# player-facing prose) moved to core/economy/OfflineAccrualService.gd
# (apply_if_needed / _build_retention_context / _build_return_notification). There was no
# blocker: no flow_machine, no controller call, one production caller. See that file's
# header for why it is a sibling of EconomySettlementService rather than a method on it
# (different clock, different trigger, different cap, and it emits a return notification).
# The one call site is the "flow.continue" arm of dispatch(), which now goes through
# _offline_accrual_service(). tests/EconomyTests.gd's five reflection call sites construct
# the service directly in the same change — no shim was left here.



# V2-INFRA-003 Phase 4 Slice 5: _compute_ally_recruit_offer_if_eligible moved to
# core/sanctum/RecruitmentConsequenceService.gd (compute_ally_recruit_offer_if_eligible). Call
# site now goes through _recruitment_consequence_service().


# V2-INFRA-003 Phase 4 Slice 8: _handle_companion_accept / _handle_companion_decline moved to
# core/runtime/controllers/SanctumController.gd (handle_companion_accept /
# handle_companion_decline). Call sites now go through _sanctum_controller().


# V2-INFRA-003 Phase 4 Slice 5: _clear_ally_fields_if_present moved to
# core/sanctum/RecruitmentConsequenceService.gd (clear_ally_fields_if_present). Call sites
# now go through _recruitment_consequence_service().


# V2-INFRA-003 Phase 4 Slice 4: _apply_encounter_emotion_drift and _apply_sanctum_emotion_tick
# moved to core/emotion/EmotionConsequenceService.gd (apply_encounter_emotion_drift /
# apply_sanctum_emotion_tick). Call sites now go through _emotion_consequence_service().


# V2-INFRA-003 Phase 4 Slice 7: _get_balance_economy_cfg moved to ConfigService.get_economy_cfg
# (shared by EconomySettlementService.settle() and OfflineAccrualService.apply_if_needed()).

# V2-INFRA-003 Phase 5 Slice A: _get_balance_rewards_cfg moved to
# ConfigService.get_rewards_cfg, and _count_revealed_situations / _get_stage_base_reward
# moved to ActiveStageService (static, explicit flow_ctx / config_service params).
# All three were shared by the encounter-retreat path above and the stage return-home path
# below, so none of them had a single-domain owner.
# V2-ECONOMY-001: Build the scout-return resolve snapshot for retreat / return_home.
	
# V2-INFRA-003 Phase 4 Slice 7: _get_max_online_settle_delta_seconds moved to
# EconomySettlementService._max_online_settle_delta_seconds (its only caller).

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

# V2-INFRA-003 Phase 4 Slice 8: _get_party_max_size / _handle_sanctum_party_toggle moved to
# core/runtime/controllers/SanctumController.gd (private _get_party_max_size() /
# handle_party_toggle()). Call site now goes through _sanctum_controller().

# V2-INFRA-003 Phase 4 Slice 10: _handle_sanctum_unlock_skill (V2-PROG-009: unlock a skill from
# the constellation skill tree) moved to core/runtime/controllers/ProgressionController.gd
# (handle_unlock_skill()) — the last action handler on FlowRuntime that belonged to an
# already-extracted controller. Call site now goes through _progression_controller().


# V2-INFRA-003 Phase 4 Slice 4: _get_bond_triggers_cfg / _get_bond_behavior_cfg /
# _get_rival_archetypes_cfg / _get_bond_recovery_cfg moved to ConfigService (as
# get_bond_triggers_cfg / get_bond_behavior_cfg / get_rival_archetypes_cfg /
# get_bond_recovery_cfg); _apply_combat_bond_triggers / _apply_bond_aftermath_modifiers /
# _seed_rival_stage_incidents moved to core/sanctum/BondConsequenceService.gd. Call
# sites now go through _bond_consequence_service().

# V2-INFRA-003 Phase 4 Slice 8: _repair_echo_schema moved to
# core/sanctum/SanctumService.gd (static repair_echo_schema(save_data, logger, t) -> bool).
# This is a CORRECTION vs the story brief, which listed it alongside the SanctumController
# handlers — its only call site is flow.continue (below, near the top of dispatch()'s match
# block), not one of the 11 sanctum.*/ui.* actions this slice's controller owns. A helper used
# by a still-private FlowRuntime handler belongs on a service (callable from anywhere, no
# flow_machine) rather than a controller (reached only via the dispatch()/FlowActionOutcome
# contract) — the same reasoning EconomySettlementController.gd's header documents for
# settle(). Call site now reads:
#   if SanctumService.repair_echo_schema(flow_ctx.save_data, logger, t):
#       _mark_save_requested("sanctum.schema.repair")

# PROG-004 / PROG-007: sanctum.rank_up and sanctum.calling.confirm.
# V2-INFRA-003 Phase 4 Slice 6b: moved to ProgressionController.handle_rank_up() /
# .handle_calling_confirm(). See dispatch()'s "sanctum.rank_up" / "sanctum.calling.confirm"
# cases and core/runtime/controllers/ProgressionController.gd.


# V2-DIRECTIVE-001: writes the chosen directive to stage_context, requests save, refreshes snapshot.


# ── XP tuning helpers (ST5) ──────────────────────────────────────────────────
# PROG-009: skill.assign / skill.unassign / persist_equipped_skills / realm XP multiplier.
# V2-INFRA-003 Phase 4 Slice 6b: moved to ProgressionController.handle_skill_assign() /
# .handle_skill_unassign() / .persist_equipped_skills() / .get_realm_xp_multiplier(). See
# dispatch()'s "skill.assign" / "skill.unassign" cases and
# core/runtime/controllers/ProgressionController.gd.
#
# V2-INFRA-003 Phase 6 Slice 6F: the two NON-handler members of that group were demoted off the
# controller so a second controller may call them, which is what a controller can never allow:
#   persist_equipped_skills → core/progression/SkillLoadoutService.gd (persist_equipped_skills)
#                             — unblocked flow.select_stage, which is now owned by
#                               VentureController.handle_select_stage() and no longer inline here
#   get_realm_xp_multiplier → ProgressionService.get_realm_xp_multiplier() (static)
#                             — unblocked _resolve_next_actor's mid-combat kill-XP call site
# Neither left a forwarder on this file or on ProgressionController.


# ---------------------------------------------------------------------------
# V2-SANCTUM-002 institution handlers
# ---------------------------------------------------------------------------

# V2-INFRA-003 Phase 4 Slice 8: _handle_sanctum_institution_establish/assign_echo/remove_echo
# moved to core/runtime/controllers/SanctumController.gd (handle_institution_establish /
# handle_institution_assign_echo / handle_institution_remove_echo). Call sites now go through
# _sanctum_controller().


# V2-INFRA-003 Phase 4 Slice 4: _get_institutions_cfg / _get_buildings_cfg moved to
# ConfigService (get_institutions_cfg / get_buildings_cfg) — plain balance.json subtree
# reads needed by both this file's institution handlers and
# EmotionConsequenceService.apply_run_emotion_modifiers().


# ────────────────────────────────────────────────────────────────────────────
# V2-INFRA-003 Phase 5 Slice D: the V2-STAGE-001 stage-exploration handlers that used to live
# here are now on core/runtime/controllers/VentureController.gd — see the migration table
# further down this file.
# ────────────────────────────────────────────────────────────────────────────


# V2-STAGE-003: NPC conversation setup — extracted from _handle_stage_engage_situation.
# Called when sit_type == TYPE_NPC and contact dict is non-empty.
# Behavior is byte-identical to the inlined V2-STAGE-003 block (no resolved undo needed
# since we no longer set resolved up front in the engage handler).


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004: Resolve a choice-overlay option (obstacle / structure).
# ────────────────────────────────────────────────────────────────────────────

# Payload: { "situation_id": String, "choice_id": String }


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-002 private helpers
# ────────────────────────────────────────────────────────────────────────────

# V2-STAGE-002: Dismiss the engagement popup without resolving the situation.
# Clears pending_situation_id — intel gathered (revealed state) is preserved.
# Party stays parked at the situation's position; the next Advance will naturally
# bypass it (distance = 0 is skipped in _find_target_situation) and move on.


# ────────────────────────────────────────────────────────────────────────────
# V2-INFRA-003 Phase 5 Slice C: the NPC-CONTACT CONVERSATION domain that used to live here
# (_handle_stage_consult_echoes, _handle_stage_speak_response, _handle_stage_disengage_contact,
# _apply_contact_outcome, _derive_contact_reaction_word, _contact_outcome_text and
# _build_contact_resolve_snapshot) moved to core/runtime/controllers/ContactController.gd.
# Dispatch routes the three stage.* contact actions through _contact_controller().
#
# V2-INFRA-003 Phase 5 Slice D: the VENTURE domain that used to live here moved to
# core/runtime/controllers/VentureController.gd (10 actions) and, for the long procedural
# bodies and the two FlowContext-reading snapshot producers, to
# core/realms/ActiveStageService.gd:
#   _handle_directive_select                → VentureController.handle_directive_select
#   _handle_stage_advance_turn              → VentureController.handle_advance_turn
#                                             + ActiveStageService.advance_turn
#   _handle_stage_return_home               → VentureController.handle_return_home
#   _handle_stage_engage_situation          → VentureController.handle_engage_situation
#                                             + ActiveStageService.engage_situation
#   _handle_stage_resolve_situation_choice  → VentureController.handle_resolve_situation_choice
#                                             + ActiveStageService.resolve_situation_choice
#   _handle_stage_ignore_situation          → VentureController.handle_ignore_situation
#   _handle_complete_stage                  → VentureController.handle_complete_stage
#   _resolve_situation_to_screen            → VentureController._situation_resolve_outcome
#   _build_situation_resolve_snapshot       → ActiveStageService
#                                             .build_situation_resolve_snapshot (static)
#   _build_scout_return_snapshot            → ActiveStageService
#                                             .build_scout_return_snapshot (static) — it had
#                                             two callers in two domains (stage.return_home and
#                                             _handle_encounter_retreat, which stays here for
#                                             Phase 6) and it reads FlowContext, which
#                                             ResolveSnapshotBuilder's purity contract forbids.
#
# V2-INFRA-003 Phase 5 Slice E re-homed those five again, without touching behaviour, because
# ActiveStageService had reached 1,461 lines. The destinations above should now read:
#   advance_turn                     → core/realms/StageExploreTurnService.gd
#   engage_situation                 → core/realms/SituationEngagementService.gd
#   resolve_situation_choice         → core/realms/SituationEngagementService.gd
#   build_situation_resolve_snapshot → core/state/flow/states/venture/
#                                      VentureResolveSnapshotBuilder.gd (static)
#   build_scout_return_snapshot      → the same file (static). It is BESIDE
#                                      ResolveSnapshotBuilder, never inside it, so the
#                                      no-FlowContext purity contract quoted above still holds.
# PHASE 6 READS THIS: _handle_encounter_retreat now calls
# VentureResolveSnapshotBuilder.build_scout_return_snapshot(), and _end_round still reaches
# ActiveStageService.resolve_combat_situation_and_objective() through
# _apply_victory_return_to_explore — that one did NOT move.
#
# CORRECTION to Slice C's STEP 0 note: _start_contact_conversation did NOT have to stay.
# Both of its recorded blockers are gone now that stage.engage_situation is owned and can
# carry a FlowActionOutcome, so it moved to core/realms/ContactConversationService.gd — the
# SERVICE the contact route out of engage_situation passes through, because VentureController
# may not call ContactController. See that file's header.
#
# flow.select_stage NO LONGER remains inline in dispatch(). V2-INFRA-003 Phase 6 Slice 6F
# demoted persist_equipped_skills to core/progression/SkillLoadoutService.gd, which removed the
# controller-to-controller call Slice D recorded as its blocker, and the case moved to
# VentureController.handle_select_stage(). See VentureController.gd's STEP 0a note.
# ────────────────────────────────────────────────────────────────────────────


# V2-INFRA-003 Phase 5 Slice C: _load_contact_responses (and its _contact_responses_cache
# instance member) moved to core/realms/ContactResponseService.load_responses() — see that
# file's header for why it became a shared static service rather than a ContactController
# method. Its callers are ContactController and (Slice D) ContactConversationService.


# V2-INFRA-003 Phase 4 Slice 3: the spirit-bark, ally-bark, travel-beat and Anansi-snippet
# helpers that used to live here (_load_spirit_barks, _fire_spirit_bark, _load_ally_barks,
# _fire_ally_bark, _select_travel_beat, _select_travel_bark, _fire_anansi_snippet,
# _anansi_snippet_events_cfg) moved to core/echoes/NarrativeVoiceService.gd — see that file's
# header for the full rationale. Call sites now go through _voice_service().


# V2-INFRA-003 Phase 5 Slice A: the stage-explore SESSION domain that used to live here
# moved to core/realms/ActiveStageService.gd — see that file's header for the full
# rationale, the location correction, and the parameterised collapse of the two drifted
# situation-resolution bodies:
#   _get_active_party_echoes            → deleted; the five call sites now call the static
#                                         SanctumService.get_active_party_echoes(save_data)
#                                         directly (the wrapper added nothing).
#   _intel_clue_for_type                → deleted; its one call site now calls the static
#                                         FlowStageExploreState._intel_clue_for_type_static()
#                                         directly (it was a one-line delegate).
#   _find_target_situation              → DELETED AS DEAD CODE. Superseded by
#                                         _find_explore_target (V2-COMBAT-002 Slice 6C); the
#                                         only remaining references anywhere in core/, ui/ or
#                                         tests/ were two prose comments.
#   _mark_situation_revealed            → DELETED AS DEAD CODE. Superseded by
#                                         FlowStageExploreState._reveal_situation_static; no
#                                         caller anywhere in core/, ui/ or tests/.
#   _explore_walkable, _lift_fog_at_cell, _situation_blocks_step, _stage_party_heading,
#   _stage_reachable_costs, _stage_integer_cell, _count_revealed_situations,
#   _get_stage_base_reward, _stage_movement_salt, _find_explore_target,
#   _mark_stage_objective_completed, _resolve_combat_situation_and_objective
#                                       → ActiveStageService.
#   _stage_situation_category_map       → ConfigService.get_situation_category_cfg
#   _stage_movement_slack_config        → ConfigService.get_movement_slack_cfg
#   _get_balance_rewards_cfg            → ConfigService.get_rewards_cfg
#
# V2-INFRA-003 Phase 4 Slice 4: _apply_morale_to_party moved to
# core/emotion/EmotionConsequenceService.gd. Call sites now go through
# _emotion_consequence_service().


# V2-INFRA-003 Phase 4 Slice 3: the sanctum-bark helpers that used to live here
# (_select_sanctum_barkers, _voice_urgency_score, _select_sanctum_bark_for_actor_and_write,
# _select_sanctum_bark_for_echo_data_and_write, _select_arrival_barks_for_party) moved to
# core/echoes/NarrativeVoiceService.gd — see that file's header for the full rationale. Call
# sites now go through _voice_service().


# ---------------------------------------------------------------------------
# V2-INFRA-003 Phase 4 Slice 4: _get_emotion_recovery_cfg / _get_fear_threshold /
# _apply_emotion_recovery_if_needed / _apply_run_emotion_modifiers moved to
# core/emotion/EmotionConsequenceService.gd (get_emotion_recovery_cfg moved on to
# ConfigService instead — see that file's header for the correction). Call sites now go
# through _emotion_consequence_service().
# ---------------------------------------------------------------------------


## _build_run_consequence_notification removed — Resolve screen already presents this data.
