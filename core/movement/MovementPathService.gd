class_name MovementPathService
extends RefCounted

## Pure deterministic weighted routing primitives shared by movement domains.
##
## Topology and diagonal legality remain owned by StageTerrain. Terrain costs are
## destination-entry overrides: an absent entry costs 1 and a present entry must
## be a positive integer. Paths returned by this service always exclude origin.


## Returns {reachable, path, cost, reason}. `path` is ordered and excludes
## `origin`. Equal-cost routes prefer the lowest cumulative deviation from the
## origin-to-destination line, then straighter relative progress. Numeric cell
## order (col, then row) is used only for irreducible perfect symmetry, never
## Dictionary iteration or lexical cell-key order.
static func shortest_path(
	origin: Dictionary,
	destination: Dictionary,
	walkable: Dictionary,
	terrain_costs: Dictionary = {},
	bounds: Dictionary = {}
) -> Dictionary:
	if not _is_cell(origin):
		return _path_failure("invalid_origin")
	if not _is_cell(destination):
		return _path_failure("invalid_destination")
	if not _is_available_cell(origin, walkable, bounds):
		return _path_failure("origin_not_walkable")
	if not _is_available_cell(destination, walkable, bounds):
		return _path_failure("destination_not_walkable")

	var origin_cell: Dictionary = _normalized_cell(origin)
	var destination_cell: Dictionary = _normalized_cell(destination)
	var origin_key: String = _cell_key(origin_cell)
	var destination_key: String = _cell_key(destination_cell)
	if origin_key == destination_key:
		return {
			"reachable": true,
			"path": [],
			"cost": 0,
			"reason": "reached_destination",
		}

	var costs: Dictionary = {origin_key: 0}
	var deviations: Dictionary = {origin_key: 0}
	var predecessors: Dictionary = {}
	var frontier: Dictionary = {origin_key: origin_cell}
	var settled: Dictionary = {}

	while not frontier.is_empty():
		var current: Dictionary = _take_lowest_cost_cell(
			frontier,
			costs,
			deviations,
			destination_cell
		)
		var current_key: String = _cell_key(current)
		if current_key.is_empty():
			break
		if settled.has(current_key):
			continue
		settled[current_key] = true

		if current_key == destination_key:
			return {
				"reachable": true,
				"path": _reconstruct_path(origin_key, destination_key, predecessors),
				"cost": int(costs[destination_key]),
				"reason": "reached_destination",
			}

		var current_cost: int = int(costs[current_key])
		var current_deviation: int = int(deviations[current_key])
		for neighbor_value: Variant in StageTerrain.legal_neighbors(current, walkable, bounds):
			var neighbor: Dictionary = neighbor_value if neighbor_value is Dictionary else {}
			var neighbor_key: String = _cell_key(neighbor)
			if settled.has(neighbor_key):
				continue
			var entry_cost: int = _entry_cost(neighbor_key, terrain_costs)
			if entry_cost < 1:
				return _path_failure("invalid_terrain_cost")
			var candidate_cost: int = current_cost + entry_cost
			var candidate_deviation: int = current_deviation + _line_deviation(
				origin_cell,
				destination_cell,
				neighbor
			)
			var improves_route: bool = not costs.has(neighbor_key) \
				or candidate_cost < int(costs[neighbor_key]) \
				or (candidate_cost == int(costs[neighbor_key]) \
					and candidate_deviation < int(deviations[neighbor_key]))
			if improves_route:
				costs[neighbor_key] = candidate_cost
				deviations[neighbor_key] = candidate_deviation
				predecessors[neighbor_key] = current_key
				frontier[neighbor_key] = _normalized_cell(neighbor)
			# Equal cost and deviation deliberately retain the first predecessor.
			# Relative frontier ordering makes it stable before numeric fallback.

	return _path_failure("unreachable")


