# res://tests/LiveMovementStyleTests.gd
# V2-COMBAT-003.5 Phase 3c — the LIVE per-turn movement-option producer.
#
# Every test drives the real production entry point
# (LiveMovementContextService.prepare_live_movement_context) and then the real
# BehaviorArbiter.select_movement_intent, with the production-shaped construction
# CombatRoundtripIntegrationTests._selection_census uses:
#   BehaviorArbiter.new(bdata["actor"], prepared["movement_cfg"]).
#
# Actor/board fixtures are reused from BehaviorCharacterizationTests (_echo_actor /
# _enemy_actor / _full_walkable / _real_bdata) rather than re-authored — that file owns
# the "raw actor dict for LiveMovementContextService" shape.

class_name LiveMovementStyleTests
extends RefCounted

const LiveMovement = preload("res://core/movement/LiveMovementContextService.gd")
const OptionService = preload("res://core/movement/MovementOptionService.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("live_movement_style/live_path_publishes_many_route_shapes", _t_many_route_shapes)
	runner.register_test("live_movement_style/direct_option_spatial_terms_unchanged", _t_direct_option_terms_unchanged)
	runner.register_test("live_movement_style/distinct_styles_reachable_live", _t_distinct_styles_reachable)
	runner.register_test("live_movement_style/arbiter_accepts_the_full_live_board", _t_arbiter_accepts_full_board)
	runner.register_test("live_movement_style/arbiter_option_cap_covers_every_route_shape", _t_option_cap_covers_producer)


# ---------------------------------------------------------------------------
# 1 — CHARACTERIZATION, assertion INVERTED by this phase.
#
# The recorded pre-change fact, measured on this same fixture: the live producer built
# exactly ONE option per goal, always route-shape "direct"
# (LiveMovementContextService._movement_build_direct_option, now deleted). With one
# candidate per goal, BehaviorArbiter's style-alignment term had nothing to
# differentiate, so every live turn published the same movement_style whatever the
# Echo's vectors, calling, fear or morale said.
#
# Inverted: the board must now carry more than one route-shape, which is the
# precondition for style to mean anything at all.
# ---------------------------------------------------------------------------
static func _t_many_route_shapes() -> Dictionary:
	var prepared: Dictionary = _prepared(_rich_fixture())
	if prepared.is_empty():
		return _fail("rich fixture produced no options")
	var styles: Array = _route_styles(prepared["options"] as Array)
	if styles.size() < 2:
		return _fail(
			"the live path published only %d route-shape(s) %s across %d option(s) — "
			% [styles.size(), str(styles), (prepared["options"] as Array).size()]
			+ "style alignment cannot differentiate a single-shape board"
		)
	if not styles.has("direct"):
		return _fail("the mechanical primary shape 'direct' vanished from the live board: %s" % str(styles))
	return _pass()


# ---------------------------------------------------------------------------
# 2 — REGRESSION GUARD for "never write a second implementation of a scoring term".
#
# Same two-actor fixture BehaviorCharacterizationTests._t_live_options_zero_spatial_terms
# pins, which still produces exactly one option. The pre-change live builder called
# MovementOptionService's own _exposure/_congestion/_cohesion/_hostile_sources/_hazard_ids;
# generate_options calls the identical helpers with the identical arguments, so every
# value must be unchanged: exposure 1.0, congestion 0.125, cohesion 0.0,
# hostile_control_sources ["enemy.near"], zero known hazards.
# ---------------------------------------------------------------------------
static func _t_direct_option_terms_unchanged() -> Dictionary:
	var prepared: Dictionary = _prepared(_simple_fixture())
	if prepared.is_empty():
		return _fail("simple fixture produced no options")
	var direct: Dictionary = {}
	for option_value: Variant in prepared["options"] as Array:
		var option: Dictionary = option_value as Dictionary
		if _route_style_of(option) == "direct":
			direct = option
			break
	if direct.is_empty():
		return _fail("no direct-shape option: %s" % str(_route_styles(prepared["options"] as Array)))
	if not is_equal_approx(float(direct["exposure"]), 1.0):
		return _fail("exposure moved: %f (was 1.0)" % float(direct["exposure"]))
	if not is_equal_approx(float(direct["congestion"]), 0.125):
		return _fail("congestion moved: %f (was 0.125)" % float(direct["congestion"]))
	if not is_equal_approx(float(direct["cohesion"]), 0.0):
		return _fail("cohesion moved: %f (was 0.0)" % float(direct["cohesion"]))
	if (direct["hostile_control_sources"] as Array) != ["enemy.near"]:
		return _fail("hostile_control_sources moved: %s (was ['enemy.near'])" % str(direct["hostile_control_sources"]))
	var hazards: Dictionary = direct["hazard_summary"] as Dictionary
	if int(hazards["known_count"]) != 0 or not (hazards["known_ids"] as Array).is_empty():
		return _fail("hazard_summary moved: %s (was 0 / [])" % str(hazards))
	return _pass()


# ---------------------------------------------------------------------------
# 3 — Two identities, one board, different published movement_style.
#
# Both movers stand on the same cell of the same board with the same goals and the
# same candidate set; only `vector_scores` differs, and the weights name a different
# route-shape per vector. Pre-Phase-3c this was unreachable by construction: a
# candidate cannot be out-scored by one that was never generated.
#
# Synthetic weights, not `data.actor.movement_style_weights`, so the test states the
# identity pull it depends on instead of breaking when the designer retunes balance.
# ---------------------------------------------------------------------------
static func _t_distinct_styles_reachable() -> Dictionary:
	var style_cfg: Dictionary = {
		"alignment_weight": 1.0,
		"vector_bias": {
			"synthetic_together": {"cohesive": 200.0},
			"synthetic_wary": {"careful": 200.0},
		},
	}
	var together: Dictionary = _select(_rich_fixture({"synthetic_together": 1.0}), style_cfg)
	var wary: Dictionary = _select(_rich_fixture({"synthetic_wary": 1.0}), style_cfg)
	if not bool(together.get("valid", false)):
		return _fail("cohesion-biased selection failed: %s" % str(together))
	if not bool(wary.get("valid", false)):
		return _fail("caution-biased selection failed: %s" % str(wary))
	var together_style: String = str((together["intent"] as Dictionary).get("movement_style", ""))
	var wary_style: String = str((wary["intent"] as Dictionary).get("movement_style", ""))
	if together_style == wary_style:
		return _fail(
			"both identities resolved to movement_style '%s' — the live board is not "
			% together_style
			+ "offering the shapes their vectors pull toward"
		)
	if together_style != "cohesive":
		return _fail("a cohesion-biased identity chose '%s', not 'cohesive'" % together_style)
	if wary_style != "careful":
		return _fail("a caution-biased identity chose '%s', not 'careful'" % wary_style)
	return _pass()


# ---------------------------------------------------------------------------
# 4 — The arbiter must ACCEPT the larger board, not discard it.
#
# `_validate_movement_inputs` rejects the WHOLE board — dropping the actor back to the
# legacy nearest-enemy selector — on `option_cap_exceeded`, `non_canonical_option_order`
# or `conflicting_duplicate_mechanics`. All three first become reachable when the live
# producer publishes more than one option per goal, and all three fail silently in play.
# ---------------------------------------------------------------------------
static func _t_arbiter_accepts_full_board() -> Dictionary:
	var selection: Dictionary = _select(_rich_fixture(), {})
	if not bool(selection.get("valid", false)):
		return _fail(
			"the arbiter discarded the live board: %s @ %s"
			% [str(selection.get("reason", "")), str(selection.get("field", ""))]
		)
	return _pass()


# ---------------------------------------------------------------------------
# 5 — Producer and consumer caps must not drift apart.
#
# MovementOptionService can emit one option per route-shape; the arbiter discards the
# whole board above its own per-goal cap. A consumer cap below the producer's is a
# silent, board-wide fallback waiting for the first busy board that reaches it — which
# is what the arbiter's literal `> 4` became when the generator's cap was raised.
# ---------------------------------------------------------------------------
static func _t_option_cap_covers_producer() -> Dictionary:
	var producer: int = (OptionService.STYLE_ORDER as Array).size()
	var consumer: int = (BehaviorArbiter._ROUTE_STYLE_ORDER as Array).size()
	if consumer < producer:
		return _fail(
			"the arbiter accepts at most %d options per goal but the generator can emit %d"
			% [consumer, producer]
		)
	return _pass()


# ---------------------------------------------------------------------------
# FIXTURES
# ---------------------------------------------------------------------------

## The two-actor board BehaviorCharacterizationTests fact 5 pins: an Echo at (0,1) two
## cells from its only hostile at (2,1) on an empty 10x10, so it must step into that
## enemy's control to strike. Still yields exactly one option.
static func _simple_fixture() -> Dictionary:
	return _build(
		BehaviorCharacterizationTests._echo_actor("echo.free", 0, 1),
		[BehaviorCharacterizationTests._enemy_actor("enemy.near", 2, 1)]
	)


## A board with room to express shape: capacity 4, a hostile far enough that the route
## is multi-step (so a shortened prefix is a real alternative), a second hostile placed
## to make one flank costlier than the other, and a living ally so `cohesion` varies
## between destinations.
static func _rich_fixture(vector_scores: Dictionary = {}) -> Dictionary:
	var mover: Dictionary = BehaviorCharacterizationTests._echo_actor("echo.free", 0, 5)
	mover["standing"] = 9
	mover["rank"] = 9
	(mover["stats"] as Dictionary)["agi"] = 20
	if not vector_scores.is_empty():
		mover["vector_scores"] = vector_scores.duplicate(true)
	return _build(mover, [
		BehaviorCharacterizationTests._enemy_actor("enemy.near", 6, 5),
		BehaviorCharacterizationTests._enemy_actor("enemy.flank", 4, 6),
		BehaviorCharacterizationTests._echo_actor("echo.ally", 2, 8),
	])


static func _build(mover: Dictionary, others: Array) -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.actors = [mover] + others
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.combat_state = {}
	ectx.purifier_id = ""

	var flow_ctx := FlowContext.new()
	flow_ctx.encounter_ctx = ectx

	var logger := StructuredLogger.new()
	logger.set_level("off")

	var bdata: Dictionary = BehaviorCharacterizationTests._real_bdata()
	var board_cfg: Dictionary = {
		"board_cols": 10, "board_rows": 10,
		"walkable": BehaviorCharacterizationTests._full_walkable(10, 10),
	}
	return {
		"mover": mover,
		"ectx": ectx,
		"bdata": bdata,
		"board_cfg": board_cfg,
		"prepared": LiveMovement.new(flow_ctx, logger).prepare_live_movement_context(
			mover, ectx, ectx.combat_state, board_cfg, bdata, 0),
	}


static func _prepared(fixture: Dictionary) -> Dictionary:
	var prepared: Dictionary = fixture["prepared"] as Dictionary
	if not bool(prepared.get("valid", false)) or (prepared["options"] as Array).is_empty():
		return {}
	return prepared


## The same construction CombatRoundtripIntegrationTests._selection_census uses.
## `style_cfg` overrides `movement_style_weights` only; everything else is real balance.
static func _select(fixture: Dictionary, style_cfg: Dictionary) -> Dictionary:
	var prepared: Dictionary = fixture["prepared"] as Dictionary
	if not bool(prepared.get("valid", false)):
		return {"valid": false, "reason": "preparation_invalid", "field": str(prepared)}
	if not bool(prepared.get("selection_enabled", false)):
		return {"valid": false, "reason": "selection_disabled", "field": ""}
	var actor_cfg: Dictionary = ((fixture["bdata"] as Dictionary).get("actor", {}) as Dictionary).duplicate(true)
	if not style_cfg.is_empty():
		actor_cfg["movement_style_weights"] = style_cfg
	var arbiter := BehaviorArbiter.new(actor_cfg, prepared.get("movement_cfg", {}) as Dictionary)
	return arbiter.select_movement_intent(
		{
			"actor": fixture["mover"],
			"all_actors": (fixture["ectx"] as EncounterContext).actors,
			"board_cfg": fixture["board_cfg"],
			"t": 0,
			"round": 0,
		},
		prepared["movement_context"],
		prepared["profile"],
		prepared["goals"],
		prepared["options"]
	)


## "option.<goal-suffix>.<style>.d<col>r<row>.p<path>" — the style token follows the
## goal's own five segments.
static func _route_style_of(option: Dictionary) -> String:
	var prefix: String = "option.%s." % str(option["goal_id"]).trim_prefix("goal.")
	return str(option["option_id"]).trim_prefix(prefix).get_slice(".", 0)


static func _route_styles(options: Array) -> Array:
	var styles: Array = []
	for option_value: Variant in options:
		var style: String = _route_style_of(option_value as Dictionary)
		if not styles.has(style):
			styles.append(style)
	styles.sort()
	return styles


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
