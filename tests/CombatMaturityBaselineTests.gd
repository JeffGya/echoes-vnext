# res://tests/CombatMaturityBaselineTests.gd
# V2-COMBAT-003 Phase 3 — the Whole-band baseline scenario.
#
# PROBLEM THIS FILE FIXES: no recorded fixture anywhere in the suite ever held a Whole-band
# Echo. EchoFactory mints every Echo at rank 1 (nascent), and band_by_standing puts "whole" at
# rank 9 (V2-COMBAT-003 calling-aligned remap — was rank 4+). Leadership traits, the maturity
# band, and every Whole-band behavior branch in ActorStateMachine/BehaviorArbiter were
# therefore invisible to the entire suite — nothing observed them, so nothing could regress
# them.
#
# This file adds a Whole-band Echo to the suite through the real production rank-up path
# (ProgressionService.execute_rank_up(), looped one Standing at a time — see
# FlowFingerprintTests._promote_echo_rank()) and demonstrates a concrete, numeric behavioral
# difference between it and a Nascent Echo under otherwise-identical combat circumstances: the
# same board, the same encounter, the same round, the same enemy roster.
#
# CHARACTERIZATION — this file observes and pins what the code does today. It does not judge
# whether the magnitude of the difference is "enough" narratively; that is Jeff's call once it
# is visible at all, which is the whole point of this phase.
#
# ISOLATION: reuses FlowFingerprintTests._setup_encounter() (same isolated save path via
# TestSaveHarness, same pinned root_seed 12346, same draw-then-override mode forcing) rather
# than a second copy of the harness. Only the rank_overrides parameter is new, and it defaults
# to {} everywhere else, so no existing recorded fingerprint is touched by this file.

class_name CombatMaturityBaselineTests
extends RefCounted

const MAX_ROUNDS := 6


static func register(runner) -> void:
	runner.register_test("maturity_baseline/rank_up_reaches_whole_band_via_production_path", func(): return _t_rank_up_reaches_whole_band())
	runner.register_test("maturity_baseline/whole_vs_nascent_expression_diverges", func(): return _t_whole_vs_nascent_diverges())


# ---------------------------------------------------------------------------
# 1. The production rank-up path really reaches the Whole band.
# ---------------------------------------------------------------------------

## Drives a single fresh Echo from rank 1 to rank 9 through ProgressionService.execute_rank_up()
## — the same function core/runtime/controllers/ProgressionController.gd:handle_rank_up() calls
## for the player-facing "sanctum.rank_up" action — one Standing at a time. Confirms the band
## table actually calls that a Whole-band Echo, and that the config values this phase depends on
## (rank_strength_scale.max_rank, band_by_standing) still say what the handoff doc recorded.
static func _t_rank_up_reaches_whole_band() -> Dictionary:
	var config := ConfigService.new()
	var bal: Dictionary = config.get_balance()
	var data: Dictionary = bal.get("data", {})
	var summ_cfg: Dictionary = data.get("summoning", {})
	var expr_cfg: Dictionary = data.get("maturity_expression", {})
	var seed := CampaignSeed.new(12346)

	var echo: Dictionary = EchoFactory.generate("mat_rankup", "echo.mat0", 0, "summon", summ_cfg, expr_cfg)
	echo["id"] = "echo_mat_0001"
	if int(echo.get("rank", 0)) != 1:
		return { "ok": false, "error": "Expected a freshly summoned Echo at rank 1, got %d" % int(echo.get("rank", 0)) }

	FlowFingerprintTests._promote_echo_rank(echo, 9, bal, seed, null, 0)

	if int(echo.get("rank", 0)) != 9:
		return { "ok": false, "error": "Expected rank 9 after eight real rank-ups, got %d" % int(echo.get("rank", 0)) }
	if int(echo.get("standing", 0)) != 9:
		return { "ok": false, "error": "Expected standing==rank==9 (V2-PROG-004 bridge field), got %d" % int(echo.get("standing", 0)) }
	# calling_eligible is set permanently at rank 3 and never cleared by a later rank-up.
	if not bool(echo.get("calling_eligible", false)):
		return { "ok": false, "error": "Expected calling_eligible=true once rank 3 was crossed en route to 9" }

	var band_by_standing: Dictionary = expr_cfg.get("band_by_standing", {})
	var band: String = MaturityExpressionService.get_expression_band(int(echo["rank"]), band_by_standing)
	if band != "whole":
		return { "ok": false, "error": "Expected band_by_standing to call rank 9 'whole', got '%s'" % band }

	var max_rank: int = int(expr_cfg.get("rank_strength_scale", {}).get("max_rank", 9))
	var rank_strength: float = MaturityExpressionService.get_rank_strength(9, max_rank)
	var nascent_strength: float = MaturityExpressionService.get_rank_strength(1, max_rank)
	if not (rank_strength > nascent_strength):
		return { "ok": false, "error": "Expected rank_strength(9)=%.4f > rank_strength(1)=%.4f" % [rank_strength, nascent_strength] }

	return { "ok": true }


