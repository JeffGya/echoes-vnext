class_name FlowRealmSelectState

extends State

func _init(id: String = FlowStateIds.REALM_SELECT) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	# MVP placeholder realms (to be replaced with config-driven lists).
	var realms: Array =[
		{"id": "realm.01", "name": "REALM 01", "locked": false},
		{"id": "realm.02", "name": "REALM 02", "locked": true}
	]
	
	var actions: Array = []
	
	for r in realms:
		actions.append({
			"type": "flow.select_realm",
			"realm_id": r["id"],
			"label": r["name"],
			"disabled": r.get("locked", false)
		})
	
	actions.append({
		"type": "flow.go_state",
		"to": FlowStateIds.SANCTUM,
		"label": "Back"
	})
	
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.REALM_SELECT,
		"data": {
			"title": "Select Realm",
			"current_realm_id": flow_ctx.realm_id,
			"realms": realms
		},
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
