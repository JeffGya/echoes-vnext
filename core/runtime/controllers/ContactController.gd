# res://core/runtime/controllers/ContactController.gd
# V2-INFRA-003 Phase 5 Slice C: the NPC-CONTACT CONVERSATION domain extracted out of
# FlowRuntime.gd, following the contract WeaveController/VowController/DebugController/
# ProgressionController/EconomySettlementController/SanctumController/OnboardingController set
# (see WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or refresh a snapshot itself. Every handler returns a
#     FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it via
#     _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — saves go through
#     flow_ctx.request_save(reason).
#   - No UI or scene-tree reference.
#
# Owns 3 actions: stage.consult_echoes, stage.speak_response, stage.disengage_contact.
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd: _handle_stage_consult_echoes,
# _handle_stage_speak_response, _handle_stage_disengage_contact, _apply_contact_outcome,
# _derive_contact_reaction_word, plus the two helpers _apply_contact_outcome cannot reach
# without them (see CORRECTION below): _build_contact_resolve_snapshot and _contact_outcome_text.
#
# ---------------------------------------------------------------------------
# STEP 0 — what could NOT move, and why
# ---------------------------------------------------------------------------
#
# _start_contact_conversation STAYS ON FlowRuntime. Two independent blockers:
#   1) OWNERSHIP. Its only caller is FlowRuntime._handle_stage_engage_situation — the handler
#      for stage.engage_situation, an action this controller does NOT own. Moving it would
#      force FlowRuntime to call a controller method as a bare mid-handler subroutine, which
#      is the exact pattern SanctumController.gd's header rejected for _repair_echo_schema:
#      "a controller's methods are meant to be reached via the dispatch()/FlowActionOutcome
#      contract, not called as a bare mid-handler subroutine."
#   2) flow_machine. It ends with flow_ctx.last_snapshot = ... + flow_machine.refresh_snapshot(),
#      and its caller then `return`s without applying any outcome. There is no FlowActionOutcome
#      in flight on that path to carry the intent, so the refresh cannot be translated. That is
#      the same blocker that kept _apply_victory_return_to_explore on FlowRuntime in Slice B.
#   It is NOT a stub: it does real, un-extracted work for a non-contact action. Its natural
#   future home is alongside this controller once stage.engage_situation itself is extracted
#   and can carry an outcome; it cannot become a service either, because services take no
#   flow_machine.
#
# SLICE 5D DISPROVED BOTH BLOCKERS — this note is kept as written above, because the claim it
# makes is exactly the kind that misleads a later reader, and deleting it would hide that the
# reasoning was wrong rather than merely superseded. What actually happened:
#
#   _start_contact_conversation is NO LONGER ON FlowRuntime. It moved wholesale to
#   core/realms/ContactConversationService.gd::start_conversation() — a SERVICE. That file's
#   header carries the full reasoning; VentureController.gd's "STEP 0b — THE CONTACT SEAM"
#   section records the seam from the caller's side.
#
#   Blocker 1 (ownership) was answered, not defeated: stage.engage_situation itself was
#   extracted in Slice 5D to VentureController.handle_engage_situation(). The route from that
#   handler into the conversation setup goes through a service precisely because a controller
#   may not call another controller — which is the rule this note cited, applied correctly.
#
#   Blocker 2 (flow_machine) was simply wrong, and the general rule stated with it —
#   "it cannot become a service either, because services take no flow_machine" — is wrong as a
#   general rule and must not be quoted. Holding no flow_machine does not make a body
#   unmovable; it makes the body's flow_machine WORK the caller's responsibility. The only
#   flow_machine use on this path was the trailing pair
#       flow_ctx.last_snapshot = StageExploreSnapshotBuilder.build(flow_ctx, t)
#       flow_machine.refresh_snapshot(flow_ctx, logger, t)
#   which handle_engage_situation() now returns as
#   FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t)) — the
#   exact assign-then-refresh _apply_action_outcome() performs. The service publishes nothing.
#   The correct test is not "does the body touch flow_machine" but "can the flow_machine work
#   be expressed as an outcome the caller applies". Here it could.
#
#   What survives from the note above: the _repair_echo_schema precedent (a controller's
#   methods are reached through dispatch()/FlowActionOutcome, not as bare mid-handler
#   subroutines) is still correct, and it is the reason the destination is a service rather
#   than a method on this controller.
#
# CORRECTION to the slice brief: _contact_outcome_text and _build_contact_resolve_snapshot did
# NOT migrate to ResolveSnapshotBuilder in Slice B. Slice B rewrote the BODY of
# _build_contact_resolve_snapshot to COMPOSE its payload through ResolveSnapshotBuilder's
# add_* blocks, but both functions remained FlowRuntime methods. _apply_contact_outcome calls
# _build_contact_resolve_snapshot twice; _build_contact_resolve_snapshot calls
# _contact_outcome_text once and nothing else calls either. With _apply_contact_outcome moving
# here, leaving them behind would mean the controller reaches back into FlowRuntime (forbidden)
# or duplicates them (forbidden, AGENTS.md mistake 19). They are pure contact-domain and
# single-caller, so they move with it. tests/VentureCharacterizationTests.gd repoints.
#
# ---------------------------------------------------------------------------
# TRANSLATIONS APPLIED (the only edits to the moved bodies)
# ---------------------------------------------------------------------------
#
# 1) `flow_ctx.last_snapshot = StageExploreSnapshotBuilder.build(flow_ctx, t)` followed by
#    `flow_machine.refresh_snapshot(...)` — the tail of all three handlers — becomes
#    `return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))`.
#    _apply_action_outcome()'s has_replacement_snapshot branch performs the assign then the
#    refresh, matching the pre-extraction pair exactly.
#
# 2) `flow_ctx.last_snapshot = _build_contact_resolve_snapshot(...)` followed by
#    `flow_machine.transition(RESOLVE, ...)` — the two contact-resolve exits of
#    apply_contact_outcome — becomes _resolve_transition_outcome() below, which returns
#    snapshot_outcome_no_refresh() plus transition_to. suppress_refresh is REQUIRED here and
#    is not a stylistic choice: pre-extraction these two paths assigned last_snapshot and
#    transitioned WITHOUT any refresh_snapshot() call. Using plain snapshot_outcome() would
#    inject an extra refresh between the assign and the transition that never ran before.
#
# 3) `flow_machine.transition(ENCOUNTER, ...)` + bare `return` — the hostile-claimant forced
#    combat exit — becomes FlowActionOutcome.transition_outcome(ENCOUNTER, ...). No snapshot
#    was assigned on that path pre-extraction, and none is now.
#
# 4) Every bare `return` guard becomes `return FlowActionOutcome.handled_outcome()` — handled,
#    no snapshot, no transition, no save. Matches the pre-extraction void return.
#
# 5) `_mark_save_requested(reason)` becomes `flow_ctx.request_save(reason)` — the same single
#    implementation _mark_save_requested itself delegates to. Deliberately NOT translated to
#    FlowActionOutcome.with_save_reason(): apply_contact_outcome interleaves save requests with
#    control flow and then transitions, and _apply_action_outcome() applies save_reasons AFTER
#    the transition. FlowContext.request_save() appends to a "|"-joined save_request_reason
#    string that FlowRuntime logs at its save choke point, so deferring the request past a
#    transition whose enter() may itself request a save would reorder that string. Calling
#    flow_ctx.request_save() at the original point keeps it byte-identical, and the hard rule
#    is "saves through flow_ctx.request_save(reason)" — which this is.
#
# 6) FlowRuntime's preload consts FlowStageExploreStateScript / ConversationServiceScript are
#    referenced here by their global class_name (FlowStageExploreState / ConversationService) —
#    the same classes, not lookalike APIs. `_load_contact_responses()` becomes
#    `ContactResponseService.load_responses()` (see core/realms/ContactResponseService.gd for
#    why that loader became a shared service rather than a method here).
#
# ---------------------------------------------------------------------------
# DETERMINISM
# ---------------------------------------------------------------------------
# No RNG is drawn anywhere in this file. But ConversationService derives conversation variation
# from (t + str(echo_id).hash()) % 997, where t is the simulation tick — so THE TICK SELECTS THE
# CONVERSATION TEXT. dispatch() computes one tick per action, so adding, removing or reordering
# a dispatch on any path that reaches a conversation changes what an NPC says. This slice adds,
# removes and reorders none. tests/ConversationRepairTests.gd guards it.
#
# ---------------------------------------------------------------------------
# KNOWN DEFECT (V2-INFRA-003 Phase 5 records; Phase 8 fixes):
# apply_contact_outcome() runs NONE of the six resolution steps that a combat result runs —
# ally teardown, emotion drift, bond triggers, sanctum emotion tick, vow discovery, vow release.
# That is why a contact result behaves differently from a combat result. The repair belongs to
# Phase 8, through EncounterResolutionService. It is deliberately NOT fixed here: a behaviour
# change inside an extraction makes any later failure impossible to trace to one cause.
# ---------------------------------------------------------------------------

