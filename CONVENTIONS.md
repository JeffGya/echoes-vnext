# Echoes vNext — Conventions & Contracts

> Bird's eye view of architecture choices made and choices deferred.
> Full codebase status: see `MEMORY.md`. Game design intent: use the `echoes-sankofa-gdd` skill.

---

## V2 Migration in Progress (Alignment Wave — started 2026-04-06)

The codebase is currently being migrated from V1 design idioms to V2 canonical design.
This file still documents V1 contracts — **the live running code**. As each system story ships,
its section here will be updated to reflect V2 truth.

**Migration map:** `docs/v2-migration-map.md` — authoritative domain-by-domain map of V1 → V2 targets.

**Terminology reminder:**
- `rank` / `level` / `xp_total` are V1 internal aliases — V2 player-facing terms are `Standing`, `Step`, `Storyweight`
- 4 legacy vectors (`protector`, `vanguard`, `seeker`, `pillar`) are being replaced by 10 virtue domains
- Each system story owns its own update to this file when the system is migrated

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

**UI node discipline (short form):**
- Prefer scene-authored structure + theme variations over runtime-created UI nodes.
- Use lightweight nodes for lightweight jobs: status badges as `Label` variants, HP bars as `ProgressBar`.
- Avoid spacer-only `Control` nodes when container `separation`/margins can express the layout.
- Use specific node names (avoid generic `PanelContainer`) to keep styling/refactors safe.

### Shell Routing Model (INFRA-001)
AppRoot routes `snapshot.type` → shell → bespoke screen.

| Shell | File | Snapshot types |
|-------|------|---------------|
| `SanctumShell` | `ui/shells/SanctumShell.gd` | flow.sanctum, flow.summon, flow.echo_party, flow.realm_select, flow.vow_manage |
| `RealmShell` | `ui/shells/RealmShell.gd` | flow.realm_init, flow.stage_map, flow.stage, flow.encounter, flow.resolve |

**Shell-cached nav pattern (UI-002):**
- SanctumShell owns the persistent NavBar — NOT injected into every sanctum-family snapshot
- On `flow.sanctum`: shell caches all `nav.*` and `cta.*` slots from `snap.actions` → `_cached_nav`
- All other sanctum-family screens inherit the cached NavBar unchanged
- This keeps SummonState, EchoPartyState, etc. free from nav injection

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

### SocialGraphService (`core/sanctum/SocialGraphService.gd`)
Pure-static `RefCounted`. BOND-001 social graph — 11-tier signed score (-100..+100) between Echo pairs.

- `get_edge(bonds, a, b) -> Dictionary` — canonical edge or `{}`
- `get_tier(strength) -> int` — -5..+5 per tier table
- `get_tier_name(tier) -> String` — Nemesis/Rival/Resentful/Tense/Wary/Indifferent/Familiar/Friendly/Trusted/Bonded/Kindred
- `get_bond_type(strength, thresholds) -> String` — "rival" | "neutral" | "friend"
- `get_bonds_for_actor(bonds, actor_id) -> Array`
- `get_encounters_for_actor(encounters, actor_id) -> Array`
- `get_rival_pairs_in_party(bonds, party_ids, thresholds) -> Array`
- `get_friend_pairs_in_party(bonds, party_ids, thresholds) -> Array`
- `apply_score_delta(bonds, a, b, delta, thresholds, logger, t) -> Array` — only mutating fn; clamps ±100; logs `sanctum.bond_updated`; no-op if delta=0 or result=current
- `is_rival_archetype_pair(arch_a, arch_b, rival_pairs) -> bool` — directional-agnostic
- `record_encounter(encounters, a, b) -> Array` — adds canonical pair once; no duplicates

**Save fields** (inside `save_data["sanctum"]`):
- `bonds: []` — Array of `{ actor_a, actor_b, strength }`. Canonical: actor_a < actor_b alphabetically. `bond_type` and `tier` never stored — derived at read time.
- `party_encounters: []` — Array of `[actor_a_id, actor_b_id]` canonical pairs. Written when two echoes first share a party slot. Never removed.

**Tier table:**
| Tier | Name | Strength range | bond_type |
|------|------|----------------|-----------|
| +5 | Kindred | 90..100 | friend |
| +4 | Bonded | 70..89 | friend |
| +3 | Trusted | 50..69 | friend |
| +2 | Friendly | 30..49 | friend (friend_min=30) |
| +1 | Familiar | 10..29 | neutral |
| 0 | Indifferent | -9..9 | neutral |
| -1 | Wary | -10..-29 | neutral |
| -2 | Tense | -30..-49 | rival (rival_max=-30) |
| -3 | Resentful | -50..-69 | rival |
| -4 | Rival | -70..-89 | rival |
| -5 | Nemesis | -90..-100 | rival |

**`bond_entries` per echo** (in `flow.echo_party` snapshot): `Array[{ echo_id, name, tier, strength_before, bond_type_before }]` — sorted by tier ascending (most negative first). Empty when no party encounters recorded.

**Bond triggers** (config only — fire in BOND-002): all integer values under `balance.data.sanctum.bond_triggers`. Balance also holds `rival_archetypes` pairs and `bond_thresholds { rival_max, friend_min }`.

### VowService (`core/sanctum/VowService.gd`)
Pure-static `RefCounted`. VOW-001 vow doctrine system.

- `unlock_vow(vow_id, discovered_realm, save_data, ctx, logger, t) -> bool` — marks vow as discovered in `sanctum.vows[vow_id]` at tier 1. Idempotent.
- `pledge_vow(vow_id, tier, cfg, save_data, ctx, logger, t) -> bool` — sets `sanctum.active_vow`. Fails if vow already active or vow not unlocked. Records `pledged_at_realm` (empty string if pledged from Sanctum) and `runs_at_pledge` (total run_count across all realms at pledge time).
- `break_vow(cfg, save_data, ctx, econ, logger, t) -> Dictionary` — clears `sanctum.active_vow`. Returns `{ morale_delta, fear_delta, ase_cost }` for caller to apply. Returns `{}` if no active vow.
- `release_vow_if_due(save_data, ctx, logger, t) -> bool` — called on every `flow.sanctum` enter. Checks if vow release condition is met; if so clears `active_vow` and returns `true`. Release condition: if `pledged_at_realm` is non-empty → that realm is no longer active; if empty → total `run_count` across all realms > `runs_at_pledge`.
- `get_vow_snapshot_data(save_data, cfg) -> Dictionary` — returns `{ can_pledge, active_vow, available_vows[] }` for snapshot injection.

**Save fields** (inside `save_data["sanctum"]`):
- `vows: {}` — Dict keyed by vow_id → `{ tier: int, discovered_realm: String }`. One entry per unlocked vow.
- `active_vow: {}` — `{ vow_id, tier, pledged_at_realm, runs_at_pledge }` or `{}` when no active vow.

**Balance fields** (inside `data.sanctum.vows[vow_id]`):
- `vow_name`, `proverb_twi`, `proverb_en`, `description`, `benefit_label`, `tradeoff_label`, `breaking_cost_hint`, `unlock_description`
- `break_cost_ase`, `break_morale_delta`, `break_fear_delta`

