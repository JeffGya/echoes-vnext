# res://tests/CombatDivergenceBarkTests.gd
# V2-PROG-012 Phase 5 — combat_divergence bark content + wiring tests.
#
# Every test here is written to FAIL if the behaviour it pins were reverted —
# see the comment above each test for the specific regression it catches.

class_name CombatDivergenceBarkTests
extends RefCounted

const _ARCHETYPES: Array[String] = [
	"loyal", "proud", "reflective", "valiant", "canny",
	"devout", "stoic", "empathic", "ambitious",
]
const _BANDS: Array[String] = ["nascent", "forming", "grounded", "whole"]


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("divergence_bark/every_slot_populated", Callable(CombatDivergenceBarkTests, "_t_every_slot_populated"))
	runner.register_test("divergence_bark/specificity_ladder_holds", Callable(CombatDivergenceBarkTests, "_t_specificity_ladder_holds"))
	runner.register_test("divergence_bark/cooldown_gated_not_high_priority", Callable(CombatDivergenceBarkTests, "_t_cooldown_gated_not_high_priority"))
	runner.register_test("divergence_bark/determinism", Callable(CombatDivergenceBarkTests, "_t_determinism"))
	runner.register_test("divergence_bark/voice_distinctness", Callable(CombatDivergenceBarkTests, "_t_voice_distinctness"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


# Test 1 — every (archetype, band) slot resolves to a real line, not ShoutBank's
# generic cross-context fallback. FALSIFIABLE: remove any one of the 36 slots
# from data/shouts/combat_expressions.json's combat_divergence block (or typo
# an archetype/band key) and this test fails on that exact pair — a missing
# slot would otherwise silently degrade to "I'll do my part." in production.
static func _t_every_slot_populated() -> Dictionary:
	for arch: String in _ARCHETYPES:
		for band: String in _BANDS:
			var line := ShoutBank.get_expression_shout("combat_divergence", arch, band, "", 0)
			if line.is_empty():
				return _fail("combat_divergence.%s.%s resolved to an empty string" % [arch, band])
			if line == "I'll do my part.":
				return _fail("combat_divergence.%s.%s fell back to ShoutBank's generic fallback line — slot is missing" % [arch, band])
	return _pass()


# Test 2 — the specificity ladder (GDD §7.3 legibility) holds structurally, not
# just for one hand-picked string: for every archetype and every authored
# variation, the "whole" line is longer than the "nascent" line at the same
# variation index. Length is a coarse proxy, but the ladder's whole design is
# "nascent = impulse only, whole = reason + alternative" — a whole line that
# is SHORTER than its nascent counterpart cannot possibly be naming a reason
# AND offering an alternative. FALSIFIABLE: swap any archetype's whole/nascent
# arrays in combat_expressions.json (or shorten a whole line to a bare "No.")
# and this test fails on that archetype.
static func _t_specificity_ladder_holds() -> Dictionary:
	for arch: String in _ARCHETYPES:
		for vk in range(3):
			var nascent_line := ShoutBank.get_expression_shout("combat_divergence", arch, "nascent", "", vk)
			var whole_line := ShoutBank.get_expression_shout("combat_divergence", arch, "whole", "", vk)
			if whole_line.length() <= nascent_line.length():
				return _fail(
					"expected whole-band line longer than nascent for '%s' (variation %d): whole='%s' (%d chars) vs nascent='%s' (%d chars)" %
					[arch, vk, whole_line, whole_line.length(), nascent_line, nascent_line.length()])
	return _pass()


# Test 3 — combat_divergence is cooldown-gated, not smuggled into
# _HIGH_PRIORITY_BARK. Calls _select_bark() directly (same pattern VoiceTests.gd
# uses for _check_reactive_bark) across two consecutive turns with diverged=true
# both times and nothing else in the priority chain competing (fear/morale
# unchanged, not last stand, not resilience). FALSIFIABLE: if combat_divergence
# were added to _HIGH_PRIORITY_BARK (bypassing the _bark_next_t gate the way
# combat_last_stand/combat_resilient/combat_fear_extreme/combat_fear_rising/
# combat_morale_falling do), turn 2 below would also produce a populated
# combat_divergence bark and this test would fail. The control block proves the
# harness itself CAN show a bark firing twice in a row (using a genuine
# high-priority context), so turn 2's silence in the main case is the cooldown
# gate working, not a broken fixture.
static func _t_cooldown_gated_not_high_priority() -> Dictionary:
	var actor: Dictionary = {"id": "echo.bark.test", "fear": 0, "morale": 50, "_bark_next_t": 0}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"

	# Turn 1 (t=0): divergence wins the priority chain and fires.
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 0, 0, true)
	if asm._bark_context != "combat_divergence":
		return _fail("expected combat_divergence to win turn 1's priority chain, got '%s'" % asm._bark_context)
	if asm._bark_line.is_empty():
		return _fail("expected a populated bark_line on turn 1")
	var next_t: int = int(actor.get("_bark_next_t", 0))
	if next_t <= 0:
		return _fail("expected _select_bark to advance _bark_next_t past 0 after firing, got %d" % next_t)

	# Turn 2, one tick later — still diverged, but well inside the cooldown
	# window _compute_bark_cooldown() just set (minimum 14 ticks).
	asm._bark_line = ""
	asm._bark_context = ""
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 1, 1, true)
	if asm._bark_context == "combat_divergence" or not asm._bark_line.is_empty():
		return _fail(
			"combat_divergence bypassed the cooldown gate on turn 2 (bark_context='%s', bark_line='%s') — it must not be in _HIGH_PRIORITY_BARK" %
			[asm._bark_context, asm._bark_line])

	# Control: a genuine _HIGH_PRIORITY_BARK context (combat_last_stand) DOES
	# fire on consecutive turns, proving the harness can show a repeat bark.
	var actor2: Dictionary = {"id": "echo.bark.control", "fear": 0, "morale": 50, "_bark_next_t": 0}
	var asm2 := ActorStateMachine.new(actor2, null, {})
	asm2._expression_band = "whole"
	asm2._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", true, false, "", 0, 0, false)
	if asm2._bark_context != "combat_last_stand":
		return _fail("control fixture broken: expected combat_last_stand on turn 1, got '%s'" % asm2._bark_context)
	asm2._bark_line = ""
	asm2._bark_context = ""
	asm2._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", true, false, "", 1, 1, false)
	if asm2._bark_context != "combat_last_stand":
		return _fail("control fixture broken: expected combat_last_stand to bypass the cooldown gate on turn 2 (it IS in _HIGH_PRIORITY_BARK), got '%s'" % asm2._bark_context)

	return _pass()


