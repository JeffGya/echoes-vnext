extends RefCounted
class_name LeadershipEmotionTests

const REQUIRED_TRAITS: Array[String] = [
	"inspire_aura", "calm_fear", "rally_call", "kill_momentum",
	"fearless_example", "fear_read", "morale_forecast", "morale_anchor",
	"steady_presence", "calm_transmission", "block_contagion",
]

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("leadership/real_balance_defines_all_emotion_traits", Callable(LeadershipEmotionTests, "_t_real_balance_defines_all_emotion_traits"))
	runner.register_test("leadership/fear_auras_use_strongest_overlap", Callable(LeadershipEmotionTests, "_t_fear_auras_use_strongest_overlap"))
	runner.register_test("leadership/source_and_radius_excluded", Callable(LeadershipEmotionTests, "_t_source_and_radius_excluded"))
	runner.register_test("leadership/morale_anchor_and_forecast_expiry", Callable(LeadershipEmotionTests, "_t_morale_anchor_and_forecast_expiry"))
	runner.register_test("leadership/direct_turn_effects_and_once_flags", Callable(LeadershipEmotionTests, "_t_direct_turn_effects_and_once_flags"))
	runner.register_test("leadership/once_per_combat_false_reactivates", Callable(LeadershipEmotionTests, "_t_once_per_combat_false_reactivates"))
	runner.register_test("leadership/noop_and_passive_traits_do_not_activate", Callable(LeadershipEmotionTests, "_t_noop_and_passive_traits_do_not_activate"))
	runner.register_test("leadership/direct_recovery_stacks", Callable(LeadershipEmotionTests, "_t_direct_recovery_stacks"))
	runner.register_test("leadership/kill_momentum_radius_and_source_exclusion", Callable(LeadershipEmotionTests, "_t_kill_momentum_radius_and_source_exclusion"))
	runner.register_test("leadership/surprise_fear_uses_shared_path", Callable(LeadershipEmotionTests, "_t_surprise_fear_uses_shared_path"))
	runner.register_test("leadership/presence_grades_leadership_strength", Callable(LeadershipEmotionTests, "_t_presence_grades_leadership_strength"))
	runner.register_test("leadership/presence_grades_leadership_radius", Callable(LeadershipEmotionTests, "_t_presence_grades_leadership_radius"))
	runner.register_test("leadership/presence_does_not_grant_eligibility", Callable(LeadershipEmotionTests, "_t_presence_does_not_grant_eligibility"))
	runner.register_test("leadership/production_archetypes_grade_differently", Callable(LeadershipEmotionTests, "_t_production_archetypes_grade_differently"))
	runner.register_test("leadership/ui_presentation_has_all_statuses", Callable(LeadershipEmotionTests, "_t_ui_presentation_has_all_statuses"))
	# V2-INFRA-003 pass 8: the score/movement half of the same trait set.
	runner.register_test("leadership/every_trait_effect_is_authored", Callable(LeadershipEmotionTests, "_t_every_trait_effect_is_authored"))
	runner.register_test("leadership/score_traits_move_arbiter_scores", Callable(LeadershipEmotionTests, "_t_score_traits_move_arbiter_scores"))
	runner.register_test("leadership/score_auras_respect_radius_and_self", Callable(LeadershipEmotionTests, "_t_score_auras_respect_radius_and_self"))
	runner.register_test("leadership/threat_read_holds_the_retreat_gate", Callable(LeadershipEmotionTests, "_t_threat_read_holds_the_retreat_gate"))
	runner.register_test("leadership/cover_positioning_reads_broken_sight_line", Callable(LeadershipEmotionTests, "_t_cover_positioning_reads_broken_sight_line"))
	runner.register_test("leadership/displacement_immunity_owner_and_radius", Callable(LeadershipEmotionTests, "_t_displacement_immunity_owner_and_radius"))

static func _t_real_balance_defines_all_emotion_traits() -> Dictionary:
	var expr := _real_expr_cfg()
	var effects: Dictionary = expr.get("leadership_trait_effects", {})
	for trait_id in REQUIRED_TRAITS:
		if not effects.has(trait_id) or not (effects[trait_id] is Dictionary):
			return { "ok": false, "error": "balance.json missing leadership effect: %s" % trait_id }
	return { "ok": true }

static func _t_fear_auras_use_strongest_overlap() -> Dictionary:
	var expr := _real_expr_cfg()
	var target := _actor("target", 1, 0, 1, [])
	var fearless := _actor("fearless", 0, 0, 4, ["fearless_example"])
	var calm := _actor("calm", 2, 0, 4, ["calm_transmission"])
	var actors: Array = [target, fearless, calm]
	if LeadershipEmotionService.apply_fear_gain(target, 10, actors, expr, false) != 7:
		return { "ok": false, "error": "fearless_example must reduce 10 fear to 7" }
	if LeadershipEmotionService.apply_fear_gain(target, 10, actors, expr, true) != 3:
		return { "ok": false, "error": "strongest propagated reduction must win (10 -> 3), not multiply" }
	var blocker := _actor("blocker", 1, 1, 4, ["block_contagion"])
	actors.append(blocker)
	if LeadershipEmotionService.apply_fear_gain(target, 10, actors, expr, true) != 0:
		return { "ok": false, "error": "block_contagion must prevent propagated fear" }
	return { "ok": true }

