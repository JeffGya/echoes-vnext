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
	runner.register_test("leadership/ui_presentation_has_all_statuses", Callable(LeadershipEmotionTests, "_t_ui_presentation_has_all_statuses"))

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
	var runtime := FlowRuntime.new(StructuredLogger.new(), ConfigService.new(),
		"/tmp/echoes-vnext-tests/kill_momentum_slot.json")
	runtime._apply_kill_momentum(source, [source, near, far], _real_expr_cfg(), 1)
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
	}
