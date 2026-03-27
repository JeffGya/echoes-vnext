# res://tests/CallingTests.gd
# PROG-007: Unit tests for CallingService.
#
# All tests are pure static — no save file, no FlowRuntime, no OS time.
# Echo dicts are minimal stubs; calling_cfg is built from the canonical
# balance.json values so tests reflect real config.
class_name CallingTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	# compute_all_options — preferred tier
	runner.register_test("calling_vanguard_dominant_preferred_blade",   Callable(CallingTests, "_test_vanguard_preferred_blade"))
	runner.register_test("calling_protector_dominant_preferred_warder", Callable(CallingTests, "_test_protector_preferred_warder"))
	runner.register_test("calling_pillar_dominant_preferred_steward",   Callable(CallingTests, "_test_pillar_preferred_steward"))
	runner.register_test("calling_seeker_courage_gte_wisdom_ranger",    Callable(CallingTests, "_test_seeker_ranger"))
	runner.register_test("calling_seeker_wisdom_gt_courage_seer",       Callable(CallingTests, "_test_seeker_seer"))
	runner.register_test("calling_seeker_tie_courage_wisdom_ranger",    Callable(CallingTests, "_test_seeker_tie_ranger"))
	# extensibility
	runner.register_test("calling_all_five_always_present",             Callable(CallingTests, "_test_all_five_present"))
	# compatible / ambivalent / incompatible tiers
	runner.register_test("calling_secondary_vector_above_threshold_compatible",  Callable(CallingTests, "_test_compatible_tier"))
	runner.register_test("calling_secondary_vector_below_threshold_ambivalent",  Callable(CallingTests, "_test_ambivalent_tier"))
	runner.register_test("calling_seeker_both_paths_compatible_when_dominant",   Callable(CallingTests, "_test_seeker_both_paths_compatible"))
	# is_calling_pending
	runner.register_test("calling_pending_false_when_not_eligible",     Callable(CallingTests, "_test_pending_false_not_eligible"))
	runner.register_test("calling_pending_false_when_already_set",      Callable(CallingTests, "_test_pending_false_already_set"))
	# confirm_calling consequences
	runner.register_test("calling_confirm_preferred_morale_boost",      Callable(CallingTests, "_test_confirm_preferred"))
	runner.register_test("calling_confirm_compatible_morale_dip",       Callable(CallingTests, "_test_confirm_compatible"))
	runner.register_test("calling_confirm_ambivalent_dip_and_fear",     Callable(CallingTests, "_test_confirm_ambivalent"))
	runner.register_test("calling_confirm_incompatible_fear_increase",  Callable(CallingTests, "_test_confirm_incompatible"))
	# edge: zero score → incompatible not ambivalent
	runner.register_test("calling_zero_vector_score_is_incompatible",   Callable(CallingTests, "_test_zero_score_incompatible"))


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

## Canonical config matching data/balance.json data.calling
static func _calling_cfg() -> Dictionary:
	return {
		"compatibility_threshold":         0.15,
		"calling_preferred_morale_boost":  10,
		"calling_compatible_morale_dip":   5,
		"calling_ambivalent_morale_dip":   3,
		"calling_ambivalent_fear_increase": 3,
		"calling_incompatible_fear_increase": 10,
		"vector_to_calling": {
			"vanguard":  "blade",
			"protector": "warder",
			"pillar":    "steward",
			"seeker":    "seeker",
		},
		"seeker_trait_split": {
			"courage_gte_wisdom": "ranger",
			"wisdom_gt_courage":  "seer",
		},
		"all_callings": ["blade", "warder", "steward", "ranger", "seer"],
		"definitions": {
			"blade":   { "display_name": "The Blade",   "icon_key": "calling_blade",   "description": "", "benefits": [], "downsides": [], "vector": "vanguard"  },
			"warder":  { "display_name": "The Warder",  "icon_key": "calling_warder",  "description": "", "benefits": [], "downsides": [], "vector": "protector" },
			"steward": { "display_name": "The Steward", "icon_key": "calling_steward", "description": "", "benefits": [], "downsides": [], "vector": "pillar"    },
			"ranger":  { "display_name": "The Ranger",  "icon_key": "calling_ranger",  "description": "", "benefits": [], "downsides": [], "vector": "seeker"    },
			"seer":    { "display_name": "The Seer",    "icon_key": "calling_seer",    "description": "", "benefits": [], "downsides": [], "vector": "seeker"    },
		},
	}

