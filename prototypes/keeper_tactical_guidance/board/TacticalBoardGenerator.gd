class_name TacticalBoardGenerator
extends RefCounted

## Deterministic, prototype-local tactical board generation and hazard resolution.
## The production project does not import this file. Movement and range semantics mirror
## GridService/StageTerrain: walkability is keyed as "col,row" and movement is 8-directional.

const MODE_RECOVER: String = "recover"
const MODE_PROTECT: String = "protect"

const HAZARD_BURNING: String = "burning_ground"
const HAZARD_UNSTABLE: String = "unstable_ground"
const HAZARD_BINDING: String = "binding_growth"

const MAX_ATTEMPTS: int = 32
const BOARD_HEIGHT: int = 10
const MIN_WIDTH: int = 10
const MAX_WIDTH: int = 14
const BURNING_DAMAGE: int = 5
const UNSTABLE_FALLBACK_DAMAGE: int = 6
const ASSUMED_ACTOR_HP: int = 40

const _DELTAS_8: Array = [
	[-1, -1], [0, -1], [1, -1],
	[-1, 0],           [1, 0],
	[-1, 1],  [0, 1],  [1, 1],
]


static func generate(seed: int, mode: String) -> Dictionary:
	var normalized_mode: String = mode if mode in [MODE_RECOVER, MODE_PROTECT] else MODE_RECOVER
	var failed_diagnostics: Array = []
	for attempt in range(MAX_ATTEMPTS):
		var namespace_path: String = "prototype.keeper.board.%s.attempt.%d" % [normalized_mode, attempt]
		var rng: RandomNumberGenerator = _rng_for(seed, namespace_path)
		var candidate: Dictionary = _build_candidate(seed, normalized_mode, attempt, rng)
		var validation: Dictionary = validate_board(candidate)
		validation["attempt"] = attempt
		candidate["validation"] = validation
		if bool(validation.get("valid", false)):
			return candidate
		failed_diagnostics.append({
			"attempt": attempt,
			"diagnostics": validation.get("diagnostics", []).duplicate(true),
		})

	# The template shares the same contract and is independently validated. It exists so a
	# pathological seed never prevents the sandbox from loading after bounded attempts.
	var fallback: Dictionary = _build_candidate(seed, normalized_mode, MAX_ATTEMPTS, _rng_for(
		seed, "prototype.keeper.board.%s.attempt.%d" % [normalized_mode, MAX_ATTEMPTS]))
	var fallback_validation: Dictionary = validate_board(fallback)
	fallback_validation["attempt"] = MAX_ATTEMPTS
	fallback_validation["used_fallback"] = true
	fallback_validation["candidate_failures"] = failed_diagnostics
	fallback["validation"] = fallback_validation
	return fallback


static func validate_board(board: Dictionary) -> Dictionary:
	var diagnostics: Array[String] = []
	var walkable: Dictionary = board.get("walkable", {})
	var bounds: Dictionary = board.get("bounds", {})
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	var objective: Dictionary = board.get("objective_pos", {})
	var deployments: Array = board.get("deployment_slots", [])
	var enemies: Array = board.get("enemy_slots", [])

	var fill_ratio: float = 0.0
	if width > 0 and height > 0:
		fill_ratio = float(walkable.size()) / float(width * height)
	var dimensions_valid: bool = width >= MIN_WIDTH and width <= MAX_WIDTH and height == BOARD_HEIGHT
	if not dimensions_valid:
		diagnostics.append("Board bounds must be 10x10 through 14x10.")
	var fill_valid: bool = fill_ratio >= 0.55 and fill_ratio <= 0.75
	if not fill_valid:
		diagnostics.append("Walkable footprint %.2f is outside 55-75%%." % fill_ratio)

	var connected: bool = _is_connected(walkable)
	if not connected:
		diagnostics.append("Walkable terrain is disconnected.")

	var objective_accessible: bool = walkable.has(_key(objective))
	if objective_accessible and not deployments.is_empty():
		var objective_field: Dictionary = _distance_field(objective, walkable)
		for slot_value in deployments:
			var slot: Dictionary = slot_value if slot_value is Dictionary else {}
			if not objective_field.has(_key(slot)):
				objective_accessible = false
				break
	if not objective_accessible:
		diagnostics.append("Objective is not reachable from every deployment slot.")

	var deployment_accessible: bool = deployments.size() >= 4 and deployments.size() <= 6
	var occupied_slots: Dictionary = {}
	for slot_value in deployments:
		var slot: Dictionary = slot_value if slot_value is Dictionary else {}
		var slot_key: String = _key(slot)
		if not walkable.has(slot_key) or occupied_slots.has(slot_key):
			deployment_accessible = false
		occupied_slots[slot_key] = true
	if enemies.size() < 4:
		deployment_accessible = false
	if not deployment_accessible:
		diagnostics.append("Deployment or enemy slots are insufficient, duplicated, or non-walkable.")

	var hazards_valid: bool = _validate_hazards(board, diagnostics)
	var obstacles_valid: bool = _validate_obstacles(board, diagnostics)
	var chokepoint_valid: bool = _validate_chokepoints(board)
	if not chokepoint_valid:
		diagnostics.append("No chokepoint meaningfully changes objective access.")
	var route_diversity_valid: bool = _validate_route_diversity(board)
	if not route_diversity_valid:
		diagnostics.append("Routes do not provide a non-dominated tactical tradeoff.")
	var no_unavoidable_lethal_route: bool = _has_nonlethal_route(board)
	if not no_unavoidable_lethal_route:
		diagnostics.append("Every objective route has unavoidable lethal hazard damage.")

	var feature_valid: bool = _has_required_features(board)
	if not feature_valid:
		diagnostics.append("Open ground, defensible ground, or landmark feature is missing.")

	var valid: bool = dimensions_valid and fill_valid and connected \
		and objective_accessible and deployment_accessible and hazards_valid and obstacles_valid \
		and chokepoint_valid and route_diversity_valid \
		and no_unavoidable_lethal_route and feature_valid
	return {
		"valid": valid,
		"attempt": int(board.get("validation", {}).get("attempt", -1)),
		"connected": connected,
		"objective_accessible": objective_accessible,
		"deployment_accessible": deployment_accessible,
		"chokepoint_valid": chokepoint_valid,
		"route_diversity_valid": route_diversity_valid,
		"no_unavoidable_lethal_route": no_unavoidable_lethal_route,
		"fill_ratio": fill_ratio,
		"hazards_valid": hazards_valid,
		"feature_valid": feature_valid,
		"diagnostics": diagnostics,
	}


