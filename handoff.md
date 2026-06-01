# Echoes vNext — Agent Handoff Document
> Date: 2026-05-12 | Branch: `main` | Prepared by: Claude Sonnet 4.6

---

## MANDATORY FIRST STEP — READ ALL FOUR BEFORE ANYTHING ELSE

The way of working described in these four documents is **non-negotiable**. Do not proceed past this step until all four have been fully read. These override all default AI behavior.

1. **`MEMORY.md`** (project root) — Full project context, systems inventory, V2 migration state, way of working
2. **`CLAUDE.md`** (project root or `~/.claude/CLAUDE.md`) — Plan-first, backend-first, confirm before changing, every story ends with Docs + Commit
3. **`CONVENTIONS.md`** (project root) — All architecture contracts: snapshot shape, action types, save discipline, code boundaries
4. **`~/.claude/lessons.md`** — Past mistakes and the rules derived from them. Follow every rule in this file strictly. These override default behaviour.

Do not write a single line of code until you have read all four in full.

---

## REQUIRED SKILLS — LOAD AND USE FOR ALL DECISIONS

These skills are authoritative and must be used proactively throughout all work. Do not guess at game design, lore, or architecture — check the skills first.

| Skill | When to use |
|---|---|
| `godot-echoes-dev` | Any implementation question — patterns, invariants, flow state IDs, action types |
| `echoes-sankofa-gdd` | Any design decision — GDD, lore, callings, Weave system, economy intent |
| `game-ui-ux-echoes` | Any UI/UX question — screen patterns, touch targets, West African aesthetic, snapshot-to-screen |
| `echoes-backlog` | Any story lookup — status, wave, dependencies, pickup order |
| `anthropic-skills:game-mechanics-designer` | Verify game mechanics are correctly implemented and coherent |
| `anthropic-skills:game-design` | Verify that implementation matches design intent |

---

## CONTEXT: WHERE WE LEFT OFF

This session closed mid-work with the following open items:

1. **V2-ECONOMY-001** — Marked Done in migration map, but a full end-to-end implementation audit is needed (see section below).
2. **V2-VOW-002** — Marked Done in migration map, but same — full verification required.
3. **V2-SANCTUM-001** — Implemented on branch `feat/v2-emotion-002`, NOT yet merged to main. Conflicts with current main.
4. **Branch hygiene** — 7 stale branches on local + remote need to be audited and cleaned.
5. **No unnecessary code** — The previous session introduced some regressions and redundant elements during conflict resolution. The audit agent must verify nothing extraneous remains.

---

## PART 1 — BRANCH AUDIT (DO THIS FIRST)

### What exists

**Local branches:**
- `main` — current working branch. Has all V2-ECONOMY-001 and V2-VOW-002 work.
- `feat/v2-emotion-002` — contains **one commit**: V2-SANCTUM-001 (post-run consequence pass + emotion recovery). NOT merged. Built on older main.
- `codex/echo-manage-scene-first-pr` — 0 commits ahead of main. Stale.
- `codex/primary` — 0 commits ahead of main. Stale.
- `codex/startup-pass` — 0 commits ahead of main. Stale.
- `feat/bond-001-social-graph` — 0 commits ahead of main. Stale.
- `feat/vow-001-vow-system` — 0 commits ahead of main. Stale.
- `v2-bond-001-seam-audit` — 0 commits ahead of main. Stale.
- `v2-emotion-003` — 0 commits ahead of main. Stale.
- `codex/keeper-intro-rewind` — 0 commits ahead of main. Stale.

**Remote `claude/*` branches** (on origin):
- `origin/claude/serene-bardeen-4ce006`
- `origin/claude/strange-jepsen-ce37df`
- `origin/codex/keeper-intro-rewind`

### Agent task: Branch Audit Agent

Spawn a dedicated agent to answer these questions for EACH branch:

1. Is it **0 commits ahead of main**? If yes — is its work already in main? Verify by checking key files, not just commit count.
2. If a branch has work NOT in main — what exactly is it? File-by-file diff summary.
3. Is the work **still needed** or has it been superseded by a later story?

