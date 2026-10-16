# res://tools/ExposureChoiceBoards.gd
#
# INVESTIGATION TOOL — not a test. Run with `-- tests spatialprobe boards`; prints, never asserts.
#
# Each board is an Echo with an exposed route and an unexposed route of near-equal progress.
# Options come from MovementOptionService.generate_options; the context comes from
# CombatTurnContextService.build_turn_context; the choice comes from select_movement_intent
# (the path of movement_arbiter/fear_lean_reaches_arbiter_through_turn_context).
#
# The generator gives two routes to ONE destination the same objective_progress, so every board
# compares two destinations of equal or near-equal progress. The flip sweep then moves the
# progress of the exposed (E) options only; that edit is the one hand-made value in this tool.
# Config is read, never written. Refusal is not modelled (the arbiter is called directly).

class_name ExposureChoiceBoards
extends RefCounted

const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

## `pick` chooses generated options by production style name; E = exposed side, U = unexposed side.
const DEFS: Array = [
	{"name": "B1_equal_progress", "w": 9, "h": 5, "origin": [0, 2], "goal": [8, 2], "hostiles": [[2, 1], [4, 3]],
		"capacity": 4, "walls": [], "pick": {"E": ["forceful"], "U": ["conservative"]}},
	{"name": "B2_exposed_1_cell_ahead", "w": 9, "h": 5, "origin": [0, 2], "goal": [8, 2], "hostiles": [[2, 2], [4, 2]],
		"capacity": 4, "walls": [], "pick": {"E": ["forceful"], "U": ["conservative"]}},
	{"name": "B3_exposed_2_cells_ahead", "w": 9, "h": 5, "origin": [0, 2], "goal": [8, 2], "hostiles": [[2, 1], [4, 3]],
		"capacity": 4, "walls": [], "pick": {"E": ["direct"], "U": ["safe"]}},
	{"name": "B4_two_exposed_routes", "w": 9, "h": 5, "origin": [0, 2], "goal": [8, 2], "hostiles": [[2, 1], [4, 3]],
		"capacity": 4, "walls": [], "pick": {"E": ["direct", "forceful"], "U": ["conservative"]}},
	{"name": "B5_exposed_1_cell_behind", "w": 9, "h": 5, "origin": [0, 2], "goal": [8, 2], "hostiles": [[2, 2], [4, 2]],
		"capacity": 4, "walls": [], "pick": {"E": ["forceful"], "U": ["direct"]}},
]
const DIRECTIVES: Array = [["scout", "directive.scout_carefully"], ["seek", "directive.seek_signs"]]
const FEARS: Array = [0, 30, 50]
const SWEEP_FROM: float = -0.5
const SWEEP_TO: float = 1.0
const SWEEP_STEP: float = 0.005
const CELL: float = 0.125


