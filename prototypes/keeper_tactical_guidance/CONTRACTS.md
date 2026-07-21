# Keeper Tactical Guidance — Shared Prototype Contracts

**Contract version:** 0.6 (frozen for the automatic-playback clarity iteration)

This document freezes the integration surface for the local prototype. `SPEC.md` remains authoritative. All prototype code stays in this folder and production code never imports it. v0.6 replaces the earlier pause/per-actor-charge contract; those fields and actions must be removed rather than retained as alternate controls.

## Scene flow

`briefing -> preparation -> combat -> review`

- `briefing`: seed/mode selection, generated-board inspection, reroll.
- `preparation`: lock one Directive and assign the four fixture Echoes to distinct deployment slots through one path only: select one row in the single party roster, then select one board slot. Board Echo tokens are display-only during preparation.
- `combat`: automatic-only actor turns at `slow`, `normal`, or `fast` presentation speed; non-pausing ping browse/preview/confirmation; delayed next-round response; objective resolution.
- `review`: result and event report; restart the identical seed or generate the next deterministic seed.

`KeeperTacticalGuidance.tscn` is the explicit entry scene. `PrototypeController.gd` is the only scene-flow coordinator. It owns one `PrototypeSimulation`, invokes the static `TacticalBoardGenerator` API, publishes UI snapshots, and receives UI commands. UI scripts never mutate simulation dictionaries directly.

## IDs and enums

String IDs are stable and lowercase:

- phases: `briefing`, `preparation`, `combat`, `review`
- modes: `recover`, `protect`
- directives: `scout_carefully`, `seek_signs`, `press_the_path`, `hold_the_circle`
- pings: `hold_ground`, `break_through`, `focus_threat`, `regroup`, `secure_objective`
- recipient modes: `echo_specific`, `area_based`, `party_wide`
- responses: `align`, `interpret`, `hesitate`, `object`, `refuse`
- hazards: `burning_ground`, `unstable_ground`, `binding_growth`

Exact ping mapping is immutable:

| ping | recipient mode | cost |
|---|---|---:|
| Hold Ground | `echo_specific` | 2 |
| Break Through | `area_based` | 3 |
| Focus Threat | `party_wide` | 5 |
| Regroup | `area_based` | 3 |
| Secure Objective | `party_wide` | 5 |

A positional subject never changes a ping's recipient mode.

## Simulation state

```gdscript
{
  "seed": int,
  "mode": String,
  "phase": String,
  "tick": int,
  "round": int,
  "directive_id": String,
  "board": Dictionary,              # board-data contract below
  "actors": Array[Dictionary],       # actor fixture contract below
  "initiative_order": Array[String],
  "initiative_index": int,
  "objective": Dictionary,
  "ping_charge": {"current": int, "maximum": 5, "gain_per_completed_round": 1},
  "unresolved_ping": Dictionary,    # empty or confirmed ping-data contract
  "last_turn_result": Dictionary,   # animation contract below; empty before first turn
  "combat_over": bool,
  "result": {"victory": bool, "reason": String},
  "timeline": Array[Dictionary],
  "response_feedback": Array[Dictionary],
  "attention_cues": Array[String],
  "metrics": Dictionary
}
```

Only `PrototypeSimulation` mutates simulation state. Ping Charge starts at 0, caps at 5, and gains exactly +1 after the final living initiative entry and all round-end objective/hold/guard/custody/end-condition work complete. A round yields no additional charge for actor count and at most one charge total. Dead/skipped entries and structures do not generate charge. Ping confirmation commits only at the same atomic boundary used between turns and never pauses playback.

Controller presentation state is separate from deterministic simulation state: `playback_speed_id: slow|normal|fast` and `queued_ping_confirmation: Dictionary`. The controller may buffer an immutable preview while the current `last_turn_result` animates, but it must ask the simulation to rebuild/revalidate and commit before resolving the next actor turn.

## Actor fixture

Fixtures faithfully expose production concepts while remaining local:

```gdscript
{
  "id": String, "name": String,
  "actor_type": String,             # echo | enemy | structure
  "faction": String,                # echo | enemy | structure
  "is_structure": bool, "is_dead": bool,
  "grid_pos": {"col": int, "row": int},
  "current_hp": int,
  "stats": {"max_hp": int, "atk": int, "def": int, "agi": int, "speed": int},
  "speed": int,
  "fear": int, "morale": int,
  "calling_origin": String,
  "standing": int,
  "expression_band": String,        # nascent | forming | grounded | whole
  "traits": Dictionary,
  "vector_scores": Dictionary,
  "bonds": Dictionary,              # other actor id -> signed strength
  "tendency": String,
  "guard_state": bool,
  "movement_remaining": int,
  "last_response": Dictionary,
  "guidance_state": String         # unaffected | pending | listening | resisting | rejecting
}
```

