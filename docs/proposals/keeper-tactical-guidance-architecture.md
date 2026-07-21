# Keeper Tactical Guidance — Production Architecture Plan

**Status:** Approved production architecture reference — implementation remains governed by picked-up stories  
**Design input:** `prototypes/keeper_tactical_guidance/SPEC.md` v0.6 and `FINDINGS.md`  
**Production baseline inspected:** 2026-07-12  
**Scope:** Incremental integration of tactical board quality, encounter preparation, automatic combat presentation, and Keeper pings into the existing deterministic encounter flow  
**Prototype dependency rule:** Production may adapt or copy validated concepts. No file under `core/`, `ui/`, `data/`, or `tests/` may import, preload, load, or otherwise depend on `prototypes/keeper_tactical_guidance/`.

## 1. Architecture decision

Implement the approved interaction model as an extension of the existing encounter architecture, not as a second combat runtime.

The production integration should preserve these authorities:

- `FlowRuntime.dispatch(action)` remains the only mutation entry point.
- `EncounterContext` remains the owner of one encounter's transient state.
- `CombatState` remains the authoritative deterministic combat-state dictionary.
- `ActorStateMachine.advance_turn()` remains the only intent-selection choke point.
- `BehaviorArbiter` remains the one weighted behavior system for Echo identity, directives, bonds, Calling, fear, morale, Standing, and maturity expression.
- `CombatState.check_end_condition()` and the existing per-mode round-end branches remain authoritative for objective wins and losses.
- `FlowEncounterState` remains responsible for creating an encounter and projecting render-safe snapshots.
- `CombatBoardScreen` remains a snapshot renderer. It may own presentation timing, animation queues, camera state, and playback speed, but not simulation decisions.
- `StageTerrain` and `GridService` remain the low-level topology and grid-math sources of truth.

The new work should be implemented as small pure services called by those authorities. It must not add another actor model, behavior tree, objective resolver, emotion model, save channel, or frame-driven simulation loop.

### Promotion cutline

