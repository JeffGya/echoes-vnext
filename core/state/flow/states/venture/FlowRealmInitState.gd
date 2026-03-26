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

	# Guard: if no active realm, fall back to realm select
	if model.is_empty():
		flow_ctx.logger.warn(t, "realm_init.no_model", "FlowRealmInitState entered with no active realm; redirecting to realm_select", {})
		flow_ctx.last_snapshot = {
			"type":    FlowStateIds.REALM_INIT,
			"data":    {},
			"actions": {},
			"meta":    { "t": t }
		}
		flow_ctx.flow_machine.call_deferred("transition", FlowStateIds.REALM_SELECT, flow_ctx, flow_ctx.logger, t)
		return

	# Skip init screen — transition directly to stage map on next frame.
	flow_ctx.logger.debug(t, "realm_init.passthrough", "RealmInit skipped; auto-advancing to stage_map", {})
	flow_ctx.last_snapshot = {
		"type":    FlowStateIds.REALM_INIT,
		"data":    {},
		"actions": {},
		"meta":    { "t": t }
	}
	flow_ctx.flow_machine.call_deferred("transition", FlowStateIds.STAGE_MAP, flow_ctx, flow_ctx.logger, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass
