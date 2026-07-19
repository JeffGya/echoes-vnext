# res://core/movement/CombatActivationService.gd
# V2-COMBAT-002 Slice 3 (DORMANT): atomic movement + action activation coordinator.
#
# Pure, deterministic, stateless. No RNG, no OS time, no mutation of inputs, no
# actor/combat_state writes, no damage applied to OTHER actors, no logging. NOT
# wired into live combat/flow — only tests (and slice-6 wiring later) consume it.
# It coordinates the already-built movement services into ONE authoritative,
# VALIDATED MovementResult:
#
#   MovementExecutor.execute (movement phase, Unstable + Binding during movement)
#     -> mover KO/death truth from movement hazard damage (mover's own hp only)
#     -> revalidate the planned MovementActionPlan at the FINAL cell
#     -> purpose-restricted declared fallback if the primary is no longer valid
#     -> record resolved_action (DECLARED — never executed; no target damage)
#     -> MovementHazardService.resolve_end_activation (Burning, once per activation)
#     -> mover KO/death truth after Burning (computed, not applied)
#     -> assemble + return a MovementResult that passes MovementResult.validate.
#
# ---------------------------------------------------------------------------
# ENTRY (FROZEN):
#   activate(context, intent, profile, hazard_ctx, action_ctx := {}) -> Dictionary
#     context    : MovementExecutor context dict (origin, bounds,
#                  authoritative_walkable, occupancy, perceived_actors,
#                  relationships, terrain_costs, known_hazards, ...).
#     intent     : MovementIntent dict (mover_id, activation_id, goal_id,
#                  option_id, path, commitment, planned_action, fallback, ...).
#     profile    : MovementProfile dict (profile.capacity is the capacity wall).
#     hazard_ctx : per-activation hazard ledger seeded with the injected config,
#                  exactly as the executor expects:
#                  { "triggered": {unstable,binding,burning: bool}, "config": <hazards cfg> }.
#     action_ctx : OPTIONAL caller-owned coordination channel (all keys optional):
#        "purpose"            String  : goal purpose; drives fallback restriction +
#                                       becomes MovementResult.purpose. Default "advance".
#        "goal_id"/"option_id" String : correlation overrides (else taken from intent).
#        "positions"          Dict    : target_id -> {col,row}. Used to revalidate an
#                                       action whose target_id is non-empty at the final cell.
#        "ranges"             Dict     : action_type -> max Chebyshev reach to the target.
#        "default_range"      int      : reach for action types absent from "ranges" (default 1).
#        "objective_progress" float    : passthrough MovementResult.objective_progress
#                                        (else context.objective_pressure.objective_progress, else 0.0).
#        "mover_hp"           int      : mover's CURRENT hp. When present, KO/death is
#                                        computed from cumulative hazard damage. When absent,
#                                        the mover is treated as never downed.
#        "mover_ko_only"      bool      : when the mover would be downed (remaining hp <= 0),
#                                        report "ko" if true, else "death" (default false).
#
# ACTION REVALIDATION RULE (deterministic):
#   * An action with an EMPTY target_id (guard / idle / region-move) is position
#     independent -> valid at any final cell.
#   * An action with a NON-EMPTY target_id is valid iff action_ctx.positions carries
#     that target AND Chebyshev(final_cell, target_pos) <= reach (ranges[type] or
#     default_range). A target absent from positions -> cannot confirm -> invalid.
#
# PURPOSE-RESTRICTED FALLBACK (design choice — orchestrator to ratify):
#   The declared fallback is applied ONLY when its type is listed as permitted for
#   the goal purpose (see _PURPOSE_FALLBACK_ALLOW), mirroring MovementGoal's
#   plan-for-purpose intent so a mover cannot silently change purpose (e.g. an
#   advancing mover cannot fall back to a melee_attack). A permitted fallback must
#   ALSO be valid at the final cell. Otherwise resolved_action is {} and stop_reason
#   becomes "action_invalid_no_fallback".
#
# KO/DEATH TRUTH (computed, never applied):
#   Cumulative hazard damage is summed from the mover's own MovementEvent.damage
#   (Unstable fallback during movement; Burning at end). remaining_hp = mover_hp -
#   cumulative. remaining_hp <= 0 -> downed (mirrors ActorStateMachine's hp<=0 rule).
#   Downed reports "death" (base rule: hp<=0 is death), or "ko" when the caller
#   declares mover_ko_only. Downing DURING movement skips the action AND Burning.

class_name CombatActivationService
extends RefCounted

