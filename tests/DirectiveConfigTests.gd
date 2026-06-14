# res://tests/DirectiveConfigTests.gd
# V2-STAGE-004 Phase 2.5 — Tests for DirectiveService config loading.
#
# Tests:
#   1.  directive_cfg/scout_step_budget_3        — load_from_config: scout step_budget==3
#   2.  directive_cfg/seek_step_budget_6         — load_from_config: seek step_budget==6
#   3.  directive_cfg/scout_intel_retention_true — scout intel_retention==true
#   4.  directive_cfg/seek_intel_retention_false — seek intel_retention==false
#   5.  directive_cfg/scout_intent_weights       — scout has non-empty intent_weights
#   6.  directive_cfg/seek_intent_weights        — seek has non-empty intent_weights
#   7.  directive_cfg/extensibility_new_directive — synthetic cfg adds third directive, zero code change
#   8.  directive_cfg/fallback_on_empty_cfg      — empty cfg → still returns valid directive, no crash
#   9.  directive_cfg/fallback_missing_directives — missing directives block → falls back to _REGISTRY
#   10. directive_cfg/scout_target_preference     — scout has target_preference with intel/objective/combat/reward
#   11. directive_cfg/scout_reveal_radius_wider   — scout reveal_radius > seek reveal_radius (fog model)
#   12. directive_cfg/passive_reveal_both_true    — passive_reveal==true for both directives (Phase 2.5)

extends RefCounted
class_name DirectiveConfigTests


# ─── Helpers ────────────────────────────────────────────────────────────────

static func _make_save() -> Dictionary:
	return { "stage_context": { "active_directive_id": "directive.scout_carefully" } }


static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger


# Build a minimal cfg that mirrors balance.json structure for two directives.
# Values match the Phase 2.5 retune in balance.json:
#   Scout: step_budget=3, reveal_radius=3, passive_reveal=true, combat target_pref=0.4
#   Seek:  step_budget=6, reveal_radius=1, passive_reveal=true, combat target_pref=1.4
static func _make_minimal_cfg() -> Dictionary:
	return {
		"data": {
			"directives": {
				"directive.scout_carefully": {
					"id":                  "directive.scout_carefully",
					"label":               "Scout Carefully",
					"description":         "Moves carefully, scouts widely, withdraws safely, keeps intel.",
					"pros":                ["Benefit A", "Benefit B"],
					"cons":                ["Risk A",    "Risk B"],
					"intent_weights":      { "survival_bias": 0.4, "avoid_overcommit": 0.3 },
					"unlock_condition":    "always",
					"step_budget":         3,
					"reveal_radius":       3,
					"passive_reveal":      true,
					"passive_reveal_radius": 3,
					"target_preference":   { "intel": 1.4, "objective": 1.2, "combat": 0.4, "reward": 1.2 },
					"precise_intel_bias":  25,
					"exposure_tolerance":  0.3,
					"escape_bonus":        20,
					"intel_retention":     true,
					"intel_retention_bonus": 1.5,
				},
				"directive.seek_signs": {
					"id":                  "directive.seek_signs",
					"label":               "Seek Signs",
					"description":         "Presses forward, deals with whatever it runs into.",
					"pros":                ["Benefit A", "Benefit B"],
					"cons":                ["Risk A",    "Risk B"],
					"intent_weights":      { "clue_seeking_priority": 0.4, "reporting_priority": 0.3 },
					"unlock_condition":    "always",
					"step_budget":         6,
					"reveal_radius":       1,
					"passive_reveal":      true,
					"passive_reveal_radius": 1,
					"target_preference":   { "intel": 0.9, "objective": 1.6, "combat": 1.4, "reward": 0.9 },
					"precise_intel_bias":  75,
					"exposure_tolerance":  0.8,
					"escape_bonus":        0,
					"intel_retention":     false,
					"intel_retention_bonus": 1.0,
				},
			}
		}
	}


