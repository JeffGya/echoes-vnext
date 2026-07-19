# res://core/movement/MovementExecutor.gd
# V2-COMBAT-002 Slice 3 (DORMANT): physical, edge-by-edge movement executor.
#
# Pure, deterministic, stateless. No RNG, no OS time, no mutation of inputs, no
# actor/combat_state writes, no logging. NOT wired into live combat/flow — only
# tests and the next agent (CombatActivationService) consume it. This layer walks
# an already-planned route against PHYSICAL truth (slice 3 treats the supplied
# MovementContext as physical truth for occupancy / hostiles / hazards) and reports
# a MOVEMENT-PHASE OUTCOME dict. It does NOT assemble a validated MovementResult
# (action revalidation, Burning end-activation, KO/death — all belong to the next
# agent); it emits the movement facts that agent needs.
#
# ---------------------------------------------------------------------------
# ENTRY (FROZEN):
#   execute(context, intent, profile, hazard_ctx) -> Dictionary
#     context     : MovementContext.build() dict (origin, bounds,
#                   authoritative_walkable, occupancy, perceived_actors,
#                   relationships, terrain_costs, known_hazards, ...).
#     intent      : MovementIntent.build() dict (path excludes start, commitment,
#                   mover_id, ...). The committed budget is intent.commitment.
#     profile     : MovementProfile.build() dict; profile.capacity is the physical
#                   movement capacity wall.
#     hazard_ctx  : the per-activation hazard ledger. Shape:
#                   { "triggered": {unstable,binding,burning: bool},
#                     "config": data.combat.movement.hazards (OPTIONAL) }.
#                   The hazard CONFIG is injected by the caller inside hazard_ctx
#                   (execute() has no config param); the executor reads it once,
#                   passes it into every MovementHazardService cell-entry call, and
#                   re-attaches it to the returned ledger so the next agent (Burning)
#                   still has it. Only the "triggered" map is mutated across entries.
#
# OUTCOME DICT (returned — a subset/superset of MovementResult movement fields):
#   origin                  {col,row}   — context.origin (deep copy)
#   final_destination       {col,row}   — cell occupied when movement halted
#   planned_path            Array       — intent.path (excludes start)
#   actual_traversed_cells  Array       — every voluntary + forced destination in
#                                         chronological order (excludes start)
#   voluntary_cost          int         — sum of voluntary edge costs charged
#   forced_steps            int         — count of forced (hazard displacement) steps
#   remaining_capacity      int         — max(0, profile.capacity - voluntary_cost)
#   stop_reason             String      — reached_destination | blocked_edge |
#                                         occupied | commitment_spent |
#                                         capacity_spent | no_route | binding_stop
#   events                  Array       — ordered MovementEvent.build() dicts,
#                                         strictly increasing + contiguous seq
#   hazards                 Array        — hazard descriptors from hazard events
#                                         (projection of every event.hazard != {})
#   hostile_constraints     Array        — sorted unique ids of every ACTIVE hostile
#                                         that projected control over a traversed edge
#   next_seq                int         — next free MovementEvent seq
#   hazard_ctx              Dictionary   — updated ledger (+ carried config)
#
# ---------------------------------------------------------------------------
# MOVEMENT SEMANTICS (FROZEN):
#   Walk intent.path from context.origin. For each edge (from -> to):
#     1. Edge legality via StageTerrain.is_legal_edge (two-solid-corners diagonal
#        rule + bounds). Illegal -> stop "blocked_edge".
#     2. Destination physically occupied (context.occupancy, minus the mover) ->
#        stop "occupied".
#     3. Voluntary edge cost = destination entry cost (terrain_costs, default 1;
#        a "difficult" cell is 2) PLUS +1 ONCE if EITHER endpoint is 8-adjacent
#        (Chebyshev == 1) to >= 1 active hostile. Budget wall = min(profile.capacity,
#        intent.commitment): projected cost > wall -> stop "capacity_spent" when
#        capacity is the tighter bound, else "commitment_spent".
#     4. On ENTERING the destination, MovementHazardService.resolve_cell_entry
#        applies Unstable forced displacement (free, no capacity) then Binding.
#        Binding -> stop "binding_stop", halting remaining edges.
#   Reaching the end of the path with budget remaining -> "reached_destination".
#   Empty path -> "no_route". Every non-binding stop emits a terminal "none" event
#   carrying the reason; Binding's own stop event is already terminal.

class_name MovementExecutor
extends RefCounted

const StageTerrain = preload("res://core/realms/StageTerrain.gd")
const HazardService = preload("res://core/movement/MovementHazardService.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")

const _PHASE: String = "movement"


static func execute(
	context: Dictionary,
	intent: Dictionary,
	profile: Dictionary,
	hazard_ctx: Dictionary
) -> Dictionary:
	var mover_id: String = str(intent.get("mover_id", context.get("mover_id", "mover")))
	var origin: Dictionary = (context.get("origin", {}) as Dictionary).duplicate(true)
	var planned_path: Array = (intent.get("path", []) as Array).duplicate(true)
	var walkable: Dictionary = context.get("authoritative_walkable", {}) as Dictionary
	var bounds: Dictionary = context.get("bounds", {}) as Dictionary
	var occupancy: Dictionary = context.get("occupancy", {}) as Dictionary
	var terrain_costs: Dictionary = context.get("terrain_costs", {}) as Dictionary
	var hazards: Array = context.get("known_hazards", []) as Array
	var commitment: int = int(intent.get("commitment", 0))
	var capacity: int = int(profile.get("capacity", 0))
	var hazard_config: Dictionary = hazard_ctx.get("config", {}) as Dictionary

	var controllers: Array = _active_hostiles(context)

	var events: Array = []
	var actual: Array = []
	var hostile_set: Dictionary = {}
	var seq: int = 0
	var voluntary_cost: int = 0
	var forced_steps: int = 0
	var current: Dictionary = origin.duplicate(true)
	var ledger: Dictionary = hazard_ctx
	var stop_reason: String = ""

	if planned_path.is_empty():
		stop_reason = "no_route"

	for cell_value: Variant in planned_path:
		var next_cell: Dictionary = cell_value as Dictionary
		var from_cell: Dictionary = current.duplicate(true)

		# 1) Edge legality (two-solid-corners diagonal rule + bounds).
		if not StageTerrain.is_legal_edge(from_cell, next_cell, walkable, bounds):
			stop_reason = "blocked_edge"
			break

		# 2) Physical occupancy (mover's own cell never blocks itself).
		var next_key: String = _cell_key(next_cell)
		if occupancy.has(next_key) and str(occupancy[next_key]) != mover_id:
			stop_reason = "occupied"
			break

		# 3) Voluntary edge cost + budget wall.
		var entry_cost: int = _entry_cost(next_key, terrain_costs)
		var edge_sources: Array = _edge_hostile_sources(controllers, from_cell, next_cell)
		var edge_cost: int = entry_cost + (1 if not edge_sources.is_empty() else 0)
		var projected: int = voluntary_cost + edge_cost
		var wall: int = mini(capacity, commitment)
		if projected > wall:
			stop_reason = "capacity_spent" if capacity < commitment else "commitment_spent"
			break

		# Commit the voluntary edge.
		voluntary_cost = projected
		for source_value: Variant in edge_sources:
			hostile_set[str(source_value)] = true
		events.append(EventContract.build(
			seq, _PHASE, "move.step", mover_id,
			from_cell, next_cell, "voluntary", edge_cost, {}, 0, ""
		))
		seq += 1
		actual.append(next_cell.duplicate(true))
		current = next_cell.duplicate(true)

		# 4) Hazard resolution on cell entry (Unstable displacement -> Binding).
		var entry_context: Dictionary = {
			"config": hazard_config,
			"walkable": walkable,
			"bounds": bounds,
			"occupied": occupancy,
			"mover_id": mover_id,
			"phase": _PHASE,
			"seq": seq,
			"from_cell": from_cell,
			"is_forced_entry": false,
		}
		var hazard_result: Dictionary = HazardService.resolve_cell_entry(
			next_cell, hazards, entry_context, ledger
		)
		for event_value: Variant in hazard_result.get("events", []) as Array:
			events.append((event_value as Dictionary).duplicate(true))
		seq = int(hazard_result.get("next_seq", seq))
		ledger = hazard_result.get("hazard_ctx", ledger) as Dictionary

		if bool(hazard_result.get("displaced", false)):
			forced_steps += 1
			current = (hazard_result.get("displaced_to", current) as Dictionary).duplicate(true)
			actual.append(current.duplicate(true))

		if bool(hazard_result.get("stop", false)):
			# Binding's stop event is already terminal — do not append another.
			stop_reason = str(hazard_result.get("stop_reason", "binding_stop"))
			break

	if stop_reason == "":
		stop_reason = "reached_destination"

	if stop_reason != "binding_stop":
		events.append(EventContract.build(
			seq, _PHASE, "move.stop", mover_id,
			current, current, "none", 0, {}, 0, stop_reason
		))
		seq += 1

	return {
		"origin": origin,
		"final_destination": current,
		"planned_path": planned_path,
		"actual_traversed_cells": actual,
		"voluntary_cost": voluntary_cost,
		"forced_steps": forced_steps,
		"remaining_capacity": maxi(0, capacity - voluntary_cost),
		"stop_reason": stop_reason,
		"events": events,
		"hazards": _project_hazards(events),
		"hostile_constraints": _sorted_keys(hostile_set),
		"next_seq": seq,
		"hazard_ctx": _final_ledger(ledger, hazard_config),
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

static func _cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


## Destination-entry cost: absent -> 1, present positive -> that value.
## MovementContext validation guarantees positive ints; this stays defensive.
static func _entry_cost(cell_key: String, terrain_costs: Dictionary) -> int:
	if not terrain_costs.has(cell_key):
		return 1
	var value: int = int(terrain_costs[cell_key])
	return value if value >= 1 else 1


## Active hostiles that project a controlling state, sorted by id. Mirrors the
## planner's control model (MovementOptionService._build_control): relationship
## "hostile", not dead/KO/structure, controlling_state == true.
static func _active_hostiles(context: Dictionary) -> Array:
	var relationships: Dictionary = context.get("relationships", {}) as Dictionary
	var controllers: Array = []
	for actor_value: Variant in context.get("perceived_actors", []) as Array:
		var actor: Dictionary = actor_value as Dictionary
		var actor_id: String = str(actor.get("id", ""))
		if str(relationships.get(actor_id, "")) != "hostile":
			continue
		if bool(actor.get("is_dead", false)) or bool(actor.get("is_ko", false)) or bool(actor.get("is_structure", false)):
			continue
		if not bool(actor.get("controlling_state", false)):
			continue
		controllers.append(actor)
	controllers.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary).get("id", "")) < str((right as Dictionary).get("id", ""))
	)
	return controllers


