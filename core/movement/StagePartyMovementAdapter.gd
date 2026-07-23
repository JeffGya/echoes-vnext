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
#     3. smallest chebyshev to party
#     4. salted FNV-1a of the canonical cell key  <- compass-de-aligned, see below
#     5. canonical cell key "col,row"             <- terminal guard (hash collision)
#
#   select_objective_target (slice 5 amendment A2 — bounded slack):
#     1. candidates farther than the nearest by more than the slack envelope are
#        DROPPED; inside the envelope, weight leads
#     2. greatest configured target_preference weight
#     3. smallest BFS distance
#     4. situation id lexicographic        <- replaces today's implicit
#                                             dependence on situations[] order
#     5. canonical cell key "col,row"      <- total-order guard (slice 6 6A/U3)
#
# SLICE 6 PHASE 6A, UNIT 3 — MANHATTAN REMOVED FROM select_frontier.
#
# The old criterion 3b was `smallest manhattan to party`, applied AFTER chebyshev.
# It was an ANISOTROPY, not a tie-break: BFS here is 8-way (the shared
# two-solid-corners diagonal rule), so an orthogonal candidate d cells away and a
# diagonal candidate d cells away are EQUIDISTANT in travel cost and equal in
# chebyshev — but manhattan scores them d and 2d respectively. Every unresolved
# tie between an orthogonal and a diagonal frontier therefore went to the
# orthogonal one, systematically, forever.
#
# It was invisible to `frontier_mirrored_boards_have_no_directional_bias` because
# manhattan is MIRROR-SYMMETRIC: reflecting the board maps an orthogonal candidate
# to an orthogonal candidate and a diagonal to a diagonal, so the anisotropy
# survives every mirror unchanged. The anti-bias test can only see COMPASS bias,
# never AXIS-vs-DIAGONAL bias.
#
# It is REMOVED rather than kept, because chebyshev on an 8-way grid already IS
# "nearest by travel cost" — manhattan is the 4-way metric and does not describe
# any movement this adapter can produce. Keeping it would mean deliberately
# preferring axis-aligned exploration, which is a gameplay policy nobody authored.
# Removing it changes no currently-pinned answer: every fixture in the suite ties
# chebyshev and manhattan together, so the outcomes are identical.
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
# COMPASS-DE-ALIGNED CRITERION 4 (slice 6 phase 6A, unit 4) — pulled forward
# from 6C, Jeff approved.
# ---------------------------------------------------------------------------
# Criterion 4 WAS a lexicographic STRING compare of the canonical `"col,row"` key.
# Three separate things were wrong with it, and slice 5's retraction block
# (preserved below in substance) got all three right:
#
#   * It is trivially reachable, not a last resort. Party (2,2) with candidates
#     (2,0) and (2,4) and no heading ties criteria 1-3, so criterion 4 decides.
#   * `heading` is not produced anywhere in `core/` today, so criterion 2 scores
#     every candidate 0 for every selection. Until it is plumbed, criterion 4 is
#     the EFFECTIVE tie-breaker rather than a fallback.
#   * It is not even row-major or col-major ordering. `V.canonical_cell_key`
#     yields "col,row" and a lexicographic string compare puts "10,3" < "9,3", so
#     the induced order is jagged, non-monotone in either axis, and the compass
#     direction it favours FLIPS with the digit count of the coordinates.
#
# WHY IT HAD TO BE FIXED IN THIS PHASE rather than deferred to 6C: unit 3 removed
# the manhattan sub-criterion (see MANHATTAN REMOVED above). Manhattan used to
# absorb every orthogonal-vs-diagonal tie before criterion 4 saw it. With it gone,
# a full ring of candidates at chebyshev d from the party — 8 directions, all at
# BFS cost d under the shared 8-way edge rule — now ties all the way down to
# criterion 4. That is roughly 2d times more traffic through this guard, and it
# moved the systematic preference from "due West" to "the NW corner". Removing one
# bias made the other one materially worse, so shipping them a phase apart would
# have shipped a regression.
#
# THE REPLACEMENT: a salted FNV-1a hash of a stage-derived salt plus the canonical
# cell key (`_salted_cell_hash`). FNV-1a is implemented explicitly in GDScript
# rather than calling `String.hash()`, so replay determinism does not depend on an
# engine internal that carries no cross-version guarantee.
#
# HONEST CAVEAT — WHAT THIS DOES NOT ACHIEVE. Two candidates related by a mirror
# symmetry of BOTH the board and the party are genuinely indistinguishable: no
# deterministic rule can "correctly" prefer one, because there is no fact that
# separates them. True mirror-covariance is unachievable and is NOT claimed. What
# IS achieved is the removal of SYSTEMATIC compass preference — the answer no
# longer correlates with direction, so the party does not drift toward a fixed
# quadrant run after run. That is the property
# `frontier_tie_break_has_no_systematic_compass_bias` asserts, alongside exact
# replay determinism.
#
# THE SALT IS A PARAMETER, never read from config here — this adapter stays PURE
# (no ConfigService, no RNG, no `OS.*`, no file I/O). At cutover the caller sources
# it from STAGE IDENTITY already present in `explore_map` / the run state
# (realm id + stage index), which is persisted in the save and constant for the
# life of the stage. That gives exact replay within a run and uncorrelated
# de-alignment between stages. The default empty salt is legitimate and fully
# deterministic — it simply de-aligns every stage identically.

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

