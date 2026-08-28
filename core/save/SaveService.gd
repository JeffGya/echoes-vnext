extends RefCounted

class_name SaveService

const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001

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

const LOAD_LOADED := "loaded"
const LOAD_RECOVERED := "recovered"
const LOAD_MISSING := "missing"
const LOAD_ERROR := "error"

static func save_to_file(path: String, data: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	# Transactional snapshot write. Alternating pending slots are distinct from the
	# recoverable legacy `.tmp`; the newest valid pending slot is never overwritten.
	if not validate(data):
		_log_info(logger, t, "save.write.fail", "Refused to write invalid save data", {"path": path})
		return false

	ensure_save_dir_exists(path)
	var candidate: Dictionary = data.duplicate(true)
	var meta_v: Variant = candidate.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	var generation: int = max(_get_generation(candidate), _highest_valid_generation(path)) + 1
	meta["save_generation"] = generation
	meta["last_saved_at_unix"] = int(Time.get_unix_time_from_system())
	candidate["meta"] = meta

	var pending_path := _select_pending_write_path(path)
	if not _write_json(pending_path, candidate):
		_log_info(logger, t, "save.write.fail", "Failed to write temporary save", {
			"path": path,
			"pending_path": pending_path,
			"generation": generation,
		})
		return false

	var verified_pending := _read_candidate(pending_path, "pending", 4)
	if not bool(verified_pending.get("valid", false)) or int(verified_pending.get("generation", -1)) != generation:
		_log_info(logger, t, "save.write.fail", "Temporary save verification failed", {
			"path": path,
			"pending_path": pending_path,
			"generation": generation,
			"reason": str(verified_pending.get("reason", "unknown")),
		})
		return false

	# Rotate oldest to newest. Invalid artifacts are never promoted into the chain.
	if not _rotate_valid_artifact(path + ".bak2", path + ".bak3", "bak2"):
		return _log_rotation_failure(logger, t, path, "bak2", generation)
	if not _rotate_valid_artifact(path + ".bak1", path + ".bak2", "bak1"):
		return _log_rotation_failure(logger, t, path, "bak1", generation)
	if not _rotate_valid_artifact(path, path + ".bak1", "primary"):
		return _log_rotation_failure(logger, t, path, "primary", generation)
	if not _archive_invalid_primary(path):
		return _log_rotation_failure(logger, t, path, "invalid_primary", generation)

	if not _replace_with_rename(pending_path, path):
		_log_info(logger, t, "save.write.fail", "Failed to promote verified temporary save", {
			"path": path,
			"pending_path": pending_path,
			"generation": generation,
		})
		return false

	# A legacy/interrupted `.tmp` is obsolete only after the newer primary exists.
	_remove_artifact_if_present(path + ".pending_a")
	_remove_artifact_if_present(path + ".pending_b")
	_remove_artifact_if_present(path + ".tmp")

	# Publish committed metadata back to the authoritative in-memory dictionary.
	data["meta"] = meta.duplicate(true)
	_log_info(logger, t, "save.write", "Saved transactional snapshot", {
		"path": path,
		"schema_version": int(data.get("schema_version", 0)),
		"generation": generation,
	})
	return true

static func load_from_file(path: String, logger: StructuredLogger = null, t: int = -1) -> Dictionary:
	var artifacts := _artifact_paths(path)
	var valid_candidates: Array = []
	var diagnostics: Array = []
	var any_exists := false

	for artifact_v in artifacts:
		var artifact: Dictionary = artifact_v
		var candidate := _read_candidate(
			str(artifact.get("path", "")),
			str(artifact.get("source", "")),
			int(artifact.get("priority", 0))
		)
		if bool(candidate.get("exists", false)):
			any_exists = true
		if bool(candidate.get("valid", false)):
			valid_candidates.append(candidate)
		elif bool(candidate.get("exists", false)):
			diagnostics.append({
				"source": candidate.get("source", ""),
				"path": candidate.get("path", ""),
				"reason": candidate.get("reason", "invalid"),
			})

	if valid_candidates.is_empty():
		if not any_exists:
			_log_info(logger, t, "save.load", "No save artifacts found", {"path": path})
			return _load_result(LOAD_MISSING, {}, "", -1, diagnostics, false)
		_log_info(logger, t, "save.load.fail", "No valid save generation found", {
			"path": path,
			"diagnostics": diagnostics,
		})
		return _load_result(LOAD_ERROR, {}, "", -1, diagnostics, false)

	valid_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var generation_a := int(a.get("generation", 0))
		var generation_b := int(b.get("generation", 0))
		if generation_a != generation_b:
			return generation_a > generation_b
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)

	var selected: Dictionary = valid_candidates[0]
	var selected_data: Dictionary = (selected.get("data", {}) as Dictionary).duplicate(true)
	var source := str(selected.get("source", ""))
	var recovered := source != "primary"
	var repaired := _apply_additive_defaults_and_repairs(selected_data, logger, t)
	repaired = repaired or bool(selected.get("repaired", false))
	var persist_ok := true
	if recovered or repaired:
		persist_ok = save_to_file(path, selected_data, logger, t)

	var status := LOAD_RECOVERED if recovered else LOAD_LOADED
	var generation := _get_generation(selected_data)
	_log_info(logger, t, "save.load", "Loaded validated save generation", {
		"path": path,
		"source": source,
		"generation": generation,
		"recovered": recovered,
		"repair_persisted": persist_ok,
	})
	return _load_result(status, selected_data, source, generation, diagnostics, not persist_ok)

static func _load_result(
	status: String,
	data: Dictionary,
	source: String,
	generation: int,
	diagnostics: Array,
	needs_save_retry: bool
) -> Dictionary:
	return {
		"status": status,
		"data": data,
		"source": source,
		"generation": generation,
		"diagnostics": diagnostics,
		"needs_save_retry": needs_save_retry,
	}

static func _artifact_paths(path: String) -> Array:
	return [
		{"path": path, "source": "primary", "priority": 6},
		{"path": path + ".pending_a", "source": "pending_a", "priority": 5},
		{"path": path + ".pending_b", "source": "pending_b", "priority": 4},
		{"path": path + ".tmp", "source": "tmp", "priority": 3},
		{"path": path + ".bak1", "source": "bak1", "priority": 2},
		{"path": path + ".bak2", "source": "bak2", "priority": 1},
		{"path": path + ".bak3", "source": "bak3", "priority": 0},
	]

static func _select_pending_write_path(path: String) -> String:
	var pending_a := _read_candidate(path + ".pending_a", "pending_a", 5)
	var pending_b := _read_candidate(path + ".pending_b", "pending_b", 4)
	if not bool(pending_a.get("valid", false)):
		return path + ".pending_a"
	if not bool(pending_b.get("valid", false)):
		return path + ".pending_b"
	if int(pending_a.get("generation", 0)) <= int(pending_b.get("generation", 0)):
		return path + ".pending_a"
	return path + ".pending_b"

static func _read_candidate(path: String, source: String, priority: int) -> Dictionary:
	var result := {
		"path": path,
		"source": source,
		"priority": priority,
		"exists": FileAccess.file_exists(path),
		"valid": false,
		"generation": -1,
		"data": {},
		"reason": "missing",
	}
	if not bool(result["exists"]):
		return result

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		result["reason"] = "open_failed"
		return result
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		result["reason"] = "json_invalid"
		return result
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		result["reason"] = "json_invalid"
		return result
	var parsed_dict: Dictionary = parsed
	if not parsed_dict.has("schema_version"):
		result["reason"] = "schema_invalid"
		return result
	var schema_version_v: Variant = parsed_dict["schema_version"]
	if typeof(schema_version_v) != TYPE_INT and typeof(schema_version_v) != TYPE_FLOAT:
		result["reason"] = "schema_invalid"
		return result
	if int(schema_version_v) != SaveSchema.SCHEMA_VERSION:
		result["reason"] = "schema_invalid"
		return result
	var repaired_candidate: Dictionary = parsed_dict.duplicate(true)
	var repair_logger := StructuredLogger.new()
	repair_logger.set_level("off")
	var repaired := _apply_additive_defaults_and_repairs(repaired_candidate, repair_logger)
	if not validate(repaired_candidate, false):
		result["reason"] = "schema_invalid"
		return result
	result["valid"] = true
	result["generation"] = _get_generation(repaired_candidate)
	result["data"] = repaired_candidate
	result["repaired"] = repaired
	result["reason"] = ""
	return result

