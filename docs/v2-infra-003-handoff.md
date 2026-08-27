# V2-INFRA-003 — Handoff

> **Status: PHASES 1–9 COMPLETE AND COMMITTED (through `bf8360e`). Suite 1,401 → 1,494.
> Phase 10 — Jeff's manual first-session test — is next. PAUSE HERE.**
> Branch `claude/v2-infra-003-proof-spine-b3c770` (git worktree).
> Full plan: `~/.claude/plans/we-are-working-on-jazzy-gem.md` — keep it for reference lookup.
> Written 2026-08-15.

---

## 1. What this story is

Two halves. Both must ship together, on one branch, in one PR.

**Half A — Flow decomposition.** `FlowRuntime.gd` was 10,061 lines. It routed 73 action types,
held 200 functions, and owned onboarding, combat rounds, movement context, stage traversal,
contacts, vows, bonds, barks and settlement directly. Snapshot builders paid rewards and wrote to
disk. Half A gives every action exactly one owner and reduces `FlowRuntime` to a composition and
transaction shell.

**Half B — Opening proof spine.** Using those boundaries, repair the first-session arc so it runs
coherently from New Game to ordinary Sanctum navigation.

Notion page: `339c3d1e-de92-81ae-9e2c-d4eae469ae3d`. Spec State **Locked**, P0, Order 260.

---

## 2. Current state

| Metric | Start | Now |
|---|---:|---:|
| `core/runtime/FlowRuntime.gd` | 10,061 lines | **1,885** (−81%) |
| `FlowEncounterState.gd` | 2,170 lines | **446** (−79%) |
| Test suite | 1,401 | **1,482**, all passing (verified cold) |
| Reflection call sites into `FlowRuntime` privates | 50 | **0** (corrected — see below) |

> **Metric corrected, Half A review corrections, 2026-08-24.** The "**3**" in the row above was
> wrong, and so was the gate's re-count of "**6**", because both mixed two different things under
> one label. Split properly:
>
> | Kind | Before C1 | After C1 |
> |---|---:|---:|
> | **String-name reflection** into a `FlowRuntime` private — `runtime.call("_x", …)`, invisible to `--check-only`, the anti-pattern `AGENTS.md` mistake 20 names | **5** (all in `tests/EconomyTests.gd`: `:70`, `:94`, `:95`, `:114`, `:134`) | **0** |
> | **Direct, compile-checked** access to a `FlowRuntime` private from a test — `runtime._x(…)` | **19** | **19** |
>
> All five string-reflection sites were `_apply_offline_accrual_if_needed`; extracting that block
> (correction C1) deleted every one of them. There are now **no** string-name reflection call
> sites into `FlowRuntime` privates anywhere in `tests/` or `tools/`.
>
> The 19 direct accesses are a different and much weaker category — they break the build rather
> than a run when a name moves, which is exactly the property the rule exists to buy. They are:
> `runtime._apply_action_outcome(…)` ×3 and `runtime._apply_victory_return_to_explore(t)` ×1
> (`tests/Stage004SeamTests.gd`), plus 15 calls through the private per-call FACTORIES —
> `runtime._contact_controller()` ×6 (`Stage004SeamTests`, `VentureCharacterizationTests`) and
> `runtime._recruitment_consequence_service()` ×9 (`Stage004SeamTests`). The 15 factory calls are
> arguably not "reaching into a private" at all: what the test uses is the public controller or
> service the factory returns, and the factory is private only because production has no other
> caller. Left as they are — changing them is test-surface work, not extraction.
| Controllers | 0 | 9 |
| Extracted services | 0 | 27 |

**Half A is committed as `aa8147d`** — 160 files, +25,263 / −12,482. The tree is clean. Half B
commits on top of it, on the same branch, and both ship in one PR.

| Phase | State |
|---|---|
| 1 Contract freeze + characterization | ✅ Gate returned APPROVED WITH CORRECTIONS; all applied |
| 2 Transaction contract | ✅ |
| 3 Snapshot ownership | ✅ (slices A, B1, B2, C) |
| 4 Noncombat controllers | ✅ (10 slices) |
| 5 Venture + contact | ✅ 5.0 · 5A · 5B · 5C · 5D · 5E all done |
| 6 Encounter + combat | ✅ **COMPLETE.** `FlowRuntime` 10,061→2,070 · `FlowEncounterState` 2,170→446 · `enter()` 982→7 · CombatController filed to V2-COMBAT-004 |
| 7 Thin shell + Half A review gate | ✅ APPROVED WITH CORRECTIONS; all 6 in-scope applied. C7 (payment) deferred to the after-Phase-9 bundle. **Committed.** |
| 8 Proof spine + settlement (Half B) | ✅ 8A settlement · 8B durable result + real Resolve · 8C opening spine |
| 9 Full regression | ✅ see below |
| 10 Jeff manual test | ⬜ **PAUSE — next** |
| 11 Docs + register→ledger + PR | ⬜ |
| Extra — remove job-2 legacy save migrations | ✅ Jeff approved folding into this story |

---

## 3. Architecture built

### Controllers — `core/runtime/controllers/` (9)
| Controller | Lines | Phase |
|---|---:|---|
| `WeaveController`, `VowController`, `DebugController`, `ProgressionController`, `EconomySettlementController`, `SanctumController`, `OnboardingController` | — | 4 |
| `ContactController` | 800 | 5C |
| `VentureController` | 586 | 5D |

**There is no `CombatController`, deliberately.** The six combat/encounter actions are `FlowRuntime`-owned by decision, not provisionally. Three blockers remain (mid-body transition, the paired `_end_round`, and a per-call cache lifetime); the cost to build it later is ~250 lines of which about **ten** are the real control-flow change. Filed as a full handoff section on the **V2-COMBAT-004** Notion page, 2026-08-24 — which also corrects that story's own audit addendum, since it instructs its implementer to wire `ProtectCustodyService` through a controller that does not exist. Correct target: `core/combat/CombatRoundObjectiveService.gd`.

Contract for every one:
- typed `RefCounted`, explicit constructor dependencies
- **no `flow_machine`** — so it structurally cannot transition
- never calls `FlowRuntime`, another controller, or `SaveService`
- saves via `flow_ctx.request_save(reason)`
- returns a `FlowActionOutcome`; `FlowRuntime.dispatch()` applies the intent
- reached through a per-call factory such as `_sanctum_controller()`

### Services
| Service | Location |
|---|---|
| `VowConsequenceService` | `core/sanctum/` |
| `NarrativeVoiceService` | `core/echoes/` (beside `ShoutBank`) |
| `EmotionConsequenceService` | `core/emotion/` |
| `BondConsequenceService` | `core/sanctum/` |
| `RecruitmentConsequenceService` | `core/sanctum/` |
| `EconomySettlementService` | `core/economy/` (sibling of `EconomyAccrualService`, not an extension) |
| institution tick | added to `InstitutionService` |
| keeper-intro trial helpers | added to `KeeperIntroService` |
| **Phase 5** | |
| `StageExploreSessionService` (527) | `core/realms/` |
| `StageExploreTurnService` (405) | `core/realms/` |
| `SituationEngagementService` (557) | `core/realms/` |
| `ContactResponseService` (62) | `core/realms/` |
| `ContactConversationService` (134) | `core/realms/` |
| **Phase 6** | |
| `CombatRoundEmotionService` (331) | `core/combat/` |
| `CombatRoundSpawnService` (447) | `core/combat/` |
| `CombatRoundGuideSpiritService` (405) | `core/combat/` |
| `LiveHazardOutcomeService` (76) | `core/movement/` |
| `CombatRoundObjectiveService` (378) | `core/combat/` |
| `CombatRoundShrineService` (232) | `core/combat/` |
| `SkillLoadoutService` (126) | `core/progression/` |
| `LiveMovementContextService` (1,018) | `core/movement/` |
| `CombatTurnActionService` (465) | `core/combat/` |
| `CombatTurnContextService` (255) | `core/combat/` |
| `ContributionLedgerService` (219) | `core/combat/` |
| `EncounterSetupService` (840) | `core/combat/` |
| `EncounterObjectiveSpawnService` (650) | `core/combat/` |

