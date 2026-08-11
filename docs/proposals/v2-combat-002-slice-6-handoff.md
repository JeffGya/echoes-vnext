# V2-COMBAT-002 Slice 6 — Continuation Handoff (6B → 6E)

Untracked planning doc in Jeff's `docs/proposals/` area. Reachable by the next agent
working in the same local repo. Written 2026-07-23 after Phase 6A shipped.

The full approved plan is at `~/.claude/plans/snazzy-fluttering-blanket.md`; this doc
is the authoritative RESUME state and supersedes that plan's 6A section (now history).

---

## STATE AT HANDOFF

- Story V2-COMBAT-002, final slice (Slice 6 = live cutover of the movement layer).
- Slices 1–5 shipped. The movement layer under `core/movement/` was fully DORMANT.
- **Phase 6A is DONE and in PR #51** (`feat/v2-combat-002-slice-6a`, commits `46ed833`
  + `886a9a3`). Dormant contract + config prep. **Suite: 1274/1274, 0 failed.**
  Once PR #51 merges, that is the new baseline.
- Three-PR structure: **PR 1 = 6A (dormant, in review)** / **PR 2 = 6B+6C (live cutover)**
  / **PR 3 = 6D+6E (stopgap presentation, tuning, docs)**.

### What 6A already delivered (do NOT redo)

- `MovementGoal` purpose/plan rules fixed: place-directed `advance` (empty target +
  `objective.<semantic>` source, semantic-token-gated per the Codex fix in `886a9a3`);
  `escort`/`protect` accept `protect_ally` or untargeted `actor.guard`; `withdraw`
  admits guard/idle (the §8.3 "forfeit" attribution was RETRACTED — it stays UNOWNED,
  belongs at action resolution, carry it if you touch withdraw).
- `GuideSpiritActivationService` now emits validatable goals (escort→`advance`/`actor.move`,
  protect→`withdraw`/`actor.move`, no-step→`hold`/`actor.guard`). Behaviour unchanged.
- Config seams live in `data.combat.movement.pressure` and `.slack`; `step_budget`
  fallback unified on `DirectiveService.DEFAULT_STEP_BUDGET`.
- **Pulled forward from 6C's original scope — ALREADY DONE:** manhattan criterion
  removed; the biased lexicographic tie-break replaced by a salted **FNV-1a/32** hash
  (`_salted_cell_hash`, `select_frontier(..., salt: String = "")`); the old
  characterisation test deleted and replaced with a no-systematic-compass-bias +
  replay-determinism test. `select_frontier` already takes both `heading` and `salt`
  parameters — they just are not fed from live state yet.

### Decisions already taken (do NOT re-litigate)

1. Stage chaining **re-plans per hop** (fog lifts before the next hop plans).
2. Cold-start bias fixed via the **mirror-covariant / salted-hash guard** (done in 6A).
   The honest caveat holds: two candidates related by a mirror of both board and party
   are genuinely indistinguishable; the goal is removing *systematic* compass preference.
3. `select_frontier` returning `{}` **maps explicitly to Tier 4**.
4. **ENDURE** is served by the generic ordinary-combat path + board fallback under
   `COLLAPSE_HEALTH`; NO `_add_endure`. Add a test pinning board fallback as health collapses.
5. Slack: contract keeps 2/0.25 as the invariant floor; only the adapter is seamed
   (done in 6A). Config may NARROW, never widen.
6. Presentation is a **MINIMAL STOPGAP ONLY** — the sole goal is "tokens must not cut
   through walls." NO hazard feedback, NO activity text, NO death beat. The full
   treatment stays with COMBAT-004. (Jeff chose the stopgap, not the fuller §3 option.)
7. Three PRs.

---

## PR 2 — Phase 6B (Combat cutover) + Phase 6C (Stage cutover). THIS IS LIVE.

Backend-first: 6B before 6C. This PR changes real in-game behaviour, so it ends with a
**genuine manual gate** — Jeff forces every mode and confirms behaviour before commit.

### 6B — Combat

- `core/actors/ActorStateMachine.gd` — delete the movement mutation (~:339-357). Keep
  identity/emotion/skill prep. Re-feed `_update_passive_state` (~:392) from actual
  traversal, not the selected intent, so a blocked move stops counting as movement.
- `core/runtime/FlowRuntime.gd:1773-1779` — delete the GUIDE `grid_pos` capture/restore
  workaround. It exists only because `advance_turn` owned execution; deleting the
  mutation makes it dead code that would mask bugs.
- `core/actors/behaviors/BehaviorArbiter.gd` — wire `select_movement_intent` (~:361). It
  is a complete working selector, not a stub; it has no caller. **AUDIT EVERY
  `BehaviorArbiter.new(...)` SITE FIRST** — `:428` does a bare `_movement_cfg["spatial_utility"]`
  subscript, so an empty movement config is a HARD CRASH, not a soft default (top risk).
  Upgrade live `select_intent`'s two-key tie-break (~:335-339) to the four-key order, or
  the two selectors disagree. Retire the exact-cell mode overrides in `_generate_candidates`
  (PURSUE ~:1107-1114, PROTECT ~:1058-1097, purify ~:1048-1049) for pressure regions.
