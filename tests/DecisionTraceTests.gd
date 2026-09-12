# res://tests/DecisionTraceTests.gd
# The Decision Trace (docs/movement-model.md §6.6).
#
# Every test states the regression it catches. Two of them are the load-bearing
# ones for this phase:
#   * trace/sanitized_projection_is_closed — the boundary. It fails if anyone
#     widens the player-facing projection to carry scores, weights or
#     debug_components.
#   * trace/counterfactual_removal_flips_winner — the causal claim. It removes the
#     contribution the trace named and shows the arbiter's own winner changes.

class_name DecisionTraceTests
extends RefCounted

const DecisionTraceScript = preload("res://core/actors/behaviors/DecisionTrace.gd")

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("trace/shape_matches_contract", Callable(DecisionTraceTests, "_t_shape_matches_contract"))
	runner.register_test("trace/sanitized_projection_is_closed", Callable(DecisionTraceTests, "_t_sanitized_projection_is_closed"))
	runner.register_test("trace/sanitized_projection_carries_no_numbers", Callable(DecisionTraceTests, "_t_sanitized_projection_carries_no_numbers"))
	runner.register_test("trace/reconstructs_recorded_score", Callable(DecisionTraceTests, "_t_reconstructs_recorded_score"))
	runner.register_test("trace/counterfactual_removal_flips_winner", Callable(DecisionTraceTests, "_t_counterfactual_removal_flips_winner"))
	runner.register_test("trace/tie_breaker_is_not_promoted", Callable(DecisionTraceTests, "_t_tie_breaker_is_not_promoted"))
	runner.register_test("trace/hard_override_wins_outright", Callable(DecisionTraceTests, "_t_hard_override_wins_outright"))
	runner.register_test("trace/legibility_governs_specificity", Callable(DecisionTraceTests, "_t_legibility_governs_specificity"))
	runner.register_test("trace/production_turn_is_explainable", Callable(DecisionTraceTests, "_t_production_turn_is_explainable"))
	runner.register_test("trace/decision_inputs_never_leave_the_state_machine", Callable(DecisionTraceTests, "_t_decision_inputs_never_leave_the_state_machine"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


static func _cfg() -> Dictionary:
	return {"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67}}


## A winner carried by its virtue scores, against a runner-up that has none.
## `vector_bonus` 30.0 against a margin of 20.0: removing it reverses the order.
static func _decisive_inputs() -> Dictionary:
	return {
		"winner": {
			"action_type": "actor.move", "target_id": "enemy.a", "score": 70.0,
			"components": {
				"base": 40.0, "trait_bonus": 0.0, "vector_bonus": 30.0,
				"archetype_bonus": 0.0, "morale_bonus": 0.0,
				"fear_factor": 1.0, "calling_mul": 1.0,
				"directive_bonus": 0.0, "situational_bonus": 0.0,
			},
			"spatial": {}, "bias": {},
		},
		"runner_up": {
			"action_type": "actor.guard", "target_id": "", "score": 50.0,
			"components": {
				"base": 50.0, "trait_bonus": 0.0, "vector_bonus": 0.0,
				"archetype_bonus": 0.0, "morale_bonus": 0.0,
				"fear_factor": 1.0, "calling_mul": 1.0,
				"directive_bonus": 0.0, "situational_bonus": 0.0,
			},
			"spatial": {}, "bias": {},
		},
		"decision_scale": 20.0,
		"purpose": "advance",
		"subject_id": "enemy.a",
		"commitment": 2, "capacity": 3,
		"hard_override": "",
	}


# Test 1 — the §6.6 field set, exactly. FALSIFIABLE: a build() that dropped
# `material`, renamed `causal_kind`, or invented a source outside §6.6's twelve
# would fail here.
static func _t_shape_matches_contract() -> Dictionary:
	var trace: Dictionary = DecisionTraceScript.build(_decisive_inputs(), 0.5, _cfg())
	var expected_top: Array = [
		"primary", "supporting", "purpose", "message_key", "message_args",
		"voice_tone", "debug_components",
	]
	var actual_top: Array = trace.keys()
	actual_top.sort()
	expected_top.sort()
	if actual_top != expected_top:
		return _fail("§6.6 top-level field set drifted: %s" % str(actual_top))
	var primary: Dictionary = trace["primary"] as Dictionary
	var expected_primary: Array = [
		"code", "source", "subject_id", "causal_kind", "material", "strength_band",
	]
	var actual_primary: Array = primary.keys()
	actual_primary.sort()
	expected_primary.sort()
	if actual_primary != expected_primary:
		return _fail("§6.6 primary field set drifted: %s" % str(actual_primary))
	if not DecisionTraceScript.SOURCES.has(str(primary["source"])):
		return _fail("source outside the §6.6 vocabulary: %s" % str(primary["source"]))
	if not DecisionTraceScript.CAUSAL_KINDS.has(str(primary["causal_kind"])):
		return _fail("causal_kind outside the §6.6 vocabulary: %s" % str(primary["causal_kind"]))
	if not (primary["material"] is bool):
		return _fail("material must be a bool, got %s" % str(primary["material"]))
	if str(primary["source"]) != "vector":
		return _fail("expected the decisive virtue contribution to be primary, got %s" % str(primary))
	return _pass()


# Test 2 — THE BOUNDARY. §6.6: a player-facing surface carries only reason code and
# source, subject, purpose, message key and arguments, voice tone. FALSIFIABLE by
# construction: this pins the projection's exact key set at both levels, so widening
# sanitize() to pass through `debug_components`, `supporting`, `strength_band`, or a
# raw score fails immediately — which is the point, since the leak would otherwise be
# invisible until it reached a screen.
static func _t_sanitized_projection_is_closed() -> Dictionary:
	var trace: Dictionary = DecisionTraceScript.build(_decisive_inputs(), 0.9, _cfg())
	var safe: Dictionary = DecisionTraceScript.sanitize(trace)

	var actual: Array = safe.keys()
	actual.sort()
	var allowed: Array = DecisionTraceScript.PLAYER_SAFE_FIELDS.duplicate()
	allowed.sort()
	if actual != allowed:
		return _fail("sanitized projection is not the §6.6 field set: %s" % str(actual))

	var actual_primary: Array = (safe["primary"] as Dictionary).keys()
	actual_primary.sort()
	var allowed_primary: Array = DecisionTraceScript.PLAYER_SAFE_PRIMARY_FIELDS.duplicate()
	allowed_primary.sort()
	if actual_primary != allowed_primary:
		return _fail("sanitized primary is not code/source/subject: %s" % str(actual_primary))

	for forbidden: String in ["debug_components", "supporting", "material", "causal_kind", "strength_band"]:
		if safe.has(forbidden) or (safe["primary"] as Dictionary).has(forbidden):
			return _fail("sanitized projection leaked '%s'" % forbidden)
	return _pass()


# Test 3 — no number of any kind survives the projection. Complements test 2: a
# widened projection could keep the right KEYS and still carry a score inside
# message_args. FALSIFIABLE: putting any float/int into the sanitized payload fails.
static func _t_sanitized_projection_carries_no_numbers() -> Dictionary:
	var trace: Dictionary = DecisionTraceScript.build(_decisive_inputs(), 0.9, _cfg())
	var leak: String = _find_number(DecisionTraceScript.sanitize(trace), "")
	if not leak.is_empty():
		return _fail("sanitized projection carries a raw number at %s" % leak)
	# The unsanitized trace MUST still carry them — core and logging keep the full
	# decomposition, and a test that passed for both would be proving nothing.
	if _find_number(trace, "").is_empty():
		return _fail("the full trace carries no numbers at all — debug_components is not being populated")
	return _pass()


static func _find_number(value: Variant, path: String) -> String:
	if value is float or value is int:
		return path
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			var found: String = _find_number((value as Dictionary)[key], "%s/%s" % [path, str(key)])
			if not found.is_empty():
				return found
	if value is Array:
		for index: int in range((value as Array).size()):
			var found: String = _find_number((value as Array)[index], "%s/%d" % [path, index])
			if not found.is_empty():
				return found
	return ""


# Test 4 — the trace reads the REAL decomposition. Reconstructing the score from the
# recorded parts must reproduce the arbiter's own value on a live production
# candidate, spatial clamp and all. FALSIFIABLE: if `_score()`, `_spatial_utility()`
# or a post-scoring bias gained a term that nothing recorded, the reconstruction
# would drift from the recorded score and this fails — which is exactly the "a second
# copy of the arithmetic" failure this phase must not introduce.
static func _t_reconstructs_recorded_score() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var winner: Dictionary = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 1})
	var inputs: Dictionary = winner.get("_decision_inputs", {}) as Dictionary
	if inputs.is_empty():
		return _fail("select_intent() attached no _decision_inputs")
	for role: String in ["winner", "runner_up"]:
		var entry: Dictionary = inputs.get(role, {}) as Dictionary
		if entry.is_empty():
			continue
		var rebuilt: float = DecisionTraceScript.score_without(entry, "")
		if not is_equal_approx(rebuilt, float(entry["score"])):
			return _fail("%s: reconstruction %s != recorded score %s" % [role, str(rebuilt), str(entry["score"])])
	return _pass()


# Test 5 — THE CAUSAL CLAIM. Builds a trace over a real arbiter turn, then removes
# the named contribution from the actor and re-runs the SAME arbiter: the winning
# action must change. FALSIFIABLE: a build() that named the largest term instead of
# the decisive one (the "grand character explanation for a tie-break" failure §6.6
# forbids) would name a contribution whose removal leaves the winner standing, and
# this test would fail.
static func _t_counterfactual_removal_flips_winner() -> Dictionary:
	# `faith` pushes actor.guard; without it the actor closes with the enemy instead.
	var actor: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {"faith": 100.0}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 1, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var cfg: Dictionary = {
		"vector_action_muls": {"actor.guard": {"faith": 1.0}},
	}
	var arbiter := BehaviorArbiter.new(cfg)
	var winner: Dictionary = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 1})
	var trace: Dictionary = DecisionTraceScript.build(
		winner.get("_decision_inputs", {}) as Dictionary, 0.9, _cfg()
	)
	var primary: Dictionary = trace["primary"] as Dictionary
	if str(primary["source"]) != "vector" or not bool(primary["material"]):
		return _fail("expected a material 'vector' primary for this fixture, got %s" % str(primary))
	if str(primary["causal_kind"]) != "co_decisive":
		return _fail("expected causal_kind 'co_decisive', got %s" % str(primary["causal_kind"]))

	# Remove exactly what the trace named — the virtue scores — and re-run.
	var stripped: Dictionary = actor.duplicate(true)
	stripped["vector_scores"] = {}
	var without: Dictionary = BehaviorArbiter.new(cfg).select_intent(
		{"actor": stripped, "all_actors": [enemy], "t": 1}
	)
	if str(without.get("action_type", "")) == str(winner.get("action_type", "")):
		return _fail(
			"the trace named 'vector' as decisive, but removing it left the winner unchanged (%s) — the primary reason is not causal"
			% str(winner.get("action_type", ""))
		)
	return _pass()