## Minimal echo dict. vector_scores sums to 400 (100 each) unless overridden.
static func _make_echo(dominant: String, traits: Dictionary = {}, scores: Dictionary = {}) -> Dictionary:
	var default_scores: Dictionary = { "vanguard": 100, "protector": 100, "pillar": 100, "seeker": 100 }
	for k in scores:
		default_scores[k] = scores[k]
	if traits.is_empty():
		traits = { "courage": 50, "wisdom": 50, "faith": 50 }
	return {
		"id":             "test_echo",
		"dominant_vector": dominant,
		"vector_scores":  default_scores,
		"traits":         traits,
		"calling_eligible": true,
		"emotion":        { "morale_current": 60, "fear_current": 10 },
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

static func _test_vanguard_preferred_blade() -> Dictionary:
	var echo := _make_echo("vanguard")
	var opts  := CallingService.compute_all_options(echo, _calling_cfg())
	var blade := _find_option(opts, "blade")
	if blade.is_empty():
		return { "ok": false, "error": "blade option not found" }
	if str(blade.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected blade=preferred, got: %s" % blade.get("compatibility") }
	if not bool(blade.get("is_preferred", false)):
		return { "ok": false, "error": "blade.is_preferred should be true" }
	return { "ok": true }


static func _test_protector_preferred_warder() -> Dictionary:
	var echo   := _make_echo("protector")
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var warder := _find_option(opts, "warder")
	if str(warder.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected warder=preferred, got: %s" % warder.get("compatibility") }
	if not bool(warder.get("is_preferred", false)):
		return { "ok": false, "error": "warder.is_preferred should be true" }
	return { "ok": true }


static func _test_pillar_preferred_steward() -> Dictionary:
	var echo    := _make_echo("pillar")
	var opts    := CallingService.compute_all_options(echo, _calling_cfg())
	var steward := _find_option(opts, "steward")
	if str(steward.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected steward=preferred, got: %s" % steward.get("compatibility") }
	if not bool(steward.get("is_preferred", false)):
		return { "ok": false, "error": "steward.is_preferred should be true" }
	return { "ok": true }


static func _test_seeker_ranger() -> Dictionary:
	# courage(60) >= wisdom(40) → ranger preferred
	var echo   := _make_echo("seeker", { "courage": 60, "wisdom": 40, "faith": 50 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var ranger := _find_option(opts, "ranger")
	if str(ranger.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected ranger=preferred, got: %s" % ranger.get("compatibility") }
	if not bool(ranger.get("is_preferred", false)):
		return { "ok": false, "error": "ranger.is_preferred should be true" }
	# seer must be compatible (shares seeker vector)
	var seer := _find_option(opts, "seer")
	if str(seer.get("compatibility")) != "compatible":
		return { "ok": false, "error": "Expected seer=compatible, got: %s" % seer.get("compatibility") }
	return { "ok": true }


static func _test_seeker_seer() -> Dictionary:
	# wisdom(60) > courage(40) → seer preferred
	var echo := _make_echo("seeker", { "courage": 40, "wisdom": 60, "faith": 50 })
	var opts := CallingService.compute_all_options(echo, _calling_cfg())
	var seer  := _find_option(opts, "seer")
	if str(seer.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected seer=preferred, got: %s" % seer.get("compatibility") }
	if not bool(seer.get("is_preferred", false)):
		return { "ok": false, "error": "seer.is_preferred should be true" }
	# ranger must be compatible (shares seeker vector)
	var ranger := _find_option(opts, "ranger")
	if str(ranger.get("compatibility")) != "compatible":
		return { "ok": false, "error": "Expected ranger=compatible, got: %s" % ranger.get("compatibility") }
	return { "ok": true }


static func _test_seeker_tie_ranger() -> Dictionary:
	# courage(50) == wisdom(50) → tie → courage_gte_wisdom → ranger
	var echo   := _make_echo("seeker", { "courage": 50, "wisdom": 50, "faith": 50 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var ranger := _find_option(opts, "ranger")
	if str(ranger.get("compatibility")) != "preferred":
		return { "ok": false, "error": "Expected ranger=preferred on tie, got: %s" % ranger.get("compatibility") }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — extensibility
# ────────────────────────────────────────────────────────────────────────────

static func _test_all_five_present() -> Dictionary:
	var echo := _make_echo("vanguard")
	var opts  := CallingService.compute_all_options(echo, _calling_cfg())
	if opts.size() != 5:
		return { "ok": false, "error": "Expected 5 options, got %d" % opts.size() }
	var ids: Array = []
	for o in opts:
		ids.append(str(o.get("calling_id", "")))
	for expected in ["blade", "warder", "steward", "ranger", "seer"]:
		if not ids.has(expected):
			return { "ok": false, "error": "Missing calling id: %s" % expected }
	return { "ok": true }


# ────────────────────────────────────────────────────────────────────────────
# Tests — compatible / ambivalent / incompatible tiers
# ────────────────────────────────────────────────────────────────────────────

static func _test_compatible_tier() -> Dictionary:
	# vanguard dominant (400 total). protector score=100 → 100/400=0.25 >= 0.15 → compatible
	var echo   := _make_echo("vanguard", {}, { "vanguard": 100, "protector": 100, "pillar": 100, "seeker": 100 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var warder := _find_option(opts, "warder")
	if str(warder.get("compatibility")) != "compatible":
		return { "ok": false, "error": "Expected warder=compatible, got: %s" % warder.get("compatibility") }
	return { "ok": true }


static func _test_ambivalent_tier() -> Dictionary:
	# vanguard dominant=350, pillar=20. pillar ratio=20/440=0.045 < 0.15 → ambivalent
	var echo    := _make_echo("vanguard", {}, { "vanguard": 350, "protector": 40, "pillar": 20, "seeker": 30 })
	var opts    := CallingService.compute_all_options(echo, _calling_cfg())
	var steward := _find_option(opts, "steward")
	if str(steward.get("compatibility")) != "ambivalent":
		return { "ok": false, "error": "Expected steward=ambivalent, got: %s" % steward.get("compatibility") }
	return { "ok": true }


static func _test_seeker_both_paths_compatible() -> Dictionary:
	# When seeker is dominant, both ranger and seer share seeker vector.
	# Preferred one is tagged preferred; the other should be compatible.
	var echo   := _make_echo("seeker", { "courage": 60, "wisdom": 40, "faith": 50 })
	var opts   := CallingService.compute_all_options(echo, _calling_cfg())
	var ranger := _find_option(opts, "ranger")
	var seer   := _find_option(opts, "seer")
	if str(ranger.get("compatibility")) != "preferred":
		return { "ok": false, "error": "ranger should be preferred, got: %s" % ranger.get("compatibility") }
	if str(seer.get("compatibility")) != "compatible":
		return { "ok": false, "error": "seer should be compatible, got: %s" % seer.get("compatibility") }
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
	var echo := { "calling_eligible": true, "calling": "blade" }
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
	# vanguard dominant → blade is preferred → morale boost of 10
	var echo := _make_echo_with_options("vanguard")
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "blade", _calling_cfg(), null, 0)
	if result != "blade":
		return { "ok": false, "error": "confirm_calling should return 'blade', got: %s" % result }
	if str(echo.get("calling", "")) != "blade":
		return { "ok": false, "error": "echo.calling should be 'blade'" }
	if echo.has("calling_options"):
		return { "ok": false, "error": "calling_options should be erased after confirm" }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	if after_morale != before_morale + 10:
		return { "ok": false, "error": "Expected morale=%d, got %d" % [before_morale + 10, after_morale] }
	return { "ok": true }


static func _test_confirm_compatible() -> Dictionary:
	# vanguard dominant. warder (protector vector) is compatible.
	# All scores equal (100 each) → ratio 100/400=0.25 >= 0.15 → compatible.
	var echo := _make_echo_with_options("vanguard", 60, 10)
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "warder", _calling_cfg(), null, 0)
	if result != "warder":
		return { "ok": false, "error": "confirm_calling should return 'warder', got: %s" % result }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	if after_morale != before_morale - 5:
		return { "ok": false, "error": "Expected morale dip of 5, got %d→%d" % [before_morale, after_morale] }
	return { "ok": true }


static func _test_confirm_ambivalent() -> Dictionary:
	# vanguard dominant=350, pillar=20 → steward is ambivalent.
	var echo := _make_echo("vanguard", {}, { "vanguard": 350, "protector": 40, "pillar": 20, "seeker": 30 })
	echo["emotion"] = { "morale_current": 60, "fear_current": 10 }
	echo["calling_options"] = CallingService.compute_all_options(echo, _calling_cfg())
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var before_fear: int   = int(echo["emotion"]["fear_current"])
	var result := CallingService.confirm_calling(echo, "steward", _calling_cfg(), null, 0)
	if result != "steward":
		return { "ok": false, "error": "Expected 'steward', got: %s" % result }
	var after_morale: int = int(echo["emotion"]["morale_current"])
	var after_fear: int   = int(echo["emotion"]["fear_current"])
	if after_morale != before_morale - 3:
		return { "ok": false, "error": "Expected morale dip of 3, got %d→%d" % [before_morale, after_morale] }
	if after_fear != before_fear + 3:
		return { "ok": false, "error": "Expected fear increase of 3, got %d→%d" % [before_fear, after_fear] }
	return { "ok": true }


static func _test_confirm_incompatible() -> Dictionary:
	# vanguard dominant. Make seeker score=0 → ranger/seer incompatible.
	var echo := _make_echo("vanguard", {}, { "vanguard": 300, "protector": 0, "pillar": 0, "seeker": 0 })
	echo["emotion"] = { "morale_current": 60, "fear_current": 10 }
	echo["calling_options"] = CallingService.compute_all_options(echo, _calling_cfg())
	var before_fear: int   = int(echo["emotion"]["fear_current"])
	var before_morale: int = int(echo["emotion"]["morale_current"])
	var result := CallingService.confirm_calling(echo, "ranger", _calling_cfg(), null, 0)
	if result != "ranger":
		return { "ok": false, "error": "Expected 'ranger', got: %s" % result }
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
	# vanguard dominant, pillar score=0 → steward should be incompatible, not ambivalent
	var echo := _make_echo("vanguard", {}, { "vanguard": 300, "protector": 50, "pillar": 0, "seeker": 50 })
	var opts    := CallingService.compute_all_options(echo, _calling_cfg())
	var steward := _find_option(opts, "steward")
	if str(steward.get("compatibility")) != "incompatible":
		return { "ok": false, "error": "Expected steward=incompatible (score=0), got: %s" % steward.get("compatibility") }
	return { "ok": true }
