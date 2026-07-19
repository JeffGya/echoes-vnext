# res://tests/MovementHazardTests.gd
# V2-COMBAT-002 Slice 3 (DORMANT): fixed-hazard behavior resolver.
#
# Deterministic, hand-built boards + hazard facts. Config set directly (no live save
# dependency) except one wiring test that reads balance.json via ConfigService.

class_name MovementHazardTests
extends RefCounted

const HazardService = preload("res://core/movement/MovementHazardService.gd")
const HazardFixtures = preload("res://core/movement/MovementHazardFixtures.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/hazard/unstable_incoming_edge_east", Callable(MovementHazardTests, "_t_unstable_incoming_edge_east"))
	runner.register_test("movement/hazard/unstable_incoming_edge_north", Callable(MovementHazardTests, "_t_unstable_incoming_edge_north"))
	runner.register_test("movement/hazard/unstable_outward_from_center", Callable(MovementHazardTests, "_t_unstable_outward_from_center"))
	runner.register_test("movement/hazard/unstable_ranking_no_rowcol_bias", Callable(MovementHazardTests, "_t_unstable_ranking_no_rowcol_bias"))
	runner.register_test("movement/hazard/unstable_ambiguous_tie_fallback", Callable(MovementHazardTests, "_t_unstable_ambiguous_tie_fallback"))
	runner.register_test("movement/hazard/unstable_fallback_boxed_in", Callable(MovementHazardTests, "_t_unstable_fallback_boxed_in"))
	runner.register_test("movement/hazard/unstable_diagonal_legality_respected", Callable(MovementHazardTests, "_t_unstable_diagonal_legality_respected"))
	runner.register_test("movement/hazard/binding_stop", Callable(MovementHazardTests, "_t_binding_stop"))
	runner.register_test("movement/hazard/binding_after_unstable_displacement", Callable(MovementHazardTests, "_t_binding_after_unstable_displacement"))
	runner.register_test("movement/hazard/burning_once_per_activation", Callable(MovementHazardTests, "_t_burning_once_per_activation"))
	runner.register_test("movement/hazard/ledger_prevents_retrigger_voluntary", Callable(MovementHazardTests, "_t_ledger_prevents_retrigger_voluntary"))
	runner.register_test("movement/hazard/forced_entry_guard", Callable(MovementHazardTests, "_t_forced_entry_guard"))
	runner.register_test("movement/hazard/forced_displacement_no_recursive_unstable", Callable(MovementHazardTests, "_t_forced_displacement_no_recursive_unstable"))
	runner.register_test("movement/hazard/events_conform_to_movement_event", Callable(MovementHazardTests, "_t_events_conform_to_movement_event"))
	runner.register_test("movement/hazard/movement_result_integration", Callable(MovementHazardTests, "_t_movement_result_integration"))
	runner.register_test("movement/hazard/no_input_mutation", Callable(MovementHazardTests, "_t_no_input_mutation"))
	runner.register_test("movement/hazard/balance_config_wired", Callable(MovementHazardTests, "_t_balance_config_wired"))


# --- fixtures / helpers ------------------------------------------------------

static func _cfg() -> Dictionary:
	return {
		"types": ["unstable", "binding", "burning"],
		"unstable": {"displacement_cells": 1, "fallback_damage": 3},
		"binding": {"stops_movement": true},
		"burning": {"end_activation_damage": 3},
	}


static func _cell(col: int, row: int) -> Dictionary:
	return {"col": col, "row": row}


static func _ctx(extra: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"config": _cfg(),
		"walkable": {},  # {} == StageTerrain all-walkable sentinel (bounds constrain)
		"bounds": {"w": 10, "h": 10},
		"occupied": {},
		"mover_id": "mover.1",
		"phase": "movement",
		"seq": 0,
	}
	for key: Variant in extra.keys():
		base[key] = extra[key]
	return base