**Release timing:**
- Pledged during a realm: released when that realm's status is no longer `"active"` (i.e. completed or abandoned).
- Pledged from Sanctum (no active realm): released when total `run_count` across all realms increases past `runs_at_pledge`.
- Early break: always available via `cta.break` — applies full penalty.

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
| SanctumScreen | `flow.sanctum` | sanctum_name, ase_balance, roster_count, roster_preview (3 echoes + emotion), active_party_count, party_slots | nav.echo_party, nav.realm_select, nav.summon, cta.enter_stage (disabled when no realm) |
| SummonScreen | `flow.summon` | ase_balance, selected_grade, summon_grade_options, summon_disabled, pending_summon_reveals | nav.back, cta.summon, overlay.dismiss_reveals |
| EchoPartyScreen | `flow.echo_party` | max_party_size (5), echoes (id/name/rank/level/in_party/archetype/calling/calling_eligible/stats/xp/bond_entries), active_party_ids | nav.back (party toggles are immediate via sanctum.party.toggle) |
| CombatBoardScreen | `flow.encounter` | actors (projected), round, round_phase, initiative_order, objective_state, retreat fields (pre_combat only) | nav.back, cta.retreat (when eligible) |
| ResolveScreen | `flow.resolve` | victory, reason, round_ended, actors (projected), objective_state, enemies_defeated, echoes_survived, ase_awarded, rank (S/A/B/C/D/F), reward_breakdown (Array of {label, delta}), xp_events (Array of XpEvent) | Victory: `cta.continue` → `flow.complete_stage` (destination=sanctum), `cta.next_stage` → `flow.complete_stage`. Defeat: `cta.continue` → `flow.go_state` (no stage advance). |
| RealmSelectScreen | `flow.realm_select` | title, current_realm_id, realms[] (id/name/virtue/description/stage_count_min/max/status/locked) | nav.back |
| ~~RealmInitScreen~~ | `flow.realm_init` | **Removed (UI-003)** — FlowRealmInitState now auto-advances to `flow.stage_map` on enter(); no screen rendered. | — |
| StageMapScreen | `flow.stage_map` | realm_id, realm_name, current_stage_id, stages_completed_count, stages[] (id, name, status, stage_type, stage_description, objective_count, objectives[{obj_index, obj_type, obj_description}]), party_preview | cta.enter_stage, nav.back |
| StageScreen | `flow.stage` | stage_id, stage_name, stage_type, stage_description, objective_count, objectives[] ({obj_index, obj_type, obj_description}), realm_id, party_preview | cta.start, nav.back |
| VowScreen | `flow.vow_manage` | can_pledge (bool), active_vow ({vow_id, tier, proverb_twi, proverb_en}), available_vows[] ({vow_id, vow_name, proverb_twi, proverb_en, description, benefit_label, tradeoff_label, breaking_cost_hint, is_unlocked, max_tier_unlocked, is_active, discovered_realm, unlock_hint}) | nav.back, cta.pledge (disabled when vow already active), cta.break (disabled when no active vow) |

**Projected actor shape** (FlowEncounterState._project_actor): `id, name, hp, max_hp, status` (dead/guarding/refusing/alive), `calling_origin`, `morale_status` (Normal/Shaken/Afraid/Broken from fear)

**Extended actor snapshot fields** (ActorStateMachine.get_snapshot() — PROG-010):
`smartness_tier` (novice/adept/veteran/elite), `resilience_traits: Array`, `leadership_traits: Array`, `active_leadership: String` (trait fired this turn), `bark_line: String`, `bark_context: String`, `bark_tier: String`, `bark_target_id: String`

---

## Flow Architecture

### Macro Loop
```
Boot → Splash → MainMenu → Sanctum
From Sanctum: EchoParty | Summon | RealmSelect
From RealmSelect: StageMap → Stage → Encounter(s) → Resolve → Sanctum
```