static func _t_source_and_radius_excluded() -> Dictionary:
	var expr := _real_expr_cfg()
	var leader := _actor("leader", 0, 0, 4, ["fearless_example"])
	var far := _actor("far", 3, 0, 1, [])
	if LeadershipEmotionService.apply_fear_gain(leader, 10, [leader], expr) != 10:
		return { "ok": false, "error": "leader must not protect itself" }
	if LeadershipEmotionService.apply_fear_gain(far, 10, [leader, far], expr) != 10:
		return { "ok": false, "error": "fear aura leaked outside configured radius" }
	var dead := _actor("dead", 1, 0, 1, [])
	dead["is_dead"] = true
	if not LeadershipEmotionService.get_nearby_living_echo_allies(leader, [leader, dead], 2).is_empty():
		return { "ok": false, "error": "dead ally included in leadership targets" }
	return { "ok": true }

static func _t_morale_anchor_and_forecast_expiry() -> Dictionary:
	var expr := _real_expr_cfg()
	var target := _actor("target", 1, 0, 1, [])
	var anchor := _actor("anchor", 0, 0, 4, ["morale_anchor"])
	if LeadershipEmotionService.apply_morale_loss(target, 10, [target, anchor], expr, 1) != 5:
		return { "ok": false, "error": "morale_anchor must halve morale loss" }
	var forecast := _actor("forecast", 0, 1, 4, ["morale_forecast"])
	forecast["_morale_forecast_until_round"] = 3
	if LeadershipEmotionService.apply_morale_loss(target, 10, [target, anchor, forecast], expr, 3) != 0:
		return { "ok": false, "error": "morale_forecast must prevent loss through expiry round" }
	if LeadershipEmotionService.apply_morale_loss(target, 10, [target, anchor, forecast], expr, 4) != 5:
		return { "ok": false, "error": "expired forecast must fall back to strongest active reduction" }
	return { "ok": true }

static func _t_direct_turn_effects_and_once_flags() -> Dictionary:
	var balance := _real_balance()
	var cases: Array = [
		["inspire_aura", 3, 0], ["steady_presence", 2, 0],
		["calm_fear", 0, -15], ["fear_read", 0, -5],
	]
	for case_v in cases:
		var case: Array = case_v
		var leader := _actor("leader_%s" % case[0], 0, 0, 4, [str(case[0])])
		var ally := _actor("ally_%s" % case[0], 1, 0, 1, [])
		ally["morale"] = 40
		ally["fear"] = 30
		var before_morale := int(ally["morale"])
		var before_fear := int(ally["fear"])
		var sm := ActorStateMachine.new(leader)
		var logger := StructuredLogger.new()
		logger.set_level("off")
		sm.advance_turn({ "actor": leader, "all_actors": [leader, ally], "cfg": balance, "round": 2 }, logger, 1)
		if int(ally["morale"]) != before_morale + int(case[1]) or int(ally["fear"]) != before_fear + int(case[2]):
			return { "ok": false, "error": "%s did not apply configured direct effect" % case[0] }

	var rally := _actor("rally", 0, 0, 4, ["rally_call"])
	var rally_ally := _actor("rally_ally", 1, 0, 1, [])
	rally_ally["morale"] = 40
	var rally_sm := ActorStateMachine.new(rally)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var context := { "actor": rally, "all_actors": [rally, rally_ally], "cfg": balance, "round": 1 }
	rally_sm.advance_turn(context, logger, 1)
	rally_sm.advance_turn(context, logger, 2)
	if int(rally_ally["morale"]) != 50 or not rally.get("_rally_call_used", false):
		return { "ok": false, "error": "rally_call must add 10 exactly once per combat" }

	var forecast := _actor("forecast", 0, 0, 4, ["morale_forecast"])
	var forecast_ally := _actor("forecast_ally", 1, 0, 1, [])
	var forecast_sm := ActorStateMachine.new(forecast)
	forecast_sm.advance_turn({ "actor": forecast, "all_actors": [forecast, forecast_ally], "cfg": balance, "round": 4 }, logger, 1)
	if int(forecast.get("_morale_forecast_until_round", -1)) != 6 or not forecast.get("_morale_forecast_used", false):
		return { "ok": false, "error": "morale_forecast must activate once for three inclusive rounds" }
	return { "ok": true }

