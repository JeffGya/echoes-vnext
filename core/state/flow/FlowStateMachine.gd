class_name FlowStateMachine

extends StateMachine

func _init() -> void:
	super("state.flow")
	
# Register the default Flow state for scaffolding.
func register_default_states() -> void:
	# registrations will be placed here.
	register_state(FlowSplashState.new())
	register_state(FlowMainMenuState.new())
	
	register_state(FlowSanctumState.new())
	register_state(FlowPartyManageState.new())
	register_state(FlowEchoManageState.new())
	register_state(FlowRealmSelectState.new())
	register_state(FlowSummonState.new())

	register_state(FlowResolveState.new())
	register_state(FlowStageMapState.new())
	register_state(FlowStageState.new())
	register_state(FlowEncounterState.new())
	
# Deterministic entry point for Flow.
func start(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	set_initial(FlowStateIds.SPLASH, ctx, logger, t)
