# Echoes vNext — Conventions & Contracts

> Bird's eye view of architecture choices made and choices deferred.
> Full codebase status: see `MEMORY.md`. Game design intent: use the `echoes-sankofa-gdd` skill.

---

## Architecture Principles (Non-Negotiable)

### Determinism
- No `OS.get_unix_time()`, `randf()`, `randomize()`, or global RNG in core sim
- All randomness via `CampaignSeed.derive("dot.separated.path")` → seeded `RandomNumberGenerator`
- Sim tick `t: int` always injected by caller — never generated internally
- All state changes logged via `StructuredLogger` with injected `t`

### Code Boundaries
- **Core** (`core/`): deterministic sim. No UI node refs. Outputs snapshots + logs.
- **UI** (`ui/`): renders snapshots. Dispatches actions. Never reads sim internals.
- **Data** (`data/`): read-only JSON configs. Schema changes are additive only.

### Single Choke Points
- `FlowRuntime.dispatch(action)` — only entry for all state mutations
- `EconomyService` — only entry for Ase/Ekwan changes
- `EmotionService` — only entry for emotion mutations (except mid-combat direct writes)
- `SaveService` — only entry for persistence; one flush per dispatch tick

### Save Discipline
- Additive-only schema — never remove or rename existing fields
- Add new fields with safe defaults; old fields stay until migration
- `flow_ctx.save_request = true` → FlowRuntime flushes once per dispatch tick
- Crash-safe: write to `.tmp` → rename to final path

### Naming Conventions
- Folders: `snake_case` (e.g. `core/state`, `ui/screens`)
- Scripts: `PascalCase.gd` — one primary class per file
- Data files: `snake_case.json`
- IDs and action types: `snake_case` strings / `domain.subdomain.verb`

---

## Core Contracts

### Snapshot Shape
```
{
  "type":    String,      // e.g. "flow.sanctum", "flow.encounter", "flow.resolve"
  "meta":    Dictionary,  // { t: int, ... }
  "data":    Dictionary,  // state-specific payload
  "actions": Dictionary   // slot-keyed (see below) — NEVER an Array
}
```
Snapshots are the **only** source of truth for UI rendering.

### Action Shape
```
{
  "type":     String,   // e.g. "flow.go_state", "sanctum.party.toggle"
  "label":    String,   // optional UI label
  "to":       String,   // optional (flow.go_state)
  "disabled": bool,     // optional — slot present but inactive
  "slot":     String,   // matches its key in snapshot.actions
  "payload":  {}        // optional extra params
}
```

### Slot-Keyed Actions (Feb 2026 — REQUIRED for all bespoke screens)
`snapshot.actions` is a **Dictionary keyed by slot name → action**. Never an Array.
```
{
  "nav.back":   { "type": "flow.go_state", "to": "flow.sanctum", "slot": "nav.back" },
  "cta.summon": { "type": "sanctum.summon", "slot": "cta.summon", "disabled": false }
}
```
Slot naming: `nav.*` (navigation), `cta.*` (primary call-to-action), `overlay.*` (overlay controls)

**Per-row interactions** (e.g. party toggle) are dispatched directly by the UI row component — NOT listed in `snapshot.actions`.

### Bespoke Screen Contract (UI-001)
Template: `res://ui/screens/ScreenTemplate.gd`

**Entry:** `func set_snapshot(snap: Dictionary) -> void`
**Exit:** `signal action_requested(action: Dictionary)`

Rules:
- Screens read `snap["data"]` for display; `snap["actions"]` (typed as Dictionary) for slots
- Screens **never** call `dispatch()` directly
- Screens **never** read `FlowContext`, `SanctumState`, `SaveService`, or any sim internal
- `UISnapshotRenderer` is fallback-only for unknown snapshot types — **not** a base class
- All new screens start from `ScreenTemplate.gd`

### Shell Routing Model (INFRA-001)
AppRoot routes `snapshot.type` → shell → bespoke screen.

| Shell | File | Snapshot types |
|-------|------|---------------|
| `SanctumShell` | `ui/shells/SanctumShell.gd` | flow.sanctum, flow.summon, flow.party_manage, flow.echo_manage, flow.realm_select |
| `RealmShell` | `ui/shells/RealmShell.gd` | flow.realm_init, flow.stage_map, flow.stage, flow.encounter, flow.resolve |

**Shell-cached nav pattern (UI-002):**
- SanctumShell owns the persistent NavBar — NOT injected into every sanctum-family snapshot
- On `flow.sanctum`: shell caches all `nav.*` and `cta.*` slots from `snap.actions` → `_cached_nav`
- All other sanctum-family screens inherit the cached NavBar unchanged
- This keeps SummonState, PartyManageState, etc. free from nav injection

**RealmShell echo bar pattern (UI-005):**
- RealmShell owns the persistent EchoBar (bottom 88px, full-width) — NOT rendered by individual screens
- `_update_echo_bar(snap)` is called on **every** `set_snapshot()` — always reflects latest HP + emotional state
- Data source by snapshot type:
  - `flow.encounter` / `flow.resolve` → filters `data.actors` by `faction == "echo"`
  - `flow.stage` / `flow.stage_map`   → reads `data.party_preview` (pre-combat shape: name, rank, calling_origin)
- HP label shown only when `hp`/`max_hp` fields are present (encounter/resolve only)
- Morale label: `morale_status` in combat; `calling_origin` pre-combat (defaults to "Ready")
- `OverlayRoot` (where screens attach) is sized to stop 88px above bottom — bar never overlaps content

### State Machine Transition Logging (required for all SM transitions)
Every `transition()` MUST emit:
```
{ "type": "state.transition", "t": int, "data": { machine_id, from_state, to_state, reason } }
```
`t` always injected. No-op transitions log at debug and return `false`.

---

## System Contracts

### CampaignSeed (`core/CampaignSeed.gd`)
- Single persisted root seed. `derive("dot.separated.path")` → `RandomNumberGenerator`
- Reserved namespaces: `campaign.starter.*`, `campaign.summon.*`, `encounter.retreat.*`
- New Game: generates root once. Continue: loads from save. Never regenerated automatically.
- Stored in save: `campaign.seed_root` (String), `campaign.seed_source` ("random" | "debug" | "repair")

### FlowRuntime + FlowContext (`core/runtime/FlowRuntime.gd` + `core/state/flow/FlowContext.gd`)
- `FlowRuntime.dispatch(action)` — single choke point for all state mutations
- Key FlowContext fields: `sim_tick`, `last_snapshot`, `pending_party_ids`, `selected_summon_grade`, `encounter_ctx`, `encounter_machine`, `encounter_id`, `save_data`, `save_request`, `logger`, `dev_combat_objective`
- `encounter_id` format: `"realm_id.stage_id"` (e.g. `"realm.01.stage.0"`). Set in `flow.select_stage` handler before transition. Used to derive unique placement seed path `"combat.placement.<encounter_id>"`. Never assign in FlowEncounterState — read-only there.
- `refresh_snapshot()` reads `ctx.last_snapshot` as-is for non-SANCTUM states
- For mid-state snapshot updates: use static `build_snapshot()` pattern, then call `refresh_snapshot()`

### Actor Contract (`core/actors/`)
Actor dicts are **read-only views** of save data. Deep-copied at construction. Mutating them must not mutate save data.

**18 REQUIRED_FIELDS** (checked by `ActorSchema.validate()`):

