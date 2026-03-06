class_name FlowPartyManageState

extends State

func _init(id: String = FlowStateIds.PARTY_MANAGE) -> void:
	super(id)

static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# 1) Read sanctum + roster from save
	var save := flow_ctx.save_data
	var sanctum: Dictionary = {}
	if save.has("sanctum") and save["sanctum"] is Dictionary:
		sanctum = save["sanctum"]

	var roster: Array = []
	if sanctum.has("roster") and sanctum["roster"] is Array:
		roster = sanctum["roster"]

	# 2) Read max party size from balance config (fallback 5)
	var max_party_size := 5
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		if balance.has("data") and balance["data"] is Dictionary:
			var data: Dictionary = balance["data"]
			if data.has("sanctum") and data["sanctum"] is Dictionary:
				var s_cfg: Dictionary = data["sanctum"]
				max_party_size = int(s_cfg.get("party_max_size", 5))

	# 3) Build roster rows using CURRENT pending_party_ids
	var roster_rows: Array = []
	for e_v in roster:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v

		var id := str(e.get("id", ""))
		if id == "":
			continue

		var name := str(e.get("name", ""))
		var rank := int(e.get("rank", 0))
		var in_party := flow_ctx.pending_party_ids.has(id)

		var row := {
			"id": id,
			"name": name,
			"rank": rank,
			"in_party": in_party
		}

		if e.has("level"):
			row["level"] = int(e.get("level", 0))

		roster_rows.append(row)

	var confirm_enabled := flow_ctx.pending_party_ids.size() >= 1

	return {
		"type": FlowStateIds.PARTY_MANAGE,
		"meta": { "t": t },
		"data": {
			"title": "Manage Party",
			"max_party_size": max_party_size,
			"active_party_ids": flow_ctx.pending_party_ids, # internal
			"roster": roster_rows
		},
		"actions": {
			"back": {
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back"
			},
			"primary": {
				"type": "sanctum.party.confirm",
				"label": "Confirm Party",
				"enabled": confirm_enabled
			}
		}
	}

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# 1) Read sanctum + roster from save
	var save := flow_ctx.save_data
	var sanctum: Dictionary = {}
	if save.has("sanctum") and save["sanctum"] is Dictionary:
		sanctum = save["sanctum"]

	var roster: Array = []
	if sanctum.has("roster") and sanctum["roster"] is Array:
		roster = sanctum["roster"]

	# 2) Persisted party ids
	var active_party_ids: Array = []
	if sanctum.has("active_party_ids") and sanctum["active_party_ids"] is Array:
		active_party_ids = sanctum["active_party_ids"]

	# 3) Initialize transient pending selection (copy)
	flow_ctx.pending_party_ids = active_party_ids.duplicate()

	# 4) Read max party size from balance config (fallback 5)
	var max_party_size := 5
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		if balance.has("data") and balance["data"] is Dictionary:
			var data: Dictionary = balance["data"]
			if data.has("sanctum") and data["sanctum"] is Dictionary:
				var s_cfg: Dictionary = data["sanctum"]
				max_party_size = int(s_cfg.get("party_max_size", 5))

	# 5) Build roster rows (UI will render 1 row per entry)
	var roster_rows: Array = []
	for e_v in roster:
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v

		var id := str(e.get("id", ""))
		if id == "":
			continue

		var name := str(e.get("name", ""))
		var rank := int(e.get("rank", 0))

		# Level: only if it exists in your echo schema.
		# If it doesn't exist yet, we can omit level from the row and from Sanctum party_slots later.
		var level := int(e.get("level", 0))

		var in_party : Variant = flow_ctx.pending_party_ids.has(id)

		var row := {
			"id": id,          # INTERNAL ONLY
			"name": name,      # player-facing
			"rank": rank,      # player-facing
			"in_party": in_party
		}

		# only include level if non-zero or explicitly present
		if e.has("level"):
			row["level"] = level

		roster_rows.append(row)

	# 6) Slot actions
	var confirm_enabled : Variant = flow_ctx.pending_party_ids.size() >= 1

	flow_ctx.last_snapshot = FlowPartyManageState.build_snapshot(flow_ctx, t)
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
