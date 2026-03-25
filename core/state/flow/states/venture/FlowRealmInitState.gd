class_name FlowRealmInitState

extends State

# REALM-001: Realm overview card shown immediately after the player selects a realm.
# Reads the active RealmModel from RealmService and emits a snapshot with:
#   - realm name, virtue, description, stage_count, seed (debug/flavour)
# Actions: cta.begin → stage_map, nav.back → realm_select

func _init(id: String = FlowStateIds.REALM_INIT) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	var model := RealmService.get_active(flow_ctx)

	# Guard: if no active realm somehow, fall back to realm select
	if model.is_empty():
		flow_ctx.logger.warn(t, "realm_init.no_model", "FlowRealmInitState entered with no active realm; redirecting", {})
		flow_ctx.last_snapshot = {
			"type":    FlowStateIds.REALM_INIT,
			"data":    {
				"realm_id":    "",
				"name":        "Unknown Realm",
				"virtue":      "",
				"description": "",
				"stage_count": 0,
				"seed":        0,
				"stages":      [],
				"error":       "no_active_realm"
			},
			"actions": {
				"nav.back": {
					"type":  "flow.go_state",
					"to":    FlowStateIds.REALM_SELECT,
					"label": "Back",
					"slot":  "nav.back",
				}
			},
			"meta": { "t": t }
		}
		return

	var raw_stages: Variant = model.get("stages", [])
	var model_stages: Array = raw_stages if raw_stages is Array else []

	# Pre-build stages array — nested lambdas inside dict literals cause GDScript parse errors
	var projected_stages: Array = []
	for stage in model_stages:
		var raw_objs: Variant = stage.get("objectives", [])
		var objs: Array = raw_objs if raw_objs is Array else []
		var projected_objs: Array = []
		for obj in objs:
			projected_objs.append({
				"obj_index":       int(obj.get("index", 0)),
				"obj_type":        str(obj.get("type", "")),
				"obj_description": str(ObjectiveModel.TYPE_DESCRIPTIONS.get(obj.get("type", ""), "")),
			})
		projected_stages.append({
			"stage_index":       int(stage.get("index", 0)),
			"stage_type":        str(stage.get("type", "")),
			"stage_seed":        int(stage.get("seed", 0)),
			"stage_description": str(StageModel.TYPE_DESCRIPTIONS.get(stage.get("type", ""), "")),
			"objective_count":   objs.size(),
			"objectives":        projected_objs,
		})

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.REALM_INIT,
		"data": {
			"realm_id":    str(model.get("id", "")),
			"name":        str(model.get("name", "")),
			"virtue":      str(model.get("virtue", "")),
			"description": str(model.get("description", "")),
			"stage_count": int(model.get("stage_count", 0)),
			"seed":        int(model.get("seed", 0)),
			"stages":      projected_stages,
		},
		"actions": {
			"cta.begin": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.STAGE_MAP,
				"label": "Begin",
				"slot":  "cta.begin",
			},
			"nav.back": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.REALM_SELECT,
				"label": "Back",
				"slot":  "nav.back",
			},
		},
		"meta": { "t": t }
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass
