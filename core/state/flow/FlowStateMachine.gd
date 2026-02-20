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
	_rebuild_snapshot(ctx, logger, t)

# Every succesful Flow transition guarantees a snapshot
func transition(to_state_id: String, ctx: RefCounted, logger: StructuredLogger, t: int, reason: String = "") -> bool:
	var ok := super.transition(to_state_id, ctx, logger, t, reason)
	if ok:
		_rebuild_snapshot(ctx as FlowContext, logger, t)
	return ok
	
func refresh_snapshot(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	_rebuild_snapshot(ctx, logger, t)
	
# A set of helpers
func _rebuild_snapshot(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	var snap: Dictionary = {}

	# Encounter passthrough wrapper (STATE-004 Subtask 3, Option 1)
	if _current_state_id == FlowStateIds.ENCOUNTER:
		if ctx.encounter_ctx != null and not ctx.encounter_ctx.phase_snapshot.is_empty():
			snap = {
				"type": FlowStateIds.ENCOUNTER,
				"meta": { "tick": t },
				"data": ctx.encounter_ctx.phase_snapshot
			}
		else:
			# Deterministic bootstrap gap: Flow has entered flow.encounter but the Encounter machine
			# has not produced its first phase snapshot yet. Emit a valid, non-null pending wrapper.
			snap = {
				"type": FlowStateIds.ENCOUNTER,
				"meta": { "tick": t },
				"data": {
					"type": "encounter.pending",
					"meta": { "tick": t },
					"data": {
						"flow_state": _current_state_id
					}
				}
			}
	else:
		# Normal flow state snapshot
		if _current_state == null:
			logger.debug(
				t,
				"snapshot.invalid",
				"Flow current state is null",
				{ "flow_state": _current_state_id }
			)
			assert(false)
			return

		snap = ctx.last_snapshot
		if str(snap.get("type", "")) != _current_state_id:
			logger.debug(
				t,
				"snapshot.mismatch",
				"Snapshot type does not match current flow state",
				{ "flow_state": _current_state_id, "snapshot_type": str(snap.get("type", "")) }
			)
			# For MVP we don't assert; just flag it.
			
	# Enforce snapshot contract (STATE-004 Subtask 5)
	_validate_snapshot(snap, logger, t)

	ctx.last_snapshot = snap
	
func _validate_snapshot(snap: Dictionary, logger: StructuredLogger, t: int) -> void:
	if snap.is_empty():
		logger.debug(t, "snapshot.invalid", "Snapshot is empty", {})
		assert(false)
		return

	if not snap.has("type") or not snap.has("meta") or not snap.has("data"):
		logger.debug(
			t,
			"snapshot.invalid",
			"Snapshot missing required keys",
			{ "keys": snap.keys() }
		)
		assert(false)
		return

	if _contains_null(snap):
		logger.debug(t, "snapshot.invalid", "Snapshot contains null value(s)", {})
		assert(false)
		return

func _contains_null(v: Variant) -> bool:
	if v == null:
		return true

	if v is Array:
		for item in v:
			if _contains_null(item):
				return true
		return false

	if v is Dictionary:
		for k in v.keys():
			if _contains_null(v[k]):
				return true
		return false

	return false