const MovementExecutor = preload("res://core/movement/MovementExecutor.gd")
const HazardService = preload("res://core/movement/MovementHazardService.gd")
const EventContract = preload("res://core/movement/contracts/MovementEvent.gd")
const ResultContract = preload("res://core/movement/contracts/MovementResult.gd")

const _ACTIVATION_PHASE: String = "activation"

## Purpose -> action types permitted as a declared fallback. Mirrors MovementGoal's
## plan-for-purpose vocabulary. Unknown purpose (or "read", whose primary is idle)
## permits NO fallback. Table-driven so it is trivial to tune / ratify.
const _PURPOSE_FALLBACK_ALLOW: Dictionary = {
	"advance": ["actor.move", "actor.guard", "actor.idle"],
	"engage": ["melee_attack", "actor.guard", "actor.idle"],
	"pursue": ["melee_attack", "actor.guard", "actor.idle"],
	"intercept": ["actor.guard", "actor.idle"],
	"hold": ["actor.guard", "actor.idle"],
	"cut_off": ["actor.guard", "actor.idle"],
	"protect": ["protect_ally", "actor.guard", "actor.idle"],
	"escort": ["protect_ally", "actor.guard", "actor.idle"],
	"reposition": ["actor.move", "actor.guard", "actor.idle"],
	"regroup": ["actor.move", "actor.guard", "actor.idle"],
	"withdraw": ["actor.move", "actor.guard", "actor.idle"],
	"read": [],
}


static func activate(
	context: Dictionary,
	intent: Dictionary,
	profile: Dictionary,
	hazard_ctx: Dictionary,
	action_ctx: Dictionary = {}
) -> Dictionary:
	# 1) Movement phase (Unstable + Binding handled inside the executor). Pure.
	var outcome: Dictionary = MovementExecutor.execute(context, intent, profile, hazard_ctx)

	var events: Array = (outcome["events"] as Array).duplicate(true)
	var origin: Dictionary = (outcome["origin"] as Dictionary).duplicate(true)
	var final_cell: Dictionary = (outcome["final_destination"] as Dictionary).duplicate(true)
	var next_seq: int = int(outcome["next_seq"])
	var move_stop: String = str(outcome["stop_reason"])
	var ledger: Dictionary = outcome["hazard_ctx"] as Dictionary
	var hazard_config: Dictionary = ledger.get("config", {}) as Dictionary
	var known_hazards: Array = context.get("known_hazards", []) as Array

	# Correlation fields (action_ctx overrides intent).
	var mover_id: String = str(intent.get("mover_id", context.get("mover_id", "mover")))
	var activation_id: String = str(intent.get("activation_id", context.get("activation_id", "activation")))
	var goal_id: String = str(action_ctx.get("goal_id", intent.get("goal_id", "goal")))
	var option_id: String = str(action_ctx.get("option_id", intent.get("option_id", "option")))
	var purpose: String = str(action_ctx.get("purpose", "advance"))
	if purpose.is_empty():
		purpose = "advance"

	# KO/death configuration (mover's own hp only; never applied to any actor).
	var has_hp: bool = action_ctx.has("mover_hp")
	var mover_hp: int = int(action_ctx.get("mover_hp", 0))
	var ko_only: bool = bool(action_ctx.get("mover_ko_only", false))

	var planned_action: Dictionary = _plan(intent.get("planned_action", {}))
	var declared_fallback: Dictionary = _plan(intent.get("fallback", {}))
	var resolved_action: Dictionary = {}
	var action_failed: bool = false

	# 2) KO/death truth from MOVEMENT damage. If downed mid-move, skip action + Burning.
	var move_damage: int = _sum_damage(events)
	var downed_in_move: bool = has_hp and (mover_hp - move_damage) <= 0

	if not downed_in_move:
		# 3) Revalidate the primary action at the FINAL cell.
		if _action_valid_at(planned_action, final_cell, action_ctx):
			resolved_action = planned_action.duplicate(true)
		# 4) Purpose-restricted declared fallback.
		elif (
			not declared_fallback.is_empty()
			and _fallback_allowed_for_purpose(purpose, str(declared_fallback.get("type", "")))
			and _action_valid_at(declared_fallback, final_cell, action_ctx)
		):
			resolved_action = declared_fallback.duplicate(true)
		else:
			action_failed = true

		# 5) resolved_action is DECLARED only — no execution, no target damage (slice 3).

		# 6) Burning END-of-activation damage, appended AFTER the action, once per activation.
		var burn: Dictionary = HazardService.resolve_end_activation(
			final_cell,
			known_hazards,
			{
				"config": hazard_config,
				"mover_id": mover_id,
				"phase": "end_activation",
				"seq": next_seq,
			},
			ledger
		)
		for event_value: Variant in burn.get("events", []) as Array:
			events.append((event_value as Dictionary).duplicate(true))
		next_seq = int(burn.get("next_seq", next_seq))
		ledger = burn.get("hazard_ctx", ledger) as Dictionary

	# 7) Recompute KO/death truth AFTER Burning (computed, not applied).
	var total_damage: int = _sum_damage(events)
	var downed: bool = has_hp and (mover_hp - total_damage) <= 0

	# 8) Final stop_reason precedence: death/ko > action_invalid_no_fallback > movement stop.
	var final_stop: String = move_stop
	if downed:
		final_stop = "ko" if ko_only else "death"
	elif action_failed:
		final_stop = "action_invalid_no_fallback"

	# Keep the terminal event's stop_reason in agreement with the final stop_reason so
	# MovementResult.validate's event/stop cross-check holds. Both are "none" facts.
	if final_stop != _last_event_stop(events):
		events.append(EventContract.build(
			next_seq, _ACTIVATION_PHASE, "activation.stop", mover_id,
			final_cell, final_cell, "none", 0, {}, 0, final_stop
		))
		next_seq += 1

	var objective_progress: float = float(action_ctx.get(
		"objective_progress",
		(context.get("objective_pressure", {}) as Dictionary).get("objective_progress", 0.0)
	))

	# Reconcile the executor's SORTED-ARRAY hostile_constraints into the Dict shape the
	# final MovementResult carries (matches the planner/option "hostile_control_sources").
	var hostile_constraints: Dictionary = {
		"hostile_control_sources": (outcome["hostile_constraints"] as Array).duplicate(true),
	}

	return ResultContract.build(
		mover_id,
		activation_id,
		goal_id,
		option_id,
		purpose,
		origin,
		final_cell,
		outcome["planned_path"] as Array,
		outcome["actual_traversed_cells"] as Array,
		int(outcome["voluntary_cost"]),
		int(outcome["forced_steps"]),
		int(outcome["remaining_capacity"]),
		final_stop,
		events,
		planned_action,
		resolved_action,
		declared_fallback,
		_project_hazards(events),
		objective_progress,
		hostile_constraints
	)


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

