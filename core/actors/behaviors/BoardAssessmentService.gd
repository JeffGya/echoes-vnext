# res://core/actors/behaviors/BoardAssessmentService.gd
# Read-only board/threat/line-of-sight assessment for BehaviorArbiter's scoring pass.
#
# Owns: the per-turn board_summary (HP, distances, active situational conditions), the
# cover-destination and line-of-sight checks behind it, leader-radius membership, and the
# flat situational score bonus derived from active conditions.
#
# Does NOT score candidates and does NOT compute leadership emotion (LeadershipEmotionService
# owns morale/fear) — this is the scoring-input half only. Holds no ConfigService: every
# config table arrives as a parameter, resolved by the caller's own `_cfg_get()`. Pure,
# static, called once per turn by `select_intent()`/`select_movement_intent()`.

class_name BoardAssessmentService

const LeadershipEmotionServiceScript = preload("res://core/combat/LeadershipEmotionService.gd")


## Read-only per-turn snapshot: HP ratio, ally/enemy counts, nearest-enemy distance, and
## which `situational_muls_cfg` conditions are active for this actor right now.
## `last_echo_standing` requires `dead_allies > 0` so an all-enemy fixture never fires it.
## `own_hp_low`/`own_hp_critical` require real `current_hp` data so an actor without it is
## never mistaken for unhurt.
static func build_board_summary(
	actor: Dictionary, all_actors: Array, _board_cfg: Dictionary,
	expression_band: String = "nascent", resolution_mode: String = "",
	objective_modes_cfg: Dictionary = {}, situational_muls_cfg: Dictionary = {}
) -> Dictionary:
	var my_id:      String = str(actor.get("id", ""))
	var my_faction: String = str(actor.get("faction", ""))
	var actor_type: String = str(actor.get("actor_type", "echo"))

	var living_allies: int  = 0
	var living_enemies: int = 0
	var dead_allies: int    = 0
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("id", "")) == my_id:
			continue
		var is_dead: bool = a.get("is_dead", false)
		if str(a.get("faction", "")) == my_faction:
			if is_dead:
				dead_allies += 1
			else:
				living_allies += 1
		else:
			if not is_dead:
				living_enemies += 1

	var max_hp: int    = int(actor.get("stats", {}).get("max_hp", 0))
	var hp_ratio: float = ActorService.health_ratio(actor)

	var nearest_enemy: Dictionary = ActorService.get_nearest_enemy(actor, all_actors)
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })
	var enemy_dist: int = 999999
	if not nearest_enemy.is_empty():
		enemy_dist = GridService.chebyshev_distance(my_pos, nearest_enemy.get("grid_pos", { "col": 0, "row": 0 }))

	var sit_cfg: Dictionary = situational_muls_cfg
	var active: Array[String] = []

	var low_threshold:  float = float(sit_cfg.get("own_hp_low",      {}).get("threshold", 0.35))
	var crit_threshold: float = float(sit_cfg.get("own_hp_critical",  {}).get("threshold", 0.20))
	if max_hp > 0 and actor.has("current_hp"):
		if hp_ratio < crit_threshold:
			active.append("own_hp_critical")
		if hp_ratio < low_threshold:
			active.append("own_hp_low")

	# Requires at least 1 living ally so a 1v1 fight doesn't count as "outnumbered".
	if living_enemies > living_allies and living_allies > 0:
		active.append("outnumbered")

	if living_enemies > 0 and living_allies >= living_enemies * 2:
		active.append("overwhelming_advantage")

	if living_allies == 0 and dead_allies > 0:
		active.append("last_echo_standing")

	var far_threshold: int = int(sit_cfg.get("enemy_far", {}).get("threshold", 5))
	if enemy_dist > far_threshold and enemy_dist < 999999:
		active.append("enemy_far")

	if actor_type == "echo" and enemy_dist <= 1:
		active.append("echo_in_melee")

	if actor_type == "enemy" and enemy_dist < 999999:
		var n_pos: Dictionary = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		if GridService.is_adjacent(my_pos, n_pos):
			active.append("enemy_engaged")
		else:
			active.append("enemy_advancing")

	# echo_retreating: enemy Forming+ pursuit — fires when any echo is mid-retreat.
	if actor_type == "enemy" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v as Dictionary
			if a.get("actor_type", "") == "echo" and not a.get("is_dead", false):
				var li_v: Variant = a.get("last_intent", {})
				if li_v is Dictionary and str((li_v as Dictionary).get("action_type", "")) == "actor.retreat":
					active.append("echo_retreating")
					break

	# seer_directive_aura: any echo ally within 3 tiles of a living Okomfo.
	if actor_type == "echo":
		for sa_v in all_actors:
			if not (sa_v is Dictionary): continue
			var sa: Dictionary = sa_v
			if sa.get("is_dead", false): continue
			if str(sa.get("id", "")) == my_id: continue
			if str(sa.get("faction", "")) == my_faction \
					and str(sa.get("calling_origin", "")) == "okomfo":
				var sa_pos: Dictionary = sa.get("grid_pos", {})
				if not sa_pos.is_empty() and GridService.chebyshev_distance(my_pos, sa_pos) <= 3:
					active.append("seer_directive_aura")
					break

	# repeated_move_penalty: 2-3 tile band — too close to keep running, close enough to act.
	if actor_type == "echo" and enemy_dist > 1 and enemy_dist <= 3:
		var last_i_v: Variant = actor.get("last_intent", {})
		var last_i: Dictionary = last_i_v if last_i_v is Dictionary else {}
		if str(last_i.get("action_type", "")) == "actor.move":
			active.append("repeated_move_penalty")

	# repeated_guard_penalty: a soft nudge alongside the hard guard-loop suppression in
	# ActionCandidateGenerator — applies to every actor type the same way.
	if enemy_dist <= 1:
		var last_i_rg_v: Variant = actor.get("last_intent", {})
		var last_i_rg: Dictionary = last_i_rg_v if last_i_rg_v is Dictionary else {}
		if str(last_i_rg.get("action_type", "")) == "actor.guard":
			active.append("repeated_guard_penalty")

	# near_friendly_structure / near_hostile_structure: shrine proximity, faction-gated.
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if a.get("is_structure", false) and not a.get("is_dead", false):
			if str(a.get("faction", "")) == "structure":
				if actor_type != "enemy":
					active.append("near_friendly_structure")
				else:
					active.append("near_hostile_structure")
			break

	# objective_in_range (§5-A RECOVER dig-in): echo adjacent to the living relic.
	if resolution_mode == "recover" and actor_type == "echo":
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if a.get("is_structure", false) and not a.get("is_dead", false):
				if GridService.is_adjacent(my_pos, a.get("grid_pos", {})):
					active.append("objective_in_range")
				break

	# objective_threatened (§5-B PROTECT interpose): living enemy within radius of the totem.
	if resolution_mode == "protect" and actor_type == "echo":
		var protect_radius: int = 3
		var om_protect_v: Variant = objective_modes_cfg.get("protect", {})
		var om_protect: Dictionary = om_protect_v if om_protect_v is Dictionary else {}
		if om_protect.has("objective_threatened_radius"):
			protect_radius = int(om_protect["objective_threatened_radius"])
		var totem_pos_pt: Dictionary = {}
		for a_v in all_actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if a.get("is_structure", false) and not a.get("is_dead", false):
				totem_pos_pt = a.get("grid_pos", {})
				break
		if not totem_pos_pt.is_empty():
			for a_v in all_actors:
				if not (a_v is Dictionary):
					continue
				var a: Dictionary = a_v
				if a.get("is_dead", false) or a.get("is_structure", false):
					continue
				if str(a.get("faction", "")) == "enemy":
					if GridService.chebyshev_distance(totem_pos_pt, a.get("grid_pos", {})) <= protect_radius:
						active.append("objective_threatened")
						break

	# quarry_near_exit (§5-C PURSUE urgency): living quarry within threshold of a board edge.
	if resolution_mode == "pursue" and actor_type == "echo":
		var _qne_threshold: int = 3
		var _om_pursue_v: Variant = objective_modes_cfg.get("pursue", {})
		var _om_pursue: Dictionary = _om_pursue_v if _om_pursue_v is Dictionary else {}
		if _om_pursue.has("quarry_near_exit_threshold"):
			_qne_threshold = int(_om_pursue["quarry_near_exit_threshold"])
		var _qne_board_w: int = int(_board_cfg.get("board_cols", 10))
		var _qne_board_h: int = int(_board_cfg.get("board_rows", 10))
		for a_v in all_actors:
			if not (a_v is Dictionary): continue
			var a_qne: Dictionary = a_v
			if bool(a_qne.get("is_quarry", false)) and not bool(a_qne.get("is_dead", false)):
				var _qne_p: Dictionary = a_qne.get("grid_pos", {})
				var _qne_col: int = int(_qne_p.get("col", 0))
				var _qne_row: int = int(_qne_p.get("row", 0))
				var _qne_dist: int = mini(
					mini(_qne_col, _qne_row),
					mini(_qne_board_w - 1 - _qne_col, _qne_board_h - 1 - _qne_row)
				)
				if _qne_dist <= _qne_threshold:
					active.append("quarry_near_exit")
				break

	return {
		"hp_ratio":          hp_ratio,
		"enemy_dist":        enemy_dist,
		"living_allies":     living_allies,
		"living_enemies":    living_enemies,
		"dead_allies":       dead_allies,
		"actor_type":        actor_type,
		"active_conditions": active,
	}


