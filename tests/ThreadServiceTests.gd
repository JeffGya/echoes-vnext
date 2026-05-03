# res://tests/ThreadServiceTests.gd
# V2-WEAVE-001: ThreadService unit tests.
class_name ThreadServiceTests
extends RefCounted

# Shared config matching data/balance.json data.threads block.
static func _make_cfg() -> Dictionary:
	return {
		"segment_quality_by_grade": {
			"S": "clean", "A": "clean",
			"B": "compromised", "C": "compromised", "D": "compromised",
			"F": "broken",
		},
		"quality_tiers": {
			"clean":       { "min_quality": 0.70, "weight": 1.0 },
			"compromised": { "min_quality": 0.35, "weight": 0.5 },
			"broken":      { "min_quality": 0.00, "weight": 0.1 },
		},
		"count_thresholds": { "three": 0.75, "two": 0.40, "one": 0.00 },
	}

static func _make_save(realm_id: String, segments: Array, virtue: String = "courage") -> Dictionary:
	return {
		"sanctum": { "threads": {} },
		"realms": {
			realm_id: {
				"virtue":                  virtue,
				"run_index":               0,
				"is_completed":            false,
				"realm_recovery_segments": segments,
			}
		},
	}

static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l

# ---------------------------------------------------------------------------

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("thread/crystallize_one_all_broken",      Callable(ThreadServiceTests, "_test_crystallize_one_thread_all_broken"))
	runner.register_test("thread/crystallize_two_mixed",           Callable(ThreadServiceTests, "_test_crystallize_two_threads_mixed"))
	runner.register_test("thread/crystallize_three_all_clean",     Callable(ThreadServiceTests, "_test_crystallize_three_threads_all_clean"))
	runner.register_test("thread/crystallize_populates_sanctum",   Callable(ThreadServiceTests, "_test_crystallize_populates_sanctum_threads"))
	runner.register_test("thread/crystallize_empty_no_segments",   Callable(ThreadServiceTests, "_test_crystallize_empty_when_no_segments"))
	runner.register_test("thread/contribute_grade_s_maps_clean",   Callable(ThreadServiceTests, "_test_contribute_segment_grade_s_maps_clean"))
	runner.register_test("thread/contribute_grade_f_maps_broken",  Callable(ThreadServiceTests, "_test_contribute_segment_grade_f_maps_broken"))
	runner.register_test("thread/contribute_ignores_completed",    Callable(ThreadServiceTests, "_test_contribute_segment_ignores_completed_realm"))
	runner.register_test("thread/derive_quality_all_clean",        Callable(ThreadServiceTests, "_test_derive_quality_all_clean"))
	runner.register_test("thread/get_recovery_band_strong",        Callable(ThreadServiceTests, "_test_get_recovery_band_returns_strong"))
	runner.register_test("thread/id_collision_guard",              Callable(ThreadServiceTests, "_test_thread_id_collision_guard"))

# ---------------------------------------------------------------------------
# Crystallize tests
# ---------------------------------------------------------------------------

## All F grades → quality=0.1 (broken weight) → 1 broken thread (GDD §14.4 minimum guarantee).
static func _test_crystallize_one_thread_all_broken() -> Dictionary:
	var cfg := _make_cfg()
	var segments := [
		{ "stage_index": 0, "quality_tier": "broken" },
		{ "stage_index": 1, "quality_tier": "broken" },
	]
	var save := _make_save("realm.01", segments)

	var result := ThreadService.crystallize_threads("realm.01", save, cfg, 0, _make_logger())

	if result.size() != 1:
		return { "ok": false, "error": "Expected 1 thread (GDD §14.4 guarantee), got %d" % result.size() }
	var th: Dictionary = result[0]
	if str(th.get("quality_tier", "")) != "broken":
		return { "ok": false, "error": "Expected quality_tier=broken, got %s" % th.get("quality_tier", "") }
	return { "ok": true }


