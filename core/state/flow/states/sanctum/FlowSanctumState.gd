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
		
	# --- Sanctum roster (from save) ---
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	# Build a small preview list (first 3)
	var roster_preview: Array = []
	var limit : Variant = min(3, roster.size())
	for i in range(limit):
		var echo_v: Variant = roster[i]
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}

		roster_preview.append({
			"id": str(echo.get("id", "")),
			"name": str(echo.get("name", "")),
			"calling_origin": str(echo.get("calling_origin", "")),
			"rarity": str(echo.get("rarity", "")),
			"rank": int(echo.get("rank", 1)),
		})
	
	# Base Sanctum snapshot. FlowStateMachine._rebuild_snapshot() enriches data with:
	# - ase_balance, ekwan_balance (Economy)
	# - roster_count, active_party_count (Sanctum)
	var data := {
		"title": "Sanctum",
		"first_boot": flow_ctx.save_data.get("first_boot", true),
		"realm_id": flow_ctx.realm_id,
		"stage_id": flow_ctx.stage_id,
		"encounter_id": flow_ctx.encounter_id,
		"roster_count": roster.size(),
		"roster_preview": roster_preview,
	}

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.SANCTUM,
		"data": data,
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
