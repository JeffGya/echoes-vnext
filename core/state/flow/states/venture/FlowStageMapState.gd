class_name FlowStageMapState

extends State

func _init(id: String = FlowStateIds.STAGE_MAP) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Load active realm model
	var model := RealmService.get_active(flow_ctx)

	# --- Build stage list from RealmModel ---
	var raw_model_stages: Variant = model.get("stages", [])
	var model_stages: Array = raw_model_stages if raw_model_stages is Array else []
	var current_stage_index := int(model.get("current_stage_index", 0))
	var realm_name: String = str(model.get("name", "")) if not model.is_empty() else ""

	# Fall back to a minimal scaffold row so the screen is never blank
	if model_stages.is_empty():
		model_stages = [{ "index": 0, "type": "combat", "seed": 0, "objectives": [] }]

	var stages: Array = []
	for stage_v in model_stages:
		var stage: Dictionary = stage_v if stage_v is Dictionary else {}
		var idx    := int(stage.get("index", 0))
		var stype  := str(stage.get("type", "combat"))
		var stage_status: String
		if idx < current_stage_index:
			stage_status = "completed"
		elif idx == current_stage_index:
			stage_status = "current"
		else:
			stage_status = "locked"

		# Project objectives for display
		var raw_objs: Variant = stage.get("objectives", [])
		var objs: Array = raw_objs if raw_objs is Array else []
		var projected_objs: Array = []
		for obj_v in objs:
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			projected_objs.append({
				"obj_index":       int(obj.get("index", 0)),
				"obj_type":        str(obj.get("type", "")),
				"obj_description": str(ObjectiveModel.TYPE_DESCRIPTIONS.get(obj.get("type", ""), "")),
			})

		stages.append({
			"id":                "stage.%d" % idx,
			"name":              "Stage %d — %s" % [idx + 1, stype.capitalize()],
			"status":            stage_status,
			"stage_type":        stype,
			"stage_description": str(StageModel.TYPE_DESCRIPTIONS.get(stype, "")),
			"objective_count":   objs.size(),
			"objectives":        projected_objs,
		})

	# Current stage entry (first with status "current")
	var current_stage: Dictionary = stages[0] if not stages.is_empty() else {}
	for s in stages:
		if s.get("status", "") == "current":
			current_stage = s
			break

	# Actions
	var actions: Dictionary = {
		"cta.enter_stage": {
			"type":     "flow.select_stage",
			"stage_id": str(current_stage.get("id", "stage.0")),
			"label":    "Enter " + str(current_stage.get("name", "Stage")),
			"slot":     "cta.enter_stage",
		},
		"nav.back": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "Back",
			"slot":  "nav.back",
		},
	}

	# Party preview (from save)
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
					"name":           str(echo.get("name", "")),
					"rank":           int(echo.get("rank", 1)),
					"calling_origin": str(echo.get("calling_origin", "")),
				})
				break

	var stages_completed_count := 0
	for s in stages:
		if s.get("status", "") == "completed":
			stages_completed_count += 1

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.STAGE_MAP,
		"data": {
			"title":                  "Stage Map",
			"realm_id":               flow_ctx.realm_id,
			"realm_name":             realm_name,
			"current_stage_id":       str(current_stage.get("id", "")),
			"stages_completed_count": stages_completed_count,
			"stages":                 stages,
			"party_preview":          party_preview,
		},
		"actions": actions,
		"meta": { "t": t },
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass
