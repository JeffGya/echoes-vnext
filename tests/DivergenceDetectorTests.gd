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
	runner.register_test("divergence/trivial_nudge_not_diverged", Callable(DivergenceDetectorTests, "_t_trivial_nudge_not_diverged"))
	runner.register_test("divergence/genuine_contest_small_margin_diverges", Callable(DivergenceDetectorTests, "_t_genuine_contest_small_margin_diverges"))
	runner.register_test("divergence/passive_directive_ignored_never_diverges", Callable(DivergenceDetectorTests, "_t_passive_directive_ignored_never_diverges"))
	runner.register_test("divergence/guard_not_ignored_can_diverge", Callable(DivergenceDetectorTests, "_t_guard_not_ignored_can_diverge"))
	runner.register_test("divergence/primary_reason_varies_with_legibility", Callable(DivergenceDetectorTests, "_t_primary_reason_varies_with_legibility"))
	runner.register_test("divergence/probe_gated_to_echo_faction", Callable(DivergenceDetectorTests, "_t_divergence_probe_gated_to_echo_faction"))
	runner.register_test("divergence/production_threshold_rejects_routine_noise", Callable(DivergenceDetectorTests, "_t_production_threshold_rejects_routine_noise"))
	runner.register_test("divergence/production_threshold_admits_meaningful_tail", Callable(DivergenceDetectorTests, "_t_production_threshold_admits_meaningful_tail"))
	# V2-PROG-012 Phase 6 Item 3(b) — data-driven, directive-agnostic coverage.
	# Enumerates data.directives at runtime (never a hardcoded directive list) so
	# a directive added later is automatically covered without editing this file.
	runner.register_test("divergence/every_registered_directive_never_crashes_and_stays_in_range", Callable(DivergenceDetectorTests, "_t_every_directive_never_crashes_and_stays_in_range"))
	runner.register_test("divergence/every_registered_directive_can_diverge_under_constructed_conflict", Callable(DivergenceDetectorTests, "_t_every_directive_can_diverge_under_constructed_conflict"))
	runner.register_test("divergence/every_registered_directive_agreement_never_diverges", Callable(DivergenceDetectorTests, "_t_every_directive_agreement_never_diverges"))


static func _pass() -> Dictionary: return {"ok": true}
static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}


