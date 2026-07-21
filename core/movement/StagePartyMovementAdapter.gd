# res://core/movement/StagePartyMovementAdapter.gd
# V2-COMBAT-002 Slice 5 (Unit A) — PURE + DORMANT stage-party movement adapter.
#
# Bridges STAGE EXPLORATION onto the slice-1..4 movement contracts. Nothing in
# production calls this file: it is consumed at the slice-6 cutover.
#
# ---------------------------------------------------------------------------
# THE ONE PARTY TOKEN
# ---------------------------------------------------------------------------
# Stage traversal moves a SINGLE party token, never individual Echoes. Every
# function here is written against that single token (`MOVER_ID`) and the public
# API deliberately exposes no per-Echo seam: there is no mover_id parameter, no
# actor array, and no per-actor capacity. Adding one would be a design change,
# not a refactor.
#
# ---------------------------------------------------------------------------
# PURITY
# ---------------------------------------------------------------------------
# Static functions only. Plain Dictionaries in, contract Dictionaries out.
# Zero references to FlowRuntime / FlowContext / SaveService / any UI node.
# No RNG, no OS time, no input mutation (every returned nested value is copied).
#
# ---------------------------------------------------------------------------
# EDGE LEGALITY
# ---------------------------------------------------------------------------
# All reachability here goes through MovementPathService, which routes over
# StageTerrain.legal_neighbors / StageTerrain.is_legal_edge — the SHARED
# two-solid-corners diagonal rule (a diagonal is illegal iff BOTH orthogonal
# side cells are non-walkable). Raw `is_walkable` is never used as an edge test,
# and the rule itself is not reimplemented here.
#
# This intentionally diverges from live `StageTerrain.next_step` /
# `StageTerrain.nearest_unexplored`, which are NOT touched this slice. The
# divergence resolves at the slice-6 cutover.
#
# NOTE (deliberate): `StageTerrain.bfs_distance_field` is NOT used, because it
# expands neighbours with a raw `walkable.has(key)` test and therefore ignores
# the diagonal rule. `MovementPathService.reachable_cost_region` is used instead.
#
# ---------------------------------------------------------------------------
# TIE-BREAKS
# ---------------------------------------------------------------------------
#   select_frontier:
#     1. smallest BFS distance from the party
#     2. greatest continuation of the current travel heading
#     3. smallest chebyshev to party, then smallest manhattan to party
#     4. canonical cell key "col,row"      <- KNOWN BIAS, see below
#
#   select_objective_target (slice 5 amendment A2 — bounded slack):
#     1. candidates farther than the nearest by more than the slack envelope are
#        DROPPED; inside the envelope, weight leads
#     2. greatest configured target_preference weight
#     3. smallest BFS distance
#     4. situation id lexicographic        <- replaces today's implicit
#                                             dependence on situations[] order
#
# ---------------------------------------------------------------------------
# OCCUPANCY IS NOT MODELLED HERE (slice 5 amendment A7)
# ---------------------------------------------------------------------------
# The freeze asked for the "occupied but walkable diagonal" case to be tested
# against the shared legality helper with a NON-EMPTY occupancy dict. It cannot
# be: occupancy is not expressible anywhere on the path this adapter uses.
#
#   * StageTerrain.is_legal_edge(from, to, walkable, bounds) and
#     StageTerrain.legal_neighbors(cell, walkable, bounds) take NO occupancy
#     argument — the shared diagonal rule is a function of the walkable set alone.
#   * MovementPathService.reachable_cost_region(origin, capacity, walkable,
#     terrain_costs, bounds, edge_costs) likewise has no occupancy parameter, and
#     select_frontier passes {} for all three optional dicts.
#
# So "occupied but walkable" is not a case this adapter can distinguish from
# "walkable": an occupant changes nothing because occupancy never enters the
# walkable authority. The freeze requirement is therefore recorded as
# STRUCTURALLY UNREACHABLE rather than tested, and
# `frontier_diagonal_one_solid_corner_allowed` asserts the property that IS
# reachable — two walkable side cells keep the diagonal legal.
#
# ---------------------------------------------------------------------------
# KNOWN BIAS — criterion 4 (slice 5 amendment A1). DO NOT call this unreachable.
# ---------------------------------------------------------------------------
# An earlier draft of this file claimed the canonical-key comparison was
# "unreachable in practice". That claim was FALSE and has been retracted:
#
#   * It is trivially reachable. Party (2,2) with candidates (2,0) and (2,4) and
#     no heading ties BFS distance, heading continuation, chebyshev AND manhattan,
#     so criterion 4 decides and picks (2,0) — NORTH.
#   * Worse, `heading` is not produced anywhere in `core/` today. Until it is
#     plumbed, criterion 2 scores every candidate 0 for every selection, which
#     makes criterion 4 the EFFECTIVE tie-breaker rather than a last resort.
#   * It is also NOT row/col ordering. `V.canonical_cell_key` yields "col,row"
#     and the comparison is a LEXICOGRAPHIC STRING compare, so "10,3" < "9,3".
#     The induced order is jagged and non-monotone in either axis: it is neither
#     row-major nor col-major, and the compass direction it favours flips with
#     the digit count of the coordinates.
#
# The algorithm is deliberately UNCHANGED this slice (Jeff's call). The bias is
# pinned by the characterisation test
# `movement/stage_party/frontier_headingless_tie_pins_known_bias`, whose expected
# values are the current biased answers. It is scheduled for removal at slice 6,
# where plumbing `heading` is the top cutover risk on record in
# docs/integration-map.md.

