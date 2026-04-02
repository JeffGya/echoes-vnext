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
	runner.register_test("vow_pledge_sets_active_vow",           Callable(VowServiceTests, "_test_pledge_sets_active_vow"))
	runner.register_test("vow_pledge_denied_no_unlock",          Callable(VowServiceTests, "_test_pledge_denied_not_unlocked"))
	runner.register_test("vow_break_applies_ase_penalty",        Callable(VowServiceTests, "_test_break_applies_ase_penalty"))
	runner.register_test("vow_release_clears_no_penalty",        Callable(VowServiceTests, "_test_release_no_penalty"))
	runner.register_test("vow_is_tier_available",                Callable(VowServiceTests, "_test_is_tier_available"))
	runner.register_test("vow_unlock_adds_entry",                Callable(VowServiceTests, "_test_unlock_adds_entry"))
	runner.register_test("vow_pledge_denied_already_active",     Callable(VowServiceTests, "_test_pledge_denied_already_active"))


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
			"unlocked_vows": [],
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


## unlock_vow adds an entry to unlocked_vows; duplicate unlock is a no-op.
static func _test_unlock_adds_entry() -> Dictionary:
	var save := _make_save()
	var logger := _make_logger()

	VowService.unlock_vow("tikoro_nko_agyina", "realm.01", save, null, logger, 0)
	var unlocked := VowService.get_unlocked_vows(save)

	if unlocked.size() != 1:
		return { "ok": false, "error": "Expected 1 unlocked vow, got %d" % unlocked.size() }

	# Duplicate unlock should be a no-op
	VowService.unlock_vow("tikoro_nko_agyina", "realm.02", save, null, logger, 1)
	unlocked = VowService.get_unlocked_vows(save)
	if unlocked.size() != 1:
		return { "ok": false, "error": "Duplicate unlock should not add a second entry" }

	return { "ok": true }
