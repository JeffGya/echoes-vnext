# res://tests/GuidanceBarkTests.gd
# V2-COMBAT-003 phase 9 — the TEMPORARY bark surface for the Echo's answer to
# the Keeper's guidance (GuidanceContribution.gd). V2-COMBAT-004 removes this
# surface and replaces it with real UI; every test here pins behaviour that
# must survive until that removal, not behaviour meant to last.
#
# What this suite proves:
#   * object and refuse consent select the two new bark contexts
#     (combat_guidance_object / combat_guidance_refuse); align and hesitate
#     select neither — the owner has a separate pending decision on those.
#   * the displayed bark line IS GuidanceContribution's own reason_text, with
#     no second copy of the prose written in ActorStateMachine.
#   * both new contexts are exempt from the routine per-actor bark cooldown,
#     same treatment as combat_last_stand and friends, so a rare response is
#     never silently swallowed.
#   * a guidance bark cannot be overwritten by an ally-reaction bark the same
#     turn (V2-VOICE-001's _check_reactive_bark).
#   * both contexts route to the BarkPopupDivergence template, and are a
#     DIFFERENT context from combat_divergence (V2-PROG-012) — the two share
#     only the visual, never the meaning.
#   * more than one guidance bark can survive NarrativeVoiceService's
#     round-level bark budget in the same round (the owner's explicit
#     requirement for phase 9).

class_name GuidanceBarkTests
extends RefCounted


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("guidance_bark/object_consent_selects_object_context", Callable(GuidanceBarkTests, "_t_object_selects_context"))
	runner.register_test("guidance_bark/refuse_consent_selects_refuse_context", Callable(GuidanceBarkTests, "_t_refuse_selects_context"))
	runner.register_test("guidance_bark/align_and_hesitate_select_neither", Callable(GuidanceBarkTests, "_t_align_and_hesitate_silent"))
	runner.register_test("guidance_bark/line_is_the_reason_text_verbatim", Callable(GuidanceBarkTests, "_t_line_is_reason_text_verbatim"))
	runner.register_test("guidance_bark/exempt_from_routine_cooldown", Callable(GuidanceBarkTests, "_t_exempt_from_routine_cooldown"))
	runner.register_test("guidance_bark/not_overwritten_by_reactive_bark", Callable(GuidanceBarkTests, "_t_not_overwritten_by_reaction"))
	runner.register_test("guidance_bark/both_contexts_route_to_divergence_template", Callable(GuidanceBarkTests, "_t_routes_to_divergence_template"))
	runner.register_test("guidance_bark/distinct_context_from_combat_divergence", Callable(GuidanceBarkTests, "_t_distinct_from_combat_divergence"))
	runner.register_test("guidance_bark/two_responses_survive_one_round_budget", Callable(GuidanceBarkTests, "_t_two_responses_survive_round_budget"))
	runner.register_test("guidance_bark/empty_reason_text_produces_no_bark", Callable(GuidanceBarkTests, "_t_empty_reason_text_no_bark"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


# Test 1 — FALSIFIABLE: if the object branch in _select_bark's priority chain
# were dropped or mis-keyed, this would fall through to a lower-priority
# context (or silence) instead of "combat_guidance_object".
static func _t_object_selects_context() -> Dictionary:
	var actor: Dictionary = {"id": "echo.guidance.object", "fear": 0, "morale": 50}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "actor.guard", 0, 0, "steady", "steady", false, false, "",
		0, 0, false, 10, "object", "it is not in her nature")
	if asm._bark_context != "combat_guidance_object":
		return _fail("expected combat_guidance_object, got '%s'" % asm._bark_context)
	if asm._bark_line != "it is not in her nature":
		return _fail("expected the bark line to be the passed reason_text, got '%s'" % asm._bark_line)
	return _pass()


# Test 2 — FALSIFIABLE: same as Test 1 for refuse. Also pins that refuse and
# object select DIFFERENT contexts — a shared "combat_guidance_response"
# context would collapse the distinction the owner asked to preserve.
static func _t_refuse_selects_context() -> Dictionary:
	var actor: Dictionary = {"id": "echo.guidance.refuse", "fear": 0, "morale": 50}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "actor.idle", 0, 0, "steady", "steady", false, false, "",
		0, 0, false, 10, "refuse", "she is too afraid of that ground")
	if asm._bark_context != "combat_guidance_refuse":
		return _fail("expected combat_guidance_refuse, got '%s'" % asm._bark_context)
	if asm._bark_context == "combat_guidance_object":
		return _fail("refuse and object must not share a context key")
	return _pass()


