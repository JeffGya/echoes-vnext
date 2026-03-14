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
		if flow_ctx.save_data.has("sanctum"):
			var party_ids: Array = flow_ctx.save_data["sanctum"].get("active_party_ids", [])
			var roster: Array = flow_ctx.save_data["sanctum"].get("roster", [])
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

		# GRID-003: deterministic seeded placement — replaces the GRID-002 manual loops.
		# Placement score = floor((agi + speed) / 2) + archetype_mod + calling_mod
		#                   + trait_mod + vector_mod (all read fresh at combat start).
		# All modifier tables live in balance.json data.grid.placement_modifiers.
		var place_cfg: Dictionary = grid_cfg.get("placement_modifiers", {})
		var placement_seed: int = 0
		var rng := RandomNumberGenerator.new()
		if flow_ctx.campaign_seed != null:
			placement_seed = flow_ctx.campaign_seed.derive(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
			rng = flow_ctx.campaign_seed.get_rng(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
		else:
			rng.seed = hash(flow_ctx.encounter_ctx.encounter_id)

		GridService.place_actors(echo_actors, enemy_actors, grid_cfg, rng, place_cfg)

		# GRID-003: log combat.actor.spawned — includes placement_seed for determinism audit.
		var all_actors: Array = echo_actors + enemy_actors
		if flow_ctx.logger != null:
			for actor in all_actors:
				flow_ctx.logger.info(t, "combat.actor.spawned",
					"Actor spawned at (%d,%d)" % [actor["grid_pos"]["col"], actor["grid_pos"]["row"]],
					{ "actor_id": actor["id"], "name": actor["name"],
					  "faction": actor.get("faction", ""), "grid_pos": actor["grid_pos"],
					  "placement_seed": placement_seed })

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
				# GRID-003: placement seed for determinism audit
				"placement_seed": placement_seed,
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
