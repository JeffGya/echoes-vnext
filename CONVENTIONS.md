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

### Campaign seed lifecycle (SANCTUM-002)

Echoes vNext runs on a single persisted campaign root seed.

Storage (save):
- campaign.seed_root: String
- campaign.seed_source: String  // "random" | "debug" | "repair" | "imported" (future)

Rules:
- New Game:
  - generates a new campaign.seed_root exactly once
  - stores it in save and sets campaign.seed_source = "random"
- Continue:
  - loads campaign.seed_root from save
  - never regenerates or changes it automatically
- Save repair:
  - if campaign.seed_root is missing, set it to a deterministic “repair seed” derived from existing save fields (fallback: “DEFAULT_SEED” only if nothing usable exists) and campaign.seed_source = "repair"
  - repair must never generate a random seed (prevents nondeterministic migrations)

Debug tooling (dev only):
- seed show / seed set / seed reset exist only in the Debug Panel (not main game UX)
- seed set <string>: updates campaign.seed_root and marks seed_source = "debug" (no gameplay UI exposure)
- seed reset <string>: sets seed_root and clears dependent summon dev state (see Sanctum summoning notes below)

### Seed path namespaces (SANCTUM-002)

All derived RNG must use dot-separated, case-sensitive seed paths under the campaign root seed.

Reserved namespaces:
- campaign.starter.*   // free starter summon on New Game
- campaign.summon.*    // paid summons from Sanctum Summon screen

Rules:
- Namespaces must never overlap.
- Stored generated records should include their seed_path for audit/replay.

#### Stored fields
- Generated Echo records must include `seed_path` and `summon_index`.
- Save must persist `campaign.seed_root`, `campaign.seed_source`, `sanctum.summon_count`, and `sanctum.roster`.

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

### Wrapper snapshots (Flow)
Some Flow states may act as **wrapper snapshots** and embed an inner snapshot inside `data`.

Example:
- `flow.encounter` wraps the current Encounter phase snapshot inside `data`.
- In that case, UI should treat `snapshot.data` as the *inner* snapshot (e.g. `encounter.setup`) and may need to read UI actions from `snapshot.data.actions` instead of `snapshot.actions`.
- This keeps Flow as the screen owner while allowing Encounter phases to drive their own UI payload.

### Snapshot: Sanctum economy fields (ECONOMY-001)
Sanctum snapshots must surface economy balances for UI display (UI reads snapshot only).

Snapshot.data keys:
- ase_balance: int
- ekwan_balance: int   (reserved / inert in MVP, but visible)

### Snapshot.data keys (Sanctum hub, SANCTUM-001)
- sanctum_name: String (empty until confirmed)
- sanctum_name_suggested: String (deterministic suggestion)
- roster_count: int (MVP placeholder)
- ase_rate_per_hour_hint: float (rate hint only, not a balance prediction)
- party_slots: Array[Dictionary] — confirmed party for display only: [{ name, level, rank }] (no IDs)

Action slots (UI-002 — slot-keyed Dictionary, Feb 2026 standard):
```
{
  "nav.party_manage": { "type": "flow.go_state", "to": "flow.party_manage", "label": "Manage Party",  "slot": "nav.party_manage" },
  "nav.echo_manage":  { "type": "flow.go_state", "to": "flow.echo_manage",  "label": "Manage Echoes", "slot": "nav.echo_manage"  },
  "nav.realm_select": { "type": "flow.go_state", "to": "flow.realm_select", "label": "Select Realm",  "slot": "nav.realm_select" },
  "nav.summon":       { "type": "flow.go_state", "to": "flow.summon",       "label": "Summon Echo",   "slot": "nav.summon"       },
  "cta.enter_stage":  { "type": "flow.go_state", "to": "flow.stage_map",    "label": "Enter Stage",   "slot": "cta.enter_stage",
                        "disabled": true/false }  // disabled when realm_id == ""
}
```

**Shell-cached nav pattern (UI-002)**
SanctumShell owns the persistent nav bar — it is NOT injected into every sanctum-family snapshot.
- On `flow.sanctum` snapshots: shell caches all `nav.*` and `cta.*` slots from `snap.actions` into `_cached_nav` and rebuilds the NavBar.
- For all other sanctum-family types (flow.summon, flow.party_manage, etc.): NavBar renders from `_cached_nav` unchanged.
- Cache is safe: `cta.enter_stage` (only conditional action) can only change via `flow.realm_select`, which always returns to `flow.sanctum` before the player sees the nav again.
- This keeps SummonState, PartyManageState, EchoManageState, RealmSelectState free from nav injection.

### Snapshot.data keys (Party Manage, SANCTUM-003)
- title: String
- max_party_size: int (from `balance.json data.sanctum.party_max_size`; default 5)
- active_party_ids: Array[String] — INTERNAL transient pending selection (FlowContext.pending_party_ids); initialized from `save.sanctum.active_party_ids` on enter
- roster: Array[Dictionary] — one row per echo: `{ id, name, rank, in_party: bool, level? }`

Action slots:
- `back` → `flow.go_state` to `flow.sanctum`
- `primary` → `sanctum.party.confirm` with `enabled: bool` (true when pending ≥ 1)

Per-row actions (dispatched directly by UI row, NOT in snapshot.actions):
- `{ "type": "sanctum.party.toggle", "payload": { "echo_id": String } }`
  - Adds echo if not in pending and `pending.size() < max_party_size`
  - Removes echo if already in pending (idempotent toggle)

Transient FlowContext field:
- `pending_party_ids: Array` — initialized from `save.sanctum.active_party_ids` on enter(); never written to save; discarded on exit()

### Action (UI → sim)
Action type format: domain.subdomain.verb (with optional qualifiers)
Examples: flow.go_state, economy.ase.spend, sanctum.name.confirm

**Action placement (Feb 2026 — required for bespoke screens)**
- Screens must not rely on generic button lists.
- Snapshots expose actions in **named slots** so UI can place buttons independently.
- Generic action rendering is fallback only.

Canonical shape:
{
  "type": "String",          // e.g. "flow.go_state", "economy.ase.spend"
  "label": "String",         // optional UI label
  "to": "String",            // optional (flow.go_state)
  "amount": 0,               // optional (economy.*)
  "reason": "String",        // optional debug/dev reason text
  "payload": {}              // optional extra params
}

Snapshot.actions shape (preferred):
{
  "actions": {
    "primary":   { ...action... },
    "secondary": { ...action... },
    "back":      { ...action... },
    "reroll":    { ...action... }
  }
}

Rules:
- `snapshot.actions` is a Dictionary keyed by slot name → action Dictionary.
- Bespoke screens bind to known slots and emit `action_requested(action: Dictionary)`.
- AppRoot listens for `action_requested` and forwards to runtime dispatch.
- Fallback generic renderer MAY iterate `snapshot.actions.values()` if a bespoke screen is not available.

### Bespoke Screen Contract (UI-001)

All snapshot-driven screens must follow this interface. It is the single standard for how UI screens receive state and send actions.

**Entry point**
Every bespoke screen must expose:
```
func set_snapshot(snap: Dictionary) -> void
```
AppRoot calls this whenever a new snapshot arrives. The screen reads `snap["data"]` for display values and `snap["actions"]` for named action slots. It must not store references to sim objects.

**Exit point**
Every bespoke screen must declare:
```
signal action_requested(action: Dictionary)
```
All user interactions that need to reach the sim are emitted through this signal. AppRoot connects it and forwards to `FlowRuntime.dispatch()`. Screens never call `dispatch()` directly.

**Action slots**
`snap["actions"]` is a **slot-keyed Dictionary** — never an Array:
```
{
  "nav.back":   { "type": "flow.go_state", "to": "flow.sanctum", "slot": "nav.back", ... },
  "cta.summon": { "type": "sanctum.summon", "slot": "cta.summon", ... }
}
```
Screens bind buttons to named slots independently. There is no prescribed display order from the snapshot. Array-style action lists are **legacy / fallback only** (UISnapshotRenderer and un-migrated states).

**Per-row actions**
Row-level interactions (e.g. party toggle per echo row) are dispatched directly by the UI row component — they are NOT listed in `snap["actions"]`.

**Hard prohibitions**
- No screen may read `FlowContext`, `FlowRuntime`, `SanctumState`, `SaveService`, or any other sim internal directly.
- No screen may call `dispatch()` directly.

**AppRoot responsibilities**
AppRoot maps `snapshot.type` to the correct bespoke scene, swaps the active screen, calls `set_snapshot()`, and connects the `action_requested` signal. For unknown snapshot types it falls back to `UISnapshotRenderer`.

**Template**
All new screens start from `res://ui/screens/ScreenTemplate.gd`. It enforces snapshot structure via asserts and types `actions` as a Dictionary.

---

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
- Never change the meaning of an existing field without bumping schema_version.
- Prefer additive changes:
    - add new fields with safe defaults
    - keep old fields until a migration is in place
- Migrations must be explicit and ordered:
    - migrate_v1_to_v2(data: Dictionary) -> Dictionary
    - migrate_v2_to_v3(...)
- SaveService.load_from_file() must: 
    - parse JSON
    - validate schema version
    - run migrations (when implemented)
    - return a valid vLatest dictionary or {}

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
- Summoning is only allowed inside the Sanctum hub (including the Summon screen).
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
- After successful summoning (paid or starter)
- After selecting a realm
- Entering a stage
- After a stage objective resolves (if multiple objectives exist)
- Returning to Sanctum
- After confirming Sanctum name
- After confirming party selection (`sanctum.party.confirm`)

Rules:
- Not every state writes to save.
- Never save multiple times per tick.
- Saving must remain deterministic and explainable.
- Echo death is permanent in MVP (no rollback system).

### Starter summon (SANCTUM-002)

On New Game / first boot setup, the Keeper receives exactly one free starter Echo.
- Starter uses reserved seed namespace: `campaign.starter.0`
- Paid summons use reserved seed namespace: `campaign.summon.<summon_count>`
- Summon generation is deterministic from `campaign.seed_root` + `seed_path` (dot-separated, case-sensitive)

---
### Summoning contract (SANCTUM-002 / ECONOMY-003)

Core rules:
- Paid summoning is only available in the Sanctum Summon screen.
- Cost is **grade-based** (ECONOMY-003): uncalled=60, called=150, chosen=400 Ase per summon.
- Legacy flat key `ase_cost_per_summon = 60` is kept in `balance.json` as a fallback only.
- Core must **settle before spend** (ECONOMY-002).
- Successful summon is **transactional**:
  1) settle_time
  2) validate funds for selected grade
  3) spend (reason="summon.cost.`<grade>`")
  4) generate Echo via EchoFactory
  5) append to `sanctum.roster`
  6) increment `sanctum.summon_count`
  7) request save (single choke point)

Grade selection:
- Grade defaults to `"uncalled"` every time the player enters the Summon screen.
- Player may select a different grade via `sanctum.grade_select` action.
- Selected grade is stored in `FlowContext.selected_summon_grade` (transient — NOT saved).

Bulk summoning:
- Summon accepts a `count` (MVP: 1–10 UI slider).
- Total cost = `grade_cost * count`.
- Each Echo uses a unique seed path: `campaign.summon.<summon_index>`.

Reveal UX (transient):
- Summon does **not** cause a Flow transition.
- Runtime refreshes the snapshot.
- Newly summoned Echo summaries are placed into a **transient reveal queue** in FlowContext.
- The reveal queue is **NOT saved**.
- UI displays a trading-card overlay to page through reveals and dismiss.

Non-goals (reserved):
- Sanctum upgrades do not affect trait rolls (rarity/grade may be affected later).
- Emotion cost/connection is deferred to EmotionService; summoning records reserve a `generation_context` field for future modifiers.
---

### Economy Accrual & Settlement Model (ECONOMY-002)
Echoes vNext uses a settlement-based economy model.

### Canon Principle
- Canon source: GDD defines the intended spirit and pacing of Ase (time invested + sanctum vitality). vNext defines the architecture to implement it safely.
- If CONVENTIONS and the GDD disagree on economy pacing (or any other rule), we prefer to default to the GDD and document the exception here.
- The Core simulation is the authoritative ledger.
- The UI may predict, but Core commits.
- Ase represents time invested and sanctum vitality (see GDD).
- Economy must feel alive without sacrificing explainability.

#### Online Accrual (Live Settlement Model)
Ase accrues continuously while the game is running, but it is not applied every frame.

Instead, Core uses a settlement model:

##### Settlement Action
Core exposes an internal action:
economy.settle_time { now_unix, source }

Settlement:
1.	Computes elapsed seconds since economy.last_settle_unix
2.	Applies deterministic accrual math
3.	Updates economy.last_settle_unix
4.	Emits structured logs
5.	Does NOT trigger a save

##### Settlement and timer
Settlement must occur:
-	Before any Ase spend
-	At sanctioned Flow boundaries
-	Start bank timer when the “run/session starts” (i.e., first non-menu snapshot)
-	Timer keeps running while the app is running (online)
-	We don’t tie it to Sanctum, because Sanctum isn’t guaranteed to be first forever
-	Sanctum is where it’s most visible, but accrual is global
This allows the game to feel alive while keeping Core authoritative.

#### UI Prediction Rules
The UI may:
- Use last_settle_unix from snapshot for smooth display
- UI may display ~ X Ase gathered p/h using ase_rate_per_hour_hint.
- UI may animate balance display, but must not imply the ledger has changed unless snapshot ase_balance changes.

The UI must NOT:
- Commit Ase values
- Pass earned amounts to Core
- Promise exact deltas to the player


Prediction contract:
- Sanctum snapshots must include `economy.last_settle_unix` and an approximate `ase_rate_hint` so UI prediction uses Core-provided parameters (reduces mismatch risk).

If UI and Core disagree, Core is authoritative.

#### Offline Accrual (Session start (flow.continue) after load only)
Offline accrual is allowed per GDD.

Rules:
-	OS time may be read only when entering a session (on Continue / Start).
-	Offline accrual applies at most once per session.
-	Uses economy.last_offline_unix.
-	Applies a decay curve from 50% → 0 over a capped duration.
-	Must clamp or penalize time anomalies.
-	Must log structured details.

Offline accrual must not run during active play.

#### OS Time Policy
OS time usage is strictly limited:

Allowed:
-	As an input to economy.settle_time
-	At boot/load for offline accrual

Forbidden:
-	Continuous OS-time-driven logic in core loops
-	Frame-based time accumulation
-	Background accrual outside settlement model

All OS time inputs must be:
-	Validated
-	Clamped
-	Logged

Time validation rule:
- Core never trusts timestamps blindly. It must detect negative deltas and extreme forward jumps, apply clamps/penalties, and log `economy.time_anomaly`.

#### Save Discipline
Settlement must:
-	Mutate in-memory save state only
-	Not trigger automatic saves
-	Respect Flow’s save trigger policy

Exactly-once behavior is enforced via:
-	economy.last_settle_unix
-	economy.last_offline_unix

Save flush
-	Core systems may set flow_ctx.save_request = true
-	FlowRuntime dispatch is the single save choke point
-	At most one save per dispatch tick

#### Determinism Philosophy
Economy accrual is deterministic relative to captured inputs.

Given:
-	Identical save state
-	Identical settlement timestamps
-	Identical multiplier inputs

The resulting Ase balance must be identical.

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

- Debug Panel is a global overlay mounted once under AppRoot and can be toggled (F1).
- Debug commands dispatch through FlowRuntime.dispatch and must not call core services directly.

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

### Snapshot.data keys (Summon screen, ECONOMY-003)
- `title`: String
- `ase_balance`: int
- `ase_rate_per_hour_hint`: float
- `ase_cost_per_summon`: int — **legacy flat fallback** (kept for backward-compat; always equals the uncalled cost)
- `selected_grade`: String — currently active grade key (`"uncalled"` | `"called"` | `"chosen"`)
- `summon_disabled`: bool — `true` when `ase_balance < selected_cost` (direct int comparison, no service call from state)
- `summon_disabled_reason`: String — `"not_enough_ase"` when disabled, `""` otherwise
- `summon_grade_options`: `Array[Dictionary]` — `[{ key, label, ase_cost }]` for all three grade tiers
- `default_summon_grade`: String (`"uncalled"`)
- `default_summon_amount`: int (1)
- `pending_summon_reveals`: Array — transient reveal queue (NOT saved)

Action slots:
- `nav.back` → `flow.go_state` to `flow.sanctum`
- `cta.summon` → `sanctum.summon` with `"disabled": summon_disabled`
- `overlay.dismiss_reveals` → `ui.dismiss_summon_reveals`

### Sanctum action types (SANCTUM-003 / ECONOMY-003)
- `sanctum.party.toggle` — payload: `{ echo_id: String }`. Adds or removes echo from transient pending selection. Silently ignored if party is full and echo is not already in pending.
- `sanctum.party.confirm` — no payload. Persists `pending_party_ids` → `save.sanctum.active_party_ids` and transitions back to `flow.sanctum`.
- `sanctum.grade_select` — flat action (grade is a top-level field, not nested in payload): `{ "type": "sanctum.grade_select", "grade": "called" }`. Stores grade in `FlowContext.selected_summon_grade`, validates against `ase_cost_per_summon_by_grade` table, then rebuilds snapshot mid-state. Invalid grade keys are logged and silently ignored.

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
-	economy.offline.apply
-	economy.offline.noop
-	economy.offline.skip
-	economy.time_anomaly

Payload rules:
- Must include: amount, before, after (if successful), reason
- Must be JSON-safe (no Nodes/Objects)
- Severity policy:
  - emit as info normally
  - emit as debug when logger level is DEBUG (to include "reason" in formatted output)

See README_DEV.md → Structured Logging (CORE-004) for architectural intent and usage guidelines.

---

## Actor Contract (ACTOR-001)

Actors are the unified data shape for any entity that participates in combat or fills a party
slot: Echoes now; enemies, NPCs, and structures in future stories.

### Required fields (all must be present and non-null)

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | Matches Echo save id; internal — never displayed |
| `name` | String | Display name |
| `rarity` | String | `"uncalled"` \| `"called"` \| `"chosen"` (enemies may use `""`) |
| `rank` | int | Echo life stage (1–10); enemies may use 0 or level-equivalent |
| `calling_origin` | String | Echo origin; `""` for enemies/NPCs |
| `stats` | Dictionary | `{ max_hp, atk, def, agi, int, cha }` — all int |
| `traits` | Dictionary | `{ courage, wisdom, faith }` — all int (0 for enemies) |
| `xp_total` | int | Lifetime XP (0 for enemies) |
| `level` | int | Experience step within rank (defaults to 1 until PROG-001) |
| `actor_type` | String | `"echo"` \| reserved: `"enemy"`, `"npc"` |

### Validation

`ActorSchema.validate(actor: Dictionary) -> bool`
Checks presence and non-null only. Does not enforce value ranges — enemy/NPC actors may use
zero or empty values for Echo-specific fields (traits, calling_origin, etc.).

### Read-only contract

Actor dicts are **read-only views** of save data. Mutating a returned actor dict must not
mutate the underlying save. Callers that need mutation (e.g. combat state) must work with
separate runtime-only copies.

This is enforced in `EchoActor.from_echo()` via `.duplicate(true)` on nested dicts.

### Canonical interfaces

- `SanctumService.get_party_actors() -> Array` — Actor dicts for the active party.
- `SanctumService.get_roster_actors() -> Array` — Actor dicts for the full roster.

Both return `[]` gracefully on empty roster/party. Neither modifies save data.

### Future stubs

- **position** `{ "x": int, "y": int }` — added when `core/grid/` lands (GRID stories).
- **ActorStateMachine** — per-round behavior selection, scaffolded when `core/combat/` exists.

---

## Echo Identity Schema (PROG-001)

Echo save dicts are generated by `EchoFactory.generate()` and stored in `sanctum.roster[]`.
They are the source of truth for Echo data and map to Actor dicts via `EchoActor.from_echo()`.

### Field table