static func run(_arm: String) -> void:
	var config := ConfigService.new()
	config.load_balance()
	var balance: Dictionary = config.get_balance()
	var bdata: Dictionary = balance["data"] as Dictionary
	var movement: Dictionary = (bdata["combat"] as Dictionary)["movement"] as Dictionary
	var utility: Dictionary = movement["spatial_utility"] as Dictionary
	SpatialTermProbe._say("### BOARDS directive_exposure_acceptance_weight=%s exposure_weight=%s fear_lean_bound=%s" % [
		str(utility["directive_exposure_acceptance_weight"]), str(utility["exposure_weight"]),
		str((movement["exposure_acceptance"] as Dictionary)["fear_lean_bound"])])
	var table: PackedStringArray = []
	for def_v: Variant in DEFS:
		var def: Dictionary = def_v
		var board: Dictionary = build(def)
		var picked: Dictionary = _pick(board["options"] as Array, def["pick"] as Dictionary)
		SpatialTermProbe._say("### BOARD %s generated=%d picked_E=%d picked_U=%d" % [
			str(def["name"]), (board["options"] as Array).size(), (picked["E"] as Array).size(), (picked["U"] as Array).size()])
		if (picked["E"] as Array).is_empty() or (picked["U"] as Array).is_empty():
			SpatialTermProbe._say("BOARD_FAILED %s pick found no option" % str(def["name"]))
			continue
		for side: String in ["E", "U"]:
			for option_v: Variant in picked[side] as Array:
				var option: Dictionary = option_v
				SpatialTermProbe._say("OPTION %s %s %s exp=%.3f prog=%.3f cells=%d" % [
					str(def["name"]), side, _short(str(option["option_id"])), float(option["exposure"]),
					float(option["objective_progress"]), (option["path"] as Array).size()])
		for directive_v: Variant in DIRECTIVES:
			var row: PackedStringArray = []
			for fear: int in FEARS:
				var tag: String = "%s dir=%s fear=%d" % [str(def["name"]), str(directive_v[0]), fear]
				var cell: Dictionary = _cell(config, balance, bdata, movement, board, picked, str(directive_v[1]), fear, tag)
				SpatialTermProbe._say("CASE %s choice=%s chosen=%s margin_E_minus_U=%.3f margin_without_dexp=%.3f choice_without_dexp=%s" % [
					tag, cell["choice"], cell["chosen"], cell["margin"], cell["margin_removed"], cell["removed_choice"]])
				for line: String in cell["lines"] as PackedStringArray:
					SpatialTermProbe._say(line)
				var flip: Dictionary = _flip(config, balance, bdata, movement, board, picked, str(directive_v[1]), fear)
				SpatialTermProbe._say("FLIP %s adv_cells=%s adv_progress=%s adv_points=%s monotonic=%d without_dexp_adv_cells=%s without_dexp_adv_points=%s" % [
					tag, flip["cells"], flip["progress"], flip["points"], 1 if bool(flip["monotonic"]) else 0,
					flip["removed_cells"], flip["removed_points"]])
				row.append("fear%d=%s(base %s)" % [fear, flip["cells"], flip["removed_cells"]])
			table.append("%s %s %s" % [str(def["name"]), str(directive_v[0]), " ".join(row)])
	SpatialTermProbe._say("### FLIP_TABLE smallest progress advantage of E over U, in cells (1 cell = 0.125), at which E is chosen; base = same with the Directive exposure part and fear lean removed; none = never inside the sweep")
	for line: String in table:
		SpatialTermProbe._say("FLIP_TABLE " + line)


static func build(def: Dictionary) -> Dictionary:
	var origin := {"col": int(def["origin"][0]), "row": int(def["origin"][1])}
	var actor: Dictionary = MovementArbitrationTests._actor()
	actor["grid_pos"] = origin
	var others: Array = []
	var index: int = 0
	for cell_v: Variant in def["hostiles"] as Array:
		index += 1
		others.append(MovementArbitrationTests._enemy("enemy.h%d" % index, {"col": int((cell_v as Array)[0]), "row": int((cell_v as Array)[1])}))
	var facts: Array = [MovementArbitrationTests._fact(actor)]
	var occupancy: Dictionary = {MovementArbitrationTests._key(origin): "echo.a"}
	var relationships: Dictionary = {}
	for other_v: Variant in others:
		var other: Dictionary = other_v
		facts.append(MovementArbitrationTests._fact(other))
		occupancy[MovementArbitrationTests._key(other["grid_pos"])] = str(other["id"])
		relationships[str(other["id"])] = "hostile"
	facts.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary)["id"]) < str((b as Dictionary)["id"]))
	var walkable: Dictionary = {}
	var terrain: Dictionary = {}
	for col: int in range(int(def["w"])):
		for row: int in range(int(def["h"])):
			if (def["walls"] as Array).has([col, row]):
				continue
			walkable["%d,%d" % [col, row]] = true
			terrain["%d,%d" % [col, row]] = 1
	var movement_context: Dictionary = ContextContract.build(
		"echo.a", "activation.a", origin, {"w": int(def["w"]), "h": int(def["h"])},
		walkable, walkable, occupancy, facts, relationships, terrain, [], {}, [])
	var region := {"col": int(def["goal"][0]), "row": int(def["goal"][1])}
	var goal: Dictionary = GoalContract.build(
		"goal.combat.advance.baseline.c%dr%d" % [int(region["col"]), int(region["row"])],
		"advance", [region], 0.5, 0.0, [],
		["mode.combat", "objective.board", "role.baseline"],
		ActionPlan.build("actor.move"), ActionPlan.build("actor.idle"))
	var profile: Dictionary = ProfileContract.build(int(def["capacity"]), [], true, "echo", {})
	var generated: Dictionary = MovementOptionService.generate_options(movement_context, profile, goal)
	return {
		"actor": actor, "others": others, "movement_context": movement_context,
		"profile": profile, "goals": [goal], "options": generated.get("options", []) as Array,
	}


