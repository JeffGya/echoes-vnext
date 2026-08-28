# res://core/movement/LiveMovementContextService.gd
# V2-INFRA-003 Phase 6 Slice 6G: the LIVE movement helper family, moved VERBATIM out of
# core/runtime/FlowRuntime.gd (the contiguous block that sat at :1180-:2092, 913 lines).
#
# WHAT THIS IS. Everything that turns the live encounter (EncounterContext + combat_state +
# the data.combat.movement config subtree) into the inputs the already-existing pure movement
# services demand, and then applies the one result they are not allowed to apply themselves.
# It is the ADAPTER between live combat state and the DORMANT-by-design pure layer:
#
#   live ectx/combat_state ──> [this file] ──> MovementContext / MovementProfile /
#                                             CombatPressureSnapshot / MovementIntent /
#                                             MovementOption
#                                                  │
#                              MovementOptionService, MovementPathService,
#                              CombatPressureService, MovementProfileService,
#                              PursueEscapeService, CombatActivationService  (all pure)
#                                                  │
#   actor dict writes  <── [this file] ──────────────┘   (+ LiveHazardOutcomeService)
#
# WHY HERE, IN core/movement/. Every one of the 27 functions exists solely to feed or drain
# that pure layer, and each pure service's own header states it "never reads live state" /
# "never touches actor or combat state". Somebody has to, and until this slice that somebody
# was FlowRuntime. This file is the named owner of that job, filed beside the services it
# adapts — the same reasoning that put LiveHazardOutcomeService here in slice 6C, which called
# itself "the write half of CombatActivationService's read-only contract". This file is the
# READ half plus the movement write, and LiveHazardOutcomeService remains its collaborator
# rather than being folded in (its header guarantees a narrower remit; nothing changed there).
#
# CONTRACT (same as the Phase 6 sibling services):
#   - Typed RefCounted. Explicit typed dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot.
#   - Never calls SaveService and never sets flow_ctx.save_request. The pre-extraction block
#     requested no save, and must not start: FlowRuntime._mark_save_requested() joins reasons
#     with "|", so a save queued here would glue its reason onto the next dispatch's string.
#   - Calls no controller. Calls only pure movement/grid/shrine services.
#   - STATELESS between calls: every input is a parameter or read through flow_ctx. There is no
#     memo, no cache, no accumulated field, so a per-call construction by FlowRuntime is exact.
#
# CONSTRUCTOR DEPENDENCIES — deliberately TWO, not the usual three. config_service is NOT
# taken: the block never reads it. `bdata` (balance["data"]) is handed in by the caller at
# both preparation entry points, which is how the pre-extraction code worked and is what keeps
# this file honest about being an adapter rather than a config reader.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line:
#   READS   flow_ctx.encounter_ctx.actors (positions, purify-shrine search, relationships),
#           flow_ctx.encounter_ctx.resolution_mode, flow_ctx.encounter_ctx.purifier_id,
#           flow_ctx.save_data["stage_context"]["encounter_approach"]["known_hazards"]
#           (read-only; the authored fixture set from MovementHazardFixtures wins on a
#           position+type identity collision), plus the ectx / combat_state / bdata passed in.
#   WRITES  ONLY through apply_live_activation and apply_live_purify_shrine, and only to actor
#           dicts: the mover's grid_pos (GridService.assign_grid_pos), the mover's
#           action_type / target_id / movement_result on the intent dict, hp/KO/death via
#           LiveHazardOutcomeService, the shrine's purify stacks via ShrineService, and morale
#           on the purifier plus its living echo allies.
#   NOT TOUCHED  save data (read-only), combat_state, flow_ctx.save_request, any snapshot.
#
# DETERMINISM. No RNG anywhere in this file and no OS time; `t` is always injected. Two
# deliberate ordering guards are preserved exactly: _movement_occupancy keeps the
# lexicographically smallest id on a stacked cell, and _movement_destination_before is the
# salted-FNV-1a tie-break for equal-cost destinations. _movement_actor_facts sorts by id.
#
# NAMING. Five methods are public because FlowRuntime (and tools/ + tests) call them across
# the class boundary: prepare_live_movement_context, apply_live_activation,
# apply_live_purify_shrine, prepare_guide_spirit_activation_context and
# movement_rect_walkable. Every other name is BYTE-IDENTICAL to its FlowRuntime original,
# underscore prefix included, so the bodies read as the same code they were.
#
# NO SHIM WAS LEFT ON FlowRuntime (AGENTS.md #20). All 5 production call sites and all
# 30 by-name reflection call sites in tools/PursueTimingProbe.gd and
# tests/CombatRoundtripIntegrationTests.gd were rewritten in this same change.
#
# SIZE — this file is over the ~1,000-line guard (1,018 lines when this note was written),
# DELIBERATELY (Half A review correction C5; the guard was weighed, not missed). The 27 functions moved VERBATIM because V2-COMBAT-003
# owns this behaviour: splitting them would mean choosing new seams inside code another story
# is about to change, and every such choice is a behaviour decision this extraction is not
# allowed to take. A file 1.8% over the guard, whose contents are byte-identical to the block
# they came from, is a smaller risk than a split that pre-empts the story that owns the
# behaviour. Revisit the split when V2-COMBAT-003 lands, not before.

class_name LiveMovementContextService
extends RefCounted

const MovementContextScript            := preload("res://core/movement/contracts/MovementContext.gd")
const MovementActorFactScript          := preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const MovementHazardFactScript         := preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const CombatPressureSnapshotScript     := preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const MovementProfileServiceScript     := preload("res://core/movement/MovementProfileService.gd")
const CombatPressureServiceScript      := preload("res://core/movement/CombatPressureService.gd")
const MovementOptionServiceScript      := preload("res://core/movement/MovementOptionService.gd")
const MovementPathServiceScript        := preload("res://core/movement/MovementPathService.gd")
const MovementIntentScript             := preload("res://core/movement/contracts/MovementIntent.gd")
const MovementActionPlanScript         := preload("res://core/movement/contracts/MovementActionPlan.gd")
const MovementOptionScript             := preload("res://core/movement/contracts/MovementOption.gd")
const CombatActivationServiceScript    := preload("res://core/movement/CombatActivationService.gd")
const MovementHazardFixturesScript     := preload("res://core/movement/MovementHazardFixtures.gd")
const PursueEscapeServiceScript        := preload("res://core/movement/PursueEscapeService.gd")
const StagePartyMovementAdapterScript  := preload("res://core/movement/StagePartyMovementAdapter.gd")

