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
- Transactional: verify alternating `.pending_a`/`.pending_b`, rotate three validated backups, then promote; legacy `.tmp` remains recoverable
- Boot loads the highest valid `meta.save_generation`; invalid saves are never replaced by a new campaign
- Failed flushes remain queued for retry; tests must inject an isolated save path

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

**Entry:** `func set_snapshot(snap: Dictionary) -> void`
**Exit:** `signal action_requested(action: Dictionary)`

Rules:
- Screens read `snap["data"]` for display; `snap["actions"]` (typed as Dictionary) for slots
- Screens **never** call `dispatch()` directly
- Screens **never** read `FlowContext`, `SanctumState`, `SaveService`, or any sim internal
- `UISnapshotRenderer` is fallback-only for unknown snapshot types — **not** a base class
- All new screens implement the bespoke screen contract directly

**UI node discipline (short form):**
- Prefer scene-authored structure + theme variations over runtime-created UI nodes.
- Use lightweight nodes for lightweight jobs: status badges as `Label` variants, HP bars as `ProgressBar`.
- Avoid spacer-only `Control` nodes when container `separation`/margins can express the layout.
- Use specific node names (avoid generic `PanelContainer`) to keep styling/refactors safe.

### Shell Routing Model (INFRA-001)
AppRoot routes `snapshot.type` → shell → bespoke screen.

| Shell | File | Snapshot types |
|-------|------|---------------|
| `SanctumShell` | `ui/shells/SanctumShell.gd` | flow.sanctum, flow.summon, flow.echo_party, flow.realm_select, flow.vow_manage, flow.weaving_rite |
| `RealmShell` | `ui/shells/RealmShell.gd` | flow.stage_map, flow.stage, flow.stage_explore, flow.encounter, flow.keeper_trial, flow.resolve |

`AppRoot` remains the application composition root. It owns runtime boot/dispatch,
shell and onboarding routing, save recovery, economy timing, debug/test entry points,
responsive layout coordination, and the single app-wide blocking `ModalHost`.
`ScreenHost` is full viewport; shells own their content-safe frames and persistent
chrome reservations.

`flow.resolve` remains a flow state because its core transition still owns combat
teardown, emotion drift, and progression side effects. Its UI is presented through
the AppRoot `ModalHost` as modal id `realm.resolve`, over the still-mounted Realm
screen. Do not remove the state until those core responsibilities have another
explicit owner.

### Responsive UI, Safe Area, and Layer Contract

**Runtime:** Godot 4.6.1. Landscape-only. Design base `1280×720`; initial desktop
window `1600×900`; desktop minimum `960×540`. The window is resizable and HiDPI
aware, using `canvas_items`, fractional scaling, and `expand`.

`ResponsiveLayoutController` owns window-to-layout conversion and emits:

```gdscript
signal layout_changed(layout: Dictionary)

{
  "profile": StringName,   # compact | standard | wide
  "logical_size": Vector2,
  "safe_insets": Vector4,  # left, top, right, bottom in logical units
  "ui_scale": float,
  "is_mobile": bool,
}
```

- Desktop scale: `clamp(min(width / 1280, height / 720), 1.0, 1.25)`.
- Phone landscape targets about `960×540` logical space, capped at `2.0`.
- Tablet/foldable landscape targets about `1280×720`, capped at `1.5`.
- Mobile profile detection prefers physical size/DPI and falls back to aspect ratio.
- Physical OS safe-area rectangles are converted through the inverse viewport
  stretch transform before logical margins are applied.
- Profile thresholds use safe logical space: compact below `1200×680`, standard
  below `1440×810`, otherwise wide.
- Wide layouts stop enlarging capped panels/chrome and give surplus room to the
  Sanctum, exploration, and combat spatial fields.

**Composition rule:** responsive means recomposition through authored containers,
profile-specific columns/visibility/margins/wrap widths, and readable maximum panel
widths. Do not uniformly scale individual screen roots, reparent UI dynamically, or
solve ordinary primary layouts by adding scroll containers everywhere. Scroll only
bounded long-content regions where content can genuinely exceed the available space.

**Safe-content rule:**
- Actionable content keeps at least `max(16, OS safe inset)` from each edge.
- Screen content excludes persistent bottom chrome plus an 8-unit gap.
- Persistent `EchoBar` and `BottomRail` are inset from the bottom and sides; neither
  is full-width edge-to-edge.
- All interactive targets are at least `48×48`; primary CTAs are 56 high; adjacent
  targets keep at least 8 units separation.
- Full-bleed spatial/world presentation may extend outside the safe frame; actionable
  content may not.

**Canonical layers:**

| Layer | Responsibility |
|---:|---|
| 0 | Full-bleed world/spatial presentation |
| 10 | Active screen content |
| 20 | Persistent EchoBar, Sanctum rail, and navigation chrome |
| 30 | Non-modal transients: barks, transitions, placement controls, notifications |
| 40 | AppRoot blocking `ModalHost` |
| 128 | Recovery, debug, and emergency UI |

Every shell-owned `CanvasLayer` must mirror `is_visible_in_tree()`. Hiding a shell or
one of its ancestors must disable both drawing and input for its world, content,
chrome, and transient layers before another shell becomes interactive.

**UI-only interfaces:**
- `ResponsiveLayoutController.layout_changed(layout)`
- `ResponsiveLayoutController.current_layout()`
- `Shell.set_layout(layout)`
- `Screen.modal_requested(modal_id, payload)`
- Modal scenes implement `present(payload)`, emit `action_requested(action)`, and
  may emit `dismiss_requested()`.

These interfaces do not alter snapshots, action dictionaries, simulation state, or
core contracts. Scene structure stays authored in `.tscn`; scripts set responsive
values and rendered state only.

**Blocking modal contract:**
- Exactly one blocking modal may be active.
- The layer-40 root and dim backdrop cover the full viewport, including shell chrome
  and device cutouts. The decorative backdrop ignores input; the full modal input
  root stops it.
- Modal cards remain inside the logical safe area. Long bodies may scroll while
  authored headers, footers, and required CTAs stay reachable.
- Opening records prior focus, moves focus to an authored safe action, contains focus
  within the modal, and restores prior focus on dismissal.
- Re-presenting the same modal id updates its payload; a different blocking modal is
  rejected until the active one closes.

**Responsive verification:** run both commands behind the exact 200-second watchdog:

```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --check-only --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext -- tests
```

Desktop resize acceptance uses a standalone/editor-launched OS window. The embedded
Godot game dock follows editor-dock sizing and is not evidence that standalone
window resizing works.

**Shell-cached nav pattern (UI-002):**
- SanctumShell owns the persistent bottom rail — NOT injected into every sanctum-family snapshot
- On `flow.sanctum`: shell caches all `nav.*` and `cta.*` slots from `snap.actions` → `_cached_nav`
- All other sanctum-family screens inherit the cached rail actions unchanged
- This keeps SummonState, EchoPartyState, etc. free from nav injection

**RealmShell echo bar pattern (UI-005):**
- RealmShell owns the persistent EchoBar (88 logical units high) — NOT rendered by individual screens
- The bar is horizontally centered, keeps safe side/bottom insets, and caps at 1440
  logical units. Overflow is clipped and horizontally scrollable.
- `_update_echo_bar(snap)` is called on **every** `set_snapshot()` — always reflects latest HP + emotional state
- Data source by snapshot type:
  - `flow.encounter` / `flow.resolve` → filters `data.actors` by `faction == "echo"`
  - `flow.stage` / `flow.stage_map` / `flow.stage_explore` → reads `data.party_preview`
- HP label shown only when `hp`/`max_hp` fields are present (encounter/resolve only)
- Emotion label: `emotional_status` in combat; `calling_origin` pre-combat (defaults to "Ready")
- Realm screens receive the persistent-chrome exclusion and reserve content above it.
- **GUIDE_SPIRIT spirit slot (V2-STAGE-004 P3c):** when `data.actors` contains an actor with `is_spirit == true`, RealmShell appends it as a **distinct last EchoBar slot** via `EchoCardItem.setup_spirit()` — a ◆ SPIRIT badge, gold accent StyleBox (`EchoCardSpiritAccent.tres`), and an HP + objective-progress line. It reads as "one of the party" but stays visually distinct.
- **Temporary Ally slot (V2-STAGE-004 P4):** when an actor carries `is_ally == true`, `EchoCardItem.setup_ally()` promotes its card to the Mist Blue `#7AB5C8` "⊕ ALLY" badge + `EchoCardAllyAccent.tres` border — the same "one of the party but visually distinct" treatment as the spirit slot, in a different accent family. Never applied together with `setup_spirit()` on the same card.

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
- Key FlowContext fields: `sim_tick`, `last_snapshot`, `pending_party_ids`, `selected_summon_grade`, `encounter_ctx`, `encounter_machine`, `encounter_id`, `save_data`, `save_request`, `logger`, `dev_combat_objective`, `vow_outcome` (V2-VOW-002: transient vow break/benefit dict for ResolveScreen; cleared on every stage entry)
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
- `init_echo(echo, logger, t)` — idempotent. `morale_base` = 25–74 from `traits.courage` + archetype modifier
- `apply_morale_delta(echo, delta, cause, logger, t)` — only valid drift entry
- `apply_fear_delta(echo, delta, cause, fear_threshold, logger, t)` — only valid drift entry
- `get_morale_tier(morale_current)` → `"inspired"` / `"steady"` / `"shaken"` / `"broken"` — **internal sim use only** (BehaviorArbiter, ActorStateMachine). Do NOT use for player-facing display.
- `get_emotional_status(morale, fear)` → unified player-facing tier (V2-EMOTION-002) — **the only emotion display field**

**Emotional status tiers (10, best → worst):** derived from both `morale_current` and `fear_current`. The derivation evaluates the five severe conditions first, then the positive conditions, with `hesitant` as fallback. This ordering means severe fear or low morale always overrides a positive threshold.

| Order | Tier | Exact derivation condition |
|---:|---|---|
| 1 | `radiant` | morale ≥ 70 and fear ≤ 15 |
| 2 | `whole` | morale ≥ 55 and fear ≤ 30 |
| 3 | `grounded` | morale ≥ 40 and fear ≤ 40 |
| 4 | `uncertain` | morale ≥ 35 and fear < 45 |
| 5 | `hesitant` | fallback after all other conditions |
| 6 | `burdened` | fear ≥ 45 or morale ≤ 24 |
| 7 | `pressed` | fear ≥ 55 or morale ≤ 20 |
| 8 | `strained` | fear ≥ 65 or morale ≤ 15 |
| 9 | `fraying` | fear ≥ 75 or morale ≤ 10 |
| 10 | `hollow` | fear ≥ 85 or morale ≤ 5 |

**Rule: Never build separate morale and fear display fields.** `emotional_status` is the single player-facing emotion field in all snapshots. All screens read this one field. Dual display (morale_tier + fear_signal) is explicitly forbidden.

**Snapshot contract:** every actor/echo/party entry that surfaces emotion to the UI carries:
```
"emotional_status": String  # one of the 10 tiers above
```
The `refused` bool in `emotion_summary` (Resolve) is kept as a factual combat outcome — it is not a display tier.

**Combat persistence and projection:** mid-combat morale/fear mutate runtime actor dicts directly. `FlowEncounterState.build_final_snapshot()` copies each Echo actor's final `fear` and `morale` back to the roster before resolve actions are offered, so both `cta.continue` and stage-completion/next-stage paths retain the combat state. Combat actor projections expose `emotional_status` only: raw `fear`/`morale` and legacy `morale_status`, `fear_signal`, `emotional_readiness`, `morale_tier`, and `refuse_cause` are omitted. Projected `status` is operational only: `dead`, `guarding`, or `alive`; fear never changes that field.

**Shared UI presentation:** `ui/components/EmotionPresentation.gd` is the single status normalizer and maps all ten statuses to display names and theme variations. Colors and chip/text treatments come from `assets/theme/LivingTreeSystem.tres` (`EmotionChip*`, `EmotionChipLabel*`, `EmotionStatus*`). UI screens and token layers must use this shared presentation source, not local status palettes.

### LeadershipEmotionService (`core/combat/LeadershipEmotionService.gd`)
Pure deterministic helpers for configured Whole-band combat emotion effects. A leader must be a living Echo whose hidden maturity-expression band resolves to `whole`; leaders never affect themselves, dead actors, non-Echo actors, or allies outside the configured Chebyshev radius. A trait-specific `radius` overrides the calling's `leadership_radius`.

Configured emotion traits:

| Trait | Effect |
|---|---|
| `inspire_aura` | +3 morale per leader turn to nearby living Echo allies |
| `steady_presence` | +2 morale per leader turn to nearby living Echo allies within radius 2 |
| `calm_fear` | −15 fear from the most fearful nearby living Echo ally |
| `fear_read` | −5 fear per leader turn from the most fearful nearby living Echo ally |
| `rally_call` | +10 morale to nearby living Echo allies, once per combat |
| `kill_momentum` | +8 morale to living Echo allies within radius 1 when the leader gets a kill |
| `fearless_example` | incoming fear ×0.7 for living Echo allies within radius 2 |
| `calm_transmission` | propagated fear ×0.3 for living Echo allies within radius 3 |
| `block_contagion` | blocks propagated fear for living Echo allies within radius 2 |
| `morale_anchor` | morale loss ×0.5 for living Echo allies within radius 2 |
| `morale_forecast` | prevents morale loss for three inclusive rounds, once per combat |

**Combination rules:** overlapping fear/morale reductions use the strongest applicable factor; they never multiply. `block_contagion` therefore wins for propagated fear, and an active `morale_forecast` wins over `morale_anchor`. Positive direct recovery from separate leaders stacks, while all values remain clamped to 0–100. The shared fear-gain path covers hit fear, surprise fear, round fear, near-death fear, ally-KO/witness propagation, and overwhelm; the shared morale-loss path covers shrine drain, periodic decay, and no-damage helplessness.

### EmotionRecoveryService (`core/emotion/EmotionRecoveryService.gd`)
Sanctum recovery piggybacks on `economy.settle_time`, including the four-minute bank interval and Continue/session settlement. Base rates are config-driven: +1 morale/min toward `morale_base` and −0.5 fear/min toward zero. Recovery uses the offline cap/decay model, per-Echo recovery modifiers, and the configured maturity fear-recovery bonus. `economy.last_emotion_settle_unix` is persisted whenever an elapsed window is consumed—even when rounding or clamps produce no emotion delta—so that window cannot be settled twice.

### GridService (`core/grid/GridService.gd`)
Pure static. Default board 10×10 (from `balance.json data.grid`); **irregular landscape boards** since V2-STAGE-004 P3a (see below).
- `place_actors(echo_actors, enemy_actors, board_cfg, rng)` → deterministic faction placement
- `manhattan_distance(a, b) -> int` — direction heuristic used by `_greedy_step()` internally; do NOT use for range checks
- `chebyshev_distance(a, b) -> int` — true step cost for 8-dir movement; use for all range checks and AI distance awareness
- `is_adjacent(a, b) -> bool` — Chebyshev == 1; use for melee range, engagement checks
- `move_toward(actor, target_pos, board_cfg) -> { from_pos, to_pos }` — 8-dir greedy, mutates `actor["grid_pos"]`
- `is_valid_pos(pos, board_cfg) -> bool`

**Walkable terrain (V2-STAGE-004 P3a):** combat boards are now irregular `StageTerrain` landscapes. The walkable set rides inside `board_cfg["walkable"]` — a `Dictionary` of `"col,row"` string keys (output of `StageTerrain.walkable_set(terrain)`). **Empty/absent `"walkable"` ⇒ LEGACY all-walkable rectangle, byte-identical to before (the regression keystone).** When present:
- `place_actors` packs each faction onto walkable cells only (echoes leftmost cols, enemies rightmost); the walkable branch makes **zero RNG draws** (the placement `rng` is not reused downstream — no draw-order shift).
- `move_toward` steps over walkable terrain via `StageTerrain.bfs_distance_field`/`next_step` (never enters void; routes over bridges).
The walkable set is threaded by `FlowEncounterState.enter()` (placement) and `FlowRuntime._resolve_next_actor()` (movement). See "Combat resolution modes & boards" below and `docs/combat-modes.md`.

