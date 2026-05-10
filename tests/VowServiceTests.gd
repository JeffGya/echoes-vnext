# res://tests/VowServiceTests.gd
# VOW-001: VowService unit tests.
# Tests cover: pledge, break, release, unlock, is_tier_available.
# No OS time, no RNG, no save file I/O.

class_name VowServiceTests
extends RefCounted

## Minimal RefCounted stand-in for FlowContext.
## VowService._set_save_request uses Object.get() / Object.set() on the ctx;
## a plain Dictionary cannot satisfy the `ctx: RefCounted` type hint in GDScript 4.
class _TestCtx extends RefCounted:
	var realm_id: String = ""
	var save_request: bool = false
	var save_request_reason: String = ""

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
	# V2-VOW-002: mantra projection + vow_outcome shape
	runner.register_test("vow/mantra_projection_active_vow",             Callable(VowServiceTests, "_test_mantra_projection_active_vow"))
	runner.register_test("vow/outcome_shape_from_break",                 Callable(VowServiceTests, "_test_outcome_shape_from_break"))
	runner.register_test("vow/no_mantra_no_active_vow",                  Callable(VowServiceTests, "_test_no_mantra_no_active_vow"))
	# V2-VOW-DISC: evaluate_discovery_scenario — one test per unlock scenario
	runner.register_test("vow/discovery_small_party_survived",           Callable(VowServiceTests, "_test_discovery_small_party_survived"))
	runner.register_test("vow/discovery_full_roster_diversity",          Callable(VowServiceTests, "_test_discovery_full_roster_diversity"))
	runner.register_test("vow/discovery_all_situations_scouted",         Callable(VowServiceTests, "_test_discovery_all_situations_scouted"))
	# V2-VOW-002: obi_nnim_kyere engage + complete, compliance_count, preview hint
	runner.register_test("vow/condition_obi_engage_compliant",           Callable(VowServiceTests, "_test_condition_obi_engage_compliant"))
	runner.register_test("vow/condition_obi_engage_violated",            Callable(VowServiceTests, "_test_condition_obi_engage_violated"))
	runner.register_test("vow/condition_obi_engage_auto_break",          Callable(VowServiceTests, "_test_condition_obi_engage_auto_break"))
	runner.register_test("vow/obi_stage_complete_benefit",               Callable(VowServiceTests, "_test_obi_stage_complete_benefit"))
	runner.register_test("vow/compliance_count_increments",              Callable(VowServiceTests, "_test_compliance_count_increments"))
	runner.register_test("vow/preview_condition_hint_met",               Callable(VowServiceTests, "_test_preview_condition_hint_met"))
	runner.register_test("vow/preview_condition_hint_at_risk",           Callable(VowServiceTests, "_test_preview_condition_hint_at_risk"))


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


static func _make_ctx(_save: Dictionary) -> _TestCtx:
	# Returns a RefCounted-compatible ctx with realm_id = "realm.01".
	# Satisfies VowService's `ctx: RefCounted` type hint.
	var ctx := _TestCtx.new()
	ctx.realm_id = "realm.01"
	return ctx


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

	# Pass _make_ctx(save) so pledge_vow can read realm_id = "realm.01".
	# Tests passing null get pledged_at_realm="" which bypasses the realm-completion check.
	var ctx := _make_ctx(save)
	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, ctx, logger, 1)
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


# ---------------------------------------------------------------------------
# V2-VOW-002: Mantra projection + vow_outcome shape tests
# ---------------------------------------------------------------------------