# Test 6 — a minor contribution is NOT promoted. Same shape as _decisive_inputs()
# but the virtue contribution is 5.0 against a margin of 20.0: it did not decide
# anything, so §6.6 requires the baseline tactical purpose instead. FALSIFIABLE: a
# build() that simply named the largest non-base term would report "vector" here.
static func _t_tie_breaker_is_not_promoted() -> Dictionary:
	var inputs: Dictionary = _decisive_inputs()
	((inputs["winner"] as Dictionary)["components"] as Dictionary)["vector_bonus"] = 5.0
	((inputs["winner"] as Dictionary)["components"] as Dictionary)["base"] = 65.0
	var trace: Dictionary = DecisionTraceScript.build(inputs, 0.9, _cfg())
	var primary: Dictionary = trace["primary"] as Dictionary
	if str(primary["causal_kind"]) != "baseline":
		return _fail("a 5-point nudge under a 20-point margin was promoted to %s" % str(primary))
	if str(primary["source"]) != "baseline" or bool(primary["material"]):
		return _fail("baseline primary must be source 'baseline' and material=false: %s" % str(primary))
	if str(primary["code"]) != "advance":
		return _fail("baseline primary should name the tactical purpose, got %s" % str(primary["code"]))
	if not (trace["supporting"] as Array).is_empty():
		return _fail("nothing was decisive, so nothing may be listed as supporting: %s" % str(trace["supporting"]))
	return _pass()


# Test 7 — a rule that selected the plan outranks every score term. FALSIFIABLE: a
# build() that scored its way to a primary regardless would report the score terms
# for a purifier whose action was never a scored choice at all.
static func _t_hard_override_wins_outright() -> Dictionary:
	var inputs: Dictionary = _decisive_inputs()
	inputs["hard_override"] = "purify_shrine_in_reach"
	var primary: Dictionary = DecisionTraceScript.build(inputs, 0.9, _cfg())["primary"] as Dictionary
	if str(primary["source"]) != "hard_rule" or str(primary["causal_kind"]) != "hard_override":
		return _fail("hard override not reported as such: %s" % str(primary))
	if str(primary["code"]) != "purify_shrine_in_reach":
		return _fail("hard override lost its code: %s" % str(primary))
	return _pass()


# Test 8 — legibility, and only legibility, decides how much the message says. It
# uses DivergenceDetector.specificity_band(), so there is one notion of specificity
# in the codebase. FALSIFIABLE: hardcoding a message key, or banding legibility a
# second time with different thresholds, breaks the three-way split below.
static func _t_legibility_governs_specificity() -> Dictionary:
	var inputs: Dictionary = _decisive_inputs()
	var vague: Dictionary = DecisionTraceScript.build(inputs, 0.1, _cfg())
	var named: Dictionary = DecisionTraceScript.build(inputs, 0.5, _cfg())
	var explicit: Dictionary = DecisionTraceScript.build(inputs, 0.9, _cfg())
	if str(vague["message_key"]) != "decision.reason.vague" \
			or str(named["message_key"]) != "decision.reason.named" \
			or str(explicit["message_key"]) != "decision.reason.explicit":
		return _fail("message keys did not track legibility: %s / %s / %s" % [
			str(vague["message_key"]), str(named["message_key"]), str(explicit["message_key"])])
	if (vague["message_args"] as Dictionary).has("source"):
		return _fail("a barely legible Echo must not attribute her reason: %s" % str(vague["message_args"]))
	if (named["message_args"] as Dictionary).has("subject_id"):
		return _fail("only the explicit band may name the subject: %s" % str(named["message_args"]))
	if not (explicit["message_args"] as Dictionary).has("subject_id"):
		return _fail("the explicit band must name the subject: %s" % str(explicit["message_args"]))
	# The decision itself is identical in all three — legibility explains, never decides.
	if vague["primary"] != named["primary"] or named["primary"] != explicit["primary"]:
		return _fail("legibility changed the reason, not just its specificity")
	return _pass()


# Test 9 — the phase's goal, end to end: a real arbiter turn produces a trace whose
# every field is populated and legal. FALSIFIABLE: an unwired seam (no
# _decision_inputs reaching the trace, or an empty purpose/tone) fails here rather
# than silently shipping a trace nobody can read.
static func _t_production_turn_is_explainable() -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var winner: Dictionary = BehaviorArbiter.new({}).select_intent(
		{"actor": actor, "all_actors": [enemy], "t": 1}
	)
	var trace: Dictionary = DecisionTraceScript.build(
		winner.get("_decision_inputs", {}) as Dictionary, 0.5, _cfg()
	)
	if str(trace["message_key"]).is_empty() or str(trace["voice_tone"]).is_empty():
		return _fail("trace is not readable: %s" % str(trace))
	if not DecisionTraceScript.SOURCES.has(str((trace["primary"] as Dictionary)["source"])):
		return _fail("illegal source on a production turn: %s" % str(trace["primary"]))
	if not DecisionTraceScript.STRENGTH_BANDS.has(str((trace["primary"] as Dictionary)["strength_band"])):
		return _fail("illegal strength_band on a production turn: %s" % str(trace["primary"]))
	for reason_value: Variant in (trace["supporting"] as Array):
		var reason: Dictionary = reason_value as Dictionary
		if str(reason["causal_kind"]) != "co_decisive" or not bool(reason["material"]):
			return _fail("a supporting reason must itself be material: %s" % str(reason))
	return _pass()


# Test 10 — the raw decomposition is consumed by ActorStateMachine and goes no
# further. FALSIFIABLE: dropping the erase() in advance_turn() would carry weights
# and trait values into combat resolution and into get_snapshot(), which is the
# other half of the §6.6 boundary.
static func _t_decision_inputs_never_leave_the_state_machine() -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.a", "name": "Ama", "faction": "echo", "actor_type": "echo",
		"calling_origin": "uncalled", "traits": {}, "vector_scores": {},
		"fear": 0, "morale": 50, "rank": 1, "grid_pos": {"col": 0, "row": 0},
		"stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var machine := ActorStateMachine.new(actor, BehaviorArbiter.new({}))
	var logger := StructuredLogger.new()
	# The trace line is debug severity — it is written every turn for every actor.
	logger.set_level(StructuredLogger.LEVEL_DEBUG)
	var intent: Dictionary = machine.advance_turn(
		{"actor": actor, "all_actors": [actor, enemy], "t": 1}, logger, 1
	)
	# The legacy select_intent() path returns the winning candidate itself as the
	# intent, so the arbiter's reporting keys ride on it unless advance_turn() removes
	# them — all three carry raw weights or per-term values.
	for internal: String in ["_decision_inputs", "_score_components", "_score_bias"]:
		if intent.has(internal):
			return _fail("scoring internals rode out of advance_turn() on the intent: %s" % internal)
		if (machine.get_snapshot()["last_intent"] as Dictionary).has(internal):
			return _fail("scoring internals reached get_snapshot(): %s" % internal)
	if machine.get_last_decision_trace().is_empty():
		return _fail("no trace was built for a real turn")
	var logged: bool = false
	for entry_value: Variant in logger.get_logs():
		if str((entry_value as Dictionary).get("type", "")) == "actor.decision_trace":
			logged = true
	if not logged:
		return _fail("no actor.decision_trace log line — the decision is not explainable from the log")
	return _pass()
