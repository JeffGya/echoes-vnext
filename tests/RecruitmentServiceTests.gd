# res://tests/RecruitmentServiceTests.gd
# V2-STAGE-004 Phase 4, S16a — Unit tests for RecruitmentService (pure-static
# except roll(), which takes an already-seeded RandomNumberGenerator).
#
# Tests:
#   1.  recruit/clamp_upper_saturates_at_cap    — maximal-input scenario: raw
#                                                  sum exceeds cap, chance clamped to cap.
#   2.  recruit/clamp_lower_never_negative       — minimal-input scenario: chance >= 0.
#   3.  recruit/breakdown_sum_matches_chance     — moderate scenario: conversation+combat+fit == chance
#                                                  (sum <= cap, so no clamping occurs).
#   3b. recruit/breakdown_sum_matches_chance_at_cap — maximal-input scenario: raw sum exceeds
#                                                  cap, components are proportionally rescaled so
#                                                  conversation+combat+fit == chance (== cap) and
#                                                  each rescaled component <= its pre-rescale value.
#   4.  recruit/roll_deterministic_same_seed     — same chance + same-seeded rng → identical bool.
#   5.  recruit/roll_zero_chance_always_false    — roll(0, rng) is always false.
#   6.  recruit/roll_hundred_chance_always_true  — roll(100, rng) is always true.
#   7.  recruit/fit_guard_empty_party            — empty party_echoes → neutral, finite fit; no crash.
#   8.  recruit/determinism_same_inputs_same_chance — identical inputs → identical chance across two calls.
#   9.  recruit/promote_returns_echo_id_shape    — promote_ally_to_echo returns "echo_%04d"-shaped id.
#   10. recruit/promote_appends_to_roster        — minted echo appended to save_data.sanctum.roster.
#   11. recruit/promote_sets_origin_rank_and_valid_actor — origin/rank fields + EchoActor.from_echo validity.
#   12. recruit/promote_seeds_negative_bond_debuff — pre-existing roster echo gets a below-neutral bond edge.
#
# Config is loaded from the real data/balance.json via ConfigService, matching the pattern
# in CallingTests.gd's _load_real_calling_cfg(). The recruitment cfg is built through
# RecruitmentService.build_effective_cfg() so the tests exercise the REAL formula — the
# canonical source blocks (data.contact.virtue_vector_key [V2-PROG-012 Phase 9], data.sanctum.
# rival_archetypes, data.contact.outcome_thresholds.good) override the recruitment block's
# own copies exactly as the runtime does it (canonical is the authoritative source).

extends RefCounted
class_name RecruitmentServiceTests


# ─── Real-config loading ──────────────────────────────────────────────────────

static func _load_balance_data() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal := cs.get_balance()
	var data_v: Variant = bal.get("data", {})
	return data_v if data_v is Dictionary else {}


static func _recruitment_cfg() -> Dictionary:
	# Merged effective cfg (canonical source blocks overlaid onto data.contact.recruitment) —
	# same dict the runtime passes to compute_recruit_chance.
	return RecruitmentService.build_effective_cfg(_load_balance_data())


# ─── Fixtures ──────────────────────────────────────────────────────────────

static func _make_contact(overrides: Dictionary = {}) -> Dictionary:
	var c := ContactModel.make(
		"contact.ally.test", "temporary_ally", "courage", "wisdom",
		50, 50, "bold", "Test Ally", 5
	)
	c["conv_score_sum"] = 0.0
	c["winning_turns"] = 0
	for k in overrides:
		c[k] = overrides[k]
	return c


