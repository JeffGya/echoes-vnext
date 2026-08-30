class_name FlowStateMachine

extends StateMachine

const FlowWeavingRiteStateScript  := preload("res://core/state/flow/states/sanctum/FlowWeavingRiteState.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")  # V2-STAGE-001
const FlowOnboardingStateScript := preload("res://core/state/flow/states/onboarding/FlowOnboardingState.gd")
const FlowKeeperIntroStateScript := preload("res://core/state/flow/states/onboarding/FlowKeeperIntroState.gd")
const KeeperIntroServiceScript := preload("res://core/onboarding/KeeperIntroService.gd")

func _init() -> void:
	super("state.flow")
	
# Register the default Flow state for scaffolding.
func register_default_states() -> void:
	# registrations will be placed here.
	register_state(FlowSplashState.new())
	register_state(FlowMainMenuState.new())
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_INVOCATION, OnboardingService.STEP_INVOCATION))
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_ANANSI, OnboardingService.STEP_ANANSI))
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_CHOOSE_NAME, OnboardingService.STEP_CHOOSE_NAME))
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_MEETING, OnboardingService.STEP_MEETING))
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_EMPTY_SANCTUM, OnboardingService.STEP_EMPTY_SANCTUM))
	register_state(FlowOnboardingStateScript.new(FlowStateIds.ONBOARDING_NAME_SANCTUM, OnboardingService.STEP_NAME_SANCTUM))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_CALL, KeeperIntroServiceScript.STEP_CALL))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_TRIAL, KeeperIntroServiceScript.STEP_TRIAL))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_REWIND, KeeperIntroServiceScript.STEP_REWIND))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_THREAD_RETURN, KeeperIntroServiceScript.STEP_THREAD_RETURN))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_AWAKENING, KeeperIntroServiceScript.STEP_AWAKENING))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_WEAVING, KeeperIntroServiceScript.STEP_WEAVING))
	register_state(FlowKeeperIntroStateScript.new(FlowStateIds.KEEPER_KEEPING, KeeperIntroServiceScript.STEP_KEEPING))
	
	register_state(FlowSanctumState.new())
	register_state(FlowEchoPartyState.new())
	register_state(FlowRealmSelectState.new())
	register_state(FlowSummonState.new())
	register_state(FlowVowState.new())  # VOW-001
	register_state(FlowWeavingRiteStateScript.new())  # V2-WEAVE-002

	register_state(FlowResolveState.new())
	register_state(FlowStageMapState.new())
	register_state(FlowStageState.new())
	register_state(FlowStageExploreStateScript.new())  # V2-STAGE-001
	register_state(FlowEncounterState.new())
	
# Deterministic entry point for Flow.
func start(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	ctx.flow_machine = self
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


# Re-runs the current state's enter() without a state transition.
# Used when save_data changes mid-state and the full snapshot needs a complete rebuild
# (e.g. after sanctum.institution.establish updates layout + occupants).
func reenter(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	if _current_state != null:
		_current_state.enter(ctx, t)

# A set of helpers
func _rebuild_snapshot(ctx: FlowContext, logger: StructuredLogger, t: int) -> void:
	var snap: Dictionary = {}

	# GRID-002: ENCOUNTER uses ctx.last_snapshot (same contract as all flow states).
	# FlowEncounterState.enter() delegates to EncounterSetupService.setup(), which builds the full combat board: board config,
	# actor list, and nav actions. The encounter_ctx.phase_snapshot passthrough will be
	# restored by a COMBAT story once EncounterStateMachine produces round snapshots.
	if _current_state_id != FlowStateIds.ENCOUNTER and _current_state == null:
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

	# V2-INFRA-003 Phase 3: the Sanctum-only enrichment block that used to live here has moved
	# into SanctumSnapshotBuilder.build(), called from FlowSanctumState.enter(). This function
	# is now fully generic across all flow states: read ctx.last_snapshot, validate, store.
	# No state-specific branch remains.

	# Enforce snapshot contract (STATE-004 Subtask 5)
	_validate_snapshot(snap, logger, t)

	ctx.last_snapshot = snap	

	

func _validate_snapshot(snap: Dictionary, logger: StructuredLogger, t: int) -> void:
	if snap.is_empty():
		logger.debug(t, "snapshot.invalid", "Snapshot is empty", {})
		assert(false)
		return

	if not snap.has("type") or not snap.has("meta") or not snap.has("data") or not snap.has("actions"):
		logger.debug(
			t,
			"snapshot.invalid",
			"Snapshot missing required keys",
			{ "keys": snap.keys() }
		)
		assert(false)
		return

	if typeof(snap.get("actions")) != TYPE_DICTIONARY:
		logger.debug(
			t,
			"snapshot.invalid",
			"Snapshot actions is not a Dictionary",
			{ "type": str(snap["type"]), "actions_type": typeof(snap.get("actions")) }
		)
		assert(false)
		return

	var snap_meta: Variant = snap.get("meta")
	if typeof(snap_meta) != TYPE_DICTIONARY or not (snap_meta as Dictionary).has("t"):
		logger.debug(
			t,
			"snapshot.invalid",
			"Snapshot meta is not a Dictionary containing 't'",
			{ "type": str(snap["type"]), "meta": snap_meta }
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
