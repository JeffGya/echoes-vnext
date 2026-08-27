# res://core/runtime/controllers/VentureController.gd
# V2-INFRA-003 Phase 5 Slice D: the VENTURE domain extracted out of FlowRuntime.gd, following
# the contract WeaveController/VowController/DebugController/ProgressionController/
# EconomySettlementController/SanctumController/OnboardingController/ContactController set
# (see WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or refresh a snapshot itself. Every handler returns a
#     FlowActionOutcome; FlowRuntime._apply_action_outcome() is the single place that acts on it.
#   - Never calls another controller. Never calls SaveService directly — saves go through
#     flow_ctx.request_save(reason).
#   - No UI or scene-tree reference.
#   - Reached through FlowRuntime._venture_controller(), a per-call factory.
#
# Owns 11 actions: stage.advance_turn, stage.engage_situation, stage.resolve_situation_choice,
# flow.complete_stage, stage.return_home, stage.ignore_situation, directive.select,
# stage.dismiss_overlay, flow.select_realm, stage.confirm_return_home, and — added in Phase 6
# Slice 6F — flow.select_stage.
#
# ---------------------------------------------------------------------------
# STEP 0a — what could NOT move in Slice D, and why it moved in Slice 6F
# ---------------------------------------------------------------------------
#
# SLICE D RECORDED: flow.select_stage STAYS INLINE ON FlowRuntime.dispatch(). Its body calls
# `_progression_controller().persist_equipped_skills(t)` before transitioning to STAGE.
# Moving the case here would make VentureController call ProgressionController, which
# AGENTS.md forbids outright ("Controllers must never call one another"). The legal fix is to
# demote persist_equipped_skills to a service both controllers may call — but that is a second
# extraction of a function ProgressionController's Slice 6b header deliberately placed on the
# controller ("NOT a dispatched-action handler — called as a preparatory step from
# FlowRuntime's flow.select_stage case (which stays on FlowRuntime)"), and it is not in this
# slice's scope. Recorded, not forced. flow.select_stage's owner remains FlowRuntime.dispatch().
#
# SLICE 6F RESOLVED IT, by doing precisely the fix Slice D named. persist_equipped_skills is now
# core/progression/SkillLoadoutService.gd::persist_equipped_skills — a service, reachable by any
# caller — so no controller-to-controller call remains and the case moved here verbatim as
# handle_select_stage(). Nothing was duplicated and no lookalike API was substituted; the single
# definition moved and both the old and new owners are forwarder-free. With this, every action
# FlowRuntime.dispatch() routes has exactly one non-provisional owner.
#
# _apply_victory_return_to_explore and _handle_encounter_retreat also stay on FlowRuntime —
# neither is in this slice's move list, and the first reads flow_machine._current_state_id
# (recorded by Slice B).
#
# ---------------------------------------------------------------------------
# STEP 0b — THE CONTACT SEAM
# ---------------------------------------------------------------------------
#
# stage.engage_situation routes NPC-with-contact situations into the conversation setup that
# Slice C left on FlowRuntime as _start_contact_conversation. A controller may not call
# ContactController, so that route now passes through a SERVICE:
# core/realms/ContactConversationService.start_conversation(). See that file's header for the
# full reasoning and for the CORRECTION it records against ContactController's STEP 0 note —
# in short, the "services take no flow_machine" objection dissolves because the only
# flow_machine work on that path was the trailing
#   flow_ctx.last_snapshot = StageExploreSnapshotBuilder.build(flow_ctx, t)
#   flow_machine.refresh_snapshot(flow_ctx, logger, t)
# pair, which handle_engage_situation() now returns as
# FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t)) — the
# exact assign-then-refresh _apply_action_outcome() performs. The service publishes nothing.
#
# ---------------------------------------------------------------------------
# SIZE — how this file stays inside its budget
# ---------------------------------------------------------------------------
# The eleven pre-extraction bodies total ~1,040 lines. A controller routes an action, applies
# domain calls and returns an outcome; it does not hold long procedural bodies. The four
# heaviest bodies therefore moved into core/realms/ActiveStageService.gd — the service
# Slice A built for exactly this — as advance_turn(), engage_situation() and
# resolve_situation_choice(), each returning a plain verdict this file translates into an
# outcome. Two snapshot PRODUCERS moved there too: build_scout_return_snapshot() (two callers
# in two domains — handle_return_home here and FlowRuntime._handle_encounter_retreat — and it
# reads FlowContext, so ResolveSnapshotBuilder's no-FlowContext purity contract disqualifies
# that file as its home) and build_situation_resolve_snapshot() (reached from both situation
# handlers). Nothing was duplicated and no lookalike API was substituted.
#
# SLICE E UPDATE — those five landed on ActiveStageService and took it to 1,461 lines,
# past the ~1,000-line guard. Slice E re-homed them without changing behaviour, so this file's
# call sites now read:
#   advance_turn                     → StageExploreTurnService              (_turn_service())
#   engage_situation                 → SituationEngagementService  (_situation_engagement_service())
#   resolve_situation_choice         → SituationEngagementService  (_situation_engagement_service())
#   build_scout_return_snapshot      → VentureResolveSnapshotBuilder (static)
#   build_situation_resolve_snapshot → VentureResolveSnapshotBuilder (static)
# The producers moved BESIDE ResolveSnapshotBuilder, not INTO it — the purity contract quoted
# above is intact and untouched. See VentureResolveSnapshotBuilder.gd's header.
#
# ---------------------------------------------------------------------------
# TRANSLATIONS APPLIED (the only edits to the moved bodies)
# ---------------------------------------------------------------------------
#
# 1) `flow_ctx.last_snapshot = <build>` + `flow_machine.refresh_snapshot(...)`
#    → `return FlowActionOutcome.snapshot_outcome(<build>)`.
#
# 2) `flow_ctx.last_snapshot = <build>` + `flow_machine.transition(RESOLVE, ...)` with NO
#    refresh between them (handle_return_home's escape success, and the situation resolve
#    screen) → snapshot_outcome_no_refresh() + transition_to. suppress_refresh is REQUIRED,
#    not stylistic: plain snapshot_outcome() would inject a refresh that never ran before.
#
# 3) A BARE `flow_machine.refresh_snapshot(...)` with no preceding assignment →
#    FlowActionOutcome.refresh_outcome(), a shape added by this slice. Two paths need it:
#    stage.advance_turn's not-exploring guard, and directive.select when the live snapshot is
#    not flow.stage. handled_outcome() would silently DROP that refresh.
#
# 4) `flow_machine.transition(X, ...)` + bare `return` → FlowActionOutcome.transition_outcome().
#
# 5) Every bare `return` guard → FlowActionOutcome.handled_outcome() — matches the
#    pre-extraction void return exactly (no snapshot, no refresh, no transition, no save).
#
# 6) `_mark_save_requested(reason)` → `flow_ctx.request_save(reason)`, at the ORIGINAL point.
#    Deliberately NOT translated to FlowActionOutcome.with_save_reason(): _apply_action_outcome()
#    applies save_reasons AFTER the transition, and FlowContext.request_save() appends to a
#    "|"-joined string FlowRuntime logs at its save choke point — deferring a reason past a
#    transition whose enter() may itself request a save would reorder that string.
#
# ---------------------------------------------------------------------------
# DETERMINISM
# ---------------------------------------------------------------------------
# 1) THE ESCAPE ROLL. Seed path "stage.escape.%s.%d" % [stage_id, turn_count]. The turn_count
#    READ is in handle_return_home() below; the INCREMENT is inside
#    StageExploreTurnService.advance_turn(). They are different handlers and both moved in
#    this slice; their relative order is unchanged — the increment still happens only on an
#    advance, after target selection, and the read still happens only on a return-home attempt.
#    No seed path string was edited and no draw was reordered inside a generator.
# 2) CONVERSATION TEXT IS TICK-DERIVED. ConversationService uses (t + str(echo_id).hash()) % 997
#    and dispatch() computes one tick per action, so adding, removing or reordering a dispatch
#    changes what an NPC says. This slice adds, removes and reorders none.
#    tests/ConversationRepairTests.gd guards it.
# All other venture randomness is path-derived (CampaignSeed.get_rng_from(realm_seed, path)),
# so extraction is safe.
#
# ---------------------------------------------------------------------------
# DEFECTS REPRODUCED, NOT FIXED (this slice is pure extraction)
# ---------------------------------------------------------------------------
# KNOWN DEFECT 1 — FIXED IN PHASE 8 (register D05). handle_complete_stage() on a NO-ENCOUNTER
#   path (encounter_ctx == null) defaulted `outcome` to "loss", so a stage completed without any
#   encounter paid nothing and was flavoured as a defeat by apply_encounter_emotion_drift / the
#   bond hooks, and wrote its Thread segment with grade "F" (= "broken"). The four
#   encounter-consequence hooks are now skipped when there was no encounter, the segment grade
#   comes from NO_COMBAT_GRADE, and the stage settlement below pays the stage regardless of
#   whether a fight happened. See the comments at each site.
# KNOWN DEFECT 2 — FIXED IN PHASE 8 (register D39). ActiveStageService.get_stage_base_reward()
#   read objectives[0] only, under a key ObjectiveModel never writes, so it returned a flat 30
#   for every stage while RewardCalc SUMMED the same stage's weights. Both readers now call
#   RewardCalc.base_reward(). Reached from handle_return_home() below.
# KNOWN DEFECT 3 — the victory-return path
#   (FlowRuntime._apply_victory_return_to_explore → resolve_combat_situation_and_objective with
#   skip_if_already_resolved=false, commit_only_when_modified=false) can double-increment
#   explore_map.objectives_found on a second pass, and commits/saves/logs unconditionally even
#   when it matched nothing. Recorded in full in ActiveStageService.gd's header.
# All three belong to later phases. Fixing a defect inside an extraction makes any later
# failure impossible to trace to one cause.
# ---------------------------------------------------------------------------

