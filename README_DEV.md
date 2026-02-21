# Echoes vNext — Dev Structure

This project is intentionally split into:
- **Core simulation** (deterministic, testable, no UI dependencies)
- **UI layer** (renders snapshots + sends actions, never reads internal sim state)

## Folder map

### res://contracts/

### res://core/
*Deterministic game logic, services, and models (no UI dependencies).*
- CampaignSeed.gd

- core/runtime/ — Authoritative runtime owners (tick + logger + dispatch)
  - FlowRuntime.gd

- core/state/ — State machine base + Flow/Encounter machines + states
  - State.gd
  - StateMachine.gd

  - core/state/flow/
    - FlowContext.gd
    - FlowStateIds.gd
    - FlowStateMachine.gd
    - core/state/flow/states/
      - boot/
        - FlowSplashState.gd
        - FlowMainMenuState.gd
      - sanctum/
        - FlowSanctumState.gd
        - FlowPartyManageState.gd
        - FlowEchoManageState.gd
        - FlowRealmSelectState.gd
        - FlowSummonState.gd
      - venture/
        - FlowEncounterState.gd
        - FlowStageMapState.gd
        - FlowStageState.gd
      - FlowResolveState.gd

  - core/state/encounter/
    - EncounterContext.gd
    - EncounterResolutionModes.gd
    - EncounterStateIds.gd
    - EncounterStateMachine.gd
    - core/state/encounter/states/
      - EncounterSetupState.gd
      - EncounterBlessingState.gd
      - EncounterRoundsState.gd
      - EncounterResolutionState.gd
      - EncounterAftermathState.gd

- core/economy/ — Economy service + systems (ase, ekwan reserved)
  - EconomyService.gd

- core/log/
  - StructuredLogger.gd
  - LogFormatter.gd

- core/save/ — Save/load schema + persistence (future migrations)
  - SaveSchema.gd
  - SaveService.gd

- core/config/ — JSON configs + validation helpers
  - JsonFileLoader.gd
  - ConfigValidator.gd
  - ConfigService.gd

- core/actors/ — Actor model (Echoes, Enemies, Allies, Structures), stats, behaviors, directives
- core/grid/ — Board model, placement rules, movement, distance helpers
- core/combat/ — Combat loop, action resolver, objectives, snapshot builders
- core/realms/ — Realm + Stage models, generator, rewards, progression service
- core/sanctum/ — Sanctum state, roster, summoning, party selection

### res://ui/
Rendering only. UI must be snapshot-driven.
- AppRoot.gd
- AppRoot.tscn
- UISnapshotRenderer.gd
- ui/screens/ — High-level screens (Sanctum, Realm Select, Combat, Resolve, Debug)
- ui/components/ — Reusable UI components (ActionList, LogView, Panels)
    - DebugPanel.gd

### res://data/
Game data assets (JSON): actor templates, realm definitions, balance knobs.
- res://data/balance.json
- res://data/actors.json
- res://data/realms.json

### res://tests/
Lightweight deterministic tests for core modules.
- Run via Debug Panel: `tests`
- Tests must not use OS time or RNG.

- CoreTestRunner.gd
- EconomyTests.gd

## Core rule
UI renders **snapshots** and triggers **actions**.
UI must never depend on internal simulation variables directly.

---

## Flow Layer (STATE-002 Baseline)

The FlowStateMachine owns the macro progression of the game. AppRoot only forwards UI actions and renders snapshots.

Flow responsibilities:
- Own the authoritative simulation tick (`sim_tick`).
- Validate and execute high-level transitions.
- Produce Flow-level snapshots.
- Decide when saving is triggered (see CONVENTIONS.md → Flow Architecture Addendum).

Flow is NOT a screen router.
It is a deterministic state machine that governs game progression.

### Current Flow States (MVP baseline)

Boot / Splash / Main Menu
Sanctum (hub)
PartyManage / EchoManage / Summon
RealmSelect
Stage / Encounter
Resolve

All transitions must:
- Emit `state.transition` logs.
- Produce a snapshot for UI.
- Be deterministic and seed-consistent.

---

## Encounter Layer (STATE-003 Baseline)

EncounterStateMachine is a reusable phased-resolution scaffold used by certain Stage Objectives.

Layering model:
Flow (macro) → Stage (objective progression) → Objective (design intent) → EncounterStateMachine (phased resolution, when needed)

Key rules:
- Encounter is not the objective itself; it is the deterministic container used to resolve an objective.
- Objectives select/inform an encounter `resolution_mode` (a stable string ID).
- Encounter phases are deterministic and write their current snapshot into `EncounterContext.phase_snapshot`.
- While in `flow.encounter`, Flow passes the encounter snapshot through to UI.

