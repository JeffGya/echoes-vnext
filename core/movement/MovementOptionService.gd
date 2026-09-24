class_name MovementOptionService
extends RefCounted

## Deterministic movement-option generation from planner-visible facts. `generate_options()`
## is the live per-turn option producer, called once per goal by
## LiveMovementContextService; `_build_control` is additionally called there directly for
## the edge-cost map the legacy `actor.move` bridge needs.

const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const OptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")

## Primary style by purpose (see `_primary_style()`): reposition/regroup -> lateral,
## protect/escort -> screen, intercept/cut_off -> intercept, withdraw -> retreating, else ->
## direct — all via `_build_primary` except lateral's own builder. `forceful`,
## `overcommitted` and `low_exposure` are unconditional extra candidates, not tied to purpose;
## so is `lateral` for every other purpose (`_build_lateral_extra`).
const STYLE_ORDER: Array = [
	"direct", "safe", "cohesive", "lateral", "screen", "intercept", "conservative", "retreating",
	"forceful", "overcommitted", "low_exposure",
]


static func generate_options(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary
) -> Dictionary:
	var context_result: Dictionary = ContextContract.validate(context)
	if not bool(context_result["valid"]):
		return _failure(
			"invalid_context.%s" % str(context_result["reason"]),
			str(context_result["field"])
		)
	var profile_result: Dictionary = ProfileContract.validate(profile)
	if not bool(profile_result["valid"]):
		return _failure(
			"invalid_profile.%s" % str(profile_result["reason"]),
			str(profile_result["field"])
		)
	var goal_result: Dictionary = GoalContract.validate(goal, context["origin"] as Dictionary)
	if not bool(goal_result["valid"]):
		return _failure(
			"invalid_goal.%s" % str(goal_result["reason"]),
			str(goal_result["field"])
		)
	if not str(goal["goal_id"]).begins_with("goal."):
		return _failure("invalid_goal_id", "goal_id")

	var origin: Dictionary = (context["origin"] as Dictionary).duplicate(true)
	var planning_walkable: Dictionary = _planning_walkable(context)
	var origin_key: String = _cell_key(origin)
	if not bool(planning_walkable.get(origin_key, false)):
		return _failure("origin_not_plannable", "context.origin")
	var occupancy: Dictionary = context["occupancy"] as Dictionary
	var occupancy_keys: Array = occupancy.keys()
	occupancy_keys.sort()
	for occupied_key_value: Variant in occupancy_keys:
		var occupied_key: String = str(occupied_key_value)
		if occupied_key != origin_key:
			planning_walkable.erase(occupied_key)
	for region_value: Variant in goal["destination_region"] as Array:
		var region_cell: Dictionary = region_value as Dictionary
		var region_key: String = _cell_key(region_cell)
		if not bool(planning_walkable.get(region_key, false)):
			return _failure("destination_not_plannable", "goal.destination_region")

	var control: Dictionary = _build_control(context, planning_walkable)
	var edge_costs: Dictionary = control["edge_costs"] as Dictionary
	var edge_sources: Dictionary = control["edge_sources"] as Dictionary
	var primary_style: String = _primary_style(str(goal["purpose"]))
	# One Dijkstra per region cell, shared by every builder that needs it. Unread when
	# the origin is already in the region: each builder returns its stay option first.
	var routes: Array = []
	if not (goal["destination_region"] as Array).has(origin):
		routes = _candidate_routes(context, goal, planning_walkable, edge_costs)
	var primary: Dictionary
	if primary_style == "lateral":
		primary = _build_lateral_primary(
			context, profile, goal, planning_walkable, edge_costs, edge_sources, routes
		)
	else:
		primary = _build_primary(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources,
			primary_style,
			routes
		)
	if bool(primary.get("failed", false)):
		return _failure(str(primary["reason"]), str(primary["field"]))

	# `hold` alone suppresses the alternatives: its stay option is the only truthful
	# candidate, and an endpoint route would walk the actor off the objective it holds.
	# The other stay-capable purposes keep their alternatives, so the arbiter weighs
	# staying against the other cells the action is still legal from.
	var holding_in_place: bool = str(goal["purpose"]) == "hold" \
		and (goal["destination_region"] as Array).has(origin)

	var candidates: Array = []
	if not primary.is_empty():
		candidates.append(primary)
	if not primary.is_empty() and not holding_in_place:
		var endpoints: Array = _build_endpoint_candidates(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources
		)
		var safe: Dictionary = _select_safe(endpoints, primary)
		if not safe.is_empty():
			safe = _with_style(safe, goal, "safe")
			candidates.append(safe)
		var cohesive: Dictionary = _select_cohesive(endpoints, primary)
		if not cohesive.is_empty():
			cohesive = _with_style(cohesive, goal, "cohesive")
			candidates.append(cohesive)
		var low_exposure: Dictionary = _select_low_exposure(
			endpoints, primary, _live_hostile_positions(context)
		)
		if not low_exposure.is_empty():
			low_exposure = _with_style(low_exposure, goal, "low_exposure")
			candidates.append(low_exposure)
		var conservative: Dictionary = _build_conservative(
			context,
			profile,
			goal,
			planning_walkable,
			edge_costs,
			edge_sources,
			primary
		)
		if not conservative.is_empty():
			candidates.append(conservative)
		var forceful: Dictionary = _build_forceful(
			context, profile, goal, planning_walkable, edge_costs, edge_sources
		)
		if not forceful.is_empty():
			candidates.append(forceful)
		var overcommitted: Dictionary = _build_overcommitted(
			context, profile, goal, planning_walkable, edge_costs, edge_sources, routes
		)
		if not overcommitted.is_empty():
			candidates.append(overcommitted)
		if primary_style != "lateral":
			var taken_destinations: Array = []
			for taken_value: Variant in candidates:
				taken_destinations.append((taken_value as Dictionary)["destination"] as Dictionary)
			var lateral: Dictionary = _build_lateral_extra(
				context, profile, goal, planning_walkable, edge_costs, edge_sources,
				taken_destinations, routes
			)
			if not lateral.is_empty():
				candidates.append(lateral)

	var validated: Array = []
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var validation: Dictionary = OptionContract.validate(candidate, origin)
		if not bool(validation["valid"]):
			return _failure(
				"invalid_generated_option.%s" % str(validation["reason"]),
				str(validation["field"])
			)
		validated.append(candidate)

	validated.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary = left_value as Dictionary
		var right: Dictionary = right_value as Dictionary
		var left_style: String = _style_from_option_id(str(left["option_id"]))
		var right_style: String = _style_from_option_id(str(right["option_id"]))
		var left_rank: int = STYLE_ORDER.find(left_style)
		var right_rank: int = STYLE_ORDER.find(right_style)
		if left_rank != right_rank:
			return left_rank < right_rank
		return str(left["option_id"]) < str(right["option_id"])
	)

	var deduplication: Dictionary = _deduplicate_candidates(validated)
	if not bool(deduplication["valid"]):
		return _failure(str(deduplication["reason"]), str(deduplication["field"]))
	return {"valid": true, "options": deduplication["options"], "reason": "", "field": ""}


