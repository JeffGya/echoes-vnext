class_name MovementActionPlan
extends RefCounted

## Internal simulation action selected alongside a movement purpose.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = ["type", "target_id", "payload"]


static func build(action_type: String, target_id: String = "", payload: Dictionary = {}) -> Dictionary:
	return {
		"type": action_type,
		"target_id": target_id,
		"payload": payload.duplicate(true),
	}


static func from_legacy_candidate(value: Dictionary) -> Dictionary:
	var action_type: String = str(value.get("type", value.get("action_type", "")))
	var target_id: String = str(value.get("target_id", ""))
	var payload: Dictionary = {}
	if value.get("payload", {}) is Dictionary:
		payload = (value.get("payload", {}) as Dictionary).duplicate(true)
	var keys: Array = value.keys()
	keys.sort()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if key in ["type", "action_type", "target_id", "payload"]:
			continue
		payload[key] = value[key]
	return build(action_type, target_id, payload)


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var type_result: Dictionary = V.require_semantic_token(value, "type")
	if not bool(type_result["valid"]):
		return type_result
	var target_result: Dictionary = V.require_type(value, "target_id", TYPE_STRING)
	if not bool(target_result["valid"]):
		return target_result
	var payload_result: Dictionary = V.require_type(value, "payload", TYPE_DICTIONARY)
	if not bool(payload_result["valid"]):
		return payload_result
	return V.ok()
