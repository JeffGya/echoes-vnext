class_name FlowEchoManageState

extends State

func _init(id: String = FlowStateIds.ECHO_MANAGE) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.ECHO_MANAGE,
		"data": {
			"title": "Manage Echoes",
			"echoes": [],
			"note": "MVP scaffold: echo management not implemented yet (stats/skills/inventory/jobs/classes)."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back"
			}
		],
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