## Applies entry hazards in contract order: unstable push/fallback damage, then binding stop.
## The actor is mutated in place, matching production combat actor dictionaries.
static func apply_entry_hazards(actor: Dictionary, from_pos: Dictionary, to_pos: Dictionary,
		board: Dictionary, occupied: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"actor_id": str(actor.get("id", "")),
		"from_pos": from_pos.duplicate(true),
		"entered_pos": to_pos.duplicate(true),
		"final_pos": to_pos.duplicate(true),
		"movement_stopped": false,
		"pushed": false,
		"damage": 0,
		"events": [],
	}
	if bool(actor.get("is_dead", false)) or bool(actor.get("is_structure", false)):
		return result
	if _key(from_pos) == _key(to_pos):
		return result

	actor["grid_pos"] = to_pos.duplicate(true)
	var hazards: Array = board.get("hazards", [])
	for hazard_value in hazards:
		var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
		if str(hazard.get("type", "")) != HAZARD_UNSTABLE:
			continue
		if not _hazard_contains(hazard, to_pos):
			continue
		var pushed_to: Dictionary = _unstable_push_cell(to_pos, hazard.get("center", {}), board, occupied)
		if not pushed_to.is_empty():
			actor["grid_pos"] = pushed_to.duplicate(true)
			result["final_pos"] = pushed_to.duplicate(true)
			result["pushed"] = true
			(result["events"] as Array).append(_hazard_event(
				actor, hazard, "push", 0, to_pos, pushed_to))
		else:
			var fallback_damage: int = int(hazard.get("damage", UNSTABLE_FALLBACK_DAMAGE))
			_apply_damage(actor, fallback_damage)
			result["damage"] = int(result["damage"]) + fallback_damage
			(result["events"] as Array).append(_hazard_event(
				actor, hazard, "fallback_damage", fallback_damage, to_pos, to_pos))
		break

	var final_pos: Dictionary = actor.get("grid_pos", to_pos)
	for hazard_value in hazards:
		var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
		if str(hazard.get("type", "")) != HAZARD_BINDING:
			continue
		if _hazard_contains(hazard, final_pos):
			actor["movement_remaining"] = 0
			result["movement_stopped"] = true
			(result["events"] as Array).append(_hazard_event(
				actor, hazard, "movement_stopped", 0, final_pos, final_pos))
			break
	return result


## Applies Burning Ground once after the actor has completed its turn.
static func apply_end_turn_hazards(actor: Dictionary, board: Dictionary) -> Dictionary:
	var position: Dictionary = actor.get("grid_pos", {})
	var result: Dictionary = {
		"actor_id": str(actor.get("id", "")),
		"final_pos": position.duplicate(true),
		"damage": 0,
		"events": [],
	}
	if bool(actor.get("is_dead", false)) or bool(actor.get("is_structure", false)):
		return result
	for hazard_value in board.get("hazards", []):
		var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
		if str(hazard.get("type", "")) != HAZARD_BURNING:
			continue
		if _hazard_contains(hazard, position):
			var damage: int = int(hazard.get("damage", BURNING_DAMAGE))
			_apply_damage(actor, damage)
			result["damage"] = damage
			(result["events"] as Array).append(_hazard_event(
				actor, hazard, "end_turn_damage", damage, position, position))
			break
	return result


static func board_signature(board: Dictionary) -> String:
	return JSON.stringify(_canonicalize(board))


static func serialize(board: Dictionary) -> String:
	return board_signature(board)


static func _build_candidate(seed: int, mode: String, attempt: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var objective_rng: RandomNumberGenerator = _rng_for(
		seed, "prototype.keeper.board.%s.objective" % mode)
	var deployment_rng: RandomNumberGenerator = _rng_for(
		seed, "prototype.keeper.board.%s.deployment" % mode)
	var width: int = rng.randi_range(MIN_WIDTH, MAX_WIDTH)
	var height: int = BOARD_HEIGHT
	var ridge_col: int = clampi(width / 2 + rng.randi_range(-1, 1), 4, width - 5)
	var top_gate_row: int = 2
	var bottom_gate_row: int = 7
	var walkable: Dictionary = {}

	# An inhabited organic footprint: substantial interior with broken north/south edges.
	for col in range(width):
		for row in range(1, height - 1):
			walkable[_key_xy(col, row)] = true
	for col in range(width):
		if (col + attempt) % 3 == 0:
			walkable[_key_xy(col, 0)] = true
		if (col * 2 + attempt) % 4 == 0:
			walkable[_key_xy(col, height - 1)] = true

	# A two-cell-thick ridge produces two separated crossings even with diagonal movement.
	for ridge_x in [ridge_col, ridge_col + 1]:
		for row in range(height):
			if row in [top_gate_row, top_gate_row + 1, bottom_gate_row - 1, bottom_gate_row]:
				continue
			walkable.erase(_key_xy(ridge_x, row))

	# Erode only non-critical border cells until the footprint reaches a seeded 62-70% target.
	var target_ratio: float = rng.randf_range(0.62, 0.70)
	var target_count: int = int(round(float(width * height) * target_ratio))
	var candidates: Array = walkable.keys()
	_shuffle(candidates, rng)
	for candidate_value in candidates:
		if walkable.size() <= target_count:
			break
		var candidate_key: String = str(candidate_value)
		var cell: Dictionary = _cell(candidate_key)
		if int(cell.get("col", 0)) in [0, 1, width - 2, width - 1]:
			continue
		if int(cell.get("col", 0)) in [ridge_col, ridge_col + 1]:
			continue
		if _near_any(cell, [
			{"col": 1, "row": 3}, {"col": 1, "row": 4},
			{"col": width - 2, "row": 4}, {"col": ridge_col, "row": top_gate_row},
			{"col": ridge_col, "row": bottom_gate_row},
		], 1):
			continue
		var reduced: Dictionary = walkable.duplicate()
		reduced.erase(candidate_key)
		if _is_connected(reduced):
			walkable = reduced

	var deployment_slots: Array = _pick_deployment_slots(walkable, width, deployment_rng)
	var objective_pos: Dictionary = _pick_objective(walkable, width, height, mode, objective_rng)
	var fallback_pos: Dictionary = _pick_fallback(walkable, objective_pos, width)
	var enemy_slots: Array = _pick_enemy_slots(walkable, objective_pos, width)
	var route_top: Array = _route_through_gate(
		deployment_slots[0], objective_pos, {"col": ridge_col, "row": top_gate_row}, walkable)
	var route_bottom: Array = _route_through_gate(
		deployment_slots[0], objective_pos, {"col": ridge_col, "row": bottom_gate_row}, walkable)
	if route_top.is_empty() or route_bottom.is_empty():
		var direct_route: Array = _shortest_path(deployment_slots[0], objective_pos, walkable)
		if route_top.is_empty():
			route_top = direct_route
		if route_bottom.is_empty():
			route_bottom = direct_route

	var hazards: Array = _build_hazards(seed, mode, route_top, route_bottom,
		walkable, objective_pos, deployment_slots)
	var routes: Array = _build_routes(route_top, route_bottom, hazards, enemy_slots)
	var chokepoints: Array = _build_chokepoints(
		deployment_slots[0], objective_pos, walkable, ridge_col, top_gate_row, bottom_gate_row)
	var cells: Array = _build_cells(walkable, width, height, ridge_col, objective_pos, fallback_pos)
	var obstacles: Array = _build_obstacles(walkable, width, height, ridge_col)

	return {
		"seed": seed,
		"mode": mode,
		"bounds": {"w": width, "h": height},
		"walkable": walkable,
		"cells": cells,
		"obstacles": obstacles,
		"deployment_slots": deployment_slots,
		"enemy_slots": enemy_slots,
		"enemy_directions": ["east_north", "east_south"],
		"objective_pos": objective_pos,
		"fallback_pos": fallback_pos,
		"hazards": hazards,
		"chokepoints": chokepoints,
		"routes": routes,
		"validation": {"valid": false, "attempt": attempt, "diagnostics": []},
	}


static func _build_obstacles(walkable: Dictionary, width: int, height: int,
		ridge_col: int) -> Array:
	# Obstacles are a presentation projection of topology, never an additional source of
	# collision truth. Enclosed pockets are filled completely. For exterior void, only the
	# cells touching the playable silhouette become raised boundary masses; the remaining
	# exterior stays empty so the renderer can distinguish obstruction from outer void.
	var exterior_void: Dictionary = _exterior_void_cells(walkable, width, height)
	var projected_by_kind: Dictionary = {
		"rock": {},
		"vegetation": {},
		"ruin": {},
	}
	for row in range(height):
		for col in range(width):
			var cell_key: String = _key_xy(col, row)
			if walkable.has(cell_key):
				continue
			var is_exterior: bool = exterior_void.has(cell_key)
			if is_exterior and not _has_cardinal_walkable_neighbor(col, row, walkable):
				continue
			var kind: String = "ruin"
			if col in [ridge_col, ridge_col + 1]:
				kind = "rock"
			elif is_exterior:
				kind = "vegetation"
			(projected_by_kind[kind] as Dictionary)[cell_key] = true

	var result: Array = []
	for kind in ["rock", "vegetation", "ruin"]:
		var groups: Array = _cell_components(projected_by_kind[kind] as Dictionary)
		for group_value in groups:
			var group: Array = group_value if group_value is Array else []
			if group.is_empty():
				continue
			var number: int = result.size() + 1
			result.append({
				"id": "obstacle.%s.%02d" % [kind, number],
				"kind": kind,
				"label": _obstacle_label(kind),
				"cells": group,
			})
	return result


static func _exterior_void_cells(walkable: Dictionary, width: int, height: int) -> Dictionary:
	var exterior: Dictionary = {}
	var queue: Array[String] = []
	for row in range(height):
		for col in range(width):
			if col != 0 and col != width - 1 and row != 0 and row != height - 1:
				continue
			var cell_key: String = _key_xy(col, row)
			if walkable.has(cell_key) or exterior.has(cell_key):
				continue
			exterior[cell_key] = true
			queue.append(cell_key)
	var head: int = 0
	while head < queue.size():
		var current: Dictionary = _cell(queue[head])
		head += 1
		for delta in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var next_col: int = int(current.get("col", 0)) + int(delta[0])
			var next_row: int = int(current.get("row", 0)) + int(delta[1])
			if next_col < 0 or next_col >= width or next_row < 0 or next_row >= height:
				continue
			var next_key: String = _key_xy(next_col, next_row)
			if walkable.has(next_key) or exterior.has(next_key):
				continue
			exterior[next_key] = true
			queue.append(next_key)
	return exterior


static func _has_cardinal_walkable_neighbor(col: int, row: int, walkable: Dictionary) -> bool:
	for delta in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		if walkable.has(_key_xy(col + int(delta[0]), row + int(delta[1]))):
			return true
	return false


static func _cell_components(cell_set: Dictionary) -> Array:
	var remaining: Dictionary = cell_set.duplicate()
	var groups: Array = []
	while not remaining.is_empty():
		var keys: Array = remaining.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return _cell_precedes(_cell(str(a)), _cell(str(b))))
		var first_key: String = str(keys[0])
		var queue: Array[String] = [first_key]
		var group: Array = []
		remaining.erase(first_key)
		var head: int = 0
		while head < queue.size():
			var current_key: String = queue[head]
			head += 1
			var current: Dictionary = _cell(current_key)
			group.append(current)
			for delta in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var next_key: String = _key_xy(
					int(current.get("col", 0)) + int(delta[0]),
					int(current.get("row", 0)) + int(delta[1]))
				if not remaining.has(next_key):
					continue
				remaining.erase(next_key)
				queue.append(next_key)
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _cell_precedes(a, b))
		groups.append(group)
	groups.sort_custom(func(a: Array, b: Array) -> bool:
		return _cell_precedes(a[0] as Dictionary, b[0] as Dictionary))
	return groups


