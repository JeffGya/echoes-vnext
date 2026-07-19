# res://tests/CombatActivationTests.gd
# V2-COMBAT-002 Slice 3 (DORMANT): CombatActivationService coordinator tests.
#
# Deterministic, hand-built boards / intents / action contexts. Proves the atomic
# movement + action activation: movement-then-action ordering, final-position action
# revalidation, purpose-restricted fallback, Unstable->Binding->action->Burning event
# ordering, once-per-activation Burning, mover KO/death truth, MovementResult.validate
# integration, deterministic replay, and no input mutation.

class_name CombatActivationTests
extends RefCounted

const Activation = preload("res://core/movement/CombatActivationService.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/activation/movement_then_action_valid_primary", Callable(CombatActivationTests, "_t_valid_primary"))
	runner.register_test("movement/activation/position_independent_action_always_valid", Callable(CombatActivationTests, "_t_position_independent"))
	runner.register_test("movement/activation/final_position_invalidates_primary_uses_fallback", Callable(CombatActivationTests, "_t_invalid_primary_fallback"))
	runner.register_test("movement/activation/custom_reach_revalidates_primary", Callable(CombatActivationTests, "_t_custom_reach_revalidation"))
	runner.register_test("movement/activation/purpose_disallows_fallback", Callable(CombatActivationTests, "_t_purpose_disallows_fallback"))
	runner.register_test("movement/activation/no_declared_fallback_invalidates", Callable(CombatActivationTests, "_t_no_fallback"))
	runner.register_test("movement/activation/unstable_binding_action_burning_order", Callable(CombatActivationTests, "_t_hazard_order"))
	runner.register_test("movement/activation/burning_once_after_action", Callable(CombatActivationTests, "_t_burning_after_action"))
	runner.register_test("movement/activation/killed_by_unstable_midmove_skips_action", Callable(CombatActivationTests, "_t_death_midmove"))
	runner.register_test("movement/activation/ko_by_burning_after_action", Callable(CombatActivationTests, "_t_ko_after_burning"))
	runner.register_test("movement/activation/result_passes_validate_rich_run", Callable(CombatActivationTests, "_t_result_validate"))
	runner.register_test("movement/activation/deterministic_replay", Callable(CombatActivationTests, "_t_deterministic_replay"))
	runner.register_test("movement/activation/no_input_mutation", Callable(CombatActivationTests, "_t_no_mutation"))


# --- fixtures / helpers ------------------------------------------------------

static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func _cfg() -> Dictionary:
	return {
		"types": ["unstable", "binding", "burning"],
		"unstable": {"displacement_cells": 1, "fallback_damage": 3},
		"binding": {"stops_movement": true},
		"burning": {"end_activation_damage": 3},
	}


static func _hazard_ctx(config: Dictionary = {}) -> Dictionary:
	return {"triggered": {"unstable": false, "binding": false, "burning": false}, "config": config}


static func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"origin": _cell(1, 1),
		"authoritative_walkable": {},
		"bounds": {"w": 10, "h": 10},
		"occupancy": {},
		"terrain_costs": {},
		"known_hazards": [],
		"perceived_actors": [],
		"relationships": {},
		"objective_pressure": {},
		"mover_id": "mover.1",
	}
	for key: Variant in overrides.keys():
		base[key] = overrides[key]
	return base


static func _intent(path: Array, commitment: int, planned: Dictionary, fallback: Dictionary = {}) -> Dictionary:
	return {
		"mover_id": "mover.1",
		"activation_id": "activation.1",
		"goal_id": "goal.1",
		"option_id": "option.1",
		"path": path,
		"commitment": commitment,
		"planned_action": planned,
		"fallback": fallback,
	}


static func _profile(capacity: int) -> Dictionary:
	return {"capacity": capacity}


static func _plan(action_type: String, target_id: String = "") -> Dictionary:
	return {"type": action_type, "target_id": target_id, "payload": {}}


static func _types(events: Array) -> Array:
	var out: Array = []
	for event_value: Variant in events:
		out.append(str((event_value as Dictionary).get("type", "")))
	return out


