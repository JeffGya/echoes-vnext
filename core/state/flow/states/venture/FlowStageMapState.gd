class_name FlowStageMapState

extends State

func _init(id: String = FlowStateIds.STAGE_MAP) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	# MVP placeholder stages (config-driven later).
	var stages: Array = [
		{ "id": "stage.01", "name": "Stage 01", "locked": false },
		{ "id": "stage.02", "name": "Stage 02", "locked": false }
	]
	
	var actions: Array = []
	
	for s in stages:
		actions.append({
			"type": "flow.select_stage",
			"stage_id": s["id"],
			"label": s["name"],
			"disabled": s.get("locked", false)
		})
		
	actions.append({
		"type": "flow.go_state",
		"to": FlowStateIds.SANCTUM,
		"label": "Back"
	})
	
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE_MAP,
		"data": {
			"title": "Stage Map",
			"realm_id": flow_ctx.realm_id,
			"current_stage_id": flow_ctx.stage_id,
			"stages": stages,
			"note": "MVP scaffold: stage list is placeholder until realms/stages stories."
		},
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
