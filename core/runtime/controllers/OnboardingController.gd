# res://core/runtime/controllers/OnboardingController.gd
# V2-INFRA-003 Phase 4 Slice 9 (Part A): Chapter I onboarding controller extracted out of
# FlowRuntime.gd, following the pattern SanctumController/WeaveController/VowController/
# DebugController/ProgressionController/EconomySettlementController set (see
# SanctumController.gd for the fullest recent contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or rebuild a snapshot itself. Every handler returns a
#     FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it
#     via _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — save intent is
#     reported on the returned FlowActionOutcome (save_reasons) and applied by
#     FlowRuntime.dispatch() via flow_ctx.request_save().
#   - No UI or scene-tree reference.
#
# PART A owns 5 actions: onboarding.advance, onboarding.fragment.hear,
# onboarding.fragment.select, onboarding.fragment.confirm, onboarding.name.confirm.
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd: _handle_onboarding_advance,
# _handle_onboarding_fragment_hear, _handle_onboarding_fragment_select,
# _handle_onboarding_fragment_confirm, _handle_onboarding_name_confirm,
# _grant_starter_echo_for_fragment, _rebuild_current_onboarding_snapshot.
#
# PART B owns 7 more actions: keeper_intro.call.answer, keeper_intro.trial.finish,
# keeper_intro.rewind.continue, keeper_intro.thread.continue, keeper_intro.awakening.choose,
# keeper_intro.weave.complete, keeper_intro.complete. Moved verbatim (behaviour unchanged) from
# FlowRuntime.gd: _handle_keeper_intro_call_answer, _handle_keeper_intro_trial_finish,
# _handle_keeper_intro_rewind_continue, _handle_keeper_intro_thread_continue,
# _handle_keeper_intro_awakening, _handle_keeper_intro_weave, _handle_keeper_intro_complete.
# Needs `econ: EconomyService` (handle_trial_finish -> KeeperIntroService.grant_trial_rewards)
# on top of Part A's flow_ctx/config_service/logger — matches SanctumController's dependency set.
#
# NOT moved to this controller — see core/onboarding/KeeperIntroService.gd's own header notes
# for the corrected placement and why:
#   _setup_keeper_intro_trial_encounter -> KeeperIntroService.setup_trial_encounter()
#     (shared by two FlowRuntime call sites that are NOT dispatched actions — a controller
#     cannot be reached from there — plus this controller's handle_call_answer/
#     handle_rewind_continue, which call the same static)
#   _is_keeper_intro_trial_active       -> KeeperIntroService.is_trial_active()
#   _keeper_intro_trial_lethal_echo_ids -> KeeperIntroService.trial_lethal_echo_ids()
#   _keeper_intro_trial_enemy_defeated  -> KeeperIntroService.trial_enemy_defeated()
#   _keeper_intro_restore_echo_after_second_attempt -> KeeperIntroService.restore_echo_after_second_attempt()
#   _handle_keeper_intro_trial_rewind   -> KeeperIntroService.apply_trial_rewind()
# All six are read/write helpers over flow_ctx.encounter_ctx keyed on the Keeper-intro trial
# encounter id, called from FlowRuntime._resolve_next_actor() (combat round resolution — a
# different domain from dispatched actions; "controller-to-controller is forbidden and
# FlowRuntime must not call into a controller for a non-action" per core/AGENTS.md). Only
# trial_enemy_defeated() and is_trial_active() are also read by this controller's
# handle_trial_finish() below — a helper used by two domains belongs on a service.
#
# THE REFRESH-SNAPSHOT TRANSLATION (mirrors SanctumController's sanctum.name.reroll note):
# _rebuild_current_onboarding_snapshot(t) built a fresh ONBOARDING-family snapshot and called
# flow_machine.refresh_snapshot() unconditionally. It is split here into a private
# _build_onboarding_snapshot(t) -> Dictionary (pure build, no side effect) whose result is
# wrapped in FlowActionOutcome.snapshot_outcome() by each handler that needs it —
# _apply_action_outcome()'s has_replacement_snapshot branch then calls
# flow_machine.refresh_snapshot() on FlowRuntime's behalf, exactly matching the pre-extraction
# call sequence (build -> assign -> refresh).
#
# D42 / D63 — FIXED in Phase 8C. handle_name_confirm used to set sanctum.ase_flame.awakened =
# true, lighting the Ase Flame at the end of Chapter I, one full chapter before the intended
# awakening beat. That write is now DELETED (not relocated): KeeperIntroService.awaken_flame(),
# called from handle_awakening() below at the KEEPER_AWAKENING step, already sets the flag —
# together with the boost duration and rate — idempotently. See handle_name_confirm for the
# reader-by-reader account of what a dark Flame for one more chapter changes.
#
# EchoFactory RNG draw order (rarity -> calling_origin -> gender -> name -> traits ->
# archetype_birth -> derived_stats) is IMMUTABLE inside _grant_starter_echo_for_fragment()
# below — moved verbatim, never reordered. Seed path "campaign.starter.0" is unchanged.