static func _cell_precedes(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("row", 0)) != int(b.get("row", 0)):
		return int(a.get("row", 0)) < int(b.get("row", 0))
	return int(a.get("col", 0)) < int(b.get("col", 0))


static func _obstacle_label(kind: String) -> String:
	match kind:
		"vegetation": return "Dense brush"
		"ruin": return "Weathered remnants"
		_: return "Stone ridge"


static func _pick_deployment_slots(walkable: Dictionary, width: int,
		rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for key_value in walkable.keys():
		var cell: Dictionary = _cell(str(key_value))
		if int(cell.get("col", 0)) <= 1:
			pool.append(cell)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_center: int = abs(int(a.get("row", 0)) - 5)
		var b_center: int = abs(int(b.get("row", 0)) - 5)
		if a_center != b_center:
			return a_center < b_center
		if int(a.get("col", 0)) != int(b.get("col", 0)):
			return int(a.get("col", 0)) > int(b.get("col", 0))
		return int(a.get("row", 0)) < int(b.get("row", 0)))
	var desired: int = rng.randi_range(4, 6)
	var result: Array = []
	for cell_value in pool:
		if result.size() >= desired:
			break
		result.append((cell_value as Dictionary).duplicate(true))
	return result


static func _pick_objective(walkable: Dictionary, width: int, height: int,
		mode: String, rng: RandomNumberGenerator) -> Dictionary:
	var desired_col: int = width - 2 if mode == MODE_RECOVER else width / 2 + 2
	var desired_row: int = clampi(height / 2 + rng.randi_range(-1, 1), 2, height - 3)
	return _nearest_cell({"col": desired_col, "row": desired_row}, walkable, true)


static func _pick_fallback(walkable: Dictionary, objective: Dictionary, width: int) -> Dictionary:
	var desired: Dictionary = {
		"col": maxi(1, int(objective.get("col", 0)) - 2),
		"row": clampi(int(objective.get("row", 0)) + 2, 1, BOARD_HEIGHT - 2),
	}
	var fallback: Dictionary = _nearest_cell(desired, walkable, false)
	if _key(fallback) == _key(objective):
		fallback = _nearest_cell({"col": clampi(width / 2 - 2, 1, width - 2), "row": 5}, walkable, false)
	return fallback


static func _pick_enemy_slots(walkable: Dictionary, objective: Dictionary, width: int) -> Array:
	var desired: Array = [
		{"col": width - 2, "row": 1}, {"col": width - 1, "row": 3},
		{"col": width - 2, "row": 8}, {"col": width - 1, "row": 6},
	]
	var result: Array = []
	var used: Dictionary = {_key(objective): true}
	for target_value in desired:
		var target: Dictionary = target_value if target_value is Dictionary else {}
		var slot: Dictionary = _nearest_unused_cell(target, walkable, used)
		if not slot.is_empty():
			result.append(slot)
			used[_key(slot)] = true
	return result


static func _build_hazards(seed: int, mode: String, route_top: Array, route_bottom: Array,
		walkable: Dictionary, objective: Dictionary, deployments: Array) -> Array:
	var rng: RandomNumberGenerator = _rng_for(seed, "prototype.keeper.board.%s.hazards" % mode)
	var protected: Dictionary = {_key(objective): true}
	for slot_value in deployments:
		protected[_key(slot_value as Dictionary)] = true
	# Put damage on the shorter route and movement delay on the longer route. This makes
	# speed-versus-safety a real choice instead of letting one approach dominate both.
	var shorter_route: Array = route_top if route_top.size() <= route_bottom.size() else route_bottom
	var longer_route: Array = route_bottom if route_top.size() <= route_bottom.size() else route_top
	var burning_cells: Array = _route_zone_cells(shorter_route, walkable, protected, 0.38, 2)
	var binding_cells: Array = _route_zone_cells(longer_route, walkable, protected, 0.62, 2)
	var unstable_center: Dictionary = _pick_hazard_center(walkable, protected, rng)
	var unstable_cells: Array = []
	if not unstable_center.is_empty():
		unstable_cells.append(unstable_center)
		var neighbor: Dictionary = _nearest_unused_cell({
			"col": int(unstable_center.get("col", 0)) + 1,
			"row": int(unstable_center.get("row", 0)),
		}, walkable, protected)
		if not neighbor.is_empty() and _chebyshev(neighbor, unstable_center) <= 1:
			unstable_cells.append(neighbor)
	return [
		{
			"id": "hazard.burning.1", "type": HAZARD_BURNING,
			"cells": burning_cells, "center": _center_of(burning_cells), "damage": BURNING_DAMAGE,
			"label": "Burning Ground",
			"rule": "Deals %d damage after an actor ends a turn here." % BURNING_DAMAGE,
		},
		{
			"id": "hazard.binding.1", "type": HAZARD_BINDING,
			"cells": binding_cells, "center": _center_of(binding_cells), "damage": 0,
			"label": "Binding Growth",
			"rule": "Entering ends remaining movement for that turn.",
		},
		{
			"id": "hazard.unstable.1", "type": HAZARD_UNSTABLE,
			"cells": unstable_cells, "center": unstable_center, "damage": UNSTABLE_FALLBACK_DAMAGE,
			"label": "Unstable Ground",
			"rule": "On entry, pushes away from its center; if blocked, deals %d damage." % UNSTABLE_FALLBACK_DAMAGE,
		},
	]