# ─── Shared fixture: a "test_calling" Echo, adjacent to a full-health enemy, ──
# ─── plus a distant living ally (so "last echo standing" never fires and    ──
# ─── morale/last-stand logic stays out of the math). directive_action_muls  ──
# ─── gives actor.idle the ONLY entry with a directive_mul big enough to     ──
# ─── make it, not melee_attack or actor.guard, the raw top-bonus preference ──
# ─── at every band — exactly production's shape under directive.scout_carefully ──
# ─── (see the story brief). Part B's fall-through therefore always resolves ──
# ─── D to actor.guard, the next-ranked NON-ignored preference (constant     ──
# ─── zero bonus — no directive_action_muls entry for it — so its self_score ──
# ─── is interpretation_width-invariant, isolating directive_interpretation_mul's ──
# ─── effect to melee's OWN bonus term).
#
# V2-PROG-012 Phase 6 (DEFECT 2 fix): the directive multiplier is now driven by
# the continuous `judgment` output (via interpretation_width), NOT expression_band
# — so `rank` alone no longer swings it the way the old per-band table did.
# `judgment` is a weighted composite (rank_strength 0.25, storyweight_maturity 0.2,
# identity_coherence 0.2, calling_accent_confirmed 0.15, bond_support 0.15, minus
# fear_pressure 0.25) — rank_strength is only ONE of five positive inputs. To
# still produce a genuine, comfortably-separated comply/diverge contrast from a
# single `rank` argument, the "mature" fixture (rank >= 4) additionally sets
# `storyweight` (maxed against data.progression.level_thresholds' ceiling →
# storyweight_maturity=1.0) and one friend-tier bond to the living bystander ally
# (bond_scale.max_bonds overridden to 1 here so a single bond saturates
# bond_support=1.0) — both levers feed ONLY `judgment`, never `_score()` directly
# (unlike vector_scores, which would also move vector_bonus and confound the
# hand-derived numbers below — deliberately left unset on this actor for that
# reason). calling_accent_confirmed is already 1.0 at every rank (actor.calling
# is always set), so it contributes the same +0.15 in both cases and isn't a
# lever here.
#   rank 1 (nascent-like): rank_strength=0, storyweight_maturity=0, bond_support=0
#     → judgment = 0.15 → dir_mul = lerp(1.30, 0.75, 0.15) = 1.2175
#   rank 9 (whole, maxed maturity signals): rank_strength=1.0, storyweight_maturity=1.0,
#     bond_support=1.0 → judgment = 0.25+0.2+0.15+0.15 = 0.75 → dir_mul = lerp(1.30, 0.75, 0.75) = 0.8875
# At rank 1, actor.idle's own directive bonus (20*1.2175=24.35) is large enough
# that idle wins the turn outright (score 56.35 vs melee's 47.65) — she is MORE
# directive-aligned than the fallen-through D (actor.guard, constant zero bonus
# in this fixture), so directive_pull goes negative and she reads as compliant,
# not merely tied. At rank 9, idle's shrunken bonus (20*0.8875=17.75) can no
# longer carry it past melee_attack's bigger base weight (72 vs idle's 32): melee
# wins (54.25 vs 49.75), and melee's own (smaller-magnitude, shrunk) negative
# bonus is still below guard's zero, giving a positive, threshold-clearing
# contest_ratio (17.75 / 67.0 ≈ 0.265). The numbers are hand-verified (see
# _t_determinism's companion diagnostic run), not tuned by trial and error.
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
	# min_contest_ratio deliberately tiny (not the production PROPOSED DEFAULT of
	# 0.30) — this fixture is about pinning directive_interpretation_mul's effect on
	# the comply/diverge boundary, not about calibrating the production threshold
	# (that's balance.json's job — see its divergence._comment for the measured
	# justification).
	expr_cfg["divergence"] = {
		"min_contest_ratio": 0.1,
		"decision_scale_epsilon": 1.0,
		"divergence_ignored_directive_actions": ["actor.idle"],
		"composure_noise_gate": 0.0,
		"composure_contradiction_gain": 0.0,
		"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67},
	}
	# V2-PROG-012 Phase 6: max_bonds=1 so a single friend-tier bond saturates
	# bond_support to 1.0 — see the fixture comment above.
	var autonomy_outputs: Dictionary = (expr_cfg.get("autonomy_outputs", {}) as Dictionary).duplicate(true)
	autonomy_outputs["bond_scale"] = {"max_bonds": 1}
	expr_cfg["autonomy_outputs"] = autonomy_outputs
	bdata["maturity_expression"] = expr_cfg

	var actor_cfg: Dictionary = {
		"intent_weights_by_calling_origin": {
			"test_calling": {"melee_attack": 72.0, "actor.idle": 32.0, "actor.guard": 5.0},
		},
		"default_intent_weight": 5.0,
		# actor.guard intentionally has NO entry here (bonus 0.0 regardless of
		# interpretation_width) — see the fixture comment above for why that
		# isolates directive_interpretation_mul's effect.
		"directive_action_muls": {
			"actor.idle":   {"test_key": 1.0},
			"melee_attack": {"test_key": -1.0},
		},
		"directive_base_bonus": 20.0,
		"directive_interpretation_mul": {"low": 0.75, "high": 1.30},
		# Neutralise board-state noise — this fixture puts the actor adjacent to an
		# enemy purely so melee_attack is a candidate at all; "echo_in_melee" and
		# friends must not skew the hand-derived numbers.
		"situational_muls": {},
	}

	# V2-PROG-012 Phase 6: storyweight and a friend bond both feed ONLY `judgment`
	# (never `_score()` directly — see the fixture comment above), maxed at rank>=4
	# to produce a genuine judgment contrast against rank 1's all-zero maturity
	# signals. ceiling matches data.progression.level_thresholds' last entry (1000
	# in production) so storyweight_maturity saturates at 1.0.
	var actor: Dictionary = {
		"id": "echo.div.test", "name": "Test Echo", "actor_type": "echo", "faction": "echo",
		"calling": "test_calling", "calling_origin": "test_calling", "rank": rank,
		"storyweight": 1000 if rank >= 4 else 0,
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
	# V2-PROG-012 Phase 6: a friend-tier bond to the living bystander (rank>=4 only
	# — see the fixture comment above). Safe against score confounds: _apply_bond_bias()
	# only ever touches "protect_ally" candidates, and this fixture's bystander is
	# full-HP and far away (never a threatened protect_ally target), so no
	# protect_ally candidate is ever generated for it to act on.
	var context: Dictionary = {
		"actor": actor,
		"all_actors": [actor, enemy, ally],
		"directive": directive,
		"bonds": [{"actor_a": "echo.div.test", "actor_b": "echo.div.bystander", "strength": 60}] if rank >= 4 else [],
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
	var run_a: Array[Dictionary] = _run(9)
	var run_b: Array[Dictionary] = _run(9)
	if run_a.size() != 1 or run_b.size() != 1:
		return _fail("expected exactly one actor.divergence per run, got %d and %d" % [run_a.size(), run_b.size()])
	if run_a[0] != run_b[0]:
		return _fail("two independent runs of the same encounter produced different actor.divergence payloads: %s vs %s" % [str(run_a[0]), str(run_b[0])])
	return _pass()


# Test 2 — high-judgment diverges where low-judgment complies. FALSIFIABLE: if
# `directive_interpretation_mul` stopped being applied to the directive term (via
# interpretation_width), or if the contest_ratio threshold/gate were wired
# backwards, either (a) the rank-9/maxed-maturity Echo would also comply (zero
# events), or (b) the rank-1/zero-maturity Echo would also diverge (a spurious
# event) — proving judgment no longer moves the comply/diverge boundary at all.
#
# V2-PROG-012 Phase 6: this used to be "rank 4 (whole band) vs rank 1 (nascent
# band)" — DEFECT 2's whole point is that expression_band/rank alone no longer
# drives the directive term, so a bare rank swing isn't enough on its own
# (rank_strength is only one of five positive judgment inputs — see the fixture
# comment on _build_env above for why storyweight + a bond are also needed, and
# why rank 9 rather than 4 is used here for a comfortable margin instead of a
# borderline one).
#
# At rank 1 (judgment 0.15), actor.idle's own directive bonus is large enough
# that idle wins the turn outright (chosen_action == "actor.idle") — she is MORE
# directive-aligned than the fallen-through D (actor.guard, constant zero bonus
# in this fixture), so directive_pull goes negative and she reads as compliant,
# not merely tied. At rank 9 (judgment 0.75, maxed storyweight + bond), idle's
# shrunken bonus can no longer carry it past melee_attack's bigger base weight
# (72 vs 32) — melee_attack wins, and its own (smaller-magnitude, shrunk)
# negative bonus is still below guard's zero, giving a positive,
# threshold-clearing contest_ratio.
static func _t_whole_diverges_nascent_complies() -> Dictionary:
	var whole_events: Array[Dictionary] = _run(9)  # rank 9, maxed maturity signals → judgment 0.75
	if whole_events.size() != 1:
		return _fail("expected exactly one actor.divergence for the high-judgment Echo, got %d" % whole_events.size())
	var data: Dictionary = whole_events[0].get("data", {})
	if str(data.get("chosen_action", "")) != "melee_attack" or str(data.get("directive_action", "")) != "actor.guard":
		return _fail("unexpected chosen/directive actions: %s" % str(data))
	if float(data.get("contest_ratio", -1.0)) <= 0.0:
		return _fail("expected a positive contest_ratio for a genuine contest, got: %s" % str(data))

	var nascent_events: Array[Dictionary] = _run(1)  # rank 1, zero maturity signals → judgment 0.15
	if nascent_events.size() != 0:
		return _fail("low-judgment Echo in the same spot should comply (zero actor.divergence events — she out-weights the Directive's own fallback preference), got %d: %s" % [nascent_events.size(), str(nascent_events)])
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
	# action_type "actor.guard" (not "actor.idle") — this test targets divergence_kind
	# discrimination, not Part B's ignore-list; actor.guard is never ignored by default.
	var directive_preferred: Dictionary = {
		"action_type": "actor.guard", "target_id": "",
		"score": 50.0, "directive_bonus": 20.0, "directive_bonus_nascent": 30.0,
	}
	var cfg: Dictionary = {"min_contest_ratio": 0.2, "decision_scale_epsilon": 1.0, "composure_noise_gate": 0.0, "composure_contradiction_gain": 0.0}
	# decision_scale=100.0: directive_pull (30.0) / decision_scale (100.0) = contest_ratio 0.3,
	# comfortably clears min_contest_ratio 0.2.
	var result: Dictionary = DivergenceDetector.detect(chosen, [directive_preferred], 100.0, 0.5, 0.5, cfg)
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
	var cfg: Dictionary = {"min_contest_ratio": 0.25, "decision_scale_epsilon": 1.0, "composure_noise_gate": 1.0, "composure_contradiction_gain": 0.0}
	# Same fixture as the pre-fix version of this test (directive_pull 10.0,
	# self_margin 25.0, overrule_strength 15.0 — kept as a fixture-drift pin below),
	# now read through decision_scale=25.0: contest_ratio = 10.0 / 25.0 = 0.4.
	#   effective_min_contest_ratio(composure=0.0) = 0.25 * (1 + 1.0*0.0) = 0.25  → 0.4 >= 0.25 → diverged
	#   effective_min_contest_ratio(composure=1.0) = 0.25 * (1 + 1.0*1.0) = 0.50  → 0.4 <  0.50 → NOT diverged
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 115.0, "directive_bonus": 10.0, "directive_bonus_nascent": 10.0,
		"components": {},
	}
	# action_type "actor.guard" — this test targets composure gating, not Part B.
	var directive_preferred: Dictionary = {
		"action_type": "actor.guard", "target_id": "",
		"score": 100.0, "directive_bonus": 20.0, "directive_bonus_nascent": 20.0,
	}
	var decision_scale: float = 25.0
	var low_composure: Dictionary = DivergenceDetector.detect(chosen, [directive_preferred], decision_scale, 0.0, 0.5, cfg)
	var high_composure: Dictionary = DivergenceDetector.detect(chosen, [directive_preferred], decision_scale, 1.0, 0.5, cfg)
	if not is_equal_approx(float(low_composure.get("overrule_strength", -1.0)), 15.0):
		return _fail("fixture drifted — expected overrule_strength 15.0, got %s" % str(low_composure.get("overrule_strength", -1.0)))
	if not is_equal_approx(float(low_composure.get("contest_ratio", -1.0)), 0.4):
		return _fail("fixture drifted — expected contest_ratio 0.4, got %s" % str(low_composure.get("contest_ratio", -1.0)))
	if not bool(low_composure.get("diverged", false)):
		return _fail("expected diverged=true at composure=0.0 (threshold 0.25, contest_ratio 0.4): %s" % str(low_composure))
	if bool(high_composure.get("diverged", true)):
		return _fail("expected diverged=false at composure=1.0 (threshold 0.50, contest_ratio 0.4): %s" % str(high_composure))
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
	var cfg: Dictionary = {"min_contest_ratio": 0.35, "decision_scale_epsilon": 1.0, "composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75}
	# decision_scale fixed at a large constant, safely above decision_scale_epsilon for
	# every combination below — this test is about the directive_pull/self_margin
	# algebra, not contest_ratio gating, so decision_scale is held out of the sweep.
	var decision_scale: float = 1000.0
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
					# action_type "actor.guard" — this test targets the directive_pull/
					# self_margin algebra, not Part B's ignore-list.
					var directive_preferred: Dictionary = {
						"action_type": "actor.guard", "target_id": "",
						"score": chosen_score - gap, "directive_bonus": d_dbonus, "directive_bonus_nascent": d_dbonus,
					}
					var result: Dictionary = DivergenceDetector.detect(chosen, [directive_preferred], decision_scale, 0.5, 0.5, cfg)
					var directive_pull: float = float(result.get("directive_pull", -1.0))
					var self_margin: float = float(result.get("self_margin", -1.0))
					if directive_pull < -0.0001:
						return _fail("directive_pull went negative: %s (case: score=%s w=%s d=%s gap=%s)" % [str(directive_pull), str(chosen_score), str(w_dbonus), str(d_dbonus), str(gap)])
					if self_margin < directive_pull - 0.0001:
						return _fail("self_margin < directive_pull: %s < %s (case: score=%s w=%s d=%s gap=%s)" % [str(self_margin), str(directive_pull), str(chosen_score), str(w_dbonus), str(d_dbonus), str(gap)])
	return _pass()


# Test 7 — A trivial nudge does not register. This is the logged PRODUCTION case that
# motivated this fix: chosen_action "actor.move" vs directive_preferred "actor.idle",
# self_margin ~235, overrule_strength ~225, directive_pull 10.5. Under the pre-fix
# raw-margin rule this cleared any plausible threshold and fired almost every turn.
# Here directive_pull (10.5) is read against a decision_scale (235.45, matching the
# self_margin order of magnitude reported in production) — contest_ratio ≈ 0.045, a
# ~4% nudge — which sits far below the production PROPOSED DEFAULT min_contest_ratio
# (0.35), even after composure_noise_gate raises the bar further.
# FALSIFIABLE: a detector that reverted to gating on overrule_strength (≈225, comfortably
# above any plausible raw-margin threshold) would incorrectly fire here; this test would
# catch that regression immediately. The idle entry ranks first in directive_candidates
# (bonus 30.0 > guard's 15.5) to also confirm Part B's fall-through is exercised, not
# bypassed, on the way to this result.
static func _t_trivial_nudge_not_diverged() -> Dictionary:
	var chosen: Dictionary = {
		"action_type": "actor.move", "target_id": "e1",
		"score": 305.0, "directive_bonus": 5.0, "directive_bonus_nascent": 5.0,
		"components": {},
	}
	var directive_candidates: Array = [
		{"action_type": "actor.idle", "target_id": "", "score": 999.0, "directive_bonus": 30.0, "directive_bonus_nascent": 30.0},
		{"action_type": "actor.guard", "target_id": "", "score": 80.05, "directive_bonus": 15.5, "directive_bonus_nascent": 15.5},
	]
	var cfg: Dictionary = {
		"min_contest_ratio": 0.35, "decision_scale_epsilon": 1.0,
		"composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75,
		"divergence_ignored_directive_actions": ["actor.idle"],
	}
	# decision_scale 235.45 ≈ the production self_margin — "the options differed to her
	# by about this much overall".
	var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 235.45, 0.4, 0.5, cfg)
	if str(result.get("directive_action", "")) != "actor.guard":
		return _fail("expected fall-through past actor.idle to actor.guard, got directive_action=%s" % str(result.get("directive_action", "")))
	if float(result.get("overrule_strength", -1.0)) < 200.0:
		return _fail("fixture drifted — expected a large raw overrule_strength (~225), got %s" % str(result.get("overrule_strength", -1.0)))
	if float(result.get("contest_ratio", -1.0)) >= 0.1:
		return _fail("fixture drifted — expected contest_ratio well under 0.1 (a trivial nudge), got %s" % str(result.get("contest_ratio", -1.0)))
	if bool(result.get("diverged", true)):
		return _fail("expected diverged=false for a trivial nudge against a large decision_scale: %s" % str(result))
	return _pass()


# Test 8 — A genuine contest registers even with a SMALL raw margin — the inverse of
# the old behaviour. directive_pull (8.0) is large relative to a small decision_scale
# (10.0) — contest_ratio 0.8, decisively above the 0.35 threshold — while overrule_strength
# (0.5) is tiny, far below the old retired min_margin default (6.0).
# FALSIFIABLE: a detector still gating on overrule_strength (or on min_contest_ratio
# applied to the wrong numerator/denominator) would read this as noise and miss it;
# this test would catch that regression.
static func _t_genuine_contest_small_margin_diverges() -> Dictionary:
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 52.0, "directive_bonus": 2.0, "directive_bonus_nascent": 2.0,
		"components": {},
	}
	var directive_candidates: Array = [
		{"action_type": "actor.guard", "target_id": "", "score": 51.5, "directive_bonus": 10.0, "directive_bonus_nascent": 10.0},
	]
	var cfg: Dictionary = {
		"min_contest_ratio": 0.35, "decision_scale_epsilon": 1.0,
		"composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75,
		"divergence_ignored_directive_actions": ["actor.idle"],
	}
	var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 10.0, 0.0, 0.5, cfg)
	if not is_equal_approx(float(result.get("overrule_strength", -1.0)), 0.5):
		return _fail("fixture drifted — expected overrule_strength 0.5, got %s" % str(result.get("overrule_strength", -1.0)))
	if not is_equal_approx(float(result.get("contest_ratio", -1.0)), 0.8):
		return _fail("fixture drifted — expected contest_ratio 0.8, got %s" % str(result.get("contest_ratio", -1.0)))
	if not bool(result.get("diverged", false)):
		return _fail("expected diverged=true for a genuine contest despite a tiny raw margin (0.5): %s" % str(result))
	return _pass()