class_name VentureController
extends RefCounted

## V2-INFRA-003 Phase 8 (defect D05): the Thread-segment grade for a stage completed without any
## encounter. "C" maps to `"compromised"` in `data.threads.segment_quality_by_grade` — the stage
## counts toward the realm's recovery, but earns none of the `"clean"` tier that "S"/"A" give.
## Before Phase 8 this path silently used the "F" default, i.e. `"broken"`.
const NO_COMBAT_GRADE: String = "C"

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var directive_service: DirectiveService
var logger: StructuredLogger


func _init(
	_flow_ctx: FlowContext,
	_config_service: ConfigService,
	_econ: EconomyService,
	_directive_service: DirectiveService,
	_logger: StructuredLogger
) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	directive_service = _directive_service
	logger = _logger


# ---------------------------------------------------------------------------
# Per-call service factories (same rationale as FlowRuntime's own: cheap RefCounted,
# always correct even when flow_ctx is replaced after construction).
# ---------------------------------------------------------------------------

## V2-INFRA-003 Phase 5 Slice E: the stage-explore procedure bodies split in two when
## ActiveStageService passed the ~1,000-line guard. advance_turn lives on
## StageExploreTurnService; engage_situation / resolve_situation_choice on
## SituationEngagementService. Both take the same (flow_ctx, config_service, logger)
## constructor, so this is two factory lines where there was one.
func _turn_service() -> StageExploreTurnService:
	return StageExploreTurnService.new(flow_ctx, config_service, logger)