static func _build_routes(top_path: Array, bottom_path: Array, hazards: Array,
		enemy_slots: Array) -> Array:
	var top_cost: int = _path_hazard_cost(top_path, hazards)
	var bottom_cost: int = _path_hazard_cost(bottom_path, hazards)
	var top_pressure: int = _path_pressure(top_path, enemy_slots)
	var bottom_pressure: int = _path_pressure(bottom_path, enemy_slots)
	var top_width: int = 2
	var bottom_width: int = 2
	if top_path.size() < bottom_path.size():
		top_width = 1
		bottom_width = 2
	elif bottom_path.size() < top_path.size():
		top_width = 2
		bottom_width = 1
	elif top_cost > bottom_cost:
		top_width = 3
		bottom_width = 1
	elif bottom_cost > top_cost:
		top_width = 1
		bottom_width = 3
	return [
		{
			"id": "route.north", "cells": top_path, "length": maxi(0, top_path.size() - 1),
			"hazard_cost": top_cost, "width": top_width, "pressure": top_pressure,
			"tradeoff": "Shorter exposed approach through Burning Ground" if top_path.size() <= bottom_path.size() else "Longer approach with northern enemy pressure",
		},
		{
			"id": "route.south", "cells": bottom_path, "length": maxi(0, bottom_path.size() - 1),
			"hazard_cost": bottom_cost, "width": bottom_width, "pressure": bottom_pressure,
			"tradeoff": "Slower stabilizing approach through Binding Growth" if bottom_path.size() >= top_path.size() else "Shorter approach with movement delay",
		},
	]


static func _build_chokepoints(start: Dictionary, objective: Dictionary,
		walkable: Dictionary, ridge_col: int, top_row: int, bottom_row: int) -> Array:
	var baseline_path: Array = _shortest_path(start, objective, walkable)
	var baseline_distance: int = maxi(0, baseline_path.size() - 1)
	var groups: Array = [
		[{"col": ridge_col, "row": top_row}, {"col": ridge_col, "row": top_row + 1}],
		[{"col": ridge_col, "row": bottom_row - 1}, {"col": ridge_col, "row": bottom_row}],
	]
	var result: Array = []
	for group_value in groups:
		var group: Array = group_value if group_value is Array else []
		var reduced: Dictionary = walkable.duplicate()
		var actual_cells: Array = []
		for cell_value in group:
			var cell: Dictionary = cell_value if cell_value is Dictionary else {}
			if reduced.has(_key(cell)):
				reduced.erase(_key(cell))
				actual_cells.append(cell.duplicate(true))
		var blocked_path: Array = _shortest_path(start, objective, reduced)
		var blocked_distance: int = 9999 if blocked_path.is_empty() else blocked_path.size() - 1
		var impact: int = blocked_distance - baseline_distance if blocked_distance < 9999 else 9999
		result.append({
			"cells": actual_cells,
			"baseline_distance": baseline_distance,
			"blocked_distance": blocked_distance,
			"impact": impact,
		})
	return result


static func _build_cells(walkable: Dictionary, width: int, height: int,
		ridge_col: int, objective: Dictionary, fallback: Dictionary) -> Array:
	var result: Array = []
	var keys: Array = walkable.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ac: Dictionary = _cell(str(a))
		var bc: Dictionary = _cell(str(b))
		if int(ac.get("row", 0)) != int(bc.get("row", 0)):
			return int(ac.get("row", 0)) < int(bc.get("row", 0))
		return int(ac.get("col", 0)) < int(bc.get("col", 0)))
	for key_value in keys:
		var cell: Dictionary = _cell(str(key_value))
		var terrain: String = "carved_path"
		var landmark: String = ""
		var col: int = int(cell.get("col", 0))
		var row: int = int(cell.get("row", 0))
		if col >= width - 4 and row >= 2 and row <= height - 3:
			terrain = "open_ground"
		elif _chebyshev(cell, fallback) <= 1:
			terrain = "defensible_stones"
		elif col in [ridge_col, ridge_col + 1]:
			terrain = "ridge_crossing"
		elif row <= 1 or row >= height - 2:
			terrain = "brush_edge"
		if _key(cell) == _key(objective):
			landmark = "severed_relic" if col >= width / 2 else "totem_court"
		elif col == 2 and row == 2:
			landmark = "termite_mound"
		var entry: Dictionary = {"col": col, "row": row, "terrain": terrain}
		if not landmark.is_empty():
			entry["landmark"] = landmark
		result.append(entry)
	return result


