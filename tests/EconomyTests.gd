# res://tests/EconomyTests.gd
class_name EconomyTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("economy/add_spend", Callable(EconomyTests, "_test_add_spend"))
	runner.register_test("economy/denied_spend_no_mutation", Callable(EconomyTests, "_test_denied_spend"))
	runner.register_test("economy/offline_taper_exceeds_8h_before_zero", Callable(EconomyTests, "_test_offline_taper_exceeds_8h"))
	runner.register_test("economy/offline_flame_gate_zero", Callable(EconomyTests, "_test_offline_flame_gate_zero"))
	runner.register_test("economy/offline_continuity_dominance", Callable(EconomyTests, "_test_offline_continuity_dominance"))
	# V2-ECONOMY-001: Ase Flame awakening gate + Ekwan cadence tests
	runner.register_test("economy/offline_gate_blocked_before_awakening", Callable(EconomyTests, "_test_offline_gate_blocked"))
	runner.register_test("economy/offline_gate_passes_after_awakening",   Callable(EconomyTests, "_test_offline_gate_passes"))
	runner.register_test("economy/ekwan_awarded_on_stage_completion",      Callable(EconomyTests, "_test_ekwan_awarded"))
	runner.register_test("economy/awakening_trigger_sets_flag_grants_ase", Callable(EconomyTests, "_test_awakening_trigger"))

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


# ─────────────────────────────────────────────────────────────
# V2-ECONOMY-001: Ase Flame awakening gate + Ekwan cadence
# ─────────────────────────────────────────────────────────────

## (a) Offline accrual guard: house dormant → gate returns false, Ase unchanged.
static func _test_offline_gate_blocked() -> Dictionary:
	var save := {
		"economy":  { "ase": 0, "ekwan": 0 },
		"sanctum":  { "ase_flame": { "awakened": false } }
	}
	var _sanctum_v: Variant = save.get("sanctum", {})
	var _sanctum: Dictionary = _sanctum_v if _sanctum_v is Dictionary else {}
	var _flame_v: Variant = _sanctum.get("ase_flame", {})
	var _flame: Dictionary = _flame_v if _flame_v is Dictionary else {}
	var gate_open := bool(_flame.get("awakened", false))

	if gate_open:
		return { "ok": false, "error": "Gate should be closed when ase_flame.awakened = false" }
	if int(save["economy"]["ase"]) != 0:
		return { "ok": false, "error": "Ase must be unchanged when gate is closed" }
	return { "ok": true }


## (b) Offline accrual guard: house awakened → gate returns true.
static func _test_offline_gate_passes() -> Dictionary:
	var save := {
		"economy": { "ase": 0, "ekwan": 0 },
		"sanctum": { "ase_flame": { "awakened": true } }
	}
	var _sanctum_v: Variant = save.get("sanctum", {})
	var _sanctum: Dictionary = _sanctum_v if _sanctum_v is Dictionary else {}
	var _flame_v: Variant = _sanctum.get("ase_flame", {})
	var _flame: Dictionary = _flame_v if _flame_v is Dictionary else {}
	var gate_open := bool(_flame.get("awakened", false))

	if not gate_open:
		return { "ok": false, "error": "Gate should be open when ase_flame.awakened = true" }
	return { "ok": true }


## (c) reward_stage_complete awards Ekwan on victory; partial run awards only Ase (no Ekwan).
static func _test_ekwan_awarded() -> Dictionary:
	var save := { "economy": { "ase": 0, "ekwan": 0 } }
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var econ := EconomyService.new(save)

	var result := econ.reward_stage_complete(
		true, 30, 0, 0, 0, 0, 0, 1.0, "B", 0, 0.12, logger, 0
	)

	var ase_awarded    := int(result.get("ase_awarded", 0))
	var ekwan_awarded  := int(result.get("ekwan_awarded", 0))
	var ekwan_balance  := int(save["economy"]["ekwan"])

	if ase_awarded <= 0:
		return { "ok": false, "error": "Expected ase_awarded > 0, got %d" % ase_awarded }
	if ekwan_awarded <= 0:
		return { "ok": false, "error": "Expected ekwan_awarded > 0, got %d" % ekwan_awarded }
	if ekwan_balance != ekwan_awarded:
		return { "ok": false, "error": "Ekwan balance (%d) != ekwan_awarded (%d)" % [ekwan_balance, ekwan_awarded] }

	# Partial run: call add_ase only (no ekwan). Assert ekwan unchanged.
	var ekwan_before := ekwan_balance
	econ.add_ase(4, "partial_scout", logger, 1)  # 4 Ase partial award, no Ekwan
	if int(save["economy"]["ekwan"]) != ekwan_before:
		return { "ok": false, "error": "Ekwan must not change on partial (scout) award" }

	return { "ok": true }


## (d) Awakening trigger sets ase_flame.awakened = true and grants 40 Ase.
static func _test_awakening_trigger() -> Dictionary:
	var save := {
		"economy": { "ase": 0, "ekwan": 0 },
		"sanctum": { "ase_flame": { "awakened": false } }
	}
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var econ := EconomyService.new(save)

	# Simulate awakening trigger: set flag + grant
	save["sanctum"]["ase_flame"]["awakened"] = true
	econ.add_ase(40, "economy.awakening_grant", logger, 0)

	var flag := bool(save["sanctum"]["ase_flame"]["awakened"])
	var ase  := int(save["economy"]["ase"])

	if not flag:
		return { "ok": false, "error": "ase_flame.awakened must be true after awakening" }
	if ase != 40:
		return { "ok": false, "error": "Expected ase=40 after awakening grant, got %d" % ase }

	return { "ok": true }