static func _make_ally_actor(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"current_hp": 60,
		"max_hp": 60,
		"death_round": 0,
		"traits": { "courage": 45, "wisdom": 45, "faith": 45 },
		"stats": { "max_hp": 60, "atk": 10, "def": 8, "agi": 6, "int": 6, "cha": 5, "speed": 6 },
		"archetype_birth": "valiant",
		"gender": "",
		"class_origin": "",
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


static func _make_rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("recruit/clamp_upper_saturates_at_cap",        Callable(RecruitmentServiceTests, "_t_clamp_upper_saturates_at_cap"))
	runner.register_test("recruit/clamp_lower_never_negative",          Callable(RecruitmentServiceTests, "_t_clamp_lower_never_negative"))
	runner.register_test("recruit/breakdown_sum_matches_chance",        Callable(RecruitmentServiceTests, "_t_breakdown_sum_matches_chance"))
	runner.register_test("recruit/breakdown_sum_matches_chance_at_cap", Callable(RecruitmentServiceTests, "_t_breakdown_sum_matches_chance_at_cap"))
	runner.register_test("recruit/roll_deterministic_same_seed",        Callable(RecruitmentServiceTests, "_t_roll_deterministic_same_seed"))
	runner.register_test("recruit/roll_zero_chance_always_false",       Callable(RecruitmentServiceTests, "_t_roll_zero_chance_always_false"))
	runner.register_test("recruit/roll_hundred_chance_always_true",     Callable(RecruitmentServiceTests, "_t_roll_hundred_chance_always_true"))
	runner.register_test("recruit/fit_guard_empty_party",               Callable(RecruitmentServiceTests, "_t_fit_guard_empty_party"))
	runner.register_test("recruit/determinism_same_inputs_same_chance", Callable(RecruitmentServiceTests, "_t_determinism_same_inputs_same_chance"))
	runner.register_test("recruit/promote_returns_echo_id_shape",       Callable(RecruitmentServiceTests, "_t_promote_returns_echo_id_shape"))
	runner.register_test("recruit/promote_appends_to_roster",          Callable(RecruitmentServiceTests, "_t_promote_appends_to_roster"))
	runner.register_test("recruit/promote_sets_origin_rank_and_valid_actor", Callable(RecruitmentServiceTests, "_t_promote_sets_origin_rank_and_valid_actor"))
	runner.register_test("recruit/promote_seeds_negative_bond_debuff",  Callable(RecruitmentServiceTests, "_t_promote_seeds_negative_bond_debuff"))


# ─── Test 1 — clamp: maximal-input scenario saturates at cap ─────────────────
static func _t_clamp_upper_saturates_at_cap() -> Dictionary:
	var cfg := _recruitment_cfg()
	var cap: int = int(cfg.get("cap", 75))

	var contact := _make_contact({
		"fear": 0, "morale": 100,
		"conv_score_sum": 10.0, "winning_turns": 5, "turn_count": 5,
	})
	var ally := _make_ally_actor({
		"current_hp": 60, "max_hp": 60, "death_round": 0, "archetype_birth": "valiant",
	})
	var contribution := { "damage_dealt": 200, "kills": 3 }
	var rounds_total := 10
	var party: Array = [{
		"archetype_birth": "valiant",
		"vector_scores": { "vanguard": 60.0, "seeker": 20.0 },
		"stats": { "max_hp": 60, "atk": 10, "def": 8, "agi": 6, "int": 6, "cha": 5, "speed": 6 },
	}]

	var out := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, rounds_total, cfg)
	var chance := int(out.get("chance", -1))
	var raw_sum := int(out.get("conversation", 0)) + int(out.get("combat", 0)) + int(out.get("fit", 0))

	if chance < 0 or chance > cap:
		return { "ok": false, "error": "chance %d out of [0, %d]" % [chance, cap] }
	if raw_sum < cap:
		return { "ok": false, "error": "fixture did not saturate the cap: raw_sum=%d cap=%d (adjust fixture to actually exercise clamping)" % [raw_sum, cap] }

	return { "ok": true }


# ─── Test 2 — clamp: minimal-input scenario never negative ──────────────────
static func _t_clamp_lower_never_negative() -> Dictionary:
	var cfg := _recruitment_cfg()
	var cap: int = int(cfg.get("cap", 75))

	var contact := _make_contact({
		"fear": 100, "morale": 0,
		"conv_score_sum": 0.0, "winning_turns": 0, "turn_count": 10,
	})
	var ally := _make_ally_actor({
		"current_hp": 0, "max_hp": 60, "death_round": 1, "archetype_birth": "stoic",
	})
	var contribution := { "damage_dealt": 0, "kills": 0 }
	var rounds_total := 100000
	var party: Array = [{
		"archetype_birth": "valiant",  # rival of "stoic" per cfg.rival_archetype_pairs
		"vector_scores": { "kra_soro": 100.0 },
		"stats": { "max_hp": 9999, "atk": 999, "def": 999, "agi": 999, "int": 999, "cha": 999, "speed": 999 },
	}]

	var out := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, rounds_total, cfg)
	var chance := int(out.get("chance", -1))

	if chance < 0:
		return { "ok": false, "error": "chance %d is negative" % chance }
	if chance > cap:
		return { "ok": false, "error": "chance %d exceeds cap %d" % [chance, cap] }

	return { "ok": true }


