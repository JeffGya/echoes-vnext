class_name MovementOption
extends RefCounted

## A mechanically truthful route candidate. Path contains destinations only.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"goal_id",
	"option_id",
	"purpose",
	"destination",
	"path",
	"route_cost",
	"shortest_cost",
	"slack",
	"capacity",
	"commitment",
	"exposure",
	"congestion",
	"cohesion",
	"hostile_control_sources",
	"hazard_summary",
	"objective_progress",
	"planned_action",
	"fallback",
]


static func build(
	goal_id: String,
	option_id: String,
	purpose: String,
	destination: Dictionary,
	path: Array,
	route_cost: int,
	shortest_cost: int,
	slack: int,
	capacity: int,
	commitment: int,
	exposure: float,
	congestion: float,
	cohesion: float,
	hostile_control_sources: Array,
	hazard_summary: Dictionary,
	objective_progress: float,
	planned_action: Dictionary,
	fallback: Dictionary
) -> Dictionary:
	return {
		"goal_id": goal_id,
		"option_id": option_id,
		"purpose": purpose,
		"destination": destination.duplicate(true),
		"path": path.duplicate(true),
		"route_cost": route_cost,
		"shortest_cost": shortest_cost,
		"slack": slack,
		"capacity": capacity,
		"commitment": commitment,
		"exposure": exposure,
		"congestion": congestion,
		"cohesion": cohesion,
		"hostile_control_sources": V.canonical_string_array(hostile_control_sources),
		"hazard_summary": hazard_summary.duplicate(true),
		"objective_progress": objective_progress,
		"planned_action": planned_action.duplicate(true),
		"fallback": fallback.duplicate(true),
	}


static func validate(value: Dictionary, origin: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var origin_result: Dictionary = V.validate_position(origin, "origin")
	if not bool(origin_result["valid"]):
		return origin_result
	for field: String in ["goal_id", "option_id", "purpose"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	var destination_result: Dictionary = V.require_position(value, "destination")
	if not bool(destination_result["valid"]):
		return destination_result
	var path_result: Dictionary = V.require_position_array(value, "path")
	if not bool(path_result["valid"]):
		return path_result
	var excludes_result: Dictionary = V.require_path_excludes_origin(value["path"] as Array, origin, "path")
	if not bool(excludes_result["valid"]):
		return excludes_result
	var path: Array = value["path"] as Array
	if not path.is_empty() and (path.back() as Dictionary) != (value["destination"] as Dictionary):
		return V.failure("path_destination_mismatch", "path")
	if path.is_empty() and (value["destination"] as Dictionary) != origin:
		return V.failure("empty_path_destination_must_equal_origin", "destination")
	for field: String in ["route_cost", "shortest_cost", "slack", "commitment"]:
		var int_result: Dictionary = V.require_non_negative_int(value, field)
		if not bool(int_result["valid"]):
			return int_result
	var capacity_result: Dictionary = V.require_capacity(value, "capacity")
	if not bool(capacity_result["valid"]):
		return capacity_result
	if int(value["shortest_cost"]) > int(value["route_cost"]):
		return V.failure("shortest_cost_exceeds_route_cost", "shortest_cost")
	var expected_slack: int = int(value["route_cost"]) - int(value["shortest_cost"])
	if int(value["slack"]) != expected_slack:
		return V.failure("slack_mismatch", "slack")
	var normal_slack_limit: int = maxi(2, ceili(float(value["shortest_cost"]) * 0.25))
	if int(value["route_cost"]) > int(value["shortest_cost"]) + normal_slack_limit:
		return V.failure("route_exceeds_normal_slack_envelope", "route_cost")
	if int(value["route_cost"]) > int(value["capacity"]):
		return V.failure("route_cost_exceeds_capacity", "route_cost")
	if int(value["commitment"]) != int(value["route_cost"]):
		return V.failure("commitment_must_equal_route_cost", "commitment")
	for field: String in ["exposure", "congestion", "cohesion", "objective_progress"]:
		var number_result: Dictionary = V.require_number(value, field)
		if not bool(number_result["valid"]):
			return number_result
	var control_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "hostile_control_sources")
	if not bool(control_result["valid"]):
		return control_result
	for field: String in ["hazard_summary", "planned_action", "fallback"]:
		var dict_result: Dictionary = V.require_type(value, field, TYPE_DICTIONARY)
		if not bool(dict_result["valid"]):
			return dict_result
	return V.ok()
