# res://core/movement/MovementHazardService.gd
# V2-COMBAT-002 Slice 3 (DORMANT): fixed-hazard behavior resolver.
#
# Pure, deterministic, stateless. No RNG, no OS time, no mutation of inputs.
# NOT wired into live combat/flow — the MovementExecutor (next agent) + tests are
# the only consumers. Resolves hazards against PHYSICAL hazard facts supplied by the
# caller (the executor owns physical truth); it never reads perceived planner facts,
# never reads ConfigService (config is INJECTED), and never touches actor/combat state.
#
# ---------------------------------------------------------------------------
# HAZARD FACTS (input `hazards` Array) — each item conforms to
# MovementKnownHazardFact.build(): { "id": String, "position": {col,row},
# "hazard_type": "unstable"|"binding"|"burning" }. Each fact is a single authored
# cell (its position is also its authored CENTER for single-cell hazards).
#
# CONTEXT (input `context` Dictionary) — caller-owned, all optional except config:
#   "config"          Dictionary : INJECTED data.combat.movement.hazards dict.
#   "walkable"        Dictionary : StageTerrain walkable set ({} = all-walkable sentinel).
#   "bounds"          Dictionary : {w,h} board bounds for edge legality.
#   "occupied"        Dictionary : set "col,row"->true of cells blocked by other actors
#                                  (a forced displacement may not land on these). Default {}.
#   "mover_id"        String     : MovementEvent source_id. Default "hazard".
#   "phase"           String     : MovementEvent phase label. Default "movement"
#                                  (end-activation resolver defaults to "end_activation").
#   "seq"             int        : next MovementEvent seq the caller wants assigned. Default 0.
#                                  Every returned dict carries "next_seq" so the executor
#                                  chains hazard events into its own strictly-increasing seq.
#   "from_cell"       Dictionary : the cell the actor moved FROM into entered_cell (the
#                                  incoming edge). Used ONLY when the actor is exactly on a
#                                  hazard's authored center (single-cell hazards always are).
#   "is_forced_entry" bool       : true when this entry is itself a forced hazard landing.
#                                  Guards Unstable/Binding against re-triggering on a forced
#                                  displacement (belt-and-suspenders with the ledger).
#
# ---------------------------------------------------------------------------
# LEDGER (`hazard_ctx`) — each hazard TYPE triggers at most once per actor activation.
#   Shape: { "triggered": { "unstable": bool, "binding": bool, "burning": bool } }
#   Build a fresh one with new_ledger(). Resolvers NEVER mutate the passed-in ledger;
#   they return an updated deep copy under "hazard_ctx".
#
# ---------------------------------------------------------------------------
# ORDER PER ACTIVATION (FROZEN):
#   cell entry -> Unstable displacement OR fallback_damage (no legal cell) -> Binding stop.
#   Burning is END-of-activation only (resolve_end_activation), applied once.
#
# UNSTABLE DISPLACEMENT DIRECTION:
#   outward = sign(entered - authored_center) per axis; when the actor is EXACTLY on the
#   center (single-cell hazards always are), outward = sign(entered - from_cell) (incoming
#   edge). Displacement is ONE 8-dir cell (frozen displacement_cells == 1; multi-cell
#   chaining is reserved for tuning). The straight outward cell is preferred; if it is not a
#   legal + walkable + unoccupied edge, ALTERNATIVES are ranked by (outward progress DESC,
#   then angular deviation ASC) — NEVER by global row/column order. A genuine tie (two
#   mirror-image candidates equal on BOTH keys) is treated as "no unambiguous cell" and
#   resolves to fallback_damage with NO move — this keeps the choice free of any row/col
#   bias and mirror-symmetric. Diagonal legality (two-solid-corners rule) is enforced via
#   StageTerrain.is_legal_edge, so a diagonal squeezing between two solids is never chosen.
#   Forced displacement consumes NO voluntary capacity and CANNOT recursively retrigger
#   Unstable: a single resolve_cell_entry call checks Unstable once, and the ledger +
#   is_forced_entry guard any follow-up entry the executor may resolve on the landing cell.

class_name MovementHazardService
extends RefCounted

const StageTerrain = preload("res://core/realms/StageTerrain.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")

const HAZARD_TYPES: Array = ["unstable", "binding", "burning"]