static func _get_generation(data: Dictionary) -> int:
	var meta_v: Variant = data.get("meta", {})
	var meta: Dictionary = meta_v if meta_v is Dictionary else {}
	return max(0, int(meta.get("save_generation", 0)))

static func _highest_valid_generation(path: String) -> int:
	var highest := -1
	for artifact_v in _artifact_paths(path):
		var artifact: Dictionary = artifact_v
		var candidate := _read_candidate(
			str(artifact.get("path", "")),
			str(artifact.get("source", "")),
			int(artifact.get("priority", 0))
		)
		if bool(candidate.get("valid", false)):
			highest = max(highest, int(candidate.get("generation", 0)))
	return highest

static func _write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	return true

static func _rotate_valid_artifact(source_path: String, destination_path: String, source: String) -> bool:
	var candidate := _read_candidate(source_path, source, 0)
	if not bool(candidate.get("exists", false)):
		return true
	if not bool(candidate.get("valid", false)):
		return true
	return _replace_with_rename(source_path, destination_path)

static func _archive_invalid_primary(path: String) -> bool:
	var candidate := _read_candidate(path, "primary", 0)
	if not bool(candidate.get("exists", false)) or bool(candidate.get("valid", false)):
		return true
	return _replace_with_rename(path, path + ".corrupt")

static func _replace_with_rename(source_path: String, destination_path: String) -> bool:
	var source_abs := ProjectSettings.globalize_path(source_path)
	var destination_abs := ProjectSettings.globalize_path(destination_path)
	if FileAccess.file_exists(destination_path):
		var remove_error := DirAccess.remove_absolute(destination_abs)
		if remove_error != OK:
			return false
	return DirAccess.rename_absolute(source_abs, destination_abs) == OK

static func _remove_artifact_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _log_rotation_failure(
	logger: StructuredLogger,
	t: int,
	path: String,
	artifact: String,
	generation: int
) -> bool:
	_log_info(logger, t, "save.write.fail", "Failed to rotate validated save artifact", {
		"path": path,
		"artifact": artifact,
		"generation": generation,
	})
	return false

static func ensure_save_dir_exists(path: String) -> void:
	# Ensure directory for an absolute path like "user://saves/slot_01.json".
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return 
	var dir_path_abs := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(dir_path_abs):
		return
	var err := DirAccess.make_dir_recursive_absolute(dir_path_abs)
	if err != OK:
		push_error("[SaveService] Failed to create save directory: " + dir_path + " (error code: " + str(err) + " )")
		
static func _has_dict_key(d: Dictionary, key:String) -> bool:
	return d.has(key) and d[key] != null

static func _starter_occupants_need_repair(sanctum: Dictionary) -> bool:
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var occupants_v: Variant = sanctum.get("occupants", [])
	var occupants: Array = occupants_v if occupants_v is Array else []
	var expected_ids: Dictionary = {"ase_flame": true}
	for echo_v in roster:
		if echo_v is Dictionary:
			var echo_id := str((echo_v as Dictionary).get("id", ""))
			if not echo_id.is_empty():
				expected_ids[echo_id] = true
	var institutions_v: Variant = sanctum.get("institutions", {})
	var institutions: Dictionary = institutions_v if institutions_v is Dictionary else {}
	for institution_id in institutions:
		var institution_v: Variant = institutions.get(institution_id, {})
		if institution_v is Dictionary and bool((institution_v as Dictionary).get("unlocked", false)):
			expected_ids[str(institution_id)] = true
	if occupants.size() != expected_ids.size():
		return true
	var found_ids: Dictionary = {}
	for occupant_v in occupants:
		if not (occupant_v is Dictionary):
			return true
		var occupant: Dictionary = occupant_v
		var occupant_id := str(occupant.get("id", ""))
		if not expected_ids.has(occupant_id) or found_ids.has(occupant_id):
			return true
		if occupant_id == "ase_flame" and (
			int(occupant.get("x", 99)) != 0 or int(occupant.get("y", 99)) != 0
		):
			return true
		found_ids[occupant_id] = true
	return found_ids.size() != expected_ids.size()
		
