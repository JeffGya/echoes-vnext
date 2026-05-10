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
				var _emo_s: Dictionary = echo.get("emotion", {})
				party_preview.append({
					"name":             str(echo.get("name", "")),
					"rank":             int(echo.get("rank", 1)),
					"calling_origin":   str(echo.get("calling_origin", "")),
					# V2-EMOTION-002: unified emotional status.
					"emotional_status": EmotionService.get_emotional_status(
						int(_emo_s.get("morale_current", 50)),
						int(_emo_s.get("fear_current", 0))
					),
				})
				break

	# V2-STAGE-001: expose explore map dimensions + situation positions for preview
	var explore_map_v: Variant = stage.get("explore_map", {})
	var explore_map_s: Dictionary = explore_map_v if explore_map_v is Dictionary else {}
	var preview_width:  int = int(explore_map_s.get("width",  30))
	var preview_height: int = int(explore_map_s.get("height", 30))
	var entry_pos_v: Variant = explore_map_s.get("party_pos", { "col": 0, "row": preview_height / 2 })
	var entry_pos: Dictionary = entry_pos_v if entry_pos_v is Dictionary else { "col": 0, "row": preview_height / 2 }

	# V2-INTEL-001: Project situation positions with revealed/resolved/type for the preview.
	# Previously scouted situations show their type marker rather than '?' on re-entry.
	var raw_map_sits: Variant = explore_map_s.get("situations", [])
	var map_situations: Array = []
	for msit_v in (raw_map_sits if raw_map_sits is Array else []):
		var msit: Dictionary = msit_v if msit_v is Dictionary else {}
		var msit_revealed := bool(msit.get("revealed", false))
		var msit_resolved := bool(msit.get("resolved", false))
		map_situations.append({
			"pos":      msit.get("pos", { "col": 0, "row": 0 }),
			"revealed": msit_revealed,
			"resolved": msit_resolved,
			"type":     str(msit.get("type", "hidden")) if msit_revealed else "hidden",
		})

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
			"to":    FlowStateIds.STAGE_EXPLORE,  # V2-STAGE-001: enters exploration map
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
			# V2-STAGE-001: map overview data for StageExploreScreen preview mode
			"map_width":         preview_width,
			"map_height":        preview_height,
			"map_entry_pos":     entry_pos,
			"map_situations":    map_situations,
			"directive": {
				"active_id":  sc_dir,
				"directives": dir_list,
			},
			# V2-VOW-002: passive mantra + condition hint for atmospheric display on stage overview.
			# Shape: { vow_id, vow_name, proverb_twi, proverb_en, tier, condition_status, condition_hint } or {}.
			"active_vow": _build_active_vow_with_hint(flow_ctx),
		},
		"actions": actions,
		"meta": { "t": t },
	}


## V2-VOW-002: Builds active_vow dict for stage overview, extending mantra with condition hint.
## Returns {} if no active vow.
static func _build_active_vow_with_hint(flow_ctx: FlowContext) -> Dictionary:
	var cfg: Dictionary = flow_ctx.config_service.get_balance() if flow_ctx.config_service != null else {}
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return {}
	var av_id := str(av.get("vow_id", ""))
	var defn := VowService.get_definition(av_id, cfg)
	var mantra: Dictionary = {
		"vow_id":      av_id,
		"vow_name":    str(defn.get("vow_name", "")),
		"proverb_twi": str(defn.get("proverb_twi", "")),
		"proverb_en":  str(defn.get("proverb_en", "")),
		"tier":        int(av.get("tier", 1)),
	}
	# Get party ids for hint preview.
	var party_ids: Array = []
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if sanctum_v is Dictionary:
		var p_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v
	var hint: Dictionary = VowService.preview_stage_condition_hint(flow_ctx.save_data, party_ids, cfg)
	mantra["condition_status"] = str(hint.get("status", "none"))
	mantra["condition_hint"]   = str(hint.get("hint", ""))
	return mantra
