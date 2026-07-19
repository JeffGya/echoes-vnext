# res://tests/MovementProfileTests.gd
# V2-COMBAT-002 Slice 3 (DORMANT): movement CAPACITY profile derivation.
#
# Deterministic, hand-built actor dicts. Config is set directly (no live save
# dependency) except one wiring test that reads balance.json via ConfigService.

class_name MovementProfileTests
extends RefCounted

const ProfileService = preload("res://core/movement/MovementProfileService.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/profile/standing_bands", Callable(MovementProfileTests, "_t_standing_bands"))
	runner.register_test("movement/profile/standing_four_band_dominates", Callable(MovementProfileTests, "_t_standing_four_band_dominates"))
	runner.register_test("movement/profile/agi_thresholds", Callable(MovementProfileTests, "_t_agi_thresholds"))
	runner.register_test("movement/profile/max_semantics", Callable(MovementProfileTests, "_t_max_semantics"))
	runner.register_test("movement/profile/clamp_floor", Callable(MovementProfileTests, "_t_clamp_floor"))
	runner.register_test("movement/profile/clamp_cap", Callable(MovementProfileTests, "_t_clamp_cap"))
	runner.register_test("movement/profile/calling_bonus", Callable(MovementProfileTests, "_t_calling_bonus"))
	runner.register_test("movement/profile/skill_bonus_and_excluded", Callable(MovementProfileTests, "_t_skill_bonus_and_excluded"))
	runner.register_test("movement/profile/structure_zero", Callable(MovementProfileTests, "_t_structure_zero"))
	runner.register_test("movement/profile/authored_override_one", Callable(MovementProfileTests, "_t_authored_override_one"))
	runner.register_test("movement/profile/bare_spirit_derives_normally", Callable(MovementProfileTests, "_t_bare_spirit_derives_normally"))
	runner.register_test("movement/profile/source_terms_transparency", Callable(MovementProfileTests, "_t_source_terms_transparency"))
	runner.register_test("movement/profile/no_input_mutation", Callable(MovementProfileTests, "_t_no_input_mutation"))
	runner.register_test("movement/profile/balance_config_wired", Callable(MovementProfileTests, "_t_balance_config_wired"))


# Frozen capacity config, mirroring data.combat.movement.capacity in balance.json.
static func _cfg() -> Dictionary:
	return {
		"floor": 2, "cap": 6, "aptitude_base": 2,
		"standing_bands": [
			{"min_standing": 1, "capacity": 2},
			{"min_standing": 3, "capacity": 3},
			{"min_standing": 6, "capacity": 4},
		],
		"agi_threshold_1": 12, "agi_threshold_2": 18,
		"calling_bonus": {"kra_soro": 1},
		"skill_bonus": {"kra_soro_open_ground": 1},
	}


static func _actor(standing: int, agi: int, calling: String = "", equipped: Dictionary = {}) -> Dictionary:
	return {
		"id": "echo.test",
		"actor_type": "echo",
		"standing": standing,
		"rank": standing,
		"stats": {"agi": agi},
		"calling": calling,
		"equipped_skills": equipped.duplicate(true),
		"is_structure": false,
		"is_spirit": false,
		"is_dead": false,
		"controlling_state": true,
	}


static func _capacity(actor: Dictionary, cfg: Dictionary = {}) -> int:
	var use_cfg: Dictionary = cfg if not cfg.is_empty() else _cfg()
	var profile: Dictionary = ProfileService.derive_profile(actor, use_cfg)
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return -1  # signals validation failure to the caller
	return int(profile["capacity"])


static func _t_standing_bands() -> Dictionary:
	# agi 0 keeps aptitude at base 2, so the standing band dominates for S>=3.
	var expected: Dictionary = {1: 2, 3: 3, 6: 4, 9: 4}
	for standing_value: Variant in expected.keys():
		var standing: int = int(standing_value)
		var got: int = _capacity(_actor(standing, 0))
		if got != int(expected[standing]):
			return _fail("standing %d expected %d, got %d" % [standing, int(expected[standing]), got])
	return _pass()


static func _t_standing_four_band_dominates() -> Dictionary:
	# Verbatim Standing=4 case inside the S3–5 band (min_standing 3 -> capacity 3).
	# agi 0 keeps aptitude at base 2, so the STANDING BAND (3) — not aptitude (2) —
	# is what max(standing, aptitude) selects. Proves the band, not just the number.
	var actor: Dictionary = _actor(4, 0)
	var profile: Dictionary = ProfileService.derive_profile(actor, _cfg())
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return _fail("standing-4 profile rejected: %s" % str(validity))
	if int(profile["capacity"]) != 3:
		return _fail("standing 4 low-agi should be capacity 3, got %d" % int(profile["capacity"]))
	# Prove the final capacity was contributed by the standing band, not aptitude.
	var standing_term: int = -1
	var aptitude_term: int = -1
	for term_value: Variant in profile["source_terms"] as Array:
		var term: Dictionary = term_value as Dictionary
		if str(term.get("source", "")) == "standing_band":
			standing_term = int(term.get("capacity", -1))
		elif str(term.get("source", "")) == "aptitude_base":
			aptitude_term = int(term.get("capacity", -1))
	if standing_term != 3:
		return _fail("standing_band source term should be 3, got %d" % standing_term)
	if aptitude_term != 2:
		return _fail("aptitude_base source term should be 2, got %d" % aptitude_term)
	if standing_term <= aptitude_term:
		return _fail("capacity 3 must come from standing band (%d) over aptitude (%d)" % [standing_term, aptitude_term])
	return _pass()


