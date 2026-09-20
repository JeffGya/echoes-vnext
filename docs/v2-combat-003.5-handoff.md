# V2-COMBAT-003.5 — Handoff for Post-Compaction Continuity

Written 2026-09-19, just before a context compaction. This document exists so the next turn of
this session picks up exactly where this one left off, with the exact same working pattern, not
a fresh guess at either.

## Who you are in this conversation, non-negotiably

You are the **game-orchestrator** for this repository. Jeff (Jeffrey Gyamfi) is the designer; you
are the developer. This is fixed by:
- The root `CLAUDE.md` at the repo root (this worktree's copy) — the orchestration contract.
  Read it in full again after compaction if any doubt remains about scope, model tiers, or
  parallelism rules.
- The user's global `~/.claude/CLAUDE.md` — working preferences (STE communication is one of
  them, see below).
- `~/.claude/lessons.md` — cross-session corrections. Several were added or updated THIS
  session; read the whole file, not just the newest entries.

**You do not write code, run Godot commands, or edit source files yourself.** You dispatch to the
project's nine-agent roster (`sr-game-designer`, `mid-game-designer`, `mechanics-developer`,
`game-feel-developer`, `sr-game-artist`, `technical-artist`, `ui-ux-designer`, `qa-verifier`,
`game-orchestrator` itself only for sequencing). Never a generic `Explore`/`general-purpose`
agent for this project — always the roster. This was corrected once this session (see lessons).

**Communicate with Jeff in Simplified Technical English (STE)** — short sentences, one meaning
per word, no idioms. He asked for this explicitly mid-session and it applies to everything you
say to him from here forward, including any message right after compaction.

## The exact working pattern this session established

1. **Every build gets a review gate.** A builder never verifies its own work. Dispatch
   `mechanics-developer` (or another roster agent) to build, then dispatch `qa-verifier` (always
   opus tier, no write tools) to attack the claim — not confirm it. Repeat until `qa-verifier`
   says SHIP with no blockers.
2. **Model tiers**: `sonnet` for well-specified builds. `opus` for genuinely tricky work
   (diagnosing an unknown mechanism, redesigning something that broke an invariant, the live
   combat path) and always for `qa-verifier`. Never omit the `model` parameter.
3. **Killed-agent discipline.** A background agent WILL get killed mid-task by a session or rate
   limit — it happened repeatedly this session. When that happens: **audit the tree yourself
   first** (`git status`, `git diff`, read the actual files) before re-dispatching. Do not trust
   a killed agent's last visible message as a status report. Several times this session the
   killed agent's work was actually complete and correct, or complete-but-missing-one-piece — the
   audit is what told the difference, not assumption in either direction.
4. **Decisions vs. ANSWERS.md — do not confuse these two files.**
   - `ANSWERS.md` (repo root) — ONLY for answers gathered through a formal `/interview` skill
     invocation. This story's interview happened once, near the start (entries #51-61 there).
     Do not add to it outside a real `/interview` run.
   - `docs/v2-combat-003.5-decisions.md` — the running decision log for THIS story, for every
     other decision made during ordinary orchestration (AskUserQuestion rounds mid-build,
     scope calls, design ratifications). Currently at **entry #28**. Same Q/A/Source/Date format
     as ANSWERS.md, plus an Overview table at the top. Add every new decision here, not to
     ANSWERS.md. This split was corrected mid-session (see lessons) — do not regress it.
5. **Ask Jeff before design/scope calls, not after.** Use `AskUserQuestion`, recommend an option,
   let him choose. He has caught real scope-widening and factual errors this way multiple times
   (e.g. the movement_style architecture rebuild, the board-variety Notion discrepancy, the
   crawl-at-range regression). Don't skip this to move faster.
6. **Comment density — stay lean.** Jeff flagged this explicitly mid-session: "we need to
   simplify these comments... we don't need this many comments." `AGENTS.md` entry 28 already
   says this; state it directly in build briefs anyway, don't just cite the file.
