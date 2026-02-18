class_name FlowResolveState
extends State

func _init(id: String = FlowStateIds.RESOLVE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# MVP scaffold: resolve will later display real run results (deaths/rewards/stats).
	# For now, keep it deterministic and simple.
	var result: Dictionary = {}
	# If you later add flow_ctx.last_run_result, read it here.

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.RESOLVE,
		"data": {
			"title": "Resolve",
			"result": result,
			"note": "MVP scaffold: stage/encounter results not implemented yet."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Return to Sanctum"
			}
		],
		"meta": {
			"t": t
		}
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass
