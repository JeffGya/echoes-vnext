# res://tests/ProtectCustodyTests.gd
# V2-COMBAT-002 Slice 4 (Unit C): PROTECT totem carry/custody tests.
#
# Deterministic, hand-built boards / custody states / configs. No RNG (theft rolls
# are injected). Proves the six frozen custody rules: pickup-as-the-activation's-
# primary-action (and that it precludes attacking), the totem following the carrier
# across voluntary AND forced (hazard-displacement) steps, the -1 carrier burden and
# its MovementProfile floor, attack-triggered theft (and that cell entry never
# transfers), the enemy-carrier restriction + double damage, and the drop/recovery
# cell. Also proves the service holds NO objective authority, replays deterministically,
# and never mutates its inputs.

class_name ProtectCustodyTests
extends RefCounted

const Custody = preload("res://core/movement/ProtectCustodyService.gd")
const ActivationService = preload("res://core/movement/CombatActivationService.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const HazardFixtures = preload("res://core/movement/MovementHazardFixtures.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/protect_custody/pickup_is_the_activation_action", Callable(ProtectCustodyTests, "_t_pickup_is_action"))
	runner.register_test("movement/protect_custody/pickup_precludes_attacking", Callable(ProtectCustodyTests, "_t_pickup_precludes_attack"))
	runner.register_test("movement/protect_custody/attack_action_never_picks_up", Callable(ProtectCustodyTests, "_t_attack_action_no_pickup"))
	runner.register_test("movement/protect_custody/pickup_out_of_range_fails", Callable(ProtectCustodyTests, "_t_pickup_out_of_range"))
	runner.register_test("movement/protect_custody/pickup_costs_no_movement_capacity", Callable(ProtectCustodyTests, "_t_pickup_no_capacity_cost"))
	runner.register_test("movement/protect_custody/pickup_of_carried_totem_rejected", Callable(ProtectCustodyTests, "_t_pickup_already_carried"))
	runner.register_test("movement/protect_custody/totem_follows_every_voluntary_step", Callable(ProtectCustodyTests, "_t_follows_voluntary"))
	runner.register_test("movement/protect_custody/totem_follows_forced_hazard_step", Callable(ProtectCustodyTests, "_t_follows_forced"))
	runner.register_test("movement/protect_custody/totem_ignores_non_carrier_movement", Callable(ProtectCustodyTests, "_t_ignores_non_carrier"))
	runner.register_test("movement/protect_custody/burden_reduces_capacity_by_one", Callable(ProtectCustodyTests, "_t_burden_minus_one"))
	runner.register_test("movement/protect_custody/burden_respects_profile_floor", Callable(ProtectCustodyTests, "_t_burden_floor"))
	runner.register_test("movement/protect_custody/burden_absorbed_at_capacity_one", Callable(ProtectCustodyTests, "_t_burden_absorbed"))
	runner.register_test("movement/protect_custody/burden_skips_non_carriers", Callable(ProtectCustodyTests, "_t_burden_non_carrier"))
	runner.register_test("movement/protect_custody/enemy_carrier_capacity_cap", Callable(ProtectCustodyTests, "_t_enemy_capacity_cap"))
	runner.register_test("movement/protect_custody/theft_transfers_on_successful_attack", Callable(ProtectCustodyTests, "_t_theft_on_attack"))
	runner.register_test("movement/protect_custody/theft_requires_hit_and_roll", Callable(ProtectCustodyTests, "_t_theft_gates"))
	runner.register_test("movement/protect_custody/cell_entry_never_transfers_custody", Callable(ProtectCustodyTests, "_t_entry_no_transfer"))
	runner.register_test("movement/protect_custody/enemy_carrier_restrictions_and_double_damage", Callable(ProtectCustodyTests, "_t_enemy_restrictions"))
	runner.register_test("movement/protect_custody/drop_cell_is_carrier_current_cell", Callable(ProtectCustodyTests, "_t_drop_cell"))
	runner.register_test("movement/protect_custody/recovery_via_pickup_after_drop", Callable(ProtectCustodyTests, "_t_recovery_after_drop"))
	runner.register_test("movement/protect_custody/hazards_resolve_while_carrying", Callable(ProtectCustodyTests, "_t_hazards_while_carrying"))
	runner.register_test("movement/protect_custody/makes_no_objective_decision", Callable(ProtectCustodyTests, "_t_no_objective_authority"))
	runner.register_test("movement/protect_custody/deterministic_replay", Callable(ProtectCustodyTests, "_t_deterministic_replay"))
	runner.register_test("movement/protect_custody/no_input_mutation", Callable(ProtectCustodyTests, "_t_no_mutation"))


# ---------------------------------------------------------------------------
# FIXTURES
# ---------------------------------------------------------------------------

static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


## data.combat.objective_modes.protect (the keys this service reads).
static func _protect_cfg(overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = {
		"theft_chance": 0.5,
		"double_damage_mult": 2.0,
		"carry_capacity_penalty": 1,
		"pickup_range": 1,
		"enemy_carrier_capacity_cap": 1,
		"enemy_carrier_movement_restricted": true,
		"enemy_carrier_action_restricted": true,
	}
	for key: Variant in overrides.keys():
		cfg[key] = overrides[key]
	return cfg


static func _profile(capacity: int, actor_kind: String = "echo", authored_override: Dictionary = {}) -> Dictionary:
	return ProfileContract.build(
		capacity,
		[{"source": "standing_band", "capacity": capacity}],
		actor_kind != "structure",
		actor_kind,
		authored_override
	)


static func _hazard_cfg() -> Dictionary:
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
		"mover_id": "echo.1",
	}
	for key: Variant in overrides.keys():
		base[key] = overrides[key]
	return base


## An activation carrying a declared primary action along `path`.
static func _activate(
	context: Dictionary,
	path: Array,
	planned_action: Dictionary,
	profile: Dictionary,
	action_ctx: Dictionary = {},
	hazard_ctx: Dictionary = {}
) -> Dictionary:
	var intent: Dictionary = IntentContract.build(
		str(context.get("mover_id", "echo.1")),
		"protect.activation",
		"goal.custody.protect",
		"option.custody",
		path,
		int(profile.get("capacity", 1)),
		path.size(),
		planned_action,
		{},
		[]
	)
	var merged_ctx: Dictionary = {"purpose": "protect", "objective_progress": 0.0}
	for key: Variant in action_ctx.keys():
		merged_ctx[key] = action_ctx[key]
	return ActivationService.activate(
		context, intent, profile, hazard_ctx if not hazard_ctx.is_empty() else _hazard_ctx(), merged_ctx
	)


## An uncarried totem on the ground at `cell`.
static func _grounded(cell: Dictionary) -> Dictionary:
	return Custody.new_state("totem.1", cell)


## The totem carried by `carrier_id` of `faction`, standing at `cell`.
static func _carried(cell: Dictionary, carrier_id: String, faction: String) -> Dictionary:
	return Custody.new_state("totem.1", cell, carrier_id, faction)


# ---------------------------------------------------------------------------
# RULE 1 — PICKUP IS THE ACTIVATION'S PRIMARY ACTION
# ---------------------------------------------------------------------------

## The echo moves, then picks up: custody transfers, the totem lands on the mover's
## final cell, and the pickup was the activation's single resolved primary action.
static func _t_pickup_is_action() -> Dictionary:
	var state: Dictionary = _grounded(_cell(4, 1))
	var cfg: Dictionary = _protect_cfg()
	var result: Dictionary = _activate(
		_ctx(),
		[_cell(2, 1), _cell(3, 1)],
		Custody.pickup_action_plan("totem.1"),
		_profile(4),
		Custody.pickup_action_ctx(state, cfg)
	)
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("activation result rejected: %s" % str(ResultContract.validate(result)))
	if str((result["resolved_action"] as Dictionary).get("type", "")) != Custody.ACTION_PICKUP:
		return _fail("pickup did not resolve as the primary action: %s" % str(result["resolved_action"]))

	var report: Dictionary = Custody.resolve_pickup(state, result, cfg)
	if not bool(report["picked_up"]):
		return _fail("pickup failed: %s" % str(report["reason"]))
	if not bool(report["action_consumed"]):
		return _fail("pickup did not consume the activation's primary action")
	var after: Dictionary = report["custody_state"] as Dictionary
	if str(after["carrier_id"]) != "echo.1":
		return _fail("custody did not transfer to the mover: %s" % str(after))
	if (after["totem_cell"] as Dictionary) != _cell(3, 1):
		return _fail("totem did not land on the carrier's cell: %s" % str(after["totem_cell"]))
	return _pass()


## Declaring the pickup means the mover does NOT attack this activation — and a
## melee attack that IS resolved never precludes.
static func _t_pickup_precludes_attack() -> Dictionary:
	var state: Dictionary = _grounded(_cell(3, 1))
	var cfg: Dictionary = _protect_cfg()
	var pickup: Dictionary = _activate(
		_ctx(), [_cell(2, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
		Custody.pickup_action_ctx(state, cfg)
	)
	if not Custody.precludes_attack(pickup):
		return _fail("pickup activation should preclude attacking")
	if not bool(Custody.resolve_pickup(state, pickup, cfg)["attack_precluded"]):
		return _fail("resolve_pickup should report attack_precluded")

	var attack: Dictionary = _activate(
		_ctx(), [_cell(2, 1)], ActionPlan.build("melee_attack", "enemy.1"), _profile(4),
		{"positions": {"enemy.1": _cell(3, 1)}}
	)
	if str((attack["resolved_action"] as Dictionary).get("type", "")) != "melee_attack":
		return _fail("melee attack did not resolve: %s" % str(attack["resolved_action"]))
	if Custody.precludes_attack(attack):
		return _fail("an attacking activation must not report a precluded attack")
	return _pass()


## An activation whose primary action is an attack never picks the totem up, even
## when the mover ends its move right beside it.
static func _t_attack_action_no_pickup() -> Dictionary:
	var state: Dictionary = _grounded(_cell(3, 1))
	var cfg: Dictionary = _protect_cfg()
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1)], ActionPlan.build("melee_attack", "enemy.1"), _profile(4),
		{"positions": {"enemy.1": _cell(3, 1)}}
	)
	var report: Dictionary = Custody.resolve_pickup(state, result, cfg)
	if bool(report["picked_up"]):
		return _fail("an attack activation picked the totem up")
	if str(report["reason"]) != "not_pickup_action":
		return _fail("unexpected reason: %s" % str(report["reason"]))
	if bool(report["attack_precluded"]):
		return _fail("an attack activation must not preclude attacking")
	if (report["custody_state"] as Dictionary) != state:
		return _fail("custody changed on a non-pickup activation")
	return _pass()


