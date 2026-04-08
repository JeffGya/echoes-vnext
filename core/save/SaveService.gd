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
			
		# Ensure seed_root exists (we derive from legacy root_seed)
		if not camp.has("seed_root") or typeof(camp["seed_root"]) != TYPE_STRING or str(camp["seed_root"]).is_empty():
			var legacy_seed := int(camp.get("root_seed", 0))
			camp["seed_root"] = "legacy:%d" % legacy_seed
			repaired = true
			repaired_notes.append("campaign.seed_root set from legacy root_seed")
			
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
			"bonds": [],
			"party_encounters": [],
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
	
		# SANCTUM-002: roster item additive repairs (Echo placeholder contract)
		# Keep deterministic: no RNG, no OS time; only defaults + key migrations.

		# V2-PROG-003: load vec_cfg once for vector backfill inside the echo loop.
		var _balance_for_repair := JsonFileLoader.load_dict(ConfigService.PATH_BALANCE)
		var _vec_cfg: Dictionary = {}
		var _vc_v: Variant = _balance_for_repair.get("data", {}).get("vectors", {})
		if typeof(_vc_v) == TYPE_DICTIONARY:
			_vec_cfg = _vc_v

		# V2-PROG-004: V1 → V2 calling ID map. Defined once here; applied inside the echo loop.
		var _v1_to_v2_calling: Dictionary = {
			"blade": "aduro", "warder": "okofor", "steward": "onyamesu",
			"ranger": "kra_soro", "seer": "okomfo"
		}

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
			if not echo.has("id") or typeof(echo["id"]) != TYPE_STRING:
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

			# stats (migrate old keys if present)
			if not echo.has("stats") or typeof(echo["stats"]) != TYPE_DICTIONARY:
				echo["stats"] = { "max_hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "cha": 0 }
				repaired = true
				repaired_notes.append("sanctum.roster[%d].stats set to default dict" % i)
			else:
				var st: Dictionary = echo["stats"]

				# Migration: old "spd" -> "agi"
				if st.has("spd") and (not st.has("agi")):
					st["agi"] = int(st.get("spd", 0))
					repaired = true
					repaired_notes.append("sanctum.roster[%d].stats migrated spd->agi" % i)

				# Migration: old "hp" -> "max_hp" (if it existed)
				if st.has("hp") and (not st.has("max_hp")):
					st["max_hp"] = int(st.get("hp", 0))
					repaired = true
					repaired_notes.append("sanctum.roster[%d].stats migrated hp->max_hp" % i)

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

			# rarity (canonical tiers: uncalled/called/chosen; repair legacy 'common')
			if not echo.has("rarity") or typeof(echo["rarity"]) != TYPE_STRING or str(echo["rarity"]).is_empty():
				echo["rarity"] = "uncalled"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].rarity set to 'uncalled' default" % i)
			elif str(echo["rarity"]) == "common":
				echo["rarity"] = "uncalled"
				repaired = true
				repaired_notes.append("sanctum.roster[%d].rarity repaired common->uncalled" % i)

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

			# PROG-008: skill_slots — Array of active skill_id strings. One slot per calling (MVP=1).
			# Initialise as [""] so the slot exists but is empty. Future rank 6 story appends "".
			if not echo.has("skill_slots") or typeof(echo["skill_slots"]) != TYPE_ARRAY:
				echo["skill_slots"] = [""]
				repaired = true
				repaired_notes.append("sanctum.roster[%d].skill_slots defaulted to ['']" % i)

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

			# V2-PROG-004: migrate V1 calling IDs to V2 canonical IDs (one-time, idempotent).
			# calling_origin immutability is a design invariant (player cannot change it);
			# this is a system-level schema correction, not a player action.
			for _field in ["calling_origin", "calling"]:
				var _cv: String = str(echo.get(_field, ""))
				if _v1_to_v2_calling.has(_cv):
					echo[_field] = _v1_to_v2_calling[_cv]
					repaired = true
					repaired_notes.append("sanctum.roster[%d].%s migrated V1 id '%s' -> V2" % [i, _field, _cv])

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

		# VOW-001: active_vow must be a Dict (not missing / wrong type)
		if not sanctum.has("active_vow") or not (sanctum["active_vow"] is Dictionary):
			sanctum["active_vow"] = {}
			repaired = true
			repaired_notes.append("sanctum.active_vow set to {} default")

		# V2-MIG-002: vow key migration — unlocked_vows Array → vows Dict
		# CONVENTIONS.md canonical shape: vows: { vow_id: { tier, discovered_realm } }
		if sanctum.has("unlocked_vows") and sanctum["unlocked_vows"] is Array:
			var old_arr: Array = sanctum["unlocked_vows"]
			var new_dict: Dictionary = {}
			for entry_v in old_arr:
				if not (entry_v is Dictionary):
					continue
				var entry: Dictionary = entry_v
				var vid := str(entry.get("vow_id", ""))
				if vid.is_empty():
					continue
				new_dict[vid] = {
					"tier":             int(entry.get("max_tier_unlocked", 1)),
					"discovered_realm": str(entry.get("discovered_realm", "")),
				}
			sanctum["vows"] = new_dict
			sanctum.erase("unlocked_vows")
			repaired = true
			repaired_notes.append("sanctum.unlocked_vows[] migrated to sanctum.vows{} (V2-MIG-002)")
		elif not sanctum.has("vows") or not (sanctum["vows"] is Dictionary):
			sanctum["vows"] = {}
			repaired = true
			repaired_notes.append("sanctum.vows set to {} default (V2-MIG-002)")

		# V2-MIG-002: Sanctum growth spine + Thread reserve stubs
		if not sanctum.has("continuity") or (typeof(sanctum["continuity"]) != TYPE_INT and typeof(sanctum["continuity"]) != TYPE_FLOAT):
			sanctum["continuity"] = 0
			repaired = true
			repaired_notes.append("sanctum.continuity set to 0 (V2 stub)")
		if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
			sanctum["threads"] = {}
			repaired = true
			repaired_notes.append("sanctum.threads set to {} (V2 stub)")

	# ---- stage_context repairs (DIRECTIVE-001) ----
	if not save.has("stage_context") or typeof(save["stage_context"]) != TYPE_DICTIONARY:
		save["stage_context"] = { "active_directive_id": "directive.none" }
		repaired = true
		repaired_notes.append("stage_context added with default active_directive_id")
	else:
		var sc: Dictionary = save["stage_context"]
		if not sc.has("active_directive_id") or typeof(sc["active_directive_id"]) != TYPE_STRING:
			sc["active_directive_id"] = "directive.none"
			repaired = true
			repaired_notes.append("stage_context.active_directive_id set to 'directive.none' default")
		# V2-MIG-002: stage-intel persistence stub
		if not sc.has("intel") or not (sc["intel"] is Dictionary):
			sc["intel"] = {}
			repaired = true
			repaired_notes.append("stage_context.intel set to {} (V2 stub)")

	# ---- REALM-001: realms repair ----
	if not save.has("realms") or typeof(save["realms"]) != TYPE_DICTIONARY:
		save["realms"] = {}
		repaired = true
		repaired_notes.append("realms added with empty dict default")

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
			
	# Required nested keys (SANCTUM-002)
	var camp: Dictionary = data["campaign"]

	# Accept either the new seed_root or legacy root_seed (repairs should backfill seed_root)
	var has_seed_root := camp.has("seed_root") and typeof(camp["seed_root"]) == TYPE_STRING and not str(camp["seed_root"]).is_empty()
	var has_root_seed := camp.has("root_seed")

	if not has_seed_root and not has_root_seed:
		push_error("[SaveService] Invalid save: missing campaign.seed_root (and legacy root_seed)")
		return false

	# If seed_root exists, seed_source must exist too
	if has_seed_root:
		if not camp.has("seed_source") or typeof(camp["seed_source"]) != TYPE_STRING:
			push_error("[SaveService] Invalid save: missing campaign.seed_source")
			return false
		
	if not data["flow"].has("state"):
		push_error("[SaveService] invalid save: missing flow.state")
		return false
		
	return true
