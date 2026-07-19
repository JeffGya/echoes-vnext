class_name MovementKnownHazardFact
extends RefCounted

## A hazard fact the mover is permitted to use during planning.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = ["id", "position", "hazard_type"]

## Canonical fixed-hazard vocabulary (V2-COMBAT-002 Slice 3). Additive reference for
## MovementHazardService; validate() is intentionally left permissive (semantic-token
## only) so existing callers/tests using other hazard_type tokens still pass.
const HAZARD_TYPES: Array = ["unstable", "binding", "burning"]


static func build(hazard_id: String, position: Dictionary, hazard_type: String) -> Dictionary:
	return {
		"id": hazard_id,
		"position": position.duplicate(true),
		"hazard_type": hazard_type,
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
	return V.require_semantic_token(value, "hazard_type")
