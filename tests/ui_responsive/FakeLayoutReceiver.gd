extends Control
class_name FakeLayoutReceiver

signal action_requested(action: Dictionary)

var received_layouts: Array[Dictionary] = []
var emitted_actions: Array[Dictionary] = []

func set_layout(layout: Dictionary) -> void:
	received_layouts.append(layout.duplicate(true))

func emit_test_action(action: Dictionary) -> void:
	emitted_actions.append(action.duplicate(true))
	action_requested.emit(action)