# Test 9 — Part B: a passive directive preference (actor.idle) is never diverged
# against, regardless of margins — even when idle is the ONLY entry in
# directive_candidates (so there is nothing left to fall through to). Uses the exact
# numbers from Test 8 (which DO clear the threshold when the same candidate is typed
# "actor.guard") to prove the ignore-list is doing the work, not a coincidence of the
# numbers.
# FALSIFIABLE: if the ignore-list were not applied (or applied to the wrong field),
# this scenario — contest_ratio 0.8, decisively above threshold — would incorrectly
# register as diverged.
static func _t_passive_directive_ignored_never_diverges() -> Dictionary:
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 52.0, "directive_bonus": 2.0, "directive_bonus_nascent": 2.0,
		"components": {},
	}
	var directive_candidates: Array = [
		{"action_type": "actor.idle", "target_id": "", "score": 51.5, "directive_bonus": 10.0, "directive_bonus_nascent": 10.0},
	]
	var cfg: Dictionary = {
		"min_contest_ratio": 0.35, "decision_scale_epsilon": 1.0,
		"composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75,
		"divergence_ignored_directive_actions": ["actor.idle"],
	}
	var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 10.0, 0.0, 0.5, cfg)
	if str(result.get("directive_action", "")) != "":
		return _fail("expected no resolvable directive preference (idle-only, ignored), got directive_action=%s" % str(result.get("directive_action", "")))
	if bool(result.get("diverged", true)):
		return _fail("expected diverged=false when the only directive preference is the ignored actor.idle: %s" % str(result))
	return _pass()


