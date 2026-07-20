# res://core/movement/GuideSpiritActivationService.gd
# V2-COMBAT-002 Slice 4 (Unit B, DORMANT): the non-joining GUIDE spirit's
# objective-phase movement, expressed as an explicit NPC activation through the
# SHARED movement executor.
#
# Pure, deterministic, stateless. No RNG, no OS time, no mutation of inputs, no
# actor/combat_state writes, no logging. NOT wired into live combat/flow — only
# tests consume it. This is the dormant replacement for FlowRuntime._end_round's
# inline escort/skittish block; live cutover is slice 6.
#
# ---------------------------------------------------------------------------
# BOUNDARY (important):
#   This service owns HOW the spirit moves, NEVER whether the objective advances.
#   Escort-radius checks, the escort-started latch, the skittish radius, the
#   destination-reached / guide_protect_counter decisions and every bark are
#   OBJECTIVE authority owned by the caller. They are accepted here as already-
#   decided inputs (guide_state.should_move) and are never re-derived. The
#   returned MovementResult always reports objective_progress 0.0 — scoring GUIDE
#   progress happens in the caller, AFTER this activation resolves.
#
# ---------------------------------------------------------------------------
# ENTRY:
#   activate_spirit(spirit_actor, context, guide_state, hazard_ctx, capacity_cfg)
#     -> validated MovementResult dict.
#
#     spirit_actor : the non-joining spirit actor dict (read-only). Supplies
#                    mover id, actor kind, and (optionally) current_hp for the
#                    activation's KO/death truth.
#     context      : MovementExecutor/MovementContext dict — origin, bounds,
#                    authoritative_walkable, occupancy, terrain_costs,
#                    known_hazards, perceived_actors, relationships.
#     guide_state  : caller-owned guide facts (see GUIDE STATE below).
#     hazard_ctx   : per-activation hazard ledger, config injected by the caller:
#                    {"triggered": {unstable,binding,burning: bool}, "config": <hazards cfg>}.
#     capacity_cfg : data.combat.movement.capacity, injected by the caller. Passed
#                    to MovementProfileService only for signature conformance — the
#                    authored override means it never affects the derived capacity.
#
# PRECONDITION — NON-JOINING SPIRITS ONLY (FIX 3):
#   This service exists for the spirit that does NOT join the battle. It stamps an
#   authored_override of capacity 1 unconditionally, so calling it on a JOINED
#   spirit would silently pin a full combatant to a single cell per round. A joined
#   spirit is an ORDINARY combatant and must go through the ordinary
#   MovementProfileService/CombatActivationService path instead.
#   `guide_state.joined` (default false) is therefore a hard precondition: when it
#   is true this service REFUSES — it selects no step, spends nothing, and stamps
#   the correlation goal_id `REFUSED_JOINED_GOAL_ID` so a mis-branched slice-6
#   caller fails loudly and visibly rather than inheriting a plausible-looking
#   one-cell result. It never throws and always returns a valid MovementResult.
#
# GUIDE STATE (caller-supplied; this service decides none of it):
#   "mode"            String  : "escort" | "protect". Anything else -> no movement.
#   "joined"          bool    : caller's spirit_joins_battle fact. TRUE -> refused
#                               (see PRECONDITION). Default false.
#   "should_move"     bool    : the caller's movement gate (escort: escort latched
#                               AND an echo within escort_radius AND not arrived;
#                               protect: enemy inside skittish_radius AND no echo
#                               adjacent). Default true. False -> the spirit holds.
#   "destination"     Dict    : {col,row} authored escort destination (escort mode).
#   "threats"         Array   : ordered [{col,row}, ...] threat cells (protect mode).
#                               CALLER ORDER IS AUTHORITATIVE for nearest-threat ties.
#   "activation_id"   String  : correlation id (default "guide.activation").
#   "goal_id"         String  : correlation id (default "guide.escort"/"guide.protect").
#   "option_id"       String  : correlation id (default "guide.step").
#   "authored_source" String  : profile source label (default "guide_spirit_nonjoining").
#   "mover_ko_only"   bool    : report "ko" instead of "death" when downed.
#
# ---------------------------------------------------------------------------
# AUTHORED PACE (FROZEN):
#   The non-joining spirit keeps its authored ONE-CELL-PER-ROUND pace. The profile
#   is ALWAYS obtained via
#     MovementProfileService.derive_profile(actor, capacity_cfg,
#       {"authored_override": {"source": <authored_source>, "capacity": 1}})
#   so it can never be auto-upgraded into the ordinary 2-6 capacity envelope.
#   The planned path is therefore at most ONE cell and commitment is at most 1.
#
# STEP SELECTION (deterministic, no RNG):
#   escort  — MovementPathService.shortest_path(origin, destination, ...) over the
#             SAME walkable/bounds/terrain_costs the executor uses; the first cell
#             of that path is the single step. (The live code used
#             StageTerrain.bfs_distance_field + next_step over an occupancy-pruned
#             walkable set; shortest_path is chosen here because it is the shared
#             slice-1 routing primitive, already carries the two-solid-corners
#             diagonal rule via StageTerrain.legal_neighbors, and honours terrain
#             entry costs — which the raw BFS field did not.) Occupancy is NOT
#             pre-pruned: the step is handed to the executor, whose own occupancy
#             rule stops the spirit with stop_reason "occupied" — i.e. it waits,
#             exactly like every other actor. Unreachable destination -> empty path
#             -> "no_route".
#
#   protect — one step AWAY from the nearest threat, chosen among
#             StageTerrain.legal_neighbors(origin, walkable, bounds) minus cells
#             occupied by anyone other than the spirit. Ranking (all maximised):
#               1. Chebyshev distance to the nearest threat
#               2. Manhattan distance to the nearest threat
#               3. the ascending-sorted vector of Chebyshev distances to ALL
#                  threats, compared lexicographically
#               4. the ascending-sorted vector of Chebyshev distances to every
#                  OBSTRUCTION (in-bounds non-walkable cell, plus any cell
#                  occupied by someone other than the spirit), compared
#                  lexicographically — i.e. prefer open ground, least pinned
#                  against terrain or bodies
#               5. numeric cell order (col asc, then row asc) — last resort
#
#             HONEST SCOPE OF KEY 5 (corrected — the earlier claim that key 4/5
#             fired "ONLY for irreducible perfect symmetry" was FALSE):
#             keys 1-3 are all functions of the THREAT distances only. With a
#             SINGLE threat — the common case for a protect-mode spirit — keys 1-3
#             collapse to (Chebyshev, Manhattan) to one point, which pins only the
#             multiset {|Δcol|,|Δrow|} and therefore provably CANNOT separate a
#             transposed pair such as (4,3) vs (3,4). A board that is NOT
#             self-symmetric could still reach the numeric fallback and answer
#             non-covariantly. Key 4 closes that window by bringing the board's own
#             asymmetric terrain/occupancy into the comparison; being a pure
#             Chebyshev-distance vector it is covariant under reflection AND
#             transposition, so it breaks such ties by geometry.
#             Key 5 REMAINS as the last resort and is deliberately NOT removed:
#             true symmetry is undecidable by any deterministic rule, so some
#             numeric tiebreak must terminate the ordering. It is now merely
#             narrower — irreducible under the threat AND obstruction keys, which
#             is a much smaller window than under the threat keys alone.
#
#             Nearest threat = minimum Chebyshev; ties keep the EARLIEST
#             caller-supplied threat (caller order, never a coordinate bias).
#
# EXECUTION:
#   The chosen step is packaged as a MovementIntent and run through
#   CombatActivationService.activate, so the spirit obeys the identical terrain,
#   occupancy, two-solid-corners diagonal, hostile-control, hazard and event rules
#   as any other actor. The declared action is a position-independent actor.idle
#   (the non-joining spirit never attacks), so no action ever invalidates.

