class_name MovementPathTests
extends RefCounted

## Slice-1 contract coverage for pure weighted routing primitives.

const _MovementPathService = preload("res://core/movement/MovementPathService.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test(
		"movement_path/shortest_excludes_origin",
		Callable(MovementPathTests, "_t_shortest_excludes_origin")
	)
	runner.register_test(
		"movement_path/origin_equals_destination",
		Callable(MovementPathTests, "_t_origin_equals_destination")
	)
	runner.register_test(
		"movement_path/weighted_route_prefers_longer_safe_path",
		Callable(MovementPathTests, "_t_weighted_route_prefers_longer_safe_path")
	)
	runner.register_test(
		"movement_path/diagonal_uses_shared_corner_rule",
		Callable(MovementPathTests, "_t_diagonal_uses_shared_corner_rule")
	)
	runner.register_test(
		"movement_path/unreachable_has_reason",
		Callable(MovementPathTests, "_t_unreachable_has_reason")
	)
	runner.register_test(
		"movement_path/reachable_region_capacity_boundary",
		Callable(MovementPathTests, "_t_reachable_region_capacity_boundary")
	)
	runner.register_test(
		"movement_path/route_cost_validation",
		Callable(MovementPathTests, "_t_route_cost_validation")
	)
	runner.register_test(
		"movement_path/replay_dictionary_order_stable",
		Callable(MovementPathTests, "_t_replay_dictionary_order_stable")
	)
	runner.register_test(
		"movement_path/mirrored_board_covariance",
		Callable(MovementPathTests, "_t_mirrored_board_covariance")
	)
	runner.register_test(
		"movement_path/invalid_terrain_cost_envelopes",
		Callable(MovementPathTests, "_t_invalid_terrain_cost_envelopes")
	)


static func _t_shortest_excludes_origin() -> Dictionary:
	var origin := _cell(0, 0)
	var destination := _cell(2, 0)
	var result: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		_walkable([origin, _cell(1, 0), destination]),
		{},
		{"w": 3, "h": 1}
	)
	if not bool(result.get("reachable", false)):
		return _fail("Expected destination to be reachable: %s" % str(result))
	if int(result.get("cost", -1)) != 2:
		return _fail("Expected cost 2, got %s" % str(result.get("cost", null)))
	var path: Array = result.get("path", [])
	if path != [_cell(1, 0), destination]:
		return _fail("Expected ordered path excluding origin, got %s" % str(path))
	if path.has(origin):
		return _fail("Shortest path repeated its origin")
	return _pass()


static func _t_origin_equals_destination() -> Dictionary:
	var origin := _cell(3, 4)
	var result: Dictionary = _MovementPathService.shortest_path(
		origin,
		origin,
		_walkable([origin])
	)
	if not bool(result.get("reachable", false)):
		return _fail("Origin should reach itself")
	if result.get("path", [origin]) != []:
		return _fail("Origin==destination path must be empty")
	if int(result.get("cost", -1)) != 0:
		return _fail("Origin==destination cost must be 0")
	if str(result.get("reason", "")) != "reached_destination":
		return _fail("Origin==destination reason must report success")
	return _pass()


static func _t_weighted_route_prefers_longer_safe_path() -> Dictionary:
	var origin := _cell(0, 0)
	var destination := _cell(3, 0)
	var direct_middle_a := _cell(1, 0)
	var direct_middle_b := _cell(2, 0)
	var safe_cells: Array = [
		_cell(0, 1),
		_cell(0, 2),
		_cell(1, 2),
		_cell(2, 2),
		_cell(3, 2),
		_cell(3, 1),
	]
	var cells: Array = [origin, direct_middle_a, direct_middle_b, destination]
	cells.append_array(safe_cells)
	var terrain_costs := {
		"1,0": 4,
		"2,0": 4,
	}
	var result: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		_walkable(cells),
		terrain_costs,
		{"w": 4, "h": 3}
	)
	if not bool(result.get("reachable", false)):
		return _fail("Weighted fixture should remain reachable: %s" % str(result))
	var path: Array = result.get("path", [])
	if path.has(direct_middle_a) or path.has(direct_middle_b):
		return _fail("Route used costly direct corridor instead of safe detour: %s" % str(path))
	if path.size() <= 3:
		return _fail("Expected safe route to be longer than direct three-edge route")
	if int(result.get("cost", -1)) != path.size():
		return _fail("Safe normal-ground route cost should equal its edge count")
	return _pass()