class_name StagePartyMovementAdapter
extends RefCounted

const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

## The single stage party token. There is exactly one, forever.
const MOVER_ID: String = "party.token"
const ACTOR_KIND: String = "party"

## Stage traversal is exploration, so every stage goal_id carries the `explore`
## MODE segment (slice 5 amendment A3 — appended to MovementGoal.MODES). The
## previous `recover` segment was simply false: thread recovery is the run's
## reward, not the movement mode.
const GOAL_MODE: String = "explore"
const GOAL_ROLE: String = "baseline"

## Target tiers, mirroring FlowRuntime._find_explore_target.
const TIER_OBJECTIVE: int = 1
const TIER_WEIGHTED: int = 2
const TIER_FRONTIER: int = 3
const TIER_PASSED_OBJECTIVE: int = 4

## Urgency per tier: hard objective (1/4) outranks weighted non-objective (2)
## outranks frontier (3).
const TIER_URGENCY: Dictionary = {
	TIER_OBJECTIVE: 1.0,
	TIER_PASSED_OBJECTIVE: 0.9,
	TIER_WEIGHTED: 0.6,
	TIER_FRONTIER: 0.3,
}

## Pressure-source token per tier (slice 5 amendment A6).
##
## An earlier draft emitted `tier.%d`. `CombatPressureService._valid_source` gates
## on the prefix set `mode. / role. / actor. / objective. / state.`, so EVERY stage
## goal would have been rejected the moment it reached the pressure layer at
## cutover. The tier is a fact about the selection state, so it is a `state.` token.
const TIER_PRESSURE_SOURCE: Dictionary = {
	TIER_OBJECTIVE: "state.tier_objective",
	TIER_PASSED_OBJECTIVE: "state.tier_passed_objective",
	TIER_WEIGHTED: "state.tier_weighted",
	TIER_FRONTIER: "state.tier_frontier",
}

