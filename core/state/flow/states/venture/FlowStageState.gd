class_name FlowStageState

extends State

func _init(id: String = FlowStateIds.STAGE) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Slot-keyed Dictionary — Feb 2026 standard. Each entry includes its own "slot" key.
	var actions: Dictionary = {
		"cta.start": {
			"type": "flow.go_state",
			"to": FlowStateIds.ENCOUNTER,
			"label": "Start Objective",
			"slot": "cta.start",
		},
		"nav.back": {
			"type": "flow.go_state",
			"to": FlowStateIds.STAGE_MAP,
			"label": "Back",
			"slot": "nav.back",
		},
	}

	# --- Party preview (from save) ---
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var active_ids_v: Variant = sanctum.get("active_party_ids", [])
	var active_ids: Array = active_ids_v if active_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var party_preview: Array = []
	for echo_id in active_ids:
		if party_preview.size() >= 5:
			break
		for echo_v in roster:
			var echo: Dictionary = echo_v if echo_v is Dictionary else {}
			if str(echo.get("id", "")) == str(echo_id):
				party_preview.append({
					"name": str(echo.get("name", "")),
					"rank": int(echo.get("rank", 1)),
					"calling_origin": str(echo.get("calling_origin", "")),
				})
				break

	var stage_names: Dictionary = { "stage.01": "Stage 01", "stage.02": "Stage 02" }

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE,
		"data": {
			"title": "Stage",
			"stage_id": flow_ctx.stage_id,
			"stage_name": stage_names.get(flow_ctx.stage_id, flow_ctx.stage_id),
			"objective_type": "purify_shrine",
			"enemy_count_hint": 2,
			"party_preview": party_preview,
			"realm_id": flow_ctx.realm_id,
			"note": "MVP scaffold"
		},
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