# Test 10 — Part B: actor.guard is NOT on the default ignore list — pins the
# deliberate design decision that a guard order IS something an Echo can meaningfully
# defy (unlike actor.idle). Same shape as Test 9, but the single candidate is typed
# "actor.guard" instead of "actor.idle" — and now it registers.
# FALSIFIABLE: if a future change widened divergence_ignored_directive_actions to
# include actor.guard (or the ignore-check were applied unconditionally), this test
# would start failing — it is the tripwire for that regression.
static func _t_guard_not_ignored_can_diverge() -> Dictionary:
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1",
		"score": 52.0, "directive_bonus": 2.0, "directive_bonus_nascent": 2.0,
		"components": {},
	}
	var directive_candidates: Array = [
		{"action_type": "actor.guard", "target_id": "", "score": 51.5, "directive_bonus": 10.0, "directive_bonus_nascent": 10.0},
	]
	var cfg: Dictionary = {
		"min_contest_ratio": 0.35, "decision_scale_epsilon": 1.0,
		"composure_noise_gate": 0.5, "composure_contradiction_gain": 0.75,
		"divergence_ignored_directive_actions": ["actor.idle"],
	}
	var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 10.0, 0.0, 0.5, cfg)
	if str(result.get("directive_action", "")) != "actor.guard":
		return _fail("expected actor.guard to resolve as the directive preference, got: %s" % str(result.get("directive_action", "")))
	if not bool(result.get("diverged", false)):
		return _fail("expected diverged=true — actor.guard must NOT be treated as a passive/ignored preference: %s" % str(result))
	return _pass()