## MovementProfile's own expressible capacity bounds — NOT the combat capacity
## formula. The contract (MovementProfile.validate) rejects capacity 0 for a
## non-structure, requires an `authored_override` at capacity 1, and caps
## capacity at 6 (MovementContractValidation.require_capacity).
##
## Slice 5 amendment A4: a step_budget below 2 is no longer silently clamped UP
## to 2 — that inflated the party's pace and hid the bad config. It now produces
## capacity 1 plus an authored_override naming `directive.step_budget` as its
## source, which is the same authored-pace seam the GUIDE spirit uses. The upper
## cap stays 6 (contract ceiling).
const MIN_EXPRESSIBLE_CAPACITY: int = 1
const AUTHORED_OVERRIDE_THRESHOLD: int = 2
const MAX_EXPRESSIBLE_CAPACITY: int = 6

## Where a below-threshold capacity came from, recorded in `authored_override`.
const CAPACITY_SOURCE: String = "directive.step_budget"

const DEFAULT_STEP_BUDGET: int = 3

## Category assigned to a situation `type` that `situation_category` does not
## map. Mirrors the `"intel"` default in FlowRuntime._find_explore_target
## (FlowRuntime.gd, Tier 2: `str(sit_cat_map.get(sit_type, "intel"))`).
const DEFAULT_SITUATION_CATEGORY: String = "intel"

## Weight applied to a category the directive's `target_preference` does not
## list. Mirrors `float(target_pref.get(category, 1.0))` in the same Tier-2 loop.
const DEFAULT_TARGET_WEIGHT: float = 1.0

## Bounded-slack envelope for objective selection (slice 5 amendment A2).
##
## This is NOT a second slack notion: it is the SAME envelope the option contract
## already enforces on routes —
##     MovementOption.validate (MovementOption.gd:138):
##         normal_slack_limit = maxi(2, ceili(float(shortest_cost) * 0.25))
## Slice 2 never gave that formula a name or a config key; it is an inline
## expression inside the contract, and `MovementOptionService` defines no slack
## const of its own. These two constants therefore introduce the NAME, not the
## rule, and are deliberately tuned identically so the two cannot disagree.
##
## Slice-6 carry-forward: promote both to `balance.json` and have MovementOption
## read the same source, so route slack and target slack cannot drift apart.
const SLACK_FLOOR: int = 2
const SLACK_FRACTION: float = 0.25


# ---------------------------------------------------------------------------
# C1 — contract builders
# ---------------------------------------------------------------------------

## MovementProfile for the party token.
##
## Capacity is the DIRECTIVE step_budget (`directive.step_budget`;
## Scout Carefully 3, Seek Signs 6). The clamp(2,6) COMBAT capacity formula in
## MovementProfileService governs combat actors and is deliberately NOT imported.
##
## `controlling_state` is false: a party token projects no hostile control.
##
## `authored_override` (slice 5 amendment A4) is EMPTY for any in-window budget
## (>= AUTHORED_OVERRIDE_THRESHOLD): the party pace is config-driven, not authored.
## A budget BELOW the threshold is no longer silently clamped up to 2 — that
## inflated the party's pace and hid the bad config. It yields capacity 1 plus an
## authored_override naming `directive.step_budget` as its source, which is the
## seam MovementProfile.validate requires at capacity 1. The upper cap stays 6.
static func build_profile(directive: Dictionary) -> Dictionary:
	var step_budget: int = int(directive.get("step_budget", DEFAULT_STEP_BUDGET))
	var capacity: int = clampi(step_budget, MIN_EXPRESSIBLE_CAPACITY, MAX_EXPRESSIBLE_CAPACITY)
	var source_terms: Array = [{
		"source": CAPACITY_SOURCE,
		"directive_id": str(directive.get("id", "")),
		"step_budget": step_budget,
		"capacity": capacity,
	}]

	# Below-threshold budgets are surfaced, not silently repaired. The override's
	# `capacity` must equal the profile capacity (MovementProfile.validate).
	var authored_override: Dictionary = {}
	if step_budget < AUTHORED_OVERRIDE_THRESHOLD:
		authored_override = {"source": CAPACITY_SOURCE, "capacity": capacity}

	return ProfileContract.build(capacity, source_terms, false, ACTOR_KIND, authored_override)


