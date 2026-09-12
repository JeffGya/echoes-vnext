# res://core/progression/SkillLoadoutService.gd
# V2-INFRA-003 Phase 6 Slice 6F: persist_equipped_skills DEMOTED out of
# core/runtime/controllers/ProgressionController.gd, verbatim, so that a SECOND controller may
# call it. Follows the contract every extracted service shares (see
# core/combat/CombatRoundObjectiveService.gd for the fullest writeup):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference. This class does not (and structurally cannot) transition
#     state or rebuild a snapshot.
#   - Never calls SaveService directly, and never calls a controller. Save intent goes through
#     flow_ctx.request_save(reason), the RULES-mandated choke point — the same call the
#     pre-demotion controller method made, at the same point in the same body.
#   - No UI or scene-tree reference.
#
# ---------------------------------------------------------------------------
# WHY IT MOVED — revisiting Slice 6b's deliberate decision, not overruling it
# ---------------------------------------------------------------------------
#
# ProgressionController's Slice 6b header placed this function on the controller and recorded
# why: "NOT a dispatched-action handler — called as a preparatory step from FlowRuntime's
# flow.select_stage case (which stays on FlowRuntime)." That was correct WHEN IT WAS WRITTEN,
# and the reason it is no longer correct is a change in the world, not a change of opinion:
#
#   1. At Slice 6b there was no VentureController. flow.select_stage was an inline case in
#      FlowRuntime.dispatch(), and FlowRuntime may call any controller it likes. "A preparatory
#      step reached from FlowRuntime" was therefore a legal, stable arrangement. The
#      parenthetical "(which stays on FlowRuntime)" recorded the then-current FACT about
#      flow.select_stage's owner — it was not asserting a principle about this function.
#
#   2. Slice D built VentureController and moved the other ten venture actions onto it. Its
#      STEP 0a note found flow.select_stage blocked by exactly this call, named this exact fix
#      ("demote persist_equipped_skills to a service both controllers may call"), and declined
#      it only on scope ("that is a second extraction ... not in this slice's scope. Recorded,
#      not forced."). So Slice 6b's arrangement was already superseded in intent by its own
#      successor slice; this file is the scheduled second extraction, not a reversal.
#
#   3. The move has precedent, twice, in this same refactor. EconomySettlementService (Slice 7)
#      demoted a cross-domain preparatory step so ProgressionController.handle_unlock_skill
#      could reach it; ContactConversationService (Slice D) did the same so VentureController
#      could reach the contact route without calling ContactController. Both are this shape: a
#      preparatory step needed by a second controller becomes a service.
#
#   4. Nothing about the function itself argues for controller residency. It holds no
#      flow_machine, returns void, produces no FlowActionOutcome, and is not routed by
#      dispatch(). Those are a service's properties, not a controller's. Living on a controller
#      granted it nothing and cost it one caller.
#
# ---------------------------------------------------------------------------
# WHERE IT LANDED — core/progression/, beside the skill domain it writes
# ---------------------------------------------------------------------------
#
# AGENTS.md: "Reads save data for a domain → a static function on that domain's service" and
# "Wraps a domain class → a service placed beside that class". The domain is skills: it writes
# echo["equipped_skills"], the field SkillDefinition.gd (same folder) reads for slot counts, and
# the same field skill.assign / skill.unassign stage into flow_ctx.pending_equipped_skills.
#
# It is NOT a static on ProgressionService, though that file is the static home of the XP rules
# and received get_realm_xp_multiplier in this same slice. ProgressionService's entire API takes
# plain dicts and knows nothing of FlowContext (grep-verified: the identifier appears only in a
# doc comment naming where a caller's save_data comes from). This function needs
# flow_ctx.pending_equipped_skills — a FlowContext field with no save-data equivalent — and
# flow_ctx.request_save(). Threading a FlowContext through ProgressionService would break that
# file's own shape, the same objection AGENTS.md records against giving EmotionService or
# MaturityExpressionService a ConfigService. A small RefCounted service that holds flow_ctx is
# the shape EconomySettlementService and ContactConversationService already established.
#
# CONSTRUCTOR — (flow_ctx, logger), deliberately not the (flow_ctx, config_service, logger)
# shape most siblings use. The body reads no config. An unused config_service field would be a
# speculative dependency, which AGENTS.md forbids ("No speculative abstractions").
#
# ---------------------------------------------------------------------------
# WHAT IT TOUCHES — the complete read/write set
# ---------------------------------------------------------------------------
#   READS   flow_ctx.pending_equipped_skills   the staged loadout, keyed by echo_id then slot
#           flow_ctx.save_data["sanctum"]["roster"]
#   WRITES  roster[i]["equipped_skills"]       a duplicate() of the staged per-echo dict
#           flow_ctx.save_request / .save_request_reason, via request_save("skill.persist")
#
# SAVE-REASON ORDERING — load-bearing, and preserved. FlowContext.request_save() joins reasons
# with "|", so WHEN the reason is queued relative to the rest of the dispatch decides the
# resulting string. Pre-demotion, flow.select_stage queued "skill.persist" BEFORE
# flow_machine.transition(STAGE, ...). VentureController.handle_select_stage therefore calls
# this service inline, mid-handler, rather than returning
# FlowActionOutcome...with_save_reason("skill.persist") — _apply_action_outcome() drains
# save_reasons AFTER it applies the transition, which would flip the order of this reason
# against any reason the STAGE transition queues for itself. The call stays inside the dispatch
# boundary either way, so no reason is stranded onto the next dispatch's string.

class_name SkillLoadoutService
extends RefCounted

var flow_ctx: FlowContext
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	logger = _logger


## PROG-009: Persists flow_ctx.pending_equipped_skills onto each matching roster echo and flags
## a save. Body moved verbatim from ProgressionController.persist_equipped_skills — no behaviour
## change: same early return on an empty staging dict, same roster lookup by string id, same
## duplicate() on write, same save reason, same log line at the same point.
func persist_equipped_skills(t: int) -> void:
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

	flow_ctx.request_save("skill.persist")

	logger.info(t, "skill.persist", "Equipped skills persisted to save", {
		"equipped_count": flow_ctx.pending_equipped_skills.size()
	})