func _situation_engagement_service() -> SituationEngagementService:
	return SituationEngagementService.new(flow_ctx, config_service, logger)


func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


func _emotion_consequence_service() -> EmotionConsequenceService:
	return EmotionConsequenceService.new(flow_ctx, config_service, logger)


func _bond_consequence_service() -> BondConsequenceService:
	return BondConsequenceService.new(flow_ctx, config_service, logger)


func _vow_consequence_service() -> VowConsequenceService:
	return VowConsequenceService.new(flow_ctx, config_service, econ, logger)


func _recruitment_consequence_service() -> RecruitmentConsequenceService:
	return RecruitmentConsequenceService.new(flow_ctx, config_service, logger)


## V2-INFRA-003 Phase 6 Slice 6F: reaches the skill loadout persist that flow.select_stage runs
## before entering a stage. Takes (flow_ctx, logger) only — the service reads no config, and an
## unused config_service field would be a speculative dependency.
func _skill_loadout_service() -> SkillLoadoutService:
	return SkillLoadoutService.new(flow_ctx, logger)


# ---------------------------------------------------------------------------
# Stage exploration (V2-STAGE-001)
# ---------------------------------------------------------------------------

## stage.advance_turn — move the party toward the nearest unresolved situation
## (directive-guided), lifting fog per step and queueing an engagement popup on arrival.
## The whole turn body lives in StageExploreTurnService.advance_turn(); this maps its
## status onto the four pre-extraction snapshot tails.
func handle_advance_turn(_action: Dictionary, t: int) -> FlowActionOutcome:
	var status := _turn_service().advance_turn(directive_service, t)
	if status == "not_exploring":
		# Pre-extraction: a BARE flow_machine.refresh_snapshot() with no rebuild.
		return FlowActionOutcome.refresh_outcome()
	# no_stage / no_target / advanced all rebuilt from save_data then refreshed.
	# refresh_snapshot() alone only re-validates ctx.last_snapshot — it does not rebuild.
	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))


