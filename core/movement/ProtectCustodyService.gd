# res://core/movement/ProtectCustodyService.gd
# V2-COMBAT-002 Slice 4 (Unit C, DORMANT): PROTECT totem carry / custody adapter.
#
# Pure, deterministic, stateless, all-static. No RNG, no OS time, no ConfigService
# reads, no mutation of inputs, no actor/combat_state writes, no damage applied to
# any actor, no logging. NOT wired into live combat/flow — only tests consume it.
# This is the dormant replacement for FlowRuntime._end_round's inline PROTECT theft
# block (proximity-roll custody); live cutover is slice 6.
#
# ---------------------------------------------------------------------------
# BOUNDARY (important):
#   This service owns WHO HOLDS THE TOTEM and WHERE THE TOTEM IS. It has NO
#   objective authority: it never decides the PROTECT win/loss, never advances or
#   resets protect_counter, never scores objective progress, and never emits a
#   guard-radius verdict. Every entry point returns structured FACTS for the
#   (future, slice-6) objective layer to consume. `custody_report` deliberately
#   carries "objective_authority": false to make that contract self-describing.
#
# ---------------------------------------------------------------------------
# CUSTODY STATE (immutable value; NEVER mutated in place — every entry point
# returns an updated COPY under "custody_state"):
#
#   {
#     "totem_id":        String,      # protected totem/entity actor id
#     "totem_cell":      {col,row},   # authoritative totem position
#     "carrier_id":      String,      # "" when the totem is on the ground
#     "carrier_faction": String,      # "" when uncarried; else "echo" | "enemy"
#   }
#
#   INVARIANT: while carried, totem_cell IS the carrier's current cell. That is
#   what makes the frozen drop/recovery rule (rule 6) a pure read of totem_cell.
#
# ---------------------------------------------------------------------------
# FROZEN CUSTODY RULES (Jeff-approved) and where each lives:
#   1. Pickup/recovery IS the activation's single primary action — the actor moves,
#      then picks up INSTEAD of attacking. It is not an entry-effect and costs no
#      extra movement capacity (action economy unchanged: capacity = movement only,
#      one primary action after movement).      -> resolve_pickup / pickup_action_plan
#   2. The totem FOLLOWS the carrier after EVERY step, voluntary AND forced. The
#      ordered custody contract is MovementResult.actual_traversed_cells, which
#      already interleaves voluntary steps and forced hazard displacements in
#      chronological order — so the totem is never left behind mid-path.
#                                               -> track_carrier_movement
#   3. Carrier burden: -1 movement capacity while carrying, applied PER ACTIVATION
#      to a MovementProfile copy, never persisted to the actor.
#                                               -> apply_carrier_burden
#   4. Theft = an enemy successfully ATTACKING the carrier transfers custody. Merely
#      entering the carrier's cell never transfers.
#                                               -> resolve_theft_on_attack / resolve_cell_entry
#   5. The enemy carrier is move/action-restricted and takes double damage.
#                                               -> enemy_carrier_restrictions (+ the
#                                                  capacity cap inside apply_carrier_burden)
#   6. Drop/recovery cell = the carrier's CURRENT cell.
#                                               -> drop_cell / resolve_drop
#
# ---------------------------------------------------------------------------
# CONFIG (INJECTED by the caller — core never reads ConfigService, for determinism).
# Shape: data.combat.objective_modes.protect from balance.json.
#   REUSED (pre-existing keys, semantics unchanged):
#     theft_chance         float : probability an enemy attack on the carrier steals.
#     double_damage_mult   float : damage multiplier an enemy carrier suffers.
#   ADDED by this unit (additive only):
#     carry_capacity_penalty            int  : capacity subtracted while carrying (1).
#     pickup_range                      int  : max Chebyshev reach from the mover's FINAL
#                                              cell to the totem for a pickup (1 = same or
#                                              adjacent cell; a structure totem occupies its
#                                              own cell, so same-cell is usually impossible).
#     enemy_carrier_capacity_cap        int  : capacity ceiling for a restricted enemy carrier.
#     enemy_carrier_movement_restricted bool : whether that cap applies.
#     enemy_carrier_action_restricted   bool : whether the enemy carrier's primary action is denied.
#
# ---------------------------------------------------------------------------
# NO RNG: theft is probability-gated, but the roll is INJECTED by the caller
# (attack.roll). Slice-6 wiring supplies it from CampaignSeed.get_rng, keeping the
# seed-draw order owned by FlowRuntime exactly as it is today.
#
# ---------------------------------------------------------------------------
# MOVEMENT PROFILE FLOOR (MovementProfile.validate invariants):
#   * actor_kind "structure" <-> capacity 0 (a structure can never be a carrier).
#   * a non-structure may NOT have capacity 0.
#   * capacity 1 REQUIRES a non-empty authored_override whose capacity matches.
#   Therefore the burden clamps at MIN_CARRIER_CAPACITY (1) and, whenever the
#   burdened capacity lands on 1, an authored_override is stamped (reusing the base
#   profile's own authored source when it already had one, else "protect_carrier_burden").
#   A base profile already at capacity 1 absorbs the burden: applied 0, floored true.

