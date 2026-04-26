# res://tests/VowServiceTests.gd
# VOW-001: VowService unit tests.
# Tests cover: pledge, break, release, unlock, is_tier_available.
# No OS time, no RNG, no save file I/O.

class_name VowServiceTests
extends RefCounted

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("vow/pledge_sets_active_vow",                   Callable(VowServiceTests, "_test_pledge_sets_active_vow"))
	runner.register_test("vow/pledge_denied_no_unlock",                  Callable(VowServiceTests, "_test_pledge_denied_not_unlocked"))
	runner.register_test("vow/break_applies_ase_penalty",                Callable(VowServiceTests, "_test_break_applies_ase_penalty"))
	runner.register_test("vow/release_clears_no_penalty",                Callable(VowServiceTests, "_test_release_no_penalty"))
	runner.register_test("vow/is_tier_available",                        Callable(VowServiceTests, "_test_is_tier_available"))
	runner.register_test("vow/unlock_adds_entry",                        Callable(VowServiceTests, "_test_unlock_adds_entry"))
	runner.register_test("vow/pledge_denied_already_active",             Callable(VowServiceTests, "_test_pledge_denied_already_active"))
	# V2-VOW-001: release_vow_if_due
	runner.register_test("vow/release_if_due_realm_completed",           Callable(VowServiceTests, "_test_release_if_due_realm_completed"))
	runner.register_test("vow/release_if_due_realm_still_active",        Callable(VowServiceTests, "_test_release_if_due_realm_still_active"))
	runner.register_test("vow/release_if_due_run_count_increased",       Callable(VowServiceTests, "_test_release_if_due_run_count_increased"))
	# V2-VOW-001: condition evaluation
	runner.register_test("vow/condition_tikoro_compliant",               Callable(VowServiceTests, "_test_condition_tikoro_compliant"))
	runner.register_test("vow/condition_tikoro_violated",                Callable(VowServiceTests, "_test_condition_tikoro_violated"))
	runner.register_test("vow/condition_tikoro_auto_break",              Callable(VowServiceTests, "_test_condition_tikoro_auto_break"))
	runner.register_test("vow/condition_praye_compliant",                Callable(VowServiceTests, "_test_condition_praye_compliant"))
	runner.register_test("vow/condition_praye_violated",                 Callable(VowServiceTests, "_test_condition_praye_violated"))
	runner.register_test("vow/condition_no_active_vow",                  Callable(VowServiceTests, "_test_condition_no_active_vow"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_save() -> Dictionary:
	return {
		"economy":  { "ase": 300, "ekwan": 50 },
		"sanctum":  {
			"roster": [],
			"active_party_ids": [],
			"bonds": [],
			"party_encounters": [],
			"active_vow": {},
			"vows": {},  # V2-MIG-002: canonical Dict shape (keyed by vow_id)
		},
		"realms": {},
	}


static func _make_cfg() -> Dictionary:
	# Minimal balance config that matches VowService's get_definitions() path.
	return {
		"data": {
			"bonds": { "friend_min": 30, "rival_max": -30 },
			"vows": {
				"definitions": {
					"tikoro_nko_agyina": {
						"vow_id":          "tikoro_nko_agyina",
						"proverb_twi":     "Tikoro nko agyina",
						"proverb_en":      "One head does not constitute a council",
						"vow_name":        "Vow of Collective Counsel",
						"benefit_label":   "Full party deployments (3+) gain fear resistance.",
						"tradeoff_label":  "Small deployments incur a fear penalty.",
						"benefit":         { "party_size_threshold": 3, "fear_resistance_bonus": 15 },
						"tradeoff":        { "small_party_fear_penalty": 10 },
						"tier_effects":    { "1": { "multiplier": 1.0 }, "2": { "multiplier": 1.5 } },
						"breaking_costs":  {
							"1": { "ase": 60, "morale_delta": -10, "bond_score_delta": 0 },
							"2": { "ase": 120, "ekwan": 20, "fear_delta": 15, "bond_score_delta": -20 },
						},
						"unlock_scenario":    "small_party_all_survived",
						"unlock_description": "After a small-party stage where all survived.",
					}
				},
				"tier_names": { "1": "Whisper", "2": "Oath" },
			}
		}
	}


static func _make_ctx(save: Dictionary) -> Dictionary:
	# Lightweight ctx stand-in (Dictionary mimics RefCounted property access via dict keys).
	# VowService._set_save_request uses ctx.get() / ctx.set() — a Dictionary works here
	# because GDScript's ctx.get("key") falls back to null for plain Dicts.
	# We just verify save_data directly in tests.
	return { "save_request": false, "save_request_reason": "", "realm_id": "realm.01" }


static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Pledging an unlocked vow sets active_vow in save_data.
static func _test_pledge_sets_active_vow() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()

	# Pre-unlock tier 1
	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)

	var ctx := _make_ctx(save)
	var ok := VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	if not ok:
		return { "ok": false, "error": "pledge_vow returned false" }

	var av: Dictionary = VowService.get_active_vow(save)
	if av.get("vow_id", "") != "tikoro_nko_agyina":
		return { "ok": false, "error": "active_vow.vow_id expected 'tikoro_nko_agyina', got '%s'" % av.get("vow_id", "") }
	if int(av.get("tier", 0)) != 1:
		return { "ok": false, "error": "active_vow.tier expected 1, got %d" % int(av.get("tier", 0)) }

	return { "ok": true }


## Pledging a vow that has NOT been unlocked is denied.
static func _test_pledge_denied_not_unlocked() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()

	# Do NOT unlock — pledge should fail.
	var ok := VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 0)
	if ok:
		return { "ok": false, "error": "pledge_vow should return false when vow not unlocked" }

	var av := VowService.get_active_vow(save)
	if not av.is_empty():
		return { "ok": false, "error": "active_vow should be empty after denied pledge" }

	return { "ok": true }