## stage.engage_situation — resolve a situation the party has reached.
## Routes: combat/shrine → flow.encounter; NPC-with-contact → conversation (via the contact
## seam service); choice panel → overlay on the explore snapshot; everything else → the
## situation resolve card on flow.resolve.
func handle_engage_situation(action: Dictionary, t: int) -> FlowActionOutcome:
	var verdict := _situation_engagement_service().engage_situation(str(action.get("situation_id", "")), econ, t)
	match str(verdict.get("outcome", "")):
		"async":
			return FlowActionOutcome.transition_outcome(
				FlowStateIds.ENCOUNTER, str(verdict.get("reason", ""))
			)
		"contact":
			return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))
		"choice":
			# Do not resolve — player must pick a choice first.
			var _snap := StageExploreSnapshotBuilder.build(flow_ctx, t)
			_snap["data"]["situation_overlay"] = {
				"situation_id": str(verdict.get("situation_id", "")),
				"type":         str(verdict.get("type", "")),
				"result_text":  "",
				"panel_kind":   "choice",
				"choices":      verdict.get("choices", []),
			}
			return FlowActionOutcome.snapshot_outcome(_snap)
		"resolved":
			return _situation_resolve_outcome(verdict, t)
		_:
			return FlowActionOutcome.handled_outcome()


## stage.resolve_situation_choice — player picked an option on a choice overlay
## (obstacle / structure). Payload: { "situation_id": String, "choice_id": String }.
func handle_resolve_situation_choice(action: Dictionary, t: int) -> FlowActionOutcome:
	var verdict := _situation_engagement_service().resolve_situation_choice(
		str(action.get("situation_id", "")), str(action.get("choice_id", "")), t
	)
	if str(verdict.get("outcome", "")) != "resolved":
		return FlowActionOutcome.handled_outcome()
	return _situation_resolve_outcome(verdict, t)


## P1 CLOSE: shared tail for both situation handlers — build the resolve card and route to the
## RESOLVE screen. Pre-extraction (_resolve_situation_to_screen) this assigned
## flow_ctx.last_snapshot and transitioned with NO refresh in between, hence
## snapshot_outcome_no_refresh(). `resolved=true` and the save were already applied by the
## session service, exactly as the pre-extraction caller applied them.
func _situation_resolve_outcome(verdict: Dictionary, t: int) -> FlowActionOutcome:
	var sit_v: Variant = verdict.get("sit", {})
	var sit: Dictionary = sit_v if sit_v is Dictionary else {}
	var emo_v: Variant = verdict.get("emotion_summary", [])
	var eff_v: Variant = verdict.get("effects", [])
	var _snap := VentureResolveSnapshotBuilder.build_situation_resolve_snapshot(
		sit,
		str(verdict.get("summary_line", "")),
		emo_v if emo_v is Array else [],
		eff_v if eff_v is Array else [],
		int(verdict.get("ase_awarded", 0)),
		t
	)
	var outcome := FlowActionOutcome.snapshot_outcome_no_refresh(_snap)
	outcome.transition_to = FlowStateIds.RESOLVE
	outcome.transition_reason = "stage.situation.resolve_screen"
	return outcome


