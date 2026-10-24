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
	runner.register_test("sanctum.summon/paid_summon_spends_rising_prices", Callable(SanctumSummonTests, "_t_paid_summon_spends_rising_prices"))
	runner.register_test("sanctum.summon/paid_summon_appends_roster_and_increments_count", Callable(SanctumSummonTests, "_t_paid_summon_appends_roster_and_increments_count"))
	runner.register_test("sanctum.summon/reveal_queue_is_transient_not_saved", Callable(SanctumSummonTests, "_t_reveal_queue_transient_not_saved"))
	# ECONOMY-003: Grade-based summon cost tests
	runner.register_test("sanctum.summon/uncalled_grade_spends_60", Callable(SanctumSummonTests, "_t_uncalled_grade_spends_60"))
	runner.register_test("sanctum.summon/called_grade_spends_150", Callable(SanctumSummonTests, "_t_called_grade_spends_150"))
	runner.register_test("sanctum.summon/denied_when_balance_insufficient_for_grade", Callable(SanctumSummonTests, "_t_denied_when_balance_insufficient_for_grade"))
	runner.register_test("sanctum.summon/summon_disabled_true_when_insufficient", Callable(SanctumSummonTests, "_t_summon_disabled_true_when_insufficient"))
	runner.register_test("sanctum.summon/summon_disabled_false_when_sufficient", Callable(SanctumSummonTests, "_t_summon_disabled_false_when_sufficient"))
	# V2-ECONOMY-004 Phase 5.5: price by village size
	runner.register_test("sanctum.summon/price_table_echo_2_to_16", Callable(SanctumSummonTests, "_t_price_table"))
	runner.register_test("sanctum.summon/called_chosen_prices", Callable(SanctumSummonTests, "_t_called_chosen_prices"))
	runner.register_test("sanctum.summon/living_count_helper", Callable(SanctumSummonTests, "_t_living_count"))
	runner.register_test("sanctum.summon/batch_of_3_at_echo_4_pays_sum", Callable(SanctumSummonTests, "_t_batch_pays_sum"))
	runner.register_test("sanctum.summon/denied_when_batch_total_short", Callable(SanctumSummonTests, "_t_denied_batch_short"))
	runner.register_test("sanctum.summon/snapshot_batch_fields", Callable(SanctumSummonTests, "_t_snapshot_batch_fields"))
	runner.register_test("sanctum.summon/snapshot_short_by_and_disabled", Callable(SanctumSummonTests, "_t_snapshot_short_by"))
	runner.register_test("sanctum.summon/snapshot_price_flat_at_ceiling", Callable(SanctumSummonTests, "_t_price_flat"))
	runner.register_test("sanctum.summon/grade_options_carry_next_and_after", Callable(SanctumSummonTests, "_t_grade_options_prices"))
	runner.register_test("sanctum.summon/all_skills_cost_60", Callable(SanctumSummonTests, "_t_skills_cost_60"))
	runner.register_test("sanctum.summon/legacy_price_config_removed", Callable(SanctumSummonTests, "_t_legacy_config_removed"))

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

static func _t_paid_summon_spends_rising_prices() -> Dictionary:
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

	# Roster of 3: the two Echoes bought are Echo 4 (70) and Echo 5 (85).
	_set_roster(save_ref, 3)
	econ["ase"] = 500
	# Move to summon state (some handlers/UI logic assume this).
	runtime.dispatch({"type": "flow.go_state", "to": "flow.summon"})

	var before := int(EconomyService.new(runtime.get_save_data()).get_ase())
	var snap2 := runtime.dispatch({
		"type": "sanctum.summon",
		"count": 2,
		"now_unix": now_unix
	})
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())

	var expected_delta := 70 + 85
	var actual_delta := before - after
	if actual_delta != expected_delta:
		return {
			"ok": false,
			"error": "Expected Ase spend %d for Echo 4 and 5. before=%d after=%d delta=%d" % [expected_delta, before, after, actual_delta]
		}

	return {"ok": true}

static func _t_paid_summon_appends_roster_and_increments_count() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]

	runtime.dispatch({"type": "flow.go_state", "to": "flow.summon"})

	var save_before: Dictionary = runtime.get_save_data()
	_set_roster(save_before, 1)
	(save_before["economy"] as Dictionary)["ase"] = 500
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

	_set_roster(save_ref, 1)
	(save_ref["economy"] as Dictionary)["ase"] = 500
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

# ECONOMY-003: Grade-based summon cost tests

static func _t_uncalled_grade_spends_60() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	var now_unix := 111111
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ

	econ["ase"] = 500
	_set_roster(save_ref, 1)
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	# grade_select "uncalled" explicitly (grade already resets to uncalled on enter)
	runtime.dispatch({ "type": "sanctum.grade_select", "grade": "uncalled" })

	var before := int(EconomyService.new(runtime.get_save_data()).get_ase())
	runtime.dispatch({ "type": "sanctum.summon", "count": 1, "now_unix": now_unix })
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())

	var delta := before - after
	if delta != 60:
		return { "ok": false, "error": "Expected -60 Ase for uncalled summon. before=%d after=%d delta=%d" % [before, after, delta] }
	return { "ok": true }

static func _t_called_grade_spends_150() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	var now_unix := 222222
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ

	econ["ase"] = 500
	_set_roster(save_ref, 1)
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	runtime.dispatch({ "type": "sanctum.grade_select", "grade": "called" })

	var before := int(EconomyService.new(runtime.get_save_data()).get_ase())
	runtime.dispatch({ "type": "sanctum.summon", "count": 1, "now_unix": now_unix })
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())

	var delta := before - after
	if delta != 150:
		return { "ok": false, "error": "Expected -150 Ase for called summon. before=%d after=%d delta=%d" % [before, after, delta] }
	return { "ok": true }

static func _t_denied_when_balance_insufficient_for_grade() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	var now_unix := 333333
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	# Set Ase directly (not via add) so existing save balance doesn't interfere
	econ["ase"] = 100
	econ["last_settle_unix"] = now_unix
	save_ref["economy"] = econ
	_set_roster(save_ref, 1)

	# 100 Ase — enough for uncalled (60) but NOT called (150)
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	runtime.dispatch({ "type": "sanctum.grade_select", "grade": "called" })

	var before := int(EconomyService.new(runtime.get_save_data()).get_ase())
	runtime.dispatch({ "type": "sanctum.summon", "count": 1, "now_unix": now_unix })
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())

	if before != after:
		return { "ok": false, "error": "Balance should be unchanged when denied. before=%d after=%d" % [before, after] }
	return { "ok": true }

static func _t_summon_disabled_true_when_insufficient() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	# Set Ase directly (not via add) so existing save balance doesn't interfere
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["ase"] = 100
	save_ref["economy"] = econ
	_set_roster(save_ref, 1)

	# 100 Ase, select "called" (costs 150) — should disable summon
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	var snap: Dictionary = runtime.dispatch({ "type": "sanctum.grade_select", "grade": "called" })

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if not data.get("summon_disabled", false):
		return { "ok": false, "error": "Expected summon_disabled=true when balance(100) < called cost(150). snap_data=%s" % [str(data)] }

	var reason := str(data.get("summon_disabled_reason", ""))
	if reason != "not_enough_ase":
		return { "ok": false, "error": "Expected summon_disabled_reason='not_enough_ase', got '%s'" % reason }

	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var cta_v: Variant = actions.get("cta.summon", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}
	if not bool(cta.get("disabled", false)):
		return { "ok": false, "error": "Expected cta.summon.disabled=true in snapshot actions" }

	return { "ok": true }

static func _t_summon_disabled_false_when_sufficient() -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env

	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()

	# Balance 500, roster 1, select "chosen" (60 + 340 = 400) — should NOT disable summon
	(save_ref["economy"] as Dictionary)["ase"] = 500
	_set_roster(save_ref, 1)
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	var snap: Dictionary = runtime.dispatch({ "type": "sanctum.grade_select", "grade": "chosen" })

	var data_v: Variant = snap.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}

	if bool(data.get("summon_disabled", true)):
		return { "ok": false, "error": "Expected summon_disabled=false when balance(500) >= chosen cost(400). snap_data=%s" % [str(data)] }

	var reason := str(data.get("summon_disabled_reason", "x"))
	if reason != "":
		return { "ok": false, "error": "Expected summon_disabled_reason='' when not disabled, got '%s'" % reason }

	var actions_v: Variant = snap.get("actions", {})
	var actions: Dictionary = actions_v if actions_v is Dictionary else {}
	var cta_v: Variant = actions.get("cta.summon", {})
	var cta: Dictionary = cta_v if cta_v is Dictionary else {}
	if bool(cta.get("disabled", true)):
		return { "ok": false, "error": "Expected cta.summon.disabled=false in snapshot actions" }

	return { "ok": true }


# -------------------------
# V2-ECONOMY-004 Phase 5.5: price by village size
# -------------------------

static func _summ_cfg() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var bal: Dictionary = config.get_balance()
	return (bal.get("data", {}) as Dictionary).get("summoning", {}) as Dictionary

static func _set_roster(save_ref: Dictionary, n: int) -> void:
	var sanctum_v: Variant = save_ref.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster: Array = []
	for i in range(n):
		roster.append({ "id": "echo_%04d" % (i + 1) })
	sanctum["roster"] = roster
	save_ref["sanctum"] = sanctum

