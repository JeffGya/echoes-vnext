# res://tests/IdentityIntegrityTests.gd
# V2-PROG-012 Phase 9 — Tests for the three canonical vector/virtue/calling identity
# tables (data.contact.vector_virtue_composition / virtue_vector_key /
# calling_to_virtue_primary) and their IdentityIntegrity.validate() guard.
#
# Tests:
#   1.  identity/integrity_accepts_real_config          — control case: production balance.json passes.
#   2.  identity/integrity_rejects_composition_missing_vector — composition dropping a vector is flagged.
#   3.  identity/integrity_rejects_composition_extra_vector   — composition naming an unknown vector is flagged.
#   4.  identity/integrity_rejects_composition_unknown_virtue — composition naming an unknown virtue is flagged.
#   5.  identity/integrity_rejects_key_duplicate_virtue       — virtue_vector_key mapping two vectors to the same virtue (not a bijection) is flagged.
#   6.  identity/integrity_rejects_key_missing_virtue         — virtue_vector_key never producing one of the ten virtues (not onto) is flagged.
#   7.  identity/integrity_rejects_calling_missing_entry      — calling_to_virtue_primary missing a calling is flagged.
#   8.  identity/integrity_rejects_calling_value_outside_composition — a calling's virtue not in its primary vector's composition is flagged.
#   9.  identity/integrity_rejects_recruitment_duplicate      — regression guard: a re-added data.contact.recruitment.vector_to_virtue_primary copy is flagged.
#   10. identity/virtue_vector_key_round_trip_all_ten_virtues — every one of the 10 canonical virtues is claimed by exactly one vector (bijection round-trips cleanly, the RecruitmentService._build_ally_vector_profile failure mode).
#   11. identity/conversation_service_reads_canonical_composition — sentinel-override: ConversationService._calling_to_virtue reflects an overridden vector_virtue_composition entry.
#   12. identity/conversation_service_fallback_reads_calling_primary — sentinel-override: the no-vector-data tertiary fallback reflects an overridden calling_to_virtue_primary entry.
#   13. identity/weaving_rite_service_reads_canonical_composition  — sentinel-override: WeavingRiteService.resolve_outcome's fit computation reflects an overridden vector_virtue_composition entry.
#   14. identity/recruitment_service_reads_canonical_key           — sentinel-override: RecruitmentService's vector-profile seeding reflects an overridden virtue_vector_key entry.
#   15. identity/onboarding_service_reads_canonical_key            — sentinel-override: OnboardingService.vector_for_virtue reflects an overridden virtue_vector_key entry.

extends RefCounted
class_name IdentityIntegrityTests


# ─── Registration ────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("identity/integrity_accepts_real_config", Callable(IdentityIntegrityTests, "_t_integrity_accepts_real_config"))
	runner.register_test("identity/integrity_rejects_composition_missing_vector", Callable(IdentityIntegrityTests, "_t_integrity_rejects_composition_missing_vector"))
	runner.register_test("identity/integrity_rejects_composition_extra_vector", Callable(IdentityIntegrityTests, "_t_integrity_rejects_composition_extra_vector"))
	runner.register_test("identity/integrity_rejects_composition_unknown_virtue", Callable(IdentityIntegrityTests, "_t_integrity_rejects_composition_unknown_virtue"))
	runner.register_test("identity/integrity_rejects_key_duplicate_virtue", Callable(IdentityIntegrityTests, "_t_integrity_rejects_key_duplicate_virtue"))
	runner.register_test("identity/integrity_rejects_key_missing_virtue", Callable(IdentityIntegrityTests, "_t_integrity_rejects_key_missing_virtue"))
	runner.register_test("identity/integrity_rejects_calling_missing_entry", Callable(IdentityIntegrityTests, "_t_integrity_rejects_calling_missing_entry"))
	runner.register_test("identity/integrity_rejects_calling_value_outside_composition", Callable(IdentityIntegrityTests, "_t_integrity_rejects_calling_value_outside_composition"))
	runner.register_test("identity/integrity_rejects_recruitment_duplicate", Callable(IdentityIntegrityTests, "_t_integrity_rejects_recruitment_duplicate"))
	runner.register_test("identity/virtue_vector_key_round_trip_all_ten_virtues", Callable(IdentityIntegrityTests, "_t_round_trip_all_ten_virtues"))
	runner.register_test("identity/conversation_service_reads_canonical_composition", Callable(IdentityIntegrityTests, "_t_conversation_reads_composition"))
	runner.register_test("identity/conversation_service_fallback_reads_calling_primary", Callable(IdentityIntegrityTests, "_t_conversation_fallback_reads_calling_primary"))
	runner.register_test("identity/weaving_rite_service_reads_canonical_composition", Callable(IdentityIntegrityTests, "_t_weaving_rite_reads_composition"))
	runner.register_test("identity/recruitment_service_reads_canonical_key", Callable(IdentityIntegrityTests, "_t_recruitment_reads_key"))
	runner.register_test("identity/onboarding_service_reads_canonical_key", Callable(IdentityIntegrityTests, "_t_onboarding_reads_key"))