static func _validate_hazards(board: Dictionary, diagnostics: Array[String]) -> bool:
	var hazards: Array = board.get("hazards", [])
	var types: Dictionary = {}
	var nonempty_zones: int = 0
	var walkable: Dictionary = board.get("walkable", {})
	for hazard_value in hazards:
		var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
		var hazard_type: String = str(hazard.get("type", ""))
		if hazard_type not in [HAZARD_BURNING, HAZARD_UNSTABLE, HAZARD_BINDING]:
			continue
		types[hazard_type] = true
		var cells: Array = hazard.get("cells", [])
		if not cells.is_empty():
			nonempty_zones += 1
		for cell_value in cells:
			var cell: Dictionary = cell_value if cell_value is Dictionary else {}
			if not walkable.has(_key(cell)):
				diagnostics.append("Hazard %s contains a non-walkable cell." % hazard_type)
				return false
	var valid: bool = types.size() >= 2 and nonempty_zones >= 2
	if not valid:
		diagnostics.append("Board requires two non-empty zones using at least two hazard types.")
	return valid


static func _validate_obstacles(board: Dictionary, diagnostics: Array[String]) -> bool:
	var walkable: Dictionary = board.get("walkable", {})
	var bounds: Dictionary = board.get("bounds", {})
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	var seen: Dictionary = {}
	var valid: bool = true
	for obstacle_value in board.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value if obstacle_value is Dictionary else {}
		var obstacle_id: String = str(obstacle.get("id", ""))
		var kind: String = str(obstacle.get("kind", ""))
		var label: String = str(obstacle.get("label", ""))
		var cells: Array = obstacle.get("cells", [])
		if obstacle_id.is_empty() or label.is_empty() or kind not in ["rock", "vegetation", "ruin", "landmark"]:
			diagnostics.append("Obstacle projection contains an invalid id, kind, or label.")
			valid = false
		if cells.is_empty():
			diagnostics.append("Obstacle %s has no projected cells." % obstacle_id)
			valid = false
		for cell_value in cells:
			var cell: Dictionary = cell_value if cell_value is Dictionary else {}
			var col: int = int(cell.get("col", -1))
			var row: int = int(cell.get("row", -1))
			var cell_key: String = _key(cell)
			if col < 0 or col >= width or row < 0 or row >= height:
				diagnostics.append("Obstacle %s contains an out-of-bounds cell." % obstacle_id)
				valid = false
			elif walkable.has(cell_key):
				diagnostics.append("Obstacle %s overlaps walkable cell %s." % [obstacle_id, cell_key])
				valid = false
			elif seen.has(cell_key):
				diagnostics.append("Obstacle cell %s is projected more than once." % cell_key)
				valid = false
			seen[cell_key] = true
	if seen.is_empty():
		diagnostics.append("Board has no projected obstacle masses along its playable silhouette.")
		valid = false
	return valid


static func _validate_chokepoints(board: Dictionary) -> bool:
	var walkable: Dictionary = board.get("walkable", {})
	var deployments: Array = board.get("deployment_slots", [])
	if deployments.is_empty():
		return false
	var start: Dictionary = deployments[0]
	var objective: Dictionary = board.get("objective_pos", {})
	var baseline: Array = _shortest_path(start, objective, walkable)
	if baseline.is_empty():
		return false
	var baseline_distance: int = baseline.size() - 1
	for choke_value in board.get("chokepoints", []):
		var choke: Dictionary = choke_value if choke_value is Dictionary else {}
		var cells: Array = choke.get("cells", [])
		if cells.is_empty() or cells.size() > 2:
			continue
		var reduced: Dictionary = walkable.duplicate()
		for cell_value in cells:
			reduced.erase(_key(cell_value as Dictionary))
		var alternate: Array = _shortest_path(start, objective, reduced)
		if alternate.is_empty() or alternate.size() - 1 >= baseline_distance + 2:
			return true
	return false


static func _validate_route_diversity(board: Dictionary) -> bool:
	var routes: Array = board.get("routes", [])
	if routes.size() < 2:
		return false
	var a: Dictionary = routes[0] if routes[0] is Dictionary else {}
	var b: Dictionary = routes[1] if routes[1] is Dictionary else {}
	var a_cells: Array = a.get("cells", [])
	var b_cells: Array = b.get("cells", [])
	if a_cells.is_empty() or b_cells.is_empty() or _path_signature(a_cells) == _path_signature(b_cells):
		return false
	var distinct_cells: int = _distinct_path_cells(a_cells, b_cells)
	if distinct_cells < 3:
		return false
	var a_dominates: bool = int(a.get("length", 9999)) <= int(b.get("length", 9999)) \
		and int(a.get("hazard_cost", 9999)) <= int(b.get("hazard_cost", 9999)) \
		and int(a.get("pressure", 9999)) <= int(b.get("pressure", 9999)) \
		and int(a.get("width", 0)) >= int(b.get("width", 0))
	var b_dominates: bool = int(b.get("length", 9999)) <= int(a.get("length", 9999)) \
		and int(b.get("hazard_cost", 9999)) <= int(a.get("hazard_cost", 9999)) \
		and int(b.get("pressure", 9999)) <= int(a.get("pressure", 9999)) \
		and int(b.get("width", 0)) >= int(a.get("width", 0))
	return not a_dominates and not b_dominates


static func _has_nonlethal_route(board: Dictionary) -> bool:
	for route_value in board.get("routes", []):
		var route: Dictionary = route_value if route_value is Dictionary else {}
		var unavoidable_damage: int = 0
		for cell_value in route.get("cells", []):
			var cell: Dictionary = cell_value if cell_value is Dictionary else {}
			for hazard_value in board.get("hazards", []):
				var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
				if str(hazard.get("type", "")) == HAZARD_BURNING and _hazard_contains(hazard, cell):
					unavoidable_damage += int(hazard.get("damage", BURNING_DAMAGE))
		if unavoidable_damage < ASSUMED_ACTOR_HP:
			return true
	return false


static func _has_required_features(board: Dictionary) -> bool:
	var has_open: bool = false
	var has_defensible: bool = false
	var has_landmark: bool = false
	for cell_value in board.get("cells", []):
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		var terrain: String = str(cell.get("terrain", ""))
		has_open = has_open or terrain == "open_ground"
		has_defensible = has_defensible or terrain == "defensible_stones"
		has_landmark = has_landmark or cell.has("landmark")
	return has_open and has_defensible and has_landmark