# Test 11 — V2-PROG-012 Phase 5 Item 3: legibility_specificity_bands genuinely
# gates primary_reason's specificity, not just the diverged boolean. Story brief:
# a live run produced primary_reason "her own values" (the NAMED tier) and asked
# whether the config that maps legibility onto specificity is actually applied,
# or a dead key that gates nothing. Same `chosen`/`directive_candidates`/
# `decision_scale`/`composure`/`divergence_cfg` at three legibility samples
# (0.1, 0.5, 0.9) straddling vague_max=0.34 / named_max=0.67 — only `legibility`
# varies between the three detect() calls.
# FALSIFIABLE: if _primary_reason() stopped reading `legibility` (e.g. collapsed
# to always returning the named label, or always the vague fallback), at least
# two of the three results below would collide and this test would fail. It also
# pins the actual band strings so a boundary-off-by-one regression is caught.
static func _t_primary_reason_varies_with_legibility() -> Dictionary:
	# vector_bonus (40.0) dominates every other term — "her own values" is the
	# unambiguous expected NAMED-tier label.
	var components: Dictionary = {
		"base": 5.0, "trait_bonus": 2.0, "vector_bonus": 40.0, "archetype_bonus": 1.0,
		"morale_bonus": 0.0, "directive_bonus": 2.0, "situational_bonus": 0.0,
		"fear_factor": 1.0, "calling_mul": 1.0,
	}
	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "e1", "score": 45.0,
		"directive_bonus": 2.0, "directive_bonus_nascent": 2.0, "components": components,
	}
	var directive_candidates: Array = [
		{"action_type": "actor.guard", "target_id": "", "score": 40.0,
			"directive_bonus": 15.0, "directive_bonus_nascent": 15.0},
	]
	var cfg: Dictionary = {
		"min_contest_ratio": 0.1, "decision_scale_epsilon": 1.0,
		"composure_noise_gate": 0.0, "composure_contradiction_gain": 0.0,
		"divergence_ignored_directive_actions": ["actor.idle"],
		"legibility_specificity_bands": {"vague_max": 0.34, "named_max": 0.67},
	}
	# decision_scale=20.0, directive_pull=15-2=13 → contest_ratio=0.65 >= 0.1:
	# diverged=true at every legibility sample (legibility must not affect the
	# diverged boolean — only composure gates that; see detect()'s comment).
	var vague: Dictionary   = DivergenceDetector.detect(chosen, directive_candidates, 20.0, 0.0, 0.1, cfg)
	var named: Dictionary   = DivergenceDetector.detect(chosen, directive_candidates, 20.0, 0.0, 0.5, cfg)
	var outweighed: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 20.0, 0.0, 0.9, cfg)

	for r in [vague, named, outweighed]:
		if not bool(r.get("diverged", false)):
			return _fail("expected diverged=true at every legibility sample (legibility must not gate the diverged boolean): %s" % str(r))

	var reason_vague: String      = str(vague.get("primary_reason", ""))
	var reason_named: String      = str(named.get("primary_reason", ""))
	var reason_outweighed: String = str(outweighed.get("primary_reason", ""))

	if reason_vague != "her own judgment":
		return _fail("expected vague-band (legibility=0.1) primary_reason 'her own judgment', got '%s'" % reason_vague)
	if reason_named != "her own values":
		return _fail("expected named-band (legibility=0.5) primary_reason 'her own values', got '%s'" % reason_named)
	if reason_outweighed != "her own values outweighed the Directive":
		return _fail("expected outweighed-band (legibility=0.9) primary_reason 'her own values outweighed the Directive', got '%s'" % reason_outweighed)
	if reason_vague == reason_named or reason_named == reason_outweighed or reason_vague == reason_outweighed:
		return _fail("legibility bands collapsed to identical primary_reason text: %s / %s / %s" % [reason_vague, reason_named, reason_outweighed])
	return _pass()


# Test 12 — V2-PROG-012 Phase 5 fix: BehaviorArbiter never attaches
# _divergence_probe for a non-echo-faction actor, regardless of scores.
# Deliberately does NOT reuse _build_env/_run's "test_calling" fixture —
# _generate_candidates() resolves melee targets by OPPOSING faction (not
# actor_type), so simply relabeling the acting actor "enemy" there would also
# silently break which fixture entity is even a valid attack target,
# confounding "no probe because gated" with "no probe because no candidate" —
# exactly the kind of false-negative test the story brief has called out
# before. Instead this builds two minimal, symmetric BehaviorArbiterTests.gd-
# style contexts (actor adjacent to ONE opposing-faction target — the only
# thing that differs between them is the actor/target faction pair), so both
# cases score an identical, ordinary (non-9999-override) intent and the ONLY
# variable exercised is the gate itself.
# FALSIFIABLE: before the faction == "echo" gate landed in
# BehaviorArbiter.select_intent(), _divergence_probe was attached whenever the
# winner wasn't a 9999.0 hard override, with no faction check at all — the
# enemy_intent assertion below would then fail (captured failure, pre-fix:
# enemy_probe non-empty, e.g. {"chosen": {"action_type": "melee_attack", ...},
# "directive_candidates": [...], "decision_scale": ...} — see the story
# writeup for the exact dict).
static func _t_divergence_probe_gated_to_echo_faction() -> Dictionary:
	var directive: Dictionary = {"id": "directive.test", "intent_weights": {}}
	var arbiter := BehaviorArbiter.new({})

	var echo_actor: Dictionary = {
		"id": "actor.a", "faction": "echo", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0},
	}
	var echo_target: Dictionary = {
		"id": "target.b", "faction": "enemy", "current_hp": 20,
		"stats": {"max_hp": 20}, "grid_pos": {"col": 1, "row": 0},
	}
	var echo_context: Dictionary = {
		"actor": echo_actor, "all_actors": [echo_actor, echo_target],
		"directive": directive, "t": 1,
	}
	var echo_intent: Dictionary = arbiter.select_intent(echo_context)
	var echo_probe: Dictionary = echo_intent.get("_divergence_probe", {}) as Dictionary
	if echo_probe.is_empty():
		return _fail("control fixture broken: expected a populated _divergence_probe for a faction='echo' actor, got empty. intent=%s" % str(echo_intent))

	var enemy_actor: Dictionary = {
		"id": "actor.a", "faction": "enemy", "calling_origin": "uncalled",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50,
		"grid_pos": {"col": 0, "row": 0},
	}
	var enemy_target: Dictionary = {
		"id": "target.b", "faction": "echo", "current_hp": 20,
		"stats": {"max_hp": 20}, "grid_pos": {"col": 1, "row": 0},
	}
	var enemy_context: Dictionary = {
		"actor": enemy_actor, "all_actors": [enemy_actor, enemy_target],
		"directive": directive, "t": 1,
	}
	var enemy_intent: Dictionary = arbiter.select_intent(enemy_context)
	var enemy_probe: Dictionary = enemy_intent.get("_divergence_probe", {}) as Dictionary
	if not enemy_probe.is_empty():
		return _fail("expected NO _divergence_probe for a faction='enemy' actor, got: %s" % str(enemy_probe))

	return _pass()