### Combat resolution modes & boards (V2-STAGE-004 P3a)
`EncounterResolutionModes.gd` defines the **closed set of seven** combat modes, one `combat` family, const names = string values **1:1 with objective types**: `COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PROTECT`, `ENDURE`, `PURSUE`, `GUIDE_SPIRIT`. (Renamed from V1 stubs: `SURVIVAL`→`ENDURE`, `PROTECT_TOTEM`→`PROTECT`.) Authored per-mode mechanics live in `docs/combat-modes.md`. `FlowEncounterState._resolve_mode_from_stage()` maps `objective.type` → mode. All seven modes now have live win/lose conditions: shrine→PURIFY_SHRINE, recover→RECOVER, protect→PROTECT, endure→ENDURE (Phase 3), pursue→PURSUE (Phase 3b), guide_spirit→GUIDE_SPIRIT (Phase 3c), all else→COMBAT.

**Irregular combat boards:** `FlowEncounterState.enter()` generates the board via `StageTerrain.generate(realm_seed, stage_index, signature, bounds, "combat.terrain." + encounter_id)` — same generator as exploration, append-only RNG namespace, keyed to the realm's **virtue signature** (`data.stages.map_shape.by_virtue`). Board **bounds scale with realm completion order** (`data.combat.board`: base 12×12 → +growth/completion → max 22×22). **PURSUE exception:** board is always 2× one dimension (randomised wide or tall per encounter seed via `data.combat.board.pursue_override.long_multiplier`, default 4.0; both orientations possible). `long_multiplier` is applied **POST-clamp** — PURSUE boards intentionally exceed the `max_cols`/`max_rows` cap that governs all other modes. **Escape-edge contract:** the escape condition fires only at the far end of the long axis (`col >= board_cols - 2` for wide boards, `row >= board_rows - 2` for tall boards); short sides are not escape edges. Terrain stored transiently on `EncounterContext.terrain` (not saved). Objective-actor placement (shrine now; relic/entity/quarry/npc later) scales **depth by completion order** via `data.combat.objective_placement` (early realm → central/reachable; late realm → deep among enemies). `CombatBoardScreen` paints only walkable cells (void = no tile, no fog). **PURSUE camera:** `CombatBoardScreen` auto-follows the quarry via manual board repositioning (`_process` lerp); player can pan (2-finger drag) or zoom (pinch) to override — auto-follow resumes after `_PAN_RESUME_DELAY` (3 s). `CombatState.create(..., objective_params={})` carries per-mode tuning.

**Per-mode win/lose conditions (V2-STAGE-004 Phase 3 + Distinctiveness — `CombatState.check_end_condition(actors, objective, combat_state={})`):**

`all_enemies_defeated` is the **universal first win** check — fires before any mode-specific check **except ENDURE** (see below). COMBAT and PURIFY_SHRINE are byte-identical to pre-P3 (pass empty `combat_state={}`). Mode-specific branches:

| Mode | Win condition | Lose condition |
|------|--------------|---------------|
| RECOVER | `combat_state["relic_secured"]` = true (`hold_counter ≥ hold_rounds`) | `all_echoes_dead` |
| PROTECT | `combat_state["protected"]` = true (`protect_counter ≥ duration_turns`); **proximity-gated** — counter advances only when a living echo is within `protect_guard_radius` (Chebyshev, default 2) of entity, **resets to 0 when unguarded**; if `totem_stolen` at win moment → `totem_taken` defeat | `combat_state["entity_lost"]` = true (entity hp → 0) OR `all_echoes_dead` |
| ENDURE | `combat_state["endured"]` = true (`round_counter ≥ duration_turns`); `all_enemies_defeated` victory is **suppressed until `all_waves_spawned`** = true (no transient-lull early-win); `all_echoes_dead` defeat fires even in the lull | `all_echoes_dead` |
| PURSUE | contain the quarry — hold an echo adjacent for `contain_rounds` consecutive rounds before the escape window closes (Phase 3b) | `quarry_escaped` (quarry reaches the far end of the long axis) OR window timer expires OR `all_echoes_dead` |
| GUIDE_SPIRIT | **escort:** `combat_state["destination_reached"]` = true → `spirit_escorted` (priority over `all_enemies_defeated`, mirrors PURSUE). **protect:** `guide_protect_counter ≥ duration_turns` → `spirit_protected` — **guard-to-count**: the counter advances only on rounds a living echo is within `escort_radius` (Chebyshev, default 2) of the living spirit and **NEVER resets** (accumulates), so a bare round timer no longer wins — the party must actually reach the spirit. On `spirit_protected` win the final snapshot sets `guide_spirit_protected: true` (V2-ITEM-002 free-summon seam, flag only) | `spirit_killed` (spirit dead — early guard, takes priority over kill-win) OR `all_echoes_dead` (a **joined** spirit is excluded from the `all_echoes_dead` check) |

**Objective-actor spawn (`FlowEncounterState`):** RECOVER relic placed **deep** (high `objective_depth`); PROTECT entity placed **mid-field**; both spawn as `StructureActor` on walkable cells. GUIDE_SPIRIT spirit placed **deep** — `StructureActor` (non-joining escort, faction `"structure"`) or `EnemyActor` with faction `"echo"` when it **joins** (Phase 3c, below). Depth scales via `data.combat.objective_placement` by realm completion order. Unscouted approach triggers a **surprise party-fear bump** (`data.combat.encounter_approach.surprise_fear`, fear only — NO initiative re-sort).

**`_resolve_mode_from_stage(stage)` mapping:** `recover` → RECOVER; `protect` → PROTECT; `endure` → ENDURE; `pursue` → PURSUE; `guide_spirit` → GUIDE_SPIRIT; all others → COMBAT (shrine handled separately in encounter_approach routing). `resolve_objective_params(mode_key, mode_cfg, completion_index, stage_params)` is pure static — floats scaled by completion order, clamped, stage `params` override.

**ENDURE wave spawn (`FlowRuntime._end_round`):** deterministic wave actors appended each round via `combat.wave.<id>.<round>` (append-only RNG namespace); appended to END of `initiative_order` — no re-sort. Wave size rises each wave by `wave_size_rising_step` (clamped to `wave_size_max`). `combat_state` tracks `waves_spawned`, `total_waves`, `all_waves_spawned`. `hold_counter` (RECOVER) also incremented here for echoes adjacent to relic. Both paths pass `combat_state` to `check_end_condition`.

**~~Known limitation~~:** ~~ENDURE can end early on an empty-wave-lull~~ — **RESOLVED** by the Distinctiveness pass. `all_enemies_defeated` is now suppressed for ENDURE until `all_waves_spawned = true`.

**Mode-distinctiveness mechanism (V2-STAGE-004 Distinctiveness pass):** per-mode "directive-weight context" is **injected additively** into `BehaviorArbiter.select_intent()` — merged onto the player's current directive `intent_weights`, never mutating the directive itself. Dormant situational conditions (`objective_in_range`, `objective_threatened`) are activated with real multipliers. Per-turn ctx carries `resolution_mode`, `totem_stolen`, `totem_carrier_id` which the arbiter reads.

- **RECOVER:** designated holder (deterministic: speed→agi→id, stored as `recover_holder_id`) gets advance/hold directive weights via injected context; `objective_in_range` situational fires when holder is adjacent to relic (digs in); enemies get `prefer_objective_target`; **relic-seeking reinforcement** trickles from far edge each `reinforce_interval` rounds (`reinforce_size` actors per wave, up to `reinforce_max_total`), appended to END of initiative_order (no re-sort, no new RNG draws beyond existing wave namespace). **Relic: invulnerable + no HP bar** (UI draw-gated on `is_objective_relic`).
- **PROTECT:** echoes interpose via `objective_threatened` situational + target overrides (intercept nearest-to-totem enemy; focus-fire carrier when stolen). **Theft:** enemy ending adjacent to an unguarded totem rolls `theft_chance` (RNG `combat.theft.<encounter>.<round>`, ≤1 draw/round) → becomes carrier + deals `double_damage_mult` damage; echoes focus-fire to recover it; carrier death clears theft. `totem_stolen` / `totem_carrier_id` written to `combat_state` and threaded to ctx each turn.
- **ENDURE:** rising wave curve only; no defensive-default bias injected. Dual-win: survive-to-N OR clear-all (only after `all_waves_spawned`).
- **PURIFY_SHRINE:** ring-defend `directive_intent_weights` injected for **NON-purifier echoes only** (purifier target selection untouched).

**New `combat_state` fields (Distinctiveness):** `recover_holder_id` (String), `recover_reinforce_count` (int), `waves_spawned` (int), `total_waves` (int), `all_waves_spawned` (bool), `totem_stolen` (bool), `totem_carrier_id` (String), `protect_counter` (int).

**New `objective_state` snapshot fields (Distinctiveness):** `objective_invulnerable` (bool — suppresses HP bar draw), `waves_remaining` (int), `wave_total` (int), `totem_stolen` (bool), `protect_progress` (int), `protect_required` (int).

**New balance keys (Distinctiveness — under `data.combat.objective_modes`):**
- `recover`: `directive_intent_weights {}`, `reinforce_interval`, `reinforce_size`, `reinforce_group`, `reinforce_max_total`
- `protect`: `directive_intent_weights {}`, `objective_threatened_radius`, `theft_chance`, `double_damage_mult`, `protect_guard_radius`
- `endure`: `wave_size_rising_step`
- `purify_shrine`: `directive_intent_weights {}`
- `data.actor.situational_muls.objective_in_range` and `objective_threatened` (real non-stub multipliers)

**Known limitations (Distinctiveness):** `objective_threatened_radius` defaults to 3 in the arbiter — tuning `data.combat.objective_modes.protect.objective_threatened_radius` in the JSON has no effect until that key is threaded from `data.combat` into the arbiter's `data.actor` `_cfg`. RECOVER holder gets no directive weight on round 1 (designated at first `_end_round`). PURIFY sharpen applies to non-purifier echoes only. A pre-existing PURIFY purifier-passivity bug (morale collapse → idle) is tracked as a separate future fix.

**GUIDE_SPIRIT mode (V2-STAGE-004 Phase 3c):** find a **NameBank-named spirit** (`is_spirit: true`, id `guide_spirit_01`), then either **protect it in place** or **escort it to a destination**. The `guide_mode` (protect|escort) is **seeded 50/50 per encounter**; whether the spirit **joins the battle** is a second seeded 50/50 roll.

- **Spirit actor.** Spawned **deep** (same depth scaling as RECOVER). Non-joining → `StructureActor` (faction `"structure"`, board movement owned by `_end_round`). Joining → `EnemyActor` with faction `"echo"` — a **fully-active ally** driven by `BehaviorArbiter`, with `_spirit_damage_mul` (0.75) applied in `CombatService._resolve_melee`. A joined spirit's HP bar is **NOT** suppressed.
- **PROTECT variant — guard-to-count.** A skittish spirit flees **1 deterministic away-step** when an enemy is within `skittish_radius` (3) and no echo is adjacent. Win = `guide_protect_counter ≥ duration_turns`; the counter advances **only** on rounds a living echo is within `escort_radius` (2, Chebyshev) of the living spirit and **NEVER resets** (accumulates). Reason `"spirit_protected"` sets `guide_spirit_protected: true` in the final snapshot (V2-ITEM-002 free-summon seam — flag only; reward wiring deferred).
- **ESCORT variant.** The spirit steps **1 cell/round** via `StageTerrain.next_step` toward the destination **only** when `escort_started` (a first-adjacency latch) AND a living echo is within `escort_radius`; if the next cell is occupied it waits. Win `"spirit_escorted"` on `destination_reached` (priority over `all_enemies_defeated`, mirrors PURSUE). Destination = a **seeded random walkable EDGE cell**, min-distance-guarded.
- **Both variants.** Spirit killed → `"spirit_killed"` defeat (early guard, priority over kill-win). A **joined** spirit is excluded from the `all_echoes_dead` check.
- **End-priority ladder:** 0 PURSUE `quarry_escaped` → **0b GUIDE_SPIRIT `spirit_killed` / `spirit_escorted`** → 1 `all_enemies_defeated` → … → 9 GUIDE_SPIRIT protect guard-to-count win.

**GUIDE_SPIRIT board override:** long/winding board via `data.combat.board.guide_spirit_override.long_multiplier` (5.0), randomised wide-or-tall per encounter seed (same POST-clamp exception as PURSUE — intentionally exceeds `max_cols`/`max_rows`).

**New `combat_state` fields (GUIDE_SPIRIT):** `guide_mode` (String), `spirit_id` (String), `spirit_joins_battle` (bool), `escort_started` (bool), `destination_col` (int), `destination_row` (int), `destination_reached` (bool), `guide_protect_counter` (int). `guide_mode` / `spirit_joins_battle` / destination are seeded via `objective_params` into `CombatState.create()`.

**New `objective_state` snapshot fields (GUIDE_SPIRIT):** `guide_mode`, `spirit_alive`, `spirit_hp`, `spirit_name`, `spirit_joins_battle`, `destination_reached`, `destination_pos`, `rounds_remaining` (= `duration_turns − guide_protect_counter`).

**New RNG namespaces (GUIDE_SPIRIT, append-only):** `combat.guide_mode.<enc>`, `combat.guide_spirit_joins.<enc>`, `combat.spirit_name.<enc>`, `combat.spirit_destination.<enc>`, `combat.guide_spirit_board.<enc>` (all seeded per encounter; dev overrides use draw-then-override to preserve RNG order).

**New balance keys (GUIDE_SPIRIT):** `data.combat.objective_modes.guide_spirit` block (incl. `escort_radius`, `skittish_radius`, `spirit_damage_mul` 0.75, `spirit_def_id`, `duration_turns`, growth keys), `data.combat.board.guide_spirit_override.long_multiplier`, `data.stages.objective_types.guide_spirit` (UI entry). `pursue` + `guide_spirit` appended to both realms' `objective_pool` and the `foundation_objective_pool`. `resolve_objective_params` `"guide_spirit"` arm propagates ALL balance keys.

**GUIDE_SPIRIT barks:** `data/bark/spirit_barks.json` — 4 contexts (`spirit_first_adjacency`, `spirit_escort_start`, `spirit_guide_win`, `spirit_killed`), loaded via `FlowRuntime._load_spirit_barks()` (contact_responses lazy-load pattern), fired via `_fire_spirit_bark` (posmod variation) into `round_bark_events`.

**GUIDE_SPIRIT dev override:** `combat_objective guide_spirit [protect|escort] [join|nojoin]` sets `FlowContext.dev_guide_mode` / `dev_guide_joins`; both use draw-then-override so the seeded RNG order is preserved.

**Known limitations (GUIDE_SPIRIT):** escort has no timeout — a permanently blocked path (should not occur given `StageTerrain` guarantees ≥2-wide bridges) would stall the escort. `ActorService.get_threatened_ally` may select the joined spirit as a guard target (accepted as thematic). A joined spirit's arbiter move intents run, but board movement is owned by `_end_round` only for STRUCTURE spirits — the joined spirit moves freely under the arbiter.

**`next_step` target-directed pathing contract (V2-STAGE-004 Phase 3, `StageTerrain.next_step(from, dist_field, walkable, target={})`):**
Among neighbours that share the minimum BFS distance, `next_step` tiebreaks **toward the target** (chebyshev-distance → then manhattan → then stable sort). The `target` dict (`{"col":int,"row":int}`) is threaded from both callers — `GridService.move_toward` (combat movement) and `FlowRuntime._handle_stage_advance_turn` (exploration). Without the target, equal-BFS neighbours were resolved by sort order, producing a systematic up-left/top-left drift visible in both game modes. **Contract: never call `next_step` without a target when directional fidelity matters.**

