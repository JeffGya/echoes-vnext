class_name CombatPressureService
extends RefCounted

## Pure dormant adapter from perceived combat pressure to complete movement goals.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const PressureContract = preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

const BUCKET_DIRECT := "direct"
const BUCKET_TACTICAL := "tactical"
const BUCKET_SAFETY := "safety"
const LOW := 0.25
const NORMAL := 0.50
const HIGH := 0.75
const CRITICAL := 1.00


static func build_goals(context: Dictionary) -> Dictionary:
	var context_result: Dictionary = ContextContract.validate(context)
	if not bool(context_result["valid"]):
		return _failure(
			"invalid_context.%s" % str(context_result["reason"]),
			"context.%s" % str(context_result["field"])
		)
	var pressure: Dictionary = context["objective_pressure"] as Dictionary
	var pressure_result: Dictionary = PressureContract.validate(pressure)
	if not bool(pressure_result["valid"]):
		return _failure(
			"invalid_pressure.%s" % str(pressure_result["reason"]),
			"objective_pressure.%s" % str(pressure_result["field"])
		)
	var source_result: Dictionary = _validate_input_sources(pressure["pressure_sources"] as Array)
	if not bool(source_result["valid"]):
		return source_result
	var role_result: Dictionary = _validate_factual_role(context, pressure)
	if not bool(role_result["valid"]):
		return role_result
	if str(pressure["mover_alignment"]) == "objective" and not _is_authored_objective_mover(pressure):
		return {"valid": true, "goals": [], "reason": "", "field": ""}

	var candidates: Array = []
	var mode: String = str(pressure["mode"])
	match mode:
		"combat", "endure":
			_add_ordinary_combat(candidates, context, pressure, "baseline")
		"purify_shrine":
			_add_purify(candidates, context, pressure)
		"recover":
			_add_recover(candidates, context, pressure)
		"protect":
			_add_protect(candidates, context, pressure)
		"pursue":
			_add_pursue(candidates, context, pressure)
		"guide_spirit":
			_add_guide(candidates, context, pressure)

	var validation_result: Dictionary = _validate_candidates(candidates, context["origin"] as Dictionary)
	if not bool(validation_result["valid"]):
		return validation_result
	var shortlisted: Array = []
	for bucket: String in [BUCKET_DIRECT, BUCKET_TACTICAL, BUCKET_SAFETY]:
		var bucket_candidates: Array = candidates.filter(
			func(item: Variant) -> bool: return str((item as Dictionary)["bucket"]) == bucket
		)
		bucket_candidates.sort_custom(Callable(CombatPressureService, "_candidate_before"))
		if not bucket_candidates.is_empty():
			shortlisted.append((bucket_candidates[0] as Dictionary)["goal"])
	shortlisted.sort_custom(Callable(CombatPressureService, "_final_goal_before"))
	return {"valid": true, "goals": shortlisted.duplicate(true), "reason": "", "field": ""}


static func _add_ordinary_combat(
	candidates: Array, context: Dictionary, pressure: Dictionary, goal_role: String
) -> void:
	for hostile_value: Variant in _hostiles(context):
		var hostile: Dictionary = hostile_value as Dictionary
		var region: Array = _adjacent_region(context, hostile["position"] as Dictionary, false)
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "advance", goal_role, region, HIGH, [str(hostile["id"])])
		_add_goal(candidates, BUCKET_SAFETY, context, pressure, "engage", goal_role, region, NORMAL, [str(hostile["id"])])


