# res://tests/DivergenceDetectorTests.gd
# V2-PROG-012 Phase 4 — Echo/Directive divergence detection tests.
#
# Every test here is written to FAIL if the behaviour it pins were reverted —
# see the comment above each test for the specific regression it catches.

class_name DivergenceDetectorTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("divergence/determinism", Callable(DivergenceDetectorTests, "_t_determinism"))
	runner.register_test("divergence/whole_diverges_nascent_complies", Callable(DivergenceDetectorTests, "_t_whole_diverges_nascent_complies"))
	runner.register_test("divergence/kind_discriminates_judgment", Callable(DivergenceDetectorTests, "_t_kind_discriminates_judgment"))
	runner.register_test("divergence/no_score_change", Callable(DivergenceDetectorTests, "_t_no_score_change"))
	runner.register_test("divergence/composure_gates_threshold", Callable(DivergenceDetectorTests, "_t_composure_gates_threshold"))
	runner.register_test("divergence/algebraic_invariant", Callable(DivergenceDetectorTests, "_t_algebraic_invariant"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


# ─── Shared fixture: a "test_calling" Echo, adjacent to a full-health enemy, ──
# ─── plus a distant living ally (so "last echo standing" never fires and    ──
# ─── morale/last-stand logic stays out of the math). Base weights are       ──
# ─── chosen so melee_attack (72) narrowly loses to actor.idle (32) once a   ──
# ─── contradicting directive is weighted at Nascent (band_mul 1.30), but    ──
# ─── narrowly WINS once that same directive is weighted at Whole (0.75).    ──
# ─── See the derivation in the PR description / DivergenceDetector.gd —    ──
# ─── the numbers are hand-verified, not tuned by trial and error.          ──
static func _build_env(rank: int) -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = (bal.get("data", {}) as Dictionary).duplicate(true)
	var expr_cfg: Dictionary = (bdata.get("maturity_expression", {}) as Dictionary).duplicate(true)
	# Neutralise calling_behavior (production "uncalled" carries directive_mul: 1.5,
	# which would perturb the hand-derived numbers below) — "test_calling" isn't a
	# real calling id anyway, so it always falls back to calling_cfg.get("uncalled", {}).
	expr_cfg["calling_behavior"] = {}
	expr_cfg["divergence"] = {
		"divergence_min_margin": 1.0,
		"composure_noise_gate": 0.0,
		"composure_contradiction_gain": 0.0,
		"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67},
	}
	bdata["maturity_expression"] = expr_cfg

	var actor_cfg: Dictionary = {
		"intent_weights_by_calling_origin": {
			"test_calling": {"melee_attack": 72.0, "actor.idle": 32.0, "actor.guard": 5.0},
		},
		"default_intent_weight": 5.0,
		"directive_action_muls": {
			"actor.idle":   {"test_key": 1.0},
			"melee_attack": {"test_key": -1.0},
		},
		"directive_base_bonus": 20.0,
		"directive_band_mul": {"nascent": 1.30, "forming": 1.10, "grounded": 0.90, "whole": 0.75},
		# Neutralise board-state noise — this fixture puts the actor adjacent to an
		# enemy purely so melee_attack is a candidate at all; "echo_in_melee" and
		# friends must not skew the hand-derived numbers.
		"situational_muls": {},
	}

	var actor: Dictionary = {
		"id": "echo.div.test", "name": "Test Echo", "actor_type": "echo", "faction": "echo",
		"calling": "test_calling", "calling_origin": "test_calling", "rank": rank,
		"current_hp": 20, "stats": {"max_hp": 20},
		"morale": 50, "fear": 0, "fear_base": 0,
		"grid_pos": {"col": 0, "row": 0},
	}
	var enemy: Dictionary = {
		"id": "enemy.div.test", "name": "Test Enemy", "actor_type": "enemy", "faction": "enemy",
		"current_hp": 20, "stats": {"max_hp": 20}, "grid_pos": {"col": 1, "row": 0},
		"morale": 50, "fear": 0,
	}
	var ally: Dictionary = {
		"id": "echo.div.bystander", "name": "Bystander", "actor_type": "echo", "faction": "echo",
		"current_hp": 20, "stats": {"max_hp": 20}, "grid_pos": {"col": 9, "row": 9},
		"morale": 50, "fear": 0,
	}
	var directive: Dictionary = {
		"id": "directive.test_divergence",
		"intent_weights": {"test_key": 1.0},
	}
	var context: Dictionary = {
		"actor": actor,
		"all_actors": [actor, enemy, ally],
		"directive": directive,
		"cfg": {"data": bdata},
		"round": 1,
	}
	return {
		"context": context, "actor": actor, "actor_cfg": actor_cfg, "bdata": bdata,
	}


static func _run(rank: int) -> Array[Dictionary]:
	var env: Dictionary = _build_env(rank)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var asm := ActorStateMachine.new(env["actor"], null, env["actor_cfg"] as Dictionary, {})
	asm.advance_turn(env["context"] as Dictionary, logger, 1)
	var divergence_events: Array[Dictionary] = []
	for entry in logger.get_logs():
		if str(entry.get("type", "")) == "actor.divergence":
			divergence_events.append(entry)
	return divergence_events


# Test 1 — Determinism. FALSIFIABLE: if BehaviorArbiter's D-search, the extra
# _score() recompute for `components`, or DivergenceDetector.detect() depended
# on anything non-deterministic (dict iteration order for the primary_reason
# tie-break, float accumulation order, etc.), the two independent runs below
# would diverge on at least one field and this test would catch it.
static func _t_determinism() -> Dictionary:
	var run_a: Array[Dictionary] = _run(4)
	var run_b: Array[Dictionary] = _run(4)
	if run_a.size() != 1 or run_b.size() != 1:
		return _fail("expected exactly one actor.divergence per run, got %d and %d" % [run_a.size(), run_b.size()])
	if run_a[0] != run_b[0]:
		return _fail("two independent runs of the same encounter produced different actor.divergence payloads: %s vs %s" % [str(run_a[0]), str(run_b[0])])
	return _pass()


# Test 2 — Whole diverges where Nascent complies. FALSIFIABLE: if `directive_band_mul`
# stopped being applied to the directive term, or if the divergence threshold/gate
# were wired backwards, either (a) the Whole-band Echo would also comply (zero events),
# or (b) the Nascent-band Echo would also diverge (a spurious event), or (c) the kind
# would come out "judgment" instead of "interpretation" (proving the nascent-band
# counterfactual re-evaluation wasn't actually wired).
static func _t_whole_diverges_nascent_complies() -> Dictionary:
	var whole_events: Array[Dictionary] = _run(4)  # rank 4 → whole band
	if whole_events.size() != 1:
		return _fail("expected exactly one actor.divergence for the Whole-band Echo, got %d" % whole_events.size())
	var data: Dictionary = whole_events[0].get("data", {})
	if str(data.get("divergence_kind", "")) != "interpretation":
		return _fail("Whole-band divergence_kind should be 'interpretation' (she'd have complied at Nascent), got: %s" % str(data.get("divergence_kind", "")))
	if str(data.get("chosen_action", "")) != "melee_attack" or str(data.get("directive_action", "")) != "actor.idle":
		return _fail("unexpected chosen/directive actions: %s" % str(data))

	var nascent_events: Array[Dictionary] = _run(1)  # rank 1 → nascent band
	if nascent_events.size() != 0:
		return _fail("Nascent-band Echo in the same spot should comply (zero actor.divergence events), got %d: %s" % [nascent_events.size(), str(nascent_events)])
	return _pass()


# Test 3 — divergence_kind discriminates. Constructs a case where the Echo's own
# judgment would STILL beat the Directive even under the most literal (Nascent)
# weighting — "judgment", not "interpretation". FALSIFIABLE: a detector that always
# returns "interpretation" (or that ignores the nascent re-evaluation entirely) would
# pass test 2 but fail this one, proving the two kinds are actually distinguished by
# real different logic, not a hardcoded string.
static func _t_kind_discriminates_judgment() -> Dictionary:
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 100.0, "directive_bonus": -10.0, "directive_bonus_nascent": -20.0,
		"components": {},
	}
	var directive_preferred: Dictionary = {
		"action_type": "actor.idle", "target_id": "",
		"score": 50.0, "directive_bonus": 20.0, "directive_bonus_nascent": 30.0,
	}
	var cfg: Dictionary = {"divergence_min_margin": 6.0, "composure_noise_gate": 0.0, "composure_contradiction_gain": 0.0}
	var result: Dictionary = DivergenceDetector.detect(chosen, directive_preferred, 0.0, 0.5, cfg)
	if not bool(result.get("diverged", false)):
		return _fail("expected diverged=true for this case, got: %s" % str(result))
	if str(result.get("divergence_kind", "")) != "judgment":
		return _fail("expected divergence_kind='judgment' (identity outweighs Directive at any band), got: %s" % str(result))
	if str(result.get("divergence_kind", "")) == "interpretation":
		return _fail("divergence_kind must NOT be 'interpretation' for a judgment case")
	return _pass()


# Test 4 — Detection changes no score. Reruns the exact fixture from
# tests/MovementArbitrationTests.gd's production_golden (no directive, so
# directive_bonus is 0.0 everywhere and the probe carries no live tension) and
# pins BOTH the winning decision (action_type/target_id/priority/morale/archetype
# — the pre-Phase-4 shape) AND that `_divergence_probe.chosen.score` exactly
# equals an independently-computed _score() call for the same candidate.
# FALSIFIABLE: if select_intent()'s D-search or probe-building accidentally
# mutated a candidate's `_score`, added the probe computation into the returned
# score, or changed tie-break order, either half of this assertion breaks.
static func _t_no_score_change() -> Dictionary:
	var actor: Dictionary = {
		"id": "echo.a", "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var enemy: Dictionary = {
		"id": "enemy.a", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": {"col": 3, "row": 0}, "stats": {"max_hp": 100}, "current_hp": 100,
	}
	var arbiter := BehaviorArbiter.new({})
	var actual: Dictionary = arbiter.select_intent({"actor": actor, "all_actors": [enemy], "t": 1})

	if str(actual.get("action_type", "")) != "actor.move" or str(actual.get("target_id", "")) != "enemy.a" \
			or float(actual.get("priority", -1.0)) != 1.0:
		return _fail("pre-Phase-4 decision shape changed: %s" % str(actual))
	if str(actual.get("morale_tier", "")) != "steady" or int(actual.get("morale_modifier", -1)) != 0 \
			or str(actual.get("archetype_birth", "x")) != "" or int(actual.get("archetype_modifier", -1)) != 0:
		return _fail("pre-Phase-4 metadata changed: %s" % str(actual))

	var probe: Dictionary = actual.get("_divergence_probe", {})
	if probe.is_empty():
		return _fail("expected a _divergence_probe to be attached (score 44.0 < 9999.0 override threshold)")
	var probe_score: float = float((probe.get("chosen", {}) as Dictionary).get("score", -1.0))

	# Independently recompute the score for the exact same candidate/context this
	# winner represents, and confirm the probe's `score` is not a different number.
	var board_summary: Dictionary = arbiter._build_board_summary(actor, [enemy], {}, "nascent", "")
	var candidate: Dictionary = {
		"action_type": "actor.move", "target_id": "enemy.a", "target_pos": {"col": 3, "row": 0},
		"target_distance": 3, "target_hp_ratio": 1.0, "priority": 1.0,
	}
	var independent_score: float = arbiter._score("actor.move", actor, {}, board_summary, "nascent", {}, candidate, 0.1, 0.0, 0.4)
	if not is_equal_approx(probe_score, independent_score) or probe_score != independent_score:
		return _fail("probe score %s does not exactly match an independent _score() recompute %s" % [str(probe_score), str(independent_score)])
	return _pass()


# Test 5 — Composure gates the threshold. FALSIFIABLE: if composure_noise_gate
# were not applied (or applied with the wrong sign), the SAME overrule_strength
# would produce the same diverged verdict at both composure extremes; this test
# specifically picks an overrule_strength that sits strictly between the two
# resulting thresholds, so a no-op or backwards implementation fails it.
static func _t_composure_gates_threshold() -> Dictionary:
	var cfg: Dictionary = {"divergence_min_margin": 10.0, "composure_noise_gate": 1.0, "composure_contradiction_gain": 0.0}
	# overrule_strength = 15.0 (self_margin 25.0 - directive_pull 10.0):
	#   effective_min_margin(composure=0.0) = 10 * (1 + 1.0*0.0) = 10.0  → 15 >= 10 → diverged
	#   effective_min_margin(composure=1.0) = 10 * (1 + 1.0*1.0) = 20.0  → 15 <  20 → NOT diverged
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 115.0, "directive_bonus": 10.0, "directive_bonus_nascent": 10.0,
		"components": {},
	}
	var directive_preferred: Dictionary = {
		"action_type": "actor.idle", "target_id": "",
		"score": 100.0, "directive_bonus": 20.0, "directive_bonus_nascent": 20.0,
	}
	var low_composure: Dictionary = DivergenceDetector.detect(chosen, directive_preferred, 0.0, 0.5, cfg)
	var high_composure: Dictionary = DivergenceDetector.detect(chosen, directive_preferred, 1.0, 0.5, cfg)
	if not is_equal_approx(float(low_composure.get("overrule_strength", -1.0)), 15.0):
		return _fail("fixture drifted — expected overrule_strength 15.0, got %s" % str(low_composure.get("overrule_strength", -1.0)))
	if not bool(low_composure.get("diverged", false)):
		return _fail("expected diverged=true at composure=0.0 (threshold 10.0, overrule_strength 15.0): %s" % str(low_composure))
	if bool(high_composure.get("diverged", true)):
		return _fail("expected diverged=false at composure=1.0 (threshold 20.0, overrule_strength 15.0): %s" % str(high_composure))
	return _pass()


