class_name FlowStageState

extends State

func _init(id: String = FlowStateIds.STAGE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


# Static builder — called by enter() and by FlowRuntime on directive.select refresh.
# Follows the same pattern as FlowSummonState and FlowStageMapState.
static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# Load active realm and resolve the current stage from stage_id
	var model := RealmService.get_active(flow_ctx)
	var raw_model_stages: Variant = model.get("stages", [])
	var model_stages: Array = raw_model_stages if raw_model_stages is Array else []

	# Parse stage index from stage_id (e.g. "stage.0" → 0, "stage.2" → 2)
	var stage_index := 0
	var sid := str(flow_ctx.stage_id)
	if sid.contains("."):
		var parts := sid.split(".")
		stage_index = int(parts[parts.size() - 1])

	# Find the matching stage dict, fall back to first
	var stage: Dictionary = {}
	for s_v in model_stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if int(s.get("index", -1)) == stage_index:
			stage = s
			break
	if stage.is_empty() and not model_stages.is_empty():
		var first_v: Variant = model_stages[0]
		stage = first_v if first_v is Dictionary else {}

	# Derive display fields
	var stype  := str(stage.get("type", "combat"))
	var sname  := "Stage %d — %s" % [stage_index + 1, stype.capitalize()]
	var sdesc  := str(StageModel.TYPE_DESCRIPTIONS.get(stype, ""))

	# Project objectives for snapshot
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

	# V2-DIRECTIVE-001: directive selection payload for the blocking overlay
	var sc_dir := str(flow_ctx.save_data.get("stage_context", {}).get("active_directive_id", "directive.scout_carefully"))
	var dir_svc := DirectiveService.new(flow_ctx.save_data)
	var dir_list: Array = []
	for dir_id in ["directive.scout_carefully", "directive.seek_signs"]:
		var d := dir_svc.get_directive(dir_id)
		dir_list.append({
			"id":          d.get("id",          dir_id),
			"label":       d.get("label",       dir_id),
			"description": d.get("description", ""),
			"pros":        d.get("pros",        []),
			"cons":        d.get("cons",        []),
		})

	var actions: Dictionary = {
		"cta.start": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.ENCOUNTER,
			"label": "Begin",
			"slot":  "cta.start",
		},
		"nav.back": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.STAGE_MAP,
			"label": "Back",
			"slot":  "nav.back",
		},
	}

	return {
		"type": FlowStateIds.STAGE,
		"data": {
			"stage_id":          flow_ctx.stage_id,
			"stage_name":        sname,
			"stage_type":        stype,
			"stage_description": sdesc,
			"objective_count":   objs.size(),
			"objectives":        projected_objs,
			"realm_id":          flow_ctx.realm_id,
			"party_preview":     party_preview,
			"directive": {
				"active_id":  sc_dir,
				"directives": dir_list,
			},
		},
		"actions": actions,
		"meta": { "t": t },
	}
