# Echoes vNext — Dev Structure

This project is intentionally split into:
- **Core simulation** (deterministic, testable, no UI dependencies)
- **UI layer** (renders snapshots + sends actions, never reads internal sim state)

## Folder map

### res://contracts/

### res://core/
*Deterministic game logic, services, and models.*
- CampaignSeed.gd
- *core/state/ — State machines (Flow + Encounter + Actor/Behavior hooks)*
    - State.gd
    - StateMachine.gd
    - *core/state/flow*
      - FlowContext.gd
      - FlowStateIds.gd
      - *core/state/flow/states*
         - *core/state/flow/states/boot*
            - FlowSplashState.gd
            - FlowMainMenuState.gd
        - *core/state/flow/states/sanctum*
            - FlowSanctumState.gd
            - FlowPartyManageState.gd
            - FLowEchoManageState.gd
            - FlowRealmSelectState.gd
            - FlowSummonState.gd
        - *core/state/flow/states/venture*
            - FlowEncounterState.gd
            - FlowStageMapState.gd
            - FlowStageState.gd
        - FlowResolveState.gd
    - *core/state/encounter*
      - EncounterContext.gd
      - EncounterResolutionModes.gd
      - EncounterStateIds.gd
      - EncounterStateMachine.gd
      - *core/state/encounter/states*
         - EncounterSetupState.gd
         - EncounterBlessingState.gd
         - EncounterRoundsState.gd
         - EncounterResolutionState.gd
         - EncounterAftermathState.gd
        

- *core/actors/ — Actor model (Echoes, Enemies, Allies, Structures), stats, behaviors, directives*
- *core/grid/ — Board model, placement rules, movement, distance helpers*
- *core/log/*
    - LogFormatter.gd
    - StructuredLogger.gd
- *core/combat/ — Combat loop, action resolver, objectives, snapshot builders*
- *core/realms/ — Realm + Stage models, generator, rewards, progression service*
- *core/sanctum/ — Sanctum state, roster, summoning, party selection*
- *core/save/ — Save/load schema, persistence service, future migrations*
    - SaveSchema.gd
    - SaveService.gd  
- *core/config/ — JSON configs + validation helpers*
    - JsonFileLoader.gd
    - ConfigValidator.gd
    - ConfigService.gd
    

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
Determinism + unit-style tests for core modules.

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
- `AppRoot` owns the logger + tick and bootstraps the encounter machine when entering `flow.encounter`.
- `AppRoot` routes `encounter.advance` and `encounter.complete` actions.

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