class_name ContactController
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


# stage.consult_echoes — player selects up to 3 echoes to hear this turn.
# Generates responses for the selected echoes; stores in explore_map.contact_responses.
func handle_consult_echoes(action: Dictionary, t: int) -> FlowActionOutcome:
	var echo_ids_v: Variant = action.get("echo_ids", [])
	var echo_ids: Array = echo_ids_v if echo_ids_v is Array else []
	if echo_ids.is_empty():
		logger.debug(t, "stage.consult.invalid", "consult_echoes: no echo_ids provided", {})
		return FlowActionOutcome.handled_outcome()
	# Trim to max 3 — button auto-passes all party IDs; handler caps the consultation.
	if echo_ids.size() > 3:
		echo_ids = echo_ids.slice(0, 3)

	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty():
		return FlowActionOutcome.handled_outcome()
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var contact_v: Variant = explore_map.get("pending_contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	if contact.is_empty():
		return FlowActionOutcome.handled_outcome()

	# Load configs
	var bal_v: Variant = config_service.get_balance().get("data", {})
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var contact_cfg_v: Variant = bal.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}
	var response_data := ContactResponseService.load_responses()

	# Read active directive
	var dir_id := str(flow_ctx.save_data.get("flow", {}).get("active_directive", "directive.scout_carefully") \
		if flow_ctx.save_data.get("flow", null) is Dictionary else "directive.scout_carefully")

	# Build selected echo dicts
	var all_party := SanctumService.get_active_party_echoes(flow_ctx.save_data)
	var selected_echoes: Array = []
	for echo_v in all_party:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) in echo_ids:
			selected_echoes.append(echo)

	# Track ignored bids
	var bid_state := ConversationService.compute_bids(all_party, contact, dir_id, contact_cfg)
	var ignored_counts_v: Variant = contact.get("ignored_bid_counts", {})
	var ignored_counts: Dictionary = ignored_counts_v if ignored_counts_v is Dictionary else {}
	for eid in bid_state:
		if str(bid_state[eid]) != "" and eid not in echo_ids:
			ignored_counts[eid] = int(ignored_counts.get(eid, 0)) + 1
	contact["ignored_bid_counts"] = ignored_counts

	# Generate responses for selected echoes
	contact["consulted_ids_this_turn"] = echo_ids
	var contact_responses := ConversationService.generate_responses(
		selected_echoes, contact, contact_cfg, response_data, t, bid_state
	)

	explore_map["pending_contact"] = contact
	explore_map["contact_responses"] = contact_responses
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.consult_echoes")

	logger.info(t, "stage.consult_echoes", "Echo consultation choices made", {
		"stage_id":    flow_ctx.stage_id,
		"echo_ids":    echo_ids,
	})

	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))