## MovementGoal for one stage-explore advance.
##
## `target` accepts either a situation dict (`{id, pos, ...}`) or a bare frontier
## target (`{pos, is_frontier}`) — the two shapes FlowRuntime._find_explore_target
## returns today. `tier` is one of the TIER_* constants.
##
## Every moving stage goal is a `reposition`; a destination equal to the party
## cell (or a non-walkable destination) degrades to `hold`, the only purpose the
## contract lets contain the mover origin.
##
## WHY NOT `advance` for the objective tiers (slice 5 amendment A6): the contract
## requires an `advance` goal to name a non-empty `planned_primary.target_id` that
## also appears in `relevant_actors` (MovementGoal._validate_plan_for_purpose).
## A situation is not an actor, and A6 forbids putting situation ids in
## `relevant_actors` because `CombatPressureService._goal_sources` expands that
## field as `"actor.%s"` — which would publish the false source `actor.sit.obj`.
## Rather than launder a situation id as an actor to satisfy `advance`, stage
## goals use `reposition` (empty target permitted). The freeze's tier ORDERING is
## untouched: it is carried by `urgency` (TIER_URGENCY), which still ranks
## hard-objective (1/4) over weighted (2) over frontier (3), and the tier is
## additionally published as a `state.` pressure source.
static func build_goal(
	explore_map: Dictionary,
	target: Dictionary,
	tier: int,
	walkable: Dictionary
) -> Dictionary:
	var party_pos: Dictionary = _cell_of(explore_map.get("party_pos", {}))
	var destination: Dictionary = _cell_of(target.get("pos", target))
	var situation_id: String = str(target.get("id", ""))

	# Degrade to `hold` when there is nowhere to go: same cell, or a destination
	# the shared walkability authority rejects.
	var holds: bool = destination == party_pos or not StageTerrain.is_walkable(destination, walkable)
	if holds:
		destination = party_pos

	var purpose: String = "hold"
	var action_type: String = "actor.guard"
	if not holds:
		purpose = "reposition"
		action_type = "actor.move"

	# A6: `relevant_actors` names ACTORS. The stage party moves toward situations,
	# and a situation id is not an actor, so this stays empty for stage goals.
	var relevant_actors: Array = []

	var pressure_sources: Array = [
		"mode.%s" % GOAL_MODE,
		"role.%s" % GOAL_ROLE,
		str(TIER_PRESSURE_SOURCE.get(tier, TIER_PRESSURE_SOURCE[TIER_FRONTIER])),
	]
	# A situation id is admissible only under the `objective.` prefix, and only when
	# it is a semantic token — the same gate CombatPressureService._valid_source
	# applies. A non-conforming id is dropped rather than published invalid.
	if not situation_id.is_empty() and V.is_semantic_token(situation_id):
		pressure_sources.append("objective.%s" % situation_id)

	var urgency: float = float(TIER_URGENCY.get(tier, TIER_URGENCY[TIER_FRONTIER]))

	return GoalContract.build(
		"goal.%s.%s.%s.%s" % [GOAL_MODE, purpose, GOAL_ROLE, _anchor_token(destination)],
		purpose,
		[destination],
		urgency,
		_objective_progress(explore_map),
		relevant_actors,
		pressure_sources,
		ActionPlan.build(action_type),
		ActionPlan.build("actor.idle")
	)