var flow_ctx: FlowContext
var logger: StructuredLogger


func _init(flow_ctx_ref: FlowContext, logger_ref: StructuredLogger) -> void:
	flow_ctx = flow_ctx_ref
	logger = logger_ref


func prepare_live_movement_context(
	actor: Dictionary,
	ectx: EncounterContext,
	combat_state: Dictionary,
	movement_board_cfg: Dictionary,
	bdata: Dictionary,
	t: int
) -> Dictionary:
	if bool(actor.get("is_structure", false)):
		return {"valid": false, "reason": "structure_no_live_movement"}
	var movement_cfg: Dictionary = bdata.get("combat", {}).get("movement", {}) as Dictionary
	var capacity_cfg: Dictionary = movement_cfg.get("capacity", {}) as Dictionary
	var hazard_cfg: Dictionary = movement_cfg.get("hazards", {}) as Dictionary
	var pressure_cfg: Dictionary = movement_cfg.get("pressure", {}) as Dictionary
	if hazard_cfg.is_empty():
		return {"valid": false, "reason": "missing_hazard_config"}
	var bounds: Dictionary = {
		"w": int(movement_board_cfg.get("board_cols", 10)),
		"h": int(movement_board_cfg.get("board_rows", 10)),
	}
	var walkable: Dictionary = movement_board_cfg.get("walkable", {}) as Dictionary
	if walkable.is_empty():
		walkable = movement_rect_walkable(bounds)
	var occupancy: Dictionary = _movement_occupancy(ectx.actors)
	# V2-COMBAT-002 Slice 6E: the mover always owns its own origin cell. Without this,
	# a stacked pair hands the losing mover an occupancy map that names someone else at
	# its origin, BehaviorArbiter._validate_movement_inputs fails `mover_occupancy_mismatch`,
	# and the ENTIRE board is discarded for that activation. No-op when nothing is stacked.
	var mover_origin: Dictionary = actor.get("grid_pos", {}) as Dictionary
	if not mover_origin.is_empty():
		occupancy[_movement_cell_key_runtime(mover_origin)] = str(actor.get("id", ""))
	var perceived: Array = _movement_actor_facts(ectx.actors)
	var relationships: Dictionary = _movement_relationships(actor, perceived)
	var pressure: Dictionary = _movement_pressure_snapshot(actor, ectx, combat_state, bounds, walkable)
	var known_hazards: Array = _live_combat_known_hazards()
	var movement_context: Dictionary = MovementContextScript.build(
		str(actor.get("id", "")),
		"combat.%s.%s.%d" % [str(ectx.encounter_id), str(actor.get("id", "")), t],
		actor.get("grid_pos", {}) as Dictionary,
		bounds,
		walkable,
		walkable,
		occupancy,
		perceived,
		relationships,
		{},
		known_hazards,
		pressure,
		[]
	)
	var planning_walkable_ec: Dictionary = _movement_planning_walkable(movement_context)
	# V2-COMBAT-002 Slice 6E: take BOTH halves of the control build. The live path used
	# to call hostile_edge_costs(), which discards `edge_sources` — so every published
	# option claimed `hostile_control_sources: []` regardless of the truth. This story
	# owes V2-COMBAT-003 normalized hostile-control and hazard summaries; handing it
	# hardcoded emptiness would make its "willingness to accept risk" seam unbuildable.
	var control_build: Dictionary = MovementOptionServiceScript._build_control(movement_context, planning_walkable_ec)
	var edge_costs: Dictionary = control_build["edge_costs"] as Dictionary
	var edge_sources: Dictionary = control_build["edge_sources"] as Dictionary
	var profile: Dictionary = MovementProfileServiceScript.derive_profile(actor, capacity_cfg, {})
	var goals_result: Dictionary = CombatPressureServiceScript.build_goals(movement_context, pressure_cfg)
	if not bool(goals_result.get("valid", false)):
		return {
			"valid": true,
			"selection_enabled": false,
			"movement_cfg": movement_cfg,
			"movement_context": movement_context,
			"profile": profile,
			"goals": [],
			"options": [],
			"edge_costs": edge_costs,
			"hazard_ctx": {
				"triggered": {"unstable": false, "binding": false, "burning": false},
				"config": hazard_cfg,
			},
		}
	var goals: Array = goals_result.get("goals", []) as Array
	var options: Array = []
	if not bool(actor.get("is_quarry", false)):
		options = _movement_live_direct_options(movement_context, profile, goals, edge_costs, edge_sources)
	# V2-COMBAT-002 Slice 6E: gate the movement-aware layer on GOALS, not options.
	# An empty option set only means no destination region was routable this activation
	# (boxed in by allies, objective behind a wall, capacity 0 after truncation). The
	# arbiter handles that case natively: `_generate_candidates` always emits an
	# unconditional `actor.idle`, so at least one STATIONARY candidate is always ranked
	# and a valid zero-length intent is produced. Gating on options threw the whole
	# board away and fell back to legacy nearest-enemy `select_intent` for the actor.
	return {
		"valid": true,
		# The PURSUE quarry is the ONE case where empty options are deliberate rather than
		# incidental: `:1705` skips option generation for it entirely because
		# FleeBehaviorModule owns quarry movement. Gating purely on goals therefore sent
		# the quarry down the movement-aware path with nothing to select, so it produced a
		# target-less `actor.move`, the legacy bridge could not rescue it, and the quarry
		# stopped fleeing altogether. Keep it on its flee module.
		"selection_enabled": not goals.is_empty() and not bool(actor.get("is_quarry", false)),
		"movement_cfg": movement_cfg,
		"movement_context": movement_context,
		"profile": profile,
		"goals": goals,
		"options": options,
		"edge_costs": edge_costs,
		"hazard_ctx": {
			"triggered": {"unstable": false, "binding": false, "burning": false},
			"config": hazard_cfg,
		},
	}