static func _route_through_gate(start: Dictionary, objective: Dictionary,
		gate: Dictionary, walkable: Dictionary) -> Array:
	var first: Array = _shortest_path(start, gate, walkable)
	var second: Array = _shortest_path(gate, objective, walkable)
	if first.is_empty() or second.is_empty():
		return []
	second.pop_front()
	first.append_array(second)
	return first


static func _shortest_path(start: Dictionary, target: Dictionary,
		walkable: Dictionary) -> Array:
	var start_key: String = _key(start)
	var target_key: String = _key(target)
	if not walkable.has(start_key) or not walkable.has(target_key):
		return []
	var queue: Array[String] = [start_key]
	var parents: Dictionary = {start_key: ""}
	var head: int = 0
	while head < queue.size():
		var current_key: String = queue[head]
		head += 1
		if current_key == target_key:
			break
		var current: Dictionary = _cell(current_key)
		for delta_value in _DELTAS_8:
			var delta: Array = delta_value if delta_value is Array else []
			var next_key: String = _key_xy(
				int(current.get("col", 0)) + int(delta[0]),
				int(current.get("row", 0)) + int(delta[1]))
			if walkable.has(next_key) and not parents.has(next_key):
				parents[next_key] = current_key
				queue.append(next_key)
	if not parents.has(target_key):
		return []
	var reversed: Array = []
	var cursor: String = target_key
	while not cursor.is_empty():
		reversed.append(_cell(cursor))
		cursor = str(parents.get(cursor, ""))
	reversed.reverse()
	return reversed


static func _distance_field(target: Dictionary, walkable: Dictionary) -> Dictionary:
	var target_key: String = _key(target)
	if not walkable.has(target_key):
		return {}
	var distances: Dictionary = {target_key: 0}
	var queue: Array[String] = [target_key]
	var head: int = 0
	while head < queue.size():
		var current_key: String = queue[head]
		head += 1
		var current: Dictionary = _cell(current_key)
		for delta_value in _DELTAS_8:
			var delta: Array = delta_value if delta_value is Array else []
			var next_key: String = _key_xy(
				int(current.get("col", 0)) + int(delta[0]),
				int(current.get("row", 0)) + int(delta[1]))
			if walkable.has(next_key) and not distances.has(next_key):
				distances[next_key] = int(distances[current_key]) + 1
				queue.append(next_key)
	return distances


static func _is_connected(walkable: Dictionary) -> bool:
	if walkable.is_empty():
		return false
	var first_key: String = str(walkable.keys()[0])
	return _distance_field(_cell(first_key), walkable).size() == walkable.size()


static func _unstable_push_cell(position: Dictionary, center: Dictionary,
		board: Dictionary, occupied: Dictionary) -> Dictionary:
	var dc: int = signi(int(position.get("col", 0)) - int(center.get("col", 0)))
	var dr: int = signi(int(position.get("row", 0)) - int(center.get("row", 0)))
	if dc == 0 and dr == 0:
		dr = -1
	var candidates: Array = []
	for delta_value in _DELTAS_8:
		var delta: Array = delta_value if delta_value is Array else []
		var candidate: Dictionary = {
			"col": int(position.get("col", 0)) + int(delta[0]),
			"row": int(position.get("row", 0)) + int(delta[1]),
		}
		var alignment: int = int(delta[0]) * dc + int(delta[1]) * dr
		var distance_from_center: int = _chebyshev(candidate, center)
		candidates.append({"cell": candidate, "alignment": alignment, "distance": distance_from_center})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("distance", 0)) != int(b.get("distance", 0)):
			return int(a.get("distance", 0)) > int(b.get("distance", 0))
		if int(a.get("alignment", 0)) != int(b.get("alignment", 0)):
			return int(a.get("alignment", 0)) > int(b.get("alignment", 0))
		var ac: Dictionary = a.get("cell", {})
		var bc: Dictionary = b.get("cell", {})
		if int(ac.get("row", 0)) != int(bc.get("row", 0)):
			return int(ac.get("row", 0)) < int(bc.get("row", 0))
		return int(ac.get("col", 0)) < int(bc.get("col", 0)))
	var walkable: Dictionary = board.get("walkable", {})
	for candidate_value in candidates:
		var item: Dictionary = candidate_value if candidate_value is Dictionary else {}
		var candidate: Dictionary = item.get("cell", {})
		var candidate_key: String = _key(candidate)
		if int(item.get("distance", 0)) <= _chebyshev(position, center):
			continue
		if walkable.has(candidate_key) and not occupied.has(candidate_key):
			return candidate
	return {}


static func _route_zone_cells(route: Array, walkable: Dictionary, protected: Dictionary,
		fraction: float, count: int) -> Array:
	var result: Array = []
	if route.is_empty():
		return result
	var center_index: int = clampi(int(round(float(route.size() - 1) * fraction)), 0, route.size() - 1)
	for offset in range(route.size()):
		for signed_offset in [offset, -offset]:
			var index: int = center_index + int(signed_offset)
			if index < 0 or index >= route.size():
				continue
			var cell: Dictionary = route[index] if route[index] is Dictionary else {}
			if protected.has(_key(cell)) or not walkable.has(_key(cell)) or _contains_cell(result, cell):
				continue
			result.append(cell.duplicate(true))
			if result.size() >= count:
				return result
	return result


static func _pick_hazard_center(walkable: Dictionary, protected: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	for key_value in walkable.keys():
		var key: String = str(key_value)
		if protected.has(key):
			continue
		var cell: Dictionary = _cell(key)
		if int(cell.get("col", 0)) >= 3 and int(cell.get("row", 0)) >= 2 \
				and int(cell.get("row", 0)) <= BOARD_HEIGHT - 3:
			pool.append(cell)
	if pool.is_empty():
		return {}
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b))
	return (pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).duplicate(true)


