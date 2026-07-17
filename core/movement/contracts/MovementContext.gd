class_name MovementContext
extends RefCounted

## Planner-visible facts plus authoritative topology needed by movement execution.
## This contract carries no simulation ownership and performs no mutation.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"mover_id",
	"activation_id",
	"origin",
	"bounds",
	"authoritative_walkable",
	"perceived_planning_cells",
	"occupancy",
	"perceived_actors",
	"relationships",
	"terrain_costs",
	"known_hazards",
	"objective_pressure",
	"movement_history",
]


static func build(
	mover_id: String,
	activation_id: String,
	origin: Dictionary,
	bounds: Dictionary,
	authoritative_walkable: Dictionary,
	perceived_planning_cells: Dictionary,
	occupancy: Dictionary,
	perceived_actors: Array,
	relationships: Dictionary,
	terrain_costs: Dictionary,
	known_hazards: Array,
	objective_pressure: Dictionary,
	movement_history: Array
) -> Dictionary:
	return {
		"mover_id": mover_id,
		"activation_id": activation_id,
		"origin": origin.duplicate(true),
		"bounds": bounds.duplicate(true),
		"authoritative_walkable": authoritative_walkable.duplicate(true),
		"perceived_planning_cells": perceived_planning_cells.duplicate(true),
		"occupancy": occupancy.duplicate(true),
		"perceived_actors": perceived_actors.duplicate(true),
		"relationships": relationships.duplicate(true),
		"terrain_costs": terrain_costs.duplicate(true),
		"known_hazards": known_hazards.duplicate(true),
		"objective_pressure": objective_pressure.duplicate(true),
		"movement_history": movement_history.duplicate(true),
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	for field: String in ["mover_id", "activation_id"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	var origin_result: Dictionary = V.require_position(value, "origin")
	if not bool(origin_result["valid"]):
		return origin_result
	var bounds_type: Dictionary = V.require_type(value, "bounds", TYPE_DICTIONARY)
	if not bool(bounds_type["valid"]):
		return bounds_type
	var bounds: Dictionary = value["bounds"] as Dictionary
	var bounds_fields: Dictionary = V.validate_exact_fields(bounds, ["w", "h"])
	if not bool(bounds_fields["valid"]):
		return V.failure("invalid_bounds.%s" % str(bounds_fields["reason"]), "bounds.%s" % str(bounds_fields["field"]))
	for dimension: String in ["w", "h"]:
		if not bounds[dimension] is int:
			return V.failure("wrong_type", "bounds.%s" % dimension)
		if int(bounds[dimension]) <= 0:
			return V.failure("non_positive_bounds", "bounds.%s" % dimension)
	for field: String in [
		"authoritative_walkable",
		"perceived_planning_cells",
		"occupancy",
		"relationships",
		"terrain_costs",
		"objective_pressure",
	]:
		var dict_result: Dictionary = V.require_type(value, field, TYPE_DICTIONARY)
		if not bool(dict_result["valid"]):
			return dict_result
	for field: String in ["perceived_actors", "known_hazards", "movement_history"]:
		var array_result: Dictionary = V.require_array_of_dictionaries(value, field)
		if not bool(array_result["valid"]):
			return array_result
	return V.ok()
