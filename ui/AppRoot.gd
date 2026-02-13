extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel

var current_snapshot: Dictionary = {}
var current_save: Dictionary = {}

func _ready():
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
	
	current_save = SaveService.load_from_file(SaveSchema.DEFAULT_SAVE_PATH)
	
	if current_save.is_empty():
		# MVP: hardcoded seed for now; late Flow will decicde seed creation and persistence rules
		current_save = SaveService.make_new_save(12346)
		SaveService.save_to_file(SaveSchema.DEFAULT_SAVE_PATH, current_save)
		
	print("Save loaded. schema_version:", int(current_save.get("schema_version", 0)))
	
	renderer.render(current_snapshot)
	
func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will rout into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)