# ─── Guard tests: pin balance.json's SHIPPED min_contest_ratio (not a hand-set ──
# ─── test override) above the routine-noise cluster measured for the V2-PROG-012 ──
# ─── Phase 6 Item 2 recalibration (0.30 -> 0.28 — Phase 6's directive_interpretation_mul
# ─── change moved directive_bonus, and therefore contest_ratio's numerator, so the
# ─── Phase 5 fix calibration was re-measured and re-fit; see balance.json's
# ─── divergence._comment for the full re-measurement writeup). Both tests read
# ─── data.maturity_expression.divergence straight off ConfigService.get_balance() —
# ─── the REAL production config — so a future tuning pass that silently drops
# ─── min_contest_ratio back toward the noise cluster (or pushes it past the
# ─── measured tail) fails one of these, not just a hand-tuned fixture that would
# ─── happily "pass" no matter what the shipped value is.
#
# Both fixtures hold decision_scale=100.0 and composure=0.0 fixed (composure=0.0
# makes effective_min_contest_ratio == min_contest_ratio exactly — see
# DivergenceDetector.detect()'s noise_gate multiplier — so contest_ratio is
# compared directly against the shipped threshold, with no composure inflation
# to account for), and vary only directive_pull (== D below, since
# w_directive_bonus is 0.0) so contest_ratio = D / 100.0 lands exactly on the
# bucket being pinned. Both buckets remain valid under the Phase 6 re-measured
# distribution too (min=0.0526, p25=0.0598, median=0.0987, p75=0.2069,
# p90=0.2959, max=0.3845 — see balance.json's divergence._comment):
#   - 0.08 sits inside the dense noise cluster (near p25/median) — routine
#     tactical disagreement, not a meaningful contest. Must NOT diverge.
#   - 0.34 sits inside the sparse tail (between p90=0.2959 and max=0.3845) — a
#     genuine directive-driven reversal. Must diverge (0.34 >= the shipped 0.28
#     default; if a future pass drops min_contest_ratio below 0.08 the FIRST
#     test below fails; if it raises min_contest_ratio above 0.34 the SECOND
#     test fails — both directions are falsifiable).
static func _t_production_threshold_rejects_routine_noise() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var divergence_cfg: Dictionary = (bal.get("data", {}) as Dictionary) \
		.get("maturity_expression", {}).get("divergence", {})

	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "t", "score": 50.0,
		"directive_bonus": 0.0, "directive_bonus_nascent": 0.0, "components": {},
	}
	var directive_preferred: Dictionary = {
		"action_type": "actor.guard", "target_id": "", "score": 42.0, "directive_bonus": 8.0,
	}
	var result: Dictionary = DivergenceDetector.detect(
		chosen, [directive_preferred], 100.0, 0.0, 0.0, divergence_cfg
	)
	if absf(float(result.get("contest_ratio", -1.0)) - 0.08) > 0.0001:
		return _fail("fixture broken: expected contest_ratio 0.08, got %s" % str(result.get("contest_ratio")))
	if bool(result.get("diverged", false)):
		return _fail("a contest_ratio of 0.08 (measured dense noise cluster, 0.05-0.10) diverged at the shipped min_contest_ratio=%s — threshold has fallen back into routine noise" % str(divergence_cfg.get("min_contest_ratio")))
	return _pass()


static func _t_production_threshold_admits_meaningful_tail() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var divergence_cfg: Dictionary = (bal.get("data", {}) as Dictionary) \
		.get("maturity_expression", {}).get("divergence", {})

	var chosen: Dictionary = {
		"action_type": "melee_attack", "target_id": "t", "score": 50.0,
		"directive_bonus": 0.0, "directive_bonus_nascent": 0.0, "components": {},
	}
	var directive_preferred: Dictionary = {
		"action_type": "actor.guard", "target_id": "", "score": 16.0, "directive_bonus": 34.0,
	}
	var result: Dictionary = DivergenceDetector.detect(
		chosen, [directive_preferred], 100.0, 0.0, 0.0, divergence_cfg
	)
	if absf(float(result.get("contest_ratio", -1.0)) - 0.34) > 0.0001:
		return _fail("fixture broken: expected contest_ratio 0.34, got %s" % str(result.get("contest_ratio")))
	if not bool(result.get("diverged", false)):
		return _fail("a contest_ratio of 0.34 (measured sparse tail, 0.30-0.3747) did NOT diverge at the shipped min_contest_ratio=%s — threshold has drifted above the measured meaningful tail, back toward a dormant seam" % str(divergence_cfg.get("min_contest_ratio")))
	return _pass()


# ═══════════════════════════════════════════════════════════════════════════
# V2-PROG-012 Phase 6 Item 3 — directive-agnostic coverage, data-driven.
#
# The designer's requirement, verbatim: "Make sure that the divergence is
# covered under all directives. More will be added later on. And the game
# should not break due to those being added."
#
# DivergenceDetector.gd itself never branches on a directive id (grep confirms
# every "scout_carefully"/"seek_signs" string in that file lives in a comment,
# never in executable code — see its header and _resolve_directive_preferred()'s
# doc comment) and never assumes a particular action is preferred, a particular
# number of intent_weights keys, or that weights sum to 1.0 — detect() only
# ever reads `directive_bonus` fields already computed by BehaviorArbiter and
# a directive-shaped `directive_candidates` ranking. The three tests below are
# the executable proof of that: they enumerate data.directives AT RUNTIME via
# DirectiveService.get_registry() (config-loaded — never a hardcoded id list),
# so a directive story adds later is automatically covered without touching
# this file. Real directive_bonus values are computed through the REAL
# BehaviorArbiter._directive_bonus() pipeline (production directive_action_muls
# table), so these tests exercise the actual translation logic for whatever
# semantic keys a future directive happens to use — not a hand-picked fixture.
# ═══════════════════════════════════════════════════════════════════════════