## The pickup is revalidated at the mover's FINAL cell: out of pickup_range, the
## action cannot resolve and custody stays put.
static func _t_pickup_out_of_range() -> Dictionary:
	var state: Dictionary = _grounded(_cell(8, 8))
	var cfg: Dictionary = _protect_cfg()
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
		Custody.pickup_action_ctx(state, cfg)
	)
	# CombatActivationService already invalidates it at the final cell...
	if not (result["resolved_action"] as Dictionary).is_empty():
		return _fail("out-of-range pickup should not resolve: %s" % str(result["resolved_action"]))
	if str(result["stop_reason"]) != "action_invalid_no_fallback":
		return _fail("expected action_invalid_no_fallback, got %s" % str(result["stop_reason"]))
	# ...and the custody service independently refuses it.
	var forced: Dictionary = result.duplicate(true)
	forced["resolved_action"] = Custody.pickup_action_plan("totem.1")
	var report: Dictionary = Custody.resolve_pickup(state, forced, cfg)
	if bool(report["picked_up"]):
		return _fail("pickup succeeded out of range")
	if str(report["reason"]) != "out_of_range":
		return _fail("unexpected reason: %s" % str(report["reason"]))
	return _pass()


## The action economy is unchanged: the pickup costs NO movement capacity beyond
## the movement the mover already spent.
static func _t_pickup_no_capacity_cost() -> Dictionary:
	var state: Dictionary = _grounded(_cell(4, 1))
	var cfg: Dictionary = _protect_cfg()
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1), _cell(3, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
		Custody.pickup_action_ctx(state, cfg)
	)
	if int(result["voluntary_cost"]) != 2 or int(result["remaining_capacity"]) != 2:
		return _fail("movement cost changed: cost=%d remaining=%d" % [
			int(result["voluntary_cost"]), int(result["remaining_capacity"])])
	var report: Dictionary = Custody.resolve_pickup(state, result, cfg)
	if int(report["capacity_cost"]) != 0:
		return _fail("pickup charged capacity: %d" % int(report["capacity_cost"]))
	return _pass()