## MovementIntent for the party token.
##
## `path` MUST already exclude the origin (MovementPathService.shortest_path
## returns exactly that shape). It is truncated to the profile capacity so the
## intent can never claim a commitment it cannot pay for.
static func build_intent(profile: Dictionary, goal: Dictionary, path: Array) -> Dictionary:
	var capacity: int = clampi(int(profile.get("capacity", 0)), 0, MAX_EXPRESSIBLE_CAPACITY)
	var committed_path: Array = []
	for cell_value: Variant in path:
		if committed_path.size() >= capacity:
			break
		committed_path.append(_cell_of(cell_value))

	var anchor: String = _goal_anchor_token(goal)
	return IntentContract.build(
		MOVER_ID,
		"activation.party.%s" % anchor,
		str(goal.get("goal_id", "")),
		"option.party.%s.d%d" % [anchor, committed_path.size()],
		committed_path,
		capacity,
		committed_path.size(),
		(goal.get("planned_primary", {}) as Dictionary),
		(goal.get("declared_fallback", {}) as Dictionary),
		(goal.get("pressure_sources", []) as Array)
	)


## MovementResult for one completed stage advance.
##
## `traversed` and the returned `planned_path` EXCLUDE the origin — a zero-step
## advance yields an EMPTY array, never `[origin]`.
##
## When `events` is empty and `traversed` is not, the voluntary step events are
## synthesised from the traversal (see build_step_events) so the result is
## self-consistent. When `events` is supplied it is authoritative and the derived
## totals (cost, forced steps, final destination, hazards) come from it.
##
## `intent` and `goal` are REQUIRED (slice 5 amendment A5). MovementResult carries
## identity fields (mover/activation/goal/option/purpose) that the four positional
## arguments cannot supply. The previous defaults fabricated `purpose: "hold"` over
## a real multi-cell walk, and `MovementResult.validate()` does not cross-check
## purpose against traversal, so that lie validated clean. A result must now be
## built from the intent and goal it actually resolves.
static func build_result(
	origin: Dictionary,
	traversed: Array,
	stop_reason: String,
	events: Array,
	intent: Dictionary,
	goal: Dictionary
) -> Dictionary:
	var origin_cell: Dictionary = _cell_of(origin)
	var path: Array = []
	for cell_value: Variant in traversed:
		path.append(_cell_of(cell_value))

	var resolved_events: Array = []
	if events.is_empty():
		resolved_events = _build_step_events(origin_cell, path, stop_reason)
	else:
		for event_value: Variant in events:
			resolved_events.append((event_value as Dictionary).duplicate(true))

	# Derive the cross-checked totals straight from the event stream so the
	# result always satisfies MovementResult.validate's projection checks.
	var voluntary_cost: int = 0
	var forced_steps: int = 0
	var hazards: Array = []
	var final_destination: Dictionary = origin_cell.duplicate(true)
	for event_value: Variant in resolved_events:
		var event: Dictionary = event_value as Dictionary
		var hazard: Dictionary = event.get("hazard", {}) as Dictionary
		if not hazard.is_empty():
			hazards.append(hazard.duplicate(true))
		var movement_kind: String = str(event.get("movement_kind", "none"))
		if movement_kind == "none":
			continue
		final_destination = _cell_of(event.get("to_pos", final_destination))
		if movement_kind == "voluntary":
			voluntary_cost += int(event.get("cost", 0))
		else:
			forced_steps += 1

	var capacity: int = clampi(int(intent.get("capacity", 0)), 0, MAX_EXPRESSIBLE_CAPACITY)
	var anchor: String = _anchor_token(origin_cell)
	return ResultContract.build(
		MOVER_ID,
		str(intent.get("activation_id", "activation.party.%s" % anchor)),
		str(intent.get("goal_id", goal.get("goal_id", "goal.%s.hold.%s.%s" % [GOAL_MODE, GOAL_ROLE, anchor]))),
		str(intent.get("option_id", "option.party.%s.d%d" % [anchor, path.size()])),
		str(goal.get("purpose", "hold")),
		origin_cell,
		final_destination,
		(intent.get("path", path) as Array),
		path,
		voluntary_cost,
		forced_steps,
		clampi(capacity - voluntary_cost, 0, MAX_EXPRESSIBLE_CAPACITY),
		stop_reason,
		resolved_events,
		(intent.get("planned_action", {}) as Dictionary),
		(intent.get("planned_action", {}) as Dictionary),
		(intent.get("fallback", {}) as Dictionary),
		hazards,
		float(goal.get("objective_progress", 0.0)),
		{}
	)


