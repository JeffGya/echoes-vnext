extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel
@onready var actions_container: Control = %ActionsContainer

var runtime: FlowRuntime

var _last_log_index: int = 0

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
	
	config_service = ConfigService.new()
	runtime = FlowRuntime.new(logger, config_service)
	var snap := runtime.boot()
	renderer.render(snap)
	_flush_logs_to_console()
	
	# Connect debug panel to AppRoot
	debug_panel.command_submitted.connect(_on_debug_command)
	
	#_run_boot()

func _flush_logs_to_console() -> void:
	var logs := logger.get_logs()
	for i in range(_last_log_index, logs.size()):
		print(LogFormatter.format(logs[i]))
	_last_log_index = logs.size()
	
func _on_ui_action_selected(action: Dictionary) -> void:
	var snap := runtime.dispatch(action)
	renderer.render(snap)
	_flush_logs_to_console()
	
func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will route into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)
