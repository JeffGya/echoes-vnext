# res://core/actors/behaviors/MeleeBehaviorModule.gd
# First concrete BehaviorModule: attacks the nearest enemy when at Manhattan distance == 1.
#
# Rules:
# - Pure function — no RNG, no side effects, no logging.
# - select_intent() is deterministic: same context → same intent every call.
# - Falls back to actor.idle if no enemy is found or nearest enemy is not adjacent.
#
# Attack range: is_adjacent() — Chebyshev distance == 1 (covers all 8 neighbours).
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

	# COMBAT-006: enemy actors in a purify_shrine encounter prioritise the shrine over echoes.
	# FlowRuntime sets prefer_objective_target = true for enemy actors in PURIFY_SHRINE encounters.
	var target: Dictionary = {}
	if context.get("prefer_objective_target", false):
		for a_v in all_actors:
			if a_v is Dictionary \
					and a_v.get("is_structure", false) \
					and not a_v.get("is_dead", false):
				target = a_v
				break

	# §5-C: PROTECT echo target overrides — mirrors the enemy prefer_objective_target pattern above.
	# Priority: stolen (focus-fire carrier) > threatened (intercept nearest-to-totem enemy).
	# Only fires for echo actors in PROTECT mode. Defensive: falls through if no valid target found.
	if target.is_empty() and context.get("resolution_mode", "") == "protect" \
			and str(actor.get("faction", "")) == "echo":
		var totem_stolen_mm: bool = context.get("totem_stolen", false)
		var totem_carrier_id_mm: String = context.get("totem_carrier_id", "")
		if totem_stolen_mm and not totem_carrier_id_mm.is_empty():
			# Stolen: focus-fire the carrier.
			for a_v in all_actors:
				if a_v is Dictionary \
						and str(a_v.get("id", "")) == totem_carrier_id_mm \
						and not a_v.get("is_dead", false):
					target = a_v
					break
		else:
			# Threatened: pick the living enemy NEAREST TO THE TOTEM (not nearest to this echo).
			# Deterministic tiebreak: lowest id string.
			var totem_pos_mm: Dictionary = {}
			for a_v in all_actors:
				if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
					totem_pos_mm = a_v.get("grid_pos", {})
					break
			if not totem_pos_mm.is_empty():
				var protect_radius_mm: int = 3  # default; matches §5-B
				var best_dist_mm: int = 999999
				var best_id_mm: String = ""
				for a_v in all_actors:
					if not (a_v is Dictionary):
						continue
					var a_mm: Dictionary = a_v
					if a_mm.get("is_dead", false) or a_mm.get("is_structure", false):
						continue
					if str(a_mm.get("faction", "")) == "enemy":
						var d_mm: int = GridService.chebyshev_distance(totem_pos_mm, a_mm.get("grid_pos", {}))
						if d_mm <= protect_radius_mm:
							var aid_mm: String = str(a_mm.get("id", ""))
							if d_mm < best_dist_mm or (d_mm == best_dist_mm and aid_mm < best_id_mm):
								best_dist_mm = d_mm
								best_id_mm = aid_mm
								target = a_mm

	if target.is_empty():
		target = ActorService.get_nearest_enemy(actor, all_actors)
	if target.is_empty():
		return { "action_type": "actor.idle", "target_id": "", "priority": 0.0 }

	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var t_pos:  Dictionary = target.get("grid_pos", { "col": 0, "row": 0 })
	var dist: int = GridService.chebyshev_distance(my_pos, t_pos)

	if GridService.is_adjacent(my_pos, t_pos):
		return {
			"action_type":    "melee_attack",
			"target_id":      str(target.get("id", "")),
			"target_distance": dist,
			"priority":       1.0,
		}

	# GRID-005: target exists but is out of melee range — close the gap.
	return {
		"action_type":    "actor.move",
		"target_id":      str(target.get("id", "")),
		"target_distance": dist,
		"target_pos":     t_pos.duplicate(),
		"priority":       0.5,
	}