# ---------------------------------------------------------------------------
# 2. A Whole-band Echo and a Nascent Echo, same board, produce different observable output.
# ---------------------------------------------------------------------------

## Builds one COMBAT encounter (5-echo roster, same as every FlowFingerprintTests mode) and
## promotes roster index 0 to rank 9 (Whole) through the real production path, leaving index 1
## at rank 1 (Nascent) untouched — both then face the same board, the same enemy roster, the
## same round. Drives real rounds via combat.init/confirm_round/next_actor (never flow.new_game
## — AGENTS.md #17) and reads the per-turn autonomy outputs ActorStateMachine writes onto each
## acting actor's own dict every time it takes a turn:
##   _expression_band, _rank_strength, _judgment, _presence, _composure, _legibility
## (core/actors/ActorStateMachine.gd:183-189). These are the same fields the live game exposes
## in the flow.resolve snapshot (EncounterSnapshotBuilder.gd:115) and in CombatTurnActionService's
## per-turn payload (:379) — this test reads them at the source rather than duplicating a
## snapshot projection.
static func _t_whole_vs_nascent_diverges() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(
		EncounterResolutionModes.COMBAT, "mat_whole_vs_nascent", "", "", { 0: 9 })
	if env.is_empty():
		return { "ok": false, "error": "Encounter setup failed" }

	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]

	var whole_id := "echo_0001"   # roster index 0 — promoted to rank 9
	var nascent_id := "echo_0002" # roster index 1 — left at rank 1

	var whole_before: Dictionary = _find_actor(ectx.actors, whole_id)
	var nascent_before: Dictionary = _find_actor(ectx.actors, nascent_id)
	if whole_before.is_empty() or nascent_before.is_empty():
		return { "ok": false, "error": "Could not find both echo_0001 and echo_0002 on the board before combat" }
	if int(whole_before.get("rank", 0)) != 9:
		return { "ok": false, "error": "echo_0001 should be rank 9 going into combat, got %d" % int(whole_before.get("rank", 0)) }
	if int(nascent_before.get("rank", 0)) != 1:
		return { "ok": false, "error": "echo_0002 should be rank 1 going into combat, got %d" % int(nascent_before.get("rank", 0)) }

	runtime.dispatch({ "type": "combat.init" })
	var whole_seen := false
	var nascent_seen := false
	var whole_snap: Dictionary = {}
	var nascent_snap: Dictionary = {}

	for _r in range(MAX_ROUNDS):
		runtime.dispatch({ "type": "combat.confirm_round" })
		# combat.confirm_round itself resolves the round's first actor (V2-COMBAT-003 Phase 2a
		# finding) — capture immediately, exactly as FlowFingerprintTests._drive_and_capture does.
		_capture_if_new(ectx.actors, whole_id, nascent_id, whole_snap, nascent_snap)
		var guard := 0
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({ "type": "combat.next_actor" })
			_capture_if_new(ectx.actors, whole_id, nascent_id, whole_snap, nascent_snap)
		if not whole_snap.is_empty():
			whole_seen = true
		if not nascent_snap.is_empty():
			nascent_seen = true
		if whole_seen and nascent_seen:
			break
		if bool(ectx.combat_state.get("combat_over", false)):
			break

	if not whole_seen:
		return { "ok": false, "error": "echo_0001 (Whole) never took a turn within %d rounds" % MAX_ROUNDS }
	if not nascent_seen:
		return { "ok": false, "error": "echo_0002 (Nascent) never took a turn within %d rounds" % MAX_ROUNDS }

	# --- The categorical difference: expression_band ---
	var whole_band: String = str(whole_snap.get("expression_band", ""))
	var nascent_band: String = str(nascent_snap.get("expression_band", ""))
	if whole_band != "whole":
		return { "ok": false, "error": "Expected echo_0001's expression_band=='whole' on its own turn, got '%s'" % whole_band }
	if nascent_band != "nascent":
		return { "ok": false, "error": "Expected echo_0002's expression_band=='nascent' on its own turn, got '%s'" % nascent_band }

	# --- The numeric difference: rank_strength is a direct, config-verified floor on the gap ---
	# rank_strength(9)=8/8=1.0, rank_strength(1)=0.0 (rank_strength_scale.max_rank=9). Every one
	# of judgment/presence/composure/legibility sums rank_strength * a positive weight (see
	# data.maturity_expression.autonomy_outputs — rank_strength_weight is 0.25/0.20/0.36/0.30
	# respectively, all > 0, all other terms independent of rank), so this alone guarantees each
	# output is measurably higher for the Whole Echo unless swamped by a materially larger
	# negative term (fear_pressure/instability) on the Whole Echo's side — which this assertion
	# checks for directly rather than assuming away.
	var whole_rs: float = float(whole_snap.get("rank_strength", -1.0))
	var nascent_rs: float = float(nascent_snap.get("rank_strength", -1.0))
	if not (whole_rs > nascent_rs):
		return { "ok": false, "error": "Expected rank_strength(whole)=%.4f > rank_strength(nascent)=%.4f" % [whole_rs, nascent_rs] }

	var whole_j: float = float(whole_snap.get("judgment", -1.0))
	var nascent_j: float = float(nascent_snap.get("judgment", -1.0))
	var whole_p: float = float(whole_snap.get("presence", -1.0))
	var nascent_p: float = float(nascent_snap.get("presence", -1.0))
	var whole_c: float = float(whole_snap.get("composure", -1.0))
	var nascent_c: float = float(nascent_snap.get("composure", -1.0))
	var whole_l: float = float(whole_snap.get("legibility", -1.0))
	var nascent_l: float = float(nascent_snap.get("legibility", -1.0))

	if not (whole_j > nascent_j):
		return { "ok": false, "error": "Expected judgment(whole)=%.4f > judgment(nascent)=%.4f" % [whole_j, nascent_j] }
	if not (whole_c > nascent_c):
		return { "ok": false, "error": "Expected composure(whole)=%.4f > composure(nascent)=%.4f" % [whole_c, nascent_c] }
	if not (whole_l > nascent_l):
		return { "ok": false, "error": "Expected legibility(whole)=%.4f > legibility(nascent)=%.4f" % [whole_l, nascent_l] }

	# MEASURED on this fixture (rank_strength(whole)=1.0000, rank_strength(nascent)=0.0000):
	#   judgment:   whole=0.3250  nascent=0.0550
	#   composure:  whole=0.5281  nascent=0.1363
	#   legibility: whole=0.4125  nascent=0.1000
	#   presence:   whole=0.3585  nascent=0.2560
	#
	# V2-COMBAT-003: promoting to rank 9 (not the pre-remap rank 4) quadruples rank_strength's
	# contribution to presence (0.20 weight * 1.0 vs * 0.375), which now clears the
	# archetype/calling/morale terms that used to swamp it — presence is asserted strictly
	# greater below too, unlike the pre-remap rank-4 fixture where it was not.
	if not (whole_p > nascent_p):
		return { "ok": false, "error": "Expected presence(whole)=%.4f > presence(nascent)=%.4f" % [whole_p, nascent_p] }
	return { "ok": true }


