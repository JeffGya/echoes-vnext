# Echoes vNext — Development Notes

## Development Environment Setup

...

## Saves

...

## Tests (res://tests/)
We maintain lightweight, deterministic core tests under `res://tests/`.
- Tests must not use OS time or RNG.
- Tests should be runnable via the Debug Panel command: `tests`.

## Structured Logging

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

Canonical event namespaces (MVP):
- save.* (e.g., save.load, save.write, save.schema.repair)
- state.transition (required)
- economy.* (see below)
- debug.cmd.* (dev tooling; outside sim tick space)

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
Contracts live in res://contracts/

### State Machines
State machines live in: `res://core/state/`

**Purpose:**
1. Provide a consistent, reusable transition model across Flow / Combat / Actor systems.
2. Enforce deterministic transition logs ("state.transition") with caller-injected tick (`t`).

#### State (base contract)
States are core-safe and must extend `RefCounted`.

Required API:
- `get_id() -> String`
  Stable, deterministic ID for the state. Must not be generated at runtime.

Lifecycle hooks (all deterministic: no OS time; no RNG):
- `enter(ctx: RefCounted, t: int) -> void`
- `exit(ctx: RefCounted, t: int) -> void`

Notes:
- Context (`ctx`) is a `RefCounted` object owned by the caller (e.g., FlowContext, CombatContext later).
- Base State provides no-op defaults; concrete overrides as needed.

#### StateMachine (base contract)
State machines are core-safe and must extend `RefCounted`.

Required behavior:
- Holds a registry of states: transitions occur by `state_id`.
- Tracks current state and only changes state through one canonical choke point: `transition()`.

Required API:
- `register_state(state: State) -> void`
- `set_initial(state_id: String, ctx: RefCounted, logger: StructuredLogger, t: int) -> void`
- `transition(to_state_id: String, ctx: RefCounted, logger: StructuredLogger, t: int, reason := "") -> bool`

Transition order:
1. current.exit(ctx, t) (if current exists)
2. set current = next
3. next.enter(ctx, t)
4. emit `state.transition` log (see below)

#### Transition Logging (required)
Every successful transition MUST emit a log event with:
- `type`: `"state.transition"`
- `t`: injected by caller
- `data` payload (canonical keys):
  - `machine_id`: String (namespaced). Example: `"state.flow"`, `"state.combat"`, `"state.actor.behavior"`
  - `from_state`: String (empty string allowed if none)
  - `to_state`: String
  - `reason`: String (may be empty)

Rules:
- Transitions must never generate their own time: `t` is always injected.
- Payload must remain JSON-safe and deterministic (no Nodes/Objects; only primitives, arrays, dictionaries).
- Missing state IDs must be handled deterministically (log + no crash; transition returns false).
- No-op transitions (to_state == current_state) must log state.transition.noop at debug and return false.


### Snapshot (sim → UI)
Snapshots are the ONLY source of truth for UI rendering.

Shape:
{
  "type": String,         // e.g. "sanctum", "realm_select", "combat_round"
  "meta": Dictionary,     // timestamps, seed refs, debug flags, version
  "data": Dictionary      // state-specific payload
}

Note: Some Flow states may act as **wrapper snapshots**.

### Snapshot: Sanctum economy fields (ECONOMY-001)
Sanctum snapshots must surface economy balances for UI display (UI reads snapshot only).

Snapshot.data keys:
- ase_balance: int
- ekwan_balance: int   (reserved / inert in MVP, but visible)

- Example: `flow.encounter` wraps the current Encounter phase snapshot inside `data`.
- In that case, UI should treat `snapshot.data` as the *inner* snapshot (e.g. `encounter.setup`) and may need to read UI actions from `snapshot.data.actions` instead of `snapshot.actions`.
- This keeps Flow as the screen owner while allowing Encounter phases to drive their own UI payload.

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

## Flow Architecture Addendum (STATE-002)

This section captures canonical Flow decisions derived from the STATE-002 design interview. These rules define macro-loop behavior, save triggers, and progression constraints. They are authoritative for FlowStateMachine and future Encounter integration.

### Canonical Macro Loop

Boot → Splash → Main Menu → Sanctum

From Sanctum:
- Party Manage
- Echo Manage
- Summon
- Realm Select

From Realm Select:
- Stage → Encounter(s) → Resolve → Sanctum

Rules:
- Summoning is only allowed inside Sanctum.
- Resolve always returns to Sanctum.
- Stage and Encounter are venture states; Sanctum is the persistent hub.

---

### Realm Progression Rule

- A player locks into a selected Realm and progresses through its stages sequentially.
- Realm selection may be restricted until all stages in the current Realm are completed.
- RealmSelect state is responsible for validating availability.

---

### Save Trigger Policy (No Manual Save)

Echoes vNext does NOT allow manual saving in MVP.

Save operations are system-driven and must occur only at controlled boundaries.


Approved save triggers:
- New game initialization
- After summoning
- After selecting a realm
- Entering a stage
- After a stage objective resolves (if multiple objectives exist)
- Returning to Sanctum

Rules:
- Not every state writes to save.
- Never save multiple times per tick.
- Saving must remain deterministic and explainable.
- Echo death is permanent in MVP (no rollback system).

---

### Deterministic Accrual at Sanctioned Boundaries
NOTE (design conflict to resolve in ECONOMY-002):
This section currently prohibits offline accumulation for now. The GDD explicitly requires offline accumulation (at a lower rate than online).
Until ECONOMY-002 is implemented, ECONOMY-001 does NOT implement accrual; EconomyService remains a balance ledger only. For accumulation later we want to adhere to the suggestions and calculations in the GDD that does require a live counter of ase being counted. We need to determine how we deal with that in a deterministic safe way. It is more important that the game feels alive and in the moment.
We will update this section during ECONOMY-002 to align with the chosen source of truth.