Structures appear in initiative only if explicitly needed for display, never take turns, and never generate charge. Dead actors are skipped and never generate charge. Higher Standing strengthens coherent self-interpretation; it is never an obedience multiplier.

## Board data

```gdscript
{
  "seed": int,
  "mode": String,
  "bounds": {"w": int, "h": int},
  "walkable": Dictionary,           # "col,row" -> true
  "cells": Array[Dictionary],       # {col,row,terrain,landmark?}
  "obstacles": Array[Dictionary],   # {id,kind,label,cells}; filled raised blockers, never icon-only
  "deployment_slots": Array[Dictionary],
  "enemy_slots": Array[Dictionary],
  "enemy_directions": Array[String], # two separated entry directions
  "objective_pos": {"col": int, "row": int},
  "fallback_pos": {"col": int, "row": int},
  "hazards": Array[Dictionary],
  "chokepoints": Array[Dictionary], # {cells,baseline_distance,blocked_distance,impact}
  "routes": Array[Dictionary],      # {id,cells,length,hazard_cost,width,pressure,tradeoff}
  "validation": {
    "valid": bool, "attempt": int, "connected": bool,
    "objective_accessible": bool, "deployment_accessible": bool,
    "chokepoint_valid": bool, "route_diversity_valid": bool,
    "no_unavoidable_lethal_route": bool,
    "fill_ratio": float, "hazards_valid": bool, "feature_valid": bool,
    "diagnostics": Array[String],
    "used_fallback": bool,          # optional; present on bounded fallback
    "candidate_failures": Array[Dictionary] # optional; fallback diagnostics
  }
}
```

`obstacles` is a deterministic visual projection of non-walkable topology and authored landmark blockers; it never changes pathfinding independently of `walkable`. Supported starting `kind` values are `rock`, `vegetation`, `ruin`, and `landmark`. Every non-walkable pocket visible inside/along the playable silhouette must read as occupied volume. Routes and chokepoints are diagnostic/tactical overlays, not obstacles: routes render only as labeled arrow ribbons when the Routes toggle is on; chokepoints render only as bracket/gate markers when the Chokepoints toggle is on. Normal tiles have no decorative interior lines. The UI legend names every visible overlay.

Board generation is deterministic and bounded: generate candidate attempts from distinct namespaces, return the first valid board, and retain diagnostics. Same seed + mode must serialize identically.

## Hazard data and order

```gdscript
{
  "id": String,
  "type": String,
  "cells": Array[Dictionary],
  "center": {"col": int, "row": int},
  "damage": int,
  "label": String,
  "rule": String
}
```

Per actor turn, each hazard triggers at most once. Deterministic order is `unstable_ground` entry push (or fallback damage), `binding_growth` entry stop, then `burning_ground` end-turn damage. Forced movement must be walkable and unoccupied. Hazards affect living Echoes and enemies equally.

`TacticalBoardGenerator.apply_entry_hazards(actor, from_pos, to_pos, board, occupied)` mutates the actor and returns:

```gdscript
{
  "actor_id": String, "from_pos": Dictionary, "entered_pos": Dictionary,
  "final_pos": Dictionary, "movement_stopped": bool, "pushed": bool,
  "damage": int, "events": Array[Dictionary]
}
```

`occupied` is keyed by `"col,row"`, contains living occupants, and excludes the moving actor. `apply_end_turn_hazards(actor, board)` mutates the actor and returns `{actor_id, final_pos, damage, events}`. The simulation may resolve the same rules locally to keep the full actor turn atomic, but its order and semantics must remain equivalent to these helpers.

## Objective data

```gdscript
{
  "mode": String,
  "structure_id": String,
  "position": Dictionary,
  "hold_counter": int, "hold_required": int,
  "protect_counter": int, "protect_required": int,
  "guard_radius": int,
  "carryable": bool, "holder_id": String,
  "totem_stolen": bool, "totem_carrier_id": String,
  "hp": int, "max_hp": int,
  "status": String
}
```

`RECOVER`: the relic is deep on the board; adjacency is Chebyshev 1; consecutive round-end hold advances while any living Echo is adjacent and resets when absent. Reaching `hold_required` wins; all Echoes dead loses.

`PROTECT`: protection advances at round end only while a living Echo is within `guard_radius` and resets when absent. The totem is carryable on a deterministic 60% roll. Preserve holder debuff, enemy theft/recovery, and enemy-carrier double damage. Reaching `protect_required` wins only if the living totem is not stolen; destroyed totem, all Echoes dead, or enemy custody at clock-out loses (`totem_taken`). Both modes retain universal kill-all victory.