# ─── Fixture: a complete, internally-consistent "data" dict ──────────────────
# Mirrors the shape (not necessarily every value) of the real balance.json so each
# rejection test can mutate exactly one piece of an otherwise-valid baseline.

static func _make_valid_data() -> Dictionary:
	return {
		"vectors": {
			"archetype_init": {
				"vanguard": {}, "protector": {}, "seeker": {}, "pillar": {}, "strategist": {},
				"skeptic": {}, "devoted": {}, "opportunist": {}, "mediator": {}, "nurturer": {},
			}
		},
		"contact": {
			"virtue_wheel": ["courage","leadership","truth","wisdom","humility","acceptance","forgiveness","compassion","empathy","generosity"],
			"vector_virtue_composition": {
				"vanguard":    ["courage", "leadership"],
				"protector":   ["courage", "compassion"],
				"seeker":      ["wisdom", "truth"],
				"strategist":  ["wisdom", "leadership"],
				"skeptic":     ["truth", "humility"],
				"pillar":      ["acceptance", "humility"],
				"devoted":     ["acceptance", "generosity"],
				"opportunist": ["courage", "wisdom"],
				"mediator":    ["empathy", "forgiveness"],
				"nurturer":    ["generosity", "compassion"],
			},
			"virtue_vector_key": {
				"vanguard": "courage", "protector": "leadership", "seeker": "wisdom",
				"pillar": "acceptance", "strategist": "truth", "skeptic": "humility",
				"devoted": "forgiveness", "opportunist": "generosity", "mediator": "compassion",
				"nurturer": "empathy",
			},
			"calling_to_virtue_primary": {
				"okofor": "courage", "onyamesu": "acceptance", "aduro": "courage",
				"sum_okwanfo": "courage", "okomfo": "wisdom", "kra_soro": "wisdom",
			},
			"recruitment": {},
		},
		"weaving_rite": {},
		"calling": {
			"all_callings": ["okofor", "onyamesu", "aduro", "sum_okwanfo", "okomfo", "kra_soro"],
			"definitions": {
				"okofor":      {"vector": "protector"},
				"onyamesu":    {"vector": "pillar"},
				"aduro":       {"vector": "vanguard"},
				"sum_okwanfo": {"vector": "opportunist"},
				"okomfo":      {"vector": "seeker"},
				"kra_soro":    {"vector": "seeker"},
			},
		},
	}


# ─── Test 1 — the REAL production config passes (control case) ───────────────
static func _t_integrity_accepts_real_config() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load production balance.json" }
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	if not IdentityIntegrity.validate(bdata, null, 0):
		return { "ok": false, "error": "production data.contact identity tables failed integrity check" }
	return { "ok": true }


# ─── Test 2 — composition missing a vector present in archetype_init ─────────
static func _t_integrity_rejects_composition_missing_vector() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["vector_virtue_composition"].erase("nurturer")
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject a composition missing an entry for a real vector" }
	return { "ok": true }


# ─── Test 3 — composition naming a vector NOT in archetype_init ──────────────
static func _t_integrity_rejects_composition_extra_vector() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["vector_virtue_composition"]["not_a_real_vector"] = ["courage", "wisdom"]
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject a composition entry for a vector outside data.vectors.archetype_init" }
	return { "ok": true }


# ─── Test 4 — composition naming a virtue NOT in virtue_wheel ────────────────
static func _t_integrity_rejects_composition_unknown_virtue() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["vector_virtue_composition"]["vanguard"] = ["not_a_real_virtue", "leadership"]
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject a composition virtue outside data.contact.virtue_wheel" }
	return { "ok": true }


