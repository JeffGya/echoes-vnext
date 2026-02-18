class_name FlowPartyManageState

extends State

func _init(id: String = FlowStateIds.PARTY_MANAGE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.PARTY_MANAGE,
		"data": {
			"title": "Manage Party",
			"party": [],
			"note": "MVP scaffold: party selection not implemented yet."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back"
			},
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Confirm Party",
				"disabled": true
			}
		],
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
