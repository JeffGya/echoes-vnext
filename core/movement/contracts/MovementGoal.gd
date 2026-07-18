class_name MovementGoal
extends RefCounted

## A truthful tactical purpose and its bounded destination region.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

const PURPOSES: Array = [
	"advance", "engage", "intercept", "protect", "hold", "pursue", "cut_off",
	"reposition", "regroup", "withdraw", "read", "escort",
]
const MODES: Array = [
	"combat", "purify_shrine", "recover", "protect", "endure", "pursue", "guide_spirit",
]
const GOAL_ROLES: Array = [
	"baseline", "purifier", "holder", "carrier", "quarry", "spirit",
	"runner", "screener", "protector", "vanguard", "rear_guard", "blocker",
	"hunter", "watcher", "breaker", "custody_threat", "escort_threat",
]

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
		"destination_region": V.canonical_position_array(destination_region),
		"urgency": urgency,
		"objective_progress": objective_progress,
		"relevant_actors": V.canonical_string_array(relevant_actors),
		"pressure_sources": V.canonical_string_array(pressure_sources),
		"planned_primary": planned_primary.duplicate(true),
		"declared_fallback": declared_fallback.duplicate(true),
	}


static func validate(value: Dictionary, mover_origin: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var origin_result: Dictionary = V.validate_position(mover_origin, "mover_origin")
	if not bool(origin_result["valid"]):
		return origin_result
	for field: String in ["goal_id", "purpose"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	if not PURPOSES.has(str(value["purpose"])):
		return V.failure("invalid_purpose", "purpose")
	var region_result: Dictionary = V.require_canonical_position_array(
		value,
		"destination_region",
		false
	)
	if not bool(region_result["valid"]):
		return region_result
	if (value["destination_region"] as Array).has(mover_origin) and str(value["purpose"]) != "hold":
		return V.failure("goal_region_contains_origin", "destination_region")
	var id_result: Dictionary = _validate_goal_id(value)
	if not bool(id_result["valid"]):
		return id_result
	for field: String in ["urgency", "objective_progress"]:
		var number_result: Dictionary = V.require_unit_interval(value, field)
		if not bool(number_result["valid"]):
			return number_result
	var relevant_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "relevant_actors")
	if not bool(relevant_result["valid"]):
		return relevant_result
	var pressure_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "pressure_sources")
	if not bool(pressure_result["valid"]):
		return pressure_result
	var primary_type: Dictionary = V.require_type(value, "planned_primary", TYPE_DICTIONARY)
	if not bool(primary_type["valid"]):
		return primary_type
	var primary_result: Dictionary = ActionPlan.validate(value["planned_primary"] as Dictionary)
	if not bool(primary_result["valid"]):
		return V.failure(
			"invalid_action_plan.%s" % str(primary_result["reason"]),
			"planned_primary.%s" % str(primary_result["field"])
		)
	var fallback_type: Dictionary = V.require_type(value, "declared_fallback", TYPE_DICTIONARY)
	if not bool(fallback_type["valid"]):
		return fallback_type
	if not (value["declared_fallback"] as Dictionary).is_empty():
		var fallback_result: Dictionary = ActionPlan.validate(value["declared_fallback"] as Dictionary)
		if not bool(fallback_result["valid"]):
			return V.failure(
				"invalid_action_plan.%s" % str(fallback_result["reason"]),
				"declared_fallback.%s" % str(fallback_result["field"])
			)
	var plan_result: Dictionary = _validate_plan_for_purpose(value)
	if not bool(plan_result["valid"]):
		return plan_result
	return V.ok()


static func _validate_goal_id(value: Dictionary) -> Dictionary:
	var goal_id: String = str(value["goal_id"])
	if not V.is_semantic_token(goal_id):
		return V.failure("invalid_goal_id", "goal_id")
	var parts: PackedStringArray = goal_id.split(".", false)
	if parts.size() != 5 or parts[0] != "goal":
		return V.failure("invalid_goal_id", "goal_id")
	if not MODES.has(parts[1]):
		return V.failure("invalid_goal_mode", "goal_id")
	if parts[2] != str(value["purpose"]):
		return V.failure("goal_id_purpose_mismatch", "goal_id")
	if not GOAL_ROLES.has(parts[3]):
		return V.failure("invalid_goal_role", "goal_id")
	var anchor: Dictionary = _parse_anchor(parts[4])
	if anchor.is_empty():
		return V.failure("invalid_goal_anchor", "goal_id")
	if anchor != (value["destination_region"] as Array)[0]:
		return V.failure("goal_anchor_mismatch", "goal_id")
	return V.ok()


static func _parse_anchor(token: String) -> Dictionary:
	if not token.begins_with("c"):
		return {}
	var row_marker: int = token.find("r", 1)
	if row_marker <= 1 or row_marker >= token.length() - 1:
		return {}
	var col_text: String = token.substr(1, row_marker - 1)
	var row_text: String = token.substr(row_marker + 1)
	if not col_text.is_valid_int() or not row_text.is_valid_int():
		return {}
	var col: int = int(col_text)
	var row: int = int(row_text)
	if col < 0 or row < 0 or token != "c%dr%d" % [col, row]:
		return {}
	return {"col": col, "row": row}


static func _validate_plan_for_purpose(value: Dictionary) -> Dictionary:
	var purpose: String = str(value["purpose"])
	var primary: Dictionary = value["planned_primary"] as Dictionary
	var fallback: Dictionary = value["declared_fallback"] as Dictionary
	var target_id: String = str(primary["target_id"])
	var relevant: Array = value["relevant_actors"] as Array
	match purpose:
		"advance":
			if not str(primary["type"]) in ["actor.move", "actor.purify_shrine"]:
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if target_id.is_empty() or not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"engage", "pursue":
			if str(primary["type"]) != "melee_attack":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if target_id.is_empty() or not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"intercept", "hold", "cut_off":
			if str(primary["type"]) != "actor.guard":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty():
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"protect":
			if str(primary["type"]) == "protect_ally":
				if target_id.is_empty() or not relevant.has(target_id):
					return V.failure("invalid_primary_target", "planned_primary.target_id")
			elif str(primary["type"]) == "actor.guard":
				if not target_id.is_empty():
					return V.failure("invalid_primary_target", "planned_primary.target_id")
			else:
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
		"reposition", "regroup", "withdraw":
			if str(primary["type"]) != "actor.move":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty() and not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"read":
			if str(primary["type"]) != "actor.idle":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if not target_id.is_empty():
				return V.failure("invalid_primary_target", "planned_primary.target_id")
		"escort":
			if str(primary["type"]) != "protect_ally":
				return V.failure("invalid_primary_for_purpose", "planned_primary.type")
			if target_id.is_empty() or not relevant.has(target_id):
				return V.failure("invalid_primary_target", "planned_primary.target_id")
	if str(primary["type"]) == "actor.idle":
		if not fallback.is_empty():
			return V.failure("idle_primary_requires_empty_fallback", "declared_fallback")
		return V.ok()
	if fallback.is_empty():
		return V.failure("missing_universal_fallback", "declared_fallback")
	if (
		str(fallback["type"]) != "actor.idle"
		or not str(fallback["target_id"]).is_empty()
		or not (fallback["payload"] as Dictionary).is_empty()
	):
		return V.failure("invalid_universal_fallback", "declared_fallback")
	return V.ok()
