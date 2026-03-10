# res://core/actors/behaviors/IdleBehaviorModule.gd
# Safe fallback behavior module for any actor not yet assigned a specialized module.
#
# select_intent() always returns "actor.idle" — the actor takes no action.
# This ensures that any actor without a concrete behavior module produces a valid,
# non-crashing intent dict on every turn call.
#
# Used as the default in ActorStateMachine._init() when no module is provided.

class_name IdleBehaviorModule
extends BehaviorModule


func get_module_id() -> String:
	return "idle"


func select_intent(_context: Dictionary) -> Dictionary:
	return { "action_type": "actor.idle", "target_id": "", "priority": 0.0 }