## Runtime in the SUMMON state with a pinned roster size and balance.
static func _summon_env(roster_n: int, ase: int) -> Dictionary:
	var env := _make_runtime_env()
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var save_ref: Dictionary = runtime.get_save_data()
	_set_roster(save_ref, roster_n)
	var econ_v: Variant = save_ref.get("economy", {})
	var econ: Dictionary = econ_v if econ_v is Dictionary else {}
	econ["ase"] = ase
	econ["last_settle_unix"] = 555555
	save_ref["economy"] = econ
	runtime.dispatch({ "type": "flow.go_state", "to": "flow.summon" })
	return env

static func _summon_data(runtime: FlowRuntime) -> Dictionary:
	var snap: Dictionary = runtime.dispatch({ "type": "sanctum.grade_select", "grade": "uncalled" })
	return snap.get("data", {}) as Dictionary

static func _t_price_table() -> Dictionary:
	var cfg := _summ_cfg()
	var expected := {
		2: 60, 3: 60, 4: 70, 5: 85, 6: 100, 7: 120, 8: 145, 9: 175, 10: 210,
		11: 250, 12: 300, 13: 360, 14: 430, 15: 430, 16: 430,
	}
	for n: int in expected:
		var got := SummonService.price_for(cfg, "uncalled", n)
		if got != int(expected[n]):
			return { "ok": false, "error": "Echo %d: expected %d, got %d" % [n, int(expected[n]), got] }
	if SummonService.village_ceiling(cfg) != 14:
		return { "ok": false, "error": "village_ceiling expected 14" }
	return { "ok": true }

static func _t_called_chosen_prices() -> Dictionary:
	var cfg := _summ_cfg()
	var cases := [["called", 2, 150], ["chosen", 2, 400], ["called", 4, 160], ["chosen", 4, 410], ["called", 14, 520], ["chosen", 20, 770]]
	for c: Array in cases:
		var got := SummonService.price_for(cfg, str(c[0]), int(c[1]))
		if got != int(c[2]):
			return { "ok": false, "error": "%s at Echo %d: expected %d, got %d" % [c[0], c[1], c[2], got] }
	return { "ok": true }

static func _t_living_count() -> Dictionary:
	var save: Dictionary = {}
	if SummonService.living_count(save) != 0:
		return { "ok": false, "error": "no sanctum should count 0" }
	_set_roster(save, 5)
	if SummonService.living_count(save) != 5:
		return { "ok": false, "error": "roster of 5 should count 5" }
	return { "ok": true }

static func _t_batch_pays_sum() -> Dictionary:
	var env := _summon_env(3, 1000)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	runtime.dispatch({ "type": "sanctum.summon", "count": 3, "now_unix": 555555 })
	var after := int(EconomyService.new(runtime.get_save_data()).get_ase())
	if 1000 - after != 255:
		return { "ok": false, "error": "Batch of 3 at Echo 4 should pay 70+85+100=255, paid %d" % (1000 - after) }
	return { "ok": true }

static func _t_denied_batch_short() -> Dictionary:
	# 254 pays 3 x 70 = 210 but not 70+85+100 = 255.
	var env := _summon_env(3, 254)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var snap: Dictionary = runtime.dispatch({ "type": "sanctum.summon", "count": 3, "now_unix": 555555 })
	var save: Dictionary = runtime.get_save_data()
	if int(EconomyService.new(save).get_ase()) != 254:
		return { "ok": false, "error": "Balance must stay 254 when the batch total is short" }
	if SummonService.living_count(save) != 3:
		return { "ok": false, "error": "Roster must not grow on a denied batch" }
	var denied: Dictionary = (snap.get("data", {}) as Dictionary).get("summon_denied", {}) as Dictionary
	if str(denied.get("reason", "")) != "insufficient_ase" or int(denied.get("total_cost", 0)) != 255:
		return { "ok": false, "error": "Denied outcome should carry reason and total 255, got %s" % str(denied) }
	return { "ok": true }

static func _t_snapshot_batch_fields() -> Dictionary:
	var env := _summon_env(3, 200)
	if not bool(env.get("ok", false)):
		return env
	var d := _summon_data(env["runtime"])
	var prices: Array = d.get("batch_prices", [])
	var totals: Array = d.get("batch_totals", [])
	if prices.size() != 10 or totals.size() != 10:
		return { "ok": false, "error": "batch arrays must hold 10 entries" }
	if prices.slice(0, 4) != [70, 85, 100, 120]:
		return { "ok": false, "error": "batch_prices start wrong: %s" % str(prices) }
	if totals[2] != 255 or totals[9] != 1815:
		return { "ok": false, "error": "batch_totals wrong: %s" % str(totals) }
	if int(d.get("batch_affordable_max", -1)) != 2:
		return { "ok": false, "error": "200 Ase pays 70+85 = 155 but not 255: max 2, got %s" % str(d.get("batch_affordable_max")) }
	if int(d.get("living_count", -1)) != 3 or int(d.get("village_ceiling", -1)) != 14:
		return { "ok": false, "error": "living_count/village_ceiling wrong" }
	if int(d.get("ase_cost_per_summon", -1)) != 70:
		return { "ok": false, "error": "legacy key must equal the next uncalled price (70)" }
	if bool(d.get("summon_disabled", true)) or int(d.get("ase_short_by", -1)) != 0:
		return { "ok": false, "error": "200 Ase pays Echo 4: not disabled, short by 0" }
	return { "ok": true }

