extends RefCounted
class_name SanctumSummonTests

# Minimal config for EchoFactory.generate() tests.
# Keep this local so tests don’t depend on ConfigService.
static func _summoning_cfg() -> Dictionary:
	return {
		"trait_min": 30,
		"trait_max": 70,
		# Calling weights (MVP): uncalled heavily favored.
		"calling_weights": {"uncalled": 0.9, "called": 0.05, "chosen": 0.05},
		# Make base HP explicit for this test suite.
		"birth_stats": {"hp_base": 100}
	}

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum.summon/echo_factory_same_path_is_identical", Callable(SanctumSummonTests, "_t_same_path_is_identical"))
	runner.register_test("sanctum.summon/echo_factory_diff_path_differs", Callable(SanctumSummonTests, "_t_diff_path_differs"))
	runner.register_test("sanctum.summon/starter_uses_reserved_namespace", Callable(SanctumSummonTests, "_t_starter_namespace"))
	runner.register_test("sanctum.summon/paid_uses_reserved_namespace", Callable(SanctumSummonTests, "_t_paid_namespace"))
	runner.register_test("sanctum.summon/gender_is_present_and_valid", Callable(SanctumSummonTests, "_t_gender_valid"))
	runner.register_test("sanctum.summon/placeholder_required_fields_exist", Callable(SanctumSummonTests, "_t_required_fields_exist"))
	runner.register_test("sanctum.summon/base_hp_is_at_least_100", Callable(SanctumSummonTests, "_t_base_hp_at_least_100"))
	runner.register_test("sanctum.summon/paid_summon_spends_60_each", Callable(SanctumSummonTests, "_t_paid_summon_spends_60_each"))
	runner.register_test("sanctum.summon/paid_summon_appends_roster_and_increments_count", Callable(SanctumSummonTests, "_t_paid_summon_appends_roster_and_increments_count"))
	runner.register_test("sanctum.summon/reveal_queue_is_transient_not_saved", Callable(SanctumSummonTests, "_t_reveal_queue_transient_not_saved"))

# -------------------------
# Tests (must return Dictionary)
# -------------------------

static func _t_same_path_is_identical() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"
	var path := "campaign.summon.0"

	var a: Dictionary = EchoFactory.generate(seed_root, path, 0, "summon", cfg)
	var b: Dictionary = EchoFactory.generate(seed_root, path, 0, "summon", cfg)

	var fp_a := _fingerprint(a)
	var fp_b := _fingerprint(b)

	if fp_a != fp_b:
		return { "ok": false, "error": "Expected identical fingerprints for same seed_root+path. fp_a=%s fp_b=%s" % [fp_a, fp_b] }
	return { "ok": true }

static func _t_diff_path_differs() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var a: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.0", 0, "summon", cfg)
	var b: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.1", 1, "summon", cfg)

	var fp_a := _fingerprint(a)
	var fp_b := _fingerprint(b)

	if fp_a == fp_b:
		return { "ok": false, "error": "Expected different fingerprints for different paths, but they matched: %s" % fp_a }
	return { "ok": true }

static func _t_starter_namespace() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var e: Dictionary = EchoFactory.generate(seed_root, "campaign.starter.0", 0, "starter", cfg)

	if str(e.get("seed_path", "")) != "campaign.starter.0":
		return { "ok": false, "error": "Starter must use campaign.starter.* namespace" }
	if str(e.get("origin", "")) != "starter":
		return { "ok": false, "error": "Starter origin must be 'starter'" }
	return { "ok": true }

static func _t_paid_namespace() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var e: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.12", 12, "summon", cfg)

	if str(e.get("seed_path", "")) != "campaign.summon.12":
		return { "ok": false, "error": "Paid must use campaign.summon.* namespace" }
	if str(e.get("origin", "")) != "summon":
		return { "ok": false, "error": "Paid origin must be 'summon'" }
	return { "ok": true }

static func _t_gender_valid() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var e: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.2", 2, "summon", cfg)
	var g := str(e.get("gender", ""))

	if not (g == "male" or g == "female"):
		return { "ok": false, "error": "gender must be 'male' or 'female', got '%s'" % g }
	return { "ok": true }

static func _t_required_fields_exist() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var e: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.3", 3, "summon", cfg)

	var required := [
		"id", "name", "gender", "seed_path", "summon_index",
		"origin", "xp_total", "rank", "archetype_birth",
		"calling_origin", "traits", "stats", "rarity",
		"vector_scores", "generation_context"
	]

	for k in required:
		if not e.has(k):
			return { "ok": false, "error": "Missing required field: %s" % k }

	if not (e.get("traits") is Dictionary):
		return { "ok": false, "error": "traits must be Dictionary" }
	if not (e.get("stats") is Dictionary):
		return { "ok": false, "error": "stats must be Dictionary" }

	return { "ok": true }

static func _t_base_hp_at_least_100() -> Dictionary:
	var cfg := _summoning_cfg()
	var seed_root := "TEST_SEED"

	var e: Dictionary = EchoFactory.generate(seed_root, "campaign.summon.4", 4, "summon", cfg)
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	var max_hp := int(stats.get("max_hp", 0))
	if max_hp < 100:
		return { "ok": false, "error": "Expected max_hp >= 100, got %d" % max_hp }

	return { "ok": true }