## Pledging when a vow is already active is denied.
static func _test_pledge_denied_already_active() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	# Try pledging again — should be denied.
	var ok := VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 2)
	if ok:
		return { "ok": false, "error": "Second pledge should return false when vow already active" }

	return { "ok": true }


## Breaking a tier 1 vow deducts the correct Ase penalty and clears active_vow.
static func _test_break_applies_ase_penalty() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()
	var econ := EconomyService.new(save)

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	var ase_before := econ.get_ase()
	var summary := VowService.break_vow(cfg, save, null, econ, logger, 2)

	if summary.is_empty():
		return { "ok": false, "error": "break_vow returned empty summary" }

	var ase_after := econ.get_ase()
	var expected_cost := 60
	if ase_before - ase_after != expected_cost:
		return { "ok": false, "error": "Expected Ase cost of %d, got %d" % [expected_cost, ase_before - ase_after] }

	var av := VowService.get_active_vow(save)
	if not av.is_empty():
		return { "ok": false, "error": "active_vow should be empty after break" }

	return { "ok": true }


## Releasing a vow applies NO penalty and clears active_vow.
static func _test_release_no_penalty() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()
	var econ := EconomyService.new(save)

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	var ase_before := econ.get_ase()
	VowService.release_vow(save, null, logger, 2)

	var ase_after := econ.get_ase()
	if ase_before != ase_after:
		return { "ok": false, "error": "release_vow should not deduct Ase (before=%d, after=%d)" % [ase_before, ase_after] }

	var av := VowService.get_active_vow(save)
	if not av.is_empty():
		return { "ok": false, "error": "active_vow should be empty after release" }

	return { "ok": true }


## is_tier_available returns false for tier above max_tier_unlocked.
static func _test_is_tier_available() -> Dictionary:
	var save := _make_save()
	var logger := _make_logger()

	# Unlock at tier 1 ceiling
	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)

	if not VowService.is_tier_available("tikoro_nko_agyina", 1, save):
		return { "ok": false, "error": "Tier 1 should be available after unlock" }

	if VowService.is_tier_available("tikoro_nko_agyina", 2, save):
		return { "ok": false, "error": "Tier 2 should NOT be available (max_tier_unlocked=1)" }

	return { "ok": true }


## Helpers shared by new tests.
static func _make_save_with_realm(realm_status: String) -> Dictionary:
	var save := _make_save()
	save["realms"] = {
		"realm.01": { "id": "realm.01", "status": realm_status, "run_count": 1 }
	}
	return save


