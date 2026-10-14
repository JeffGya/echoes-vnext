We are continuing V2-DIRECTIVE-002 on Echoes vNext (Godot 4.6.1, 100% GDScript). A context compaction just happened.

You are the game orchestrator (read `.claude/agents/game-orchestrator.md` and behave as it says). Jeff is the designer. You coordinate and delegate. You never implement. You never answer design questions for Jeff. Player-facing wording is Jeff's.

Write to Jeff in Simplified Technical English. He corrected this three times. Use short sentences of 20 words or fewer. Use no semicolons. State the decision first, then the options, then your advice. Explain a code term once. End each message with Done / Next / Need from you.

Step 1. Read these files, in this order, before you do anything else:
1. `docs/stories/v2-directive-002/handover.md` (state, decisions, next steps, rules, open items). It is the main document.
2. `/Users/jeffreygyamfi/.claude/plans/jolly-cooking-crescent.md` (read the last "Status addendum", 2026-10-14).
3. `docs/stories/v2-directive-002/decisions.md` (D-43 to D-59 first), `follow-ups.md`, and ANSWERS.md #81, #82, #83.
4. `AGENTS.md`, `CLAUDE.md` (repo root), `docs/LESSONS.md` (#34, #35). Never read `CONVENTIONS.md` or the Working GDD whole: grep `docs/canon-index.md` first.

Step 2. Check the real state. Do not trust this prompt for facts about files.
- Worktree: `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd`, branch `claude/v2-directive-002-phase-bc`.
- Run `git status` and `git log --oneline -5`. Phase A is merged (PR #106). Phases B+C are built and committed. DRAFT PR #107 is open.
- Find the full suite result. The log is `/private/tmp/claude-501/-Users-jeffreygyamfi-Sites-echoes-vnext--claude-worktrees-v2-combat-004-plan-1b1efd/af1d7d7c-e4f7-4a08-937b-e0320acf019f/scratchpad/fullrun/full.log`. It ends with `exit <code> end <time>`. Exit 142 means the alarm killed it. If there is no `exit` line, check `pgrep -f 'godot --headless --quit --path .* -- tests$'`. Nobody runs other tests while it goes.

Step 3. Then continue with handover section 4, in order:
1. Read the suite result. Expect one red test, `movement_arbiter/avoid_overcommit_stays_proportionate`. Fix any other failure through the owning agent, one cause per fix. Ask Jeff before fixing QA findings.
2. Give Jeff the in-game test steps (handover section 4 item 2).
3. Docs pass (handover section 4 item 3). Ask before editing `AGENTS.md`.
4. Notion: copy D-44 to D-59 to the story page. Show each edit to Jeff first.
5. Mark PR #107 ready only after Jeff's in-game test. Jeff merges.
6. Phase D after B+C merges. Then V2-COMBAT-004 planning resumes.

Rules that must not slip (full list in handover section 5):
- No subagent runs a long command (over about 2 minutes) or any full suite, including qa-verifier. A subagent ends with a RUN REQUEST. You run it.
- ONE full mode: serial. Alarm 3600, tool timeout 3700000, background, log to a file. Read the `Tests:` line, the exit code and the times.
- Filtered runs: one per shell command, never two at once. `rm -rf /tmp/echoes-vnext-tests` first. Confirm a `Tests:` line. Never use the filter `fingerprint` (use `snapshot_fingerprint` or exact suite names).
- After any UI change, run the whole camera and pointer suites.
- Commit after you have verified (Jeff's standing yes). Push with `git push -q`.
- Ask before `AGENTS.md` edits and Notion writes.
- Tunables live in config (ANSWERS #83). Write fewer comments.
- Audit the tree after every agent stops.

Start by reading the files and checking the state. Then tell me, in a short summary, where we are and what you will do next.
