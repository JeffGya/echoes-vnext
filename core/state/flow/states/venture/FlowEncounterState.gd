class_name FlowEncounterState

extends State

func _init(id: String = FlowStateIds.ENCOUNTER) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	# MVP scaffold: Encounter will later be driven by EncounterStateMachine + combat loop.
	# For now, treat it as a placeholder "encounter screen" with deterministic actions.
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.ENCOUNTER,
		"data": {
			"title": "Encounter",
			"realm_id": flow_ctx.realm_id,
			"stage_id": flow_ctx.stage_id,
			"encounter_id": flow_ctx.encounter_id,
			"note": "MVP scaffold: encounter/combat not implemented yet."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.RESOLVE,
				"label": "Complete Encounter -> Resolver"
			},
			{
				"type": "flow.go_state",
				"to": FlowStateIds.STAGE,
				"label": "Back to Stage",
				"disabled": true
			}
		],
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
