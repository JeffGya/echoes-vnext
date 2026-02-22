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
	
	var repaired := _apply_additive_defaults_and_repairs(parsed, logger, t)
	if repaired:
		save_to_file(path, parsed, logger, t)
	
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
		
static func _apply_additive_defaults_and_repairs(save: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	if save == null or save.is_empty():
		return false
		
	var repaired := false
	var repaired_notes: Array = []
	var now_unix := int(Time.get_unix_time_from_system())
	
	# Make sure economy dictionary exists
	if not save.has("economy") or typeof(save["economy"]) != TYPE_DICTIONARY:
		# Legacy backfill is removed. sanctum.ase is properly ignored from now on.
		save["economy"] = {
			"ase": 0,
			"ekwan": 0,

			# ECONOMY-002 guards
			"last_settle_unix": now_unix,
			"last_offline_unix": now_unix
		}
		repaired = true
		repaired_notes.append("economy added (ase defaulted to 0) + added accrual guard timestamps")
		
	var econ : Dictionary = save["economy"]
	
	# Make sure ase exist as an int
	if not econ.has("ase") or (typeof(econ["ase"]) != TYPE_INT and typeof(econ["ase"]) != TYPE_FLOAT):
		econ["ase"] = 0
		repaired = true
		repaired_notes.append("economy.ase set to int default")
	
	# Makes sure ekwan exists as an int
	if not econ.has("ekwan") or (typeof(econ["ekwan"]) != TYPE_INT and typeof(econ["ekwan"]) != TYPE_FLOAT):
		econ["ekwan"] = 0
		repaired = true
		repaired_notes.append("economy.ekwan set to int default")
	
	# Make sure last_settle_unix exists
	if not econ.has("last_settle_unix"):
		econ["last_settle_unix"] = now_unix
		repaired = true
		repaired_notes.append("economy.last_settle_unix set to unix default")
	else:
		var v = econ["last_settle_unix"]
		var vi := int(v)
		if typeof(v) == TYPE_FLOAT:
			# Only repair if the float is not already an integer value (i.e., has decimals)
			if v != float(vi):
				econ["last_settle_unix"] = vi
				repaired = true
				repaired_notes.append("economy.last_settle_unix normalized float->int (fractional)")
		elif typeof(v) != TYPE_INT:
			econ["last_settle_unix"] = vi
			repaired = true
			repaired_notes.append("economy.last_settle_unix repaired invalid type")
	
	# Make sure last_offline_unix exists
	if not econ.has("last_offline_unix"):
		econ["last_offline_unix"] = now_unix
		repaired = true
		repaired_notes.append("economy.last_offline_unix set to unix default")
	else:
		var v = econ["last_offline_unix"]
		var vi := int(v)
		if typeof(v) == TYPE_FLOAT:
			# Only repair if the float is not already an integer value (i.e., has decimals)
			if v != float(vi):
				econ["last_offline_unix"] = vi
				repaired = true
				repaired_notes.append("economy.last_offline_unix normalized float->int (fractional)")
		elif typeof(v) != TYPE_INT:
			econ["last_offline_unix"] = vi
			repaired = true
			repaired_notes.append("economy.last_offline_unix repaired invalid type")
		
	# ---- Sanctum repairs (SANCTUM-001) ----
	if not save.has("sanctum") or typeof(save["sanctum"]) != TYPE_DICTIONARY:
		save["sanctum"] = {
			# NOTE: sanctum.ase is legacy and ignored.
			"ase": 0,
			"roster": [],
			"active_party_ids": [],
			"name": "",
			"name_roll_index": 0
		}
		repaired = true
		repaired_notes.append("sanctum added (roster + active_party_ids defaults; sanctum.ase legacy ignored)")
	else:
		var sanctum: Dictionary = save["sanctum"]

		if not sanctum.has("roster") or not (sanctum["roster"] is Array):
			sanctum["roster"] = []
			repaired = true
			repaired_notes.append("sanctum.roster set to array default")

		if not sanctum.has("active_party_ids") or not (sanctum["active_party_ids"] is Array):
			sanctum["active_party_ids"] = []
			repaired = true
			repaired_notes.append("sanctum.active_party_ids set to array default")
		
		if not sanctum.has("name") or typeof(sanctum["name"]) != TYPE_STRING:
			sanctum["name"] = ""
			repaired = true
			repaired_notes.append("sanctum.name set to string default")

		if not sanctum.has("name_roll_index") or (typeof(sanctum["name_roll_index"]) != TYPE_INT and typeof(sanctum["name_roll_index"]) != TYPE_FLOAT):
			sanctum["name_roll_index"] = 0
			repaired = true
			repaired_notes.append("sanctum.name_roll_index set to int default")
		else:
			# normalize float->int if needed
			sanctum["name_roll_index"] = int(sanctum["name_roll_index"])
	
	
	# Get structured log if anything was repaired (uses injected t)
	if repaired:
		_log_info(logger, t, "save.schema.repair", "Applied additive save schema repairs", {
			"notes": repaired_notes,
			"schema_version": int(save.get("schema_version", 0))
		})
		
	return repaired
	
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
	for k in ["meta", "campaign", "flow", "sanctum", "economy"]:
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