# Full 10x10 walkable board minus the listed blocked cells.
static func _board(blocked: Array) -> Dictionary:
	var walkable: Dictionary = {}
	for col: int in range(10):
		for row: int in range(10):
			walkable["%d,%d" % [col, row]] = true
	for cell_value: Variant in blocked:
		var cell: Dictionary = cell_value as Dictionary
		walkable.erase("%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))])
	return walkable


static func _all_events_valid(events: Array) -> Dictionary:
	for event_value: Variant in events:
		var event: Dictionary = event_value as Dictionary
		var result: Dictionary = EventContract.validate(event)
		if not bool(result["valid"]):
			return _fail("event failed MovementEvent.validate: %s (%s)" % [str(result), str(event)])
	return _pass()


# --- tests -------------------------------------------------------------------

static func _t_unstable_incoming_edge_east() -> Dictionary:
	# Actor enters the hazard cell (== authored center) from the WEST -> pushed EAST.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5)})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if not bool(res["displaced"]):
		return _fail("expected displacement")
	if (res["displaced_to"] as Dictionary) != _cell(6, 5):
		return _fail("expected push east to (6,5), got %s" % str(res["displaced_to"]))
	if int(res["damage"]) != 0 or bool(res["stop"]):
		return _fail("displacement should carry no damage and no stop")
	if (res["events"] as Array).size() != 1:
		return _fail("expected one forced event")
	var event: Dictionary = (res["events"] as Array)[0] as Dictionary
	if str(event["movement_kind"]) != "forced" or int(event["cost"]) != 0:
		return _fail("displacement event must be forced, cost 0")
	if not bool((res["hazard_ctx"] as Dictionary)["triggered"]["unstable"]):
		return _fail("ledger should mark unstable triggered")
	if int(res["next_seq"]) != 1:
		return _fail("next_seq should advance to 1")
	return _all_events_valid(res["events"] as Array)


static func _t_unstable_incoming_edge_north() -> Dictionary:
	# Enter from the SOUTH (row 6 -> row 5) -> pushed NORTH to (5,4).
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(5, 6)})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if (res["displaced_to"] as Dictionary) != _cell(5, 4):
		return _fail("expected push north to (5,4), got %s" % str(res["displaced_to"]))
	return _pass()


static func _t_unstable_outward_from_center() -> Dictionary:
	# Multi-cell footprint path: entered != authored center -> push straight outward
	# from the center (no incoming edge needed). Exercised via the private helper since
	# single-cell facts always trigger with entered == center.
	var hazard: Dictionary = HazardFact.build("hazard.unstable.x", _cell(4, 5), "unstable")
	var east: Dictionary = HazardService._displacement_target(_cell(5, 5), hazard, {}, {}, {"w": 10, "h": 10}, {})
	if east != _cell(6, 5):
		return _fail("center (4,5), entered (5,5) should push east to (6,5), got %s" % str(east))
	var diag_hazard: Dictionary = HazardFact.build("hazard.unstable.y", _cell(4, 4), "unstable")
	var diag: Dictionary = HazardService._displacement_target(_cell(5, 5), diag_hazard, {}, {}, {"w": 10, "h": 10}, {})
	if diag != _cell(6, 6):
		return _fail("center (4,4), entered (5,5) should push diagonally to (6,6), got %s" % str(diag))
	return _pass()


static func _t_unstable_ranking_no_rowcol_bias() -> Dictionary:
	# dir = east; primary (6,5) blocked. Alternatives NE(6,4) & SE(6,6) share outward
	# progress + angular deviation. We block ONE so a UNIQUE cell remains, then MIRROR the
	# board (row 4 <-> row 6). A row/col-order tiebreak would pick the same absolute cell
	# both times; geometry-relative ranking mirrors the choice.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))

	# Case A: SE blocked -> unique NE (6,4).
	var ctx_a: Dictionary = _ctx({"from_cell": _cell(4, 5), "walkable": _board([_cell(6, 5), _cell(6, 6)])})
	var res_a: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx_a, HazardService.new_ledger())
	if (res_a["displaced_to"] as Dictionary) != _cell(6, 4):
		return _fail("case A expected (6,4), got %s" % str(res_a["displaced_to"]))

	# Case B (mirror): NE blocked -> unique SE (6,6). Proves no fixed lowest-row bias.
	var ctx_b: Dictionary = _ctx({"from_cell": _cell(4, 5), "walkable": _board([_cell(6, 5), _cell(6, 4)])})
	var res_b: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx_b, HazardService.new_ledger())
	if (res_b["displaced_to"] as Dictionary) != _cell(6, 6):
		return _fail("case B (mirror) expected (6,6), got %s" % str(res_b["displaced_to"]))
	return _pass()


static func _t_unstable_ambiguous_tie_fallback() -> Dictionary:
	# Primary (6,5) blocked; NE(6,4) and SE(6,6) both legal and symmetric -> ambiguous
	# mirror pair -> NO row/col tiebreak -> fallback_damage, no move.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5), "walkable": _board([_cell(6, 5)])})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if bool(res["displaced"]):
		return _fail("symmetric tie must NOT displace")
	if int(res["damage"]) != 3:
		return _fail("ambiguous tie should apply fallback_damage 3, got %d" % int(res["damage"]))
	if (res["displaced_to"] as Dictionary) != _cell(5, 5):
		return _fail("no displacement means actor stays on entered cell")
	return _all_events_valid(res["events"] as Array)


static func _t_unstable_fallback_boxed_in() -> Dictionary:
	# Actor cell is the only walkable cell -> no legal displacement -> fallback_damage.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5), "walkable": {"5,5": true}})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if bool(res["displaced"]) or int(res["damage"]) != 3:
		return _fail("boxed-in should fallback with damage 3, got displaced=%s damage=%d" % [str(res["displaced"]), int(res["damage"])])
	var event: Dictionary = (res["events"] as Array)[0] as Dictionary
	if str(event["movement_kind"]) != "none" or int(event["damage"]) != 3:
		return _fail("fallback event should be a none-move carrying damage 3")
	return _all_events_valid(res["events"] as Array)


static func _t_unstable_diagonal_legality_respected() -> Dictionary:
	# Primary (6,5) blocked. NE(6,4) would squeeze between TWO solids (6,5)+(5,4) -> illegal
	# by the two-solid-corners rule -> excluded. SE(6,6) stays legal -> unique winner (6,6).
	# If the diagonal rule were ignored, NE+SE would tie -> fallback; getting (6,6) proves it.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5), "walkable": _board([_cell(6, 5), _cell(5, 4)])})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if (res["displaced_to"] as Dictionary) != _cell(6, 6):
		return _fail("diagonal legality should leave (6,6) as the unique cell, got %s" % str(res["displaced_to"]))
	return _pass()


static func _t_binding_stop() -> Dictionary:
	var hazards: Array = HazardFixtures.binding_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5)})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if not bool(res["stop"]) or str(res["stop_reason"]) != "binding_stop":
		return _fail("binding should stop movement with reason binding_stop")
	if bool(res["displaced"]) or int(res["damage"]) != 0:
		return _fail("binding alone should not displace or damage")
	if not bool((res["hazard_ctx"] as Dictionary)["triggered"]["binding"]):
		return _fail("ledger should mark binding triggered")
	var event: Dictionary = (res["events"] as Array)[0] as Dictionary
	if str(event["stop_reason"]) != "binding_stop":
		return _fail("binding event must carry stop_reason binding_stop")
	return _all_events_valid(res["events"] as Array)


static func _t_binding_after_unstable_displacement() -> Dictionary:
	# Unstable displaces east to (6,5); a Binding hazard sits on that LANDING cell -> stop.
	var hazards: Array = [
		HazardFact.build("hazard.unstable.a", _cell(5, 5), "unstable"),
		HazardFact.build("hazard.binding.a", _cell(6, 5), "binding"),
	]
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5)})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if not bool(res["displaced"]) or (res["displaced_to"] as Dictionary) != _cell(6, 5):
		return _fail("expected displacement to (6,5)")
	if not bool(res["stop"]) or str(res["stop_reason"]) != "binding_stop":
		return _fail("binding on landing cell should stop movement")
	if (res["events"] as Array).size() != 2:
		return _fail("expected forced-displace + binding-stop events")
	var triggered: Dictionary = (res["hazard_ctx"] as Dictionary)["triggered"]
	if not bool(triggered["unstable"]) or not bool(triggered["binding"]):
		return _fail("both unstable and binding should be marked triggered")
	return _all_events_valid(res["events"] as Array)