| Field | Type | Source | Default |
|-------|------|--------|---------|
| `id` | String | Post-gen — assigned by caller (FlowRuntime) | `""` |
| `name` | String | RNG draw 4 — `NameBank.build_full_name(gender, rng)` | `""` |
| `gender` | String | RNG draw 3 — 50/50 bit | `"male"` |
| `seed_path` | String | Post-gen — caller-provided | `""` |
| `summon_index` | int | Post-gen — caller-provided | `0` |
| `origin` | String | Post-gen — caller-provided (`"summon"` / `"starter"`) | `"summon"` |
| `rarity` | String | RNG draw 1 — MVP always clamps to `"uncalled"` | `"uncalled"` |
| `calling_origin` | String | RNG draw 2 — weighted from `data.summoning.calling_weights` | `"uncalled"` |
| `class_origin` | String | RNG draw 6 — v2 birth Vector bias (see below) | `"protector"` |
| `archetype_birth` | String | Derived post-draw from dominant trait (no RNG) | `"brave"` |
| `traits` | Dictionary | RNG draw 5 — `{ courage, wisdom, faith }` each int | `{}` |
| `stats` | Dictionary | Derived from traits via birth_stats multipliers (no RNG) | `{}` |
| `xp_total` | int | Static — `0` at generation | `0` |
| `rank` | int | Static — `1` at generation | `1` |
| `level` | int | Static — `1` at generation; updated by progression systems later | `1` |
| `vector_scores` | Dictionary | Empty at birth — accumulates over time | `{}` |
| `generation_context` | Dictionary | Post-gen metadata (version, draw order, modifiers) | see below |

### RNG draw order v1 (draws 1–5 — IMMUTABLE: never reorder or insert between existing draws)

1. Rarity tier (`rarity_raw`) — consumed; MVP output always clamped to `"uncalled"`
2. `calling_origin` — weighted draw from `data.summoning.calling_weights`
3. `gender` — 50/50 bit
4. `name` — `NameBank.build_full_name(gender, rng)`
5. Traits: `courage`, `wisdom`, `faith` — each `randi_range(trait_min, trait_max)`

Post-draw derivations (no RNG draw, no version bump):
- `archetype_birth` — derived from dominant trait: `courage ≥ all` → `"brave"`, `wisdom ≥ all` → `"sage"`, else → `"devout"`
- `stats` — derived from trait values via `data.summoning.birth_stats` multipliers

### RNG draw order v2 (draws 1–6 — current as of PROG-001)

All v1 draws remain unchanged, plus one appended draw:

6. `class_origin` — birth Vector bias. Drawn from `data.summoning.class_origin_weights` via `_roll_weighted_key()`. **Always appended after all v1 draws — never inserted in the middle.**

Static (no RNG draw):
- `level: 1` — static at generation. No draw, no version bump.

`generation_context.rng_draw_order_version` = `"v2"` for all Echoes generated from PROG-001 onward.

### Key distinctions

**`archetype_birth` vs `class_origin`** — SEPARATE GDD Layer 1 fields; never conflate them.
- `archetype_birth` (`"brave"` / `"sage"` / `"devout"`) — derived from dominant trait post-draw. A personality archetype. No independent RNG draw.
- `class_origin` (`"protector"` / `"vanguard"` / `"seeker"` / `"pillar"`) — independently drawn (draw 6, v2). The Echo's birth Vector bias — its starting disposition before any Vector accumulation.

**Three-way calling/origin distinction** — three completely separate concepts:
- `calling_origin` — summoning lineage (how the Echo was called). Drawn at generation, save-stable.
- `class_origin` — birth Vector bias. Values mirror the active Vector taxonomy. An independently drawn Layer 1 field.
- `calling` (future, Rank 3 milestone) — earned identity unlocked through progression. NOT in MVP saves.

### Vector registry principle

`data.summoning.class_origin_weights` is the **single Vector type registry for the entire system**.
Values always mirror the active Vector taxonomy (`"protector"`, `"vanguard"`, `"seeker"`, `"pillar"` in MVP).
Post-MVP: add new Vectors by adding entries here in `balance.json` — no code change required.
This guarantees `class_origin` and the Vector system always stay in parity (one registry, one source of truth).

### Save compatibility rule

Any Echo field introduced after draw-order v1 must have a safe default in:
`EchoFactory.repair_echo_fields(echo: Dictionary) -> bool`

`FlowRuntime._repair_echo_schema(t)` calls this for every `flow.continue`, before any state `enter()` runs.
If any field was patched, `flow_ctx.save_request = true` persists the repair immediately.

Old Echo repair mapping (for `class_origin` on pre-v2 saves — derived from `calling_origin`):
- `"guardian"` → `"protector"`
- `"warrior"` → `"vanguard"`
- `"archer"` → `"seeker"`
- `"uncalled"` → `"pillar"`
- all others → `"protector"` (safe fallback)