static func _deduplicate_candidates(candidates: Array) -> Dictionary:
	var deduplicated: Array = []
	var mechanics: Dictionary = {}
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var mechanics_key: String = _mechanics_key(candidate)
		if mechanics.has(mechanics_key):
			var prior: Dictionary = mechanics[mechanics_key] as Dictionary
			if not _same_mechanical_facts(prior, candidate):
				return {
					"valid": false,
					"options": [],
					"reason": "conflicting_duplicate_mechanics",
					"field": "options",
				}
			continue
		mechanics[mechanics_key] = candidate
		deduplicated.append(candidate)
		if deduplicated.size() == STYLE_ORDER.size():
			break
	return {"valid": true, "options": deduplicated, "reason": "", "field": ""}


## Cost-optimal route to each destination in the goal region, cheapest first.
## Shared by `_build_primary`, both lateral builders (baseline before offset)
## and `_build_overcommitted` (which re-sorts the same routes the other way).
static func _candidate_routes(
	context: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary
) -> Array:
	var origin: Dictionary = context["origin"] as Dictionary
	var routes: Array = []
	for destination_value: Variant in goal["destination_region"] as Array:
		var destination: Dictionary = destination_value as Dictionary
		var result: Dictionary = MovementPathService.shortest_path(
			origin,
			destination,
			planning_walkable,
			context["terrain_costs"] as Dictionary,
			context["bounds"] as Dictionary,
			edge_costs
		)
		if bool(result["reachable"]):
			routes.append({
				"destination": destination.duplicate(true),
				"path": (result["path"] as Array).duplicate(true),
				"cost": int(result["cost"]),
			})
	routes.sort_custom(Callable(MovementOptionService, "_primary_route_less"))
	return routes


## `precomputed_routes` is `_candidate_routes`' result from `generate_options`, or
## null for a direct caller, which then pays for the search itself.
static func _routes_or_compute(
	precomputed_routes: Variant,
	context: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary
) -> Array:
	if precomputed_routes is Array:
		return precomputed_routes as Array
	return _candidate_routes(context, goal, planning_walkable, edge_costs)


static func _build_primary(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	style: String,
	precomputed_routes: Variant = null
) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	# A mover already standing in its own destination region is in position: the
	# truthful primary is the zero-step stay, not a route to a different cell in the
	# same region. Which purposes may admit the origin at all is MovementGoal's
	# STAY_CAPABLE_PURPOSES, enforced by the goal contract before this runs.
	if (goal["destination_region"] as Array).has(origin):
		return _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			style, [], 0
		)

	var routes: Array = _routes_or_compute(precomputed_routes, context, goal, planning_walkable, edge_costs)
	if routes.is_empty():
		return {}
	var selected: Dictionary = routes[0] as Dictionary
	var path: Array = (selected["path"] as Array).duplicate(true)
	var capacity: int = int(profile["capacity"])
	if int(selected["cost"]) > capacity:
		path = _longest_affordable_prefix(
			origin,
			path,
			capacity,
			planning_walkable,
			context["terrain_costs"] as Dictionary,
			context["bounds"] as Dictionary,
			edge_costs
		)
	if path.is_empty():
		return {}
	var option: Dictionary = _build_option(
		context, profile, goal, planning_walkable, edge_costs, edge_sources,
		style, path
	)
	if float(option.get("objective_progress", 0.0)) <= 0.0:
		return {}
	return option


