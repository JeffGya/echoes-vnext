# res://core/state/flow/FlowActionOutcome.gd
# V2-INFRA-003 Phase 2 Part A: typed result handed back by a controller's action handler.
#
# This is a plain data carrier — no behavior, no side effects. It exists so that, in a
# later phase (Part B), per-action handlers can report "what happened" (should the flow
# transition, is there a replacement snapshot, what save reasons were requested, did it
# fail) as one typed value instead of mutating FlowContext directly and returning void.
#
# There is no `handled` flag. One was defined and written by every constructor, but no
# caller ever read it, and the doc claimed a fall-through behaviour that did not exist.
# Removed after the PR #61 review. A handler that does not recognise an action does not
# return an outcome at all.

class_name FlowActionOutcome
extends RefCounted

## Non-empty when the outcome should trigger a flow state transition. Holds a FlowStateIds
## constant value (a state ID string), matching the `to` field used elsewhere in actions.
var transition_to: String = ""

## Human-readable reason for the transition, mirrors the `reason` argument already threaded
## through FlowStateMachine.transition().
var transition_reason: String = ""

## A fully-built snapshot the caller should assign to flow_ctx.last_snapshot in place of
## re-deriving one. Only meaningful when has_replacement_snapshot is true.
var replacement_snapshot: Dictionary = {}
var has_replacement_snapshot: bool = false

## V2-INFRA-003 Phase 4 Slice 6b: when true, the caller must assign replacement_snapshot to
## flow_ctx.last_snapshot WITHOUT then calling flow_machine.refresh_snapshot(). Exists because
## sanctum.rank_up and sanctum.calling.confirm are the only two dispatched actions that build
## and assign a replacement snapshot but never refresh it (pre-extraction: they wrote
## flow_ctx.last_snapshot directly and returned void, with no flow_machine.refresh_snapshot()
## call anywhere on their path). Ignored when has_replacement_snapshot is false.
var suppress_refresh: bool = false

## V2-INFRA-003 Phase 4 Slice 8: when true, the caller must call
## flow_machine.reenter(flow_ctx, logger, t) then flow_machine.refresh_snapshot(flow_ctx,
## logger, t) instead of assigning a replacement_snapshot. reenter() re-runs the current state's
## enter() and assigns flow_ctx.last_snapshot itself, so replacement_snapshot/
## has_replacement_snapshot are not used alongside this flag — a controller sets one shape or
## the other, never both. This is the reenter()+refresh_snapshot() pairing that fixed a recorded
## defect where the Sanctum projection came back incomplete after a mid-state mutation (skill
## unlock, party toggle). Designed in an earlier slice with zero call sites; SanctumController
## (sanctum.party.toggle's SANCTUM branch, the three sanctum.institution.* handlers, and
## sanctum.companion.accept/decline) is its first set of call sites.
var requires_reenter: bool = false

## V2-INFRA-003 Phase 5 Slice D: when true, the caller must call
## flow_machine.refresh_snapshot(flow_ctx, logger, t) WITHOUT first assigning any replacement
## snapshot. Exists because two venture handlers refresh a snapshot they did not rebuild:
## stage.advance_turn's "party not in exploring state" guard, and directive.select when the
## live snapshot is NOT flow.stage (only the STAGE branch rebuilds via
## FlowStageState.build_snapshot()). Pre-extraction both called a bare
## flow_machine.refresh_snapshot() and returned void. snapshot_outcome() cannot express this —
## it always assigns — and handled_outcome() would DROP the refresh. Ignored when
## has_replacement_snapshot or requires_reenter is true; a controller sets exactly one shape.
var requires_refresh: bool = false

## Save reasons this outcome wants recorded. Each entry is passed to
## FlowContext.request_save() / FlowRuntime._mark_save_requested() by the caller — this
## array does not itself request a save.
var save_reasons: Array[String] = []

## Non-empty when the handler failed in a way the caller should surface (e.g. validation
## failure). Empty string means no error.
var error_code: String = ""


## Convenience constructor for the common "handled, no transition, no save" case.
static func handled_outcome() -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	return outcome


## Convenience constructor for a handled outcome that also requests a state transition.
static func transition_outcome(to_state: String, reason: String = "") -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.transition_to = to_state
	outcome.transition_reason = reason
	return outcome


## Convenience constructor for a handled outcome that supplies a ready-made snapshot.
static func snapshot_outcome(snapshot: Dictionary) -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.replacement_snapshot = snapshot
	outcome.has_replacement_snapshot = true
	return outcome


## Convenience constructor matching snapshot_outcome(), except the caller must assign the
## snapshot WITHOUT refreshing afterward. See suppress_refresh above for why this exists.
static func snapshot_outcome_no_refresh(snapshot: Dictionary) -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.replacement_snapshot = snapshot
	outcome.has_replacement_snapshot = true
	outcome.suppress_refresh = true
	return outcome


## Convenience constructor for a handled outcome that requires a reenter()+refresh_snapshot()
## pairing instead of a directly supplied replacement snapshot. See requires_reenter above.
static func reenter_outcome() -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.requires_reenter = true
	return outcome


## Convenience constructor for a handled outcome that only needs a bare
## flow_machine.refresh_snapshot() — no replacement snapshot. See requires_refresh above.
static func refresh_outcome() -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.requires_refresh = true
	return outcome


## Convenience constructor for a handled outcome that failed with a specific error code.
static func error_outcome(code: String) -> FlowActionOutcome:
	var outcome := FlowActionOutcome.new()
	outcome.error_code = code
	return outcome


## Chainable helper: appends a save reason and returns self, so callers can write
## FlowActionOutcome.handled_outcome().with_save_reason("sanctum.summon").
func with_save_reason(reason: String) -> FlowActionOutcome:
	save_reasons.append(reason)
	return self