## A totem already in someone's hands cannot be picked up off the ground.
static func _t_pickup_already_carried() -> Dictionary:
	var state: Dictionary = _carried(_cell(3, 1), "enemy.9", "enemy")
	var cfg: Dictionary = _protect_cfg()
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
		Custody.pickup_action_ctx(state, cfg)
	)
	var report: Dictionary = Custody.resolve_pickup(state, result, cfg)
	if bool(report["picked_up"]):
		return _fail("picked up a carried totem")
	if str(report["reason"]) != "already_carried":
		return _fail("unexpected reason: %s" % str(report["reason"]))
	if str((report["custody_state"] as Dictionary)["carrier_id"]) != "enemy.9":
		return _fail("carrier changed on a rejected pickup")
	return _pass()


# ---------------------------------------------------------------------------
# RULE 2 — THE TOTEM FOLLOWS THE CARRIER AFTER EVERY STEP
# ---------------------------------------------------------------------------

## Multi-step voluntary path: the totem occupies every traversed cell in order and
## ends on the carrier's final cell.
static func _t_follows_voluntary() -> Dictionary:
	var state: Dictionary = _carried(_cell(1, 1), "echo.1", "echo")
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1), _cell(3, 1), _cell(4, 1)], ActionPlan.build("actor.guard"), _profile(4)
	)
	var report: Dictionary = Custody.track_carrier_movement(state, result)
	if not bool(report["followed"]):
		return _fail("totem did not follow: %s" % str(report["reason"]))
	if (report["totem_path"] as Array) != (result["actual_traversed_cells"] as Array):
		return _fail("totem path diverged from the carrier's traversal: %s vs %s" % [
			str(report["totem_path"]), str(result["actual_traversed_cells"])])
	if int(report["steps_followed"]) != 3:
		return _fail("expected 3 followed steps, got %d" % int(report["steps_followed"]))
	if ((report["custody_state"] as Dictionary)["totem_cell"] as Dictionary) \
			!= (result["final_destination"] as Dictionary):
		return _fail("totem did not end on the carrier's final cell")
	return _pass()