All accrual, drift, or periodic effects must be deterministic and applied only at sanctioned Flow boundaries.

#### Rules

1) No OS time
- Core must never call OS time APIs (e.g., DateTime, system clock, unix time) for progression.
- No "time since last login" logic.
- No background/offline accumulation.

2) Accrual is boundary-applied, not continuous
- Economy or Emotion drift does NOT run every frame.
- It must be executed explicitly at approved boundaries owned by Flow.

3) Sanctioned boundaries
Accrual/drift may only be applied at the same boundaries approved for system-driven saves:
- New game initialization
- After summoning
- After selecting a realm
- Entering a stage
- After a stage objective resolves
- Returning to Sanctum

4) Use sim_tick deltas
- Each system that applies accrual must persist a `last_applied_tick` in save.
- When applying:
  - `delta_ticks = current_sim_tick - last_applied_tick`
  - Apply bounded, deterministic math.
  - Update `last_applied_tick`.
- If `last_applied_tick == current_sim_tick`, the operation must be a deterministic no-op.

5) Exactly-once per boundary
- Accrual must be safe against duplicate calls within the same tick.
- Systems must guard against double-application.

6) No cascading saves
- Applying accrual must not trigger multiple saves within the same tick.
- Flow remains the authoritative owner of when a save actually occurs.

This rule exists to preserve determinism, replayability, and simulation explainability.

---

### First Boot Branching

Main Menu → Continue must branch deterministically:

- If first boot: initialize minimal save state and proceed to Sanctum.
- If save exists: load and continue.


Future expansions (cutscene/tutorial) must remain FlowState transitions, not UI shortcuts.

---

## Encounter Terminology (Objective vs Encounter Resolution)

To avoid confusion between design-level objectives and runtime encounter phases, Echoes vNext uses the following layered model:

Flow (macro)
    ↓
Stage (objective progression)
    ↓
Objective (what a stage node represents)
    ↓
EncounterStateMachine (only if the objective requires phased resolution)

### Definitions

- **Objective**: A design-level concept that describes what a stage node represents (e.g. combat, shrine, event, boss, treasure, narrative choice).
- **EncounterStateMachine**: A runtime phase scaffold used to *resolve* certain objectives deterministically (Setup → Blessing → Rounds → Resolution → Aftermath).

Not every Objective requires an EncounterStateMachine. Simple objectives may be resolved directly by Stage without entering Encounter phases.

### Resolution Mode

When an Objective is resolved via EncounterStateMachine, the EncounterContext should carry a **resolution_mode** (not "objective type") to describe which resolution logic is plugged into the phase scaffold.

Examples:
- ObjectiveType: `shrine` → resolution_mode: `purify_shrine`
- ObjectiveType: `combat` → resolution_mode: `combat`
- ObjectiveType: `event` → resolution_mode: `guide_spirit`

Rule:
- Treat "Encounter" as a *phase resolution container*, not as a content label.
- `resolution_mode` is a stable ID that may appear in snapshots and saves; avoid renaming once used.

### Encounter Contracts (STATE-003)

Encounter state machines live in: `res://core/state/encounter/`

Contracts:
- Machine id: `state.encounter`
- Phase ids (MVP scaffold):
  - `encounter.setup`
  - `encounter.blessing`
  - `encounter.rounds`
  - `encounter.resolution`
  - `encounter.aftermath`

Snapshot contract:
- Encounter states write the current snapshot into `EncounterContext.phase_snapshot`.
- Flow passes that snapshot through to UI while in `flow.encounter`.

Action contracts:
- `encounter.advance` (UI → core)
  - must include `to` (String) to indicate the next encounter phase.
- `encounter.complete` (UI → core)
  - signals the encounter is done; Flow decides where to go next (MVP: Resolve).

Logger ownership:
- State `enter(ctx, t)` does not receive a logger.
- The caller that owns `t` (currently AppRoot) is responsible for starting machines and calling `transition(..., logger, t, reason)`.
- Encounter machine bootstrap happens when Flow enters `flow.encounter`:
  - `FlowEncounterState` ensures `EncounterContext` + `EncounterStateMachine` exist and sets defaults (including `resolution_mode`).
  - `AppRoot` detects `flow.encounter` and calls `EncounterStateMachine.start(ctx, logger, t)` once if needed.

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

### Tooling logs outside sim time (DebugCmd)
Some dev tooling events are logged outside the simulation tick space using a negative tick.

- Debug command events use `t = -1` (rendered as `t:-` by LogFormatter).
- These events are NOT simulation progression and must not consume sim ticks.

Canonical types:
- debug.cmd.in   (payload: { cmd })
- debug.cmd.out  (payload: { line })
- debug.cmd.err  (payload: { line })

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

### Economy log event types (ECONOMY-001)
Economy changes must be explainable and replay-friendly. Use these canonical types:

- economy.ase.add
- economy.ase.spend
- economy.ase.add_denied (invalid amount)
- economy.ase.spend_denied (insufficient funds)

Reserved / symmetric (Ekwan is inert in MVP but present):
- economy.ekwan.add
- economy.ekwan.spend
- economy.ekwan.add_denied
- economy.ekwan.spend_denied

Payload rules:
- Must include: amount, before, after (if successful), reason
- Must be JSON-safe (no Nodes/Objects)
- Severity policy:
  - emit as info normally
  - emit as debug when logger level is DEBUG (to include "reason" in formatted output)

See README_DEV.md → Structured Logging (CORE-004) for architectural intent and usage guidelines.
