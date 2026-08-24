# res://core/runtime/controllers/VowController.gd
# V2-INFRA-003 Phase 4 Slice 2: second bounded domain controller extracted out of
# FlowRuntime.gd, following the pattern WeaveController set (see WeaveController.gd for the
# full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or rebuild a snapshot itself. Every handler returns a
#     FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it
#     via _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — VowService (the
#     pure vow-domain logic layer this controller delegates to) already requests saves via
#     flow_ctx.request_save() when given a real FlowContext as its ctx argument.
#   - No UI or scene-tree reference.
#
# Owns 3 actions: vow.pledge, vow.break, debug.vow.unlock. Moved verbatim (behaviour
# unchanged) from FlowRuntime.gd: _handle_vow_pledge, _handle_vow_break, _handle_debug_vow_unlock.
#
# THE SPLIT: the eleven vow methods that used to live on FlowRuntime split into two homes.
# This controller owns the three that respond to a dispatched vow.* action. The other eight
# — consequence hooks invoked from stage/encounter/return paths, never from a vow action —
# went to core/sanctum/VowConsequenceService.gd instead, because those hooks are called from
# several unrelated domains and a controller may not be called by another controller.
# handle_break() below calls VowConsequenceService.apply_vow_break_aftermath() after a
# successful break — that is a controller calling a *service*, which is allowed; only
# controller-to-controller calls are forbidden.
#
# core/sanctum/VowService.gd already exists and stays exactly as it is — it holds the vow
# DOMAIN rules (pledge/break/release/unlock). This controller is the action-dispatch seam on
# top of it, same relationship WeaveController has with WeavingRiteService.

class_name VowController
extends RefCounted

const FlowVowStateScript          := preload("res://core/state/flow/states/sanctum/FlowVowState.gd")
const VowConsequenceServiceScript := preload("res://core/sanctum/VowConsequenceService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## vow.pledge — pledges the requested vow_id at the requested tier. Denial (missing vow_id,
## locked tier, already-active vow, unknown definition) is handled inside VowService.pledge_vow
## via its own debug-log + false return; either way this handler rebuilds the VowScreen
## snapshot so the UI reflects the current (possibly unchanged) state.
func handle_pledge(action: Dictionary, t: int) -> FlowActionOutcome:
	var vow_id := str(action.get("vow_id", ""))
	var tier   := int(action.get("tier", 1))

	if vow_id.is_empty():
		logger.debug(t, "vow.pledge_denied", "Missing vow_id in action", { "action": action })
		return FlowActionOutcome.snapshot_outcome(FlowVowStateScript.build_snapshot(flow_ctx, t))

	var cfg := config_service.get_balance()
	VowService.pledge_vow(vow_id, tier, cfg, flow_ctx.save_data, flow_ctx, logger, t)
	# Rebuild snapshot from current save_data so UI reflects the pledge outcome (or denial).
	# refresh_snapshot() reads ctx.last_snapshot as-is for non-SANCTUM states — must supply
	# the rebuilt snapshot via the outcome (same pattern as FlowSummonState.build_snapshot).
	return FlowActionOutcome.snapshot_outcome(FlowVowStateScript.build_snapshot(flow_ctx, t))


## vow.break — breaks the active vow, if any, and applies its penalties + aftermath. No-op
## (no snapshot rebuild) when there is no active vow to break, matching the pre-extraction
## behaviour of refreshing the unchanged snapshot rather than rebuilding it.
func handle_break(t: int) -> FlowActionOutcome:
	var cfg := config_service.get_balance()

	var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
	if summary.is_empty():
		return FlowActionOutcome.handled_outcome()

	# Apply morale/fear deltas + EmotionRecovery modifier to all roster echoes. This is a
	# controller calling a service (allowed) — VowConsequenceService is shared with the
	# auto-break paths (stage-entry / engage condition) so the aftermath logic is not
	# duplicated between VowController and VowConsequenceService.
	_consequence_service().apply_vow_break_aftermath(summary, cfg, t)

	# Rebuild snapshot from current save_data so UI reflects the break outcome.
	return FlowActionOutcome.snapshot_outcome(FlowVowStateScript.build_snapshot(flow_ctx, t))


## debug.vow.unlock — dev-only forced unlock, reached via the F1 debug panel. No snapshot
## rebuild, matching the pre-extraction behaviour (VowScreen re-reads unlocked vows on its
## own next natural rebuild).
func handle_debug_unlock(action: Dictionary, t: int) -> FlowActionOutcome:
	var vow_id := str(action.get("vow_id", ""))
	if vow_id.is_empty():
		push_warning("debug.vow.unlock: missing vow_id")
		return FlowActionOutcome.handled_outcome()
	VowService.unlock_vow(vow_id, "debug", flow_ctx.save_data, flow_ctx, logger, t)
	return FlowActionOutcome.handled_outcome()


## Builds a fresh VowConsequenceService scoped to the current flow_ctx/config_service/econ/
## logger. Constructed per-call, same rationale as FlowRuntime._weave_controller(): cheap
## RefCounted, always correct even if a caller replaces flow_ctx after construction.
func _consequence_service() -> VowConsequenceService:
	return VowConsequenceServiceScript.new(flow_ctx, config_service, econ, logger)