# stage.speak_response — player picks which consulted echo speaks; advances conversation turn.
func handle_speak_response(action: Dictionary, t: int) -> FlowActionOutcome:
	var speaking_id := str(action.get("echo_id", ""))
	if speaking_id.is_empty():
		return FlowActionOutcome.handled_outcome()

	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty():
		return FlowActionOutcome.handled_outcome()
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var contact_v: Variant = explore_map.get("pending_contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	if contact.is_empty():
		return FlowActionOutcome.handled_outcome()

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
		return FlowActionOutcome.handled_outcome()

	var turn_score := float(chosen_response.get("resonance_score", 0.5))

	# Load config
	var bal_v: Variant = config_service.get_balance().get("data", {})
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var contact_cfg_v: Variant = bal.get("contact", {})
	var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}

	# Apply NPC reaction
	var reaction := ConversationService.apply_npc_reaction(contact, turn_score, contact_cfg)
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
	var all_party := SanctumService.get_active_party_echoes(flow_ctx.save_data)
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

	var social_effects := ConversationService.get_social_effects(
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
	# Reset every turn so a losing turn doesn't leave a stale gain/name on the contact
	# from a prior winning turn (this drives the player-facing confirmation — see below).
	contact["last_turn_storyweight_gain"] = 0
	contact["last_turn_speaker_name"] = ""
	if turn_score >= sw_threshold:
		for echo_v in roster:
			if not (echo_v is Dictionary):
				continue
			var echo: Dictionary = echo_v
			if str(echo.get("id", "")) == speaking_id:
				var sw_gain_cfg := float(contact_cfg.get("storyweight_speak_partial_step", 0))
				var sw_gain := int(round(sw_gain_cfg))
				if sw_gain_cfg > 0.0 and sw_gain == 0:
					logger.warn(t, "conversation.storyweight_gain.rounded_to_zero",
						"storyweight_speak_partial_step is configured non-zero but rounds to 0 storyweight; no gain applied",
						{ "configured_value": sw_gain_cfg, "speaking_id": speaking_id })
				if sw_gain > 0:
					var xp_before := int(echo.get("xp_total", 0))
					var story_before := int(echo.get("storyweight", xp_before))
					var xp_after := xp_before + sw_gain
					var story_after := story_before + sw_gain
					echo["xp_total"] = xp_after
					echo["storyweight"] = story_after
					contact["last_turn_storyweight_gain"] = sw_gain
					contact["last_turn_speaker_name"] = str(echo.get("name", ""))
					logger.info(t, "conversation.storyweight_gain.awarded",
						"Conversation turn won; speaker gained Storyweight", {
							"stage_id":    flow_ctx.stage_id,
							"echo_id":     speaking_id,
							"echo_name":   str(echo.get("name", "")),
							"turn_score":  turn_score,
							"threshold":   sw_threshold,
							"threshold_cleared": true,
							"gain":        sw_gain,
							"storyweight": story_after,
							"xp_total":    xp_after,
						})
				break

	# S14a: conversation-quality accumulator — read by S14 recruit formula's conversation
	# component. Lives on the contact dict alongside the existing turn tracking (turn_current
	# / consulted_ids_this_turn below); survives into explore_map["ally_contact"] via the
	# contact.duplicate(true) in _apply_contact_outcome() when a temporary_ally is recruited.
	# Additive-only bookkeeping — zero effect on reaction/outcome/storyweight resolution above.
	contact["conv_score_sum"] = float(contact.get("conv_score_sum", 0.0)) + turn_score
	if turn_score >= sw_threshold:
		contact["winning_turns"] = int(contact.get("winning_turns", 0)) + 1

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
			outcome = ConversationService.resolve_outcome(contact, contact_cfg)
		contact["outcome"] = outcome
		contact["state"]   = "concluded" if outcome != "failed" else "failed"

		return apply_contact_outcome(contact, stage, explore_map, t)

	# Conversation continues — derive NPC follow-up line, then save and rebuild
	var _next_party := SanctumService.get_active_party_echoes(flow_ctx.save_data)
	var _next_responses: Array = []
	var _next_resp_data := ContactResponseService.load_responses()

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
		var _next_bids := ConversationService.compute_bids(_next_party, contact, _next_dir_id, contact_cfg)
		_next_responses = ConversationService.generate_responses(
			_next_party, contact, contact_cfg, _next_resp_data, t, _next_bids
		)
	explore_map["contact_responses"] = _next_responses
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.speak_response")

	logger.info(t, "stage.speak_response", "Echo spoke; conversation continues", {
		"stage_id":     flow_ctx.stage_id,
		"echo_id":      speaking_id,
		"turn_score":   turn_score,
		"turn_current": turn_current,
		"turn_count":   turn_count,
		"npc_fear":     contact.get("fear",   0),
		"npc_morale":   contact.get("morale", 0),
	})

	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))


