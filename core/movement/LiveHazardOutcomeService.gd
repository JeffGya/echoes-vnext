# res://core/movement/LiveHazardOutcomeService.gd
# V2-INFRA-003 Phase 6 Slice 6C (prerequisite): the live mutation choke for a pure
# CombatActivationService result, moved VERBATIM out of
# core/runtime/FlowRuntime.gd::_apply_live_hazard_outcome (which sat at :1579–:1610).
#
# WHY THIS FILE EXISTS. Slice 6C moves the GUIDE_SPIRIT escort/skittish block out of
# _end_round. That block calls this helper four times. The helper is NOT exclusive to
# guide spirits — it also has two live callers on the ordinary per-actor activation path
# (apply_live_activation and the PURSUE quarry step) — so it could neither travel with
# the block nor be duplicated (AGENTS.md #19). Per "a helper used by two or more domains
# has an owner, find it", the owner is here in core/movement/, beside
# CombatActivationService: this is the write half of that service's read-only contract
# ("CombatActivationService only computes event damage and KO/death truth; the caller owns
# actor state writes"). It is deliberately NOT folded into MovementHazardService, whose
# own header guarantees it "never touches actor/combat state" and never logs.
#
# NO SHIM WAS LEFT ON FlowRuntime (AGENTS.md #20). Every call site was rewritten in the
# same change: FlowRuntime ×2 on the ordinary activation path (V2-INFRA-003 Slice 6G moved
# one of those two, apply_live_activation, onto LiveMovementContextService in this same
# directory; the end-of-activation Burning call stayed on FlowRuntime), the four sites inside the
# extracted GUIDE_SPIRIT block, and the seven `runtime._apply_live_hazard_outcome(...)`
# reflection call sites in tests/CombatRoundtripIntegrationTests.gd.
#
# WHAT IT TOUCHES — the complete read/write set:
#   READS   result["events"] (each event's "phase" and "damage"), result["stop_reason"],
#           actor["current_hp"], actor["id"].
#   WRITES  actor["current_hp"]; on a lethal total, erases actor["is_ko"] and sets
#           actor["is_dead"] = true and actor["death_round"] = t. One logger line
#           (combat.hazard_resolved), emitted only when damage > 0.
#   NOT TOUCHED  save data, flow_ctx, combat_state, ectx, any other actor.
#
# DETERMINISM. No RNG, no OS time. `t` is injected. Behaviour is byte-identical to the
# private it replaces, including the early return that suppresses the log line when the
# selected phase carried no damage, and including `death_round = t` (the sim tick, not the
# round counter — pre-existing and preserved; see the defect note in the slice writeup).

class_name LiveHazardOutcomeService
extends RefCounted


## Applies one phase of an activation result's hazard damage to a live actor dict.
## `end_activation_only` selects WHICH events count: false = movement/forced damage
## (resolved before the primary action), true = end-of-activation Burning (resolved
## after it). Callers invoke it twice, once per phase, in that order.
static func apply(
	actor: Dictionary,
	result: Dictionary,
	t: int,
	logger: StructuredLogger,
	end_activation_only: bool = false
) -> void:
	var damage: int = 0
	for event_value: Variant in result.get("events", []) as Array:
		if event_value is Dictionary:
			var event: Dictionary = event_value as Dictionary
			var is_end_activation: bool = str(event.get("phase", "")) == "end_activation"
			if is_end_activation == end_activation_only:
				damage += int(event.get("damage", 0))
	if damage <= 0:
		return
	var hp_before: int = int(actor.get("current_hp", 0))
	var hp_after: int = maxi(0, hp_before - damage)
	actor["current_hp"] = hp_after
	var stop_reason: String = str(result.get("stop_reason", ""))
	if hp_after <= 0:
		# Live combat owns only the established ActorSchema lifecycle fields.
		# Pure activation tests may still exercise `ko`, but live callers request death.
		actor.erase("is_ko")
		actor["is_dead"] = true
		actor["death_round"] = t
	logger.info(t, "combat.hazard_resolved", "Movement hazard applied", {
		"actor_id": str(actor.get("id", "")),
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"downed": hp_after <= 0,
		"stop_reason": stop_reason,
	})