# ─── Test 3 — breakdown sums: conversation + combat + fit == chance when sum <= cap ──
static func _t_breakdown_sum_matches_chance() -> Dictionary:
	var cfg := _recruitment_cfg()
	var cap: int = int(cfg.get("cap", 75))

	var contact := _make_contact({
		"fear": 20, "morale": 80,
		"conv_score_sum": 1.5, "winning_turns": 2, "turn_count": 4,
	})
	var ally := _make_ally_actor({
		"current_hp": 30, "max_hp": 60, "death_round": 5, "archetype_birth": "valiant",
	})
	var contribution := { "damage_dealt": 40, "kills": 0 }
	var rounds_total := 10
	var party: Array = [{
		"archetype_birth": "valiant",  # match, no rival
		# no vector_scores / stats keys — exercises the "no signal" neutral branches
	}]

	var out := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, rounds_total, cfg)
	var conversation := int(out.get("conversation", 0))
	var combat := int(out.get("combat", 0))
	var fit := int(out.get("fit", 0))
	var chance := int(out.get("chance", -1))
	var sum_pts := conversation + combat + fit

	if sum_pts > cap:
		return { "ok": false, "error": "fixture exceeded cap (sum=%d cap=%d) — cannot verify sum==chance invariant; adjust fixture to a lower-magnitude scenario" % [sum_pts, cap] }
	if sum_pts != chance:
		return { "ok": false, "error": "conversation(%d) + combat(%d) + fit(%d) = %d != chance %d" % [conversation, combat, fit, sum_pts, chance] }

	return { "ok": true }


# ─── Test 3b — rescale invariant: raw sum > cap → components scaled down to sum exactly to chance ──
# Reuses the maximal-input fixture from Test 1 (already proven to saturate raw_sum > cap).
# Runs compute_recruit_chance twice against configs that differ only in "cap": once with an
# inflated cap (no rescale triggers, so conversation/combat/fit come back as the pre-rescale
# raw points) and once with the real cap (rescale triggers). Asserts:
#   (a) chance == cap
#   (b) conversation + combat + fit == chance (the rescale invariant)
#   (c) each rescaled component <= its pre-rescale counterpart
static func _t_breakdown_sum_matches_chance_at_cap() -> Dictionary:
	var cfg := _recruitment_cfg()
	var cap: int = int(cfg.get("cap", 75))

	var contact := _make_contact({
		"fear": 0, "morale": 100,
		"conv_score_sum": 10.0, "winning_turns": 5, "turn_count": 5,
	})
	var ally := _make_ally_actor({
		"current_hp": 60, "max_hp": 60, "death_round": 0, "archetype_birth": "valiant",
	})
	var contribution := { "damage_dealt": 200, "kills": 3 }
	var rounds_total := 10
	var party: Array = [{
		"archetype_birth": "valiant",
		"vector_scores": { "vanguard": 60.0, "seeker": 20.0 },
		"stats": { "max_hp": 60, "atk": 10, "def": 8, "agi": 6, "int": 6, "cha": 5, "speed": 6 },
	}]

	# Uncapped pass: same cfg except "cap" is inflated so no rescale triggers — the returned
	# component ints are the pre-rescale raw points.
	var cfg_uncapped := cfg.duplicate(true)
	cfg_uncapped["cap"] = 999999
	var raw_out := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, rounds_total, cfg_uncapped)
	var raw_conversation := int(raw_out.get("conversation", 0))
	var raw_combat := int(raw_out.get("combat", 0))
	var raw_fit := int(raw_out.get("fit", 0))
	var raw_sum := raw_conversation + raw_combat + raw_fit

	if raw_sum <= cap:
		return { "ok": false, "error": "fixture did not exceed cap: raw_sum=%d cap=%d (adjust fixture to actually exercise rescaling)" % [raw_sum, cap] }

	# Capped pass: real cfg (real cap) — rescale must trigger.
	var out := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, rounds_total, cfg)
	var conversation := int(out.get("conversation", 0))
	var combat := int(out.get("combat", 0))
	var fit := int(out.get("fit", 0))
	var chance := int(out.get("chance", -1))

	if chance != cap:
		return { "ok": false, "error": "expected chance == cap (%d), got %d" % [cap, chance] }
	if conversation + combat + fit != chance:
		return { "ok": false, "error": "conversation(%d) + combat(%d) + fit(%d) = %d != chance %d" % [conversation, combat, fit, conversation + combat + fit, chance] }
	if conversation > raw_conversation:
		return { "ok": false, "error": "rescaled conversation %d exceeds pre-rescale value %d" % [conversation, raw_conversation] }
	if combat > raw_combat:
		return { "ok": false, "error": "rescaled combat %d exceeds pre-rescale value %d" % [combat, raw_combat] }
	if fit > raw_fit:
		return { "ok": false, "error": "rescaled fit %d exceeds pre-rescale value %d" % [fit, raw_fit] }

	return { "ok": true }


