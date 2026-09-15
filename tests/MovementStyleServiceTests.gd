# res://tests/MovementStyleServiceTests.gd
# V2-COMBAT-003.5 Phase 3b — MovementStyleService as a per-candidate alignment term:
# eligibility masking, the route-shape/style vocabularies, and the integrated
# BehaviorArbiter path where style is part of the score the winner-sort compares.

class_name MovementStyleServiceTests
extends RefCounted

const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const OptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const DecisionTraceScript = preload("res://core/actors/behaviors/DecisionTrace.gd")


## Captures the context ActorStateMachine actually hands the movement path, then
## defers to the real arbiter so the turn resolves normally (a rejected selection
## would register a legacy-selector use, which MovementFallbackGuardTests fails on).
class _CaptureArbiter extends BehaviorArbiter:
	var seen_context: Dictionary = {}

	func _init(actor_cfg: Dictionary = {}, movement_cfg: Dictionary = {}) -> void:
		super(actor_cfg, movement_cfg)

	func select_movement_intent(
		context: Dictionary,
		movement_context: Dictionary,
		profile: Dictionary,
		goals: Array,
		options: Array
	) -> Dictionary:
		seen_context = context
		return super(context, movement_context, profile, goals, options)


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement_style/eligibility_masking", _t_eligibility_masking)
	runner.register_test("movement_style/alignment_deterministic_and_weighted", _t_alignment_deterministic_and_weighted)
	runner.register_test("movement_style/vector_bias_scores_its_own_style", _t_vector_bias_scores_its_own_style)
	runner.register_test("movement_style/ineligible_style_is_penalised", _t_ineligible_style_is_penalised)
	runner.register_test("movement_style/route_style_round_trip", _t_route_style_round_trip)
	runner.register_test("movement_style/no_rng_no_config_service", _t_no_rng_no_config_service)
	runner.register_test("movement_style/arbiter_style_wins_by_score", _t_arbiter_style_wins_by_score)
	runner.register_test("movement_style/arbiter_no_identity_signal_no_preference", _t_arbiter_no_identity_signal_no_preference)
	runner.register_test("movement_style/calling_family_reaches_live_path", _t_calling_family_reaches_live_path)
	runner.register_test("movement_style/decisive_style_names_movement_style_in_trace", _t_decisive_style_names_movement_style_in_trace)
	runner.register_test("movement_style/ineligible_runner_up_does_not_inflate_margin", _t_ineligible_runner_up_does_not_inflate_margin)
	runner.register_test("movement_style/ineligible_winner_style_not_published_on_intent", _t_ineligible_winner_style_not_published_on_intent)


static func _t_eligibility_masking() -> Dictionary:
	for purpose: String in ["advance", "protect", "hold", "read", "carry"]:
		var eligible: Array = MovementStyleService.eligible_styles(purpose)
		if eligible.has("retreating"):
			return _fail("%s wrongly admitted retreating" % purpose)
		if eligible.has("overcommitted"):
			return _fail("%s wrongly admitted overcommitted" % purpose)
		if not eligible.has("intercepting"):
			return _fail("%s should admit intercepting" % purpose)
	for purpose: String in ["withdraw", "regroup", "escort", "reposition"]:
		if not MovementStyleService.eligible_styles(purpose).has("retreating"):
			return _fail("%s should admit retreating" % purpose)
	for purpose: String in ["engage", "intercept", "cut_off", "pursue"]:
		if not MovementStyleService.eligible_styles(purpose).has("overcommitted"):
			return _fail("%s should admit overcommitted" % purpose)
	if MovementStyleService.eligible_styles("withdraw").has("overcommitted"):
		return _fail("withdraw wrongly admitted overcommitted")
	if MovementStyleService.eligible_styles("engage").has("retreating"):
		return _fail("engage wrongly admitted retreating")
	return _pass()