## Returns {action_type: directive_bonus} for every action_type present in
## data.actor.directive_action_muls, computed via the REAL _directive_bonus()
## pipeline for `directive` at interpretation_width=0.0 (most literal — the
## directive's strongest possible pull for each action, floor of the lerp).
static func _directive_bonus_by_action(directive: Dictionary, actor_cfg: Dictionary) -> Dictionary:
	var arbiter := BehaviorArbiter.new(actor_cfg)
	var dir_muls_v: Variant = actor_cfg.get("directive_action_muls", {})
	var dir_muls_table: Dictionary = dir_muls_v if dir_muls_v is Dictionary else {}
	var result: Dictionary = {}
	for atype_v in dir_muls_table:
		var atype: String = str(atype_v)
		result[atype] = arbiter._directive_bonus(atype, directive, 0.0, {})
	return result


## Shared setup: the REAL production directive registry (config-loaded, via the
## same DirectiveService.get_registry() path production code uses), the REAL
## data.actor block (directive_action_muls table), and the REAL shipped
## data.maturity_expression.divergence config. Returns {} if config failed to
## load (callers must treat that as a hard failure, not "zero directives").
static func _load_production_directive_fixtures() -> Dictionary:
	var cs := ConfigService.new()
	if not cs.load_balance():
		return {}
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var actor_cfg: Dictionary = bdata.get("actor", {})
	var divergence_cfg: Dictionary = (bdata.get("maturity_expression", {}) as Dictionary).get("divergence", {})

	var dir_svc := DirectiveService.new({})
	dir_svc.load_from_config(bal)
	var registry: Dictionary = dir_svc.get_registry()

	return {"registry": registry, "actor_cfg": actor_cfg, "divergence_cfg": divergence_cfg}


# Test — (a) no-crash / bounds check. For EVERY directive in the runtime
# registry, build a directive_candidates ranking from REAL computed
# directive_bonus values and run detect() across a spread of decision_scale /
# composure combinations (including the degenerate decision_scale=0.0 case).
# FALSIFIABLE: any directive whose intent_weights shape trips a divide-by-zero,
# a NaN propagation, or a contest_ratio/severity value outside [0,1] (contest_ratio)
# would fail this test the moment that directive's data ships — not months later
# when a real playtest happens to hit the case.
static func _t_every_directive_never_crashes_and_stays_in_range() -> Dictionary:
	var fx: Dictionary = _load_production_directive_fixtures()
	if fx.is_empty():
		return _fail("could not load production balance.json")
	var registry: Dictionary = fx["registry"]
	if registry.is_empty():
		return _fail("directive registry is empty — nothing to enumerate (config or DirectiveService broken)")
	var actor_cfg: Dictionary = fx["actor_cfg"]
	var divergence_cfg: Dictionary = fx["divergence_cfg"]

	for did_v in registry:
		var did: String = str(did_v)
		var directive: Dictionary = registry[did_v]
		var bonuses: Dictionary = _directive_bonus_by_action(directive, actor_cfg)
		if bonuses.is_empty():
			return _fail("[%s] data.actor.directive_action_muls is empty — cannot exercise any action_type" % did)

		var ranked: Array = bonuses.keys()
		ranked.sort_custom(func(a, b): return float(bonuses[a]) > float(bonuses[b]))

		var directive_candidates: Array = []
		for atype in ranked:
			directive_candidates.append({
				"action_type": str(atype), "target_id": "",
				"score": 50.0 + float(bonuses[atype]), "directive_bonus": float(bonuses[atype]),
				"directive_bonus_nascent": float(bonuses[atype]),
			})
		var chosen: Dictionary = {
			"action_type": str(ranked[0]), "target_id": "e1",
			"score": 50.0 + float(bonuses[ranked[0]]), "directive_bonus": float(bonuses[ranked[0]]),
			"directive_bonus_nascent": float(bonuses[ranked[0]]), "components": {},
		}

		for decision_scale_case: float in [0.0, 0.5, 1.0, 50.0, 1000.0]:
			for composure_case: float in [0.0, 0.5, 1.0]:
				var result: Dictionary = DivergenceDetector.detect(
					chosen, directive_candidates, decision_scale_case, composure_case, 0.5, divergence_cfg
				)
				var cr: float = float(result.get("contest_ratio", -1.0))
				if is_nan(cr) or not is_finite(cr):
					return _fail("[%s] contest_ratio is NaN/non-finite at decision_scale=%s composure=%s: %s" % [did, str(decision_scale_case), str(composure_case), str(cr)])
				if cr < 0.0 or cr > 1.0:
					return _fail("[%s] contest_ratio %s out of [0.0, 1.0] at decision_scale=%s composure=%s" % [did, str(cr), str(decision_scale_case), str(composure_case)])
				var sev: float = float(result.get("severity", 0.0))
				if is_nan(sev) or not is_finite(sev):
					return _fail("[%s] severity is NaN/non-finite at decision_scale=%s composure=%s: %s" % [did, str(decision_scale_case), str(composure_case), str(sev)])
	return _pass()