The Foundation production cut must enable the complete experience for all seven currently authored combat modes: `COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PROTECT`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`. Every mode preserves its existing placement, pressure, objective, and resolution authority while gaining compatible preparation, tactical-field, guidance, and readability behavior.

The prototype directly validated only `RECOVER` and `PROTECT`. That evidence informs the shared architecture but does not narrow the promoted Foundation scope. The other five modes require mode-specific production design and verification rather than being treated as already proven by the prototype.

## 2. Current production seams

The repository already contains most of the needed rails:

1. `FlowRuntime._resolve_next_actor()` resolves one living actor per dispatch and publishes one snapshot. This is already the correct atomic boundary for non-pausing ping confirmation and presentation gating.
2. `FlowRuntime._end_round()` already owns emotion ticks, `RECOVER` hold progress, `PROTECT` theft and guard progress, reinforcements, mode-specific updates, and the final end-condition check. Round Charge belongs here, after all round consequences and before the next-round snapshot is projected.
3. `ActorStateMachine.advance_turn()` computes maturity expression, Calling behavior, rank/presence strength, fear thresholds, leadership, and then delegates to `BehaviorArbiter`. This is the correct seam for evaluating a pending ping response once and passing its influence into the existing arbiter.
4. `BehaviorArbiter` already scores directive intent weights and layers vow and bond bias. Guidance can be another additive, recipient-scoped influence layer rather than an override or separate identity system.
5. `FlowEncounterState.enter()` already generates `StageTerrain`, places actors, chooses objective parameters, and places objective actors before `combat.init`. It can call a tactical board/deployment service without adding a flow state.
6. `EncounterContext` already stores transient terrain, objective parameters, last action results, and round snapshots. Tactical preparation and guidance do not require campaign persistence.
7. `FlowEncounterState.build_round_snapshot()` already projects actors, terrain, initiative, objective state, `last_actor_action`, and slot-keyed actions. New fields can be additive.
8. `CombatBoardScreen` already has automatic timer dispatch, three speeds, isometric tiles, pan/zoom/recenter, a token presentation state, move telegraph, objective banner, and a persistent `RealmShell` Echo bar.
9. `StageTerrain` provides deterministic irregular connected terrain, walkable sets, distance fields, and next-step pathing. It does not currently validate tactical route diversity, chokepoints, objective/deployment access, hazards, or unavoidable lethal routes.
10. `GridService` already enforces walkable-aware placement and movement with deterministic tiebreaks.
11. `DirectiveService` is config-backed and extensible. Adding promoted Directives is a config/content change, not a new directive service.

### Current debt that this work must not deepen

- `FlowRuntime` currently contains a very large amount of per-turn and per-round mode logic. New guidance, hazard, and board algorithms should not be written inline there.
- `FlowEncounterState.enter()` currently contains terrain generation, spawn construction, objective scaling, and per-mode objective placement. New tactical generation should be extracted behind a service API instead of adding more nested branches.
- `CombatBoardScreen` currently exposes a Manual toggle. The promoted design removes the player-facing manual path; the existing `combat.next_actor` and `combat.confirm_round` actions remain internal automatic driver actions.
- `last_actor_action` is too small for reliable animation: movement lacks a guaranteed ordered path and attack/hazard/follow-up beats are not represented as one structured presentation result.
- Authored `PROTECT` canon requires a deterministic 60% carryable roll, holder burden, class/state mitigation of that burden, enemy theft/recovery, and double damage to the enemy carrier. The inspected runtime implements theft and double damage but not the complete carryable/holder path. That is a production implementation gap which must close before Foundation acceptance; it is not an open mechanic unless the canon is explicitly amended.

## 3. Target component boundaries

### 3.1 Core services

#### `CombatBoardGenerator` — new, pure-static

Responsibilities:

- Build bounded deterministic tactical-board candidates from `StageTerrain`.
- Select a seeded board pattern/profile without hand-authoring individual boards.
- Place objective, deployment zone/slots, enemy entry zones, hazards, and visual obstacle descriptors.
- Return the first candidate accepted by `CombatBoardValidator`.
- Return diagnostics and a deterministic conservative fallback when all attempts fail.

It does not place runtime actor dictionaries, resolve hazards, mutate saves, or know about Godot nodes.

#### `CombatBoardValidator` — new, pure-static

Responsibilities:

- Connectivity and capacity.
- Objective and deployment accessibility.
- At least one meaningful chokepoint for modes that require it.
- At least two viable routes with a real distance/exposure/width/pressure tradeoff where required.
- No route whose minimum unavoidable hazard damage is lethal to the lowest-HP deployed Echo at full health.
- `RECOVER` deep-objective access and hold-space validation.
- `PROTECT` competing approach lanes and at least one valid defensive/fallback region.
- Stable diagnostic codes; no logging or mutation.

#### `CombatDeploymentService` — new, pure-static

Responsibilities:

- Produce generated numbered deployment slots from a validated board.
- Validate one Echo-to-slot assignment.
- Deterministically swap occupied assignments.
- Apply finalized assignments to encounter actors before `CombatState.create()`.
- Reject duplicates, missing actors, non-walkable slots, objective overlap, and enemy-zone overlap.

It does not choose the party and does not create a second selection model.

#### `CombatHazardService` — new, pure-static

Responsibilities:

- Validate and index `burning_ground`, `unstable_ground`, and `binding_growth` data.
- Resolve entry effects and end-turn effects in a fixed order.
- Return structured hazard beats and actor mutations to the combat loop.
- Provide pure hazard-exposure summaries to `BehaviorArbiter` so route choice can account for danger.

Fixed order per actor turn:

1. movement enters a cell;
2. Unstable Ground pushes to a valid walkable unoccupied cell, or applies configured fallback damage;
3. Binding Growth ends remaining movement;
4. the selected action and any counters resolve;
5. Burning Ground applies end-turn damage;
6. objective/custody/end-condition updates complete at their existing boundary.

Every hazard affects living Echoes and enemies under the same rule. Structures do not trigger hazards unless a future mode explicitly opts in.

#### `ProtectObjectiveService` — new, pure-static mode adapter

Responsibilities:

- Resolve the authored 60% carryable decision from the encounter seed.
- Represent holder, burden, and class/state mitigation without changing actor identity fields.
- Return custody, pickup, movement, theft, recovery, and carrier-damage state deltas/events.
- Preserve the existing `CombatState.check_end_condition()` authority for victory/defeat.

This service closes the current runtime gap; it does not redesign `PROTECT` or create a second objective family.

#### `CombatGuidanceService` — new, pure-static

Responsibilities:

- Load and expose the five configured ping definitions.
- Build spatial previews from board, actors, subject, and current charge.
- Enforce exactly one recipient mode: `party_wide`, `area_based`, or `echo_specific`.
- Validate and confirm a ping only from a current preview.
- Snapshot subject, footprint, and recipient IDs at confirmation.
- Manage charge, activation round, remaining recipients, expiry, and unresolved blocking.
- Never evaluate a response for an actor outside the snapshotted recipients.

This service owns ping lifecycle rules, not Echo identity. Every function receives an input guidance-state dictionary and returns a new state plus structured events/deltas; it never mutates `EncounterContext`, `CombatState`, actors, or the caller's dictionary in place. Representative APIs:

```gdscript
build_preview(state, request, combat_view, cfg) -> {"state": Dictionary, "events": Array}
confirm(state, preview, combat_view, round, cfg) -> {"state": Dictionary, "accepted": bool, "events": Array}
complete_round(state, round, combat_over, cfg) -> {"state": Dictionary, "events": Array}
complete_recipient_turn(state, actor_id, response, round) -> {"state": Dictionary, "events": Array}
expire_at_round_end(state, living_actor_ids, round) -> {"state": Dictionary, "events": Array}
```

`FlowRuntime` assigns the returned state to `combat_state["guidance"]` at the dispatch/turn boundary and logs the returned events.

#### `GuidanceResponseService` — new, pure-static adapter

Responsibilities:

- Evaluate one snapshotted recipient immediately before that Echo's first living turn in the activation round.
- Consume existing actor, emotion, bond, objective, hazard, Calling, Standing, and maturity-expression inputs already available to `ActorStateMachine`.
- Return one of `align`, `interpret`, `hesitate`, `object`, or `refuse`, with a primary reason for every non-align result.
- Convert that response into a normalized influence payload for `BehaviorArbiter`.

It must not calculate an alternative personality, obedience, maturity, morale, fear, Calling, or bond state. It is an adapter from existing identity state to a temporary behavior influence. It returns response/influence data only and never mutates guidance state, recipient lists, actors, or encounter state.

#### `CombatTurnResult` / `CombatTurnResultBuilder` — new, pure-static

Responsibilities:

- Normalize one completely resolved actor turn into an immutable presentation event.
- Include ordered movement, target, damage, hazards, custody/objective beats, counters/follow-ups, and ping response.
- Assign a monotonic encounter-local presentation sequence.
- Supply structured data to UI; UI must not infer attacks from timeline prose.

### 3.2 Existing authorities to extend

#### `ActorStateMachine`

Before `ActorStateMachine.advance_turn()`, `FlowRuntime` derives a read-only `guidance_activation` for the current actor from authoritative guidance state. After the actor state machine computes expression band, Calling behavior, presence strength, rank strength, and the dynamic fear threshold:

1. evaluate the supplied activation through `GuidanceResponseService` when non-empty;
2. keep the returned response/influence local and add it to the augmented context;
3. retain the Absolute Fear Rule as an independent actor-state outcome, attaching the guidance response to an early-return refusal intent when both occur;
4. call the existing behavior module when the Absolute Fear Rule does not fire;
5. return the response on the intent; only after the actor's movement, action, damage, hazards, custody, counters, and end-condition effects complete does `FlowRuntime` call `CombatGuidanceService.complete_recipient_turn()` and assign its returned state.

A ping `refuse` means the Echo rejects the guidance; it does **not** automatically force `actor.refuse`. The Echo still chooses an autonomous action without guidance influence. If the Absolute Fear Rule independently fires, the action may also be `actor.refuse`, and the turn result must distinguish the two reasons.

#### `BehaviorArbiter`

Add a recipient-scoped influence pass after base/directive scoring and before final sort. The influence may:

- add configured weights to compatible action families;
- bias a target/anchor/lane/objective subject already represented by valid candidates;
- suppress no candidate by itself;
- never inject an exact path, exact attack, or guaranteed action;
- scale by the response influence (`align` strongest, `refuse` zero).

Existing trait, vector, Calling, fear, morale, vow, bond, skill, situational, and objective logic remains active. Guidance is intentionally allowed to lose to those pressures.

#### `FlowRuntime`

Remain a thin coordinator:

- dispatch deployment and ping actions;
- call the services and assign their returned state dictionaries at dispatch boundaries;
- call one actor turn;
- apply returned hazard and objective beats in the existing order;
- increment charge at the completed-round boundary;
- publish the rebuilt snapshot;
- log structured events.

No timers, tweens, frame polling, or UI state enter `FlowRuntime`.

## 4. Production state contracts

All shapes below are additive extensions. Exact schema keys should be locked in contract tests before implementation.

### 4.1 `EncounterContext` additions

```gdscript
var tactical_board: Dictionary = {}
var preparation_state: Dictionary = {}
var last_turn_result: Dictionary = {}
var presentation_sequence: int = 0
```

These are transient and never written directly to campaign save data.

### 4.2 Tactical board shape

```gdscript
{
  "schema_version": 1,
  "mode": String,
  "bounds": {"w": int, "h": int},
  "terrain": Dictionary,                 # StageTerrain output
  "walkable": Dictionary,                # "col,row" -> true
  "deployment_zone": Array[Dictionary],
  "deployment_slots": Array[{"id": String, "position": Dictionary}],
  "enemy_entry_zones": Array[Dictionary],
  "objective_position": Dictionary,
  "hazards": Array[Dictionary],
  "obstacles": Array[Dictionary],         # visual projection; never independent collision
  "routes": Array[Dictionary],            # diagnostics/optional overlay
  "chokepoints": Array[Dictionary],       # diagnostics/optional overlay
  "validation": {
    "valid": bool,
    "attempt": int,
    "codes": Array[String],
    "metrics": Dictionary,
    "used_fallback": bool
  }
}
```

`walkable` is authoritative for collision/pathing. `obstacles` visualizes non-walkable topology or authored landmarks but must never create a second collision map.

### 4.3 Hazard shape

```gdscript
{
  "id": String,
  "type": String,                         # burning_ground|unstable_ground|binding_growth
  "cells": Array[Dictionary],
  "center": Dictionary,
  "damage": int,
  "label": String,
  "rule": String,
  "danger_cost": int
}
```

### 4.4 Preparation shape

```gdscript
{
  "phase": String,                        # briefing|deployment|ready|combat
  "selected_echo_id": String,
  "assignments": Dictionary,              # echo_id -> deployment_slot_id
  "valid": bool,
  "invalid_reason": String,
  "locked": bool
}
```

The UI exposes exactly one assignment path: select one row in the one party roster, then select one numbered board slot. During briefing/deployment, actor tokens and initiative portraits are hidden; the board shows neutral numbered slot occupancy, while the panel row shows which slot that Echo owns. `RealmShell` must hide/collapse its EchoBar so `CombatPreparationPanel` is the only visible party representation. Actor tokens, initiative, and the EchoBar return when `encounter_phase == "combat"`.

### 4.5 Guidance state in `CombatState`

```gdscript
"guidance": {
  "charge": int,                          # starts 0
  "max_charge": int,                      # starts 5
  "last_charge_round": int,
  "selected_ping_id": String,             # transient selection projection
  "preview": Dictionary,
  "unresolved_ping": Dictionary,
  "ping_sequence": int,
  "responses": Dictionary                 # actor_id -> latest response projection
}
```

`CombatState["guidance"]` is the single authoritative guidance-state location. `EncounterContext` does not carry a second mutable copy. Every transition replaces this dictionary with the copied state returned by `CombatGuidanceService`.

Authoritative rules:

- `charge += 1` exactly once after a fully completed round, capped at 5.
- Echo-specific costs 2, area-based costs 3, party-wide costs 5.
- Any confirmation consumes all stored charge.
- Cancel consumes nothing.
- One unresolved ping blocks another confirmation.
- Confirmation in round `r` activates in `r + 1`.
- Charge may rebuild while the ping is unresolved.
- Dead recipients are removed without a response.
- The ping clears after all living snapshotted recipients have taken their first activation-round turn, or at activation-round end.

### 4.6 Ping definition and confirmed shape

```gdscript
{
  "id": String,
  "label": String,
  "suggestion": String,
  "mechanical_influence": String,
  "targeting_instruction": String,
  "recipient_mode": String,
  "charge_required": int,
  "subject": Dictionary,
  "footprint": Array[Dictionary],
  "eligible_recipient_ids": Array[String],
  "recipient_ids": Array[String],          # immutable after confirmation
  "remaining_recipient_ids": Array[String],
  "confirmed_round": int,
  "activation_round": int,
  "expires_after_round": int,
  "availability_state": String,
  "rounds_until_charge": int,
  "expected_duration": String,
  "valid": bool,
  "invalid_reason": String
}
```

Positional subjects never alter recipient mode. Each of the five pings has one configured mode:

| Ping | Mode | Cost |
|---|---|---:|
| Hold Ground | `echo_specific` | 2 |
| Break Through | `area_based` | 3 |
| Focus Threat | `party_wide` | 5 |
| Regroup | `area_based` | 3 |
| Secure Objective | `party_wide` | 5 |

### 4.7 Response shape

```gdscript
{
  "actor_id": String,
  "ping_id": String,
  "outcome": String,                      # align|interpret|hesitate|object|refuse
  "presentation_state": String,           # listening|resisting|rejecting
  "influence": float,
  "primary_reason": String,
  "secondary_reason": String,
  "explanation": String,
  "factors": Dictionary
}
```

Pending is a lifecycle state, not a response outcome. Unaffected Echoes have no response record and project `guidance_state = "unaffected"`. Absence must never be interpreted as refusal.

### 4.8 Structured turn result

```gdscript
{
  "presentation_id": int,
  "tick": int,
  "round": int,
  "actor_id": String,
  "action_type": String,
  "from_pos": Dictionary,
  "to_pos": Dictionary,
  "path": Array[Dictionary],
  "target_id": String,
  "damage": int,
  "hit": bool,
  "hazard_events": Array[Dictionary],
  "objective_events": Array[Dictionary],
  "follow_up": Array[Dictionary],
  "ping_response": Dictionary,
  "guidance_expression": String
}
```

The complete state mutation for that actor is finished before this result is published.

## 5. Snapshot and action contracts

The envelope remains:

```gdscript
{
  "type": "flow.encounter",
  "meta": {"t": int},
  "data": Dictionary,
  "actions": Dictionary
}
```

### Additive `data` fields

```gdscript
{
  "encounter_phase": String,
  "tactical_board": Dictionary,
  "preparation": Dictionary,
  "party_roster": Array[Dictionary],
  "directive": Dictionary,
  "guidance": Dictionary,
  "ping_library": Dictionary,
  "last_turn_result": Dictionary,
  "attention_cues": Array[Dictionary],
  "overlay_legend": Array[Dictionary],
  "overlay_visibility": {"routes": bool, "chokepoints": bool}
}
```

`party_roster` appears once in the encounter preparation content. During `briefing` and `deployment`, `RealmShell` hides/collapses its persistent EchoBar, actor tokens/initiative portraits are hidden, and `CombatPreparationPanel` is the only visible party representation. The board exposes numbered slot occupancy without duplicating Echo identity. The shell restores the EchoBar and the board renders actor tokens when combat begins. No initiative row, token, portrait, or duplicate card may assign an Echo.

### Player and UI-driver actions

All mutations still pass through `FlowRuntime.dispatch`.

| Action type | Source | Notes |
|---|---|---|
| `combat.deployment.select_echo` | roster row | Per-row dispatch; not stored in `snapshot.actions` |
| `combat.deployment.assign_slot` | board slot | Direct board interaction; deterministic swap |
| `combat.deployment.reset` | preparation control | Optional slot action |
| `combat.init` | `cta.combat_init` | Existing slot; disabled until assignments validate |
| `combat.ping.select` | ping card | Read/preview selection; no charge mutation |
| `combat.ping.preview` | board subject/cell | Rebuilds current preview |
| `combat.ping.confirm` | `cta.ping_confirm` | Revalidates current state, snapshots recipients, consumes all charge |
| `combat.ping.cancel` | `overlay.ping_cancel` | Clears unconfirmed preview only |
| `combat.next_actor` | hidden UI driver | Automatically dispatched after presentation completes |
| `combat.confirm_round` | hidden UI driver | Automatically dispatched between rounds |

`snapshot.actions` remains a slot-keyed dictionary. Repeated list and board interactions dispatch their own typed actions; they are not duplicated into the action dictionary. The automatic driver actions may remain in `actions` so the renderer receives the current valid command, but no visible Next/Confirm/Manual control is rendered.

Playback speed is presentation-only local UI state (`slow`, `normal`, `fast`). It must not change `CombatState`, RNG, turn order, or action results. Persistence of the preferred speed is deferred to a general settings story rather than combat save data.

## 6. Deterministic namespaces

Existing namespaces and their draw order remain unchanged on the disabled/legacy path. The tactical path uses new append-only namespaces:

```text
combat.tactical_board.<encounter_id>.profile
combat.tactical_board.<encounter_id>.attempt.<n>.terrain
combat.tactical_board.<encounter_id>.attempt.<n>.objective
combat.tactical_board.<encounter_id>.attempt.<n>.hazards
combat.tactical_board.<encounter_id>.attempt.<n>.deployment
combat.protect.carryable.<encounter_id>
combat.guidance.<encounter_id>.ping.<ping_sequence>.<actor_id>
```

Rules:

- Board candidate attempts have independent RNGs. Rejection never shifts another system's draws.
- The first valid candidate wins; attempt count is bounded and configured.
- Hazard, objective, and deployment draws are separate even when generated in one service call.
- Response evaluation should be threshold/pure in the first production cut. The guidance namespace is reserved only for a future approved deterministic tie-break; do not draw from it merely to create variation.
- Do not use `sim_tick` as a seed. Retrying the same encounter seed and choices must reproduce the result.
- Existing `combat.placement.<encounter_id>`, `combat.theft.<encounter_id>.<round>`, initiative, reinforcement, and objective namespaces are not renamed or repurposed.
- Feature-off runs preserve existing seed usage. Feature-on runs are a declared deterministic-generation version change and require golden fingerprints.

## 7. Board generation and validation

### Candidate process

1. Resolve realm terrain signature and board bounds exactly as production does now.
2. Seed a tactical profile such as split approaches, central choke, twin lanes, or basin/fallback. Profiles alter generation parameters, not objective rules.
3. Generate a `StageTerrain` candidate using the attempt namespace.
4. Derive walkable topology and candidate obstacles from non-walkable volume.
5. Place objective and deployment/enemy zones according to the mode.
6. Place hazards only after routes and required safe capacity are known.
7. Calculate route, choke, accessibility, capacity, and minimum-danger metrics.
8. Accept the first valid candidate.
9. If all configured attempts fail, generate a conservative deterministic fallback with connected deployment/objective regions, two routes, one readable choke, and no mandatory hazard damage. Mark `used_fallback = true`.

### Variety without uncontrolled complexity

The prototype finding that boards are too similar should be addressed through a small topology-profile vocabulary and metric bands, not dozens of exceptions. Batch diagnostics should track profile frequency, walkable ratio, route cost delta, hazard exposure delta, choke count, objective depth, and fallback rate. No one profile may exceed its configured distribution tolerance over a large deterministic batch.

### Objective compatibility

- `RECOVER`: preserve hold reset, configured hold requirement, holder designation, reinforcements, and universal kill-all. Board validation adds deep access, two viable approaches, and adequate adjacent hold cells.
- `PROTECT`: implement and preserve the authored 60% carryable roll, holder burden, class/state mitigation, entity HP, guard-radius counter/reset, theft/recovery, clock-out loss, double-damage enemy carrier, and universal kill-all. Board validation adds multiple approach lanes and a viable fallback region. Runtime parity with all authored rules is a first-slice acceptance condition.
- `COMBAT`, `PURIFY_SHRINE`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`: preserve every authored win/loss, actor, timing, wave, escape/containment, shrine, spirit, and universal kill-all rule that applies. Each requires mode-specific objective accessibility, pressure topology, guidance-subject, preview, and readability validation before Foundation completion.
- No board service may decide victory, defeat, custody, or round progress.