class_name GuideSpiritActivationService
extends RefCounted

const ProfileService = preload("res://core/movement/MovementProfileService.gd")
const PathService = preload("res://core/movement/MovementPathService.gd")
const ActivationService = preload("res://core/movement/CombatActivationService.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")
const StageTerrain = preload("res://core/realms/StageTerrain.gd")

const MODE_ESCORT: String = "escort"
const MODE_PROTECT: String = "protect"

## The authored non-joining pace: exactly one cell per round, never derived.
const AUTHORED_CAPACITY: int = 1
const DEFAULT_AUTHORED_SOURCE: String = "guide_spirit_nonjoining"

## Correlation goal_id stamped when the PRECONDITION is violated (joined spirit).
const REFUSED_JOINED_GOAL_ID: String = "guide.refused_joined_spirit"


static func activate_spirit(
	spirit_actor: Dictionary,
	context: Dictionary,
	guide_state: Dictionary,
	hazard_ctx: Dictionary,
	capacity_cfg: Dictionary
) -> Dictionary:
	var mover_id: String = str(spirit_actor.get("id", "guide.spirit"))
	var origin: Dictionary = _cell_of(context.get("origin", {}) as Dictionary)
	var walkable: Dictionary = context.get("authoritative_walkable", {}) as Dictionary
	var bounds: Dictionary = context.get("bounds", {}) as Dictionary
	var occupancy: Dictionary = context.get("occupancy", {}) as Dictionary
	var terrain_costs: Dictionary = context.get("terrain_costs", {}) as Dictionary

	var mode: String = str(guide_state.get("mode", ""))
	var should_move: bool = bool(guide_state.get("should_move", true))

	# --- PRECONDITION: non-joining spirits ONLY (see header). ------------------
	# A joined spirit is an ordinary combatant; capping it at the authored one-cell
	# pace would be a silent, hard-to-trace nerf. Refuse loudly instead.
	var joined: bool = bool(guide_state.get("joined", false))
	if joined:
		should_move = false

	# --- Authored profile: ALWAYS capacity 1 via the override channel. ---------
	var authored_source: String = str(guide_state.get("authored_source", DEFAULT_AUTHORED_SOURCE))
	var profile: Dictionary = ProfileService.derive_profile(
		spirit_actor,
		capacity_cfg,
		{"authored_override": {"source": authored_source, "capacity": AUTHORED_CAPACITY}}
	)

	# --- Single step selection (caller gate first; this service never re-derives it).
	var step: Dictionary = {}
	if should_move:
		if mode == MODE_ESCORT:
			step = _escort_step(origin, guide_state, walkable, terrain_costs, bounds)
		elif mode == MODE_PROTECT:
			step = _skittish_step(origin, guide_state, walkable, bounds, occupancy, mover_id)

	var path: Array = [] if step.is_empty() else [step]
	var commitment: int = 0 if path.is_empty() else AUTHORED_CAPACITY

	var goal_id: String = REFUSED_JOINED_GOAL_ID if joined else str(
		guide_state.get("goal_id", "guide.%s" % (mode if not mode.is_empty() else "hold"))
	)
	var intent: Dictionary = IntentContract.build(
		mover_id,
		str(guide_state.get("activation_id", "guide.activation")),
		goal_id,
		str(guide_state.get("option_id", "guide.step")),
		path,
		int(profile.get("capacity", AUTHORED_CAPACITY)),
		commitment,
		ActionPlan.build("actor.idle"),
		{},
		[]
	)

	var action_ctx: Dictionary = {
		# escort/protect are both declared MovementGoal purposes; actor.idle is a
		# permitted fallback for each, so the idle plan can never invalidate.
		"purpose": MODE_ESCORT if mode == MODE_ESCORT else MODE_PROTECT,
		"goal_id": str(intent["goal_id"]),
		"option_id": str(intent["option_id"]),
		# NO objective authority here — progress scoring belongs to the caller.
		"objective_progress": 0.0,
	}
	if spirit_actor.has("current_hp"):
		action_ctx["mover_hp"] = int(spirit_actor["current_hp"])
	if guide_state.has("mover_ko_only"):
		action_ctx["mover_ko_only"] = bool(guide_state["mover_ko_only"])

	return ActivationService.activate(context, intent, profile, hazard_ctx, action_ctx)