static func _t_diagonal_uses_shared_corner_rule() -> Dictionary:
	var origin := _cell(0, 0)
	var destination := _cell(1, 1)
	var both_solid: Dictionary = _walkable([origin, destination])
	var blocked: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		both_solid,
		{},
		{"w": 2, "h": 2}
	)
	if bool(blocked.get("reachable", true)):
		return _fail("Diagonal through two solid orthogonal sides must be blocked")

	var one_side_open: Dictionary = _walkable([origin, _cell(0, 1), destination])
	var open: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		one_side_open,
		{},
		{"w": 2, "h": 2}
	)
	if not bool(open.get("reachable", false)):
		return _fail("Diagonal with one open orthogonal side must remain legal")
	if open.get("path", []) != [destination] or int(open.get("cost", -1)) != 1:
		return _fail("Expected direct one-cost diagonal, got %s" % str(open))
	return _pass()


static func _t_unreachable_has_reason() -> Dictionary:
	var origin := _cell(0, 0)
	var destination := _cell(3, 3)
	var result: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		_walkable([origin, destination]),
		{},
		{"w": 4, "h": 4}
	)
	if bool(result.get("reachable", true)):
		return _fail("Disconnected destination must be unreachable")
	if result.get("path", [origin]) != []:
		return _fail("Unreachable result must not expose a partial path")
	if int(result.get("cost", 0)) != -1:
		return _fail("Unreachable result must use cost -1")
	if str(result.get("reason", "")) != "unreachable":
		return _fail("Expected deterministic unreachable reason, got %s" % result.get("reason", null))
	return _pass()


static func _t_reachable_region_capacity_boundary() -> Dictionary:
	var origin := _cell(0, 0)
	var result: Dictionary = _MovementPathService.reachable_cost_region(
		origin,
		3,
		_walkable([origin, _cell(1, 0), _cell(2, 0), _cell(3, 0)]),
		{"2,0": 2},
		{"w": 4, "h": 1}
	)
	if not bool(result.get("reachable", false)):
		return _fail("Expected reachable region success: %s" % str(result))
	var costs: Dictionary = result.get("costs", {})
	if int(costs.get("0,0", -1)) != 0:
		return _fail("Reachable region must contain origin at cost 0")
	if int(costs.get("1,0", -1)) != 1:
		return _fail("First normal cell should cost 1")
	if int(costs.get("2,0", -1)) != 3:
		return _fail("Difficult boundary cell should be included at exact capacity 3")
	if costs.has("3,0"):
		return _fail("Cell beyond capacity boundary must be excluded")

	var invalid: Dictionary = _MovementPathService.reachable_cost_region(
		origin,
		-1,
		_walkable([origin])
	)
	if bool(invalid.get("reachable", true)) or str(invalid.get("reason", "")) != "invalid_capacity":
		return _fail("Negative capacity must be rejected deterministically")
	return _pass()


static func _t_route_cost_validation() -> Dictionary:
	var origin := _cell(0, 0)
	var walkable: Dictionary = _walkable([
		origin,
		_cell(1, 0),
		_cell(2, 0),
		_cell(2, 1),
	])
	var valid: Dictionary = _MovementPathService.validate_route(
		origin,
		[_cell(1, 0), _cell(2, 0), _cell(2, 1)],
		walkable,
		{"2,0": 2},
		{"w": 3, "h": 2}
	)
	if not bool(valid.get("valid", false)) or int(valid.get("cost", -1)) != 4:
		return _fail("Expected valid route cost 4, got %s" % str(valid))
	if str(valid.get("reason", "")) != "valid_route":
		return _fail("Valid route must report valid_route")

	var includes_origin: Dictionary = _MovementPathService.validate_route(
		origin,
		[origin, _cell(1, 0)],
		walkable
	)
	if str(includes_origin.get("reason", "")) != "path_includes_origin":
		return _fail("Route repeating origin first must be rejected explicitly")

	var returns_to_origin: Dictionary = _MovementPathService.validate_route(
		origin,
		[_cell(1, 0), origin],
		walkable
	)
	if bool(returns_to_origin.get("valid", true)) \
			or str(returns_to_origin.get("reason", "")) != "path_includes_origin":
		return _fail("Route returning to origin later must be rejected explicitly")
	if int(returns_to_origin.get("cost", -1)) != 1:
		return _fail("Later origin rejection must preserve valid-prefix cost 1")

	var discontinuous: Dictionary = _MovementPathService.validate_route(
		origin,
		[_cell(2, 0)],
		walkable
	)
	if bool(discontinuous.get("valid", true)) \
			or str(discontinuous.get("reason", "")) != "discontinuous_path":
		return _fail("Discontinuous route must be rejected deterministically")

	var diagonal_destination := _cell(1, 1)
	var illegal_edge: Dictionary = _MovementPathService.validate_route(
		origin,
		[diagonal_destination],
		_walkable([origin, diagonal_destination]),
		{},
		{"w": 2, "h": 2}
	)
	if bool(illegal_edge.get("valid", true)) \
			or str(illegal_edge.get("reason", "")) != "illegal_edge":
		return _fail("Adjacent edge violating shared corner topology must be rejected")

	var invalid_cost: Dictionary = _MovementPathService.validate_route(
		origin,
		[_cell(1, 0)],
		walkable,
		{"1,0": 0}
	)
	if str(invalid_cost.get("reason", "")) != "invalid_terrain_cost":
		return _fail("Encountered non-positive terrain cost must be rejected")
	return _pass()