### Save Triggers (no manual save in MVP)
`new_game`, `summon` (paid + starter), `realm_select`, `stage_enter`, `resolve/aftermath`, `name_confirm`, `party_toggle_immediate_apply`

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
| | `sanctum.name.reroll` | rerolls sanctum name suggestion |
| | `sanctum.name.confirm` | persists name to save |
| **economy** | `economy.settle_time` | settles elapsed accrual (call before every spend) |
| | `economy.ase.add` | adds Ase (debug/reward); reason `"stage_reward"` used for ECONOMY-004 stage payouts |
| | `economy.ase.spend` | spends Ase (validate first) |
| **combat** | `combat.init` | initializes combat state, places actors |
| | `combat.confirm_round` | runs full round loop |
| **actor** | `actor.taunt` | Blade Veteran+ only; sets `taunted_by` on nearest enemy actor; clears next round. Taunted enemy gets +25 melee_attack score vs taunter. |
| | `actor.retreat` | Calling-gated (Adept+): blade=never, warder/uncalled < 30% HP, ranger < 50% HP. |
| | `actor.press` | **Blade skill** (blade_resolve). Condition: hit same target last round. Extra melee candidate +15 base score. |
| | `actor.interpose` | **Warder skill** (warders_vigil). Condition: ally threatened. Move to interpose; grant guard_state to protected ally. |
| | `actor.hold_ground` | **Steward skill** (stewards_ground). Condition: adjacent to shrine OR 2+ allies within 2 tiles. +3 morale to allies in 2-tile radius; soft taunt on adjacent enemies. |
| | `actor.steady_call` | **Steward skill** (stewards_call). Once-per-combat. fear_current −20 to all allies in leadership_radius. |
| | `actor.mark` | **Ranger skill** (rangers_mark). Condition: enemy within 3 tiles AND not already marked. Sets `marked_by` → +10 all Echo attack scores vs target for 2 rounds. |
| | `actor.withdraw` | **Ranger skill** (rangers_withdraw). Condition: adjacent to 2+ enemies. Move to threat-minimising tile; −3 fear on resolve. cooldown: 1. |
| | `actor.read_field` | **Seer skill** (seers_sight). Condition: `_read_field_cooldown == 0`. Writes `_seers_blessing` to allies in radius → +10 next guard/protect_ally. Streak cap: 3 consecutive uses; 1-round cooldown after cap. |
| | `actor.reveal` | **Seer skill** (seers_reveal). Once-per-combat. Condition: enemy not yet attacked this combat. Sets `revealed_by_seer` → +15 all Echo attack scores vs target for 3 rounds. |
| | | *Calling skill action types defined in `/docs/calling-reference.md`* |
| **encounter** | `encounter.retreat` | attempts retreat; spends Ase regardless of roll outcome |
| | `encounter.complete` | signals encounter done; Flow routes to resolve |
| | `encounter.advance` | advances encounter phase (`to: String`) |
| **directive** | `directive.select` | sets active directive in save |
| **ui** | `ui.dismiss_summon_reveals` | clears pending reveal queue |
| **flow** | `flow.select_realm` | selects a realm; triggers `RealmService.get_or_create`; transitions to `flow.realm_init`. Payload: `{ realm_id: String }` |
| | `flow.select_stage` | sets `ctx.stage_id`, transitions to `flow.stage`. Payload: `{ stage_id: String }` |
| | `flow.complete_stage` | REALM-004: advances `current_stage_index` via `RealmService.advance_stage()`; on realm complete routes to `flow.realm_select` (clears `ctx.realm_id`+`ctx.stage_id`); else routes to `flow.stage_map`. Optional `destination` field overrides routing for non-completed stages (e.g. `"flow.sanctum"` for victory "To Sanctum" path). |
| **vow** | `vow.pledge` | payload: `{ vow_id, tier }`. Calls VowService.pledge_vow(). Saves `pledged_at_realm` + `runs_at_pledge`. |
| | `vow.break` | Calls VowService.break_vow(). Applies morale/fear delta to all roster echoes. |
| **debug** | `debug.seed.show/set/reset` | seed tooling (dev only, `t = -1`) |
| | `debug.echo.gen_test` | generates test echo (dev only) |
| | `debug.vow.unlock` | payload: `{ vow_id }`. Unlocks a vow at tier 1 without scenario trigger (dev only) |
| | `debug.vow.pledge` | payload: `{ vow_id }`. Pledges a vow directly (dev only) |
| | `debug.vow.break` | Breaks active vow without confirmation (dev only) |
| | `debug.vow.status` | Logs current vow state to debug panel (dev only) |

---

## Log Event Type Registry