# Synthetic cfg with a third directive not in code — extensibility proof.
# Adding reveal_radius proves the fog model is also config-driven, no code change.
static func _make_synthetic_cfg() -> Dictionary:
	var cfg := _make_minimal_cfg()
	(cfg["data"] as Dictionary)["directives"]["directive.test_probe"] = {
		"id":                "directive.test_probe",
		"label":             "Test Probe",
		"description":       "A test-only directive.",
		"pros":              ["Pro 1", "Pro 2"],
		"cons":              ["Con 1", "Con 2"],
		"intent_weights":    { "probe_bias": 0.9 },
		"unlock_condition":  "always",
		"step_budget":       7,
		"reveal_radius":     4,
		"passive_reveal":    true,
		"passive_reveal_radius": 4,
		"target_preference": { "intel": 2.0, "objective": 0.5, "combat": 0.1, "reward": 0.4 },
		"precise_intel_bias": 10,
		"exposure_tolerance": 0.1,
		"escape_bonus":      15,
		"intel_retention":   true,
		"intel_retention_bonus": 1.2,
	}
	return cfg


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("directive_cfg/scout_step_budget_3",        Callable(DirectiveConfigTests, "_t_scout_step_budget_3"))
	runner.register_test("directive_cfg/seek_step_budget_6",         Callable(DirectiveConfigTests, "_t_seek_step_budget_6"))
	runner.register_test("directive_cfg/scout_intel_retention_true", Callable(DirectiveConfigTests, "_t_scout_intel_retention_true"))
	runner.register_test("directive_cfg/seek_intel_retention_false", Callable(DirectiveConfigTests, "_t_seek_intel_retention_false"))
	runner.register_test("directive_cfg/scout_intent_weights",       Callable(DirectiveConfigTests, "_t_scout_intent_weights"))
	runner.register_test("directive_cfg/seek_intent_weights",        Callable(DirectiveConfigTests, "_t_seek_intent_weights"))
	runner.register_test("directive_cfg/extensibility_new_directive", Callable(DirectiveConfigTests, "_t_extensibility_new_directive"))
	runner.register_test("directive_cfg/fallback_on_empty_cfg",      Callable(DirectiveConfigTests, "_t_fallback_on_empty_cfg"))
	runner.register_test("directive_cfg/fallback_missing_directives", Callable(DirectiveConfigTests, "_t_fallback_missing_directives"))
	runner.register_test("directive_cfg/scout_target_preference",    Callable(DirectiveConfigTests, "_t_scout_target_preference"))
	runner.register_test("directive_cfg/scout_reveal_radius_wider",  Callable(DirectiveConfigTests, "_t_scout_reveal_radius_wider"))
	runner.register_test("directive_cfg/passive_reveal_both_true",   Callable(DirectiveConfigTests, "_t_passive_reveal_both_true"))


# ─── Test 1 — scout step_budget == 3 after load_from_config ─────────────────
static func _t_scout_step_budget_3() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.scout_carefully", logger, 1)
	var defn := svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() returned empty after set" }
	var sb := int(defn.get("step_budget", -1))
	if sb != 3:
		return { "ok": false, "error": "scout step_budget expected 3, got %d" % sb }
	return { "ok": true }


# ─── Test 2 — seek step_budget == 6 after load_from_config ──────────────────
static func _t_seek_step_budget_6() -> Dictionary:
	var save := _make_save()
	var svc  := DirectiveService.new(save)
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.seek_signs", logger, 1)
	var defn := svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() returned empty for seek_signs" }
	var sb := int(defn.get("step_budget", -1))
	if sb != 6:
		return { "ok": false, "error": "seek step_budget expected 6, got %d" % sb }
	return { "ok": true }


# ─── Test 3 — scout intel_retention == true ──────────────────────────────────
static func _t_scout_intel_retention_true() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.scout_carefully", logger, 1)
	var defn := svc.get_active_directive()
	if not bool(defn.get("intel_retention", false)):
		return { "ok": false, "error": "scout intel_retention should be true" }
	return { "ok": true }


# ─── Test 4 — seek intel_retention == false ──────────────────────────────────
static func _t_seek_intel_retention_false() -> Dictionary:
	var save := _make_save()
	var svc  := DirectiveService.new(save)
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.seek_signs", logger, 1)
	var defn := svc.get_active_directive()
	if bool(defn.get("intel_retention", true)):
		return { "ok": false, "error": "seek intel_retention should be false" }
	return { "ok": true }


# ─── Test 5 — scout has non-empty intent_weights ─────────────────────────────
static func _t_scout_intent_weights() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.scout_carefully", logger, 1)
	var defn := svc.get_active_directive()
	var iw_v: Variant = defn.get("intent_weights", null)
	if not (iw_v is Dictionary):
		return { "ok": false, "error": "scout intent_weights is not a Dictionary" }
	var iw: Dictionary = iw_v
	if iw.is_empty():
		return { "ok": false, "error": "scout intent_weights should be non-empty (combat behavior intact)" }
	return { "ok": true }


# ─── Test 6 — seek has non-empty intent_weights ──────────────────────────────
static func _t_seek_intent_weights() -> Dictionary:
	var save := _make_save()
	var svc  := DirectiveService.new(save)
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.seek_signs", logger, 1)
	var defn := svc.get_active_directive()
	var iw_v: Variant = defn.get("intent_weights", null)
	if not (iw_v is Dictionary):
		return { "ok": false, "error": "seek intent_weights is not a Dictionary" }
	var iw: Dictionary = iw_v
	if iw.is_empty():
		return { "ok": false, "error": "seek intent_weights should be non-empty (combat behavior intact)" }
	return { "ok": true }


