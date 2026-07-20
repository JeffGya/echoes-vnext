class_name CombatPressureService
extends RefCounted

## Pure dormant adapter from perceived combat pressure to complete movement goals.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")
const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const PressureContract = preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

const EscapeAuthority = preload("res://core/movement/PursueEscapeService.gd")

const BUCKET_DIRECT := "direct"
const BUCKET_TACTICAL := "tactical"
const BUCKET_SAFETY := "safety"
const LOW := 0.25
const NORMAL := 0.50
const HIGH := 0.75
const CRITICAL := 1.00

## V2-COMBAT-002 Slice 4, Unit D — spatial-mode tuning (dormant, no config seam yet).
##
## Mover health at or below this ratio is a local collapse: a board fall-back
## (`withdraw`) candidate is emitted into the SAFETY bucket ALONGSIDE the ordinary
## safety engage, at HIGH urgency versus the engage's NORMAL. It therefore
## OUTRANKS the engage in that bucket's shortlist rather than replacing it — the
## engage candidate is still built, still validated, and still wins the bucket if
## the withdraw candidate is dropped (e.g. an empty derived region). Mirrors the
## 0.5 band already used for objective health.
const COLLAPSE_HEALTH := 0.5
## Chebyshev radius searched for board fall-back ground. Bounds the derived
## region without needing a count cap (a count cap would not be mirror-covariant).
const FALLBACK_RADIUS := 3
## Outer Chebyshev radius for derived interception lanes.
const INTERCEPT_LANE_RADIUS := 3


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

	_add_board_fallback(candidates, context, pressure)

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
		var carrier_cutoff: Array = pressure["approach_region"] as Array
		if _is_living_actor(carrier):
			var carrier_region: Array = _adjacent_region(context, carrier["position"] as Dictionary, false)
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "pursue", "hunter", carrier_region, CRITICAL, [str(carrier["id"])])
			# §13.4 "focus or cut off the enemy carrier" — the fleeing carrier is an
			# escaper, so its cutoff is projected from its own traversable escape
			# graph rather than from the objective-approach lane (which points the
			# wrong way once custody has already been taken).
			carrier_cutoff = _region_or(
				_cutoff_region(context, carrier["position"] as Dictionary),
				pressure["approach_region"] as Array
			)
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "cut_off", "blocker", carrier_cutoff, HIGH, [str(pressure["carrier_id"])])
	elif alignment == "party":
		_add_goal(candidates, BUCKET_DIRECT, context, pressure, "protect", "protector", _screen_or_authored(context, pressure, pressure["objective_position"] as Dictionary), HIGH, [str(pressure["objective_id"])])
		_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "blocker", _lane_or_authored(context, pressure, pressure["objective_position"] as Dictionary), HIGH, [str(pressure["objective_id"])])
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
		# §13.6 — "cutoff projection from the quarry's traversable escape graph
		# rather than geometric direction". Cutoff TARGETING is the one place where
		# the escape graph outranks authored regions: an authored containment region
		# describes desirable ground, but only the quarry's real traversable corridor
		# describes ground that actually cuts the quarry off. When a corridor exists
		# it is therefore PRIMARY. Authored containment terrain remains the fallback
		# for when no corridor can be projected (quarry gone, unreachable, or fully
		# contained), and the geometric approach lane remains the last resort.
		#
		# This overrides ONLY cutoff targeting. Escape timing, containment timing and
		# quarry capacity/economy are untouched, and every other mode's authored
		# regions still win.
		var corridor: Array = []
		if _is_living_actor(quarry) and bool(quarry["is_quarry"]):
			corridor = _cutoff_region(context, quarry["position"] as Dictionary)
		if not corridor.is_empty():
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "cut_off", "blocker", corridor, HIGH, [str(pressure["quarry_id"])])
		elif not (pressure["fallback_region"] as Array).is_empty():
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "cut_off", "blocker", pressure["fallback_region"] as Array, HIGH, [str(pressure["quarry_id"])])
		elif not (pressure["approach_region"] as Array).is_empty():
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
			# §13.7 — the spirit is a MOVING anchor, so a derived screen/rear-guard is
			# taken around the spirit's live position when no authored region exists.
			var spirit_position: Dictionary = spirit["position"] as Dictionary
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, purpose, "protector", _screen_or_authored(context, pressure, spirit_position), HIGH, [str(pressure["spirit_id"])])
			_add_goal(candidates, BUCKET_TACTICAL, context, pressure, "intercept", "rear_guard", _lane_or_authored(context, pressure, spirit_position), HIGH, [str(pressure["spirit_id"])])
		_add_truthful_engage(candidates, context, pressure)
	elif alignment == "hostile":
		if spirit_is_active:
			_add_goal(candidates, BUCKET_DIRECT, context, pressure, "advance", "escort_threat", pressure["destination_region"] as Array, CRITICAL, [str(pressure["spirit_id"])])
			_add_actor_engage(candidates, BUCKET_TACTICAL, context, pressure, "breaker", NORMAL, str(pressure["spirit_id"]))
		_add_truthful_engage(candidates, context, pressure, [str(pressure["spirit_id"])])
	else:
		_add_truthful_engage(candidates, context, pressure)


