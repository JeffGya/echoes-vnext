extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel
@onready var actions_container: Control = %ActionsContainer

# current_snapshot to be deleted after STATE-002 has been implemented properly.
var current_snapshot: Dictionary = {}
var current_save: Dictionary = {}

var logger: StructuredLogger
var config_service: ConfigService

# Flow-owned runtime
var flow_ctx: FlowContext
var flow_machine: FlowStateMachine

func _ready():
	# Bind renderer to UI elements it can update.
	renderer.bind_view(snapshot_view, actions_container)
	renderer.action_selected.connect(_on_ui_action_selected)
	
	logger = StructuredLogger.new()
	# TEMP: debug by default until DebugPanel controls log level
	logger.set_level("debug")
	
	# Connect debug panel to AppRoot
	debug_panel.command_submitted.connect(_on_debug_command)
	
	_run_boot()

func _flush_logs_to_console() -> void:
	for e in logger.get_logs():
		print(LogFormatter.format(e))
	
# Deterministic tick source owned by FlowContext.
func _next_tick() -> int:
	var t := flow_ctx.sim_tick
	flow_ctx.sim_tick += 1
	return t
	
func _run_boot() -> void:
	# Flow owned ticks should start counting.
	flow_ctx = FlowContext.new()
	flow_ctx.sim_tick = 0
	
	config_service = ConfigService.new()
	logger.debug(_next_tick(), "boot.start", "Boot sequence started", {})
	
	# Set variables for config checks
	var ok_balance := config_service.load_balance(logger, _next_tick())
	var ok_actors := config_service.load_actors(logger, _next_tick())
	var ok_realms := config_service.load_realms(logger, _next_tick())
	
	if not (ok_balance and ok_actors and ok_realms):
		# log state transition to an error state later; for now just print error snapshot
		logger.log_state_transition(_next_tick(), "boot", "error", "config_invalid")
		
		current_snapshot = {
			"type": "error",
			"meta": {
				"version": "vNext-dev",
				"tick": flow_ctx.sim_tick
			},
			"data": {
				"message": "Configuration validation failed. See logs."
			}
		}
		
		renderer.render(current_snapshot)
		_flush_logs_to_console()
		return
	
	# Check if there is a current save, if there load it if not make a new one. This should move to main menu or splash later on.
	current_save = SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH, logger, _next_tick())
	if current_save.is_empty():
		# MVP: hardcoded seed for now; late Flow will decide seed creation and persistence rules
		current_save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, current_save, logger, _next_tick())
	flow_ctx.save_data = current_save
	flow_ctx.config_service = config_service

	# We start up the Flow state machine and let it do it's thing. It will inform Approot which last snapshot should be shown.
	flow_machine = FlowStateMachine.new()
	flow_machine.register_default_states()
	
	flow_machine.start(flow_ctx, logger, _next_tick())
	current_snapshot = flow_ctx.last_snapshot
	renderer.render(current_snapshot)
	_flush_logs_to_console()

func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will route into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)

func _on_ui_action_selected(action: Dictionary) -> void:
	# Centralized, explicit action routing.
	var t := _next_tick()
	var action_type := str(action.get("type", ""))
	
	match action_type:
		"flow.advance":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.advance")
			# TODO: call flow_machine.transition(...) with correct argument order
			
		"flow.go_state":
			var to_state := str(action.get("to", ""))
			flow_machine.transition(to_state, flow_ctx, logger, t, "ui.flow.go_state")
		
		"flow.select_realm":
			# Mutate FlowContext, not UI, based on action payload,
			var realm_id := str(action.get("realm_id", ""))
			flow_ctx.realm_id = realm_id
			flow_ctx.save_request = true
			flow_ctx.save_request_reason = "realm_select"
			flow_machine.transition(FlowStateIds.STAGE, flow_ctx, logger, t, "ui.flow.select_stage")
		
		"flow.continue":
			var is_first_boot: bool = flow_ctx.save_data.get("first_boot", true)

			if is_first_boot:
				# MVP: initialize a new game state in the save (minimal placeholder).
				# Later: branch to tutorial/cutscene state before sanctum.
				flow_ctx.save_data["first_boot"] = false
				flow_ctx.save_request = true
				flow_ctx.save_request_reason = "continue_first_boot"

			flow_machine.transition(FlowStateIds.SANCTUM, flow_ctx, logger, t, "ui.flow.continue")
		
		"flow.settings":
			logger.debug(t, "ui.flow.settings", "Settings not implemented (MVP).", {})

		"flow.quit":
			logger.debug(t, "ui.flow.quit", "Quit not implemented (MVP).", {})
		
		_:
			logger.debug(t, "ui.action.unknown", "Unkown action type", { "action": action })
	
	# Re-render whatever Flow decided is current
	current_snapshot = flow_ctx.last_snapshot
	renderer.render(current_snapshot)
	_flush_logs_to_console()
