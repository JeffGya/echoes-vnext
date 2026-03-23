# res://core/actors/ActorService.gd
# Shared spatial and roster utilities for behavior modules and combat systems.
#
# Rules:
# - Pure static functions only — no side effects, no logging.
# - Enemy lookup is faction-based: actors with a different "faction" string are enemies.
# - Grid positions use { "col": int, "row": int } until core/grid/ lands (GRID stories).
#
# ACTOR-004: get_nearest_enemy() established here.
# ACTOR-005: get_threatened_ally() added here.
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
		if candidate.get("is_dead", false):
			continue  # ACTOR-008: dead actors are not valid targets
		if candidate.get("faction", "") == my_faction:
			continue  # same faction — skip
		if candidate.get("is_structure", false):
			continue  # COMBAT-006 fix: structures are never valid enemy targets
		if candidate.get("id", "") == actor.get("id", ""):
			continue  # self — skip

		var cpos: Dictionary = candidate.get("grid_pos", { "col": 0, "row": 0 })
		var dist: int = GridService.chebyshev_distance(my_pos, cpos)

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


## Returns the most threatened same-faction ally of `actor` from `all_actors`.
## "Threatened" = current_hp < max_hp * threshold (from balance.json data.actor.threat_threshold).
## `actor` itself is excluded — an echo cannot protect itself via this function.
## Tiebreak: lowest current_hp; if equal, lexicographically smallest actor_id.
## Returns {} if no threatened ally found.
##
## Pure function — same inputs always produce the same output.
static func get_threatened_ally(actor: Dictionary, all_actors: Array, threshold: float) -> Dictionary:
	var my_faction: String = actor.get("faction", "")
	var best: Dictionary = {}

	for candidate_v in all_actors:
		if not (candidate_v is Dictionary):
			continue
		var c: Dictionary = candidate_v
		if c.get("is_dead", false):
			continue  # ACTOR-008: dead actors cannot be protected
		if c.get("faction", "") != my_faction:
			continue  # different faction — skip
		if c.get("id", "") == actor.get("id", ""):
			continue  # self — skip

		var chp: int = int(c.get("current_hp", 0))
		var mhp: int = int(c.get("stats", {}).get("max_hp", 1))
		if mhp <= 0 or float(chp) >= float(mhp) * threshold:
			continue  # not threatened — skip

		var better := false
		if best.is_empty():
			better = true
		else:
			var bhp: int = int(best.get("current_hp", 0))
			if chp < bhp:
				better = true
			elif chp == bhp:
				# Tiebreak: lexicographically smallest actor_id
				better = str(c.get("id", "")) < str(best.get("id", ""))

		if better:
			best = c

	return best