## 8. Preparation and deployment flow

Use the existing `flow.encounter` pre-combat phase; do not add a new campaign flow state.

Recommended sequence:

1. Stage-level Directive selection remains where the current stage-entry flow owns it.
2. Engaging a combat situation creates `EncounterContext`, actors, tactical board, objective, and generated deployment slots.
3. `flow.encounter` first projects `encounter_phase = "briefing"` with objective, hazards, routes/legend, enemy pressure, and party tendencies.
4. The same screen transitions locally to `encounter_phase = "deployment"` through an action/snapshot update. `RealmShell` keeps its EchoBar collapsed throughout briefing/deployment.
5. The player assigns each active Echo through the one roster-to-numbered-slot interaction; the panel row reports its slot and the board does not duplicate the Echo as a token.
6. `combat.init` is enabled only when every required living Echo has one valid slot.
7. Final assignments are applied before `CombatState.create()` calculates readiness and deep-copies actors.
8. Once combat starts, assignments lock, `RealmShell` restores its EchoBar, and no exact movement command becomes available.

This is encounter-specific tactical deployment, not general party management or skill loadout. StageMap remains the home for party composition and broader pre-stage preparation. A UX signoff is required before implementation because this adds a richer subphase to the existing combat screen.

## 9. Automatic playback and presentation queue