## Voluntary one-cost movement events for a destination-only `path`.
## The final event carries `stop_reason`; an empty path yields an empty array.
##
## PRIVATE: `build_result` is the only caller. It is not part of the frozen C1 API.
static func _build_step_events(origin: Dictionary, path: Array, stop_reason: String) -> Array:
	var events: Array = []
	var current: Dictionary = _cell_of(origin)
	for index: int in range(path.size()):
		var destination: Dictionary = _cell_of(path[index])
		events.append(EventContract.build(
			index,
			"movement",
			"movement.step",
			MOVER_ID,
			current,
			destination,
			"voluntary",
			1,
			{},
			0,
			stop_reason if index == path.size() - 1 else ""
		))
		current = destination
	return events


# ---------------------------------------------------------------------------
# C2 — corrected deterministic tie-breaks
# ---------------------------------------------------------------------------

## Pick one frontier cell out of `candidates`.
##
## `heading` is the party's previous travel delta ({col,row}); an empty heading
## makes criterion 2 neutral for every candidate. Returns the chosen {col,row},
## or {} when no candidate is reachable.
##
## Distances come from MovementPathService.reachable_cost_region, so the shared
## two-solid-corners diagonal rule applies. When `walkable` is the legacy
## all-walkable sentinel (empty) the board is unbounded and BFS cannot terminate,
## so chebyshev distance stands in.
static func select_frontier(
	candidates: Array,
	party_pos: Dictionary,
	heading: Dictionary,
	walkable: Dictionary
) -> Dictionary:
	var party: Dictionary = _cell_of(party_pos)
	var costs: Dictionary = {}
	var use_bfs: bool = not walkable.is_empty()
	if use_bfs:
		# Capacity == cell count: an upper bound on any in-region distance, so
		# nothing reachable is ever truncated away.
		var region: Dictionary = MovementPathService.reachable_cost_region(
			party, maxi(walkable.size(), 1), walkable, {}, {}, {}
		)
		if not bool(region.get("reachable", false)):
			return {}
		costs = region["costs"] as Dictionary

	var best: Dictionary = {}
	var best_rank: Array = []
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = _cell_of(candidate_value)
		var distance: int = 0
		if use_bfs:
			var key: String = V.canonical_cell_key(candidate)
			if not costs.has(key):
				continue  # unreachable under the shared edge rule
			distance = int(costs[key])
		else:
			distance = _chebyshev(party, candidate)
		var rank: Array = [
			distance,
			-_heading_continuation(party, candidate, heading),
			_chebyshev(party, candidate),
			_manhattan(party, candidate),
			# Criterion 4 — KNOWN BIAS, NOT a last resort. See the retraction block
			# at the top of this file. It is trivially reachable (party (2,2) vs
			# candidates (2,0)/(2,4) with no heading ties criteria 1-3), and because
			# no `heading` is produced anywhere in core/ today, criterion 2 scores 0
			# for every candidate and this becomes the EFFECTIVE tie-breaker.
			#
			# It is also not row/col ordering: `canonical_cell_key` yields "col,row"
			# and this is a LEXICOGRAPHIC STRING compare, so "10,3" < "9,3". The
			# induced order is jagged and non-monotone in either axis — neither
			# row-major nor col-major — and the compass direction it favours flips
			# with the digit count of the coordinates.
			#
			# Pinned by `frontier_headingless_tie_pins_known_bias`. Scheduled for
			# removal at slice 6, where plumbing `heading` is the top cutover risk.
			V.canonical_cell_key(candidate),
		]
		if best.is_empty() or _rank_less(rank, best_rank):
			best = candidate
			best_rank = rank
	return best


