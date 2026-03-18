# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

var logger: StructuredLogger
var config_service: ConfigService
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine
var econ: EconomyService
var directive_service: DirectiveService  # DIRECTIVE-001

func _init(_logger: StructuredLogger, _config_service: ConfigService) -> void:
	logger = _logger
	config_service = _config_service

func _next_tick() -> int:
	var t := flow_ctx.sim_tick
	flow_ctx.sim_tick += 1
	return t

func boot() -> Dictionary:
	# Flow owned ticks should start counting.
	flow_ctx = FlowContext.new()
	flow_ctx.sim_tick = 0
	flow_ctx.config_service = config_service
	flow_ctx.logger = logger  # GRID-002: allows flow states to log without changing State.enter() signature

	logger.debug(_next_tick(), "boot.start", "Boot sequence started", {})

	# Load configs
	var ok_balance := config_service.load_balance(logger, _next_tick())
	var ok_actors := config_service.load_actors(logger, _next_tick())
	var ok_realms := config_service.load_realms(logger, _next_tick())

	if not (ok_balance and ok_actors and ok_realms):
		logger.log_state_transition(_next_tick(), "boot", "error", "config_invalid")
		var snap := {
			"type": "error",
			"meta": { "tick": flow_ctx.sim_tick },
			"data": { "message": "Configuration validation failed. See logs." }
		}
		_log_snapshot_emitted(flow_ctx.sim_tick, snap, "boot.error")
		flow_ctx.last_snapshot = snap
		return snap

	# Save load/create
	var save := SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH, logger, _next_tick())
	if save.is_empty():
		save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, save, logger, _next_tick())

	flow_ctx.save_data = save
	econ = EconomyService.new(flow_ctx.save_data)
	directive_service = DirectiveService.new(flow_ctx.save_data)  # DIRECTIVE-001

	# Flow state machine
	flow_machine = FlowStateMachine.new()
	flow_machine.register_default_states()
	flow_machine.start(flow_ctx, logger, _next_tick())

	# Flow should have placed last_snapshot already
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(flow_ctx.sim_tick, out, "boot.complete")
	return out

func dispatch(action: Dictionary) -> Dictionary:
	var t := _next_tick()
	var action_type := str(action.get("type", ""))

	match action_type:
		
		# ---- Flow ----
		"flow.new_game":
			_handle_new_game(t)
			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.new_game")
			
		"flow.advance":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.advance")

		"flow.go_state":
			var to_state := str(action.get("to", ""))
			# EMOTION-002: sanctum recovery tick applies before snapshot rebuild
			if to_state == FlowStateIds.SANCTUM:
				_apply_sanctum_emotion_tick(t)
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")

		"flow.select_realm":
			var realm_id := str(action.get("realm_id", ""))
			flow_ctx.realm_id = realm_id
			flow_ctx.save_request = true
			flow_ctx.save_request_reason = "realm_select"
			flow_machine.transition(FlowStateIds.STAGE, flow_ctx, logger, t, "ui.flow.select_stage")

		"flow.continue":
			var is_first_boot: bool = bool(flow_ctx.save_data.get("first_boot", true))
			if is_first_boot:
				flow_ctx.save_data["first_boot"] = false
				flow_ctx.save_request = true
				flow_ctx.save_request_reason = "continue_first_boot"

			_apply_offline_accrual_if_needed(t, "flow.continue")

			# PROG-001: patch old echo dicts that pre-date draw-order v2 fields
			_repair_echo_schema(t)

			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")

		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})

		# ---- Debug Seed (SANCTUM-002) ----
		"debug.seed.show":
			_handle_debug_seed_show(t)

		"debug.seed.set":
			_handle_debug_seed_set(action, t, false)

		"debug.seed.reset":
			_handle_debug_seed_set(action, t, true)
			
		# ---- Debug Echo (SANCTUM-002) ----
		"debug.echo.gen_test":
			_handle_debug_echo_gen_test(t)

		# ---- Combat ----
		"combat.init":
			_handle_combat_init(t)

		# COMBAT-004: starts a new round, resolves the first actor, emits a per-actor snapshot.
		"combat.confirm_round":
			_handle_combat_confirm_round(t)

		# COMBAT-SEQ: advances to the next actor in initiative order; emits a per-actor snapshot.
		"combat.next_actor":
			_handle_combat_next_actor(t)

		# ---- Encounter ----
		"encounter.advance":
			var to_state := str(action.get("to", ""))
			if flow_ctx.encounter_machine == null or flow_ctx.encounter_ctx == null:
				logger.debug(t, "ui.encounter.advance", "Encounter not initialized", { "action": action })
			else:
				flow_ctx.encounter_machine.transition(to_state, flow_ctx.encounter_ctx, logger, t, "ui.encounter.advance")
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"encounter.complete":
			# EMOTION-002: apply win/loss drift to all roster echoes before clearing encounter
			var enc_outcome := str(action.get("outcome", "loss"))
			_apply_encounter_emotion_drift(enc_outcome, t)
			flow_ctx.encounter_ctx = null
			flow_ctx.encounter_machine = null
			flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.encounter.complete")

		# ---- Economy ----
		"economy.settle_time":
			_handle_economy_settle_time(action, t)
			
		"economy.ase.add":
			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.add"))
			econ.add_ase(amount, reason, logger, t)
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"economy.ase.spend":
			# settle first (same as you do in debug.before_spend)
			var now_unix := int(action.get("now_unix", 0))
			if now_unix > 0:
				_handle_economy_settle_time({ "type":"economy.settle_time", "now_unix": now_unix, "source": "debug.before_spend" }, t)

			var amount := int(action.get("amount", 0))
			var reason := str(action.get("reason", "economy.ase.spend"))
			econ.spend_ase(amount, reason, logger, t)
			# include ok in snapshot? not needed now; debug prints it
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		# ---- Sanctum ----
		"sanctum.name.reroll":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
			var idx := int(sanctum.get("name_roll_index", 0)) + 1
			sanctum["name_roll_index"] = idx

			# No save request on reroll (no save spam)
			logger.debug(t, "sanctum.name.reroll", "Rerolled sanctum name suggestion", {
				"roll_index": idx
			})

			# IMPORTANT: no transition occurs, so we must refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		"sanctum.name.confirm":
			if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
				flow_ctx.save_data["sanctum"] = {}

			var sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary

			var raw := str(action.get("name", ""))
			var name := raw.strip_edges()

			# MVP sanitize rules (deterministic, no OS time)
			if name.length() < 2:
				name = "Sanctum"
			if name.length() > 24:
				name = name.substr(0, 24)

			sanctum["name"] = name

			# Request a save flush (Flow-owned choke point will do it once)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason != "":
				flow_ctx.save_request_reason += "|sanctum.name.confirm"
			else:
				flow_ctx.save_request_reason = "sanctum.name.confirm"

			logger.info(t, "sanctum.name.confirm", "Sanctum name set", {
				"name": name
			})
			
		"sanctum.summon":
			_handle_sanctum_summon(action, t)

		"sanctum.grade_select":
			_handle_sanctum_grade_select(action, t)

		"sanctum.party.toggle":
			_handle_sanctum_party_toggle(action, t)
			
		"sanctum.party.confirm":
			_handle_sanctum_party_confirm(t)

		# ---- Directives (DIRECTIVE-001) ----
		"directive.select":
			_handle_directive_select(action, t)

		# UI actions
		"ui.dismiss_summon_reveals":
			flow_ctx.pending_summon_reveals.clear()
			logger.debug(t, "ui.dismiss_summon_reveals", "Dismissed summon reveal queue", {
				"remaining": flow_ctx.pending_summon_reveals.size()
			})
			flow_machine.refresh_snapshot(flow_ctx, logger, t)

			# IMPORTANT: no transition occurs, so refresh snapshot
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
		
		_:
			logger.debug(t, "ui.action.unknown", "Unknown action type", { "action": action })

	# If we just entered flow.encounter, bootstrap the Encounter machine.
	_ensure_encounter_started(t)

	# Flow-owned save choke point (single save max per dispatch tick)
	if flow_ctx.save_request:
		var reason := str(flow_ctx.save_request_reason)
		var ok := SaveService.save_to_file(
			SaveSchema.DEFAULT_SAVE_PATH,
			flow_ctx.save_data,
			logger,
			t
		)

		logger.debug(t, "save.flush", "Save flush executed", {
			"ok": ok,
			"reason": reason
		})

		# Always clear request so we don't spam saves on repeated dispatch
		flow_ctx.save_request = false
		flow_ctx.save_request_reason = ""

	# IMPORTANT: Subtask 2 will keep behavior identical:
	# return whatever Flow decided is current
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(t, out, "dispatch")
	return out