Bootstrap + routing (current MVP):
- `FlowEncounterState` creates/holds `EncounterContext` + `EncounterStateMachine` in `FlowContext` and sets defaults (including `resolution_mode`).
- `FlowRuntime` (core/runtime) owns the logger + tick and bootstraps the encounter machine when entering `flow.encounter`.
- `FlowRuntime` routes `encounter.advance` and `encounter.complete` actions.

UI never talks to EncounterStateMachine directly.

MVP encounter phases:
- `encounter.setup` → `encounter.blessing` → `encounter.rounds` → `encounter.resolution` → `encounter.aftermath`

Note:
- Combat logic is not implemented here. Combat-specific behavior plugs into these phases later under COMBAT backlog tasks.

## Determinism
- Campaigns are driven by a single root seed.
- Seeds are derived via dot-separated paths (case-sensitive).
- UI does not own randomness.
- No global randomness functions are used.

## Saves
Default save path: user://saves/slot_01.json
Saves are JSON and include schema_version for future migrations.

Game has one single save slot forever. No multiple saves allowed.
See CONVENTIONS.md for more about saving and making sure it works properly.

## Economy (ECONOMY-001)

Economy is centralized in `res://core/economy/EconomyService.gd`.

MVP rules:
- Ase is the primary currency.
- Ekwan is present as a reserved/inert field (default 0) for future systems (post-MVP).
- All balance mutations must go through EconomyService (single choke point).
- Sanctum snapshots surface:
  - `ase_balance` (int)
  - `ekwan_balance` (int, reserved)

Accrual / offline accumulation is NOT implemented in ECONOMY-001.

### ECONOMY-002
- Offline accrual is applied when the player presses Continue (session start), not at boot/splash.
-	FlowRuntime owns the save flush via save_request (single choke point).
-	Online “bank timer” settlements do not save. (we shal see if after gameplay tests it makes sense to still do that for now we follow this.)

## Structured Logging (CORE-004)

Echoes vNext uses a deterministic StructuredLogger located in `res://core/log/StructuredLogger.gd`.

Purpose:
- Determinism validation
- Debugging complex state machines
- Future replay tooling
- Snapshot inspection

Key rules:
- Logs are structured dictionaries (see LogEvent contract in CONVENTIONS.md).
- Logs use a monotonic simulation tick (`t`) injected by the caller.
- Logger never generates its own time.
- No OS timestamps.
- Core systems must not use `print()` for meaningful events.
- All state transitions must log via `state.transition`.
- Event types must be namespaced (e.g., `save.load`, `combat.attack`).

The UI may format logs for readability (see LogFormatter), but the stored log structure must remain JSON-safe and deterministic.

---
## Debug Panel commands (dev tooling)

The Debug Panel is a dev-only helper for running core tests and mutating balances during development.
Commands are logged as `debug.cmd.*` events with `t:-` (outside simulation tick space).

Available commands:
- `tests` — run core test suite
- `ase show`
- `ase add <amount> [reason...]`
- `ase spend <amount> [reason...]`
- `ekwan show`
- `ekwan add <amount> [reason...]`
- `ekwan spend <amount> [reason...]`

Note: these commands must not advance simulation tick and must not introduce non-deterministic behavior.
---

## Snapshot Emission Model (STATE-004)

Snapshots are emitted deterministically on successful Flow transitions.

Authoritative owner:
- `FlowRuntime` (core/runtime) owns:
  - simulation tick (`t`)
  - logger
  - FlowContext
  - FlowStateMachine
  - dispatch(action) → snapshot

State machines:
- Mutate context.
- Log transitions.
- DO NOT emit UI snapshots directly.

Flow responsibilities:
- After every successful Flow transition:
  - Rebuild snapshot from current state.
  - Validate snapshot structure.
  - Return snapshot to UI layer.

Encounter integration:
- While in `flow.encounter`, Flow wraps the active Encounter phase snapshot.
- The Encounter phase snapshot lives in `EncounterContext.phase_snapshot`.
- Flow snapshot structure:

  {
    "type": "flow.encounter",
    "meta": {...},
    "data": <encounter phase snapshot>
  }

UI layer:
- Renders only the snapshot returned from `FlowRuntime`.
- Never reads internal FlowContext or EncounterContext directly.

Snapshot contract:
- Must include: `type`, `meta`, `data`.
- Must be JSON-safe.
- Must not contain null values.
- Exactly one snapshot is emitted per successful Flow transition.

This guarantees:
- UI decoupling.
- Deterministic replay potential.
- Extensibility for Player Influence Systems, Sanctum dashboards, Grid, and Combat rendering.