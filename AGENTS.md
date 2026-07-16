# Echoes vNext — Agent Instructions

> **For:** OpenAI Codex and any AI coding agent working in this repository.
> **Design canon:** `docs/Echoes vNext Working GDD.md` — nothing overrides it.
> **Architecture reference:** `CONVENTIONS.md` — full contracts, action types, system contracts.
> **Context + workflow:** `docs/CONTEXT.md` — working preferences, role separation, task flow.
> **Lessons learned:** `docs/LESSONS.md` — corrected behaviours. Read before starting any task.

---

## Project Identity

Godot 4.6.1 GDScript strategy game. Deterministic core simulation with snapshot-driven UI.
The player runs a Sanctum, summons Echoes (returning fragments of stolen stories), and leads them through Realm trials.

**Stack:** 100% GDScript. No web, no TypeScript, no Python. Godot 4.6.1 only.

---

## How to Run & Verify

### Compile check (no editor needed)
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --check-only --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext
```
Run this after every GDScript change. Zero errors expected.

### Tests
Tests run inside Godot via the Debug Panel (`F1` → `tests` command) or headlessly via `CoreTestRunner.gd`.
There is no standalone CLI test runner — Godot must execute the tests.

Run the full suite behind the same exact watchdog:

```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext -- tests
```

**Test suites** (all in `tests/`):
EconomyTests, SanctumSummonTests, PartyTests, ActorTests, EchoSchemaTests, ActorStatInitTests,
DerivedStatTests, BehaviorModuleTests, MeleeTests, BehaviorArbiterTests, StructureTests,
MoraleInfluenceTests, KODeathTests, EmotionTests, VectorTests, DirectiveTests, GridTests,
CombatStateTests, CombatServiceTests, CombatRoundTests, CombatSnapshotTests, RetreatTests,
ArchetypeTests, StageProgressionTests, SkillDefinitionTests, CallingBehaviorTests,
ExclusiveActionTests, CooldownTests, PassiveIdentityTests, SkillLoadoutTests,
MaturityExpressionTests, ThreadServiceTests, VowServiceTests, SocialGraphTests

---

## Repo Structure

```
core/       Deterministic simulation. No UI deps. Pure GDScript.
  actors/       Actor model, behavior, stats, emotion
  combat/       Combat resolution, shrine, retreat
  config/       ConfigService — loads data/balance.json
  directives/   DirectiveService
  economy/      EconomyService
  emotion/      EmotionService
  grid/         GridService (10×10 board)
  log/          StructuredLogger
  progression/  Skill definitions, thread service
  realms/       RealmModel, RealmService, RealmGenerator
  runtime/      FlowRuntime (single dispatch choke point)
  sanctum/      EchoFactory, SanctumService, SummonService, SocialGraphService, VowService
  save/         SaveService + schema
  state/        FlowStateMachine, FlowContext, FlowStateIds, all flow states

ui/         Snapshot renderer. Dispatches actions. No sim state access.
  shells/       SanctumShell, RealmShell
  screens/      One .tscn + .gd per screen. ScreenTemplate.gd is the base.
  components/   Reusable UI components
  overlays/     Modal/overlay nodes

data/       Read-only JSON configs
  balance.json  All tuning values — ConfigService loads this

tests/      Deterministic unit test suites

docs/       Project documentation
  CONTEXT.md          Working preferences + workflow (read first)
  MEMORY.md           Systems inventory + architecture reference
  LESSONS.md          Corrected behaviours — read before starting
  skills/             Skill reference docs (godot-echoes-dev, echoes-sankofa-gdd, etc.)
  Echoes vNext Working GDD.md   Primary design canon
  v2-migration-map.md           V1→V2 migration map