# stage.disengage_contact — player exits mid-conversation. No outcome; stage continues.
func handle_disengage_contact(_action: Dictionary, t: int) -> FlowActionOutcome:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)
	if stage.is_empty():
		return FlowActionOutcome.handled_outcome()
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
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.disengage_contact")

	logger.info(t, log_reason, "Player disengaged from NPC conversation", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})

	return FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t))
# Apply conversation outcome by role: intel clues, map reveals, objective, emotion, continuity, fear bleed.
# KNOWN DEFECT (V2-INFRA-003 Phase 5 records; Phase 8 fixes): this function runs NONE of the
# six resolution steps a combat result runs — ally teardown, emotion drift, bond triggers,
# sanctum emotion tick, vow discovery, vow release. That is why a contact result behaves
# differently from a combat result. Phase 8 owns the repair, through EncounterResolutionService.
# Recorded, not fixed: a behaviour change inside an extraction makes a later failure impossible
# to trace to one cause.
func apply_contact_outcome(
	contact: Dictionary, stage: Dictionary, explore_map: Dictionary, t: int
) -> FlowActionOutcome:
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
					_stage_explore_session_service().mark_stage_objective_completed(obj_index, t)
				# Party morale boost
				_emotion_consequence_service().apply_morale_to_party(+8, "contact.charge.good", t)
			elif outcome == "partial":
				_emotion_consequence_service().apply_morale_to_party(+4, "contact.charge.partial", t)
			elif outcome == "failed" and is_objective:
				# Automatic stage failure for objective-linked Charge
				contact["state"] = "failed"
				explore_map["pending_contact"] = {}
				explore_map["contact_responses"] = []
				var fail_count := int(explore_map.get("contact_fail_count", 0)) + 1
				explore_map["contact_fail_count"] = fail_count
				explore_map["situations"] = map_situations
				stage["explore_map"] = explore_map
				FlowStageExploreState._write_stage_back(flow_ctx, stage)
				flow_ctx.request_save("stage.charge.fail")

				logger.info(t, "stage.charge.fail", "Objective Charge failed — stage abandoned", {
					"stage_id":       flow_ctx.stage_id,
					"situation_id":   sit_id,
					"contact_fail_count": fail_count,
				})

				return _resolve_transition_outcome(
					_build_contact_resolve_snapshot(contact, "failed", false, t),
					"stage_abandoned_charge_fled")
			elif outcome == "failed" and not is_objective:
				# V2-STAGE-004 Phase 4 (S13): a failed non-objective Charge doesn't abandon the
				# stage — it raises pressure instead. Consumed exactly once by the stage's next
				# PROTECT/ENDURE objective combat (EncounterSetupService.setup, charge-pressure block),
				# then cleared. Resolution still proceeds to the normal Resolve screen below.
				explore_map["hostile_charge_sit_id"] = sit_id

		"claimant":
			if outcome == "good":
				# Small Ase reward
				var _ase_reward := 20
				econ.add_ase(_ase_reward, "contact.claimant.good", logger, t)
				_emotion_consequence_service().apply_morale_to_party(+5, "contact.claimant.good", t)
			elif outcome == "partial":
				_emotion_consequence_service().apply_morale_to_party(+3, "contact.claimant.partial", t)
			elif outcome == "failed":
				contact["state"] = "failed"
				# Hostile slot (V2-STAGE-004 will wire actual combat) — surfaced via contact_result
				logger.info(t, "stage.claimant.hostile", "Claimant turned hostile", {
					"stage_id": flow_ctx.stage_id,
					"situation_id": sit_id,
				})

				# V2-STAGE-004 Phase 4 (S13): a hostile Claimant forces immediate combat — mirrors
				# the async situation → ENCOUNTER routing in _handle_stage_engage_situation (index
				# forced to -1 so _resolve_mode_from_stage() resolves plain COMBAT). Mark the
				# situation resolved first so it can't be re-prompted from Explore; combat victory
				# returns to Explore via the existing generic complete_stage path.
				if sit_ref_idx >= 0:
					sit_ref["resolved"] = true
					sit_ref["revealed"] = true
					map_situations[sit_ref_idx] = sit_ref
				explore_map["situations"]        = map_situations
				explore_map["pending_contact"]   = {}
				explore_map["contact_responses"] = []
				# V2-STAGE-004 S15 prep: durable marker so FlowEncounterState can project a
				# combat_intro_line context beat. Cleared at encounter teardown alongside
				# ally fields (see RecruitmentConsequenceService.clear_ally_fields_if_present).
				explore_map["combat_intro_reason"] = "claimant_hostile"
				stage["explore_map"] = explore_map
				FlowStageExploreState._write_stage_back(flow_ctx, stage)
				flow_ctx.request_save("stage.claimant.combat_forced")

				flow_ctx.active_encounter_objective_index = -1

				logger.info(t, "stage.claimant.combat_forced", "Hostile Claimant forces combat", {
					"stage_id":     flow_ctx.stage_id,
					"situation_id": sit_id,
				})

				return FlowActionOutcome.transition_outcome(FlowStateIds.ENCOUNTER, "stage.claimant.combat_forced")

		"temporary_ally":
			if outcome == "good":
				contact["allied"] = true
				# Continuity gain
				var cont_pts := int(contact_cfg.get("continuity_temporary_ally_good", 5))
				ContinuityService.add_points(flow_ctx.save_data, cont_pts, "contact.ally.good", logger, t)
				# V2-STAGE-004 Phase 4 (S12): persist the ally durably on explore_map so
				# EncounterSetupService.setup() can auto-join it into the NEXT encounter fought
				# in this stage (one battle only — ally_consumed_in_encounter gates repeat
				# injection; both cleared at encounter teardown).
				explore_map["ally_contact"]    = contact.duplicate(true)
				explore_map["ally_contact_id"] = sit_id
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
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.contact.resolved")

	logger.info(t, "stage.contact.resolved", "NPC conversation resolved", {
		"stage_id":   flow_ctx.stage_id,
		"role":       role,
		"outcome":    outcome,
		"sit_id":     sit_id,
	})

	return _resolve_transition_outcome(
		_build_contact_resolve_snapshot(contact, outcome, true, t),
		"stage.contact.resolve_screen")


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
	var resp_data := ContactResponseService.load_responses()
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

	# V2-INFRA-003 Phase 5 Slice B: producer D, composed through ResolveSnapshotBuilder.
	# Same eight keys as before. `verdict` is written and never read — the contact renderer
	# sets _rank_badge.visible = false unconditionally — but it is reproduced verbatim here.
	# KNOWN DEFECT (V2-INFRA-003 Phase 5 records; a later story fixes): D emits `verdict`
	# into a badge ResolveScreen hides on this branch.
	var _actions: Dictionary = {
		"cta.continue": {
			"type":  "flow.go_state",
			"to":    continue_to,
			"label": continue_label,
			"slot":  "cta.continue",
		},
	}
	var _snap: Dictionary = ResolveSnapshotBuilder.build(t, _actions, "contact_result")
	var _data: Dictionary = _snap["data"]
	ResolveSnapshotBuilder.add_contact_outcome(_data, role, role_label, outcome, outcome_text)
	# P1 CLOSE: additive fields for unified Resolve component.
	ResolveSnapshotBuilder.add_banner(_data, "npc_contact", outcome_text)
	ResolveSnapshotBuilder.add_grade_verdict(_data, _contact_verdict)
	return _snap