## Mixed quality (3 clean + 2 broken): quality≈0.64 → 2 compromised threads.
static func _test_crystallize_two_threads_mixed() -> Dictionary:
	var cfg := _make_cfg()
	# quality = (3×1.0 + 2×0.1) / 5 = 3.2/5 = 0.64 → ≥0.40, <0.75 → 2 threads
	# tier: 0.64 ≥ 0.35, <0.70 → "compromised"
	var segments := [
		{ "stage_index": 0, "quality_tier": "clean" },
		{ "stage_index": 1, "quality_tier": "clean" },
		{ "stage_index": 2, "quality_tier": "clean" },
		{ "stage_index": 3, "quality_tier": "broken" },
		{ "stage_index": 4, "quality_tier": "broken" },
	]
	var save := _make_save("realm.02", segments)

	var result := ThreadService.crystallize_threads("realm.02", save, cfg, 0, _make_logger())

	if result.size() != 2:
		return { "ok": false, "error": "Expected 2 threads, got %d" % result.size() }
	var th: Dictionary = result[0]
	if str(th.get("quality_tier", "")) != "compromised":
		return { "ok": false, "error": "Expected quality_tier=compromised, got %s" % th.get("quality_tier", "") }
	return { "ok": true }


## All clean → quality=1.0 → 3 clean threads.
static func _test_crystallize_three_threads_all_clean() -> Dictionary:
	var cfg := _make_cfg()
	var segments := [
		{ "stage_index": 0, "quality_tier": "clean" },
		{ "stage_index": 1, "quality_tier": "clean" },
		{ "stage_index": 2, "quality_tier": "clean" },
	]
	var save := _make_save("realm.03", segments)

	var result := ThreadService.crystallize_threads("realm.03", save, cfg, 0, _make_logger())

	if result.size() != 3:
		return { "ok": false, "error": "Expected 3 threads, got %d" % result.size() }
	var th: Dictionary = result[0]
	if str(th.get("quality_tier", "")) != "clean":
		return { "ok": false, "error": "Expected quality_tier=clean, got %s" % th.get("quality_tier", "") }
	return { "ok": true }


## Threads are written into save_data.sanctum.threads.
static func _test_crystallize_populates_sanctum_threads() -> Dictionary:
	var cfg := _make_cfg()
	var segments := [
		{ "stage_index": 0, "quality_tier": "clean" },
		{ "stage_index": 1, "quality_tier": "clean" },
	]
	var save := _make_save("realm.04", segments, "wisdom")

	var result := ThreadService.crystallize_threads("realm.04", save, cfg, 0, _make_logger())

	var threads: Dictionary = save.get("sanctum", {}).get("threads", {})
	if threads.size() != result.size():
		return { "ok": false, "error": "sanctum.threads size %d != returned size %d" % [threads.size(), result.size()] }
	for th_v in result:
		var th: Dictionary = th_v
		var tid := str(th.get("id", ""))
		if not threads.has(tid):
			return { "ok": false, "error": "Thread id '%s' not found in sanctum.threads" % tid }
		var stored: Dictionary = threads[tid]
		if str(stored.get("virtue", "")) != "wisdom":
			return { "ok": false, "error": "Expected virtue=wisdom, got %s" % stored.get("virtue", "") }
	return { "ok": true }


## No segments → crystallize returns [] (no threads created; empty realm has no contribution).
static func _test_crystallize_empty_when_no_segments() -> Dictionary:
	var cfg := _make_cfg()
	var save := _make_save("realm.05", [])

	var result := ThreadService.crystallize_threads("realm.05", save, cfg, 0, _make_logger())

	if result.size() != 0:
		return { "ok": false, "error": "Expected [] for no segments, got %d items" % result.size() }
	return { "ok": true }

# ---------------------------------------------------------------------------
# contribute_segment tests (via RealmService — needs minimal FlowContext)
# ---------------------------------------------------------------------------

static func _make_ctx(realm_id: String, is_completed: bool = false, stage_index: int = 0) -> FlowContext:
	var ctx := FlowContext.new()
	ctx.realm_id = realm_id
	ctx.logger   = _make_logger()
	ctx.save_data = {
		"realms": {
			realm_id: {
				"id":                      realm_id,
				"virtue":                  "courage",
				"run_index":               0,
				"is_completed":            is_completed,
				"current_stage_index":     stage_index,
				"realm_recovery_segments": [],
			}
		}
	}
	return ctx


## Grade "S" should map to quality_tier "clean".
static func _test_contribute_segment_grade_s_maps_clean() -> Dictionary:
	var cfg := _make_cfg()
	var ctx := _make_ctx("realm.s1")

	RealmService.contribute_segment(ctx, "S", cfg, 0)

	var segs: Array = ctx.save_data["realms"]["realm.s1"].get("realm_recovery_segments", [])
	if segs.size() != 1:
		return { "ok": false, "error": "Expected 1 segment, got %d" % segs.size() }
	var tier := str(segs[0].get("quality_tier", ""))
	if tier != "clean":
		return { "ok": false, "error": "Expected tier=clean for grade S, got %s" % tier }
	return { "ok": true }


