class_name MovementGoal
extends RefCounted

## A truthful tactical purpose and its bounded destination region.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"goal_id",
	"purpose",
	"destination_region",
	"urgency",
	"objective_progress",
	"relevant_actors",
	"pressure_sources",
	"planned_primary",
	"declared_fallback",
]


static func build(
	goal_id: String,
	purpose: String,
	destination_region: Array,
	urgency: float,
	objective_progress: float,
	relevant_actors: Array,
	pressure_sources: Array,
	planned_primary: Dictionary,
	declared_fallback: Dictionary
) -> Dictionary:
	return {
		"goal_id": goal_id,
		"purpose": purpose,
		"destination_region": destination_region.duplicate(true),
		"urgency": urgency,
		"objective_progress": objective_progress,
		"relevant_actors": relevant_actors.duplicate(true),
		"pressure_sources": V.canonical_string_array(pressure_sources),
		"planned_primary": planned_primary.duplicate(true),
		"declared_fallback": declared_fallback.duplicate(true),
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	for field: String in ["goal_id", "purpose"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	var region_result: Dictionary = V.require_position_array(value, "destination_region")
	if not bool(region_result["valid"]):
		return region_result
	for field: String in ["urgency", "objective_progress"]:
		var number_result: Dictionary = V.require_number(value, field)
		if not bool(number_result["valid"]):
			return number_result
	var relevant_result: Dictionary = V.require_array_of_strings(value, "relevant_actors")
	if not bool(relevant_result["valid"]):
		return relevant_result
	var pressure_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "pressure_sources")
	if not bool(pressure_result["valid"]):
		return pressure_result
	for field: String in ["planned_primary", "declared_fallback"]:
		var dict_result: Dictionary = V.require_type(value, field, TYPE_DICTIONARY)
		if not bool(dict_result["valid"]):
			return dict_result
	return V.ok()