# Test 4 — determinism. Same actor id, same expression band, same archetype/
# calling, same t, same variation_key, diverged=true both times, on two
# independently-constructed ActorStateMachine instances. FALSIFIABLE: if
# _select_bark's combat_divergence branch ever drew from CampaignSeed, RNG, or
# any non-deterministic source instead of reusing the existing
# (t + id.hash()) % 997 variation_key, the two lines below could differ.
static func _t_determinism() -> Dictionary:
	var actor_a: Dictionary = {"id": "echo.det.1", "fear": 0, "morale": 50}
	var asm_a := ActorStateMachine.new(actor_a, null, {})
	asm_a._expression_band = "grounded"
	asm_a._select_bark("empathic", "okofor", "melee_attack", 0, 0, "steady", "steady", false, false, "", 17, 5, true)

	var actor_b: Dictionary = {"id": "echo.det.1", "fear": 0, "morale": 50}
	var asm_b := ActorStateMachine.new(actor_b, null, {})
	asm_b._expression_band = "grounded"
	asm_b._select_bark("empathic", "okofor", "melee_attack", 0, 0, "steady", "steady", false, false, "", 17, 5, true)

	if asm_a._bark_context != "combat_divergence" or asm_b._bark_context != "combat_divergence":
		return _fail("expected bark_context='combat_divergence' on both runs, got '%s' and '%s'" % [asm_a._bark_context, asm_b._bark_context])
	if asm_a._bark_line.is_empty() or asm_b._bark_line.is_empty():
		return _fail("expected a populated bark_line on both runs")
	if asm_a._bark_line != asm_b._bark_line:
		return _fail("same actor/band/tick/variation_key produced different combat_divergence lines: '%s' vs '%s'" % [asm_a._bark_line, asm_b._bark_line])
	return _pass()


# Test 5 — voice distinctness. No identical line text is shared across two
# different archetypes at the same band (every authored variation, 0-2).
# FALSIFIABLE: copy-pasting one archetype's line into another archetype's slot
# at the same band (an easy authoring mistake with 36 slots to fill) makes this
# test fail on that exact pair.
static func _t_voice_distinctness() -> Dictionary:
	for band: String in _BANDS:
		var seen: Dictionary = {}  # line text -> archetype that first used it
		for arch: String in _ARCHETYPES:
			for vk in range(3):
				var line := ShoutBank.get_expression_shout("combat_divergence", arch, band, "", vk)
				if seen.has(line) and str(seen[line]) != arch:
					return _fail("identical combat_divergence line shared by '%s' and '%s' at band '%s': '%s'" % [str(seen[line]), arch, band, line])
				seen[line] = arch
	return _pass()