static func _find_actor(actors: Array, id: String) -> Dictionary:
	for a_v in actors:
		if a_v is Dictionary and str((a_v as Dictionary).get("id", "")) == id:
			return a_v as Dictionary
	return {}


## Records the first post-turn snapshot of the autonomy outputs for either watched id, the
## instant each one first appears (i.e. the instant that actor has taken its own turn) — later
## turns for the same actor are not overwritten, so this is genuinely "same round, same board"
## for both actors' FIRST action.
static func _capture_if_new(actors: Array, whole_id: String, nascent_id: String, whole_snap: Dictionary, nascent_snap: Dictionary) -> void:
	if whole_snap.is_empty():
		var w: Dictionary = _find_actor(actors, whole_id)
		if not w.is_empty() and w.has("_expression_band"):
			whole_snap.merge(_autonomy_snapshot(w))
	if nascent_snap.is_empty():
		var n: Dictionary = _find_actor(actors, nascent_id)
		if not n.is_empty() and n.has("_expression_band"):
			nascent_snap.merge(_autonomy_snapshot(n))


static func _autonomy_snapshot(a: Dictionary) -> Dictionary:
	return {
		"expression_band": str(a.get("_expression_band", "")),
		"rank_strength":   float(a.get("_rank_strength", -1.0)),
		"judgment":        float(a.get("_judgment", -1.0)),
		"presence":        float(a.get("_presence", -1.0)),
		"composure":       float(a.get("_composure", -1.0)),
		"legibility":      float(a.get("_legibility", -1.0)),
	}
