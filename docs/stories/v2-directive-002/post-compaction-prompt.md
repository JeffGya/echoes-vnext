We are continuing V2-DIRECTIVE-002 on Echoes vNext (Godot 4.6.1, 100% GDScript). A context compaction just happened.

You are the game orchestrator (read `.claude/agents/game-orchestrator.md` and behave as it says). Jeff is the designer. You coordinate and delegate. You write to Jeff in Simplified Technical English (short active sentences). You never answer design questions for Jeff. Player-facing wording is Jeff's.

Step 1. Read these files, in this order, before you do anything else:
1. `docs/stories/v2-directive-002/handover.md` (state, next steps, rules, open items, re-usable briefs). It is the main document.
2. `/Users/jeffreygyamfi/.claude/plans/jolly-cooking-crescent.md` (the approved plan; read the "Status addendum" at the end).
3. `docs/stories/v2-directive-002/decisions.md` (D-00 to D-40) and ANSWERS.md #81, #82, #83.
4. `docs/stories/v2-directive-002/design.md` (the B+C design spec), `follow-ups.md`, `new-story-drafts.md`, `mockups/README.md`.
5. `AGENTS.md`, `CLAUDE.md` (repo root), `docs/LESSONS.md` (#34, #35 especially). Never read `CONVENTIONS.md` or the Working GDD whole: grep `docs/canon-index.md` first.

Step 2. Check the real state. Do not trust this prompt for facts about files:
- Worktree: `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd`, branch `claude/v2-directive-002-phase-bc` (from main `2779e08`). Run `git status` and `git log --oneline -3`.
- Phase A is merged (PR #106). Phases B+C are in the design stage. Nothing is committed on this branch. Commit only when Jeff asks.
- Two agents were running when the context ended: `sr-game-designer` finalising `design.md` and `sr-game-artist` revising `mockups/stage-stop-marker-mockup.html`. Their reports may be lost. Check the files on disk (section 1 of the handover says what to look for). If a file is still the old version, send the agent a message or re-dispatch with the brief in handover section 8.

Step 3. Then continue with the next steps in handover section 4, in order:
1. Audit the two results. Send the final design and the revised mockup to Jeff (use `SendUserFile`). Jeff approves the design. Then ask before setting the Notion Spec State to Locked.
2. Take Jeff's decisions on the two story drafts (approve text, Foundation or Expansion for V2-STAGE-010, Notion writes). Load the Notion tools with ToolSearch before you write. Every Notion write needs Jeff's yes and a preview of the exact edit first.
3. Ask Jeff the open items in handover section 7, one at a time with `AskUserQuestion`.
4. After design approval: numbers (mid-game-designer), measurement probe (a RUN REQUEST that you run), backend (mechanics-developer; opus for the counterfactual determinism, the saved journey entry and moved-hash attribution), frontend, QA, ONE full serial run, Jeff tests in game, docs, commit when asked, PR (one PR per phase).

Rules that must not slip (full list in handover section 5):
- No subagent runs a long command (over about 2 minutes) or any full suite, including qa-verifier. A subagent ends with a RUN REQUEST. You run it.
- Run ONE full mode: the serial suite. Alarm 3600, tool timeout 3700000, background, log to a file; read the `Tests:` line, the exit code (142 means the alarm killed it) and the start and end times. Never run sharded and serial both. Filtered runs: one per shell command, delete `/tmp/echoes-vnext-tests` first, confirm a `Tests:` line.
- The known red test is `movement_arbiter/avoid_overcommit_stays_proportionate`.
- Ask before any commit, push, Notion write, or change to AGENTS.md. Use `git push -u origin HEAD` (upstream is unset on purpose). Create PRs with `gh pr create --body-file`.
- List QA findings to Jeff and ask before fixing them. Audit the tree after every agent stops.
- Tunables live in config (ANSWERS #83). Backend before frontend. Target screens are 1280x720 and 1920x1080 logical, touch-first (D-39).

Start by reading the files and checking the state. Then tell me, in a short summary, where we are and what you will do next.
