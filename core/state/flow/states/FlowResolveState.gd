class_name FlowResolveState
extends State

func _init(id: String = FlowStateIds.RESOLVE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Fix BUG-001: build_final_snapshot() already writes a proper "flow.resolve" snapshot
	# into flow_ctx.last_snapshot before the FSM transitions here. Guard-and-pass-through:
	# if it's already the right type, keep it — do not overwrite with the scaffold.
	if not flow_ctx.last_snapshot.is_empty() \
			and str(flow_ctx.last_snapshot.get("type", "")) == FlowStateIds.RESOLVE:
		return

	# Fallback scaffold — only reached if the encounter path skipped build_final_snapshot().
	# Uses slot-keyed Dictionary actions (not legacy Array). No cta.next_stage — player must replay.
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.RESOLVE,
		"data": {
			"title":   "Resolve",
			"victory": false,
			"note":    "Result unavailable.",
		},
		"actions": {
			"cta.continue": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "Return to Sanctum",
				"slot":  "cta.continue",
			},
		},
		"meta": { "t": t },
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass
