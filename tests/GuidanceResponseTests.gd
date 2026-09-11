# res://tests/GuidanceResponseTests.gd
# The Keeper's guidance and the two axes of the answer to it — consent and reading.
#
# Every test states the regression it catches. Five are load-bearing:
#   * guidance/absent_request_changes_nothing — the safety property. It fails the
#     moment guidance leaks into a decision no one guided.
#   * guidance/refusal_is_not_idling — a refusing Echo still acts, on her own purpose.
#     This is the single most likely way to build the feature and get it wrong.
#   * guidance/reason_is_materially_true — the reason names a pressure whose removal
#     really does change the order. A reason that cannot pass this is not a reason.
#   * guidance/directive_bonus_stays_outside_the_brackets — the locked invariant that
#     `self_score = score - directive_bonus` rests on, which no other test would catch.
#   * guidance/consent_and_reading_are_independent — the axes must not re-flatten. An
#     Echo who fully agrees can still do it her own way.

class_name GuidanceResponseTests
extends RefCounted

const GuidanceScript = preload("res://core/actors/behaviors/GuidanceContribution.gd")
const DecisionTraceScript = preload("res://core/actors/behaviors/DecisionTrace.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("guidance/absent_request_changes_nothing", Callable(GuidanceResponseTests, "_t_absent_request_changes_nothing"))
	runner.register_test("guidance/an_enemy_receives_nothing", Callable(GuidanceResponseTests, "_t_an_enemy_receives_nothing"))
	runner.register_test("guidance/a_non_recipient_receives_nothing", Callable(GuidanceResponseTests, "_t_a_non_recipient_receives_nothing"))
	runner.register_test("guidance/five_responses_are_reachable", Callable(GuidanceResponseTests, "_t_five_responses_are_reachable"))
	runner.register_test("guidance/each_response_transforms_the_contribution_differently", Callable(GuidanceResponseTests, "_t_each_response_transforms_the_contribution_differently"))
	runner.register_test("guidance/refusal_is_not_idling", Callable(GuidanceResponseTests, "_t_refusal_is_not_idling"))
	runner.register_test("guidance/reason_is_materially_true", Callable(GuidanceResponseTests, "_t_reason_is_materially_true"))
	runner.register_test("guidance/reason_carries_no_number_and_no_identifier", Callable(GuidanceResponseTests, "_t_reason_carries_no_number_and_no_identifier"))
	runner.register_test("guidance/two_echoes_answer_the_same_suggestion_differently", Callable(GuidanceResponseTests, "_t_two_echoes_answer_differently"))
	runner.register_test("guidance/standing_buys_articulacy_not_obedience", Callable(GuidanceResponseTests, "_t_standing_buys_articulacy_not_obedience"))
	runner.register_test("guidance/contest_ignores_how_hard_the_keeper_pushed", Callable(GuidanceResponseTests, "_t_contest_ignores_keeper_push"))
	runner.register_test("guidance/response_is_deterministic", Callable(GuidanceResponseTests, "_t_response_is_deterministic"))
	runner.register_test("guidance/trace_names_guidance_when_it_carried_the_decision", Callable(GuidanceResponseTests, "_t_trace_names_guidance"))
	runner.register_test("guidance/directive_bonus_stays_outside_the_brackets", Callable(GuidanceResponseTests, "_t_directive_bonus_stays_outside_the_brackets"))
	runner.register_test("guidance/consent_and_reading_are_independent", Callable(GuidanceResponseTests, "_t_consent_and_reading_are_independent"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


static func _echo() -> Dictionary:
	return {"id": "echo.a", "faction": "echo"}


## One candidate as the arbiter records it. `carrier` is the score term that holds the
## entry up, so a test can take exactly one §6.6 source away and watch the order move.
static func _entry(
	key: String,
	action_type: String,
	target_id: String,
	purpose: String,
	score: float,
	carrier: String = "base",
	carrier_value: float = 0.0
) -> Dictionary:
	var components: Dictionary = {
		"base": score, "trait_bonus": 0.0, "vector_bonus": 0.0,
		"archetype_bonus": 0.0, "morale_bonus": 0.0,
		"fear_factor": 1.0, "calling_mul": 1.0,
		"directive_bonus": 0.0, "situational_bonus": 0.0,
	}
	if carrier != "base":
		components["base"] = score - carrier_value
		components[carrier] = carrier_value
	return {
		"key": key, "action_type": action_type, "target_id": target_id,
		"purpose": purpose, "commitment": 0, "capacity": 3,
		"score": score, "components": components, "spatial": {}, "bias": {},
	}


## A board she reads clearly: attacking is best, guarding is middling, standing still
## is worst. Spread 100, so a contest reads directly as a percentage of that spread.
static func _entries() -> Array:
	return [
		_entry("c0000", "melee_attack", "enemy.a", "engage", 100.0),
		_entry("c0001", "melee_attack", "enemy.b", "engage", 55.0),
		_entry("c0002", "actor.guard", "", "hold", 50.0),
		_entry("c0003", "actor.idle", "", "read", 0.0),
	]


static func _request(guidance_id: String, action_type: String, purpose: String, subject_id: String = "") -> Dictionary:
	return {
		"guidance_id": guidance_id, "action_type": action_type,
		"purpose": purpose, "subject_id": subject_id, "recipient_ids": [],
	}


## An Echo standing three cells from one enemy, on the real arbiter. `guidance`
## is whatever the caller wants in the per-turn context.
static func _live_winner(guidance: Dictionary) -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var context: Dictionary = {"actor": actor, "all_actors": [enemy], "t": 1}
	if not guidance.is_empty():
		context["guidance"] = guidance
	return BehaviorArbiter.new({}).select_intent(context)


# Test 1 — THE SAFETY PROPERTY. An unguided decision must be byte-identical to one made
# before this feature existed. FALSIFIABLE: any contribution applied outside a live
# request — a default weight, a zero-delta bias key, a reordered sort — fails here.
static func _t_absent_request_changes_nothing() -> Dictionary:
	var baseline: Dictionary = _live_winner({})
	if baseline.has("_guidance_response"):
		return _fail("an unguided decision carried a guidance response")
	# Three shapes that must all be inert: no key at all, an empty request, and a
	# request addressed to somebody else.
	var empty_request: Dictionary = _live_winner({})
	var other_recipient: Dictionary = _request("hold", "actor.guard", "hold")
	other_recipient["recipient_ids"] = ["echo.someone_else"]
	var addressed_elsewhere: Dictionary = _live_winner(other_recipient)
	for candidate_v: Variant in [empty_request, addressed_elsewhere]:
		var candidate: Dictionary = candidate_v
		if candidate.has("_guidance_response"):
			return _fail("a response was produced for an actor the suggestion never reached")
		if str(candidate.get("action_type", "")) != str(baseline.get("action_type", "")):
			return _fail("the chosen action moved without any guidance")
		var inputs: Dictionary = candidate.get("_decision_inputs", {}) as Dictionary
		var base_inputs: Dictionary = baseline.get("_decision_inputs", {}) as Dictionary
		if not is_equal_approx(
				float((inputs.get("winner", {}) as Dictionary).get("score", 0.0)),
				float((base_inputs.get("winner", {}) as Dictionary).get("score", 0.0))):
			return _fail("the winning score moved without any guidance")
	return _pass()


# Test 2 — the Keeper guides the Echoes in her care. FALSIFIABLE: a faction gate removed
# from resolve() would let a Distortion answer a suggestion it never received.
static func _t_an_enemy_receives_nothing() -> Dictionary:
	var response: Dictionary = GuidanceScript.resolve(
		_request("hold", "actor.guard", "hold"), _entries(),
		{"id": "enemy.a", "faction": "enemy"}, 0.2, 0.1
	)
	if not response.is_empty():
		return _fail("an enemy answered the Keeper: %s" % str(response))
	return _pass()


# Test 3 — absence is "unaffected", never refusal. FALSIFIABLE: a recipient list treated
# as advisory would make every Echo on the board a recipient of every suggestion.
static func _t_a_non_recipient_receives_nothing() -> Dictionary:
	var request: Dictionary = _request("hold", "actor.guard", "hold")
	request["recipient_ids"] = ["echo.b"]
	var response: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.2, 0.1)
	if not response.is_empty():
		return _fail("an Echo outside the recipients answered: %s" % str(response))
	return _pass()


# Test 4 — all five are reachable. FALSIFIABLE: a ladder that collapses two answers
# together, or a threshold moved past the [0, 1] range the contest actually occupies,
# fails here rather than at the next measurement.
static func _t_five_responses_are_reachable() -> Dictionary:
	var cases: Array = [
		# Suggest what she was already going to do.
		["align", _request("a", "melee_attack", "engage"), 0.20, 0.0],
		# Name a different enemy: same purpose, her own shape — and the coherence to hold it.
		["interpret", _request("b", "melee_attack", "engage", "enemy.b"), 0.20, 0.0],
		# The same suggestion to an Echo who cannot yet hold a purpose while changing it.
		["hesitate", _request("c", "melee_attack", "engage", "enemy.b"), 0.02, 0.0],
		# A different purpose she rates well below her own, and the coherence to say so.
		["object", _request("d", "actor.guard", "hold"), 0.20, 0.0],
		# The worst thing on her board.
		["refuse", _request("e", "actor.idle", "read"), 0.20, 0.0],
	]
	for case_v: Variant in cases:
		var case: Array = case_v
		var response: Dictionary = GuidanceScript.resolve(
			case[1] as Dictionary, _entries(), _echo(), float(case[2]), float(case[3])
		)
		if str(response.get("response", "")) != str(case[0]):
			return _fail("expected %s, got %s (contest %.4f)" % [
				str(case[0]), str(response.get("response", "")), float(response.get("contest", -1.0))
			])
	return _pass()


# Test 5 — the answers differ MECHANICALLY, not only in voice. Consent decides how much
# of the contribution arrives; reading decides which part of it does. FALSIFIABLE: an
# interpreted reading that still carries the exact plan, or an Object that quietly leaves
# the contribution applied, would be indistinguishable from its neighbour and fail here.
static func _t_each_response_transforms_the_contribution_differently() -> Dictionary:
	var entries: Array = _entries()
	var align: Dictionary = GuidanceScript.resolve(
		_request("a", "melee_attack", "engage"), entries, _echo(), 0.2, 0.0)
	if float((align["deltas"] as Dictionary).get("c0000", 0.0)) <= 0.0:
		return _fail("Align did not carry the suggested plan")

	# Name a line she cannot serve: the suggestion relaxes to its purpose, so she keeps
	# what the Keeper meant and drops the plan part.
	var interpret: Dictionary = GuidanceScript.resolve(
		_request("b", "melee_attack", "engage", "enemy.absent"), entries, _echo(), 0.2, 0.0)
	var interpret_deltas: Dictionary = interpret["deltas"] as Dictionary
	if str(interpret.get("reading", "")) != "interpreted":
		return _fail("a suggestion she could not serve as given was read literally")
	if not is_equal_approx(
			float(interpret_deltas.get("c0001", 0.0)),
			float(interpret_deltas.get("c0000", 0.0))):
		return _fail("Interpret kept the plan part: the named option was weighted above its purpose siblings")
	if float(interpret_deltas.get("c0002", 0.0)) != 0.0:
		return _fail("Interpret reached an option serving a different purpose")

	var hesitate: Dictionary = GuidanceScript.resolve(
		_request("c", "melee_attack", "engage", "enemy.b"), entries, _echo(), 0.02, 0.0)
	var hesitate_delta: float = float((hesitate["deltas"] as Dictionary).get("c0000", 0.0))
	if hesitate_delta <= 0.0 or hesitate_delta >= float(interpret_deltas.get("c0000", 0.0)):
		return _fail("Hesitate did not weaken the contribution")

	for name: String in ["object", "refuse"]:
		var request: Dictionary = _request("d", "actor.guard", "hold") if name == "object" \
			else _request("e", "actor.idle", "read")
		var response: Dictionary = GuidanceScript.resolve(request, entries, _echo(), 0.2, 0.0)
		if not (response["deltas"] as Dictionary).is_empty():
			return _fail("%s left the Keeper's contribution applied" % name)
	if not bool((GuidanceScript.resolve(
			_request("e", "actor.idle", "read"), entries, _echo(), 0.2, 0.0)
		)["recipient_dropped"]):
		return _fail("Refuse did not drop her from the suggestion's recipients")
	return _pass()


# Test 6 — A REFUSAL REMOVES THE KEEPER'S INFLUENCE, NOT THE ECHO. FALSIFIABLE: an
# implementation that treats refusal as "do nothing this turn" — the obvious wrong
# build — makes the guided winner actor.idle and fails here.
static func _t_refusal_is_not_idling() -> Dictionary:
	var unguided: Dictionary = _live_winner({})
	var guided: Dictionary = _live_winner(_request("stand_still", "actor.idle", "read"))
	var response: Dictionary = guided.get("_guidance_response", {}) as Dictionary
	if str(response.get("response", "")) != "refuse":
		return _fail("suggesting the worst option produced '%s', not a refusal" % str(response.get("response", "")))
	if str(guided.get("action_type", "")) == "actor.idle":
		return _fail("a refusing Echo went idle")
	if str(guided.get("action_type", "")) != str(unguided.get("action_type", "")):
		return _fail("a refusal changed what she did: %s vs %s" % [
			str(guided.get("action_type", "")), str(unguided.get("action_type", ""))
		])
	return _pass()


# Test 7 — THE CAUSAL CLAIM. The reason names a source; removing that source really does
# put the suggestion back ahead. FALSIFIABLE: a reason picked by magnitude alone, or by
# a fixed priority table, would name a pressure that fails this arithmetic.
static func _t_reason_is_materially_true() -> Dictionary:
	# Her own plan is held up entirely by her virtue scores; the suggestion is not.
	var entries: Array = [
		_entry("c0000", "melee_attack", "enemy.a", "engage", 100.0, "vector_bonus", 60.0),
		_entry("c0001", "actor.guard", "", "hold", 50.0),
		_entry("c0002", "actor.idle", "", "read", 0.0),
	]
	var response: Dictionary = GuidanceScript.resolve(
		_request("hold", "actor.guard", "hold"), entries, _echo(), 0.2, 0.0)
	var reason: Dictionary = response.get("reason", {}) as Dictionary
	if not bool(reason.get("material", false)):
		return _fail("a non-Align answer gave a reason it could not stand behind")
	var source: String = str(reason["source"])
	var mine: Dictionary = entries[0]
	var suggested: Dictionary = entries[1]
	var before: float = float(mine["score"]) - float(suggested["score"])
	var after: float = DecisionTraceScript.score_without(mine, source) \
		- DecisionTraceScript.score_without(suggested, source)
	if before <= 0.0 or after > 0.0:
		return _fail("removing '%s' did not reverse the order (%.2f -> %.2f)" % [source, before, after])
	if str(reason["code"]) != "values":
		return _fail("the reason named '%s' where her virtue scores carried the decision" % str(reason["code"]))
	return _pass()


# Test 8 — the reason is prose an Echo could say. FALSIFIABLE: an id or a score leaking
# into the sentence — the failure this project has a standing rule against.
static func _t_reason_carries_no_number_and_no_identifier() -> Dictionary:
	for request_v: Variant in [
		_request("b", "melee_attack", "engage", "enemy.b"),
		_request("d", "actor.guard", "hold"),
		_request("e", "actor.idle", "read"),
	]:
		var response: Dictionary = GuidanceScript.resolve(
			request_v as Dictionary, _entries(), _echo(), 0.2, 0.0)
		var text: String = str(response.get("reason_text", ""))
		if text.is_empty():
			return _fail("a non-Align answer gave no reason: %s" % str(response.get("response", "")))
		for index: int in range(text.length()):
			if text[index].is_valid_int():
				return _fail("a number reached the player-facing reason: '%s'" % text)
		if text.contains(".") or text.contains("_"):
			return _fail("an identifier reached the player-facing reason: '%s'" % text)
	return _pass()


# Test 9 — THE DECISION BELONGS TO THE ECHO. Same suggestion, same board, same turn,
# two Echoes. FALSIFIABLE: a response computed from the suggestion alone would return
# one answer for the whole party.
static func _t_two_echoes_answer_differently() -> Dictionary:
	var request: Dictionary = _request("b", "melee_attack", "engage", "enemy.b")
	var coherent: String = str(GuidanceScript.resolve(request, _entries(), _echo(), 0.20, 0.0).get("response", ""))
	var young: String = str(GuidanceScript.resolve(request, _entries(), _echo(), 0.02, 0.0).get("response", ""))
	if coherent == young:
		return _fail("two Echoes gave the same answer to the same suggestion: %s" % coherent)
	return _pass()


# Test 10 — NO OBEDIENCE SCORE. At the same contest a coherent Echo objects where a
# young one hesitates — and neither does what was suggested, because both leave the
# contribution at zero. FALSIFIABLE: a build in which Standing raises compliance would
# give the coherent Echo a non-empty contribution here.
static func _t_standing_buys_articulacy_not_obedience() -> Dictionary:
	var request: Dictionary = _request("d", "actor.guard", "hold")
	var coherent: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.20, 0.0)
	var young: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.02, 0.0)
	if str(coherent.get("response", "")) != "object" or str(young.get("response", "")) != "hesitate":
		return _fail("expected object/hesitate, got %s/%s" % [
			str(coherent.get("response", "")), str(young.get("response", ""))
		])
	if not (coherent["deltas"] as Dictionary).is_empty():
		return _fail("the more coherent Echo was made more obedient")
	return _pass()