# ---------------------------------------------------------------------------
# STEP SELECTION
# ---------------------------------------------------------------------------

## First cell of the shortest route to the authored destination, or {} when there
## is no destination / no route. Occupancy is deliberately NOT pruned here: the
## executor's own occupancy rule makes the spirit wait ("occupied").
static func _escort_step(
	origin: Dictionary,
	guide_state: Dictionary,
	walkable: Dictionary,
	terrain_costs: Dictionary,
	bounds: Dictionary
) -> Dictionary:
	if not (guide_state.get("destination", {}) is Dictionary):
		return {}
	var destination: Dictionary = guide_state["destination"] as Dictionary
	if not destination.has("col") or not destination.has("row"):
		return {}
	var route: Dictionary = PathService.shortest_path(
		origin, _cell_of(destination), walkable, terrain_costs, bounds
	)
	if not bool(route.get("reachable", false)):
		return {}
	var cells: Array = route.get("path", []) as Array
	if cells.is_empty():
		return {}
	return _cell_of(cells[0] as Dictionary)


## One deterministic step away from the nearest threat. Returns {} when there are
## no threats or no free legal neighbour (the spirit then holds).
static func _skittish_step(
	origin: Dictionary,
	guide_state: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary,
	occupancy: Dictionary,
	mover_id: String
) -> Dictionary:
	var threats: Array = _threat_cells(guide_state)
	if threats.is_empty():
		return {}
	var nearest: Dictionary = _nearest_threat(origin, threats)
	# Computed ONCE: identical for every candidate, so the key-4 vectors always
	# share a length and compare term-by-term.
	var obstructions: Array = _obstruction_cells(walkable, bounds, occupancy, mover_id)

	var best: Dictionary = {}
	var best_key: Array = []
	for candidate_value: Variant in StageTerrain.legal_neighbors(origin, walkable, bounds):
		var candidate: Dictionary = _cell_of(candidate_value as Dictionary)
		var occupant_key: String = _cell_key(candidate)
		if occupancy.has(occupant_key) and str(occupancy[occupant_key]) != mover_id:
			continue
		var key: Array = [
			_chebyshev(candidate, nearest),
			_manhattan(candidate, nearest),
			_threat_distance_vector(candidate, threats),
			_distance_vector(candidate, obstructions),
		]
		if best.is_empty() or _key_greater(key, best_key) \
				or (key == best_key and _cell_less(candidate, best)):
			best = candidate
			best_key = key
	return best