# Helper section for the flow actions
func _handle_sanctum_summon(action: Dictionary, t: int) -> void:
	# 0) parse count
	var count := int(action.get("count", 1))
	if count < 1:
		count = 1
	if count > 10:
		count = 10

	# 1) settle before spend
	var now_unix := int(action.get("now_unix", 0))
	if now_unix > 0:
		_handle_economy_settle_time({
			"type": "economy.settle_time",
			"now_unix": now_unix,
			"source": "sanctum.summon.before_spend"
		}, t)

	# 2) read cost (grade-based; fall back to flat key if grade missing)
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	var fallback_flat_cost := int(summ_cfg.get("ase_cost_per_summon", 60))
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}
	var grade := flow_ctx.selected_summon_grade
	var cost_each := int(grade_costs.get(grade, fallback_flat_cost))

	var total_cost := cost_each * count

	# 3) check funds
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_before := int(econ_data.get("ase", 0))

	if ase_before < total_cost:
		logger.info(t, "sanctum.summon.denied", "Not enough Ase to summon", {
			"ase": ase_before,
			"grade": grade,
			"cost_each": cost_each,
			"count": count,
			"total_cost": total_cost
		})
		return

	# 4) spend once
	var spend_reason := "summon.cost." + grade
	var ok_spend: bool = econ.spend_ase(total_cost, spend_reason, logger, t)
	if not ok_spend:
		logger.info(t, "sanctum.summon.denied", "Spend failed", {
			"ase": ase_before,
			"grade": grade,
			"total_cost": total_cost,
			"count": count
		})
		return

	# 5) generate + persist many
	var camp: Dictionary = {}
	if flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]
	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "sanctum.summon.denied", "Missing campaign seed_root", {})
		return

	var result := SummonService.summon_paid_many(flow_ctx.save_data, seed_root, summ_cfg, count, logger, t)

	if bool(result.get("ok", false)):
		# Append newly summoned echoes to transient reveal queue (NOT saved)
		var echoes_v: Variant = result.get("echoes", [])
		var echoes: Array = echoes_v if echoes_v is Array else []
		# PROG-005: extract vector config once for the loop (data dict is already resolved above)
		var vec_cfg_v: Variant = data.get("vectors", {})
		var vec_cfg: Dictionary = vec_cfg_v if vec_cfg_v is Dictionary else {}
		for e_v in echoes:
			if e_v is Dictionary:
				# EMOTION-001: initialise emotion block before the echo enters reveals/roster
				EmotionService.init_echo(e_v, logger, t)
				# PROG-005: initialise vector scores from archetype_init config
				VectorService.init_vectors(e_v, vec_cfg, logger, t)
				flow_ctx.pending_summon_reveals.append(e_v)

		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "sanctum.summon"

		# Rebuild snapshot so SummonScreen immediately reflects the updated Ase balance
		# and the pending_summon_reveals queue (reveal overlay). Without this, the screen
		# stays stale and repeated clicks each trigger a real summon — the root cause of
		# echoes accumulating silently across sessions.
		# Same static build_snapshot() pattern used by _handle_sanctum_grade_select.
		flow_ctx.last_snapshot = FlowSummonState.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _handle_sanctum_grade_select(action: Dictionary, t: int) -> void:
	var grade := str(action.get("grade", "")).strip_edges()
	if grade.is_empty():
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (empty grade)", {})
		return

	# Validate grade against the cost table in balance.json
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}
	var grade_costs_v: Variant = summ_cfg.get("ase_cost_per_summon_by_grade", {})
	var grade_costs: Dictionary = grade_costs_v if grade_costs_v is Dictionary else {}

	if not grade_costs.has(grade):
		logger.debug(t, "economy.summon.grade_select.denied", "Grade select denied (invalid grade key)", {
			"grade": grade,
			"valid_grades": grade_costs.keys()
		})
		return

	flow_ctx.selected_summon_grade = grade

	var ase_cost := int(grade_costs.get(grade, 60))
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	var econ_data: Dictionary = econ_v if econ_v is Dictionary else {}
	var ase_balance := int(econ_data.get("ase", 0))

	logger.debug(t, "economy.summon.grade_select", "Summon grade selected", {
		"grade": grade,
		"ase_cost": ase_cost,
		"can_afford": ase_balance >= ase_cost,
	})

	# Rebuild snapshot mid-state (refresh_snapshot reads ctx.last_snapshot as-is for SUMMON)
	flow_ctx.last_snapshot = FlowSummonState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _handle_new_game(t: int) -> void:
	# Create a new campaign root seed string (random once; then persisted)
	var seed_root := _generate_seed_root_string()
	var legacy_root_seed := _legacy_root_seed_from_seed_root(seed_root)

	# Replace current save with a fresh one
	var save := SaveService.make_new_save(legacy_root_seed)

	# Canonical campaign seed fields (SANCTUM-002)
	if not save.has("campaign") or typeof(save["campaign"]) != TYPE_DICTIONARY:
		save["campaign"] = {}
	var camp: Dictionary = save["campaign"]
	camp["seed_root"] = seed_root
	camp["seed_source"] = "random"

	# This is a brand-new run (menu first boot should not persist)
	save["first_boot"] = false

	# Ensure sanctum dict exists
	if not save.has("sanctum") or typeof(save["sanctum"]) != TYPE_DICTIONARY:
		save["sanctum"] = {}
	var sanctum: Dictionary = save["sanctum"]
	
	if not sanctum.has("roster") or typeof(sanctum["roster"]) != TYPE_ARRAY:
		sanctum["roster"] = []

	var roster: Array = sanctum["roster"] as Array
	
	# Deterministic starter Echo (no placeholder)
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v: Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	var seed_path := "campaign.starter.0"

	# NOTE: EchoFactory leaves "id" blank on purpose (id is assigned by caller)
	var echo: Dictionary = EchoFactory.generate(
		seed_root,
		seed_path,
		0,
		"starter",
		summ_cfg
	)

	# Assign stable id outside factory (does NOT affect determinism)
	var echo_id := "echo_%04d" % (roster.size() + 1)
	echo["id"] = echo_id

	# EMOTION-001: initialise emotion block before the echo enters the roster
	EmotionService.init_echo(echo, logger, t)
	# PROG-005: initialise vector scores from archetype_init config
	var vec_cfg_ng_v: Variant = data.get("vectors", {})
	var vec_cfg_ng: Dictionary = vec_cfg_ng_v if vec_cfg_ng_v is Dictionary else {}
	VectorService.init_vectors(echo, vec_cfg_ng, logger, t)

	roster.append(echo)
	sanctum["starter_granted"] = true

	logger.info(t, "sanctum.starter.grant", "Starter Echo granted", {
		"echo_id": echo_id,
		"seed_path": seed_path,
		"seed_root": seed_root
	})

	# Install save into runtime + rebuild economy service
	flow_ctx.save_data = save
	econ = EconomyService.new(flow_ctx.save_data)
	directive_service = DirectiveService.new(flow_ctx.save_data)  # DIRECTIVE-001

	# Request save flush via Flow-owned choke point
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|flow.new_game"
	else:
		flow_ctx.save_request_reason = "flow.new_game"

	# IMPORTANT: no transition has occurred yet when this runs, so refresh snapshot after mutation
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# Helpers
func _handle_debug_seed_show(t: int) -> void:
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", ""))
	var seed_source := str(camp.get("seed_source", ""))
	var root_seed := int(camp.get("root_seed", 0))

	logger.info(t, "debug.seed.show", "Seed show", {
		"seed_root": seed_root,
		"seed_source": seed_source,
		"root_seed": root_seed
	})

	# Refresh is optional, but harmless and keeps UI consistent if you display seed-derived hints.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_debug_seed_set(action: Dictionary, t: int, do_reset: bool) -> void:
	var seed_root := str(action.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.seed.denied", "Denied seed set/reset (empty seed_root)", {})
		return

	# Ensure campaign dict exists
	if not flow_ctx.save_data.has("campaign") or typeof(flow_ctx.save_data["campaign"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]

	# Update canonical seed fields
	camp["seed_root"] = seed_root
	camp["seed_source"] = "debug"

	# Keep legacy root_seed in sync for current systems (e.g., sanctum name suggestion)
	camp["root_seed"] = _legacy_root_seed_from_seed_root(seed_root)

	# Reset sanctum data if requested
	if do_reset:
		if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
			flow_ctx.save_data["sanctum"] = {}
		var sanctum: Dictionary = flow_ctx.save_data["sanctum"]

		# Reset everything test-relevant
		sanctum["name"] = ""
		sanctum["name_roll_index"] = 0
		sanctum["roster"] = []
		sanctum["active_party_ids"] = []
		sanctum["summon_count"] = 0
		sanctum["starter_granted"] = false

		logger.info(t, "debug.seed.reset", "Seed reset applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})
	else:
		logger.info(t, "debug.seed.set", "Seed set applied", {
			"seed_root": seed_root,
			"root_seed": int(camp.get("root_seed", 0))
		})

	# Save once via Flow-owned choke point
	flow_ctx.save_request = true
	var reason := "debug.seed.reset" if do_reset else "debug.seed.set"
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|" + reason
	else:
		flow_ctx.save_request_reason = reason

	# IMPORTANT: no flow transition occurs, so refresh snapshot immediately
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

## COMBAT-001: initializes CombatState, logs combat.init, saves, and rebuilds snapshot.
func _handle_combat_init(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_machine == null:
		logger.debug(t, "combat.init.no_op", "combat.init with no encounter context", {})
		return

	# If machine hasn't been started yet (edge case), start it first.
	if flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		flow_ctx.encounter_machine.start(flow_ctx.encounter_ctx, logger, t)

	# Transition to ROUNDS — EncounterRoundsState.enter() creates CombatState on ectx.
	flow_ctx.encounter_machine.transition(
		EncounterStateIds.ROUNDS, flow_ctx.encounter_ctx, logger, t, "combat.init")

	# Log after EncounterRoundsState.enter() has set combat_state.
	var cs: Dictionary = flow_ctx.encounter_ctx.combat_state
	logger.info(t, "combat.init", "Combat state initialized", {
		"actor_count":   cs.get("actors", []).size(),
		"objective":     cs.get("objective", ""),
		"round_counter": int(cs.get("round_counter", 0)),
	})
	# COMBAT-002: log round_start with full initiative order for determinism audit.
	var order: Array = cs.get("initiative_order", [])
	logger.info(t, "combat.round_start", "Round 0 initiative set", {
		"round_counter":    int(cs.get("round_counter", 0)),
		"actor_count":      order.size(),
		"initiative_order": order,
	})

	# Save checkpoint on combat start.
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "combat.init"

	# Rebuild flow.encounter snapshot with combat state included.
	flow_ctx.last_snapshot = FlowEncounterState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: starts a new round, clears round-scoped state, resolves the first living actor,
## and emits a per-actor snapshot. Subsequent actors are driven by combat.next_actor.
func _handle_combat_confirm_round(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_ctx.combat_state.is_empty():
		logger.debug(t, "combat.confirm_round.no_op", "Confirm round: no active combat state", {})
		return

	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state

	# Guard: combat already over — ignore stale presses.
	if bool(combat_state.get("combat_over", false)):
		return

	# 1. Log round_start before incrementing.
	var prev_round: int = int(combat_state.get("round_counter", 0))
	logger.info(t, "combat.round_start", "Round starting", { "round": prev_round + 1 })

	# 2. Clear round-scoped state on all actors (guard_state is runtime-only — not persisted).
	for actor_v in ectx.actors:
		if actor_v is Dictionary:
			actor_v["guard_state"] = false
	ectx.last_round_results = []
	ectx.last_actor_action  = {}

	# 3. Advance round counter, reset actor pointer, mark round active.
	combat_state["round_counter"]        = prev_round + 1
	combat_state["current_actor_index"]  = 0
	combat_state["round_phase"]          = "in_round"

	# 4. Resolve the first actor (emits snapshot with cta.next_actor).
	_resolve_next_actor(t)


## COMBAT-SEQ: advances one step in the current round — resolves the next living actor
## and emits a per-actor snapshot.
func _handle_combat_next_actor(t: int) -> void:
	if flow_ctx.encounter_ctx == null or flow_ctx.encounter_ctx.combat_state.is_empty():
		return
	if bool(flow_ctx.encounter_ctx.combat_state.get("combat_over", false)):
		return
	_resolve_next_actor(t)


## COMBAT-SEQ: finds the next living actor from current_actor_index, resolves their turn,
## appends the result to last_round_results, emits a per-actor snapshot.
## If no living actor remains, calls _end_round() instead.
func _resolve_next_actor(t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state

	# Find the next living actor starting at current_actor_index.
	var next_idx: int = _find_next_living_actor_idx(ectx)
	if next_idx == -1:
		_end_round(t)
		return

	# Advance pointers — current_actor_index advances PAST this actor after resolution.
	combat_state["active_initiative_index"] = next_idx

	var order: Array = combat_state.get("initiative_order", [])
	var actor_id: String = str(order[next_idx].get("id", ""))
	var actor: Dictionary = _find_actor_by_id(ectx.actors, actor_id)

	# Read config blocks.
	var balance: Dictionary = config_service.get_balance()
	var bdata: Dictionary = balance.get("data", {})
	var grid_cfg: Dictionary = bdata.get("grid", {})
	var actor_cfg: Dictionary = bdata.get("actor", {})
	var round: int = int(combat_state.get("round_counter", 0))

	# Build per-turn context — matches ActorStateMachine.advance_turn() contract.
	var ctx: Dictionary = {
		"actor":      actor,
		"all_actors": ectx.actors,
		"board_cfg":  grid_cfg,
		"cfg":        balance,
		"t":          t,
		"round":      round,
	}

	# Resolve this actor's turn.
	var asm := ActorStateMachine.new(actor, null, actor_cfg)
	var intent: Dictionary = asm.advance_turn(ctx, logger, t)
	var action_type: String = intent.get("action_type", "actor.idle")

	logger.debug(t, "combat.actor_turn", "%s → %s" % [actor.get("name", "?"), action_type], {
		"round":       round,
		"actor_id":    actor.get("id", ""),
		"actor_name":  actor.get("name", ""),
		"action_type": action_type,
		"faction":     actor.get("faction", ""),
	})

	# Resolve the action and append result to last_round_results.
	match action_type:
		"melee_attack":
			var target_id: String = str(intent.get("target_id", ""))
			var target: Dictionary = _find_actor_by_id(ectx.actors, target_id)
			if not target.is_empty():
				var result: Dictionary = CombatService.resolve_action("melee_attack", actor, target, round)
				if not result.is_empty():
					result["source_name"] = str(actor.get("name", ""))
					result["target_name"] = str(target.get("name", ""))
					ectx.last_round_results.append(result)
					var kill_str: String = " (kills)" if result.get("is_kill", false) else ""
					logger.info(t, "combat.action_resolved",
					"%s attacks %s for %d%s" % [actor.get("name", "?"), target.get("name", "?"), int(result.get("damage", 0)), kill_str], result)
		"actor.guard":
			var guard_result: Dictionary = CombatService.resolve_action("actor.guard", actor, {}, round)
			if not guard_result.is_empty():
				guard_result["source_name"] = str(actor.get("name", ""))
				ectx.last_round_results.append(guard_result)
				logger.info(t, "combat.guard_taken",
					"%s guards" % actor.get("name", "?"), { "actor_id": actor.get("id", "") })
		"actor.refuse":
			logger.info(t, "combat.action_refused",
				"%s refuses (fear %d)" % [actor.get("name", "?"), int(actor.get("fear", 0))], {
				"actor_id": actor.get("id", ""),
				"fear":     int(actor.get("fear", 0)),
			})
			ectx.last_round_results.append({
				"action_type": "actor.refuse",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   "",
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})
		"actor.move":
			var move_target_id: String = str(intent.get("target_id", ""))
			var move_target: Dictionary = _find_actor_by_id(ectx.actors, move_target_id)
			var move_target_name: String = str(move_target.get("name", "")) if not move_target.is_empty() else ""
			logger.debug(t, "combat.actor_moved",
				"%s moves toward %s" % [actor.get("name", "?"), move_target_name if not move_target_name.is_empty() else move_target_id], {
				"actor_id":    actor.get("id", ""),
				"actor_name":  actor.get("name", ""),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"grid_pos":    actor.get("grid_pos", {}),
				"round":       round,
			})
			ectx.last_round_results.append({
				"action_type": "actor.move",
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   move_target_id,
				"target_name": move_target_name,
				"damage":      0,
				"is_kill":     false,
				"to_pos":      actor.get("grid_pos", {}).duplicate(),
			})
		_:
			ectx.last_round_results.append({
				"action_type": action_type,
				"source_id":   str(actor.get("id", "")),
				"source_name": str(actor.get("name", "")),
				"target_id":   str(intent.get("target_id", "")),
				"target_name": "",
				"damage":      0,
				"is_kill":     false,
			})

	# Store the most recent result for per-actor snapshot display.
	if not ectx.last_round_results.is_empty():
		ectx.last_actor_action = ectx.last_round_results.back().duplicate()

	# Advance current_actor_index past this actor so the next call finds the correct one.
	combat_state["current_actor_index"] = next_idx + 1

	# Emit per-actor snapshot — UI shows updated board + arrow + action text for this actor.
	flow_ctx.last_snapshot = FlowEncounterState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: called after the last actor in the round has acted.
## Logs round_end, checks end condition, resets round state, emits round-end snapshot.
func _end_round(t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var combat_state: Dictionary = ectx.combat_state
	var round: int = int(combat_state.get("round_counter", 0))

	# Build remaining_actors list (living — for round_end log).
	var remaining_actors: Array = []
	for a_v in ectx.actors:
		if a_v is Dictionary and not a_v.get("is_dead", false):
			remaining_actors.append(str(a_v.get("id", "")))

	logger.info(t, "combat.round_end", "Round complete", {
		"round":            round,
		"remaining_actors": remaining_actors,
	})

	# Check end condition.
	var end_check: Dictionary = CombatState.check_end_condition(ectx.actors, ectx.resolution_mode)
	if end_check.get("over", false):
		combat_state["combat_over"] = true
		# COMBAT-005: store result on ectx so build_snapshot() can surface it.
		ectx.combat_result = {
			"victory":     bool(end_check.get("victory", false)),
			"reason":      str(end_check.get("reason", "")),
			"round_ended": round,
		}
		logger.info(t, "combat.end", "Combat ended", {
			"victory": bool(end_check.get("victory", false)),
			"reason":  str(end_check.get("reason", "")),
			"round":   round,
		})

	# Reset round-phase state — snapshot will show cta.confirm_round (or nothing if combat_over).
	combat_state["round_phase"]          = "idle"
	combat_state["current_actor_index"]  = 0
	combat_state["active_initiative_index"] = 0
	ectx.last_actor_action = {}

	flow_ctx.last_snapshot = FlowEncounterState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## COMBAT-SEQ: scans initiative_order from current_actor_index forward.
## Returns the index of the next living actor, or -1 if all actors in the order have gone.
func _find_next_living_actor_idx(ectx: EncounterContext) -> int:
	var order: Array = ectx.combat_state.get("initiative_order", [])
	var start: int = int(ectx.combat_state.get("current_actor_index", 0))
	for i in range(start, order.size()):
		var aid: String = str(order[i].get("id", ""))
		var a: Dictionary = _find_actor_by_id(ectx.actors, aid)
		if not a.is_empty() and not a.get("is_dead", false):
			return i
	return -1


## Returns the first actor dict matching actor_id in the array, or {} if not found.
func _find_actor_by_id(actors: Array, actor_id: String) -> Dictionary:
	for a_v in actors:
		if a_v is Dictionary and str(a_v.get("id", "")) == actor_id:
			return a_v
	return {}


func _generate_seed_root_string() -> String:
	# Dev-safe randomness: allowed only as an input at New Game.
	# Uses OS crypto bytes, not global RNG.
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	return bytes.hex_encode()

func _legacy_root_seed_from_seed_root(seed_root: String) -> int:
	# Temporary compatibility: several MVP systems still use CampaignSeed(int).
	# Derive a deterministic int from the first 8 hex chars (32-bit).
	if seed_root.length() < 8:
		return 0
	var prefix := seed_root.substr(0, 8)
	# Parse as hex via "0x" prefix
	return int("0x" + prefix)

func _handle_debug_echo_gen_test(t: int) -> void:
	# Pull seed_root from save
	var camp: Dictionary = {}
	if flow_ctx.save_data != null and flow_ctx.save_data.has("campaign") and typeof(flow_ctx.save_data["campaign"]) == TYPE_DICTIONARY:
		camp = flow_ctx.save_data["campaign"]

	var seed_root := str(camp.get("seed_root", "")).strip_edges()
	if seed_root.is_empty():
		logger.info(t, "debug.echo.gen_test.denied", "Denied echo gen test (missing seed_root)", {})
		return

	# Pull summoning config from balance.json
	var balance := config_service.get_balance()
	var data_v : Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summ_v : Variant = data.get("summoning", {})
	var summ_cfg: Dictionary = summ_v if summ_v is Dictionary else {}

	# Generate same path twice
	var path0 := "campaign.summon.0"
	var e1: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)
	var e2: Dictionary = EchoFactory.generate(seed_root, path0, 0, "summon", summ_cfg)

	# Generate different path
	var path1 := "campaign.summon.1"
	var e3: Dictionary = EchoFactory.generate(seed_root, path1, 1, "summon", summ_cfg)

	var fp1 := _echo_fingerprint(e1)
	var fp2 := _echo_fingerprint(e2)
	var fp3 := _echo_fingerprint(e3)

	logger.info(t, "debug.echo.gen_test", "EchoFactory determinism test", {
		"seed_root": seed_root,
		"path_a": path0,
		"path_b": path1,
		"fingerprint_1": fp1,
		"fingerprint_2": fp2,
		"fingerprint_3": fp3,
		"same_path_equal": fp1 == fp2,
		"diff_path_differs": fp1 != fp3,
	})

	# No state transition: refresh snapshot so UI/debug panels remain in sync
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _echo_fingerprint(e: Dictionary) -> String:
	# Stable, human-readable digest for determinism checks.
	# Do NOT include id (caller assigns it).
	var name := str(e.get("name", ""))
	var gender := str(e.get("gender", ""))
	var rarity := str(e.get("rarity", ""))
	var calling := str(e.get("calling_origin", ""))
	var arch := str(e.get("archetype_birth", ""))
	var traits_v : Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var stats_v : Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	return "%s|%s|%s|%s|%s|c%dw%df%d|hp%datk%ddef%dagi%dint%dcha%d" % [
		name,
		gender,
		rarity,
		calling,
		arch,
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]

func _handle_economy_settle_time(action: Dictionary, t: int) -> void:
	var now_unix := int(action.get("now_unix", 0))
	var source := str(action.get("source", ""))
	
	if now_unix <= 0:
		logger.info(t, "economy.time_anomaly", "Denied settle (invalid now_unix)", {
			"now_unix": now_unix,
			"source": source
		})
		return
		
	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		logger.info(t, "economy.settle.denied", "No economy data in save", {
			"source": source
		})
		return
		
	var econ_data := flow_ctx.save_data["economy"] as Dictionary
	var last_settle := int(econ_data.get("last_settle_unix", now_unix))
	
	var raw_delta := now_unix - last_settle
	var delta_seconds := raw_delta
	
	# Clamp policy (MVP)
	var clamped_negative := false
	var clamped_cap := false
	
	if delta_seconds < 0:
		delta_seconds = 0
		clamped_negative = true
		
	var max_delta_seconds := _get_max_online_settle_delta_seconds()
	if delta_seconds > max_delta_seconds:
		delta_seconds = max_delta_seconds
		clamped_cap = true
	
	var note := ""
	if clamped_cap:
		note = "delta clamped to cap (likely boot catch-up; not offline accrual)"
	elif clamped_negative:
		note = "negative delta clamped to 0"
	
	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0
	
	# Multiplier seam (Faith later) - optional input, default 1.0
	var multiplier := float(action.get("multiplier", 1.0))
	
	# Compute gain
	var gain := EconomyAccrualService.compute_online_settle_gain(delta_seconds, rate_per_sec, multiplier)
	
	var settle_reason := "economy.settle_time.normal"
	if clamped_cap:
		settle_reason = "economy.settle_time.catch_up"
	elif clamped_negative:
		settle_reason = "economy.settle_time.anomaly"

	# Apply via EconomyService (keep logging cnetralized there)
	if gain > 0:
		# Replace this call with your EconomyService signature if different.
		econ.add_ase(gain, settle_reason, logger, t)
	
	# Update settle guard even if gain=0 (prevents re-settling same window)
	econ_data["last_settle_unix"] = now_unix
	
	# Structured settle log (Core truth)
	var settle_msg := "Ase settled"
	if clamped_cap:
		settle_msg = "Ase settled (clamped)"
	elif clamped_negative:
		settle_msg = "Ase settled (time anomaly)"

	logger.debug(t, "economy.settle", settle_msg, {
		"source": source,
		"now_unix": now_unix,
		"last_settle_unix_before": last_settle,
		"raw_delta_seconds": raw_delta,
		"delta_seconds_used": delta_seconds,
		"clamped_negative": clamped_negative,
		"clamped_cap": clamped_cap,
		"cap_seconds": max_delta_seconds,
		"note": note,
		"ase_per_min_base": ase_per_min,
		"multiplier": multiplier,
		"gain": gain,
		"ase_after": int(econ_data.get("ase", 0)),
	})
	
	# IMPORTANT: settle_time can occur without a flow transition (e.g., Sanctum bank interval),
	# so we must refresh snapshot so UI updates immediately.
	flow_machine.refresh_snapshot(flow_ctx, logger, t)
	
func _apply_offline_accrual_if_needed(t: int, source: String) -> int:
	# Offline accrual must only happen when the player enters the session (flow.continue),
	# not on boot/splash/menu. Uses OS time only here.
	var now_unix := int(Time.get_unix_time_from_system())

	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		flow_ctx.save_data["economy"] = {}
	var econ_data := flow_ctx.save_data["economy"] as Dictionary

	var last_offline := int(econ_data.get("last_offline_unix", now_unix))
	var raw_delta := now_unix - last_offline

	# Nothing to do (or suspicious backwards time)
	if raw_delta <= 0:
		if raw_delta < 0:
			logger.info(t, "economy.time_anomaly", "Offline accrual denied (time went backwards)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		else:
			logger.debug(t, "economy.offline.skip", "Offline accrual skipped (no elapsed time)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		return 0

	# Read balance knobs
	var econ_cfg := _get_balance_economy_cfg()
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0

	var offline_start_factor := float(econ_cfg.get("offline_start_factor", 0.5))
	var offline_cap_seconds := int(econ_cfg.get("offline_cap_seconds", 28800))

	# Clamp forward jumps to cap (anti-cheat MVP)
	var delta_seconds := raw_delta
	var clamped_cap := false
	if offline_cap_seconds > 0 and delta_seconds > offline_cap_seconds:
		delta_seconds = offline_cap_seconds
		clamped_cap = true

	# Multiplier seam (Faith later). Economy stays emotion-agnostic.
	var multiplier := 1.0

	var ase_before := int(econ_data.get("ase", 0))

	var gain := EconomyAccrualService.compute_offline_gain(
		delta_seconds,
		rate_per_sec,
		multiplier,
		offline_start_factor,
		offline_cap_seconds
	)

	# Apply via EconomyService (centralizes ledger logs)
	if gain > 0:
		econ.add_ase(gain, "economy.offline_accrual", logger, t)
		logger.debug(t, "economy.offline.apply", "Offline accrual applied", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"gain": gain,
			"ase_before": ase_before,
			"ase_after": int(econ_data.get("ase", 0)),
		})
	else:
		logger.debug(t, "economy.offline.noop", "Offline accrual no-op", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"gain": gain,
		})

	# Update guards ONLY here (so we don't re-award next launch)
	econ_data["last_offline_unix"] = now_unix

	# Also reset last_settle_unix so online settle doesn't mint a "catch-up" window after continue
	econ_data["last_settle_unix"] = now_unix

	# Persist via Flow boundary save policy (sanctioned boundary)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|economy.offline_accrual"
	else:
		flow_ctx.save_request_reason = "economy.offline_accrual"
	
	return gain
	
func _get_drift_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	var drift_v: Variant = emo.get("drift", {})
	return drift_v if drift_v is Dictionary else {}


# EMOTION-002: applies combat win/loss morale+fear deltas to all roster echoes.
func _apply_encounter_emotion_drift(outcome: String, t: int) -> void:
	var drift := _get_drift_cfg()
	var fear_threshold := int(drift.get("fear_threshold", 80))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		if outcome == "win":
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_win_morale",   10)), "combat_exit_win",  logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_win_fear",      -5)), "combat_exit_win",  fear_threshold, logger, t)
		else:
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_loss_morale", -15)), "combat_exit_loss", logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_loss_fear",    20)), "combat_exit_loss", fear_threshold, logger, t)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|encounter.emotion_drift"
	else:
		flow_ctx.save_request_reason = "encounter.emotion_drift"