# ---------------------------------------------------------------------------
# V2-COMBAT-002 Slice 4, Unit D — SPATIAL REALISATION (pure, dormant)
#
# Every helper below is a pure function of the supplied context/pressure facts:
# no RNG, no OS time, no mutation, no live state. They publish REGIONS ONLY —
# none of them decides win/loss, custody transfer, or objective progress. Those
# remain owned by the round-end objective layer (and, for custody, Unit C).
#
# Authority rule (uniform across this unit): a region supplied by the objective
# authority is always preferred. These helpers only derive a spatially real
# region where the authority is SILENT (empty region) and the goal would
# otherwise be dropped or approximated by geometric direction.
#
# Mirror-safety: every predicate below is expressed in Chebyshev distance or in
# reachability over the walkable set. Both are invariant under horizontal /
# vertical mirroring and transposition, so derived MEMBERSHIP is mirror-
# covariant. Region ORDER is not a claim of this unit: `_add_goal` re-sorts every
# region through `V.canonical_position_array`. Region size is bounded by a value
# predicate (a radius), never by a count cap — a count cap would break mirror
# covariance by tie-breaking on raw coordinates.
# ---------------------------------------------------------------------------


## Board fall-back under local collapse (§13.4 "move toward fallback terrain when
## current custody is failing", §13.5 "controlled fallback ... when the line
## breaks"). Uses the EXISTING `withdraw` purpose — this is a tactical board
## fall-back, NOT withdrawal from the encounter (that stays RetreatService).
##
## Dormant gate: only a collapsing mover falls back, so a healthy board is
## completely unaffected. Objective-aligned movers (quarry / non-joining spirit)
## are excluded outright so PURSUE quarry timing and economy stay untouched.
static func _add_board_fallback(
	candidates: Array, context: Dictionary, pressure: Dictionary
) -> void:
	if str(pressure["mover_alignment"]) == "objective":
		return
	var mover: Dictionary = _actor_by_id(context, str(context["mover_id"]))
	if not _is_living_actor(mover):
		return
	if float(mover.get("health_ratio", 1.0)) > COLLAPSE_HEALTH:
		return
	# FIX 6 — the `withdraw` goal deliberately does NOT borrow
	# `pressure["fallback_region"]`, even though that key names "fallback".
	# `fallback_region` is MODE-SPECIFIC authored terrain, and in PURSUE it is the
	# CONTAINMENT region: the net the hunters push the QUARRY into. Reusing it here
	# would send a wounded pursuer to retreat into exactly the ground it is trying
	# to trap its target on — precisely backwards, and a pure naming collision
	# rather than a shared meaning. The board fall-back has its own purpose-built
	# derivation (`_board_fallback_region`: reachable ground strictly farther from
	# the nearest hostile than the mover's current cell), which is correct in every
	# mode because it is defined against threat distance, not against an objective.
	var region: Array = _board_fallback_region(context)
	if region.is_empty():
		return
	# Safety bucket at HIGH: under collapse, falling back outranks the ordinary
	# NORMAL-urgency engage inside that bucket (both are emitted; see
	# COLLAPSE_HEALTH).
	_add_goal(candidates, BUCKET_SAFETY, context, pressure, "withdraw", "baseline", region, HIGH, [])