# ---------------------------------------------------------------------------
# LEDGER
# ---------------------------------------------------------------------------

## Fresh per-activation ledger: no hazard type has triggered yet.
static func new_ledger() -> Dictionary:
	return {"triggered": {"unstable": false, "binding": false, "burning": false}}


## Deep, normalized copy of a ledger (never mutate caller input).
static func _ledger_copy(hazard_ctx: Dictionary) -> Dictionary:
	var triggered_in: Dictionary = hazard_ctx.get("triggered", {}) as Dictionary
	return {
		"triggered": {
			"unstable": bool(triggered_in.get("unstable", false)),
			"binding": bool(triggered_in.get("binding", false)),
			"burning": bool(triggered_in.get("burning", false)),
		}
	}


# ---------------------------------------------------------------------------
# PUBLIC RESOLVERS
# ---------------------------------------------------------------------------

## Resolve hazards on a single cell entry: Unstable (displacement OR fallback_damage)
## then Binding (stop). Returns:
##   {
##     "displaced":    bool,        # Unstable forced a displacement
##     "displaced_to": {col,row},   # cell the actor occupies after Unstable (== entered if none)
##     "stop":         bool,        # Binding stopped movement
##     "stop_reason":  String,      # "binding_stop" when stop, else ""
##     "damage":       int,         # Unstable fallback_damage (0 otherwise)
##     "events":       Array,       # ordered MovementEvent dicts (MovementEvent.build shape)
##     "next_seq":     int,         # next free seq after the emitted events
##     "hazard_ctx":   Dictionary,  # updated ledger (deep copy)
##   }
static func resolve_cell_entry(
	entered_cell: Dictionary,
	hazards: Array,
	context: Dictionary,
	hazard_ctx: Dictionary
) -> Dictionary:
	var ledger: Dictionary = _ledger_copy(hazard_ctx)
	var triggered: Dictionary = ledger["triggered"] as Dictionary
	var events: Array = []
	var seq: int = int(context.get("seq", 0))
	var mover_id: String = str(context.get("mover_id", "hazard"))
	var phase: String = str(context.get("phase", "movement"))
	var walkable: Dictionary = context.get("walkable", {}) as Dictionary
	var bounds: Dictionary = context.get("bounds", {}) as Dictionary
	var occupied: Dictionary = context.get("occupied", {}) as Dictionary
	var config: Dictionary = context.get("config", {}) as Dictionary
	var is_forced_entry: bool = bool(context.get("is_forced_entry", false))
	# V2-INFRA-003 pass 8: leadership traits position_lock (owner) and anchor_presence
	# (allies in radius) make a mover immune to Unstable's forced displacement. The
	# hazard still triggers once per activation — the mover simply is not moved, and
	# takes no fallback_damage, because nothing tried to push it off the cell.
	var immune_to_displacement: bool = bool(context.get("immune_to_displacement", false))

	var final_cell: Dictionary = entered_cell.duplicate(true)
	var displaced: bool = false
	var damage: int = 0

	# --- Unstable: voluntary entry only, once per activation ---
	if not is_forced_entry and not bool(triggered["unstable"]):
		var unstable_matches: Array = _hazards_at(hazards, entered_cell, "unstable")
		if not unstable_matches.is_empty():
			triggered["unstable"] = true
			var hazard: Dictionary = unstable_matches[0] as Dictionary
			var ucfg: Dictionary = config.get("unstable", {}) as Dictionary
			var fallback_damage: int = int(ucfg.get("fallback_damage", 0))
			var from_cell: Dictionary = context.get("from_cell", {}) as Dictionary
			var target: Dictionary = {} if immune_to_displacement else _displacement_target(
				entered_cell, hazard, from_cell, walkable, bounds, occupied
			)
			if immune_to_displacement:
				events.append(EventContract.build(
					seq, phase, "hazard.unstable.resisted", mover_id,
					entered_cell, entered_cell, "none", 0,
					_descriptor(hazard, "displacement_resisted"), 0, ""
				))
				seq += 1
			elif not target.is_empty():
				events.append(EventContract.build(
					seq, phase, "hazard.unstable.displace", mover_id,
					entered_cell, target, "forced", 0,
					_descriptor(hazard, "displacement"), 0, ""
				))
				seq += 1
				final_cell = target.duplicate(true)
				displaced = true
			else:
				# No legal, unambiguous displacement cell -> fallback_damage, no move.
				damage = fallback_damage
				events.append(EventContract.build(
					seq, phase, "hazard.unstable.fallback", mover_id,
					entered_cell, entered_cell, "none", 0,
					_descriptor(hazard, "fallback_damage"), fallback_damage, ""
				))
				seq += 1

	# --- Binding: stop at the cell the actor now occupies, once per activation ---
	var stop: bool = false
	var stop_reason: String = ""
	if not is_forced_entry and not bool(triggered["binding"]):
		var binding_matches: Array = _hazards_at(hazards, final_cell, "binding")
		if not binding_matches.is_empty():
			var bcfg: Dictionary = config.get("binding", {}) as Dictionary
			if bool(bcfg.get("stops_movement", true)):
				triggered["binding"] = true
				stop = true
				stop_reason = "binding_stop"
				var bhazard: Dictionary = binding_matches[0] as Dictionary
				events.append(EventContract.build(
					seq, phase, "hazard.binding.stop", mover_id,
					final_cell, final_cell, "none", 0,
					_descriptor(bhazard, "binding_stop"), 0, "binding_stop"
				))
				seq += 1

	return {
		"displaced": displaced,
		"displaced_to": final_cell,
		"stop": stop,
		"stop_reason": stop_reason,
		"damage": damage,
		"events": events,
		"next_seq": seq,
		"hazard_ctx": ledger,
	}