static func _t_alignment_deterministic_and_weighted() -> Dictionary:
	var cfg: Dictionary = _cfg()
	var first: float = MovementStyleService.style_alignment_score(
		"forceful", "advance", {"vanguard": 40.0, "skeptic": 10.0}, "edge",
		{"courage": 30.0}, 20.0, "steady", 0.5, -0.3, cfg
	)
	var second: float = MovementStyleService.style_alignment_score(
		"forceful", "advance", {"vanguard": 40.0, "skeptic": 10.0}, "edge",
		{"courage": 30.0}, 20.0, "steady", 0.5, -0.3, cfg
	)
	if first != second:
		return _fail("Same inputs produced different scores: %f vs %f" % [first, second])
	if first == 0.0:
		return _fail("Fixture scored 0.0 — the weighting assertion below would be vacuous")

	var halved_cfg: Dictionary = cfg.duplicate(true)
	halved_cfg["alignment_weight"] = 0.5
	var halved: float = MovementStyleService.style_alignment_score(
		"forceful", "advance", {"vanguard": 40.0, "skeptic": 10.0}, "edge",
		{"courage": 30.0}, 20.0, "steady", 0.5, -0.3, halved_cfg
	)
	if not is_equal_approx(halved, first * 0.5):
		return _fail("alignment_weight did not scale the term: %f vs %f" % [halved, first * 0.5])
	return _pass()


## Each direction's strong bias must score its own style above the others it competes
## with, and route-shape `screen` must stay neutral (it has no style counterpart).
static func _t_vector_bias_scores_its_own_style() -> Dictionary:
	var cfg: Dictionary = _cfg()
	var cases: Array = [
		["vanguard", "forceful", "safe"],
		["protector", "intercept", "direct"],
		["seeker", "safe", "lateral"],
		["nurturer", "low_exposure", "direct"],
	]
	for case_v: Variant in cases:
		var case: Array = case_v as Array
		var strong: float = MovementStyleService.style_alignment_score(
			str(case[1]), "advance", {str(case[0]): 100.0}, "", {}, 0.0, "steady", 0.0, 0.0, cfg
		)
		var other: float = MovementStyleService.style_alignment_score(
			str(case[2]), "advance", {str(case[0]): 100.0}, "", {}, 0.0, "steady", 0.0, 0.0, cfg
		)
		if strong <= other:
			return _fail("%s did not favour route-shape %s (%f vs %f)" % [case[0], case[1], strong, other])
	var screen: float = MovementStyleService.style_alignment_score(
		"screen", "protect", {"vanguard": 100.0}, "edge", {}, 100.0, "inspired", 1.0, 1.0, cfg
	)
	if screen != 0.0:
		return _fail("route-shape screen must stay neutral, scored %f" % screen)
	return _pass()


## INELIGIBLE_ALIGNMENT is now 0.0 (decision #21, neutral not a veto — F1 fix), so a
## bare "score == INELIGIBLE_ALIGNMENT" check can no longer tell "gated" apart from
## "no identity signal". These fixtures use max fear, which `_cfg()`'s fear_weight
## gives a real nonzero pull for `overcommitted`/`retreating` — proving the gate
## still zeroes an ineligible style's score even though the signal that would have
## produced a nonzero score is present.
static func _t_ineligible_style_is_penalised() -> Dictionary:
	var cfg: Dictionary = _cfg()
	var banned: float = MovementStyleService.style_alignment_score(
		"overcommitted", "advance", {}, "", {}, 100.0, "steady", 0.0, 0.0, cfg
	)
	if banned != 0.0:
		return _fail("overcommitted on advance was not neutralised: %f" % banned)
	if not is_finite(banned):
		return _fail("The penalty must stay finite — BehaviorArbiter rejects a non-finite score")
	var allowed: float = MovementStyleService.style_alignment_score(
		"overcommitted", "engage", {}, "", {}, 100.0, "steady", 0.0, 0.0, cfg
	)
	if allowed == 0.0:
		return _fail("overcommitted on engage lost its fear signal — the eligibility gate is over-firing")
	var retreating: float = MovementStyleService.style_alignment_score(
		"retreating", "engage", {}, "", {}, 100.0, "steady", 0.0, 0.0, cfg
	)
	if retreating != 0.0:
		return _fail("retreating leaked into engage at maximum fear: %f" % retreating)
	return _pass()