CONVENTIONS.md    Full architecture contracts
```

---

## Non-Negotiable Rules

### Determinism — never break these
- No `OS.get_unix_time()`, `randf()`, `randomize()`, `rand()` anywhere in `core/`
- All RNG via `CampaignSeed.derive("dot.separated.path")` → `RandomNumberGenerator`
- Sim tick `t: int` always injected by caller — never generated inside a service
- Never reorder `EchoFactory` RNG draws — only append at end; bump version string

### Single Choke Points — never bypass
- `FlowRuntime.dispatch(action)` — only entry for all state mutations
- `EconomyService` — only entry for Ase/Ekwan mutations
- `EmotionService` — only entry for emotion mutations outside mid-combat direct writes
- `SaveService` — only entry for persistence; one flush per dispatch tick

### Code Boundaries — never cross
- `core/` has zero UI node refs or Godot scene tree calls
- `ui/` never calls `dispatch()` directly; never reads `FlowContext`, `SaveService`, or any sim internal
- `data/` is read-only; schema changes are additive only (never remove or rename existing fields)

### Snapshot Shape — always enforce
```gdscript
{
  "type":    String,      # e.g. "flow.sanctum", "flow.encounter"
  "meta":    Dictionary,  # { t: int, ... }
  "data":    Dictionary,  # state-specific payload
  "actions": Dictionary   # slot-keyed — NEVER an Array
}
```
- `snapshot.actions` is always a **slot-keyed Dictionary** — never an Array
- Slot names: `nav.*`, `cta.*`, `overlay.*`, `primary`, `secondary`, `back`
- Per-row UI interactions (toggle, select) are dispatched by the row — never put in `snapshot.actions`

### Action Shape
```gdscript
{
  "type":     String,   # domain.subdomain.verb
  "slot":     String,   # matches key in snapshot.actions
  "label":    String,   # optional UI label
  "disabled": bool,     # optional — slot present but inactive
  "to":       String,   # optional — for flow.go_state
  "payload":  {}        # optional
}
```
Action type format: `domain.subdomain.verb` e.g. `flow.go_state`, `sanctum.party.toggle`

### Save Discipline
- Additive-only — never remove or rename fields in `save_data`
- Add new fields with safe defaults; old fields stay as compatibility aliases
- `flow_ctx.save_request = true` → FlowRuntime flushes once per dispatch tick
- Crash-safe: write to `.tmp` → rename to final path

### Actor Contract
- Actor dicts are **read-only views** — deep-copied at construction
- 18 REQUIRED_FIELDS checked by `ActorSchema.validate()` (see `CONVENTIONS.md`)
- Access top-level fields directly: `actor["speed"]` not `actor["stats"]["speed"]`
- `current_hp`, `speed`, `morale`, `fear` are top-level, NOT inside `stats`

---

## Naming Conventions

- Folders: `snake_case` (`core/state`, `ui/screens`)
- Scripts: `PascalCase.gd` — one class per file
- Data files: `snake_case.json`
- IDs and action types: `snake_case` strings using `domain.subdomain.verb`
- Logging: use `StructuredLogger.info(t, type, msg, data)` — never `print()`

---

## UI Rules

- **Build structure in `.tscn`** — scripts render values and apply profile values such as margins, columns, visibility, wrap widths, and min/max sizes
- Never create/reparent the UI hierarchy or construct visual styles programmatically in `.gd`; layout relationships and theme hooks belong in `.tscn`
- Reusable visual treatments belong in `assets/theme/LivingTreeSystem.tres`; extend the theme instead of restyling the same patterns per scene
- Godot 4.6.1 responsive base is 1280×720 landscape; desktop starts at 1600×900 and may resize down to 960×540
- Responsive means profile recomposition, capped readable UI, and spatial surplus on wide views — not uniform root scaling or scroll containers everywhere
- `SanctumShell` owns the inset BottomRail via `_cached_nav` — do NOT inject nav into snapshots
- `RealmShell` owns the inset, capped EchoBar (88 logical units high) — do NOT render it in individual screens
- Screens reserve safe edges and persistent bottom chrome; full-bleed spatial presentation may extend beyond the safe frame, actionable content may not
- AppRoot owns the single layer-40 blocking `ModalHost`; shell screens request modals by id and payload
- Blocking modal roots cover all chrome, stop underlying input, contain focus, and restore prior focus on dismissal
- Minimum target 48×48; primary CTA height 56; adjacent targets keep at least 8 units separation
- Canonical layers: world 0, screen 10, persistent chrome 20, non-modal transient 30, blocking modal 40, recovery/debug 128
- Every shell-owned `CanvasLayer` must mirror inherited shell visibility so hidden Realm/Sanctum layers cannot draw or intercept input
- No IDs in player-facing display — show names, standings, callings only

---

## Shell Routing

| Shell | Snapshot types |
|-------|---------------|
| `SanctumShell` | `flow.sanctum`, `flow.summon`, `flow.echo_party`, `flow.realm_select`, `flow.vow_manage`, `flow.weaving_rite` |
| `RealmShell` | `flow.stage_map`, `flow.stage`, `flow.stage_explore`, `flow.encounter`, `flow.keeper_trial`, `flow.resolve` |

AppRoot routes on `snapshot.type`. Shell routes to bespoke screen.

---

## V2 Terminology (use these, not V1 aliases)

| V2 (use this) | V1 (avoid) |
|---------------|-----------|
| `Storyweight` | `xp_total` |
| `Standing` | `rank` |
| `Step` | `level` |
| Virtue domain (10 domains) | vector (4 legacy) |
| `Scout Carefully` | `directive.scout` |
| `Seek Signs` | `directive.none` |
| Calling milestones at Standing 3/6/9 | rank 3 gate |

V1 aliases still exist in save data as compatibility fields — do not delete them; add V2 keys additively.

---

## V2 Alignment Wave — Current State (2026-04-10)

| Story | Status |
|-------|--------|
| V2-MIG-002 — Save schema bridge | Done |
| V2-PROG-001 — Progression language rename | Done |
| V2-PROG-002 — Calling seam unification | Done |
| V2-PROG-003 — Vector expansion (4→10) | Done |
| V2-PROG-004 — 6-calling set | Done |
| V2-PROG-005 — Skill family foundation | Done |
| V2-PROG-006 — Maturity-expression seam | Done |
| V2-WEAVE-001 — Thread recovery model | Done |
| V2-DIRECTIVE-001 — Directive rewrite | **Next up** |

Read `docs/v2-migration-map.md` before starting any Alignment story.

---

## Common Mistakes — Do Not Repeat

1. Using Array for `snapshot.actions` — always slot-keyed Dictionary
2. Putting per-row actions in `snapshot.actions` — rows dispatch directly
3. Calling `economy.ase.add` in tests — set `save_data["economy"]["ase"] = value` directly
4. Placing config keys in the wrong `balance.json` section — grep where FlowRuntime reads them first
5. Calling `refresh_snapshot()` expecting it to re-run `enter()` — it only re-reads `ctx.last_snapshot`
6. Creating UI nodes in `.gd` — all structure goes in `.tscn`
7. Reordering EchoFactory RNG draws — append only, bump version string
8. Uniformly scaling the whole UI on wide screens — cap UI and expose more spatial field
9. Adding a scroll container to solve every responsive problem — recompose primary layouts first
10. Letting autowrap determine first-pass geometry without authored/profile wrap widths
11. Leaving stale offsets on a full-rect container after changing responsive profiles
12. Hiding a shell Control without synchronizing its independent `CanvasLayer` visibility/input

Full lesson history: `docs/LESSONS.md`

---

## Workflow Expectations

- **Read the repo first** — never write subtasks or a plan without reading relevant files
- **Backend before frontend** — complete all `core/` changes before touching `ui/`
- **Confirm contracts first** — verify snapshot shape, action types, and service interfaces before implementing
- **Sanctum UI overhaul:** visible layers only, one screen story at a time, and use `docs/screens.md` as the authoritative screen ledger
- **If Sanctum implementation reality clashes with the approved screen spec:** stop and re-spec with Jeff before continuing
- **Every story ends with:** compile check → Jeff tests in-game → docs update → git commit
- **No speculative abstractions** — implement exactly what is asked, no more

---

## Key References

- `CONVENTIONS.md` — full system contracts (read for any implementation work)
- `docs/CONTEXT.md` — working preferences, workflow, environment notes
- `docs/MEMORY.md` — systems inventory, all service interfaces
- `docs/LESSONS.md` — corrected behaviours
- `docs/skills/godot-echoes-dev.md` — implementation patterns, checklists
- `docs/skills/echoes-sankofa-gdd.md` — design knowledge, V2 terminology
- `docs/Echoes vNext Working GDD.md` — primary design canon