static func _t_agi_thresholds() -> Dictionary:
	# Standing 1 → standing band 2, so aptitude (agi-driven) dominates.
	var cases: Array = [[11, 2], [12, 3], [18, 4]]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var got: int = _capacity(_actor(1, int(case[0])))
		if got != int(case[1]):
			return _fail("agi %d expected capacity %d, got %d" % [int(case[0]), int(case[1]), got])
	return _pass()


static func _t_max_semantics() -> Dictionary:
	# Standing 7 → standing band 4 (ceiling). max(standing, aptitude).
	if _capacity(_actor(7, 0)) != 4:
		return _fail("S7 low-agi should be 4 (standing band dominates)")
	if _capacity(_actor(7, 19)) != 4:
		return _fail("S7 agi19 should be 4 (aptitude 2+1+1 == standing 4)")
	if _capacity(_actor(7, 19, "kra_soro")) != 5:
		return _fail("S7 agi19 + kra_soro should be 5")
	if _capacity(_actor(7, 19, "kra_soro", {"0": "kra_soro_open_ground"})) != 6:
		return _fail("S7 agi19 + kra_soro + open_ground skill should be 6")
	return _pass()


static func _t_clamp_floor() -> Dictionary:
	var cfg: Dictionary = _cfg()
	cfg["aptitude_base"] = 0
	cfg["standing_bands"] = []  # force raw below the floor
	var got: int = _capacity(_actor(1, 0), cfg)
	if got != 2:
		return _fail("raw 0 should clamp up to floor 2, got %d" % got)
	return _pass()


static func _t_clamp_cap() -> Dictionary:
	var cfg: Dictionary = _cfg()
	cfg["aptitude_base"] = 8  # force raw above the cap
	var got: int = _capacity(_actor(1, 0), cfg)
	if got != 6:
		return _fail("raw 8 should clamp down to cap 6, got %d" % got)
	return _pass()


static func _t_calling_bonus() -> Dictionary:
	# Standing 1 band = 2; kra_soro pushes aptitude to 3.
	if _capacity(_actor(1, 0, "kra_soro")) != 3:
		return _fail("kra_soro calling should add +1")
	if _capacity(_actor(1, 0, "aduro")) != 2:
		return _fail("non-listed calling should add nothing")
	if _capacity(_actor(1, 0, "")) != 2:
		return _fail("empty calling should add nothing")
	return _pass()


static func _t_skill_bonus_and_excluded() -> Dictionary:
	if _capacity(_actor(1, 0, "", {"0": "kra_soro_open_ground"})) != 3:
		return _fail("kra_soro_open_ground skill should add +1")
	# sum_okwanfo_shadow_step is intentionally NOT a skill_bonus key.
	if _capacity(_actor(1, 0, "", {"0": "sum_okwanfo_shadow_step"})) != 2:
		return _fail("sum_okwanfo_shadow_step must NOT be counted")
	if _capacity(_actor(1, 0, "", {"0": "sum_okwanfo_shadow_step", "1": "kra_soro_open_ground"})) != 3:
		return _fail("only the listed skill should add, once")
	return _pass()


static func _t_structure_zero() -> Dictionary:
	var actor: Dictionary = _actor(6, 20)
	actor["is_structure"] = true
	actor["actor_type"] = "structure"
	var profile: Dictionary = ProfileService.derive_profile(actor, _cfg())
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return _fail("structure profile rejected: %s" % str(validity))
	if int(profile["capacity"]) != 0:
		return _fail("structure capacity should be 0, got %d" % int(profile["capacity"]))
	if str(profile["actor_kind"]) != "structure":
		return _fail("structure actor_kind should be 'structure'")
	if bool(profile["controlling_state"]):
		return _fail("structure should not project control")
	return _pass()


