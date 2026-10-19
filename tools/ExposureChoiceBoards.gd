# res://tools/ExposureChoiceBoards.gd
#
# INVESTIGATION TOOL, not a test. Run with `-- tests spatialprobe boards`; prints, never asserts.
# Each board is an Echo with an exposed route (E) and an unexposed route (U) of near-equal
# progress, built through the production path (generate_options, build_turn_context,
# select_movement_intent). The flip sweep moves the progress of the E options only: the one
# hand-made value. Config is read, never written. Refusal is not modelled.

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
const FEARS: Array = [0, 50]
## Standing (rank) of the test Echo; Judgment comes from the production derivation, not a literal.
const STANDINGS: Array = [1, 9]
const SWEEP_FROM: float = -0.5
const SWEEP_TO: float = 1.0
const SWEEP_STEP: float = 0.005
const CELL: float = 0.125
## [name, fear, morale] of the states the felt-state rows print.
const FELT_STATES: Array = [["grounded", 0, 50], ["burdened", 45, 50], ["pressed", 55, 50], ["hollow", 90, 50], ["radiant", 0, 80]]
const FELT_STANDINGS: Array = [1, 3, 6, 9]


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
			for standing: int in STANDINGS:
				var row: PackedStringArray = []
				for fear: int in FEARS:
					var judgment: float = MovementArbitrationTests._production_judgment(standing, "okofor", fear)
					var cell_board: Dictionary = board.duplicate()
					cell_board["judgment"] = judgment
					var tag: String = "%s dir=%s standing=%d fear=%d" % [str(def["name"]), str(directive_v[0]), standing, fear]
					var cell: Dictionary = _cell(config, balance, bdata, movement, cell_board, picked, str(directive_v[1]), fear, tag)
					SpatialTermProbe._say("CASE %s judgment=%.3f choice=%s chosen=%s margin_E_minus_U=%.3f margin_without_dexp=%.3f choice_without_dexp=%s" % [
						tag, judgment, cell["choice"], cell["chosen"], cell["margin"], cell["margin_removed"], cell["removed_choice"]])
					for line: String in cell["lines"] as PackedStringArray:
						SpatialTermProbe._say(line)
					var flip: Dictionary = _flip(config, balance, bdata, movement, cell_board, picked, str(directive_v[1]), fear)
					SpatialTermProbe._say("FLIP %s judgment=%.3f adv_cells=%s adv_progress=%s adv_points=%s monotonic=%d without_dexp_adv_cells=%s without_dexp_adv_points=%s" % [
						tag, judgment, flip["cells"], flip["progress"], flip["points"], 1 if bool(flip["monotonic"]) else 0,
						flip["removed_cells"], flip["removed_points"]])
					row.append("fear%d(J%.2f)=%s(base %s)" % [fear, judgment, flip["cells"], flip["removed_cells"]])
				table.append("%s %s standing%d %s" % [str(def["name"]), str(directive_v[0]), standing, " ".join(row)])
	SpatialTermProbe._say("### FLIP_TABLE smallest progress advantage of E over U, in cells (1 cell = 0.125), at which E is chosen; base = same with the Directive exposure part and fear lean removed; none = never inside the sweep")
	for line: String in table:
		SpatialTermProbe._say("FLIP_TABLE " + line)
	_felt_rows(config, balance, bdata, movement)


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
	actor["morale"] = int(board.get("morale", actor.get("morale", 50)))
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
	ctx["judgment"] = float(board["judgment"])
	if board.has("composure"):
		ctx["composure"] = float(board["composure"])
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


## Judgment and composure as the combat pipeline derives them for an Echo of this Standing and state.
static func _expression(config: ConfigService, bdata: Dictionary, standing: int, fear: int, morale: int) -> Dictionary:
	var actor: Dictionary = MovementArbitrationTests._judgment_actor(bdata, standing, "okofor", fear)
	actor["morale"] = morale
	var inputs: Dictionary = MaturityExpressionService.build_ctx_inputs(
		actor, [], {}, bdata, ConfigService.get_bond_thresholds_cfg(config), {}, 0.0)
	var expression: Dictionary = MaturityExpressionService.derive_expression(actor, inputs, bdata["maturity_expression"] as Dictionary)
	expression["actor"] = actor
	return expression


static func _chosen_cells(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary,
		board: Dictionary, fear: int) -> String:
	var result: Dictionary = _select(config, balance, bdata, movement, board, board["options"] as Array, "directive.scout_carefully", fear)
	if not bool(result["valid"]):
		return "failed"
	var chosen_id: String = str((result["chosen"] as Dictionary).get("option_id", ""))
	for option_v: Variant in board["options"] as Array:
		if str((option_v as Dictionary)["option_id"]) == chosen_id:
			return str(((option_v as Dictionary)["path"] as Array).size())
	return "stay"


