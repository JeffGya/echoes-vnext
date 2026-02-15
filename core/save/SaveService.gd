extends RefCounted

class_name SaveService

# SaveService owns persistence (file IO)
# It should stay UI-free and Node-free.

# Helper to make sure we log safely
static func _log_info(logger: StructuredLogger, t: int, type: String, msg: String, data: Dictionary) -> void:
	if logger == null:
		return
	if t < 0:
		return
	logger.info(t, type, msg, data)

static func make_new_save(root_seed: int, app_version: String = "vNext-dev") -> Dictionary:
	return SaveSchema.make_new_save(root_seed, app_version)

static func save_to_file(path: String, data: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:	# Crash-safe approach: write to temp file then rename.
	# Returns true on success, false on failure.
	ensure_save_dir_exists(path)
	
	var tmp_path := path + ".tmp"
	var json_text := JSON.stringify(data, "\t")
	
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveService] Failed to open temp save for writing: " + tmp_path)
		_log_info(logger, t, "save.write.fail", "Failed to open temp save for writing", {"path": path, "tmp_path": tmp_path})
		return false
		
	f.store_string(json_text)
	f.flush()
	f.close()
	
	# Best effort replace: remove existing file then rename temp into place.
	if FileAccess.file_exists(path):
		var err_remove := DirAccess.remove_absolute(path)
		if err_remove != OK:
			push_error("[SaveService] Failed to remove existing save: " + path + "( error code: " + str(err_remove) + ")" )
			_log_info(logger, t, "save.write.fail", "Failed to remove existing save", {"path": path, "error_code": err_remove})
			return false
	
	var err_rename := DirAccess.rename_absolute(tmp_path, path)
	if err_rename != OK:
		push_error("[SaveService] Failed to rename temp save to final: " + tmp_path + " -> " + path + " (error " + str(err_rename) + ")" )
		_log_info(logger, t, "save.write.fail", "Failed to rename temp save to final", {"path": path, "tmp_path": tmp_path, "error_code": err_rename})
		return false
	
	_log_info(logger, t, "save.write", "Saved to " + path, {
		"path": path,
		"schema_version": int(data.get("schema_version", 0))
	})
	return true

static func load_from_file(path: String, logger: StructuredLogger = null, t: int = -1) -> Dictionary:
	if not FileAccess.file_exists(path):
		_log_info(logger, t, "save.load", "No save found", {"path": path})
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveService] Failed to open save for reading: " + path)
		_log_info(logger, t, "save.load.fail", "Failed to open save for reading", {"path": path})
		return {}

	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(("[SaveService] Save file JSON did not parse into Dictionary: " + path))
		_log_info(logger, t, "save.load.fail", "Save JSON did not parse into Dictionary", {"path": path})
		return {}
		
	if not validate(parsed):
		_log_info(logger, t, "save.validate.fail", "Save validation failed", {"path": path})
		return {}
		
	_log_info(logger, t, "save.load", "Loaded save from path: " + path, {
	"path": path,
	"schema_version": int(parsed.get("schema_version", 0))
	})
	return parsed

static func ensure_save_dir_exists(path: String) -> void:
	# Ensure directory for an absolute path like "user://saves/slot_01.json".
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return 
	
	if DirAccess.dir_exists_absolute(dir_path):
		return
	
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("[SaveService] Failed to create save directory: " + dir_path + " (error code: " + str(err) + " )")
		
static func _has_dict_key(d: Dictionary, key:String) -> bool:
	return d.has(key) and d[key] != null
		
static func validate(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	# schema_version must exist and be supported
	if not data.has("schema_version"):
		push_error("[SaveService] Invalid save: missing schema_version")
		return false
		
	var v_raw = data["schema_version"]
	if typeof(v_raw) != TYPE_INT and typeof(v_raw) != TYPE_FLOAT:
		push_error("[SaveService] Invalid save: schema_version is not a number")
		return false
		
	var version := int(v_raw)
	if version != SaveSchema.SCHEMA_VERSION:
		push_error("[SaveService] Unsupported save schema_version: " + str(version))
		push_error("[SaveService] Expected schema_version: " + str(SaveSchema.SCHEMA_VERSION))
		return false
		
	# Required top-level keys
	for k in ["meta", "campaign", "flow", "sanctum"]:
		if not data.has(k) or typeof(data[k]) != TYPE_DICTIONARY:
			push_error("[SaveService] Invalid save: missing or invalid top-level key: " + k)
			return false
			
	# Required nested keys
	if not data["campaign"].has("root_seed"):
		push_error("[SaveService] Invalid save: missing campaign.root_seed")
		return false
		
	if not data["flow"].has("state"):
		push_error("[SaveService] invalid save: missing flow.state")
		return false
		
	return true
	
	