**Builders** — `SanctumSnapshotBuilder` (476), `StageExploreSnapshotBuilder` (488),
`ResolveSnapshotBuilder` (225, the 17-block library), `VentureResolveSnapshotBuilder` (171),
`EncounterSnapshotBuilder` (667).

**Helpers relocated to their true owners:** `EncounterContext.find_actor_by_id()` (a data class, not
a service — the first of its kind here); `ConfigService.get_enemy_actor_cfg()` +
`get_enemy_actor_cfg_from_balance()`; ~15 other `ConfigService` static getters.

**Services exist because controllers may not call each other.** A hook invoked from several domains
must be a service. This split has recurred three times: Vow, emotion/bond, keeper intro.

### `FlowActionOutcome` — `core/state/flow/FlowActionOutcome.gd` (136 lines)
`handled`, `transition_to`, `transition_reason`, `replacement_snapshot` +
`has_replacement_snapshot`, `save_reasons`, `error_code`, plus **three** fields added when real call
sites appeared:
- `suppress_refresh` — for `sanctum.rank_up` and `sanctum.calling.confirm`, the only two actions
  that never refresh
- `requires_reenter` + `reenter_outcome()` — checked **before** `has_replacement_snapshot`, because
  `reenter()` assigns the snapshot itself. Five call sites.
- `requires_refresh` + `refresh_outcome()` (added 5D) — two paths call a BARE
  `flow_machine.refresh_snapshot()` with no preceding assignment: `stage.advance_turn`'s
  not-exploring guard and `directive.select` off the STAGE branch. `snapshot_outcome()` always
  assigns; `handled_outcome()` would have silently DROPPED the refresh.

### Snapshot ownership
`SanctumSnapshotBuilder` is pure. `FlowStateMachine._rebuild_snapshot()` went from 166 lines to 39
and is fully generic — no gameplay branch remains. One-shot flags (`pending_awakening_banner`,
`pending_return_notification`) are cleared in the dispatch closure **after** publication, gated to
`flow.sanctum` snapshots.

---

## 4. Decisions taken with Jeff

Record these; several contradict the original draft plan.

1. One story, one branch, one PR. Half A then Half B, uninterrupted.
2. `realm.prologue` is the fixed opening Realm — internal, unnamed, one real Stage, excluded from
   normal Realm ordering and difficulty counts.
3. One-shot snapshot data is consumed in the dispatch transaction closure, after publication.
4. **Resolve becomes a real state**, built from one durable result by one builder.
5. **No Ase grant is added.** The player leaves the intro with exactly 40 Ase and cannot yet summon.
   Economy and balancing are out of scope.
6. The Flame flip moves to the awakening beat. The unreachable `awakening_ase_grant` key goes to
   **V2-ECONOMY-002**.
7. The awakening modal is wired with new copy: *"The house wakes. Ase gathers while you keep it."*
8. Reward split — base objective weight + virtue bonus pay **once per stage**; enemies-defeated,
   echoes-survived and speed bonuses stay per encounter.
9. `xp_stage_clear_base` follows the same rule. Per-kill Storyweight unchanged.
10. **Defeat consolation stays per-encounter** — it never reaches settlement, so routing it there
    would overload settlement with a non-completing case.
11. All four outcomes (victory, defeat, partial, withdrawal) write the durable result; Continue
    routes back to Resolve when one is pending.
12. Run-outcome emotion routes off the outcome and applies once. **Withdrawal is a credit**
    (morale ×1.25), not a penalty — today it is silently overwritten by defeat's fear ×0.5.
13. The existing first Weave **is** spine step 5 — the GDD's "second simple rite". No new content.
14. The opening Realm unlocks from awakening + first Weave, **not** from the second Echo. GDD §20.7
    ordering is temporarily unenforced pending V2-ECONOMY-002 — record this divergence.
15. The `EncounterStateMachine` phase sub-machine is **superseded**, not deferred. No COMBAT story
    claims it. Removal filed against V2-COMBAT-004; **not removed here.**
16. The missing `save_request` in the economy settle handler is a Phase 2 transaction defect, in
    scope. It changes one dispatch from 0 flushes to 1 — an approved exception.
17. The game is not live. Jeff is the only tester. Save-breaking changes are negotiable — say so
    first and he will make a new save.
18. **`ResolveSnapshotBuilder` uses a COMPOSITION model** — a base payload plus optional blocks each
    producer opts into. Jeff chose this over one fixed shape (2026-08-16), so that each encounter
    type can present a different resolve screen, and a later story can add or remove a screen
    section without touching the other producers.
    - There are **six** producers, not five. The plan missed the fallback scaffold in
      `FlowResolveState.enter()`, which uses a third key vocabulary.
    - The payloads are irregular, so some blocks must be partial. Measured example: `ase_awarded` is
      set by combat, keeper, scout and situation but not contact; `ekwan_awarded` is set by combat,
      scout and situation but **not** keeper. A single "rewards" block cannot serve all six.
    - Hard constraint: the model reproduces all six payloads exactly.
    - **ANSWERED: key absence is NOT load-bearing.** `ui/screens/venture/ResolveScreen.gd` uses
      `data.get(key, default)` everywhere — zero `data.has(...)` calls. Sections show/hide on VALUE
      (`ekwan_awarded > 0`, `vow_outcome.is_empty()`). Two defaults do real work: absent `rank`
      renders `"F"`, and **`run_type` selects which of four renderers runs** — writing it as `""` is
      safe, writing a wrong default like `"combat"` silently breaks producers A, B and F.
    - Producers C/D/E/F are in scope for Phase 5. A (combat) and B (Keeper trial) live in
      `FlowEncounterState.gd` and migrate in Phase 6.
    - Block specification: `docs/resolve-snapshot-block-spec.md`.

---

## 5. Way of working

**The orchestrator does not write product code.** Not features, not tests, not config values — not
even a two-line fix. Route everything to an agent. The only inline work is verification runs, tree
audits, docs, memory, lessons and the plan file.

**Never trust an agent report.** Verify every claim from a cold start yourself. This caught:
- a completed agent reporting "1409 passed, 0 failed" when a clean run gave 1402 passed, 7 failed
- a duplicated helper that had to be relocated
- a substituted API that introduced a mutation into a read path
- a fingerprint constant that never described the real payload

**Ask agents to verify your lists.** Five briefs of mine contained errors. Agents caught all five,
because the brief told them to check before acting.

**After any agent stops — killed or completed — audit the tree read-only before re-dispatching.**
Nine agents were stopped by usage limits. Every audit found either a clean tree or usable partial
work, because every brief says to save incrementally.

**Slices are one domain each and run serially**, since they all edit `FlowRuntime.gd`. Parallel
agents are only safe on genuinely disjoint file sets, and the brief must name the files the other
agent holds.

---

## 6. The agent brief pattern that works

1. Point at `AGENTS.md` first — it now carries the run commands, extraction rules and 20 common
   mistakes. Do not restate them.
2. Give the **exact run command block**, with the cache rebuild as line one and `timeout: 300000`.
3. Name the pattern file to read first (most recent controller or service).
4. State the baseline test count.
5. List what moves — and say "verify this list against the file first; report corrections".
6. List the behaviours that must survive **and why they exist**. Bare "preserve X" gets lost; "X is
   the guard that stops Y" survives.
7. State the hard rule: no duplicating, no substituting a lookalike API, no clean owner means stop
   and report a blocker.