static func _apply_additive_defaults_and_repairs(save: Dictionary, logger: StructuredLogger = null, t: int = -1) -> bool:
	if save == null or save.is_empty():
		return false
		
	var repaired := false
	var repaired_notes: Array = []
	var now_unix := int(Time.get_unix_time_from_system())
	
	# ---- Campaign repairs (SANCTUM-002) ----
	if not save.has("campaign") or typeof(save["campaign"]) != TYPE_DICTIONARY:
		# Deterministic repair only (no randomness). If we can, derive repair seed from created_at_unix.
		var repair_seed := "DEFAULT_SEED"
		if save.has("meta") and typeof(save["meta"]) == TYPE_DICTIONARY:
			var meta: Dictionary = save["meta"]
			if meta.has("created_at_unix") and (typeof(meta["created_at_unix"]) == TYPE_INT or typeof(meta["created_at_unix"]) == TYPE_FLOAT):
				repair_seed = "repair:%d:%d" % [int(meta["created_at_unix"]), int(save.get("schema_version", 0))]
				
		save["campaign"] = {
			"root_seed": 0, # legacy
			"tick": 0,
			"seed_root": repair_seed,
			"seed_source": "repair"
		}
		repaired = true
		repaired_notes.append("campaign added (seed_root/seed_source repaired)")
	else:
		var camp: Dictionary = save["campaign"]
		
		# Ensure legacy root_seed exists and is numeric
		if not camp.has("root_seed") or (typeof(camp["root_seed"]) != TYPE_INT and typeof(camp["root_seed"]) != TYPE_FLOAT):
			camp["root_seed"] = 0
			repaired = true
			repaired_notes.append("campaign.root_seed set to int default")
			
		# Ensure tick exists
		if not camp.has("tick") or (typeof(camp["tick"]) != TYPE_INT and typeof(camp["tick"]) != TYPE_FLOAT):			
			camp["tick"] = 0
			repaired = true
			repaired_notes.append("campaign.tick set to int default")
		else:
			camp["tick"] = int(camp["tick"])
			
		# Ensure seed_source exists
		if not camp.has("seed_source") or typeof(camp["seed_source"]) != TYPE_STRING or str(camp["seed_source"]).is_empty():
			camp["seed_source"] = "repair"
			repaired = true
			repaired_notes.append("campaign.seed_source set to string default")
			
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
		
	# V2-SANCTUM-001: emotion recovery settlement timestamp
	if not econ.has("last_emotion_settle_unix"):
		econ["last_emotion_settle_unix"] = now_unix
		repaired = true
		repaired_notes.append("economy.last_emotion_settle_unix set to unix default")
	else:
		var _esv = econ["last_emotion_settle_unix"]
		var _esvi := int(_esv)
		if typeof(_esv) == TYPE_FLOAT:
			if _esv != float(_esvi):
				econ["last_emotion_settle_unix"] = _esvi
				repaired = true
				repaired_notes.append("economy.last_emotion_settle_unix normalized float->int")
		elif typeof(_esv) != TYPE_INT:
			econ["last_emotion_settle_unix"] = _esvi
			repaired = true
			repaired_notes.append("economy.last_emotion_settle_unix repaired invalid type")

	# ---- Economy V2 stubs (V2-MIG-002) ----
	if not econ.has("relics") or (typeof(econ["relics"]) != TYPE_INT and typeof(econ["relics"]) != TYPE_FLOAT):
		econ["relics"] = 0
		repaired = true
		repaired_notes.append("economy.relics set to 0 (V2 stub)")
	if not econ.has("faith") or (typeof(econ["faith"]) != TYPE_INT and typeof(econ["faith"]) != TYPE_FLOAT):
		econ["faith"] = 0
		repaired = true
		repaired_notes.append("economy.faith set to 0 (V2 stub)")
	if not econ.has("harmony") or (typeof(econ["harmony"]) != TYPE_INT and typeof(econ["harmony"]) != TYPE_FLOAT):
		econ["harmony"] = 0
		repaired = true
		repaired_notes.append("economy.harmony set to 0 (V2 stub)")
	if not econ.has("favor") or (typeof(econ["favor"]) != TYPE_INT and typeof(econ["favor"]) != TYPE_FLOAT):
		econ["favor"] = 0
		repaired = true
		repaired_notes.append("economy.favor set to 0 (V2 stub)")

	# ---- Flow repairs (V2-INFRA-003 Phase 8 groundwork) ----
	# save.flow already exists as {state, context} in every save written by make_new_save
	# and is otherwise never touched. Add pending_result beside the existing keys; never
	# remove or overwrite state/context.
	if not save.has("flow") or typeof(save["flow"]) != TYPE_DICTIONARY:
		save["flow"] = {
			"state": "flow.splash",
			"context": {},
			"pending_result": {},
		}
		repaired = true
		repaired_notes.append("flow added with defaults (state/context/pending_result)")
	else:
		var flow: Dictionary = save["flow"]
		if not flow.has("pending_result") or typeof(flow["pending_result"]) != TYPE_DICTIONARY:
			flow["pending_result"] = {}
			repaired = true
			repaired_notes.append("flow.pending_result set to {} default (V2-INFRA-003 stub)")

	# ---- Onboarding repairs (Chapter I) ----
	if not save.has("onboarding") or typeof(save["onboarding"]) != TYPE_DICTIONARY:
		save["onboarding"] = {
			"chapter_one_complete": false,
			"chapter_one_step": "invocation",
			"fragment_options": [],
			"heard_fragments": [],
			"selected_fragment": "",
			"name_options": [],
			"keeper_intro_complete": false,
			"keeper_intro_step": "",
			"keeper_trial_phase": "ready",
			"keeper_trial_rewind_used": false,
			"first_thread_id": "",
			"first_trial_rewards_granted": false,
			"awakening_choice": "",
			"opening_realm_id": "",
			"opening_realm_status": "locked",
		}
		repaired = true
		repaired_notes.append("onboarding added (Chapter I defaults)")
	else:
		var onboarding: Dictionary = save["onboarding"]
		if not onboarding.has("chapter_one_complete") or typeof(onboarding["chapter_one_complete"]) != TYPE_BOOL:
			onboarding["chapter_one_complete"] = false
			repaired = true
			repaired_notes.append("onboarding.chapter_one_complete set to false")
		if not onboarding.has("chapter_one_step") or typeof(onboarding["chapter_one_step"]) != TYPE_STRING:
			onboarding["chapter_one_step"] = "invocation"
			repaired = true
			repaired_notes.append("onboarding.chapter_one_step set to invocation")
		if not onboarding.has("fragment_options") or not (onboarding["fragment_options"] is Array):
			onboarding["fragment_options"] = []
			repaired = true
			repaired_notes.append("onboarding.fragment_options set to []")
		if not onboarding.has("heard_fragments") or not (onboarding["heard_fragments"] is Array):
			onboarding["heard_fragments"] = []
			repaired = true
			repaired_notes.append("onboarding.heard_fragments set to []")
		if not onboarding.has("selected_fragment") or typeof(onboarding["selected_fragment"]) != TYPE_STRING:
			onboarding["selected_fragment"] = ""
			repaired = true
			repaired_notes.append("onboarding.selected_fragment set to empty")
		if not onboarding.has("name_options") or not (onboarding["name_options"] is Array):
			onboarding["name_options"] = []
			repaired = true
			repaired_notes.append("onboarding.name_options set to []")
		if not onboarding.has("keeper_intro_complete") or typeof(onboarding["keeper_intro_complete"]) != TYPE_BOOL:
			onboarding["keeper_intro_complete"] = bool(onboarding.get("chapter_one_complete", false))
			repaired = true
			repaired_notes.append("onboarding.keeper_intro_complete backfilled")
		if not onboarding.has("keeper_intro_step") or typeof(onboarding["keeper_intro_step"]) != TYPE_STRING:
			onboarding["keeper_intro_step"] = "complete" if bool(onboarding.get("keeper_intro_complete", false)) else ""
			repaired = true
			repaired_notes.append("onboarding.keeper_intro_step backfilled")
		if not onboarding.has("keeper_trial_phase") or typeof(onboarding["keeper_trial_phase"]) != TYPE_STRING:
			onboarding["keeper_trial_phase"] = "ready"
			repaired = true
			repaired_notes.append("onboarding.keeper_trial_phase set to ready")
		if not onboarding.has("keeper_trial_rewind_used") or typeof(onboarding["keeper_trial_rewind_used"]) != TYPE_BOOL:
			onboarding["keeper_trial_rewind_used"] = false
			repaired = true
			repaired_notes.append("onboarding.keeper_trial_rewind_used set to false")
		if not onboarding.has("first_thread_id") or typeof(onboarding["first_thread_id"]) != TYPE_STRING:
			onboarding["first_thread_id"] = ""
			repaired = true
			repaired_notes.append("onboarding.first_thread_id set to empty")
		if not onboarding.has("first_trial_rewards_granted") or typeof(onboarding["first_trial_rewards_granted"]) != TYPE_BOOL:
			onboarding["first_trial_rewards_granted"] = false
			repaired = true
			repaired_notes.append("onboarding.first_trial_rewards_granted set to false")
		if not onboarding.has("awakening_choice") or typeof(onboarding["awakening_choice"]) != TYPE_STRING:
			onboarding["awakening_choice"] = ""
			repaired = true
			repaired_notes.append("onboarding.awakening_choice set to empty")
		# V2-INFRA-003 Phase 8 groundwork: opening-realm gating fields (additive stub).
		if not onboarding.has("opening_realm_id") or typeof(onboarding["opening_realm_id"]) != TYPE_STRING:
			onboarding["opening_realm_id"] = ""
			repaired = true
			repaired_notes.append("onboarding.opening_realm_id set to empty default")
		if not onboarding.has("opening_realm_status") or typeof(onboarding["opening_realm_status"]) != TYPE_STRING:
			onboarding["opening_realm_status"] = "locked"
			repaired = true
			repaired_notes.append("onboarding.opening_realm_status set to 'locked' default")

	# ---- Sanctum repairs (SANCTUM-001) ----
	if not save.has("sanctum") or typeof(save["sanctum"]) != TYPE_DICTIONARY:
		save["sanctum"] = {
			# NOTE: sanctum.ase is legacy and ignored.
			"ase": 0,
			"roster": [],
			"active_party_ids": [],
			"summon_count": 0,
			"name": "",
			"name_roll_index": 0,
			"starter_granted": false,
			"layout": SanctumLayoutService.make_starter_layout(),
			"occupants": [],
			"bonds": [],
			"party_encounters": [],
			"rival_incidents": [],
			"companion_invite": {},
			"ase_flame": {
				"awakened": false,
				"boost_remaining_seconds": 0,
				"boost_per_bank_tick": 0,
			},
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
	
		# SANCTUM-002: starter summon gating flag
		if not sanctum.has("starter_granted") or typeof(sanctum["starter_granted"]) != TYPE_BOOL:
			sanctum["starter_granted"] = false
			repaired = true
			repaired_notes.append("sanctum.starter_granted set to bool default")
	
		# SANCTUM-002: summon_count default (stable index for seed paths)
		if not sanctum.has("summon_count") or (typeof(sanctum["summon_count"]) != TYPE_INT and typeof(sanctum["summon_count"]) != TYPE_FLOAT):
			sanctum["summon_count"] = 0
			repaired = true
			repaired_notes.append("sanctum.summon_count set to int default")
		else:
			sanctum["summon_count"] = int(sanctum["summon_count"])

		if not sanctum.has("layout") or not (sanctum["layout"] is Dictionary):
			sanctum["layout"] = SanctumLayoutService.make_starter_layout()
			repaired = true
			repaired_notes.append("sanctum.layout set to starter 3x3 diamond default")
		else:
			var layout: Dictionary = sanctum["layout"]
			if not layout.has("tiles") or not (layout["tiles"] is Array) or (layout["tiles"] as Array).is_empty():
				sanctum["layout"] = SanctumLayoutService.make_starter_layout()
				repaired = true
				repaired_notes.append("sanctum.layout repaired to starter 3x3 diamond default")
			elif not layout.has("version") or (typeof(layout["version"]) != TYPE_INT and typeof(layout["version"]) != TYPE_FLOAT):
				sanctum["layout"] = SanctumLayoutService.make_starter_layout()
				repaired = true
				repaired_notes.append("sanctum.layout repaired to current starter version")
			else:
				layout["version"] = int(layout["version"])
				if int(layout["version"]) < SanctumLayoutService.LAYOUT_VERSION:
					sanctum["layout"] = SanctumLayoutService.make_starter_layout()
					repaired = true
					repaired_notes.append("sanctum.layout migrated to starter 3x3 diamond")
			if not (sanctum["layout"] as Dictionary).has("origin") or not ((sanctum["layout"] as Dictionary)["origin"] is Dictionary):
				(sanctum["layout"] as Dictionary)["origin"] = { "x": 0, "y": 0 }
				repaired = true
				repaired_notes.append("sanctum.layout.origin set to center default")

		if not sanctum.has("occupants") or not (sanctum["occupants"] is Array):
			sanctum["occupants"] = []
			repaired = true
			repaired_notes.append("sanctum.occupants set to array default")

		# V2-STAGE-004 Phase 4 (S14 redesign): earned-return companion invite — a one-slot
		# Sanctum inbox surfaced by FlowSanctumState on entry until the player accepts
		# (sanctum.companion.accept) or declines (sanctum.companion.decline). {} = none pending.
		if not sanctum.has("companion_invite") or not (sanctum["companion_invite"] is Dictionary):
			sanctum["companion_invite"] = {}
			repaired = true
			repaired_notes.append("sanctum.companion_invite set to dict default")

		# SANCTUM-002: roster item additive repairs (Echo placeholder contract)
		# Keep deterministic: no RNG, no OS time; only defaults + key migrations.

		# V2-PROG-003: load vec_cfg once for vector backfill inside the echo loop.
		var _balance_for_repair := JsonFileLoader.load_dict(ConfigService.PATH_BALANCE)
		var _vec_cfg: Dictionary = {}
		var _vc_v: Variant = _balance_for_repair.get("data", {}).get("vectors", {})
		if typeof(_vc_v) == TYPE_DICTIONARY:
			_vec_cfg = _vc_v

		var roster: Array = sanctum.get("roster", [])
		for i in range(roster.size()):
			var item = roster[i]
			if typeof(item) != TYPE_DICTIONARY:
				# If something weird got into the roster, replace it with a minimal safe dict.
				roster[i] = {
					"id": "echo_repaired_%04d" % i,
					"name": "",
					"gender": "unknown",
					"seed_path": "",
					"summon_index": 0,
					"origin": "repair",
					"class_origin": "uncalled",
					"archetype_birth": "",
					"traits": { "courage": 0, "wisdom": 0, "faith": 0 },
					"stats": { "max_hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 },
					"xp_total": 0,
					"rank": 1,
					"vector_scores": {},
					"rarity": "uncalled",
					"generation_context": { "modifiers": {} }
				}
				repaired = true
				repaired_notes.append("sanctum.roster[%d] replaced non-dict with safe echo record" % i)
				continue

			var echo: Dictionary = item

			# id
			# Must be a NON-EMPTY string. An empty id ("") is a string and would slip
			# past a type-only check, but two roster echoes sharing "" collide in the
			# id-keyed combat round loop (CombatState initiative + _find_actor_by_id),
			# freezing every duplicate at spawn. Treat empty as missing.
			if not echo.has("id") or typeof(echo["id"]) != TYPE_STRING or str(echo["id"]).is_empty():
				echo["id"] = "echo_repaired_%04d" % i
				repaired = true
				repaired_notes.append("sanctum.roster[%d].id set to string default" % i)

			# name
			if not echo.has("name") or typeof(echo["name"]) != TYPE_STRING:
				echo["name"] = ""
				repaired = true
				repaired_notes.append("sanctum.roster[%d].name set to string default" % i)

			# gender (we do NOT backfill deterministically yet—legacy becomes 'unknown')
			if not echo.has("gender") or typeof(echo["gender"]) != TYPE_STRING:
				echo["gender"] = "unknown"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].gender set to 'unknown' default" % i)

			# origin
			if not echo.has("origin") or typeof(echo["origin"]) != TYPE_STRING:
				echo["origin"] = "repair"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].origin set to string default" % i)

			# summon_index
			if not echo.has("summon_index") or (typeof(echo["summon_index"]) != TYPE_INT and typeof(echo["summon_index"]) != TYPE_FLOAT):
				echo["summon_index"] = 0
				repaired = true
				repaired_notes.append("sanctum.roster[%d].summon_index set to int default" % i)
			else:
				echo["summon_index"] = int(echo["summon_index"])

			# seed_path
			if not echo.has("seed_path") or typeof(echo["seed_path"]) != TYPE_STRING:
				echo["seed_path"] = ""
				repaired = true
				repaired_notes.append("sanctum.roster[%d].seed_path set to string default" % i)

			# class_origin (we now treat 'uncalled' as the default class at birth)
			if not echo.has("class_origin") or typeof(echo["class_origin"]) != TYPE_STRING or str(echo["class_origin"]).is_empty():
				echo["class_origin"] = "uncalled"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].class_origin defaulted to 'uncalled'" % i)

			# archetype_birth — ensure it is a valid 9-archetype value.
			# Legacy saves may contain "brave" or "sage" (old 3-value system); re-derive from traits.
			if not echo.has("archetype_birth") or typeof(echo["archetype_birth"]) != TYPE_STRING:
				echo["archetype_birth"] = ""
				repaired = true
				repaired_notes.append("sanctum.roster[%d].archetype_birth set to string default" % i)
			if echo["archetype_birth"] not in PersonalityArchetype.ARCHETYPES:
				var t_v: Dictionary = echo.get("traits", {})
				if not t_v.is_empty():
					echo["archetype_birth"] = EchoFactory._derive_archetype_birth(
						int(t_v.get("courage", 50)),
						int(t_v.get("wisdom",  50)),
						int(t_v.get("faith",   50))
					)
				else:
					echo["archetype_birth"] = "reflective"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].archetype_birth re-derived (legacy value)" % i)

			# xp_total
			if not echo.has("xp_total") or (typeof(echo["xp_total"]) != TYPE_INT and typeof(echo["xp_total"]) != TYPE_FLOAT):
				echo["xp_total"] = 0
				repaired = true
				repaired_notes.append("sanctum.roster[%d].xp_total set to int default" % i)
			else:
				echo["xp_total"] = int(echo["xp_total"])

			# rank
			if not echo.has("rank") or (typeof(echo["rank"]) != TYPE_INT and typeof(echo["rank"]) != TYPE_FLOAT):
				echo["rank"] = 1
				repaired = true
				repaired_notes.append("sanctum.roster[%d].rank set to int default" % i)
			else:
				echo["rank"] = int(echo["rank"])

			# traits
			if not echo.has("traits") or typeof(echo["traits"]) != TYPE_DICTIONARY:
				echo["traits"] = { "courage": 0, "wisdom": 0, "faith": 0 }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].traits set to default dict" % i)
			else:
				var tr: Dictionary = echo["traits"]
				for k in ["courage", "wisdom", "faith"]:
					if not tr.has(k) or (typeof(tr[k]) != TYPE_INT and typeof(tr[k]) != TYPE_FLOAT):
						tr[k] = 0
						repaired = true
						repaired_notes.append("sanctum.roster[%d].traits.%s set to int default" % [i, k])
					else:
						tr[k] = int(tr[k])

			# stats
			if not echo.has("stats") or typeof(echo["stats"]) != TYPE_DICTIONARY:
				echo["stats"] = { "max_hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].stats set to default dict" % i)
			else:
				var st: Dictionary = echo["stats"]

				# Ensure canonical stat keys exist and are ints
				for k in ["max_hp", "atk", "def", "agi", "int", "cha"]:
					if not st.has(k) or (typeof(st[k]) != TYPE_INT and typeof(st[k]) != TYPE_FLOAT):
						st[k] = 0
						repaired = true
						repaired_notes.append("sanctum.roster[%d].stats.%s set to int default" % [i, k])
					else:
						st[k] = int(st[k])

			# vector_scores
			if not echo.has("vector_scores") or typeof(echo["vector_scores"]) != TYPE_DICTIONARY:
				echo["vector_scores"] = {}
				repaired = true
				repaired_notes.append("sanctum.roster[%d].vector_scores set to {} default" % i)

			# V2-PROG-003: backfill any new vector keys missing from existing saves.
			if VectorService.backfill_vector_scores(echo, _vec_cfg, logger, t):
				repaired = true
				repaired_notes.append("sanctum.roster[%d].vector_scores backfilled new V2 keys" % i)

			# rarity (canonical tiers: uncalled/called/chosen)
			if not echo.has("rarity") or typeof(echo["rarity"]) != TYPE_STRING or str(echo["rarity"]).is_empty():
				echo["rarity"] = "uncalled"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].rarity set to 'uncalled' default" % i)

			# generation_context
			if not echo.has("generation_context") or typeof(echo["generation_context"]) != TYPE_DICTIONARY:
				echo["generation_context"] = { "modifiers": {} }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].generation_context set to default dict" % i)

			# EMOTION-001: emotion block
			if not echo.has("emotion") or typeof(echo["emotion"]) != TYPE_DICTIONARY:
				echo["emotion"] = { "faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 0 }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].emotion added with defaults" % i)
			else:
				var _e_def := { "faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 0 }
				for _k in _e_def:
					if not echo["emotion"].has(_k):
						echo["emotion"][_k] = _e_def[_k]
						repaired = true
						repaired_notes.append("sanctum.roster[%d].emotion.%s set to default" % [i, _k])

			# V2-SANCTUM-001: per-echo recovery modifier block (additive — never overwrites existing)
			if not echo.has("recovery_modifiers") or typeof(echo["recovery_modifiers"]) != TYPE_DICTIONARY:
				echo["recovery_modifiers"] = { "morale_multiplier": 1.0, "fear_multiplier": 1.0, "ticks_remaining": 0 }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].recovery_modifiers defaulted" % i)
			else:
				var _rm: Dictionary = echo["recovery_modifiers"]
				if not _rm.has("morale_multiplier") or (typeof(_rm["morale_multiplier"]) != TYPE_FLOAT and typeof(_rm["morale_multiplier"]) != TYPE_INT):
					_rm["morale_multiplier"] = 1.0
					repaired = true
					repaired_notes.append("sanctum.roster[%d].recovery_modifiers.morale_multiplier set to 1.0" % i)
				if not _rm.has("fear_multiplier") or (typeof(_rm["fear_multiplier"]) != TYPE_FLOAT and typeof(_rm["fear_multiplier"]) != TYPE_INT):
					_rm["fear_multiplier"] = 1.0
					repaired = true
					repaired_notes.append("sanctum.roster[%d].recovery_modifiers.fear_multiplier set to 1.0" % i)
				if not _rm.has("ticks_remaining") or (typeof(_rm["ticks_remaining"]) != TYPE_INT and typeof(_rm["ticks_remaining"]) != TYPE_FLOAT):
					_rm["ticks_remaining"] = 0
					repaired = true
					repaired_notes.append("sanctum.roster[%d].recovery_modifiers.ticks_remaining set to 0" % i)
				else:
					_rm["ticks_remaining"] = int(_rm["ticks_remaining"])

			# PROG-008: skill_slots — Array of active skill_id strings. One slot per calling (MVP=1).
			# Initialise as [""] so the slot exists but is empty. Future rank 6 story appends "".
			if not echo.has("skill_slots") or typeof(echo["skill_slots"]) != TYPE_ARRAY:
				echo["skill_slots"] = [""]
				repaired = true
				repaired_notes.append("sanctum.roster[%d].skill_slots defaulted to ['']" % i)

			# V2-PROG-009: unlocked skill IDs — pool of techniques the Keeper has paid to unlock.
			# Equipping (placing in active slot) is a separate action, out of scope for this story.
			# No unlock cap — Keeper can unlock as many S3 skills as they can afford.
			if not echo.has("unlocked_skills") or typeof(echo["unlocked_skills"]) != TYPE_ARRAY:
				echo["unlocked_skills"] = []
				repaired = true
				repaired_notes.append("sanctum.roster[%d].unlocked_skills defaulted to []" % i)

			# V2-WEAVE-002: woven Threads + deferred memory marks (additive only).
			if not echo.has("woven_threads") or not (echo["woven_threads"] is Array):
				echo["woven_threads"] = []
				repaired = true
				repaired_notes.append("sanctum.roster[%d].woven_threads defaulted to []" % i)
			if not echo.has("weave_memory_marks") or not (echo["weave_memory_marks"] is Array):
				echo["weave_memory_marks"] = []
				repaired = true
				repaired_notes.append("sanctum.roster[%d].weave_memory_marks defaulted to []" % i)

			# V2-MIG-002: Storyweight / Standing / Step bridge fields (mirror V1 values)
			if not echo.has("storyweight") or (typeof(echo["storyweight"]) != TYPE_INT and typeof(echo["storyweight"]) != TYPE_FLOAT):
				echo["storyweight"] = int(echo.get("xp_total", 0))
				repaired = true
				repaired_notes.append("sanctum.roster[%d].storyweight mirrored from xp_total" % i)
			if not echo.has("standing") or (typeof(echo["standing"]) != TYPE_INT and typeof(echo["standing"]) != TYPE_FLOAT):
				echo["standing"] = int(echo.get("rank", 1))
				repaired = true
				repaired_notes.append("sanctum.roster[%d].standing mirrored from rank" % i)
			if not echo.has("step") or (typeof(echo["step"]) != TYPE_INT and typeof(echo["step"]) != TYPE_FLOAT):
				echo["step"] = int(echo.get("level", 1))
				repaired = true
				repaired_notes.append("sanctum.roster[%d].step mirrored from level" % i)

			# V2-PROG-002: calling — confirmed runtime identity (empty until Standing-3 milestone).
			# Additive only — never overwrites an existing non-empty confirmed calling.
			if not echo.has("calling") or typeof(echo["calling"]) != TYPE_STRING:
				echo["calling"] = ""
				repaired = true
				repaired_notes.append("sanctum.roster[%d].calling initialised as empty" % i)

		# Roster id uniqueness — guarantees the id-keyed combat round loop can never
		# resolve two roster echoes to the same actor. Empty ids were already repaired
		# above; this catches legacy/corrupt saves where two echoes share a NON-empty id.
		# Deterministic: scan in stable roster order, keep the first occurrence, rename
		# later duplicates to a collision-free "echo_repaired_<i>".
		var _seen_ids: Dictionary = {}
		for i in range(roster.size()):
			var _re_v: Variant = roster[i]
			if typeof(_re_v) != TYPE_DICTIONARY:
				continue
			var _re: Dictionary = _re_v
			var _rid: String = str(_re.get("id", ""))
			if _seen_ids.has(_rid):
				var _new_id: String = "echo_repaired_%04d" % i
				while _seen_ids.has(_new_id):
					_new_id += "_d"
				_re["id"] = _new_id
				_seen_ids[_new_id] = true
				repaired = true
				repaired_notes.append("sanctum.roster[%d].id '%s' was a duplicate; renamed to '%s'" % [i, _rid, _new_id])
			else:
				_seen_ids[_rid] = true

		# BOND-001: social graph edges
		if not sanctum.has("bonds") or not (sanctum["bonds"] is Array):
			sanctum["bonds"] = []
			repaired = true
			repaired_notes.append("sanctum.bonds set to [] default")

		# BOND-001: party encounter registry
		if not sanctum.has("party_encounters") or not (sanctum["party_encounters"] is Array):
			sanctum["party_encounters"] = []
			repaired = true
			repaired_notes.append("sanctum.party_encounters set to [] default")

		# BOND-002: rival incident seeds (for SANCTUM-005)
		if not sanctum.has("rival_incidents") or not (sanctum["rival_incidents"] is Array):
			sanctum["rival_incidents"] = []
			repaired = true
			repaired_notes.append("sanctum.rival_incidents set to [] default")

		# VOW-001: active_vow must be a Dict (not missing / wrong type)
		if not sanctum.has("active_vow") or not (sanctum["active_vow"] is Dictionary):
			sanctum["active_vow"] = {}
			repaired = true
			repaired_notes.append("sanctum.active_vow set to {} default")

		# V2-MIG-002: vows Dict, keyed by vow_id -> {tier, discovered_realm}.
		if not sanctum.has("vows") or not (sanctum["vows"] is Dictionary):
			sanctum["vows"] = {}
			repaired = true
			repaired_notes.append("sanctum.vows set to {} default (V2-MIG-002)")

		# V2-VOW-002: lifetime vow adherence stats
		if not sanctum.has("vow_stats") or not (sanctum["vow_stats"] is Dictionary):
			sanctum["vow_stats"] = {"honors": 0, "breaks": 0}
			repaired = true
			repaired_notes.append("sanctum.vow_stats defaulted")
		else:
			var _vs: Dictionary = sanctum["vow_stats"]
			if not _vs.has("honors"):
				_vs["honors"] = 0
				repaired = true
				repaired_notes.append("sanctum.vow_stats.honors defaulted")
			if not _vs.has("breaks"):
				_vs["breaks"] = 0
				repaired = true
				repaired_notes.append("sanctum.vow_stats.breaks defaulted")

		# V2-VOW-002: persisted broken vow debuff chip
		if not sanctum.has("pending_broken_vow_effect") or not (sanctum["pending_broken_vow_effect"] is Dictionary):
			sanctum["pending_broken_vow_effect"] = {}
			repaired = true
			repaired_notes.append("sanctum.pending_broken_vow_effect defaulted")

		# V2-VOW-002: pledge re-entry cooldown counter
		if not sanctum.has("pledge_cooldown_stages_remaining") or (
			typeof(sanctum["pledge_cooldown_stages_remaining"]) != TYPE_INT
			and typeof(sanctum["pledge_cooldown_stages_remaining"]) != TYPE_FLOAT
		):
			sanctum["pledge_cooldown_stages_remaining"] = 0
			repaired = true
			repaired_notes.append("sanctum.pledge_cooldown_stages_remaining defaulted")
		else:
			sanctum["pledge_cooldown_stages_remaining"] = int(sanctum["pledge_cooldown_stages_remaining"])

		# V2-MIG-002: Sanctum growth spine + Thread reserve stubs
		if not sanctum.has("continuity") or (typeof(sanctum["continuity"]) != TYPE_INT and typeof(sanctum["continuity"]) != TYPE_FLOAT):
			sanctum["continuity"] = 0
			repaired = true
			repaired_notes.append("sanctum.continuity set to 0 (V2 stub)")
		if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
			sanctum["threads"] = {}
			repaired = true
			repaired_notes.append("sanctum.threads set to {} (V2 stub)")

		# V2-ECONOMY-001: ase_flame — dormancy gate for offline Ase accrual
		if not sanctum.has("ase_flame") or not (sanctum["ase_flame"] is Dictionary):
			sanctum["ase_flame"] = {
				"awakened": bool(save.get("onboarding", {}).get("keeper_intro_complete", false)),
				"boost_remaining_seconds": 0,
				"boost_per_bank_tick": 0,
			}
			repaired = true
			repaired_notes.append("sanctum.ase_flame added")
		else:
			var _flame: Dictionary = sanctum["ase_flame"]
			if not _flame.has("awakened") or typeof(_flame["awakened"]) != TYPE_BOOL:
				_flame["awakened"] = bool(save.get("onboarding", {}).get("keeper_intro_complete", false))
				repaired = true
				repaired_notes.append("sanctum.ase_flame.awakened backfilled")
			if not _flame.has("boost_remaining_seconds") or (typeof(_flame["boost_remaining_seconds"]) != TYPE_INT and typeof(_flame["boost_remaining_seconds"]) != TYPE_FLOAT):
				_flame["boost_remaining_seconds"] = 0
				repaired = true
				repaired_notes.append("sanctum.ase_flame.boost_remaining_seconds set to 0")
			else:
				_flame["boost_remaining_seconds"] = int(_flame["boost_remaining_seconds"])
			if not _flame.has("boost_per_bank_tick") or (typeof(_flame["boost_per_bank_tick"]) != TYPE_INT and typeof(_flame["boost_per_bank_tick"]) != TYPE_FLOAT):
				_flame["boost_per_bank_tick"] = 0
				repaired = true
				repaired_notes.append("sanctum.ase_flame.boost_per_bank_tick set to 0")
			else:
				_flame["boost_per_bank_tick"] = int(_flame["boost_per_bank_tick"])
		# V2-SANCTUM-002: institution model
		if not sanctum.has("institutions") or not (sanctum["institutions"] is Dictionary):
			sanctum["institutions"] = {
				"hearth":           { "unlocked": false, "tier": 0, "condition": "neglected", "last_activated_unix": 0, "occupant_ids": [] },
				"training_grounds": { "unlocked": false, "tier": 0, "condition": "neglected", "last_activated_unix": 0, "occupant_ids": [] },
			}
			repaired = true
			repaired_notes.append("sanctum.institutions initialised (V2-SANCTUM-002)")
		else:
			for _inst_id in ["hearth", "training_grounds"]:
				var _inst_v: Variant = sanctum["institutions"].get(_inst_id, null)
				if not (_inst_v is Dictionary):
					sanctum["institutions"][_inst_id] = { "unlocked": false, "tier": 0, "condition": "neglected", "last_activated_unix": 0, "occupant_ids": [] }
					repaired = true
					repaired_notes.append("sanctum.institutions.%s repaired" % _inst_id)
				else:
					var _inst: Dictionary = _inst_v
					if not _inst.has("last_activated_unix") or (typeof(_inst["last_activated_unix"]) != TYPE_INT and typeof(_inst["last_activated_unix"]) != TYPE_FLOAT):
						_inst["last_activated_unix"] = 0
						repaired = true
						repaired_notes.append("sanctum.institutions.%s.last_activated_unix defaulted" % _inst_id)
					else:
						_inst["last_activated_unix"] = int(_inst["last_activated_unix"])
					if not _inst.has("occupant_ids") or not (_inst["occupant_ids"] is Array):
						_inst["occupant_ids"] = []
						repaired = true
						repaired_notes.append("sanctum.institutions.%s.occupant_ids defaulted" % _inst_id)
					if not _inst.has("condition") or typeof(_inst["condition"]) != TYPE_STRING:
						_inst["condition"] = "neglected"
						repaired = true
						repaired_notes.append("sanctum.institutions.%s.condition defaulted" % _inst_id)

		if _starter_occupants_need_repair(sanctum):
			SanctumLayoutService.ensure_starter_occupant(save)
			repaired = true
			repaired_notes.append("sanctum.occupants repaired to starter placement")

	# ---- stage_context repairs (DIRECTIVE-001 / V2-DIRECTIVE-001) ----
	if not save.has("stage_context") or typeof(save["stage_context"]) != TYPE_DICTIONARY:
		save["stage_context"] = { "active_directive_id": "directive.scout_carefully" }
		repaired = true
		repaired_notes.append("stage_context added with default active_directive_id")
	else:
		var sc: Dictionary = save["stage_context"]
		if not sc.has("active_directive_id") or typeof(sc["active_directive_id"]) != TYPE_STRING:
			sc["active_directive_id"] = "directive.scout_carefully"
			repaired = true
			repaired_notes.append("stage_context.active_directive_id set to 'directive.scout_carefully' default")
		# V2-DIRECTIVE-001: migrate V1 directive IDs to V2 canonical IDs
		var _v1_dir_map: Dictionary = {
			"directive.scout":    "directive.scout_carefully",
			"directive.protect":  "directive.scout_carefully",
			"directive.push":     "directive.scout_carefully",
			"directive.preserve": "directive.scout_carefully",
			"directive.focus":    "directive.scout_carefully"
		}
		var cur_dir_id := str(sc.get("active_directive_id", ""))
		if _v1_dir_map.has(cur_dir_id):
			var migrated: String = str(_v1_dir_map[cur_dir_id])
			sc["active_directive_id"] = migrated
			repaired = true
			repaired_notes.append("directive V1→V2: %s → %s" % [cur_dir_id, migrated])
		elif cur_dir_id not in ["directive.scout_carefully", "directive.seek_signs"]:
			sc["active_directive_id"] = "directive.scout_carefully"
			repaired = true
			repaired_notes.append("unknown directive '%s' reset to scout_carefully" % cur_dir_id)
		# V2-MIG-002: stage-intel persistence stub
		if not sc.has("intel") or not (sc["intel"] is Dictionary):
			sc["intel"] = {}
			repaired = true
			repaired_notes.append("stage_context.intel set to {} (V2 stub)")
		# V2-STAGE-004: encounter_approach stores choice results from non-combat situations
		if not sc.has("encounter_approach"):
			sc["encounter_approach"] = {}
			repaired = true
			repaired_notes.append("stage_context.encounter_approach defaulted to {} (V2-STAGE-004)")

	# ---- REALM-001: realms repair ----
	if not save.has("realms") or typeof(save["realms"]) != TYPE_DICTIONARY:
		save["realms"] = {}
		repaired = true
		repaired_notes.append("realms added with empty dict default")

	# V2-WEAVE-001 + V2-STAGE-001: repair per-realm model fields
	var _realms_repair_v: Variant = save.get("realms", {})
	if _realms_repair_v is Dictionary:
		var _realms_repair: Dictionary = _realms_repair_v
		for _realm_id in _realms_repair:
			var _model_v: Variant = _realms_repair[_realm_id]
			if not (_model_v is Dictionary):
				continue
			var _model: Dictionary = _model_v

			# V2-WEAVE-001: realm_recovery_segments
			if not _model.has("realm_recovery_segments") or not (_model["realm_recovery_segments"] is Array):
				_model["realm_recovery_segments"] = []
				repaired = true
				repaired_notes.append("realm.%s.realm_recovery_segments defaulted to [] (V2-WEAVE-001)" % _realm_id)

			# V2-STAGE-001/002: repairs on each stage
			var _stages_v: Variant = _model.get("stages", [])
			if _stages_v is Array:
				var _stages: Array = _stages_v
				for _stage_v in _stages:
					if not (_stage_v is Dictionary):
						continue
					var _stage: Dictionary = _stage_v
					var _stage_label: String = str(_stage.get("index", "?"))

					# V2-STAGE-001: explore_map
					if not _stage.has("explore_map") or not (_stage["explore_map"] is Dictionary):
						_stage["explore_map"] = StageExploreModelScript.make_default()
						repaired = true
						repaired_notes.append("realm.%s.stage.%s.explore_map defaulted (V2-STAGE-001)" % [_realm_id, _stage_label])

					# V2-INFRA-003 Phase 8 groundwork: settlement_receipt. Additive-only, nothing
					# reads or writes this yet. {} = not settled. Intended shape once populated:
					# { version:int, result_id:String, settled:bool, outcome:String, settled_t:int }
					if not _stage.has("settlement_receipt") or not (_stage["settlement_receipt"] is Dictionary):
						_stage["settlement_receipt"] = {}
						repaired = true
						repaired_notes.append("realm.%s.stage.%s.settlement_receipt defaulted (V2-INFRA-003)" % [_realm_id, _stage_label])

					# V2-STAGE-002: objective completed + required fields
					var _objs_repair_v: Variant = _stage.get("objectives", [])
					if _objs_repair_v is Array:
						for _obj_repair_v in (_objs_repair_v as Array):
							if not (_obj_repair_v is Dictionary):
								continue
							var _obj_repair: Dictionary = _obj_repair_v
							if not _obj_repair.has("completed"):
								_obj_repair["completed"] = false
								repaired = true
							if not _obj_repair.has("required"):
								_obj_repair["required"] = true
								repaired = true
							# V2-STAGE-004: params defensive default (ObjectiveModel.make already sets it)
							if not _obj_repair.has("params"):
								_obj_repair["params"] = {}
								repaired = true
					if repaired:
						repaired_notes.append("realm.%s.stage.%s objectives completed/required defaulted (V2-STAGE-002)" % [_realm_id, _stage_label])

					# V2-STAGE-002: objective_index on explore_map situations
					var _emap_v: Variant = _stage.get("explore_map", {})
					if _emap_v is Dictionary:
						var _emap: Dictionary = _emap_v
						var _sits_v: Variant = _emap.get("situations", [])
						if _sits_v is Array:
							for _sit_v in (_sits_v as Array):
								if not (_sit_v is Dictionary):
									continue
								var _sit: Dictionary = _sit_v
								if not _sit.has("objective_index"):
									_sit["objective_index"] = -1
									repaired = true
						if repaired:
							repaired_notes.append("realm.%s.stage.%s situations objective_index defaulted (V2-STAGE-002)" % [_realm_id, _stage_label])

					# V2-STAGE-003: role + contact fields on each situation; pending_contact + contact_responses on explore_map
					var _003_repaired := false
					var _emap_003_v: Variant = _stage.get("explore_map", {})
					if _emap_003_v is Dictionary:
						var _emap_003: Dictionary = _emap_003_v
						# per-situation repairs
						var _sits_003_v: Variant = _emap_003.get("situations", [])
						if _sits_003_v is Array:
							for _sit_003_v in (_sits_003_v as Array):
								if not (_sit_003_v is Dictionary):
									continue
								var _sit_003: Dictionary = _sit_003_v
								if not _sit_003.has("role"):
									_sit_003["role"] = ""
									_003_repaired = true
								if not _sit_003.has("contact"):
									_sit_003["contact"] = {}
									_003_repaired = true
						# per-explore_map repairs
						if not _emap_003.has("pending_contact"):
							_emap_003["pending_contact"] = {}
							_003_repaired = true
						if not _emap_003.has("contact_responses"):
							_emap_003["contact_responses"] = []
							_003_repaired = true
						if not _emap_003.has("contact_fail_count"):
							_emap_003["contact_fail_count"] = 0
							_003_repaired = true
						if not _emap_003.has("contact_result"):
							_emap_003["contact_result"] = {}
							_003_repaired = true
						# V2-STAGE-004: loot_results accumulates resolved loot situation pickups
						if not _emap_003.has("loot_results"):
							_emap_003["loot_results"] = []
							_003_repaired = true
						# V2-STAGE-004 Phase 2: traversal state fields
						if not _emap_003.has("terrain"):
							_emap_003["terrain"] = {}
							_003_repaired = true
						if not _emap_003.has("in_transit"):
							_emap_003["in_transit"] = false
							_003_repaired = true
						if not _emap_003.has("target_situation_id"):
							_emap_003["target_situation_id"] = ""
							_003_repaired = true
						# V2-STAGE-004-P2: presentation-only path for UI chained tween
						if not _emap_003.has("last_traveled_path"):
							_emap_003["last_traveled_path"] = []
						# V2-COMBAT-002 slice 5: pre-advance cell the path above departs from.
						# Additive alongside last_traveled_path (which is never removed or
						# renamed). Safe default {} — the snapshot projection then falls back
						# to the current party_pos, so legacy saves keep a valid tween anchor.
						if not _emap_003.has("last_traveled_origin"):
							_emap_003["last_traveled_origin"] = {}
						# V2-STAGE-004 Phase 2.5: durable fog-of-war discovered-tile set.
						# Dict used as set: { "col,row": true }. Additive — never reset.
						if not _emap_003.has("explored_cells"):
							_emap_003["explored_cells"] = {}
							_003_repaired = true
						# V2-STAGE-004 Phase 4 (S12): durable Temporary Ally auto-join fields.
						# ally_contact holds the durable contact dict once earned (temporary_ally
						# good outcome); ally_consumed_in_encounter spends it for one battle only.
						if not _emap_003.has("ally_contact"):
							_emap_003["ally_contact"] = {}
							_003_repaired = true
						if not _emap_003.has("ally_contact_id"):
							_emap_003["ally_contact_id"] = ""
							_003_repaired = true
						if not _emap_003.has("ally_consumed_in_encounter"):
							_emap_003["ally_consumed_in_encounter"] = false
							_003_repaired = true
						# V2-STAGE-004 Phase 4 (S13): durable Charge-pressure flag. Set by a failed
						# non-objective Charge (FlowRuntime._apply_contact_outcome charge branch);
						# consumed once by the first PROTECT/ENDURE objective combat fought afterward
						# (EncounterSetupService.setup, charge-pressure block), then cleared back to "".
						if not _emap_003.has("hostile_charge_sit_id"):
							_emap_003["hostile_charge_sit_id"] = ""
							_003_repaired = true
						# V2-STAGE-004 Phase 4 (S14 redesign): compute-once guard marker for the
						# earned-return ally recruit roll — tracks which encounter_id's roll was
						# already evaluated by RecruitmentConsequenceService.compute_ally_recruit_offer_if_eligible()
						# so a re-render/Continue never re-rolls. The invite itself now lives on
						# save_data.sanctum.companion_invite (see the sanctum repair block below).
						if not _emap_003.has("ally_recruit_rolled_encounter_id"):
							_emap_003["ally_recruit_rolled_encounter_id"] = ""
							_003_repaired = true
						# V2-STAGE-004 Phase 4 (S15 prep): durable combat-intro marker. Set by
						# FlowRuntime's stage.claimant.combat_forced branch ("claimant_hostile");
						# cleared back to "" at encounter teardown alongside the ally fields.
						if not _emap_003.has("combat_intro_reason"):
							_emap_003["combat_intro_reason"] = ""
							_003_repaired = true
					if _003_repaired:
						repaired = true
						repaired_notes.append("realm.%s.stage.%s contact fields defaulted (V2-STAGE-003)" % [_realm_id, _stage_label])

	# Get structured log if anything was repaired (uses injected t)
	if repaired:
		_log_info(logger, t, "save.schema.repair", "Applied additive save schema repairs", {
			"notes": repaired_notes,
			"schema_version": int(save.get("schema_version", 0))
		})
		
	return repaired
	