## `lateral` primary for reposition/regroup: offsets the cost-optimal (baseline)
## destination one Chebyshev step perpendicular to the line from the nearest
## perceived threat (or, absent one, ally) to that destination, then paths to
## the offset cell. This is what makes `lateral` a genuine flanking route
## rather than `_build_primary`'s straight line under a different label. With
## no reference actor perceived, or neither offset side reachable within
## capacity, it falls back to the unoffset baseline route unchanged.
static func _build_lateral_primary(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	precomputed_routes: Variant = null
) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	if (goal["destination_region"] as Array).has(origin):
		return _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"lateral", [], 0
		)
	var routes: Array = _routes_or_compute(precomputed_routes, context, goal, planning_walkable, edge_costs)
	if routes.is_empty():
		return {}
	var baseline: Dictionary = routes[0] as Dictionary
	var capacity: int = int(profile["capacity"])
	var path: Array = _flank_path(
		context, profile, planning_walkable, edge_costs, baseline["destination"] as Dictionary,
		_flank_reference(context)
	)
	var option: Dictionary = {}
	if not path.is_empty():
		option = _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"lateral", path
		)
		if float(option.get("objective_progress", 0.0)) <= 0.0:
			option = {}
	# Falls back to the unoffset baseline route whenever the flank attempt produced
	# nothing usable — either no reachable offset cell, or (the case that used to be
	# missed) a flank destination exactly 1 Chebyshev step off the baseline, which
	# always scores objective_progress 0.0 when the origin itself is 1 step from the
	# destination region (see `_objective_progress`: d_flank is always 1 by construction).
	if option.is_empty():
		path = (baseline["path"] as Array).duplicate(true)
		if int(baseline["cost"]) > capacity:
			path = _longest_affordable_prefix(
				origin, path, capacity, planning_walkable,
				context["terrain_costs"] as Dictionary, context["bounds"] as Dictionary, edge_costs
			)
		if path.is_empty():
			return {}
		option = _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"lateral", path
		)
		if float(option.get("objective_progress", 0.0)) <= 0.0:
			return {}
	return option


## `lateral` as an extra candidate for purposes whose primary is not lateral — the
## §9 "lateral cut-off" / flanking-approach reading. Same flank geometry as
## `_build_lateral_primary`, with two differences: it flanks a perceived HOSTILE only
## (flanking around an ally is a regroup/reposition idea, not an approach), and it has
## no baseline fallback, because the unoffset baseline is the purpose's own primary route.
## A flank that capacity cuts short can end on a cell already claimed by another candidate
## for this goal — the primary (whichever style it is) or any of safe/cohesive/low_exposure/
## conservative/forceful/overcommitted, per the caller's full `taken_destinations` list. It is
## dropped: `lateral` sorts early in STYLE_ORDER, so dedup would keep it and rename the other
## candidate. A different middle cell is not a flank.
static func _build_lateral_extra(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	taken_destinations: Array,
	precomputed_routes: Variant = null
) -> Dictionary:
	if (goal["destination_region"] as Array).has(context["origin"] as Dictionary):
		return {}
	var hostile: Dictionary = _nearest_related_position(context, "hostile")
	if hostile.is_empty():
		return {}
	var routes: Array = _routes_or_compute(precomputed_routes, context, goal, planning_walkable, edge_costs)
	if routes.is_empty():
		return {}
	var path: Array = _flank_path(
		context, profile, planning_walkable, edge_costs,
		(routes[0] as Dictionary)["destination"] as Dictionary, hostile
	)
	if path.is_empty():
		return {}
	var flank_key: String = _cell_key(path.back() as Dictionary)
	for taken_value: Variant in taken_destinations:
		if _cell_key(taken_value as Dictionary) == flank_key:
			return {}
	var option: Dictionary = _build_option(
		context, profile, goal, planning_walkable, edge_costs, edge_sources, "lateral", path
	)
	if float(option.get("objective_progress", 0.0)) <= 0.0:
		return {}
	return option


## Offset target for the lateral builders: the baseline destination shifted
## one Chebyshev step perpendicular to the reference-to-destination line, tried
## on both sides. Returns the affordable, walkable, reachable candidate path
## with the canonically smaller destination cell; `[]` when neither side works.
static func _flank_path(
	context: Dictionary,
	profile: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	baseline_destination: Dictionary,
	reference: Dictionary
) -> Array:
	if reference.is_empty():
		return []
	var delta_col: int = signi(int(baseline_destination["col"]) - int(reference["col"]))
	var delta_row: int = signi(int(baseline_destination["row"]) - int(reference["row"]))
	if delta_col == 0 and delta_row == 0:
		delta_col = 1
	var offsets: Array = [
		{"col": -delta_row, "row": delta_col},
		{"col": delta_row, "row": -delta_col},
	]
	var origin: Dictionary = context["origin"] as Dictionary
	var capacity: int = int(profile["capacity"])
	var best_path: Array = []
	var best_destination: Dictionary = {}
	for offset_value: Variant in offsets:
		var offset: Dictionary = offset_value as Dictionary
		var candidate: Dictionary = {
			"col": int(baseline_destination["col"]) + int(offset["col"]),
			"row": int(baseline_destination["row"]) + int(offset["row"]),
		}
		if candidate == origin or not bool(planning_walkable.get(_cell_key(candidate), false)):
			continue
		# Picks the canonically smaller side purely by cell order, not by objective_progress —
		# assumes the two offsets are symmetric enough to tie on progress. Unconfirmed on an
		# asymmetric board where the smaller side scores 0 (silently dropped by the caller)
		# while the other side would have scored positive.
		var result: Dictionary = MovementPathService.shortest_path(
			origin, candidate, planning_walkable,
			context["terrain_costs"] as Dictionary, context["bounds"] as Dictionary, edge_costs
		)
		if not bool(result["reachable"]):
			continue
		var path: Array = (result["path"] as Array).duplicate(true)
		if int(result["cost"]) > capacity:
			path = _longest_affordable_prefix(
				origin, path, capacity, planning_walkable,
				context["terrain_costs"] as Dictionary, context["bounds"] as Dictionary, edge_costs
			)
		if path.is_empty():
			continue
		if best_path.is_empty() or _cell_less(candidate, best_destination):
			best_path = path
			best_destination = candidate
	return best_path


## Nearest perceived hostile to the origin; the nearest perceived friendly ally
## when none is perceived. Empty when neither exists — the caller then has no
## line to flank around.
static func _flank_reference(context: Dictionary) -> Dictionary:
	var hostile: Dictionary = _nearest_related_position(context, "hostile")
	if not hostile.is_empty():
		return hostile
	return _nearest_related_position(context, "friendly")