## cover_positioning: does this route END behind terrain, out of sight of the nearest
## hostile? The board has no LOS system, so "cover" means an in-bounds non-walkable cell
## sits on the straight line between destination and threat. Deterministic, no RNG.
static func is_cover_destination(path: Array, movement_context: Dictionary) -> bool:
	if path.is_empty():
		return false
	var destination: Dictionary = path.back() as Dictionary
	var walkable: Dictionary = movement_context.get("authoritative_walkable", {}) as Dictionary
	var bounds: Dictionary = movement_context.get("bounds", {}) as Dictionary
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	if width <= 0 or height <= 0:
		return false
	var relationships: Dictionary = movement_context.get("relationships", {}) as Dictionary
	var threat: Dictionary = {}
	var best_distance: int = 2147483647
	for fact_v: Variant in (movement_context.get("perceived_actors", []) as Array):
		var fact: Dictionary = fact_v as Dictionary
		if str(relationships.get(str(fact.get("id", "")), "")) != "hostile":
			continue
		if fact.get("is_dead", false) or fact.get("is_structure", false):
			continue
		var cell: Dictionary = fact.get("position", {}) as Dictionary
		if cell.is_empty():
			continue
		var distance: int = GridService.chebyshev_distance(destination, cell)
		if distance < best_distance:
			best_distance = distance
			threat = cell
	if threat.is_empty():
		return false
	return line_is_blocked(destination, threat, walkable, width, height)