| Field | Notes |
|-------|-------|
| `id`, `name`, `rarity`, `rank`, `calling_origin` | Identity |
| `stats` | Sub-dict: `max_hp, atk, def, agi, int, cha, speed` (7 fields — DerivedStatService) |
| `traits` | Sub-dict: `courage, wisdom, faith` |
| `xp_total`, `level`, `actor_type` | Progression + type |
| `current_hp`, `speed`, `morale`, `fear` | Top-level runtime fields — **not** inside `stats` |
| `is_structure` | `true` for StructureActor only. Immutable after construction. Prevents movement. |
| `is_dead` | `false` at spawn. Set `true` by ActorStateMachine. Immutable once true. |
| `death_round` | `0` (alive). Set to `t` at KO. Never reset. |
| `grid_pos` | `{ "col": int, "row": int }` |
| `resilience_traits` | `Array[String]` — seeded personal traits (1–2, e.g. `["resist_fear"]`). Default `[]`. EchoActor only; `[]` for enemies/structures. |
| `leadership_traits` | `Array[String]` — seeded calling-pool traits (1–2). Default `[]`. EchoActor only; `[]` for enemies/structures. |

`guard_state: false` — in `get_defaults()` only (runtime, not saved, not in REQUIRED_FIELDS)

Access top-level fields directly: `actor["speed"]`, `actor["current_hp"]`. NOT via `actor["stats"]`.

**Mappers:**
- `EchoActor.from_echo(echo)` → actor dict (deep copy from save, reads `echo["emotion"]` for morale/fear)
- `EnemyActor.from_definition(defn, t)` → actor dict (level-scaled via DerivedStatService)
- `StructureActor.from_definition(defn)` → actor dict (`is_structure=true`, idle behavior)

### BehaviorModule (`core/actors/BehaviorModule.gd`)
Interface:
- `get_module_id() -> String` — stable, not generated at runtime
- `select_intent(context: Dictionary) -> Dictionary` — pure. No side effects, no RNG, no OS time.

Context dict: `{ actor, all_actors, t, board_cfg }`
Intent dict: `{ action_type: String, target_id?, target_pos?, target_distance? }`

Default module assignment (ActorStateMachine._init()):
- `actor_type == "echo"` or `"enemy"` → `BehaviorArbiter` (data-driven weighted scoring)
- all others (incl. `"structure"`) → `IdleBehaviorModule`
- Explicit module passed to `_init()` always overrides the default

**Absolute Fear Rule:** `fear ≥ 80` → returns `actor.refuse` immediately, before module is called. **PROG-010 tier override:** Veteran+ last-echo-standing raises threshold to 88; Elite raises to 95. `suppress_panic_spiral` resilience trait adds +5 on top of tier baseline.

### EmotionService (`core/emotion/EmotionService.gd`)
Single choke point for all emotion mutations (outside of mid-combat direct writes).

Emotion block stored at `echo["emotion"]`:
```
{ faith: int, morale_base: int, morale_current: int, fear_current: int }
```
- `init_echo(echo, logger, t)` — idempotent. `morale_base` = 25–74 from `traits.courage` + archetype modifier (brave+5, sage−5, devout+0)
- `apply_morale_delta(echo, delta, cause, logger, t)` — only valid drift entry
- `apply_fear_delta(echo, delta, cause, fear_threshold, logger, t)` — only valid drift entry
- `get_morale_tier(morale_current)` → `"inspired"` / `"steady"` / `"shaken"` / `"broken"`

**Mid-combat:** direct dict writes only — EmotionService NOT called. Exit deltas applied at combat end.

### GridService (`core/grid/GridService.gd`)
Pure static. Board 10×10 (from `balance.json data.grid`).
- `place_actors(echo_actors, enemy_actors, board_cfg, rng)` → deterministic faction placement
- `manhattan_distance(a, b) -> int` — direction heuristic used by `_greedy_step()` internally; do NOT use for range checks
- `chebyshev_distance(a, b) -> int` — true step cost for 8-dir movement; use for all range checks and AI distance awareness
- `is_adjacent(a, b) -> bool` — Chebyshev == 1; use for melee range, engagement checks
- `move_toward(actor, target_pos, board_cfg) -> { from_pos, to_pos }` — 8-dir greedy, mutates `actor["grid_pos"]`
- `is_valid_pos(pos, board_cfg) -> bool`

### CombatState (`core/combat/CombatState.gd`)
- `create(actors, objective, initiative_seed, init_cfg) -> Dictionary`
- `check_end_condition(actors, objective) -> { over: bool, victory: bool, reason: String }`

End condition priority:
1. `all_enemies_defeated` → victory
2. `shrine_destroyed` → defeat (purify_shrine objective only)
3. `all_echoes_dead` → defeat

Initiative: composite score (`speed XOR seed`), stable descending sort.

### Save Schema (`core/save/SaveSchema.gd` + `SaveService.gd`)
9 top-level keys: `schema_version`, `first_boot`, `meta`, `campaign`, `flow`, `economy`, `sanctum`, `stage_context`, `realms`

Crash-safe: write to `.tmp` → rename. Additive repair on load (adds missing fields with safe defaults).

### Economy Settlement (`core/economy/EconomyService.gd` + `EconomyAccrualService.gd`)
- No frame-based accrual. **Settle before every Ase spend.**
- `economy.settle_time` action: computes elapsed, applies math, updates `last_settle_unix`. Does NOT save.
- Offline accrual: 50% decay → 0 over 8hr cap. Applied once per session on Continue.
- UI may predict/animate balance; Core commits. Core is authoritative if they disagree.
- Ase summon costs (grade-based): uncalled=60, called=150, chosen=400

---

## Per-Screen Snapshot Summaries
Full field shapes live in each FlowState file (`core/state/flow/states/`).

| Screen | Snapshot type | Key data fields | Action slots |
|--------|--------------|-----------------|-------------|
| SanctumScreen | `flow.sanctum` | sanctum_name, ase_balance, roster_count, roster_preview (3 echoes + emotion), active_party_count, party_slots | nav.party_manage, nav.echo_manage, nav.realm_select, nav.summon, cta.enter_stage (disabled when no realm) |
| SummonScreen | `flow.summon` | ase_balance, selected_grade, summon_grade_options, summon_disabled, pending_summon_reveals | nav.back, cta.summon, overlay.dismiss_reveals |
| PartyManageScreen | `flow.party_manage` | max_party_size (5), roster (id/name/rank/in_party), active_party_ids | back, primary (sanctum.party.confirm, enabled when pending≥1) |
| CombatBoardScreen | `flow.encounter` | actors (projected), round, round_phase, initiative_order, objective_state, retreat fields (pre_combat only) | nav.back, cta.retreat (when eligible) |
| ResolveScreen | `flow.resolve` | victory, reason, round_ended, actors (projected), objective_state, enemies_defeated, echoes_survived, ase_awarded, rank (S/A/B/C/D/F), reward_breakdown (Array of {label, delta}) | cta.continue → flow.sanctum, cta.next_stage → flow.complete_stage |
| RealmSelectScreen | `flow.realm_select` | title, current_realm_id, realms[] (id/name/virtue/description/stage_count_min/max/status/locked) | nav.back |
| RealmInitScreen | `flow.realm_init` | realm_id, name, virtue, description, stage_count, seed, stages[] (stage_index, stage_type, stage_seed, stage_description, objective_count, objectives[{obj_index, obj_type, obj_description}]) | cta.begin, nav.back |
| StageMapScreen | `flow.stage_map` | realm_id, realm_name, current_stage_id, stages_completed_count, stages[] (id, name, status, stage_type, stage_description, objective_count, objectives[{obj_index, obj_type, obj_description}]), party_preview | cta.enter_stage, nav.back |
| StageScreen | `flow.stage` | stage_id, stage_name, stage_type, stage_description, objective_count, objectives[] ({obj_index, obj_type, obj_description}), realm_id, party_preview | cta.start, nav.back |