## Reachable ground that is strictly SAFER than the mover's current cell.
##
## A cell qualifies when it is reachable from the origin within FALLBACK_RADIUS
## over the authoritative walkable set (honouring the diagonal rule via
## MovementPathService) AND its distance to the nearest perceived hostile is
## strictly greater than the origin's. "Strictly greater" is what makes this a
## real fall-back rather than a lateral shuffle, and it is what keeps the region
## disjoint from the `advance` regions (which close on hostiles).
static func _board_fallback_region(context: Dictionary) -> Array:
	var hostiles: Array = _hostiles(context)
	if hostiles.is_empty():
		return []
	var origin: Dictionary = context["origin"] as Dictionary
	var origin_threat: int = _threat_distance(origin, hostiles)
	var region: Dictionary = MovementPathService.reachable_cost_region(
		origin,
		FALLBACK_RADIUS,
		context["authoritative_walkable"] as Dictionary,
		{},
		context["bounds"] as Dictionary,
		{}
	)
	if not bool(region.get("reachable", false)):
		return []
	var cells: Array = []
	for key_value: Variant in (region["costs"] as Dictionary):
		var cell: Dictionary = V.parse_canonical_cell_key(str(key_value))
		if cell.is_empty() or cell == origin:
			continue
		if _threat_distance(cell, hostiles) > origin_threat:
			cells.append(cell)
	# FIX 7 — canonicalise ORDER at the source. Membership here is already
	# mirror-covariant, but the raw order is Dictionary iteration order. Any direct
	# consumer that takes `region[0]` would otherwise inherit an arbitrary bias.
	return _canonical_cells(cells)


## Interposition cells: ground that physically stands between a perceived hostile
## and the protected actor (§13.4 "occupy intercept cells", §13.7 "front screen").
##
## `min_distance`/`max_distance` are Chebyshev bands measured from the PROTECTED
## actor, which is what separates a close screen (band 1) from an interception
## lane further out (band 2..N). A cell is on the lane when it sits on a Chebyshev
## geodesic between the hostile and the protected actor:
##     dist(hostile, cell) + dist(cell, protected) == dist(hostile, protected)
static func _interposition_region(
	context: Dictionary,
	protected_position: Dictionary,
	min_distance: int,
	max_distance: int
) -> Array:
	if protected_position.is_empty():
		return []
	var hostiles: Array = _hostiles(context)
	if hostiles.is_empty():
		return []
	var cells: Array = []
	for hostile_value: Variant in hostiles:
		var hostile: Dictionary = hostile_value as Dictionary
		var hostile_position: Dictionary = hostile["position"] as Dictionary
		var span: int = _chebyshev(hostile_position, protected_position)
		if span < min_distance + 1:
			continue
		for col_delta: int in range(-max_distance, max_distance + 1):
			for row_delta: int in range(-max_distance, max_distance + 1):
				var cell := {
					"col": int(protected_position["col"]) + col_delta,
					"row": int(protected_position["row"]) + row_delta,
				}
				# FIX 4 — this producer builds cells by ARITHMETIC, so unlike
				# `_board_fallback_region` (reachable_cost_region) and
				# `_cutoff_region` (escape graph) it inherits no board guard. A
				# protected actor near an edge would otherwise emit negative /
				# off-board columns and rows, and solid terrain, into the region.
				if not _in_bounds_walkable(context, cell):
					continue
				var to_protected: int = _chebyshev(cell, protected_position)
				if to_protected < min_distance or to_protected > max_distance:
					continue
				if cell == hostile_position:
					continue
				if _chebyshev(hostile_position, cell) + to_protected != span:
					continue
				if not cells.has(cell):
					cells.append(cell)
	return _canonical_cells(cells)


