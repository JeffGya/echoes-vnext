class_name FlowEncounterState

extends State

func _init(id: String = FlowStateIds.ENCOUNTER) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Create encounter context once per active encounter.
	if flow_ctx.encounter_ctx == null:
		flow_ctx.encounter_ctx = EncounterContext.new()
		flow_ctx.encounter_ctx.encounter_id = flow_ctx.encounter_id
		# Prove the pipe works with a non-combat mode.
		flow_ctx.encounter_ctx.resolution_mode = EncounterResolutionModes.PURIFY_SHRINE

	# Create machine once, register states once.
	if flow_ctx.encounter_machine == null:
		flow_ctx.encounter_machine = EncounterStateMachine.new()
		flow_ctx.encounter_machine.register_default_states()

	# Pass-through the encounter phase snapshot to UI.
	flow_ctx.last_snapshot = flow_ctx.encounter_ctx.phase_snapshot
	
	# GRID-001: read board config from balance.json data.grid block.
	var grid_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bdata: Dictionary = balance.get("data", {})
		grid_cfg = bdata.get("grid", {})
	var board_cols: int = GridService.get_board_cols(grid_cfg)
	var board_rows: int = GridService.get_board_rows(grid_cfg)

	# If the encounter machine hasn't produced a phase snapshot yet, show the combat board scaffold.
	if flow_ctx.encounter_ctx.phase_snapshot.is_empty():

		# GRID-002: build echo actor list from the active party in save_data.
		var echo_actors: Array = []
		if flow_ctx.save_data.has("sanctum") and flow_ctx.save_data.has("roster"):
			var party_ids: Array = flow_ctx.save_data["sanctum"].get("active_party_ids", [])
			var roster: Array = flow_ctx.save_data["roster"]
			for echo in roster:
				if echo.get("id", "") in party_ids:
					echo_actors.append(EchoActor.from_echo(echo))
		echo_actors.sort_custom(func(a, b): return a["id"] < b["id"])

		# GRID-002: build enemy actor list (hardcoded stubs — actors.json is empty in MVP).
		var enemy_defs: Array = [
			{ "id": "enemy_guardian_01", "name": "Guardian", "level": 1, "faction": "enemy" },
			{ "id": "enemy_shadow_01",   "name": "Shadow",   "level": 1, "faction": "enemy" },
		]
		var enemy_actors: Array = []
		for defn in enemy_defs:
			enemy_actors.append(EnemyActor.from_definition(defn, t))
		enemy_actors.sort_custom(func(a, b): return a["id"] < b["id"])

		# GRID-002: assign positions — echoes on the left (col 0), enemies on the right (col cols-1).
		# Sorted by actor_id within each faction (initiative rank deferred to GRID-003+).
		var left_col := 0; var left_row := 0
		for actor in echo_actors:
			GridService.assign_grid_pos(actor, left_col, left_row)
			left_row += 1
			if left_row >= board_rows: left_row = 0; left_col += 1

		var right_col := board_cols - 1; var right_row := 0
		for actor in enemy_actors:
			GridService.assign_grid_pos(actor, right_col, right_row)
			right_row += 1
			if right_row >= board_rows: right_row = 0; right_col -= 1

		# GRID-002: log combat.actor.spawned for every actor with their assigned grid_pos.
		var all_actors: Array = echo_actors + enemy_actors
		if flow_ctx.logger != null:
			for actor in all_actors:
				flow_ctx.logger.info(t, "combat.actor.spawned",
					"Actor spawned at (%d,%d)" % [actor["grid_pos"]["col"], actor["grid_pos"]["row"]],
					{ "actor_id": actor["id"], "name": actor["name"],
					  "faction": actor.get("faction", ""), "grid_pos": actor["grid_pos"] })

		flow_ctx.last_snapshot = {
			"type": FlowStateIds.ENCOUNTER,
			"data": {
				"title": "Encounter",
				"encounter_id": flow_ctx.encounter_ctx.encounter_id,
				"resolution_mode": flow_ctx.encounter_ctx.resolution_mode,
				# GRID-001: board dimensions for CombatBoardScreen renderer
				"board_cols": board_cols,
				"board_rows": board_rows,
				# GRID-002: spawned actor list for token rendering
				"actors": all_actors,
			},
			"actions": {
				"nav.back": {
					"type": "flow.go_state",
					"to": FlowStateIds.SANCTUM,
					"label": "← Back",
					"slot": "nav.back",
				},
			},
			"meta": { "t": t }
		}
		return

	flow_ctx.last_snapshot = flow_ctx.encounter_ctx.phase_snapshot
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
