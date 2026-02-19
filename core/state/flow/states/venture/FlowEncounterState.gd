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
	
	# If the encounter machine hasn't produced a phase snapshot yet, show a tiny scaffold.
	if flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		flow_ctx.last_snapshot = {
			"type": FlowStateIds.ENCOUNTER,
			"data": {
				"title": "Encounter",
				"encounter_id": flow_ctx.encounter_ctx.encounter_id,
				"resolution_mode": flow_ctx.encounter_ctx.resolution_mode,
				"note": "Encounter initializing (waiting for AppRoot to start machine)."
			},
			"actions": [],
			"meta": { "t": t }
		}
		return

	flow_ctx.last_snapshot = flow_ctx.encounter_ctx.phase_snapshot
	
func exit(ctx: RefCounted, t: int) -> void:
	pass
