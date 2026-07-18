class_name MovementContext
extends RefCounted

## Planner-visible facts plus authoritative topology needed by movement execution.
## This contract carries no simulation ownership and performs no mutation.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ActorFact = preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")

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
	for field: String in ["authoritative_walkable", "perceived_planning_cells"]:
		var bool_map_result: Dictionary = _validate_cell_map(value[field] as Dictionary, field, TYPE_BOOL)
		if not bool(bool_map_result["valid"]):
			return bool_map_result
	var terrain_result: Dictionary = _validate_cell_map(value["terrain_costs"] as Dictionary, "terrain_costs", TYPE_INT, true)
	if not bool(terrain_result["valid"]):
		return terrain_result
	var actors_by_id: Dictionary = {}
	var actor_facts: Array = (value["perceived_actors"] as Array).duplicate(true)
	actor_facts.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _stable_variant_key(left) < _stable_variant_key(right)
	)
	for actor_value: Variant in actor_facts:
		var actor: Dictionary = actor_value as Dictionary
		var actor_result: Dictionary = ActorFact.validate(actor)
		if not bool(actor_result["valid"]):
			return V.failure(
				"invalid_actor_fact.%s" % str(actor_result["reason"]),
				"perceived_actors.%s" % str(actor_result["field"])
			)
		var actor_id: String = str(actor["id"])
		if actors_by_id.has(actor_id):
			return V.failure("duplicate_actor_id", "perceived_actors")
		actors_by_id[actor_id] = actor
	var occupancy: Dictionary = value["occupancy"] as Dictionary
	var occupancy_keys: Array = occupancy.keys()
	occupancy_keys.sort()
	for key_value: Variant in occupancy_keys:
		var key: String = str(key_value)
		if V.parse_canonical_cell_key(key).is_empty():
			return V.failure("invalid_cell_key", "occupancy.%s" % key)
		if not occupancy[key] is String:
			return V.failure("wrong_type", "occupancy.%s" % key)
		var actor_id: String = str(occupancy[key])
		if not actors_by_id.has(actor_id):
			return V.failure("unknown_actor_id", "occupancy.%s" % key)
		var actor: Dictionary = actors_by_id[actor_id] as Dictionary
		if V.canonical_cell_key(actor["position"] as Dictionary) != key:
			return V.failure("occupancy_position_mismatch", "occupancy.%s" % key)
	var relationships: Dictionary = value["relationships"] as Dictionary
	var relationship_ids: Array = relationships.keys()
	relationship_ids.sort()
	for id_value: Variant in relationship_ids:
		var actor_id: String = str(id_value)
		if not actors_by_id.has(actor_id):
			return V.failure("unknown_actor_id", "relationships.%s" % actor_id)
		if not relationships[actor_id] is String:
			return V.failure("wrong_type", "relationships.%s" % actor_id)
		if not str(relationships[actor_id]) in ["friendly", "neutral", "hostile"]:
			return V.failure("invalid_relationship", "relationships.%s" % actor_id)
	var hazard_ids: Dictionary = {}
	var hazard_facts: Array = (value["known_hazards"] as Array).duplicate(true)
	hazard_facts.sort_custom(func(left: Variant, right: Variant) -> bool:
		return _stable_variant_key(left) < _stable_variant_key(right)
	)
	for hazard_value: Variant in hazard_facts:
		var hazard: Dictionary = hazard_value as Dictionary
		var hazard_result: Dictionary = HazardFact.validate(hazard)
		if not bool(hazard_result["valid"]):
			return V.failure(
				"invalid_hazard_fact.%s" % str(hazard_result["reason"]),
				"known_hazards.%s" % str(hazard_result["field"])
			)
		var hazard_id: String = str(hazard["id"])
		if hazard_ids.has(hazard_id):
			return V.failure("duplicate_hazard_id", "known_hazards")
		hazard_ids[hazard_id] = true
	return V.ok()


static func _stable_variant_key(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value as Dictionary
			var keys: Array = dictionary.keys()
			keys.sort_custom(func(left: Variant, right: Variant) -> bool:
				return _stable_variant_key(left) < _stable_variant_key(right)
			)
			var parts: Array = []
			for key_value: Variant in keys:
				parts.append(
					"%s=%s" % [
						_stable_variant_key(key_value),
						_stable_variant_key(dictionary[key_value]),
					]
				)
			return "dictionary{%s}" % ";".join(parts)
		TYPE_ARRAY:
			var parts: Array = []
			for item: Variant in value as Array:
				parts.append(_stable_variant_key(item))
			return "array[%s]" % ";".join(parts)
		TYPE_STRING:
			return "string:%s" % str(value)
		TYPE_INT:
			return "int:%s" % str(value)
		TYPE_FLOAT:
			return "float:%s" % str(value)
		TYPE_BOOL:
			return "bool:%s" % str(value)
		TYPE_NIL:
			return "nil"
		_:
			return "%d:%s" % [typeof(value), str(value)]


static func _validate_cell_map(
	cell_map: Dictionary,
	field: String,
	expected_type: int,
	require_positive: bool = false
) -> Dictionary:
	var keys: Array = cell_map.keys()
	keys.sort()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if V.parse_canonical_cell_key(key).is_empty():
			return V.failure("invalid_cell_key", "%s.%s" % [field, key])
		if typeof(cell_map[key]) != expected_type:
			return V.failure("wrong_type", "%s.%s" % [field, key])
		if require_positive and int(cell_map[key]) <= 0:
			return V.failure("non_positive_cost", "%s.%s" % [field, key])
	return V.ok()