class_name OnboardingController
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## onboarding.advance — moved verbatim from FlowRuntime._handle_onboarding_advance. No-op
## (handled_outcome(), no save/transition) once STEP_COMPLETE would be reached — matches
## pre-extraction bare `return`.
func handle_advance(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	var step := OnboardingService.current_step(flow_ctx.save_data, cfg)
	var next := OnboardingService.next_step(step)
	if next == OnboardingService.STEP_COMPLETE:
		return FlowActionOutcome.handled_outcome()

	OnboardingService.set_step(flow_ctx.save_data, cfg, next)
	return FlowActionOutcome.transition_outcome(
		OnboardingService.step_to_flow_id(next), "ui.onboarding.advance"
	).with_save_reason("onboarding.advance")


## onboarding.fragment.hear — moved verbatim from FlowRuntime._handle_onboarding_fragment_hear.
func handle_fragment_hear(action: Dictionary, t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	var virtue := str(action.get("virtue", "")).strip_edges().to_lower()
	OnboardingService.mark_heard(flow_ctx.save_data, cfg, virtue)
	return FlowActionOutcome.snapshot_outcome(_build_onboarding_snapshot(t)).with_save_reason("onboarding.fragment.hear")


## onboarding.fragment.select — moved verbatim from FlowRuntime._handle_onboarding_fragment_select.
func handle_fragment_select(action: Dictionary, t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	var virtue := str(action.get("virtue", "")).strip_edges().to_lower()
	OnboardingService.mark_heard(flow_ctx.save_data, cfg, virtue)
	OnboardingService.select_fragment(flow_ctx.save_data, cfg, virtue)
	return FlowActionOutcome.snapshot_outcome(_build_onboarding_snapshot(t)).with_save_reason("onboarding.fragment.select")


## onboarding.fragment.confirm — moved verbatim from FlowRuntime._handle_onboarding_fragment_confirm.
## Denied path (no fragment selected) rebuilds the current onboarding snapshot with no save —
## matches pre-extraction exactly (that path only rebuilt + refreshed, no save request).
func handle_fragment_confirm(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	var selected := OnboardingService.selected_fragment(flow_ctx.save_data, cfg)
	if selected.is_empty():
		logger.debug(t, "onboarding.fragment.confirm.denied", "No fragment selected", {})
		return FlowActionOutcome.snapshot_outcome(_build_onboarding_snapshot(t))

	_grant_starter_echo_for_fragment(selected, t)
	OnboardingService.set_step(flow_ctx.save_data, cfg, OnboardingService.STEP_MEETING)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.ONBOARDING_MEETING, "ui.onboarding.fragment.confirm"
	).with_save_reason("onboarding.fragment.confirm")


## onboarding.name.confirm — moved verbatim from FlowRuntime._handle_onboarding_name_confirm,
## then amended in Phase 8C: the early Ase Flame write (D42 / D63) is deleted. See the block
## where it used to be, below.
func handle_name_confirm(action: Dictionary, t: int) -> FlowActionOutcome:
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
	KeeperIntroService.start_after_chapter_one(flow_ctx.save_data, cfg)

	# V2-INFRA-003 Phase 8C (defects D42 / D63): the `sanctum.ase_flame.awakened = true` write
	# that used to sit here is DELETED, not relocated. KeeperIntroService.awaken_flame() already
	# does the whole job — flag, boost duration, boost rate — idempotently, at the KEEPER_AWAKENING
	# beat where the narrative puts it. Writing it here as well only lit the Flame a full chapter
	# early and spoiled that beat for every player.
	#
	# What a dark Flame for one more chapter changes, at every measured reader:
	#   OfflineAccrualService:102-107,134 — no offline Ase accrues during the keeper intro. The
	#     house is genuinely dormant now, which is what that gate was written to express.
	#   EconomySettlementService:132 — online accrual rate stays 0 for the same window.
	#   FlowSummonState:49-51 — the per-hour RATE HINT reads 0. Summoning is NOT disabled by it;
	#     `summon_disabled` is affordability only (ase_balance < selected_cost). Verified.
	#   SanctumSnapshotBuilder:386-396 — ase_flame_awakened false, rate hint 0. Not player-visible
	#     in this window: flow.sanctum is unreachable until keeper_intro.complete.
	#   FlowKeeperIntroState:84-96 -> KeeperIntroScreen.gd:65 — THE VISIBLE FIX. The flame core
	#     shows on `step == "awakening_rite" or flame.awakened`; with the early write it was lit
	#     on every intro step from the Call onward. It now lights at the awakening and stays lit.
	#   SanctumLayoutService:78,110-135 — reads NOTHING here. The `ase_flame` entry there is a
	#     layout TILE, present unconditionally; it never consults `awakened`.

	logger.info(t, "onboarding.name.confirm", "Chapter I complete; Sanctum name set", {
		"name": name
	})

	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_CALL, "ui.onboarding.name.confirm"
	).with_save_reason("onboarding.name.confirm")


## Moved verbatim from FlowRuntime._grant_starter_echo_for_fragment. Only caller:
## handle_fragment_confirm() above. EchoFactory RNG draw order is IMMUTABLE — see file header.
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


## Moved verbatim from FlowRuntime._rebuild_current_onboarding_snapshot, split into a pure
## build step — see file header's "THE REFRESH-SNAPSHOT TRANSLATION" note. Used by
## handle_fragment_hear, handle_fragment_select, and handle_fragment_confirm's denied path.
func _build_onboarding_snapshot(t: int) -> Dictionary:
	var cfg := config_service.get_balance()
	var step := OnboardingService.current_step(flow_ctx.save_data, cfg)
	var flow_id := OnboardingService.step_to_flow_id(step)
	return FlowOnboardingState.build_snapshot(flow_ctx, t, step, flow_id)


# ---------------------------------------------------------------------------------------------
# PART B — Keeper intro after Chapter I
# ---------------------------------------------------------------------------------------------

## keeper_intro.call.answer — moved verbatim from FlowRuntime._handle_keeper_intro_call_answer.
## KeeperIntroService.setup_trial_encounter() replaces the private
## _setup_keeper_intro_trial_encounter(t) call — see file header for why that helper moved to
## the service instead of this controller.
func handle_call_answer(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	KeeperIntroService.ensure_starter_party(flow_ctx.save_data)
	KeeperIntroService.setup_trial_encounter(flow_ctx, cfg, t)
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_TRIAL)
	var onboarding: Dictionary = flow_ctx.save_data.get("onboarding", {})
	onboarding["keeper_trial_phase"] = KeeperIntroService.TRIAL_READY
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_TRIAL, "keeper_intro.call.answer"
	).with_save_reason("keeper_intro.call.answer")


## keeper_intro.trial.finish — moved verbatim from FlowRuntime._handle_keeper_intro_trial_finish.
## Blocked path (trial active, enemy not yet defeated) rebuilds the current combat round
## snapshot with no save request — matches pre-extraction exactly (that path only rebuilt +
## refreshed). Uses KeeperIntroService.is_trial_active()/.trial_enemy_defeated() — the two
## service reads shared with FlowRuntime's combat path (see file header).
func handle_trial_finish(t: int) -> FlowActionOutcome:
	if KeeperIntroService.is_trial_active(flow_ctx) and not KeeperIntroService.trial_enemy_defeated(flow_ctx):
		logger.info(t, "keeper_intro.trial.finish.blocked", "First trial rewards blocked until the Fragment Wound is defeated", {})
		return FlowActionOutcome.snapshot_outcome(EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t))
	var cfg := config_service.get_balance()
	KeeperIntroService.grant_trial_rewards(flow_ctx.save_data, cfg, econ, logger, t)
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.encounter_id = ""
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_THREAD_RETURN)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_THREAD_RETURN, "keeper_intro.trial.finish"
	).with_save_reason("keeper_intro.trial.finish")