## FORCED steps count too: an Unstable hazard displaces the carrier mid-path and the
## totem tracks that displacement cell-by-cell — never left behind.
static func _t_follows_forced() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(2, 5),
		"bounds": HazardFixtures.board_bounds(),
		"known_hazards": HazardFixtures.unstable_at(_cell(3, 5)),
	})
	var state: Dictionary = _carried(_cell(2, 5), "echo.1", "echo")
	var result: Dictionary = _activate(
		context, [_cell(3, 5), _cell(4, 5)], ActionPlan.build("actor.guard"), _profile(4),
		{}, _hazard_ctx(_hazard_cfg())
	)
	if int(result["forced_steps"]) < 1:
		return _fail("fixture produced no forced step: %s" % str(result["events"]))

	var report: Dictionary = Custody.track_carrier_movement(state, result)
	if not bool(report["followed"]):
		return _fail("totem did not follow through the hazard: %s" % str(report["reason"]))
	# actual_traversed_cells interleaves voluntary and forced steps chronologically —
	# mirroring it IS the ordered custody contract.
	if (report["totem_path"] as Array) != (result["actual_traversed_cells"] as Array):
		return _fail("totem path skipped the forced step: %s vs %s" % [
			str(report["totem_path"]), str(result["actual_traversed_cells"])])
	if int(report["forced_steps"]) != int(result["forced_steps"]):
		return _fail("forced-step count not reported")
	if ((report["custody_state"] as Dictionary)["totem_cell"] as Dictionary) \
			!= (result["final_destination"] as Dictionary):
		return _fail("totem did not end where the displaced carrier ended")
	return _pass()


## Somebody else's activation never drags the totem, and an uncarried totem stays put.
static func _t_ignores_non_carrier() -> Dictionary:
	var carried: Dictionary = _carried(_cell(1, 1), "echo.1", "echo")
	var result: Dictionary = _activate(
		_ctx({"mover_id": "echo.2"}), [_cell(2, 1)], ActionPlan.build("actor.guard"), _profile(4)
	)
	var report: Dictionary = Custody.track_carrier_movement(carried, result)
	if bool(report["followed"]) or str(report["reason"]) != "not_the_carrier":
		return _fail("a non-carrier moved the totem: %s" % str(report))
	if (report["custody_state"] as Dictionary) != carried:
		return _fail("custody changed on a non-carrier activation")

	var grounded: Dictionary = _grounded(_cell(5, 5))
	var grounded_report: Dictionary = Custody.track_carrier_movement(
		grounded,
		_activate(_ctx(), [_cell(2, 1)], ActionPlan.build("actor.guard"), _profile(4))
	)
	if bool(grounded_report["followed"]) or str(grounded_report["reason"]) != "not_carried":
		return _fail("a grounded totem followed a mover: %s" % str(grounded_report))
	if ((grounded_report["custody_state"] as Dictionary)["totem_cell"] as Dictionary) != _cell(5, 5):
		return _fail("grounded totem moved")
	return _pass()


# ---------------------------------------------------------------------------
# RULE 3 — CARRIER BURDEN
# ---------------------------------------------------------------------------

## Exactly -1 capacity while carrying; the resulting profile is still valid and the
## base profile is untouched (the burden is per-activation, never persisted).
static func _t_burden_minus_one() -> Dictionary:
	var base: Dictionary = _profile(4)
	var base_before: Dictionary = base.duplicate(true)
	var state: Dictionary = _carried(_cell(1, 1), "echo.1", "echo")
	var report: Dictionary = Custody.apply_carrier_burden(base, state, "echo.1", _protect_cfg())

	if int((report["profile"] as Dictionary)["capacity"]) != 3:
		return _fail("expected capacity 3, got %d" % int((report["profile"] as Dictionary)["capacity"]))
	if int(report["applied"]) != 1:
		return _fail("expected applied 1, got %d" % int(report["applied"]))
	if bool(report["floored"]):
		return _fail("capacity 4 should not have floored")
	if not bool(ProfileContract.validate(report["profile"] as Dictionary)["valid"]):
		return _fail("burdened profile rejected: %s" % str(ProfileContract.validate(report["profile"] as Dictionary)))
	if base != base_before:
		return _fail("base profile was mutated (burden must not persist)")
	return _pass()


## The MovementProfile floor: a non-structure mover may never reach capacity 0, and
## capacity 1 requires an authored_override — so the burden stamps one.
static func _t_burden_floor() -> Dictionary:
	var report: Dictionary = Custody.apply_carrier_burden(
		_profile(2), _carried(_cell(1, 1), "echo.1", "echo"), "echo.1", _protect_cfg()
	)
	var profile: Dictionary = report["profile"] as Dictionary
	if int(profile["capacity"]) != Custody.MIN_CARRIER_CAPACITY:
		return _fail("expected floor capacity 1, got %d" % int(profile["capacity"]))
	var override: Dictionary = profile["authored_override"] as Dictionary
	if override.is_empty():
		return _fail("capacity 1 without an authored_override is an invalid profile")
	if str(override.get("source", "")) != Custody.SOURCE_BURDEN or int(override.get("capacity", 0)) != 1:
		return _fail("unexpected authored_override: %s" % str(override))
	if not bool(ProfileContract.validate(profile)["valid"]):
		return _fail("floored profile rejected: %s" % str(ProfileContract.validate(profile)))

	# A structure can never be a carrier — its intrinsic capacity 0 is inviolable.
	var structure: Dictionary = Custody.apply_carrier_burden(
		_profile(0, "structure"), _carried(_cell(1, 1), "totem.2", "echo"), "totem.2", _protect_cfg()
	)
	if int((structure["profile"] as Dictionary)["capacity"]) != 0:
		return _fail("structure capacity was altered")
	if not bool(ProfileContract.validate(structure["profile"] as Dictionary)["valid"]):
		return _fail("structure profile rejected")
	return _pass()


