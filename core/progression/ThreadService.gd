class_name ThreadService
extends RefCounted

# V2-WEAVE-001: Thread crystallization and recovery band utilities.
# Deterministic — no RNG. All outputs are fully determined by save state + config.


## Crystallize Threads from a completed Realm's recovery segments into sanctum.threads.
## Returns Array of Thread dicts added.
## GDD §14.4: every completed Realm guarantees at least 1 usable full Thread.
static func crystallize_threads(
	realm_id: String,
	save_data: Dictionary,
	cfg: Dictionary,    # data.threads block from balance.json
	t: int,
	logger
) -> Array:
	var realms_v: Variant = save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var realm_v: Variant = realms.get(realm_id, {})
	var realm: Dictionary = realm_v if realm_v is Dictionary else {}
	if realm.is_empty():
		logger.warn(t, "thread.crystallize.fail", "Realm not found", {"realm_id": realm_id})
		return []

	var segments_v: Variant = realm.get("realm_recovery_segments", [])
	var segments: Array = segments_v if segments_v is Array else []
	if segments.is_empty():
		logger.info(t, "thread.crystallize.none", "No segments — no threads crystallized", {"realm_id": realm_id})
		return []

	var quality: float   = _derive_quality(segments, cfg)
	var virtue: String   = str(realm.get("virtue", "unknown"))
	var run_index: int   = int(realm.get("run_index", 0))

	var count_thresholds_v: Variant = cfg.get("count_thresholds", {})
	var count_thresholds: Dictionary = count_thresholds_v if count_thresholds_v is Dictionary else {}
	# GDD §14.4: every completed Realm guarantees at least 1 usable full Thread.
	# "one": 0.00 threshold handles this; max(1, ...) is the code-level safety floor.
	var thread_count: int = max(1, _resolve_count(quality, count_thresholds))

	var quality_tiers_v: Variant = cfg.get("quality_tiers", {})
	var quality_tiers: Dictionary = quality_tiers_v if quality_tiers_v is Dictionary else {}
	var quality_tier: String = _resolve_tier(quality, quality_tiers)

	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	if not sanctum.has("threads") or not (sanctum["threads"] is Dictionary):
		sanctum["threads"] = {}
		save_data["sanctum"] = sanctum
	var threads: Dictionary = sanctum["threads"]

	var added: Array = []
	for i in range(thread_count):
		var thread_id := _gen_thread_id(realm_id, i, run_index, threads)
		var thread := {
			"id":                thread_id,
			"virtue":            virtue,
			"quality_tier":      quality_tier,
			"realm_id":          realm_id,
			"run_index":         run_index,
		}
		threads[thread_id] = thread
		added.append(thread)

	logger.info(t, "thread.crystallize", "Threads crystallized", {
		"realm_id":     realm_id,
		"quality":      quality,
		"thread_count": thread_count,
		"quality_tier": quality_tier,
		"virtue":       virtue,
	})
	return added


## Derive weighted quality float (0.0–1.0) from segments Array.
## clean=weight 1.0, compromised=0.5, broken=0.1 (from cfg.quality_tiers[tier].weight).
static func _derive_quality(segments: Array, cfg: Dictionary) -> float:
	if segments.is_empty():
		return 0.0
	var quality_tiers_v: Variant = cfg.get("quality_tiers", {})
	var quality_tiers: Dictionary = quality_tiers_v if quality_tiers_v is Dictionary else {}
	var total: float = 0.0
	for seg_v in segments:
		var seg: Dictionary = seg_v if seg_v is Dictionary else {}
		var tier := str(seg.get("quality_tier", "broken"))
		var tier_cfg_v: Variant = quality_tiers.get(tier, {})
		var tier_cfg: Dictionary = tier_cfg_v if tier_cfg_v is Dictionary else {}
		total += float(tier_cfg.get("weight", 0.1))
	return minf(1.0, total / float(segments.size()))


## Map recovery segments to a player-facing band label: "strong" / "compromised" / "weak".
## Used by FlowStageMapState for the Recovery Cord display.
static func get_recovery_band(segments: Array, cfg: Dictionary) -> String:
	var quality := _derive_quality(segments, cfg)
	var quality_tiers_v: Variant = cfg.get("quality_tiers", {})
	var quality_tiers: Dictionary = quality_tiers_v if quality_tiers_v is Dictionary else {}
	for tier in ["clean", "compromised", "broken"]:
		var tier_cfg_v: Variant = quality_tiers.get(tier, {})
		var tier_cfg: Dictionary = tier_cfg_v if tier_cfg_v is Dictionary else {}
		if quality >= float(tier_cfg.get("min_quality", 0.0)):
			match tier:
				"clean":       return "strong"
				"compromised": return "compromised"
				_:             return "weak"
	return "weak"


## Resolve Thread count from weighted quality float.
## GDD §14.4 guarantees ≥1 for any completed Realm — "one": 0.00 threshold handles this;
## callers additionally apply max(1, result) as a code-level safety floor.
static func _resolve_count(quality: float, thresholds: Dictionary) -> int:
	if quality >= float(thresholds.get("three", 0.75)): return 3
	if quality >= float(thresholds.get("two",   0.40)): return 2
	if quality >= float(thresholds.get("one",   0.00)): return 1
	return 0


## Resolve quality tier label from derived float.
static func _resolve_tier(quality: float, tiers: Dictionary) -> String:
	for tier in ["clean", "compromised", "broken"]:
		var tier_cfg_v: Variant = tiers.get(tier, {})
		var tier_cfg: Dictionary = tier_cfg_v if tier_cfg_v is Dictionary else {}
		if quality >= float(tier_cfg.get("min_quality", 0.0)):
			return tier
	return "broken"


## Generate unique Thread ID. Appends run suffix on collision.
static func _gen_thread_id(realm_id: String, index: int, run_index: int, existing: Dictionary) -> String:
	var base_id := "thread." + realm_id + "." + str(index)
	if not existing.has(base_id):
		return base_id
	return base_id + ".r" + str(run_index)