static func _t_route_style_round_trip() -> Dictionary:
	for style_v: Variant in MovementStyleService.STYLES:
		var style: String = str(style_v)
		var route_style: String = MovementStyleService.route_style_for(style)
		if route_style.is_empty():
			return _fail("%s has no route-shape mapping" % style)
		if MovementStyleService.movement_style_for(route_style) != style:
			return _fail("%s did not survive the round trip via %s" % [style, route_style])
	if MovementStyleService.route_style_for("not_a_style") != "":
		return _fail("Unknown style did not degrade to empty route style")
	if MovementStyleService.movement_style_for("screen") != "":
		return _fail("screen must have no movement_style counterpart")
	# §9 spells this style with the -ing, which also keeps it distinct from
	# `intercept` the §9 PURPOSE.
	if MovementStyleService.STYLES.has("intercept"):
		return _fail("`intercept` is a purpose token, not a style token")
	return _pass()


## No RNG anywhere, and no ConfigService read: every weight arrives via `cfg`.
static func _t_no_rng_no_config_service() -> Dictionary:
	var source: String = FileAccess.get_file_as_string(
		"res://core/actors/behaviors/MovementStyleService.gd"
	)
	for line_v: Variant in source.split("\n"):
		var line: String = str(line_v)
		var code: String = line.get_slice("#", 0)
		if code.contains("CampaignSeed.") or code.contains("randf(") or code.contains("randi(") \
				or code.contains("randomize(") or code.contains("RandomNumberGenerator.new"):
			return _fail("MovementStyleService's CODE (not a comment) touches RNG: %s" % line)
		if code.contains("ConfigService."):
			return _fail("MovementStyleService's CODE reads ConfigService directly: %s" % line)
	return _pass()


## END TO END, INTEGRATED. Two mechanically distinct routes under the SAME goal. With
## no style config the ordinary sort takes the `direct` one; a vanguard vector bias
## must make the `forceful` one outscore it in the arbiter's OWN pass — so the winner
## is still simply candidates[0] and DecisionTrace's margin stays non-negative.
static func _t_arbiter_style_wins_by_score() -> Dictionary:
	var control: Dictionary = _select_two_route_fixture({}, {"vanguard": 1.0})
	if not bool(control["valid"]):
		return _fail("Control selection failed: %s" % str(control))
	var control_intent: Dictionary = control["intent"] as Dictionary
	if not str(control_intent["option_id"]).contains(".direct."):
		return _fail("Control did not take the direct route: %s" % str(control_intent["option_id"]))

	var styled: Dictionary = _select_two_route_fixture(
		{"vector_bias": {"vanguard": {"forceful": 100.0}}}, {"vanguard": 1.0}
	)
	if not bool(styled["valid"]):
		return _fail("Styled selection failed: %s" % str(styled))
	var intent: Dictionary = styled["intent"] as Dictionary
	if not str(intent["option_id"]).contains(".forceful."):
		return _fail("Style did not move the winner: %s" % str(intent["option_id"]))
	if str(intent.get("movement_style", "")) != "forceful":
		return _fail("movement_style was not read off the winner: %s" % str(intent.get("movement_style", "")))

	var decision: Dictionary = styled["_decision_inputs"] as Dictionary
	var winner: Dictionary = decision["winner"] as Dictionary
	var runner_up: Dictionary = decision["runner_up"] as Dictionary
	if not runner_up.is_empty() and float(winner["score"]) < float(runner_up["score"]):
		return _fail("Winner did not win its own sort: %f < %f" % [winner["score"], runner_up["score"]])
	if not (winner["bias"] as Dictionary).has("movement_style"):
		return _fail("The style term was not recorded on the winner: %s" % str(winner["bias"]))
	return _pass()


