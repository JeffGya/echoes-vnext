class_name MovementPerceivedActorFact
extends RefCounted

## Perceived actor facts available to planning. This is never physical hidden truth.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"id", "position", "kind", "is_dead", "is_ko", "is_structure",
	"is_spirit", "is_quarry", "controlling_state", "health_ratio",
]


static func build(
	actor_id: String,
	position: Dictionary,
	kind: String,
	is_dead: bool,
	is_ko: bool,
	is_structure: bool,
	is_spirit: bool,
	is_quarry: bool,
	controlling_state: bool,
	health_ratio: float
) -> Dictionary:
	return {
		"id": actor_id,
		"position": position.duplicate(true),
		"kind": kind,
		"is_dead": is_dead,
		"is_ko": is_ko,
		"is_structure": is_structure,
		"is_spirit": is_spirit,
		"is_quarry": is_quarry,
		"controlling_state": controlling_state,
		"health_ratio": health_ratio,
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var id_result: Dictionary = V.require_non_empty_string(value, "id")
	if not bool(id_result["valid"]):
		return id_result
	var position_result: Dictionary = V.require_position(value, "position")
	if not bool(position_result["valid"]):
		return position_result
	var kind_result: Dictionary = V.require_semantic_token(value, "kind")
	if not bool(kind_result["valid"]):
		return kind_result
	for field: String in [
		"is_dead", "is_ko", "is_structure", "is_spirit", "is_quarry", "controlling_state",
	]:
		var bool_result: Dictionary = V.require_type(value, field, TYPE_BOOL)
		if not bool(bool_result["valid"]):
			return bool_result
	var health_result: Dictionary = V.require_unit_interval(value, "health_ratio")
	if not bool(health_result["valid"]):
		return health_result
	if bool(value["is_structure"]) != (str(value["kind"]) == "structure"):
		return V.failure("kind_structure_mismatch", "kind")
	if (
		bool(value["controlling_state"])
		and (bool(value["is_dead"]) or bool(value["is_ko"]) or bool(value["is_structure"]))
	):
		return V.failure("incapable_actor_cannot_control", "controlling_state")
	return V.ok()
