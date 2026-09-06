# res://tests/BehaviorCharacterizationTests.gd
# V2-COMBAT-003 Phase 1 — CHARACTERIZATION ONLY. No production file changed by this story phase.
#
# Pins seven current-behaviour facts named in the V2-COMBAT-003 kickoff so a later phase can
# invert each assertion when it corrects that defect. Every test here carries
#   # KNOWN DEFECT (V2-COMBAT-003 will change this):
# directly above it. CHARACTERIZATION, NOT CORRECTION — nothing is fixed here.
#
# Pattern file: tests/CombatBaselineTests.gd (register(runner) + register_test(name, func())
# returning {"ok": bool, "error": String}). Harness reuse, same rule that file states: never
# duplicate a fixture/helper that already has an owner elsewhere in tests/. This file reuses,
# rather than re-implements:
#   - FlowFingerprintTests._setup_encounter() / ._drive_and_capture()  (full encounter harness)
#   - CombatPressureTests._context() / MaturityExpressionTests._BALANCE_CFG / ._make_enemy()
#     (hand-built fixtures already proven correct by their owning suites)
#
# Some facts are pinned via a full encounter drive (facts 2); most are pinned via a direct,
# focused call into the real production method with a hand-built fixture, because assembling a
# full encounter that reliably lands an actor in the exact narrow state under test (boxed in by
# allies, a specific fear value on a specific band, a specific health ratio) is impractical to
# do deterministically without duplicating a great deal of encounter-setup machinery. Each test
# says which shape it is in its own doc comment.

class_name BehaviorCharacterizationTests
extends RefCounted

const LiveMovement = preload("res://core/movement/LiveMovementContextService.gd")
const CombatPressureServiceScript = preload("res://core/movement/CombatPressureService.gd")
const BehaviorArbiterScript = preload("res://core/actors/behaviors/BehaviorArbiter.gd")
const ActorStateMachineScript = preload("res://core/actors/ActorStateMachine.gd")


static func register(runner) -> void:
	runner.register_test("behavior_char/movement_option_starvation_boxed_in", func(): return _t_movement_option_starvation())
	runner.register_test("behavior_char/moved_actor_can_still_log_actor_idle", func(): return _t_moved_actor_logs_idle())
	runner.register_test("behavior_char/enemy_can_refuse_no_faction_gate", func(): return _t_enemy_can_refuse())
	runner.register_test("behavior_char/enemy_nascent_65_vs_grounded_echo_80", func(): return _t_band_thresholds_diverge())
	runner.register_test("behavior_char/live_options_carry_real_spatial_terms", func(): return _t_live_options_zero_spatial_terms())
	runner.register_test("behavior_char/purify_above_half_health_delegates_to_ordinary_combat", func(): return _t_purify_delegates_to_ordinary_combat())
	runner.register_test("behavior_char/legacy_selector_fallback_is_loud", func(): return _t_legacy_fallback_loud())
	runner.register_test("behavior_char/health_ratio_ladders_agree_on_zero_max_hp", func(): return _t_health_ratio_ladders_agree())


# ---------------------------------------------------------------------------
# Shared fixture helpers (local to this file — no existing suite owns a
# "build a raw actor dict for LiveMovementContextService" helper at this shape).
# ---------------------------------------------------------------------------

