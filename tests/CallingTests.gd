# res://tests/CallingTests.gd
# PROG-007: Unit tests for CallingService.
# V2-PROG-004: Updated to V2 six-calling model (okofor/onyamesu/aduro/sum_okwanfo/okomfo/kra_soro).
#
# All tests are pure static — no save file, no FlowRuntime, no OS time.
# Echo dicts are minimal stubs; calling_cfg is built from the canonical
# balance.json values so tests reflect real config.
class_name CallingTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	# compute_all_options — preferred tier (V2 six callings)
	runner.register_test("calling/vanguard_dominant_preferred_aduro",      Callable(CallingTests, "_test_vanguard_preferred_aduro"))
	runner.register_test("calling/protector_dominant_preferred_okofor",    Callable(CallingTests, "_test_protector_preferred_okofor"))
	runner.register_test("calling/pillar_dominant_preferred_onyamesu",     Callable(CallingTests, "_test_pillar_preferred_onyamesu"))
	runner.register_test("calling/seeker_dominant_preferred_okomfo",       Callable(CallingTests, "_test_seeker_preferred_okomfo"))
	runner.register_test("calling/seeker_kra_soro_compatible_when_dominant", Callable(CallingTests, "_test_seeker_kra_soro_compatible"))
	runner.register_test("calling/opportunist_dominant_preferred_sum_okwanfo", Callable(CallingTests, "_test_opportunist_preferred_sum_okwanfo"))
	# extensibility
	runner.register_test("calling/all_six_always_present",                 Callable(CallingTests, "_test_all_six_present"))
	# compatible / ambivalent / incompatible tiers
	runner.register_test("calling/secondary_vector_above_threshold_compatible",  Callable(CallingTests, "_test_compatible_tier"))
	runner.register_test("calling/secondary_vector_below_threshold_ambivalent",  Callable(CallingTests, "_test_ambivalent_tier"))
	runner.register_test("calling/seeker_both_paths_compatible_when_dominant",   Callable(CallingTests, "_test_seeker_both_paths_compatible"))
	# is_calling_pending
	runner.register_test("calling/pending_false_when_not_eligible",        Callable(CallingTests, "_test_pending_false_not_eligible"))
	runner.register_test("calling/pending_false_when_already_set",         Callable(CallingTests, "_test_pending_false_already_set"))
	# confirm_calling consequences
	runner.register_test("calling/confirm_preferred_morale_boost",         Callable(CallingTests, "_test_confirm_preferred"))
	runner.register_test("calling/confirm_compatible_morale_dip",          Callable(CallingTests, "_test_confirm_compatible"))
	runner.register_test("calling/confirm_ambivalent_dip_and_fear",        Callable(CallingTests, "_test_confirm_ambivalent"))
	runner.register_test("calling/confirm_incompatible_fear_increase",     Callable(CallingTests, "_test_confirm_incompatible"))
	# edge: zero score → incompatible not ambivalent
	runner.register_test("calling/zero_vector_score_is_incompatible",      Callable(CallingTests, "_test_zero_score_incompatible"))
	# V2-PROG-002: calling seam — EchoActor projects confirmed calling field into actor dict
	runner.register_test("calling/seam_echo_actor_projects_calling_field", Callable(CallingTests, "_test_echo_actor_projects_calling"))
	# V2-PROG-003: six new vector preferred-calling mappings (updated to V2 IDs in V2-PROG-004)
	runner.register_test("calling/strategist_dominant_preferred_okomfo",   Callable(CallingTests, "_test_strategist_preferred_okomfo"))
	runner.register_test("calling/skeptic_dominant_preferred_kra_soro",    Callable(CallingTests, "_test_skeptic_preferred_kra_soro"))
	runner.register_test("calling/devoted_dominant_preferred_onyamesu",    Callable(CallingTests, "_test_devoted_preferred_onyamesu"))
	runner.register_test("calling/mediator_dominant_preferred_okofor",     Callable(CallingTests, "_test_mediator_preferred_okofor"))
	runner.register_test("calling/nurturer_dominant_preferred_onyamesu",   Callable(CallingTests, "_test_nurturer_preferred_onyamesu"))
	# V2-PROG-007: Standing-6 / Standing-9 data + adjacency ring
	runner.register_test("calling/standing_6_exists_for_all_callings",          Callable(CallingTests, "_test_standing_6_exists_for_all_callings"))
	runner.register_test("calling/standing_6_entries_have_required_fields",     Callable(CallingTests, "_test_standing_6_entries_have_required_fields"))
	runner.register_test("calling/standing_6_parent_matches_calling_id",        Callable(CallingTests, "_test_standing_6_parent_matches_calling_id"))
	runner.register_test("calling/adjacency_ring_complete",                     Callable(CallingTests, "_test_adjacency_ring_complete"))
	runner.register_test("calling/adjacency_lookup_correct_okofor",             Callable(CallingTests, "_test_adjacency_lookup_correct_okofor"))
	runner.register_test("calling/adjacency_lookup_correct_kra_soro",           Callable(CallingTests, "_test_adjacency_lookup_correct_kra_soro"))
	runner.register_test("calling/validator_rejects_invalid_standing_6_parent", Callable(CallingTests, "_test_validator_rejects_invalid_standing_6_parent"))
	runner.register_test("calling/standing_9_count_per_calling",                Callable(CallingTests, "_test_standing_9_count_per_calling"))
	runner.register_test("calling/standing_9_entries_have_required_fields",     Callable(CallingTests, "_test_standing_9_entries_have_required_fields"))
	runner.register_test("calling/standing_9_parent_s6_references_valid_entry", Callable(CallingTests, "_test_standing_9_parent_s6_references_valid_entry"))
	runner.register_test("calling/validator_rejects_invalid_standing_9_parent", Callable(CallingTests, "_test_validator_rejects_invalid_standing_9_parent"))
	# V2-PROG-008: Standing-6 / Standing-9 service query functions
	runner.register_test("calling/s6_options_returns_2_per_calling",         Callable(CallingTests, "_test_s6_options_returns_2_per_calling"))
	runner.register_test("calling/s6_pool_returns_6_for_confirmed_echo",     Callable(CallingTests, "_test_s6_pool_returns_6_for_confirmed_echo"))
	runner.register_test("calling/s6_pool_falls_back_to_calling_origin",     Callable(CallingTests, "_test_s6_pool_falls_back_to_calling_origin"))
	runner.register_test("calling/s6_pool_returns_empty_for_uncalled_echo",  Callable(CallingTests, "_test_s6_pool_returns_empty_for_uncalled_echo"))
	runner.register_test("calling/s9_options_returns_2_per_s6",              Callable(CallingTests, "_test_s9_options_returns_2_per_s6"))
	runner.register_test("calling/s6_options_empty_for_unknown_id",          Callable(CallingTests, "_test_s6_options_empty_for_unknown_id"))
	runner.register_test("calling/s9_options_empty_for_unknown_id",          Callable(CallingTests, "_test_s9_options_empty_for_unknown_id"))
	runner.register_test("calling/count_integrity_passes_on_real_config",    Callable(CallingTests, "_test_count_integrity_passes_on_real_config"))
	runner.register_test("calling/count_integrity_fails_for_wrong_s6_count", Callable(CallingTests, "_test_count_integrity_fails_for_wrong_s6_count"))
	runner.register_test("calling/count_integrity_catches_cross_calling_s9_duplicate", Callable(CallingTests, "_test_count_integrity_catches_cross_calling_s9_duplicate"))


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