## An actor with NO identity signal — no vector_scores, no calling family, no traits,
## zero fear, steady morale, no bonds, no vow — must get exactly 0.0 on every
## candidate, so the ordinary tie-break decides and no route-shape is systematically
## preferred. This is the enemy case: enemies carry no vector_scores at all.
static func _t_arbiter_no_identity_signal_no_preference() -> Dictionary:
	var blank: Dictionary = _select_two_route_fixture({}, {}, "enemy")
	var full: Dictionary = _select_two_route_fixture(_cfg(), {}, "enemy")
	if not bool(blank["valid"]) or not bool(full["valid"]):
		return _fail("Fixture selection failed: %s / %s" % [str(blank), str(full)])
	var blank_id: String = str((blank["intent"] as Dictionary)["option_id"])
	var full_id: String = str((full["intent"] as Dictionary)["option_id"])
	if blank_id != full_id:
		return _fail("A no-identity actor's choice moved with the style table: %s vs %s" % [blank_id, full_id])
	var winner: Dictionary = (full["_decision_inputs"] as Dictionary)["winner"] as Dictionary
	if (winner["bias"] as Dictionary).has("movement_style"):
		return _fail("A no-identity actor still got a style term: %s" % str(winner["bias"]))
	return _pass()


## LIVE PATH. `calling_family` is resolved in ActorStateMachine for
## MaturityExpressionService; this proves the same value now also reaches the context
## the arbiter's movement path scores with, and that it moves the alignment score.
static func _t_calling_family_reaches_live_path() -> Dictionary:
	var actor: Dictionary = _actor("echo")
	actor["calling"] = "okofor"
	var enemy: Dictionary = _enemy()
	var goal: Dictionary = _goal()
	var context: Dictionary = {
		"actor": actor,
		"all_actors": [enemy],
		"t": 1,
		"cfg": {"data": {"calling": {"definitions": {"okofor": {"family": "anchor"}}}}},
		"movement_context": _movement_context(),
		"movement_profile": MovementProfile.build(4, [], true, "echo", {}),
		"movement_goals": [goal],
		"movement_options": _options(goal),
	}
	var module := _CaptureArbiter.new({}, {"spatial_utility": _spatial_cfg()})
	var sm := ActorStateMachine.new(actor, module)
	var logger := StructuredLogger.new()
	sm.advance_turn(context, logger, 1)
	if module.seen_context.is_empty():
		return _fail("The movement path was never reached")
	var seen_family: String = str(module.seen_context.get("calling_family", ""))
	if seen_family != "anchor":
		return _fail("calling_family did not reach the movement context: '%s'" % seen_family)

	var cfg: Dictionary = _cfg()
	var with_family: float = MovementStyleService.style_alignment_score(
		"cohesive", "advance", {}, seen_family, {}, 0.0, "steady", 0.0, 0.0, cfg
	)
	var without_family: float = MovementStyleService.style_alignment_score(
		"cohesive", "advance", {}, "", {}, 0.0, "steady", 0.0, 0.0, cfg
	)
	if with_family == without_family:
		return _fail("calling_family made no difference to the alignment score: %f" % with_family)
	return _pass()