- `core/runtime/FlowRuntime.gd` `_resolve_next_actor` (~:1614-2101) — insert EXACTLY ONE
  call to `CombatActivationService.activate(...)` between `advance_turn` and bark
  queueing. Context assembly already lives here (`:1661-1662` threads walkable + board
  dims — that IS the `MovementContext` payload); no new algorithm enters FlowRuntime.
- `core/runtime/FlowRuntime.gd:2075-2094` — replace the inline PURSUE escape check with
  `PursueEscapeService.is_escaped` (byte-replicates `:2082-2087`, provably
  behaviour-preserving). Add the fidelity test.
- `core/runtime/FlowRuntime.gd:2749-2762`, `:2777` — replace the `_end_round` GUIDE
  escort/skittish movement with `GuideSpiritActivationService.activate_spirit(...)`,
  resolved BEFORE GUIDE progress is scored. Nothing else in `_end_round` moves anyone;
  steps that only READ positions must stay untouched.
- `core/grid/GridService.gd:113-176` — delete `move_toward` and its legacy greedy fallback.
- **Group-D live-caller guards:** reconcile `controlling_state` default (executor false
  vs profile true); ASSERT `hazard_ctx.config` presence (it currently fails soft to ZERO
  damage); drive `mover_ko_only` from live actor state; declare the guard/observe
  fallback; disambiguate `"no_route"`'s four conflated outcomes (caller-gated /
  joined-refusal / arrived / unreachable — "arrived" and "unreachable" are opposite facts
  a GUIDE scorer must distinguish); fix joined-refusal double-billing Burning.
- **ENDURE** (decision 4): document the generic path; add the board-fallback test.
- **Also fix now:** the `advance` objective-source clause is near-vacuous inside
  `CombatPressureService` because `_goal_sources` appends `objective.<id>` to every goal
  in an objective mode regardless of what it targets. Tighten so the source relates to
  the goal, before the arbiter goes live. (Carried from the 6A review board.)

### 6C — Stage

- **Heading:** derive from `explore_map["last_traveled_origin"] → party_pos` and feed
  `select_frontier`'s existing `heading` param. Slice 5 already persists
  `last_traveled_origin`; NO new save field. Recompute per chain hop, not once per advance.
- **Salt:** feed `select_frontier`'s existing `salt` param from stage identity (realm id +
  stage index) out of `explore_map`/run state — constant per stage, so replay is stable.
- **Chaining (decision 1):** restructure `FlowRuntime._handle_stage_advance_turn`'s loop
  (~:6177-6222) so each hop builds its own intent and executes it, lifting fog before the
  next hop plans. Preserve per-cell fog, `_situation_blocks_step` interruption, turn
  accounting, budget consumption exactly.
- Replace `StageTerrain.next_step` / `nearest_unexplored` in the stage loop with the
  adapter. **Sentinel (decision 3):** map `select_frontier` `{}` to an explicit Tier-4 branch.
- Fix **E1** (the `dist_field`-empty branch teleports the party to target, ~:6202-6204)
  and **E2** (`stage.is_empty()` early-exit at ~:6097 skips the snapshot refresh).
- NOTE: the frontier tie-break itself is already fixed (6A). 6C only PLUMBS heading + salt
  and does the chaining/sentinel/E1/E2 work.

### Tests that legitimately change (update, do NOT coerce green)

`GridTests` (4 `move_toward`), `CombatTerrainTests` (~11; `:345-346` asserts the legacy
greedy path byte-identical — intentionally broken now; `:646` monotonic Chebyshev per
call — multi-step routing breaks it), `StageTerrainTests` (`next_step_no_lateral_drift`
~:419-424), `CombatRoundtripIntegrationTests` (all three components change at once).
Likely: `ObjectiveCombatTests`, `Stage004SeamTests`, `StageExploreTests`,
`StageExploreP5Tests`, `TraversalModelTests`, `BehaviorArbiterTests`, `StageObjectiveTests`,
`ContactModelTests`.

### PR 2 gate
Compile clean; full suite green with the above legitimately-updated expectations; **Jeff's
manual pass over all seven modes + stage under both directives.** Tokens must never cut
through walls — but that visual is 6D; for PR 2 the acceptance is behavioural (purposeful
movement, correct per-mode behaviour, no top-left/bottom-right drift, party-based stage).

---

## PR 3 — Phase 6D (minimal stopgap) + Phase 6E (tuning, regression, docs)

### 6D — Minimal presentation stopgap (decision 6). Scope: tokens must not cut through walls.

- Thread the traversed path into the encounter snapshot. NO `path`/`actual_traversed_cells`
  field reaches any snapshot today — `FlowEncounterState.gd:1554` projects
  `last_actor_action`, carrying only `action_type` + `source_id`.
