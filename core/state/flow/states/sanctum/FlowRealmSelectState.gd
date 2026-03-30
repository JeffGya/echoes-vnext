class_name FlowRealmSelectState

extends State

# REALM-001: Config-driven realm selection screen.
# Reads realm list from realms.json via ConfigService.
# Computes runtime lock status from save_data["realms"] via RealmService.
#
# Realm card selection is per-row dispatch from UI (not in snapshot.actions),
# consistent with other sanctum screens.
# snapshot.actions only contains nav.back.

func _init(id: String = FlowStateIds.REALM_SELECT) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Load realm config
	var realms_cfg : Dictionary = flow_ctx.config_service.get_realms()
	var data_v: Variant = realms_cfg.get("data", {})
	var cfg_data: Dictionary = data_v if data_v is Dictionary else {}

	var realm_order_v: Variant = cfg_data.get("realm_order", [])
	var realm_order: Array = realm_order_v if realm_order_v is Array else []

	var realms_map_v: Variant = cfg_data.get("realms", {})
	var realms_map: Dictionary = realms_map_v if realms_map_v is Dictionary else {}

	# Current save state for lock computation
	var save_realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var save_realms: Dictionary = save_realms_v if save_realms_v is Dictionary else {}

	# Build config list for lock computation (ordered by realm_order)
	var realm_cfg_list: Array = []
	for rid in realm_order:
		if realms_map.has(rid):
			realm_cfg_list.append(realms_map[rid])

	var locks := RealmService.compute_runtime_locks(realm_cfg_list, save_realms)

	# Build realm cards for snapshot
	var realms_out: Array = []
	for rid in realm_order:
		if not realms_map.has(rid):
			continue

		var cfg_entry_v: Variant = realms_map[rid]
		var cfg_entry: Dictionary = cfg_entry_v if cfg_entry_v is Dictionary else {}

		# Runtime status from save, or "not_started" if never touched
		var saved_v: Variant = save_realms.get(rid, {})
		var saved: Dictionary = saved_v if saved_v is Dictionary else {}
		var status := str(saved.get("status", RealmModel.STATUS_NOT_STARTED))

		# Locked = computed runtime lock
		var is_locked: bool = locks.get(rid, false)

		realms_out.append({
			"id":          str(cfg_entry.get("id", rid)),
			"name":        str(cfg_entry.get("name", rid)),
			"virtue":      str(cfg_entry.get("virtue", "")),
			"description": str(cfg_entry.get("description", "")),
			"stage_count_min": int(cfg_entry.get("stage_count_min", 0)),
			"stage_count_max": int(cfg_entry.get("stage_count_max", 0)),
			"status":      status,
			"locked":      is_locked,
		})

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.REALM_SELECT,
		"data": {
			"title":            "Select Realm",
			"current_realm_id": flow_ctx.realm_id,
			"realms":           realms_out,
		},
		"actions": {
			"nav.back": {
				"type":  "flow.go_state",
				"to":    FlowStateIds.SANCTUM,
				"label": "← Back",
				"slot":  "nav.back",
			}
		},
		"meta": { "t": t }
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass
