## ScreenTemplate
##
## Starting point for all new snapshot-driven screens.
## Implement _clear() and _render(). Bind buttons to named slots in the actions Dictionary.
## Never read sim internals (FlowContext, FlowRuntime, SanctumState, SaveService) directly.
## Never call dispatch() directly — emit action_requested and AppRoot will forward it.
##
## See CONVENTIONS.md → "Bespoke Screen Contract" for the full interface spec.

extends Control

signal action_requested(action: Dictionary)

func set_snapshot(snap: Dictionary) -> void:
	assert(snap.has("type"), "Snapshot missing 'type' key")
	assert(snap.has("data"), "Snapshot missing 'data' key")
	_clear()
	# snap["actions"] is a slot-keyed Dictionary: { "nav.back": {...}, "cta.primary": {...} }
	_render(snap["data"], snap.get("actions", {}))

func _clear() -> void:
	pass  # Override: clear previous render state

func _render(data: Dictionary, actions: Dictionary) -> void:
	pass  # Override: bind named action slots and populate UI from data

func _on_action(action: Dictionary) -> void:
	action_requested.emit(action)