8. Require: compile clean, filtered suite while working, full suite once at the end, no fingerprint
   drift.
9. Deliverable must include the `Tests:` line verbatim and `git diff --stat`.

Order tasks inside a brief by value, and say "finish and verify part A before starting part B", so a
session-limit kill leaves the most valuable work intact.

---

## 7. Environment traps — all cost real time

| Trap | Symptom | Fix |
|---|---|---|
| Bash auto-backgrounds at 120s; suite takes 173s | Agent parks forever, work lost | Pass `timeout: 300000` |
| Stale script class cache | Batch of fingerprint tests "fail" with drifted hashes | `--headless --import` **first**, every time |
| `--path` points at the main checkout | Verifies the wrong branch | Always pass the worktree path |
| Runner always exits 0 | False green | Only the `Tests: N total…` line is evidence |
| `flow.new_game` uses `Crypto.generate_random_bytes()` | Non-deterministic tests | Drive onboarding from `boot()` (pinned seed 12346) |

Five agents in a row skipped the cache warning. The fix was to move the rebuild into the copy-paste
command block, not to warn harder.

**Test filtering now exists**: `-- tests <filter>` runs one suite in ~5s instead of 173s.
Substring match on suite name. An unmatched filter lists the suites and runs nothing.

---

## 8. Defects found (status)

**Fixed in this story**
- Weave lock returned before the save flush — a queued save could be stranded indefinitely
- `_handle_economy_settle_time` mutated save data and requested no flush
- 84 `save_request` sites unified; ~24 clobbered the reason instead of appending
- Duplicate `refresh_snapshot()` in `ui.dismiss_summon_reveals`
- Sanctum enrichment and one-shot consumption inside `FlowStateMachine`
- `_project_actor` mutated the actor it was projecting
- `ensure_layout` wrote save data with no save-request seam
- `Array[Vector2i]` in the Sanctum payload (not JSON-safe)
- Splash/MainMenu Array actions; `FlowVowState` `meta.sim_tick`; boot error snapshot shape
- ~60 lines of provably dead legacy save migrations

**Found, deliberately left for Half B / other stories**
- Stage completion without an encounter pays **nothing**, is flavoured as a loss, and writes a
  `broken` Thread segment (grade falls back to `"F"`)
- `_get_stage_base_reward()` reads `objectives[0]` only → double pay on multi-objective stages
- Quit-at-Resolve keeps the reward but never advances the stage → replayable for full reward
- `RealmService.advance_stage()`'s idempotency guard **causes** Thread double-minting: it returns a
  model whose `is_completed` flag is the caller's crystallize trigger
- A successful withdrawal is scored as a defeat (`_apply_run_emotion_modifiers`)
- `STATE_ESCAPED` is written and never read
- 48 of 73 actions have no test coverage

---

## 9. What remains

**Phase 5 — venture + contact.** Re-scoped 2026-08-16 after a measured recon pass. Six slices:

| Slice | Builds |
|---|---|
| 5.0 | Characterization tests — entry gate, `tests/` only |
| 5A | `StageExploreSessionService` + `StageExploreSnapshotBuilder` |
| 5B | `ResolveSnapshotBuilder` (composition model — decision 18) |
| 5C | `ContactController` |
| 5D | `VentureController` |
| gate | Orchestrator cold full-suite run |

**Why 5.0 exists.** These handlers have ZERO dispatch coverage and are exactly what moves next:
`flow.complete_stage` (119 lines), `encounter.retreat` (67), `stage.confirm_return_home`,
`stage.dismiss_overlay`, and `_build_scout_return_snapshot` (60, untested on both call sites). That
is ~250 lines of reward-paying, save-writing logic with no guard. Same entry-gate pattern Phase 3
used.

**Corrections the recon made to this plan** — all measured, with file:line evidence:
- `_build_scout_return_snapshot` has a **second** impurity beyond the known `SanctumService.new(...)`
  case: it zeroes `flow_ctx.pending_scout_return_ase` and `pending_scout_return_intel_count`
  (`FlowRuntime.gd:4352-4353`), so it consumes its own input and a second call returns different
  data. Consumption moves to the dispatch closure, as `pending_awakening_banner` did in Phase 3.
- Its `meta` carries **`sim_tick`, not `t`** — a live snapshot-contract violation no test catches.
- ~~`_apply_victory_return_to_explore` and `_resolve_combat_situation_and_objective` drifted on
  `revealed`~~ — **THIS WAS WRONG.** Both set `revealed = true`. Corrected during slice 5A. The pair
  did drift, but on **four other axes**, now explicit parameters on
  `StageExploreSessionService.resolve_combat_situation_and_objective()`:
  `skip_if_already_resolved`, `commit_only_when_modified` (covers two axes), `log_type` /
  `log_message` / `log_objective_index`.
  Also: `_apply_victory_return_to_explore` **cannot** move to a service — it reads
  `flow_machine._current_state_id`, and a service may not hold `flow_machine`. Only the
  situation-resolution body moved; the function stays on `FlowRuntime` as a combat-teardown
  orchestrator. `tests/Stage004SeamTests.gd:1133` therefore correctly still calls it — that is not
  the shim anti-pattern, because the function still does real un-extracted work.
- **114 lines are dead** (no callers in `core/`, `ui/`, `tests/`): `_find_target_situation`
  (`:6348-6433`) and `_mark_situation_revealed` (`:6656-6683`). Delete, do not move.
- `stage.dismiss_overlay` is **not** runtime-generic — its body rebuilds a stage-explore snapshot, so
  it goes to `VentureController`. Still exactly one owner.
- A `VentureController` built as planned lands near 1,000 lines (879 before helpers), so the heavy
  explore-turn logic delegates to `StageExploreSessionService`.
- `FlowStageExploreState.build_snapshot` (452 lines) is **already pure** — a clean verbatim move.
- Rewrite the reflection call sites in `tests/Stage004SeamTests.gd:353/398/431/1133` in the same
  change; they reach into `_apply_contact_outcome` and `_apply_victory_return_to_explore` by name.

**Phase 6 — encounter + combat.** Highest risk. `_end_round` is ~1,075 lines with a 7-collaborator
split proposed; `FlowEncounterState.enter()` is 991 lines and breaches the ~1,000-line guard alone.
Guarded by the seven mode fingerprints. Move the 26 movement helpers **verbatim** — COMBAT-003 owns
that behaviour.

**Phase 7** — thin shell, then the highest-tier Half A architecture review gate.

**Phase 8 — Half B.** `flow.pending_result` and per-stage `settlement_receipt` already exist in the
schema with defaults, repair and 6 tests. Still to build: `StageSettlementService`,
`EncounterResolutionService` (a **service**, since the five call paths span three controllers),
`PrologueRealmService`, and the opening-gate wiring.

**Phases 9–11** — regression, Jeff's manual first-session pass, docs + Notion + commit + PR.

---

## 9b. Phase 5 progress

### Slice 5.0 — characterization + harness repair ✅
`tests/VentureCharacterizationTests.gd` (16 tests) pins `flow.complete_stage`, `encounter.retreat`,
`_build_scout_return_snapshot` on both call sites, `stage.confirm_return_home`,
`stage.dismiss_overlay`, and the contact resolve shape — all previously at ZERO coverage.

**A harness defect was found and fixed, and it matters more than the tests.** `_fresh_save_path()`
deleted only the primary save file. `SaveService` writes six artifacts beside it and returns
`LOAD_MISSING` only when *none* exists, so a leftover `.bak1` made `boot()` recover a backup instead
of calling `make_new_save(<pinned seed>)` — every run silently **resumed the previous run's
campaign**. This produced 9 fingerprint failures that survived a full `.godot` delete and a clean
checkout, and looked exactly like a Phase 4 regression. It was not one; every pinned constant was
correct. See `AGENTS.md` "Save isolation" and mistakes 21-23.

