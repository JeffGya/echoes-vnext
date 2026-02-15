extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel

var current_snapshot: Dictionary = {}
var current_save: Dictionary = {}
# AppRoot owns sim_tick for now. Replace with Flow/Encounter-owned sim_tick later.
var sim_tick: int = 0
var logger: StructuredLogger
var config_service: ConfigService

func _ready():
	# Bind renderer to UI elements it can update.
	renderer.bind_view(snapshot_view)
	
	logger = StructuredLogger.new()
	# TEMP: debug by default until DebugPanel controls log level
	logger.set_level("debug")
	
	# Connect debug panel to AppRoot
	debug_panel.command_submitted.connect(_on_debug_command)
	
	_run_boot()

func _flush_logs_to_console() -> void:
	for e in logger.get_logs():
		print(LogFormatter.format(e))
	
# TEMPORARY!!! Deterministic tick source (replace when Flow/Encounter exists)
func _next_tick() -> int:
	var t := sim_tick
	sim_tick += 1
	return t
	
func _run_boot() -> void:
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
				"tick": sim_tick
			},
			"data": {
				"message": "Configuration validation failed. See logs."
			}
		}
		
		renderer.render(current_snapshot)
		_flush_logs_to_console()
		return
	
	# Placeholder snapshot (will later come from FlowStateMachine)
	current_snapshot = {
		"type": "boot",
		"meta": {
			"version": "vNext-dev",
			"tick": sim_tick
		},
		"data": {
			"message": "System initialized.",
			"next_state": "sanctum"
		}
	}
	
	current_save = SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH, logger, _next_tick())

	if current_save.is_empty():
		# MVP: hardcoded seed for now; late Flow will decide seed creation and persistence rules
		current_save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, current_save, logger, _next_tick())
			

	logger.log_state_transition(_next_tick(), "boot", "sanctum", "save_loaded")
	
	renderer.render(current_snapshot)
	_flush_logs_to_console()

func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will route into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)