func _movement_live_direct_options(
	movement_context: Dictionary,
	profile: Dictionary,
	goals: Array,
	edge_costs: Dictionary = {},
	edge_sources: Dictionary = {}
) -> Array:
	var options: Array = []
	for goal_value: Variant in goals:
		if not (goal_value is Dictionary):
			continue
		var goal: Dictionary = goal_value
		var option: Dictionary = _movement_direct_option_for_goal(movement_context, profile, goal, edge_costs, edge_sources)
		if not option.is_empty():
			options.append(option)
	return options


func _movement_direct_option_for_goal(
	movement_context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	edge_costs: Dictionary = {},
	edge_sources: Dictionary = {}
) -> Dictionary:
	var origin: Dictionary = movement_context.get("origin", {}) as Dictionary
	var salt: String = str(movement_context.get("mover_id", ""))
	var destination_region: Array = goal.get("destination_region", []) as Array
	if destination_region.has(origin) and str(goal.get("purpose", "")) == "hold":
		return _movement_build_direct_option(movement_context, profile, goal, origin, [], 0, 0, edge_sources)

	if destination_region.is_empty():
		return {}

	var planning_walkable: Dictionary = _movement_planning_walkable(movement_context)
	var terrain_costs: Dictionary = movement_context.get("terrain_costs", {}) as Dictionary
	var bounds: Dictionary = movement_context.get("bounds", {}) as Dictionary

	# PERF (perf/pursue-option-generation): destination_region can be 300+ cells for a
	# hunter positioned ahead of its quarry (a PURSUE "cut off" goal). The old code ran a
	# COMPLETE single-target shortest_path from the same origin to every candidate cell
	# just to keep the cheapest — 300+ full searches per turn instead of one.
	#
	# Dijkstra's minimum cost to a given node is independent of tie-break policy (candidate
	# relaxation here only ever fires on strictly-lower cost — see reachable_cost_region's
	# `candidate_cost < costs[neighbor_key]` — so the recorded cost is the same regardless of
	# traversal/extraction order). That means ONE single-source flood fill from `origin`
	# (reachable_cost_region) yields the exact same cost-to-every-cell that running
	# shortest_path once per destination would have produced. We use that flood fill only to
	# pick the WINNING destination (same cost values, same tie-break via
	# _movement_destination_before as before), then make exactly one shortest_path call for
	# that single destination — the identical call the old loop would have made for it — so
	# the returned path is byte-identical (tie-breaks included) to the pre-optimization code.
	var best_cost: int = 999999
	var best_destination: Dictionary = {}
	var region: Dictionary = MovementPathServiceScript.reachable_cost_region(
		origin, best_cost, planning_walkable, terrain_costs, bounds, edge_costs)
	var region_costs: Dictionary = region.get("costs", {}) as Dictionary
	for destination_value: Variant in destination_region:
		if not (destination_value is Dictionary):
			continue
		var destination: Dictionary = destination_value
		var destination_key: String = _movement_cell_key_runtime(destination)
		if not region_costs.has(destination_key):
			continue
		var cost: int = int(region_costs[destination_key])
		if cost < best_cost or (cost == best_cost and _movement_destination_before(salt, destination, best_destination)):
			best_cost = cost
			best_destination = destination.duplicate(true)

	var best_path: Array = []
	if not best_destination.is_empty():
		var winning_route: Dictionary = MovementPathServiceScript.shortest_path(
			origin,
			best_destination,
			planning_walkable,
			terrain_costs,
			bounds,
			edge_costs
		)
		if bool(winning_route.get("reachable", false)):
			best_cost = int(winning_route.get("cost", 0))
			best_path = (winning_route.get("path", []) as Array).duplicate(true)

	if best_path.is_empty():
		return {}

	var capacity: int = int(profile.get("capacity", 0))
	var selected_path: Array = best_path
	var selected_cost: int = best_cost
	if selected_cost > capacity:
		var prefix: Dictionary = _movement_affordable_prefix(
			origin,
			best_path,
			capacity,
			planning_walkable,
			movement_context.get("terrain_costs", {}) as Dictionary,
			movement_context.get("bounds", {}) as Dictionary,
			edge_costs
		)
		selected_path = prefix.get("path", []) as Array
		selected_cost = int(prefix.get("cost", 0))
	if selected_path.is_empty():
		return {}
	var destination: Dictionary = selected_path.back() as Dictionary
	return _movement_build_direct_option(
		movement_context, profile, goal, destination, selected_path, selected_cost, selected_cost, edge_sources)


func _movement_planning_walkable(movement_context: Dictionary) -> Dictionary:
	var result: Dictionary = (movement_context.get("authoritative_walkable", {}) as Dictionary).duplicate(true)
	var origin: Dictionary = movement_context.get("origin", {}) as Dictionary
	var origin_key: String = _movement_cell_key_runtime(origin)
	var occupancy: Dictionary = movement_context.get("occupancy", {}) as Dictionary
	for occupied_key_value: Variant in occupancy.keys():
		var occupied_key: String = str(occupied_key_value)
		if occupied_key != origin_key:
			result.erase(occupied_key)
	return result


func _movement_affordable_prefix(
	origin: Dictionary,
	path: Array,
	capacity: int,
	walkable: Dictionary,
	terrain_costs: Dictionary,
	bounds: Dictionary,
	edge_costs: Dictionary = {}
) -> Dictionary:
	var best_path: Array = []
	var best_cost: int = 0
	for end_index in range(path.size()):
		var prefix: Array = path.slice(0, end_index + 1)
		var route: Dictionary = MovementPathServiceScript.validate_route(
			origin,
			prefix,
			walkable,
			terrain_costs,
			bounds,
			edge_costs
		)
		if not bool(route.get("valid", false)):
			break
		var cost: int = int(route.get("cost", 0))
		if cost > capacity:
			break
		best_path = prefix
		best_cost = cost
	return {"path": best_path, "cost": best_cost}