static func _t_replay_dictionary_order_stable() -> Dictionary:
	var cells: Array = []
	for col in range(3):
		for row in range(3):
			cells.append(_cell(col, row))
	var reverse_cells: Array = cells.duplicate(true)
	reverse_cells.reverse()
	var origin := _cell(0, 1)
	var destination := _cell(2, 1)
	var result_a: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		_walkable(cells),
		{},
		{"w": 3, "h": 3}
	)
	var result_b: Dictionary = _MovementPathService.shortest_path(
		origin,
		destination,
		_walkable(reverse_cells),
		{},
		{"w": 3, "h": 3}
	)
	if result_a != result_b:
		return _fail("Dictionary insertion order changed path result: %s vs %s" % [result_a, result_b])
	var expected_path: Array = [_cell(1, 1), destination]
	if result_a.get("path", []) != expected_path:
		return _fail("Expected straight relative route %s, got %s" % [expected_path, result_a.get("path", [])])
	return _pass()


static func _t_mirrored_board_covariance() -> Dictionary:
	var cells: Array = []
	for col in range(5):
		for row in range(5):
			cells.append(_cell(col, row))
	var walkable: Dictionary = _walkable(cells)
	var bounds := {"w": 5, "h": 5}
	var origin_a := _cell(0, 1)
	var destination_a := _cell(4, 3)
	var origin_b := _mirror_cell(origin_a, 4)
	var destination_b := _mirror_cell(destination_a, 4)
	var result_a: Dictionary = _MovementPathService.shortest_path(
		origin_a,
		destination_a,
		walkable,
		{},
		bounds
	)
	var result_b: Dictionary = _MovementPathService.shortest_path(
		origin_b,
		destination_b,
		walkable,
		{},
		bounds
	)
	if not bool(result_a.get("reachable", false)) or not bool(result_b.get("reachable", false)):
		return _fail("Both mirrored open-board routes must be reachable")
	if int(result_a.get("cost", -1)) != int(result_b.get("cost", -2)):
		return _fail("Mirrored routes must preserve cost")
	var mirrored_path_a: Array = []
	for cell_value: Variant in result_a.get("path", []):
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		mirrored_path_a.append(_mirror_cell(cell, 4))
	if mirrored_path_a != result_b.get("path", []):
		return _fail(
			"Relative tie policy failed mirrored covariance: %s mirrored to %s, got %s"
			% [result_a.get("path", []), mirrored_path_a, result_b.get("path", [])]
		)
	return _pass()


static func _t_invalid_terrain_cost_envelopes() -> Dictionary:
	var origin := _cell(0, 0)
	var destination := _cell(1, 0)
	var walkable: Dictionary = _walkable([origin, destination])
	var invalid_values: Array = [0, -2, "2"]
	for invalid_value: Variant in invalid_values:
		var terrain_costs := {"1,0": invalid_value}
		var shortest: Dictionary = _MovementPathService.shortest_path(
			origin,
			destination,
			walkable,
			terrain_costs,
			{"w": 2, "h": 1}
		)
		if bool(shortest.get("reachable", true)) \
				or shortest.get("path", [origin]) != [] \
				or int(shortest.get("cost", 0)) != -1 \
				or str(shortest.get("reason", "")) != "invalid_terrain_cost":
			return _fail("Shortest-path invalid-cost envelope drifted for %s: %s" % [invalid_value, shortest])

		var region: Dictionary = _MovementPathService.reachable_cost_region(
			origin,
			1,
			walkable,
			terrain_costs,
			{"w": 2, "h": 1}
		)
		if bool(region.get("reachable", true)) \
				or region.get("costs", {"unexpected": true}) != {} \
				or str(region.get("reason", "")) != "invalid_terrain_cost":
			return _fail("Reachable-region invalid-cost envelope drifted for %s: %s" % [invalid_value, region])
	return _pass()


static func _walkable(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		result["%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]] = true
	return result


static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func _mirror_cell(cell: Dictionary, max_row: int) -> Dictionary:
	return {"col": int(cell.get("col", 0)), "row": max_row - int(cell.get("row", 0))}


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
