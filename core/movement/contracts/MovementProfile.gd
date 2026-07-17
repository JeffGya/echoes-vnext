class_name MovementProfile
extends RefCounted

## Physical movement capability. Capacity zero is valid for structures.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const REQUIRED_FIELDS: Array = [
	"capacity",
	"source_terms",
	"controlling_state",
	"actor_kind",
	"authored_override",
]


static func build(
	capacity: int,
	source_terms: Array,
	controlling_state: bool,
	actor_kind: String,
	authored_override: Dictionary
) -> Dictionary:
	return {
		"capacity": capacity,
		"source_terms": source_terms.duplicate(true),
		"controlling_state": controlling_state,
		"actor_kind": actor_kind,
		"authored_override": authored_override.duplicate(true),
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	var capacity_result: Dictionary = V.require_capacity(value, "capacity")
	if not bool(capacity_result["valid"]):
		return capacity_result
	var source_result: Dictionary = V.require_array_of_dictionaries(value, "source_terms")
	if not bool(source_result["valid"]):
		return source_result
	var controlling_result: Dictionary = V.require_type(value, "controlling_state", TYPE_BOOL)
	if not bool(controlling_result["valid"]):
		return controlling_result
	var kind_result: Dictionary = V.require_non_empty_string(value, "actor_kind")
	if not bool(kind_result["valid"]):
		return kind_result
	var override_result: Dictionary = V.require_type(value, "authored_override", TYPE_DICTIONARY)
	if not bool(override_result["valid"]):
		return override_result
	var capacity: int = int(value["capacity"])
	var actor_kind: String = str(value["actor_kind"])
	var authored_override: Dictionary = value["authored_override"] as Dictionary
	if not authored_override.is_empty():
		var authored_fields: Dictionary = V.validate_exact_fields(authored_override, ["source", "capacity"])
		if not bool(authored_fields["valid"]):
			return V.failure(
				"invalid_authored_override.%s" % str(authored_fields["reason"]),
				"authored_override.%s" % str(authored_fields["field"])
			)
		var authored_source_result: Dictionary = V.require_non_empty_string(authored_override, "source")
		if not bool(authored_source_result["valid"]):
			return V.failure(str(authored_source_result["reason"]), "authored_override.source")
		var override_capacity_result: Dictionary = V.require_capacity(authored_override, "capacity")
		if not bool(override_capacity_result["valid"]):
			return V.failure(str(override_capacity_result["reason"]), "authored_override.capacity")
		if int(authored_override["capacity"]) != capacity:
			return V.failure("authored_override_capacity_mismatch", "authored_override.capacity")
	if actor_kind == "structure" and capacity != 0:
		return V.failure("structure_capacity_nonzero", "capacity")
	if actor_kind != "structure" and capacity == 0:
		return V.failure("zero_capacity_requires_structure", "capacity")
	if capacity == 1 and authored_override.is_empty():
		return V.failure("one_capacity_requires_authored_override", "authored_override")
	return V.ok()