func _movement_build_direct_option(
	movement_context: Dictionary,
	profile: Dictionary,
	goal: Dictionary,
	destination: Dictionary,
	path: Array,
	route_cost: int,
	shortest_cost: int,
	edge_sources: Dictionary = {}
) -> Dictionary:
	var goal_id: String = str(goal.get("goal_id", "goal.live"))
	# The option_id is contract-checked by MovementOption._validate_option_id, which demands
	# exactly "option.<goal-suffix>.<style>.d<col>r<row>.p<path>". Reuse the canonical builder
	# from MovementOptionService instead of hand-rolling the token — a hand-rolled id silently
	# failed validation here, which disabled movement-aware selection for the whole live loop.
	var option_id: String = MovementOptionServiceScript._option_id(
		{"goal_id": goal_id}, "direct", destination, path)
	var planned_action: Dictionary = goal.get("planned_primary", {}) as Dictionary
	var option: Dictionary = MovementOptionScript.build(
		goal_id,
		option_id,
		str(goal.get("purpose", "advance")),
		destination,
		path,
		route_cost,
		shortest_cost,
		route_cost - shortest_cost,
		int(profile.get("capacity", 0)),
		route_cost,
		# exposure / congestion / cohesion stay 0.0 ON PURPOSE. These three are consumed by
		# BehaviorArbiter._spatial_utility as WEIGHTED terms (exposure -6.0, cohesion 4.0,
		# congestion -2.0), so populating them here would silently activate scoring weights
		# that have never run in a live encounter. Deciding "whether a particular Echo
		# accepts that risk" is V2-COMBAT-003 (Movement Model Slice C), which owns both
		# filling these and tuning their weights together. See docs/movement-model.md.
		0.0,
		0.0,
		0.0,
		# hostile_control_sources + hazard_summary ARE this story's to publish truthfully:
		# they are declarative route facts, not risk appetite, and V2-COMBAT-003 is written
		# to consume them. Both were previously hardcoded empty, which was a false claim.
		# Inert for selection today, so this is a contract-honesty fix with no behaviour change.
		MovementOptionServiceScript._hostile_sources(
			path, movement_context.get("origin", {}) as Dictionary, edge_sources),
		_movement_hazard_summary(movement_context, path),
		1.0 if (goal.get("destination_region", []) as Array).has(destination) else 0.25,
		planned_action,
		goal.get("declared_fallback", {}) as Dictionary
	)
	var validation: Dictionary = MovementOptionScript.validate(
		option,
		movement_context.get("origin", {}) as Dictionary
	)
	return option if bool(validation.get("valid", false)) else {}


## V2-COMBAT-002 Slice 6E: the normalized known-hazard summary this story owes
## V2-COMBAT-003. Mirrors MovementOptionService's own shape exactly — ids strictly
## sorted and unique, `known_count` equal to the id count — which MovementOption.validate
## enforces (`hazard_count_mismatch`). Only hazards the mover actually KNOWS about are
## published; undiscovered hazards must never influence selection or explanation.
func _movement_hazard_summary(movement_context: Dictionary, path: Array) -> Dictionary:
	var hazard_ids: Array = MovementOptionServiceScript._hazard_ids(
		path, movement_context.get("known_hazards", []) as Array)
	return {"known_count": hazard_ids.size(), "known_ids": hazard_ids}


func _movement_cell_key_runtime(cell: Dictionary) -> String:
	if cell.is_empty():
		return ""
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


## Compass-de-aligned, replay-stable tie-break for equal-cost combat destinations.
## Replaces the old lexicographic "col,row" preference that biased every mover to
## the top-left cell around its target. Salted FNV-1a (the 6A stage de-aligner),
## keyed by the mover so attackers spread instead of stacking; numeric col/row is
## the final total-order fallback on the (rare) hash tie. Pure — replay-exact.
func _movement_destination_before(salt: String, a: Dictionary, b: Dictionary) -> bool:
	var ha: int = StagePartyMovementAdapterScript.salted_cell_hash(salt, _movement_cell_key_runtime(a))
	var hb: int = StagePartyMovementAdapterScript.salted_cell_hash(salt, _movement_cell_key_runtime(b))
	if ha != hb:
		return ha < hb
	if int(a.get("col", 0)) != int(b.get("col", 0)):
		return int(a.get("col", 0)) < int(b.get("col", 0))
	return int(a.get("row", 0)) < int(b.get("row", 0))