## Interception cells projected from an escaper's traversable escape graph
## (§13.6 "cutoff projection from the quarry's traversable escape graph rather
## than geometric direction").
##
## The mover itself is the candidate interceptor, so it is passed as the sole
## pursuer: PursueEscapeService then keeps only corridor cells this mover can
## actually reach no later than the escaper. Perceived structures are passed as
## blockers so the corridor bends around them exactly as traversal would.
##
## `context["bounds"]` is ALREADY the canonical { "w", "h" } movement-domain
## shape that PursueEscapeService documents, so it is forwarded unchanged — no
## board_cols/board_rows adaptation is required at this seam.
static func _cutoff_region(context: Dictionary, escaper_position: Dictionary) -> Array:
	if escaper_position.is_empty():
		return []
	# FIX 7 — PursueEscapeService orders the corridor by quarry cost and then by RAW
	# (col,row). Membership is mirror-covariant, but that second key is not: a
	# mirrored board yields the mirror SET in a different ORDER. Re-sort to the
	# canonical cell key here so no consumer taking `region[0]` inherits a
	# west-then-north bias. (The cost ordering is PursueEscapeService's own
	# contract and is untouched there — this canonicalises only what this adapter
	# publishes.)
	return _canonical_cells(EscapeAuthority.cutoff_cells(
		escaper_position,
		context["bounds"] as Dictionary,
		context["authoritative_walkable"] as Dictionary,
		[context["origin"] as Dictionary],
		_structure_blockers(context)
	))


## Authored destination region, else a derived close screen around the protected
## actor. Derivation is gated on a KNOWN objective: the pressure contract forbids
## regions while the objective is unknown, so the adapter must stay silent too.
static func _screen_or_authored(
	context: Dictionary, pressure: Dictionary, protected_position: Dictionary
) -> Array:
	var authored: Array = pressure["destination_region"] as Array
	if not authored.is_empty() or not bool(pressure["objective_known"]):
		return authored
	return _interposition_region(context, protected_position, 1, 1)


## Authored approach region, else a derived interception lane standing off the
## protected actor. Same known-objective gate as `_screen_or_authored`.
static func _lane_or_authored(
	context: Dictionary, pressure: Dictionary, protected_position: Dictionary
) -> Array:
	var authored: Array = pressure["approach_region"] as Array
	if not authored.is_empty() or not bool(pressure["objective_known"]):
		return authored
	return _interposition_region(context, protected_position, 2, INTERCEPT_LANE_RADIUS)


static func _structure_blockers(context: Dictionary) -> Array:
	var blockers: Array = []
	for actor_value: Variant in context["perceived_actors"] as Array:
		var actor: Dictionary = actor_value as Dictionary
		if bool(actor["is_structure"]) and not bool(actor["is_dead"]):
			blockers.append((actor["position"] as Dictionary).duplicate(true))
	blockers.sort_custom(func(a: Variant, b: Variant) -> bool:
		return V.canonical_cell_key(a as Dictionary) < V.canonical_cell_key(b as Dictionary)
	)
	return blockers


## In-bounds + walkable guard for DERIVED region producers (FIX 4).
##
## `_board_fallback_region` and `_cutoff_region` get this for free from
## `reachable_cost_region` / the escape graph. `_interposition_region` constructs
## cells arithmetically and must apply it explicitly.
static func _in_bounds_walkable(context: Dictionary, cell: Dictionary) -> bool:
	var bounds: Dictionary = context["bounds"] as Dictionary
	var width: int = int(bounds.get("w", 0))
	var height: int = int(bounds.get("h", 0))
	var col: int = int(cell["col"])
	var row: int = int(cell["row"])
	if col < 0 or row < 0 or col >= width or row >= height:
		return false
	return StageTerrain.is_walkable(cell, context["authoritative_walkable"] as Dictionary)


## Canonical (col, row) ordering for every DERIVED region this unit publishes, so
## region ORDER never carries a directional bias (FIX 7).
##
## Uses `V.canonical_position_array` — the SAME comparator the goal contract
## validates against (`require_canonical_position_array`). It compares col and row
## NUMERICALLY, so it stays correct past column 9, where a lexical "col,row" string
## sort would place "10,0" before "2,0".
static func _canonical_cells(cells: Array) -> Array:
	return V.canonical_position_array(cells)


static func _threat_distance(cell: Dictionary, hostiles: Array) -> int:
	var nearest: int = -1
	for hostile_value: Variant in hostiles:
		var hostile: Dictionary = hostile_value as Dictionary
		var distance: int = _chebyshev(cell, hostile["position"] as Dictionary)
		if nearest < 0 or distance < nearest:
			nearest = distance
	return nearest


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(
		absi(int(a["col"]) - int(b["col"])),
		absi(int(a["row"]) - int(b["row"]))
	)


static func _region_or(preferred: Array, alternative: Array) -> Array:
	return preferred if not preferred.is_empty() else alternative


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
