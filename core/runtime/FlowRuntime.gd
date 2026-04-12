# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

const FlowWeavingRiteStateScript  := preload("res://core/state/flow/states/sanctum/FlowWeavingRiteState.gd")
const WeavingRiteServiceScript    := preload("res://core/progression/WeavingRiteService.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")  # V2-STAGE-001
const StageExploreModelScript     := preload("res://core/realms/StageExploreModel.gd")                          # V2-STAGE-001
const SituationModelScript        := preload("res://core/realms/SituationModel.gd")                             # V2-STAGE-001

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

	# REALM-001: populate campaign_seed from save (was always null before this story)
	var _boot_camp_v: Variant = flow_ctx.save_data.get("campaign", {})
	var _boot_camp: Dictionary = _boot_camp_v if _boot_camp_v is Dictionary else {}
	flow_ctx.campaign_seed = CampaignSeed.new(int(_boot_camp.get("root_seed", 0)))

	# REALM-001: restore active realm_id from save (survives Continue)
	var _boot_realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var _boot_realms: Dictionary = _boot_realms_v if _boot_realms_v is Dictionary else {}
	for _rid in _boot_realms:
		var _rm: Dictionary = _boot_realms[_rid] if _boot_realms[_rid] is Dictionary else {}
		if _rm.get("status", "") == "active":
			flow_ctx.realm_id = str(_rid)
			break

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
	if flow_ctx.weave_commit_locked and action_type != "weave.confirm":
		logger.debug(t, "weave.commit.locked", "Action blocked by weaving commitment lock", {
			"blocked_action": action_type,
		})
		var locked_out := flow_ctx.last_snapshot
		_log_snapshot_emitted(t, locked_out, "dispatch.weave_locked")
		return locked_out

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
			elif to_state == FlowStateIds.WEAVING_RITE:
				flow_ctx.selected_weave_thread_id = ""
				flow_ctx.selected_weave_echo_id = ""
				flow_ctx.weave_commit_locked = false
				flow_ctx.weave_resolution = {}
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")

		"flow.select_realm":
			# REALM-001: create/retrieve RealmModel, then go directly to stage map
			var realm_id := str(action.get("realm_id", ""))
			flow_ctx.realm_id = realm_id
			RealmService.get_or_create(realm_id, flow_ctx, t)  # sets save_request internally
			flow_machine.transition(FlowStateIds.STAGE_MAP, flow_ctx, logger, t, "ui.realm_selected")

		"flow.select_stage":
			var stage_id := str(action.get("stage_id", ""))
			flow_ctx.stage_id     = stage_id
			flow_ctx.encounter_id = flow_ctx.realm_id + "." + stage_id  # BUG-003: was always ""
			# PROG-009: persist skill loadout to save before entering the stage
			_persist_equipped_skills(t)
			logger.info(t, "state.stage_select", "Stage selected", { "stage_id": stage_id })
			flow_machine.transition(FlowStateIds.STAGE, flow_ctx, logger, t, "ui.flow.select_stage")

		# REALM-004: advance stage index; on realm complete, route to REALM_SELECT.
		# destination override allows cta.continue on victory to route to SANCTUM instead of STAGE_MAP.
		"flow.complete_stage":
			var dest_override := str(action.get("destination", ""))
			_handle_complete_stage(t, dest_override)

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

		# UI-004: player attempts to retreat before combat starts.
		# Roll is seeded for determinism; Ase spent win or lose.
		# Success → Sanctum. Failure → combat starts automatically.
		"encounter.retreat":
			_handle_encounter_retreat(action, t)

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

			# Refresh snapshot so the modal hides (sanctum_name is now set)
			flow_machine.refresh_snapshot(flow_ctx, logger, t)
			
		"sanctum.summon":
			_handle_sanctum_summon(action, t)

		"sanctum.grade_select":
			_handle_sanctum_grade_select(action, t)

		"sanctum.party.toggle":
			_handle_sanctum_party_toggle(action, t)

		# ---- Weaving Rite (V2-WEAVE-002) ----
		"weave.start_for_echo":
			_handle_weave_start_for_echo(action, t)

		"weave.select_thread":
			if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
				logger.debug(t, "weave.select_thread.ignored", "Selection ignored outside rite state", {})
			else:
				flow_ctx.selected_weave_thread_id = str(action.get("thread_id", ""))
				flow_ctx.weave_resolution = {}
				flow_ctx.weave_commit_locked = false
				flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"weave.begin_rite":
			_handle_weave_begin_rite(t)

		"weave.confirm":
			_handle_weave_confirm(t)

		# PROG-004: Keeper-confirmed rank-up from EchoParty.
		"sanctum.rank_up":
			_handle_sanctum_rank_up(action, t)

		# PROG-007: Keeper confirms a calling for an echo (may be deferred after rank-up).
		"sanctum.calling.confirm":
			_handle_sanctum_calling_confirm(action, t)

		# ---- Vows (VOW-001) ----
		"vow.pledge":
			_handle_vow_pledge(action, t)

		"vow.break":
			_handle_vow_break(t)

		"debug.vow.unlock":
			_handle_debug_vow_unlock(action, t)

		# ---- Directives (DIRECTIVE-001) ----
		"directive.select":
			_handle_directive_select(action, t)

		# ---- Skill Loadout (PROG-009) — assign/unassign while on STAGE_MAP ----
		"skill.assign":
			_handle_skill_assign(action, t)

		"skill.unassign":
			_handle_skill_unassign(action, t)

		# ---- Stage Exploration (V2-STAGE-001) ----
		"stage.advance_turn":
			_handle_stage_advance_turn(action, t)

		"stage.return_home":
			_handle_stage_return_home(action, t)

		"stage.engage_situation":
			_handle_stage_engage_situation(action, t)

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

	var expr_v: Variant = data.get("maturity_expression", {})
	var expression_cfg: Dictionary = expr_v if expr_v is Dictionary else {}
	var result := SummonService.summon_paid_many(flow_ctx.save_data, seed_root, summ_cfg, count, logger, t, expression_cfg)

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
				# Arrival bark — logged for debug output and telemetry (display-only, no side effects)
				var arch_v   := str(e_v.get("archetype_birth", ""))
				var t_v_bark := e_v.get("traits", {}) as Dictionary
				var tier_v   := ShoutBank.get_tier(
					int(t_v_bark.get("courage", 50)),
					int(t_v_bark.get("wisdom",  50)),
					int(t_v_bark.get("faith",   50))
				)
				var bark := ShoutBank.get_shout("arrival", arch_v, tier_v)
				logger.info(t, "sanctum.summon.bark", bark, {
					"echo_id": str(e_v.get("id", "")),
					"arch":    arch_v,
					"tier":    tier_v,
				})
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