## Grade "F" should map to quality_tier "broken".
static func _test_contribute_segment_grade_f_maps_broken() -> Dictionary:
	var cfg := _make_cfg()
	var ctx := _make_ctx("realm.f1")

	RealmService.contribute_segment(ctx, "F", cfg, 0)

	var segs: Array = ctx.save_data["realms"]["realm.f1"].get("realm_recovery_segments", [])
	if segs.size() != 1:
		return { "ok": false, "error": "Expected 1 segment, got %d" % segs.size() }
	var tier := str(segs[0].get("quality_tier", ""))
	if tier != "broken":
		return { "ok": false, "error": "Expected tier=broken for grade F, got %s" % tier }
	return { "ok": true }


## contribute_segment must be a no-op when realm is already completed.
static func _test_contribute_segment_ignores_completed_realm() -> Dictionary:
	var cfg := _make_cfg()
	var ctx := _make_ctx("realm.done", true)  # is_completed = true

	RealmService.contribute_segment(ctx, "S", cfg, 0)

	var segs: Array = ctx.save_data["realms"]["realm.done"].get("realm_recovery_segments", [])
	if segs.size() != 0:
		return { "ok": false, "error": "Expected 0 segments for completed realm, got %d" % segs.size() }
	return { "ok": true }

# ---------------------------------------------------------------------------
# _derive_quality / get_recovery_band tests
# ---------------------------------------------------------------------------

## All clean segments → quality = 1.0.
static func _test_derive_quality_all_clean() -> Dictionary:
	var cfg := _make_cfg()
	var segments := [
		{ "stage_index": 0, "quality_tier": "clean" },
		{ "stage_index": 1, "quality_tier": "clean" },
		{ "stage_index": 2, "quality_tier": "clean" },
	]
	var save := _make_save("realm.dq1", segments)

	# Crystallize and check count/tier as proxy for quality=1.0
	var result := ThreadService.crystallize_threads("realm.dq1", save, cfg, 0, _make_logger())
	if result.size() != 3:
		return { "ok": false, "error": "All-clean quality should yield 3 threads, got %d" % result.size() }
	if str(result[0].get("quality_tier", "")) != "clean":
		return { "ok": false, "error": "All-clean quality should yield clean threads, got %s" % result[0].get("quality_tier", "") }
	return { "ok": true }


## All clean → get_recovery_band returns "strong".
static func _test_get_recovery_band_returns_strong() -> Dictionary:
	var cfg := _make_cfg()
	var segments := [
		{ "stage_index": 0, "quality_tier": "clean" },
		{ "stage_index": 1, "quality_tier": "clean" },
	]

	var band := ThreadService.get_recovery_band(segments, cfg)
	if band != "strong":
		return { "ok": false, "error": "Expected band=strong, got %s" % band }
	return { "ok": true }

# ---------------------------------------------------------------------------
# ID collision guard
# ---------------------------------------------------------------------------

## When a thread ID already exists, _gen_thread_id appends a run suffix.
static func _test_thread_id_collision_guard() -> Dictionary:
	var cfg := _make_cfg()
	# Use "broken" quality so _resolve_count → 1 thread (quality=0.1, threshold one=0.00).
	# A "clean" segment gives quality=1.0 → count=3, which is correct but complicates the
	# collision test (we only want to verify the ID guard, not the count logic).
	var segments := [
		{ "stage_index": 0, "quality_tier": "broken" },
	]
	var realm_id := "realm.cg1"
	# Pre-populate sanctum.threads with the base ID to force a collision.
	var base_id := "thread." + realm_id + ".0"
	var save := {
		"sanctum": { "threads": { base_id: { "id": base_id } } },
		"realms": {
			realm_id: {
				"virtue":                  "courage",
				"run_index":               2,
				"is_completed":            false,
				"realm_recovery_segments": segments,
			}
		},
	}

	var result := ThreadService.crystallize_threads(realm_id, save, cfg, 0, _make_logger())

	if result.size() != 1:
		return { "ok": false, "error": "Expected 1 thread from collision guard test, got %d" % result.size() }
	var new_id := str(result[0].get("id", ""))
	if new_id == base_id:
		return { "ok": false, "error": "Expected collision guard to produce a different ID, still got base_id" }
	if not new_id.ends_with(".r2"):
		return { "ok": false, "error": "Expected ID ending '.r2', got %s" % new_id }
	return { "ok": true }
