# res://core/realms/ContactConversationService.gd
# V2-INFRA-003 Phase 5 Slice D: the NPC conversation SETUP step, extracted out of
# FlowRuntime._start_contact_conversation().
#
# WHY THIS IS A SERVICE AND NOT PART OF ContactController.
# Its one caller is the stage.engage_situation handler, which this slice moved onto
# VentureController. Controllers must never call one another (AGENTS.md, "Controllers vs
# services"), so the contact route out of engage_situation has to pass through a service.
#
# CORRECTION to core/runtime/controllers/ContactController.gd's STEP 0 note. Slice C recorded
# two blockers that kept _start_contact_conversation on FlowRuntime, and concluded "it cannot
# become a service either, because services take no flow_machine". Both blockers are resolved
# by this slice, and the second conclusion was wrong:
#   1) OWNERSHIP — stage.engage_situation is now an owned, extracted action, so the call is a
#      normal service call from its owning controller rather than FlowRuntime reaching into a
#      controller mid-handler.
#   2) flow_machine — the function ended with
#        flow_ctx.last_snapshot = StageExploreSnapshotBuilder.build(flow_ctx, t)
#        flow_machine.refresh_snapshot(flow_ctx, logger, t)
#      and its caller then returned void, so there was no FlowActionOutcome in flight to carry
#      the intent. There is one now: VentureController.handle_engage_situation() returns
#      FlowActionOutcome.snapshot_outcome(StageExploreSnapshotBuilder.build(flow_ctx, t)) on the
#      contact branch, which _apply_action_outcome() turns back into exactly that assign-then-
#      refresh pair. The publish therefore stays OUT of this service — which is why the service
#      needs no flow_machine and the Slice C objection no longer applies.
#
# CONTRACT (same as every other service in this refactor):
#   - Typed RefCounted, explicit typed constructor dependencies, no autoloads.
#   - No flow_machine. Never calls FlowRuntime, a controller, or SaveService. Saves go through
#     flow_ctx.request_save(reason).
#   - No UI or scene-tree reference.
#
# LOCATION. core/realms/, beside the two classes it composes — ConversationService.gd (bids +
# response generation) and ContactResponseService.gd (the contact_responses.json loader Slice C
# placed here for the same reason) — and beside SituationModel/StageExploreModel, the domain
# classes whose dicts it mutates.
#
# DETERMINISM. No RNG. But ConversationService.generate_responses() derives its text from
# (t + str(echo_id).hash()) % 997, so the simulation tick SELECTS THE CONVERSATION TEXT.
# dispatch() computes one tick per action; this slice adds, removes and reorders no dispatch,
# and start_conversation() is still called at the same point on the same tick as before.
# tests/ConversationRepairTests.gd guards it.

class_name ContactConversationService
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# V2-STAGE-003: NPC conversation setup. Called when sit_type == TYPE_NPC and the situation's
# contact dict is non-empty. Moved verbatim from FlowRuntime._start_contact_conversation()
# except for the two trailing snapshot-publication lines, which the caller now expresses as a
# FlowActionOutcome (see the header).
func start_conversation(sit: Dictionary, sit_id: String, explore_map: Dictionary, stage: Dictionary, t: int) -> void:
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
	var response_data := ContactResponseService.load_responses()

	# Load contact config
	var contact_cfg_bal_v: Variant = _sit_bal.get("contact", {})
	var contact_cfg_bal: Dictionary = contact_cfg_bal_v if contact_cfg_bal_v is Dictionary else {}

	# Read active directive
	var _dir_id := str(flow_ctx.save_data.get("flow", {}).get("active_directive", "directive.scout_carefully") \
		if flow_ctx.save_data.get("flow", null) is Dictionary else "directive.scout_carefully")

	# Build party echoes (active party only)
	var _party_echoes := SanctumService.get_active_party_echoes(flow_ctx.save_data)

	# Compute initial bids
	var bid_state := ConversationService.compute_bids(
		_party_echoes, contact_work, _dir_id, contact_cfg_bal
	)

	# Set NPC opening line from burden_variant (authored in contact_responses.json), when available.
	# NOTE: contact_responses.json is keyed by calling, not by contact role, and no entry
	# currently defines a "burden_variants" map — this content has never been authored (see
	# RealmGenerator._BURDEN_VARIANTS_BY_ROLE / npc_opening_lines.json for the real opening-line
	# source). Guard the overwrite so an unauthored/empty lookup never blanks the populated
	# npc_line that RealmGenerator already selected.
	var _bv := str(contact_work.get("burden_variant", ""))
	var _bv_role_data_v: Variant = response_data.get(str(contact_work.get("role", "")), {})
	var _bv_role_data: Dictionary = _bv_role_data_v if _bv_role_data_v is Dictionary else {}
	var _bv_variants_v: Variant = _bv_role_data.get("burden_variants", {})
	var _bv_variants: Dictionary = _bv_variants_v if _bv_variants_v is Dictionary else {}
	var _bv_variant_v: Variant = _bv_variants.get(_bv, {})
	var _bv_variant: Dictionary = _bv_variant_v if _bv_variant_v is Dictionary else {}
	var _bv_opening := str(_bv_variant.get("opening", ""))
	if not _bv_opening.is_empty():
		contact_work["npc_line"] = _bv_opening

	# Auto-generate responses if party ≤ 3
	var contact_responses: Array = []
	if _party_echoes.size() <= 3:
		contact_responses = ConversationService.generate_responses(
			_party_echoes, contact_work, contact_cfg_bal, response_data, t, bid_state
		)

	explore_map["pending_contact"] = contact_work
	explore_map["contact_responses"] = contact_responses
	stage["explore_map"] = explore_map
	FlowStageExploreState._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.contact.start")

	logger.info(t, "stage.contact.start", "NPC conversation started", {
		"stage_id":    flow_ctx.stage_id,
		"situation_id": sit_id,
		"role":        str(contact_work.get("role", "")),
		"name":        str(contact_work.get("name", "")),
	})