func apply_live_activation(
	actor: Dictionary,
	intent: Dictionary,
	prepared: Dictionary,
	asm: ActorStateMachine,
	ctx: Dictionary,
	t: int
) -> Dictionary:
	_prepare_legacy_move_intent_for_activation(actor, intent, prepared)
	if not bool(prepared.get("valid", false)) or not intent.has("planned_action"):
		asm.update_passive_state_from_activation(intent, ctx, t, false, logger)
		return {}
	var movement_context: Dictionary = prepared["movement_context"] as Dictionary
	var profile: Dictionary = prepared["profile"] as Dictionary
	var hazard_ctx: Dictionary = prepared["hazard_ctx"] as Dictionary
	var goal: Dictionary = _movement_goal_by_id(
		prepared.get("goals", []) as Array, str(intent.get("goal_id", "")))
	var action_ctx: Dictionary = {
		"purpose": str(intent.get("movement_purpose", goal.get("purpose", "advance"))),
		"goal_id": str(intent.get("goal_id", "")),
		"option_id": str(intent.get("option_id", "")),
		"positions": _movement_actor_positions(flow_ctx.encounter_ctx.actors),
		"ranges": {
			"melee_attack": 1,
			"protect_ally": 1,
			"actor.purify_shrine": 1,
		},
		"default_range": 1,
		"objective_progress": float(goal.get("objective_progress", 0.0)),
		"mover_hp": int(actor.get("current_hp", 0)),
		"mover_ko_only": false,
	}
	var result: Dictionary = CombatActivationServiceScript.activate(
		movement_context, intent, profile, hazard_ctx, action_ctx)
	var final_cell: Dictionary = result.get("final_destination", actor.get("grid_pos", {})) as Dictionary
	var actual: Array = result.get("actual_traversed_cells", []) as Array
	if not actual.is_empty():
		var from_pos: Dictionary = actor.get("grid_pos", {}).duplicate(true)
		GridService.assign_grid_pos(actor, int(final_cell.get("col", 0)), int(final_cell.get("row", 0)))
		# goal_id/option_id say WHY the mover went there. Without them a route that
		# reaches the right cell for the wrong reason is indistinguishable from a correct one.
		logger.info(t, "actor.moved", "Actor moved", {
			"actor_id": actor.get("id", ""),
			"from_pos": from_pos,
			"to_pos": actor.get("grid_pos", {}),
			"path": actual.duplicate(true),
			"stop_reason": str(result.get("stop_reason", "")),
			"goal_id": str(result.get("goal_id", "")),
			"option_id": str(result.get("option_id", "")),
		})
	var resolved_action: Dictionary = result.get("resolved_action", {}) as Dictionary
	if resolved_action.is_empty():
		intent["action_type"] = "actor.idle"
		intent["target_id"] = ""
	else:
		intent["action_type"] = str(resolved_action.get("type", "actor.idle"))
		intent["target_id"] = str(resolved_action.get("target_id", ""))
	# Movement/forced hazard damage resolves before the external primary action.
	# Burning is deliberately deferred until that action has completed below.
	LiveHazardOutcomeService.apply(actor, result, t, int(ctx.get("round", t)), logger, false)
	if bool(actor.get("is_dead", false)):
		intent["action_type"] = "actor.idle"
		intent["target_id"] = ""
	intent["movement_result"] = result
	asm.update_passive_state_from_activation(intent, ctx, t, not actual.is_empty(), logger)
	return result


## Applies the shrine effect only after CombatActivationService has legally resolved
## the action at the final cell. Intent selection itself remains side-effect free.
func apply_live_purify_shrine(
	actor: Dictionary,
	target_id: String,
	ctx: Dictionary,
	t: int
) -> void:
	var shrine_cfg: Dictionary = ctx.get("cfg", {}).get("data", {}).get("combat", {}).get("shrine", {})
	var shrine_ref: Dictionary = {}
	for actor_value: Variant in flow_ctx.encounter_ctx.actors:
		if actor_value is Dictionary:
			var candidate: Dictionary = actor_value
			if not bool(candidate.get("is_structure", false)) or bool(candidate.get("is_dead", false)):
				continue
			# Empty target_id: the purify candidate is authored without one, so locate
			# the live shrine directly (mirrors the pre-cutover ActorStateMachine path).
			if target_id.is_empty() or str(candidate.get("id", "")) == target_id:
				shrine_ref = candidate
				break
	if shrine_ref.is_empty():
		return
	ShrineService.apply_purify_stack(shrine_ref, actor, shrine_cfg)
	logger.info(t, "actor.purified_shrine", "Purify applied to shrine", {
		"actor_id": str(actor.get("id", "")),
		"shrine_id": str(shrine_ref.get("id", "")),
		"stacks_count": (shrine_ref.get("purify_stacks", []) as Array).size(),
		"cooldown_set": int(actor.get("purify_cooldown", 0)),
	})
	var emotion_cfg: Dictionary = ctx.get("cfg", {}).get("data", {}).get("combat", {}).get("emotion", {})
	var shrine_morale: int = int(emotion_cfg.get("morale_on_shrine_purify", 5))
	var shrine_ripple: int = int(emotion_cfg.get("morale_ripple_shrine_purify", 2))
	actor["morale"] = mini(100, int(actor.get("morale", 50)) + shrine_morale)
	for actor_value: Variant in flow_ctx.encounter_ctx.actors:
		if not (actor_value is Dictionary):
			continue
		var ally: Dictionary = actor_value
		if str(ally.get("id", "")) != str(actor.get("id", "")) \
				and str(ally.get("faction", "")) == "echo" \
				and not bool(ally.get("is_dead", false)):
			ally["morale"] = mini(100, int(ally.get("morale", 50)) + shrine_ripple)


func _prepare_legacy_move_intent_for_activation(
	actor: Dictionary,
	intent: Dictionary,
	prepared: Dictionary
) -> void:
	if not bool(prepared.get("valid", false)):
		return
	if intent.has("planned_action"):
		return
	if str(intent.get("action_type", "")) != "actor.move":
		return
	var target_pos: Dictionary = intent.get("target_pos", {}) as Dictionary
	if target_pos.is_empty():
		return
	var movement_context: Dictionary = prepared["movement_context"] as Dictionary
	var origin: Dictionary = movement_context.get("origin", actor.get("grid_pos", {})) as Dictionary
	var walkable: Dictionary = _movement_planning_walkable(movement_context)
	var edge_costs: Dictionary = prepared.get("edge_costs", {}) as Dictionary
	var bounds: Dictionary = movement_context.get("bounds", {}) as Dictionary
	var destination: Dictionary = target_pos
	if not bool(walkable.get(_movement_cell_key_runtime(destination), false)):
		destination = _movement_nearest_reachable_adjacent(
			origin,
			target_pos,
			walkable,
			movement_context.get("terrain_costs", {}) as Dictionary,
			bounds,
			edge_costs,
			str(movement_context.get("mover_id", ""))
		)
		if destination.is_empty():
			return
	var route: Dictionary = MovementPathServiceScript.shortest_path(
		origin,
		destination,
		walkable,
		movement_context.get("terrain_costs", {}) as Dictionary,
		bounds,
		edge_costs
	)
	var path: Array = route.get("path", []) as Array if bool(route.get("reachable", false)) else []
	var profile: Dictionary = prepared["profile"] as Dictionary
	var capacity: int = int(profile.get("capacity", 0))
	# Commitment is a COST budget the executor charges the hostile-control surcharge
	# against — not a step count. Use the surcharged route cost so a step into a
	# hostile-adjacent cell (cost 2) is actually funded; empty path keeps commitment 0.
	var commitment: int = 0 if path.is_empty() else mini(capacity, int(route.get("cost", path.size())))
	var plan: Dictionary = MovementActionPlanScript.build("actor.move", str(intent.get("target_id", "")))
	var fallback: Dictionary = MovementActionPlanScript.build("actor.idle", "")
	var movement_intent: Dictionary = MovementIntentScript.build(
		str(movement_context.get("mover_id", actor.get("id", ""))),
		str(movement_context.get("activation_id", "live.activation")),
		"goal.live.quarry_flee" if bool(actor.get("is_quarry", false)) else "goal.live.move",
		"option.live.quarry_flee" if bool(actor.get("is_quarry", false)) else "option.live.move",
		path,
		capacity,
		commitment,
		plan,
		fallback,
		["mode.%s" % str(flow_ctx.encounter_ctx.resolution_mode)]
	)
	var validation: Dictionary = MovementIntentScript.validate(movement_intent, origin)
	if not bool(validation.get("valid", false)):
		return
	for key_value: Variant in movement_intent.keys():
		intent[key_value] = movement_intent[key_value]
	intent["movement_purpose"] = "withdraw" if bool(actor.get("is_quarry", false)) else "advance"