## Missing-key fallback when a directive dict carries no `step_budget` at all.
##
## SLICE 6 PHASE 6A, UNIT 3 — this is now an ALIAS, not a third copy. Unit 1 made
## `DirectiveService.DEFAULT_STEP_BUDGET` the one canonical fallback and collapsed
## FlowRuntime's and FlowStageExploreState's independent `3`s onto it; this file
## held a fourth. Three constants that must agree and are free to drift is a bug
## waiting for a config change, so it is sourced rather than duplicated.
##
## This does NOT compromise the adapter's purity. It is a compile-time `const`
## read off a class, so there is no instantiation, no `ConfigService` call, no
## file I/O and no state — exactly the same category of dependency as the
## `preload`ed contract scripts above. `DirectiveService` is `core/directives/`,
## a peer of `core/movement/` in the deterministic core, so no layer is crossed.
##
## It also does not affect dormancy: dormancy is about production callers OF
## `core/movement/`, and this is `core/movement/` calling OUT to a const.
const DEFAULT_STEP_BUDGET: int = DirectiveService.DEFAULT_STEP_BUDGET

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
## SLICE 6 PHASE 6A, UNIT 3 — these two are now the INVARIANT CONTRACT FLOOR, and
## `data.combat.movement.slack` (Unit 1) is a seam that may only NARROW it. See
## `_slack_envelope` for the clamp and the reasoning.
const SLACK_FLOOR: int = 2
const SLACK_FRACTION: float = 0.25

## Keys the injected `data.combat.movement.slack` object supplies.
const SLACK_CONFIG_FLOOR_KEY: String = "floor"
const SLACK_CONFIG_FRACTION_KEY: String = "fraction"