static func _path_hazard_cost(path: Array, hazards: Array) -> int:
	var cost: int = 0
	for cell_value in path:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		for hazard_value in hazards:
			var hazard: Dictionary = hazard_value if hazard_value is Dictionary else {}
			if not _hazard_contains(hazard, cell):
				continue
			match str(hazard.get("type", "")):
				HAZARD_BURNING: cost += int(hazard.get("damage", BURNING_DAMAGE))
				HAZARD_UNSTABLE: cost += 3
				HAZARD_BINDING: cost += 2
	return cost


static func _path_pressure(path: Array, enemies: Array) -> int:
	var pressure: int = 0
	for cell_value in path:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		for enemy_value in enemies:
			var enemy: Dictionary = enemy_value if enemy_value is Dictionary else {}
			if _chebyshev(cell, enemy) <= 2:
				pressure += 1
	return pressure


static func _minimum_path_width(path: Array) -> int:
	# The authored ridge gates are two cells wide. This field remains explicit for UI/debug.
	return 2 if path.size() > 1 else 1


static func _nearest_cell(target: Dictionary, walkable: Dictionary,
		prefer_high_col: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 999999
	for key_value in walkable.keys():
		var cell: Dictionary = _cell(str(key_value))
		var distance: int = _chebyshev(cell, target)
		if distance < best_distance:
			best = cell
			best_distance = distance
		elif distance == best_distance:
			var better_col: bool = int(cell.get("col", 0)) > int(best.get("col", 0)) if prefer_high_col \
				else int(cell.get("col", 0)) < int(best.get("col", 0))
			if better_col or (int(cell.get("col", 0)) == int(best.get("col", 0)) \
					and int(cell.get("row", 0)) < int(best.get("row", 0))):
				best = cell
	return best.duplicate(true)


static func _nearest_unused_cell(target: Dictionary, walkable: Dictionary,
		used: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 999999
	for key_value in walkable.keys():
		var key: String = str(key_value)
		if used.has(key):
			continue
		var cell: Dictionary = _cell(key)
		var distance: int = _chebyshev(cell, target)
		if distance < best_distance or (distance == best_distance and key < _key(best)):
			best = cell
			best_distance = distance
	return best.duplicate(true)


static func _near_any(cell: Dictionary, targets: Array, radius: int) -> bool:
	for target_value in targets:
		var target: Dictionary = target_value if target_value is Dictionary else {}
		if _chebyshev(cell, target) <= radius:
			return true
	return false


static func _center_of(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	var col_sum: int = 0
	var row_sum: int = 0
	for cell_value in cells:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		col_sum += int(cell.get("col", 0))
		row_sum += int(cell.get("row", 0))
	return {"col": int(round(float(col_sum) / float(cells.size()))),
		"row": int(round(float(row_sum) / float(cells.size())))}


static func _hazard_contains(hazard: Dictionary, position: Dictionary) -> bool:
	for cell_value in hazard.get("cells", []):
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		if _key(cell) == _key(position):
			return true
	return false


static func _contains_cell(cells: Array, target: Dictionary) -> bool:
	for cell_value in cells:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		if _key(cell) == _key(target):
			return true
	return false


static func _distinct_path_cells(a: Array, b: Array) -> int:
	var b_set: Dictionary = {}
	for cell_value in b:
		b_set[_key(cell_value as Dictionary)] = true
	var count: int = 0
	for cell_value in a:
		if not b_set.has(_key(cell_value as Dictionary)):
			count += 1
	return count


static func _path_signature(path: Array) -> String:
	var keys: Array[String] = []
	for cell_value in path:
		keys.append(_key(cell_value as Dictionary))
	return "|".join(keys)


static func _hazard_event(actor: Dictionary, hazard: Dictionary, effect: String,
		damage: int, from_pos: Dictionary, to_pos: Dictionary) -> Dictionary:
	return {
		"type": "hazard.%s" % effect,
		"actor_id": str(actor.get("id", "")),
		"hazard_id": str(hazard.get("id", "")),
		"hazard_type": str(hazard.get("type", "")),
		"damage": damage,
		"from_pos": from_pos.duplicate(true),
		"to_pos": to_pos.duplicate(true),
		"actor_dead": bool(actor.get("is_dead", false)),
	}


static func _apply_damage(actor: Dictionary, damage: int) -> void:
	actor["current_hp"] = maxi(0, int(actor.get("current_hp", 0)) - maxi(0, damage))
	if int(actor.get("current_hp", 0)) <= 0:
		actor["is_dead"] = true


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Dictionary = {}
		for key_value in keys:
			result[str(key_value)] = _canonicalize(source[key_value])
		return result
	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_canonicalize(item))
		return result_array
	return value


static func _rng_for(seed: int, namespace_path: String) -> RandomNumberGenerator:
	var mixed: int = seed ^ 0x4B545047
	for index in range(namespace_path.length()):
		mixed = int((mixed * 1103515245 + namespace_path.unicode_at(index) + 12345) & 0x7FFFFFFFFFFFFFFF)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = mixed
	return rng


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[other]
		values[other] = temporary


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(abs(int(a.get("col", 0)) - int(b.get("col", 0))),
		abs(int(a.get("row", 0)) - int(b.get("row", 0))))


static func _key(cell: Dictionary) -> String:
	return _key_xy(int(cell.get("col", -999)), int(cell.get("row", -999)))


static func _key_xy(col: int, row: int) -> String:
	return "%d,%d" % [col, row]


static func _cell(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	if parts.size() < 2:
		return {}
	return {"col": int(parts[0]), "row": int(parts[1])}