func _movement_nearest_reachable_adjacent(
	origin: Dictionary,
	center: Dictionary,
	walkable: Dictionary,
	terrain_costs: Dictionary,
	bounds: Dictionary,
	edge_costs: Dictionary = {},
	salt: String = ""
) -> Dictionary:
	var best: Dictionary = {}
	var best_cost: int = 999999
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var candidate: Dictionary = {
				"col": int(center.get("col", 0)) + dc,
				"row": int(center.get("row", 0)) + dr,
			}
			if not bool(walkable.get(_movement_cell_key_runtime(candidate), false)):
				continue
			var route: Dictionary = MovementPathServiceScript.shortest_path(
				origin,
				candidate,
				walkable,
				terrain_costs,
				bounds,
				edge_costs
			)
			if not bool(route.get("reachable", false)):
				continue
			var cost: int = int(route.get("cost", 0))
			if cost < best_cost or (cost == best_cost and _movement_destination_before(salt, candidate, best)):
				best = candidate
				best_cost = cost
	return best


func prepare_guide_spirit_activation_context(
	spirit: Dictionary,
	ectx: EncounterContext,
	combat_state: Dictionary,
	bdata: Dictionary,
	t: int
) -> Dictionary:
	var movement_cfg: Dictionary = bdata.get("combat", {}).get("movement", {}) as Dictionary
	var capacity_cfg: Dictionary = movement_cfg.get("capacity", {}) as Dictionary
	var hazard_cfg: Dictionary = movement_cfg.get("hazards", {}) as Dictionary
	if hazard_cfg.is_empty():
		return {"valid": false, "reason": "missing_hazard_config"}
	var grid_cfg: Dictionary = bdata.get("grid", {}) as Dictionary
	var bounds: Dictionary = {
		"w": GridService.get_board_cols(grid_cfg),
		"h": GridService.get_board_rows(grid_cfg),
	}
	var walkable: Dictionary = {}
	if not ectx.terrain.is_empty():
		walkable = StageTerrain.walkable_set(ectx.terrain)
		var terrain_bounds: Dictionary = ectx.terrain.get("bounds", {}) as Dictionary
		if terrain_bounds.has("w"):
			bounds["w"] = int(terrain_bounds["w"])
		if terrain_bounds.has("h"):
			bounds["h"] = int(terrain_bounds["h"])
	if walkable.is_empty():
		walkable = movement_rect_walkable(bounds)
	var perceived: Array = _movement_actor_facts(ectx.actors)
	var known_hazards: Array = _live_combat_known_hazards()
	var context: Dictionary = MovementContextScript.build(
		str(spirit.get("id", "")),
		"guide.%s.%s.%d" % [str(ectx.encounter_id), str(spirit.get("id", "")), t],
		spirit.get("grid_pos", {}) as Dictionary,
		bounds,
		walkable,
		walkable,
		_movement_occupancy(ectx.actors),
		perceived,
		_movement_relationships(spirit, perceived),
		{},
		known_hazards,
		_movement_pressure_snapshot(spirit, ectx, combat_state, bounds, walkable),
		[]
	)
	return {
		"valid": true,
		"context": context,
		"capacity_cfg": capacity_cfg,
		"hazard_ctx": {
			"triggered": {"unstable": false, "binding": false, "burning": false},
			"config": hazard_cfg,
		},
	}


## The approach stores only information the party learned before engagement. The
## fixed combat-board field is separately authored; its cell/type fact replaces an
## approach fact at the same identity so physical board truth has precedence.
func _live_combat_known_hazards() -> Array:
	var stage_context: Dictionary = flow_ctx.save_data.get("stage_context", {}) as Dictionary
	var approach: Dictionary = stage_context.get("encounter_approach", {}) as Dictionary
	var approach_hazards: Array = approach.get("known_hazards", []) as Array
	var winners_by_identity: Dictionary = {}
	for hazard_value: Variant in approach_hazards:
		_merge_live_combat_hazard(winners_by_identity, hazard_value, 0)
	for hazard_value: Variant in MovementHazardFixturesScript.authored_set():
		_merge_live_combat_hazard(winners_by_identity, hazard_value, 1)

	var identities: Array = winners_by_identity.keys()
	identities.sort()
	var winners_by_id: Dictionary = {}
	for identity_value: Variant in identities:
		var candidate: Dictionary = winners_by_identity[identity_value] as Dictionary
		var hazard: Dictionary = candidate["hazard"] as Dictionary
		var hazard_id: String = str(hazard.get("id", ""))
		if not winners_by_id.has(hazard_id) \
				or int(candidate["source_priority"]) >= int((winners_by_id[hazard_id] as Dictionary)["source_priority"]):
			winners_by_id[hazard_id] = candidate

	var result: Array = []
	for identity_value: Variant in identities:
		var candidate: Dictionary = winners_by_identity[identity_value] as Dictionary
		var hazard: Dictionary = candidate["hazard"] as Dictionary
		var chosen: Dictionary = winners_by_id[str(hazard.get("id", ""))] as Dictionary
		if candidate == chosen:
			result.append(hazard.duplicate(true))
	return result