## A profile already at the floor (authored capacity 1) absorbs the burden: it stays
## valid at 1 and reports applied 0 / floored true rather than sliding to 0.
static func _t_burden_absorbed() -> Dictionary:
	var base: Dictionary = _profile(1, "npc", {"source": "guide_spirit_nonjoining", "capacity": 1})
	var report: Dictionary = Custody.apply_carrier_burden(
		base, _carried(_cell(1, 1), "npc.1", "echo"), "npc.1", _protect_cfg()
	)
	var profile: Dictionary = report["profile"] as Dictionary
	if int(profile["capacity"]) != 1:
		return _fail("absorbed burden changed capacity: %d" % int(profile["capacity"]))
	if int(report["applied"]) != 0 or not bool(report["floored"]):
		return _fail("expected applied 0 + floored true, got %s" % str(report))
	if str((profile["authored_override"] as Dictionary).get("source", "")) != "guide_spirit_nonjoining":
		return _fail("authored source was overwritten: %s" % str(profile["authored_override"]))
	if not bool(ProfileContract.validate(profile)["valid"]):
		return _fail("absorbed profile rejected")
	return _pass()


## Non-carriers pay nothing.
static func _t_burden_non_carrier() -> Dictionary:
	var base: Dictionary = _profile(4)
	var carried_by_other: Dictionary = Custody.apply_carrier_burden(
		base, _carried(_cell(1, 1), "echo.2", "echo"), "echo.1", _protect_cfg()
	)
	if int((carried_by_other["profile"] as Dictionary)["capacity"]) != 4:
		return _fail("a non-carrier was burdened")
	if bool(carried_by_other["is_carrier"]):
		return _fail("non-carrier reported as carrier")

	var grounded: Dictionary = Custody.apply_carrier_burden(
		base, _grounded(_cell(5, 5)), "echo.1", _protect_cfg()
	)
	if int((grounded["profile"] as Dictionary)["capacity"]) != 4:
		return _fail("burden applied with no carrier at all")
	return _pass()


## Rule 5's movement restriction expressed as a real capacity cap on the enemy carrier.
static func _t_enemy_capacity_cap() -> Dictionary:
	var state: Dictionary = _carried(_cell(1, 1), "enemy.1", "enemy")
	var report: Dictionary = Custody.apply_carrier_burden(_profile(5, "enemy"), state, "enemy.1", _protect_cfg())
	var profile: Dictionary = report["profile"] as Dictionary
	if int(profile["capacity"]) != 1:
		return _fail("enemy carrier not capped to 1, got %d" % int(profile["capacity"]))
	if not bool(report["enemy_capped"]):
		return _fail("enemy cap not reported")
	if not bool(ProfileContract.validate(profile)["valid"]):
		return _fail("capped enemy profile rejected: %s" % str(ProfileContract.validate(profile)))

	# With the restriction disabled, only the ordinary -1 burden applies.
	var unrestricted: Dictionary = Custody.apply_carrier_burden(
		_profile(5, "enemy"), state, "enemy.1",
		_protect_cfg({"enemy_carrier_movement_restricted": false})
	)
	if int((unrestricted["profile"] as Dictionary)["capacity"]) != 4:
		return _fail("unrestricted enemy carrier should be 4, got %d" % int((unrestricted["profile"] as Dictionary)["capacity"]))
	return _pass()


# ---------------------------------------------------------------------------
# RULE 4 — THEFT IS ATTACK-TRIGGERED
# ---------------------------------------------------------------------------

## A successful enemy attack on the carrier transfers custody, and the totem moves
## to the new carrier's cell.
static func _t_theft_on_attack() -> Dictionary:
	var state: Dictionary = _carried(_cell(3, 3), "echo.1", "echo")
	var report: Dictionary = Custody.resolve_theft_on_attack(state, {
		"attacker_id": "enemy.1",
		"attacker_faction": "enemy",
		"attacker_cell": _cell(4, 3),
		"defender_id": "echo.1",
		"hit": true,
		"roll": 0.1,
	}, _protect_cfg())
	if not bool(report["stolen"]):
		return _fail("theft did not trigger: %s" % str(report["reason"]))
	var after: Dictionary = report["custody_state"] as Dictionary
	if str(after["carrier_id"]) != "enemy.1" or str(after["carrier_faction"]) != "enemy":
		return _fail("custody did not transfer to the attacker: %s" % str(after))
	if (after["totem_cell"] as Dictionary) != _cell(4, 3):
		return _fail("totem did not move to the new carrier's cell: %s" % str(after["totem_cell"]))
	if str(state["carrier_id"]) != "echo.1":
		return _fail("input custody state was mutated by the theft")
	return _pass()