Production remains dispatch-driven rather than frame-simulated:

1. Core resolves one atomic actor turn and publishes one `last_turn_result`.
2. `CombatBoardScreen` de-duplicates by `presentation_id` and enqueues the event.
3. The screen animates response reveal, movement, hazard displacement, attack/counter, damage, and objective/custody beats in contract order.
4. When the event completes, the screen automatically emits the current hidden `combat.next_actor` or `combat.confirm_round` action.
5. Ping browsing and preview remain live while animations run. A ping dispatch sees already-resolved authoritative state and revalidates against it.
6. Speed scales animation duration only. Slow/Normal/Fast never changes the number or order of dispatches.

No player-facing pause, resume, manual-step, Next, or Confirm Round control remains. Application/window suspension may naturally stop Godot processing, but it is not a combat mechanic.

The UI must never advance simulation before the current presentation event is complete, and must never mutate actor positions to make an animation look correct. Tokens interpolate from result data while the snapshot remains authoritative for final positions.

## 10. Ping lifecycle and response timing

### Confirmation

- A preview is recomputed from the latest snapshot whenever board/actor state changes.
- Confirm dispatch revalidates charge, unresolved state, subject, footprint, and eligible recipients.
- A valid confirmation consumes all charge, increments `ping_sequence`, snapshots subject/footprint/recipients, and sets `activation_round = current_round + 1`.
- All living recipients project `pending` immediately.
- Invalid confirmation changes no charge and returns a specific availability state/reason.