# --- tests -------------------------------------------------------------------

static func _t_valid_primary() -> Dictionary:
	# Move one cell east to (2,1); enemy target at (3,1) is adjacent (Chebyshev 1) to
	# the FINAL cell -> the melee primary stays valid -> resolved_action == planned.
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("melee_attack", "enemy.1"), _plan("actor.guard"))
	var action_ctx: Dictionary = {"purpose": "engage", "positions": {"enemy.1": _cell(3, 1)}}
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), action_ctx)
	if str(result["stop_reason"]) != "reached_destination":
		return _fail("expected reached_destination, got %s" % str(result["stop_reason"]))
	if (result["resolved_action"] as Dictionary) != _plan("melee_attack", "enemy.1"):
		return _fail("valid primary not resolved: %s" % str(result["resolved_action"]))
	if (result["planned_action"] as Dictionary) != _plan("melee_attack", "enemy.1"):
		return _fail("planned_action not recorded: %s" % str(result["planned_action"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("valid-primary result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


static func _t_position_independent() -> Dictionary:
	# actor.guard has an empty target -> position independent -> valid at any final cell.
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 4, _plan("actor.guard"), _plan("actor.idle"))
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), {"purpose": "hold"})
	if (result["resolved_action"] as Dictionary) != _plan("actor.guard"):
		return _fail("position-independent guard not resolved: %s" % str(result["resolved_action"]))
	if str(result["purpose"]) != "hold":
		return _fail("purpose passthrough wrong: %s" % str(result["purpose"]))
	return _pass()


static func _t_invalid_primary_fallback() -> Dictionary:
	# Final cell (2,1); target at (5,1) is out of melee reach -> primary invalid. Declared
	# fallback actor.guard is permitted for engage -> resolved_action == fallback.
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("melee_attack", "enemy.1"), _plan("actor.guard"))
	var action_ctx: Dictionary = {"purpose": "engage", "positions": {"enemy.1": _cell(5, 1)}}
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), action_ctx)
	if str(result["stop_reason"]) != "reached_destination":
		return _fail("fallback path changed movement stop: %s" % str(result["stop_reason"]))
	if (result["resolved_action"] as Dictionary) != _plan("actor.guard"):
		return _fail("permitted fallback not resolved: %s" % str(result["resolved_action"]))
	if (result["fallback"] as Dictionary) != _plan("actor.guard"):
		return _fail("declared fallback not recorded: %s" % str(result["fallback"]))
	return _pass()


