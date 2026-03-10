# res://core/actors/BehaviorModule.gd
# Base class for all pluggable actor behavior modules.
#
# Every concrete module must override both methods.
# Calling either method on the base class directly will push_error and return a safe default.
#
# Interface (ACTOR-003):
#   get_module_id() -> String
#       Returns the stable string ID for this module (e.g. "idle", "melee", "guardian").
#       Must not be generated at runtime.
#
#   select_intent(context: Dictionary) -> Dictionary
#       Pure function — no side effects, no RNG, no OS time.
#       context shape: { "actor": Dictionary, "all_actors": Array, "t": int }
#       Returns intent shape: { "action_type": String, "target_id": String, "priority": float }
#
# Rules:
# - Never instantiate BehaviorModule directly. Always use a concrete subclass.
# - select_intent() must be deterministic: same context → same intent every call.
# - context dict must be JSON-safe (no Nodes/Objects).

class_name BehaviorModule
extends RefCounted


func get_module_id() -> String:
	push_error("BehaviorModule.get_module_id() called on base class — override in subclass")
	return ""


func select_intent(_context: Dictionary) -> Dictionary:
	push_error("BehaviorModule.select_intent() called on base class — override in subclass")
	return {}