static func _nearest_related_position(context: Dictionary, relation: String) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	var mover_id: String = str(context["mover_id"])
	var relationships: Dictionary = context["relationships"] as Dictionary
	var actors: Array = (context["perceived_actors"] as Array).duplicate(true)
	actors.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary)["id"]) < str((right as Dictionary)["id"])
	)
	var best: Dictionary = {}
	var best_distance: int = 2147483647
	for actor_value: Variant in actors:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor["id"])
		if actor_id == mover_id or str(relationships.get(actor_id, "")) != relation:
			continue
		if bool(actor["is_dead"]) or bool(actor["is_ko"]) or bool(actor["is_structure"]):
			continue
		var position: Dictionary = actor["position"] as Dictionary
		var distance: int = _chebyshev(origin, position)
		if distance < best_distance:
			best_distance = distance
			best = position
	return best


## `forceful`: minimises STEP COUNT rather than total cost, so it is willing to
## pay hostile-control surcharges `_build_primary` routes around. Finds the
## route with the fewest cells over an unweighted search (terrain/edge costs
## zeroed), then prices that exact route at its real, capacity-truncated cost —
## the same truncation rule `_build_primary` uses.
static func _build_forceful(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary
) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	if (goal["destination_region"] as Array).has(origin):
		return _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"forceful", [], 0
		)
	var bounds: Dictionary = context["bounds"] as Dictionary
	var routes: Array = []
	for destination_value: Variant in goal["destination_region"] as Array:
		var destination: Dictionary = destination_value as Dictionary
		var result: Dictionary = MovementPathService.shortest_path(
			origin, destination, planning_walkable, {}, bounds, {}
		)
		if bool(result["reachable"]):
			routes.append({
				"destination": destination.duplicate(true),
				"path": (result["path"] as Array).duplicate(true),
			})
	if routes.is_empty():
		return {}
	routes.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary = left_value as Dictionary
		var right: Dictionary = right_value as Dictionary
		var left_path: Array = left["path"] as Array
		var right_path: Array = right["path"] as Array
		if left_path.size() != right_path.size():
			return left_path.size() < right_path.size()
		if left["destination"] != right["destination"]:
			return _cell_less(left["destination"] as Dictionary, right["destination"] as Dictionary)
		return _path_less(left_path, right_path)
	)
	var selected: Dictionary = routes[0] as Dictionary
	var path: Array = (selected["path"] as Array).duplicate(true)
	var terrain_costs: Dictionary = context["terrain_costs"] as Dictionary
	var route_validation: Dictionary = MovementPathService.validate_route(
		origin, path, planning_walkable, terrain_costs, bounds, edge_costs
	)
	if not bool(route_validation["valid"]):
		return {}
	var capacity: int = int(profile["capacity"])
	if int(route_validation["cost"]) > capacity:
		path = _longest_affordable_prefix(
			origin, path, capacity, planning_walkable, terrain_costs, bounds, edge_costs
		)
	if path.is_empty():
		return {}
	var option: Dictionary = _build_option(
		context, profile, goal, planning_walkable, edge_costs, edge_sources,
		"forceful", path
	)
	if float(option.get("objective_progress", 0.0)) <= 0.0:
		return {}
	return option


## `overcommitted`: among destinations in the goal region reachable within
## capacity, spends as close to full capacity as it can rather than taking the
## cheapest — the inverse tie-break of `_build_primary`. Falls back to
## `_build_primary`'s cheapest-route-and-truncate behaviour when nothing in the
## region is affordable outright, so this always produces the same guaranteed
## option `_build_primary` does.
static func _build_overcommitted(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	precomputed_routes: Variant = null
) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	if (goal["destination_region"] as Array).has(origin):
		return _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"overcommitted", [], 0
		)
	var routes: Array = _routes_or_compute(precomputed_routes, context, goal, planning_walkable, edge_costs)
	if routes.is_empty():
		return {}
	var capacity: int = int(profile["capacity"])
	var affordable: Array = routes.filter(
		func(route_value: Variant) -> bool: return int((route_value as Dictionary)["cost"]) <= capacity
	)
	var path: Array
	if not affordable.is_empty():
		affordable.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
			var left: Dictionary = left_value as Dictionary
			var right: Dictionary = right_value as Dictionary
			if int(left["cost"]) != int(right["cost"]):
				return int(left["cost"]) > int(right["cost"])
			var left_destination: Dictionary = left["destination"] as Dictionary
			var right_destination: Dictionary = right["destination"] as Dictionary
			if left_destination != right_destination:
				return _cell_less(left_destination, right_destination)
			return _path_less(left["path"] as Array, right["path"] as Array)
		)
		path = ((affordable[0] as Dictionary)["path"] as Array).duplicate(true)
	else:
		var selected: Dictionary = routes[0] as Dictionary
		path = (selected["path"] as Array).duplicate(true)
		if int(selected["cost"]) > capacity:
			path = _longest_affordable_prefix(
				origin, path, capacity, planning_walkable,
				context["terrain_costs"] as Dictionary, context["bounds"] as Dictionary, edge_costs
			)
	if path.is_empty():
		return {}
	var option: Dictionary = _build_option(
		context, profile, goal, planning_walkable, edge_costs, edge_sources,
		"overcommitted", path
	)
	if float(option.get("objective_progress", 0.0)) <= 0.0:
		return {}
	return option