## V2-COMBAT-003 Phase 2b: production-shaped vector state. This is an Actor dict (post-
## EchoActor.from_echo shape), not a roster Echo dict, so the production summon-time pair
## (EmotionService.init_echo + VectorService.init_vectors, called on the pre-mapped Echo dict —
## see FlowFingerprintTests._setup_encounter) doesn't apply directly here: an Actor dict never
## carries "class_origin" in production (EchoActor.gd's field list omits it) and never reads an
## "emotion" sub-dict for its live fear/morale (those are top-level per the Actor Contract).
## What DOES apply, and is called directly rather than hand-rolled: VectorService.init_vectors()
## is the single choke point for turning a class_origin + real archetype_init config into
## vector_scores/dominant_vector (VectorService.gd:28-65) — exactly the step this fixture
## skipped, leaving vector_scores={} and silently disabling the vector half of
## BehaviorArbiter._score() (ANSWERS.md #50). class_origin is added here only to drive that one
## real call — it does not persist past this function, matching the fact that production never
## carries it past EchoFactory/EchoActor.from_echo either.
static func _echo_actor(id: String, col: int, row: int) -> Dictionary:
	var actor: Dictionary = {
		"id": id, "faction": "echo", "actor_type": "echo", "calling_origin": "uncalled",
		"traits": {}, "class_origin": "vanguard", "vector_scores": {}, "dominant_vector": "",
		"fear": 0, "morale": 50, "rank": 1,
		"grid_pos": { "col": col, "row": row }, "stats": { "max_hp": 100 }, "current_hp": 100,
	}
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var vec_cfg: Dictionary = _real_bdata().get("vectors", {})
	VectorService.init_vectors(actor, vec_cfg, logger, 0)
	actor.erase("class_origin")
	return actor


static func _enemy_actor(id: String, col: int, row: int) -> Dictionary:
	return {
		"id": id, "faction": "enemy", "actor_type": "enemy", "calling_origin": "enemy",
		"traits": {}, "vector_scores": {}, "fear": 0, "morale": 50, "rank": 1,
		"grid_pos": { "col": col, "row": row }, "stats": { "max_hp": 100 }, "current_hp": 100,
	}


static func _full_walkable(cols: int, rows: int) -> Dictionary:
	var w: Dictionary = {}
	for col in range(cols):
		for row in range(rows):
			w["%d,%d" % [col, row]] = true
	return w


static func _real_bdata() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	return config.get_balance().get("data", {}) as Dictionary


# ---------------------------------------------------------------------------
# 1 — Movement-option starvation: goals >= 1, options == 0, gated on goals only.
#
# FOCUSED, direct call into the real production method
# (LiveMovementContextService.prepare_live_movement_context — the exact method FlowRuntime
# calls). Reproducing the "long board, capacity exhausted mid-route" shape from V2-INFRA-003's
# defect register deterministically, without a live seeded encounter, is impractical (which
# column/row gets the 5x multiplier is itself an RNG draw). Instead this reproduces the SAME
# contract-level outcome via a cause the production comment at LiveMovementContextService.gd
# names explicitly ("boxed in by allies"): the mover has a live, reachable-in-principle combat
# goal (a hostile exists) but literally no walkable neighbour cell, so no route exists AT ALL,
# at any cost. `_movement_direct_option_for_goal` returns {} and the option list stays empty
# while `CombatPressureService.build_goals` still produced >=1 goal — the exact
# goals>=1/options==0 shape LiveMovementContextService.gd:211's "gate on goals, not options"
# comment describes.
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_movement_option_starvation() -> Dictionary:
	var mover: Dictionary = _echo_actor("echo.boxed", 5, 5)
	var enemy: Dictionary = _enemy_actor("enemy.far", 0, 0)
	# Eight allies occupy every one of the mover's neighbour cells — nothing left to step onto.
	var allies: Array = []
	var n: int = 0
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			n += 1
			allies.append(_echo_actor("echo.wall%d" % n, 5 + dc, 5 + dr))

	var ectx := EncounterContext.new()
	ectx.actors = [mover, enemy] + allies
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.combat_state = {}
	ectx.purifier_id = ""

	var flow_ctx := FlowContext.new()
	flow_ctx.encounter_ctx = ectx

	var logger := StructuredLogger.new()
	logger.set_level("off")

	var bdata: Dictionary = _real_bdata()
	var movement_board_cfg: Dictionary = {
		"board_cols": 10, "board_rows": 10,
		"walkable": _full_walkable(10, 10),
	}

	var live := LiveMovement.new(flow_ctx, logger)
	var result: Dictionary = live.prepare_live_movement_context(
		mover, ectx, ectx.combat_state, movement_board_cfg, bdata, 0)

	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected a valid movement-context result, got invalid: %s" % str(result) }
	var goals: Array = result.get("goals", []) as Array
	var options: Array = result.get("options", []) as Array
	if goals.size() < 1:
		return { "ok": false, "error": "expected the boxed-in mover to still receive >=1 goal (a live hostile exists), got %d" % goals.size() }
	if options.size() != 0:
		return { "ok": false, "error": "expected zero routable options for a mover with no walkable neighbour cell, got %d: %s" % [options.size(), JSON.stringify(options)] }
	if not bool(result.get("selection_enabled", false)):
		return { "ok": false, "error": "selection_enabled is documented to depend on goals alone (LiveMovementContextService.gd:211) — expected true with %d goal(s) present" % goals.size() }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 2 — a turn that traversed cells is never recorded as actor.idle.