func _merge_live_combat_hazard(winners_by_identity: Dictionary, value: Variant, source_priority: int) -> void:
	if not (value is Dictionary):
		return
	var hazard: Dictionary = value as Dictionary
	var validation: Dictionary = MovementHazardFactScript.validate(hazard)
	if not bool(validation.get("valid", false)):
		return
	var hazard_type: String = str(hazard.get("hazard_type", ""))
	if not hazard_type in ["unstable", "binding", "burning"]:
		return
	var position: Dictionary = hazard["position"] as Dictionary
	var identity: String = "%d,%d:%s" % [
		int(position.get("col", 0)), int(position.get("row", 0)), hazard_type,
	]
	winners_by_identity[identity] = {
		"hazard": hazard.duplicate(true),
		"source_priority": source_priority,
	}


func movement_rect_walkable(bounds: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for col in range(int(bounds.get("w", 0))):
		for row in range(int(bounds.get("h", 0))):
			result["%d,%d" % [col, row]] = true
	return result


func _movement_occupancy(actors: Array) -> Dictionary:
	var result: Dictionary = {}
	for actor_value: Variant in actors:
		if not (actor_value is Dictionary):
			continue
		var actor: Dictionary = actor_value
		if bool(actor.get("is_dead", false)):
			continue
		var pos: Dictionary = actor.get("grid_pos", {}) as Dictionary
		if pos.is_empty():
			continue
		var cell_key: String = "%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]
		var actor_id: String = str(actor.get("id", ""))
		# V2-COMBAT-002 Slice 6E: deterministic stacking guard. Two live actors on one
		# cell is latent (never observed in 3,585 activations) but not impossible, and a
		# raw last-writer-wins map makes the recorded occupant depend on `ectx.actors`
		# order. Keep the lexicographically smallest id so the same board always yields
		# the same occupancy — the mover's own origin is re-asserted by the caller.
		if result.has(cell_key) and str(result[cell_key]) <= actor_id:
			continue
		result[cell_key] = actor_id
	return result


func _movement_actor_facts(actors: Array) -> Array:
	var facts: Array = []
	for actor_value: Variant in actors:
		if not (actor_value is Dictionary):
			continue
		var actor: Dictionary = actor_value
		var max_hp: int = int((actor.get("stats", {}) as Dictionary).get("max_hp", actor.get("max_hp", 1)))
		var hp_ratio: float = 0.0 if max_hp <= 0 else clampf(float(actor.get("current_hp", 0)) / float(max_hp), 0.0, 1.0)
		var is_dead: bool = bool(actor.get("is_dead", false))
		var is_ko: bool = bool(actor.get("is_ko", false)) or (int(actor.get("current_hp", 1)) <= 0 and not is_dead)
		var is_structure: bool = bool(actor.get("is_structure", false))
		var controlling: bool = bool(actor.get("controlling_state", true)) \
			and not is_dead and not is_ko and not is_structure
		facts.append(MovementActorFactScript.build(
			str(actor.get("id", "")),
			actor.get("grid_pos", {}) as Dictionary,
			"structure" if is_structure else str(actor.get("actor_type", "echo")),
			is_dead,
			is_ko,
			is_structure,
			bool(actor.get("is_spirit", false)),
			bool(actor.get("is_quarry", false)),
			controlling,
			hp_ratio
		))
	facts.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str((left as Dictionary)["id"]) < str((right as Dictionary)["id"])
	)
	return facts


func _movement_relationships(mover: Dictionary, facts: Array) -> Dictionary:
	var result: Dictionary = {}
	var mover_faction: String = str(mover.get("faction", ""))
	for fact_value: Variant in facts:
		var fact: Dictionary = fact_value
		var actor_id: String = str(fact["id"])
		var actor_ref: Dictionary = EncounterContext.find_actor_by_id(flow_ctx.encounter_ctx.actors, actor_id)
		var faction: String = str(actor_ref.get("faction", ""))
		var relationship: String = "neutral"
		if actor_id == str(mover.get("id", "")) or faction == mover_faction:
			relationship = "friendly"
		elif mover_faction == "enemy" or faction == "enemy":
			relationship = "hostile"
		result[actor_id] = relationship
	return result


func _movement_actor_positions(actors: Array) -> Dictionary:
	var result: Dictionary = {}
	for actor_value: Variant in actors:
		if actor_value is Dictionary:
			var actor: Dictionary = actor_value
			result[str(actor.get("id", ""))] = (actor.get("grid_pos", {}) as Dictionary).duplicate(true)
	return result


func _movement_goal_by_id(goals: Array, goal_id: String) -> Dictionary:
	for goal_value: Variant in goals:
		var goal: Dictionary = goal_value
		if str(goal.get("goal_id", "")) == goal_id:
			return goal
	return {}


