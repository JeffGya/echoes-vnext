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