## stage.return_home — party attempts to leave before completing all objectives.
## Escape check: seeded roll > (40 - directive.escape_bonus) = success.
## Success → party_state = "escaped", partial intel Ase, transition to the scout-return card.
## Failure → return_home_result overlay on the explore snapshot.
##
## DETERMINISM: the turn_count READ below is the counterpart of the increment inside
## StageExploreTurnService.advance_turn(). Do not move either relative to the other.
func handle_return_home(_action: Dictionary, t: int) -> FlowActionOutcome:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.return.no_stage", "return_home: no active stage", {})
		return FlowActionOutcome.handled_outcome()

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
		explore_map["party_state"] = StageExploreModel.STATE_ESCAPED
		stage["explore_map"] = explore_map
		FlowStageExploreState._write_stage_back(flow_ctx, stage)
		flow_ctx.request_save("stage.escaped")

		# V2-ECONOMY-001: Intel-gated partial Ase award.
		# V2-STAGE-004-P2: intel_retention keeps full revealed-count value (no penalty on withdrawal).
		var _intel_count := ActiveStageService.count_revealed_situations(flow_ctx)
		var _partial_ase := 0
		if _intel_count > 0:
			var _pf := float(ConfigService.get_rewards_cfg(config_service).get("partial_intel_reward_factor", 0.12))
			# V2-STAGE-004-P2: intel_retention — a directive that retains intel on a failed/partial
			# withdrawal multiplies the partial reward by its `intel_retention_bonus` (data-driven,
			# default 1.0 = no change). Scout (retention true, bonus 1.5) keeps more of the value it
			# gathered; Seek (false) does not. Magnitude is tunable in data.directives.
			# Phase 8 (D39): get_stage_base_reward() now sums the stage's objective weights via
			# RewardCalc.base_reward(), the same definition the stage payout uses. This partial
			# payout therefore rises on every multi-objective stage.
			var _retention_mul := 1.0
			if bool(directive.get("intel_retention", false)):
				_retention_mul = float(directive.get("intel_retention_bonus", 1.0))
			_partial_ase = roundi(float(ActiveStageService.get_stage_base_reward(flow_ctx, config_service)) * _pf * _retention_mul)
			if _partial_ase > 0:
				econ.add_ase(_partial_ase, "return_home_intel_partial", logger, t)
		flow_ctx.pending_scout_return_ase         = _partial_ase
		flow_ctx.pending_scout_return_intel_count = _intel_count

		_emotion_consequence_service().apply_sanctum_emotion_tick(t)
		var _outcome := FlowActionOutcome.snapshot_outcome_no_refresh(
			VentureResolveSnapshotBuilder.build_scout_return_snapshot(flow_ctx, t)
		)
		_outcome.transition_to = FlowStateIds.RESOLVE
		_outcome.transition_reason = "stage.return_home.scout_return"
		return _outcome

	# Escape failed — show overlay. Full consequence mechanic deferred to V2-INTEL-002.
	# V2-STAGE-004 P5 (playtest fix): Anansi event (d) — a failed return-home escape roll is
	# a genuine narrative beat. Clear any stale snippet first, then fire (gated by config).
	explore_map["travel_snippet"] = ""
	_voice_service().fire_anansi_snippet(explore_map, "return_home_failed", t)
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	var snap_fail := StageExploreSnapshotBuilder.build(flow_ctx, t)
	snap_fail["data"]["return_home_result"] = {
		"success": false,
		"message": "The way is blocked. The party cannot leave yet.",
	}
	return FlowActionOutcome.snapshot_outcome(snap_fail)


## stage.ignore_situation — V2-STAGE-002: dismiss the engagement popup without resolving.
## Clears pending_situation_id — intel gathered (revealed state) is preserved. Party stays
## parked at the situation's position; the next Advance naturally bypasses it.
func handle_ignore_situation(_action: Dictionary, t: int) -> FlowActionOutcome:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty():
		return FlowActionOutcome.handled_outcome()
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var sit_id := str(explore_map.get("pending_situation_id", ""))

	# V2-STAGE-004 Phase 2.5 (pass-fix): mark the ignored situation as passed=true
	# so find_explore_target skips it in Tiers 1–2 and the party explores the frontier
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
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.ignore_situation")

	logger.debug(t, "stage.explore.situation_ignored", "Engagement popup dismissed — situation marked passed", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})

	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))


## stage.dismiss_overlay — rebuild the explore snapshot from save_data so overlay data
## (return_home_result, situation_overlay) is stripped. refresh_snapshot() alone just
## re-validates the stale snapshot. Pre-extraction the whole body sat inside the
## `not _stg.is_empty()` guard: with no active stage NOTHING happened, not even a refresh.
func handle_dismiss_overlay(_action: Dictionary, t: int) -> FlowActionOutcome:
	if FlowStageExploreState._get_current_stage(flow_ctx).is_empty():
		return FlowActionOutcome.handled_outcome()
	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))


## stage.confirm_return_home — the player acknowledged the failed-escape overlay.
func handle_confirm_return_home(_action: Dictionary, _t: int) -> FlowActionOutcome:
	return FlowActionOutcome.transition_outcome(
		FlowStateIds.STAGE_MAP, "stage.return_home.confirmed"
	)


# ---------------------------------------------------------------------------
# Directives (DIRECTIVE-001)
# ---------------------------------------------------------------------------