For `feat/v2-emotion-002` specifically:
- V2-SANCTUM-001 commit modifies: `CONVENTIONS.md`, `core/emotion/EmotionRecoveryService.gd`, `core/runtime/FlowRuntime.gd`, `core/sanctum/ConsequencePassService.gd`, `core/save/SaveSchema.gd`, `core/save/SaveService.gd`, `core/state/flow/FlowContext.gd`, `core/state/flow/states/sanctum/FlowSanctumState.gd`, `data/balance.json`, `docs/v2-migration-map.md`, `tests/SanctumPulseTests.gd`, `ui/AppRoot.gd`, `ui/screens/sanctum/RunConsequenceNotificationChip.gd/.tscn`, `ui/screens/sanctum/SanctumScreen.gd`, `ui/screens/sanctum/SanctumScreen.tscn`
- The new service files (`ConsequencePassService.gd`, `EmotionRecoveryService.gd`, `RunConsequenceNotificationChip.*`, `SanctumPulseTests.gd`) are pure additions — check if they exist in main already
- The shared-file modifications (FlowRuntime, SanctumScreen, balance.json) were built on an older version of main — verify if the V2-SANCTUM-001 logic additions are already in main or still missing
- **Do not merge anything.** Report findings to Jeff. Jeff decides what gets integrated.

---

## PART 2 — V2-ECONOMY-001 IMPLEMENTATION AUDIT

### Original plan (from `docs/v2-migration-map.md` Domain 6)

V2-ECONOMY-001 — "Reframe early economy cadence so awakening, first summons, stage payouts, withdrawal, and offline Ase recovery match the V2 opening loop."

**What was supposed to be done:**

| Item | Target |
|---|---|
| `economy.ekwan` | Wired to stage rewards; displayed on Sanctum hub |
| `EconomyService.reward_stage_complete()` | Extended with `ekwan_factor`; awards Ekwan; `reward_breakdown` entries include `currency` field |
| Ase Flame dormancy gate | `sanctum.ase_flame.awakened` gates offline accrual; set on onboarding completion; 40 Ase granted |
| Scout-return resolve screen | Retreat/return_home always routes to RESOLVE with intel-gated partial Ase |
| Offline accrual | Flat cap 8hr; gated by `ase_flame.awakened` |

**Config targets (balance.json):**
```
data.economy.ase_online_per_min_base: 0.3
data.economy.sanctum_bank_interval_seconds: 240
data.economy.offline_cap_seconds: 28800 (8 hours)
data.economy.offline_start_factor: 0.05
data.economy.awakening_ase_grant: 40
```

**What was explicitly deferred (NOT in scope for V2-ECONOMY-001):**
- Relics (new currency)
- Faith / Harmony / Favor (visible states)
- Threads reserve
- Ase offline accrual degradation based on Sanctum stability

### Agent task: Economy Audit Agent

Spawn a dedicated agent to verify:

1. **`EconomyService.gd`** — Does `reward_stage_complete()` exist? Does it award Ekwan with a `currency` field in breakdown entries?
2. **`FlowRuntime.gd`** — Is `_apply_offline_accrual_if_needed()` gated by `sanctum.ase_flame.awakened`? Does onboarding name-confirm set `awakened = true` and grant 40 Ase?
3. **`balance.json`** — Are all the above config keys present with correct values? Is there any extra economy config that shouldn't be there?
4. **`SanctumScreen.gd` / `SanctumScreen.tscn`** — Is `EkwanLabel` present, wired, and visible only when `ekwan_balance > 0`? Is there any leftover duplicate economy panel (RightSidebar or equivalent)?
5. **`ResolveScreen.gd` / `ResolveScreen.tscn`** — Is `EkwanRow` present, wired, visible only when `ekwan_awarded > 0`? Does `RewardEntryItem.setup()` correctly handle `currency: "ekwan"` vs `currency: "ase"` with correct colors?
6. **Tests** — Do `EconomyTests.gd` cover: offline gate blocked (dormant flame), offline gate passes (awakened flame), awakening trigger (name confirm → grant)? Are these real FlowRuntime calls (not stubs)?
7. **No unnecessary code** — Check for any dead `@onready` refs, removed nodes still referenced, duplicate panels, no-op color overrides on container nodes (not labels).

For every item: report Pass / Fail / Gap with the exact file path and line number.

---

## PART 3 — V2-VOW-002 IMPLEMENTATION AUDIT