# ─── Test 4 — roll(): same chance + same-seeded rng → identical bool ─────────
static func _t_roll_deterministic_same_seed() -> Dictionary:
	var chance := 50
	var rng1 := _make_rng(777)
	var rng2 := _make_rng(777)

	var r1 := RecruitmentService.roll(chance, rng1)
	var r2 := RecruitmentService.roll(chance, rng2)

	if r1 != r2:
		return { "ok": false, "error": "roll(50, seed=777) gave %s then %s across two identically-seeded rngs" % [r1, r2] }

	return { "ok": true }


# ─── Test 5 — roll(0, rng) is always false ───────────────────────────────────
static func _t_roll_zero_chance_always_false() -> Dictionary:
	for seed_val in [1, 2, 3, 42, 9999, 123456]:
		var rng := _make_rng(seed_val)
		if RecruitmentService.roll(0, rng):
			return { "ok": false, "error": "roll(0, rng) returned true for seed %d" % seed_val }
	return { "ok": true }


# ─── Test 6 — roll(100, rng) is always true ──────────────────────────────────
static func _t_roll_hundred_chance_always_true() -> Dictionary:
	for seed_val in [1, 2, 3, 42, 9999, 123456]:
		var rng := _make_rng(seed_val)
		if not RecruitmentService.roll(100, rng):
			return { "ok": false, "error": "roll(100, rng) returned false for seed %d" % seed_val }
	return { "ok": true }


# ─── Test 7 — fit guard: empty party_echoes does not crash, returns neutral fit ──
static func _t_fit_guard_empty_party() -> Dictionary:
	var cfg := _recruitment_cfg()
	var subw_v: Variant = cfg.get("fit_subweights", {})
	var subw: Dictionary = subw_v if subw_v is Dictionary else {}
	var w_vector: float = float(subw.get("vector", 15.0))
	var w_archetype: float = float(subw.get("archetype", 8.0))
	var w_stat: float = float(subw.get("stat", 7.0))
	var expected_fit: int = int(round(0.5 * w_vector + 0.5 * w_archetype + 0.5 * w_stat))

	var contact := _make_contact()
	var ally := _make_ally_actor()
	var contribution := { "damage_dealt": 0, "kills": 0 }

	var out := RecruitmentService.compute_recruit_chance(ally, contact, [], contribution, 5, cfg)
	var fit := int(out.get("fit", -1))
	var chance := int(out.get("chance", -1))

	if fit != expected_fit:
		return { "ok": false, "error": "empty-party fit expected %d (neutral), got %d" % [expected_fit, fit] }
	if chance < 0:
		return { "ok": false, "error": "empty-party chance is negative: %d" % chance }

	return { "ok": true }


# ─── Test 8 — determinism: identical inputs → identical chance ──────────────
static func _t_determinism_same_inputs_same_chance() -> Dictionary:
	var cfg := _recruitment_cfg()
	var contact := _make_contact({ "fear": 15, "morale": 70, "conv_score_sum": 2.0, "winning_turns": 3, "turn_count": 5 })
	var ally := _make_ally_actor({ "current_hp": 45, "max_hp": 60, "death_round": 0 })
	var contribution := { "damage_dealt": 60, "kills": 1 }
	var party: Array = [{ "archetype_birth": "canny", "vector_scores": { "seeker": 40.0 }, "stats": { "max_hp": 55, "atk": 9, "def": 7, "agi": 5, "int": 8, "cha": 4, "speed": 5 } }]

	var out1 := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, 8, cfg)
	var out2 := RecruitmentService.compute_recruit_chance(ally, contact, party, contribution, 8, cfg)

	var c1 := int(out1.get("chance", -1))
	var c2 := int(out2.get("chance", -2))
	if c1 != c2:
		return { "ok": false, "error": "Determinism failure: chance %d != %d for identical inputs" % [c1, c2] }

	return { "ok": true }


# ─── promote_ally_to_echo fixtures + tests ───────────────────────────────────