static func _t_snapshot_short_by() -> Dictionary:
	var env := _summon_env(3, 50)
	if not bool(env.get("ok", false)):
		return env
	var d := _summon_data(env["runtime"])
	if int(d.get("ase_short_by", -1)) != 20 or int(d.get("batch_affordable_max", -1)) != 0:
		return { "ok": false, "error": "50 Ase vs 70: short by 20, max 0. Got %s / %s" % [str(d.get("ase_short_by")), str(d.get("batch_affordable_max"))] }
	if not bool(d.get("summon_disabled", false)):
		return { "ok": false, "error": "summon_disabled must be true when no summon is affordable" }
	return { "ok": true }

static func _t_price_flat() -> Dictionary:
	# roster n buys Echo n+1; flat when Echo n+1 and Echo n+2 both sit at or above the ceiling.
	var cases := { 11: false, 12: false, 13: true, 14: true, 20: true }
	for n: int in cases:
		var env := _summon_env(n, 0)
		if not bool(env.get("ok", false)):
			return env
		var d := _summon_data(env["runtime"])
		if bool(d.get("price_flat", not cases[n])) != cases[n]:
			return { "ok": false, "error": "roster %d: price_flat expected %s" % [n, str(cases[n])] }
	return { "ok": true }

static func _t_grade_options_prices() -> Dictionary:
	var env := _summon_env(3, 1000)
	if not bool(env.get("ok", false)):
		return env
	var runtime: FlowRuntime = env["runtime"]
	var snap: Dictionary = runtime.dispatch({ "type": "sanctum.grade_select", "grade": "called" })
	var d: Dictionary = snap.get("data", {}) as Dictionary
	var want := { "uncalled": [70, 85], "called": [160, 175], "chosen": [410, 425] }
	for opt_v: Variant in d.get("summon_grade_options", []):
		var opt: Dictionary = opt_v
		var w: Array = want[str(opt["key"])]
		if int(opt["ase_cost"]) != w[0] or int(opt["ase_cost_after"]) != w[1]:
			return { "ok": false, "error": "%s: expected %s, got %s/%s" % [opt["key"], str(w), str(opt["ase_cost"]), str(opt["ase_cost_after"])] }
	if (d.get("batch_prices", []) as Array).slice(0, 2) != [160, 175]:
		return { "ok": false, "error": "batch_prices must follow the selected grade (called)" }
	return { "ok": true }

static func _t_skills_cost_60() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var bal: Dictionary = config.get_balance()
	var defs: Dictionary = ((bal.get("data", {}) as Dictionary).get("skills", {}) as Dictionary).get("definitions", {}) as Dictionary
	if defs.size() != 14:
		return { "ok": false, "error": "Expected 14 skill definitions, got %d" % defs.size() }
	for id: String in defs:
		var uc: Dictionary = (defs[id] as Dictionary).get("unlock_conditions", {}) as Dictionary
		if int(uc.get("ase_cost", -1)) != 60:
			return { "ok": false, "error": "%s: ase_cost expected 60, got %s" % [id, str(uc.get("ase_cost"))] }
	return { "ok": true }

static func _t_legacy_config_removed() -> Dictionary:
	var cfg := _summ_cfg()
	for k in ["ase_cost_per_summon", "ase_cost_per_summon_by_grade"]:
		if cfg.has(k):
			return { "ok": false, "error": "data.summoning.%s must be gone" % k }
	var hits: Array = []
	_scan_core("res://core", "ase_cost_per_summon_by_grade", hits)
	if not hits.is_empty():
		return { "ok": false, "error": "core/ still names the removed key: %s" % str(hits) }
	return { "ok": true }

static func _scan_core(dir_path: String, needle: String, hits: Array) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir_path + "/" + f).contains(needle):
			hits.append(dir_path + "/" + f)
	for d in DirAccess.get_directories_at(dir_path):
		_scan_core(dir_path + "/" + d, needle, hits)

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
	var runtime = FlowRuntimeScript.new(logger, config, TestSaveHarness.dir() + "sanctum_summon_slot.json")
	runtime.boot()

	# Sanity: ensure we can access save.
	if not runtime.has_method("get_save_data"):
		return {"ok": false, "error": "FlowRuntime.get_save_data() missing"}

	return {"ok": true, "runtime": runtime}