#
# Full production drive: reuses FlowFingerprintTests._setup_encounter() +
# ._drive_and_capture() (the proven mode-forcing round loop) rather than a second copy of it.
# COMBAT mode, own seed tag so it does not share a save file with any other suite. Scans the
# captured per-turn projection for any turn where the actor's position changed but its logged
# action_type is still "actor.idle" — V2-COMBAT-003 Phase 5 fixed
# LiveMovementContextService.apply_live_activation() to relabel such a turn actor.move.
# ---------------------------------------------------------------------------

# FIXED (V2-COMBAT-003 Phase 5): was KNOWN DEFECT "actor.idle recorded for a moved turn" —
# assertion inverted.
static func _t_moved_actor_logs_idle() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "cb_char_moved_idle")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(env["runtime"], env["ectx"], 30)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "encounter did not conclude within 30 rounds — cannot evaluate the full trace" }

	for round_v in drive["rounds"] as Array:
		var round_data: Dictionary = round_v as Dictionary
		for turn_v in round_data["turns"] as Array:
			var turn: Dictionary = turn_v as Dictionary
			if str(turn.get("action_type", "")) != "actor.idle":
				continue
			var from_pos: Dictionary = turn.get("from_pos", {}) as Dictionary
			var to_pos: Dictionary = turn.get("to_pos", {}) as Dictionary
			if from_pos.is_empty() or to_pos.is_empty():
				continue
			if JSON.stringify(from_pos) != JSON.stringify(to_pos):
				return { "ok": false, "error": "round %d actor %s logged actor.idle but moved %s -> %s" \
					% [int(round_data["round"]), str(turn["actor_id"]), JSON.stringify(from_pos), JSON.stringify(to_pos)] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 3 — An enemy can no longer refuse. V2-COMBAT-003 Phase 4 gated the Absolute Fear
# Rule (ActorStateMachine.gd:288) to faction == "echo" (decision 3, D97): an enemy
# keeps fear as a score input but never receives the permanent-refusal consequence.
#
# Real production call: ActorStateMachine.advance_turn(), the single choke point for intent
# selection. Reuses MaturityExpressionTests._BALANCE_CFG (the already-proven config fixture
# every fear-threshold test in that suite uses) and ._make_enemy() rather than re-authoring
# either.
# ---------------------------------------------------------------------------

# FIXED (V2-COMBAT-003 Phase 4): was KNOWN DEFECT "an enemy can refuse" — assertion inverted.
static func _t_enemy_can_refuse() -> Dictionary:
	var enemy: Dictionary = MaturityExpressionTests._make_enemy("en_refuse", { "col": 0, "row": 0 })
	enemy["fear"] = 70  # >= nascent's band threshold of 65 (see refusal_thresholds_by_band)
	enemy["morale"] = 50
	var ally_echo: Dictionary = _echo_actor("echo.bystander", 5, 5)

	var sm := ActorStateMachine.new(enemy)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var context := { "actor": enemy, "all_actors": [ally_echo], "cfg": MaturityExpressionTests._BALANCE_CFG, "t": 1 }
	var intent: Dictionary = sm.advance_turn(context, logger, 1)

	if str(intent.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "expected an enemy at fear=70 (>= nascent threshold 65) to NOT refuse — the Absolute Fear Rule is now gated to faction == 'echo'. Got: %s" % str(intent) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 4 — Band threshold divergence: an enemy (rank 1 -> nascent) gets threshold 65; a grounded
# (rank 3) Echo gets 80, for the identical fear value.
#
# Same real production call as fact 3, reading the `_fear_threshold` field
# ActorStateMachine.advance_turn() writes onto the actor dict as a side effect
# (ActorStateMachine.gd's "_actor['_fear_threshold'] = fear_threshold").
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_band_thresholds_diverge() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var enemy: Dictionary = MaturityExpressionTests._make_enemy("en_band", { "col": 0, "row": 0 })
	enemy["fear"] = 70
	enemy["morale"] = 50
	var sm_enemy := ActorStateMachine.new(enemy)
	sm_enemy.advance_turn({ "actor": enemy, "all_actors": [], "cfg": MaturityExpressionTests._BALANCE_CFG, "t": 1 }, logger, 1)
	if int(enemy.get("_fear_threshold", -1)) != 65:
		return { "ok": false, "error": "expected an unranked enemy (rank 1 -> nascent) to resolve threshold 65, got %s" % str(enemy.get("_fear_threshold", "<missing>")) }

	var echo := ActorTests._make_test_echo("echo_grounded", "Ama Kwei")
	var echo_actor: Dictionary = EchoActor.from_echo(echo)
	echo_actor["rank"] = 3  # grounded per band_by_standing
	echo_actor["fear"] = 70
	echo_actor["morale"] = 50
	echo_actor["grid_pos"] = { "col": 0, "row": 0 }
	# A second LIVE echo keeps this actor from being the last echo standing — that path
	# overrides the threshold to last_stand_fear_threshold.grounded (88 in this fixture),
	# which would mask the plain band-baseline value this test pins.
	var live_ally: Dictionary = _echo_actor("echo.ally_alive", 1, 1)
	var sm_echo := ActorStateMachine.new(echo_actor)
	var intent_echo: Dictionary = sm_echo.advance_turn(
		{ "actor": echo_actor, "all_actors": [live_ally], "cfg": MaturityExpressionTests._BALANCE_CFG, "t": 1 }, logger, 1)
	if int(echo_actor.get("_fear_threshold", -1)) != 80:
		return { "ok": false, "error": "expected a grounded (rank 3) echo to resolve threshold 80, got %s" % str(echo_actor.get("_fear_threshold", "<missing>")) }
	# Same fear value (70), divergent bands -> divergent outcomes: the grounded echo must NOT refuse.
	if str(intent_echo.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "grounded echo at fear=70 (< threshold 80) refused unexpectedly: %s" % str(intent_echo) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 5 — exposure, congestion and cohesion are published from MovementOptionService's own
# implementations. They were hardcoded 0.0 until V2-COMBAT-003 phase 6.
#
# Same real production method as fact 1 (prepare_live_movement_context), this time with the
# mover free to move (no boxing-in), so it actually receives >=1 option to inspect.
#
# The mover starts two cells from the only hostile, so it must step into that hostile's
# control to strike: exposure 1.0, corroborated by hostile_control_sources naming that same
# enemy. congestion is 1/8 — one of the destination's eight neighbours holds the enemy.
# cohesion is 0.0 because a two-actor fixture has no friendly actor to be close to;
# _cohesion returns 0.0 on an empty friend set rather than dividing by zero.
#
# The gap is load-bearing: a mover already within melee reach gets the zero-step stay
# option, whose empty path carries exposure 0.0 — truthful, but indistinguishable from the
# hardcoded 0.0 this fact exists to rule out.
# ---------------------------------------------------------------------------

static func _t_live_options_zero_spatial_terms() -> Dictionary:
	var mover: Dictionary = _echo_actor("echo.free", 0, 1)
	var enemy: Dictionary = _enemy_actor("enemy.near", 2, 1)  # out of reach -> the mover must move to strike

	var ectx := EncounterContext.new()
	ectx.actors = [mover, enemy]
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.combat_state = {}
	ectx.purifier_id = ""

	var flow_ctx := FlowContext.new()
	flow_ctx.encounter_ctx = ectx

	var logger := StructuredLogger.new()
	logger.set_level("off")

	var bdata: Dictionary = _real_bdata()
	var movement_board_cfg: Dictionary = {
		"board_cols": 10, "board_rows": 10,
		"walkable": _full_walkable(10, 10),
	}

	var live := LiveMovement.new(flow_ctx, logger)
	var result: Dictionary = live.prepare_live_movement_context(
		mover, ectx, ectx.combat_state, movement_board_cfg, bdata, 0)

	if not bool(result.get("valid", false)):
		return { "ok": false, "error": "expected a valid movement-context result, got invalid: %s" % str(result) }
	var options: Array = result.get("options", []) as Array
	if options.is_empty():
		return { "ok": false, "error": "expected at least one live option for a free, adjacent-to-hostile mover — got none, cannot check the spatial fields" }
	for option_v in options:
		var option: Dictionary = option_v as Dictionary
		if not (is_equal_approx(float(option.get("exposure", -1.0)), 1.0)
				and is_equal_approx(float(option.get("congestion", -1.0)), 0.125)
				and is_equal_approx(float(option.get("cohesion", -1.0)), 0.0)):
			return { "ok": false, "error": "expected exposure 1.0 / congestion 0.125 / cohesion 0.0, got %s" % str(option) }
		if (option.get("hostile_control_sources", []) as Array) != ["enemy.near"]:
			return { "ok": false, "error": "exposure 1.0 must agree with hostile_control_sources, got %s" % str(option) }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 6 — Purify-shrine mode delegates to ordinary combat once objective_health_ratio >= 0.5
# (CombatPressureService.gd:188).
#
# Real production call: CombatPressureService.build_goals(), reusing CombatPressureTests._context()
# (the already-proven fixture builder that suite uses for every mode) rather than re-authoring
# a MovementContext/CombatPressureSnapshot pair by hand. Compares the "purify_shrine" result at
# health >= 0.5 against the "combat" mode result built from the same positions, after
# normalizing away the one expected difference: the mode name baked into each goal_id and into
# each goal's "mode.<mode>" pressure-source tag (CombatPressureService._goal_sources).
# Everything else — purpose, destination region, urgency, relevant actors — must be identical,
# because _add_purify's >=0.5 branch does nothing but call _add_ordinary_combat(..., "baseline"),
# the exact function "combat"/"endure" call directly.
# ---------------------------------------------------------------------------

static func _normalize_goal(goal: Dictionary, mode: String) -> Dictionary:
	var sources: Array = (goal.get("pressure_sources", []) as Array).filter(
		func(s: Variant) -> bool: return not str(s).begins_with("mode."))
	sources.sort()
	var goal_id: String = str(goal.get("goal_id", "")).replace(".%s." % mode, ".<mode>.")
	return {
		"goal_id_normalized": goal_id,
		"purpose": str(goal.get("purpose", "")),
		"destination_region": goal.get("destination_region", []),
		"urgency": float(goal.get("urgency", -1.0)),
		"relevant_actors": goal.get("relevant_actors", []),
		"sources_normalized": sources,
	}


static func _normalized_goal_set(result: Dictionary, mode: String) -> Array:
	var out: Array = []
	for goal_v in result.get("goals", []) as Array:
		out.append(_normalize_goal(goal_v as Dictionary, mode))
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		return JSON.stringify(a) < JSON.stringify(b))
	return out


# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_purify_delegates_to_ordinary_combat() -> Dictionary:
	var purify_ctx: Dictionary = CombatPressureTests._context("purify_shrine", "hostile")
	(purify_ctx["objective_pressure"] as Dictionary)["objective_health_ratio"] = 1.0
	var purify_result: Dictionary = CombatPressureServiceScript.build_goals(purify_ctx)
	if not bool(purify_result.get("valid", false)):
		return { "ok": false, "error": "purify_shrine (healthy) build_goals rejected: %s" % str(purify_result) }

	var combat_ctx: Dictionary = CombatPressureTests._context("combat", "hostile")
	# _goal_sources() tags "state.objective_low" whenever objective_health_ratio < 0.5,
	# regardless of mode — CombatPressureTests._context()'s default fixture value (0.4) would
	# otherwise leak an unrelated difference into this comparison that has nothing to do with
	# purify's own health-gated branch.
	(combat_ctx["objective_pressure"] as Dictionary)["objective_health_ratio"] = 1.0
	var combat_result: Dictionary = CombatPressureServiceScript.build_goals(combat_ctx)
	if not bool(combat_result.get("valid", false)):
		return { "ok": false, "error": "combat build_goals rejected: %s" % str(combat_result) }

	var purify_norm: Array = _normalized_goal_set(purify_result, "purify_shrine")
	var combat_norm: Array = _normalized_goal_set(combat_result, "combat")
	if JSON.stringify(purify_norm) != JSON.stringify(combat_norm):
		return { "ok": false, "error": "purify_shrine at health>=0.5 did not produce the same (mode-normalized) goals as plain combat:\n  purify=%s\n  combat=%s" % [JSON.stringify(purify_norm), JSON.stringify(combat_norm)] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 7 — The legacy selector fallback (ActorStateMachine.gd, select_movement_intent returning
# valid:false) now ANNOUNCES itself. FIXED by V2-COMBAT-003 phase 10, owner decision 7.
#
# This test used to pin the SILENCE and was marked "KNOWN DEFECT (V2-COMBAT-003 will change
# this)". It now pins the opposite, on the same two contexts: (a) a context that never offers
# movement_context/profile/goals/options at all — the pure legacy route, which stays silent
# because it is a unit-test idiom, not a contract failure — and (b) a context that offers all
# four keys but whose movement_context is an empty dict, which fails MovementContext.validate()
# trivially and makes select_movement_intent() return valid:false.
#
# Case (b) must log exactly one extra `actor.legacy_selector_fallback` warning carrying the
# actor and the exact rejection reason, and must record exactly one ledger entry.
#
# THIS TEST CONSUMES ITS OWN LEDGER ENTRY. It induces the fallback deliberately, and
# MovementFallbackGuardTests fails the whole run on any entry left behind.
# ---------------------------------------------------------------------------

static func _logged_types(logger: StructuredLogger) -> Array:
	var out: Array = []
	for event_v in logger.get_logs():
		out.append(str((event_v as Dictionary).get("type", "")))
	return out


static func _t_legacy_fallback_loud() -> Dictionary:
	var enemy_for_legacy: Dictionary = _enemy_actor("enemy.legacy", 0, 0)
	var enemy_for_fallback: Dictionary = _enemy_actor("enemy.fallback", 0, 0)
	var ally: Dictionary = _echo_actor("echo.witness", 5, 5)

	# Start from a clean ledger so the count below describes this test alone.
	ActorStateMachine.take_legacy_selector_uses()

	var logger_legacy := StructuredLogger.new()
	logger_legacy.set_level(StructuredLogger.LEVEL_DEBUG)
	var sm_legacy := ActorStateMachine.new(enemy_for_legacy)
	var context_legacy := { "actor": enemy_for_legacy, "all_actors": [ally], "t": 1 }
	sm_legacy.advance_turn(context_legacy, logger_legacy, 1)
	var types_legacy: Array = _logged_types(logger_legacy)
	if types_legacy.has("actor.legacy_selector_fallback"):
		return { "ok": false, "error": "the no-movement-context route logged the fallback warning; it is a unit-test idiom and must stay silent" }
	if not ActorStateMachine.legacy_selector_uses.is_empty():
		return { "ok": false, "error": "the no-movement-context route wrote a ledger entry; only the valid:false fallback may" }

	var logger_fallback := StructuredLogger.new()
	logger_fallback.set_level(StructuredLogger.LEVEL_DEBUG)
	var sm_fallback := ActorStateMachine.new(enemy_for_fallback)
	var context_fallback := {
		"actor": enemy_for_fallback, "all_actors": [ally], "t": 1,
		"movement_context": {}, "movement_profile": {}, "movement_goals": [], "movement_options": [],
	}
	sm_fallback.advance_turn(context_fallback, logger_fallback, 1)
	var types_fallback: Array = _logged_types(logger_fallback)
	if not types_fallback.has("actor.legacy_selector_fallback"):
		return { "ok": false, "error": "the movement-selection-failed fallback logged no warning; it is silent again:\n  types=%s" % JSON.stringify(types_fallback) }

	# The warning must say WHY, not only THAT.
	var warned: Dictionary = {}
	for event_v in logger_fallback.get_logs():
		var event: Dictionary = event_v as Dictionary
		if str(event.get("type", "")) == "actor.legacy_selector_fallback":
			warned = event.get("data", {}) as Dictionary
	if str(warned.get("actor_id", "")) != "enemy.fallback":
		return { "ok": false, "error": "the warning does not name the actor: %s" % JSON.stringify(warned) }
	var reason: String = str(warned.get("reason", ""))
	if reason == "" or reason == "unreported":
		return { "ok": false, "error": "the warning does not carry a rejection reason: %s" % JSON.stringify(warned) }

	# Consume the deliberate entry, or MovementFallbackGuardTests fails the whole run.
	var uses: Array = ActorStateMachine.take_legacy_selector_uses()
	if uses.size() != 1:
		return { "ok": false, "error": "expected exactly one ledger entry, got %d" % uses.size() }
	if str((uses[0] as Dictionary).get("reason", "")) != reason:
		return { "ok": false, "error": "the ledger entry and the warning disagree about the reason" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 8 (task's fact 7) — health_ratio had two divergent ladders for the same input:
# BehaviorArbiter's returned 1.0 when max_hp <= 0, LiveMovementContextService's per-actor
# fact builder 0.0. The arbiter's copy is gone; both sides now read
# ActorService.health_ratio, and BehaviorArbiter._validate_perceived_actor compares the two
# every turn, so a new divergence is a movement failure rather than a difference of opinion.
#
# FOCUSED unit-level calls into both real methods with the SAME actor dict — no full
# encounter needed; this is a pure function comparison.
# ---------------------------------------------------------------------------

static func _t_health_ratio_ladders_agree() -> Dictionary:
	var actor: Dictionary = { "id": "actor.zero_max_hp", "stats": { "max_hp": 0 }, "current_hp": 50 }

	var arbiter_ratio: float = ActorService.health_ratio(actor)
	if not is_equal_approx(arbiter_ratio, 1.0):
		return { "ok": false, "error": "expected ActorService.health_ratio() to return the absent-data sentinel 1.0 for max_hp<=0, got %s" % str(arbiter_ratio) }

	var flow_ctx := FlowContext.new()
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var live := LiveMovement.new(flow_ctx, logger)
	var facts: Array = live._movement_actor_facts([actor])
	if facts.is_empty():
		return { "ok": false, "error": "expected one perceived-actor fact back, got none" }
	var live_ratio: float = float((facts[0] as Dictionary).get("health_ratio", -1.0))
	if not is_equal_approx(arbiter_ratio, live_ratio):
		return { "ok": false, "error": "expected both ladders to give the same answer for one actor dict, got arbiter=%s live=%s" % [str(arbiter_ratio), str(live_ratio)] }
	return { "ok": true }