7. **One-line text changes still need a test run.** Learned the hard way this session — a
   "trivial" bark-string lowercase edit broke a test elsewhere that asserted the old value, and
   it wasn't caught for two phases. Before scoping any content/copy change to "compile check
   only," grep the literal value across `tests/` first.
8. **Interim WIP commits per shipped phase** (Jeff's decision #15) — not one commit at the very
   end. Story-only files, never `git add -A`. See "What's committed" below.
9. **Spawn a task chip (`mcp__ccd_session__spawn_task`) for anything genuinely out of this
   story's scope that you notice in passing** — don't silently fix it, don't silently drop it.
   Six of these exist so far, tracked in `docs/v2-combat-003.5-followup-tasks.md` (this file was
   found missing from the repo during this document's own verification pass — it only ever
   existed in a scratchpad and in a file sent to Jeff — and was recreated in the repo
   immediately after, so it is now a real, committed-when-this-phase-commits artifact). Keep it
   updated every time a new task chip is spawned, and resend it to Jeff when it changes.

## Story state — read this before doing anything else

**Plan file**: `/Users/jeffreygyamfi/.claude/plans/rippling-conjuring-neumann.md` — the original
approved plan, phases 0-9. Still the governing structure; Phase 3 grew far larger than
originally scoped (3a/3b/3c sub-phases) because of what got discovered along the way — that's
expected and already reflected in the decision log, not a deviation to worry about.

**Repo-tracked fallback copy of the plan**: `docs/v2-combat-003.5-plan-snapshot.md`. The real
plan file above lives outside the repo, which is a weaker link for post-compaction continuity, so
this is a point-in-time snapshot of it, placed in the repo as insurance, with two correction
notes added inline (the `DecisionTrace` vs. Movement Intent/Result placement, and the Phase 3
sub-phase split). Prefer the real plan file when reachable; fall back to this copy if not. **This
file is TEMPORARY** — along with `docs/v2-combat-003.5-handoff.md` (this document) and
`docs/v2-combat-003.5-followup-tasks.md`, Jeff has said these get cleaned up at Phase 9, during
docs/PR prep, not before. Do not delete any of them earlier than that on your own initiative.

**Committed so far** (on branch `claude/echoes-vnext-docs-review-b8028b`):
- `369ccfe` — Phases 1-3a: stalemate progress signal, board variety + size, movement
  route-shape foundation.
- `603b5de` — Phase 3b: movement-style selection service (the scoring architecture, after a
  full rebuild — see decisions #18-25 for why).

**In progress, UNCOMMITTED right now** — Phase 3c, live movement wiring. This is the most
complex, highest-risk phase in the story (the live combat path). Do not treat it as done. Current
sub-state, in order of what happened:

1. `LiveMovementContextService` rewired to call `MovementOptionService.generate_options()` per
   goal instead of one hardcoded `"direct"` option — this is what makes `movement_style`
   observable in real play for the first time. ~230 lines of duplicated pathfinding deleted.
2. Found and fixed along the way: an option-count validation cap that would have silently
   discarded the whole live board once more than 4 real options could be generated (raised to
   match the 11-value style vocabulary); a ~16x performance regression (two full pathfinding
   searches where one would do); a board-discarding bug where two validation rules (a
   truncated-route action downgrade vs. an exact-match requirement) had never met before this
   phase (resolved: keep the action name verbatim, decision #26).
3. **A real regression discovered and now being fixed**: movement selection scoring had (and
   has, pending the fix below) a unit-mismatch bug — a "progress toward target" term shrinks
   with distance, a "cost of the move" term didn't, so past a break-even distance EVERY actor's
   best move collapsed to the smallest possible step (1 cell), regardless of movement capacity.
   Confirmed via measurement, docs (`docs/movement-model.md` names this exact symptom as a
   defined failure the whole movement rewrite was meant to eliminate), a game-feel verdict
   (feels wrong), and critically — **confirmed against Jeff's own prior play-testing**: before
   this story, movement had no scoring choice at all, an actor just moved as far as its
   Standing/Calling-driven capacity allowed, which is what Jeff remembered working correctly.
   This story's Phase 3c wiring is what introduced the scoring choice that broke it. Decision
   #28: fix it in this story, not a separate follow-up.
4. `sr-game-designer` designed the fix (change the commitment-cost term's denominator from
   capacity to the same remaining-distance value progress already uses — a unit fix, not a
   weight retune). `game-feel-developer` confirmed the shape is right to build.
5. `mechanics-developer` (opus) implemented the fix and wrote 4 acceptance tests
   (`tests/MovementArbitrationTests.gd`, suite `movement_arbiter`). **Result just in, not yet
   reviewed by qa-verifier**:
   - Tests A, B, C pass (cliff removed on open ground; capacity stays meaningful at range;
     hostile-control restraint still works and is attributable to the real cause).
   - **Test D fails ON PURPOSE** — a smaller residual cliff exists specifically under the
     `directive.scout_carefully` directive (its own `avoid_overcommit` term was deliberately
     left capacity-normalized, per the design). The agent left this test red rather than
     quietly relaxing it, to keep the gap visible. **Open question for Jeff**: should
     `directive_avoid_overcommit` also be distance-normalized (closing this gap), or is a
     directive-driven "patience shortens a long approach" acceptable as-is?
   - **Explained, with real evidence (an isolation experiment, not theory), why RECOVER,
     PROTECT, PURSUE, ENDURE, and GUIDE_SPIRIT fixture fights did NOT get shorter from this
     commitment fix** — those five modes are provably unaffected by the commitment-scoring
     change (byte-identical hashes with and without it). Their round-count increases (e.g.
     PURSUE 4→8, PROTECT 5→6) come from a DIFFERENT already-uncommitted change: the
     multi-route-shape live wiring itself (item 1 above), confirmed by a second isolation
     experiment. **Open question for Jeff**: are these new PURSUE/PROTECT numbers the intended
     Phase 3 outcome (in which case the seven `combat_baseline` fingerprints get re-recorded
     once everything is settled), or do they need their own investigation first, the way
     COMBAT/PURIFY_SHRINE's numbers did?

6. **`qa-verifier` (opus) reviewed all of the above. Verdict: SHIP, with corrections.** Full
   result is in the conversation (search for "QA VERIFICATION — V2-COMBAT-003.5 Phase 3c"). Key
   points for whoever resumes:
   - **The real expected-failure count is 15, not 8.** The build agent's report only checked
     `tests combat` (misses a separate `fingerprint` suite with 7 more failures of the same
     already-approved cause). Cold full suite: `1667 total, 1652 passed, 15 failed` — 1 is Test D
     (expected), 7 are `fingerprint/*`, 7 are `combat_baseline/emotion_trace_*` (all held per
     decision #27). No new failures beyond what's already understood.
   - **Test D's arithmetic re-derived independently and confirmed exact** — real residual gap
     under `directive.scout_carefully` specifically, `seek_signs` is structurally immune (no
     `avoid_overcommit` key at all). Two open questions from Phase 3c's build (below) both
     confirmed accurately characterized.
   - **New finding, not blocking**: the fix's `commitment / progress_origin_distance` mixes
     units — cost (movement points) over distance (cells). These are equal today only because
     the live path uses uniform terrain cost and 8-way movement; the day non-uniform terrain
     cost or a bigger hostile-control surcharge is authored, this silently breaks. Needs a
     design decision, not urgent.
   - **New finding, not blocking**: the full suite now takes ~20 minutes, not the ~7 `AGENTS.md`
     documents. Every future agent using that documented timeout will get killed mid-run and it
     will look exactly like a hang. `AGENTS.md`'s "How to Run & Verify" section needs correcting
     once Phase 3 settles.
   - **Methodology flag**: the isolation experiment proving RECOVER/PROTECT/PURSUE/ENDURE/
     GUIDE_SPIRIT are unaffected by the commitment fix may have run on an uncleared
     `/tmp/echoes-vnext-tests` (a stale `.bak1` was found there). The conclusion is also stated
     too broadly — the accurate claim is "on these seven fixtures, at these seeds, the fix never
     flipped a decision," not "zero effect, structurally." Recommend a clean rerun (delete the
     save dir first) before fully trusting this, and correct the claim's wording either way.

   Bring all of this to Jeff via `AskUserQuestion`, in STE, before doing anything else — do not
   silently apply any of the three "needs a decision" items above.

## What must happen next, in order — do not skip ahead

1. Read `qa-verifier`'s Phase 3c review result (may already be in the conversation by the time
   this is read post-compaction — check for a `<task-notification>` first).
2. Resolve whatever it finds. If clean: present the two open questions above to Jeff.
3. Once Jeff answers: apply his decisions (dispatch a small fix/re-record pass as needed),
   record the new decisions in `docs/v2-combat-003.5-decisions.md` (next entry is **#29**).
4. Get Phase 3c to a genuinely clean, fully-reviewed state — full cold suite run via
   `qa-verifier`, zero unexplained failures (the 7 fingerprint failures are expected until the
   re-record decision is made and executed; after that, zero).
5. Commit Phase 3c as its own WIP commit (matching the style of `369ccfe`/`603b5de` — a
   thorough commit message naming every subject the commit carries).
6. **Only then** move to Phase 4 (doc/debug fixes — Group C: `combat_emotion` deletion done
   already? check decisions #22-25/#55 — the doc/debug items were mostly Phase-agnostic small
   fixes folded into earlier phases; check `docs/v2-combat-003.5-decisions.md` and the plan file
   for what's actually left) and Phase 5 (scattered small defects — Groups D/E from the original
   story scope: `shrine_hp_ratio`, `_divergence_probe`, `resist_fear`, `_stationary_rounds`,
   `_withdraw_cooldown`, `_dominant_key` unification, raw-floats-in-snapshot removal,
   enemy-directive faction-gating investigation — check the plan file's Phase 5 section for the
   full list and each item's default treatment).
7. Then Phase 6 (combined verification), 7 (full regression), 8 (manual verification — **stop
   and ask Jeff to test in-game**, don't skip this), 9 (docs + Notion + CSV + final commit + PR).

## The six spawned follow-up tasks (out of this story's scope, tracked separately)

**The tracking file described below (`docs/v2-combat-003.5-followup-tasks.md`) does not exist in
the repo, this worktree, or the scratchpad as of this verification pass.** It was never written
to disk despite being described as committed and sent to Jeff as a file. Recreate it from the
task IDs below the first time any of them needs updating, and check with Jeff whether he still
has the file he was sent, since that may be the only surviving copy of the full opening prompts.

Task IDs, for reference if any need `dismiss_task`:
1. `task_6206db50` — Fix `perceived_actors` script error in `MovementOptionService`
2. `task_0a287277` — Review PURSUE reward payout after board-size increase
3. `task_d44dccca` — Fix stale PURSUE comment and board-size fallback defaults
4. `task_1868ffd0` — Check if `speed_bonus_threshold` needs to scale with board size
5. `task_8b7887b3` — Add pronoun substitution to `GuidanceContribution` reason text
6. `task_afaaec2e` — Design a real "stop and hold" movement behavior (§7.5)

If you notice anything else out of scope, spawn a 7th and update that file + resend it to Jeff.

## Decision log — where the real history lives

`docs/v2-combat-003.5-decisions.md`, 28 entries as of this writing. Read it in full if any doubt
about a past call — it has the Q, the A, and why, for every scope/design/naming decision made
outside the one formal interview. Do not re-ask something already answered there.

## Lessons updated this session — read `~/.claude/lessons.md` in full

At minimum, these were added or corrected THIS session and directly affect how you work:
- ANSWERS.md is interview-only; decisions get their own per-story file (not ANSWERS.md).
- Use the project's own 9-agent roster, never generic agent types.
- A one-line text change can still need a test run.
- Comment density keeps creeping back despite the existing repo rule — trim proactively.

## One more thing

Jeff said, when asking for this handoff: **"I want to maintain our exact way of working and the
agent."** Read that as the standard to hold yourself to post-compaction — not a looser,
faster, or more autonomous version of this session's process. The review gates, the STE
communication, the decision log discipline, the roster-only dispatch, the killed-agent audits —
all of it, unchanged.