## unlock_vow adds an entry to vows dict; duplicate unlock is a no-op.
static func _test_unlock_adds_entry() -> Dictionary:
	var save := _make_save()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	var unlocked: Dictionary = VowService.get_unlocked_vows(save)

	if not unlocked.has("tikoro_nko_agyina"):
		return { "ok": false, "error": "Expected vow entry after unlock" }
	if int(unlocked["tikoro_nko_agyina"].get("tier", 0)) != 1:
		return { "ok": false, "error": "Expected tier 1 after unlock" }
	if str(unlocked["tikoro_nko_agyina"].get("discovered_realm", "")) != "realm.01":
		return { "ok": false, "error": "Expected discovered_realm 'realm.01'" }

	# Duplicate unlock should be a no-op (discovered_realm stays original)
	VowService.unlock_vow("tikoro_nko_agyina", "realm.02", save, null, logger, 1)
	unlocked = VowService.get_unlocked_vows(save)
	if unlocked.size() != 1:
		return { "ok": false, "error": "Duplicate unlock should not add a second entry" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-VOW-001: release_vow_if_due tests
# ---------------------------------------------------------------------------

## Pledged during realm.01 — realm completes → vow releases.
static func _test_release_if_due_realm_completed() -> Dictionary:
	var save   := _make_save_with_realm("completed")  # realm is no longer active
	var cfg    := _make_cfg()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)
	# Verify pledged_at_realm is set.
	var av_before := VowService.get_active_vow(save)
	if str(av_before.get("pledged_at_realm", "")) != "realm.01":
		return { "ok": false, "error": "pledged_at_realm should be 'realm.01'" }

	var released := VowService.release_vow_if_due(save, null, logger, 2)
	if not released:
		return { "ok": false, "error": "release_vow_if_due should return true when realm is completed" }

	var av_after := VowService.get_active_vow(save)
	if not av_after.is_empty():
		return { "ok": false, "error": "active_vow should be empty after release" }

	return { "ok": true }


## Pledged during realm.01 — realm still active → no release.
static func _test_release_if_due_realm_still_active() -> Dictionary:
	var save   := _make_save_with_realm("active")  # realm still active
	var cfg    := _make_cfg()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	var released := VowService.release_vow_if_due(save, null, logger, 2)
	if released:
		return { "ok": false, "error": "release_vow_if_due should return false when realm is still active" }

	var av := VowService.get_active_vow(save)
	if av.is_empty():
		return { "ok": false, "error": "active_vow should remain set when realm is still active" }

	return { "ok": true }