# REALM-004: Advance stage index; on realm complete, clear context and route to REALM_SELECT.
# destination_override: when set, non-completed stages route there instead of STAGE_MAP.
# Realm completion always routes to REALM_SELECT regardless of override.
func _handle_complete_stage(t: int, destination_override: String = "") -> void:
	# Fix BUG-003: read outcome BEFORE nulling encounter_ctx so drift reflects the actual result.
	var outcome := "loss"
	if flow_ctx.encounter_ctx != null:
		var victory := bool(flow_ctx.encounter_ctx.combat_result.get("victory", false))
		outcome = "win" if victory else "loss"
	_apply_encounter_emotion_drift(outcome, t)
	flow_ctx.encounter_ctx     = null
	flow_ctx.encounter_machine = null

	# V2-WEAVE-001: load thread config (read-only)
	var _bal_v: Variant = flow_ctx.config_service.get_balance()
	var _bal: Dictionary = _bal_v if _bal_v is Dictionary else {}
	var _bal_data_v: Variant = _bal.get("data", {})
	var _bal_data: Dictionary = _bal_data_v if _bal_data_v is Dictionary else {}
	var _thread_cfg_v: Variant = _bal_data.get("threads", {})
	var _thread_cfg: Dictionary = _thread_cfg_v if _thread_cfg_v is Dictionary else {}

	# V2-WEAVE-001: contribute segment — grade from the final encounter snapshot
	if not _thread_cfg.is_empty() and not flow_ctx.realm_id.is_empty():
		var _snap_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
		var _snap_data: Dictionary = _snap_data_v if _snap_data_v is Dictionary else {}
		var _combat_grade := str(_snap_data.get("rank", "F"))
		RealmService.contribute_segment(flow_ctx, _combat_grade, _thread_cfg, t)

	var result := RealmService.advance_stage(flow_ctx, t)  # sets save_request + logs internally
	if result.get("is_completed", false):
		# V2-WEAVE-001: crystallize Threads before clearing realm context
		flow_ctx.last_realm_threads_earned = []
		if not _thread_cfg.is_empty():
			var _completed_realm_id := flow_ctx.realm_id  # capture BEFORE clearing
			flow_ctx.last_realm_threads_earned = ThreadService.crystallize_threads(
				_completed_realm_id, flow_ctx.save_data, _thread_cfg, t, flow_ctx.logger
			)
			flow_ctx.save_request = true
			if flow_ctx.save_request_reason.is_empty():
				flow_ctx.save_request_reason = "thread.crystallize"
			else:
				flow_ctx.save_request_reason += "|thread.crystallize"

		# Clear stale context so re-entry into a new realm starts clean
		flow_ctx.realm_id = ""
		flow_ctx.stage_id = ""
		flow_machine.transition(FlowStateIds.REALM_SELECT, flow_ctx, logger, t, "realm.complete")
	else:
		var dest: String = destination_override if destination_override != "" else FlowStateIds.STAGE_MAP
		flow_machine.transition(dest, flow_ctx, logger, t, "realm.stage_complete")


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

	# REALM-001: populate campaign_seed from the newly generated save
	flow_ctx.campaign_seed = CampaignSeed.new(legacy_root_seed)
	# New game always starts with no active realm
	flow_ctx.realm_id = ""

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

