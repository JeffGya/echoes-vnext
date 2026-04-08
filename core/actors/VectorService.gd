# res://core/actors/VectorService.gd
# Single choke point for all Vector mutations and queries.
#
# Contract:
# - All methods are static — no instantiation needed.
# - No RNG, no OS time, no side effects beyond the passed-in echo dict and logger.
# - Vector keys are NEVER hardcoded — all iteration uses echo.vector_scores.keys()
#   or config-driven key sets. New vectors are added via balance.json only.
# - Accumulator range: 0–1000 per vector key (integer).
#
# Dominant vector rule (PROG-005, locked):
#   A vector becomes dominant only when it exceeds the current dominant by
#   > 3% of the total score sum. If total == 0, returns current_dominant unchanged.
#   This prevents rapid oscillation while still allowing meaningful shifts.
#
# Save paths (additive-only):
#   echo["vector_scores"]   — Dictionary<String, int>  (accumulator per key)
#   echo["dominant_vector"] — String                   (stored for hysteresis)

extends RefCounted

class_name VectorService

const CLAMP_MAX    := 1000
const MARGIN_FACTOR := 0.03  # 3% — dominant switch threshold


## Initialises vector_scores and dominant_vector for a freshly generated echo.
## Reads archetype_init weights keyed by echo.class_origin from vec_cfg.
## Idempotent: safe to call again (overwrites scores cleanly).
##
## vec_cfg shape: { "archetype_init": { "<class_origin>": { "<vector_key>": int, ... }, ... } }
## echo must have "class_origin" and "id" fields already set.
static func init_vectors(echo: Dictionary, vec_cfg: Dictionary, logger: StructuredLogger, t: int) -> void:
	var archetype_init: Dictionary = {}
	var ai_v: Variant = vec_cfg.get("archetype_init", {})
	if typeof(ai_v) == TYPE_DICTIONARY:
		archetype_init = ai_v

	var class_origin: String = str(echo.get("class_origin", ""))

	var weights: Dictionary = {}
	if archetype_init.has(class_origin):
		var raw: Variant = archetype_init[class_origin]
		if typeof(raw) == TYPE_DICTIONARY:
			weights = raw.duplicate()

	if weights.is_empty():
		# No config found for this class_origin — leave scores empty.
		# dominant_vector fallback (class_origin) was set by EchoFactory/repair_echo_fields.
		logger.info(t, "vector.init.fallback", "No archetype_init config for class_origin", {
			"echo_id": str(echo.get("id", "")),
			"class_origin": class_origin
		})
		return

	echo["vector_scores"] = weights.duplicate()
	echo["dominant_vector"] = compute_dominant(weights, class_origin)

	logger.info(t, "vector.init", "Vector scores initialised from archetype", {
		"echo_id": str(echo.get("id", "")),
		"class_origin": class_origin,
		"starting_scores": weights.duplicate(),
		"dominant_vector": echo["dominant_vector"]
	})


## Adds amount to echo.vector_scores[vector_key], clamped to [0, CLAMP_MAX].
## Detects and logs a dominant vector switch if the margin rule is satisfied.
## vector_key may be any string — no hardcoded key list.
static func accumulate(echo: Dictionary, vector_key: String, amount: int, logger: StructuredLogger, t: int) -> void:
	if not echo.has("vector_scores") or typeof(echo["vector_scores"]) != TYPE_DICTIONARY:
		echo["vector_scores"] = {}

	var scores: Dictionary = echo["vector_scores"]

	var current_val: int = int(scores.get(vector_key, 0))
	var new_val: int = clampi(current_val + amount, 0, CLAMP_MAX)
	scores[vector_key] = new_val

	var old_dominant: String = str(echo.get("dominant_vector", ""))
	var new_dominant: String = compute_dominant(scores, old_dominant)

	logger.info(t, "vector.accumulate", "Vector accumulated", {
		"echo_id": str(echo.get("id", "")),
		"vector_key": vector_key,
		"delta": amount,
		"new_value": new_val
	})

	if new_dominant != old_dominant:
		echo["dominant_vector"] = new_dominant
		logger.info(t, "vector.dominant.changed", "Dominant vector switched", {
			"echo_id": str(echo.get("id", "")),
			"old_dominant": old_dominant,
			"new_dominant": new_dominant
		})