| Namespace | Key event types |
|-----------|----------------|
| `state.transition` | Required for every SM transition. Payload: machine_id, from_state, to_state, reason |
| `save.*` | save.load, save.write, save.schema.repair |
| `economy.*` | economy.ase.add/spend/add_denied/spend_denied, economy.offline.apply/noop, economy.time_anomaly |
| `sanctum.*` | sanctum.summon.bark, sanctum.party.toggle, sanctum.rank_up, sanctum.calling.confirm, sanctum.summon.start/complete |
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
- REALM-005: `RealmService.calculate_stage_reward(stage_index, realm_virtue, run_index, reward_cfg)` is a pure static helper. Formula: `roundi((virtue_bonuses[virtue] + stage_index × stage_index_bonus_per) × (realm_order_multiplier_base + run_index × realm_order_multiplier_step))`. Scales ×0.5 per realm entered (no cap). Victory-only — defeat gets existing 25% consolation, no virtue bonus. Added to total after redo multiplier (flat bonus, not subject to redo penalty). Logged via `economy.stage.reward` with `formula_inputs`. Config in `balance.data.rewards`. `formula_inputs` + `relics: []` stub (ITEM-001 attachment point) added to `flow.resolve` snapshot data in `build_final_snapshot()`. `StructuredLogger.warn()` added (maps to `info` severity).
- Combat-stage pipeline fixes (post REALM-004): Three bugs fixed. (1) `_handle_complete_stage()` now nulls `encounter_ctx`+`encounter_machine` before advancing stage — fixes stale board actors on next stage entry. (2) `FlowEncounterState.enter()` now calls `_resolve_mode_from_stage()` instead of hardcoding `PURIFY_SHRINE` — reads stage's first objective type (`combat`→`COMBAT`, `shrine`→`PURIFY_SHRINE`) from the realm model. (3) `flow.select_stage` handler now sets `encounter_id = realm_id + "." + stage_id` — fixes identical actor placement across all encounters. Win-path emotion drift (`_apply_encounter_emotion_drift("win", t)`) is now called in `_handle_complete_stage()` before nulling the encounter, wiring the EMOTION-002 drift that was silently skipped in the `build_final_snapshot()` path.
- PROG-003 post-implementation fixes: (1) Stage completion on "To Sanctum" — victory `cta.continue` now dispatches `flow.complete_stage` with `destination="flow.sanctum"` so `advance_stage()` is called on both victory exit paths; defeat `cta.continue` unchanged (`flow.go_state`, no advance). (2) Party toggles are accepted from `flow.echo_party` and rebuild via `FlowEchoPartyState.build_snapshot()`. (3) Final combat emotion state is synced back to `save_data["sanctum"]["roster"]` in `build_final_snapshot()` before returning the resolve snapshot — win/loss drift in `_apply_encounter_emotion_drift()` then applies on top.
- PROG-003: XP accrual, level-up, and EchoParty screen. `ProgressionService` (pure static, `core/progression/ProgressionService.gd`) — `award_post_combat_xp(save_data, echo_action_logs, victory, realm_completed, prog_cfg, birth_stats_cfg, logger, t) → Array[XpEvent]`. XP sources: kill bonus (attacker only), stage clear (all party), realm completion bonus (all party, final stage only). Virtue multiplier: courage-based, max +20%, scales on `melee_share × (courage/100) × max_mult`. Level-up triggers `DerivedStatService.compute_stats()` recompute. Cap: `max_level_per_rank=5`. `EncounterContext.echo_action_logs: Dictionary` accumulates `{ melee_count, guard_count, kill_count, total_count }` per echo in `FlowRuntime._resolve_next_actor()`. XP award called in `FlowEncounterState.build_final_snapshot()` after Ase reward block; `xp_events` added to snapshot data. Config in `balance.data.progression`. Snapshot building is now owned by `FlowEchoPartyState` and rendered by `EchoPartyScreen`.
- PROG-004: Rank-up logic, trait drift, wisdom/faith virtue multipliers, and EchoParty UI additions. **Rank-up contract:** `ProgressionService.execute_rank_up(echo, campaign_seed, prog_cfg, birth_stats_cfg, logger, t) → event_dict`. Eligible when `level == max_level_per_rank` and `rank < 5` (MVP cap). Execution: increment rank, reset level to 1, carry XP overflow (`xp_total = max(0, xp_total - level_thresholds[-1])`), apply seeded trait drift, recompute derived stats via `DerivedStatService.compute_stats()`, log `"progression.rank_up"`. **Drift seed path:** `"echo.{id}.rank_up.rank_{new_rank}"` → `CampaignSeed.derive()` → `int` → seed a `RandomNumberGenerator`. Trait selection: weighted roll from `vector_drift_weights[dominant_vector]` (config-driven in `balance.data.progression`). Direction: `+1` or `-1`, second seeded roll. Magnitude: `±rank_up_trait_drift_magnitude` (default 1), clamped `[1, 100]`. `calling_eligible = true` when `new_rank == 3` (PROG-007 attachment point). **Virtue multiplier formulas (full set):** courage: `melee_share × (courage/100) × virtue_xp_multiplier_max`; wisdom: `guard_share × (wisdom/100) × wisdom_xp_multiplier_max`; faith: `survived_factor (1 or 0) × (faith/100) × faith_xp_multiplier_max`. Survival tracked via `echo_action_logs[id]["survived"]` — set to `false` when echo is KO'd (`is_dead=true`) in `FlowEncounterState.build_final_snapshot()`. **Dominant vector display:** surfaced descriptively only (e.g. "Vanguard spirit") — never shown numerically (GDD §5.4). **EchoParty UI:** `DominantVectorLabel`, `CallingEligibleBadge` ("★ Calling awaits"), `AscendButton` ("▲ Ascend to Rank N"), and the rank-up overlay (`ui/overlays/RankUpOverlay.tscn`) are wired through `EchoPartyScreen`.