# Test 11 — a Keeper cannot buy an answer by pressing harder. The contest is her own
# spread. FALSIFIABLE: a contest derived from the contribution's size would move when
# the suggestion's authority is scaled.
static func _t_contest_ignores_keeper_push() -> Dictionary:
	var request: Dictionary = _request("d", "actor.guard", "hold")
	var response: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.20, 0.0)
	var expected: float = (100.0 - 50.0) / 100.0
	if not is_equal_approx(float(response.get("contest", -1.0)), expected):
		return _fail("contest was %.4f, not the spread fraction %.4f" % [
			float(response.get("contest", -1.0)), expected
		])
	return _pass()


# Test 12 — same state, same answer. FALSIFIABLE: an unordered scan over a Dictionary,
# or a tie broken by anything but the recorded key, would drift between runs.
static func _t_response_is_deterministic() -> Dictionary:
	var request: Dictionary = _request("d", "actor.guard", "hold")
	var first: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.20, 0.0)
	for _repeat: int in range(8):
		var again: Dictionary = GuidanceScript.resolve(request, _entries(), _echo(), 0.20, 0.0)
		if str(again) != str(first):
			return _fail("the same state produced two different answers")
	return _pass()


# Test 13 — when the Keeper's voice carried the decision, the trace says so, with §6.6's
# own source word. FALSIFIABLE: a guidance bias not registered in DecisionTrace's tables
# would be attributed to `baseline` and the explanation would name the wrong cause.
static func _t_trace_names_guidance() -> Dictionary:
	# The suggested option trails by 4 and the guidance carries it by 10: removing the
	# guidance reverses the order, so §6.6 permits naming it.
	var winner: Dictionary = _entry("c0001", "actor.guard", "", "hold", 46.0)
	winner["bias"] = {"guidance": 10.0}
	winner["score"] = 56.0
	var runner_up: Dictionary = _entry("c0000", "melee_attack", "enemy.a", "engage", 50.0)
	var trace: Dictionary = DecisionTraceScript.build({
		"winner": winner, "runner_up": runner_up, "decision_scale": 20.0,
		"purpose": "hold", "subject_id": "", "commitment": 0, "capacity": 3,
		"hard_override": "",
	}, 0.9, {"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67}})
	var primary: Dictionary = trace["primary"] as Dictionary
	if str(primary.get("source", "")) != "guidance":
		return _fail("the trace named '%s' where the Keeper's suggestion carried the decision" % str(primary.get("source", "")))
	if str(primary.get("code", "")) != "keeper_guidance":
		return _fail("the guidance bias was not told apart from a leader's cover aura: %s" % str(primary.get("code", "")))
	return _pass()


# Test 14 — THE LOCKED INVARIANT. `directive_bonus` is a flat additive term OUTSIDE the
# fear and calling brackets, which is what makes `self_score = score - directive_bonus`
# exact. FALSIFIABLE: moving the term inside either bracket — a tidy-up no other test
# would catch — breaks this equality and silently disables divergence detection.
static func _t_directive_bonus_stays_outside_the_brackets() -> Dictionary:
	var entry: Dictionary = _entry("c0000", "melee_attack", "enemy.a", "engage", 100.0)
	var components: Dictionary = entry["components"] as Dictionary
	# Fear and the calling multiplier are both engaged, so a directive term folded into
	# either bracket would be scaled by them and the subtraction below would not close.
	components["fear_factor"] = 0.6
	components["calling_mul"] = 1.4
	components["directive_bonus"] = 12.0
	entry["score"] = float(components["base"]) * 0.6 * 1.4 + 12.0
	var without_directive: float = DecisionTraceScript.score_without(entry, "directive")
	if not is_equal_approx(without_directive, float(entry["score"]) - 12.0):
		return _fail("self_score is no longer score - directive_bonus: %.4f vs %.4f" % [
			without_directive, float(entry["score"]) - 12.0
		])
	return _pass()


# Test 15 — THE TWO AXES ARE INDEPENDENT. Consent measures how much of the suggestion
# survived; reading measures whether she took it as given or as meant. FALSIFIABLE: a
# build that folds the reading back into the consent ladder — the flattening this split
# removed — cannot produce `align` together with `interpreted` and fails here.
static func _t_consent_and_reading_are_independent() -> Dictionary:
	var entries: Array = _entries()
	# She cannot reach the line the Keeper named, and her own plan already serves the
	# purpose behind it. Full consent, and still not what he said.
	var meant: Dictionary = GuidanceScript.resolve(
		_request("a", "melee_attack", "engage", "enemy.absent"), entries, _echo(), 0.20, 0.0)
	if str(meant.get("consent", "")) != "align" or str(meant.get("reading", "")) != "interpreted":
		return _fail("expected align + interpreted, got %s + %s" % [
			str(meant.get("consent", "")), str(meant.get("reading", ""))
		])
	if str(meant.get("reason_text", "")).is_empty():
		return _fail("an interpreted reading said nothing about doing it her own way")

	# The same board and the same suggestion, read by an Echo below the interpret gate.
	var literal: Dictionary = GuidanceScript.resolve(
		_request("a", "melee_attack", "engage", "enemy.absent"), entries, _echo(), 0.02, 0.0)
	if str(literal.get("consent", "")) != "align" or str(literal.get("reading", "")) != "literal":
		return _fail("expected align + literal below the interpret gate, got %s + %s" % [
			str(literal.get("consent", "")), str(literal.get("reading", ""))
		])

	# Consent still moves on the contest alone, with the reading held at literal.
	for case_v: Variant in [
		["align", _request("b", "melee_attack", "engage")],
		["object", _request("c", "actor.guard", "hold")],
		["refuse", _request("d", "actor.idle", "read")],
	]:
		var case: Array = case_v
		var answer: Dictionary = GuidanceScript.resolve(
			case[1] as Dictionary, entries, _echo(), 0.20, 0.0)
		if str(answer.get("consent", "")) != str(case[0]):
			return _fail("expected consent %s, got %s (contest %.4f)" % [
				str(case[0]), str(answer.get("consent", "")), float(answer.get("contest", -1.0))
			])
		if str(answer.get("reading", "")) != "literal":
			return _fail("a suggestion she could serve as given was read as interpreted")
	return _pass()