## F2 (blocker fix follow-up). Same scenario as _t_arbiter_style_wins_by_score:
## style is the only thing that flips the winner from `direct` to `forceful`. The
## Echo's OWN decomposition must say so — DecisionTrace must not fall through to
## "baseline" just because `movement_style` has no §6.6 source entry.
static func _t_decisive_style_names_movement_style_in_trace() -> Dictionary:
	var styled: Dictionary = _select_two_route_fixture(
		{"vector_bias": {"vanguard": {"forceful": 100.0}}}, {"vanguard": 1.0}
	)
	if not bool(styled["valid"]):
		return _fail("Styled selection failed: %s" % str(styled))
	var inputs: Dictionary = styled["_decision_inputs"] as Dictionary
	var trace: Dictionary = DecisionTraceScript.build(
		inputs, 1.0, {"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67}}
	)
	var primary: Dictionary = trace["primary"] as Dictionary
	if str(primary["source"]) != "movement_style":
		return _fail("Style was decisive but the trace named '%s' instead of movement_style: %s" \
			% [str(primary["source"]), str(primary)])
	if str(primary["code"]) != "style_expression":
		return _fail("Unexpected code for the movement_style source: %s" % str(primary["code"]))
	var reason_text: String = GuidanceContribution._reason_text(
		"object", "literal", {"source": "movement_style", "code": "style_expression"}, {}
	)
	if reason_text != "She made the only right move":
		return _fail("style_expression reason text was '%s', not the bark line" % reason_text)
	return _pass()


## F3 (verifying the F1 fix resolves the margin-inflation side effect). When the
## runner-up's own route-shape is one the purpose cannot express, its alignment term
## used to be INELIGIBLE_ALIGNMENT = -1.0e6, which inflated the recorded margin to
## ~1,000,000 and silenced every causal reason (swing > margin could never pass).
## Now the sentinel is 0.0 (neutral), so the margin must stay a normal, small value.
static func _t_ineligible_runner_up_does_not_inflate_margin() -> Dictionary:
	var actor: Dictionary = _actor("echo")
	var goal: Dictionary = _goal()
	var arbiter := BehaviorArbiter.new(
		{"movement_style_weights": _cfg()},
		{"spatial_utility": _spatial_cfg()}
	)
	var result: Dictionary = arbiter.select_movement_intent(
		{"actor": actor, "all_actors": [_enemy()], "t": 1},
		_movement_context(),
		MovementProfile.build(4, [], true, "echo", {}),
		[goal],
		_options_direct_and_overcommitted(goal)
	)
	if not bool(result["valid"]):
		return _fail("Selection failed: %s" % str(result))
	var inputs: Dictionary = result["_decision_inputs"] as Dictionary
	var winner: Dictionary = inputs["winner"] as Dictionary
	var runner_up: Dictionary = inputs["runner_up"] as Dictionary
	if runner_up.is_empty():
		return _fail("Fixture only produced one candidate — nothing to measure a margin against")
	var margin: float = float(winner["score"]) - float(runner_up["score"])
	if margin > 1000.0:
		return _fail("Margin still looks inflated by an ineligible-style sentinel: %f" % margin)
	return _pass()


## The winner-sort has no style config at all here, so the win is purely mechanical
## (cost). Purpose `advance` cannot express `overcommitted` (§9) — the winning
## candidate's own route-shape is style-ineligible for its purpose, and the intent
## must not say a style the purpose cannot truthfully express (decision #23).
static func _t_ineligible_winner_style_not_published_on_intent() -> Dictionary:
	var actor: Dictionary = _actor("echo")
	var goal: Dictionary = _goal()
	var arbiter := BehaviorArbiter.new(
		{"movement_style_weights": {}},
		{"spatial_utility": _spatial_cfg()}
	)
	var result: Dictionary = arbiter.select_movement_intent(
		{"actor": actor, "all_actors": [_enemy()], "t": 1},
		_movement_context(),
		MovementProfile.build(4, [], true, "echo", {}),
		[goal],
		_options_overcommitted_wins_by_cost(goal)
	)
	if not bool(result["valid"]):
		return _fail("Selection failed: %s" % str(result))
	var intent: Dictionary = result["intent"] as Dictionary
	if not str(intent["option_id"]).contains(".overcommitted."):
		return _fail("Fixture did not make the ineligible-style route win: %s" % str(intent["option_id"]))
	if str(intent.get("movement_style", "")) == "overcommitted":
		return _fail("Ineligible style was published on the intent anyway: %s" % str(intent))
	return _pass()


# ---------------------------------------------------------------------------
# FIXTURES
# ---------------------------------------------------------------------------

## One goal, two mechanically distinct routes (`direct` and `forceful`), selected
## through the real arbiter. `style_cfg` is the movement_style_weights block.
static func _select_two_route_fixture(
	style_cfg: Dictionary, vector_scores: Dictionary, faction: String = "echo"
) -> Dictionary:
	var actor: Dictionary = _actor(faction)
	actor["vector_scores"] = vector_scores
	var goal: Dictionary = _goal()
	var arbiter := BehaviorArbiter.new(
		{"movement_style_weights": style_cfg},
		{"spatial_utility": _spatial_cfg()}
	)
	return arbiter.select_movement_intent(
		{"actor": actor, "all_actors": [_enemy()], "t": 1},
		_movement_context(faction),
		MovementProfile.build(4, [], true, faction, {}),
		[goal],
		_options(goal)
	)


static func _actor(faction: String) -> Dictionary:
	return {
		"id": "echo.a", "faction": faction, "actor_type": faction,
		"calling_origin": "uncalled", "traits": {}, "vector_scores": {},
		"fear": 0, "morale": 50, "current_hp": 100,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100},
	}


