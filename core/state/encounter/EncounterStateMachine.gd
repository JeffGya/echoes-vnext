class_name EncounterStateMachine

extends StateMachine

func _init() -> void:
	super("state.encounter")
	
func register_default_states() -> void:
	# NOTE: Phase state classes will be created in Subtask 4
	# Keep registration centralized here similar to Flow.
	register_state(EncounterSetupState.new())
	register_state(EncounterBlessingState.new())
	register_state(EncounterRoundsState.new())
	register_state(EncounterResolutionState.new())
	register_state(EncounterAftermathState.new())
	
func start(ctx: EncounterContext, logger: StructuredLogger, t: int) -> void:
	# Start at first phase.
	set_initial(EncounterStateIds.SETUP, ctx, logger, t)