## Canonical config matching data/balance.json data.calling (V2-PROG-004: 6 V2 callings)
static func _calling_cfg() -> Dictionary:
	return {
		"compatibility_threshold":          0.15,
		"calling_preferred_morale_boost":   10,
		"calling_compatible_morale_dip":    5,
		"calling_ambivalent_morale_dip":    3,
		"calling_ambivalent_fear_increase": 3,
		"calling_incompatible_fear_increase": 10,
		"vector_to_calling": {
			"vanguard":    "aduro",
			"protector":   "okofor",
			"pillar":      "onyamesu",
			"seeker":      "okomfo",
			"strategist":  "okomfo",
			"skeptic":     "kra_soro",
			"devoted":     "onyamesu",
			"opportunist": "sum_okwanfo",
			"mediator":    "okofor",
			"nurturer":    "onyamesu",
		},
		"all_callings": ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"],
		"definitions": {
			"okofor":      { "display_name": "Oko Fo",      "icon_key": "calling_okofor",      "description": "", "benefits": [], "downsides": [], "vector": "protector"  },
			"onyamesu":    { "display_name": "Onyame Su",   "icon_key": "calling_onyamesu",    "description": "", "benefits": [], "downsides": [], "vector": "pillar"      },
			"aduro":       { "display_name": "Aduro",       "icon_key": "calling_aduro",       "description": "", "benefits": [], "downsides": [], "vector": "vanguard"    },
			"sum_okwanfo": { "display_name": "Sum Okwanfo", "icon_key": "calling_sum_okwanfo", "description": "", "benefits": [], "downsides": [], "vector": "opportunist" },
			"okomfo":      { "display_name": "Okomfo",      "icon_key": "calling_okomfo",      "description": "", "benefits": [], "downsides": [], "vector": "seeker"      },
			"kra_soro":    { "display_name": "Kra Soro",    "icon_key": "calling_kra_soro",    "description": "", "benefits": [], "downsides": [], "vector": "seeker"      },
		},
	}

