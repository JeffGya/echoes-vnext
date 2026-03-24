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

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.REALM_INIT,
		"data": {
			"realm_id":    str(model.get("id", "")),
			"name":        str(model.get("name", "")),
			"virtue":      str(model.get("virtue", "")),
			"description": str(model.get("description", "")),
			"stage_count": int(model.get("stage_count", 0)),
			"seed":        int(model.get("seed", 0)),
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
