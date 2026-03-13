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
		flow_ctx.last_snapshot = {
			"type": FlowStateIds.ENCOUNTER,
			"data": {
				"title": "Encounter",
				"encounter_id": flow_ctx.encounter_ctx.encounter_id,
				"resolution_mode": flow_ctx.encounter_ctx.resolution_mode,
				# GRID-001: board dimensions for CombatBoardScreen renderer
				"board_cols": board_cols,
				"board_rows": board_rows,
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