**Projected actor shape** (FlowEncounterState._project_actor): `id, name, hp, max_hp, status` (dead/guarding/refusing/alive), `calling_origin`, `morale_status` (Normal/Shaken/Afraid/Broken from fear)

**Extended actor snapshot fields** (ActorStateMachine.get_snapshot() — PROG-010):
`smartness_tier` (novice/adept/veteran/elite), `resilience_traits: Array`, `leadership_traits: Array`, `active_leadership: String` (trait fired this turn), `bark_line: String`, `bark_context: String`, `bark_tier: String`, `bark_target_id: String`

---

## Flow Architecture

### Macro Loop
```
Boot → Splash → MainMenu → Sanctum
From Sanctum: PartyManage | EchoManage | Summon | RealmSelect
From RealmSelect: StageMap → Stage → Encounter(s) → Resolve → Sanctum
```

### Save Triggers (no manual save in MVP)
`new_game`, `summon` (paid + starter), `realm_select`, `stage_enter`, `resolve/aftermath`, `name_confirm`, `party_confirm`

### Encounter Resolution
Encounter ≠ just combat. `ObjectiveType` drives `resolution_mode`:
- ObjectiveType `shrine` → resolution_mode `purify_shrine`
- ObjectiveType `combat` → resolution_mode `defeat_enemies`

EncounterStateMachine phases (scaffold): `setup → blessing → rounds → resolution → aftermath`

---

## Action Type Registry

| Domain | Action type | Notes |
|--------|------------|-------|
| **flow** | `flow.go_state` | transitions to `to` state |
| | `flow.new_game` | initializes save, goes to sanctum |
| | `flow.continue` | loads save, applies offline accrual |
| | `flow.advance` | generic advance (encounter phases) |
| **sanctum** | `sanctum.summon` | pays cost, generates echo(es), adds to roster |
| | `sanctum.grade_select` | updates `FlowContext.selected_summon_grade`, rebuilds snapshot. Grade is flat top-level field, NOT nested in payload |
| | `sanctum.party.toggle` | payload: `{ echo_id }`. Adds/removes from pending_party_ids |
| | `sanctum.party.confirm` | persists pending → save, returns to sanctum |
| | `sanctum.name.reroll` | rerolls sanctum name suggestion |
| | `sanctum.name.confirm` | persists name to save |
| **economy** | `economy.settle_time` | settles elapsed accrual (call before every spend) |
| | `economy.ase.add` | adds Ase (debug/reward); reason `"stage_reward"` used for ECONOMY-004 stage payouts |
| | `economy.ase.spend` | spends Ase (validate first) |
| **combat** | `combat.init` | initializes combat state, places actors |
| | `combat.confirm_round` | runs full round loop |
| **actor** | `actor.taunt` | Blade Veteran+ only; sets `taunted_by` on nearest enemy actor; clears next round. Taunted enemy gets +25 melee_attack score vs taunter. |
| | `actor.retreat` | Calling-gated (Adept+): warrior=never, guardian/uncalled < 30% HP, archer < 50% HP. |
| **encounter** | `encounter.retreat` | attempts retreat; spends Ase regardless of roll outcome |
| | `encounter.complete` | signals encounter done; Flow routes to resolve |
| | `encounter.advance` | advances encounter phase (`to: String`) |
| **directive** | `directive.select` | sets active directive in save |
| **ui** | `ui.dismiss_summon_reveals` | clears pending reveal queue |
| **flow** | `flow.select_realm` | selects a realm; triggers `RealmService.get_or_create`; transitions to `flow.realm_init`. Payload: `{ realm_id: String }` |
| | `flow.select_stage` | sets `ctx.stage_id`, transitions to `flow.stage`. Payload: `{ stage_id: String }` |
| | `flow.complete_stage` | REALM-004: advances `current_stage_index` via `RealmService.advance_stage()`; on realm complete routes to `flow.realm_select` (clears `ctx.realm_id`+`ctx.stage_id`); else routes to `flow.stage_map` |
| **debug** | `debug.seed.show/set/reset` | seed tooling (dev only, `t = -1`) |
| | `debug.echo.gen_test` | generates test echo (dev only) |