static func _enemy() -> Dictionary:
	return {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}


static func _goal() -> Dictionary:
	return GoalContract.build(
		"goal.combat.advance.baseline.c2r0", "advance", [{"col": 2, "row": 0}], 1.0, 0.0,
		["enemy.a"], ["mode.combat", "role.baseline"],
		ActionPlan.build("actor.move", "enemy.a"), ActionPlan.build("actor.idle")
	)


## The two routes differ mechanically (different paths), so BehaviorArbiter's
## duplicate-mechanics guard accepts both as genuine alternate route-shapes for the
## same goal — exactly what MovementOptionService.generate_options() would hand it.
static func _options(goal: Dictionary) -> Array:
	var direct_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.direct.d2r0.pc1r0-c2r0",
		"advance", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}],
		2, 2, 0, 4, 2, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	var forceful_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.forceful.d2r0.pc1r0-c1r1-c2r1-c2r0",
		"advance", {"col": 2, "row": 0},
		[{"col": 1, "row": 0}, {"col": 1, "row": 1}, {"col": 2, "row": 1}, {"col": 2, "row": 0}],
		4, 4, 0, 4, 4, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	return [direct_option, forceful_option]


## Same goal, `direct` against a mechanically distinct `overcommitted` route. Purpose
## `advance` cannot express `overcommitted` (§9) — for F3, the point is that this
## makes the runner-up style-ineligible without making it the winner.
static func _options_direct_and_overcommitted(goal: Dictionary) -> Array:
	var direct_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.direct.d2r0.pc1r0-c2r0",
		"advance", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}],
		2, 2, 0, 4, 2, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	var overcommitted_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.overcommitted.d2r0.pc0r1-c1r1-c2r1-c2r0",
		"advance", {"col": 2, "row": 0},
		[{"col": 0, "row": 1}, {"col": 1, "row": 1}, {"col": 2, "row": 1}, {"col": 2, "row": 0}],
		4, 4, 0, 4, 4, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	return [direct_option, overcommitted_option]


## Same two route-shapes as `_options_direct_and_overcommitted`, costs reversed so
## `overcommitted` wins on mechanical merit alone — proving the winner can be
## style-ineligible for its own purpose, not just the runner-up.
static func _options_overcommitted_wins_by_cost(goal: Dictionary) -> Array:
	var direct_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.direct.d2r0.pc1r0-c2r0",
		"advance", {"col": 2, "row": 0}, [{"col": 1, "row": 0}, {"col": 2, "row": 0}],
		4, 4, 0, 4, 4, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	var overcommitted_option: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c2r0",
		"option.combat.advance.baseline.c2r0.overcommitted.d2r0.pc0r1-c1r1-c2r1-c2r0",
		"advance", {"col": 2, "row": 0},
		[{"col": 0, "row": 1}, {"col": 1, "row": 1}, {"col": 2, "row": 1}, {"col": 2, "row": 0}],
		2, 2, 0, 4, 2, 0.0, 0.0, 0.0, [], {"known_count": 0, "known_ids": []}, 1.0,
		goal["planned_primary"], goal["declared_fallback"]
	)
	return [direct_option, overcommitted_option]


