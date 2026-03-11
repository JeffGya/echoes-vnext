# res://core/actors/ActorStateMachine.gd
# Per-actor behavior host. Stores the actor dict, owns a BehaviorModule, and
# drives one turn of intent selection per advance_turn() call.
#
# Rules:
# - No RNG, no OS time, no side effects.
# - get_stat() reads base stats from actor_dict.stats (the 6 PROG-002-derived fields).
# - Top-level runtime fields (current_hp, speed, morale, fear) are accessed
#   directly from the actor dict by behavior modules — no wrapper in MVP.
# - advance_turn() is the single choke point for intent selection each combat turn.
# - select_intent() is pure: same context → same intent every call.
#
# GRID-STUB: position { x, y } will be added to the actor context when
# core/grid/ lands (GRID stories). Not present in MVP.

class_name ActorStateMachine
extends RefCounted

var _actor: Dictionary
var _behavior_module: BehaviorModule
var _last_intent: Dictionary = {}


## actor_dict: the actor's full dict (from EchoActor.from_echo or EnemyActor.from_definition).
## behavior_module: the AI module to query each turn. Defaults to IdleBehaviorModule if null.
func _init(actor_dict: Dictionary, behavior_module: BehaviorModule = null) -> void:
	_actor = actor_dict
	_behavior_module = behavior_module if behavior_module != null else IdleBehaviorModule.new()
	_last_intent = {}


## Returns the value of a base stat from actor_dict.stats[stat_name].
## Covers: max_hp, atk, def, agi, int, cha.
## Returns null if stat_name is not found — caller must guard against null.
## Note: top-level runtime fields (current_hp, speed, morale, fear) are not
## in the stats sub-dict; access them directly via actor_dict["field_name"].
func get_stat(stat_name: String) -> Variant:
	var stats: Dictionary = _actor.get("stats", {})
	if stats.has(stat_name):
		return stats[stat_name]
	return null


## Called by the combat loop once per turn. Selects intent via the behavior module,
## stores it internally, and logs actor.intent.
##
## context shape (ACTOR-003, locked):
##   { "actor": Dictionary, "all_actors": Array, "t": int }
##   Grid fields (position, adjacency) added when core/grid/ lands.
##
## Returns the selected intent dict:
##   { "action_type": String, "target_id": String, "priority": float }
func advance_turn(context: Dictionary, logger: StructuredLogger, t: int) -> Dictionary:
	var intent: Dictionary = _behavior_module.select_intent(context)
	_last_intent = intent
	logger.info(t, "actor.intent", "Intent selected", {
		"module_id": _behavior_module.get_module_id(),
		"action_type": intent.get("action_type", ""),
		"target_id": intent.get("target_id", ""),
		"actor_id": _actor.get("id", "")
	})
	return intent


## Returns a debug-friendly snapshot of this actor's current behavior state.
## Used by debug overlays and tests to verify module assignment, last intent, and vectors.
##
## Shape:
##   {
##     "actor_id": String,
##     "name": String,
##     "behavior_module": String,
##     "last_intent": Dictionary,
##     "vectors": { "scores": Dictionary<String,int>, "dominant_vector": String }
##   }
## vectors.scores contains all keys from actor_dict.vector_scores (any N keys — no hardcoded list).
func get_snapshot() -> Dictionary:
	return {
		"actor_id": _actor.get("id", ""),
		"name": _actor.get("name", ""),
		"behavior_module": _behavior_module.get_module_id(),
		"last_intent": _last_intent.duplicate(),
		# PROG-005: Layer 2 vector data for intent pipeline and debug display
		"vectors": VectorService.get_snapshot_data(_actor)
	}