static func _build_endpoint_candidates(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary
) -> Array:
	var candidates: Array = []
	var keys: Array = planning_walkable.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _cell_less(_cell_from_key(str(left)), _cell_from_key(str(right)))
	)
	# One capacity-bounded flood fill replaces one full Dijkstra per unreachable or
	# unaffordable cell. Dijkstra's minimum cost to a cell is unique, so `costs` holds
	# exactly the keys the per-cell `shortest_path` below would have accepted — the
	# surviving set, its order and its options are unchanged. An empty/failed region is
	# NOT treated as "nothing reachable": the filter is simply skipped.
	var region: Dictionary = MovementPathService.reachable_cost_region(
		context["origin"] as Dictionary,
		int(profile["capacity"]),
		planning_walkable,
		context["terrain_costs"] as Dictionary,
		context["bounds"] as Dictionary,
		edge_costs
	)
	var affordable: Dictionary = region["costs"] as Dictionary if bool(region["reachable"]) else {}
	var region_usable: bool = not affordable.is_empty()
	var origin_cell: Dictionary = context["origin"] as Dictionary
	var destination_region: Array = goal["destination_region"] as Array
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if not bool(planning_walkable[key]):
			continue
		if region_usable and not affordable.has(key):
			continue
		var destination: Dictionary = _cell_from_key(key)
		if destination == origin_cell:
			continue
		# Progress is a fact about origin and destination only, so this is the same test
		# applied to the built option below — moved ahead of the route search, where it
		# costs nothing, rather than after it.
		if _objective_progress(origin_cell, destination, destination_region) <= 0.0:
			continue
		var result: Dictionary = MovementPathService.shortest_path(
			origin_cell,
			destination,
			planning_walkable,
			context["terrain_costs"] as Dictionary,
			context["bounds"] as Dictionary,
			edge_costs
		)
		if not bool(result["reachable"]) or int(result["cost"]) > int(profile["capacity"]):
			continue
		var option: Dictionary = _build_option(
			context, profile, goal, planning_walkable, edge_costs, edge_sources,
			"direct", result["path"] as Array, int(result["cost"]), int(result["cost"])
		)
		if float(option["objective_progress"]) > 0.0:
			candidates.append(option)
	return candidates


static func _build_conservative(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	primary: Dictionary
) -> Dictionary:
	if (primary["path"] as Array).is_empty():
		return {}
	var limit: int = maxi(1, floori(float(profile["capacity"]) / 2.0))
	var prefix: Array = _longest_affordable_prefix(
		context["origin"] as Dictionary,
		primary["path"] as Array,
		limit,
		planning_walkable,
		context["terrain_costs"] as Dictionary,
		context["bounds"] as Dictionary,
		edge_costs
	)
	if prefix.is_empty() or prefix == primary["path"]:
		return {}
	var option: Dictionary = _build_option(
		context, profile, goal, planning_walkable, edge_costs, edge_sources,
		"conservative", prefix
	)
	if float(option["objective_progress"]) <= 0.0:
		return {}
	return option


static func _build_option(
	context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	planning_walkable: Dictionary,
	edge_costs: Dictionary,
	edge_sources: Dictionary,
	style: String,
	path: Array,
	known_route_cost: int = -1,
	# Only for callers whose `path` came straight out of `shortest_path`: passing the
	# cost back saves re-running that identical search. Any other caller must leave it
	# at -1, or `slack` silently reports zero for a detour.
	known_shortest_cost: int = -1
) -> Dictionary:
	var origin: Dictionary = context["origin"] as Dictionary
	var destination: Dictionary = origin if path.is_empty() else path.back() as Dictionary
	var route_cost: int = known_route_cost
	if route_cost < 0:
		var route_result: Dictionary = MovementPathService.validate_route(
			origin,
			path,
			planning_walkable,
			context["terrain_costs"] as Dictionary,
			context["bounds"] as Dictionary,
			edge_costs
		)
		if not bool(route_result["valid"]):
			return {"failed": true, "reason": str(route_result["reason"]), "field": "path"}
		route_cost = int(route_result["cost"])
	var shortest_cost: int = 0
	if not path.is_empty() and known_shortest_cost >= 0:
		shortest_cost = known_shortest_cost
	elif not path.is_empty():
		var shortest: Dictionary = MovementPathService.shortest_path(
			origin,
			destination,
			planning_walkable,
			context["terrain_costs"] as Dictionary,
			context["bounds"] as Dictionary,
			edge_costs
		)
		if not bool(shortest["reachable"]):
			return {"failed": true, "reason": "unreachable_destination", "field": "path"}
		shortest_cost = int(shortest["cost"])
	var destination_region: Array = goal["destination_region"] as Array
	var progress: float = _objective_progress(origin, destination, destination_region)
	# Raw distance behind `progress`'s ratio — see BehaviorArbiter._spatial_utility(),
	# which normalizes commitment against this same value instead of capacity.
	var progress_origin_distance: int = _distance_to_region(origin, destination_region)
	var hazard_ids: Array = _hazard_ids(path, context["known_hazards"] as Array)
	var hostile_sources: Array = _hostile_sources(path, origin, edge_sources)
	var option_id: String = _option_id(goal, style, destination, path)
	var planned_action: Dictionary = _planned_action_for_destination(goal, destination)
	return OptionContract.build(
		str(goal["goal_id"]),
		option_id,
		str(goal["purpose"]),
		destination,
		path,
		route_cost,
		shortest_cost,
		route_cost - shortest_cost,
		int(profile["capacity"]),
		route_cost,
		_exposure(path, origin, edge_costs),
		_congestion(destination, context["occupancy"] as Dictionary, str(context["mover_id"])),
		_cohesion(destination, context),
		hostile_sources,
		{"known_count": hazard_ids.size(), "known_ids": hazard_ids},
		progress,
		progress_origin_distance,
		planned_action,
		goal["declared_fallback"] as Dictionary
	)


