class_name MovementIntent
extends RefCounted

## The selected actor, route option, commitment, and action/fallback pair.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"mover_id",
	"activation_id",
	"goal_id",
	"option_id",
	"path",
	"capacity",
	"commitment",
	"planned_action",
	"fallback",
	"pressure_sources",
]


static func build(
	mover_id: String,
	activation_id: String,
	goal_id: String,
	option_id: String,
	path: Array,
	capacity: int,
	commitment: int,
	planned_action: Dictionary,
	fallback: Dictionary,
	pressure_sources: Array
) -> Dictionary:
	return {
		"mover_id": mover_id,
		"activation_id": activation_id,
		"goal_id": goal_id,
		"option_id": option_id,
		"path": path.duplicate(true),
		"capacity": capacity,
		"commitment": commitment,
		"planned_action": planned_action.duplicate(true),
		"fallback": fallback.duplicate(true),
		"pressure_sources": V.canonical_string_array(pressure_sources),
	}


static func validate(value: Dictionary, origin: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var origin_result: Dictionary = V.validate_position(origin, "origin")
	if not bool(origin_result["valid"]):
		return origin_result
	for field: String in ["mover_id", "activation_id", "goal_id", "option_id"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	var path_result: Dictionary = V.require_position_array(value, "path")
	if not bool(path_result["valid"]):
		return path_result
	var excludes_result: Dictionary = V.require_path_excludes_origin(value["path"] as Array, origin, "path")
	if not bool(excludes_result["valid"]):
		return excludes_result
	var capacity_result: Dictionary = V.require_capacity(value, "capacity")
	if not bool(capacity_result["valid"]):
		return capacity_result
	var commitment_result: Dictionary = V.require_non_negative_int(value, "commitment")
	if not bool(commitment_result["valid"]):
		return commitment_result
	if int(value["commitment"]) > int(value["capacity"]):
		return V.failure("commitment_exceeds_capacity", "commitment")
	for field: String in ["planned_action", "fallback"]:
		var dict_result: Dictionary = V.require_type(value, field, TYPE_DICTIONARY)
		if not bool(dict_result["valid"]):
			return dict_result
	var pressure_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "pressure_sources")
	if not bool(pressure_result["valid"]):
		return pressure_result
	return V.ok()
