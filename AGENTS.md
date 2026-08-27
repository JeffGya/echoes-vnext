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

> **`--path` must be the checkout you are editing.** If you work in a git worktree
> (`.claude/worktrees/<branch>/`), pass that path. The literal path below is the main
> checkout and is usually on a different branch — running it verifies the wrong code.

> **Pass `timeout: 300000` on every Bash call that runs Godot.** The tool auto-backgrounds
> at 120s and the suite takes ~7 MINUTES (measured 2026-08-25; the old "~173s" in this file was stale by ~4 minutes). A backgrounded run cannot notify a subagent, so its
> work is lost. This has cost this project many agent-hours.

### Compile check (no editor needed)
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --check-only --quit --path <checkout>
```
Run this after every GDScript change. Zero errors expected.

### Rebuild the script class cache — do this FIRST when a new `class_name` file exists
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 400 /opt/homebrew/bin/godot --headless --import --path <checkout>
```
`--check-only` does **not** register a brand-new `class_name`, so you get
`Identifier "X" not declared`. Worse, a stale cache makes **existing fingerprint tests fail
with drifted hashes** — indistinguishable from a real regression. Five agents in a row have
lost a cycle investigating "pre-existing failures" that a rebuild cleared. Rebuild before you
believe any fingerprint failure.

### Tests
Tests run inside Godot via the Debug Panel (`F1` → `tests`) or headlessly. There is no
standalone CLI runner — Godot must execute them.

Full suite (**~7 minutes**, measured 2026-08-25 — `fingerprint` alone is ~3 min of it. Pass `timeout: 600000`, NOT 300000; 5 minutes now truncates a healthy run and looks like a hang):
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests
```

**One suite only (~5s)** — use this while working, and the full suite once at the end:
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests vow
```
The filter is a case-insensitive substring match on the suite name. **A filter that matches nothing prints the
suite list, runs zero tests, and emits NO `Tests:` line — while still exiting 0. Skim past that and
it reads as a pass.** Always confirm a `Tests:` line came back. Suite names are not file names:
`Stage004SeamTests` registers as `seam`, so the filter `stage004` matches nothing.

**Get the authoritative list from the runner, never from memory or a planning doc.** Regenerate it:
```bash
<godot ...> -- tests __nomatch__ 2>&1 | sed -n 's/.*Debug output "  \([a-z0-9_]*\)"/\1/p'
```
The 90 registered suite names, captured 2026-08-22:
```
actor arbiter archetype bark_popup behavior behavior_arbiter bond_trigger bridge calling
calling_behavior combat combat_baseline combat_initiative combat_roundtrip combat_terrain
combat_ui consequence contact contact_actor continuity conversation_repair cooldown derived
directive directive_cfg divergence divergence_bark echo_party echofactory economy emotion
exclusive_action explore explore_p5 expr fingerprint flow_transaction foundation_ui grid
identity institution intel ko_death leadership melee morale movement movement_arbiter
movement_option movement_path objective objective_combat old_echo onboarding passive prog realm
realm_prog realm_reward realm_ui recruit retreat reward sanctum_pulse save_integrity seam
shrine sit_res situational skill skill_loadout skill_unlock snapshot snapshot_contract
snapshot_fingerprint snapshot_purity social_graph stage statinit structure support terrain
thread traversal unified_resolve vector venture_char voice vow weave
```
Names that look right and are WRONG: `guide_spirit` (it is under `movement`), `stage_explore`
(it is `explore`), `stage_objective` (it is `objective`), `stage004` (it is `seam`).
 `tests snapshot` matches
`snapshot`, `snapshot_contract`, `snapshot_fingerprint` and `snapshot_purity`. An unmatched
filter prints the available suite names and runs nothing.

### Save isolation — DELETE THE WHOLE SAVE DIRECTORY BEFORE EVERY RUN

Suites write saves into a shared directory under `/tmp`. **Stale files there silently corrupt
results and produce false failures that survive a cache rebuild.** Always start a verification
run with the delete:

```bash
rm -rf /tmp/echoes-vnext-tests && <godot ... -- tests>
```

**Why.** `SaveService` writes six artifacts beside the primary save — `.pending_a`, `.pending_b`,
`.tmp`, `.bak1`, `.bak2`, `.bak3` ([SaveService.gd:173-181](core/save/SaveService.gd:173)). It
returns `LOAD_MISSING` only when *no* artifact exists ([SaveService.gd:116-118](core/save/SaveService.gd:116)).
A helper that deletes only the primary therefore leaves a recoverable backup, `boot()` never
reaches `make_new_save(<pinned seed>)`, and the test **resumes a previous run's campaign** — other
balances, other XP, another map, another hash. The production behaviour is correct; recovering from
a backup is what a crash-safe save system is for. The test harness is what is wrong.