- Chain the token tween per path segment in `ui/screens/combat/CombatTokenPresentationState.gd`
  (~:34-148, replacing the straight `start_pos.lerp(target_pos)` at ~:137). **Reuse the
  proven pattern at `ui/screens/venture/StageExploreScreen.gd:489-541`** (already chains one
  tween per cell, already corrected for path-excludes-origin). Port its SHAPE — stage tweens
  the board under a fixed token; combat must tween the token.
- **Total-duration clamp is required, not optional** (`movement-model.md:2466-2467`): an
  uncapped capacity-6 move at 180 ms/tile is ~1.08 s and starves the AutoTimer. Ensure the
  AutoTimer cannot fire mid-animation.
- Consume `MovementResult.actual_traversed_cells` VERBATIM. Do NOT port the prototype's
  `_presentation_path()` reconstruction — it tolerates malformed input and would hide the
  contract violations `MovementContractValidation` exists to surface.
- OUT of scope for the stopgap: hazard feedback, activity text, death beat.

### 6E — Tuning, regression, docs

- Jeff ratifies the proposed 3/3 hazard damages by manual play (`data.combat.movement.hazards`,
  marked PROPOSED DEFAULTS).
- Close test gaps: F2 (`resolve_pickup` "mover_downed", `track_carrier_movement`
  `carrier_downed`, `precludes_attack` on invalidated pickup), F3 (legacy-save prepended-path
  × repaired-origin), F4 (`_003_repaired` flag not set by the `last_traveled_origin` repair).
- Docs: `CONVENTIONS.md`, `docs/MEMORY.md`, `docs/integration-map.md`,
  `docs/project_systems_audit.md`, and **amend `docs/movement-model.md:2649-2653`** to record
  that the minimal movement animation ships in COMBAT-002 while Slice F presentation stays
  with COMBAT-004. Fix the stale `AppRoot.gd` F1 help string. Notion story page last, matching
  the Slice 1–5 progress-entry format.

---

## METHOD (unchanged, Jeff enforces)

- Orchestrator DELEGATES every file write — code, tests, config, docs. Own hands touch only
  scratchpad/planning docs, memory, git, the compile/test watchdogs, and dispatch. Jeff has
  corrected this twice.
- Build agents SERIAL in the single local repo, disjoint file ownership. `FlowRuntime.gd`,
  `BehaviorArbiter.gd`, `balance.json`, `AppRoot.gd` are serial bottlenecks — never two
  concurrent editors.
- Independent reviews at each PR gate (architecture, determinism, movement-design,
  mode-correctness, test-coverage). **MUTATION TESTING BANNED in review agents.**
- VERIFY personally: re-run the suite; the runner ALWAYS exits 0, so the ONLY truth is
  `Tests: N total, N passed, M failed` plus a grep for `❌`. A `Tests: 0 total` means a
  registered test has no body (an interrupted agent) — audit registered-vs-defined.
- Interrupted agents leave green-compiling trees whose comments describe unimplemented code.
  Audit per spec item; never trust a report or a green compile alone.
- STOP for Jeff on genuine design forks the decisions above do not settle.

## GIT / WORKTREE

- Build in the LOCAL repo `/Users/jeffreygyamfi/Sites/echoes-vnext` (Jeff's instruction — he
  tests directly). Import cache already warm.
- After PR #51 merges: `git -C <repo> checkout main`, `git merge --ff-only origin/main`,
  then branch `feat/v2-combat-002-slice-6bc` off merged main. Re-baseline (expect 1274/1274).
- Stage EXPLICITLY at commit time (never `git add -A`) — the import step regenerates stray
  `.uid` sidecars for older movement scripts that must NOT be committed.
- PRESERVE Jeff's dirty/untracked files: `AGENTS.md`, the GDD, the backlog CSV,
  `docs/movement-model.md`, `docs/proposals/` (including THIS file), `prototypes/`. Never
  reset/stash/stage/commit them.
- Commit messages end with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  PR bodies end with:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## VERIFY COMMANDS

Compile: `/opt/homebrew/bin/godot --headless --check-only --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext`
Tests:   `/opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext -- tests`
Benign ERRORs: the `uid://8qssuuodths2` theme warning, `BehaviorModule.*() called on base class`,
`[SaveService] Invalid save: missing schema_version`.

## GOTCHAS (each already cost real time this story)

1. Runner ALWAYS exits 0. Grep `Tests: N total, N passed, M failed` AND `❌` lines.
2. A fresh worktree has no `.godot` import cache and the headless run HANGS until killed —
   `godot --headless --import --path <repo>` once (~9s). (Not needed here; local repo is warm.)
3. Avoid `cd` — use `git -C` and absolute paths; godot takes `--path`.
4. Do NOT use the perl watchdog from AGENTS.md; call godot directly with the Bash timeout.
5. Mutation testing by agents can leave the tree red behind a green compile — ban it.
6. `user://` resolves by PROJECT NAME, so running the game from here touches Jeff's REAL
   save. The headless test runner is unaffected. (First relevant at the 6B/6C manual gate.)
