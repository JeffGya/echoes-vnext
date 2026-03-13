# res://core/actors/ActorService.gd
# Shared spatial and roster utilities for behavior modules and combat systems.
#
# Rules:
# - Pure static functions only — no side effects, no logging.
# - Enemy lookup is faction-based: actors with a different "faction" string are enemies.
# - Grid positions use { "col": int, "row": int } until core/grid/ lands (GRID stories).
#
# ACTOR-004: get_nearest_enemy() established here.
# All future behaviors that need spatial queries should use this service.

class_name ActorService
extends RefCounted


## Returns the nearest enemy actor to `actor` from `all_actors`.
## "Enemy" = any actor whose "faction" string differs from actor["faction"].
## Nearest = smallest Manhattan distance using grid_pos { col, row }.
## Tiebreak: lexicographically smallest actor_id string when equidistant.
## Returns {} if no enemies found.
##
## Pure function — same inputs always produce the same output.
static func get_nearest_enemy(actor: Dictionary, all_actors: Array) -> Dictionary:
	var my_faction: String = actor.get("faction", "")
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })

	var best: Dictionary = {}
	var best_dist: int = 999999

	for candidate_v in all_actors:
		if not (candidate_v is Dictionary):
			continue
		var candidate: Dictionary = candidate_v
		if candidate.get("faction", "") == my_faction:
			continue  # same faction — skip
		if candidate.get("id", "") == actor.get("id", ""):
			continue  # self — skip

		var cpos: Dictionary = candidate.get("grid_pos", { "col": 0, "row": 0 })
		var dist: int = abs(my_pos.get("col", 0) - cpos.get("col", 0)) \
					  + abs(my_pos.get("row", 0) - cpos.get("row", 0))

		var better := false
		if best.is_empty():
			better = true
		elif dist < best_dist:
			better = true
		elif dist == best_dist:
			# Tiebreak: lexicographically smallest actor_id
			better = str(candidate.get("id", "")) < str(best.get("id", ""))

		if better:
			best = candidate
			best_dist = dist

	return best
