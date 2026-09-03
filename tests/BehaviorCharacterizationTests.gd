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
	runner.register_test("behavior_char/live_options_always_zero_spatial_terms", func(): return _t_live_options_zero_spatial_terms())
	runner.register_test("behavior_char/purify_above_half_health_delegates_to_ordinary_combat", func(): return _t_purify_delegates_to_ordinary_combat())
	runner.register_test("behavior_char/legacy_selector_fallback_is_silent", func(): return _t_legacy_fallback_silent())
	runner.register_test("behavior_char/health_ratio_ladders_diverge_on_zero_max_hp", func(): return _t_health_ratio_ladders_diverge())


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
# 2 — actor.idle is recorded for a turn that logged a real actor.moved path.
#
# Full production drive: reuses FlowFingerprintTests._setup_encounter() +
# ._drive_and_capture() (the proven mode-forcing round loop) rather than a second copy of it.
# COMBAT mode, own seed tag so it does not share a save file with any other suite. Scans the
# captured per-turn projection (already recorded by _drive_and_capture from
# EncounterContext.last_round_results + before/after grid positions — no new instrumentation
# added) for at least one turn where the actor's position changed but its logged action_type
# is still "actor.idle" — the exact shape the V2-INFRA-003 defect register calls "normal": a
# resolved_action came back empty (target out of range after a partial move), so
# LiveMovementContextService.gd's activation helper labels the turn actor.idle even though the
# actor really moved.
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_moved_actor_logs_idle() -> Dictionary:
	var env: Dictionary = FlowFingerprintTests._setup_encounter(EncounterResolutionModes.COMBAT, "cb_char_moved_idle")
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var drive: Dictionary = FlowFingerprintTests._drive_and_capture(env["runtime"], env["ectx"], 30)
	if not bool(drive.get("combat_over", false)):
		return { "ok": false, "error": "encounter did not conclude within 30 rounds — cannot evaluate the full trace" }

	var found: Dictionary = {}
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
				found = { "round": round_data["round"], "actor_id": turn["actor_id"], "from_pos": from_pos, "to_pos": to_pos }
				break
		if not found.is_empty():
			break

	if found.is_empty():
		return { "ok": false, "error": "no turn in a 30-round COMBAT trace showed a moved actor logged as actor.idle — either the trace is too short/uneventful, or this defect no longer reproduces" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 3 — An enemy can refuse. The Absolute Fear Rule (ActorStateMachine.gd:288) is not gated by
# faction.
#
# Real production call: ActorStateMachine.advance_turn(), the single choke point for intent
# selection. Reuses MaturityExpressionTests._BALANCE_CFG (the already-proven config fixture
# every fear-threshold test in that suite uses) and ._make_enemy() rather than re-authoring
# either.
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
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

	if str(intent.get("action_type", "")) != "actor.refuse":
		return { "ok": false, "error": "expected an enemy at fear=70 (>= nascent threshold 65) to refuse — the Absolute Fear Rule carries no faction gate. Got: %s" % str(intent) }
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
# 5 — Three live-option fields are always zero: exposure, congestion, cohesion
# (LiveMovementContextService.gd:452-454).
#
# Same real production method as fact 1 (prepare_live_movement_context), this time with the
# mover free to move (no boxing-in), so it actually receives >=1 option to inspect.
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_live_options_zero_spatial_terms() -> Dictionary:
	var mover: Dictionary = _echo_actor("echo.free", 1, 1)
	var enemy: Dictionary = _enemy_actor("enemy.near", 2, 1)  # adjacent -> a direct "engage" goal+option

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
		if not (is_equal_approx(float(option.get("exposure", -1.0)), 0.0)
				and is_equal_approx(float(option.get("congestion", -1.0)), 0.0)
				and is_equal_approx(float(option.get("cohesion", -1.0)), 0.0)):
			return { "ok": false, "error": "expected exposure/congestion/cohesion to all be 0.0 (hardcoded), got %s" % str(option) }
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
# valid:false) logs nothing of its own.
#
# Real production call: ActorStateMachine.advance_turn(). Compares the exact set of logged
# event types between (a) a context that never offers movement_context/profile/goals/options at
# all (the pure legacy path) and (b) a context that offers all four keys but with a movement_context
# that fails contract validation trivially (an empty dict), forcing select_movement_intent() to
# return valid:false and advance_turn() to fall through to the legacy _behavior_module.select_intent()
# call with no log call of its own in between. If the fallback logged anything extra, the two
# type lists would differ.
# ---------------------------------------------------------------------------

static func _logged_types(logger: StructuredLogger) -> Array:
	var out: Array = []
	for event_v in logger.get_logs():
		out.append(str((event_v as Dictionary).get("type", "")))
	return out


# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_legacy_fallback_silent() -> Dictionary:
	var enemy_for_legacy: Dictionary = _enemy_actor("enemy.legacy", 0, 0)
	var enemy_for_fallback: Dictionary = _enemy_actor("enemy.fallback", 0, 0)
	var ally: Dictionary = _echo_actor("echo.witness", 5, 5)

	var logger_legacy := StructuredLogger.new()
	logger_legacy.set_level(StructuredLogger.LEVEL_DEBUG)
	var sm_legacy := ActorStateMachine.new(enemy_for_legacy)
	var context_legacy := { "actor": enemy_for_legacy, "all_actors": [ally], "t": 1 }
	sm_legacy.advance_turn(context_legacy, logger_legacy, 1)
	var types_legacy: Array = _logged_types(logger_legacy)

	var logger_fallback := StructuredLogger.new()
	logger_fallback.set_level(StructuredLogger.LEVEL_DEBUG)
	var sm_fallback := ActorStateMachine.new(enemy_for_fallback)
	# All four keys present (so ActorStateMachine even attempts select_movement_intent), but
	# movement_context is an empty dict, which fails MovementContext.validate()'s required-field
	# check trivially -> select_movement_intent() returns {"valid": false, ...}.
	var context_fallback := {
		"actor": enemy_for_fallback, "all_actors": [ally], "t": 1,
		"movement_context": {}, "movement_profile": {}, "movement_goals": [], "movement_options": [],
	}
	sm_fallback.advance_turn(context_fallback, logger_fallback, 1)
	var types_fallback: Array = _logged_types(logger_fallback)

	if JSON.stringify(types_legacy) != JSON.stringify(types_fallback):
		return { "ok": false, "error": "the movement-selection-failed fallback logged a different set of event types than the pure legacy path — the fallback branch is no longer silent:\n  legacy=%s\n  fallback=%s" % [JSON.stringify(types_legacy), JSON.stringify(types_fallback)] }
	return { "ok": true }


# ---------------------------------------------------------------------------
# 8 (task's fact 7) — health_ratio has two divergent ladders for the same input:
# BehaviorArbiter._hp_ratio() returns 1.0 when max_hp <= 0; LiveMovementContextService's
# per-actor fact builder returns 0.0 for the identical actor dict.
#
# FOCUSED unit-level calls into both real static/instance methods with the SAME actor dict —
# no full encounter needed; this is a pure function comparison.
# ---------------------------------------------------------------------------

# KNOWN DEFECT (V2-COMBAT-003 will change this):
static func _t_health_ratio_ladders_diverge() -> Dictionary:
	var actor: Dictionary = { "id": "actor.zero_max_hp", "stats": { "max_hp": 0 }, "current_hp": 50 }

	var arbiter_ratio: float = BehaviorArbiterScript._hp_ratio(actor)
	if not is_equal_approx(arbiter_ratio, 1.0):
		return { "ok": false, "error": "expected BehaviorArbiter._hp_ratio() to return 1.0 for max_hp<=0, got %s" % str(arbiter_ratio) }

	var flow_ctx := FlowContext.new()
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var live := LiveMovement.new(flow_ctx, logger)
	var facts: Array = live._movement_actor_facts([actor])
	if facts.is_empty():
		return { "ok": false, "error": "expected one perceived-actor fact back, got none" }
	var live_ratio: float = float((facts[0] as Dictionary).get("health_ratio", -1.0))
	if not is_equal_approx(live_ratio, 0.0):
		return { "ok": false, "error": "expected LiveMovementContextService's per-actor fact builder to return 0.0 for max_hp<=0, got %s" % str(live_ratio) }

	if is_equal_approx(arbiter_ratio, live_ratio):
		return { "ok": false, "error": "expected the two ladders to DIVERGE for the same actor dict (1.0 vs 0.0) — they agreed instead (%s == %s), so this defect no longer reproduces" % [str(arbiter_ratio), str(live_ratio)] }
	return { "ok": true }