## Resolve Burning at end of activation: end_activation_damage applied at most once
## per activation, based on the cell the actor finally occupies. Returns:
##   {
##     "damage":     int,          # Burning end_activation_damage (0 if none / already triggered)
##     "events":     Array,        # ordered MovementEvent dicts
##     "next_seq":   int,
##     "hazard_ctx": Dictionary,   # updated ledger (deep copy)
##   }
static func resolve_end_activation(
	final_cell: Dictionary,
	hazards: Array,
	context: Dictionary,
	hazard_ctx: Dictionary
) -> Dictionary:
	var ledger: Dictionary = _ledger_copy(hazard_ctx)
	var triggered: Dictionary = ledger["triggered"] as Dictionary
	var events: Array = []
	var seq: int = int(context.get("seq", 0))
	var mover_id: String = str(context.get("mover_id", "hazard"))
	var phase: String = str(context.get("phase", "end_activation"))
	var config: Dictionary = context.get("config", {}) as Dictionary
	var damage: int = 0

	if not bool(triggered["burning"]):
		var matches: Array = _hazards_at(hazards, final_cell, "burning")
		if not matches.is_empty():
			triggered["burning"] = true
			var bcfg: Dictionary = config.get("burning", {}) as Dictionary
			damage = int(bcfg.get("end_activation_damage", 0))
			var hazard: Dictionary = matches[0] as Dictionary
			events.append(EventContract.build(
				seq, phase, "hazard.burning.end", mover_id,
				final_cell, final_cell, "none", 0,
				_descriptor(hazard, "burning"), damage, ""
			))
			seq += 1

	return {
		"damage": damage,
		"events": events,
		"next_seq": seq,
		"hazard_ctx": ledger,
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

static func _sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


## All hazard facts of `hazard_type` whose position equals `cell`, sorted by id for
## caller-order-independent determinism.
static func _hazards_at(hazards: Array, cell: Dictionary, hazard_type: String) -> Array:
	var matches: Array = []
	var cell_col: int = int(cell.get("col", 0))
	var cell_row: int = int(cell.get("row", 0))
	for hazard_value: Variant in hazards:
		if not hazard_value is Dictionary:
			continue
		var hazard: Dictionary = hazard_value as Dictionary
		if str(hazard.get("hazard_type", "")) != hazard_type:
			continue
		var pos: Dictionary = hazard.get("position", {}) as Dictionary
		if int(pos.get("col", cell_col - 9999)) == cell_col and int(pos.get("row", cell_row - 9999)) == cell_row:
			matches.append(hazard)
	matches.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", ""))
	)
	return matches


## Compact, JSON-safe hazard descriptor carried on a MovementEvent's `hazard` field.
static func _descriptor(hazard: Dictionary, effect: String) -> Dictionary:
	return {
		"hazard_id": str(hazard.get("id", "")),
		"type": str(hazard.get("hazard_type", "")),
		"position": (hazard.get("position", {}) as Dictionary).duplicate(true),
		"effect": effect,
	}


