class_name JsonFileLoader
# Loads JSON config files from disk and return parsed Dictionaries.
# Determinism: no OS time, no unchecked randomness. Log use injected tick

extends RefCounted

static func load_dict(path: String, logger: StructuredLogger = null, t: int = -1) -> Dictionary:
	# 1. Existence check
	if not FileAccess.file_exists(path):
		_log_fail(logger, t, path, "File does not exist")
		return {}
	
	# 2. Open
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_log_fail(logger, t, path, "Failed to open file for reading")
		return {}
		
	# 3. Read and parse
	var text := f.get_as_text()
	f.close()
	
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_log_fail(logger, t, path, "Invalid JSON")
		
	# 4. Root type check (Must be Dictionary)
	if typeof(parsed) != TYPE_DICTIONARY:
		_log_fail(logger, t, path, "Root is not Dictionary")
		return {}
		
	_log_ok(logger, t, path)
	return parsed
	
static func _log_ok(logger: StructuredLogger, t: int, path: String) -> void:
	if logger == null or t < 0:
		return
	logger.debug(t, "config.load", "Loaded config from path: " + path, {"path": path})

static func _log_fail(logger: StructuredLogger, t: int, path: String, reason: String) -> void:
	if logger == null or t < 0:
		return
	logger.debug(t, "config.load.fail", "Failed to load config: " + reason + " (" + path + ")", {
		"path": path,
		"reason": reason
	})