### Original plan (from `docs/v2-migration-map.md`)

V2-VOW-002 — "Surface active vow pressure during runs and make break or release fallout readable on return to the house."

**What was supposed to be done:**

| Item | Target |
|---|---|
| Passive proverb mantra | `active_vow: { vow_id, vow_name, proverb_twi, proverb_en, tier }` added to `flow.stage` snapshot |
| `vow_outcome` transient field | Added to `FlowContext`; cleared on stage entry; populated by `_apply_vow_break_aftermath()` (break) and `_store_vow_benefit_preview()` + `_apply_vow_stage_complete_benefit()` (benefit) |
| `vow_outcome` in resolve snapshot | Added to `flow.resolve` final snapshot |
| ResolveScreen vow display | Shows "The promise fractured." / "The promise held." + vow name + signed deltas (morale/fear/ase) |
| No vow data during combat | Design decision — no vow pressure display in encounter/combat screen |
| Tests | 3 new deterministic VowServiceTests: `mantra_projection_active_vow`, `outcome_shape_from_break`, `no_mantra_no_active_vow` |

**Also in this session (regression fixes applied):**
- `V2-VOW-002` backend shipped multiple commits: compliance tracking, condition hints, session effects, frontend vow pressure display, outcomes panel, persistent debuff (pledge cooldown after vow break), lifetime stats persistence

### Agent task: Vow Audit Agent

Spawn a dedicated agent to verify:

1. **`FlowContext.gd`** — Is `vow_outcome` declared? Is it cleared on stage entry?
2. **`FlowStageState.gd` (or wherever stage snapshot is built)** — Is `active_vow` injected into the `flow.stage` snapshot with the correct shape: `{ vow_id, vow_name, proverb_twi, proverb_en, tier }`?
3. **`FlowRuntime.gd`** — Do `_apply_vow_break_aftermath()`, `_store_vow_benefit_preview()`, and `_apply_vow_stage_complete_benefit()` exist and populate `flow_ctx.vow_outcome`?
4. **`FlowResolveState.gd`** (or wherever resolve snapshot is built) — Is `vow_outcome` injected into the `flow.resolve` snapshot?
5. **`ResolveScreen.gd` / `ResolveScreen.tscn`** — Are the vow outcome nodes present (`VowOutcomeSection`, `VowOutcomeList`)? Does the screen render "The promise fractured." / "The promise held." correctly when a vow outcome exists? Is it hidden when no vow outcome is present?
6. **`SanctumScreen.gd`** — Is `VowMantraLabel` displayed with the active vow's proverb text during `flow.sanctum`? (The vow mantra shows in the hub under the title when a vow is active.)
7. **`VowService.gd`** — Do the three VowServiceTests pass? Is pledge cooldown logic clean and not mixed with other systems?
8. **ActiveEffectsPanel** — Is the `_effects_panel` / `_effects_list` / `_effect_detail` node structure present in `SanctumScreen.tscn` and wired in `SanctumScreen.gd`? Does it show the broken-vow debuff chip? Is there a duplicate `EffectDetailPanel` node?
9. **No unnecessary code** — Check for any orphaned UI nodes that were added during merges but no longer referenced in `.gd`. Check for any V1-era compliance/condition code that was superseded.

For every item: report Pass / Fail / Gap with exact file path and line number.

---

## PART 4 — THEME, ART DIRECTION & DESIGN SYSTEM COMPLIANCE AUDIT

Use the `game-ui-ux-echoes` skill and `anthropic-skills:ui-design-system` skill for this section.

### What to check

**Design system rules (non-negotiable):**
1. All visual structure in `.tscn` — never create nodes dynamically in `.gd` via `Node.new()` unless it's a pool/overlay with no persistent scene equivalent
2. Colors, font sizes, separations, StyleBoxFlat properties — all authored in `.tscn`, not in `.gd`
3. `.gd` may only update: `.text`, `.visible`, `.disabled`, `.modulate`, `add_theme_color_override` for data-driven colors only
4. Theme variations (`theme_type_variation`) must use the design system's registered variants — never invent new ones inline
5. Minimum touch target: 48×48dp on any interactive element
6. Mobile-first: all layouts must work in portrait at 1080×1920

**Specific screens to audit:**