## keeper_intro.rewind.continue — moved verbatim from FlowRuntime._handle_keeper_intro_rewind_continue.
func handle_rewind_continue(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	KeeperIntroService.ensure_starter_party(flow_ctx.save_data)
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_TRIAL)
	var onboarding: Dictionary = KeeperIntroService.ensure_intro(flow_ctx.save_data, cfg)
	onboarding["keeper_trial_phase"] = KeeperIntroService.TRIAL_READY
	KeeperIntroService.setup_trial_encounter(flow_ctx, cfg, t)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_TRIAL, "keeper_intro.rewind.continue"
	).with_save_reason("keeper_intro.rewind.continue")


## keeper_intro.thread.continue — moved verbatim from FlowRuntime._handle_keeper_intro_thread_continue.
func handle_thread_continue(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_AWAKENING)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_AWAKENING, "keeper_intro.thread.continue"
	).with_save_reason("keeper_intro.thread.continue")


## keeper_intro.awakening.choose — moved verbatim from FlowRuntime._handle_keeper_intro_awakening.
## The Time.get_unix_time_from_system() call is pre-existing behaviour, moved as-is — not
## introduced by this extraction, out of scope to fix here.
func handle_awakening(action: Dictionary, t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	var choice := str(action.get("choice", "")).strip_edges()
	KeeperIntroService.awaken_flame(flow_ctx.save_data, cfg, choice, logger, t)
	logger.info(t, "economy.ase_flame.awakened", "Ase Flame awakened", { "choice": choice })

	# V2-INFRA-003 Phase 8C: arm the one-shot awakening modal.
	#
	# The modal (ui/overlays/sanctum/AwakeningModal.tscn, registered in SanctumShell's modal map)
	# and its whole render path already existed and had NEVER rendered, for one reason: nothing
	# in core/ or ui/ ever set this flag true — the only production write set it false, in the
	# consume closure at the end of FlowRuntime.dispatch().
	#
	# Set here, at the awakening, not at keeper_intro.complete: this IS the awakening beat, and
	# the established consume gate does the rest. That closure clears the flag only when the
	# published snapshot is a flow.sanctum one, so the flag survives the two intervening
	# dispatches (keeper_intro.weave.complete -> KEEPER_WEAVING, keeper_intro.complete ->
	# SANCTUM) and is spent by exactly the first Sanctum snapshot the player is shown.
	#
	# NO ASE IS GRANTED WITH IT. `data.economy.awakening_ase_grant` stays unreachable and belongs
	# to V2-ECONOMY-002; the player leaves the intro with the 40 Ase from the first trial and
	# nothing more. The modal was showing a "+40 Ase" line that no code paid — that label is
	# removed from the scene in this same slice so the copy cannot promise money that never
	# arrives.
	flow_ctx.pending_awakening_banner = true

	var econ_data_v: Variant = flow_ctx.save_data.get("economy", {})
	if econ_data_v is Dictionary:
		var econ_data: Dictionary = econ_data_v
		econ_data["last_settle_unix"] = int(Time.get_unix_time_from_system())
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_WEAVING)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_WEAVING, "keeper_intro.awakening"
	).with_save_reason("keeper_intro.awakening")