## Ping preview and confirmed data

```gdscript
{
  "id": String,
  "label": String,
  "suggestion": String,            # plain-language Keeper intent
  "mechanical_influence": String,  # weighted behavior, not a command guarantee
  "targeting_instruction": String,
  "recipient_mode": String,
  "charge_required": int,
  "subject": Dictionary,            # anchor/lane/rally/enemy/objective
  "footprint": Array[Dictionary],
  "eligible_recipient_ids": Array[String],
  "recipient_ids": Array[String],   # populated only at confirmation; immutable snapshot
  "remaining_recipient_ids": Array[String],
  "confirmed_round": int,
  "activation_round": int,          # confirmed_round + 1
  "expires_after_round": int,       # equals activation_round
  "availability_state": String,     # available | insufficient_charge | blocked_unresolved | invalid_subject | no_eligible_recipients
  "rounds_until_charge": int,
  "expected_duration": String,
  "valid": bool,
  "invalid_reason": String
}
```

The five definitions also ship to UI as `ping_library`, keyed by ping ID, with immutable `label`, `suggestion`, `mechanical_influence`, `targeting_instruction`, `recipient_mode`, and `charge_required`. Locked definitions remain inspectable and spatially previewable; `valid` governs confirmation, not inspection.

Confirm input during an animation is acknowledged by placing the exact preview in `queued_ping_confirmation`. At the next atomic boundary the simulation rebuilds/revalidates the preview against current positions and either commits it or returns the new `availability_state`/`invalid_reason`; the queue then clears. Confirmation consumes all stored charge. Cancellation clears only unconfirmed preview/queue and consumes none. One unresolved ping blocks another even if charge rebuilds.

Confirmation snapshots subject, footprint, and recipients and sets `activation_round = confirmed_round + 1`. Every living recipient becomes `pending`; no response evaluates during `confirmed_round`. On a recipient's first living initiative entry in `activation_round`, response evaluation occurs immediately before intent/action resolution, its guidance state changes, and the response is embedded in `last_turn_result`. The recipient is then removed from `remaining_recipient_ids`. Dead recipients are removed without a response. The ping expires when no living recipients remain or at activation-round end.

## Echo response result

```gdscript
{
  "actor_id": String,
  "ping_id": String,
  "outcome": String,
  "influence": float,               # align 1.0; interpretation/hesitation/object lower; refuse 0
  "primary_reason": String,
  "secondary_reason": String,
  "explanation": String,
  "score": int,                    # optional deterministic debug projection
  "factors": Dictionary            # optional deterministic debug projection
}
```

Every non-align result has a non-empty primary reason and explanation. Inputs are survival/danger/hazard, fear, morale, Calling/expression fit, bonds, Standing, objective pressure, and baseline tendency. Thresholds are deterministic. Unaffected Echoes never receive a response entry.

Guidance-state mapping is exact: no response entry -> `unaffected`; confirmed but not activated -> `pending`; `align|interpret` -> `listening`; `hesitate|object` -> `resisting`; `refuse` -> `rejecting`. Player-facing UI always shows the named outcome as well as this grouped presentation state. It must never infer refusal from absence.

## Turn presentation / animation result

Every completed actor turn stores and publishes one structured result. UI animation uses this contract, not timeline prose:

```gdscript
{
  "tick": int,                      # monotonic presentation key
  "round": int,
  "actor_id": String,
  "action_type": String,            # move | attack | guard | objective | wait
  "from_pos": Dictionary,
  "to_pos": Dictionary,
  "path": Array[Dictionary],        # ordered, includes each traversed destination
  "target_id": String,              # empty when not applicable
  "damage": int,
  "hit": bool,
  "hazard_events": Array[Dictionary],
  "objective_events": Array[Dictionary],
  "follow_up": Array[Dictionary],   # ordered additional attack/counter/forced-move beats
  "ping_response": Dictionary,      # Echo response result or empty
  "guidance_expression": String     # unaffected | follow | interpret | resist | reject
}
```

Each `follow_up` beat uses `{type, source_id, target_id, from_pos, to_pos, damage, label}`. Hazard events preserve entered/final positions and damage so forced movement animates in order. `last_turn_result.tick` changes once per completed simulation turn and is never reused; presentation may delay the next simulation turn until its animation completes, but cannot alter results.

Starting Normal-speed timings are movement 180 ms/tile; attack anticipation 140 ms, lunge 100 ms, target punch/flash 160 ms, recovery 120 ms; damage number 450 ms; response reveal 500 ms. Speed presentation multipliers are starting values: `slow = 0.6x`, `normal = 1.0x`, `fast = 1.8x`. These change presentation duration only and require playtest tuning.

## UI-facing snapshot