class_name ProtectCustodyService
extends RefCounted

const ProfileContract = preload("res://core/movement/contracts/MovementProfile.gd")
const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")

## The pickup/recovery primary action type. Valid MovementActionPlan semantic token.
const ACTION_PICKUP: String = "protect.totem_pickup"

## Profile source label for a burden-stamped authored override / source term.
const SOURCE_BURDEN: String = "protect_carrier_burden"

## MovementProfile floor for a carrier: a non-structure mover may never reach 0.
const MIN_CARRIER_CAPACITY: int = 1

const FACTION_ENEMY: String = "enemy"

## Stop reasons that mean the mover went down during its activation.
const _DOWNED_STOPS: Array = ["ko", "death"]


# ---------------------------------------------------------------------------
# CUSTODY STATE
# ---------------------------------------------------------------------------

## Canonical custody state. Uncarried by default (the totem sits on the ground).
static func new_state(
	totem_id: String,
	totem_cell: Dictionary,
	carrier_id: String = "",
	carrier_faction: String = ""
) -> Dictionary:
	return {
		"totem_id": totem_id,
		"totem_cell": _cell_of(totem_cell),
		"carrier_id": carrier_id,
		"carrier_faction": carrier_faction if not carrier_id.is_empty() else "",
	}


## Normalized deep copy — the only way this service ever "changes" a state.
static func copy_state(custody_state: Dictionary) -> Dictionary:
	return new_state(
		str(custody_state.get("totem_id", "")),
		custody_state.get("totem_cell", {}) as Dictionary,
		str(custody_state.get("carrier_id", "")),
		str(custody_state.get("carrier_faction", ""))
	)


static func is_carried(custody_state: Dictionary) -> bool:
	return not str(custody_state.get("carrier_id", "")).is_empty()


static func is_enemy_carried(custody_state: Dictionary) -> bool:
	return is_carried(custody_state) \
		and str(custody_state.get("carrier_faction", "")) == FACTION_ENEMY


# ---------------------------------------------------------------------------
# RULE 3 — CARRIER BURDEN (per-activation, never persisted)
# ---------------------------------------------------------------------------

## Apply the carry burden to `base_profile` for `mover_id`. Returns:
##   {
##     "profile":            Dictionary,  # validated MovementProfile (a COPY)
##     "is_carrier":         bool,
##     "base_capacity":      int,
##     "effective_capacity": int,
##     "applied":            int,   # capacity actually removed (0 when floored/absorbed)
##     "floored":            bool,  # the clamp at MIN_CARRIER_CAPACITY bit
##     "enemy_capped":       bool,  # the enemy-carrier capacity cap bit
##     "reason":             String,
##   }
## A non-carrier (or a structure) gets its profile back untouched.
static func apply_carrier_burden(
	base_profile: Dictionary,
	custody_state: Dictionary,
	mover_id: String,
	protect_cfg: Dictionary
) -> Dictionary:
	var profile: Dictionary = _profile_copy(base_profile)
	var base_capacity: int = int(profile.get("capacity", 0))
	var is_carrier: bool = is_carried(custody_state) \
		and str(custody_state.get("carrier_id", "")) == mover_id

	if not is_carrier:
		return _burden_report(profile, false, base_capacity, base_capacity, false, false, "not_carrier")

	# A structure can never be a carrier: capacity 0 is intrinsic and inviolable.
	if str(profile.get("actor_kind", "")) == "structure" or base_capacity <= 0:
		return _burden_report(profile, true, base_capacity, base_capacity, false, false, "structure_never_carries")

	var penalty: int = int(protect_cfg.get("carry_capacity_penalty", 1))
	var effective: int = base_capacity - penalty

	# Rule 5: a restricted ENEMY carrier is additionally capped.
	var enemy_capped: bool = false
	if str(custody_state.get("carrier_faction", "")) == FACTION_ENEMY \
			and bool(protect_cfg.get("enemy_carrier_movement_restricted", true)):
		var cap: int = int(protect_cfg.get("enemy_carrier_capacity_cap", MIN_CARRIER_CAPACITY))
		if cap < effective:
			effective = cap
			enemy_capped = true

	# MovementProfile floor: a non-structure mover may never fall to 0.
	var floored: bool = false
	if effective < MIN_CARRIER_CAPACITY:
		effective = MIN_CARRIER_CAPACITY
		floored = true

	if effective == base_capacity:
		# Nothing removable (base already at the floor) — the burden is absorbed.
		return _burden_report(profile, true, base_capacity, effective, true, enemy_capped, "burden_absorbed_at_floor")

	var applied: int = base_capacity - effective
	var source_terms: Array = (profile.get("source_terms", []) as Array).duplicate(true)
	source_terms.append({"source": SOURCE_BURDEN, "capacity": -applied})

	# Reconcile authored_override: capacity 1 REQUIRES one, and any present override
	# must carry a capacity equal to the profile capacity.
	var override_in: Dictionary = profile.get("authored_override", {}) as Dictionary
	var authored_override: Dictionary = {}
	if not override_in.is_empty():
		authored_override = {"source": str(override_in.get("source", SOURCE_BURDEN)), "capacity": effective}
	elif effective == MIN_CARRIER_CAPACITY:
		authored_override = {"source": SOURCE_BURDEN, "capacity": effective}

	var burdened: Dictionary = ProfileContract.build(
		effective,
		source_terms,
		bool(profile.get("controlling_state", false)),
		str(profile.get("actor_kind", "echo")),
		authored_override
	)
	return _burden_report(burdened, true, base_capacity, effective, floored, enemy_capped, "burden_applied")


# ---------------------------------------------------------------------------
# RULE 1 — PICKUP / RECOVERY AS THE ACTIVATION'S PRIMARY ACTION
# ---------------------------------------------------------------------------

## The pickup/recovery MovementActionPlan. Declaring it as an activation's
## planned_action is exactly what makes the actor pick up INSTEAD of attacking.
static func pickup_action_plan(totem_id: String, payload: Dictionary = {}) -> Dictionary:
	return ActionPlan.build(ACTION_PICKUP, totem_id, payload)


## action_ctx fragment so CombatActivationService can revalidate the pickup at the
## mover's FINAL cell: the totem's position plus the configured pickup reach.
static func pickup_action_ctx(custody_state: Dictionary, protect_cfg: Dictionary) -> Dictionary:
	return {
		"positions": {str(custody_state.get("totem_id", "")): _cell_of(custody_state.get("totem_cell", {}) as Dictionary)},
		"ranges": {ACTION_PICKUP: int(protect_cfg.get("pickup_range", 1))},
	}


## Did this activation declare the pickup as its primary action (and therefore
## forgo attacking this activation)? Reads the RESOLVED action — a pickup that was
## invalidated at the final cell resolves to a fallback and no longer precludes.
static func precludes_attack(result: Dictionary) -> bool:
	return str((result.get("resolved_action", {}) as Dictionary).get("type", "")) == ACTION_PICKUP


