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
	runner.register_test("divergence_bark/not_suppressed_by_routine_cooldown", Callable(CombatDivergenceBarkTests, "_t_not_suppressed_by_routine_cooldown"))
	runner.register_test("divergence_bark/no_two_in_a_row", Callable(CombatDivergenceBarkTests, "_t_no_two_in_a_row"))
	runner.register_test("divergence_bark/later_divergence_still_lands", Callable(CombatDivergenceBarkTests, "_t_later_divergence_still_lands"))


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


# Test 3 — REWRITTEN for V2-PROG-012 Phase 11. The original version of this
# test pinned the Phase 5 behaviour: combat_divergence gated by the SAME
# routine _bark_next_t cooldown as ordinary chatter. That was the defect a
# live 2026-08-09 playtest exposed — zero divergence barks surfaced across two
# full encounters despite a genuine divergence event firing, because the
# measured real Echo-only divergence rate (~0.73/encounter, post Phase
# 5 faction gate + Phase 6 recalibration) is nothing like the ~33/encounter
# Phase 5 assumed, and Phase 5's own measurement already showed only 2 of 7
# such events survived that gate. The fix ("show it, but never twice in a
# row") exempts combat_divergence from _bark_next_t entirely and gives it its
# own _divergence_bark_next_t cooldown instead (see the Priority 5.5 comment
# and the gate above in ActorStateMachine.gd). This test now pins: (a)
# divergence still wins the priority chain, (b) firing advances
# _divergence_bark_next_t — the NEW field, not _bark_next_t, (c) a second
# diverging turn one tick later stays silent EVEN THOUGH _bark_next_t is
# deliberately reset to an already-expired value going into turn 2 — proving
# the suppression comes from the divergence-specific gate, not a leftover
# dependency on the routine one. FALSIFIABLE: if combat_divergence were ever
# made to fall back to checking _bark_next_t (the pre-fix mechanism this test
# used to pin), turn 2 below would incorrectly fire, because _bark_next_t=0
# is already expired at t=1. The control block still proves the harness can
# show a genuine _HIGH_PRIORITY_BARK context (combat_last_stand) fire twice in
# a row, so turn 2's silence in the main case is a real gate, not a broken
# fixture.
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
	var next_divergence_t: int = int(actor.get("_divergence_bark_next_t", 0))
	if next_divergence_t <= 0:
		return _fail("expected _select_bark to advance _divergence_bark_next_t past 0 after firing, got %d" % next_divergence_t)

	# Deliberately reset the ROUTINE cooldown to an already-expired value —
	# isolates turn 2's suppression to _divergence_bark_next_t, proving it is
	# no longer piggybacking on _bark_next_t the way the pre-fix code did.
	actor["_bark_next_t"] = 0

	# Turn 2, one tick later — still diverged, but well inside the
	# divergence-specific cooldown window turn 1 just set (default 10 ticks;
	# see data.maturity_expression.divergence.bark_cooldown_ticks).
	asm._bark_line = ""
	asm._bark_context = ""
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 1, 1, true)
	if asm._bark_context == "combat_divergence" or not asm._bark_line.is_empty():
		return _fail(
			"combat_divergence fired on turn 2 despite _divergence_bark_next_t=%d and diverged=true (bark_context='%s', bark_line='%s') — the divergence-specific cooldown gate is not being applied" %
			[next_divergence_t, asm._bark_context, asm._bark_line])

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


