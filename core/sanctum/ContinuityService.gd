# res://core/sanctum/ContinuityService.gd
# V2-CONTINUITY-001: Single choke point for all Continuity mutations.
# Pure-static RefCounted — no UI deps, no RNG, no OS time.
# Mirrors EconomyService pattern.

class_name ContinuityService
extends RefCounted


# ---------------------------------------------------------------------------
# Read
# ---------------------------------------------------------------------------

static func get_points(save_data: Dictionary) -> int:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return 0
	return int((sanctum_v as Dictionary).get("continuity", 0))


static func get_echo_rejection_count(save_data: Dictionary, echo_id: String) -> int:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return 0
	var counts_v: Variant = (sanctum_v as Dictionary).get("rejection_counts", {})
	if not (counts_v is Dictionary):
		return 0
	return int((counts_v as Dictionary).get(echo_id, 0))


static func get_band(points: int, continuity_cfg: Dictionary) -> String:
	var bands_v: Variant = continuity_cfg.get("bands", [])
	if not (bands_v is Array):
		return "awakening"
	var bands: Array = bands_v as Array

	# Sort descending by min_points so first match wins.
	var sorted: Array = bands.duplicate()
	sorted.sort_custom(func(a, b):
		return int(a.get("min_points", 0)) > int(b.get("min_points", 0))
	)

	for band_v in sorted:
		if not (band_v is Dictionary):
			continue
		var band: Dictionary = band_v
		if points >= int(band.get("min_points", 0)):
			return str(band.get("name", "awakening"))

	return "awakening"


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------

static func add_points(save_data: Dictionary, amount: int, cause: String, logger: Object, t: int) -> void:
	if amount <= 0:
		return
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var old_val := int(sanctum.get("continuity", 0))
	var new_val := old_val + amount
	sanctum["continuity"] = new_val
	logger.info(t, "sanctum.continuity.changed", "Continuity increased", {
		"cause": cause, "delta": amount, "old": old_val, "new": new_val,
	})


static func apply_penalty(save_data: Dictionary, amount: int, cause: String, logger: Object, t: int) -> void:
	if amount <= 0:
		return
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var old_val := int(sanctum.get("continuity", 0))
	var new_val := maxi(0, old_val - amount)
	sanctum["continuity"] = new_val
	logger.info(t, "sanctum.continuity.changed", "Continuity decreased", {
		"cause": cause, "delta": -amount, "old": old_val, "new": new_val,
	})


static func apply_reject_penalty(save_data: Dictionary, echo_id: String, base: int, max_penalty: int, cause: String, logger: Object, t: int) -> void:
	# Increment rejection count for this echo, then apply escalating penalty capped at max_penalty.
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary

	# Ensure rejection_counts dict exists.
	if not sanctum.has("rejection_counts") or not (sanctum["rejection_counts"] is Dictionary):
		sanctum["rejection_counts"] = {}
	var counts: Dictionary = sanctum["rejection_counts"] as Dictionary

	var prev_count := int(counts.get(echo_id, 0))
	var new_count  := prev_count + 1
	counts[echo_id] = new_count

	var penalty := mini(base * new_count, max_penalty)
	apply_penalty(save_data, penalty, cause, logger, t)
	logger.info(t, "sanctum.continuity.reject_penalty", "Reject penalty applied", {
		"echo_id": echo_id, "rejection_count": new_count, "penalty": penalty,
	})
