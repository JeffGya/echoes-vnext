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
	#
	# V2-INFRA-003 Phase 5 Slice B: producer F, composed through ResolveSnapshotBuilder.
	# It emits no run_type, so ResolveScreen falls through to the combat renderer — same as
	# before. `title` and `note` are dead keys with zero consumers; they are reproduced
	# deliberately (see the builder's blocks #16/#17) rather than dropped here.
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
	ResolveSnapshotBuilder.add_legacy_title(data, "Resolve")
	ResolveSnapshotBuilder.add_victory_flag(data, false)
	ResolveSnapshotBuilder.add_legacy_note(data, "Result unavailable.")
	flow_ctx.last_snapshot = snap

func exit(ctx: RefCounted, t: int) -> void:
	pass
