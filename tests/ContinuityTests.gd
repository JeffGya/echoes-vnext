# res://tests/ContinuityTests.gd
# V2-CONTINUITY-001: Unit tests for ContinuityService and InstitutionService blocker.

extends RefCounted
class_name ContinuityTests

const ContinuityServiceScript := preload("res://core/sanctum/ContinuityService.gd")
const InstitutionServiceScript := preload("res://core/sanctum/InstitutionService.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("continuity/thread_integration_increments",   Callable(ContinuityTests, "_test_add_points"))
	runner.register_test("continuity/vow_break_applies_penalty",       Callable(ContinuityTests, "_test_apply_penalty"))
	runner.register_test("continuity/reject_penalty_escalates",        Callable(ContinuityTests, "_test_reject_escalates"))
	runner.register_test("continuity/reject_penalty_capped",           Callable(ContinuityTests, "_test_reject_capped"))
	runner.register_test("continuity/reject_count_tracked_per_echo",   Callable(ContinuityTests, "_test_reject_per_echo"))
	runner.register_test("continuity/institution_blocker_present_when_unmet", Callable(ContinuityTests, "_test_blocker_present"))
	runner.register_test("continuity/institution_blocker_absent_when_met",    Callable(ContinuityTests, "_test_blocker_absent"))
	runner.register_test("continuity/band_derivation",                 Callable(ContinuityTests, "_test_band_derivation"))
	runner.register_test("continuity/no_below_zero",                   Callable(ContinuityTests, "_test_no_below_zero"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_save(continuity: int = 0) -> Dictionary:
	return {
		"sanctum": {
			"continuity":       continuity,
			"rejection_counts": {},
		}
	}

static func _make_logger() -> Object:
	return _NullLogger.new()

static func _band_cfg() -> Dictionary:
	return {
		"bands": [
			{ "name": "awakening",         "min_points": 0  },
			{ "name": "habit",             "min_points": 5  },
			{ "name": "role",              "min_points": 15 },
			{ "name": "governance",        "min_points": 30 },
			{ "name": "differentiation",   "min_points": 50 },
			{ "name": "cultural_maturity", "min_points": 75 },
		]
	}

static func _make_inst_cfg(threshold: int) -> Dictionary:
	return {
		"hearth": { "unlock_continuity_threshold": threshold }
	}

static func _make_inst_save(continuity: int) -> Dictionary:
	return {
		"sanctum": {
			"continuity": continuity,
			"institutions": {
				"hearth": {
					"unlocked": false, "tier": 0, "condition": "neglected",
					"last_activated_unix": 0, "occupant_ids": [], "position": {"x": 0, "y": 0},
				},
				"training_grounds": {
					"unlocked": false, "tier": 0, "condition": "neglected",
					"last_activated_unix": 0, "occupant_ids": [], "position": {"x": 0, "y": 0},
				},
			},
		}
	}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _test_add_points() -> Dictionary:
	var save := _make_save(0)
	ContinuityServiceScript.add_points(save, 5, "test", _make_logger(), 0)
	var pts := ContinuityServiceScript.get_points(save)
	if pts != 5:
		return { "ok": false, "error": "add_points: expected 5, got %d" % pts }
	return { "ok": true }


static func _test_apply_penalty() -> Dictionary:
	var save := _make_save(10)
	ContinuityServiceScript.apply_penalty(save, 3, "test", _make_logger(), 0)
	var pts := ContinuityServiceScript.get_points(save)
	if pts != 7:
		return { "ok": false, "error": "apply_penalty: 10-3 expected 7, got %d" % pts }
	return { "ok": true }


static func _test_reject_escalates() -> Dictionary:
	var save := _make_save(30)
	var log  := _make_logger()
	# 1st reject → 1*2=2
	ContinuityServiceScript.apply_reject_penalty(save, "echo_01", 2, 10, "test", log, 0)
	var pts1 := ContinuityServiceScript.get_points(save)
	if pts1 != 28:
		return { "ok": false, "error": "1st reject: expected 28, got %d" % pts1 }
	# 2nd reject → 2*2=4
	ContinuityServiceScript.apply_reject_penalty(save, "echo_01", 2, 10, "test", log, 1)
	var pts2 := ContinuityServiceScript.get_points(save)
	if pts2 != 24:
		return { "ok": false, "error": "2nd reject: expected 24, got %d" % pts2 }
	# 3rd reject → 3*2=6
	ContinuityServiceScript.apply_reject_penalty(save, "echo_01", 2, 10, "test", log, 2)
	var pts3 := ContinuityServiceScript.get_points(save)
	if pts3 != 18:
		return { "ok": false, "error": "3rd reject: expected 18, got %d" % pts3 }
	return { "ok": true }


static func _test_reject_capped() -> Dictionary:
	var save := _make_save(100)
	var log  := _make_logger()
	for i in range(5):
		ContinuityServiceScript.apply_reject_penalty(save, "echo_cap", 2, 10, "test", log, i)
	var before := ContinuityServiceScript.get_points(save)
	ContinuityServiceScript.apply_reject_penalty(save, "echo_cap", 2, 10, "test", log, 5)
	var after := ContinuityServiceScript.get_points(save)
	var cost := before - after
	if cost != 10:
		return { "ok": false, "error": "6th reject should cost 10 (capped), got %d" % cost }
	return { "ok": true }


static func _test_reject_per_echo() -> Dictionary:
	var save := _make_save(50)
	var log  := _make_logger()
	ContinuityServiceScript.apply_reject_penalty(save, "echo_a", 2, 10, "test", log, 0)
	ContinuityServiceScript.apply_reject_penalty(save, "echo_b", 2, 10, "test", log, 1)
	var ca1 := ContinuityServiceScript.get_echo_rejection_count(save, "echo_a")
	var cb1 := ContinuityServiceScript.get_echo_rejection_count(save, "echo_b")
	if ca1 != 1:
		return { "ok": false, "error": "echo_a count expected 1, got %d" % ca1 }
	if cb1 != 1:
		return { "ok": false, "error": "echo_b count expected 1 (independent), got %d" % cb1 }
	# echo_a rejects again — count should be 2, echo_b stays 1
	ContinuityServiceScript.apply_reject_penalty(save, "echo_a", 2, 10, "test", log, 2)
	var ca2 := ContinuityServiceScript.get_echo_rejection_count(save, "echo_a")
	var cb2 := ContinuityServiceScript.get_echo_rejection_count(save, "echo_b")
	if ca2 != 2:
		return { "ok": false, "error": "echo_a count expected 2 after 2nd reject, got %d" % ca2 }
	if cb2 != 1:
		return { "ok": false, "error": "echo_b count should stay 1, got %d" % cb2 }
	return { "ok": true }


static func _test_blocker_present() -> Dictionary:
	var save     := _make_inst_save(0)
	var inst_cfg := _make_inst_cfg(1)
	var result   := InstitutionServiceScript.get_snapshot_data(save, inst_cfg, 0)
	var hearth: Dictionary = {}
	for e_v in result:
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == "hearth":
			hearth = e_v
			break
	var reason := str(hearth.get("blocker_reason", "MISSING"))
	if reason != "The ground is not ready":
		return { "ok": false, "error": "Expected blocker_reason='The ground is not ready', got '%s'" % reason }
	return { "ok": true }


static func _test_blocker_absent() -> Dictionary:
	var save     := _make_inst_save(5)
	var inst_cfg := _make_inst_cfg(1)
	var result   := InstitutionServiceScript.get_snapshot_data(save, inst_cfg, 0)
	var hearth: Dictionary = {}
	for e_v in result:
		if e_v is Dictionary and str((e_v as Dictionary).get("id", "")) == "hearth":
			hearth = e_v
			break
	var reason := str(hearth.get("blocker_reason", "MISSING"))
	if reason != "":
		return { "ok": false, "error": "Expected empty blocker_reason when cont >= threshold, got '%s'" % reason }
	return { "ok": true }


static func _test_band_derivation() -> Dictionary:
	var cfg := _band_cfg()
	var cases := [
		[0,  "awakening"],
		[8,  "habit"],
		[15, "role"],
		[50, "differentiation"],
		[75, "cultural_maturity"],
	]
	for c in cases:
		var pts: int  = c[0]
		var expected: String = c[1]
		var got := ContinuityServiceScript.get_band(pts, cfg)
		if got != expected:
			return { "ok": false, "error": "get_band(%d): expected '%s', got '%s'" % [pts, expected, got] }
	return { "ok": true }


static func _test_no_below_zero() -> Dictionary:
	var save := _make_save(3)
	ContinuityServiceScript.apply_penalty(save, 100, "test", _make_logger(), 0)
	var pts := ContinuityServiceScript.get_points(save)
	if pts != 0:
		return { "ok": false, "error": "Expected 0 (clamped), got %d" % pts }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Null logger (no-op for tests)
# ---------------------------------------------------------------------------

class _NullLogger:
	extends RefCounted
	func info(_t: int, _type: String, _msg: String, _data: Dictionary = {}) -> void:
		pass
	func debug(_t: int, _type: String, _msg: String, _data: Dictionary = {}) -> void:
		pass