static func _pick(options: Array, pick: Dictionary) -> Dictionary:
	var result := {"E": [], "U": []}
	for side: String in ["E", "U"]:
		for style_v: Variant in pick[side] as Array:
			for option_v: Variant in options:
				if str((option_v as Dictionary)["option_id"]).contains(".%s." % str(style_v)):
					(result[side] as Array).append((option_v as Dictionary).duplicate(true))
	return result


static func _short(option_id: String) -> String:
	var slices: PackedStringArray = option_id.split(".")
	return "%s.%s" % [slices[5], slices[6]] if slices.size() > 6 else option_id


## One production-path pass: build_turn_context, then select_movement_intent.
static func _select(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary,
		board: Dictionary, options: Array, directive_id: String, fear: int) -> Dictionary:
	var actor: Dictionary = (board["actor"] as Dictionary).duplicate(true)
	actor["fear"] = fear
	var flow_ctx := FlowContext.new()
	flow_ctx.save_data = {"stage_context": {"active_directive_id": directive_id}}
	var ectx := EncounterContext.new()
	ectx.encounter_id = "probe.exposure_boards"
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.actors = (board["others"] as Array).duplicate(true)
	flow_ctx.encounter_ctx = ectx
	var directives := DirectiveService.new(flow_ctx.save_data)
	directives.load_from_config(balance)
	var svc := CombatTurnContextService.new(flow_ctx, config, directives, StructuredLogger.new())
	var ctx: Dictionary = svc.build_turn_context(actor, ectx, balance, bdata, 1, 1)["ctx"]
	var arbiter := ExposureCaptureArbiter.new({}, movement)
	var result: Dictionary = arbiter.select_movement_intent(
		ctx, board["movement_context"] as Dictionary, board["profile"] as Dictionary, board["goals"] as Array, options)
	if not bool(result.get("valid", false)) or arbiter.last.is_empty():
		return {"valid": false, "reason": str(result.get("reason", "no capture"))}
	return {"valid": true, "records": arbiter.last["records"], "chosen": arbiter.last["chosen"]}


static func _classify(option_id: String, e_ids: Array, u_ids: Array) -> String:
	if e_ids.has(option_id):
		return "E"
	return "U" if u_ids.has(option_id) else "other"


