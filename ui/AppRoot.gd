extends Control

@onready var snapshot_view: RichTextLabel = %SnapshotView
@onready var renderer: UISnapshotRenderer = %UISnapshotRenderer
@onready var debug_panel: DebugPanel = $HSplitContainer/DebugPanel

var current_snapshot: Dictionary = {}

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
	
	renderer.render(current_snapshot)
	
func _on_debug_command(command: String) -> void:
	# For now: echo + placeholder.
	# Later: this will rout into acting dispatch / debug commands.
	# We keep the behaviour explicit and centralized.
	print("[DEBUG CMD]", command)