| Screen | Key concerns |
|---|---|
| `SanctumScreen.tscn` | RightSidebar fully removed? EkwanLabel uses correct theme variation? AseFlameTip correct? No duplicate nodes from merge artifacts? |
| `ResolveScreen.tscn` | EkwanRow properly styled? VowOutcomeSection/VowDiscoveredSection correctly hidden by default? Button row uses `ButtonPrimary`/`ButtonSecondary` theme variations? |
| `RewardEntryItem.tscn` | Ekwan color (`Color(0.91, 0.627, 0.188, 1)`) authored in `.gd` only (data-driven) — correct since it's conditional |
| `RunConsequenceNotificationChip.tscn` (if present in main) | Gold border, center-bottom positioning, `mouse_filter=IGNORE`, 5s display rule |

**West African aesthetic compliance:**
- Warm palette (ochre/amber for Ekwan, cream/gold for positive values)
- No cold blues or harsh reds for primary UI (those are reserved for fear/distress signals)
- Typography hierarchy: `HeaderTitle` for screen titles, `StatsPanel` for stat values, standard Label for body text
- Verify no ad-hoc `theme_override_colors` that diverge from the palette

**Agent task: Design Audit Agent**

Spawn a dedicated agent to:
1. Read the art direction reference from `game-ui-ux-echoes` skill
2. Audit all modified `.tscn` files from recent commits against the design system
3. Flag any node that has inline style overrides that should be in the theme resource instead
4. Flag any `.gd` file that creates or styles nodes dynamically when a `.tscn` approach exists
5. Report a pass/fail table with file paths

---

## PART 5 — FLOW VERIFICATION (END-TO-END)

### The critical path to verify

These flows must be traced from action dispatch through state transition to snapshot to UI:

**Flow A: Awakening → First Summon → First Stage**
1. New game dispatch → `FlowRuntime._handle_new_game()` → correct starting state
2. Name confirm dispatch → `_handle_onboarding_name_confirm()` → `ase_flame.awakened = true`, 40 Ase granted, correct state transition
3. Summon dispatch → `SummonService.summon_paid_one()` → Ase deducted → correct echo generated → snapshot correct
4. Realm select → Stage select → Stage enter → Encounter → Resolve
5. On resolve: Ase awarded, Ekwan awarded (if applicable), vow outcome (if vow active) all in snapshot
6. "To Sanctum" button → correct state transition → Sanctum snapshot includes ekwan_balance, vow mantra if active

**Flow B: Stage Defeat → Return to Sanctum**
1. All echoes dead or retreat dispatch
2. Resolve screen shows DEFEAT banner
3. Scout-return variant: partial Ase awarded, no Ekwan (intel-gated)
4. "To Sanctum" → consequence pass → normal Sanctum

**Flow C: Active Vow → Stage → Break**
1. Active vow present in save
2. Stage snapshot includes `active_vow` with proverb
3. Vow condition violated during stage
4. `vow_outcome` populated on resolve snapshot
5. ResolveScreen shows vow outcome section with "The promise fractured." + deltas

**Agent task: Flow Verification Agent**

Spawn an agent to trace these flows in the code — not run the game, but verify the code path exists and is correct by reading the relevant source files. For each flow step, identify the method, file, and line where the transition happens. Report any broken or missing links.

---

## PART 6 — FINAL INTEGRATION DECISION (JEFF MUST APPROVE)

After all audit agents have reported, present Jeff with a single consolidated decision document:

1. **Stale branches** — Which ones are safe to delete? Which ones have unreleased work?
2. **`feat/v2-emotion-002` (V2-SANCTUM-001)** — Is it needed? Is any of its work already in main? What's the cleanest integration path (manual file-by-file integration recommended — no git merge)?
3. **Any gaps found in V2-ECONOMY-001 or V2-VOW-002** — Exact list of what needs fixing, with file paths.
4. **Any design system violations** — Exact list with file paths and what needs changing.

**Do not fix anything without Jeff's approval.** Present findings, wait for go-ahead, then fix.

---

## PART 7 — AFTER JEFF APPROVES: FIX WORKFLOW

Follow this sequence strictly:

