class_name FlowStageState

extends State

func _init(id: String = FlowStateIds.STAGE) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE,
		"data": {
			"title": "Stage",
			"realm_id": flow_ctx.realm_id,
			"stage_id": flow_ctx.stage_id,
			"objective_index": 0,
			"note": "MVP scaffold: stage objectives and encounter generation not implemented yet."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.ENCOUNTER,
				"label": "Start Objective (Encounter)"
			},
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Abort Run (Return to Sanctum)",
				"disabled": true
			}
		],
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