## Returns {reachable, costs, reason}. `costs` maps canonical "col,row" keys to
## minimum integer cost and always contains origin at 0 on success.
static func reachable_cost_region(
	origin: Dictionary,
	capacity: int,
	walkable: Dictionary,
	terrain_costs: Dictionary = {},
	bounds: Dictionary = {}
) -> Dictionary:
	if capacity < 0:
		return _region_failure("invalid_capacity")
	if not _is_cell(origin):
		return _region_failure("invalid_origin")
	if not _is_available_cell(origin, walkable, bounds):
		return _region_failure("origin_not_walkable")

	var origin_cell: Dictionary = _normalized_cell(origin)
	var origin_key: String = _cell_key(origin_cell)
	var costs: Dictionary = {origin_key: 0}
	var frontier: Dictionary = {origin_key: origin_cell}
	var settled: Dictionary = {}

	while not frontier.is_empty():
		var current: Dictionary = _take_lowest_cost_cell(frontier, costs)
		var current_key: String = _cell_key(current)
		if current_key.is_empty():
			break
		if settled.has(current_key):
			continue
		settled[current_key] = true
		var current_cost: int = int(costs[current_key])
		if current_cost >= capacity:
			continue

		for neighbor_value: Variant in StageTerrain.legal_neighbors(current, walkable, bounds):
			var neighbor: Dictionary = neighbor_value if neighbor_value is Dictionary else {}
			var neighbor_key: String = _cell_key(neighbor)
			if settled.has(neighbor_key):
				continue
			var entry_cost: int = _entry_cost(neighbor_key, terrain_costs)
			if entry_cost < 1:
				return _region_failure("invalid_terrain_cost")
			var candidate_cost: int = current_cost + entry_cost
			if candidate_cost > capacity:
				continue
			if not costs.has(neighbor_key) or candidate_cost < int(costs[neighbor_key]):
				costs[neighbor_key] = candidate_cost
				frontier[neighbor_key] = _normalized_cell(neighbor)

	return {
		"reachable": true,
		"costs": costs,
		"reason": "region_built",
	}


## Validates and totals one caller-supplied ordered route. `path` must exclude
## origin. Returns {valid, cost, reason}; on failure cost is the valid prefix cost.
static func validate_route(
	origin: Dictionary,
	path: Array,
	walkable: Dictionary,
	terrain_costs: Dictionary = {},
	bounds: Dictionary = {}
) -> Dictionary:
	if not _is_cell(origin):
		return _route_failure("invalid_origin", 0)
	if not _is_available_cell(origin, walkable, bounds):
		return _route_failure("origin_not_walkable", 0)

	var current: Dictionary = _normalized_cell(origin)
	var origin_key: String = _cell_key(current)
	var total_cost: int = 0
	for index in range(path.size()):
		var next_value: Variant = path[index]
		if not next_value is Dictionary or not _is_cell(next_value as Dictionary):
			return _route_failure("invalid_path_cell", total_cost)
		var next_cell: Dictionary = _normalized_cell(next_value as Dictionary)
		if _cell_key(next_cell) == origin_key:
			return _route_failure("path_includes_origin", total_cost)

		var delta_col: int = abs(int(next_cell["col"]) - int(current["col"]))
		var delta_row: int = abs(int(next_cell["row"]) - int(current["row"]))
		if max(delta_col, delta_row) != 1:
			return _route_failure("discontinuous_path", total_cost)
		if not StageTerrain.is_legal_edge(current, next_cell, walkable, bounds):
			return _route_failure("illegal_edge", total_cost)

		var entry_cost: int = _entry_cost(_cell_key(next_cell), terrain_costs)
		if entry_cost < 1:
			return _route_failure("invalid_terrain_cost", total_cost)
		total_cost += entry_cost
		current = next_cell

	return {
		"valid": true,
		"cost": total_cost,
		"reason": "valid_route",
	}


static func _take_lowest_cost_cell(
	frontier: Dictionary,
	costs: Dictionary,
	deviations: Dictionary = {},
	destination: Dictionary = {}
) -> Dictionary:
	var found: bool = false
	var best_key: String = ""
	var best_cell: Dictionary = {}
	var best_cost: int = 0
	var best_deviation: int = 0
	for key_value: Variant in frontier:
		var key: String = str(key_value)
		var cell_value: Variant = frontier[key]
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		var cost: int = int(costs.get(key, 0))
		var deviation: int = int(deviations.get(key, 0))
		if not found \
				or cost < best_cost \
				or (cost == best_cost and deviation < best_deviation) \
				or (cost == best_cost and deviation == best_deviation \
					and _relative_progress_less(cell, best_cell, destination)) \
				or (cost == best_cost and deviation == best_deviation \
					and _same_relative_progress(cell, best_cell, destination) \
					and _cell_less(cell, best_cell)):
			found = true
			best_key = key
			best_cell = cell
			best_cost = cost
			best_deviation = deviation
	if found:
		frontier.erase(best_key)
	return best_cell