## `shift` moves the progress of every E option; the U options keep theirs.
static func _eval(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary,
		board: Dictionary, picked: Dictionary, directive_id: String, fear: int, shift: float) -> Dictionary:
	var options: Array = []
	var e_ids: Array = []
	var u_ids: Array = []
	for option_v: Variant in picked["E"] as Array:
		e_ids.append(str((option_v as Dictionary)["option_id"]))
	for option_v: Variant in picked["U"] as Array:
		u_ids.append(str((option_v as Dictionary)["option_id"]))
	# The arbiter rejects options that are not in the generator's canonical order.
	for option_v: Variant in board["options"] as Array:
		var option: Dictionary = (option_v as Dictionary).duplicate(true)
		var option_id: String = str(option["option_id"])
		if e_ids.has(option_id):
			option["objective_progress"] = clampf(float(option["objective_progress"]) + shift, 0.0, 1.0)
		elif not u_ids.has(option_id):
			continue
		options.append(option)
	var pass_result: Dictionary = _select(config, balance, bdata, movement, board, options, directive_id, fear)
	if not bool(pass_result["valid"]):
		return {"valid": false, "reason": pass_result["reason"]}
	var records: Array = pass_result["records"]
	var chosen: Dictionary = pass_result["chosen"]
	var best_e: float = -INF
	var best_u: float = -INF
	var best_e_removed: float = -INF
	var best_u_removed: float = -INF
	var e_progress: float = 0.0
	var u_progress: float = 0.0
	var e_part: float = 0.0
	var u_part: float = 0.0
	for record_v: Variant in records:
		var record: Dictionary = record_v
		if not bool(record["route"]):
			continue
		var side: String = _classify(str(record["option_id"]), e_ids, u_ids)
		var removed: float = ExposureCaptureArbiter.score_without_acceptance(record)
		var objective_part: float = float((record["parts"] as Dictionary).get("objective_progress", 0.0))
		if side == "E":
			best_e_removed = maxf(best_e_removed, removed)
			if float(record["score"]) > best_e:
				best_e = float(record["score"])
				e_progress = float(record["progress"])
				e_part = objective_part
		elif side == "U":
			best_u_removed = maxf(best_u_removed, removed)
			if float(record["score"]) > best_u:
				best_u = float(record["score"])
				u_progress = float(record["progress"])
				u_part = objective_part
	var removed_pick: Dictionary = ExposureCaptureArbiter.argmax(records, true)
	return {
		"valid": true,
		"choice": _classify(str(chosen["option_id"]), e_ids, u_ids),
		"chosen": _short(str(chosen["option_id"])),
		"removed_choice": _classify(str(removed_pick.get("option_id", "")), e_ids, u_ids),
		"margin": best_e - best_u,
		"margin_removed": best_e_removed - best_u_removed,
		"adv_progress": e_progress - u_progress,
		"adv_points": e_part - u_part,
		"records": records,
		"chosen_key": chosen,
	}


static func _cell(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary,
		board: Dictionary, picked: Dictionary, directive_id: String, fear: int, tag: String) -> Dictionary:
	var evaluated: Dictionary = _eval(config, balance, bdata, movement, board, picked, directive_id, fear, 0.0)
	if not bool(evaluated["valid"]):
		SpatialTermProbe._say("CASE_FAILED %s %s" % [tag, str(evaluated["reason"])])
		return {"choice": "failed", "chosen": "-", "removed_choice": "-", "margin": 0.0, "margin_removed": 0.0, "lines": PackedStringArray()}
	var records: Array = evaluated["records"]
	var chosen: Dictionary = evaluated["chosen_key"]
	var lines: PackedStringArray = ExposureCaptureArbiter.decision_lines(tag, records, chosen)
	lines.append(ExposureCaptureArbiter.turnsum_line(tag, ExposureCaptureArbiter.analyse(records, chosen)))
	evaluated["lines"] = lines
	return evaluated


## Smallest progress advantage of E over U at which E is chosen, found by sweeping the E progress.
static func _flip(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary,
		board: Dictionary, picked: Dictionary, directive_id: String, fear: int) -> Dictionary:
	var first: Dictionary = {}
	var first_removed: Dictionary = {}
	var seen_e: bool = false
	var monotonic: bool = true
	var shift: float = SWEEP_FROM
	while shift <= SWEEP_TO + 0.0001:
		var evaluated: Dictionary = _eval(config, balance, bdata, movement, board, picked, directive_id, fear, shift)
		if bool(evaluated["valid"]):
			var is_e: bool = str(evaluated["choice"]) == "E"
			if is_e and first.is_empty():
				first = evaluated
			if seen_e and not is_e:
				monotonic = false
			seen_e = seen_e or is_e
			if str(evaluated["removed_choice"]) == "E" and first_removed.is_empty():
				first_removed = evaluated
		shift += SWEEP_STEP
	return {
		"cells": "none" if first.is_empty() else "%.2f" % (float(first["adv_progress"]) / CELL),
		"progress": "none" if first.is_empty() else "%.3f" % float(first["adv_progress"]),
		"points": "none" if first.is_empty() else "%.2f" % float(first["adv_points"]),
		"removed_cells": "none" if first_removed.is_empty() else "%.2f" % (float(first_removed["adv_progress"]) / CELL),
		"removed_points": "none" if first_removed.is_empty() else "%.2f" % float(first_removed["adv_points"]),
		"monotonic": monotonic,
	}
