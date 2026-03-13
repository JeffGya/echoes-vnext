# res://core/actors/behaviors/MeleeBehaviorModule.gd
# First concrete BehaviorModule: attacks the nearest enemy when at Manhattan distance == 1.
#
# Rules:
# - Pure function — no RNG, no side effects, no logging.
# - select_intent() is deterministic: same context → same intent every call.
# - Falls back to actor.idle if no enemy is found or nearest enemy is not adjacent.
#
# Attack range: distance == 1 (Manhattan, using grid_pos { col, row }).
# Tiebreak: lexicographically smallest actor_id (delegated to ActorService).
#
# GRID-STUB: All actors default to grid_pos { col: 0, row: 0 } until GRID-001.
# This means attacks won't fire until real positions are injected — the module
# is live once the grid system places actors at different positions.

class_name MeleeBehaviorModule
extends BehaviorModule


func get_module_id() -> String:
	return "melee"


func select_intent(context: Dictionary) -> Dictionary:
	var actor: Dictionary = context.get("actor", {})
	var all_actors: Array = context.get("all_actors", [])

	var target: Dictionary = ActorService.get_nearest_enemy(actor, all_actors)
	if target.is_empty():
		return { "action_type": "actor.idle", "target_id": "", "priority": 0.0 }

	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var t_pos:  Dictionary = target.get("grid_pos", { "col": 0, "row": 0 })
	var dist: int = abs(my_pos.get("col", 0) - t_pos.get("col", 0)) \
				  + abs(my_pos.get("row", 0) - t_pos.get("row", 0))

	if dist == 1:
		return {
			"action_type": "melee_attack",
			"target_id":   str(target.get("id", "")),
			"distance":    dist,
			"priority":    1.0,
		}

	return { "action_type": "actor.idle", "target_id": "", "priority": 0.0 }