static func _reconstruct_path(
	origin_key: String,
	destination_key: String,
	predecessors: Dictionary
) -> Array:
	var reversed_path: Array = []
	var cursor: String = destination_key
	while cursor != origin_key:
		reversed_path.append(_cell_from_key(cursor))
		if not predecessors.has(cursor):
			return []
		cursor = str(predecessors[cursor])
	reversed_path.reverse()
	return reversed_path


static func _entry_cost(cell_key: String, terrain_costs: Dictionary) -> int:
	if not terrain_costs.has(cell_key):
		return 1
	var value: Variant = terrain_costs[cell_key]
	if not value is int or int(value) < 1:
		return -1
	return int(value)


static func _is_available_cell(
	cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary
) -> bool:
	if not _is_in_bounds(cell, bounds):
		return false
	return StageTerrain.is_walkable(cell, walkable)


static func _is_in_bounds(cell: Dictionary, bounds: Dictionary) -> bool:
	if bounds.is_empty():
		return true
	var col: int = int(cell["col"])
	var row: int = int(cell["row"])
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	return col >= 0 and row >= 0 and col < width and row < height


static func _is_cell(value: Dictionary) -> bool:
	return value.has("col") \
		and value.has("row") \
		and value["col"] is int \
		and value["row"] is int


static func _normalized_cell(cell: Dictionary) -> Dictionary:
	return {"col": int(cell["col"]), "row": int(cell["row"])}


static func _cell_key(cell: Dictionary) -> String:
	if not _is_cell(cell):
		return ""
	return "%d,%d" % [int(cell["col"]), int(cell["row"])]


static func _cell_from_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	return {"col": int(parts[0]), "row": int(parts[1])}


static func _cell_less(left: Dictionary, right: Dictionary) -> bool:
	var left_col: int = int(left.get("col", 0))
	var right_col: int = int(right.get("col", 0))
	if left_col != right_col:
		return left_col < right_col
	return int(left.get("row", 0)) < int(right.get("row", 0))


static func _line_deviation(
	origin: Dictionary,
	destination: Dictionary,
	cell: Dictionary
) -> int:
	var line_col: int = int(destination["col"]) - int(origin["col"])
	var line_row: int = int(destination["row"]) - int(origin["row"])
	var cell_col: int = int(cell["col"]) - int(origin["col"])
	var cell_row: int = int(cell["row"]) - int(origin["row"])
	# Absolute 2D cross product is an integer-scaled perpendicular deviation.
	# It avoids float precision and is covariant under board reflection.
	return abs(cell_col * line_row - cell_row * line_col)


static func _relative_progress_less(
	left: Dictionary,
	right: Dictionary,
	destination: Dictionary
) -> bool:
	if destination.is_empty():
		return false
	var left_chebyshev: int = _chebyshev_to(left, destination)
	var right_chebyshev: int = _chebyshev_to(right, destination)
	if left_chebyshev != right_chebyshev:
		return left_chebyshev < right_chebyshev
	return _manhattan_to(left, destination) < _manhattan_to(right, destination)


static func _same_relative_progress(
	left: Dictionary,
	right: Dictionary,
	destination: Dictionary
) -> bool:
	if destination.is_empty():
		return true
	return _chebyshev_to(left, destination) == _chebyshev_to(right, destination) \
		and _manhattan_to(left, destination) == _manhattan_to(right, destination)


static func _chebyshev_to(cell: Dictionary, destination: Dictionary) -> int:
	return max(
		abs(int(cell["col"]) - int(destination["col"])),
		abs(int(cell["row"]) - int(destination["row"]))
	)


static func _manhattan_to(cell: Dictionary, destination: Dictionary) -> int:
	return abs(int(cell["col"]) - int(destination["col"])) \
		+ abs(int(cell["row"]) - int(destination["row"]))


static func _path_failure(reason: String) -> Dictionary:
	return {
		"reachable": false,
		"path": [],
		"cost": -1,
		"reason": reason,
	}


static func _region_failure(reason: String) -> Dictionary:
	return {
		"reachable": false,
		"costs": {},
		"reason": reason,
	}


static func _route_failure(reason: String, cost: int) -> Dictionary:
	return {
		"valid": false,
		"cost": cost,
		"reason": reason,
	}
