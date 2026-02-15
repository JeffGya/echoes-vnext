# Echoes vNext — Development Notes

## Development Environment Setup

...

## Saves

...

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

# Echoes vNext — Conventions & Contracts

## Naming conventions

### Folders
- snake_case (e.g., core/state, ui/screens)

### Scripts
- PascalCase.gd for classes (e.g., FlowStateMachine.gd)
- One primary class per file whenever possible.

### Data files
- snake_case.json (e.g., actor_templates.json, realms.json)

### IDs
- snake_case strings (e.g., vale_of_dust, purify_shrine)

## Code boundaries (non-negotiable)

### Core simulation (res://core)
- Deterministic logic only.
- No direct UI node references.
- Outputs snapshots + logs.

### UI layer (res://ui)
- Renders snapshots.
- Sends actions.
- Must not read internal sim variables directly.

---

## Randomness Policy (Determinism)
- All randomness must derive from CampaignSeed
- Use dot-separated seed paths (case-sensitive) e.g. campaign.realm.01.stage.03.encounter.01.spawn.enemy.02
- Forbidden: randomize(), rand(), randf(), and global randomness.
- Forbidden: creating RandomNumberGenerator.new() directly in systems. (Only allowed inside CampaignSeed or future RandomProvider wrapper.)
- Each subsystem must request an RNG via:
  - CampaignSeed.get_rng(path) or
  - CampaignSeed.get_rng_from(parent_seed, path)

---

## Contracts
Contracts live in res://core/contracts/

### Snapshot (sim → UI)
Snapshots are the ONLY source of truth for UI rendering.

Shape:
{
  "type": String,         // e.g. "sanctum", "realm_select", "combat_round"
  "meta": Dictionary,     // timestamps, seed refs, debug flags, version
  "data": Dictionary      // state-specific payload
}

### Action (UI → sim)
Action ID format: domain.subdomain.verb_noun
UI triggers actions by ID, not by calling internal functions directly.

Shape:
{
  "id": String,           // e.g. "sanctum.summon_echo"
  "label": String,        // UI-facing label
  "enabled": bool,        // UI state
  "tooltip": String,      // explain why enabled/disabled
  "payload": Dictionary   // parameters (optional)
}

### LogEvent (sim → UI/QA)
Logs are structured, stable, and testable.

Shape:
{
  "t": int,               // monotonic tick or timestamp
  "sev": String,          // "info" | "debug"
  "type": String,         // e.g. "state.transition", "combat.attack"
  "msg": String,          // short human-readable line
  "data": Dictionary      // optional detailed payload
}

### Config
Configs live in res://data/ there are treated as read-only inputs.
Schema changes are additive. Migrations will come later if needed. 

Shape: 
{
  "schema_version": 1,    // Only int allowed.
  "data": {}              // Data must be a Dictionary
}



---

## Save Schema Versioning & Migrations
- Saves are JSON and must include schema_version (int).
-	Never change the meaning of an existing field without bumping schema_version.
-	Prefer additive changes:
    -	add new fields with safe defaults
    -	keep old fields until a migration is in place
-	Migrations must be explicit and ordered:
    -	migrate_v1_to_v2(data: Dictionary) -> Dictionary
    -	migrate_v2_to_v3(...)
-	SaveService.load_from_file() must: 
    -	parse JSON
    -	validate schema version
    -	run migrations (when implemented)
    -	return a valid vLatest dictionary or {}

### Save Files & Crash Safety
-	Default save path: user://saves/slot_01.json
-	Writes must be crash-safe:
	-	write to *.tmp
	-	rename to final

---

## Logging (StructuredLogger)

We use structured logs for determinism validation, debugging, and future replay tooling.

### LogEvent shape (canonical)
Every log entry must be a JSON-safe Dictionary with this shape:

{
  "t": int,
  "sev": "String"
  "type": String,
  "msg": String,
  "data": Dictionary
}

### Timestamp (`t`)
`t` is a deterministic simulation tick provided by the caller.

- The logger does NOT generate timestamps.
- The logger does NOT call OS time APIs.
- For early foundation work, `t` comes from a temporary `sim_tick` owned by AppRoot.
- IMPORTANT: When Flow/Encounter state machines are implemented, they will become the
  authoritative owner of `sim_tick`. AppRoot ticking must be replaced at that point.

### Rules
- No `print()` in core systems for meaningful events — use StructuredLogger instead.
- `type` must be namespaced (e.g. "state.transition", "combat.action").
- `msg` is a short human-readable summary.
- `data` is structured payload (always a Dictionary; may be empty).
- Payload must be JSON-safe (no Nodes/Objects; only primitives, arrays, dictionaries).
- Logger must deep-copy `data` before storing it to prevent mutation side effects.
- Logger must never maintain its own internal tick counter; time is always injected by the caller.
- All state machine transitions must emit a `state.transition` log.
- Core services (save, flow, combat, grid, actors) must log meaningful state changes.
- Logger level filtering (off/info/debug) must not affect simulation determinism.
- Log formatting is a UI concern; stored logs must remain structured dictionaries.

See README_DEV.md → Structured Logging (CORE-004) for architectural intent and usage guidelines.