static func _t_burning_once_per_activation() -> Dictionary:
	var hazards: Array = HazardFixtures.burning_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"phase": "end_activation"})
	var first: Dictionary = HazardService.resolve_end_activation(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if int(first["damage"]) != 3 or (first["events"] as Array).size() != 1:
		return _fail("first end-activation should deal 3 burning damage with one event")
	if not bool((first["hazard_ctx"] as Dictionary)["triggered"]["burning"]):
		return _fail("ledger should mark burning triggered")
	# Second call with the carried ledger -> no re-trigger.
	var second: Dictionary = HazardService.resolve_end_activation(_cell(5, 5), hazards, ctx, first["hazard_ctx"] as Dictionary)
	if int(second["damage"]) != 0 or not (second["events"] as Array).is_empty():
		return _fail("burning must not re-trigger within the same activation")
	# No burning hazard on the final cell -> no damage.
	var none: Dictionary = HazardService.resolve_end_activation(_cell(1, 1), hazards, ctx, HazardService.new_ledger())
	if int(none["damage"]) != 0:
		return _fail("no burning hazard on final cell -> no damage")
	return _all_events_valid(first["events"] as Array)


static func _t_ledger_prevents_retrigger_voluntary() -> Dictionary:
	# Two unstable cells: first entry displaces; a later voluntary entry on the other
	# unstable cell (carrying the ledger) does NOT re-trigger unstable.
	var hazards: Array = [
		HazardFact.build("hazard.unstable.a", _cell(5, 5), "unstable"),
		HazardFact.build("hazard.unstable.b", _cell(7, 5), "unstable"),
	]
	var first: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, _ctx({"from_cell": _cell(4, 5)}), HazardService.new_ledger())
	if not bool(first["displaced"]):
		return _fail("first unstable entry should displace")
	var second: Dictionary = HazardService.resolve_cell_entry(_cell(7, 5), hazards, _ctx({"from_cell": _cell(6, 5)}), first["hazard_ctx"] as Dictionary)
	if bool(second["displaced"]) or not (second["events"] as Array).is_empty() or int(second["damage"]) != 0:
		return _fail("unstable must not re-trigger once ledgered")

	# Same for binding across two cells.
	var bhaz: Array = [
		HazardFact.build("hazard.binding.a", _cell(5, 5), "binding"),
		HazardFact.build("hazard.binding.b", _cell(6, 5), "binding"),
	]
	var b1: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), bhaz, _ctx({"from_cell": _cell(4, 5)}), HazardService.new_ledger())
	var b2: Dictionary = HazardService.resolve_cell_entry(_cell(6, 5), bhaz, _ctx({"from_cell": _cell(5, 5)}), b1["hazard_ctx"] as Dictionary)
	if bool(b2["stop"]) or not (b2["events"] as Array).is_empty():
		return _fail("binding must not re-trigger once ledgered")
	return _pass()


static func _t_forced_entry_guard() -> Dictionary:
	# A forced landing (is_forced_entry) must not trigger Unstable even with a fresh ledger.
	var hazards: Array = HazardFixtures.unstable_at(_cell(5, 5))
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5), "is_forced_entry": true})
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, HazardService.new_ledger())
	if bool(res["displaced"]) or not (res["events"] as Array).is_empty():
		return _fail("forced entry should not trigger unstable")
	if bool((res["hazard_ctx"] as Dictionary)["triggered"]["unstable"]):
		return _fail("forced entry should leave unstable untriggered")
	return _pass()


static func _t_forced_displacement_no_recursive_unstable() -> Dictionary:
	# Landing an Unstable displacement onto ANOTHER Unstable cell must not chain.
	var hazards: Array = [
		HazardFact.build("hazard.unstable.a", _cell(5, 5), "unstable"),
		HazardFact.build("hazard.unstable.b", _cell(6, 5), "unstable"),
	]
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), hazards, _ctx({"from_cell": _cell(4, 5)}), HazardService.new_ledger())
	if (res["displaced_to"] as Dictionary) != _cell(6, 5):
		return _fail("expected single displacement to (6,5)")
	if (res["events"] as Array).size() != 1:
		return _fail("displacement onto another unstable must not chain a second forced move")
	# Executor re-resolving the forced landing (is_forced_entry) also does nothing.
	var landing: Dictionary = HazardService.resolve_cell_entry(_cell(6, 5), hazards, _ctx({"from_cell": _cell(5, 5), "is_forced_entry": true}), res["hazard_ctx"] as Dictionary)
	if bool(landing["displaced"]) or not (landing["events"] as Array).is_empty():
		return _fail("re-resolving the forced landing must not re-trigger unstable")
	return _pass()


static func _t_events_conform_to_movement_event() -> Dictionary:
	# Produce displacement + binding + burning events and validate every one.
	var move_hazards: Array = [
		HazardFact.build("hazard.unstable.a", _cell(5, 5), "unstable"),
		HazardFact.build("hazard.binding.a", _cell(6, 5), "binding"),
	]
	var entry: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), move_hazards, _ctx({"from_cell": _cell(4, 5)}), HazardService.new_ledger())
	var entry_valid: Dictionary = _all_events_valid(entry["events"] as Array)
	if not bool(entry_valid["ok"]):
		return entry_valid
	var burn: Dictionary = HazardService.resolve_end_activation(_cell(6, 5), HazardFixtures.burning_at(_cell(6, 5)), _ctx({"phase": "end_activation", "seq": int(entry["next_seq"])}), HazardService.new_ledger())
	return _all_events_valid(burn["events"] as Array)