## Pledged from Sanctum (no active realm) — run_count increased → releases.
static func _test_release_if_due_run_count_increased() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg()
	var logger := _make_logger()

	# No realms initially (runs_at_pledge will be 0).
	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	var av := VowService.get_active_vow(save)
	if str(av.get("pledged_at_realm", "x")) != "":
		return { "ok": false, "error": "pledged_at_realm should be '' when no active realm" }
	if int(av.get("runs_at_pledge", -1)) != 0:
		return { "ok": false, "error": "runs_at_pledge should be 0 with no realms" }

	# Simulate a realm run completing by adding a realm with run_count=1.
	save["realms"] = { "realm.01": { "id": "realm.01", "status": "completed", "run_count": 1 } }

	var released := VowService.release_vow_if_due(save, null, logger, 2)
	if not released:
		return { "ok": false, "error": "release_vow_if_due should return true when run_count increased" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-VOW-001: condition evaluation tests
# ---------------------------------------------------------------------------

static func _make_save_with_active_vow(vow_id: String) -> Dictionary:
	var save := _make_save()
	var logger := _make_logger()
	var cfg := _make_cfg()
	VowService.unlock_vow(vow_id, "realm.01", save, null, logger, 0)
	VowService.pledge_vow(vow_id, 1, cfg, save, null, logger, 1)
	return save


## tikoro_nko_agyina — party=3 → compliant, morale bonus, consecutive reset to 0.
static func _test_condition_tikoro_compliant() -> Dictionary:
	var save   := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg    := _make_cfg()
	var party  := ["echo.a", "echo.b", "echo.c"]

	var result := VowService.evaluate_stage_condition(save, party, cfg)
	if str(result.get("status", "")) != "compliant":
		return { "ok": false, "error": "Expected status 'compliant', got '%s'" % result.get("status", "") }
	if int(result.get("morale_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected morale_delta > 0 for compliant party" }
	if bool(result.get("should_auto_break", true)):
		return { "ok": false, "error": "should_auto_break must be false on compliant" }

	var av := VowService.get_active_vow(save)
	if int(av.get("consecutive_small_deployments", -1)) != 0:
		return { "ok": false, "error": "consecutive_small_deployments should be reset to 0" }

	return { "ok": true }


## tikoro_nko_agyina — party=2 → violated, fear penalty, consecutive=1.
static func _test_condition_tikoro_violated() -> Dictionary:
	var save   := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg    := _make_cfg()
	var party  := ["echo.a", "echo.b"]

	var result := VowService.evaluate_stage_condition(save, party, cfg)
	if str(result.get("status", "")) != "violated":
		return { "ok": false, "error": "Expected status 'violated', got '%s'" % result.get("status", "") }
	if int(result.get("fear_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected fear_delta > 0 for violated party" }
	if bool(result.get("should_auto_break", false)):
		return { "ok": false, "error": "should_auto_break must be false on first violation" }

	var av := VowService.get_active_vow(save)
	if int(av.get("consecutive_small_deployments", 0)) != 1:
		return { "ok": false, "error": "consecutive_small_deployments should be 1 after first violation" }

	return { "ok": true }


## tikoro_nko_agyina — two consecutive small deployments → should_auto_break=true.
static func _test_condition_tikoro_auto_break() -> Dictionary:
	var save   := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg    := _make_cfg()
	var party  := ["echo.a", "echo.b"]

	# First violation
	VowService.evaluate_stage_condition(save, party, cfg)
	# Second violation
	var result := VowService.evaluate_stage_condition(save, party, cfg)

	if not bool(result.get("should_auto_break", false)):
		return { "ok": false, "error": "should_auto_break must be true on second consecutive violation" }

	return { "ok": true }


## praye_wokabomu — party has 2 distinct callings → compliant, morale bonus.
static func _test_condition_praye_compliant() -> Dictionary:
	var save  := _make_save()
	var cfg   := _make_cfg_with_praye()
	var logger := _make_logger()
	VowService.unlock_vow("praye_wokabomu", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("praye_wokabomu", 1, cfg, save, null, logger, 1)

	# Add two roster echoes with distinct calling_origins.
	save["sanctum"]["roster"] = [
		{ "id": "echo.a", "calling_origin": "okofor" },
		{ "id": "echo.b", "calling_origin": "aduro" },
	]
	var party := ["echo.a", "echo.b"]

	var result := VowService.evaluate_stage_condition(save, party, cfg)
	if str(result.get("status", "")) != "compliant":
		return { "ok": false, "error": "Expected 'compliant' for diverse party, got '%s'" % result.get("status", "") }
	if int(result.get("morale_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected morale_delta > 0 for compliant diverse party" }

	return { "ok": true }


## praye_wokabomu — all party echoes share same calling_origin → violated, fear penalty.
static func _test_condition_praye_violated() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg_with_praye()
	var logger := _make_logger()
	VowService.unlock_vow("praye_wokabomu", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("praye_wokabomu", 1, cfg, save, null, logger, 1)

	# Both echoes share the same calling_origin.
	save["sanctum"]["roster"] = [
		{ "id": "echo.a", "calling_origin": "okofor" },
		{ "id": "echo.b", "calling_origin": "okofor" },
	]
	var party := ["echo.a", "echo.b"]

	var result := VowService.evaluate_stage_condition(save, party, cfg)
	if str(result.get("status", "")) != "violated":
		return { "ok": false, "error": "Expected 'violated' for same-calling party, got '%s'" % result.get("status", "") }
	if int(result.get("fear_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected fear_delta > 0 for violated party" }

	return { "ok": true }


## No active vow → evaluate_stage_condition returns status "none", no deltas.
static func _test_condition_no_active_vow() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg()
	var party  := ["echo.a", "echo.b"]

	var result := VowService.evaluate_stage_condition(save, party, cfg)
	if str(result.get("status", "")) != "none":
		return { "ok": false, "error": "Expected status 'none' with no active vow, got '%s'" % result.get("status", "") }
	if int(result.get("morale_delta", 0)) != 0 or int(result.get("fear_delta", 0)) != 0:
		return { "ok": false, "error": "Expected zero deltas with no active vow" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Config helper for praye_wokabomu tests
# ---------------------------------------------------------------------------

static func _make_cfg_with_praye() -> Dictionary:
	var cfg := _make_cfg()
	cfg["data"]["vows"]["definitions"]["praye_wokabomu"] = {
		"vow_id":         "praye_wokabomu",
		"proverb_twi":    "Praye, se woyi baako a na ebu; wokabomu a emmu",
		"proverb_en":     "When you remove one broomstick it breaks, but together they do not break",
		"vow_name":       "Vow of United Strength",
		"benefit_label":  "Diverse parties gain morale.",
		"tradeoff_label": "Same-calling parties incur fear.",
		"benefit":        { "calling_diversity_threshold": 2, "morale_bonus_on_entry": 3 },
		"tradeoff":       { "single_calling_fear_penalty": 8 },
		"tier_effects":   { "1": { "multiplier": 1.0 } },
		"breaking_costs": { "1": { "ase": 60, "morale_delta": -10, "bond_score_delta": -10 } },
		"unlock_scenario": "full_roster_diversity",
	}
	return cfg