---

## Log Event Type Registry

| Namespace | Key event types |
|-----------|----------------|
| `state.transition` | Required for every SM transition. Payload: machine_id, from_state, to_state, reason |
| `save.*` | save.load, save.write, save.schema.repair |
| `economy.*` | economy.ase.add/spend/add_denied/spend_denied, economy.offline.apply/noop, economy.time_anomaly |
| `sanctum.*` | sanctum.summon.bark, sanctum.party.toggle, sanctum.party.confirm, sanctum.summon.start/complete |
| `actor.*` | actor.intent, actor.action, actor.moved, actor.purified_shrine, actor.died |
| `combat.*` | combat.round_start, combat.shrine_drain, combat.end |
| `realm.*` | realm.created — Payload: `realm_id, virtue, seed, stage_count, run_index, run_count, stage_types: Array[String], stage_seeds: Array[int]` |
| `encounter.*` | encounter.retreat.attempted, encounter.retreat.failed |
| `snapshot.*` | snapshot.emitted (includes `field_count: data.size()`) |
| `debug.cmd.*` | debug.cmd.in/out/err (`t = -1` — outside sim tick space) |

Rules:
- `type` must be namespaced. `msg` is short human-readable. `data` is JSON-safe Dictionary.
- Logger never generates `t`. No `print()` in core for meaningful events.
- All SM transitions must emit `state.transition`.

---

## Summoning Contract

Core rules:
- Paid summons: Sanctum Summon screen only
- Cost is **grade-based**: uncalled=60, called=150, chosen=400 Ase. Legacy flat key kept as fallback.
- Settle before spend. Transactional: settle → validate → spend → generate → append → save
- Grade defaults to `"uncalled"` on every Sanctum Summon screen entry. `selected_summon_grade` is transient.
- Bulk: 1–10 per call. Each echo gets unique seed path `campaign.summon.<summon_index>`.
- Reveal queue is **transient** (not saved). Summon does NOT cause a flow transition.

EchoFactory RNG draw order v1 — **IMMUTABLE. Never reorder. Append new draws at end only (bump to v2):**
`rarity_tier → calling_origin → gender → name → traits → archetype_birth → derived_stats`

Echo traits (resilience + leadership) use a **separate derived RNG** at path `<seed_path>.echo_traits.v1` — they are NOT part of the v1/v2 draw sequence. This derived RNG is also immutable once assigned.

---

## Decisions Made vs Deferred

