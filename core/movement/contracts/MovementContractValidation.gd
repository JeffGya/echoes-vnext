extends RefCounted

## Internal deterministic validation helpers shared by the movement contracts.
## Validation results always use the same stable shape:
## { "valid": bool, "reason": String, "field": String }.


static func ok() -> Dictionary:
	return {"valid": true, "reason": "", "field": ""}


static func failure(reason: String, field: String = "") -> Dictionary:
	return {"valid": false, "reason": reason, "field": field}


static func validate_exact_fields(value: Dictionary, required_fields: Array) -> Dictionary:
	for field_value: Variant in required_fields:
		var field: String = str(field_value)
		if not value.has(field):
			return failure("missing_field", field)
		if value[field] == null:
			return failure("null_field", field)

	var keys: Array = value.keys()
	keys.sort()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if not required_fields.has(key):
			return failure("unexpected_field", key)
	return ok()


static func require_type(value: Dictionary, field: String, expected_type: int) -> Dictionary:
	if typeof(value[field]) != expected_type:
		return failure("wrong_type", field)
	return ok()


static func require_number(value: Dictionary, field: String) -> Dictionary:
	if not (value[field] is int or value[field] is float):
		return failure("wrong_type", field)
	return ok()


static func require_finite_number(value: Dictionary, field: String) -> Dictionary:
	var number_result: Dictionary = require_number(value, field)
	if not bool(number_result["valid"]):
		return number_result
	if not is_finite(float(value[field])):
		return failure("non_finite_number", field)
	return ok()


static func require_unit_interval(value: Dictionary, field: String) -> Dictionary:
	var finite_result: Dictionary = require_finite_number(value, field)
	if not bool(finite_result["valid"]):
		return finite_result
	var number: float = float(value[field])
	if number < 0.0 or number > 1.0:
		return failure("number_out_of_range", field)
	return ok()


static func require_non_empty_string(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_STRING)
	if not bool(typed["valid"]):
		return typed
	if str(value[field]).is_empty():
		return failure("empty_string", field)
	return ok()


static func require_non_negative_int(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_INT)
	if not bool(typed["valid"]):
		return typed
	if int(value[field]) < 0:
		return failure("negative_value", field)
	return ok()


static func require_capacity(value: Dictionary, field: String) -> Dictionary:
	var non_negative: Dictionary = require_non_negative_int(value, field)
	if not bool(non_negative["valid"]):
		return non_negative
	if int(value[field]) > 6:
		return failure("capacity_exceeds_system_cap", field)
	return ok()


static func require_array_of_dictionaries(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_ARRAY)
	if not bool(typed["valid"]):
		return typed
	for item: Variant in value[field] as Array:
		if not item is Dictionary:
			return failure("wrong_item_type", field)
	return ok()


static func require_array_of_strings(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_ARRAY)
	if not bool(typed["valid"]):
		return typed
	for item: Variant in value[field] as Array:
		if not item is String:
			return failure("wrong_item_type", field)
	return ok()


static func canonical_string_array(values: Array) -> Array:
	var canonical: Array = []
	for value: Variant in values:
		var text: String = str(value)
		if not canonical.has(text):
			canonical.append(text)
	canonical.sort()
	return canonical


static func canonical_position_array(values: Array) -> Array:
	var canonical: Array = values.duplicate(true)
	canonical.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not a is Dictionary or not b is Dictionary:
			return str(a) < str(b)
		var a_position: Dictionary = a as Dictionary
		var b_position: Dictionary = b as Dictionary
		var a_col: int = int(a_position.get("col", 0))
		var b_col: int = int(b_position.get("col", 0))
		if a_col != b_col:
			return a_col < b_col
		return int(a_position.get("row", 0)) < int(b_position.get("row", 0))
	)
	var unique: Array = []
	for position_value: Variant in canonical:
		if not unique.has(position_value):
			unique.append(position_value)
	return unique


static func require_strictly_sorted_unique_strings(value: Dictionary, field: String) -> Dictionary:
	var strings_result: Dictionary = require_array_of_strings(value, field)
	if not bool(strings_result["valid"]):
		return strings_result
	var previous: String = ""
	var has_previous: bool = false
	for item: Variant in value[field] as Array:
		var current: String = str(item)
		if has_previous and current <= previous:
			return failure("not_strictly_sorted_unique", field)
		previous = current
		has_previous = true
	return ok()


static func require_position(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_DICTIONARY)
	if not bool(typed["valid"]):
		return typed
	return validate_position(value[field] as Dictionary, field)


static func validate_position(position: Dictionary, field: String) -> Dictionary:
	if position.size() != 2 or not position.has("col") or not position.has("row"):
		return failure("invalid_position", field)
	if not position["col"] is int or not position["row"] is int:
		return failure("invalid_position", field)
	return ok()


static func require_position_array(value: Dictionary, field: String) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_ARRAY)
	if not bool(typed["valid"]):
		return typed
	for item: Variant in value[field] as Array:
		if not item is Dictionary:
			return failure("wrong_item_type", field)
		var position_result: Dictionary = validate_position(item as Dictionary, field)
		if not bool(position_result["valid"]):
			return position_result
	return ok()


static func require_canonical_position_array(value: Dictionary, field: String, allow_empty: bool = true) -> Dictionary:
	var positions_result: Dictionary = require_position_array(value, field)
	if not bool(positions_result["valid"]):
		return positions_result
	var positions: Array = value[field] as Array
	if not allow_empty and positions.is_empty():
		return failure("empty_array", field)
	if positions != canonical_position_array(positions):
		return failure("not_canonical_position_array", field)
	return ok()


static func require_semantic_token(value: Dictionary, field: String, allow_empty: bool = false) -> Dictionary:
	var typed: Dictionary = require_type(value, field, TYPE_STRING)
	if not bool(typed["valid"]):
		return typed
	var token: String = str(value[field])
	if token.is_empty():
		if allow_empty:
			return ok()
		return failure("empty_string", field)
	if not is_semantic_token(token):
		return failure("invalid_semantic_token", field)
	return ok()


static func is_semantic_token(token: String) -> bool:
	if token.is_empty():
		return false
	for index: int in range(token.length()):
		var code: int = token.unicode_at(index)
		var valid: bool = (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or code == 95
			or code == 46
		)
		if not valid:
			return false
	return true


static func canonical_cell_key(position: Dictionary) -> String:
	return "%d,%d" % [int(position.get("col", 0)), int(position.get("row", 0))]


static func parse_canonical_cell_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",", false)
	if parts.size() != 2:
		return {}
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {}
	var position: Dictionary = {"col": int(parts[0]), "row": int(parts[1])}
	if canonical_cell_key(position) != key:
		return {}
	return position


static func require_path_excludes_origin(path: Array, origin: Dictionary, field: String) -> Dictionary:
	if origin.is_empty():
		return ok()
	var origin_result: Dictionary = validate_position(origin, "origin")
	if not bool(origin_result["valid"]):
		return origin_result
	for cell_value: Variant in path:
		if cell_value is Dictionary and (cell_value as Dictionary) == origin:
			return failure("path_includes_origin", field)
	return ok()
