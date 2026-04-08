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
