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

	# GRID-001: read board config from balance.json data.grid block.
	var grid_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bdata: Dictionary = balance.get("data", {})
		grid_cfg = bdata.get("grid", {})
		# COMBAT-002: store initiative modifiers so EncounterRoundsState.enter() can use them.
		var combat_cfg: Dictionary = bdata.get("combat", {})
		flow_ctx.encounter_ctx.initiative_cfg = combat_cfg.get("initiative_modifiers", {})

	# Build actors only once (when phase_snapshot is empty = first entry before machine starts).
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

		# GRID-003: deterministic seeded placement.
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

		# COMBAT-001: store placed actors and seed on ectx for snapshot rebuilds.
		var all_actors: Array = echo_actors + enemy_actors
		flow_ctx.encounter_ctx.actors = all_actors.duplicate(true)
		flow_ctx.encounter_ctx.placement_seed = placement_seed

		# GRID-003: log combat.actor.spawned — includes placement_seed for determinism audit.
		if flow_ctx.logger != null:
			for actor in all_actors:
				flow_ctx.logger.info(t, "combat.actor.spawned",
					"Actor spawned at (%d,%d)" % [actor["grid_pos"]["col"], actor["grid_pos"]["row"]],
					{ "actor_id": actor["id"], "name": actor["name"],
					  "faction": actor.get("faction", ""), "grid_pos": actor["grid_pos"],
					  "placement_seed": placement_seed })

	# COMBAT-001: always build snapshot via static builder (type always "flow.encounter").
	flow_ctx.last_snapshot = FlowEncounterState.build_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


## COMBAT-001: static snapshot builder — always emits type "flow.encounter".
## Reads ectx.actors, ectx.combat_state, ectx.placement_seed.
## COMBAT-002: also emits initiative_order + active_initiative_index from combat_state.
## Called from enter() and from FlowRuntime._handle_combat_init().
static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# Read board config.
	var grid_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bdata: Dictionary = balance.get("data", {})
		grid_cfg = bdata.get("grid", {})
	var board_cols: int = GridService.get_board_cols(grid_cfg)
	var board_rows: int = GridService.get_board_rows(grid_cfg)

	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var actors: Array = ectx.actors if ectx != null else []
	var combat_state: Dictionary = ectx.combat_state if ectx != null else {}
	var encounter_id: String = ectx.encounter_id if ectx != null else ""
	var placement_seed: int = ectx.placement_seed if ectx != null else 0

	var objective_type: String = ""
	var round: int = 0
	var initiative_order: Array = []
	var active_initiative_index: int = 0

	var actions: Dictionary = {
		"nav.back": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "← Back",
			"slot":  "nav.back",
		},
	}

	if combat_state.is_empty():
		# Pre-init: offer Start Combat.
		actions["cta.combat_init"] = {
			"type":  "combat.init",
			"label": "Start Combat",
			"slot":  "cta.combat_init",
		}
	else:
		# Post-init: COMBAT-004 — Confirm Round is now live (no longer disabled).
		objective_type = str(combat_state.get("objective", ""))
		round = int(combat_state.get("round_counter", 0))
		# COMBAT-002: include initiative order in post-init snapshot.
		initiative_order = combat_state.get("initiative_order", [])
		active_initiative_index = int(combat_state.get("active_initiative_index", 0))
		# COMBAT-004: omit cta.confirm_round when combat is over (no more rounds).
		var combat_over: bool = bool(combat_state.get("combat_over", false))
		if not combat_over:
			actions["cta.confirm_round"] = {
				"type":  "combat.confirm_round",
				"label": "Confirm Round",
				"slot":  "cta.confirm_round",
			}

	var combat_over_flag: bool = bool(combat_state.get("combat_over", false))
	return {
		"type": FlowStateIds.ENCOUNTER,
		"data": {
			"title":          "Encounter",
			"encounter_id":   encounter_id,
			"board_cols":     board_cols,
			"board_rows":     board_rows,
			"actors":                  actors,
			"placement_seed":           placement_seed,
			"objective_type":           objective_type,
			"round":                    round,
			"initiative_order":         initiative_order,
			"active_initiative_index":  active_initiative_index,
			# COMBAT-003: transient action results from the last resolved round.
			"action_results":           ectx.last_round_results.duplicate() if ectx != null else [],
			# COMBAT-004: end condition fields.
			"actors_acted":             [],
			"combat_over":              combat_over_flag,
		},
		"actions": actions,
		"meta":    { "t": t },
	}