## FNV-1a/32 parameters for `select_frontier`'s criterion-4 guard. See
## `_fnv1a_32` for why this is hand-rolled rather than `String.hash()`.
const FNV_OFFSET_BASIS: int = 2166136261
const FNV_PRIME: int = 16777619
const FNV_MASK_32: int = 0xffffffff


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
## A destination equal to the party cell (or a non-walkable destination) degrades
## to `hold`, the only purpose the contract lets contain the mover origin.
##
## SLICE 6 PHASE 6A — THE OBJECTIVE TIERS NOW EMIT `advance`.
##
## Slice 5 (amendment A6) had to emit `reposition` for EVERY moving stage goal,
## because `MovementGoal._validate_plan_for_purpose` then required an `advance` to
## name a non-empty `planned_primary.target_id` that also appeared in
## `relevant_actors` — and a situation is not an actor. Laundering a situation id
## through `relevant_actors` was refused, because `CombatPressureService._goal_sources`
## expands that field as `"actor.%s"` and would have published the false fact
## `actor.sit.obj`. So the compromise was to under-claim.
##
## Unit 2 added the PLACE-DIRECTED shape: an `advance` may leave `target_id` EMPTY
## iff `pressure_sources` carries an `objective.<id>` source naming what it advances
## toward. That is exactly the shape this adapter already emits, so the compromise
## is now unnecessary and is lifted — but only where it is TRUE:
##
##   TIER_OBJECTIVE / TIER_PASSED_OBJECTIVE -> `advance`
##       These target an AUTHORED stage objective, which is precisely what
##       docs/movement-model.md §9 says `advance` means: "reduce route distance to
##       an authored objective". The `objective.<id>` source is not manufactured
##       to unlock the label — it is the situation's own id, published under the
##       `objective.` prefix, and the purpose is chosen FROM whether that source
##       was truthfully emitted (see `has_objective_source` below), never the
##       other way round. An objective-tier target with a missing or
##       non-semantic id publishes no objective source and therefore stays
##       `reposition` rather than claiming an objective it cannot name.
##
##   TIER_WEIGHTED -> `reposition`
##       A Tier-2 situation is a weighted point of interest the party drifts
##       toward, not the stage's authored objective (`is_objective` is what
##       separates them). It carries an `objective.` source, so the contract WOULD
##       now admit `advance` — the restriction here is semantic, not structural.
##
##   TIER_FRONTIER -> `reposition`
##       A frontier is unexplored space, has no id, and publishes NO objective
##       source at all. §9's "authored objective" does not describe it, and the
##       contract would reject the claim anyway. It must stay `reposition`.
##
## The freeze's tier ORDERING is untouched either way: it is carried by `urgency`
## (TIER_URGENCY), which still ranks hard-objective (1/4) over weighted (2) over
## frontier (3), and the tier is additionally published as a `state.` source.
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
	#
	# This flag is derived from what was ACTUALLY published, and the purpose below
	# is chosen from it. The dependency runs source -> purpose and never the
	# reverse: no source is added in order to make `advance` validate.
	var has_objective_source: bool = not situation_id.is_empty() and V.is_semantic_token(situation_id)
	if has_objective_source:
		pressure_sources.append("objective.%s" % situation_id)

	var targets_authored_objective: bool = (
		tier == TIER_OBJECTIVE or tier == TIER_PASSED_OBJECTIVE
	)

	var purpose: String = "hold"
	var action_type: String = "actor.guard"
	if not holds:
		action_type = "actor.move"
		if targets_authored_objective and has_objective_source:
			purpose = "advance"
		else:
			purpose = "reposition"

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
##
## SLICE 6 PHASE 6A, UNIT 3 — THE ORIGIN GUARD IS NOW ENFORCED, NOT ASSUMED.
##
## Slice 5 documented path-excludes-origin as a precondition and then copied
## `path` verbatim, trusting the caller. `MovementResult.validate` enforces the
## same rule on `planned_path`, so a violating intent produced a *valid-looking*
## intent that only blew up later, one layer away from the router that caused it.
##
## `mover_origin` is therefore now REQUIRED (the same call the caller already
## makes for `MovementIntent.validate(intent, origin)`), and the check reuses
## `MovementContractValidation.require_path_excludes_origin` rather than
## reimplementing it — one rule, one implementation.
##
## A violation returns an EMPTY Dictionary. It is deliberately NOT repaired by
## dropping the origin cell: a path containing its own origin means the caller's
## router is wrong, and silently repairing it would hide that exactly the way
## slice 5 amendment A4 refused to hide a below-threshold step budget. An empty
## return cannot be mistaken for a usable intent — `MovementIntent.validate`
## rejects it immediately on missing fields.
##
## SLICE 6 PHASE 6A, UNIT 4 — THE GUARD NO LONGER FAILS OPEN, AND NO LONGER
## INVENTS AN ORIGIN.
##
## Unit 3 compared a RAW path cell against a `_cell_of`-NORMALISED origin, and
## `require_path_excludes_origin` tests exact Dictionary equality. Two ways that
## fails OPEN, both silently:
##
##   * a path cell carrying an extra key (`{"col":1,"row":1,"cost":2}`) or float
##     coordinates (`{"col":1.0,"row":1.0}`) is not `==` to `{"col":1,"row":1}`,
##     so an origin-containing path SAILED THROUGH the guard. The Unit-3 test
##     could not see this: it passed the identical dict literal as both the origin
##     and the path element, which is the one shape that cannot expose the
##     mismatch. BOTH SIDES are now normalised through `_cell_of`, so the guard
##     compares geometry rather than dict layout.
##
##   * `_cell_of({})` returns `{"col":0,"row":0}`, so an ABSENT origin was coerced
##     into a real cell and the guard was applied against (0,0).
##     `require_path_excludes_origin` deliberately bypasses on an EMPTY origin
##     ("no origin declared, nothing to exclude"); coercion defeated that bypass
##     and silently rejected any legitimate path crossing the board corner. The
##     empty origin is now preserved as empty and the contract's own bypass runs.
static func build_intent(
	profile: Dictionary,
	goal: Dictionary,
	path: Array,
	mover_origin: Dictionary
) -> Dictionary:
	# Normalise BOTH sides so the equality test compares cells, not dict shapes —
	# but never manufacture an origin the caller did not supply.
	var guarded_origin: Dictionary = {} if mover_origin.is_empty() else _cell_of(mover_origin)
	var guarded_path: Array = []
	for cell_value: Variant in path:
		guarded_path.append(_cell_of(cell_value))
	var origin_guard: Dictionary = V.require_path_excludes_origin(
		guarded_path, guarded_origin, "path"
	)
	if not bool(origin_guard["valid"]):
		return {}

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
##
## SLICE 6 PHASE 6A, UNIT 3 — `resolved_action` IS NOW A REAL SEAM.
##
## It previously took `intent.planned_action` unconditionally for BOTH fields, so
## planned and resolved could not diverge by construction. `MovementResult` carries
## them as two fields precisely because they CAN diverge: the plan is what the goal
## declared, the resolution is what the executor actually got to do. The stop
## reasons `action_invalid_no_fallback`, `blocked_edge`, `occupied`, `interrupted`,
## `ko` and `death` all describe runs where a declared `actor.move` ends up
## resolving as the goal's `actor.idle` fallback, or as nothing at all.
##
## `resolved_action` is therefore an explicit trailing argument. EMPTY (the default)
## means "resolved exactly as planned" and reproduces the previous behaviour
## byte-for-byte, so no existing caller changes; a caller that knows better passes
## the action that actually resolved. At cutover `MovementExecutor` is that caller.
##
## Note `MovementResult.validate` only type-checks `resolved_action`, so it will
## NOT catch a caller that keeps mirroring the plan — this is a seam the executor
## has to use honestly, not a rule the contract can enforce.
static func build_result(
	origin: Dictionary,
	traversed: Array,
	stop_reason: String,
	events: Array,
	intent: Dictionary,
	goal: Dictionary,
	resolved_action: Dictionary = {}
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
	var planned_action: Dictionary = intent.get("planned_action", {}) as Dictionary
	# Empty means "resolved as planned" — see the docblock. The plan is never
	# overwritten by the resolution; both are reported.
	var actually_resolved: Dictionary = planned_action
	if not resolved_action.is_empty():
		actually_resolved = resolved_action
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
		planned_action,
		actually_resolved,
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
	walkable: Dictionary,
	salt: String = ""
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
		var candidate_key: String = V.canonical_cell_key(candidate)
		var rank: Array = [
			distance,
			-_heading_continuation(party, candidate, heading),
			# Criterion 3 — chebyshev ONLY. The manhattan sub-criterion that used to
			# sit under this line was removed in slice 6 phase 6A: on an 8-way grid it
			# scored an equidistant diagonal candidate 2d against an orthogonal
			# candidate's d, systematically deprioritising diagonal frontiers, and was
			# invisible to the mirror test because it is mirror-symmetric. See the
			# MANHATTAN REMOVED block at the top of this file.
			_chebyshev(party, candidate),
			# Criterion 4 — COMPASS-DE-ALIGNED GUARD (slice 6 phase 6A, unit 4).
			# Salted FNV-1a over the canonical key. Deterministic and replay-exact,
			# but uncorrelated with compass direction, so a tie no longer resolves
			# toward a fixed quadrant. See the COMPASS-DE-ALIGNED block at the top of
			# this file for why this had to land now rather than at 6C.
			float(_salted_cell_hash(salt, candidate_key)),
			# Criterion 5 — terminal total-order guard. Reached ONLY when two tied
			# candidates COLLIDE in the 32-bit hash, which criterion 4 cannot break by
			# construction. Some deterministic rule has to terminate the ordering, and
			# at that point the residual choice is arbitrary by definition.
			candidate_key,
		]
		if best.is_empty() or _rank_less(rank, best_rank):
			best = candidate
			best_rank = rank
	return best


## Pick one situation out of `situations`.
##
## `dist_field` maps canonical "col,row" keys to travel cost from the party.
## Situations absent from a non-empty field are unreachable and skipped.
##
## IT MUST BE A `MovementPathService.reachable_cost_region` `costs` DICT.
## SLICE 6 PHASE 6A, UNIT 3 — the docstring previously also admitted a
## `StageTerrain.bfs_distance_field`, and that permission was a bug. That field
## expands neighbours with a raw `walkable.has(key)` test and so IGNORES the shared
## two-solid-corners diagonal rule, while `select_frontier` (and everything else on
## this adapter's path) routes through `reachable_cost_region`, which applies it.
## Accepting both means objective selection and frontier selection can disagree
## about which cell is "nearest" INSIDE A SINGLE ADVANCE — the objective layer
## would cost a route through a diagonal the movement layer refuses to walk. One
## distance authority, or none.
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
##   5. canonical cell key "col,row"  <- total-order guard, slice 6 phase 6A
##
## So weight leads inside the envelope and distance still bounds how far the
## party will detour for a preferred category.
##
## `slack_config` is the injected `data.combat.movement.slack` object. It is a
## PARAMETER: this adapter never loads config itself. Empty (the default) uses the
## contract constants. See `_slack_envelope` for the narrow-only clamp.
##
## Eligibility filtering (resolved / revealed / passed) stays with the caller —
## this function ranks whatever it is handed.
##
## SLICE 6 PHASE 6A, UNIT 3 — CRITERION 4 WAS NOT A TOTAL ORDER.
##
## Criterion 4 exists to remove the dependence on `situations[]` array position.
## It only did so when every id was present and unique. Two situations sharing an
## id — or two both LACKING one, which `str(situation.get("id", ""))` collapses to
## the same `""` — tied criterion 4 completely and fell through to array position:
## exactly the flaw the criterion was added to remove.
##
## AN ID-LESS ENTRY IS LEGITIMATE INPUT, NOT MALFORMED DATA. (Slice 6 phase 6A,
## unit 4 — this docblock previously called id-less entries "legitimate" in one
## paragraph and "malformed" in the next, and only the first is true.) Stage
## situations are generated, and a frontier-shaped entry carries no id at all by
## design. That is why the fix is a genuine total-order guard rather than a
## documented precondition: the precondition is not one the caller can cheaply
## guarantee, because well-formed callers legitimately produce id-less entries.
## Criterion 5 is the situation's own canonical cell key, distinct for any two
## situations that are not co-located.
##
## The RESIDUAL precondition, stated explicitly: two situations that share a
## position AND an id are indistinguishable to this function and still resolve by
## array position. That is a genuine data duplicate, not a tie-break gap — no
## deterministic rule can prefer one over the other, and repairing it belongs to
## whatever produced them.
##
## KNOWN, ACCEPTED FOR NOW — criterion 5 carries the SAME defect as frontier
## criterion 4 did. It is a lexicographic string compare of `"col,row"`, so
## "10,3" < "9,3" and the induced order is jagged, non-monotone in either axis, and
## flips its favoured compass direction with coordinate magnitude. The earlier
## claim that this was "acceptable HERE and not there" rested on id-less entries
## being rare malformed data; since they are in fact ordinary input, that
## justification does not hold and is withdrawn.
##
## It is left unchanged in this unit deliberately. The approved scope was frontier
## criterion 4, whose traffic unit 3 materially increased; this one is reached only
## after weight AND distance AND id have all tied, so the exposure is far smaller.
## When it is fixed it FOLLOWS CRITERION 4'S FIX — the same salted `_fnv1a_32` over
## the canonical key, with the salt threaded in as a parameter — rather than
## inventing a second mechanism.
##
## Returns a copy of the chosen situation, or {}.
static func select_objective_target(
	situations: Array,
	dist_field: Dictionary,
	weights: Dictionary,
	category_map: Dictionary,
	slack_config: Dictionary = {}
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
		eligible.append({"situation": situation, "distance": distance, "pos": position})
		if nearest < 0 or distance < nearest:
			nearest = distance
	if eligible.is_empty():
		return {}

	# Pass 2 — drop everything outside the envelope, then let weight lead.
	var envelope: int = nearest + _slack_envelope(nearest, slack_config)
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
			# Criterion 5 — the total-order guard. Reached only when weight, distance
			# AND id all tie, i.e. duplicate or id-less situations. See the docblock.
			V.canonical_cell_key(entry["pos"] as Dictionary),
		]
		if best.is_empty() or _rank_less(rank, best_rank):
			best = situation
			best_rank = rank
	if best.is_empty():
		return {}
	return best.duplicate(true)


## How far past the nearest candidate the party will still consider a target.
##
## Baseline is MovementOption.validate's `normal_slack_limit` (see SLACK_FLOOR /
## SLACK_FRACTION): a flat floor of 2 cells, widening to a quarter of the distance
## once the nearest target is far enough away for that to matter.
##
## SLICE 6 PHASE 6A, UNIT 3 — CONFIG MAY NARROW, NEVER WIDEN (plan decision 5).
##
## `slack_config` is the injected `data.combat.movement.slack` object (Unit 1),
## passed in by the caller — this adapter never reads config itself, so it stays
## pure and testable with a literal Dictionary.
##
## The result is clamped DOWN to the contract limit and never up. That asymmetry
## is the whole point: `MovementOption.validate` enforces
##     maxi(2, ceili(float(shortest_cost) * 0.25))
## as an inline, deliberately CONFIG-FREE invariant. If config could widen this
## envelope, the adapter would happily select targets whose routes the option
## contract then rejects outright — a config edit would produce goals the movement
## layer structurally cannot serve, and the failure would surface at the contract
## boundary far from the number that caused it. Narrowing is always safe: a
## tighter envelope only ever proposes routes the contract already admits.
##
## Negative or non-numeric config is floored at zero rather than trusted, so a
## broken key can only tighten toward "nearest wins", never invert the rule.
##
## SLICE 6 PHASE 6A, UNIT 4 — "non-numeric" IS NOW ACTUALLY TRUE.
##
## This read the two keys with bare `int()` / `float()` casts, which do not tolerate
## non-numeric input at all: `int({})` and `float([])` are hard runtime cast errors,
## not zeroes. So a Dictionary or Array in `balance.json` CRASHED here while the
## docstring promised it was floored at zero. The values are now type-gated first,
## matching the discipline `CombatPressureService._cfg_number` already applies to
## the sibling `data.combat.movement.pressure` keys — one config-reading rule
## across the movement layer, not two.
static func _slack_envelope(nearest_distance: int, slack_config: Dictionary = {}) -> int:
	var contract_limit: int = maxi(SLACK_FLOOR, ceili(float(nearest_distance) * SLACK_FRACTION))
	if slack_config.is_empty():
		return contract_limit
	var configured_floor: int = maxi(
		0, int(_cfg_number(slack_config, SLACK_CONFIG_FLOOR_KEY, float(SLACK_FLOOR)))
	)
	var configured_fraction: float = maxf(
		0.0, _cfg_number(slack_config, SLACK_CONFIG_FRACTION_KEY, SLACK_FRACTION)
	)
	var configured_limit: int = maxi(
		configured_floor, ceili(float(nearest_distance) * configured_fraction)
	)
	return mini(configured_limit, contract_limit)


## Numeric config read, type-gated. A key whose value is not an int or a float
## (Dictionary, Array, String, null, or absent) yields `fallback` rather than
## raising a cast error.
##
## Deliberately a local mirror of `CombatPressureService._cfg_number` rather than a
## call into it: this adapter's purity guarantee is that it preloads contracts and
## nothing else, and `CombatPressureService` is a SERVICE. The rule is four lines;
## the coupling would cost more than the duplication. Keep the two in step.
static func _cfg_number(cfg: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = cfg.get(key, null)
	if value is int or value is float:
		return float(value)
	return fallback


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

## Criterion 4's compass-de-aligned tie value: FNV-1a/32 over `<salt>|<cell key>`.
##
## FNV-1a IS IMPLEMENTED EXPLICITLY HERE, ON PURPOSE. `String.hash()` is an engine
## internal with no compatibility guarantee across Godot versions, and this value
## decides which cell the party walks to — a saved run must replay to the same
## answer after an engine upgrade. Twelve lines of arithmetic buy that guarantee
## outright. Standard 32-bit parameters (offset basis 2166136261, prime 16777619),
## masked to 32 bits after every step; GDScript ints are 64-bit, so the widest
## intermediate (2^32 * 2^24) cannot overflow.
##
## The value is a pure function of (salt, cell) — no RNG, no clock, no state — so
## replay is exact and the function stays as pure as the rest of this adapter.
static func _salted_cell_hash(salt: String, cell_key: String) -> int:
	return _fnv1a_32("%s|%s" % [salt, cell_key])


static func _fnv1a_32(text: String) -> int:
	var digest: int = FNV_OFFSET_BASIS
	for byte: int in text.to_utf8_buffer():
		digest = (digest ^ byte) & FNV_MASK_32
		digest = (digest * FNV_PRIME) & FNV_MASK_32
	return digest


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
