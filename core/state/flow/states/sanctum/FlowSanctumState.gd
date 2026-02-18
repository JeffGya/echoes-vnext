class_name FlowSanctumState

extends State

func _init(id: String = FlowStateIds.SANCTUM) -> void:
	super(id)
	
func enter(ctx: RefCounted, t:int) -> void:
	var flow_ctx := ctx as FlowContext
	
	var has_realm_locked_in := flow_ctx.realm_id != ""
	
	var actions: Array = [
		{
			"type": "flow.go_state",
			"to": FlowStateIds.PARTY_MANAGE,
			"label": "Manage Party"
		},
		{
			"type": "flow.go_state",
			"to": FlowStateIds.ECHO_MANAGE,
			"label": "Manage Echoes"
		},
		{
			"type": "flow.go_state",
			"to": FlowStateIds.REALM_SELECT,
			"label": "Select Realm"
		},
		{
			"type": "flow.go_state",
			"to": FlowStateIds.SUMMON,
			"label": "Summon Echo"
		}
	]
	
	# Start run is only available if a realm is locked in.
	if has_realm_locked_in:
		actions.append({
			"type": "flow.go_state",
			"to": FlowStateIds.STAGE_MAP,
			"label": "Enter Stage"
		})
	else: 
		# Still show it, but disabled, so UI can teach the flow.
		actions.append({
			"type": "flow.go_state",
			"to": FlowStateIds.STAGE_MAP,
			"label": "Enter Stage (Select a Realm first)",
			"disabled": true
		})
		
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.SANCTUM,
		"data": {
			"title": "Sanctum",
			"first_boot": flow_ctx.save_data.get("first_boot", true),
			"realm_id": flow_ctx.realm_id,
			"stage_id": flow_ctx.stage_id,
			"encounter_id": flow_ctx.encounter_id
		},
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