## keeper_intro.weave.complete — moved verbatim from FlowRuntime._handle_keeper_intro_weave.
func handle_weave(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	KeeperIntroService.apply_first_weave(flow_ctx.save_data, cfg, logger, t)
	# V2-INFRA-003 Phase 8C: the opening Realm is unlocked by AWAKENING + FIRST WEAVE — both
	# beats are now behind us, so the gate opens here. mark_realm_ready() re-checks the Flame
	# itself and is a no-op unless the status is still "locked", so a replay cannot double-open
	# it. See OpeningRealmService's header for why the gate is not the second Echo.
	OpeningRealmService.mark_realm_ready(flow_ctx.save_data, logger, t)
	KeeperIntroService.set_step(flow_ctx.save_data, cfg, KeeperIntroService.STEP_KEEPING)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.KEEPER_KEEPING, "keeper_intro.weave"
	).with_save_reason("keeper_intro.weave")


## keeper_intro.complete — moved verbatim from FlowRuntime._handle_keeper_intro_complete. Uses
## this controller's own _emotion_consequence_service() factory (below) rather than reaching
## back into FlowRuntime's — controllers may not call FlowRuntime, so each controller that needs
## a per-call service builds its own, same rationale as SanctumController's private
## _economy_settlement_service().
func handle_complete(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()
	KeeperIntroService.mark_complete(flow_ctx.save_data, cfg)
	# V2-INFRA-003 Phase 8C: THE OPENING REALM OPENS HERE. The gate was armed by the first Weave
	# one dispatch ago; this creates the single-stage prologue run around the player's starter
	# virtue and makes it the active Realm, so the Sanctum the player lands on already has a
	# trial waiting. It adds NO dispatch — it runs inside this one. No-op unless the status is
	# exactly "realm_ready", so an old save or a replay cannot re-open it.
	OpeningRealmService.open_prologue(flow_ctx, t)
	_emotion_consequence_service().apply_sanctum_emotion_tick(t)
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.SANCTUM, "keeper_intro.complete"
	).with_save_reason("keeper_intro.complete")


## Builds a fresh EmotionConsequenceService scoped to the current flow_ctx/config_service/
## logger. Constructed per-call, same rationale as SanctumController's
## _economy_settlement_service(): cheap RefCounted, always correct even if flow_ctx is replaced
## after construction. Used by handle_complete() above.
func _emotion_consequence_service() -> EmotionConsequenceService:
	return EmotionConsequenceService.new(flow_ctx, config_service, logger)