static func _t_direct_recovery_stacks() -> Dictionary:
	var balance := _real_balance()
	var leader_a := _actor("a", 0, 0, 4, ["inspire_aura"])
	var leader_b := _actor("b", 2, 0, 4, ["steady_presence"])
	var target := _actor("target", 1, 0, 1, [])
	target["morale"] = 40
	var logger := StructuredLogger.new()
	logger.set_level("off")
	ActorStateMachine.new(leader_a).advance_turn({ "actor": leader_a, "all_actors": [leader_a, leader_b, target], "cfg": balance }, logger, 1)
	ActorStateMachine.new(leader_b).advance_turn({ "actor": leader_b, "all_actors": [leader_a, leader_b, target], "cfg": balance }, logger, 2)
	if int(target["morale"]) != 45:
		return { "ok": false, "error": "direct recovery from separate leaders must stack (40 -> 45)" }
	return { "ok": true }

static func _t_once_per_combat_false_reactivates() -> Dictionary:
	var balance := _real_balance().duplicate(true)
	var effects: Dictionary = balance["data"]["maturity_expression"]["leadership_trait_effects"]
	(effects["rally_call"] as Dictionary)["once_per_combat"] = false
	(effects["morale_forecast"] as Dictionary)["once_per_combat"] = false
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var rally := _actor("repeat_rally", 0, 0, 4, ["rally_call"])
	var rally_ally := _actor("repeat_rally_ally", 1, 0, 1, [])
	rally_ally["morale"] = 40
	var rally_sm := ActorStateMachine.new(rally)
	var rally_context := { "actor": rally, "all_actors": [rally, rally_ally], "cfg": balance, "round": 1 }
	rally_sm.advance_turn(rally_context, logger, 1)
	rally_context["round"] = 2
	rally_sm.advance_turn(rally_context, logger, 2)
	if int(rally_ally["morale"]) != 60 or rally.has("_rally_call_used"):
		return { "ok": false, "error": "rally_call must reactivate without setting a used flag when once_per_combat is false" }

	var forecast := _actor("repeat_forecast", 0, 0, 4, ["morale_forecast"])
	var forecast_ally := _actor("repeat_forecast_ally", 1, 0, 1, [])
	var forecast_sm := ActorStateMachine.new(forecast)
	var forecast_context := { "actor": forecast, "all_actors": [forecast, forecast_ally], "cfg": balance, "round": 4 }
	forecast_sm.advance_turn(forecast_context, logger, 3)
	forecast_context["round"] = 5
	forecast_sm.advance_turn(forecast_context, logger, 4)
	if int(forecast.get("_morale_forecast_until_round", -1)) != 7 \
			or forecast.has("_morale_forecast_used"):
		return { "ok": false, "error": "morale_forecast must reactivate without setting a used flag when once_per_combat is false" }
	return { "ok": true }

static func _t_noop_and_passive_traits_do_not_activate() -> Dictionary:
	var balance := _real_balance().duplicate(true)
	var effects: Dictionary = balance["data"]["maturity_expression"]["leadership_trait_effects"]
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var noop_cases: Array = [["rally_call", "morale_boost"], ["morale_forecast", "morale_lock_rounds"]]
	for case_v in noop_cases:
		var case: Array = case_v
		var trait_id := str(case[0])
		(effects[trait_id] as Dictionary)[str(case[1])] = 0
		var leader := _actor("noop_%s" % trait_id, 0, 0, 4, [trait_id])
		var ally := _actor("noop_ally_%s" % trait_id, 1, 0, 1, [])
		var sm := ActorStateMachine.new(leader)
		sm.advance_turn({ "actor": leader, "all_actors": [leader, ally], "cfg": balance, "round": 1 }, logger, 1)
		if not str(sm.get_snapshot().get("active_leadership", "")).is_empty():
			return { "ok": false, "error": "%s reported a zero-value activation" % trait_id }
		if leader.has("_%s_used" % trait_id):
			return { "ok": false, "error": "%s set its once flag for a zero-value effect" % trait_id }

	var passive_traits: Array = [
		"kill_momentum", "fearless_example", "morale_anchor", "calm_transmission", "block_contagion",
	]
	for trait_id_v in passive_traits:
		var trait_id := str(trait_id_v)
		var leader := _actor("passive_%s" % trait_id, 0, 0, 4, [trait_id])
		var ally := _actor("passive_ally_%s" % trait_id, 1, 0, 1, [])
		var sm := ActorStateMachine.new(leader)
		sm.advance_turn({ "actor": leader, "all_actors": [leader, ally], "cfg": balance, "round": 1 }, logger, 1)
		if not str(sm.get_snapshot().get("active_leadership", "")).is_empty():
			return { "ok": false, "error": "%s falsely activated during the leader turn" % trait_id }

	var capped := _actor("capped_inspire", 0, 0, 4, ["inspire_aura"])
	var capped_ally := _actor("capped_ally", 1, 0, 1, [])
	capped_ally["morale"] = 100
	var capped_sm := ActorStateMachine.new(capped)
	capped_sm.advance_turn({ "actor": capped, "all_actors": [capped, capped_ally], "cfg": balance }, logger, 1)
	if not str(capped_sm.get_snapshot().get("active_leadership", "")).is_empty():
		return { "ok": false, "error": "capped morale tick falsely reported an applied turn effect" }
	return { "ok": true }