### For each fix:
1. **Plan first** — write checkable subtasks, confirm with Jeff
2. **Backend first** — all `.gd` logic before any `.tscn` changes
3. **One concern at a time** — don't mix economy fixes with vow fixes in one commit
4. **Verify** — after each fix, run headless Godot tests and confirm pass count
5. **Pause for Jeff** — manually test the fixed flow in-game before committing
6. **Commit** — scope-limited commit with co-author tag

### Test command
```bash
godot --headless --quit -- tests
```

### Commit format
```
fix(<scope>): <description>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### PR rule
Work on a feature branch. Open a PR for Jeff to merge. Never push directly to main.

---

## REFERENCE: KEY FILES

| File | Purpose |
|---|---|
| `core/economy/EconomyService.gd` | Ase/Ekwan mutations — single choke point |
| `core/economy/EconomyAccrualService.gd` | Offline Ase accrual |
| `core/runtime/FlowRuntime.gd` | Dispatch choke, state transitions, save trigger |
| `core/state/flow/FlowContext.gd` | Runtime state including `vow_outcome`, `last_run_consequence` |
| `core/sanctum/VowService.gd` | Vow condition eval, break/benefit logic |
| `core/state/flow/states/venture/FlowResolveState.gd` | Resolve snapshot builder |
| `core/state/flow/states/venture/FlowStageState.gd` | Stage snapshot (active_vow injection) |
| `ui/screens/sanctum/SanctumScreen.gd` / `.tscn` | Sanctum hub — EkwanLabel, VowMantraLabel, AwakeningOverlay |
| `ui/screens/venture/ResolveScreen.gd` / `.tscn` | Resolve — EkwanRow, VowOutcomeSection, RewardEntryItem |
| `ui/components/RewardEntryItem.gd` / `.tscn` | Reward breakdown row — currency-aware coloring |
| `data/balance.json` | All config — verify economy and vow keys |
| `docs/v2-migration-map.md` | Authoritative record of what each story implemented |
| `CONVENTIONS.md` | Architecture contracts — read before touching any core file |

---

## REFERENCE: KNOWN ISSUES FROM PREVIOUS SESSION

1. **Merge conflict residue** — Previous session had a bad conflict resolution that introduced duplicate nodes and dead `@onready` refs. These were partially fixed. The audit must confirm no residue remains.
2. **`feat/v2-emotion-002` conflict** — 10 files conflict between V2-SANCTUM-001 (on this branch) and V2-ECONOMY-001 (now on main). **Aborted** — no merge in progress. Branch is untouched. Manual integration is the recommended path.
3. **RunConsequenceNotificationChip** — V2-SANCTUM-001 adds this chip to `SanctumScreen`. It was NOT in main as of session close. It may or may not be needed now depending on the branch audit findings.
4. **`_apply_sanctum_emotion_tick()`** — The old V1 emotion tick in FlowRuntime. V2-SANCTUM-001 removed it and replaced with a proper settlement model. Verify current main: does it still have the old tick or the new settlement?
5. **`ase_rate_label` vs `ase_flame_tip`** — During this session, `AseRateLabel` was renamed to `AseFlameTip` in the `.tscn`. The `.gd` must reference `%AseFlameTip`, not `%AseRateLabel`. Verify this is consistent.

---

## AGENT ORCHESTRATION GUIDE

The next session should spawn these agents in this order:

```
Session start:
  ↓ Read MEMORY.md + CLAUDE.md + CONVENTIONS.md + lessons.md (main chat)
  ↓ Load required skills (main chat)
  
Phase 1 (parallel):
  → Branch Audit Agent         (which branches are stale vs. needed?)
  → Economy Audit Agent        (V2-ECONOMY-001 pass/fail/gap)
  → Vow Audit Agent            (V2-VOW-002 pass/fail/gap)
  
Phase 2 (after Phase 1 reports):
  → Flow Verification Agent    (end-to-end flow trace)
  → Design Audit Agent         (theme/art direction compliance)
  
Phase 3 (consolidated):
  → Present Jeff with single decision document
  → Wait for approval
  
Phase 4 (after approval, sequential):
  → Fix gaps (one story scope per commit)
  → Test → pause → commit
```

All agents must use the four required skills. No agent may change files without reporting to main chat first.

---

*Handoff created: 2026-05-12. Working directory: `/Users/jeffreygyamfi/Sites/echoes-vnext`. Current branch: `main`.*
