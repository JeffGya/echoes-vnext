# V2-DIRECTIVE-002 — Session handover (rewritten 2026-10-18, after phase D was built)

Read this first after a compaction. Then read the files in section 3. Written in Simplified Technical English (STE).
You are the **game orchestrator** (`.claude/agents/game-orchestrator.md`). You coordinate. You do not implement. Jeff is the designer. He decides scope, numbers and player-facing wording.

**How to write to Jeff (he corrected this three times, 2026-10-13 and 2026-10-14):**
- Short sentences. 20 words or fewer. No semicolons.
- State the decision first. Then the options. Then your advice.
- Explain a code term once, in plain words.
- End every message with: Done / Next / Need from you.

## 1. Where we are

| Item | State |
|---|---|
| Story | V2-DIRECTIVE-002 (profile-sensitive Directives). Engine: Godot 4.6.1. Notion page id `339c3d1e-de92-8103-9faa-cf423c3e61ba`. Spec State is Locked. |
| Phase A | DONE and merged. PR #106. |
| Phases B+C | DONE and merged. PR #107. |
| Phase D | BUILT and committed on branch `claude/v2-directive-002-phase-d`. **DRAFT PR #108**: https://github.com/JeffGya/echoes-vnext/pull/108. Check the head with `git log --oneline -5` (last known head `32a55b0`). |
| Last full serial suite | Not recorded yet. The main chat runs it (see section 4). Known red test: `movement_arbiter/avoid_overcommit_stays_proportionate` (no owner, not this story). |
| Docs pass | Done 2026-10-18 and left uncommitted for the main chat to commit: integration map, systems audit, MEMORY, CONVENTIONS rows, LESSONS #39 to #41, phase D design files, follow-ups, this file. |
| AGENTS.md | Suite count 133, `felt_state` in the suite list and shard 1 map: done in commit `32a55b0`. Stale numbers (`~124`, `~16 sibling`) remain. They need Jeff's yes. |
| Parked goal | V2-COMBAT-004 (Keeper tactical guidance). Planning resumes after PR #108 merges. Recon is in the memory file `directive-002-before-combat-004`. |
| Worktree | `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd` (old name; the branch is the phase D branch). |