static func _t_kill_momentum_radius_and_source_exclusion() -> Dictionary:
	var source := _actor("source", 0, 0, 4, ["kill_momentum"])
	var near := _actor("near", 1, 0, 1, [])
	var far := _actor("far", 2, 0, 1, [])
	source["morale"] = 40
	near["morale"] = 40
	far["morale"] = 40
	# V2-INFRA-003 Phase 6 Slice 6H: _apply_kill_momentum moved off FlowRuntime onto
	# CombatTurnActionService together with its sole production caller (the melee kill branch).
	# No delegating shim was left behind (AGENTS.md #20), so this reaches the new owner directly.
	# The service needs only a logger, so no FlowRuntime and no save slot are constructed here.
	var kill_momentum := CombatTurnActionService.new(StructuredLogger.new())
	kill_momentum._apply_kill_momentum(source, [source, near, far], _real_expr_cfg(), 1)
	if int(source["morale"]) != 40:
		return { "ok": false, "error": "kill_momentum boosted its source" }
	if int(near["morale"]) != 48:
		return { "ok": false, "error": "kill_momentum did not boost nearby ally by real balance value" }
	if int(far["morale"]) != 40:
		return { "ok": false, "error": "kill_momentum leaked outside radius" }
	return { "ok": true }

static func _t_surprise_fear_uses_shared_path() -> Dictionary:
	var expr := _real_expr_cfg()
	var leader := _actor("leader", 0, 0, 4, ["fearless_example"])
	var ally := _actor("ally", 1, 0, 1, [])
	var surprise := int(_real_balance().get("data", {}).get("combat", {}).get("encounter_approach", {}).get("surprise_fear", 0))
	if surprise <= 0:
		return { "ok": false, "error": "real balance surprise fear must be positive" }
	var applied := LeadershipEmotionService.apply_fear_gain(ally, surprise, [leader, ally], expr)
	if applied != roundi(float(surprise) * 0.7):
		return { "ok": false, "error": "surprise fear did not use leadership-aware fear path" }
	return { "ok": true }

## V2-PROG-012 Phase 3, Item 4 #1: two Whole leaders with the same trait but different
## Presence must produce different fear mitigation on the same-amount target. Before this
## phase, is_whole_leader() was a binary gate — grading by Presence was impossible to
## construct at all. Leader/target are adjacent (distance 1) so radius grading (tested
## separately below) can never be the thing that changes the outcome here — only the
## trait_factor grading can. Falsifiable: reverting apply_fear_gain()'s presence-grading
## line collapses both leaders to factor 0.7 regardless of _presence, producing 14/14
## instead of 14/17, and this test fails on both the inequality check and the pinned values.
static func _t_presence_grades_leadership_strength() -> Dictionary:
	var expr := _real_expr_cfg()
	var canonical: float = float(expr.get("leadership_presence_scaling", {}).get("canonical_presence", 0.0))
	if canonical <= 0.0:
		return { "ok": false, "error": "real balance canonical_presence must be positive" }

	var full_leader := _actor("full_presence_leader", 0, 0, 4, ["fearless_example"])
	full_leader["_presence"] = canonical
	var target_a := _actor("target_a", 1, 0, 1, [])
	var applied_full := LeadershipEmotionService.apply_fear_gain(target_a, 20, [full_leader, target_a], expr, false)

	var weak_leader := _actor("half_presence_leader", 0, 0, 4, ["fearless_example"])
	weak_leader["_presence"] = canonical * 0.5
	var target_b := _actor("target_b", 1, 0, 1, [])
	var applied_weak := LeadershipEmotionService.apply_fear_gain(target_b, 20, [weak_leader, target_b], expr, false)

	if applied_full == applied_weak:
		return { "ok": false, "error": "leaders with different Presence must mitigate fear differently (both gave %d)" % applied_full }
	if applied_full != 14 or applied_weak != 17:
		return { "ok": false, "error": "graded leadership strength produced unexpected values (full=%d, half=%d), expected (14, 17)" % [applied_full, applied_weak] }
	return { "ok": true }