## Resolve a pickup/recovery from a completed activation MovementResult. Returns:
##   {
##     "custody_state":   Dictionary,  # updated COPY
##     "picked_up":       bool,
##     "action_consumed": bool,  # the pickup WAS this activation's primary action
##     "attack_precluded":bool,  # -> the mover cannot also attack this activation
##     "capacity_cost":   int,   # FROZEN 0: pickup costs no movement capacity
##     "carrier_id":      String,
##     "reason":          String,
##   }
## Reasons: picked_up | not_pickup_action | wrong_totem | already_carried |
##          mover_downed | out_of_range
static func resolve_pickup(
	custody_state: Dictionary,
	result: Dictionary,
	protect_cfg: Dictionary,
	mover_faction: String = "echo"
) -> Dictionary:
	var state: Dictionary = copy_state(custody_state)
	var resolved: Dictionary = result.get("resolved_action", {}) as Dictionary
	var is_pickup: bool = str(resolved.get("type", "")) == ACTION_PICKUP

	if not is_pickup:
		return _pickup_report(state, false, false, false, "not_pickup_action")
	if str(resolved.get("target_id", "")) != str(state.get("totem_id", "")):
		return _pickup_report(state, false, true, true, "wrong_totem")
	# The action was declared and consumed the activation's single primary slot even
	# when the pickup itself fails — the mover still did not attack.
	if _DOWNED_STOPS.has(str(result.get("stop_reason", ""))):
		return _pickup_report(state, false, true, true, "mover_downed")
	if is_carried(state):
		return _pickup_report(state, false, true, true, "already_carried")

	var final_cell: Dictionary = _cell_of(result.get("final_destination", {}) as Dictionary)
	var reach: int = int(protect_cfg.get("pickup_range", 1))
	if _chebyshev(final_cell, state["totem_cell"] as Dictionary) > reach:
		return _pickup_report(state, false, true, true, "out_of_range")

	# Custody transfers to the mover, and the totem moves onto the carrier's cell —
	# restoring the "carried totem IS at the carrier's cell" invariant.
	var picked: Dictionary = new_state(
		str(state.get("totem_id", "")),
		final_cell,
		str(result.get("mover_id", "")),
		mover_faction
	)
	return _pickup_report(picked, true, true, true, "picked_up")


# ---------------------------------------------------------------------------
# RULE 2 — THE TOTEM FOLLOWS THE CARRIER AFTER EVERY STEP
# ---------------------------------------------------------------------------

## Track the totem along a carrier's completed activation. MovementResult's
## `actual_traversed_cells` is the ORDERED custody contract: it already interleaves
## voluntary steps and forced hazard displacements chronologically, so replaying it
## cell-by-cell means the totem is never left behind mid-path.
## Returns:
##   {
##     "custody_state":  Dictionary,  # updated COPY (totem at the carrier's final cell)
##     "followed":       bool,
##     "totem_path":     Array,       # ordered cells the totem occupied, mirroring the carrier
##     "steps_followed": int,
##     "forced_steps":   int,         # how many of those were FORCED (hazard displacement)
##     "carrier_downed": bool,        # a fact for the caller; the drop is a separate decision
##     "reason":         String,
##   }
## Reasons: followed | not_carried | not_the_carrier
static func track_carrier_movement(custody_state: Dictionary, result: Dictionary) -> Dictionary:
	var state: Dictionary = copy_state(custody_state)
	if not is_carried(state):
		return _track_report(state, false, [], 0, false, "not_carried")
	if str(result.get("mover_id", "")) != str(state.get("carrier_id", "")):
		return _track_report(state, false, [], 0, false, "not_the_carrier")

	var totem_path: Array = []
	var carried_cell: Dictionary = state["totem_cell"] as Dictionary
	for cell_value: Variant in result.get("actual_traversed_cells", []) as Array:
		carried_cell = _cell_of(cell_value as Dictionary)
		totem_path.append(carried_cell.duplicate(true))

	# Voluntary or forced, the totem ends exactly where the carrier ended.
	var moved: Dictionary = new_state(
		str(state.get("totem_id", "")),
		carried_cell,
		str(state.get("carrier_id", "")),
		str(state.get("carrier_faction", ""))
	)
	var downed: bool = _DOWNED_STOPS.has(str(result.get("stop_reason", "")))
	return _track_report(
		moved, true, totem_path, int(result.get("forced_steps", 0)), downed, "followed"
	)


# ---------------------------------------------------------------------------
# RULE 4 — THEFT IS ATTACK-TRIGGERED, NEVER ENTRY-TRIGGERED
# ---------------------------------------------------------------------------