static func _t_authored_override_one() -> Dictionary:
	# Non-joining GUIDE spirit: capacity comes from an EXPLICIT caller-driven
	# authored_override, not from any actor flag. High Standing/agi are ignored.
	var actor: Dictionary = _actor(9, 20)
	actor["is_spirit"] = true
	var options: Dictionary = {"authored_override": {"source": "guide_nonjoining", "capacity": 1}}
	var profile: Dictionary = ProfileService.derive_profile(actor, _cfg(), options)
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return _fail("authored-override profile rejected: %s" % str(validity))
	if int(profile["capacity"]) != 1:
		return _fail("authored override capacity should be 1, got %d" % int(profile["capacity"]))
	var override: Dictionary = profile["authored_override"] as Dictionary
	if str(override.get("source", "")) != "guide_nonjoining" or int(override.get("capacity", -1)) != 1:
		return _fail("authored_override must echo the caller's [source,capacity]: %s" % str(override))
	# A 1-capacity mover is NEVER a structure.
	if str(profile["actor_kind"]) == "structure":
		return _fail("authored-override mover must not be modeled as a structure")
	if str(profile["actor_kind"]).is_empty():
		return _fail("authored-override mover must carry a non-empty actor_kind")
	if (profile["source_terms"] as Array) != [{"source": "guide_nonjoining", "capacity": 1}]:
		return _fail("authored-override source_terms mismatch: %s" % str(profile["source_terms"]))
	if bool(profile["controlling_state"]):
		return _fail("non-joining authored-override mover should not project control")
	return _pass()


static func _t_bare_spirit_derives_normally() -> Dictionary:
	# Without options, a plain is_spirit actor derives via the normal formula —
	# NOT auto-clamped to 1. (A JOINED combatant spirit is also is_spirit == true.)
	var actor: Dictionary = _actor(7, 19, "kra_soro", {"0": "kra_soro_open_ground"})
	actor["is_spirit"] = true
	var profile: Dictionary = ProfileService.derive_profile(actor, _cfg())
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return _fail("bare spirit profile rejected: %s" % str(validity))
	if int(profile["capacity"]) != 6:
		return _fail("bare is_spirit should derive normally (expected 6), got %d" % int(profile["capacity"]))
	if not (profile["authored_override"] as Dictionary).is_empty():
		return _fail("normal derivation must not set an authored_override")
	return _pass()


static func _t_source_terms_transparency() -> Dictionary:
	# S7 agi19 + kra_soro + open_ground: every contribution should be recorded.
	var actor: Dictionary = _actor(7, 19, "kra_soro", {"0": "kra_soro_open_ground"})
	var profile: Dictionary = ProfileService.derive_profile(actor, _cfg())
	var expected: Array = [
		{"source": "standing_band", "capacity": 4},
		{"source": "aptitude_base", "capacity": 2},
		{"source": "agi_threshold_1", "capacity": 1},
		{"source": "agi_threshold_2", "capacity": 1},
		{"source": "calling:kra_soro", "capacity": 1},
		{"source": "skill:kra_soro_open_ground", "capacity": 1},
	]
	if (profile["source_terms"] as Array) != expected:
		return _fail("source_terms mismatch: %s" % str(profile["source_terms"]))
	# Below-threshold agi omits the threshold terms.
	var lean: Dictionary = ProfileService.derive_profile(_actor(1, 5), _cfg())
	var lean_expected: Array = [
		{"source": "standing_band", "capacity": 2},
		{"source": "aptitude_base", "capacity": 2},
	]
	if (lean["source_terms"] as Array) != lean_expected:
		return _fail("lean source_terms mismatch: %s" % str(lean["source_terms"]))
	return _pass()


static func _t_no_input_mutation() -> Dictionary:
	var actor: Dictionary = _actor(7, 19, "kra_soro", {"0": "kra_soro_open_ground"})
	var actor_snapshot: Dictionary = actor.duplicate(true)
	var cfg: Dictionary = _cfg()
	var cfg_snapshot: Dictionary = cfg.duplicate(true)
	ProfileService.derive_profile(actor, cfg)
	if actor != actor_snapshot:
		return _fail("derive_profile mutated the actor dict")
	if cfg != cfg_snapshot:
		return _fail("derive_profile mutated the capacity config")
	return _pass()


static func _t_balance_config_wired() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var cap_cfg: Dictionary = config.get_balance() \
		.get("data", {}) \
		.get("combat", {}) \
		.get("movement", {}) \
		.get("capacity", {})
	if cap_cfg.is_empty():
		return _fail("data.combat.movement.capacity missing from balance.json")
	for key: String in ["floor", "cap", "aptitude_base", "standing_bands", "agi_threshold_1", "agi_threshold_2", "calling_bonus", "skill_bonus"]:
		if not cap_cfg.has(key):
			return _fail("capacity config missing key '%s'" % key)
	if int(cap_cfg["floor"]) != 2 or int(cap_cfg["cap"]) != 6 or int(cap_cfg["aptitude_base"]) != 2:
		return _fail("capacity scalar values differ from frozen spec")
	# A real echo derived from the live config must produce a bounded, valid profile.
	var actor: Dictionary = _actor(9, 18, "kra_soro", {"0": "kra_soro_open_ground"})
	var profile: Dictionary = ProfileService.derive_profile(actor, cap_cfg)
	var validity: Dictionary = ProfileContract.validate(profile)
	if not bool(validity["valid"]):
		return _fail("profile from live config rejected: %s" % str(validity))
	if int(profile["capacity"]) != 6:
		return _fail("S9 agi18 kra_soro+skill should be 6 from live config, got %d" % int(profile["capacity"]))
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