# Every option carries `goal.planned_primary` VERBATIM, including a route that stops
# short of the goal region. This layer used to rewrite a range-bound primary
# (melee_attack / protect_ally / actor.guard / actor.purify_shrine) into a bare
# `actor.move` on such routes, which read as "do not advertise an out-of-range strike".
# It cost more than it bought:
#   - BehaviorArbiter._validate_movement_inputs requires planned_action == planned_primary
#     and answers a mismatch by discarding the WHOLE board, dropping every actor back to
#     legacy nearest-enemy selection;
#   - the rewrite dropped `target_id`, so a truncated approach no longer named who it was
#     closing on;
#   - it bought no safety: CombatActivationService revalidates the primary at the FINAL
#     cell and takes the declared fallback when it is out of range.
static func _planned_action_for_destination(goal: Dictionary, _destination: Dictionary) -> Dictionary:
	return goal["planned_primary"] as Dictionary


## Public seam for live callers (e.g. FlowRuntime): the hostile-control edge-cost map
## that MovementPathService._edge_surcharge consumes, built from the SAME control model
## MovementExecutor charges ("from>to" -> 1 for any edge whose either endpoint is
## 8-adjacent to a live hostile). Threading this into the planner keeps route_cost /
## commitment equal to the executor's real per-edge cost — a single source of truth.
static func hostile_edge_costs(context: Dictionary, planning_walkable: Dictionary) -> Dictionary:
	return _build_control(context, planning_walkable)["edge_costs"] as Dictionary


static func _build_control(context: Dictionary, planning_walkable: Dictionary) -> Dictionary:
	var controllers: Array = []
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor["id"])
		if str((context["relationships"] as Dictionary).get(actor_id, "")) != "hostile":
			continue
		if bool(actor["is_dead"]) or bool(actor["is_ko"]) or bool(actor["is_structure"]):
			continue
		if not bool(actor["controlling_state"]):
			continue
		controllers.append(actor)
	controllers.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str((left_value as Dictionary)["id"]) < str((right_value as Dictionary)["id"])
	)

	var controlled_sources: Dictionary = {}
	var planning_keys: Array = planning_walkable.keys()
	planning_keys.sort()
	for key_value: Variant in planning_keys:
		var key: String = str(key_value)
		if not bool(planning_walkable[key]):
			continue
		var cell: Dictionary = _cell_from_key(key)
		var sources: Array = []
		for controller_value: Variant in controllers:
			var controller: Dictionary = controller_value as Dictionary
			if _chebyshev(cell, controller["position"] as Dictionary) == 1:
				sources.append(str(controller["id"]))
		if not sources.is_empty():
			controlled_sources[key] = sources

	var edge_costs: Dictionary = {}
	var edge_sources: Dictionary = {}
	for from_key_value: Variant in planning_keys:
		var from_key: String = str(from_key_value)
		if not bool(planning_walkable[from_key]):
			continue
		var from_cell: Dictionary = _cell_from_key(from_key)
		for to_value: Variant in StageTerrain.legal_neighbors(
			from_cell,
			planning_walkable,
			context["bounds"] as Dictionary
		):
			var to_cell: Dictionary = to_value as Dictionary
			var to_key: String = _cell_key(to_cell)
			var sources: Array = []
			for source_value: Variant in controlled_sources.get(from_key, []) as Array:
				if not sources.has(source_value):
					sources.append(source_value)
			for source_value: Variant in controlled_sources.get(to_key, []) as Array:
				if not sources.has(source_value):
					sources.append(source_value)
			if sources.is_empty():
				continue
			sources.sort()
			var edge_key: String = "%s>%s" % [from_key, to_key]
			edge_costs[edge_key] = 1
			edge_sources[edge_key] = sources
	return {"edge_costs": edge_costs, "edge_sources": edge_sources}


static func _planning_walkable(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var authoritative: Dictionary = context["authoritative_walkable"] as Dictionary
	var perceived: Dictionary = context["perceived_planning_cells"] as Dictionary
	var keys: Array = authoritative.keys()
	keys.sort()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if bool(authoritative[key]) and bool(perceived.get(key, false)):
			result[key] = true
	return result


static func _longest_affordable_prefix(
	origin: Dictionary,
	path: Array,
	limit: int,
	walkable: Dictionary,
	terrain_costs: Dictionary,
	bounds: Dictionary,
	edge_costs: Dictionary
) -> Array:
	var prefix: Array = []
	for cell_value: Variant in path:
		var candidate: Array = prefix.duplicate(true)
		candidate.append((cell_value as Dictionary).duplicate(true))
		var result: Dictionary = MovementPathService.validate_route(
			origin, candidate, walkable, terrain_costs, bounds, edge_costs
		)
		if not bool(result["valid"]) or int(result["cost"]) > limit:
			break
		prefix = candidate
	return prefix


static func _select_safe(candidates: Array, primary: Dictionary) -> Dictionary:
	var eligible: Array = []
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var candidate_hazards: int = int((candidate["hazard_summary"] as Dictionary)["known_count"])
		var primary_hazards: int = int((primary["hazard_summary"] as Dictionary)["known_count"])
		var improves: bool = candidate_hazards < primary_hazards \
			or (candidate_hazards == primary_hazards \
				and float(candidate["exposure"]) < float(primary["exposure"]))
		if improves:
			eligible.append(candidate)
	eligible.sort_custom(Callable(MovementOptionService, "_safe_less"))
	return {} if eligible.is_empty() else (eligible[0] as Dictionary).duplicate(true)


## Sibling of `_select_safe` with exposure (hostile-control edges) as the first key.
## Full priority, for both eligibility and the sort: exposure, then known hazard
## count, then distance from the destination to the nearest live hostile, then
## objective progress, then `_common_option_less`. Hazards outrank threat distance
## (decision #52): at equal exposure a farther cell never beats a less hazardous one.
## Threat distance is what separates this from `safe` on a hazard-free board.
## Strictly lower exposure alone still qualifies, as before, whatever the hazards.
static func _select_low_exposure(
	candidates: Array, primary: Dictionary, hostile_positions: Array
) -> Dictionary:
	var eligible: Array = []
	var primary_exposure: float = float(primary["exposure"])
	var primary_hazards: int = int((primary["hazard_summary"] as Dictionary)["known_count"])
	var primary_threat: int = _threat_distance(primary["destination"] as Dictionary, hostile_positions)
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var candidate_exposure: float = float(candidate["exposure"])
		var candidate_hazards: int = int((candidate["hazard_summary"] as Dictionary)["known_count"])
		var candidate_threat: int = _threat_distance(candidate["destination"] as Dictionary, hostile_positions)
		var improves: bool = candidate_exposure < primary_exposure \
			or (candidate_exposure == primary_exposure and candidate_hazards < primary_hazards) \
			or (candidate_exposure == primary_exposure and candidate_hazards == primary_hazards \
				and candidate_threat > primary_threat)
		if improves:
			eligible.append(candidate)
	eligible.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary = left_value as Dictionary
		var right: Dictionary = right_value as Dictionary
		if float(left["exposure"]) != float(right["exposure"]):
			return float(left["exposure"]) < float(right["exposure"])
		var left_hazards: int = int((left["hazard_summary"] as Dictionary)["known_count"])
		var right_hazards: int = int((right["hazard_summary"] as Dictionary)["known_count"])
		if left_hazards != right_hazards:
			return left_hazards < right_hazards
		var left_threat: int = _threat_distance(left["destination"] as Dictionary, hostile_positions)
		var right_threat: int = _threat_distance(right["destination"] as Dictionary, hostile_positions)
		if left_threat != right_threat:
			return left_threat > right_threat
		# Most progress, not `_common_option_less`'s cheapest (least-progress) cell.
		if float(left["objective_progress"]) != float(right["objective_progress"]):
			return float(left["objective_progress"]) > float(right["objective_progress"])
		return _common_option_less(left, right)
	)
	return {} if eligible.is_empty() else (eligible[0] as Dictionary).duplicate(true)