New: `tests/TestSaveHarness.gd`, adopted by 22 suites. Derives its suffix list from
`SaveService._artifact_paths()` rather than copying it; scopes the save dir per process id so
concurrent runs cannot collide. Found a seventh artifact the analysis missed: `.corrupt`.

All four failing characterization expectations were **wrong expectations, not defects**:
`nav.skills` has never existed in the codebase; `_next_tick()` returns the pre-increment value so
the test read the tick one dispatch too late; and the contact card genuinely does write `verdict`.

### Slice 5A — stage-explore service + builder ✅
`FlowRuntime.gd` **6,704 → 6,213**. `FlowStageExploreState.gd` **1,346 → 894**.

| New file | Lines |
|---|---|
| `core/realms/StageExploreSessionService.gd` (renamed `ActiveStageService.gd`, correction C4) | 506 |
| `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` | 488 |

The service went to `core/realms/`, not under `states/venture/` — `states/` holds flow states, and
every domain class it touches (`StageExploreModel`, `StageTerrain`, `SituationModel`,
`ObjectiveModel`) lives in `core/realms/`. The builder DID go to `states/venture/`, matching
`SanctumSnapshotBuilder`.

Three config readers moved to `ConfigService`: `get_situation_category_cfg`, `get_movement_slack_cfg`,
`get_rewards_cfg`. ~135 lines of dead code and pointless wrappers deleted. No delegating shim was
left behind — `FlowStageExploreState` no longer declares `build_snapshot` at all, and all 28 call
sites were repointed.

**Defects found, NOT fixed** (now visible instead of buried in a duplicated block):
1. The victory-return path has no already-resolved guard, so `objectives_found` can be
   double-incremented.
2. That path commits unconditionally — an unmatched `last_situation_id` still writes the stage back,
   requests a save, and logs a resolution for a situation it never touched.
3. `ConfigService.get_rewards_cfg` has no `config_service == null` guard, unlike its two siblings.
   Transcribed as-is; adding the guard would be a behaviour change.

---

### Slice 5B — ResolveSnapshotBuilder, composition model ✅
`core/state/flow/states/venture/ResolveSnapshotBuilder.gd`, 225 lines, base + **17 blocks**.
Producers C (scout return), D (contact), E (situation) and F (fallback) migrated. A (combat) and
B (Keeper trial) stay in `FlowEncounterState.gd` for Phase 6.

`FlowRuntime.gd` 6,213 → **6,245 (+32)**. This slice does not shrink the file; purity was the goal.
Suite 1,458 → **1,460**.

**The builder takes NO `FlowContext`.** Every input is a plain value the producer computes first.
That is a stronger guarantee than `SanctumSnapshotBuilder`, which reads `flow_ctx`.

**Jeff's decisions, 2026-08-16:**
- **Q1 APPROVED — producer C emits `meta: { "t": t }`, not `sim_tick`.** It violated
  `FlowStateMachine._validate_snapshot()`, which calls `assert(false)` when `t` is absent — so every
  successful retreat and return-home tripped an assertion in a debug build. Nothing reads the key.
- **Q5 APPROVED — 17 blocks**, no opt-out flags. Five are single-key; three map to no screen section.
- Q3 — `title` / `note` are dead keys but STAY. Deleting them drifts producer A's seven fingerprint
  constants, which is cheap in Phase 6 and gratuitous now.
- **NOT approved** — `flow.resolve` cases in `SnapshotContractTests`. Recorded as a coverage gap.

**One-shot consumption** moved to the dispatch closure, gated on `type == flow.resolve` **AND**
`data.run_type == "scout_return"`. The second condition is load-bearing: five other producers emit
`flow.resolve`, and a combat resolve must never zero an award the player has not been shown.

**Correction the agent made to the spec:** the spec claimed no test covered the `sim_tick` defect.
`tests/VentureCharacterizationTests.gd` did — it failed the moment the approved fix landed. Three
such tests were inverted rather than deleted, per `AGENTS.md`. **Check that suite before touching
producers A or B in Phase 6.**

**Coverage gaps, all now recorded:**
- `SnapshotContractTests` has no `flow.resolve` case — a future producer can reintroduce the defect
- **producer F has no test anywhere in the repo** — the weakest point of the slice
- nothing asserts that producer B *omits* `ekwan_awarded`, which is the most fragile fact in the
  spec and the entire reason `ekwan` is block #8 rather than a flag on `ledger`

---

### Slice 5C — ContactController ✅
`FlowRuntime.gd` 6,245 → **5,601 (−644)**. Suite stayed at 1,460, all passing.

| New file | Lines |
|---|---|
| `core/runtime/controllers/ContactController.gd` | 800 |
| `core/realms/ContactResponseService.gd` | 62 |

Five of six functions moved. Every `flow_machine` use translated into a `FlowActionOutcome` — the
controller's header carries that translation table and is the best reference for slice 5D.

**Two RESOLVE exits use `suppress_refresh`, and must.** Before extraction they assigned
`last_snapshot` and transitioned with NO refresh in between. Plain `snapshot_outcome()` would have
added a refresh call that never previously ran.

**`_start_contact_conversation` could NOT move** — two independent blockers. Its only caller is
`_handle_stage_engage_situation`, an action `ContactController` does not own, so moving it would make
`FlowRuntime` call a controller method as a bare subroutine. And it ends with
`flow_machine.refresh_snapshot()` while its caller returns without applying any outcome, so there is
no `FlowActionOutcome` in flight to carry the intent. It also cannot be a service, because services
hold no `flow_machine`. **This is slice 5D's problem** — `VentureController` may not call
`ContactController`, so the route needs a contact SERVICE.

`ContactResponseService` went to `core/realms/` because `ConversationService`, the consumer of its
parsed shape, lives there. Its cache became a `static var` — safe, because the source is a read-only
`res://` file with no writer.

**Corrections the agent made to my facts:**
- I said slice 5B moved `_contact_outcome_text` and `_build_contact_resolve_snapshot` to
  `ResolveSnapshotBuilder`. **It did not.** 5B rewrote the *body* of the latter to compose through
  the builder's blocks; both functions stayed on `FlowRuntime`. They moved in 5C, with
  `_apply_contact_outcome`, their only caller.
- **Six** tests reached in by name, not three. `tests/VentureCharacterizationTests.gd:1101/1173/1174`
  also called `_build_contact_resolve_snapshot`. All six repointed; no stub left behind.
- The test filter `stage004` matches nothing — `Stage004SeamTests` registers as `seam`. An unmatched
  filter runs zero tests, prints no `Tests:` line, and exits 0, so it reads as a pass. Now
  `AGENTS.md` mistake 24.

---

### Slice 5D — VentureController ✅ (Phase 5 complete)
`FlowRuntime.gd` 5,601 → **4,435 (−1,166)**. Suite stayed at 1,460, all passing.

| File | Lines |
|---|---|
| `core/runtime/controllers/VentureController.gd` | 566 (budget was 700) |
| `core/realms/ContactConversationService.gd` | 134 |
| `core/realms/StageExploreSessionService.gd` (renamed `ActiveStageService.gd`, correction C4) | 506 → **1,461** ⚠️ |
| `core/state/flow/FlowActionOutcome.gd` | 117 → 136 |

**`StageExploreSessionService` reached 1,461 lines here — RESOLVED in slice 5E below.**

**`FlowActionOutcome` gained a fourth field: `requires_refresh` / `refresh_outcome()`.** Two paths
call a BARE `flow_machine.refresh_snapshot()` with no preceding assignment — `stage.advance_turn`'s
not-exploring guard, and `directive.select` when the live snapshot is not `flow.stage`.
`snapshot_outcome()` always assigns; `handled_outcome()` would have silently DROPPED the refresh.
Same additive precedent as `suppress_refresh` and `requires_reenter`.

