# V2-COMBAT-002 Slice 5 — Orchestrator Handoff

Created 2026-07-19 (Europe/Amsterdam). Copy the block below into a new chat.

---

```text
Act as the root orchestrator for Echoes vNext story V2-COMBAT-002, continuing at SLICE 5 of 6.
Slices 1–4 are complete. Do not re-plan the story; continue the existing approved plan.

## THE PLAN (read first, completely)
Canonical plan: /Users/jeffreygyamfi/Sites/echoes-vnext/docs/proposals/v2-combat-002-orchestrator-handoff.md
(An ephemeral original may still exist at /private/tmp/v2-combat-002-orchestrator-handoff.md — /private/tmp is NOT
durable; the docs/proposals copy is authoritative. It is untracked on purpose — Jeff's private planning area.)

Then independently obey AGENTS.md and re-read the mandatory authorities it and the plan list:
CONVENTIONS.md, docs/CONTEXT.md, docs/LESSONS.md, ~/.claude/lessons.md, docs/MEMORY.md,
docs/v2-migration-map.md, docs/integration-map.md, docs/Echoes vNext Working GDD.md,
docs/movement-model.md (untracked, main repo), docs/combat-modes.md.
Use the project skills: godot-echoes-dev, echoes-sankofa-gdd, echoes-backlog, game-ui-ux-echoes.
prototypes/ is EVIDENCE ONLY and must never be imported into production.

Notion story: https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8
(The workspace Notion connector works — fetch/update-page are available. The OAuth-gated
"plugin:Notion" is a different, unavailable integration; don't confuse them.)

## STATE
- Slices 1/2/3 merged to main as PRs #45 / #46 / #47. origin/main was at 421d209 (slice 3).
- Slice 4 shipped as commit 6e3f1f4, PR #48 — VERIFY whether #48 has merged before branching.
- Test baseline after #48 merges: 1233/1233, 0 failed. (Slice-3 merge point was 1149.)
- Everything through slice 4 is DORMANT: no live wiring. The seven objective modes are untouched.
- Godot 4.6.1 at /opt/homebrew/bin/godot.

## SLICE 5 SCOPE — "Party stage adapter" (P6), still DORMANT
Build `StagePartyMovementAdapter`: convert party/directive state into ONE shared profile, goal,
intent, and result for STAGE traversal, using the slice-1..4 contracts. Combat is done; this is stage.
Known facts to verify against current code:
- Stage traversal is ONE PARTY TOKEN in `_handle_stage_advance_turn()`. It must remain party-based —
  do NOT introduce per-Echo stage movement.
- Party budget currently comes from directive `step_budget`: Scout Carefully 3, Seek Signs 6.
- Per-cell fog reveal and contact interruption already exist and must be preserved.
- KNOWN DEFECT TO CORRECT: internal stepped cells exclude the start, but the stored/projected
  `traveled_path` PREPENDS it. The movement contracts mandate path-excludes-start; reconcile, and
  adapt the presentation's chained tween to the corrected convention.
- Hard objective preference and deterministic frontier ties need a BIAS REVIEW (no row/col bias),
  not random wandering.
Live cutover stays in SLICE 6.

## FROZEN DECISIONS — do not re-litigate
1. Capacity = clamp(max(standing_capacity, aptitude_capacity), 2, 6). Standing bands S1-2→2, S3-5→3,
   S6-9→4 (ceiling 4). aptitude = 2 + (agi≥12) + (agi≥18) + kra_soro Calling + kra_soro_open_ground.
   max(), NOT sum. No Standing term in aptitude; no saved max_movement; equipment → ITEM-003.
2. Diagonal illegal iff BOTH orthogonal side cells are non-walkable; occupied-but-walkable does not
   block. This is a REBUILD — no legacy compatibility; old paths get replaced at cutover, not preserved.
3. GUIDE objective-phase = explicit NPC activation through the shared executor + hazards, authored
   one-cell pace preserved, resolved before GUIDE progress is scored.
4. Six-PR slicing; slices 1–5 dormant; live cutover in slice 6.
5. PROTECT custody: pickup IS the activation's single primary action; totem follows the carrier on
   voluntary AND forced steps; −1 carrier burden; theft only on a successful ATTACK, never on cell
   entry; enemy carrier restricted + double damage; drop = carrier's current cell.
6. Board retreat reuses the EXISTING `withdraw` goal purpose. "Withdraw from combat entirely" is the
   separate, already-shipped RetreatService — out of scope, untouched.
7. PURSUE quarry timing/economy PRESERVED; only cutoff TARGETING changed. Escape-graph cutoff is
   PRIMARY over the authored fallback_region. Escape win-line stays the long-axis far end.
8. Authored one-cell pace is a STEP COUNT, not a cost budget; keyed off the `authored_override`
   contract, so it also covers burdened PROTECT carriers (Jeff explicitly confirmed the broad form).
9. Action economy UNCHANGED (capacity = movement only; one primary action after movement). A unified
   action-point pool is DEFERRED to its own story — see docs/proposals/action-point-economy.md.

## SLICE-6 CARRY-FORWARD (do NOT fix in slice 5 unless Jeff says so)
Full list in docs/integration-map.md. Headlines: `escort`/`protect` purpose paired with an
`actor.idle` primary is invalid under MovementGoal's rules; `"no_route"` conflates arrived vs
unreachable; joined-refusal still resolves Burning at origin; COLLAPSE_HEALTH/FALLBACK_RADIUS/
INTERCEPT_LANE_RADIUS need a balance.json seam; `withdraw`'s §8.3 action consequence is unowned;
controlling_state default divergence (executor false vs profile true); guard hazard_ctx.config
presence; drive mover_ko_only from live actor state; ratify _PURPOSE_FALLBACK_ALLOW; confirm the
proposed 3/3 hazard damages; add an escape-rule fidelity test vs FlowRuntime.gd:2082-2087.

## METHOD — orchestrator, and Jeff enforces this
- DELEGATE EVERYTHING that writes a file: code, tests, config (including balance.json), docs,
  AppRoot test registration. Also delegate reconnaissance. Your own hands touch only: scratchpad
  planning/contract-freeze docs, memory, git operations, the compile/test watchdogs, and dispatch.
  Jeff has corrected this twice — do not edit repo files yourself.
- Freeze contracts BEFORE delegating. Write a slice-5 contract-freeze doc to your scratchpad.
- Build agents run SERIALLY in the single worktree (concurrent Godot runs + shared files race).
  Give disjoint file ownership; only one agent owns a shared file (balance.json, AppRoot) at a time.
- Commission independent reviews: architecture, determinism, movement-design, mode-correctness,
  test-coverage. Ban mutation testing in review agents (see gotcha below).
- STOP for Jeff on genuine design forks the freezes don't settle. Present options with a
  recommendation. Do not assume; do not silently pick.
- VERIFY, don't trust agent reports. Re-run the suite yourself.

## CRITICAL GOTCHAS (each of these already cost real time)
1. THE TEST RUNNER ALWAYS EXITS 0. `tests exit: 0` means nothing. The ONLY truth is the summary line
   `Tests: N total, N passed, M failed`. A slice once sat at "1207 passed, 17 failed" behind a green
   exit code. Always grep the totals AND grep for `❌ <suite>` lines.
2. A fresh git worktree has NO .godot import cache (it's gitignored), and the headless test run will
   HANG until the watchdog kills it, leaving a boot-only log. Fix once per worktree, ~9s:
   /opt/homebrew/bin/godot --headless --import --path <worktree>
3. AVOID `cd` in Bash — it triggers permission prompts. Use `git -C <path> …` and absolute paths.
   Godot takes `--path`, so it never needs a cd.
4. DON'T use the perl watchdog wrapper from AGENTS.md — its head command is `perl`, which can't be
   safely allowlisted, so it re-prompts forever. Call godot directly and use the Bash tool's own
   `timeout` parameter. Generalized godot patterns are already allowlisted in .claude/settings.json.
5. MUTATION TESTING BY AGENTS CAN LEAVE THE TREE BROKEN. An agent validating test strength edited
   production code (`if false:` in place of a guard, a malformed ternary) and was interrupted before
   reverting — the suite went red with a plausible-looking defect that took real effort to diagnose.
   Ban it in review agents; if a build agent uses it, require immediate revert, never batched.
6. Godot resolves user:// by PROJECT NAME, so running the game from a worktree shares Jeff's REAL
   save file. The headless test runner is unaffected (redirects to /tmp/echoes-vnext-tests/).

## GIT / WORKTREE
- PRESERVE Jeff's user-owned dirty + untracked files in the main repo. Never reset, stash, stage,
  rewrite, or commit them: AGENTS.md, docs/Echoes vNext Working GDD.md, the backlog CSV,
  docs/movement-model.md, docs/proposals/, prototypes/.
- Leave the /Users/jeffreygyamfi/.codex/worktrees/* worktrees alone — not ours to clean.
- After #48 merges: fast-forward local main (`git -C <repo> merge --ff-only origin/main`), prune the
  slice-4 worktree + branch, then create a FRESH worktree/branch off updated origin/main:
  git -C <repo> worktree add -b feat/v2-combat-002-slice-5 /private/tmp/echoes-vnext-v2-combat-002-slice-5 origin/main
  then build the import cache (gotcha 2), then establish a clean baseline before any edits.
- Stage EXPLICITLY at commit time (never `git add -A`): the import step regenerates stray .uid
  sidecars for older slices that must NOT be committed.
- Commit messages end with: Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  PR bodies end with: 🤖 Generated with [Claude Code](https://claude.com/claude-code)

## VERIFY COMMANDS
Compile:  /opt/homebrew/bin/godot --headless --check-only --quit --path <worktree>
Tests:    /opt/homebrew/bin/godot --headless --quit --path <worktree> -- tests
Benign-and-expected ERROR lines in a clean run: the uid://8qssuuodths2 theme warning,
"BehaviorModule.*() called on base class", and "[SaveService] Invalid save: missing schema_version".

## CLOSING SEQUENCE (only after automated verification)
Stop for Jeff's manual in-game check → Docs (CONVENTIONS.md, docs/MEMORY.md, docs/integration-map.md)
→ commit → PR → append a "Slice 5 Accepted" progress entry to the Notion story page, matching the
format of the Slice 1–4 entries already there. Note: for a DORMANT slice, Jeff has said the manual
test can only confirm "nothing broke" — treat it as a formality, not a gate, and say so honestly.

At every handoff report: exact contracts, mode behavior, tests and ACTUAL totals, manual result,
deferred work, changed files, commit/PR, and remaining risks.
```