Because production resolves only one actor per dispatch, dispatch itself is an atomic boundary. The prototype's buffered-confirmation concept does not require a frame-level core queue. If input arrives during an animation, the preceding actor is already resolved in core; the confirmation can commit on that dispatch after revalidation. The presentation layer must not send the next actor-driver action until its animation is complete.

### Activation

- At the recipient's first living initiative entry in the activation round, `GuidanceResponseService` evaluates the response before intent selection.
- The response is written into the same turn result.
- `BehaviorArbiter` receives the resulting temporary influence for that turn.
- The response reveal animates immediately before the action, then the first action visually expresses agreement, interpretation, resistance, or rejection.
- After the complete atomic turn, `FlowRuntime` passes the response to `CombatGuidanceService.complete_recipient_turn()`, assigns the returned guidance state, and only then removes the recipient from `remaining_recipient_ids` through that returned state.
- Non-recipients are never evaluated and never show a response.

### Round charge boundary

In `_end_round()`, charge increments only after all actor turns, movement, damage, hazards, theft/custody, objective progress, emotion ticks, and end-condition updates for that round have completed. A round that reaches combat end still counts as completed for metrics, but its newly gained charge has no gameplay use and need not animate before Resolve.

## 11. UI scene and layer plan

Persistent UI structure is authored in `.tscn`; scripts update values and draw variable board data only.

### `CombatBoardScreen.tscn`

Retain the existing scene and add authored child scenes/layers:

```text
CombatBoardScreen (Control)
├── Ground / TileMapLayer
├── HazardFloorLayer (Node2D)
├── DeploymentAndPingLayer (Node2D)
├── MoveTelegraphLayer (Node2D)
├── TokenLayer (Node2D)
├── CombatFeedbackLayer (Node2D)
├── ObstacleForegroundLayer (Node2D)
├── BarkPopupLayer (Node2D)
├── ScreenChrome (Control, containers)
│   ├── ObjectiveBanner
│   ├── InitiativePanel
│   ├── PreparationPanel instance
│   ├── GuidancePanel instance
│   ├── SpeedBar
│   ├── OverlayLegend
│   └── CameraControls
└── AutoDriverTimer
```

Required visual order is ground/hazard/footprints, actors and combat feedback, then raised obstacle foreground. This satisfies the validated isometric occlusion direction without changing collision.

### New reusable UI scenes

- `CombatPreparationPanel.tscn/.gd`: one roster, inspection details, selected-row state, assignment status, start CTA.
- `CombatGuidancePanel.tscn/.gd`: charge meter, five inspectable ping cards, plain-language suggestion/effect/targeting/cost/activation, current preview and response summary.
- `CombatOverlayLegend.tscn/.gd`: obstacles, three hazards, deployment, ping footprint, routes, chokepoints.
- `CombatFeedbackLayer.gd`: presentation-event animation only; no core reads.
- `CombatHazardLayer.gd`, `CombatObstacleLayer.gd`, `CombatPingLayer.gd`: variable world drawing from snapshots.

The existing `CombatTokenLayer` should gain guidance badges/states and structured hit/movement animation input. It should not duplicate the RealmShell Echo cards. UI meaning must use shape/text/icon as well as color, and focus/controller navigation must cover every ping, preparation row, speed button, and confirm/cancel control.

## 12. Configuration schema

Add under `data.combat` so the existing runtime read path remains clear:

```json
{
  "tactical_guidance": {
    "enabled": false,
    "enabled_modes": ["combat", "purify_shrine", "recover", "protect", "endure", "pursue", "guide_spirit"],
    "generation_version": 1,
    "max_generation_attempts": 16,
    "board_profiles": {},
    "validation": {},
    "deployment": {},
    "hazards": {
      "burning_ground": {},
      "unstable_ground": {},
      "binding_growth": {}
    },
    "charge": {
      "start": 0,
      "max": 5,
      "gain_per_completed_round": 1
    },
    "pings": {},
    "response_thresholds": {},
    "response_influence": {},
    "presentation": {}
  }
}
```

Promoted `Press the Path` and `Hold the Circle` definitions, if accepted by the canonical proposal, belong in existing `data.directives` and use the existing intent-weight vocabulary. Do not hardcode their IDs in traversal or combat code.