## Print rows for the felt-state lean, steps and style growth. Print only.
static func _felt_rows(config: ConfigService, balance: Dictionary, bdata: Dictionary, movement: Dictionary) -> void:
	var def: Dictionary = DEFS[0]
	var live := LiveMovementContextService.new(FlowContext.new(), StructuredLogger.new())
	var capacity_cfg: Dictionary = movement["capacity"] as Dictionary
	SpatialTermProbe._say("### FELT F-1 chosen route and the smallest progress advantage (cells) at which the exposed route wins, board B1, scout")
	for standing: int in [1, 9]:
		for state: Array in FELT_STATES:
			var expression: Dictionary = _expression(config, bdata, standing, int(state[1]), int(state[2]))
			var board: Dictionary = build(def)
			board["judgment"] = float(expression["judgment"])
			board["composure"] = float(expression["composure"])
			board["morale"] = int(state[2])
			var picked: Dictionary = _pick(board["options"] as Array, def["pick"] as Dictionary)
			var cell: Dictionary = _cell(config, balance, bdata, movement, board, picked, "directive.scout_carefully", int(state[1]), "FELT")
			var flip: Dictionary = _flip(config, balance, bdata, movement, board, picked, "directive.scout_carefully", int(state[1]))
			SpatialTermProbe._say("FELT_F1 standing=%d state=%s composure=%.2f chosen=%s flip_cells=%s" % [
				standing, str(state[0]), float(expression["composure"]), cell["chosen"], flip["cells"]])
	SpatialTermProbe._say("### FELT F-2 capacity and option count (board B1) by Standing and state")
	var f2_board: Dictionary = build(def)
	for standing: int in FELT_STANDINGS:
		for state: Array in FELT_STATES:
			var expression: Dictionary = _expression(config, bdata, standing, int(state[1]), int(state[2]))
			var mover: Dictionary = (expression["actor"] as Dictionary).duplicate(true)
			mover["standing"] = standing
			mover["fear"] = int(state[1])
			mover["morale"] = int(state[2])
			mover["_composure"] = float(expression["composure"])
			var base: Dictionary = MovementProfileService.derive_profile(mover, capacity_cfg)
			var profile: Dictionary = live._with_state_steps(base, mover, movement, bdata, float(mover["_composure"]))
			var generated: Dictionary = MovementOptionService.generate_options(
				f2_board["movement_context"] as Dictionary, profile, (f2_board["goals"] as Array)[0] as Dictionary)
			SpatialTermProbe._say("FELT_F2 standing=%d state=%s base_capacity=%d capacity=%d options=%d" % [
				standing, str(state[0]), int(base["capacity"]), int(profile["capacity"]), (generated.get("options", []) as Array).size()])
	SpatialTermProbe._say("### FELT F-3 style score of the forceful route shape at production Judgment, without and with growth")
	var style_cfg: Dictionary = (bdata["actor"] as Dictionary)["movement_style_weights"] as Dictionary
	for standing: int in [1, 6, 9]:
		var expression: Dictionary = _expression(config, bdata, standing, 0, 50)
		var actor: Dictionary = expression["actor"] as Dictionary
		var judgment: float = float(expression["judgment"])
		var growth: Dictionary = BehaviorArbiter.new({}, movement)._style_growth(judgment)
		var plain: float = MovementStyleService.style_alignment_score("forceful", "advance", actor["vector_scores"] as Dictionary,
			"", actor.get("traits", {}) as Dictionary, 0.0, 0.0, 0.0, 0.0, style_cfg)
		var grown: float = MovementStyleService.style_alignment_score("forceful", "advance", actor["vector_scores"] as Dictionary,
			"", actor.get("traits", {}) as Dictionary, 0.0, 0.0, 0.0, 0.0, style_cfg, float(growth["vector_mul"]), float(growth["trait_mul"]))
		SpatialTermProbe._say("FELT_F3 standing=%d judgment=%.3f vector_mul=%.3f trait_mul=%.3f score=%.3f grown=%.3f" % [
			standing, judgment, float(growth["vector_mul"]), float(growth["trait_mul"]), plain, grown])
	SpatialTermProbe._say("### FELT F-4 afraid Echo, standing 3, pressed: cells of the chosen route with the switches off and on (stop-short is not modelled here)")
	var off_movement: Dictionary = movement.duplicate(true)
	for key: String in ["lean", "steps", "style_growth"]:
		((off_movement["felt_state"] as Dictionary)[key] as Dictionary)["enabled"] = false
	var pressed: Array = FELT_STATES[2]
	var expression: Dictionary = _expression(config, bdata, 3, int(pressed[1]), int(pressed[2]))
	for arm: Array in [["off", off_movement], ["on", movement]]:
		var mover: Dictionary = (expression["actor"] as Dictionary).duplicate(true)
		mover["standing"] = 3
		mover["fear"] = int(pressed[1])
		mover["morale"] = int(pressed[2])
		mover["_composure"] = float(expression["composure"])
		var base: Dictionary = MovementProfileService.derive_profile(mover, capacity_cfg)
		var profile: Dictionary = live._with_state_steps(base, mover, arm[1] as Dictionary, bdata, float(mover["_composure"]))
		var arm_def: Dictionary = def.duplicate(true)
		arm_def["capacity"] = int(profile["capacity"])
		var board: Dictionary = build(arm_def)
		board["judgment"] = float(expression["judgment"])
		board["composure"] = float(expression["composure"])
		board["morale"] = int(pressed[2])
		SpatialTermProbe._say("FELT_F4 arm=%s capacity=%d cells=%s" % [
			str(arm[0]), int(profile["capacity"]), _chosen_cells(config, balance, bdata, arm[1] as Dictionary, board, int(pressed[1]))])