static func _t_movement_result_integration() -> Dictionary:
	# A hand-built voluntary move + the binding-stop event from the resolver must assemble
	# into a valid MovementResult (proves hazard events chain into the authoritative shape).
	var voluntary: Dictionary = EventContract.build(
		0, "movement", "move.voluntary", "mover.1",
		_cell(4, 5), _cell(5, 5), "voluntary", 1, {}, 0, ""
	)
	var entry: Dictionary = HazardService.resolve_cell_entry(
		_cell(5, 5), HazardFixtures.binding_at(_cell(5, 5)), _ctx({"from_cell": _cell(4, 5), "seq": 1}), HazardService.new_ledger()
	)
	var binding_event: Dictionary = (entry["events"] as Array)[0] as Dictionary
	var result: Dictionary = ResultContract.build(
		"mover.1", "act.1", "goal.1", "opt.1", "protect",
		_cell(4, 5),                # origin
		_cell(5, 5),                # final_destination
		[_cell(5, 5)],              # planned_path (excludes origin)
		[_cell(5, 5)],              # actual_traversed_cells
		1,                          # voluntary_cost
		0,                          # forced_steps
		2,                          # remaining_capacity
		"binding_stop",             # stop_reason
		[voluntary, binding_event], # events
		{}, {}, {},                 # planned_action / resolved_action / fallback
		[binding_event["hazard"] as Dictionary],  # hazards (projected)
		0.0,                        # objective_progress
		{}                          # hostile_constraints
	)
	var validity: Dictionary = ResultContract.validate(result)
	if not bool(validity["valid"]):
		return _fail("assembled MovementResult rejected: %s" % str(validity))
	return _pass()


static func _t_no_input_mutation() -> Dictionary:
	var hazards: Array = [
		HazardFact.build("hazard.unstable.a", _cell(5, 5), "unstable"),
		HazardFact.build("hazard.binding.a", _cell(6, 5), "binding"),
	]
	var hazards_snapshot: Array = hazards.duplicate(true)
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5)})
	var ctx_snapshot: Dictionary = ctx.duplicate(true)
	var ledger: Dictionary = HazardService.new_ledger()
	var ledger_snapshot: Dictionary = ledger.duplicate(true)

	HazardService.resolve_cell_entry(_cell(5, 5), hazards, ctx, ledger)
	HazardService.resolve_end_activation(_cell(8, 5), HazardFixtures.burning_at(_cell(8, 5)), ctx, ledger)

	if hazards != hazards_snapshot:
		return _fail("resolver mutated the hazard facts array")
	if ctx != ctx_snapshot:
		return _fail("resolver mutated the context dict")
	if ledger != ledger_snapshot:
		return _fail("resolver mutated the passed-in ledger")
	return _pass()


static func _t_balance_config_wired() -> Dictionary:
	var config := ConfigService.new()
	config.load_balance()
	var haz_cfg: Dictionary = config.get_balance() \
		.get("data", {}) \
		.get("combat", {}) \
		.get("movement", {}) \
		.get("hazards", {})
	if haz_cfg.is_empty():
		return _fail("data.combat.movement.hazards missing from balance.json")
	for key: String in ["types", "unstable", "binding", "burning"]:
		if not haz_cfg.has(key):
			return _fail("hazards config missing key '%s'" % key)
	if int((haz_cfg["unstable"] as Dictionary).get("displacement_cells", -1)) != 1:
		return _fail("unstable.displacement_cells should be 1")
	if int((haz_cfg["unstable"] as Dictionary).get("fallback_damage", -1)) != 3:
		return _fail("unstable.fallback_damage should be 3")
	if not bool((haz_cfg["binding"] as Dictionary).get("stops_movement", false)):
		return _fail("binding.stops_movement should be true")
	if int((haz_cfg["burning"] as Dictionary).get("end_activation_damage", -1)) != 3:
		return _fail("burning.end_activation_damage should be 3")
	# The live config must drive a real resolution.
	var ctx: Dictionary = _ctx({"from_cell": _cell(4, 5)})
	ctx["config"] = haz_cfg
	var res: Dictionary = HazardService.resolve_cell_entry(_cell(5, 5), HazardFixtures.unstable_at(_cell(5, 5)), ctx, HazardService.new_ledger())
	if (res["displaced_to"] as Dictionary) != _cell(6, 5):
		return _fail("live config should drive an eastward displacement to (6,5)")
	return _pass()


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
