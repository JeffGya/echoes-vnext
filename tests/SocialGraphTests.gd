# res://tests/SocialGraphTests.gd
# BOND-001: Tests for SocialGraphService — tier logic, edge management, encounter recording.

extends RefCounted
class_name SocialGraphTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("social_graph/get_edge_empty_for_unknown",      Callable(SocialGraphTests, "_t_get_edge_empty_for_unknown"))
	runner.register_test("social_graph/get_edge_canonical_order",        Callable(SocialGraphTests, "_t_get_edge_canonical_order"))
	runner.register_test("social_graph/tier_at_boundaries",              Callable(SocialGraphTests, "_t_tier_at_boundaries"))
	runner.register_test("social_graph/apply_delta_clamp_max",           Callable(SocialGraphTests, "_t_apply_delta_clamp_max"))
	runner.register_test("social_graph/apply_delta_clamp_min",           Callable(SocialGraphTests, "_t_apply_delta_clamp_min"))
	runner.register_test("social_graph/apply_delta_creates_edge",        Callable(SocialGraphTests, "_t_apply_delta_creates_edge"))
	runner.register_test("social_graph/record_encounter_no_duplicate",   Callable(SocialGraphTests, "_t_record_encounter_no_duplicate"))
	runner.register_test("social_graph/archetype_pair_bidirectional",    Callable(SocialGraphTests, "_t_archetype_pair_bidirectional"))


static func _thresholds() -> Dictionary:
	return { "rival_max": -30, "friend_min": 30 }


static func _rival_pairs() -> Array:
	return [
		["proud", "empathic"],
		["valiant", "stoic"],
		["ambitious", "devout"],
		["canny", "loyal"],
	]


# 1 — get_edge returns {} on empty bonds array
static func _t_get_edge_empty_for_unknown() -> Dictionary:
	var edge := SocialGraphService.get_edge([], "alpha", "beta")
	if not edge.is_empty():
		return { "ok": false, "error": "Expected {} for unknown pair, got %s" % str(edge) }
	return { "ok": true }


# 2 — get_edge finds the edge regardless of argument order
static func _t_get_edge_canonical_order() -> Dictionary:
	var bonds: Array = [{ "actor_a": "alpha", "actor_b": "beta", "strength": 15 }]
	var fwd := SocialGraphService.get_edge(bonds, "alpha", "beta")
	var rev := SocialGraphService.get_edge(bonds, "beta", "alpha")
	if fwd.is_empty():
		return { "ok": false, "error": "Forward lookup returned {}" }
	if rev.is_empty():
		return { "ok": false, "error": "Reverse lookup returned {}" }
	if int(fwd.get("strength", 0)) != 15 or int(rev.get("strength", 0)) != 15:
		return { "ok": false, "error": "Strength mismatch: fwd=%s rev=%s" % [fwd, rev] }
	return { "ok": true }


# 3 — tier boundaries at -30/-29 and +29/+30
static func _t_tier_at_boundaries() -> Dictionary:
	var cases := [
		[-30, -2],
		[-29, -1],
		[29,   1],
		[30,   2],
		[0,    0],
	]
	for c in cases:
		var input: int = int(c[0])
		var expected: int = int(c[1])
		var got: int = SocialGraphService.get_tier(input)
		if got != expected:
			return { "ok": false, "error": "get_tier(%d) = %d, want %d" % [input, got, expected] }
	return { "ok": true }


# 4 — apply_score_delta clamps at +100
static func _t_apply_delta_clamp_max() -> Dictionary:
	var bonds: Array = [{ "actor_a": "alpha", "actor_b": "beta", "strength": 95 }]
	bonds = SocialGraphService.apply_score_delta(bonds, "alpha", "beta", 10, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "alpha", "beta")
	var strength := int(edge.get("strength", 0))
	if strength != 100:
		return { "ok": false, "error": "Expected strength=100 after clamping, got %d" % strength }
	return { "ok": true }


# 5 — apply_score_delta clamps at -100
static func _t_apply_delta_clamp_min() -> Dictionary:
	var bonds: Array = [{ "actor_a": "alpha", "actor_b": "beta", "strength": -95 }]
	bonds = SocialGraphService.apply_score_delta(bonds, "alpha", "beta", -10, _thresholds(), null, 0)
	var edge := SocialGraphService.get_edge(bonds, "alpha", "beta")
	var strength := int(edge.get("strength", 0))
	if strength != -100:
		return { "ok": false, "error": "Expected strength=-100 after clamping, got %d" % strength }
	return { "ok": true }


# 6 — apply_score_delta creates a new edge when none exists
static func _t_apply_delta_creates_edge() -> Dictionary:
	var bonds: Array = []
	bonds = SocialGraphService.apply_score_delta(bonds, "alpha", "beta", 5, _thresholds(), null, 0)
	if bonds.size() != 1:
		return { "ok": false, "error": "Expected 1 edge after delta on empty array, got %d" % bonds.size() }
	var edge := SocialGraphService.get_edge(bonds, "alpha", "beta")
	if edge.is_empty():
		return { "ok": false, "error": "Edge not findable after creation" }
	if int(edge.get("strength", 0)) != 5:
		return { "ok": false, "error": "Expected strength=5, got %d" % int(edge.get("strength", 0)) }
	return { "ok": true }


# 7 — record_encounter adds once and does not duplicate
static func _t_record_encounter_no_duplicate() -> Dictionary:
	var encounters: Array = []
	encounters = SocialGraphService.record_encounter(encounters, "alpha", "beta")
	encounters = SocialGraphService.record_encounter(encounters, "alpha", "beta")
	encounters = SocialGraphService.record_encounter(encounters, "beta", "alpha")
	if encounters.size() != 1:
		return { "ok": false, "error": "Expected 1 encounter entry, got %d" % encounters.size() }
	return { "ok": true }


# 8 — is_rival_archetype_pair is bidirectional
static func _t_archetype_pair_bidirectional() -> Dictionary:
	var pairs := _rival_pairs()
	if not SocialGraphService.is_rival_archetype_pair("proud", "empathic", pairs):
		return { "ok": false, "error": "proud+empathic not recognised as rival pair" }
	if not SocialGraphService.is_rival_archetype_pair("empathic", "proud", pairs):
		return { "ok": false, "error": "empathic+proud (reversed) not recognised as rival pair" }
	if SocialGraphService.is_rival_archetype_pair("proud", "loyal", pairs):
		return { "ok": false, "error": "proud+loyal incorrectly flagged as rival pair" }
	return { "ok": true }