## UI-004: Player attempts retreat before round 1.
## Gate (speed) and tier (agi) were computed at snapshot time and baked into the action dict.
## Ase is spent regardless of roll outcome.
## Success → clear encounter, go to Sanctum. Failure → start combat immediately.
func _handle_encounter_retreat(action: Dictionary, t: int) -> void:
	if flow_ctx.encounter_ctx == null:
		logger.debug(t, "encounter.retreat.no_op", "Retreat: no active encounter context", {})
		return

	var ase_cost:    int = int(action.get("ase_cost",    0))
	var success_pct: int = int(action.get("success_pct", 0))
	var encounter_id: String = flow_ctx.encounter_ctx.encounter_id

	# Spend Ase (always, win or lose). Guard: only spend if player can afford.
	if ase_cost > 0:
		if econ.can_afford_ase(ase_cost):
			econ.spend_ase(ase_cost, "encounter.retreat", logger, t)
		else:
			logger.debug(t, "encounter.retreat.no_ase", "Retreat: insufficient Ase — no spend", {
				"ase_cost": ase_cost, "ase_balance": econ.get_ase()
			})

	# Seeded roll for determinism.
	var rng := RandomNumberGenerator.new()
	if flow_ctx.campaign_seed != null:
		rng = flow_ctx.campaign_seed.get_rng("encounter.retreat." + encounter_id + "." + str(t))
	else:
		rng.seed = hash("encounter.retreat." + encounter_id + str(t))

	var roll_result: Dictionary = RetreatService.roll_retreat(success_pct, rng)
	var success: bool = bool(roll_result.get("success", false))

	logger.info(t, "encounter.retreat", "Retreat attempted", {
		"encounter_id": encounter_id,
		"ase_cost":     ase_cost,
		"success_pct":  success_pct,
		"success":      success,
	})

	if success:
		# Clear encounter context — no emotion drift on retreat.
		flow_ctx.encounter_ctx    = null
		flow_ctx.encounter_machine = null
		flow_ctx.save_request      = true
		flow_ctx.save_request_reason = "encounter.retreat"
		_apply_sanctum_emotion_tick(t)
		flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "encounter.retreat.success")
	else:
		logger.info(t, "encounter.retreat.failed", "Retreat failed — combat begins", {
			"encounter_id": encounter_id,
		})
		# Start combat immediately.
		_handle_combat_init(t)


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
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)
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
	var prog_cfg_block: Dictionary    = bdata.get("progression", {})
	var birth_stats_block: Dictionary = bdata.get("summoning", {}).get("birth_stats", {})
	var round: int = int(combat_state.get("round_counter", 0))

	# COMBAT-006: find shrine and compute context fields for purify_shrine objective.
	var shrine_alive: bool    = false
	var shrine_hp_ratio: float = 1.0
	if ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				shrine_alive = true
				var s_max: int = int(a_v.get("stats", {}).get("max_hp", 0))
				if s_max > 0:
					shrine_hp_ratio = clampf(float(a_v.get("current_hp", s_max)) / float(s_max), 0.0, 1.0)
				break

	# VOW-001: pass active vow into per-turn context so BehaviorArbiter can apply vow bias.
	var _vow_ctx := VowService.get_active_vow(flow_ctx.save_data)

	# Build per-turn context — matches ActorStateMachine.advance_turn() contract.
	var ctx: Dictionary = {
		"actor":                   actor,
		"all_actors":              ectx.actors,
		"board_cfg":               grid_cfg,
		"cfg":                     balance,
		"t":                       t,
		"round":                   round,
		# COMBAT-006: shrine context fields for BehaviorArbiter + MeleeBehaviorModule.
		"purifier_id":             ectx.purifier_id,
		"is_purifier":             str(actor.get("id", "")) == ectx.purifier_id,
		"shrine_alive":            shrine_alive,
		"shrine_hp_ratio":         shrine_hp_ratio,
		"prefer_objective_target": actor.get("faction", "") == "enemy" \
			and ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE,
		# VOW-001: active vow dict (or {}) for BehaviorArbiter vow bias layer.
		"active_vow":              _vow_ctx,
		# VOW-001: echo party size for tikoro_nko_agyina party-size gate.
		"party_size":              ectx.actors.filter(func(a): return str(a.get("faction","")) == "echo" and not bool(a.get("is_dead", false))).size(),
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
					# In-combat fear accumulation: each hit adds fear pressure to the defender (runtime dict only).
					var combat_emo_cfg: Dictionary = bdata.get("combat", {}).get("emotion", {})
					var fear_per_hit: int = int(combat_emo_cfg.get("fear_per_hit", 2))
					target["fear"] = mini(100, int(target.get("fear", 0)) + fear_per_hit)
					logger.debug(t, "combat.fear.hit", "%s gains fear from hit" % target.get("name", "?"), {
						"actor_id": str(target.get("id", "")),
						"delta":    fear_per_hit,
						"new_fear": int(target.get("fear", 0)),
					})
					# Kill bonus: killer gets morale + fear reduction; living Echo allies get a ripple.
					if result.get("is_kill", false):
						var morale_per_kill: int      = int(combat_emo_cfg.get("morale_per_kill",       25))
						var fear_reduce_per_kill: int = int(combat_emo_cfg.get("fear_reduce_per_kill",  15))
						var morale_ripple: int         = int(combat_emo_cfg.get("morale_ripple_per_kill", 10))
						var fear_ripple: int           = int(combat_emo_cfg.get("fear_ripple_per_kill",    5))
						actor["morale"] = mini(100, int(actor.get("morale", 50)) + morale_per_kill)
						actor["fear"]   = maxi(0,   int(actor.get("fear",   0)) - fear_reduce_per_kill)
						logger.info(t, "combat.kill_boost", "%s gains morale from kill" % actor.get("name", "?"), {
							"actor_id":     str(actor.get("id", "")),
							"morale_delta": morale_per_kill,
							"fear_delta":   -fear_reduce_per_kill,
						})
						for ally_v in ectx.actors:
							var ally: Dictionary = ally_v if ally_v is Dictionary else {}
							if str(ally.get("id", "")) == str(actor.get("id", "")): continue
							if ally.get("is_dead", false): continue
							if str(ally.get("faction", "")) != "echo": continue
							ally["morale"] = mini(100, int(ally.get("morale", 50)) + morale_ripple)
							ally["fear"]   = maxi(0,   int(ally.get("fear",   0)) - fear_ripple)
							logger.info(t, "combat.kill_ripple",
								"%s ripple from %s kill" % [ally.get("name", "?"), actor.get("name", "?")], {
								"ally_id":      str(ally.get("id", "")),
								"morale_delta": morale_ripple,
								"fear_delta":   -fear_ripple,
							})
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

	# PROG-003: accumulate echo action log for XP virtue multiplier at resolve.
	# Only echo-faction actors contribute. Accumulated across all rounds.
	if str(actor.get("faction", "")) == "echo" and not ectx.last_round_results.is_empty():
		var last_res: Dictionary = ectx.last_round_results.back()
		var eid: String = str(actor.get("id", ""))
		if not ectx.echo_action_logs.has(eid):
			ectx.echo_action_logs[eid] = { "melee_count": 0, "guard_count": 0, "kill_count": 0, "total_count": 0 }
		var alog: Dictionary = ectx.echo_action_logs[eid]
		match str(last_res.get("action_type", "")):
			"melee_attack":
				alog["melee_count"] += 1
				alog["total_count"] += 1
				if bool(last_res.get("is_kill", false)):
					alog["kill_count"] += 1
					# XP tuning: kill XP applied immediately for mid-combat stat bump.
					var roster_echo: Dictionary = _find_roster_echo(str(actor.get("id", "")))
					if not roster_echo.is_empty():
						ProgressionService.apply_mid_combat_kill_xp(
							roster_echo, actor, prog_cfg_block, birth_stats_block,
							_get_realm_xp_multiplier(), logger, t
						)
			"actor.guard":
				alog["guard_count"] += 1
				alog["total_count"] += 1
			"actor.move", "actor.idle", "actor.refuse":
				alog["total_count"] += 1

	# Advance current_actor_index past this actor so the next call finds the correct one.
	combat_state["current_actor_index"] = next_idx + 1

	# Emit per-actor snapshot — UI shows updated board + arrow + action text for this actor.
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)
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

	# COMBAT-006: apply per-round shrine drain before end-condition check (drain can kill shrine).
	var shrine_hp_val: int = 0
	if ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
		var balance_drain: Dictionary = config_service.get_balance()
		var shrine_cfg_drain: Dictionary = balance_drain.get("data", {}).get("combat", {}).get("shrine", {})
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				var drain_result: Dictionary = ShrineService.apply_drain(a_v, shrine_cfg_drain)
				shrine_hp_val = int(drain_result.get("shrine_hp", 0))
				if shrine_hp_val <= 0:
					a_v["is_dead"]     = true
					a_v["death_round"] = round
				logger.info(t, "combat.shrine_drain", "Shrine drained this round", {
					"shrine_id":     str(a_v.get("id", "")),
					"drain":         int(drain_result.get("drain", 0)),
					"shrine_hp":     shrine_hp_val,
					"stacks_active": a_v.get("purify_stacks", []).size(),
				})
				# Decrement purifier cooldown (min 0).
				if not ectx.purifier_id.is_empty():
					for pa_v in ectx.actors:
						if pa_v is Dictionary and str(pa_v.get("id", "")) == ectx.purifier_id:
							pa_v["purify_cooldown"] = maxi(0, int(pa_v.get("purify_cooldown", 0)) - 1)
							break
				# Shrine morale drain: each wave grinds down the party's will (runtime dict only).
				var morale_drain_wave: int = int(shrine_cfg_drain.get("morale_drain_per_wave", 5))
				var shrine_morale_affected: int = 0
				for em_a in ectx.actors:
					if em_a is Dictionary and not em_a.get("is_dead", false) \
							and em_a.get("faction", "") == "echo":
						em_a["morale"] = maxi(0, int(em_a.get("morale", 50)) - morale_drain_wave)
						shrine_morale_affected += 1
				if shrine_morale_affected > 0:
					logger.info(t, "combat.shrine.morale_drain", "Shrine wave drains echo morale", {
						"delta":          -morale_drain_wave,
						"affected_count": shrine_morale_affected,
					})
				break
		# Capture shrine_hp even if alive (for snapshot).
		if shrine_hp_val == 0:
			for a_v in ectx.actors:
				if a_v is Dictionary and a_v.get("is_structure", false):
					shrine_hp_val = int(a_v.get("current_hp", 0))
					break

	# In-combat emotion tick — applied to runtime actor dicts only; save data unchanged here.
	var emo_tick_cfg: Dictionary = config_service.get_balance().get("data", {}).get("combat", {}).get("emotion", {})

	# A) Ally KO fear spread: when a comrade falls, surviving same-faction actors gain fear.
	var fear_per_ally_ko: int = int(emo_tick_cfg.get("fear_per_ally_ko", 4))
	for res_v in ectx.last_round_results:
		if res_v is Dictionary and int(res_v.get("defender_hp_after", 1)) <= 0:
			var ko_id: String = str(res_v.get("target_id", ""))
			var ko_actor: Dictionary = _find_actor_by_id(ectx.actors, ko_id)
			if ko_actor.is_empty():
				continue
			var ko_faction: String = str(ko_actor.get("faction", ""))
			var ko_spread_count: int = 0
			for sp_a in ectx.actors:
				if sp_a is Dictionary and not sp_a.get("is_dead", false) \
						and str(sp_a.get("id", "")) != ko_id \
						and str(sp_a.get("faction", "")) == ko_faction \
						and not sp_a.get("is_structure", false):
					sp_a["fear"] = mini(100, int(sp_a.get("fear", 0)) + fear_per_ally_ko)
					ko_spread_count += 1
			if ko_spread_count > 0:
				logger.info(t, "combat.fear.ally_ko", "Ally KO spreads fear to survivors", {
					"ko_actor_id":    ko_id,
					"affected_count": ko_spread_count,
					"delta":          fear_per_ally_ko,
				})

	# B) Per-round fear tick: baseline fear accumulation for all living actors.
	var fear_per_round: int = int(emo_tick_cfg.get("fear_per_round", 1))
	for tick_a in ectx.actors:
		if tick_a is Dictionary and not tick_a.get("is_dead", false) \
				and not tick_a.get("is_structure", false):
			tick_a["fear"] = mini(100, int(tick_a.get("fear", 0)) + fear_per_round)
	logger.debug(t, "combat.emotion.tick", "Round fear tick applied", {
		"round":      round,
		"fear_delta": fear_per_round,
	})

	# C) Morale decay every N rounds: long fights grind echo morale (echo actors only).
	var morale_decay_n: int  = int(emo_tick_cfg.get("morale_decay_n_rounds", 3))
	var morale_decay_amt: int = int(emo_tick_cfg.get("morale_decay_amount", 1))
	if morale_decay_n > 0 and round % morale_decay_n == 0:
		for dec_a in ectx.actors:
			if dec_a is Dictionary and not dec_a.get("is_dead", false) \
					and dec_a.get("faction", "") == "echo":
				dec_a["morale"] = maxi(0, int(dec_a.get("morale", 50)) - morale_decay_amt)
		logger.debug(t, "combat.emotion.morale_decay", "Round morale decay applied", {
			"round": round,
			"delta": -morale_decay_amt,
		})

	# Check end condition.
	var end_check: Dictionary = CombatState.check_end_condition(ectx.actors, ectx.resolution_mode)
	if end_check.get("over", false):
		combat_state["combat_over"] = true
		# COMBAT-005: store result on ectx so build_snapshot() can surface it.
		# COMBAT-006: include shrine_hp in result for snapshot display.
		ectx.combat_result = {
			"victory":     bool(end_check.get("victory", false)),
			"reason":      str(end_check.get("reason", "")),
			"round_ended": round,
			"shrine_hp":   shrine_hp_val,
		}
		logger.info(t, "combat.end", "Combat ended", {
			"victory":   bool(end_check.get("victory", false)),
			"reason":    str(end_check.get("reason", "")),
			"round":     round,
			"shrine_hp": shrine_hp_val,
		})

	# Reset round-phase state — snapshot will show cta.confirm_round (or nothing if combat_over).
	combat_state["round_phase"]          = "idle"
	combat_state["current_actor_index"]  = 0
	combat_state["active_initiative_index"] = 0
	ectx.last_actor_action = {}

	# COMBAT-007: build the appropriate snapshot and persist it in-memory on ectx.
	if bool(combat_state.get("combat_over", false)):
		# FinalCombatSnapshot — emits type "flow.resolve"; stored on ectx.final_snapshot.
		var final_snap: Dictionary = FlowEncounterState.build_final_snapshot(flow_ctx, t)
		ectx.final_snapshot    = final_snap
		flow_ctx.last_snapshot = final_snap
	else:
		# RoundSnapshot — emits type "flow.encounter"; stored on ectx.last_round_snapshot.
		var round_snap: Dictionary = FlowEncounterState.build_round_snapshot(flow_ctx, t)
		ectx.last_round_snapshot = round_snap
		flow_ctx.last_snapshot   = round_snap
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
	# COMBAT-007: include field_count for determinism audit (LOG_SNAPSHOT_EMITTED contract).
	var data_v: Variant = snapshot.get("data", {})
	var field_count: int = data_v.size() if data_v is Dictionary else 0
	logger.debug(t, "snapshot.emitted", "Snapshot emitted", {
		"reason":        reason,
		"snapshot_type": str(snapshot.get("type", "")),
		"field_count":   field_count,
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
	# Allow from EchoParty only; ignore elsewhere.
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.party.toggle.ignored", "Party toggle ignored (not in echo party)", {
			"snapshot_type": snap_type
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

		# BOND-001: record party encounter with all current party members (before this echo was added)
		if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
			flow_ctx.save_data["sanctum"] = {}
		var bond_sanctum: Dictionary = flow_ctx.save_data["sanctum"] as Dictionary
		var enc_v = bond_sanctum.get("party_encounters", [])
		var encounters: Array = enc_v if enc_v is Array else []
		for existing_id_v in flow_ctx.pending_party_ids:
			var existing_id: String = str(existing_id_v)
			if existing_id == echo_id:
				continue
			encounters = SocialGraphService.record_encounter(encounters, echo_id, existing_id)
		bond_sanctum["party_encounters"] = encounters

	logger.debug(t, "sanctum.party.toggle", "Party toggled", {
		"echo_id": echo_id,
		"added": added,
		"pending_count": flow_ctx.pending_party_ids.size(),
		"max_party_size": max_party_size
	})

	# Immediate apply: persist selection on each toggle.
	if not flow_ctx.save_data.has("sanctum") or typeof(flow_ctx.save_data["sanctum"]) != TYPE_DICTIONARY:
		flow_ctx.save_data["sanctum"] = {}
	var sanctum_for_save: Dictionary = flow_ctx.save_data["sanctum"]
	sanctum_for_save["active_party_ids"] = flow_ctx.pending_party_ids.duplicate()
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|sanctum.party.autosave"
	else:
		flow_ctx.save_request_reason = "sanctum.party.autosave"

	flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_weave_start_for_echo(action: Dictionary, t: int) -> void:
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY and snap_type != FlowStateIds.SANCTUM:
		logger.debug(t, "weave.start_for_echo.ignored", "weave.start_for_echo ignored outside Sanctum family", {
			"snapshot_type": snap_type,
		})
		return

	var echo_id := str(action.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Missing echo_id for rite start", {})
		return

	var echo_ref := _find_roster_echo(echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Echo not found in roster", {
			"echo_id": echo_id,
		})
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	if threads.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "No threads in reserve", {
			"echo_id": echo_id,
		})
		return

	flow_ctx.selected_weave_echo_id = echo_id
	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	flow_machine.transition(FlowStateIds.WEAVING_RITE, flow_ctx, logger, t, "ui.weave.start_for_echo")


func _handle_weave_begin_rite(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.begin_rite.ignored", "weave.begin_rite ignored outside rite state", {})
		return

	var thread_id := str(flow_ctx.selected_weave_thread_id).strip_edges()
	var echo_id := str(flow_ctx.selected_weave_echo_id).strip_edges()
	if thread_id.is_empty() or echo_id.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Missing selected thread or echo", {
			"thread_id": thread_id,
			"echo_id": echo_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var thread_v: Variant = threads.get(thread_id, {})
	if not (thread_v is Dictionary):
		logger.debug(t, "weave.begin_rite.denied", "Selected thread not found in reserve", {
			"thread_id": thread_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return
	var thread: Dictionary = thread_v

	var echo_ref := _find_roster_echo(echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Selected echo not found in roster", {
			"echo_id": echo_id,
		})
		flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var rite_cfg := _get_weaving_rite_cfg()
	var resonance_candidates: Array = WeavingRiteServiceScript.get_candidates(thread, roster, flow_ctx.save_data, rite_cfg)

	var outcome: String = WeavingRiteServiceScript.resolve_outcome(echo_ref, thread, flow_ctx.save_data, rite_cfg)
	flow_ctx.weave_commit_locked = true
	WeavingRiteServiceScript.apply_outcome(outcome, echo_id, thread_id, flow_ctx.save_data, logger, t)

	var non_chosen: Array = []
	non_chosen = WeavingRiteServiceScript.get_non_chosen_consequences(resonance_candidates, echo_id, outcome, rite_cfg)
	if not non_chosen.is_empty():
		_apply_weave_non_chosen_consequences(non_chosen, echo_id, t)

	flow_ctx.weave_resolution = {
		"outcome": outcome,
		"thread_id": thread_id,
		"thread_virtue": str(thread.get("virtue", "unknown")),
		"thread_quality_tier": str(thread.get("quality_tier", "broken")),
		"echo_id": echo_id,
		"echo_name": str(echo_ref.get("name", "")),
		"non_chosen": non_chosen,
		"aftermath_lines": _build_weave_aftermath_lines(outcome, echo_ref, thread, non_chosen),
	}

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|weave.begin_rite"
	else:
		flow_ctx.save_request_reason = "weave.begin_rite"

	flow_ctx.last_snapshot = FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_weave_confirm(t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.confirm.ignored", "weave.confirm ignored outside rite state", {})
		return

	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.selected_weave_echo_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.weave.confirm")


func _apply_weave_non_chosen_consequences(non_chosen: Array, chosen_id: String, t: int) -> void:
	if non_chosen.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v

	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var thresholds := _get_bond_thresholds_cfg()

	var drift := _get_drift_cfg()
	var fear_threshold := int(drift.get("fear_threshold", 80))
	var applied := 0
	for c_v in non_chosen:
		if not (c_v is Dictionary):
			continue
		var c: Dictionary = c_v
		var target_id := str(c.get("echo_id", "")).strip_edges()
		if target_id.is_empty() or target_id == chosen_id:
			continue

		var echo_ref := _find_roster_echo(target_id)
		if echo_ref.is_empty():
			continue

		var morale_delta := int(c.get("morale_delta", 0))
		var fear_delta := int(c.get("fear_delta", 0))
		var bond_delta := int(c.get("bond_delta", 0))

		if morale_delta != 0:
			EmotionService.apply_morale_delta(echo_ref, morale_delta, "weave.non_chosen", logger, t)
		if fear_delta != 0:
			EmotionService.apply_fear_delta(echo_ref, fear_delta, "weave.non_chosen", fear_threshold, logger, t)
		if bond_delta != 0:
			bonds = SocialGraphService.apply_score_delta(
				bonds,
				chosen_id,
				target_id,
				bond_delta,
				thresholds,
				logger,
				t
			)
		applied += 1

	sanctum["bonds"] = bonds
	flow_ctx.save_data["sanctum"] = sanctum

	if applied > 0:
		logger.info(t, "weave.non_chosen.applied", "Applied non-chosen weave consequences", {
			"chosen_id": chosen_id,
			"affected_count": applied,
		})


func _build_weave_aftermath_lines(outcome: String, echo: Dictionary, thread: Dictionary, non_chosen: Array) -> Array:
	var echo_name := str(echo.get("name", "This echo"))
	var virtue := str(thread.get("virtue", "story"))
	var lines: Array = []
	match outcome:
		"accept":
			lines.append("%s accepts the %s thread." % [echo_name, virtue])
			lines.append("The weave settles and the reserve releases its hold.")
			if not non_chosen.is_empty():
				lines.append("The other resonant Echoes leave with tightened bonds and shaken hearts.")
		"reject":
			lines.append("%s rejects the %s thread." % [echo_name, virtue])
			lines.append("The thread is consumed in refusal, and identity is clarified.")
			if not non_chosen.is_empty():
				lines.append("Others who leaned toward this thread take the refusal personally.")
		"defer":
			lines.append("%s defers the %s thread." % [echo_name, virtue])
			lines.append("A memory mark remains; the thread returns to reserve.")
			if not non_chosen.is_empty():
				lines.append("The waiting unsettles nearby hearts, even without full rupture.")
		_:
			lines.append("The rite resolves without a clear outcome.")
	return lines


func _get_weaving_rite_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rite_v: Variant = data.get("weaving_rite", {})
	return rite_v if rite_v is Dictionary else {}


func _get_bond_thresholds_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var thresholds_v: Variant = sanctum_cfg.get("bond_thresholds", {})
	return thresholds_v if thresholds_v is Dictionary else {}
	
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

# PROG-004: Executes Keeper-confirmed rank-up for a single echo.
# Valid from ECHO_PARTY snapshots.
func _handle_sanctum_rank_up(action: Dictionary, t: int) -> void:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.rank_up.ignored", "Rank-up ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (missing echo_id)", {})
		return

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	var echo_idx: int = -1
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			echo_idx = i
			break

	if echo_idx == -1:
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	# Read prog_cfg and calling_cfg from balance.json.
	var prog_cfg_v: Variant = {}
	var birth_stats_v: Variant = {}
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		prog_cfg_v    = bd.get("progression", {})
		birth_stats_v = bd.get("summoning", {}).get("birth_stats", {})
		calling_cfg_v = bd.get("calling", {})
	var prog_cfg: Dictionary    = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var birth_stats: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Guard: must be eligible.
	if not ProgressionService.is_rank_up_eligible(echo_ref, prog_cfg):
		logger.debug(t, "sanctum.rank_up.denied", "Rank-up denied (not eligible)", {
			"echo_id": echo_id,
			"level": int(echo_ref.get("level", 1)),
			"rank":  int(echo_ref.get("rank", 1)),
		})
		return

	# Execute rank-up — mutates echo_ref in place (roster[echo_idx] is the same ref).
	var event: Dictionary = ProgressionService.execute_rank_up(
		echo_ref,
		flow_ctx.campaign_seed,
		prog_cfg,
		birth_stats,
		calling_cfg,
		logger,
		t
	)

	# Persist.
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|progression.rank_up"
	else:
		flow_ctx.save_request_reason = "progression.rank_up"

	# Rebuild EchoParty snapshot with updated roster data.
	flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)

	# Attach the rank-up event to the snapshot data so the UI can drive the reveal overlay.
	if flow_ctx.last_snapshot.has("data") and flow_ctx.last_snapshot["data"] is Dictionary:
		flow_ctx.last_snapshot["data"]["rank_up_event"] = event


# PROG-007: Confirms a Keeper-chosen calling for an echo.
# Valid from ECHO_PARTY snapshots.
func _handle_sanctum_calling_confirm(action: Dictionary, t: int) -> void:
	var snap_type: String = str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY:
		logger.debug(t, "sanctum.calling.ignored", "Calling confirm ignored (not in echo party)", {
			"snapshot_type": snap_type
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id: String = str(payload.get("echo_id", "")).strip_edges()
	var chosen_calling_id: String = str(payload.get("chosen_calling_id", "")).strip_edges()

	if echo_id.is_empty() or chosen_calling_id.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (missing echo_id or chosen_calling_id)", {})
		return

	# Find echo in roster.
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var echo_ref: Dictionary = {}
	for i in range(roster.size()):
		if roster[i] is Dictionary and str(roster[i].get("id", "")) == echo_id:
			echo_ref = roster[i]
			break

	if echo_ref.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (echo not in roster)", {
			"echo_id": echo_id
		})
		return

	# Guard: must have a calling pending (calling_eligible=true and no calling set yet).
	if not CallingService.is_calling_pending(echo_ref):
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (no calling pending)", {
			"echo_id":         echo_id,
			"calling_eligible": bool(echo_ref.get("calling_eligible", false)),
			"calling":         str(echo_ref.get("calling", "")),
		})
		return

	# Read calling_cfg from balance.json.
	var calling_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		calling_cfg_v = bal.get("data", {}).get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}

	# Confirm the calling — mutates echo_ref in place.
	var confirmed: String = CallingService.confirm_calling(echo_ref, chosen_calling_id, calling_cfg, logger, t)
	if confirmed.is_empty():
		logger.debug(t, "sanctum.calling.denied", "Calling confirm denied (invalid chosen_calling_id)", {
			"echo_id":           echo_id,
			"chosen_calling_id": chosen_calling_id,
		})
		return

	# Persist.
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|progression.calling.confirm"
	else:
		flow_ctx.save_request_reason = "progression.calling.confirm"

	# Rebuild EchoParty snapshot.
	flow_ctx.last_snapshot = FlowEchoPartyState.build_snapshot(flow_ctx, t)

	# Attach calling_event so UI can react (clear pending indicator, etc.).
	if flow_ctx.last_snapshot.has("data") and flow_ctx.last_snapshot["data"] is Dictionary:
		flow_ctx.last_snapshot["data"]["calling_event"] = {
			"echo_id":    echo_id,
			"calling":    confirmed,
		}