## Pick one situation out of `situations`.
##
## `dist_field` maps canonical "col,row" keys to BFS distance from the party
## (either StageTerrain.bfs_distance_field or a reachable_cost_region `costs`
## dict). Situations absent from a non-empty field are unreachable and skipped.
##
## `weights` is the resolved directive `target_preference` map and `category_map`
## is `data.stages.situation_category` from balance.json. Both are REQUIRED: a
## situation's weight is derived by mapping its `type` through `category_map` and
## then looking the resulting CATEGORY up in `weights` (see `_target_weight`).
##
## BOUNDED SLACK (slice 5 amendment A2). The earlier distance-first rule was a
## gameplay policy change smuggled in under a determinism heading: live code scores
## `weight * 1/(d+1)`, so making one cell of distance beat any weight flattened
## Scout Carefully and Seek Signs into identical behaviour. The corrected rule:
##
##   1. candidates farther than the nearest by MORE than the slack envelope are
##      dropped (`_slack_envelope`, the option contract's route-slack rule)
##   2. greatest configured target_preference weight
##   3. smallest BFS distance
##   4. situation id lexicographic
##
## So weight leads inside the envelope and distance still bounds how far the
## party will detour for a preferred category.
##
## Eligibility filtering (resolved / revealed / passed) stays with the caller —
## this function ranks whatever it is handed.
##
## Selection is INDEPENDENT of the order of `situations`: the id-lexicographic
## final criterion replaces today's implicit dependence on array position.
## Returns a copy of the chosen situation, or {}.
static func select_objective_target(
	situations: Array,
	dist_field: Dictionary,
	weights: Dictionary,
	category_map: Dictionary
) -> Dictionary:
	# Pass 1 — keep the reachable candidates and find the nearest distance, which
	# anchors the slack envelope.
	var eligible: Array = []
	var nearest: int = -1
	for situation_value: Variant in situations:
		if not situation_value is Dictionary:
			continue
		var situation: Dictionary = situation_value as Dictionary
		var position: Dictionary = _cell_of(situation.get("pos", {}))
		var distance: int = 0
		if not dist_field.is_empty():
			var key: String = V.canonical_cell_key(position)
			if not dist_field.has(key):
				continue  # unreachable
			distance = int(dist_field[key])
			if distance < 0:
				continue
		eligible.append({"situation": situation, "distance": distance})
		if nearest < 0 or distance < nearest:
			nearest = distance
	if eligible.is_empty():
		return {}

	# Pass 2 — drop everything outside the envelope, then let weight lead.
	var envelope: int = nearest + _slack_envelope(nearest)
	var best: Dictionary = {}
	var best_rank: Array = []
	for entry_value: Variant in eligible:
		var entry: Dictionary = entry_value as Dictionary
		var distance: int = int(entry["distance"])
		if distance > envelope:
			continue
		var situation: Dictionary = entry["situation"] as Dictionary
		var rank: Array = [
			-_target_weight(situation, weights, category_map),
			distance,
			str(situation.get("id", "")),
		]
		if best.is_empty() or _rank_less(rank, best_rank):
			best = situation
			best_rank = rank
	if best.is_empty():
		return {}
	return best.duplicate(true)


## How far past the nearest candidate the party will still consider a target.
##
## Mirrors MovementOption.validate's `normal_slack_limit` exactly (see SLACK_FLOOR
## / SLACK_FRACTION): a flat floor of 2 cells, widening to a quarter of the
## distance once the nearest target is far enough away for that to matter.
static func _slack_envelope(nearest_distance: int) -> int:
	return maxi(SLACK_FLOOR, ceili(float(nearest_distance) * SLACK_FRACTION))


