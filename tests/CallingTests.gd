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