# V2-DIRECTIVE-001: writes the chosen directive to stage_context, requests save, refreshes snapshot.
func _handle_directive_select(action: Dictionary, t: int) -> void:
	var id := str(action.get("directive_id", ""))
	directive_service.set_active_directive(id, logger, t)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|directive.select"
	else:
		flow_ctx.save_request_reason = "directive.select"
	# Lesson 9: non-SANCTUM states read ctx.last_snapshot as-is on refresh.
	# STAGE uses static build_snapshot() — rebuild before refresh so snapshot reflects the new choice.
	if flow_ctx.last_snapshot.get("type", "") == FlowStateIds.STAGE:
		flow_ctx.last_snapshot = FlowStageState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ── XP tuning helpers (ST5) ──────────────────────────────────────────────────

## Returns the save_data roster entry for the given echo_id, or {} if not found.
func _find_roster_echo(echo_id: String) -> Dictionary:
	if echo_id.is_empty():
		return {}
	var sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not sanc_v is Dictionary:
		return {}
	var roster_v: Variant = (sanc_v as Dictionary).get("roster", [])
	if not roster_v is Array:
		return {}
	for entry_v in roster_v:
		if entry_v is Dictionary and str(entry_v.get("id", "")) == echo_id:
			return entry_v as Dictionary
	return {}