## Every gate on the pre-existing theft_chance semantics: a miss, a wrong defender,
## a same-faction attacker and a failed roll all leave custody untouched.
static func _t_theft_gates() -> Dictionary:
	var state: Dictionary = _carried(_cell(3, 3), "echo.1", "echo")
	var cfg: Dictionary = _protect_cfg()
	var base: Dictionary = {
		"attacker_id": "enemy.1",
		"attacker_faction": "enemy",
		"attacker_cell": _cell(4, 3),
		"defender_id": "echo.1",
		"hit": true,
		"roll": 0.1,
	}
	var cases: Array = [
		[{"hit": false}, "attack_missed"],
		[{"defender_id": "echo.2"}, "defender_not_carrier"],
		[{"attacker_faction": "echo"}, "same_faction"],
		# roll == theft_chance is a MISS (strict <), matching the live `randf() < chance`.
		[{"roll": 0.5}, "roll_failed"],
		[{"roll": 0.9}, "roll_failed"],
	]
	for case_value: Variant in cases:
		var case: Array = case_value as Array
		var attack: Dictionary = base.duplicate(true)
		for key: Variant in (case[0] as Dictionary).keys():
			attack[key] = (case[0] as Dictionary)[key]
		var report: Dictionary = Custody.resolve_theft_on_attack(state, attack, cfg)
		if bool(report["stolen"]):
			return _fail("theft triggered for %s" % str(case[0]))
		if str(report["reason"]) != str(case[1]):
			return _fail("expected reason %s, got %s" % [str(case[1]), str(report["reason"])])
		if (report["custody_state"] as Dictionary) != state:
			return _fail("custody changed on a failed theft: %s" % str(case[0]))

	# An uncarried totem cannot be stolen by an attack at all.
	var grounded: Dictionary = Custody.resolve_theft_on_attack(_grounded(_cell(3, 3)), base, cfg)
	if bool(grounded["stolen"]) or str(grounded["reason"]) != "not_carried":
		return _fail("stole an uncarried totem: %s" % str(grounded))
	return _pass()


## FROZEN rule 4: merely ENTERING the carrier's cell never transfers custody. This
## guards the slice-6 cutover against reintroducing the old proximity-based theft.
static func _t_entry_no_transfer() -> Dictionary:
	var state: Dictionary = _carried(_cell(3, 3), "echo.1", "echo")
	var report: Dictionary = Custody.resolve_cell_entry(state, {
		"actor_id": "enemy.1",
		"actor_faction": "enemy",
		"cell": _cell(3, 3),
	})
	if bool(report["transferred"]):
		return _fail("cell entry transferred custody")
	if (report["custody_state"] as Dictionary) != state:
		return _fail("cell entry changed custody state")
	if str(report["reason"]) != "cell_entry_never_transfers":
		return _fail("unexpected reason: %s" % str(report["reason"]))
	return _pass()


# ---------------------------------------------------------------------------
# RULE 5 — ENEMY CARRIER RESTRICTION + DOUBLE DAMAGE
# ---------------------------------------------------------------------------

static func _t_enemy_restrictions() -> Dictionary:
	var cfg: Dictionary = _protect_cfg()
	var enemy: Dictionary = Custody.enemy_carrier_restrictions(_carried(_cell(3, 3), "enemy.1", "enemy"), cfg)
	if not bool(enemy["is_enemy_carrier"]):
		return _fail("enemy carrier not detected")
	if not bool(enemy["movement_restricted"]) or not bool(enemy["action_restricted"]):
		return _fail("enemy carrier not move/action restricted: %s" % str(enemy))
	if not bool(enemy["takes_double_damage"]):
		return _fail("enemy carrier does not take double damage")
	if not is_equal_approx(float(enemy["damage_multiplier"]), 2.0):
		return _fail("expected the existing double_damage_mult 2.0, got %f" % float(enemy["damage_multiplier"]))
	if int(enemy["capacity_cap"]) != 1:
		return _fail("expected capacity cap 1, got %d" % int(enemy["capacity_cap"]))

	# An ECHO carrier is never restricted and never takes double damage.
	var echo: Dictionary = Custody.enemy_carrier_restrictions(_carried(_cell(3, 3), "echo.1", "echo"), cfg)
	if bool(echo["is_enemy_carrier"]) or bool(echo["takes_double_damage"]):
		return _fail("echo carrier treated as an enemy carrier: %s" % str(echo))
	if not is_equal_approx(float(echo["damage_multiplier"]), 1.0):
		return _fail("echo carrier multiplier should be 1.0")

	# A grounded totem restricts nobody.
	var grounded: Dictionary = Custody.enemy_carrier_restrictions(_grounded(_cell(3, 3)), cfg)
	if bool(grounded["is_enemy_carrier"]) or bool(grounded["movement_restricted"]):
		return _fail("grounded totem produced restrictions: %s" % str(grounded))
	return _pass()