**`flow.select_stage` could not move in 5D** — its body called
`_progression_controller().persist_equipped_skills(t)`, and a controller may never call another
controller. ✅ **RESOLVED in slice 6F**: the method moved to `core/progression/SkillLoadoutService.gd`
and the action now lives on `VentureController`. No action has a provisional owner any more.

**The contact seam resolved, and it corrected slice 5C.** `ContactController`'s header claims
`_start_contact_conversation` can never be a service because services hold no `flow_machine`. That is
wrong. Its only `flow_machine` work was the trailing publish, which the controller now returns as an
outcome. With the publish lifted out, the body needs no `flow_machine` and moved wholesale into
`ContactConversationService`. `VentureController` never touches `ContactController`.

**Actions still inline in `dispatch()` after Phase 5:** `flow.new_game`, `flow.advance`,
`flow.go_state`, `flow.continue`, `flow.settings`, `flow.quit`,
and the six Phase 6 combat/encounter actions. All 73 still have exactly one owner.

**Corrections the agent made:** `stage_explore` and `stage_objective` are NOT valid test filters —
both matched nothing and exited 0. Real names: `explore`, `explore_p5`, `objective`,
`objective_combat`, `stage`. Also `stage.dismiss_overlay` has a third state I did not know about:
with no active stage the pre-extraction body did nothing at all, not even a refresh.

---

### Slice 5E — split the oversized session service ✅
Run BEFORE Phase 6, not deferred to the Phase 7 gate. The deciding fact: **Phase 6 calls into this
file**, so its agents must read it. Splitting a file that breaches the size guard is cheap and
mechanical; making the highest-risk phase work against it is not.

| File | Lines |
|---|---:|
| `core/realms/StageExploreSessionService.gd` | 1,461 → **527** |
| `core/realms/StageExploreTurnService.gd` | new, 405 |
| `core/realms/SituationEngagementService.gd` | new, 557 |
| `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd` | new, 171 |

Suite unchanged at 1,460. No file in the new set exceeds 557 lines.

**The agent proposed 4 files, not the 3 I sketched, and was right.** My group 3 would have landed at
~810 lines — above the target the slice existed to hit. It cut `advance_turn` (movement, fog, turn
body) away from `engage_situation` + `resolve_situation_choice` (the situation bodies), because those
two share the `"stage.resolution.%s"` RNG namespace, the same `emotion_summary`/`effects` payload and
the same `"resolved"` verdict shape. Cutting between them would have cut through a shared contract.

**`build_scout_return_snapshot` KEPT its `FlowContext` parameter, and my preferred fix was wrong.**
I proposed hoisting the context reads out so it could compose as a pure producer. The agent rejected
that on merit: `tests/VentureCharacterizationTests.gd` calls it twice with the same `FlowContext` and
asserts byte-identical payloads — which is exactly what proves it no longer consumes the two one-shot
`pending_scout_return_*` fields (the defect slice 5B fixed). Passing pre-read plain ints would make
that assertion prove nothing. **The hoist would have weakened an existing guard.** The purity contract
is untouched because the destination is a sibling builder, not `ResolveSnapshotBuilder` itself —
which is the block library, and whose header already locates all six producers outside itself.

**Correction for Phase 6:** `_handle_encounter_retreat` no longer calls `StageExploreSessionService`
— it calls `VentureResolveSnapshotBuilder.build_scout_return_snapshot()`. Only the
`_end_round` → `_apply_victory_return_to_explore` → `resolve_combat_situation_and_objective` path
still reaches the session service. `FlowRuntime`'s Phase 6 comment map records this.

Two private factories I omitted from the brief (`_voice_service`, `_contact_conversation_service`)
moved with their single callers. Working from my table alone would have stranded them.

---

## 9c. Phase 6 — encounter + combat

### Recon findings that reshape the phase
- `_resolve_next_actor` = `FlowRuntime.gd:2132-2699` (568 lines); `_end_round` = `:2700-3779` (1,080).
- **Neither can become a controller.** Two independent blockers: `_resolve_next_actor:2613`
  transitions to the keeper rewind then returns bare (no outcome in flight — same class as
  `_apply_victory_return_to_explore`), and `:2657` calls
  `_progression_controller().get_realm_xp_multiplier()`, which is controller-to-controller.
  ✅ **The second blocker is GONE** — slice 6F moved that method to a static on `ProgressionService`.
  The first remains, and slice 6F found **two more**, listed under "Slice 6F" below.
- **`_end_round` has FIVE real seams, not seven.** One (the GUIDE_SPIRIT mover, 231 lines) is
  V2-COMBAT-003 boundary and must move verbatim.
- **The movement set is 28 functions, not 26 or 25** — 20 `_movement_*` plus 8 others, including
  three `_apply_live_*` that must travel with them or `_prepare_legacy_move_intent_for_activation`
  is stranded. Nothing in `FlowRuntime.gd:1146-2131` would need to change.
- **Producers A and B are byte-for-byte what the block spec measured** — 24 and 16 keys, zero
  differences. Spec §5 holds: Phase 6 needs NO edit to `ResolveSnapshotBuilder.gd`.
- **Payment CAN move out of `build_final_snapshot`.** The payload reads `reward_result` and
  `xp_events` — the RETURN VALUES — never `save_data`. But the ally-death knock at `:1656/:1660` is
  a genuine read-after-write: three later consumers read those `fear`/`morale` fields. It must run
  BEFORE the pure builder, as a mutation.
- **The purity probe `snapshot_purity/build_final_snapshot_pays_rewards` would go silently vacuous.**
  It drives the whole dispatch and asserts save data changed. Move payment to `_end_round` — same
  dispatch — and it still passes while proving nothing. Inverting it needs a rewritten body scoped to
  a direct `build_final_snapshot()` call, not a flipped boolean.

**My facts the recon corrected:** the theft site does NOT discard its derived seed (it is an
if/else, hash only on the null branch); `_end_round` contains none of damage, death, ledger or
payment — those are in `_resolve_next_actor` and the builder.

### Slice 6.0 — combat baseline ✅
`tests/CombatBaselineTests.gd`, 740 lines, **18 tests**. Suite 1,460 → **1,478**. Test-only diff plus
one registration line.

Closes the measured fingerprint gaps: `fear`/`morale`/`_witness_fear_taken`/`_no_damage_streak` per
actor per round across all seven modes (the 231-line emotion block had NO fingerprint cover and is
the first thing that moves); transition sequences; per-dispatch save flush counts and reasons; the
tick-bound retreat roll; and the two dormant actions no test had ever dispatched.

An empty baseline constant FAILS rather than passing, and a non-triviality test proves the hashed
values actually move — so the guard cannot degrade into pinning a frozen board.

**Defects pinned, not fixed:**
- `FlowRuntime.gd:1017` — the retreat fallback builds `...encounter_id + str(t)` with **no dot**, a
  different seed namespace from the primary path one line above. Pinned as unreachable in play.
- The retreat roll is genuinely tick-bound: same encounter, same 50% — ticks 7 and 8 succeed, 9 and
  10 fail. **Any Phase 6 change to the dispatch count re-rolls every retreat in the game.**
- **The flow machine never transitions to RESOLVE at end of combat** — `_end_round` writes
  `flow_ctx.last_snapshot` directly. Previously documented in prose; now pinned.
- `encounter.advance` has no phase guard; `encounter.complete` transitions to RESOLVE from whatever
  state it is in.
- Harness note: `_mark_save_requested()` joins reasons with `|`, so a save queued OUTSIDE a dispatch
  glues its reason onto the next one. A controller that queues a save outside a dispatch boundary
  would silently corrupt the reason string.