## Returns the dominant vector key given current scores and the previously stored dominant.
## PURE function — no side effects, no logging.
##
## Rule: a challenger becomes dominant only when it exceeds the current dominant
##       by > MARGIN_FACTOR (3%) of the total score sum.
## If total == 0, returns current_dominant unchanged (safe for empty/new echoes).
static func compute_dominant(vector_scores: Dictionary, current_dominant: String) -> String:
	if vector_scores.is_empty():
		return current_dominant

	var total: float = 0.0
	for key in vector_scores:
		total += float(int(vector_scores[key]))

	if total <= 0.0:
		return current_dominant

	# Find candidate (key with highest value) — dynamic, no hardcoded keys
	var candidate: String = ""
	var candidate_val: float = -1.0
	for key in vector_scores:
		var v: float = float(int(vector_scores[key]))
		if v > candidate_val:
			candidate_val = v
			candidate = key

	if candidate == current_dominant:
		return current_dominant

	var current_val: float = float(int(vector_scores.get(current_dominant, 0)))
	var margin_threshold: float = total * MARGIN_FACTOR

	if candidate_val - current_val > margin_threshold:
		return candidate

	return current_dominant


## Backfills any vector keys present in vec_cfg.archetype_init but absent from
## echo.vector_scores. Missing keys are added at 0 (additive-only, never deletes).
## Returns true if any key was added.
## Designed to run at save-load repair time to expand old 4-key saves to 10 V2 keys.
##
## vec_cfg shape: { "archetype_init": { "<class_origin>": { "<vector_key>": float, ... } } }
static func backfill_vector_scores(echo: Dictionary, vec_cfg: Dictionary, logger: StructuredLogger, t: int) -> bool:
	var archetype_init: Dictionary = {}
	var ai_v: Variant = vec_cfg.get("archetype_init", {})
	if typeof(ai_v) == TYPE_DICTIONARY:
		archetype_init = ai_v

	# Collect union of all canonical vector keys across all class_origin entries.
	# Config-driven: adding a new vector to archetype_init is sufficient.
	var canonical_keys: Dictionary = {}
	for origin_key in archetype_init:
		var weights: Variant = archetype_init[origin_key]
		if typeof(weights) == TYPE_DICTIONARY:
			for vk in weights:
				canonical_keys[vk] = true

	if canonical_keys.is_empty():
		return false

	if not echo.has("vector_scores") or typeof(echo["vector_scores"]) != TYPE_DICTIONARY:
		echo["vector_scores"] = {}

	var scores: Dictionary = echo["vector_scores"]
	var added: Array = []
	for vk in canonical_keys:
		if not scores.has(vk):
			scores[vk] = 0
			added.append(vk)

	if added.is_empty():
		return false

	logger.info(t, "vector.backfill", "Backfilled missing vector keys", {
		"echo_id": str(echo.get("id", "")),
		"added_keys": added
	})
	return true


## Returns a snapshot-safe dict with current vector data for this echo.
## Shape: { "scores": Dictionary<String, int>, "dominant_vector": String }
## "scores" contains all keys from echo.vector_scores — no hardcoded key list.
## Supports any number of future vector keys with no code changes.
static func get_snapshot_data(echo: Dictionary) -> Dictionary:
	var raw_scores: Dictionary = {}
	var rs_v: Variant = echo.get("vector_scores", {})
	if typeof(rs_v) == TYPE_DICTIONARY:
		raw_scores = rs_v

	var scores: Dictionary = {}
	for key in raw_scores:
		scores[key] = int(raw_scores[key])

	return {
		"scores": scores,
		"dominant_vector": str(echo.get("dominant_vector", ""))
	}