func _movement_pressure_snapshot(
	actor: Dictionary,
	ectx: EncounterContext,
	combat_state: Dictionary,
	bounds: Dictionary,
	walkable: Dictionary
) -> Dictionary:
	var mode: String = str(ectx.resolution_mode)
	var objective: Dictionary = _movement_objective_actor(ectx, combat_state)
	var objective_known: bool = not objective.is_empty()
	var objective_id: String = str(objective.get("id", ""))
	var objective_pos: Dictionary = objective.get("grid_pos", {}) if objective_known else {}
	var destination_region: Array = []
	var approach_region: Array = []
	var fallback_region: Array = []
	var search_region: Array = _movement_all_cells(walkable)
	if objective_known:
		destination_region = _movement_adjacent_cells(objective_pos, bounds, walkable)
		approach_region = destination_region.duplicate(true)
		fallback_region = destination_region.duplicate(true)
	if mode == EncounterResolutionModes.PURSUE and bool(actor.get("is_quarry", false)):
		destination_region = PursueEscapeServiceScript.escape_cells(bounds, walkable)
	var guide_mode: String = str(combat_state.get("guide_mode", "")) if mode == EncounterResolutionModes.GUIDE_SPIRIT else ""
	var faction: String = str(actor.get("faction", ""))
	var alignment: String = "objective" if bool(actor.get("is_structure", false)) else ("hostile" if faction == "enemy" else "party")
	var factual_role: String = _movement_factual_role(actor, combat_state)
	var progress_current: int = 0
	var progress_required: int = 0
	match mode:
		EncounterResolutionModes.RECOVER:
			progress_current = int(combat_state.get("hold_counter", 0))
			progress_required = int((combat_state.get("objective_params", {}) as Dictionary).get("hold_rounds", 0))
		EncounterResolutionModes.PROTECT:
			progress_current = int(combat_state.get("protect_counter", 0))
			progress_required = int((combat_state.get("objective_params", {}) as Dictionary).get("duration_turns", 0))
		EncounterResolutionModes.PURSUE:
			progress_current = int(combat_state.get("contain_counter", 0))
			progress_required = int((combat_state.get("objective_params", {}) as Dictionary).get("contain_rounds", 0))
		EncounterResolutionModes.GUIDE_SPIRIT:
			progress_current = int(combat_state.get("guide_protect_counter", 0))
			progress_required = int((combat_state.get("objective_params", {}) as Dictionary).get("duration_turns", 0))
		EncounterResolutionModes.ENDURE:
			progress_current = int(combat_state.get("round_counter", 0))
			progress_required = int((combat_state.get("objective_params", {}) as Dictionary).get("duration_turns", 0))
	var objective_health: float = -1.0
	if objective_known:
		var max_hp: int = int((objective.get("stats", {}) as Dictionary).get("max_hp", objective.get("max_hp", 1)))
		objective_health = 0.0 if max_hp <= 0 else clampf(float(objective.get("current_hp", 0)) / float(max_hp), 0.0, 1.0)
	return CombatPressureSnapshotScript.build(
		mode,
		guide_mode,
		alignment,
		factual_role,
		objective_known,
		objective_id,
		objective_pos,
		destination_region,
		approach_region,
		fallback_region,
		search_region,
		str(ectx.purifier_id),
		str(combat_state.get("recover_holder_id", "")),
		str(combat_state.get("totem_carrier_id", "")),
		str(objective_id) if mode == EncounterResolutionModes.PURSUE else "",
		str(combat_state.get("spirit_id", "")),
		objective_health,
		progress_current,
		progress_required,
		bool(combat_state.get("escort_started", false)),
		bool(combat_state.get("spirit_joins_battle", false)),
		bool(combat_state.get("totem_stolen", false)),
		["mode.%s" % mode]
	)


func _movement_objective_actor(ectx: EncounterContext, combat_state: Dictionary) -> Dictionary:
	match str(ectx.resolution_mode):
		EncounterResolutionModes.PURSUE:
			for actor_value: Variant in ectx.actors:
				if actor_value is Dictionary and bool((actor_value as Dictionary).get("is_quarry", false)):
					return actor_value
		EncounterResolutionModes.GUIDE_SPIRIT:
			return EncounterContext.find_actor_by_id(ectx.actors, str(combat_state.get("spirit_id", "")))
		EncounterResolutionModes.PURIFY_SHRINE, EncounterResolutionModes.RECOVER, EncounterResolutionModes.PROTECT:
			for actor_value: Variant in ectx.actors:
				# V2-COMBAT-002 Slice 6E: mirror the `shrine_alive` liveness check in
				# _resolve_next_actor. A destroyed structure was still published as the
				# movement objective, so pressure carried objective_known=true with an
				# objective_health of 0.0 — below every 0.5 urgency threshold — and movers
				# kept advancing on a corpse instead of reading "no objective".
				if actor_value is Dictionary \
						and bool((actor_value as Dictionary).get("is_structure", false)) \
						and not bool((actor_value as Dictionary).get("is_dead", false)):
					return actor_value
	return {}


func _movement_factual_role(actor: Dictionary, combat_state: Dictionary) -> String:
	var actor_id: String = str(actor.get("id", ""))
	if actor_id == str(combat_state.get("recover_holder_id", "")):
		return "holder"
	if actor_id == str(combat_state.get("totem_carrier_id", "")):
		return "carrier"
	if bool(actor.get("is_quarry", false)):
		return "quarry"
	if bool(actor.get("is_spirit", false)):
		return "spirit"
	if actor_id == str(flow_ctx.encounter_ctx.purifier_id):
		return "purifier"
	return "baseline"


func _movement_adjacent_cells(center: Dictionary, bounds: Dictionary, walkable: Dictionary) -> Array:
	var cells: Array = []
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var cell: Dictionary = {"col": int(center.get("col", 0)) + dc, "row": int(center.get("row", 0)) + dr}
			var key: String = "%d,%d" % [int(cell["col"]), int(cell["row"])]
			if int(cell["col"]) >= 0 and int(cell["row"]) >= 0 \
					and int(cell["col"]) < int(bounds.get("w", 0)) \
					and int(cell["row"]) < int(bounds.get("h", 0)) \
					and bool(walkable.get(key, false)):
				cells.append(cell)
	cells.sort_custom(func(left: Variant, right: Variant) -> bool:
		var a: Dictionary = left
		var b: Dictionary = right
		if int(a["col"]) != int(b["col"]):
			return int(a["col"]) < int(b["col"])
		return int(a["row"]) < int(b["row"])
	)
	return cells


func _movement_all_cells(walkable: Dictionary) -> Array:
	var cells: Array = []
	var keys: Array = walkable.keys()
	keys.sort()
	for key_value: Variant in keys:
		var parts: PackedStringArray = str(key_value).split(",")
		if parts.size() == 2:
			cells.append({"col": int(parts[0]), "row": int(parts[1])})
	return cells