**Permanent gap, stated plainly:** the movement decision (`goal_id` / `option_id`) is a private local
in `_resolve_next_actor`, never stored and never logged. A refactor that reaches the right cell for
the wrong reason passes silently. Closing it needs a production change and belongs to its own story.

### `_end_round` decomposition — the running number

| After slice | `_end_round` | `FlowRuntime.gd` |
|---|---:|---:|
| start | 1,080 | 4,453 |
| 6A emotion | 854 | 4,228 |
| 6B spawn | 535 | 3,918 |
| 6C guide spirit | 326 | 3,682 |
| 6D objective counters | 196 | 3,561 |
| 6E shrine drain + comment trim | **139** (70 code) | **3,512** |

**`_end_round` is FINISHED.** Every remaining block is either the runtime's own snapshot-and-refresh
duty (structurally barred from a service — it needs `flow_machine`), the end-condition decision that
produces the `combat_result` those snapshots read, or five lines of local bookkeeping. There is no
further phase to extract. Do not chase it lower.

### Slice 6A — CombatRoundEmotionService ✅
`core/combat/CombatRoundEmotionService.gd`, 331 lines. The seven emotion terms (234 lines, not the
231 I stated).

**The seam was NOT self-contained, and my brief repeated the recon's omission.** It also appends to
`ectx.round_bark_events` via the bark call and requires `FlowContext` to build the voice service.
From here every slice verifies its own seam before extracting — the recon's "self-contained" labels
are hypotheses, not facts.

`_find_actor_by_id` had no owner (10 call sites). It went to **`EncounterContext`**, the class that
owns the `actors` array every caller passes — the first time a shared helper in this story resolved
to a data class rather than a service. Body byte-identical, including the first-match quirk an
integration suite pins. `EncounterContext` had zero methods before this.

**Rejected `EmotionConsequenceService` as the home, correctly:** that service routes every write
through `EmotionService` and touches `save_data` in every method; this block is the documented
mid-combat direct-write exception and touches no save data. Merging would have broken an invariant
that file documents about itself.

Defects recorded: a parameter named `round` shadows the built-in `round()` (safe today, term D calls
the built-in inside that scope); `_ally_killed_barked` is an ad-hoc string key where its sibling is a
typed field; a KO can be visited twice in one loop so fear spread may double-apply.

### Slice 6B — CombatRoundSpawnService ✅
`core/combat/CombatRoundSpawnService.gd`, 447 lines. RECOVER reinforcement + ENDURE waves.

**My blocking prerequisite named the WRONG helper.** `_merge_actor_cfg` / `_get_actor_cfg_merged`
have one production caller and are unrelated to spawning. The genuinely shared helper was the
`{birth_stats, enemy_types}` assembly, written longhand at **four** sites — two of them inside the
code being moved, so a naive extraction would have produced a fifth copy in a new file. Now one
owner: `ConfigService.get_enemy_actor_cfg()` / `get_enemy_actor_cfg_from_balance()`.

**The fingerprints are two keys short of this seam.** These phases write seven `combat_state` keys;
`FlowFingerprintTests` pins five. `initiative_order` and `total_waves` are outside fingerprint cover
— guarded only by `combat_baseline` and `objective_combat`. Relying on the fingerprints alone as
"the guard for exactly what moves" would have been wrong.

Defects recorded: **placement silently drops actors** — when cells run out, position assignment
stops but the already-built actors are appended anyway and land at the default `{0,0}`, on the echo
side, possibly overlapping a living actor (reachable only on a nearly-full board); `total_waves` is
frozen on the first ENDURE round; ~60 lines of the two placement bodies are character-for-character
duplicates including a determinism-critical sort — now confined to one file, which is the
precondition for fixing it.

### Slice 6C — CombatRoundGuideSpiritService ✅
`core/combat/CombatRoundGuideSpiritService.gd` (405) + `core/movement/LiveHazardOutcomeService.gd`
(76). Moved verbatim — V2-COMBAT-003 owns this behaviour.

**I predicted the coupling would be barks. Barks were there, but the real blocker was different:**
the block mutates the spirit's HP and death state through `_apply_live_hazard_outcome`, a second
private shared with the main combat path. That forced the second file — the write half of
`CombatActivationService`'s read-only contract, deliberately not folded into `MovementHazardService`,
whose header guarantees it never touches actor state. Nine call sites repointed, including seven
reflection-based ones in `CombatRoundtripIntegrationTests`.

**`_prepare_guide_spirit_activation_context` did NOT move** — it depends transitively on eight more
`_movement_*` privates, all shared with the main activation path and several reached by name from
`tools/PursueTimingProbe.gd`, `BehaviorArbiter.gd` and three suites. ~250 lines, its own extraction.
The context is passed in, and the gate lives on the service as `static needs_activation_context()`,
so preparation stays exactly as lazy as before — no mode newly pays the full-grid flood fill that
caused the PURSUE freeze. The agent verified the hoist behaviour-neutral rather than assuming it.

Defects recorded: `death_round` is set to the sim tick, not the round counter, so hazard deaths
record a meaningless round; `_gs_spirit_pos` goes stale in the protect branch; an unrecognised
`guide_mode` silently does nothing; the escort win latch can fire on a spirit that never moved.

### Slice 6D — CombatRoundObjectiveService ✅
`core/combat/CombatRoundObjectiveService.gd`, 327 lines. PROTECT theft, PROTECT proximity, PURSUE
contain. `_end_round` 326 → 196.

**The agent rejected my framing and was right.** I asked whether these counters should join
`CombatRoundSpawnService`, which already owns the RECOVER hold counter. No: these services decompose
`_end_round` **by phase, and for objective work that means by resolution mode, not by mechanism**.
Spawn owns RECOVER+ENDURE, guide-spirit owns GUIDE_SPIRIT, this owns PROTECT+PURSUE. The hold counter
lives with spawn because it is a sub-step of the RECOVER phase in fixed order — not because that file
claims counters as a remit. It also declined my offer to move the hold counter out: that would split
one mode's fixed-order phase across two files to fix a name rather than a behaviour.

**My "splits one mechanism" worry was wrong** — the adjacency-counter shape is hand-written FOUR
times across three files and they genuinely differ (simple adjacency vs configurable radius; one
never resets). Nothing was split; this consolidated two of the four for the first time. Extracting a
shared helper would be behaviour-adjacent, not extraction — reported, not attempted.

**First self-contained seam in Phase 6.** No barks, no save, no second shared private, no
fingerprint-uncovered key.

Defects: `_double_damage_mult` is written on theft but **never cleared on recovery**, unlike its
partner flag — a former carrier keeps a stale multiplier all encounter, inert only because consumers
check the other flag first. `_carrier_double_damage` is cleared only when the carrier dict is still
findable. `data.combat.objective_modes` has no `ConfigService` owner (read longhand at four sites) —
deliberately NOT fixed here, because these reads were moved, not copied; the site count is unchanged.

### Slice 6E — CombatRoundShrineService ✅ (last `_end_round` phase)
`core/combat/CombatRoundShrineService.gd`, 232 lines. `_end_round` 196 → 157 → **139** after a
separate comment trim.

**The seam returns a value — the first one that does.** `shrine_hp_val` is consumed twice downstream
(`combat_result["shrine_hp"]` and the `combat.end` log). Re-derivation was not an option: by the time
the end check runs the shrine may be marked dead, so a second scan would have to re-decide whether to
skip dead structures — a decision the drain phase already made and encoded in the value.

**Placed BESIDE `ShrineService`, not inside it** (which is at `core/combat/`, not `core/realms/` as I
stated). That file's own first rule is *"Pure static functions only — no side effects outside the
passed dicts, no logging."* The drain phase breaks all three clauses. Folding it in would have meant
rewriting that sentence to accommodate a caller. So the new file owns the *phase*; `ShrineService`
keeps the *arithmetic*.