## Directive `target_preference` weight for one situation.
##
## Mirrors the LIVE Tier-2 derivation in FlowRuntime._find_explore_target:
##     var sit_type := str(sit.get("type", ""))
##     var category := str(sit_cat_map.get(sit_type, "intel"))
##     var weight   := float(target_pref.get(category, 1.0))
## where `sit_cat_map` is `data.stages.situation_category` out of balance.json.
##
## An earlier draft read `situation["category"]` first, falling back to `type`.
## NO situation dict in this codebase carries a `category` key — the category is
## PRODUCED by the map lookup and never stored — so that branch was dead in
## production and was only ever exercised by fixtures that fabricated the key.
## The fallback is removed: `type` through `category_map` is the only path.
static func _target_weight(
	situation: Dictionary,
	weights: Dictionary,
	category_map: Dictionary
) -> float:
	var situation_type: String = str(situation.get("type", ""))
	var category: String = str(category_map.get(situation_type, DEFAULT_SITUATION_CATEGORY))
	return float(weights.get(category, DEFAULT_TARGET_WEIGHT))


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Lexicographic comparison of two equal-length, equal-typed criterion tuples.
static func _rank_less(left: Array, right: Array) -> bool:
	for index: int in range(left.size()):
		var a: Variant = left[index]
		var b: Variant = right[index]
		if a is String or b is String:
			if str(a) != str(b):
				return str(a) < str(b)
			continue
		if float(a) != float(b):
			return float(a) < float(b)
	return false


## How well a step toward `candidate` continues the party's previous heading.
##
## Sign-only per axis, summed: an integer in [-2, 2], greater is better. Using
## signs rather than magnitudes keeps the metric MIRROR-SYMMETRIC — mirroring the
## board flips the heading and the candidate delta together, so the score is
## preserved. An empty or zero heading scores every candidate 0.
static func _heading_continuation(
	party: Dictionary,
	candidate: Dictionary,
	heading: Dictionary
) -> int:
	if heading.is_empty():
		return 0
	var heading_col: int = signi(int(heading.get("col", 0)))
	var heading_row: int = signi(int(heading.get("row", 0)))
	var delta_col: int = signi(int(candidate["col"]) - int(party["col"]))
	var delta_row: int = signi(int(candidate["row"]) - int(party["row"]))
	return delta_col * heading_col + delta_row * heading_row


static func _chebyshev(from_cell: Dictionary, to_cell: Dictionary) -> int:
	return maxi(
		absi(int(to_cell["col"]) - int(from_cell["col"])),
		absi(int(to_cell["row"]) - int(from_cell["row"]))
	)


static func _manhattan(from_cell: Dictionary, to_cell: Dictionary) -> int:
	return absi(int(to_cell["col"]) - int(from_cell["col"])) \
		+ absi(int(to_cell["row"]) - int(from_cell["row"]))


## Fraction of this stage's OBJECTIVE situations already resolved, in [0, 1].
static func _objective_progress(explore_map: Dictionary) -> float:
	var situations_value: Variant = explore_map.get("situations", [])
	var situations: Array = situations_value if situations_value is Array else []
	var total: int = 0
	var resolved: int = 0
	for situation_value: Variant in situations:
		if not situation_value is Dictionary:
			continue
		var situation: Dictionary = situation_value as Dictionary
		if not bool(situation.get("is_objective", false)):
			continue
		total += 1
		if bool(situation.get("resolved", false)):
			resolved += 1
	if total <= 0:
		return 0.0
	return float(resolved) / float(total)


## Normalised {col, row} copy. Never returns a reference into the caller's data.
static func _cell_of(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"col": 0, "row": 0}
	var cell: Dictionary = value as Dictionary
	return {"col": int(cell.get("col", 0)), "row": int(cell.get("row", 0))}


## MovementGoal's goal_id anchor segment for a cell.
static func _anchor_token(cell: Dictionary) -> String:
	return "c%dr%d" % [int(cell["col"]), int(cell["row"])]


static func _goal_anchor_token(goal: Dictionary) -> String:
	var region_value: Variant = goal.get("destination_region", [])
	var region: Array = region_value if region_value is Array else []
	if region.is_empty():
		return "c0r0"
	return _anchor_token(_cell_of(region[0]))
