# res://tests/EconomyTests.gd
class_name EconomyTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("economy/add_spend", Callable(EconomyTests, "_test_add_spend"))
	runner.register_test("economy/denied_spend_no_mutation", Callable(EconomyTests, "_test_denied_spend"))
	runner.register_test("economy/offline_taper_exceeds_8h_before_zero", Callable(EconomyTests, "_test_offline_taper_exceeds_8h"))
	runner.register_test("economy/offline_flame_gate_zero", Callable(EconomyTests, "_test_offline_flame_gate_zero"))
	runner.register_test("economy/offline_continuity_dominance", Callable(EconomyTests, "_test_offline_continuity_dominance"))
	# Roundtrip test can be added after we decide test save path strategy.

static func _test_add_spend() -> Dictionary:
	var save := { "economy": { "ase": 10, "ekwan": 0 } }
	var logger := StructuredLogger.new()
	logger.set_level("off") # tests don’t need log output

	var econ := EconomyService.new(save)
	econ.add_ase(5, "test.add", logger, 0)
	var ok := econ.spend_ase(3, "test.spend", logger, 1)

	var ase := int(save["economy"]["ase"])
	if ok != true:
		return { "ok": false, "error": "Expected spend_ase to return true" }
	if ase != 12:
		return { "ok": false, "error": "Expected ase=12, got %d" % ase }

	return { "ok": true }

static func _test_denied_spend() -> Dictionary:
	var save := { "economy": { "ase": 2, "ekwan": 0 } }
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var econ := EconomyService.new(save)
	var ok := econ.spend_ase(999, "test.denied", logger, 0)

	var ase := int(save["economy"]["ase"])
	if ok != false:
		return { "ok": false, "error": "Expected spend_ase to return false" }
	if ase != 2:
		return { "ok": false, "error": "Expected ase unchanged (=2), got %d" % ase }

	return { "ok": true }

static func _test_offline_taper_exceeds_8h() -> Dictionary:
	var rate_per_sec := 0.3 / 60.0
	var gain_8h := EconomyAccrualService.compute_offline_gain(8 * 3600, rate_per_sec, 1.0, 0.06, 42 * 3600)
	var gain_24h := EconomyAccrualService.compute_offline_gain(24 * 3600, rate_per_sec, 1.0, 0.06, 42 * 3600)
	var gain_48h := EconomyAccrualService.compute_offline_gain(48 * 3600, rate_per_sec, 1.0, 0.06, 42 * 3600)
	if gain_8h <= 0:
		return { "ok": false, "error": "Expected 8h offline gain to be visible" }
	if gain_24h <= gain_8h:
		return { "ok": false, "error": "Expected 24h gain (%d) to exceed 8h gain (%d)" % [gain_24h, gain_8h] }
	if gain_48h != EconomyAccrualService.compute_offline_gain(42 * 3600, rate_per_sec, 1.0, 0.06, 42 * 3600):
		return { "ok": false, "error": "Expected taper to reach zero growth at the configured window" }
	return { "ok": true }

static func _test_offline_flame_gate_zero() -> Dictionary:
	var runtime := OnboardingTests._make_runtime()
	var now_unix := int(Time.get_unix_time_from_system())
	var econ_data: Dictionary = runtime.flow_ctx.save_data.get("economy", {})
	econ_data["ase"] = 0
	econ_data["last_offline_unix"] = now_unix - (24 * 3600)
	econ_data["last_settle_unix"] = now_unix - (24 * 3600)
	var gain := int(runtime.call("_apply_offline_accrual_if_needed", 2, "test.offline.flame_gate"))
	if gain != 0:
		return { "ok": false, "error": "Expected dormant flame to block offline gain" }
	if int(econ_data.get("ase", 0)) != 0:
		return { "ok": false, "error": "Expected ase unchanged when flame is dormant" }
	return { "ok": true }

static func _test_offline_continuity_dominance() -> Dictionary:
	var low := OnboardingTests._make_runtime()
	var high := OnboardingTests._make_runtime()
	var now_unix := int(Time.get_unix_time_from_system())
	for runtime in [low, high]:
		var sanctum: Dictionary = runtime.flow_ctx.save_data.get("sanctum", {})
		var flame: Dictionary = sanctum.get("ase_flame", {})
		flame["awakened"] = true
		sanctum["ase_flame"] = flame
		var econ_data: Dictionary = runtime.flow_ctx.save_data.get("economy", {})
		econ_data["ase"] = 0
		econ_data["last_offline_unix"] = now_unix - (8 * 3600)
		econ_data["last_settle_unix"] = now_unix - (8 * 3600)
	var low_sanctum: Dictionary = low.flow_ctx.save_data.get("sanctum", {})
	low_sanctum["continuity"] = 0
	var high_sanctum: Dictionary = high.flow_ctx.save_data.get("sanctum", {})
	high_sanctum["continuity"] = 100
	var low_gain := int(low.call("_apply_offline_accrual_if_needed", 2, "test.offline.low"))
	var high_gain := int(high.call("_apply_offline_accrual_if_needed", 2, "test.offline.high"))
	if high_gain <= low_gain:
		return { "ok": false, "error": "Expected high continuity gain (%d) to exceed low continuity gain (%d)" % [high_gain, low_gain] }
	return { "ok": true }
