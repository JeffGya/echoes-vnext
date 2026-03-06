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
				"meta": { "t": t },
				"data": ctx.encounter_ctx.phase_snapshot
			}
		else:
			# Deterministic bootstrap gap: Flow has entered flow.encounter but the Encounter machine
			# has not produced its first phase snapshot yet. Emit a valid, non-null pending wrapper.
			snap = {
				"type": FlowStateIds.ENCOUNTER,
				"meta": { "t": t },
				"data": {
					"type": "encounter.pending",
					"meta": { "t": t },
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
		# per_hour = per_min * 60
		data["ase_rate_per_hour_hint"] = ase_per_min_base * 60.0 * multiplier
		
		
		# SANCTUM-001: surface sanctum hub info (snapshot-only UI contract)
		var sanctum: Dictionary = {}
		if ctx.save_data != null and ctx.save_data.has("sanctum") and typeof(ctx.save_data["sanctum"]) == TYPE_DICTIONARY:
			sanctum = ctx.save_data["sanctum"]
			
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
					party_slots.append({
						"name": str(echo.get("name", "")),
						"level": int(echo.get("level", 1)),
						"rank": int(echo.get("rank", 1))
					})
					break
		data["party_slots"] = party_slots

		# Optional: include these only if you want the UI to list them later (out of scope for MVP. Possibly later we can use set parties that can be prepared before.)
		# data["active_party_ids"] = active_party_ids

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
