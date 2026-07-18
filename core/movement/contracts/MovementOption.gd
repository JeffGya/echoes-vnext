class_name MovementOption
extends RefCounted

## A mechanically truthful route candidate. Path contains destinations only.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")

const STYLES: Array = [
	"direct", "safe", "cohesive", "lateral", "screen", "intercept", "conservative",
]

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
	if not GoalContract.PURPOSES.has(str(value["purpose"])):
		return V.failure("invalid_purpose", "purpose")
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
	var option_id_result: Dictionary = _validate_option_id(value)
	if not bool(option_id_result["valid"]):
		return option_id_result
	for field: String in ["route_cost", "shortest_cost", "slack", "commitment"]:
		var int_result: Dictionary = V.require_non_negative_int(value, field)
		if not bool(int_result["valid"]):
			return int_result
	if path.is_empty():
		if str(value["purpose"]) != "hold":
			return V.failure("stationary_option_requires_hold", "purpose")
		if int(value["route_cost"]) != 0:
			return V.failure("empty_path_requires_zero_route_cost", "route_cost")
		if int(value["shortest_cost"]) != 0:
			return V.failure("empty_path_requires_zero_shortest_cost", "shortest_cost")
		if int(value["slack"]) != 0:
			return V.failure("empty_path_requires_zero_slack", "slack")
		if int(value["commitment"]) != 0:
			return V.failure("empty_path_requires_zero_commitment", "commitment")
	else:
		if int(value["route_cost"]) == 0:
			return V.failure("nonempty_path_requires_positive_route_cost", "route_cost")
		if int(value["shortest_cost"]) == 0:
			return V.failure("nonempty_path_requires_positive_shortest_cost", "shortest_cost")
		if int(value["commitment"]) == 0:
			return V.failure("nonempty_path_requires_positive_commitment", "commitment")
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
		var number_result: Dictionary = V.require_unit_interval(value, field)
		if not bool(number_result["valid"]):
			return number_result
	var control_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "hostile_control_sources")
	if not bool(control_result["valid"]):
		return control_result
	var hazard_type: Dictionary = V.require_type(value, "hazard_summary", TYPE_DICTIONARY)
	if not bool(hazard_type["valid"]):
		return hazard_type
	var hazard_summary: Dictionary = value["hazard_summary"] as Dictionary
	var hazard_fields: Dictionary = V.validate_exact_fields(hazard_summary, ["known_count", "known_ids"])
	if not bool(hazard_fields["valid"]):
		return V.failure(
			"invalid_hazard_summary.%s" % str(hazard_fields["reason"]),
			"hazard_summary.%s" % str(hazard_fields["field"])
		)
	var hazard_count_result: Dictionary = V.require_non_negative_int(hazard_summary, "known_count")
	if not bool(hazard_count_result["valid"]):
		return V.failure(
			"invalid_hazard_summary.%s" % str(hazard_count_result["reason"]),
			"hazard_summary.%s" % str(hazard_count_result["field"])
		)
	var hazard_ids_result: Dictionary = V.require_strictly_sorted_unique_strings(hazard_summary, "known_ids")
	if not bool(hazard_ids_result["valid"]):
		return V.failure(
			"invalid_hazard_summary.%s" % str(hazard_ids_result["reason"]),
			"hazard_summary.%s" % str(hazard_ids_result["field"])
		)
	if int(hazard_summary["known_count"]) != (hazard_summary["known_ids"] as Array).size():
		return V.failure("hazard_count_mismatch", "hazard_summary.known_count")
	var action_type: Dictionary = V.require_type(value, "planned_action", TYPE_DICTIONARY)
	if not bool(action_type["valid"]):
		return action_type
	var action_result: Dictionary = ActionPlan.validate(value["planned_action"] as Dictionary)
	if not bool(action_result["valid"]):
		return V.failure(
			"invalid_action_plan.%s" % str(action_result["reason"]),
			"planned_action.%s" % str(action_result["field"])
		)
	var fallback_type: Dictionary = V.require_type(value, "fallback", TYPE_DICTIONARY)
	if not bool(fallback_type["valid"]):
		return fallback_type
	if not (value["fallback"] as Dictionary).is_empty():
		var fallback_result: Dictionary = ActionPlan.validate(value["fallback"] as Dictionary)
		if not bool(fallback_result["valid"]):
			return V.failure(
				"invalid_action_plan.%s" % str(fallback_result["reason"]),
				"fallback.%s" % str(fallback_result["field"])
			)
	return V.ok()


static func _validate_option_id(value: Dictionary) -> Dictionary:
	var goal_id: String = str(value["goal_id"])
	var goal_parts: PackedStringArray = goal_id.split(".", false)
	if (
		goal_parts.size() != 5
		or goal_parts[0] != "goal"
		or not V.is_semantic_token(goal_id)
		or not GoalContract.MODES.has(goal_parts[1])
		or goal_parts[2] != str(value["purpose"])
		or not GoalContract.GOAL_ROLES.has(goal_parts[3])
		or not _is_canonical_cell_token(goal_parts[4], "c")
	):
		return V.failure("invalid_goal_id", "goal_id")
	var prefix: String = "option.%s." % goal_id.trim_prefix("goal.")
	var option_id: String = str(value["option_id"])
	if not option_id.begins_with(prefix):
		return V.failure("invalid_option_id", "option_id")
	var suffix_parts: PackedStringArray = option_id.trim_prefix(prefix).split(".", false)
	if suffix_parts.size() != 3:
		return V.failure("invalid_option_id", "option_id")
	var style: String = suffix_parts[0]
	if not STYLES.has(style):
		return V.failure("invalid_option_style", "option_id")
	var destination: Dictionary = value["destination"] as Dictionary
	if int(destination["col"]) < 0 or int(destination["row"]) < 0:
		return V.failure("invalid_option_destination_token", "option_id")
	var expected_destination: String = "d%dr%d" % [
		int(destination["col"]), int(destination["row"]),
	]
	if suffix_parts[1] != expected_destination:
		return V.failure("option_id_destination_mismatch", "option_id")
	var expected_path: String = "pstay"
	var path: Array = value["path"] as Array
	if not path.is_empty():
		var cells: Array = []
		for cell_value: Variant in path:
			var cell: Dictionary = cell_value as Dictionary
			if int(cell["col"]) < 0 or int(cell["row"]) < 0:
				return V.failure("invalid_option_path_token", "option_id")
			cells.append("c%dr%d" % [int(cell["col"]), int(cell["row"])])
		expected_path = "p%s" % "-".join(cells)
	if suffix_parts[2] != expected_path:
		return V.failure("option_id_path_mismatch", "option_id")
	return V.ok()


static func _is_canonical_cell_token(token: String, prefix: String) -> bool:
	if not token.begins_with(prefix):
		return false
	var row_marker: int = token.find("r", prefix.length())
	if row_marker <= prefix.length() or row_marker >= token.length() - 1:
		return false
	var col_text: String = token.substr(prefix.length(), row_marker - prefix.length())
	var row_text: String = token.substr(row_marker + 1)
	if not col_text.is_valid_int() or not row_text.is_valid_int():
		return false
	var col: int = int(col_text)
	var row: int = int(row_text)
	return col >= 0 and row >= 0 and token == "%s%dr%d" % [prefix, col, row]