static func validate(data: Dictionary, report_errors: bool = true) -> bool:
	if data.is_empty():
		return false
		
	# schema_version must exist and be supported
	if not data.has("schema_version"):
		return _validation_failure("Invalid save: missing schema_version", report_errors)
		
	var v_raw = data["schema_version"]
	if typeof(v_raw) != TYPE_INT and typeof(v_raw) != TYPE_FLOAT:
		return _validation_failure("Invalid save: schema_version is not a number", report_errors)
		
	var version := int(v_raw)
	if version != SaveSchema.SCHEMA_VERSION:
		return _validation_failure(
			"Unsupported save schema_version %d; expected %d" % [version, SaveSchema.SCHEMA_VERSION],
			report_errors
		)
		
	# Required top-level keys
	for k in ["meta", "campaign", "flow", "sanctum", "economy"]:
		if not data.has(k) or typeof(data[k]) != TYPE_DICTIONARY:
			return _validation_failure("Invalid save: missing or invalid top-level key: " + k, report_errors)

	var meta: Dictionary = data["meta"]
	if meta.has("save_generation"):
		var generation_v: Variant = meta["save_generation"]
		if (typeof(generation_v) != TYPE_INT and typeof(generation_v) != TYPE_FLOAT) or int(generation_v) < 0:
			return _validation_failure("Invalid save: meta.save_generation must be a non-negative number", report_errors)
			
	# Required nested keys (SANCTUM-002)
	var camp: Dictionary = data["campaign"]

	# Accept either the new seed_root or legacy root_seed (repairs should backfill seed_root)
	var has_seed_root := camp.has("seed_root") and typeof(camp["seed_root"]) == TYPE_STRING and not str(camp["seed_root"]).is_empty()
	var has_root_seed := camp.has("root_seed")

	if not has_seed_root and not has_root_seed:
		return _validation_failure("Invalid save: missing campaign.seed_root (and legacy root_seed)", report_errors)

	# If seed_root exists, seed_source must exist too
	if has_seed_root:
		if not camp.has("seed_source") or typeof(camp["seed_source"]) != TYPE_STRING:
			return _validation_failure("Invalid save: missing campaign.seed_source", report_errors)
		
	if not data["flow"].has("state"):
		return _validation_failure("Invalid save: missing flow.state", report_errors)
		
	return true

static func _validation_failure(message: String, report_errors: bool) -> bool:
	if report_errors:
		push_error("[SaveService] " + message)
	return false
