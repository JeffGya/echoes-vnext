class_name CallingService
extends RefCounted

## CallingService — pure static. No RNG, no OS time, no side effects.
##
## Determines compatibility tiers for all 6 callings against a given echo's
## vector scores, and applies the emotional consequence when a calling is confirmed.
##
## Tier order (first match wins):
##   "preferred"    — calling maps from the dominant vector
##   "compatible"   — calling maps from a vector with score >= threshold × total
##   "incompatible" — calling maps from a vector with score = 0
##   "ambivalent"   — catch-all (score > 0 but below threshold)


## Returns ALL calling options for the echo, each tagged with a compatibility tier.
## Always returns one entry per id in calling_cfg.all_callings — never filters.
##
## Each entry:
##   calling_id    String
##   display_name  String
##   icon_key      String
##   description   String
##   benefits      Array[String]
##   downsides     Array[String]
##   compatibility "preferred" | "compatible" | "incompatible" | "ambivalent"
##   is_preferred  bool  (true for the single most-aligned choice)
static func compute_all_options(echo: Dictionary, calling_cfg: Dictionary) -> Array:
	var dominant: String = str(echo.get("dominant_vector", ""))
	var scores_v: Variant  = echo.get("vector_scores", {})
	var scores: Dictionary = scores_v if scores_v is Dictionary else {}

	var defns_v: Variant   = calling_cfg.get("definitions", {})
	var defns: Dictionary  = defns_v if defns_v is Dictionary else {}
	var all_ids_v: Variant = calling_cfg.get("all_callings", [])
	var all_ids: Array     = all_ids_v if all_ids_v is Array else []
	var v2c_v: Variant     = calling_cfg.get("vector_to_calling", {})
	var v2c: Dictionary    = v2c_v if v2c_v is Dictionary else {}
	var threshold: float   = float(calling_cfg.get("compatibility_threshold", 0.15))

	# Total score across all vectors (for threshold ratio calc)
	var total_score: float = 0.0
	for s in scores.values():
		total_score += float(s)

	# Preferred calling from dominant vector
	var preferred_calling: String = str(v2c.get(dominant, ""))

	# Non-dominant vectors that clear the compatibility threshold
	var compatible_vectors: Array = []
	for vec in scores:
		if str(vec) == dominant:
			continue
		if total_score > 0.0 and (float(scores[vec]) / total_score) >= threshold:
			compatible_vectors.append(str(vec))

	var result: Array = []
	for cid_v in all_ids:
		var cid: String   = str(cid_v)
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var vec: String   = str(defn.get("vector", ""))

		var compatibility: String = "ambivalent"  # catch-all default
		var is_preferred: bool    = false

		if cid == preferred_calling:
			compatibility = "preferred"
			is_preferred  = true
		elif vec in compatible_vectors:
			compatibility = "compatible"
		elif vec == dominant:
			# Calling shares the dominant vector but is not the preferred pick → compatible
			# (e.g. kra_soro and okomfo both have vector=seeker; seeker-dominant gets okomfo
			# as preferred and kra_soro as compatible)
			compatibility = "compatible"
		elif total_score <= 0.0 or float(scores.get(vec, 0)) <= 0.0:
			# Vector has zero contribution → truly incompatible
			compatibility = "incompatible"
		# else: score > 0 but below threshold → stays "ambivalent"

		result.append({
			"calling_id":    cid,
			"display_name":  str(defn.get("display_name", cid)),
			"icon_key":      str(defn.get("icon_key", "")),
			"description":   str(defn.get("description", "")),
			"benefits":      defn.get("benefits", []) if defn.get("benefits") is Array else [],
			"downsides":     defn.get("downsides", []) if defn.get("downsides") is Array else [],
			"compatibility": compatibility,
			"is_preferred":  is_preferred,
		})

	return result


## Returns true when the echo has reached the calling milestone but hasn't chosen yet.
static func is_calling_pending(echo: Dictionary) -> bool:
	return bool(echo.get("calling_eligible", false)) and str(echo.get("calling", "")).is_empty()