## Positions of every perceived living, non-KO, non-structure hostile — the same
## filter `_nearest_related_position` applies.
static func _live_hostile_positions(context: Dictionary) -> Array:
	var positions: Array = []
	var relationships: Dictionary = context["relationships"] as Dictionary
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor["id"])
		if actor_id == str(context["mover_id"]) or str(relationships.get(actor_id, "")) != "hostile":
			continue
		if bool(actor["is_dead"]) or bool(actor["is_ko"]) or bool(actor["is_structure"]):
			continue
		positions.append((actor["position"] as Dictionary).duplicate(true))
	return positions


## Chebyshev distance from `cell` to the nearest position; 0 with none, so an
## empty board ties every candidate on this key.
static func _threat_distance(cell: Dictionary, hostile_positions: Array) -> int:
	if hostile_positions.is_empty():
		return 0
	var best: int = 2147483647
	for position_value: Variant in hostile_positions:
		best = mini(best, _chebyshev(cell, position_value as Dictionary))
	return best


static func _select_cohesive(candidates: Array, primary: Dictionary) -> Dictionary:
	var eligible: Array = []
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		if float(candidate["cohesion"]) > float(primary["cohesion"]):
			eligible.append(candidate)
	eligible.sort_custom(Callable(MovementOptionService, "_cohesive_less"))
	return {} if eligible.is_empty() else (eligible[0] as Dictionary).duplicate(true)


static func _with_style(option: Dictionary, goal: Dictionary, style: String) -> Dictionary:
	var styled: Dictionary = option.duplicate(true)
	styled["option_id"] = _option_id(
		goal,
		style,
		styled["destination"] as Dictionary,
		styled["path"] as Array
	)
	return styled