## directive.select — set the active directive.
## Lesson 9: non-SANCTUM states read ctx.last_snapshot as-is on refresh. STAGE uses static
## build_snapshot() — rebuild before refresh so the snapshot reflects the new choice. Every
## other state refreshes WITHOUT a rebuild, which is what refresh_outcome() expresses.
func handle_directive_select(action: Dictionary, t: int) -> FlowActionOutcome:
	var id := str(action.get("directive_id", ""))
	directive_service.set_active_directive(id, logger, t)
	flow_ctx.request_save("directive.select")
	if flow_ctx.last_snapshot.get("type", "") == FlowStateIds.STAGE:
		return FlowActionOutcome.snapshot_outcome(FlowStageState.build_snapshot(flow_ctx, t))
	return FlowActionOutcome.refresh_outcome()


# ---------------------------------------------------------------------------
# Realm / stage progression (REALM-001 / REALM-004)
# ---------------------------------------------------------------------------

## flow.select_realm — REALM-001: create/retrieve the RealmModel, then go to the stage map.
##
## V2-INFRA-003 Phase 8C: validated against the opening-Realm gate. The normal Realms open only
## after the prologue is finished; until then this denies the selection and leaves the player on
## Realm Select (handled_outcome() — no transition, no snapshot replacement, no save), exactly
## the shape `handle_fragment_confirm`'s denied path uses.
##
## `realm.prologue` is not selectable through here at all. It is opened once, from
## `keeper_intro.complete`, by OpeningRealmService — Realm Select never lists it (it is absent
## from `realm_order`), so the only way to reach this branch with it is a hand-built action.
func handle_select_realm(action: Dictionary, t: int) -> FlowActionOutcome:
	var realm_id := str(action.get("realm_id", ""))
	if RealmService.is_prologue_run(realm_id):
		logger.info(t, "realm.select.denied", "The opening Realm is not selectable; it opens from the keeper intro", {
			"realm_id": realm_id,
		})
		return FlowActionOutcome.handled_outcome()
	if not OpeningRealmService.normal_realms_unlocked(flow_ctx.save_data):
		logger.info(t, "realm.select.denied", "Realms are locked until the opening Realm is complete", {
			"realm_id": realm_id,
			"opening_realm_status": OpeningRealmService.get_status(flow_ctx.save_data),
		})
		return FlowActionOutcome.handled_outcome()
	flow_ctx.realm_id = realm_id
	RealmService.get_or_create(realm_id, flow_ctx, t)  # sets save_request internally
	return FlowActionOutcome.transition_outcome(FlowStateIds.STAGE_MAP, "ui.realm_selected")


## flow.select_stage — sets the stage/encounter identity on FlowContext, persists the staged
## skill loadout, then transitions to STAGE.
##
## V2-INFRA-003 Phase 6 Slice 6F: moved verbatim out of FlowRuntime.dispatch()'s inline
## "flow.select_stage" case — the last action in the codebase whose owner was provisional. STEP
## 0a above recorded why it could not move in Slice D: its body called
## _progression_controller().persist_equipped_skills(t), and controllers may not call one
## another. Slice 6F demoted that function to core/progression/SkillLoadoutService.gd, which any
## caller may reach, so the recorded blocker is gone and the case moves as-is.
##
## ORDER IS LOAD-BEARING, and unchanged. The persist call stays INLINE here rather than becoming
## an outcome save_reason: FlowContext.request_save() joins reasons with "|", and
## FlowRuntime._apply_action_outcome() drains an outcome's save_reasons AFTER it applies the
## transition. Returning the reason instead of queuing it here would move "skill.persist" behind
## any reason the STAGE transition queues for itself, changing the joined string. Calling the
## service mid-handler reproduces the pre-move sequence exactly: identity writes → persist (which
## queues "skill.persist") → log → transition.
##
## No save is queued outside a dispatch boundary — this handler runs inside dispatch(), the same
## place the inline case ran.
func handle_select_stage(action: Dictionary, t: int) -> FlowActionOutcome:
	var stage_id := str(action.get("stage_id", ""))
	flow_ctx.stage_id     = stage_id
	flow_ctx.encounter_id = flow_ctx.realm_id + "." + stage_id  # BUG-003: was always ""
	flow_ctx.active_encounter_objective_index = -1  # V2-STAGE-002: reset on stage entry
	# PROG-009: persist skill loadout to save before entering the stage
	_skill_loadout_service().persist_equipped_skills(t)
	# VOW-001 / V2-VOW-002: vow entry condition evaluated on actual entry (go_state→STAGE_EXPLORE),
	# not here — covers first entry and re-entry after defeat.
	logger.info(t, "state.stage_select", "Stage selected", { "stage_id": stage_id })
	return FlowActionOutcome.transition_outcome(FlowStateIds.STAGE, "ui.flow.select_stage")


