class_name MovementEvent
extends RefCounted

## One ordered movement/execution fact. MovementResult validates sequence order.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const MOVEMENT_KINDS: Array = ["none", "voluntary", "forced"]
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
	"seq",
	"phase",
	"type",
	"source_id",
	"from_pos",
	"to_pos",
	"movement_kind",
	"cost",
	"hazard",
	"damage",
	"stop_reason",
]


static func build(
	seq: int,
	phase: String,
	event_type: String,
	source_id: String,
	from_pos: Dictionary,
	to_pos: Dictionary,
	movement_kind: String,
	cost: int,
	hazard: Dictionary,
	damage: int,
	stop_reason: String
) -> Dictionary:
	return {
		"seq": seq,
		"phase": phase,
		"type": event_type,
		"source_id": source_id,
		"from_pos": from_pos.duplicate(true),
		"to_pos": to_pos.duplicate(true),
		"movement_kind": movement_kind,
		"cost": cost,
		"hazard": hazard.duplicate(true),
		"damage": damage,
		"stop_reason": stop_reason,
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var seq_result: Dictionary = V.require_non_negative_int(value, "seq")
	if not bool(seq_result["valid"]):
		return seq_result
	for field: String in ["phase", "type"]:
		var string_result: Dictionary = V.require_non_empty_string(value, field)
		if not bool(string_result["valid"]):
			return string_result
	for field: String in ["source_id", "movement_kind", "stop_reason"]:
		var string_result: Dictionary = V.require_type(value, field, TYPE_STRING)
		if not bool(string_result["valid"]):
			return string_result
	for field: String in ["from_pos", "to_pos"]:
		var position_result: Dictionary = V.require_position(value, field)
		if not bool(position_result["valid"]):
			return position_result
	if not MOVEMENT_KINDS.has(str(value["movement_kind"])):
		return V.failure("invalid_movement_kind", "movement_kind")
	if str(value["movement_kind"]) != "none":
		var from_pos: Dictionary = value["from_pos"] as Dictionary
		var to_pos: Dictionary = value["to_pos"] as Dictionary
		var col_distance: int = absi(int(to_pos["col"]) - int(from_pos["col"]))
		var row_distance: int = absi(int(to_pos["row"]) - int(from_pos["row"]))
		if maxi(col_distance, row_distance) != 1:
			return V.failure("invalid_movement_edge", "to_pos")
	for field: String in ["cost", "damage"]:
		var int_result: Dictionary = V.require_non_negative_int(value, field)
		if not bool(int_result["valid"]):
			return int_result
	if str(value["movement_kind"]) == "voluntary" and int(value["cost"]) < 1:
		return V.failure("voluntary_movement_requires_positive_cost", "cost")
	var hazard_result: Dictionary = V.require_type(value, "hazard", TYPE_DICTIONARY)
	if not bool(hazard_result["valid"]):
		return hazard_result
	var stop_reason: String = str(value["stop_reason"])
	if not stop_reason.is_empty() and not STOP_REASONS.has(stop_reason):
		return V.failure("invalid_stop_reason", "stop_reason")
	return V.ok()