## Whether `to_cell` is a legal + walkable (diagonal two-solid-corners respected) +
## unoccupied single 8-dir edge from `from_cell`.
static func _cell_available(
	from_cell: Dictionary,
	to_cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary,
	occupied: Dictionary
) -> bool:
	if not StageTerrain.is_legal_edge(from_cell, to_cell, walkable, bounds):
		return false
	var key: String = "%d,%d" % [int(to_cell.get("col", 0)), int(to_cell.get("row", 0))]
	if occupied.has(key):
		return false
	return true


## Resolve the single-cell Unstable displacement landing, or {} when none is possible
## (caller then applies fallback_damage). Direction is outward from the hazard's authored
## center, or the incoming edge when the actor is exactly on the center. Alternatives are
## ranked by outward progress then angular deviation; a genuine (mirror) tie -> {}.
static func _displacement_target(
	entered_cell: Dictionary,
	hazard: Dictionary,
	from_cell: Dictionary,
	walkable: Dictionary,
	bounds: Dictionary,
	occupied: Dictionary
) -> Dictionary:
	var entered_col: int = int(entered_cell.get("col", 0))
	var entered_row: int = int(entered_cell.get("row", 0))
	var center: Dictionary = hazard.get("position", {}) as Dictionary

	# Outward direction from the authored center.
	var dir_col: int = _sign(entered_col - int(center.get("col", entered_col)))
	var dir_row: int = _sign(entered_row - int(center.get("row", entered_row)))
	if dir_col == 0 and dir_row == 0:
		# Exactly on the center (single-cell hazards always are): use the incoming edge.
		if from_cell.is_empty():
			return {}
		dir_col = _sign(entered_col - int(from_cell.get("col", entered_col)))
		dir_row = _sign(entered_row - int(from_cell.get("row", entered_row)))
	if dir_col == 0 and dir_row == 0:
		# No usable outward reference -> ambiguous -> fallback.
		return {}

	# Preferred straight-outward cell.
	var primary: Dictionary = {"col": entered_col + dir_col, "row": entered_row + dir_row}
	if _cell_available(entered_cell, primary, walkable, bounds, occupied):
		return primary

	# Rank alternatives by (outward progress DESC, angular deviation ASC == cos-sim DESC).
	# A genuine tie on both keys is a mirror-image pair -> geometrically ambiguous -> {}.
	var dir_mag: float = sqrt(float(dir_col * dir_col + dir_row * dir_row))
	var candidates: Array = []  # each: {"cell": {...}, "dot": int, "cos": float}
	for delta_col in [-1, 0, 1]:
		for delta_row in [-1, 0, 1]:
			if delta_col == 0 and delta_row == 0:
				continue
			if delta_col == dir_col and delta_row == dir_row:
				continue  # primary already tried and blocked
			var dot: int = delta_col * dir_col + delta_row * dir_row
			if dot <= 0:
				continue  # keep only outward-progressing candidates
			var candidate: Dictionary = {"col": entered_col + delta_col, "row": entered_row + delta_row}
			if not _cell_available(entered_cell, candidate, walkable, bounds, occupied):
				continue
			var mag: float = sqrt(float(delta_col * delta_col + delta_row * delta_row))
			var cos_sim: float = float(dot) / (mag * dir_mag)
			candidates.append({"cell": candidate, "dot": dot, "cos": cos_sim})

	if candidates.is_empty():
		return {}

	var best_dot: int = -999
	var best_cos: float = -2.0
	for entry_value: Variant in candidates:
		var entry: Dictionary = entry_value as Dictionary
		var d: int = int(entry["dot"])
		var c: float = float(entry["cos"])
		if d > best_dot or (d == best_dot and c > best_cos + 0.000000001):
			best_dot = d
			best_cos = c

	var winners: Array = []
	for entry_value: Variant in candidates:
		var entry: Dictionary = entry_value as Dictionary
		if int(entry["dot"]) == best_dot and absf(float(entry["cos"]) - best_cos) <= 0.000000001:
			winners.append((entry["cell"] as Dictionary).duplicate(true))

	if winners.size() == 1:
		return winners[0] as Dictionary
	return {}  # ambiguous mirror pair -> no unbiased choice -> fallback