**Actor-id uniqueness invariant (V2-STAGE-004 Phase 3):**
Combat requires every actor to have a **unique, non-empty id**. Duplicate or empty ids freeze the id-keyed round loop. Enforcement is three-layer:
1. `SaveService` — repairs empty/duplicate echo ids at load, preserving id→roster attribution.
2. `ActorSchema.validate()` — fails on empty `id` field (use `has_all_required_fields()` for structural-only checks that should not fail on empty id).
3. `FlowEncounterState._ensure_unique_actor_ids()` — guards at encounter assembly before actors are passed to `CombatState.create()`.

`EchoActor.from_echo(echo)` uses `has_all_required_fields()` as a build-assert (structural check only). Never call `validate()` on a freshly-built EchoActor dict before its id is assigned.

### V2-STAGE-004 Phase 4 — Conversation→Combat Seams, Earned Return Recruitment & Contribution Ledger (STORY NOW DONE)

Closes the last STAGE-004 gap: STAGE-003 conversation outcomes now reach combat, and a surviving companion can be earned into the roster. **Suite: 882 tests, all passing.**

**Temporary Ally auto-join (`core/actors/ContactActorBuilder.gd`, pure static, mirrors the P3c joined-spirit build):**
- `ContactActorBuilder.build(contact: Dictionary, cfg: Dictionary, t: int, level: int) -> Dictionary` — builds an echo-faction combat actor from a good `temporary_ally` `ContactModel` via `EnemyActor.from_definition(defn, t, actor_cfg)` (`data.actor.enemy_types.temporary_ally` is the stat template — a `ContactModel` carries no combat stats of its own). Sets `faction:"echo"`, `is_ally: true`, `_ally_damage_mul` (config `data.contact.ally.damage_mul`, default 0.75, applied in `CombatService._resolve_melee` the same way `_spirit_damage_mul` is), and a deterministic `archetype_birth` (`PersonalityArchetype.from_traits`) so `RecruitmentService` never has to re-derive it later.
- `FlowEncounterState.enter()` injects the built ally PARTY-SIDE on a walkable cell when `explore_map.ally_contact` is set and `ally_consumed_in_encounter` is false.
- `CombatState.check_end_condition`'s `all_echoes_dead` check excludes `is_ally == true` actors, the same way it already excludes `is_spirit == true` (P3c).
- Consumed after exactly ONE battle: `explore_map.ally_consumed_in_encounter` set `true` once the ally has fought.
- Ally death → a small party morale/fear knock, applied to all OTHER living echoes (never to spirit/ally recipients themselves).
- Visual: ⊕ ALLY badge in Mist Blue `#7AB5C8`, `EchoCardAllyAccent.tres` board-token ring — same visual family as the P3c spirit gold accent, distinct color.