**Comment trim, done as a separate step:** the five call-site blocks held 45 comment lines; 20
removed, 25 kept — the load-bearing phase order, the round-counter/theft-seed determinism hazard, the
`_prepare_guide_spirit_activation_context` constraint, and the NOT-VOID note.

Defects: a sentinel-keyed fallback (`if shrine_hp_val == 0`) cannot tell "no living shrine" from "hp
landed on exactly 0", and its fallback scan does not filter `is_dead`, so after the shrine dies every
later round reports the dead shrine's hp; only the first living structure is drained; the cooldown
decrement and party morale drain are nested inside the shrine loop, so they stop when it dies; the
morale-drain log reports the configured amount, not the applied one.

### Slice 6F — service demotions, and the last provisional owner ✅
`core/progression/SkillLoadoutService.gd` (126, new) + `ProgressionService.get_realm_xp_multiplier()`
(static). Suite unchanged at 1,478.

**`FlowRuntime.gd` GREW, 3,512 → 3,521 (+9).** The executable body shrank — a 15-line inline case
became a one-line route — but the replacement comments cost more than the code saved. Recorded
because a slice that removes code and ends on a higher line count reads as an error in a summary.

**All 73 actions now have exactly one owner, counted rather than asserted:** Venture 11, Onboarding
12, Sanctum 11, Debug 7, Weave 6, Progression 5, Economy/Contact/Vow 3 each, FlowRuntime 12
(deliberately — the six `flow.*` boot/session actions and the six combat/encounter ones). Zero
duplicates. **This closes a stop condition for the story.**

**The earlier decision was not overruled — it had been overtaken.** `ProgressionController`'s header
said `flow.select_stage` "stays on FlowRuntime". That was correct when written: there was no
`VentureController` then, and `FlowRuntime` may call any controller. Slice 5D later found this exact
blocker, named this exact fix, and declined it purely on scope. 6F is that scheduled second
extraction.

**The save-reason hazard was decisive, not decorative.** `persist_equipped_skills` requests a save,
and `_apply_action_outcome()` drains `save_reasons` AFTER the transition. Returning the reason through
the outcome would have moved it behind any reason the transition queues, changing the `|`-joined
string. So the service is called **inline, mid-handler**, reproducing the original sequence exactly.

**Coverage gap found and closed on Jeff's instruction:** `get_realm_xp_multiplier` had NO direct test.
`prog/realm_multiplier_scales_stage_xp` computes the multiplier itself and passes the result in, and
the fingerprints cannot bite because `RealmService._count_started_realms()` runs before the new model
is stored, so every fixture's first realm yields `run_index = 0` → multiplier `1.0`. A wrong
`realm_id` or config subtree was invisible to the whole suite.

**Defect recorded, not fixed:** the multiplier formula is written twice —
`FlowEncounterState.gd:1831-1834` recomputes `1.0 + run_index * rate` inline from a separately
sourced `run_index`. Collapsing them is behaviour-adjacent, not extraction, because the two sources
may differ.

### `_resolve_next_actor` — blocker status after 6F

| Blocker | State |
|---|---|
| Controller-to-controller call | ✅ **gone** (6F) |
| Mid-function `flow_machine.transition(KEEPER_REWIND)` at `:2610` | ❌ remains — fires from inside a per-actor turn, not at a handler exit, so no `FlowActionOutcome` can carry it. The tail `refresh_snapshot` at `:2702` maps cleanly onto `refresh_outcome()`; this one does not. |
| **Ten private `FlowRuntime` helpers** still called from the body | ❌ NEW — each needs a home first (services before controllers): `_apply_kill_momentum`, `_apply_live_purify_shrine`, `_apply_live_activation`, `_credit_support_tally`, `_fold_support_tally`, `_new_contribution_ledger_entry`, `_prepare_live_movement_context`, `_movement_rect_walkable`, `_get_actor_cfg_merged`, `_merge_actor_cfg` |
| **`_actor_cfg_merged_cache`** — a mutable instance member backing `_get_actor_cfg_merged()` | ❌ NEW and important — controllers are constructed **per call**, so a per-call controller would rebuild the merged dict on every actor turn, which is the ~240-rebuilds-per-encounter cost the cache exists to avoid. **The cache needs an owner that outlives a dispatch.** This is a real constraint on the control-flow decision, not a detail. |

---

### Still to do in Phase 6 beyond `_end_round`
- `FlowEncounterState.enter()` — 984 lines, two `request_save` calls, so it cannot become a builder.
  Largest sub-unit is a 415-line objective-actor spawn block.
- `EncounterSnapshotBuilder` — the pure projection functions from `FlowEncounterState`.
- The `_movement_*` family — **28 functions**, moved verbatim (V2-COMBAT-003 owns the behaviour).
- Producers A and B → `ResolveSnapshotBuilder`, plus rewriting the vacuous purity probe.
- ~~Prerequisite: demote `get_realm_xp_multiplier`~~ ✅ done in 6F. A `CombatController` is still blocked — see 6F.

### A process note worth keeping
I have now given a bad test filter in **three** briefs after documenting the trap myself as mistake
24. Cause: writing filters from memory. Fixed at the source — `AGENTS.md` now carries all 90
authoritative suite names plus the command to regenerate them, and the four names that look right
and are wrong (`guide_spirit`→`movement`, `stage_explore`→`explore`, `stage_objective`→`objective`,
`stage004`→`seam`).

### Agreed sequence for the rest of Phase 6
1. ✅ Baseline the unguarded behaviour
2. Extract the bodies to services — required whichever way the control-flow question resolves
3. Measure what is left of the two functions
4. Decide the control-flow restructure **with a real number**, not an estimate

Jeff's steer: the restructure option is not an alternative to body extraction, it CONTAINS it — a
controller cannot hold 1,648 lines. So step 2 is unconditional.

---

### Slice 6G — the movement family, moved without edit ✅
`core/movement/LiveMovementContextService.gd`, 1,018 lines. `FlowRuntime.gd` 3,521 → **2,595**
(−926). Suite unchanged at 1,482.

**The cache was SPLIT, not moved.** `_get_actor_cfg_merged` is backed by a mutable member. The agent
sent the pure merge to `ConfigService.merge_actor_cfg()` and **kept the memo on `FlowRuntime`**.
Its reason for rejecting a `static var`: the correct lifetime is one campaign, a static would be
process-wide with **no invalidation hook at all**, and the runner builds many `FlowRuntime`s in one
process — so two campaigns or two suites would read each other's merged config. A silent
cross-campaign determinism bug. An instance member is the only owner with the right lifetime.

**Five of my facts were wrong:** 28 co-moving functions was **27**; "two `flow_ctx` reads" was
**six**; "three logger calls" was **six**; reflection sites in four files was **two** (the arbiter
and two suites only mention them in comments); three constructor dependencies was **two** — the block
never reads config, so a third would document a relationship that does not exist. It found **30**
reflection call sites where I predicted fewer across more files.

It also removed 14 orphaned preload constants and repaired stale headers in two services that still
described moved code as living on `FlowRuntime`.

### Slice 6H — `_resolve_next_actor` bodies ✅
`_resolve_next_actor` **577 → 129** (−78%). `FlowRuntime.gd` 2,595 → **2,070**.

| New file | Lines |
|---|---:|
| `CombatTurnActionService` | 465 |
| `CombatTurnContextService` | 255 |
| `ContributionLedgerService` | 219 |
| `CombatRoundObjectiveService` (extended) | +51 |

**The agent refused to move one block, correctly.** The `last_actor_action` path stamping has **no
production guard** — the fingerprints compute start and end positions *in the test*, from snapshots
taken around the dispatch, and never read the production field. Unguarded, so it stayed.