# Test 6 — The algebraic invariant: self_margin >= directive_pull >= 0 across a
# spread of candidates. FALSIFIABLE: this holds ONLY because `directive_preferred`
# is defined as the candidate maximizing directive_bonus (so directive_pull can
# never be negative) and `chosen` is defined as a genuine arbiter winner (so
# chosen.score >= directive_preferred.score, which algebraically forces
# self_margin >= directive_pull — see DivergenceDetector.gd's comment on this).
# A sign error or a swap of which candidate plays which role would violate this
# for at least one of the combinations below.
static func _t_algebraic_invariant() -> Dictionary:
	var cfg: Dictionary = {"divergence_min_margin": 6.0, "composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75}
	var chosen_scores: Array = [10.0, 50.0, 200.0]
	var directive_bonuses: Array = [-30.0, -5.0, 0.0, 5.0, 30.0]
	var score_gaps: Array = [0.0, 1.0, 25.0, 100.0]  # chosen.score - directive_preferred.score, always >= 0
	for chosen_score: float in chosen_scores:
		for w_dbonus: float in directive_bonuses:
			for d_dbonus: float in directive_bonuses:
				if d_dbonus < w_dbonus:
					continue  # directive_preferred must maximize directive_bonus by construction
				for gap: float in score_gaps:
					var chosen: Dictionary = {
						"action_type": "melee_attack", "target_id": "e1",
						"score": chosen_score, "directive_bonus": w_dbonus, "directive_bonus_nascent": w_dbonus,
						"components": {},
					}
					var directive_preferred: Dictionary = {
						"action_type": "actor.idle", "target_id": "",
						"score": chosen_score - gap, "directive_bonus": d_dbonus, "directive_bonus_nascent": d_dbonus,
					}
					var result: Dictionary = DivergenceDetector.detect(chosen, directive_preferred, 0.5, 0.5, cfg)
					var directive_pull: float = float(result.get("directive_pull", -1.0))
					var self_margin: float = float(result.get("self_margin", -1.0))
					if directive_pull < -0.0001:
						return _fail("directive_pull went negative: %s (case: score=%s w=%s d=%s gap=%s)" % [str(directive_pull), str(chosen_score), str(w_dbonus), str(d_dbonus), str(gap)])
					if self_margin < directive_pull - 0.0001:
						return _fail("self_margin < directive_pull: %s < %s (case: score=%s w=%s d=%s gap=%s)" % [str(self_margin), str(directive_pull), str(chosen_score), str(w_dbonus), str(d_dbonus), str(gap)])
	return _pass()