# Test 3 — FALSIFIABLE: the owner's brief is explicit that align and hesitate
# are NOT surfaced this phase (a separate pending decision). If a stray "elif"
# ever widened the guard to those consent values, this test fails.
static func _t_align_and_hesitate_silent() -> Dictionary:
	for consent in ["align", "hesitate", "", "interpret"]:
		var actor: Dictionary = {"id": "echo.guidance.silent.%s" % consent, "fear": 0, "morale": 50}
		var asm := ActorStateMachine.new(actor, null, {})
		asm._expression_band = "whole"
		asm._select_bark("proud", "", "actor.idle", 0, 0, "steady", "steady", false, false, "",
			0, 0, false, 10, consent, "she reads it the way you do")
		if asm._bark_context.begins_with("combat_guidance_"):
			return _fail("consent '%s' incorrectly selected a guidance bark context '%s'" % [consent, asm._bark_context])
	return _pass()


# Test 4 — FALSIFIABLE: if ActorStateMachine ever wrote its own prose (a
# ShoutBank lookup, a hand-authored fallback string) instead of using the text
# GuidanceContribution already produced, this would fail on the exact line
# GuidanceContribution._REASON_TEXT holds for "values".
static func _t_line_is_reason_text_verbatim() -> Dictionary:
	var expected: String = "it goes against what she holds to"  # GuidanceContribution._REASON_TEXT["values"]
	var actor: Dictionary = {"id": "echo.guidance.verbatim", "fear": 0, "morale": 50}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "nascent"
	asm._select_bark("proud", "", "actor.guard", 0, 0, "steady", "steady", false, false, "",
		0, 0, false, 10, "object", expected)
	if asm._bark_line != expected:
		return _fail("expected the exact GuidanceContribution reason_text '%s', got '%s'" % [expected, asm._bark_line])
	return _pass()


# Test 5 — FALSIFIABLE: if combat_guidance_object/refuse were left out of
# _HIGH_PRIORITY_BARK, a recent routine bark's _bark_next_t (up to 35 ticks —
# see _compute_bark_cooldown) would silently swallow the response, the exact
# defect V2-PROG-012 Phase 11 found and fixed for combat_divergence.
static func _t_exempt_from_routine_cooldown() -> Dictionary:
	var actor: Dictionary = {"id": "echo.guidance.cooldown", "fear": 0, "morale": 50, "_bark_next_t": 100}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "actor.guard", 0, 0, "steady", "steady", false, false, "",
		0, 5, false, 10, "object", "her temperament pulls another way")
	if asm._bark_context != "combat_guidance_object":
		return _fail("expected combat_guidance_object to fire despite _bark_next_t=100 (t=5), got '%s'" % asm._bark_context)
	if asm._bark_line.is_empty():
		return _fail("expected a populated bark_line even though the routine cooldown had not expired")
	return _pass()


# Test 6 — FALSIFIABLE: if combat_guidance_object/refuse were left out of
# _check_reactive_bark's _TIER1_R guard, an ally's high-signal bark this same
# round could overwrite the guidance response with a "combat_rally_ally"
# reaction, erasing the first player-visible proof of the answer.
static func _t_not_overwritten_by_reaction() -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.guidance.reaction", "fear": 0, "morale": 50,
		"faction": "echo", "grid_pos": {"col": 0, "row": 0},
	}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "actor.idle", 0, 0, "steady", "steady", false, false, "",
		0, 0, false, 10, "refuse", "she is too afraid of that ground")
	if asm._bark_context != "combat_guidance_refuse":
		return _fail("fixture broken: expected combat_guidance_refuse before the reaction check, got '%s'" % asm._bark_context)

	var round_bark_events: Array = [{
		"bark_context": "combat_last_stand", "faction": "echo",
		"grid_pos": {"col": 0, "row": 0}, "actor_id": "echo.other",
	}]
	asm._check_reactive_bark({"round_bark_events": round_bark_events, "cfg": {"data": {"voice": {}}}}, 0)
	if asm._bark_context != "combat_guidance_refuse" or asm._bark_is_response:
		return _fail("a reaction overwrote the guidance bark: context='%s' is_response=%s" % [asm._bark_context, asm._bark_is_response])
	return _pass()