## Resolve a custody transfer from a resolved ATTACK against the carrier.
##   attack = {
##     "attacker_id":      String,
##     "attacker_faction": String,      # "enemy" | "echo"
##     "attacker_cell":    {col,row},   # becomes the totem cell on transfer
##     "defender_id":      String,      # must be the current carrier
##     "hit":              bool,        # caller-resolved: did the attack land
##     "roll":             float,       # caller-supplied deterministic roll in [0,1)
##   }
## Steals iff: carried AND defender is the carrier AND the attack HIT AND the
## attacker is of a different faction AND roll < theft_chance (the pre-existing
## `theft_chance` semantics, unchanged). NO RNG here — the roll is injected.
## Returns:
##   { "custody_state", "stolen": bool, "theft_chance": float, "roll": float, "reason": String }
## Reasons: stolen | not_carried | defender_not_carrier | attack_missed |
##          same_faction | roll_failed
static func resolve_theft_on_attack(
	custody_state: Dictionary,
	attack: Dictionary,
	protect_cfg: Dictionary
) -> Dictionary:
	var state: Dictionary = copy_state(custody_state)
	var chance: float = float(protect_cfg.get("theft_chance", 0.5))
	var roll: float = float(attack.get("roll", 1.0))

	if not is_carried(state):
		return _theft_report(state, false, chance, roll, "not_carried")
	if str(attack.get("defender_id", "")) != str(state.get("carrier_id", "")):
		return _theft_report(state, false, chance, roll, "defender_not_carrier")
	if not bool(attack.get("hit", false)):
		return _theft_report(state, false, chance, roll, "attack_missed")
	var attacker_faction: String = str(attack.get("attacker_faction", ""))
	if attacker_faction == str(state.get("carrier_faction", "")):
		return _theft_report(state, false, chance, roll, "same_faction")
	if roll >= chance:
		return _theft_report(state, false, chance, roll, "roll_failed")

	var stolen: Dictionary = new_state(
		str(state.get("totem_id", "")),
		_cell_of(attack.get("attacker_cell", {}) as Dictionary),
		str(attack.get("attacker_id", "")),
		attacker_faction
	)
	return _theft_report(stolen, true, chance, roll, "stolen")


## Entering the carrier's cell NEVER transfers custody (frozen rule 4). Present as
## an explicit, tested no-op so the slice-6 cutover cannot reintroduce the old
## proximity/entry-based theft by accident.
## Returns: { "custody_state" (unchanged COPY), "transferred": false, "reason" }
static func resolve_cell_entry(custody_state: Dictionary, _entry: Dictionary) -> Dictionary:
	return {
		"custody_state": copy_state(custody_state),
		"transferred": false,
		"reason": "cell_entry_never_transfers",
	}


# ---------------------------------------------------------------------------
# RULE 6 — DROP / RECOVERY CELL
# ---------------------------------------------------------------------------

## The drop/recovery cell IS the carrier's current cell. Because the totem follows
## the carrier after every step, that is exactly totem_cell.
static func drop_cell(custody_state: Dictionary) -> Dictionary:
	return _cell_of(custody_state.get("totem_cell", {}) as Dictionary)


## Release custody. The totem stays put — it lands on the carrier's current cell —
## and becomes recoverable by the pickup action.
## Returns: { "custody_state", "dropped": bool, "drop_cell": {col,row}, "reason" }
static func resolve_drop(custody_state: Dictionary, reason: String = "carrier_down") -> Dictionary:
	var state: Dictionary = copy_state(custody_state)
	var cell: Dictionary = drop_cell(state)
	if not is_carried(state):
		return {"custody_state": state, "dropped": false, "drop_cell": cell, "reason": "not_carried"}
	return {
		"custody_state": new_state(str(state.get("totem_id", "")), cell, "", ""),
		"dropped": true,
		"drop_cell": cell,
		"reason": reason,
	}


# ---------------------------------------------------------------------------
# RULE 5 — ENEMY CARRIER RESTRICTIONS + DOUBLE DAMAGE
# ---------------------------------------------------------------------------

