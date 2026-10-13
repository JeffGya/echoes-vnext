# res://core/realms/StageCounterfactualService.gd
# Who decided the first plan of a stage Advance (V2-DIRECTIVE-002 design 4, D-04, D-46).
# First plan only: target, entered cells of the first leg, effective steps, commitment depth and
# the predicted stop, all from the party cell. An Echo is named only when removing that Echo (and
# the bond edges it gives the others, D-26) changes that plan, and that plan is the real walk
# (confirm_walk, D-55). Read-only: every plan runs on a deep copy of the explore map. No RNG draw.
# Never calls SaveService.
class_name StageCounterfactualService
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const MovementPathServiceScript   := preload("res://core/movement/MovementPathService.gd")
const AdapterScript               := preload("res://core/movement/StagePartyMovementAdapter.gd")
const ExposureScript              := preload("res://core/movement/StageExposureMap.gd")
const StanceScript                := preload("res://core/movement/StagePartyStance.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger
## Plans with a changed party made by the latest name_deciders call. Test observable.
var dry_runs: int = 0
# The no-name cause of the latest name_deciders call, on its pre-walk copy. Set only when it named an Echo.
var _cause_if_unnamed: Callable = Callable()


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## First leg from `explore_map.party_pos` (an integer cell). Reads revealed situations and explored
## cells only (design 4 rule 10). `fixed_target` (a Dictionary) skips the target pick.
## Returns {target_id, path, effective_steps, commitment_depth, stop_kind, detour_refused}.
func plan_first_leg(explore_map: Dictionary, directive: Dictionary, stance: Dictionary, walkable: Dictionary,
		explored: Dictionary, stage: Dictionary, region: Dictionary = {}, fixed_target: Variant = null) -> Dictionary:
	var here: Dictionary = ActiveStageService.stage_integer_cell(explore_map.get("party_pos", {}))
	var target: Dictionary = fixed_target if fixed_target is Dictionary else _pick_target(
		explore_map, directive, stance, walkable, explored, stage, region)
	var plan := {
		"target_id": str(target.get("id", "")),
		"path": [],
		"effective_steps": int(stance["effective_steps"]),
		"commitment_depth": int(stance["commitment_depth"]),
		"stop_kind": "",
		"detour_refused": false,
	}
	if target.is_empty():
		return plan
	var goal: Dictionary = ActiveStageService.stage_integer_cell(target.get("pos", {}))
	if goal == here:
		return plan

	var stance_cfg := ConfigService.get_party_stance_cfg(config_service)
	var exposure_cfg_v: Variant = stance_cfg.get("exposure", {})
	var exposure_cfg: Dictionary = exposure_cfg_v if exposure_cfg_v is Dictionary else {}
	var costs := ExposureScript.to_terrain_costs(
		ExposureScript.build(explore_map, ConfigService.get_situation_category_cfg(config_service), exposure_cfg),
		float((stance["dials"] as Dictionary)["exposure_tolerance"]),
		int(ExposureScript.cfg_num(exposure_cfg, "price_scale")))
	# Same route rule as the live loop (StageExploreTurnService.advance_turn).
	var route := MovementPathServiceScript.shortest_path(here, goal, walkable, costs, {}, {})
	if not costs.is_empty() and bool(route.get("reachable", false)):
		var plain := MovementPathServiceScript.shortest_path(here, goal, walkable, {}, {}, {})
		if not ExposureScript.detour_within_slack((route.get("path", []) as Array).size(),
				(plain.get("path", []) as Array).size(), ConfigService.get_movement_slack_cfg(config_service)):
			route = plain
			plan["detour_refused"] = true
	if not bool(route.get("reachable", false)):
		plan["stop_kind"] = "no_route"
		return plan

	var known := {"situations": _revealed(explore_map)}
	var cells_v: Variant = route.get("path", [])
	var cells: Array = cells_v if cells_v is Array else []
	for i in mini(cells.size(), int(plan["commitment_depth"])):
		var cell: Dictionary = ActiveStageService.stage_integer_cell(cells[i])
		plan["path"].append(cell)
		if ActiveStageService.situation_blocks_step(known, cell, str(plan["target_id"])):
			plan["stop_kind"] = "interrupted"
			return plan
		if cell == goal:
			plan["stop_kind"] = "reached_destination"
			return plan
	plan["stop_kind"] = "capacity_spent" if int(plan["commitment_depth"]) >= int(plan["effective_steps"]) else "commitment_spent"
	return plan


## How many of the three material groups differ (design 4 rule 8): path (with target), steps, stop.
## A different depth counts only when it cuts the walk of either plan before the stop (D-54 S1).
func plan_changes(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	if a["path"] != b["path"] or a["target_id"] != b["target_id"]:
		n += 1
	if a["effective_steps"] != b["effective_steps"] \
			or (a["commitment_depth"] != b["commitment_depth"] and (_depth_cuts(a) or _depth_cuts(b))):
		n += 1
	if a["stop_kind"] != b["stop_kind"]:
		n += 1
	return n


func plans_differ(a: Dictionary, b: Dictionary) -> bool:
	return plan_changes(a, b) > 0


# The walk ended on the depth, not on the stop it was walking to.
static func _depth_cuts(plan: Dictionary) -> bool:
	return plan["stop_kind"] == "commitment_spent" or plan["stop_kind"] == "capacity_spent"


## Names the deciders of the first plan of the current stage. Writes nothing.
## Returns {plan, contributor_ids, decisive_contributor_id, reason_class, cause, dry_runs}.
## cause: "echo" when an Echo is named, else terrain / objective / situation / party / directive,
## or "" when there is no target (no Advance happens).
func name_deciders(directive: Dictionary, t: int) -> Dictionary:
	dry_runs = 0
	_cause_if_unnamed = Callable()
	var out := {"plan": {}, "contributor_ids": [], "decisive_contributor_id": "", "reason_class": "", "cause": "", "dry_runs": 0}
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return out
	var em_v: Variant = stage.get("explore_map", {})
	var em: Dictionary = (em_v as Dictionary).duplicate(true) if em_v is Dictionary else {}
	var walkable := ActiveStageService.explore_walkable(em)
	var here := ActiveStageService.stage_integer_cell(em.get("party_pos", {}))
	em["party_pos"] = here
	var explored_v: Variant = em.get("explored_cells", {})
	var explored: Dictionary = explored_v if explored_v is Dictionary else {}
	# The live loop lifts the origin fog before its first in-loop target pick.
	ActiveStageService.lift_fog_at_cell(here, int(directive.get("reveal_radius", directive.get("passive_reveal_radius", 2))), walkable, explored)
	em["explored_cells"] = explored
	var region := ActiveStageService.stage_reachable_costs(here, walkable)

	var cfg_data := _cfg_data()
	var stance_cfg := ConfigService.get_party_stance_cfg(config_service)
	var echoes := StanceScript.read_party(flow_ctx.save_data, cfg_data)
	var real_stance := StanceScript.build(echoes, directive, stance_cfg, false)
	var target := _pick_target(em, directive, real_stance, walkable, explored, stage, region)
	var real := plan_first_leg(em, directive, real_stance, walkable, explored, stage, region, target)
	out["plan"] = real
	if target.is_empty():
		return out
	# The bend only orders pool candidates (select_objective_target). It cannot fill or empty the
	# pool, so a frontier or passed-objective target is the same for every party.
	var tier := int(target.get("_movement_tier", AdapterScript.TIER_FRONTIER))
	var fixed: Variant = null if tier == AdapterScript.TIER_OBJECTIVE or tier == AdapterScript.TIER_WEIGHTED else target
	var plan_for := func(party: Array) -> Dictionary:
		dry_runs += 1
		return plan_first_leg(em, directive, StanceScript.build(party, directive, stance_cfg, false), walkable, explored, stage, region, fixed)

	var cf_v: Variant = stance_cfg.get("counterfactual", {})
	var cf: Dictionary = cf_v if cf_v is Dictionary else {}
	var classes_v: Variant = cf.get("reason_classes", [])
	var classes: Array = classes_v if classes_v is Array else []
	var cap := echoes.size() + int(ExposureScript.cfg_num(cf, "extra_replans_per_reason_class")) * classes.size()

	var deciders: Array = []
	for id in real_stance["candidates"]:
		if dry_runs >= cap:
			break
		var n := plan_changes(real, plan_for.call(StanceScript.read_party(flow_ctx.save_data, cfg_data, str(id))))
		if n > 0:
			deciders.append({"id": str(id), "n": n, "weight": _contribution(real_stance["leans"][id], stance_cfg)})

	if deciders.is_empty():
		out["cause"] = _cause_without_echo(real, target, here, walkable, real_stance, plan_for, dry_runs < cap)
	else:
		# Design 4 rule 6: most groups changed, then the largest contribution, then the lowest id (D-47 J3).
		deciders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["n"] != b["n"]:
				return a["n"] > b["n"]
			if a["weight"] != b["weight"]:
				return a["weight"] > b["weight"]
			return a["id"] < b["id"])
		var ids: Array = []
		for d in deciders:
			ids.append(d["id"])
		ids.sort()
		out["contributor_ids"] = ids
		out["decisive_contributor_id"] = deciders[0]["id"]
		out["reason_class"] = _reason_class(str(deciders[0]["id"]), echoes, classes, stance_cfg, real, plan_for, cap)
		out["cause"] = "echo"
		_cause_if_unnamed = func() -> String:
			return _cause_without_echo(real, target, here, walkable, real_stance, plan_for, dry_runs < cap)
	out["dry_runs"] = dry_runs
	logger.debug(t, "stage.counterfactual.named", "first-plan naming", {
		"cause": out["cause"], "reason_class": out["reason_class"], "dry_runs": dry_runs, "cap": cap, "plan": real,
	})
	return out


## Keeps the name of `why` (this instance's latest name_deciders result) only when its base plan is
## the real walk (D-55). Else names nobody and gives the no-name cause. `walk` is the live Advance:
## {target_id (first leg), path (every entered cell), stop_kind (the loop's final reason),
## effective_steps, commitment_depth}.
func confirm_walk(why: Dictionary, walk: Dictionary, t: int) -> Dictionary:
	if str(why.get("cause", "")) != "echo" or plan_is_walk(why["plan"], walk):
		return why
	var out := why.duplicate()
	out["contributor_ids"] = []
	out["decisive_contributor_id"] = ""
	out["reason_class"] = ""
	out["cause"] = _cause_if_unnamed.call()
	out["dry_runs"] = dry_runs
	logger.debug(t, "stage.counterfactual.walk_differs", "base plan is not the real walk; no name", {
		"cause": out["cause"], "plan_path": (why["plan"] as Dictionary)["path"], "walk_path": walk.get("path", []),
	})
	return out


## Equal: same first-leg target, steps and depth; the walk enters the plan cells first, in order;
## the walk ends where the plan ends with the same stop kind, or walks on only past a reached target.
static func plan_is_walk(plan: Dictionary, walk: Dictionary) -> bool:
	var path: Array = plan["path"]
	var cells: Array = walk.get("path", [])
	if str(plan["target_id"]) != str(walk.get("target_id", "")) \
			or int(plan["effective_steps"]) != int(walk.get("effective_steps", -1)) \
			or int(plan["commitment_depth"]) != int(walk.get("commitment_depth", -1)) \
			or cells.size() < path.size() or cells.slice(0, path.size()) != path:
		return false
	if cells.size() == path.size():
		return str(plan["stop_kind"]) == str(walk.get("stop_kind", ""))
	return str(plan["stop_kind"]) == "reached_destination"


func _pick_target(em: Dictionary, directive: Dictionary, stance: Dictionary, walkable: Dictionary,
		explored: Dictionary, stage: Dictionary, region: Dictionary) -> Dictionary:
	var session := ActiveStageService.new(flow_ctx, config_service, logger)
	return session.find_explore_target(em, directive, walkable, explored, stage, stance.get("category_bend", {}), region)


## Neutralises one class on the named Echo and keeps the class whose removal changes the most;
## ties keep config order. When no single class changes the plan, the Echo decided through the
## party mean alone: "steadied" (D-54 S2), which needs no dry run.
func _reason_class(id: String, echoes: Array, classes: Array, stance_cfg: Dictionary, real: Dictionary,
		plan_for: Callable, cap: int) -> String:
	var ramps_v: Variant = stance_cfg.get("state_ramps", {})
	var neutral := {
		"calling": ["family", ""],
		"temperament": ["style_score", 0.0],
		"fear": ["fear", 0.0],
		"morale": ["morale", ExposureScript.cfg_num(ramps_v if ramps_v is Dictionary else {}, "morale_neutral")],
	}
	var best := ""
	var best_n := 0
	for cls in classes:
		if not neutral.has(cls) or dry_runs >= cap:
			continue
		var party: Array = []
		for e in echoes:
			var copy: Dictionary = (e as Dictionary).duplicate()
			if str(copy["id"]) == id:
				copy[neutral[cls][0]] = neutral[cls][1]
			party.append(copy)
		var n := plan_changes(real, plan_for.call(party))
		if n > best_n:
			best = str(cls)
			best_n = n
	if best.is_empty() and classes.has("steadied"):
		return "steadied"
	return best


## Cause order when no Echo is named: terrain, objective, situation, then party or directive.
func _cause_without_echo(real: Dictionary, target: Dictionary, here: Dictionary, walkable: Dictionary,
		real_stance: Dictionary, plan_for: Callable, may_dry_run: bool) -> String:
	if real["stop_kind"] == "no_route" or bool(real["detour_refused"]) or _only_way(real, target, here, walkable):
		return "terrain"
	if bool(target.get("is_objective", false)):
		return "objective"
	if not bool(target.get("is_frontier", false)):
		return "situation"
	# Leave-one-out misses Echoes that decide only together (design 4 rule 7): compare with no party.
	if real_stance["candidates"].is_empty() or not may_dry_run:
		return "directive"
	return "party" if plans_differ(real, plan_for.call([])) else "directive"


## True when no entered cell can be avoided: without it the goal is unreachable or past the slack.
func _only_way(real: Dictionary, target: Dictionary, here: Dictionary, walkable: Dictionary) -> bool:
	var path: Array = real["path"]
	if path.is_empty():
		return false
	var goal := ActiveStageService.stage_integer_cell(target.get("pos", {}))
	var plain_len := (MovementPathServiceScript.shortest_path(here, goal, walkable, {}, {}, {}).get("path", []) as Array).size()
	var slack := ConfigService.get_movement_slack_cfg(config_service)
	for cell in path:
		if cell == goal:
			continue
		var without := walkable.duplicate()
		without.erase("%d,%d" % [int(cell["col"]), int(cell["row"])])
		var alt := MovementPathServiceScript.shortest_path(here, goal, without, {}, {}, {})
		if bool(alt.get("reachable", false)) and ExposureScript.detour_within_slack(
				(alt.get("path", []) as Array).size(), plain_len, slack):
			return false
	return true


func _contribution(leans: Dictionary, stance_cfg: Dictionary) -> float:
	var bounds_v: Variant = stance_cfg.get("bounds", {})
	var bounds: Dictionary = bounds_v if bounds_v is Dictionary else {}
	var sum := 0.0
	for dial in leans:
		var b := ExposureScript.cfg_num(bounds, str(dial))
		if b > 0.0:
			sum += absf(float(leans[dial])) / b
	return sum


func _revealed(explore_map: Dictionary) -> Array:
	var out: Array = []
	var sits_v: Variant = explore_map.get("situations", [])
	for s in (sits_v as Array if sits_v is Array else []):
		if s is Dictionary and bool((s as Dictionary).get("revealed", false)):
			out.append(s)
	return out


func _cfg_data() -> Dictionary:
	if config_service == null:
		return {}
	var data_v: Variant = config_service.get_balance().get("data", {})
	return data_v if data_v is Dictionary else {}