## Confirms the Keeper's chosen calling on the echo.
## Applies the emotional consequence matching the calling's compatibility tier.
## Clears calling_options and writes calling permanently.
## Returns the confirmed calling_id on success, "" on failure (invalid id).
static func confirm_calling(
	echo: Dictionary,
	chosen_calling_id: String,
	calling_cfg: Dictionary,
	logger,
	t: int
) -> String:
	var options_v: Variant = echo.get("calling_options", [])
	var options: Array = options_v if options_v is Array else []

	# Find the compatibility tier for the chosen calling from stored options
	var compatibility: String = ""
	for opt_v in options:
		if opt_v is Dictionary and str(opt_v.get("calling_id", "")) == chosen_calling_id:
			compatibility = str(opt_v.get("compatibility", ""))
			break

	if compatibility.is_empty():
		return ""  # invalid calling_id — not in options

	# Store calling permanently; erase temp options
	echo["calling"] = chosen_calling_id
	echo.erase("calling_options")

	# Apply emotional consequence
	var emo_v: Variant = echo.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	match compatibility:
		"preferred":
			var boost: int = int(calling_cfg.get("calling_preferred_morale_boost", 10))
			emo["morale_current"] = mini(100, int(emo.get("morale_current", 50)) + boost)
		"compatible":
			var dip: int = int(calling_cfg.get("calling_compatible_morale_dip", 5))
			emo["morale_current"] = maxi(0, int(emo.get("morale_current", 50)) - dip)
		"ambivalent":
			var m_dip: int = int(calling_cfg.get("calling_ambivalent_morale_dip", 3))
			var f_inc: int = int(calling_cfg.get("calling_ambivalent_fear_increase", 3))
			emo["morale_current"] = maxi(0, int(emo.get("morale_current", 50)) - m_dip)
			emo["fear_current"]   = mini(100, int(emo.get("fear_current", 0)) + f_inc)
		"incompatible":
			var fear_inc: int = int(calling_cfg.get("calling_incompatible_fear_increase", 10))
			emo["fear_current"] = mini(100, int(emo.get("fear_current", 0)) + fear_inc)
	echo["emotion"] = emo

	if logger != null:
		logger.info(t, "calling.confirmed", "Calling confirmed: %s (%s)" % [chosen_calling_id, compatibility], {
			"echo_id":       str(echo.get("id", "")),
			"calling":       chosen_calling_id,
			"compatibility": compatibility,
		})

	return chosen_calling_id


## Returns the two Standing-6 expressions for a given foundational calling.
## Returns [] for an unknown calling_id — no crash.
##
## Return shape (raw from config — each entry):
##   id              String   — canonical S6 expression ID
##   display_name    String   — Twi name (may be empty if twi_provisional)
##   english_scaffold String  — English scaffold name
##   descriptor      String   — one-line description of the expression
##   parent_calling  String   — the foundational calling this expression belongs to
##
## Note: this is a pure data getter. Entry shape validation is validate_standing_6_entry()'s job.
## Eligibility (standing >= 6) is always checked by the caller — not here.
static func get_standing_6_options(calling_id: String, calling_cfg: Dictionary) -> Array:
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var defn_v: Variant = defns.get(calling_id, {})
	var defn: Dictionary = defn_v if defn_v is Dictionary else {}
	var s6_v: Variant = defn.get("standing_6", [])
	return s6_v if s6_v is Array else []


## Returns the full 6-option Standing-6 selection pool for an echo.
## Pool: 2 entries from the echo's own confirmed calling + 2 from each of the 2 adjacent callings.
##
## Anchor resolution:
##   1. echo["calling"] if non-empty and not "uncalled"
##   2. echo["calling_origin"] as fallback
##   3. Returns [] if both resolve to "" or "uncalled" — see design contract below.
##
## Return shape: Array of S6 entry dicts (raw from config, same as get_standing_6_options).
## Downstream callers (V2-PROG-009, V2-PROG-012) own eligibility gating.
static func compute_standing_6_pool(echo: Dictionary, calling_cfg: Dictionary) -> Array:
	var calling: String = str(echo.get("calling", ""))
	if calling.is_empty() or calling == "uncalled":
		calling = str(echo.get("calling_origin", ""))

	if calling.is_empty() or calling == "uncalled":
		# Design contract: uncalled echo at S6 → empty pool.
		# Intended resolution: forced confirmation screen (Option C) triggered by caller before
		# invoking this function. Fear accumulation for late callings is also deferred design debt.
		# Do NOT auto-confirm calling_origin here. See V2-PROG-008 plan.
		return []

	var pool: Array = []
	pool.append_array(get_standing_6_options(calling, calling_cfg))
	var neighbours: Array = get_adjacent_callings(calling, calling_cfg)
	for neighbour_v in neighbours:
		var neighbour: String = str(neighbour_v)
		pool.append_array(get_standing_6_options(neighbour, calling_cfg))
	return pool


## Returns the two adjacent calling IDs in the adjacency ring for calling_id.
## Returns [] if calling_id is not present in the adjacency config.
static func get_adjacent_callings(calling_id: String, calling_cfg: Dictionary) -> Array:
	var adj_v: Variant = calling_cfg.get("adjacency", {})
	var adj: Dictionary = adj_v if adj_v is Dictionary else {}
	var neighbours_v: Variant = adj.get(calling_id, [])
	return neighbours_v if neighbours_v is Array else []