static func _add_purify(candidates: Array, context: Dictionary, pressure: Dictionary) -> void:
	if not bool(pressure["objective_known"]):
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "read", "baseline", pressure["search_region"] as Array, LOW, [])
		_add_truthful_engage(candidates, context, pressure)
		return
	var health: float = float(pressure["objective_health_ratio"])
	if health < 0.0 or health >= 0.5:
		_add_ordinary_combat(candidates, context, pressure, "baseline")
		return
	var alignment: String = str(pressure["mover_alignment"])
	var role: String = str(pressure["factual_role"])
	if role == "purifier":
		var adjacent: bool = _is_adjacent(context["origin"] as Dictionary, pressure["objective_position"] as Dictionary)
		if adjacent:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "hold", "purifier", [context["origin"]], CRITICAL, [str(pressure["objective_id"])])
		else:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "purifier", pressure["destination_region"] as Array, CRITICAL, [str(pressure["objective_id"])])
	elif alignment == "party":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "protect", "protector", pressure["destination_region"] as Array, HIGH, [str(pressure["objective_id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "blocker", pressure["approach_region"] as Array, HIGH, [str(pressure["objective_id"])])
	elif alignment == "hostile":
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "advance", "breaker", pressure["approach_region"] as Array, HIGH, [str(pressure["objective_id"])])
		_add_objective_engage(candidates, BUCKET_DIRECT, context, pressure, "breaker", NORMAL)
	_add_truthful_engage(candidates, context, pressure)


static func _add_recover(candidates: Array, context: Dictionary, pressure: Dictionary) -> void:
	var alignment: String = str(pressure["mover_alignment"])
	var role: String = str(pressure["factual_role"])
	if alignment == "party" and role == "holder":
		if _is_adjacent(context["origin"] as Dictionary, pressure["objective_position"] as Dictionary):
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "hold", "holder", [context["origin"]], CRITICAL, [str(pressure["objective_id"])])
		else:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "holder", pressure["destination_region"] as Array, CRITICAL, [str(pressure["objective_id"])])
	elif alignment == "party":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "runner", pressure["destination_region"] as Array, CRITICAL, [str(pressure["objective_id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "screener", pressure["approach_region"] as Array, HIGH, [str(pressure["objective_id"])])
	elif alignment == "hostile":
		var holder: Dictionary = _actor_by_id(context, str(pressure["holder_id"]))
		if _is_living_actor(holder):
			var holder_region: Array = _adjacent_region(context, holder["position"] as Dictionary, false)
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "breaker", holder_region, CRITICAL, [str(holder["id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "blocker", pressure["approach_region"] as Array, HIGH, [str(pressure["objective_id"])])
	_add_truthful_engage(candidates, context, pressure)


static func _add_protect(candidates: Array, context: Dictionary, pressure: Dictionary) -> void:
	var alignment: String = str(pressure["mover_alignment"])
	var role: String = str(pressure["factual_role"])
	if alignment == "hostile" and role == "carrier" and bool(pressure["totem_stolen"]):
		_add_ordinary_combat(candidates, context, pressure, "baseline")
		return
	if alignment == "party" and role == "holder":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "hold", "holder", [context["origin"]], CRITICAL, [str(pressure["objective_id"])])
	elif alignment == "party" and bool(pressure["totem_stolen"]):
		var carrier: Dictionary = _actor_by_id(context, str(pressure["carrier_id"]))
		if _is_living_actor(carrier):
			var carrier_region: Array = _adjacent_region(context, carrier["position"] as Dictionary, false)
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "pursue", "hunter", carrier_region, CRITICAL, [str(carrier["id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "cut_off", "blocker", pressure["approach_region"] as Array, HIGH, [str(pressure["carrier_id"])])
	elif alignment == "party":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "protect", "protector", pressure["destination_region"] as Array, HIGH, [str(pressure["objective_id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "blocker", pressure["approach_region"] as Array, HIGH, [str(pressure["objective_id"])])
	elif alignment == "hostile":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "custody_threat", pressure["destination_region"] as Array, CRITICAL, [str(pressure["objective_id"])])
		_add_objective_engage(candidates, BUCKET_TACTICAL, context, pressure, "breaker", NORMAL)
	_add_truthful_engage(candidates, context, pressure)


static func _add_pursue(candidates: Array, context: Dictionary, pressure: Dictionary) -> void:
	var alignment: String = str(pressure["mover_alignment"])
	var role: String = str(pressure["factual_role"])
	if role == "quarry":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "withdraw", "quarry", pressure["destination_region"] as Array, CRITICAL, [])
		return
	if alignment == "party":
		var quarry: Dictionary = _actor_by_id(context, str(pressure["quarry_id"]))
		var engaged_elsewhere: Array = []
		if _is_living_actor(quarry) and bool(quarry["is_quarry"]):
			var quarry_region: Array = _adjacent_region(context, quarry["position"] as Dictionary, false)
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "pursue", "hunter", quarry_region, CRITICAL, [str(quarry["id"])])
			engaged_elsewhere.append(str(quarry["id"]))
		if not (pressure["fallback_region"] as Array).is_empty():
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "cut_off", "blocker", pressure["fallback_region"] as Array, HIGH, [str(pressure["quarry_id"])])
		else:
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "blocker", pressure["approach_region"] as Array, HIGH, [str(pressure["quarry_id"])])
		_add_truthful_engage(candidates, context, pressure, engaged_elsewhere)


static func _add_guide(candidates: Array, context: Dictionary, pressure: Dictionary) -> void:
	var alignment: String = str(pressure["mover_alignment"])
	var role: String = str(pressure["factual_role"])
	var spirit: Dictionary = _actor_by_id(context, str(pressure["spirit_id"]))
	var spirit_is_active: bool = (
		_is_living_actor(spirit)
		and bool(spirit.get("is_spirit", false))
	)
	if role == "spirit" and not bool(pressure["spirit_joins_battle"]):
		if spirit_is_active:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "spirit", pressure["destination_region"] as Array, CRITICAL, [str(pressure["objective_id"])])
		return
	if role == "spirit" and bool(pressure["spirit_joins_battle"]):
		if spirit_is_active:
			_add_ordinary_combat(candidates, context, pressure, "spirit")
		return
	if alignment == "party":
		if spirit_is_active:
			var purpose: String = "escort" if str(pressure["guide_mode"]) == "escort" else "protect"
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, purpose, "protector", pressure["destination_region"] as Array, HIGH, [str(pressure["spirit_id"])])
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "rear_guard", pressure["approach_region"] as Array, HIGH, [str(pressure["spirit_id"])])
		_add_truthful_engage(candidates, context, pressure)
	elif alignment == "hostile":
		if spirit_is_active:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "escort_threat", pressure["destination_region"] as Array, CRITICAL, [str(pressure["spirit_id"])])
			_add_actor_engage(candidates, BUCKET_TACTICAL, context, pressure, "breaker", NORMAL, str(pressure["spirit_id"]))
		_add_truthful_engage(candidates, context, pressure, [str(pressure["spirit_id"])])
	else:
		_add_truthful_engage(candidates, context, pressure)


static func _add_truthful_engage(
	candidates: Array, context: Dictionary, pressure: Dictionary, excluded_actor_ids: Array = []
) -> void:
	for hostile_value: Variant in _hostiles(context):
		var hostile: Dictionary = hostile_value as Dictionary
		if excluded_actor_ids.has(str(hostile["id"])):
			continue
		var region: Array = _adjacent_region(context, hostile["position"] as Dictionary, false)
		_add_goal(candidates, BUCKET_SAFETY, context, pressure, "engage", "baseline", region, NORMAL, [str(hostile["id"])])


static func _add_objective_engage(
	candidates: Array,
	bucket: String,
	context: Dictionary,
	pressure: Dictionary,
	goal_role: String,
	urgency: float
) -> void:
	var objective: Dictionary = _actor_by_id(context, str(pressure["objective_id"]))
	if objective.is_empty():
		return
	var relationship: String = str((context["relationships"] as Dictionary).get(str(objective["id"]), ""))
	if relationship != "hostile" or bool(objective["is_dead"]) or bool(objective["is_ko"]):
		return
	var region: Array = _adjacent_region(context, objective["position"] as Dictionary, false)
	_add_goal(candidates, bucket, context, pressure, "engage", goal_role, region, urgency, [str(objective["id"])])


static func _add_actor_engage(
	candidates: Array,
	bucket: String,
	context: Dictionary,
	pressure: Dictionary,
	goal_role: String,
	urgency: float,
	actor_id: String
) -> void:
	var actor: Dictionary = _actor_by_id(context, actor_id)
	if not _is_living_actor(actor):
		return
	if str((context["relationships"] as Dictionary).get(actor_id, "")) != "hostile":
		return
	var region: Array = _adjacent_region(context, actor["position"] as Dictionary, false)
	_add_goal(candidates, bucket, context, pressure, "engage", goal_role, region, urgency, [actor_id])


static func _add_goal(
	candidates: Array,
	bucket: String,
	context: Dictionary,
	pressure: Dictionary,
	purpose: String,
	goal_role: String,
	region_input: Array,
	urgency: float,
	relevant_input: Array
) -> void:
	var region: Array = _truthful_region(context, region_input, purpose == "hold")
	if region.is_empty():
		return
	var relevant: Array = V.canonical_string_array(relevant_input.filter(func(value: Variant) -> bool: return not str(value).is_empty()))
	var primary: Dictionary = _primary_plan(context, pressure, purpose, relevant)
	if primary.is_empty():
		return
	var fallback: Dictionary = {} if str(primary["type"]) == "actor.idle" else ActionPlan.build("actor.idle")
	var anchor: Dictionary = region[0] as Dictionary
	var goal_id := "goal.%s.%s.%s.c%dr%d" % [str(pressure["mode"]), purpose, goal_role, int(anchor["col"]), int(anchor["row"])]
	var sources: Array = _goal_sources(pressure, goal_role, relevant)
	var goal: Dictionary = GoalContract.build(
		goal_id,
		purpose,
		region,
		urgency,
		_objective_progress(pressure),
		relevant,
		sources,
		primary,
		fallback
	)
	candidates.append({"bucket": bucket, "goal": goal})


static func _primary_plan(
	context: Dictionary, pressure: Dictionary, purpose: String, relevant: Array
) -> Dictionary:
	var target_id: String = str(relevant[0]) if not relevant.is_empty() else ""
	match purpose:
		"advance":
			if str(pressure["factual_role"]) == "purifier" and float(pressure["objective_health_ratio"]) >= 0.0 and float(pressure["objective_health_ratio"]) < 0.5:
				return ActionPlan.build("actor.purify_shrine", str(pressure["objective_id"]))
			return ActionPlan.build("actor.move", target_id)
		"engage", "pursue":
			return ActionPlan.build("melee_attack", target_id)
		"intercept", "hold", "cut_off":
			return ActionPlan.build("actor.guard")
		"protect":
			var target: Dictionary = _actor_by_id(context, target_id)
			if target.is_empty() or bool(target.get("is_structure", false)):
				return ActionPlan.build("actor.guard")
			return ActionPlan.build("protect_ally", target_id)
		"reposition", "regroup", "withdraw":
			return ActionPlan.build("actor.move", target_id)
		"read":
			return ActionPlan.build("actor.idle")
		"escort":
			return ActionPlan.build("protect_ally", target_id)
	return {}


static func _truthful_region(context: Dictionary, input_region: Array, allow_origin: bool) -> Array:
	var result: Array = []
	var origin: Dictionary = context["origin"] as Dictionary
	var perceived: Dictionary = context["perceived_planning_cells"] as Dictionary
	var walkable: Dictionary = context["authoritative_walkable"] as Dictionary
	var occupancy: Dictionary = context["occupancy"] as Dictionary
	for cell_value: Variant in V.canonical_position_array(input_region):
		if not cell_value is Dictionary:
			continue
		var cell: Dictionary = cell_value as Dictionary
		if not bool(V.validate_position(cell, "region")["valid"]):
			continue
		var key: String = V.canonical_cell_key(cell)
		if not bool(perceived.get(key, false)) or not bool(walkable.get(key, false)):
			continue
		if cell == origin:
			if allow_origin:
				result.append(cell.duplicate(true))
			continue
		if occupancy.has(key):
			continue
		result.append(cell.duplicate(true))
	return V.canonical_position_array(result)


static func _adjacent_region(context: Dictionary, center: Dictionary, allow_origin: bool) -> Array:
	var cells: Array = []
	for col_delta: int in range(-1, 2):
		for row_delta: int in range(-1, 2):
			if col_delta == 0 and row_delta == 0:
				continue
			cells.append({"col": int(center["col"]) + col_delta, "row": int(center["row"]) + row_delta})
	return _truthful_region(context, cells, allow_origin)


static func _hostiles(context: Dictionary) -> Array:
	var result: Array = []
	var actors: Array = (context["perceived_actors"] as Array).duplicate(true)
	actors.sort_custom(func(a: Variant, b: Variant) -> bool: return str((a as Dictionary)["id"]) < str((b as Dictionary)["id"]))
	for actor_value: Variant in actors:
		var actor: Dictionary = actor_value as Dictionary
		if str((context["relationships"] as Dictionary).get(str(actor["id"]), "")) == "hostile" and _is_living_actor(actor) and not bool(actor["is_structure"]):
			result.append(actor)
	return result


static func _is_authored_objective_mover(pressure: Dictionary) -> bool:
	var mode: String = str(pressure["mode"])
	var role: String = str(pressure["factual_role"])
	if mode == "pursue" and role == "quarry":
		return true
	if mode == "guide_spirit" and role == "spirit" and not bool(pressure["spirit_joins_battle"]):
		return true
	return false


static func _actor_by_id(context: Dictionary, actor_id: String) -> Dictionary:
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if str(actor["id"]) == actor_id:
			return actor
	return {}


static func _is_living_actor(actor: Dictionary) -> bool:
	return not actor.is_empty() and not bool(actor["is_dead"]) and not bool(actor["is_ko"])


static func _is_adjacent(a: Dictionary, b: Dictionary) -> bool:
	return max(abs(int(a["col"]) - int(b["col"])), abs(int(a["row"]) - int(b["row"]))) == 1


static func _objective_progress(pressure: Dictionary) -> float:
	var required: int = int(pressure["progress_required"])
	if required <= 0:
		return 0.0
	return clampf(float(pressure["progress_current"]) / float(required), 0.0, 1.0)


static func _goal_sources(pressure: Dictionary, goal_role: String, relevant: Array) -> Array:
	var sources: Array = (pressure["pressure_sources"] as Array).duplicate()
	sources.append("mode.%s" % str(pressure["mode"]))
	sources.append("role.%s" % goal_role)
	for actor_value: Variant in relevant:
		sources.append("actor.%s" % str(actor_value))
	if not str(pressure["objective_id"]).is_empty():
		sources.append("objective.%s" % str(pressure["objective_id"]))
	if not bool(pressure["objective_known"]):
		sources.append("state.objective_unknown")
	elif float(pressure["objective_health_ratio"]) >= 0.0 and float(pressure["objective_health_ratio"]) < 0.5:
		sources.append("state.objective_low")
	if bool(pressure["totem_stolen"]):
		sources.append("state.totem_stolen")
	if bool(pressure["escort_started"]):
		sources.append("state.escort_started")
	if str(pressure["mode"]) == "guide_spirit":
		sources.append("state.spirit_joined" if bool(pressure["spirit_joins_battle"]) else "state.spirit_nonjoining")
	return V.canonical_string_array(sources)


static func _validate_input_sources(sources: Array) -> Dictionary:
	for source_value: Variant in sources:
		var source: String = str(source_value)
		if not _valid_source(source):
			return _failure("invalid_pressure_source", "objective_pressure.pressure_sources")
	return _ok()


static func _valid_source(source: String) -> bool:
	for prefix: String in ["mode.", "role.", "actor.", "objective.", "state."]:
		if source.begins_with(prefix) and source.length() > prefix.length():
			return V.is_semantic_token(source)
	return false


static func _validate_factual_role(context: Dictionary, pressure: Dictionary) -> Dictionary:
	var mover_id: String = str(context["mover_id"])
	var matches: Array = []
	for role: String in ["purifier", "holder", "carrier", "quarry", "spirit"]:
		if str(pressure["%s_id" % role]) == mover_id:
			matches.append(role)
	var factual_role: String = str(pressure["factual_role"])
	if matches.is_empty():
		if factual_role != "baseline":
			return _failure("factual_role_mover_mismatch", "objective_pressure.factual_role")
	else:
		if matches.size() != 1 or factual_role != str(matches[0]):
			return _failure("contradictory_factual_roles", "objective_pressure.factual_role")
	var mover: Dictionary = _actor_by_id(context, mover_id)
	if mover.is_empty():
		return _failure("mover_fact_missing", "context.perceived_actors")
	if factual_role == "quarry" and not bool(mover["is_quarry"]):
		return _failure("quarry_fact_mismatch", "context.perceived_actors")
	if factual_role == "spirit" and not bool(mover["is_spirit"]):
		return _failure("spirit_fact_mismatch", "context.perceived_actors")
	return _ok()


static func _validate_candidates(candidates: Array, mover_origin: Dictionary) -> Dictionary:
	var mechanics: Dictionary = {}
	for index: int in range(candidates.size()):
		var candidate: Dictionary = candidates[index] as Dictionary
		var goal: Dictionary = candidate["goal"] as Dictionary
		var result: Dictionary = GoalContract.validate(goal, mover_origin)
		if not bool(result["valid"]):
			return _failure(
				"invalid_goal.%s" % str(result["reason"]),
				"goals.%d.%s" % [index, str(result["field"])]
			)
		for source_value: Variant in goal["pressure_sources"] as Array:
			if not _valid_source(str(source_value)):
				return _failure("invalid_goal_pressure_source", "goals.%d.pressure_sources" % index)
		var mechanics_key: String = str([
			goal["purpose"], goal["destination_region"], goal["planned_primary"], goal["declared_fallback"],
		])
		if mechanics.has(mechanics_key) and mechanics[mechanics_key] != goal:
			return _failure("contradictory_duplicate_mechanics", "goals.%d" % index)
		mechanics[mechanics_key] = goal
	return _ok()


static func _candidate_before(a: Variant, b: Variant) -> bool:
	var ga: Dictionary = (a as Dictionary)["goal"] as Dictionary
	var gb: Dictionary = (b as Dictionary)["goal"] as Dictionary
	if float(ga["urgency"]) != float(gb["urgency"]):
		return float(ga["urgency"]) > float(gb["urgency"])
	if float(ga["objective_progress"]) != float(gb["objective_progress"]):
		return float(ga["objective_progress"]) > float(gb["objective_progress"])
	var purpose_a: int = GoalContract.PURPOSES.find(str(ga["purpose"]))
	var purpose_b: int = GoalContract.PURPOSES.find(str(gb["purpose"]))
	if purpose_a != purpose_b:
		return purpose_a < purpose_b
	var relevant_a: String = str(ga["relevant_actors"])
	var relevant_b: String = str(gb["relevant_actors"])
	if relevant_a != relevant_b:
		return relevant_a < relevant_b
	var region_order: int = _compare_regions(
		ga["destination_region"] as Array,
		gb["destination_region"] as Array
	)
	if region_order != 0:
		return region_order < 0
	return str(ga["goal_id"]) < str(gb["goal_id"])


static func _final_goal_before(a: Variant, b: Variant) -> bool:
	var ga: Dictionary = a as Dictionary
	var gb: Dictionary = b as Dictionary
	if float(ga["urgency"]) != float(gb["urgency"]):
		return float(ga["urgency"]) > float(gb["urgency"])
	return str(ga["goal_id"]) < str(gb["goal_id"])


static func _compare_regions(a: Array, b: Array) -> int:
	var shared_size: int = mini(a.size(), b.size())
	for index: int in range(shared_size):
		var position_a: Dictionary = a[index] as Dictionary
		var position_b: Dictionary = b[index] as Dictionary
		if int(position_a["col"]) != int(position_b["col"]):
			return -1 if int(position_a["col"]) < int(position_b["col"]) else 1
		if int(position_a["row"]) != int(position_b["row"]):
			return -1 if int(position_a["row"]) < int(position_b["row"]) else 1
	if a.size() == b.size():
		return 0
	return -1 if a.size() < b.size() else 1


static func _ok() -> Dictionary:
	return {"valid": true, "goals": [], "reason": "", "field": ""}


static func _failure(reason: String, field: String) -> Dictionary:
	return {"valid": false, "goals": [], "reason": reason, "field": field}