# ─── Test 5 — virtue_vector_key is not a bijection: two vectors claim the same virtue ─
static func _t_integrity_rejects_key_duplicate_virtue() -> Dictionary:
	var data := _make_valid_data()
	# protector already maps to "leadership" in the fixture; make vanguard collide with it.
	(data["contact"] as Dictionary)["virtue_vector_key"]["vanguard"] = "leadership"
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject virtue_vector_key when two vectors claim the same virtue" }
	return { "ok": true }


# ─── Test 6 — virtue_vector_key is not onto: dropping a vector's entry leaves its
#     virtue ("courage") claimed by nobody. Distinct failure mode from Test 5 (a
#     COLLISION between two entries) — this is a DROPPED entry, no collision at all.
static func _t_integrity_rejects_key_missing_virtue() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["virtue_vector_key"].erase("vanguard")
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject virtue_vector_key when a canonical virtue (courage) is claimed by no vector" }
	return { "ok": true }


# ─── Test 7 — calling_to_virtue_primary missing an entry for a real calling ──
static func _t_integrity_rejects_calling_missing_entry() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["calling_to_virtue_primary"].erase("kra_soro")
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject calling_to_virtue_primary missing an entry for kra_soro" }
	return { "ok": true }


# ─── Test 8 — calling_to_virtue_primary value outside its primary vector's composition ─
static func _t_integrity_rejects_calling_value_outside_composition() -> Dictionary:
	var data := _make_valid_data()
	# okofor's primary vector is "protector" -> composition [courage, compassion].
	# "empathy" is not in that pair.
	(data["contact"] as Dictionary)["calling_to_virtue_primary"]["okofor"] = "empathy"
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject calling_to_virtue_primary['okofor'] = 'empathy' (not in protector's composition)" }
	return { "ok": true }


# ─── Test 9 — regression guard: a re-added recruitment-block duplicate is flagged ─
static func _t_integrity_rejects_recruitment_duplicate() -> Dictionary:
	var data := _make_valid_data()
	(data["contact"] as Dictionary)["recruitment"] = {
		"vector_to_virtue_primary": {"vanguard": "courage"},
	}
	if IdentityIntegrity.validate(data, null, 0):
		return { "ok": false, "error": "expected validate() to reject a reintroduced data.contact.recruitment.vector_to_virtue_primary copy" }
	return { "ok": true }


# ─── Test 10 — ROUND TRIP: virtue_vector_key claims all ten canonical virtues ─
# Falsifiable: if any of the 10 virtues in virtue_wheel is not a value anywhere in
# virtue_vector_key, this fails. This is exactly RecruitmentService.
# _build_ally_vector_profile's failure mode — a virtue with no vector key silently
# contributes nothing to a recruit's seeded vector_scores.
static func _t_round_trip_all_ten_virtues() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return { "ok": false, "error": "could not load production balance.json" }
	var bdata: Dictionary = cs.get_balance().get("data", {})
	var contact: Dictionary = bdata.get("contact", {})
	var virtue_wheel: Array = contact.get("virtue_wheel", [])
	var key_table: Dictionary = contact.get("virtue_vector_key", {})

	var claimed_by: Dictionary = {}  # virtue -> vector
	for vk in key_table:
		if str(vk).begins_with("_"):
			continue
		var virtue := str(key_table[vk])
		if claimed_by.has(virtue):
			return { "ok": false, "error": "virtue '%s' claimed by both '%s' and '%s' — not a bijection" % [virtue, claimed_by[virtue], vk] }
		claimed_by[virtue] = str(vk)

	for virtue_v in virtue_wheel:
		var virtue := str(virtue_v)
		if not claimed_by.has(virtue):
			return { "ok": false, "error": "virtue '%s' is not claimed by any vector in virtue_vector_key — round trip broken" % virtue }
		# Round trip: the vector that claims this virtue must map back to it exactly.
		var vector: String = claimed_by[virtue]
		if str(key_table.get(vector, "")) != virtue:
			return { "ok": false, "error": "round trip failed for virtue '%s' via vector '%s'" % [virtue, vector] }
	return { "ok": true }


# ─── Test 11 — SENTINEL OVERRIDE: ConversationService reads cfg.vector_virtue_composition ─
# Proves _calling_to_virtue is not silently falling back to a deleted hardcoded const —
# a sentinel value that exists nowhere in real game data can only come from cfg.
static func _t_conversation_reads_composition() -> Dictionary:
	var cfg := {
		"vector_virtue_composition": { "vanguard": ["sentinel_virtue_zz", "other_zz"] },
		"calling_to_virtue_primary": {},
	}
	var echo := { "dominant_vector": "vanguard" }
	var result := ConversationService._calling_to_virtue("aduro", echo, cfg)
	if result != "sentinel_virtue_zz":
		return { "ok": false, "error": "expected 'sentinel_virtue_zz' from overridden cfg.vector_virtue_composition, got '%s'" % result }
	return { "ok": true }


# ─── Test 12 — SENTINEL OVERRIDE: tertiary fallback reads cfg.calling_to_virtue_primary ─
static func _t_conversation_fallback_reads_calling_primary() -> Dictionary:
	var cfg := {
		"vector_virtue_composition": {},
		"calling_to_virtue_primary": { "okofor": "sentinel_virtue_yy" },
	}
	var echo := {}  # no dominant_vector, no vector_scores — forces tertiary fallback
	var result := ConversationService._calling_to_virtue("okofor", echo, cfg)
	if result != "sentinel_virtue_yy":
		return { "ok": false, "error": "expected 'sentinel_virtue_yy' from overridden cfg.calling_to_virtue_primary, got '%s'" % result }
	return { "ok": true }


# ─── Test 13 — SENTINEL OVERRIDE: WeavingRiteService reads cfg.vector_virtue_composition ─
# Uses the public resolve_outcome() entry point (not a private helper) so the test
# also proves the wiring through _compute_fit is intact end to end.
static func _t_weaving_rite_reads_composition() -> Dictionary:
	var cfg := {
		"max_candidates": 3,
		"fit_threshold_accept": 0.55,
		"readiness_threshold_defer": 0.38,
		"vector_virtue_composition": { "vanguard": ["sentinel_virtue_xx", "other_xx"] },
		"calling_to_virtue_primary": {},
	}
	var echo := {
		"id": "echo.1",
		"dominant_vector": "vanguard",
		"emotion": { "fear_current": 0, "morale_current": 90 },
	}
	var thread := { "id": "thread.1", "virtue": "sentinel_virtue_xx", "quality_tier": "clean" }
	var save_data := { "sanctum": { "active_party_ids": ["echo.1"], "bonds": [] } }
	var outcome := WeavingRiteService.resolve_outcome(echo, thread, save_data, cfg)
	if outcome != "accept":
		return { "ok": false, "error": "expected 'accept' (perfect fit via overridden cfg.vector_virtue_composition, high readiness), got '%s'" % outcome }
	return { "ok": true }


# ─── Test 14 — SENTINEL OVERRIDE: RecruitmentService reads cfg.virtue_vector_key ──
static func _t_recruitment_reads_key() -> Dictionary:
	var cfg := {
		"virtue_vector_key": { "sentinel_vector_ww": "sentinel_virtue_ww" },
		"vector_seed_primary": 60.0,
		"vector_seed_secondary": 20.0,
	}
	var source_contact := { "virtue_primary": "sentinel_virtue_ww", "virtue_secondary": "" }
	var profile: Dictionary = RecruitmentService._build_ally_vector_profile(source_contact, cfg)
	if not profile.has("sentinel_vector_ww"):
		return { "ok": false, "error": "expected vector profile to contain 'sentinel_vector_ww' from overridden cfg.virtue_vector_key, got %s" % str(profile) }
	if float(profile["sentinel_vector_ww"]) != 60.0:
		return { "ok": false, "error": "expected sentinel_vector_ww seeded at 60.0 (vector_seed_primary), got %s" % str(profile["sentinel_vector_ww"]) }
	return { "ok": true }


# ─── Test 15 — SENTINEL OVERRIDE: OnboardingService reads cfg.data.contact.virtue_vector_key ─
static func _t_onboarding_reads_key() -> Dictionary:
	var cfg := {
		"data": {
			"contact": {
				"virtue_vector_key": { "sentinel_vector_vv": "sentinel_virtue_vv" },
			},
		},
	}
	var result := OnboardingService.vector_for_virtue(cfg, "sentinel_virtue_vv")
	if result != "sentinel_vector_vv":
		return { "ok": false, "error": "expected 'sentinel_vector_vv' from overridden cfg.data.contact.virtue_vector_key, got '%s'" % result }
	return { "ok": true }