## PROG-009: Assigns a skill to an echo slot while on STAGE_MAP party prep.
## Updates flow_ctx.pending_equipped_skills and rebuilds the STAGE_MAP snapshot.
func _handle_skill_assign(action: Dictionary, t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.assign.ignored", "skill.assign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id  := str(payload.get("echo_id",  "")).strip_edges()
	var slot     := str(payload.get("slot",     "0")).strip_edges()
	var skill_id := str(payload.get("skill_id", "")).strip_edges()

	if echo_id.is_empty() or skill_id.is_empty():
		logger.debug(t, "skill.assign.denied", "skill.assign missing echo_id or skill_id", { "payload": payload })
		return

	if not flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id] = {}
	flow_ctx.pending_equipped_skills[echo_id][slot] = skill_id

	logger.debug(t, "skill.assign", "Skill assigned", {
		"echo_id": echo_id, "slot": slot, "skill_id": skill_id
	})
	flow_ctx.last_snapshot = FlowStageMapState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## PROG-009: Unassigns a skill from an echo slot while on STAGE_MAP party prep.
func _handle_skill_unassign(action: Dictionary, t: int) -> void:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.STAGE_MAP:
		logger.debug(t, "skill.unassign.ignored", "skill.unassign outside STAGE_MAP", {
			"snapshot_type": str(flow_ctx.last_snapshot.get("type", ""))
		})
		return

	var payload_v: Variant = action.get("payload", {})
	var payload: Dictionary = payload_v if payload_v is Dictionary else {}
	var echo_id := str(payload.get("echo_id", "")).strip_edges()
	var slot    := str(payload.get("slot",    "0")).strip_edges()

	if echo_id.is_empty():
		logger.debug(t, "skill.unassign.denied", "skill.unassign missing echo_id", {})
		return

	if flow_ctx.pending_equipped_skills.has(echo_id):
		flow_ctx.pending_equipped_skills[echo_id].erase(slot)

	logger.debug(t, "skill.unassign", "Skill unassigned", {
		"echo_id": echo_id, "slot": slot
	})
	flow_ctx.last_snapshot = FlowStageMapState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## PROG-009: Persists pending_equipped_skills to each echo in the roster and flags a save.