Two tells that you are looking at contamination rather than a real regression:
- the "actual" hash **changes between identical runs**, or differs between a filtered and a full run
- a payload diff shows every integer arrived as a float (`43` → `43.0`) — that is a JSON round-trip,
  so the data was read back off disk instead of generated

**Never run two Godot processes against this project at the same time.** They share that directory
and contaminate each other. This applies to parallel subagents: serialize every test run.

### Reading the result — the runner ALWAYS exits 0
Exit status is not evidence. Only this line is:
```
Tests: 1442 total, 1442 passed, 0 failed
```
Pipe output to a file and grep the file. **Never re-run the suite to read a different field** —
the answer is already in the output you discarded.

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

### Scope Control — never overreach
- Do not perform work beyond the requester-defined scope. Audit findings are not authorization to fix adjacent issues.
- If out-of-scope work appears necessary, useful, or blocking, report it and obtain explicit requester approval before mutating files, external tools, tasks, identifiers, dependencies, or backlog state.

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
  - **Exception (V2-PROG-012 precedent):** a rename/removal is permitted when the old name is actively misleading or its value was unreachable (silently falling through to a code default), provided **every** consumer is migrated in the same change and no alias is left behind. V2-PROG-012 renamed four keys under this exception — `presence_dampen_scale` → `composure_dampen_scale`, `directive_band_mul` → `directive_interpretation_mul`, per-calling `absolute_fear_threshold` → `absolute_fear_offset`, `vector_to_virtue_primary` → `virtue_vector_key` — after auditing every `core/`, `ui/`, `tests/`, and `docs/` reference. Default to the additive-only rule; reach for this exception only with the same full-repo audit, and say so in the story writeup.

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

## Extraction & Refactor Rules

Learned the hard way during V2-INFRA-003, which moved ~1,800 lines out of `FlowRuntime.gd`.

### Extract shared services BEFORE the controllers that need them
Dependencies point from controllers to services, so services must exist first. If you extract a
controller while a helper it needs is still private on `FlowRuntime`, that controller has no legal
option — reaching back is forbidden, and so is duplicating. It will invent a workaround.

### A helper used by two or more domains has an owner. Find it.
- Reads a named subtree of `balance.json` → a static getter on `ConfigService`, beside
  `get_bond_thresholds_cfg` and friends. **Not** on a pure domain service: `EmotionService`,
  `SocialGraphService` and `MaturityExpressionService` all document that they never read
  `ConfigService` and only accept passed-in dicts. Giving them one breaks their own invariant.
- Reads save data for a domain → a **static** function on that domain's service.
- Wraps a domain class → a service placed **beside** that class
  (`VowConsequenceService` with `VowService`, `NarrativeVoiceService` with `ShoutBank`).

### Never duplicate a helper. Never substitute a lookalike API either.
Copying is banned — two copies drift. But the second-order mistake is worse: when copying is
forbidden, the tempting move is to reach for an existing public API that *looks* equivalent.
A real example: `_get_active_party_echoes()` (a pure `.get()` read, roster order) was swapped for
`SanctumService.new(save_data).get_party_actors()`. That changed iteration order, changed the data
shape, and introduced a **constructor that can write to save data**. Every test still passed.

If a helper has no clean owner, **stop and report a blocker.** Do not work around it.

### Constructing a service can mutate. Prefer static reads.
`SanctumService.new(save_ref)` builds `SanctumState`, which can call
`_ensure_sanctum_dict_exists()` and write to `save_data`. Never construct a service merely to read.
Use a static reader, or add one.

### Controllers vs services
- **Controller** — owns dispatched actions for one domain. Returns a `FlowActionOutcome` describing
  transition / snapshot / save intent. `FlowRuntime.dispatch()` applies that intent. Give it no
  `flow_machine`, so it *cannot* transition by itself.
- **Service** — consequence hooks and shared logic called from several domains. Any controller or
  service may call it.
- **Controllers must never call one another.** If two controllers need the same behaviour, it is a
  service.
- Neither may call `SaveService`. Request a save with `flow_ctx.request_save(reason)`.