static func _t_paid_summon_spends_60_each() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	# Prevent unexpected settle-time gains during this test by making delta=0.
	var now_unix := 123456
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ

	# Ensure we have enough Ase to cover 2 summons.
	var snap1 := runtime.dispatch({
		"type": "economy.ase.add",
		"amount": 500,
		"reason": "test.seed"
	})
	# Move to summon state (some handlers/UI logic assume this).
	runtime.dispatch({"type": "flow.go_state", "to": "flow.summon"})

	var before := int(EconomyService.new(runtime.get_save_data()).get_ase())
	var snap2 := runtime.dispatch({
		"type": "sanctum.summon",
		"count": 2,
		"now_unix": now_unix
	})
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())

	var expected_delta := 60 * 2
	var actual_delta := before - after
	if actual_delta != expected_delta:
		return {
			"ok": false,
			"error": "Expected Ase spend %d for 2 summons (60 each). before=%d after=%d delta=%d" % [expected_delta, before, after, actual_delta]
		}

	return {"ok": true}

static func _t_paid_summon_appends_roster_and_increments_count() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	# Ensure we have enough Ase to cover 3 summons.
	runtime.dispatch({
		"type": "economy.ase.add",
		"amount": 500,
		"reason": "test.seed"
	})
	runtime.dispatch({"type": "flow.go_state", "to": "flow.summon"})

	var save_before: Dictionary = runtime.get_save_data()
	var sanctum_v: Variant = save_before.get("sanctum", {})
	var sanctum_before: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_before: Array = sanctum_before.get("roster", [])
	var summon_count_before := int(sanctum_before.get("summon_count", 0))
	var roster_before_size := roster_before.size()

	var now_unix := 222222
	var econ_v: Variant = save_before.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_before["economy"] = econ

	runtime.dispatch({
		"type": "sanctum.summon",
		"count": 3,
		"now_unix": now_unix
	})

	var save_after: Dictionary = runtime.get_save_data()
	var sanctum2_v: Variant = save_after.get("sanctum", {})
	var sanctum_after: Dictionary = sanctum2_v if sanctum2_v is Dictionary else {}
	var roster_after: Array = sanctum_after.get("roster", [])
	var summon_count_after := int(sanctum_after.get("summon_count", 0))

	if roster_after.size() != roster_before_size + 3:
		return {
			"ok": false,
			"error": "Expected roster +3. before=%d after=%d" % [roster_before_size, roster_after.size()]
		}

	if summon_count_after != summon_count_before + 3:
		return {
			"ok": false,
			"error": "Expected summon_count +3. before=%d after=%d" % [summon_count_before, summon_count_after]
		}

	return {"ok": true}

static func _t_reveal_queue_transient_not_saved() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	runtime.dispatch({
		"type": "economy.ase.add",
		"amount": 500,
		"reason": "test.seed"
	})
	runtime.dispatch({"type": "flow.go_state", "to": "flow.summon"})

	var now_unix := 333333
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ

	# Trigger a summon so pending reveal data exists in runtime context/snapshot.
	runtime.dispatch({
		"type": "sanctum.summon",
		"count": 1,
		"now_unix": now_unix
	})

	# The reveal queue must NOT be persisted in the save dictionary.
	var save_after: Dictionary = runtime.get_save_data()
	if save_after.has("pending_reveals"):
		return {"ok": false, "error": "Save must not contain pending_reveals at root"}

	var sanctum_v: Variant = save_after.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	if sanctum.has("pending_reveals"):
		return {"ok": false, "error": "Save must not contain sanctum.pending_reveals"}

	# Also ensure the save doesn't contain obvious UI-only keys.
	if save_after.has("ui"):
		var ui_v: Variant = save_after.get("ui", {})
		var ui: Dictionary = ui_v if ui_v is Dictionary else {}
		if ui.has("pending_reveals"):
			return {"ok": false, "error": "Save must not contain ui.pending_reveals"}

	return {"ok": true}

# -------------------------
# Helpers
# -------------------------

static func _fingerprint(e: Dictionary) -> String:
	var traits_v: Variant = e.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var stats_v: Variant = e.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}

	return "%s|%s|%s|%s|c%dw%df%d|hp%datk%ddef%dagi%dint%dcha%d" % [
		str(e.get("name", "")),
		str(e.get("gender", "")),
		str(e.get("calling_origin", "")),
		str(e.get("archetype_birth", "")),
		int(traits.get("courage", 0)),
		int(traits.get("wisdom", 0)),
		int(traits.get("faith", 0)),
		int(stats.get("max_hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("agi", 0)),
		int(stats.get("int", 0)),
		int(stats.get("cha", 0)),
	]

static func _make_runtime_env() -> Dictionary:
	# Creates a FlowRuntime wired like AppRoot, but with logging off.
	# Returns { ok=true, runtime=FlowRuntime } or { ok=false, error=... }.

	var FlowRuntimeScript := load("res://core/runtime/FlowRuntime.gd")
	var ConfigServiceScript := load("res://core/config/ConfigService.gd")
	var StructuredLoggerScript := load("res://core/log/StructuredLogger.gd")

	if FlowRuntimeScript == null:
		return {"ok": false, "error": "FlowRuntime script not found at expected path"}
	if ConfigServiceScript == null:
		return {"ok": false, "error": "ConfigService script not found at expected path"}
	if StructuredLoggerScript == null:
		return {"ok": false, "error": "StructuredLogger script not found at expected path"}

	var logger = StructuredLoggerScript.new()
	logger.set_level("off")

	var config = ConfigServiceScript.new()
	var runtime = FlowRuntimeScript.new(logger, config)
	runtime.boot()

	# Sanity: ensure we can access save.
	if not runtime.has_method("get_save_data"):
		return {"ok": false, "error": "FlowRuntime.get_save_data() missing"}

	return {"ok": true, "runtime": runtime}