- PROG-007: **Calling Determination at Rank 3.** `CallingService` (`core/progression/CallingService.gd`) — pure static. `compute_all_options(echo, calling_cfg) → Array[OptionDict]` — always returns one entry per id in `calling_cfg.all_callings` (never filtered). Compatibility tier (first match wins): `"preferred"` (calling maps from dominant vector), `"compatible"` (non-dominant vector score ≥ `compatibility_threshold × total_score`), `"incompatible"` (vector score = 0), `"ambivalent"` (catch-all: score > 0 but below threshold). Seeker special rule: seeker vector maps to TWO callings (ranger + seer); preferred one determined by trait split (courage ≥ wisdom → ranger; wisdom > courage → seer); the other seeker-vector path is `"compatible"`. `confirm_calling(echo, chosen_calling_id, calling_cfg, logger, t) → String` — stores `echo["calling"]` permanently, erases `echo["calling_options"]`, applies emotional consequence matching tier: preferred → morale +10; compatible → morale −5; ambivalent → morale −3 AND fear +3; incompatible → fear +10. `is_calling_pending(echo) → bool` — true when `calling_eligible=true` and `calling` is empty. **Storage lifecycle:** `echo["calling_options"]` (Array) written at rank 3 in `execute_rank_up()` if `calling_cfg` provided; erased on confirm. `echo["calling"]` is permanent once set. **Action:** `sanctum.calling.confirm { echo_id, chosen_calling_id }` — handled by `FlowRuntime._handle_sanctum_calling_confirm()`. **Deferral contract:** calling is never forced; `calling_options` persists in save; EchoParty shows `⚡ Path Awaits` on pending echoes and opens `RankUpOverlay.show_calling(echo_id, options)` directly (no rank-up flow). **Post-rank-up overlay flow:** `show_reveal()` checks `calling_options`; ContinueButton label becomes "Choose a Path" if pending; tapping routes to CallingPanel; "Choose Later" (DeferButton) dismisses without confirming. **Config:** `balance.data.calling` — `compatibility_threshold`, per-tier emotion deltas, `vector_to_calling`, `seeker_trait_split`, `all_callings`, `definitions` (with `display_name`, `icon_key`, `description`, `benefits`, `downsides`, `vector`). **Extensibility rule:** adding a new calling = append to `all_callings` + `definitions` only; no code changes needed. `ProgressionService.execute_rank_up()` now takes `calling_cfg: Dictionary` as 5th param (after `birth_stats_cfg`); existing callers pass `{}` to skip calling_options generation.