## V2-PROG-012 Phase 3, Item 4 #2: a lower-Presence leader's trait radius must be smaller
## than a canonical-Presence leader's, and must never collapse below the configured
## radius_floor_tiles even at zero Presence. Calls get_trait_radius() directly (not via
## apply_fear_gain) so the radius grading is isolated from the strength grading covered
## above. Falsifiable: reverting get_trait_radius()'s presence scaling makes all three
## leaders report the same base radius (3), failing the strict-monotonic check; removing
## the floor clamp makes the zero-Presence leader report 0 instead of the floor value.
static func _t_presence_grades_leadership_radius() -> Dictionary:
	var expr := _real_expr_cfg()
	var scaling_cfg: Dictionary = expr.get("leadership_presence_scaling", {})
	var canonical: float = float(scaling_cfg.get("canonical_presence", 0.0))
	var floor_tiles: int = int(scaling_cfg.get("radius_floor_tiles", 1))
	if canonical <= 0.0:
		return { "ok": false, "error": "real balance canonical_presence must be positive" }

	var full_leader := _actor("radius_full", 0, 0, 4, ["calm_transmission"])
	full_leader["_presence"] = canonical
	var full_radius := LeadershipEmotionService.get_trait_radius(full_leader, "calm_transmission", expr)

	var half_leader := _actor("radius_half", 0, 0, 4, ["calm_transmission"])
	half_leader["_presence"] = canonical * 0.5
	var half_radius := LeadershipEmotionService.get_trait_radius(half_leader, "calm_transmission", expr)

	var zero_leader := _actor("radius_zero", 0, 0, 4, ["calm_transmission"])
	zero_leader["_presence"] = 0.0
	var zero_radius := LeadershipEmotionService.get_trait_radius(zero_leader, "calm_transmission", expr)

	if not (zero_radius < half_radius and half_radius < full_radius):
		return { "ok": false, "error": "radius must shrink monotonically as Presence drops (zero=%d, half=%d, full=%d)" % [zero_radius, half_radius, full_radius] }
	if zero_radius != floor_tiles:
		return { "ok": false, "error": "zero-Presence leader radius must equal the configured floor of %d tiles, got %d" % [floor_tiles, zero_radius] }
	return { "ok": true }

## V2-PROG-012 Phase 3, Item 4 #3: pins the deliberate decision to keep is_whole_leader()'s
## band gate as ELIGIBILITY, separate from Presence grading. A Grounded (non-Whole) Echo
## with a high _presence must still fail to lead — Presence only grades an already-eligible
## Whole leader's strength/radius, it does not grant eligibility on its own. Falsifiable: if
## is_whole_leader() were changed to check Presence instead of (or in addition to) the
## expression band, this Grounded leader would start reducing fear and the full-amount
## (20) assertion below would fail.
static func _t_presence_does_not_grant_eligibility() -> Dictionary:
	var expr := _real_expr_cfg()
	var grounded_leader := _actor("grounded_high_presence", 0, 0, 3, ["fearless_example"])
	grounded_leader["_presence"] = 1.0
	var target := _actor("grounded_target", 1, 0, 1, [])
	var applied := LeadershipEmotionService.apply_fear_gain(target, 20, [grounded_leader, target], expr, false)
	if applied != 20:
		return { "ok": false, "error": "non-Whole leader with high Presence must not reduce fear at all (Whole-band eligibility gate must stay), got %d" % applied }
	return { "ok": true }

## Regression guard for a Phase 3 review finding: the first cut of presence grading
## calibrated canonical_presence against these test fixtures themselves (no
## archetype_birth -> archetype_projection 0.0), but archetype_projection carries the
## joint-largest weight (0.25) in the presence formula and every production Echo has an
## archetype. That made the fixture-derived canonical value sit at the bottom of the real
## production range, so clamp(presence/canonical, 0, 1) saturated at 1.0 for every real
## archetype — the grading was dormant in actual gameplay despite passing tests.
## reflective (0.25, weakest projection) and valiant (0.9, strongest) are the two ends of
## data.maturity_expression.autonomy_outputs.archetype_projection. Both leaders are built
## the way production Echoes are built — via MaturityExpressionService.derive_expression(),
## not a hand-set _presence — so this exercises the real seam end to end. Falsifiable: if
## the calibration saturates again (canonical too low relative to the real archetype
## spread, or the multiplier ceiling clamped back to 1.0), both leaders clamp to the same
## multiplier and applied_reflective == applied_valiant, failing this test.
static func _t_production_archetypes_grade_differently() -> Dictionary:
	var expr := _real_expr_cfg()
	var reflective_leader := _production_leader("reflective_leader", 4, ["fearless_example"], "reflective")
	var target_a := _actor("target_reflective", 1, 0, 1, [])
	var applied_reflective := LeadershipEmotionService.apply_fear_gain(
		target_a, 20, [reflective_leader, target_a], expr, false)

	var valiant_leader := _production_leader("valiant_leader", 4, ["fearless_example"], "valiant")
	var target_b := _actor("target_valiant", 1, 0, 1, [])
	var applied_valiant := LeadershipEmotionService.apply_fear_gain(
		target_b, 20, [valiant_leader, target_b], expr, false)

	if applied_reflective == applied_valiant:
		return { "ok": false, "error": "production leaders at opposite archetype extremes must mitigate fear differently (both gave %d) — presence grading is saturated/dormant" % applied_reflective }
	return { "ok": true }

static func _t_ui_presentation_has_all_statuses() -> Dictionary:
	var theme: Theme = load("res://assets/theme/LivingTreeSystem.tres")
	for status in EmotionPresentation.STATUSES:
		if EmotionPresentation.normalize(status) != status:
			return { "ok": false, "error": "EmotionPresentation rejected %s" % status }
		var text_theme := EmotionPresentation.text_theme(status)
		if not text_theme in theme.get_type_list():
			return { "ok": false, "error": "theme missing text variation %s" % text_theme }
		if EmotionPresentation.color(status).a <= 0.0:
			return { "ok": false, "error": "status %s has no visible color" % status }
	return { "ok": true }