All controller emissions use the production-aligned envelope:

```gdscript
{
  "type": String,                   # prototype.briefing|preparation|combat|review
  "meta": {"t": int, "seed": int},
  "data": Dictionary,               # deep-copied UI projection
  "actions": Dictionary             # slot-keyed; never Array
}
```

The preparation projection includes exactly one `party_roster`, one `selected_deployment_actor_id`, `deployment_assignments`, and board deployment slots. The board's actor tokens are not selectable in preparation; no other card/list/initiative surface may select or assign an Echo.

The combat projection includes board, actors, objective, directive, initiative, round-based charge, `playback_speed_id`, immutable `playback_speed_options`, `ping_library`, selected `ping_preview`, `queued_ping_confirmation`, `unresolved_ping`, response feedback/guidance states, `last_turn_result`, attention cues, overlay legend/toggles, timeline tail, and debug metrics. It contains no pause/manual-step state. The review projection includes the complete timeline and comparison metrics. Player-facing text uses Standing and the exact canonical/prototype Directive, ping, hazard, and objective labels.

Required combat UI fields:

```gdscript
{
  "playback_speed_id": String,
  "playback_speed_options": [
    {"id": "slow", "label": "Slow", "multiplier": 0.6},
    {"id": "normal", "label": "Normal", "multiplier": 1.0},
    {"id": "fast", "label": "Fast", "multiplier": 1.8}
  ],
  "ping_library": Dictionary,
  "ping_preview": Dictionary,
  "queued_ping_confirmation": Dictionary,
  "unresolved_ping": Dictionary,
  "last_turn_result": Dictionary,
  "overlay_legend": Array[Dictionary], # {id,label,description,shape/color hint}
  "overlay_visibility": {"routes": bool, "chokepoints": bool}
}
```

## Signals and boundaries

- `PrototypeController._publish_snapshot()` directly calls `PrototypeUI.set_snapshot(snapshot)`; there is no redundant controller snapshot signal.
- `PrototypeUI.action_requested(action)` -> `PrototypeController.handle_action(action)`.
- `TacticalBoardView.cell_selected(pos)` and `subject_selected(subject)` -> UI, which emits preview commands; the view never mutates simulation state.
- `PrototypeSimulation.state_changed()` -> controller rebuilds and directly publishes a snapshot.
- Controller playback is mandatory during combat. It uses a presentation gate/timer and resolves exactly one atomic actor turn after the previous `last_turn_result` animation duration. Ping browsing never stops this gate.
- `prototype.playback.speed` accepts only `slow|normal|fast` and changes presentation scheduling only.
- `prototype.deployment.select_echo` selects the sole roster row; `prototype.deployment.assign_slot` assigns that selected Echo to the board slot and deterministically swaps occupants. There is no actor-token assignment action.
- `prototype.ping.select`, `.preview`, `.confirm`, and `.cancel` never pause playback. `.confirm` buffers during an animation and commits/rejects at the next boundary.
- `prototype.combat.next`, `prototype.combat.pause`, `prototype.combat.resume`, `prototype.ping.request`, and any equivalent player-facing manual/pause actions are forbidden in v0.6.

Action types use `prototype.<domain>.<verb>` and include a `slot`. Persistent nodes, controls, and layout are authored in `.tscn`; scripts update values and draw the variable board only.

## Deterministic namespaces

All local RNG derives from `seed` with a stable string hashed into a local `RandomNumberGenerator`:

- `prototype.keeper.board.<mode>.attempt.<n>`
- `prototype.keeper.board.<mode>.hazards`
- `prototype.keeper.board.<mode>.objective`
- `prototype.keeper.board.<mode>.deployment`
- fixture actors are currently explicit and consume no RNG namespace
- `prototype.keeper.initiative.<actor_id>`
- `prototype.keeper.protect.carryable`
- `prototype.keeper.protect.theft.round.<n>`
- `prototype.keeper.response.<ping_id>.<confirmed_round>.<actor_id>`
- actor turns are currently threshold/path driven and consume no turn RNG namespace
- `prototype.keeper.next_seed.<current_seed>`

Do not use OS time or global random functions. Adding a new random decision requires a new namespace; existing namespaces and draw order are never repurposed.

## File ownership during parallel work

- Simulation agent: `simulation/` and explicitly delegated controller integration patches.
- Board agent: `board/` and this corrective contract audit.
- UI agent: `ui/`, `KeeperTacticalGuidance.tscn`, and local `.tres` resources only.
- Verification agent: `tests/`, `RUN.md`, and test/debug instrumentation files explicitly agreed with the lead.
- Lead: orchestration, contract review, contribution review, and integration decisions only. The lead does not edit files; implementation and corrective patches are explicitly delegated to an owning agent.
