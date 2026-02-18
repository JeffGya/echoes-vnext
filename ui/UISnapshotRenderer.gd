extends Node

class_name UISnapshotRenderer

signal action_selected(action: Dictionary)

# Renderer is responsible only for taking snapshots and updating UI.
# It must not know anything about game logic systems.
var snapshot_view: RichTextLabel
var actions_container: Control

func bind_view(view: RichTextLabel, actions: Control) -> void:
	# AppRoot provides the UI nodes this renderer can write to.
	snapshot_view = view
	actions_container = actions
	
# Render function that is repsonsible for keeping track and showing the content and actions based on what the flows and states pass from the Approot.
func render(snapshot: Dictionary) -> void:
	if snapshot_view == null:
		push_warning("UISnapShotRenderer has no bound SnapshotView.")
		return
	# 1) Debug JSON view (temporary for debug/dev purposes)
	snapshot_view.text = JSON.stringify(snapshot, "\t")
	
	# 2) Action buttons
	_clear_actions()
	if actions_container == null:
		return
		
	var actions_v: Variant = snapshot.get("actions", [])
	if typeof(actions_v) != TYPE_ARRAY:
		return
		
	var actions: Array = actions_v
		
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue

		var action_dict: Dictionary = a
		var btn := Button.new()
		btn.text = str(action_dict.get("label", action_dict.get("type", "action")))
		btn.disabled = bool(action_dict.get("disabled", false))
		
	
		# Capture the action dictionary deterministically
		# Deep copy so UI can’t mutate the original snapshot dictionary.
		var action_copy: Dictionary = action_dict.duplicate(true)
		btn.pressed.connect(_on_action_button_pressed.bind(action_copy))
		actions_container.add_child(btn)
		
	# snapshot_view.text = json_string

# A helper to clear old buttons
func _clear_actions() -> void:
	if actions_container == null:
		return
	for child in actions_container.get_children():
		child.queue_free()

# A helper to emit action when button is pressed
func _on_action_button_pressed(action: Dictionary) -> void:
	action_selected.emit(action)