## Sorted unique ids of controllers 8-adjacent (Chebyshev == 1) to EITHER edge
## endpoint. Non-empty -> the edge pays the once-per-edge hostile-control surcharge.
static func _edge_hostile_sources(controllers: Array, from_cell: Dictionary, to_cell: Dictionary) -> Array:
	var sources: Dictionary = {}
	for controller_value: Variant in controllers:
		var controller: Dictionary = controller_value as Dictionary
		var pos: Dictionary = controller.get("position", {}) as Dictionary
		if _chebyshev(from_cell, pos) == 1 or _chebyshev(to_cell, pos) == 1:
			sources[str(controller.get("id", ""))] = true
	return _sorted_keys(sources)


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(
		absi(int(a.get("col", 0)) - int(b.get("col", 0))),
		absi(int(a.get("row", 0)) - int(b.get("row", 0)))
	)


static func _sorted_keys(set_dict: Dictionary) -> Array:
	var keys: Array = set_dict.keys()
	keys.sort()
	return keys


## Every non-empty hazard descriptor carried on an event, in order. Matches
## MovementResult's hazard projection so the next agent can assemble a valid result.
static func _project_hazards(events: Array) -> Array:
	var projected: Array = []
	for event_value: Variant in events:
		var event: Dictionary = event_value as Dictionary
		var hazard: Dictionary = event.get("hazard", {}) as Dictionary
		if not hazard.is_empty():
			projected.append(hazard.duplicate(true))
	return projected


## Normalized ledger with the stable config re-attached for the next agent.
static func _final_ledger(ledger: Dictionary, config: Dictionary) -> Dictionary:
	var triggered: Dictionary = ledger.get("triggered", {}) as Dictionary
	return {
		"triggered": {
			"unstable": bool(triggered.get("unstable", false)),
			"binding": bool(triggered.get("binding", false)),
			"burning": bool(triggered.get("burning", false)),
		},
		"config": config.duplicate(true),
	}