## Called by flow.select_stage (on cta.enter_stage) before transitioning to STAGE.
func _persist_equipped_skills(t: int) -> void:
	if flow_ctx.pending_equipped_skills.is_empty():
		return

	var sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanc_v if sanc_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	for echo_id in flow_ctx.pending_equipped_skills.keys():
		var eq: Dictionary = flow_ctx.pending_equipped_skills[echo_id]
		for i in range(roster.size()):
			var e: Dictionary = roster[i] if roster[i] is Dictionary else {}
			if str(e.get("id", "")) == str(echo_id):
				roster[i]["equipped_skills"] = eq.duplicate()
				break

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|skill.persist"
	else:
		flow_ctx.save_request_reason = "skill.persist"

	logger.info(t, "skill.persist", "Equipped skills persisted to save", {
		"equipped_count": flow_ctx.pending_equipped_skills.size()
	})


## Returns the realm XP multiplier for the current realm based on run_index.
## Reads realm_id from flow_ctx and run_index from save_data["realms"].
## Returns 1.0 on any guard failure.
func _get_realm_xp_multiplier() -> float:
	if flow_ctx == null:
		return 1.0
	var realm_id: String = str(flow_ctx.realm_id)
	if realm_id.is_empty():
		return 1.0
	var prog_cfg_v: Variant = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd: Dictionary  = bal.get("data", {})
		prog_cfg_v = bd.get("progression", {})
	var prog_cfg_r: Dictionary = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var rate: float = float(prog_cfg_r.get("realm_xp_multiplier_per_realm", 0.0))
	if rate <= 0.0:
		return 1.0
	var realms_v: Variant = flow_ctx.save_data.get("realms", {})
	if not realms_v is Dictionary:
		return 1.0
	var realm_entry_v: Variant = (realms_v as Dictionary).get(realm_id, {})
	if not realm_entry_v is Dictionary:
		return 1.0
	var run_idx: int = int((realm_entry_v as Dictionary).get("run_index", 0))
	return 1.0 + float(run_idx) * rate