# Test 6 — V2-PROG-012 Phase 11: a divergence bark is NOT suppressed by an
# unrelated recent bark. Sets _bark_next_t far into the future (as if the
# Echo had just voiced a routine "broken morale" line, whose cooldown can run
# up to 35 ticks — see _compute_bark_cooldown) and leaves
# _divergence_bark_next_t untouched (0 — never fired before), then triggers a
# divergence well inside that routine window. FALSIFIABLE: this is the exact
# pre-fix defect — before Phase 11, combat_divergence fell through to the
# generic `if t < _bark_next_t: return` gate (it was not in
# _HIGH_PRIORITY_BARK), so an Echo who had just spoken any routine line
# stayed silent on a genuine divergence for the rest of that cooldown. This
# test fails against that code because t=5 < _bark_next_t=100.
static func _t_not_suppressed_by_routine_cooldown() -> Dictionary:
	var actor: Dictionary = {"id": "echo.bark.routine", "fear": 0, "morale": 50, "_bark_next_t": 100}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 0, 5, true)
	if asm._bark_context != "combat_divergence":
		return _fail("expected combat_divergence to fire despite _bark_next_t=100 (t=5 is well inside that window), got '%s'" % asm._bark_context)
	if asm._bark_line.is_empty():
		return _fail("expected a populated bark_line even though the routine cooldown had not expired")
	return _pass()


# Test 7 — V2-PROG-012 Phase 11: the same Echo does not voice divergence
# twice in a row. Turn 1 fires at t=0 (default divergence cooldown = 10
# ticks). Turn 2 at t=7 — one full round later, at the codebase's own
# ~7-ticks/round approximation used throughout _compute_bark_cooldown's
# comments — is still inside that 10-tick window, so it must stay silent.
# FALSIFIABLE: if the divergence-specific cooldown were removed (e.g.
# combat_divergence made fully unconditional like a literal
# _HIGH_PRIORITY_BARK entry), turn 2 would also produce a populated
# combat_divergence bark and this test would fail.
static func _t_no_two_in_a_row() -> Dictionary:
	var actor: Dictionary = {"id": "echo.bark.tworow", "fear": 0, "morale": 50, "_bark_next_t": 0}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"

	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 0, 0, true)
	if asm._bark_context != "combat_divergence" or asm._bark_line.is_empty():
		return _fail("expected turn 1 (t=0) to fire a combat_divergence bark, got context='%s' line='%s'" % [asm._bark_context, asm._bark_line])

	asm._bark_line = ""
	asm._bark_context = ""
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 1, 7, true)
	if asm._bark_context == "combat_divergence" or not asm._bark_line.is_empty():
		return _fail("expected turn 2 (t=7, one round later) to stay silent — same Echo voiced divergence twice in a row (bark_context='%s', bark_line='%s')" % [asm._bark_context, asm._bark_line])
	return _pass()


# Test 8 — V2-PROG-012 Phase 11: a later, genuinely separate divergence still
# lands once the divergence-specific cooldown expires. Turn 1 fires at t=0
# (sets _divergence_bark_next_t=10 under the default cooldown). A later event
# at t=14 — two full rounds on, past that cooldown — must fire again. This is
# the test that stops the fix from becoming a permanent mute: it proves the
# cooldown is a "not twice in a row" gate, not a sticky one-shot-per-encounter
# suppression. FALSIFIABLE: if the divergence cooldown were implemented as an
# "already spoken this encounter" flag instead of an expiring tick window (or
# set far too long — e.g. reusing the 35-tick "broken morale" routine
# cooldown), turn 2 here would incorrectly stay silent.
static func _t_later_divergence_still_lands() -> Dictionary:
	var actor: Dictionary = {"id": "echo.bark.later", "fear": 0, "morale": 50, "_bark_next_t": 0}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"

	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 0, 0, true)
	if asm._bark_context != "combat_divergence" or asm._bark_line.is_empty():
		return _fail("expected turn 1 (t=0) to fire a combat_divergence bark, got context='%s' line='%s'" % [asm._bark_context, asm._bark_line])

	asm._bark_line = ""
	asm._bark_context = ""
	asm._select_bark("proud", "", "melee_attack", 0, 0, "steady", "steady", false, false, "", 1, 14, true)
	if asm._bark_context != "combat_divergence" or asm._bark_line.is_empty():
		return _fail("expected a later divergence at t=14 (past the 10-tick cooldown set by turn 1) to fire again — got context='%s' line='%s'" % [asm._bark_context, asm._bark_line])
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