# Maps a turn_score to a reaction word that keys into npc_followup in contact_responses.json.
func _derive_contact_reaction_word(turn_score: float) -> String:
	if turn_score > 0.8:  return "Opening"
	if turn_score >= 0.5: return "Steadied"
	if turn_score >= 0.3: return "Uncertain"
	return "Withdrawn"


## Builds the "assign this resolve snapshot, then transition to RESOLVE, and do NOT refresh in
## between" outcome shape used by apply_contact_outcome()'s two contact-resolve exits. See
## translation 2 in the file header for why suppress_refresh is required rather than optional.
func _resolve_transition_outcome(snapshot: Dictionary, reason: String) -> FlowActionOutcome:
	var outcome := FlowActionOutcome.snapshot_outcome_no_refresh(snapshot)
	outcome.transition_to = FlowStateIds.RESOLVE
	outcome.transition_reason = reason
	return outcome


## Builds a fresh EmotionConsequenceService scoped to the current flow_ctx/config_service/
## logger. Constructed per-call, same rationale as FlowRuntime._weave_controller(): cheap
## RefCounted, always correct even if a caller replaces flow_ctx after construction. A
## controller may not reach back into FlowRuntime for its factory, so this mirrors
## SanctumController._economy_settlement_service().
func _emotion_consequence_service() -> EmotionConsequenceService:
	return EmotionConsequenceService.new(flow_ctx, config_service, logger)


## Builds a fresh ActiveStageService — same per-call construction rationale as
## _emotion_consequence_service() above. Used only by apply_contact_outcome()'s
## charge/good branch (mark_stage_objective_completed).
func _stage_explore_session_service() -> ActiveStageService:
	return ActiveStageService.new(flow_ctx, config_service, logger)