# ---------------------------------------------------------------------------
# RULE 6 — DROP / RECOVERY CELL
# ---------------------------------------------------------------------------

## The drop cell IS the carrier's current cell — including after the carrier was
## dragged by a forced hazard displacement.
static func _t_drop_cell() -> Dictionary:
	var state: Dictionary = _carried(_cell(1, 1), "enemy.1", "enemy")
	var result: Dictionary = _activate(
		_ctx({"mover_id": "enemy.1"}), [_cell(2, 1), _cell(3, 1)],
		ActionPlan.build("actor.guard"), _profile(4, "enemy")
	)
	var moved: Dictionary = (Custody.track_carrier_movement(state, result)["custody_state"]) as Dictionary
	if Custody.drop_cell(moved) != (result["final_destination"] as Dictionary):
		return _fail("drop cell is not the carrier's current cell")

	var dropped: Dictionary = Custody.resolve_drop(moved, "carrier_down")
	if not bool(dropped["dropped"]):
		return _fail("drop failed: %s" % str(dropped["reason"]))
	if (dropped["drop_cell"] as Dictionary) != (result["final_destination"] as Dictionary):
		return _fail("drop landed elsewhere: %s" % str(dropped["drop_cell"]))
	var after: Dictionary = dropped["custody_state"] as Dictionary
	if not str(after["carrier_id"]).is_empty() or not str(after["carrier_faction"]).is_empty():
		return _fail("carrier not cleared on drop: %s" % str(after))
	if (after["totem_cell"] as Dictionary) != (result["final_destination"] as Dictionary):
		return _fail("totem did not stay on the drop cell")
	if (moved["totem_cell"] as Dictionary) != (result["final_destination"] as Dictionary):
		return _fail("resolve_drop mutated its input state")
	return _pass()


## Recovery is the same pickup action, taken against the dropped totem.
static func _t_recovery_after_drop() -> Dictionary:
	var cfg: Dictionary = _protect_cfg()
	var dropped: Dictionary = (Custody.resolve_drop(
		_carried(_cell(4, 1), "enemy.1", "enemy"), "carrier_down"
	)["custody_state"]) as Dictionary
	if Custody.is_carried(dropped):
		return _fail("totem still carried after the drop")

	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1), _cell(3, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
		Custody.pickup_action_ctx(dropped, cfg)
	)
	var report: Dictionary = Custody.resolve_pickup(dropped, result, cfg)
	if not bool(report["picked_up"]):
		return _fail("recovery failed: %s" % str(report["reason"]))
	var after: Dictionary = report["custody_state"] as Dictionary
	if str(after["carrier_id"]) != "echo.1" or str(after["carrier_faction"]) != "echo":
		return _fail("recovery did not restore echo custody: %s" % str(after))
	return _pass()


# ---------------------------------------------------------------------------
# HAZARDS / BOUNDARY / DETERMINISM
# ---------------------------------------------------------------------------

## Carrying changes nothing about hazards: Burning still resolves at end of
## activation while the totem is in hand, and the totem still tracks the carrier.
static func _t_hazards_while_carrying() -> Dictionary:
	var context: Dictionary = _ctx({
		"origin": _cell(7, 5),
		"bounds": HazardFixtures.board_bounds(),
		"known_hazards": HazardFixtures.burning_at(_cell(8, 5)),
	})
	var state: Dictionary = _carried(_cell(7, 5), "echo.1", "echo")
	var result: Dictionary = _activate(
		context, [_cell(8, 5)], ActionPlan.build("actor.guard"), _profile(4), {}, _hazard_ctx(_hazard_cfg())
	)
	var burned: bool = false
	for hazard_value: Variant in result.get("hazards", []) as Array:
		if str((hazard_value as Dictionary).get("type", "")) == "burning":
			burned = true
	if not burned:
		return _fail("burning did not resolve for a carrier: %s" % str(result["hazards"]))
	if not bool(ResultContract.validate(result)["valid"]):
		return _fail("carrier hazard result rejected")
	var report: Dictionary = Custody.track_carrier_movement(state, result)
	if ((report["custody_state"] as Dictionary)["totem_cell"] as Dictionary) != _cell(8, 5):
		return _fail("totem did not follow into the hazard cell")
	return _pass()