# Test — (b) a strong constructed identity conflict CAN fire, for every
# directive. Does not assert a specific rate (per the story brief) — only that
# the detector is CAPABLE of registering a genuine contest for whatever
# directive shows up, using that directive's own REAL computed directive_bonus
# spread (not a hand-tuned fixture number). Picks D = the highest-bonus,
# non-ignored action_type (mirrors _resolve_directive_preferred's fall-through)
# and W = the lowest-bonus action_type, then hand-sets decision_scale so
# contest_ratio lands at 0.9 (comfortably above any plausible min_contest_ratio)
# — this is "construct the conflict", exactly as the story brief asks, not a
# measurement of how often it happens naturally.
#
# If a directive's own bonus spread is flat/inverted (D never out-bonuses any
# alternative — directive_pull_raw <= 0) or the achievable pull sits below
# decision_scale_epsilon (too small a spread to ever be a "meaningful contest"
# by the detector's own noise guard), that directive is SKIPPED with a printed
# note rather than failed — this is a real, documented structural finding
# (see the story report), not a test bug. Every directive currently shipped
# (scout_carefully, seek_signs) clears this comfortably — real directive_pull
# ≈18.2 for both, verified via a throwaway measurement probe — so a silent
# empty run here is itself suspicious; the test asserts at least one directive
# was actually exercised.
static func _t_every_directive_can_diverge_under_constructed_conflict() -> Dictionary:
	var fx: Dictionary = _load_production_directive_fixtures()
	if fx.is_empty():
		return _fail("could not load production balance.json")
	var registry: Dictionary = fx["registry"]
	if registry.is_empty():
		return _fail("directive registry is empty — nothing to enumerate")
	var actor_cfg: Dictionary = fx["actor_cfg"]
	var divergence_cfg: Dictionary = fx["divergence_cfg"]
	var ignored_actions: Array = divergence_cfg.get("divergence_ignored_directive_actions", ["actor.idle"])
	var epsilon: float = float(divergence_cfg.get("decision_scale_epsilon", 1.0))

	var exercised := 0
	for did_v in registry:
		var did: String = str(did_v)
		var directive: Dictionary = registry[did_v]
		var bonuses: Dictionary = _directive_bonus_by_action(directive, actor_cfg)
		if bonuses.size() < 2:
			continue  # nothing to contrast against

		var ranked: Array = bonuses.keys()
		ranked.sort_custom(func(a, b): return float(bonuses[a]) > float(bonuses[b]))

		var d_action: String = ""
		var d_bonus: float = 0.0
		for atype in ranked:
			if not ignored_actions.has(str(atype)):
				d_action = str(atype)
				d_bonus = float(bonuses[atype])
				break
		if d_action == "":
			continue  # every action_type ignored — Part B has nothing left to contest

		var w_action: String = ""
		var w_bonus: float = INF
		for atype in ranked:
			if str(atype) == d_action:
				continue
			if float(bonuses[atype]) < w_bonus:
				w_bonus = float(bonuses[atype])
				w_action = str(atype)
		if w_action == "":
			continue  # only one non-ignored action_type exists — nothing to contrast

		var directive_pull_raw: float = d_bonus - w_bonus
		if directive_pull_raw <= epsilon * 1.5:
			continue  # flat/inverted or too small a spread — structural, not a bug (see doc comment)

		var decision_scale: float = directive_pull_raw / 0.9  # forces contest_ratio == 0.9
		var self_score_d: float = 0.0
		var self_score_w: float = directive_pull_raw + 5.0  # comfortably a genuine winner (self_margin > directive_pull)
		var chosen: Dictionary = {
			"action_type": w_action, "target_id": "e1",
			"score": self_score_w + w_bonus, "directive_bonus": w_bonus,
			"directive_bonus_nascent": w_bonus, "components": {},
		}
		var directive_candidates: Array = [
			{"action_type": d_action, "target_id": "", "score": self_score_d + d_bonus,
				"directive_bonus": d_bonus, "directive_bonus_nascent": d_bonus},
		]
		var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, decision_scale, 0.0, 0.5, divergence_cfg)
		if not bool(result.get("diverged", false)):
			return _fail("[%s] constructed conflict (chosen=%s vs directive_preferred=%s, contest_ratio target 0.9) did NOT diverge: %s" % [did, w_action, d_action, str(result)])
		exercised += 1

	if exercised == 0:
		return _fail("no directive in the registry was exercisable — every one was flat, single-action, or fully ignored; this is suspicious for the current registry (scout_carefully/seek_signs both have a real bonus spread) and should be investigated, not silently passed")
	return _pass()


# Test — (c) agreement never diverges, for every directive. chosen_action ==
# directive_action by construction — DivergenceDetector.detect()'s diverged
# gate requires chosen_action != directive_action (see its comment), so an
# Echo who does exactly what the directive's own top (non-ignored) preference
# is must never be logged as diverged, regardless of directive content.
static func _t_every_directive_agreement_never_diverges() -> Dictionary:
	var fx: Dictionary = _load_production_directive_fixtures()
	if fx.is_empty():
		return _fail("could not load production balance.json")
	var registry: Dictionary = fx["registry"]
	if registry.is_empty():
		return _fail("directive registry is empty — nothing to enumerate")
	var actor_cfg: Dictionary = fx["actor_cfg"]
	var divergence_cfg: Dictionary = fx["divergence_cfg"]
	var ignored_actions: Array = divergence_cfg.get("divergence_ignored_directive_actions", ["actor.idle"])

	for did_v in registry:
		var did: String = str(did_v)
		var directive: Dictionary = registry[did_v]
		var bonuses: Dictionary = _directive_bonus_by_action(directive, actor_cfg)
		if bonuses.is_empty():
			continue

		var ranked: Array = bonuses.keys()
		ranked.sort_custom(func(a, b): return float(bonuses[a]) > float(bonuses[b]))

		var d_action: String = ""
		var d_bonus: float = 0.0
		for atype in ranked:
			if not ignored_actions.has(str(atype)):
				d_action = str(atype)
				d_bonus = float(bonuses[atype])
				break
		if d_action == "":
			continue

		var chosen: Dictionary = {
			"action_type": d_action, "target_id": "e1",
			"score": 100.0 + d_bonus, "directive_bonus": d_bonus,
			"directive_bonus_nascent": d_bonus, "components": {},
		}
		var directive_candidates: Array = [
			{"action_type": d_action, "target_id": "", "score": 100.0 + d_bonus,
				"directive_bonus": d_bonus, "directive_bonus_nascent": d_bonus},
		]
		var result: Dictionary = DivergenceDetector.detect(chosen, directive_candidates, 50.0, 0.0, 0.5, divergence_cfg)
		if bool(result.get("diverged", true)):
			return _fail("[%s] agreement case (chosen_action == directive_action == '%s') incorrectly diverged: %s" % [did, d_action, str(result)])
	return _pass()