## Runs a fresh promotion (own save_data each call) and returns
## { save_data, new_id, logger } for assertions.
static func _run_promotion() -> Dictionary:
	var pre_existing: Dictionary = { "id": "echo_pre", "name": "Preexisting" }
	var save_data: Dictionary = { "sanctum": { "roster": [pre_existing], "bonds": [] } }
	var cfg_data := _load_balance_data()
	var logger := StructuredLogger.new()
	var t := 0

	var ally := _make_ally_actor({ "archetype_birth": "valiant", "gender": "male" })
	var contact := _make_contact({
		"id": "contact.promote.test",
		"virtue_primary": "courage",
		"virtue_secondary": "wisdom",
	})

	var new_id := RecruitmentService.promote_ally_to_echo(ally, contact, save_data, cfg_data, logger, t)

	return { "save_data": save_data, "new_id": new_id, "logger": logger }


# ─── Test 9 — promote_ally_to_echo returns an "echo_%04d"-shaped id ──────────
static func _t_promote_returns_echo_id_shape() -> Dictionary:
	var result := _run_promotion()
	var new_id: String = str(result.get("new_id", ""))

	if not new_id.begins_with("echo_"):
		return { "ok": false, "error": "new_id '%s' does not start with 'echo_'" % new_id }
	var suffix := new_id.substr(5)
	if suffix.length() != 4:
		return { "ok": false, "error": "new_id '%s' suffix is not 4 digits" % new_id }
	if not suffix.is_valid_int():
		return { "ok": false, "error": "new_id '%s' suffix is not numeric" % new_id }

	return { "ok": true }


# ─── Test 10 — minted echo is appended to save_data.sanctum.roster ───────────
static func _t_promote_appends_to_roster() -> Dictionary:
	var result := _run_promotion()
	var save_data: Dictionary = result.get("save_data", {})
	var new_id: String = str(result.get("new_id", ""))
	var sanctum: Dictionary = save_data.get("sanctum", {})
	var roster: Array = sanctum.get("roster", [])

	if roster.size() != 2:
		return { "ok": false, "error": "expected roster size 2 (1 pre-existing + 1 minted), got %d" % roster.size() }

	var last: Dictionary = roster[roster.size() - 1]
	if str(last.get("id", "")) != new_id:
		return { "ok": false, "error": "last roster entry id '%s' != returned new_id '%s'" % [str(last.get("id", "")), new_id] }

	return { "ok": true }


# ─── Test 11 — origin/rank fields + EchoActor.from_echo validity ────────────
static func _t_promote_sets_origin_rank_and_valid_actor() -> Dictionary:
	var result := _run_promotion()
	var save_data: Dictionary = result.get("save_data", {})
	var new_id: String = str(result.get("new_id", ""))
	var sanctum: Dictionary = save_data.get("sanctum", {})
	var roster: Array = sanctum.get("roster", [])

	var minted: Dictionary = {}
	for r_v in roster:
		var r: Dictionary = r_v if r_v is Dictionary else {}
		if str(r.get("id", "")) == new_id:
			minted = r
			break

	if minted.is_empty():
		return { "ok": false, "error": "could not find minted echo '%s' in roster" % new_id }
	if str(minted.get("origin", "")) != "recruited_ally":
		return { "ok": false, "error": "expected origin 'recruited_ally', got '%s'" % str(minted.get("origin", "")) }
	if int(minted.get("rank", -1)) != 1:
		return { "ok": false, "error": "expected rank 1, got %d" % int(minted.get("rank", -1)) }

	var mapped_actor := EchoActor.from_echo(minted)
	if not ActorSchema.has_all_required_fields(mapped_actor):
		return { "ok": false, "error": "EchoActor.from_echo(minted echo) failed ActorSchema.has_all_required_fields()" }

	return { "ok": true }


# ─── Test 12 — companion bond debuff: negative edge vs. every pre-existing roster echo ──
static func _t_promote_seeds_negative_bond_debuff() -> Dictionary:
	var result := _run_promotion()
	var save_data: Dictionary = result.get("save_data", {})
	var new_id: String = str(result.get("new_id", ""))
	var sanctum: Dictionary = save_data.get("sanctum", {})
	var bonds: Array = sanctum.get("bonds", [])

	var edge := SocialGraphService.get_edge(bonds, new_id, "echo_pre")
	if edge.is_empty():
		return { "ok": false, "error": "no bond edge found between '%s' and 'echo_pre'" % new_id }

	var strength := int(edge.get("strength", 0))
	if strength >= 0:
		return { "ok": false, "error": "expected negative companion bond debuff strength, got %d" % strength }

	return { "ok": true }