static func _real_balance() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	return parsed if parsed is Dictionary else {}

static func _real_expr_cfg() -> Dictionary:
	return _real_balance().get("data", {}).get("maturity_expression", {})

static func _actor(id: String, col: int, row: int, rank: int, traits: Array) -> Dictionary:
	return {
		"id": id, "name": id, "actor_type": "echo", "faction": "echo",
		"rank": rank, "calling_origin": "okofor", "is_dead": false,
		"current_hp": 50, "stats": { "max_hp": 50, "atk": 5, "def": 5, "agi": 5, "int": 5, "cha": 5 },
		"grid_pos": { "col": col, "row": row }, "fear": 0, "morale": 50,
		"traits": { "courage": 50, "wisdom": 50, "faith": 50 }, "vector_scores": {},
		"leadership_traits": traits.duplicate(), "resilience_traits": [],
		"archetype_birth": "empathic",  # V2-PROG-012 Phase 3: real Echoes always have an
		# archetype (EchoActor.gd reads archetype_birth; PersonalityArchetype.from_traits()
		# always returns one of nine) — "" (no archetype) is not a production-representative
		# fixture shape. "empathic" (0.55) sits close to the mean of the nine
		# archetype_projection values (~0.567), used here as the shared fixture default so
		# every actor built by this helper represents a plausible production Echo.
	}


## Builds an actor at grid_pos (0,0) with a real, derived _presence — the way
## ActorStateMachine.advance_turn() computes it via MaturityExpressionService.
## derive_expression(), not hand-set. Used to exercise the actual production seam
## (as opposed to _actor()'s leaders in most tests above, whose _presence is simply
## absent because they're never run through derive_expression — see
## LeadershipEmotionService._presence_multiplier()'s doc comment for why that's a
## deliberate identity default rather than an oversight).
static func _production_leader(id: String, rank: int, traits: Array, archetype_birth: String) -> Dictionary:
	var actor := _actor(id, 0, 0, rank, traits)
	actor["archetype_birth"] = archetype_birth
	var bdata: Dictionary = _real_balance().get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var calling_defs: Dictionary = bdata.get("calling", {}).get("definitions", {})
	var family: String = str(calling_defs.get(str(actor.get("calling_origin", "")), {}).get("family", ""))
	var ctx_inputs: Dictionary = { "calling_family": family }
	var result := MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)
	actor["_presence"] = float(result.get("presence", 0.0))
	return actor


# ---------------------------------------------------------------------------
# V2-INFRA-003 pass 8 — leadership traits that modify decisions, not emotion.
# ---------------------------------------------------------------------------

## Every trait in the pool must carry a usable effect body. cover_positioning shipped
## as {} and anchor_presence carried only a radius; both were unreachable in play.
static func _t_every_trait_effect_is_authored() -> Dictionary:
	var expr := _real_expr_cfg()
	var effects: Dictionary = expr.get("leadership_trait_effects", {})
	var pool: Dictionary = expr.get("leadership_trait_pool", {})
	for calling_v: Variant in pool:
		if str(calling_v).begins_with("_"):
			continue
		for trait_v: Variant in (pool[calling_v] as Array):
			var trait_id := str(trait_v)
			var effect_v: Variant = effects.get(trait_id, null)
			if not (effect_v is Dictionary) or (effect_v as Dictionary).is_empty():
				return { "ok": false, "error": "leadership trait has no effect body: %s" % trait_id }
			# block_contagion is the one legitimate radius-only trait: its effect is a
			# total block, hardcoded in LeadershipEmotionService.apply_fear_gain(), so
			# there is no magnitude left to author.
			if trait_id == "block_contagion":
				continue
			var payload: Dictionary = effect_v
			var has_lever := false
			for key_v: Variant in payload:
				if str(key_v) != "radius":
					has_lever = true
			if not has_lever:
				return { "ok": false, "error": "leadership trait carries only a radius: %s" % trait_id }
	return { "ok": true }