**Failed Claimant → immediate combat:** on a hostile Claimant outcome, `FlowRuntime._apply_contact_outcome()` sets `flow_ctx.active_encounter_objective_index = -1` (forces `COMBAT` mode, bypassing the stage's normal objective) and `explore_map.combat_intro_reason = "claimant_hostile"`, then transitions to `flow.encounter`. `FlowEncounterState` reads `combat_intro_reason` and, when it equals `"claimant_hostile"`, surfaces `data.contact.claimant.combat_intro_line` on the pre-battle panel.

**Failed non-objective Charge → pressure (not immediate combat):** a failed non-objective Charge conversation instead sets `explore_map.hostile_charge_sit_id` (no immediate transition). The marker is consumed **exactly once**, by the objective-params of the first PROTECT or ENDURE combat fought afterward (`FlowEncounterState`, reads `data.combat.charge_pressure`): PROTECT gets `+protect_duration_bonus` added to `duration_turns`; ENDURE gets `+endure_wave_bonus` added to wave size (both clamped). `flow_ctx.encounter_ctx.charge_pressure_applied` is set on the encounter that consumes it and surfaces as `objective_state.charge_pressure_applied`; `ObjectiveBanner` shows an Amber "Pressure raised" marker. Parallels the existing unscouted-approach `surprise_fear` modifier (P3a) as a second config-driven pre-combat pressure lever.

**RecruitmentService (`core/sanctum/RecruitmentService.gd`, pure static) — "Earned Return":**
- `compute_recruit_chance(ally_actor, source_contact, party_echoes, contribution_entry, rounds_total, cfg) -> { chance, conversation, combat, fit }` — additive, base 0, `chance = clampi(conversation + combat + fit, 0, cfg.cap)` (`cap` default 75). Three components, each a POINT allocation (not a fraction) capped at its own `cfg.*_max`:
  - `conversation` ∈ `[0, conversation_max]` — blend of talk-quality (final morale/fear vs. `conversation_good_fear_max`/`conversation_good_morale_min`) and engagement (`conv_score_sum` / `winning_turns` ratio).
  - `combat` ∈ `[0, combat_max]` — remaining-HP ratio, rounds-survived ratio, offensive output (`damage_dealt + kills×baseline`) normalized against `combat_subweights.offensive_damage_baseline` — **this is the contribution ledger's first consumer**.
  - `fit` ∈ `[0, fit_max]` — vector-profile cosine similarity (contact virtue wheel → `vector_scores` keyspace via `cfg.vector_to_virtue_primary`), archetype match/rival bonus (`SocialGraphService.is_rival_archetype_pair`), and derived-stat closeness vs. the party average.
  - **Invariant:** the three returned ints always sum to exactly `chance`. When the raw sum exceeds `cap`, components are rescaled down via the largest-remainder method (floor each exact share, hand out the leftover one unit at a time to the largest fractional remainders) — never via independent rounding, which could break the sum.
- `roll(chance: int, rng: RandomNumberGenerator) -> bool` — single seeded draw (`rng.randi_range(1,100) <= chance`); `rng` must already be seeded by the caller under the append-only namespace `combat.<encounter_id>.ally_recruit`. Honors `FlowContext.dev_force_recruit` via draw-then-override (RNG order preserved even when the debug override fires).
- `promote_ally_to_echo(ally_actor, source_contact, save_data, cfg_data, logger, t) -> String` (returns new `echo_id`) — a **direct builder, NOT `EchoFactory`** (EchoFactory's v1/v2 RNG draw order is immutable and a recruited companion has no RNG-driven birth). Mints a roster echo: `origin: "recruited_ally"`, `rarity: "uncalled"`, `rank: 1` / `level: 1` (Standing 1), traits carried from the ally's battle build, stats re-derived fresh via `DerivedStatService.compute_stats()`, `vector_scores` built from the source contact's `virtue_primary`/`virtue_secondary`. **Seeds a NEGATIVE companion bond debuff** (`data.contact.recruitment.companion_bond_debuff`, default −30) against every roster echo that existed before the promotion, via `SocialGraphService.apply_score_delta()`.
- **Gate (enforced by the caller, not this service):** ally must be ALIVE at battle end AND the encounter must be a VICTORY.

**Companion invite is a SANCTUM EVENT — design change from the original plan (a Resolve-panel accept/decline).** A successful `roll()` writes a durable `sanctum.companion_invite` dict (ONE pending max — a no-stack guard discards a second success while one is already pending, logged `sanctum.companion_invite.discarded`). `FlowSanctumState.build_snapshot()` projects it as `data.companion_invite` (`{}` when none pending). `SanctumScreen` requests modal id `companion_invite`; AppRoot presents the blocking `CompanionInviteModal` on every Sanctum entry until the player decides, including across sessions. Actions `sanctum.companion.accept` (`FlowRuntime._handle_companion_accept`, calls `promote_ally_to_echo()` then clears the invite) / `sanctum.companion.decline` (`FlowRuntime._handle_companion_decline`, clears with no roster mutation) — both no-payload. **Removed from Resolve:** the old plan's `cta.recruit_accept`/`cta.recruit_decline` + `ally_recruit_offer` resolve-snapshot projection do not exist — recruitment offers never appear on `flow.resolve`.

**Combat Contribution Ledger (Tier 1):** `EncounterContext.echo_action_logs` (previously echo-only, keyed by echo id for XP contribution) is generalized to **all factions** (echo/enemy/spirit/ally). Every entry now carries `damage_dealt: int, damage_taken: int, kills: int` (plus the pre-existing `melee_count`/`guard_count`/`kill_count`/`total_count`/`survived` XP fields) via `FlowRuntime._new_contribution_ledger_entry()`. Populated at the single melee resolution choke in `FlowRuntime._resolve_next_actor()` — `kills` increments when `defender_hp_after <= 0`. Projected into the final resolve snapshot as a `contribution` sub-dict (per actor). **`ProgressionService` is byte-identical** — it already read this dict by keyed lookup, so widening it to non-echo factions is purely additive; XP math is unaffected. This is the ledger `RecruitmentService`'s `combat` component reads.

**Combat Contribution Ledger (Tier 2 — support/defensive, S14b):** the same ledger entry gains five additive fields. `guards_granted`, `morale_given`, `fear_relieved`, `support_actions` are **support** metrics, **echo-gated** (attributed only to echo-faction acting actors); `morale_given`/`fear_relieved` are **effective post-clamp** points delivered to *allies* (self-effects excluded). `fear_inflicted` is an **offensive** metric (fear dealt to whoever the actor hits), **all-faction**, written directly at the per-hit fear choke (mirrors `damage_dealt`). Unlike offensive damage (one choke), support effects live at ~10 scattered inline sites — `ActorStateMachine` (`hold_ground`/`steady_call`/`interpose`/Seer `idle_fear_aura`/leadership auras `inspire_aura`/`steady_presence`/`calm_fear`/`fear_read`/`rally_call`) and `FlowRuntime` (kill ripple + `kill_momentum`). Each site accumulates onto a transient `actor["_support_tally"]` dict during the actor's turn (the established `_expression_band`-on-actor-dict pattern — `ActorStateMachine` never references `EncounterContext`); a **single fold** `FlowRuntime._fold_support_tally(actor, ectx)` merges the tally into `echo_action_logs` once per turn (echo-gated) and **always erases it** so a stale tally can never double-count. **Zero behaviour change** to the effects themselves; **`ProgressionService` and `RecruitmentService` remain byte-identical** (they read only their named fields; the new keys are ignored). Excluded from attribution: passive/environmental sites with no acting actor (round fear tick, periodic morale decay, shrine drain, ally-KO contagion, near-death self-reaction, no-damage helplessness, witness/overwhelm).

**Companion origin tag:** the additive `echo["origin"]` field (`"recruited_ally"` for companions, absent/empty for summoned echoes) is projected in every sanctum-family snapshot and drives a ⊕ Companion badge on every Sanctum echo surface: `SanctumScreen` hub strip + echo detail, `EchoPartyScreen` list/cards/detail.

**Debug commands (F1 panel, dev-only; see Action Type Registry for exact types):** `spawn_ally`, `force_claimant_combat`, `force_charge_pressure [on|off]`, `force_recruit <success|fail|clear>`.

**guide_spirit routing fix (pre-existing Phase 3c soft-lock, discovered and fixed while wiring these seams):** `SituationResolutionService._ASYNC_OBJ_TYPES` was missing `"guide_spirit"`. A guide_spirit **OBJECTIVE** situation therefore fell through to the `"in_explore"` flavor-text branch instead of routing to real combat, and never set `completed` — silently soft-locking stage advancement whenever a guide_spirit objective was rolled. Fixed by appending `"guide_spirit"` to the array (it was already present in the sibling `_ASYNC_SIT_TYPES`-adjacent combat routing everywhere else in the P3c contract above).

**Historical Phase 4 workaround — superseded:** Phase 4 temporarily bounded the
Resolve body and raised a RealmShell-owned overlay above the EchoBar to unblock its
playtest. The general responsive/layering refactor supersedes that add-order fix:
Resolve now requests `realm.resolve` from the AppRoot layer-40 `ModalHost`. Its
full-viewport blocker covers persistent chrome, while its authored safe card uses a
bounded body and reachable footer actions.

**New save fields (all additive):**
- `explore_map.ally_contact` (Dictionary), `explore_map.ally_contact_id` (String), `explore_map.ally_consumed_in_encounter` (bool), `explore_map.hostile_charge_sit_id` (String), `explore_map.combat_intro_reason` (String), `explore_map.ally_recruit_rolled_encounter_id` (String — guards a single recruit roll per encounter).
- `sanctum.companion_invite` (Dictionary, `{}` = none pending).
- per echo: `echo.origin` (String, additive companion marker).

**New action types:** `sanctum.companion.accept`, `sanctum.companion.decline` (see Action Type Registry).

**New config (`data/balance.json`):** `data.contact.ally` (`def_id`, `damage_mul`), `data.contact.recruitment` (cap/component weights/subweights — see `RecruitmentService` doc comment for the full formula), `data.contact.claimant.combat_intro_line`, `data.combat.charge_pressure` (`protect_duration_bonus`, `endure_wave_bonus`), `data.actor.enemy_types.temporary_ally`.

**New tests:** `tests/RecruitmentServiceTests.gd`, `tests/ContactActorBuilderTests.gd`, `tests/Stage004SeamTests.gd`; extended `tests/CombatStateTests.gd`, `SituationResolutionServiceTests.gd`.

**Visual language:** ally/companion = Mist Blue `#7AB5C8` + ⊕ Odo Nnyew glyph — a third combat-visual family distinct from the P3c spirit gold nimbus and standard enemy red.

**Deferrals (tracked, not blocking):** Tier-2 support-attribution ledger (guard/heal/utility contribution, not just damage); `is_kill` dead-code fix (pre-existing, unrelated to this phase); recruitment-config de-duplication (`conversation_good_fear_max`/`conversation_good_morale_min` duplicate thresholds `ConversationService` already defines elsewhere); in-explore objective-completion guard (defense-in-depth beyond the guide_spirit fix above). Plus the original STAGE-004 deferrals carried forward: item rewards → V2-ITEM-002, enemy pressure roles → V2-COMBAT-002.

**V2-STAGE-004 is now fully DONE.** All phases shipped: P0–P3c (PRs #27/#28/#29/#30/#33/#36/#37), P3a, P5 (#38), P4 (this phase).

### SanctumLayoutService (`core/sanctum/SanctumLayoutService.gd`)
Pure-static `RefCounted`. V2-SANCTUM-002. No Nodes, no UI refs.

**Signatures:**
- `snapshot_layout(save_data, inst_snapshot: Array = []) -> Dictionary` — returns `{ tiles: Array }`. Each tile: `{ x, y, kind }`. Kind values: `"floor"`, `"ase_flame"`, `"institution"`.
- `snapshot_occupants(save_data, roster: Array = [], active_party_ids: Array = [], inst_snapshot: Array = []) -> Array` — returns Array of occupant dicts. Each occupant carries `kind`, `id`, `name`, `x`, `y`. Echo occupants also carry `emotional_status: String`.
- `compute_valid_placement_cells(save_data, inst_snapshot: Array = []) -> Array` — returns `Array[Vector2i]`. Valid cells are adjacent (8-dir) to an existing floor tile, not occupied, not already a floor tile, and not within Chebyshev-2 of any institution or the Ase Flame.
- `ensure_layout(save_data, inst_snapshot: Array = []) -> void` — ensures Ase Flame tile at (0,0), institution tiles at their stored positions, and bridge floor tiles.
- `ensure_starter_occupant(save_data, roster: Array = [], active_party_ids: Array = [], inst_snapshot: Array = []) -> void`
- `check_placement_validity_from_data(cell: Vector2i, floor_cells: Array, occupied_cells: Array) -> Dictionary` — returns `{ "valid": bool, "reason": String }`. Checks 4 rules in order: occupied → already floor → exclusion zone (Chebyshev-2 from any occupied cell) → not adjacent to any floor tile. No save_data needed — operates on pre-computed arrays from snapshot.
- `get_bridge_preview_from_floor(target: Vector2i, floor_cells: Array) -> Array` — returns `Array[Vector2i]` of bridge floor cells that would be auto-generated if an institution were placed at `target`. Up to 2 cells. No state mutation. No save_data needed.

**`sanctum_occupants` kind values:**
| Kind | Meaning |
|---|---|
| `"ase_flame"` | Permanent spiritual anchor at (0,0). Always first entry. |
| `"institution"` | Established or candidate institution marker. |
| `"echo"` | Roster echo. Carries the canonical player-facing `emotional_status` field. |

**`emotional_status` in echo occupants:** computed at snapshot time via `EmotionService.get_emotional_status(morale_current, fear_current)` — not stored in save. `SanctumOccupantLayer` resolves token fill through `EmotionPresentation`; `morale_tier` must not appear in the occupant projection.

**Ase Flame:** hardcoded at `Vector2i(0, 0)`. Never goes through `InstitutionService`. Never in valid placement cells.

**Institution positions:** stored in `save_data.sanctum.institutions[inst_id].position` as `{ "x": int, "y": int }`. Added by `InstitutionService.establish()` when placement is confirmed. Safe default `{ x:0, y:0 }` added by `SaveSchema` repair.

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

**`bond_entries` per echo** (in `flow.echo_party` snapshot): `Array[{ echo_id, name, tier, tier_name, strength, bond_type }]` — sorted by tier ascending (most negative first). Empty when no party encounters recorded.

**Bond triggers** (wired in BOND-002 — `FlowRuntime._apply_combat_bond_triggers()`):

| Trigger key | Delta | Condition |
|---|---|---|
| `shared_combat_proximity` | +1 | All echo pairs sharing a stage, always |
| `shared_stage_win` | +3 | All echo pairs on victory |
| `stage_defeat_shared` | -3 | All echo pairs on defeat |
| `archetype_incompatible_shared_stage` | -5 | Incompatible archetype pair sharing a stage |
| `ko_incompatible_no_protect` | -10 | Incompatible pair + one KO'd + neither guarded |
| `protect_action_for_ally` | +8 | Friend-tier pair where either had guard_count > 0 |
| `witnessed_ally_sacrifice` | +12 | One bonded (non-neutral) echo KO'd, partner survived |
| `near_wipe_survival_together` | +10 | Victory + ≥1 echo KO'd + both pair members survived |

Deferred triggers (config stubs only, not fired yet): `same_calling_shared_stage`, `adjacent_calling_shared_stage`, `guard_withheld_ally_endangered`, `reckless_advance_ally_exposed`, `vector_opposition_shared_stage`, `directive_deviation_repeated`, `morale_contagion_negative`, `three_plus_stages_incompatible`.

**`rival_incidents`** (BOND-002, seed for SANCTUM-005): canonical `[a_id, b_id]` pairs appended to `sanctum["rival_incidents"]` when a rival-tier pair shares a stage. Never cleared. Never duplicated.

### VowService (`core/sanctum/VowService.gd`)
Pure-static `RefCounted`. VOW-001 vow doctrine system.

- `unlock_vow(vow_id, discovered_realm, save_data, ctx, logger, t) -> bool` — marks vow as discovered in `sanctum.vows[vow_id]` at tier 1. Idempotent.
- `pledge_vow(vow_id, tier, cfg, save_data, ctx, logger, t) -> bool` — sets `sanctum.active_vow`. Fails if vow already active or vow not unlocked. Records `pledged_at_realm` (empty string if pledged from Sanctum) and `runs_at_pledge` (total run_count across all realms at pledge time).
- `break_vow(cfg, save_data, ctx, econ, logger, t) -> Dictionary` — clears `sanctum.active_vow`. Returns `{ morale_delta, fear_delta, ase_cost }` for caller to apply. Returns `{}` if no active vow.
- `release_vow(save_data, ctx, logger, t) -> void` — clears `active_vow` with no penalty. Used by natural release path.
- `release_vow_if_due(save_data, ctx, logger, t) -> bool` — called on every `flow.sanctum` enter. Checks if vow release condition is met; if so calls `release_vow()` and returns `true`. Release condition: if `pledged_at_realm` is non-empty → that realm is no longer `"active"`; if empty → total `run_count` across all realms > `runs_at_pledge`.
- `evaluate_stage_condition(save_data, party_echo_ids, cfg) -> Dictionary` — called at stage entry. Returns `{ status, morale_delta, fear_delta, should_auto_break }`. `status` is `"compliant"`, `"violated"`, or `"none"` (no active vow). Mutates `active_vow.consecutive_small_deployments` / `consecutive_same_calling_deployments` in save_data. Supports `tikoro_nko_agyina` and `praye_wokabomu`.
- `evaluate_engage_condition(save_data, situation, stage_id, cfg) -> Dictionary` — called at situation engagement (before `revealed` is set). Returns `{ status, morale_delta, fear_delta, should_auto_break }`. Tracks `consecutive_blind_engagements` in `active_vow`; resets on new `stage_id` via `blind_stage_id`. Supports `obi_nnim_kyere`.
- `evaluate_stage_complete_benefit(save_data, situations, cfg) -> Dictionary` — called at stage completion. Returns `{ morale_delta, fear_delta }`. Grants bonus morale if all situations were revealed before engagement (`obi_nnim_kyere`).
- `get_vow_snapshot_data(save_data, cfg) -> Dictionary` — returns `{ can_pledge, active_vow, available_vows[] }` for snapshot injection.

**Save fields** (inside `save_data["sanctum"]`):
- `vows: {}` — Dict keyed by vow_id → `{ tier: int, discovered_realm: String }`. One entry per unlocked vow.
- `active_vow: {}` — `{ vow_id, tier, pledged_at_realm, runs_at_pledge }` + runtime tracking fields `consecutive_small_deployments`, `consecutive_same_calling_deployments`, `consecutive_blind_engagements`, `blind_stage_id`. All tracking fields default to `0`/`""` via `.get(..., 0)` — no new top-level save keys needed.

**Balance fields** (inside `data.vows.definitions[vow_id]`):
- `vow_name`, `proverb_twi`, `proverb_en`, `description`, `benefit_label`, `tradeoff_label`, `breaking_cost_hint`, `unlock_description`, `unlock_scenario`
- `benefit`, `tradeoff` — Dicts with vow-specific condition thresholds and deltas
- `tier_effects` — Dict keyed by tier string → `{ multiplier: float }` (scales deltas)
- `breaking_costs` — Dict keyed by tier string → `{ ase, morale_delta, fear_delta, bond_score_delta, ekwan }`

**Vow definitions (V2-VOW-001):**
- `tikoro_nko_agyina` — "One head does not constitute a council". Stage-entry check: party ≥ 3 → morale bonus; party < 3 → fear penalty. Auto-break on second consecutive small deployment. Unlock: `small_party_all_survived`.
- `praye_wokabomu` — "When you remove one broomstick it breaks, but together they do not break". Stage-entry check: 2+ distinct `calling_origin` values → morale bonus; all same calling → fear penalty. Unlock: `full_roster_diversity`.
- `obi_nnim_kyere` — "If someone does not know, someone teaches". Engage check: revealed situation → morale bonus, blind → fear penalty. Stage-complete bonus if all situations scouted. Auto-break on second consecutive blind engagement in same stage. Unlock: `all_situations_scouted`.

**Release timing:**
- Pledged during a realm: released when that realm's status is no longer `"active"` (i.e. completed or abandoned).
- Pledged from Sanctum (no active realm): released when total `run_count` across all realms increases past `runs_at_pledge`.
- Early break: always available via `cta.break` — applies full penalty + EmotionRecoveryService.set_modifier on all roster echoes.

### ThreadService (`core/progression/ThreadService.gd`)
Pure-static `RefCounted`. V2-WEAVE-001 Thread crystallization and per-stage recovery utilities.

- `crystallize_threads(realm_id, save_data, cfg, t, logger) -> Array` — deterministic; no RNG. Reads `realm_recovery_segments`, derives weighted quality float, resolves count (1–3) and tier, writes Thread dicts into `save_data["sanctum"]["threads"]`. Returns Array of added Thread dicts. GDD §14.4: always ≥1 thread (`max(1, _resolve_count())`).
- `get_recovery_band(segments, cfg) -> String` — returns `"strong"` / `"compromised"` / `"weak"` for display. Used by stage-map snapshots.

**Call order:** `RealmService.contribute_segment()` BEFORE `RealmService.advance_stage()`. Then `ThreadService.crystallize_threads()` AFTER realm is confirmed complete (inside `FlowRuntime._handle_complete_stage()`).

**Config block:** `balance.json data.threads` — `segment_quality_by_grade`, `quality_tiers` (min_quality + weight per tier), `count_thresholds` (three/two/one).

**Thread dict shape:**
```
{ "id": "thread.realm.01.0", "virtue": "courage", "quality_tier": "clean", "realm_id": "realm.01", "run_index": 0 }
```

**Save location:** `save_data["sanctum"]["threads"]` — Dict keyed by thread ID.

### WeavingRiteService (`core/progression/WeavingRiteService.gd`)
Pure-static `RefCounted`. V2-WEAVE-002 foundation rite loop (deterministic; no RNG; no OS time).

- `get_candidates(thread, roster, save_data, cfg) -> Array` — candidate list sorted by fit, capped at `cfg.max_candidates`
- `resolve_outcome(echo, thread, save_data, cfg) -> "accept" | "reject" | "defer"`
- `apply_outcome(outcome, echo_id, thread_id, save_data, logger, t) -> void`
- `get_non_chosen_consequences(candidates, chosen_id, outcome, cfg) -> Array[{echo_id, name, morale_delta, fear_delta, bond_delta}]`

**Outcome write contract:**
- `accept` — removes thread from `sanctum.threads`, appends `{id, virtue, quality_tier}` to chosen echo `woven_threads`
- `reject` — removes thread from `sanctum.threads`
- `defer` — keeps thread in reserve, appends mark to chosen echo `weave_memory_marks`

### CombatState (`core/combat/CombatState.gd`)
- `create(actors, objective, initiative_seed, init_cfg) -> Dictionary`
- `check_end_condition(actors, objective) -> { over: bool, victory: bool, reason: String }`

End condition priority:
1. `all_enemies_defeated` → victory
2. `shrine_destroyed` → defeat (purify_shrine objective only)
3. `all_echoes_dead` → defeat

**Readiness score** (V2-COMBAT-001): determines turn order — asks "how ready is this Echo *right now*?"

Formula: `score = (speed × 3 + agi × 2) + archetype_mod + calling_mod + trait_mod + vector_mod + morale_mod + seed_nudge`

- `morale_mod` — from `balance.json → data.combat.initiative_modifiers.by_morale_tier`: inspired +4, steady 0, shaken −3, broken −6. Morale reflects openness-of-spirit at encounter start; a high-morale Echo reacts faster.
- `seed_nudge` — `CampaignSeed.derive_from(seed, actor_id) % 10` (deterministic tiebreak, 0–9)
- **Calculated once at combat start — mid-combat morale recovery does NOT re-sort.**

Sort: descending by score. Tiebreak: input list position (stable — party echoes act before enemies on a tie).

**Morale vs fear — design split:**
- `morale_mod` in readiness uses **morale** (openness-of-spirit, a pre-encounter measure). A high-morale Echo is more ready to act.
- Hesitation status uses **fear** (immediate threat response during the encounter). Fear accumulates in combat and degrades intent.
- **Do not conflate these axes.** A broken Echo can have low fear at combat start; a high-morale Echo can accumulate fear mid-fight.

**Consequence bands** (three named tiers — do not collapse):

| Consequence type | Trigger | Effect |
|---|---|---|
| **Normal** | fear < 40 | Full intent scoring; no modifier. |
| **Hesitating** | 40 ≤ fear < 80 (display boundary) | `_derive_status()` returns "hesitating"; `fear_factor` already degrades aggressive scoring in BehaviorArbiter. |
| **Refusing** | fear ≥ fear_threshold (dynamic per-actor) | Absolute Fear Rule fires; `actor.refuse` returned before behavior module called. |

Guard consequence types:
- **Guard** — `actor.guard` intent → `guard_state = true` on the acting Echo (self)
- **Interpose** — `actor.interpose` intent → `guard_state = true` on the protected ally

**V2-INFRA-005 dependency:** Must ship before any permadeath story. Owns `fear_base` permanent raise, grief consequences, and the emotional safety net after Echo death. Do not ship permadeath without it.

**V2-COMBAT-002 dependency:** Required for tonal realm differentiation. V2-COMBAT-001 scales enemy count only — type variety (making realms feel distinct in pressure and tone) belongs to V2-COMBAT-002.

### Save Schema (`core/save/SaveSchema.gd` + `SaveService.gd`)
9 top-level keys: `schema_version`, `first_boot`, `meta`, `campaign`, `flow`, `economy`, `sanctum`, `stage_context`, `realms`

Transactional persistence uses `slot_01.json`, alternating verified `.pending_a`/`.pending_b`, recoverable legacy `.tmp`, and `.bak1`–`.bak3`. Each successful write increments additive `meta.save_generation`, updates `meta.last_saved_at_unix`, writes to the absent or older pending slot, verifies it before rotation, and retains the newest pending source across interruption points. Boot scans all artifacts and recovers the highest valid generation without rewriting its source; corrupt primaries are archived as `.corrupt`. A new campaign is created only when no save artifacts exist. Additive repairs run only after structural validation.

**V2-MIG-002 additive keys (added 2026-04-06):**

| Location | Key | Type | Default | Purpose |
|---|---|---|---|---|
| `economy` | `relics` | int | 0 | V2-ECONOMY-001+: rare artifact currency stub |
| `economy` | `faith` | int | 0 | V2-ECONOMY-001+: visible state stub |
| `economy` | `harmony` | int | 0 | V2-ECONOMY-001+: visible state stub |
| `economy` | `favor` | int | 0 | V2-ECONOMY-001+: visible state stub |
| `sanctum` | `continuity` | int | 0 | V2-SANCTUM-001+: Sanctum growth spine stub |
| `sanctum` | `threads` | Dict | {} | V2-WEAVE-001+: Thread reserve stub |
| `stage_context` | `intel` | Dict | {} | V2-INTEL-001+: stage-intel persistence stub |
| per echo | `storyweight` | int | mirrors `xp_total` | V2 bridge field (V2-PROG-001 uses for display) |
| per echo | `standing` | int | mirrors `rank` | V2 bridge field (V2-PROG-001 uses for display) |
| per echo | `step` | int | mirrors `level` | V2 bridge field (V2-PROG-001 uses for display) |
| per echo | `woven_threads` | Array | `[]` | V2-WEAVE-002: accepted Threads integrated into Echo identity |
| per echo | `weave_memory_marks` | Array | `[]` | V2-WEAVE-002: deferred rite memory marks |

**V2-CONTINUITY-001 additive keys (added 2026-05-21):**

| Location | Key | Type | Default | Purpose |
|---|---|---|---|---|
| `sanctum` | `rejection_counts` | Dict | `{}` | V2-CONTINUITY-001: per-echo Thread rejection counts for escalating penalty calculation |

**V2-STAGE-004 Phase 1 additive keys:**

| Location | Key | Type | Default | Purpose |
|---|---|---|---|---|
| `explore_map` | `loot_results` | Array | `[]` | V2-STAGE-004: loot accumulation seam — consumed by V2-ITEM-002 |
| `stage_context` | `encounter_approach` | Dict | `{}` | V2-STAGE-004: async-route situation context passed to ENCOUNTER (objective type, sit_id, etc.) |
| per objective | `params` | Dict | `{}` | V2-STAGE-004: extension point for post-MVP objective content; read via `.get("params", {})` |

**V2-ECONOMY-001 additive keys (added 2026-05-10):**

| Location | Key | Type | Default | Purpose |
|---|---|---|---|---|
| `sanctum` | `ase_flame` | Dict | `{awakened:false, boost_remaining_seconds:0, boost_per_bank_tick:0}` | V2-ECONOMY-001: Ase Flame dormancy gate; awakened by onboarding completion |

**Vow key (canonical):** `sanctum.vows` — Dict keyed by `vow_id` → `{ tier: int, discovered_realm: String }`.
The old `unlocked_vows: []` Array key is superseded. SaveService repair migrates old saves on load.

### ContinuityService (`core/sanctum/ContinuityService.gd`) — V2-CONTINUITY-001
Pure-static `RefCounted`. Single choke point for all Continuity mutations.

- `get_points(save_data) -> int` — reads `save_data["sanctum"]["continuity"]`
- `add_points(save_data, delta, reason, logger, t) -> void` — adds delta; clamps to ≥ 0; logs `sanctum.continuity.change`
- `apply_penalty(save_data, delta, reason, logger, t) -> void` — subtracts delta; clamps to ≥ 0
- `apply_reject_penalty(save_data, echo_id, cfg, logger, t) -> void` — escalating penalty per echo, capped by config; increments `sanctum.rejection_counts[echo_id]`
- `get_echo_rejection_count(save_data, echo_id) -> int` — reads `sanctum.rejection_counts.get(echo_id, 0)`
- `get_band(save_data, bands_cfg) -> String` — returns band name for current continuity_points (e.g. `"awakening"`, `"habit"`, `"role"`, `"governance"`, `"differentiation"`, `"cultural_maturity"`)

**Save keys (added V2-CONTINUITY-001):**
- `sanctum.continuity` — `int`, default `0`. Never shown as raw number to player.
- `sanctum.rejection_counts` — `Dict` keyed by `echo_id`, default `{}`. Tracks per-echo rejection count for escalating penalty calculation.

**Continuity drivers:**
| Event | Delta | Notes |
|-------|-------|-------|
| Thread accept (Weaving Rite) | +5 | Primary growth driver |
| Thread reject | Escalating per echo | Capped; penalises repeated rejection by the same echo |
| Vow break | −3 | Costs continuity when the house breaks its word |

**Band config:** `balance.json → data.continuity.bands` — Array of `{ name, threshold }` objects sorted ascending by threshold. Six bands: Awakening (0), Habit (5), Role (15), Governance (30), Differentiation (50), Cultural Maturity (75).

**Gating:** `InstitutionService.get_snapshot_data()` adds `blocker_reason: String` per institution entry when `continuity_points < threshold`. UI reads this field to show lock state — no other gating mechanism exists at this layer.

**Visual:** `ContinuityFlameControl` (`ui/screens/sanctum/ContinuityFlameControl.gd`) — ember-toned flame indicator in TitleRow beside Sanctum name. API: `set_band(band: String)`, `set_settled(t: float)`. Hidden when `continuity_points == 0`. Asset migration path: drop `res://ui/assets/continuity/flame_{band}.png` — auto-activates. See `docs/continuity-visual-design.md` for full design rationale, band characters, and Ase Flame distinction.

### Economy Settlement (`core/economy/EconomyService.gd` + `EconomyAccrualService.gd`)
- No frame-based accrual. **Settle before every Ase spend.**
- `economy.settle_time` action: computes elapsed, applies math, updates `last_settle_unix`. Does NOT save.
- Offline accrual: 50% decay → 0 over 8hr cap. Applied once per session on Continue. **Gated by `sanctum.ase_flame.awakened`** — no Ase accrues while house is dormant (V2-ECONOMY-001).
- UI may predict/animate balance; Core commits. Core is authoritative if they disagree.
- Ase summon costs (grade-based): uncalled=60, called=150, chosen=400
- **Ekwan** is awarded on stage completion only. Scales off final Ase awarded (post-redo, post-virtue) via `ekwan_base_factor` and `ekwan_shrine_multiplier` in `balance.json → data.rewards`.
- **Partial Ase** awarded on retreat/return_home when ≥1 situation revealed (intel-gated). Factor: `partial_intel_reward_factor` × stage base reward. No Ekwan on partial runs.
- **reward_breakdown** entries now include `"currency": "ase" | "ekwan"` field. UI colors Ekwan entries in Amber `#E8A030`.

### DirectiveService (`core/directives/DirectiveService.gd`) — V2 (V2-DIRECTIVE-001)

**V2 registry (2 entries only):**
| ID | Label | Fallback |
|----|-------|---------|
| `directive.scout_carefully` | Scout Carefully | ✓ default |
| `directive.seek_signs` | Seek Signs | — |

The 4 locked V1 entries (`protect`, `push`, `preserve`, `focus`) and `directive.none` / `directive.scout` are removed. A comment in the registry marks them as deferred to a future expansion DIRECTIVE story.

**Required keys per entry:** `id`, `label`, `description`, `pros` (Array[2]), `cons` (Array[2]), `intent_weights`, `unlock_condition`.

**V1→V2 save migration:** `SaveService.gd` repair block migrates old IDs on load:
- `directive.none` → `directive.seek_signs`
- `directive.scout`, `directive.protect`, `directive.push`, `directive.preserve`, `directive.focus` → `directive.scout_carefully`
- Unknown IDs reset to `directive.scout_carefully`

**Directive selection UI:** Stage preview requests modal id `realm.directive` at every
stage entry. AppRoot presents the authored `DirectiveSelectOverlay` through
`ModalHost`, blocking the preview and persistent EchoBar until the player confirms.
Confirmation emits the unchanged `directive.select` action.

**Intent weights → BehaviorArbiter:** Semantic keys in `intent_weights` match keys in `balance.json → directive_action_muls`. Scout Carefully favours `survival_bias`, `avoid_overcommit`, `prefer_disengage`. Seek Signs favours `clue_seeking_priority`, `reporting_priority`, `exposure_acceptance`.

**V2-STAGE-004 P2 — registry now data-driven + extensible:** The registry moved from the GDScript `const _REGISTRY` to `balance.json → data.directives`. `DirectiveService.load_from_config(cfg)` loads it at boot (wired right after each `DirectiveService.new(...)` in `FlowRuntime`); the const stays as a boot-order fallback. **No directive ID may be named in exploration/traversal GDScript** — all behaviour reads directive *fields* with `.get(field, default)`. Adding a directive is a new JSON block, zero code (guarded by a `DirectiveConfigTests` synthetic-directive case). `intent_weights`/`pros`/`cons`/`unlock_condition` are preserved verbatim → combat (V2-DIRECTIVE-001) is byte-identical.

**V2-STAGE-004 P2.5 — directives are exploration STYLE (not combat-only — Lesson #18):** new traversal fields per directive: `step_budget`, `reveal_radius` (fog-lift lever), `passive_reveal`, `target_preference` (per-`situation_category` weights — light bias over *discovered* nodes only), `exposure_tolerance`, `escape_bonus` (→ `_handle_stage_return_home` threshold), `intel_retention` + `intel_retention_bonus` (→ partial-run reward). Scout Carefully = short steps / wide `reveal_radius` / safe escape / keeps intel; Seek Signs = long steps / narrow radius / high exposure / worse escape. (`reveal_threshold` was removed — discovery is now unconditional within radius.)

---

### Stage Exploration — Terrain, Traversal & Fog-of-War (V2-STAGE-004 Phase 2 + 2.5 + 5)

**Terrain (`core/realms/StageTerrain.gd`, pure-static):** stages are irregular landscapes — 2–4 organic plateaus (seeded border-erosion blobs, `plateau.cells`), ≥2-wide connectivity bridges, stragglers; everything else is **uncrossable void**. Generated deterministically from a **per-realm landscape signature**. `walkable_set(terrain)` (empty terrain ⇒ legacy full-rect), `bfs_distance_field`/`next_step` (walkable-aware pathing — the party never enters void or dead-ends), `cells_within_radius`, `nearest_unexplored`. New append-only RNG: `stage.N.explore.terrain.{bounds,plateau.K,plateau.K.shape,bridge.K,straggler.K}`, `…sit.N.wpos.K`.

**Per-realm landscape signatures (`balance.json → data.stages.map_shape`):** `default` + `by_virtue` with all **10** virtue-keyed signatures (the 10 Realms map 1:1 to the 10 virtue domains; only realm.01 Courage + realm.02 Wisdom exist in `realms.json` today — the rest inherit by virtue). `RealmGenerator._resolve_terrain_signature(realm_cfg, stages_cfg)` order: realm-entry `terrain_signature` override → `by_virtue[virtue]` → `default`. Each signature carries plateau count/size/shape-bias, bridge width/density, straggler count, and a **`relief` descriptor string RESERVED for future per-realm visual assets** — **art will key off realm.id / virtue + `relief`; do not lose or rename this seam.** Stages within a realm vary deterministically off the stage seed (no two identical) yet share the realm's character.

**Traversal (`FlowRuntime._handle_stage_advance_turn`):** "Guidance over Control" — the player sets a directive + engages/ignores/returns; the party moves **autonomously** up to `step_budget` walkable tiles per Advance along a BFS path (UI animates a chained tween that follows the path). Explore-turns never tick during combat (hard one-way door).

**Fog-of-war (P2.5):** situations AND terrain tiles start hidden; the party **discovers by exploring**. `explore_map.explored_cells` (Dict set `{ "col,row": true }`) is the single source of truth — drives both the **three-state tile render** (void = no tile; discovered = clear; undiscovered = dim `FogLayer` overlay tile, placeholder swappable for art) and **frontier targeting**. Discovery is **tile-tied**: `_reveal_explored_situations` reveals any situation whose tile is in `explored_cells`, so **tile discovered ⟺ situation revealed → the objective is always discoverable → the stage is always completable.** Discovery is unconditional within `reveal_radius` (Scout wide, Seek narrow); `precise_intel_bias` governs only intel quality.

**Frontier targeting (`_find_explore_target`, 4-tier):** (1) nearest discovered unresolved objective (not passed) → (2) light-biased discovered non-objective (not passed) → (3) nearest **unexplored** frontier cell → (4) re-offer an objective once the map is fully explored (completability guarantee). **Pass = `passed`:** ignoring a situation marks it `passed` so the party keeps exploring instead of returning; passed nodes stay visible; objectives are re-offered at full exploration; ambient passed nodes stay skipped. Walking *past* a passed node never re-prompts.

**Frontier chaining (P5, tier-3 targets only):** when the target is a **frontier** cell (tier 3), the advance lifts fog **per step** and re-computes the target (`StageTerrain.nearest_unexplored`) each time the party reaches the current frontier cell, **chaining** until `step_budget` is spent (or `nearest_unexplored` returns the current cell = map fully explored). Previously an advance stopped ~`reveal_radius`+1 tiles out (≈ 2 tiles under Seek's narrow radius); the budget now binds. **Tier-1/2 targets (discovered objective / discovered node) keep hard-stop-on-arrival** — they do not chain. Per-step fog-lift is required so the chained `nearest_unexplored` recompute sees the updated `explored_cells`.

**Mid-path stop (P5):** stepping the party **onto** an unresolved, un-passed situation parks it with `pending_situation_id` mid-advance (canon: walking onto any situation triggers the resolution flow, even with budget remaining). Passed/resolved cells are walked through. Pass invariants preserved — a `passed` node never re-prompts.

**Durable run-state:** `explored_cells`, `revealed`, `resolved`, `passed` persist across `return_home` → re-entry (and a different party) — `FlowStageExploreState._reset_session_state` carries them; only transients (`pending_situation_id`, `in_transit`, `target_situation_id`, `last_traveled_path`) clear. Reset on stage regeneration (realm replay).

**Snapshot (`flow.stage_explore` + overview `flow.stage`):** `data.terrain`, `data.explored_cells`, `data.situations` (only **revealed** entries, each with `passed`), `step_budget`, `steps_to_target`, `in_transit`, `target_situation_id`, `traveled_path`. The overview emits no situation markers + the discovered-fog map + objective briefing (objective positions never exposed pre-entry).

**Save (additive, `if not has`):** `explore_map.terrain {}`, `explored_cells {}`, `in_transit false`, `target_situation_id ""`, `last_traveled_path []`; per-situation `passed` defaults false via `.get`.

**Travel beats (P5) — echo barks vs Anansi snippets are two distinct systems:**
- **Echo travel barks (cadence).** Fired once per advance when the party actually moved (`stepped` non-empty), on the **odd-t** gate (`_select_travel_beat` → `_select_travel_bark`). Deterministically picks one living party echo, then a `ShoutBank.get_expression_shout("journey.travel", archetype, band, calling, vk)` line — **no RNG**, variation-key = `posmod(t + echo.id.hash, 997)`. New authored content: `journey.travel` context in `data/shouts/journey.json` (9 archetypes × 4 expression bands × 3 lines). Projected as `travel_bark {actor_name, line}`.
- **Anansi snippets (EVENT-DRIVEN, not cadence).** Anansi is not a constant narrator — his ghost text fires only at four narrative moments, each togglable via `data.stages.anansi_snippet_events` (fires unless the key is explicitly `false`): **(a)** `stage_first_entry` and **(c)** `objectives_complete` fire from `FlowStageExploreState.enter()`; **(b)** `objective_revealed` (an objective situation revealed on an advance) and **(d)** `return_home_failed` fire from `FlowRuntime`. All four route through the shared static `FlowStageExploreState.fire_anansi_snippet(...)`: deterministic `posmod(t, pool.size())` line pick from `data/stages/anansi_travel_snippets.json` (24 lines, one moment-agnostic `"travel"` pool today — `_load_anansi_snippet_pool` carries the per-event-pool seam). `objectives_complete` is a one-shot per run via the durable `explore_map.anansi_complete_fired` flag. Projected as `travel_snippet` (String, `""` when nothing fired).

**Transient travel-field hygiene (P5):** `travel_bark` and `travel_snippet` share the **exact lifecycle of `last_traveled_path`** — written onto `explore_map` only when the beat fires, overwritten/cleared to `{}`/`""` each advance, and dropped by `_reset_session_state` on session reset. They **persist in the saved `explore_map`** (accepted, same as `last_traveled_path`) but are **never re-emitted on Continue**; the UI de-dupes any save-replay via a last-played gate.

---

## Per-Screen Snapshot Summaries
Full field shapes live in each FlowState file (`core/state/flow/states/`).

| Screen | Snapshot type | Key data fields | Action slots |
|--------|--------------|-----------------|-------------|
| SanctumScreen | `flow.sanctum` | sanctum_name, ase_balance, ekwan_balance, ase_rate_per_hour, ase_flame_awakened, show_awakening_overlay (one-shot bool), awakening_grant (int), roster_count, roster_preview (3 echoes + emotion + **origin** (V2-STAGE-004 P4, ⊕ Companion badge)), active_party_count, party_slots, **companion_invite** ({} when none pending — V2-STAGE-004 P4, requests the app-wide `companion_invite` modal and persists across Sanctum entries until decided) | nav.echo_party, nav.realm_select, nav.summon, cta.enter_stage (disabled when no realm), **sanctum.companion.accept / sanctum.companion.decline** (emitted by `CompanionInviteModal`, not slot-keyed — see Action Type Registry) |
| SummonScreen | `flow.summon` | ase_balance, selected_grade, summon_grade_options, summon_disabled, pending_summon_reveals | nav.back, cta.summon, overlay.dismiss_reveals |
| EchoPartyScreen | `flow.echo_party` | max_party_size (5), echoes (id/name/rank/level/in_party/archetype/calling/calling_eligible/stats/xp/bond_entries/**origin** — V2-STAGE-004 P4, ⊕ Companion badge on list/cards/detail), active_party_ids | nav.back (party toggles are immediate via sanctum.party.toggle) |
| CombatBoardScreen | `flow.encounter` | actors (projected, incl. `is_quarry`, `is_spirit`, **`is_ally`** — V2-STAGE-004 P4), round, round_phase, initiative_order, objective_state, retreat fields (pre_combat only) | nav.back, cta.retreat (when eligible). **Camera (ALL modes since P3c):** `CombatBoardScreen` extends `Control` (no Camera2D node). **Pan** via 2-finger gesture AND single-pointer click/tap-drag in `_gui_input` (`_DRAG_THRESHOLD` 8px; mouse/touch source-lock so `emulate_touch_from_mouse` doesn't double-apply the delta). **Pinch zoom** on all modes. `_apply_board_transform(pos)` repositions all five layers simultaneously (`_board`, `_token_layer`, `_move_telegraph_layer`, `_distance_layer`, `_bark_popup_layer`). Isometric-accurate pan clamp via `_board_span_px` (fixes the old rows×64 vertical under-measure). **⌖ RecenterButton** re-centres on the party centroid. **PURSUE:** auto-follow the quarry (`is_quarry` flag; `_pursue_mode` gates a `_process` lerp; auto-follow resumes after `_PAN_RESUME_DELAY` 3 s; quarry gold-diamond badge in `CombatTokenLayer`). **GUIDE_SPIRIT (P3c):** the spirit (`is_spirit`) gets a **gold halo/nimbus** in `CombatTokenLayer` (distinct from the quarry's solid diamond; tunable via `CombatTokenVisualConfig` exports); spirit HP bar NOT suppressed. **ObjectiveBanner (P5):** an authored `%ObjectiveBanner` PanelContainer renders all per-mode objective content from `objective_state` — **7 per-mode layouts** (combat / purify / recover / protect incl. `entity_name` + STOLEN urgent state with distinct chrome / endure / pursue incl. window + `%QuarryPips` distance pips driven by `quarry_distance_to_exit` / guide_spirit instruction-only, detail stays in the EchoBar spirit slot). Urgent tint applied via `modulate` **plus** a text hint ("STOLEN — recover it!") so the signal is never colour-only. **Top-chrome de-overlap (P5):** round label top-center, banner below it, initiative pushed down, pace controls in a stacked bottom band. **Palette fix (P5):** theme-default dark-brown labels were 1.4:1 on the dark panel → retinted cream/gold chrome, all pairs ≥5.33:1; `RoundLabel` is cream + 4px dark outline (~17:1 governing pair, board-independent). |
| ResolveScreen | `flow.resolve` | victory, reason, round_ended, actors (projected — each entry now also carries **`contribution`**: `{damage_dealt, damage_taken, kills}` (Tier 1) plus S14b Tier-2 `{guards_granted, morale_given, fear_relieved, support_actions, fear_inflicted}`, sourced from `EncounterContext.echo_action_logs`; offensive fields are all-faction, support fields echo-gated; zeros when the actor took no logged action), objective_state, enemies_defeated, echoes_survived, ase_awarded, ekwan_awarded, rank (S/A/B/C/D/F), reward_breakdown (Array of {label, delta, currency}), xp_events (Array of XpEvent), emotion_summary (Array of per-echo emotion arc with `direction` lift/ease/steady/fall + optional `tag` ko/refused + `bark`), vow_outcome ({event, vow_id, vow_name, proverb_twi, tier, morale_delta, fear_delta, ase_delta, echoes_affected} or {}), **run_type** ("" for combat, "scout_return" for retreat/return_home, "contact_result" for NPC conversation, **"situation_result"** for in-explore resolution), **surface** (String — screen label e.g. "Combat", "Scout Return", situation type label), **verdict** (carried/passed/good/partial/missed — non-combat runs; blank for pure combat), **summary_line** (String — one-line outcome prose), **effects[]** (Array of {kind: item/intel/continuity/objective/storyweight, label, value, tone}) | Victory: `cta.continue` → `flow.complete_stage` (destination=sanctum), `cta.next_stage` → `flow.complete_stage`. Defeat: `cta.continue` → `flow.go_state` (no stage advance). Scout/contact/situation return: `cta.continue` → `flow.go_state` (→ stage_explore). **V2-STAGE-004:** `run_type="situation_result"` routes back to STAGE_EXPLORE. RealmShell requests modal id `realm.resolve`; AppRoot presents it through the layer-40 `ModalHost` over the still-mounted venture screen. Four zones: Banner (surface + S–F rank for combat / verdict badge otherwise), Summary line, Echo stage (token + tier-arc + direction cue + KO/refused tag + arrival bark), Effects rail (EffectChip). Ledger (reward breakdown + stat readout + vow) still present. |
| RealmSelectScreen | `flow.realm_select` | title, current_realm_id, realms[] (id/name/virtue/description/stage_count_min/max/status/locked) | nav.back |
| ~~RealmInitScreen~~ | `flow.realm_init` | **Removed (UI-003)** — FlowRealmInitState now auto-advances to `flow.stage_map` on enter(); no screen rendered. | — |
| StageMapScreen | `flow.stage_map` | realm_id, realm_name, current_stage_id, stages_completed_count, stages[] (id, name, status, stage_type, stage_description, objective_count, objectives[{obj_index, obj_type, obj_description}]), party_preview | cta.enter_stage, nav.back |
| StageExploreScreen (preview mode) | `flow.stage` | stage_id, stage_name, stage_type, stage_description, objective_count, objectives[] ({obj_index, obj_type, obj_description}), realm_id, party_preview, directive ({active_id, directives[]}), map_width, map_height, map_entry_pos, map_situations[] ({pos}), active_vow ({vow_id, vow_name, proverb_twi, proverb_en, tier} or {}) | cta.start, nav.back |
| VowScreen | `flow.vow_manage` | can_pledge (bool), active_vow ({vow_id, tier, proverb_twi, proverb_en}), available_vows[] ({vow_id, vow_name, proverb_twi, proverb_en, description, benefit_label, tradeoff_label, breaking_cost_hint, is_unlocked, max_tier_unlocked, is_active, discovered_realm, unlock_hint}) | nav.back, cta.pledge (disabled when vow already active), cta.break (disabled when no active vow) |
| WeavingRiteScreen | `flow.weaving_rite` | phase, selected_echo, thread_reserve, selected_thread_id, invitation_lines (prose clues), outcome, aftermath_lines, non_chosen | nav.back, cta.begin_rite, cta.confirm |

**Projected actor shape** (FlowEncounterState._project_actor): `id, name, hp, max_hp, status` (dead/guarding/refusing/**hesitating**/alive — V2-COMBAT-001: hesitating = fear ≥ 40), `calling_origin`, `morale_status` (Normal/Shaken/Afraid/Broken from fear)

**Extended actor snapshot fields** (ActorStateMachine.get_snapshot() — PROG-010 + V2-VOICE-001):
`smartness_tier` (novice/adept/veteran/elite), `resilience_traits: Array`, `leadership_traits: Array`, `active_leadership: String` (trait fired this turn), `bark_line: String`, `bark_context: String`, `bark_tier: String`, `bark_target_id: String`, `bark_is_response: bool` (true = reactive/reply bark)

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
| **stage** | `stage.advance_turn` | moves party, reveal check, parks at next situation |
| | `stage.engage_situation` | routes by type: async → ENCOUNTER; in_explore → resolve or choice (V2-STAGE-004) |
| | `stage.ignore_situation` | dismisses engagement popup; party stays; next turn skips this pos |
| | `stage.return_home` | escape roll; success → stage_map; fail → return_failed flag |
| | `stage.calling_action` | calling-qualified bonus explore action (V2-STAGE-002) |
| | `stage.consult_echoes` | payload: `{ echo_ids: Array }`. Selects ≤3 echoes to hear per contact turn (V2-STAGE-003) |
| | `stage.speak_response` | payload: `{ echo_id }`. Speaking echo advances contact turn; resolves after final turn (V2-STAGE-003) |
| | `stage.disengage_contact` | no payload. Exits mid-conversation; resolves with no outcome (V2-STAGE-003) |
| | `stage.resolve_situation_choice` | payload: `{ situation_id, choice_id }`. Resolves obstacle/structure choice; routes to situation_result overlay (V2-STAGE-004) |
| **directive** | `directive.select` | sets active directive in save |
| **ui** | `ui.dismiss_summon_reveals` | clears pending reveal queue |
| **flow** | `flow.select_realm` | selects a realm; triggers `RealmService.get_or_create`; transitions to `flow.stage_map`. Payload: `{ realm_id: String }` |
| | `flow.select_stage` | sets `ctx.stage_id`, transitions to `flow.stage`. Payload: `{ stage_id: String }` |
| | `flow.complete_stage` | REALM-004: advances `current_stage_index` via `RealmService.advance_stage()`; on realm complete routes to `flow.realm_select` (clears `ctx.realm_id`+`ctx.stage_id`); else routes to `flow.stage_map`. Optional `destination` field overrides routing for non-completed stages (e.g. `"flow.sanctum"` for victory "To Sanctum" path). |
| **sanctum (institutions)** | `sanctum.institution.establish` | payload: `{ institution_id, position: { x: int, y: int } }`. Spends Ekwan, unlocks institution at free-placed position. Gated by Continuity threshold + Ekwan affordability. Position dispatched by `SanctumScreen` confirm flow after player selects a valid cell. |
| | `sanctum.institution.assign_echo` | payload: `{ institution_id, echo_id }`. Spends Ase, adds echo to occupant_ids. Auto-removes echo from active_party_ids if present. |
| | `sanctum.institution.remove_echo` | payload: `{ institution_id, echo_id }`. Spends Ekwan, removes echo, drops condition one tier. Applies morale/fear delta if echo was natural_fit. |
| **weave** | `weave.start_for_echo` | payload: `{ echo_id }`. Starts rite from an EchoParty/Sanctum-family interaction, seeds rite context with the chosen echo, transitions to `flow.weaving_rite`. |
| | `weave.enter_rite` | No payload. Clears stale rite context (echo_id, thread_id, resolution, locked) and transitions fresh to `flow.weaving_rite`. Entry point from BottomRail Weaving button. |
| | `weave.pick_echo` | payload: `{ echo_id }`. Per-row dispatch from echo picker in `echo_missing` phase. Sets selected echo, clears thread/resolution, rebuilds rite snapshot. |
| | `weave.select_thread` | payload: `{ thread_id }`. Sets offered thread for the currently selected rite echo and refreshes rite snapshot. |
| | `weave.begin_rite` | validates selection, resolves outcome, applies outcome + non-chosen consequences, locks rite until confirm. |
| | `weave.confirm` | clears rite transients and returns to Sanctum. |
| **vow** | `vow.pledge` | payload: `{ vow_id, tier }`. Calls VowService.pledge_vow(). Saves `pledged_at_realm` + `runs_at_pledge`. |
| | `vow.break` | Calls VowService.break_vow(). Applies morale/fear delta to all roster echoes. |
| **sanctum (companion, V2-STAGE-004 P4)** | `sanctum.companion.accept` | No payload. Reads `sanctum.companion_invite`, calls `RecruitmentService.promote_ally_to_echo()`, clears the invite. Handled by `FlowRuntime._handle_companion_accept()`. |
| | `sanctum.companion.decline` | No payload. Clears `sanctum.companion_invite` with no roster mutation. Handled by `FlowRuntime._handle_companion_decline()`. |
| **debug** | `debug.seed.show/set/reset` | seed tooling (dev only, `t = -1`) |
| | `debug.echo.gen_test` | generates test echo (dev only) |
| | `debug.vow.unlock` | payload: `{ vow_id }`. Unlocks a vow at tier 1 without scenario trigger (dev only) |
| | `debug.vow.pledge` | payload: `{ vow_id }`. Pledges a vow directly (dev only) |
| | `debug.vow.break` | Breaks active vow without confirmation (dev only) |
| | `debug.vow.status` | Logs current vow state to debug panel (dev only) |
| | `debug.ally.spawn` | V2-STAGE-004 P4 (S12). `spawn_ally` debug-panel command. Only usable in `flow.stage_explore`; forces the next objective encounter's `temporary_ally` join path for manual testing (dev only). |
| | `debug.claimant.force_combat` | V2-STAGE-004 P4 (S13). `force_claimant_combat` debug-panel command. Only usable in `flow.stage_explore`; sets `explore_map.combat_intro_reason="claimant_hostile"` and routes to `flow.encounter` (dev only). |
| | `debug.charge_pressure.set` | V2-STAGE-004 P4 (S13). `force_charge_pressure [on|off]` (default `on`) debug-panel command; payload `{ on: bool }`. Only usable in `flow.stage_explore`; sets/clears `explore_map.hostile_charge_sit_id` (dev only). |
| | *(no action type)* `force_recruit <success\|fail\|clear>` | V2-STAGE-004 P4 (S14). Debug-panel command handled entirely client-side in `AppRoot._run_force_recruit_command()` — sets `runtime.flow_ctx.dev_force_recruit` directly ("success"/"fail"/"") without dispatching an action. The next `RecruitmentService.roll()` draws-then-overrides so the seeded RNG order is preserved (dev only). |

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
- Shell-cached nav: SanctumShell owns the BottomRail; sanctum-family states do NOT inject nav
- Two-shell router: SanctumShell (hub) vs RealmShell (venture)
- EmotionService as single choke point outside combat
- Direct dict writes for mid-combat emotion (EmotionService not called during rounds)
- EchoFactory RNG draw order v1 immutable
- Absolute Fear Rule: `fear ≥ 80 → actor.refuse` before module is called
- `is_dead` and `is_structure` are immutable once set
- One save slot forever. Auto-save only at sanctioned boundaries (no manual save in MVP)
- `static build_snapshot()` pattern for mid-state snapshot updates
- `MaturityExpressionService` is the single lookup point for expression_band (Standing-based) + calling_behavior config. Expression bands: nascent (S1), forming (S2), grounded (S3), whole (S4–5). `presence_strength`: 0.1 / 0.25 / 0.5 / 1.0. All downstream systems (BehaviorArbiter, EmotionService, ShoutBank) read `expression_band` from actor context — never `smartness_tier`. Config lives under `balance.data.maturity_expression`. (V2-PROG-006)
- Echo traits (`resilience_traits` + `leadership_traits`) seeded at EchoFactory via derived RNG `.echo_traits.v1` — immutable, separate from v1/v2 draw sequence. Never reorder v1/v2.
- **Sanctum spatial layer architecture (V2-SANCTUM-002):** Three dedicated `Node2D` layers defined in `SanctumSpatialRenderer.tscn` (never created in code). `SanctumBuildingLayer` (z=1): Ase Flame marker + institution established/candidate markers. `SanctumOccupantLayer` (z=2): echo tokens only — combat-board circle style with morale_tier fill color. `SanctumPlacementLayer` (z=3): isometric diamond grid overlay (Akan Gold 18%, ~200ms fade-in via Tween on `_grid_alpha`); ghost building (valid = semi-transparent, invalid = red-tinted, 44×28px rect); bridge tile preview (light gold filled diamonds); last-tapped cell highlight (36% alpha gold ring); shown/hidden atomically during placement mode. `SanctumSpatialRenderer.gd` coordinates all three — receives snapshot data, pre-converts tile coords to pixel positions, calls each layer's setter. `SanctumGroundScene` was deleted — do not recreate it.
- **Voice system (V2-VOICE-001):** Real-time bark display + reactive barks + priority display. Full contracts below.
  - **Actor dict bark fields** (written by `ActorStateMachine.advance_turn()` + `finalize_combat_bark()`; reset at turn start): `_bark_line: String`, `_bark_context: String`, `_bark_tier: String` (1/2/3), `_bark_target_id: String`, `_bark_is_response: bool`.
  - **`round_bark_events: Array`** on `EncounterContext` — reset at round start; each entry `{ actor_id, faction, bark_context, grid_pos }`. Appended to by `FlowRuntime._resolve_next_actor()` for high-signal barks (`combat_last_stand`, `combat_fear_extreme`, `combat_resilient`, `combat_taunt`, `combat_ko`). Passed to every actor's `advance_turn()` ctx so forming+ band actors can react.
  - **`_sanctum_bark: Dictionary`** on echo save-data entries — shape: `{ "line": String, "context": String }`. Written by `FlowRuntime._select_sanctum_bark_for_*()` helpers. Read by `FlowSanctumState` (→ `roster_preview[i].sanctum_bark`), `FlowEncounterState.build_final_snapshot()` (→ actor `arrival_bark`), and `SanctumScreen` (text quote below emotional_status). Spatial popup above echo tokens deferred to V2-SANCTUM-005.
  - **`data.voice` config** (balance.json): `reactive_range` (4), `reactive_high_signal_contexts[]`, `reactive_min_expression_band` ("forming"), `reactions_exceed_cap` (true), `max_reactions_per_original` (1), `max_barks_per_round` (3), `bark_tiers` (1/2/3 keyed → context arrays), `sanctum_max_barkers` (2).
  - **Bark tier system** — Tier 1 (critical: always show), Tier 2 (emotional: max 2/round), Tier 3 (situational: max 1/round, dropped first); `combat_rally_ally` reaction barks bypass cap entirely. Per-round cap = `max_barks_per_round` originals; reactions are interleaved after their trigger (up to 1 per original shown).
  - **New bark contexts** — `combat_ko` (killing blow), `combat_calling_skill` (calling ability used), `combat_rally_ally` (reactive response), `sanctum.arrival_victory`, `sanctum.arrival_defeat`, `sanctum.broken`, `sanctum.calling_settled`, `sanctum.bond_formed`, `sanctum.idle` (stub only), `rite.thread_accept`, `rite.thread_reject`, `rite.thread_defer`, `vow.benefit`, `vow.penalty`, `progress.rank_up`, `resolve.victory`, `resolve.defeat`.
  - **ShoutBank variation** — `get_expression_shout(ctx, arch, band, calling, variation_key: int = 0)`. Array data entries → `variation_key % size()`. Deterministic selection; no RNG. `variation_key = (t + str(actor_id).hash()) % 997`. All contexts have ≥3 lines per arch/band combo. Arch×calling combos in `data/bark/combat_callings.json`.
  - **`finalize_combat_bark(is_kill, variation_key)`** — separate method on `ActorStateMachine`, called by `FlowRuntime` AFTER `CombatService.resolve_action()` returns (kill only known post-resolution). Promotes bark to `combat_ko` context if `is_kill=true`.
- `StageModel` + `ObjectiveModel` are immutable data contracts after REALM-002. Adding new objective types = add a constant + TYPE_DESCRIPTIONS entry in `ObjectiveModel.gd` only. Generator pre-boss pool (`_PRE_BOSS_POOL` in `RealmGenerator.gd`) must never be reordered (determinism). Append new types at the end only.
- `objective_params: {}` on ObjectiveModel is the extension point for post-MVP stage content (roaming intel map, escort targets, etc.). Not in REQUIRED_FIELDS — always read via `.get("params", {})`.
- Stage IDs use format `"stage.%d"` (zero-based index), e.g. `"stage.0"`, `"stage.1"`. Set on `flow_ctx.stage_id` by `flow.select_stage` action handler in FlowRuntime.
- ECONOMY-004: Stage reward is paid once inside `build_final_snapshot()` — no `reward_paid` guard needed since this function is called exactly once per combat end. `RewardCalc` is a pure static helper with zero side effects. Rank uses board totals (`total_enemies`, `total_echoes`) for `max_possible` so rank reflects missed opportunities. Defeat uses `base × defeat_factor` as rank numerator — defeat naturally scores C or lower. All reward config lives in `balance.data.rewards`.
- REALM-003 delivered as part of REALM-002: deterministic stage generation (`RealmGenerator.generate()`), stage progression UI (`StageMapScreen` plus the shared `StageExploreScreen` preview/explore flow), and `LOG_REALM_CREATED` with full stage list are all complete. REALM-003 Notion card is Done — no additional code needed.
- REALM-004: `RealmService.advance_stage(ctx, t) → Dictionary` increments `current_stage_index` in save; detects realm complete (`new_index >= stage_count`) and writes `is_completed=true`, `status="completed"`; always sets `save_request=true`; idempotent if already complete. Called by `flow.complete_stage` handler in FlowRuntime. `cta.next_stage` in resolve snapshot dispatches `flow.complete_stage` (not `flow.go_state`). On realm complete, FlowRuntime clears `ctx.realm_id`+`ctx.stage_id` before routing to `REALM_SELECT`. `FlowStageMapState` emits `stages_remaining`, `realm_complete`, `stage_count` in snapshot data; gates `cta.enter_stage` when `realm_complete==true`; guards empty model with redirect snapshot (not scaffold).
- REALM-005: `RealmService.calculate_stage_reward(stage_index, realm_virtue, run_index, reward_cfg)` is a pure static helper. Formula: `roundi((virtue_bonuses[virtue] + stage_index × stage_index_bonus_per) × (realm_order_multiplier_base + run_index × realm_order_multiplier_step))`. Scales ×0.5 per realm entered (no cap). Victory-only — defeat gets existing 25% consolation, no virtue bonus. Added to total after redo multiplier (flat bonus, not subject to redo penalty). Logged via `economy.stage.reward` with `formula_inputs`. Config in `balance.data.rewards`. `formula_inputs` + `relics: []` stub (ITEM-001 attachment point) added to `flow.resolve` snapshot data in `build_final_snapshot()`. `StructuredLogger.warn()` added (maps to `info` severity).
- Combat-stage pipeline fixes (post REALM-004): Three bugs fixed. (1) `_handle_complete_stage()` now nulls `encounter_ctx`+`encounter_machine` before advancing stage — fixes stale board actors on next stage entry. (2) `FlowEncounterState.enter()` now calls `_resolve_mode_from_stage()` instead of hardcoding `PURIFY_SHRINE` — reads stage's first objective type (`combat`→`COMBAT`, `shrine`→`PURIFY_SHRINE`) from the realm model. (3) `flow.select_stage` handler now sets `encounter_id = realm_id + "." + stage_id` — fixes identical actor placement across all encounters. Win-path emotion drift (`_apply_encounter_emotion_drift("win", t)`) is now called in `_handle_complete_stage()` before nulling the encounter, wiring the EMOTION-002 drift that was silently skipped in the `build_final_snapshot()` path.
- **V2-STAGE-002 encounter lifecycle fix:** `FlowEncounterState.exit(ctx, t)` now nulls `flow_ctx.encounter_ctx`, `flow_ctx.encounter_machine`, and resets `flow_ctx.active_encounter_objective_index = -1`. **Principle: state-specific teardown belongs in `exit()`, not scattered across action handlers.** Previously only the `flow.go_state → SANCTUM` path nulled the encounter context; the new multi-objective path (`flow.go_state → STAGE_EXPLORE` after partial victory) was missing the cleanup, causing the old encounter (dead enemies, `combat_over=true`) to be reused on the next combat engagement.
- **V2-STAGE-002 multi-objective resolve routing:** `FlowEncounterState._build_resolve_actions(victory, objectives_remaining)` now checks `objectives_remaining`. Victory + objectives remain → `cta.continue = flow.go_state → STAGE_EXPLORE` ("Return to Exploration"). Victory + all done → `cta.continue` (To Sanctum) + `cta.next_stage` (advance stage). Defeat unchanged. `objectives_remaining` also surfaces in resolve snapshot `data` field for UI display.

- **V2-STAGE-004 Phase 1 — unified situation resolver + unified resolve surface:**
  - `SituationResolutionService.route()` is the single decision point for async-vs-in_explore. Never inline this routing logic.
  - `flow.resolve` payload extended **additively** (no field renamed/removed). Fields added: `surface`, `verdict`, `summary_line`, `emotion_summary[].direction` + `.tag`, `effects[]`. All existing producers enriched. Existing combat/scout consumers zero regression.
  - `EffectChip` (`ui/components/EffectChip.gd/.tscn`) — atomic rail chip for the effects zone. Carries: `kind`, `label`, `value`, `tone`. Reused by all resolve producers. Never instantiate inline — scene instanced.
  - `ResolveScreen` is now a **single parametric component** for all resolution surfaces (combat, scout, contact, situation). Four display zones: Banner, Summary, Echo stage, Effects rail. Do not add a fifth zone without review.
  - `RealmShell` keeps `flow.resolve` out of `_scene_by_flow_type` and requests
    modal id `realm.resolve`; AppRoot presents the parametric ResolveScreen through
    its layer-40 `ModalHost` over the still-mounted venture screen.
  - `run_type="situation_result"` — cta.continue routes back to STAGE_EXPLORE (not sanctum/stage_map).
  - Four objective-type combat scenarios (recover/protect/endure/pursue as distinct fight shapes) deferred to V2-STAGE-004 Phase 3. The four types do run real combats now, but use the generic layout.

- PROG-003 post-implementation fixes: (1) Stage completion on "To Sanctum" — victory `cta.continue` now dispatches `flow.complete_stage` with `destination="flow.sanctum"` so `advance_stage()` is called on both victory exit paths; defeat `cta.continue` unchanged (`flow.go_state`, no advance). (2) Party toggles are accepted from `flow.echo_party` and rebuild via `FlowEchoPartyState.build_snapshot()`. (3) Final combat emotion state is synced back to `save_data["sanctum"]["roster"]` in `build_final_snapshot()` before returning the resolve snapshot — win/loss drift in `_apply_encounter_emotion_drift()` then applies on top.
- PROG-003: XP accrual, level-up, and EchoParty screen. `ProgressionService` (pure static, `core/progression/ProgressionService.gd`) — `award_post_combat_xp(save_data, echo_action_logs, victory, realm_completed, prog_cfg, birth_stats_cfg, logger, t) → Array[XpEvent]`. XP sources: kill bonus (attacker only), stage clear (all party), realm completion bonus (all party, final stage only). Virtue multiplier: courage-based, max +20%, scales on `melee_share × (courage/100) × max_mult`. Level-up triggers `DerivedStatService.compute_stats()` recompute. Cap: `max_level_per_rank=5`. `EncounterContext.echo_action_logs: Dictionary` accumulates `{ melee_count, guard_count, kill_count, total_count }` per echo in `FlowRuntime._resolve_next_actor()`. XP award called in `FlowEncounterState.build_final_snapshot()` after Ase reward block; `xp_events` added to snapshot data. Config in `balance.data.progression`. Snapshot building is now owned by `FlowEchoPartyState` and rendered by `EchoPartyScreen`.
- PROG-004: Rank-up logic, trait drift, wisdom/faith virtue multipliers, and EchoParty UI additions. **Rank-up contract:** `ProgressionService.execute_rank_up(echo, campaign_seed, prog_cfg, birth_stats_cfg, logger, t) → event_dict`. Eligible when `level == max_level_per_rank` and `rank < 5` (MVP cap). Execution: increment rank, reset level to 1, carry XP overflow (`xp_total = max(0, xp_total - level_thresholds[-1])`), apply seeded trait drift, recompute derived stats via `DerivedStatService.compute_stats()`, log `"progression.rank_up"`. **Drift seed path:** `"echo.{id}.rank_up.rank_{new_rank}"` → `CampaignSeed.derive()` → `int` → seed a `RandomNumberGenerator`. Trait selection: weighted roll from `vector_drift_weights[dominant_vector]` (config-driven in `balance.data.progression`). Direction: `+1` or `-1`, second seeded roll. Magnitude: `±rank_up_trait_drift_magnitude` (default 1), clamped `[1, 100]`. `calling_eligible = true` when `new_rank == 3` (PROG-007 attachment point). **Virtue multiplier formulas (full set):** courage: `melee_share × (courage/100) × virtue_xp_multiplier_max`; wisdom: `guard_share × (wisdom/100) × wisdom_xp_multiplier_max`; faith: `survived_factor (1 or 0) × (faith/100) × faith_xp_multiplier_max`. Survival tracked via `echo_action_logs[id]["survived"]` — set to `false` when echo is KO'd (`is_dead=true`) in `FlowEncounterState.build_final_snapshot()`. **Dominant vector display:** surfaced descriptively only (e.g. "Vanguard spirit") — never shown numerically (GDD §5.4). **EchoParty UI:** `DominantVectorLabel`, `CallingEligibleBadge` ("★ Calling awaits"), `AscendButton` ("▲ Ascend to Rank N"), and the rank-up overlay (`ui/overlays/RankUpOverlay.tscn`) are wired through `EchoPartyScreen`.

- PROG-007: **Calling Determination at Rank 3.** `CallingService` (`core/progression/CallingService.gd`) — pure static. `compute_all_options(echo, calling_cfg) → Array[OptionDict]` — always returns one entry per id in `calling_cfg.all_callings` (never filtered). Compatibility tier (first match wins): `"preferred"` (calling maps from dominant vector), `"compatible"` (non-dominant vector score ≥ `compatibility_threshold × total_score`), `"incompatible"` (vector score = 0), `"ambivalent"` (catch-all: score > 0 but below threshold). Seeker special rule: seeker vector maps to TWO callings (ranger + seer); preferred one determined by trait split (courage ≥ wisdom → ranger; wisdom > courage → seer); the other seeker-vector path is `"compatible"`. `confirm_calling(echo, chosen_calling_id, calling_cfg, logger, t) → String` — stores `echo["calling"]` permanently, erases `echo["calling_options"]`, applies emotional consequence matching tier: preferred → morale +10; compatible → morale −5; ambivalent → morale −3 AND fear +3; incompatible → fear +10. `is_calling_pending(echo) → bool` — true when `calling_eligible=true` and `calling` is empty. **Storage lifecycle:** `echo["calling_options"]` (Array) written at rank 3 in `execute_rank_up()` if `calling_cfg` provided; erased on confirm. `echo["calling"]` is permanent once set. **Action:** `sanctum.calling.confirm { echo_id, chosen_calling_id }` — handled by `FlowRuntime._handle_sanctum_calling_confirm()`. **Deferral contract:** calling is never forced; `calling_options` persists in save; EchoParty shows `⚡ Path Awaits` on pending echoes and opens `RankUpOverlay.show_calling(echo_id, options)` directly (no rank-up flow). **Post-rank-up overlay flow:** `show_reveal()` checks `calling_options`; ContinueButton label becomes "Choose a Path" if pending; tapping routes to CallingPanel; "Choose Later" (DeferButton) dismisses without confirming. **Config:** `balance.data.calling` — `compatibility_threshold`, per-tier emotion deltas, `vector_to_calling`, `seeker_trait_split`, `all_callings`, `definitions` (with `display_name`, `icon_key`, `description`, `benefits`, `downsides`, `vector`). **Extensibility rule:** adding a new calling = append to `all_callings` + `definitions` only; no code changes needed. `ProgressionService.execute_rank_up()` now takes `calling_cfg: Dictionary` as 5th param (after `birth_stats_cfg`); existing callers pass `{}` to skip calling_options generation.

- SANCTUM-005: **Echo Profile & Archetype Display.** Pure UI story — no new services or save_data keys. Three-tier calling display applied to all Sanctum-facing echo lists: (1) confirmed `echo["calling"]` → show calling name; (2) `calling_eligible=true` + no confirmed calling → "Calling Undecided"; (3) not yet eligible → hide calling section, archetype only. `calling_description` (one-liner from `balance.data.calling.definitions[id].description`) is surfaced in `flow.echo_party` per-echo detail data. `FlowEchoPartyState` rows include `archetype`, `calling`, and `calling_eligible`, and `EchoPartyScreen` detail panel renders the full profile.

- XP Tuning (post PROG-004): **Option A thresholds** `[0, 100, 300, 600, 1000]` — all XP config is tunable in `balance.data.progression`. **Rank base shift:** `rank_level_base_shift` (default 50) — each per-level step cost is increased by `(rank-1) × shift`; first step for rank 2 = 150, rank 3 = 200. `ProgressionService.get_effective_thresholds(rank, prog_cfg) → Array` is the single source of truth for thresholds — **never** use the raw `level_thresholds` array directly for a rank > 1. **Realm XP multiplier:** `realm_xp_multiplier_per_realm` (default 0.15) applied to `clear_xp` and `realm_xp` in `award_post_combat_xp()`; multiplier = `1.0 + run_index × rate` where `run_index` comes from the realm model in `save_data["realms"]`. **Mid-combat kill XP:** `ProgressionService.apply_mid_combat_kill_xp(echo, actor, prog_cfg, birth_stats_cfg, realm_xp_multiplier, logger, t) → event_dict`. Called from `FlowRuntime._resolve_next_actor()` immediately after `kill_count += 1` — only for `echo`-faction actors. If a level threshold is crossed, `DerivedStatService.compute_stats()` runs on both the save_data roster entry and the live `actor` dict; `current_hp` raised by hp_gained, capped at new `max_hp`. **No double-counting:** `award_post_combat_xp()` accepts `skip_kill_xp: bool = false`; `build_final_snapshot()` passes `true` because kill XP was already applied mid-combat. Stage and realm completion XP are still awarded post-combat. **Snapshot XP fields:** `FlowEchoPartyState` includes `xp_in_level` and `xp_per_level` per echo so `EchoPartyScreen` can render the XP bar without client-side threshold math.

- BOND-001: **Social Graph Contracts.** `SocialGraphService` is the single static API for all bond/encounter reads and writes. `bonds[]` + `party_encounters[]` live inside `save_data["sanctum"]` — additive, no schema_version bump. Party co-occurrence is recorded in `FlowRuntime._handle_sanctum_party_toggle` on every add (not remove). `bond_type` ("rival"/"neutral"/"friend") and `tier` are always derived at read time, never stored. All bond score triggers are config-defined in `balance.data.sanctum.bond_triggers` but fire only in BOND-002. The Bonds tab in EchoPartyScreen is always enabled (not gated by calling like Skills), showing `bond_entries[]` sorted most-negative first. `BondTierBar.tscn` is a fully .tscn-authored 11-cell visual bar — script only sets modulate + label text.

### V2-STAGE-001 + V2-STAGE-002 — Stage Exploration + Objective Taxonomy

`SituationModel` (`core/realms/SituationModel.gd`) — pure data factory.
- `make(id, type, col, row, seed, is_objective, objective_index=-1) → Dict` — produces one situation dict.
- Fields: `id`, `type`, `pos: {col, row}`, `seed`, `revealed: false`, `resolved: false`, `is_objective`, `intel_clues: []`, `objective_index` (-1 = non-objective, ≥0 = index into `stage.objectives[]`).
- Types: `TYPE_COMBAT`, `TYPE_NPC`, `TYPE_LOOT`, `TYPE_MONEY`. `SITUATION_TYPE_POOL` weighted array (combat×3, npc×2, loot×2, money×1). **V2-STAGE-002:** objective situations inherit type from the matching objective (combat/shrine/recover/protect/endure/pursue). **V2-STAGE-004:** four additional non-objective types appended at indices 8–11 (append-only, no reorder): `TYPE_OMEN`, `TYPE_OBSTACLE`, `TYPE_RITUAL`, `TYPE_STRUCTURE`. All added to `VALID_TYPES`, `SITUATION_TYPE_POOL`, and `TYPE_DESCRIPTIONS`.
- `validate(sit) → bool` checks `REQUIRED_FIELDS`. V2-STAGE-003 `role` field deferred (comment stub).

`StageExploreModel` (`core/realms/StageExploreModel.gd`) — pure data factory.
- `make(width, height, situations) → Dict` — produces one explore_map dict (attached to `stages[i]["explore_map"]`).
- `make_default() → Dict` — safe empty defaults for SaveService repair (`locked: false`).
- Constants: `MIN_WIDTH = 30`, `MIN_HEIGHT = 30`, `STATE_EXPLORING`, `STATE_ESCAPED`, `STATE_COMPLETE`.
- `validate(map) → bool` checks `REQUIRED_FIELDS`.

`FlowStageExploreState` (`core/state/flow/states/venture/FlowStageExploreState.gd`) — flow state `flow.stage_explore`.
- `enter(ctx, t)` → locks map on first entry (`locked=true`, `save_request=true`), resets session state, builds snapshot. Re-entry from combat preserves `party_pos` and `turn_count` (lock already true).
- `static build_snapshot(flow_ctx, t) → Dictionary` — projects explore_map data; hidden situations shown as `type: "hidden"`, `is_objective: false` (never leaked while hidden). Includes `situation_pending` + `objectives[]` + `objectives_remaining` + `party_calling_actions` + `party_requesting_return`.
- Action slots: `cta.advance_turn` (disabled when not `STATE_EXPLORING` or pending), `cta.return_home` (always present), `nav.back` (disabled while exploring), `cta.engage_situation` + `cta.ignore_situation` (both when pending), `cta.proceed_to_stage_map` (when all required objectives complete + no pending), calling-bonus slots (`cta.calling_reveal_adjacent`, `cta.calling_fortify_position`, `cta.calling_inspire_push`, `cta.cautious_advance` when applicable).
- **V2-STAGE-002 completion gate:** `cta.proceed_to_stage_map` absent until `objectives_remaining == 0`. Stage advance flows through `flow.complete_stage`.

**Explore map size rules:**
- Each stage gets a random asymmetric size; width and height picked independently.
- Minimum 30 tiles per dimension. Driven by per-realm config keys in `realms.json`: `map_width_min/max`, `map_height_min/max`.
- `_MAP_SIZE_STAGE_BUMP = 2` — each subsequent stage in same realm gets +2 per min/max dimension.
- Earlier realms use smaller ranges (realm 1: 30–45 × 30–40); later realms larger (realm 2: 50–70 × 45–65).

**Dispatch actions:**
- `stage.advance_turn` — moves party toward nearest unresolved situation (directive-guided; Seek Signs prioritises objectives). `_find_target_situation` skips resolved situations **and** situations at Chebyshev distance = 0 (party already parked there after a Pass). Runs reveal check (roll > 50 base, > 35 Seek Signs → `revealed=true`; writes `intel_clues` + `intel_quality`). Parks party with `pending_situation_id` set; player confirms via popup.
- `stage.engage_situation` — sets `active_encounter_objective_index` on FlowContext, marks situation resolved/revealed, writes firsthand intel; routes by type: combat/shrine → `flow.encounter`; npc/loot/money → config-driven emotion effect (`balance.json data.stages.situation_emotion_effects`) + overlay stub; recover/protect/endure/pursue → stub-complete objective + overlay (V2-STAGE-004 replaces stubs). For combat/shrine, resolved state is held until victory confirmed in `_handle_complete_stage`.
- `stage.ignore_situation` — V2-STAGE-002: dismisses engagement popup without resolving. Clears `pending_situation_id`; intel preserved. Party stays parked; next `advance_turn` skips this position (distance = 0 guard) and moves to a genuinely new location.
- `stage.return_home` — escape check (roll > 40 = success → `flow.stage_map`; fail → `data.return_failed = true`). Player-initiated anytime, or party-requested when avg fear > `party_return_fear_threshold` (snapshot: `party_requesting_return: true`).
- `stage.calling_action` — V2-STAGE-002: bonus explore action for calling-qualified parties (ranger → `reveal_adjacent`, okofor → `fortify_position`, aduro → `inspire_push`; fear-gated → `cautious_advance`). V2-STAGE-003/004 will wire resolution logic.
- `stage.consult_echoes` — V2-STAGE-003: `{ echo_ids: Array }` — dispatched once per conversation turn (party > 3); selects up to 3 echoes to hear. Generates per-echo responses via `ConversationService`; stores in `explore_map.contact_responses`. Tracks ignored bids in `contact.ignored_bid_counts`.
- `stage.speak_response` — V2-STAGE-003: `{ echo_id: String }` — player picks which consulted echo speaks. Applies NPC reaction (fear/morale delta), social effects (consulted morale +3, speaker morale +5, not-consulted −1, bond deltas for rivals/friends), storyweight partial step on score ≥ threshold. Advances `turn_current`; resolves outcome when `turn_current >= turn_count`.
- `stage.disengage_contact` — V2-STAGE-003: no payload. Player exits mid-conversation; marks situation resolved with no outcome, clears `pending_contact` and `contact_responses`. Stage exploration continues normally.
- `stage.resolve_situation_choice` — V2-STAGE-004: `{ situation_id, choice_id }`. Resolves an obstacle or structure situation via the selected choice branch (fear/morale/turn deltas from config). Routes to `situation_result` resolve overlay.

**SituationResolutionService** (`core/realms/SituationResolutionService.gd`) — V2-STAGE-004. Pure-static `RefCounted`.
- `route(sit_type, is_objective) → "async" | "in_explore"` — `"async"` for combat/shrine/recover/protect/endure/pursue (→ ENCOUNTER); `"in_explore"` for all others (single-outcome or choice).
- `resolve_in_explore(sit, stages_cfg, rng) → { panel_kind, result_text, fear_delta, morale_delta, ase_delta, loot_results, choices }` — RNG injected; result-text index deterministic from situation seed. Reads `data.stages.situation_resolution` + `situation_emotion_effects`.
- `resolve_choice(sit, choice_id, stages_cfg, rng) → { result_text, fear_delta, morale_delta, turn_cost }` — choice-branch resolver for obstacle/structure types.
- New RNG namespace: `stage.resolution.<sit_id>` — append-only, no existing draw paths reordered.
- Old `_stub_situation_result` + mutate-then-undo blocks deleted. NPC-with-contact path extracted to `_start_contact_conversation`.

**Config keys added (V2-STAGE-004)** (`balance.json → data.stages`):
- `situation_emotion_effects`: omen/obstacle/ritual/structure entries added.
- `situation_resolution`: per-type block with `panel_kind`, `result_text[]`, `money.ase_min/max`, `loot.kinds[]`, obstacle/structure `choices[]` each with `id`, `label`, `fear_delta`, `morale_delta`, `turn_cost`.

**Pending situation flow (added post-foundation):**
After `advance_turn`, party is at situation but does not engage automatically. `explore_map["pending_situation_id"]` is set. Snapshot includes `data.situation_pending` `{ situation_id, revealed, type, is_objective, intel_clues, intel_quality, enemy_estimate }` and `actions["cta.engage_situation"]`. UI shows engagement popup; player presses Enter → `stage.engage_situation` dispatched. `enemy_estimate` is non-empty only for revealed combat situations (precise: figure count from seed; rough: generic language).

**Invariants:**
- `stages[i].objectives` array is unchanged (explore_map is additive only).
- Existing `RealmGenerator` RNG draw paths NOT reordered — explore seed path (`"stage.N.explore.*"`) appended after all existing draws.
- All situations start `revealed: false`, `resolved: false`, `intel_clues: []`.
- `revealed` and `resolved` persist across session entries — `_reset_session_state` carries them forward via `sit.duplicate(true)`.
- `intel_clues` (Array[String]) and `intel_quality` (`"precise"` | `"rough"`) are written at reveal time (scout roll) or on direct engagement. Never cleared on session reset.
- `objectives_found` is recomputed on every session entry from `is_objective=true AND resolved=true` — never stored stale.
- `stage_context.intel` dict is reserved for future cross-stage intel aggregation (V2-INTEL-101+). Not used in V2-INTEL-001.
- `map_to_local(Vector2i)` is the grid-to-screen conversion (same as `CombatBoardScreen`).

**Screen summary entry:**
| StageExploreScreen | `flow.stage` (preview) | stage_name, objective_count, objectives[] ({obj_index, obj_type, obj_description, reveal_hint, required, completed}), directive, map_width, map_height, map_entry_pos, map_situations[] ({pos, revealed, resolved, type}) | cta.start, nav.back |
| StageExploreScreen | `flow.stage_explore` | map_width, map_height, party_pos, turn_count, party_state, objectives_found, objectives_total, **objectives[]** ({type, label, reveal_hint, completed, required}), **objectives_remaining**, situations[] ({id, pos, revealed, resolved, type, is_objective}), party_preview (each with **`emotional_status`** — P5), **party_calling_actions[]**, **party_requesting_return**, **directive** ({id, label} — P5 composite for UI display; individual directive-derived fields like `step_budget` unchanged), **travel_bark** ({actor_name, line} or {} — P5 transient echo journey bark, present only on advance turns where the party moved), **travel_snippet** (String — P5 transient Anansi ghost text, "" when no event fired), [situation_pending ({situation_id, revealed, type, is_objective, intel_clues, **choices[]** ({id, label} — P5, obstacle/structure only, empty for all other types), intel_quality, enemy_estimate})], [situation_overlay], [return_home_result], **[contact_pending]** ({role, role_label, name, virtue_primary, disposition, fear, morale, turn_current, turn_count, state}), **[contact_responses]** ([{echo_id, echo_name, calling, response_text, resonance_score, emotional_readiness, stat_texture, is_calling_aligned, bid_type}]), **[contact_echo_bids]** ([{echo_id, echo_name, bid_type, bid_label}]), [contact_result] ({role, outcome, outcome_text}) | cta.advance_turn, cta.return_home, nav.back, [cta.engage_situation], [cta.ignore_situation], **[cta.resolve_situation_choice.{choice_id}]** (P5 — obstacle/structure choice CTAs → `stage.resolve_situation_choice`; >2 choices warned + dropped), [cta.proceed_to_stage_map], [calling-bonus slots], **[cta.disengage_contact]**, **[cta.speak_response.{echo_id}]**, **[cta.consult_echoes]** |

**V2-STAGE-002 UI additions (`StageExploreScreen.gd` + `.tscn`):**
- Travel animation: board tweens to new party position (`_TRAVEL_DURATION = 0.5 s`, SINE ease). `SituationLayer` position mirrors `_board.position` in `_process()` so markers travel with the board.
- `SituationMarkerDraw.gd` — custom `Node2D` that draws typed shapes per situation: combat = square, shrine = triangle, loot/money = diamond, other = circle. Hidden = grey circle+?. Resolved objective = gold shape+✓. Revealed objective = blue shape + gold ring (+3.5 px arc).
- Engagement popup header: "Objective" (Akan Gold) vs "Encounter" (white) based on `is_objective`.
- "Pass" button (`IgnoreButton`) in the popup → dispatches `stage.ignore_situation`.
- "Stage Complete" button (`StageCompleteButton`) in action bar → shown when `cta.proceed_to_stage_map` present → dispatches `flow.complete_stage`.

**V2-STAGE-004 Phase 5 UI additions (`StageExploreScreen.gd` + `.tscn` + new venture components):**
- `StepProgressBar.gd` (new) — kente-segment bar; segments = the ACTUAL steps taken this advance, depleting per tile with the travel tween; at rest shows the full budget; "Steps x/y" readout where y = active directive's `step_budget` (data-driven).
- `DirectiveBadge.gd` (new) — glyph + label + tint, dict-driven: Mist Blue scout / Akan Gold seek.
- `GhostFootprintLayer.gd` (new) — fading trail on traveled cells; board-parented so it tracks board pan/zoom.
- TravelSnippetLabel — Anansi ghost text (cream + dark outline, ~17.5:1); driven by `data.travel_snippet`.
- Travel echo barks via an instanced BarkPopupLayer above the party token; driven by `data.travel_bark`. UI de-dupes replay via a last-played gate (the transient fields persist in the saved `explore_map`).
- Reveal scale-pop on situation markers; 200ms transition flash into combat-track engagements.

**Responsive exploration composition:** Explore mode uses a capped Living Tree HUD
card for Turn / Objectives / Party State with the directive badge on the same top
row. The cluster is informational and ignores input. The spatial field begins below
that row; Step budget and action controls occupy a separate bottom region above the
EchoBar exclusion. Stage preview hides the explore HUD and refits its authored
briefing plus map to the safe body. Live profile changes preserve the explored
world point and player zoom rather than resetting the camera.

**RealmShell routing:** Both `flow.stage` AND `flow.stage_explore` → `StageExploreScreen.tscn`. Shell scene-reuse logic ensures the same instance persists across the preview→explore transition; the zoom tween plays on the actual board.

---

### Deferred
- Full art: StageExploreScreen preview/explore states, StageMapScreen (scaffolds built; deferred to UI-006+)
- HP progress bar in RealmShell EchoBar (text label is current; bar deferred to UX pass)
- Sanctum bark spatial popup above echo tokens: deferred to V2-SANCTUM-005 (Phase D Alive Layer). Data pipeline (`_sanctum_bark` dict on echo save entries + `roster_preview.sanctum_bark`) is fully built by V2-VOICE-001. Text display in SanctumScreen roster cards ships in VOICE-001. Spatial positioning requires per-echo node identity which doesn't exist until SANCTUM-005.
- Multiple save slots (one slot is the current contract)
- Sanctuary upgrades affecting trait rolls (`generation_context` reserved for future modifiers)
