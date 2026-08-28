class_name FlowResolveState
extends State

func _init(id: String = FlowStateIds.RESOLVE) -> void:
	super(id)

## V2-INFRA-003 Phase 8B — this state stopped being a pass-through.
##
## It used to do one thing: if `flow_ctx.last_snapshot` was already a flow.resolve snapshot,
## return and keep it; otherwise build a dead scaffold that said "Result unavailable." The
## scaffold was unreachable in play, and the live snapshot was the ONLY record of a run's
## outcome — held in memory, lost on quit.
##
## The order is now inverted. The DURABLE result comes first, the live snapshot second:
##
##   1. `save.flow.pending_result` — producer G (PendingResultService.build_snapshot). This is
##      the only branch that can serve a player who quit on the Resolve screen and pressed
##      Continue, because after a relaunch there is no live snapshot to pass through.
##   2. The live flow.resolve snapshot — the ordinary path. On the dispatch that ENDS a run,
##      producer A/C has already written the card into `last_snapshot` and the durable result
##      has not been captured yet (capture happens at the end of that same dispatch, after this
##      transition), so this branch still serves every in-session resolve exactly as before.
##   3. The fallback scaffold — producer F. Unchanged, still last.
##
## Why 1 before 2 rather than after: a stale flow.resolve snapshot can outlive the run that
## made it (nothing clears `last_snapshot` on transition), so "already the right type" is not
## evidence that it is the right CARD. The durable result carries a `result_id` and a
## `created_t`; the loose snapshot carries neither. When both exist and disagree, the record
## that was deliberately written wins over the one that was merely left behind.
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# 1 — producer G, from the durable result.
	var pending := PendingResultService.build_snapshot(flow_ctx, t)
	if not pending.is_empty():
		flow_ctx.last_snapshot = pending
		return

	# 2 — Fix BUG-001: build_final_snapshot() already writes a proper "flow.resolve" snapshot
	# into flow_ctx.last_snapshot before the FSM transitions here. Guard-and-pass-through:
	# if it's already the right type, keep it — do not overwrite with the scaffold.
	if not flow_ctx.last_snapshot.is_empty() \
			and str(flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.RESOLVE:
		return

	# 3 — Fallback scaffold — only reached if the encounter path skipped build_final_snapshot()
	# and nothing is pending.
	# Uses slot-keyed Dictionary actions (not legacy Array). No cta.next_stage — player must replay.
	#
	# Producer F, composed through ResolveSnapshotBuilder. It emits no run_type, so
	# ResolveScreen falls through to the combat renderer.
	var actions: Dictionary = {
		"cta.continue": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "Return to Sanctum",
			"slot":  "cta.continue",
		},
	}
	var snap: Dictionary = ResolveSnapshotBuilder.build(t, actions)
	var data: Dictionary = snap["data"]
	ResolveSnapshotBuilder.add_victory_flag(data, false)
	flow_ctx.last_snapshot = snap

func exit(ctx: RefCounted, t: int) -> void:
	pass