- SANCTUM-005: **Echo Profile & Archetype Display.** Pure UI story — no new services or save_data keys. Three-tier calling display applied to all Sanctum-facing echo lists: (1) confirmed `echo["calling"]` → show calling name; (2) `calling_eligible=true` + no confirmed calling → "Calling Undecided"; (3) not yet eligible → hide calling section, archetype only. `calling_description` (one-liner from `balance.data.calling.definitions[id].description`) is surfaced in `flow.echo_party` per-echo detail data. `FlowEchoPartyState` rows include `archetype`, `calling`, and `calling_eligible`, and `EchoPartyScreen` detail panel renders the full profile.

- XP Tuning (post PROG-004): **Option A thresholds** `[0, 100, 300, 600, 1000]` — all XP config is tunable in `balance.data.progression`. **Rank base shift:** `rank_level_base_shift` (default 50) — each per-level step cost is increased by `(rank-1) × shift`; first step for rank 2 = 150, rank 3 = 200. `ProgressionService.get_effective_thresholds(rank, prog_cfg) → Array` is the single source of truth for thresholds — **never** use the raw `level_thresholds` array directly for a rank > 1. **Realm XP multiplier:** `realm_xp_multiplier_per_realm` (default 0.15) applied to `clear_xp` and `realm_xp` in `award_post_combat_xp()`; multiplier = `1.0 + run_index × rate` where `run_index` comes from the realm model in `save_data["realms"]`. **Mid-combat kill XP:** `ProgressionService.apply_mid_combat_kill_xp(echo, actor, prog_cfg, birth_stats_cfg, realm_xp_multiplier, logger, t) → event_dict`. Called from `FlowRuntime._resolve_next_actor()` immediately after `kill_count += 1` — only for `echo`-faction actors. If a level threshold is crossed, `DerivedStatService.compute_stats()` runs on both the save_data roster entry and the live `actor` dict; `current_hp` raised by hp_gained, capped at new `max_hp`. **No double-counting:** `award_post_combat_xp()` accepts `skip_kill_xp: bool = false`; `build_final_snapshot()` passes `true` because kill XP was already applied mid-combat. Stage and realm completion XP are still awarded post-combat. **Snapshot XP fields:** `FlowEchoPartyState` includes `xp_in_level` and `xp_per_level` per echo so `EchoPartyScreen` can render the XP bar without client-side threshold math.

- BOND-001: **Social Graph Contracts.** `SocialGraphService` is the single static API for all bond/encounter reads and writes. `bonds[]` + `party_encounters[]` live inside `save_data["sanctum"]` — additive, no schema_version bump. Party co-occurrence is recorded in `FlowRuntime._handle_sanctum_party_toggle` on every add (not remove). `bond_type` ("rival"/"neutral"/"friend") and `tier` are always derived at read time, never stored. All bond score triggers are config-defined in `balance.data.sanctum.bond_triggers` but fire only in BOND-002. The Bonds tab in EchoPartyScreen is always enabled (not gated by calling like Skills), showing `bond_entries[]` sorted most-negative first. `BondTierBar.tscn` is a fully .tscn-authored 11-cell visual bar — script only sets modulate + label text.

### Deferred
- Full art: StageScreen, StageMapScreen (scaffolds built; deferred to UI-006+)
- HP progress bar in RealmShell EchoBar (text label is current; bar deferred to UX pass)
- Voice reactive system: VOICE-001 (reactive bark responses — other actors respond to barks, deferred). Bark display: VOICE-002 (deferred). Bark snapshot fields + ShoutBank expansion: DONE (PROG-010).
- Multiple save slots (one slot is the current contract)
- Sanctuary upgrades affecting trait rolls (`generation_context` reserved for future modifiers)