static func _t_custom_reach_revalidation() -> Dictionary:
	# A ranged primary declares reach 3 via action_ctx.ranges. Move one cell east to the
	# FINAL cell (2,1); target at (5,1) is Chebyshev 3 -> WITHIN the custom reach -> the
	# primary is revalidated as VALID -> resolved_action == planned. (At the default reach
	# of 1 this same target would be invalid, so this exercises the ranges/default_range
	# lookup in _action_valid_at, not the reach-1 path.)
	var planned: Dictionary = _plan("ranged_attack", "enemy.1")
	var intent: Dictionary = _intent([_cell(2, 1)], 2, planned, {})
	var action_ctx: Dictionary = {
		"purpose": "engage",
		"positions": {"enemy.1": _cell(5, 1)},
		"ranges": {"ranged_attack": 3},
	}
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), action_ctx)
	if str(result["stop_reason"]) != "reached_destination":
		return _fail("custom-reach run changed movement stop: %s" % str(result["stop_reason"]))
	if (result["resolved_action"] as Dictionary) != planned:
		return _fail("in-reach ranged primary not revalidated as valid: %s" % str(result["resolved_action"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("custom-reach result rejected: %s" % str(ResultContract.validate(result)))
	# Companion: same target pushed to (6,1) -> Chebyshev 4 > reach 3 -> primary invalid.
	# With NO declared fallback -> action_invalid_no_fallback and no resolved action.
	var far_ctx: Dictionary = {
		"purpose": "engage",
		"positions": {"enemy.1": _cell(6, 1)},
		"ranges": {"ranged_attack": 3},
	}
	var far: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), far_ctx)
	if str(far["stop_reason"]) != "action_invalid_no_fallback":
		return _fail("beyond-reach primary not invalidated: %s" % str(far["stop_reason"]))
	if not (far["resolved_action"] as Dictionary).is_empty():
		return _fail("beyond-reach still resolved an action: %s" % str(far["resolved_action"]))
	return _pass()


static func _t_purpose_disallows_fallback() -> Dictionary:
	# advance purpose: primary actor.move to a far objective is invalid at the final cell,
	# and a melee_attack fallback is NOT permitted for advance -> action_invalid_no_fallback.
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("actor.move", "objective.a"), _plan("melee_attack", "enemy.1"))
	var action_ctx: Dictionary = {
		"purpose": "advance",
		"positions": {"objective.a": _cell(8, 1), "enemy.1": _cell(3, 1)},
	}
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), action_ctx)
	if str(result["stop_reason"]) != "action_invalid_no_fallback":
		return _fail("disallowed fallback not rejected: %s" % str(result["stop_reason"]))
	if not (result["resolved_action"] as Dictionary).is_empty():
		return _fail("disallowed fallback still resolved an action: %s" % str(result["resolved_action"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("action_invalid result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


static func _t_no_fallback() -> Dictionary:
	# Primary invalid (target out of reach) and NO declared fallback -> action_invalid_no_fallback.
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("melee_attack", "enemy.1"), {})
	var action_ctx: Dictionary = {"purpose": "engage", "positions": {"enemy.1": _cell(6, 1)}}
	var result: Dictionary = Activation.activate(_ctx(), intent, _profile(6), _hazard_ctx(), action_ctx)
	if str(result["stop_reason"]) != "action_invalid_no_fallback":
		return _fail("no-fallback primary failure not flagged: %s" % str(result["stop_reason"]))
	if not (result["resolved_action"] as Dictionary).is_empty():
		return _fail("no-fallback resolved a phantom action: %s" % str(result["resolved_action"]))
	return _pass()


static func _t_hazard_order() -> Dictionary:
	# Unstable at (2,1) displaces the mover east onto (3,1), which BINDS (movement stops);
	# the same cell also BURNS at end-activation. Event order must be:
	#   move.step -> hazard.unstable.displace -> hazard.binding.stop -> hazard.burning.end
	# with strictly-increasing contiguous seq, Burning appended AFTER the action.
	var ctx: Dictionary = _ctx({"known_hazards": [
		HazardFact.build("h.u", _cell(2, 1), "unstable"),
		HazardFact.build("h.b", _cell(3, 1), "binding"),
		HazardFact.build("h.f", _cell(3, 1), "burning"),
	]})
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 6, _plan("actor.guard"), _plan("actor.idle"))
	var result: Dictionary = Activation.activate(ctx, intent, _profile(6), _hazard_ctx(_cfg()), {"purpose": "hold"})
	var expected_types: Array = ["move.step", "hazard.unstable.displace", "hazard.binding.stop", "hazard.burning.end"]
	if _types(result["events"] as Array) != expected_types:
		return _fail("hazard/action event order wrong: %s" % str(_types(result["events"] as Array)))
	var seq: int = 0
	for event_value: Variant in result["events"] as Array:
		if int((event_value as Dictionary)["seq"]) != seq:
			return _fail("seq not contiguous at %d: %s" % [seq, str(event_value)])
		seq += 1
	if str(result["stop_reason"]) != "binding_stop":
		return _fail("expected binding_stop, got %s" % str(result["stop_reason"]))
	if (result["final_destination"] as Dictionary) != _cell(3, 1):
		return _fail("final destination wrong: %s" % str(result["final_destination"]))
	if int(result["forced_steps"]) != 1:
		return _fail("expected 1 forced step: %d" % int(result["forced_steps"]))
	if (result["hazards"] as Array).size() != 3:
		return _fail("expected 3 projected hazards: %s" % str(result["hazards"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("ordered hazard result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


static func _t_burning_after_action() -> Dictionary:
	# Burning at the final cell contributes exactly ONE end-activation event, appended
	# after the (resolved) action, and only once per activation.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.f", _cell(2, 1), "burning")]})
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("actor.guard"), _plan("actor.idle"))
	var result: Dictionary = Activation.activate(ctx, intent, _profile(6), _hazard_ctx(_cfg()), {"purpose": "hold"})
	var burns: int = 0
	for event_value: Variant in result["events"] as Array:
		if str((event_value as Dictionary).get("type", "")) == "hazard.burning.end":
			burns += 1
	if burns != 1:
		return _fail("expected exactly one burning event, got %d" % burns)
	var last: Dictionary = (result["events"] as Array).back() as Dictionary
	if str(last["type"]) != "hazard.burning.end":
		return _fail("burning not the final event (should follow the action): %s" % str(last))
	if (result["resolved_action"] as Dictionary) != _plan("actor.guard"):
		return _fail("action not resolved before burning: %s" % str(result["resolved_action"]))
	return _pass()


static func _t_death_midmove() -> Dictionary:
	# Unstable at the east edge (9,1) has no legal displacement cell -> fallback_damage 3.
	# With mover_hp 3 the mover is downed DURING movement -> action skipped, stop death.
	var ctx: Dictionary = _ctx({
		"origin": _cell(8, 1),
		"known_hazards": [HazardFact.build("h.u", _cell(9, 1), "unstable")],
	})
	var intent: Dictionary = _intent([_cell(9, 1)], 2, _plan("actor.guard"), _plan("actor.idle"))
	var action_ctx: Dictionary = {"purpose": "hold", "mover_hp": 3}
	var result: Dictionary = Activation.activate(ctx, intent, _profile(6), _hazard_ctx(_cfg()), action_ctx)
	if str(result["stop_reason"]) != "death":
		return _fail("mover not marked dead from unstable fallback: %s" % str(result["stop_reason"]))
	if not (result["resolved_action"] as Dictionary).is_empty():
		return _fail("action executed despite mid-move death: %s" % str(result["resolved_action"]))
	# No Burning was resolved (skipped when downed in movement) -> no burning event.
	for event_value: Variant in result["events"] as Array:
		if str((event_value as Dictionary).get("type", "")) == "hazard.burning.end":
			return _fail("burning resolved despite mid-move death")
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("death result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


static func _t_ko_after_burning() -> Dictionary:
	# Mover survives movement, resolves its action, then Burning (3) downs it. With
	# mover_ko_only the downed outcome is "ko" (not "death"), and the action still resolved.
	var ctx: Dictionary = _ctx({"known_hazards": [HazardFact.build("h.f", _cell(2, 1), "burning")]})
	var intent: Dictionary = _intent([_cell(2, 1)], 2, _plan("actor.guard"), _plan("actor.idle"))
	var action_ctx: Dictionary = {"purpose": "hold", "mover_hp": 3, "mover_ko_only": true}
	var result: Dictionary = Activation.activate(ctx, intent, _profile(6), _hazard_ctx(_cfg()), action_ctx)
	if str(result["stop_reason"]) != "ko":
		return _fail("burning down did not report ko: %s" % str(result["stop_reason"]))
	if (result["resolved_action"] as Dictionary) != _plan("actor.guard"):
		return _fail("action not resolved before burning ko: %s" % str(result["resolved_action"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("ko result rejected: %s" % str(ResultContract.validate(result)))
	return _pass()


static func _t_result_validate() -> Dictionary:
	# Rich run: hostile surcharge + unstable displacement + burning at the end, with a
	# valid targeted primary. The assembled MovementResult must pass the authoritative
	# contract (traversal / forced / hazards / seq contiguity all cross-checked).
	var ctx: Dictionary = _ctx({
		"perceived_actors": [{"id": "enemy.a", "position": _cell(2, 0), "is_dead": false, "is_ko": false, "is_structure": false, "controlling_state": true}],
		"relationships": {"enemy.a": "hostile"},
		"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable"), HazardFact.build("h.f", _cell(4, 1), "burning")],
	})
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 6, _plan("melee_attack", "enemy.a"), _plan("actor.guard"))
	var action_ctx: Dictionary = {"purpose": "engage", "positions": {"enemy.a": _cell(4, 1)}, "objective_progress": 0.5}
	var result: Dictionary = Activation.activate(ctx, intent, _profile(6), _hazard_ctx(_cfg()), action_ctx)
	var validated: Dictionary = ResultContract.validate(result)
	if not bool(validated["valid"]):
		return _fail("rich activation result rejected: %s (%s)" % [str(validated), str(result)])
	# Unstable displaced east onto (4,1) -> that IS the burning cell -> mover in melee reach.
	if (result["final_destination"] as Dictionary) != _cell(4, 1):
		return _fail("expected displaced final (4,1): %s" % str(result["final_destination"]))
	if (result["resolved_action"] as Dictionary) != _plan("melee_attack", "enemy.a"):
		return _fail("targeted primary not resolved at displaced cell: %s" % str(result["resolved_action"]))
	if (result["hostile_constraints"] as Dictionary) != {"hostile_control_sources": ["enemy.a"]}:
		return _fail("hostile_constraints not wrapped into dict shape: %s" % str(result["hostile_constraints"]))
	if abs(float(result["objective_progress"]) - 0.5) > 0.000001:
		return _fail("objective_progress passthrough wrong: %s" % str(result["objective_progress"]))
	return _pass()


static func _t_deterministic_replay() -> Dictionary:
	var make: Callable = func() -> Array:
		var ctx: Dictionary = _ctx({
			"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable"), HazardFact.build("h.f", _cell(4, 1), "burning")],
			"terrain_costs": {"2,1": 2},
		})
		var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 6, _plan("actor.guard"), _plan("actor.idle"))
		return [ctx, intent]
	var a: Array = make.call()
	var b: Array = make.call()
	var out_a: Dictionary = Activation.activate(a[0], a[1], _profile(6), _hazard_ctx(_cfg()), {"purpose": "hold"})
	var out_b: Dictionary = Activation.activate(b[0], b[1], _profile(6), _hazard_ctx(_cfg()), {"purpose": "hold"})
	if out_a != out_b:
		return _fail("identical inputs produced different activations")
	return _pass()


static func _t_no_mutation() -> Dictionary:
	var ctx: Dictionary = _ctx({
		"perceived_actors": [{"id": "enemy.a", "position": _cell(2, 0), "is_dead": false, "is_ko": false, "is_structure": false, "controlling_state": true}],
		"relationships": {"enemy.a": "hostile"},
		"known_hazards": [HazardFact.build("h.u", _cell(3, 1), "unstable"), HazardFact.build("h.f", _cell(4, 1), "burning")],
	})
	var intent: Dictionary = _intent([_cell(2, 1), _cell(3, 1)], 6, _plan("melee_attack", "enemy.a"), _plan("actor.guard"))
	var profile: Dictionary = _profile(6)
	var hazard_ctx: Dictionary = _hazard_ctx(_cfg())
	var action_ctx: Dictionary = {"purpose": "engage", "positions": {"enemy.a": _cell(4, 1)}}
	var ctx_before: Dictionary = ctx.duplicate(true)
	var intent_before: Dictionary = intent.duplicate(true)
	var profile_before: Dictionary = profile.duplicate(true)
	var hazard_before: Dictionary = hazard_ctx.duplicate(true)
	var action_before: Dictionary = action_ctx.duplicate(true)
	Activation.activate(ctx, intent, profile, hazard_ctx, action_ctx)
	if ctx != ctx_before:
		return _fail("activate mutated context")
	if intent != intent_before:
		return _fail("activate mutated intent")
	if profile != profile_before:
		return _fail("activate mutated profile")
	if hazard_ctx != hazard_before:
		return _fail("activate mutated hazard_ctx")
	if action_ctx != action_before:
		return _fail("activate mutated action_ctx")
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