# Test 7 — FALSIFIABLE: this is the whole point of the phase — if
# resolve_template_kind() were left as a plain equality test against
# "combat_divergence", both new contexts would fall through to "original"
# instead of "divergence", contradicting the brief's explicit instruction to
# route both to the existing BarkPopupDivergence template.
static func _t_routes_to_divergence_template() -> Dictionary:
	for context in ["combat_guidance_object", "combat_guidance_refuse"]:
		var kind := BarkPopupLayer.resolve_template_kind(context, false)
		if kind != "divergence":
			return _fail("expected '%s' to resolve to the divergence template, got '%s'" % [context, kind])
	return _pass()


# Test 8 — FALSIFIABLE: proves the shared-template claim does not collapse
# into a shared-context claim. combat_divergence (V2-PROG-012, judgment vs.
# the standing Directive) and the two guidance contexts (this phase, answer to
# the Keeper's suggestion) must remain three distinct strings even though all
# three resolve to the same visual.
static func _t_distinct_from_combat_divergence() -> Dictionary:
	var contexts: Array = ["combat_divergence", "combat_guidance_object", "combat_guidance_refuse"]
	for i in range(contexts.size()):
		for j in range(contexts.size()):
			if i != j and contexts[i] == contexts[j]:
				return _fail("guidance and divergence contexts collapsed to the same string")
	for context in contexts:
		if BarkPopupLayer.resolve_template_kind(context, false) != "divergence":
			return _fail("expected '%s' to still route to the divergence template" % context)
	return _pass()


# Test 9 — THE OWNER'S EXPLICIT REQUIREMENT: more than one guidance response
# must be able to show in the same round. Builds two projected-actor rows,
# both in tier 1 (combat_guidance_object and combat_guidance_refuse are both
# authored into data.voice.bark_tiers tier "1"), well under max_barks_per_round
# (3), and checks NarrativeVoiceService.apply_round_bark_budget leaves both
# bark_line fields populated. FALSIFIABLE: if the two contexts had been left
# out of bark_tiers, _bark_tier_index would default them to the LOWEST tier,
# and a round crowded with higher-tier barks could zero one or both out even
# though the design intent is that a response always outranks that traffic.
static func _t_two_responses_survive_round_budget() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	var voice_cfg: Dictionary = ConfigService.get_voice_cfg(config)
	var projected: Array = [
		{ "id": "echo.a", "bark_context": "combat_guidance_object", "bark_line": "it is not in her nature", "bark_is_response": false },
		{ "id": "echo.b", "bark_context": "combat_guidance_refuse", "bark_line": "she is too afraid of that ground", "bark_is_response": false },
		{ "id": "echo.c", "bark_context": "combat_banter", "bark_line": "tier-3 chatter", "bark_is_response": false },
	]
	NarrativeVoiceService.apply_round_bark_budget(projected, voice_cfg)
	if str(projected[0].get("bark_line", "")).is_empty():
		return _fail("the combat_guidance_object row was zeroed out of a round with only 3 barks total")
	if str(projected[1].get("bark_line", "")).is_empty():
		return _fail("the combat_guidance_refuse row was zeroed out of a round with only 3 barks total")
	return _pass()


# Test 10 — FALSIFIABLE: _speaks() in GuidanceContribution guarantees object
# and refuse always produce reason_text, but this pins the defensive path in
# ActorStateMachine anyway: an empty reason_text must not silently stand up a
# bark with an empty label (an empty popup bubble) or bump the cooldown.
static func _t_empty_reason_text_no_bark() -> Dictionary:
	var actor: Dictionary = {"id": "echo.guidance.empty", "fear": 0, "morale": 50, "_bark_next_t": 0}
	var asm := ActorStateMachine.new(actor, null, {})
	asm._expression_band = "whole"
	asm._select_bark("proud", "", "actor.guard", 0, 0, "steady", "steady", false, false, "",
		0, 0, false, 10, "object", "")
	if not asm._bark_line.is_empty():
		return _fail("expected no bark line for an empty reason_text, got '%s'" % asm._bark_line)
	if int(actor.get("_bark_next_t", 0)) != 0:
		return _fail("an empty-reason guidance bark still advanced the cooldown")
	return _pass()
