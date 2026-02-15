extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel

var current_snapshot: Dictionary = {}
var current_save: Dictionary = {}
#AppRoot owns sim_tick for now. Replace with Flow/Encounter-owned sim_tick later.
var sim_tick: int = 0
var logger: StructuredLogger

func _ready():
	logger = StructuredLogger.new()
	
	# Bind renderer to UI elements it can update.
	renderer.bind_view(snapshot_view)
	
	# Connect debug panel to approot
	debug_panel.command_submitted.connect(_on_debug_command)
	
	# Placeholder snapshot (will later come from FlowStateMachine)
	current_snapshot = {
		"type": "boot",
		"meta": {
			"version": "vNext-dev",
			"tick": 0
		},
		"data": {
			"message": "System initialized.",
			"next_state": "sanctum"
		}
	}
	
	current_save = SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH, logger, _next_tick())
	
	if current_save.is_empty():
		# MVP: hardcoded seed for now; late Flow will decicde seed creation and persistence rules
		current_save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, current_save, logger, _next_tick())
			
	renderer.render(current_snapshot)
	
	logger.log_state_transition(_next_tick(), "boot", "sanctum", "save_loaded")
	for e in logger.get_logs():
		print(LogFormatter.format(e))
	
# TEMPORARY!!! Deterministic tick source (replace when Flow/Encounter exists)
func _next_tick() -> int:
	var t := sim_tick
	sim_tick += 1
	return t

func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will rout into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)