**Largest finding: D01/D04, the top-level `max_hp` read.** See the defect register.

**Five more of my facts were wrong:** the function started at `:1200` not `~:2129`; "ten private
helpers" was **eight**; "death handling lives here" is half right (deaths are written by
`CombatService`; the *consequences* live here); and there is **no round-counter increment in this
function** — it only reads, so there was nothing to preserve.

### The residue — what the control-flow decision now costs
`_resolve_next_actor` is 129 lines, 73 of them code:

| Category | Code lines |
|---|---:|
| Controller glue — locals, config, activation, service calls, snapshot emit | ~46 |
| Keeper-rewind blocker | 10 |
| Unguarded stamping block | 13 |
| `_end_round` handoff | 4 |

A controller version lands at **95–110 lines**. The residue is dominated by glue, not logic, so the
restructure is worth **about 10 lines of change, not a rewrite**.

Two constraints came with it: a `CombatController` must take **both** `_resolve_next_actor` and
`_end_round`, because the first calls the second; and the config memo has a lifetime mismatch with
per-call controller construction (~240 rebuilds per encounter), with a clean one-line fix available
on `ConfigService` that is behaviour-adjacent and therefore not taken.

---

### Phase 7 — thin shell + the Half A review gate ✅

Gate verdict: **APPROVED WITH CORRECTIONS (7)**. `docs/v2-infra-003-half-a-review.md`.

Verified clean by the gate, independently: 73 actions with one owner each (a naive extraction
returns 76 rows; three are not cases); no delegating stubs — all 24 factories are real constructors;
no controller calls another; no controller or service holds `flow_machine`, `SaveService` or a
`FlowRuntime` reference in code; one dispatch, one flush site; **`git diff -- data/` empty**; no RNG
namespace or draw-order edit; save schema purely additive.

| # | Correction | Outcome |
|---|---|---|
| C1 | 294 lines of offline accrual never left `FlowRuntime` | → `core/economy/OfflineAccrualService.gd` (349) |
| C2 | `_generate_seed_root_string` stayed while its partner moved | → `CampaignSeed` |
| C3 | Two headers asserted facts slice 5D disproved | corrected, originals kept visible |
| C4 | `StageExploreSessionService` name outlived its behaviour | → **`ActiveStageService`** |
| C5 | 1,018-line file had no written size justification | added |
| C6 | **The no-`CombatController` decision was invisible in code** | ownership block above the six inline arms |
| C7 | `build_final_snapshot` still pays the player | **deferred** — D36/D77, after-Phase-9 bundle |

**C6 was the gate's highest priority, and its argument is the one to remember:** *"A reader of
`dispatch()` sees 67 routed arms and 6 inline ones with nothing distinguishing decision from debt.
A deliberate decision invisible in the code is indistinguishable from unfinished work."*

**The gate corrected the orchestrator's defence of that decision.** "The residue is irreducible" is
overstated — `encounter.retreat`, `combat.init` and `encounter.complete` have no turn-loop coupling
and map onto an outcome today. The honest reason is **cohesion**: three-in-a-controller and
three-inline with the turn loop straddling both is exactly the ambiguous ownership this story exists
to remove. The code comment says that, not the overstated version.

**The agent then rejected two of the orchestrator's own suggestions, with better reasoning.** C1 did
NOT go on `EconomySettlementService` — that file documents "three settlements, three clocks", all on
the online bank timer, and offline accrual runs on a different clock, trigger and cap. C4 rejected the
gate's suggested `StageExploreQueryService`, because three of the twelve methods write.

**New defect D81:** the offline dormant-house gate is evaluated twice and the second is unreachable.
The two are semantically identical but NOT equal in effect — the reachable one leaves the clocks
untouched, the dead one rolls them forward and requests a save. So deleting the *inline* gate as the
obvious duplicate would silently change behaviour.

**Reflection metric corrected in both directions.** The handoff said 3, the gate said 6; both mixed
two categories. Truth: **5 string-name sites → 0** (all were the C1 function), and 19 direct
compile-checked accesses, which break the build rather than a run and were left alone.

Two items left to Jeff: whether the ~1,000-line guard becomes a standing `AGENTS.md` rule, and a
legacy `# COMBAT-004:` comment near the new block that could read as the same thing.

---

## 9d. Phase 11 must also do these

- **Convert `docs/v2-infra-003-defect-register.md` from a worklist into a ledger of completed work.**
  Conversion rules are written at the top of that file. Every one of its entries must end with an
  outcome; deferred items must name the story they were filed against, never "later"; nothing is
  deleted, including the entries that were disproved.
- **Remove the "When you reach the site of a known defect" section from `AGENTS.md`.** It is scoped
  to this story and would otherwise send later agents to a document about finished work.

---

## 9e. Phase 9 — full automated regression ✅

Run at `bf8360e`, tree clean.

| Check | Result |
|---|---|
| Compile | no errors |
| Full suite, cold `/tmp` | **1,494 total, 1,494 passed, 0 failed** |
| Full suite again, WARM `/tmp` | identical — no cross-run contamination |
| Tree | clean, nothing untracked |

### Stop conditions, audited against `main` across the whole story

| Condition | Result |
|---|---|
| Config VALUE changed | **None.** `data/` is +23 lines, **0 removed** — the `realm.prologue` entry only. Not one existing line altered. |
| RNG namespace or draw-order change | **None.** Two seed-path-shaped strings vanish from the diff — `"stage.reveal"` and `"stage.situation.revealed"` — and both were a save reason and a log tag inside `_mark_situation_revealed`, the dead function deleted in Phase 5. The live RNG path `"stage.reveal.%s"` is unchanged at `FlowStageExploreState.gd:708`. |
| A file over ~1,000 CODE lines | **None from this story.** Only `BehaviorArbiter.gd` (1,613 code, **untouched**) and `SaveService.gd` (1,151 code, net −21 lines). |
| Test baseline regressing | No. 1,401 → 1,494, monotonic. |
| Two flushes in one dispatch | Guarded by `flow_transaction`, green. |
| Controller calling a controller | None — verified by the Phase 7 gate across all new files. |

### The story's commits

| Commit | Content |
|---|---|
| `aa8147d` | Half A — decomposition, 160 files |
| `61ffcf8` | D82 — `prologue.first` no longer inflates `run_index` |
| `091bcfd` | 8A — settle stage rewards once per stage; 14 constants re-recorded **with attribution** |
| `0e801f1` | 8B/8C — durable result, real Resolve state, opening proof spine |
| `bf8360e` | `AGENTS.md` — size guard counts code; comment discipline |

### The one re-record in the whole story
14 of 21 fingerprint constants, in `091bcfd`. **Not one ROUNDS hash moved** — no combat behaviour
changed, only where the reward is paid. The proof is quantitative: **−70 Ase in every one of the
seven modes**, identical, where 70 is the stage base (two combat objectives × 30) plus the realm
virtue bonus (10) — both stage cadence. Per-fight bonuses differ per mode and are untouched. The
attribution is written into the test file header, not only into a report.

---

## 10. Known-stale docs to fix in Phase 11

- `CONVENTIONS.md` states debug actions run at `t = -1`. **False** — `dispatch()` computes one tick
  for every action.
- `SaveSchema.make_new_save()` writes `stage_context.active_directive_id = "directive.none"`, which
  the repair immediately rewrites to `directive.seek_signs`. **The V1→V2 directive migration is
  therefore LIVE, not dead.** Fix the schema default first, then the migration can be removed.
- The prompt assigns the reward-type weighting bug to `V2-ECONOMY-004`; Notion shows that story is
  the Ekwan loop. Confirm the true owner before filing.
- `AGENTS.md` has already been updated with this story's findings — run commands, extraction rules,
  and common mistakes 13–20.