# ---------------------------------------------------------------------------
# VOW-001 handlers
# ---------------------------------------------------------------------------

func _handle_vow_pledge(action: Dictionary, t: int) -> void:
	var vow_id := str(action.get("vow_id", ""))
	var tier   := int(action.get("tier", 1))

	if vow_id.is_empty():
		logger.debug(t, "vow.pledge_denied", "Missing vow_id in action", { "action": action })
		flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	var cfg := config_service.get_balance()
	var ok := VowService.pledge_vow(vow_id, tier, cfg, flow_ctx.save_data, flow_ctx, logger, t)
	# Rebuild snapshot from current save_data so UI reflects the pledge outcome.
	# refresh_snapshot() reads ctx.last_snapshot as-is for non-SANCTUM states — must
	# assign the rebuilt snapshot first (same pattern as FlowSummonState.build_snapshot).
	flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
	if ok:
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
	else:
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_vow_break(t: int) -> void:
	var cfg := config_service.get_balance()

	var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
	if summary.is_empty():
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# Apply morale and fear deltas to all roster echoes via EmotionService
	var morale_d := int(summary.get("morale_delta", 0))
	var fear_d   := int(summary.get("fear_delta", 0))

	if (morale_d != 0 or fear_d != 0) and flow_ctx.save_data.has("sanctum"):
		var sanctum_v: Variant = flow_ctx.save_data["sanctum"]
		if sanctum_v is Dictionary:
			var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
			if roster_v is Array:
				var roster: Array = roster_v
				var cfg_em: Dictionary = cfg.get("emotion", {})
				var fear_threshold := int(cfg_em.get("fear_threshold", 80))
				for echo_v in roster:
					if not (echo_v is Dictionary):
						continue
					var echo: Dictionary = echo_v
					var eid := str(echo.get("id", ""))
					if eid.is_empty():
						continue
					if morale_d != 0:
						EmotionService.apply_morale_delta(
							echo, morale_d, "vow.break", logger, t
						)
					if fear_d != 0:
						EmotionService.apply_fear_delta(
							echo, fear_d, "vow.break", fear_threshold, logger, t
						)

	# Rebuild snapshot from current save_data so UI reflects the break outcome.
	flow_ctx.last_snapshot = FlowVowState.build_snapshot(flow_ctx, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


func _handle_debug_vow_unlock(action: Dictionary, t: int) -> void:
	var vow_id := str(action.get("vow_id", ""))
	if vow_id.is_empty():
		push_warning("debug.vow.unlock: missing vow_id")
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return
	VowService.unlock_vow(vow_id, "debug", flow_ctx.save_data, flow_ctx, logger, t)
	flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-001: Stage exploration handlers
# ────────────────────────────────────────────────────────────────────────────

## Move the party to the nearest unresolved situation (directive-guided).
## On arrival: runs a stub reveal check.
##   - High roll (>50): situation is revealed; snapshot rebuilt to show type.
##   - Low roll (<=50): party stumbles in blind → dispatch stage.engage_situation.
## If situation was already revealed on arrival → dispatch stage.engage_situation.
func _handle_stage_advance_turn(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.advance.no_stage", "advance_turn: no active stage", {})
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	if str(explore_map.get("party_state", "")) != StageExploreModelScript.STATE_EXPLORING:
		logger.debug(t, "stage.advance.not_exploring", "advance_turn: party not in exploring state", {
			"party_state": explore_map.get("party_state", "")
		})
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# Find target situation based on active directive
	var active_dir := str(flow_ctx.save_data.get("stage_context", {}).get("active_directive_id", "directive.scout_carefully"))
	var target_sit := _find_target_situation(explore_map, active_dir)

	if target_sit.is_empty():
		# No unresolved situations left — should not normally reach here; guard gracefully
		logger.debug(t, "stage.advance.no_target", "advance_turn: no unresolved situations found", {})
		flow_machine.refresh_snapshot(flow_ctx, logger, t)
		return

	# Move party to situation position
	var sit_pos_v: Variant = target_sit.get("pos", { "col": 0, "row": 0 })
	var sit_pos: Dictionary = sit_pos_v if sit_pos_v is Dictionary else { "col": 0, "row": 0 }
	explore_map["party_pos"]         = sit_pos
	explore_map["turn_count"]        = int(explore_map.get("turn_count", 0)) + 1
	explore_map["last_situation_id"] = str(target_sit.get("id", ""))

	var sit_id     := str(target_sit.get("id", "sit.0"))
	var turn_count := int(explore_map.get("turn_count", 0))

	# Reveal check — run before save so result is persisted in one write
	if not bool(target_sit.get("revealed", false)):
		var rng := CampaignSeed.get_rng_from(
			int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0)),
			"stage.reveal.%s.%d" % [sit_id, turn_count]
		)
		if rng.randi_range(0, 100) > 50:
			# Scout roll succeeded — mark revealed before the engagement popup
			var sits_v2: Variant = explore_map.get("situations", [])
			var sits_arr: Array  = sits_v2 if sits_v2 is Array else []
			for _si in range(sits_arr.size()):
				var s_v2: Variant = sits_arr[_si]
				if s_v2 is Dictionary and str((s_v2 as Dictionary).get("id", "")) == sit_id:
					var s2: Dictionary = s_v2
					s2["revealed"] = true
					sits_arr[_si]  = s2
					break
			explore_map["situations"] = sits_arr

	# Park the party — player confirms engagement via situation popup
	explore_map["pending_situation_id"] = sit_id
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request        = true
	flow_ctx.save_request_reason = "stage.advance_turn"

	logger.info(t, "stage.advance_turn", "Party moved to situation (pending engagement)", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
		"turn_count":   explore_map["turn_count"],
	})

	flow_machine.refresh_snapshot(flow_ctx, logger, t)