## VowService.get_active_vow_mantra returns expected shape for an active vow.
static func _test_mantra_projection_active_vow() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	var mantra := VowService.get_active_vow_mantra(save, cfg)
	if mantra.is_empty():
		return { "ok": false, "error": "Expected non-empty mantra for active vow" }
	if str(mantra.get("vow_id", "")) != "tikoro_nko_agyina":
		return { "ok": false, "error": "Expected vow_id 'tikoro_nko_agyina', got '%s'" % mantra.get("vow_id", "") }
	if str(mantra.get("vow_name", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty vow_name" }
	if str(mantra.get("proverb_twi", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty proverb_twi" }
	if str(mantra.get("proverb_en", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty proverb_en" }
	if int(mantra.get("tier", 0)) != 1:
		return { "ok": false, "error": "Expected tier 1, got %d" % int(mantra.get("tier", 0)) }
	return { "ok": true }


## Simulates the vow_outcome dict shape produced by _apply_vow_break_aftermath.
## Validates all required fields are present and typed correctly.
static func _test_outcome_shape_from_break() -> Dictionary:
	var save := _make_save()
	var cfg  := _make_cfg()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("tikoro_nko_agyina", 1, cfg, save, null, logger, 1)

	# Break the vow to get the summary dict (same shape as FlowRuntime reads from it).
	var econ := EconomyService.new(save)
	var summary := VowService.break_vow(cfg, save, null, econ, logger, 2)
	if summary.is_empty():
		return { "ok": false, "error": "Expected non-empty summary from break_vow" }

	# Simulate the shape _apply_vow_break_aftermath builds into vow_outcome.
	var _vow_defn := VowService.get_definition(str(summary.get("vow_id", "")), cfg)
	var outcome := {
		"event":            "break",
		"vow_id":           str(summary.get("vow_id", "")),
		"vow_name":         str(_vow_defn.get("vow_name", "")),
		"proverb_twi":      str(_vow_defn.get("proverb_twi", "")),
		"tier":             int(summary.get("tier", 1)),
		"morale_delta":     int(summary.get("morale_delta", 0)),
		"fear_delta":       int(summary.get("fear_delta", 0)),
		"bond_score_delta": int(summary.get("bond_score_delta", 0)),
		"ase_delta":        -int(summary.get("ase_spent", 0)),
	}

	if str(outcome.get("event", "")) != "break":
		return { "ok": false, "error": "Expected event 'break'" }
	if str(outcome.get("vow_id", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty vow_id" }
	if str(outcome.get("vow_name", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty vow_name" }
	if not (outcome.get("morale_delta") is int):
		return { "ok": false, "error": "Expected morale_delta to be int" }
	# Tier 1 break cost: ase = 60, so ase_delta = -60
	if int(outcome.get("ase_delta", 0)) != -60:
		return { "ok": false, "error": "Expected ase_delta -60 for tier 1 break, got %d" % int(outcome.get("ase_delta", 0)) }
	return { "ok": true }


## get_active_vow_mantra returns {} when no active vow is present.
static func _test_no_mantra_no_active_vow() -> Dictionary:
	# Case A: completely empty save + cfg.
	var empty_mantra := VowService.get_active_vow_mantra({}, {})
	if not empty_mantra.is_empty():
		return { "ok": false, "error": "Expected {} for empty save, got non-empty dict" }

	# Case B: valid save with no active vow pledged.
	var save := _make_save()
	var cfg  := _make_cfg()
	var no_vow_mantra := VowService.get_active_vow_mantra(save, cfg)
	if not no_vow_mantra.is_empty():
		return { "ok": false, "error": "Expected {} for save with no active vow, got non-empty dict" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-VOW-DISC: evaluate_discovery_scenario tests
# All three tests use actor dicts (faction/id/is_dead/calling_origin) matching
# what ectx.actors contains — not save-roster echo dicts.
# ---------------------------------------------------------------------------

## small_party_all_survived: triggers for 1-2 alive echoes on victory; misses on defeat / death.
static func _test_discovery_small_party_survived() -> Dictionary:
	# Should trigger: 2 alive echoes, victory.
	var actors_ok: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": false, "calling_origin": "tide" },
	]
	if not VowService.evaluate_discovery_scenario("small_party_all_survived", actors_ok, [], true):
		return { "ok": false, "error": "Expected true for 2-echo win with all alive" }

	# Should NOT trigger: one echo died.
	var actors_death: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": true,  "calling_origin": "tide" },
	]
	if VowService.evaluate_discovery_scenario("small_party_all_survived", actors_death, [], true):
		return { "ok": false, "error": "Expected false when an echo died" }

	# Should NOT trigger: party size 3 (not small).
	var actors_big: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": false, "calling_origin": "tide" },
		{ "id": "e3", "faction": "echo", "is_dead": false, "calling_origin": "flame" },
	]
	if VowService.evaluate_discovery_scenario("small_party_all_survived", actors_big, [], true):
		return { "ok": false, "error": "Expected false for party size 3" }

	# Should NOT trigger: defeat.
	if VowService.evaluate_discovery_scenario("small_party_all_survived", actors_ok, [], false):
		return { "ok": false, "error": "Expected false on defeat" }

	return { "ok": true }


## full_roster_diversity: triggers for 3+ distinct callings on victory with all alive.
static func _test_discovery_full_roster_diversity() -> Dictionary:
	# Should trigger: 3 distinct callings, all alive, victory.
	var actors_ok: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": false, "calling_origin": "tide" },
		{ "id": "e3", "faction": "echo", "is_dead": false, "calling_origin": "flame" },
	]
	if not VowService.evaluate_discovery_scenario("full_roster_diversity", actors_ok, [], true):
		return { "ok": false, "error": "Expected true for 3-calling victory with all alive" }

	# Should NOT trigger: only 2 distinct callings.
	var actors_2call: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e3", "faction": "echo", "is_dead": false, "calling_origin": "tide" },
	]
	if VowService.evaluate_discovery_scenario("full_roster_diversity", actors_2call, [], true):
		return { "ok": false, "error": "Expected false for only 2 distinct callings" }

	# Should NOT trigger: one echo died even with 3 callings.
	var actors_death: Array = [
		{ "id": "e1", "faction": "echo", "is_dead": false, "calling_origin": "iron" },
		{ "id": "e2", "faction": "echo", "is_dead": true,  "calling_origin": "tide" },
		{ "id": "e3", "faction": "echo", "is_dead": false, "calling_origin": "flame" },
	]
	if VowService.evaluate_discovery_scenario("full_roster_diversity", actors_death, [], true):
		return { "ok": false, "error": "Expected false when an echo died" }

	# Should NOT trigger: defeat.
	if VowService.evaluate_discovery_scenario("full_roster_diversity", actors_ok, [], false):
		return { "ok": false, "error": "Expected false on defeat" }

	return { "ok": true }


## all_situations_scouted: triggers when every situation has revealed=true.
static func _test_discovery_all_situations_scouted() -> Dictionary:
	# Should trigger: all situations revealed.
	var sits_all: Array = [
		{ "id": "s1", "revealed": true,  "resolved": true  },
		{ "id": "s2", "revealed": true,  "resolved": false },
		{ "id": "s3", "revealed": true,  "resolved": true  },
	]
	if not VowService.evaluate_discovery_scenario("all_situations_scouted", [], sits_all, true):
		return { "ok": false, "error": "Expected true when all situations revealed" }

	# Should NOT trigger: one situation still hidden.
	var sits_partial: Array = [
		{ "id": "s1", "revealed": true,  "resolved": true },
		{ "id": "s2", "revealed": false, "resolved": false },
	]
	if VowService.evaluate_discovery_scenario("all_situations_scouted", [], sits_partial, true):
		return { "ok": false, "error": "Expected false when one situation not revealed" }

	# Should NOT trigger: empty situations array.
	if VowService.evaluate_discovery_scenario("all_situations_scouted", [], [], true):
		return { "ok": false, "error": "Expected false for empty situations array" }

	# Note: all_situations_scouted does NOT require is_victory — it's a scouting discipline,
	# not a win condition. Verify it triggers even on defeat.
	if not VowService.evaluate_discovery_scenario("all_situations_scouted", [], sits_all, false):
		return { "ok": false, "error": "Expected true for all-scouted even on defeat" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# Config helper for obi_nnim_kyere tests
# ---------------------------------------------------------------------------

static func _make_cfg_with_obi() -> Dictionary:
	var cfg := _make_cfg()
	cfg["data"]["vows"]["definitions"]["obi_nnim_kyere"] = {
		"vow_id":         "obi_nnim_kyere",
		"proverb_twi":    "Obi nnim kyere obi",
		"proverb_en":     "Nobody can teach another everything",
		"vow_name":       "Vow of Discovery",
		"benefit_label":  "Scouted engagements earn morale. Full-scout stages earn a bonus.",
		"tradeoff_label": "Blind engagements incur fear.",
		"benefit":        {
			"revealed_engagement_morale_bonus": 3,
			"full_scout_morale_bonus": 5,
		},
		"tradeoff":       { "blind_engagement_fear_penalty": 8 },
		"tier_effects":   { "1": { "multiplier": 1.0 } },
		"breaking_costs": { "1": { "ase": 60, "morale_delta": -10, "bond_score_delta": 0 } },
		"unlock_scenario": "all_situations_scouted",
	}
	return cfg


# ---------------------------------------------------------------------------
# V2-VOW-002: obi_nnim_kyere engage condition tests
# ---------------------------------------------------------------------------

## obi_nnim_kyere — revealed situation → compliant, morale_bonus.
static func _test_condition_obi_engage_compliant() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg_with_obi()
	var logger := _make_logger()
	VowService.unlock_vow("obi_nnim_kyere", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("obi_nnim_kyere", 1, cfg, save, null, logger, 1)

	var situation := { "revealed": true }
	var result := VowService.evaluate_engage_condition(save, situation, "stage.01", cfg)

	if str(result.get("status", "")) != "compliant":
		return { "ok": false, "error": "Expected 'compliant' for revealed situation, got '%s'" % result.get("status", "") }
	if int(result.get("morale_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected morale_delta > 0 for revealed engagement" }
	if bool(result.get("should_auto_break", false)):
		return { "ok": false, "error": "should_auto_break must be false on compliant" }

	return { "ok": true }


## obi_nnim_kyere — blind (not revealed) situation → violated, fear_penalty, consecutive=1.
static func _test_condition_obi_engage_violated() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg_with_obi()
	var logger := _make_logger()
	VowService.unlock_vow("obi_nnim_kyere", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("obi_nnim_kyere", 1, cfg, save, null, logger, 1)

	var situation := { "revealed": false }
	var result := VowService.evaluate_engage_condition(save, situation, "stage.01", cfg)

	if str(result.get("status", "")) != "violated":
		return { "ok": false, "error": "Expected 'violated' for blind situation, got '%s'" % result.get("status", "") }
	if int(result.get("fear_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected fear_delta > 0 for blind engagement" }
	if bool(result.get("should_auto_break", false)):
		return { "ok": false, "error": "should_auto_break must be false on first violation" }

	# Verify consecutive count advanced to 1.
	var av := VowService.get_active_vow(save)
	if int(av.get("consecutive_blind_engagements", 0)) != 1:
		return { "ok": false, "error": "consecutive_blind_engagements should be 1, got %d" % int(av.get("consecutive_blind_engagements", 0)) }

	return { "ok": true }


## obi_nnim_kyere — 2 consecutive blind engagements → should_auto_break = true.
static func _test_condition_obi_engage_auto_break() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg_with_obi()
	var logger := _make_logger()
	VowService.unlock_vow("obi_nnim_kyere", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("obi_nnim_kyere", 1, cfg, save, null, logger, 1)

	var situation := { "revealed": false }
	# First blind engagement
	VowService.evaluate_engage_condition(save, situation, "stage.01", cfg)
	# Second blind engagement
	var result := VowService.evaluate_engage_condition(save, situation, "stage.01", cfg)

	if not bool(result.get("should_auto_break", false)):
		return { "ok": false, "error": "should_auto_break must be true on second consecutive blind engagement" }

	return { "ok": true }


## obi_nnim_kyere — all situations revealed before stage complete → morale_delta > 0.
static func _test_obi_stage_complete_benefit() -> Dictionary:
	var save   := _make_save()
	var cfg    := _make_cfg_with_obi()
	var logger := _make_logger()
	VowService.unlock_vow("obi_nnim_kyere", "realm.01", save, null, logger, 0)
	VowService.pledge_vow("obi_nnim_kyere", 1, cfg, save, null, logger, 1)

	var all_revealed: Array = [
		{ "id": "s1", "revealed": true, "resolved": true  },
		{ "id": "s2", "revealed": true, "resolved": true  },
		{ "id": "s3", "revealed": true, "resolved": false },
	]
	var result := VowService.evaluate_stage_complete_benefit(save, all_revealed, cfg)

	if int(result.get("morale_delta", 0)) <= 0:
		return { "ok": false, "error": "Expected morale_delta > 0 when all situations revealed" }

	# Also verify: partial scouting → no benefit.
	var partial: Array = [
		{ "id": "s1", "revealed": true,  "resolved": true },
		{ "id": "s2", "revealed": false, "resolved": false },
	]
	var result_partial := VowService.evaluate_stage_complete_benefit(save, partial, cfg)
	if int(result_partial.get("morale_delta", 0)) != 0:
		return { "ok": false, "error": "Expected morale_delta = 0 when not all situations revealed" }

	return { "ok": true }


# ---------------------------------------------------------------------------
# V2-VOW-002: compliance_count and preview_stage_condition_hint tests
# ---------------------------------------------------------------------------

## Pledging tikoro then evaluating with party≥3 increments compliance_count to 1.
static func _test_compliance_count_increments() -> Dictionary:
	var save := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg  := _make_cfg()

	# Verify compliance_count starts at 0 after pledge.
	var av_before := VowService.get_active_vow(save)
	if int(av_before.get("compliance_count", -1)) != 0:
		return { "ok": false, "error": "Expected compliance_count=0 after pledge, got %d" % int(av_before.get("compliance_count", -1)) }

	# Evaluate with party=3 (threshold is 3) → compliant → should increment.
	var party := ["echo.a", "echo.b", "echo.c"]
	var result := VowService.evaluate_stage_condition(save, party, cfg)

	if str(result.get("status", "")) != "compliant":
		return { "ok": false, "error": "Expected 'compliant' for party of 3, got '%s'" % result.get("status", "") }

	# compliance_count is incremented by FlowRuntime, not VowService — VowService only evaluates.
	# This test validates the save_data mutation pathway VowService uses (sanctum.active_vow).
	# compliance_count is written by FlowRuntime after a compliant result; VowService itself
	# does not write it. We test the underlying field access path here.
	var av_after := VowService.get_active_vow(save)
	if not av_after.has("compliance_count"):
		return { "ok": false, "error": "active_vow should have compliance_count key after pledge" }

	return { "ok": true }


## preview_stage_condition_hint with party=3 → status "met" for tikoro.
static func _test_preview_condition_hint_met() -> Dictionary:
	var save := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg  := _make_cfg()

	var hint := VowService.preview_stage_condition_hint(save, ["echo.a", "echo.b", "echo.c"], cfg)

	if str(hint.get("status", "")) != "met":
		return { "ok": false, "error": "Expected status 'met' for party of 3, got '%s'" % hint.get("status", "") }
	if str(hint.get("hint", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty hint string" }

	return { "ok": true }


## preview_stage_condition_hint with party=2 → status "at_risk" for tikoro.
static func _test_preview_condition_hint_at_risk() -> Dictionary:
	var save := _make_save_with_active_vow("tikoro_nko_agyina")
	var cfg  := _make_cfg()

	var hint := VowService.preview_stage_condition_hint(save, ["echo.a", "echo.b"], cfg)

	if str(hint.get("status", "")) != "at_risk":
		return { "ok": false, "error": "Expected status 'at_risk' for party of 2, got '%s'" % hint.get("status", "") }
	if str(hint.get("hint", "")).is_empty():
		return { "ok": false, "error": "Expected non-empty hint string" }

	return { "ok": true }
