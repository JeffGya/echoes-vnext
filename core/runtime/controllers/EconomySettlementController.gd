# res://core/runtime/controllers/EconomySettlementController.gd
# V2-INFRA-003 Phase 4 Slice 7: fifth bounded domain controller extracted out of
# FlowRuntime.gd, following the pattern WeaveController/VowController/DebugController/
# ProgressionController set (see WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - No flow_machine reference — this controller does not (and structurally cannot)
#     transition state or rebuild a snapshot itself. Every handler returns a
#     FlowActionOutcome describing what should happen; FlowRuntime.dispatch() applies it
#     via _apply_action_outcome(), the single place that acts on a controller's intent.
#   - Never calls another controller. Never calls SaveService directly — EconomySettlementService
#     (which handle_settle_time delegates to) requests saves via flow_ctx.request_save(), the
#     RULES-mandated choke point.
#   - No UI or scene-tree reference.
#
# Owns the 3 economy.* dispatched actions: economy.settle_time, economy.ase.add,
# economy.ase.spend. Moved verbatim (behaviour unchanged) from FlowRuntime.gd's "---- Economy
# ----" dispatch block.
#
# WHAT DID NOT MOVE HERE: _handle_economy_settle_time's ~140-line body did not move onto this
# controller — it moved to core/economy/EconomySettlementService.gd (settle()), because it is
# also called inline from two places that are NOT the economy.settle_time action:
# FlowRuntime._handle_sanctum_summon (settle-before-spend) and
# FlowRuntime._handle_sanctum_unlock_skill (settle-before-afford-check). Those two handlers stay
# on FlowRuntime this slice (SanctumController extraction is explicitly out of scope — see this
# story's brief) but now call the service directly, the same as this controller does. A
# controller may not be called by another controller, and a private FlowRuntime method may not
# call a controller either (controllers take no flow_machine, but more importantly the point of
# this split is that *any* caller — controller or still-private FlowRuntime handler — can now
# reach the same settle logic without duplicating it. See EconomySettlementService.gd's header
# for the full three-settlements/three-clocks writeup.
#
# THE REFRESH-SNAPSHOT TRANSLATION: none of these three handlers build a new/rebuilt snapshot —
# pre-extraction they all ended with a bare `flow_machine.refresh_snapshot(flow_ctx, logger, t)`
# call (economy.ase.add and economy.ase.spend directly; economy.settle_time via the settle
# function's own unconditional call at its end, now removed — see EconomySettlementService.gd).
# Same translation DebugController.gd's header documents: each handler below returns
# `FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)` — assigning last_snapshot back to
# itself is a no-op, and _apply_action_outcome()'s has_replacement_snapshot branch then calls
# flow_machine.refresh_snapshot() on FlowRuntime's behalf, exactly matching the pre-extraction
# call.
#
# economy.ase.spend's pre-extraction body called _handle_economy_settle_time inline (with its
# own unconditional refresh) BEFORE spend_ase(), then refreshed AGAIN at the end — two refresh
# calls when now_unix > 0. handle_ase_spend below collapses this to the one final refresh the
# returned outcome triggers. This is safe: refresh_snapshot() only re-validates and re-stores
# the CURRENT ctx.last_snapshot (FlowStateMachine._rebuild_snapshot() — it does not call enter()
# or derive from a delta), nothing between the two original calls read flow_ctx.last_snapshot,
# and spend_ase() runs between them either way — so the end state after "settle, refresh,
# spend, refresh" and after "settle, spend, refresh" is identical. No functional behaviour
# (Ase balance, guards, logs from settle/spend themselves) changed; one redundant snapshot
# re-validation pass did.
#
# economy.ase.add does NOT call settle — pre-extraction it never did, and neither does
# handle_ase_add below. It also never requested a save pre-extraction; handle_ase_add doesn't
# either — preserved exactly, not "fixed" (unlike economy.settle_time's save-request, which WAS
# a deliberate approved fix made in an earlier phase and stays in EconomySettlementService.settle()).

class_name EconomySettlementController
extends RefCounted

const EconomySettlementServiceScript := preload("res://core/economy/EconomySettlementService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## economy.settle_time — the dispatched bank-timer settle action (Sanctum bank interval / debug
## commands). Delegates the actual settlement to EconomySettlementService.settle(), which
## already requests its own save; this handler's only remaining job is the refresh-snapshot
## translation described above.
func handle_settle_time(action: Dictionary, t: int) -> FlowActionOutcome:
	_settlement_service().settle(action, t)
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## economy.ase.add — direct Ase grant (debug / reward paths that don't go through settle).
## Moved verbatim from FlowRuntime's inline case body. No settle, no save request — matches
## pre-extraction behaviour exactly.
func handle_ase_add(action: Dictionary, t: int) -> FlowActionOutcome:
	var amount := int(action.get("amount", 0))
	var reason := str(action.get("reason", "economy.ase.add"))
	econ.add_ase(amount, reason, logger, t)
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## economy.ase.spend — settles accrued Ase first (when now_unix is supplied) so the spend reads
## an up-to-date balance, then spends. Moved verbatim from FlowRuntime's inline case body (see
## the refresh-collapse note above for the one behaviour-preserving simplification).
func handle_ase_spend(action: Dictionary, t: int) -> FlowActionOutcome:
	var now_unix := int(action.get("now_unix", 0))
	if now_unix > 0:
		_settlement_service().settle({
			"type": "economy.settle_time",
			"now_unix": now_unix,
			"source": "debug.before_spend"
		}, t)

	var amount := int(action.get("amount", 0))
	var reason := str(action.get("reason", "economy.ase.spend"))
	econ.spend_ase(amount, reason, logger, t)
	return FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot)


## Builds a fresh EconomySettlementService scoped to the current flow_ctx/config_service/econ/
## logger. Constructed per-call, same rationale as FlowRuntime._weave_controller(): cheap
## RefCounted, always correct even if a caller replaces flow_ctx after construction.
func _settlement_service() -> EconomySettlementService:
	return EconomySettlementServiceScript.new(flow_ctx, config_service, econ, logger)