## Ascending-sorted Chebyshev distances to EVERY threat. Reflection-covariant, so
## it breaks mirror ties by geometry rather than by a raw coordinate preference.
static func _threat_distance_vector(cell: Dictionary, threats: Array) -> Array:
	return _distance_vector(cell, threats)


## Ascending-sorted Chebyshev distances from `cell` to every cell in `others`.
## Pure distance data — covariant under reflection AND transposition.
static func _distance_vector(cell: Dictionary, others: Array) -> Array:
	var distances: Array = []
	for other_value: Variant in others:
		distances.append(_chebyshev(cell, other_value as Dictionary))
	distances.sort()
	return distances


## Every cell the spirit could NOT step into: in-bounds non-walkable terrain plus
## cells occupied by someone other than the spirit. Enumerated in canonical
## (col, row) order so the SET is stable; the ranking only ever consumes the
## sorted distance vector, so this order carries no directional bias.
##
## An EMPTY `walkable` dict is the legacy all-walkable sentinel (StageTerrain's
## own rule), which means there is no blocked terrain to report.
static func _obstruction_cells(
	walkable: Dictionary, bounds: Dictionary, occupancy: Dictionary, mover_id: String
) -> Array:
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	var seen: Dictionary = {}
	var cells: Array = []
	if not walkable.is_empty() and width > 0 and height > 0:
		for col in range(width):
			for row in range(height):
				var key: String = "%d,%d" % [col, row]
				if bool(walkable.get(key, false)):
					continue
				seen[key] = true
				cells.append({"col": col, "row": row})
	for occupancy_key: Variant in occupancy:
		var occupant_cell_key: String = str(occupancy_key)
		if str(occupancy[occupancy_key]) == mover_id:
			continue
		if seen.has(occupant_cell_key):
			continue
		var parts: PackedStringArray = occupant_cell_key.split(",")
		if parts.size() != 2:
			continue
		seen[occupant_cell_key] = true
		cells.append({"col": int(parts[0]), "row": int(parts[1])})
	cells.sort_custom(Callable(GuideSpiritActivationService, "_cell_less"))
	return cells


## Lexicographic "greater" over the ranking key (Array of ints / Array of ints).
static func _key_greater(left: Array, right: Array) -> bool:
	for index in range(mini(left.size(), right.size())):
		var left_term: Variant = left[index]
		var right_term: Variant = right[index]
		if left_term is Array:
			if _key_greater(left_term as Array, right_term as Array):
				return true
			if _key_greater(right_term as Array, left_term as Array):
				return false
			continue
		if int(left_term) != int(right_term):
			return int(left_term) > int(right_term)
	return false


## Minimum-Chebyshev threat; ties keep the EARLIEST caller-supplied threat.
static func _nearest_threat(origin: Dictionary, threats: Array) -> Dictionary:
	var nearest: Dictionary = _cell_of(threats[0] as Dictionary)
	var nearest_distance: int = _chebyshev(origin, nearest)
	for index in range(1, threats.size()):
		var threat: Dictionary = _cell_of(threats[index] as Dictionary)
		var distance: int = _chebyshev(origin, threat)
		if distance < nearest_distance:
			nearest = threat
			nearest_distance = distance
	return nearest


static func _threat_cells(guide_state: Dictionary) -> Array:
	var raw: Array = guide_state.get("threats", []) as Array
	var cells: Array = []
	for threat_value: Variant in raw:
		if not (threat_value is Dictionary):
			continue
		var threat: Dictionary = threat_value as Dictionary
		if threat.has("col") and threat.has("row"):
			cells.append(_cell_of(threat))
	return cells


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

static func _cell_of(cell: Dictionary) -> Dictionary:
	return {"col": int(cell.get("col", 0)), "row": int(cell.get("row", 0))}


static func _cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(
		absi(int(a.get("col", 0)) - int(b.get("col", 0))),
		absi(int(a.get("row", 0)) - int(b.get("row", 0)))
	)


static func _manhattan(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a.get("col", 0)) - int(b.get("col", 0))) \
		+ absi(int(a.get("row", 0)) - int(b.get("row", 0)))


## Numeric cell order (col asc, then row asc). Used ONLY for irreducible perfect
## symmetry, mirroring MovementPathService's documented tiebreak idiom.
static func _cell_less(left: Dictionary, right: Dictionary) -> bool:
	var left_col: int = int(left.get("col", 0))
	var right_col: int = int(right.get("col", 0))
	if left_col != right_col:
		return left_col < right_col
	return int(left.get("row", 0)) < int(right.get("row", 0))