## Minimal echo dict. V2 vector_scores: old 4 at 100 each; new 6 default to 0.
static func _make_echo(dominant: String, traits: Dictionary = {}, scores: Dictionary = {}) -> Dictionary:
	var default_scores: Dictionary = {
		"vanguard": 100, "protector": 100, "pillar": 100, "seeker": 100,
		"strategist": 0, "skeptic": 0, "devoted": 0, "opportunist": 0, "mediator": 0, "nurturer": 0
	}
	for k in scores:
		default_scores[k] = scores[k]
	if traits.is_empty():
		traits = { "courage": 50, "wisdom": 50, "faith": 50 }
	return {
		"id":              "test_echo",
		"dominant_vector": dominant,
		"vector_scores":   default_scores,
		"traits":          traits,
		"calling_eligible": true,
		"emotion":         { "morale_current": 60, "fear_current": 10 },
	}

## Find an option by calling_id in the result array.
static func _find_option(options: Array, cid: String) -> Dictionary:
	for o in options:
		if o is Dictionary and str(o.get("calling_id", "")) == cid:
			return o
	return {}


# ────────────────────────────────────────────────────────────────────────────
# Tests — preferred tier
# ────────────────────────────────────────────────────────────────────────────

static func _test_vanguard_preferred_aduro() -> Dictionary:
	var echo  := _make_echo("vanguard")
	var opts  := CallingService.compute_all_options(echo, _calling_cfg())
	var aduro := _find_option(opts, "aduro")
	if aduro.is_empty():
		return { "ok": false, "error": "aduro option not found" }
	if str(aduro.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected aduro=preferred, got: %s" % aduro.get("compatibility") }
	if not bool(aduro.get("is_preferred", false)):
		return { "ok": false, "error": "aduro.is_preferred should be true" }
	return { "ok": true }


static func _test_protector_preferred_okofor() -> Dictionary:
	var echo   := _make_echo("protector")
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var okofor := _find_option(opts, "okofor")
	if str(okofor.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected okofor=preferred, got: %s" % okofor.get("compatibility") }
	if not bool(okofor.get("is_preferred", false)):
		return { "ok": false, "error": "okofor.is_preferred should be true" }
	return { "ok": true }


static func _test_pillar_preferred_onyamesu() -> Dictionary:
	var echo     := _make_echo("pillar")
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var onyamesu := _find_option(opts, "onyamesu")
	if str(onyamesu.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected onyamesu=preferred, got: %s" % onyamesu.get("compatibility") }
	if not bool(onyamesu.get("is_preferred", false)):
		return { "ok": false, "error": "onyamesu.is_preferred should be true" }
	return { "ok": true }


static func _test_seeker_preferred_okomfo() -> Dictionary:
	# seeker dominant → okomfo is preferred (vector_to_calling["seeker"] = "okomfo")
	var echo   := _make_echo("seeker")
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var okomfo := _find_option(opts, "okomfo")
	if str(okomfo.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected okomfo=preferred for seeker dominant, got: %s" % okomfo.get("compatibility") }
	if not bool(okomfo.get("is_preferred", false)):
		return { "ok": false, "error": "okomfo.is_preferred should be true" }
	return { "ok": true }


static func _test_seeker_kra_soro_compatible() -> Dictionary:
	# seeker dominant → kra_soro shares vector=seeker → compatible (vec == dominant rule)
	var echo     := _make_echo("seeker")
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var kra_soro := _find_option(opts, "kra_soro")
	if str(kra_soro.get("compatibility")) != "compatible":
		return { "ok": false, "error": "Expected kra_soro=compatible for seeker dominant, got: %s" % kra_soro.get("compatibility") }
	return { "ok": true }


static func _test_opportunist_preferred_sum_okwanfo() -> Dictionary:
	var echo        := _make_echo("opportunist", {}, { "opportunist": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts        := CallingService.compute_all_options(echo, _calling_cfg())
	var sum_okwanfo := _find_option(opts, "sum_okwanfo")
	if str(sum_okwanfo.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected sum_okwanfo=preferred for opportunist dominant, got: %s" % sum_okwanfo.get("compatibility") }
	if not bool(sum_okwanfo.get("is_preferred", false)):
		return { "ok": false, "error": "sum_okwanfo.is_preferred should be true" }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — extensibility
# ────────────────────────────────────────────────────────────────────────────

static func _test_all_six_present() -> Dictionary:
	var echo := _make_echo("vanguard")
	var opts  := CallingService.compute_all_options(echo, _calling_cfg())
	if opts.size() != 6:
		return { "ok": false, "error": "Expected 6 options, got %d" % opts.size() }
	var ids: Array = []
	for o in opts:
		ids.append(str(o.get("calling_id", "")))
	for expected in ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]:
		if not ids.has(expected):
			return { "ok": false, "error": "Missing calling id: %s" % expected }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — compatible / ambivalent / incompatible tiers
# ────────────────────────────────────────────────────────────────────────────

static func _test_compatible_tier() -> Dictionary:
	# vanguard dominant (400 total). protector score=100 → 100/400=0.25 >= 0.15 → okofor compatible
	var echo   := _make_echo("vanguard", {}, { "vanguard": 100, "protector": 100, "pillar": 100, "seeker": 100 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var okofor := _find_option(opts, "okofor")
	if str(okofor.get("compatibility")) != "compatible":
		return { "ok": false, "error": "Expected okofor=compatible, got: %s" % okofor.get("compatibility") }
	return { "ok": true }


static func _test_ambivalent_tier() -> Dictionary:
	# vanguard dominant=350, pillar=20. pillar ratio=20/440=0.045 < 0.15 → onyamesu ambivalent
	var echo     := _make_echo("vanguard", {}, { "vanguard": 350, "protector": 40, "pillar": 20, "seeker": 30 })
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var onyamesu := _find_option(opts, "onyamesu")
	if str(onyamesu.get("compatibility")) != "ambivalent":
		return { "ok": false, "error": "Expected onyamesu=ambivalent, got: %s" % onyamesu.get("compatibility") }
	return { "ok": true }


static func _test_seeker_both_paths_compatible() -> Dictionary:
	# seeker dominant: okomfo = preferred, kra_soro = compatible (both share vector=seeker)
	var echo     := _make_echo("seeker")
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var okomfo   := _find_option(opts, "okomfo")
	var kra_soro := _find_option(opts, "kra_soro")
	if str(okomfo.get("compatibility")) != "preferred":
		return { "ok": false, "error": "okomfo should be preferred, got: %s" % okomfo.get("compatibility") }
	if str(kra_soro.get("compatibility")) != "compatible":
		return { "ok": false, "error": "kra_soro should be compatible, got: %s" % kra_soro.get("compatibility") }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — is_calling_pending
# ────────────────────────────────────────────────────────────────────────────

static func _test_pending_false_not_eligible() -> Dictionary:
	var echo := { "calling_eligible": false, "calling": "" }
	if CallingService.is_calling_pending(echo):
		return { "ok": false, "error": "is_calling_pending should be false when calling_eligible=false" }
	return { "ok": true }


static func _test_pending_false_already_set() -> Dictionary:
	var echo := { "calling_eligible": true, "calling": "aduro" }
	if CallingService.is_calling_pending(echo):
		return { "ok": false, "error": "is_calling_pending should be false when calling is already set" }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — confirm_calling consequences
# ────────────────────────────────────────────────────────────────────────────

static func _make_echo_with_options(dominant: String, morale: int = 60, fear: int = 10) -> Dictionary:
	var echo := _make_echo(dominant)
	echo["emotion"] = { "morale_current": morale, "fear_current": fear }
	echo["calling_options"] = CallingService.compute_all_options(echo, _calling_cfg())
	return echo


static func _test_confirm_preferred() -> Dictionary:
	# vanguard dominant → aduro is preferred → morale boost of 10
	var echo := _make_echo_with_options("vanguard")
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "aduro", _calling_cfg(), null, 0)
	if result != "aduro":
		return { "ok": false, "error": "confirm_calling should return 'aduro', got: %s" % result }
	if str(echo.get("calling", "")) != "aduro":
		return { "ok": false, "error": "echo.calling should be 'aduro'" }
	if echo.has("calling_options"):
		return { "ok": false, "error": "calling_options should be erased after confirm" }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	if after_morale != before_morale + 10:
		return { "ok": false, "error": "Expected morale=%d, got %d" % [before_morale + 10, after_morale] }
	return { "ok": true }


static func _test_confirm_compatible() -> Dictionary:
	# vanguard dominant. okofor (protector vector) is compatible.
	# All scores equal (100 each) → ratio 100/400=0.25 >= 0.15 → compatible.
	var echo := _make_echo_with_options("vanguard", 60, 10)
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "okofor", _calling_cfg(), null, 0)
	if result != "okofor":
		return { "ok": false, "error": "confirm_calling should return 'okofor', got: %s" % result }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	if after_morale != before_morale - 5:
		return { "ok": false, "error": "Expected morale dip of 5, got %d→%d" % [before_morale, after_morale] }
	return { "ok": true }


static func _test_confirm_ambivalent() -> Dictionary:
	# vanguard dominant=350, pillar=20 → onyamesu is ambivalent.
	var echo := _make_echo("vanguard", {}, { "vanguard": 350, "protector": 40, "pillar": 20, "seeker": 30 })
	echo["emotion"] = { "morale_current": 60, "fear_current": 10 }
	echo["calling_options"] = CallingService.compute_all_options(echo, _calling_cfg())
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var before_fear: int   = int(echo["emotion"]["fear_current"])
	var result := CallingService.confirm_calling(echo, "onyamesu", _calling_cfg(), null, 0)
	if result != "onyamesu":
		return { "ok": false, "error": "Expected 'onyamesu', got: %s" % result }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	var after_fear: int   = int(echo["emotion"]["fear_current"])
	if after_morale != before_morale - 3:
		return { "ok": false, "error": "Expected morale dip of 3, got %d→%d" % [before_morale, after_morale] }
	if after_fear != before_fear + 3:
		return { "ok": false, "error": "Expected fear increase of 3, got %d→%d" % [before_fear, after_fear] }
	return { "ok": true }


static func _test_confirm_incompatible() -> Dictionary:
	# vanguard dominant. Make seeker score=0 → okomfo/kra_soro incompatible.
	var echo := _make_echo("vanguard", {}, { "vanguard": 300, "protector": 0, "pillar": 0, "seeker": 0 })
	echo["emotion"] = { "morale_current": 60, "fear_current": 10 }
	echo["calling_options"] = CallingService.compute_all_options(echo, _calling_cfg())
	var before_fear: int   = int(echo["emotion"]["fear_current"])
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "kra_soro", _calling_cfg(), null, 0)
	if result != "kra_soro":
		return { "ok": false, "error": "Expected 'kra_soro', got: %s" % result }
	var after_fear: int   = int(echo["emotion"]["fear_current"])
	var after_morale: int = int(echo["emotion"]["morale_current"])
	if after_fear != before_fear + 10:
		return { "ok": false, "error": "Expected fear increase of 10, got %d→%d" % [before_fear, after_fear] }
	if after_morale != before_morale:
		return { "ok": false, "error": "Morale should not change for incompatible, got %d→%d" % [before_morale, after_morale] }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — zero score → incompatible (not ambivalent)
# ────────────────────────────────────────────────────────────────────────────

static func _test_zero_score_incompatible() -> Dictionary:
	# vanguard dominant, pillar score=0 → onyamesu should be incompatible, not ambivalent
	var echo     := _make_echo("vanguard", {}, { "vanguard": 300, "protector": 50, "pillar": 0, "seeker": 50 })
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var onyamesu := _find_option(opts, "onyamesu")
	if str(onyamesu.get("compatibility")) != "incompatible":
		return { "ok": false, "error": "Expected onyamesu=incompatible (score=0), got: %s" % onyamesu.get("compatibility") }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — V2-PROG-002: calling seam
# ────────────────────────────────────────────────────────────────────────────

## EchoActor must project both calling_origin (birth bias) and calling (confirmed identity).
## Verifies the seam: two distinct fields are now available in the actor dict.
static func _test_echo_actor_projects_calling() -> Dictionary:
	var echo := {
		"id":               "echo_seam_001",
		"name":             "Kofi",
		"rarity":           "common",
		"rank":             3,
		"calling_origin":   "okofor",
		"calling":          "aduro",  # confirmed calling — different from birth origin
		"stats":            { "max_hp": 100, "atk": 10, "def": 8, "agi": 6, "int": 4, "cha": 5 },
		"traits":           { "courage": 60, "wisdom": 30, "faith": 20 },
		"xp_total":         500,
		"level":            5,
		"emotion":          { "morale_current": 60, "fear_current": 10 },
		"vector_scores":    {},
		"dominant_vector":  "vanguard",
		"resilience_traits": [],
		"leadership_traits": [],
		"skill_slots":      [""],
		"equipped_skills":  {},
	}
	var actor := EchoActor.from_echo(echo)
	if not actor.has("calling"):
		return { "ok": false, "error": "actor dict missing 'calling' field — EchoActor must project it" }
	if str(actor.get("calling")) != "aduro":
		return { "ok": false, "error": "Expected calling='aduro', got: %s" % str(actor.get("calling")) }
	if str(actor.get("calling_origin")) != "okofor":
		return { "ok": false, "error": "calling_origin should remain 'okofor' (birth bias), got: %s" % str(actor.get("calling_origin")) }
	return { "ok": true }


## ────────────────────────────────────────────────────────────────────────────
## V2-PROG-003 (updated to V2 IDs in V2-PROG-004): six new vector → preferred calling tests
## ────────────────────────────────────────────────────────────────────────────

static func _test_strategist_preferred_okomfo() -> Dictionary:
	var echo   := _make_echo("strategist", {}, { "strategist": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var okomfo := _find_option(opts, "okomfo")
	if okomfo.is_empty():
		return { "ok": false, "error": "okomfo option not found" }
	if str(okomfo.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected okomfo=preferred for strategist dominant, got: %s" % okomfo.get("compatibility") }
	if not bool(okomfo.get("is_preferred", false)):
		return { "ok": false, "error": "okomfo.is_preferred should be true for strategist dominant" }
	return { "ok": true }


static func _test_skeptic_preferred_kra_soro() -> Dictionary:
	var echo     := _make_echo("skeptic", {}, { "skeptic": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var kra_soro := _find_option(opts, "kra_soro")
	if str(kra_soro.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected kra_soro=preferred for skeptic dominant, got: %s" % kra_soro.get("compatibility") }
	if not bool(kra_soro.get("is_preferred", false)):
		return { "ok": false, "error": "kra_soro.is_preferred should be true for skeptic dominant" }
	return { "ok": true }


static func _test_devoted_preferred_onyamesu() -> Dictionary:
	var echo     := _make_echo("devoted", {}, { "devoted": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var onyamesu := _find_option(opts, "onyamesu")
	if str(onyamesu.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected onyamesu=preferred for devoted dominant, got: %s" % onyamesu.get("compatibility") }
	if not bool(onyamesu.get("is_preferred", false)):
		return { "ok": false, "error": "onyamesu.is_preferred should be true for devoted dominant" }
	return { "ok": true }


static func _test_mediator_preferred_okofor() -> Dictionary:
	var echo   := _make_echo("mediator", {}, { "mediator": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var okofor := _find_option(opts, "okofor")
	if str(okofor.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected okofor=preferred for mediator dominant, got: %s" % okofor.get("compatibility") }
	if not bool(okofor.get("is_preferred", false)):
		return { "ok": false, "error": "okofor.is_preferred should be true for mediator dominant" }
	return { "ok": true }


static func _test_nurturer_preferred_onyamesu() -> Dictionary:
	var echo     := _make_echo("nurturer", {}, { "nurturer": 400, "vanguard": 0, "protector": 0, "pillar": 0, "seeker": 0 })
	var opts     := CallingService.compute_all_options(echo, _calling_cfg())
	var onyamesu := _find_option(opts, "onyamesu")
	if str(onyamesu.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected onyamesu=preferred for nurturer dominant, got: %s" % onyamesu.get("compatibility") }
	if not bool(onyamesu.get("is_preferred", false)):
		return { "ok": false, "error": "onyamesu.is_preferred should be true for nurturer dominant" }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# V2-PROG-007: Standing-6 / Standing-9 data + adjacency ring
# All lattice data tests load from the real balance.json via ConfigService.
# Validator rejection tests use inline stubs.
# ────────────────────────────────────────────────────────────────────────────

static func _load_real_calling_cfg() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal := cs.get_balance()
	var data_v: Variant = bal.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var calling_v: Variant = data.get("calling", {})
	return calling_v if calling_v is Dictionary else {}


static func _test_standing_6_exists_for_all_callings() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var all_ids: Array = ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]
	for cid in all_ids:
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		var s6: Array = s6_v if s6_v is Array else []
		if s6.size() != 2:
			return { "ok": false, "error": "%s should have 2 standing_6 entries, got %d" % [cid, s6.size()] }
	return { "ok": true }


static func _test_standing_6_entries_have_required_fields() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var required := ["id", "display_name", "english_scaffold", "descriptor", "parent_calling"]
	for cid_v in defns:
		var defn_v: Variant = defns.get(cid_v, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		for entry_v in (s6_v if s6_v is Array else []):
			if not (entry_v is Dictionary):
				return { "ok": false, "error": "standing_6 entry in %s is not a Dictionary" % str(cid_v) }
			for field in required:
				if not entry_v.has(field):
					return { "ok": false, "error": "standing_6 entry in %s missing field: %s" % [str(cid_v), field] }
	return { "ok": true }


static func _test_standing_6_parent_matches_calling_id() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	for cid_v in defns:
		var cid: String = str(cid_v)
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		for entry_v in (s6_v if s6_v is Array else []):
			if entry_v is Dictionary:
				var parent: String = str(entry_v.get("parent_calling", ""))
				if parent != cid:
					return { "ok": false, "error": "standing_6 entry '%s' in %s has wrong parent_calling: '%s'" % [str(entry_v.get("id", "")), cid, parent] }
	return { "ok": true }


static func _test_adjacency_ring_complete() -> Dictionary:
	var cfg := _load_real_calling_cfg()
	var adj_v: Variant = cfg.get("adjacency", {})
	var adj: Dictionary = adj_v if adj_v is Dictionary else {}
	var expected_ids := ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]
	if adj.size() != 6:
		return { "ok": false, "error": "adjacency should have 6 callings, got %d" % adj.size() }
	for cid in expected_ids:
		if not adj.has(cid):
			return { "ok": false, "error": "adjacency missing calling: %s" % cid }
		var neighbours_v: Variant = adj.get(cid, [])
		var neighbours: Array = neighbours_v if neighbours_v is Array else []
		if neighbours.size() != 2:
			return { "ok": false, "error": "%s should have 2 adjacency neighbours, got %d" % [cid, neighbours.size()] }
	return { "ok": true }


static func _test_adjacency_lookup_correct_okofor() -> Dictionary:
	var cfg       := _load_real_calling_cfg()
	var neighbours := CallingService.get_adjacent_callings("okofor", cfg)
	if neighbours.size() != 2:
		return { "ok": false, "error": "Expected 2 neighbours for okofor, got %d" % neighbours.size() }
	if str(neighbours[0]) != "onyamesu" or str(neighbours[1]) != "aduro":
		return { "ok": false, "error": "Expected [onyamesu, aduro], got %s" % str(neighbours) }
	return { "ok": true }


static func _test_adjacency_lookup_correct_kra_soro() -> Dictionary:
	var cfg       := _load_real_calling_cfg()
	var neighbours := CallingService.get_adjacent_callings("kra_soro", cfg)
	if neighbours.size() != 2:
		return { "ok": false, "error": "Expected 2 neighbours for kra_soro, got %d" % neighbours.size() }
	if str(neighbours[0]) != "sum_okwanfo" or str(neighbours[1]) != "okomfo":
		return { "ok": false, "error": "Expected [sum_okwanfo, okomfo], got %s" % str(neighbours) }
	return { "ok": true }


static func _test_validator_rejects_invalid_standing_6_parent() -> Dictionary:
	var cfg   := _calling_cfg()
	var bogus := { "id": "bogus_s6", "parent_calling": "completely_bogus_calling" }
	if CallingService.validate_standing_6_entry(bogus, cfg):
		return { "ok": false, "error": "Validator should reject entry with non-existent parent_calling" }
	return { "ok": true }


static func _test_standing_9_count_per_calling() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var all_ids: Array = ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]
	for cid in all_ids:
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s9_v: Variant = defn.get("standing_9", [])
		var s9: Array = s9_v if s9_v is Array else []
		if s9.size() != 4:
			return { "ok": false, "error": "%s should have 4 standing_9 entries, got %d" % [cid, s9.size()] }
	return { "ok": true }


static func _test_standing_9_entries_have_required_fields() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var required := ["id", "english_scaffold", "parent_standing_6", "twi_provisional"]
	for cid_v in defns:
		var defn_v: Variant = defns.get(cid_v, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s9_v: Variant = defn.get("standing_9", [])
		for entry_v in (s9_v if s9_v is Array else []):
			if not (entry_v is Dictionary):
				return { "ok": false, "error": "standing_9 entry in %s is not a Dictionary" % str(cid_v) }
			for field in required:
				if not entry_v.has(field):
					return { "ok": false, "error": "standing_9 entry in %s missing field: %s" % [str(cid_v), field] }
	return { "ok": true }


static func _test_standing_9_parent_s6_references_valid_entry() -> Dictionary:
	var cfg := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var s6_ids: Array = []
	for defn_v in defns.values():
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		for e_v in (defn.get("standing_6", []) if defn.get("standing_6", []) is Array else []):
			if e_v is Dictionary:
				s6_ids.append(str(e_v.get("id", "")))
	for cid_v in defns:
		var defn_v: Variant = defns.get(cid_v, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s9_v: Variant = defn.get("standing_9", [])
		for entry_v in (s9_v if s9_v is Array else []):
			if entry_v is Dictionary:
				var parent_s6: String = str(entry_v.get("parent_standing_6", ""))
				if not s6_ids.has(parent_s6):
					return { "ok": false, "error": "standing_9 entry '%s' in %s has unresolvable parent_standing_6: '%s'" % [str(entry_v.get("id", "")), str(cid_v), parent_s6] }
	return { "ok": true }


static func _test_validator_rejects_invalid_standing_9_parent() -> Dictionary:
	var cfg   := _load_real_calling_cfg()
	var bogus := { "id": "bogus_s9", "parent_standing_6": "completely_bogus_s6_id", "twi_provisional": true }
	if CallingService.validate_standing_9_entry(bogus, cfg):
		return { "ok": false, "error": "Validator should reject entry with non-existent parent_standing_6" }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# V2-PROG-008: Standing-6 / Standing-9 service query functions
# ────────────────────────────────────────────────────────────────────────────

static func _test_s6_options_returns_2_per_calling() -> Dictionary:
	var cfg := _load_real_calling_cfg()
	var all_ids := ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"]
	for cid in all_ids:
		var opts := CallingService.get_standing_6_options(cid, cfg)
		if opts.size() != 2:
			return { "ok": false, "error": "%s: expected 2 S6 options, got %d" % [cid, opts.size()] }
	return { "ok": true }


static func _test_s6_pool_returns_6_for_confirmed_echo() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var echo := { "calling": "okofor", "calling_origin": "aduro" }
	var pool := CallingService.compute_standing_6_pool(echo, cfg)
	if pool.size() != 6:
		return { "ok": false, "error": "Expected pool size 6 for confirmed calling, got %d" % pool.size() }
	return { "ok": true }


static func _test_s6_pool_falls_back_to_calling_origin() -> Dictionary:
	var cfg  := _load_real_calling_cfg()
	var echo := { "calling": "", "calling_origin": "okofor" }
	var pool := CallingService.compute_standing_6_pool(echo, cfg)
	if pool.size() != 6:
		return { "ok": false, "error": "Expected pool size 6 via calling_origin fallback, got %d" % pool.size() }
	return { "ok": true }


static func _test_s6_pool_returns_empty_for_uncalled_echo() -> Dictionary:
	var cfg  := _calling_cfg()
	var echo := { "calling": "", "calling_origin": "" }
	var pool := CallingService.compute_standing_6_pool(echo, cfg)
	if pool.size() != 0:
		return { "ok": false, "error": "Expected empty pool for uncalled echo, got %d" % pool.size() }
	return { "ok": true }


static func _test_s9_options_returns_2_per_s6() -> Dictionary:
	var cfg     := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var s6_ids: Array = []
	for defn_v in defns.values():
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var s6_v: Variant = defn.get("standing_6", [])
		for entry_v in (s6_v if s6_v is Array else []):
			if entry_v is Dictionary:
				s6_ids.append(str(entry_v.get("id", "")))
	if s6_ids.size() != 12:
		return { "ok": false, "error": "Expected 12 S6 IDs in real config, got %d" % s6_ids.size() }
	for s6_id in s6_ids:
		var opts := CallingService.get_standing_9_options(s6_id, cfg)
		if opts.size() != 2:
			return { "ok": false, "error": "%s: expected 2 S9 options, got %d" % [s6_id, opts.size()] }
	return { "ok": true }


static func _test_s6_options_empty_for_unknown_id() -> Dictionary:
	var cfg  := _calling_cfg()
	var opts := CallingService.get_standing_6_options("completely_bogus_calling", cfg)
	if opts.size() != 0:
		return { "ok": false, "error": "Expected empty array for unknown calling ID, got %d" % opts.size() }
	return { "ok": true }


static func _test_s9_options_empty_for_unknown_id() -> Dictionary:
	var cfg  := _calling_cfg()
	var opts := CallingService.get_standing_9_options("completely_bogus_s6_id", cfg)
	if opts.size() != 0:
		return { "ok": false, "error": "Expected empty array for unknown S6 ID, got %d" % opts.size() }
	return { "ok": true }


static func _test_count_integrity_passes_on_real_config() -> Dictionary:
	var cfg := _load_real_calling_cfg()
	if not CallingService.validate_count_integrity(cfg, null, 0):
		return { "ok": false, "error": "validate_count_integrity returned false on real config" }
	return { "ok": true }


static func _test_count_integrity_fails_for_wrong_s6_count() -> Dictionary:
	var cfg: Dictionary = _calling_cfg().duplicate(true)
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var okofor_v: Variant = defns.get("okofor", {})
	var okofor: Dictionary = (okofor_v if okofor_v is Dictionary else {}).duplicate(true)
	okofor["standing_6"] = [{ "id": "only_one", "parent_calling": "okofor" }]
	defns["okofor"] = okofor
	cfg["definitions"] = defns
	if CallingService.validate_count_integrity(cfg, null, 0):
		return { "ok": false, "error": "validate_count_integrity should return false when okofor has only 1 S6 entry" }
	return { "ok": true }


static func _test_count_integrity_catches_cross_calling_s9_duplicate() -> Dictionary:
	# Reproduces the reviewer-identified gap: an S9 entry for okyefo_kesee placed
	# inside aduro's standing_9 block gives a global count of 3 for that S6 expression.
	# The old local-only scan would have missed this; the global scan must catch it.
	var cfg := _load_real_calling_cfg()
	var defns_v: Variant = cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}
	var aduro_v: Variant = defns.get("aduro", {})
	var aduro: Dictionary = (aduro_v if aduro_v is Dictionary else {}).duplicate(true)
	var aduro_s9_v: Variant = aduro.get("standing_9", [])
	var aduro_s9: Array = (aduro_s9_v if aduro_s9_v is Array else []).duplicate(true)
	# Inject a rogue S9 entry that claims to belong to okofor's S6 expression
	aduro_s9.append({ "id": "rogue_s9", "parent_standing_6": "okyefo_kesee", "twi_provisional": true, "english_scaffold": "Rogue" })
	aduro["standing_9"] = aduro_s9
	defns["aduro"] = aduro
	cfg["definitions"] = defns
	if CallingService.validate_count_integrity(cfg, null, 0):
		return { "ok": false, "error": "validate_count_integrity should catch cross-calling S9 duplicate (global count = 3 for okyefo_kesee)" }
	return { "ok": true }
