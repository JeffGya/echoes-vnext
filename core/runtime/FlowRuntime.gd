# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

var logger: StructuredLogger
var config_service: ConfigService
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine
var econ: EconomyService

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
		"flow.advance":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.advance")

		"flow.go_state":
			var to_state := str(action.get("to", ""))
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
				
			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")

		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})

		# ---- Encounter ----
		"encounter.advance":
			var to_state := str(action.get("to", ""))
			if flow_ctx.encounter_machine == null or flow_ctx.encounter_ctx == null:
				logger.debug(t, "ui.encounter.advance", "Encounter not initialized", { "action": action })
			else:
				flow_ctx.encounter_machine.transition(to_state, flow_ctx.encounter_ctx, logger, t, "ui.encounter.advance")
				flow_machine.refresh_snapshot(flow_ctx, logger, t)

		"encounter.complete":
			flow_ctx.encounter_ctx = null
			flow_ctx.encounter_machine = null
			flow_machine.transition(FlowStateIds.RESOLVE, flow_ctx, logger, t, "ui.encounter.complete")

		# ---- Economy ----
		"economy.settle_time":
			_handle_economy_settle_time(action, t)
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