## Restriction facts for the current carrier. Reported, never applied: no actor is
## written to and no damage is dealt here.
## Returns:
##   {
##     "is_enemy_carrier":    bool,
##     "movement_restricted": bool,
##     "action_restricted":   bool,
##     "capacity_cap":        int,    # -1 when no cap applies
##     "takes_double_damage": bool,
##     "damage_multiplier":   float,  # double_damage_mult for an enemy carrier, else 1.0
##   }
static func enemy_carrier_restrictions(custody_state: Dictionary, protect_cfg: Dictionary) -> Dictionary:
	var enemy_carrier: bool = is_enemy_carried(custody_state)
	if not enemy_carrier:
		return {
			"is_enemy_carrier": false,
			"movement_restricted": false,
			"action_restricted": false,
			"capacity_cap": -1,
			"takes_double_damage": false,
			"damage_multiplier": 1.0,
		}
	var movement_restricted: bool = bool(protect_cfg.get("enemy_carrier_movement_restricted", true))
	return {
		"is_enemy_carrier": true,
		"movement_restricted": movement_restricted,
		"action_restricted": bool(protect_cfg.get("enemy_carrier_action_restricted", true)),
		"capacity_cap": int(protect_cfg.get("enemy_carrier_capacity_cap", MIN_CARRIER_CAPACITY)) if movement_restricted else -1,
		"takes_double_damage": true,
		"damage_multiplier": float(protect_cfg.get("double_damage_mult", 2.0)),
	}


# ---------------------------------------------------------------------------
# REPORT FOR THE OBJECTIVE LAYER (facts only — no win/loss, no counter)
# ---------------------------------------------------------------------------

## Everything the slice-6 objective layer needs to score PROTECT, and nothing that
## scores it. "objective_authority": false is a standing declaration that no
## protect_counter / win / loss decision is made anywhere in this service.
static func custody_report(custody_state: Dictionary, protect_cfg: Dictionary) -> Dictionary:
	var state: Dictionary = copy_state(custody_state)
	return {
		"custody_state": state,
		"totem_id": str(state.get("totem_id", "")),
		"totem_cell": (state["totem_cell"] as Dictionary).duplicate(true),
		"carried": is_carried(state),
		"carrier_id": str(state.get("carrier_id", "")),
		"carrier_faction": str(state.get("carrier_faction", "")),
		"restrictions": enemy_carrier_restrictions(state, protect_cfg),
		"objective_authority": false,
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

static func _burden_report(
	profile: Dictionary,
	is_carrier: bool,
	base_capacity: int,
	effective_capacity: int,
	floored: bool,
	enemy_capped: bool,
	reason: String
) -> Dictionary:
	return {
		"profile": profile,
		"is_carrier": is_carrier,
		"base_capacity": base_capacity,
		"effective_capacity": effective_capacity,
		"applied": base_capacity - effective_capacity,
		"floored": floored,
		"enemy_capped": enemy_capped,
		"reason": reason,
	}


static func _pickup_report(
	state: Dictionary,
	picked_up: bool,
	action_consumed: bool,
	attack_precluded: bool,
	reason: String
) -> Dictionary:
	return {
		"custody_state": state,
		"picked_up": picked_up,
		"action_consumed": action_consumed,
		"attack_precluded": attack_precluded,
		"capacity_cost": 0,
		"carrier_id": str(state.get("carrier_id", "")),
		"reason": reason,
	}


static func _track_report(
	state: Dictionary,
	followed: bool,
	totem_path: Array,
	forced_steps: int,
	carrier_downed: bool,
	reason: String
) -> Dictionary:
	return {
		"custody_state": state,
		"followed": followed,
		"totem_path": totem_path,
		"steps_followed": totem_path.size(),
		"forced_steps": forced_steps,
		"carrier_downed": carrier_downed,
		"reason": reason,
	}


static func _theft_report(
	state: Dictionary,
	stolen: bool,
	theft_chance: float,
	roll: float,
	reason: String
) -> Dictionary:
	return {
		"custody_state": state,
		"stolen": stolen,
		"theft_chance": theft_chance,
		"roll": roll,
		"reason": reason,
	}


## Deep, normalized MovementProfile copy — never an alias of the caller's dict.
static func _profile_copy(profile: Dictionary) -> Dictionary:
	return ProfileContract.build(
		int(profile.get("capacity", 0)),
		profile.get("source_terms", []) as Array,
		bool(profile.get("controlling_state", false)),
		str(profile.get("actor_kind", "echo")),
		profile.get("authored_override", {}) as Dictionary
	)


static func _cell_of(cell: Dictionary) -> Dictionary:
	return {"col": int(cell.get("col", 0)), "row": int(cell.get("row", 0))}


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(
		absi(int(a.get("col", 0)) - int(b.get("col", 0))),
		absi(int(a.get("row", 0)) - int(b.get("row", 0)))
	)