# EMOTION-002: applies sanctum morale recovery tick to echoes below their base.
func _apply_sanctum_emotion_tick(t: int) -> void:
	var drift := _get_drift_cfg()
	var tick_delta := int(drift.get("sanctum_tick_morale", 2))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		var emo := EmotionService.get_emotion(echo_v)
		var morale_base    := int(emo.get("morale_base",    50))
		var morale_current := int(emo.get("morale_current", 50))
		# Recovery only moves morale toward base — never above it
		if morale_current < morale_base:
			EmotionService.apply_morale_delta(echo_v, tick_delta, "sanctum_tick", logger, t)


func _get_balance_economy_cfg() -> Dictionary:
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}

	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var econ_v = data.get("economy", {})
	var econ_cfg: Dictionary = econ_v as Dictionary if econ_v is Dictionary else {}

	return econ_cfg
	
func _get_max_online_settle_delta_seconds() -> int:
	# Online settle guard. Offline accrual has its own capped window.
	return 3600 # 1 hour
	
func get_save_data() -> Dictionary:
	return flow_ctx.save_data

func get_tick() -> int:
	return int(flow_ctx.sim_tick)

func _ensure_encounter_started(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.ENCOUNTER:
		return
	if flow_ctx.encounter_ctx == null:
		return
	if flow_ctx.encounter_machine == null:
		return
	if not flow_ctx.encounter_ctx.phase_snapshot.is_empty():
		return
	flow_ctx.encounter_machine.start(flow_ctx.encounter_ctx, logger, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)

func _log_snapshot_emitted(t: int, snapshot: Dictionary, reason: String) -> void:
	logger.debug(t, "snapshot.emitted", "Snapshot emitted", {
		"reason": reason,
		"snapshot_type": str(snapshot.get("type", "")),
	})
	
func _get_party_max_size() -> int:
	var max_party_size := 5
	if config_service == null:
		return max_party_size

	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	var s_v: Variant = data.get("sanctum", {})
	var s_cfg: Dictionary = s_v if s_v is Dictionary else {}

	return int(s_cfg.get("party_max_size", 5))
	
func _handle_sanctum_party_toggle(action: Dictionary, t: int) -> void:
	# Only meaningful inside Party Manage; ignore elsewhere to avoid accidental mutations.
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.PARTY_MANAGE:
		logger.debug(t, "sanctum.party.toggle.ignored", "Party toggle ignored (not in party_manage)", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}

	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (missing echo_id)", {})
		return

	# Ensure pending exists (should have been initialized on enter, but be defensive)
	if flow_ctx.pending_party_ids == null:
		flow_ctx.pending_party_ids = []
	if not (flow_ctx.pending_party_ids is Array):
		flow_ctx.pending_party_ids = []

	# Validate echo_id exists in roster (prevent selecting ghost ids)
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var exists := false
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			exists = true
			break

	if not exists:
		logger.debug(t, "sanctum.party.toggle.denied", "Party toggle denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	var max_party_size := _get_party_max_size()

	# Toggle behavior
	var added := false
	if flow_ctx.pending_party_ids.has(echo_id):
		flow_ctx.pending_party_ids.erase(echo_id)
		added = false
	else:
		if flow_ctx.pending_party_ids.size() >= max_party_size:
			logger.info(t, "sanctum.party.toggle_denied", "Party is full", {
				"echo_id": echo_id,
				"max_party_size": max_party_size,
				"pending_count": flow_ctx.pending_party_ids.size()
			})
			return
		flow_ctx.pending_party_ids.append(echo_id)
		added = true

	logger.debug(t, "sanctum.party.toggle", "Party toggled", {
		"echo_id": echo_id,
		"added": added,
		"pending_count": flow_ctx.pending_party_ids.size(),
		"max_party_size": max_party_size
	})

	# No flow transition — update UI immediately
	flow_ctx.last_snapshot = FlowPartyManageState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)
	
## PROG-001: one-time repair pass for echo fields added after draw-order v1.
## Called on flow.continue — patches roster echoes missing class_origin / level.
## If any echoes were patched, requests a save flush so defaults persist.
func _repair_echo_schema(t: int) -> void:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var patched_count := 0
	for e_v in roster:
		if e_v is Dictionary:
			if EchoFactory.repair_echo_fields(e_v):
				patched_count += 1

	if patched_count > 0:
		flow_ctx.save_request = true
		if flow_ctx.save_request_reason != "":
			flow_ctx.save_request_reason += "|sanctum.schema.repair"
		else:
			flow_ctx.save_request_reason = "sanctum.schema.repair"
		logger.info(t, "sanctum.schema.repair", "Repaired old echo fields", {
			"patched": patched_count,
			"roster_size": roster.size()
		})


func _handle_sanctum_party_confirm(t: int) -> void:
	# Only meaningful inside Party Manage
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.PARTY_MANAGE:
		logger.debug(t, "sanctum.party.confirm.ignored", "Party confirm ignored (not in party_manage)", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var max_party_size := _get_party_max_size()

	var pending: Array = flow_ctx.pending_party_ids if flow_ctx.pending_party_ids is Array else []
	if pending.size() < 1:
		logger.debug(t, "sanctum.party.confirm.denied", "Party confirm denied (empty selection)", {})
		return
	if pending.size() > max_party_size:
		logger.debug(t, "sanctum.party.confirm.denied", "Party confirm denied (over max)", {
			"count": pending.size(),
			"max_party_size": max_party_size
		})
		return

	# Ensure sanctum dict exists
	if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["sanctum"] = {}
	var sanctum: Dictionary = flow_ctx.save_data["sanctum"]

	# Persist selection
	sanctum["active_party_ids"] = pending.duplicate()

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|sanctum.party.confirm"
	else:
		flow_ctx.save_request_reason = "sanctum.party.confirm"

	logger.info(t, "sanctum.party.confirm", "Party confirmed", {
		"count": pending.size(),
		"party_ids": pending
	})

	# Return to sanctum hub
	flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.sanctum.party.confirm")


# DIRECTIVE-001: writes the chosen directive to stage_context, requests save, refreshes snapshot.
func _handle_directive_select(action: Dictionary, t: int) -> void:
	var id := str(action.get("directive_id", ""))
	directive_service.set_active_directive(id, logger, t)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|directive.select"
	else:
		flow_ctx.save_request_reason = "directive.select"
	flow_machine.refresh_snapshot(flow_ctx, logger, t)
