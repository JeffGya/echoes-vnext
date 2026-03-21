class_name FlowStageMapState

extends State

func _init(id: String = FlowStateIds.STAGE_MAP) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Stages run sequentially — players cannot select them out of order.
	# Only realms can be selected out of order. MVP: Stage 01 is always current.
	# Future stories will track completed stages in save_data and unlock Stage 02+.
	var stages: Array = [
		{ "id": "stage.01", "name": "Stage 01", "status": "current" },
		{ "id": "stage.02", "name": "Stage 02", "status": "locked" },
	]

	# Current stage = first stage with status "current". Default to stage.01.
	var current_stage: Dictionary = stages[0]
	for s in stages:
		if s.get("status", "") == "current":
			current_stage = s
			break

	# Single CTA — advances to the current (next) stage in sequence.
	# No per-stage selectable slots. Stages are shown as progress, not as choices.
	var actions: Dictionary = {
		"cta.enter_stage": {
			"type": "flow.select_stage",
			"stage_id": current_stage["id"],
			"label": "Enter " + current_stage["name"],
			"slot": "cta.enter_stage",
		},
		"nav.back": {
			"type": "flow.go_state",
			"to": FlowStateIds.SANCTUM,
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

	# Format realm name for display. MVP: derive from realm_id until realms.json has names.
	var realm_name: String = ""
	var raw_realm: String = str(flow_ctx.realm_id)
	if not raw_realm.is_empty():
		realm_name = raw_realm.replace(".", " ").replace("_", " ").capitalize()

	var stages_completed_count: int = 0
	for s in stages:
		if s.get("status", "") == "completed":
			stages_completed_count += 1

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE_MAP,
		"data": {
			"title": "Stage Map",
			"realm_id": flow_ctx.realm_id,
			"realm_name": realm_name,
			"current_stage_id": current_stage["id"],
			"stages_completed_count": stages_completed_count,
			"stages": stages,  # each entry: { id, name, status: current|locked|completed }
			"party_preview": party_preview,
			"note": "MVP scaffold: stage list is placeholder until realms/stages stories."
		},
		"actions": actions,
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