static func _primary_route_less(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value as Dictionary
	var right: Dictionary = right_value as Dictionary
	if int(left["cost"]) != int(right["cost"]):
		return int(left["cost"]) < int(right["cost"])
	var left_destination: Dictionary = left["destination"] as Dictionary
	var right_destination: Dictionary = right["destination"] as Dictionary
	if left_destination != right_destination:
		return _cell_less(left_destination, right_destination)
	return _path_less(left["path"] as Array, right["path"] as Array)


static func _safe_less(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value as Dictionary
	var right: Dictionary = right_value as Dictionary
	var left_hazards: int = int((left["hazard_summary"] as Dictionary)["known_count"])
	var right_hazards: int = int((right["hazard_summary"] as Dictionary)["known_count"])
	if left_hazards != right_hazards:
		return left_hazards < right_hazards
	if float(left["exposure"]) != float(right["exposure"]):
		return float(left["exposure"]) < float(right["exposure"])
	return _common_option_less(left, right)


static func _cohesive_less(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value as Dictionary
	var right: Dictionary = right_value as Dictionary
	if float(left["cohesion"]) != float(right["cohesion"]):
		return float(left["cohesion"]) > float(right["cohesion"])
	return _common_option_less(left, right)


static func _common_option_less(left: Dictionary, right: Dictionary) -> bool:
	if int(left["route_cost"]) != int(right["route_cost"]):
		return int(left["route_cost"]) < int(right["route_cost"])
	if left["destination"] != right["destination"]:
		return _cell_less(left["destination"] as Dictionary, right["destination"] as Dictionary)
	if left["path"] != right["path"]:
		return _path_less(left["path"] as Array, right["path"] as Array)
	return str(left["option_id"]) < str(right["option_id"])


## Progress is a fact about where the option ENDS. Keying it on the origin would score
## every candidate 1.0 the moment the mover stands in the region — including the ones
## that walk out of it.
static func _objective_progress(origin: Dictionary, destination: Dictionary, region: Array) -> float:
	if region.has(destination):
		return 1.0
	var origin_distance: int = _distance_to_region(origin, region)
	var destination_distance: int = _distance_to_region(destination, region)
	return clampf(
		float(origin_distance - destination_distance) / float(maxi(1, origin_distance)),
		0.0,
		1.0
	)


static func _distance_to_region(cell: Dictionary, region: Array) -> int:
	var best: int = 2147483647
	for region_value: Variant in region:
		best = mini(best, _chebyshev(cell, region_value as Dictionary))
	return best


static func _exposure(path: Array, origin: Dictionary, edge_costs: Dictionary) -> float:
	var controlled_edges: int = 0
	var current: Dictionary = origin
	for cell_value: Variant in path:
		var next_cell: Dictionary = cell_value as Dictionary
		if edge_costs.has("%s>%s" % [_cell_key(current), _cell_key(next_cell)]):
			controlled_edges += 1
		current = next_cell
	return float(controlled_edges) / float(maxi(1, path.size()))


static func _hostile_sources(path: Array, origin: Dictionary, edge_sources: Dictionary) -> Array:
	var sources: Array = []
	var current: Dictionary = origin
	for cell_value: Variant in path:
		var next_cell: Dictionary = cell_value as Dictionary
		var edge_key: String = "%s>%s" % [_cell_key(current), _cell_key(next_cell)]
		for source_value: Variant in edge_sources.get(edge_key, []) as Array:
			if not sources.has(source_value):
				sources.append(source_value)
		current = next_cell
	sources.sort()
	return sources


static func _congestion(destination: Dictionary, occupancy: Dictionary, mover_id: String) -> float:
	var occupied_neighbors: int = 0
	for delta_col in range(-1, 2):
		for delta_row in range(-1, 2):
			if delta_col == 0 and delta_row == 0:
				continue
			var key: String = "%d,%d" % [
				int(destination["col"]) + delta_col,
				int(destination["row"]) + delta_row,
			]
			if occupancy.has(key) and str(occupancy[key]) != mover_id:
				occupied_neighbors += 1
	return float(occupied_neighbors) / 8.0


static func _cohesion(destination: Dictionary, context: Dictionary) -> float:
	var friends: Array = []
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor["id"])
		if actor_id == str(context["mover_id"]):
			continue
		if str((context["relationships"] as Dictionary).get(actor_id, "")) != "friendly":
			continue
		if bool(actor["is_dead"]) or bool(actor["is_structure"]):
			continue
		friends.append(actor)
	if friends.is_empty():
		return 0.0
	var close_friends: int = 0
	for friend_value: Variant in friends:
		var friend: Dictionary = friend_value as Dictionary
		if _chebyshev(destination, friend["position"] as Dictionary) <= 2:
			close_friends += 1
	return float(close_friends) / float(friends.size())


static func _hazard_ids(path: Array, hazards: Array) -> Array:
	var ids: Array = []
	for hazard_value: Variant in hazards:
		var hazard: Dictionary = hazard_value as Dictionary
		if path.has(hazard["position"] as Dictionary):
			ids.append(str(hazard["id"]))
	ids.sort()
	return ids


static func _primary_style(purpose: String) -> String:
	if purpose in ["reposition", "regroup"]:
		return "lateral"
	if purpose in ["protect", "escort"]:
		return "screen"
	if purpose in ["intercept", "cut_off"]:
		return "intercept"
	if purpose == "withdraw":
		return "retreating"
	return "direct"


static func _option_id(
	goal: Dictionary,
	style: String,
	destination: Dictionary,
	path: Array
) -> String:
	var path_token: String = "pstay"
	if not path.is_empty():
		var cells: Array = []
		for cell_value: Variant in path:
			var cell: Dictionary = cell_value as Dictionary
			cells.append("c%dr%d" % [int(cell["col"]), int(cell["row"])])
		path_token = "p%s" % "-".join(cells)
	return "option.%s.%s.d%dr%d.%s" % [
		str(goal["goal_id"]).trim_prefix("goal."),
		style,
		int(destination["col"]),
		int(destination["row"]),
		path_token,
	]


static func _style_from_option_id(option_id: String) -> String:
	for style_value: Variant in STYLE_ORDER:
		var style: String = str(style_value)
		if option_id.contains(".%s.d" % style):
			return style
	return ""


static func _mechanics_key(option: Dictionary) -> String:
	return "%s|%s" % [
		_cell_key(option["destination"] as Dictionary),
		_path_token(option["path"] as Array),
	]


static func _same_mechanical_facts(left: Dictionary, right: Dictionary) -> bool:
	var left_copy: Dictionary = left.duplicate(true)
	var right_copy: Dictionary = right.duplicate(true)
	left_copy.erase("option_id")
	right_copy.erase("option_id")
	return left_copy == right_copy


static func _path_token(path: Array) -> String:
	var cells: Array = []
	for cell_value: Variant in path:
		cells.append(_cell_key(cell_value as Dictionary))
	return ">".join(cells)


static func _path_less(left: Array, right: Array) -> bool:
	var limit: int = mini(left.size(), right.size())
	for index in range(limit):
		var left_cell: Dictionary = left[index] as Dictionary
		var right_cell: Dictionary = right[index] as Dictionary
		if left_cell != right_cell:
			return _cell_less(left_cell, right_cell)
	return left.size() < right.size()


static func _cell_less(left: Dictionary, right: Dictionary) -> bool:
	if int(left["col"]) != int(right["col"]):
		return int(left["col"]) < int(right["col"])
	return int(left["row"]) < int(right["row"])


static func _cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell["col"]), int(cell["row"])]


static func _cell_from_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	return {"col": int(parts[0]), "row": int(parts[1])}


static func _chebyshev(left: Dictionary, right: Dictionary) -> int:
	return maxi(
		abs(int(left["col"]) - int(right["col"])),
		abs(int(left["row"]) - int(right["row"]))
	)


static func _failure(reason: String, field: String) -> Dictionary:
	return {"valid": false, "options": [], "reason": reason, "field": field}