## BOUNDARY: no entry point decides PROTECT win/loss, the protect counter, or any
## objective progress — every report is custody facts only.
static func _t_no_objective_authority() -> Dictionary:
	var cfg: Dictionary = _protect_cfg()
	var state: Dictionary = _carried(_cell(3, 3), "enemy.1", "enemy")
	var result: Dictionary = _activate(
		_ctx({"mover_id": "enemy.1"}), [_cell(2, 1)], ActionPlan.build("actor.guard"), _profile(4, "enemy")
	)
	var banned: Array = [
		"protect_counter", "objective_progress", "win", "loss", "objective_complete",
		"resolution", "outcome", "victory", "defeat",
	]
	var reports: Array = [
		Custody.custody_report(state, cfg),
		Custody.resolve_pickup(_grounded(_cell(3, 1)), result, cfg),
		Custody.track_carrier_movement(state, result),
		Custody.resolve_theft_on_attack(state, {"defender_id": "enemy.1", "hit": true, "roll": 0.1,
			"attacker_id": "echo.1", "attacker_faction": "echo", "attacker_cell": _cell(3, 4)}, cfg),
		Custody.resolve_drop(state, "carrier_down"),
		Custody.enemy_carrier_restrictions(state, cfg),
		Custody.apply_carrier_burden(_profile(4, "enemy"), state, "enemy.1", cfg),
	]
	for report_value: Variant in reports:
		var report: Dictionary = report_value as Dictionary
		for key: Variant in banned:
			if report.has(key):
				return _fail("custody report leaked objective authority key '%s'" % str(key))
	if bool((Custody.custody_report(state, cfg) as Dictionary)["objective_authority"]):
		return _fail("custody_report must declare objective_authority false")
	return _pass()


## Same inputs -> byte-identical outputs, every entry point. No RNG, no time.
static func _t_deterministic_replay() -> Dictionary:
	var cfg: Dictionary = _protect_cfg()
	var grounded: Dictionary = _grounded(_cell(4, 1))
	var carried: Dictionary = _carried(_cell(1, 1), "echo.1", "echo")
	var attack: Dictionary = {
		"attacker_id": "enemy.1", "attacker_faction": "enemy", "attacker_cell": _cell(2, 1),
		"defender_id": "echo.1", "hit": true, "roll": 0.25,
	}
	for _pass_index in range(3):
		var result_a: Dictionary = _activate(
			_ctx(), [_cell(2, 1), _cell(3, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
			Custody.pickup_action_ctx(grounded, cfg)
		)
		var result_b: Dictionary = _activate(
			_ctx(), [_cell(2, 1), _cell(3, 1)], Custody.pickup_action_plan("totem.1"), _profile(4),
			Custody.pickup_action_ctx(grounded, cfg)
		)
		if Custody.resolve_pickup(grounded, result_a, cfg) != Custody.resolve_pickup(grounded, result_b, cfg):
			return _fail("resolve_pickup replay diverged")
		if Custody.track_carrier_movement(carried, result_a) != Custody.track_carrier_movement(carried, result_b):
			return _fail("track_carrier_movement replay diverged")
		if Custody.resolve_theft_on_attack(carried, attack, cfg) != Custody.resolve_theft_on_attack(carried, attack, cfg):
			return _fail("resolve_theft_on_attack replay diverged")
		if Custody.apply_carrier_burden(_profile(4), carried, "echo.1", cfg) \
				!= Custody.apply_carrier_burden(_profile(4), carried, "echo.1", cfg):
			return _fail("apply_carrier_burden replay diverged")
		if Custody.custody_report(carried, cfg) != Custody.custody_report(carried, cfg):
			return _fail("custody_report replay diverged")
	return _pass()


## No entry point mutates any input: custody state, result, profile or config.
static func _t_no_mutation() -> Dictionary:
	var cfg: Dictionary = _protect_cfg()
	var state: Dictionary = _carried(_cell(1, 1), "echo.1", "echo")
	var grounded: Dictionary = _grounded(_cell(4, 1))
	var profile: Dictionary = _profile(4)
	var result: Dictionary = _activate(
		_ctx(), [_cell(2, 1), _cell(3, 1)], Custody.pickup_action_plan("totem.1"), profile,
		Custody.pickup_action_ctx(grounded, cfg)
	)
	var attack: Dictionary = {
		"attacker_id": "enemy.1", "attacker_faction": "enemy", "attacker_cell": _cell(2, 1),
		"defender_id": "echo.1", "hit": true, "roll": 0.1,
	}

	var cfg_before: Dictionary = cfg.duplicate(true)
	var state_before: Dictionary = state.duplicate(true)
	var grounded_before: Dictionary = grounded.duplicate(true)
	var profile_before: Dictionary = profile.duplicate(true)
	var result_before: Dictionary = result.duplicate(true)
	var attack_before: Dictionary = attack.duplicate(true)

	Custody.resolve_pickup(grounded, result, cfg)
	Custody.track_carrier_movement(state, result)
	Custody.resolve_theft_on_attack(state, attack, cfg)
	Custody.resolve_cell_entry(state, {"actor_id": "enemy.1", "cell": _cell(1, 1)})
	Custody.resolve_drop(state, "carrier_down")
	Custody.apply_carrier_burden(profile, state, "echo.1", cfg)
	Custody.enemy_carrier_restrictions(state, cfg)
	Custody.custody_report(state, cfg)
	Custody.pickup_action_ctx(state, cfg)

	if cfg != cfg_before:
		return _fail("protect_cfg was mutated")
	if state != state_before:
		return _fail("carried custody_state was mutated")
	if grounded != grounded_before:
		return _fail("grounded custody_state was mutated")
	if profile != profile_before:
		return _fail("MovementProfile was mutated")
	if result != result_before:
		return _fail("MovementResult was mutated")
	if attack != attack_before:
		return _fail("attack dict was mutated")
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