## True when an in-bounds, non-walkable cell lies strictly between `from` and `to`.
## Bresenham walk with both axes tested, so a diagonal sight line is blocked by a clip.
static func line_is_blocked(
	from: Dictionary, to: Dictionary, walkable: Dictionary, width: int, height: int
) -> bool:
	var col: int = int(from.get("col", 0))
	var row: int = int(from.get("row", 0))
	var target_col: int = int(to.get("col", 0))
	var target_row: int = int(to.get("row", 0))
	var delta_col: int = absi(target_col - col)
	var delta_row: int = absi(target_row - row)
	var step_col: int = 1 if target_col > col else -1
	var step_row: int = 1 if target_row > row else -1
	var error: int = delta_col - delta_row
	while true:
		if error * 2 > -delta_row:
			error -= delta_row
			col += step_col
		elif error * 2 < delta_col:
			error += delta_col
			row += step_row
		else:
			break
		if col == target_col and row == target_row:
			return false
		if col < 0 or row < 0 or col >= width or row >= height:
			continue
		if not bool(walkable.get("%d,%d" % [col, row], false)):
			return true
	return false


## True when `actor_id` is one of the leader's nearby living echo allies at `radius`.
## Routed through LeadershipEmotionService's own membership helper so there is exactly
## one definition of "nearby living echo ally".
static func is_in_leader_radius(
	leader: Dictionary, actor_id: String, all_actors: Array, radius: int
) -> bool:
	for ally_v: Variant in LeadershipEmotionServiceScript.get_nearby_living_echo_allies(
		leader, all_actors, radius
	):
		if str((ally_v as Dictionary).get("id", "")) == actor_id:
			return true
	return false


## Flat bonus from active board_summary conditions. Keys starting with "_stub_" are never
## placed in active_conditions, so stub rows in balance.json have zero effect. Returns 0.0
## when board_summary is empty (existing tests depend on this).
static func situational_bonus(
	action_type: String, board_summary: Dictionary, situational_muls_cfg: Dictionary
) -> float:
	var conditions: Array = board_summary.get("active_conditions", [])
	if conditions.is_empty():
		return 0.0
	var bonus: float = 0.0
	for cond_key: String in conditions:
		var cond_row: Dictionary = situational_muls_cfg.get(cond_key, {})
		bonus += float(cond_row.get(action_type, 0.0))
	return bonus
