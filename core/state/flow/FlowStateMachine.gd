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
	# FlowEncounterState.enter() builds the full combat board snapshot: board config,
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

	# ECONOMY-001 Subtask 5: surface balances in Sanctum snapshot data (snapshot-only UI contract)
	if str(snap.get("type", "")) == FlowStateIds.SANCTUM:
		# Ensure snap.data is a dictionary we can safely augment
		if not snap.has("data") or typeof(snap["data"]) != TYPE_DICTIONARY:
			snap["data"] = {}

		var data: Dictionary = snap["data"]

		# Read from save data only (authoritative), normalize int/float safely
		var econ: Dictionary = {}
		if ctx.save_data != null and ctx.save_data.has("economy") and typeof(ctx.save_data["economy"]) == TYPE_DICTIONARY:
			econ = ctx.save_data["economy"]
		var sanctum: Dictionary = {}
		if ctx.save_data != null and ctx.save_data.has("sanctum") and typeof(ctx.save_data["sanctum"]) == TYPE_DICTIONARY:
			sanctum = ctx.save_data["sanctum"]
			
		# SANCTUM-001: Ase rate hint (NOT a balance prediction)
		# Used only for UI text like: "~ 1.2 Ase gathered p/h"
		var ase_per_min_base := 0.0
		var multiplier := 1.0 # seam for later emotion metrics

		if ctx.config_service != null:
			var balance: Dictionary = ctx.config_service.get_balance()
			if balance.has("data") and typeof(balance["data"]) == TYPE_DICTIONARY:
				var bal_data: Dictionary = balance["data"]
				if bal_data.has("economy") and typeof(bal_data["economy"]) == TYPE_DICTIONARY:
					var econ_cfg: Dictionary = bal_data["economy"]
					ase_per_min_base = float(econ_cfg.get("ase_online_per_min_base", 0.0))


		data["ase_balance"] = int(econ.get("ase", 0))
		data["ekwan_balance"] = int(econ.get("ekwan", 0))
		var flame_v: Variant = sanctum.get("ase_flame", {})
		var flame: Dictionary = flame_v if flame_v is Dictionary else {}
		if not bool(flame.get("awakened", false)):
			ase_per_min_base = 0.0
		# per_hour = per_min * 60
		data["ase_rate_per_hour_hint"] = ase_per_min_base * 60.0 * multiplier
		data["ase_flame"] = flame.duplicate(true)
		data["ase_rate_per_hour"] = ase_per_min_base * 60.0 * multiplier

		# V2-ECONOMY-001: Ase Flame awakened flag + awakening overlay (one-shot consume)
		data["ase_flame_awakened"] = bool(flame.get("awakened", false))

		# Consume pending_awakening_banner — true once, then cleared.
		var _show_overlay := false
		if ctx is FlowContext and (ctx as FlowContext).pending_awakening_banner:
			_show_overlay = true
			(ctx as FlowContext).pending_awakening_banner = false
		data["show_awakening_overlay"] = _show_overlay

		# Awakening grant amount for overlay label (read from balance config).
		var _aw_grant := 40
		if ctx.config_service != null:
			var _aw_bal: Dictionary = ctx.config_service.get_balance()
			var _aw_data_v: Variant = _aw_bal.get("data", {})
			var _aw_data: Dictionary = _aw_data_v if _aw_data_v is Dictionary else {}
			var _aw_econ_v: Variant = _aw_data.get("economy", {})
			var _aw_econ: Dictionary = _aw_econ_v if _aw_econ_v is Dictionary else {}
			_aw_grant = int(_aw_econ.get("awakening_ase_grant", 40))
		data["awakening_grant"] = _aw_grant

		# ECONOMY-005: one-shot return notification (VOW-002 path).
		# Always erase first so stale data from previous emissions does not re-fire.
		data.erase("return_notification")
		if ctx is FlowContext and not (ctx as FlowContext).pending_return_notification.is_empty():
			data["return_notification"] = (ctx as FlowContext).pending_return_notification.duplicate(true)
			(ctx as FlowContext).pending_return_notification = {}
		
		
		# SANCTUM-001: surface sanctum hub info (snapshot-only UI contract)
		var roster: Array = []
		if sanctum.has("roster") and sanctum["roster"] is Array:
			roster = sanctum["roster"]
			
		var active_party_ids: Array = []
		if sanctum.has("active_party_ids") and sanctum["active_party_ids"] is Array:
			active_party_ids = sanctum["active_party_ids"]
		
		# Sanctum name
		if ctx.save_data != null and ctx.save_data.has("sanctum") and typeof(ctx.save_data["sanctum"]) == TYPE_DICTIONARY:
			sanctum = ctx.save_data["sanctum"]
			
		var sanctum_name := str(sanctum.get("name", ""))
		var roll_index := int(sanctum.get("name_roll_index", 0))
		
		# Deterministic suggestion (even if already named, harmless)
		var root_seed := int(ctx.save_data.get("campaign", {}).get("root_seed", 0))
		var seed := CampaignSeed.new(root_seed)
		data["sanctum_name_suggested"] = SanctumNameService.suggest(seed, roll_index)


		data["sanctum_name"] = sanctum_name
		data["roster_count"] = roster.size()
		data["active_party_count"] = active_party_ids.size()

		# SANCTUM-003 Subtask 4: party_slots projection (player-facing only, no IDs)
		var party_slots: Array = []
		for pid_v in active_party_ids:
			var pid := str(pid_v)
			if pid.is_empty():
				continue
			for echo_v in roster:
				if not (echo_v is Dictionary):
					continue
				var echo: Dictionary = echo_v
				if str(echo.get("id", "")) == pid:
					var _emo_p: Dictionary = echo.get("emotion", {})
					party_slots.append({
						"name":             str(echo.get("name", "")),
						"step":             int(echo.get("level", 1)),
						"standing":         int(echo.get("rank", 1)),
						# V2-EMOTION-002: unified emotional status.
						"emotional_status": EmotionService.get_emotional_status(
							int(_emo_p.get("morale_current", 50)),
							int(_emo_p.get("fear_current", 0))
						),
					})
					break
		data["party_slots"] = party_slots

		# Optional: include these only if you want the UI to list them later (out of scope for MVP. Possibly later we can use set parties that can be prepared before.)
		# data["active_party_ids"] = active_party_ids

		# DIRECTIVE-001: surface active directive in Sanctum snapshot (debug/snapshot visibility)
		# DIRECTIVE-002 will replace the static available_directives list with a dynamic call.
		var stage_ctx_dir: Dictionary = {}
		if ctx.save_data != null and ctx.save_data.has("stage_context") \
				and typeof(ctx.save_data["stage_context"]) == TYPE_DICTIONARY:
			stage_ctx_dir = ctx.save_data["stage_context"]
		data["active_directive_id"] = str(stage_ctx_dir.get("active_directive_id", "directive.scout_carefully"))
		data["available_directives"] = ["directive.scout_carefully", "directive.seek_signs"]

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