Config tests must reject unknown recipient modes, hybrid/missing modes, bad costs, invalid hazard ordering, negative damage, non-bounded attempts, missing explanation strings, and guidance intent keys not understood by `BehaviorArbiter`.

## 13. Save and persistence decision

No save-schema change in the first production cut.

Rationale:

- `EncounterContext` and current combat state are already transient.
- Combat-start saves are checkpoints around campaign flow, not exact mid-round resume snapshots.
- Persisting a partially animated turn or unresolved ping would create a larger encounter-resume project and new corruption/replay risks.
- Playback speed is a presentation preference and should later use a general settings store.

The active stage Directive continues using the existing stage/save field. Tactical board, deployment assignments, hazards, charge, pings, responses, and presentation sequence live only for the encounter. If exact mid-combat resume becomes a requirement, it must be a separate save story with additive schema, migration, and replay tests.

## 14. Logging, metrics, and debug surfaces

Add structured events with injected `t`:

```text
combat.board.generated
combat.board.fallback
combat.deployment.assigned
combat.guidance.charge_changed
combat.guidance.previewed
combat.guidance.confirmed
combat.guidance.rejected_invalid
combat.guidance.response
combat.guidance.expired
combat.hazard.triggered
combat.presentation.turn_built
```

Production snapshots should expose only player-relevant explanations. Generator scores, behavior candidate scores, raw response factors, and route diagnostics belong behind the existing debug-panel/developer toggle and must never become required to understand a ping.

Playtest telemetry should aggregate:

- board profile/fallback/validation distribution;
- Directive, party, deployment, objective, and same-seed outcome;
- charge held/spent and ping chosen;
- preview-to-confirm cancellation and invalidation;
- recipient count, response outcome/reason, and whether the first action matched the influence family;
- hazard exposure/damage and route chosen;
- battle duration, speed usage, rounds, deaths, objective result, and retry choice.

## 15. Verification plan

### Contract and unit tests

- `CombatBoardGeneratorTests`: same seed equality, different-seed variance, bounded attempts, stable fallback, profile distribution.
- `CombatBoardValidatorTests`: connectivity, capacity, objective/deployment access, choke detection, route diversity, unavoidable lethal-route rejection, and mode-specific accessibility/pressure requirements across all currently authored combat modes.
- `CombatDeploymentTests`: one assignment per Echo, swap, invalid slot, final actor positions, no duplicate selection surface contract.
- `CombatHazardTests`: all three hazards, fixed order, occupied push fallback, faction parity, death/end-condition interaction.
- `ProtectObjectiveTests`: seeded 60% carryability, holder burden, class/state mitigation, custody movement, theft/recovery, carrier double damage, clock-out defeat, and same-seed replay.
- `CombatGuidanceTests`: all five pings, exact recipient modes, spatial footprint rules, immutable recipients, invalid reasons, unresolved blocking, returned-state assignment, no in-place mutation, event/delta shape, and recipient removal only after the full actor turn.
- `PingChargeTests`: start/max, +1 once per completed round, persistence, all-charge consumption, cancel, charge rebuild under unresolved ping.
- `GuidanceResponseTests`: recipient-only evaluation, activation-round timing, dead recipient cleanup, all five outcomes, required reasons, deterministic identity factors, and proof that evaluation mutates no input.
- `BehaviorArbiterTests`: additive influence, refusal gives zero influence, directives/identity still compete, no exact-command override.
- `CombatTurnResultTests`: ordered path/damage/hazard/counter/objective/response shape and monotonic IDs.
- `CombatSnapshotTests`: additive fields, no raw sim internals, slot-keyed actions, one roster projection, no manual/pause action.

### Existing regression suites

At minimum run and extend:

- `StageTerrainTests`
- `GridTests`
- `CombatStateTests`
- `CombatServiceTests`
- `CombatRoundTests`
- `CombatSnapshotTests`
- `CombatRoundtripIntegrationTests`
- `BehaviorArbiterTests`
- `DirectiveTests` and directive config tests
- objective-mode tests for all seven modes
- emotion, bond, Calling behavior, maturity-expression, skill, cooldown, KO/death, and retreat suites

### Batch and replay gates

- Large deterministic board batches per enabled mode with zero disconnected/unreachable boards.
- Same seed + same choices produces identical board, initiative, turn results, ping responses, hazards, objectives, and final result.
- Feature flag off reproduces pre-change golden combat fingerprints.
- Same seed with different deployment/Directive/ping schedules produces attributable differences without changing unrelated RNG streams.
- At least one full headless battle for every production objective mode, each covering briefing through Resolve.

### Manual gates

- Jeff signs off the exact preparation location and one-selection interaction before UI implementation.
- Desktop and compact viewport checks for board, preparation, guidance, legend, and Resolve overlay.
- Controller/keyboard focus and reduced-motion path.
- New-player explanation checks from the prototype spec: 4/5 pings understood, 8/10 non-align reasons understood, 8/10 source-target-result animations understood.
- Paired same-seed playtests retain the prototype's meaningful-choice thresholds before enabling by default.

## 16. Backend-first implementation phases

Each phase ends with contract tests, compile check, Jeff's in-game test, documentation, then a focused commit. Frontend work does not start until its backend snapshot contract is passing.

### Phase 0 — Canon and characterization

Goal: freeze the promoted rules and protect legacy behavior.

Likely files:

- `docs/Echoes vNext Working GDD.md`
- `docs/combat-modes.md`
- `CONVENTIONS.md`
- `docs/proposals/keeper-tactical-guidance-proposal.md` (proposal-owned filename may differ)
- existing combat snapshot/round/objective tests

Work:

- Resolve open canon questions listed in section 20.
- Record golden same-seed fingerprints with tactical guidance disabled.
- Lock shapes, action types, event types, and config validation.

### Dependency gate — Foundation behavior and readiness seams

Goal: finish the production authorities that tactical guidance must consume instead of duplicating.

Order:

1. `V2-COMBAT-002` — useful objective/stage-shaped enemy pressure work after `V2-STAGE-004`.
2. `V2-PROG-012` — settle autonomy/refusal threshold behavior before collision-order work.
3. `V2-COMBAT-003` — deterministic collision order and observable primary reasons; must follow `V2-PROG-012`.
4. `V2-DIRECTIVE-002` — identity-sensitive interpretation of a shared influence; follows `V2-COMBAT-003`.
5. `V2-INFRA-004` — consolidated readiness information architecture; coordinate before the preparation UI phase.

