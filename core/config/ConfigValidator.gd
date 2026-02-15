class_name ConfigValidator
# Validates config dictionaries against expected schema versions and structures.

extends RefCounted

# Shared failure logger
static func _fail(logger: StructuredLogger, t: int, context: String, reason: String, data: Dictionary = {}) -> bool:
	if logger != null and t >= 0:
		var payload := {"context": context, "reason": reason}
		for k in data.keys():
			payload[k] = data[k]
		logger.debug(t, "config.validate.fail", "Config validation failed: " + reason, payload)
	return false

# Helpers logging mistakes
static func _require_key(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not dict.has(key):
		return _fail(logger, t, context, "Missing required key:" + key)
	return true

static func _require_int(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not _require_key(dict, key, context, logger, t):
		return false
	
	var v = dict[key]
	var vt := typeof(v)
	
	if vt == TYPE_INT:
		return true
		
	# Godot JSON sometimes parses numbers as float; accept 1.0 but reject 1.5
	if vt == TYPE_FLOAT:
		if float(v) == float(int(v)):
			return true
		return _fail(logger, t, context, "Key is float but not whole number: " + key, {"key": key, "value": v})
	
	return _fail(logger, t, context, "Key is not int: " + key, {"key": key, "type":vt}) 

static func _require_dict(dict: Dictionary, key: String, context: String, logger: StructuredLogger, t: int) -> bool:
	if not _require_key(dict, key, context, logger, t):
		return false
	if typeof(dict[key]) != TYPE_DICTIONARY:
		return _fail(logger, t, context, "Key is not Dictionary: " + key, {"key": key, "type": typeof(dict[key])})
	return true
	
# Core validator
static func validate_root(root: Dictionary, expected_schema_version: int, context: String, logger: StructuredLogger = null, t: int = -1) -> bool:
	# root must have schema_version:int and data:Dictionary
	if not _require_int(root, "schema_version", context, logger, t):
		return false
	if int(root["schema_version"]) != expected_schema_version:
		return _fail(logger, t, context, "Unsupported schema_version", {
			"schema_version": int(root["schema_version"]),
			"expected": expected_schema_version
		})
	if not _require_dict(root, "data", context, logger, t):
		return false
	
	if logger != null and t >= 0:
		logger.debug(t, "config.validate", "Config validation OK", {
			"context": context,
			"schema_version": expected_schema_version
		})
	return true
	
# Thin wrappers per config
static func validate_balance(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "balance", logger, t)
	
static func validate_actors(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "actors", logger, t)

static func validate_realms(root: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	return validate_root(root, 1, "realms", logger, t)