**Commit rule (Jeff's standing yes):** commit as we go, after the main chat has verified the work. Push with `git push -q`. Jeff merges. One PR per phase.

### 1a. What phase D built (short)
- Combat route scoring reads the Directive `exposure_tolerance`. Acceptance = tolerance minus `data.combat.movement.exposure_acceptance.offset`. The intent weight `exposure_acceptance` serves action choice only.
- One Judgment scale on acceptance and on the Directive stop cause. One floor key: `data.combat.movement.directive_judgment` (`judgment_floor`, `judgment_floor_min`). One helper: `core/actors/behaviors/DirectiveJudgmentScale.gd`.
- Directive stop cause in `StopShortService` (last row). Affinities in `data.actor.stop_short.directive`. Text key `cause_clause.directive_order`.
- One emotional-status reading: `core/emotion/EmotionStatusLean.gd` (larger of fear and base fear). Config `data.combat.movement.felt_state`. The stage reads it too (`StagePartyStance`; `state_ramps` removed; `readiness.status_steps_lost`).
- Slice 5: lean on progress and cohesion weights. Slice 6: `MovementProfileService.apply_state_steps` after `derive_profile`. Slice 7: Standing-scaled style (wired by the final QA fix).
- Swing budget `interpretation_swing_max` 2.5, with `layer_max.action` and `.stop` 2.0. Judgment is required on the movement path (`missing_judgment`). The divergence check removes the Directive acceptance part and the stop bias.
- Tests and tools: suites `fingerprint_seek` and `felt_state` (133 suites). Probes `SpatialTermProbe`, `ExposureChoiceBoards`, `ExposureCaptureArbiter`. Seam `FlowRuntime.behavior_module_factory` (unset in play).
- No new snapshot field, save field or action type.

## 2. Decisions recap (full log: `decisions.md`, D-00 to D-91; ANSWERS #81, #82, #83)

Earlier decisions (D-00 to D-65) are in `decisions.md`. Phase D decisions:

| ID | Decision |
|---|---|
| D-69 to D-73 | Design answers, numbers approved. Exposure weight 17. Hold affinity 0.8. |
| D-74 to D-80 | Seek fingerprint suite. Measure exposure choices once (1 to 2 percent of Echo decisions). |
| D-81, D-82 | State systems must matter. Budget may rise to 2.5. |
| D-83, D-88 | Fear rule, floor minimum 0.55, one shared floor key, stop line wording. |
| D-84, D-85 | No authored arenas. Procedural only. No GDD change. |
| D-86 | One recorded-value run for slices 5 to 7. |
| D-87 | One reading per system. Binding rule. |
| D-89 | Slices 5 to 7 build basis. C1 to C5 and C8 taken. C6 and C7 deferred. |
| D-90 | Stop rate measured: Scout 8.7 percent, Seek 7.5 percent. No change. |
| D-91 | Final QA answers. Stage aligned to the emotional status. |

## 3. File map (all in `docs/stories/v2-directive-002/` unless noted)

| File | What it is |
|---|---|
| `decisions.md` | Decision log, D-00 to D-91. |
| `phase-d-design.md`, `phase-d-numbers.md` | Phase D design and numbers. Superseded passages are marked. |
| `phase-d-design-5-7.md` | Slices 5 to 7 note (one reading per system). Build basis. |
| `exposure-lever-study.md`, `state-systems-movement-study.md` | Studies behind D-76 to D-82. |
| `proposed-wording-stop-cause.md` | Stop line proposals. Jeff chose C (D-88). |
| `follow-ups.md` | Open items and findings not in scope. Read it fully. Last section: phase D. |
| `design.md`, `numbers.md`, `backend-plan.md` | Phase B+C documents. |
| `new-story-drafts.md` | Drafts of V2-BOND-004 and V2-STAGE-010. |
| `~/.claude/plans/jolly-cooking-crescent.md` | Approved plan. Read the last "Status addendum". |
| `docs/LESSONS.md` (#34 to #41), `AGENTS.md`, `ANSWERS.md` | Rules and recorded decisions. Never read `CONVENTIONS.md` or the GDD whole: use `docs/canon-index.md`. |

## 4. Next steps, in order

1. **Full serial suite** on the phase D head. The main chat runs it (alarm 3600, tool timeout 3700000, background, log to a file). Read the `Tests:` line. Expected: one failure, the known red test.
2. **Commit the docs pass** (uncommitted files listed in section 1). Check `git diff --stat` first.
3. **Ask Jeff for his yes** on two items:
   - Notion: copy D-69 to D-91 to the V2-DIRECTIVE-002 page. Show each edit first.
   - `AGENTS.md`: replace the stale numbers `~124` (lines ~203, ~291) and `~16 sibling suites`. The same stale comments are in `scripts/run-tests-sharded.sh` (lines ~22, ~93, ~267).
4. **Mark PR #108 ready.** Jeff merges.
5. **Jeff's remaining work:** wording in `data/ui/stage_why_text.json`; finished glyphs; the blank Advance label task (`task_2e47501b`); decide the items in `follow-ups.md`.
6. **V2-COMBAT-004 planning** resumes after the merge.

## 5. Rules you must follow (Jeff's)

- **STE.** Write to Jeff in STE. STE does not apply to player-facing game text. Player wording is Jeff's.
- **One reading per system (D-87).** Before a mechanic reads fear, morale, Judgment or composure, grep the code for the existing reading. Use it. Add no second one.
- **Few runs (D-79, D-86).** No weight sweeps. One recorded-value run for a group of slices. No QA agent runs tests. One full serial suite at the end.
- **No GDD change (D-85).** Stages and combat boards are procedural by seed (D-84). Do not propose authored arenas. Check options against the GDD generation model.
- **Comments short, no story ids, no hard-coded numbers.** Refer to config (D-88). AGENTS.md rule 28.
- **Working preferences** (`~/.claude/CLAUDE.md`): ask before assuming. Jeff designs, you coordinate. Backend before frontend. Every story ends with Docs + Commit.
- **Repo `CLAUDE.md`:** agents default to sonnet. Opus is per call. Never `fable`. Agent questions reach Jeff through you (OPEN blocks). Re-check `BLOCKED` lines against the repo first.
- **ASSUMED lines** that change what Jeff sees or feels become questions before the next step (LESSONS #37).
- **Tests:**
  - ONE full mode only: serial. No subagent runs a long command (over about 2 minutes) or any full suite, including `qa-verifier`. A subagent ends with a RUN REQUEST. The main chat runs it.
  - Filtered runs: one per shell command, never two at once. `rm -rf /tmp/echoes-vnext-tests` first. Confirm a `Tests:` line.
  - Never use the filter `fingerprint`. Use `snapshot_fingerprint` or exact suite names.
  - Rebuild the class cache (`--import`) before you believe a fingerprint failure.
- **Ask first:** `AGENTS.md` edits and Notion writes.
- **Tunables live in config** (ANSWERS #83).
- **Commits:** STE message. End with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Habits:** after an agent stops, audit the tree (`git status`, `git diff`) before you trust its report. Findings are not authorisation. A probe whose input is invalid proves nothing (LESSONS #40).

## 6. Facts worth remembering

- `EmotionStatusLean` is the one fear-and-morale reading. `EmotionService.get_emotional_status` is the table; callers pass the larger of fear and base fear.
- Two exposure inputs remain on purpose (D-69): the intent weight (action choice) and the Directive tolerance (movement).
- Exposure choices are rare in generated fights (D-80). The effect shows on test boards. A watch note exists on V2-STAGE-010 (D-85).
- `ConfigService.get_directives_cfg` owns the Directive subtree read. `DirectiveService.resolve` is the accessor.
- Save dirs: tests use `/tmp/echoes-vnext-tests`. Normal play uses `~/Library/Application Support/Godot/app_userdata/echoes-vnext/saves/`.
- Memory dir: `/Users/jeffreygyamfi/.claude/projects/-Users-jeffreygyamfi-Sites-echoes-vnext/memory/`.

## 7. Open items for Jeff (ask one at a time)

| # | Item | Recorded in |
|---|---|---|
| 1 | Notion copy of D-69 to D-91. Needs his yes. | section 4 |
| 2 | `AGENTS.md` stale numbers. Needs his yes. | section 4 |
| 3 | Phase D follow-ups: divergence parts, one Echo gate, raw fear readers C6 and C7, known red test owner. | `follow-ups.md` (last section) |
| 4 | Player wording in `data/ui/stage_why_text.json`. | D-48, D-57 |
| 5 | Finished glyph shapes. | `glyph-shapes.md` |
| 6 | Dropped names: 52 percent dropped by `confirm_walk`. | D-65 |
| 7 | Blank Advance label: separate task `task_2e47501b`. | this file |
| 8 | Overlap of exposure-choice generation with V2-COMBAT-004 slices 004B and 004D. | D-85 |

## 8. Briefs to re-use

- **Fix after a suite run (owning agent):** name the failing test, the cause and the file. One cause per fix. Opus if the cause is unknown. End with a compile check and a filtered run. No full suite.
- **Docs pass:** list the facts to check in code. The agent edits docs only and reports what it could not verify.