The `V2-COMBAT-004A` contract/architecture is approved, but the full ping runtime must not hardcode its own pressure order while these prerequisites remain unsettled.

### Phase 1 — Tactical board, validation, hazards

Goal: validated board data and deterministic effects for all currently authored combat modes, no new UI.

Likely files:

- new `core/combat/CombatBoardGenerator.gd`
- new `core/combat/CombatBoardValidator.gd`
- new `core/combat/CombatHazardService.gd`
- new `core/combat/ProtectObjectiveService.gd`
- `core/state/flow/states/venture/FlowEncounterState.gd`
- `core/state/encounter/EncounterContext.gd`
- `core/runtime/FlowRuntime.gd` (thin calls only)
- `core/actors/behaviors/BehaviorArbiter.gd` (hazard exposure input)
- `data/balance.json`
- new board/validator/hazard/PROTECT objective tests plus `StageTerrainTests`, `GridTests`, mode tests

### Phase 2 — Encounter briefing and deployment backend

Goal: one transient preparation contract before combat init.

Likely files:

- new `core/combat/CombatDeploymentService.gd`
- `core/state/encounter/EncounterContext.gd`
- `core/state/flow/states/venture/FlowEncounterState.gd`
- `core/runtime/FlowRuntime.gd`
- `core/combat/CombatState.gd`
- deployment, snapshot, roundtrip, and initiative tests

No UI changes until snapshot/action tests pass.

### Phase 3 — Round Charge, pings, response adapter

Goal: complete deterministic guidance backend integrated into existing identity selection.

Likely files:

- new `core/combat/CombatGuidanceService.gd`
- new `core/combat/GuidanceResponseService.gd`
- `core/actors/ActorStateMachine.gd`
- `core/actors/behaviors/BehaviorArbiter.gd`
- `core/combat/CombatState.gd`
- `core/state/encounter/EncounterContext.gd`
- `core/runtime/FlowRuntime.gd`
- `core/state/flow/states/venture/FlowEncounterState.gd`
- `data/balance.json`
- guidance, response, charge, arbiter, snapshot, round, emotion, bond, Calling, and maturity tests

### Phase 4 — Structured turn results and automatic driver

Goal: simulation emits presentation-complete events; no manual player control remains.

Likely files:

- new `core/combat/CombatTurnResult.gd`
- `core/runtime/FlowRuntime.gd`
- `core/state/encounter/EncounterContext.gd`
- `core/state/flow/states/venture/FlowEncounterState.gd`
- turn-result, sequential-round, snapshot, and deterministic replay tests

### Phase 5 — Production UI integration

Goal: playable briefing, deployment, automatic combat, pings, response feedback, hazards, obstacles, and animations.

Likely files:

- `ui/screens/combat/CombatBoardScreen.tscn/.gd`
- `ui/screens/combat/CombatTokenLayer.gd`
- `ui/screens/combat/CombatTokenPresentationState.gd`
- `ui/screens/combat/CombatMoveTelegraphLayer.gd`
- new combat preparation/guidance/legend component `.tscn/.gd` files
- new hazard/obstacle/ping/feedback layer scripts with nodes authored in `.tscn`
- `ui/shells/RealmShell.tscn/.gd` to collapse the EchoBar during briefing/deployment and restore it for combat
- `assets/theme/LivingTreeSystem.tres` and reusable theme resources

Do not create persistent controls or layout in GDScript.

### Phase 6 — Rollout, telemetry, and playtest gates

Goal: enable all currently authored combat modes after mode-specific evidence; preserve rollback throughout development.

Likely files:

- `data/balance.json` feature flags/tuning
- DebugPanel command/test registration as appropriate
- telemetry/report projection and tests
- `CONVENTIONS.md`, `docs/combat-modes.md`, `docs/MEMORY.md`, and story docs

## 17. Migration and rollback

### Migration

- No save migration in the first cut.
- Additive snapshot fields are ignored safely by old/fallback render paths.
- Config is additive under `data.combat.tactical_guidance`.
- New combat-state keys receive safe defaults from `CombatState.create()`.
- Generation behavior has an explicit `generation_version` and mode allowlist.

### Rollback

- `enabled = false` routes all modes through the current encounter generation, placement, manual-capable screen contract, and existing objective logic while the feature is under development.
- Per-mode allowlist permits disabling one problematic mode without touching saves or objectives.
- Board-generation failure uses a deterministic safe fallback and logs the diagnostics; it never leaves the encounter unstartable.
- Guidance failure is fail-closed: preview/confirmation becomes invalid, no charge is consumed, and autonomous combat continues under the active Directive.
- UI failure must not mutate core. Unknown additive snapshot fields can be ignored, while the hidden automatic driver actions remain available.
- Do not delete old fields or old code paths until feature-on production playtests and same-seed regression evidence are accepted.

## 18. Dependency and backlog sequencing