# ─── Test 7 — EXTENSIBILITY: synthetic third directive, no code change needed ─
static func _t_extensibility_new_directive() -> Dictionary:
	var save := { "stage_context": { "active_directive_id": "directive.test_probe" } }
	var svc  := DirectiveService.new(save)
	svc.load_from_config(_make_synthetic_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.test_probe", logger, 1)
	var defn := svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() returned empty for synthetic directive" }
	if str(defn.get("id", "")) != "directive.test_probe":
		return { "ok": false, "error": "Expected id 'directive.test_probe', got '%s'" % defn.get("id", "") }
	var sb := int(defn.get("step_budget", -1))
	if sb != 7:
		return { "ok": false, "error": "test_probe step_budget expected 7, got %d" % sb }
	var tp_v: Variant = defn.get("target_preference", null)
	if not (tp_v is Dictionary):
		return { "ok": false, "error": "test_probe target_preference is not a Dictionary" }
	var tp: Dictionary = tp_v
	if abs(float(tp.get("intel", 0.0)) - 2.0) > 0.001:
		return { "ok": false, "error": "test_probe target_preference.intel expected 2.0, got %s" % str(tp.get("intel", 0.0)) }
	var eb := int(defn.get("escape_bonus", -1))
	if eb != 15:
		return { "ok": false, "error": "test_probe escape_bonus expected 15, got %d" % eb }
	return { "ok": true }


# ─── Test 8 — FALLBACK: empty cfg → valid directive, no crash ────────────────
static func _t_fallback_on_empty_cfg() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config({})  # totally empty
	var defn := svc.get_active_directive()
	if defn.is_empty():
		return { "ok": false, "error": "get_active_directive() must not return empty dict on empty cfg fallback" }
	var id := str(defn.get("id", ""))
	if id.is_empty():
		return { "ok": false, "error": "Fallback directive missing 'id' field" }
	return { "ok": true }


# ─── Test 9 — FALLBACK: missing directives key → falls back to _REGISTRY ─────
static func _t_fallback_missing_directives() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	# cfg with data but no directives key
	svc.load_from_config({ "data": { "stages": {} } })
	var registry := svc.get_registry()
	# Should fall back to hardcoded _REGISTRY with at least the two canonical directives
	if not registry.has("directive.scout_carefully"):
		return { "ok": false, "error": "Fallback registry missing directive.scout_carefully" }
	if not registry.has("directive.seek_signs"):
		return { "ok": false, "error": "Fallback registry missing directive.seek_signs" }
	return { "ok": true }


# ─── Test 10 — scout target_preference has intel/objective/combat/reward ─────
static func _t_scout_target_preference() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()
	svc.set_active_directive("directive.scout_carefully", logger, 1)
	var defn := svc.get_active_directive()
	var tp_v: Variant = defn.get("target_preference", null)
	if not (tp_v is Dictionary):
		return { "ok": false, "error": "scout target_preference is not a Dictionary" }
	var tp: Dictionary = tp_v
	for req_key in ["intel", "objective", "combat", "reward"]:
		if not tp.has(req_key):
			return { "ok": false, "error": "scout target_preference missing key '%s'" % req_key }
	return { "ok": true }


# ─── Test 11 — scout reveal_radius > seek reveal_radius (fog model Phase 2.5) ─
# Scout has a wider fog-lift radius than Seek — core intel trade-off.
static func _t_scout_reveal_radius_wider() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()

	svc.set_active_directive("directive.scout_carefully", logger, 1)
	var scout_defn := svc.get_active_directive()
	var scout_radius := int(scout_defn.get("reveal_radius", -1))
	if scout_radius < 0:
		return { "ok": false, "error": "scout directive missing reveal_radius field" }

	svc.set_active_directive("directive.seek_signs", logger, 2)
	var seek_defn := svc.get_active_directive()
	var seek_radius := int(seek_defn.get("reveal_radius", -1))
	if seek_radius < 0:
		return { "ok": false, "error": "seek directive missing reveal_radius field" }

	if scout_radius <= seek_radius:
		return {
			"ok": false,
			"error": "scout reveal_radius (%d) must be > seek reveal_radius (%d) — fog intel trade-off" % [
				scout_radius, seek_radius
			]
		}
	return { "ok": true }


# ─── Test 12 — passive_reveal == true for BOTH directives (Phase 2.5 redesign) ─
# Both directives always reveal tiles as they move (radius is the lever, not on/off).
static func _t_passive_reveal_both_true() -> Dictionary:
	var svc := DirectiveService.new(_make_save())
	svc.load_from_config(_make_minimal_cfg())
	var logger := _make_logger()

	for dir_id in ["directive.scout_carefully", "directive.seek_signs"]:
		svc.set_active_directive(dir_id, logger, 1)
		var defn := svc.get_active_directive()
		if not bool(defn.get("passive_reveal", false)):
			return {
				"ok": false,
				"error": "%s must have passive_reveal=true (Phase 2.5: always-on discovery, radius is the lever)" % dir_id
			}
	return { "ok": true }