## Each score trait must move the arbiter score of the action it names, by the
## amount balance.json authors, and must move nothing when no leader is in range.
static func _t_score_traits_move_arbiter_scores() -> Dictionary:
	var bdata: Dictionary = _real_balance().get("data", {})
	var expr: Dictionary = bdata.get("maturity_expression", {})
	var arbiter := BehaviorArbiter.new(bdata.get("actor", {}), bdata.get("combat", {}).get("movement", {}))
	var calling_behavior: Dictionary = expr.get("calling_behavior", {}).get("okofor", {})
	var directive: Dictionary = { "intent_weights": { "objective_advance_priority": 1.0 } }
	# trait, action, expected additive delta (directive traits are multiplicative and
	# are only required to raise the score — their size depends on the directive).
	var cases: Array = [
		["aggression_field", "melee_attack", 8.0],
		["mark_target",      "melee_attack", 10.0],
		["challenge_call",   "actor.taunt",  25.0],
		["safe_path_read",   "actor.move",   8.0],
		["hold_formation",   "actor.move",   -5.0],
		["directive_amplify", "melee_attack", 0.0],
		["directive_echo",    "melee_attack", 0.0],
	]
	for case_v: Variant in cases:
		var case: Array = case_v
		var trait_id := str(case[0])
		var action := str(case[1])
		var expected := float(case[2])
		var subject := _actor("subject_%s" % trait_id, 1, 0, 4, [])
		var leader := _actor("leader_%s" % trait_id, 0, 0, 4, [trait_id])
		var candidate: Dictionary = { "action_type": action, "target_id": "e1", "target_hp_ratio": 1.0 }
		var alone: Dictionary = arbiter.call("_leadership_score_mods", subject, [subject], expr)
		if not alone.is_empty():
			return { "ok": false, "error": "%s applied with no leader present" % trait_id }
		var led: Dictionary = arbiter.call("_leadership_score_mods", subject, [subject, leader], expr)
		if led.is_empty():
			return { "ok": false, "error": "%s produced no score modifier" % trait_id }
		var without: float = arbiter.call("_score", action, subject, directive, {}, "whole",
			calling_behavior, candidate, 0.1, 0.0, 0.4, 0.3, {}, alone)
		var with_leader: float = arbiter.call("_score", action, subject, directive, {}, "whole",
			calling_behavior, candidate, 0.1, 0.0, 0.4, 0.3, {}, led)
		var delta: float = with_leader - without
		if expected == 0.0:
			if delta <= 0.0:
				return { "ok": false, "error": "%s did not raise the directive term" % trait_id }
		elif absf(delta - expected) > 0.001:
			return { "ok": false, "error": "%s changed %s by %.3f, expected %.3f"
				% [trait_id, action, delta, expected] }
	return { "ok": true }


## Same membership rule as the fear and morale auras: the leader is never its own
## beneficiary, and the effect stops at the configured radius.
static func _t_score_auras_respect_radius_and_self() -> Dictionary:
	var bdata: Dictionary = _real_balance().get("data", {})
	var expr: Dictionary = bdata.get("maturity_expression", {})
	var arbiter := BehaviorArbiter.new(bdata.get("actor", {}), {})
	var leader := _actor("self_leader", 0, 0, 4, ["hold_formation"])  # authored radius 2
	var near := _actor("near", 2, 0, 4, [])
	var far := _actor("far", 5, 0, 4, [])
	if not (arbiter.call("_leadership_score_mods", leader, [leader, near], expr) as Dictionary).is_empty():
		return { "ok": false, "error": "leader applied its own score aura to itself" }
	if (arbiter.call("_leadership_score_mods", near, [leader, near], expr) as Dictionary).is_empty():
		return { "ok": false, "error": "score aura did not reach an ally inside the radius" }
	if not (arbiter.call("_leadership_score_mods", far, [leader, far], expr) as Dictionary).is_empty():
		return { "ok": false, "error": "score aura leaked outside the configured radius" }
	var nascent := _actor("nascent_leader", 0, 0, 1, ["hold_formation"])
	if not (arbiter.call("_leadership_score_mods", near, [nascent, near], expr) as Dictionary).is_empty():
		return { "ok": false, "error": "score aura fired below the Whole band" }
	return { "ok": true }


## threat_read lowers the HP at which actor.retreat is even offered, so an ally that
## would have had the option loses it while the leader is reading the threat for it.
static func _t_threat_read_holds_the_retreat_gate() -> Dictionary:
	var bdata: Dictionary = _real_balance().get("data", {})
	var expr: Dictionary = bdata.get("maturity_expression", {})
	var arbiter := BehaviorArbiter.new(bdata.get("actor", {}), {})
	var calling_behavior: Dictionary = expr.get("calling_behavior", {}).get("okofor", {})
	var subject := _actor("gate_subject", 1, 0, 4, [])
	subject["current_hp"] = 20  # hp_ratio 0.40; okofor retreat_threshold is 0.45
	var leader := _actor("gate_leader", 0, 0, 4, ["threat_read"])
	var enemy := _actor("gate_enemy", 5, 5, 1, [])
	enemy["actor_type"] = "enemy"
	enemy["faction"] = "enemy"
	var alone: Array = arbiter.call("_generate_candidates", subject, [subject, enemy],
		{}, "whole", calling_behavior, {})
	if not _has_action(alone, "actor.retreat"):
		return { "ok": false, "error": "retreat must be offered at 0.40 HP with no leader" }
	var mods: Dictionary = arbiter.call("_leadership_score_mods", subject, [subject, leader], expr)
	var led: Array = arbiter.call("_generate_candidates", subject, [subject, leader, enemy],
		{}, "whole", calling_behavior, mods)
	if _has_action(led, "actor.retreat"):
		return { "ok": false, "error": "threat_read did not lower the retreat gate" }
	return { "ok": true }


