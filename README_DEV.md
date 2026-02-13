# Echoes vNext — Dev Structure

This project is intentionally split into:
- **Core simulation** (deterministic, testable, no UI dependencies)
- **UI layer** (renders snapshots + sends actions, never reads internal sim state)

## Folder map

### res://core/
Deterministic game logic, services, and models.

- core/state/ — State machines (Flow + Encounter + Actor/Behavior hooks)
- core/actors/ — Actor model (Echoes, Enemies, Allies, Structures), stats, behaviors, directives
- core/grid/ — Board model, placement rules, movement, distance helpers
- core/combat/ — Combat loop, action resolver, objectives, snapshot builders
- core/realms/ — Realm + Stage models, generator, rewards, progression service
- core/sanctum/ — Sanctum state, roster, summoning, party selection
- core/save/ — Save/load schema, persistence service, future migrations
- core/config/ — JSON configs + validation helpers

### res://ui/
Rendering only. UI must be snapshot-driven.

- ui/screens/ — High-level screens (Sanctum, Realm Select, Combat, Resolve, Debug)
- ui/components/ — Reusable UI components (ActionList, LogView, Panels)

### res://data/
Game data assets (JSON): actor templates, realm definitions, balance knobs.

### res://tests/
Determinism + unit-style tests for core modules.

## Core rule
UI renders **snapshots** and triggers **actions**.
UI must never depend on internal simulation variables directly.