## Returns the two Standing-9 culminations for a given Standing-6 expression ID.
## Returns [] for an unknown s6_id — no crash.
##
## Implementation: inline scan across all calling definitions (O(6 × 4) = 24 reads max).
## A flat lookup map is not used — this function is called at most a handful of times per session
## and the scan cost is negligible.
##
## Return shape (raw from config — each entry):
##   id               String   — canonical S9 culmination ID
##   display_name     String   — Twi name (empty when twi_provisional = true)
##   english_scaffold  String   — English scaffold name
##   parent_standing_6 String   — the S6 expression this culmination belongs to
##   twi_provisional  bool     — true when Twi name needs cultural validation before ship
static func get_standing_9_options(s6_id: String, calling_cfg: Dictionary) -> Array:
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var result: Array = []
	for cid_v in defns:
		var defn_v: Variant = defns.get(cid_v, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s9_v: Variant = defn.get("standing_9", [])
		var s9: Array = s9_v if s9_v is Array else []
		for entry_v in s9:
			if entry_v is Dictionary and str(entry_v.get("parent_standing_6", "")) == s6_id:
				result.append(entry_v)
	return result


## Returns true if entry["parent_calling"] is a recognised foundational calling.
## Rejects entries whose parent_calling is absent, empty, or not in all_callings.
static func validate_standing_6_entry(entry: Dictionary, calling_cfg: Dictionary) -> bool:
	var parent: String = str(entry.get("parent_calling", ""))
	if parent.is_empty():
		return false
	var all_ids_v: Variant = calling_cfg.get("all_callings", [])
	var all_ids: Array = all_ids_v if all_ids_v is Array else []
	return parent in all_ids


## Returns true if entry["parent_standing_6"] matches a valid standing_6.id
## across all calling definitions in calling_cfg.
## Returns false for empty, absent, or unrecognised parent_standing_6 values.
static func validate_standing_9_entry(entry: Dictionary, calling_cfg: Dictionary) -> bool:
	var parent_s6: String = str(entry.get("parent_standing_6", ""))
	if parent_s6.is_empty():
		return false
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	for cid_v in defns:
		var defn_v: Variant = defns.get(cid_v, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		var s6: Array = s6_v if s6_v is Array else []
		for expr_v in s6:
			if expr_v is Dictionary and str(expr_v.get("id", "")) == parent_s6:
				return true
	return false


## Validates that every calling has exactly 2 Standing-6 entries,
## and every S6 expression has exactly 2 Standing-9 entries.
## Logs a warning for each miscounted entry. Returns true only if all counts are correct.
##
## This is a COUNT-only guard. Shape/parent-ref validation is validate_config_integrity()'s job.
## Both are called at balance load in ConfigService.
static func validate_count_integrity(calling_cfg: Dictionary, logger, t: int) -> bool:
	var all_valid := true
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var all_ids_v: Variant = calling_cfg.get("all_callings", [])
	var all_ids: Array = all_ids_v if all_ids_v is Array else []

	for cid_v in all_ids:
		var cid: String = str(cid_v)
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		var s6: Array = s6_v if s6_v is Array else []

		if s6.size() != 2:
			if logger != null:
				logger.info(t, "calling.config.warn",
					"Expected 2 standing_6 entries for %s, got %d" % [cid, s6.size()], {})
			all_valid = false

		for expr_v in s6:
			if not (expr_v is Dictionary):
				continue
			var s6_id: String = str(expr_v.get("id", ""))
			if s6_id.is_empty():
				continue
			var s9_v: Variant = defn.get("standing_9", [])
			var s9: Array = s9_v if s9_v is Array else []
			var count: int = 0
			for s9_entry_v in s9:
				if s9_entry_v is Dictionary and str(s9_entry_v.get("parent_standing_6", "")) == s6_id:
					count += 1
			if count != 2:
				if logger != null:
					logger.info(t, "calling.config.warn",
						"Expected 2 standing_9 entries for S6 '%s' in %s, got %d" % [s6_id, cid, count], {})
				all_valid = false

	return all_valid


## Validates all standing_6 and standing_9 entries in calling_cfg.
## Logs a warning for each malformed entry. Returns true only if all entries are valid.
## Call once at boot (via ConfigValidator or FlowRuntime) to catch config errors early.
static func validate_config_integrity(calling_cfg: Dictionary, logger, t: int) -> bool:
	var all_valid := true
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}

	for cid_v in defns:
		var cid: String = str(cid_v)
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}

		var s6_v: Variant = defn.get("standing_6", [])
		for entry_v in (s6_v if s6_v is Array else []):
			if not (entry_v is Dictionary) or not validate_standing_6_entry(entry_v, calling_cfg):
				if logger != null:
					logger.info(t, "calling.config.warn",
						"Invalid standing_6 entry in %s" % cid, {"entry": str(entry_v)})
				all_valid = false

		var s9_v: Variant = defn.get("standing_9", [])
		for entry_v in (s9_v if s9_v is Array else []):
			if not (entry_v is Dictionary) or not validate_standing_9_entry(entry_v, calling_cfg):
				if logger != null:
					logger.info(t, "calling.config.warn",
						"Invalid standing_9 entry in %s" % cid, {"entry": str(entry_v)})
				all_valid = false

	return all_valid