### Made (locked)
- Slot-keyed actions Dictionary — no going back to Array-style
- Shell-cached nav: SanctumShell owns NavBar; sanctum-family states do NOT inject nav
- Two-shell router: SanctumShell (hub) vs RealmShell (venture)
- EmotionService as single choke point outside combat
- Direct dict writes for mid-combat emotion (EmotionService not called during rounds)
- EchoFactory RNG draw order v1 immutable
- Absolute Fear Rule: `fear ≥ 80 → actor.refuse` before module is called
- `is_dead` and `is_structure` are immutable once set
- One save slot forever. Auto-save only at sanctioned boundaries (no manual save in MVP)
- `static build_snapshot()` pattern for mid-state snapshot updates
- `SmartnessTierService` is the single lookup point for tier (rank-based) + calling_behavior config
- Echo traits (`resilience_traits` + `leadership_traits`) seeded at EchoFactory via derived RNG `.echo_traits.v1` — immutable, separate from v1/v2 draw sequence. Never reorder v1/v2.
- Bark system (PROG-010): snapshot fields + ShoutBank expansion only. Reactive responses deferred to VOICE-001. Bark display deferred to VOICE-002.
- `StageModel` + `ObjectiveModel` are immutable data contracts after REALM-002. Adding new objective types = add a constant + TYPE_DESCRIPTIONS entry in `ObjectiveModel.gd` only. Generator pre-boss pool (`_PRE_BOSS_POOL` in `RealmGenerator.gd`) must never be reordered (determinism). Append new types at the end only.
- `objective_params: {}` on ObjectiveModel is the extension point for post-MVP stage content (roaming intel map, escort targets, etc.). Not in REQUIRED_FIELDS — always read via `.get("params", {})`.
- Stage IDs use format `"stage.%d"` (zero-based index), e.g. `"stage.0"`, `"stage.1"`. Set on `flow_ctx.stage_id` by `flow.select_stage` action handler in FlowRuntime.
- ECONOMY-004: Stage reward is paid once inside `build_final_snapshot()` — no `reward_paid` guard needed since this function is called exactly once per combat end. `RewardCalc` is a pure static helper with zero side effects. Rank uses board totals (`total_enemies`, `total_echoes`) for `max_possible` so rank reflects missed opportunities. Defeat uses `base × defeat_factor` as rank numerator — defeat naturally scores C or lower. All reward config lives in `balance.data.rewards`.
- REALM-003 delivered as part of REALM-002: deterministic stage generation (`RealmGenerator.generate()`), `stages[]` in `RealmInitSnapshot`, stage UI (RealmInitScreen, StageMapScreen, StageScreen), and `LOG_REALM_CREATED` with full stage list are all complete. REALM-003 Notion card is Done — no additional code needed.
- REALM-004: `RealmService.advance_stage(ctx, t) → Dictionary` increments `current_stage_index` in save; detects realm complete (`new_index >= stage_count`) and writes `is_completed=true`, `status="completed"`; always sets `save_request=true`; idempotent if already complete. Called by `flow.complete_stage` handler in FlowRuntime. `cta.next_stage` in resolve snapshot dispatches `flow.complete_stage` (not `flow.go_state`). On realm complete, FlowRuntime clears `ctx.realm_id`+`ctx.stage_id` before routing to `REALM_SELECT`. `FlowStageMapState` emits `stages_remaining`, `realm_complete`, `stage_count` in snapshot data; gates `cta.enter_stage` when `realm_complete==true`; guards empty model with redirect snapshot (not scaffold).
- Combat-stage pipeline fixes (post REALM-004): Three bugs fixed. (1) `_handle_complete_stage()` now nulls `encounter_ctx`+`encounter_machine` before advancing stage — fixes stale board actors on next stage entry. (2) `FlowEncounterState.enter()` now calls `_resolve_mode_from_stage()` instead of hardcoding `PURIFY_SHRINE` — reads stage's first objective type (`combat`→`COMBAT`, `shrine`→`PURIFY_SHRINE`) from the realm model. (3) `flow.select_stage` handler now sets `encounter_id = realm_id + "." + stage_id` — fixes identical actor placement across all encounters. Win-path emotion drift (`_apply_encounter_emotion_drift("win", t)`) is now called in `_handle_complete_stage()` before nulling the encounter, wiring the EMOTION-002 drift that was silently skipped in the `build_final_snapshot()` path.

### Deferred
- XP / rank progression (fields reserved in schema; no logic yet)
- Echo Manage screen (`FlowEchoManageState` = scaffold, no logic)
- Full art: StageScreen, StageMapScreen (scaffolds built; deferred to UI-006+)
- HP progress bar in RealmShell EchoBar (text label is current; bar deferred to UX pass)
- Voice reactive system: VOICE-001 (reactive bark responses — other actors respond to barks, deferred). Bark display: VOICE-002 (deferred). Bark snapshot fields + ShoutBank expansion: DONE (PROG-010).
- Multiple save slots (one slot is the current contract)
- Sanctuary upgrades affecting trait rolls (`generation_context` reserved for future modifiers)
