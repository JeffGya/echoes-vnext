# res://tests/ArchetypeTests.gd
# Tests for the 9-archetype personality system:
#   1. Dominant courage → valiant (dominance pass)
#   2. Dominant wisdom  → canny   (dominance pass)
#   3. Dominant faith   → devout  (dominance pass)
#   4. Tied high C+F    → loyal   (band rule 1)
#   5. High C, low F    → proud   (band rule 2)
#   6. Balanced         → reflective (fallback)
#   7. combat_bias() returns a valid bias string for all 9 archetypes
#   8. dialogue_key() returns "voice_<arch>" format for all 9 archetypes
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name ArchetypeTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("archetype/dominant_courage_gives_valiant", Callable(ArchetypeTests, "_t_dominant_courage"))
	runner.register_test("archetype/dominant_wisdom_gives_canny",    Callable(ArchetypeTests, "_t_dominant_wisdom"))
	runner.register_test("archetype/dominant_faith_gives_devout",    Callable(ArchetypeTests, "_t_dominant_faith"))
	runner.register_test("archetype/tied_high_c_f_gives_loyal",      Callable(ArchetypeTests, "_t_loyal"))
	runner.register_test("archetype/high_c_low_f_gives_proud",       Callable(ArchetypeTests, "_t_proud"))
	runner.register_test("archetype/balanced_gives_reflective",      Callable(ArchetypeTests, "_t_reflective"))
	runner.register_test("archetype/combat_bias_all_valid",          Callable(ArchetypeTests, "_t_combat_bias_coverage"))
	runner.register_test("archetype/dialogue_key_format",            Callable(ArchetypeTests, "_t_dialogue_key_format"))


# -------------------------
# Tests
# -------------------------

# Test 1: dominant courage → valiant
# c=80, w=50, f=50: mean=60, dc=20 (unique max, ≥8) → valiant
static func _t_dominant_courage() -> Dictionary:
	var result := PersonalityArchetype.from_traits(80, 50, 50)
	if result != "valiant":
		return { "ok": false, "error": "Expected 'valiant' for c=80/w=50/f=50, got '%s'" % result }
	return { "ok": true }


# Test 2: dominant wisdom → canny
# c=50, w=80, f=50: mean=60, dw=20 (unique max, ≥8) → canny
static func _t_dominant_wisdom() -> Dictionary:
	var result := PersonalityArchetype.from_traits(50, 80, 50)
	if result != "canny":
		return { "ok": false, "error": "Expected 'canny' for c=50/w=80/f=50, got '%s'" % result }
	return { "ok": true }


# Test 3: dominant faith → devout
# c=50, w=50, f=80: mean=60, df=20 (unique max, ≥8) → devout
static func _t_dominant_faith() -> Dictionary:
	var result := PersonalityArchetype.from_traits(50, 50, 80)
	if result != "devout":
		return { "ok": false, "error": "Expected 'devout' for c=50/w=50/f=80, got '%s'" % result }
	return { "ok": true }


# Test 4: tied high C + high F → loyal (band rule 1)
# c=70, w=50, f=70: mean=63.3, dc=6.7, df=6.7 (tied → no unique dominance)
# C:HIGH (≥5), F:HIGH (≥5) → loyal
static func _t_loyal() -> Dictionary:
	var result := PersonalityArchetype.from_traits(70, 50, 70)
	if result != "loyal":
		return { "ok": false, "error": "Expected 'loyal' for c=70/w=50/f=70, got '%s'" % result }
	return { "ok": true }


# Test 5: high C, low F, tied C+W → proud (band rule 2)
# c=65, w=65, f=50: mean=60, dc=5 (tied dc=dw → no unique dominance)
# C:HIGH (5≥5), F:LOW (-10≤-5) → proud (rule 2 fires before siphon rule, F not MID)
static func _t_proud() -> Dictionary:
	var result := PersonalityArchetype.from_traits(65, 65, 50)
	if result != "proud":
		return { "ok": false, "error": "Expected 'proud' for c=65/w=65/f=50, got '%s'" % result }
	return { "ok": true }


# Test 6: balanced traits → reflective (fallback)
# c=55, w=55, f=55: mean=55, all deltas=0 → all MID → no rule matches → reflective
static func _t_reflective() -> Dictionary:
	var result := PersonalityArchetype.from_traits(55, 55, 55)
	if result != "reflective":
		return { "ok": false, "error": "Expected 'reflective' for c=55/w=55/f=55, got '%s'" % result }
	return { "ok": true }


# Test 7: combat_bias() returns a valid bias for all 9 archetypes
static func _t_combat_bias_coverage() -> Dictionary:
	const VALID_BIASES := ["aggressive", "cautious", "steadfast", "supportive", "balanced"]
	for arch in PersonalityArchetype.ARCHETYPES:
		var bias := PersonalityArchetype.combat_bias(arch)
		if bias not in VALID_BIASES:
			return { "ok": false, "error": "combat_bias('%s') returned invalid '%s'" % [arch, bias] }
	# Unknown archetype falls back to "balanced"
	var fallback := PersonalityArchetype.combat_bias("unknown_arch")
	if fallback != "balanced":
		return { "ok": false, "error": "Expected 'balanced' fallback for unknown arch, got '%s'" % fallback }
	return { "ok": true }


# Test 8: dialogue_key() returns "voice_<arch>" for all 9 archetypes
static func _t_dialogue_key_format() -> Dictionary:
	for arch in PersonalityArchetype.ARCHETYPES:
		var key := PersonalityArchetype.dialogue_key(arch)
		if key != "voice_" + arch:
			return { "ok": false, "error": "dialogue_key('%s') returned '%s', expected 'voice_%s'" % [arch, key, arch] }
	# Unknown archetype returns "voice_unknown"
	var fallback := PersonalityArchetype.dialogue_key("nope")
	if fallback != "voice_unknown":
		return { "ok": false, "error": "Expected 'voice_unknown' for unknown arch, got '%s'" % fallback }
	return { "ok": true }