## Normalized action-plan copy: always a Dictionary, never an input alias.
static func _plan(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


## Is `action` still performable from `final_cell`? Empty target -> position
## independent (valid). Non-empty target -> must be known in action_ctx.positions and
## within reach (Chebyshev <= ranges[type] or default_range).
static func _action_valid_at(action: Dictionary, final_cell: Dictionary, action_ctx: Dictionary) -> bool:
	if action.is_empty():
		return false
	var target_id: String = str(action.get("target_id", ""))
	if target_id.is_empty():
		return true
	var positions: Dictionary = action_ctx.get("positions", {}) as Dictionary
	if not positions.has(target_id):
		return false
	var target_pos: Dictionary = positions[target_id] as Dictionary
	var ranges: Dictionary = action_ctx.get("ranges", {}) as Dictionary
	var reach: int = int(ranges.get(str(action.get("type", "")), int(action_ctx.get("default_range", 1))))
	return _chebyshev(final_cell, target_pos) <= reach


## Whether `fallback_type` is a permitted fallback for `purpose` (table-driven).
static func _fallback_allowed_for_purpose(purpose: String, fallback_type: String) -> bool:
	var allowed: Array = _PURPOSE_FALLBACK_ALLOW.get(purpose, []) as Array
	return allowed.has(fallback_type)


## Sum of the mover's own hazard damage across every event (movement steps carry 0).
static func _sum_damage(events: Array) -> int:
	var total: int = 0
	for event_value: Variant in events:
		total += int((event_value as Dictionary).get("damage", 0))
	return total


## The last non-empty stop_reason carried by any event (mirrors MovementResult.validate).
static func _last_event_stop(events: Array) -> String:
	var last: String = ""
	for event_value: Variant in events:
		var reason: String = str((event_value as Dictionary).get("stop_reason", ""))
		if not reason.is_empty():
			last = reason
	return last


## Every non-empty hazard descriptor carried on an event, in order (matches
## MovementResult's hazard projection so the assembled result validates).
static func _project_hazards(events: Array) -> Array:
	var projected: Array = []
	for event_value: Variant in events:
		var hazard: Dictionary = (event_value as Dictionary).get("hazard", {}) as Dictionary
		if not hazard.is_empty():
			projected.append(hazard.duplicate(true))
	return projected


static func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(
		absi(int(a.get("col", 0)) - int(b.get("col", 0))),
		absi(int(a.get("row", 0)) - int(b.get("row", 0)))
	)
