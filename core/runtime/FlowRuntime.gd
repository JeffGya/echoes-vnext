# res://core/runtime/FlowRuntime.gd
class_name FlowRuntime
extends RefCounted

var logger: StructuredLogger
var config_service: ConfigService
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine

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
			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")

		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})

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

		_:
			logger.debug(t, "ui.action.unknown", "Unknown action type", { "action": action })

	# If we just entered flow.encounter, bootstrap the Encounter machine.
	_ensure_encounter_started(t)

	# IMPORTANT: Subtask 2 will keep behavior identical:
	# return whatever Flow decided is current
	var out := flow_ctx.last_snapshot
	_log_snapshot_emitted(t, out, "dispatch")
	return out

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
