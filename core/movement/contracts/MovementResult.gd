class_name MovementResult
extends RefCounted

## Authoritative chronological movement result for combat and stage traversal.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")

const STOP_REASONS: Array = [
	"reached_destination",
	"commitment_spent",
	"capacity_spent",
	"no_route",
	"blocked_edge",
	"occupied",
	"interrupted",
	"binding_stop",
	"ko",
	"death",
	"action_invalid_no_fallback",
]
const REQUIRED_FIELDS: Array = [
	"mover_id",
	"activation_id",
	"goal_id",
	"option_id",
	"purpose",
	"origin",
	"final_destination",
	"planned_path",
	"actual_traversed_cells",
	"voluntary_cost",
	"forced_steps",
	"remaining_capacity",
	"stop_reason",
	"events",
	"planned_action",
	"resolved_action",
	"fallback",
	"hazards",
	"objective_progress",
	"hostile_constraints",
]


static func build(
	mover_id: String,
	activation_id: String,
	goal_id: String,
	option_id: String,
	purpose: String,
	origin: Dictionary,
	final_destination: Dictionary,
	planned_path: Array,
	actual_traversed_cells: Array,
	voluntary_cost: int,
	forced_steps: int,
	remaining_capacity: int,
	stop_reason: String,
	events: Array,
	planned_action: Dictionary,
	resolved_action: Dictionary,
	fallback: Dictionary,
	hazards: Array,
	objective_progress: float,
	hostile_constraints: Dictionary
) -> Dictionary:
	return {
		"mover_id": mover_id,
		"activation_id": activation_id,
		"goal_id": goal_id,
		"option_id": option_id,
		"purpose": purpose,
		"origin": origin.duplicate(true),
		"final_destination": final_destination.duplicate(true),
		"planned_path": planned_path.duplicate(true),
		"actual_traversed_cells": actual_traversed_cells.duplicate(true),
		"voluntary_cost": voluntary_cost,
		"forced_steps": forced_steps,
		"remaining_capacity": remaining_capacity,
		"stop_reason": stop_reason,
		"events": events.duplicate(true),
		"planned_action": planned_action.duplicate(true),
		"resolved_action": resolved_action.duplicate(true),
		"fallback": fallback.duplicate(true),
		"hazards": hazards.duplicate(true),
		"objective_progress": objective_progress,
		"hostile_constraints": hostile_constraints.duplicate(true),
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	for field: String in ["mover_id", "activation_id", "goal_id", "option_id", "purpose"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	for field: String in ["origin", "final_destination"]:
		var position_result: Dictionary = V.require_position(value, field)
		if not bool(position_result["valid"]):
			return position_result
	for field: String in ["planned_path", "actual_traversed_cells"]:
		var path_result: Dictionary = V.require_position_array(value, field)
		if not bool(path_result["valid"]):
			return path_result
		var excludes_result: Dictionary = V.require_path_excludes_origin(
			value[field] as Array,
			value["origin"] as Dictionary,
			field
		)
		if not bool(excludes_result["valid"]):
			return excludes_result
	for field: String in ["voluntary_cost", "forced_steps"]:
		var int_result: Dictionary = V.require_non_negative_int(value, field)
		if not bool(int_result["valid"]):
			return int_result
	var remaining_capacity_result: Dictionary = V.require_capacity(value, "remaining_capacity")
	if not bool(remaining_capacity_result["valid"]):
		return remaining_capacity_result
	var stop_result: Dictionary = V.require_non_empty_string(value, "stop_reason")
	if not bool(stop_result["valid"]):
		return stop_result
	if not STOP_REASONS.has(str(value["stop_reason"])):
		return V.failure("invalid_stop_reason", "stop_reason")
	var events_result: Dictionary = V.require_array_of_dictionaries(value, "events")
	if not bool(events_result["valid"]):
		return events_result
	var previous_seq: int = -1
	var projected_traversal: Array = []
	var current_position: Dictionary = (value["origin"] as Dictionary).duplicate(true)
	var projected_voluntary_cost: int = 0
	var projected_forced_steps: int = 0
	var movement_stopped: bool = false
	var last_event_stop_reason: String = ""
	var projected_hazards: Array = []
	for event_value: Variant in value["events"] as Array:
		var event: Dictionary = event_value as Dictionary
		var event_result: Dictionary = EventContract.validate(event)
		if not bool(event_result["valid"]):
			return V.failure(
				"invalid_event.%s" % str(event_result["reason"]),
				"events.%s" % str(event_result["field"])
			)
		var seq: int = int(event["seq"])
		if seq <= previous_seq:
			return V.failure("event_seq_not_strictly_increasing", "events")
		previous_seq = seq
		var movement_kind: String = str(event["movement_kind"])
		var event_stop_reason: String = str(event["stop_reason"])
		var event_hazard: Dictionary = event["hazard"] as Dictionary
		if not event_hazard.is_empty():
			projected_hazards.append(event_hazard.duplicate(true))
		if movement_kind != "none" and movement_stopped:
			return V.failure("movement_after_stop_event", "events")
		if not event_stop_reason.is_empty():
			last_event_stop_reason = event_stop_reason
			movement_stopped = true
		if movement_kind == "none":
			continue
		if (event["from_pos"] as Dictionary) != current_position:
			return V.failure("event_movement_not_contiguous", "events")
		current_position = (event["to_pos"] as Dictionary).duplicate(true)
		projected_traversal.append(current_position.duplicate(true))
		if movement_kind == "voluntary":
			projected_voluntary_cost += int(event["cost"])
		else:
			if int(event["cost"]) != 0:
				return V.failure("forced_movement_has_cost", "events")
			projected_forced_steps += 1
	if not (value["events"] as Array).is_empty() and last_event_stop_reason.is_empty():
		return V.failure("missing_event_stop_reason", "events")
	if not last_event_stop_reason.is_empty() and last_event_stop_reason != str(value["stop_reason"]):
		return V.failure("event_stop_reason_mismatch", "stop_reason")
	var actual: Array = value["actual_traversed_cells"] as Array
	if projected_traversal != actual:
		return V.failure("actual_traversal_event_mismatch", "actual_traversed_cells")
	if projected_voluntary_cost != int(value["voluntary_cost"]):
		return V.failure("voluntary_cost_event_mismatch", "voluntary_cost")
	if projected_forced_steps != int(value["forced_steps"]):
		return V.failure("forced_steps_event_mismatch", "forced_steps")
	if current_position != (value["final_destination"] as Dictionary):
		return V.failure("final_destination_mismatch", "final_destination")
	for field: String in ["planned_action", "resolved_action", "fallback", "hostile_constraints"]:
		var dict_result: Dictionary = V.require_type(value, field, TYPE_DICTIONARY)
		if not bool(dict_result["valid"]):
			return dict_result
	var hazard_result: Dictionary = V.require_array_of_dictionaries(value, "hazards")
	if not bool(hazard_result["valid"]):
		return hazard_result
	if (value["hazards"] as Array) != projected_hazards:
		return V.failure("hazard_projection_mismatch", "hazards")
	var objective_result: Dictionary = V.require_number(value, "objective_progress")
	if not bool(objective_result["valid"]):
		return objective_result
	return V.ok()
