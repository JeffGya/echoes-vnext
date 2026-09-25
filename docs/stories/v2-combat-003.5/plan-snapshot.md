<!--
TEMPORARY COPY, placed here 2026-09-19 for post-compaction continuity.

The real, canonical plan file is:
/Users/jeffreygyamfi/.claude/plans/rippling-conjuring-neumann.md

That file lives outside the repo (Claude Code's plan storage), so it is not guaranteed to
survive a context compaction or be easy to find in a fresh session the way a repo-tracked file
is. This is a point-in-time snapshot of it, kept here as a fallback only — the real plan file may
have moved further along (phases checked off, notes added) since this copy was made. If both
exist, prefer the real plan file for anything it covers; use this copy only if that file is
unreachable. Safe to delete once the story is far enough along that this snapshot is no longer
useful as a fallback (e.g. after Phase 9 / the final PR).
-->

# V2-COMBAT-003.5 — Movement Style, Board Variety, Stalemate Signal, and Cleanup

## Context

`V2-COMBAT-003.5` was created as the parking place for work that fell outside `V2-COMBAT-003`
while that story ran. `V2-COMBAT-003` merged 2026-09-11 as PR #62 (commit `80c31c2`), suite
1,519 → 1,613, and that merge unblocked this story.

The live Notion page (`3d2c3d1e-de92-812c-800f-c8505eeeadc4`, Status: Ready, Order 253.5, P2,
Foundation) carries 13 numbered items filed across two rounds (2026-09-05/06, 2026-09-11). It
does **not** list the combat-board-variety work the original brief described — Jeff confirmed
this is because that work was moved late from `V2-COMBAT-003` and the Notion page was never
updated to reflect it. It is in scope; the page is stale on this one point.

Jeff reviewed the full grouping (Subtask 1) and, rather than trimming the bucket, chose to ship
**everything** — movement style, board variety, board size, the stalemate signal, all doc/debug
fixes, and all nine scattered small defects — as **one story, built in sequential phases, one PR
at the end**. This plan sequences those phases so the story stays reviewable phase-by-phase
despite its width, per `docs/LESSONS.md` #21 ("price the sum, not the item") and the brief's own
"final size rule."

**Baseline, confirmed this session:**
- Full suite: `1629 total, 1629 passed, 0 failed` (up from 1,613 at the COMBAT-003 merge; the
  +16 delta is unexplained and not traced — worth a one-line check before Phase 1 starts, not a
  blocker).
- `grep -rn "movement_style" --include=*.gd .` → **0 hits**, confirmed.
- `BehaviorArbiter.gd`: 2,691 total lines / **1,877 code lines** (`grep -vcE '^\s*(#|$)'`)
  against the ~1,000-line soft guard. It must not grow further in this story.
- This worktree: clean. Main checkout: pre-existing unrelated uncommitted changes (docs,
  prototypes) — not ours, not touched.

---

## Problem Statement

**Movement style.** An Echo can hold a purpose (protect, guide, endure...) but has no way to
express *how* she carries it out. Every Echo enacting the same purpose looks identical in
combat — same approach, same posture, same choices — because `movement_style` does not exist.
`docs/movement-model.md` §9 specifies ten styles; today the player cannot tell two Echoes with
the same purpose apart by behavior. This also crowds "Interpret" (a nuanced response the
Decision Trace should be able to explain) into having almost nowhere to live, since purpose and
style are currently collapsed into one axis.

**Board variety.** Every fight inside one stage currently loads the same board shape and the
same spawn cells, because `encounter_id` (the seed key for terrain and spawn generation) is set
from the *stage*, not the *encounter* (`VentureController.gd:525`:
`flow_ctx.encounter_id = flow_ctx.realm_id + "." + stage_id`). Two different fights in the same
stage are visually and tactically identical. Separately, boards stay small and plain-square
early in a run (12×12, growing only with completed realms, of which only two exist), so
authored terrain character (islands, moats) often has no room to appear at all.

**Stalemate false positives.** The no-progress detector (shipped in V2-COMBAT-003) exempts
`PURIFY_SHRINE` and `GUIDE_SPIRIT` escort by name because their own progress is invisible to it.
`ENDURE` and `PURSUE` are *not* exempted and are safe only because their own clocks (5 and 12
rounds) happen to stay under the 15-round limit today. If a future tuning pass raises either
clock even slightly, a fight that is resolving correctly would silently end as a forced retreat
that pays nothing — and nothing would announce why. A genuine soft-lock (refusing Echo, guarding
enemy, 200+ rounds) must still be impossible to reach.

**Small defects and doc drift.** A scattered set of dead fields, one leaking debug dict, one
non-functional trait in combat, one cooldown that never blocks, a dead debug command, and two
places where documentation actively disagrees with the code or with itself — none of these are
visible to the player today, but each is a trap for the next change that touches its area.

**What becomes reliably true after this ships:** Echoes visibly vary in *how* they act on a
shared purpose. Fights inside one stage look and play differently from each other. Boards show
authored terrain character early in a run (per Jeff's chosen sizing option). A tuning change to
ENDURE or PURSUE cannot silently create a false forced retreat. The listed dead code, debug
command, and documentation contradictions are gone or corrected.

---

## Design Brief

**What changes for the player:**
- Echoes performing the same purpose (e.g. "protect") now visibly differ in how they approach
  it — different movement patterns depending on their assigned style.
- Two encounters in the same stage produce different board shapes and different spawn points.
- Early-run (Courage-stage) boards show visible authored terrain character instead of reading as
  plain squares — exact shape depends on which sizing option Jeff picks off measured numbers.
- A `combat_emotion` debug command that used to throw is gone. (`emotion`, the working command,
  is unaffected.)
- Nothing else changes visually. Combat resolution rules, action economy, and all existing
  emotion/fear/morale mechanics are untouched.

**What stays visually identical:** Combat UI layout, action buttons, HUD, all existing objective
types' win/loss conditions, all currently-working debug commands.

**What becomes more varied or more trustworthy:** Board shape per encounter. Movement expression
per Echo. The stalemate detector's coverage (now driven by a real progress signal instead of a
per-objective exemption list that can silently miss a new objective).

**What the player can verify after the story ships:**
- Same purpose, different Echoes, different movement patterns in a real fight.
- Replaying the same stage's two encounters back-to-back shows different boards and different
  spawn cells.
- A new game's Courage realm early boards show visible plateaus/islands, not plain squares.
- All seven objective types (`combat`, `shrine`/PURIFY_SHRINE, `boss`, `recover`, `protect`,
  `endure`/ENDURE, `pursue`/PURSUE) plus `GUIDE_SPIRIT` (protect and escort) start, run, resolve
  and return normally — no false forced retreat, no soft-lock.

### UI / UX Design

This is not a UI redesign; nothing new is drawn. Verification is entirely through:
- **`CombatBoardScreen`** — the existing isometric board already renders whatever terrain and
  spawn cells the backend generates; board variety and size changes are visible here with zero
  UI code changes.
- **Movement style** communicates through the existing token movement animation
  (`CombatTokenPresentationState`) — different styles route through different paths/behaviors
  that the existing waypoint-based tween already renders correctly, since it is agnostic to
  *why* a path was chosen.
- **`combat_emotion` removal**: deleting a debug command from `AppRoot.gd`'s debug dispatcher;
  no visible screen changes since the command already threw before producing output.
- **Regression detection**: any existing screen (Sanctum, Realm, Combat) rendering unexpectedly,
  or any debug command in the existing F1 panel behaving differently, is the tell that something
  leaked outside this story's intended surface.

---

## Architecture Blueprint

**Movement style ownership.** Following the precedent set by `DecisionTrace.gd` and
`GuidanceContribution.gd` (both extend `BehaviorArbiter`'s output without growing
`BehaviorArbiter.gd` itself), movement style selection gets its **own bounded file** —
provisionally `core/actors/behaviors/MovementStyleService.gd` — a pure, stateless service that:
- Takes the chosen purpose, the actor's identity (calling, traits, vectors), and context as
  input.
- Deterministically selects one of the ten styles from `docs/movement-model.md` §9 via
  `CampaignSeed.derive("behavior.movement_style.<...>")` (exact dot-path and selection
  algorithm to be confirmed against `docs/movement-model.md` §9 during contract freeze — I have
  not read that file directly this session, only the story brief's paraphrase of it).
- Is called by `BehaviorArbiter` (or `ActorStateMachine`) as a single attach point, not
  absorbed into `BehaviorArbiter`'s existing scoring logic.
- Writes `movement_style` onto `DecisionTrace` per §6.6, keeping `PLAYER_SAFE_FIELDS`
  sanitization intact.

> **Superseded by decisions #67/#6 in the two decision logs**: `movement_style` actually lives on
> Movement Intent (§6.5) and Movement Result (§6.7), NOT on `DecisionTrace` — §6.6 does not grant
> it a field there, and `PLAYER_SAFE_FIELDS` explicitly excludes it. Jeff confirmed: follow the
> doc as written. See `docs/stories/v2-combat-003.5/decisions.md` #6 for the full record. The bounded
> `MovementStyleService.gd` file itself was still built and is correct — only this one paragraph
> of the original plan was wrong and has since been corrected in practice.

**Locked invariant carried forward:** `directive_bonus` in `BehaviorArbiter._score()` stays a
flat additive term outside the fear/calling brackets. Nothing in this story touches `_score()`'s
structure.

**Board variety.** `encounter_id` moves from stage-identity to encounter-identity. Every seed
path keyed on `encounter_id` (confirmed this session, all in `core/`):
`EncounterSetupService.gd` (terrain :371, pursue-board :341/343, guide-spirit-board :356/358,
placement :388/392), `CombatRoundObjectiveService.gd` (theft :216/218),
`EncounterObjectiveSpawnService.gd` (guide_mode :364/366, spirit_name :383/385,
guide_spirit_joins :398/400, spirit_destination :565/567), `FlowRuntime.gd` (retreat
:1172/1174), `RecruitmentConsequenceService.gd` (:130/138), `LiveMovementContextService.gd`
(:152, :761) — **every one of these moves** once `encounter_id` identity changes. This is
authorized (Jeff confirmed board variety in scope) and every moved recorded value gets a named
cause in the phase's own commit, not a blanket re-baseline.

**Deliberately NOT built now:** cosmetic terrain variance (island shape) and
hazard/obstacle variance are excluded per Jeff's answer — but the encounter-identity change
becomes the foundation V2-COMBAT-004 needs to add them without a second seed-path rework.

**No new coupling.** `core/` stays free of UI/scene-tree references. `FlowRuntime.dispatch()`
remains the single mutation entry. No event bus, service locator, or catch-all helper.

---

## Measurement Plan

A green suite cannot see most of this story. Per group:

- **Movement style:** measure style distribution across purposes over a bounded number of
  production-generated combat rounds (mirroring `tools/TerrainRegionProbe.gd`'s
  production-faithful construction — Lesson from `docs/LESSONS.md` #17: a probe that doesn't
  build its inputs the way production does invalidates its own headline number). Failure
  condition: any purpose resolves to a single style 100% of the time, or Interpret remains
  unreachable.
- **Board variety:** confirm two encounters in the same stage produce different terrain seeds
  and different spawn cells, across a sample of encounter pairs. Failure condition: any pair
  still matches.
- **Board size:** measure what each of the three recorded options (raise `base_cols`/`rows`;
  scale island size to board area; accept plain early boards) produces on Courage
  (`realm.01`, 2–3 plateaus, 1–2 islands, `bridge_density` 0.0) and Wisdom (`realm.02`, 5–6
  plateaus, 4–6 islands) — same measurement shape as the `docs/LESSONS.md` #17 island-frequency
  probe. Bring the three option outputs to Jeff; do not choose on his behalf.
- **Stalemate false-positive envelope:** measure across all seven objectives
  (`combat`, `shrine`, `boss`, `recover`, `protect`, `endure`, `pursue`) plus `GUIDE_SPIRIT`
  escort and protect, on production-generated boards, after the exemption list is replaced by a
  real progress signal. Failure condition: any objective now force-retreats before its own
  natural resolution, or `GUIDE_SPIRIT` protect stops being caught by a genuine stall (its
  control test must keep passing).
- **Probe party-composition fix (item 7):** verify the fixed probe actually resamples
  calling/traits across seed variants (not just the first two seed-tag characters) before
  trusting any measurement above that depends on varied party composition.

---

## Verification Strategy

- **Unit tests** per phase, added alongside the phase's own files.
- **Integration tests**: `CombatRoundtripIntegrationTests`, `ObjectiveCombatTests` extended for
  the stalemate signal change; movement-style tests alongside `BehaviorArbiterTests`/
  `MovementOptionTests` family.
- **Deterministic fingerprint comparison**: `FlowSnapshotFingerprintTests` — expect board-variety
  phase to move fingerprints; every moved value gets a named cause in that phase's commit,
  predicted before observed (Lesson from `docs/LESSONS.md` #17/#27 — predict-then-observe
  attribution, scaled to this phase's actual blast radius, not a blanket re-baseline).
- **Full suite**: compile check + full deterministic suite at every phase boundary, not just at
  the end — this story is wide enough that phase-boundary regressions must be caught early.
- **Measurement probes**: per the Measurement Plan above, run once per phase that needs one.
- **Manual play verification**: after all phases land, before commit — Jeff tests a new game
  (explore-map terrain persists; an in-progress campaign would show stale boards and look like a
  false regression).
- **Dirty-tree and diff review**: after every headless Godot invocation, `git status` +
  inspect Godot-normalized `.tscn`/`.tres`/`.gd.uid` output; never stage unrelated pre-existing
  files (the main checkout's unrelated dirty state is explicitly out of bounds).
- **Combined verification**: `qa-verifier` reviews the full combined tree once all phases land,
  attacking the claims (movement style is reachable and varied; boards vary; the stalemate
  signal covers all objectives; nothing from V2-COMBAT-003 regressed), not confirming a
  completion report.

---

## Implementation Phases

Each phase: its own build dispatch (`sonnet` tier per the project's model-tier rule, escalating
to `opus` only where a phase's own difficulty warrants it — see notes), its own tests, a compile
check, and a highest-tier (`opus`) review against the actual diff before the next phase starts.
**Report the running total cost/risk to Jeff at each phase boundary**, not just the phase's own
cost (`docs/LESSONS.md` #21).

> **Status note, added 2026-09-19**: Phases 0-3a are committed (`369ccfe`). Phase 3b is committed
> (`603b5de`), after a full architecture rebuild — see `docs/stories/v2-combat-003.5/decisions.md` #18 for
> why. Phase 3 grew a third sub-phase, **3c**, not anticipated by this original plan: live
> movement wiring (`LiveMovementContextService`), which is what makes `movement_style` and board
> variety actually observable in real play rather than only in tests. Phase 3c is in progress,
> uncommitted, as of this snapshot — see `docs/stories/v2-combat-003.5/handoff.md` for its exact current
> state and what must happen before Phase 4 starts. Do not begin Phase 4 until Phase 3c is
> reviewed clean and committed.

### Phase 0 — Setup
- Record this session's interview answers in `ANSWERS.md` (board variety in scope; board size
  measured-then-chosen; all groups ship; story shape = sequential phases/one PR;
  `combat_emotion` deleted; both tie-break comments deleted; `ui/AGENTS.md` reworded to name
  screens; `_stationary_rounds` counter removed, no new feature; raw floats removed from
  snapshot whitelist; `_dominant_key` unified; `shrine_hp_ratio` deleted).
- Confirm the +16 test-count delta since the COMBAT-003 merge baseline (1613→1629) is not a
  contamination artifact — one targeted check, not a re-run.
- Dispatch: `mechanics-developer` (sonnet), quick.

### Phase 1 — Stalemate progress signal (Group B, item 11)
**Files:** `core/combat/CombatState.gd` (`check_end_condition()` branch 10),
`core/runtime/FlowRuntime.gd` (`_end_round()`), `data/balance.json`
(`data.combat.stalemate`), `tests/CombatStateTests.gd`,
`tests/CombatRoundtripIntegrationTests.gd`.
**Contract:** replace the by-name exemption list (`PURIFY_SHRINE`, `GUIDE_SPIRIT` escort) with a
genuine progress signal so a future objective cannot be silently forgotten. `GUIDE_SPIRIT`
protect mode's existing control test (asserting it still force-retreats on a real stall) must
keep passing.
**Tests:** the false-positive envelope measurement (see Measurement Plan) across all seven
objectives + `GUIDE_SPIRIT` both modes, before and after.
**Compile gate:** headless `--check-only`.
**Reviewer gate:** `opus`-tier review (`game-orchestrator` dispatches; this qualifies as
"diagnosing/replacing a signal an unknown mechanism depended on," opus-tier per the model
policy) against the actual diff and the envelope measurement.
**Rollback/stop condition:** if the new signal cannot be made to cover all seven objectives
without another named exemption, stop and report — do not ship a second exemption list under a
different name.

### Phase 2 — Board variety + board size (Group B1/B2)
**Files:** `core/runtime/controllers/VentureController.gd` (:525),
`core/combat/EncounterSetupService.gd`, plus every other `encounter_id`-keyed seed path listed
in the Architecture Blueprint above, `data/balance.json` (`data.combat.board`), `tests/StageTerrainTests.gd`, `tests/CombatRoundtripIntegrationTests.gd`,
`tests/FlowSnapshotFingerprintTests.gd` (expected to move; attribute every moved value).
**Contract:** `encounter_id` identifies one encounter, not one stage. Two encounters in one
stage produce different terrain, different spawn cells. Board size uses whichever of the three
options Jeff picks after seeing the measurement.
**Sequencing within the phase:** measure all three sizing options and present them to Jeff
*before* implementing the size change — his choice may affect the final board-size code path,
so don't build ahead of the decision.
**Tests:** board-variety measurement (encounter pairs differ), fingerprint attribution for every
moved value, sizing measurement per option.
**Compile gate:** headless `--check-only`.
**Reviewer gate:** `opus`-tier (moves recorded values — mandatory escalation per the model
policy).
**Rollback/stop condition:** if a recorded value moves and cannot be explained, stop — do not
re-baseline blind (`docs/LESSONS.md` #23-equivalent rule, restated in AGENTS.md's save/
determinism-safety section).

### Phase 3 — Movement-style axis (Group A)
**Files:** new `core/actors/behaviors/MovementStyleService.gd` (or confirmed equivalent name
after contract freeze), `core/actors/behaviors/DecisionTrace.gd` (add `movement_style` field),
`core/actors/behaviors/BehaviorArbiter.gd` (single attach-point call only — must not grow past
its current 1,877 code lines by more than the one call site needs),
`docs/movement-model.md` (reconciled with what's actually built), new test suite alongside
`BehaviorArbiterTests`/movement-family tests.
**Contract-freeze sub-step (do this first, before any code):** read `docs/movement-model.md` §9
(ten style definitions) and §6.6 (Decision Trace contract) directly — this plan has not read
that file itself, only the story brief's paraphrase — and confirm the exact style names and
selection rule with `sr-game-designer` before `mechanics-developer` builds against it.
**Contract:** ten styles exist, named per §9. Selection is deterministic, all RNG through
`CampaignSeed.derive`, zero draws in `core/movement/` and `core/actors/` outside the new
service. `DecisionTrace` carries `movement_style`; `PLAYER_SAFE_FIELDS` sanitization holds.
Interpret becomes reachable without naming a subject the Echo cannot serve.
**Tests:** style-distribution measurement (see Measurement Plan), reachability test for
Interpret, `DecisionTrace` sanitization test.
**Compile gate:** headless `--check-only`.
**Reviewer gate:** `opus`-tier — this is the highest-risk phase (new design surface, a file-size
guard already at its limit, an architecture decision about where behavior selection authority
lives).
**Rollback/stop condition:** if the new service cannot stay bounded without either (a) growing
`BehaviorArbiter.gd` past its guard or (b) duplicating logic `BehaviorArbiter` already owns,
stop and report — this is exactly the "no clean owner" case AGENTS.md's extraction rules call
out.

> **Actual outcome, added 2026-09-19**: Phase 3 split into three sub-phases in practice — 3a
> (route-shape foundation in `MovementOptionService.gd`, committed in `369ccfe`), 3b (the
> selection scoring architecture described above, after a full rebuild, committed in `603b5de`),
> and 3c (live wiring, not anticipated by this original plan text, in progress — see
> `docs/stories/v2-combat-003.5/handoff.md`). `movement_style` ended up on Movement Intent/Result, not
> `DecisionTrace` — see the Architecture Blueprint correction note above.

### Phase 4 — Doc/debug fixes (Group C)
**Files:** `ui/AppRoot.gd` (delete `combat_emotion` command + its dispatcher entry),
`ui/screens/combat/CombatTokenLayer.gd` (confirm no other caller of the now-removed
`set_emotion_debug()` no-op before deleting it too), `data/balance.json` (delete both stale
tie-break `_comment` blocks near lines 1476 and 1768 — verified this session that they also
disagree with each other, not only with the code), `ui/AGENTS.md` (reword the dispatch ban to
name screens specifically, since `AppRoot.gd` is the confirmed sanctioned dispatcher).
**Contract:** `combat_emotion` no longer exists as a debug command; `emotion` (the working
command) is unaffected. No `balance.json` comment claims a tie-break order the code doesn't
implement. `ui/AGENTS.md`'s ban is accurate to what's actually shipped.
**Tests:** none of substance — this is a deletion/wording phase. Confirm compile-clean and that
no other file references the deleted command or field.
**Compile gate:** headless `--check-only`.
**Reviewer gate:** `sonnet`-tier is sufficient (mechanical, low-risk); spot-check by
`qa-verifier` in the combined pass.
**Rollback/stop condition:** none expected; if `set_emotion_debug()` turns out to have another
caller, keep the no-op function and only remove the `AppRoot.gd` dispatcher entry.

### Phase 5 — Scattered small defects (Groups D/E)
One bounded sub-task per item, `mechanics-developer` (sonnet) unless noted:
- **`shrine_hp_ratio`** — delete the dead field from `CombatTurnContextService` and its
  publication point.
- **`_divergence_probe`** — stop leaking the raw `components` dict onto the intent; strip or
  scope it the same way the Phase-5 raw-floats fix does for the snapshot boundary.
- **`resist_fear`** — wire the trait into combat's per-hit fear path, matching how it already
  applies to bleed/weave/vow/Sanctum ticks. This is the one item in this phase with real
  in-combat behavior impact; give it its own test showing fear reduction on a hit for a
  `resist_fear` actor.
- **`_stationary_rounds`** — remove the dead counter; do not build the soft-taunt feature it was
  meant to gate (Jeff's decision this session).
- **`_withdraw_cooldown`** — fix the check-before-decrement ordering so the cooldown actually
  blocks during its window.
- **Probe party-composition fix (item 7)** — extend whichever probe tool
  (`tools/TerrainRegionProbe.gd` or its measurement-probe siblings used above) to resample
  calling/traits per seed variant, not just the first two seed-tag characters. Do this **early
  enough** that Phase 2/3's own measurements can use the fixed probe rather than measuring twice.
- **`_dominant_key` unification** — extract `GridService.gd:652`, `CombatState.gd:344`,
  `ShrineService.gd:158` to one shared static helper; each call site's existing tiebreak-list
  argument stays as-is (no behavior change — same lists, same order, now evaluated once).
- **Raw floats snapshot removal** — remove `_judgment`/`_composure`/`_legibility`/`_presence`
  from `EncounterSnapshotBuilder._project_actor`'s whitelist.
- **Enemy-directive faction gating (item 10)** — this is the one item that is **unproven**.
  First: one probe/test logging `directive_bonus` for a hostile actor to confirm or refute that
  `CombatTurnContextService.gd:192` sets `ctx["directive"]` with no faction check while
  mode-directive weights elsewhere ARE faction-gated. Only if confirmed real, gate it to match
  the existing `faction == "echo"` pattern. If refuted, say so and close the item — do not fix a
  defect that doesn't exist (mirrors the vector-tiebreak refutation from the prior story).
**Compile gate:** headless `--check-only` after each sub-item, or batched — orchestrator's call
based on how independent the edits prove to be.
**Reviewer gate:** `opus`-tier for `resist_fear` (behavior change) and the enemy-directive
investigation (diagnosis of an unproven mechanism); `sonnet`-tier sufficient for the rest,
spot-checked in the combined pass.
**Rollback/stop condition:** if `resist_fear`'s combat wiring touches anything the fear-economy
work (`V2-EMOTION-002`, currently Draft) depends on, stop and flag rather than guessing at the
boundary.

**Status note, added 2026-09-19**: Phase 5 has NOT started as of this snapshot. All of its items
remain open work, to be picked up after Phase 3c and Phase 4 are done. Check
`docs/stories/v2-combat-003.5/decisions.md` for whether any individual item's default treatment changed
during Phase 1-3 work (none noted as of this snapshot, but confirm).

### Phase 6 — Combined verification
Dispatch `qa-verifier` (no write tools, by design) against the full combined tree: attack the
claims from every phase above, not confirm completion reports. Specifically: re-derive the
movement-style measurement independently; re-derive the board-variety and false-positive-
envelope numbers; confirm `BehaviorArbiter.gd` did not grow; confirm the `directive_bonus`
invariant is intact; confirm `GUIDE_SPIRIT` protect's control test still passes; confirm no
`V2-COMBAT-003` behavior changed silently.

### Phase 7 — Full regression + measurement consolidation
Full deterministic suite (real `Tests:` line, not exit-code-only), all measurement probes
re-run once against the final combined tree, results consolidated for the Jeff-facing summary.

### Phase 8 — Manual verification (pause here)
Stop and ask Jeff to test a **new game** (not a continued campaign — persisted explore-map
terrain will make a working fix look broken). Checklist: movement style varies per Echo with
one purpose and Interpret is reachable; two same-stage fights show different boards/spawns;
Courage boards show visible terrain character early; all seven objectives + both `GUIDE_SPIRIT`
modes start/run/resolve/return correctly, no false forced retreat, no soft-lock;
`combat_emotion` command is gone and no other debug command broke.

### Phase 9 — Docs, Notion, CSV, commit, PR
Update `CONVENTIONS.md` (if any contract changed), `docs/MEMORY.md` (systems inventory + status
entry matching the "Shipped Story Status" format used for prior stories),
`docs/movement-model.md` (reconcile with what was built), `docs/integration-map.md` and
`docs/project_systems_audit.md` (kept synchronized with each other), the live Notion page
(reconcile with what shipped — note explicitly that the board-variety/size items were carried
forward from the pre-Notion-update state, not newly invented), the backlog CSV (append only,
never sort — a prior sort produced a 238-line diff for a 2-row change). Story-only commit
(never `git add -A`), push the feature branch, open a PR that names **every** subject the branch
carries — this PR will legitimately carry more than one subject by design, so the body must
enumerate all of them, matching the precedent set by the V2-COMBAT-003 PR body.

---

## Verification (end-to-end, how to confirm this plan's execution actually worked)

- Every phase's own compile check + targeted test filter while building.
- Full suite at every phase boundary (not just the end) — `Tests: N total, N passed, 0 failed`,
  grepped from a piped log, never re-run to check a second field.
- `git status` clean (in this worktree) after every phase, with only this story's files staged
  at commit time.
- Jeff's manual new-game pass (Phase 8) before any commit.
- Final diff review naming every moved recorded value and its cause (Phase 2's fingerprint
  moves, specifically).