### Tests that reach in by string name break silently
`runtime.call("_private_name", …)` is invisible to `--check-only`, so moving that method fails only
at runtime. Find these before extracting, and **rewrite the call site in the same change**. Do not
leave a delegating shim on `FlowRuntime` — a shim keeps the test green while proving nothing.

### File size and comments

**Aim to keep files under ~1,000 lines — and the guard counts CODE, not comments or blanks.**
Measure with `grep -vcE '^\s*(#|$)' <file>`, not `wc -l`.

- **Do not fragment a file to satisfy the number.** A new file must earn its existence by owning
  something. Splitting for a line count produces the same tangle spread across more files, which is
  harder to follow, not easier.
- **Core central files may exceed it**, with a written justification in the header saying why the
  content is one unit.

**Comments: write what a reader needs, not the history of the change.**

| Belongs in the file | Belongs elsewhere |
|---|---|
| What this file owns, in a few lines | How it came to be here — that is the commit message |
| A constraint that prevents a mistake: a determinism hazard, a load-bearing order, a shared-state trap | Alternatives considered and rejected |
| A defect note at the site, one or two lines | The full defect analysis — that is the register's job |
| | Slice numbers, phase names and process narrative |

**Delete legacy and superseded comments when you encounter them.** A comment describing code that has
moved, or naming a story that has been renumbered, is not explanation — it is a trap. It also costs
parse time and reader attention for nothing.

### When you reach the site of a known defect, investigate and record
> **SCOPE: story V2-INFRA-003 ONLY. Delete this section when that story ships.**
> It exists because that one refactor touches most of `core/` and produced a 76-entry register.
> It is not a standing rule for other work.

`docs/v2-infra-003-defect-register.md` lists every known defect with an ID (`D01`…), a location, and
a classification. **Read it before you start any V2-INFRA-003 slice.**

If your work brings you to the location of a listed defect:

1. Do a short investigation. Why is it a defect? What is the correct behaviour? What would fixing it
   change — does it move a fingerprint or a recorded baseline?
2. **Do not fix it.** The extraction stays behaviour-neutral.
3. **Write your finding into the register entry**, under that defect's ID. Add what you learned;
   do not overwrite what is there.

If you find a defect that is NOT in the register, add a new entry with the next free ID, the same
columns as the existing rows, and mark it as found during your slice.

Rationale: standing at the code is the cheapest moment to understand it. A defect note written from
the call site is worth more than one written later from a grep. The register is the single place
these decisions are made, so a finding recorded anywhere else is lost.

**Again: this applies to V2-INFRA-003 only.** Remove this section with the story.

### Characterization before behaviour change
Record what the code does today, including its bugs, and label each one
`# KNOWN DEFECT (<story> will change this):`. Invert the assertion in the phase that fixes it.
A probe that asserts the fixed behaviour before the fix exists tempts the next agent to "fix"
production code to make its own test pass.

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
13. Running Godot without `timeout: 300000` — the Bash tool auto-backgrounds at 120s and a subagent then loses all its work
14. Believing a fingerprint failure before rebuilding the script class cache with `--import`
15. Trusting the runner's exit code — it is always 0; only the `Tests: N total, N passed, M failed` line is evidence
16. Re-running the full suite to read a different field instead of grepping the log you already produced
17. Dispatching `flow.new_game` in a characterization test — `_generate_seed_root_string()` uses `Crypto.generate_random_bytes()`, so the campaign seed differs every run. Drive onboarding from `boot()`, which uses the pinned literal seed when no save exists
18. Constructing a service just to read from it — `SanctumService.new()` can write to `save_data` via `SanctumState._ensure_sanctum_dict_exists()`. Use a static reader
19. Duplicating a shared helper, **or** swapping in a lookalike API to avoid duplicating it. Both drift. If a helper has no clean owner, stop and report a blocker
20. Leaving a delegating shim on `FlowRuntime` so a reflection-based test keeps passing — the shim proves the extraction did *not* happen
21. Diagnosing a fingerprint failure without first deleting the shared `/tmp` save directory — a leftover `.bak1` makes the harness resume an old campaign, and the failure looks exactly like a real regression through a cache rebuild, a clean checkout and four repeat runs
22. Running two Godot test processes concurrently — they share the save directory and corrupt each other's results
23. Re-baselining a fingerprint constant to make the suite green before you can explain what moved — a constant you recalibrated without understanding is worse than no guard, because it still looks like protection
24. Reading a filtered run as green without checking a `Tests:` line came back — an unmatched filter runs nothing, prints nothing, and exits 0. Suite names differ from file names (`Stage004SeamTests` registers as `seam`)

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