The canonical backlog home is the existing [`V2-COMBAT-004`](https://app.notion.com/p/339c3d1ede92819ab2a3cdf32df96731), now Ready/Mostly Locked/P1/Foundation at order 262. Its scope names tactical pre-positioning and richer mid-battle guidance without invalidating indirect command. Refine and split that story; do not create a competing tactical-guidance epic.

Do **not** expand [`V2-STAGE-004`](https://app.notion.com/p/339c3d1ede928111b43af78e2c44f7ee). That story owns consistent encounter resolution, persistence, logging, hostile-contact escalation, noncombat outcomes, and the encounter-to-combat handoff. Charge, pings, response evaluation, deployment interaction, automatic presentation, and camera state are combat concerns.

Recommended pickup order:

1. Finish and sign off `V2-STAGE-004` with no tactical-guidance scope expansion.
2. Pick up the approved `V2-COMBAT-004A` production contract/architecture slice against the finished stage/encounter seam.
3. Complete the Foundation behavior prerequisites in order:
   - [`V2-COMBAT-002`](https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8) — useful objective/stage-shaped enemy pressure after `V2-STAGE-004`; it may proceed while the approved contract is being locked.
   - [`V2-PROG-012`](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596) — autonomy/refusal threshold behavior; must complete before collision-order implementation.
   - [`V2-COMBAT-003`](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8) — deterministic collision order and reason-bearing behavior; follows `V2-PROG-012`.
   - [`V2-DIRECTIVE-002`](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba) — identity-sensitive interpretation of a shared influence; follows `V2-COMBAT-003`.
4. Coordinate the one-readiness-surface information architecture with [`V2-INFRA-004`](https://app.notion.com/p/339c3d1ede928133b08af6877b4b5be3). `INFRA-004` owns consolidation of Directive, intel, loadout, fear, morale, and readiness; `COMBAT-004` owns tactical deployment rules and board interaction.
5. Implement `V2-COMBAT-004B` tactical field/preparation, `004C` asynchronous guidance, `004D` readability/report, then `004E` production tuning/promotion.
6. Keep broad topology/content variety in later Realm expansion: [`V2-STAGE-101`](https://app.notion.com/p/339c3d1ede92816c9e8ee8b897441a0a) and [`V2-STAGE-102`](https://app.notion.com/p/339c3d1ede92810caf85edeed948513b). The first production generator still must meet its tactical acceptance metrics, but Realm ecology breadth does not block promotion.

Established rails should be reused: [`V2-COMBAT-001`](https://app.notion.com/p/339c3d1ede9281aca40fd9c2f802d385), [`V2-EMOTION-001`](https://app.notion.com/p/339c3d1ede92818897cbe53e9773eabb), and [`V2-PROG-010`](https://app.notion.com/p/339c3d1ede9281e4a6f2e32c2d2e122d) are Done. `V2-PROG-012` does not block `V2-COMBAT-004A` contract design, but it **does** block completion of `V2-COMBAT-003` and therefore the full guidance implementation.

## 19. Risk register

| Risk | Impact | Mitigation / gate |
|---|---|---|
| Guidance becomes direct control | Breaks Echo autonomy and player fantasy | Additive arbiter weights only; no exact path/action injection; identity-competition tests |
| New response system duplicates identity logic | Conflicting behavior and unreadable tuning | Response adapter consumes ActorStateMachine outputs and existing bonds/emotion; no new obedience stat |
| `FlowRuntime` grows further | High defect and integration cost | Put algorithms in pure services; FlowRuntime only coordinates and logs |
| Board validation causes retries/performance spikes | Slow encounter entry | Bounded attempts, per-attempt namespaces, deterministic safe fallback, batch timing gate |
| Board variety remains cosmetic | Repeated play feels same | Small topology-profile vocabulary plus measurable route/choke/exposure distributions |
| Hazards become unavoidable or visually noisy | Unfair deaths and low clarity | Minimum-danger validation; floor treatment + icon + legend; hazard-off batch comparison |
| Pings become optimal on cooldown | Removes tactical judgment | All-charge spend, scope costs, unresolved block, mode/board playtest matrix |
| Pings are too weak to notice | Feature feels cosmetic | Structured first-action match telemetry and 70% visible-change gate |
| Pings overwhelm Directives/identity | Echoes feel like units | Influence caps, response scaling, same-seed identity comparisons |
| Asynchronous UI skips/duplicates turns | Misread combat or desync | Monotonic `presentation_id`, de-dup queue, next dispatch only after animation completion |
| Speed changes deterministic outcome | Replay failure | Speed local to UI duration; replay tests across all three speeds |
| Input during animation targets stale state | Invalid recipients/subjects | Core revalidation on every confirm; invalid action consumes no charge |
| Duplicate Echo selection returns | Confusing preparation | `CombatPreparationPanel` is the only visible party representation; EchoBar and actor/initiative tokens hidden; board shows neutral numbered slot occupancy only; UX task test |
| Pure guidance boundary is bypassed | Hidden mutation, replay drift, recipient timing defects | Services return copied state + events; FlowRuntime alone assigns; input-immutability and post-turn-removal tests |
| Canonical PROTECT carry path remains missing | Objective does not match authored mode or prototype acceptance | Implement seeded 60% carryability, burden/mitigation, custody, theft/recovery, and carrier damage before mode acceptance |
| New board path breaks one or more authored modes | Broad regression | Per-mode development allowlist, mode-specific tests, all-current-mode Foundation gate, and feature-off golden fingerprints |
| Objective rules drift during extraction | Win/loss regressions | Keep `CombatState.check_end_condition` authority and existing round-end order; mode regression suite |
| Mid-combat persistence is assumed | Lost state after quit | Explicit no-resume decision and player-facing behavior; separate future save story if required |
| Prototype code leaks into production | Ignored/untracked dependency and brittle build | Repository check forbids production references to `prototypes/keeper_tactical_guidance` |

## 20. Completed and open decision record

Completed July 12, 2026:

- GDD V2.5 and the companion design/architecture references are approved.
- Foundation scope covers all seven currently authored combat modes; prototype evidence is direct for `RECOVER` and `PROTECT`.
- `V2-COMBAT-004A` through `004E` are approved planning slice labels under one `V2-COMBAT-004` database page, not separate story codes; the relevant Notion pages were updated.

Open before the relevant implementation slice:

1. Decide whether `Press the Path` and `Hold the Circle` become canonical Directives, unlock through `V2-DIRECTIVE-002`, or remain playtest-only content.
2. Define the mode-specific tactical-field and guidance requirements for all seven currently authored combat modes.
3. Approve the encounter briefing/deployment subphase inside `flow.encounter`; this remains a major UX-flow decision.
4. Lock the implementation/tuning contract for canonical `PROTECT` carryability—holder burden and the existing class/state mitigation sources—without reopening the authored 60% mechanic unless the GDD and `docs/combat-modes.md` are explicitly amended.
5. Validate whether the existing target battle length of 4–7 minutes remains appropriate for production stages.
6. Decide whether route/chokepoint overlays are developer-only by default or player-toggleable after the briefing.
7. Confirm accessibility requirements for reduced motion, color-independent response states, and compact viewport targeting before UI estimation.

## 21. Definition of architecture-ready

Implementation of a picked-up slice may begin only when:

- the canonical proposal is approved (complete July 12, 2026);
- the open decisions relevant to that slice are resolved or explicitly deferred;
- `V2-COMBAT-004` scope and dependencies are updated in the backlog (complete July 12, 2026);
- snapshot, action, state, seed, config, and logging contracts are accepted;
- feature-off golden fingerprints exist;
- backend phases are split into independently testable stories, each ending in visible/playable verification;
- production remains entirely independent of the ignored prototype directory.