## Party attempts to return home before completing all objectives.
## Stub escape check: seeded roll > 40 = success.
## Success → party_state = "escaped", transition to flow.stage_map.
## Failure → return_failed flag in snapshot (full mechanic deferred to V2-INTEL-002).
func _handle_stage_return_home(_action: Dictionary, t: int) -> void:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.return.no_stage", "return_home: no active stage", {})
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var turn_count := int(explore_map.get("turn_count", 0))
	var realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))

	var rng := CampaignSeed.get_rng_from(
		realm_seed,
		"stage.escape.%s.%d" % [flow_ctx.stage_id, turn_count]
	)
	var roll := rng.randi_range(0, 100)
	var success := roll > 40

	logger.info(t, "stage.return_home", "Party return home attempt", {
		"stage_id":   flow_ctx.stage_id,
		"roll":       roll,
		"success":    success,
		"turn_count": turn_count,
	})

	if success:
		explore_map["party_state"] = StageExploreModelScript.STATE_ESCAPED
		stage["explore_map"] = explore_map
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		flow_ctx.save_request = true
		flow_ctx.save_request_reason = "stage.escaped"
		flow_machine.transition(FlowStateIds.STAGE_MAP, flow_ctx, logger, t, "stage.return_home.success")
	else:
		# Escape failed — rebuild snapshot with return_failed flag for UI feedback
		# Full consequence mechanic deferred to V2-INTEL-002
		stage["explore_map"] = explore_map
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		var snap := FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
		snap["data"]["return_failed"] = true
		flow_ctx.last_snapshot = snap
		flow_machine.refresh_snapshot(flow_ctx, logger, t)


## Resolve a situation the party has reached.
## Marks situation resolved + revealed. Increments objectives_found if applicable.
## Routes: combat → flow.encounter; npc/loot/money → inline overlay stub.
## All objectives found → flow.complete_stage.
func _handle_stage_engage_situation(action: Dictionary, t: int) -> void:
	var sit_id := str(action.get("situation_id", ""))
	if sit_id.is_empty():
		logger.debug(t, "stage.engage.no_id", "engage_situation: missing situation_id", {})
		return

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	# Clear pending state — engagement is now committed
	explore_map["pending_situation_id"] = ""
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	# Find and mutate the situation
	var sit: Dictionary = {}
	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s["resolved"] = true
			s["revealed"] = true
			situations[i] = s
			sit = s
			break

	if sit.is_empty():
		logger.debug(t, "stage.engage.not_found", "engage_situation: situation not found", {
			"situation_id": sit_id
		})
		return

	# Update objectives_found
	if bool(sit.get("is_objective", false)):
		explore_map["objectives_found"] = int(explore_map.get("objectives_found", 0)) + 1

	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.engage_situation"

	logger.info(t, "stage.engage_situation", "Party engaged situation", {
		"stage_id":      flow_ctx.stage_id,
		"situation_id":  sit_id,
		"type":          str(sit.get("type", "")),
		"is_objective":  sit.get("is_objective", false),
		"obj_found":     explore_map.get("objectives_found", 0),
		"obj_total":     explore_map.get("objectives_total", 0),
	})

	# Check if all objectives are found → complete the stage
	var obj_found := int(explore_map.get("objectives_found", 0))
	var obj_total := int(explore_map.get("objectives_total", 0))
	if obj_total > 0 and obj_found >= obj_total:
		explore_map["party_state"] = StageExploreModelScript.STATE_COMPLETE
		stage["explore_map"] = explore_map
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		_handle_complete_stage(t, "")
		return

	# Route by situation type
	var sit_type := str(sit.get("type", ""))
	match sit_type:
		SituationModelScript.TYPE_COMBAT:
			flow_machine.transition(FlowStateIds.ENCOUNTER, flow_ctx, logger, t, "stage.engage.combat")
		_:
			# NPC / loot / money — inline placeholder overlay (V2-STAGE-003 / V2-STAGE-004 will replace)
			var result_text := _stub_situation_result(sit_type)
			var snap := FlowStageExploreStateScript.build_snapshot(flow_ctx, t)
			snap["data"]["situation_overlay"] = {
				"situation_id": sit_id,
				"type":         sit_type,
				"result_text":  result_text,
			}
			flow_ctx.last_snapshot = snap
			flow_machine.refresh_snapshot(flow_ctx, logger, t)


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-001 private helpers
# ────────────────────────────────────────────────────────────────────────────

# Find the best next unresolved situation based on active directive.
# scout_carefully → nearest unresolved (Chebyshev from party_pos)
# seek_signs      → nearest unresolved objective first; fallback nearest unresolved
func _find_target_situation(explore_map: Dictionary, directive_id: String) -> Dictionary:
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }
	var px := int(party_pos.get("col", 0))
	var py := int(party_pos.get("row", 0))

	var best_obj: Dictionary  = {}
	var best_any: Dictionary  = {}
	var best_obj_dist := 999999
	var best_any_dist := 999999

	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		var pos_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		var sx := int(pos.get("col", 0))
		var sy := int(pos.get("row", 0))
		var dist: int = max(abs(sx - px), abs(sy - py))  # Chebyshev

		if dist < best_any_dist:
			best_any_dist = dist
			best_any = sit
		if bool(sit.get("is_objective", false)) and dist < best_obj_dist:
			best_obj_dist = dist
			best_obj = sit

	if directive_id == "directive.seek_signs" and not best_obj.is_empty():
		return best_obj
	return best_any


# Mark a specific situation as revealed in save_data.
func _mark_situation_revealed(stage: Dictionary, sit_id: String, t: int) -> void:
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s["revealed"] = true
			situations[i] = s
			break

	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	flow_ctx.save_request_reason = "stage.reveal"

	logger.info(t, "stage.situation.revealed", "Situation revealed before engagement", {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": sit_id,
	})


# Returns a stub result text for non-combat situation types.
# Real outcomes deferred to V2-STAGE-003 (NPC) and V2-STAGE-004 (loot/money).
func _stub_situation_result(sit_type: String) -> String:
	match sit_type:
		SituationModelScript.TYPE_NPC:
			return "A presence stirs. The party watches, unseen. Nothing more for now."
		SituationModelScript.TYPE_LOOT:
			return "Something left behind. The party gathers what they can."
		SituationModelScript.TYPE_MONEY:
			return "An offering, unclaimed. The party takes it quietly."
		_:
			return "The party finds something unexpected. More will be known in time."