static func _movement_context(mover_kind: String = "echo") -> Dictionary:
	var walkable: Dictionary = {}
	var terrain: Dictionary = {}
	for col: int in range(4):
		for row: int in range(2):
			terrain["%d,%d" % [col, row]] = 1
			walkable["%d,%d" % [col, row]] = true
	return MovementContext.build(
		"echo.a", "activation.a", {"col": 0, "row": 0}, {"w": 4, "h": 2}, walkable, walkable,
		{"0,0": "echo.a", "3,0": "enemy.a"},
		[
			MovementPerceivedActorFact.build(
				"echo.a", {"col": 0, "row": 0}, mover_kind, false, false, false, false, false, true, 1.0
			),
			MovementPerceivedActorFact.build(
				"enemy.a", {"col": 3, "row": 0}, "enemy", false, false, false, false, false, true, 1.0
			),
		],
		{"enemy.a": "hostile"}, terrain, [], {}, []
	)


static func _spatial_cfg() -> Dictionary:
	return {
		"cap": 20.0, "urgency_weight": 4.0, "objective_progress_weight": 8.0,
		"cohesion_weight": 4.0, "exposure_weight": -6.0, "congestion_weight": -2.0,
		"commitment_weight": -2.0, "directive_objective_advance_weight": 4.0,
		"directive_avoid_overcommit_weight": 2.0, "directive_exposure_acceptance_weight": 2.0,
		"directive_ally_protection_weight": 2.0, "directive_threat_interception_weight": 2.0,
	}


static func _cfg() -> Dictionary:
	return {
		"alignment_weight": 1.0,
		"vector_bias": {
			"vanguard":   {"forceful": 2.0, "direct": 1.0},
			"protector":  {"intercepting": 2.0, "cohesive": 1.0},
			"seeker":     {"careful": 2.0, "lateral": 1.0},
			"strategist": {"restrained": 2.0, "direct": 1.0},
			"skeptic":    {"careful": 2.0, "low_exposure": 1.0},
			"pillar":     {"cohesive": 2.0, "restrained": 1.0},
			"devoted":    {"cohesive": 2.0, "low_exposure": 1.0},
			"opportunist":{"lateral": 2.0, "intercepting": 1.0},
			"mediator":   {"cohesive": 2.0, "restrained": 1.0},
			"nurturer":   {"low_exposure": 2.0, "cohesive": 1.0},
		},
		"calling_family_bias": {
			"anchor": {"cohesive": 1.0, "low_exposure": 1.0},
			"edge": {"forceful": 1.0, "direct": 1.0},
			"sight": {"lateral": 1.0, "careful": 1.0},
		},
		"fear_weight": {
			"direct": 0.0, "restrained": 0.1, "careful": 0.2, "forceful": -0.1, "cohesive": 0.1,
			"low_exposure": 0.2, "lateral": 0.1, "intercepting": -0.1, "retreating": 5.0,
			"overcommitted": -0.2,
		},
		"morale_bias": {
			"broken": {"careful": 1.0, "restrained": 1.0},
			"shaken": {"careful": 0.5, "restrained": 0.5},
			"steady": {},
			"inspired": {"forceful": 1.0, "direct": 1.0},
		},
		"bond_weight": {"intercepting": 1.0, "cohesive": 1.0},
		"vow_ward_weight": {"cohesive": 1.0, "low_exposure": 1.0},
		"vow_break_weight": {"forceful": 1.0, "direct": 1.0},
		"trait_nudge": {
			"courage": {"forceful": 0.01, "direct": 0.01},
			"faith": {"cohesive": 0.01, "restrained": 0.01},
			"wisdom": {"careful": 0.01, "low_exposure": 0.01},
		},
	}


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