## cover_positioning grants a move bonus, and the cover test itself must distinguish a
## destination whose sight line to the nearest hostile is broken by terrain from one in the open.
static func _t_cover_positioning_reads_broken_sight_line() -> Dictionary:
	var bdata: Dictionary = _real_balance().get("data", {})
	var expr: Dictionary = bdata.get("maturity_expression", {})
	var arbiter := BehaviorArbiter.new(bdata.get("actor", {}), {})
	var subject := _actor("cover_subject", 1, 0, 4, [])
	var leader := _actor("cover_leader", 0, 0, 4, ["cover_positioning"])
	var alone: Dictionary = arbiter.call("_leadership_score_mods", subject, [subject], expr)
	var led: Dictionary = arbiter.call("_leadership_score_mods", subject, [subject, leader], expr)
	if float(alone.get("_cover_move_bonus", 0.0)) != 0.0:
		return { "ok": false, "error": "cover bonus applied with no leader present" }
	if float(led.get("_cover_move_bonus", 0.0)) <= 0.0:
		return { "ok": false, "error": "cover_positioning granted no move bonus" }
	var path: Array = [{ "col": 4, "row": 4 }]
	if bool(arbiter.call("_is_cover_destination", path, _cover_context(false))):
		return { "ok": false, "error": "open ground counted as cover" }
	if not bool(arbiter.call("_is_cover_destination", path, _cover_context(true))):
		return { "ok": false, "error": "terrain on the sight line did not count as cover" }
	return { "ok": true }


## position_lock protects only its owner; anchor_presence protects allies in radius.
## Immunity must reach the hazard resolver and stop the forced move.
static func _t_displacement_immunity_owner_and_radius() -> Dictionary:
	var expr := _real_expr_cfg()
	# flow_ctx is never touched by the immunity read, so a bare service is enough here.
	var live := LiveMovementContextService.new(null, null)
	var owner := _actor("lock_owner", 0, 0, 4, ["position_lock"])
	var plain := _actor("lock_plain", 0, 0, 4, [])
	if not bool(live.call("_movement_displacement_immunity", owner, [owner], expr)):
		return { "ok": false, "error": "position_lock did not protect its owner" }
	if bool(live.call("_movement_displacement_immunity", plain, [plain], expr)):
		return { "ok": false, "error": "an actor with no trait was reported immune" }
	var anchor := _actor("anchor_leader", 0, 0, 4, ["anchor_presence"])
	var near := _actor("anchor_near", 1, 0, 4, [])
	var far := _actor("anchor_far", 6, 0, 4, [])
	if not bool(live.call("_movement_displacement_immunity", near, [anchor, near], expr)):
		return { "ok": false, "error": "anchor_presence did not protect an ally in radius" }
	if bool(live.call("_movement_displacement_immunity", far, [anchor, far], expr)):
		return { "ok": false, "error": "anchor_presence leaked outside its radius" }
	if not bool((_unstable_entry(false) as Dictionary).get("displaced", false)):
		return { "ok": false, "error": "unstable hazard must displace a normal mover" }
	if bool((_unstable_entry(true) as Dictionary).get("displaced", false)):
		return { "ok": false, "error": "immunity did not stop the forced displacement" }
	return { "ok": true }


static func _has_action(candidates: Array, action_type: String) -> bool:
	for candidate_v: Variant in candidates:
		if str((candidate_v as Dictionary).get("action_type", "")) == action_type:
			return true
	return false


## A 10x10 board with a hostile due east of (4,4). `blocked` puts one non-walkable
## cell on the sight line between them.
static func _cover_context(blocked: bool) -> Dictionary:
	var walkable: Dictionary = _full_walkable()
	if blocked:
		walkable["5,4"] = false
	return {
		"authoritative_walkable": walkable,
		"bounds": { "w": 10, "h": 10 },
		"relationships": { "cover_enemy": "hostile" },
		"perceived_actors": [{
			"id": "cover_enemy", "position": { "col": 8, "row": 4 }, "kind": "enemy",
			"is_dead": false, "is_ko": false, "is_structure": false,
			"is_spirit": false, "is_quarry": false, "controlling_state": true,
			"health_ratio": 1.0,
		}],
	}


static func _unstable_entry(immune: bool) -> Dictionary:
	return MovementHazardService.resolve_cell_entry(
		{ "col": 3, "row": 3 },
		[{ "id": "hz1", "hazard_type": "unstable", "position": { "col": 3, "row": 3 } }],
		{
			"config": { "unstable": { "displacement_cells": 1, "fallback_damage": 3 } },
			"walkable": _full_walkable(),
			"bounds": { "w": 10, "h": 10 },
			"occupied": {},
			"mover_id": "mover",
			"phase": "movement",
			"seq": 0,
			"from_cell": { "col": 2, "row": 3 },
			"is_forced_entry": false,
			"immune_to_displacement": immune,
		},
		{ "triggered": { "unstable": false, "binding": false, "burning": false } }
	)


static func _full_walkable() -> Dictionary:
	var walkable: Dictionary = {}
	for col: int in range(10):
		for row: int in range(10):
			walkable["%d,%d" % [col, row]] = true
	return walkable