## flow.complete_stage — REALM-004: advance the stage index; on realm complete, clear context
## and route to REALM_SELECT. `destination` overrides the non-completed destination (cta.continue
## on victory routes to SANCTUM instead of STAGE_MAP); realm completion always wins.
func handle_complete_stage(action: Dictionary, t: int) -> FlowActionOutcome:
	var destination_override := str(action.get("destination", ""))

	# Fix BUG-003: read outcome BEFORE nulling encounter_ctx so drift reflects the actual result.
	#
	# V2-INFRA-003 Phase 8 — KNOWN DEFECT 1 (D05) FIXED HERE. `outcome` used to be seeded to
	# "loss" and upgraded only when an encounter context existed, so a stage completed WITHOUT a
	# fight took the full defeat treatment: the loss emotion drift (morale down, fear up,
	# loss_streak incremented, fear_base pushed up) and all three loss-flavoured bond hooks.
	# Nothing about finishing a stage without a fight is a defeat.
	#
	# The fix is a removal, not an invention. These four calls are ENCOUNTER-consequence hooks —
	# `apply_encounter_emotion_drift`, `apply_combat_bond_triggers`,
	# `apply_bond_aftermath_modifiers`, `seed_rival_stage_incidents` all take a combat outcome as
	# their subject. With no encounter there is no combat outcome for them to act on, so they do
	# not run. A no-encounter completion is deliberately NOT flavoured as a win either: the party
	# is not paid a victory's morale, it is simply not punished for a defeat that never happened.
	# The reward it SHOULD receive is D05's other half, and it now arrives through the stage
	# settlement below, which does not care whether an encounter happened.
	var has_encounter := flow_ctx.encounter_ctx != null
	var is_combat_victory := false
	if has_encounter:
		is_combat_victory = bool(flow_ctx.encounter_ctx.combat_result.get("victory", false))
	if has_encounter:
		var outcome := "win" if is_combat_victory else "loss"
		_emotion_consequence_service().apply_encounter_emotion_drift(outcome, t)
		# BOND-002: fire stage-level bond triggers + aftermath modifiers BEFORE nulling encounter context.
		_bond_consequence_service().apply_combat_bond_triggers(t, outcome)
		_bond_consequence_service().apply_bond_aftermath_modifiers(t, outcome)
		_bond_consequence_service().seed_rival_stage_incidents(t)
	# V2-VOW-002: decrement pledge cooldown on stage completion (victory only).
	var _cd_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _cd_sanc_v is Dictionary:
		var _cd_sanc: Dictionary = _cd_sanc_v as Dictionary
		var _cd_rem := int(_cd_sanc.get("pledge_cooldown_stages_remaining", 0))
		if _cd_rem > 0:
			_cd_sanc["pledge_cooldown_stages_remaining"] = _cd_rem - 1

	# VOW-001: post-stage complete benefit (obi_nnim_kyere full-scout bonus).
	_vow_consequence_service().apply_vow_stage_complete_benefit(t)

	# On combat victory: resolve the situation that triggered the encounter.
	# engage_situation deliberately left it unresolved so a defeat allows retry.
	if is_combat_victory and not flow_ctx.stage_id.is_empty():
		var _vstage := FlowStageExploreState._get_current_stage(flow_ctx)
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
					_vmap["party_state"] = StageExploreModel.STATE_COMPLETE
				_vstage["explore_map"] = _vmap
				FlowStageExploreState._write_stage_back(flow_ctx, _vstage)
				flow_ctx.request_save("stage.combat_resolved")
				logger.info(t, "stage.combat_resolved", "Combat situation resolved on victory", {
					"stage_id":     flow_ctx.stage_id,
					"situation_id": _vsit_id,
					"obj_found":    _vmap.get("objectives_found", 0),
					"obj_total":    _vmap.get("objectives_total", 0),
				})

	# VOW-001: discovery check runs AFTER the combat-victory situation write-back so
	# all_situations_scouted reads the correct revealed state. ectx is still non-null
	# here so check_vow_discovery can read is_dead from ectx.actors; nulled right after.
	_vow_consequence_service().check_vow_discovery(t)
	# V2-STAGE-004 Phase 4 (S12): ally is spent for one battle only — clear before nulling ctx.
	_recruitment_consequence_service().clear_ally_fields_if_present(t)

	# ── V2-INFRA-003 Phase 8: THE STAGE SETTLEMENT (defects D36 / D77 / D05) ────────────────
	# Base objective weights + realm-virtue bonus + stage-clear Storyweight, paid ONCE per
	# stage, behind the stage's `settlement_receipt` stamp. This used to fire inside
	# `FlowEncounterState.build_final_snapshot()`, once per ENCOUNTER, in a dispatch that never
	# advanced the stage — so a multi-situation stage paid several full stage rewards (D77) and
	# quitting at the Resolve screen banked the money with the stage still "current" (D36).
	# Here it is one dispatch with `RealmService.advance_stage()` below and one save flush, so
	# there is no window to quit inside, and it pays on the no-encounter path too (D05).
	#
	# PLACED HERE, not earlier: it must run while `encounter_ctx` is still non-null (the
	# Storyweight virtue multiplier reads each echo's action log off it) and after
	# `check_vow_discovery`/`clear_ally_fields_if_present`, so not one existing call changed
	# order. It is still ahead of `advance_stage`, which is the ordering the fix requires.
	#
	# `stage_cleared` is true on a combat victory and on the no-encounter path. A defeat pays
	# nothing and stamps nothing — and cannot reach here anyway, because the defeat Resolve
	# screen offers no `flow.complete_stage` action.
	var _stage_cleared := is_combat_victory or not has_encounter
	StageSettlementService.new(flow_ctx, config_service, econ, logger).settle(_stage_cleared, t)

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

	# V2-WEAVE-001: contribute segment — grade from the final encounter snapshot.
	#
	# V2-INFRA-003 Phase 8 — the second half of KNOWN DEFECT 1 (D05). With no encounter there is
	# no resolve snapshot, so `data.rank` is absent and this fell through to the default "F",
	# which `data.threads.segment_quality_by_grade` maps to `"broken"`. A stage the party
	# COMPLETED contributed a broken Thread segment.
	#
	# A stage cleared without a fight now contributes NO_COMBAT_GRADE = "C" → "compromised": it
	# counts, because the party completed the content, but it earns none of the clean tier that
	# only "S"/"A" give, because no fight was graded. This is the one value in this slice that is
	# a judgement rather than a repair; it is recorded against D05 in the defect register, where
	# D05's open question ("what grade should a no-encounter stage carry?") is answered.
	if not _thread_cfg.is_empty() and not flow_ctx.realm_id.is_empty():
		var _combat_grade := NO_COMBAT_GRADE
		if has_encounter:
			var _snap_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
			var _snap_data: Dictionary = _snap_data_v if _snap_data_v is Dictionary else {}
			_combat_grade = str(_snap_data.get("rank", "F"))
		RealmService.contribute_segment(flow_ctx, _combat_grade, _thread_cfg, t)

	var result := RealmService.advance_stage(flow_ctx, t)  # sets save_request + logs internally
	if result.get("is_completed", false):
		# V2-INFRA-003 Phase 8C: finishing the prologue Realm is what opens the normal Realms.
		# Stamped BEFORE realm_id is cleared below, and idempotent ("active" -> "complete" only).
		if RealmService.is_prologue_run(flow_ctx.realm_id):
			OpeningRealmService.mark_complete(flow_ctx.save_data, logger, t)
			flow_ctx.request_save("onboarding.opening_realm.complete")
		# V2-WEAVE-001: crystallize Threads before clearing realm context
		flow_ctx.last_realm_threads_earned = []
		if not _thread_cfg.is_empty():
			var _completed_realm_id := flow_ctx.realm_id  # capture BEFORE clearing
			flow_ctx.last_realm_threads_earned = ThreadService.crystallize_threads(
				_completed_realm_id, flow_ctx.save_data, _thread_cfg, t, flow_ctx.logger
			)
			flow_ctx.request_save("thread.crystallize")

		# Clear stale context so re-entry into a new realm starts clean
		flow_ctx.realm_id = ""
		flow_ctx.stage_id = ""
		return FlowActionOutcome.transition_outcome(FlowStateIds.REALM_SELECT, "realm.complete")

	var dest: String = destination_override if destination_override != "" else FlowStateIds.STAGE_MAP
	# V2-SANCTUM-001: victory — apply emotion modifiers + vow release when routing back to Sanctum
	if dest == FlowStateIds.SANCTUM:
		_emotion_consequence_service().apply_run_emotion_modifiers("victory", t)
		_vow_consequence_service().check_vow_release_condition(t)
	return FlowActionOutcome.transition_outcome(dest, "realm.stage_complete")
